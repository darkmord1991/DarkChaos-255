/*
 * Seasonal Reward System - DarkChaos
 * 
 * Core C++ implementation for seasonal rewards, caps, and progression
 * Client communication handled via Eluna AIO bridge
 * 
 * Author: DarkChaos Development Team
 * Date: November 22, 2025
 */

#pragma once

#include "Define.h"
#include "Player.h"
#include "SeasonalSystem.h"
#include <string>
#include <map>
#include <vector>

namespace DarkChaos
{
    namespace SeasonalRewards
    {
        // =====================================================================
        // Constants
        // =====================================================================
        
        constexpr uint8 WEEKLY_RESET_DAY = 2;               // Tuesday (0=Sunday)
        constexpr uint8 WEEKLY_RESET_HOUR = 15;             // 3:00 PM server time
        
        // =====================================================================
        // Configuration Structure
        // =====================================================================
        
        struct SeasonalConfig
        {
            bool enabled = true;
            uint32 activeSeason = 1;
            uint32 tokenItemId = DEFAULT_TOKEN_ITEM_ID;
            uint32 essenceItemId = DEFAULT_ESSENCE_ITEM_ID;
            uint32 weeklyTokenCap = 0;                      // 0 = unlimited
            uint32 weeklyEssenceCap = 0;                    // 0 = unlimited
            float questMultiplier = 1.0f;
            float creatureMultiplier = 1.0f;
            float worldBossMultiplier = 1.5f;
            float eventBossMultiplier = 1.25f;
            bool logTransactions = true;
            bool achievementTracking = true;
            uint8 resetDay = WEEKLY_RESET_DAY;
            uint8 resetHour = WEEKLY_RESET_HOUR;
        };
        
        // =====================================================================
        // Player Stats Structure
        // =====================================================================
        
        struct PlayerSeasonStats
        {
            uint32 playerGuid = 0;
            uint32 seasonId = 0;
            uint32 seasonalTokensEarned = 0;
            uint32 seasonalEssenceEarned = 0;
            uint32 weeklyTokensEarned = 0;
            uint32 weeklyEssenceEarned = 0;
            uint32 questsCompleted = 0;
            uint32 creaturesKilled = 0;
            uint32 dungeonBossesKilled = 0;
            uint32 worldBossesKilled = 0;
            uint32 prestigeLevel = 0;
            time_t lastWeeklyReset = 0;
            time_t lastUpdated = 0;
        };
        
        // =====================================================================
        // Reward Transaction Structure
        // =====================================================================
        
        struct RewardTransaction
        {
            uint32 playerGuid;
            uint32 seasonId;
            std::string source;
            uint32 sourceId;
            uint32 tokensAwarded;
            uint32 essenceAwarded;
            time_t timestamp;
        };
        
        // =====================================================================
        // Weekly Chest Structure
        // =====================================================================
        
        struct WeeklyChest
        {
            uint32 playerGuid;
            uint32 seasonId;
            time_t weekTimestamp;
            uint32 slot1Tokens = 0;
            uint32 slot1Essence = 0;
            uint32 slot2Tokens = 0;
            uint32 slot2Essence = 0;
            uint32 slot3Tokens = 0;
            uint32 slot3Essence = 0;
            uint8 slotsUnlocked = 0;
            bool collected = false;
        };
        
        // =====================================================================
        // Seasonal Reward Manager
        // =====================================================================
        
        class SeasonalRewardManager : public Seasonal::SeasonalParticipant
        {
        public:
            static SeasonalRewardManager* instance();
            
            // SeasonalParticipant interface implementation
            std::string GetSystemName() const override { return "seasonal_rewards"; }
            uint32 GetSystemVersion() const override { return 100; }
            void OnSeasonStart(uint32 season_id) override;
            void OnSeasonEnd(uint32 season_id) override;
            void OnPlayerSeasonChange(uint32 player_guid, uint32 old_season, uint32 new_season) override;
            bool ValidateSeasonTransition(uint32 player_guid, uint32 season_id) override;
            bool InitializeForSeason(uint32 season_id) override;
            bool CleanupFromSeason(uint32 season_id) override;
            
            // Initialization
            void LoadConfiguration();
            void LoadPlayerStats();
            void Initialize();
            
            // Configuration
            const SeasonalConfig& GetConfig() const { return config_; }
            void SetConfig(const SeasonalConfig& config) { config_ = config; }
            void ReloadConfiguration();
            
            // Reward Distribution
            bool AwardTokens(Player* player, uint32 amount, const std::string& source, uint32 sourceId = 0);
            bool AwardEssence(Player* player, uint32 amount, const std::string& source, uint32 sourceId = 0);
            bool AwardBoth(Player* player, uint32 tokens, uint32 essence, const std::string& source, uint32 sourceId = 0);
            
            // Quest Rewards
            bool ProcessQuestReward(Player* player, uint32 questId);
            
            // Creature Kill Rewards
            bool ProcessCreatureKill(Player* player, uint32 creatureEntry, bool isDungeonBoss = false, bool isWorldBoss = false);
            
            // Weekly Cap Management
            bool CheckWeeklyCap(Player* player, uint32& tokens, uint32& essence);
            time_t GetCurrentWeekTimestamp() const;
            bool IsNewWeek(Player* player);
            void ResetWeeklyStats(Player* player);
            
            // Weekly Chest System
            void GenerateWeeklyChest(Player* player);
            bool CollectWeeklyChest(Player* player);
            WeeklyChest* GetWeeklyChest(Player* player);
            
            // Player Stats
            PlayerSeasonStats* GetPlayerStats(uint32 playerGuid);
            PlayerSeasonStats* GetOrCreatePlayerStats(Player* player);
            void UpdatePlayerStats(Player* player, const PlayerSeasonStats& stats);
            void SavePlayerStats(const PlayerSeasonStats& stats);
            
            // Achievement Tracking
            void CheckAchievements(Player* player);
            void GrantAchievement(Player* player, uint32 achievementId);
            
            // Admin Commands
            void ResetPlayerSeason(Player* player);
            void SetActiveSeason(uint32 seasonId);
            void SetMultiplier(const std::string& type, float value);
            
            // Periodic Tasks
            void CheckWeeklyReset();
            void Update(uint32 diff);
            
            // Transaction Logging
            void LogTransaction(const RewardTransaction& transaction);
            std::vector<RewardTransaction> GetPlayerTransactions(uint32 playerGuid, uint32 limit = 50);
            
        private:
            SeasonalRewardManager() = default;
            ~SeasonalRewardManager() = default;
            
            // Internal helpers
            bool AwardCurrency(Player* player, uint32 itemId, uint32 amount, const std::string& source, uint32 sourceId);
            void UpdateWeeklyEarnings(Player* player, uint32 tokens, uint32 essence);
            void NotifyPlayer(Player* player, uint32 tokens, uint32 essence, const std::string& source);
            
            // Data storage
            SeasonalConfig config_;
            std::map<uint32, PlayerSeasonStats> playerStats_;
            std::map<uint32, WeeklyChest> weeklyChests_;
            
            // Cache for reward definitions
            std::map<uint32, std::pair<uint32, uint32>> questRewards_;      // questId -> (tokens, essence)
            std::map<uint32, std::pair<uint32, uint32>> creatureRewards_;   // creatureEntry -> (tokens, essence)
            
            // Update tracker
            uint32 updateTimer_ = 0;
            time_t lastWeeklyCheck_ = 0;
        };
        
        // =====================================================================
        // Singleton Accessor
        // =====================================================================
        
        #define sSeasonalRewards DarkChaos::SeasonalRewards::SeasonalRewardManager::instance()
        
    } // namespace SeasonalRewards
} // namespace DarkChaos
