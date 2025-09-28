/*
 * AzerothCore Custom Script: AC_Quest_NPC_800009 (CreatureScript)
 *
 * Purpose / Feature Overview:
 * - Native C++ replacement for two Eluna quest scripts bound to NPC 800009.
 * - Quest 820056 (Welcome): Sends a welcome line on accept and a follow-up on reward.
 * - Quest 820057 (LevelArea Show AC): On accept, spawns a temporary duplicate of the NPC
 *   that guides the player through four stations, whispering guidance as it moves; the
 *   original NPC remains stationary as the quest giver. The duplicate auto-despawns.
 *
 * Movement Path (Q820057 duplicate):
 *   - Station 1: (141.98, 991.51, 295.10)
 *   - Station 2: (157.81, 977.75, 293.65)
 *   - Station 3: (149.01, 985.66, 295.07)
 *   - Station 4: (140.19, 971.87, 295.22)
 *
 * Script Names and Integration:
 * - CreatureScript class name: AC_Quest_NPC_800009
 * - ScriptName to set in DB (creature_template.ScriptName): "AC_Quest_NPC_800009"
 * - Creature template entry: 800009 (ensure npcflag includes Quest Giver; Gossip optional)
 * - AIName should be empty (not SmartAI) so the C++ script runs.
 * - Loader registration function: AddSC_ac_quest_npc_800009() (wired in dc_script_loader.cpp)
 *
 * Replaces Eluna scripts:
 *  - Q820056 - Welcome.lua
 *  - Q820057 - LevelArea Show AC.lua
 *
 * Notes / Design:
 * - The duplicate uses the same entry (800009) and inherits the ScriptName; no extra DB rows needed.
 * - Chat uses Say/Whisper with LANG_UNIVERSAL so all players can read it.
 * - Returning false in hooks allows default processing to continue.
 */

#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "QuestDef.h"
#include "TemporarySummon.h"
#include "ScriptedCreature.h"
#include "TaskScheduler.h"
#include "ObjectAccessor.h"

namespace
{
    static constexpr uint32 NPC_ID   = 800009;
    static constexpr uint32 Q_WELCOME = 820056;
    static constexpr uint32 Q_LEVELAREA = 820057;
}

class AC_Quest_NPC_800009 : public CreatureScript
{
public:
    AC_Quest_NPC_800009() : CreatureScript("AC_Quest_NPC_800009") { }

    // Simple AI that can perform a guided tour for the summoned duplicate
    // Used by Quest 820057 (LevelArea Show AC) only. Q820056 does not use AI.
    struct AC_Quest_NPC_800009AI : public ScriptedAI
    {
        AC_Quest_NPC_800009AI(Creature* creature) : ScriptedAI(creature) { }

        TaskScheduler scheduler;
        ObjectGuid targetPlayerGuid;
        bool isTour = false;
        uint8 index = 0; // current waypoint index

        // Returns the tour station position for the given index (0..3)
        Position GetStation(uint8 i) const
        {
            Position pos;
            switch (i)
            {
                case 0: pos.Relocate(141.98f, 991.51f, 295.10f, 0.0f); break;
                case 1: pos.Relocate(157.81f, 977.75f, 293.65f, 0.0f); break;
                case 2: pos.Relocate(149.01f, 985.66f, 295.07f, 0.0f); break;
                case 3: pos.Relocate(140.19f, 971.87f, 295.22f, 0.0f); break;
                default: break;
            }
            return pos;
        }

        enum : int32 { ACTION_START_TOUR = 1 };

        void Reset() override
        {
            scheduler.CancelAll();
            isTour = false;
            index = 0;
        }

        void SetGUID(ObjectGuid guid, int32 /*type*/) override
        {
            // Store the player to guide
            targetPlayerGuid = guid;
        }

        void DoAction(int32 action) override
        {
            if (action == ACTION_START_TOUR)
            {
                // Mark this instance as the moving duplicate
                isTour = true;
                index = 0;
                me->SetWalk(false); // run, do not walk

                // Small delayed intro whisper
                scheduler.Schedule(1s, [this](TaskContext /*ctx*/)
                {
                    if (Player* player = ObjectAccessor::FindPlayer(targetPlayerGuid))
                        me->Whisper("Let me show you the Start of the Level Area of Ashzara Crater.", LANG_UNIVERSAL, player);
                });

                // Start moving to the first station immediately
                MoveToCurrentStation();
            }
        }

        void MoveToCurrentStation()
        {
            if (index < 4)
            {
                Position pos = GetStation(index);
                me->GetMotionMaster()->MovePoint(index + 1, pos);
            }
        }

        void MovementInform(uint32 type, uint32 id) override
        {
            if (!isTour || type != POINT_MOTION_TYPE)
                return;

            // id is 1-based, convert to 0-based index
            uint8 reached = (id > 0 ? id - 1 : 0);
            if (reached >= 4)
                return;

            // Stop for 3 seconds at each station
            me->GetMotionMaster()->MoveIdle();

            // Contextual delayed whispers at station 1 and final station
            if (Player* player = ObjectAccessor::FindPlayer(targetPlayerGuid))
            {
                if (reached == 0)
                {
                    scheduler.Schedule(1200ms, [this, player](TaskContext /*ctx*/)
                    {
                        me->Whisper("We have lots of creatures living in the Crater, as it was never explored completely, its your turn now!", LANG_UNIVERSAL, player);
                    });
                }
                else if (reached == 3)
                {
                    // Final station: chain a few short messages with small delays
                    scheduler.Schedule(1000ms, [this, player](TaskContext /*ctx*/)
                    {
                        me->Whisper("This area is huge and has lots of different zones!", LANG_UNIVERSAL, player);
                    }).Schedule(2000ms, [this, player](TaskContext /*ctx*/)
                    {
                        me->Whisper("Go and start your journey, you will find lots of wild stuff, I am sure.", LANG_UNIVERSAL, player);
                    }).Schedule(3000ms, [this, player](TaskContext /*ctx*/)
                    {
                        me->Whisper("Use your start gear and your mobile teleporter pet to get around!", LANG_UNIVERSAL, player);
                    }).Schedule(4000ms, [this, player](TaskContext /*ctx*/)
                    {
                        me->Whisper("Do you see this Shrine? It is for more challenging experiences.", LANG_UNIVERSAL, player);
                    }).Schedule(3500ms, [this](TaskContext /*ctx*/)
                    {
                        // Face the player and wave early to ensure animation is seen
                        if (Player* player = ObjectAccessor::FindPlayer(targetPlayerGuid))
                            me->SetFacingToObject(player);
                        me->HandleEmoteCommand(EMOTE_ONESHOT_WAVE);
                    }).Schedule(4500ms, [this](TaskContext /*ctx*/)
                    {
                        // Face again and give a friendly wave just before despawn
                        if (Player* player = ObjectAccessor::FindPlayer(targetPlayerGuid))
                            me->SetFacingToObject(player);
                        me->HandleEmoteCommand(EMOTE_ONESHOT_WAVE);
                    }).Schedule(4800ms, [this](TaskContext /*ctx*/)
                    {
                        // Face again and reinforce in case of client latency/animation cut-off
                        if (Player* player = ObjectAccessor::FindPlayer(targetPlayerGuid))
                            me->SetFacingToObject(player);
                        me->HandleEmoteCommand(EMOTE_ONESHOT_WAVE);
                    }).Schedule(5s, [this](TaskContext /*ctx*/)
                    {
                        // Despawn at current location 5 seconds after arriving at the last station
                        me->DespawnOrUnsummon();
                    });
                }
            }

            // After a 3-second pause, proceed to the next station (if any)
            scheduler.Schedule(3s, [this](TaskContext /*ctx*/)
            {
                if (index < 4)
                    ++index;
                if (index < 4)
                    MoveToCurrentStation();
            });
        }

        void UpdateAI(uint32 diff) override
        {
            scheduler.Update(diff);
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new AC_Quest_NPC_800009AI(creature);
    }

    bool OnQuestAccept(Player* player, Creature* creature, Quest const* quest) override
    {
        if (!player || !creature || creature->GetEntry() != NPC_ID || !quest)
            return false;

        switch (quest->GetQuestId())
        {
            // === Quest 820056: Welcome — OnQuestAccept ===
            case Q_WELCOME:
                // creature:SendUnitSay("A warm Welcome to DC-WoW! We wish you all the fun! HÖHÖHÖ", 0)
                creature->Say("A warm Welcome to DC-WoW! We wish you all the fun! HÖHÖHÖ", LANG_UNIVERSAL);
                break;

            // === Quest 820057: LevelArea Show AC — OnQuestAccept ===
            case Q_LEVELAREA:
            {
                // Spawn a temporary duplicate that performs the guidance so the original stays as quest giver
                if (Creature* mover = creature->SummonCreature(NPC_ID, creature->GetPosition(), TEMPSUMMON_TIMED_DESPAWN, 60000))
                {
                    if (mover->AI())
                    {
                        mover->AI()->SetGUID(player->GetGUID());
                        mover->AI()->DoAction(AC_Quest_NPC_800009AI::ACTION_START_TOUR);
                    }
                }
                break;
            }
            default:
                break;
        }
        // Return false to allow default processing to continue
        return false;
    }

    bool OnQuestReward(Player* player, Creature* creature, Quest const* quest, uint32 /*opt*/) override
    {
        if (!player || !creature || creature->GetEntry() != NPC_ID || !quest)
            return false;

        switch (quest->GetQuestId())
        {
            // === Quest 820056: Welcome — OnQuestReward ===
            case Q_WELCOME:
                // creature:SendUnitSay("For more questions please use the .faq commands or check on discord! There is also a world chat for everyone.", 0)
                creature->Say("For more questions please use the .faq commands or check on discord! There is also a world chat for everyone.", LANG_UNIVERSAL);
                break;
            // === Quest 820057: LevelArea Show AC — OnQuestReward ===
            case Q_LEVELAREA:
                creature->Whisper("Lots of fun with leveling to 80!", LANG_UNIVERSAL, player);
                // No despawn: original quest giver should remain; the summoned duplicate will auto-despawn
                break;
            default:
                break;
        }

        return false;
    }
};

void AddSC_ac_quest_npc_800009()
{
    new AC_Quest_NPC_800009();
}
