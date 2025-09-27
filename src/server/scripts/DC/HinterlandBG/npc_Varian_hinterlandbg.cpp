
/*
 * AzerothCore Custom Script: Hinterland BG - King Varian Wrynn NPC
 *
 * Feature Overview:
 * - Custom King Varian Wrynn NPC for Hinterland Battleground
 * - Interactive gossip menu for quest progression and lore
 * - Handles quest rewards, spell casting, and event triggers
 * - Schedules emotes, spell effects, and map-wide player interactions
 * - Easily extendable for custom battleground logic
 *
 * Integration:
 * - Place this file in src/server/scripts/DC/HinterlandBG/
 * - Register AddSC_hinterlandbg_Varian_hinterlandbg and AddSC_hinterlandbg_Varian_wrynn in your script loader
 * - Add to CMakeLists.txt for compilation
 * - Set ScriptName to "npc_Varian_hinterlandbg" in your creature_template DB entry
 * - Set npcflag to 1 (GOSSIP) for the NPC in the DB
 *
 * Author: (your name or team)
 * Date: 2025-09-27
 *
 * Usage:
 * - Talk to King Varian Wrynn in Hinterland BG
 * - Select options from the gossip menu for quest and event progression
 * - NPC will trigger emotes, spells, and interact with players on the map
 */
// --- Main King Varian Wrynn NPC Script ---
    // Build gossip menu with quest/event options
    // Handle gossip selection, quest rewards, and event triggers
    // AI logic for spell casting, emotes, and map-wide effects
// --- Script Registration ---

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
    SPELL_CHAIN_LIGHTNING          = 16033, // You may want to change these to Varian-specific spells
    SPELL_SHOCK                    = 16034,
    SPELL_KING_BLESSING            = 16609,  // Example spell, adjust as needed
    NPC_HERALD_OF_VARIAN           = 29589,  // Example herald, adjust as needed
    ACTION_START_TALKING           = 0,
    SAY_VARIAN_ON_QUEST_REWARD_0   = 0,
    SAY_VARIAN_ON_QUEST_REWARD_1   = 1,
    GO_UNADORNED_SPIKE             = 175787,
    GOSSIP_MENU_VARIAN             = 3664,
    GOSSIP_RESPONSE_VARIAN_FIRST   = 5733,
};

const Position heraldOfVarianPos = { -462.404f, -2637.68f, 96.0656f, 5.8606f };


// Main script class for King Varian Wrynn
class npc_Varian_hinterlandbg : public CreatureScript
{
public:
    npc_Varian_hinterlandbg() : CreatureScript("npc_Varian_hinterlandbg") { }

    // Called when a player selects a gossip menu item
    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        // Clear previous gossip menu
        ClearGossipMenuFor(player);
        // Calculate which option was selected
        uint32 DiscussionOrder = action - GOSSIP_ACTION_INFO_DEF;
        // Handle main menu and submenu navigation
        if (DiscussionOrder>= 1 && DiscussionOrder <= 6)
        {
            uint32 NextAction = GOSSIP_ACTION_INFO_DEF + DiscussionOrder + 1;
            uint32 GossipResponse = GOSSIP_RESPONSE_VARIAN_FIRST + DiscussionOrder - 1;
            // Add next gossip item and show response
            AddGossipItemFor(player, GOSSIP_MENU_VARIAN + DiscussionOrder, 0, GOSSIP_SENDER_MAIN, NextAction);
            SendGossipMenuFor(player, GossipResponse, creature->GetGUID());
        }
        else if (DiscussionOrder == 7)
        {
            // Final option: close menu
            CloseGossipMenuFor(player);
        }
        return true;
    }

    // Called when a player interacts with the NPC
    bool OnGossipHello(Player* player, Creature* creature) override
    {
        // Always show main gossip option
        AddGossipItemFor(player, GOSSIP_MENU_VARIAN, 0, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        // Show the gossip menu to the player
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    // OnQuestReward removed (no quest logic)

    // Returns the custom AI for this NPC
    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_Varian_hinterlandbgAI(creature);
    }

    // Custom AI logic for King Varian Wrynn
    struct npc_Varian_hinterlandbgAI : public ScriptedAI
    {
        npc_Varian_hinterlandbgAI(Creature* creature) : ScriptedAI(creature) { }
        uint32 ChainLightningTimer;
        uint32 ShockTimer;
        // Called when the NPC is reset (respawned or disengaged)
        void Reset() override
        {
            ChainLightningTimer = 2000;
            ShockTimer = 8000;
        }
        void JustEngagedWith(Unit* /*who*/) override { }
        // Handles custom event logic (emotes, spell casting, etc.)
        void DoAction(int32 action) override
        {
            if (action == ACTION_START_TALKING)
            {
                // Remove gossip flag and summon herald
                me->RemoveNpcFlag(UNIT_NPC_FLAG_GOSSIP);
                me->GetMap()->LoadGrid(heraldOfVarianPos.GetPositionX(), heraldOfVarianPos.GetPositionY());
                me->SummonCreature(NPC_HERALD_OF_VARIAN, heraldOfVarianPos, TEMPSUMMON_TIMED_DESPAWN, 20 * IN_MILLISECONDS);
                me->HandleEmoteCommand(EMOTE_ONESHOT_ROAR);
                // Schedule emotes, spell effects, and map-wide interactions
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
        // Main update loop for the NPC AI
        void UpdateAI(uint32 diff) override
        {
            scheduler.Update(diff);
            if (!UpdateVictim())
                return;
            // Cast spells on timers
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

// Wrapper for compatibility with script loader
extern "C" void AddSC_hinterlandbg_Varian_wrynn()
{
    AddSC_hinterlandbg_Varian_hinterlandbg();
}
