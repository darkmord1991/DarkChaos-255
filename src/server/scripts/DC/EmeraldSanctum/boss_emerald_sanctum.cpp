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

// Emerald Sanctum -- Erennius plus the four rotating Wakeners.
//
// The Wakeners keep the CLASSIC EMERALD DRAGON KITS, which is what made them nearly free:
// Ysondre's Lightning Wave and summoned druid spirits, Lethon's Shadow Bolt Whirl and Draw
// Spirit, Emeriss's Volatile Infection and Corruption of the Earth, Taerar's Arcane Blast.
// Every one of those spells was verified present in the live Spell.dbc.
//
// One substitution: Shades of Taerar (24810) is NOT in this client's Spell.dbc -- it was the
// only id in the whole set that came back missing -- so Taerar uses Sleep (24777) for his
// third ability instead. Everything else is the original kit.
//
// All four share DATA_WAKENER, so whichever the week rolled credits the same encounter.

#include "CreatureScript.h"
#include "ScriptedCreature.h"
#include "emerald_sanctum.h"

enum EMSASpells
{
    // shared dragon kit
    SPELL_NOXIOUS_BREATH     = 24818,
    SPELL_TAIL_SWEEP         = 15847,
    SPELL_MARK_OF_NATURE     = 25040,
    SPELL_SEEPING_FOG        = 24814,
    SPELL_CREATURE_NIGHTMARE = 25806,

    // per-dragon signatures
    SPELL_LIGHTNING_WAVE     = 24819,   // Ysondre
    SPELL_SUMMON_DRUIDS      = 24795,   // Ysondre
    SPELL_SHADOW_BOLT_WHIRL  = 24834,   // Lethon
    SPELL_DRAW_SPIRIT        = 24811,   // Lethon
    SPELL_VOLATILE_INFECTION = 24928,   // Emeriss
    SPELL_CORRUPTION_EARTH   = 24910,   // Emeriss
    SPELL_ARCANE_BLAST       = 24857,   // Taerar
    SPELL_SLEEP              = 24777,   // Taerar -- stands in for the absent Shades of Taerar

    // Erennius
    SPELL_SHADOW_BOLT_VOLLEY = 27383,
    SPELL_CURSE_OF_TONGUES   = 12889,
    SPELL_FEAR               = 26070
};

enum EMSAEvents
{
    EVENT_BREATH = 1,
    EVENT_SWEEP,
    EVENT_MARK,
    EVENT_SIGNATURE_1,
    EVENT_SIGNATURE_2
};

enum EMSASays
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
// own enrage must therefore forward to EmeraldSanctumBossAI::DamageTaken, or it hides this and silently
// loses its half-health line.
//
// Every `Sound` in creature_text is 0 -- the source packs' voice-over sound ids are NOT in our
// SoundEntries.dbc (verified, all missing), so referencing them would only spam the boot log.
struct EmeraldSanctumBossAI : public BossAI
{
    EmeraldSanctumBossAI(Creature* creature, uint32 bossId) : BossAI(creature, bossId) { }

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

// ---------------------------------------------------------------- Erennius (mini-boss)
struct boss_erennius : public EmeraldSanctumBossAI
{
    boss_erennius(Creature* creature) : EmeraldSanctumBossAI(creature, DATA_ERENNIUS) { }

    void JustEngagedWith(Unit* who) override
    {
        EmeraldSanctumBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_SIGNATURE_1, 6s);
        events.ScheduleEvent(EVENT_SIGNATURE_2, 13s);
        events.ScheduleEvent(EVENT_MARK, 22s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_SIGNATURE_1:
                DoCastAOE(SPELL_SHADOW_BOLT_VOLLEY);
                events.ScheduleEvent(EVENT_SIGNATURE_1, 12s);
                break;
            case EVENT_SIGNATURE_2:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 40.0f, true))
                    DoCast(target, SPELL_CURSE_OF_TONGUES);
                events.ScheduleEvent(EVENT_SIGNATURE_2, 20s);
                break;
            case EVENT_MARK:
                DoCastAOE(SPELL_FEAR);
                events.ScheduleEvent(EVENT_MARK, 26s);
                break;
            default:
                break;
        }
    }
};

namespace
{
    /// Shared body of the four Wakeners: the classic dragon kit. Only the two signature
    /// abilities differ, which is exactly the distinction the rotation is meant to deliver.
    struct WakenerAI : public EmeraldSanctumBossAI
    {
        WakenerAI(Creature* creature, uint32 sig1, uint32 sig2, bool sig1OnTarget)
            : EmeraldSanctumBossAI(creature, DATA_WAKENER), _sig1(sig1), _sig2(sig2), _sig1OnTarget(sig1OnTarget) { }

        void JustEngagedWith(Unit* who) override
        {
            EmeraldSanctumBossAI::JustEngagedWith(who);
            events.ScheduleEvent(EVENT_BREATH, 8s);
            events.ScheduleEvent(EVENT_SWEEP, 12s);
            events.ScheduleEvent(EVENT_MARK, 18s);
            events.ScheduleEvent(EVENT_SIGNATURE_1, 15s);
            events.ScheduleEvent(EVENT_SIGNATURE_2, 27s);
        }

        void ExecuteEvent(uint32 eventId) override
        {
            switch (eventId)
            {
                case EVENT_BREATH:
                    DoCastVictim(SPELL_NOXIOUS_BREATH);
                    events.ScheduleEvent(EVENT_BREATH, 16s);
                    break;
                case EVENT_SWEEP:
                    DoCastAOE(SPELL_TAIL_SWEEP);
                    events.ScheduleEvent(EVENT_SWEEP, 14s);
                    break;
                case EVENT_MARK:
                    if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 45.0f, true))
                        DoCast(target, SPELL_MARK_OF_NATURE);
                    events.ScheduleEvent(EVENT_MARK, 24s);
                    break;
                case EVENT_SIGNATURE_1:
                    if (_sig1OnTarget)
                    {
                        if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 45.0f, true))
                            DoCast(target, _sig1);
                    }
                    else
                        DoCastAOE(_sig1);
                    events.ScheduleEvent(EVENT_SIGNATURE_1, 20s);
                    break;
                case EVENT_SIGNATURE_2:
                    DoCastAOE(_sig2);
                    events.ScheduleEvent(EVENT_SIGNATURE_2, 30s);
                    break;
                default:
                    break;
            }
        }

    private:
        uint32 _sig1;
        uint32 _sig2;
        bool _sig1OnTarget;
    };
}

struct boss_wakener_ysondre : public WakenerAI
{
    boss_wakener_ysondre(Creature* creature)
        : WakenerAI(creature, SPELL_LIGHTNING_WAVE, SPELL_SUMMON_DRUIDS, true) { }
};

struct boss_wakener_lethon : public WakenerAI
{
    boss_wakener_lethon(Creature* creature)
        : WakenerAI(creature, SPELL_SHADOW_BOLT_WHIRL, SPELL_DRAW_SPIRIT, false) { }
};

struct boss_wakener_emeriss : public WakenerAI
{
    boss_wakener_emeriss(Creature* creature)
        : WakenerAI(creature, SPELL_VOLATILE_INFECTION, SPELL_CORRUPTION_EARTH, true) { }
};

struct boss_wakener_taerar : public WakenerAI
{
    boss_wakener_taerar(Creature* creature)
        : WakenerAI(creature, SPELL_ARCANE_BLAST, SPELL_SLEEP, true) { }
};

void AddSC_boss_emerald_sanctum()
{
    RegisterEmeraldSanctumCreatureAI(boss_erennius);
    RegisterEmeraldSanctumCreatureAI(boss_wakener_ysondre);
    RegisterEmeraldSanctumCreatureAI(boss_wakener_lethon);
    RegisterEmeraldSanctumCreatureAI(boss_wakener_emeriss);
    RegisterEmeraldSanctumCreatureAI(boss_wakener_taerar);
}
