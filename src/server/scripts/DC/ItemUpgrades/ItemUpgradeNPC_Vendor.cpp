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
        auto mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
        uint32 upgradeTokens = mgr ? mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN) : 0;
        uint32 artifactEssence = mgr ? mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_ARTIFACT_ESSENCE) : 0;

        // Clear any previous menu
        ClearGossipMenuFor(player);

        // Build greeting text - not used in current gossip system but kept for future enhancement
        std::ostringstream greetingText;
        greetingText << "Greetings, " << player->GetName() << ".\n\n";
        greetingText << "I can help you upgrade your items using tokens earned through various activities.\n\n";
        greetingText << "|cff00ff00Upgrade Tokens:|r " << DarkChaos::ItemUpgrade::UI::FormatCurrency(upgradeTokens) << "\n";
        greetingText << "|cffff9900Artifact Essence:|r " << DarkChaos::ItemUpgrade::UI::FormatCurrency(artifactEssence);

        // Add menu options
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00ff00Item Upgrades|r - View available upgrades", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cffffff00Token Exchange|r - Trade tokens for upgrades", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff99ccffArtifact Shop|r - View available artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ffffWeekly Stats|r - View your earnings breakdown", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 5);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffffffHelp|r - System Information", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);

        player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        (void)sender;
        ClearGossipMenuFor(player);

        switch (action)
        {
            case GOSSIP_ACTION_INFO_DEF + 1: // View upgrades
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    "Item upgrade interface coming in Phase 4B!",
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    "You will be able to upgrade equipped items here.",
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
                break;
            }
            case GOSSIP_ACTION_INFO_DEF + 2: // Token exchange
            {
                auto mgr = DarkChaos::ItemUpgrade::GetUpgradeManager();
                uint32 tokens = mgr ? mgr->GetCurrency(player->GetGUID().GetCounter(), DarkChaos::ItemUpgrade::CURRENCY_UPGRADE_TOKEN) : 0;

                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    "You currently have " + std::to_string(tokens) + " Upgrade Tokens.",
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    "Token exchange system coming soon!",
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
                break;
            }
            case GOSSIP_ACTION_INFO_DEF + 3: // Artifact shop
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    "Artifact shop will be available in Phase 4B!",
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
                break;
            }
            case GOSSIP_ACTION_INFO_DEF + 4: // Help
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    "Earn Upgrade Tokens by completing quests, killing bosses,",
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    "PvP combat, and completing achievements.",
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    "Weekly cap: 500 tokens. Reset: Monday 00:00 server time.",
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
                break;
            }
            case GOSSIP_ACTION_INFO_DEF + 5: // Weekly Stats
            {
                // Query weekly earnings
                QueryResult result = CharacterDatabase.Query(
                    "SELECT weekly_earned FROM dc_player_upgrade_tokens WHERE player_guid = {} AND currency_type = 'upgrade_token' AND season = 1",
                    player->GetGUID().GetCounter());

                uint32 weeklyEarned = result ? result->Fetch()[0].Get<uint32>() : 0;
                uint32 remaining = (weeklyEarned >= 500) ? 0 : (500 - weeklyEarned);

                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    "Tokens earned this week: " + std::to_string(weeklyEarned) + " / 500",
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 5);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    "Remaining tokens: " + std::to_string(remaining),
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
void AddSC_ItemUpgradeVendor()
{
    new ItemUpgradeVendor();
}
