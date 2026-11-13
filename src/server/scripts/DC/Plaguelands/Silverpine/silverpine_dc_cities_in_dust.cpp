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

// Silverpine Forest on map 751 -- the last slice of Neltharion's zone_silverpine_forest.cpp
// (source lines 4804-6007):
//
//   npc_mutant_bush_chicken      quest 27088 "It's Only Poisonous if You Ingest It"
//   npc_sylvanas_cities_in_dust  quest 27601 "Cities in Dust": Sylvanas walks from the Forsaken
//   npc_cities_in_dust_actors      High Command to the Battlefront, parleys with Crowley, is shot
//   npc_cities_in_dust_enemies     by Godfrey and raised again by her val'kyr.
//
// Departures from the source, all deliberate:
//
//  1. No phasing. The source put the whole scene in phase 2048 and ended it for everyone else
//     with a "triggered by another player" whisper. Here every actor is summoned BY THE PLAYER
//     with visibleBySummonerOnly, so each player gets a private copy of the scene and nobody
//     else can see or touch it. Actor lookups are filtered on that summoner GUID
//     (FindSceneActor), so two players running the scene side by side never cross-talk.
//     What this cannot hide: the actors' says and yells still reach players standing nearby.
//  2. The Neltharion helper spells 151332-151335 and the dummy pings 98914-98916 are replaced
//     by DoAction. The action ids ARE those spell ids, so the mapping stays readable.
//  3. The quest-accept trigger lives here (playerscript_silverpine_cities_in_dust). In the
//     source it was the questgiver's SmartAI (45617, event 19) casting 85955, a spell no client
//     has, which cast the five summon spells 85864/85868-85871. Those use SummonProperties
//     3050, which is not in this server's SummonProperties.dbc, so they would summon nothing.
//     Do NOT also port that SmartAI: the scene would start twice.
//  4. Sylvanas's escort AI is a plain point walker: npc_escortAI's despawn-when-far and its
//     flag handling do not fit a private scene. She waits at a waypoint while the player is
//     more than 40 yards away instead of despawning (the source despawned at 50).
//  5. Godfrey carried Lorna in vehicle seat 1170, which is not in this Vehicle.dbc. Lorna is
//     led behind him with a follow movement instead.
//  6. The facing target bunny (75042) is replaced by its fixed position.
//  7. The forest ettin's half of the chicken event (its SmartAI pinged the chicken when it was
//     within 3 yards, then attacked the nearest player when the explosion hit it) is done by
//     the chicken: our ettin 4144367 has only its combat SmartAI.

#include "CreatureScript.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "PlayerScript.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "TemporarySummon.h"
#include "silverpine_dc.h"

#include <list>
#include <vector>

namespace
{
    // Event ids keep the source's SilverpineEvents numbering.
    enum CitiesInDustEvents
    {
        EVENT_DOOMHOWL                  = 11,
        EVENT_UNHOLY_SMITE              = 12,
        EVENT_WALDEN_SMITE              = 51,
        EVENT_WALDEN_HOLYNOVA           = 52,
        EVENT_GODFREY_FIREBALL          = 53,
        EVENT_GODFREY_BLASTWAVE         = 54,
        EVENT_GODFREY_FLAMESTRIKE       = 55,
        EVENT_ASHBURY_MINDBLAST         = 56,
        EVENT_ASHBURY_PAIN              = 57,
        EVENT_MUTANT_CHICKEN_1          = 78,
        EVENT_FINAL_SCENE_1             = 79,
        EVENT_FINAL_SCENE_2             = 80,
        EVENT_FINAL_SCENE_3             = 81,
        EVENT_FINAL_SCENE_FACING        = 82,
        EVENT_FINAL_SCENE_AGATHA_FACING = 83,
        EVENT_FINAL_SCENE_FACING_2      = 84,
        EVENT_FINAL_LOW_HP              = 86,
        EVENT_FINAL_SCENE_4             = 87,
        EVENT_FINAL_SCENE_5             = 88,
        EVENT_FINAL_SCENE_6             = 89,
        EVENT_FINAL_SCENE_7             = 90,
        EVENT_FINAL_SCENE_8             = 91,
        EVENT_FINAL_SCENE_9             = 92,
        EVENT_FINAL_SCENE_10            = 93,
        EVENT_FINAL_SCENE_11            = 94,
        EVENT_FINAL_SCENE_12            = 95,
        EVENT_FINAL_SCENE_13            = 96,
        EVENT_FINAL_SCENE_14            = 97,
        EVENT_FINAL_SCENE_15            = 98,
        EVENT_FINAL_SCENE_16            = 99,
        EVENT_FINAL_SCENE_17            = 100,
        EVENT_FINAL_SCENE_18            = 101,
        EVENT_FINAL_SCENE_19            = 102,
        EVENT_FINAL_SCENE_20            = 103,
        EVENT_FINAL_SCENE_22            = 105,
        EVENT_FINAL_SCENE_23            = 106,
        EVENT_FINAL_SCENE_24            = 107,
        EVENT_FINAL_SCENE_25            = 108,
        EVENT_FINAL_SCENE_26            = 109,
        EVENT_FINAL_SCENE_27            = 110,
        EVENT_FINAL_SCENE_28            = 111,
        EVENT_THUNDERCLAP               = 112,
        EVENT_MORTAL_STRIKE             = 113,

        // Added by this port: stand-ins for CastWithDelay, the escort AI and the check timers.
        EVENT_NEXT_WAYPOINT             = 200,
        EVENT_SONG_AND_ROOT             = 201,
        EVENT_GODFREY_SHOOT             = 202,
        EVENT_RAISE_FORSAKEN            = 203,
        EVENT_PING_SYLVANAS_3           = 204,
        EVENT_CHICKEN_EXPLODE           = 205,
        EVENT_SCENE_CHECK               = 206
    };

    // DoAction ids = the ids of the spells the source pinged with.
    enum CitiesInDustActions
    {
        ACTION_DUMMY_PING          = 98914,
        ACTION_DUMMY_PING_2        = 98915,
        ACTION_DUMMY_PING_3        = 98916,
        ACTION_PING_ACTORS_1       = 151332,
        ACTION_PING_ACTORS_DESPAWN = 151333,
        ACTION_PING_ACTORS_2       = 151334,
        ACTION_PING_ACTORS_ENEMIES = 151335
    };

    enum CitiesInDustData
    {
        DATA_SYLVANAS_GUID = 1,
        DATA_LORNA_GUID    = 2
    };

    enum CitiesInDust
    {
        // Summoned, never spawned: plain Cata ids (imported by this slice's SQL).
        NPC_FINAL_SYLVANAS         = 46026,
        NPC_FINAL_LORNA            = 46027,
        NPC_FINAL_GODFREY          = 46028,
        NPC_FINAL_WALDEN           = 46029,
        NPC_FINAL_ASHBURY          = 46030,
        NPC_FINAL_CROMUSH          = 46031,
        NPC_FINAL_ARTHURA          = 46032,
        NPC_FINAL_DASCHLA          = 46033,
        NPC_FINAL_AGATHA           = 46034,
        NPC_FINAL_BLOODFANG        = 46035,
        NPC_FINAL_CROWLEY          = 46036,
        // Quest 27601's objective (RequiredNpcOrGo1 in the 4.3.4 data).
        NPC_CITIES_IN_DUST_CREDIT  = 46019,

        QUEST_CITIES_IN_DUST       = 27601,

        SPELL_SONG_OF_SYLVANAS     = 85874,
        SPELL_FINAL_RAISE_FORSAKEN = 85950,
        SPELL_ROOT                 = 42716,
        SPELL_SANCTUARY_NO_COMBAT  = 88467,
        SPELL_GODFREY_SHOOT        = 74279,
        SPELL_PERMANENT_DEATH_ANIM = 29266,
        SPELL_TELEPORT_EFFECT      = 52096,
        SPELL_THUNDERCLAP          = 33967,
        SPELL_MORTAL_STRIKE        = 32736,
        SPELL_DOOMHOWL             = 84012,
        SPELL_UNHOLY_SMITE         = 84014,
        SPELL_WALDEN_SMITE         = 9734,
        SPELL_WALDEN_HOLYNOVA      = 85965,
        SPELL_GODFREY_FIREBALL     = 79854,
        SPELL_GODFREY_BLASTWAVE    = 79857,
        SPELL_GODFREY_FLAMESTRIKE  = 79856,
        SPELL_ASHBURY_MINDBLAST    = 13860,
        SPELL_ASHBURY_PAIN         = 589
    };

    enum MutantChicken
    {
        SPELL_RIDE_VEHICLE         = 46598,
        SPELL_CHICKEN_EXPLOSION    = 83903,

        POINT_ETTIN                = 1
    };

    // The spawned forest ettins on 751, and quest 27088's kill objective.
    constexpr uint32 NPC_FOREST_ETTIN_751 = SilverpineDC::Creature751(44367);

    constexpr float SCENE_SEARCH_RANGE = 100.0f;
    constexpr float WAIT_FOR_PLAYER_RANGE = 40.0f;

    // Where wondi's facing bunny (75042) stood in the source DB.
    constexpr float TARGET_BUNNY_X = -712.28f;
    constexpr float TARGET_BUNNY_Y = 1548.55f;

    Position const SylvanasStartPos = { -153.324f, 1270.27f, 51.54f, 3.071f };

    // nelt_world.script_waypoint entry 46026; she waits 24 s at point 12 and stops at 25.
    constexpr uint32 SYLVANAS_PATH_SIZE = 25;
    Position const SylvanasPath[SYLVANAS_PATH_SIZE] =
    {
        { -160.69f, 1273.93f, 49.734f }, { -178.64f, 1288.06f, 44.878f }, { -199.82f, 1296.95f, 41.871f },
        { -225.48f, 1297.28f, 42.458f }, { -264.70f, 1299.28f, 42.405f }, { -319.61f, 1304.42f, 38.463f },
        { -343.21f, 1309.30f, 40.400f }, { -375.41f, 1321.29f, 37.144f }, { -405.49f, 1328.54f, 39.780f },
        { -442.08f, 1339.03f, 37.697f }, { -459.05f, 1346.05f, 37.050f }, { -469.31f, 1346.78f, 37.675f },
        { -480.79f, 1351.97f, 36.848f }, { -531.90f, 1375.91f, 32.537f }, { -566.04f, 1386.54f, 30.289f },
        { -586.58f, 1400.16f, 28.660f }, { -605.26f, 1427.50f, 28.435f }, { -628.41f, 1442.02f, 28.698f },
        { -635.95f, 1449.36f, 28.390f }, { -643.51f, 1468.64f, 28.676f }, { -667.99f, 1484.81f, 28.733f },
        { -673.21f, 1508.22f, 29.358f }, { -688.52f, 1534.51f, 27.800f }, { -692.53f, 1546.11f, 27.814f },
        { -698.39f, 1546.56f, 27.950f }
    };

    Position const CrowleySpawnPos       = { -745.57f, 1551.27f, 28.01f, 6.26f };
    Position const BloodfangSpawnPos     = { -745.63f, 1547.79f, 28.01f, 6.25f };
    Position const CrowleyParleyPos      = { -710.67f, 1550.983f, 28.02f };
    Position const BloodfangParleyPos    = { -711.01f, 1547.964f, 28.02f };
    Position const BloodfangExitPos      = { -745.63f, 1547.79f, 28.01f };
    Position const CrowleyExitPos        = { -749.9f, 1549.09f, 28.01f };

    Position const GodfreySpawnPos       = { -702.303f, 1513.114f, 28.755f, 1.66f };
    Position const WaldenSpawnPos        = { -704.783f, 1509.923f, 28.723f, 1.66f };
    Position const AshburySpawnPos       = { -699.660f, 1510.400f, 28.594f, 1.66f };
    Position const GodfreyParleyPos      = { -705.148f, 1535.31f, 28.47f };
    Position const WaldenParleyPos       = { -707.136f, 1531.97f, 28.91f };
    Position const AshburyParleyPos      = { -702.256f, 1533.11f, 28.74f };
    Position const GodfreyAdvancePos     = { -692.46f, 1546.36f, 27.81f };
    Position const WaldenAdvancePos      = { -696.88f, 1542.78f, 27.98f };
    Position const AshburyAdvancePos     = { -694.49f, 1543.94f, 27.89f };

    Position const LornaJumpPos          = { -706.89f, 1536.98f, 28.27f };
    Position const LornaKneelPos         = { -709.36f, 1547.89f, 28.01f };
    Position const LornaExitPos          = { -750.377f, 1544.63f, 28.014f };

    Position const CromushBattlePos      = { -696.53f, 1549.96f, 27.93f };
    Position const DaschlaBattlePos      = { -701.644f, 1542.776f, 28.011f };
    Position const AgathaHoverPos        = { -700.99f, 1547.657f, 33.98f };
    Position const AgathaLandPos         = { -700.99f, 1547.657f, 28.0f };
    Position const ArthuraBattlePos      = { -700.44f, 1553.789f, 27.99f };

    Position const CromushGatherPos      = { -694.82f, 1545.61f, 27.883f };
    Position const AgathaGatherPos       = { -702.771f, 1547.591f, 27.997f };
    Position const ArthuraGatherPos      = { -698.006f, 1541.907f, 28.0202f };
    Position const DaschlaGatherPos      = { -697.085f, 1552.68f, 27.956f };

    struct CompanionInfo
    {
        uint32 Entry;
        float SummonDist;
        float FollowAngle;
    };

    // The four companions that follow the player from the Forsaken High Command. Summon
    // distances follow the radius of the summon spells (85868-85871); follow angles are the
    // source's.
    CompanionInfo const Companions[] =
    {
        { NPC_FINAL_CROMUSH, 2.0f, 0.4f * float(M_PI) },
        { NPC_FINAL_ARTHURA, 4.0f, 0.7f * float(M_PI) },
        { NPC_FINAL_AGATHA,  4.0f, 1.1f * float(M_PI) },
        { NPC_FINAL_DASCHLA, 6.0f, 1.4f * float(M_PI) }
    };

    std::vector<uint32> const SceneEntries =
    {
        NPC_FINAL_SYLVANAS, NPC_FINAL_LORNA, NPC_FINAL_GODFREY, NPC_FINAL_WALDEN, NPC_FINAL_ASHBURY,
        NPC_FINAL_CROMUSH, NPC_FINAL_ARTHURA, NPC_FINAL_DASCHLA, NPC_FINAL_AGATHA, NPC_FINAL_BLOODFANG,
        NPC_FINAL_CROWLEY
    };

    bool IsSceneActorOf(Creature const* creature, ObjectGuid const& playerGuid)
    {
        TempSummon const* summon = creature->ToTempSummon();
        return summon && summon->GetSummonerGUID() == playerGuid;
    }

    // Nearest live actor of THIS player's scene. Every actor is summoned by the player, so the
    // summoner GUID tells two parallel scenes apart.
    Creature* FindSceneActor(WorldObject const* searcher, uint32 entry, ObjectGuid const& playerGuid,
        float range = SCENE_SEARCH_RANGE)
    {
        std::list<Creature*> candidates;
        searcher->GetCreatureListWithEntryInGrid(candidates, entry, range);

        Creature* best = nullptr;
        for (Creature* candidate : candidates)
        {
            if (!candidate->IsAlive() || !IsSceneActorOf(candidate, playerGuid))
                continue;

            if (!best || searcher->GetDistance(candidate) < searcher->GetDistance(best))
                best = candidate;
        }

        return best;
    }

    TempSummon* SummonSceneActor(Player* player, uint32 entry, Position const& pos)
    {
        return player->SummonCreature(entry, pos, TEMPSUMMON_MANUAL_DESPAWN, 0, 0, nullptr, true);
    }

    void FaceTargetBunny(Creature* creature)
    {
        creature->SetFacingTo(creature->GetAngle(TARGET_BUNNY_X, TARGET_BUNNY_Y));
    }

    // ---------------------------------------------------------------------------------------
    // Mutant Bush Chicken (44935, summoned by item 60808's spell 83902) -- quest 27088.
    // Runs to the nearest forest ettin, climbs on and explodes: 83903 damages the ettin, cuts
    // its damage done by 62% and kills the chicken. The ettin then turns on the player.
    // ---------------------------------------------------------------------------------------
    struct npc_mutant_bush_chicken : public ScriptedAI
    {
        npc_mutant_bush_chicken(Creature* creature) : ScriptedAI(creature) { }

        void IsSummonedBy(WorldObject* summoner) override
        {
            if (Player* player = summoner ? summoner->ToPlayer() : nullptr)
                _playerGUID = player->GetGUID();

            me->SetWalk(false);
            me->SetReactState(REACT_PASSIVE);
            // The 4.3.4 template carried IMMUNE_TO_PC | IMMUNE_TO_NPC; ours does not, and an ettin
            // would otherwise swat the chicken on its way in.
            me->SetImmuneToAll(true);

            _events.ScheduleEvent(EVENT_MUTANT_CHICKEN_1, 3s);
        }

        // Arrived where the ettin was: board it if it is still here, otherwise chase it again.
        // The source's "if (point = 1 && ...)" assignment made it re-chase on every arrival too.
        void MovementInform(uint32 type, uint32 point) override
        {
            if (type == POINT_MOTION_TYPE && point == POINT_ETTIN && !_foundEttin)
                _events.ScheduleEvent(EVENT_MUTANT_CHICKEN_1, 0ms);
        }

        void UpdateAI(uint32 diff) override
        {
            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_MUTANT_CHICKEN_1:
                        BoardOrChaseEttin();
                        break;
                    case EVENT_CHICKEN_EXPLODE:
                        Explode();
                        break;
                    default:
                        break;
                }
            }
        }

    private:
        void BoardOrChaseEttin()
        {
            Creature* ettin = _ettinGUID.IsEmpty() ? nullptr : ObjectAccessor::GetCreature(*me, _ettinGUID);
            if (ettin && ettin->IsAlive() && me->IsWithinDist(ettin, 5.0f))
            {
                BoardEttin(ettin);
                return;
            }

            ettin = me->FindNearestCreature(NPC_FOREST_ETTIN_751, 70.0f);
            if (!ettin)
            {
                me->DespawnOrUnsummon();
                return;
            }

            _ettinGUID = ettin->GetGUID();
            me->GetMotionMaster()->MovePoint(POINT_ETTIN, ettin->GetPositionX(), ettin->GetPositionY(),
                ettin->GetPositionZ());
        }

        void BoardEttin(Creature* ettin)
        {
            _foundEttin = true;
            me->GetMotionMaster()->Clear();
            me->CastSpell(ettin, SPELL_RIDE_VEHICLE, true);
            _events.ScheduleEvent(EVENT_CHICKEN_EXPLODE, 3s);
        }

        void Explode()
        {
            me->SetImmuneToAll(false);
            me->CastSpell(me, SPELL_CHICKEN_EXPLOSION, true);

            Creature* ettin = ObjectAccessor::GetCreature(*me, _ettinGUID);
            Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
            if (ettin && ettin->IsAlive() && ettin->IsAIEnabled && player && player->IsAlive()
                && ettin->IsWithinDist(player, 60.0f))
                ettin->AI()->AttackStart(player);
        }

        EventMap _events;
        ObjectGuid _playerGUID;
        ObjectGuid _ettinGUID;
        bool _foundEttin = false;
    };

    // ---------------------------------------------------------------------------------------
    // Lady Sylvanas Windrunner (46026) -- the director of "Cities in Dust".
    // ---------------------------------------------------------------------------------------
    struct npc_sylvanas_cities_in_dust : public ScriptedAI
    {
        npc_sylvanas_cities_in_dust(Creature* creature) : ScriptedAI(creature), _summons(creature) { }

        void IsSummonedBy(WorldObject* summoner) override
        {
            Player* player = summoner ? summoner->ToPlayer() : nullptr;
            if (!player)
                return;

            _playerGUID = player->GetGUID();
            me->SetReactState(REACT_PASSIVE);
            _events.ScheduleEvent(EVENT_SONG_AND_ROOT, 100ms);
            _events.ScheduleEvent(EVENT_FINAL_SCENE_1, 1s);
            _events.ScheduleEvent(EVENT_SCENE_CHECK, 500ms);
        }

        void MovementInform(uint32 type, uint32 point) override
        {
            if (type != POINT_MOTION_TYPE || point == 0 || point > SYLVANAS_PATH_SIZE)
                return;

            _currentWaypoint = point;

            switch (point)
            {
                case 12:
                {
                    Player* player = GetPlayer();
                    Talk(2, player, 1000ms);
                    Talk(3, player, 5500ms);
                    Talk(4, player, 11000ms);
                    Talk(5, player, 19000ms);
                    _events.ScheduleEvent(EVENT_NEXT_WAYPOINT, 24s);
                    break;
                }
                case SYLVANAS_PATH_SIZE:
                    _isClose = false;
                    break;
                default:
                    _events.ScheduleEvent(EVENT_NEXT_WAYPOINT, 0ms);
                    break;
            }
        }

        void SetGUID(ObjectGuid const& guid, int32 id) override
        {
            if (id == DATA_LORNA_GUID)
                _lornaGUID = guid;
        }

        void DoAction(int32 action) override
        {
            switch (action)
            {
                case ACTION_DUMMY_PING: // Lorna is free and kneeling
                    _events.ScheduleEvent(EVENT_FINAL_SCENE_12, 0ms);
                    break;
                case ACTION_DUMMY_PING_3: // the val'kyr have raised her
                    _events.ScheduleEvent(EVENT_FINAL_SCENE_26, 1s);
                    break;
                case ACTION_PING_ACTORS_DESPAWN:
                    EndScene();
                    break;
                default:
                    break;
            }
        }

        void UpdateAI(uint32 diff) override
        {
            if (_playerGUID.IsEmpty())
                return;

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_SCENE_CHECK:
                        if (!CheckScene())
                            return;
                        _events.ScheduleEvent(EVENT_SCENE_CHECK, 500ms);
                        break;
                    case EVENT_SONG_AND_ROOT:
                        DoCastSelf(SPELL_SONG_OF_SYLVANAS, true);
                        DoCastSelf(SPELL_ROOT, true);
                        break;
                    case EVENT_FINAL_SCENE_1:
                        Talk(0, GetPlayer(), 1000ms);
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_2, 3500ms);
                        break;
                    case EVENT_FINAL_SCENE_2:
                        Talk(1, GetPlayer());
                        me->RemoveAurasDueToSpell(SPELL_ROOT);
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_3, 1s);
                        break;
                    case EVENT_FINAL_SCENE_3:
                        me->SetWalk(false);
                        _currentWaypoint = 0;
                        _events.ScheduleEvent(EVENT_NEXT_WAYPOINT, 0ms);
                        break;
                    case EVENT_NEXT_WAYPOINT:
                        MoveToNextWaypoint();
                        break;
                    case EVENT_FINAL_SCENE_4:
                        SceneCrowleyArrives();
                        break;
                    case EVENT_FINAL_SCENE_5:
                        if (Creature* crowley = GetActor(_crowleyGUID))
                        {
                            crowley->AI()->Talk(0);
                            Talk(7, 7000ms);
                            Talk(8, 17000ms);
                            crowley->AI()->Talk(1, 25000ms);
                            Talk(9, 30000ms);
                            crowley->AI()->Talk(2, 40000ms);
                            Talk(10, 46000ms);
                            Talk(11, 50000ms);
                            Talk(12, 57000ms);
                            Talk(13, 64500ms);
                            Talk(14, 71500ms);
                            _events.ScheduleEvent(EVENT_FINAL_SCENE_6, 75500ms);
                        }
                        break;
                    case EVENT_FINAL_SCENE_6:
                        SceneGodfreyArrives();
                        break;
                    case EVENT_FINAL_SCENE_7:
                        if (Creature* godfrey = GetActor(_godfreyGUID))
                        {
                            godfrey->AI()->Talk(0);
                            _events.ScheduleEvent(EVENT_FINAL_SCENE_8, 4s);
                        }
                        break;
                    case EVENT_FINAL_SCENE_8:
                        if (Creature* crowley = GetActor(_crowleyGUID))
                        {
                            crowley->SetFacingTo(6.04f);
                            crowley->AI()->Talk(4, 1500ms);
                            _events.ScheduleEvent(EVENT_FINAL_SCENE_9, 3500ms);
                        }
                        break;
                    case EVENT_FINAL_SCENE_9:
                        if (Creature* crowley = GetActor(_crowleyGUID))
                            if (Creature* bloodfang = GetActor(_bloodfangGUID))
                            {
                                bloodfang->SetFacingToObject(crowley);
                                bloodfang->AI()->Talk(0, 1500ms);
                                Talk(15, 4500ms);
                                _events.ScheduleEvent(EVENT_FINAL_SCENE_10, 7s);
                            }
                        break;
                    case EVENT_FINAL_SCENE_10:
                        if (Creature* godfrey = GetActor(_godfreyGUID))
                        {
                            if (Creature* bloodfang = GetActor(_bloodfangGUID))
                            {
                                bloodfang->SetWalk(false);
                                bloodfang->GetMotionMaster()->MovePoint(2, BloodfangExitPos);
                                bloodfang->DespawnOrUnsummon(3s);
                            }

                            godfrey->AI()->Talk(1);
                            godfrey->AI()->DoAction(ACTION_DUMMY_PING);
                        }
                        break;
                    case EVENT_FINAL_SCENE_12:
                        Talk(16);
                        Talk(17, 5000ms);
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_13, 10s);
                        break;
                    case EVENT_FINAL_SCENE_13:
                        if (Creature* crowley = GetActor(_crowleyGUID))
                        {
                            if (Creature* lorna = GetActor(_lornaGUID))
                                crowley->SetFacingToObject(lorna);
                            crowley->AI()->Talk(5, 1000ms);
                            _events.ScheduleEvent(EVENT_FINAL_SCENE_14, 5s);
                        }
                        break;
                    case EVENT_FINAL_SCENE_14:
                        if (Creature* lorna = GetActor(_lornaGUID))
                        {
                            lorna->SetStandState(UNIT_STAND_STATE_STAND);
                            lorna->GetMotionMaster()->MovePoint(2, LornaExitPos);
                            lorna->DespawnOrUnsummon(4s);
                        }
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_15, 3s);
                        break;
                    case EVENT_FINAL_SCENE_15:
                        if (Creature* crowley = GetActor(_crowleyGUID))
                        {
                            crowley->SetWalk(false);
                            crowley->GetMotionMaster()->MovePoint(2, CrowleyExitPos);
                            crowley->DespawnOrUnsummon(4s);
                        }
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_16, 7s);
                        break;
                    case EVENT_FINAL_SCENE_16:
                        Talk(18);
                        AdvanceEnemy(_waldenGUID, WaldenAdvancePos);
                        AdvanceEnemy(_ashburyGUID, AshburyAdvancePos);
                        AdvanceEnemy(_godfreyGUID, GodfreyAdvancePos);
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_17, 3s);
                        break;
                    case EVENT_FINAL_SCENE_17:
                        if (Creature* godfrey = GetActor(_godfreyGUID))
                        {
                            godfrey->SetSheath(SHEATH_STATE_RANGED);
                            godfrey->HandleEmoteCommand(EMOTE_STATE_READY_RIFLE);
                            _events.ScheduleEvent(EVENT_GODFREY_SHOOT, 1500ms);
                        }
                        break;
                    case EVENT_GODFREY_SHOOT:
                        if (Creature* godfrey = GetActor(_godfreyGUID))
                        {
                            // 74279 is a bare dummy; the source reacted in SpellHit, done inline here.
                            godfrey->CastSpell(me, SPELL_GODFREY_SHOOT, true);
                            ShotByGodfrey(godfrey);
                        }
                        break;
                    case EVENT_FINAL_SCENE_26:
                        me->SetStandState(UNIT_STAND_STATE_STAND);
                        Talk(21, 2500ms);
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_27, 9500ms);
                        break;
                    case EVENT_FINAL_SCENE_27:
                        if (Creature* cromush = FindSceneActor(me, NPC_FINAL_CROMUSH, _playerGUID, 60.0f))
                            me->SetFacingToObject(cromush);
                        Talk(22, 1000ms);
                        Talk(23, 7000ms);
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_28, 12s);
                        break;
                    case EVENT_FINAL_SCENE_28:
                        if (Player* player = GetPlayer())
                            if (player->IsWithinDist(me, 70.0f)
                                && player->GetQuestStatus(QUEST_CITIES_IN_DUST) == QUEST_STATUS_INCOMPLETE)
                                player->KilledMonsterCredit(NPC_CITIES_IN_DUST_CREDIT);
                        EndScene();
                        return;
                    default:
                        break;
                }
            }
        }

    private:
        Player* GetPlayer() const
        {
            return ObjectAccessor::GetPlayer(*me, _playerGUID);
        }

        Creature* GetActor(ObjectGuid const& guid) const
        {
            return guid.IsEmpty() ? nullptr : ObjectAccessor::GetCreature(*me, guid);
        }

        // The source's 500 ms owner check. Returns false once the scene has been torn down.
        bool CheckScene()
        {
            Player* player = GetPlayer();
            if (!player || !player->IsAlive() || player->GetMapId() != me->GetMapId()
                || me->GetZoneId() != SilverpineDC::ZONE_SILVERPINE_751
                || player->GetQuestStatus(QUEST_CITIES_IN_DUST) == QUEST_STATUS_NONE)
            {
                EndScene();
                return false;
            }

            if (!_isClose && player->IsWithinDist(me, 10.0f))
            {
                _isClose = true;
                PingCompanions(ACTION_PING_ACTORS_1);
                _events.ScheduleEvent(EVENT_FINAL_SCENE_4, 3s);
            }

            return true;
        }

        void MoveToNextWaypoint()
        {
            if (_currentWaypoint >= SYLVANAS_PATH_SIZE)
                return;

            // Wait for the player instead of running off without them.
            Player* player = GetPlayer();
            if (!player || !player->IsWithinDist(me, WAIT_FOR_PLAYER_RANGE))
            {
                _events.ScheduleEvent(EVENT_NEXT_WAYPOINT, 1s);
                return;
            }

            uint32 const next = _currentWaypoint + 1;
            Position const& pos = SylvanasPath[next - 1];
            me->GetMotionMaster()->MovePoint(next, pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ());
        }

        void PingCompanions(int32 action)
        {
            for (CompanionInfo const& companion : Companions)
                if (Creature* actor = FindSceneActor(me, companion.Entry, _playerGUID))
                    actor->AI()->DoAction(action);
        }

        Creature* SummonForScene(uint32 entry, Position const& pos)
        {
            Player* player = GetPlayer();
            if (!player)
                return nullptr;

            TempSummon* summon = SummonSceneActor(player, entry, pos);
            if (summon)
                _summons.Summon(summon);
            return summon;
        }

        void SceneCrowleyArrives()
        {
            Talk(6);

            Creature* crowley = SummonForScene(NPC_FINAL_CROWLEY, CrowleySpawnPos);
            Creature* bloodfang = SummonForScene(NPC_FINAL_BLOODFANG, BloodfangSpawnPos);
            if (!crowley || !bloodfang)
                return;

            _crowleyGUID = crowley->GetGUID();
            _bloodfangGUID = bloodfang->GetGUID();
            crowley->SetWalk(true);
            bloodfang->SetWalk(true);
            crowley->GetMotionMaster()->MovePoint(1, CrowleyParleyPos);
            bloodfang->GetMotionMaster()->MovePoint(1, BloodfangParleyPos);
            _events.ScheduleEvent(EVENT_FINAL_SCENE_5, 12s);
        }

        void SceneGodfreyArrives()
        {
            Creature* crowley = GetActor(_crowleyGUID);
            if (!crowley)
                return;

            Creature* godfrey = SummonForScene(NPC_FINAL_GODFREY, GodfreySpawnPos);
            Creature* walden = SummonForScene(NPC_FINAL_WALDEN, WaldenSpawnPos);
            Creature* ashbury = SummonForScene(NPC_FINAL_ASHBURY, AshburySpawnPos);
            if (!godfrey || !walden || !ashbury)
                return;

            _godfreyGUID = godfrey->GetGUID();
            _waldenGUID = walden->GetGUID();
            _ashburyGUID = ashbury->GetGUID();

            for (Creature* enemy : { godfrey, walden, ashbury })
            {
                enemy->AI()->SetGUID(me->GetGUID(), DATA_SYLVANAS_GUID);
                enemy->SetWalk(true);
            }

            // Godfrey brought Lorna along in his IsSummonedBy; she goes when the scene goes.
            if (Creature* lorna = GetActor(godfrey->AI()->GetGUID(DATA_LORNA_GUID)))
                _summons.Summon(lorna);

            godfrey->GetMotionMaster()->MovePoint(1, GodfreyParleyPos);
            walden->GetMotionMaster()->MovePoint(1, WaldenParleyPos);
            ashbury->GetMotionMaster()->MovePoint(1, AshburyParleyPos);

            crowley->SetFacingTo(5.13f);
            crowley->AI()->Talk(3, 1500ms);
            _events.ScheduleEvent(EVENT_FINAL_SCENE_7, 6s);
        }

        void AdvanceEnemy(ObjectGuid const& guid, Position const& pos)
        {
            if (Creature* enemy = GetActor(guid))
            {
                enemy->SetWalk(false);
                enemy->SetFaction(FACTION_MONSTER);
                enemy->GetMotionMaster()->MovePoint(2, pos);
            }
        }

        // The source's SpellHit(SPELL_GODFREY_SHOOT).
        void ShotByGodfrey(Creature* godfrey)
        {
            PingCompanions(ACTION_PING_ACTORS_2);
            me->Dismount();
            Talk(19);
            DoCastSelf(SPELL_PERMANENT_DEATH_ANIM, true);
            godfrey->AI()->DoAction(ACTION_DUMMY_PING_2);
        }

        // The source's SPELL_PING_ACTORS_DESPAWN round plus SummonList::DespawnAll.
        void EndScene()
        {
            _events.Reset();
            PingCompanions(ACTION_PING_ACTORS_DESPAWN);
            _summons.DespawnAll();
            me->DespawnOrUnsummon();
        }

        EventMap _events;
        SummonList _summons;
        ObjectGuid _playerGUID;
        ObjectGuid _crowleyGUID;
        ObjectGuid _bloodfangGUID;
        ObjectGuid _godfreyGUID;
        ObjectGuid _waldenGUID;
        ObjectGuid _ashburyGUID;
        ObjectGuid _lornaGUID;
        uint32 _currentWaypoint = 0;
        bool _isClose = true;
    };

    // ---------------------------------------------------------------------------------------
    // Lord Godfrey (46028), Lord Walden (46029), Baron Ashbury (46030).
    // ---------------------------------------------------------------------------------------
    struct npc_cities_in_dust_enemies : public ScriptedAI
    {
        npc_cities_in_dust_enemies(Creature* creature) : ScriptedAI(creature) { }

        void IsSummonedBy(WorldObject* summoner) override
        {
            Player* player = summoner ? summoner->ToPlayer() : nullptr;
            if (!player)
                return;

            _playerGUID = player->GetGUID();
            me->SetReactState(REACT_PASSIVE);

            if (me->GetEntry() != NPC_FINAL_GODFREY)
                return;

            // Lorna rode vehicle seat 1170 in the source, which this Vehicle.dbc does not have.
            if (TempSummon* lorna = SummonSceneActor(player, NPC_FINAL_LORNA, me->GetPosition()))
            {
                _lornaGUID = lorna->GetGUID();
                lorna->GetMotionMaster()->MoveFollow(me, 1.0f, float(M_PI));
            }
        }

        void SetGUID(ObjectGuid const& guid, int32 id) override
        {
            if (id == DATA_SYLVANAS_GUID)
                _sylvanasGUID = guid;
        }

        ObjectGuid GetGUID(int32 id) const override
        {
            if (id == DATA_LORNA_GUID)
                return _lornaGUID;

            return ObjectGuid::Empty;
        }

        void DamageTaken(Unit* /*attacker*/, uint32& damage, DamageEffectType /*damagetype*/,
            SpellSchoolMask /*damageSchoolMask*/) override
        {
            if (damage >= me->GetHealth())
                damage = 0;

            if (_fightInProgress && me->GetEntry() == NPC_FINAL_GODFREY && me->GetHealthPct() <= 10.0f)
            {
                _fightInProgress = false;
                _events.ScheduleEvent(EVENT_FINAL_LOW_HP, 0ms);
            }
        }

        void MovementInform(uint32 type, uint32 point) override
        {
            if (type == POINT_MOTION_TYPE && point == 2)
                _events.ScheduleEvent(EVENT_FINAL_SCENE_FACING_2, 100ms);
        }

        void JustEngagedWith(Unit* /*who*/) override
        {
            switch (me->GetEntry())
            {
                case NPC_FINAL_GODFREY:
                    _events.ScheduleEvent(EVENT_GODFREY_FIREBALL, 0ms, 2s);
                    _events.ScheduleEvent(EVENT_GODFREY_BLASTWAVE, 4s, 12s);
                    _events.ScheduleEvent(EVENT_GODFREY_FLAMESTRIKE, 8s, 15s);
                    break;
                case NPC_FINAL_WALDEN:
                    _events.ScheduleEvent(EVENT_WALDEN_SMITE, 1s, 3s);
                    _events.ScheduleEvent(EVENT_WALDEN_HOLYNOVA, 4s, 15s);
                    break;
                case NPC_FINAL_ASHBURY:
                    // The source also scheduled EVENT_ASHBURY_PSYCHIC here but never handled it.
                    _events.ScheduleEvent(EVENT_ASHBURY_MINDBLAST, 2s, 6s);
                    _events.ScheduleEvent(EVENT_ASHBURY_PAIN, 1s, 12s);
                    break;
                default:
                    break;
            }
        }

        void DoAction(int32 action) override
        {
            switch (action)
            {
                case ACTION_DUMMY_PING: // "Release her, Godfrey."
                    if (Creature* lorna = GetActor(_lornaGUID))
                    {
                        lorna->GetMotionMaster()->Clear();
                        lorna->GetMotionMaster()->MoveJump(LornaJumpPos, 8.0f, 12.0f);
                        me->RemoveNpcFlag(UNIT_NPC_FLAG_SPELLCLICK);
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_11, 1s);
                    }
                    else
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_12, 2500ms); // no Lorna: hand back anyway
                    break;
                case ACTION_DUMMY_PING_2: // Sylvanas is down
                    _events.ScheduleEvent(EVENT_FINAL_SCENE_18, 6s);
                    break;
                case ACTION_PING_ACTORS_ENEMIES:
                    if (_fightInProgress)
                        me->DespawnOrUnsummon();
                    break;
                default:
                    break;
            }
        }

        void UpdateAI(uint32 diff) override
        {
            DoMeleeAttackIfReady();

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_FINAL_SCENE_11:
                        if (Creature* lorna = GetActor(_lornaGUID))
                        {
                            lorna->SetWalk(false);
                            lorna->GetMotionMaster()->MovePoint(1, LornaKneelPos);
                            _events.ScheduleEvent(EVENT_FINAL_SCENE_12, 1500ms);
                        }
                        break;
                    case EVENT_FINAL_SCENE_12:
                        if (Creature* sylvanas = GetActor(_sylvanasGUID))
                        {
                            sylvanas->AI()->SetGUID(_lornaGUID, DATA_LORNA_GUID);
                            sylvanas->AI()->DoAction(ACTION_DUMMY_PING);
                        }
                        break;
                    case EVENT_FINAL_SCENE_FACING_2:
                        if (Creature* sylvanas = GetActor(_sylvanasGUID))
                        {
                            me->SetFacingToObject(sylvanas);
                            me->HandleEmoteCommand(EMOTE_STATE_READY_UNARMED);
                        }
                        break;
                    case EVENT_FINAL_SCENE_18:
                        Talk(2);
                        Talk(3, 6000ms);
                        Talk(4, 11000ms);
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_19, 11100ms);
                        break;
                    case EVENT_FINAL_SCENE_19:
                        StartBattle();
                        break;
                    case EVENT_GODFREY_FIREBALL:
                        CastOnVictim(SPELL_GODFREY_FIREBALL);
                        _events.ScheduleEvent(EVENT_GODFREY_FIREBALL, 3s, 6s);
                        break;
                    case EVENT_GODFREY_BLASTWAVE:
                        CastOnVictim(SPELL_GODFREY_BLASTWAVE);
                        _events.ScheduleEvent(EVENT_GODFREY_BLASTWAVE, 8s, 15s);
                        break;
                    case EVENT_GODFREY_FLAMESTRIKE:
                        CastOnVictim(SPELL_GODFREY_FLAMESTRIKE);
                        _events.ScheduleEvent(EVENT_GODFREY_FLAMESTRIKE, 12s, 15s);
                        break;
                    case EVENT_WALDEN_SMITE:
                        CastOnVictim(SPELL_WALDEN_SMITE);
                        _events.ScheduleEvent(EVENT_WALDEN_SMITE, 3s, 6s);
                        break;
                    case EVENT_WALDEN_HOLYNOVA:
                        CastOnVictim(SPELL_WALDEN_HOLYNOVA);
                        _events.ScheduleEvent(EVENT_WALDEN_HOLYNOVA, 8s, 12s);
                        break;
                    case EVENT_ASHBURY_MINDBLAST:
                        CastOnVictim(SPELL_ASHBURY_MINDBLAST);
                        _events.ScheduleEvent(EVENT_ASHBURY_MINDBLAST, 3s, 6s);
                        break;
                    case EVENT_ASHBURY_PAIN:
                        CastOnVictim(SPELL_ASHBURY_PAIN);
                        _events.ScheduleEvent(EVENT_ASHBURY_PAIN, 30s, 40s);
                        break;
                    case EVENT_FINAL_LOW_HP:
                        Talk(5);
                        Talk(6, 4000ms);
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_20, 6500ms);
                        break;
                    case EVENT_FINAL_SCENE_20:
                        // The source fell through into EVENT_FINAL_SCENE_21 (no break), so the
                        // companions regroup at once; both halves run here, once.
                        Retreat();
                        RegroupCompanions();
                        return;
                    default:
                        break;
                }
            }
        }

    private:
        Creature* GetActor(ObjectGuid const& guid) const
        {
            return guid.IsEmpty() ? nullptr : ObjectAccessor::GetCreature(*me, guid);
        }

        void CastOnVictim(uint32 spellId)
        {
            if (Unit* victim = me->GetVictim())
                me->CastSpell(victim, spellId);
        }

        static void Engage(Creature* enemy, Creature* companion)
        {
            enemy->SetReactState(REACT_AGGRESSIVE);
            enemy->SetImmuneToAll(false);
            if (!companion)
                return;

            enemy->AI()->AttackStart(companion);
            companion->AI()->AttackStart(enemy);
        }

        // EVENT_FINAL_SCENE_19. The source had each companion cast "Attack Me" (53799) on GODFREY,
        // even inside the Walden and Ashbury blocks; the pairing below is what those blocks
        // were evidently written for: Godfrey/Cromush, Walden/Arthura, Ashbury/Daschla.
        void StartBattle()
        {
            _fightInProgress = true;
            Engage(me, FindSceneActor(me, NPC_FINAL_CROMUSH, _playerGUID, 60.0f));

            if (Creature* walden = FindSceneActor(me, NPC_FINAL_WALDEN, _playerGUID, 60.0f))
            {
                _waldenGUID = walden->GetGUID();
                Engage(walden, FindSceneActor(me, NPC_FINAL_ARTHURA, _playerGUID, 60.0f));
            }

            if (Creature* ashbury = FindSceneActor(me, NPC_FINAL_ASHBURY, _playerGUID, 60.0f))
            {
                _ashburyGUID = ashbury->GetGUID();
                Engage(ashbury, FindSceneActor(me, NPC_FINAL_DASCHLA, _playerGUID, 60.0f));
            }
        }

        // EVENT_FINAL_SCENE_20: "FALL BACK, BROTHERS! TO SHADOWFANG!"
        void Retreat()
        {
            for (ObjectGuid const& guid : { me->GetGUID(), _waldenGUID, _ashburyGUID })
            {
                Creature* enemy = GetActor(guid);
                if (!enemy)
                    continue;

                enemy->CastSpell(enemy, SPELL_TELEPORT_EFFECT, true);
                enemy->CastSpell(enemy, SPELL_SANCTUARY_NO_COMBAT, true);
                enemy->SetImmuneToAll(true);
                enemy->SetReactState(REACT_PASSIVE);
                enemy->CombatStop(true);
                enemy->DespawnOrUnsummon(1500ms);
            }
        }

        // EVENT_FINAL_SCENE_21: the companions break off and gather around Sylvanas.
        void RegroupCompanions()
        {
            struct Regroup
            {
                uint32 Entry;
                Position const* Pos;
            };

            Regroup const regroups[] =
            {
                { NPC_FINAL_CROMUSH, &CromushGatherPos },
                { NPC_FINAL_AGATHA,  &AgathaGatherPos },
                { NPC_FINAL_ARTHURA, &ArthuraGatherPos },
                { NPC_FINAL_DASCHLA, &DaschlaGatherPos }
            };

            for (Regroup const& regroup : regroups)
            {
                Creature* companion = FindSceneActor(me, regroup.Entry, _playerGUID, 60.0f);
                if (!companion)
                    continue;

                // Sanctuary only zeroes threat on creatures here; stop the fight outright so
                // nothing evades the companion back to where it was summoned.
                companion->CombatStop(true);
                companion->SetReactState(REACT_PASSIVE);
                companion->CastSpell(companion, SPELL_SANCTUARY_NO_COMBAT, true);
                companion->SetImmuneToAll(true);
                companion->SetWalk(false);
                companion->GetMotionMaster()->MovePoint(3, *regroup.Pos);
            }
        }

        EventMap _events;
        ObjectGuid _playerGUID;
        ObjectGuid _sylvanasGUID;
        ObjectGuid _lornaGUID;
        ObjectGuid _waldenGUID;
        ObjectGuid _ashburyGUID;
        bool _fightInProgress = false;
    };

    // ---------------------------------------------------------------------------------------
    // The rest of the cast: High Warlord Cromush (46031) and the val'kyr Arthura (46032),
    // Daschla (46033) and Agatha (46034) follow the player; Lorna (46027), Bloodfang (46035)
    // and Crowley (46036) are the other side of the parley.
    // ---------------------------------------------------------------------------------------
    struct npc_cities_in_dust_actors : public ScriptedAI
    {
        npc_cities_in_dust_actors(Creature* creature) : ScriptedAI(creature) { }

        void IsSummonedBy(WorldObject* summoner) override
        {
            Player* player = summoner ? summoner->ToPlayer() : nullptr;
            if (!player)
                return;

            _playerGUID = player->GetGUID();
            me->SetReactState(REACT_PASSIVE);
            me->SetCanFly(false);
            me->SetDisableGravity(false);

            if (GetCompanionInfo())
                _events.ScheduleEvent(EVENT_SCENE_CHECK, 1s);
        }

        void DamageTaken(Unit* /*attacker*/, uint32& damage, DamageEffectType /*damagetype*/,
            SpellSchoolMask /*damageSchoolMask*/) override
        {
            if (damage >= me->GetHealth())
                damage = 0;
        }

        void JustEngagedWith(Unit* /*who*/) override
        {
            if (me->GetEntry() == NPC_FINAL_CROMUSH)
            {
                _events.ScheduleEvent(EVENT_THUNDERCLAP, 4s, 12s);
                _events.ScheduleEvent(EVENT_MORTAL_STRIKE, 2s, 5s);
            }
            else
            {
                _events.ScheduleEvent(EVENT_DOOMHOWL, 2s, 8s);
                _events.ScheduleEvent(EVENT_UNHOLY_SMITE, 1s, 4s);
            }
        }

        void MovementInform(uint32 type, uint32 point) override
        {
            if (type != POINT_MOTION_TYPE)
                return;

            if (me->GetEntry() == NPC_FINAL_LORNA)
            {
                if (point == 1)
                    me->SetStandState(UNIT_STAND_STATE_KNEEL);
                return;
            }

            if (point == 1)
                _events.ScheduleEvent(EVENT_FINAL_SCENE_FACING, 100ms);
            else if (point == 3)
            {
                switch (me->GetEntry())
                {
                    case NPC_FINAL_CROMUSH:
                        _events.CancelEvent(EVENT_THUNDERCLAP);
                        _events.CancelEvent(EVENT_MORTAL_STRIKE);
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_22, 100ms);
                        break;
                    case NPC_FINAL_DASCHLA:
                    case NPC_FINAL_AGATHA:
                    case NPC_FINAL_ARTHURA:
                        _events.ScheduleEvent(EVENT_FINAL_SCENE_23, 100ms);
                        break;
                    default:
                        break;
                }
            }
        }

        void DoAction(int32 action) override
        {
            if (_playerGUID.IsEmpty() || !GetCompanionInfo())
                return;

            switch (action)
            {
                case ACTION_PING_ACTORS_1:
                    TakeBattlePosition();
                    break;
                case ACTION_PING_ACTORS_DESPAWN:
                    me->DespawnOrUnsummon();
                    break;
                case ACTION_PING_ACTORS_2:
                    AvengeSylvanas();
                    break;
                default:
                    break;
            }
        }

        void UpdateAI(uint32 diff) override
        {
            DoMeleeAttackIfReady();

            _events.Update(diff);

            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_SCENE_CHECK:
                        if (!CheckCompanion())
                            return;
                        _events.ScheduleEvent(EVENT_SCENE_CHECK, 1s);
                        break;
                    case EVENT_FINAL_SCENE_FACING:
                        switch (me->GetEntry())
                        {
                            case NPC_FINAL_CROMUSH:
                                FaceTargetBunny(me);
                                me->HandleEmoteCommand(EMOTE_STATE_READY2H);
                                break;
                            case NPC_FINAL_DASCHLA:
                            case NPC_FINAL_ARTHURA:
                                FaceTargetBunny(me);
                                break;
                            default:
                                break;
                        }
                        break;
                    case EVENT_FINAL_SCENE_AGATHA_FACING:
                        FaceTargetBunny(me);
                        break;
                    case EVENT_DOOMHOWL:
                        CastOnVictim(SPELL_DOOMHOWL);
                        _events.ScheduleEvent(EVENT_DOOMHOWL, 12s, 25s);
                        break;
                    case EVENT_UNHOLY_SMITE:
                        CastOnVictim(SPELL_UNHOLY_SMITE);
                        _events.ScheduleEvent(EVENT_UNHOLY_SMITE, 3s, 7s);
                        break;
                    case EVENT_THUNDERCLAP:
                        CastOnVictim(SPELL_THUNDERCLAP);
                        _events.ScheduleEvent(EVENT_THUNDERCLAP, 12s, 25s);
                        break;
                    case EVENT_MORTAL_STRIKE:
                        CastOnVictim(SPELL_MORTAL_STRIKE);
                        _events.ScheduleEvent(EVENT_MORTAL_STRIKE, 5s, 8s);
                        break;
                    case EVENT_FINAL_SCENE_22:
                        if (Creature* sylvanas = FindSceneActor(me, NPC_FINAL_SYLVANAS, _playerGUID, 50.0f))
                        {
                            me->SetFacingToObject(sylvanas);
                            me->SetStandState(UNIT_STAND_STATE_KNEEL);
                            Talk(1, 3000ms);
                            _events.ScheduleEvent(EVENT_FINAL_SCENE_24, 5s);
                        }
                        break;
                    case EVENT_FINAL_SCENE_23:
                        if (Creature* sylvanas = FindSceneActor(me, NPC_FINAL_SYLVANAS, _playerGUID, 50.0f))
                            me->SetFacingToObject(sylvanas);
                        break;
                    case EVENT_FINAL_SCENE_24:
                        ValkyrSacrifice();
                        break;
                    case EVENT_RAISE_FORSAKEN:
                        for (ObjectGuid const& guid : { _agathaGUID, _daschlaGUID, _arthuraGUID })
                            if (Creature* valkyr = GetActor(guid))
                                valkyr->CastSpell(valkyr, SPELL_FINAL_RAISE_FORSAKEN, true);
                        break;
                    case EVENT_FINAL_SCENE_25:
                        SylvanasRises();
                        break;
                    case EVENT_PING_SYLVANAS_3:
                        if (Creature* sylvanas = FindSceneActor(me, NPC_FINAL_SYLVANAS, _playerGUID, 50.0f))
                            sylvanas->AI()->DoAction(ACTION_DUMMY_PING_3);
                        break;
                    default:
                        break;
                }
            }
        }

    private:
        CompanionInfo const* GetCompanionInfo() const
        {
            for (CompanionInfo const& companion : Companions)
                if (companion.Entry == me->GetEntry())
                    return &companion;

            return nullptr;
        }

        Creature* GetActor(ObjectGuid const& guid) const
        {
            return guid.IsEmpty() ? nullptr : ObjectAccessor::GetCreature(*me, guid);
        }

        void CastOnVictim(uint32 spellId)
        {
            if (Unit* victim = me->GetVictim())
                me->CastSpell(victim, spellId);
        }

        // The source's 1 s owner check and follow logic, companions only.
        bool CheckCompanion()
        {
            Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
            if (!player || !player->IsAlive() || player->GetMapId() != me->GetMapId()
                || me->GetZoneId() != SilverpineDC::ZONE_SILVERPINE_751
                || player->GetQuestStatus(QUEST_CITIES_IN_DUST) == QUEST_STATUS_NONE)
            {
                me->DespawnOrUnsummon();
                return false;
            }

            if (_stopFollow)
                return true;

            float const angle = GetCompanionInfo()->FollowAngle;
            if (me->GetReactState() != REACT_PASSIVE && !player->GetVictim() && !player->IsInCombat())
            {
                me->SetReactState(REACT_PASSIVE);
                DoCastSelf(SPELL_SANCTUARY_NO_COMBAT, true);
                me->GetMotionMaster()->MoveFollow(player, 0.9f, angle);
            }

            if (!_isFollowing)
            {
                me->GetMotionMaster()->MoveFollow(player, 0.9f, angle);
                _isFollowing = true;
            }

            return true;
        }

        // ACTION_PING_ACTORS_1: Sylvanas has reached the Battlefront with the player.
        void TakeBattlePosition()
        {
            _stopFollow = true;
            me->GetMotionMaster()->Clear();

            switch (me->GetEntry())
            {
                case NPC_FINAL_CROMUSH:
                    me->GetMotionMaster()->MovePoint(1, CromushBattlePos);
                    break;
                case NPC_FINAL_DASCHLA:
                    me->GetMotionMaster()->MovePoint(1, DaschlaBattlePos);
                    break;
                case NPC_FINAL_AGATHA:
                    me->SetCanFly(true);
                    me->SetDisableGravity(true);
                    me->GetMotionMaster()->MoveJump(AgathaHoverPos, 20.0f, 10.0f);
                    _events.ScheduleEvent(EVENT_FINAL_SCENE_AGATHA_FACING, 2s);
                    break;
                case NPC_FINAL_ARTHURA:
                    me->GetMotionMaster()->MovePoint(1, ArthuraBattlePos);
                    break;
                default:
                    break;
            }
        }

        // ACTION_PING_ACTORS_2: Godfrey has shot Sylvanas.
        void AvengeSylvanas()
        {
            Creature* godfrey = FindSceneActor(me, NPC_FINAL_GODFREY, _playerGUID, 60.0f);
            if (!godfrey)
                return;

            me->SetImmuneToAll(false);
            me->SetReactState(REACT_AGGRESSIVE);
            me->SetFacingToObject(godfrey);

            switch (me->GetEntry())
            {
                case NPC_FINAL_CROMUSH:
                    Talk(0, 2000ms);
                    break;
                case NPC_FINAL_AGATHA:
                    me->SetCanFly(false);
                    me->SetDisableGravity(false);
                    me->GetMotionMaster()->MovePoint(5, AgathaLandPos);
                    break;
                default:
                    break;
            }
        }

        // EVENT_FINAL_SCENE_24 (Cromush): the val'kyr give their lives to raise Sylvanas.
        void ValkyrSacrifice()
        {
            Creature* arthura = FindSceneActor(me, NPC_FINAL_ARTHURA, _playerGUID, 50.0f);
            Creature* agatha = FindSceneActor(me, NPC_FINAL_AGATHA, _playerGUID, 50.0f);
            Creature* daschla = FindSceneActor(me, NPC_FINAL_DASCHLA, _playerGUID, 50.0f);
            if (!arthura || !agatha || !daschla)
                return;

            _agathaGUID = agatha->GetGUID();
            _arthuraGUID = arthura->GetGUID();
            _daschlaGUID = daschla->GetGUID();
            agatha->AI()->Talk(0, 2000ms);
            arthura->AI()->Talk(0, 6000ms);
            daschla->AI()->Talk(0, 10500ms);
            arthura->AI()->Talk(1, 15500ms);
            _events.ScheduleEvent(EVENT_RAISE_FORSAKEN, 19500ms);
            _events.ScheduleEvent(EVENT_FINAL_SCENE_25, 27500ms);
        }

        // EVENT_FINAL_SCENE_25 (Cromush).
        void SylvanasRises()
        {
            Creature* sylvanas = FindSceneActor(me, NPC_FINAL_SYLVANAS, _playerGUID, 50.0f);
            if (!sylvanas)
                return;

            for (ObjectGuid const& guid : { _agathaGUID, _arthuraGUID, _daschlaGUID })
            {
                if (Creature* valkyr = GetActor(guid))
                {
                    valkyr->CastSpell(valkyr, SPELL_PERMANENT_DEATH_ANIM, true);
                    valkyr->DespawnOrUnsummon(12s);
                }
            }

            sylvanas->RemoveAurasDueToSpell(SPELL_PERMANENT_DEATH_ANIM);
            sylvanas->SetStandState(UNIT_STAND_STATE_KNEEL);
            sylvanas->AI()->Talk(20, 3000ms);
            _events.ScheduleEvent(EVENT_PING_SYLVANAS_3, 5s);
        }

        EventMap _events;
        ObjectGuid _playerGUID;
        ObjectGuid _arthuraGUID;
        ObjectGuid _agathaGUID;
        ObjectGuid _daschlaGUID;
        bool _stopFollow = false;
        bool _isFollowing = false;
    };

    // ---------------------------------------------------------------------------------------
    // Quest 27601 accepted -> summon the scene, privately, for this player.
    // ---------------------------------------------------------------------------------------
    class playerscript_silverpine_cities_in_dust : public PlayerScript
    {
    public:
        playerscript_silverpine_cities_in_dust() : PlayerScript("playerscript_silverpine_cities_in_dust",
            { PLAYERHOOK_ON_PLAYER_QUEST_ACCEPT }) { }

        void OnPlayerQuestAccept(Player* player, Quest const* quest) override
        {
            if (!player || !quest || quest->GetQuestId() != QUEST_CITIES_IN_DUST
                || player->GetMapId() != SilverpineDC::MAP_LORDAERON_751)
                return;

            // A scene left over from an abandoned attempt would answer FindSceneActor() for the
            // new one; the actors' own checks only notice the abandon within a second.
            std::list<Creature*> stale;
            player->GetCreatureListWithEntryInGrid(stale, SceneEntries, 250.0f);
            for (Creature* creature : stale)
                if (IsSceneActorOf(creature, player->GetGUID()))
                    creature->DespawnOrUnsummon();

            SummonSceneActor(player, NPC_FINAL_SYLVANAS, SylvanasStartPos);

            for (CompanionInfo const& companion : Companions)
                SummonSceneActor(player, companion.Entry, player->GetNearPosition(companion.SummonDist,
                    companion.FollowAngle));
        }
    };
}

void AddSC_dc_silverpine_cities_in_dust()
{
    RegisterCreatureAI(npc_mutant_bush_chicken);
    RegisterCreatureAI(npc_sylvanas_cities_in_dust);
    RegisterCreatureAI(npc_cities_in_dust_enemies);
    RegisterCreatureAI(npc_cities_in_dust_actors);
    new playerscript_silverpine_cities_in_dust();
}
