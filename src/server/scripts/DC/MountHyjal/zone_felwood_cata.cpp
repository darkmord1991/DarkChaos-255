/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Cataclysm-era Felwood content that lives on the downported continent (map 750).
 *
 * Map 750 is a coordinate-preserving copy of the Hyjal corner of Kalimdor, so it
 * also carries the Cata revamp of Felwood -- Whisperwind Grove, Wildheart Point
 * and Irontree Clearing. Those creatures were imported by
 * Custom/Custom feature SQLs/worlddb/HyjalCata/181_ and 183_ at the +3,700,000
 * offset; this file is the C++ half.
 *
 * Ported from CataTC src/server/scripts/Kalimdor/zone_felwood.cpp. The other
 * three scripts in that file (spell_swipe_honey, spell_beesbees,
 * spell_ruumbos_silly_dance) are deliberately NOT ported: they drive the Ruumbo
 * honey quests, whose NPCs (Honey Bunny 47308, Ferli 47558), item (Honey Glob
 * 62820) and quests (27989, 27995) were never downported, so the scripts would
 * be dead code. See the audit note in 186_.
 */

#include "CreatureScript.h"
#include "MotionMaster.h"
#include "Player.h"
#include "Random.h"
#include "ScriptedCreature.h"
#include "ScriptMgr.h"

enum WhisperwindLasher
{
    EVENT_CHECK_OOC             = 1,

    // Both of these exist in the stock 3.3.5 Spell.dbc -- verified against
    // Custom/CSV DBC/Spell.csv, no overlay row needed.
    SPELL_INFECTED_WOUND        = 52225,
    SPELL_STAND                 = 37752,

    // +3,700,000 Kalimdor-clone band (181_ / 186_).
    NPC_WHISPERWIND_LASHER      = 3747747,
    NPC_CORRUPTED_LASHER        = 3748387,

    FACTION_HOSTILE             = 14,
    CHANCE_HOSTILE              = 30
};

// EventMap::ScheduleEvent takes Milliseconds on this core, not a raw uint32.
constexpr Milliseconds DESPAWN_CHECK_FIRST = Milliseconds(20000);
constexpr Milliseconds DESPAWN_CHECK_RETRY = Milliseconds(5000);
constexpr float WANDER_DISTANCE = 8.0f;

// Clicking a lasher coaxes it upright. Most of the grove is merely dormant, but
// roughly a third of it has taken the corruption and turns on the player.
struct npc_whisperwind_lasher : public ScriptedAI
{
    npc_whisperwind_lasher(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        _events.Reset();
        _lasherClicked = false;
    }

    void OnSpellClick(Unit* clicker, bool& result) override
    {
        // result is false when every spellclick row was filtered out (conditions,
        // user type). Nothing was cast, so nothing should happen here either.
        if (!result || _lasherClicked)
        {
            return;
        }

        if (roll_chance_i(CHANCE_HOSTILE))
        {
            me->CastSpell(me, SPELL_INFECTED_WOUND, true);
            me->SetEntry(NPC_CORRUPTED_LASHER);
            me->SetFaction(FACTION_HOSTILE);
        }
        else
        {
            me->SetUnitFlag(UNIT_FLAG_NOT_SELECTABLE);
        }

        me->RemoveNpcFlag(UNIT_NPC_FLAG_SPELLCLICK);
        me->CastSpell(me, SPELL_STAND, true);
        me->GetMotionMaster()->MoveRandom(WANDER_DISTANCE);
        _events.ScheduleEvent(EVENT_CHECK_OOC, DESPAWN_CHECK_FIRST);
        _lasherClicked = true;

        if (Player* player = clicker->ToPlayer())
        {
            player->KilledMonsterCredit(NPC_WHISPERWIND_LASHER);
        }
    }

    void UpdateAI(uint32 diff) override
    {
        // Untouched lashers are scenery -- no combat, no timers, no melee.
        if (!_lasherClicked)
        {
            return;
        }

        _events.Update(diff);

        while (uint32 eventId = _events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_CHECK_OOC:
                    // Never yank a lasher out from under a player mid-fight.
                    if (!me->IsInCombat())
                    {
                        me->DespawnOrUnsummon();
                    }
                    else
                    {
                        _events.ScheduleEvent(EVENT_CHECK_OOC, DESPAWN_CHECK_RETRY);
                    }
                    break;
                default:
                    break;
            }
        }

        DoMeleeAttackIfReady();
    }

private:
    EventMap _events;
    bool _lasherClicked = false;
};

void AddSC_dc_felwood_cata()
{
    RegisterCreatureAI(npc_whisperwind_lasher);
}
