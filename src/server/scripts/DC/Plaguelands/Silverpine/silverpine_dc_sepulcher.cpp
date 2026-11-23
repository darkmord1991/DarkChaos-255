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

// Silverpine Forest on map 751: the Sepulcher / Ruins of Gilneas slice of Project Neltharion's
// zone_silverpine_forest.cpp (source lines 1921-2653). Bound by the pending world SQL that ships
// with this file (ScriptNames, the cannon's spellclick, condition and weapon, the camera's text).
//
// The Waters Run Red... (27232)
//   npc_horde_cannon_45263 -> 4145263 (the three spawned cannons). Boarding starts the worgen waves.
//   The cannon's own spell is 84575 (its hit, 84574, is what nelt_world keys on); neither exists on
//   this server (Spell.dbc or spell_dbc), so the action bar uses stock 57385 "Argent Cannon" (the
//   cannon of the WotLK quest 13086, same "kill N attackers from a cannon" design, scripted by
//   spell_q13086_last_line_of_defence). That substitution is data (creature_template_spell).
//   npc_hillsbrad_worgen_45270 -> 45270, the companion AI the cannon drives with SetData(1, n).
//   nelt_world did this in SmartAI (SetData 1,n -> waypoint path 4527000 + n - 1, despawn at
//   point 4); it is C++ here so the paths live next to the summons and need no waypoint ids.
//   The worgen are the PLAIN id: the quest objective is 45270 and no 4145270 template exists.
//   Dropped from that SmartAI: spell hit 84574 -> cast 84563 (both absent) and the phase mask.
//
// What Tomorrow Brings (27401)
//   The source summons Gilneas Camera 01 (45427), a vehicle (1105) the player rides on a flight
//   over the harbour, then teleports the player back with Neltharion's spell 151320. On 751 the
//   camera template, Vehicle 1105, its ride spell 98707 and 151320 do not exist. The scene is
//   kept without a vehicle: the telescope summons the objective's own creature, Gilneas Camera 01
//   (Target) 45430, and the player looks through it with Bind Sight (6277, the spell behind the
//   GM .bindsight command) while it flies the source's two paths. The player never leaves the
//   telescope, so no teleport is needed. As in the source, leaving the view at any point grants
//   the credit. The GO's own spell (84936) is suppressed: it force-casts 84882, which is absent.
//
// Not ported (nothing on 751 to bind them to; see the port report):
//   npc_nowhere_master_forteski, npc_veteran_forsaken_trooper - quest 27195 "Nowhere to Run" and
//   the templates 45228 / 45225 / 45236 / 45237 / 74948 were never imported, nor was the quest's
//   ender, Lady Sylvanas at the Sepulcher (44365).
//   npc_arthura_flight_sepuchler - Arthura 45318 has no template, Vehicle 1100 is not in the
//   server Vehicle.dbc, and its summon (84695) and ride (84691) spells are absent.

#include "CombatAI.h"
#include "CreatureScript.h"
#include "GameObjectAI.h"
#include "GameObjectScript.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellAuraDefines.h"
#include "TemporarySummon.h"
#include "silverpine_dc.h"
#include <unordered_map>

namespace
{
    enum SepulcherEvents
    {
        // Same values as the source's file-wide SilverpineEvents enum.
        EVENT_HORDE_CANNON_1        = 21,
        EVENT_HORDE_CANNON_2        = 22,
        EVENT_HORDE_CANNON_3        = 23,
        EVENT_HORDE_CANNON_4        = 24,
        EVENT_HORDE_CANNON_5        = 25,
        EVENT_HORDE_CANNON_6        = 26,
        EVENT_HORDE_CANNON_7        = 27,
        EVENT_TELESCOPE_EXIT        = 68,
        EVENT_TELESCOPE_START_PATH  = 69
    };

    enum SepulcherData
    {
        QUEST_WATER_RUN_RED             = 27232,
        QUEST_WHAT_TOMORROW_BRINGS      = 27401,

        // Plain ids: neither has a +4,100,000 template, and both quests name the plain id.
        NPC_SUMMONED_HILLSBRAD_WORGEN   = 45270,
        NPC_GILNEAS_CAMERA_TARGET       = 45430,

        SPELL_EJECT_ALL_PASSENGERS      = 50630,
        SPELL_TELESCOPE_BIND_SIGHT      = 6277,

        DATA_WORGEN_PATH                = 1,
        DISPLAY_INVISIBLE_STALKER       = 11686,

        SAY_CAMERA_REINFORCEMENTS       = 0
    };

    constexpr uint32 HILLSBRAD_WORGEN_COUNT = 7;
    constexpr uint32 HILLSBRAD_WORGEN_PATH_SIZE = 4;
    constexpr uint32 HILLSBRAD_WORGEN_DESPAWN_MS = 300000;
    // An idle rider must not keep active worgen streaming: live cap per cannon, and the rider is
    // ejected after this many volleys in a row without a kill (two full cycles).
    constexpr uint32 HILLSBRAD_WORGEN_MAX_LIVE = 21;
    constexpr uint32 HORDE_CANNON_IDLE_VOLLEYS = 14;
    constexpr uint32 TELESCOPE_CAMERA_DESPAWN_MS = 120000;

    Position const HillsbradWorgenSpawns[HILLSBRAD_WORGEN_COUNT] =
    {
        { 805.598f,  704.482f, 54.832f, 0.0f },
        { 788.0078f, 724.038f, 46.58f,  0.0f },
        { 778.0219f, 727.539f, 41.79f,  0.0f },
        { 760.8857f, 724.518f, 39.64f,  0.0f },
        { 692.0272f, 715.251f, 33.90f,  0.0f },
        { 683.4419f, 721.917f, 33.06f,  0.0f },
        { 670.4308f, 715.311f, 33.15f,  0.0f }
    };

    // nelt_world waypoints 4527000-4527006, one path per SetData(1, n) value.
    G3D::Vector3 const HillsbradWorgenPaths[HILLSBRAD_WORGEN_COUNT][HILLSBRAD_WORGEN_PATH_SIZE] =
    {
        {
            { 791.676f, 747.526f, 32.5817f }, { 807.529f, 836.323f, 30.8f },
            { 796.009f, 901.657f, 30.8f },    { 763.756f, 1018.38f, 30.8f }
        },
        {
            { 782.468f, 746.684f, 31.7934f }, { 779.127f, 797.293f, 30.8f },
            { 768.523f, 893.695f, 30.8f },    { 745.992f, 1004.89f, 30.8f }
        },
        {
            { 774.103f, 745.628f, 32.1365f }, { 775.365f, 778.088f, 30.8f },
            { 770.497f, 872.098f, 30.8f },    { 734.508f, 1003.71f, 30.8f }
        },
        {
            { 757.304f, 745.04f, 32.2209f },  { 750.398f, 787.833f, 30.8f },
            { 752.541f, 872.908f, 30.8f },    { 730.496f, 1004.38f, 30.8f }
        },
        {
            { 692.513f, 741.194f, 31.2808f }, { 699.484f, 822.211f, 30.8f },
            { 696.291f, 888.485f, 30.8f },    { 658.954f, 960.844f, 30.8f }
        },
        {
            { 678.7f, 732.47f, 31.6651f },    { 674.29f, 799.686f, 30.8f },
            { 668.353f, 870.24f, 30.8f },     { 648.068f, 955.065f, 30.8f }
        },
        {
            { 670.424f, 729.031f, 31.3264f }, { 655.973f, 835.409f, 30.8f },
            { 660.639f, 919.318f, 30.8f },    { 661.788f, 964.049f, 30.8f }
        }
    };

    Position const TelescopeCameraSpawn = { -1460.48f, 1720.85f, 24.341f, 0.9376f };

    constexpr uint32 CameraTelescopePathSize = 5;
    G3D::Vector3 const CameraTelescopePath[CameraTelescopePathSize] =
    {
        { -1453.45f, 1732.00f, 28.63f },
        { -1369.92f, 1848.82f, 31.91f },
        { -1291.73f, 1942.79f, 29.29f },
        { -1235.85f, 1992.15f, 15.85f },
        { -1148.59f, 2096.81f, 13.10f }
    };

    constexpr uint32 CameraTelescopePathSize2 = 5;
    G3D::Vector3 const CameraTelescopePath2[CameraTelescopePathSize2] =
    {
        { -1235.85f, 1992.15f, 15.85f },
        { -1291.73f, 1942.79f, 29.29f },
        { -1369.92f, 1848.82f, 31.91f },
        { -1453.45f, 1732.00f, 28.63f },
        { -1467.25f, 1712.87f, 29.79f }
    };
}

// Horde Cannon (4145263), quest 27232. Boarding roots the cannon and starts the waves: seven
// worgen every 2-4.5 s for seven volleys, then a 10-15 s pause, until the rider leaves or the
// quest is no longer in progress.
struct npc_horde_cannon_45263 : public VehicleAI
{
    npc_horde_cannon_45263(Creature* creature) : VehicleAI(creature), _summons(me) { }

    void PassengerBoarded(Unit* passenger, int8 /*seatId*/, bool apply) override
    {
        if (!passenger->IsPlayer())
            return;

        if (apply)
        {
            _onUse = true;
            _checkTimer = 1000;
            _volleysWithoutKill = 0;
            _playerGUID = passenger->GetGUID();
            me->SetControlled(true, UNIT_STATE_ROOT);
            _events.ScheduleEvent(EVENT_HORDE_CANNON_1, 3s);
        }
        else
            StopWaves();
    }

    void SummonedCreatureDespawn(Creature* summon) override
    {
        _summons.Despawn(summon);
    }

    void SummonedCreatureDies(Creature* /*summon*/, Unit* /*killer*/) override
    {
        _volleysWithoutKill = 0;
    }

    void UpdateAI(uint32 diff) override
    {
        if (_onUse)
        {
            if (_checkTimer <= diff)
            {
                _checkTimer = 1000;

                if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                {
                    QuestStatus const status = player->GetQuestStatus(QUEST_WATER_RUN_RED);
                    if (status == QUEST_STATUS_NONE || status == QUEST_STATUS_COMPLETE)
                    {
                        me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS, true);
                        StopWaves();
                        return;
                    }
                }
            }
            else
                _checkTimer -= diff;
        }

        _events.Update(diff);

        while (uint32 eventId = _events.ExecuteEvent())
        {
            if (eventId < EVENT_HORDE_CANNON_1 || eventId > EVENT_HORDE_CANNON_7)
                continue;

            if (++_volleysWithoutKill > HORDE_CANNON_IDLE_VOLLEYS)
            {
                me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS, true);
                StopWaves();
                return;
            }

            if (CountLiveWorgen() + HILLSBRAD_WORGEN_COUNT <= HILLSBRAD_WORGEN_MAX_LIVE)
                SummonWorgens();

            if (eventId == EVENT_HORDE_CANNON_7)
                _events.ScheduleEvent(EVENT_HORDE_CANNON_1, 10s, 15s);
            else
                _events.ScheduleEvent(eventId + 1, 2s, 4500ms);
        }
    }

private:
    uint32 CountLiveWorgen() const
    {
        uint32 count = 0;
        for (ObjectGuid const& guid : _summons)
            if (Creature* worgen = ObjectAccessor::GetCreature(*me, guid))
                if (worgen->IsAlive())
                    ++count;

        return count;
    }

    void SummonWorgens()
    {
        for (uint32 i = 0; i < HILLSBRAD_WORGEN_COUNT; ++i)
        {
            Creature* worgen = me->SummonCreature(NPC_SUMMONED_HILLSBRAD_WORGEN, HillsbradWorgenSpawns[i],
                TEMPSUMMON_TIMED_DESPAWN, HILLSBRAD_WORGEN_DESPAWN_MS);
            if (!worgen)
                continue;

            _summons.Summon(worgen);
            worgen->setActive(true);

            if (CreatureAI* ai = worgen->AI())
                ai->SetData(DATA_WORGEN_PATH, i + 1);
        }
    }

    void StopWaves()
    {
        _onUse = false;
        _playerGUID.Clear();
        _summons.DespawnAll();
        _events.Reset();
    }

    bool _onUse = false;
    uint32 _checkTimer = 1000;
    uint32 _volleysWithoutKill = 0;
    ObjectGuid _playerGUID;
    SummonList _summons;
    EventMap _events;
};

// Hillsbrad Worgen (45270), summoned by the cannon. SetData(1, n) walks path n across
// Lordamere Lake and despawns the worgen at its last point.
struct npc_hillsbrad_worgen_45270 : public ScriptedAI
{
    npc_hillsbrad_worgen_45270(Creature* creature) : ScriptedAI(creature) { }

    void SetData(uint32 type, uint32 data) override
    {
        if (type != DATA_WORGEN_PATH || data < 1 || data > HILLSBRAD_WORGEN_COUNT)
            return;

        _onPath = true;
        me->SetWalk(true);
        SilverpineDC::DoMoveSmoothPath(me, HillsbradWorgenPaths[data - 1], HILLSBRAD_WORGEN_PATH_SIZE);
    }

    void MovementInform(uint32 type, uint32 id) override
    {
        if (type != ESCORT_MOTION_TYPE || !_onPath || id != HILLSBRAD_WORGEN_PATH_SIZE - 1)
            return;

        _onPath = false;
        me->DespawnOrUnsummon();
    }

private:
    bool _onPath = false;
};

// 7th Legion Telescope (4805417), quest 27401.
struct go_7th_legion_telescope : public GameObjectAI
{
    go_7th_legion_telescope(GameObject* go) : GameObjectAI(go) { }

    // Always handled, so the template's own spell (84936 -> absent 84882) is never cast.
    bool GossipHello(Player* player, bool reportUse) override
    {
        if (reportUse)
            return true;

        if (player->GetQuestStatus(QUEST_WHAT_TOMORROW_BRINGS) != QUEST_STATUS_INCOMPLETE)
            return true;

        // Already looking through a camera. Bind Sight's aura sits on the camera, not the player,
        // so each player's camera is tracked by GUID.
        auto const itr = _cameras.find(player->GetGUID());
        if (itr != _cameras.end() && ObjectAccessor::GetCreature(*me, itr->second))
            return true;

        std::erase_if(_cameras, [this](auto const& entry)
        {
            return !ObjectAccessor::GetCreature(*me, entry.second);
        });

        if (Creature* camera = player->SummonCreature(NPC_GILNEAS_CAMERA_TARGET, TelescopeCameraSpawn,
            TEMPSUMMON_TIMED_DESPAWN, TELESCOPE_CAMERA_DESPAWN_MS))
        {
            _cameras[player->GetGUID()] = camera->GetGUID();

            // The source's 151235 "Dismount and Cancel Shapeshifts" is a script effect with no script here.
            player->RemoveAurasByType(SPELL_AURA_MOUNTED);
            player->RemoveAurasByType(SPELL_AURA_MOD_SHAPESHIFT);
        }

        return true;
    }

private:
    std::unordered_map<ObjectGuid, ObjectGuid> _cameras; // player -> live camera (45430)
};

// Gilneas Camera 01 (Target) (45430), summoned by the telescope. The summoner looks through it
// (Bind Sight) while it flies out over the harbour and back; ending the view grants the credit.
struct npc_camera_silverpine_telescope : public ScriptedAI
{
    npc_camera_silverpine_telescope(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(WorldObject* summoner) override
    {
        Player* player = summoner ? summoner->ToPlayer() : nullptr;
        if (!player)
            return;

        _playerGUID = player->GetGUID();

        // The template lacks the trigger flag, so it would show a random one of its two models.
        me->SetDisplayId(DISPLAY_INVISIBLE_STALKER);
        me->SetReactState(REACT_PASSIVE);
        me->setActive(true);
        me->SetDisableGravity(true);
        me->SetCanFly(true);

        // Replaces riding the camera vehicle (98707).
        player->CastSpell(me, SPELL_TELESCOPE_BIND_SIGHT, true);
        _events.ScheduleEvent(EVENT_TELESCOPE_START_PATH, 1s);
    }

    void MovementInform(uint32 type, uint32 id) override
    {
        if (type != ESCORT_MOTION_TYPE || !_inProgress)
            return;

        if (!_back && id == CameraTelescopePathSize - 1)
        {
            _back = true;
            me->SetSpeed(MOVE_FLIGHT, 4.0f);
            me->SetSpeed(MOVE_RUN, 4.0f);

            if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                Talk(SAY_CAMERA_REINFORCEMENTS, player);

            _events.ScheduleEvent(EVENT_TELESCOPE_EXIT, 4500ms);
        }
        else if (_back && id == CameraTelescopePathSize2 - 1)
            Finish();
    }

    void UpdateAI(uint32 diff) override
    {
        // The view ended early: the player cancelled the channel, cast something else or logged out.
        if (_inProgress && !me->HasAura(SPELL_TELESCOPE_BIND_SIGHT))
        {
            Finish();
            return;
        }

        _events.Update(diff);

        while (uint32 eventId = _events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_TELESCOPE_START_PATH:
                    // The view did not bind: do not hold the quest hostage to the scene.
                    if (!me->HasAura(SPELL_TELESCOPE_BIND_SIGHT))
                    {
                        Finish();
                        return;
                    }

                    _inProgress = true;
                    // Set only now: the aura is applied on the caster's next update.
                    me->SetImmuneToAll(true);
                    me->SetUnitFlag(UNIT_FLAG_NON_ATTACKABLE);
                    SilverpineDC::DoMoveSmoothPath(me, CameraTelescopePath, CameraTelescopePathSize);
                    break;
                case EVENT_TELESCOPE_EXIT:
                    SilverpineDC::DoMoveSmoothPath(me, CameraTelescopePath2, CameraTelescopePathSize2);
                    break;
                default:
                    break;
            }
        }
    }

private:
    void Finish()
    {
        if (_finished)
            return;

        _finished = true;
        _inProgress = false;
        _events.Reset();

        // Removing the aura from the camera clears the viewpoint and ends the caster's channel.
        me->RemoveAurasDueToSpell(SPELL_TELESCOPE_BIND_SIGHT);

        if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
            player->KilledMonsterCredit(NPC_GILNEAS_CAMERA_TARGET);

        me->DespawnOrUnsummon(1s);
    }

    ObjectGuid _playerGUID;
    EventMap _events;
    bool _inProgress = false;
    bool _back = false;
    bool _finished = false;
};

void AddSC_dc_silverpine_sepulcher()
{
    RegisterCreatureAI(npc_horde_cannon_45263);
    RegisterCreatureAI(npc_hillsbrad_worgen_45270);
    RegisterGameObjectAI(go_7th_legion_telescope);
    RegisterCreatureAI(npc_camera_silverpine_telescope);
}
