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

// DarkChaos downport of Castle Nathria: Council of Blood (map 2296).
// Ported from the ShadowCore (TC 9.x) implementation and adapted to AzerothCore
// 3.3.5a idioms. One shared encounter (DATA_COUNCIL_OF_BLOOD) across the three
// co-bosses Baroness Frieda (166969), Castellan Niklaus (166971) and Lord
// Stavros (166970); the encounter only completes once all three are dead.
// The Shadowlands spell ids used here all have authored Spell.dbc rows (verified
// 2026-08-30 against the live 54221-record Spell.dbc). AreaTrigger-driven mechanics
// are re-expressed with 3.3.5 constructs or stubbed with TODO(port) notes.

#include "InstanceScript.h"
#include "Map.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellInfo.h"
#include "castle_nathria.h"

namespace CastleNathria::CouncilOfBlood
{
enum Spells
{
    // Shared
    SPELL_DANSE_MACABRE_MOD_DAMAGE_TAKEN    = 330959,   // unused, see StartDanseMacabre()
    SPELL_DANSE_MACABRE_DUMMY               = 328497,   // unused, see StartDanseMacabre()
    SPELL_DANSE_MACABRE_CREATE_AT           = 328485,   // AreaTrigger creator, unused on 3.3.5
    SPELL_DANSE_MACABRE_AURA                = 328495,   // unused, see StartDanseMacabre()
    SPELL_DANSE_MACABRE_CREATE_AT_TWO       = 344181,   // AreaTrigger creator, unused on 3.3.5
    SPELL_OPRESSIVE_ATMOSPHERE              = 334909,
    SPELL_BERSERK                           = 26662,    // real 3.3.5 spell

    // Baroness Frieda
    SPELL_DREADBOLT_VOLLEY                  = 337110,
    SPELL_DRAIN_ESSENCE_CHANNEL             = 346654,
    SPELL_DRAIN_ESSENCE_PERIODIC_DAMAGE     = 346651,
    SPELL_DRAIN_ESSENCE_MOD_HEALTH          = 327773,
    SPELL_PRIDEFUL_ERUPTION_CAST            = 346657,
    SPELL_PRIDEFUL_ERUPTION_MISSILE         = 346661,
    SPELL_PRIDEFUL_ERUPTION_DAMAGE          = 346660,
    SPELL_SOUL_SPIKES_DEBUFF                = 346681,
    SPELL_SOUL_SPIKES_PERIODIC_DUMMY        = 346762,
    SPELL_SOUL_SPIKES_DAMAGE                = 346685,

    // Castellan Niklaus
    SPELL_DUELIST_RISPOSE                   = 346690,
    SPELL_UNDYING_SHIELD                    = 346694,
    SPELL_DREDGER_SERVANT                   = 330978,   // unused, summon done directly
    SPELL_THROW_FOOD                        = 330968,   // unused (Begrudging Waiter ability)
    SPELL_CASTELLANS_CADRE                  = 330965,   // unused, summon done directly

    // Lord Stavros
    SPELL_EVASIVE_LUNGE_DAMAGE              = 327610,
    SPELL_EVASIVE_LUNGE_TELEPORT            = 327497,   // SPELL_EFFECT_CHARGE to the target
    SPELL_DARK_RECITAL                      = 331634,
    SPELL_DARK_RECITAL_TRIGGER              = 334741,
    SPELL_WALTZ_OF_BLOOD_STUN               = 327619,   // unused (Waltz of Blood not ported)
    SPELL_DANCING_FOOLS                     = 330964,   // unused (Dancing Fools not ported)
    SPELL_VIOLENT_UPROAR                    = 346303,   // unused (Danger Fools enrage)

    // Heroic (retail Heroic+)
    SPELL_MANIFEST_PAIN_CREATE_AT           = 346944,   // ground zone: persistent area aura ticking 346945
    SPELL_MANIFEST_PAIN_AT_DAMAGE           = 346945,
    SPELL_TWISTED_PAIN                      = 346939,   // unused
    SPELL_TWISTED_PAIN_CREATE_AT            = 346937,   // AreaTrigger creator, unused
    SPELL_CASTELLANS_FURY                   = 346934,   // unused
    SPELL_TWO_LEFT_FEET                     = 346932,   // unused

    // Mythic (mapped to 3.3.5 heroic)
    SPELL_DANCING_FEVER_AURA                = 347350
};

enum Texts
{
    // Baroness Frieda (166969) - 09_creature_text.sql GroupIDs
    SAY_FRIEDA_DANSE            = 0,    // "Dear guests and vile intruders, take your places for the dance macabre!"
    SAY_FRIEDA_SHIMMY_RIGHT     = 1,
    SAY_FRIEDA_SASHAY_LEFT      = 2,
    SAY_FRIEDA_PRANCE_FORWARD   = 3,
    SAY_FRIEDA_BOOGIE_DOWN      = 4,
    SAY_FRIEDA_DANSE_END        = 5,    // "Enough! Your gyrations sicken me."
    SAY_FRIEDA_DEATH            = 6,

    // Lord Stavros (166970)
    SAY_STAVROS_AGGRO           = 0,    // "How dare you invade my party in such dreadful attire!"
    // GroupIDs 1-8 are reserved: Waltz of Blood partners (1), Dancing Fools (2) and Stavros'
    // own danse-macabre call-outs (3-8) - those mechanics are not ported (Frieda conducts
    // the simplified intermission), the DB rows stay available for a later fidelity pass.
    SAY_STAVROS_DEATH           = 9,

    // Castellan Niklaus (166971)
    SAY_NIKLAUS_DEATH           = 0
};

enum Events
{
    // Shared
    EVENT_BERSERK = 1,

    // Baroness Frieda
    EVENT_OPPRESSIVE_ATMOSPHERE,
    EVENT_DREADBOLT_VOLLEY,
    EVENT_DRAIN_ESSENCE,
    EVENT_DANSE_MACABRE,
    EVENT_DANCING_FEVER,
    EVENT_PRIDEFUL_ERUPTION,
    EVENT_SOUL_SPIKES,

    // Castellan Niklaus
    EVENT_DUELIST_RIPOSTE,
    EVENT_UNDYING_SHIELD,

    // Lord Stavros
    EVENT_EVASIVE_LUNGE,
    EVENT_DARK_RECITAL
};

enum Actions
{
    // Frieda empowerments (granted when a co-boss dies)
    ACTION_PRIDEFUL_ERUPTION    = 1,
    ACTION_SOUL_SPIKES          = 2,
    // Niklaus empowerments
    ACTION_DREDGER_SERVANT      = 3,
    ACTION_CASTELLANS_CADRE     = 4
};

uint32 const CouncilEntries[3] = { NPC_BARONESS_FRIEDA, NPC_CASTELLAN_NIKLAUS, NPC_LORD_STAVROS };
uint32 const AfterimageEntries[3] = { NPC_AFTERIMAGE_OF_BARONESS_FRIEDA, NPC_AFTERIMAGE_OF_CASTELLAN_NIKLAUS, NPC_AFTERIMAGE_OF_LORD_STAVROS };

// 166969, 166971, 166970 - one script bound to all three lords (ScriptName boss_council_of_blood)
struct boss_council_of_blood : public BossAI
{
    boss_council_of_blood(Creature* creature) : BossAI(creature, DATA_COUNCIL_OF_BLOOD), _danceActive(false) { }

    void Reset() override
    {
        _Reset();
        scheduler.CancelAll();
        _danceActive = false;
        me->setPowerType(POWER_ENERGY);
        me->SetMaxPower(POWER_ENERGY, 100);
        me->SetPower(POWER_ENERGY, 100);
        me->SetRegeneratingPower(false);
        me->SetReactState(REACT_AGGRESSIVE);
        // TODO(port): AURA_OVERRIDE_POWER_COLOR_DEMONIC (power bar recolor) has no 3.3.5 equivalent.
    }

    Creature* GetOtherLord(uint32 entry, bool alive = true) const
    {
        return me->FindNearestCreature(entry, 150.0f, alive);
    }

    // Counts dead council members, treating ourselves as dead (call from JustDied only).
    uint8 CountDeadLords() const
    {
        uint8 dead = 0;
        for (uint32 entry : CouncilEntries)
        {
            if (entry == me->GetEntry())
                ++dead;
            else if (!GetOtherLord(entry, true))
                ++dead;
        }
        return dead;
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        _JustEngagedWith();

        // The council always fights as one - pull the other two lords.
        for (uint32 entry : CouncilEntries)
            if (entry != me->GetEntry())
                if (Creature* lord = GetOtherLord(entry, true))
                    if (!lord->IsInCombat())
                        DoZoneInCombat(lord);

        events.ScheduleEvent(EVENT_BERSERK, 10min);

        switch (me->GetEntry())
        {
            case NPC_BARONESS_FRIEDA:
                events.ScheduleEvent(EVENT_OPPRESSIVE_ATMOSPHERE, 1s);
                events.ScheduleEvent(EVENT_DREADBOLT_VOLLEY, 5s);
                events.ScheduleEvent(EVENT_DRAIN_ESSENCE, 12s);
                events.ScheduleEvent(EVENT_DANSE_MACABRE, 30s);
                if (IsHeroic()) // TODO(port): Mythic-only on retail; 3.3.5 heroic is the nearest difficulty
                    events.ScheduleEvent(EVENT_DANCING_FEVER, 6s);
                break;
            case NPC_CASTELLAN_NIKLAUS:
                events.ScheduleEvent(EVENT_DUELIST_RIPOSTE, 5s);
                events.ScheduleEvent(EVENT_UNDYING_SHIELD, 6s);
                break;
            case NPC_LORD_STAVROS:
                Talk(SAY_STAVROS_AGGRO);
                events.ScheduleEvent(EVENT_EVASIVE_LUNGE, 5s);
                events.ScheduleEvent(EVENT_DARK_RECITAL, 22s);
                break;
            default:
                break;
        }
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_BERSERK:
                DoCastSelf(SPELL_BERSERK, true);
                break;
            case EVENT_OPPRESSIVE_ATMOSPHERE:
                ForEachPlayerInRoom([this](Player* player)
                {
                    me->AddAura(SPELL_OPRESSIVE_ATMOSPHERE, player);
                });
                events.Repeat(10s);
                break;
            case EVENT_DREADBOLT_VOLLEY:
                DoCastRandomTarget(SPELL_DREADBOLT_VOLLEY, 0, 100.0f, true, false);
                events.Repeat(20s);
                break;
            case EVENT_DRAIN_ESSENCE:
                if (Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 100.0f, true))
                {
                    me->CastSpell(target, SPELL_DRAIN_ESSENCE_CHANNEL);
                    me->AddAura(SPELL_DRAIN_ESSENCE_PERIODIC_DAMAGE, target);
                    me->AddAura(SPELL_DRAIN_ESSENCE_MOD_HEALTH, target);
                }
                events.Repeat(30s);
                break;
            case EVENT_DANSE_MACABRE:
                StartDanseMacabre();
                events.Repeat(60s);
                break;
            case EVENT_DANCING_FEVER:
            {
                std::list<Unit*> targets;
                SelectTargetList(targets, 5, SelectTargetMethod::Random, 0, 150.0f, true);
                for (Unit* target : targets)
                {
                    me->AddAura(SPELL_DANCING_FEVER_AURA, target);
                    if (Aura* fever = target->GetAura(SPELL_DANCING_FEVER_AURA))
                        fever->SetStackAmount(3);
                }
                events.Repeat(35s);
                break;
            }
            case EVENT_PRIDEFUL_ERUPTION:
                DoCastAOE(SPELL_PRIDEFUL_ERUPTION_CAST);
                // TODO(port): source cores fire the eruption from an OnSpellFinished hook; the
                // 3.3.5 CreatureAI has no such hook, so the impact is scheduled off the cast start.
                scheduler.Schedule(3s, [this](TaskContext /*context*/)
                {
                    ForEachPlayerInRoom([this](Player* player)
                    {
                        me->CastSpell(player, SPELL_PRIDEFUL_ERUPTION_MISSILE, TRIGGERED_FULL_MASK);
                        me->CastSpell(player, SPELL_PRIDEFUL_ERUPTION_DAMAGE, TRIGGERED_FULL_MASK);
                    });
                });
                events.Repeat(35s);
                break;
            case EVENT_SOUL_SPIKES:
                if (Unit* target = SelectTarget(SelectTargetMethod::MaxThreat, 0, 100.0f, true))
                {
                    me->CastSpell(target, SPELL_SOUL_SPIKES_PERIODIC_DUMMY);
                    me->CastSpell(target, SPELL_SOUL_SPIKES_DAMAGE, TRIGGERED_FULL_MASK);
                    me->CastSpell(target, SPELL_SOUL_SPIKES_DEBUFF, TRIGGERED_FULL_MASK);
                }
                events.Repeat(40s);
                break;
            case EVENT_DUELIST_RIPOSTE:
                DoCastVictim(SPELL_DUELIST_RISPOSE);
                events.Repeat(20s);
                break;
            case EVENT_UNDYING_SHIELD:
                if (Creature* attendant = me->SummonCreature(NPC_DUTIFUL_ATTENDANT, me->GetRandomNearPosition(30.0f), TEMPSUMMON_MANUAL_DESPAWN))
                    me->CastSpell(attendant, SPELL_UNDYING_SHIELD);
                events.Repeat(30s);
                break;
            case EVENT_EVASIVE_LUNGE:
                if (Unit* target = SelectTarget(SelectTargetMethod::MaxThreat, 0, 100.0f, true))
                {
                    me->CastSpell(target, SPELL_EVASIVE_LUNGE_TELEPORT);
                    me->CastSpell(target, SPELL_EVASIVE_LUNGE_DAMAGE, TRIGGERED_FULL_MASK);
                }
                events.Repeat(20s);
                break;
            case EVENT_DARK_RECITAL:
                DoCastAOE(SPELL_DARK_RECITAL);
                // TODO(port): OnSpellFinished substitute, see EVENT_PRIDEFUL_ERUPTION.
                scheduler.Schedule(3s, [this](TaskContext /*context*/)
                {
                    ForEachPlayerInRoom([this](Player* player)
                    {
                        me->CastSpell(player, SPELL_DARK_RECITAL_TRIGGER, TRIGGERED_FULL_MASK);
                    });
                });
                events.Repeat(30s);
                break;
            default:
                break;
        }
    }

    // Simplified Danse Macabre intermission.
    // TODO(port): retail spawns NPC_DANCE_CONTROLLER (168870) plus Waltzing Venthyr/Danger Fools
    // (176016/176026) and drives a follow-the-pattern dance floor through AreaTriggers
    // (SPELL_DANSE_MACABRE_CREATE_AT*). 3.3.5 has no AreaTrigger runtime, so the intermission is
    // reduced to a forced dance: players are rooted with a dance emote-state while Frieda calls the
    // steps, and the council itself stops fighting to dance along.
    void StartDanseMacabre()
    {
        Talk(SAY_FRIEDA_DANSE);
        _danceActive = true;
        SetPlayersDancing(true);
        SetCouncilDancing(true);

        static constexpr uint8 danceSteps[4] = { SAY_FRIEDA_SHIMMY_RIGHT, SAY_FRIEDA_SASHAY_LEFT, SAY_FRIEDA_PRANCE_FORWARD, SAY_FRIEDA_BOOGIE_DOWN };
        for (uint8 i = 0; i < 4; ++i)
        {
            scheduler.Schedule(Seconds(3 * (i + 1)), [this, i](TaskContext /*context*/)
            {
                Talk(danceSteps[i]);
            });
        }

        scheduler.Schedule(15s, [this](TaskContext /*context*/)
        {
            Talk(SAY_FRIEDA_DANSE_END);
            EndDanseMacabre();
        });
    }

    void EndDanseMacabre()
    {
        if (!_danceActive)
            return;
        _danceActive = false;
        SetPlayersDancing(false);
        SetCouncilDancing(false);
    }

    void SetPlayersDancing(bool apply)
    {
        ForEachPlayerInRoom([apply](Player* player)
        {
            if (apply)
            {
                player->SetControlled(true, UNIT_STATE_ROOT);
                player->SetEmoteState(EMOTE_STATE_DANCE);
            }
            else if (player->GetUInt32Value(UNIT_NPC_EMOTESTATE) == EMOTE_STATE_DANCE)
            {
                player->ClearEmoteState();
                player->SetControlled(false, UNIT_STATE_ROOT);
            }
        });
    }

    void SetCouncilDancing(bool apply)
    {
        for (uint32 entry : CouncilEntries)
        {
            Creature* lord = entry == me->GetEntry() ? me : GetOtherLord(entry, true);
            if (!lord || !lord->IsAlive())
                continue;
            if (apply)
            {
                lord->AttackStop();
                lord->SetReactState(REACT_PASSIVE);
                lord->SetEmoteState(EMOTE_STATE_DANCE);
            }
            else
            {
                lord->ClearEmoteState();
                lord->SetReactState(REACT_AGGRESSIVE);
            }
        }
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
            if (me->IsWithinDistInMap(player, 150.0f))
                worker(player);
        }
    }

    void SpellHitTarget(Unit* target, SpellInfo const* spellInfo) override
    {
        // Retail Heroic+ Manifest Pain (source checked IsHeroic/IsMythic).
        if (!IsHeroic() || me->GetEntry() != NPC_BARONESS_FRIEDA || !target)
            return;

        switch (spellInfo->Id)
        {
            case SPELL_DREADBOLT_VOLLEY:
            case SPELL_DRAIN_ESSENCE_PERIODIC_DAMAGE:
            case SPELL_PRIDEFUL_ERUPTION_DAMAGE:
                // TODO(port): creates a Manifest Pain AreaTrigger zone on retail; without an AT
                // runtime the ground effect does not persist (cast kept for later spell_dbc work).
                me->CastSpell(target->GetPositionX(), target->GetPositionY(), target->GetPositionZ(), SPELL_MANIFEST_PAIN_CREATE_AT, true);
                break;
            default:
                break;
        }
    }

    void DoAction(int32 action) override
    {
        switch (action)
        {
            case ACTION_PRIDEFUL_ERUPTION:
                events.RescheduleEvent(EVENT_PRIDEFUL_ERUPTION, 3s);
                break;
            case ACTION_SOUL_SPIKES:
                events.RescheduleEvent(EVENT_SOUL_SPIKES, 3s);
                break;
            case ACTION_DREDGER_SERVANT:
                me->SummonCreature(NPC_BEGRUDGING_WAITER, me->GetRandomNearPosition(30.0f), TEMPSUMMON_MANUAL_DESPAWN);
                break;
            case ACTION_CASTELLANS_CADRE:
                me->SummonCreature(NPC_VETERAN_STONEGUARD, me->GetRandomNearPosition(30.0f), TEMPSUMMON_MANUAL_DESPAWN);
                break;
            default:
                break;
        }
    }

    void KilledUnit(Unit* victim) override
    {
        if (!victim->IsPlayer() || !_danceActive)
            return;
        // A rooted dancer died - nothing extra, root/emote clear on death.
    }

    void JustDied(Unit* /*killer*/) override
    {
        scheduler.CancelAll();
        EndDanseMacabre();

        switch (me->GetEntry())
        {
            case NPC_BARONESS_FRIEDA:
                Talk(SAY_FRIEDA_DEATH);
                break;
            case NPC_CASTELLAN_NIKLAUS:
                Talk(SAY_NIKLAUS_DEATH);
                break;
            case NPC_LORD_STAVROS:
                Talk(SAY_STAVROS_DEATH);
                break;
            default:
                break;
        }

        summons.DespawnAll();

        uint8 const deadLords = CountDeadLords();
        if (deadLords >= 3)
        {
            // Last lord down - now (and only now) the encounter completes.
            DespawnAfterimages();
            _JustDied();
            return;
        }

        // A co-boss fell: spawn its afterimage (retail Mythic; 3.3.5 heroic is the nearest
        // difficulty - TODO(port)) and empower/refresh the survivors.
        if (IsHeroic())
            me->SummonCreature(AfterimageEntryFor(me->GetEntry()), me->GetPosition(), TEMPSUMMON_MANUAL_DESPAWN);

        for (uint32 entry : CouncilEntries)
            if (entry != me->GetEntry())
                if (Creature* lord = GetOtherLord(entry, true))
                    lord->SetFullHealth();

        if (Creature* frieda = GetOtherLord(NPC_BARONESS_FRIEDA, true))
        {
            frieda->AI()->DoAction(ACTION_PRIDEFUL_ERUPTION);
            if (deadLords == 2)
                frieda->AI()->DoAction(ACTION_SOUL_SPIKES);
        }

        if (Creature* niklaus = GetOtherLord(NPC_CASTELLAN_NIKLAUS, true))
        {
            niklaus->AI()->DoAction(ACTION_DREDGER_SERVANT);
            if (deadLords == 2)
                niklaus->AI()->DoAction(ACTION_CASTELLANS_CADRE);
        }
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        scheduler.CancelAll();
        EndDanseMacabre();
        DespawnAfterimages();

        for (uint32 entry : CouncilEntries)
        {
            if (entry == me->GetEntry())
                continue;
            if (Creature* lord = GetOtherLord(entry, true))
            {
                if (lord->IsInCombat() && !lord->IsInEvadeMode())
                    lord->AI()->EnterEvadeMode(why);
            }
            else if (Creature* corpse = GetOtherLord(entry, false))
                corpse->DespawnOrUnsummon(0ms, 30s); // fallen lords return for the next attempt
        }

        summons.DespawnAll();
        BossAI::EnterEvadeMode(why);
    }

private:
    static uint32 AfterimageEntryFor(uint32 lordEntry)
    {
        switch (lordEntry)
        {
            case NPC_BARONESS_FRIEDA:
                return NPC_AFTERIMAGE_OF_BARONESS_FRIEDA;
            case NPC_CASTELLAN_NIKLAUS:
                return NPC_AFTERIMAGE_OF_CASTELLAN_NIKLAUS;
            case NPC_LORD_STAVROS:
                return NPC_AFTERIMAGE_OF_LORD_STAVROS;
            default:
                return 0;
        }
    }

    void DespawnAfterimages()
    {
        for (uint32 entry : AfterimageEntries)
            if (Creature* image = me->FindNearestCreature(entry, 200.0f, true))
                image->DespawnOrUnsummon();
    }

    bool _danceActive;
};

// 172803, 172993, 173053 - Mythic afterimages of the fallen lords (ScriptName npc_afterimage)
struct npc_afterimage : public ScriptedAI
{
    npc_afterimage(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(WorldObject* /*summoner*/) override
    {
        DoZoneInCombat();

        switch (me->GetEntry())
        {
            case NPC_AFTERIMAGE_OF_BARONESS_FRIEDA:
                scheduler.Schedule(2s, [this](TaskContext context)
                {
                    DoCastRandomTarget(SPELL_DREADBOLT_VOLLEY, 0, 100.0f, true, false);
                    context.Repeat(20s);
                });
                break;
            case NPC_AFTERIMAGE_OF_CASTELLAN_NIKLAUS:
                scheduler.Schedule(2s, [this](TaskContext context)
                {
                    if (Creature* attendant = me->SummonCreature(NPC_DUTIFUL_ATTENDANT, me->GetRandomNearPosition(30.0f), TEMPSUMMON_MANUAL_DESPAWN))
                        me->CastSpell(attendant, SPELL_UNDYING_SHIELD);
                    context.Repeat(30s);
                });
                break;
            case NPC_AFTERIMAGE_OF_LORD_STAVROS:
                scheduler.Schedule(2s, [this](TaskContext context)
                {
                    DoCastAOE(SPELL_DARK_RECITAL);
                    context.Repeat(30s);
                });
                break;
            default:
                break;
        }
    }

    void UpdateAI(uint32 diff) override
    {
        scheduler.Update(diff);

        if (!UpdateVictim())
            return;

        DoMeleeAttackIfReady();
    }
};
}

void AddSC_boss_council_of_blood()
{
    using namespace CastleNathria::CouncilOfBlood;
    RegisterCastleNathriaCreatureAI(boss_council_of_blood);
    RegisterCastleNathriaCreatureAI(npc_afterimage);
}
