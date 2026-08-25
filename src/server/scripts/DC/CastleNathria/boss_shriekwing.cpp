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

// DarkChaos downport of Shriekwing, first boss of Castle Nathria (Shadowlands raid, map 2296).
// Ported from ShadowCore (TrinityCore 9.x) to AzerothCore 3.3.5a idioms -- see
// DC/BlackwingDescent/PORT_NOTES.md for the API divergence log this port follows.
//
// 3.3.5 substitutions:
// - Spawned AreaTriggers do not exist. The "create areatrigger" spells are kept as plain casts;
//   author their spell_dbc downports as persistent-area-aura (DynObj) ground effects, which also
//   replaces at_sanguine_ichor's enter/exit damage handling. The moving AreaTrigger AIs
//   (at_echoing_sonar one-shot kill zones, at_echoing_screech horror zones) cannot be represented
//   and were cut -- their pools spawn as static hazards instead.
// - Mythic difficulty does not exist: the Blood Lantern carry mechanic (NPC_BLOOD_LANTERN summon,
//   at_blood_lantern, bloodlight auras) was cut entirely.
// - AURA_OVERRIDE_POWER_COLOR_RAGE (energy bar recolored to red) has no 3.3.5 counterpart.

#include "InstanceScript.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellAuras.h"
#include "SpellScript.h"
#include "castle_nathria.h"

namespace CastleNathria::Shriekwing
{
enum Spells
{
    SPELL_BLOOD_SHROUD_CAST             = 343995,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_SANGUINE_ICHOR_CREATE_AT      = 340299,   // TODO(spell_dbc): SL spell, needs downport row (author as persistent-area-aura)
    SPELL_EARSPITTING_SHRIEK_CAST       = 330711,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_EARSPITTING_SHRIEK_PERIODIC   = 330713,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_SANGUINE_ICHOR_AT_DAMAGE      = 340324,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_ECHOLOCATION_MARK             = 342077,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_DESCENT                       = 342923,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_DEADLY_DESCENT                = 343021,   // TODO(spell_dbc): SL spell, needs downport row (unused -- was at_echoing_screech)
    SPELL_EXSANGUINATING_BITE           = 328857,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_EXSANGUINATED_DEBUFF          = 328897,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_BLIND_SWIPE_CAST              = 343005,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_WAVE_OF_BLOOD                 = 345397,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_ECHOING_SONAR_CAST            = 329362,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_ECHOING_SONAR_CREATE_AT       = 329002,   // TODO(spell_dbc): SL spell, needs downport row (author as persistent-area-aura)
    SPELL_ECHOING_SONAR_DAMAGE          = 343022,   // TODO(spell_dbc): SL spell, needs downport row (unused -- was at_echoing_sonar)
    SPELL_BERSERK                       = 343364,   // TODO(spell_dbc): SL spell, needs downport row (unused in source too)
    SPELL_HORRIFIED                     = 343024,   // TODO(spell_dbc): SL spell, needs downport row (unused -- was at_echoing_screech)

    // Heroic
    SPELL_ECHOING_SCREECH_CAST          = 342864,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_ECHOING_SCREECH_CREATE_AT     = 342865,   // TODO(spell_dbc): SL spell, needs downport row (author as persistent-area-aura)

    // Mythic -- unreferenced after the Blood Lantern cut, kept for downport reference
    SPELL_BLOOD_LANTER_APPLY_AT         = 344124,
    SPELL_BLOOD_LANTERN_GRANT_BUTTON    = 341684,
    SPELL_BLOOD_LANTERN_STUN            = 341490,
    SPELL_BLOOD_LANTER_APPLY_AT_2       = 341690,
    SPELL_BLODLIGHT_APPLY_AT            = 343303,
    SPELL_BLOODLIGHT_PERIODIC_DUMMY     = 341489,
    SPELL_RAVENOUS_HORROR_MISSILE       = 344762,
    SPELL_BLOODLIGHT_PERIODIC_DAMAGE_TRIGGER = 344235
};

enum Events
{
    EVENT_GAIN_ENERGY           = 1,
    EVENT_PHASE_ONE             = 2,
    EVENT_ECHOING_SONAR_SPAWN   = 3,
    EVENT_ECHOING_SCREECH_SPAWN = 4,
    EVENT_EXSANGUINATING_BITE = 5,  // was raw SPELL_EXSANGUINATING_BITE
    EVENT_ECHOLOCATION_MARK = 6,  // was raw SPELL_ECHOLOCATION_MARK
    EVENT_BLIND_SWIPE_CAST = 7,  // was raw SPELL_BLIND_SWIPE_CAST
    EVENT_WAVE_OF_BLOOD = 8,  // was raw SPELL_WAVE_OF_BLOOD
    EVENT_EARSPITTING_SHRIEK_CAST = 9  // was raw SPELL_EARSPITTING_SHRIEK_CAST
};

enum Texts
{
    // creature_text GroupIDs for entry 164406 (Custom/.../worlddb/CastleNathria/09_creature_text.sql).
    // The source AI had no Talk() calls; these hook the two DB announce lines to their abilities.
    SAY_ANNOUNCE_EARSPLITTING_SHRIEK    = 0,
    SAY_ANNOUNCE_BLOOD_SHROUD           = 1
};

Position const MiddlePosition       = { -1864.986f, 6779.375f, 4319.209f };
Position const EchoingSonarSpawnPos = { -1864.157f, 6790.122f, 4319.208f };
Position const EchoingSonarSpawnPos2 = { -1864.138f, 6759.732f, 4319.208f };

// 164406 - Shriekwing
struct boss_shriekwing : public BossAI
{
    boss_shriekwing(Creature* creature) : BossAI(creature, DATA_SHRIEKWING), _earSpitting(0) { }

    void Reset() override
    {
        _Reset();
        me->setPowerType(POWER_ENERGY);
        me->SetMaxPower(POWER_ENERGY, 100);
        me->SetPower(POWER_ENERGY, 0);
        // TODO(port): source applied AURA_OVERRIDE_POWER_COLOR_RAGE here (recolors the energy bar);
        // no power-color override system on 3.3.5.
        me->SetReactState(REACT_AGGRESSIVE);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        _JustEngagedWith();
        _earSpitting = 0;
        events.ScheduleEvent(EVENT_GAIN_ENERGY, 1s);
        events.ScheduleEvent(EVENT_EXSANGUINATING_BITE, 5s);
        events.ScheduleEvent(EVENT_ECHOLOCATION_MARK, 13s);
        events.ScheduleEvent(EVENT_BLIND_SWIPE_CAST, 19s);
        events.ScheduleEvent(EVENT_WAVE_OF_BLOOD, 12s);
        if (IsHeroic())
            events.ScheduleEvent(EVENT_ECHOING_SCREECH_SPAWN, 23s);
        // TODO(port): mythic-only Blood Lantern summon (NPC_BLOOD_LANTERN, scale 2.0,
        // not-selectable, SPELL_BLOOD_LANTER_APPLY_AT_2) cut -- no mythic difficulty on 3.3.5.
    }

    void ExecuteEvent(uint32 eventId) override
    {
        // Energy poll runs on every event pop; EVENT_GAIN_ENERGY ticks each second, so this is
        // effectively a once-per-second check, as in the source.
        if (me->GetPower(POWER_ENERGY) == 100)
        {
            // Source removed the lingering echoing-sonar AreaTrigger here.
            me->RemoveDynObject(SPELL_ECHOING_SONAR_CREATE_AT);
            me->NearTeleportTo(MiddlePosition.GetPositionX(), MiddlePosition.GetPositionY(),
                MiddlePosition.GetPositionZ(), me->GetOrientation());
            me->SetPower(POWER_ENERGY, 0);
            events.Reset();
            me->AttackStop();
            me->SetReactState(REACT_PASSIVE);
            Talk(SAY_ANNOUNCE_BLOOD_SHROUD);
            me->CastSpell(me, SPELL_BLOOD_SHROUD_CAST);
            events.ScheduleEvent(EVENT_ECHOING_SONAR_SPAWN, 1s);
            events.ScheduleEvent(EVENT_EARSPITTING_SHRIEK_CAST, 3s);
            events.ScheduleEvent(EVENT_PHASE_ONE, 40s);
        }

        switch (eventId)
        {
            case EVENT_PHASE_ONE:
                me->SetReactState(REACT_AGGRESSIVE);
                events.Reset();
                events.ScheduleEvent(EVENT_GAIN_ENERGY, 1s);
                events.ScheduleEvent(EVENT_EXSANGUINATING_BITE, 5s);
                events.ScheduleEvent(EVENT_ECHOLOCATION_MARK, 8s);
                events.ScheduleEvent(EVENT_BLIND_SWIPE_CAST, 13s);
                events.ScheduleEvent(EVENT_WAVE_OF_BLOOD, 18s);
                break;
            case EVENT_GAIN_ENERGY:
                me->ModifyPower(POWER_ENERGY, 1);
                events.Repeat(1s);
                break;
            case EVENT_ECHOLOCATION_MARK:
            {
                UnitList targetList;
                SelectTargetList(targetList, 3, SelectTargetMethod::Random, 0, 100.0f, true);
                for (Unit* target : targetList)
                {
                    me->CastSpell(target, SPELL_ECHOLOCATION_MARK, TRIGGERED_FULL_MASK);
                    ObjectGuid targetGuid = target->GetGUID();
                    scheduler.Schedule(8s, [this, targetGuid](TaskContext /*context*/)
                    {
                        if (Unit* target = ObjectAccessor::GetUnit(*me, targetGuid))
                        {
                            me->CastSpell(target, SPELL_DESCENT, TRIGGERED_FULL_MASK);
                            me->CastSpell(target, SPELL_SANGUINE_ICHOR_CREATE_AT, TRIGGERED_FULL_MASK);
                        }
                    });
                }
                events.Repeat(25s);
                break;
            }
            case EVENT_EXSANGUINATING_BITE:
                if (Unit* target = SelectTarget(SelectTargetMethod::MaxThreat, 0, 30.0f))
                {
                    me->CastSpell(target, SPELL_EXSANGUINATING_BITE);
                    me->AddAura(SPELL_EXSANGUINATED_DEBUFF, target);
                    if (Aura* exsanguinated = target->GetAura(SPELL_EXSANGUINATED_DEBUFF))
                    {
                        exsanguinated->SetStackAmount(10);
                        // Source ran the stack decay through the target's per-unit scheduler with
                        // captured raw pointers; rerouted through the AI scheduler + ObjectGuid.
                        ObjectGuid targetGuid = target->GetGUID();
                        scheduler.Schedule(1500ms, [this, targetGuid](TaskContext context)
                        {
                            Unit* target = ObjectAccessor::GetUnit(*me, targetGuid);
                            if (!target)
                                return;

                            Aura* exsanguinated = target->GetAura(SPELL_EXSANGUINATED_DEBUFF);
                            if (!exsanguinated)
                                return;

                            uint8 stacks = exsanguinated->GetStackAmount();
                            if (stacks <= 2)
                                target->RemoveAura(SPELL_EXSANGUINATED_DEBUFF);
                            else
                            {
                                exsanguinated->SetStackAmount(stacks - 1);
                                context.Repeat(1500ms);
                            }
                        });
                    }
                }
                events.Repeat(20s);
                break;
            case EVENT_BLIND_SWIPE_CAST:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f))
                {
                    me->SetFacingToObject(target);
                    me->CastSpell(target, SPELL_BLIND_SWIPE_CAST);
                }
                events.Repeat(30s);
                break;
            case EVENT_WAVE_OF_BLOOD:
            {
                UnitList targetList;
                SelectTargetList(targetList, 3, SelectTargetMethod::Random, 0, 100.0f, true);
                for (Unit* target : targetList)
                    me->CastSpell(target, SPELL_WAVE_OF_BLOOD);
                events.Repeat(36s);
                break;
            }
            case EVENT_EARSPITTING_SHRIEK_CAST:
                ++_earSpitting;
                if (_earSpitting != 3)  // source quirk: the third blind phase skips the shriek
                {
                    Talk(SAY_ANNOUNCE_EARSPLITTING_SHRIEK);
                    for (auto const& ref : me->GetMap()->GetPlayers())
                    {
                        Player* player = ref.GetSource();
                        if (!player || player->IsGameMaster() || !me->IsWithinDistInMap(player, 100.0f))
                            continue;

                        me->CastSpell(player, SPELL_EARSPITTING_SHRIEK_PERIODIC, TRIGGERED_FULL_MASK);
                        if (player->IsWithinLOSInMap(me))
                            me->CastSpell(player, SPELL_SANGUINE_ICHOR_CREATE_AT, TRIGGERED_FULL_MASK);
                    }
                }
                break;
            case EVENT_ECHOING_SONAR_SPAWN:
                me->RemoveDynObject(SPELL_ECHOING_SONAR_CREATE_AT);
                me->CastSpell(me, SPELL_ECHOING_SONAR_CAST);
                // TODO(port): at_echoing_sonar made these wander the room as one-shot kill zones;
                // on 3.3.5 they stay as static pools at the two gate positions.
                for (uint8 i = 0; i < 12; ++i)
                    me->CastSpell(EchoingSonarSpawnPos.GetPositionX(), EchoingSonarSpawnPos.GetPositionY(),
                        EchoingSonarSpawnPos.GetPositionZ(), SPELL_ECHOING_SONAR_CREATE_AT, true);
                for (uint8 i = 0; i < 12; ++i)
                    me->CastSpell(EchoingSonarSpawnPos2.GetPositionX(), EchoingSonarSpawnPos2.GetPositionY(),
                        EchoingSonarSpawnPos2.GetPositionZ(), SPELL_ECHOING_SONAR_CREATE_AT, true);
                break;
            case EVENT_ECHOING_SCREECH_SPAWN:
                me->RemoveDynObject(SPELL_ECHOING_SCREECH_CREATE_AT);
                me->CastSpell(me, SPELL_ECHOING_SCREECH_CAST);
                // TODO(port): at_echoing_screech applied SPELL_HORRIFIED + SPELL_DEADLY_DESCENT to
                // touched players from a moving AreaTrigger; static pools only on 3.3.5.
                for (uint8 i = 0; i < 10; ++i)
                    me->CastSpell(me, SPELL_ECHOING_SCREECH_CREATE_AT, TRIGGERED_FULL_MASK);
                break;
            default:
                break;
        }
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        me->RemoveAllDynObjects();
        // Source also despawned the mythic Blood Lantern (cut) and used _DespawnAtEvade();
        // AC 3.3.5 BossAI resets in place instead.
        BossAI::EnterEvadeMode(why);
    }

    void JustDied(Unit* /*killer*/) override
    {
        me->RemoveAllDynObjects();
        _JustDied();
    }

private:
    uint8 _earSpitting;
};

// 343995 - Blood Shroud
// Drops targets that broke line of sight (hiding behind the pillars).
class spell_blood_shroud : public SpellScript
{
    PrepareSpellScript(spell_blood_shroud);

    void FilterTargets(std::list<WorldObject*>& targets)
    {
        Unit* caster = GetCaster();
        if (!caster)
            return;

        targets.remove_if([caster](WorldObject* target)
        {
            return !target->IsWithinLOS(caster->GetPositionX(), caster->GetPositionY(), caster->GetPositionZ());
        });
    }

    void Register() override
    {
        // Deliberately binds nothing. 343995 is a SELF-cast (see CastSpell(me, ...) above)
        // and retail agrees: both its effects are APPLY_AURA on ImplicitTarget 1 (caster) --
        // idx0 DUMMY, idx1 PERIODIC_DUMMY -- with radius index 0. There is no area target
        // list for OnObjectAreaTargetSelect to filter, so that binding could never fire and
        // only produced a boot-log error.
        //
        // The LOS/pillar mechanic this filter belongs to is driven by an AreaTrigger in the
        // source (see the at_sanguine_ichor / at_echoing_sonar TODO in AddSC below), which
        // 3.3.5 has no equivalent for. FilterTargets is kept as the ready-made predicate for
        // whoever ports that; turning the boss's self-buff into a 60y area nuke to give it
        // something to filter would invent a mechanic, not downport one.
    }
};
}

void AddSC_boss_shriekwing()
{
    using namespace CastleNathria;
    using namespace CastleNathria::Shriekwing;
    RegisterCastleNathriaCreatureAI(boss_shriekwing);
    RegisterSpellScript(spell_blood_shroud);
    // TODO(port): shadowcore's AreaTriggerAI scripts (at_sanguine_ichor, at_echoing_sonar,
    // at_echoing_screech, at_blood_lantern) have no 3.3.5 equivalent. Author the *_CREATE_AT
    // spell_dbc downports as persistent-area-aura spells triggering their damage spells
    // (e.g. SPELL_SANGUINE_ICHOR_AT_DAMAGE) to restore the ground hazards.
}
