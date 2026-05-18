/*
 * Dark Chaos - Mythic+ Addon Module Handler
 * ==========================================
 *
 * Handles DC|MPLUS|... messages for Mythic+ dungeon system.
 * Integrates with MythicPlusRunManager.
 *
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "Common.h"
#include "dc_addon_namespace.h"
#include "WorldSessionMgr.h"
#include "WorldPacket.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"
#include "DBCStores.h"
#include "../MythicPlus/dc_mythicplus_run_manager.h"
#include "../MythicPlus/dc_mythicplus_constants.h"
#include "dc_addon_mythicplus.h"

#include <algorithm>
#include <optional>
#include <unordered_map>

namespace DCAddon
{
namespace MythicPlus
{
    namespace BridgeOpcode
    {
        enum : uint16
        {
            CMSG_REQUEST_HUD_SNAPSHOT = ::CMSG_REQUEST_MPLUS_HUD_SNAPSHOT,
            SMSG_HUD_SNAPSHOT = ::SMSG_MPLUS_HUD_SNAPSHOT,
        };
    }

    namespace
    {
        constexpr uint32 WEEK_SECONDS = 7u * 24u * 60u * 60u;

        DCAddon::TransportPolicyDecision ResolveHudTransport(Player* player)
        {
            DCAddon::TransportPolicyRequest request;
            request.featureName = "mythicplus-hud";
            request.nativeCapability =
                DCAddon::ProtocolVersion::Capability::MYTHICPLUS_HUD_NATIVE;
            return DCAddon::ResolveTransportPolicy(player, request);
        }

        void SendNativeHudSnapshot(Player* player,
            std::string const& payload)
        {
            if (!player || !player->GetSession() || payload.empty())
                return;

            WorldPacket data(BridgeOpcode::SMSG_HUD_SNAPSHOT,
                payload.size() + 1);
            data << payload;
            player->GetSession()->SendPacket(&data);
        }

        void SendAddonHudSnapshot(Player* player,
            std::string const& payload)
        {
            if (!player || payload.empty())
                return;

            Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_TIMER_UPDATE)
                .Add(payload)
                .Send(player);
        }

        void SendHudSnapshot(Player* player, std::string const& payload)
        {
            if (ResolveHudTransport(player).UsesNative())
            {
                SendNativeHudSnapshot(player, payload);
                return;
            }

            SendAddonHudSnapshot(player, payload);
        }

        bool JsonGetBool(DCAddon::JsonValue const& json, std::string const& key,
            bool defaultValue = false)
        {
            DCAddon::JsonValue const& value = json[key];
            if (value.IsBool())
                return value.AsBool();
            if (value.IsNumber())
                return value.AsInt32() != 0;
            if (value.IsString())
            {
                std::string lowered = value.AsString();
                std::transform(lowered.begin(), lowered.end(), lowered.begin(),
                    [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
                return lowered == "1" || lowered == "true" || lowered == "yes" ||
                    lowered == "on";
            }

            return defaultValue;
        }

        uint32 CountBits32(uint32 value)
        {
            uint32 count = 0;
            while (value)
            {
                value &= (value - 1);
                ++count;
            }
            return count;
        }

        uint32 GetRaidBossesForWeek(uint32 guidLow, uint32 weekStart, uint32 weekEnd)
        {
            uint32 raidBosses = 0;

            if (QueryResult raidRes = CharacterDatabase.Query(
                "SELECT i.map, i.completedEncounters "
                "FROM character_instance ci "
                "JOIN instance i ON i.id = ci.instance "
                "WHERE ci.guid = {} AND i.resettime >= {} AND i.resettime < {}",
                guidLow, weekStart, weekEnd))
            {
                do
                {
                    Field* fields = raidRes->Fetch();
                    uint32 mapId = fields[0].Get<uint32>();
                    uint32 completedEncounters = fields[1].Get<uint32>();

                    MapEntry const* mapEntry = sMapStore.LookupEntry(mapId);
                    if (!mapEntry || !mapEntry->IsRaid())
                        continue;

                    raidBosses += CountBits32(completedEncounters);
                } while (raidRes->NextRow());
            }

            return raidBosses;
        }

        uint32 GetMPlusRunsForWeek(uint32 guidLow, uint32 seasonId,
            uint32 weekStart, uint32 weekEnd)
        {
            if (QueryResult runsRes = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM dc_mplus_runs "
                "WHERE character_guid = {} AND season_id = {} AND success = 1 "
                "AND completed_at >= FROM_UNIXTIME({}) "
                "AND completed_at < FROM_UNIXTIME({})",
                guidLow, seasonId, weekStart, weekEnd))
            {
                return (*runsRes)[0].Get<uint32>();
            }

            return 0;
        }

        uint32 GetPvpWinsForWeek(uint32 guidLow, uint32 weekStart, uint32 weekEnd)
        {
            if (QueryResult pvpRes = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM pvpstats_players p "
                "JOIN pvpstats_battlegrounds b ON b.id = p.battleground_id "
                "WHERE p.character_guid = {} AND p.winner = 1 "
                "AND b.date >= FROM_UNIXTIME({}) "
                "AND b.date < FROM_UNIXTIME({})",
                guidLow, weekStart, weekEnd))
            {
                return (*pvpRes)[0].Get<uint32>();
            }

            return 0;
        }

        bool IsVaultRewardClaimed(uint32 guidLow, uint32 seasonId,
            uint32 claimWeekStart)
        {
            if (QueryResult claimRes = CharacterDatabase.Query(
                "SELECT reward_claimed FROM dc_weekly_vault "
                "WHERE character_guid = {} AND season_id = {} AND week_start = {}",
                guidLow, seasonId, claimWeekStart))
            {
                return (*claimRes)[0].Get<bool>();
            }

            return false;
        }

        bool CharacterTableExists(char const* tableName)
        {
            if (QueryResult result = CharacterDatabase.Query(
                "SELECT 1 FROM information_schema.TABLES "
                "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}' LIMIT 1",
                tableName))
            {
                return result->GetRowCount() > 0;
            }

            return false;
        }

        bool HasCharacterDungeonTable()
        {
            static bool const hasTable = CharacterTableExists("dc_mplus_dungeons");
            return hasTable;
        }

        void SendVaultAvailableNotification(Player* player)
        {
            if (!player)
                return;

            uint32 guidLow = player->GetGUID().GetCounter();
            uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
            uint32 currentWeekStart = sMythicRuns->GetWeekStartTimestamp();

            if (currentWeekStart < WEEK_SECONDS)
                return;

            uint32 claimWeekStart = currentWeekStart - WEEK_SECONDS;
            uint32 claimWeekEnd = claimWeekStart + WEEK_SECONDS;

            if (IsVaultRewardClaimed(guidLow, seasonId, claimWeekStart))
                return;

            uint32 mplusRuns = GetMPlusRunsForWeek(
                guidLow, seasonId, claimWeekStart, claimWeekEnd);
            uint32 raidBosses = GetRaidBossesForWeek(
                guidLow, claimWeekStart, claimWeekEnd);
            uint32 pvpWins = GetPvpWinsForWeek(
                guidLow, claimWeekStart, claimWeekEnd);

            auto raidThreshold = [](uint8 slotInTrack) -> uint32
            {
                if (slotInTrack == 1)
                    return sConfigMgr->GetOption<uint32>(
                        "MythicPlus.Vault.Raid.Threshold1", 2);
                if (slotInTrack == 2)
                    return sConfigMgr->GetOption<uint32>(
                        "MythicPlus.Vault.Raid.Threshold2", 4);
                return sConfigMgr->GetOption<uint32>(
                    "MythicPlus.Vault.Raid.Threshold3", 6);
            };

            auto pvpThreshold = [](uint8 slotInTrack) -> uint32
            {
                if (slotInTrack == 1)
                    return sConfigMgr->GetOption<uint32>(
                        "MythicPlus.Vault.PvP.Threshold1", 1);
                if (slotInTrack == 2)
                    return sConfigMgr->GetOption<uint32>(
                        "MythicPlus.Vault.PvP.Threshold2", 4);
                return sConfigMgr->GetOption<uint32>(
                    "MythicPlus.Vault.PvP.Threshold3", 8);
            };

            uint32 unlockedCount = 0;
            for (uint8 i = 1; i <= 3; ++i)
            {
                if (raidBosses >= raidThreshold(i))
                    ++unlockedCount;
                if (mplusRuns >= static_cast<uint32>(sMythicRuns->GetVaultThreshold(i)))
                    ++unlockedCount;
                if (pvpWins >= pvpThreshold(i))
                    ++unlockedCount;
            }

            if (unlockedCount == 0)
                return;

            JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_VAULT_AVAILABLE)
                .Set("available", true)
                .Set("unlockedCount", static_cast<int32>(unlockedCount))
                .Set("claimWeekStart", static_cast<int32>(claimWeekStart))
                .Set("claimWindowStart", static_cast<int32>(claimWeekStart))
                .Set("claimWindowEnd", static_cast<int32>(claimWeekEnd))
                .Set("weeklyResetAt", static_cast<int32>(currentWeekStart))
                .Set("nextWeeklyResetAt", static_cast<int32>(
                    currentWeekStart + WEEK_SECONDS))
                .Send(player);
        }
    }

    // Send current keystone info
    static void SendKeyInfo(Player* player)
    {
        // Query player's current keystone from dc_mplus_keystones
        uint32 guid = player->GetGUID().GetCounter();

        QueryResult result;
        if (HasCharacterDungeonTable())
        {
            result = CharacterDatabase.Query(
                "SELECT k.map_id, k.level, COALESCE(d.dungeon_name, '') "
                "FROM dc_mplus_keystones k "
                "LEFT JOIN dc_mplus_dungeons d ON k.map_id = d.map_id "
                "WHERE k.character_guid = {}",
                guid);
        }
        else
        {
            result = CharacterDatabase.Query(
                "SELECT map_id, level FROM dc_mplus_keystones WHERE character_guid = {}",
                guid);
        }

        if (result)
        {
            uint32 dungeonId = (*result)[0].Get<uint32>();
            uint32 level = (*result)[1].Get<uint32>();
            bool depleted = false;  // dc_mplus_keystones doesn't have depleted column

            // Get dungeon name
            std::string dungeonName = "Unknown";
            if (HasCharacterDungeonTable())
            {
                std::string const joinedName = (*result)[2].Get<std::string>();
                if (!joinedName.empty())
                    dungeonName = joinedName;
            }
            else
            {
                QueryResult nameResult = WorldDatabase.Query(
                    "SELECT dungeon_name FROM dc_mplus_dungeons WHERE dungeon_id = {}",
                    dungeonId);
                if (nameResult)
                    dungeonName = (*nameResult)[0].Get<std::string>();
            }

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
        std::vector<MythicPlusRunManager::WeeklyAffixInfo> affixes;
        if (sConfigMgr->GetOption<bool>("MythicPlus.Affixes.Enabled", false))
            affixes = sMythicRuns->GetWeeklyAffixInfo(sMythicRuns->GetCurrentSeasonId());

        std::string affixList;
        if (!affixes.empty())
        {
            for (size_t i = 0; i < affixes.size(); ++i)
            {
                if (i > 0)
                    affixList += ";";

                affixList += std::to_string(affixes[i].affixId) + ":" + affixes[i].name + ":" + affixes[i].description;
            }
        }

        Message(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_AFFIXES)
            .Add(affixList)
            .Send(player);
    }

    // Send canonical keystone item IDs as JSON list
    static void SendJsonKeystoneList(Player* player)
    {
        JsonValue itemsArr;
        itemsArr.SetArray();
        for (uint8 i = 0; i < 19; ++i)
        {
            itemsArr.Push(JsonValue(static_cast<int32>(MythicPlusConstants::KEYSTONE_ITEM_IDS[i])));
        }

        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_KEYSTONE_LIST)
            .Set("items", itemsArr.Encode())
            .Send(player);
    }

    // Send player's best runs
    static void SendBestRuns(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();

        QueryResult result = CharacterDatabase.Query(
            "SELECT dungeon_id, level, completion_time, deaths, season "
            "FROM dc_mplus_best_runs WHERE player_guid = {} ORDER BY level DESC LIMIT 10",
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

    // Handler: Get canonical keystone list
    static void HandleGetKeystoneList(Player* player, const ParsedMessage& /*msg*/)
    {
        SendJsonKeystoneList(player);
    }

    // Handler: Pending keystone activation ready / decline response
    static void HandleKeystoneResponse(Player* player, const ParsedMessage& msg)
    {
        if (!player)
            return;

        bool accepted = true;
        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
            accepted = JsonGetBool(json, "accepted",
                JsonGetBool(json, "ready", true));
        }
        else if (msg.GetDataCount() > 0)
        {
            accepted = msg.GetBool(0);
        }

        HandleKeystoneActivationResponse(player, accepted);
    }

    // Handler: Pending keystone activation cancel request
    static void HandleKeystoneCancel(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player)
            return;

        HandleKeystoneActivationCancel(player);
    }

    // Send Great Vault info
    void SendVaultInfo(Player* player, bool openWindow)
    {
        uint32 guidLow = player->GetGUID().GetCounter();
        uint32 seasonId = sMythicRuns->GetCurrentSeasonId();

        constexpr uint32 SECONDS_PER_WEEK = 7u * 24u * 60u * 60u;

        // Retail-like grace window:
        // - show claimable rewards from LAST week
        // - show current-week progress separately
        uint32 progressWeekStart = sMythicRuns->GetWeekStartTimestamp();
        uint32 progressWeekEnd = progressWeekStart + SECONDS_PER_WEEK;
        uint32 nextWeekStart = progressWeekEnd;

        uint32 claimWeekStart = progressWeekStart >= SECONDS_PER_WEEK ? (progressWeekStart - SECONDS_PER_WEEK) : 0;
        uint32 claimWeekEnd = claimWeekStart + SECONDS_PER_WEEK;

        auto CountBits32 = [](uint32 value) -> uint32
        {
            uint32 count = 0;
            while (value)
            {
                value &= (value - 1);
                ++count;
            }
            return count;
        };

        auto GetMPlusLevelsForWeek = [&](uint32 weekStart, uint32 weekEnd) -> std::vector<uint8>
        {
            std::vector<uint8> levels;
            if (QueryResult runsResult = CharacterDatabase.Query(
                "SELECT keystone_level FROM dc_mplus_runs "
                "WHERE character_guid = {} AND season_id = {} AND success = 1 "
                "AND completed_at >= FROM_UNIXTIME({}) AND completed_at < FROM_UNIXTIME({}) "
                "ORDER BY keystone_level DESC LIMIT 8",
                guidLow, seasonId, weekStart, weekEnd))
            {
                do
                {
                    levels.push_back((*runsResult)[0].Get<uint8>());
                } while (runsResult->NextRow());
            }
            return levels;
        };

        auto GetRaidBossesForWeek = [&](uint32 weekStart, uint32 weekEnd) -> uint32
        {
            uint32 raidBosses = 0;
            if (QueryResult raidRes = CharacterDatabase.Query(
                "SELECT i.map, i.completedEncounters "
                "FROM character_instance ci "
                "JOIN instance i ON i.id = ci.instance "
                "WHERE ci.guid = {} AND i.resettime >= {} AND i.resettime < {}",
                guidLow, weekStart, weekEnd))
            {
                do
                {
                    Field* fields = raidRes->Fetch();
                    uint32 mapId = fields[0].Get<uint32>();
                    uint32 completedEncounters = fields[1].Get<uint32>();

                    MapEntry const* mapEntry = sMapStore.LookupEntry(mapId);
                    if (!mapEntry || !mapEntry->IsRaid())
                        continue;

                    raidBosses += CountBits32(completedEncounters);
                } while (raidRes->NextRow());
            }
            return raidBosses;
        };

        auto GetPvpWinsForWeek = [&](uint32 weekStart, uint32 weekEnd) -> uint32
        {
            uint32 pvpWins = 0;
            if (QueryResult pvpRes = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM pvpstats_players p "
                "JOIN pvpstats_battlegrounds b ON b.id = p.battleground_id "
                "WHERE p.character_guid = {} AND p.winner = 1 "
                "AND b.date >= FROM_UNIXTIME({}) AND b.date < FROM_UNIXTIME({})",
                guidLow, weekStart, weekEnd))
            {
                pvpWins = (*pvpRes)[0].Get<uint32>();
            }
            return pvpWins;
        };

        struct RecentRunEntry
        {
            uint16 mapId = 0;
            uint8 keystoneLevel = 0;
            uint32 completionTime = 0;
            bool success = false;
            uint32 completedAt = 0;
            std::string mapName;
        };

        std::vector<RecentRunEntry> recentRuns;
        if (QueryResult runHistoryResult = CharacterDatabase.Query(
            "SELECT map_id, keystone_level, COALESCE(completion_time, 0), success, UNIX_TIMESTAMP(completed_at) "
            "FROM dc_mplus_runs "
            "WHERE character_guid = {} AND season_id = {} "
            "ORDER BY completed_at DESC, run_id DESC "
            "LIMIT 9",
            guidLow, seasonId))
        {
            do
            {
                Field* fields = runHistoryResult->Fetch();
                RecentRunEntry run;
                run.mapId = fields[0].Get<uint16>();
                run.keystoneLevel = fields[1].Get<uint8>();
                run.completionTime = fields[2].Get<uint32>();
                run.success = fields[3].Get<uint8>() != 0;
                run.completedAt = fields[4].Get<uint32>();

                std::string runMapName = "Map " + std::to_string(run.mapId);
                if (MapEntry const* mapEntry = sMapStore.LookupEntry(run.mapId))
                {
                    char const* dbMapName = mapEntry->name[0];
                    if (dbMapName && dbMapName[0] != '\0')
                        runMapName = dbMapName;
                }

                run.mapName = runMapName;
                recentRuns.push_back(run);
            } while (runHistoryResult->NextRow());
        }

        // Claim state applies to CLAIM WEEK.
        bool claimed = false;
        uint8 claimedSlot = 0;
        if (claimWeekStart != 0)
        {
            CharacterDatabase.DirectExecute(
                "INSERT IGNORE INTO dc_weekly_vault (character_guid, season_id, week_start) VALUES ({}, {}, {})",
                guidLow, seasonId, claimWeekStart);

            if (QueryResult claimResult = CharacterDatabase.Query(
                "SELECT reward_claimed, claimed_slot FROM dc_weekly_vault WHERE character_guid = {} AND season_id = {} AND week_start = {}",
                guidLow, seasonId, claimWeekStart))
            {
                Field* fields = claimResult->Fetch();
                claimed = fields[0].Get<bool>();
                claimedSlot = fields[1].Get<uint8>();
            }
        }

        // Mythic+ stats
        std::vector<uint8> mplusLevelsProgress = GetMPlusLevelsForWeek(progressWeekStart, progressWeekEnd);
        uint8 mplusRunsProgress = static_cast<uint8>(mplusLevelsProgress.size());
        uint8 mplusHighest = mplusRunsProgress > 0 ? mplusLevelsProgress[0] : 0;

        uint8 mplusSlotLevelProgress[4] = { 0, 0, 0, 0 };
        if (mplusLevelsProgress.size() >= 1)
            mplusSlotLevelProgress[1] = mplusLevelsProgress[0];
        if (mplusLevelsProgress.size() >= 4)
            mplusSlotLevelProgress[2] = mplusLevelsProgress[3];
        if (mplusLevelsProgress.size() >= 8)
            mplusSlotLevelProgress[3] = mplusLevelsProgress[7];

        std::vector<uint8> mplusLevelsClaim = claimWeekStart != 0 ? GetMPlusLevelsForWeek(claimWeekStart, claimWeekEnd) : std::vector<uint8>();
        uint8 mplusRunsClaim = static_cast<uint8>(mplusLevelsClaim.size());

        auto mplusThreshold = [&](uint8 slotInTrack) -> uint8 { return sMythicRuns->GetVaultThreshold(slotInTrack); };
        auto mplusUnlockedProgress = [&](uint8 slotInTrack) -> bool { return mplusRunsProgress >= mplusThreshold(slotInTrack); };
        auto mplusUnlockedClaim = [&](uint8 slotInTrack) -> bool { return mplusRunsClaim >= mplusThreshold(slotInTrack); };

        // Raid stats
        uint32 raidBossesProgress = GetRaidBossesForWeek(progressWeekStart, progressWeekEnd);
        uint32 raidBossesClaim = claimWeekStart != 0 ? GetRaidBossesForWeek(claimWeekStart, claimWeekEnd) : 0;

        auto raidThreshold = [&](uint8 slotInTrack) -> uint32
        {
            if (slotInTrack == 1)
                return sConfigMgr->GetOption<uint32>("MythicPlus.Vault.Raid.Threshold1", 2);
            if (slotInTrack == 2)
                return sConfigMgr->GetOption<uint32>("MythicPlus.Vault.Raid.Threshold2", 4);
            return sConfigMgr->GetOption<uint32>("MythicPlus.Vault.Raid.Threshold3", 6);
        };

        auto raidUnlockedProgress = [&](uint8 slotInTrack) -> bool { return raidBossesProgress >= raidThreshold(slotInTrack); };
        auto raidUnlockedClaim = [&](uint8 slotInTrack) -> bool { return raidBossesClaim >= raidThreshold(slotInTrack); };

        // PvP stats
        uint32 pvpWinsProgress = GetPvpWinsForWeek(progressWeekStart, progressWeekEnd);
        uint32 pvpWinsClaim = claimWeekStart != 0 ? GetPvpWinsForWeek(claimWeekStart, claimWeekEnd) : 0;

        auto pvpThreshold = [&](uint8 slotInTrack) -> uint32
        {
            if (slotInTrack == 1)
                return sConfigMgr->GetOption<uint32>("MythicPlus.Vault.PvP.Threshold1", 1);
            if (slotInTrack == 2)
                return sConfigMgr->GetOption<uint32>("MythicPlus.Vault.PvP.Threshold2", 4);
            return sConfigMgr->GetOption<uint32>("MythicPlus.Vault.PvP.Threshold3", 8);
        };

        auto pvpUnlockedProgress = [&](uint8 slotInTrack) -> bool { return pvpWinsProgress >= pvpThreshold(slotInTrack); };
        auto pvpUnlockedClaim = [&](uint8 slotInTrack) -> bool { return pvpWinsClaim >= pvpThreshold(slotInTrack); };

        uint32 raidForecastIlvl = sConfigMgr->GetOption<uint32>("MythicPlus.Vault.Raid.ItemLevel", 264);
        uint32 pvpForecastIlvl = sConfigMgr->GetOption<uint32>("MythicPlus.Vault.PvP.ItemLevel", 264);

        auto mplusForecastIlvl = [&](uint8 slotInTrack) -> uint32
        {
            uint8 keyLevel = mplusSlotLevelProgress[slotInTrack];
            if (keyLevel == 0)
                return 0;

            // Keep in sync with GreatVault reward generation logic.
            return 200u + (static_cast<uint32>(keyLevel) * 3u);
        };

        // Generate claim-week rewards lazily on open (idempotent generation).
        uint32 unlockedCountClaim = 0;
        for (uint8 i = 1; i <= 3; ++i)
        {
            if (raidUnlockedClaim(i)) ++unlockedCountClaim;
            if (mplusUnlockedClaim(i)) ++unlockedCountClaim;
            if (pvpUnlockedClaim(i)) ++unlockedCountClaim;
        }

        if (claimWeekStart != 0 && !claimed && unlockedCountClaim > 0)
        {
            sMythicRuns->GenerateVaultRewardPool(guidLow, seasonId, claimWeekStart);
        }

        // Claim-week reward pool
        std::unordered_map<uint8, std::pair<uint32, uint32>> rewardBySlot;
        if (claimWeekStart != 0)
        {
            auto rewards = sMythicRuns->GetVaultRewardPool(guidLow, seasonId, claimWeekStart);
            for (auto const& [slotIndex, itemId, itemLevel] : rewards)
                rewardBySlot[slotIndex] = { itemId, itemLevel };
        }

        auto MakeClaimSlotObj = [&](uint8 globalSlot, uint8 slotInTrack, uint32 threshold, uint32 progress, bool isUnlocked) -> JsonValue
        {
            JsonValue slotObj;
            slotObj.SetObject();
            slotObj.Set("id", slotInTrack);
            slotObj.Set("globalId", globalSlot);
            slotObj.Set("threshold", static_cast<int32>(threshold));
            slotObj.Set("progress", static_cast<int32>(progress));

            if (claimed && claimedSlot == globalSlot)
            {
                slotObj.Set("status", "claimed");
            }
            else if (isUnlocked)
            {
                slotObj.Set("status", "unlocked");
                JsonValue rewardsArr;
                rewardsArr.SetArray();

                auto itr = rewardBySlot.find(globalSlot);
                if (itr != rewardBySlot.end())
                {
                    JsonValue rewardObj;
                    rewardObj.SetObject();
                    rewardObj.Set("itemId", itr->second.first);
                    rewardObj.Set("ilvl", static_cast<int32>(itr->second.second));
                    rewardsArr.Push(rewardObj);
                }

                slotObj.Set("rewards", rewardsArr);
            }
            else
            {
                slotObj.Set("status", "locked");
            }

            return slotObj;
        };

        auto MakeProgressSlotObj = [&](uint8 globalSlot, uint8 slotInTrack, uint32 threshold, uint32 progress, bool isUnlocked) -> JsonValue
        {
            JsonValue slotObj;
            slotObj.SetObject();
            slotObj.Set("id", slotInTrack);
            slotObj.Set("globalId", globalSlot);
            slotObj.Set("threshold", static_cast<int32>(threshold));
            slotObj.Set("progress", static_cast<int32>(progress));

            if (isUnlocked)
            {
                slotObj.Set("status", "unlocked");
                JsonValue rewardsArr;
                rewardsArr.SetArray();
                slotObj.Set("rewards", rewardsArr);
            }
            else
            {
                slotObj.Set("status", "locked");
            }

            return slotObj;
        };

        auto MakeForecastSlotObj = [&](uint8 globalSlot, uint8 slotInTrack, uint32 threshold, uint32 progress, bool isUnlocked, uint32 forecastIlvl, uint32 sourceKeyLevel) -> JsonValue
        {
            JsonValue slotObj;
            slotObj.SetObject();
            slotObj.Set("id", slotInTrack);
            slotObj.Set("globalId", globalSlot);
            slotObj.Set("threshold", static_cast<int32>(threshold));
            slotObj.Set("progress", static_cast<int32>(progress));

            if (isUnlocked)
            {
                slotObj.Set("status", "forecast");
                if (forecastIlvl > 0)
                    slotObj.Set("forecastIlvl", static_cast<int32>(forecastIlvl));
                if (sourceKeyLevel > 0)
                    slotObj.Set("sourceKeyLevel", static_cast<int32>(sourceKeyLevel));
            }
            else
            {
                slotObj.Set("status", "locked");
            }

            return slotObj;
        };

        auto MakeHistorySlotObj = [&](uint8 globalSlot, uint8 slotInTrack, RecentRunEntry const* run) -> JsonValue
        {
            JsonValue slotObj;
            slotObj.SetObject();
            slotObj.Set("id", slotInTrack);
            slotObj.Set("globalId", globalSlot);

            if (!run)
            {
                slotObj.Set("status", "empty");
                return slotObj;
            }

            slotObj.Set("status", "history");
            slotObj.Set("mapId", static_cast<int32>(run->mapId));
            slotObj.Set("mapName", run->mapName);
            slotObj.Set("keystoneLevel", static_cast<int32>(run->keystoneLevel));
            slotObj.Set("completionTime", static_cast<int32>(run->completionTime));
            slotObj.Set("success", run->success);
            slotObj.Set("completedAt", static_cast<int32>(run->completedAt));
            return slotObj;
        };

        auto BuildTracks = [&](bool claimWeek) -> JsonValue
        {
            JsonValue tracksArr;
            tracksArr.SetArray();

            // Raid track (global slots 1-3)
            {
                JsonValue trackObj;
                trackObj.SetObject();
                trackObj.Set("id", "raid");
                trackObj.Set("name", "Raid");

                JsonValue slotsArr;
                slotsArr.SetArray();
                for (uint8 i = 1; i <= 3; ++i)
                {
                    uint8 globalSlot = static_cast<uint8>(0 * 3 + i);
                    uint32 threshold = raidThreshold(i);
                    uint32 progress = claimWeek ? raidBossesClaim : raidBossesProgress;
                    bool unlocked = claimWeek ? raidUnlockedClaim(i) : raidUnlockedProgress(i);
                    slotsArr.Push(claimWeek ? MakeClaimSlotObj(globalSlot, i, threshold, progress, unlocked)
                                            : MakeProgressSlotObj(globalSlot, i, threshold, progress, unlocked));
                }

                trackObj.Set("slots", slotsArr);
                tracksArr.Push(trackObj);
            }

            // Mythic+ track (global slots 4-6)
            {
                JsonValue trackObj;
                trackObj.SetObject();
                trackObj.Set("id", "mplus");
                trackObj.Set("name", "Mythic+");

                JsonValue slotsArr;
                slotsArr.SetArray();
                for (uint8 i = 1; i <= 3; ++i)
                {
                    uint8 globalSlot = static_cast<uint8>(1 * 3 + i);
                    uint32 threshold = mplusThreshold(i);
                    uint32 progress = claimWeek ? mplusRunsClaim : mplusRunsProgress;
                    bool unlocked = claimWeek ? mplusUnlockedClaim(i) : mplusUnlockedProgress(i);
                    slotsArr.Push(claimWeek ? MakeClaimSlotObj(globalSlot, i, threshold, progress, unlocked)
                                            : MakeProgressSlotObj(globalSlot, i, threshold, progress, unlocked));
                }

                trackObj.Set("slots", slotsArr);
                tracksArr.Push(trackObj);
            }

            // PvP track (global slots 7-9)
            {
                JsonValue trackObj;
                trackObj.SetObject();
                trackObj.Set("id", "pvp");
                trackObj.Set("name", "PvP");

                JsonValue slotsArr;
                slotsArr.SetArray();
                for (uint8 i = 1; i <= 3; ++i)
                {
                    uint8 globalSlot = static_cast<uint8>(2 * 3 + i);
                    uint32 threshold = pvpThreshold(i);
                    uint32 progress = claimWeek ? pvpWinsClaim : pvpWinsProgress;
                    bool unlocked = claimWeek ? pvpUnlockedClaim(i) : pvpUnlockedProgress(i);
                    slotsArr.Push(claimWeek ? MakeClaimSlotObj(globalSlot, i, threshold, progress, unlocked)
                                            : MakeProgressSlotObj(globalSlot, i, threshold, progress, unlocked));
                }

                trackObj.Set("slots", slotsArr);
                tracksArr.Push(trackObj);
            }

            return tracksArr;
        };

        auto BuildForecastTracks = [&]() -> JsonValue
        {
            JsonValue tracksArr;
            tracksArr.SetArray();

            // Raid track (global slots 1-3)
            {
                JsonValue trackObj;
                trackObj.SetObject();
                trackObj.Set("id", "raid");
                trackObj.Set("name", "Raid");

                JsonValue slotsArr;
                slotsArr.SetArray();
                for (uint8 i = 1; i <= 3; ++i)
                {
                    uint8 globalSlot = static_cast<uint8>(0 * 3 + i);
                    uint32 threshold = raidThreshold(i);
                    uint32 progress = raidBossesProgress;
                    bool unlocked = raidUnlockedProgress(i);
                    uint32 forecastIlvl = unlocked ? raidForecastIlvl : 0;
                    slotsArr.Push(MakeForecastSlotObj(globalSlot, i, threshold, progress, unlocked, forecastIlvl, 0));
                }

                trackObj.Set("slots", slotsArr);
                tracksArr.Push(trackObj);
            }

            // Mythic+ track (global slots 4-6)
            {
                JsonValue trackObj;
                trackObj.SetObject();
                trackObj.Set("id", "mplus");
                trackObj.Set("name", "Mythic+");

                JsonValue slotsArr;
                slotsArr.SetArray();
                for (uint8 i = 1; i <= 3; ++i)
                {
                    uint8 globalSlot = static_cast<uint8>(1 * 3 + i);
                    uint32 threshold = mplusThreshold(i);
                    uint32 progress = mplusRunsProgress;
                    bool unlocked = mplusUnlockedProgress(i);
                    uint32 sourceKeyLevel = mplusSlotLevelProgress[i];
                    uint32 forecastIlvl = unlocked ? mplusForecastIlvl(i) : 0;
                    slotsArr.Push(MakeForecastSlotObj(globalSlot, i, threshold, progress, unlocked, forecastIlvl, sourceKeyLevel));
                }

                trackObj.Set("slots", slotsArr);
                tracksArr.Push(trackObj);
            }

            // PvP track (global slots 7-9)
            {
                JsonValue trackObj;
                trackObj.SetObject();
                trackObj.Set("id", "pvp");
                trackObj.Set("name", "PvP");

                JsonValue slotsArr;
                slotsArr.SetArray();
                for (uint8 i = 1; i <= 3; ++i)
                {
                    uint8 globalSlot = static_cast<uint8>(2 * 3 + i);
                    uint32 threshold = pvpThreshold(i);
                    uint32 progress = pvpWinsProgress;
                    bool unlocked = pvpUnlockedProgress(i);
                    uint32 forecastIlvl = unlocked ? pvpForecastIlvl : 0;
                    slotsArr.Push(MakeForecastSlotObj(globalSlot, i, threshold, progress, unlocked, forecastIlvl, 0));
                }

                trackObj.Set("slots", slotsArr);
                tracksArr.Push(trackObj);
            }

            return tracksArr;
        };

        auto BuildHistoryTracks = [&]() -> JsonValue
        {
            JsonValue tracksArr;
            tracksArr.SetArray();

            JsonValue trackObj;
            trackObj.SetObject();
            trackObj.Set("id", "history");
            trackObj.Set("name", "Latest Runs");

            JsonValue slotsArr;
            slotsArr.SetArray();

            for (uint8 slotInTrack = 1; slotInTrack <= 3; ++slotInTrack)
            {
                uint8 globalSlot = slotInTrack;
                std::size_t const runIndex = static_cast<std::size_t>(slotInTrack - 1);
                RecentRunEntry const* run = runIndex < recentRuns.size()
                    ? &recentRuns[runIndex]
                    : nullptr;
                slotsArr.Push(MakeHistorySlotObj(globalSlot, slotInTrack, run));
            }

            trackObj.Set("slots", slotsArr);
            tracksArr.Push(trackObj);

            return tracksArr;
        };

        JsonValue claimTracks = BuildTracks(true);
        JsonValue progressTracks = BuildTracks(false);
        JsonValue nextWeekTracks = BuildForecastTracks();
        JsonValue historyTracks = BuildHistoryTracks();

        bool claimAvailable = (unlockedCountClaim > 0) && (!claimed);

        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_VAULT_INFO)
            // Backward compatibility: top-level fields represent CLAIM WEEK.
            .Set("claimed", claimed)
            .Set("claimedSlot", static_cast<int32>(claimedSlot))
            .Set("highestLevel", static_cast<int32>(mplusHighest))
            .Set("tracks", claimTracks)
            .Set("progressTracks", progressTracks)
            .Set("nextWeekTracks", nextWeekTracks)
            .Set("historyTracks", historyTracks)
            .Set("claimWeekStart", static_cast<int32>(claimWeekStart))
            .Set("progressWeekStart", static_cast<int32>(progressWeekStart))
            .Set("nextWeekStart", static_cast<int32>(nextWeekStart))
            .Set("defaultView", claimAvailable ? "claim" : "progress")
            .Set("open", openWindow)
            .Send(player);
    }

    void SendOpenVault(Player* player)
    {
        SendVaultInfo(player, true);
    }

    // Handler: Get vault info
    static void HandleGetVaultInfo(Player* player, const ParsedMessage& /*msg*/)
    {
        SendVaultInfo(player, false);
    }

    // Handler: Claim vault reward
    static void HandleClaimVaultReward(Player* player, const ParsedMessage& msg)
    {
        if (msg.GetDataCount() < 2)
            return;

        uint8 slot = static_cast<uint8>(msg.GetUInt32(0));
        uint32 itemId = msg.GetUInt32(1);

        bool success = sMythicRuns->ClaimVaultItemReward(player, slot, itemId);

        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_CLAIM_VAULT_RESULT)
            .Set("success", success)
            .Set("slot", slot)
            .Set("itemId", itemId)
            .Send(player);

        if (success)
        {
            SendVaultInfo(player); // Refresh info
        }
    }

    // Forward declaration for HUD handler (defined later)
    static void HandleRequestHud(Player* player, const ParsedMessage& msg);

    // Register all handlers
    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_KEY_INFO, HandleGetKeyInfo);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_AFFIXES, HandleGetAffixes);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_BEST_RUNS, HandleGetBestRuns);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_KEYSTONE_LIST, HandleGetKeystoneList);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_REQUEST_HUD, HandleRequestHud);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_GET_VAULT_INFO, HandleGetVaultInfo);
        DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_CLAIM_VAULT_REWARD, HandleClaimVaultReward);

        if (sConfigMgr->GetOption<bool>("DC.AddonProtocol.MythicPlus.Enable", true))
        {
            DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_KEYSTONE_RESPONSE,
                HandleKeystoneResponse);
            DC_REGISTER_HANDLER(Module::MYTHIC_PLUS, Opcode::MPlus::CMSG_KEYSTONE_CANCEL,
                HandleKeystoneCancel);
        }

        LOG_INFO("dc.addon", "Mythic+ module handlers registered (includes HUD cache manager)");
    }

    // Broadcast run update to all party members
    void BroadcastRunUpdate(uint32 /*runId*/, uint32 /*elapsed*/, uint32 /*remaining*/,
                           uint32 /*deaths*/, uint32 /*bossesKilled*/, uint32 /*bossesTotal*/,
                           uint32 /*enemiesKilled*/, bool /*failed*/, bool /*completed*/)
    {
        // This would be called from MythicPlusRunManager
        // Get all players in the run and send updates

        // For now, placeholder - actual implementation needs RunManager integration
    }

    // Send HUD update to player (pipe-delimited)
    void SendHUDUpdate(Player* player, const std::string& jsonData)
    {
        SendHudSnapshot(player, jsonData);
    }

    // ========================================================================
    // HUD CACHE MANAGER - Migrated from DCMythicPlusHUD.lua
    // ========================================================================

    class HudCacheMgr
    {
    private:
        struct CacheEntry
        {
            std::string payload;
            uint64 updatedAt;
            uint64 instanceKey;
        };

        struct PlayerSnapshot
        {
            uint64 instanceKey = 0;
            uint64 lastUpdated = 0;
            std::string idleReason;
        };

        std::unordered_map<uint64, CacheEntry> m_cache;
        std::unordered_map<uint32, PlayerSnapshot> m_playerSnapshots;  // playerGuid -> snapshot
        std::unordered_map<uint64, time_t> m_missingKeys;  // backoff tracking
        std::unordered_map<uint64, time_t> m_cacheValidation;  // cache key -> last DB validation
        uint64 m_lastSeenUpdate = 0;
        bool m_tableEnsured = false;
        bool m_queryInFlight = false;
        std::optional<QueryCallback> m_pendingQuery;

        static constexpr char const* HUD_CACHE_TABLE = "dc_mplus_hud_cache";
        static constexpr uint32 POLL_INTERVAL_MS = 1000;
        static constexpr uint64 INSTANCE_KEY_FACTOR = 4294967296ULL;  // 2^32
        static constexpr uint32 BACKOFF_SECONDS = 2;
        static constexpr uint32 CACHE_REVALIDATE_SECONDS = 2;

        HudCacheMgr() = default;

        void EnsureTable()
        {
            if (m_tableEnsured)
                return;

            CharacterDatabase.DirectExecute(
                "CREATE TABLE IF NOT EXISTS `{}` ("
                "  `instance_key` BIGINT UNSIGNED NOT NULL,"
                "  `map_id` INT UNSIGNED NOT NULL,"
                "  `instance_id` INT UNSIGNED NOT NULL,"
                "  `owner_guid` INT UNSIGNED NOT NULL,"
                "  `keystone_level` TINYINT UNSIGNED NOT NULL,"
                "  `season_id` INT UNSIGNED NOT NULL,"
                "  `payload` LONGTEXT NOT NULL,"
                "  `updated_at` BIGINT UNSIGNED NOT NULL,"
                "  PRIMARY KEY (`instance_key`)"
                ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
                HUD_CACHE_TABLE);

            m_tableEnsured = true;
            LOG_INFO("dc.addon.mplus", "HudCacheMgr: Table `{}` ensured", HUD_CACHE_TABLE);
        }

        uint64 MakeInstanceKey(Player* player) const
        {
            if (!player || !player->IsInWorld())
                return 0;

            uint32 mapId = player->GetMapId();
            uint32 instanceId = player->GetInstanceId();

            if (instanceId == 0)
                return 0;

            Map* map = player->GetMap();
            if (!map || (!map->IsDungeon() && !map->IsRaid()))
                return 0;

            return static_cast<uint64>(mapId) * INSTANCE_KEY_FACTOR + instanceId;
        }

        void SendIdle(Player* player, const std::string& reason)
        {
            if (!player)
                return;

            uint32 guid = player->GetGUID().GetCounter();
            PlayerSnapshot& prev = m_playerSnapshots[guid];

            if (prev.idleReason == reason)
                return;  // Already sent this idle reason

            JsonValue payload;
            payload.SetObject();
            payload.Set("op", "idle");
            payload.Set("reason", reason);
            SendHudSnapshot(player, payload.Encode());

            prev.idleReason = reason;
            prev.instanceKey = 0;
            prev.lastUpdated = 0;
        }

        void StoreSnapshot(uint32 playerGuid, uint64 instanceKey, uint64 updatedAt)
        {
            PlayerSnapshot& snap = m_playerSnapshots[playerGuid];
            snap.instanceKey = instanceKey;
            snap.lastUpdated = updatedAt;
            snap.idleReason.clear();
        }

        bool SendPayload(Player* player, const CacheEntry& record)
        {
            if (!player || record.payload.empty())
                return false;

            SendHudSnapshot(player, record.payload);

            StoreSnapshot(player->GetGUID().GetCounter(), record.instanceKey, record.updatedAt);
            return true;
        }

        bool CacheMissBackoff(uint64 instanceKey)
        {
            time_t now = time(nullptr);
            auto it = m_missingKeys.find(instanceKey);

            if (it != m_missingKeys.end() && (now - it->second) < BACKOFF_SECONDS)
                return true;  // Still in backoff

            m_missingKeys[instanceKey] = now;
            return false;
        }

        CacheEntry* FetchSnapshot(uint64 instanceKey, bool forceValidate = false)
        {
            if (instanceKey == 0)
                return nullptr;

            time_t now = time(nullptr);

            // Check cache first
            auto it = m_cache.find(instanceKey);
            if (it != m_cache.end())
            {
                bool shouldValidate = forceValidate;
                if (!shouldValidate)
                {
                    auto validateIt = m_cacheValidation.find(instanceKey);
                    if (validateIt == m_cacheValidation.end() ||
                        (now - validateIt->second) >= CACHE_REVALIDATE_SECONDS)
                    {
                        shouldValidate = true;
                    }
                }

                if (!shouldValidate)
                    return &it->second;

                m_cacheValidation[instanceKey] = now;
                EnsureTable();

                QueryResult result = CharacterDatabase.Query(
                    "SELECT payload, updated_at FROM `{}` WHERE instance_key = {} LIMIT 1",
                    HUD_CACHE_TABLE, instanceKey);

                if (!result)
                {
                    m_cache.erase(it);
                    m_missingKeys[instanceKey] = now;
                    return nullptr;
                }

                Field* fields = result->Fetch();
                std::string payload = fields[0].Get<std::string>();
                uint64 updated = fields[1].Get<uint64>();

                if (payload.empty())
                {
                    m_cache.erase(it);
                    m_missingKeys[instanceKey] = now;
                    return nullptr;
                }

                it = m_cache.find(instanceKey);
                if (it == m_cache.end())
                    return nullptr;

                it->second.payload = payload;
                it->second.updatedAt = updated;
                it->second.instanceKey = instanceKey;

                if (updated > m_lastSeenUpdate)
                    m_lastSeenUpdate = updated;

                m_missingKeys.erase(instanceKey);
                return &it->second;
            }

            // Check backoff
            if (CacheMissBackoff(instanceKey))
                return nullptr;

            EnsureTable();

            // Query database
            QueryResult result = CharacterDatabase.Query(
                "SELECT payload, updated_at FROM `{}` WHERE instance_key = {} LIMIT 1",
                HUD_CACHE_TABLE, instanceKey);

            if (!result)
                return nullptr;

            Field* fields = result->Fetch();
            std::string payload = fields[0].Get<std::string>();
            uint64 updated = fields[1].Get<uint64>();

            if (payload.empty())
                return nullptr;

            // Cache it
            CacheEntry& entry = m_cache[instanceKey];
            entry.payload = payload;
            entry.updatedAt = updated;
            entry.instanceKey = instanceKey;

            if (updated > m_lastSeenUpdate)
                m_lastSeenUpdate = updated;

            m_cacheValidation[instanceKey] = now;
            m_missingKeys.erase(instanceKey);
            return &entry;
        }

        void ApplyCacheQueryResult(QueryResult result)
        {
            m_queryInFlight = false;

            if (!result)
                return;

            do
            {
                Field* fields = result->Fetch();
                uint64 key = fields[0].Get<uint64>();
                std::string payload = fields[1].Get<std::string>();
                uint64 updated = fields[2].Get<uint64>();

                if (key > 0 && !payload.empty())
                {
                    CacheEntry& entry = m_cache[key];
                    entry.payload = payload;
                    entry.updatedAt = updated;
                    entry.instanceKey = key;

                    if (updated > m_lastSeenUpdate)
                        m_lastSeenUpdate = updated;

                    m_missingKeys.erase(key);
                    m_cacheValidation[key] = time(nullptr);
                }
            } while (result->NextRow());
        }

        void PullCacheUpdates()
        {
            EnsureTable();

            if (m_queryInFlight)
                return;

            m_queryInFlight = true;
            std::string sql = Acore::StringFormat(
                "SELECT instance_key, payload, updated_at FROM `{}` WHERE updated_at > {} ORDER BY updated_at",
                HUD_CACHE_TABLE, m_lastSeenUpdate);
            m_pendingQuery.emplace(
                CharacterDatabase.AsyncQuery(sql)
                .WithCallback([this](QueryResult result)
                {
                    ApplyCacheQueryResult(std::move(result));
                }));
        }

        void ProcessPendingQuery()
        {
            if (m_pendingQuery && m_pendingQuery->InvokeIfReady())
                m_pendingQuery.reset();
        }

        bool DeliverSnapshot(Player* player, bool force = false, const std::string& reason = "")
        {
            uint64 instanceKey = MakeInstanceKey(player);

            if (instanceKey == 0)
            {
                SendIdle(player, reason.empty() ? "not_in_mythic" : reason);
                return false;
            }

            CacheEntry* record = FetchSnapshot(instanceKey, force);
            if (!record)
            {
                SendIdle(player, "no_snapshot");
                return false;
            }

            uint32 guid = player->GetGUID().GetCounter();
            PlayerSnapshot& previous = m_playerSnapshots[guid];

            if (!force && previous.instanceKey == instanceKey && previous.lastUpdated == record->updatedAt)
                return true;  // Already sent, no changes

            return SendPayload(player, *record);
        }

    public:
        static HudCacheMgr& Instance()
        {
            static HudCacheMgr instance;
            return instance;
        }

        // Main update loop (called periodically)
        void Update()
        {
            ProcessPendingQuery();
            PullCacheUpdates();

            // Iterate all online players
            auto const& sessions = sWorldSessionMgr->GetAllSessions();
            for (auto const& pair : sessions)
            {
                if (WorldSession* session = pair.second)
                {
                    if (Player* player = session->GetPlayer())
                    {
                        if (player->IsInWorld())
                            DeliverSnapshot(player);
                    }
                }
            }
        }

        // Client-requested snapshot (force refresh)
        void RequestHud(Player* player, const std::string& reason = "client")
        {
            DeliverSnapshot(player, true, reason);
        }

        // Clear cache (for instance resets)
        void ClearCache()
        {
            m_cache.clear();
            m_missingKeys.clear();
            m_cacheValidation.clear();
            LOG_INFO("dc.addon.mplus", "HudCacheMgr: Cache cleared");
        }

        // Clear player snapshot on logout
        void OnPlayerLogout(Player* player)
        {
            if (!player)
                return;

            uint32 guid = player->GetGUID().GetCounter();
            m_playerSnapshots.erase(guid);
        }
    };

    // Handler: Client requests HUD snapshot
    static void HandleRequestHud(Player* player, const ParsedMessage& msg)
    {
        std::string reason = msg.GetString(0);
        if (reason.empty())
            reason = "client_request";

        HudCacheMgr::Instance().RequestHud(player, reason);

        if (reason == "register" || reason == "PLAYER_LOGIN" ||
            reason == "PLAYER_ENTERING_WORLD")
        {
            SendVaultAvailableNotification(player);
        }
    }

    static void HandleNativeHudRequest(Player* player,
        std::string const& reasonValue)
    {
        std::string reason = reasonValue;
        if (reason.empty())
            reason = "client_request";

        HudCacheMgr::Instance().RequestHud(player, reason);

        if (reason == "register" || reason == "PLAYER_LOGIN" ||
            reason == "PLAYER_ENTERING_WORLD")
        {
            SendVaultAvailableNotification(player);
        }
    }

    // ========================================================================
    // JSON HANDLERS - For complex data that benefits from structured format
    // ========================================================================

    // Send key info as JSON (more readable, easier to extend)
    void SendJsonKeyInfo(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();

        QueryResult result;
        if (HasCharacterDungeonTable())
        {
            result = CharacterDatabase.Query(
                "SELECT k.map_id, k.level, COALESCE(d.dungeon_name, '') "
                "FROM dc_mplus_keystones k "
                "LEFT JOIN dc_mplus_dungeons d ON k.map_id = d.map_id "
                "WHERE k.character_guid = {}",
                guid);
        }
        else
        {
            result = CharacterDatabase.Query(
                "SELECT map_id, level FROM dc_mplus_keystones WHERE character_guid = {}",
                guid);
        }

        if (result)
        {
            uint32 dungeonId = (*result)[0].Get<uint32>();
            uint32 level = (*result)[1].Get<uint32>();
            bool depleted = false;  // dc_mplus_keystones doesn't have depleted column

            // Get dungeon name
            std::string dungeonName = "Unknown";
            if (HasCharacterDungeonTable())
            {
                std::string const joinedName = (*result)[2].Get<std::string>();
                if (!joinedName.empty())
                    dungeonName = joinedName;
            }
            else
            {
                QueryResult nameResult = WorldDatabase.Query(
                    "SELECT dungeon_name FROM dc_mplus_dungeons WHERE dungeon_id = {}",
                    dungeonId);
                if (nameResult)
                    dungeonName = (*nameResult)[0].Get<std::string>();
            }

            JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_KEY_INFO)
                .Set("hasKey", true)
                .Set("dungeonId", dungeonId)
                .Set("dungeonName", dungeonName)
                .Set("level", level)
                .Set("depleted", depleted)
                .Send(player);
        }
        else
        {
            JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_KEY_INFO)
                .Set("hasKey", false)
                .Send(player);
        }
    }

    // Send affixes as JSON
    void SendJsonAffixes(Player* player)
    {
        // Calculate current week number
        uint32 weekStart = sMythicRuns->GetWeekStartTimestamp();
        uint32 weekNumber = (weekStart / (7 * 24 * 60 * 60)) % 52;

        JsonValue affixArray;
        affixArray.SetArray();

        if (sConfigMgr->GetOption<bool>("MythicPlus.Affixes.Enabled", false))
        {
            for (MythicPlusRunManager::WeeklyAffixInfo const& info : sMythicRuns->GetWeeklyAffixInfo(sMythicRuns->GetCurrentSeasonId()))
            {
                JsonValue affix;
                affix.SetObject();
                affix.Set("id", JsonValue(static_cast<int32>(info.affixId)));
                affix.Set("name", JsonValue(info.name));
                affix.Set("description", JsonValue(info.description));
                affixArray.Push(affix);
            }
        }

        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_AFFIXES)
            .Set("weekNumber", weekNumber)
            .Set("affixes", affixArray.Encode())
            .Send(player);
    }

    // Send best runs as JSON
    void SendJsonBestRuns(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();

        QueryResult result;
        if (HasCharacterDungeonTable())
        {
            result = CharacterDatabase.Query(
                "SELECT r.dungeon_id, r.level, r.completion_time, r.deaths, r.season, "
                "COALESCE(d.dungeon_name, '') "
                "FROM dc_mplus_best_runs r "
                "LEFT JOIN dc_mplus_dungeons d ON r.dungeon_id = d.map_id "
                "WHERE r.player_guid = {} ORDER BY r.level DESC LIMIT 10",
                guid);
        }
        else
        {
            result = CharacterDatabase.Query(
                "SELECT dungeon_id, level, completion_time, deaths, season "
                "FROM dc_mplus_best_runs WHERE player_guid = {} ORDER BY level DESC LIMIT 10",
                guid);
        }

        JsonValue runsArray;
        runsArray.SetArray();

        if (result)
        {
            do
            {
                JsonValue run;
                run.SetObject();
                run.Set("dungeonId", JsonValue((*result)[0].Get<int32>()));
                run.Set("level", JsonValue((*result)[1].Get<int32>()));
                run.Set("time", JsonValue((*result)[2].Get<int32>()));
                run.Set("deaths", JsonValue((*result)[3].Get<int32>()));
                run.Set("season", JsonValue((*result)[4].Get<int32>()));

                if (HasCharacterDungeonTable())
                {
                    std::string const joinedName = (*result)[5].Get<std::string>();
                    run.Set("dungeonName", JsonValue(
                        joinedName.empty() ? "Unknown" : joinedName));
                }
                else
                {
                    uint32 dungeonId = (*result)[0].Get<uint32>();
                    QueryResult nameResult = WorldDatabase.Query(
                        "SELECT dungeon_name FROM dc_mplus_dungeons WHERE dungeon_id = {}",
                        dungeonId);
                    if (nameResult)
                        run.Set("dungeonName", JsonValue((*nameResult)[0].Get<std::string>()));
                    else
                        run.Set("dungeonName", JsonValue("Unknown"));
                }

                runsArray.Push(run);
            } while (result->NextRow());
        }

        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_BEST_RUNS)
            .Set("runs", runsArray.Encode())
            .Set("count", static_cast<int32>(runsArray.Size()))
            .Send(player);
    }

    // Send run update as JSON (for HUD)
    void SendJsonRunUpdate(Player* player, uint32 runId, uint32 elapsed, uint32 remaining,
                           uint32 deaths, uint32 bossesKilled, uint32 bossesTotal,
                           uint32 enemyCount, uint32 enemyRequired, bool failed, bool completed)
    {
        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_TIMER_UPDATE)
            .Set("runId", runId)
            .Set("elapsed", elapsed)
            .Set("remaining", remaining)
            .Set("deaths", deaths)
            .Set("bossesKilled", bossesKilled)
            .Set("bossesTotal", bossesTotal)
            .Set("enemyCount", enemyCount)
            .Set("enemyRequired", enemyRequired)
            .Set("failed", failed)
            .Set("completed", completed)
            .Send(player);
    }

    // Send run start notification as JSON
    void SendJsonRunStart(Player* player, uint32 keyLevel, uint32 dungeonId,
                          const std::string& dungeonName, uint32 timeLimit,
                          const std::vector<uint32>& affixIds)
    {
        std::string affixListStr;
        for (size_t i = 0; i < affixIds.size(); ++i)
        {
            if (i > 0) affixListStr += ",";
            affixListStr += std::to_string(affixIds[i]);
        }

        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_RUN_START)
            .Set("keyLevel", keyLevel)
            .Set("dungeonId", dungeonId)
            .Set("dungeonName", dungeonName)
            .Set("timeLimit", timeLimit)
            .Set("affixes", affixListStr)
            .Send(player);
    }

    // Send run end notification as JSON
    void SendJsonRunEnd(Player* player, bool success, uint32 timeElapsed, int32 keyChange,
                        uint32 score, uint32 newKeyLevel)
    {
        JsonMessage(Module::MYTHIC_PLUS, Opcode::MPlus::SMSG_RUN_END)
            .Set("success", success)
            .Set("timeElapsed", timeElapsed)
            .Set("keyChange", keyChange)
            .Set("score", score)
            .Set("newKeyLevel", newKeyLevel)
            .Send(player);
    }

    // Helper to get current week number (for future weekly reset logic)
    [[maybe_unused]] static uint32 GetCurrentWeekNumber()
    {
        time_t now = time(nullptr);
        // Simple week calculation from epoch
        return static_cast<uint32>((now / 604800) % 52);
    }

}  // namespace MythicPlus
}  // namespace DCAddon

// Player script to auto-push the keystone list on login and handle logout
class MythicPlusKeystoneLoginPlayerScript : public PlayerScript
{
public:
    MythicPlusKeystoneLoginPlayerScript() : PlayerScript("MythicPlusKeystoneLoginPlayerScript") {}

    void OnPlayerLogin(Player* player) override
    {
        if (!player || !player->GetSession())
            return;
        // Send the canonical keystone list to the player
        DCAddon::MythicPlus::SendJsonKeystoneList(player);
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!player)
            return;
        // Clean up player's HUD snapshot
        DCAddon::MythicPlus::HudCacheMgr::Instance().OnPlayerLogout(player);
    }
};

// World script for HUD cache polling
class MythicPlusHudCacheWorldScript : public WorldScript
{
public:
    MythicPlusHudCacheWorldScript() : WorldScript("MythicPlusHudCacheWorldScript") {}

    void OnUpdate(uint32 /*diff*/) override
    {
        // Poll every 1 second
        static uint32 lastUpdate = 0;
        uint32 now = getMSTime();

        if (now - lastUpdate >= 1000)
        {
            DCAddon::MythicPlus::HudCacheMgr::Instance().Update();
            lastUpdate = now;
        }
    }
};

class MythicPlusHudNativeServerScript : public ServerScript
{
public:
    MythicPlusHudNativeServerScript()
        : ServerScript("MythicPlusHudNativeServerScript",
            { SERVERHOOK_CAN_PACKET_RECEIVE })
    {
    }

private:
    bool CanPacketReceive(WorldSession* session,
        WorldPacket const& packet) override
    {
        if (packet.GetOpcode() !=
            DCAddon::MythicPlus::BridgeOpcode::CMSG_REQUEST_HUD_SNAPSHOT)
            return true;

        if (!session)
            return false;

        Player* player = session->GetPlayer();
        if (!player || !player->IsInWorld())
            return false;

        std::string reason;
        if (packet.size() > 0)
        {
            WorldPacket nativePacket(packet);
            nativePacket.rpos(0);

            try
            {
                nativePacket >> reason;
            }
            catch (ByteBufferException const&)
            {
                reason.clear();
            }
        }

        DCAddon::MythicPlus::HandleNativeHudRequest(player, reason);
        return false;
    }
};

void AddSC_dc_addon_mythicplus()
{
    DCAddon::MythicPlus::RegisterHandlers();
    // Auto-push keystone list on login for connected players
    new MythicPlusKeystoneLoginPlayerScript();
    // Start HUD cache polling
    new MythicPlusHudCacheWorldScript();
    new MythicPlusHudNativeServerScript();
}
