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

// DarkChaos downport of the Hungering Destroyer, third boss of Castle Nathria (Shadowlands raid, map 2296).
// Ported from ShadowCore (TrinityCore 9.x) to AzerothCore 3.3.5a idioms -- see
// DC/BlackwingDescent/PORT_NOTES.md for the API divergence log this port follows.
//
// 3.3.5 substitutions:
// - Spawned AreaTriggers do not exist. at_obliterating_rift (heroic rift left behind by an expired
//   Expunge) was cut; author SPELL_OBLITERATING_RIFT_CREATE_AT's spell_dbc downport as a
//   persistent-area-aura (DynObj) ground effect triggering SPELL_OBLITERATING_RIFT_DAMAGE.
// - Mythic difficulty does not exist: heroic/mythic forks collapse to IsHeroic();
//   mythic-only Essence Sap follows the source and fires on heroic.
// - The aura scripts hooked SL-only aura types (SPELL_AURA_AREA_TRIGGER); they hook
//   SPELL_AURA_ANY here so the authored spell_dbc downports are free to pick 3.3.5 aura types.

#include "InstanceScript.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellAuraEffects.h"
#include "SpellAuras.h"
#include "SpellScript.h"
#include "castle_nathria.h"

namespace CastleNathria::HungeringDestroyer
{
enum Spells
{
    SPELL_GROWING_HUNGER_BUFF               = 332295,   // unused in source too
    SPELL_OVERWHELM                         = 329774,
    SPELL_GLUTTONOUS_MIASMA                 = 329298,   // every 24s
    SPELL_GLUTTONOUS_MIASMA_DAMAGE          = 330590,
    SPELL_GLUTTONOUS_MIASMA_HEAL            = 329314,
    SPELL_DESOLATE                          = 329455,   // 22s on combat, then every minute
    SPELL_VOLATILE_EJECTION_CAST            = 334266,   // every 30s
    SPELL_VOLATILE_EJECTION_DAMAGE_TAKEN_DEBUFF = 334228,   // unused in source too
    SPELL_VOLATILE_EJECTION_MARK            = 334064,   // unused in source too
    SPELL_VOLATILE_EJECTION_EXP_VISUAL      = 334191,   // unused in source too
    SPELL_EXPUNGE_CAST                      = 329758,   // never scheduled by the source AI
    SPELL_EXPUNGE_DAMAGE                    = 329742,   // unused in source too
    SPELL_EXPUNGE_APPLY_AT                  = 329725,   // aura_expunge hooks its removal
    SPELL_CONSUME                           = 334522,

    // Heroic
    SPELL_OBLITERATING_RIFT_CREATE_AT       = 332375,   // author as persistent-area-aura
    SPELL_OBLITERATING_RIFT_DAMAGE          = 329835,   // unused -- was at_obliterating_rift

    // Mythic (source also fired it on heroic; kept that behaviour)
    SPELL_ESSENCE_SAP                       = 334755
    // The remaining events reuse their spell ids, as in the source.
};

enum Events
{
    EVENT_GAIN_ENERGY = 1,
    EVENT_GLUTTONOUS_MIASMA = 2,  // was raw SPELL_GLUTTONOUS_MIASMA
    EVENT_OVERWHELM = 3,  // was raw SPELL_OVERWHELM
    EVENT_VOLATILE_EJECTION_CAST = 4,  // was raw SPELL_VOLATILE_EJECTION_CAST
    EVENT_DESOLATE = 5,  // was raw SPELL_DESOLATE
    EVENT_CONSUME = 6  // was raw SPELL_CONSUME
};

// NOTE: no creature_text in DB yet for 164261 (see Custom/.../worlddb/CastleNathria/09_creature_text.sql);
// the source AI had no Talk() calls either.

// 164261 - Hungering Destroyer
struct boss_hungering_destroyer : public BossAI
{
    boss_hungering_destroyer(Creature* creature) : BossAI(creature, DATA_HUNGERING_DESTROYER) { }

    void Reset() override
    {
        _Reset();
        me->setPowerType(POWER_ENERGY);
        me->SetMaxPower(POWER_ENERGY, 100);
        me->SetPower(POWER_ENERGY, 0);
        me->SetReactState(REACT_AGGRESSIVE);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        _JustEngagedWith();
        events.ScheduleEvent(EVENT_GAIN_ENERGY, 1s);
        events.ScheduleEvent(EVENT_GLUTTONOUS_MIASMA, 3s);
        events.ScheduleEvent(EVENT_OVERWHELM, 5s);
        events.ScheduleEvent(EVENT_VOLATILE_EJECTION_CAST, 10s);
        events.ScheduleEvent(EVENT_DESOLATE, 22s);
        // Source quirk kept: SPELL_CONSUME has no switch case -- the pop only matters as an
        // extra tick of the full-energy check below (Consume is energy-driven).
        events.ScheduleEvent(EVENT_CONSUME, 92s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        // Energy poll runs on every event pop; EVENT_GAIN_ENERGY ticks each second, so this is
        // effectively a once-per-second check, as in the source.
        if (me->GetPower(POWER_ENERGY) == 100)
        {
            me->SetPower(POWER_ENERGY, 0);
            me->CastSpell(me, SPELL_CONSUME);
        }

        switch (eventId)
        {
            case EVENT_GAIN_ENERGY:
                me->ModifyPower(POWER_ENERGY, 1);
                events.Repeat(1s);
                break;
            case EVENT_OVERWHELM:
                DoCastVictim(SPELL_OVERWHELM, false);
                events.Repeat(20s);
                break;
            case EVENT_GLUTTONOUS_MIASMA:
            {
                UnitList targetList;
                SelectTargetList(targetList, 3, SelectTargetMethod::Random, 0, 100.0f, true);
                for (Unit* target : targetList)
                    me->AddAura(SPELL_GLUTTONOUS_MIASMA, target);
                events.Repeat(24s);
                break;
            }
            case EVENT_VOLATILE_EJECTION_CAST:
                me->CastSpell(nullptr, SPELL_VOLATILE_EJECTION_CAST);
                events.Repeat(30s);
                break;
            case EVENT_DESOLATE:
                DoCastAOE(SPELL_DESOLATE, false);
                events.Repeat(60s);
                break;
            default:
                break;
        }
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        summons.DespawnAll();
        me->RemoveAllDynObjects();  // source: RemoveAllAreaTriggers()
        // Source teleported home + _DespawnAtEvade(); AC 3.3.5 BossAI resets in place instead.
        BossAI::EnterEvadeMode(why);
    }

    void JustDied(Unit* /*killer*/) override
    {
        summons.DespawnAll();
        me->RemoveAllDynObjects();  // source: RemoveAllAreaTriggers()
        _JustDied();
    }
};

// 329725 - Expunge
// Heroic: an Obliterating Rift is left behind where the Expunge aura expires.
class aura_expunge : public AuraScript
{
    PrepareAuraScript(aura_expunge);

    void HandleRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        if (GetTarget()->GetMap()->IsHeroic())
            GetTarget()->CastSpell(nullptr, SPELL_OBLITERATING_RIFT_CREATE_AT, TRIGGERED_FULL_MASK);
    }

    void Register() override
    {
        // NOTE: source hooked SPELL_AURA_AREA_TRIGGER (SL-only); SPELL_AURA_ANY leaves the
        // authored spell_dbc downport free to pick any 3.3.5 aura type on EFFECT_0.
        OnEffectRemove += AuraEffectRemoveFn(aura_expunge::HandleRemove, EFFECT_0, SPELL_AURA_ANY, AURA_EFFECT_HANDLE_REAL);
    }
};

// 329298 - Gluttonous Miasma
class aura_gluttonous_miasma : public AuraScript
{
    PrepareAuraScript(aura_gluttonous_miasma);

    void OnTick(AuraEffect const* /*aurEff*/)
    {
        if (GetCaster() && GetTarget())
        {
            GetTarget()->CastSpell(nullptr, SPELL_GLUTTONOUS_MIASMA_DAMAGE, TRIGGERED_FULL_MASK);
            GetTarget()->CastSpell(nullptr, SPELL_GLUTTONOUS_MIASMA_HEAL, TRIGGERED_FULL_MASK);
        }

        // Mythic-only Essence Sap, but the source fired it on heroic as well -- kept.
        if (GetTarget()->GetMap()->IsHeroic())
            GetTarget()->CastSpell(nullptr, SPELL_ESSENCE_SAP, TRIGGERED_FULL_MASK);
    }

    void Register() override
    {
        // NOTE: source hooked a periodic SPELL_AURA_MOD_HEALING_PCT on EFFECT_0; the authored
        // spell_dbc downport must carry a periodic aura on EFFECT_0 for this to tick.
        OnEffectPeriodic += AuraEffectPeriodicFn(aura_gluttonous_miasma::OnTick, EFFECT_0, SPELL_AURA_ANY);
    }
};
}

void AddSC_boss_hungering_destroyer()
{
    using namespace CastleNathria;
    using namespace CastleNathria::HungeringDestroyer;
    RegisterCastleNathriaCreatureAI(boss_hungering_destroyer);
    RegisterSpellScript(aura_expunge);
    RegisterSpellScript(aura_gluttonous_miasma);
    // TODO(port): shadowcore's at_obliterating_rift AreaTriggerAI has no 3.3.5 equivalent.
    // Author the SPELL_OBLITERATING_RIFT_CREATE_AT spell_dbc downport as a persistent-area-aura
    // spell triggering SPELL_OBLITERATING_RIFT_DAMAGE to restore the ground hazard.
}
