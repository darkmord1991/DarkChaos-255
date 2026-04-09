/*
 * Heirloom Cache GameObjects Script
 *
 * Handles custom loot caches for Heirloom Tier 3 items.
 * - OnGossipHello: Directly adds heirloom items to player inventory (no bind dialogs)
 * - Visibility: Cache is hidden for players who cannot currently receive cache items
 * - Despawns after looting
 *
 * This script hardcodes heirloom items to completely bypass the loot system
 * and bind confirmation dialogs on the client side.
 */

#include "GameObjectScript.h"
#include "GameObjectAI.h"
#include "Player.h"
#include "GameObject.h"
#include "ObjectMgr.h"
#include "Log.h"

namespace
{
    constexpr uint32 HEIRLOOM_SHIRT_ITEM = 300365;
    constexpr uint32 HEIRLOOM_BAG_ITEM = 300366;

    bool CanReceiveItemNow(Player* player, uint32 itemId)
    {
        if (!player)
            return false;

        ItemPosCountVec dest;
        return player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, 1) == EQUIP_ERR_OK;
    }

    bool CanLootAnyHeirloomCacheItem(Player* player)
    {
        return CanReceiveItemNow(player, HEIRLOOM_SHIRT_ITEM) || CanReceiveItemNow(player, HEIRLOOM_BAG_ITEM);
    }
}

class go_heirloom_cache : public GameObjectScript
{
public:
    go_heirloom_cache() : GameObjectScript("go_heirloom_cache") { }

    struct go_heirloom_cacheAI : public GameObjectAI
    {
        explicit go_heirloom_cacheAI(GameObject* gameObject) : GameObjectAI(gameObject) { }

        bool CanBeSeen(Player const* seer) override
        {
            if (!seer)
                return false;

            if (seer->IsGameMaster())
                return true;

            return CanLootAnyHeirloomCacheItem(const_cast<Player*>(seer));
        }
    };

    GameObjectAI* GetAI(GameObject* go) const override
    {
        return new go_heirloom_cacheAI(go);
    }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!player || !go)
            return false;

        // Keep interaction logic consistent with visibility logic.
        if (!CanLootAnyHeirloomCacheItem(player))
        {
            player->SendEquipError(EQUIP_ERR_ITEM_NOT_FOUND, nullptr, nullptr);
            return true;
        }

        // Check if already looted
        if (go->getLootState() == GO_ACTIVATED || go->getLootState() == GO_JUST_DEACTIVATED)
        {
            return false;
        }

        // Add heirloom items directly to inventory
        uint32 itemsAdded = 0;

        // Item 300365 - Heirloom Shirt (Transmog cosmetic, all classes)
        if (player->AddItem(HEIRLOOM_SHIRT_ITEM, 1))
        {
            LOG_DEBUG("scripts.dc", "go_heirloom_cache: Added Heirloom Shirt (300365) to player {}", player->GetName());
            itemsAdded++;
        }

        // Item 300366 - Heirloom Bag (all classes)
        if (player->AddItem(HEIRLOOM_BAG_ITEM, 1))
        {
            LOG_DEBUG("scripts.dc", "go_heirloom_cache: Added Heirloom Bag (300366) to player {}", player->GetName());
            itemsAdded++;
        }

        if (itemsAdded == 0)
        {
            player->SendEquipError(EQUIP_ERR_ITEM_NOT_FOUND, nullptr, nullptr);
            LOG_DEBUG("scripts.dc", "go_heirloom_cache: Player {} received no items - inventory full", player->GetName());
        }

        // Mark chest as looted
        go->SetLootState(GO_ACTIVATED, player);
        go->SetGoState(GO_STATE_ACTIVE);

        LOG_DEBUG("scripts.dc", "go_heirloom_cache: Player {} looted heirloom cache entry {} (items added: {})",
            player->GetName(), go->GetEntry(), itemsAdded);

        return true; // Handled - don't process default behavior
    }
};

// Add the script to the script loader
void AddSC_go_heirloom_cache()
{
    new go_heirloom_cache();
}
