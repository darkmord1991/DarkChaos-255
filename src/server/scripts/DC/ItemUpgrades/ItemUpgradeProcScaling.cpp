/*
 * DarkChaos Item Upgrade - Proc Effect Scaling System
 * 
 * This file implements scaling for item proc effects (trinkets, weapons, etc.)
 * Procs are scaled based on the item's upgrade level.
 * 
 * How it works:
 * - Intercepts spell damage/healing from item procs
 * - Checks if the spell originated from an upgraded item
 * - Applies the upgrade multiplier to the proc damage/healing
 * 
 * Author: DarkChaos Development Team
 * Date: November 8, 2025
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Spell.h"
#include "SpellInfo.h"
#include "ItemUpgradeManager.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include <map>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        // =====================================================================
        // Helper: Track Item Procs
        // =====================================================================
        
        // Map: spell_id -> item_entry (for known item proc spells)
        // THREAD SAFETY: This map is populated once during initialization and only read afterwards.
        //                All access is on the world thread (single-threaded), so no mutex required.
        static std::map<uint32, uint32> spell_to_item_map;
        
        // Cache item upgrade multipliers for equipped items
        // THREAD SAFETY: Each player has their own cache entry. All player operations occur on
        //                the world thread (single-threaded), so no mutex required. If AzerothCore
        //                adds multi-threaded player processing in the future, this will need mutexes.
        struct PlayerItemCache
        {
            std::map<uint32, float> item_multipliers; // item_guid -> multiplier
            time_t last_update;
            
            PlayerItemCache() : last_update(0) {}
        };
        
        static std::map<uint32, PlayerItemCache> player_caches; // player_guid -> cache
        
        // =====================================================================
        // Build Spell->Item Mapping
        // =====================================================================
        
        void BuildSpellToItemMapping()
        {
            spell_to_item_map.clear();
            
            // Load from database
            QueryResult result = WorldDatabase.Query("SELECT spell_id, item_entry FROM dc_item_proc_spells WHERE scales_with_upgrade = 1");
            
            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    uint32 spell_id = fields[0].Get<uint32>();
                    uint32 item_entry = fields[1].Get<uint32>();
                    
                    spell_to_item_map[spell_id] = item_entry;
                    
                } while (result->NextRow());
                
                LOG_INFO("scripts", "ItemUpgrade: Loaded {} proc spell mappings from database", spell_to_item_map.size());
            }
            else
            {
                LOG_WARN("scripts", "ItemUpgrade: No proc spell mappings found in database. Run dc_item_proc_spells.sql");
                
                // Fallback: Hardcode some common procs if database table doesn't exist
                LOG_INFO("scripts", "ItemUpgrade: Using fallback hardcoded proc mappings");
                
                // Darkmoon Card: Greatness (various procs)
                spell_to_item_map[60229] = 42989; // Agility proc
                spell_to_item_map[60233] = 42990; // Strength proc
                spell_to_item_map[60234] = 42991; // Intellect proc
                spell_to_item_map[60235] = 42992; // Spirit proc
                
                // Mjolnir Runestone
                spell_to_item_map[45522] = 33831;
                
                // Illustration of the Dragon Soul
                spell_to_item_map[60486] = 40432;
                
                // Dying Curse
                spell_to_item_map[60494] = 40255;
                
                // Forge Ember
                spell_to_item_map[60479] = 37660;
                
                // Extract of Necromantic Power
                spell_to_item_map[60488] = 40373;
                
                // Grim Toll
                spell_to_item_map[60437] = 40256;
                
                // Mirror of Truth
                spell_to_item_map[60065] = 40684;
                
                LOG_INFO("scripts", "ItemUpgrade: Loaded {} fallback proc mappings", spell_to_item_map.size());
            }
        }
        
        // =====================================================================
        // Update Player's Item Cache
        // =====================================================================
        
        void UpdatePlayerItemCache(Player* player)
        {
            if (!player)
                return;
            
            uint32 player_guid = player->GetGUID().GetCounter();
            PlayerItemCache& cache = player_caches[player_guid];
            
            time_t now = time(nullptr);
            // Only update every 5 seconds to avoid excessive lookups
            if (now - cache.last_update < 5)
                return;
            
            cache.item_multipliers.clear();
            cache.last_update = now;
            
            UpgradeManager* mgr = GetUpgradeManager();
            if (!mgr)
                return;
            
            // Cache all equipped items and their multipliers
            for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            {
                Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                if (!item)
                    continue;
                
                uint32 item_guid = item->GetGUID().GetCounter();
                ItemUpgradeState* state = mgr->GetItemUpgradeState(item_guid);
                
                if (state && state->upgrade_level > 0)
                {
                    cache.item_multipliers[item_guid] = state->stat_multiplier;
                }
            }
        }
        
        // =====================================================================
        // Get Multiplier for Item
        // =====================================================================
        
        float GetItemProcMultiplier(Player* player, uint32 item_entry)
        {
            if (!player)
                return 1.0f;
            
            uint32 player_guid = player->GetGUID().GetCounter();
            auto cache_it = player_caches.find(player_guid);
            
            if (cache_it == player_caches.end())
            {
                UpdatePlayerItemCache(player);
                cache_it = player_caches.find(player_guid);
            }
            
            if (cache_it == player_caches.end())
                return 1.0f;
            
            // Find the item with this entry in equipped slots
            for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            {
                Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                if (!item || item->GetEntry() != item_entry)
                    continue;
                
                uint32 item_guid = item->GetGUID().GetCounter();
                auto mult_it = cache_it->second.item_multipliers.find(item_guid);
                
                if (mult_it != cache_it->second.item_multipliers.end())
                    return mult_it->second;
            }
            
            return 1.0f;
        }
        
        // =====================================================================
        // Spell Hook: Scale Proc Damage/Healing (Removed - SpellSC not available)
        // =====================================================================
        
        // Note: SpellSC is not available in AzerothCore
        // Proc scaling is handled via PlayerScript hooks below
        
        // =====================================================================
        // Alternative: Damage/Healing Modifier Hook
        // =====================================================================
        
        class ItemProcDamageHook : public PlayerScript
        {
        public:
            ItemProcDamageHook() : PlayerScript("ItemProcDamageHook") {}
            
            // Called to modify spell damage
            void OnSpellDamage(Player* player, Unit* /*victim*/, uint32& damage, SpellInfo const* spellInfo) override
            {
                if (!player || !spellInfo || damage == 0)
                    return;
                
                // Check if spell is from an item proc
                auto item_it = spell_to_item_map.find(spellInfo->Id);
                if (item_it == spell_to_item_map.end())
                    return;
                
                uint32 item_entry = item_it->second;
                float multiplier = GetItemProcMultiplier(player, item_entry);
                
                if (multiplier > 1.0f)
                {
                    uint32 original_damage = damage;
                    damage = static_cast<uint32>(damage * multiplier);
                    
                    LOG_DEBUG("scripts", "ItemUpgrade: Scaled proc damage from {} to {} (x{:.2f}) for spell {} from item {}", 
                             original_damage, damage, multiplier, spellInfo->Id, item_entry);
                }
            }
            
            // Called to modify spell healing
            void OnSpellHeal(Player* player, Unit* /*target*/, uint32& heal, SpellInfo const* spellInfo) override
            {
                if (!player || !spellInfo || heal == 0)
                    return;
                
                // Check if spell is from an item proc
                auto item_it = spell_to_item_map.find(spellInfo->Id);
                if (item_it == spell_to_item_map.end())
                    return;
                
                uint32 item_entry = item_it->second;
                float multiplier = GetItemProcMultiplier(player, item_entry);
                
                if (multiplier > 1.0f)
                {
                    uint32 original_heal = heal;
                    heal = static_cast<uint32>(heal * multiplier);
                    
                    LOG_DEBUG("scripts", "ItemUpgrade: Scaled proc healing from {} to {} (x{:.2f}) for spell {} from item {}", 
                             original_heal, heal, multiplier, spellInfo->Id, item_entry);
                }
            }
            
            // Update cache when items are equipped
            void OnAfterEquipItem(Player* player, uint8 /*slot*/, Item* /*item*/) override
            {
                UpdatePlayerItemCache(player);
            }
            
            // Clean up cache on logout
            void OnLogout(Player* player) override
            {
                if (!player)
                    return;
                
                uint32 player_guid = player->GetGUID().GetCounter();
                player_caches.erase(player_guid);
            }
        };
        
        // =====================================================================
        // Registration & Initialization
        // =====================================================================
        
        void AddSC_ItemUpgradeProcScaling()
        {
            // Build the spell->item mapping
            BuildSpellToItemMapping();
            
            // Register hooks
            new ItemProcDamageHook();
            
            LOG_INFO("scripts", "ItemUpgrade: Proc scaling system registered successfully");
        }
    }
}
