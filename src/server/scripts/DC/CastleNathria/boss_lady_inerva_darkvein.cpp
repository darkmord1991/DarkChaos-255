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

// DarkChaos downport of Lady Inerva Darkvein, sixth boss of Castle Nathria (map 2296).
// Ported from ShadowCore (TrinityCore 9.x) to AzerothCore 3.3.5a idioms -- see
// DC/BlackwingDescent/PORT_NOTES.md for the API divergence log this port follows.
//
// 3.3.5 substitutions:
// - Spawned AreaTriggers do not exist: at_bottled_anima, at_lingering_anima and
//   at_fragments_of_shadow were cut. The *_CREATE_AT spells are kept as plain casts; author
//   their spell_dbc downports as persistent-area-aura (DynObj) ground effects. The Fragments
//   of Shadow ring cannot travel outwards -- the fragments spawn as a static ring instead.
// - The anima-container spellclick minigame (Containers of Desire/Sin/Anima, Loose Anima,
//   Container Breach) was not implemented in the source AI and is not ported.
// - AURA_OVERRIDE_POWER_COLOR_RAGE (energy bar recolored to red) has no 3.3.5 counterpart.
//
// NOTE: no creature_text in DB yet for 165521 (the source had no Talk() calls).

#include "InstanceScript.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellAuraEffects.h"
#include "SpellScript.h"
#include "castle_nathria.h"

namespace CastleNathria::LadyInervaDarkvein
{
enum Spells
{
    SPELL_LOOSE_ANIMA_PERIODIC_DAMAGE   = 325184,   // TODO(spell_dbc): SL spell, needs downport row (unused -- container minigame)
    SPELL_CONTAINER_BREACH              = 325225,   // TODO(spell_dbc): SL spell, needs downport row (unused -- container minigame)
    SPELL_FOCUS_ANIMA_CREATE_AT         = 331844,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_EXPOSE_DESIRES                = 325379,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_EXPOSE_DESIRES_DAMAGE         = 341621,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_WARPED_DESIRES_DEBUFF         = 325382,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_EXPOSE_COGNITION              = 341623,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_SHARED_COGNITION              = 325908,   // TODO(spell_dbc): SL spell, needs downport row

    // Exposed
    SPELL_CHANGE_OF_HEART_TRIGGER       = 340452,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_CHANGE_OF_HEART_DAMAGE        = 325384,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_BOTTLED_ANIMA_CAST            = 339557,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_BOTTLED_ANIMA                 = 342280,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_BOTTLED_ANIMA_MISSILE         = 339556,   // TODO(spell_dbc): SL spell, needs downport row (was at_bottled_anima)
    SPELL_BOTTLED_ANIMA_CREATE_AT       = 329620,   // TODO(spell_dbc): SL spell, needs downport row (author as persistent-area-aura)
    SPELL_UNLEASHED_VOLATILY            = 329618,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_LINGERING_ANIMA_CREATE_AT     = 325718,   // TODO(spell_dbc): SL spell, needs downport row (author as persistent-area-aura)
    SPELL_LINGERING_ANIMA_AT_DAMAGE     = 325713,   // TODO(spell_dbc): SL spell, needs downport row (was at_lingering_anima)
    SPELL_LESSER_SINS_AND_SUFFERING     = 342287,   // TODO(spell_dbc): SL spell, needs downport row (unused -- summons done directly)
    SPELL_ANIMA_WEB                     = 326139,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_SINS_OF_THE_PAST_DAMAGE       = 326040,   // TODO(spell_dbc): SL spell, needs downport row (unused -- 166766 ability)
    SPELL_INDEMNIFICATION_PERIODIC      = 331527,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_SHARED_SUFFERING              = 324983,   // TODO(spell_dbc): SL spell, needs downport row (source: "missing data")
    SPELL_GREATER_SINS_OF_SUFFERING     = 342290,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_LIGHTLY_CONCETRATED_ANIMA     = 342320,   // TODO(spell_dbc): SL spell, needs downport row (source typo preserved)
    SPELL_CONCENTRATED_ANIMA            = 342321,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_ROOTED_IN_ANIMA               = 341746,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_ANIMA_WEB_CREATE_AT           = 339614,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_ANIMA_WEB_CREATE_AT_2         = 326094,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_ANIMA_WEB_AT_DAMAGE           = 339612,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_CONCETRATED_ANIMA_PERIODIC    = 332664,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_HIGHLY_CONCETRATED_ANIMA_CAST = 342322,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_FRAGMENTS_OF_SHADOW_DAMAGE    = 325596,   // TODO(spell_dbc): SL spell, needs downport row (was at_fragments_of_shadow)
    SPELL_FRAGHMENTS_OF_SHADOW_CREATE_AT = 327125   // TODO(spell_dbc): SL spell, needs downport row (author as persistent-area-aura)
};

enum Events
{
    EVENT_GAIN_ENERGY = 1,
    EVENT_EXPOSE_DESIRES,
    EVENT_EXPOSED_COGNITION,
    EVENT_EXPOSED_HEART,
    EVENT_BOTTLED_ANIMA,
    EVENT_LINGERING_ANIMA,
    EVENT_REPLICATING_ANIMA,
    EVENT_LESSER_SINS_AND_SUFFERING,
    EVENT_LIGHTLY_CONCENTRATED_ANIMA,
    EVENT_HIGHLY_CONCENTRATED_ANIMA
};

Position const SinsOfThePastSpawnPos  = { -1612.527f, 6983.473f, 4291.221f, 0.0f };
Position const SinsOfThePastSpawnPos2 = { -1601.090f, 6972.282f, 4291.222f, 0.0f };
Position const SinsOfThePastSpawnPos3 = { -1601.068f, 6995.120f, 4291.221f, 0.0f };

// 165521 - Lady Inerva Darkvein
struct boss_lady_inerva_darkvein : public BossAI
{
    boss_lady_inerva_darkvein(Creature* creature) : BossAI(creature, DATA_LADY_INERVA_DARKVEIN) { }

    void Reset() override
    {
        _Reset();
        me->setPowerType(POWER_ENERGY);
        me->SetMaxPower(POWER_ENERGY, 100);
        me->SetPower(POWER_ENERGY, 0);
        me->SetReactState(REACT_AGGRESSIVE);
        // TODO(port): source applied AURA_OVERRIDE_POWER_COLOR_RAGE here (recolors the energy
        // bar); no power-color override system on 3.3.5.
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        _JustEngagedWith();
        events.ScheduleEvent(EVENT_GAIN_ENERGY, 1s);
        events.ScheduleEvent(EVENT_EXPOSE_DESIRES, 5s);
        events.ScheduleEvent(EVENT_EXPOSED_COGNITION, 14s);
        events.ScheduleEvent(EVENT_EXPOSED_HEART, 47s);
        events.ScheduleEvent(EVENT_BOTTLED_ANIMA, 35s);
        events.ScheduleEvent(EVENT_LESSER_SINS_AND_SUFFERING, 50s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        // Energy wraps at full; runs on every event pop as in the source (EVENT_GAIN_ENERGY
        // ticks each second, so this is effectively a once-per-second check).
        if (me->GetPowerPct(POWER_ENERGY) >= 100.0f)
            me->SetPower(POWER_ENERGY, 0);

        switch (eventId)
        {
            case EVENT_GAIN_ENERGY:
                me->ModifyPower(POWER_ENERGY, irand(5, 15));
                events.Repeat(1s);
                break;
            case EVENT_EXPOSE_DESIRES:
                me->CastSpell(nullptr, SPELL_EXPOSE_DESIRES, true);
                if (Unit* target = SelectTarget(SelectTargetMethod::MaxThreat, 0, 100.0f, true))
                {
                    me->CastSpell(target, SPELL_EXPOSE_DESIRES_DAMAGE, false);
                    me->AddAura(SPELL_WARPED_DESIRES_DEBUFF, target);
                }
                events.Repeat(19s);
                break;
            case EVENT_EXPOSED_COGNITION:
                if (Unit* target = SelectTarget(SelectTargetMethod::MaxThreat, 0, 100.0f, true))
                {
                    me->CastSpell(target, SPELL_EXPOSE_DESIRES_DAMAGE, false);
                    me->AddAura(SPELL_WARPED_DESIRES_DEBUFF, target);
                    if (Unit* cognitionTarget = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                        me->AddAura(SPELL_SHARED_COGNITION, cognitionTarget);

                    events.ScheduleEvent(EVENT_LINGERING_ANIMA, 1s);
                    events.ScheduleEvent(EVENT_LIGHTLY_CONCENTRATED_ANIMA, 2s);
                }
                events.Repeat(33s);
                break;
            case EVENT_EXPOSED_HEART:
                if (Unit* target = SelectTarget(SelectTargetMethod::MaxThreat, 0, 100.0f, true))
                    if (!target->HasAura(SPELL_WARPED_DESIRES_DEBUFF))
                        me->AddAura(SPELL_CHANGE_OF_HEART_TRIGGER, target);

                events.ScheduleEvent(EVENT_REPLICATING_ANIMA, 1s);
                events.ScheduleEvent(EVENT_HIGHLY_CONCENTRATED_ANIMA, 2s);
                events.Repeat(66s);
                break;
            case EVENT_BOTTLED_ANIMA:
                me->CastSpell(nullptr, SPELL_BOTTLED_ANIMA_CAST, false);
                ForEachPlayerInRoom([this](Player* player)
                {
                    // NOTE: the source rolled a random near-position and discarded it, dropping
                    // the pool on the player instead; the scatter is applied here.
                    Position pos = player->GetRandomNearPosition(5.0f);
                    me->CastSpell(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ(),
                        SPELL_BOTTLED_ANIMA_CREATE_AT, true);
                });
                events.Repeat(35s);
                break;
            case EVENT_LINGERING_ANIMA:
                ForEachPlayerInRoom([this](Player* player)
                {
                    Position pos = player->GetRandomNearPosition(5.0f);
                    me->CastSpell(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ(),
                        SPELL_BOTTLED_ANIMA_CREATE_AT, true);
                    me->CastSpell(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ(),
                        SPELL_LINGERING_ANIMA_CREATE_AT, true);
                });
                break;
            case EVENT_REPLICATING_ANIMA:
                ForEachPlayerInRoom([this](Player* player)
                {
                    Position pos = player->GetRandomNearPosition(5.0f);
                    me->CastSpell(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ(),
                        SPELL_BOTTLED_ANIMA_CREATE_AT, true);
                });
                break;
            case EVENT_LESSER_SINS_AND_SUFFERING:
            {
                me->SummonCreature(NPC_SINS_OF_THE_PAST, SinsOfThePastSpawnPos, TEMPSUMMON_MANUAL_DESPAWN);
                me->SummonCreature(NPC_SINS_OF_THE_PAST, SinsOfThePastSpawnPos2, TEMPSUMMON_MANUAL_DESPAWN);
                me->SummonCreature(NPC_SINS_OF_THE_PAST, SinsOfThePastSpawnPos3, TEMPSUMMON_MANUAL_DESPAWN);
                UnitList targetList;
                SelectTargetList(targetList, 3, SelectTargetMethod::Random, 0, 100.0f, true);
                for (Unit* target : targetList)
                    me->CastSpell(target, SPELL_SHARED_SUFFERING, true);
                events.Repeat(50s);
                break;
            }
            case EVENT_LIGHTLY_CONCENTRATED_ANIMA:
                me->CastSpell(nullptr, SPELL_LIGHTLY_CONCETRATED_ANIMA, false);
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                {
                    me->CastSpell(target, SPELL_CONCETRATED_ANIMA_PERIODIC, true);
                    me->AddAura(SPELL_ROOTED_IN_ANIMA, target);
                    if (IsHeroic()) // source: heroic + mythic; no mythic on 3.3.5
                        DoCastRandomTarget(SPELL_CONCETRATED_ANIMA_PERIODIC, 0, 100.0f, true, true);
                }
                break;
            case EVENT_HIGHLY_CONCENTRATED_ANIMA:
                me->CastSpell(nullptr, SPELL_HIGHLY_CONCETRATED_ANIMA_CAST, false);
                ForEachPlayerInRoom([this](Player* player)
                {
                    if (!player->HasAura(SPELL_CONCENTRATED_ANIMA))
                        return;

                    // Two mirrored 180-degree arcs of Fragments of Shadow around a random axis.
                    // TODO(port): the source AreaTriggers travelled 30 yd outwards
                    // (at_fragments_of_shadow); the ring spawns as static hazards on 3.3.5.
                    float const randAngle = frand(0.0f, 2.0f * float(M_PI));
                    float const step = float(M_PI) / 14.0f;
                    for (uint8 i = 0; i < 15; ++i)
                    {
                        // NOTE: GetNearPosition substitutes TC's GetPositionWithDistInOrientation.
                        Position posOne = me->GetNearPosition(8.0f, randAngle + step * float(i));
                        me->CastSpell(posOne.GetPositionX(), posOne.GetPositionY(), posOne.GetPositionZ(),
                            SPELL_FRAGHMENTS_OF_SHADOW_CREATE_AT, true);
                        Position posTwo = me->GetNearPosition(8.0f, randAngle - step * float(i));
                        me->CastSpell(posTwo.GetPositionX(), posTwo.GetPositionY(), posTwo.GetPositionZ(),
                            SPELL_FRAGHMENTS_OF_SHADOW_CREATE_AT, true);
                    }
                });
                break;
            default:
                break;
        }
    }

    void JustSummoned(Creature* summon) override
    {
        summons.Summon(summon);
        switch (summon->GetEntry())
        {
            case NPC_SINS_OF_THE_PAST:
                summon->AI()->DoZoneInCombat();
                summon->AddAura(SPELL_ANIMA_WEB, summon);
                // If the webs still stand after 45s, the raid is punished with Indemnification.
                // (Source ran this on the summon's per-unit scheduler and re-resolved the boss
                // through FindNearestCreature; rerouted through the AI scheduler on `me`.)
                scheduler.Schedule(45s, [this](TaskContext /*context*/)
                {
                    ForEachPlayerInRoom([this](Player* player)
                    {
                        if (!player->HasAura(SPELL_INDEMNIFICATION_PERIODIC))
                            me->AddAura(SPELL_INDEMNIFICATION_PERIODIC, player);
                    });
                });
                break;
            default:
                break;
        }
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        me->RemoveAllDynObjects();
        summons.DespawnAll();
        RemoveEncounterAuras();
        // Source used _DespawnAtEvade(); AC 3.3.5 BossAI resets in place instead.
        BossAI::EnterEvadeMode(why);
    }

    void JustDied(Unit* /*killer*/) override
    {
        me->RemoveAllDynObjects();
        RemoveEncounterAuras();
        _JustDied();
    }

private:
    void RemoveEncounterAuras()
    {
        instance->DoRemoveAurasDueToSpellOnPlayers(SPELL_INDEMNIFICATION_PERIODIC);
        instance->DoRemoveAurasDueToSpellOnPlayers(SPELL_CONCETRATED_ANIMA_PERIODIC);
        instance->DoRemoveAurasDueToSpellOnPlayers(SPELL_LINGERING_ANIMA_AT_DAMAGE);
    }

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
};

// 340452 - Change of Heart
// Detonates on the victim's position when the trigger aura fades.
class aura_change_of_heart : public AuraScript
{
    PrepareAuraScript(aura_change_of_heart);

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Unit* caster = GetCaster();
        Unit* target = GetTarget();
        // NOTE: the source's guard was inverted (it bailed out whenever caster or target
        // was valid, so the handler never ran); fixed to a plain null check.
        if (!caster || !target)
            return;

        caster->CastSpell(target->GetPositionX(), target->GetPositionY(), target->GetPositionZ(),
            SPELL_CHANGE_OF_HEART_DAMAGE, true);
    }

    void Register() override
    {
        // NOTE: effect/aura type must match the authored spell_dbc downport (source hooked EFFECT_0 dummy).
        OnEffectRemove += AuraEffectRemoveFn(aura_change_of_heart::OnRemove, EFFECT_0, SPELL_AURA_DUMMY,
            AURA_EFFECT_HANDLE_REAL);
    }
};

// 332664 - Concentrated Anima
// Leaves a Harnessed Specter behind when the periodic damage fades.
class aura_concentrated_anima : public AuraScript
{
    PrepareAuraScript(aura_concentrated_anima);

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Unit* target = GetTarget();
        // NOTE: the source's guard was inverted (it bailed out whenever the target was valid,
        // then dereferenced the null it let through); fixed to a plain null check.
        if (!target)
            return;

        target->SummonCreature(NPC_HARNESSED_SPECTER, target->GetPosition(), TEMPSUMMON_MANUAL_DESPAWN);
    }

    void Register() override
    {
        // NOTE: effect/aura type must match the authored spell_dbc downport (source hooked EFFECT_0 periodic).
        OnEffectRemove += AuraEffectRemoveFn(aura_concentrated_anima::OnRemove, EFFECT_0,
            SPELL_AURA_PERIODIC_DAMAGE, AURA_EFFECT_HANDLE_REAL);
    }
};
}

void AddSC_boss_lady_inerva_darkvein()
{
    using namespace CastleNathria;
    using namespace CastleNathria::LadyInervaDarkvein;
    RegisterCastleNathriaCreatureAI(boss_lady_inerva_darkvein);
    RegisterSpellScript(aura_change_of_heart);
    RegisterSpellScript(aura_concentrated_anima);
    // TODO(port): shadowcore's AreaTriggerAI scripts (at_bottled_anima, at_lingering_anima,
    // at_fragments_of_shadow) have no 3.3.5 equivalent. Author the *_CREATE_AT spell_dbc
    // downports as persistent-area-aura spells triggering their damage spells
    // (SPELL_LINGERING_ANIMA_AT_DAMAGE, SPELL_FRAGMENTS_OF_SHADOW_DAMAGE) and fold
    // at_bottled_anima's impact missile (SPELL_BOTTLED_ANIMA_MISSILE) into the creator spell
    // to restore the ground hazards.
}
