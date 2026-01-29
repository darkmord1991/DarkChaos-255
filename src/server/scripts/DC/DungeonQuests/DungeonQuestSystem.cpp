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
#include "DungeonQuestHelpers.h"
#include "DC/CrossSystem/CrossSystemRewards.h"
#include <unordered_set>

using namespace DungeonQuest;

// Database helper functions with caching for performance
class DungeonQuestDB
{
private:
    // Caches populated at startup
    static std::unordered_map<uint32, uint32> _dailyTokenRewards;      // questId -> token count
    static std::unordered_map<uint32, uint32> _weeklyTokenRewards;     // questId -> token count
    static std::unordered_map<uint32, QuestDifficulty> _questDifficulties; // questId -> difficulty
    static std::unordered_map<uint32, uint32> _questDungeonIds;        // questId -> dungeonId
    static std::unordered_map<uint8, float> _difficultyTokenMultipliers;  // difficulty -> multiplier
    static std::unordered_map<uint8, float> _difficultyGoldMultipliers;   // difficulty -> multiplier
    static uint32 _tokenItemId;
    static bool _cacheLoaded;

public:
    // Call this once at server startup
    static void LoadCache()
    {
        if (_cacheLoaded)
            return;

        // Load daily token rewards
        QueryResult result = WorldDatabase.Query("SELECT quest_id, token_count FROM dc_daily_quest_token_rewards");
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                _dailyTokenRewards[fields[0].Get<uint32>()] = fields[1].Get<uint32>();
            } while (result->NextRow());
        }
        LOG_INFO("scripts.dc", "DungeonQuestDB: Loaded {} daily token rewards", _dailyTokenRewards.size());

        // Load weekly token rewards
        result = WorldDatabase.Query("SELECT quest_id, token_count FROM dc_weekly_quest_token_rewards");
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                _weeklyTokenRewards[fields[0].Get<uint32>()] = fields[1].Get<uint32>();
            } while (result->NextRow());
        }
        LOG_INFO("scripts.dc", "DungeonQuestDB: Loaded {} weekly token rewards", _weeklyTokenRewards.size());

        // Load token item ID
        result = WorldDatabase.Query("SELECT token_item_id FROM dc_quest_reward_tokens LIMIT 1");
        if (result)
            _tokenItemId = (*result)[0].Get<uint32>();
        LOG_INFO("scripts.dc", "DungeonQuestDB: Token item ID = {}", _tokenItemId);

        // Load quest difficulty mappings (schema uses base_difficulty)
        result = WorldDatabase.Query("SELECT quest_id, base_difficulty FROM dc_quest_difficulty_mapping");
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint32 questId = fields[0].Get<uint32>();
                uint8 baseDifficulty = fields[1].Get<uint8>();

                QuestDifficulty mappedDifficulty = DIFFICULTY_NORMAL;
                switch (baseDifficulty)
                {
                    case 4: mappedDifficulty = DIFFICULTY_HEROIC; break;
                    case 5: mappedDifficulty = DIFFICULTY_MYTHIC; break;
                    case 3: mappedDifficulty = DIFFICULTY_HEROIC; break;
                    case 2: mappedDifficulty = DIFFICULTY_NORMAL; break;
                    case 1: mappedDifficulty = DIFFICULTY_NORMAL; break;
                    default: mappedDifficulty = DIFFICULTY_NORMAL; break;
                }

                _questDifficulties[questId] = mappedDifficulty;
            } while (result->NextRow());
        }
        LOG_INFO("scripts.dc", "DungeonQuestDB: Loaded {} quest difficulty mappings", _questDifficulties.size());

        // Load quest -> dungeon mappings from mapping table (schema-safe)
        result = WorldDatabase.Query("SELECT quest_id, dungeon_id FROM dc_dungeon_quest_mapping");
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint32 questId = fields[0].Get<uint32>();
                uint32 dungeonId = fields[1].Get<uint32>();
                if (dungeonId > 0)
                    _questDungeonIds[questId] = dungeonId;
            } while (result->NextRow());
        }
        LOG_INFO("scripts.dc", "DungeonQuestDB: Loaded {} quest dungeon mappings", _questDungeonIds.size());

        // Validate quest_template entries referenced by difficulty mapping
        std::unordered_set<uint32> templateQuestIds;
        QueryResult qt = WorldDatabase.Query(
            "SELECT ID FROM quest_template WHERE ID BETWEEN {} AND {}",
            QUEST_SYSTEM_MIN, QUEST_SYSTEM_MAX
        );
        if (qt)
        {
            do
            {
                templateQuestIds.insert((*qt)[0].Get<uint32>());
            } while (qt->NextRow());
        }

        uint32 missingTemplate = 0;
        for (auto const& entry : _questDifficulties)
        {
            if (templateQuestIds.find(entry.first) == templateQuestIds.end())
            {
                ++missingTemplate;
                LOG_ERROR("scripts.dc", "DungeonQuestDB: Missing quest_template entry for quest_id={} (difficulty mapping)", entry.first);
            }
        }
        if (missingTemplate > 0)
        {
            LOG_ERROR("scripts.dc", "DungeonQuestDB: {} difficulty-mapped quests are missing in quest_template", missingTemplate);
        }

        // Load difficulty configurations
        result = WorldDatabase.Query("SELECT difficulty_id, token_multiplier, gold_multiplier FROM dc_difficulty_config");
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint8 diffId = fields[0].Get<uint8>();
                _difficultyTokenMultipliers[diffId] = fields[1].Get<float>();
                _difficultyGoldMultipliers[diffId] = fields[2].Get<float>();
            } while (result->NextRow());
        }
        LOG_INFO("scripts.dc", "DungeonQuestDB: Loaded {} difficulty configs", _difficultyTokenMultipliers.size());

        _cacheLoaded = true;
        LOG_INFO("scripts.dc", "DungeonQuestDB: Cache loading complete");
    }

    // Get token rewards for a daily quest (cached)
    static uint32 GetDailyQuestTokenReward(uint32 questId)
    {
        auto it = _dailyTokenRewards.find(questId);
        return (it != _dailyTokenRewards.end()) ? it->second : 0;
    }

    // Get token rewards for a weekly quest (cached)
    static uint32 GetWeeklyQuestTokenReward(uint32 questId)
    {
        auto it = _weeklyTokenRewards.find(questId);
        return (it != _weeklyTokenRewards.end()) ? it->second : 0;
    }

    // Get token item ID from config table (cached)
    static uint32 GetTokenItemId()
    {
        return _tokenItemId;
    }

    // v4.0: Get difficulty from quest ID (cached)
    static QuestDifficulty GetQuestDifficulty(uint32 questId)
    {
        auto it = _questDifficulties.find(questId);
        return (it != _questDifficulties.end()) ? it->second : DIFFICULTY_NORMAL;
    }

    // v4.0: Get difficulty configuration (cached)
    static float GetDifficultyTokenMultiplier(QuestDifficulty difficulty)
    {
        auto it = _difficultyTokenMultipliers.find(static_cast<uint8>(difficulty));
        return (it != _difficultyTokenMultipliers.end()) ? it->second : 1.0f;
    }

    static float GetDifficultyGoldMultiplier(QuestDifficulty difficulty)
    {
        auto it = _difficultyGoldMultipliers.find(static_cast<uint8>(difficulty));
        return (it != _difficultyGoldMultipliers.end()) ? it->second : 1.0f;
    }

    // v4.0: Get dungeon ID from quest ID (cached)
    static uint32 GetDungeonIdFromQuest(uint32 questId)
    {
        auto it = _questDungeonIds.find(questId);
        return (it != _questDungeonIds.end()) ? it->second : 0;
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

        LOG_DEBUG("scripts.dc", "DungeonQuest: Updated {} for player {}",
                  statName, player->GetName());
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
        std::string sql = Acore::StringFormat(
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
        CharacterDatabase.Execute(sql.c_str());
    }

    // Update dungeon progress
    static void UpdateDungeonProgress(Player* player, uint32 dungeonId, uint32 questId)
    {
        if (!player)
            return;

        std::string sql = Acore::StringFormat(
            "INSERT INTO dc_character_dungeon_progress (guid, dungeon_id, quest_id, completion_count, last_update) "
            "VALUES ({}, {}, {}, 1, NOW()) "
            "ON DUPLICATE KEY UPDATE completion_count = completion_count + 1, last_update = NOW()",
            player->GetGUID().GetCounter(), dungeonId, questId);
        CharacterDatabase.Execute(sql.c_str());
    }

    // Log quest completion
    static void LogQuestCompletion(Player* player, uint32 questId)
    {
        if (!player)
            return;

        std::string sql = Acore::StringFormat(
            "INSERT INTO dc_character_dungeon_quests_completed (guid, quest_id, completion_time) "
            "VALUES ({}, {}, NOW())",
            player->GetGUID().GetCounter(), questId);
        CharacterDatabase.Execute(sql.c_str());
    }

    // Update statistics
    static void UpdateStatistics(Player* player, const std::string& stat_name, uint32 value)
    {
        if (!player)
            return;

        std::string sql = Acore::StringFormat(
            "INSERT INTO dc_character_dungeon_statistics (guid, stat_name, stat_value, last_update) "
            "VALUES ({}, '{}', {}, NOW()) "
            "ON DUPLICATE KEY UPDATE stat_value = stat_value + {}, last_update = NOW()",
            player->GetGUID().GetCounter(), stat_name, value, value);
        CharacterDatabase.Execute(sql.c_str());
    }

    // Get statistic value
    static uint32 GetStatisticValue(Player* player, const std::string& stat_name)
    {
        if (!player)
            return 0;

        std::string sql = Acore::StringFormat(
            "SELECT stat_value FROM dc_character_dungeon_statistics WHERE guid = {} AND stat_name = '{}'",
            player->GetGUID().GetCounter(), stat_name);
        QueryResult result = CharacterDatabase.Query(sql.c_str());

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

        std::string sql = Acore::StringFormat(
            "SELECT COUNT(*) FROM dc_character_dungeon_quests_completed WHERE guid = {}",
            player->GetGUID().GetCounter());
        QueryResult result = CharacterDatabase.Query(sql.c_str());

        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint32>();
        }
        return 0;
    }

    static uint32 GetDungeonQuestCompletions(Player* player)
    {
        if (!player)
            return 0;

        std::string sql = Acore::StringFormat(
            "SELECT COUNT(*) FROM dc_character_dungeon_quests_completed "
            "WHERE guid = {} AND quest_id BETWEEN {} AND {}",
            player->GetGUID().GetCounter(), QUEST_DUNGEON_MIN, QUEST_DUNGEON_MAX);
        QueryResult result = CharacterDatabase.Query(sql.c_str());

        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint32>();
        }
        return 0;
    }
};

// Static member definitions for DungeonQuestDB cache
std::unordered_map<uint32, uint32> DungeonQuestDB::_dailyTokenRewards;
std::unordered_map<uint32, uint32> DungeonQuestDB::_weeklyTokenRewards;
std::unordered_map<uint32, QuestDifficulty> DungeonQuestDB::_questDifficulties;
std::unordered_map<uint32, uint32> DungeonQuestDB::_questDungeonIds;
std::unordered_map<uint8, float> DungeonQuestDB::_difficultyTokenMultipliers;
std::unordered_map<uint8, float> DungeonQuestDB::_difficultyGoldMultipliers;
uint32 DungeonQuestDB::_tokenItemId = 0;
bool DungeonQuestDB::_cacheLoaded = false;

// Main PlayerScript for dungeon quest system
class DungeonQuestPlayerScript : public PlayerScript
{
public:
    DungeonQuestPlayerScript() : PlayerScript("DungeonQuestPlayerScript")
    {
    }

    void OnPlayerLogout(Player* player) override
    {
        DungeonQuestHelpers::InvalidatePlayerStatsCache(player);
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
        LOG_INFO("scripts.dc", "DungeonQuest: Player {} is about to complete quest {}",
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

        LOG_INFO("scripts.dc", "DungeonQuest: Player {} completed dungeon quest {}",
                 player->GetName(), questId);

        // Log the completion
        DungeonQuestDB::LogQuestCompletion(player, questId);

        // Handle token rewards
        HandleTokenRewards(player, questId, isDailyQuest, isWeeklyQuest);

        // Update statistics
        UpdateQuestStatistics(player, isDailyQuest, isWeeklyQuest, isDungeonQuest, questId);

        // Gossip/UI stats cache is keyed off stats tables; invalidate after updates.
        DungeonQuestHelpers::InvalidatePlayerStatsCache(player);

        // Check for achievement completion
        CheckAchievements(player, questId, isDailyQuest, isWeeklyQuest, isDungeonQuest);
    }

private:
    // Handle token reward distribution
    void HandleTokenRewards(Player* player, uint32 questId, bool isDailyQuest, bool isWeeklyQuest)
    {
        uint32 tokenAmount = 0;

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
            LOG_DEBUG("scripts.dc", "DungeonQuest: No token reward configured for quest {}", questId);
            return;
        }

        // v4.0: Get difficulty and apply multiplier
        QuestDifficulty difficulty = DungeonQuestDB::GetQuestDifficulty(questId);
        float multiplier = DungeonQuestDB::GetDifficultyTokenMultiplier(difficulty);

        // Calculate final token amount
        uint32 finalTokenAmount = static_cast<uint32>(tokenAmount * multiplier);

        LOG_INFO("scripts.dc", "DungeonQuest: Quest {} base={} tokens, difficulty multiplier={:.2f}, final={} tokens",
                 questId, tokenAmount, multiplier, finalTokenAmount);

        // Award tokens to player via central CrossSystem/Seasonal pipeline.
        if (finalTokenAmount > 0)
        {
            using DarkChaos::CrossSystem::ContentDifficulty;
            ContentDifficulty csDifficulty = ContentDifficulty::None;
            switch (difficulty)
            {
                case DIFFICULTY_HEROIC: csDifficulty = ContentDifficulty::Heroic; break;
                case DIFFICULTY_MYTHIC: csDifficulty = ContentDifficulty::Mythic; break;
                case DIFFICULTY_MYTHIC_PLUS: csDifficulty = ContentDifficulty::MythicPlus; break;
                default: csDifficulty = ContentDifficulty::Normal; break;
            }

            DarkChaos::CrossSystem::EventType evt = DarkChaos::CrossSystem::EventType::QuestComplete;
            if (isDailyQuest)
                evt = DarkChaos::CrossSystem::EventType::DailyQuestComplete;
            else if (isWeeklyQuest)
                evt = DarkChaos::CrossSystem::EventType::WeeklyQuestComplete;

            std::string sourceName = "Dungeon Quest";
            if (csDifficulty == ContentDifficulty::Heroic)
                sourceName = "Dungeon Quest (Heroic)";
            else if (csDifficulty == ContentDifficulty::Mythic)
                sourceName = "Dungeon Quest (Mythic)";
            else if (csDifficulty == ContentDifficulty::MythicPlus)
                sourceName = "Dungeon Quest (Mythic+)";

            bool ok = DarkChaos::CrossSystem::Rewards::AwardTokens(
                player,
                finalTokenAmount,
                DarkChaos::CrossSystem::SystemId::DungeonQuests,
                evt,
                sourceName,
                questId
            );

            if (ok)
                LOG_INFO("scripts.dc", "DungeonQuest: Awarded {} tokens to player {} via CrossSystem", finalTokenAmount, player->GetName());
            else
                LOG_ERROR("scripts.dc", "DungeonQuest: Failed to award {} tokens to player {} via CrossSystem", finalTokenAmount, player->GetName());
        }
    }

    // Update quest completion statistics
    void UpdateQuestStatistics(Player* player, bool isDailyQuest, bool isWeeklyQuest, bool isDungeonQuest, uint32 questId)
    {
        // Update totals and v4.0 difficulty tracking
        DungeonQuestDB::UpdateStatistics(player, "total_quests_completed", 1);

        QuestDifficulty difficulty = DungeonQuestDB::GetQuestDifficulty(questId);
        DungeonQuestDB::UpdateDifficultyStatistics(player, difficulty);

        // v4.0: Track difficulty completion when mapping exists
        uint32 dungeonId = DungeonQuestDB::GetDungeonIdFromQuest(questId);
        if (dungeonId > 0)
            DungeonQuestDB::TrackDifficultyCompletion(player, dungeonId, difficulty);

        if (isDailyQuest)
        {
            DungeonQuestDB::UpdateStatistics(player, "daily_quests_completed", 1);
            LOG_DEBUG("scripts.dc", "DungeonQuest: Updated daily quest statistics for player {}", player->GetName());
        }
        else if (isWeeklyQuest)
        {
            DungeonQuestDB::UpdateStatistics(player, "weekly_quests_completed", 1);
            LOG_DEBUG("scripts.dc", "DungeonQuest: Updated weekly quest statistics for player {}", player->GetName());
        }
        else if (isDungeonQuest)
        {
            DungeonQuestDB::UpdateStatistics(player, "dungeon_quests_completed", 1);

            // Update dungeon-specific progress
            uint32 dungeonId = DungeonQuestDB::GetDungeonIdFromQuest(questId); // v4.0: Use static database function
            if (dungeonId > 0)
            {
                DungeonQuestDB::UpdateDungeonProgress(player, dungeonId, questId);
                LOG_DEBUG("scripts.dc", "DungeonQuest: Updated dungeon {} progress for player {}",
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
            uint32 totalCompletions = DungeonQuestDB::GetDungeonQuestCompletions(player);

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
            LOG_INFO("scripts.dc", "DungeonQuest: Awarded achievement {} ({}) to player {}",
                     achievementId, name, player->GetName());
        }
        else
        {
            LOG_ERROR("scripts.dc", "DungeonQuest: Achievement {} not found in Achievement.dbc", achievementId);
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
        LOG_INFO("scripts.dc", ">> Loading Dungeon Quest System...");

        // Load cached data from database
        DungeonQuestDB::LoadCache();

        // Verify database tables exist
        if (CheckDatabaseTables())
        {
            LOG_INFO("scripts.dc", ">> Dungeon Quest System loaded successfully");
        }
        else
        {
            LOG_ERROR("scripts.dc", ">> Dungeon Quest System: Database tables not found! Please execute SQL files.");
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

        for (auto const& tableName : charTables)
        {
            std::string sql = Acore::StringFormat("SHOW TABLES LIKE '{}'", tableName);
            QueryResult result = CharacterDatabase.Query(sql.c_str());
            if (!result)
            {
                LOG_ERROR("scripts.dc", "DungeonQuest: Missing character table: {}", tableName);
                allTablesExist = false;
            }
        }

        // Check world database tables
        std::vector<std::string> worldTables = {
            "dc_daily_quest_token_rewards",
            "dc_weekly_quest_token_rewards",
            "dc_quest_reward_tokens"
        };

        for (auto const& tableName : worldTables)
        {
            std::string sql = Acore::StringFormat("SHOW TABLES LIKE '{}'", tableName);
            QueryResult result = WorldDatabase.Query(sql.c_str());
            if (!result)
            {
                LOG_ERROR("scripts.dc", "DungeonQuest: Missing world table: {}", tableName);
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
