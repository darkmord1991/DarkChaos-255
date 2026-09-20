/*
 * Dark Chaos - Unified Leaderboard Addon Handler
 * ===============================================
 *
 * Server-side handler for the DC-Leaderboards addon.
 * Provides leaderboard data for all DC systems via DCAddonProtocol.
 *
 * Supports:
 * - Mythic+ leaderboards (best key, runs, score, best runs, per dungeon, run history)
 * - Seasonal leaderboards (tokens, essence, quests, bosses)
 * - Hinterland BG leaderboards (seasonal rating/wins/winrate/games, all-time kills/wins/resources)
 * - Prestige leaderboards (prestige level, prestige XP)
 * - Artifact Mastery leaderboards (mastery points, artifacts mastered, best artifact)
 * - Item Upgrade leaderboards (tokens, items, essence, tier)
 * - Duel leaderboards (wins, winrate, total, damage)
 * - AOE Loot leaderboards (items, filtered, gold)
 * - Achievement leaderboards (points, completed) -- ranked per ACCOUNT, because
 *   achievements are shared account-wide (see dc_accountwide_achievements.cpp)
 *
 * Every ranked board is loaded whole, by one query per cache lifetime, and
 * every page, "my rank" answer and view option (playerbots shown or hidden,
 * one entry per account) is cut from that in-memory ranking. Mythic+ run
 * history is a log rather than a ranking and stays paginated in SQL.
 *
 * Uses JSON protocol for all responses.
 *
 * Copyright (C) 2025 DarkChaos Development Team
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Log.h"
#include "Config.h"
#include "DC/CrossSystem/LeaderboardUtils.h"
#include "DC/CrossSystem/CrossSystemSeasonHelper.h"
#include <algorithm>
#include <atomic>
#include <cstdio>   // for snprintf
#include <cstdlib>  // for strtoul
#include <functional>
#include <map>
#include <memory>
#include <mutex>    // for cache thread safety
#include <unordered_map>
#include <unordered_set>
#include <utility>  // for std::pair

namespace
{
    // Display name for the Mythic+ ranking queries. Playerbots that were
    // backfilled into a run keep their rows; the is_bot flag on their
    // dc_mplus_runs rows labels them "BOT <name>" wherever they rank.
    char const kMPlusNameExpr[] =
        "CASE WHEN EXISTS (SELECT 1 FROM dc_mplus_runs b "
        "WHERE b.character_guid = s.character_guid AND b.is_bot = 1) "
        "THEN CONCAT('BOT ', c.name) ELSE c.name END AS name";

    // Module identifier for leaderboards
    constexpr char const* MODULE_LEADERBOARD = "LBRD";

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
    constexpr uint32 MAX_PAGE = 10000;

    // Ranked boards are loaded whole; this only guards against a runaway table.
    constexpr uint32 MAX_BOARD_ROWS = 20000;

    // CMSG_REFRESH flushes caches every player shares, so it is throttled.
    constexpr time_t REFRESH_THROTTLE_SECONDS = 15;

    // How often the playerbot account list is re-read from the auth DB.
    constexpr uint32 BOT_ACCOUNT_REFRESH_MS = 10 * MINUTE * IN_MILLISECONDS;

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
        uint32 rank = 0;
        std::string name;
        std::string className;
        uint32 score = 0;
        std::string extra;
        // Extended fields for v1.3.0
        std::string score_str;   // For uint64 values (gold, damage) sent as string
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

        // Who the row belongs to. Ranked-board and run-history queries end
        // their SELECT list with `c.guid, c.account` (see ReadRowIdentity).
        uint32 ownerGuid = 0;    // character; the account's main on account boards
        uint32 accountId = 0;
        bool isBot = false;      // row belongs to a playerbot account

        // Set per requester when a page is cut
        bool isSelf = false;     // the requester (their account on account views)
        bool isAlt = false;      // another character on the requester's account
    };

    // Mythic+ run history is paginated in SQL, so its pages are cached one by one.
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

    // A ranked board: every qualifying row, best first.
    struct LeaderboardBoard
    {
        std::vector<LeaderboardEntry> rows;
        bool accountScoped = false;   // one row per account (achievements)
        time_t builtAt = 0;

        bool IsValid() const
        {
            return (time(nullptr) - builtAt) < static_cast<time_t>(GetCacheLifetime());
        }
    };

    using BoardPtr = std::shared_ptr<LeaderboardBoard const>;
    using BoardCallback = std::function<void(BoardPtr const&)>;

    // A board build in flight and the requests waiting for it.
    struct PendingBoardBuild
    {
        time_t startedAt = 0;
        std::vector<BoardCallback> waiters;
    };

    // A build that has not answered in this long is presumed lost and restarted.
    constexpr time_t BOARD_BUILD_TIMEOUT_SECONDS = 30;

    // Global cache maps
    // History key format: "category_subcategory_seasonId_page_limit"
    std::unordered_map<std::string, LeaderboardCacheEntry> g_leaderboardCache;
    std::unordered_map<uint32, AccountStatsCacheEntry> g_accountStatsCache;  // Key: accountId
    // Board key format: "category_subcategory_seasonId" (seasonId 0 = not seasonal)
    std::unordered_map<std::string, BoardPtr> g_boards;
    std::unordered_map<std::string, PendingBoardBuild> g_boardBuilds;
    std::mutex g_cacheMutex;  // Thread safety for every map above

    // Helper to generate cache key
    std::string MakeCacheKey(std::string const& category, std::string const& subcategory,
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
            // Builds in flight (g_boardBuilds) keep their waiters and simply store a fresh board.
            g_boards.clear();
        }
        {
            std::lock_guard<std::mutex> lock(g_dungeonCacheMutex);
            g_dungeonCache.loaded = false;  // reload dc_mplus_featured_dungeons on next use
        }
        LOG_DEBUG("server.scripts", "DC-Leaderboards: All caches cleared");
    }

    // ------------------------------------------------------------------
    // Playerbot accounts. mod-playerbots names its random-bot (and AddClass)
    // accounts <AiPlayerbot.RandomBotAccountPrefix><n> and finds them with
    // this same query; the characters DB itself has no bot flag. Loaded at
    // startup, then refreshed in the background.
    // ------------------------------------------------------------------
    std::unordered_set<uint32> g_botAccounts;
    std::mutex g_botAccountsMutex;

    std::string BuildBotAccountSql()
    {
        std::string prefix = sConfigMgr->GetOption<std::string>("AiPlayerbot.RandomBotAccountPrefix", "rndbot", false);
        LoginDatabase.EscapeString(prefix);
        return Acore::StringFormat("SELECT id FROM account WHERE username LIKE '{}%'", prefix);
    }

    void StoreBotAccounts(QueryResult const& result)
    {
        std::unordered_set<uint32> accounts;
        if (result)
        {
            do
            {
                accounts.insert(result->Fetch()[0].Get<uint32>());
            } while (result->NextRow());
        }

        std::lock_guard<std::mutex> lock(g_botAccountsMutex);
        g_botAccounts = std::move(accounts);
    }

    void LoadBotAccounts()
    {
        StoreBotAccounts(LoginDatabase.Query(BuildBotAccountSql()));

        std::lock_guard<std::mutex> lock(g_botAccountsMutex);
        LOG_INFO("dc.addon", "DC-Leaderboards: {} playerbot accounts will be labelled on the leaderboards",
            g_botAccounts.size());
    }

    void RefreshBotAccountsAsync()
    {
        DCAddon::EnqueueQueryCallback(LoginDatabase.AsyncQuery(BuildBotAccountSql())
            .WithCallback([](QueryResult result)
        {
            StoreBotAccounts(result);
        }));
    }

    void MarkBotRows(std::vector<LeaderboardEntry>& rows)
    {
        std::lock_guard<std::mutex> lock(g_botAccountsMutex);
        for (LeaderboardEntry& row : rows)
            row.isBot = g_botAccounts.count(row.accountId) != 0;
    }

    // Forward declarations
    uint32 GetCurrentSeasonId();
    std::string GetDungeonNameForMap(uint16 mapId, uint32 seasonId = 0);

    // Use centralized utilities from LeaderboardUtils.h to avoid duplication
    using DarkChaos::Leaderboard::JsonEscape;
    using DarkChaos::Leaderboard::GetClassNameFromId;

    // Reads the trailing `c.guid, c.account` columns every ranked-board and
    // run-history query ends with, so the row parsers keep their own indices.
    void ReadRowIdentity(LeaderboardEntry& entry, Field* fields, uint32 fieldCount)
    {
        entry.ownerGuid = fields[fieldCount - 2].Get<uint32>();
        entry.accountId = fields[fieldCount - 1].Get<uint32>();
    }

    std::string GetItemDisplayName(uint32 itemId)
    {
        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemId))
            return proto->Name1;
        return "Item #" + std::to_string(itemId);
    }

    // ========================================================================
    // LEADERBOARD DATA FETCHERS
    // ========================================================================

    // Mythic+ run history: a log, not a ranking, so it stays paginated in SQL.
    // Hiding bots here drops runs a bot session played (dc_mplus_runs.is_bot).
    std::string RunHistoryFilter(uint32 seasonId, uint32 requesterGuid, bool myRunsOnly, bool includeBots)
    {
        // Account 0 = characters unlinked by CharDelete.Method = 1 (blank name).
        std::string filter = Acore::StringFormat("r.season_id = {} AND c.account <> 0", seasonId);
        if (myRunsOnly && requesterGuid > 0)
            filter += Acore::StringFormat(" AND r.character_guid = {}", requesterGuid);
        else if (!includeBots)
            filter += " AND r.is_bot = 0";
        return filter;
    }

    std::string BuildRunHistorySql(std::string const& filter, uint32 limit, uint32 offset)
    {
        return Acore::StringFormat(
            "SELECT IF(r.is_bot = 1, CONCAT('BOT ', c.name), c.name) AS name, c.class, r.keystone_level, r.map_id, "
            "COALESCE(r.completion_time, 0), r.success, DATE_FORMAT(r.completed_at, '%Y-%m-%d %H:%i'), "
            "c.guid, c.account "
            "FROM dc_mplus_runs r "
            "JOIN characters c ON r.character_guid = c.guid "
            "WHERE {} "
            "ORDER BY r.completed_at DESC, r.run_id DESC "
            "LIMIT {} OFFSET {}",
            filter, limit, offset);
    }

    std::string BuildRunHistoryCountSql(std::string const& filter)
    {
        // Aliased: Field warns on every unaliased COUNT(*) read as uint32.
        return Acore::StringFormat(
            "SELECT COUNT(*) AS total FROM dc_mplus_runs r "
            "JOIN characters c ON r.character_guid = c.guid "
            "WHERE {}",
            filter);
    }

    std::vector<LeaderboardEntry> ParseRunHistory(QueryResult result, uint32 seasonId, uint32 offset)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

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

            ReadRowIdentity(entry, fields, result->GetFieldCount());
            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Mythic+ per-player aggregate across all dungeons of the season
    // Note: dc_mplus_scores table has: character_guid, season_id, map_id, best_level, best_score, last_run_ts, total_runs
    std::string BuildMythicPlusBoardSql(std::string const& subcat, uint32 seasonId)
    {
        // Use aggregate function aliases in ORDER BY for sql_mode=only_full_group_by compatibility
        std::string orderBy = "best_level DESC, total_score DESC";
        if (subcat == "mplus_runs")
            orderBy = "total_runs DESC, best_level DESC";
        else if (subcat == "mplus_score")
            orderBy = "total_score DESC, best_level DESC";

        return Acore::StringFormat(
            std::string("SELECT ") + kMPlusNameExpr + ", c.class, MAX(s.best_level) AS best_level, "
            "SUM(s.best_score) AS total_score, SUM(s.total_runs) AS total_runs, c.guid, c.account "
            "FROM dc_mplus_scores s "
            "JOIN characters c ON s.character_guid = c.guid "
            "WHERE s.season_id = {} "
            "GROUP BY s.character_guid, c.guid, c.account, c.name, c.class "
            "ORDER BY {}, c.guid "
            "LIMIT {}",
            seasonId, orderBy, MAX_BOARD_ROWS);
    }

    std::vector<LeaderboardEntry> ParseMythicPlusBoard(QueryResult result, std::string const& subcat)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
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

            ReadRowIdentity(entry, fields, result->GetFieldCount());
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

    bool IsFeaturedDungeon(uint32 seasonId, uint16 mapId)
    {
        std::lock_guard<std::mutex> lock(g_dungeonCacheMutex);
        EnsureDungeonCacheLoaded();

        return g_dungeonCache.nameBySeasonAndMap.count({seasonId, mapId}) != 0;
    }

    // Mythic+ leaderboard for a specific dungeon
    // v1.3.0: per-dungeon leaderboards with dungeon name display
    std::string BuildMythicPlusDungeonBoardSql(uint16 mapId, uint32 seasonId)
    {
        return Acore::StringFormat(
            std::string("SELECT ") + kMPlusNameExpr + ", c.class, s.best_level, s.best_score, s.total_runs, s.map_id, "
            "c.guid, c.account "
            "FROM dc_mplus_scores s "
            "JOIN characters c ON s.character_guid = c.guid "
            "WHERE s.season_id = {} AND s.map_id = {} "
            "ORDER BY s.best_level DESC, s.best_score DESC, c.guid "
            "LIMIT {}",
            seasonId, mapId, MAX_BOARD_ROWS);
    }

    std::vector<LeaderboardEntry> ParseMythicPlusDungeonBoard(QueryResult result, uint16 mapId, uint32 seasonId)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        std::string dungeonName = GetDungeonNameForMap(mapId, seasonId);

        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            entry.score = fields[2].Get<uint32>();  // best_level
            entry.mapId = fields[5].Get<uint16>();

            // Extra shows dungeon name and total runs
            entry.extra = dungeonName + " (" + std::to_string(fields[4].Get<uint32>()) + " runs)";

            ReadRowIdentity(entry, fields, result->GetFieldCount());
            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Mythic+ best dungeon run per player (shows their best dungeon)
    // v1.3.0: Shows which dungeon each player performed best in. ROW_NUMBER
    // keeps it to one row per player; the old "best_level = MAX(...)" filter
    // listed a player twice when two dungeons tied on level.
    std::string BuildMythicPlusBestRunsSql(uint32 seasonId)
    {
        return Acore::StringFormat(
            std::string("SELECT ") + kMPlusNameExpr + ", c.class, s.best_level, s.best_score, s.total_runs, s.map_id, "
            "c.guid, c.account "
            "FROM (SELECT character_guid, map_id, best_level, best_score, total_runs, "
            "ROW_NUMBER() OVER (PARTITION BY character_guid "
            "ORDER BY best_level DESC, best_score DESC, map_id ASC) AS rn "
            "FROM dc_mplus_scores WHERE season_id = {}) s "
            "JOIN characters c ON s.character_guid = c.guid "
            "WHERE s.rn = 1 "
            "ORDER BY s.best_level DESC, s.best_score DESC, c.guid "
            "LIMIT {}",
            seasonId, MAX_BOARD_ROWS);
    }

    std::vector<LeaderboardEntry> ParseMythicPlusBestRuns(QueryResult result, uint32 seasonId)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());
            entry.score = fields[2].Get<uint32>();  // best_level
            entry.mapId = fields[5].Get<uint16>();

            // Dungeon name comes from the in-memory featured-dungeons cache
            entry.extra = GetDungeonNameForMap(entry.mapId, seasonId);

            ReadRowIdentity(entry, fields, result->GetFieldCount());
            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Seasonal leaderboard
    // Table: dc_player_seasonal_stats with fields: total_tokens_earned, total_essence_earned, quests_completed,
    // dungeon_bosses_killed, world_bosses_killed
    std::string BuildSeasonalBoardSql(std::string const& subcat, uint32 seasonId)
    {
        std::string metric = "d.total_tokens_earned";
        if (subcat == "season_essence")
            metric = "d.total_essence_earned";
        else if (subcat == "season_quests")
            metric = "d.quests_completed";
        else if (subcat == "season_bosses")
            metric = "(d.dungeon_bosses_killed + d.world_bosses_killed)";

        // Only players with something to rank: nearly every row has zero
        // bosses killed, and a board of thousands of zeros helps nobody.
        return Acore::StringFormat(
            "SELECT c.name, c.class, {0}, d.total_tokens_earned, d.total_essence_earned, d.quests_completed, "
            "c.guid, c.account "
            "FROM dc_player_seasonal_stats d "
            "JOIN characters c ON d.player_guid = c.guid "
            "WHERE d.season_id = {1} AND {0} > 0 "
            "ORDER BY {0} DESC, c.guid "
            "LIMIT {2}",
            metric, seasonId, MAX_BOARD_ROWS);
    }

    std::vector<LeaderboardEntry> ParseSeasonalBoard(QueryResult result, std::string const& subcat)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
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

            ReadRowIdentity(entry, fields, result->GetFieldCount());
            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Hinterland BG leaderboard
    // Sources:
    //   - v_hlbg_player_seasonal_stats: unified seasonal aggregation
    //   - dc_hlbg_player_stats: all-time kill/win/resource counters
    bool IsHLBGOverallSubcategory(std::string const& subcat)
    {
        return subcat == "hlbg_kills" || subcat == "hlbg_alltime_wins" || subcat == "hlbg_resources";
    }

    std::string BuildHLBGBoardSql(std::string const& subcat, uint32 seasonId)
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
                "SELECT c.name, c.class, h.battles_won, h.total_kills, h.total_deaths, h.resources_captured, "
                "h.battles_participated, c.guid, c.account "
                "FROM dc_hlbg_player_stats h "
                "JOIN characters c ON h.player_guid = c.guid "
                "ORDER BY {}, h.battles_participated DESC, c.guid "
                "LIMIT {}",
                orderBy, MAX_BOARD_ROWS);
        }

        // Use v_hlbg_player_seasonal_stats view for seasonal stats (unified schema).
        // Win rate is the view's wins / games_played, so the value shown and
        // the order agree (a drawn match counts as played, not as a loss).
        std::string orderBy = "v.current_rating DESC, v.wins DESC";
        if (subcat == "hlbg_wins")
            orderBy = "v.wins DESC, v.games_played ASC";
        else if (subcat == "hlbg_winrate")
            orderBy = "v.win_rate DESC, v.games_played DESC";
        else if (subcat == "hlbg_games")
            orderBy = "v.games_played DESC, v.wins DESC";

        return Acore::StringFormat(
            "SELECT c.name, c.class, GREATEST(v.current_rating, 0), v.wins, v.losses, v.games_played, "
            "c.guid, c.account "
            "FROM v_hlbg_player_seasonal_stats v "
            "JOIN characters c ON v.guid = c.guid "
            "WHERE v.season_id = {} "
            "ORDER BY {}, c.guid "
            "LIMIT {}",
            seasonId, orderBy, MAX_BOARD_ROWS);
    }

    std::vector<LeaderboardEntry> ParseHLBGBoard(QueryResult result, std::string const& subcat)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        if (IsHLBGOverallSubcategory(subcat))
        {
            do
            {
                Field* fields = result->Fetch();
                LeaderboardEntry entry;
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

                ReadRowIdentity(entry, fields, result->GetFieldCount());
                entries.push_back(entry);
            } while (result->NextRow());

            return entries;
        }

        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());

            uint32 wins = fields[3].Get<uint32>();
            uint32 losses = fields[4].Get<uint32>();
            uint32 games = fields[5].Get<uint32>();
            float winRate = games > 0 ? (static_cast<float>(wins) / games * 100.0f) : 0.0f;

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
                entry.extra = std::to_string(games) + " games";
            }
            else if (subcat == "hlbg_games")
            {
                entry.score = games;
                entry.extra = std::to_string(wins) + "W/" + std::to_string(losses) + "L";
            }
            else  // hlbg_rating
            {
                entry.score = fields[2].Get<uint32>();
                entry.extra = std::to_string(wins) + "W/" + std::to_string(losses) + "L";
            }

            ReadRowIdentity(entry, fields, result->GetFieldCount());
            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Prestige leaderboard (the level-reset prestige system).
    // Table: dc_character_prestige -- prestige_level (== total_prestiges) and
    // prestige_points, the "Prestige XP" the DC-Welcome panel shows.
    std::string BuildPrestigeBoardSql(std::string const& subcat)
    {
        bool const byXp = subcat == "prestige_points";

        return Acore::StringFormat(
            "SELECT c.name, c.class, p.prestige_level, p.prestige_points, c.guid, c.account "
            "FROM dc_character_prestige p "
            "JOIN characters c ON p.guid = c.guid "
            "WHERE {} > 0 "
            "ORDER BY {}, p.last_prestige_time ASC, c.guid "
            "LIMIT {}",
            byXp ? "p.prestige_points" : "p.prestige_level",
            byXp ? "p.prestige_points DESC, p.prestige_level DESC" : "p.prestige_level DESC, p.prestige_points DESC",
            MAX_BOARD_ROWS);
    }

    std::vector<LeaderboardEntry> ParsePrestigeBoard(QueryResult result, std::string const& subcat)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());

            uint32 prestigeLevel = fields[2].Get<uint32>();
            uint32 prestigePoints = fields[3].Get<uint32>();

            if (subcat == "prestige_points")
            {
                entry.score = prestigePoints;
                entry.extra = "Prestige " + std::to_string(prestigeLevel);
            }
            else  // prestige_level (default)
            {
                entry.score = prestigeLevel;
                entry.extra = std::to_string(prestigePoints) + " XP";
            }

            ReadRowIdentity(entry, fields, result->GetFieldCount());
            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Artifact Mastery leaderboard
    // The item upgrade system adds mastery_points per (character, item entry)
    // on every upgrade (ItemUpgradeManager), with artifact_id holding the item
    // entry. The per-player columns (mastery_level, total_mastery_points, ...)
    // belong to an older manager nothing calls; they are all zero, which is why
    // the board used to come back empty.
    std::string BuildMasteryBoardSql(std::string const& subcat)
    {
        std::string orderBy = "t.total_points DESC, t.artifacts DESC";
        if (subcat == "mastery_artifacts")
            orderBy = "t.artifacts DESC, t.total_points DESC";
        else if (subcat == "mastery_best")
            orderBy = "t.mastery_points DESC, t.total_points DESC";

        return Acore::StringFormat(
            "SELECT c.name, c.class, t.total_points, t.artifacts, t.mastery_points, t.artifact_id, c.guid, c.account "
            "FROM (SELECT am.player_guid, am.artifact_id, am.mastery_points, "
            "SUM(am.mastery_points) OVER (PARTITION BY am.player_guid) AS total_points, "
            "COUNT(*) OVER (PARTITION BY am.player_guid) AS artifacts, "
            "ROW_NUMBER() OVER (PARTITION BY am.player_guid "
            "ORDER BY am.mastery_points DESC, am.artifact_id ASC) AS rn "
            "FROM dc_player_artifact_mastery am "
            "WHERE am.mastery_points > 0) t "
            "JOIN characters c ON t.player_guid = c.guid "
            "WHERE t.rn = 1 "
            "ORDER BY {}, c.guid "
            "LIMIT {}",
            orderBy, MAX_BOARD_ROWS);
    }

    std::vector<LeaderboardEntry> ParseMasteryBoard(QueryResult result, std::string const& subcat)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
            entry.name = fields[0].Get<std::string>();
            entry.className = GetClassNameFromId(fields[1].Get<uint8>());

            uint32 totalPoints = fields[2].Get<uint32>();
            uint32 artifacts = fields[3].Get<uint32>();
            uint32 bestPoints = fields[4].Get<uint32>();
            uint32 bestItemId = fields[5].Get<uint32>();

            if (subcat == "mastery_artifacts")
            {
                entry.score = artifacts;
                entry.extra = std::to_string(totalPoints) + " pts";
            }
            else if (subcat == "mastery_best")
            {
                entry.score = bestPoints;
                entry.extra = GetItemDisplayName(bestItemId);
            }
            else  // mastery_points (default)
            {
                entry.score = totalPoints;
                entry.extra = std::to_string(artifacts) + " artifacts";
            }

            ReadRowIdentity(entry, fields, result->GetFieldCount());
            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Item Upgrade leaderboard
    // Uses dc_item_upgrades table: player_guid, tier_id, upgrade_level, tokens_invested, essence_invested
    std::string BuildUpgradeBoardSql(std::string const& subcat, uint32 seasonId)
    {
        std::string metric = "total_tokens";
        std::string orderBy = "total_tokens DESC, item_count DESC";
        if (subcat == "upgrade_items")
        {
            metric = "item_count";
            orderBy = "item_count DESC, total_tokens DESC";
        }
        else if (subcat == "upgrade_essence")
        {
            metric = "total_essence";
            orderBy = "total_essence DESC, item_count DESC";
        }
        else if (subcat == "upgrade_tier")
        {
            metric = "highest_tier";
            orderBy = "highest_tier DESC, total_tokens DESC";
        }

        // Aggregate upgrades per player from dc_item_upgrades
        return Acore::StringFormat(
            "SELECT c.name, c.class, "
            "SUM(u.tokens_invested) AS total_tokens, "
            "SUM(u.essence_invested) AS total_essence, "
            "COUNT(DISTINCT u.item_guid) AS item_count, "
            "MAX(u.tier_id) AS highest_tier, c.guid, c.account "
            "FROM dc_item_upgrades u "
            "JOIN characters c ON u.player_guid = c.guid "
            "WHERE u.season = {} OR u.season = 0 "
            "GROUP BY u.player_guid, c.guid, c.account, c.name, c.class "
            "HAVING {} > 0 "
            "ORDER BY {}, c.guid "
            "LIMIT {}",
            seasonId, metric, orderBy, MAX_BOARD_ROWS);
    }

    std::vector<LeaderboardEntry> ParseUpgradeBoard(QueryResult result, std::string const& subcat)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
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

            ReadRowIdentity(entry, fields, result->GetFieldCount());
            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Duel leaderboard
    // Table: dc_duel_statistics with fields: player_guid, wins, losses, draws, total_damage_dealt.
    // Win rate is wins / (wins + losses + draws) both for the order and for
    // the value shown.
    std::string BuildDuelBoardSql(std::string const& subcat)
    {
        std::string orderBy = "d.wins DESC, d.losses ASC";
        if (subcat == "duel_winrate")
            orderBy = "d.wins / GREATEST(d.wins + d.losses + d.draws, 1) DESC, (d.wins + d.losses + d.draws) DESC";
        else if (subcat == "duel_total")
            orderBy = "(d.wins + d.losses + d.draws) DESC, d.wins DESC";
        else if (subcat == "duel_damage")
            orderBy = "d.total_damage_dealt DESC";

        return Acore::StringFormat(
            "SELECT c.name, c.class, d.wins, d.losses, d.draws, d.total_damage_dealt, c.guid, c.account "
            "FROM dc_duel_statistics d "
            "JOIN characters c ON d.player_guid = c.guid "
            "WHERE d.wins + d.losses + d.draws > 0 "
            "ORDER BY {}, c.guid "
            "LIMIT {}",
            orderBy, MAX_BOARD_ROWS);
    }

    std::vector<LeaderboardEntry> ParseDuelBoard(QueryResult result, std::string const& subcat)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
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
                entry.score = static_cast<uint32>(winRate * 10);  // Store as x10 for precision
                entry.extra = std::to_string(totalGames) + " duels";
            }
            else if (subcat == "duel_total")
            {
                entry.score = totalGames;
                entry.extra = std::to_string(wins) + "W/" + std::to_string(losses) + "L/" + std::to_string(draws) + "D";
            }
            else if (subcat == "duel_damage")
            {
                // Full value as a string (uint64); the client abbreviates it.
                entry.score = 0;
                entry.score_str = std::to_string(damage);
                entry.extra = std::to_string(wins) + " wins";
            }
            else  // duel_wins
            {
                entry.score = wins;
                entry.extra = std::to_string(losses) + " losses";
            }

            ReadRowIdentity(entry, fields, result->GetFieldCount());
            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // AOE Loot leaderboard
    // Table: dc_aoeloot_detailed_stats with quality breakdown columns
    // Simplified to 3 views: aoe_items (looted + quality), aoe_filtered (filtered + quality), aoe_gold
    std::string BuildAOEBoardSql(std::string const& subcat)
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
            "COALESCE(a.filtered_rare, 0), COALESCE(a.filtered_epic, 0), COALESCE(a.filtered_legendary, 0), "
            "c.guid, c.account "
            "FROM dc_aoeloot_detailed_stats a "
            "JOIN characters c ON a.player_guid = c.guid "
            "ORDER BY {}, c.guid "
            "LIMIT {}",
            orderBy, MAX_BOARD_ROWS);
    }

    std::vector<LeaderboardEntry> ParseAOEBoard(QueryResult result, std::string const& subcat)
    {
        std::vector<LeaderboardEntry> entries;
        if (!result)
            return entries;

        do
        {
            Field* fields = result->Fetch();
            LeaderboardEntry entry;
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
                // Uncommon and better have their own columns in the client;
                // the info column carries what is left: common / poor.
                entry.hasQuality = true;
                entry.qLeg = fLegendary;
                entry.qEpic = fEpic;
                entry.qRare = fRare;
                entry.qUncommon = fUncommon;

                entry.score = fPoor + fCommon + fUncommon + fRare + fEpic + fLegendary;
                entry.extra = std::to_string(fCommon) + " / |cff9d9d9d" + std::to_string(fPoor) + "|r";
            }
            else  // aoe_items (default)
            {
                entry.hasQuality = true;
                entry.qLeg = qLegendary;
                entry.qEpic = qEpic;
                entry.qRare = qRare;
                entry.qUncommon = qUncommon;

                entry.score = items;
                entry.extra = std::to_string(qCommon) + " / |cff9d9d9d" + std::to_string(qPoor) + "|r";
            }

            ReadRowIdentity(entry, fields, result->GetFieldCount());
            entries.push_back(entry);
        } while (result->NextRow());

        return entries;
    }

    // Extract the map id from a "mplus_dungeon_<mapId>" subcategory.
    bool TryParseDungeonMapId(std::string const& subcategory, uint16& mapId)
    {
        if (subcategory.rfind("mplus_dungeon_", 0) != 0)
            return false;
        mapId = static_cast<uint16>(std::strtoul(subcategory.c_str() + 14, nullptr, 10));
        return true;
    }

    // Dispatch: build the full-board SQL for a normalized category/subcategory.
    // Achievements are built separately (BuildAchievementBoard).
    std::string BuildBoardSql(std::string const& category, std::string const& subcategory, uint32 seasonId)
    {
        if (category == "mplus")
        {
            uint16 mapId = 0;
            if (TryParseDungeonMapId(subcategory, mapId))
                return BuildMythicPlusDungeonBoardSql(mapId, seasonId);
            if (subcategory == "mplus_bestruns")
                return BuildMythicPlusBestRunsSql(seasonId);
            return BuildMythicPlusBoardSql(subcategory, seasonId);
        }
        if (category == "seasons")
            return BuildSeasonalBoardSql(subcategory, seasonId);
        if (category == "hlbg")
            return BuildHLBGBoardSql(subcategory, seasonId);
        if (category == "prestige")
            return BuildPrestigeBoardSql(subcategory);
        if (category == "mastery")
            return BuildMasteryBoardSql(subcategory);
        if (category == "upgrade")
            return BuildUpgradeBoardSql(subcategory, seasonId);
        if (category == "duel")
            return BuildDuelBoardSql(subcategory);
        if (category == "aoe")
            return BuildAOEBoardSql(subcategory);

        return std::string();
    }

    // Dispatch: parse the board-query result with the matching row parser.
    std::vector<LeaderboardEntry> ParseBoardRows(QueryResult result, std::string const& category,
        std::string const& subcategory, uint32 seasonId)
    {
        if (category == "mplus")
        {
            uint16 mapId = 0;
            if (TryParseDungeonMapId(subcategory, mapId))
                return ParseMythicPlusDungeonBoard(result, mapId, seasonId);
            if (subcategory == "mplus_bestruns")
                return ParseMythicPlusBestRuns(result, seasonId);
            return ParseMythicPlusBoard(result, subcategory);
        }
        if (category == "seasons")
            return ParseSeasonalBoard(result, subcategory);
        if (category == "hlbg")
            return ParseHLBGBoard(result, subcategory);
        if (category == "prestige")
            return ParsePrestigeBoard(result, subcategory);
        if (category == "mastery")
            return ParseMasteryBoard(result, subcategory);
        if (category == "upgrade")
            return ParseUpgradeBoard(result, subcategory);
        if (category == "duel")
            return ParseDuelBoard(result, subcategory);
        if (category == "aoe")
            return ParseAOEBoard(result, subcategory);

        return {};
    }

    // ========================================================================
    // RANKED BOARDS
    // ========================================================================

    // Subcategories each category serves; the first one is the default.
    std::unordered_map<std::string, std::vector<std::string>> const KnownSubcategories =
    {
        { "mplus",    { "mplus_key", "mplus_runs", "mplus_score", "mplus_bestruns", "mplus_history" } },
        { "seasons",  { "season_tokens", "season_essence", "season_quests", "season_bosses" } },
        { "hlbg",     { "hlbg_rating", "hlbg_wins", "hlbg_winrate", "hlbg_games",
                        "hlbg_kills", "hlbg_alltime_wins", "hlbg_resources" } },
        { "prestige", { "prestige_level", "prestige_points" } },
        { "mastery",  { "mastery_points", "mastery_artifacts", "mastery_best" } },
        { "upgrade",  { "upgrade_tokens", "upgrade_items", "upgrade_essence", "upgrade_tier" } },
        { "duel",     { "duel_wins", "duel_winrate", "duel_total", "duel_damage" } },
        { "aoe",      { "aoe_items", "aoe_filtered", "aoe_gold" } },
        { "achieve",  { "achieve_points", "achieve_completed" } },
    };

    // Subcategory ids older clients still send.
    std::unordered_map<std::string, std::string> const LegacySubcategories =
    {
        { "achieve_progress", "achieve_points" },
        { "prestige_resets", "prestige_level" },
    };

    struct BoardView
    {
        bool includeBots = false;
        bool perAccount = false;   // collapse a character board to each account's best row
    };

    struct LeaderboardRequest
    {
        ObjectGuid playerGuid;
        uint32 accountId = 0;
        std::string category;
        std::string subcategory;        // as sent; echoed so the client files the reply under its own key
        std::string boardSubcategory;   // normalized; selects the board
        uint32 seasonId = 0;
        uint32 page = 1;
        uint32 limit = DEFAULT_ENTRIES_PER_PAGE;
        BoardView view;
        bool myRunsOnly = false;
        std::string requestId;
        std::string requestToken;
    };

    bool IsRunHistory(LeaderboardRequest const& request)
    {
        return request.category == "mplus" && request.boardSubcategory == "mplus_history";
    }

    // Seasonal boards are keyed by season; the rest are one board for every
    // season the client may have selected.
    uint32 BoardSeasonId(std::string const& category, std::string const& subcategory, uint32 seasonId)
    {
        if (category == "mplus" || category == "seasons" || category == "upgrade")
            return seasonId;
        if (category == "hlbg" && !IsHLBGOverallSubcategory(subcategory))
            return seasonId;
        return 0;
    }

    std::string MakeBoardKey(std::string const& category, std::string const& subcategory, uint32 seasonId)
    {
        return category + "_" + subcategory + "_" + std::to_string(BoardSeasonId(category, subcategory, seasonId));
    }

    // Validates the category and maps the subcategory onto a board the server
    // builds: legacy ids to their replacement, anything unknown (including a
    // dungeon that is not featured this season) to the category default. With
    // the season clamped in ReadLeaderboardRequest the set of boards is closed.
    // Returns false for an unknown category.
    bool NormalizeBoardRequest(LeaderboardRequest& request)
    {
        auto known = KnownSubcategories.find(request.category);
        if (known == KnownSubcategories.end())
            return false;

        std::string& subcategory = request.boardSubcategory;

        auto legacy = LegacySubcategories.find(subcategory);
        if (legacy != LegacySubcategories.end())
            subcategory = legacy->second;

        uint16 mapId = 0;
        if (request.category == "mplus" && TryParseDungeonMapId(subcategory, mapId)
            && IsFeaturedDungeon(request.seasonId, mapId))
        {
            subcategory = "mplus_dungeon_" + std::to_string(mapId);
            return true;
        }

        std::vector<std::string> const& subcategories = known->second;
        if (std::find(subcategories.begin(), subcategories.end(), subcategory) == subcategories.end())
            subcategory = subcategories.front();
        return true;
    }

    bool ReadJsonFlag(DCAddon::JsonValue const& json, std::string const& key, bool fallback)
    {
        if (!json.HasKey(key))
            return fallback;

        DCAddon::JsonValue const& value = json[key];
        if (value.IsBool())
            return value.AsBool();
        if (value.IsNumber())
            return value.AsUInt32() != 0;
        if (value.IsString())
            return value.AsString() == "1" || value.AsString() == "true";
        return fallback;
    }

    // Helper to get the current active season ID
    uint32 GetCurrentSeasonId()
    {
        return DarkChaos::GetActiveSeasonId();
    }

    LeaderboardRequest ReadLeaderboardRequest(Player* player, DCAddon::JsonValue const& json)
    {
        LeaderboardRequest request;
        request.playerGuid = player->GetGUID();
        request.accountId = player->GetSession()->GetAccountId();
        request.category = json["category"].IsString() ? json["category"].AsString() : "mplus";
        request.subcategory = json["subcategory"].IsString() ? json["subcategory"].AsString() : "mplus_key";
        request.boardSubcategory = request.subcategory;

        uint32 page = json["page"].IsNumber() ? json["page"].AsUInt32() : 1;
        request.page = std::clamp<uint32>(page, 1, MAX_PAGE);

        uint32 limit = json["limit"].IsNumber() ? json["limit"].AsUInt32() : DEFAULT_ENTRIES_PER_PAGE;
        if (limit > MAX_ENTRIES_PER_PAGE)
            limit = MAX_ENTRIES_PER_PAGE;
        if (limit < 1)
            limit = DEFAULT_ENTRIES_PER_PAGE;
        request.limit = limit;

        // 0 means the current season. The season is part of the board cache
        // key, so only seasons that can hold data are accepted: an arbitrary
        // client value must not mint a new board per request.
        uint32 currentSeason = GetCurrentSeasonId();
        request.seasonId = json["seasonId"].IsNumber() ? json["seasonId"].AsUInt32() : 0;
        if (request.seasonId == 0 || request.seasonId > currentSeason)
            request.seasonId = currentSeason;

        request.view.includeBots = ReadJsonFlag(json, "includeBots", false);
        request.view.perAccount = ReadJsonFlag(json, "perAccount", false);
        request.myRunsOnly = ReadJsonFlag(json, "myRunsOnly", false);
        request.requestId = DCAddon::GetCurrentRequestId();
        request.requestToken = ExtractLeaderboardRequestToken(json);
        return request;
    }

    // Stores a freshly built board and hands it to every request that waited on it.
    void FinishBoardBuild(std::string const& key, LeaderboardBoard&& built)
    {
        built.builtAt = time(nullptr);
        BoardPtr board = std::make_shared<LeaderboardBoard>(std::move(built));

        std::vector<BoardCallback> waiters;
        {
            std::lock_guard<std::mutex> lock(g_cacheMutex);

            if (g_boards.size() >= s_CacheConfig.maxCacheEntries)
            {
                for (auto it = g_boards.begin(); it != g_boards.end();)
                {
                    if (!it->second->IsValid())
                        it = g_boards.erase(it);
                    else
                        ++it;
                }
            }

            // Still full of live boards: drop the oldest so the cap holds.
            if (g_boards.size() >= s_CacheConfig.maxCacheEntries && !g_boards.count(key))
            {
                auto oldest = std::min_element(g_boards.begin(), g_boards.end(),
                    [](auto const& a, auto const& b) { return a.second->builtAt < b.second->builtAt; });
                if (oldest != g_boards.end())
                    g_boards.erase(oldest);
            }

            g_boards[key] = board;

            auto building = g_boardBuilds.find(key);
            if (building != g_boardBuilds.end())
            {
                waiters = std::move(building->second.waiters);
                g_boardBuilds.erase(building);
            }
        }

        LOG_DEBUG("server.scripts", "DC-Leaderboards: Built board {} ({} rows, {} waiting)",
            key, board->rows.size(), waiters.size());

        for (BoardCallback const& waiter : waiters)
            waiter(board);
    }

    // Achievements are shared account-wide (dc_accountwide_achievements
    // replays the pool onto every alt at login), so a per-character board
    // listed each account once per alt. This one ranks ACCOUNTS: everything
    // any character on the account has completed, scored with the points
    // from Achievement.dbc (DC custom achievements included). Statistics
    // counters and hidden internal entries are skipped. Each account is shown
    // under its most played character.
    void BuildAchievementBoard(std::string const& key, std::string const& subcategory)
    {
        struct AccountTotals
        {
            uint32 points = 0;
            uint32 completed = 0;
        };

        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(
            "SELECT c.account, ca.achievement "
            "FROM character_achievement ca "
            "JOIN characters c ON c.guid = ca.guid "
            "WHERE c.account <> 0 "
            "GROUP BY c.account, ca.achievement")
            .WithCallback([key, subcategory](QueryResult pairs)
        {
            std::unordered_map<uint32, AccountTotals> totals;
            if (pairs)
            {
                do
                {
                    Field* fields = pairs->Fetch();
                    AchievementEntry const* achievement = sAchievementStore.LookupEntry(fields[1].Get<uint32>());
                    if (!achievement || (achievement->flags & (ACHIEVEMENT_FLAG_COUNTER | ACHIEVEMENT_FLAG_HIDDEN)))
                        continue;

                    AccountTotals& account = totals[fields[0].Get<uint32>()];
                    account.points += achievement->points;
                    ++account.completed;
                } while (pairs->NextRow());
            }

            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(
                "SELECT m.account, m.guid, m.name, m.class, m.num_chars FROM ("
                "SELECT c.account, c.guid, c.name, c.class, "
                "ROW_NUMBER() OVER (PARTITION BY c.account "
                "ORDER BY c.totaltime DESC, c.level DESC, c.guid ASC) AS rn, "
                "COUNT(*) OVER (PARTITION BY c.account) AS num_chars "
                "FROM characters c "
                "WHERE c.account <> 0) m "
                "WHERE m.rn = 1")
                .WithCallback([key, subcategory, totals = std::move(totals)](QueryResult mains)
            {
                struct AccountRow
                {
                    LeaderboardEntry entry;
                    uint32 points = 0;
                    uint32 completed = 0;
                };

                bool const byCompleted = subcategory == "achieve_completed";
                std::vector<AccountRow> accounts;

                if (mains)
                {
                    do
                    {
                        Field* fields = mains->Fetch();
                        auto it = totals.find(fields[0].Get<uint32>());
                        if (it == totals.end())
                            continue;

                        AccountRow row;
                        row.points = it->second.points;
                        row.completed = it->second.completed;
                        row.entry.accountId = it->first;
                        row.entry.ownerGuid = fields[1].Get<uint32>();
                        row.entry.name = fields[2].Get<std::string>();
                        row.entry.className = GetClassNameFromId(fields[3].Get<uint8>());

                        uint32 characters = fields[4].Get<uint32>();
                        std::string characterText = std::to_string(characters) + (characters == 1 ? " char" : " chars");

                        if (byCompleted)
                        {
                            row.entry.score = row.completed;
                            row.entry.extra = std::to_string(row.points) + " pts, " + characterText;
                        }
                        else
                        {
                            row.entry.score = row.points;
                            row.entry.extra = std::to_string(row.completed) + " done, " + characterText;
                        }

                        accounts.push_back(std::move(row));
                    } while (mains->NextRow());
                }

                std::sort(accounts.begin(), accounts.end(), [byCompleted](AccountRow const& a, AccountRow const& b)
                {
                    uint32 aFirst = byCompleted ? a.completed : a.points;
                    uint32 bFirst = byCompleted ? b.completed : b.points;
                    if (aFirst != bFirst)
                        return aFirst > bFirst;

                    uint32 aSecond = byCompleted ? a.points : a.completed;
                    uint32 bSecond = byCompleted ? b.points : b.completed;
                    if (aSecond != bSecond)
                        return aSecond > bSecond;

                    return a.entry.accountId < b.entry.accountId;
                });

                LeaderboardBoard board;
                board.accountScoped = true;
                board.rows.reserve(accounts.size());
                for (AccountRow& row : accounts)
                    board.rows.push_back(std::move(row.entry));

                MarkBotRows(board.rows);
                FinishBoardBuild(key, std::move(board));
            }));
        }));
    }

    void StartBoardBuild(std::string const& key, std::string const& category, std::string const& subcategory,
        uint32 seasonId)
    {
        if (category == "achieve")
        {
            BuildAchievementBoard(key, subcategory);
            return;
        }

        std::string sql = BuildBoardSql(category, subcategory, seasonId);
        if (sql.empty())
        {
            FinishBoardBuild(key, LeaderboardBoard{});
            return;
        }

        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(sql)
            .WithCallback([key, category, subcategory, seasonId](QueryResult result)
        {
            LeaderboardBoard board;
            board.rows = ParseBoardRows(result, category, subcategory, seasonId);

            // Characters unlinked by CharDelete.Method = 1 keep their row but
            // move to account 0 with a blank name; they are not on any board.
            board.rows.erase(std::remove_if(board.rows.begin(), board.rows.end(),
                [](LeaderboardEntry const& row) { return row.accountId == 0; }), board.rows.end());

            MarkBotRows(board.rows);
            FinishBoardBuild(key, std::move(board));
        }));
    }

    // Runs `callback` with the board, straight away from the cache or once a
    // build finishes. Concurrent requests for a stale board share one build.
    void WithBoard(std::string const& category, std::string const& subcategory, uint32 seasonId,
        BoardCallback callback)
    {
        std::string const key = MakeBoardKey(category, subcategory, seasonId);

        BoardPtr cached;
        {
            std::lock_guard<std::mutex> lock(g_cacheMutex);

            auto it = g_boards.find(key);
            if (it != g_boards.end() && it->second->IsValid())
            {
                cached = it->second;
            }
            else
            {
                time_t now = time(nullptr);
                PendingBoardBuild& build = g_boardBuilds[key];
                bool const buildInFlight = !build.waiters.empty()
                    && now - build.startedAt < BOARD_BUILD_TIMEOUT_SECONDS;

                build.waiters.push_back(std::move(callback));
                if (buildInFlight)
                    return;

                build.startedAt = now;
            }
        }

        if (cached)
        {
            callback(cached);
            return;
        }

        StartBoardBuild(key, category, subcategory, seasonId);
    }

    struct BoardPage
    {
        std::vector<LeaderboardEntry> entries;
        uint32 totalEntries = 0;
        bool accountScoped = false;
        uint32 myRank = 0;         // 0 = the requester is not on this board
        uint32 myScore = 0;
        std::string myScoreStr;
    };

    void LabelBot(std::string& name)
    {
        // Mythic+ queries already label bot runs.
        if (name.rfind("BOT ", 0) != 0)
            name.insert(0, "BOT ");
    }

    // Walks the board once: applies the view (bots, one row per account),
    // numbers the rows that remain, finds the requester and slices the page.
    BoardPage CutBoardPage(LeaderboardBoard const& board, BoardView const& view, uint32 offset, uint32 limit,
        uint32 requesterGuid, uint32 requesterAccount)
    {
        BoardPage page;
        page.accountScoped = board.accountScoped || view.perAccount;
        bool const collapseAccounts = view.perAccount && !board.accountScoped;

        std::unordered_set<uint32> seenAccounts;
        uint32 rank = 0;

        for (LeaderboardEntry const& row : board.rows)
        {
            if (row.isBot && !view.includeBots)
                continue;

            // Rows are best first, so the first row of an account is its best.
            if (collapseAccounts && !seenAccounts.insert(row.accountId).second)
                continue;

            ++rank;

            bool const own = page.accountScoped ? row.accountId == requesterAccount : row.ownerGuid == requesterGuid;
            if (own && !page.myRank)
            {
                page.myRank = rank;
                page.myScore = row.score;
                page.myScoreStr = row.score_str;
            }

            if (rank <= offset || page.entries.size() >= limit)
                continue;

            LeaderboardEntry& entry = page.entries.emplace_back(row);
            entry.rank = rank;
            entry.isSelf = own;
            entry.isAlt = !own && row.accountId == requesterAccount;
            if (row.isBot)
                LabelBot(entry.name);
        }

        page.totalEntries = rank;
        return page;
    }

    uint32 CountPages(uint32 totalEntries, uint32 limit)
    {
        return std::max<uint32>(1, (totalEntries + limit - 1) / limit);
    }

    // Serialize one leaderboard entry.
    std::string BuildEntryJson(LeaderboardEntry const& entry)
    {
        std::string json = "{";
        json += "\"rank\":" + std::to_string(entry.rank) + ",";
        json += "\"name\":\"" + JsonEscape(entry.name) + "\",";
        json += "\"class\":\"" + JsonEscape(entry.className) + "\",";
        json += "\"score\":" + std::to_string(entry.score) + ",";
        // v1.3.0: Add score_str for large values (gold, damage as uint64)
        if (!entry.score_str.empty())
            json += "\"score_str\":\"" + JsonEscape(entry.score_str) + "\",";
        // v1.3.0: Add mapId for per-dungeon display
        if (entry.mapId > 0)
            json += "\"mapId\":" + std::to_string(entry.mapId) + ",";

        if (entry.isSelf)
            json += "\"self\":true,";
        if (entry.isAlt)
            json += "\"alt\":true,";
        if (entry.isBot)
            json += "\"bot\":true,";

        // HLBG: provide structured fields expected by the addon UI
        if (entry.hasWinsLosses)
        {
            json += "\"wins\":" + std::to_string(entry.wins) + ",";
            json += "\"losses\":" + std::to_string(entry.losses) + ",";
        }

        if (entry.hasKD)
        {
            json += "\"kills\":" + std::to_string(entry.kills) + ",";
            json += "\"deaths\":" + std::to_string(entry.deaths) + ",";
            // Use a compact float representation (client handles tonumber)
            json += "\"kdRatio\":" + std::to_string(entry.kdRatio) + ",";
        }

        // AOE Loot: provide separate quality columns (v1.4.0 client)
        if (entry.hasQuality)
        {
            json += "\"qLeg\":" + std::to_string(entry.qLeg) + ",";
            json += "\"qEpic\":" + std::to_string(entry.qEpic) + ",";
            json += "\"qRare\":" + std::to_string(entry.qRare) + ",";
            json += "\"qUncommon\":" + std::to_string(entry.qUncommon) + ",";
        }

        json += "\"extra\":\"" + JsonEscape(entry.extra) + "\"";
        json += "}";
        return json;
    }

    // Everything in SMSG_LEADERBOARD_DATA besides the entries.
    struct PageHeader
    {
        std::string category;
        std::string subcategory;
        uint32 page = 1;
        uint32 totalPages = 1;
        uint32 totalEntries = 0;
        BoardView view;
        bool accountScoped = false;
        bool myRunsOnly = false;
        uint32 myRank = 0;
        uint32 myScore = 0;
        std::string myScoreStr;
    };

    // Serialize the SMSG_LEADERBOARD_DATA payload. The view flags are echoed
    // so the client files the reply under the view it was requested for.
    std::string BuildLeaderboardJson(PageHeader const& header, std::vector<LeaderboardEntry> const& entries)
    {
        auto flag = [](bool value) { return std::string(value ? "true" : "false"); };

        std::string entriesJson = "[";
        for (size_t i = 0; i < entries.size(); ++i)
        {
            if (i > 0)
                entriesJson += ",";
            entriesJson += BuildEntryJson(entries[i]);
        }
        entriesJson += "]";

        std::string fullJson = "{";
        fullJson += "\"category\":\"" + JsonEscape(header.category) + "\",";
        fullJson += "\"subcategory\":\"" + JsonEscape(header.subcategory) + "\",";
        fullJson += "\"page\":" + std::to_string(header.page) + ",";
        fullJson += "\"totalPages\":" + std::to_string(header.totalPages) + ",";
        fullJson += "\"totalEntries\":" + std::to_string(header.totalEntries) + ",";
        fullJson += "\"accountScoped\":" + flag(header.accountScoped) + ",";
        fullJson += "\"includeBots\":" + flag(header.view.includeBots) + ",";
        fullJson += "\"perAccount\":" + flag(header.view.perAccount) + ",";
        fullJson += "\"myRunsOnly\":" + flag(header.myRunsOnly) + ",";
        fullJson += "\"myRank\":" + std::to_string(header.myRank) + ",";
        fullJson += "\"myScore\":" + std::to_string(header.myScore) + ",";
        if (!header.myScoreStr.empty())
            fullJson += "\"myScoreStr\":\"" + JsonEscape(header.myScoreStr) + "\",";
        fullJson += "\"entries\":" + entriesJson;
        fullJson += "}";
        return fullJson;
    }

    void SendLeaderboardPage(Player* player, LeaderboardRequest const& request, PageHeader const& header,
        std::vector<LeaderboardEntry> const& entries)
    {
        std::string fullJson = BuildLeaderboardJson(header, entries);
        SendRawJson(player, Opcode::SMSG_LEADERBOARD_DATA, fullJson, request.requestId);
        SendLeaderboardResponseEnvelope(player, Opcode::SMSG_LEADERBOARD_DATA,
            StatsFeature::LEADERBOARD, fullJson, request.requestToken);
    }

    void SendBoardPage(Player* player, LeaderboardRequest const& request, LeaderboardBoard const& board)
    {
        uint32 offset = (request.page - 1) * request.limit;
        BoardPage page = CutBoardPage(board, request.view, offset, request.limit,
            request.playerGuid.GetCounter(), request.accountId);

        PageHeader header;
        header.category = request.category;
        header.subcategory = request.subcategory;
        header.page = request.page;
        header.totalEntries = page.totalEntries;
        header.totalPages = CountPages(page.totalEntries, request.limit);
        header.view = request.view;
        header.accountScoped = page.accountScoped;
        header.myRank = page.myRank;
        header.myScore = page.myScore;
        header.myScoreStr = page.myScoreStr;

        SendLeaderboardPage(player, request, header, page.entries);
    }

    // Store a freshly fetched run-history page in the page cache (with
    // oldest-entry eviction).
    void StoreLeaderboardCache(std::string const& cacheKey, std::vector<LeaderboardEntry> const& entries,
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

    void SendRunHistoryResponse(Player* player, LeaderboardRequest const& request,
        std::vector<LeaderboardEntry> entries, uint32 totalEntries)
    {
        uint32 requesterGuid = request.playerGuid.GetCounter();
        for (LeaderboardEntry& entry : entries)
        {
            entry.isSelf = entry.ownerGuid == requesterGuid;
            entry.isAlt = !entry.isSelf && entry.accountId == request.accountId;
        }

        PageHeader header;
        header.category = request.category;
        header.subcategory = request.subcategory;
        header.page = request.page;
        header.totalEntries = totalEntries;
        header.totalPages = CountPages(totalEntries, request.limit);
        header.view = request.view;
        header.myRunsOnly = request.myRunsOnly;

        SendLeaderboardPage(player, request, header, entries);
    }

    void SendRunHistoryPage(Player* player, LeaderboardRequest const& request)
    {
        uint32 requesterGuid = request.playerGuid.GetCounter();
        uint32 offset = (request.page - 1) * request.limit;

        std::string cacheSubcategory = "mplus_history";
        if (request.myRunsOnly)
            cacheSubcategory += "_self_" + std::to_string(requesterGuid);
        else
            cacheSubcategory += request.view.includeBots ? "_all" : "_players";

        std::string cacheKey = MakeCacheKey(request.category, cacheSubcategory, request.seasonId,
            request.page, request.limit);

        bool cacheHit = false;
        std::vector<LeaderboardEntry> cachedEntries;
        uint32 cachedTotal = 0;
        {
            std::lock_guard<std::mutex> lock(g_cacheMutex);
            auto it = g_leaderboardCache.find(cacheKey);
            if (it != g_leaderboardCache.end() && it->second.IsValid())
            {
                cacheHit = true;
                cachedEntries = it->second.entries;
                cachedTotal = it->second.totalEntries;
            }
        }

        if (cacheHit)
        {
            LOG_DEBUG("server.scripts", "DC-Leaderboards: Cache HIT for {}", cacheKey);
            SendRunHistoryResponse(player, request, std::move(cachedEntries), cachedTotal);
            return;
        }

        std::string filter = RunHistoryFilter(request.seasonId, requesterGuid, request.myRunsOnly,
            request.view.includeBots);
        std::string fetchSql = BuildRunHistorySql(filter, request.limit, offset);
        std::string countSql = BuildRunHistoryCountSql(filter);

        // Never capture Player* across queries; re-resolve from the guid at send time.
        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(fetchSql)
            .WithCallback([request, offset, cacheKey, countSql](QueryResult result)
        {
            std::vector<LeaderboardEntry> entries = ParseRunHistory(result, request.seasonId, offset);
            MarkBotRows(entries);

            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(countSql)
                .WithCallback([request, cacheKey, entries = std::move(entries)](QueryResult countResult)
            {
                uint32 totalEntries = countResult ? countResult->Fetch()[0].Get<uint32>() : 0;

                // Cache even if the requester logged off meanwhile
                StoreLeaderboardCache(cacheKey, entries, totalEntries);

                Player* player = ObjectAccessor::FindPlayer(request.playerGuid);
                if (!player || !player->GetSession())
                    return;

                SendRunHistoryResponse(player, request, entries, totalEntries);
            }));
        }));
    }

    // ========================================================================
    // MESSAGE HANDLERS
    // ========================================================================

    void HandleGetLeaderboard(Player* player, DCAddon::ParsedMessage const& msg)
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
        LeaderboardRequest request = ReadLeaderboardRequest(player, json);

        LOG_DEBUG("server.scripts",
            "DC-Leaderboards: Request for {}/{} page {} limit {} season {} (bots={}, perAccount={})",
            request.category, request.subcategory, request.page, request.limit, request.seasonId,
            request.view.includeBots, request.view.perAccount);

        if (!NormalizeBoardRequest(request))
        {
            // Unknown category: empty payload, without DB round-trips
            SendBoardPage(player, request, LeaderboardBoard{});
            return;
        }

        if (IsRunHistory(request))
        {
            SendRunHistoryPage(player, request);
            return;
        }

        WithBoard(request.category, request.boardSubcategory, request.seasonId, [request](BoardPtr const& board)
        {
            Player* player = ObjectAccessor::FindPlayer(request.playerGuid);
            if (!player || !player->GetSession())
                return;

            SendBoardPage(player, request, *board);
        });
    }

    void HandleGetCategories(Player* player, DCAddon::ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        // Send available categories (client already has these hardcoded, but we can confirm)
        DCAddon::JsonMessage response(MODULE_LEADERBOARD, Opcode::SMSG_CATEGORIES);
        response.Set("success", true);
        response.Set("count", static_cast<uint32>(KnownSubcategories.size()));
        response.Send(player);
    }

    void SendMyRankResponse(Player* player, LeaderboardRequest const& request, BoardPage const& page)
    {
        double percentile = (page.myRank && page.totalEntries)
            ? static_cast<double>(page.myRank) / page.totalEntries * 100.0 : 0.0;

        DCAddon::JsonMessage response(MODULE_LEADERBOARD, Opcode::SMSG_MY_RANK);
        response.SetRequestId(request.requestId);
        response.Set("category", request.category);
        response.Set("subcategory", request.subcategory);
        response.Set("rank", page.myRank);
        response.Set("total", page.totalEntries);
        response.Set("percentile", percentile);
        response.Set("score", page.myScore);
        if (!page.myScoreStr.empty())
            response.Set("score_str", page.myScoreStr);
        response.Set("accountScoped", page.accountScoped);
        response.Set("includeBots", request.view.includeBots);
        response.Set("perAccount", request.view.perAccount);
        response.Send(player);
    }

    // Answered from the same board the leaderboard page is cut from, so the
    // rank always matches the list (it used to exist for M+ Best Key only).
    void HandleGetMyRank(Player* player, DCAddon::ParsedMessage const& msg)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        LeaderboardRequest request = ReadLeaderboardRequest(player, json);

        // Unknown categories and the run history (a log, not a ranking) have no rank
        if (!NormalizeBoardRequest(request) || IsRunHistory(request))
        {
            SendMyRankResponse(player, request, BoardPage{});
            return;
        }

        WithBoard(request.category, request.boardSubcategory, request.seasonId, [request](BoardPtr const& board)
        {
            Player* player = ObjectAccessor::FindPlayer(request.playerGuid);
            if (!player || !player->GetSession())
                return;

            BoardPage page = CutBoardPage(*board, request.view, 0, 0,
                request.playerGuid.GetCounter(), request.accountId);
            SendMyRankResponse(player, request, page);
        });
    }

    void HandleRefresh(Player* player, DCAddon::ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        // Every player shares these caches: spamming Refresh must not turn
        // into a stream of full-table queries.
        static std::atomic<time_t> s_lastFlush{0};
        time_t now = time(nullptr);
        time_t last = s_lastFlush.load();
        if (now - last >= REFRESH_THROTTLE_SECONDS && s_lastFlush.compare_exchange_strong(last, now))
        {
            ClearAllCaches();
            LOG_DEBUG("server.scripts", "DC-Leaderboards: Player {} requested refresh, caches cleared",
                player->GetName());
        }

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
        "dc_player_artifact_mastery",
        "dc_item_upgrades",
        "dc_duel_statistics",
        "dc_aoeloot_detailed_stats",
        "character_achievement"
    };

    void HandleTestTables(Player* player, DCAddon::ParsedMessage const& /*msg*/)
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

            DCAddon::EnqueueQueryCallback(WorldDatabase.AsyncQuery("SELECT COUNT(*) AS total FROM dc_seasons")
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

    void HandleGetSeasons(Player* player, DCAddon::ParsedMessage const& /*msg*/)
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
    void HandleGetMythicPlusDungeons(Player* player, DCAddon::ParsedMessage const& msg)
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
    void HandleGetAccountStats(Player* player, DCAddon::ParsedMessage const& /*msg*/)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = player->GetSession()->GetAccountId();

        LOG_DEBUG("server.scripts", "DC-Leaderboards: Getting account stats for account {}", accountId);

        // ===== CACHE CHECK =====
        std::string cachedJson;
        {
            std::lock_guard<std::mutex> lock(g_cacheMutex);
            auto it = g_accountStatsCache.find(accountId);
            if (it != g_accountStatsCache.end() && it->second.IsValid())
                cachedJson = it->second.jsonResponse;
        }

        if (!cachedJson.empty())
        {
            // Cache hit! Send cached response (outside the lock)
            LOG_DEBUG("server.scripts", "DC-Leaderboards: Account stats cache HIT for account {}", accountId);
            SendRawJson(player, Opcode::SMSG_ACCOUNT_STATS, cachedJson);
            return;
        }

        LOG_DEBUG("server.scripts", "DC-Leaderboards: Account stats cache MISS for account {}", accountId);

        // Async rebuild: the M+ "Best Key Level" board of the current season
        // supplies each character's rank (the same ranking the leaderboard
        // shows, playerbots hidden), then one query lists the characters and
        // one aggregates the account totals. The world thread only assembles JSON.
        ObjectGuid const playerGuid = player->GetGUID();
        std::string requestId = DCAddon::GetCurrentRequestId();

        WithBoard("mplus", "mplus_key", GetCurrentSeasonId(), [playerGuid, accountId, requestId](BoardPtr const& board)
        {
            std::unordered_map<uint32, uint32> mplusRanks;  // character guid -> rank
            uint32 rank = 0;
            for (LeaderboardEntry const& row : board->rows)
            {
                if (row.isBot)
                    continue;

                ++rank;
                if (row.accountId == accountId)
                    mplusRanks.emplace(row.ownerGuid, rank);
            }

            std::string charsSql = Acore::StringFormat(
                "SELECT c.guid, c.name, c.class, c.level "
                "FROM characters c "
                "WHERE c.account = {} "
                "ORDER BY c.level DESC, c.name ASC",
                accountId);

            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(charsSql)
                .WithCallback([playerGuid, accountId, requestId, mplusRanks = std::move(mplusRanks)](QueryResult result)
            {
                std::string charactersJson = "[";
                bool first = true;

                if (result)
                {
                    do
                    {
                        Field* fields = result->Fetch();
                        uint32 guid = fields[0].Get<uint32>();
                        std::string name = fields[1].Get<std::string>();
                        uint8 classId = fields[2].Get<uint8>();
                        uint8 level = fields[3].Get<uint8>();

                        std::string className = GetClassNameFromId(classId);

                        // M+ is currently the only ranked category shown here;
                        // characters without an M+ score this season have no rank.
                        uint32 bestRank = 0;
                        std::string bestCategory = "";
                        auto rankIt = mplusRanks.find(guid);
                        if (rankIt != mplusRanks.end())
                        {
                            bestRank = rankIt->second;
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
                    "(SELECT COALESCE(SUM(s.total_runs), 0) FROM dc_mplus_scores s "
                    "JOIN characters c ON s.character_guid = c.guid WHERE c.account = {0}), "
                    "(SELECT COALESCE(SUM(a.total_gold), 0) FROM dc_aoeloot_detailed_stats a "
                    "JOIN characters c ON a.player_guid = c.guid WHERE c.account = {0}), "
                    "(SELECT COALESCE(SUM(a.total_items), 0) FROM dc_aoeloot_detailed_stats a "
                    "JOIN characters c ON a.player_guid = c.guid WHERE c.account = {0}), "
                    "(SELECT COALESCE(SUM(h.battles_won), 0) FROM dc_hlbg_player_stats h "
                    "JOIN characters c ON h.player_guid = c.guid WHERE c.account = {0})",
                    accountId);

                DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(totalsSql)
                    .WithCallback([playerGuid, accountId, requestId, charactersJson](QueryResult totals)
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
                    // Convert copper to gold
                    totalsJson += ",\"Total Gold Looted\":" + std::to_string(totalGold / 10000);
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
                            SendRawJson(player, Opcode::SMSG_ACCOUNT_STATS, fullJson, requestId);
                }));
            }));
        });
    }

    // Error handler for future use
    [[maybe_unused]] void HandleError(Player* player, std::string const& message)
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

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        s_CacheConfig.Load();
    }

    void OnStartup() override
    {
        s_CacheConfig.Load();
        LoadBotAccounts();
        RegisterLeaderboardHandlers();
    }

    void OnUpdate(uint32 diff) override
    {
        _botAccountTimer += diff;
        if (_botAccountTimer < BOT_ACCOUNT_REFRESH_MS)
            return;

        _botAccountTimer = 0;
        RefreshBotAccountsAsync();
    }

private:
    uint32 _botAccountTimer = 0;
};

void AddSC_dc_addon_leaderboards()
{
    new dc_addon_leaderboards_world();
}
