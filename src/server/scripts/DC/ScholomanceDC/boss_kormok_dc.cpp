/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// ---------------------------------------------------------------------------------
// DARKCHAOS CLONE -- map 822. Generated from boss_kormok.cpp, then renamed.
//
// This is a copy, not a fork: the logic is upstream AzerothCore's and should stay that way
// so upstream fixes can be re-applied by regenerating. What differs:
//     * script names, so they cannot collide with the stock registrations
//       (ScriptMgr.h:839 silently DELETES the older script when a name is reused)
//     * the map id, 822 instead of 289
//     * the header, scholomance_dc.h, whose enums carry the REMAPPED clone entry ids
//
//     * the two spell-bound scripts in the upstream file are NOT cloned. They attach to
//       SPELL ids via spell_script_names, and Spell.dbc is shared with stock Scholomance,
//       so the stock registrations already run here -- cloning them would double-register
//       the same spells.
// Stock Scholomance on map 289 keeps its own scripts, spawns and entrance untouched.
// ---------------------------------------------------------------------------------

#include "CreatureScript.h"
#include "ScriptedCreature.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "TaskScheduler.h"
#include "scholomance_dc.h"

enum Spells
{
    SPELL_SHADOWBOLT_VOLLEY             = 20741,
    SPELL_BONE_SHIELD                   = 27688,

    SPELL_SUMMON_BONE_MAGES             = 27695,

    SPELL_SUMMON_BONE_MAGE_FRONT_LEFT   = 27696,
    SPELL_SUMMON_BONE_MAGE_FRONT_RIGHT  = 27697,
    SPELL_SUMMON_BONE_MAGE_BACK_RIGHT   = 27698,
    SPELL_SUMMON_BONE_MAGE_BACK_LEFT    = 27699,

    SPELL_SUMMON_BONE_MINION1           = 27690,
    SPELL_SUMMON_BONE_MINION2           = 27691,
    SPELL_SUMMON_BONE_MINION3           = 27692,
    SPELL_SUMMON_BONE_MINION4           = 27693,

    SPELL_SUMMON_BONE_MINIONS           = 27687
};

enum Events
{
    EVENT_SHADOWBOLT_VOLLEY = 1,
    EVENT_SUMMON_MINIONS
};

enum Says
{
    TALK_SUMMON     = 0,
    TALK_AGGRO      = 1,
    TALK_ENRAGE     = 2,
    TALK_DEATH      = 3
};

struct boss_kormok_dc : public ScriptedAI
{
    boss_kormok_dc(Creature* creature) : ScriptedAI(creature), _summons(creature) {}

    void Reset() override
    {
        _mages = false;

        _scheduler.CancelAll();
        _scheduler.SetValidator([this]
        {
            return !me->HasUnitState(UNIT_STATE_CASTING);
        });

        _summons.DespawnAll();
    }

    void IsSummonedBy(WorldObject* /*summoner*/) override
    {
        Talk(TALK_SUMMON);

        _scheduler.Schedule(2s, [this](TaskContext context)
        {
            DoCastSelf(SPELL_BONE_SHIELD);
            context.Repeat(45s);
        });
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        Talk(TALK_AGGRO);

        _scheduler.Schedule(10s, [this](TaskContext context)
        {
            DoCastVictim(SPELL_SHADOWBOLT_VOLLEY);
            context.Repeat(15s);
        })
        .Schedule(15s, [this](TaskContext context)
        {
            DoCast(SPELL_SUMMON_BONE_MINIONS);
            context.Repeat(12s);
        });
    }

    void JustSummoned(Creature* summon) override
    {
        // ---------------------------------------------------------------------------
        // WHY THIS SWAP EXISTS
        // ---------------------------------------------------------------------------
        // Kormok's adds are not summoned by this script. He casts 27687 / 27695, whose
        // spell scripts chain to 27690-27693 and 27696-27699, and THOSE do the summoning
        // through SPELL_EFFECT_SUMMON with the creature id in EffectMiscValue -- i.e. the
        // entry lives in Spell.dbc, which is SHARED with stock Scholomance. Verified:
        // 27690-27693 all carry EffectMiscValue 16119.
        //
        // So on this map the spells still produce the STOCK adds. They would fight and die
        // normally, but they are the stock entries -- stock level and stock loot -- which
        // defeats the point of a private map that is going to be re-levelled to 130-160.
        //
        // Cloning the eight summon spells would mean appending to the 234-field fork
        // Spell.dbc and redeploying the client. Instead the summon is caught here and
        // replaced with the clone entry AT THE SAME POSITION, so the spell keeps choosing
        // where each add appears and only the creature identity changes.
        //
        // No recursion: the replacement is summoned with a clone entry, so when
        // JustSummoned fires again for it, neither branch below matches and it simply
        // falls through to the normal path.
        uint32 cloneEntry = 0;
        if (summon->GetEntry() == NPC_BONE_MINION_STOCK)
            cloneEntry = NPC_BONE_MINION;
        else if (summon->GetEntry() == NPC_BONE_MAGE_STOCK)
            cloneEntry = NPC_BONE_MAGE;

        if (cloneEntry)
        {
            Position const pos = summon->GetPosition();
            summon->DespawnOrUnsummon();

            if (Creature* replacement = me->SummonCreature(cloneEntry, pos, TEMPSUMMON_CORPSE_TIMED_DESPAWN, 5000))
            {
                _summons.Summon(replacement);
                DoZoneInCombat(replacement);
            }
            return;
        }

        _summons.Summon(summon);
        DoZoneInCombat(summon);
    }

    void SummonedCreatureDespawn(Creature* summon) override
    {
        _summons.Despawn(summon);
    }

    void DamageTaken(Unit* /*attacker*/, uint32& damage, DamageEffectType /*damageType*/, SpellSchoolMask /*damageSchoolMask*/) override
    {
        if (!_mages && me->HealthBelowPctDamaged(25, damage))
        {
            _mages = true;

            Talk(TALK_ENRAGE);

            DoCast(SPELL_SUMMON_BONE_MAGES);
        }
    }

    void JustDied(Unit* /*killer*/) override
    {
        Talk(TALK_DEATH);
    }

    void UpdateAI(uint32 diff) override
    {
        _scheduler.Update(diff);

        if (!UpdateVictim())
        {
            return;
        }

        DoMeleeAttackIfReady();
    }

    private:
        TaskScheduler _scheduler;
        SummonList _summons;
        bool _mages;
};


void AddSC_boss_kormok_dc()
{
    RegisterScholomanceDCCreatureAI(boss_kormok_dc);
}
