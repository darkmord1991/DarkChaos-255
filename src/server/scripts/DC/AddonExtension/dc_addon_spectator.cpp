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

#include <mutex>

namespace DCAddon
{
namespace Spectator
{
    // ========================================================================
    // DUNGEON NAME CACHE
    // ========================================================================
    //
    // dc_mplus_dungeons is a static world configuration table, but it used to
    // be re-queried from the DB on every HandleRequestSpectate call and on
    // every entry in the HandleListRuns loop (up to 20 blocking queries per
    // request). Load it once (lazily) into memory and serve every lookup from
    // the cache. Mirrors the GetDungeonNameById pattern in
    // dc_addon_groupfinder.cpp.
    // NOTE: changes to dc_mplus_dungeons require a worldserver restart to show.

    namespace
    {
        struct DungeonNameCacheEntry
        {
            uint32 dungeonId = 0;
            std::string name;
        };

        std::mutex sDungeonNameCacheMutex;
        bool sDungeonNameCacheLoaded = false;
        std::vector<DungeonNameCacheEntry> sDungeonNameCache;

        // Must be called with sDungeonNameCacheMutex held.
        void LoadDungeonNameCacheLocked()
        {
            if (sDungeonNameCacheLoaded)
                return;

            sDungeonNameCacheLoaded = true;

            // One-time synchronous read of a static world config table.
            QueryResult result = WorldDatabase.Query(
                "SELECT dungeon_id, dungeon_name FROM dc_mplus_dungeons");

            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();

                    DungeonNameCacheEntry entry;
                    entry.dungeonId = fields[0].Get<uint32>();
                    entry.name = fields[1].Get<std::string>();
                    sDungeonNameCache.push_back(std::move(entry));
                } while (result->NextRow());
            }

            LOG_INFO("dc.addon", "Spectator dungeon name cache loaded {} dungeons from dc_mplus_dungeons",
                sDungeonNameCache.size());
        }

        // Name lookup by dungeon_id (map id). Empty string when unknown.
        std::string GetDungeonNameById(uint32 dungeonId)
        {
            std::lock_guard<std::mutex> lock(sDungeonNameCacheMutex);
            LoadDungeonNameCacheLocked();

            for (DungeonNameCacheEntry const& entry : sDungeonNameCache)
                if (entry.dungeonId == dungeonId)
                    return entry.name;

            return "";
        }
    }

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
            std::string cachedName = GetDungeonNameById(mapId);
            if (!cachedName.empty())
                dungeonName = cachedName;
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
            std::string cachedName = GetDungeonNameById(run.mapId);
            if (!cachedName.empty())
                dungeonName = cachedName;

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

        // Options: showTimer, showDeaths, showBosses, showDamage, showHealing
        if (option != "showTimer" && option != "showDeaths" && option != "showBosses" &&
            option != "showDamage" && option != "showHealing")
        {
            LOG_DEBUG("dc.addon.spec", "Player {} sent unknown HUD option {}",
                      player->GetName(), option);
            return;
        }

        // Store player's HUD preferences
        uint32 guid = player->GetGUID().GetCounter();

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
