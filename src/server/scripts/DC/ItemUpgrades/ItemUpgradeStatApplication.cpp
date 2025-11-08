/*
 * DarkChaos Item Upgrade - Stat Application System (Enchantment-Based)
 * 
 * This file implements stat scaling using the enchantment system.
 * When items are equipped, a temporary enchantment is applied that grants
 * bonus stats based on the item's upgrade level and tier.
 * 
 * APPROACH: Hybrid Solution
 * - Base stats: Scaled via temporary enchantments
 * - Proc effects: Scaled via UnitScript hooks (see ItemUpgradeProcScaling.cpp)
 * 
 * Author: DarkChaos Development Team
 * Date: November 8, 2025
 * Version: 2.0 (Enchantment-based)
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "ItemUpgradeManager.h"
#include "SpellMgr.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include <algorithm>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Enchantment ID Calculator
        // =====================================================================
        
        uint32 GetUpgradeEnchantId(uint8 tier_id, uint8 upgrade_level)
        {
            // Enchant ID format: 80000 + (tier * 100) + level
            // Example: Tier 3 Level 10 = 80310
            if (tier_id < 1 || tier_id > 5 || upgrade_level < 1 || upgrade_level > 15)
                return 0;
            
            return 80000 + (tier_id * 100) + upgrade_level;
        }
        
        // =====================================================================
        // Stat Application Hook (Enchantment-Based)
        // =====================================================================
        
        class ItemUpgradeStatHook : public PlayerScript
        {
        public:
            ItemUpgradeStatHook() : PlayerScript("ItemUpgradeStatHook") {}
            
            // Called when a player equips an item
            void OnPlayerEquip(Player* player, Item* item, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
            {
                if (!player || !item)
                    return;
                
                ApplyUpgradeEnchant(player, item);
            }
            
            // Called when player logs in - apply enchants to all equipped items
            void OnPlayerLogin(Player* player) override
            {
                if (!player)
                    return;
                
                // Apply upgrade enchants to all equipped items immediately
                // AzerothCore loads items before OnPlayerLogin, so they're ready
                for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
                {
                    Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                    if (item)
                    {
                        ApplyUpgradeEnchant(player, item);
                    }
                }
                
                LOG_DEBUG("scripts", "ItemUpgrade: Applied enchants to all equipment for player {} on login",
                         player->GetGUID().GetCounter());
            }
            
        private:
            static void ApplyUpgradeEnchant(Player* player, Item* item)
            {
                if (!player || !item)
                    return;
                
                uint32 item_guid = item->GetGUID().GetCounter();
                UpgradeManager* mgr = GetUpgradeManager();
                if (!mgr)
                    return;
                
                // Remove any existing upgrade enchant first
                RemoveUpgradeEnchant(player, item);
                
                // Get upgrade state from database
                ItemUpgradeState* state = mgr->GetItemUpgradeState(item_guid);
                if (!state || state->upgrade_level == 0)
                    return;  // No upgrade
                
                // Calculate enchant ID
                uint32 enchant_id = GetUpgradeEnchantId(static_cast<uint8>(state->tier_id), 
                                                        static_cast<uint8>(state->upgrade_level));
                if (enchant_id == 0)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Invalid enchant ID for tier {} level {}", 
                             state->tier_id, state->upgrade_level);
                    return;
                }
                
                // Verify enchant exists in database
                if (!VerifyEnchantExists(enchant_id))
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Enchant {} not found in dc_item_upgrade_enchants table - "
                             "tier {}, level {}. Skipping enchant application.", 
                             enchant_id, state->tier_id, state->upgrade_level);
                    return;
                }
                
                // Log before applying to help debug
                LOG_INFO("scripts", "ItemUpgrade: Attempting to apply enchant {} to item {} (guid={}) for player {}. "
                        "Tier={}, Level={}, CurrentMultiplier={}",
                        enchant_id, item->GetEntry(), item_guid, player->GetGUID().GetCounter(),
                        state->tier_id, state->upgrade_level, state->stat_multiplier);
                
                // Apply enchant to TEMP_ENCHANTMENT_SLOT
                item->SetEnchantment(TEMP_ENCHANTMENT_SLOT, enchant_id, 0, 0);
                player->ApplyEnchantment(item, TEMP_ENCHANTMENT_SLOT, true);
                
                // Verify enchant was actually applied
                uint32 applied_enchant = item->GetEnchantmentId(TEMP_ENCHANTMENT_SLOT);
                if (applied_enchant == enchant_id)
                {
                    LOG_DEBUG("scripts", "ItemUpgrade: Successfully applied enchant {} to item {}", 
                             enchant_id, item_guid);
                }
                else
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Failed to apply enchant {}! Item has enchant {} instead",
                             enchant_id, applied_enchant);
                }
            }
            
            static void RemoveUpgradeEnchant(Player* player, Item* item)
            {
                if (!player || !item)
                    return;
                
                // Check if item has an upgrade enchant (IDs 80001-80599)
                for (EnchantmentSlot slot = PERM_ENCHANTMENT_SLOT; slot < MAX_INSPECTED_ENCHANTMENT_SLOT; 
                     slot = EnchantmentSlot(slot + 1))
                {
                    uint32 enchant_id = item->GetEnchantmentId(slot);
                    if (enchant_id >= 80001 && enchant_id <= 80599)
                    {
                        player->ApplyEnchantment(item, slot, false);
                        item->ClearEnchantment(slot);
                        LOG_DEBUG("scripts", "ItemUpgrade: Removed enchant {} from item {}",
                                 enchant_id, item->GetGUID().GetCounter());
                    }
                }
            }
            
            static bool VerifyEnchantExists(uint32 enchant_id)
            {
                // Cache verified enchants to avoid repeated DB queries
                static std::unordered_set<uint32> verified_enchants;
                
                if (verified_enchants.find(enchant_id) != verified_enchants.end())
                    return true;
                
                // Check database
                QueryResult result = WorldDatabase.Query(
                    "SELECT 1 FROM dc_item_upgrade_enchants WHERE enchant_id = {}", 
                    enchant_id);
                
                if (result)
                {
                    verified_enchants.insert(enchant_id);
                    return true;
                }
                
                return false;
            }
        };
        
        // =====================================================================
        // Global Helper: Force Enchant Update After Upgrade
        // =====================================================================
        
        void ForcePlayerStatUpdate(Player* player)
        {
            if (!player)
                return;
            
            // Reapply enchants to all equipped items
            for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            {
                Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                if (item)
                {
                    // Remove old enchant
                    for (EnchantmentSlot enchSlot = PERM_ENCHANTMENT_SLOT; 
                         enchSlot < MAX_INSPECTED_ENCHANTMENT_SLOT; 
                         enchSlot = EnchantmentSlot(enchSlot + 1))
                    {
                        uint32 enchant_id = item->GetEnchantmentId(enchSlot);
                        if (enchant_id >= 80001 && enchant_id <= 80599)
                        {
                            player->ApplyEnchantment(item, enchSlot, false);
                            item->ClearEnchantment(enchSlot);
                        }
                    }
                    
                    // Reapply based on current upgrade state
                    uint32 item_guid = item->GetGUID().GetCounter();
                    UpgradeManager* mgr = GetUpgradeManager();
                    if (mgr)
                    {
                        ItemUpgradeState* state = mgr->GetItemUpgradeState(item_guid);
                        if (state && state->upgrade_level > 0)
                        {
                            uint32 enchant_id = GetUpgradeEnchantId(
                                static_cast<uint8>(state->tier_id),
                                static_cast<uint8>(state->upgrade_level));
                            
                            if (enchant_id > 0)
                            {
                                item->SetEnchantment(TEMP_ENCHANTMENT_SLOT, enchant_id, 0, 0);
                                player->ApplyEnchantment(item, TEMP_ENCHANTMENT_SLOT, true);
                            }
                        }
                    }
                }
            }
            
            // Update all stats
            player->UpdateAllStats();
            player->UpdateArmor();
            player->UpdateAttackPowerAndDamage();
            player->UpdateAttackPowerAndDamage(true);
            player->UpdateMaxHealth();
            player->UpdateMaxPower(POWER_MANA);
            
            LOG_INFO("scripts", "ItemUpgrade: Forced enchant update for player {}", 
                     player->GetGUID().GetCounter());
        }
        
        // =====================================================================
        // Registration
        // =====================================================================
        
    } // namespace ItemUpgrade
} // namespace DarkChaos

// Registration function must be in global namespace for dc_script_loader.cpp
void AddSC_ItemUpgradeStatApplication()
{
    try
    {
        new DarkChaos::ItemUpgrade::ItemUpgradeStatHook();
        LOG_INFO("scripts", "ItemUpgrade: Stat application hooks registered successfully (enchantment-based)");
    }
    catch (const std::exception& e)
    {
        LOG_ERROR("scripts", "ItemUpgrade: Failed to register stat application hooks: {}", e.what());
    }
}
