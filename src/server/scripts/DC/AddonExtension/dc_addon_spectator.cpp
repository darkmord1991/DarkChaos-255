/*
 * Dark Chaos - Spectator Addon Module Handler
 * ============================================
 *
 * Handles DC|SPEC|... messages for M+ spectator system.
 * Integrates with dc_mythic_spectator.cpp
 *
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"

#include "../MythicPlus/dc_mythicplus_spectator.h"

namespace DCAddon
{
namespace Spectator
{
    // Handler: Request to spectate a run
    static void HandleRequestSpectate(Player* player, const ParsedMessage& msg)
    {
        uint32 instanceId = msg.GetUInt32(0);

        auto& mgr = DCMythicSpectator::MythicSpectatorManager::Get();

        std::string error;
        if (!mgr.CanSpectate(player, instanceId, error))
        {
            Message(Module::SPECTATOR, Opcode::Spec::SMSG_SPECTATE_STOP)
                .Add(0)
                .Add(error.empty() ? "Cannot spectate this run" : error)
                .Send(player);
            return;
        }

        if (!mgr.StartSpectating(player, instanceId))
        {
            Message(Module::SPECTATOR, Opcode::Spec::SMSG_SPECTATE_STOP)
                .Add(0)
                .Add("Failed to start spectating")
                .Send(player);
            return;
        }

        DCMythicSpectator::SpectateableRun const* run = mgr.GetRun(instanceId);
        uint32 mapId = run ? run->mapId : 0u;
        uint32 keystoneLevel = run ? run->keystoneLevel : 0u;

        std::string dungeonName = "Unknown Dungeon";
        if (mapId)
        {
            QueryResult dungeonResult = WorldDatabase.Query(
                "SELECT dungeon_name FROM dc_mplus_dungeons WHERE dungeon_id = {}",
                mapId);
            if (dungeonResult)
                dungeonName = (*dungeonResult)[0].Get<std::string>();
        }

        Message(Module::SPECTATOR, Opcode::Spec::SMSG_SPECTATE_START)
            .Add(1)  // success
            .Add(instanceId)
            .Add(mapId)
            .Add(dungeonName)
            .Add(mapId)
            .Add(keystoneLevel)
            .Send(player);

        LOG_DEBUG("dc.addon.spec", "Player {} started spectating run {}",
                  player->GetName(), instanceId);
    }

    // Handler: Stop spectating
    static void HandleStopSpectate(Player* player, const ParsedMessage& /*msg*/)
    {
        auto& mgr = DCMythicSpectator::MythicSpectatorManager::Get();

        if (!mgr.IsSpectating(player))
        {
            Message(Module::SPECTATOR, Opcode::Spec::SMSG_SPECTATE_STOP)
                .Add(0)
                .Add("Not currently spectating")
                .Send(player);
            return;
        }

        DCMythicSpectator::SpectatorState* state = mgr.GetSpectatorState(player->GetGUID());
        uint32 instanceId = state ? state->targetInstanceId : 0u;

        mgr.StopSpectating(player);

        Message(Module::SPECTATOR, Opcode::Spec::SMSG_SPECTATE_STOP)
            .Add(1)  // success
            .Add(instanceId)
            .Send(player);

        LOG_DEBUG("dc.addon.spec", "Player {} stopped spectating run {}",
                  player->GetName(), instanceId);
    }

    // Handler: List active runs available to spectate
    static void HandleListRuns(Player* player, const ParsedMessage& /*msg*/)
    {
        auto& mgr = DCMythicSpectator::MythicSpectatorManager::Get();
        std::vector<DCMythicSpectator::SpectateableRun> runs = mgr.GetSpectateableRuns();

        std::string runList;
        uint32 count = 0;

        for (DCMythicSpectator::SpectateableRun const& run : runs)
        {
            if (count >= 20)
                break;

            std::string dungeonName = "Unknown";
            QueryResult nameResult = WorldDatabase.Query(
                "SELECT dungeon_name FROM dc_mplus_dungeons WHERE dungeon_id = {}",
                run.mapId);
            if (nameResult)
                dungeonName = (*nameResult)[0].Get<std::string>();

            uint32 partySize = run.participantNames.empty()
                ? 5u
                : static_cast<uint32>(run.participantNames.size());

            if (count > 0)
                runList += ";";

            std::ostringstream ss;
            ss << run.instanceId << ":" << run.mapId << ":" << dungeonName << ":" << uint32(run.keystoneLevel) << ":" << partySize;
            runList += ss.str();
            ++count;
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
        return DCMythicSpectator::MythicSpectatorManager::Get().IsSpectating(player);
    }

    // Get run ID player is spectating
    uint32 GetSpectatingRunId(Player* player)
    {
        auto& mgr = DCMythicSpectator::MythicSpectatorManager::Get();
        if (DCMythicSpectator::SpectatorState* state = mgr.GetSpectatorState(player->GetGUID()))
            return state->targetInstanceId;
        return 0;
    }

    // Send HUD update to all spectators of a run
    void BroadcastHUDUpdate(uint32 runId, uint32 /*elapsed*/, uint32 /*remaining*/,
                           uint32 /*deaths*/, float /*progress*/, const std::string& /*bossInfo*/)
    {
        // TODO: If/when addon HUD updates are needed, use MythicSpectatorManager::GetSpectatorsForInstance(runId)
        // and broadcast appropriate messages.
        (void)runId;
    }

    // Player logout cleanup
    void OnPlayerLogout(Player* player)
    {
        DCMythicSpectator::MythicSpectatorManager::Get().StopSpectating(player);
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
