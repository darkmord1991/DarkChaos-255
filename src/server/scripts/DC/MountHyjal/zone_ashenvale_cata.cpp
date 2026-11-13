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

/*
 * DarkChaos: Ashenvale on the downported continent (map 750).
 *
 * npc_dc_muglash is a copy of the stock npc_muglash (src/server/scripts/Kalimdor/zone_ashenvale.cpp) for the
 * map-750 Muglash 3712717; the stock script stays untouched. "Vorsha the Lasher" (6641) is still offered by the
 * stock Muglash in old Ashenvale, so map 750 has its own copy of the quest, 206641 (raw id + 200000). The stock
 * script cannot run it: it starts only for 6641, looks for the stock brazier and summons the level-20 naga and
 * Vorsha.
 *
 * Map 750 keeps Kalimdor's coordinates, so the path (script_waypoint, copied to 3712717) and the summon points are
 * the stock ones. The quest copy, Vorsha 3712940 and the waypoints come with the same world update; the map-750
 * brazier 3778247 already tells the nearest 3712717 when it is used (SmartAI, Do Action 0).
 *
 * One change from the stock behaviour: the waves are timed with an EventMap instead of a hand-rolled counter. The
 * timing is the same: each wave comes 10 seconds after the last fight at the brazier ended.
 */

#include "CreatureScript.h"
#include "Player.h"
#include "Random.h"
#include "ScriptedCreature.h"
#include "ScriptedEscortAI.h"

enum DCMuglash
{
    SAY_MUG_START1              = 0,
    SAY_MUG_START2              = 1,
    SAY_MUG_BRAZIER             = 2,
    SAY_MUG_BRAZIER_WAIT        = 3,
    SAY_MUG_ON_GUARD            = 4,
    SAY_MUG_DONE                = 6,
    SAY_MUG_GRATITUDE           = 7,
    SAY_MUG_PATROL              = 8,
    SAY_MUG_RETURN              = 9,

    // "Vorsha the Lasher" on map 750 (stock 6641 + 200000)
    QUEST_DC_VORSHA             = 206641,

    // the map-750 Naga Brazier; when used, its SmartAI sends ACTION_EXTINGUISH_BRAZIER to the nearest 3712717
    GO_DC_NAGA_BRAZIER          = 3778247,
    ACTION_EXTINGUISH_BRAZIER   = 0,

    // the map-750 naga (level 88-91) and Vorsha (level 92)
    NPC_DC_WRATH_RIDER          = 3603713,
    NPC_DC_WRATH_SORCERESS      = 3603717,
    NPC_DC_WRATH_RAZORTAIL      = 3703712,
    NPC_DC_WRATH_PRIESTESS      = 3603944,
    NPC_DC_WRATH_MYRMIDON       = 3603711,
    NPC_DC_WRATH_SEAWITCH       = 3703715,
    NPC_DC_VORSHA               = 3712940,

    WAYPOINT_START              = 0,
    WAYPOINT_BRAZIER            = 24,
    WAYPOINT_DONE               = 25,
    WAYPOINT_PATROL             = 26,
    WAYPOINT_RETURN             = 27,

    EVENT_NEXT_WAVE             = 1,

    WAVE_FIRST_NAGA             = 1,
    WAVE_SECOND_NAGA            = 2,
    WAVE_VORSHA                 = 3,
    WAVE_ALL_CLEAR              = 4
};

constexpr Milliseconds WAVE_DELAY = Milliseconds(10000);
constexpr uint32 SUMMON_DESPAWN_MS = 60000;  // out of combat

struct DCNagaSpawn
{
    uint32 Entry;
    Position Pos;
};

// The stock summon points.
DCNagaSpawn const DCFirstNagaWave[] =
{
    { NPC_DC_WRATH_RIDER,     { 3603.504150f, 1122.631104f,  1.635f, 0.0f } },
    { NPC_DC_WRATH_SORCERESS, { 3589.293945f, 1148.664063f,  5.565f, 0.0f } },
    { NPC_DC_WRATH_RAZORTAIL, { 3609.925537f, 1168.759521f, -1.168f, 0.0f } }
};

DCNagaSpawn const DCSecondNagaWave[] =
{
    { NPC_DC_WRATH_PRIESTESS, { 3609.925537f, 1168.759521f, -1.168f, 0.0f } },
    { NPC_DC_WRATH_MYRMIDON,  { 3645.652100f, 1139.425415f,  1.322f, 0.0f } },
    { NPC_DC_WRATH_SEAWITCH,  { 3583.602051f, 1128.405762f,  2.347f, 0.0f } }
};

Position const DCVorshaPos = { 3633.056885f, 1172.924072f, -5.388f, 0.0f };

struct npc_dc_muglash : public npc_escortAI
{
    npc_dc_muglash(Creature* creature) : npc_escortAI(creature) { }

    void Reset() override
    {
        _events.Reset();
        _waveId = 0;
        _isBrazierExtinguished = false;
    }

    void DoAction(int32 actionId) override
    {
        if (actionId != ACTION_EXTINGUISH_BRAZIER || _isBrazierExtinguished)
            return;

        Talk(SAY_MUG_BRAZIER_WAIT);
        _isBrazierExtinguished = true;
        _events.ScheduleEvent(EVENT_NEXT_WAVE, WAVE_DELAY);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        if (Player* player = GetPlayerForEscort())
            if (HasEscortState(STATE_ESCORT_PAUSED) && urand(0, 1))
                Talk(SAY_MUG_ON_GUARD, player);
    }

    void JustDied(Unit* /*killer*/) override
    {
        if (HasEscortState(STATE_ESCORT_ESCORTING))
            if (Player* player = GetPlayerForEscort())
                player->FailQuest(QUEST_DC_VORSHA);
    }

    void JustSummoned(Creature* summoned) override
    {
        summoned->AI()->AttackStart(me);
    }

    void sQuestAccept(Player* player, Quest const* quest) override
    {
        if (quest->GetQuestId() != QUEST_DC_VORSHA)
            return;

        Talk(SAY_MUG_START1);
        me->SetFaction(FACTION_ESCORTEE_N_NEUTRAL_PASSIVE);
        me->SetWalk(true);
        Start(true, player->GetGUID());
    }

    using CreatureAI::WaypointReached;
    void WaypointReached(uint32 waypointId) override
    {
        Player* player = GetPlayerForEscort();
        if (!player)
            return;

        switch (waypointId)
        {
            case WAYPOINT_START:
                Talk(SAY_MUG_START2, player);
                break;
            case WAYPOINT_BRAZIER:
                Talk(SAY_MUG_BRAZIER, player);
                WaitAtBrazier();
                break;
            case WAYPOINT_DONE:
                Talk(SAY_MUG_GRATITUDE);
                player->GroupEventHappens(QUEST_DC_VORSHA, me);
                break;
            case WAYPOINT_PATROL:
                Talk(SAY_MUG_PATROL);
                break;
            case WAYPOINT_RETURN:
                Talk(SAY_MUG_RETURN);
                break;
            default:
                break;
        }
    }

    void UpdateAI(uint32 diff) override
    {
        npc_escortAI::UpdateAI(diff);

        if (me->GetVictim())
        {
            DoMeleeAttackIfReady();
            return;
        }

        // The countdown to the next wave runs only while Muglash is out of combat.
        if (!HasEscortState(STATE_ESCORT_PAUSED) || !_isBrazierExtinguished)
            return;

        _events.Update(diff);
        while (uint32 eventId = _events.ExecuteEvent())
            if (eventId == EVENT_NEXT_WAVE)
                NextWave();
    }

private:
    // Muglash waits at the brazier until the player puts it out; the waves come from there.
    void WaitAtBrazier()
    {
        GameObject* brazier = GetClosestGameObjectWithEntry(me, GO_DC_NAGA_BRAZIER, INTERACTION_DISTANCE * 2);
        if (!brazier)
            return;

        brazier->RemoveGameObjectFlag(GO_FLAG_NOT_SELECTABLE);
        SetEscortPaused(true);
    }

    void NextWave()
    {
        switch (++_waveId)
        {
            case WAVE_FIRST_NAGA:
                SummonWave(DCFirstNagaWave);
                break;
            case WAVE_SECOND_NAGA:
                SummonWave(DCSecondNagaWave);
                break;
            case WAVE_VORSHA:
                me->SummonCreature(NPC_DC_VORSHA, DCVorshaPos, TEMPSUMMON_TIMED_DESPAWN_OUT_OF_COMBAT,
                    SUMMON_DESPAWN_MS);
                break;
            case WAVE_ALL_CLEAR:
                SetEscortPaused(false);
                Talk(SAY_MUG_DONE);
                return;
            default:
                return;
        }

        _events.ScheduleEvent(EVENT_NEXT_WAVE, WAVE_DELAY);
    }

    void SummonWave(DCNagaSpawn const (&wave)[3])
    {
        for (DCNagaSpawn const& naga : wave)
            me->SummonCreature(naga.Entry, naga.Pos, TEMPSUMMON_TIMED_DESPAWN_OUT_OF_COMBAT, SUMMON_DESPAWN_MS);
    }

    EventMap _events;
    uint8 _waveId = 0;
    bool _isBrazierExtinguished = false;
};

void AddSC_dc_ashenvale_cata()
{
    RegisterCreatureAI(npc_dc_muglash);
}
