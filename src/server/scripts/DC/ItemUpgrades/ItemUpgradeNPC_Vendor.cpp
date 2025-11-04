/*
 * DarkChaos Item Upgrade - Vendor NPC
 * 
 * This file implements the Item Upgrade Vendor NPC (ID: 190001)
 * who provides item upgrade services and token exchange
 * 
 * Author: DarkChaos Development Team
 * Date: November 4, 2025
 */

#include "ScriptMgr.h"
#include "CreatureScript.h"
#include "Player.h"

// NPC ID: 190001 - Item Upgrade Vendor
// Locations: Main cities (faction-based)

class ItemUpgradeVendor : public CreatureScript
{
public:
    ItemUpgradeVendor() : CreatureScript("npc_item_upgrade_vendor") {}

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        // Main menu options
        AddGossipItemFor(player, 0, "[Item Upgrades] View available upgrades", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        AddGossipItemFor(player, 0, "[Token Exchange] Trade tokens", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
        AddGossipItemFor(player, 0, "[Artifact Shop] View artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
        AddGossipItemFor(player, 0, "[Help] System Information", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);
        
        SendGossipMenuFor(player, 68, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        switch (action)
        {
            case GOSSIP_ACTION_INFO_DEF + 1: // View upgrades
                AddGossipItemFor(player, 0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                SendGossipMenuFor(player, 68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 2: // Token exchange
                AddGossipItemFor(player, 0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                SendGossipMenuFor(player, 68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 3: // Artifact shop
                AddGossipItemFor(player, 0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                SendGossipMenuFor(player, 68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 4: // Help
                SendGossipMenuFor(player, 68, creature->GetGUID());
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
void AddSC_ItemUpgradeVendor()
{
    new ItemUpgradeVendor();
}
