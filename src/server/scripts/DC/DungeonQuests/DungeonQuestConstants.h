/*
 * DarkChaos-255 Dungeon Quest System - Shared Constants
 * Version: 4.0
 *
 * This header file consolidates all constants used across the dungeon quest system.
 * Include this file in all DungeonQuest C++ files to ensure consistency.
 *
 * Purpose: Eliminate duplicate constant definitions across 6 different files
 */

#ifndef DUNGEON_QUEST_CONSTANTS_H
#define DUNGEON_QUEST_CONSTANTS_H

#include "Common.h"

namespace DungeonQuest {

// =====================================================================
// QUEST ID RANGES
// =====================================================================

// Daily Quests (50 quests)
constexpr uint32 QUEST_DAILY_MIN    = 700101;
constexpr uint32 QUEST_DAILY_MAX    = 700150;  // v4.0: Updated from 700104

// Weekly Quests (24 quests)
constexpr uint32 QUEST_WEEKLY_MIN   = 700201;
constexpr uint32 QUEST_WEEKLY_MAX   = 700224;  // v4.0: Updated from 700204

// Dungeon Quests (337 quests active, up to 8299 possible)
constexpr uint32 QUEST_DUNGEON_MIN  = 700701;
constexpr uint32 QUEST_DUNGEON_MAX  = 708999;  // v4.0: Updated from 700999

// Total Quest Range
constexpr uint32 QUEST_SYSTEM_MIN   = 700101;
constexpr uint32 QUEST_SYSTEM_MAX   = 708999;

// =====================================================================
// NPC ENTRY RANGES
// =====================================================================

// Dungeon Quest Master NPCs (53 NPCs, one per dungeon)
constexpr uint32 NPC_QUEST_MASTER_MIN     = 700000;
constexpr uint32 NPC_QUEST_MASTER_MAX     = 700052;
constexpr uint32 NPC_DEFAULT_QUEST_MASTER = 700000;  // Ragefire Chasm default

// Phase visibility for quest masters
constexpr uint32 PHASE_BASE_DUNGEON_QUEST = 10000;   // Base phase mask

// =====================================================================
// ACHIEVEMENT ID RANGES
// =====================================================================

// v4.0 Dungeon Quest Achievements (98 achievements)
constexpr uint32 ACHIEVEMENT_DUNGEON_MIN = 10800;
constexpr uint32 ACHIEVEMENT_DUNGEON_MAX = 10999;

// Achievement Category
constexpr uint32 ACHIEVEMENT_CATEGORY_DUNGEON_QUEST = 10010;  // "Dungeon Quest System"
constexpr uint32 ACHIEVEMENT_CATEGORY_DARK_CHAOS    = 10000;  // Parent category

// Legacy Achievement IDs (pre-v4.0, may be deprecated)
constexpr uint32 ACHIEVEMENT_DUNGEON_NOVICE     = 13500;  // First quest
constexpr uint32 ACHIEVEMENT_DAILY_DEDICATION   = 13501;  // 10 daily quests
constexpr uint32 ACHIEVEMENT_DAILY_DEVOTION     = 13502;  // 25 daily quests
constexpr uint32 ACHIEVEMENT_DAILY_CHAMPION     = 13503;  // 50 daily quests
constexpr uint32 ACHIEVEMENT_DAILY_LEGEND       = 13504;  // 100 daily quests
constexpr uint32 ACHIEVEMENT_WEEKLY_DEDICATION  = 13505;  // 10 weekly quests
constexpr uint32 ACHIEVEMENT_WEEKLY_DEVOTION    = 13506;  // 25 weekly quests
// Additional dungeon progression achievements
constexpr uint32 ACHIEVEMENT_DUNGEON_EXPLORER   = 13510;  // 10 dungeon quests completed
constexpr uint32 ACHIEVEMENT_LEGENDARY_DUNGEON  = 13511;  // 50 dungeon quests completed

// =====================================================================
// TOKEN ITEM IDS
// =====================================================================

// Token Types (5 different tokens)
constexpr uint32 ITEM_DUNGEON_EXPLORER_TOKEN      = 700001;  // Daily quest reward
constexpr uint32 ITEM_EXPANSION_SPECIALIST_TOKEN  = 700002;  // Weekly quest reward
constexpr uint32 ITEM_LEGENDARY_DUNGEON_TOKEN     = 700003;  // Rare drop
constexpr uint32 ITEM_CHALLENGE_MASTER_TOKEN      = 700004;  // Challenge mode
constexpr uint32 ITEM_SPEED_RUNNER_TOKEN          = 700005;  // Speed runs

// =====================================================================
// DIFFICULTY SYSTEM (v4.0)
// =====================================================================

// Difficulty Tiers
enum QuestDifficulty : uint8
{
    DIFFICULTY_NORMAL       = 0,  // 1.0x multiplier (default)
    DIFFICULTY_HEROIC       = 1,  // 1.5x multiplier
    DIFFICULTY_MYTHIC       = 2,  // 2.0x multiplier
    DIFFICULTY_MYTHIC_PLUS  = 3   // 3.0x multiplier
};

// Default Multipliers (queried from dc_difficulty_config in practice)
constexpr float MULTIPLIER_NORMAL      = 1.0f;
constexpr float MULTIPLIER_HEROIC      = 1.5f;
constexpr float MULTIPLIER_MYTHIC      = 2.0f;
constexpr float MULTIPLIER_MYTHIC_PLUS = 3.0f;

// =====================================================================
// DATABASE TABLE NAMES
// =====================================================================

// World Database Tables
constexpr const char* TABLE_DIFFICULTY_CONFIG           = "dc_difficulty_config";
constexpr const char* TABLE_QUEST_DIFFICULTY_MAPPING    = "dc_quest_difficulty_mapping";
constexpr const char* TABLE_DUNGEON_QUEST_MAPPING       = "dc_dungeon_quest_mapping";
constexpr const char* TABLE_DAILY_QUEST_TOKEN_REWARDS   = "dc_daily_quest_token_rewards";
constexpr const char* TABLE_WEEKLY_QUEST_TOKEN_REWARDS  = "dc_weekly_quest_token_rewards";
constexpr const char* TABLE_QUEST_REWARD_TOKENS         = "dc_quest_reward_tokens";

// Character Database Tables
constexpr const char* TABLE_CHARACTER_STATISTICS            = "dc_character_statistics";
constexpr const char* TABLE_CHARACTER_DIFFICULTY_COMPLETIONS = "dc_character_difficulty_completions";
constexpr const char* TABLE_CHARACTER_DIFFICULTY_STREAKS    = "dc_character_difficulty_streaks";
constexpr const char* TABLE_CHARACTER_DUNGEON_PROGRESS      = "dc_character_dungeon_progress";

// =====================================================================
// CONFIGURATION KEYS
// =====================================================================

// Config.worldserver keys
constexpr const char* CONFIG_DUNGEON_QUEST_ENABLE       = "DungeonQuest.Enable";
constexpr const char* CONFIG_FOLLOWER_ENABLE            = "DungeonQuest.FollowerEnable";
constexpr const char* CONFIG_DEBUG_ENABLE               = "DungeonQuest.Debug.Enable";
constexpr const char* CONFIG_TOKEN_ITEM_ID              = "DungeonQuest.TokenItemId";

// =====================================================================
// GAMEPLAY CONSTANTS
// =====================================================================

// Follower System
constexpr float FOLLOWER_DISTANCE           = 2.0f;   // Yards behind player
constexpr float FOLLOWER_SPAWN_OFFSET       = 2.0f;   // Spawn offset distance
constexpr uint32 FOLLOWER_NPC_FLAGS         = 0x03;   // GOSSIP | QUESTGIVER

// Phase System
constexpr uint32 PHASE_ALL_VISIBLE          = 0xFFFFFFFF;  // Quest masters visible in all phases
constexpr uint32 PHASE_DEFAULT              = 1;           // Default phase when not in dungeon

// Quest Reset Timing
constexpr uint32 DAILY_RESET_HOURS         = 24;      // 24 hours
constexpr uint32 WEEKLY_RESET_HOURS        = 168;     // 7 days

// Gossip Menu Actions
constexpr uint32 GOSSIP_ACTION_SHOW_DAILY_QUESTS    = 1000;
constexpr uint32 GOSSIP_ACTION_SHOW_WEEKLY_QUESTS   = 1001;
constexpr uint32 GOSSIP_ACTION_SHOW_DUNGEON_QUESTS  = 1002;
constexpr uint32 GOSSIP_ACTION_SHOW_ALL_QUESTS      = 1003;
constexpr uint32 GOSSIP_ACTION_SHOW_REWARDS_INFO    = 1004;
constexpr uint32 GOSSIP_ACTION_SHOW_MY_STATS        = 1005;
constexpr uint32 GOSSIP_ACTION_BACK_TO_MAIN         = 1006;

// =====================================================================
// HELPER FUNCTIONS
// =====================================================================

// Quest Type Checking (inline for performance)
inline bool IsDailyQuest(uint32 questId)
{
    return questId >= QUEST_DAILY_MIN && questId <= QUEST_DAILY_MAX;
}

inline bool IsWeeklyQuest(uint32 questId)
{
    return questId >= QUEST_WEEKLY_MIN && questId <= QUEST_WEEKLY_MAX;
}

inline bool IsDungeonQuest(uint32 questId)
{
    return questId >= QUEST_DUNGEON_MIN && questId <= QUEST_DUNGEON_MAX;
}

inline bool IsSystemQuest(uint32 questId)
{
    return questId >= QUEST_SYSTEM_MIN && questId <= QUEST_SYSTEM_MAX;
}

inline bool IsQuestMasterNPC(uint32 npcEntry)
{
    return npcEntry >= NPC_QUEST_MASTER_MIN && npcEntry <= NPC_QUEST_MASTER_MAX;
}

inline bool IsDungeonAchievement(uint32 achievementId)
{
    return achievementId >= ACHIEVEMENT_DUNGEON_MIN && achievementId <= ACHIEVEMENT_DUNGEON_MAX;
}

// Quest Type Name (for logging/display)
inline const char* GetQuestTypeName(uint32 questId)
{
    if (IsDailyQuest(questId))
        return "Daily Quest";
    else if (IsWeeklyQuest(questId))
        return "Weekly Quest";
    else if (IsDungeonQuest(questId))
        return "Dungeon Quest";
    else
        return "Unknown Quest";
}

// Difficulty Name (for logging/display)
inline const char* GetDifficultyName(QuestDifficulty difficulty)
{
    switch (difficulty)
    {
        case DIFFICULTY_NORMAL:      return "Normal";
        case DIFFICULTY_HEROIC:      return "Heroic";
        case DIFFICULTY_MYTHIC:      return "Mythic";
        case DIFFICULTY_MYTHIC_PLUS: return "Mythic+";
        default:                     return "Unknown";
    }
}

// Get color code for difficulty (for chat messages)
inline const char* GetDifficultyColor(QuestDifficulty difficulty)
{
    switch (difficulty)
    {
        case DIFFICULTY_NORMAL:      return "|cFF00FF00"; // Green
        case DIFFICULTY_HEROIC:      return "|cFFFFD700"; // Gold
        case DIFFICULTY_MYTHIC:      return "|cFFFF4500"; // Orange-Red
        case DIFFICULTY_MYTHIC_PLUS: return "|cFFDC143C"; // Crimson
        default:                     return "|cFFFFFFFF"; // White
    }
}

} // namespace DungeonQuest

#endif // DUNGEON_QUEST_CONSTANTS_H

/*
 * USAGE EXAMPLE:
 * 
 * #include "DungeonQuestConstants.h"
 * using namespace DungeonQuest;
 * 
 * if (IsDailyQuest(questId)) {
 *     LOG_INFO("scripts", "Processing daily quest: {}", questId);
 *     player->AddItem(ITEM_DUNGEON_EXPLORER_TOKEN, 1);
 * }
 * 
 * QuestDifficulty diff = DIFFICULTY_HEROIC;
 * ChatHandler(player->GetSession()).PSendSysMessage(
 *     "%sCompleted %s quest!|r", 
 *     GetDifficultyColor(diff), 
 *     GetDifficultyName(diff)
 * );
 */
