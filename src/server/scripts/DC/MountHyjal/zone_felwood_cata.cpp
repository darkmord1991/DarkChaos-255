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
 *
 * Also here: the map-750 copy of the stock Cenarion Beacon gossip
 * (npcs_riverbreeze_and_silversky in src/server/scripts/Kalimdor/zone_felwood.cpp),
 * so the stock script stays untouched. See npc_dc_riverbreeze_and_silversky below.
 */

#include "CreatureScript.h"
#include "MotionMaster.h"
#include "Player.h"
#include "Random.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
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

// ---------------------------------------------------------------------------
// Arathandris Silversky / Maybess Riverbreeze -- Cleansing Felwood and the Salve quests
// ---------------------------------------------------------------------------
// The map-750 copies 3709528 / 3709529 offer the +100000 copies of the Felwood
// quests (104101 Cleansing Felwood and 104103-104112 for the Alliance, 104102 and
// 105882-105891 for the Horde). They used to run the stock script, which compares
// the creature entry with 9528 / 9529: on the copies it matched neither NPC and
// sent no window at all, so none of those quests could be taken.
enum DCRiverbreezeAndSilversky
{
    SPELL_CENARION_BEACON           = 15120,
    ITEM_CENARION_BEACON            = 11511,
    ACTION_CREATE_CENARION_BEACON   = GOSSIP_ACTION_INFO_DEF + 1,

    // +3,700,000 Kalimdor-clone band
    NPC_DC_ARATHANDRIS_SILVERSKY    = 3709528,
    NPC_DC_MAYBESS_RIVERBREEZE      = 3709529,

    // Cleansing Felwood on map 750 (stock 4101 / 4102 + 100000)
    QUEST_DC_CLEANSING_FELWOOD_A    = 104101,
    QUEST_DC_CLEANSING_FELWOOD_H    = 104102,

    // the stock menus and texts
    GOSSIP_MENU_SILVERSKY           = 2208,
    GOSSIP_MENU_RIVERBREEZE         = 21400,
    GOSSIP_OPTION_BEACON            = 0,

    TEXT_SILVERSKY_DONE             = 2848,
    TEXT_SILVERSKY_HORDE            = 2845,
    TEXT_SILVERSKY_NOT_DONE         = 2844,
    TEXT_RIVERBREEZE_DONE           = 2849,
    TEXT_RIVERBREEZE_ALLIANCE       = 2843,
    TEXT_RIVERBREEZE_NOT_DONE       = 2842
};

class npc_dc_riverbreeze_and_silversky : public CreatureScript
{
public:
    npc_dc_riverbreeze_and_silversky() : CreatureScript("npc_dc_riverbreeze_and_silversky") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        switch (creature->GetEntry())
        {
            case NPC_DC_ARATHANDRIS_SILVERSKY:
                SendBeaconMenu(player, creature, QUEST_DC_CLEANSING_FELWOOD_A, GOSSIP_MENU_SILVERSKY,
                    TEXT_SILVERSKY_DONE,
                    player->GetTeamId() == TEAM_HORDE ? TEXT_SILVERSKY_HORDE : TEXT_SILVERSKY_NOT_DONE);
                break;
            case NPC_DC_MAYBESS_RIVERBREEZE:
                SendBeaconMenu(player, creature, QUEST_DC_CLEANSING_FELWOOD_H, GOSSIP_MENU_RIVERBREEZE,
                    TEXT_RIVERBREEZE_DONE,
                    player->GetTeamId() == TEAM_ALLIANCE ? TEXT_RIVERBREEZE_ALLIANCE : TEXT_RIVERBREEZE_NOT_DONE);
                break;
            default:
                // Assigned to some other creature: still open its quest list rather than nothing.
                SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
                break;
        }

        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);

        if (action == ACTION_CREATE_CENARION_BEACON)
        {
            CloseGossipMenuFor(player);
            creature->CastSpell(player, SPELL_CENARION_BEACON, false);
        }

        return true;
    }

private:
    // Whoever finished this NPC's Cleansing Felwood can get a lost Cenarion Beacon back; the Salve quests need it.
    static void SendBeaconMenu(Player* player, Creature* creature, uint32 questId, uint32 menuId, uint32 doneText,
        uint32 otherText)
    {
        if (!player->GetQuestRewardStatus(questId))
        {
            SendGossipMenuFor(player, otherText, creature->GetGUID());
            return;
        }

        if (!player->HasItemCount(ITEM_CENARION_BEACON, 1, true))
            AddGossipItemFor(player, menuId, GOSSIP_OPTION_BEACON, GOSSIP_SENDER_MAIN, ACTION_CREATE_CENARION_BEACON);

        SendGossipMenuFor(player, doneText, creature->GetGUID());
    }
};

void AddSC_dc_felwood_cata()
{
    RegisterCreatureAI(npc_whisperwind_lasher);
    new npc_dc_riverbreeze_and_silversky();
}
