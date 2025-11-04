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
// Forward-declare CurrencyType to avoid pulling in full manager header and
// prevent duplicate type/struct definitions when both headers are included
// in the same translation unit.
enum CurrencyType : uint8;

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Item Upgrade State & Persistence
        // =====================================================================

        // Forward-declare ItemUpgradeState to avoid duplicate definitions across headers.
        // The canonical definition lives in ItemUpgradeManager.h.
        struct ItemUpgradeState;

        // =====================================================================
        // Upgrade Cost Management
        // =====================================================================

        /**
         * Calculates upgrade costs based on item tier and current level
         */
        class UpgradeCostCalculator
        {
        public:
            static uint32 GetEssenceCost(uint8 tier_id, uint8 current_level);
            static uint32 GetTokenCost(uint8 tier_id, uint8 current_level);
            static void GetCumulativeCost(uint8 tier_id, uint8 target_level,
                                          uint32& out_essence, uint32& out_tokens);
            static void GetRefundCost(uint8 tier_id, uint8 current_level,
                                      uint32& out_essence, uint32& out_tokens);
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
            static float GetStatMultiplier(uint8 upgrade_level);
            static float GetTierMultiplier(uint8 tier_id);
            static float GetFinalMultiplier(uint8 upgrade_level, uint8 tier_id);
            static std::string GetStatBonusDisplay(uint8 upgrade_level, uint8 tier_id);
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
            static uint16 GetItemLevelBonus(uint8 upgrade_level, uint8 tier_id);
            static uint16 GetUpgradedItemLevel(uint16 base_ilvl, uint8 upgrade_level, uint8 tier_id);
            static std::string GetItemLevelDisplay(uint16 base_ilvl, uint16 current_ilvl);
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
            // Create an upgrade display; implemented in the .cpp to avoid depending on
            // the concrete ItemUpgradeState definition in this header.
            std::string CreateUpgradeDisplay(const ItemUpgradeState& state, uint8 tier_id);

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
