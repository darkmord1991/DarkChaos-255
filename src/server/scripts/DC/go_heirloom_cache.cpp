/*
 * Heirloom Cache GameObjects Script
 * 
 * Handles custom loot caches for Heirloom Tier 3 items (entries 1991001-1991033)
 * - OnGossipHello: Directly adds heirloom items to player inventory
 * - Class restrictions: Items not usable by your class are destroyed
 * - Despawns after looting
 * 
 * This script bypasses the normal chest/loot dialog system which conflicts with
 * Quality=7 (heirloom) bind confirmation dialogs on the client side.
 */

#include "GameObjectScript.h"
#include "Player.h"
#include "GameObject.h"
#include "ObjectMgr.h"
#include "LootMgr.h"
#include "Log.h"

class go_heirloom_cache : public GameObjectScript
{
public:
    go_heirloom_cache() : GameObjectScript("go_heirloom_cache") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!player || !go)
            return false;

        // Get loot ID from gameobject template Data1 field (for GAMEOBJECT_TYPE_CHEST)
        uint32 lootId = go->GetGOInfo()->chest.lootId;
        
        if (!lootId)
        {
            LOG_ERROR("scripts", "go_heirloom_cache: GameObject entry {} has no lootId configured!", go->GetEntry());
            return false;
        }

        // Check if already looted
        if (go->getLootState() == GO_ACTIVATED || go->getLootState() == GO_JUST_DEACTIVATED)
        {
            return false;
        }

        // Generate loot using the normal system but process it directly
        Loot loot;
        loot.FillLoot(lootId, LootTemplates_Gameobject, player, true, false, go->GetLootMode(), go);
        
        // Add gold if configured
        if (GameObjectTemplateAddon const* addon = go->GetTemplateAddon())
            loot.generateMoneyLoot(addon->mingold, addon->maxgold);

        // Process loot items - add directly to inventory with class checks
        uint32 itemsAdded = 0;
        for (auto const& lootItem : loot.items)
        {
            ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(lootItem.itemid);
            if (!itemTemplate)
                continue;

            // Check if player can use this item (class restrictions)
            if (itemTemplate->AllowableClass != -1 && 
                !(itemTemplate->AllowableClass & player->getClassMask()))
            {
                LOG_DEBUG("scripts", "go_heirloom_cache: Player {} ({}) cannot use item {} ({}) - class mismatch", 
                    player->GetName(), player->getClass(), itemTemplate->ItemId, itemTemplate->Name1);
                // Item will not be added to inventory (class restricted)
                continue;
            }

            // Add item to inventory
            ItemPosCountVec dest;
            InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, lootItem.itemid, lootItem.count);
            
            if (msg == EQUIP_ERR_OK)
            {
                Item* newItem = player->StoreNewItem(dest, lootItem.itemid, true, lootItem.randomPropertyId);
                if (newItem)
                {
                    player->SendNewItem(newItem, lootItem.count, true, false);
                    itemsAdded++;
                    LOG_DEBUG("scripts", "go_heirloom_cache: Added {} x{} to player {} inventory", 
                        itemTemplate->Name1, lootItem.count, player->GetName());
                }
            }
            else
            {
                // Inventory full
                player->SendEquipError(msg, nullptr, nullptr, lootItem.itemid);
                LOG_DEBUG("scripts", "go_heirloom_cache: Could not add {} to {} - inventory full (error: {})", 
                    itemTemplate->Name1, player->GetName(), msg);
            }
        }

        // Process money
        uint32 money = loot.gold;
        if (money > 0)
        {
            player->ModifyMoney(money);
            player->SendDisplayedMoney(money);
            LOG_DEBUG("scripts", "go_heirloom_cache: Added {} copper to player {} ", money, player->GetName());
        }

        if (itemsAdded == 0 && money == 0)
        {
            player->SendEquipError(EQUIP_ERR_ITEM_NOT_FOUND, nullptr, nullptr);
        }

        // Set the GO state to activated (marks as looted)
        go->SetLootState(GO_ACTIVATED, player);
        go->SetGoState(GO_STATE_ACTIVE);

        LOG_DEBUG("scripts", "go_heirloom_cache: Player {} looted heirloom cache entry {} (items: {}, money: {})", 
            player->GetName(), go->GetEntry(), itemsAdded, money);

        return true; // Handled - don't process default behavior
    }
};

// Add the script to the script loader
void AddSC_go_heirloom_cache()
{
    new go_heirloom_cache();
}
