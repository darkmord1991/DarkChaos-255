/*
 * Dark Chaos - Unified Leaderboard Addon Handler
 * ===============================================
 *
 * Server-side handler for the DC-Leaderboards addon.
 * Provides leaderboard data for all DC systems via DCAddonProtocol.
 *
 * Supports:
 * - Mythic+ leaderboards (best key, best time, runs, score)
 * - Seasonal leaderboards (tokens, essence, points, level)
 * - Hinterland BG leaderboards (rating, wins, winrate, games)
 * - Prestige leaderboards (level, points, resets)
 * - Item Upgrade leaderboards (total, items, efficiency, tier)
 * - Duel leaderboards (wins, winrate, rating, streak)
 * - AOE Loot leaderboards (items, gold, skinned)
 * - Achievement leaderboards (points, completed)
 *
 * Uses JSON protocol for all responses.
 *
 * Copyright (C) 2025 DarkChaos Development Team
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "ObjectAccessor.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Config.h"
#include "../CrossSystem/LeaderboardUtils.h"
#include "../CrossSystem/CrossSystemSeasonHelper.h"
#include <cstdio>   // for snprintf
#include <cstdlib>  // for strtoul
#include <map>
#include <sstream>
#include <unordered_map>
#include <utility>  // for std::pair
#include <mutex>    // for cache thread safety

namespace
{
    // Module identifier for leaderboards
    constexpr const char* MODULE_LEADERBOARD = "LBRD";

    // Opcodes
    namespace Opcode
    {
        // Client -> Server
        constexpr uint8 CMSG_GET_LEADERBOARD = 0x01;
        constexpr uint8 CMSG_GET_CATEGORIES = 0x02;
        constexpr uint8 CMSG_GET_MY_RANK = 0x03;
        constexpr uint8 CMSG_REFRESH = 0x04;
        constexpr uint8 CMSG_TEST_TABLES = 0x05;
        constexpr uint8 CMSG_GET_SEASONS = 0x06;
        constexpr uint8 CMSG_GET_MPLUS_DUNGEONS = 0x07;  // v1.3.0: Get available M+ dungeons
        constexpr uint8 CMSG_GET_ACCOUNT_STATS = 0x08;   // v1.5.0: Get account-wide statistics

        // Server -> Client
        constexpr uint8 SMSG_LEADERBOARD_DATA = 0x10;
        constexpr uint8 SMSG_CATEGORIES = 0x11;
        constexpr uint8 SMSG_MY_RANK = 0x12;
        constexpr uint8 SMSG_TEST_RESULTS = 0x15;
        constexpr uint8 SMSG_SEASONS_LIST = 0x16;
        constexpr uint8 SMSG_MPLUS_DUNGEONS = 0x17;      // v1.3.0: M+ dungeon list response
        constexpr uint8 SMSG_ACCOUNT_STATS = 0x18;       // v1.5.0: Account statistics response
        constexpr uint8 SMSG_ERROR = 0x1F;
    }

    // Maximum entries per page
    constexpr uint32 MAX_ENTRIES_PER_PAGE = 50;
    constexpr uint32 DEFAULT_ENTRIES_PER_PAGE = 25;

    // ========================================================================
    // SERVER-SIDE CACHING
    // ========================================================================

    // Cache configuration - loaded from config, with defaults
    struct LeaderboardCacheConfig
    {
        uint32 lifetimeSeconds = 60;           // Default: 1 minute
        uint32 accountCacheLifetimeSeconds = 120;  // Default: 2 minutes for account stats
        uint32 maxCacheEntries = 100;          // Default: Max cached leaderboards

        void Load()
        {
            lifetimeSeconds = sConfigMgr->GetOption<uint32>("DC.Leaderboards.CacheLifetime", 60);
            accountCacheLifetimeSeconds = sConfigMgr->GetOption<uint32>("DC.Leaderboards.AccountCacheLifetime", 120);
            maxCacheEntries = sConfigMgr->GetOption<uint32>("DC.Leaderboards.MaxCacheEntries", 100);

            LOG_DEBUG("server.scripts", "DC-Leaderboards: Cache config loaded (lifetime={}s, account={}s, max={})",
                     lifetimeSeconds, accountCacheLifetimeSeconds, maxCacheEntries);
        }
    };

    static LeaderboardCacheConfig s_CacheConfig;

    static void SendRawJson(Player* player, uint8 opcode, std::string const& json, std::string requestId = {})
    {
        if (!player || !player->GetSession())
            return;

        if (requestId.empty())
            requestId = DCAddon::GetCurrentRequestId();
        if (!requestId.empty() && !DCAddon::IsSafeRequestId(requestId))
            requestId.clear();

        std::string msg_str = std::string(MODULE_LEADERBOARD) + "|" + std::to_string(opcode);
        if (!requestId.empty())
            msg_str += "|RID:" + requestId;
        msg_str += "|J|" + json;

        WorldPacket data;
        std::string fullMsg = std::string(DCAddon::DC_PREFIX) + "\t" + msg_str;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, fullMsg);
        player->SendDirectMessage(&data);

        if (!requestId.empty())
            DCAddon::NotifyResponseSent(player, requestId);
    }

    // Stage 2 native bridge: feature labels exported through
    // SMSG_DC_NATIVE_ENVELOPE for DC-Leaderboards responses. Mirrors the
    // existing SMSG_LEADERBOARD_DATA payload byte-for-byte so envelope
    // consumers can read GetLastDCNativeEnvelope("LBRD", <feature>).
    namespace StatsFeature
    {
        constexpr char LEADERBOARD[]     = "leaderboard";
        constexpr char ACTION_RESPONSE[] = "response";
    }

    static bool SupportsLeaderboardsNativeEnvelope(Player* player)
    {
        DCAddon::TransportPolicyRequest request;
        request.featureName = "leaderboards-stats";
        request.nativeCapability =
            DCAddon::ProtocolVersion::Capability::GENERIC_NATIVE_ENVELOPE;
        return DCAddon::ResolveTransportPolicy(player, request).UsesNative();
    }

    static uint32 NextLeaderboardRevision()
    {
        static std::atomic<uint32> s_revision{0};
        uint32 revision = ++s_revision;
        if (revision == 0)
            revision = ++s_revision;
        return revision;
    }

    static std::string ExtractLeaderboardRequestToken(DCAddon::JsonValue const& json)
    {
        if (!json.HasKey("requestToken"))
            return std::string();
        auto const& tok = json["requestToken"];
        if (tok.IsString())
            return tok.AsString();
        return std::string();
    }

    static void SendLeaderboardResponseEnvelope(Player* player, uint8 logicalOpcode,
        std::string const& feature, std::string const& payload,
        std::string const& requestToken)
    {
        if (!player || !SupportsLeaderboardsNativeEnvelope(player))
            return;

        DCAddon::SendNativeEnvelope(player, MODULE_LEADERBOARD, logicalOpcode,
            feature, StatsFeature::ACTION_RESPONSE, NextLeaderboardRevision(),
            payload, requestToken);
    }

    // Helper to access cache lifetime (for IsValid() checks)
    uint32 GetCacheLifetime() { return s_CacheConfig.lifetimeSeconds; }
    uint32 GetAccountCacheLifetime() { return s_CacheConfig.accountCacheLifetimeSeconds; }

    struct LeaderboardEntry
    {
        uint32 rank;
        std::string name;
        std::string className;
        uint32 score;
        std::string extra;
        // Extended fields for v1.3.0
        std::string score_str;   // For gold (uint64) sent as string
        uint32 mapId = 0;        // For M+ per-dungeon display

        // Extended fields consumed by the client UI
        // HLBG expects these for seasonal W/L and for all-time K/D displays
        bool hasWinsLosses = false;
        uint32 wins = 0;
        uint32 losses = 0;

        bool hasKD = false;
        uint32 kills = 0;
        uint32 deaths = 0;
        double kdRatio = 0.0;

        // AOE Loot expects separate quality columns in v1.4.0
        bool hasQuality = false;
        uint32 qLeg = 0;
        uint32 qEpic = 0;
        uint32 qRare = 0;
        uint32 qUncommon = 0;
    };

    // Structure for cached leaderboard data
    struct LeaderboardCacheEntry
    {
        std::vector<LeaderboardEntry> entries;
        uint32 totalEntries;
        time_t lastUpdate;

        bool IsValid() const
        {
            return (time(nullptr) - lastUpdate) < static_cast<time_t>(GetCacheLifetime());
        }
    };

    // Structure for cached account stats
    struct AccountStatsCacheEntry
    {
        std::string jsonResponse;
        time_t lastUpdate;

        bool IsValid() const
        {
            return (time(nullptr) - lastUpdate) < static_cast<time_t>(GetAccountCacheLifetime());
        }
    };

    // Global cache maps
    // Key format: "category_subcategory_seasonId_page_limit"
    std::unordered_map<std::string, LeaderboardCacheEntry> g_leaderboardCache;
    std::unordered_map<uint32, AccountStatsCacheEntry> g_accountStatsCache;  // Key: accountId
    std::mutex g_cacheMutex;  // Thread safety

    // Helper to generate cache key
    std::string MakeCacheKey(const std::string& category, const std::string& subcategory,
                             uint32 seasonId, uint32 page, uint32 limit)
    {
        return category + "_" + subcategory + "_" + std::to_string(seasonId) +
               "_" + std::to_string(page) + "_" + std::to_string(limit);
    }

    // ------------------------------------------------------------------
    // In-memory mirror of dc_mplus_featured_dungeons (small config table:
    // season_id, map_id, sort_order, dungeon_name). Loaded with ONE
    // synchronous WorldDatabase query on first use per uptime (and again
    // after HandleRefresh); every subsequent dungeon-name lookup and the
    // per-season dungeon list are served from memory, which removes the
    // former per-row N+1 name queries.
    // ------------------------------------------------------------------
    struct FeaturedDungeonCache
    {
        bool loaded = false;
        std::map<std::pair<uint32, uint16>, std::string> nameBySeasonAndMap;
        std::map<uint16, std::string> nameByMap;  // highest-season name per map (fallback)
        std::map<uint32, std::vector<std::pair<uint16, std::string>>> dungeonsBySeason;  // ordered by sort_order
    };

    FeaturedDungeonCache g_dungeonCache;
    std::mutex g_dungeonCacheMutex;

    // Caller must hold g_dungeonCacheMutex.
    void EnsureDungeonCacheLoaded()
    {
        if (g_dungeonCache.loaded)
            return;

        g_dungeonCache.nameBySeasonAndMap.clear();
        g_dungeonCache.nameByMap.clear();
        g_dungeonCache.dungeonsBySeason.clear();

        // Ascending season order so nameByMap ends up holding the highest
        // season's name per map, matching the old
        // "ORDER BY season_id DESC LIMIT 1" fallback query.
        if (QueryResult result = WorldDatabase.Query(
            "SELECT season_id, map_id, dungeon_name FROM dc_mplus_featured_dungeons "
            "ORDER BY season_id ASC, sort_order ASC"))
        {
            do
            {
                Field* fields = result->Fetch();
                uint32 seasonId = fields[0].Get<uint32>();
                uint16 mapId = fields[1].Get<uint16>();
                std::string name = fields[2].Get<std::string>();

                g_dungeonCache.nameBySeasonAndMap[{seasonId, mapId}] = name;
                g_dungeonCache.nameByMap[mapId] = name;
                g_dungeonCache.dungeonsBySeason[seasonId].emplace_back(mapId, std::move(name));
            } while (result->NextRow());
        }

        g_dungeonCache.loaded = true;
    }

    // Clear all caches
    void ClearAllCaches()
    {
        {
            std::lock_guard<std::mutex> lock(g_cacheMutex);
            g_leaderboardCache.clear();
            g_accountStatsCache.clear();
        }
        {
            std::lock_guard<std::mutex> lock(g_dungeonCacheMutex);
            g_dungeonCache.loaded = false;  // reload dc_mplus_featured_dungeons on next use
        }
        LOG_DEBUG("server.scripts", "DC-Leaderboards: All caches cleared");
    }

    // Forward declarations
    uint32 GetCurrentSeasonId();
    std::string GetDungeonNameForMap(uint16 mapId, uint32 seasonId = 0);

    // Use centralized utilities from LeaderboardUtils.h to avoid duplication
    using DarkChaos::Leaderboard::JsonEscape;
    using DarkChaos::Leaderboard::GetClassNameFromId;

    // ========================================================================
    // LEADERBOARD DATA FETCHERS
    // ========================================================================

    // Mythic+ leaderboard (history or per-player aggregate views)
    // Note: dc_mplus_scores table has: character_guid, season_id, map_id, best_level, best_score, last_run_ts, total_runs
    std::string BuildMythicPlusLeaderboardSql(const std::string& subcat, uint32 seasonId, uint32 limit, uint32 offset,
        uint32 requesterGuid, bool myRunsOnly)
    {
        if (subcat == "mplus_history")
        {
            if (myRunsOnly && requesterGuid > 0)
            {
                return Acore::StringFormat(
                    "SELECT c.name, c.class, r.keystone_level, r.map_id, COALESCE(r.completion_time, 0), r.success, DATE_FORMAT(r.completed_at, '%Y-%m-%d %H:%i') "
                    "FROM dc_mplus_runs r "
                    "JOIN characters c ON r.character_guid = c.guid "
                    "WHERE r.season_id = {} AND r.character_guid = {} "
                    "ORDER BY r.completed_at DESC, r.run_id DESC "
                    "LIMIT {} OFFSET {}",
                    seasonId, requesterGuid, limit, offset);
            }

            return Acore::StringFormat(
                "SELECT c.name, c.class, r.keystone_level, r.map_id, COALESCE(r.completion_time, 0), r.success, DATE_FORMAT(r.completed_at, '%Y-%m-%d %H:%i') "
                "FROM dc_mplus_runs r "
                "JOIN characters c ON r.character_guid = c.guid "
                "WHERE r.season_id = {} "
                "ORDER BY r.completed_at DESC, r.run_id DESC "
                "LIMIT {} OFFSET {}",
                seasonId, limit, offset);
        }

        // Use aggregate function aliases in ORDER BY for sql_mode=only_full_group_by compatibility
        std::string orderBy = "best_level DESC, total_score DESC";
        if (subcat == "mplus_runs")
            orderBy = "total_runs DESC, best_level DESC";
        else if (subcat == "mplus_score")
            orderBy = "total_score DESC, best_level DESC";

        // Aggregate per-player across all dungeons for the season
        return Acore::StringFormat(
            "SELECT c.name, c.class, MAX(s.best_level) as best_level, SUM(s.best_score) as total_score, SUM(s.total_runs) as total_runs "
            "FROM dc_mplus_scores s "
            "JOIN characters c ON s.character_guid = c.guid "
            "WHERE s.season_id = {} "
            "GROUP BY s.character_guid, c.name, c.class "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            seasonId, orderBy, limit, offset);
    }

    std::vector<LeaderboardEntry> ParseMythicPlusLeaderboard(QueryResult result, const std::string& subcat,
        uint32 seasonId, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        if (subcat == "mplus_history")
        {
            auto formatDuration = [](uint32 seconds) -> std::string
            {
                if (seconds == 0)
                    return "--:--";

                uint32 hours = seconds / 3600;
                uint32 minutes = (seconds % 3600) / 60;
                uint32 secs = seconds % 60;

                char buffer[16];
                if (hours > 0)
                    std::snprintf(buffer, sizeof(buffer), "%u:%02u:%02u", hours, minutes, secs);
                else
                    std::snprintf(buffer, sizeof(buffer), "%02u:%02u", minutes, secs);

                return std::string(buffer);
            };

            uint32 rank = offset + 1;
            do
            {
                Field* fields = result->Fetch();
                LeaderboardEntry entry;
                entry.rank = rank++;
                entry.name = fields[0].Get<std::string>();
                entry.className = GetClassNameFromId(fields[1].Get<uint8>());
                entry.score = fields[2].Get<uint32>();

                uint16 mapId = fields[3].Get<uint16>();
                uint32 completionTime = fields[4].Get<uint32>();
                bool success = fields[5].Get<uint8>() != 0;
                std::string completedAt = fields[6].Get<std::string>();
                std::string dungeonName = GetDungeonNameForMap(mapId, seasonId);

                entry.mapId = mapId;
                entry.extra = dungeonName + " | " + formatDuration(completionTime) + " | " +
                    (success ? "Success" : "Failed") + " | " + completedAt;

                entries.push_back(entry);
            } while (result->NextRow());

            return entries;
        }

        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());

            if (subcat == "mplus_runs")
            {
                entry.score = fields[4].Get<uint32>();  // total_runs
                entry.extra = "M+" + std::to_string(fields[2].Get<uint32>()) + " best";
            }
            else if (subcat == "mplus_score")
            {
                entry.score = fields[3].Get<uint32>();  // total_score
                entry.extra = std::to_string(fields[4].Get<uint32>()) + " runs";
            }
            else  // mplus_key (default)
            {
                entry.score = fields[2].Get<uint32>();  // best_level
                entry.extra = std::to_string(fields[4].Get<uint32>()) + " runs";
            }

            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Get dungeon name from the in-memory dc_mplus_featured_dungeons cache:
    // season-specific row -> highest-season row -> "Dungeon #<mapId>"
    std::string GetDungeonNameForMap(uint16 mapId, uint32 seasonId)
    {
        std::lock_guard<std::mutex> lock(g_dungeonCacheMutex);
        EnsureDungeonCacheLoaded();

        if (seasonId > 0)
        {
            auto it = g_dungeonCache.nameBySeasonAndMap.find({seasonId, mapId});
            if (it != g_dungeonCache.nameBySeasonAndMap.end())
                return it->second;
        }

        auto it = g_dungeonCache.nameByMap.find(mapId);
        if (it != g_dungeonCache.nameByMap.end())
            return it->second;

        return "Dungeon #" + std::to_string(mapId);
    }

    // Get available M+ dungeons for a season from the in-memory cache
    std::vector<std::pair<uint16, std::string>> GetMythicPlusDungeons(uint32 seasonId)
    {
        std::lock_guard<std::mutex> lock(g_dungeonCacheMutex);
        EnsureDungeonCacheLoaded();

        auto it = g_dungeonCache.dungeonsBySeason.find(seasonId);
        if (it != g_dungeonCache.dungeonsBySeason.end())
            return it->second;

        return {};
    }

    // Mythic+ leaderboard for a specific dungeon
    // v1.3.0: per-dungeon leaderboards with dungeon name display
    std::string BuildMythicPlusDungeonLeaderboardSql(uint16 mapId, uint32 seasonId, uint32 limit, uint32 offset)
    {
        // Query best runs for this specific dungeon
        return Acore::StringFormat(
            "SELECT c.name, c.class, s.best_level, s.best_score, s.total_runs, s.map_id "
            "FROM dc_mplus_scores s "
            "JOIN characters c ON s.character_guid = c.guid "
            "WHERE s.season_id = {} AND s.map_id = {} "
            "ORDER BY s.best_level DESC, s.best_score DESC "
            "LIMIT {} OFFSET {}",
            seasonId, mapId, limit, offset);
    }

    std::vector<LeaderboardEntry> ParseMythicPlusDungeonLeaderboard(QueryResult result, uint16 mapId,
        uint32 seasonId, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        std::string dungeonName = GetDungeonNameForMap(mapId, seasonId);

        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            entry.score = fields[2].Get<uint32>();  // best_level
            entry.mapId = fields[5].Get<uint16>();

            // Extra shows dungeon name and total runs
            entry.extra = dungeonName + " (" + std::to_string(fields[4].Get<uint32>()) + " runs)";

            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Mythic+ best dungeon runs per player (shows their best dungeon)
    // v1.3.0: Shows which dungeon each player performed best in
    std::string BuildMythicPlusBestRunsSql(uint32 seasonId, uint32 limit, uint32 offset)
    {
        // Get each player's best single dungeon run (highest level)
        return Acore::StringFormat(
            "SELECT c.name, c.class, s.best_level, s.best_score, s.total_runs, s.map_id "
            "FROM dc_mplus_scores s "
            "JOIN characters c ON s.character_guid = c.guid "
            "WHERE s.season_id = {} AND s.best_level = ("
            "    SELECT MAX(s2.best_level) FROM dc_mplus_scores s2 "
            "    WHERE s2.character_guid = s.character_guid AND s2.season_id = s.season_id"
            ") "
            "ORDER BY s.best_level DESC, s.best_score DESC "
            "LIMIT {} OFFSET {}",
            seasonId, limit, offset);
    }

    std::vector<LeaderboardEntry> ParseMythicPlusBestRuns(QueryResult result, uint32 seasonId, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            entry.score = fields[2].Get<uint32>();  // best_level
            entry.mapId = fields[5].Get<uint16>();

            // Dungeon name comes from the in-memory featured-dungeons cache
            entry.extra = GetDungeonNameForMap(entry.mapId, seasonId);

            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Seasonal leaderboard
    // Table: dc_player_seasonal_stats with fields: total_tokens_earned, total_essence_earned, quests_completed, bosses_killed
    std::string BuildSeasonalLeaderboardSql(const std::string& subcat, uint32 seasonId, uint32 limit, uint32 offset)
    {
        std::string orderBy = "d.total_tokens_earned DESC";
        std::string selectField = "d.total_tokens_earned";

        if (subcat == "season_essence")
        {
            orderBy = "d.total_essence_earned DESC";
            selectField = "d.total_essence_earned";
        }
        else if (subcat == "season_quests")
        {
            orderBy = "d.quests_completed DESC";
            selectField = "d.quests_completed";
        }
        else if (subcat == "season_bosses")
        {
            orderBy = "(d.dungeon_bosses_killed + d.world_bosses_killed) DESC";
            selectField = "(d.dungeon_bosses_killed + d.world_bosses_killed)";
        }

        return Acore::StringFormat(
            "SELECT c.name, c.class, {}, d.total_tokens_earned, d.total_essence_earned, d.quests_completed "
            "FROM dc_player_seasonal_stats d "
            "JOIN characters c ON d.player_guid = c.guid "
            "WHERE d.season_id = {} "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            selectField, seasonId, orderBy, limit, offset);
    }

    std::vector<LeaderboardEntry> ParseSeasonalLeaderboard(QueryResult result, const std::string& subcat, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            entry.score = fields[2].Get<uint32>();

            if (subcat == "season_quests" || subcat == "season_bosses")
            {
                entry.extra = std::to_string(fields[3].Get<uint32>()) + " tokens";
            }
            else
            {
                entry.extra = std::to_string(fields[5].Get<uint32>()) + " quests";
            }

            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Hinterland BG leaderboard
    // Sources:
    //   - v_hlbg_player_seasonal_stats: unified seasonal aggregation
    //   - dc_hlbg_player_stats: all-time kill/win/resource counters
    bool IsHLBGOverallSubcategory(const std::string& subcat)
    {
        return subcat == "hlbg_kills" || subcat == "hlbg_alltime_wins" || subcat == "hlbg_resources";
    }

    std::string BuildHLBGLeaderboardSql(const std::string& subcat, uint32 seasonId, uint32 limit, uint32 offset)
    {
        if (IsHLBGOverallSubcategory(subcat))
        {
            // Use dc_hlbg_player_stats for all-time stats
            std::string orderBy = "h.total_kills DESC";
            if (subcat == "hlbg_alltime_wins")
                orderBy = "h.battles_won DESC";
            else if (subcat == "hlbg_resources")
                orderBy = "h.resources_captured DESC";

            return Acore::StringFormat(
                "SELECT c.name, c.class, h.battles_won, h.total_kills, h.total_deaths, h.resources_captured, h.battles_participated "
                "FROM dc_hlbg_player_stats h "
                "JOIN characters c ON h.player_guid = c.guid "
                "ORDER BY {} "
                "LIMIT {} OFFSET {}",
                orderBy, limit, offset);
        }

        // Use v_hlbg_player_seasonal_stats view for seasonal stats (unified schema)
        std::string orderBy = "v.current_rating DESC";
        if (subcat == "hlbg_wins")
            orderBy = "v.wins DESC";
        else if (subcat == "hlbg_winrate")
            orderBy = "v.win_rate DESC";
        else if (subcat == "hlbg_games")
            orderBy = "v.games_played DESC";

        return Acore::StringFormat(
            "SELECT c.name, c.class, v.current_rating, v.wins, v.losses "
            "FROM v_hlbg_player_seasonal_stats v "
            "JOIN characters c ON v.guid = c.guid "
            "WHERE v.season_id = {} "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            seasonId, orderBy, limit, offset);
    }

    std::vector<LeaderboardEntry> ParseHLBGLeaderboard(QueryResult result, const std::string& subcat, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        if (IsHLBGOverallSubcategory(subcat))
        {
            uint32 rank = offset + 1;
            do
            {
                Field* fields = result->Fetch();
                LeaderboardEntry entry;
                entry.rank = rank++;
                entry.name = fields[0].Get<std::string>();
                entry.className = GetClassNameFromId(fields[1].Get<uint8>());

                uint32 wins = fields[2].Get<uint32>();
                uint32 kills = fields[3].Get<uint32>();
                uint32 deaths = fields[4].Get<uint32>();
                uint32 resources = fields[5].Get<uint32>();
                uint32 battles = fields[6].Get<uint32>();

                // Client UI uses these fields for K/D rendering in several HLBG subcats
                entry.hasKD = true;
                entry.kills = kills;
                entry.deaths = deaths;
                entry.kdRatio = deaths > 0 ? (static_cast<double>(kills) / deaths) : static_cast<double>(kills);

                if (subcat == "hlbg_alltime_wins")
                {
                    entry.score = wins;
                    entry.extra = std::to_string(battles) + " battles";
                }
                else if (subcat == "hlbg_resources")
                {
                    entry.score = resources;
                    entry.extra = std::to_string(kills) + " kills";
                }
                else  // hlbg_kills
                {
                    entry.score = kills;
                    float kd = deaths > 0 ? (static_cast<float>(kills) / deaths) : static_cast<float>(kills);
                    char kdBuf[16];
                    snprintf(kdBuf, sizeof(kdBuf), "%.2f K/D", kd);
                    entry.extra = kdBuf;
                }

                entries.push_back(entry);
            } while (result->NextRow());

            return entries;
        }

        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());

            uint32 wins = fields[3].Get<uint32>();
            uint32 losses = fields[4].Get<uint32>();
            uint32 totalGames = wins + losses;
            float winRate = totalGames > 0 ? (static_cast<float>(wins) / totalGames * 100.0f) : 0.0f;

            // Client UI expects wins/losses to render the extra column
            entry.hasWinsLosses = true;
            entry.wins = wins;
            entry.losses = losses;

            if (subcat == "hlbg_wins")
            {
                entry.score = wins;
                entry.extra = std::to_string(losses) + " losses";
            }
            else if (subcat == "hlbg_winrate")
            {
                entry.score = static_cast<uint32>(winRate * 10);  // Store as x10 for precision
                entry.extra = std::to_string(totalGames) + " games";
            }
            else if (subcat == "hlbg_games")
            {
                entry.score = totalGames;
                entry.extra = std::to_string(wins) + "W/" + std::to_string(losses) + "L";
            }
            else  // hlbg_rating
            {
                entry.score = fields[2].Get<uint32>();
                entry.extra = std::to_string(wins) + "W/" + std::to_string(losses) + "L";
            }

            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Get Prestige / Artifact Mastery leaderboard
    // Client category "prestige" is labeled "Artifact Mastery" and expects:
    //   - prestige_level     => mastery level
    //   - prestige_points    => total points
    //   - prestige_artifacts => artifacts unlocked
    // Schema tables:
    //   - dc_player_artifact_mastery (per artifact)
    // Legacy subcat "prestige_resets" still uses dc_character_prestige.
    std::string BuildPrestigeLeaderboardSql(const std::string& subcat, uint32 limit, uint32 offset)
    {
        // Legacy: prestige resets leaderboard
        if (subcat == "prestige_resets")
        {
            return Acore::StringFormat(
                "SELECT c.name, c.class, p.prestige_level, p.total_prestiges, p.last_prestige_time "
                "FROM dc_character_prestige p "
                "JOIN characters c ON p.guid = c.guid "
                "WHERE p.prestige_level > 0 OR p.total_prestiges > 0 "
                "ORDER BY p.total_prestiges DESC, p.prestige_level DESC "
                "LIMIT {} OFFSET {}",
                limit, offset);
        }

        // Artifact Mastery leaderboards (default for "prestige" category)
        std::string orderBy = "mastery_level DESC, total_points DESC";
        if (subcat == "prestige_points")
            orderBy = "total_points DESC, mastery_level DESC";
        else if (subcat == "prestige_artifacts")
            orderBy = "artifacts_unlocked DESC, total_points DESC";

        return Acore::StringFormat(
            "SELECT c.name, c.class, "
            "MAX(am.mastery_level) as mastery_level, "
            "SUM(am.total_points_earned) as total_points, "
            "COUNT(DISTINCT IF(am.mastery_level > 0 OR am.unlocked_at IS NOT NULL, am.artifact_id, NULL)) as artifacts_unlocked "
            "FROM dc_player_artifact_mastery am "
            "JOIN characters c ON am.player_guid = c.guid "
            "WHERE am.mastery_level > 0 OR am.total_points_earned > 0 OR am.unlocked_at IS NOT NULL "
            "GROUP BY am.player_guid, c.name, c.class "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            orderBy, limit, offset);
    }

    std::vector<LeaderboardEntry> ParsePrestigeLeaderboard(QueryResult result, const std::string& subcat, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        // Legacy: prestige resets leaderboard
        if (subcat == "prestige_resets")
        {
            uint32 rank = offset + 1;
            do
            {
                Field* fields = result->Fetch();
                LeaderboardEntry entry;
                entry.rank = rank++;
                entry.name = fields[0].Get<std::string>();
                entry.className = GetClassNameFromId(fields[1].Get<uint8>());

                uint32 prestigeLevel = fields[2].Get<uint32>();
                uint32 totalPrestiges = fields[3].Get<uint32>();
                entry.score = totalPrestiges;
                entry.extra = "P" + std::to_string(prestigeLevel);

                entries.push_back(entry);
            } while (result->NextRow());

            return entries;
        }

        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());

            uint32 masteryLevel = fields[2].Get<uint32>();
            uint32 totalPoints = fields[3].Get<uint32>();
            uint32 artifactsUnlocked = fields[4].Get<uint32>();

            if (subcat == "prestige_points")
            {
                entry.score = totalPoints;
                entry.extra = "Lvl " + std::to_string(masteryLevel) + ", " + std::to_string(artifactsUnlocked) + " artifacts";
            }
            else if (subcat == "prestige_artifacts")
            {
                entry.score = artifactsUnlocked;
                entry.extra = "Lvl " + std::to_string(masteryLevel) + ", " + std::to_string(totalPoints) + " pts";
            }
            else  // prestige_level (default)
            {
                entry.score = masteryLevel;
                entry.extra = std::to_string(totalPoints) + " pts";
            }

            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Item Upgrade leaderboard
    // Uses dc_item_upgrades table: player_guid, tier_id, upgrade_level, tokens_invested, essence_invested
    std::string BuildUpgradeLeaderboardSql(const std::string& subcat, uint32 seasonId, uint32 limit, uint32 offset)
    {
        std::string orderBy = "total_tokens DESC";
        if (subcat == "upgrade_items")
            orderBy = "item_count DESC";
        else if (subcat == "upgrade_essence")
            orderBy = "total_essence DESC";
        else if (subcat == "upgrade_tier")
            orderBy = "highest_tier DESC, total_tokens DESC";

        // Aggregate upgrades per player from dc_item_upgrades
        return Acore::StringFormat(
            "SELECT c.name, c.class, "
            "SUM(u.tokens_invested) as total_tokens, "
            "SUM(u.essence_invested) as total_essence, "
            "COUNT(DISTINCT u.item_guid) as item_count, "
            "MAX(u.tier_id) as highest_tier "
            "FROM dc_item_upgrades u "
            "JOIN characters c ON u.player_guid = c.guid "
            "WHERE u.season = {} OR u.season = 0 "
            "GROUP BY u.player_guid, c.name, c.class "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            seasonId, orderBy, limit, offset);
    }

    std::vector<LeaderboardEntry> ParseUpgradeLeaderboard(QueryResult result, const std::string& subcat, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());

            uint32 tokens = fields[2].Get<uint32>();
            uint32 essence = fields[3].Get<uint32>();
            uint32 itemCount = fields[4].Get<uint32>();
            uint32 tier = fields[5].Get<uint32>();

            if (subcat == "upgrade_items")
            {
                entry.score = itemCount;
                entry.extra = std::to_string(tokens) + " tokens spent";
            }
            else if (subcat == "upgrade_essence")
            {
                entry.score = essence;
                entry.extra = std::to_string(itemCount) + " items";
            }
            else if (subcat == "upgrade_tier")
            {
                entry.score = tier;
                entry.extra = std::to_string(itemCount) + " items upgraded";
            }
            else  // upgrade_tokens (default)
            {
                entry.score = tokens;
                entry.extra = std::to_string(itemCount) + " items";
            }

            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Duel leaderboard
    // Table: dc_duel_statistics with fields: player_guid, wins, losses, draws, total_damage_dealt
    std::string BuildDuelLeaderboardSql(const std::string& subcat, uint32 limit, uint32 offset)
    {
        std::string orderBy = "d.wins DESC";
        if (subcat == "duel_winrate")
            orderBy = "(CAST(d.wins AS FLOAT) / GREATEST(d.wins + d.losses, 1)) DESC";
        else if (subcat == "duel_total")
            orderBy = "(d.wins + d.losses + d.draws) DESC";
        else if (subcat == "duel_damage")
            orderBy = "d.total_damage_dealt DESC";

        return Acore::StringFormat(
            "SELECT c.name, c.class, d.wins, d.losses, d.draws, d.total_damage_dealt "
            "FROM dc_duel_statistics d "
            "JOIN characters c ON d.player_guid = c.guid "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            orderBy, limit, offset);
    }

    std::vector<LeaderboardEntry> ParseDuelLeaderboard(QueryResult result, const std::string& subcat, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());

            uint32 wins = fields[2].Get<uint32>();
            uint32 losses = fields[3].Get<uint32>();
            uint32 draws = fields[4].Get<uint32>();
            uint64 damage = fields[5].Get<uint64>();
            uint32 totalGames = wins + losses + draws;
            float winRate = totalGames > 0 ? (static_cast<float>(wins) / totalGames * 100.0f) : 0.0f;

            if (subcat == "duel_winrate")
            {
                entry.score = static_cast<uint32>(winRate * 10);
                entry.extra = std::to_string(totalGames) + " duels";
            }
            else if (subcat == "duel_total")
            {
                entry.score = totalGames;
                entry.extra = std::to_string(wins) + "W/" + std::to_string(losses) + "L/" + std::to_string(draws) + "D";
            }
            else if (subcat == "duel_damage")
            {
                entry.score = static_cast<uint32>(damage / 1000);  // Display as thousands
                entry.extra = std::to_string(wins) + " wins";
            }
            else  // duel_wins
            {
                entry.score = wins;
                entry.extra = std::to_string(losses) + " losses";
            }

            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // AOE Loot leaderboard
    // Table: dc_aoeloot_detailed_stats with quality breakdown columns
    // Simplified to 3 views: aoe_items (looted + quality), aoe_filtered (filtered + quality), aoe_gold
    std::string BuildAOELeaderboardSql(const std::string& subcat, uint32 limit, uint32 offset)
    {
        std::string orderBy = "a.total_items DESC";
        if (subcat == "aoe_gold")
        {
            orderBy = "a.total_gold DESC";
        }
        else if (subcat == "aoe_filtered")
        {
            // Order by total filtered items
            orderBy = "(COALESCE(a.filtered_poor, 0) + COALESCE(a.filtered_common, 0) + COALESCE(a.filtered_uncommon, 0) + "
                      "COALESCE(a.filtered_rare, 0) + COALESCE(a.filtered_epic, 0) + COALESCE(a.filtered_legendary, 0)) DESC";
        }
        // aoe_items uses default order by total_items

        return Acore::StringFormat(
            "SELECT c.name, c.class, a.total_items, a.total_gold, a.upgrades, a.skinned, a.vendor_gold, "
            "COALESCE(a.quality_poor, 0), COALESCE(a.quality_common, 0), COALESCE(a.quality_uncommon, 0), "
            "COALESCE(a.quality_rare, 0), COALESCE(a.quality_epic, 0), COALESCE(a.quality_legendary, 0), "
            "COALESCE(a.filtered_poor, 0), COALESCE(a.filtered_common, 0), COALESCE(a.filtered_uncommon, 0), "
            "COALESCE(a.filtered_rare, 0), COALESCE(a.filtered_epic, 0), COALESCE(a.filtered_legendary, 0) "
            "FROM dc_aoeloot_detailed_stats a "
            "JOIN characters c ON a.player_guid = c.guid "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            orderBy, limit, offset);
    }

    std::vector<LeaderboardEntry> ParseAOELeaderboard(QueryResult result, const std::string& subcat, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());

            uint32 items = fields[2].Get<uint32>();
            uint64 totalGold = fields[3].Get<uint64>();  // In copper
            // Future: These fields are queried but not yet exposed in the UI
            // uint32 upgrades = fields[4].Get<uint32>();
            // uint32 skinned = fields[5].Get<uint32>();
            // uint64 vendorGold = fields[6].Get<uint64>();
            (void)fields[4];  // upgrades - reserved for future use
            (void)fields[5];  // skinned - reserved for future use
            (void)fields[6];  // vendorGold - reserved for future use

            // Quality breakdown for looted items
            uint32 qPoor = fields[7].Get<uint32>();
            uint32 qCommon = fields[8].Get<uint32>();
            uint32 qUncommon = fields[9].Get<uint32>();
            uint32 qRare = fields[10].Get<uint32>();
            uint32 qEpic = fields[11].Get<uint32>();
            uint32 qLegendary = fields[12].Get<uint32>();

            // Quality breakdown for filtered/skipped items
            uint32 fPoor = fields[13].Get<uint32>();
            uint32 fCommon = fields[14].Get<uint32>();
            uint32 fUncommon = fields[15].Get<uint32>();
            uint32 fRare = fields[16].Get<uint32>();
            uint32 fEpic = fields[17].Get<uint32>();
            uint32 fLegendary = fields[18].Get<uint32>();

            if (subcat == "aoe_gold")
            {
                // Gold view: send as string to avoid uint32 truncation (max 4.2B copper = 429k gold)
                // Client will parse and format with FormatMoney()
                entry.score = 0;  // Set to 0, use score_str instead
                entry.score_str = std::to_string(totalGold);  // Full uint64 as string
                entry.extra = std::to_string(items) + " items";
            }
            else if (subcat == "aoe_filtered")
            {
                // Client expects separate quality columns to be populated from filtered_* counts
                entry.hasQuality = true;
                entry.qLeg = fLegendary;
                entry.qEpic = fEpic;
                entry.qRare = fRare;
                entry.qUncommon = fUncommon;

                // Filtered items view with quality breakdown
                uint32 totalFiltered = fPoor + fCommon + fUncommon + fRare + fEpic + fLegendary;
                entry.score = totalFiltered;

                // Format: "P:X C:X U:X R:X" with colors
                std::ostringstream oss;
                if (fPoor > 0) oss << "|cff9d9d9dP:" << fPoor << "|r ";
                if (fCommon > 0) oss << "C:" << fCommon << " ";
                if (fUncommon > 0) oss << "|cff1eff00U:" << fUncommon << "|r ";
                if (fRare > 0) oss << "|cff0070ddR:" << fRare << "|r ";
                if (fEpic > 0) oss << "|cffa335eeE:" << fEpic << "|r ";
                if (fLegendary > 0) oss << "|cffff8000L:" << fLegendary << "|r";
                entry.extra = oss.str();
                if (entry.extra.empty())
                    entry.extra = "None filtered";
            }
            else  // aoe_items (default)
            {
                // Client expects separate quality columns to be populated from quality_* counts
                entry.hasQuality = true;
                entry.qLeg = qLegendary;
                entry.qEpic = qEpic;
                entry.qRare = qRare;
                entry.qUncommon = qUncommon;

                // Items view with quality breakdown
                entry.score = items;

                // Format: "L:X E:X R:X U:X" with colors (from best to worst)
                std::ostringstream oss;
                if (qLegendary > 0) oss << "|cffff8000L:" << qLegendary << "|r ";
                if (qEpic > 0) oss << "|cffa335eeE:" << qEpic << "|r ";
                if (qRare > 0) oss << "|cff0070ddR:" << qRare << "|r ";
                if (qUncommon > 0) oss << "|cff1eff00U:" << qUncommon << "|r";
                entry.extra = oss.str();
                if (entry.extra.empty())
                {
                    // Fallback: show common + poor count
                    entry.extra = std::to_string(qCommon + qPoor) + " common/poor";
                }
            }

            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Achievement leaderboard
    // Table: dc_player_achievements with fields: player_guid, achievement_id, progress, completed
    std::string BuildAchievementLeaderboardSql(const std::string& subcat, uint32 limit, uint32 offset)
    {
        std::string orderBy = "total_completed DESC";
        if (subcat == "achieve_progress")
            orderBy = "total_progress DESC";

        // Aggregate achievements per player
        return Acore::StringFormat(
            "SELECT c.name, c.class, SUM(a.completed) as total_completed, SUM(a.progress) as total_progress "
            "FROM dc_player_achievements a "
            "JOIN characters c ON a.player_guid = c.guid "
            "GROUP BY a.player_guid, c.name, c.class "
            "ORDER BY {} "
            "LIMIT {} OFFSET {}",
            orderBy, limit, offset);
    }

    std::vector<LeaderboardEntry> ParseAchievementLeaderboard(QueryResult result, const std::string& subcat, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        uint32 rank = offset + 1;
        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.rank = rank++;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());

            uint32 completed = fields[2].Get<uint32>();
            uint32 progress = fields[3].Get<uint32>();

            if (subcat == "achieve_progress")
            {
                entry.score = progress;
                entry.extra = std::to_string(completed) + " completed";
            }
            else  // achieve_completed (default)
            {
                entry.score = completed;
                entry.extra = std::to_string(progress) + " progress";
            }

            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Build the total-entry-count query for pagination (all sources live in the
    // character DB). Empty string = unknown category (no query to run).
    std::string BuildTotalEntryCountSql(const std::string& category, const std::string& subcat, uint32 seasonId,
        bool myRunsOnly, uint32 requesterGuid)
    {
        // Handle seasonId = 0 as current season
        if (seasonId == 0)
            seasonId = GetCurrentSeasonId();

        if (category == "mplus")
        {
            if (subcat == "mplus_history")
            {
                if (myRunsOnly && requesterGuid > 0)
                    return Acore::StringFormat(
                        "SELECT COUNT(*) FROM dc_mplus_runs WHERE season_id = {} AND character_guid = {}",
                        seasonId, requesterGuid);
                return Acore::StringFormat("SELECT COUNT(*) FROM dc_mplus_runs WHERE season_id = {}", seasonId);
            }
            return Acore::StringFormat(
                "SELECT COUNT(DISTINCT character_guid) FROM dc_mplus_scores WHERE season_id = {}", seasonId);
        }

        if (category == "seasons")
            return Acore::StringFormat(
                "SELECT COUNT(*) FROM dc_player_seasonal_stats WHERE season_id = {}", seasonId);

        if (category == "hlbg")
        {
            if (IsHLBGOverallSubcategory(subcat))
                return "SELECT COUNT(*) FROM dc_hlbg_player_stats";
            return Acore::StringFormat(
                "SELECT COUNT(DISTINCT guid) FROM v_hlbg_player_seasonal_stats WHERE season_id = {}", seasonId);
        }

        if (category == "prestige")
            return "SELECT COUNT(DISTINCT player_guid) FROM dc_player_artifact_mastery";

        if (category == "upgrade")
            return Acore::StringFormat(
                "SELECT COUNT(DISTINCT player_guid) FROM dc_item_upgrades WHERE season = {} OR season = 0", seasonId);

        if (category == "duel")
            return "SELECT COUNT(*) FROM dc_duel_statistics";

        if (category == "aoe")
        {
            // Use dc_aoeloot_detailed_stats which is populated by dc_aoeloot_extensions.cpp
            return "SELECT COUNT(*) FROM dc_aoeloot_detailed_stats";
        }

        if (category == "achieve")
            return "SELECT COUNT(DISTINCT player_guid) FROM dc_player_achievements";

        return std::string();
    }

    // Build the player-rank query for HandleGetMyRank. Empty string = no rank
    // source implemented for this category/subcategory.
    // This is a simplified version - a full implementation would use window
    // functions or subqueries to get the exact rank per category.
    std::string BuildPlayerRankSql(uint32 requesterGuid, const std::string& category, const std::string& subcat,
        uint32 seasonId)
    {
        if (category == "mplus" && subcat == "mplus_key")
            return Acore::StringFormat(
                "SELECT COUNT(*) + 1 FROM dc_mplus_scores s1 "
                "WHERE s1.season_id = {} AND s1.best_level > "
                "(SELECT best_level FROM dc_mplus_scores WHERE character_guid = {} AND season_id = {} LIMIT 1)",
                seasonId, requesterGuid, seasonId);
        // Add more cases as needed...

        return std::string();
    }

    // Extract the map id from a "mplus_dungeon_<mapId>" subcategory.
    bool TryParseDungeonMapId(const std::string& subcategory, uint16& mapId)
    {
        if (subcategory.rfind("mplus_dungeon_", 0) != 0)
            return false;
        mapId = static_cast<uint16>(std::strtoul(subcategory.c_str() + 14, nullptr, 10));
        return true;
    }

    // Dispatch: build the fetch SQL for a category/subcategory.
    // Empty string = unknown category (respond with an empty leaderboard).
    std::string BuildLeaderboardSql(const std::string& category, const std::string& subcategory, uint32 seasonId,
        uint32 limit, uint32 offset, uint32 requesterGuid, bool myRunsOnly)
    {
        if (category == "mplus")
        {
            uint16 mapId = 0;
            if (TryParseDungeonMapId(subcategory, mapId))
                return BuildMythicPlusDungeonLeaderboardSql(mapId, seasonId, limit, offset);
            if (subcategory == "mplus_bestruns")
                return BuildMythicPlusBestRunsSql(seasonId, limit, offset);
            return BuildMythicPlusLeaderboardSql(subcategory, seasonId, limit, offset, requesterGuid, myRunsOnly);
        }
        if (category == "seasons")
            return BuildSeasonalLeaderboardSql(subcategory, seasonId, limit, offset);
        if (category == "hlbg")
            return BuildHLBGLeaderboardSql(subcategory, seasonId, limit, offset);
        if (category == "prestige")
            return BuildPrestigeLeaderboardSql(subcategory, limit, offset);
        if (category == "upgrade")
            return BuildUpgradeLeaderboardSql(subcategory, seasonId, limit, offset);
        if (category == "duel")
            return BuildDuelLeaderboardSql(subcategory, limit, offset);
        if (category == "aoe")
            return BuildAOELeaderboardSql(subcategory, limit, offset);
        if (category == "achieve")
            return BuildAchievementLeaderboardSql(subcategory, limit, offset);

        return std::string();
    }

    // Dispatch: parse the fetch-query result with the matching row parser.
    std::vector<LeaderboardEntry> ParseLeaderboardEntries(QueryResult result, const std::string& category,
        const std::string& subcategory, uint32 seasonId, uint32 offset)
    {
        if (category == "mplus")
        {
            uint16 mapId = 0;
            if (TryParseDungeonMapId(subcategory, mapId))
                return ParseMythicPlusDungeonLeaderboard(result, mapId, seasonId, offset);
            if (subcategory == "mplus_bestruns")
                return ParseMythicPlusBestRuns(result, seasonId, offset);
            return ParseMythicPlusLeaderboard(result, subcategory, seasonId, offset);
        }
        if (category == "seasons")
            return ParseSeasonalLeaderboard(result, subcategory, offset);
        if (category == "hlbg")
            return ParseHLBGLeaderboard(result, subcategory, offset);
        if (category == "prestige")
            return ParsePrestigeLeaderboard(result, subcategory, offset);
        if (category == "upgrade")
            return ParseUpgradeLeaderboard(result, subcategory, offset);
        if (category == "duel")
            return ParseDuelLeaderboard(result, subcategory, offset);
        if (category == "aoe")
            return ParseAOELeaderboard(result, subcategory, offset);
        if (category == "achieve")
            return ParseAchievementLeaderboard(result, subcategory, offset);

        return {};
    }

    // Serialize the SMSG_LEADERBOARD_DATA payload (shared by the cache-hit
    // path and the async cache-miss callback).
    std::string BuildLeaderboardJson(const std::string& category, const std::string& subcategory, uint32 page,
        uint32 totalPages, uint32 totalEntries, std::vector<LeaderboardEntry> const& entries)
    {
        // Build entries array as JSON string
        std::string entriesJson = "[";
        for (size_t i = 0; i < entries.size(); ++i)
        {
            if (i > 0) entriesJson += ",";
            entriesJson += "{";
            entriesJson += "\"rank\":" + std::to_string(entries[i].rank) + ",";
            entriesJson += "\"name\":\"" + JsonEscape(entries[i].name) + "\",";
            entriesJson += "\"class\":\"" + JsonEscape(entries[i].className) + "\",";
            entriesJson += "\"score\":" + std::to_string(entries[i].score) + ",";
            // v1.3.0: Add score_str for large values (gold as uint64)
            if (!entries[i].score_str.empty())
                entriesJson += "\"score_str\":\"" + JsonEscape(entries[i].score_str) + "\",";
            // v1.3.0: Add mapId for per-dungeon display
            if (entries[i].mapId > 0)
                entriesJson += "\"mapId\":" + std::to_string(entries[i].mapId) + ",";

            // HLBG: provide structured fields expected by the addon UI
            if (category == "hlbg")
            {
                if (entries[i].hasWinsLosses)
                {
                    entriesJson += "\"wins\":" + std::to_string(entries[i].wins) + ",";
                    entriesJson += "\"losses\":" + std::to_string(entries[i].losses) + ",";
                }

                if (entries[i].hasKD)
                {
                    entriesJson += "\"kills\":" + std::to_string(entries[i].kills) + ",";
                    entriesJson += "\"deaths\":" + std::to_string(entries[i].deaths) + ",";
                    // Use a compact float representation (client handles tonumber)
                    entriesJson += "\"kdRatio\":" + std::to_string(entries[i].kdRatio) + ",";
                }
            }

            // AOE Loot: provide separate quality columns (v1.4.0 client)
            if (category == "aoe" && (subcategory == "aoe_items" || subcategory == "aoe_filtered") && entries[i].hasQuality)
            {
                entriesJson += "\"qLeg\":" + std::to_string(entries[i].qLeg) + ",";
                entriesJson += "\"qEpic\":" + std::to_string(entries[i].qEpic) + ",";
                entriesJson += "\"qRare\":" + std::to_string(entries[i].qRare) + ",";
                entriesJson += "\"qUncommon\":" + std::to_string(entries[i].qUncommon) + ",";
            }

            entriesJson += "\"extra\":\"" + JsonEscape(entries[i].extra) + "\"";
            entriesJson += "}";
        }
        entriesJson += "]";

        std::string fullJson = "{";
        fullJson += "\"category\":\"" + JsonEscape(category) + "\",";
        fullJson += "\"subcategory\":\"" + JsonEscape(subcategory) + "\",";
        fullJson += "\"page\":" + std::to_string(page) + ",";
        fullJson += "\"totalPages\":" + std::to_string(totalPages) + ",";
        fullJson += "\"totalEntries\":" + std::to_string(totalEntries) + ",";
        fullJson += "\"entries\":" + entriesJson;
        fullJson += "}";
        return fullJson;
    }

    // Store a freshly fetched page in the leaderboard cache (with the same
    // oldest-entry eviction the synchronous path used).
    void StoreLeaderboardCache(const std::string& cacheKey, std::vector<LeaderboardEntry> const& entries,
        uint32 totalEntries)
    {
        std::lock_guard<std::mutex> lock(g_cacheMutex);

        // Evict old entries if cache is too large
        if (g_leaderboardCache.size() >= s_CacheConfig.maxCacheEntries)
        {
            // Simple eviction: remove oldest entries
            time_t oldest = time(nullptr);
            std::string oldestKey;
            for (auto& [key, entry] : g_leaderboardCache)
            {
                if (entry.lastUpdate < oldest)
                {
                    oldest = entry.lastUpdate;
                    oldestKey = key;
                }
            }
            if (!oldestKey.empty())
                g_leaderboardCache.erase(oldestKey);
        }

        LeaderboardCacheEntry cacheEntry;
        cacheEntry.entries = entries;
        cacheEntry.totalEntries = totalEntries;
        cacheEntry.lastUpdate = time(nullptr);
        g_leaderboardCache[cacheKey] = std::move(cacheEntry);

        LOG_DEBUG("server.scripts", "DC-Leaderboards: Cached {} entries for {}", entries.size(), cacheKey);
    }

    // ========================================================================
    // MESSAGE HANDLERS
    // ========================================================================

    // Helper to get the current active season ID
    uint32 GetCurrentSeasonId()
    {
        return DarkChaos::GetActiveSeasonId();
    }

    void HandleGetLeaderboard(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession())
            return;

        if (!DCAddon::IsJsonMessage(msg))
        {
            DCAddon::SendError(player, MODULE_LEADERBOARD, "Invalid request format",
                DCAddon::ErrorCode::BAD_FORMAT, DCAddon::Opcode::Core::SMSG_ERROR);
            return;
        }

        // Parse JSON data
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);

        std::string category = json["category"].IsString() ? json["category"].AsString() : "mplus";
        std::string subcategory = json["subcategory"].IsString() ? json["subcategory"].AsString() : "mplus_key";
        uint32 page = json["page"].IsNumber() ? json["page"].AsUInt32() : 1;
        uint32 limit = json["limit"].IsNumber() ? json["limit"].AsUInt32() : DEFAULT_ENTRIES_PER_PAGE;
        uint32 seasonId = json["seasonId"].IsNumber() ? json["seasonId"].AsUInt32() : 0;
        bool myRunsOnly = false;
        if (json.HasKey("myRunsOnly"))
        {
            if (json["myRunsOnly"].IsBool())
                myRunsOnly = json["myRunsOnly"].AsBool();
            else if (json["myRunsOnly"].IsNumber())
                myRunsOnly = (json["myRunsOnly"].AsUInt32() != 0);
            else if (json["myRunsOnly"].IsString())
                myRunsOnly = (json["myRunsOnly"].AsString() == "1" || json["myRunsOnly"].AsString() == "true");
        }

        // If seasonId is 0, get the current active season
        if (seasonId == 0)
            seasonId = GetCurrentSeasonId();

        LOG_DEBUG("server.scripts", "DC-Leaderboards: Request for {}/{} page {} limit {} season {}",
            category, subcategory, page, limit, seasonId);

        // Clamp limit
        if (limit > MAX_ENTRIES_PER_PAGE)
            limit = MAX_ENTRIES_PER_PAGE;
        if (limit < 1)
            limit = DEFAULT_ENTRIES_PER_PAGE;

        // Calculate offset
        uint32 offset = (page - 1) * limit;

        // ===== CACHE CHECK =====
        std::string cacheSubcategory = subcategory;
        if (category == "mplus" && subcategory == "mplus_history")
        {
            cacheSubcategory += myRunsOnly ? "_self" : "_all";
            if (myRunsOnly)
                cacheSubcategory += "_" + std::to_string(player->GetGUID().GetCounter());
        }

        std::string cacheKey = MakeCacheKey(category, cacheSubcategory, seasonId, page, limit);
        bool useCache = false;
        std::vector<LeaderboardEntry> entries;
        uint32 totalEntries = 0;
        uint32 totalPages = 1;

        {
            std::lock_guard<std::mutex> lock(g_cacheMutex);
            auto it = g_leaderboardCache.find(cacheKey);
            if (it != g_leaderboardCache.end() && it->second.IsValid())
            {
                // Cache hit!
                entries = it->second.entries;
                totalEntries = it->second.totalEntries;
                totalPages = (totalEntries + limit - 1) / limit;
                if (totalPages < 1) totalPages = 1;
                useCache = true;
                LOG_DEBUG("server.scripts", "DC-Leaderboards: Cache HIT for {}", cacheKey);
            }
        }

        std::string requestToken = ExtractLeaderboardRequestToken(json);

        if (useCache)
        {
            std::string fullJson = BuildLeaderboardJson(category, subcategory, page, totalPages, totalEntries, entries);
            SendRawJson(player, Opcode::SMSG_LEADERBOARD_DATA, fullJson);
            SendLeaderboardResponseEnvelope(player, Opcode::SMSG_LEADERBOARD_DATA,
                StatsFeature::LEADERBOARD, fullJson, requestToken);
            return;
        }

        LOG_DEBUG("server.scripts", "DC-Leaderboards: Cache MISS for {}", cacheKey);

        std::string fetchSql = BuildLeaderboardSql(category, subcategory, seasonId, limit, offset,
            player->GetGUID().GetCounter(), myRunsOnly);

        if (fetchSql.empty())
        {
            // Unknown category: same empty payload as before, without DB round-trips
            std::string fullJson = BuildLeaderboardJson(category, subcategory, page, 1, 0, {});
            SendRawJson(player, Opcode::SMSG_LEADERBOARD_DATA, fullJson);
            SendLeaderboardResponseEnvelope(player, Opcode::SMSG_LEADERBOARD_DATA,
                StatsFeature::LEADERBOARD, fullJson, requestToken);
            return;
        }

        std::string countSql = BuildTotalEntryCountSql(category, subcategory, seasonId,
            myRunsOnly, player->GetGUID().GetCounter());

        // ===== ASYNC FETCH: entries query -> count query -> cache + respond =====
        // Never capture Player* across queries; re-resolve from the guid at send time.
        ObjectGuid const playerGuid = player->GetGUID();
        std::string requestId = DCAddon::GetCurrentRequestId();

        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(fetchSql)
            .WithCallback([playerGuid, category, subcategory, seasonId, page, limit, offset, cacheKey,
                countSql, requestId, requestToken](QueryResult result)
        {
            std::vector<LeaderboardEntry> entries =
                ParseLeaderboardEntries(result, category, subcategory, seasonId, offset);

            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(countSql)
                .WithCallback([playerGuid, category, subcategory, page, limit, cacheKey, requestId, requestToken,
                    entries = std::move(entries)](QueryResult countResult)
            {
                uint32 totalEntries = countResult ? countResult->Fetch()[0].Get<uint32>() : 0;
                uint32 totalPages = (totalEntries + limit - 1) / limit;
                if (totalPages < 1)
                    totalPages = 1;

                // Cache even if the requester logged off meanwhile
                StoreLeaderboardCache(cacheKey, entries, totalEntries);

                Player* player = ObjectAccessor::FindPlayer(playerGuid);
                if (!player || !player->GetSession())
                    return;

                std::string fullJson = BuildLeaderboardJson(category, subcategory, page, totalPages, totalEntries, entries);
                SendRawJson(player, Opcode::SMSG_LEADERBOARD_DATA, fullJson, requestId);
                SendLeaderboardResponseEnvelope(player, Opcode::SMSG_LEADERBOARD_DATA,
                    StatsFeature::LEADERBOARD, fullJson, requestToken);
            }));
        }));
    }

    void HandleGetCategories(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player)
            return;

        // Send available categories (client already has these hardcoded, but we can confirm)
        DCAddon::JsonMessage response(MODULE_LEADERBOARD, Opcode::SMSG_CATEGORIES);
        response.Set("success", true);
        response.Set("count", 8);
        response.Send(player);
    }

    void SendMyRankResponse(Player* player, const std::string& category, const std::string& subcategory,
        uint32 rank, uint32 total)
    {
        float percentile = total > 0 ? (static_cast<float>(rank) / total * 100.0f) : 0.0f;

        DCAddon::JsonMessage response(MODULE_LEADERBOARD, Opcode::SMSG_MY_RANK);
        response.Set("category", category);
        response.Set("subcategory", subcategory);
        response.Set("rank", static_cast<int32>(rank));
        response.Set("percentile", static_cast<double>(percentile));
        response.Send(player);
    }

    void HandleGetMyRank(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);

        std::string category = json["category"].IsString() ? json["category"].AsString() : "mplus";
        std::string subcategory = json["subcategory"].IsString() ? json["subcategory"].AsString() : "mplus_key";
        uint32 seasonId = json["seasonId"].IsNumber() ? json["seasonId"].AsUInt32() : 0;

        // If seasonId is 0, get the current active season
        if (seasonId == 0)
            seasonId = GetCurrentSeasonId();

        ObjectGuid const playerGuid = player->GetGUID();
        std::string rankSql = BuildPlayerRankSql(playerGuid.GetCounter(), category, subcategory, seasonId);
        std::string countSql = BuildTotalEntryCountSql(category, subcategory, seasonId, false, 0);

        if (countSql.empty())
        {
            // Unknown category: same zeroed response as before, without DB round-trips
            SendMyRankResponse(player, category, subcategory, 0, 0);
            return;
        }

        // Only some categories have a rank query; the count query always runs.
        if (rankSql.empty())
        {
            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(countSql)
                .WithCallback([playerGuid, category, subcategory](QueryResult countResult)
            {
                uint32 total = countResult ? countResult->Fetch()[0].Get<uint32>() : 0;

                Player* player = ObjectAccessor::FindPlayer(playerGuid);
                if (!player || !player->GetSession())
                    return;

                SendMyRankResponse(player, category, subcategory, 0, total);
            }));
            return;
        }

        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(rankSql)
            .WithCallback([playerGuid, category, subcategory, countSql](QueryResult rankResult)
        {
            uint32 rank = rankResult ? rankResult->Fetch()[0].Get<uint32>() : 0;

            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(countSql)
                .WithCallback([playerGuid, category, subcategory, rank](QueryResult countResult)
            {
                uint32 total = countResult ? countResult->Fetch()[0].Get<uint32>() : 0;

                Player* player = ObjectAccessor::FindPlayer(playerGuid);
                if (!player || !player->GetSession())
                    return;

                SendMyRankResponse(player, category, subcategory, rank, total);
            }));
        }));
    }

    void HandleRefresh(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player)
            return;

        // Clear all server-side caches on refresh
        ClearAllCaches();
        LOG_DEBUG("server.scripts", "DC-Leaderboards: Player {} requested refresh, caches cleared", player->GetName());

        DCAddon::JsonMessage response(MODULE_LEADERBOARD, Opcode::SMSG_LEADERBOARD_DATA);
        response.Set("refreshed", true);
        response.Send(player);
    }

    // Leaderboard tables/views living in the character DB; dc_seasons lives
    // in the world DB and is probed separately.
    std::vector<std::string> const TestTablesCharacterDb = {
        "dc_mplus_scores",
        "dc_player_seasonal_stats",
        "v_hlbg_player_seasonal_stats",
        "dc_hlbg_player_stats",
        "dc_character_prestige",
        "dc_item_upgrades",
        "dc_duel_statistics",
        "dc_aoeloot_detailed_stats",
        "dc_player_achievements"
    };

    void HandleTestTables(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player)
            return;

        LOG_INFO("server.scripts", "DC-Leaderboards: Testing database tables for player {}", player->GetName());

        // One UNION ALL count query covers all character-DB tables, chained
        // with a single world-DB count for dc_seasons.
        std::string charSql;
        for (auto const& tableName : TestTablesCharacterDb)
        {
            if (!charSql.empty())
                charSql += " UNION ALL ";
            charSql += Acore::StringFormat("SELECT '{}' AS name, COUNT(*) AS cnt FROM {}", tableName, tableName);
        }

        ObjectGuid const playerGuid = player->GetGUID();
        std::string requestId = DCAddon::GetCurrentRequestId();

        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(charSql)
            .WithCallback([playerGuid, requestId](QueryResult charResult)
        {
            // If the UNION fails wholesale (e.g. one table missing), charResult
            // is null and every character table is reported exists=false/0 --
            // the same signal a failed per-table count used to give.
            std::unordered_map<std::string, uint32> counts;
            if (charResult)
            {
                do
                {
                    Field* fields = charResult->Fetch();
                    counts[fields[0].Get<std::string>()] = fields[1].Get<uint32>();
                } while (charResult->NextRow());
            }

            std::string tablesJson = "[";
            bool first = true;
            for (auto const& tableName : TestTablesCharacterDb)
            {
                auto it = counts.find(tableName);
                bool exists = it != counts.end();
                uint32 count = exists ? it->second : 0;

                if (!first) tablesJson += ",";
                first = false;

                tablesJson += "{";
                tablesJson += "\"name\":\"" + JsonEscape(tableName) + "\",";
                tablesJson += "\"exists\":" + std::string(exists ? "true" : "false") + ",";
                tablesJson += "\"count\":" + std::to_string(count);
                tablesJson += "}";

                LOG_DEBUG("server.scripts", "  Table {}: exists={}, count={}", tableName, exists, count);
            }

            DCAddon::EnqueueQueryCallback(WorldDatabase.AsyncQuery("SELECT COUNT(*) FROM dc_seasons")
                .WithCallback([playerGuid, requestId, tablesJson](QueryResult worldResult)
            {
                bool seasonsExists = worldResult != nullptr;
                uint32 seasonsCount = worldResult ? worldResult->Fetch()[0].Get<uint32>() : 0;

                LOG_DEBUG("server.scripts", "  Table dc_seasons: exists={}, count={}", seasonsExists, seasonsCount);

                std::string allTablesJson = tablesJson;
                allTablesJson += ",{";
                allTablesJson += "\"name\":\"dc_seasons\",";
                allTablesJson += "\"exists\":" + std::string(seasonsExists ? "true" : "false") + ",";
                allTablesJson += "\"count\":" + std::to_string(seasonsCount);
                allTablesJson += "}]";

                // Build full JSON response
                std::string fullJson = "{";
                fullJson += "\"tables\":" + allTablesJson + ",";
                fullJson += "\"currentSeason\":" + std::to_string(GetCurrentSeasonId());
                fullJson += "}";

                Player* player = ObjectAccessor::FindPlayer(playerGuid);
                if (!player || !player->GetSession())
                    return;

                SendRawJson(player, Opcode::SMSG_TEST_RESULTS, fullJson, requestId);
            }));
        }));
    }

    void HandleGetSeasons(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player)
            return;

        LOG_DEBUG("server.scripts", "DC-Leaderboards: Getting seasons list for player {}", player->GetName());

        ObjectGuid const playerGuid = player->GetGUID();
        std::string requestId = DCAddon::GetCurrentRequestId();

        DCAddon::EnqueueQueryCallback(WorldDatabase.AsyncQuery(
            "SELECT season_id, season_state FROM dc_seasons ORDER BY season_id DESC LIMIT 10")
            .WithCallback([playerGuid, requestId](QueryResult result)
        {
            // Build seasons array
            std::string seasonsJson = "[";
            bool first = true;

            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    uint32 seasonId = fields[0].Get<uint32>();
                    bool isActive = fields[1].Get<uint8>() == 1;

                    if (!first) seasonsJson += ",";
                    first = false;

                    seasonsJson += "{";
                    seasonsJson += "\"id\":" + std::to_string(seasonId) + ",";
                    seasonsJson += "\"active\":" + std::string(isActive ? "true" : "false");
                    seasonsJson += "}";
                } while (result->NextRow());
            }

            seasonsJson += "]";

            // Build full JSON response
            std::string fullJson = "{\"seasons\":" + seasonsJson + "}";

            Player* player = ObjectAccessor::FindPlayer(playerGuid);
            if (!player || !player->GetSession())
                return;

            SendRawJson(player, Opcode::SMSG_SEASONS_LIST, fullJson, requestId);
        }));
    }

    // v1.3.0: Handle request for available M+ dungeons
    void HandleGetMythicPlusDungeons(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        uint32 seasonId = json["seasonId"].IsNumber() ? json["seasonId"].AsUInt32() : 0;

        if (seasonId == 0)
            seasonId = GetCurrentSeasonId();

        LOG_DEBUG("server.scripts", "DC-Leaderboards: Getting M+ dungeons for season {}", seasonId);

        auto dungeons = GetMythicPlusDungeons(seasonId);

        // Build dungeons array
        std::string dungeonsJson = "[";
        bool first = true;

        for (auto const& [mapId, dungeonName] : dungeons)
        {
            if (!first) dungeonsJson += ",";
            first = false;

            dungeonsJson += "{";
            dungeonsJson += "\"mapId\":" + std::to_string(mapId) + ",";
            dungeonsJson += "\"name\":\"" + JsonEscape(dungeonName) + "\"";
            dungeonsJson += "}";
        }

        dungeonsJson += "]";

        // Build full JSON response
        std::string fullJson = "{\"seasonId\":" + std::to_string(seasonId) + ",\"dungeons\":" + dungeonsJson + "}";

        SendRawJson(player, Opcode::SMSG_MPLUS_DUNGEONS, fullJson);
    }

    // v1.5.0: Handle request for account-wide statistics
    void HandleGetAccountStats(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = player->GetSession()->GetAccountId();

        LOG_DEBUG("server.scripts", "DC-Leaderboards: Getting account stats for account {}", accountId);

        // ===== CACHE CHECK =====
        {
            std::lock_guard<std::mutex> lock(g_cacheMutex);
            auto it = g_accountStatsCache.find(accountId);
            if (it != g_accountStatsCache.end() && it->second.IsValid())
            {
                // Cache hit! Send cached response
                LOG_DEBUG("server.scripts", "DC-Leaderboards: Account stats cache HIT for account {}", accountId);

                SendRawJson(player, Opcode::SMSG_ACCOUNT_STATS, it->second.jsonResponse);
                return;
            }
        }

        LOG_DEBUG("server.scripts", "DC-Leaderboards: Account stats cache MISS for account {}", accountId);

        // Async rebuild. This used to run 1 + N-per-character + 4 blocking
        // queries on the world thread (classic N+1); now the per-character M+
        // rank is a correlated subquery, everything runs in two chained async
        // queries, and the world thread only assembles JSON.
        ObjectGuid const playerGuid = player->GetGUID();

        std::string charsSql = Acore::StringFormat(
            "SELECT c.name, c.class, c.level, "
            "(SELECT COUNT(*) + 1 FROM dc_mplus_scores s1 "
            "WHERE s1.season_id = (SELECT MAX(season_id) FROM dc_mplus_scores) "
            "AND s1.best_level > ("
            "    SELECT COALESCE(MAX(s2.best_level), 0) FROM dc_mplus_scores s2 WHERE s2.character_guid = c.guid"
            ")) AS mplus_rank "
            "FROM characters c "
            "WHERE c.account = {} "
            "ORDER BY c.level DESC, c.name ASC",
            accountId);

        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(charsSql)
            .WithCallback([playerGuid, accountId](QueryResult result)
        {
            std::string charactersJson = "[";
            bool first = true;

            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    std::string name = fields[0].Get<std::string>();
                    uint8 classId = fields[1].Get<uint8>();
                    uint8 level = fields[2].Get<uint8>();
                    uint32 mplusRank = fields[3].Get<uint32>();

                    std::string className = GetClassNameFromId(classId);

                    // M+ score is currently the only ranked category.
                    uint32 bestRank = 0;
                    std::string bestCategory = "";
                    if (mplusRank > 0)
                    {
                        bestRank = mplusRank;
                        bestCategory = "M+";
                    }

                    if (!first) charactersJson += ",";
                    first = false;

                    charactersJson += "{";
                    charactersJson += "\"name\":\"" + JsonEscape(name) + "\",";
                    charactersJson += "\"class\":\"" + className + "\",";
                    charactersJson += "\"level\":" + std::to_string(level) + ",";
                    charactersJson += "\"bestRank\":" + std::to_string(bestRank) + ",";
                    charactersJson += "\"bestCategory\":\"" + bestCategory + "\"";
                    charactersJson += "}";

                } while (result->NextRow());
            }

            charactersJson += "]";

            // Aggregate account totals in one row of scalar subqueries.
            std::string totalsSql = Acore::StringFormat(
                "SELECT "
                "(SELECT COALESCE(SUM(s.total_runs), 0) FROM dc_mplus_scores s JOIN characters c ON s.character_guid = c.guid WHERE c.account = {}), "
                "(SELECT COALESCE(SUM(a.total_gold), 0) FROM dc_aoeloot_detailed_stats a JOIN characters c ON a.player_guid = c.guid WHERE c.account = {}), "
                "(SELECT COALESCE(SUM(a.total_items), 0) FROM dc_aoeloot_detailed_stats a JOIN characters c ON a.player_guid = c.guid WHERE c.account = {}), "
                "(SELECT COALESCE(SUM(h.battles_won), 0) FROM dc_hlbg_player_stats h JOIN characters c ON h.player_guid = c.guid WHERE c.account = {})",
                accountId, accountId, accountId, accountId);

            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(totalsSql)
                .WithCallback([playerGuid, accountId, charactersJson](QueryResult totals)
            {
                uint32 totalMplusRuns = 0;
                uint64 totalGold = 0;
                uint32 totalItems = 0;
                uint32 totalBgWins = 0;

                if (totals)
                {
                    Field* fields = totals->Fetch();
                    totalMplusRuns = fields[0].Get<uint32>();
                    totalGold = fields[1].Get<uint64>();
                    totalItems = fields[2].Get<uint32>();
                    totalBgWins = fields[3].Get<uint32>();
                }

                std::string totalsJson = "{";
                totalsJson += "\"Total M+ Runs\":" + std::to_string(totalMplusRuns);
                totalsJson += ",\"Total Gold Looted\":" + std::to_string(totalGold / 10000);  // Convert copper to gold
                totalsJson += ",\"Total Items Looted\":" + std::to_string(totalItems);
                totalsJson += ",\"Total BG Wins\":" + std::to_string(totalBgWins);
                totalsJson += "}";

                // Build full JSON response
                std::string fullJson = "{\"characters\":" + charactersJson + ",\"totals\":" + totalsJson + "}";

                // ===== STORE IN CACHE =====
                {
                    std::lock_guard<std::mutex> lock(g_cacheMutex);

                    // Opportunistic pruning: drop expired entries so the map
                    // stays bounded by concurrently-active accounts instead of
                    // "accounts ever seen".
                    for (auto it = g_accountStatsCache.begin(); it != g_accountStatsCache.end();)
                    {
                        if (!it->second.IsValid())
                            it = g_accountStatsCache.erase(it);
                        else
                            ++it;
                    }

                    AccountStatsCacheEntry cacheEntry;
                    cacheEntry.jsonResponse = fullJson;
                    cacheEntry.lastUpdate = time(nullptr);
                    g_accountStatsCache[accountId] = std::move(cacheEntry);
                    LOG_DEBUG("server.scripts", "DC-Leaderboards: Cached account stats for account {}", accountId);
                }

                if (Player* player = ObjectAccessor::FindPlayer(playerGuid))
                    if (player->GetSession())
                        SendRawJson(player, Opcode::SMSG_ACCOUNT_STATS, fullJson);
            }));
        }));
    }

    // Error handler for future use
    [[maybe_unused]] void HandleError(Player* player, const std::string& message)
    {
        if (!player)
            return;

        DCAddon::JsonMessage response(MODULE_LEADERBOARD, Opcode::SMSG_ERROR);
        response.Set("message", message);
        response.Send(player);
    }

    // ========================================================================
    // REGISTRATION
    // ========================================================================

    void RegisterLeaderboardHandlers()
    {
        auto& router = DCAddon::MessageRouter::Instance();

        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_GET_LEADERBOARD, HandleGetLeaderboard);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_GET_CATEGORIES, HandleGetCategories);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_GET_MY_RANK, HandleGetMyRank);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_REFRESH, HandleRefresh);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_TEST_TABLES, HandleTestTables);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_GET_SEASONS, HandleGetSeasons);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_GET_MPLUS_DUNGEONS, HandleGetMythicPlusDungeons);
        router.RegisterHandler(MODULE_LEADERBOARD, Opcode::CMSG_GET_ACCOUNT_STATS, HandleGetAccountStats);

        LOG_INFO("dc.addon", "DC-Leaderboards: Addon protocol handlers registered");
    }

}  // anonymous namespace

// ============================================================================
// SCRIPT REGISTRATION
// ============================================================================

class dc_addon_leaderboards_world : public WorldScript
{
public:
    dc_addon_leaderboards_world() : WorldScript("dc_addon_leaderboards_world") { }

    void OnStartup() override
    {
        RegisterLeaderboardHandlers();
    }
};

void AddSC_dc_addon_leaderboards()
{
    new dc_addon_leaderboards_world();
}
