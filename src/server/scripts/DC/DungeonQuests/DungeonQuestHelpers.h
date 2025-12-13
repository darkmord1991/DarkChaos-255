/*
 * DarkChaos-255 Dungeon Quest System - Shared Helper Functions
 * Version: 4.0
 *
 * This file consolidates common helper functions used across multiple
 * dungeon quest scripts to eliminate code duplication.
 *
 * Functions consolidated from:
 * - npc_dungeon_quest_master.cpp
 * - npc_dungeon_quest_daily_weekly.cpp
 * - DungeonQuestSystem.cpp
 */

#ifndef DUNGEON_QUEST_HELPERS_H
#define DUNGEON_QUEST_HELPERS_H

#include "ScriptMgr.h"
#include "Player.h"
#include "DatabaseEnv.h"
#include "QueryResult.h"
#include "DungeonQuestConstants.h"
#include "Log.h"
#include <unordered_set>
#include <unordered_map>
#include <chrono>

namespace DungeonQuestHelpers {

using namespace DungeonQuest;

// =====================================================================
// STATISTICS CACHING SYSTEM (30-second TTL)
// =====================================================================

struct PlayerStatsCache
{
    uint32 totalQuests;
    uint32 dailyQuests;
    uint32 weeklyQuests;
    uint32 dungeonQuests;
    uint32 heroicQuests;
    uint32 mythicQuests;
    uint32 mythicPlusQuests;
    std::chrono::steady_clock::time_point timestamp;
};

// Global cache map (GUID -> cached stats)
static std::unordered_map<uint64, PlayerStatsCache> g_PlayerStatsCache;
constexpr uint32 CACHE_TTL_SECONDS = 30;

/**
 * Get cached statistics or fetch from database if expired
 * PERFORMANCE: Reduces database queries from 7 per gossip to 1 per 30 seconds
 */
inline PlayerStatsCache GetCachedPlayerStats(Player* player)
{
    if (!player)
        return PlayerStatsCache{};

    uint64 guid = player->GetGUID().GetCounter();
    auto now = std::chrono::steady_clock::now();

    // Check if cache exists and is still valid
    auto it = g_PlayerStatsCache.find(guid);
    if (it != g_PlayerStatsCache.end())
    {
        auto age = std::chrono::duration_cast<std::chrono::seconds>(now - it->second.timestamp).count();
        if (age < CACHE_TTL_SECONDS)
        {
            LOG_DEBUG("scripts.dungeonquest", "Using cached stats for GUID {} (age: {}s)", guid, age);
            return it->second;
        }
    }

    // Cache miss or expired - fetch from database
    LOG_DEBUG("scripts.dungeonquest", "Fetching fresh stats for GUID {}", guid);
    
    PlayerStatsCache cache{};
    cache.timestamp = now;

    // Single aggregated query against the actual key/value stats table.
    // This avoids schema drift (dc_character_statistics does not exist in this project snapshot).
    QueryResult result = CharacterDatabase.Query(
        "SELECT "
        "MAX(CASE WHEN stat_name='total_quests_completed' THEN stat_value ELSE 0 END) AS total_quests, "
        "MAX(CASE WHEN stat_name='daily_quests_completed' THEN stat_value ELSE 0 END) AS daily_quests, "
        "MAX(CASE WHEN stat_name='weekly_quests_completed' THEN stat_value ELSE 0 END) AS weekly_quests, "
        "MAX(CASE WHEN stat_name='dungeon_quests_completed' THEN stat_value ELSE 0 END) AS dungeon_quests, "
        "MAX(CASE WHEN stat_name='heroic_quests_completed' THEN stat_value ELSE 0 END) AS heroic_quests, "
        "MAX(CASE WHEN stat_name='mythic_quests_completed' THEN stat_value ELSE 0 END) AS mythic_quests, "
        "MAX(CASE WHEN stat_name='mythic_plus_quests_completed' THEN stat_value ELSE 0 END) AS mythic_plus_quests "
        "FROM dc_character_dungeon_statistics WHERE guid = {}",
        guid
    );

    if (result)
    {
        Field* fields = result->Fetch();
        cache.totalQuests = fields[0].Get<uint32>();
        cache.dailyQuests = fields[1].Get<uint32>();
        cache.weeklyQuests = fields[2].Get<uint32>();
        cache.dungeonQuests = fields[3].Get<uint32>();
        cache.heroicQuests = fields[4].Get<uint32>();
        cache.mythicQuests = fields[5].Get<uint32>();
        cache.mythicPlusQuests = fields[6].Get<uint32>();

        // If total is not explicitly tracked, derive it.
        if (cache.totalQuests == 0)
            cache.totalQuests = cache.dailyQuests + cache.weeklyQuests + cache.dungeonQuests;
    }

    // Update cache
    g_PlayerStatsCache[guid] = cache;
    
    return cache;
}

/**
 * Invalidate cache for a player (call after quest completion)
 */
inline void InvalidatePlayerStatsCache(Player* player)
{
    if (!player)
        return;
        
    uint64 guid = player->GetGUID().GetCounter();
    g_PlayerStatsCache.erase(guid);
    
    LOG_DEBUG("scripts.dungeonquest", "Invalidated stats cache for GUID {}", guid);
}

// =====================================================================
// STATISTICS QUERY FUNCTIONS (now use cache)
// =====================================================================

/**
 * Get total number of quests completed by player
 * Uses cache to minimize database queries
 */
inline uint32 GetTotalQuestCompletions(Player* player)
{
    return GetCachedPlayerStats(player).totalQuests;
}

/**
 * Get number of daily quests completed by player
 * Uses cache to minimize database queries
 */
inline uint32 GetDailyQuestCompletions(Player* player)
{
    return GetCachedPlayerStats(player).dailyQuests;
}

/**
 * Get number of weekly quests completed by player
 * Uses cache to minimize database queries
 */
inline uint32 GetWeeklyQuestCompletions(Player* player)
{
    return GetCachedPlayerStats(player).weeklyQuests;
}

/**
 * Get number of dungeon quests completed by player
 * Uses cache to minimize database queries
 */
inline uint32 GetDungeonQuestCompletions(Player* player)
{
    return GetCachedPlayerStats(player).dungeonQuests;
}

/**
 * Get specific statistic value by field name
 * SECURITY: Uses whitelist validation to prevent SQL injection
 */
inline uint32 GetStatisticValue(Player* player, const std::string& statName)
{
    if (!player || statName.empty())
        return 0;

    // Whitelist of valid column names (prevents SQL injection)
    static const std::unordered_set<std::string> validStats = {
        "total_quests_completed",
        "daily_quests_completed",
        "weekly_quests_completed",
        "dungeon_quests_completed",
        "heroic_quests_completed",
        "mythic_quests_completed",
        "mythic_plus_quests_completed"
    };

    // Validate column name against whitelist
    if (validStats.find(statName) == validStats.end())
    {
        LOG_ERROR("scripts.dungeonquest", 
            "GetStatisticValue: Invalid stat name '{}' requested by player {}", 
            statName, player->GetGUID().ToString());
        return 0;
    }

    // Safe: statName validated against whitelist, GUID is numeric
    QueryResult result = CharacterDatabase.Query(
        "SELECT stat_value FROM dc_character_dungeon_statistics WHERE guid = {} AND stat_name = '{}'",
        player->GetGUID().GetCounter(), statName
    );

    return result ? (*result)[0].Get<uint32>() : 0;
}

/**
 * Get number of Heroic quests completed by player (v4.0)
 * Uses cache to minimize database queries
 */
inline uint32 GetHeroicQuestCompletions(Player* player)
{
    return GetCachedPlayerStats(player).heroicQuests;
}

/**
 * Get number of Mythic quests completed by player (v4.0)
 * Uses cache to minimize database queries
 */
inline uint32 GetMythicQuestCompletions(Player* player)
{
    return GetCachedPlayerStats(player).mythicQuests;
}

/**
 * Get number of Mythic+ quests completed by player (v4.0)
 * Uses cache to minimize database queries
 */
inline uint32 GetMythicPlusQuestCompletions(Player* player)
{
    return GetCachedPlayerStats(player).mythicPlusQuests;
}

// =====================================================================
// DATABASE QUERY FUNCTIONS
// =====================================================================

/**
 * Get dungeon ID from quest ID (v4.0 - database-driven)
 * Queries: dc_quest_difficulty_mapping.dungeon_id
 */
inline uint32 GetDungeonIdFromQuest(uint32 questId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT dungeon_id FROM dc_quest_difficulty_mapping WHERE quest_id = {}",
        questId
    );

    return result ? (*result)[0].Get<uint32>() : 0;
}

/**
 * Get quest master NPC entry for a given map ID (v4.0 - database-driven)
 * Queries: dc_dungeon_npc_mapping.quest_master_entry
 * Falls back to default if not found
 */
inline uint32 GetQuestMasterForMap(uint32 mapId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT quest_master_entry FROM dc_dungeon_npc_mapping WHERE map_id = {}",
        mapId
    );

    return result ? (*result)[0].Get<uint32>() : NPC_DEFAULT_QUEST_MASTER;
}

/**
 * Get quest difficulty tier (v4.0)
 * Queries: dc_quest_difficulty_mapping.difficulty
 */
inline QuestDifficulty GetQuestDifficulty(uint32 questId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT difficulty FROM dc_quest_difficulty_mapping WHERE quest_id = {}",
        questId
    );

    if (result)
    {
        uint8 difficulty = (*result)[0].Get<uint8>();
        return static_cast<QuestDifficulty>(difficulty);
    }

    return DIFFICULTY_NORMAL; // Default to normal if not found
}

/**
 * Get difficulty token multiplier (v4.0)
 * Queries: dc_difficulty_config.token_multiplier
 */
inline float GetDifficultyTokenMultiplier(QuestDifficulty difficulty)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT token_multiplier FROM dc_difficulty_config WHERE difficulty_id = {}",
        static_cast<uint8>(difficulty)
    );

    return result ? (*result)[0].Get<float>() : 1.0f;
}

/**
 * Get difficulty gold multiplier (v4.0)
 * Queries: dc_difficulty_config.gold_multiplier
 */
inline float GetDifficultyGoldMultiplier(QuestDifficulty difficulty)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT gold_multiplier FROM dc_difficulty_config WHERE difficulty_id = {}",
        static_cast<uint8>(difficulty)
    );

    return result ? (*result)[0].Get<float>() : 1.0f;
}

/**
 * Get number of times a dungeon has been completed on a specific difficulty
 * Queries: dc_character_difficulty_completions.completion_count
 */
inline uint32 GetDifficultyCompletionCount(Player* player, uint32 dungeonId, QuestDifficulty difficulty)
{
    if (!player)
        return 0;

    QueryResult result = CharacterDatabase.Query(
        "SELECT completion_count FROM dc_character_difficulty_completions "
        "WHERE char_guid = {} AND dungeon_id = {} AND difficulty = {}",
        player->GetGUID().GetCounter(),
        dungeonId,
        static_cast<uint8>(difficulty)
    );

    return result ? (*result)[0].Get<uint32>() : 0;
}

// =====================================================================
// UTILITY FUNCTIONS
// =====================================================================

/**
 * Format quest statistics for display in gossip menu
 * OPTIMIZED: Uses cached stats (1 query per 30 seconds instead of 7 per gossip)
 */
inline std::string FormatQuestStatistics(Player* player)
{
    if (!player)
        return "Error: Invalid player";

    // Get cached stats (will auto-fetch if expired)
    PlayerStatsCache stats = GetCachedPlayerStats(player);

    std::ostringstream output;
    output << "Your Dungeon Quest Statistics:\n\n";
    output << "Total Quests: " << stats.totalQuests << "\n";
    output << "Daily Quests: " << stats.dailyQuests << "\n";
    output << "Weekly Quests: " << stats.weeklyQuests << "\n";
    output << "Dungeon Quests: " << stats.dungeonQuests << "\n\n";
    
    // v4.0: Difficulty breakdown
    output << "Difficulty Breakdown:\n";
    output << "- Heroic: " << stats.heroicQuests << "\n";
    output << "- Mythic: " << stats.mythicQuests << "\n";
    output << "- Mythic+: " << stats.mythicPlusQuests << "\n";
    
    return output.str();
}

/**
 * Format rewards information for display in gossip menu
 */
inline std::string FormatRewardsInfo()
{
    std::ostringstream info;
    info << "Dungeon Quest Rewards:\n\n";
    info << "Daily Quests:\n";
    info << "- Dungeon Explorer Tokens\n";
    info << "- Experience & Gold\n";
    info << "- Daily Quest achievements\n\n";
    info << "Weekly Quests:\n";
    info << "- Expansion Specialist Tokens\n";
    info << "- Bonus Experience & Gold\n";
    info << "- Weekly Quest achievements\n\n";
    info << "Dungeon Quests:\n";
    info << "- Various Token Types\n";
    info << "- Experience & Gold\n";
    info << "- Dungeon completion achievements\n\n";
    info << "Difficulty Bonuses (v4.0):\n";
    info << "- Heroic: +50% token rewards\n";
    info << "- Mythic: +100% token rewards\n";
    info << "- Mythic+: +200% token rewards\n";
    
    return info.str();
}

/**
 * Check if player can accept a quest based on difficulty unlock requirements
 * Returns true if player has met the requirements for the quest's difficulty
 */
inline bool CanAcceptDifficultyQuest(Player* player, uint32 questId)
{
    if (!player)
        return false;

    QuestDifficulty difficulty = GetQuestDifficulty(questId);
    
    // Normal difficulty always available
    if (difficulty == DIFFICULTY_NORMAL)
        return true;

    uint32 dungeonId = GetDungeonIdFromQuest(questId);
    if (dungeonId == 0)
        return true; // Not a dungeon-specific quest, allow

    // Check if player has completed enough of the lower difficulty
    QuestDifficulty lowerDifficulty = static_cast<QuestDifficulty>(static_cast<uint8>(difficulty) - 1);
    uint32 lowerCompletions = GetDifficultyCompletionCount(player, dungeonId, lowerDifficulty);

    // Unlock requirements:
    // Heroic: 5 Normal completions
    // Mythic: 10 Heroic completions
    // Mythic+: 20 Mythic completions
    switch (difficulty)
    {
        case DIFFICULTY_HEROIC:
            return lowerCompletions >= 5;
        case DIFFICULTY_MYTHIC:
            return lowerCompletions >= 10;
        case DIFFICULTY_MYTHIC_PLUS:
            return lowerCompletions >= 20;
        default:
            return true;
    }
}

/**
 * Get next achievement milestone for player
 * Returns achievement ID and description, or 0 if all milestones achieved
 */
inline std::pair<uint32, std::string> GetNextMilestone(Player* player)
{
    uint32 totalQuests = GetTotalQuestCompletions(player);
    
    if (totalQuests < 1)
        return {13500, "Complete 1 quest for Dungeon Novice"};
    else if (totalQuests < 10)
        return {13501, "Complete " + std::to_string(10 - totalQuests) + " more for Daily Dedication"};
    else if (totalQuests < 25)
        return {13502, "Complete " + std::to_string(25 - totalQuests) + " more for Daily Devotion"};
    else if (totalQuests < 50)
        return {13503, "Complete " + std::to_string(50 - totalQuests) + " more for Daily Champion"};
    else if (totalQuests < 100)
        return {13504, "Complete " + std::to_string(100 - totalQuests) + " more for Daily Legend"};
    else
        return {0, "All major milestones achieved!"};
}

/**
 * Send colored difficulty message to player
 */
inline void SendDifficultyMessage(Player* player, QuestDifficulty difficulty, const std::string& message)
{
    if (!player)
        return;

    std::string coloredMessage = std::string(GetDifficultyColor(difficulty)) + message + "|r";
    ChatHandler(player->GetSession()).SendSysMessage(coloredMessage.c_str());
}

} // namespace DungeonQuestHelpers

#endif // DUNGEON_QUEST_HELPERS_H

/*
 * USAGE EXAMPLE:
 * 
 * #include "DungeonQuestHelpers.h"
 * using namespace DungeonQuestHelpers;
 * 
 * // Get player statistics
 * uint32 totalQuests = GetTotalQuestCompletions(player);
 * uint32 heroicQuests = GetHeroicQuestCompletions(player);
 * 
 * // Check difficulty unlock
 * if (!CanAcceptDifficultyQuest(player, questId)) {
 *     ChatHandler(player->GetSession()).SendSysMessage(
 *         "You must complete more quests on lower difficulty first!"
 *     );
 *     return;
 * }
 * 
 * // Display statistics in gossip
 * std::string stats = FormatQuestStatistics(player);
 * AddGossipItemFor(player, GOSSIP_ICON_CHAT, stats, ...);
 * 
 * // Send colored message
 * SendDifficultyMessage(player, DIFFICULTY_MYTHIC, "Quest completed!");
 */
