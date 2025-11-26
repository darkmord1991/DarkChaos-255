/*
 * Heirloom Cache GameObjects Script
 * 
 * Handles custom loot caches for Heirloom Tier 3 items (entries 1991001-1991033)
 * - OnGossipHello: Opens loot window directly without requiring Lock.dbc entries
 * - After looting: Despawns the gameobject
 * 
 * This script bypasses the normal chest opening mechanism which requires
 * valid Lock.dbc entries for the client to cast the "Opening" spell.
 */

#include "GameObjectScript.h"
#include "Player.h"
#include "GameObject.h"
#include "Loot.h"
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
        if (go->GetLootState() == GO_ACTIVATED || go->GetLootState() == GO_JUST_DEACTIVATED)
        {
            // Already being looted or already looted
            return false;
        }

        // Prepare the loot
        Loot* loot = &go->loot;
        
        // If loot not yet generated, generate it now
        if (loot->empty())
        {
            // Clear any existing loot
            loot->clear();
            
            // Generate loot from gameobject_loot_template
            loot->FillLoot(lootId, LootTemplates_Gameobject, player, true, false, go->GetLootMode(), go);
            
            // Add gold if configured (using minGold/maxGold from chest template addon if exists)
            if (GameObjectTemplateAddon const* addon = go->GetTemplateAddon())
                loot->generateMoneyLoot(addon->mingold, addon->maxgold);
        }

        // Check if there's actually loot for this player
        if (loot->empty())
        {
            LOG_DEBUG("scripts", "go_heirloom_cache: No loot generated for player {} from lootId {}", 
                player->GetName(), lootId);
            // Still allow opening to show empty loot window
        }

        // Set loot state to activated
        go->SetLootState(GO_ACTIVATED, player);
        
        // Add the player as a loot recipient
        loot->AddLooter(player->GetGUID());
        
        // Send loot to player (LOOT_CORPSE works for gameobjects)
        player->SendLoot(go->GetGUID(), LOOT_CORPSE);
        
        // Set the GO state to active (open animation)
        go->SetGoState(GO_STATE_ACTIVE);

        LOG_DEBUG("scripts", "go_heirloom_cache: Player {} opened heirloom cache entry {} (lootId: {})", 
            player->GetName(), go->GetEntry(), lootId);

        return true; // Handled - don't process default behavior
    }
};

// Add the script to the script loader
void AddSC_go_heirloom_cache()
{
    new go_heirloom_cache();
}
