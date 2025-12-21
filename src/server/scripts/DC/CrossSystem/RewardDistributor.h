/*
 * DarkChaos Cross-System Reward Distributor
 *
 * Unified reward distribution system that calculates multipliers,
 * applies cross-system bonuses, and routes rewards to appropriate systems.
 *
 * Features:
 * - Centralized multiplier calculation
 * - Cross-system bonus stacking
 * - Weekly cap enforcement
 * - Transaction logging
 * - Reward previews
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#pragma once

#include "DC/CrossSystem/CrossSystemCore.h"
#include <functional>
#include <optional>
#include <unordered_map>
#include <vector>

class Player;

namespace DarkChaos
{
namespace CrossSystem
{
    // =========================================================================
    // Reward Types
    // =========================================================================

    enum class RewardType : uint8
    {
        None        = 0,
        Tokens      = 1,
        Essence     = 2,
        Item        = 3,
        Currency    = 4,    // Generic currency (honor, etc.)
        Experience  = 5,
        Gold        = 6,
        Max
    };

    // =========================================================================
    // Reward Definition
    // =========================================================================

    struct RewardDefinition
    {
        RewardType type = RewardType::None;
        uint32 amount = 0;
        uint32 itemId = 0;          // For Item type
        uint32 currencyId = 0;      // For Currency type
        float multiplier = 1.0f;    // Applied before distribution

        RewardDefinition() = default;
        RewardDefinition(RewardType t, uint32 a, float m = 1.0f)
            : type(t), amount(a), multiplier(m) {}

        static RewardDefinition Tokens(uint32 amount, float mult = 1.0f)
        {
            return RewardDefinition(RewardType::Tokens, amount, mult);
        }

        static RewardDefinition Essence(uint32 amount, float mult = 1.0f)
        {
            return RewardDefinition(RewardType::Essence, amount, mult);
        }

        static RewardDefinition Item(uint32 itemId, uint32 count = 1)
        {
            RewardDefinition r(RewardType::Item, count);
            r.itemId = itemId;
            return r;
        }
    };

    // =========================================================================
    // Reward Calculation Result
    // =========================================================================

    struct RewardCalculation
    {
        RewardType type = RewardType::None;
        uint32 baseAmount = 0;
        uint32 finalAmount = 0;

        // Multiplier breakdown
        float baseMultiplier = 1.0f;
        float prestigeMultiplier = 1.0f;
        float difficultyMultiplier = 1.0f;
        float contentMultiplier = 1.0f;
        float keystoneMultiplier = 1.0f;
        float seasonalMultiplier = 1.0f;
        float eventMultiplier = 1.0f;
        float finalMultiplier = 1.0f;

        // Cap info
        uint32 cappedAmount = 0;
        bool wasCapped = false;
        uint32 weeklyCapRemaining = 0;

        std::string GetBreakdown() const;
    };

    // =========================================================================
    // Distribution Result
    // =========================================================================

    struct DistributionResult
    {
        bool success = false;
        std::string error;

        uint32 tokensAwarded = 0;
        uint32 essenceAwarded = 0;
        std::vector<std::pair<uint32, uint32>> itemsAwarded;  // itemId, count

        RewardCalculation tokenCalc;
        RewardCalculation essenceCalc;

        uint64 transactionId = 0;

        operator bool() const { return success; }
    };

    // =========================================================================
    // Weekly Cap Status
    // =========================================================================

    struct WeeklyCapStatus
    {
        uint32 tokensCurrent = 0;
        uint32 tokensCap = 0;
        uint32 tokensRemaining = 0;

        uint32 essenceCurrent = 0;
        uint32 essenceCap = 0;
        uint32 essenceRemaining = 0;

        time_t resetTime = 0;
        bool tokensAtCap = false;
        bool essenceAtCap = false;

        bool IsAtCap() const { return tokensAtCap || essenceAtCap; }
    };

    // =========================================================================
    // Reward Transaction Log
    // =========================================================================

    struct RewardTransaction
    {
        uint64 id = 0;
        ObjectGuid playerGuid;
        uint64 timestamp = 0;

        SystemId sourceSystem = SystemId::None;
        EventType triggerEvent = EventType::None;
        std::string source;
        uint32 sourceId = 0;

        uint32 tokensBase = 0;
        uint32 tokensFinal = 0;
        uint32 essenceBase = 0;
        uint32 essenceFinal = 0;

        float multiplierApplied = 1.0f;
        bool wasCapped = false;

        std::string notes;
    };

    // =========================================================================
    // Reward Distributor Class
    // =========================================================================

    class RewardDistributor
    {
    public:
        static RewardDistributor* instance();

        // =====================================================================
        // Configuration
        // =====================================================================

        void LoadConfiguration();
        void ReloadConfiguration();

        const MultiplierConfig& GetMultiplierConfig() const { return multiplierConfig_; }
        void SetMultiplierConfig(const MultiplierConfig& config) { multiplierConfig_ = config; }

        // Set global event multiplier (for special events)
        void SetEventMultiplier(float multiplier, uint32 durationSeconds = 0);
        float GetEventMultiplier() const;

        // =====================================================================
        // Multiplier Calculation
        // =====================================================================

        // Calculate all applicable multipliers for a reward context
        RewardCalculation CalculateReward(const RewardContext& context, RewardType type, uint32 baseAmount);

        // Get multiplier for specific factors
        float GetPrestigeMultiplier(uint8 prestigeLevel) const;
        float GetDifficultyMultiplier(ContentDifficulty difficulty) const;
        float GetContentTypeMultiplier(ContentType type) const;
        float GetKeystoneMultiplier(uint8 keystoneLevel) const;
        float GetSeasonalMultiplier(uint32 seasonId) const;

        // =====================================================================
        // Reward Distribution
        // =====================================================================

        // Main distribution entry point
        DistributionResult Distribute(Player* player, const RewardContext& context,
                                      const std::vector<RewardDefinition>& rewards);

        // Convenience methods for common reward types
        DistributionResult DistributeTokens(Player* player, const RewardContext& context, uint32 baseAmount);
        DistributionResult DistributeEssence(Player* player, const RewardContext& context, uint32 baseAmount);
        DistributionResult DistributeBoth(Player* player, const RewardContext& context,
                                         uint32 baseTokens, uint32 baseEssence);

        // Item rewards (no multipliers applied)
        bool DistributeItem(Player* player, uint32 itemId, uint32 count = 1,
                           SystemId source = SystemId::None, const std::string& reason = "");

        // =====================================================================
        // Preview (no actual distribution)
        // =====================================================================

        std::vector<RewardCalculation> PreviewRewards(Player* player, const RewardContext& context,
                                                      const std::vector<RewardDefinition>& rewards);

        std::string GetRewardPreviewText(Player* player, const RewardContext& context,
                                         const std::vector<RewardDefinition>& rewards);

        // =====================================================================
        // Weekly Caps
        // =====================================================================

        WeeklyCapStatus GetWeeklyCapStatus(Player* player) const;

        uint32 GetWeeklyTokenCap() const { return weeklyTokenCap_; }
        uint32 GetWeeklyEssenceCap() const { return weeklyEssenceCap_; }

        void SetWeeklyTokenCap(uint32 cap) { weeklyTokenCap_ = cap; }
        void SetWeeklyEssenceCap(uint32 cap) { weeklyEssenceCap_ = cap; }

        bool IsAtTokenCap(Player* player) const;
        bool IsAtEssenceCap(Player* player) const;

        // =====================================================================
        // Transaction Logging
        // =====================================================================

        void EnableTransactionLogging(bool enable) { logTransactions_ = enable; }
        bool IsTransactionLoggingEnabled() const { return logTransactions_; }

        const std::vector<RewardTransaction>& GetRecentTransactions() const { return recentTransactions_; }
        std::vector<RewardTransaction> GetTransactionsForPlayer(ObjectGuid guid) const;
        void ClearTransactionHistory();

        // =====================================================================
        // Statistics
        // =====================================================================

        struct Statistics
        {
            uint64 totalTransactions = 0;
            uint64 tokensDistributed = 0;
            uint64 essenceDistributed = 0;
            uint64 itemsDistributed = 0;
            uint64 transactionsCapped = 0;
            std::unordered_map<SystemId, uint64> distributionsBySystem;
        };

        const Statistics& GetStatistics() const { return stats_; }
        void ResetStatistics();

    private:
        RewardDistributor() = default;

        // Internal distribution
        bool DoDistributeTokens(Player* player, uint32 amount, const RewardContext& context);
        bool DoDistributeEssence(Player* player, uint32 amount, const RewardContext& context);

        // Logging
        void LogTransaction(const RewardTransaction& transaction);

        // Configuration
        MultiplierConfig multiplierConfig_;
        uint32 weeklyTokenCap_ = 0;      // 0 = unlimited
        uint32 weeklyEssenceCap_ = 0;    // 0 = unlimited

        // Event multiplier
        float eventMultiplier_ = 1.0f;
        uint64 eventMultiplierExpires_ = 0;

        // Transaction log
        bool logTransactions_ = true;
        std::vector<RewardTransaction> recentTransactions_;
        uint32 maxTransactionHistory_ = 500;
        uint64 nextTransactionId_ = 1;

        // Statistics
        Statistics stats_;

        mutable std::mutex mutex_;
    };

    // Convenience inline
    inline RewardDistributor* GetRewardDistributor()
    {
        return RewardDistributor::instance();
    }

} // namespace CrossSystem
} // namespace DarkChaos
