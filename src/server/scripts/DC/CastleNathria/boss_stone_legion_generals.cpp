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

// DarkChaos downport of the Stone Legion Generals, ninth encounter of Castle Nathria
// (Shadowlands raid, map 2296). Ported from ShadowCore (TrinityCore 9.x) to AzerothCore
// 3.3.5a idioms -- see DC/BlackwingDescent/PORT_NOTES.md for the API divergence log.
//
// One shared encounter (DATA_STONE_LEGION_GENERALS) across both generals -- Kaal (168112)
// fights on the ground while Grashaal (168113) bombards from the air. At 50% health a general
// locks into Hardened Stoneform; Prince Renathal (172652, friendly) charges anima and shatters
// the form with Shattering Blast, which swaps the generals' roles (the alternation): phase two
// puts Grashaal on the front line with Kaal raining blades from behind, phase three swaps back.
// The encounter completes only when BOTH generals are dead (source completed it on the first
// death -- fixed here, Council-of-Blood style).
//
// 3.3.5 substitutions:
// - at_anima_orb (dead Commandos dropped anima orbs players walked over to charge Renathal):
//   no AreaTrigger runtime, so a Commando death charges Renathal with 40 anima directly.
//   TODO(port): restore the walk-over pickup once ground-object mechanics exist.
// - The source required BOTH generals stoneformed at once before Renathal would blast
//   (unreachable -- they stoneform at their own 50%); Renathal now blasts whichever general
//   is currently locked, Kaal first.
// - Reverberating Eruption relied on a summon spell to spawn the Reverberation Stalker
//   (175102); the stalker is summoned directly (its template is not yet in the DC DB --
//   the summon degrades to a no-op until it is authored).
// - Grashaal's "flying" opener uses SetCanFly/SetDisableGravity; he drops to the floor via
//   MoveFall when phase two puts him on the front line.

#include "InstanceScript.h"
#include "Map.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellInfo.h"
#include "castle_nathria.h"

namespace CastleNathria::StoneLegionGenerals
{
enum Spells
{
    // General Grashaal
    SPELL_STONE_SPIKE_MISSILE                   = 170926,   // TODO(spell_dbc): needs downport row
    SPELL_STONE_BREAKERS_COMBO                  = 339645,   // TODO(spell_dbc): unused, combo done via channel + burst
    SPELL_CRYSTALIZE_CHANNEL                    = 339690,   // TODO(spell_dbc): needs downport row
    SPELL_CRYSTALLINE_BURST_DAMAGE              = 339693,   // TODO(spell_dbc): needs downport row
    SPELL_PULVERIZING_METEOR_MISSILE            = 342544,   // TODO(spell_dbc): needs downport row
    SPELL_STONE_FIST                            = 342425,   // TODO(spell_dbc): needs downport row
    SPELL_SEISMIC_UPHEAVAL_MISSILE              = 337595,   // TODO(spell_dbc): needs downport row
    SPELL_REVERBERATING_ERUPTION_MARK           = 344496,   // TODO(spell_dbc): needs downport row
    SPELL_REVERBERATING_ERUPTION_DAMAGE_SUMMON  = 344500,   // TODO(spell_dbc): summon spell; stalker summoned directly

    // General Kaal
    SPELL_SERRATED_SWIPE                        = 334929,   // TODO(spell_dbc): needs downport row
    SPELL_HEART_REND                            = 334765,   // TODO(spell_dbc): needs downport row
    SPELL_HEART_HEMORRAGE                       = 334771,   // TODO(spell_dbc): unused, triggers from rend on dispel/expire
    SPELL_WICKED_BLADE                          = 333387,   // TODO(spell_dbc): needs downport row
    SPELL_HARDENED_STONEFORM                    = 329636,   // TODO(spell_dbc): needs downport row
    SPELL_ANIMA_ORB_CREATE_AT                   = 332393,   // TODO(spell_dbc): AreaTrigger creator, kept for later authoring
    SPELL_RICOCHETING_SHURIKEN                  = 343086,   // TODO(spell_dbc): needs downport row

    // Prince Renathal
    SPELL_SHATTERING_BLAST                      = 332683,   // TODO(spell_dbc): needs downport row

    // Reverberation Stalker
    SPELL_UNSTABLE_GROUND_APPLY_AT              = 344503,   // TODO(spell_dbc): AreaTrigger creator (author as persistent-area-aura)
    SPELL_ECHOING_ANNIHILATION                  = 344721,   // TODO(spell_dbc): needs downport row
    SPELL_REVERBERATING_VULNERABILITY           = 344655,   // TODO(spell_dbc): needs downport row
    SPELL_ECHOING_BLAST                         = 344740,   // TODO(spell_dbc): unused in source too
    SPELL_SOLDIERS_OATH                         = 336212    // TODO(spell_dbc): needs downport row
};

enum Events
{
    EVENT_STONEFORM_ADDS = 1
    // The remaining events reuse their spell ids, as in the source.
};

enum Actions
{
    // Renathal (internal)
    ACTION_BLAST_KAAL       = 1,
    ACTION_BLAST_GRASHAAL   = 2,
    // Generals (role swap; source values 2/3 renumbered behind the Renathal actions)
    ACTION_PHASE_TWO        = 3,
    ACTION_PHASE_THREE      = 4
};

enum Texts
{
    // creature_text GroupIDs (Custom/.../worlddb/CastleNathria/09_creature_text.sql).
    // The source AI had no Talk() calls; these hook the DB lines to their abilities.

    // General Kaal (168112)
    SAY_KAAL_AGGRO              = 0,    // "Tear you asunder!"
    SAY_KAAL_WICKED_BLADE       = 1,    // "No escape!"
    SAY_KAAL_HEART_REND         = 2,    // "Bleed!"
    SAY_KAAL_STONEFORM          = 3,    // "Flesh to stone!"
    SAY_KAAL_SHURIKEN           = 4,    // "My blade will find you!"
    // GroupID 5 ("I will not be broken!") reserved for a later fidelity pass.
    SAY_KAAL_SLAY               = 6,    // "Tremble in my shadow!"
    SAY_KAAL_PHASE_TWO          = 7,    // "Grashaal, shield yourself! It is time to rain terror from above!"
    SAY_KAAL_PHASE_THREE        = 8,    // "I will end you myself!"
    SAY_KAAL_DEATH              = 9,

    // General Grashaal (168113)
    SAY_GRASHAAL_ANNOUNCE_CRYSTALIZE = 0,   // raid announce (type 16)
    SAY_GRASHAAL_AGGRO          = 1,    // "General Kaal, Get cover! My soldiers will strike from the sky!"
    SAY_GRASHAAL_ENGAGE         = 2,    // "Die by my hand!" (phase two landing)
    SAY_GRASHAAL_STONE_FIST     = 3,    // "I will break you!"
    SAY_GRASHAAL_STONEFORM      = 4,    // "Your blades will break across my skin!"
    SAY_GRASHAAL_SEISMIC        = 5,    // "I will drive you into the ground!"
    SAY_GRASHAAL_PHASE_THREE    = 6,    // "I cannot be shattered!"
    SAY_GRASHAAL_DEATH          = 7
};

uint32 const GeneralEntries[2] = { NPC_GENERAL_KAAL, NPC_GENERAL_GRASHAAL };

// 168112 (General Kaal), 168113 (General Grashaal) - one script bound to both generals
// (ScriptName boss_stone_legion_generals)
struct boss_stone_legion_generals : public BossAI
{
    boss_stone_legion_generals(Creature* creature) : BossAI(creature, DATA_STONE_LEGION_GENERALS),
        _stoneformDone(false), _seismicCount(0) { }

    void Reset() override
    {
        _Reset();
        scheduler.CancelAll();
        _stoneformDone = false;
        _seismicCount = 0;
        me->SetReactState(REACT_DEFENSIVE);
        switch (me->GetEntry())
        {
            case NPC_GENERAL_GRASHAAL:
                // Opens the fight airborne, bombarding from above (source: CanFly + SetFlying).
                me->SetCanFly(true);
                me->SetDisableGravity(true);
                break;
            case NPC_GENERAL_KAAL:
                me->setPowerType(POWER_ENERGY);
                me->SetMaxPower(POWER_ENERGY, 100);
                me->SetPower(POWER_ENERGY, 0);
                me->SetRegeneratingPower(false);
                break;
            default:
                break;
        }
    }

    Creature* GetOtherGeneral(bool alive = true) const
    {
        uint32 const otherEntry = me->GetEntry() == NPC_GENERAL_KAAL ? NPC_GENERAL_GRASHAAL : NPC_GENERAL_KAAL;
        return me->FindNearestCreature(otherEntry, 200.0f, alive);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        _JustEngagedWith();

        // The generals fight as one encounter - pull the sibling too.
        if (Creature* other = GetOtherGeneral(true))
            if (!other->IsInCombat())
                DoZoneInCombat(other);

        switch (me->GetEntry())
        {
            case NPC_GENERAL_GRASHAAL:
                Talk(SAY_GRASHAAL_AGGRO);
                events.ScheduleEvent(SPELL_STONE_SPIKE_MISSILE, 5s);
                events.ScheduleEvent(SPELL_STONE_BREAKERS_COMBO, 30s);
                break;
            case NPC_GENERAL_KAAL:
                Talk(SAY_KAAL_AGGRO);
                events.ScheduleEvent(SPELL_SERRATED_SWIPE, 5s);
                events.ScheduleEvent(SPELL_HEART_REND, 10s);
                events.ScheduleEvent(SPELL_WICKED_BLADE, 15s);
                break;
            default:
                break;
        }
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case SPELL_STONE_SPIKE_MISSILE:
            {
                UnitList targetList;
                SelectTargetList(targetList, 5, SelectTargetMethod::Random, 0, 100.0f, true);
                for (Unit* target : targetList)
                    me->CastSpell(target, SPELL_STONE_SPIKE_MISSILE, true);
                events.Repeat(15s, 20s);
                break;
            }
            case SPELL_STONE_BREAKERS_COMBO:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                {
                    Talk(SAY_GRASHAAL_ANNOUNCE_CRYSTALIZE);
                    me->CastSpell(target, SPELL_CRYSTALIZE_CHANNEL, false);
                    ObjectGuid targetGuid = target->GetGUID();
                    scheduler.Schedule(5100ms, [this, targetGuid](TaskContext /*context*/)
                    {
                        Unit* target = ObjectAccessor::GetUnit(*me, targetGuid);
                        if (!target)
                            return;

                        me->CastSpell(target, SPELL_CRYSTALLINE_BURST_DAMAGE, true);
                        ForEachPlayerNear(target, 8.0f, [this](Player* player)
                        {
                            me->CastSpell(player, SPELL_CRYSTALLINE_BURST_DAMAGE, true);
                        });
                        me->CastSpell(target, SPELL_PULVERIZING_METEOR_MISSILE, false);
                    });
                }
                events.Repeat(60s);
                break;
            case SPELL_SERRATED_SWIPE:
                DoCastVictim(SPELL_SERRATED_SWIPE);
                events.Repeat(20s);
                break;
            case SPELL_HEART_REND:
            {
                Talk(SAY_KAAL_HEART_REND);
                me->CastSpell(me, SPELL_HEART_REND, false);
                UnitList targetList;
                SelectTargetList(targetList, 4, SelectTargetMethod::Random, 0, 100.0f, true);
                for (Unit* target : targetList)
                    me->AddAura(SPELL_HEART_REND, target);
                events.Repeat(25s);
                break;
            }
            case SPELL_WICKED_BLADE:
                Talk(SAY_KAAL_WICKED_BLADE);
                DoCastAOE(SPELL_WICKED_BLADE);
                events.Repeat(30s);
                break;
            case EVENT_STONEFORM_ADDS:
                me->SummonCreature(NPC_STONE_LEGION_GOLIATH_TWO, me->GetRandomNearPosition(25.0f), TEMPSUMMON_MANUAL_DESPAWN);
                for (uint8 i = 0; i < 3; ++i)
                    me->SummonCreature(NPC_STONE_LEGION_COMMANDO, me->GetRandomNearPosition(25.0f), TEMPSUMMON_MANUAL_DESPAWN);
                break;
            case SPELL_RICOCHETING_SHURIKEN:
                Talk(SAY_KAAL_SHURIKEN);
                DoCastRandomTarget(SPELL_RICOCHETING_SHURIKEN, 0, 100.0f, true, false);
                events.Repeat(15s);
                break;
            case SPELL_STONE_FIST:
                Talk(SAY_GRASHAAL_STONE_FIST);
                DoCastVictim(SPELL_STONE_FIST);
                events.Repeat(20s);
                break;
            case SPELL_SEISMIC_UPHEAVAL_MISSILE:
                Talk(SAY_GRASHAAL_SEISMIC);
                // Five 1s waves over the raid (source counted per player hit - per-wave was the intent).
                _seismicCount = 0;
                scheduler.Schedule(1s, [this](TaskContext context)
                {
                    ForEachPlayerNear(me, 100.0f, [this](Player* player)
                    {
                        me->CastSpell(player, SPELL_SEISMIC_UPHEAVAL_MISSILE, true);
                    });
                    if (++_seismicCount < 5)
                        context.Repeat(1s);
                });
                events.Repeat(30s);
                break;
            case SPELL_REVERBERATING_ERUPTION_MARK:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                {
                    Position const pos = target->GetPosition();
                    me->CastSpell(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ(),
                        SPELL_REVERBERATING_ERUPTION_MARK, false);
                    scheduler.Schedule(5100ms, [this, pos](TaskContext /*context*/)
                    {
                        me->CastSpell(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ(),
                            SPELL_REVERBERATING_ERUPTION_DAMAGE_SUMMON, true);
                        // TODO(port): source relied on the summon spell to spawn the stalker;
                        // summoned directly here. The 175102 template is not yet in the DC DB
                        // (05_creature_templates.sql), so this degrades to a no-op until authored.
                        Creature* stalker = me->SummonCreature(NPC_REVERBERATING_ERUPTION_STALKER, pos, TEMPSUMMON_TIMED_DESPAWN, 30000);
                        if (!stalker)
                            stalker = me->FindNearestCreature(NPC_REVERBERATING_ERUPTION_STALKER, 150.0f, true);
                        if (stalker)
                        {
                            stalker->RemoveAllAuras();
                            me->CastSpell(stalker->GetPositionX(), stalker->GetPositionY(), stalker->GetPositionZ(),
                                SPELL_ECHOING_ANNIHILATION, true);
                        }
                    });
                }
                events.Repeat(35s);
                break;
            default:
                break;
        }
    }

    void SpellHitTarget(Unit* target, SpellInfo const* spellInfo) override
    {
        if (me->GetEntry() != NPC_GENERAL_GRASHAAL || !target)
            return;

        switch (spellInfo->Id)
        {
            case SPELL_ECHOING_ANNIHILATION:
            case SPELL_REVERBERATING_ERUPTION_DAMAGE_SUMMON:
                me->AddAura(SPELL_REVERBERATING_VULNERABILITY, target);
                break;
            default:
                break;
        }
    }

    void SummonedCreatureDies(Creature* summon, Unit* /*killer*/) override
    {
        if (summon->GetEntry() != NPC_STONE_LEGION_COMMANDO)
            return;

        summon->CastSpell(summon, SPELL_ANIMA_ORB_CREATE_AT, true);
        // TODO(port): at_anima_orb let a player walk over the dropped orb to charge Renathal;
        // without an AreaTrigger runtime the anima is granted directly on the Commando's death.
        if (Creature* renathal = me->FindNearestCreature(NPC_PRINCE_RENATHAL_END, 200.0f, true))
            renathal->ModifyPower(POWER_MANA, 40);
    }

    void DamageTaken(Unit* /*attacker*/, uint32& /*damage*/, DamageEffectType /*damagetype*/, SpellSchoolMask /*damageSchoolMask*/) override
    {
        if (!me->HealthBelowPct(50) || _stoneformDone)
            return;

        _stoneformDone = true;
        Talk(me->GetEntry() == NPC_GENERAL_KAAL ? SAY_KAAL_STONEFORM : SAY_GRASHAAL_STONEFORM);
        DoCastSelf(SPELL_HARDENED_STONEFORM);
        events.ScheduleEvent(EVENT_STONEFORM_ADDS, 3s);
    }

    void DoAction(int32 action) override
    {
        switch (action)
        {
            case ACTION_PHASE_TWO:
                // Kaal's stoneform was shattered: he falls back to ranged blades while Grashaal
                // lands and takes the front line (the alternation swap).
                events.Reset();
                switch (me->GetEntry())
                {
                    case NPC_GENERAL_KAAL:
                        Talk(SAY_KAAL_PHASE_TWO);
                        events.ScheduleEvent(SPELL_WICKED_BLADE, 5s);
                        events.ScheduleEvent(SPELL_RICOCHETING_SHURIKEN, 10s);
                        break;
                    case NPC_GENERAL_GRASHAAL:
                        Talk(SAY_GRASHAAL_ENGAGE);
                        me->SetCanFly(false);
                        me->SetDisableGravity(false);
                        me->GetMotionMaster()->MoveFall();
                        me->SetReactState(REACT_AGGRESSIVE);
                        events.ScheduleEvent(SPELL_STONE_BREAKERS_COMBO, 5s);
                        events.ScheduleEvent(SPELL_STONE_FIST, 10s);
                        events.ScheduleEvent(SPELL_SEISMIC_UPHEAVAL_MISSILE, 15s);
                        events.ScheduleEvent(SPELL_REVERBERATING_ERUPTION_MARK, 20s);
                        break;
                    default:
                        break;
                }
                break;
            case ACTION_PHASE_THREE:
                // Grashaal's stoneform was shattered: Kaal returns to the front line.
                events.Reset();
                switch (me->GetEntry())
                {
                    case NPC_GENERAL_GRASHAAL:
                        Talk(SAY_GRASHAAL_PHASE_THREE);
                        events.ScheduleEvent(SPELL_STONE_SPIKE_MISSILE, 5s);
                        events.ScheduleEvent(SPELL_STONE_FIST, 10s);
                        events.ScheduleEvent(SPELL_STONE_BREAKERS_COMBO, 30s);
                        break;
                    case NPC_GENERAL_KAAL:
                        Talk(SAY_KAAL_PHASE_THREE);
                        events.ScheduleEvent(SPELL_SERRATED_SWIPE, 5s);
                        events.ScheduleEvent(SPELL_HEART_REND, 10s);
                        events.ScheduleEvent(SPELL_WICKED_BLADE, 15s);
                        break;
                    default:
                        break;
                }
                break;
            default:
                break;
        }
    }

    void KilledUnit(Unit* victim) override
    {
        if (victim->IsPlayer() && me->GetEntry() == NPC_GENERAL_KAAL)
            Talk(SAY_KAAL_SLAY);
    }

    void JustDied(Unit* /*killer*/) override
    {
        scheduler.CancelAll();
        Talk(me->GetEntry() == NPC_GENERAL_KAAL ? SAY_KAAL_DEATH : SAY_GRASHAAL_DEATH);
        summons.DespawnAll();

        if (Creature* other = GetOtherGeneral(true))
        {
            // NOTE(port): source completed the encounter on the first general's death; here the
            // survivor enrages (Soldier's Oath, as in source) and the encounter stays in progress.
            other->AddAura(SPELL_SOLDIERS_OATH, other);
            return;
        }

        _JustDied();
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        scheduler.CancelAll();

        if (Creature* other = GetOtherGeneral(true))
        {
            if (other->IsInCombat() && !other->IsInEvadeMode())
                other->AI()->EnterEvadeMode(why);
        }
        else if (Creature* corpse = GetOtherGeneral(false))
            corpse->DespawnOrUnsummon(0ms, 30s); // the fallen general returns for the next attempt

        summons.DespawnAll();
        me->RemoveAllDynObjects();
        // Source teleported home + _DespawnAtEvade(); AC 3.3.5 BossAI resets in place instead.
        BossAI::EnterEvadeMode(why);
    }

private:
    template <typename Worker>
    void ForEachPlayerNear(WorldObject* center, float range, Worker&& worker)
    {
        Map::PlayerList const& players = me->GetMap()->GetPlayers();
        for (auto const& ref : players)
        {
            Player* player = ref.GetSource();
            if (!player || !player->IsAlive() || player->IsGameMaster())
                continue;
            if (center->IsWithinDistInMap(player, range))
                worker(player);
        }
    }

    bool _stoneformDone;
    uint8 _seismicCount;
};

// 172652 - Prince Renathal (friendly; charges anima and shatters the generals' stoneforms)
struct npc_prince_renathal_stone_legion : public ScriptedAI
{
    npc_prince_renathal_stone_legion(Creature* creature) : ScriptedAI(creature),
        _instance(creature->GetInstanceScript()), _blastedKaal(false), _blastedGrashaal(false) { }

    void Reset() override
    {
        scheduler.CancelAll();
        _blastedKaal = false;
        _blastedGrashaal = false;
        me->setPowerType(POWER_MANA);
        me->SetMaxPower(POWER_MANA, 100);
        me->SetPower(POWER_MANA, 0);
        me->SetRegeneratingPower(false);
    }

    void DoAction(int32 action) override
    {
        switch (action)
        {
            case ACTION_BLAST_KAAL:
                ShatterGeneral(NPC_GENERAL_KAAL, ACTION_PHASE_TWO);
                break;
            case ACTION_BLAST_GRASHAAL:
                ShatterGeneral(NPC_GENERAL_GRASHAAL, ACTION_PHASE_THREE);
                break;
            default:
                break;
        }
    }

    void ShatterGeneral(uint32 entry, int32 phaseAction)
    {
        Creature* general = me->FindNearestCreature(entry, 180.0f, true);
        if (!general)
            return;

        me->CastSpell(general, SPELL_SHATTERING_BLAST, false);
        ObjectGuid generalGuid = general->GetGUID();
        scheduler.Schedule(5100ms, [this, generalGuid, phaseAction](TaskContext /*context*/)
        {
            if (Creature* general = ObjectAccessor::GetCreature(*me, generalGuid))
                general->RemoveAura(SPELL_HARDENED_STONEFORM);

            // NOTE(port): the shatter swaps BOTH generals' roles (source only re-kitted the
            // shattered one; its Grashaal ACTION_PHASE_TWO branch was unreachable).
            for (uint32 generalEntry : GeneralEntries)
                if (Creature* swapped = me->FindNearestCreature(generalEntry, 200.0f, true))
                    swapped->AI()->DoAction(phaseAction);
        });
    }

    void UpdateAI(uint32 diff) override
    {
        scheduler.Update(diff);

        if (!_instance)
            return;

        if (_instance->GetBossState(DATA_STONE_LEGION_GENERALS) != IN_PROGRESS)
        {
            // Wipe/reset: re-arm the blasts for the next attempt (Renathal never enters
            // combat himself, so his Reset() is not driven by the encounter).
            if (_blastedKaal || _blastedGrashaal)
                Reset();
            return;
        }

        if (me->GetPower(POWER_MANA) < 100)
            return;

        // Blast whichever general is currently locked in Hardened Stoneform, Kaal first
        // (source required both stoneformed at once, which never happens - fixed).
        if (!_blastedKaal)
        {
            if (Creature* kaal = me->FindNearestCreature(NPC_GENERAL_KAAL, 180.0f, true))
            {
                if (kaal->HasAura(SPELL_HARDENED_STONEFORM))
                {
                    me->SetPower(POWER_MANA, 0);
                    _blastedKaal = true;
                    DoAction(ACTION_BLAST_KAAL);
                    return;
                }
            }
        }

        if (!_blastedGrashaal)
        {
            if (Creature* grashaal = me->FindNearestCreature(NPC_GENERAL_GRASHAAL, 180.0f, true))
            {
                if (grashaal->HasAura(SPELL_HARDENED_STONEFORM))
                {
                    me->SetPower(POWER_MANA, 0);
                    _blastedGrashaal = true;
                    DoAction(ACTION_BLAST_GRASHAAL);
                }
            }
        }
    }

private:
    InstanceScript* _instance;
    bool _blastedKaal;
    bool _blastedGrashaal;
};

// 175102 - Reverberation Stalker (Reverberating Eruption ground hazard marker)
struct npc_reverberation_stalker : public ScriptedAI
{
    npc_reverberation_stalker(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        me->SetReactState(REACT_PASSIVE);
        // TODO(port): the AreaTrigger-creator aura is kept as a plain self-aura; author its
        // spell_dbc downport as a persistent-area-aura ground hazard.
        me->AddAura(SPELL_UNSTABLE_GROUND_APPLY_AT, me);
    }
};
}

void AddSC_boss_stone_legion_generals()
{
    using namespace CastleNathria::StoneLegionGenerals;
    RegisterCastleNathriaCreatureAI(boss_stone_legion_generals);
    RegisterCastleNathriaCreatureAI(npc_prince_renathal_stone_legion);
    RegisterCastleNathriaCreatureAI(npc_reverberation_stalker);
    // TODO(port): shadowcore's at_anima_orb AreaTriggerAI has no 3.3.5 equivalent; the anima
    // grant moved into boss_stone_legion_generals::SummonedCreatureDies (direct, no walk-over).
}
