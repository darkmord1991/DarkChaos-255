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
#include "CreatureAI.h"
#include "Player.h"
#include "Chat.h"
#include "GameEventMgr.h"
#include "PassiveAI.h"
#include "QueryResult.h"
#include "DatabaseEnv.h"

// NPC ID: 190001 - Item Upgrade Vendor
// Locations: Main cities (faction-based)

class ItemUpgradeVendor : public CreatureScript
{
public:
    ItemUpgradeVendor() : CreatureScript("npc_item_upgrade_vendor") {}

    struct npc_item_upgrade_vendorAI : public PassiveAI
    {
        npc_item_upgrade_vendorAI(Creature* creature) : PassiveAI(creature) {}

        void Initialize()
        {
            // Initialize any state variables needed
        }

        void Reset() override
        {
            Initialize();
        }

        void MoveInLineOfSight(Unit* unit) override
        {
            if (!unit)
                return;

            Player* player = unit->ToPlayer();
            if (!player)
                return;

            // Distance check - greet when player is nearby
            if (me->GetDistance(unit) < 8.0f)
            {
                if (!me->HasUnitState(UNIT_STATE_BUSY) && me->GetDistance2d(unit) < 5.0f)
                {
                    me->SetFacingToObject(unit);
                }
            }
        }

        void OnGossipHello(Player* player) override
        {
            // Clear previous options
            player->ClearGossipMenu();

            // Main menu options
            player->AddGossipMenuItem(0, "[Item Upgrades] View available upgrades", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
            player->AddGossipMenuItem(0, "[Token Exchange] Trade tokens", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
            player->AddGossipMenuItem(0, "[Artifact Shop] View artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
            player->AddGossipMenuItem(0, "[Help] System Information", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);
            
            player->SendGossipMenu(68, me->GetGUID());
        }

        void OnGossipSelect(Player* player, uint32 menuId, uint32 gossipListId) override
        {
            player->ClearGossipMenu();

            switch (gossipListId)
            {
                case GOSSIP_ACTION_INFO_DEF + 1: // View upgrades
                    ShowUpgradeMenu(player);
                    break;
                case GOSSIP_ACTION_INFO_DEF + 2: // Token exchange
                    ShowTokenExchangeMenu(player);
                    break;
                case GOSSIP_ACTION_INFO_DEF + 3: // Artifact shop
                    ShowArtifactShopMenu(player);
                    break;
                case GOSSIP_ACTION_INFO_DEF + 4: // Help
                    ShowHelpMenu(player);
                    break;
                default:
                    break;
            }
        }

    private:
        void ShowUpgradeMenu(Player* player)
        {
            player->ADD_GOSSIP_ITEM_DB(0, "View my equipped items for upgrade", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 10);
            player->ADD_GOSSIP_ITEM_DB(0, "Show upgrade costs", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 11);
            player->ADD_GOSSIP_ITEM_DB(0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
            
            player->SendGossipMenu(68, me->GetGUID());
        }

        void ShowTokenExchangeMenu(Player* player)
        {
            player->ADD_GOSSIP_ITEM_DB(0, "Exchange tokens for currency", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 30);
            player->ADD_GOSSIP_ITEM_DB(0, "Check token balance", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 31);
            player->ADD_GOSSIP_ITEM_DB(0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
            
            player->SendGossipMenu(68, me->GetGUID());
        }

        void ShowArtifactShopMenu(Player* player)
        {
            player->ADD_GOSSIP_ITEM_DB(0, "Browse Chaos Artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 40);
            player->ADD_GOSSIP_ITEM_DB(0, "View discovered artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 41);
            player->ADD_GOSSIP_ITEM_DB(0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
            
            player->SendGossipMenu(68, me->GetGUID());
        }

        void ShowHelpMenu(Player* player)
        {
            player->SendGossipMenu(68, me->GetGUID());
            player->ChatRelayed("NPC", "Welcome to the Item Upgrade System!");
            player->ChatRelayed("NPC", "I help you upgrade your equipment using Upgrade Tokens.");
            player->ChatRelayed("NPC", "Use the command: .upgrade status");
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_item_upgrade_vendorAI(creature);
    }
};

// Register the NPC script
void AddSC_ItemUpgradeVendor()
{
    new ItemUpgradeVendor();
}
