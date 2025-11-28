/*
 * Dark Chaos - Mythic+ Addon Module Handler
 * ==========================================
 * 
 * Handles DC|MPLUS|... messages for Mythic+ dungeon system.
 * Integrates with MythicPlusRunManager.
 * 
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "DCAddonNamespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"
#include "MythicPlusRunManager.h"

namespace DCAddon
{
namespace MythicPlus
{
    // Send current keystone info
    static void SendKeyInfo(Player* player)
    {
        // Query player's current keystone
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT dungeon_id, level, depleted FROM dc_mythic_keystones WHERE player_guid = {}",
            guid);
        
        if (result)
        {
            uint32 dungeonId = (*result)[0].Get<uint32>();
            uint32 level = (*result)[1].Get<uint32>();
            bool depleted = (*result)[2].Get<bool>();
            
            // Get dungeon name
            std::string dungeonName = "Unknown";
            QueryResult nameResult = WorldDatabase.Query(
                "SELECT dungeon_name FROM dc_mythic_plus_dungeons WHERE dungeon_id = {}",
                dungeonId);
            if (nameResult)
                dungeonName = (*nameResult)[0].Get<std::string>();
            
            Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_KEY_INFO)
                .Add(1)  // has keystone
                .Add(dungeonId)
                .Add(dungeonName)
                .Add(level)
                .Add(depleted)
                .Send(player);
        }
        else
        {
            Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_KEY_INFO)
                .Add(0)  // no keystone
                .Send(player);
        }
    }
    
    // Send current week's affixes
    static void SendAffixes(Player* player)
    {
        // Get current affixes from MythicPlusRunManager or config
        // For now, query from database
        QueryResult result = WorldDatabase.Query(
            "SELECT affix_id, affix_name, affix_description FROM dc_mythic_plus_weekly_affixes "
            "WHERE week_number = (SELECT MAX(week_number) FROM dc_mythic_plus_weekly_affixes)");
        
        std::string affixList;
        if (result)
        {
            bool first = true;
            do
            {
                if (!first) affixList += ";";
                first = false;
                
                uint32 id = (*result)[0].Get<uint32>();
                std::string name = (*result)[1].Get<std::string>();
                std::string desc = (*result)[2].Get<std::string>();
                
                affixList += std::to_string(id) + ":" + name + ":" + desc;
            } while (result->NextRow());
        }
        
        Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_AFFIXES)
            .Add(affixList)
            .Send(player);
    }
    
    // Send player's best runs
    static void SendBestRuns(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT dungeon_id, level, completion_time, deaths, season "
            "FROM dc_mythic_plus_best_runs WHERE player_guid = {} ORDER BY level DESC LIMIT 10",
            guid);
        
        std::string runList;
        if (result)
        {
            bool first = true;
            do
            {
                if (!first) runList += ";";
                first = false;
                
                uint32 dungeonId = (*result)[0].Get<uint32>();
                uint32 level = (*result)[1].Get<uint32>();
                uint32 time = (*result)[2].Get<uint32>();
                uint32 deaths = (*result)[3].Get<uint32>();
                uint32 season = (*result)[4].Get<uint32>();
                
                runList += std::to_string(dungeonId) + ":" + std::to_string(level) + ":" 
                        + std::to_string(time) + ":" + std::to_string(deaths) + ":" 
                        + std::to_string(season);
            } while (result->NextRow());
        }
        
        Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_BEST_RUNS)
            .Add(runList)
            .Send(player);
    }
    
    // Handler: Get keystone info
    static void HandleGetKeyInfo(Player* player, const ParsedMessage& /*msg*/)
    {
        SendKeyInfo(player);
    }
    
    // Handler: Get affixes
    static void HandleGetAffixes(Player* player, const ParsedMessage& /*msg*/)
    {
        SendAffixes(player);
    }
    
    // Handler: Get best runs
    static void HandleGetBestRuns(Player* player, const ParsedMessage& /*msg*/)
    {
        SendBestRuns(player);
    }
    
    // Register all handlers
    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_KEY_INFO, HandleGetKeyInfo);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_AFFIXES, HandleGetAffixes);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_BEST_RUNS, HandleGetBestRuns);
        
        LOG_INFO("dc.addon", "Mythic+ module handlers registered");
    }
    
    // Broadcast run update to all party members
    void BroadcastRunUpdate(uint32 runId, uint32 elapsed, uint32 remaining, 
                           uint32 deaths, uint32 bossesKilled, uint32 bossesTotal,
                           uint32 enemiesKilled, bool failed, bool completed)
    {
        // This would be called from MythicPlusRunManager
        // Get all players in the run and send updates
        
        // For now, placeholder - actual implementation needs RunManager integration
    }
    
    // Send HUD update to player
    void SendHUDUpdate(Player* player, const std::string& jsonData)
    {
        Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_TIMER_UPDATE)
            .Add(jsonData)
            .Send(player);
    }

}  // namespace MythicPlus
}  // namespace DCAddon

void AddSC_dc_addon_mythicplus()
{
    DCAddon::MythicPlus::RegisterHandlers();
}
