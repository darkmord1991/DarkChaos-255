/*
 * Dark Chaos - Welcome/First-Start Addon Handler
 * ================================================
 *
 * Server-side handler for the DC-Welcome addon.
 * Provides first-login detection, server info sync, and progressive introduction.
 *
 * Features:
 * - First-login detection and welcome popup trigger
 * - Server configuration sync (max level, season, links)
 * - Progressive feature unlock notifications
 * - Level milestone messages
 * - FAQ data sync
 * - Progress data sync (M+ rating, prestige, seasons)
 *
 * Message Format:
 * - JSON format: WELC|OPCODE|J|{json}
 *
 * Opcodes:
 * - CMSG: 0x01 (GET_SERVER_INFO), 0x02 (GET_FAQ), 0x03 (DISMISS), 0x04 (MARK_SEEN), 0x05 (GET_WHATS_NEW), 0x06 (GET_PROGRESS)
 * - SMSG: 0x10 (SHOW_WELCOME), 0x11 (SERVER_INFO), 0x12 (FAQ_DATA), 0x13 (FEATURE_UNLOCK), 0x14 (WHATS_NEW), 0x15 (LEVEL_MILESTONE), 0x16 (PROGRESS_DATA)
 *
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "GameTime.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"
#include "Chat.h"
#include "WorldPacket.h"
#include "DatabaseEnv.h"
#include "dc_addon_namespace.h"
#include "Config.h"
#include "World.h"
#include "AchievementMgr.h"
#include "../CrossSystem/CrossSystemSeasonHelper.h"
#include "../CrossSystem/CrossSystemDbSchema.h"
#include "../Seasons/DCWeeklyResetHub.h"
#include <algorithm>
#include <cctype>
#include <ctime>
#include <mutex>
#include <string>
#include <sstream>
#include <unordered_map>

namespace DCWelcome
{
    namespace
    {
        constexpr std::time_t WELCOME_CONTENT_CACHE_TTL_SECS = 30;
        constexpr uint64 WELCOME_PROGRESS_CACHE_TTL_MS = 1000;

        struct CachedFaqPayload
        {
            std::string entries = "[]";
            uint32 count = 0;
            std::time_t expiresAt = 0;
        };

        struct CachedWhatsNewPayload
        {
            std::string version = "1.0.0";
            std::string entries = "[]";
            uint32 count = 0;
            std::time_t expiresAt = 0;
        };

        struct CachedProgressPayload
        {
            uint32 accountId = 0;
            uint32 activeSeason = 0;
            uint32 weekStart = 0;
            uint32 maxLevel = 0;
            std::string data = "{}";
            uint64 expiresAtMs = 0;
        };

        std::mutex sWelcomeContentCacheLock;
        std::unordered_map<std::string, CachedFaqPayload> sCachedFaqPayloads;
        std::unordered_map<uint32, CachedProgressPayload> sCachedProgressPayloads;
        CachedWhatsNewPayload sCachedWhatsNewPayload;

        std::string NormalizeFaqCategoryFilter(std::string categoryFilter)
        {
            if (categoryFilter.empty())
                return "all";

            std::transform(categoryFilter.begin(), categoryFilter.end(),
                categoryFilter.begin(), [](unsigned char value)
                {
                    return static_cast<char>(std::tolower(value));
                });

            if (categoryFilter == "all")
                return "all";

            if (!std::all_of(categoryFilter.begin(), categoryFilter.end(),
                [](unsigned char value)
                {
                    return std::isalnum(value) || value == '_';
                }))
            {
                return "all";
            }

            return categoryFilter;
        }

        CachedFaqPayload LoadFaqPayload(std::string const& categoryFilter)
        {
            CachedFaqPayload payload;
            std::string query =
                "SELECT id, category, question, answer FROM dc_welcome_faq WHERE active = 1";

            if (categoryFilter != "all")
                query += " AND category = '" + categoryFilter + "'";

            query += " ORDER BY category, priority DESC, id";

            if (QueryResult result = WorldDatabase.Query(query))
            {
                DCAddon::JsonValue entriesArray;
                entriesArray.SetArray();

                do
                {
                    Field* fields = result->Fetch();
                    DCAddon::JsonValue entry;
                    entry.SetObject();
                    entry.Set("id", DCAddon::JsonValue(static_cast<int32>(fields[0].Get<uint32>())));
                    entry.Set("category", DCAddon::JsonValue(fields[1].Get<std::string>()));
                    entry.Set("question", DCAddon::JsonValue(fields[2].Get<std::string>()));
                    entry.Set("answer", DCAddon::JsonValue(fields[3].Get<std::string>()));
                    entriesArray.Push(entry);
                    ++payload.count;
                } while (result->NextRow());

                payload.entries = entriesArray.Encode();
            }

            payload.expiresAt = std::time(nullptr) + WELCOME_CONTENT_CACHE_TTL_SECS;
            return payload;
        }

        CachedFaqPayload GetCachedFaqPayload(std::string const& categoryFilter)
        {
            std::string const normalizedFilter = NormalizeFaqCategoryFilter(categoryFilter);
            std::time_t const now = std::time(nullptr);
            std::lock_guard<std::mutex> lock(sWelcomeContentCacheLock);

            auto itr = sCachedFaqPayloads.find(normalizedFilter);
            if (itr != sCachedFaqPayloads.end() && itr->second.expiresAt > now)
                return itr->second;

            CachedFaqPayload payload = LoadFaqPayload(normalizedFilter);
            sCachedFaqPayloads[normalizedFilter] = payload;
            return payload;
        }

        CachedWhatsNewPayload LoadWhatsNewPayload()
        {
            CachedWhatsNewPayload payload;

            if (QueryResult result = WorldDatabase.Query(
                "SELECT id, version, title, content, icon, category FROM dc_welcome_whats_new "
                "WHERE active = 1 AND (expires_at IS NULL OR expires_at > NOW()) "
                "ORDER BY priority DESC, id DESC LIMIT 10"))
            {
                DCAddon::JsonValue entriesArray;
                entriesArray.SetArray();

                do
                {
                    Field* fields = result->Fetch();
                    DCAddon::JsonValue entry;
                    entry.SetObject();
                    entry.Set("id", DCAddon::JsonValue(static_cast<int32>(fields[0].Get<uint32>())));
                    entry.Set("version", DCAddon::JsonValue(fields[1].Get<std::string>()));
                    entry.Set("title", DCAddon::JsonValue(fields[2].Get<std::string>()));
                    entry.Set("content", DCAddon::JsonValue(fields[3].Get<std::string>()));
                    entry.Set("icon", DCAddon::JsonValue(fields[4].Get<std::string>()));
                    entry.Set("category", DCAddon::JsonValue(fields[5].Get<std::string>()));
                    entriesArray.Push(entry);
                    ++payload.count;

                    if (payload.version == "1.0.0")
                        payload.version = fields[1].Get<std::string>();
                } while (result->NextRow());

                payload.entries = entriesArray.Encode();
            }

            payload.expiresAt = std::time(nullptr) + WELCOME_CONTENT_CACHE_TTL_SECS;
            return payload;
        }

        CachedWhatsNewPayload GetCachedWhatsNewPayload()
        {
            std::time_t const now = std::time(nullptr);
            std::lock_guard<std::mutex> lock(sWelcomeContentCacheLock);

            if (sCachedWhatsNewPayload.expiresAt > now)
                return sCachedWhatsNewPayload;

            sCachedWhatsNewPayload = LoadWhatsNewPayload();
            return sCachedWhatsNewPayload;
        }

        bool HasWeeklyVaultSummary()
        {
            static bool const hasWeeklyVaultTable = DC::DbSchema::CharacterTableExists("dc_weekly_vault");
            return hasWeeklyVaultTable
                && sConfigMgr->GetOption<bool>("MythicPlus.Vault.Enabled", false);
        }

        bool HasSeasonalProgressSummary()
        {
            static bool const hasSeasonalStatsTable = DC::DbSchema::CharacterTableExists("dc_player_seasonal_stats");
            return hasSeasonalStatsTable;
        }

        uint32 GetWeeklySeasonPointCap()
        {
            uint32 cap = sConfigMgr->GetOption<uint32>("DarkChaos.Seasonal.WeeklyTokenCap", 0);
            if (cap == 0)
                cap = sConfigMgr->GetOption<uint32>("SeasonalRewards.MaxTokensPerWeek", 0);

            return cap > 0 ? cap : 1000;
        }

        std::string const& BuildProgressSnapshotQuery(bool useWeeklyVaultSummary,
            bool useSeasonalProgressSummary)
        {
            static std::array<std::string, 4> const queries = []
            {
                std::array<std::string, 4> builtQueries;
                auto buildQuery = [](bool useWeeklyVault, bool useSeasonalSummary)
                {
                    std::string seasonPointsSelect;
                    std::string seasonPointsJoin;
                    if (useSeasonalSummary)
                    {
                        seasonPointsSelect = "COALESCE(s.weekly_tokens_earned, 0)";
                        seasonPointsJoin =
                            "LEFT JOIN dc_player_seasonal_stats s "
                            "ON s.player_guid = {} AND s.season_id = {} ";
                    }
                    else
                    {
                        seasonPointsSelect = "COALESCE(sp.season_points, 0)";
                        seasonPointsJoin =
                            "LEFT JOIN (SELECT COALESCE(SUM(best_score), 0) AS season_points "
                            "FROM dc_mplus_scores WHERE character_guid = {} AND season_id = {}) sp "
                            "ON 1 = 1 ";
                    }

                    std::string weeklyRunsSelect;
                    std::string weeklyRunsJoin;
                    if (useWeeklyVault)
                    {
                        weeklyRunsSelect = "COALESCE(v.runs_completed, 0)";
                        weeklyRunsJoin =
                            "LEFT JOIN dc_weekly_vault v "
                            "ON v.character_guid = {} AND v.season_id = {} "
                            "AND v.week_start = {} ";
                    }
                    else
                    {
                        weeklyRunsSelect = "COALESCE(wr.runs_completed, 0)";
                        weeklyRunsJoin =
                            "LEFT JOIN (SELECT COUNT(*) AS runs_completed FROM dc_mplus_runs "
                            "WHERE character_guid = {} AND season_id = {} AND success = 1 "
                            "AND completed_at >= FROM_UNIXTIME({}) "
                            "AND completed_at < FROM_UNIXTIME({})) wr ON 1 = 1 ";
                    }

                    return std::string(
                        "SELECT COALESCE(r.rating, 0), COALESCE(p.prestige_level, 0), ")
                        + seasonPointsSelect + ", " + weeklyRunsSelect + ", "
                        + "LEAST(5, COALESCE(alt.alt_count, 0)) "
                        + "FROM (SELECT 1) seed "
                        + "LEFT JOIN dc_mplus_player_ratings r "
                        + "ON r.player_guid = {} AND r.season_id = {} "
                        + "LEFT JOIN dc_character_prestige p ON p.guid = {} "
                        + seasonPointsJoin
                        + weeklyRunsJoin
                        + "LEFT JOIN (SELECT COUNT(*) AS alt_count FROM characters "
                        + "WHERE account = {} AND level >= {}) alt ON 1 = 1";
                };

                builtQueries[0] = buildQuery(false, false);
                builtQueries[1] = buildQuery(false, true);
                builtQueries[2] = buildQuery(true, false);
                builtQueries[3] = buildQuery(true, true);
                return builtQueries;
            }();

            std::size_t const queryIndex =
                (useWeeklyVaultSummary ? 2u : 0u)
                + (useSeasonalProgressSummary ? 1u : 0u);
            return queries[queryIndex];
        }

        struct ProgressSnapshot
        {
            uint32 mythicRating = 0;
            uint32 prestigeLevel = 0;
            uint32 seasonPoints = 0;
            uint32 seasonPointsMax = 1000;
            uint32 completedRunsThisWeek = 0;
            uint32 altBonusLevel = 0;
        };

        ProgressSnapshot LoadProgressSnapshot(uint32 guid, uint32 accountId,
            uint32 activeSeason, uint32 weekStart, uint32 weekEnd,
            uint32 maxLevel)
        {
            ProgressSnapshot snapshot;
            bool const useWeeklyVaultSummary = HasWeeklyVaultSummary();
            bool const useSeasonalProgressSummary = HasSeasonalProgressSummary();

            if (useSeasonalProgressSummary)
                snapshot.seasonPointsMax = GetWeeklySeasonPointCap();

            QueryResult result;
            std::string const& query = BuildProgressSnapshotQuery(
                useWeeklyVaultSummary, useSeasonalProgressSummary);

            if (useWeeklyVaultSummary)
            {
                result = CharacterDatabase.Query(
                    query,
                    guid,
                    activeSeason,
                    guid,
                    guid, activeSeason,
                    guid, activeSeason, weekStart,
                    accountId, maxLevel);
            }
            else
            {
                result = CharacterDatabase.Query(
                    query,
                    guid,
                    activeSeason,
                    guid,
                    guid, activeSeason,
                    guid, activeSeason, weekStart, weekEnd,
                    accountId, maxLevel);
            }

            if (!result)
                return snapshot;

            Field* fields = result->Fetch();
            snapshot.mythicRating = fields[0].Get<uint32>();
            snapshot.prestigeLevel = fields[1].Get<uint32>();
            snapshot.seasonPoints = fields[2].Get<uint32>();
            snapshot.completedRunsThisWeek = fields[3].Get<uint32>();
            snapshot.altBonusLevel = fields[4].Get<uint32>();
            return snapshot;
        }

        uint32 CalculateAchievementPoints(Player* player)
        {
            if (!player)
                return 0;

            uint32 achievementPoints = 0;
            if (AchievementMgr* achieveMgr = player->GetAchievementMgr())
            {
                CompletedAchievementMap const& completedAchievements =
                    achieveMgr->GetCompletedAchievements();
                for (auto const& [achievementId, completedData]
                    : completedAchievements)
                {
                    if (AchievementEntry const* achievement =
                        sAchievementStore.LookupEntry(achievementId))
                    {
                        achievementPoints += achievement->points;
                    }
                }
            }

            return achievementPoints;
        }

        CachedProgressPayload BuildProgressPayload(Player* player,
            uint32 accountId, uint32 activeSeason, uint32 weekStart,
            uint32 weekEnd, uint32 maxLevel)
        {
            CachedProgressPayload payload;
            if (!player)
                return payload;

            uint32 guid = player->GetGUID().GetCounter();
            ProgressSnapshot snapshot = LoadProgressSnapshot(guid, accountId,
                activeSeason, weekStart, weekEnd, maxLevel);
            uint32 achievementPoints = CalculateAchievementPoints(player);
            uint32 weeklyVaultProgress = std::min(static_cast<uint32>(3),
                snapshot.completedRunsThisWeek);
            uint32 altBonusPercent = snapshot.altBonusLevel * 5;

            DCAddon::JsonValue data;
            data.SetObject();
            data.Set("mythicRating", static_cast<int32>(snapshot.mythicRating));
            data.Set("prestigeLevel", static_cast<int32>(snapshot.prestigeLevel));
            data.Set("prestigeXP", 0);
            data.Set("seasonPoints", static_cast<int32>(snapshot.seasonPoints));
            data.Set("seasonPointsMax", static_cast<int32>(snapshot.seasonPointsMax));
            data.Set("seasonRank", 0);
            data.Set("weeklyVaultProgress", static_cast<int32>(weeklyVaultProgress));
            data.Set("achievementPoints", static_cast<int32>(achievementPoints));
            data.Set("keysThisWeek", static_cast<int32>(snapshot.completedRunsThisWeek));
            data.Set("altBonusLevel", static_cast<int32>(snapshot.altBonusLevel));
            data.Set("altBonusPercent", static_cast<int32>(altBonusPercent));

            payload.accountId = accountId;
            payload.activeSeason = activeSeason;
            payload.weekStart = weekStart;
            payload.maxLevel = maxLevel;
            payload.data = data.Encode();
            payload.expiresAtMs = static_cast<uint64>(
                GameTime::GetGameTimeMS().count())
                + WELCOME_PROGRESS_CACHE_TTL_MS;
            return payload;
        }

        CachedProgressPayload GetCachedProgressPayload(Player* player,
            uint32 accountId, uint32 activeSeason, uint32 weekStart,
            uint32 weekEnd, uint32 maxLevel)
        {
            CachedProgressPayload payload;
            if (!player)
                return payload;

            uint32 guid = player->GetGUID().GetCounter();
            uint64 nowMs = static_cast<uint64>(GameTime::GetGameTimeMS().count());

            {
                std::lock_guard<std::mutex> lock(sWelcomeContentCacheLock);
                auto itr = sCachedProgressPayloads.find(guid);
                if (itr != sCachedProgressPayloads.end()
                    && itr->second.accountId == accountId
                    && itr->second.activeSeason == activeSeason
                    && itr->second.weekStart == weekStart
                    && itr->second.maxLevel == maxLevel
                    && itr->second.expiresAtMs > nowMs)
                {
                    return itr->second;
                }
            }

            payload = BuildProgressPayload(player, accountId, activeSeason,
                weekStart, weekEnd, maxLevel);

            std::lock_guard<std::mutex> lock(sWelcomeContentCacheLock);
            sCachedProgressPayloads[guid] = payload;
            return payload;
        }
    }

    // Module identifier - must match client-side
    constexpr const char* MODULE = "WELC";

    // Opcodes - must match client-side
    namespace Opcode
    {
        // Client -> Server
        constexpr uint8 CMSG_GET_SERVER_INFO     = 0x01;
        constexpr uint8 CMSG_GET_FAQ             = 0x02;
        constexpr uint8 CMSG_DISMISS_WELCOME     = 0x03;
        constexpr uint8 CMSG_MARK_FEATURE_SEEN   = 0x04;
        constexpr uint8 CMSG_GET_WHATS_NEW       = 0x05;
        constexpr uint8 CMSG_GET_PROGRESS        = 0x06;  // NEW: Request progress data

        // Server -> Client
        constexpr uint8 SMSG_SHOW_WELCOME        = 0x10;
        constexpr uint8 SMSG_SERVER_INFO         = 0x11;
        constexpr uint8 SMSG_FAQ_DATA            = 0x12;  // Dynamic FAQ from DB
        constexpr uint8 SMSG_FEATURE_UNLOCK      = 0x13;
        constexpr uint8 SMSG_WHATS_NEW           = 0x14;
        constexpr uint8 SMSG_LEVEL_MILESTONE     = 0x15;
        constexpr uint8 SMSG_PROGRESS_DATA       = 0x16;  // NEW: Progress data response
    }

    // Configuration keys
    namespace Config
    {
        // Welcome system
        constexpr const char* ENABLED = "DCWelcome.Enable";
        constexpr const char* SERVER_NAME = "DCWelcome.ServerName";
        constexpr const char* DISCORD_URL = "DCWelcome.DiscordUrl";
        constexpr const char* WEBSITE_URL = "DCWelcome.WebsiteUrl";
        constexpr const char* WIKI_URL = "DCWelcome.WikiUrl";

        // Progressive introduction
        constexpr const char* PROGRESSIVE_ENABLED = "DCWelcome.Progressive.Enabled";
        // Future: Load custom messages from config
        // constexpr const char* LEVEL_10_MESSAGE = "DCWelcome.Progressive.Level10.Message";
        // constexpr const char* LEVEL_20_MESSAGE = "DCWelcome.Progressive.Level20.Message";
        // constexpr const char* LEVEL_80_MESSAGE = "DCWelcome.Progressive.Level80.Message";
    }

    // Level milestones for progressive introduction
    // Matches DarkChaos-255 progression (max level 255)
    struct LevelMilestone
    {
        uint8 level;
        std::string feature;
        std::string message;
    };

    const std::vector<LevelMilestone> MILESTONES = {
        { 10,  "hotspots",        "Hotspots are now available! Use /hotspot to see active bonus zones." },
        { 20,  "prestige_preview","Prestige is planned for the future level-255 bracket, where capped characters can reset for permanent bonuses." },
        { 58,  "outland",         "Outland awaits! At 80, unlock Item Upgrades to enhance your gear." },
        { 80,  "endgame",         "Congratulations! You've reached the current live bracket cap and unlocked Mythic+ Dungeons plus the first major endgame systems!" },
        { 100, "tier_100",        "Level 100! New custom dungeons are now available: The Nexus & The Oculus!" },
        { 130, "tier_130",        "Level 130! Gundrak and Ahn'kahet dungeons are now accessible!" },
        { 160, "tier_160",        "Level 160! Auchindoun dungeons unlocked: Crypts, Mana Tombs, Sethekk, Shadow Lab!" },
        { 200, "tier_200",        "Level 200! You've entered the endgame tier. Elite challenges await!" },
        { 255, "max_level",       "MAXIMUM LEVEL! You've reached the pinnacle of power on DarkChaos-255!" },
    };

    // =======================================================================
    // Handler Functions
    // =======================================================================

    void SendServerInfo(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        // Get current season info using unified helper
        uint32 seasonId = DarkChaos::GetActiveSeasonId();
        std::string seasonName = DarkChaos::GetActiveSeasonName();

        // Build JSON message
        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_SERVER_INFO);
        msg.Set("serverName", sConfigMgr->GetOption<std::string>(Config::SERVER_NAME, "DarkChaos-255"));
        msg.Set("maxLevel", sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL));
        msg.Set("discordUrl", sConfigMgr->GetOption<std::string>(Config::DISCORD_URL, "https://discord.gg/pNddMEMbb2"));
        msg.Set("websiteUrl", sConfigMgr->GetOption<std::string>(Config::WEBSITE_URL, "https://github.com/darkmord1991/DarkChaos-255"));
        msg.Set("wikiUrl", sConfigMgr->GetOption<std::string>(Config::WIKI_URL, "https://github.com/darkmord1991/DarkChaos-255/blob/master/README.md"));
        msg.Set("seasonId", seasonId);
        msg.Set("seasonName", seasonName);
        msg.Set("uptimeSeconds", uint32(GameTime::GetUptime().count()));
        msg.Set("playersOnline", sWorldSessionMgr->GetPlayerCount());

        msg.Send(player);
    }

    void SendShowWelcome(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        // Get season info using unified helper
        uint32 seasonId = DarkChaos::GetActiveSeasonId();
        std::string seasonName = DarkChaos::GetActiveSeasonName();

        // Build welcome message with embedded server info
        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_SHOW_WELCOME);
        msg.Set("serverName", sConfigMgr->GetOption<std::string>(Config::SERVER_NAME, "DarkChaos-255"));
        msg.Set("maxLevel", sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL));
        msg.Set("discordUrl", sConfigMgr->GetOption<std::string>(Config::DISCORD_URL, "https://discord.gg/pNddMEMbb2"));
        msg.Set("websiteUrl", sConfigMgr->GetOption<std::string>(Config::WEBSITE_URL, "https://github.com/darkmord1991/DarkChaos-255"));
        msg.Set("wikiUrl", sConfigMgr->GetOption<std::string>(Config::WIKI_URL, "https://github.com/darkmord1991/DarkChaos-255/blob/master/README.md"));
        msg.Set("seasonId", seasonId);
        msg.Set("seasonName", seasonName);
        msg.Set("uptimeSeconds", uint32(GameTime::GetUptime().count()));
        msg.Set("playersOnline", sWorldSessionMgr->GetPlayerCount());
        msg.Set("isFirstLogin", true);

        msg.Send(player);
    }

    void SendLevelMilestone(Player* player, uint8 level)
    {
        if (!player || !player->GetSession())
            return;

        for (auto const& milestone : MILESTONES)
        {
            if (milestone.level == level)
            {
                DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_LEVEL_MILESTONE);
                msg.Set("level", milestone.level);
                msg.Set("feature", milestone.feature);
                msg.Set("message", milestone.message);

                msg.Send(player);
                break;
            }
        }
    }

    void SendFeatureUnlock(Player* player, const std::string& feature, const std::string& message)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_FEATURE_UNLOCK);
        msg.Set("feature", feature);
        msg.Set("message", message);

        msg.Send(player);
    }

    // =======================================================================
    // Message Handlers
    // =======================================================================

    void HandleGetServerInfo(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendServerInfo(player);
    }

    void HandleGetFAQ(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player || !player->GetSession())
            return;

        // Parse optional category filter from request
        std::string categoryFilter = "";
        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.IsNull() && json.HasKey("category"))
        {
            categoryFilter = json["category"].AsString();
        }

        DCAddon::JsonMessage response(MODULE, Opcode::SMSG_FAQ_DATA);

        CachedFaqPayload payload = GetCachedFaqPayload(categoryFilter);
        response.Set("entries", payload.entries);
        response.Set("count", static_cast<int32>(payload.count));

        response.Send(player);
    }

    void HandleDismissWelcome(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player)
            return;

        // Record that player dismissed the welcome screen
        CharacterDatabase.Execute(
            "INSERT INTO dc_player_welcome (guid, account_id, dismissed_at, show_on_login) "
            "VALUES ({}, {}, NOW(), 0) "
            "ON DUPLICATE KEY UPDATE dismissed_at = NOW(), show_on_login = 0",
            player->GetGUID().GetCounter(),
            player->GetSession()->GetAccountId()
        );
    }

    void HandleMarkFeatureSeen(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (json.IsNull())
            return;

        std::string feature = json["feature"].AsString();
        if (feature.empty())
            return;

        // Record that player has seen this feature intro
        CharacterDatabase.Execute(
            "INSERT INTO dc_player_seen_features (guid, feature, seen_at, dismissed) "
            "VALUES ({}, '{}', NOW(), 1) "
            "ON DUPLICATE KEY UPDATE seen_at = NOW(), dismissed = 1",
            player->GetGUID().GetCounter(),
            feature
        );
    }

    void HandleGetWhatsNew(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonMessage response(MODULE, Opcode::SMSG_WHATS_NEW);

        CachedWhatsNewPayload payload = GetCachedWhatsNewPayload();
        response.Set("version", payload.version);
        response.Set("entries", payload.entries);
        response.Set("count", static_cast<int32>(payload.count));

        if (payload.count == 0)
            response.Set("content", "Welcome to DarkChaos-255! Features include Mythic+, Prestige, Hotspots, and more.");

        response.Send(player);
    }

    // =======================================================================
    // Progress Data Handler - NEW
    // =======================================================================

    void HandleGetProgress(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = player->GetSession()->GetAccountId();
        uint32 activeSeason = DarkChaos::GetActiveSeasonId();
        uint32 weekStart = DarkChaos::Seasons::GetVaultWeekStartTimestamp();
        uint32 weekEnd = weekStart + 7u * 24u * 60u * 60u;
        uint32 maxLevel = sConfigMgr->GetOption<uint32>(
            "Prestige.AltBonus.MaxLevel", 255);
        CachedProgressPayload payload = GetCachedProgressPayload(player,
            accountId, activeSeason, weekStart, weekEnd, maxLevel);

        DCAddon::JsonMessage response(MODULE, Opcode::SMSG_PROGRESS_DATA);
        response.SetPreEncodedJson(payload.data);
        response.Send(player);
    }

    // =======================================================================
    // Deprecated Handler - NPC Info (moved to QOS module)
    // =======================================================================

    void HandleGetNPCInfoDeprecated(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player || !player->GetSession())
            return;

        // Send error response directing clients to QOS module
        // NOTE: NPC info handling has been consolidated to DC-QoS addon
        // Use DC-QoS's CMSG_GET_NPC_INFO (0x04) and SMSG_NPC_INFO (0x13) instead
        DCAddon::JsonMessage(MODULE, DCAddon::Opcode::Welcome::SMSG_NPC_INFO)
            .Set("deprecated", true)
            .Set("error", "NPC info functionality moved to QOS module")
            .Set("message", "Please update your addon to use QOS module opcode 0x04 (CMSG_GET_NPC_INFO) instead")
            .Set("redirectModule", "QOS")
            .Set("redirectOpcode", 0x04)
            .Send(player);
    }

    void RegisterHandlers()
    {
        using namespace DCAddon;

        MessageRouter::Instance().RegisterHandler(MODULE, Opcode::CMSG_GET_SERVER_INFO, HandleGetServerInfo);
        MessageRouter::Instance().RegisterHandler(MODULE, Opcode::CMSG_GET_FAQ, HandleGetFAQ);
        MessageRouter::Instance().RegisterHandler(MODULE, Opcode::CMSG_DISMISS_WELCOME, HandleDismissWelcome);
        MessageRouter::Instance().RegisterHandler(MODULE, Opcode::CMSG_MARK_FEATURE_SEEN, HandleMarkFeatureSeen);
        MessageRouter::Instance().RegisterHandler(MODULE, Opcode::CMSG_GET_WHATS_NEW, HandleGetWhatsNew);
        MessageRouter::Instance().RegisterHandler(MODULE, Opcode::CMSG_GET_PROGRESS, HandleGetProgress);
        MessageRouter::Instance().RegisterHandler(MODULE, DCAddon::Opcode::Welcome::CMSG_GET_NPC_INFO, HandleGetNPCInfoDeprecated);  // Deprecated - redirects to QOS

        MessageRouter::Instance().SetModuleEnabled(MODULE, true);
    }

} // namespace DCWelcome

// ===========================================================================
// Player Scripts for First Login and Level Up
// ===========================================================================

class DCWelcome_PlayerScript : public PlayerScript
{
public:
    DCWelcome_PlayerScript() : PlayerScript("DCWelcome_PlayerScript") { }

    // Called when player logs in
    void OnPlayerLogin(Player* player) override
    {
        if (!player || !sConfigMgr->GetOption<bool>(DCWelcome::Config::ENABLED, true))
            return;

        // Check if this is a first login (new character - total played time is 0)
        if (player->GetTotalPlayedTime() == 0)
        {
            // This is effectively a first login - show welcome popup
            DCWelcome::SendShowWelcome(player);
            return;
        }

        // Always send server info on login (for version updates, season changes, etc.)
        DCWelcome::SendServerInfo(player);
    }

    // Called when player levels up
    void OnPlayerLevelChanged(Player* player, uint8 oldLevel) override
    {
        if (!player || !sConfigMgr->GetOption<bool>(DCWelcome::Config::PROGRESSIVE_ENABLED, true))
            return;

        uint8 newLevel = player->GetLevel();

        // Check for milestone levels
        for (auto const& milestone : DCWelcome::MILESTONES)
        {
            if (newLevel == milestone.level && oldLevel < milestone.level)
            {
                DCWelcome::SendLevelMilestone(player, newLevel);
                break;
            }
        }
    }
};

// ===========================================================================
// Script Loader
// ===========================================================================

void AddSC_dc_addon_welcome()
{
    // Register message handlers
    DCWelcome::RegisterHandlers();

    // Register player script
    new DCWelcome_PlayerScript();
}
