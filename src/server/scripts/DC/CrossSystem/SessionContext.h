/*
 * DarkChaos Cross-System Session Context
 *
 * Tracks per-player state across all DC systems during a play session.
 * Provides centralized access to player's current dungeon, difficulty,
 * active systems, pending rewards, and cross-system bonuses.
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#pragma once

#include "CrossSystemCore.h"
#include "ObjectGuid.h"
#include <chrono>
#include <optional>
#include <unordered_set>

namespace DarkChaos
{
namespace CrossSystem
{
    // =========================================================================
    // Active Content State
    // =========================================================================
    
    struct ActiveContentState
    {
        ContentType type = ContentType::None;
        ContentDifficulty difficulty = ContentDifficulty::None;
        uint32 mapId = 0;
        uint32 instanceId = 0;
        uint64 enteredAt = 0;
        uint8 keystoneLevel = 0;      // For M+ dungeons
        uint32 seasonId = 0;
        bool isRunActive = false;     // For timed content like M+
        uint64 runStartedAt = 0;
        
        // Dungeon-specific
        uint32 bossesKilled = 0;
        uint32 trashKilled = 0;
        uint8 deaths = 0;
        uint8 wipes = 0;
        
        void Reset()
        {
            type = ContentType::None;
            difficulty = ContentDifficulty::None;
            mapId = 0;
            instanceId = 0;
            enteredAt = 0;
            keystoneLevel = 0;
            seasonId = 0;
            isRunActive = false;
            runStartedAt = 0;
            bossesKilled = 0;
            trashKilled = 0;
            deaths = 0;
            wipes = 0;
        }
        
        bool IsInContent() const { return type != ContentType::None; }
        bool IsInDungeon() const { return type == ContentType::Dungeon; }
        bool IsInRaid() const { return type == ContentType::Raid; }
        bool IsInPvP() const { return type == ContentType::Battleground || type == ContentType::Arena || type == ContentType::HLBG; }
        bool IsMythicPlus() const { return type == ContentType::Dungeon && keystoneLevel > 0; }
    };
    
    // =========================================================================
    // Player Progression Snapshot
    // =========================================================================
    
    struct ProgressionSnapshot
    {
        // Prestige
        uint8 prestigeLevel = 0;
        uint32 totalPrestiges = 0;
        
        // Seasonal
        uint32 currentSeasonId = 0;
        uint32 seasonalTokensEarned = 0;
        uint32 seasonalEssenceEarned = 0;
        uint32 weeklyTokensEarned = 0;
        uint32 weeklyEssenceEarned = 0;
        
        // M+ Score
        uint32 mythicPlusRating = 0;
        uint8 highestKeyCompleted = 0;
        uint32 mplusRunsThisWeek = 0;
        
        // Item Upgrades
        uint32 itemsUpgraded = 0;
        uint32 upgradesApplied = 0;
        uint8 highestUpgradeLevel = 0;
        
        // Dungeon Quests
        uint32 dungeonQuestsCompleted = 0;
        uint32 dailyQuestsToday = 0;
        uint32 weeklyQuestsThisWeek = 0;
        
        // Challenge Modes
        uint32 activeChallengeFlags = 0;  // Bitflags for active challenges
        bool isHardcoreLocked = false;
        
        // HLBG
        uint32 hlbgRating = 0;
        uint32 hlbgMatchesThisSeason = 0;
        
        // Calculated bonuses
        float prestigeBonus = 1.0f;       // 1.0 + (prestigeLevel * 0.02)
        float achievementBonus = 1.0f;    // Based on unlocked achievements
        float seasonalBonus = 1.0f;       // Current season multiplier
        
        void CalculateBonuses()
        {
            prestigeBonus = 1.0f + (prestigeLevel * 0.02f);  // +2% per prestige
            // achievementBonus calculated elsewhere based on unlocked achievements
            // seasonalBonus loaded from seasonal config
        }
    };
    
    // =========================================================================
    // Pending Reward Tracking
    // =========================================================================
    
    struct PendingReward
    {
        uint64 id = 0;
        SystemId sourceSystem = SystemId::None;
        EventType triggerEvent = EventType::None;
        uint32 tokens = 0;
        uint32 essence = 0;
        uint32 itemId = 0;
        uint32 itemCount = 0;
        std::string description;
        uint64 createdAt = 0;
        uint64 expiresAt = 0;
        bool claimed = false;
    };
    
    // =========================================================================
    // Session Context Class
    // =========================================================================
    
    class SessionContext
    {
    public:
        explicit SessionContext(ObjectGuid playerGuid);
        ~SessionContext();
        
        // Non-copyable
        SessionContext(const SessionContext&) = delete;
        SessionContext& operator=(const SessionContext&) = delete;
        
        // =====================================================================
        // Basic Info
        // =====================================================================
        
        ObjectGuid GetPlayerGuid() const { return playerGuid_; }
        uint64 GetSessionStartTime() const { return sessionStartTime_; }
        uint64 GetSessionDuration() const;
        
        // =====================================================================
        // Active Content State
        // =====================================================================
        
        const ActiveContentState& GetActiveContent() const { return activeContent_; }
        ActiveContentState& GetActiveContentMutable() { return activeContent_; }
        
        void SetActiveContent(ContentType type, ContentDifficulty difficulty, 
                             uint32 mapId, uint32 instanceId, uint8 keystoneLevel = 0);
        void ClearActiveContent();
        
        bool IsInContent() const { return activeContent_.IsInContent(); }
        bool IsInDungeon() const { return activeContent_.IsInDungeon(); }
        bool IsInRaid() const { return activeContent_.IsInRaid(); }
        bool IsInPvP() const { return activeContent_.IsInPvP(); }
        bool IsMythicPlus() const { return activeContent_.IsMythicPlus(); }
        
        // =====================================================================
        // Run State (for timed content)
        // =====================================================================
        
        void StartRun(uint32 seasonId = 0);
        void EndRun(bool success);
        bool IsRunActive() const { return activeContent_.isRunActive; }
        uint64 GetRunDuration() const;
        
        void IncrementBossKills();
        void IncrementTrashKills(uint32 count = 1);
        void IncrementDeaths();
        void IncrementWipes();
        
        // =====================================================================
        // Progression Snapshot
        // =====================================================================
        
        const ProgressionSnapshot& GetProgression() const { return progression_; }
        ProgressionSnapshot& GetProgressionMutable() { return progression_; }
        
        void RefreshProgression(Player* player);
        void SetPrestigeLevel(uint8 level);
        void SetSeasonalData(uint32 seasonId, uint32 tokens, uint32 essence, uint32 weeklyTokens, uint32 weeklyEssence);
        void SetMythicPlusData(uint32 rating, uint8 highestKey, uint32 runsThisWeek);
        
        // =====================================================================
        // Active Systems Tracking
        // =====================================================================
        
        void SetSystemActive(SystemId system, bool active = true);
        bool IsSystemActive(SystemId system) const;
        std::vector<SystemId> GetActiveSystems() const;
        
        // =====================================================================
        // Pending Rewards
        // =====================================================================
        
        uint64 AddPendingReward(const PendingReward& reward);
        bool ClaimReward(uint64 rewardId);
        void ExpireRewards();
        std::vector<PendingReward> GetPendingRewards() const;
        std::vector<PendingReward> GetPendingRewardsForSystem(SystemId system) const;
        uint32 GetPendingRewardCount() const { return static_cast<uint32>(pendingRewards_.size()); }
        
        // =====================================================================
        // Multiplier Calculations
        // =====================================================================
        
        float CalculateTokenMultiplier() const;
        float CalculateEssenceMultiplier() const;
        float CalculateLootQualityBonus() const;
        
        // Build a RewardContext with current session state
        RewardContext BuildRewardContext(SystemId sourceSystem, EventType triggerEvent, 
                                         uint32 sourceId = 0, const std::string& sourceName = "") const;
        
        // =====================================================================
        // Session Stats
        // =====================================================================
        
        struct SessionStats
        {
            uint32 tokensEarned = 0;
            uint32 essenceEarned = 0;
            uint32 creaturesKilled = 0;
            uint32 bossesKilled = 0;
            uint32 questsCompleted = 0;
            uint32 dungeonsCompleted = 0;
            uint32 mplusCompleted = 0;
            uint32 itemsUpgraded = 0;
            uint32 deaths = 0;
        };
        
        const SessionStats& GetSessionStats() const { return sessionStats_; }
        void AddSessionTokens(uint32 amount) { sessionStats_.tokensEarned += amount; }
        void AddSessionEssence(uint32 amount) { sessionStats_.essenceEarned += amount; }
        void IncrementSessionStat(const std::string& stat);
        
        // =====================================================================
        // Dirty Flag (for persistence)
        // =====================================================================
        
        bool IsDirty() const { return isDirty_; }
        void SetDirty(bool dirty = true) { isDirty_ = dirty; }
        void MarkClean() { isDirty_ = false; }
        
    private:
        ObjectGuid playerGuid_;
        uint64 sessionStartTime_;
        
        ActiveContentState activeContent_;
        ProgressionSnapshot progression_;
        SessionStats sessionStats_;
        
        std::unordered_set<SystemId> activeSystems_;
        std::vector<PendingReward> pendingRewards_;
        uint64 nextRewardId_ = 1;
        
        bool isDirty_ = false;
        
        mutable std::mutex mutex_;
    };
    
    // =========================================================================
    // Session Manager
    // =========================================================================
    
    class SessionManager
    {
    public:
        static SessionManager* instance();
        
        // Get or create session for player
        SessionContext* GetSession(ObjectGuid guid);
        SessionContext* GetSession(Player* player);
        
        // Session lifecycle
        SessionContext* CreateSession(Player* player);
        void DestroySession(ObjectGuid guid);
        bool HasSession(ObjectGuid guid) const;
        
        // Batch operations
        void SaveDirtySessions();
        void CleanupExpiredRewards();
        
        // Statistics
        uint32 GetActiveSessionCount() const;
        
    private:
        SessionManager() = default;
        
        std::unordered_map<ObjectGuid::LowType, std::unique_ptr<SessionContext>> sessions_;
        mutable std::mutex mutex_;
    };
    
    // Convenience inline
    inline SessionContext* GetPlayerSession(Player* player)
    {
        return SessionManager::instance()->GetSession(player);
    }

} // namespace CrossSystem
} // namespace DarkChaos
