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

// Timbermaw Hold -- the seven encounters.
//
// Every spell id here was verified present in the live server Spell.dbc before use; nothing is
// invented and nothing needed downporting. The Nightmare vocabulary is all stock 3.3.5:
// Creature of Nightmare is the classic Emerald Dragon fear, and "Immersed in the Emerald
// Nightmare" ships with its own right-click-to-pinch-yourself escape, which is what lets
// Ursol's dream phase exist without any bespoke spell work.
//
// BossAI does the bookkeeping AND the update loop: its UpdateAI already runs UpdateVictim,
// events.Update, the ExecuteEvent dispatch and the melee swing, re-checking casting state
// between events. So each encounter below only supplies its schedule and its ExecuteEvent.
// _JustEngagedWith / _JustDied set the encounter IN_PROGRESS / DONE, which is why the instance
// script needs no death hook.

#include "CreatureScript.h"
#include "ScriptedCreature.h"
#include "timbermaw_hold.h"

enum TMBHSpells
{
    SPELL_MORTAL_STRIKE      = 32736,
    SPELL_CLEAVE             = 15496,
    SPELL_THUNDERCLAP        = 23931,

    SPELL_WAR_STOMP          = 46026,
    SPELL_WHIRLWIND          = 33238,
    SPELL_ENRAGE             = 8599,

    SPELL_MAUL               = 26996,
    SPELL_REND               = 13738,
    SPELL_CHARGE             = 22120,
    SPELL_BLOOD_OF_OLD_GOD   = 52560,

    SPELL_SHADOW_BOLT_VOLLEY = 27383,
    SPELL_CURSE_OF_TONGUES   = 12889,
    SPELL_FEAR               = 26070,

    SPELL_ENTANGLING_ROOTS   = 33844,
    SPELL_THORNS             = 25777,

    SPELL_CREATURE_NIGHTMARE = 25806,
    SPELL_IMMERSED_NIGHTMARE = 57413,
    SPELL_NIGHTMARE_CLOUD    = 71939
};

enum TMBHEvents
{
    EVENT_ABILITY_1 = 1,
    EVENT_ABILITY_2,
    EVENT_ABILITY_3
};

enum TMBHSays
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
// own enrage must therefore forward to TimbermawBossAI::DamageTaken, or it hides this and silently
// loses its half-health line.
//
// Every `Sound` in creature_text is 0 -- the source packs' voice-over sound ids are NOT in our
// SoundEntries.dbc (verified, all missing), so referencing them would only spam the boot log.
struct TimbermawBossAI : public BossAI
{
    TimbermawBossAI(Creature* creature, uint32 bossId) : BossAI(creature, bossId) { }

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

// ---------------------------------------------------------------- 1. Gatewarden Mor'thak
struct boss_gatewarden_morthak : public TimbermawBossAI
{
    boss_gatewarden_morthak(Creature* creature) : TimbermawBossAI(creature, DATA_GATEWARDEN) { }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 8s);
        events.ScheduleEvent(EVENT_ABILITY_2, 12s);
        events.ScheduleEvent(EVENT_ABILITY_3, 18s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastVictim(SPELL_MORTAL_STRIKE);
                events.ScheduleEvent(EVENT_ABILITY_1, 14s);
                break;
            case EVENT_ABILITY_2:
                DoCastVictim(SPELL_CLEAVE);
                events.ScheduleEvent(EVENT_ABILITY_2, 10s);
                break;
            case EVENT_ABILITY_3:
                DoCastAOE(SPELL_THUNDERCLAP);
                events.ScheduleEvent(EVENT_ABILITY_3, 20s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- 2. The Sundered Chieftain
struct boss_sundered_chieftain : public TimbermawBossAI
{
    boss_sundered_chieftain(Creature* creature) : TimbermawBossAI(creature, DATA_CHIEFTAIN) { }

    void Reset() override
    {
        TimbermawBossAI::Reset();
        _enraged = false;
    }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 10s);
        events.ScheduleEvent(EVENT_ABILITY_2, 16s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastAOE(SPELL_WAR_STOMP);
                events.ScheduleEvent(EVENT_ABILITY_1, 18s);
                break;
            case EVENT_ABILITY_2:
                DoCastAOE(SPELL_WHIRLWIND);
                events.ScheduleEvent(EVENT_ABILITY_2, 22s);
                break;
            default:
                break;
        }
    }

    // The village falling is the story beat, so he goes out swinging.
    void DamageTaken(Unit* attacker, uint32& damage, DamageEffectType damageType, SpellSchoolMask schoolMask) override
    {
        TimbermawBossAI::DamageTaken(attacker, damage, damageType, schoolMask);

        if (!_enraged && me->HealthBelowPct(30))
        {
            _enraged = true;
            DoCastSelf(SPELL_ENRAGE, true);
        }
    }

private:
    bool _enraged = false;
};

// ---------------------------------------------------------------- 3. Den Mother Ursara
struct boss_den_mother_ursara : public TimbermawBossAI
{
    boss_den_mother_ursara(Creature* creature) : TimbermawBossAI(creature, DATA_DEN_MOTHER) { }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 7s);
        events.ScheduleEvent(EVENT_ABILITY_2, 11s);
        events.ScheduleEvent(EVENT_ABILITY_3, 20s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastVictim(SPELL_MAUL);
                events.ScheduleEvent(EVENT_ABILITY_1, 12s);
                break;
            case EVENT_ABILITY_2:
                DoCastVictim(SPELL_REND);
                events.ScheduleEvent(EVENT_ABILITY_2, 15s);
                break;
            case EVENT_ABILITY_3:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 30.0f, true))
                    DoCast(target, SPELL_CHARGE);
                events.ScheduleEvent(EVENT_ABILITY_3, 21s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- 4. Xanthir the Defiler
struct boss_xanthir_the_defiler : public TimbermawBossAI
{
    boss_xanthir_the_defiler(Creature* creature) : TimbermawBossAI(creature, DATA_XANTHIR) { }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 6s);
        events.ScheduleEvent(EVENT_ABILITY_2, 14s);
        events.ScheduleEvent(EVENT_ABILITY_3, 25s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastAOE(SPELL_SHADOW_BOLT_VOLLEY);
                events.ScheduleEvent(EVENT_ABILITY_1, 12s);
                break;
            case EVENT_ABILITY_2:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 40.0f, true))
                    DoCast(target, SPELL_CURSE_OF_TONGUES);
                events.ScheduleEvent(EVENT_ABILITY_2, 20s);
                break;
            case EVENT_ABILITY_3:
                DoCastAOE(SPELL_FEAR);
                events.ScheduleEvent(EVENT_ABILITY_3, 28s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- 5. The Nightmare Given Root
struct boss_nightmare_given_root : public TimbermawBossAI
{
    boss_nightmare_given_root(Creature* creature) : TimbermawBossAI(creature, DATA_NIGHTMARE_ROOT) { }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 5s);
        events.ScheduleEvent(EVENT_ABILITY_2, 15s);
        events.ScheduleEvent(EVENT_ABILITY_3, 22s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 35.0f, true))
                    DoCast(target, SPELL_ENTANGLING_ROOTS);
                events.ScheduleEvent(EVENT_ABILITY_1, 13s);
                break;
            case EVENT_ABILITY_2:
                DoCastSelf(SPELL_THORNS);
                events.ScheduleEvent(EVENT_ABILITY_2, 30s);
                break;
            case EVENT_ABILITY_3:
                DoCastAOE(SPELL_NIGHTMARE_CLOUD);
                events.ScheduleEvent(EVENT_ABILITY_3, 24s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- 6. Ursol, the dreaming twin
struct boss_ursol : public TimbermawBossAI
{
    boss_ursol(Creature* creature) : TimbermawBossAI(creature, DATA_URSOL) { }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 12s);
        events.ScheduleEvent(EVENT_ABILITY_2, 20s);
        events.ScheduleEvent(EVENT_ABILITY_3, 30s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastAOE(SPELL_CREATURE_NIGHTMARE);
                events.ScheduleEvent(EVENT_ABILITY_1, 25s);
                break;
            case EVENT_ABILITY_2:
                DoCastAOE(SPELL_NIGHTMARE_CLOUD);
                events.ScheduleEvent(EVENT_ABILITY_2, 18s);
                break;
            case EVENT_ABILITY_3:
                // Carries its own escape, so the dream phase is survivable as shipped.
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 40.0f, true))
                    DoCast(target, SPELL_IMMERSED_NIGHTMARE);
                events.ScheduleEvent(EVENT_ABILITY_3, 32s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- 7. Ursoc, the raging twin
struct boss_ursoc : public TimbermawBossAI
{
    boss_ursoc(Creature* creature) : TimbermawBossAI(creature, DATA_URSOC) { }

    void Reset() override
    {
        TimbermawBossAI::Reset();
        _bloodCalled = false;
    }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 6s);
        events.ScheduleEvent(EVENT_ABILITY_2, 14s);
        events.ScheduleEvent(EVENT_ABILITY_3, 24s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastVictim(SPELL_MAUL);
                events.ScheduleEvent(EVENT_ABILITY_1, 9s);
                break;
            case EVENT_ABILITY_2:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 30.0f, true))
                    DoCast(target, SPELL_CHARGE);
                events.ScheduleEvent(EVENT_ABILITY_2, 18s);
                break;
            case EVENT_ABILITY_3:
                DoCastSelf(SPELL_ENRAGE, true);
                events.ScheduleEvent(EVENT_ABILITY_3, 40s);
                break;
            default:
                break;
        }
    }

    // Below 25% the corruption shows its source. The spell's own tooltip is
    // "Summons the Blood of the Old God to Ursoc's Aid", which is exactly the beat.
    void DamageTaken(Unit* attacker, uint32& damage, DamageEffectType damageType, SpellSchoolMask schoolMask) override
    {
        TimbermawBossAI::DamageTaken(attacker, damage, damageType, schoolMask);

        if (!_bloodCalled && me->HealthBelowPct(25))
        {
            _bloodCalled = true;
            DoCastSelf(SPELL_BLOOD_OF_OLD_GOD, true);
        }
    }

private:
    bool _bloodCalled = false;
};

void AddSC_boss_timbermaw_hold()
{
    RegisterTimbermawHoldCreatureAI(boss_gatewarden_morthak);
    RegisterTimbermawHoldCreatureAI(boss_sundered_chieftain);
    RegisterTimbermawHoldCreatureAI(boss_den_mother_ursara);
    RegisterTimbermawHoldCreatureAI(boss_xanthir_the_defiler);
    RegisterTimbermawHoldCreatureAI(boss_nightmare_given_root);
    RegisterTimbermawHoldCreatureAI(boss_ursol);
    RegisterTimbermawHoldCreatureAI(boss_ursoc);
}
