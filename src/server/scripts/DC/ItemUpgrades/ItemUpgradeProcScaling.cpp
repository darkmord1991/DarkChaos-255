/*
 * DarkChaos Item Upgrade - Proc Scaling System (UnitScript Hook-Based)
 * 
 * This file implements proc effect scaling using UnitScript hooks.
 * Damage/healing from item procs is scaled based on the player's equipped
 * upgraded items.
 * 
 * APPROACH: Hybrid Solution
 * - Base stats: Scaled via enchantments (see ItemUpgradeStatApplication.cpp)
 * - Proc effects: Scaled via UnitScript damage/heal hooks
 * 
 * Author: DarkChaos Development Team
 * Date: November 8, 2025
 * Version: 2.0 (UnitScript hook-based)
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "Unit.h"
#include "ItemUpgradeManager.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include <unordered_set>
#include <unordered_map>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Item Proc Spell Database
        // =====================================================================
        
        // Cache of known item proc spell IDs
        class ProcSpellDatabase
        {
        private:
            static std::unordered_set<uint32> proc_spell_ids;
            static bool initialized;
            
        public:
            static void Initialize()
            {
                if (initialized)
                    return;
                
                LOG_INFO("scripts", "ItemUpgrade: Loading item proc spells from database...");
                
                try
                {
                    // Load from database
                    QueryResult result = WorldDatabase.Query("SELECT spell_id FROM dc_item_proc_spells");
                    if (result)
                    {
                        do {
                            proc_spell_ids.insert((*result)[0].Get<uint32>());
                        } while (result->NextRow());
                        
                        LOG_INFO("scripts", "ItemUpgrade: Loaded {} item proc spells from database", proc_spell_ids.size());
                    }
                    else
                    {
                        LOG_WARN("scripts", "ItemUpgrade: No proc spells found in database, using hardcoded list");
                        LoadHardcodedProcSpells();
                    }
                }
                catch (...)
                {
                    LOG_ERROR("scripts", "ItemUpgrade: Failed to load proc spells from database (table missing?), using hardcoded list");
                    LoadHardcodedProcSpells();
                }
                
                initialized = true;
            }
            
            static bool IsItemProcSpell(uint32 spell_id)
            {
                if (!initialized)
                    Initialize();
                
                return proc_spell_ids.find(spell_id) != proc_spell_ids.end();
            }
            
        private:
            static void LoadHardcodedProcSpells()
            {
                // Common WotLK item proc spells (fallback list)
                // Trinket procs
                proc_spell_ids.insert(71484);  // Deathbringer's Will (Str)
                proc_spell_ids.insert(71485);  // Deathbringer's Will (Agi)
                proc_spell_ids.insert(71492);  // Deathbringer's Will (AP)
                proc_spell_ids.insert(60065);  // Tears of the Vanquished (Ulduar trinket)
                proc_spell_ids.insert(64741);  // Mjolnir Runestone
                proc_spell_ids.insert(64713);  // Banner of Victory
                
                // Weapon procs
                proc_spell_ids.insert(59620);  // Berserking (weapon proc)
                proc_spell_ids.insert(60314);  // Pyrite Infusion
                proc_spell_ids.insert(60437);  // Blood Presence
                
                LOG_INFO("scripts", "ItemUpgrade: Loaded {} hardcoded proc spells", proc_spell_ids.size());
            }
        };
        
        std::unordered_set<uint32> ProcSpellDatabase::proc_spell_ids;
        bool ProcSpellDatabase::initialized = false;
        
        // =====================================================================
        // Multiplier Calculator
        // =====================================================================
        
        float GetPlayerAvgProcMultiplier(Player* player)
        {
            if (!player)
                return 1.0f;
            
            UpgradeManager* mgr = GetUpgradeManager();
            if (!mgr)
                return 1.0f;
            
            float total_multiplier = 0.0f;
            uint32 upgraded_items = 0;
            
            // Calculate average multiplier from all equipped upgraded items
            for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            {
                Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                if (!item)
                    continue;
                
                ItemUpgradeState* state = mgr->GetItemUpgradeState(item->GetGUID().GetCounter());
                if (state && state->upgrade_level > 0)
                {
                    total_multiplier += state->stat_multiplier;
                    upgraded_items++;
                }
            }
            
            if (upgraded_items == 0)
                return 1.0f;
            
            // Return average multiplier
            return total_multiplier / upgraded_items;
        }
        
        float GetPlayerWeaponProcMultiplier(Player* player)
        {
            if (!player)
                return 1.0f;
            
            UpgradeManager* mgr = GetUpgradeManager();
            if (!mgr)
                return 1.0f;
            
            float mh_mult = 1.0f;
            float oh_mult = 1.0f;
            uint32 weapon_count = 0;
            
            // Main-hand weapon
            Item* mainhand = player->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_MAINHAND);
            if (mainhand)
            {
                ItemUpgradeState* state = mgr->GetItemUpgradeState(mainhand->GetGUID().GetCounter());
                if (state && state->upgrade_level > 0)
                {
                    mh_mult = state->stat_multiplier;
                    weapon_count++;
                }
            }
            
            // Off-hand weapon
            Item* offhand = player->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_OFFHAND);
            if (offhand && offhand->GetTemplate()->InventoryType == INVTYPE_WEAPON)
            {
                ItemUpgradeState* state = mgr->GetItemUpgradeState(offhand->GetGUID().GetCounter());
                if (state && state->upgrade_level > 0)
                {
                    oh_mult = state->stat_multiplier;
                    weapon_count++;
                }
            }
            
            if (weapon_count == 0)
                return 1.0f;
            
            // Return average
            return (mh_mult + oh_mult) / std::max(1u, weapon_count);
        }
        
        // =====================================================================
        // UnitScript Hooks for Damage/Healing Scaling
        // =====================================================================
        
        class ItemUpgradeProcDamageHook : public UnitScript
        {
        public:
            ItemUpgradeProcDamageHook() : UnitScript("ItemUpgradeProcDamageHook") {}
            
            // Hook: Spell damage taken (scales spell damage including procs)
            void OnDamage(Unit* attacker, Unit* victim, uint32& damage) override
            {
                if (!attacker || !victim || damage == 0)
                    return;
                
                Player* player = attacker->ToPlayer();
                if (!player)
                    return;
                
                // For now, we scale all damage slightly based on average item upgrades
                // This is a simplified approach until we can track spell sources
                float multiplier = GetPlayerAvgProcMultiplier(player);
                if (multiplier > 1.0f)
                {
                    // Apply 50% of the multiplier to prevent double-dipping with base stat scaling
                    float proc_bonus = (multiplier - 1.0f) * 0.5f;
                    damage = static_cast<uint32>(damage * (1.0f + proc_bonus));
                }
            }
            
            // Hook: Healing done (scales healing including procs)
            void OnHeal(Unit* healer, Unit* reciever, uint32& gain) override
            {
                if (!healer || !reciever || gain == 0)
                    return;
                
                Player* player = healer->ToPlayer();
                if (!player)
                    return;
                
                // Scale healing based on average item upgrades
                float multiplier = GetPlayerAvgProcMultiplier(player);
                if (multiplier > 1.0f)
                {
                    // Apply 50% of the multiplier
                    float proc_bonus = (multiplier - 1.0f) * 0.5f;
                    gain = static_cast<uint32>(gain * (1.0f + proc_bonus));
                }
            }
        };
        
        // =====================================================================
        // Player Equipment Tracking
        // =====================================================================
        
        class ItemProcEquipmentHook : public PlayerScript
        {
        public:
            ItemProcEquipmentHook() : PlayerScript("ItemProcEquipmentHook") {}
            
            void OnPlayerEquip(Player* player, Item* /*item*/, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
            {
                if (!player)
                    return;
                
                // Recalculate player's average proc multiplier
                float multiplier = GetPlayerAvgProcMultiplier(player);
                LOG_DEBUG("scripts", "ItemUpgrade: Player {} equipment changed, avg proc multiplier: {:.2f}x",
                         player->GetGUID().GetCounter(), multiplier);
            }
            
            void OnPlayerLogout(Player* player) override
            {
                if (!player)
                    return;
                
                // Cleanup if needed (nothing to do for now)
            }
        };
        
        // =====================================================================
        // Registration
        // =====================================================================
        
    } // namespace ItemUpgrade
} // namespace DarkChaos

// Registration function must be in global namespace
void AddSC_ItemUpgradeProcScaling()
{
    try
    {
        // Initialize proc spell database
        DarkChaos::ItemUpgrade::ProcSpellDatabase::Initialize();
        
        // Register hooks
        new DarkChaos::ItemUpgrade::ItemUpgradeProcDamageHook();
        new DarkChaos::ItemUpgrade::ItemProcEquipmentHook();
        
        LOG_INFO("scripts", "ItemUpgrade: Proc scaling hooks registered successfully (UnitScript-based)");
    }
    catch (const std::exception& e)
    {
        LOG_ERROR("scripts", "ItemUpgrade: Failed to register proc scaling hooks: {}", e.what());
    }
}
