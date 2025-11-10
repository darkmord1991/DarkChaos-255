/*
 * DarkChaos-WoW Dungeon Quest System
 * Copyright (C) 2025 DarkChaos-WoW
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "Config.h"
#include "Chat.h"
#include "ObjectMgr.h"
#include "DatabaseEnv.h"
#include "World.h"
#include "AchievementMgr.h"
#include "Log.h"
#include "DungeonQuestConstants.h"

using namespace DungeonQuest;

// Database helper functions
class DungeonQuestDB
{
public:
    // Get token rewards for a daily quest
    static uint32 GetDailyQuestTokenReward(uint32 questId)
    {
        QueryResult result = WorldDatabase.Query("SELECT token_amount FROM dc_daily_quest_token_rewards WHERE quest_id = {}", questId);
        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint32>();
        }
        return 0;
    }

    // Get token rewards for a weekly quest
    static uint32 GetWeeklyQuestTokenReward(uint32 questId)
    {
        QueryResult result = WorldDatabase.Query("SELECT token_amount FROM dc_weekly_quest_token_rewards WHERE quest_id = {}", questId);
        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint32>();
        }
        return 0;
    }

    // Get token item ID from config table
    static uint32 GetTokenItemId()
    {
        QueryResult result = WorldDatabase.Query("SELECT token_item_id FROM dc_quest_reward_tokens LIMIT 1");
        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint32>();
        }
        return 0; // No token configured
    }

    // v4.0: Get difficulty from quest ID
    static QuestDifficulty GetQuestDifficulty(uint32 questId)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT difficulty FROM dc_quest_difficulty_mapping WHERE quest_id = {}", questId
        );
        
        if (result)
        {
            Field* fields = result->Fetch();
            uint8 difficulty = fields[0].Get<uint8>();
            return static_cast<QuestDifficulty>(difficulty);
        }
        
        return DIFFICULTY_NORMAL;
    }
    
    // v4.0: Get difficulty configuration
    static float GetDifficultyTokenMultiplier(QuestDifficulty difficulty)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT token_multiplier FROM dc_difficulty_config WHERE difficulty_id = {}", 
            static_cast<uint32>(difficulty)
        );
        
        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<float>();
        }
        
        return 1.0f;
    }
    
    static float GetDifficultyGoldMultiplier(QuestDifficulty difficulty)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT gold_multiplier FROM dc_difficulty_config WHERE difficulty_id = {}", 
            static_cast<uint32>(difficulty)
        );
        
        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<float>();
        }
        
        return 1.0f;
    }
    
    // v4.0: Update difficulty-specific statistics
    static void UpdateDifficultyStatistics(Player* player, QuestDifficulty difficulty)
    {
        if (!player)
            return;
            
        std::string statName;
        switch (difficulty)
        {
            case DIFFICULTY_HEROIC:
                statName = "heroic_quests_completed";
                break;
            case DIFFICULTY_MYTHIC:
                statName = "mythic_quests_completed";
                break;
            case DIFFICULTY_MYTHIC_PLUS:
                statName = "mythic_plus_quests_completed";
                break;
            default:
                return; // Don't track Normal separately
        }
        
        UpdateStatistics(player, statName, 1);
        
        LOG_DEBUG("scripts", "DungeonQuest: Updated {} for player {}", 
                  statName, player->GetName());
    }
    
    // v4.0: Get dungeon ID from quest ID
    static uint32 GetDungeonIdFromQuest(uint32 questId)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT dungeon_id FROM dc_quest_difficulty_mapping WHERE quest_id = {}", questId
        );
        
        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint32>();
        }
        
        return 0;
    }
    
    // v4.0: Track difficulty completion
    static void TrackDifficultyCompletion(Player* player, uint32 dungeonId, QuestDifficulty difficulty)
    {
        if (!player || dungeonId == 0)
            return;
        
        std::string difficultyStr = "Normal";
        switch (difficulty)
        {
            case DIFFICULTY_HEROIC: difficultyStr = "Heroic"; break;
            case DIFFICULTY_MYTHIC: difficultyStr = "Mythic"; break;
            case DIFFICULTY_MYTHIC_PLUS: difficultyStr = "Mythic+"; break;
            default: break;
        }
        
        // Update completion tracking
        CharacterDatabase.Execute(
            "INSERT INTO dc_character_difficulty_completions "
            "(guid, dungeon_id, difficulty, total_completions, last_completion_date) "
            "VALUES ({}, {}, '{}', 1, NOW()) "
            "ON DUPLICATE KEY UPDATE "
            "total_completions = total_completions + 1, "
            "last_completion_date = NOW()",
            player->GetGUID().GetCounter(),
            dungeonId,
            difficultyStr
        );
    }

    // Update dungeon progress
    static void UpdateDungeonProgress(Player* player, uint32 dungeonId, uint32 questId)
    {
        if (!player)
            return;

        bool success = CharacterDatabase.Execute(
            "INSERT INTO dc_character_dungeon_progress (guid, dungeon_id, quest_id, completion_count, last_update) "
            "VALUES ({}, {}, {}, 1, NOW()) "
            "ON DUPLICATE KEY UPDATE completion_count = completion_count + 1, last_update = NOW()",
            player->GetGUID().GetCounter(), dungeonId, questId);
        
        if (!success)
        {
            LOG_ERROR("scripts.dungeonquest",
                "Failed to update dungeon progress for GUID {} (dungeon: {}, quest: {})",
                player->GetGUID().ToString(), dungeonId, questId);
        }
    }

    // Log quest completion
    static void LogQuestCompletion(Player* player, uint32 questId)
    {
        if (!player)
            return;

        bool success = CharacterDatabase.Execute(
            "INSERT INTO dc_character_dungeon_quests_completed (guid, quest_id, completion_time) "
            "VALUES ({}, {}, NOW())",
            player->GetGUID().GetCounter(), questId);
        
        if (!success)
        {
            LOG_ERROR("scripts.dungeonquest",
                "Failed to log quest completion for GUID {} (quest: {})",
                player->GetGUID().ToString(), questId);
        }
    }

    // Update statistics
    static void UpdateStatistics(Player* player, const std::string& stat_name, uint32 value)
    {
        if (!player)
            return;

        bool success = CharacterDatabase.Execute(
            "INSERT INTO dc_character_dungeon_statistics (guid, stat_name, stat_value, last_update) "
            "VALUES ({}, '{}', {}, NOW()) "
            "ON DUPLICATE KEY UPDATE stat_value = stat_value + {}, last_update = NOW()",
            player->GetGUID().GetCounter(), stat_name, value, value);
        
        if (!success)
        {
            LOG_ERROR("scripts.dungeonquest",
                "Failed to update statistics for GUID {} (stat: {}, value: {})",
                player->GetGUID().ToString(), stat_name, value);
        }
    }

    // Get statistic value
    static uint32 GetStatisticValue(Player* player, const std::string& stat_name)
    {
        if (!player)
            return 0;

        QueryResult result = CharacterDatabase.Query(
            "SELECT stat_value FROM dc_character_dungeon_statistics WHERE guid = {} AND stat_name = '{}'",
            player->GetGUID().GetCounter(), stat_name);

        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint32>();
        }
        return 0;
    }

    // Get total quest completion count
    static uint32 GetTotalQuestCompletions(Player* player)
    {
        if (!player)
            return 0;

        QueryResult result = CharacterDatabase.Query(
            "SELECT COUNT(*) FROM dc_character_dungeon_quests_completed WHERE guid = {}",
            player->GetGUID().GetCounter());

        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint32>();
        }
        return 0;
    }
};

// Main PlayerScript for dungeon quest system
class DungeonQuestPlayerScript : public PlayerScript
{
public:
    DungeonQuestPlayerScript() : PlayerScript("DungeonQuestPlayerScript")
    {
    }

    // Called BEFORE quest completion (can block completion)
    bool OnPlayerBeforeQuestComplete(Player* player, uint32 questId) override
    {
        // Validate quest ID is in our range
        bool isDungeonQuest = (questId >= QUEST_DAILY_MIN && questId <= QUEST_DAILY_MAX) ||
                              (questId >= QUEST_WEEKLY_MIN && questId <= QUEST_WEEKLY_MAX) ||
                              (questId >= QUEST_DUNGEON_MIN && questId <= QUEST_DUNGEON_MAX);

        if (!isDungeonQuest)
            return true;

        // Additional validation can go here
        LOG_INFO("scripts", "DungeonQuest: Player {} is about to complete quest {}", 
                 player->GetName(), questId);

        return true; // Allow completion
    }

    // Called AFTER quest completion
    void OnPlayerCompleteQuest(Player* player, Quest const* quest) override
    {
        if (!player || !quest)
            return;

        uint32 questId = quest->GetQuestId();

        // Check if this is a dungeon quest
        bool isDailyQuest = (questId >= QUEST_DAILY_MIN && questId <= QUEST_DAILY_MAX);
        bool isWeeklyQuest = (questId >= QUEST_WEEKLY_MIN && questId <= QUEST_WEEKLY_MAX);
        bool isDungeonQuest = (questId >= QUEST_DUNGEON_MIN && questId <= QUEST_DUNGEON_MAX);

        if (!isDailyQuest && !isWeeklyQuest && !isDungeonQuest)
            return;

        LOG_INFO("scripts", "DungeonQuest: Player {} completed dungeon quest {}", 
                 player->GetName(), questId);

        // Log the completion
        DungeonQuestDB::LogQuestCompletion(player, questId);

        // Handle token rewards
        HandleTokenRewards(player, questId, isDailyQuest, isWeeklyQuest);

        // Update statistics
        UpdateQuestStatistics(player, isDailyQuest, isWeeklyQuest, isDungeonQuest, questId);

        // Check for achievement completion
        CheckAchievements(player, questId, isDailyQuest, isWeeklyQuest, isDungeonQuest);
    }

private:
    // Handle token reward distribution
    void HandleTokenRewards(Player* player, uint32 questId, bool isDailyQuest, bool isWeeklyQuest)
    {
        uint32 tokenAmount = 0;
        uint32 tokenItemId = DungeonQuestDB::GetTokenItemId();

        if (tokenItemId == 0)
        {
            LOG_DEBUG("scripts", "DungeonQuest: No token item configured, skipping token rewards");
            return;
        }

        // Get base token amount from database
        if (isDailyQuest)
        {
            tokenAmount = DungeonQuestDB::GetDailyQuestTokenReward(questId);
        }
        else if (isWeeklyQuest)
        {
            tokenAmount = DungeonQuestDB::GetWeeklyQuestTokenReward(questId);
        }

        if (tokenAmount == 0)
        {
            LOG_DEBUG("scripts", "DungeonQuest: No token reward configured for quest {}", questId);
            return;
        }

        // v4.0: Get difficulty and apply multiplier
        QuestDifficulty difficulty = DungeonQuestDB::GetQuestDifficulty(questId);
        float multiplier = DungeonQuestDB::GetDifficultyTokenMultiplier(difficulty);
        
        // Calculate final token amount
        uint32 finalTokenAmount = static_cast<uint32>(tokenAmount * multiplier);
        
        LOG_INFO("scripts", "DungeonQuest: Quest {} base={} tokens, difficulty multiplier={:.2f}, final={} tokens", 
                 questId, tokenAmount, multiplier, finalTokenAmount);

        // Award tokens to player
        if (finalTokenAmount > 0)
        {
            if (player->AddItem(tokenItemId, finalTokenAmount))
            {
                // Build difficulty message
                std::string difficultyText = "";
                if (difficulty == DIFFICULTY_HEROIC)
                    difficultyText = " |cFFFFD700(Heroic +50% bonus)|r";
                else if (difficulty == DIFFICULTY_MYTHIC)
                    difficultyText = " |cFFFF4500(Mythic +100% bonus)|r";
                else if (difficulty == DIFFICULTY_MYTHIC_PLUS)
                    difficultyText = " |cFFDC143C(Mythic+ +200% bonus)|r";
                
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFF00FF00You have been awarded %u Dungeon Tokens!|r%s", 
                    finalTokenAmount, 
                    difficultyText.c_str()
                );
                
                LOG_INFO("scripts", "DungeonQuest: Awarded {} tokens (item {}) to player {}", 
                         finalTokenAmount, tokenItemId, player->GetName());
            }
            else
            {
                LOG_ERROR("scripts", "DungeonQuest: Failed to add token item {} to player {}", 
                         tokenItemId, player->GetName());
            }
        }
        
        // v4.0: Track difficulty completion
        uint32 dungeonId = DungeonQuestDB::GetDungeonIdFromQuest(questId);
        if (dungeonId > 0)
        {
            DungeonQuestDB::TrackDifficultyCompletion(player, dungeonId, difficulty);
        }
        
        // v4.0: Update difficulty statistics
        DungeonQuestDB::UpdateDifficultyStatistics(player, difficulty);
    }

    // Update quest completion statistics
    void UpdateQuestStatistics(Player* player, bool isDailyQuest, bool isWeeklyQuest, bool isDungeonQuest, uint32 questId)
    {
        // v4.0: Update difficulty statistics for all quest types
        QuestDifficulty difficulty = DungeonQuestDB::GetQuestDifficulty(questId);
        DungeonQuestDB::UpdateDifficultyStatistics(player, difficulty);
        
        if (isDailyQuest)
        {
            DungeonQuestDB::UpdateStatistics(player, "daily_quests_completed", 1);
            LOG_DEBUG("scripts", "DungeonQuest: Updated daily quest statistics for player {}", player->GetName());
        }
        else if (isWeeklyQuest)
        {
            DungeonQuestDB::UpdateStatistics(player, "weekly_quests_completed", 1);
            LOG_DEBUG("scripts", "DungeonQuest: Updated weekly quest statistics for player {}", player->GetName());
        }
        else if (isDungeonQuest)
        {
            DungeonQuestDB::UpdateStatistics(player, "dungeon_quests_completed", 1);
            
            // Update dungeon-specific progress
            uint32 dungeonId = DungeonQuestDB::GetDungeonIdFromQuest(questId); // v4.0: Use static database function
            if (dungeonId > 0)
            {
                DungeonQuestDB::UpdateDungeonProgress(player, dungeonId, questId);
                LOG_DEBUG("scripts", "DungeonQuest: Updated dungeon {} progress for player {}", 
                         dungeonId, player->GetName());
            }
        }
    }

    // Check and award achievements
    void CheckAchievements(Player* player, uint32 questId, bool isDailyQuest, bool isWeeklyQuest, bool isDungeonQuest)
    {
        // questId currently unused in this implementation; keep parameter for future use
        (void)questId;
        if (!player)
            return;

        // Achievement: First dungeon quest completed (ID 13500)
        if (isDungeonQuest)
        {
            uint32 totalCompletions = DungeonQuestDB::GetTotalQuestCompletions(player);
            
            if (totalCompletions == 1)
            {
                AwardAchievement(player, 13500, "First Steps");
            }
        }

        // Daily quest achievement milestones
        if (isDailyQuest)
        {
            uint32 dailyCount = DungeonQuestDB::GetStatisticValue(player, "daily_quests_completed");

            // Award milestones: 10, 25, 50, 100 dailies
            if (dailyCount == 10)
                AwardAchievement(player, 13501, "Daily Dedication (10)");
            else if (dailyCount == 25)
                AwardAchievement(player, 13502, "Daily Devotion (25)");
            else if (dailyCount == 50)
                AwardAchievement(player, 13503, "Daily Champion (50)");
            else if (dailyCount == 100)
                AwardAchievement(player, 13504, "Daily Legend (100)");
        }

        // Weekly quest achievement milestones
        if (isWeeklyQuest)
        {
            uint32 weeklyCount = DungeonQuestDB::GetStatisticValue(player, "weekly_quests_completed");

            // Award milestones: 5, 10, 25, 50 weeklies
            if (weeklyCount == 5)
                AwardAchievement(player, 13505, "Weekly Warrior (5)");
            else if (weeklyCount == 10)
                AwardAchievement(player, 13506, "Weekly Champion (10)");
            else if (weeklyCount == 25)
                AwardAchievement(player, 13507, "Weekly Legend (25)");
            else if (weeklyCount == 50)
                AwardAchievement(player, 13508, "Weekly Master (50)");
        }

        // Total dungeon quest milestones
        if (isDungeonQuest)
        {
            uint32 dungeonCount = DungeonQuestDB::GetStatisticValue(player, "dungeon_quests_completed");

            // Award milestones: 10, 25, 50, 100, 250, 500 dungeons
            if (dungeonCount == 10)
                AwardAchievement(player, 13509, "Dungeon Explorer (10)");
            else if (dungeonCount == 25)
                AwardAchievement(player, 13510, "Dungeon Adventurer (25)");
            else if (dungeonCount == 50)
                AwardAchievement(player, 13511, "Dungeon Champion (50)");
            else if (dungeonCount == 100)
                AwardAchievement(player, 13512, "Dungeon Master (100)");
            else if (dungeonCount == 250)
                AwardAchievement(player, 13513, "Dungeon Legend (250)");
            else if (dungeonCount == 500)
                AwardAchievement(player, 13514, "Dungeon Hero (500)");
        }
    }

    // Award achievement helper
    void AwardAchievement(Player* player, uint32 achievementId, const std::string& name) const
    {
        if (!player)
            return;

        AchievementEntry const* achievement = sAchievementStore.LookupEntry(achievementId);
        if (achievement)
        {
            player->CompletedAchievement(achievement);
            LOG_INFO("scripts", "DungeonQuest: Awarded achievement {} ({}) to player {}", 
                     achievementId, name, player->GetName());
        }
        else
        {
            LOG_ERROR("scripts", "DungeonQuest: Achievement {} not found in Achievement.dbc", achievementId);
        }
    }
};

// WorldScript for system initialization
class DungeonQuestWorldScript : public WorldScript
{
public:
    DungeonQuestWorldScript() : WorldScript("DungeonQuestWorldScript") { }

    void OnStartup() override
    {
        LOG_INFO("server.loading", ">> Loading Dungeon Quest System...");
        
        // Verify database tables exist
        if (CheckDatabaseTables())
        {
            LOG_INFO("server.loading", ">> Dungeon Quest System loaded successfully");
        }
        else
        {
            LOG_ERROR("server.loading", ">> Dungeon Quest System: Database tables not found! Please execute SQL files.");
        }
    }

private:
    bool CheckDatabaseTables() const
    {
        bool allTablesExist = true;

        // Check character database tables
        std::vector<std::string> charTables = {
            "dc_character_dungeon_progress",
            "dc_character_dungeon_quests_completed",
            "dc_character_dungeon_npc_respawn",
            "dc_character_dungeon_statistics"
        };

        for (const auto& tableName : charTables)
        {
            QueryResult result = CharacterDatabase.Query("SHOW TABLES LIKE '{}'", tableName);
            if (!result)
            {
                LOG_ERROR("server.loading", "DungeonQuest: Missing character table: {}", tableName);
                allTablesExist = false;
            }
        }

        // Check world database tables
        std::vector<std::string> worldTables = {
            "dc_daily_quest_token_rewards",
            "dc_weekly_quest_token_rewards",
            "dc_quest_reward_tokens"
        };

        for (const auto& tableName : worldTables)
        {
            QueryResult result = WorldDatabase.Query("SHOW TABLES LIKE '{}'", tableName);
            if (!result)
            {
                LOG_ERROR("server.loading", "DungeonQuest: Missing world table: {}", tableName);
                allTablesExist = false;
            }
        }

        return allTablesExist;
    }
};

// Register scripts
void AddSC_DungeonQuestSystem()
{
    new DungeonQuestPlayerScript();
    new DungeonQuestWorldScript();
}
