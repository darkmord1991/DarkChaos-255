/*
 * DarkChaos Item Upgrade - Artifact Curator NPC
 * 
 * This file implements the Chaos Artifact Curator NPC (ID: 190002)
 * who manages artifact collection, discovery, and cosmetic display
 * 
 * Author: DarkChaos Development Team
 * Date: November 4, 2025
 */

#include "ScriptMgr.h"
#include "CreatureScript.h"
#include "Player.h"

// NPC ID: 190002 - Artifact Curator
// Location: Single location (curator museum/vault)

class ItemUpgradeCurator : public CreatureScript
{
public:
    ItemUpgradeCurator() : CreatureScript("npc_item_upgrade_curator") {}

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        player->ClearGossipMenu();

        // Main menu options
        player->AddGossipMenuItem(0, "[Artifact Collection] View my artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        player->AddGossipMenuItem(0, "[Discovery Info] Learn about artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
        player->AddGossipMenuItem(0, "[Cosmetics] Apply artifact cosmetics", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
        player->AddGossipMenuItem(0, "[Statistics] View collection stats", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);
        player->AddGossipMenuItem(0, "[Help] System Information", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 5);
        
        player->SendGossipMenu(68, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        player->ClearGossipMenu();

        switch (action)
        {
            case GOSSIP_ACTION_INFO_DEF + 1: // Artifact collection
                player->AddGossipMenuItem(0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->SendGossipMenu(68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 2: // Discovery info
                player->AddGossipMenuItem(0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->SendGossipMenu(68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 3: // Cosmetics
                player->AddGossipMenuItem(0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->SendGossipMenu(68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 4: // Statistics
                player->AddGossipMenuItem(0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->SendGossipMenu(68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 5: // Help
                player->SendGossipMenu(68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 20: // Back
                OnGossipHello(player, creature);
                break;
            default:
                break;
        }
        return true;
    }
};

// Register the NPC script
void AddSC_ItemUpgradeCurator()
{
    new ItemUpgradeCurator();
}
