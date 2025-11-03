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

// Quest ID ranges
constexpr uint32 QUEST_DAILY_MIN = 700101;
constexpr uint32 QUEST_DAILY_MAX = 700104;
constexpr uint32 QUEST_WEEKLY_MIN = 700201;
constexpr uint32 QUEST_WEEKLY_MAX = 700204;
constexpr uint32 QUEST_DUNGEON_MIN = 700701;
constexpr uint32 QUEST_DUNGEON_MAX = 700999;

// Achievement ID range (13500-13551)
constexpr uint32 ACHIEVEMENT_MIN = 13500;
constexpr uint32 ACHIEVEMENT_MAX = 13551;

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

    // Update dungeon progress
    static void UpdateDungeonProgress(Player* player, uint32 dungeonId, uint32 questId)
    {
        if (!player)
            return;

        CharacterDatabase.Execute(
            "INSERT INTO dc_character_dungeon_progress (guid, dungeon_id, quest_id, completion_count, last_update) "
            "VALUES ({}, {}, {}, 1, NOW()) "
            "ON DUPLICATE KEY UPDATE completion_count = completion_count + 1, last_update = NOW()",
            player->GetGUID().GetCounter(), dungeonId, questId);
    }

    // Log quest completion
    static void LogQuestCompletion(Player* player, uint32 questId)
    {
        if (!player)
            return;

        CharacterDatabase.Execute(
            "INSERT INTO dc_character_dungeon_quests_completed (guid, quest_id, completion_time) "
            "VALUES ({}, {}, NOW())",
            player->GetGUID().GetCounter(), questId);
    }

    // Update statistics
    static void UpdateStatistics(Player* player, const std::string& stat_name, uint32 value)
    {
        if (!player)
            return;

        CharacterDatabase.Execute(
            "INSERT INTO dc_character_dungeon_statistics (guid, stat_name, stat_value, last_update) "
            "VALUES ({}, '{}', {}, NOW()) "
            "ON DUPLICATE KEY UPDATE stat_value = stat_value + {}, last_update = NOW()",
            player->GetGUID().GetCounter(), stat_name, value, value);
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

        if (isDailyQuest)
        {
            tokenAmount = DungeonQuestDB::GetDailyQuestTokenReward(questId);
        }
        else if (isWeeklyQuest)
        {
            tokenAmount = DungeonQuestDB::GetWeeklyQuestTokenReward(questId);
        }

        if (tokenAmount > 0)
        {
            // Add tokens to player inventory. AddItem returns bool for item IDs
            if (player->AddItem(tokenItemId, tokenAmount))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You have been awarded %u Dungeon Tokens!", tokenAmount);
                LOG_INFO("scripts", "DungeonQuest: Awarded {} tokens (item {}) to player {}", 
                         tokenAmount, tokenItemId, player->GetName());
            }
            else
            {
                LOG_ERROR("scripts", "DungeonQuest: Failed to add token item {} to player {}", 
                         tokenItemId, player->GetName());
            }
        }
    }

    // Update quest completion statistics
    void UpdateQuestStatistics(Player* player, bool isDailyQuest, bool isWeeklyQuest, bool isDungeonQuest, uint32 questId)
    {
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
            uint32 dungeonId = GetDungeonIdFromQuest(questId);
            if (dungeonId > 0)
            {
                DungeonQuestDB::UpdateDungeonProgress(player, dungeonId, questId);
                LOG_DEBUG("scripts", "DungeonQuest: Updated dungeon {} progress for player {}", 
                         dungeonId, player->GetName());
            }
        }
    }

    // Map quest IDs to dungeon IDs
    uint32 GetDungeonIdFromQuest(uint32 questId) const
    {
        // Quest ranges by dungeon (based on SQL data)
        // Ragefire Chasm: 700701-700702
        if (questId >= 700701 && questId <= 700702)
            return 389; // Ragefire Chasm zone ID

        // Blackfathom Deeps: 700703-700704
        if (questId >= 700703 && questId <= 700704)
            return 48; // Blackfathom Deeps zone ID

        // Gnomeregan: 700705-700706
        if (questId >= 700705 && questId <= 700706)
            return 90; // Gnomeregan zone ID

        // Shadowfang Keep: 700707-700708
        if (questId >= 700707 && questId <= 700708)
            return 33; // Shadowfang Keep zone ID

        return 0;
    }

    // Check and award achievements
    void CheckAchievements(Player* player, uint32 questId, bool isDailyQuest, bool isWeeklyQuest, bool isDungeonQuest)
    {
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
