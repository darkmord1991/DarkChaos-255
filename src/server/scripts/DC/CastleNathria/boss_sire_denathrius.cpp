/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
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

// DarkChaos downport of Sire Denathrius, final boss of Castle Nathria (map 2296).
// Ported from the ShadowCore (TrinityCore-9.x) implementation to AzerothCore 3.3.5a idioms.
//
// Substitutions versus the Shadowlands source (see PORT_NOTES.md of BlackwingDescent for the
// conversion catalogue this port follows):
//  * Spawned AreaTriggers (at_desolation / at_massacre_line / at_massacre / at_rancor) have no
//    3.3.5 equivalent. Desolation and Rancor ground zones are emulated with WORLD_TRIGGER
//    marker summons plus a 1 s pulse on Remornia's TaskScheduler that applies/removes the zone
//    aura. The Massacre blade sweep is emulated with a moving lethal point advanced on the boss
//    scheduler (60 yd over 6 s, matching the source AreaTrigger's SetDestination travel).
//  * Unit::GetScheduler() task chains became guid-captured tasks on the AI TaskScheduler.
//  * OnSpellFinished aftermaths (Ravage / Massacre / Sinister Reflection) are scheduler-driven
//    from the command cast instead; the SL command spells have no spell_dbc rows yet, so a
//    cast-completion hook would never fire.
//  * The March of the Penitent scene: players are walked to the chamber center under lost
//    control, then teleported down to the Sanctum floor (source relied on the scene movie).
//  * Remornia is a static spawn in the DC DB, so phase three retires her to her Crimson
//    Chamber perch instead of despawning her (source called DespawnOrUnsummon).
// All Shadowlands spell ids are kept verbatim and are inert until spell_dbc rows are authored.

#include "InstanceScript.h"
#include "Map.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellAuraEffects.h"
#include "SpellScript.h"
#include "castle_nathria.h"
#include <cmath>

namespace CastleNathria::SireDenathrius
{
enum Spells
{
    // Shared / phase one. All ids below are Shadowlands ids — TODO(spell_dbc) as a family.
    SPELL_OVERRIDE_POWER_COLOR_RAGE         = 299970, // shadowcore SharedDefines aura (red energy bar)
    SPELL_MARCH_OF_THE_PENITENT_SEND_EVENT  = 328117,
    SPELL_DESOLATION_CREATE_AT              = 327982, // source: "pizza" AreaTrigger
    SPELL_DESOLATION_AT_DAMAGE              = 327992,
    SPELL_MASSACRE_CREATE_LINE_AT           = 330116, // unused: line AT replaced by blade sweep
    SPELL_MASSACRE_CREATE_WEAPON_AT         = 330089, // unused: weapon AT replaced by blade sweep
    SPELL_COMMAND_RAVAGE                    = 327227,
    SPELL_RAVAGE_CAST_DUMMY                 = 327122,
    SPELL_INEVITABLE_DAMAGE                 = 328936, // kept for DB-authoring phase
    SPELL_INEVITABLE_TELEPORT               = 328934, // kept for DB-authoring phase
    SPELL_FEEDING_TIME_MARK                 = 327039,
    SPELL_FEEDING_TIME_DRAIN_HEALTH         = 327089,
    SPELL_FEEDING_TIME_SUMMON               = 327085, // unused: echoes summoned directly
    SPELL_BURDEN_OF_SIN_PERIODIC_DUMMY      = 326699,
    SPELL_BURDEN_OF_SIN_DAMAGE              = 326700,
    SPELL_CLEANSING_PAIN_ALLOW_CAST         = 327040,
    SPELL_CLEANSING_PAIN                    = 326707,
    SPELL_PAINFUL_MEMORIES_CHANNEL          = 326824,
    SPELL_PAINFUL_MEMORIES_DAMAGE           = 326833,
    SPELL_BLOOD_PRICE_CHANNEL               = 326994,
    SPELL_BLOOD_PRICE_DAMAGE                = 326858,
    SPELL_BLOOD_PRICE_IMMOBILIZE            = 326851,
    SPELL_BLOOD_PRICE_SUMMON                = 326857, // kept for DB-authoring phase
    SPELL_BLOOD_PRICE_KNOCKBACK             = 328527,
    SPELL_BLOOD_PRICE_KNOCKBACK_2           = 339188, // kept for DB-authoring phase
    SPELL_BLOOD_PRICE_EFFECT                = 326988,

    // Phase two
    SPELL_BLOODBOUND                        = 330580, // kept for DB-authoring phase
    SPELL_CRIMSON_CHORUS                    = 329711,
    SPELL_CRIMSON_CHORUS_PERIODIC_DAMAGE    = 329785, // kept for DB-authoring phase
    SPELL_WRACKING_PAIN_ALLOW_CAST          = 329183,
    SPELL_WRACKING_PAIN                     = 329181,
    SPELL_CARNAGE                           = 329875,
    SPELL_CARNAGE_PERIODIC                  = 329906,
    SPELL_IMPALE_MARK                       = 329951,
    SPELL_IMPALE_DAMAGE                     = 329974,
    SPELL_COMMAND_MASSACRE                  = 330042,
    SPELL_HAND_OF_DESTRUCTION_CAST          = 333932,
    SPELL_HAND_OF_DESTRUCTION_DAMAGE        = 330627,
    SPELL_DUSK_ELEGY                        = 335875, // kept for DB-authoring phase

    // Phase three
    SPELL_INDIGNATION                       = 326005,
    SPELL_INDIGNATION_CREATE_AT             = 332746,
    SPELL_SHATTERING_PAIN_ALLOW_CAST        = 333223,
    SPELL_SHATTERING_PAIN_TRIGGER           = 332619,
    SPELL_SHATTERING_PAIN_KNOCKBACK_BOSS    = 332621, // kept for DB-authoring phase
    SPELL_SHATTERING_PAIN_DAMAGE_KNOCK      = 332626,
    SPELL_SHATTERING_PAIN_KNOCK_FOR_TARGETS = 339148, // kept for DB-authoring phase
    SPELL_SHATTERING_PAIN_DAMAGE            = 332620,
    SPELL_FATAL_FINESSE_PERIODIC_DAMAGE     = 332797,
    SPELL_FATAL_FINESSE_SUMMON              = 332795, // kept for DB-authoring phase
    SPELL_SINISTER_REFLECTION               = 333979,
    SPELL_SINISTER_REFLECTION_CHANGE_MODEL  = 332909, // kept for DB-authoring phase

    // Heroic
    SPELL_NIGHT_HUNTER_MISSILE              = 334873,
    SPELL_NIGHT_HUNTER_DAMAGE               = 327810,
    SPELL_NIGHT_HUNTER_MARK                 = 327796,
    SPELL_NIGHT_HUNTER_DUMMY                = 332213, // kept for DB-authoring phase
    SPELL_RANCOR_CREATE_AREATRIGGER         = 335872, // source: AreaTrigger creator
    SPELL_RANCOR_AT_DAMAGE                  = 335873,
    SPELL_CRESCENDO_MISSILE                 = 336161,
    SPELL_SMOLDERING_IRE_CREATE_AT          = 335997,
    SPELL_SMOLDERING_IRE_CREATE_AT_2        = 336000,
    SPELL_SMOLDERING_IRE_SCRIPT_EFFECT      = 336004, // kept for DB-authoring phase
    SPELL_SMOLDERING_IRE_DAMAGE             = 336008, // kept for DB-authoring phase

    // Mythic (dormant on 3.3.5 — no fourth difficulty)
    SPELL_COLLECTIVE_TRAUMA_DAMAGE          = 338582, // kept for DB-authoring phase
    SPELL_SPITEFUL                          = 338510, // kept for DB-authoring phase
    SPELL_THROUGH_THE_MIRROR_MOD_PHASE      = 338738, // kept for DB-authoring phase

    // Court of Night (mythic anointed) — Nathrian Hymns
    SPELL_HYMN_SINSEAR_PERIODIC_DUMMY       = 341728,
    SPELL_HYMN_SINSEAR_DAMAGE               = 338683,
    SPELL_HYMN_EVERSHADE_PERIODIC_DUMMY     = 341648,
    SPELL_HYMN_EVERSHADE_DAMAGE             = 338685,
    SPELL_HYMN_DUSKHOLLOW_PERIODIC_DUMMY    = 338686,
    SPELL_HYMN_DUSKHOLLOW_DAMAGE            = 338687,
    SPELL_HYMN_GLOOMVEIL_PERIODIC_DUMMY     = 338688,
    SPELL_HYMN_GLOOMVEIL_DAMAGE             = 338689
};

enum Texts
{
    // Sire Denathrius — NOTE: no creature_text in DB yet (source-data gap, see 09_creature_text.sql);
    // the group ids below are pre-assigned so the yells activate as soon as rows are authored.
    SAY_AGGRO           = 0,
    SAY_INTERMISSION    = 1,
    SAY_PHASE_TWO       = 2,
    SAY_PHASE_THREE     = 3,
    SAY_RAVAGE          = 4,
    SAY_MASSACRE        = 5,
    SAY_SLAY            = 6,
    SAY_DEATH           = 7
};

enum Events
{
    // Sire Denathrius
    EVENT_GAIN_ENERGY = 1,
    EVENT_CLEANSING_PAIN,
    EVENT_FEEDING_TIME,
    EVENT_BLOOD_PRICE,
    EVENT_WRACKING_PAIN,
    EVENT_HAND_OF_DESTRUCTION,
    EVENT_INDIGNATION,
    EVENT_SHATTERING_PAIN,
    EVENT_FATAL_FINESSE,

    // Remornia
    EVENT_IMPALE
};

enum Actions
{
    // Values 1-4 preserved from the shadowcore source
    ACTION_INIT_PHASE_2     = 1,
    ACTION_INIT_NIGHTCLOAK  = 2,
    ACTION_REMORNIA_EVENTS  = 3,
    ACTION_INIT_PHASE_3     = 4,
    // DC additions
    ACTION_REMORNIA_RETIRE  = 5
};

enum MiscData
{
    // TODO(port): the source used custom marker bunnies 600601 (massacre) / 600600 (reflection
    // anchor) that do not exist in the DC DB; the stock world trigger serves as marker instead.
    NPC_TELEGRAPH_TRIGGER       = WORLD_TRIGGER, // 12999
    POINT_MARCH_OF_THE_PENITENT = 1
};

// Phase one plays in the Crimson Chamber (z ~4672); phases two/three on the Sanctum floor
// directly below (z ~4338). Coordinates taken verbatim from the shadowcore source.
Position const DenathriusPhaseTwoPosition   = { -1925.044f, -9357.142f, 4338.889f, 0.0f }; // source passed `false` as orientation
Position const RemorniaPhaseTwoPosition     = { -1925.044f, -9357.142f, 4338.889f, 0.0f };
Position const MarchWalkPosition            = { -1901.589f, -9357.918f, 4672.623f };
// TODO(port): source dropped players at z 4671.578 and relied on the March of the Penitent
// scene to carry them down; substituted with a direct teleport onto the Sanctum floor.
Position const MarchSanctumPosition         = { -1901.375f, -9358.053f, 4338.9f, 1.5708f };

Position const CrimsonCabalistPositions[4] =
{
    { -1851.677f, -9312.821f, 4338.777f, 4.00f },
    { -1859.526f, -9403.921f, 4338.777f, 3.43f },
    { -1944.445f, -9404.380f, 4338.777f, 0.54f },
    { -1945.439f, -9310.392f, 4338.777f, 5.96f }
};

Position const NightcloakPositions[4] =
{
    { -1950.330f, -9308.497f, 4338.777f, 5.50f }, // Lady Sinsear
    { -1851.573f, -9307.436f, 4338.777f, 3.95f }, // Lord Evershade
    { -1852.687f, -9406.740f, 4338.777f, 2.40f }, // Baron Duskhollow
    { -1949.777f, -9406.352f, 4338.776f, 0.78f }  // Countess Gloomveil
};

// Substitute for the source's persistent ground AreaTriggers (Desolation / Rancor): a marker
// summon plus an aura kept applied to players standing inside the radius.
struct GroundZone
{
    ObjectGuid TriggerGuid;
    uint32 AuraId;
    float Radius;
};

// 168156 - Remornia
struct npc_remornia : public ScriptedAI
{
    npc_remornia(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        events.Reset();
        scheduler.CancelAll();
        _zones.clear();
        me->SetCanFly(true);
        me->SetDisableGravity(true);
        me->SetReactState(REACT_PASSIVE);
        me->SetUnitFlag(UnitFlags(UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC));
        me->SetObjectScale(4.5f);

        // Ground-zone pulse must run even while she hovers passively during phase one.
        scheduler.Schedule(1s, [this](TaskContext context)
        {
            UpdateGroundZones();
            context.Repeat(1s);
        });
    }

    void AddGroundZone(Position const& pos, uint32 auraId, float radius, uint32 durationMs)
    {
        if (Creature* trigger = me->SummonCreature(NPC_TELEGRAPH_TRIGGER, pos, TEMPSUMMON_TIMED_DESPAWN, durationMs))
            _zones.push_back({ trigger->GetGUID(), auraId, radius });
    }

    // The source removed the previous Desolation AreaTrigger before recasting (RemoveAura on the
    // CREATE_AT); mirror that per-aura so repeated Ravage orders REPLACE the zone instead of
    // accumulating up to 6 minutes of stacked pools (2026-07-20 port-audit finding).
    void ClearGroundZonesByAura(uint32 auraId)
    {
        std::erase_if(_zones, [this, auraId](GroundZone const& zone)
        {
            if (zone.AuraId != auraId)
                return false;
            if (Creature* trigger = ObjectAccessor::GetCreature(*me, zone.TriggerGuid))
                trigger->DespawnOrUnsummon();
            return true;
        });
    }

    void ClearGroundZones()
    {
        for (GroundZone const& zone : _zones)
            if (Creature* trigger = ObjectAccessor::GetCreature(*me, zone.TriggerGuid))
                trigger->DespawnOrUnsummon();
        _zones.clear();

        Map::PlayerList const& players = me->GetMap()->GetPlayers();
        for (auto const& ref : players)
            if (Player* player = ref.GetSource())
            {
                player->RemoveAurasDueToSpell(SPELL_DESOLATION_AT_DAMAGE);
                player->RemoveAurasDueToSpell(SPELL_RANCOR_AT_DAMAGE);
            }
    }

    void UpdateGroundZones()
    {
        std::erase_if(_zones, [this](GroundZone const& zone)
        {
            return !ObjectAccessor::GetCreature(*me, zone.TriggerGuid);
        });

        Map::PlayerList const& players = me->GetMap()->GetPlayers();
        for (auto const& ref : players)
        {
            Player* player = ref.GetSource();
            if (!player)
                continue;

            for (uint32 auraId : { uint32(SPELL_DESOLATION_AT_DAMAGE), uint32(SPELL_RANCOR_AT_DAMAGE) })
            {
                bool inside = false;
                for (GroundZone const& zone : _zones)
                {
                    if (zone.AuraId != auraId)
                        continue;
                    Creature* trigger = ObjectAccessor::GetCreature(*me, zone.TriggerGuid);
                    if (trigger && player->IsWithinDist(trigger, zone.Radius))
                    {
                        inside = true;
                        break;
                    }
                }

                if (inside && player->IsAlive() && !player->HasAura(auraId))
                    me->AddAura(auraId, player); // TODO(spell_dbc)
                else if (!inside && player->HasAura(auraId))
                    player->RemoveAurasDueToSpell(auraId);
            }
        }
    }

    void DoAction(int32 action) override
    {
        switch (action)
        {
            case ACTION_REMORNIA_EVENTS:
                me->AddAura(SPELL_CARNAGE, me); // TODO(spell_dbc)
                events.ScheduleEvent(EVENT_IMPALE, 10s);
                break;
            case ACTION_REMORNIA_RETIRE:
                Retire();
                break;
            default:
                break;
        }
    }

    // TODO(port): the source despawned Remornia for phase three; she is a static spawn in the
    // DC DB, so she returns to her Crimson Chamber perch as an inert blade instead.
    void Retire()
    {
        events.Reset();
        ClearGroundZones();
        me->RemoveAurasDueToSpell(SPELL_CARNAGE);
        me->CombatStop(true);
        me->SetReactState(REACT_PASSIVE);
        me->SetUnitFlag(UnitFlags(UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC));
        me->SetCanFly(true);
        me->SetDisableGravity(true);
        Position home = me->GetHomePosition();
        me->NearTeleportTo(home);
    }

    void JustDied(Unit* /*killer*/) override
    {
        // Keep the raid frame clean if she is killed while active in phase two.
        if (InstanceScript* instance = me->GetInstanceScript())
            instance->SendEncounterUnit(ENCOUNTER_FRAME_DISENGAGE, me);
    }

    void UpdateAI(uint32 diff) override
    {
        // Zone pulse and impale follow-ups tick even without a victim (passive phase one).
        scheduler.Update(diff);

        if (!UpdateVictim())
            return;

        events.Update(diff);

        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_IMPALE:
                    DoImpale();
                    events.Repeat(25s);
                    break;
                default:
                    break;
            }
        }

        DoMeleeAttackIfReady();
    }

private:
    void DoImpale()
    {
        std::list<Unit*> targets;
        SelectTargetList(targets, urand(3, 4), SelectTargetMethod::Random, 0, 100.0f, true);
        for (Unit* target : targets)
        {
            me->CastSpell(target, SPELL_IMPALE_MARK, TRIGGERED_FULL_MASK); // TODO(spell_dbc)
            ObjectGuid targetGuid = target->GetGUID();
            scheduler.Schedule(6100ms, [this, targetGuid](TaskContext /*context*/)
            {
                Unit* target = ObjectAccessor::GetUnit(*me, targetGuid);
                if (!target)
                    return;

                me->CastSpell(target, SPELL_IMPALE_DAMAGE, TRIGGERED_FULL_MASK); // TODO(spell_dbc)
                if (target->HasAura(SPELL_CARNAGE_PERIODIC))
                    me->CastSpell(target, SPELL_CARNAGE_PERIODIC, TRIGGERED_FULL_MASK); // TODO(spell_dbc)

                if (IsHeroic())
                {
                    // TODO(port): source created the Rancor AreaTrigger (SPELL_RANCOR_CREATE_AREATRIGGER).
                    AddGroundZone(target->GetPosition(), SPELL_RANCOR_AT_DAMAGE, 4.0f, 60000);
                }
            });
        }
    }

    std::vector<GroundZone> _zones;
};

// 167406 - Sire Denathrius
struct boss_sire_denathrius : public BossAI
{
    boss_sire_denathrius(Creature* creature) : BossAI(creature, DATA_SIRE_DENATHRIUS),
        _intermission(false), _stageTwo(false), _stageThree(false) { }

    void Reset() override
    {
        _Reset();
        _intermission = false;
        _stageTwo = false;
        _stageThree = false;
        me->SetReactState(REACT_AGGRESSIVE);
        me->setPowerType(POWER_ENERGY);
        me->SetMaxPower(POWER_ENERGY, 100);
        me->SetPower(POWER_ENERGY, 0);
        me->AddAura(SPELL_OVERRIDE_POWER_COLOR_RAGE, me); // TODO(spell_dbc)
        me->LoadEquipment(2, true); // set 2: empty-handed while Remornia hovers beside him
    }

    Creature* GetRemornia() const
    {
        // 350 yd covers both the Crimson Chamber (z 4672) and the Sanctum floor (z 4338).
        return me->FindNearestCreature(NPC_REMORNIA, 350.0f, true);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        _JustEngagedWith();
        Talk(SAY_AGGRO); // NOTE: no creature_text in DB yet
        events.ScheduleEvent(EVENT_GAIN_ENERGY, 1s);
        events.ScheduleEvent(EVENT_CLEANSING_PAIN, 5s);
        events.ScheduleEvent(EVENT_FEEDING_TIME, 13s);
        events.ScheduleEvent(EVENT_BLOOD_PRICE, 20s);

        Map::PlayerList const& players = me->GetMap()->GetPlayers();
        for (auto const& ref : players)
        {
            Player* player = ref.GetSource();
            if (!player || !player->IsAlive())
                continue;
            me->AddAura(SPELL_BURDEN_OF_SIN_PERIODIC_DUMMY, player); // TODO(spell_dbc)
            if (Aura* burdenOfSin = player->GetAura(SPELL_BURDEN_OF_SIN_PERIODIC_DUMMY))
                burdenOfSin->SetStackAmount(4);
        }
    }

    void ExecuteEvent(uint32 eventId) override
    {
        switch (eventId)
        {
            case EVENT_GAIN_ENERGY:
                me->ModifyPower(POWER_ENERGY, +2);
                if (me->GetPower(POWER_ENERGY) >= 100)
                    HandleEmpoweredCommand();
                events.Repeat(1s);
                break;
            case EVENT_CLEANSING_PAIN:
                me->AddAura(SPELL_CLEANSING_PAIN_ALLOW_CAST, me); // TODO(spell_dbc)
                DoCastVictim(SPELL_CLEANSING_PAIN);               // TODO(spell_dbc)
                events.Repeat(25s);
                break;
            case EVENT_FEEDING_TIME:
                DoFeedingTime(); // one-shot in the source (scheduled once at 13 s)
                break;
            case EVENT_BLOOD_PRICE:
                DoBloodPrice(); // one-shot in the source
                break;
            case EVENT_WRACKING_PAIN:
                me->AddAura(SPELL_WRACKING_PAIN_ALLOW_CAST, me); // TODO(spell_dbc)
                DoCastVictim(SPELL_WRACKING_PAIN);               // TODO(spell_dbc)
                events.Repeat(20s);
                break;
            case EVENT_HAND_OF_DESTRUCTION:
                me->CastSpell(nullptr, SPELL_HAND_OF_DESTRUCTION_CAST); // TODO(spell_dbc)
                me->SummonCreature(NPC_HAND_OF_DESTRUCTION, me->GetRandomNearPosition(15.0f), TEMPSUMMON_MANUAL_DESPAWN);
                events.Repeat(45s);
                break;
            case EVENT_INDIGNATION:
                me->CastSpell(nullptr, SPELL_INDIGNATION_CREATE_AT, TRIGGERED_FULL_MASK); // TODO(spell_dbc): SL AreaTrigger visual
                me->CastSpell(nullptr, SPELL_INDIGNATION); // TODO(spell_dbc)
                break;
            case EVENT_SHATTERING_PAIN:
                me->AddAura(SPELL_SHATTERING_PAIN_ALLOW_CAST, me);        // TODO(spell_dbc)
                me->CastSpell(nullptr, SPELL_SHATTERING_PAIN_TRIGGER); // TODO(spell_dbc)
                if (Unit* target = SelectTarget(SelectTargetMethod::MaxThreat, 0, 25.0f, true))
                {
                    me->CastSpell(target, SPELL_SHATTERING_PAIN_DAMAGE, TRIGGERED_FULL_MASK); // TODO(spell_dbc)
                    scheduler.Schedule(3100ms, [this](TaskContext /*context*/)
                    {
                        me->CastSpell(nullptr, SPELL_SHATTERING_PAIN_DAMAGE_KNOCK, TRIGGERED_FULL_MASK); // TODO(spell_dbc)
                    });
                }
                events.Repeat(25s);
                break;
            case EVENT_FATAL_FINESSE:
                DoFatalFinesse();
                events.Repeat(30s);
                break;
            default:
                break;
        }
    }

    void DamageTaken(Unit* attacker, uint32& damage, DamageEffectType damagetype, SpellSchoolMask damageSchoolMask) override
    {
        BossAI::DamageTaken(attacker, damage, damagetype, damageSchoolMask);

        if (!_intermission && me->HealthBelowPctDamaged(70, damage))
            StartIntermission();

        // Source allowed phase three to trigger before phase two on a large burst; gated on
        // _stageTwo so the transitions always run in order.
        if (_stageTwo && !_stageThree && me->HealthBelowPctDamaged(40, damage))
        {
            _stageThree = true;
            events.Reset();
            DoAction(ACTION_INIT_PHASE_3);
        }
    }

    void DoAction(int32 action) override
    {
        switch (action)
        {
            case ACTION_INIT_PHASE_2:
            {
                events.Reset();
                _stageTwo = true;
                Talk(SAY_PHASE_TWO); // NOTE: no creature_text in DB yet
                if (Creature* remornia = GetRemornia())
                {
                    remornia->NearTeleportTo(RemorniaPhaseTwoPosition.GetPositionX(), RemorniaPhaseTwoPosition.GetPositionY(),
                        RemorniaPhaseTwoPosition.GetPositionZ(), RemorniaPhaseTwoPosition.GetOrientation());
                    remornia->RemoveUnitFlag(UnitFlags(UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC));
                    remornia->SetReactState(REACT_AGGRESSIVE);
                    remornia->SetInCombatWithZone();
                    if (instance)
                        instance->SendEncounterUnit(ENCOUNTER_FRAME_ENGAGE, remornia);
                    remornia->AI()->DoAction(ACTION_REMORNIA_EVENTS);
                }
                me->NearTeleportTo(DenathriusPhaseTwoPosition.GetPositionX(), DenathriusPhaseTwoPosition.GetPositionY(),
                    DenathriusPhaseTwoPosition.GetPositionZ(), DenathriusPhaseTwoPosition.GetOrientation());
                me->SetReactState(REACT_AGGRESSIVE); // source never left REACT_PASSIVE after the intermission
                events.ScheduleEvent(EVENT_GAIN_ENERGY, 1s);
                events.ScheduleEvent(EVENT_WRACKING_PAIN, 5s);
                events.ScheduleEvent(EVENT_HAND_OF_DESTRUCTION, 15s);
                for (Position const& pos : CrimsonCabalistPositions)
                    me->SummonCreature(NPC_CRIMSON_CABALIST, pos, TEMPSUMMON_MANUAL_DESPAWN);
                scheduler.Schedule(5s, [this](TaskContext /*context*/)
                {
                    // TODO(port): mythic-only in the source; mapped to 25-player heroic here.
                    if (Is25ManRaid() && IsHeroic())
                        DoAction(ACTION_INIT_NIGHTCLOAK);
                });
                break;
            }
            case ACTION_INIT_NIGHTCLOAK:
                me->SummonCreature(NPC_LADY_SINSEAR, NightcloakPositions[0], TEMPSUMMON_MANUAL_DESPAWN);
                me->SummonCreature(NPC_LORD_EVERSHADE, NightcloakPositions[1], TEMPSUMMON_MANUAL_DESPAWN);
                me->SummonCreature(NPC_BARON_DUSKHOLLOW, NightcloakPositions[2], TEMPSUMMON_MANUAL_DESPAWN);
                me->SummonCreature(NPC_COUNTESS_GLOOMVEIL, NightcloakPositions[3], TEMPSUMMON_MANUAL_DESPAWN);
                break;
            case ACTION_INIT_PHASE_3:
                Talk(SAY_PHASE_THREE); // NOTE: no creature_text in DB yet
                if (Creature* remornia = GetRemornia())
                {
                    if (instance)
                        instance->SendEncounterUnit(ENCOUNTER_FRAME_DISENGAGE, remornia);
                    remornia->AI()->DoAction(ACTION_REMORNIA_RETIRE);
                }
                me->LoadEquipment(1, true); // set 1: Denathrius reclaims Remornia as his blade
                events.ScheduleEvent(EVENT_GAIN_ENERGY, 1s);
                events.ScheduleEvent(EVENT_INDIGNATION, 3s);
                events.ScheduleEvent(EVENT_SHATTERING_PAIN, 5s);
                events.ScheduleEvent(EVENT_HAND_OF_DESTRUCTION, 10s);
                events.ScheduleEvent(EVENT_FATAL_FINESSE, 15s);
                events.ScheduleEvent(EVENT_BLOOD_PRICE, 20s);
                break;
            default:
                break;
        }
    }

    void EnterEvadeMode(EvadeReason why) override
    {
        if (Creature* remornia = GetRemornia())
        {
            if (instance)
                instance->SendEncounterUnit(ENCOUNTER_FRAME_DISENGAGE, remornia);
            remornia->AI()->DoAction(ACTION_REMORNIA_RETIRE);
        }
        else if (Creature* deadRemornia = me->FindNearestCreature(NPC_REMORNIA, 350.0f, false))
            deadRemornia->Respawn(); // keep the blade available for the next attempt

        // Summoned adds (echoes, cabalists, hands, nightcloaks, telegraph markers) despawn via
        // the summon list when _Reset runs on reaching home.
        Position home = me->GetHomePosition();
        me->NearTeleportTo(home); // source teleported home; walking up from the Sanctum floor is not pathable
        _EnterEvadeMode(why);
    }

    void KilledUnit(Unit* victim) override
    {
        if (victim->IsPlayer())
            Talk(SAY_SLAY); // NOTE: no creature_text in DB yet
    }

    void JustDied(Unit* /*killer*/) override
    {
        Talk(SAY_DEATH); // NOTE: no creature_text in DB yet
        _JustDied(); // sets DATA_SIRE_DENATHRIUS = DONE and saves; loot flows normally from the corpse
        if (Creature* remornia = GetRemornia())
        {
            if (instance)
                instance->SendEncounterUnit(ENCOUNTER_FRAME_DISENGAGE, remornia);
            remornia->AI()->DoAction(ACTION_REMORNIA_RETIRE);
        }
    }

private:
    // Energy-100 empowered command: Ravage (P1), Massacre (P2), Sinister Reflection (P3).
    // TODO(port): the source drove the aftermaths from OnSpellFinished; the SL command casts
    // cannot complete without spell_dbc rows, so the aftermath is scheduler-driven instead.
    void HandleEmpoweredCommand()
    {
        me->SetPower(POWER_ENERGY, 0);
        if (_stageThree)
        {
            me->StopMoving();
            me->CastSpell(nullptr, SPELL_SINISTER_REFLECTION); // TODO(spell_dbc)
            scheduler.Schedule(2s, [this](TaskContext /*context*/)
            {
                // TODO(port): source spawned at marker bunny 600600 (not in DC DB).
                me->SummonCreature(NPC_SINISTER_REFLETION, me->GetRandomNearPosition(20.0f), TEMPSUMMON_MANUAL_DESPAWN);
            });
        }
        else if (_stageTwo)
        {
            me->StopMoving();
            Talk(SAY_MASSACRE); // NOTE: no creature_text in DB yet
            me->CastSpell(nullptr, SPELL_COMMAND_MASSACRE); // TODO(spell_dbc)
            scheduler.Schedule(2s, [this](TaskContext /*context*/)
            {
                DoMassacreVolley();
            });
        }
        else
        {
            Talk(SAY_RAVAGE); // NOTE: no creature_text in DB yet
            me->CastSpell(nullptr, SPELL_COMMAND_RAVAGE); // TODO(spell_dbc)
            scheduler.Schedule(2s, [this](TaskContext /*context*/)
            {
                DoRavageOrder();
            });
        }
    }

    // Command: Ravage — Remornia telegraphs a random player, then a persistent Desolation
    // ground zone forms at the impact point (substitute for the source "pizza" AreaTrigger).
    void DoRavageOrder()
    {
        Creature* remornia = GetRemornia();
        if (!remornia)
            return;
        Unit* target = SelectTarget(SelectTargetMethod::Random, 0, 25.0f, true);
        if (!target)
            return;

        remornia->CastSpell(target, SPELL_RAVAGE_CAST_DUMMY); // TODO(spell_dbc)
        ObjectGuid remorniaGuid = remornia->GetGUID();
        ObjectGuid targetGuid = target->GetGUID();
        scheduler.Schedule(6100ms, [this, remorniaGuid, targetGuid](TaskContext /*context*/)
        {
            Creature* remornia = ObjectAccessor::GetCreature(*me, remorniaGuid);
            if (!remornia)
                return;

            Unit* target = ObjectAccessor::GetUnit(*me, targetGuid);
            Position impact = target ? target->GetPosition() : remornia->GetPosition();
            if (npc_remornia* remorniaAI = CAST_AI(npc_remornia, remornia->AI()))
            {
                // Source removed the previous Desolation AT before recasting -- replace, don't stack.
                remorniaAI->ClearGroundZonesByAura(SPELL_DESOLATION_AT_DAMAGE);
                remorniaAI->AddGroundZone(impact, SPELL_DESOLATION_AT_DAMAGE, 6.0f, 360000); // 6 min, as the source AT
            }
        });
    }

    // Command: Massacre — twelve blades sweep the Sanctum. Substitute for the source line/weapon
    // AreaTriggers: each marker fires a lethal point moving 60 yd over 6 s along its facing.
    void DoMassacreVolley()
    {
        for (uint8 i = 0; i < 12; ++i)
        {
            Creature* marker = me->SummonCreature(NPC_TELEGRAPH_TRIGGER, me->GetRandomNearPosition(30.0f), TEMPSUMMON_TIMED_DESPAWN, 9000);
            if (!marker)
                continue;

            float orientation = frand(0.0f, 6.28f); // source: SetFacingTo(urand(1, 5))
            marker->SetFacingTo(orientation);
            Position origin = marker->GetPosition();
            scheduler.Schedule(1500ms, [this, origin, orientation, elapsed = 0.0f](TaskContext context) mutable
            {
                float distance = 10.0f * elapsed; // 60 yd over 6 s
                float bladeX = origin.GetPositionX() + std::cos(orientation) * distance;
                float bladeY = origin.GetPositionY() + std::sin(orientation) * distance;

                Map::PlayerList const& players = me->GetMap()->GetPlayers();
                for (auto const& ref : players)
                {
                    Player* player = ref.GetSource();
                    if (!player || !player->IsAlive())
                        continue;
                    if (player->GetExactDist2d(bladeX, bladeY) <= 3.0f &&
                        std::fabs(player->GetPositionZ() - origin.GetPositionZ()) < 10.0f)
                        Unit::Kill(me, player); // source AreaTrigger killed on contact
                }

                elapsed += 0.25f;
                if (elapsed <= 6.0f)
                    context.Repeat(250ms); // source: SetPeriodicProcTimer(250)
            });
        }
    }

    void DoFeedingTime()
    {
        // Source gated with `!IsHeroic() || !IsMythic()` (always true); intent restored:
        // Feeding Time on normal, Night Hunter on heroic.
        std::list<Unit*> targets;
        SelectTargetList(targets, 3, SelectTargetMethod::Random, 0, 100.0f, true);
        if (!IsHeroic())
        {
            for (Unit* target : targets)
            {
                me->CastSpell(target, SPELL_FEEDING_TIME_MARK, TRIGGERED_FULL_MASK); // TODO(spell_dbc)
                ObjectGuid targetGuid = target->GetGUID();
                scheduler.Schedule(5100ms, [this, targetGuid](TaskContext /*context*/)
                {
                    Unit* target = ObjectAccessor::GetUnit(*me, targetGuid);
                    if (!target)
                        return;

                    // TODO(port): source cast SPELL_FEEDING_TIME_SUMMON twice; summoned directly
                    // until the summon spell exists in spell_dbc.
                    for (uint8 i = 0; i < 2; ++i)
                        me->SummonCreature(NPC_ECHO_OF_SIN, target->GetRandomNearPosition(8.0f), TEMPSUMMON_MANUAL_DESPAWN);
                    me->CastSpell(target, SPELL_FEEDING_TIME_DRAIN_HEALTH, TRIGGERED_FULL_MASK); // TODO(spell_dbc)
                });
            }
        }
        else
        {
            for (Unit* target : targets)
            {
                me->AddAura(SPELL_NIGHT_HUNTER_MARK, target); // TODO(spell_dbc)
                ObjectGuid targetGuid = target->GetGUID();
                scheduler.Schedule(6100ms, [this, targetGuid](TaskContext /*context*/)
                {
                    Unit* target = ObjectAccessor::GetUnit(*me, targetGuid);
                    if (!target)
                        return;

                    target->CastSpell(target, SPELL_NIGHT_HUNTER_MISSILE, TRIGGERED_FULL_MASK); // TODO(spell_dbc)
                    me->CastSpell(target, SPELL_NIGHT_HUNTER_DAMAGE, TRIGGERED_FULL_MASK);      // TODO(spell_dbc)
                });
            }
        }
    }

    void DoBloodPrice()
    {
        me->CastSpell(nullptr, SPELL_BLOOD_PRICE_CHANNEL); // TODO(spell_dbc)
        Map::PlayerList const& players = me->GetMap()->GetPlayers();
        for (auto const& ref : players)
        {
            Player* player = ref.GetSource();
            if (!player || !player->IsAlive())
                continue;

            // TODO(port): source issued a malformed MoveCharge (boolean z); the immobilize aura
            // alone anchors the player here.
            me->AddAura(SPELL_BLOOD_PRICE_IMMOBILIZE, player); // TODO(spell_dbc)
            ObjectGuid playerGuid = player->GetGUID();
            scheduler.Schedule(3600ms, [this, playerGuid](TaskContext /*context*/)
            {
                Player* player = ObjectAccessor::GetPlayer(*me, playerGuid);
                if (!player)
                    return;

                me->CastSpell(player, SPELL_BLOOD_PRICE_EFFECT, TRIGGERED_FULL_MASK);    // TODO(spell_dbc)
                me->CastSpell(player, SPELL_BLOOD_PRICE_DAMAGE, TRIGGERED_FULL_MASK);    // TODO(spell_dbc)
                me->CastSpell(player, SPELL_BLOOD_PRICE_KNOCKBACK, TRIGGERED_FULL_MASK); // TODO(spell_dbc)
            });
        }
    }

    void DoFatalFinesse()
    {
        std::list<Unit*> targets;
        SelectTargetList(targets, urand(3, 4), SelectTargetMethod::Random, 0, 100.0f, true);
        for (Unit* target : targets)
        {
            me->AddAura(SPELL_FATAL_FINESSE_PERIODIC_DAMAGE, target); // TODO(spell_dbc)
            if (IsHeroic())
            {
                ObjectGuid targetGuid = target->GetGUID();
                scheduler.Schedule(19s, [this, targetGuid](TaskContext /*context*/)
                {
                    Unit* target = ObjectAccessor::GetUnit(*me, targetGuid);
                    if (!target)
                        return;

                    // TODO(port): Smoldering Ire spawned SL AreaTriggers; casts kept for the
                    // DB-authoring phase.
                    me->CastSpell(target, SPELL_SMOLDERING_IRE_CREATE_AT, TRIGGERED_FULL_MASK);   // TODO(spell_dbc)
                    me->CastSpell(target, SPELL_SMOLDERING_IRE_CREATE_AT_2, TRIGGERED_FULL_MASK); // TODO(spell_dbc)
                });
            }
        }
    }

    // 70% — March of the Penitent: the raid is marched to the chamber center, then carried
    // down onto the Sanctum floor where phase two begins.
    void StartIntermission()
    {
        _intermission = true;
        Talk(SAY_INTERMISSION); // NOTE: no creature_text in DB yet
        events.Reset();
        me->SetReactState(REACT_PASSIVE);
        me->AttackStop();
        me->StopMoving();
        me->CastSpell(nullptr, SPELL_MARCH_OF_THE_PENITENT_SEND_EVENT); // TODO(spell_dbc): retail scene trigger
        if (Creature* remornia = GetRemornia())
            if (npc_remornia* remorniaAI = CAST_AI(npc_remornia, remornia->AI()))
                remorniaAI->ClearGroundZones(); // source removed the Desolation AreaTrigger here

        scheduler.Schedule(16s, [this](TaskContext /*context*/)
        {
            DoAction(ACTION_INIT_PHASE_2);
        });

        Map::PlayerList const& players = me->GetMap()->GetPlayers();
        for (auto const& ref : players)
        {
            Player* player = ref.GetSource();
            if (!player || !player->IsAlive())
                continue;

            // TODO(port): source used UNIT_STATE_LOST_CONTROL; client control toggle is the
            // 3.3.5 equivalent for the forced penitent walk.
            player->SetClientControl(player, false);
            player->SetWalk(true);
            player->GetMotionMaster()->MovePoint(POINT_MARCH_OF_THE_PENITENT, MarchWalkPosition);
            ObjectGuid playerGuid = player->GetGUID();
            scheduler.Schedule(15s, [this, playerGuid](TaskContext /*context*/)
            {
                Player* player = ObjectAccessor::GetPlayer(*me, playerGuid);
                if (!player)
                    return;

                player->SetClientControl(player, true);
                player->SetWalk(false);
                player->NearTeleportTo(MarchSanctumPosition.GetPositionX(), MarchSanctumPosition.GetPositionY(),
                    MarchSanctumPosition.GetPositionZ(), MarchSanctumPosition.GetOrientation());
            });
        }
    }

    bool _intermission;
    bool _stageTwo;
    bool _stageThree;
};

// 169813 - Hand of Destruction
struct npc_hand_of_destruction : public ScriptedAI
{
    npc_hand_of_destruction(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(WorldObject* /*summoner*/) override
    {
        if (InstanceScript* instance = me->GetInstanceScript())
            instance->SendEncounterUnit(ENCOUNTER_FRAME_ENGAGE, me);
        scheduler.Schedule(6s, [this](TaskContext /*context*/)
        {
            DoCastAOE(SPELL_HAND_OF_DESTRUCTION_DAMAGE, true); // TODO(spell_dbc)
            if (InstanceScript* instance = me->GetInstanceScript())
                instance->SendEncounterUnit(ENCOUNTER_FRAME_DISENGAGE, me);
            me->DespawnOrUnsummon();
        });
    }

    void JustDied(Unit* /*killer*/) override
    {
        if (InstanceScript* instance = me->GetInstanceScript())
            instance->SendEncounterUnit(ENCOUNTER_FRAME_DISENGAGE, me);
    }

    void UpdateAI(uint32 diff) override
    {
        scheduler.Update(diff);

        if (!UpdateVictim())
            return;

        DoMeleeAttackIfReady();
    }
};

// 169196 - Crimson Cabalist
struct npc_crimson_cabalist : public ScriptedAI
{
    npc_crimson_cabalist(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(WorldObject* /*summoner*/) override
    {
        me->CastSpell(nullptr, SPELL_CRIMSON_CHORUS); // TODO(spell_dbc)
    }

    void JustDied(Unit* /*killer*/) override
    {
        // TODO(port): source fired on heroic and mythic; mythic does not exist on 3.3.5.
        if (IsHeroic())
            me->CastSpell(nullptr, SPELL_CRESCENDO_MISSILE, TRIGGERED_FULL_MASK); // TODO(spell_dbc)
    }
};

// 170710 - Sinister Reflection
struct npc_sinister_reflection : public ScriptedAI
{
    npc_sinister_reflection(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(WorldObject* /*summoner*/) override
    {
        // Intentionally empty in the source; the reflection fights as a plain melee add.
    }
};

// 167999 - Echo of Sin
struct npc_echo_of_sin : public ScriptedAI
{
    npc_echo_of_sin(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(WorldObject* /*summoner*/) override
    {
        me->GetMotionMaster()->MoveIdle();
        me->SetReactState(REACT_PASSIVE);
        me->CastSpell(nullptr, SPELL_PAINFUL_MEMORIES_CHANNEL); // TODO(spell_dbc)
    }
};

// 174161 / 174134 / 174126 / 173164 - Court of Night anointed (DB binds 174126 and 174134)
struct npc_nightcloak : public ScriptedAI
{
    npc_nightcloak(Creature* creature) : ScriptedAI(creature)
    {
        me->GetMotionMaster()->MoveIdle();
    }

    void Reset() override
    {
        switch (me->GetEntry())
        {
            case NPC_LADY_SINSEAR:
                me->CastSpell(nullptr, SPELL_HYMN_SINSEAR_PERIODIC_DUMMY); // TODO(spell_dbc)
                break;
            case NPC_LORD_EVERSHADE:
                me->CastSpell(nullptr, SPELL_HYMN_EVERSHADE_PERIODIC_DUMMY); // TODO(spell_dbc)
                break;
            case NPC_BARON_DUSKHOLLOW:
                me->CastSpell(nullptr, SPELL_HYMN_DUSKHOLLOW_PERIODIC_DUMMY); // TODO(spell_dbc)
                break;
            case NPC_COUNTESS_GLOOMVEIL:
                me->CastSpell(nullptr, SPELL_HYMN_GLOOMVEIL_PERIODIC_DUMMY); // TODO(spell_dbc)
                break;
            default:
                break;
        }
    }
};

// 326707 - Cleansing Pain
class spell_cleansing_pain : public SpellScript
{
    PrepareSpellScript(spell_cleansing_pain);

    void HandleOnHit()
    {
        Unit* caster = GetCaster();
        Unit* hitUnit = GetHitUnit();
        if (!caster || !hitUnit)
            return;

        if (Aura* burdenOfSin = hitUnit->GetAura(SPELL_BURDEN_OF_SIN_PERIODIC_DUMMY))
            if (burdenOfSin->GetStackAmount() > 1)
                burdenOfSin->SetStackAmount(burdenOfSin->GetStackAmount() - 1);

        // Summoner changed from the hit player to the boss so the echo joins the boss summon
        // list and is cleaned up with the encounter (source summoned via the player).
        caster->SummonCreature(NPC_ECHO_OF_SIN, hitUnit->GetRandomNearPosition(10.0f), TEMPSUMMON_MANUAL_DESPAWN);

        // TODO(port): mythic-only SPELL_COLLECTIVE_TRAUMA_DAMAGE dropped — no mythic on 3.3.5.
    }

    void Register() override
    {
        OnHit += SpellHitFn(spell_cleansing_pain::HandleOnHit);
    }
};

// 329181 - Wracking Pain
class spell_wracking_pain : public SpellScript
{
    PrepareSpellScript(spell_wracking_pain);

    void FilterTargets(std::list<WorldObject*>& targets)
    {
        // Source filtered via GetHitUnit() inside target selection (invalid there); the intent —
        // the cleave damages players only — is restored here.
        targets.remove_if([](WorldObject* target)
        {
            return !target->IsPlayer();
        });
    }

    void Register() override
    {
        // TODO(spell_dbc): align the target type with the authored spell_dbc row (source bound
        // against SPELL_EFFECT_SCHOOL_DAMAGE on EFFECT_0).
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(spell_wracking_pain::FilterTargets, EFFECT_0, TARGET_UNIT_SRC_AREA_ENEMY);
    }
};

// 341728 / 341648 / 338686 / 338688 - Nathrian Hymns (periodic dummy)
class aura_nathrian_hymn : public AuraScript
{
    PrepareAuraScript(aura_nathrian_hymn);

    void OnTick(AuraEffect const* /*aurEff*/)
    {
        Unit* caster = GetCaster();
        if (!caster) // source guard was inverted (`if (GetCaster()) return;`)
            return;

        switch (caster->GetEntry())
        {
            case NPC_LADY_SINSEAR:
                caster->CastSpell(nullptr, SPELL_HYMN_SINSEAR_DAMAGE); // TODO(spell_dbc)
                break;
            case NPC_LORD_EVERSHADE:
                caster->CastSpell(nullptr, SPELL_HYMN_EVERSHADE_DAMAGE); // TODO(spell_dbc)
                break;
            case NPC_BARON_DUSKHOLLOW:
                caster->CastSpell(nullptr, SPELL_HYMN_DUSKHOLLOW_DAMAGE); // TODO(spell_dbc)
                break;
            case NPC_COUNTESS_GLOOMVEIL:
                caster->CastSpell(nullptr, SPELL_HYMN_GLOOMVEIL_DAMAGE); // TODO(spell_dbc)
                break;
            default:
                break;
        }
    }

    void Register() override
    {
        OnEffectPeriodic += AuraEffectPeriodicFn(aura_nathrian_hymn::OnTick, EFFECT_0, SPELL_AURA_PERIODIC_DUMMY);
    }
};

// 326699 - Burden of Sin (periodic dummy)
class aura_burden_sin : public AuraScript
{
    PrepareAuraScript(aura_burden_sin);

    void OnTick(AuraEffect const* /*aurEff*/)
    {
        // Source guard was inverted (`if (GetCaster() || GetTarget()) return;` — always bailed).
        if (!GetCaster() || !GetTarget())
            return;

        GetCaster()->CastSpell(GetTarget(), SPELL_BURDEN_OF_SIN_DAMAGE, TRIGGERED_FULL_MASK); // TODO(spell_dbc)
    }

    void Register() override
    {
        OnEffectPeriodic += AuraEffectPeriodicFn(aura_burden_sin::OnTick, EFFECT_0, SPELL_AURA_PERIODIC_DUMMY);
    }
};

// 326824 - Painful Memories (source header said 324831)
class aura_painful_memories : public AuraScript
{
    PrepareAuraScript(aura_painful_memories);

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Unit* caster = GetCaster();
        if (!caster) // source guard was inverted (`if (GetCaster()) return;`)
            return;

        caster->CastSpell(nullptr, SPELL_PAINFUL_MEMORIES_DAMAGE, TRIGGERED_FULL_MASK); // TODO(spell_dbc)
    }

    void Register() override
    {
        AfterEffectApply += AuraEffectApplyFn(aura_painful_memories::OnApply, EFFECT_0, SPELL_AURA_PERIODIC_TRIGGER_SPELL, AURA_EFFECT_HANDLE_REAL);
    }
};
} // namespace CastleNathria::SireDenathrius

void AddSC_boss_sire_denathrius()
{
    using namespace CastleNathria;
    using namespace CastleNathria::SireDenathrius;
    // The source's AreaTriggerAI scripts (at_desolation, at_massacre_line, at_massacre,
    // at_rancor) have no 3.3.5 registration path; their behaviour lives in the AIs above.
    RegisterCastleNathriaCreatureAI(boss_sire_denathrius);
    RegisterCastleNathriaCreatureAI(npc_remornia);
    RegisterCastleNathriaCreatureAI(npc_hand_of_destruction);
    RegisterCastleNathriaCreatureAI(npc_crimson_cabalist);
    RegisterCastleNathriaCreatureAI(npc_sinister_reflection);
    RegisterCastleNathriaCreatureAI(npc_echo_of_sin);
    RegisterCastleNathriaCreatureAI(npc_nightcloak);
    RegisterSpellScript(spell_cleansing_pain);
    RegisterSpellScript(spell_wracking_pain);
    RegisterSpellScript(aura_nathrian_hymn);
    RegisterSpellScript(aura_burden_sin);
    RegisterSpellScript(aura_painful_memories);
}
