/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
 * more details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Silverpine Forest on map 751 -- the Forsaken High Command slice of the Neltharion 4.3.4 port.
//
// Source: Project Neltharion zone_silverpine_forest.cpp, lines 1-1138.
//
//   npc_warchief_cometh_controller   "The Warchief Cometh" (26965). Hosted on Grand Executor Mortuus 4144615.
//   npc_fallen_human_silverpine      the corpses Agatha raises, the static 4144592 (male) / 4144593 (female).
//   spell_forsaken_tropper_rand_transform   83149, "Forsaken Trooper Master Script".
//   spell_pick_up_orc_crate          "Steel Thunder" (27069), bound to the crate's own spell 83837.
//   npc_webbed_victim_silverpine     "Lost in the Darkness" (27093), the spawned cocoons 4144941.
//   npc_orc_sea_dog_rescued          the rescued sailor, the plain summon id 44942.
//
// Not ported, because what they drive does not exist on 751 (details in the coordinator report):
//   npc_forsaken_bat_vs_murlocs_vehicle   quest 26998 and the bat 44821 are not in the database.
//   npc_armoire_vehicle, npc_waiting_to_exsanguinate_controller   quest 27045 has no giver on 751, the
//       armoire 44893, Crowley 44883, Bloodfang 44884 and the controller 74953 do not exist, and the
//       summon/camera spells 83752, 83753, 83763, 83764 are in neither Spell.dbc nor spell_dbc.
//   npc_orc_sea_pup   44914 has no template, its display 34179 and vehicle 1060 are not in our DBCs, the
//       summon spell 83839 names SummonProperties 3026 (absent) and 83838 does not exist.
//
// THE WARCHIEF COMETH, 751 VERSION
// In 4.3.4 the quest put the player into phase 4, where a bunny (74954, Neltharion-custom) summoned a
// complete second cast: Sylvanas, three val'kyr, 14 corpses, portals, 17 elites, Garrosh and Cromush.
// Sylvanas, Garrosh, Cromush and Agatha then ran their lines from SmartAI timed action lists
// (nelt_world 4436500, 4462900, 4464000/4464001, 4460800). 751 has no phases: the static Agatha
// (4144608) and 11 corpses already lie on the exact spots the bunny summoned its copies at, and the
// bunny itself was never imported. So:
//   - Mortuus, who gives and takes the quest, hosts the controller and starts it on accept. A player who
//     already has the quest restarts it by talking to him (a cutscene cut off by a restart).
//   - the static Agatha and corpses act the raise; the corpses reset (respawn after 30 s) when it ends.
//   - Sylvanas (44365) and Cromush (44640) are imported at their plain ids by this slice's SQL, Garrosh
//     (44629) already exists. Daschla and Arthura are temporary copies of the 751 entries 4149128 and
//     4145314 (both flight-capable; quest flags are stripped from the copy).
//   - the SmartAI lists are replayed by the controller from the table below, timings unchanged.
//   - the portals (44630) and the 17 elites (44636) are left out: their displays 32698 and 34008 are not
//     in our CreatureDisplayInfo. Garrosh and Cromush arrive with "Simple Teleport" (12980) instead,
//     the spell the elites used.
//   - the source raised the corpses with 83173 (SRC_AREA_ENTRY). Our 83173 carries radius index 0, so
//     the area search finds nobody; Agatha still casts it for the visual and the controller raises each
//     corpse through DoAction(ACTION_RISE_FORSAKEN). SpellHit(83173) is kept for when the radius is fixed.
//   - the 8 random transform spells behind 83149 (83150..83168) are in no DBC; the spell script sets a
//     random Forsaken Trooper display of the corpse's gender instead (male 33986-33989 of Cata 44596,
//     female 34054-34057 of Cata 44792; 44597's female set 33991-33994 is not in our client).
// The SpellHit entry points of the source controller (98914 start, 98915 raise, 98916 end) are kept.
//
// Behaviour fixes against the source, each marked "Source:" where it happens:
//   - the periodic checks of the sea dog never re-armed their timer, so they ran on every tick.
//   - GetOwner() was dereferenced unguarded; the player is resolved from the stored GUID instead.

#include "CellImpl.h"
#include "CreatureScript.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "MotionMaster.h"
#include "MoveSpline.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptedCreature.h"
#include "SpellInfo.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "TaskScheduler.h"
#include "TemporarySummon.h"
#include "silverpine_dc.h"
#include <array>
#include <functional>
#include <vector>

namespace
{
    enum HighCommandSpells : uint32
    {
        // file-wide (source lines 42-58)
        SPELL_DUMMY_PING                    = 98914,
        SPELL_DUMMY_PING_2                  = 98915,
        SPELL_DUMMY_PING_3                  = 98916,
        SPELL_SANCTUARY_NO_COMBAT           = 88467,
        SPELL_ROOT                          = 42716,

        // WarchiefCometh
        SPELL_CAMERA_SHAKE                  = 47533,
        SPELL_SIMPLE_TELEPORT               = 12980,
        SPELL_RISE_FORSAKEN                 = 83173,
        SPELL_FORSAKEN_TRANSFORM            = 83149,
        SPELL_FEIGNED                       = 80636,    // the corpses' template aura

        // QuestSteelThunder: 83837 is what the Sea Dog Crate (4805165, spellcaster) casts on use. It force-casts
        // 83838 "Pick Up Orc Crate", the spell the source script was bound to, which does not exist here.
        SPELL_SEA_DOG_CRATE_USE             = 83837,
    };

    enum HighCommandEvents : uint32
    {
        // SilverpineEvents values (source lines 60-66)
        EVENT_WARCHIEF_COMETH_4             = 4,
        EVENT_WARCHIEF_COMETH_5             = 5,

        // not in the source: the corpses' own reset when the controller is gone
        EVENT_FALLEN_FAILSAFE_RESET         = 200,
    };

    enum HighCommandActions : int32
    {
        // not in the source (it only had SpellHit 83173, which cannot hit here); nothing else sends actions
        // to the corpses
        ACTION_RISE_FORSAKEN                = 1,
        ACTION_FALLEN_RESET                 = 2,
    };

    enum HighCommandPoints : uint32
    {
        POINT_RISE                          = 1,        // source MovePoint id
        POINT_AGATHA_RAISE                  = 1,        // waypoint 1 of nelt path 44608
        POINT_AGATHA_HOME                   = 2,        // waypoint 2 of nelt path 44608
    };

    enum HighCommandNpcs : uint32
    {
        // plain ids: summoned or credited by id, imported at the Cata id
        NPC_GARROSH_HELLSCREAM              = 44629,    // also the 26965 objective (RequiredNpcOrGo1 = 44629)
        NPC_HIGH_WARLORD_CROMUSH            = 44640,    // imported by this slice's SQL
        NPC_LADY_SYLVANAS                   = 44365,    // imported by this slice's SQL
        NPC_ORC_CRATE                       = 44915,    // the 27069 objective (RequiredNpcOrGo1 = 44915)
        NPC_ORC_SEA_DOG_RESCUED             = 44942,    // the 27093 objective (RequiredNpcOrGo1 = 44942)

        // spawned on 751: Cata entry + 4,100,000
        NPC_FALLEN_HUMAN_MALE               = SilverpineDC::Creature751(44592),
        NPC_FALLEN_HUMAN_FEMALE             = SilverpineDC::Creature751(44593),
        NPC_VALKYR_AGATHA                   = SilverpineDC::Creature751(44608),
        NPC_VALKYR_DASCHLA                  = SilverpineDC::Creature751(49128),
        NPC_VALKYR_ARTHURA                  = SilverpineDC::Creature751(45314),
        NPC_BLOODFANG_SCAVENGER             = SilverpineDC::Creature751(44547),
    };

    enum HighCommandQuests : uint32
    {
        QUEST_THE_WARCHIEF_COMETH           = 26965,
        QUEST_STEEL_THUNDER                 = 27069,
        QUEST_LOST_IN_THE_DARKNESS          = 27093,
    };

    // The source's summons all lived 300 s.
    constexpr uint32 SCENE_SUMMON_DESPAWN_MS = 300000;
    constexpr float SCENE_CREDIT_RANGE = 100.0f;
    constexpr float SCENE_ACTOR_SEARCH_RANGE = 40.0f;
    constexpr Seconds FALLEN_RESPAWN = 30s;

    Position const SylvanasPos      = { 1381.69f, 1041.260f, 54.317f, 4.028f };
    Position const DaschlaPos       = { 1365.73f, 1024.98f, 57.024f, 1.13446f };
    Position const ArthuraPos       = { 1360.81f, 1030.57f, 56.874f, 0.64577f };
    Position const GarroshPos       = { 1403.192f, 1065.561f, 60.478f, 3.93f };
    Position const CromushPos       = { 1405.383f, 1062.260f, 60.478f, 3.93f };
    // nelt 4462900 row 0 (SMART_ACTION_JUMP_TO_POS 20/20)
    Position const GarroshJumpPos   = { 1378.38f, 1043.68f, 53.768f, 3.9919f };
    // nelt path 44608: over the corpses, then back to where the static Agatha stands
    Position const AgathaRaisePos   = { 1368.67f, 1031.63f, 61.9359f, 0.0f };
    Position const AgathaHomePos    = { 1364.02f, 1028.54f, 55.9914f, 0.855f };

    // nelt path 44640, run (4464000 row 1); Cromush faces 4.35 at its end (44640 id 1)
    std::array<Position, 6> const CromushPath =
    { {
        { 1410.44f, 1089.35f, 60.47f, 0.0f },
        { 1402.73f, 1094.02f, 60.15f, 0.0f },
        { 1392.58f, 1089.38f, 56.32f, 0.0f },
        { 1376.37f, 1073.02f, 53.11f, 0.0f },
        { 1371.14f, 1055.20f, 53.12f, 0.0f },
        { 1374.08f, 1045.84f, 53.16f, 0.0f },
    } };
    constexpr float CROMUSH_END_FACING = 4.35f;

    // nelt path 44629, walk (4462900 row 16)
    std::array<Position, 4> const GarroshExitPath =
    { {
        { 1381.58f, 1046.06f, 53.946f, 0.0f },
        { 1375.18f, 1048.76f, 53.204f, 0.0f },
        { 1371.00f, 1064.11f, 53.058f, 0.0f },
        { 1380.23f, 1075.75f, 52.765f, 0.0f },
    } };

    enum class SceneActor : uint8
    {
        Sylvanas,
        Garrosh,
        Cromush,
    };

    struct SceneBeat
    {
        uint32 AtMs;            // from the start of the scene
        SceneActor Actor;
        int8 TalkGroup;         // creature_text group, NO_TALK for a turn only
        float Facing;           // NO_TURN for a line only
    };

    constexpr int8 NO_TALK = -1;
    constexpr float NO_TURN = -1.0f;

    // The talk and turn rows of nelt_world's timed action lists, as absolute times. Sylvanas's list starts
    // when she is summoned (0 s), Garrosh's and Cromush's when they are summoned (6 s). Movement, the raise
    // and the end are scheduled separately in StartCutscene().
    std::array<SceneBeat, 30> const SceneBeats =
    { {
        {      0, SceneActor::Sylvanas,  0, NO_TURN },  // "Where is that ogre-headed buffoon?"
        {   6000, SceneActor::Sylvanas, NO_TALK, 0.7584f },
        {   7000, SceneActor::Sylvanas,  1, NO_TURN },  // "Ah, speak of the devil..."
        {  10000, SceneActor::Sylvanas, NO_TALK, 3.837f },
        {  12000, SceneActor::Garrosh, NO_TALK, 5.533f },
        {  13000, SceneActor::Garrosh,   0, NO_TURN },
        {  22000, SceneActor::Garrosh, NO_TALK, 3.99f },
        {  22500, SceneActor::Garrosh,   1, NO_TURN },
        {  27500, SceneActor::Sylvanas,  2, 2.474f },
        {  31500, SceneActor::Sylvanas, NO_TALK, 3.837f },
        {  33500, SceneActor::Sylvanas,  3, NO_TURN },
        {  46500, SceneActor::Sylvanas,  4, NO_TURN },
        {  50500, SceneActor::Garrosh,   2, NO_TURN },
        {  55500, SceneActor::Sylvanas,  5, NO_TURN },
        {  60500, SceneActor::Sylvanas,  6, NO_TURN },
        {  65500, SceneActor::Sylvanas,  7, NO_TURN },
        {  72500, SceneActor::Sylvanas,  8, NO_TURN },  // "Agatha, show the Warchief!"
        {  91500, SceneActor::Garrosh,   3, NO_TURN },
        { 102500, SceneActor::Sylvanas,  9, NO_TURN },
        { 110500, SceneActor::Garrosh,   4, NO_TURN },
        { 115500, SceneActor::Garrosh,   5, NO_TURN },
        { 122000, SceneActor::Sylvanas, 10, NO_TURN },
        { 126500, SceneActor::Garrosh, NO_TALK, 5.533f },
        { 127000, SceneActor::Garrosh,   6, NO_TURN },
        { 132000, SceneActor::Garrosh, NO_TALK, 2.77f },
        { 132500, SceneActor::Garrosh,   7, NO_TURN },
        { 143500, SceneActor::Cromush, NO_TALK, 5.88f },
        { 144000, SceneActor::Cromush,   1, NO_TURN },  // "As you command, Warchief!"
        { 147500, SceneActor::Garrosh, NO_TALK, 5.533f },
        { 148000, SceneActor::Garrosh,   8, NO_TURN },
    } };

    constexpr Milliseconds SCENE_CAMERA_SHAKE_AT  = 1000ms;
    constexpr Milliseconds SCENE_WARCHIEF_ARRIVES = 6000ms;
    constexpr Milliseconds SCENE_WARCHIEF_MOVES   = 9000ms;
    constexpr Milliseconds SCENE_AGATHA_RAISES    = 75500ms;   // Sylvanas 4436500 row 14: 98915 to the controller
    constexpr Milliseconds SCENE_GARROSH_LEAVES   = 160000ms;
    constexpr Milliseconds SCENE_END              = 167000ms;  // Garrosh 4462900 row 17: 98916 to the controller

    // Polls every 500 ms; 40 polls = 20 s, more than any leg of these paths needs.
    constexpr uint8 MOVE_POLL_LIMIT = 40;

    // The source's GetPlayersInRange(range, alive).
    std::list<Player*> GetPlayersInRange(WorldObject* who, float range)
    {
        std::list<Player*> players;
        Acore::AnyPlayerInObjectRangeCheck checker(who, range, true);
        Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck> searcher(who, players, checker);
        Cell::VisitObjects(who, searcher, range);
        return players;
    }

    // ---------------------------------------------------------------------------------------------------
    // The Warchief Cometh (26965) -- the controller, on Grand Executor Mortuus (4144615)
    // ---------------------------------------------------------------------------------------------------
    struct npc_warchief_cometh_controller : public ScriptedAI
    {
        npc_warchief_cometh_controller(Creature* creature) : ScriptedAI(creature), summons(me) { }

        void sQuestAccept(Player* /*player*/, Quest const* quest) override
        {
            // nelt: Mortuus's SmartAI cast 98914 on the bunny when this quest was accepted
            if (quest->GetQuestId() == QUEST_THE_WARCHIEF_COMETH)
                StartCutscene();
        }

        void sGossipHello(Player* player) override
        {
            // Not in the source: without phases there is nothing else to replay a scene that was cut off
            if (!_cutsceneInProgress && player->GetQuestStatus(QUEST_THE_WARCHIEF_COMETH) == QUEST_STATUS_INCOMPLETE)
                StartCutscene();
        }

        void SpellHit(Unit* /*caster*/, SpellInfo const* spellInfo) override
        {
            switch (spellInfo->Id)
            {
                case SPELL_DUMMY_PING:
                    StartCutscene();
                    break;
                case SPELL_DUMMY_PING_2:
                    if (_cutsceneInProgress)
                        StartAgathaRaise();
                    break;
                case SPELL_DUMMY_PING_3:
                    FinishCutscene(true);
                    break;
                default:
                    break;
            }
        }

        void JustDied(Unit* /*killer*/) override
        {
            FinishCutscene(false);
        }

        void UpdateAI(uint32 diff) override
        {
            _scheduler.Update(diff);

            if (!UpdateVictim())
                return;

            DoMeleeAttackIfReady();
        }

    private:
        void StartCutscene()
        {
            if (_cutsceneInProgress)
                return;

            _cutsceneInProgress = true;
            _agathaRaiseStarted = false;
            ++_run;

            _sylvanasGUID.Clear();
            _garroshGUID.Clear();
            _cromushGUID.Clear();

            SummonCourt();
            FindWorldActors();

            At(SCENE_CAMERA_SHAKE_AT, [this]()
            {
                DoCastSelf(SPELL_CAMERA_SHAKE, true);
            });

            At(SCENE_WARCHIEF_ARRIVES, [this]()
            {
                SummonWarchief();
            });

            At(SCENE_WARCHIEF_MOVES, [this]()
            {
                if (Creature* garrosh = Actor(_garroshGUID))
                    garrosh->GetMotionMaster()->MoveJump(GarroshJumpPos, 20.0f, 20.0f);

                WalkPath(_cromushGUID, CromushPath.data(), uint8(CromushPath.size()), FORCED_MOVEMENT_RUN, 0,
                    [](Creature* cromush)
                    {
                        cromush->SetFacingTo(CROMUSH_END_FACING);
                    });
            });

            for (SceneBeat const& beat : SceneBeats)
                At(Milliseconds(beat.AtMs), [this, beat]()
                {
                    PlayBeat(beat);
                });

            At(SCENE_AGATHA_RAISES, [this]()
            {
                StartAgathaRaise();
            });

            At(SCENE_GARROSH_LEAVES, [this]()
            {
                WalkPath(_garroshGUID, GarroshExitPath.data(), uint8(GarroshExitPath.size()), FORCED_MOVEMENT_WALK, 0,
                    nullptr);
            });

            At(SCENE_END, [this]()
            {
                FinishCutscene(true);
            });
        }

        // Sylvanas, and the two val'kyr the static Agatha does not stand in for.
        void SummonCourt()
        {
            if (Creature* sylvanas = me->SummonCreature(NPC_LADY_SYLVANAS, SylvanasPos, TEMPSUMMON_TIMED_DESPAWN,
                SCENE_SUMMON_DESPAWN_MS))
            {
                // nelt 4436500 row 0: SMART_ACTION_SET_NPC_FLAG 0
                sylvanas->ReplaceAllNpcFlags(UNIT_NPC_FLAG_NONE);
                _sylvanasGUID = sylvanas->GetGUID();
                summons.Summon(sylvanas);
            }

            for (auto const& [entry, pos] : { std::pair<uint32, Position>(NPC_VALKYR_DASCHLA, DaschlaPos),
                std::pair<uint32, Position>(NPC_VALKYR_ARTHURA, ArthuraPos) })
            {
                if (Creature* valkyr = me->SummonCreature(entry, pos, TEMPSUMMON_TIMED_DESPAWN,
                    SCENE_SUMMON_DESPAWN_MS))
                {
                    // 4145314 is a quest giver at the Sepulcher; this copy only hovers
                    valkyr->ReplaceAllNpcFlags(UNIT_NPC_FLAG_NONE);
                    valkyr->SetDisableGravity(true);
                    summons.Summon(valkyr);
                }
            }
        }

        void SummonWarchief()
        {
            if (Creature* garrosh = me->SummonCreature(NPC_GARROSH_HELLSCREAM, GarroshPos, TEMPSUMMON_TIMED_DESPAWN,
                SCENE_SUMMON_DESPAWN_MS))
            {
                garrosh->CastSpell(garrosh, SPELL_SIMPLE_TELEPORT, true);
                _garroshGUID = garrosh->GetGUID();
                summons.Summon(garrosh);
            }

            if (Creature* cromush = me->SummonCreature(NPC_HIGH_WARLORD_CROMUSH, CromushPos, TEMPSUMMON_TIMED_DESPAWN,
                SCENE_SUMMON_DESPAWN_MS))
            {
                // nelt 4464000 row 0: SMART_ACTION_SET_NPC_FLAG 0
                cromush->ReplaceAllNpcFlags(UNIT_NPC_FLAG_NONE);
                cromush->CastSpell(cromush, SPELL_SIMPLE_TELEPORT, true);
                _cromushGUID = cromush->GetGUID();
                summons.Summon(cromush);
            }
        }

        // The static Agatha and corpses that stand in for the source's summoned copies.
        void FindWorldActors()
        {
            _agathaGUID.Clear();
            if (Creature* agatha = me->FindNearestCreature(NPC_VALKYR_AGATHA, SCENE_ACTOR_SEARCH_RANGE))
                _agathaGUID = agatha->GetGUID();

            _fallenGUIDs.clear();
            std::list<Creature*> fallen;
            me->GetCreatureListWithEntryInGrid(fallen, { NPC_FALLEN_HUMAN_MALE, NPC_FALLEN_HUMAN_FEMALE },
                SCENE_ACTOR_SEARCH_RANGE);
            for (Creature* corpse : fallen)
                _fallenGUIDs.push_back(corpse->GetGUID());
        }

        void PlayBeat(SceneBeat const& beat)
        {
            ObjectGuid guid;
            switch (beat.Actor)
            {
                case SceneActor::Sylvanas:
                    guid = _sylvanasGUID;
                    break;
                case SceneActor::Garrosh:
                    guid = _garroshGUID;
                    break;
                case SceneActor::Cromush:
                    guid = _cromushGUID;
                    break;
            }

            Creature* actor = Actor(guid);
            if (!actor)
                return;

            if (beat.Facing >= 0.0f)
                actor->SetFacingTo(beat.Facing);

            if (beat.TalkGroup >= 0)
                actor->AI()->Talk(uint8(beat.TalkGroup));
        }

        // Source: agatha->AI()->SetData(1, 1), which started her SmartAI path 44608. Agatha 4144608 has no
        // AI on 751, so the controller flies her itself: over the corpses, raise after 1 s, Cromush's
        // outburst and the way back after the 10 s pause of 4460800.
        void StartAgathaRaise()
        {
            if (_agathaRaiseStarted)
                return;

            _agathaRaiseStarted = true;

            Creature* agatha = Actor(_agathaGUID);
            if (!agatha)
            {
                At(1s, [this]()
                {
                    RaiseFallen();
                });
                return;
            }

            agatha->GetMotionMaster()->MovePoint(POINT_AGATHA_RAISE, AgathaRaisePos, FORCED_MOVEMENT_NONE, 0.0f, false);
            WhenStopped(_agathaGUID, [this](Creature* /*agatha*/)
            {
                At(1s, [this]()
                {
                    if (Creature* agatha = Actor(_agathaGUID))
                        agatha->CastSpell(agatha, SPELL_RISE_FORSAKEN, true);

                    RaiseFallen();
                });

                At(10s, [this]()
                {
                    if (Creature* cromush = Actor(_cromushGUID))
                        cromush->AI()->Talk(0);     // "ABBERATION!"

                    SendAgathaHome();
                });
            });
        }

        void SendAgathaHome()
        {
            Creature* agatha = Actor(_agathaGUID);
            if (!agatha || agatha->GetExactDist(&AgathaHomePos) < 0.5f)
                return;

            agatha->GetMotionMaster()->MovePoint(POINT_AGATHA_HOME, AgathaHomePos, FORCED_MOVEMENT_NONE, 0.0f, false);
            WhenStopped(_agathaGUID, [](Creature* agatha)
            {
                agatha->SetFacingTo(AgathaHomePos.GetOrientation());
            });
        }

        void RaiseFallen()
        {
            for (ObjectGuid const& guid : _fallenGUIDs)
                if (Creature* corpse = Actor(guid))
                    corpse->AI()->DoAction(ACTION_RISE_FORSAKEN);
        }

        void FinishCutscene(bool credit)
        {
            if (!_cutsceneInProgress)
                return;

            _cutsceneInProgress = false;
            ++_run;     // every step still queued for this run is now a no-op

            summons.DespawnAll();

            for (ObjectGuid const& guid : _fallenGUIDs)
                if (Creature* corpse = Actor(guid))
                    corpse->AI()->DoAction(ACTION_FALLEN_RESET);

            if (Creature* agatha = Actor(_agathaGUID))
                if (agatha->GetExactDist(&AgathaHomePos) >= 0.5f)
                    agatha->GetMotionMaster()->MovePoint(POINT_AGATHA_HOME, AgathaHomePos, FORCED_MOVEMENT_NONE, 0.0f,
                        false);

            if (!credit)
                return;

            for (Player* player : GetPlayersInRange(me, SCENE_CREDIT_RANGE))
                if (player->GetQuestStatus(QUEST_THE_WARCHIEF_COMETH) == QUEST_STATUS_INCOMPLETE)
                    player->KilledMonsterCredit(NPC_GARROSH_HELLSCREAM);
        }

        Creature* Actor(ObjectGuid const& guid) const
        {
            return guid ? ObjectAccessor::GetCreature(*me, guid) : nullptr;
        }

        // A scene step that only runs if the scene it was queued for is still the running one.
        void At(Milliseconds when, std::function<void()> step)
        {
            _scheduler.Schedule(when, [this, run = _run, step = std::move(step)](TaskContext /*context*/)
            {
                if (run == _run)
                    step();
            });
        }

        // Runs `then` once the actor's current spline has finished (or after MOVE_POLL_LIMIT polls, so a stuck
        // actor cannot stall the scene).
        void WhenStopped(ObjectGuid guid, std::function<void(Creature*)> then)
        {
            _scheduler.Schedule(500ms, [this, run = _run, guid, then = std::move(then)](TaskContext context)
            {
                if (run != _run)
                    return;

                Creature* actor = Actor(guid);
                if (!actor)
                    return;

                if (!actor->movespline->Finalized() && context.GetRepeatCounter() < MOVE_POLL_LIMIT)
                {
                    context.Repeat();
                    return;
                }

                then(actor);
            });
        }

        // A SmartAI waypoint path, leg by leg with path generation.
        void WalkPath(ObjectGuid guid, Position const* path, uint8 count, ForcedMovement movement, uint8 index,
            std::function<void(Creature*)> done)
        {
            Creature* actor = Actor(guid);
            if (!actor)
                return;

            if (index >= count)
            {
                if (done)
                    done(actor);
                return;
            }

            actor->GetMotionMaster()->MovePoint(index + 1, path[index], movement);
            WhenStopped(guid, [this, guid, path, count, movement, index, done](Creature* /*actor*/)
            {
                WalkPath(guid, path, count, movement, index + 1, done);
            });
        }

        TaskScheduler _scheduler;
        SummonList summons;
        uint32 _run = 0;
        bool _cutsceneInProgress = false;
        bool _agathaRaiseStarted = false;

        ObjectGuid _sylvanasGUID;
        ObjectGuid _garroshGUID;
        ObjectGuid _cromushGUID;
        ObjectGuid _agathaGUID;
        std::vector<ObjectGuid> _fallenGUIDs;
    };

    // ---------------------------------------------------------------------------------------------------
    // Fallen Human (4144592 male / 4144593 female): lifted 5 yards, dropped, stands up as a Forsaken Trooper
    // ---------------------------------------------------------------------------------------------------
    struct npc_fallen_human_silverpine : public ScriptedAI
    {
        npc_fallen_human_silverpine(Creature* creature) : ScriptedAI(creature) { }

        void Reset() override
        {
            _events.Reset();
            _risen = false;

            // A respawn restores display, addon and aura but not unit_flags2, so lay the body down again.
            if (me->GetCreatureTemplate()->unit_flags2 & UNIT_FLAG2_FEIGN_DEATH)
                me->SetUnitFlag2(UNIT_FLAG2_FEIGN_DEATH);
        }

        void SpellHit(Unit* /*caster*/, SpellInfo const* spellInfo) override
        {
            if (spellInfo->Id == SPELL_RISE_FORSAKEN)
                Rise();
        }

        void DoAction(int32 action) override
        {
            if (action == ACTION_RISE_FORSAKEN)
                Rise();
            else if (action == ACTION_FALLEN_RESET && _risen)
                me->DespawnOrUnsummon(0ms, FALLEN_RESPAWN);
        }

        void UpdateAI(uint32 diff) override
        {
            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_WARCHIEF_COMETH_4:
                        me->GetMotionMaster()->MoveJump(_corpsePos, 10.0f, 10.0f);
                        _events.ScheduleEvent(EVENT_WARCHIEF_COMETH_5, 1s);
                        break;
                    case EVENT_WARCHIEF_COMETH_5:
                        StandAsForsaken();
                        break;
                    case EVENT_FALLEN_FAILSAFE_RESET:
                        me->DespawnOrUnsummon(0ms, FALLEN_RESPAWN);
                        break;
                    default:
                        break;
                }
            }
        }

    private:
        void Rise()
        {
            if (_risen)
                return;

            _risen = true;
            _corpsePos = me->GetPosition();

            // The val'kyr lifts the body: without DisableGravity the spline would stay on the ground.
            me->SetDisableGravity(true);
            me->GetMotionMaster()->MovePoint(POINT_RISE, me->GetPositionX(), me->GetPositionY(),
                me->GetPositionZ() + 5.0f, FORCED_MOVEMENT_NONE, 0.0f, 0.0f, false);
            _events.ScheduleEvent(EVENT_WARCHIEF_COMETH_4, 8500ms);
        }

        void StandAsForsaken()
        {
            me->SetDisableGravity(false);

            // Source: RemoveByteFlag(UNIT_FIELD_BYTES_1, 0, 7). On 751 the corpses lie dead through
            // UNIT_FLAG2_FEIGN_DEATH (template unit_flags2 2049) and the "Feigned" aura instead.
            me->RemoveAurasDueToSpell(SPELL_FEIGNED);
            me->RemoveUnitFlag2(UNIT_FLAG2_FEIGN_DEATH);
            me->SetStandState(UNIT_STAND_STATE_STAND);

            DoCastSelf(SPELL_FORSAKEN_TRANSFORM, true);
            me->SetFacingTo(0.7224f);

            // The source's corpses were summons that died with the scene after at most 300 s.
            _events.ScheduleEvent(EVENT_FALLEN_FAILSAFE_RESET, 300s);
        }

        EventMap _events;
        Position _corpsePos;
        bool _risen = false;
    };

    // ---------------------------------------------------------------------------------------------------
    // 83149 "Forsaken Trooper Master Script"
    // ---------------------------------------------------------------------------------------------------
    std::array<uint32, 4> const TrooperDisplaysMale = { 33986, 33987, 33988, 33989 };
    std::array<uint32, 4> const TrooperDisplaysFemale = { 34054, 34055, 34056, 34057 };

    class spell_forsaken_tropper_rand_transform : public SpellScript
    {
        PrepareSpellScript(spell_forsaken_tropper_rand_transform);

        // Source: cast one of 83149, 83150, 83152, 83163-83168 at random. Only 83149 (this spell) exists here,
        // so the transform is done directly, keeping the corpse's gender (creature_model_info.Gender).
        void HandleScriptEffect(SpellEffIndex /*effIndex*/)
        {
            Unit* caster = GetCaster();
            if (!caster)
                return;

            bool female = false;
            if (CreatureModelInfo const* modelInfo = sObjectMgr->GetCreatureModelInfo(caster->GetNativeDisplayId()))
                female = modelInfo->gender == GENDER_FEMALE;

            std::array<uint32, 4> const& displays = female ? TrooperDisplaysFemale : TrooperDisplaysMale;
            caster->SetDisplayId(displays[urand(0, uint32(displays.size()) - 1)]);
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(spell_forsaken_tropper_rand_transform::HandleScriptEffect, EFFECT_0,
                SPELL_EFFECT_SCRIPT_EFFECT);
        }
    };

    // ---------------------------------------------------------------------------------------------------
    // Steel Thunder (27069): 83837, cast by the player who uses a Sea Dog Crate
    // ---------------------------------------------------------------------------------------------------
    // Source chain: crate -> 83838 on the player's Orc Sea Pup -> 98914 ping -> the pup casts 83843
    // (KILL_CREDIT2 44915 to its master) and stacks the crate on its back. Neither 83838 nor the pup exists
    // here, so the crate's own spell grants the same credit. Only a player on the quest can use a crate,
    // so nobody else uses up its single charge.
    class spell_pick_up_orc_crate : public SpellScript
    {
        PrepareSpellScript(spell_pick_up_orc_crate);

        SpellCastResult CheckQuest()
        {
            Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!player || player->GetQuestStatus(QUEST_STEEL_THUNDER) != QUEST_STATUS_INCOMPLETE)
                return SPELL_FAILED_DONT_REPORT;

            return SPELL_CAST_OK;
        }

        void HandleForceCast(SpellEffIndex effIndex)
        {
            // The forced spell, 83838, is not in Spell.dbc or spell_dbc.
            PreventHitDefaultEffect(effIndex);

            if (Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr)
                player->KilledMonsterCredit(NPC_ORC_CRATE);
        }

        void Register() override
        {
            OnCheckCast += SpellCheckCastFn(spell_pick_up_orc_crate::CheckQuest);
            OnEffectHitTarget += SpellEffectFn(spell_pick_up_orc_crate::HandleForceCast, EFFECT_0,
                SPELL_EFFECT_FORCE_CAST);
        }
    };

    // ---------------------------------------------------------------------------------------------------
    // Lost in the Darkness (27093): Webbed Victim cocoons (4144941)
    // ---------------------------------------------------------------------------------------------------
    struct npc_webbed_victim_silverpine : public ScriptedAI
    {
        npc_webbed_victim_silverpine(Creature* creature) : ScriptedAI(creature) { }

        void JustDied(Unit* killer) override
        {
            Player* player = killer ? killer->GetCharmerOrOwnerPlayerOrPlayerItself() : nullptr;
            if (!player || player->GetQuestStatus(QUEST_LOST_IN_THE_DARKNESS) != QUEST_STATUS_INCOMPLETE)
                return;

            // 3 in 5: an Orc Sea Dog was in the web. 2 in 5: a Bloodfang Scavenger (44547, spawned as 4144547).
            if (urand(0, 4) <= 2)
            {
                // Source: player->CastSpell(player, 83927). 83927 names SummonProperties 3028, which our
                // SummonProperties.dbc does not have, so the summon would fail; summon directly with the
                // spell's 10 minute duration. The sailor's AI grants the credit.
                player->SummonCreature(NPC_ORC_SEA_DOG_RESCUED, me->GetPosition(), TEMPSUMMON_TIMED_OR_DEAD_DESPAWN,
                    600000);
            }
            else
                me->SummonCreature(NPC_BLOODFANG_SCAVENGER, me->GetPosition(), TEMPSUMMON_TIMED_DESPAWN, 90000);
        }

        // The cocoon cannot fight (flags_extra CANNOT_ENTER_COMBAT).
        void UpdateAI(uint32 /*diff*/) override { }
    };

    // ---------------------------------------------------------------------------------------------------
    // Orc Sea Dog, rescued (44942): follows the rescuer, helps in fights, cheers when the quest is handed in
    // ---------------------------------------------------------------------------------------------------
    struct npc_orc_sea_dog_rescued : public ScriptedAI
    {
        npc_orc_sea_dog_rescued(Creature* creature) : ScriptedAI(creature) { }

        void IsSummonedBy(WorldObject* summoner) override
        {
            Player* player = summoner ? summoner->ToPlayer() : nullptr;
            if (!player)
            {
                me->DespawnOrUnsummon(1s);
                return;
            }

            _playerGUID = player->GetGUID();
            me->SetReactState(REACT_PASSIVE);
            Talk(0, player, 1s);
            FollowPlayer(player);
            player->KilledMonsterCredit(NPC_ORC_SEA_DOG_RESCUED);

            // Source: the 1 s check never reset its timer, so it ran on every update after the first second.
            _scheduler.Schedule(1s, [this](TaskContext context)
            {
                if (CheckPlayer())
                    context.Repeat();
            });
        }

        void EnterEvadeMode(EvadeReason /*why*/) override
        {
            // A summon without an owner would walk back to the cocoon; go back to the rescuer instead.
            me->CombatStop(true);
            me->GetThreatMgr().ClearAllThreat();
            me->SetReactState(REACT_PASSIVE);

            if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                FollowPlayer(player);
        }

        void UpdateAI(uint32 diff) override
        {
            _scheduler.Update(diff);

            if (!UpdateVictim())
                return;

            DoMeleeAttackIfReady();
        }

    private:
        void FollowPlayer(Player* player)
        {
            me->GetMotionMaster()->MoveFollow(player, frand(0.9f, 2.0f), frand(0.0f, 2.0f * float(M_PI)));
        }

        // Returns false once the sea dog is leaving.
        bool CheckPlayer()
        {
            Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
            if (!player || !player->IsAlive())
            {
                me->DespawnOrUnsummon();
                return false;
            }

            QuestStatus const status = player->GetQuestStatus(QUEST_LOST_IN_THE_DARKNESS);
            if (status == QUEST_STATUS_NONE)
            {
                me->DespawnOrUnsummon();
                return false;
            }

            if (status == QUEST_STATUS_REWARDED)
            {
                DoCastSelf(SPELL_ROOT, true);
                me->SetFacingToObject(player);
                me->HandleEmoteCommand(EMOTE_ONESHOT_CHEER);
                me->DespawnOrUnsummon(1500ms);
                return false;
            }

            Unit* playerVictim = player->GetVictim();
            if (!me->GetVictim() && me->GetReactState() != REACT_AGGRESSIVE && playerVictim)
            {
                me->SetReactState(REACT_AGGRESSIVE);
                AttackStart(playerVictim);
            }

            if (me->GetReactState() != REACT_PASSIVE && !playerVictim)
            {
                me->SetReactState(REACT_PASSIVE);
                DoCastSelf(SPELL_SANCTUARY_NO_COMBAT, true);
                me->CombatStop(true);
                me->GetThreatMgr().ClearAllThreat();
                FollowPlayer(player);
            }

            return true;
        }

        TaskScheduler _scheduler;
        ObjectGuid _playerGUID;
    };
}

void AddSC_dc_silverpine_high_command()
{
    RegisterCreatureAI(npc_warchief_cometh_controller);
    RegisterCreatureAI(npc_fallen_human_silverpine);
    RegisterSpellScript(spell_forsaken_tropper_rand_transform);
    RegisterSpellScript(spell_pick_up_orc_crate);
    RegisterCreatureAI(npc_webbed_victim_silverpine);
    RegisterCreatureAI(npc_orc_sea_dog_rescued);
}
