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
#include "CreatureAI.h"
#include "Player.h"
#include "Chat.h"
#include "GameEventMgr.h"
#include "PassiveAI.h"
#include "QueryResult.h"
#include "DatabaseEnv.h"

// NPC ID: 190002 - Artifact Curator
// Location: Single location (curator museum/vault)

class ItemUpgradeCurator : public CreatureScript
{
public:
    ItemUpgradeCurator() : CreatureScript("npc_item_upgrade_curator") {}

    struct npc_item_upgrade_curatorAI : public PassiveAI
    {
        npc_item_upgrade_curatorAI(Creature* creature) : PassiveAI(creature) {}

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
            if (me->GetDistance(unit) < 10.0f)
            {
                if (!me->HasUnitState(UNIT_STATE_BUSY) && me->GetDistance2d(unit) < 7.0f)
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
            player->AddGossipMenuItem(0, "[Artifact Collection] View my artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
            player->AddGossipMenuItem(0, "[Discovery Info] Learn about artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
            player->AddGossipMenuItem(0, "[Cosmetics] Apply artifact cosmetics", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
            player->AddGossipMenuItem(0, "[Statistics] View collection stats", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);
            player->AddGossipMenuItem(0, "[Help] System Information", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 5);
            
            player->SendGossipMenu(68, me->GetGUID());
        }

        void OnGossipSelect(Player* player, uint32 menuId, uint32 gossipListId) override
        {
            player->ClearGossipMenu();

            switch (gossipListId)
            {
                case GOSSIP_ACTION_INFO_DEF + 1: // Artifact collection
                    ShowArtifactCollectionMenu(player);
                    break;
                case GOSSIP_ACTION_INFO_DEF + 2: // Discovery info
                    ShowDiscoveryInfoMenu(player);
                    break;
                case GOSSIP_ACTION_INFO_DEF + 3: // Cosmetics
                    ShowCosmeticsMenu(player);
                    break;
                case GOSSIP_ACTION_INFO_DEF + 4: // Statistics
                    ShowStatisticsMenu(player);
                    break;
                case GOSSIP_ACTION_INFO_DEF + 5: // Help
                    ShowHelpMenu(player);
                    break;
                default:
                    break;
            }
        }

    private:
        void ShowArtifactCollectionMenu(Player* player)
        {
            player->ADD_GOSSIP_ITEM_DB(0, "View all discovered artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 10);
            player->ADD_GOSSIP_ITEM_DB(0, "Show artifact details", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 11);
            player->ADD_GOSSIP_ITEM_DB(0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
            
            player->SendGossipMenu(68, me->GetGUID());
        }

        void ShowDiscoveryInfoMenu(Player* player)
        {
            player->ADD_GOSSIP_ITEM_DB(0, "Where to find artifacts", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 30);
            player->ADD_GOSSIP_ITEM_DB(0, "Artifact rarity levels", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 31);
            player->ADD_GOSSIP_ITEM_DB(0, "Collection achievements", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 32);
            player->ADD_GOSSIP_ITEM_DB(0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
            
            player->SendGossipMenu(68, me->GetGUID());
        }

        void ShowCosmeticsMenu(Player* player)
        {
            player->ADD_GOSSIP_ITEM_DB(0, "View cosmetic variants", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 40);
            player->ADD_GOSSIP_ITEM_DB(0, "Apply cosmetic effect", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 41);
            player->ADD_GOSSIP_ITEM_DB(0, "Customize appearance", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 42);
            player->ADD_GOSSIP_ITEM_DB(0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
            
            player->SendGossipMenu(68, me->GetGUID());
        }

        void ShowStatisticsMenu(Player* player)
        {
            player->ADD_GOSSIP_ITEM_DB(0, "Collection progress", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 50);
            player->ADD_GOSSIP_ITEM_DB(0, "Discovered vs Total", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 51);
            player->ADD_GOSSIP_ITEM_DB(0, "Rarity breakdown", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 52);
            player->ADD_GOSSIP_ITEM_DB(0, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
            
            player->SendGossipMenu(68, me->GetGUID());
        }

        void ShowHelpMenu(Player* player)
        {
            player->SendGossipMenu(68, me->GetGUID());
            player->ChatRelayed("NPC", "Welcome to the Artifact Collection!");
            player->ChatRelayed("NPC", "I curate and display Chaos Artifacts from across the realm.");
            player->ChatRelayed("NPC", "Discover artifacts by exploring dungeons, raids, and special locations.");
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_item_upgrade_curatorAI(creature);
    }
};

// Register the NPC script
void AddSC_ItemUpgradeCurator()
{
    new ItemUpgradeCurator();
}
