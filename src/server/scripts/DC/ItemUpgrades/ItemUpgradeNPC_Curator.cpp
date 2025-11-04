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
#include "ItemUpgradeManager.h"
#include "ItemUpgradeUIHelpers.h"
#include "DatabaseEnv.h"
#include <sstream>

// NPC ID: 190002 - Artifact Curator
// Location: Single location (curator museum/vault)

class ItemUpgradeCurator : public CreatureScript
{
public:
    ItemUpgradeCurator() : CreatureScript("npc_item_upgrade_curator") {}

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        // Get player's token balances and artifact discovery count
        auto mgr = DarkChaos::ItemUpgrade::sUpgradeManager();
        uint32 upgradeTokens = mgr ? mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN) : 0;
        uint32 artifactEssence = mgr ? mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE) : 0;
        
        // Build enhanced header with progress bar
        std::ostringstream ss;
        ss << DarkChaos::ItemUpgrade::UI::CreateHeader("Artifact Curator", 40);
        ss << "\n\n";
        ss << DarkChaos::ItemUpgrade::UI::CreateStatRow("Upgrade Tokens:", DarkChaos::ItemUpgrade::UI::FormatCurrency(upgradeTokens), 40) << "\n";
        ss << DarkChaos::ItemUpgrade::UI::CreateStatRow("Artifact Essence:", DarkChaos::ItemUpgrade::UI::FormatCurrency(artifactEssence), 40) << "\n\n";
        
        player->SetGossipMenuForTalking(ss.str());
        
        // Main menu options with enhanced formatting
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff99ccffArtifact Collection|r - View my artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffff00Discovery Info|r - Learn about artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff66ff66Cosmetics|r - Apply artifact cosmetics", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffStatistics|r - View collection stats", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffHelp|r - System Information", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 5);
        
        SendGossipMenuFor(player, 68, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        (void)sender;
        switch (action)
        {
            case GOSSIP_ACTION_INFO_DEF + 1: // Artifact collection
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                SendGossipMenuFor(player, 68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 2: // Discovery info
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                SendGossipMenuFor(player, 68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 3: // Cosmetics
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                SendGossipMenuFor(player, 68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 4: // Statistics
                AddGossipItemFor(player, 0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                SendGossipMenuFor(player, 68, creature->GetGUID());
                break;
            case GOSSIP_ACTION_INFO_DEF + 5: // Help
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
void AddSC_ItemUpgradeCurator()
{
    new ItemUpgradeCurator();
}
