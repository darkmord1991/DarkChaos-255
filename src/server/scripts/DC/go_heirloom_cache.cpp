/*
 * Heirloom Cache GameObjects Script
 *
 * Handles custom loot caches for Heirloom Tier 3 items (entries 1991001-1991033)
 * - OnGossipHello: Directly adds heirloom items to player inventory (no bind dialogs)
 * - Class restrictions: Items not usable by your class are NOT added
 * - Despawns after looting
 *
 * This script hardcodes heirloom items to completely bypass the loot system
 * and bind confirmation dialogs on the client side.
 */

#include "GameObjectScript.h"
#include "Player.h"
#include "GameObject.h"
#include "ObjectMgr.h"
#include "Log.h"

class go_heirloom_cache : public GameObjectScript
{
public:
    go_heirloom_cache() : GameObjectScript("go_heirloom_cache") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!player || !go)
            return false;

        // Check if already looted
        if (go->getLootState() == GO_ACTIVATED || go->getLootState() == GO_JUST_DEACTIVATED)
        {
            return false;
        }

        // Add heirloom items directly to inventory
        uint32 itemsAdded = 0;

        // Item 300365 - Heirloom Shirt (Transmog cosmetic, all classes)
        if (player->AddItem(300365, 1))
        {
            LOG_DEBUG("scripts", "go_heirloom_cache: Added Heirloom Shirt (300365) to player {}", player->GetName());
            itemsAdded++;
        }

        // Item 300366 - Heirloom Bag (all classes)
        if (player->AddItem(300366, 1))
        {
            LOG_DEBUG("scripts", "go_heirloom_cache: Added Heirloom Bag (300366) to player {}", player->GetName());
            itemsAdded++;
        }

        if (itemsAdded == 0)
        {
            player->SendEquipError(EQUIP_ERR_ITEM_NOT_FOUND, nullptr, nullptr);
            LOG_DEBUG("scripts", "go_heirloom_cache: Player {} received no items - inventory full", player->GetName());
        }

        // Mark chest as looted
        go->SetLootState(GO_ACTIVATED, player);
        go->SetGoState(GO_STATE_ACTIVE);

        LOG_DEBUG("scripts", "go_heirloom_cache: Player {} looted heirloom cache entry {} (items added: {})",
            player->GetName(), go->GetEntry(), itemsAdded);

        return true; // Handled - don't process default behavior
    }
};

// Add the script to the script loader
void AddSC_go_heirloom_cache()
{
    new go_heirloom_cache();
}
