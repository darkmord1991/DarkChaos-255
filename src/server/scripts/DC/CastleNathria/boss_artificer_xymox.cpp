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

// DarkChaos downport of Artificer Xy'mox, fifth boss of Castle Nathria (map 2296).
// Ported from ShadowCore (TrinityCore 9.x) to AzerothCore 3.3.5a idioms -- see
// DC/BlackwingDescent/PORT_NOTES.md for the API divergence log this port follows.
//
// 3.3.5 substitutions:
// - The 3.3.5 CreatureAI has no OnSpellFinished hook: each "on cast finished" follow-up is
//   scheduled off the cast start via the AI scheduler (~3s, matching the SL cast times).
// - Spawned AreaTriggers do not exist: the Stasis Trap AreaTrigger (at_stasis_trap) is
//   substituted with the NPC_STASIS_TRAP trigger creature; the Seeds of Extinction were
//   already creatures in the source. Author the *_CREATE_AT spell_dbc downports as
//   persistent-area-aura ground effects.
// - Mythic difficulty does not exist: mythic-only branches (8 seeds, root kept in phase 3)
//   were folded into the normal/heroic paths.

#include "InstanceScript.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "castle_nathria.h"

namespace CastleNathria::ArtificerXymox
{
enum Spells
{
    SPELL_DIMENSIONAL_TEAR_CAST         = 328437,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_DIMENSIONAL_TEAR_DEBUFF       = 328448,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_DIMENSIONAL_TEAR_EXP          = 328545,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_WORMHOLE_A_SUMMON             = 328308,   // TODO(spell_dbc): SL spell, needs downport row (unused -- summons 168726)
    SPELL_WORMHOLE_B_SUMMON             = 328312,   // TODO(spell_dbc): SL spell, needs downport row (unused -- summons 168730)
    SPELL_GLYPH_OF_DESTRUCTION          = 325361,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_GLYPH_OF_DESTRUCTION_PERIODIC = 325236,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_GLYPH_OF_DESTRUCTION_EXP      = 325324,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_RIFT_BLAST_CAST               = 335013,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_RIFT_BLAST_DAMAGE             = 329256,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_RIFT_BLAST_SUMMON             = 329459,   // TODO(spell_dbc): SL spell, needs downport row (unused -- summon done directly)
    SPELL_HYPERLIGHT_SPARK              = 325399,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_CRYSTAL_OF_PHANTASM           = 327887,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_POSSESION                     = 327414,   // TODO(spell_dbc): SL spell, needs downport row (source typo preserved)
    SPELL_SOUL_SINGE                    = 340824,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)

    // Phase 2
    SPELL_ROOT_OF_EXTINCTION_CAST       = 329770,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_ROOT_OF_EXTINCTION_VISUAL     = 329243,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_ROOT_OF_EXTINCTION_CREATE_AT  = 329982,   // TODO(spell_dbc): SL spell, needs downport row (author as persistent-area-aura)
    SPELL_SEED_OF_EXTINCTION_BUTTON     = 329090,   // TODO(spell_dbc): SL spell, needs downport row (spellclick disarm, unused in source)
    SPELL_SEED_OF_EXTINCTION_CAST       = 329834,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_SEED_OF_EXTINCTION_EXP        = 329107,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_WITHERING_TOUCH_MISSILE       = 340854,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_WITHERING_TOUCH_PERIODIC      = 340860,   // TODO(spell_dbc): SL spell, needs downport row (unused in source)

    // Phase 3
    SPELL_EDGE_OF_ANNIHILATION_CAST     = 328880,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_EDGE_OF_ANNIHILATION_VISUAL   = 258832,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_EDGE_OF_ANNIHILATION_KNOCKBACK = 329613,  // TODO(spell_dbc): SL spell, needs downport row (unused in source)
    SPELL_AURA_OF_DREAD                 = 340870,   // TODO(spell_dbc): SL spell, needs downport row

    // Heroic
    SPELL_STASIS_TRAP_CAST              = 326271,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_STASIS_TRAP_TRIGGER           = 326272,   // TODO(spell_dbc): SL spell, needs downport row
    SPELL_STASIS_TRAP_CREATE_AT         = 326275,   // TODO(spell_dbc): SL spell, needs downport row (was at_stasis_trap)
    SPELL_STASIS_TRAP_STUN              = 326302    // TODO(spell_dbc): SL spell, needs downport row
};

enum Texts
{
    // creature_text GroupIDs for entry 166644 (Custom/.../worlddb/CastleNathria/09_creature_text.sql).
    // The source AI had no Talk() calls; the DB lines are hooked to their matching abilities.
    SAY_AGGRO                   = 0,    // "Wonderful! I have been hoping to test these relics on live targets."
    SAY_STASIS_TRAP             = 1,    // "Mind your step!"
    SAY_ROOT_OF_EXTINCTION      = 2,    // "Let us see if the legends of this relic are true!"
    SAY_GLYPH_OF_DESTRUCTION    = 3,    // "Destruction is guaranteed!"
    SAY_DIMENSIONAL_TEAR        = 4,    // "The warp beckons!"
    SAY_EDGE_OF_ANNIHILATION    = 5,    // "The anticipation to use this relic is killing me! ..."
    SAY_SLAY                    = 6,    // "To die is your only value!"
    SAY_SLAY_2                  = 7,    // "You cannot bargain with death!"
    SAY_SEED_OF_EXTINCTION      = 8,    // "Die together!"
    SAY_CRYSTAL_OF_PHANTASM     = 9,    // "I hope this wondrous item is as lethal as it looks!"
    SAY_DEATH                   = 10    // "This exchange has no further value. ..."
};

Position const RootOfExtinctionSpawnPos    = { -1846.248f, 6402.999f, 4364.875f, 0.0f };
Position const EdgeOfAnnihilationSpawnPos  = { -1845.812f, 6402.990f, 4331.588f, 0.0f };

// 166644 - Artificer Xy'mox
struct boss_artificer_xymox : public BossAI
{
    boss_artificer_xymox(Creature* creature) : BossAI(creature, DATA_ARTIFICER_XYMOX),
        _stageTwo(false), _stageThree(false) { }

    void Reset() override
    {
        _Reset();
        me->setPowerType(POWER_ENERGY);
        me->SetMaxPower(POWER_ENERGY, 100);
        me->SetPower(POWER_ENERGY, 0);
        me->SetReactState(REACT_AGGRESSIVE);
        me->SetObjectScale(2.0f);
        _stageTwo = false;
        _stageThree = false;
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        _JustEngagedWith();
        Talk(SAY_AGGRO);
        events.ScheduleEvent(SPELL_HYPERLIGHT_SPARK, 4800ms);
        events.ScheduleEvent(SPELL_DIMENSIONAL_TEAR_CAST, 13s);
        events.ScheduleEvent(SPELL_GLYPH_OF_DESTRUCTION, 8s);
        events.ScheduleEvent(SPELL_RIFT_BLAST_CAST, 19s);
        events.ScheduleEvent(SPELL_CRYSTAL_OF_PHANTASM, 25s);
        if (IsHeroic()) // source: heroic + mythic; no mythic on 3.3.5
            events.ScheduleEvent(SPELL_STASIS_TRAP_CAST, 10s);
    }

    void DamageTaken(Unit* attacker, uint32& damage, DamageEffectType damagetype, SpellSchoolMask damageSchoolMask) override
    {
        BossAI::DamageTaken(attacker, damage, damagetype, damageSchoolMask);

        if (HealthBelowPct(70) && !_stageTwo)
        {
            _stageTwo = true;
            events.Reset();
            events.ScheduleEvent(SPELL_HYPERLIGHT_SPARK, 4800ms);
            events.ScheduleEvent(SPELL_DIMENSIONAL_TEAR_CAST, 13s);
            events.ScheduleEvent(SPELL_GLYPH_OF_DESTRUCTION, 8s);
            events.ScheduleEvent(SPELL_RIFT_BLAST_CAST, 19s);
            if (IsHeroic())
            {
                events.ScheduleEvent(SPELL_STASIS_TRAP_CAST, 10s);
                events.ScheduleEvent(SPELL_CRYSTAL_OF_PHANTASM, 25s);
            }
            events.ScheduleEvent(SPELL_ROOT_OF_EXTINCTION_CAST, 3s);
            events.ScheduleEvent(SPELL_SEED_OF_EXTINCTION_CAST, 45s);
            events.ScheduleEvent(SPELL_WITHERING_TOUCH_MISSILE, 50s);
        }

        if (HealthBelowPct(40) && !_stageThree)
        {
            _stageThree = true;
            events.Reset();
            // Source kept the root alive on mythic only; no mythic on 3.3.5.
            if (Creature* root = me->FindNearestCreature(NPC_ROOT_OF_EXTINCTION, 100.0f, true))
                root->DespawnOrUnsummon();

            events.ScheduleEvent(SPELL_HYPERLIGHT_SPARK, 4800ms);
            events.ScheduleEvent(SPELL_DIMENSIONAL_TEAR_CAST, 13s);
            events.ScheduleEvent(SPELL_GLYPH_OF_DESTRUCTION, 8s);
            events.ScheduleEvent(SPELL_RIFT_BLAST_CAST, 19s);
            if (IsHeroic())
            {
                events.ScheduleEvent(SPELL_STASIS_TRAP_CAST, 10s);
                events.ScheduleEvent(SPELL_CRYSTAL_OF_PHANTASM, 25s);
            }
            events.ScheduleEvent(SPELL_EDGE_OF_ANNIHILATION_CAST, 3s);
        }
    }

    void ExecuteEvent(uint32 eventId) override
    {
        // TODO(port): the source fired most follow-ups from an OnSpellFinished hook; the 3.3.5
        // CreatureAI has no such hook, so impacts are scheduled off the cast start (~SL cast time).
        switch (eventId)
        {
            case SPELL_HYPERLIGHT_SPARK:
                ForEachPlayerInRoom([this](Player* player)
                {
                    me->CastSpell(player, SPELL_HYPERLIGHT_SPARK, false);
                });
                events.Repeat(14s, 18s);
                break;
            case SPELL_DIMENSIONAL_TEAR_CAST:
                Talk(SAY_DIMENSIONAL_TEAR);
                me->CastSpell(nullptr, SPELL_DIMENSIONAL_TEAR_CAST, false);
                scheduler.Schedule(3s, [this](TaskContext /*context*/)
                {
                    UnitList targetList;
                    SelectTargetList(targetList, 2, SelectTargetMethod::Random, 0, 100.0f, true);
                    for (Unit* target : targetList)
                    {
                        me->AddAura(SPELL_DIMENSIONAL_TEAR_DEBUFF, target);
                        ObjectGuid targetGuid = target->GetGUID();
                        scheduler.Schedule(8100ms, [this, targetGuid](TaskContext /*context*/)
                        {
                            if (Unit* target = ObjectAccessor::GetUnit(*me, targetGuid))
                                me->CastSpell(target, SPELL_DIMENSIONAL_TEAR_EXP, true);
                        });
                    }
                });
                events.Repeat(40s);
                break;
            case SPELL_GLYPH_OF_DESTRUCTION:
                if (Unit* target = SelectTarget(SelectTargetMethod::MaxThreat, 0, 100.0f, true))
                {
                    Talk(SAY_GLYPH_OF_DESTRUCTION);
                    me->CastSpell(target, SPELL_GLYPH_OF_DESTRUCTION, false);
                    ObjectGuid targetGuid = target->GetGUID();
                    scheduler.Schedule(3s, [this, targetGuid](TaskContext /*context*/)
                    {
                        if (Unit* target = ObjectAccessor::GetUnit(*me, targetGuid))
                            me->AddAura(SPELL_GLYPH_OF_DESTRUCTION_PERIODIC, target);
                    });
                    scheduler.Schedule(7s, [this, targetGuid](TaskContext /*context*/) // 3s cast + 4s fuse
                    {
                        if (Unit* target = ObjectAccessor::GetUnit(*me, targetGuid))
                            me->CastSpell(target, SPELL_GLYPH_OF_DESTRUCTION_EXP, true);
                    });
                }
                events.Repeat(30s);
                break;
            case SPELL_RIFT_BLAST_CAST:
                me->CastSpell(nullptr, SPELL_RIFT_BLAST_CAST, false);
                // NOTE: the source re-blasted every rift in the grid per summon; simplified to
                // one blast per freshly summoned rift.
                scheduler.Schedule(3s, [this](TaskContext /*context*/)
                {
                    UnitList targetList;
                    SelectTargetList(targetList, 3, SelectTargetMethod::Random, 0, 100.0f, true);
                    for (Unit* target : targetList)
                        if (Creature* rift = me->SummonCreature(NPC_RIFT_BLAST, target->GetPosition(), TEMPSUMMON_TIMED_DESPAWN, 30000))
                            if (Unit* blastTarget = SelectTarget(SelectTargetMethod::Random, 0, 30.0f, true))
                            {
                                rift->SetFacingToObject(blastTarget);
                                rift->CastSpell(blastTarget, SPELL_RIFT_BLAST_DAMAGE, false);
                            }
                });
                events.Repeat(45s);
                break;
            case SPELL_CRYSTAL_OF_PHANTASM:
                Talk(SAY_CRYSTAL_OF_PHANTASM);
                me->CastSpell(nullptr, SPELL_CRYSTAL_OF_PHANTASM, false);
                scheduler.Schedule(3s, [this](TaskContext /*context*/)
                {
                    me->SummonCreature(NPC_FLEETING_SPIRIT, me->GetPosition(), TEMPSUMMON_MANUAL_DESPAWN);
                });
                events.Repeat(50s);
                break;
            case SPELL_ROOT_OF_EXTINCTION_CAST:
                Talk(SAY_ROOT_OF_EXTINCTION);
                me->CastSpell(nullptr, SPELL_ROOT_OF_EXTINCTION_CAST, false);
                scheduler.Schedule(3s, [this](TaskContext /*context*/)
                {
                    me->SummonCreature(NPC_ROOT_OF_EXTINCTION, RootOfExtinctionSpawnPos, TEMPSUMMON_MANUAL_DESPAWN);
                });
                break;
            case SPELL_SEED_OF_EXTINCTION_CAST:
                Talk(SAY_SEED_OF_EXTINCTION);
                me->CastSpell(nullptr, SPELL_SEED_OF_EXTINCTION_CAST, false);
                // TODO(port): mythic spawned 8 seeds; no mythic on 3.3.5, always 4.
                scheduler.Schedule(3s, [this](TaskContext /*context*/)
                {
                    for (uint8 i = 0; i < 4; ++i)
                        me->SummonCreature(NPC_SEED_OF_EXTINCTION, me->GetRandomNearPosition(30.0f), TEMPSUMMON_MANUAL_DESPAWN);
                });
                events.Repeat(45s);
                break;
            case SPELL_WITHERING_TOUCH_MISSILE:
                DoCastRandomTarget(SPELL_WITHERING_TOUCH_MISSILE, 0, 100.0f, true, true);
                events.Repeat(21s);
                break;
            case SPELL_EDGE_OF_ANNIHILATION_CAST:
                Talk(SAY_EDGE_OF_ANNIHILATION);
                me->CastSpell(nullptr, SPELL_EDGE_OF_ANNIHILATION_CAST, false);
                scheduler.Schedule(3s, [this](TaskContext /*context*/)
                {
                    me->SummonCreature(NPC_EDGE_OF_ANNIHILATION, EdgeOfAnnihilationSpawnPos, TEMPSUMMON_MANUAL_DESPAWN);
                });
                break;
            case SPELL_STASIS_TRAP_CAST:
            {
                Talk(SAY_STASIS_TRAP);
                me->CastSpell(nullptr, SPELL_STASIS_TRAP_CAST, true);
                UnitList targetList;
                SelectTargetList(targetList, 3, SelectTargetMethod::Random, 0, 100.0f, true);
                for (Unit* target : targetList)
                {
                    me->CastSpell(target, SPELL_STASIS_TRAP_TRIGGER, true);
                    // TODO(port): the trigger created a Stasis Trap AreaTrigger (at_stasis_trap);
                    // substituted with the NPC_STASIS_TRAP trigger creature. Its stun
                    // (SPELL_STASIS_TRAP_STUN) needs the spell_dbc downport authored as a
                    // proximity-periodic on the trap.
                    me->SummonCreature(NPC_STASIS_TRAP, target->GetPosition(), TEMPSUMMON_TIMED_DESPAWN, 60000);
                }
                events.Repeat(28s);
                break;
            }
            default:
                break;
        }
    }

    void JustSummoned(Creature* summon) override
    {
        summons.Summon(summon);
        switch (summon->GetEntry())
        {
            case NPC_FLEETING_SPIRIT:
                summon->AI()->DoZoneInCombat();
                // NOTE: the source added the fixate threat to the boss instead of the spirit.
                if (Unit* target = SelectTarget(SelectTargetMethod::MaxDistance, 0, 100.0f, true))
                {
                    summon->AddThreat(target, 100.0f);
                    summon->AI()->AttackStart(target);
                }
                break;
            case NPC_ROOT_OF_EXTINCTION:
                summon->SetReactState(REACT_PASSIVE);
                summon->SetCanFly(true);
                summon->SetDisableGravity(true);
                summon->SetUnitFlag(UnitFlags(UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE));
                break;
            case NPC_SEED_OF_EXTINCTION:
            {
                summon->SetFaction(35);
                summon->SetNpcFlag(UNIT_NPC_FLAG_SPELLCLICK);
                summon->CastSpell(nullptr, SPELL_ROOT_OF_EXTINCTION_CREATE_AT, false);
                ObjectGuid seedGuid = summon->GetGUID();
                scheduler.Schedule(18100ms, [this, seedGuid](TaskContext /*context*/)
                {
                    Creature* seed = ObjectAccessor::GetCreature(*me, seedGuid);
                    if (!seed)
                        return;

                    seed->CastSpell(nullptr, SPELL_SEED_OF_EXTINCTION_EXP, true);
                    seed->DespawnOrUnsummon();
                });
                break;
            }
            case NPC_EDGE_OF_ANNIHILATION:
                // NOTE: the source or'ed UNIT_STATE_UNATTACKABLE (a UnitState) into UnitFlags;
                // replaced with the intended UNIT_FLAG_NON_ATTACKABLE.
                summon->SetUnitFlag(UnitFlags(UNIT_FLAG_IMMUNE_TO_NPC | UNIT_FLAG_NON_ATTACKABLE));
                summon->SetReactState(REACT_PASSIVE);
                summon->AddAura(SPELL_EDGE_OF_ANNIHILATION_VISUAL, summon);
                ForEachPlayerInRoom([summon](Player* player)
                {
                    summon->CastSpell(player, SPELL_AURA_OF_DREAD, true);
                });
                break;
            default:
                break;
        }
    }

    void KilledUnit(Unit* victim) override
    {
        if (victim->IsPlayer())
            Talk(urand(SAY_SLAY, SAY_SLAY_2));
    }

    void JustDied(Unit* /*killer*/) override
    {
        Talk(SAY_DEATH);
        me->RemoveAllDynObjects();
        instance->DoRemoveAurasDueToSpellOnPlayers(SPELL_AURA_OF_DREAD);
        summons.DespawnAll();
        _JustDied();
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        me->RemoveAllDynObjects();
        summons.DespawnAll();
        // Source used _DespawnAtEvade(); AC 3.3.5 BossAI resets in place instead.
        BossAI::EnterEvadeMode(why);
    }

private:
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

    bool _stageTwo;
    bool _stageThree;
};

// 169267 - Root of Extinction
struct npc_root_of_extinction : public ScriptedAI
{
    npc_root_of_extinction(Creature* creature) : ScriptedAI(creature)
    {
        SetCombatMovement(false);
    }

    void Reset() override
    {
        me->CastSpell(nullptr, SPELL_ROOT_OF_EXTINCTION_VISUAL, true);
    }
};

// 168317 - Fleeting Spirit
struct npc_fleeting_spirit : public ScriptedAI
{
    npc_fleeting_spirit(Creature* creature) : ScriptedAI(creature) { }

    // Fixates on the farthest player (threat set by the summoner) and possesses whoever it
    // catches. NOTE: the source's range check was inverted (it "possessed" every player farther
    // than 5 yd on sight); ported as on-reach, per the source's own design comment
    // ("fixate on random, on reach 327414, remove on 50% hp").
    // TODO(port): the "remove possession at 50% spirit health" part is not implemented.
    void MoveInLineOfSight(Unit* who) override
    {
        if (!who->IsPlayer() || !me->IsWithinDist2d(who, 5.0f) || who->HasAura(SPELL_POSSESION))
            return;

        me->AddAura(SPELL_POSSESION, who);
    }
};
}

void AddSC_boss_artificer_xymox()
{
    using namespace CastleNathria;
    using namespace CastleNathria::ArtificerXymox;
    RegisterCastleNathriaCreatureAI(boss_artificer_xymox);
    RegisterCastleNathriaCreatureAI(npc_root_of_extinction);
    RegisterCastleNathriaCreatureAI(npc_fleeting_spirit);
    // TODO(port): shadowcore's at_stasis_trap AreaTriggerAI has no 3.3.5 equivalent -- the trap
    // is substituted with the NPC_STASIS_TRAP trigger creature above. Author
    // SPELL_STASIS_TRAP_CREATE_AT's spell_dbc downport as a persistent-area aura triggering
    // SPELL_STASIS_TRAP_STUN to restore the stun zone.
}
