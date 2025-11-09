/*
 * ItemUpgradeStatApplication.cpp
 * 
 * Purpose: Handle stat application and updates for upgraded items
 * Ensures that upgraded item stats are properly applied to players
 * 
 * This module provides the stat update functionality for the item upgrade system.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "ItemUpgradeManager.h"

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Stat Application Implementation
        // =====================================================================

        void ForcePlayerStatUpdate(Player* player)
        {
            if (!player)
                return;

            // Method 1: Update all stats
            // This triggers the stat recalculation for all primary and derived stats
            player->UpdateAllStats();

            // Method 2: Apply all stat bonuses
            // This ensures all bonuses from items, auras, etc. are recalculated
            player->_ApplyAllStatBonuses();

            // Method 3: Update all ratings
            // Ensures combat ratings are recalculated
            player->UpdateAllRatings();

            // Method 4: Update creature data if applicable
            // Ensures client gets updated unit data
            player->UpdateObjectVisibility();

            // Method 5: Trigger item stat update for all equipped items
            // This ensures the item upgrade changes are reflected
            for (int slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            {
                Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                if (item)
                {
                    // Update item display/tooltip by re-applying item enchantments
                    player->ApplyEnchantment(item, PERM_ENCHANTMENT_SLOT, true);
                    player->ApplyEnchantment(item, PERM_ENCHANTMENT_SLOT, false);
                }
            }

            // Optional: Send debug message if enabled
            // ChatHandler(player->GetSession()).SendSysMessage("Stats updated!");
        }

    } // namespace ItemUpgrade
} // namespace DarkChaos

// =====================================================================
// Script Registration
// =====================================================================

void AddSC_ItemUpgradeStatApplication()
{
    // This module is purely functional - no scripts to register
    // It's called for side effects in stat updates
}
