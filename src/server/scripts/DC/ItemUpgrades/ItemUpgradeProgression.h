/*
 * DarkChaos Item Upgrade - Upgrade Progression System (Phase 4B)
 * 
 * This header defines the progression tracking system including:
 * - Tier-based progression management
 * - Level caps and constraints
 * - Cost scaling configuration
 * - Soft/hard caps on weekly essence spending
 * - Prestige system for tracking achievements
 * - Player progression statistics
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
        // Tier-Based Progression Configuration
        // =====================================================================

        /**
         * Configuration for a specific tier's progression
         */
        struct TierProgressionConfig
        {
            uint8 tier_id;                       // 1-5 (Common to Legendary)
            uint8 max_upgrade_level;             // Maximum upgrade level for this tier
            float cost_multiplier;               // Multiplier for this tier's costs
            float stat_multiplier;               // Stat bonus multiplier
            float ilvl_multiplier;               // Item level bonus multiplier
            uint32 prestige_points_per_level;    // Prestige points awarded per upgrade
            bool requires_unlocking;             // If true, player must "unlock" this tier
            uint32 unlock_cost_tokens;           // Cost to unlock tier
            uint32 unlock_cost_essence;          // Cost to unlock tier
            std::string tier_name;               // Display name (Common, Uncommon, etc.)

            TierProgressionConfig() :
                tier_id(0), max_upgrade_level(15), cost_multiplier(1.0f),
                stat_multiplier(1.0f), ilvl_multiplier(1.0f),
                prestige_points_per_level(10), requires_unlocking(false),
                unlock_cost_tokens(0), unlock_cost_essence(0),
                tier_name("Unknown") {}
        };

        /**
         * Manages tier progression configuration
         */
        class TierProgressionManager
        {
        private:
            std::map<uint8, TierProgressionConfig> tier_configs;

        public:
            TierProgressionManager()
            {
                InitializeDefaultTiers();
            }

            /**
             * Initialize default tier configurations
             */
            void InitializeDefaultTiers()
            {
                // Common (Tier 1)
                TierProgressionConfig common;
                common.tier_id = 1;
                common.tier_name = "Common";
                common.max_upgrade_level = 10;
                common.cost_multiplier = 0.8f;
                common.stat_multiplier = 0.9f;
                common.ilvl_multiplier = 1.0f;
                common.prestige_points_per_level = 5;
                tier_configs[1] = common;

                // Uncommon (Tier 2)
                TierProgressionConfig uncommon;
                uncommon.tier_id = 2;
                uncommon.tier_name = "Uncommon";
                uncommon.max_upgrade_level = 12;
                uncommon.cost_multiplier = 1.0f;
                uncommon.stat_multiplier = 0.95f;
                uncommon.ilvl_multiplier = 1.0f;
                uncommon.prestige_points_per_level = 10;
                tier_configs[2] = uncommon;

                // Rare (Tier 3)
                TierProgressionConfig rare;
                rare.tier_id = 3;
                rare.tier_name = "Rare";
                rare.max_upgrade_level = 15;
                rare.cost_multiplier = 1.2f;
                rare.stat_multiplier = 1.0f;
                rare.ilvl_multiplier = 1.5f;
                rare.prestige_points_per_level = 15;
                tier_configs[3] = rare;

                // Epic (Tier 4)
                TierProgressionConfig epic;
                epic.tier_id = 4;
                epic.tier_name = "Epic";
                epic.max_upgrade_level = 15;
                epic.cost_multiplier = 1.5f;
                epic.stat_multiplier = 1.15f;
                epic.ilvl_multiplier = 2.0f;
                epic.prestige_points_per_level = 25;
                tier_configs[4] = epic;

                // Legendary (Tier 5)
                TierProgressionConfig legendary;
                legendary.tier_id = 5;
                legendary.tier_name = "Legendary";
                legendary.max_upgrade_level = 15;
                legendary.cost_multiplier = 2.0f;
                legendary.stat_multiplier = 1.25f;
                legendary.ilvl_multiplier = 2.5f;
                legendary.prestige_points_per_level = 50;
                tier_configs[5] = legendary;
            }

            /**
             * Get tier configuration
             */
            const TierProgressionConfig* GetTierConfig(uint8 tier_id) const
            {
                auto it = tier_configs.find(tier_id);
                return it != tier_configs.end() ? &it->second : nullptr;
            }

            /**
             * Get maximum upgrade level for tier
             */
            uint8 GetMaxUpgradeLevel(uint8 tier_id) const
            {
                const auto* config = GetTierConfig(tier_id);
                return config ? config->max_upgrade_level : 0;
            }

            /**
             * Get tier name
             */
            std::string GetTierName(uint8 tier_id) const
            {
                const auto* config = GetTierConfig(tier_id);
                return config ? config->tier_name : "Unknown";
            }
        };

        // =====================================================================
        // Level Caps & Constraints
        // =====================================================================

        /**
         * Enforces upgrade level constraints
         */
        class LevelCapManager
        {
        public:
            /**
             * Check if player can upgrade to a specific level
             * @param player_guid: Player GUID
             * @param target_level: Target upgrade level
             * @param tier_id: Item tier
             * @return true if upgrade is allowed
             */
            virtual bool CanUpgradeToLevel(uint32 player_guid, uint8 target_level, uint8 tier_id) const = 0;

            /**
             * Get maximum level player can upgrade to
             * @param player_guid: Player GUID
             * @param tier_id: Item tier
             * @return Maximum upgrade level
             */
            virtual uint8 GetPlayerMaxUpgradeLevel(uint32 player_guid, uint8 tier_id) const = 0;

            /**
             * Set player's upgrade level cap for tier
             */
            virtual void SetPlayerTierCap(uint32 player_guid, uint8 tier_id, uint8 max_level) = 0;

            /**
             * Check if tier is unlocked for player
             */
            virtual bool IsTierUnlocked(uint32 player_guid, uint8 tier_id) const = 0;

            /**
             * Unlock tier for player
             */
            virtual void UnlockTier(uint32 player_guid, uint8 tier_id) = 0;
        };

        // =====================================================================
        // Cost Scaling Configuration
        // =====================================================================

        /**
         * Configuration for cost scaling behavior
         */
        struct CostScalingConfig
        {
            float base_escalation_rate;          // Default 1.1 (10% increase per level)
            float tier_cost_multipliers[6];      // Multipliers per tier
            uint32 softcap_weekly_essence;       // Soft cap (warning)
            uint32 hardcap_weekly_essence;       // Hard cap (blocking)
            uint32 softcap_weekly_tokens;        // Soft cap tokens
            uint32 hardcap_weekly_tokens;        // Hard cap tokens
            bool enable_weekly_caps;             // Toggle caps on/off
            uint32 cap_reset_day;                // Day of week caps reset (0=Sunday)

            CostScalingConfig() :
                base_escalation_rate(1.1f),
                softcap_weekly_essence(1000),
                hardcap_weekly_essence(2000),
                softcap_weekly_tokens(500),
                hardcap_weekly_tokens(1000),
                enable_weekly_caps(true),
                cap_reset_day(0)
            {
                // Default tier multipliers (applied to base costs)
                tier_cost_multipliers[0] = 0.0f;
                tier_cost_multipliers[1] = 0.8f;   // Common: 80%
                tier_cost_multipliers[2] = 1.0f;   // Uncommon: 100%
                tier_cost_multipliers[3] = 1.2f;   // Rare: 120%
                tier_cost_multipliers[4] = 1.5f;   // Epic: 150%
                tier_cost_multipliers[5] = 2.0f;   // Legendary: 200%
            }
        };

        /**
         * Manages cost scaling and caps
         */
        class CostScalingManager
        {
        private:
            CostScalingConfig config;

        public:
            CostScalingManager() = default;

            /**
             * Check if player has hit weekly cap
             */
            virtual bool HasHitWeeklyCap(uint32 player_guid, CurrencyType currency) const = 0;

            /**
             * Get remaining weekly budget for player
             */
            virtual uint32 GetWeeklyRemainingBudget(uint32 player_guid, CurrencyType currency) const = 0;

            /**
             * Get weekly spending for player
             */
            virtual uint32 GetWeeklySpending(uint32 player_guid, CurrencyType currency) const = 0;

            /**
             * Check if spending would trigger soft cap warning
             */
            bool WouldTriggerSoftCap(uint32 player_guid, CurrencyType currency, uint32 amount) const
            {
                uint32 current = GetWeeklySpending(player_guid, currency);
                uint32 cap = (currency == CURRENCY_ARTIFACT_ESSENCE) ?
                    config.softcap_weekly_essence : config.softcap_weekly_tokens;
                return (current + amount) > cap;
            }

            /**
             * Check if spending would hit hard cap
             */
            bool WouldHitHardCap(uint32 player_guid, CurrencyType currency, uint32 amount) const
            {
                if (!config.enable_weekly_caps)
                    return false;
                return (GetWeeklySpending(player_guid, currency) + amount) >
                       ((currency == CURRENCY_ARTIFACT_ESSENCE) ?
                           config.hardcap_weekly_essence : config.hardcap_weekly_tokens);
            }

            /**
             * Get config
             */
            const CostScalingConfig& GetConfig() const { return config; }
        };

        // =====================================================================
        // Prestige System
        // =====================================================================

        /**
         * Player artifact mastery information
         */
        struct PlayerArtifactMasteryInfo
        {
            uint32 player_guid;
            uint32 total_mastery_points;         // Total mastery points earned
            uint8 mastery_rank;                  // Mastery level (0+)
            uint32 mastery_points_this_rank;     // Progress to next rank
            uint32 items_fully_upgraded;         // Number of fully upgraded items
            uint32 total_upgrades_applied;       // Total number of upgrades
            uint64 last_upgrade_timestamp;       // When last upgrade was applied
            std::string mastery_title;           // Display title

            PlayerArtifactMasteryInfo() :
                player_guid(0), total_mastery_points(0), mastery_rank(0),
                mastery_points_this_rank(0), items_fully_upgraded(0),
                total_upgrades_applied(0), last_upgrade_timestamp(0),
                mastery_title("Novice Upgrader") {}

            /**
             * Get progress to next rank (0-100%)
             */
            uint8 GetProgressToNextRank() const
            {
                const uint32 points_per_rank = 1000;
                return static_cast<uint8>((mastery_points_this_rank * 100) / points_per_rank);
            }

            /**
             * Get mastery title based on rank
             */
            std::string GetMasteryTitle() const
            {
                if (mastery_rank < 1) return "Novice Upgrader";
                if (mastery_rank < 5) return "Skilled Upgrader";
                if (mastery_rank < 10) return "Master Upgrader";
                if (mastery_rank < 20) return "Grand Master";
                if (mastery_rank < 50) return "Artifact Lord";
                return "Supreme Artifact Master";
            }
        };

        /**
         * Manages artifact mastery system
         */
        class ArtifactMasteryManager
        {
        public:
            virtual ~ArtifactMasteryManager() = default;

            /**
             * Get mastery info for player
             */
            virtual PlayerArtifactMasteryInfo* GetMasteryInfo(uint32 player_guid) = 0;

            /**
             * Award mastery points to player
             */
            virtual void AwardMasteryPoints(uint32 player_guid, uint32 points) = 0;

            /**
             * Increment fully upgraded item counter
             */
            virtual void IncrementFullyUpgradedCount(uint32 player_guid) = 0;

            /**
             * Get mastery leaderboard
             */
            virtual std::vector<PlayerArtifactMasteryInfo> GetMasteryLeaderboard(uint32 limit = 10) = 0;

            /**
             * Get player's mastery rank (1-based)
             */
            virtual uint32 GetPlayerMasteryRank(uint32 player_guid) = 0;
        };

        // =====================================================================
        // Progression Statistics
        // =====================================================================

        /**
         * Detailed progression statistics for a player
         */
        struct ProgressionStatistics
        {
            uint32 player_guid;
            uint32 total_items_upgraded;         // Items that have been upgraded at least once
            uint32 total_upgrades;               // Total number of upgrades applied
            uint32 fully_upgraded_items;         // Items at max level
            uint32 items_per_tier[6];            // Count per tier
            uint32 total_essence_spent;          // Total essence consumed
            uint32 total_tokens_spent;           // Total tokens consumed
            float average_ilvl_gain;             // Average ilvl gain per item
            float average_stat_bonus;            // Average stat multiplier
            uint64 days_active;                  // Days since first upgrade
            uint64 last_activity;                // Last upgrade timestamp

            ProgressionStatistics() :
                player_guid(0), total_items_upgraded(0), total_upgrades(0),
                fully_upgraded_items(0), total_essence_spent(0), total_tokens_spent(0),
                average_ilvl_gain(0.0f), average_stat_bonus(0.0f),
                days_active(0), last_activity(0)
            {
                for (int i = 0; i < 6; ++i)
                    items_per_tier[i] = 0;
            }

            /**
             * Calculate efficiency (upgrades per essence spent)
             */
            float GetEfficiency() const
            {
                return total_essence_spent > 0 ? (float)total_upgrades / total_essence_spent : 0.0f;
            }
        };

    } // namespace ItemUpgrade
} // namespace DarkChaos
