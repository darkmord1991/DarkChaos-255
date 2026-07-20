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

// DarkChaos downport of Sun King's Salvation, fourth encounter of Castle Nathria (map 2296).
// Protect-the-boss event: High Torturer Darithos knocks Kael'thas down to 20% health on pull;
// the raid must heal the Sun King back to full while killing the summoned waves and the
// Shades of Kael'thas. Ported from ShadowCore (TrinityCore 9.x) to AzerothCore 3.3.5a idioms --
// see DC/BlackwingDescent/PORT_NOTES.md for the API divergence log this port follows.
//
// 3.3.5 substitutions:
// - Spawned AreaTriggers do not exist: at_smoldering_remnants was cut; author the
//   *_CREATE_AT spell_dbc downports as persistent-area-aura ground effects instead.
// - aura_smoldering_plumage drove the phoenix ground-fire through the phoenix's per-unit
//   scheduler (no such thing on 3.3.5); rerouted through the shade's AI scheduler.
// - Mythic difficulty does not exist: the Cloak of Flames / Unleashed Pyroclasm shield phase
//   and the mythic seed count were cut; heroic branches use IsHeroic().
// - The source AI never completed the encounter; the win condition (Kael'thas healed back to
//   full while the event runs) is implemented here so the encounter can be finished.
//
// NOTE: no creature_text in DB yet for 165759/168973/165805 (the source had no Talk() calls).

#include "InstanceScript.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellScript.h"
#include "castle_nathria.h"

namespace CastleNathria::SunKingsSalvation
{
enum Spells
{
    SPELL_GREATER_CASTIGNATION_CAST         = 328885,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_GREATER_CASTIGNATION_PERI_DUMMY   = 328889,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_GREATER_CASTIGNATION_CHANNEL      = 328894,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_GREATER_CASTIGNATION_DAMAGE       = 328890,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_FIERY_STRIKE                      = 326455,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_BURNING_REMNANTS                  = 326456,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_BLAZING_SURGE                     = 329518,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_BLAZING_SURGE_MISSILE             = 329515,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_SMOLDERING_REMNANTS_AT_DAMAGE     = 328579,   // TODO(spell_dbc): SL spell, needs downport row (was at_smoldering_remnants)
    SPELL_SMOLDERING_REMNANTS_CREATE_AT_ONE = 328658,   // TODO(spell_dbc): SL spell, needs downport row (author as persistent-area-aura)
    SPELL_SMOLDERING_REMNANTS_CREATE_AT_TWO = 328578,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_SMOLDERING_REMNANTS_CREATE_AT_THREE = 328600, // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_SMOLDERING_PLUMAGE_PERIODIC_TRIGER = 328659,  // TODO(spell_dbc): SL spell, needs downport row
    SPELL_SMOLDERING_PLUMAGE_DAMAGE         = 340499,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_EMBER_BLAST_CAST                  = 325877,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_LINGERING_EMBERS_PERIODIC         = 326430,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_SOUL_INFUSION                     = 325665,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_DRAINED_SOUL_DEBUFF               = 339251,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_SUMMON_ESSENCE_FONT               = 329565,   // TODO(spell_dbc): SL spell, needs downport row

    // Heroic
    SPELL_FRAGMENTATION                     = 336398,   // TODO(spell_dbc): SL spell, needs downport row

    // Mythic -- unreferenced after the Cloak of Flames cut, kept for downport reference
    SPELL_CLOAK_OF_FLAMES_ABSORB            = 343026,
    SPELL_UNLEASHED_PYROCLASM               = 343025,
    SPELL_CRACKED_RESERVOIR                 = 329539,
    SPELL_ESSENCE_OVERFLOW                  = 329561,
    SPELL_PHOENIX_FLGIHT                    = 342474,   // source typo preserved
    SPELL_REFLECTION_OF_GUILT               = 323402
};

enum Events
{
    EVENT_GAIN_ENERGY = 1,
    EVENT_GREATER_CASTIGNATION_CAST = 2,  // was raw SPELL_GREATER_CASTIGNATION_CAST
    EVENT_FIERY_STRIKE = 3,  // was raw SPELL_FIERY_STRIKE
    EVENT_EMBER_BLAST_CAST = 4  // was raw SPELL_EMBER_BLAST_CAST
};

enum Actions
{
    ACTION_SPAWN_ADDS       = 1,
    ACTION_RESET_ENCOUNTER  = 2
};

Position const VanquisherSpawnPos   = { -2212.901f, 6384.651f, 4367.636f, 0.0f };
Position const AssassinSpawnPos    = { -2258.140f, 6344.804f, 4367.202f, 1.806f };
Position const AssassinSpawnPos2   = { -2256.673f, 6424.470f, 4367.202f, 4.708f };
Position const FiendSpawnCenter    = { -2247.565f, 6384.229f, 4367.202f, 3.172f };
Position const InfuserSpawnCenter  = { -2207.122f, 6436.489f, 4367.776f, 3.803f };
Position const InfuserSpawnCenter2 = { -2203.518f, 6328.727f, 4367.776f, 2.177f };
Position const ShadeSpawnPos       = { -2251.194f, 6384.164f, 4367.203f, 0.0f };

// 165759 - Kael'thas Sunstrider (Sun King's Salvation)
struct boss_sun_kings_salvation : public BossAI
{
    boss_sun_kings_salvation(Creature* creature) : BossAI(creature, DATA_SUN_KINGS_SALVATION),
        _eventActive(false), _shadeOfKaelthas45(false), _shadeOfKaelthas90(false), _updateTimer(0) { }

    void Reset() override
    {
        _Reset();
        me->setPowerType(POWER_ENERGY);
        me->SetMaxPower(POWER_ENERGY, 100);
        me->SetPower(POWER_ENERGY, 0);
        me->SetReactState(REACT_PASSIVE);
        me->SetFaction(16);
        me->SetUnitFlag(UNIT_FLAG_NON_ATTACKABLE);
        me->SetRegeneratingHealth(false);
        _eventActive = false;
        _shadeOfKaelthas45 = false;
        _shadeOfKaelthas90 = false;
        _updateTimer = 0;
        me->SetFullHealth();

        if (Creature* darithos = me->FindNearestCreature(NPC_HIGH_TORTURER_DARITHOS, 100.0f, false))
        {
            Position const& home = darithos->GetHomePosition();
            darithos->NearTeleportTo(home.GetPositionX(), home.GetPositionY(), home.GetPositionZ(), home.GetOrientation());
            darithos->Respawn(true);
        }
    }

    void DoAction(int32 action) override
    {
        switch (action)
        {
            case ACTION_SPAWN_ADDS:
                if (!_eventActive)
                {
                    _eventActive = true;
                    // Kael'thas never "engages" (friendly, passive) so BossAI::_JustEngagedWith
                    // never runs -- flag the encounter in progress by hand.
                    instance->SetBossState(DATA_SUN_KINGS_SALVATION, IN_PROGRESS);
                }
                scheduler.Schedule(1s, [this](TaskContext context)
                {
                    // NOTE: the source stopped the waves for good once a shade was up; here the
                    // wave merely skips while a shade lives and resumes afterwards.
                    if (!me->FindNearestCreature(NPC_SHADE_OF_KAELTHAS, 100.0f, true))
                        SpawnAddWave();
                    if (_eventActive)
                        context.Repeat(60s);
                });
                break;
            case ACTION_RESET_ENCOUNTER:
                _eventActive = false;
                scheduler.CancelAll();
                summons.DespawnAll();
                DespawnPhoenixes();
                // NOTE: the source also replaced all unit flags with UNIT_FLAG_PVP_ATTACKABLE
                // right after re-adding NON_ATTACKABLE (contradictory); the replace was dropped.
                me->SetUnitFlag(UnitFlags(UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE));
                me->SetFaction(16);
                me->SetFullHealth();
                break;
            default:
                break;
        }
    }

    void SpawnAddWave()
    {
        me->SummonCreature(NPC_ROCKBOUND_VANQUISHER, VanquisherSpawnPos, TEMPSUMMON_MANUAL_DESPAWN);
        for (uint8 i = 0; i < 2; ++i)
            me->SummonCreature(NPC_BLEAKWING_ASSASIN, AssassinSpawnPos, TEMPSUMMON_MANUAL_DESPAWN);
        for (uint8 i = 0; i < 2; ++i)
            me->SummonCreature(NPC_BLEAKWING_ASSASIN, AssassinSpawnPos2, TEMPSUMMON_MANUAL_DESPAWN);
        uint8 const occultists = urand(3, 5);
        for (uint8 i = 0; i < occultists; ++i)
            me->SummonCreature(NPC_VILE_OCCULTIST, VanquisherSpawnPos, TEMPSUMMON_MANUAL_DESPAWN);
        for (uint8 i = 0; i < 8; ++i)
            me->SummonCreature(NPC_PESTERING_FIEND, me->GetRandomPoint(FiendSpawnCenter, 15.0f), TEMPSUMMON_MANUAL_DESPAWN);
        uint8 const infusers = urand(1, 3);
        for (uint8 i = 0; i < infusers; ++i)
            me->SummonCreature(NPC_SOUL_INFUSER, me->GetRandomPoint(InfuserSpawnCenter, 15.0f), TEMPSUMMON_MANUAL_DESPAWN);
        uint8 const infusers2 = urand(1, 3);
        for (uint8 i = 0; i < infusers2; ++i)
            me->SummonCreature(NPC_SOUL_INFUSER, me->GetRandomPoint(InfuserSpawnCenter2, 15.0f), TEMPSUMMON_MANUAL_DESPAWN);
    }

    void JustSummoned(Creature* summon) override
    {
        summons.Summon(summon);
        summon->AI()->DoZoneInCombat();
    }

    void SummonedCreatureDies(Creature* summon, Unit* /*killer*/) override
    {
        switch (summon->GetEntry())
        {
            case NPC_VILE_OCCULTIST:
                summon->CastSpell(summon, SPELL_SUMMON_ESSENCE_FONT, TRIGGERED_FULL_MASK);
                break;
            case NPC_PESTERING_FIEND:
                if (IsHeroic()) // source: heroic + mythic; no mythic on 3.3.5
                    summon->CastSpell(nullptr, SPELL_FRAGMENTATION, TRIGGERED_FULL_MASK);
                break;
            default:
                break;
        }
    }

    void UpdateAI(uint32 diff) override
    {
        // Kael'thas never acquires a victim (friendly and passive), so BossAI::UpdateAI would
        // early-out on UpdateVictim(); the event runs on a raw 1s poll like the source.
        scheduler.Update(diff);

        if (_updateTimer > diff)
        {
            _updateTimer -= diff;
            return;
        }
        _updateTimer = 1000;

        if (!_eventActive)
            return;

        if (!me->GetMap()->HavePlayers())
        {
            EnterEvadeMode(EVADE_REASON_NO_HOSTILES);
            return;
        }

        // NOTE: the source compared GetHealthPct() == 45 / == 90 (float equality that would
        // almost never fire); ported as crossing thresholds while being healed up from 20%.
        if (!_shadeOfKaelthas45 && me->GetHealthPct() >= 45.0f)
        {
            _shadeOfKaelthas45 = true;
            me->SummonCreature(NPC_SHADE_OF_KAELTHAS, ShadeSpawnPos, TEMPSUMMON_MANUAL_DESPAWN);
        }

        if (!_shadeOfKaelthas90 && me->GetHealthPct() >= 90.0f)
        {
            _shadeOfKaelthas90 = true;
            me->SummonCreature(NPC_SHADE_OF_KAELTHAS, ShadeSpawnPos, TEMPSUMMON_MANUAL_DESPAWN);
        }

        // TODO(port): mythic-only Cloak of Flames / Unleashed Pyroclasm shield phase cut --
        // no mythic difficulty on 3.3.5.

        // Win condition: the Sun King healed back to full (absent from the source AI).
        if (me->IsFullHealth())
            FinishEvent();
    }

    // The Reborn Phoenixes are summoned by the SHADE, not this boss, so they are not in this
    // AI's SummonList and summons.DespawnAll() misses them -- sweep them explicitly on every
    // encounter-teardown path (found by the 2026-07-20 port audit: they leaked permanently on
    // wipe/win/Kael-death; the shade only cleans them up in its own JustDied).
    void DespawnPhoenixes()
    {
        std::list<Creature*> phoenixList;
        GetCreatureListWithEntryInGrid(phoenixList, me, NPC_REBORN_PHOENIX, 200.0f);
        for (Creature* phoenix : phoenixList)
            phoenix->DespawnOrUnsummon();
    }

    void FinishEvent()
    {
        _eventActive = false;
        scheduler.CancelAll();
        instance->SendEncounterUnit(ENCOUNTER_FRAME_DISENGAGE, me);
        instance->SetBossState(DATA_SUN_KINGS_SALVATION, DONE);
        summons.DespawnAll();
        DespawnPhoenixes();
        me->SetUnitFlag(UnitFlags(UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE));
        me->SetFaction(35);
        // Loot comes from the statically spawned Cache of the Sun King chest (GO 357752, loot
        // table populated). The source never gated or spawned it.
        // TODO(port): gate chest visibility until encounter done.
    }

    void JustDied(Unit* /*killer*/) override
    {
        // Kael'thas dying means the raid failed to protect him -- never award the kill.
        _eventActive = false;
        scheduler.CancelAll();
        instance->SendEncounterUnit(ENCOUNTER_FRAME_DISENGAGE, me);
        instance->SetBossState(DATA_SUN_KINGS_SALVATION, FAIL);
        summons.DespawnAll();
        DespawnPhoenixes();
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        DoAction(ACTION_RESET_ENCOUNTER);
        // Source used _DespawnAtEvade(); AC 3.3.5 BossAI resets in place instead.
        BossAI::EnterEvadeMode(why);
    }

private:
    bool _eventActive;
    bool _shadeOfKaelthas45;
    bool _shadeOfKaelthas90;
    uint32 _updateTimer;
};

// 168973 - High Torturer Darithos
struct npc_high_torturer_darithos : public ScriptedAI
{
    npc_high_torturer_darithos(Creature* creature) : ScriptedAI(creature),
        _instance(creature->GetInstanceScript()) { }

    void JustEngagedWith(Unit* /*who*/) override
    {
        if (Creature* kaelthas = me->FindNearestCreature(NPC_SUN_KING_SALVATION, 100.0f, true))
        {
            if (_instance)
                _instance->SendEncounterUnit(ENCOUNTER_FRAME_ENGAGE, kaelthas);
            kaelthas->RemoveUnitFlag(UnitFlags(UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE));
            kaelthas->SetInCombatWithZone();
            // Source dealt 80% max-health fire damage; set the Sun King straight to 20%.
            kaelthas->SetHealth(std::max<uint32>(kaelthas->CountPctFromMaxHealth(20), 1));
            kaelthas->AI()->DoAction(ACTION_SPAWN_ADDS);
            kaelthas->SetFaction(35);
        }

        std::list<Creature*> addsList;
        GetCreatureListWithEntryInGrid(addsList, me, NPC_VILE_OCCULTIST, 150.0f);
        for (Creature* occultist : addsList)
            occultist->AI()->DoZoneInCombat();

        // NOTE: the source scheduled its signature cast once and never repeated it
        // (its OnSpellFinished handler was empty); kept as-is.
        events.ScheduleEvent(EVENT_GREATER_CASTIGNATION_CAST, 6s);
    }

    void JustReachedHome() override
    {
        if (Creature* kaelthas = me->FindNearestCreature(NPC_SUN_KING_SALVATION, 100.0f, true))
            kaelthas->AI()->EnterEvadeMode(EVADE_REASON_NO_HOSTILES);
    }

    void UpdateAI(uint32 diff) override
    {
        if (!UpdateVictim())
            return;

        events.Update(diff);

        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        while (uint32 const eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_GREATER_CASTIGNATION_CAST:
                    me->CastSpell(nullptr, SPELL_GREATER_CASTIGNATION_CAST);
                    break;
                default:
                    break;
            }
        }

        DoMeleeAttackIfReady();
    }

private:
    InstanceScript* _instance;
};

// 165805 - Shade of Kael'thas
struct npc_shade_of_kaelthas : public ScriptedAI
{
    npc_shade_of_kaelthas(Creature* creature) : ScriptedAI(creature),
        _instance(creature->GetInstanceScript()) { }

    void Reset() override
    {
        events.Reset();
        scheduler.CancelAll();
        me->setPowerType(POWER_ENERGY);
        me->SetMaxPower(POWER_ENERGY, 100);
        me->SetPower(POWER_ENERGY, 0);
        me->SetReactState(REACT_AGGRESSIVE);
        me->SetObjectScale(1.5f);
        for (uint8 i = 0; i < 2; ++i)
            me->SummonCreature(NPC_REBORN_PHOENIX, me->GetRandomNearPosition(30.0f), TEMPSUMMON_MANUAL_DESPAWN);
    }

    void JustSummoned(Creature* summon) override
    {
        switch (summon->GetEntry())
        {
            case NPC_REBORN_PHOENIX:
            {
                summon->AddAura(SPELL_SMOLDERING_PLUMAGE_PERIODIC_TRIGER, summon);
                summon->SetWalk(true);
                summon->AI()->DoZoneInCombat();
                // TODO(port): aura_smoldering_plumage ran this loop on the phoenix's per-unit
                // scheduler (none on 3.3.5): while the plumage aura holds, drop a Smoldering
                // Remnants ground effect every 2.5s. Rerouted through the AI scheduler.
                ObjectGuid phoenixGuid = summon->GetGUID();
                scheduler.Schedule(100ms, [this, phoenixGuid](TaskContext context)
                {
                    Creature* phoenix = ObjectAccessor::GetCreature(*me, phoenixGuid);
                    if (!phoenix || !phoenix->IsAlive() || !phoenix->HasAura(SPELL_SMOLDERING_PLUMAGE_PERIODIC_TRIGER))
                        return;

                    phoenix->CastSpell(nullptr, SPELL_SMOLDERING_REMNANTS_CREATE_AT_ONE, TRIGGERED_FULL_MASK);
                    context.Repeat(2500ms);
                });
                break;
            }
            default:
                break;
        }
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        if (_instance)
            _instance->SendEncounterUnit(ENCOUNTER_FRAME_ENGAGE, me);

        events.ScheduleEvent(EVENT_GAIN_ENERGY, 1s);
        events.ScheduleEvent(EVENT_FIERY_STRIKE, 3s);
        events.ScheduleEvent(EVENT_EMBER_BLAST_CAST, 10s);
    }

    void UpdateAI(uint32 diff) override
    {
        if (!UpdateVictim())
            return;

        events.Update(diff);
        scheduler.Update(diff);

        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        // Blazing Surge fires the moment the energy bar fills (the source ran this check on
        // every event pop; energy only moves once per second, so once per tick is equivalent).
        if (me->GetPower(POWER_ENERGY) == 100)
        {
            me->SetPower(POWER_ENERGY, 0);
            if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
            {
                me->CastSpell(target, SPELL_BLAZING_SURGE);
                ObjectGuid targetGuid = target->GetGUID();
                scheduler.Schedule(3100ms, [this, targetGuid](TaskContext /*context*/)
                {
                    Unit* target = ObjectAccessor::GetUnit(*me, targetGuid);
                    if (!target)
                        return;

                    for (uint8 i = 0; i < 3; ++i)
                    {
                        Position pos = target->GetRandomNearPosition(float(urand(1, 10)));
                        me->CastSpell(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ(),
                            SPELL_BLAZING_SURGE_MISSILE, true);
                    }
                });
            }
        }

        while (uint32 const eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_GAIN_ENERGY:
                    me->ModifyPower(POWER_ENERGY, 5);
                    events.Repeat(1s);
                    break;
                case EVENT_FIERY_STRIKE:
                    if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                    {
                        me->SetFacingToObject(target);
                        me->CastSpell(target, SPELL_FIERY_STRIKE);
                    }
                    events.Repeat(15s, 20s);
                    break;
                case EVENT_EMBER_BLAST_CAST:
                    // NOTE: not repeated in the source either.
                    if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                        me->CastSpell(target, SPELL_EMBER_BLAST_CAST);
                    break;
                default:
                    break;
            }

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;
        }

        DoMeleeAttackIfReady();
    }

    void JustDied(Unit* /*killer*/) override
    {
        if (_instance)
            _instance->SendEncounterUnit(ENCOUNTER_FRAME_DISENGAGE, me);

        // Source kept the phoenixes alive on mythic only; no mythic on 3.3.5.
        std::list<Creature*> phoenixList;
        GetCreatureListWithEntryInGrid(phoenixList, me, NPC_REBORN_PHOENIX, 200.0f);
        for (Creature* phoenix : phoenixList)
            phoenix->DespawnOrUnsummon();
    }

private:
    InstanceScript* _instance;
};

// 340499 - Smoldering Plumage
class spell_smoldering_plumage : public SpellScript
{
    PrepareSpellScript(spell_smoldering_plumage);

    void FilterTargets(std::list<WorldObject*>& targets)
    {
        targets.remove(GetCaster());
    }

    void Register() override
    {
        // NOTE: effect/target must match the authored spell_dbc downport (source hooked EFFECT_0).
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(spell_smoldering_plumage::FilterTargets,
            EFFECT_0, TARGET_UNIT_SRC_AREA_ENTRY);
    }
};
}

void AddSC_boss_sun_kings_salvation()
{
    using namespace CastleNathria;
    using namespace CastleNathria::SunKingsSalvation;
    RegisterCastleNathriaCreatureAI(boss_sun_kings_salvation);
    RegisterCastleNathriaCreatureAI(npc_high_torturer_darithos);
    RegisterCastleNathriaCreatureAI(npc_shade_of_kaelthas);
    RegisterSpellScript(spell_smoldering_plumage);
    // TODO(port): shadowcore's at_smoldering_remnants AreaTriggerAI has no 3.3.5 equivalent.
    // Author SPELL_SMOLDERING_REMNANTS_CREATE_AT_ONE's spell_dbc downport as a persistent-area
    // aura triggering SPELL_SMOLDERING_REMNANTS_AT_DAMAGE to restore the ground hazard.
}
