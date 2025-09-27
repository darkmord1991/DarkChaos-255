/*
 * AzerothCore Custom Script: Hinterland BG - King Varian Wrynn NPC
 *
 * This script is a copy of npc_thrall_hinterlandbg, adapted for King Varian Wrynn as a battleground boss.
 *
 * Place this file in src/server/scripts/DC/HinterlandBG/ and register it in your script loader and CMakeLists.txt.
 */

#include "AreaDefines.h"
#include "CreatureScript.h"
#include "Player.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "TaskScheduler.h"
#include "LFGMgr.h"

enum VarianHinterlandBG : uint32
{
    SPELL_CHAIN_LIGHTNING          = 16033, // You may want to change these to Varian-specific spells
    SPELL_SHOCK                    = 16034,
    QUEST_FOR_THE_ALLIANCE         = 810003, // Example quest ID for Varian
    SPELL_KING_BLESSING            = 16609,  // Example spell, adjust as needed
    NPC_HERALD_OF_VARIAN           = 29589,  // Example herald, adjust as needed
    ACTION_START_TALKING           = 0,
    SAY_VARIAN_ON_QUEST_REWARD_0   = 0,
    SAY_VARIAN_ON_QUEST_REWARD_1   = 1,
    GO_UNADORNED_SPIKE             = 175787,
    QUEST_WHAT_THE_WIND_CARRIES    = 6566,
    GOSSIP_MENU_VARIAN             = 3664,
    GOSSIP_RESPONSE_VARIAN_FIRST   = 5733,
    QUEST_KINGS_BLESSING           = 13189,
};

const Position heraldOfVarianPos = { -462.404f, -2637.68f, 96.0656f, 5.8606f };

class npc_Varian_hinterlandbg : public CreatureScript
{
public:
    npc_Varian_hinterlandbg() : CreatureScript("npc_Varian_hinterlandbg") { }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        uint32 DiscussionOrder = action - GOSSIP_ACTION_INFO_DEF;
        if (DiscussionOrder>= 1 && DiscussionOrder <= 6)
        {
            uint32 NextAction = GOSSIP_ACTION_INFO_DEF + DiscussionOrder + 1;
            uint32 GossipResponse = GOSSIP_RESPONSE_VARIAN_FIRST + DiscussionOrder - 1;
            AddGossipItemFor(player, GOSSIP_MENU_VARIAN + DiscussionOrder, 0, GOSSIP_SENDER_MAIN, NextAction);
            SendGossipMenuFor(player, GossipResponse, creature->GetGUID());
        }
        else if (DiscussionOrder == 7)
        {
            CloseGossipMenuFor(player);
            player->AreaExploredOrEventHappens(QUEST_WHAT_THE_WIND_CARRIES);
        }
        return true;
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
        {
            player->PrepareQuestMenu(creature->GetGUID());
        }
        if (player->GetQuestStatus(QUEST_WHAT_THE_WIND_CARRIES) == QUEST_STATUS_INCOMPLETE)
        {
            AddGossipItemFor(player, GOSSIP_MENU_VARIAN, 0, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        }
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnQuestReward(Player* player, Creature* creature, Quest const* quest, uint32 /*item*/) override
    {
        switch (quest->GetQuestId())
        {
            case (QUEST_FOR_THE_ALLIANCE):
                if (creature && creature->AI())
                    creature->AI()->DoAction(ACTION_START_TALKING);
                break;
            case (QUEST_KINGS_BLESSING):
                sLFGMgr->InitializeLockedDungeons(player);
                break;
            default:
                break;
        }
        return true;
    }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_Varian_hinterlandbgAI(creature);
    }

    struct npc_Varian_hinterlandbgAI : public ScriptedAI
    {
        npc_Varian_hinterlandbgAI(Creature* creature) : ScriptedAI(creature) { }
        uint32 ChainLightningTimer;
        uint32 ShockTimer;
        void Reset() override
        {
            ChainLightningTimer = 2000;
            ShockTimer = 8000;
        }
        void JustEngagedWith(Unit* /*who*/) override { }
        void DoAction(int32 action) override
        {
            if (action == ACTION_START_TALKING)
            {
                me->RemoveNpcFlag(UNIT_NPC_FLAG_GOSSIP);
                me->GetMap()->LoadGrid(heraldOfVarianPos.GetPositionX(), heraldOfVarianPos.GetPositionY());
                me->SummonCreature(NPC_HERALD_OF_VARIAN, heraldOfVarianPos, TEMPSUMMON_TIMED_DESPAWN, 20 * IN_MILLISECONDS);
                me->HandleEmoteCommand(EMOTE_ONESHOT_ROAR);
                scheduler.Schedule(1s, [this](TaskContext /*context*/)
                {
                    if (GameObject* spike = me->FindNearestGameObject(GO_UNADORNED_SPIKE, 10.0f))
                    {
                        spike->SetGoState(GO_STATE_ACTIVE);
                    }
                }).Schedule(2s, [this](TaskContext /*context*/)
                {
                    Talk(SAY_VARIAN_ON_QUEST_REWARD_0);
                }).Schedule(9s, [this](TaskContext /*context*/)
                {
                    Talk(SAY_VARIAN_ON_QUEST_REWARD_1);
                    DoCastAOE(SPELL_KING_BLESSING, true);
                    me->SetNpcFlag(UNIT_NPC_FLAG_GOSSIP);
                    me->GetMap()->DoForAllPlayers([&](Player* player)
                    {
                        if (player->IsAlive() && !player->IsGameMaster())
                        {
                            if (player->GetAreaId() == AREA_ORGRIMMAR)
                            {
                                player->CastSpell(player, SPELL_KING_BLESSING, true);
                            }
                        }
                    });
                }).Schedule(19s, [this](TaskContext /*context*/)
                {
                    me->GetMap()->DoForAllPlayers([&](Player* player)
                    {
                        if (player->IsAlive() && !player->IsGameMaster())
                        {
                            if (player->GetAreaId() == AREA_THE_CROSSROADS)
                            {
                                player->CastSpell(player, SPELL_KING_BLESSING, true);
                            }
                        }
                    });
                });
            }
        }
        void UpdateAI(uint32 diff) override
        {
            scheduler.Update(diff);
            if (!UpdateVictim())
                return;
            if (ChainLightningTimer <= diff)
            {
                DoCastVictim(SPELL_CHAIN_LIGHTNING);
                ChainLightningTimer = 9000;
            }
            else ChainLightningTimer -= diff;
            if (ShockTimer <= diff)
            {
                DoCastVictim(SPELL_SHOCK);
                ShockTimer = 15000;
            }
            else ShockTimer -= diff;
            DoMeleeAttackIfReady();
        }
    };
};

void AddSC_hinterlandbg_Varian_hinterlandbg()
{
    new npc_Varian_hinterlandbg();
}
