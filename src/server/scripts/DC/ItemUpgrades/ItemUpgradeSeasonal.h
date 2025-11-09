/*
 * DarkChaos Item Upgrade - Seasonal Reset & Balance (Phase 4C)
 *
 * This header defines the seasonal system including:
 * - Seasonal data tracking and isolation
 * - Season transitions and reset mechanics
 * - Dynamic balance adjustments
 * - Progression history tracking
 * - Season-specific leaderboards
 *
 * Author: DarkChaos Development Team
 * Date: November 4, 2025
 */

#pragma once

#include "Define.h"
#include <map>
#include <vector>
#include <string>
#include <memory>
#include <ctime>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Season Management
        // =====================================================================

        /**
         * Represents a single season with its configuration
         */
        struct Season
        {
            uint32 season_id;                    // Unique season identifier
            std::string season_name;             // Display name (e.g., "Season 1: Awakening")
            uint64 start_timestamp;              // When season started
            uint64 end_timestamp;                // When season ends (0 = ongoing)
            bool is_active;                      // Is this the current season?
            uint32 max_upgrade_level;            // Maximum upgrade level in this season
            float cost_multiplier;               // Global cost multiplier for season
            float reward_multiplier;             // Prestige point multiplier
            std::string theme;                   // Season theme description
            uint32 milestone_essence_cap;        // Total essence that can be earned
            uint32 milestone_token_cap;          // Total tokens that can be earned

            Season() :
                season_id(1), season_name("Season 1"),
                start_timestamp(0), end_timestamp(0), is_active(false),
                max_upgrade_level(15), cost_multiplier(1.0f),
                reward_multiplier(1.0f), theme("Standard"),
                milestone_essence_cap(50000), milestone_token_cap(25000) {}

            /**
             * Check if season is in progress
             */
            bool IsInProgress() const
            {
                time_t now = time(nullptr);
                return is_active && start_timestamp <= (uint64)now &&
                       (end_timestamp == 0 || (uint64)now < end_timestamp);
            }

            /**
             * Get remaining time in season (in seconds)
             */
            int64 GetRemainingTime() const
            {
                if (!is_active || end_timestamp == 0)
                    return -1;  // Indefinite

                time_t now = time(nullptr);
                return end_timestamp - (uint64)now;
            }
        };

        /**
         * Manages seasons
         */
        class SeasonManager
        {
        private:
            std::map<uint32, Season> seasons;
            uint32 current_season_id;

        public:
            SeasonManager() : current_season_id(1)
            {
                InitializeSeasons();
            }

            /**
             * Initialize default seasons
             */
            void InitializeSeasons()
            {
                Season season1;
                season1.season_id = 1;
                season1.season_name = "Season 1: Awakening";
                season1.is_active = true;
                season1.start_timestamp = time(nullptr);
                season1.theme = "The beginning of artifact mastery";
                seasons[1] = season1;
            }

            /**
             * Create a new season
             */
            void CreateSeason(const Season& season)
            {
                seasons[season.season_id] = season;
            }

            /**
             * Get current active season
             */
            Season* GetActiveSeason()
            {
                for (auto& pair : seasons)
                {
                    if (pair.second.is_active && pair.second.IsInProgress())
                        return &pair.second;
                }
                return nullptr;
            }

            /**
             * Get season by ID
             */
            Season* GetSeason(uint32 season_id)
            {
                auto it = seasons.find(season_id);
                return it != seasons.end() ? &it->second : nullptr;
            }

            /**
             * Transition to next season
             */
            void TransitionToNextSeason(Season& next_season)
            {
                Season* current = GetActiveSeason();
                if (current)
                    current->is_active = false;

                next_season.is_active = true;
                seasons[next_season.season_id] = next_season;
                current_season_id = next_season.season_id;
            }

            /**
             * Get all seasons
             */
            const std::map<uint32, Season>& GetAllSeasons() const
            {
                return seasons;
            }
        };

        // =====================================================================
        // Season-Specific Player Data
        // =====================================================================

        /**
         * Player's data for a specific season
         */
        struct SeasonPlayerData
        {
            uint32 player_guid;
            uint32 season_id;
            uint32 essence_earned;               // Essence earned this season
            uint32 tokens_earned;                // Tokens earned this season
            uint32 essence_spent;                // Essence spent this season
            uint32 tokens_spent;                 // Tokens spent this season
            uint32 items_upgraded;               // Items upgraded this season
            uint32 upgrades_applied;             // Total upgrades applied
            uint32 prestige_earned;              // Prestige points earned
            uint8 rank_this_season;              // Leaderboard rank
            uint64 first_upgrade_timestamp;      // When first upgrade happened
            uint64 last_upgrade_timestamp;       // When last upgrade happened
            std::map<uint32, uint8> item_max_levels;  // Per-item max levels this season

            SeasonPlayerData() :
                player_guid(0), season_id(1), essence_earned(0), tokens_earned(0),
                essence_spent(0), tokens_spent(0), items_upgraded(0),
                upgrades_applied(0), prestige_earned(0), rank_this_season(0),
                first_upgrade_timestamp(0), last_upgrade_timestamp(0) {}

            /**
             * Check if at soft cap
             */
            bool IsAtEssenceSoftCap(uint32 cap) const
            {
                return essence_spent >= cap;
            }

            /**
             * Get season activity days
             */
            uint32 GetActivePlayDays() const
            {
                if (first_upgrade_timestamp == 0)
                    return 0;

                time_t now = time(nullptr);
                uint64 elapsed = (now - first_upgrade_timestamp);
                return static_cast<uint32>(elapsed / 86400);  // Convert to days
            }

            /**
             * Get efficiency (upgrades per essence)
             */
            float GetEfficiency() const
            {
                return essence_spent > 0 ? (float)upgrades_applied / essence_spent : 0.0f;
            }
        };

        // =====================================================================
        // Reset Mechanics
        // =====================================================================

        /**
         * Configuration for season reset behavior
         */
        struct SeasonResetConfig
        {
            bool carry_over_prestige;            // Prestige points carry to next season?
            bool reset_item_upgrades;            // Reset all item upgrades on season end?
            bool reset_currencies;               // Reset unspent currencies?
            uint32 prestige_carryover_percent;   // Prestige to carry over (%)
            uint32 token_carryover_percent;      // Tokens to carry over (%)
            uint32 essence_carryover_percent;    // Essence to carry over (%)
            bool award_season_rewards;           // Award cosmetic rewards?
            bool preserve_statistics;            // Keep historical data?

            SeasonResetConfig() :
                carry_over_prestige(true), reset_item_upgrades(false),
                reset_currencies(false), prestige_carryover_percent(100),
                token_carryover_percent(10), essence_carryover_percent(5),
                award_season_rewards(true), preserve_statistics(true) {}
        };

        /**
         * Manages season resets and transitions
         */
        class SeasonResetManager
        {
        private:
            SeasonResetConfig config;

        public:
            SeasonResetManager() = default;

            /**
             * Execute season reset for a player
             */
            virtual void ResetPlayerForSeason(uint32 player_guid, uint32 new_season_id) = 0;

            /**
             * Execute global season reset
             */
            virtual void ExecuteGlobalSeasonReset(uint32 new_season_id) = 0;

            /**
             * Calculate carry-over amounts
             */
            void CalculateCarryover(uint32 current_amount, uint32& out_carryover) const
            {
                out_carryover = (current_amount * config.prestige_carryover_percent) / 100;
            }

            /**
             * Get reset configuration
             */
            const SeasonResetConfig& GetConfig() const { return config; }

            /**
             * Set reset configuration
             */
            void SetConfig(const SeasonResetConfig& new_config)
            {
                config = new_config;
            }
        };

        // =====================================================================
        // Balance Adjustments
        // =====================================================================

        /**
         * Balance adjustment entry for tracking changes
         */
        struct BalanceAdjustment
        {
            uint32 adjustment_id;
            uint64 timestamp;
            std::string description;              // What was adjusted
            std::string change_details;           // Details of change
            uint32 season_id;                     // Which season this applied to
            float impact_multiplier;              // Multiplier for impact
            bool is_active;                       // Is this active?

            BalanceAdjustment() :
                adjustment_id(0), timestamp(0), season_id(1),
                impact_multiplier(1.0f), is_active(true) {}
        };

        /**
         * Manages dynamic balance adjustments
         */
        class BalanceManager
        {
        private:
            std::vector<BalanceAdjustment> adjustments;

        public:
            /**
             * Add a balance adjustment
             */
            void AddAdjustment(const BalanceAdjustment& adjustment)
            {
                adjustments.push_back(adjustment);
            }

            /**
             * Get active adjustments for season
             */
            std::vector<BalanceAdjustment> GetActiveAdjustments(uint32 season_id) const
            {
                std::vector<BalanceAdjustment> active;
                for (const auto& adj : adjustments)
                {
                    if (adj.is_active && adj.season_id == season_id)
                        active.push_back(adj);
                }
                return active;
            }

            /**
             * Get combined impact multiplier
             */
            float GetCombinedImpact(uint32 season_id) const
            {
                float combined = 1.0f;
                for (const auto& adj : GetActiveAdjustments(season_id))
                    combined *= adj.impact_multiplier;
                return combined;
            }

            /**
             * Apply adjustment to value
             */
            uint32 ApplyAdjustments(uint32 value, uint32 season_id) const
            {
                return static_cast<uint32>(value * GetCombinedImpact(season_id));
            }

            /**
             * Disable adjustment
             */
            void DisableAdjustment(uint32 adjustment_id)
            {
                for (auto& adj : adjustments)
                {
                    if (adj.adjustment_id == adjustment_id)
                        adj.is_active = false;
                }
            }
        };

        // =====================================================================
        // Progression History
        // =====================================================================

        /**
         * Historical record of a single upgrade event
         */
        struct UpgradeHistoryEntry
        {
            uint32 player_guid;
            uint32 item_guid;
            uint32 item_id;
            uint8 season_id;
            uint8 upgrade_from;                  // Previous level
            uint8 upgrade_to;                    // New level
            uint32 essence_cost;
            uint32 token_cost;
            uint64 timestamp;
            uint16 old_ilvl;
            uint16 new_ilvl;

            UpgradeHistoryEntry() :
                player_guid(0), item_guid(0), item_id(0), season_id(1),
                upgrade_from(0), upgrade_to(0), essence_cost(0),
                token_cost(0), timestamp(0), old_ilvl(0), new_ilvl(0) {}
        };

        /**
         * Manages upgrade history
         */
        class HistoryManager
        {
        public:
            virtual ~HistoryManager() = default;

            /**
             * Record an upgrade
             */
            virtual void RecordUpgrade(const UpgradeHistoryEntry& entry) = 0;

            /**
             * Get player's upgrade history
             */
            virtual std::vector<UpgradeHistoryEntry> GetPlayerHistory(uint32 player_guid, uint32 limit = 100) = 0;

            /**
             * Get season history for player
             */
            virtual std::vector<UpgradeHistoryEntry> GetSeasonHistory(uint32 player_guid, uint32 season_id) = 0;

            /**
             * Get item's upgrade history
             */
            virtual std::vector<UpgradeHistoryEntry> GetItemHistory(uint32 item_guid) = 0;

            /**
             * Get recent upgrades across all players (for leaderboard)
             */
            virtual std::vector<UpgradeHistoryEntry> GetRecentUpgrades(uint32 limit = 50) = 0;
        };

        // =====================================================================
        // Season Leaderboards
        // =====================================================================

        /**
         * Leaderboard entry
         */
        struct LeaderboardEntry
        {
            uint32 rank;
            uint32 player_guid;
            std::string player_name;
            uint32 score;                        // Points/upgrades/etc
            uint32 items_upgraded;
            uint32 prestige_points;
            uint8 prestige_rank;
            std::string prestige_title;

            LeaderboardEntry() :
                rank(0), player_guid(0), score(0), items_upgraded(0),
                prestige_points(0), prestige_rank(0) {}
        };

        /**
         * Manages season leaderboards
         */
        class LeaderboardManager
        {
        public:
            virtual ~LeaderboardManager() = default;

            /**
             * Get upgrade leaderboard for season
             */
            virtual std::vector<LeaderboardEntry> GetUpgradeLeaderboard(uint32 season_id, uint32 limit = 25) = 0;

            /**
             * Get prestige leaderboard for season
             */
            virtual std::vector<LeaderboardEntry> GetPrestigeLeaderboard(uint32 season_id, uint32 limit = 25) = 0;

            /**
             * Get efficiency leaderboard (upgrades per essence spent)
             */
            virtual std::vector<LeaderboardEntry> GetEfficiencyLeaderboard(uint32 season_id, uint32 limit = 25) = 0;

            /**
             * Get player's rank on leaderboard
             */
            virtual uint32 GetPlayerRank(uint32 player_guid, uint32 season_id) = 0;

            /**
             * Update leaderboards (called after each upgrade or daily)
             */
            virtual void UpdateLeaderboards(uint32 season_id) = 0;
        };

    } // namespace ItemUpgrade
} // namespace DarkChaos
