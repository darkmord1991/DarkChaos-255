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

// DarkChaos downport of Huntsman Altimor, second boss of Castle Nathria (Shadowlands raid, map 2296).
// Ported from ShadowCore (TrinityCore 9.x) to AzerothCore 3.3.5a idioms -- see
// DC/BlackwingDescent/PORT_NOTES.md for the API divergence log this port follows.
//
// 3.3.5 substitutions:
// - Spawned AreaTriggers do not exist. at_stone_shards (Hecutis' Petrifying Howl ground hazard) was
//   cut; author SPELL_PETRIFYING_HOWL_CREATE_AT's spell_dbc downport as a persistent-area-aura
//   (DynObj) ground effect triggering SPELL_STONE_SHARDS_AT_DAMAGE to restore it.
// - Mythic difficulty does not exist: mythic-only Shatter Shot was cut; heroic/mythic forks
//   collapse to IsHeroic().
// - The pets used shadowcore's ScriptedAI events/ExecuteEvent pump, which AC's ScriptedAI lacks --
//   they drive the inherited EventMap/TaskScheduler from a local UpdateAI instead.

#include "InstanceScript.h"
#include "Map.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "PetDefines.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellAuras.h"
#include "SpellScript.h"
#include "castle_nathria.h"

namespace CastleNathria::HuntsmanAltimor
{
enum Spells
{
    SPELL_SPREADSHOT                    = 334404,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_SINSEEKER                     = 335114,   // TODO(spell_dbc): SL spell, needs downport row -- every 45s, 3 targets
    SPELL_SINSEEKER_PERIODIC_DAMAGE     = 335304,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_SINSEEKER_INIT_DAMAGE         = 335116,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_SINSEEKER_CONVERSATION        = 335488,   // TODO(spell_dbc): SL spell, needs downport row (unused in source too)
    SPELL_HUNTSMAN_BLOOD                = 334504,   // TODO(spell_dbc): SL spell, needs downport row (shared-health link)

    // Margore 165067
    SPELL_JAGGED_CLAWS                  = 334971,   // TODO(spell_dbc): SL spell, needs downport row -- 10-20s, tank
    SPELL_VICIOUS_LUNGE_CIRCLE          = 334939,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_VICIOUS_LUNGE_MARK            = 334945,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_VICIOUS_LUNGE_CHARGE          = 266947,   // TODO(spell_dbc): BfA spell, needs downport row

    // Bargast 169457
    SPELL_RIP_SOUL                      = 334797,   // TODO(spell_dbc): SL spell, needs downport row (event id only in source)
    SPELL_DEVOUR_SOUL                   = 334884,   // TODO(spell_dbc): SL spell, needs downport row (heals Altimor when a soul reaches him)
    SPELL_SHADES_OF_BARGAST             = 334757,   // TODO(spell_dbc): SL spell, needs downport row (summons NPC_SHADE_OF_BARGAST)
    SPELL_DEATHLY_ROAR                  = 334708,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_DESTABILIZE                   = 334695,   // TODO(spell_dbc): SL spell, needs downport row (unused in source too)

    // Hecutis 169458
    SPELL_CRUSHING_STONE                = 334860,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_PETRIFYING_HOWL               = 334852,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_PETRIFYING_HOWL_CREATE_AT     = 334889,   // TODO(spell_dbc): SL spell, needs downport row (author as persistent-area-aura)
    SPELL_STONE_SHARDS_AT_DAMAGE        = 334893,   // TODO(spell_dbc): SL spell, needs downport row (unused -- was at_stone_shards)
    SPELL_CHARGE                        = 343259,   // TODO(spell_dbc): SL spell, needs downport row

    // Heroic
    SPELL_VICIOUS_WOUND                 = 334960,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_RIPPED_SOUL_AOE               = 339638,   // TODO(spell_dbc): SL spell, needs downport row

    // Mythic -- unreferenced after the mythic cut, kept for downport reference
    SPELL_SHATTER_SHOT_DAMAGE           = 338593
    // The events reuse their spell ids, as in the source.
};

enum Events
{
    EVENT_SPREADSHOT = 1,  // was raw SPELL_SPREADSHOT
    EVENT_VICIOUS_LUNGE_CIRCLE = 2,  // was raw SPELL_VICIOUS_LUNGE_CIRCLE
    EVENT_SINSEEKER = 3,  // was raw SPELL_SINSEEKER
    EVENT_JAGGED_CLAWS = 4,  // was raw SPELL_JAGGED_CLAWS
    EVENT_RIP_SOUL = 5,  // was raw SPELL_RIP_SOUL
    EVENT_SHADES_OF_BARGAST = 6,  // was raw SPELL_SHADES_OF_BARGAST
    EVENT_CRUSHING_STONE = 7,  // was raw SPELL_CRUSHING_STONE
    EVENT_PETRIFYING_HOWL = 8,  // was raw SPELL_PETRIFYING_HOWL
    EVENT_DEATHLY_ROAR = 9  // was raw SPELL_DEATHLY_ROAR
};

// NOTE: no creature_text in DB yet for 165066 (see Custom/.../worlddb/CastleNathria/09_creature_text.sql);
// Talk() group ids preserved from the source AI.
enum Texts
{
    SAY_AGGRO           = 0,
    SAY_VICIOUS_LUNGE   = 2,
    SAY_MARGORE_DEAD    = 3,
    SAY_RIP_SOUL        = 4
};

Position const MargoreSpawnPos = { -1651.586f, 6700.420f, 4279.040f, 3.233f };
Position const BargastSpawnPos = { -1652.252f, 6682.398f, 4279.040f, 3.233f };
Position const HecutisSpawnPos = { -1651.693f, 6717.287f, 4279.040f, 3.233f };

// 165066 - Huntsman Altimor
struct boss_huntsman_altimor : public BossAI
{
    boss_huntsman_altimor(Creature* creature) : BossAI(creature, DATA_HUNTSMAN_ALTIMOR) { }

    void Reset() override
    {
        _Reset();
        me->SetReactState(REACT_AGGRESSIVE);
        me->SummonCreature(NPC_MARGORE, MargoreSpawnPos, TEMPSUMMON_MANUAL_DESPAWN);
        me->AddAura(SPELL_HUNTSMAN_BLOOD, me);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        _JustEngagedWith();
        Talk(SAY_AGGRO);    // NOTE: no creature_text in DB yet
        events.ScheduleEvent(EVENT_SPREADSHOT, 6s);
        // Source quirk kept: SPELL_VICIOUS_LUNGE_CIRCLE is scheduled on the boss but only
        // Margore's AI handles it -- the pop is a no-op here.
        events.ScheduleEvent(EVENT_VICIOUS_LUNGE_CIRCLE, 17s);
        events.ScheduleEvent(EVENT_SINSEEKER, 27s);
        if (Creature* margore = me->FindNearestCreature(NPC_MARGORE, 100.0f, true))
            margore->AI()->DoZoneInCombat();
    }

    void JustSummoned(Creature* summon) override
    {
        summons.Summon(summon);
        switch (summon->GetEntry())
        {
            case NPC_MARGORE:
                summon->SetFacingTo(3.233f);
                summon->AddAura(SPELL_HUNTSMAN_BLOOD, summon);
                break;
            case NPC_BARGAST:
            case NPC_HECUTIS:
                summon->AddAura(SPELL_HUNTSMAN_BLOOD, summon);
                summon->AI()->DoZoneInCombat();
                break;
            default:
                break;
        }
    }

    void SummonedCreatureDies(Creature* summon, Unit* /*killer*/) override
    {
        switch (summon->GetEntry())
        {
            case NPC_MARGORE:
                Talk(SAY_MARGORE_DEAD);     // NOTE: no creature_text in DB yet
                me->SummonCreature(NPC_BARGAST, BargastSpawnPos, TEMPSUMMON_MANUAL_DESPAWN);
                break;
            case NPC_BARGAST:
                me->SummonCreature(NPC_HECUTIS, HecutisSpawnPos, TEMPSUMMON_MANUAL_DESPAWN);
                break;
            default:
                break;
        }
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_SPREADSHOT:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                {
                    me->SetFacingToObject(target);
                    me->CastSpell(target, SPELL_SPREADSHOT);
                }
                events.Repeat(20s);
                break;
            case EVENT_SINSEEKER:
            {
                UnitList targetList;
                SelectTargetList(targetList, 3, SelectTargetMethod::Random, 0, 100.0f, true);
                for (Unit* target : targetList)
                {
                    me->CastSpell(me, SPELL_SINSEEKER);     // one cast per target, as in the source
                    // Source captured the raw target pointer into the scheduler; rerouted via ObjectGuid.
                    ObjectGuid targetGuid = target->GetGUID();
                    scheduler.Schedule(100ms, [this, targetGuid](TaskContext /*context*/)
                    {
                        if (Unit* target = ObjectAccessor::GetUnit(*me, targetGuid))
                        {
                            me->CastSpell(target, SPELL_SINSEEKER_INIT_DAMAGE, TRIGGERED_FULL_MASK);
                            me->CastSpell(target, SPELL_SINSEEKER_PERIODIC_DAMAGE, TRIGGERED_FULL_MASK);
                        }
                    });
                }
                events.Repeat(45s);
                break;
            }
            default:
                break;
        }
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        summons.DespawnAll();
        DespawnShades();
        me->RemoveAllDynObjects();  // source: RemoveAllAreaTriggers()
        // Source teleported home + _DespawnAtEvade(); AC 3.3.5 BossAI resets in place instead.
        BossAI::EnterEvadeMode(why);
    }

    void JustDied(Unit* /*killer*/) override
    {
        summons.DespawnAll();
        DespawnShades();
        me->RemoveAllDynObjects();  // source: RemoveAllAreaTriggers()
        _JustDied();
    }

private:
    // Shades are summoned by Bargast's spell cast, so they are not in the boss' summon list.
    // Substitute for TC's Creature::DespawnCreaturesInArea, which AC lacks.
    void DespawnShades()
    {
        std::list<Creature*> shades;
        GetCreatureListWithEntryInGrid(shades, me, NPC_SHADE_OF_BARGAST, 100.0f);
        for (Creature* shade : shades)
            shade->DespawnOrUnsummon();
    }
};

// 165067 - Margore, 169457 - Bargast, 169458 - Hecutis
struct npc_altimor_pet : public ScriptedAI
{
    npc_altimor_pet(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        events.Reset();
        scheduler.CancelAll();
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        if (InstanceScript* instance = me->GetInstanceScript())
            instance->SendEncounterUnit(ENCOUNTER_FRAME_ENGAGE, me);

        switch (me->GetEntry())
        {
            case NPC_MARGORE:
                events.ScheduleEvent(EVENT_JAGGED_CLAWS, 5s);
                events.ScheduleEvent(EVENT_VICIOUS_LUNGE_CIRCLE, 10s);
                break;
            case NPC_BARGAST:
                events.ScheduleEvent(EVENT_RIP_SOUL, 5s);
                events.ScheduleEvent(EVENT_SHADES_OF_BARGAST, 10s);
                break;
            case NPC_HECUTIS:
                events.ScheduleEvent(EVENT_CRUSHING_STONE, 5s);
                events.ScheduleEvent(EVENT_PETRIFYING_HOWL, 10s);
                break;
            default:
                break;
        }
    }

    void JustDied(Unit* /*killer*/) override
    {
        // Not in the source, but required on 3.3.5 to clear the boss frame again.
        if (InstanceScript* instance = me->GetInstanceScript())
            instance->SendEncounterUnit(ENCOUNTER_FRAME_DISENGAGE, me);
    }

    void ExecuteEvent(uint32 eventId)
    {
        switch (eventId)
        {
            case EVENT_JAGGED_CLAWS:
                DoCastVictim(SPELL_JAGGED_CLAWS, false);
                events.Repeat(10s, 20s);
                break;
            case EVENT_VICIOUS_LUNGE_CIRCLE:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                {
                    if (Creature* altimor = me->FindNearestCreature(NPC_HUNTSMAN_ALTIMOR, 100.0f, true))
                        altimor->AI()->Talk(SAY_VICIOUS_LUNGE);     // NOTE: no creature_text in DB yet
                    me->SetFacingToObject(target);
                    me->CastSpell(target, SPELL_VICIOUS_LUNGE_CIRCLE, TRIGGERED_FULL_MASK);
                    me->AddAura(SPELL_VICIOUS_LUNGE_MARK, target);
                    // Source captured the raw target pointer into the scheduler; rerouted via ObjectGuid.
                    ObjectGuid targetGuid = target->GetGUID();
                    scheduler.Schedule(6100ms, [this, targetGuid](TaskContext /*context*/)
                    {
                        if (Unit* target = ObjectAccessor::GetUnit(*me, targetGuid))
                            me->CastSpell(target, SPELL_CHARGE, TRIGGERED_FULL_MASK);
                    });
                }
                events.Repeat(30s, 35s);
                break;
            case EVENT_RIP_SOUL:
                // Source quirk kept: SPELL_RIP_SOUL is only used as event id; the soul is
                // summoned directly instead of being torn out via the spell.
                if (Creature* altimor = me->FindNearestCreature(NPC_HUNTSMAN_ALTIMOR, 100.0f, true))
                    altimor->AI()->Talk(SAY_RIP_SOUL);      // NOTE: no creature_text in DB yet
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                    me->SummonCreature(NPC_RIPPED_SOUL, *target, TEMPSUMMON_TIMED_DESPAWN, 60000);   // source left the despawn timer defaulted
                events.Repeat(10s, 20s);
                break;
            case EVENT_SHADES_OF_BARGAST:
            {
                // Source condition (!IsHeroic() || !IsMythic()) was always true; the intent
                // (1 shade on normal, 2 on heroic/mythic) is restored here.
                uint8 count = IsHeroic() ? 2 : 1;
                for (uint8 i = 0; i < count; ++i)
                {
                    Position pos = me->GetRandomNearPosition(15.0f);
                    me->CastSpell(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ(),
                        SPELL_SHADES_OF_BARGAST, false);
                }
                events.Repeat(30s, 35s);
                break;
            }
            case EVENT_CRUSHING_STONE:
                me->AddAura(SPELL_CRUSHING_STONE, me);
                events.Repeat(2s);
                break;
            case EVENT_PETRIFYING_HOWL:
            {
                DoCastAOE(SPELL_PETRIFYING_HOWL, false);
                UnitList targetList;
                SelectTargetList(targetList, 3, SelectTargetMethod::Random, 0, 100.0f, true);
                for (Unit* target : targetList)
                {
                    me->AddAura(SPELL_PETRIFYING_HOWL, target);
                    // Source captured the raw target pointer into the scheduler; rerouted via ObjectGuid.
                    ObjectGuid targetGuid = target->GetGUID();
                    scheduler.Schedule(8s, [this, targetGuid](TaskContext /*context*/)
                    {
                        if (Unit* target = ObjectAccessor::GetUnit(*me, targetGuid))
                            target->CastSpell(target->GetPositionX(), target->GetPositionY(), target->GetPositionZ(),
                                SPELL_PETRIFYING_HOWL_CREATE_AT, true);
                    });
                }
                events.Repeat(30s, 35s);
                break;
            }
            default:
                break;
        }
    }

    void UpdateAI(uint32 diff) override
    {
        // AC's ScriptedAI has no events/ExecuteEvent pump (shadowcore's did) -- drive the
        // inherited EventMap/TaskScheduler here.
        if (!UpdateVictim())
            return;

        events.Update(diff);
        scheduler.Update(diff);

        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        while (uint32 eventId = events.ExecuteEvent())
        {
            ExecuteEvent(eventId);
            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;
        }

        DoMeleeAttackIfReady();
    }
};

// 171557 - Shade of Bargast
struct npc_shade_of_bargast : public ScriptedAI
{
    npc_shade_of_bargast(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        events.Reset();
        if (me->GetMap()->IsRaid())
            DoZoneInCombat();
        // NOTE(port): SPELL_DESTABILIZE (on-death stacking buff to surviving shades) was
        // unreferenced in the source AI too; wire it up once the spell_dbc row is authored.
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        if (InstanceScript* instance = me->GetInstanceScript())
            instance->SendEncounterUnit(ENCOUNTER_FRAME_ENGAGE, me);
        events.ScheduleEvent(EVENT_DEATHLY_ROAR, 3s);
    }

    void JustDied(Unit* /*killer*/) override
    {
        // Not in the source, but required on 3.3.5 to clear the boss frame again.
        if (InstanceScript* instance = me->GetInstanceScript())
            instance->SendEncounterUnit(ENCOUNTER_FRAME_DISENGAGE, me);
    }

    void UpdateAI(uint32 diff) override
    {
        if (!UpdateVictim())
            return;

        events.Update(diff);

        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        while (uint32 eventId = events.ExecuteEvent())
        {
            if (eventId == SPELL_DEATHLY_ROAR)
            {
                DoCastAOE(SPELL_DEATHLY_ROAR, false);
                events.Repeat(20s, 25s);
            }
            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;
        }

        DoMeleeAttackIfReady();
    }
};

// 171577 - Ripped Soul
struct npc_ripped_soul : public ScriptedAI
{
    npc_ripped_soul(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(WorldObject* /*summoner*/) override
    {
        if (Creature* altimor = me->FindNearestCreature(NPC_HUNTSMAN_ALTIMOR, 100.0f, true))
        {
            if (IsHeroic())
                me->CastSpell(nullptr, SPELL_RIPPED_SOUL_AOE, TRIGGERED_FULL_MASK);
            Unit::DealDamage(me, me, me->GetMaxHealth() / 2);   // spawns at half health
            me->SetWalk(true);
            me->GetMotionMaster()->MoveFollow(altimor, PET_FOLLOW_DIST, PET_FOLLOW_ANGLE);
        }
    }

    void MoveInLineOfSight(Unit* who) override
    {
        if (!who->IsCreature() || who->GetEntry() != NPC_HUNTSMAN_ALTIMOR)
            return;

        if (me->GetDistance(who) > 5.0f)
            return;

        if (!who->HasAura(SPELL_DEVOUR_SOUL))
        {
            me->AddAura(SPELL_DEVOUR_SOUL, who);
            me->DespawnOrUnsummon();
        }
    }
};

// 334939 - Vicious Lunge
class spell_vicious_lunge_damage : public SpellScript
{
    PrepareSpellScript(spell_vicious_lunge_damage);

    void GetTargetCount(std::list<WorldObject*>& targets)
    {
        _targetCount = targets.size();
    }

    void HandleOnHit()
    {
        if (!_targetCount)  // source divided unguarded
            return;

        SetHitDamage(GetHitDamage() / int32(_targetCount));
        if (Unit* caster = GetCaster())
            if (caster->GetMap()->IsHeroic())
                caster->CastSpell(GetHitUnit(), SPELL_VICIOUS_WOUND, TRIGGERED_FULL_MASK);
    }

    void Register() override
    {
        // NOTE: effect/target must match the authored spell_dbc downport (source hooked EFFECT_0).
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(spell_vicious_lunge_damage::GetTargetCount,
            EFFECT_0, TARGET_UNIT_SRC_AREA_ENEMY);
        OnHit += SpellHitFn(spell_vicious_lunge_damage::HandleOnHit);
    }

private:
    uint32 _targetCount = 0;
};
}

void AddSC_boss_huntsman_altimor()
{
    using namespace CastleNathria;
    using namespace CastleNathria::HuntsmanAltimor;
    RegisterCastleNathriaCreatureAI(boss_huntsman_altimor);
    RegisterCastleNathriaCreatureAI(npc_altimor_pet);
    RegisterCastleNathriaCreatureAI(npc_shade_of_bargast);
    RegisterCastleNathriaCreatureAI(npc_ripped_soul);
    RegisterSpellScript(spell_vicious_lunge_damage);
    // TODO(port): shadowcore's at_stone_shards AreaTriggerAI has no 3.3.5 equivalent. Author the
    // SPELL_PETRIFYING_HOWL_CREATE_AT spell_dbc downport as a persistent-area-aura spell
    // triggering SPELL_STONE_SHARDS_AT_DAMAGE to restore the ground hazard.
}
