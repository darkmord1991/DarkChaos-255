/*
 * Dark Chaos - Spectator Addon Module Handler
 * ============================================
 * 
 * Handles DC|SPEC|... messages for M+ spectator system.
 * Integrates with dc_mythic_spectator.cpp
 * 
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "DCAddonNamespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"

namespace DCAddon
{
namespace Spectator
{
    // Active spectators map: spectatorGuid -> runId they're watching
    static std::unordered_map<uint32, uint32> s_ActiveSpectators;
    
    // Handler: Request to spectate a run
    static void HandleRequestSpectate(Player* player, const ParsedMessage& msg)
    {
        uint32 runId = msg.GetUInt32(0);
        
        // Verify run exists and is in progress
        QueryResult result = CharacterDatabase.Query(
            "SELECT dungeon_id, keystone_level, start_time, status FROM dc_mythic_plus_runs "
            "WHERE run_id = {} AND status = 'in_progress'",
            runId);
        
        if (!result)
        {
            Message(Module::SPECTATOR, Opcode::Spec::SMSG_SPECTATE_STOP)
                .Add(0)  // error
                .Add("Run not found or not in progress")
                .Send(player);
            return;
        }
        
        uint32 dungeonId = (*result)[0].Get<uint32>();
        uint32 keystoneLevel = (*result)[1].Get<uint32>();
        
        // Check if player is allowed to spectate
        bool canSpectate = true;
        
        // Option: Only allow spectating if not in combat
        if (player->IsInCombat())
        {
            Message(Module::SPECTATOR, Opcode::Spec::SMSG_SPECTATE_STOP)
                .Add(0)
                .Add("Cannot spectate while in combat")
                .Send(player);
            return;
        }
        
        // Register as spectator
        s_ActiveSpectators[player->GetGUID().GetCounter()] = runId;
        
        // Get dungeon info
        std::string dungeonName = "Unknown Dungeon";
        uint32 mapId = 0;
        QueryResult dungeonResult = WorldDatabase.Query(
            "SELECT dungeon_name, map_id FROM dc_mythic_plus_dungeons WHERE dungeon_id = {}",
            dungeonId);
        if (dungeonResult)
        {
            dungeonName = (*dungeonResult)[0].Get<std::string>();
            mapId = (*dungeonResult)[1].Get<uint32>();
        }
        
        Message(Module::SPECTATOR, Opcode::Spec::SMSG_SPECTATE_START)
            .Add(1)  // success
            .Add(runId)
            .Add(dungeonId)
            .Add(dungeonName)
            .Add(mapId)
            .Add(keystoneLevel)
            .Send(player);
        
        LOG_DEBUG("dc.addon.spec", "Player {} started spectating run {}", 
                  player->GetName(), runId);
    }
    
    // Handler: Stop spectating
    static void HandleStopSpectate(Player* player, const ParsedMessage& /*msg*/)
    {
        uint32 guid = player->GetGUID().GetCounter();
        
        auto it = s_ActiveSpectators.find(guid);
        if (it != s_ActiveSpectators.end())
        {
            uint32 runId = it->second;
            s_ActiveSpectators.erase(it);
            
            Message(Module::SPECTATOR, Opcode::Spec::SMSG_SPECTATE_STOP)
                .Add(1)  // success
                .Add(runId)
                .Send(player);
            
            LOG_DEBUG("dc.addon.spec", "Player {} stopped spectating run {}", 
                      player->GetName(), runId);
        }
        else
        {
            Message(Module::SPECTATOR, Opcode::Spec::SMSG_SPECTATE_STOP)
                .Add(0)
                .Add("Not currently spectating")
                .Send(player);
        }
    }
    
    // Handler: List active runs available to spectate
    static void HandleListRuns(Player* player, const ParsedMessage& /*msg*/)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT r.run_id, r.dungeon_id, r.keystone_level, r.start_time, "
            "d.dungeon_name, COUNT(DISTINCT p.player_guid) as party_size "
            "FROM dc_mythic_plus_runs r "
            "LEFT JOIN dc_mythic_plus_dungeons d ON r.dungeon_id = d.dungeon_id "
            "LEFT JOIN dc_mythic_plus_run_participants p ON r.run_id = p.run_id "
            "WHERE r.status = 'in_progress' AND r.allow_spectators = 1 "
            "GROUP BY r.run_id ORDER BY r.keystone_level DESC LIMIT 20");
        
        std::string runList;
        uint32 count = 0;
        
        if (result)
        {
            do
            {
                if (count > 0) runList += ";";
                
                uint32 runId = (*result)[0].Get<uint32>();
                uint32 dungeonId = (*result)[1].Get<uint32>();
                uint32 level = (*result)[2].Get<uint32>();
                // start_time is [3]
                std::string dungeonName = (*result)[4].IsNull() ? "Unknown" : (*result)[4].Get<std::string>();
                uint32 partySize = (*result)[5].Get<uint32>();
                
                std::ostringstream ss;
                ss << runId << ":" << dungeonId << ":" << dungeonName << ":" << level << ":" << partySize;
                runList += ss.str();
                count++;
            } while (result->NextRow());
        }
        
        Message(Module::SPECTATOR, Opcode::Spec::SMSG_RUN_LIST)
            .Add(count)
            .Add(runList)
            .Send(player);
    }
    
    // Handler: Set HUD display option
    static void HandleSetHUDOption(Player* player, const ParsedMessage& msg)
    {
        std::string option = msg.GetString(0);
        bool enabled = msg.GetBool(1);
        
        // Store player's HUD preferences
        uint32 guid = player->GetGUID().GetCounter();
        
        // Options: showTimer, showDeaths, showBosses, showDamage, showHealing
        CharacterDatabase.Execute(
            "INSERT INTO dc_spectator_settings (player_guid, setting_key, setting_value) "
            "VALUES ({}, '{}', {}) ON DUPLICATE KEY UPDATE setting_value = {}",
            guid, option, enabled ? 1 : 0, enabled ? 1 : 0);
        
        LOG_DEBUG("dc.addon.spec", "Player {} set HUD option {} to {}", 
                  player->GetName(), option, enabled);
    }
    
    // Register all handlers
    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(Module::SPECTATOR, Opcode::Spec::CMSG_REQUEST_SPECTATE, HandleRequestSpectate);
        DC_REGISTER_HANDLER(Module::SPECTATOR, Opcode::Spec::CMSG_STOP_SPECTATE, HandleStopSpectate);
        DC_REGISTER_HANDLER(Module::SPECTATOR, Opcode::Spec::CMSG_LIST_RUNS, HandleListRuns);
        DC_REGISTER_HANDLER(Module::SPECTATOR, Opcode::Spec::CMSG_SET_HUD_OPTION, HandleSetHUDOption);
        
        LOG_INFO("dc.addon", "Spectator module handlers registered");
    }
    
    // Check if player is spectating
    bool IsSpectating(Player* player)
    {
        return s_ActiveSpectators.find(player->GetGUID().GetCounter()) != s_ActiveSpectators.end();
    }
    
    // Get run ID player is spectating
    uint32 GetSpectatingRunId(Player* player)
    {
        auto it = s_ActiveSpectators.find(player->GetGUID().GetCounter());
        return (it != s_ActiveSpectators.end()) ? it->second : 0;
    }
    
    // Send HUD update to all spectators of a run
    void BroadcastHUDUpdate(uint32 runId, uint32 elapsed, uint32 remaining,
                           uint32 deaths, float progress, const std::string& bossInfo)
    {
        for (const auto& [spectatorGuid, watchingRunId] : s_ActiveSpectators)
        {
            if (watchingRunId != runId)
                continue;
            
            // Find player by GUID
            // Note: This needs SessionMgr access - placeholder for now
            // if (Player* spectator = ObjectAccessor::FindPlayer(ObjectGuid(HighGuid::Player, spectatorGuid)))
            // {
            //     Message(Module::SPECTATOR, Opcode::Spec::SMSG_HUD_UPDATE)
            //         .Add(elapsed)
            //         .Add(remaining)
            //         .Add(deaths)
            //         .Add(progress)
            //         .Add(bossInfo)
            //         .Send(spectator);
            // }
        }
    }
    
    // Player logout cleanup
    void OnPlayerLogout(Player* player)
    {
        s_ActiveSpectators.erase(player->GetGUID().GetCounter());
    }

}  // namespace Spectator
}  // namespace DCAddon

// Script class for cleanup
class DCAddonSpectatorScript : public PlayerScript
{
public:
    DCAddonSpectatorScript() : PlayerScript("DCAddonSpectatorScript") {}
    
    void OnPlayerLogout(Player* player) override
    {
        DCAddon::Spectator::OnPlayerLogout(player);
    }
};

void AddSC_dc_addon_spectator()
{
    DCAddon::Spectator::RegisterHandlers();
    new DCAddonSpectatorScript();
}
