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
        auto mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        
        uint32 upgradeTokens = 0;
        uint32 artifactEssence = 0;
        
        if (mgr)
        {
            upgradeTokens = mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN);
            artifactEssence = mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE);
        }
        
        // Also query from database to verify
        QueryResult result = CharacterDatabase.Query(
            "SELECT amount FROM dc_player_upgrade_tokens WHERE player_guid = {} AND currency_type = 'artifact_essence'", 
            player->GetGUID().GetCounter());
        
        if (result)
        {
            artifactEssence = result->Fetch()[0].Get<uint32>();
        }
        
        // Clear any previous menu
        ClearGossipMenuFor(player);
        
        // Build greeting text
        std::ostringstream greetingText;
        greetingText << "Greetings, " << player->GetName() << ".\n\n";
        greetingText << "I am the Artifact Curator. I preserve knowledge of ancient artifacts and can help you unlock their power.\n\n";
        greetingText << "|cff00ff00Upgrade Tokens:|r " << DarkChaos::ItemUpgrade::UI::FormatCurrency(upgradeTokens) << "\n";
        greetingText << "|cffff9900Artifact Essence:|r " << DarkChaos::ItemUpgrade::UI::FormatCurrency(artifactEssence);
        
        // Add menu options
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff99ccffArtifact Collection|r - View my artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffff00Discovery Info|r - Learn about artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff66ff66Cosmetics|r - Apply artifact cosmetics", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffStatistics|r - View collection stats", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffHelp|r - System Information", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 5);
        
        player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        (void)sender;
        ClearGossipMenuFor(player);
        
        switch (action)
        {
            case GOSSIP_ACTION_INFO_DEF + 1: // Artifact collection
            {
                // Query discovered artifacts
                QueryResult result = CharacterDatabase.Query(
                    "SELECT COUNT(*) FROM dc_player_artifact_discoveries WHERE player_guid = {}", 
                    player->GetGUID().GetCounter());
                
                uint32 discoveredCount = result ? result->Fetch()[0].Get<uint32>() : 0;
                
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "You have discovered " + std::to_string(discoveredCount) + " artifacts so far.", 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
                break;
            }
            case GOSSIP_ACTION_INFO_DEF + 2: // Discovery info
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "Artifacts are discovered by completing achievements.", 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "Each achievement grants 50 Artifact Essence.", 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
                break;
            }
            case GOSSIP_ACTION_INFO_DEF + 3: // Cosmetics
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "Cosmetic features are coming in Phase 4B!", 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
                break;
            }
            case GOSSIP_ACTION_INFO_DEF + 4: // Statistics
            {
                auto mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
                uint32 essence = mgr ? mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE) : 0;
                
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "Total Artifact Essence: " + std::to_string(essence), 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
                break;
            }
            case GOSSIP_ACTION_INFO_DEF + 5: // Help
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "Complete achievements to discover artifacts and earn essence.", 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 5);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "Use essence to unlock artifact cosmetics (Phase 4B).", 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 5);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
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
void AddSC_ItemUpgradeCurator()
{
    new ItemUpgradeCurator();
}
