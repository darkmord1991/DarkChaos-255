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

// Crescent Grove -- the five encounters, plus the two elders that share the council fight.
// All spell ids verified present in the live server Spell.dbc before use.

#include "CreatureScript.h"
#include "ScriptedCreature.h"
#include "crescent_grove.h"

enum CRGVSpells
{
    SPELL_ENTANGLING_ROOTS   = 33844,
    SPELL_MOONFIRE           = 21669,
    SPELL_THORNS             = 25777,
    SPELL_HEALING_TOUCH      = 25297,

    SPELL_CLEAVE             = 15496,
    SPELL_WAR_STOMP          = 46026,
    SPELL_ENRAGE             = 8599,

    SPELL_SHADOW_BOLT_VOLLEY = 27383,
    SPELL_CURSE_OF_TONGUES   = 12889,
    SPELL_FEAR               = 26070,

    SPELL_RAIN_OF_FIRE       = 34435
};

enum CRGVEvents
{
    EVENT_ABILITY_1 = 1,
    EVENT_ABILITY_2,
    EVENT_ABILITY_3
};

enum CRGVSays
{
    SAY_AGGRO    = 0,
    SAY_HALF_HP,
    SAY_SLAY,
    SAY_DEATH
};

// Every encounter in this instance shares one creature_text layout, so the four universal lines
// are wired once here instead of being repeated in each boss. The GroupID IS the Talk()
// argument, and the rows themselves live in 16_creature_text.sql.
//
// SAY_HALF_HP fires ONCE below 50% health rather than off an ability: an ability-triggered line
// would repeat on every cooldown and become spam. Any boss that overrides DamageTaken for its
// own enrage must therefore forward to CrescentGroveBossAI::DamageTaken, or it hides this and silently
// loses its half-health line.
//
// Every `Sound` in creature_text is 0 -- the source packs' voice-over sound ids are NOT in our
// SoundEntries.dbc (verified, all missing), so referencing them would only spam the boot log.
struct CrescentGroveBossAI : public BossAI
{
    CrescentGroveBossAI(Creature* creature, uint32 bossId) : BossAI(creature, bossId) { }

    void Reset() override
    {
        BossAI::Reset();
        _saidHalfHealth = false;
    }

    void JustEngagedWith(Unit* who) override
    {
        BossAI::JustEngagedWith(who);
        Talk(SAY_AGGRO);
    }

    void KilledUnit(Unit* victim) override
    {
        if (victim->IsPlayer())
            Talk(SAY_SLAY);
    }

    void JustDied(Unit* killer) override
    {
        BossAI::JustDied(killer);
        Talk(SAY_DEATH);
    }

    void DamageTaken(Unit* /*attacker*/, uint32& /*damage*/, DamageEffectType, SpellSchoolMask) override
    {
        if (!_saidHalfHealth && me->HealthBelowPct(50))
        {
            _saidHalfHealth = true;
            Talk(SAY_HALF_HP);
        }
    }

private:
    bool _saidHalfHealth = false;
};

// ---------------------------------------------------------------- Keeper Ranathos
struct boss_keeper_ranathos : public CrescentGroveBossAI
{
    boss_keeper_ranathos(Creature* creature) : CrescentGroveBossAI(creature, DATA_RANATHOS) { }

    void JustEngagedWith(Unit* who) override
    {
        CrescentGroveBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 6s);
        events.ScheduleEvent(EVENT_ABILITY_2, 11s);
        events.ScheduleEvent(EVENT_ABILITY_3, 18s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 35.0f, true))
                    DoCast(target, SPELL_ENTANGLING_ROOTS);
                events.ScheduleEvent(EVENT_ABILITY_1, 14s);
                break;
            case EVENT_ABILITY_2:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 40.0f, true))
                    DoCast(target, SPELL_MOONFIRE);
                events.ScheduleEvent(EVENT_ABILITY_2, 9s);
                break;
            case EVENT_ABILITY_3:
                DoCastSelf(SPELL_THORNS);
                events.ScheduleEvent(EVENT_ABILITY_3, 30s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- Grovetender Engryss
struct boss_grovetender_engryss : public CrescentGroveBossAI
{
    boss_grovetender_engryss(Creature* creature) : CrescentGroveBossAI(creature, DATA_ENGRYSS) { }

    void JustEngagedWith(Unit* who) override
    {
        CrescentGroveBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 8s);
        events.ScheduleEvent(EVENT_ABILITY_2, 15s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastVictim(SPELL_CLEAVE);
                events.ScheduleEvent(EVENT_ABILITY_1, 11s);
                break;
            case EVENT_ABILITY_2:
                DoCastAOE(SPELL_WAR_STOMP);
                events.ScheduleEvent(EVENT_ABILITY_2, 20s);
                break;
            default:
                break;
        }
    }

    // DELIBERATELY NOT CrescentGroveBossAI::JustDied(). The base chains to BossAI::JustDied(),
    // whose _JustDied() would mark the council DONE the instant the Grovetender falls, letting a
    // group skip both elders. The instance script watches all three and sets the state once they
    // are actually down. Summons are still cleaned up here.
    //
    // The death line is spoken directly for the same reason: it belongs to the Grovetender, but
    // it must not drag the encounter-state change along with it.
    void JustDied(Unit* /*killer*/) override
    {
        summons.DespawnAll();
        Talk(SAY_DEATH);
    }
};

// ---------------------------------------------------------------- Elder 'One Eye' / Blackmaw
struct npc_crescent_grove_elder : public ScriptedAI
{
    npc_crescent_grove_elder(Creature* creature) : ScriptedAI(creature) { }

    // `events` is inherited from CreatureAI (CreatureAI.h:73), so there is no need to carry a
    // private EventMap here.
    void Reset() override
    {
        events.Reset();
    }

    // The elders are ScriptedAI, not CrescentGroveBossAI -- they are council adds, not encounters
    // in their own right, so they must not touch encounter state. That means the shared base's
    // Talk() wiring does not reach them and their two lines are hooked up by hand. Both entries
    // (4020003 Elder 'One Eye' and 4020004 Elder Blackmaw) share this AI but have their own
    // creature_text rows, so each speaks in its own voice.
    void JustEngagedWith(Unit* /*who*/) override
    {
        events.ScheduleEvent(EVENT_ABILITY_1, 9s);
        Talk(SAY_AGGRO);
    }

    void KilledUnit(Unit* victim) override
    {
        if (victim->IsPlayer())
            Talk(SAY_SLAY);
    }

    void JustDied(Unit* /*killer*/) override
    {
        Talk(SAY_DEATH);
    }

    void UpdateAI(uint32 diff) override
    {
        if (!UpdateVictim())
            return;

        events.Update(diff);

        if (me->IsActionPreventedByCasting())
            return;

        while (uint32 eventId = events.ExecuteEvent())
        {
            if (eventId == EVENT_ABILITY_1)
            {
                DoCastVictim(SPELL_CLEAVE);
                events.ScheduleEvent(EVENT_ABILITY_1, 13s);
            }
        }

        DoMeleeAttackIfReady();
    }
};

// ---------------------------------------------------------------- High Priestess A'lathea
struct boss_high_priestess_alathea : public CrescentGroveBossAI
{
    boss_high_priestess_alathea(Creature* creature) : CrescentGroveBossAI(creature, DATA_ALATHEA) { }

    void JustEngagedWith(Unit* who) override
    {
        CrescentGroveBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 5s);
        events.ScheduleEvent(EVENT_ABILITY_2, 13s);
        events.ScheduleEvent(EVENT_ABILITY_3, 21s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 40.0f, true))
                    DoCast(target, SPELL_MOONFIRE);
                events.ScheduleEvent(EVENT_ABILITY_1, 8s);
                break;
            case EVENT_ABILITY_2:
                // A heal on the boss is the whole reason this fight wants an interrupt.
                DoCastSelf(SPELL_HEALING_TOUCH);
                events.ScheduleEvent(EVENT_ABILITY_2, 22s);
                break;
            case EVENT_ABILITY_3:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 35.0f, true))
                    DoCast(target, SPELL_ENTANGLING_ROOTS);
                events.ScheduleEvent(EVENT_ABILITY_3, 18s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- Fenektis the Deceiver
struct boss_fenektis_the_deceiver : public CrescentGroveBossAI
{
    boss_fenektis_the_deceiver(Creature* creature) : CrescentGroveBossAI(creature, DATA_FENEKTIS) { }

    void JustEngagedWith(Unit* who) override
    {
        CrescentGroveBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 7s);
        events.ScheduleEvent(EVENT_ABILITY_2, 14s);
        events.ScheduleEvent(EVENT_ABILITY_3, 24s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastAOE(SPELL_SHADOW_BOLT_VOLLEY);
                events.ScheduleEvent(EVENT_ABILITY_1, 13s);
                break;
            case EVENT_ABILITY_2:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 40.0f, true))
                    DoCast(target, SPELL_CURSE_OF_TONGUES);
                events.ScheduleEvent(EVENT_ABILITY_2, 21s);
                break;
            case EVENT_ABILITY_3:
                DoCastAOE(SPELL_FEAR);
                events.ScheduleEvent(EVENT_ABILITY_3, 27s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- Master Raxxieth
struct boss_master_raxxieth : public CrescentGroveBossAI
{
    boss_master_raxxieth(Creature* creature) : CrescentGroveBossAI(creature, DATA_RAXXIETH) { }

    void Reset() override
    {
        CrescentGroveBossAI::Reset();
        _enraged = false;
    }

    void JustEngagedWith(Unit* who) override
    {
        CrescentGroveBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 6s);
        events.ScheduleEvent(EVENT_ABILITY_2, 12s);
        events.ScheduleEvent(EVENT_ABILITY_3, 20s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastVictim(SPELL_CLEAVE);
                events.ScheduleEvent(EVENT_ABILITY_1, 10s);
                break;
            case EVENT_ABILITY_2:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 40.0f, true))
                    DoCast(target, SPELL_RAIN_OF_FIRE);
                events.ScheduleEvent(EVENT_ABILITY_2, 18s);
                break;
            case EVENT_ABILITY_3:
                DoCastAOE(SPELL_FEAR);
                events.ScheduleEvent(EVENT_ABILITY_3, 26s);
                break;
            default:
                break;
        }
    }

    void DamageTaken(Unit* attacker, uint32& damage, DamageEffectType damageType, SpellSchoolMask schoolMask) override
    {
        CrescentGroveBossAI::DamageTaken(attacker, damage, damageType, schoolMask);

        if (!_enraged && me->HealthBelowPct(20))
        {
            _enraged = true;
            DoCastSelf(SPELL_ENRAGE, true);
        }
    }

private:
    bool _enraged = false;
};

void AddSC_boss_crescent_grove()
{
    RegisterCrescentGroveCreatureAI(boss_keeper_ranathos);
    RegisterCrescentGroveCreatureAI(boss_grovetender_engryss);
    RegisterCrescentGroveCreatureAI(boss_high_priestess_alathea);
    RegisterCrescentGroveCreatureAI(boss_fenektis_the_deceiver);
    RegisterCrescentGroveCreatureAI(boss_master_raxxieth);
    RegisterCreatureAI(npc_crescent_grove_elder);
}
