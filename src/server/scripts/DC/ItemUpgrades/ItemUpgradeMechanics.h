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

        // The concrete UpgradeManager interface is declared in ItemUpgradeManager.h.
        // Forward-declare it here so mechanics code can refer to the type without
        // causing duplicate definitions when both headers are included.
        class UpgradeManager;

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
            inline static std::string CreateCostDisplay([[maybe_unused]] uint32 essence_cost, [[maybe_unused]] uint32 token_cost,
                                                [[maybe_unused]] uint32 player_essence, [[maybe_unused]] uint32 player_tokens)
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
