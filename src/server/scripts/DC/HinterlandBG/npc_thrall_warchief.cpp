
/*
 * AzerothCore Custom Script: Hinterland BG - Thrall Warchief NPC
 *
 * Purpose / Feature Overview:
 * - Provides an in-world NPC (Thrall) used to trigger lore-based events,
 *   temporary buffs and map-wide interactions inside the Hinterland battleground.
 * - Exposes a simple gossip menu to initiate multi-step sequences. Used for
 *   demonstration and can be expanded into quest-like flows inside the BG.
 *
 * Implementation notes:
 * - Uses a TaskScheduler to sequence emotes and spells with delays which
 *   makes the script easier to read and less error-prone than manual timers.
 * - Removes the gossip flag while an event runs then restores it once the
 *   sequence completes so players cannot re-trigger while the event is active.
 * - The script is intentionally conservative about what it affects: it only
 *   targets players in specific area IDs when applying buffs to avoid
 *   accidentally buffing players outside the expected regions.
 *
 * Deployment / Integration:
 * - Place in src/server/scripts/DC/HinterlandBG/ and ensure it is added to
 *   the DC CMakeLists and that the DC loader calls AddSC_hinterlandbg_thrall_hinterlandbg().
 * - Creature template should set ScriptName="npc_thrall_hinterlandbg" and
 *   have the GOSSIP npcflag.
 *
 * TODO / Enhancements:
 * - Externalize the spell IDs and text lines to a config file to simplify
 *   tuning and localization.
 * - Add safety checks to avoid summoning creatures in occupied grids or
 *   when the map is unloading.
 * - Consider using a separate event state to persist across server restarts
 *   if events should be recoverable after a crash.
 * - Add role-based restrictions so only GMs or certain players can trigger
 *   the event in live environments.
 */
// --- Main Thrall Warchief NPC Script ---
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

enum ThrallWarchief : uint32
{
    SPELL_CHAIN_LIGHTNING          = 16033,
    SPELL_SHOCK                    = 16034,
    SPELL_WARCHIEF_BLESSING        = 16609,
    NPC_HERALD_OF_THRALL           = 10719,
    ACTION_START_TALKING           = 0,
    SAY_THRALL_ON_QUEST_REWARD_0   = 0,
    SAY_THRALL_ON_QUEST_REWARD_1   = 1,
    GO_UNADORNED_SPIKE             = 175787,
    GOSSIP_MENU_THRALL             = 3664,
    GOSSIP_RESPONSE_THRALL_FIRST   = 5733,
};

const Position heraldOfThrallPos = { -462.404f, -2637.68f, 96.0656f, 5.8606f };


// Main script class for Thrall Warchief
class npc_thrall_hinterlandbg : public CreatureScript
{
public:
    npc_thrall_hinterlandbg() : CreatureScript("npc_thrall_hinterlandbg") { }

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
            uint32 GossipResponse = GOSSIP_RESPONSE_THRALL_FIRST + DiscussionOrder - 1;
            // Add next gossip item and show response
            AddGossipItemFor(player, GOSSIP_MENU_THRALL + DiscussionOrder, 0, GOSSIP_SENDER_MAIN, NextAction);
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
        AddGossipItemFor(player, GOSSIP_MENU_THRALL, 0, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        // Show the gossip menu to the player
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    // OnQuestReward removed (no quest logic)

    // Returns the custom AI for this NPC
    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_thrall_hinterlandbgAI(creature);
    }

    // Custom AI logic for Thrall Warchief
    struct npc_thrall_hinterlandbgAI : public ScriptedAI
    {
        npc_thrall_hinterlandbgAI(Creature* creature) : ScriptedAI(creature) { }
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
                me->GetMap()->LoadGrid(heraldOfThrallPos.GetPositionX(), heraldOfThrallPos.GetPositionY());
                me->SummonCreature(NPC_HERALD_OF_THRALL, heraldOfThrallPos, TEMPSUMMON_TIMED_DESPAWN, 20 * IN_MILLISECONDS);
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
                    Talk(SAY_THRALL_ON_QUEST_REWARD_0);
                }).Schedule(9s, [this](TaskContext /*context*/)
                {
                    Talk(SAY_THRALL_ON_QUEST_REWARD_1);
                    DoCastAOE(SPELL_WARCHIEF_BLESSING, true);
                    me->SetNpcFlag(UNIT_NPC_FLAG_GOSSIP);
                    me->GetMap()->DoForAllPlayers([&](Player* player)
                    {
                        if (player->IsAlive() && !player->IsGameMaster())
                        {
                            if (player->GetAreaId() == AREA_ORGRIMMAR)
                            {
                                player->CastSpell(player, SPELL_WARCHIEF_BLESSING, true);
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
                                player->CastSpell(player, SPELL_WARCHIEF_BLESSING, true);
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


// Registration function for the script loader (extern "C" for stable linkage)
void AddSC_npc_thrall_hinterlandbg()
{
    new npc_thrall_hinterlandbg();
}
