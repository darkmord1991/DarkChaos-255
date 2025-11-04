/*
 * DarkChaos Item Upgrade - Item Upgrade Mechanics (Phase 4A)
 * 
 * This header defines the core item upgrade mechanics including:
 * - Item upgrade interface and state management
 * - Cost calculations for upgrades
 * - Stat scaling and multiplier calculations
 * - Item level recalculation
 * - Database persistence layer
 * - UI helpers for displaying upgrade information
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
#include <cmath>
// Include shared manager header for CurrencyType enum and core interfaces
#include "ItemUpgradeManager.h"

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Item Upgrade State & Persistence
        // =====================================================================

        /**
         * Represents the upgrade state of a single item
         * Stores current upgrade level and associated stats
         */
        struct ItemUpgradeState
        {
            uint32 item_guid;                    // Item's unique GUID
            uint32 player_guid;                  // Owner player GUID
            uint8 upgrade_level;                 // Current upgrade level (0 = base, 1-15 = upgraded)
            uint32 essence_invested;             // Total essence spent on this item
            uint32 tokens_invested;              // Total tokens spent on this item
            uint16 base_item_level;              // Original item level
            uint16 upgraded_item_level;          // Current item level after upgrades
            float current_stat_multiplier;       // Current stat scaling multiplier
            uint32 last_upgraded_timestamp;      // When this item was last upgraded
            uint32 season_id;                    // Season when upgrade was made

            ItemUpgradeState() :
                item_guid(0), player_guid(0), upgrade_level(0),
                essence_invested(0), tokens_invested(0),
                base_item_level(0), upgraded_item_level(0),
                current_stat_multiplier(1.0f), last_upgraded_timestamp(0), season_id(1) {}

            // Calculate total cost invested
            uint32 GetTotalCostInvested() const
            {
                return (essence_invested + tokens_invested);
            }

            // Get visual progress percentage (0-100)
            uint8 GetProgressPercentage() const
            {
                return static_cast<uint8>((upgrade_level * 100) / 15);  // Max level 15
            }

            // Check if item is fully upgraded
            bool IsFullyUpgraded() const
            {
                return upgrade_level >= 15;
            }
        };

        // =====================================================================
        // Upgrade Cost Management
        // =====================================================================

        /**
         * Calculates upgrade costs based on item tier and current level
         */
        class UpgradeCostCalculator
        {
        public:
            /**
             * Calculate the essence cost for upgrading an item
             * @param tier_id: Item tier (1-5: common to legendary)
             * @param current_level: Current upgrade level (0-14)
             * @return Essence cost for next upgrade
             */
            static uint32 GetEssenceCost(uint8 tier_id, uint8 current_level)
            {
                if (tier_id < 1 || tier_id > 5 || current_level >= 15)
                    return 0;

                // Base costs per tier: Common=10, Uncommon=25, Rare=50, Epic=100, Legendary=200
                const uint32 base_costs[] = { 0, 10, 25, 50, 100, 200 };
                uint32 base_cost = base_costs[tier_id];

                // Escalation: costs increase by 10% per level
                // Level 0->1: base cost
                // Level 1->2: base * 1.1
                // Level 2->3: base * 1.21, etc.
                float escalation = std::pow(1.1f, current_level);
                return static_cast<uint32>(base_cost * escalation);
            }

            /**
             * Calculate the token cost for upgrading an item
             * @param tier_id: Item tier (1-5)
             * @param current_level: Current upgrade level (0-14)
             * @return Token cost for next upgrade
             */
            static uint32 GetTokenCost(uint8 tier_id, uint8 current_level)
            {
                if (tier_id < 1 || tier_id > 5 || current_level >= 15)
                    return 0;

                // Base token costs per tier
                const uint32 base_costs[] = { 0, 5, 10, 15, 25, 50 };
                uint32 base_cost = base_costs[tier_id];

                // Escalation similar to essence
                float escalation = std::pow(1.1f, current_level);
                return static_cast<uint32>(base_cost * escalation);
            }

            /**
             * Get total cost to reach a specific upgrade level
             * @param tier_id: Item tier
             * @param target_level: Target upgrade level
             * @param out_essence: Output parameter for total essence needed
             * @param out_tokens: Output parameter for total tokens needed
             */
            static void GetCumulativeCost(uint8 tier_id, uint8 target_level,
                                         uint32& out_essence, uint32& out_tokens)
            {
                out_essence = 0;
                out_tokens = 0;

                for (uint8 level = 0; level < target_level && level < 15; ++level)
                {
                    out_essence += GetEssenceCost(tier_id, level);
                    out_tokens += GetTokenCost(tier_id, level);
                }
            }

            /**
             * Get refund amounts for downgrading an item
             * Returns 50% of invested cost
             * @param tier_id: Item tier
             * @param current_level: Current upgrade level
             * @param out_essence: Output essence refund
             * @param out_tokens: Output token refund
             */
            static void GetRefundCost(uint8 tier_id, uint8 current_level,
                                     uint32& out_essence, uint32& out_tokens)
            {
                GetCumulativeCost(tier_id, current_level, out_essence, out_tokens);
                out_essence = out_essence / 2;  // 50% refund
                out_tokens = out_tokens / 2;
            }
        };

        // =====================================================================
        // Stat Scaling & Multipliers
        // =====================================================================

        /**
         * Calculates stat multipliers based on upgrade level and tier
         */
        class StatScalingCalculator
        {
        public:
            /**
             * Get stat multiplier for an upgraded item
             * Each level adds 2.5% to stats (base = 1.0)
             * @param upgrade_level: Current upgrade level
             * @return Multiplier for all stats (1.0 = base, 1.25 = 25% bonus, etc.)
             */
            static float GetStatMultiplier(uint8 upgrade_level)
            {
                if (upgrade_level == 0)
                    return 1.0f;

                // Each level = +2.5% to stats
                // Level 1 = 1.025, Level 2 = 1.050, ... Level 15 = 1.375 (37.5% bonus)
                return 1.0f + (upgrade_level * 0.025f);
            }

            /**
             * Get tier-specific multiplier adjustments
             * Higher tiers scale better with upgrades
             * @param tier_id: Item tier (1-5)
             * @return Multiplier adjustment (1.0 = normal scaling)
             */
            static float GetTierMultiplier(uint8 tier_id)
            {
                // Common/Uncommon: 0.9x (90% scaling)
                // Rare: 1.0x (100% scaling - normal)
                // Epic: 1.15x (115% scaling)
                // Legendary: 1.25x (125% scaling)
                const float tier_mults[] = { 0.0f, 0.9f, 0.95f, 1.0f, 1.15f, 1.25f };
                return tier_id >= 1 && tier_id <= 5 ? tier_mults[tier_id] : 1.0f;
            }

            /**
             * Calculate combined stat multiplier
             * @param upgrade_level: Current upgrade level
             * @param tier_id: Item tier
             * @return Final multiplier combining both bonuses
             */
            static float GetFinalMultiplier(uint8 upgrade_level, uint8 tier_id)
            {
                float base_mult = GetStatMultiplier(upgrade_level);
                float tier_mult = GetTierMultiplier(tier_id);
                
                // Combined multiplier (always at least 1.0)
                float result = (base_mult - 1.0f) * tier_mult + 1.0f;
                return std::max(1.0f, result);
            }

            /**
             * Get visual representation of stat bonus
             * @param upgrade_level: Current upgrade level
             * @param tier_id: Item tier
             * @return Percentage bonus (e.g., "25%" for 1.25 multiplier)
             */
            static std::string GetStatBonusDisplay(uint8 upgrade_level, uint8 tier_id)
            {
                float mult = GetFinalMultiplier(upgrade_level, tier_id);
                int percentage = static_cast<int>((mult - 1.0f) * 100);
                return std::to_string(percentage) + "%";
            }
        };

        // =====================================================================
        // Item Level Calculations
        // =====================================================================

        /**
         * Calculates item level bonuses from upgrades
         */
        class ItemLevelCalculator
        {
        public:
            /**
             * Get item level bonus from upgrade level
             * Each upgrade level adds 1-2 ilvl based on tier
             * @param upgrade_level: Current upgrade level
             * @param tier_id: Item tier
             * @return Item level bonus
             */
            static uint16 GetItemLevelBonus(uint8 upgrade_level, uint8 tier_id)
            {
                if (upgrade_level == 0)
                    return 0;

                // Common: +1 ilvl per level = +15 max
                // Uncommon: +1 ilvl per level = +15 max
                // Rare: +1.5 ilvl per level = +22 max
                // Epic: +2 ilvl per level = +30 max
                // Legendary: +2.5 ilvl per level = +37 max
                const float bonus_per_level[] = { 0.0f, 1.0f, 1.0f, 1.5f, 2.0f, 2.5f };
                float multiplier = tier_id >= 1 && tier_id <= 5 ? bonus_per_level[tier_id] : 1.0f;

                return static_cast<uint16>(upgrade_level * multiplier);
            }

            /**
             * Calculate upgraded item level
             * @param base_ilvl: Base item level
             * @param upgrade_level: Current upgrade level
             * @param tier_id: Item tier
             * @return New item level
             */
            static uint16 GetUpgradedItemLevel(uint16 base_ilvl, uint8 upgrade_level, uint8 tier_id)
            {
                return base_ilvl + GetItemLevelBonus(upgrade_level, tier_id);
            }

            /**
             * Get display string for item level bonus
             * @param base_ilvl: Base item level
             * @param current_ilvl: Current item level
             * @return Display string (e.g., "385 -> 402")
             */
            static std::string GetItemLevelDisplay(uint16 base_ilvl, uint16 current_ilvl)
            {
                return std::to_string(base_ilvl) + " -> " + std::to_string(current_ilvl);
            }
        };

        // =====================================================================
        // Upgrade Manager Interface Extension
        // =====================================================================

        /**
         * Extended upgrade manager interface with mechanics methods
         * Implements Phase 4A functionality
         */
        class UpgradeManager
        {
        public:
            virtual ~UpgradeManager() = default;

            // Phase 3 methods (existing)
            virtual bool UpgradeItem(uint32 player_guid, uint32 item_guid) = 0;
            virtual bool AddCurrency(uint32 player_guid, CurrencyType currency, uint32 amount, uint32 season = 1) = 0;
            virtual bool RemoveCurrency(uint32 player_guid, CurrencyType currency, uint32 amount, uint32 season = 1) = 0;
            virtual uint32 GetCurrency(uint32 player_guid, CurrencyType currency, uint32 season = 1) = 0;

            // Phase 4A methods (new)
            
            /**
             * Get upgrade state for an item
             */
            virtual ItemUpgradeState* GetItemUpgradeState(uint32 item_guid) = 0;

            /**
             * Perform an item upgrade
             * @param player_guid: Player GUID
             * @param item_guid: Item GUID
             * @param essence_cost: Essence to consume
             * @param token_cost: Tokens to consume
             * @return true if upgrade successful
             */
            virtual bool PerformItemUpgrade(uint32 player_guid, uint32 item_guid,
                                           uint32 essence_cost, uint32 token_cost) = 0;

            /**
             * Get tier ID for an item
             * @param item_id: Item entry ID
             * @return Tier ID (1-5) or 0 if not upgradeable
             */
            virtual uint8 GetItemTier(uint32 item_id) = 0;

            /**
             * Check if item can be upgraded
             * @param item_guid: Item GUID
             * @param player_guid: Player GUID
             * @return true if item can be upgraded further
             */
            virtual bool CanUpgradeItem(uint32 item_guid, uint32 player_guid) = 0;

            /**
             * Get next upgrade cost
             * @param item_guid: Item GUID
             * @param out_essence: Output essence cost
             * @param out_tokens: Output token cost
             * @return true if costs calculated
             */
            virtual bool GetNextUpgradeCost(uint32 item_guid,
                                          uint32& out_essence, uint32& out_tokens) = 0;

            /**
             * Save item upgrade state to database
             */
            virtual void SaveItemUpgradeState(uint32 item_guid) = 0;

            /**
             * Load item upgrade state from database
             */
            virtual void LoadItemUpgradeState(uint32 item_guid) = 0;

            /**
             * Get refund values for item
             */
            virtual void GetDowngradeRefund(uint32 item_guid,
                                           uint32& out_essence, uint32& out_tokens) = 0;

            /**
             * Downgrade an item (reset upgrades)
             */
            virtual bool DowngradeItem(uint32 player_guid, uint32 item_guid) = 0;
        };

        // =====================================================================
        // UI Display Helpers (Phase 4A)
        // =====================================================================

        namespace UI
        {
            /**
             * Create an upgrade display showing current stats
             */
            static std::string CreateUpgradeDisplay(const ItemUpgradeState& state, uint8 tier_id)
            {
                std::ostringstream ss;
                
                float current_mult = StatScalingCalculator::GetFinalMultiplier(state.upgrade_level, tier_id);
                uint16 upgraded_ilvl = ItemLevelCalculator::GetUpgradedItemLevel(
                    state.base_item_level, state.upgrade_level, tier_id);

                ss << "|cff00ff00Upgrade Level: " << static_cast<int>(state.upgrade_level) << "/15|r\n";
                ss << "|cffffffff Item Level: " << state.base_item_level << " -> " << upgraded_ilvl << "|r\n";
                ss << "|cffffff00Stat Bonus: " << std::fixed << std::setprecision(1) 
                   << (current_mult - 1.0f) * 100 << "%|r\n";
                ss << "|cffccccccInvested: " << state.tokens_invested << " Tokens, "
                   << state.essence_invested << " Essence|r\n";

                return ss.str();
            }

            /**
             * Create upgrade cost display
             */
            static std::string CreateCostDisplay(uint32 essence_cost, uint32 token_cost,
                                                uint32 player_essence, uint32 player_tokens)
            {
                std::ostringstream ss;
                bool can_afford_essence = (player_essence >= essence_cost);
                bool can_afford_tokens = (player_tokens >= token_cost);
                bool can_afford_all = can_afford_essence && can_afford_tokens;

                std::string color_essence = can_afford_essence ? "|cff00ff00" : "|cffff0000";
                std::string color_tokens = can_afford_tokens ? "|cff00ff00" : "|cffff0000";

                ss << color_essence << "Essence: " << player_essence << " / " << essence_cost << "|r\n";
                ss << color_tokens << "Tokens: " << player_tokens << " / " << token_cost << "|r\n";
                
                if (!can_afford_all)
                    ss << "|cffff0000Insufficient resources|r";

                return ss.str();
            }
        }

    } // namespace ItemUpgrade
} // namespace DarkChaos
