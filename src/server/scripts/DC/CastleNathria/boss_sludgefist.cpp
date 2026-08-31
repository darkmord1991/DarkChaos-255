/*
 * Copyright (C) 2021 ShadowCore
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// DarkChaos downport of Sludgefist, eighth boss of Castle Nathria (Shadowlands raid, map 2296).
// Ported from ShadowCore (TrinityCore 9.x) to AzerothCore 3.3.5a idioms -- see
// DC/BlackwingDescent/PORT_NOTES.md for the API divergence log this port follows.
//
// 3.3.5 substitutions:
// - Hateful Gaze / Headless Charge: the source attached a moving AreaTrigger (339068) to the boss
//   and resolved collisions from at_headless_charge (its "pillar hit" was a 5-players-clumped test;
//   the wall branch was unreachable). Re-expressed geometrically: the charge is a MoveCharge to the
//   marked tank, players crossed en route are hit by a 200ms proximity tick, and the impact point is
//   resolved against the four statically spawned Pillar Stalkers (170083, 07_creature_spawns.sql) --
//   pillar in reach = Destructive Impact + pillar destroyed, otherwise wall = Collapsing Foundation.
//   Either way the boss is stunned for 12s (retail collision stun the source AT logic never applied).
// - The destructible-pillar visual is not wired: despawning the Pillar Stalker marks the pillar as
//   spent for this attempt (respawns for the next pull). TODO(port): destructible GO state visual.
// - at_stonequake (long-lived ground pools with enter/exit aura handling) cannot be represented:
//   the *_CREATE_AT casts are kept as static ground casts; author their spell_dbc downports as
//   persistent-area-aura (DynObj) effects triggering SPELL_STONEQUAKE_AT_DAMAGE.
// - Mythic Seismic Shift runs on 3.3.5 heroic (nearest difficulty), as in the Council port.
// - AURA_OVERRIDE_POWER_COLOR_RAGE (energy bar recolored to red) has no 3.3.5 counterpart.

#include "InstanceScript.h"
#include "Map.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellInfo.h"
#include "castle_nathria.h"

namespace CastleNathria::Sludgefist
{
enum Spells
{
    SPELL_GIANT_FISTS_DUMMY             = 335297,
    SPELL_GIANT_FISTS_DAMAGE            = 335298,
    SPELL_HATEFUL_GAZE_MARK             = 331209,
    SPELL_HEADLESS_CHARGE_MAIN          = 339067,
    SPELL_HEADLESS_CHARGE_APPLY_AT      = 339068,   // AreaTrigger creator, unused -- see charge tick
    SPELL_HEADLESS_CHARGE_CREATE_AT     = 339069,   // AreaTrigger creator, unused on 3.3.5
    SPELL_DESTRUCTIVE_IMPACT            = 332969,
    SPELL_CRUMBLING_FOUNDATION_PERIODIC = 332443,
    SPELL_CRUMBLING_FOUNDATION_DAMAGE   = 332444,   // unused, triggered by the periodic
    SPELL_COLLAPSING_FOUNDATION         = 332197,
    SPELL_DESTRUCTIVE_STOMP             = 332318,
    SPELL_FALLING_RUMBLE_MISSILE        = 332552,
    SPELL_STONEQUAKE_AT_DAMAGE          = 335361,   // was at_stonequake
    SPELL_STONEQUAKE_CREATE_AT_ONE      = 335371,   // AreaTrigger creator (author as persistent-area-aura)
    SPELL_STONEQUAKE_CREATE_AT_TWO      = 348698,   // AreaTrigger creator (author as persistent-area-aura)
    SPELL_COLOSSAL_ROAR_CAST            = 332687,
    SPELL_COLOSSAL_ROAR_DAMAGE          = 332698,
    SPELL_GRUESOME_RAGE                 = 341250,

    // Mythic (runs on 3.3.5 heroic)
    SPELL_SEISMIC_SHIFT_TRIGGER         = 340803,
    SPELL_SEISMIC_SHIFT_DAMAGE          = 341087,
    SPELL_SEISMIC_SHIFT_TARGET_DEBUFF   = 340817
};

enum Events
{
    EVENT_ENERGY_GAIN = 1,
    EVENT_COLOSSAL_ROAR_CAST = 2,  // was raw SPELL_COLOSSAL_ROAR_CAST
    EVENT_GIANT_FISTS_DAMAGE = 3,  // was raw SPELL_GIANT_FISTS_DAMAGE
    EVENT_FALLING_RUMBLE_MISSILE = 4,  // was raw SPELL_FALLING_RUMBLE_MISSILE
    EVENT_DESTRUCTIVE_STOMP = 5,  // was raw SPELL_DESTRUCTIVE_STOMP
    EVENT_SEISMIC_SHIFT_TRIGGER = 6  // was raw SPELL_SEISMIC_SHIFT_TRIGGER
};

enum Texts
{
    // creature_text GroupIDs for entry 164407 (Custom/.../worlddb/CastleNathria/09_creature_text.sql).
    // The source AI had no Talk() calls; these hook the DB lines to their abilities.
    SAY_AGGRO                       = 0,    // "Gonna flatten your bones!"
    SAY_SLAY                        = 1,    // "You flat now!"
    SAY_ANNOUNCE_DESTRUCTIVE_STOMP  = 2,    // raid announce (type 16)
    SAY_HATEFUL_GAZE                = 3,    // "Stand still."
    SAY_CHARGE                      = 5,    // "Squish you!"
    SAY_DESTRUCTIVE_STOMP           = 6,    // "Skull stomping time!"
    SAY_PILLAR_HIT                  = 8,    // "Ouchie!"
    SAY_WALL_HIT                    = 12,   // "No fair."
    SAY_DEATH                       = 13
    // GroupIDs 4, 7, 9, 10 and 11 are generic yells left unbound for a later flavor pass.
};

enum SludgefistMisc
{
    // Chain pillar stalker (statically spawned x4 in 07_creature_spawns.sql); not part of the
    // shared header's shadowcore-verbatim entry list, so declared locally.
    NPC_PILLAR_STALKER  = 170083,

    TASK_GROUP_CHARGE   = 1
};

// 164407 - Sludgefist
struct boss_sludgefist : public BossAI
{
    boss_sludgefist(Creature* creature) : BossAI(creature, DATA_SLUDGEFIST), _hp30(false), _charging(false) { }

    void Reset() override
    {
        _Reset();
        scheduler.CancelAll();
        _hp30 = false;
        _charging = false;
        _chargeHitGuids.clear();
        me->SetControlled(false, UNIT_STATE_STUNNED);
        me->setPowerType(POWER_ENERGY);
        me->SetMaxPower(POWER_ENERGY, 100);
        me->SetPower(POWER_ENERGY, 0);
        me->SetRegeneratingPower(false);
        me->SetReactState(REACT_DEFENSIVE);
        // TODO(port): source applied AURA_OVERRIDE_POWER_COLOR_RAGE here (recolors the energy bar);
        // no power-color override system on 3.3.5.
        DoCastSelf(SPELL_GIANT_FISTS_DUMMY, true);
        if (instance->GetBossState(DATA_COUNCIL_OF_BLOOD) != DONE)
            me->SetUnitFlag(UNIT_FLAG_NON_ATTACKABLE);
        else
            me->RemoveUnitFlag(UNIT_FLAG_NON_ATTACKABLE);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        _JustEngagedWith();
        Talk(SAY_AGGRO);
        events.ScheduleEvent(EVENT_ENERGY_GAIN, 1s);
        events.ScheduleEvent(EVENT_COLOSSAL_ROAR_CAST, 1s);
        events.ScheduleEvent(EVENT_GIANT_FISTS_DAMAGE, 2s);
        events.ScheduleEvent(EVENT_FALLING_RUMBLE_MISSILE, 12s);
        events.ScheduleEvent(EVENT_DESTRUCTIVE_STOMP, 17s);
        if (IsHeroic()) // TODO(port): Mythic-only on retail; 3.3.5 heroic is the nearest difficulty
            events.ScheduleEvent(EVENT_SEISMIC_SHIFT_TRIGGER, 16s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        // Energy poll runs on every event pop; EVENT_ENERGY_GAIN ticks each second, so this is
        // effectively a once-per-second check, as in the source.
        if (me->GetPower(POWER_ENERGY) == 100)
        {
            me->SetPower(POWER_ENERGY, 0);
            if (Unit* target = SelectTarget(SelectTargetMethod::MaxThreat, 0, 100.0f, true))
            {
                Talk(SAY_HATEFUL_GAZE);
                me->AddAura(SPELL_HATEFUL_GAZE_MARK, target);
                ObjectGuid targetGuid = target->GetGUID();
                scheduler.Schedule(6100ms, [this, targetGuid](TaskContext /*context*/)
                {
                    Unit* target = ObjectAccessor::GetUnit(*me, targetGuid);
                    if (!target)
                        return;

                    Talk(SAY_CHARGE);
                    StartHeadlessCharge(target);
                });
            }
        }

        switch (eventId)
        {
            case EVENT_ENERGY_GAIN:
                me->ModifyPower(POWER_ENERGY, 2);
                events.Repeat(1s);
                break;
            case EVENT_GIANT_FISTS_DAMAGE:
                if (Unit* target = SelectTarget(SelectTargetMethod::MinDistance, 0, 10.0f, true))
                {
                    me->CastSpell(target, SPELL_GIANT_FISTS_DAMAGE, TRIGGERED_FULL_MASK);
                    // Source: the blow lands twice when no other player shares it within 10 yards.
                    if (!HasOtherPlayerNear(target, 10.0f))
                        me->CastSpell(target, SPELL_GIANT_FISTS_DAMAGE, TRIGGERED_FULL_MASK);
                }
                events.Repeat(2s);
                break;
            case EVENT_DESTRUCTIVE_STOMP:
                Talk(SAY_ANNOUNCE_DESTRUCTIVE_STOMP);
                Talk(SAY_DESTRUCTIVE_STOMP);
                DoCastAOE(SPELL_DESTRUCTIVE_STOMP);
                events.Repeat(20s, 25s);
                break;
            case EVENT_FALLING_RUMBLE_MISSILE:
            {
                UnitList targetList;
                SelectTargetList(targetList, 5, SelectTargetMethod::Random, 0, 100.0f, true);
                for (Unit* target : targetList)
                {
                    me->CastSpell(target, SPELL_FALLING_RUMBLE_MISSILE, TRIGGERED_FULL_MASK);
                    // TODO(port): at_stonequake gave these pools enter/exit aura handling; static
                    // ground casts only until the spell_dbc downports exist (persistent-area-aura).
                    me->CastSpell(target, SPELL_STONEQUAKE_CREATE_AT_ONE, TRIGGERED_FULL_MASK);
                    me->CastSpell(target, SPELL_STONEQUAKE_CREATE_AT_TWO, TRIGGERED_FULL_MASK);
                }
                events.Repeat(15s, 18s);
                break;
            }
            case EVENT_COLOSSAL_ROAR_CAST:
                DoCastAOE(SPELL_COLOSSAL_ROAR_CAST);
                // TODO(port): source fired the damage from an OnSpellFinished hook; the 3.3.5
                // CreatureAI has no such hook, so the impact is scheduled off the cast start.
                scheduler.Schedule(3s, [this](TaskContext /*context*/)
                {
                    DoCastAOE(SPELL_COLOSSAL_ROAR_DAMAGE, true);
                });
                events.Repeat(30s);
                break;
            case EVENT_SEISMIC_SHIFT_TRIGGER:
                DoCastSelf(SPELL_SEISMIC_SHIFT_TRIGGER, true);
                // TODO(port): OnSpellFinished substitute -- the trigger cast is instant, apply now.
                ForEachPlayerInRoom([this](Player* player)
                {
                    me->AddAura(SPELL_SEISMIC_SHIFT_TARGET_DEBUFF, player);
                    ObjectGuid playerGuid = player->GetGUID();
                    scheduler.Schedule(4100ms, [this, playerGuid](TaskContext /*context*/)
                    {
                        if (Unit* target = ObjectAccessor::GetUnit(*me, playerGuid))
                            me->CastSpell(target, SPELL_SEISMIC_SHIFT_DAMAGE, TRIGGERED_FULL_MASK);
                    });
                });
                events.Repeat(28s);
                break;
            default:
                break;
        }
    }

    // Headless Charge: MoveCharge at the marked tank; a proximity tick substitutes the moving
    // AreaTrigger (339068) that hit players crossed en route.
    void StartHeadlessCharge(Unit* target)
    {
        _charging = true;
        _chargeHitGuids.clear();
        scheduler.Schedule(200ms, TASK_GROUP_CHARGE, [this](TaskContext context)
        {
            if (!_charging)
                return;

            ForEachPlayerInRoom([this](Player* player)
            {
                if (!me->IsWithinDistInMap(player, 8.0f) || _chargeHitGuids.count(player->GetGUID()))
                    return;

                _chargeHitGuids.insert(player->GetGUID());
                me->CastSpell(player, SPELL_HEADLESS_CHARGE_MAIN, TRIGGERED_FULL_MASK);
            });
            context.Repeat(200ms);
        });
        me->GetMotionMaster()->MoveCharge(target->GetPositionX(), target->GetPositionY(),
            target->GetPositionZ(), 20.0f, EVENT_CHARGE, nullptr, true);
    }

    void MovementInform(uint32 type, uint32 id) override
    {
        if (type != POINT_MOTION_TYPE || id != EVENT_CHARGE || !_charging)
            return;

        _charging = false;
        scheduler.CancelGroup(TASK_GROUP_CHARGE);

        // Collision resolution against the statically spawned Pillar Stalkers (source resolved this
        // from at_headless_charge; its wall branch was unreachable -- reauthored geometrically).
        if (Creature* pillar = me->FindNearestCreature(NPC_PILLAR_STALKER, 12.0f, true))
        {
            Talk(SAY_PILLAR_HIT);
            DoCastSelf(SPELL_DESTRUCTIVE_IMPACT, true);
            // TODO(port): destructible-pillar GO visual not wired; the despawned stalker marks the
            // pillar as spent for this attempt (respawns for the next pull).
            pillar->DespawnOrUnsummon(0ms, 30s);
            // Source ACTION_PILLAR_HIT: Crumbling Foundation on the raid.
            ForEachPlayerInRoom([this](Player* player)
            {
                me->AddAura(SPELL_CRUMBLING_FOUNDATION_PERIODIC, player);
            });
        }
        else
        {
            // Source ACTION_WALL_HIT: Collapsing Foundation raid damage.
            Talk(SAY_WALL_HIT);
            DoCastAOE(SPELL_COLLAPSING_FOUNDATION, true);
        }

        // Retail collision stun: 12s regardless of what was hit.
        me->SetControlled(true, UNIT_STATE_STUNNED);
        events.DelayEvents(12s);
        scheduler.Schedule(12s, [this](TaskContext /*context*/)
        {
            me->SetControlled(false, UNIT_STATE_STUNNED);
        });
    }

    void DamageTaken(Unit* /*attacker*/, uint32& /*damage*/, DamageEffectType /*damagetype*/, SpellSchoolMask /*damageSchoolMask*/) override
    {
        if (me->HealthBelowPct(30) && !_hp30)
        {
            _hp30 = true;
            DoCastSelf(SPELL_GRUESOME_RAGE, true);
        }
    }

    void KilledUnit(Unit* victim) override
    {
        if (victim->IsPlayer())
            Talk(SAY_SLAY);
    }

    void JustDied(Unit* /*killer*/) override
    {
        Talk(SAY_DEATH);
        scheduler.CancelAll();
        me->RemoveAllDynObjects();
        _JustDied();
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        scheduler.CancelAll();
        _charging = false;
        me->SetControlled(false, UNIT_STATE_STUNNED);
        me->RemoveAllDynObjects();
        // Source teleported home + _DespawnAtEvade(); AC 3.3.5 BossAI resets in place instead.
        BossAI::EnterEvadeMode(why);
    }

private:
    template <typename Worker>
    void ForEachPlayerInRoom(Worker&& worker)
    {
        Map::PlayerList const& players = me->GetMap()->GetPlayers();
        for (auto const& ref : players)
        {
            Player* player = ref.GetSource();
            if (!player || !player->IsAlive() || player->IsGameMaster())
                continue;
            if (me->IsWithinDistInMap(player, 100.0f))
                worker(player);
        }
    }

    bool HasOtherPlayerNear(Unit* target, float range) const
    {
        Map::PlayerList const& players = me->GetMap()->GetPlayers();
        for (auto const& ref : players)
        {
            Player* player = ref.GetSource();
            if (!player || player == target || !player->IsAlive() || player->IsGameMaster())
                continue;
            if (target->IsWithinDistInMap(player, range))
                return true;
        }
        return false;
    }

    bool _hp30;
    bool _charging;
    GuidSet _chargeHitGuids;
};
}

void AddSC_boss_sludgefist()
{
    using namespace CastleNathria::Sludgefist;
    RegisterCastleNathriaCreatureAI(boss_sludgefist);
    // TODO(port): shadowcore's AreaTriggerAI scripts (at_headless_charge, at_stonequake) have no
    // 3.3.5 equivalent. The charge collision moved into boss_sludgefist::MovementInform; restore
    // the stonequake ground hazards by authoring the *_CREATE_AT spell_dbc downports as
    // persistent-area-aura spells triggering SPELL_STONEQUAKE_AT_DAMAGE.
}
