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

// Timbermaw Hold -- the nine encounters, plus Kodiak and the Corrupted Draenethyst Geode.
//
// Turtle shipped these creatures with EventAI names and no events, so the kits are new. Each one
// is built from the creature itself: its Turtle model, its loot and the quest text around it
// (Ormanos is a cracked corrupted giant, Trioch a three-headed hydra, Loktanag a rotting bog beast,
// Selenaxx a crystal satyr drawing on the Geode next to her).
//
// Every spell id was checked against the server Spell.dbc before use. Weapon-damage spells (Cleave,
// Maul, Mortal Strike, Whirlwind, War Stomp, Trample) scale on their own; every fixed-damage spell
// goes through CastScaled, which sizes it off the caster's melee -- see TimbermawScaledDamage.

#include "CreatureScript.h"
#include "ScriptedCreature.h"
#include "timbermaw_hold.h"
#include <list>

enum TMBHSpells
{
    SPELL_CLEAVE                    = 15284,
    SPELL_CLEAVE_HEAVY              = 40504,
    SPELL_MORTAL_STRIKE             = 32736,
    SPELL_MORTAL_STRIKE_HEAVY       = 16856,
    SPELL_THUNDERCLAP               = 8078,     // dmg + slow; 23931 carries a -100% attack speed aura
    SPELL_ENRAGE                    = 8599,
    SPELL_FRENZY                    = 28131,
    SPELL_FRENZY_HEAVY              = 24318,
    SPELL_BERSERK                   = 26662,

    SPELL_NET                       = 12024,
    SPELL_MAUL                      = 26996,
    SPELL_TRAMPLE                   = 5568,
    SPELL_INFECTED_BITE             = 16128,

    SPELL_POISON_BOLT_VOLLEY        = 24099,
    SPELL_ENTANGLING_ROOTS          = 22415,
    SPELL_BLACK_SLUDGE              = 7279,

    SPELL_WAR_STOMP_HEAVY           = 31408,
    SPELL_KNOCK_AWAY                = 10101,
    SPELL_CRUSH_ARMOR               = 33661,

    SPELL_SHADOW_BOLT               = 34344,
    SPELL_SHADOW_BOLT_VOLLEY        = 27383,
    SPELL_SHADOW_BOLT_VOLLEY_RAID   = 21341,    // instant, 100 yd -- the Geode pulse and Ursol's shockwave
    SPELL_CURSE_OF_TONGUES          = 13338,
    SPELL_PSYCHIC_SCREAM            = 13704,

    SPELL_MOONFIRE                  = 20690,
    SPELL_HEALING_TOUCH             = 25297,
    SPELL_BLIND                     = 21060,

    SPELL_FLAME_BREATH              = 16390,
    SPELL_FROST_BREATH              = 16340,
    SPELL_ACID_BREATH               = 24839,

    SPELL_WHIRLWIND                 = 15589,
    SPELL_WAR_STOMP                 = 24375,
    SPELL_DEMORALIZING_SHOUT        = 23511,
    SPELL_BATTLE_SHOUT              = 9128,
    SPELL_INTIMIDATING_ROAR         = 16508
};

enum TMBHEvents
{
    EVENT_ABILITY_1 = 1,
    EVENT_ABILITY_2,
    EVENT_ABILITY_3,
    EVENT_ABILITY_4,
    EVENT_ABILITY_5
};

// creature_text GroupIDs, shared by every encounter. 4 is the "brazier goes dark" boss emote on the
// four guardians, and Selenaxx's "Geode shatters" line.
enum TMBHSays
{
    SAY_AGGRO   = 0,
    SAY_ABILITY = 1,
    SAY_PHASE   = 2,
    SAY_DEATH   = 3,
    SAY_EXTRA   = 4,
    SAY_BERSERK = 5
};

enum TMBHActions
{
    ACTION_PARTNER_DIED = 1
};

struct TimbermawBossAI : public BossAI
{
    TimbermawBossAI(Creature* creature, uint32 bossId) : BossAI(creature, bossId) { }

    void JustEngagedWith(Unit* who) override
    {
        BossAI::JustEngagedWith(who);
        Talk(SAY_AGGRO);
    }

    void JustDied(Unit* killer) override
    {
        BossAI::JustDied(killer);
        Talk(SAY_DEATH);
    }

protected:
    // bp0/bp1 as a fraction of this creature's melee swing; 0 leaves that effect's own value.
    void CastScaled(Unit* target, uint32 spellId, float bp0Fraction, float bp1Fraction = 0.0f)
    {
        if (!target)
            return;

        int32 const bp0 = TimbermawScaledDamage(me, bp0Fraction);
        int32 const bp1 = TimbermawScaledDamage(me, bp1Fraction);
        me->CastCustomSpell(target, spellId, bp0Fraction > 0.0f ? &bp0 : nullptr,
            bp1Fraction > 0.0f ? &bp1 : nullptr, nullptr, false);
    }

    Unit* RandomTarget(float range = 40.0f)
    {
        return SelectTarget(SelectTargetMethod::Random, 0, range, true);
    }

    void SummonAround(uint32 entry, uint8 count, float radius)
    {
        for (uint8 i = 0; i < count; ++i)
            me->SummonCreature(entry, me->GetRandomNearPosition(radius), TEMPSUMMON_CORPSE_TIMED_DESPAWN, 30000);
    }
};

// ---------------------------------------------------------------- Karrsh the Sentinel
// The gate guardian beside the Brazier of Corruption. A straight melee check that calls the
// hold's shadowkeepers in at half health.
struct boss_karrsh_the_sentinel : public TimbermawBossAI
{
    boss_karrsh_the_sentinel(Creature* creature) : TimbermawBossAI(creature, DATA_KARRSH) { }

    void Reset() override
    {
        TimbermawBossAI::Reset();
        ScheduleHealthCheckEvent(50, [&] {
            Talk(SAY_PHASE);
            SummonAround(NPC_WITHERMAW_SHADOWKEEPER, 2, 10.0f);
        });
        ScheduleHealthCheckEvent(30, [&] {
            DoCastSelf(SPELL_ENRAGE, true);
        });
    }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 6s);
        events.ScheduleEvent(EVENT_ABILITY_2, 12s);
        events.ScheduleEvent(EVENT_ABILITY_3, 18s);
    }

    void JustDied(Unit* killer) override
    {
        TimbermawBossAI::JustDied(killer);
        Talk(SAY_EXTRA);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastVictim(SPELL_CLEAVE);
                events.ScheduleEvent(EVENT_ABILITY_1, 8s, 10s);
                break;
            case EVENT_ABILITY_2:
                DoCastVictim(SPELL_MORTAL_STRIKE_HEAVY);
                events.ScheduleEvent(EVENT_ABILITY_2, 15s);
                break;
            case EVENT_ABILITY_3:
                Talk(SAY_ABILITY);
                CastScaled(me, SPELL_THUNDERCLAP, 0.35f);
                events.ScheduleEvent(EVENT_ABILITY_3, 20s, 24s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- Rotgrowl and Kodiak
// A hunter and his bear, one encounter. Kill one and the other goes berserk; the encounter (and the
// Brazier of Defilement) is only done when both are down. Rotgrowl carries the loot.
struct boss_rotgrowl : public TimbermawBossAI
{
    boss_rotgrowl(Creature* creature) : TimbermawBossAI(creature, DATA_ROTGROWL) { }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        if (Creature* kodiak = instance->GetCreature(DATA_KODIAK))
            if (kodiak->IsAlive() && !kodiak->IsInCombat())
                kodiak->AI()->AttackStart(who);

        events.ScheduleEvent(EVENT_ABILITY_1, 6s);
        events.ScheduleEvent(EVENT_ABILITY_2, 10s);
        events.ScheduleEvent(EVENT_ABILITY_3, 14s);
    }

    void DoAction(int32 action) override
    {
        if (action == ACTION_PARTNER_DIED)
        {
            Talk(SAY_PHASE);
            DoCastSelf(SPELL_FRENZY, true);
        }
    }

    void JustDied(Unit* /*killer*/) override
    {
        Talk(SAY_DEATH);
        if (Creature* kodiak = instance->GetCreature(DATA_KODIAK))
        {
            if (kodiak->IsAlive())
            {
                // The encounter ends with Kodiak, see npc_kodiak::JustDied.
                events.Reset();
                summons.DespawnAll();
                kodiak->AI()->DoAction(ACTION_PARTNER_DIED);
                return;
            }
        }

        _JustDied();
        Talk(SAY_EXTRA);
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        TimbermawBossAI::EnterEvadeMode(why);
        if (Creature* kodiak = instance->GetCreature(DATA_KODIAK))
        {
            if (!kodiak->IsAlive())
                kodiak->Respawn(true);
            else if (kodiak->IsInCombat())
                kodiak->AI()->EnterEvadeMode(why);
        }
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastVictim(SPELL_CLEAVE_HEAVY);
                events.ScheduleEvent(EVENT_ABILITY_1, 9s, 11s);
                break;
            case EVENT_ABILITY_2:
                if (Unit* target = RandomTarget(30.0f))
                {
                    Talk(SAY_ABILITY);
                    DoCast(target, SPELL_NET);
                }
                events.ScheduleEvent(EVENT_ABILITY_2, 16s, 20s);
                break;
            case EVENT_ABILITY_3:
                DoCastVictim(SPELL_MORTAL_STRIKE);
                events.ScheduleEvent(EVENT_ABILITY_3, 12s, 15s);
                break;
            default:
                break;
        }
    }
};

struct npc_kodiak : public ScriptedAI
{
    npc_kodiak(Creature* creature) : ScriptedAI(creature), _instance(creature->GetInstanceScript()) { }

    void Reset() override
    {
        _events.Reset();
    }

    void JustEngagedWith(Unit* who) override
    {
        if (Creature* rotgrowl = _instance->GetCreature(DATA_ROTGROWL))
            if (rotgrowl->IsAlive() && !rotgrowl->IsInCombat())
                rotgrowl->AI()->AttackStart(who);

        _events.ScheduleEvent(EVENT_ABILITY_1, 5s);
        _events.ScheduleEvent(EVENT_ABILITY_2, 9s);
        _events.ScheduleEvent(EVENT_ABILITY_3, 12s);
    }

    void DoAction(int32 action) override
    {
        if (action == ACTION_PARTNER_DIED)
        {
            Talk(0);
            DoCastSelf(SPELL_FRENZY_HEAVY, true);
        }
    }

    void JustDied(Unit* /*killer*/) override
    {
        Creature* rotgrowl = _instance->GetCreature(DATA_ROTGROWL);
        if (!rotgrowl)
            return;

        if (rotgrowl->IsAlive())
        {
            rotgrowl->AI()->DoAction(ACTION_PARTNER_DIED);
            return;
        }

        _instance->SetBossState(DATA_ROTGROWL, DONE);
        _instance->SaveToDB();
        rotgrowl->AI()->Talk(SAY_EXTRA);
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        ScriptedAI::EnterEvadeMode(why);
        if (Creature* rotgrowl = _instance->GetCreature(DATA_ROTGROWL))
        {
            if (!rotgrowl->IsAlive())
            {
                // Rotgrowl died first and the raid wiped on Kodiak: the whole pair resets.
                rotgrowl->Respawn(true);
                _instance->SetBossState(DATA_ROTGROWL, NOT_STARTED);
            }
            else if (rotgrowl->IsInCombat())
                rotgrowl->AI()->EnterEvadeMode(why);
        }
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
                case EVENT_ABILITY_1:
                    DoCastVictim(SPELL_MAUL);
                    _events.ScheduleEvent(EVENT_ABILITY_1, 6s, 8s);
                    break;
                case EVENT_ABILITY_2:
                {
                    int32 const tick = TimbermawScaledDamage(me, 0.06f);
                    if (Unit* victim = me->GetVictim())
                        me->CastCustomSpell(victim, SPELL_INFECTED_BITE, &tick, nullptr, nullptr, false);
                    _events.ScheduleEvent(EVENT_ABILITY_2, 15s, 18s);
                    break;
                }
                case EVENT_ABILITY_3:
                    DoCastSelf(SPELL_TRAMPLE);
                    _events.ScheduleEvent(EVENT_ABILITY_3, 12s, 15s);
                    break;
                default:
                    break;
            }
        }

        DoMeleeAttackIfReady();
    }

private:
    InstanceScript* _instance;
    EventMap _events;
};

// ---------------------------------------------------------------- Loktanag the Vile
// The rotting bog beast below the north wing. Every quarter of his health spills two more
// Corruptions of Loktanag into the room.
struct boss_loktanag_the_vile : public TimbermawBossAI
{
    boss_loktanag_the_vile(Creature* creature) : TimbermawBossAI(creature, DATA_LOKTANAG) { }

    void Reset() override
    {
        TimbermawBossAI::Reset();
        ScheduleHealthCheckEvent({ 75, 50, 25 }, [&] {
            Talk(SAY_ABILITY);
            SummonAround(NPC_CORRUPTION_OF_LOKTANAG, 2, 12.0f);
        });
    }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 8s);
        events.ScheduleEvent(EVENT_ABILITY_2, 14s);
        events.ScheduleEvent(EVENT_ABILITY_3, 20s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                CastScaled(me, SPELL_POISON_BOLT_VOLLEY, 0.30f, 0.06f);
                events.ScheduleEvent(EVENT_ABILITY_1, 14s, 16s);
                break;
            case EVENT_ABILITY_2:
                if (Unit* target = RandomTarget(35.0f))
                {
                    Talk(SAY_PHASE);
                    CastScaled(target, SPELL_ENTANGLING_ROOTS, 0.0f, 0.07f);
                }
                events.ScheduleEvent(EVENT_ABILITY_2, 18s, 22s);
                break;
            case EVENT_ABILITY_3:
                DoCastSelf(SPELL_BLACK_SLUDGE);
                events.ScheduleEvent(EVENT_ABILITY_3, 25s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- Ormanos the Cracked
// A corrupted mountain giant in the village. The hardest single hitter in the hold; at two thirds
// and one third pieces of him break off as Twisted Rumblers.
struct boss_ormanos_the_cracked : public TimbermawBossAI
{
    boss_ormanos_the_cracked(Creature* creature) : TimbermawBossAI(creature, DATA_ORMANOS) { }

    void Reset() override
    {
        TimbermawBossAI::Reset();
        ScheduleHealthCheckEvent({ 66, 33 }, [&] {
            Talk(SAY_ABILITY);
            SummonAround(NPC_TWISTED_RUMBLER, 3, 10.0f);
        });
    }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 6s);
        events.ScheduleEvent(EVENT_ABILITY_2, 15s);
        events.ScheduleEvent(EVENT_ABILITY_3, 22s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastVictim(SPELL_CRUSH_ARMOR);
                events.ScheduleEvent(EVENT_ABILITY_1, 8s);
                break;
            case EVENT_ABILITY_2:
                DoCastVictim(SPELL_KNOCK_AWAY);
                events.ScheduleEvent(EVENT_ABILITY_2, 18s, 22s);
                break;
            case EVENT_ABILITY_3:
                Talk(SAY_PHASE);
                DoCastSelf(SPELL_WAR_STOMP_HEAVY);
                events.ScheduleEvent(EVENT_ABILITY_3, 28s, 32s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- Chieftain Partath
// The high chieftain beside the Brazier of Putrification, flanked by two Withermaw Illuminators who
// join him the moment he is pulled.
struct boss_chieftain_partath : public TimbermawBossAI
{
    boss_chieftain_partath(Creature* creature) : TimbermawBossAI(creature, DATA_PARTATH) { }

    void Reset() override
    {
        TimbermawBossAI::Reset();
        ScheduleHealthCheckEvent(25, [&] {
            Talk(SAY_PHASE);
            DoCastSelf(SPELL_FRENZY_HEAVY, true);
        });
    }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);

        std::list<Creature*> illuminators;
        me->GetCreatureListWithEntryInGrid(illuminators, NPC_WITHERMAW_ILLUMINATOR, 40.0f);
        for (Creature* illuminator : illuminators)
            if (illuminator->IsAlive() && !illuminator->IsInCombat())
                illuminator->AI()->AttackStart(who);

        if (!illuminators.empty())
            Talk(SAY_ABILITY);

        DoCastSelf(SPELL_BATTLE_SHOUT, true);
        events.ScheduleEvent(EVENT_ABILITY_1, 8s);
        events.ScheduleEvent(EVENT_ABILITY_2, 5s);
        events.ScheduleEvent(EVENT_ABILITY_3, 15s);
        events.ScheduleEvent(EVENT_ABILITY_4, 25s);
    }

    void JustDied(Unit* killer) override
    {
        TimbermawBossAI::JustDied(killer);
        Talk(SAY_EXTRA);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastVictim(SPELL_MORTAL_STRIKE);
                events.ScheduleEvent(EVENT_ABILITY_1, 10s, 12s);
                break;
            case EVENT_ABILITY_2:
                DoCastSelf(SPELL_DEMORALIZING_SHOUT);
                events.ScheduleEvent(EVENT_ABILITY_2, 30s);
                break;
            case EVENT_ABILITY_3:
                DoCastSelf(SPELL_WHIRLWIND);
                events.ScheduleEvent(EVENT_ABILITY_3, 18s, 22s);
                break;
            case EVENT_ABILITY_4:
                DoCastSelf(SPELL_WAR_STOMP);
                events.ScheduleEvent(EVENT_ABILITY_4, 30s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- Archdruid Kronn
// The tribe's archdruid, beside the Brazier of Decay. A caster who keeps calling shadowkeepers out
// of the dark and tries to heal himself twice -- both heals are long casts, and both should be
// interrupted.
struct boss_archdruid_kronn : public TimbermawBossAI
{
    boss_archdruid_kronn(Creature* creature) : TimbermawBossAI(creature, DATA_KRONN) { }

    void Reset() override
    {
        TimbermawBossAI::Reset();
        ScheduleHealthCheckEvent({ 50, 25 }, [&] {
            int32 const heal = int32(me->CountPctFromMaxHealth(5));
            me->CastCustomSpell(me, SPELL_HEALING_TOUCH, &heal, nullptr, nullptr, false);
        }, false);
    }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 3s);
        events.ScheduleEvent(EVENT_ABILITY_2, 12s);
        events.ScheduleEvent(EVENT_ABILITY_3, 20s);
        events.ScheduleEvent(EVENT_ABILITY_4, 25s);
    }

    void JustDied(Unit* killer) override
    {
        TimbermawBossAI::JustDied(killer);
        Talk(SAY_EXTRA);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                CastScaled(RandomTarget(), SPELL_MOONFIRE, 0.06f, 0.40f);
                events.ScheduleEvent(EVENT_ABILITY_1, 6s, 8s);
                break;
            case EVENT_ABILITY_2:
                CastScaled(RandomTarget(35.0f), SPELL_ENTANGLING_ROOTS, 0.0f, 0.05f);
                events.ScheduleEvent(EVENT_ABILITY_2, 16s, 20s);
                break;
            case EVENT_ABILITY_3:
                Talk(SAY_ABILITY);
                SummonAround(NPC_WITHERMAW_SHADOWKEEPER, 2, 12.0f);
                events.ScheduleEvent(EVENT_ABILITY_3, 40s);
                break;
            case EVENT_ABILITY_4:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 1, 30.0f, true))
                {
                    Talk(SAY_PHASE);
                    DoCast(target, SPELL_BLIND);
                }
                events.ScheduleEvent(EVENT_ABILITY_4, 25s, 30s);
                break;
            default:
                break;
        }
    }
};

// ---------------------------------------------------------------- Selenaxx Foulheart
// The crystal satyr in the satyr room, drawing on the Corrupted Draenethyst Geode beside her.
// While the Geode stands she takes a quarter damage and it pulses shadow through the whole room, so
// the fight is: break the Geode, then her. Geode Shards (Draenethyst Recovery) drop from her.
struct boss_selenaxx_foulheart : public TimbermawBossAI
{
    boss_selenaxx_foulheart(Creature* creature) : TimbermawBossAI(creature, DATA_SELENAXX) { }

    Creature* LivingGeode() const
    {
        Creature* geode = instance->GetCreature(DATA_GEODE);
        return geode && geode->IsAlive() ? geode : nullptr;
    }

    void Reset() override
    {
        TimbermawBossAI::Reset();
        if (Creature* geode = instance->GetCreature(DATA_GEODE))
            if (!geode->IsAlive())
                geode->Respawn(true);

        ScheduleHealthCheckEvent(50, [&] {
            Talk(SAY_PHASE);
            SummonAround(NPC_FOULHEART_WARLOCK, 2, 10.0f);
        });
    }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        if (Creature* geode = LivingGeode())
        {
            Talk(SAY_ABILITY);
            if (!geode->IsInCombat())
                geode->AI()->AttackStart(who);
        }

        events.ScheduleEvent(EVENT_ABILITY_1, 4s);
        events.ScheduleEvent(EVENT_ABILITY_2, 12s);
        events.ScheduleEvent(EVENT_ABILITY_3, 10s);
        events.ScheduleEvent(EVENT_ABILITY_4, 25s);
    }

    void DamageTaken(Unit* attacker, uint32& damage, DamageEffectType damageType, SpellSchoolMask schoolMask) override
    {
        if (LivingGeode())
            damage /= 4;

        TimbermawBossAI::DamageTaken(attacker, damage, damageType, schoolMask);
    }

    void JustDied(Unit* killer) override
    {
        TimbermawBossAI::JustDied(killer);
        if (Creature* geode = LivingGeode())
            geode->DespawnOrUnsummon();
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        TimbermawBossAI::EnterEvadeMode(why);
        if (Creature* geode = LivingGeode())
            if (geode->IsInCombat())
                geode->AI()->EnterEvadeMode(why);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                CastScaled(RandomTarget(), SPELL_SHADOW_BOLT, 0.60f);
                events.ScheduleEvent(EVENT_ABILITY_1, 6s, 8s);
                break;
            case EVENT_ABILITY_2:
                CastScaled(me, SPELL_SHADOW_BOLT_VOLLEY, 0.25f);
                events.ScheduleEvent(EVENT_ABILITY_2, 16s, 18s);
                break;
            case EVENT_ABILITY_3:
                if (Unit* target = RandomTarget())
                    DoCast(target, SPELL_CURSE_OF_TONGUES);
                events.ScheduleEvent(EVENT_ABILITY_3, 18s, 22s);
                break;
            case EVENT_ABILITY_4:
                DoCastSelf(SPELL_PSYCHIC_SCREAM);
                events.ScheduleEvent(EVENT_ABILITY_4, 30s);
                break;
            default:
                break;
        }
    }
};

struct npc_corrupted_draenethyst_geode : public ScriptedAI
{
    npc_corrupted_draenethyst_geode(Creature* creature)
        : ScriptedAI(creature), _instance(creature->GetInstanceScript()) { }

    void Reset() override
    {
        _events.Reset();
    }

    void JustEngagedWith(Unit* who) override
    {
        if (Creature* selenaxx = _instance->GetCreature(DATA_SELENAXX))
            if (selenaxx->IsAlive() && !selenaxx->IsInCombat())
                selenaxx->AI()->AttackStart(who);

        _events.ScheduleEvent(EVENT_ABILITY_1, 4s);
    }

    void JustDied(Unit* /*killer*/) override
    {
        if (Creature* selenaxx = _instance->GetCreature(DATA_SELENAXX))
            if (selenaxx->IsAlive())
                selenaxx->AI()->Talk(SAY_EXTRA);
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        ScriptedAI::EnterEvadeMode(why);
        if (Creature* selenaxx = _instance->GetCreature(DATA_SELENAXX))
            if (selenaxx->IsAlive() && selenaxx->IsInCombat())
                selenaxx->AI()->EnterEvadeMode(why);
    }

    // Rooted and never swings: its whole threat is the pulse, sized off Selenaxx's melee so the
    // two always scale together.
    void UpdateAI(uint32 diff) override
    {
        if (!UpdateVictim())
            return;

        _events.Update(diff);
        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        if (_events.ExecuteEvent() == EVENT_ABILITY_1)
        {
            Creature* selenaxx = _instance->GetCreature(DATA_SELENAXX);
            int32 const pulse = TimbermawScaledDamage(selenaxx ? selenaxx : me, 0.12f);
            me->CastCustomSpell(me, SPELL_SHADOW_BOLT_VOLLEY_RAID, &pulse, nullptr, nullptr, false);
            _events.ScheduleEvent(EVENT_ABILITY_1, 8s);
        }
    }

private:
    InstanceScript* _instance;
    EventMap _events;
};

// ---------------------------------------------------------------- Trioch the Devourer
// The three-headed hydra patrolling the corruption wing. Each head breathes in turn -- fire, frost
// and acid -- so the cone never stops; its melee is light by design, the breaths are the damage.
struct boss_trioch_the_devourer : public TimbermawBossAI
{
    boss_trioch_the_devourer(Creature* creature) : TimbermawBossAI(creature, DATA_TRIOCH) { }

    void Reset() override
    {
        TimbermawBossAI::Reset();
        _nextHead = 0;
        ScheduleHealthCheckEvent(30, [&] {
            DoCastSelf(SPELL_FRENZY, true);
        });
    }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        events.ScheduleEvent(EVENT_ABILITY_1, 8s);
        events.ScheduleEvent(EVENT_ABILITY_2, 14s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                if (_nextHead == 0)
                    Talk(SAY_ABILITY);
                switch (_nextHead)
                {
                    case 0:
                        CastScaled(me->GetVictim(), SPELL_FLAME_BREATH, 0.90f);
                        break;
                    case 1:
                        CastScaled(me->GetVictim(), SPELL_FROST_BREATH, 0.80f);
                        break;
                    default:
                        CastScaled(me->GetVictim(), SPELL_ACID_BREATH, 0.60f, 0.08f);
                        break;
                }
                _nextHead = (_nextHead + 1) % 3;
                events.ScheduleEvent(EVENT_ABILITY_1, 9s);
                break;
            case EVENT_ABILITY_2:
                DoCastSelf(SPELL_TRAMPLE);
                events.ScheduleEvent(EVENT_ABILITY_2, 14s, 16s);
                break;
            default:
                break;
        }
    }

private:
    uint8 _nextHead = 0;
};

// ---------------------------------------------------------------- Ursol
// The corrupted demigod, final boss. He wakes when the fourth brazier dies (see the instance
// script). Calls his sons at each quarter, frenzies at 20% and goes berserk at ten minutes.
struct boss_ursol : public TimbermawBossAI
{
    boss_ursol(Creature* creature) : TimbermawBossAI(creature, DATA_URSOL) { }

    void Reset() override
    {
        TimbermawBossAI::Reset();
        ScheduleHealthCheckEvent({ 75, 50, 25 }, [&] {
            Talk(SAY_ABILITY);
            SummonAround(NPC_SON_OF_URSOL, 3, 15.0f);
        });
        ScheduleHealthCheckEvent(20, [&] {
            Talk(SAY_PHASE);
            DoCastSelf(SPELL_FRENZY_HEAVY, true);
        });
    }

    void JustEngagedWith(Unit* who) override
    {
        TimbermawBossAI::JustEngagedWith(who);
        ScheduleEnrageTimer(SPELL_BERSERK, 10min, SAY_BERSERK);
        events.ScheduleEvent(EVENT_ABILITY_1, 5s);
        events.ScheduleEvent(EVENT_ABILITY_2, 8s);
        events.ScheduleEvent(EVENT_ABILITY_3, 10s);
        events.ScheduleEvent(EVENT_ABILITY_4, 20s);
        events.ScheduleEvent(EVENT_ABILITY_5, 30s);
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_ABILITY_1:
                DoCastVictim(SPELL_MAUL);
                events.ScheduleEvent(EVENT_ABILITY_1, 6s, 8s);
                break;
            case EVENT_ABILITY_2:
                DoCastVictim(SPELL_CLEAVE_HEAVY);
                events.ScheduleEvent(EVENT_ABILITY_2, 9s);
                break;
            case EVENT_ABILITY_3:
                DoCastVictim(SPELL_CRUSH_ARMOR);
                events.ScheduleEvent(EVENT_ABILITY_3, 10s);
                break;
            case EVENT_ABILITY_4:
                CastScaled(me, SPELL_SHADOW_BOLT_VOLLEY_RAID, 0.20f);
                events.ScheduleEvent(EVENT_ABILITY_4, 22s, 26s);
                break;
            case EVENT_ABILITY_5:
                DoCastSelf(SPELL_INTIMIDATING_ROAR);
                events.ScheduleEvent(EVENT_ABILITY_5, 35s);
                break;
            default:
                break;
        }
    }
};

void AddSC_boss_timbermaw_hold()
{
    RegisterTimbermawHoldCreatureAI(boss_karrsh_the_sentinel);
    RegisterTimbermawHoldCreatureAI(boss_rotgrowl);
    RegisterTimbermawHoldCreatureAI(npc_kodiak);
    RegisterTimbermawHoldCreatureAI(boss_loktanag_the_vile);
    RegisterTimbermawHoldCreatureAI(boss_ormanos_the_cracked);
    RegisterTimbermawHoldCreatureAI(boss_chieftain_partath);
    RegisterTimbermawHoldCreatureAI(boss_archdruid_kronn);
    RegisterTimbermawHoldCreatureAI(boss_selenaxx_foulheart);
    RegisterTimbermawHoldCreatureAI(npc_corrupted_draenethyst_geode);
    RegisterTimbermawHoldCreatureAI(boss_trioch_the_devourer);
    RegisterTimbermawHoldCreatureAI(boss_ursol);
}
