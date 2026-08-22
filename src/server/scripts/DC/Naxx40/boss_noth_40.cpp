/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "CreatureScript.h"
#include "ScriptedCreature.h"
#include "naxx40_instance.h"

enum Says
{
    SAY_AGGRO                               = 0,
    SAY_SUMMON                              = 1,
    SAY_SLAY                                = 2,
    SAY_DEATH                               = 3,
    EMOTE_SUMMON                            = 4,
    EMOTE_SUMMON_WAVE                       = 5,
    EMOTE_TELEPORT_BALCONY                  = 6,
    EMOTE_TELEPORT_BACK                     = 7,
    EMOTE_BLINK                             = 8
};

enum Spells
{
    SPELL_CURSE_OF_THE_PLAGUEBRINGER        = 29213,
    SPELL_CRIPPLE                           = 29212,
    SPELL_SUMMON_PLAGUED_WARRIORS           = 29237,
    SPELL_TELEPORT                          = 29216,   // see NOTE below: cast replaced by NearTeleportTo
    SPELL_TELEPORT_BACK                     = 29231,   // see NOTE below: cast replaced by NearTeleportTo
    SPELL_BERSERK                           = 68378,
    SPELL_BLINK                             = 29208
};

// [DC] These self-teleports used to be `me->CastSpell(me, SPELL_TELEPORT*, ...)`.
// The destination lives in `spell_target_position`, which stores an ABSOLUTE map
// id and has exactly one row per spell -- and that row says map 533, because the
// spell is shared with core's Naxxramas. On map 2921 SpellEffects.cpp:1240 hits
//     "attempted to teleport creature to a different map"
// and the boss never moves, stalling the encounter.
// Maps 533 and 2921 share one coordinate space (identical WMO origin), so only
// the map id was ever wrong: teleport directly, using the exact coordinates the
// spell_target_position rows already hold. Repointing those rows instead would
// break stock Naxxramas on 533.
// spell_target_position 29216 -- Noth up to the balcony
constexpr float NOTH_BALCONY_X = 2631.37f, NOTH_BALCONY_Y = -3529.68f, NOTH_BALCONY_Z = 274.04f, NOTH_BALCONY_O = 0.0f;
// spell_target_position 29231 -- Noth back down to the room
constexpr float NOTH_GROUND_X  = 2684.80f, NOTH_GROUND_Y  = -3502.52f, NOTH_GROUND_Z  = 261.31f, NOTH_GROUND_O  = 0.0f;

enum Events
{
    EVENT_CURSE                             = 1,
    EVENT_CRIPPLE                           = 2,
    EVENT_SUMMON_PLAGUED_WARRIOR_ANNOUNCE   = 3,
    EVENT_MOVE_TO_BALCONY                   = 4,
    EVENT_BLINK                             = 5,
    EVENT_MOVE_TO_GROUND                    = 6,
    EVENT_SUMMON_PLAGUED_WARRIOR_REAL       = 7,
    EVENT_BALCONY_SUMMON_ANNOUNCE           = 8,
    EVENT_BALCONY_SUMMON_REAL               = 9
};

const Position summoningPosition[5] =
{
    {2728.06f, -3535.38f, 263.21f, 2.75f},
    {2725.71f, -3514.80f, 263.23f, 2.86f},
    {2728.24f, -3465.08f, 264.20f, 3.56f},
    {2704.79f, -3459.17f, 263.74f, 4.25f},
    {2652.02f, -3459.13f, 262.50f, 5.39f}
};

const Position nothPosition = {2684.94f, -3502.53f, 261.31f, 4.7f};

class boss_noth_40 : public CreatureScript
{
public:
    boss_noth_40() : CreatureScript("boss_noth_40") { }

    CreatureAI* GetAI(Creature* pCreature) const override
    {
        return GetNaxxramasAI<boss_noth_40AI>(pCreature);
    }

    struct boss_noth_40AI : public BossAI
    {
        explicit boss_noth_40AI(Creature* c) : BossAI(c, BOSS_NOTH), summons(me) { }

        uint8 timesInBalcony;
        EventMap events;
        SummonList summons;

        void StartGroundPhase()
        {
            me->SetReactState(REACT_AGGRESSIVE);
            me->RemoveUnitFlag(UNIT_FLAG_NOT_SELECTABLE | UNIT_FLAG_DISABLE_MOVE);
            me->SetControlled(false, UNIT_STATE_ROOT);
            events.Reset();
            events.ScheduleEvent(EVENT_MOVE_TO_BALCONY, 110s);
            events.ScheduleEvent(EVENT_CURSE, 15s);
            events.ScheduleEvent(EVENT_SUMMON_PLAGUED_WARRIOR_ANNOUNCE, 10s);
            events.ScheduleEvent(EVENT_BLINK, 35s);
        }

        void StartBalconyPhase()
        {
            me->SetReactState(REACT_PASSIVE);
            me->AttackStop();
            me->SetUnitFlag(UNIT_FLAG_NOT_SELECTABLE | UNIT_FLAG_DISABLE_MOVE);
            me->SetControlled(true, UNIT_STATE_ROOT);
            events.Reset();
            events.ScheduleEvent(EVENT_BALCONY_SUMMON_ANNOUNCE, 4s);
            events.ScheduleEvent(EVENT_MOVE_TO_GROUND, 70s);
        }

        void SummonHelper(uint32 entry, uint32 count)
        {
            for (uint8 i = 0; i < count; ++i)
            {
                me->SummonCreature(entry, summoningPosition[urand(0, 4)]);
            }
        }

        bool IsInRoom()
        {
            if (me->GetExactDist(2684.8f, -3502.5f, 261.3f) > 80.0f)
            {
                EnterEvadeMode(EVADE_REASON_OTHER);
                return false;
            }
            return true;
        }

        void Reset() override
        {
            BossAI::Reset();
            events.Reset();
            summons.DespawnAll();
            me->NearTeleportTo(NOTH_GROUND_X, NOTH_GROUND_Y, NOTH_GROUND_Z, NOTH_GROUND_O, true);
            me->SetControlled(false, UNIT_STATE_ROOT);
            me->SetReactState(REACT_AGGRESSIVE);
            timesInBalcony = 0;
        }

        void EnterEvadeMode(EvadeReason why) override
        {
            me->SetControlled(false, UNIT_STATE_ROOT);
            ScriptedAI::EnterEvadeMode(why);
        }

        void JustEngagedWith(Unit* who) override
        {
            BossAI::JustEngagedWith(who);
            Talk(SAY_AGGRO);
            StartGroundPhase();
        }

        void JustSummoned(Creature* summon) override
        {
            summons.Summon(summon);
            summon->SetInCombatWithZone();
        }

        void JustDied(Unit*  killer) override
        {
            if (me->GetPositionZ() > 270.27f)
            {
                me->RemoveUnitFlag(UNIT_FLAG_NOT_SELECTABLE | UNIT_FLAG_DISABLE_MOVE);
                me->NearTeleportTo(nothPosition.GetPositionX(), nothPosition.GetPositionY(), nothPosition.GetPositionZ(), nothPosition.GetOrientation(), true);
            }
            BossAI::JustDied(killer);
            Talk(SAY_DEATH);
        }

        void KilledUnit(Unit* who) override
        {
            if (!who->IsPlayer())
                return;

            Talk(SAY_SLAY);
            // instance->StorePersistentData(PERSISTENT_DATA_IMMORTAL_FAIL, 1);
        }

        void UpdateAI(uint32 diff) override
        {
            if (!IsInRoom())
                return;

            if (!UpdateVictim())
                return;

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;

            events.Update(diff);

            switch (events.ExecuteEvent())
            {
                // GROUND
                case EVENT_CURSE:
                    if (events.GetPhaseMask() == 0)
                    {
                        me->CastCustomSpell(SPELL_CURSE_OF_THE_PLAGUEBRINGER, SPELLVALUE_MAX_TARGETS, 20, me, false);
                    }
                    events.Repeat(50s, 60s);
                    break;
                case EVENT_SUMMON_PLAGUED_WARRIOR_ANNOUNCE:
                    Talk(SAY_SUMMON);
                    Talk(EMOTE_SUMMON);
                    events.Repeat(30s);
                    events.ScheduleEvent(EVENT_SUMMON_PLAGUED_WARRIOR_REAL, 4s);
                    break;
                case EVENT_SUMMON_PLAGUED_WARRIOR_REAL:
                    me->CastSpell(me, SPELL_SUMMON_PLAGUED_WARRIORS, true);
                    SummonHelper(NPC_PLAGUED_WARRIOR_40, 3);
                    break;
                case EVENT_MOVE_TO_BALCONY:
                    Talk(EMOTE_TELEPORT_BALCONY);
                    me->NearTeleportTo(NOTH_BALCONY_X, NOTH_BALCONY_Y, NOTH_BALCONY_Z, NOTH_BALCONY_O, true);
                    StartBalconyPhase();
                    break;
                case EVENT_BLINK:
                    DoResetThreatList();
                    me->CastSpell(me, SPELL_CRIPPLE, false);
                    me->CastSpell(me, SPELL_BLINK, true);
                    Talk(EMOTE_BLINK);
                    events.Repeat(30s);
                    break;
                // BALCONY
                case EVENT_BALCONY_SUMMON_ANNOUNCE:
                    Talk(EMOTE_SUMMON_WAVE);
                    events.Repeat(30s);
                    events.ScheduleEvent(EVENT_BALCONY_SUMMON_REAL, 4s);
                    break;
                case EVENT_BALCONY_SUMMON_REAL:
                    me->CastSpell(me, SPELL_SUMMON_PLAGUED_WARRIORS, true); // visual
                    switch (timesInBalcony)
                    {
                         case 0:
                             SummonHelper(NPC_PLAGUED_CHAMPION_40, 4);
                             break;
                         case 1:
                             SummonHelper(NPC_PLAGUED_CHAMPION_40, 2);
                             SummonHelper(NPC_PLAGUED_GUARDIAN_40, 2);
                             break;
                         default:
                             SummonHelper(NPC_PLAGUED_GUARDIAN_40, 4);
                             break;
                    }
                    break;
                case EVENT_MOVE_TO_GROUND:
                    Talk(EMOTE_TELEPORT_BACK);
                    me->NearTeleportTo(NOTH_GROUND_X, NOTH_GROUND_Y, NOTH_GROUND_Z, NOTH_GROUND_O, true);
                    timesInBalcony++;
                    if (timesInBalcony == 3)
                    {
                        DoCastSelf(SPELL_BERSERK);
                    }
                    StartGroundPhase();
                    break;
            }
            if (me->HasReactState(REACT_AGGRESSIVE))
                DoMeleeAttackIfReady();
        }
    };
};

void AddSC_boss_noth_40()
{
    new boss_noth_40();
}
