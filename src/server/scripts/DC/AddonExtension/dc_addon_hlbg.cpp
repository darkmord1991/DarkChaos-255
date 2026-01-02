/*
 * Dark Chaos - Hinterland BG Unified Addon Handler
 *
 * Consolidated handler providing:
 * - Real-time BG status updates (queue, preparation, active, ended)
 * - Live resource tracking and objective updates
 * - Team scores, timers, and affix information
 * - Leaderboard data (seasonal player rankings - 7 types)
 * - Player personal stats (seasonal statistics)
 * - All-time career statistics
 * - Match end notifications with rewards
 *
 * Uses DCAddonProtocol for efficient binary + JSON communication.
 * Replaces old AIO-only handlers. Unified schema compatible.
 *
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "Scripting/ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "Config.h"
#include "Log.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"
#include "StringFormat.h"
#include "Common.h"
#include "dc_addon_namespace.h"
#include "OutdoorPvP/OutdoorPvPMgr.h"
#include "OutdoorPvP/OutdoorPvPHL.h"
#include "../HinterlandBG/HinterlandBGConstants.h"
#include "Time/GameTime.h"
#include <algorithm>
#include <cctype>
#include <ctime>
#include <iterator>
#include <map>
#include <sstream>
#include <string>
#include <tuple>
#include <unordered_map>
#include <vector>
#include "../CrossSystem/LeaderboardUtils.h"
#include "dc_addon_hlbg.h"

// Use shared utilities from LeaderboardUtils.h
using DarkChaos::Leaderboard::GetClassNameFromId;
using DarkChaos::Leaderboard::JsonEscape;

// Forward declarations for helpers defined later in this TU.
namespace HLBGAddonFallback {}

namespace DCAddon
{
namespace HLBG
{
    namespace
    {
        // Avoid expensive lookups and allow rate-limiting without extra dependencies.
        static std::unordered_map<uint32, uint32> s_lastRequestMs;

        static bool IsRateLimited(Player* player, uint32 cooldownMs)
        {
            if (!player)
                return true;

            uint32 now = GameTime::GetGameTimeMS().count();
            uint32 key = player->GetGUID().GetCounter();
            auto it = s_lastRequestMs.find(key);
            if (it != s_lastRequestMs.end() && (now - it->second) < cooldownMs)
                return true;
            s_lastRequestMs[key] = now;
            return false;
        }

        static OutdoorPvPHL* GetHL()
        {
            OutdoorPvP* opvp = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]);
            return opvp ? dynamic_cast<OutdoorPvPHL*>(opvp) : nullptr;
        }
    }

    // =====================================================================
    // ENUMS & STRUCTURES
    // =====================================================================

    // HLBGStatus enum moved to header

    // Client message opcodes
    // IMPORTANT: Keep aligned with DCAddonNamespace.h (DCAddon::Opcode::HLBG)
    enum ClientOpcodes : uint8
    {
        CMSG_REQUEST_STATUS         = 0x01,
        CMSG_REQUEST_RESOURCES      = 0x02,
        CMSG_REQUEST_OBJECTIVE      = 0x03,
        CMSG_QUICK_QUEUE            = 0x04,
        CMSG_LEAVE_QUEUE            = 0x05,
        CMSG_REQUEST_STATS          = 0x06,

        // Extended/legacy JSON requests (not part of the canonical HLBG opcode set).
        // Kept in a non-conflicting range to avoid overlap with the live BG opcodes.
        CMSG_GET_LEADERBOARD        = 0x20,
        CMSG_GET_PLAYER_STATS       = 0x21,
        CMSG_GET_ALLTIME_STATS      = 0x22,
        CMSG_REQUEST_HISTORY_UI     = 0x23,
    };

    // Server message opcodes
    // IMPORTANT: Keep aligned with DCAddonNamespace.h (DCAddon::Opcode::HLBG)
    enum ServerOpcodes : uint8
    {
        SMSG_STATUS                 = 0x10,
        SMSG_RESOURCES              = 0x11,
        SMSG_OBJECTIVE              = 0x12,
        SMSG_QUEUE_UPDATE           = 0x13,
        SMSG_TIMER_SYNC             = 0x14,
        SMSG_TEAM_SCORE             = 0x15,
        SMSG_STATS                  = 0x16,
        SMSG_AFFIX_INFO             = 0x17,
        SMSG_MATCH_END              = 0x18,

        // Extended/legacy JSON responses (non-canonical, kept separate)
        SMSG_LEADERBOARD_DATA       = 0x30,
        SMSG_PLAYER_STATS           = 0x31,
        SMSG_ALLTIME_STATS          = 0x32,
        SMSG_HISTORY_TSV            = 0x33,

        SMSG_ERROR                  = 0x1F,
    };

    // Leaderboard entry structure
    struct LeaderboardEntry
    {
        uint32 rank;
        std::string playerName;
        uint32 playerGuid;
        uint32 score;
        uint32 extra;  // Wins, games, K/D, etc depending on type
    };

    // Configuration
    static bool s_enabled = true;

    void LoadConfig()
    {
        s_enabled = sConfigMgr->GetOption<bool>("DC.Addon.HLBG.Enable", true);
    }

    // =====================================================================
    // BINARY MESSAGE HELPERS - Real-time BG updates
    // =====================================================================

    void SendStatus(Player* player, HLBGStatus status, uint32 mapId, uint32 timeRemaining)
    {
        Message msg(Module::HINTERLAND, SMSG_STATUS);
        msg.Add(static_cast<uint8>(status));
        msg.Add(mapId);
        msg.Add(timeRemaining);
        msg.Send(player);
    }

    void SendResources(Player* player, uint32 allianceRes, uint32 hordeRes,
                       uint32 allianceBases, uint32 hordeBases)
    {
        Message msg(Module::HINTERLAND, SMSG_RESOURCES);
        msg.Add(allianceRes);
        msg.Add(hordeRes);
        msg.Add(allianceBases);
        msg.Add(hordeBases);
        msg.Send(player);
    }

    void SendQueueUpdate(Player* player, uint8 queueStatus, uint32 position, uint32 estimatedTime,
                         uint32 totalQueued, uint32 allianceQueued, uint32 hordeQueued, 
                         uint32 minPlayers, uint8 state)
    {
        Message msg(Module::HINTERLAND, SMSG_QUEUE_UPDATE);
        msg.Add(queueStatus);
        msg.Add(position);
        msg.Add(estimatedTime);
        msg.Add(totalQueued);
        msg.Add(allianceQueued);
        msg.Add(hordeQueued);
        msg.Add(minPlayers);
        msg.Add(state);
        msg.Send(player);
    }

    // Helper to gather queue stats and send update
    void SendQueueInfo(Player* player)
    {
        if (!player) return;

        OutdoorPvPHL* hl = GetHL();
        if (!hl)
        {
            SendQueueUpdate(player, 0, 0, 0, 0, 0, 0, 10, 0);
            return;
        }

        uint8 queueStatus = hl->IsPlayerQueued(player) ? 1 : 0;
        uint32 position = 0; // Position logic not yet exposed
        uint32 estimatedTime = 0; 

        uint32 totalQueued = hl->GetQueuedPlayerCount();
        uint32 allianceQueued = hl->GetQueuedPlayerCountByTeam(TEAM_ALLIANCE);
        uint32 hordeQueued = hl->GetQueuedPlayerCountByTeam(TEAM_HORDE);
        uint32 minPlayers = hl->GetMinPlayersToStart();
        uint8 state = static_cast<uint8>(hl->GetBGState());

        SendQueueUpdate(player, queueStatus, position, estimatedTime, 
                        totalQueued, allianceQueued, hordeQueued, minPlayers, state);
    }

    void SendTimerSync(Player* player, uint32 elapsedMs, uint32 maxMs)
    {
        Message msg(Module::HINTERLAND, SMSG_TIMER_SYNC);
        msg.Add(elapsedMs);
        msg.Add(maxMs);
        msg.Send(player);
    }

    void SendTeamScore(Player* player, uint32 allianceScore, uint32 hordeScore,
                       uint32 allianceKills, uint32 hordeKills)
    {
        Message msg(Module::HINTERLAND, SMSG_TEAM_SCORE);
        msg.Add(allianceScore);
        msg.Add(hordeScore);
        msg.Add(allianceKills);
        msg.Add(hordeKills);
        msg.Send(player);
    }

    void SendAffixInfo(Player* player, uint32 affixId1, uint32 affixId2, uint32 affixId3, uint32 seasonId)
    {
        Message msg(Module::HINTERLAND, SMSG_AFFIX_INFO);
        msg.Add(affixId1);
        msg.Add(affixId2);
        msg.Add(affixId3);
        msg.Add(seasonId);
        msg.Send(player);
    }

    void SendMatchEnd(Player* player, bool victory, uint32 personalScore, uint32 honorGained,
                      uint32 reputationGained, uint32 tokensGained)
    {
        Message msg(Module::HINTERLAND, SMSG_MATCH_END);
        msg.Add(victory);
        msg.Add(personalScore);
        msg.Add(honorGained);
        msg.Add(reputationGained);
        msg.Add(tokensGained);
        msg.Send(player);
    }

    // =====================================================================
    // UNIFIED SCHEMA LEADERBOARD QUERIES
    // =====================================================================

    /**
     * Query seasonal player leaderboard from materialized views
     * Uses v_hlbg_player_seasonal_stats for all 7 leaderboard types
     */
    static bool QuerySeasonalLeaderboard(
        uint32 leaderboardType,
        uint32 season,
        uint32 limit,
        std::vector<LeaderboardEntry>& outEntries,
        std::string& outError)
    {
        std::string query;

        // Map leaderboard type to SQL query
        switch (leaderboardType)
        {
            case 1:  // RATING
                query = Acore::StringFormat(
                    "SELECT guid, player_name, current_rating, wins "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u "
                    "ORDER BY current_rating DESC LIMIT %u",
                    season, limit);
                break;

            case 2:  // WINS
                query = Acore::StringFormat(
                    "SELECT guid, player_name, wins, games_played "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u "
                    "ORDER BY wins DESC LIMIT %u",
                    season, limit);
                break;

            case 3:  // WINRATE
                query = Acore::StringFormat(
                    "SELECT guid, player_name, CAST(win_rate * 100 AS UNSIGNED), games_played "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u AND games_played >= 5 "
                    "ORDER BY win_rate DESC LIMIT %u",
                    season, limit);
                break;

            case 4:  // GAMES PLAYED
                query = Acore::StringFormat(
                    "SELECT guid, player_name, games_played, wins "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u "
                    "ORDER BY games_played DESC LIMIT %u",
                    season, limit);
                break;

            case 5:  // KILLS
                query = Acore::StringFormat(
                    "SELECT guid, player_name, total_kills, avg_kills_per_game "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u "
                    "ORDER BY total_kills DESC LIMIT %u",
                    season, limit);
                break;

            case 6:  // RESOURCES CAPTURED
                query = Acore::StringFormat(
                    "SELECT guid, player_name, total_resources_captured, games_played "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u "
                    "ORDER BY total_resources_captured DESC LIMIT %u",
                    season, limit);
                break;

            case 7:  // K/D RATIO
                query = Acore::StringFormat(
                    "SELECT guid, player_name, CAST(kd_ratio * 100 AS UNSIGNED), games_played "
                    "FROM `v_hlbg_player_seasonal_stats` "
                    "WHERE season_id = %u AND total_deaths > 0 "
                    "ORDER BY kd_ratio DESC LIMIT %u",
                    season, limit);
                break;

            default:
                outError = "Invalid leaderboard type";
                return false;
        }

        // Execute query
        QueryResult result = CharacterDatabase.Query(query);
        if (!result)
        {
            outError = "No data available";
            return false;
        }

        uint32 rank = 1;
        do
        {
            Field* fields = result->Fetch();

            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.playerGuid = fields[0].Get<uint32>();
            entry.playerName = fields[1].Get<std::string>();
            entry.score = fields[2].Get<uint32>();
            entry.extra = fields[3].Get<uint32>();

            outEntries.push_back(entry);
        } while (result->NextRow());

        return true;
    }

    /**
     * Query player's seasonal statistics from unified schema view
     */
    static bool QueryPlayerSeasonalStats(
        Player* player,
        uint32 season,
        std::string& outJson,
        std::string& outError)
    {
        if (!player)
        {
            outError = "Invalid player";
            return false;
        }

        uint32 playerGuid = player->GetGUID().GetCounter();

        std::string query = Acore::StringFormat(
            "SELECT "
            "IFNULL(current_rating, 0), "
            "IFNULL(wins, 0), "
            "IFNULL(losses, 0), "
            "IFNULL(games_played, 0), "
            "IFNULL(win_rate, 0), "
            "IFNULL(total_kills, 0), "
            "IFNULL(total_deaths, 0), "
            "IFNULL(kd_ratio, 0), "
            "IFNULL(avg_kills_per_game, 0), "
            "IFNULL(avg_damage_per_game, 0) "
            "FROM `v_hlbg_player_seasonal_stats` "
            "WHERE guid = %u AND season_id = %u",
            playerGuid, season);

        QueryResult result = CharacterDatabase.Query(query);
        if (!result)
        {
            // Return zero stats
            outJson = "{"
                "\"rating\":0,\"wins\":0,\"losses\":0,\"games\":0,"
                "\"winRate\":0,\"kills\":0,\"deaths\":0,\"kdRatio\":0,"
                "\"avgKills\":0,\"avgDamage\":0"
                "}";
            return true;
        }

        Field* fields = result->Fetch();

        outJson = Acore::StringFormat(
            "{"
            "\"rating\":%d,"
            "\"wins\":%u,"
            "\"losses\":%u,"
            "\"games\":%u,"
            "\"winRate\":%.2f,"
            "\"kills\":%u,"
            "\"deaths\":%u,"
            "\"kdRatio\":%.2f,"
            "\"avgKills\":%.2f,"
            "\"avgDamage\":%.0f"
            "}",
            fields[0].Get<int32>(),
            fields[1].Get<uint32>(),
            fields[2].Get<uint32>(),
            fields[3].Get<uint32>(),
            fields[4].Get<float>(),
            fields[5].Get<uint32>(),
            fields[6].Get<uint32>(),
            fields[7].Get<float>(),
            fields[8].Get<float>(),
            fields[9].Get<float>());

        return true;
    }

    /**
     * Query player's all-time statistics from unified schema view
     */
    static bool QueryPlayerAllTimeStats(
        Player* player,
        std::string& outJson,
        std::string& outError)
    {
        if (!player)
        {
            outError = "Invalid player";
            return false;
        }

        uint32 playerGuid = player->GetGUID().GetCounter();

        std::string query = Acore::StringFormat(
            "SELECT "
            "IFNULL(total_matches, 0), "
            "IFNULL(lifetime_wins, 0), "
            "IFNULL(lifetime_losses, 0), "
            "IFNULL(lifetime_kills, 0), "
            "IFNULL(lifetime_deaths, 0), "
            "IFNULL(lifetime_kd_ratio, 0), "
            "IFNULL(avg_kills_career, 0), "
            "IFNULL(avg_damage_career, 0) "
            "FROM `v_hlbg_player_alltime_stats` "
            "WHERE guid = %u",
            playerGuid);

        QueryResult result = CharacterDatabase.Query(query);
        if (!result)
        {
            // Return zero stats
            outJson = "{"
                "\"totalMatches\":0,\"lifetimeWins\":0,\"lifetimeLosses\":0,"
                "\"lifetimeKills\":0,\"lifetimeDeaths\":0,\"kdRatio\":0,"
                "\"avgKills\":0,\"avgDamage\":0"
                "}";
            return true;
        }

        Field* fields = result->Fetch();

        outJson = Acore::StringFormat(
            "{"
            "\"totalMatches\":%u,"
            "\"lifetimeWins\":%u,"
            "\"lifetimeLosses\":%u,"
            "\"lifetimeKills\":%u,"
            "\"lifetimeDeaths\":%u,"
            "\"kdRatio\":%.2f,"
            "\"avgKills\":%.2f,"
            "\"avgDamage\":%.0f"
            "}",
            fields[0].Get<uint32>(),
            fields[1].Get<uint32>(),
            fields[2].Get<uint32>(),
            fields[3].Get<uint32>(),
            fields[4].Get<uint32>(),
            fields[5].Get<float>(),
            fields[6].Get<float>(),
            fields[7].Get<float>());

        return true;
    }

    // =====================================================================
    // MESSAGE HANDLERS
    // =====================================================================

    // Real-time BG status handlers
    static void HandleRequestStatus(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;
        if (IsRateLimited(player, 300))
            return;

        OutdoorPvPHL* hl = GetHL();
        uint32 zoneId = player->GetZoneId();
        uint32 mapId = player->GetMapId();
        uint32 timeRemaining = hl ? hl->GetTimeRemainingSeconds() : 0u;

        HLBGStatus status = STATUS_NONE;
        if (hl)
        {
            if (zoneId == OutdoorPvPHLBuffZones[0])
                status = STATUS_ACTIVE;
            else if (hl->IsPlayerQueued(player))
                status = STATUS_QUEUED;
        }

        SendStatus(player, status, mapId, timeRemaining);
    }

    static void HandleRequestResources(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;
        if (IsRateLimited(player, 300))
            return;

        OutdoorPvPHL* hl = GetHL();
        if (!hl)
        {
            SendResources(player, 0, 0, 0, 0);
            return;
        }

        uint32 a = hl->GetResources(TEAM_ALLIANCE);
        uint32 h = hl->GetResources(TEAM_HORDE);
        // HLBG doesn't track bases like AB; keep fields for forward-compat.
        SendResources(player, a, h, 0, 0);
    }

    static void HandleRequestObjective(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;
        Message response(Module::HINTERLAND, SMSG_ERROR);
        response.Add(std::string("Objectives not implemented for HLBG"));
        response.Send(player);
    }

    static void HandleQuickQueue(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;
        if (IsRateLimited(player, 800))
            return;

        if (OutdoorPvPHL* hl = GetHL())
            hl->QueueCommandFromAddon(player, "queue", "join");
        else
            ChatHandler(player->GetSession()).ParseCommands(".hlbg queue join");

        SendQueueInfo(player);
    }

    static void HandleLeaveQueue(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;
        if (IsRateLimited(player, 800))
            return;

        if (OutdoorPvPHL* hl = GetHL())
                hl->QueueCommandFromAddon(player, "queue", "leave");
        else
            ChatHandler(player->GetSession()).ParseCommands(".hlbg queue leave");

        SendQueueInfo(player);
    }

    static void HandleRequestStats(Player* player, const ParsedMessage& msg)
    {
        if (!player) return;
        (void)msg;
        // Deprecated: redundant with CMSG_GET_PLAYER_STATS / CMSG_GET_ALLTIME_STATS and DC-Leaderboards.
        Message response(Module::HINTERLAND, SMSG_ERROR);
        response.Add(std::string("HLBG stats request is deprecated. Use DC-Leaderboards (/leaderboard)."));
        response.Send(player);
    }

    static void HandleRequestHistoryUI(Player* player, const ParsedMessage& msg)
    {
        if (!player)
            return;

        (void)msg;
        // Deprecated: moved to DC-Leaderboards to avoid duplicate big transfers.
        Message response(Module::HINTERLAND, SMSG_ERROR);
        response.Add(std::string("HLBG history UI is deprecated. Use DC-Leaderboards (/leaderboard)."));
        response.Send(player);
    }

    // Leaderboard and stats handlers
    static void HandleGetLeaderboard(Player* player, const ParsedMessage& msg)
    {
        if (!player) return;

        if (IsRateLimited(player, 800))
            return;

        uint32 leaderboardType = 1;
        uint32 season = 0;
        uint32 limit = 100;

        // Accept either positional args (preferred) or a JSON blob (legacy).
        // Positional: leaderboardType|season|limit
        if (msg.GetDataCount() >= 1)
            leaderboardType = msg.GetUInt32(0);
        if (msg.GetDataCount() >= 2)
            season = msg.GetUInt32(1);
        if (msg.GetDataCount() >= 3)
            limit = msg.GetUInt32(2);

        // Legacy JSON: data may be {..} or J|{..}
        std::string data = msg.GetString(0);
        if (data == "J")
            data = msg.GetString(1);

        if (!data.empty() && data[0] == '{')
        {
            if (data.find("\"leaderboardType\"") != std::string::npos)
            {
                int val = 0;
                if (sscanf(data.c_str(), "{\"leaderboardType\":%d", &val) == 1 || sscanf(data.c_str(), "\"leaderboardType\":%d", &val) == 1)
                    leaderboardType = val;
            }
            if (data.find("\"season\"") != std::string::npos)
            {
                int val = 0;
                if (sscanf(data.c_str(), "\"season\":%d", &val) == 1)
                    season = val;
            }
            if (data.find("\"limit\"") != std::string::npos)
            {
                int val = 100;
                if (sscanf(data.c_str(), "\"limit\":%d", &val) == 1)
                    limit = val;
            }
        }

        if (season == 0)
            if (OutdoorPvPHL* hl = GetHL())
                season = hl->GetSeason();

        limit = std::min<uint32>(limit, 200u);

        // Query leaderboard
        std::vector<LeaderboardEntry> entries;
        std::string error;

        if (!QuerySeasonalLeaderboard(leaderboardType, season, limit, entries, error))
        {
            Message packet(Module::HINTERLAND, SMSG_ERROR);
            packet.Add(error);
            packet.Send(player);
            return;
        }

        // Build JSON response
        std::string jsonEntries = "[";
        for (size_t i = 0; i < entries.size(); ++i)
        {
            if (i > 0) jsonEntries += ",";

            jsonEntries += Acore::StringFormat(
                "{\"rank\":%u,\"guid\":%u,\"name\":\"%s\",\"score\":%u,\"extra\":%u}",
                entries[i].rank,
                entries[i].playerGuid,
                entries[i].playerName.c_str(),
                entries[i].score,
                entries[i].extra);
        }
        jsonEntries += "]";

        std::string response = Acore::StringFormat(
            "{\"leaderboardType\":%u,\"season\":%u,\"entries\":%s}",
            leaderboardType,
            season,
            jsonEntries.c_str());

        Message packet(Module::HINTERLAND, SMSG_LEADERBOARD_DATA);
        packet.Add(response);
        packet.Send(player);
    }

    static void HandleGetPlayerStats(Player* player, const ParsedMessage& msg)
    {
        if (!player) return;

        if (IsRateLimited(player, 800))
            return;

        uint32 season = 0;

        // Preferred positional: season
        if (msg.GetDataCount() >= 1)
            season = msg.GetUInt32(0);

        // Legacy JSON: data may be {..} or J|{..}
        std::string data = msg.GetString(0);
        if (data == "J")
            data = msg.GetString(1);

        if (!data.empty() && data[0] == '{')
        {
            if (data.find("\"season\"") != std::string::npos)
            {
                int val = 0;
                if (sscanf(data.c_str(), "\"season\":%d", &val) == 1)
                    season = val;
            }
        }

        if (season == 0)
            if (OutdoorPvPHL* hl = GetHL())
                season = hl->GetSeason();

        std::string statsJson;
        std::string error;

        if (!QueryPlayerSeasonalStats(player, season, statsJson, error))
        {
            Message packet(Module::HINTERLAND, SMSG_ERROR);
            packet.Add(error);
            packet.Send(player);
            return;
        }

        Message packet(Module::HINTERLAND, SMSG_PLAYER_STATS);
        packet.Add(statsJson);
        packet.Send(player);
    }

    static void HandleGetAllTimeStats(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;

        if (IsRateLimited(player, 800))
            return;

        std::string statsJson;
        std::string error;

        if (!QueryPlayerAllTimeStats(player, statsJson, error))
        {
            Message msg(Module::HINTERLAND, SMSG_ERROR);
            msg.Add(error);
            msg.Send(player);
            return;
        }

        Message msg(Module::HINTERLAND, SMSG_ALLTIME_STATS);
        msg.Add(statsJson);
        msg.Send(player);
    }

    // =====================================================================
    // HANDLER REGISTRATION
    // =====================================================================

    void RegisterHandlers()
    {
        LoadConfig();
        if (!s_enabled)
        {
            LOG_INFO("dc.addon", "HLBG unified handler disabled by config");
            return;
        }

        // Real-time BG handlers
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_REQUEST_STATUS, HandleRequestStatus);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_REQUEST_RESOURCES, HandleRequestResources);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_REQUEST_OBJECTIVE, HandleRequestObjective);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_QUICK_QUEUE, HandleQuickQueue);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_LEAVE_QUEUE, HandleLeaveQueue);

        // Legacy/extended requests intentionally no longer registered.
        // (Stats/history moved to DC-Leaderboards to avoid duplicated code + transfers.)

        // Leaderboard and stats handlers (JSON-based)
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_GET_LEADERBOARD, HandleGetLeaderboard);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_GET_PLAYER_STATS, HandleGetPlayerStats);
        DC_REGISTER_HANDLER(Module::HINTERLAND, CMSG_GET_ALLTIME_STATS, HandleGetAllTimeStats);

        LOG_INFO("dc.addon", "HLBG unified handler registered with %s support",
            "real-time + leaderboards + unified schema");
    }

}  // namespace HLBG
}  // namespace DCAddon

// Register the unified HLBG addon handler
void AddSC_dc_addon_hlbg()
{
    DCAddon::HLBG::RegisterHandlers();
}

// ============================================================================
// Chat-prefixed addon fallback handlers (moved from DC/HinterlandBG/hlbg_addon.cpp)
// These are called by the centralized .hlbg command table in src/server/scripts/Commands/cs_hl_bg.cpp
// ============================================================================

namespace HLBGAddonFallback
{
    using namespace HinterlandBGConstants;

    static std::string EscapeJson(const std::string& in)
    {
        std::string out;
        out.reserve(in.size());
        for (char c : in)
        {
            switch (c)
            {
                case '\\': out += "\\\\"; break;
                case '"':  out += "\\\""; break;
                case '\n': out += "\\n"; break;
                case '\r': out += "\\r"; break;
                case '\t': out += "\\t"; break;
                default:   out += c; break;
            }
        }
        return out;
    }

    static OutdoorPvPHL* GetHL()
    {
        OutdoorPvP* opvp = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(OutdoorPvPHLBuffZones[0]);
        return opvp ? dynamic_cast<OutdoorPvPHL*>(opvp) : nullptr;
    }

    static std::string NowTimestamp()
    {
        std::time_t t = std::time(nullptr);
        char buf[64];
        std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", std::localtime(&t));
        return std::string(buf);
    }

    static std::string BuildLiveJson(uint32 matchStart, uint32 a, uint32 h)
    {
        std::ostringstream ss;
        ss << '{'
           << "\"ts\":\"" << EscapeJson(NowTimestamp()) << "\",";
        ss << "\"matchStart\":" << matchStart << ',';
        ss << "\"A\":" << a << ',';
        ss << "\"H\":" << h;
        ss << '}';
        return ss.str();
    }

    // (History/stats helpers removed; use DC-Leaderboards instead.)

    static std::string BuildLivePlayersJson(OutdoorPvPHL* hl, uint32 limit = 40)
    {
        if (!hl)
            return "[]";

        struct Row { std::string name; std::string team; uint32 score; uint32 hk; uint8 cls; int8 subgroup; };
        std::vector<Row> rows;
        hl->ForEachPlayerInZone([&](Player* p)
        {
            if (!p)
                return;
            Row r;
            r.name = p->GetName();
            r.team = (p->GetTeamId() == TEAM_ALLIANCE) ? "A" : "H";
            r.score = hl->GetPlayerScore(p->GetGUID());
            r.hk = hl->GetPlayerHKDelta(p);
            r.cls = p->getClass();
            r.subgroup = p->GetSubGroup();
            rows.push_back(r);
        });

        std::sort(rows.begin(), rows.end(), [](Row const& a, Row const& b) { return a.score > b.score; });
        if (rows.size() > limit)
            rows.resize(limit);

        std::ostringstream ss;
        ss << '[';
        bool first = true;
        std::string ts = EscapeJson(NowTimestamp());
        uint32 mid = hl->GetMatchStartEpoch();
        for (Row const& r : rows)
        {
            if (!first)
                ss << ',';
            first = false;
            ss << '{'
               << "\"name\":\"" << EscapeJson(r.name) << "\",";
            ss << "\"team\":\"" << r.team << "\",";
            ss << "\"score\":" << r.score << ',';
            ss << "\"hk\":" << r.hk << ',';
            ss << "\"class\":" << (unsigned)r.cls << ',';
            ss << "\"sub\":" << (int)r.subgroup << ',';
            ss << "\"ts\":\"" << ts << "\",";
            ss << "\"matchStart\":" << mid;
            ss << '}';
        }
        ss << ']';
        return ss.str();
    }
}

bool HandleHLBGLive(ChatHandler* handler, char const* args)
{
    if (!handler || !handler->GetSession())
        return false;
    Player* player = handler->GetSession()->GetPlayer();
    if (!player)
        return false;

    OutdoorPvPHL* hl = HLBGAddonFallback::GetHL();
    if (!hl)
    {
        ChatHandler(player->GetSession()).SendSysMessage("[HLBG_LIVE_JSON] {\"A\":0,\"H\":0,\"matchStart\":0}");
        return true;
    }

    uint32 a = hl->GetResources(TEAM_ALLIANCE);
    uint32 h = hl->GetResources(TEAM_HORDE);
    uint32 ms = hl->GetMatchStartEpoch();
    std::string jsonAH = HLBGAddonFallback::BuildLiveJson(ms, a, h);
    ChatHandler(player->GetSession()).SendSysMessage((std::string("[HLBG_LIVE_JSON] ") + jsonAH).c_str());

    bool wantPlayers = false;
    if (args && *args)
    {
        std::string v(args);
        std::transform(v.begin(), v.end(), v.begin(), [](unsigned char c) { return (char)std::tolower(c); });
        wantPlayers = (v.find("players") != std::string::npos);
    }
    if (wantPlayers)
    {
        std::string rows = HLBGAddonFallback::BuildLivePlayersJson(hl);
        ChatHandler(player->GetSession()).SendSysMessage((std::string("[HLBG_LIVE_PLAYERS_JSON] ") + rows).c_str());
    }
    return true;
}

bool HandleHLBGWarmup(ChatHandler* handler, char const* args)
{
    if (!handler || !handler->GetSession())
        return false;
    Player* player = handler->GetSession()->GetPlayer();
    if (!player)
        return false;
    std::string text = args ? std::string(args) : std::string();
    if (text.empty())
        text = "";
    std::string msg = std::string("[HLBG_WARMUP] ") + text;
    ChatHandler(player->GetSession()).SendSysMessage(msg.c_str());
    return true;
}

bool HandleHLBGResults(ChatHandler* handler, char const* /*args*/)
{
    if (!handler || !handler->GetSession())
        return false;
    Player* player = handler->GetSession()->GetPlayer();
    if (!player)
        return false;

    OutdoorPvPHL* hl = HLBGAddonFallback::GetHL();
    std::string winner = "Draw";
    uint32 a = 0, h = 0, dur = 0, affix = 0;
    if (hl)
    {
        TeamId w = hl->GetLastWinnerTeamId();
        winner = (w == TEAM_ALLIANCE) ? "Alliance" : ((w == TEAM_HORDE) ? "Horde" : "Draw");
        a = hl->GetResources(TEAM_ALLIANCE);
        h = hl->GetResources(TEAM_HORDE);
        dur = hl->GetCurrentMatchDurationSeconds();
        affix = hl->GetActiveAffixCode();
    }

    std::ostringstream ss;
    ss << '{' << "\"winner\":\"" << winner << "\",";
    ss << "\"A\":" << a << ',';
    ss << "\"H\":" << h << ',';
    ss << "\"affix\":" << affix << ',';
    ss << "\"duration\":" << dur;
    ss << '}';
    ChatHandler(player->GetSession()).SendSysMessage((std::string("[HLBG_RESULTS_JSON] ") + ss.str()).c_str());
    return true;
}

bool HandleHLBGHistoryUI(ChatHandler* handler, char const* args)
{
    if (!handler || !handler->GetSession())
        return false;
    Player* player = handler->GetSession()->GetPlayer();
    if (!player)
        return false;

    (void)player;
    (void)args;
    handler->SendSysMessage("HLBG: history UI is deprecated. Use /leaderboard.");
    return true;
}

bool HandleHLBGStatsUI(ChatHandler* handler, char const* args)
{
    // Deprecated: stats UI moved to DC-Leaderboards (/leaderboard).
    if (!handler || !handler->GetSession())
        return false;
    Player* player = handler->GetSession()->GetPlayer();
    if (!player)
        return false;

    (void)player;
    (void)args;
    handler->SendSysMessage("HLBG: stats UI is deprecated. Use /leaderboard.");
    return true;
}

bool HandleHLBGQueueJoin(ChatHandler* handler, char const* /*args*/)
{
    if (!handler || !handler->GetSession())
        return false;
    Player* player = handler->GetSession()->GetPlayer();
    if (!player)
        return false;

    OutdoorPvPHL* hl = HLBGAddonFallback::GetHL();
    if (!hl)
    {
        handler->SendSysMessage("HLBG: system not available");
        return true;
    }

    if (!hl->IsPlayerMaxLevel(player))
    {
        handler->PSendSysMessage("HLBG: You must be at least level {}.", hl->GetMinLevel());
        return true;
    }

    if (player->HasAura(26013))
    {
        handler->SendSysMessage("HLBG: You cannot join while deserter.");
        return true;
    }

    if (!player->IsAlive() || player->IsInCombat())
    {
        handler->SendSysMessage("HLBG: You must be alive and out of combat.");
        return true;
    }

    // Queue join is allowed during warmup (to participate immediately) and also during an active match
    // (queueing for the next match). The underlying HLBG queue logic enforces final eligibility.

    hl->QueueCommandFromAddon(player, "queue", "join");
    return true;
}

bool HandleHLBGQueueLeave(ChatHandler* handler, char const* /*args*/)
{
    if (!handler || !handler->GetSession())
        return false;
    Player* player = handler->GetSession()->GetPlayer();
    if (!player)
        return false;
    if (OutdoorPvPHL* hl = HLBGAddonFallback::GetHL())
        hl->QueueCommandFromAddon(player, "queue", "leave");
    return true;
}

bool HandleHLBGQueueStatus(ChatHandler* handler, char const* /*args*/)
{
    if (!handler || !handler->GetSession())
        return false;
    Player* player = handler->GetSession()->GetPlayer();
    if (!player)
        return false;
    if (OutdoorPvPHL* hl = HLBGAddonFallback::GetHL())
        hl->QueueCommandFromAddon(player, "queue", "status");
    return true;
}

// Legacy symbol expected by DC script loader; command registration is in cs_hl_bg.cpp.
void AddSC_hlbg_addon() {}
