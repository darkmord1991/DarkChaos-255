/*
* DarkChaos-255 Dungeon Quest NPC System - Main NPC Script
* Version: 2.0 (Token-based rewards, CSV configuration)
* 
* This script handles quest master NPC interactions:
* - Gossip menu for quest selection
* - Quest acceptance and tracking
* - Token reward distribution
* - Daily/weekly quest reset handling
*/

#include "ScriptMgr.h"
#include "Player.h"
#include "Quest.h"
#include "QueryResult.h"
#include "WorldSession.h"

// NPC Entry Range: 700000-700052
#define DC_NPC_START_ENTRY      700000
#define DC_NPC_END_ENTRY        700052

// Quest Entry Ranges
#define DC_DAILY_QUEST_START    700101
#define DC_DAILY_QUEST_END      700104
#define DC_WEEKLY_QUEST_START   700201
#define DC_WEEKLY_QUEST_END     700204
#define DC_DUNGEON_QUEST_START  700701
#define DC_DUNGEON_QUEST_END    700999

// Token IDs
#define DC_TOKEN_EXPLORER       700001
#define DC_TOKEN_SPECIALIST     700002
#define DC_TOKEN_LEGENDARY      700003
#define DC_TOKEN_CHALLENGE      700004
#define DC_TOKEN_SPEED_RUNNER   700005

class npc_dungeon_quest_master : public CreatureScript
{
public:
    npc_dungeon_quest_master() : CreatureScript("npc_dungeon_quest_master") { }

    struct npc_dungeon_quest_masterAI : public ScriptedAI
    {
        npc_dungeon_quest_masterAI(Creature* creature) : ScriptedAI(creature) { }

        void MoveInLineOfSight(Unit* who) override
        {
            if (Player* player = who->ToPlayer())
            {
                // Check if player meets minimum level requirements
                if (player->getLevel() >= 15)
                {
                    // Gossip will be shown automatically via gossip_menu
                }
            }
        }

        void sGossipHello(Player* player) override
        {
            // Main menu: Show quest categories
            ClearGossipMenuFor(player);
            
            AddGossipItemFor(player, 0, "I want to undertake a dungeon quest.", GOSSIP_SENDER_MAIN, 1);
            AddGossipItemFor(player, 0, "Tell me about daily challenges.", GOSSIP_SENDER_MAIN, 2);
            AddGossipItemFor(player, 0, "Tell me about weekly trials.", GOSSIP_SENDER_MAIN, 3);
            AddGossipItemFor(player, 0, "What rewards can I earn?", GOSSIP_SENDER_MAIN, 4);
            AddGossipItemFor(player, 0, "Never mind.", GOSSIP_SENDER_MAIN, 99);

            SendGossipMenuFor(player, 1, me->GetGUID());
        }

        void sGossipSelect(Player* player, uint32 sender, uint32 action) override
        {
            ClearGossipMenuFor(player);

            switch (action)
            {
                case 1:  // Dungeon quests
                    ShowDungeonQuestsMenu(player);
                    break;
                case 2:  // Daily quests
                    ShowDailyQuestsMenu(player);
                    break;
                case 3:  // Weekly quests
                    ShowWeeklyQuestsMenu(player);
                    break;
                case 4:  // Rewards info
                    ShowRewardsInfo(player);
                    break;
                case 99: // Exit
                    CloseGossipMenuFor(player);
                    break;
                default:
                    // Individual quest selection
                    HandleQuestSelection(player, action);
                    break;
            }
        }

        void ShowDungeonQuestsMenu(Player* player)
        {
            AddGossipItemFor(player, 0, "I'm ready to explore dungeons!", GOSSIP_SENDER_MAIN, 100);
            AddGossipItemFor(player, 0, "Back...", GOSSIP_SENDER_MAIN, 99);
            SendGossipMenuFor(player, 2, me->GetGUID());
        }

        void ShowDailyQuestsMenu(Player* player)
        {
            AddGossipItemFor(player, 0, "Daily Quest 1: Explorer's Challenge", GOSSIP_SENDER_MAIN, 700101);
            AddGossipItemFor(player, 0, "Daily Quest 2: Focused Exploration", GOSSIP_SENDER_MAIN, 700102);
            AddGossipItemFor(player, 0, "Daily Quest 3: Quick Runner", GOSSIP_SENDER_MAIN, 700103);
            AddGossipItemFor(player, 0, "Daily Quest 4: Dungeon Master's Gauntlet", GOSSIP_SENDER_MAIN, 700104);
            AddGossipItemFor(player, 0, "Back...", GOSSIP_SENDER_MAIN, 99);
            SendGossipMenuFor(player, 3, me->GetGUID());
        }

        void ShowWeeklyQuestsMenu(Player* player)
        {
            AddGossipItemFor(player, 0, "Weekly Quest 1: Expansion Specialist", GOSSIP_SENDER_MAIN, 700201);
            AddGossipItemFor(player, 0, "Weekly Quest 2: Speed Runner's Trial", GOSSIP_SENDER_MAIN, 700202);
            AddGossipItemFor(player, 0, "Weekly Quest 3: Devoted Runner", GOSSIP_SENDER_MAIN, 700203);
            AddGossipItemFor(player, 0, "Weekly Quest 4: The Collector", GOSSIP_SENDER_MAIN, 700204);
            AddGossipItemFor(player, 0, "Back...", GOSSIP_SENDER_MAIN, 99);
            SendGossipMenuFor(player, 4, me->GetGUID());
        }

        void ShowRewardsInfo(Player* player)
        {
            AddGossipItemFor(player, 0, 
                "Each quest earns Tokens:\n"
                "- Dungeon Explorer Token (basic reward)\n"
                "- Expansion Specialist Token (tier 2)\n"
                "- Legendary Dungeon Token (rare)\n"
                "- Challenge Master Token (difficult)\n"
                "- Speed Runner Token (time-based)", 
                GOSSIP_SENDER_MAIN, 99);
            SendGossipMenuFor(player, 5, me->GetGUID());
        }

        void HandleQuestSelection(Player* player, uint32 questId)
        {
            Quest const* quest = sQuestDataStore->GetQuestTemplate(questId);
            if (!quest)
                return;

            // Check if player meets level requirements
            if (player->GetQuestLevel(quest) > player->getLevel())
            {
                player->SendGossipMenu(player->GetGossipTextId(me), me->GetGUID());
                me->Say("You are not yet experienced enough for this quest.", LANG_UNIVERSAL, player);
                return;
            }

            // Accept the quest
            player->AddQuest(quest, me);
            CloseGossipMenuFor(player);
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_dungeon_quest_masterAI(creature);
    }
};

void AddSC_npc_dungeon_quest_master()
{
    new npc_dungeon_quest_master();
}

/*
* NOTES FOR INTEGRATION:
* 
* 1. Add this script to the DC module loader
* 2. Register gossip texts in gossip_menu table:
*    INSERT INTO gossip_menu (entry, text_id) VALUES (1, 60000);
*    INSERT INTO gossip_menu (entry, text_id) VALUES (2, 60001);
*    etc.
* 
* 3. Link NPC creature entries to this script:
*    UPDATE creature_template SET AIName='SmartAI', gossip_menu_id=1 
*    WHERE entry BETWEEN 700000 AND 700052;
* 
* 4. Daily/Weekly reset is handled via player_daily_quest_progress
*    and player_weekly_quest_progress tables (database level)
* 
* 5. Token rewards are handled via quest_reward_table linking to
*    dc_daily_quest_token_rewards and dc_weekly_quest_token_rewards
* 
* FUTURE ENHANCEMENTS:
* - CSV-based dynamic quest loading (TokenConfigManager)
* - Reward scaling based on player level
* - Achievement tracking integration
* - Statistics tracking for leaderboards
*/
