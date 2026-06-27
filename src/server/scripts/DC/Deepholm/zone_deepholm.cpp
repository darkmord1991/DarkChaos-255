/*
 * This file is part of the AzerothCore Project. See AUTHORS file for
 * Copyright information.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Deepholm (map 646) zone scripts -- downported from TrinityCore's
 * Maelstrom/zone_deepholm.cpp and adapted to the AzerothCore 3.3.5a API.
 *
 * Contents:
 *   npc_deepholm_xariona                       - the Twilight world boss
 *   npc_deepholm_twilight_fissure              - boss-summoned Void Blast trap
 *   npc_deepholm_wyvern                        - intro flight vehicle to the Temple
 *   spell_deepholm_twilight_buffet_targeting   - Twilight Buffet single-target filter
 *
 * Spell/vehicle dependency note: several referenced spells are Cata-era ids
 * absent from 3.3.5 Spell.dbc (93544-93556 Xariona kit, 84364/84093/96123 intro
 * flight, 87239 zero-power). The AI logic is faithful and fails safe -- those
 * casts no-op until the spells are authored via the CSV-DBC pipeline. The intro
 * wyvern further needs Vehicle.dbc + waypoint paths; the feasibility report
 * recommends a portal-GO + SmartAI teleport for entry instead.
 */

#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellScript.h"
#include "MotionMaster.h"
#include "PassiveAI.h"
#include "Vehicle.h"

namespace Deepholm
{
enum VehicleSeatIds
{
    SEAT_1 = 0,
    SEAT_2 = 1
};

enum Xariona
{
    // Events
    EVENT_FURY_OF_THE_TWILIGHT_FLIGHT = 1,
    EVENT_TWILIGHT_BREATH,
    EVENT_TWILIGHT_BUFFET,
    EVENT_UNLEASHED_MAGIC,
    EVENT_TWILIGHT_FISSURE,
    EVENT_TWILIGHT_ZONE,

    // Spells
    SPELL_ZERO_POWER                        = 87239,
    SPELL_ROGUE_CLASS_CRIT_DODGE_DEBUFF     = 73059,
    SPELL_FURY_OF_THE_TWILIGHT_FLIGHT       = 93554,
    SPELL_TWILIGHT_BREATH                   = 93544,
    SPELL_TWILIGHT_BUFFET_TARGETING         = 95385,
    SPELL_UNLEASHED_MAGIC                   = 93556,
    SPELL_TWILIGHT_FISSURE                  = 93546,
    SPELL_VOID_BLAST                        = 93545,
    SPELL_TWILIGHT_ZONE                     = 93553,

    // Creatures
    NPC_TWILIGHT_FISSURE                    = 50431,

    // Fissure event
    EVENT_FISSURE_VOID_BLAST                = 1
};

struct npc_deepholm_xariona : public ScriptedAI
{
    npc_deepholm_xariona(Creature* creature) : ScriptedAI(creature), _summons(me), _furyCount(0)
    {
        me->setPowerType(POWER_ENERGY);
        me->SetMaxPower(POWER_ENERGY, 100);
    }

    void Reset() override
    {
        _events.Reset();
        _summons.DespawnAll();
        _furyCount = 0;
        // This fork's CreatureAI has no JustAppeared() hook; Reset() runs at
        // spawn (and on evade) -- re-applying these self-auras is harmless.
        DoCastSelf(SPELL_ZERO_POWER, true);
        DoCastSelf(SPELL_ROGUE_CLASS_CRIT_DODGE_DEBUFF, true);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        me->SetHomePosition(me->GetPosition());
        _events.ScheduleEvent(EVENT_FURY_OF_THE_TWILIGHT_FLIGHT, 1s);
        _events.ScheduleEvent(EVENT_TWILIGHT_BREATH, 14s);
        _events.ScheduleEvent(EVENT_TWILIGHT_BUFFET, 13s);
        _events.ScheduleEvent(EVENT_TWILIGHT_FISSURE, 29s);
        _events.ScheduleEvent(EVENT_TWILIGHT_ZONE, 31s);
    }

    void JustSummoned(Creature* summon) override
    {
        _summons.Summon(summon);
    }

    void SummonedCreatureDespawn(Creature* summon) override
    {
        _summons.Despawn(summon);
    }

    void JustDied(Unit* /*killer*/) override
    {
        _summons.DespawnAll();
    }

    void EnterEvadeMode(EvadeReason /*why*/) override
    {
        _summons.DespawnAll();
        me->DespawnOrUnsummon(0s, 30s);
    }

    void UpdateAI(uint32 diff) override
    {
        if (!UpdateVictim())
            return;

        _events.Update(diff);

        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        while (uint32 eventId = _events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_FURY_OF_THE_TWILIGHT_FLIGHT:
                    DoCastSelf(SPELL_FURY_OF_THE_TWILIGHT_FLIGHT);
                    if (++_furyCount < 2)
                        _events.Repeat(30s + 500ms);
                    else
                        _events.ScheduleEvent(EVENT_UNLEASHED_MAGIC, 32s);
                    break;
                case EVENT_TWILIGHT_BREATH:
                    DoCastVictim(SPELL_TWILIGHT_BREATH);
                    _events.Repeat(18s, 20s);
                    break;
                case EVENT_TWILIGHT_BUFFET:
                    // Twilight Buffet hits a single random non-tank target.
                    me->CastCustomSpell(SPELL_TWILIGHT_BUFFET_TARGETING, SPELLVALUE_MAX_TARGETS, 1, me, false);
                    _events.Repeat(23s, 25s);
                    break;
                case EVENT_UNLEASHED_MAGIC:
                    DoCastAOE(SPELL_UNLEASHED_MAGIC);
                    _furyCount = 0;
                    _events.DelayEvents(5s);
                    _events.ScheduleEvent(EVENT_FURY_OF_THE_TWILIGHT_FLIGHT, 1ms);
                    break;
                case EVENT_TWILIGHT_FISSURE:
                    if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 45.0f, true))
                        DoCast(target, SPELL_TWILIGHT_FISSURE);
                    _events.Repeat(29s);
                    break;
                case EVENT_TWILIGHT_ZONE:
                    if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 55.0f, true))
                        DoCast(target, SPELL_TWILIGHT_ZONE);
                    _events.Repeat(31s);
                    break;
                default:
                    break;
            }

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;
        }

        DoMeleeAttackIfReady();
    }

private:
    EventMap _events;
    SummonList _summons;
    uint8 _furyCount;
};

// Replaces TrinityCore's inline summon->m_Events lambda: the fissure casts Void
// Blast 4s after appearing (tooltip says 5s, sniffs say 4s), then despawns.
struct npc_deepholm_twilight_fissure : public ScriptedAI
{
    npc_deepholm_twilight_fissure(Creature* creature) : ScriptedAI(creature)
    {
        me->SetReactState(REACT_PASSIVE);
    }

    void Reset() override
    {
        _events.Reset();
        _events.ScheduleEvent(EVENT_FISSURE_VOID_BLAST, 4s);
    }

    void UpdateAI(uint32 diff) override
    {
        _events.Update(diff);

        if (_events.ExecuteEvent() == EVENT_FISSURE_VOID_BLAST)
        {
            DoCastSelf(SPELL_VOID_BLAST, true);
            me->DespawnOrUnsummon(4s);
        }
    }

private:
    EventMap _events;
};

enum DeepholmTheRealmOfEarth
{
    // Spells
    SPELL_CAMERA_1                      = 84364,
    SPELL_FORCECAST_AGGRA_PING          = 96123,
    SPELL_FORCECAST_TELEPORT            = 84093,
    SPELL_EJECT_PASSENGER_2             = 62539,

    // Events
    EVENT_PING_AGGRA                    = 1,
    EVENT_APPROACH_MAELSTROM,

    // Move Points
    POINT_ID_INTRO_FLIGHT               = 0,
    POINT_ID_LEAVE_PLAYER,

    // Creature
    NPC_WYVERN_TEMPLE_OF_EARTH          = 45024
};

struct npc_deepholm_wyvern : public NullCreatureAI
{
    npc_deepholm_wyvern(Creature* creature) : NullCreatureAI(creature) { }

    void PassengerBoarded(Unit* passenger, int8 seatId, bool apply) override
    {
        if (!passenger || !passenger->IsPlayer())
            return;

        if (apply && seatId == SEAT_2)
        {
            if (me->GetEntry() != NPC_WYVERN_TEMPLE_OF_EARTH)
                DoCastSelf(SPELL_CAMERA_1);
            else
                me->GetMotionMaster()->MovePath(me->GetEntry() * 100, FORCED_MOVEMENT_NONE, PathSource::WAYPOINT_MGR);

            _events.ScheduleEvent(EVENT_PING_AGGRA, 400ms);
        }
    }

    void MovementInform(uint32 motionType, uint32 pointId) override
    {
        if (motionType != WAYPOINT_MOTION_TYPE)
            return;

        switch (pointId)
        {
            case POINT_ID_INTRO_FLIGHT:
                if (me->GetEntry() != NPC_WYVERN_TEMPLE_OF_EARTH)
                    DoCastSelf(SPELL_FORCECAST_TELEPORT);
                else
                    DoCastSelf(SPELL_EJECT_PASSENGER_2);
                break;
            case POINT_ID_LEAVE_PLAYER:
                me->DespawnOrUnsummon(3s);
                break;
            default:
                break;
        }
    }

    void UpdateAI(uint32 diff) override
    {
        _events.Update(diff);

        while (uint32 eventId = _events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_PING_AGGRA:
                    if (Vehicle const* vehicle = me->GetVehicleKit())
                        if (Unit* aggra = vehicle->GetPassenger(SEAT_1))
                            DoCast(aggra, SPELL_FORCECAST_AGGRA_PING);

                    if (me->GetEntry() != NPC_WYVERN_TEMPLE_OF_EARTH)
                        _events.ScheduleEvent(EVENT_APPROACH_MAELSTROM, 800ms);
                    break;
                case EVENT_APPROACH_MAELSTROM:
                    me->GetMotionMaster()->MovePath(me->GetEntry() * 100, FORCED_MOVEMENT_NONE, PathSource::WAYPOINT_MGR);
                    break;
                default:
                    break;
            }
        }
    }

private:
    EventMap _events;
};

// 95385 - Twilight Buffet Targeting
class spell_deepholm_twilight_buffet_targeting : public SpellScript
{
    PrepareSpellScript(spell_deepholm_twilight_buffet_targeting);

    void FilterTargets(std::list<WorldObject*>& targets)
    {
        if (targets.empty())
            return;

        // Xariona never hits her current victim with Twilight Buffet.
        Unit const* victim = GetCaster() ? GetCaster()->GetVictim() : nullptr;
        targets.remove_if([victim](WorldObject* target) { return target == victim; });
    }

    void HandleDummyEffect(SpellEffIndex /*effIndex*/)
    {
        if (Unit* caster = GetCaster())
            caster->CastSpell(GetHitUnit(), uint32(GetEffectValue()), true);
    }

    void Register() override
    {
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(spell_deepholm_twilight_buffet_targeting::FilterTargets, EFFECT_0, TARGET_UNIT_SRC_AREA_ENTRY);
        OnEffectHitTarget += SpellEffectFn(spell_deepholm_twilight_buffet_targeting::HandleDummyEffect, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};
}

void AddSC_deepholm()
{
    using namespace Deepholm;
    RegisterCreatureAI(npc_deepholm_xariona);
    RegisterCreatureAI(npc_deepholm_twilight_fissure);
    RegisterCreatureAI(npc_deepholm_wyvern);
    RegisterSpellScript(spell_deepholm_twilight_buffet_targeting);
}
