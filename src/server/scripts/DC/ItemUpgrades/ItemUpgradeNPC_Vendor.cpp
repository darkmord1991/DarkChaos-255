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
#include "ItemUpgradeManager.h"
#include <sstream>

// NPC ID: 190001 - Item Upgrade Vendor
// Locations: Main cities (faction-based)

class ItemUpgradeVendor : public CreatureScript
{
public:
    ItemUpgradeVendor() : CreatureScript("npc_item_upgrade_vendor") {}

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        // Get player's token balances
        auto mgr = DarkChaos::ItemUpgrade::sUpgradeManager();
        uint32 upgradeTokens = mgr ? mgr->GetCurrency(player->GetGUID(), DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN) : 0;
        uint32 artifactEssence = mgr ? mgr->GetCurrency(player->GetGUID(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE) : 0;
        
        // Build header with token info
        std::ostringstream ss;
        ss << "|cff00ff00=== Item Upgrade Vendor ===|r\n";
        ss << "|cffff0000Upgrade Tokens:|r |cff00ff00" << upgradeTokens << "|r\n";
        ss << "|cffff0000Artifact Essence:|r |cff99ccff" << artifactEssence << "|r\n\n";
        ss << "|cffffffffClick below to browse services|r";
        
        player->SetGossipMenuForTalking(ss.str());
        
        // Main menu options (use icons and colored text for nicer look)
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00ff00Item Upgrades|r - View available upgrades", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cffffff00Token Exchange|r - Trade your tokens for upgrades", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff99ccffArtifact Shop|r - View available artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffHelp|r - System Information and tips", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);
        
        SendGossipMenuFor(player, 68, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        (void)sender;
        switch (action)
        {
            case GOSSIP_ACTION_INFO_DEF + 1: // View upgrades
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                SendGossipMenuFor(player, 68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 2: // Token exchange
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                SendGossipMenuFor(player, 68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 3: // Artifact shop
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
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
