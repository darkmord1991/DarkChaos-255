/*
 * DarkChaos Item Upgrade - Advanced Features (Phase 4D)
 *
 * This header defines advanced features including:
 * - Cross-spec optimization and loadouts
 * - Transmog integration
 * - Achievement system
 * - Item trading with upgrade preservation
 * - Respec costs and mechanics
 * - Guild progression tracking
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
#include <unordered_map>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Spec-Based Optimization
        // =====================================================================

        /**
         * Represents a stat optimization loadout for a specific spec
         */
        struct StatLoadout
        {
            uint32 loadout_id;
            uint32 player_guid;
            uint8 spec_id;                       // Spec (0-2 typically)
            std::string loadout_name;            // Custom name
            std::map<uint32, uint8> item_upgrades;  // Item GUID -> Upgrade Level
            std::map<std::string, int> stat_weights;  // Stat -> Weight (for optimization)
            uint32 created_timestamp;
            uint32 last_used_timestamp;
            bool is_active;                      // Currently active loadout?

            StatLoadout() :
                loadout_id(0), player_guid(0), spec_id(0),
                created_timestamp(0), last_used_timestamp(0), is_active(false) {}

            /**
             * Get stat weight for a specific stat
             */
            int GetStatWeight(const std::string& stat) const
            {
                auto it = stat_weights.find(stat);
                return it != stat_weights.end() ? it->second : 0;
            }

            /**
             * Set stat weight
             */
            void SetStatWeight(const std::string& stat, int weight)
            {
                stat_weights[stat] = weight;
            }
        };

        /**
         * Manages optimization loadouts
         */
        class OptimizationManager
        {
        public:
            virtual ~OptimizationManager() = default;

            /**
             * Create a new loadout
             */
            virtual uint32 CreateLoadout(const StatLoadout& loadout) = 0;

            /**
             * Get player's loadouts
             */
            virtual std::vector<StatLoadout> GetPlayerLoadouts(uint32 player_guid) = 0;

            /**
             * Get active loadout for player
             */
            virtual StatLoadout* GetActiveLoadout(uint32 player_guid) = 0;

            /**
             * Switch to a loadout
             */
            virtual bool SwitchLoadout(uint32 player_guid, uint32 loadout_id) = 0;

            /**
             * Auto-optimize loadout based on stat weights
             */
            virtual void AutoOptimizeLoadout(uint32 loadout_id) = 0;

            /**
             * Calculate total stat bonus for loadout
             */
            virtual float CalculateTotalStatBonus(const StatLoadout& loadout) = 0;

            /**
             * Save loadout to database
             */
            virtual void SaveLoadout(const StatLoadout& loadout) = 0;
        };

        // =====================================================================
        // Transmog Integration
        // =====================================================================

        /**
         * Transmog preset linked with upgrades
         */
        struct UpgradeTransmogPreset
        {
            uint32 preset_id;
            uint32 player_guid;
            std::string preset_name;
            std::map<uint32, uint32> item_display_map;  // Slot -> Display Item ID
            std::map<uint32, uint8> item_upgrades;      // Item -> Upgrade Level
            bool preserve_on_transmog;           // Keep upgrades when transmog changing?
            uint32 created_timestamp;

            UpgradeTransmogPreset() :
                preset_id(0), player_guid(0), preserve_on_transmog(true),
                created_timestamp(0) {}
        };

        /**
         * Manages transmog integration with upgrades
         */
        class TransmogManager
        {
        public:
            virtual ~TransmogManager() = default;

            /**
             * Create transmog preset
             */
            virtual uint32 CreateTransmogPreset(const UpgradeTransmogPreset& preset) = 0;

            /**
             * Get player's transmog presets
             */
            virtual std::vector<UpgradeTransmogPreset> GetTransmogPresets(uint32 player_guid) = 0;

            /**
             * Apply transmog preset
             */
            virtual bool ApplyTransmogPreset(uint32 player_guid, uint32 preset_id) = 0;

            /**
             * Check if upgrade is preserved on transmog
             */
            virtual bool WillUpgradesTransmog(uint32 source_item, uint32 target_item) = 0;

            /**
             * Transfer upgrades from one item to another
             */
            virtual bool TransferUpgrades(uint32 source_item_guid, uint32 target_item_guid) = 0;
        };

        // =====================================================================
        // Achievement System
        // =====================================================================

        /**
         * Custom upgrade achievement definition
         */
        struct UpgradeAchievement
        {
            uint32 achievement_id;
            std::string name;
            std::string description;
            uint32 reward_prestige_points;
            uint32 reward_tokens;
            bool is_hidden;                      // Hidden until earned?
            uint32 unlock_requirement;           // What must be completed?
            std::string unlock_type;             // Type of requirement

            UpgradeAchievement() :
                achievement_id(0), reward_prestige_points(0),
                reward_tokens(0), is_hidden(false), unlock_requirement(0) {}
        };

        /**
         * Manages upgrade achievements
         */
        class AchievementManager
        {
        public:
            virtual ~AchievementManager() = default;

            /**
             * Get all achievements
             */
            virtual std::vector<UpgradeAchievement> GetAllAchievements() = 0;

            /**
             * Check if player has achievement
             */
            virtual bool PlayerHasAchievement(uint32 player_guid, uint32 achievement_id) = 0;

            /**
             * Award achievement to player
             */
            virtual void AwardAchievement(uint32 player_guid, uint32 achievement_id) = 0;

            /**
             * Get player's achievements
             */
            virtual std::vector<UpgradeAchievement> GetPlayerAchievements(uint32 player_guid) = 0;

            /**
             * Check achievement progress
             */
            virtual uint32 GetAchievementProgress(uint32 player_guid, uint32 achievement_id) = 0;

            /**
             * Define new achievement
             */
            virtual void DefineAchievement(const UpgradeAchievement& achievement) = 0;

            /**
             * Check and award achievements (called after upgrades)
             */
            virtual void CheckAndAwardAchievements(uint32 player_guid) = 0;
        };

        // =====================================================================
        // Item Trading
        // =====================================================================

        /**
         * Configuration for trading mechanics
         */
        struct TradingConfig
        {
            bool allow_upgrade_trading;          // Can upgrades be traded?
            bool preserve_upgrades_on_trade;     // Do upgrades transfer?
            uint32 trade_tax_percent;            // Tax on trades (%)
            uint32 min_level_to_trade;           // Minimum upgrade level to trade
            bool require_same_ilvl;              // Both items must be same ilvl?
            uint32 cooldown_minutes;             // Cooldown between trades

            TradingConfig() :
                allow_upgrade_trading(true), preserve_upgrades_on_trade(true),
                trade_tax_percent(10), min_level_to_trade(3),
                require_same_ilvl(false), cooldown_minutes(60) {}
        };

        /**
         * Trade record
         */
        struct TradeRecord
        {
            uint32 trade_id;
            uint32 player_from;
            uint32 player_to;
            uint32 item_from_guid;
            uint32 item_to_guid;
            uint32 upgrade_level_transferred;
            uint64 timestamp;
            bool was_taxed;
            uint32 tax_amount;

            TradeRecord() :
                trade_id(0), player_from(0), player_to(0),
                item_from_guid(0), item_to_guid(0),
                upgrade_level_transferred(0), timestamp(0),
                was_taxed(false), tax_amount(0) {}
        };

        /**
         * Manages item trading with upgrades
         */
        class TradingManager
        {
        private:
            TradingConfig config;

        public:
            TradingManager() = default;

            /**
             * Can player trade this item?
             */
            virtual bool CanTradeItem(uint32 player_guid, uint32 item_guid) = 0;

            /**
             * Execute a trade
             */
            virtual bool ExecuteTrade(uint32 player_from, uint32 item_from_guid,
                                     uint32 player_to, uint32 item_to_guid) = 0;

            /**
             * Get trade history for player
             */
            virtual std::vector<TradeRecord> GetTradeHistory(uint32 player_guid, uint32 limit = 50) = 0;

            /**
             * Check trade cooldown
             */
            virtual bool CanTradeAgain(uint32 player_guid) = 0;

            /**
             * Get configuration
             */
            const TradingConfig& GetConfig() const { return config; }
        };

        // =====================================================================
        // Respec System
        // =====================================================================

        /**
         * Respec configuration
         */
        struct RespecConfig
        {
            bool allow_full_respec;              // Can player reset all upgrades?
            uint32 respec_cost_tokens;           // Cost to respec
            uint32 respec_cost_essence;          // Cost to respec
            uint32 partial_respec_cost;          // Cost per item respec
            uint32 daily_respec_limit;           // How many respecs per day?
            bool refund_on_respec;               // Get resources back?
            uint32 refund_percent;               // How much refunded (%)

            RespecConfig() :
                allow_full_respec(true), respec_cost_tokens(1000),
                respec_cost_essence(500), partial_respec_cost(100),
                daily_respec_limit(3), refund_on_respec(true),
                refund_percent(50) {}
        };

        /**
         * Manages respec/reset mechanics
         */
        class RespecManager
        {
        private:
            RespecConfig config;

        public:
            RespecManager() = default;

            /**
             * Can player respec?
             */
            virtual bool CanRespec(uint32 player_guid) = 0;

            /**
             * Respec a single item
             */
            virtual bool RespecItem(uint32 player_guid, uint32 item_guid) = 0;

            /**
             * Full respec - reset all items
             */
            virtual bool RespecAll(uint32 player_guid) = 0;

            /**
             * Get respec cooldown
             */
            virtual uint32 GetRespecCooldown(uint32 player_guid) = 0;

            /**
             * Get respec count today
             */
            virtual uint32 GetRespecCountToday(uint32 player_guid) = 0;

            /**
             * Calculate respec cost
             */
            virtual void CalculateRespecCost(uint32 player_guid, bool full_respec,
                                            uint32& out_tokens, uint32& out_essence) = 0;

            /**
             * Get configuration
             */
            const RespecConfig& GetConfig() const { return config; }
        };

        // =====================================================================
        // Guild Progression
        // =====================================================================

        /**
         * Guild-wide upgrade statistics
         */
        struct GuildUpgradeStats
        {
            uint32 guild_id;
            std::string guild_name;
            uint32 total_members;
            uint32 members_with_upgrades;        // Members who have upgraded items
            uint32 total_guild_upgrades;         // Total upgrades across guild
            uint32 total_items_upgraded;         // Total items across guild
            float average_ilvl_increase;         // Average ilvl gain
            uint32 total_essence_invested;       // Guild-wide essence spent
            uint32 total_tokens_invested;        // Guild-wide tokens spent
            uint64 last_updated;

            GuildUpgradeStats() :
                guild_id(0), total_members(0), members_with_upgrades(0),
                total_guild_upgrades(0), total_items_upgraded(0),
                average_ilvl_increase(0.0f), total_essence_invested(0),
                total_tokens_invested(0), last_updated(0) {}
        };

        /**
         * Manages guild progression
         */
        class GuildProgressionManager
        {
        public:
            virtual ~GuildProgressionManager() = default;

            /**
             * Get guild statistics
             */
            virtual GuildUpgradeStats GetGuildStats(uint32 guild_id) = 0;

            /**
             * Update guild stats
             */
            virtual void UpdateGuildStats(uint32 guild_id) = 0;

            /**
             * Get guild leaderboard
             */
            virtual std::vector<GuildUpgradeStats> GetGuildLeaderboard(uint32 limit = 10) = 0;

            /**
             * Award guild bonuses based on progression
             */
            virtual void AwardGuildBonuses(uint32 guild_id) = 0;

            /**
             * Get guild progression tier
             */
            virtual uint8 GetGuildTier(uint32 guild_id) = 0;
        };

        // =====================================================================
        // Factory Functions
        // =====================================================================

        OptimizationManager* GetOptimizationManager();
        TransmogManager* GetTransmogManager();
        AchievementManager* GetAchievementManager();
        TradingManager* GetTradingManager();
        RespecManager* GetRespecManager();
        GuildProgressionManager* GetGuildProgressionManager();

    } // namespace ItemUpgrade
} // namespace DarkChaos
