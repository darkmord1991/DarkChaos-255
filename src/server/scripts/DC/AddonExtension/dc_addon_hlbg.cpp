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
#include "../HinterlandBG/hlbg_constants.h"
#include "Time/GameTime.h"
#include <algorithm>
#include <cctype>
#include <ctime>
#include <iterator>
#include <map>
#include <mutex>
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
    namespace BridgeOpcode
    {
        enum : uint16
        {
            CMSG_REQUEST_LIVE_SNAPSHOT = ::CMSG_REQUEST_HLBG_LIVE_SNAPSHOT,
            SMSG_LIVE_SNAPSHOT = ::SMSG_HLBG_LIVE_SNAPSHOT,
        };
    }

    namespace
    {
        constexpr uint64 HLBG_RESPONSE_CACHE_TTL_MS = 1000;

        struct AllTimeViewColumns
        {
            char const* totalMatches = nullptr;
            char const* totalWins = nullptr;
            char const* totalLosses = nullptr;
            char const* totalKills = nullptr;
            char const* totalDeaths = nullptr;
            char const* kdRatio = nullptr;
            char const* avgKills = nullptr;
            char const* avgDamage = nullptr;

            bool IsComplete() const
            {
                return totalMatches && totalWins && totalLosses && totalKills
                    && totalDeaths && kdRatio && avgKills && avgDamage;
            }
        };

        // Avoid expensive lookups and allow rate-limiting without extra dependencies.
        static std::unordered_map<uint32, uint32> s_lastRequestMs;
        static std::mutex s_rateLimitMutex;  // Thread safety for rate limiting

        struct CachedLeaderboardPayload
        {
            std::string response;
            uint64 expiresAtMs = 0;
        };

        struct CachedAllTimeStatsPayload
        {
            std::string response;
            uint64 expiresAtMs = 0;
        };

        static std::unordered_map<uint64, CachedLeaderboardPayload>
            s_cachedLeaderboardPayloads;
        static std::unordered_map<uint32, CachedAllTimeStatsPayload>
            s_cachedAllTimeStatsPayloads;
        static std::mutex s_responseCacheMutex;

        static uint64 GetNowMs()
        {
            return static_cast<uint64>(GameTime::GetGameTimeMS().count());
        }

        static uint64 MakeLeaderboardCacheKey(uint32 leaderboardType,
            uint32 season, uint32 limit)
        {
            return (static_cast<uint64>(leaderboardType) << 48)
                | (static_cast<uint64>(season) << 16)
                | static_cast<uint64>(limit);
        }

        static bool CharacterColumnExists(char const* tableName,
            char const* columnName)
        {
            std::string query = Acore::StringFormat(
                "SELECT 1 FROM information_schema.COLUMNS "
                "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '%s' "
                "AND COLUMN_NAME = '%s' LIMIT 1",
                tableName, columnName);
            return CharacterDatabase.Query(query) != nullptr;
        }

        static bool CharacterTableExists(char const* tableName)
        {
            std::string query = Acore::StringFormat(
                "SELECT 1 FROM information_schema.TABLES "
                "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '%s' LIMIT 1",
                tableName);
            return CharacterDatabase.Query(query) != nullptr;
        }

        static bool HasUnifiedStatTables()
        {
            static bool const hasTables =
                CharacterTableExists("dc_hlbg_match_participants")
                && CharacterTableExists("dc_hlbg_winner_history");
            return hasTables;
        }

        static bool HasSeasonalStatView()
        {
            static bool const hasView =
                CharacterTableExists("v_hlbg_player_seasonal_stats");
            return hasView;
        }

        static bool HasSeasonalSummaryTable()
        {
            static bool const hasTable =
                CharacterTableExists("dc_hlbg_player_season_data");
            return hasTable;
        }

        static AllTimeViewColumns DetectAllTimeViewColumns()
        {
            AllTimeViewColumns columns;

            if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "total_matches"))
                columns.totalMatches = "total_matches";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "total_games_played"))
                columns.totalMatches = "total_games_played";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "lifetime_wins"))
                columns.totalWins = "lifetime_wins";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "total_wins"))
                columns.totalWins = "total_wins";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "lifetime_losses"))
                columns.totalLosses = "lifetime_losses";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "total_losses"))
                columns.totalLosses = "total_losses";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "lifetime_kills"))
                columns.totalKills = "lifetime_kills";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "total_kills"))
                columns.totalKills = "total_kills";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "lifetime_deaths"))
                columns.totalDeaths = "lifetime_deaths";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "total_deaths"))
                columns.totalDeaths = "total_deaths";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "lifetime_kd_ratio"))
                columns.kdRatio = "lifetime_kd_ratio";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "overall_kd_ratio"))
                columns.kdRatio = "overall_kd_ratio";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "avg_kills_career"))
                columns.avgKills = "avg_kills_career";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "avg_kills_per_game"))
                columns.avgKills = "avg_kills_per_game";

            if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "avg_damage_career"))
                columns.avgDamage = "avg_damage_career";
            else if (CharacterColumnExists("v_hlbg_player_alltime_stats",
                    "avg_damage_per_game"))
                columns.avgDamage = "avg_damage_per_game";

            return columns;
        }

        static AllTimeViewColumns const& GetAllTimeViewColumns()
        {
            static AllTimeViewColumns const columns = DetectAllTimeViewColumns();
            return columns;
        }

        static bool IsRateLimited(Player* player, uint32 cooldownMs)
        {
            if (!player)
                return true;

            uint32 now = GameTime::GetGameTimeMS().count();
            uint32 key = player->GetGUID().GetCounter();

            std::lock_guard<std::mutex> lock(s_rateLimitMutex);
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

        TransportPolicyDecision ResolveLiveSnapshotTransport(Player* player)
        {
            TransportPolicyRequest request;
            request.featureName = "hlbg-live";
            request.nativeCapability =
                ProtocolVersion::Capability::HLBG_LIVE_NATIVE;
            request.allowAddonFallback = false;
            return ResolveTransportPolicy(player, request);
        }
        void AuditAddonUiTransport(Player* player)
        {
            if (!player)
                return;

            SessionCapabilityState capabilityState;
            if (!TryGetSessionCapabilityState(player, capabilityState))
                return;

            TransportPolicyRequest request;
            request.featureName = "hlbg-ui";
            request.forceAddon = true;
            request.forceAddonReason = "addon-ui-request";
            ResolveTransportPolicy(player, request);
        }

        void SendNativeLiveSnapshot(Player* player, std::string const& payload)
        {
            if (!player || !player->GetSession() || payload.empty())
                return;

            WorldPacket data(BridgeOpcode::SMSG_LIVE_SNAPSHOT,
                payload.size() + 1);
            data << payload;
            player->GetSession()->SendPacket(&data);
            std::string preview = "bytes=" + std::to_string(payload.size());
            DCAddon::LogNativeS2CMessage(player, Module::HINTERLAND, 0,
                BridgeOpcode::SMSG_LIVE_SNAPSHOT, data.size(), preview, true,
                0);
        }

        struct LiveHudMetrics
        {
            uint32 alliancePlayers = 0;
            uint32 hordePlayers = 0;
            uint32 alliancePlayerKills = 0;
            uint32 hordePlayerKills = 0;
            uint32 allianceNpcKills = 0;
            uint32 hordeNpcKills = 0;
        };

        LiveHudMetrics CollectLiveHudMetrics(OutdoorPvPHL const* hl)
        {
            LiveHudMetrics metrics;
            if (!hl)
                return metrics;

            hl->ForEachPlayerInZone([&](Player* zonePlayer)
            {
                if (!zonePlayer)
                    return;

                if (zonePlayer->GetTeamId() == TEAM_ALLIANCE)
                {
                    ++metrics.alliancePlayers;
                    metrics.alliancePlayerKills += hl->GetPlayerHKDelta(zonePlayer);
                }
                else if (zonePlayer->GetTeamId() == TEAM_HORDE)
                {
                    ++metrics.hordePlayers;
                    metrics.hordePlayerKills += hl->GetPlayerHKDelta(zonePlayer);
                }
            });

            metrics.allianceNpcKills = hl->GetNpcKillCount(TEAM_ALLIANCE);
            metrics.hordeNpcKills = hl->GetNpcKillCount(TEAM_HORDE);
            return metrics;
        }

        std::string BuildNativeLiveSnapshotPayload(Player* player,
            OutdoorPvPHL* hl, uint32 limit = 40)
        {
            JsonValue payload;
            payload.SetObject();

            JsonValue players;
            players.SetArray();

            uint32 mapId = player ? player->GetMapId() : 0u;
            uint32 timeRemaining = hl ? hl->GetTimeRemainingSeconds() : 0u;
            HLBGStatus status = STATUS_NONE;

            if (player && hl)
            {
                if (hl->IsPlayerAfkFlagged(player))
                {
                    mapId = 0;
                    timeRemaining = 0u;
                }
                else if (IsPlayerInOutdoorPvPHLArea(player))
                    status = STATUS_ACTIVE;
                else if (hl->IsPlayerQueued(player))
                    status = STATUS_QUEUED;
            }

            if (!hl)
            {
                payload.Set("status", static_cast<int32>(status));
                payload.Set("mapId", static_cast<int32>(mapId));
                payload.Set("timeRemaining", static_cast<int32>(timeRemaining));
                payload.Set("duration", static_cast<int32>(timeRemaining));
                payload.Set("matchStart", 0);
                payload.Set("A", 0);
                payload.Set("H", 0);
                payload.Set("APC", 0);
                payload.Set("HPC", 0);
                payload.Set("aBases", 0);
                payload.Set("hBases", 0);
                payload.Set("aPlayerKills", 0);
                payload.Set("hPlayerKills", 0);
                payload.Set("aNpcKills", 0);
                payload.Set("hNpcKills", 0);
                payload.Set("affix", 0);
                payload.Set("players", players);
                return payload.Encode();
            }

            struct LiveRow
            {
                std::string name;
                std::string team;
                uint32 score = 0;
                uint32 hk = 0;
                uint8 cls = 0;
                int8 subgroup = 0;
            };

            std::vector<LiveRow> rows;
            uint32 alliancePlayers = 0;
            uint32 hordePlayers = 0;

            hl->ForEachPlayerInZone([&](Player* zonePlayer)
            {
                if (!zonePlayer)
                    return;

                if (zonePlayer->GetTeamId() == TEAM_ALLIANCE)
                    ++alliancePlayers;
                else if (zonePlayer->GetTeamId() == TEAM_HORDE)
                    ++hordePlayers;

                LiveRow row;
                row.name = zonePlayer->GetName();
                row.team = zonePlayer->GetTeamId() == TEAM_ALLIANCE ? "A" : "H";
                row.score = hl->GetPlayerScore(zonePlayer->GetGUID());
                row.hk = hl->GetPlayerHKDelta(zonePlayer);
                row.cls = zonePlayer->getClass();
                row.subgroup = zonePlayer->GetSubGroup();
                rows.push_back(row);
            });

            std::sort(rows.begin(), rows.end(), [](LiveRow const& left,
                LiveRow const& right)
            {
                return left.score > right.score;
            });

            if (rows.size() > limit)
                rows.resize(limit);

            for (LiveRow const& row : rows)
            {
                JsonValue playerRow;
                playerRow.SetObject();
                playerRow.Set("name", row.name);
                playerRow.Set("team", row.team);
                playerRow.Set("score", static_cast<int32>(row.score));
                playerRow.Set("hk", static_cast<int32>(row.hk));
                playerRow.Set("class", static_cast<int32>(row.cls));
                playerRow.Set("sub", static_cast<int32>(row.subgroup));
                players.Push(playerRow);
            }

            LiveHudMetrics metrics = CollectLiveHudMetrics(hl);

            payload.Set("status", static_cast<int32>(status));
            payload.Set("mapId", static_cast<int32>(mapId));
            payload.Set("timeRemaining", static_cast<int32>(timeRemaining));
            payload.Set("duration", static_cast<int32>(timeRemaining));
            payload.Set("matchStart",
                static_cast<int32>(hl->GetMatchStartEpoch()));
            payload.Set("A", static_cast<int32>(hl->GetResources(TEAM_ALLIANCE)));
            payload.Set("H", static_cast<int32>(hl->GetResources(TEAM_HORDE)));
            payload.Set("APC", static_cast<int32>(alliancePlayers));
            payload.Set("HPC", static_cast<int32>(hordePlayers));
            payload.Set("aBases", 0);
            payload.Set("hBases", 0);
            payload.Set("aPlayerKills",
                static_cast<int32>(metrics.alliancePlayerKills));
            payload.Set("hPlayerKills",
                static_cast<int32>(metrics.hordePlayerKills));
            payload.Set("aNpcKills",
                static_cast<int32>(metrics.allianceNpcKills));
            payload.Set("hNpcKills",
                static_cast<int32>(metrics.hordeNpcKills));
            payload.Set("affix", static_cast<int32>(hl->GetActiveAffixCode()));
            payload.Set("players", players);
            return payload.Encode();
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
                       uint32 allianceBases, uint32 hordeBases,
                       uint32 alliancePlayers, uint32 hordePlayers,
                       uint32 alliancePlayerKills, uint32 hordePlayerKills,
                       uint32 allianceNpcKills, uint32 hordeNpcKills)
    {
        Message msg(Module::HINTERLAND, SMSG_RESOURCES);
        msg.Add(allianceRes);
        msg.Add(hordeRes);
        msg.Add(allianceBases);
        msg.Add(hordeBases);
        msg.Add(alliancePlayers);
        msg.Add(hordePlayers);
        msg.Add(alliancePlayerKills);
        msg.Add(hordePlayerKills);
        msg.Add(allianceNpcKills);
        msg.Add(hordeNpcKills);
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

    static void SendRateLimitedError(Player* player)
    {
        if (!player)
            return;

        DCAddon::SendError(player, Module::HINTERLAND,
            "HLBG request rate-limited", DCAddon::ErrorCode::UNKNOWN,
            Opcode::Core::SMSG_ERROR);
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

        if (HasSeasonalSummaryTable() && leaderboardType <= 4)
        {
            switch (leaderboardType)
            {
                case 1:  // RATING
                    query = Acore::StringFormat(
                        "SELECT s.player_guid, COALESCE(c.name, ''), s.rating, s.wins "
                        "FROM `dc_hlbg_player_season_data` s "
                        "LEFT JOIN `characters` c ON s.player_guid = c.guid "
                        "WHERE s.season_id = %u "
                        "ORDER BY s.rating DESC LIMIT %u",
                        season, limit);
                    break;

                case 2:  // WINS
                    query = Acore::StringFormat(
                        "SELECT s.player_guid, COALESCE(c.name, ''), s.wins, s.completed_games "
                        "FROM `dc_hlbg_player_season_data` s "
                        "LEFT JOIN `characters` c ON s.player_guid = c.guid "
                        "WHERE s.season_id = %u "
                        "ORDER BY s.wins DESC LIMIT %u",
                        season, limit);
                    break;

                case 3:  // WINRATE
                    query = Acore::StringFormat(
                        "SELECT s.player_guid, COALESCE(c.name, ''), "
                        "CAST(ROUND((s.wins * 10000.0) / NULLIF(s.completed_games, 0), 0) AS UNSIGNED), "
                        "s.completed_games "
                        "FROM `dc_hlbg_player_season_data` s "
                        "LEFT JOIN `characters` c ON s.player_guid = c.guid "
                        "WHERE s.season_id = %u AND s.completed_games >= 5 "
                        "ORDER BY (s.wins / NULLIF(s.completed_games, 0)) DESC LIMIT %u",
                        season, limit);
                    break;

                case 4:  // GAMES PLAYED
                    query = Acore::StringFormat(
                        "SELECT s.player_guid, COALESCE(c.name, ''), s.completed_games, s.wins "
                        "FROM `dc_hlbg_player_season_data` s "
                        "LEFT JOIN `characters` c ON s.player_guid = c.guid "
                        "WHERE s.season_id = %u "
                        "ORDER BY s.completed_games DESC LIMIT %u",
                        season, limit);
                    break;

                default:
                    outError = "Invalid leaderboard type";
                    return false;
            }
        }
        else if (HasSeasonalStatView())
        {
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
        }
        else if (HasUnifiedStatTables())
        {
            switch (leaderboardType)
            {
                case 1:
                    query = Acore::StringFormat(
                        "SELECT p.guid, MAX(p.player_name) AS player_name, "
                        "GREATEST(0, COALESCE(SUM(p.rating_change), 0) + 1200) AS score, "
                        "SUM(CASE WHEN wh.winner_tid = p.team THEN 1 ELSE 0 END) AS extra "
                        "FROM `dc_hlbg_match_participants` p "
                        "LEFT JOIN `dc_hlbg_winner_history` wh ON p.match_id = wh.id "
                        "WHERE p.season_id = %u "
                        "GROUP BY p.guid "
                        "ORDER BY score DESC LIMIT %u",
                        season, limit);
                    break;

                case 2:
                    query = Acore::StringFormat(
                        "SELECT p.guid, MAX(p.player_name) AS player_name, "
                        "SUM(CASE WHEN wh.winner_tid = p.team THEN 1 ELSE 0 END) AS score, "
                        "COUNT(*) AS extra "
                        "FROM `dc_hlbg_match_participants` p "
                        "LEFT JOIN `dc_hlbg_winner_history` wh ON p.match_id = wh.id "
                        "WHERE p.season_id = %u "
                        "GROUP BY p.guid "
                        "ORDER BY score DESC LIMIT %u",
                        season, limit);
                    break;

                case 3:
                    query = Acore::StringFormat(
                        "SELECT p.guid, MAX(p.player_name) AS player_name, "
                        "CAST(ROUND((SUM(CASE WHEN wh.winner_tid = p.team THEN 1 ELSE 0 END) * 10000.0) / NULLIF(COUNT(*), 0), 0) AS UNSIGNED) AS score, "
                        "COUNT(*) AS extra "
                        "FROM `dc_hlbg_match_participants` p "
                        "LEFT JOIN `dc_hlbg_winner_history` wh ON p.match_id = wh.id "
                        "WHERE p.season_id = %u "
                        "GROUP BY p.guid "
                        "HAVING COUNT(*) >= 5 "
                        "ORDER BY score DESC LIMIT %u",
                        season, limit);
                    break;

                case 4:
                    query = Acore::StringFormat(
                        "SELECT p.guid, MAX(p.player_name) AS player_name, "
                        "COUNT(*) AS score, "
                        "SUM(CASE WHEN wh.winner_tid = p.team THEN 1 ELSE 0 END) AS extra "
                        "FROM `dc_hlbg_match_participants` p "
                        "LEFT JOIN `dc_hlbg_winner_history` wh ON p.match_id = wh.id "
                        "WHERE p.season_id = %u "
                        "GROUP BY p.guid "
                        "ORDER BY score DESC LIMIT %u",
                        season, limit);
                    break;

                case 5:
                    query = Acore::StringFormat(
                        "SELECT p.guid, MAX(p.player_name) AS player_name, "
                        "COALESCE(SUM(p.kills), 0) AS score, "
                        "CAST(ROUND(COALESCE(SUM(p.kills), 0) / NULLIF(COUNT(*), 0), 0) AS UNSIGNED) AS extra "
                        "FROM `dc_hlbg_match_participants` p "
                        "LEFT JOIN `dc_hlbg_winner_history` wh ON p.match_id = wh.id "
                        "WHERE p.season_id = %u "
                        "GROUP BY p.guid "
                        "ORDER BY score DESC LIMIT %u",
                        season, limit);
                    break;

                case 6:
                    query = Acore::StringFormat(
                        "SELECT p.guid, MAX(p.player_name) AS player_name, "
                        "COALESCE(SUM(p.resources_captured), 0) AS score, "
                        "COUNT(*) AS extra "
                        "FROM `dc_hlbg_match_participants` p "
                        "LEFT JOIN `dc_hlbg_winner_history` wh ON p.match_id = wh.id "
                        "WHERE p.season_id = %u "
                        "GROUP BY p.guid "
                        "ORDER BY score DESC LIMIT %u",
                        season, limit);
                    break;

                case 7:
                    query = Acore::StringFormat(
                        "SELECT p.guid, MAX(p.player_name) AS player_name, "
                        "CAST(ROUND((COALESCE(SUM(p.kills), 0) * 100.0) / NULLIF(COALESCE(SUM(p.deaths), 0), 0), 0) AS UNSIGNED) AS score, "
                        "COUNT(*) AS extra "
                        "FROM `dc_hlbg_match_participants` p "
                        "LEFT JOIN `dc_hlbg_winner_history` wh ON p.match_id = wh.id "
                        "WHERE p.season_id = %u "
                        "GROUP BY p.guid "
                        "HAVING COALESCE(SUM(p.deaths), 0) > 0 "
                        "ORDER BY score DESC LIMIT %u",
                        season, limit);
                    break;

                default:
                    outError = "Invalid leaderboard type";
                    return false;
            }
        }
        else
        {
            outError = "No seasonal stats source available";
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

    static bool BuildSeasonalLeaderboardResponse(
        uint32 leaderboardType,
        uint32 season,
        uint32 limit,
        std::string& outResponse,
        std::string& outError)
    {
        std::vector<LeaderboardEntry> entries;
        if (!QuerySeasonalLeaderboard(leaderboardType, season, limit, entries,
            outError))
        {
            return false;
        }

        std::string jsonEntries = "[";
        for (size_t i = 0; i < entries.size(); ++i)
        {
            if (i > 0)
                jsonEntries += ",";

            jsonEntries += Acore::StringFormat(
                "{\"rank\":%u,\"guid\":%u,\"name\":\"%s\",\"score\":%u,\"extra\":%u}",
                entries[i].rank,
                entries[i].playerGuid,
                entries[i].playerName.c_str(),
                entries[i].score,
                entries[i].extra);
        }
        jsonEntries += "]";

        outResponse = Acore::StringFormat(
            "{\"leaderboardType\":%u,\"season\":%u,\"entries\":%s}",
            leaderboardType,
            season,
            jsonEntries.c_str());
        return true;
    }

    static bool GetCachedSeasonalLeaderboardResponse(
        uint32 leaderboardType,
        uint32 season,
        uint32 limit,
        std::string& outResponse,
        std::string& outError)
    {
        uint64 const cacheKey = MakeLeaderboardCacheKey(leaderboardType,
            season, limit);
        uint64 const nowMs = GetNowMs();

        {
            std::lock_guard<std::mutex> lock(s_responseCacheMutex);
            auto itr = s_cachedLeaderboardPayloads.find(cacheKey);
            if (itr != s_cachedLeaderboardPayloads.end()
                && itr->second.expiresAtMs > nowMs)
            {
                outResponse = itr->second.response;
                return true;
            }
        }

        std::string response;
        if (!BuildSeasonalLeaderboardResponse(leaderboardType, season, limit,
            response, outError))
        {
            return false;
        }

        CachedLeaderboardPayload payload;
        payload.response = response;
        payload.expiresAtMs = nowMs + HLBG_RESPONSE_CACHE_TTL_MS;

        std::lock_guard<std::mutex> lock(s_responseCacheMutex);
        s_cachedLeaderboardPayloads[cacheKey] = payload;
        outResponse = payload.response;
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

        std::string query;
        if (HasUnifiedStatTables())
        {
            query = Acore::StringFormat(
                "SELECT "
                "CASE WHEN COUNT(*) = 0 THEN 0 ELSE GREATEST(0, COALESCE(SUM(p.rating_change), 0) + 1200) END, "
                "COALESCE(SUM(CASE WHEN wh.winner_tid = p.team THEN 1 ELSE 0 END), 0), "
                "COALESCE(SUM(CASE WHEN wh.winner_tid <> p.team AND wh.winner_tid <> 0 THEN 1 ELSE 0 END), 0), "
                "COUNT(*), "
                "CASE WHEN COUNT(*) = 0 THEN 0 ELSE ROUND((SUM(CASE WHEN wh.winner_tid = p.team THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) END, "
                "COALESCE(SUM(p.kills), 0), "
                "COALESCE(SUM(p.deaths), 0), "
                "CASE WHEN COALESCE(SUM(p.deaths), 0) = 0 THEN 0 ELSE ROUND(COALESCE(SUM(p.kills), 0) / SUM(p.deaths), 2) END, "
                "CASE WHEN COUNT(*) = 0 THEN 0 ELSE ROUND(COALESCE(SUM(p.kills), 0) / COUNT(*), 2) END, "
                "CASE WHEN COUNT(*) = 0 THEN 0 ELSE ROUND(COALESCE(SUM(p.damage_done), 0) / COUNT(*), 0) END "
                "FROM `dc_hlbg_match_participants` p "
                "LEFT JOIN `dc_hlbg_winner_history` wh ON p.match_id = wh.id "
                "WHERE p.guid = %u AND p.season_id = %u",
                playerGuid, season);
        }
        else if (HasSeasonalStatView())
        {
            query = Acore::StringFormat(
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
        }
        else
        {
            outError = "No seasonal stats source available";
            return false;
        }

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

        std::string query;
        if (HasUnifiedStatTables())
        {
            query = Acore::StringFormat(
                "SELECT "
                "COUNT(*), "
                "COALESCE(SUM(CASE WHEN wh.winner_tid = p.team THEN 1 ELSE 0 END), 0), "
                "COALESCE(SUM(CASE WHEN wh.winner_tid <> p.team AND wh.winner_tid <> 0 THEN 1 ELSE 0 END), 0), "
                "COALESCE(SUM(p.kills), 0), "
                "COALESCE(SUM(p.deaths), 0), "
                "CASE WHEN COALESCE(SUM(p.deaths), 0) = 0 THEN 0 ELSE ROUND(COALESCE(SUM(p.kills), 0) / SUM(p.deaths), 2) END, "
                "CASE WHEN COUNT(*) = 0 THEN 0 ELSE ROUND(COALESCE(SUM(p.kills), 0) / COUNT(*), 2) END, "
                "CASE WHEN COUNT(*) = 0 THEN 0 ELSE ROUND(COALESCE(SUM(p.damage_done), 0) / COUNT(*), 0) END "
                "FROM `dc_hlbg_match_participants` p "
                "LEFT JOIN `dc_hlbg_winner_history` wh ON p.match_id = wh.id "
                "WHERE p.guid = %u",
                playerGuid);
        }
        else
        {
            AllTimeViewColumns const& columns = GetAllTimeViewColumns();

            if (!columns.IsComplete())
            {
                LOG_ERROR("dc.hlbg",
                    "v_hlbg_player_alltime_stats is missing one or more expected columns");
                outJson = "{"
                    "\"totalMatches\":0,\"lifetimeWins\":0,\"lifetimeLosses\":0,"
                    "\"lifetimeKills\":0,\"lifetimeDeaths\":0,\"kdRatio\":0,"
                    "\"avgKills\":0,\"avgDamage\":0"
                    "}";
                return true;
            }

            query = Acore::StringFormat(
                "SELECT "
                "IFNULL(%s, 0), "
                "IFNULL(%s, 0), "
                "IFNULL(%s, 0), "
                "IFNULL(%s, 0), "
                "IFNULL(%s, 0), "
                "IFNULL(%s, 0), "
                "IFNULL(%s, 0), "
                "IFNULL(%s, 0) "
                "FROM `v_hlbg_player_alltime_stats` "
                "WHERE guid = %u",
                columns.totalMatches,
                columns.totalWins,
                columns.totalLosses,
                columns.totalKills,
                columns.totalDeaths,
                columns.kdRatio,
                columns.avgKills,
                columns.avgDamage,
                playerGuid);
        }

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

    static bool GetCachedAllTimeStatsResponse(Player* player,
        std::string& outJson, std::string& outError)
    {
        if (!player)
        {
            outError = "Invalid player";
            return false;
        }

        uint32 const playerGuid = player->GetGUID().GetCounter();
        uint64 const nowMs = GetNowMs();

        {
            std::lock_guard<std::mutex> lock(s_responseCacheMutex);
            auto itr = s_cachedAllTimeStatsPayloads.find(playerGuid);
            if (itr != s_cachedAllTimeStatsPayloads.end()
                && itr->second.expiresAtMs > nowMs)
            {
                outJson = itr->second.response;
                return true;
            }
        }

        std::string response;
        if (!QueryPlayerAllTimeStats(player, response, outError))
            return false;

        CachedAllTimeStatsPayload payload;
        payload.response = response;
        payload.expiresAtMs = nowMs + HLBG_RESPONSE_CACHE_TTL_MS;

        std::lock_guard<std::mutex> lock(s_responseCacheMutex);
        s_cachedAllTimeStatsPayloads[playerGuid] = payload;
        outJson = payload.response;
        return true;
    }

    // =====================================================================
    // MESSAGE HANDLERS
    // =====================================================================

    // Real-time BG status handlers
    static void HandleRequestStatus(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;

        AuditAddonUiTransport(player);

        OutdoorPvPHL* hl = GetHL();
        uint32 mapId = player->GetMapId();
        uint32 timeRemaining = hl ? hl->GetTimeRemainingSeconds() : 0u;

        HLBGStatus status = STATUS_NONE;
        if (hl)
        {
            if (hl->IsPlayerAfkFlagged(player))
            {
                mapId = 0;
                timeRemaining = 0u;
            }
            else if (IsPlayerInOutdoorPvPHLArea(player))
                status = STATUS_ACTIVE;
            else if (hl->IsPlayerQueued(player))
                status = STATUS_QUEUED;
        }

        SendStatus(player, status, mapId, timeRemaining);

        // Queue UI polls CMSG_REQUEST_STATUS; mirror queue payload so clients
        // always get authoritative queue state even without an explicit 0x13 push.
        SendQueueInfo(player);
    }

    static void HandleRequestResources(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;

        AuditAddonUiTransport(player);

        OutdoorPvPHL* hl = GetHL();
        if (!hl)
        {
            SendResources(player, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
            return;
        }

        uint32 a = hl->GetResources(TEAM_ALLIANCE);
        uint32 h = hl->GetResources(TEAM_HORDE);
        LiveHudMetrics metrics = CollectLiveHudMetrics(hl);
        // HLBG doesn't track bases like AB; keep fields for forward-compat.
        SendResources(player, a, h, 0, 0,
            metrics.alliancePlayers, metrics.hordePlayers,
            metrics.alliancePlayerKills, metrics.hordePlayerKills,
            metrics.allianceNpcKills, metrics.hordeNpcKills);
    }

    static void HandleRequestObjective(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;

        AuditAddonUiTransport(player);

        Message response(Module::HINTERLAND, SMSG_ERROR);
        response.Add(std::string("Objectives not implemented for HLBG"));
        response.Send(player);
    }

    static void HandleQuickQueue(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;

        AuditAddonUiTransport(player);

        if (IsRateLimited(player, 800))
        {
            SendRateLimitedError(player);
            return;
        }

        if (OutdoorPvPHL* hl = GetHL())
            hl->QueueCommandFromAddon(player, "queue", "join");
        else
            ChatHandler(player->GetSession()).ParseCommands(".hlbg queue join");

        SendQueueInfo(player);
    }

    static void HandleLeaveQueue(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player) return;

        AuditAddonUiTransport(player);

        if (IsRateLimited(player, 800))
        {
            SendRateLimitedError(player);
            return;
        }

        if (OutdoorPvPHL* hl = GetHL())
                hl->QueueCommandFromAddon(player, "queue", "leave");
        else
            ChatHandler(player->GetSession()).ParseCommands(".hlbg queue leave");

        SendQueueInfo(player);
    }

    // Leaderboard and stats handlers
    static void HandleGetLeaderboard(Player* player, const ParsedMessage& msg)
    {
        if (!player) return;

        AuditAddonUiTransport(player);

        if (IsRateLimited(player, 800))
        {
            SendRateLimitedError(player);
            return;
        }

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

        std::string response;
        std::string error;

        if (!GetCachedSeasonalLeaderboardResponse(leaderboardType, season,
            limit, response, error))
        {
            Message packet(Module::HINTERLAND, SMSG_ERROR);
            packet.Add(error);
            packet.Send(player);
            return;
        }

        Message packet(Module::HINTERLAND, SMSG_LEADERBOARD_DATA);
        packet.Add(response);
        packet.Send(player);
    }

    static void HandleGetPlayerStats(Player* player, const ParsedMessage& msg)
    {
        if (!player) return;

        AuditAddonUiTransport(player);

        if (IsRateLimited(player, 800))
        {
            SendRateLimitedError(player);
            return;
        }

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

        AuditAddonUiTransport(player);

        if (IsRateLimited(player, 800))
        {
            SendRateLimitedError(player);
            return;
        }

        std::string statsJson;
        std::string error;

        if (!GetCachedAllTimeStatsResponse(player, statsJson, error))
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

    static bool HandleNativeLiveSnapshotRequest(Player* player)
    {
        if (!player)
            return false;

        if (!ResolveLiveSnapshotTransport(player).UsesNative())
            return false;

        SendNativeLiveSnapshot(player,
            BuildNativeLiveSnapshotPayload(player, GetHL()));
        return true;
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

        LOG_INFO("dc.addon", "HLBG unified handler registered with {} support",
            "real-time + leaderboards + unified schema");
    }

    class HLBGLiveNativeServerScript : public ServerScript
    {
    public:
        HLBGLiveNativeServerScript()
            : ServerScript("HLBGLiveNativeServerScript",
                { SERVERHOOK_CAN_PACKET_RECEIVE })
        {
        }

    private:
        bool CanPacketReceive(WorldSession* session,
            WorldPacket const& packet) override
        {
            if (packet.GetOpcode() != BridgeOpcode::CMSG_REQUEST_LIVE_SNAPSHOT)
                return true;

            if (!session)
                return false;

            Player* player = session->GetPlayer();
            if (!player || !player->IsInWorld())
                return false;

            bool handled = HandleNativeLiveSnapshotRequest(player);
            DCAddon::AuditNativeC2SRequest(player, Module::HINTERLAND, 0,
                BridgeOpcode::CMSG_REQUEST_LIVE_SNAPSHOT, packet.size(),
                "request", handled,
                handled ? std::string() : "Native HLBG live snapshot unavailable",
                handled ? std::string() : "native_transport_denied",
                handled ? std::string() : "Native HLBG live snapshot request rejected");
            return false;
        }
    };

}  // namespace HLBG
}  // namespace DCAddon

// Register the unified HLBG addon handler
void AddSC_dc_addon_hlbg()
{
    DCAddon::HLBG::RegisterHandlers();
    new DCAddon::HLBG::HLBGLiveNativeServerScript();
}

// Compatibility wrapper for legacy loader symbol
void AddSC_hlbg_addon()
{
    AddSC_dc_addon_hlbg();
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
