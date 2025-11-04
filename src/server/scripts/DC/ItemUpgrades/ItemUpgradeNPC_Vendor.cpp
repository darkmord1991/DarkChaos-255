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
#include "ItemUpgradeUIHelpers.h"
#include "DatabaseEnv.h"
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
        uint32 upgradeTokens = mgr ? mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN) : 0;
        uint32 artifactEssence = mgr ? mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE) : 0;
        
        // Build enhanced header with progress bar
        std::ostringstream ss;
        ss << DarkChaos::ItemUpgrade::UI::CreateHeader("Item Upgrade Vendor", 40);
        ss << "\n\n";
        ss << DarkChaos::ItemUpgrade::UI::CreateStatRow("Upgrade Tokens:", DarkChaos::ItemUpgrade::UI::FormatCurrency(upgradeTokens), 40) << "\n";
        ss << DarkChaos::ItemUpgrade::UI::CreateStatRow("Artifact Essence:", DarkChaos::ItemUpgrade::UI::FormatCurrency(artifactEssence), 40) << "\n\n";
        
        // Main menu options with enhanced formatting
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00ff00Item Upgrades|r - View available upgrades", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cffffff00Token Exchange|r - Trade your tokens for upgrades", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff99ccffArtifact Shop|r - View available artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ffffWeekly Stats|r - View your earnings breakdown", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 5);
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
            case GOSSIP_ACTION_INFO_DEF + 5: // Weekly Stats
            {
                std::ostringstream ss;
                ss << DarkChaos::ItemUpgrade::UI::CreateHeader("Weekly Earnings", 40);
                ss << "\n\n";
                ss << "Coming Soon: Weekly earning tracking\n";
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                SendGossipMenuFor(player, 68, creature->GetGUID());
                break;
            }
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
