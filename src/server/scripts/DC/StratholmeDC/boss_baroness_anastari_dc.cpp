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
// DARKCHAOS CLONE -- map 821. Generated from boss_baroness_anastari.cpp, then renamed.
//
// This is a copy, not a fork: the logic is upstream AzerothCore's and should stay that way
// so upstream fixes can be re-applied by regenerating. Only three kinds of thing differ:
//     * the script names, so they cannot collide with the stock registrations
//       (ScriptMgr.h:839 silently DELETES the older script when a name is reused)
//     * the map id, 821 instead of 329
//     * the header, stratholme_dc.h, whose enums carry the REMAPPED clone entry ids
//
// Stock Stratholme on map 329 keeps its own scripts, spawns and entrances untouched.
// ---------------------------------------------------------------------------------

#include "CreatureScript.h"
#include "InstanceScript.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptedCreature.h"
#include "TaskScheduler.h"
#include "stratholme_dc.h"

enum Spells
{
    SPELL_BANSHEEWAIL           = 16565,
    SPELL_BANSHEECURSE          = 16867,
    SPELL_SILENCE               = 18327,
    SPELL_POSSESS               = 17244,    // the charm on player
    SPELL_POSSESSED             = 17246,    // the damage debuff on player
    SPELL_POSSESS_INV           = 17250     // baroness becomes invisible while possessing a target
};

class boss_baroness_anastari_dc : public CreatureScript
{
public:
    boss_baroness_anastari_dc() : CreatureScript("boss_baroness_anastari_dc") { }

    struct boss_baroness_anastari_dcAI : public BossAI
    {
        boss_baroness_anastari_dcAI(Creature* creature) : BossAI(creature, TYPE_ZIGGURAT1)
        {
        }

        void Reset() override
        {
            _possessedTargetGuid.Clear();

            instance->DoRemoveAurasDueToSpellOnPlayers(SPELL_POSSESS);
            instance->DoRemoveAurasDueToSpellOnPlayers(SPELL_POSSESSED);
            me->RemoveAurasDueToSpell(SPELL_POSSESS_INV);

            _scheduler.CancelAll();

            _scheduler.SetValidator([this]
            {
                return !me->HasUnitState(UNIT_STATE_CASTING);
            });
        }

        void JustEngagedWith(Unit* /*who*/) override
        {
            _scheduler.Schedule(1s, [this](TaskContext context){
                DoCastVictim(SPELL_BANSHEEWAIL);
                context.Repeat(4s);
            })
            .Schedule(11s, [this](TaskContext context){
                DoCastVictim(SPELL_BANSHEECURSE);
                context.Repeat(18s);
            })
            .Schedule(13s, [this](TaskContext context){
                DoCastVictim(SPELL_SILENCE);
                context.Repeat(13s);
            });

            SchedulePossession();
        }

        void JustDied(Unit* /*killer*/) override
        {
            instance->SetData(TYPE_ZIGGURAT1, IN_PROGRESS);
        }

        // Clear the possession state and re-arm the next possession. Must run on every
        // exit path out of the possession watchdog, including the one where the possessed
        // player can no longer be resolved.
        void EndPossession()
        {
            me->RemoveAurasDueToSpell(SPELL_POSSESS_INV);
            _possessedTargetGuid.Clear();
            SchedulePossession();
        }

        void SchedulePossession()
        {
            _scheduler.Schedule(20s, 30s, [this](TaskContext context){
                if (Unit* possessTarget = SelectTarget(SelectTargetMethod::Random, 1, 0, true, false))
                {
                    DoCast(possessTarget, SPELL_POSSESS, true);
                    DoCast(possessTarget, SPELL_POSSESSED, true);
                    DoCastSelf(SPELL_POSSESS_INV, true);
                    _possessedTargetGuid = possessTarget->GetGUID();

                    // We must keep track of the possessed player, the aura falls off when their health drops below 50%.
                    // The encounter resumes when the aura falls off.
                    _scheduler.Schedule(1s, [this](TaskContext possessionContext) {
                        if (Player* possessedTarget = ObjectAccessor::GetPlayer(*me, _possessedTargetGuid))
                        {
                            if (!possessedTarget->HasAura(SPELL_POSSESSED) || possessedTarget->HealthBelowPct(50))
                            {
                                possessedTarget->RemoveAurasDueToSpell(SPELL_POSSESS);
                                possessedTarget->RemoveAurasDueToSpell(SPELL_POSSESSED);
                                EndPossession();
                            }
                            else
                            {
                                possessionContext.Repeat(1s);
                            }
                        }
                        else
                        {
                            // The possessed player is gone (logout, teleport out, death removing
                            // them from the map). This watchdog is the only thing that strips
                            // SPELL_POSSESS_INV and re-arms possession, so returning here without
                            // rescheduling left the boss permanently invisible and never
                            // possessing again -- the group would have to force an evade.
                            EndPossession();
                        }
                    });
                }
                else
                {
                    // No valid possession targets found, retry.
                    context.Repeat(1s);
                }
            });
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
            {
                return;
            }

            _scheduler.Update(diff,
                std::bind(&ScriptedAI::DoMeleeAttackIfReady, this));
        }

    private:
        ObjectGuid _possessedTargetGuid;
        TaskScheduler _scheduler;
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return GetStratholmeDCAI<boss_baroness_anastari_dcAI>(creature);
    }
};

void AddSC_boss_baroness_anastari_dc()
{
    new boss_baroness_anastari_dc;
}
