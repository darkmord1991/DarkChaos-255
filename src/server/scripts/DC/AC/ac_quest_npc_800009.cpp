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

    bool OnQuestAccept(Player* player, Creature* creature, Quest const* quest) override
    {
        if (!player || !creature || creature->GetEntry() != NPC_ID || !quest)
            return false;

        switch (quest->GetQuestId())
        {
            case Q_WELCOME:
                // creature:SendUnitSay("A warm Welcome to DC-WoW! We wish you all the fun! HÖHÖHÖ", 0)
                creature->Say("A warm Welcome to DC-WoW! We wish you all the fun! HÖHÖHÖ", LANG_UNIVERSAL);
                break;

            case Q_LEVELAREA:
            {
                // Spawn a temporary duplicate that performs the guidance so the original stays as quest giver
                if (Creature* mover = creature->SummonCreature(NPC_ID, creature->GetPosition(), TEMPSUMMON_TIMED_DESPAWN, 60000))
                {
                    mover->Whisper("Let me show you the Start of the Level Area of Ashzara Crater.", LANG_UNIVERSAL, player);
                    mover->GetMotionMaster()->MovePoint(1, 141.98f, 991.51f, 295.10f);
                    mover->GetMotionMaster()->MoveIdle();

                    mover->Whisper("We have lots of creatures living in the Crater, as it was never explored completely, its your turn now!", LANG_UNIVERSAL, player);
                    mover->GetMotionMaster()->MovePoint(2, 157.81f, 977.75f, 293.65f);
                    mover->GetMotionMaster()->MoveIdle();

                    // Third station
                    mover->GetMotionMaster()->MovePoint(3, 149.01f, 985.66f, 295.07f);
                    mover->GetMotionMaster()->MoveIdle();

                    // Fourth station
                    mover->GetMotionMaster()->MovePoint(4, 140.19f, 971.87f, 295.22f);
                    mover->GetMotionMaster()->MoveIdle();

                    mover->Whisper("This area is huge and has lots of different zones!", LANG_UNIVERSAL, player);
                    mover->Whisper("Go and start your journey, you will find lots of wild stuff, I am sure.", LANG_UNIVERSAL, player);
                    mover->Whisper("Use your start gear and your mobile teleporter pet to get around!", LANG_UNIVERSAL, player);
                    mover->Whisper("Do you see this Shrine? It is for more challenging experiences.", LANG_UNIVERSAL, player);
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
            case Q_WELCOME:
                // creature:SendUnitSay("For more questions please use the .faq commands or check on discord! There is also a world chat for everyone.", 0)
                creature->Say("For more questions please use the .faq commands or check on discord! There is also a world chat for everyone.", LANG_UNIVERSAL);
                break;
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
