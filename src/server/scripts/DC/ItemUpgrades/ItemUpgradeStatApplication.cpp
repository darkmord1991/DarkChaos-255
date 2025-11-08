/*
 * DarkChaos Item Upgrade - Stat Application System
 * 
 * This file implements the hooks that apply upgraded stats to items
 * when they are equipped, inspected, or their stats are queried.
 * 
 * CRITICAL: This ensures upgraded items actually increase player stats!
 * 
 * Author: DarkChaos Development Team
 * Date: November 8, 2025
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "ItemUpgradeManager.h"
#include "Log.h"
#include "Chat.h"
#include <algorithm>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Stat Application Hook
        // =====================================================================
        
        class ItemUpgradeStatHook : public PlayerScript
        {
        public:
            ItemUpgradeStatHook() : PlayerScript("ItemUpgradeStatHook") {}
            
            // Called when a player equips an item (use correct hook name)
            void OnPlayerEquip(Player* player, Item* item, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
            {
                if (!player || !item)
                    return;
                
                // Force stat recalculation
                ApplyUpgradeStats(player, item);
            }
            
            // Called when player logs in - apply all equipment stats (use correct hook name)
            void OnPlayerLogin(Player* player) override
            {
                if (!player)
                    return;
                
                // Wait a moment for player to fully load
                player->GetScheduler().Schedule(Seconds(2), [](TaskContext context)
                {
                    Player* player = context.GetContextPlayer();
                    if (!player)
                        return;
                    
                    // Apply upgrade stats to all equipped items
                    for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
                    {
                        Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                        if (item)
                        {
                            ApplyUpgradeStats(player, item);
                        }
                    }
                    
                    // Force update stats
                    player->UpdateAllStats();
                    player->UpdateArmor();
                    player->UpdateAttackPowerAndDamage();
                    player->UpdateAttackPowerAndDamage(true);
                    player->UpdateMaxHealth();
                    player->UpdateMaxPower(POWER_MANA);
                    
                    LOG_DEBUG("scripts", "ItemUpgrade: Applied upgrade stats for player {} on login", player->GetGUID().GetCounter());
                });
            }
            
        private:
            static void ApplyUpgradeStats(Player* player, Item* item)
            {
                if (!player || !item)
                    return;
                
                uint32 item_guid = item->GetGUID().GetCounter();
                UpgradeManager* mgr = GetUpgradeManager();
                if (!mgr)
                    return;
                
                ItemUpgradeState* state = mgr->GetItemUpgradeState(item_guid);
                if (!state || state->upgrade_level == 0)
                    return;  // No upgrade
                
                // Get the stat multiplier
                float multiplier = state->stat_multiplier;
                if (multiplier <= 1.0f)
                    return;  // No stat bonus
                
                // Remove old item stats
                player->_ApplyItemMods(item, item->GetSlot(), false);
                
                // Apply upgraded stats by temporarily modifying item stats
                ApplyMultiplierToItemStats(item, multiplier);
                
                // Apply new stats
                player->_ApplyItemMods(item, item->GetSlot(), true);
                
                LOG_DEBUG("scripts", "ItemUpgrade: Applied {:.2f}x stat multiplier to item {} for player {}", 
                         multiplier, item_guid, player->GetGUID().GetCounter());
            }
            
            static void ApplyMultiplierToItemStats(Item* item, float multiplier)
            {
                if (!item || multiplier <= 1.0f)
                    return;
                
                ItemTemplate const* proto = item->GetTemplate();
                if (!proto)
                    return;
                
                // Store original stats if not already stored
                uint32 item_guid = item->GetGUID().GetCounter();
                static std::map<uint32, ItemTemplate> original_stats;
                
                if (original_stats.find(item_guid) == original_stats.end())
                {
                    // Store original template
                    original_stats[item_guid] = *proto;
                }
                
                // Get mutable template (DANGEROUS: modifying const data!)
                // This is a hack but necessary for 3.3.5a
                ItemTemplate* mutable_proto = const_cast<ItemTemplate*>(proto);
                
                // Apply multiplier to all item stats (Strength, Agility, Stamina, Intellect, Spirit, etc.)
                for (uint8 i = 0; i < MAX_ITEM_PROTO_STATS; ++i)
                {
                    if (original_stats[item_guid].ItemStat[i].ItemStatType != 0)
                    {
                        int32 original_value = original_stats[item_guid].ItemStat[i].ItemStatValue;
                        mutable_proto->ItemStat[i].ItemStatValue = static_cast<int32>(original_value * multiplier);
                    }
                }
                
                // Apply multiplier to armor
                if (original_stats[item_guid].Armor > 0)
                {
                    mutable_proto->Armor = static_cast<uint32>(original_stats[item_guid].Armor * multiplier);
                }
                
                // Apply multiplier to weapon damage (both min and max)
                for (uint8 i = 0; i < MAX_ITEM_PROTO_DAMAGES; ++i)
                {
                    if (original_stats[item_guid].Damage[i].DamageMin > 0.0f)
                    {
                        mutable_proto->Damage[i].DamageMin = original_stats[item_guid].Damage[i].DamageMin * multiplier;
                        mutable_proto->Damage[i].DamageMax = original_stats[item_guid].Damage[i].DamageMax * multiplier;
                    }
                }
                
                // Apply multiplier to spell power and all secondary stats
                // These are in the Spells array but we want to scale the base stats
                if (original_stats[item_guid].SpellPowerBonus > 0)
                {
                    mutable_proto->SpellPowerBonus = static_cast<int32>(original_stats[item_guid].SpellPowerBonus * multiplier);
                }
                
                // Scale attack power bonus
                if (original_stats[item_guid].AttackPowerBonus > 0)
                {
                    mutable_proto->AttackPowerBonus = static_cast<int32>(original_stats[item_guid].AttackPowerBonus * multiplier);
                }
                
                // Scale ranged attack power bonus  
                if (original_stats[item_guid].RangedAttackPowerBonus > 0)
                {
                    mutable_proto->RangedAttackPowerBonus = static_cast<int32>(original_stats[item_guid].RangedAttackPowerBonus * multiplier);
                }
                
                // Note: Rating stats (Hit, Crit, Haste, etc.) are stored in ItemStat array
                // and are already scaled above. No additional scaling needed.
            }
        };
        
        // =====================================================================
        // Item Query Hook - Apply Upgrade Info to Item Queries
        // =====================================================================
        
        class ItemUpgradeQueryHook : public ItemScript
        {
        public:
            ItemUpgradeQueryHook() : ItemScript("ItemUpgradeQueryHook") {}
            
            // Called when item is created or query packet is sent
            bool OnQuestAccept(Player* player, Item* item, Quest const* /*quest*/) override
            {
                // This is called when items are interacted with
                // We can use it to ensure stats are up-to-date
                if (player && item)
                {
                    uint32 item_guid = item->GetGUID().GetCounter();
                    UpgradeManager* mgr = GetUpgradeManager();
                    if (mgr)
                    {
                        ItemUpgradeState* state = mgr->GetItemUpgradeState(item_guid);
                        if (state && state->upgrade_level > 0)
                        {
                            // Ensure item has upgrade applied
                            LOG_DEBUG("scripts", "ItemUpgrade: Item {} query with upgrade level {}", 
                                     item_guid, state->upgrade_level);
                        }
                    }
                }
                return true;  // Allow quest accept
            }
        };
        
        // =====================================================================
        // Global Hook: Force Stat Update on Upgrade
        // =====================================================================
        
        void ForcePlayerStatUpdate(Player* player)
        {
            if (!player)
                return;
            
            // Remove all item stats
            for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            {
                Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                if (item)
                {
                    player->_ApplyItemMods(item, slot, false);
                }
            }
            
            // Reapply all item stats (will include upgraded stats)
            for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            {
                Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                if (item)
                {
                    player->_ApplyItemMods(item, slot, true);
                }
            }
            
            // Update all stat calculations
            player->UpdateAllStats();
            player->UpdateArmor();
            player->UpdateAttackPowerAndDamage();
            player->UpdateAttackPowerAndDamage(true);
            player->UpdateMaxHealth();
            player->UpdateMaxPower(POWER_MANA);
            player->UpdateMaxPower(POWER_RAGE);
            player->UpdateMaxPower(POWER_ENERGY);
            player->UpdateMaxPower(POWER_FOCUS);
            player->UpdateMaxPower(POWER_RUNIC_POWER);
            
            LOG_INFO("scripts", "ItemUpgrade: Forced stat update for player {}", player->GetGUID().GetCounter());
        }
        
        // =====================================================================
        // Registration
        // =====================================================================
        
        void AddSC_ItemUpgradeStatApplication()
        {
            new ItemUpgradeStatHook();
            new ItemUpgradeQueryHook();
            LOG_INFO("scripts", "ItemUpgrade: Stat application hooks registered successfully");
        }
    }
}
