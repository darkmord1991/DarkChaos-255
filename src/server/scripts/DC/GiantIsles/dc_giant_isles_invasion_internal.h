/*
 * Giant Isles - Invasion: internal bridge between the orchestrator and its NPCs
 * ==========================================================================
 * The invasion is split across three translation units:
 *   - dc_giant_isles_invasion.cpp      : the WorldMapScript orchestrator
 *                                        (stages, war plans, spawning, scoring,
 *                                        InfoBar) + the trigger horn.
 *   - dc_giant_isles_invasion_npcs.cpp : the creature AIs (invaders, defenders,
 *                                        objectives, warlord, general).
 *   - dc_giant_isles_warfront.cpp      : the content that outlives one assault
 *                                        (foothold camps, captives, sabotage,
 *                                        scouting, the War-God).
 * This header declares the small set of functions they call across the split
 * plus the entry ids / factions they share.
 * ==========================================================================
 */

#ifndef DC_GIANT_ISLES_INVASION_INTERNAL_H
#define DC_GIANT_ISLES_INVASION_INTERNAL_H

#include "ObjectGuid.h"

#include "dc_giant_isles_invasion.h"
#include "dc_giant_isles_invasion_data.h"

#include <string>
#include <vector>

class Creature;
class Map;
class Unit;

namespace DCGiantIsles
{
    enum InvasionNpc : uint32
    {
        NPC_INVASION_HORN               = 400325,

        // Invaders
        NPC_ZANDALARI_INVADER           = 400326,
        NPC_ZANDALARI_SCOUT             = 400327,
        NPC_ZANDALARI_SPEARMAN          = 400328,
        NPC_ZANDALARI_WARRIOR           = 400329,
        NPC_ZANDALARI_BERSERKER         = 400330,
        NPC_ZANDALARI_SHADOW_HUNTER     = 400331,
        NPC_ZANDALARI_BLOOD_GUARD       = 400332,
        NPC_ZANDALARI_WITCH_DOCTOR      = 400333,
        NPC_ZANDALARI_BEAST_TAMER       = 400334,
        NPC_ZANDALARI_WAR_RAPTOR        = 400335,
        NPC_WARLORD_ZULMAR              = 400336,
        NPC_ZANDALARI_HONOR_GUARD       = 400337,
        NPC_ZANDALARI_INVASION_LEADER   = 400338,

        // Kill-credit dummy shared by every invader (KillCredit1).
        NPC_INVADER_KILL_CREDIT         = 400339,

        // War-beasts (summoned by the war-beast surge chaos pulse)
        NPC_ZANDALARI_WAR_DIREHORN      = 400361,
        NPC_ZANDALARI_PTERRORDAX_BOMBER = 400362,
        NPC_PRIMAL_DEVILSAUR            = 400363,

        // Loa ritual objective: a destructible effigy the witch doctors channel.
        NPC_LOA_EFFIGY                  = 400364,

        // Lane objective: the war standard each beached longboat plants. Cut it
        // down to scuttle that landing and choke off the lane's reinforcements.
        NPC_ZANDALARI_WAR_STANDARD      = 400366,

        // Defenders (neutral-friendly camp units summoned by the orchestrator)
        NPC_BEAST_HUNTER                = 401004,
        NPC_BEAST_HUNTER_VETERAN        = 401005,
        NPC_BEAST_HUNTER_TRAPPER        = 401006,
        NPC_BEAST_HUNTER_WARLORD        = 401007,

        // Warden's Landing guards. Mobilized for the assault, stood down after.
        NPC_PRIMAL_GUARDIAN             = 401008,
        NPC_ANCIENT_PRIMAL_GUARDIAN     = 401009,

        // War economy: the quartermaster trades War-Tokens for goods.
        NPC_WAR_QUARTERMASTER           = 400365,

        // War front (static camps and the plans that use them)
        NPC_ZANDALARI_DINOMANCER        = 400580,
        NPC_WAR_GOD_DOKAH               = 400581,
        NPC_ZANDALARI_WAR_ENGINE        = 400582,
        NPC_ZANDALARI_ENGINE_CREW       = 400583,
        NPC_BINDING_PYLON               = 400584,
        NPC_BOUND_BEHEMOTH              = 400585,
        NPC_ZANDALARI_BEASTMASTER       = 400586,
        NPC_STAMPEDING_DIREHORN         = 400587,
        NPC_ZANDALARI_SKY_CALLER        = 400588,
        NPC_ELDER_ZULJIN_BATTLE         = 400589,
        NPC_CAPTIVE_BEAST_HUNTER        = 400590,
        NPC_SCOUT_MARKER_CANOES         = 400591,
        NPC_SCOUT_MARKER_WAR_CAMP       = 400592,
        NPC_SCOUT_MARKER_BUNKERS        = 400593,
        NPC_EXPEDITION_MEDIC            = 400594,
        NPC_IMPACT_MARKER               = 400595,
        NPC_ROGUE_TYRANT                = 400596,
        NPC_CREDIT_WAR_STANDARD         = 400597,
        NPC_CREDIT_WAR_PLAN             = 400598,
        NPC_CREDIT_ENGINE_SABOTAGED     = 400599,
    };

    enum InvasionGameObject : uint32
    {
        GO_ZANDALARI_POWDER_CHARGE      = 700040,
    };

    enum InvasionQuest : uint32
    {
        QUEST_HOLD_THE_SHORE            = 400340,
        QUEST_REPEL_THE_INCURSION       = 400341,
        QUEST_SMOKE_ON_THE_HORIZON      = 400344,
        QUEST_BLOOD_AND_BONE            = 400345,
        QUEST_THE_HIGH_RITUALIST        = 400346,
        QUEST_THE_WAR_GODS_DECK         = 400347,
        QUEST_CUT_THEIR_CHAINS          = 400348,
        QUEST_SPIKE_THE_ENGINES         = 400349,
        QUEST_THIN_THE_BINDERS          = 400350,
        QUEST_SCUTTLE_THE_LONGBOATS     = 400351,
        QUEST_BREAK_THE_WAR_PLAN        = 400352,
        QUEST_THE_WARLORDS_HEAD         = 400353,
    };

    enum InvasionItem : uint32
    {
        // Currency awarded by the invasion, scaled by personal contribution,
        // and spent at the War Quartermaster (gossip exchange, no DBC cost).
        WAR_TOKEN_ITEM                  = 400456,
    };

    enum InvasionFaction : uint32
    {
        // See dc_giant_isles_invasion.cpp for the full faction rationale.
        INVADER_FACTION                 = 16,   // Monster group; hostile to all players
        DEFENDER_FACTION                = 250,  // Player group; friendly to all players, HOSTILE to monsters/invaders
        ROGUE_BEAST_FACTION             = 1925, // Monster group; hostile to players AND other monsters
    };

    enum InvasionAiData : uint32
    {
        DATA_MARCH_ROUTE                = 1,    // SetData: start marching this MarchRoute
        DATA_MARCH_RESUME               = 2,    // SetData: re-send the current march leg
        DATA_MARCH_ROUTE_DELAYED        = 3,    // SetData: as ROUTE, once a jump has landed
    };

    enum InvasionAiAction : int32
    {
        ACTION_LEADER_COME_ASHORE       = 1,    // Rak'zor takes the field himself
        ACTION_LEADER_STAND_DOWN        = 2,    // Rak'zor returns to the ship
        ACTION_DROP_FIRE                = 3,    // impact marker: rain fire here
        ACTION_ZULJIN_CHARGE            = 4,    // Elder Zul'jin: order the counter-charge
        ACTION_ZULJIN_RECKONING         = 5,    // Elder Zul'jin: warn of Rak'zor
        ACTION_ZULJIN_VICTORY           = 6,    // Elder Zul'jin: closing words
        ACTION_ROGUE_ARRIVES            = 7,    // rogue devilsaur: announce itself
    };

    enum InvasionMovePoint : uint32
    {
        POINT_MARCH                     = 1405,
    };

    // Narration lines for General Rak'zor (creature_text groups of 400338).
    enum LeaderTextGroup : uint8
    {
        LEADER_SAY_OMENS                = 0,
        LEADER_SAY_LANDFALL             = 1,
        LEADER_SAY_ONSLAUGHT            = 2,
        LEADER_SAY_SIEGE                = 3,
        LEADER_SAY_WARLORD              = 4,
        LEADER_SAY_RETREAT              = 5,
        LEADER_SAY_TRIUMPH              = 6,
        LEADER_SAY_RECKONING            = 7,
        LEADER_SAY_PLAN_LOA             = 8,
        LEADER_SAY_PLAN_STAMPEDE        = 9,
        LEADER_SAY_PLAN_SKY_RAID        = 10,
        LEADER_SAY_PLAN_IRON_RAIN       = 11,
        LEADER_SAY_PLAN_BINDING         = 12,
    };
}

// Implemented by the orchestrator (dc_giant_isles_invasion.cpp), called from
// the NPC AIs (dc_giant_isles_invasion_npcs.cpp).
bool GI_IsInvasionActive();
bool GI_IsBattleRunning();
void GI_RegisterSummonedInvader(Creature* creature);
void GI_MaintainBossGuards(Map* map);
void GI_NotifyBossDeath();
void GI_NotifyGeneralDeath();
void GI_InvaderReachedLine(Creature* invader);
void GI_DefenderDied(Creature* defender);
void GI_ObjectiveDestroyed(Creature* objective, std::vector<ObjectGuid> const& attackers);
void GI_CreditParticipants(Creature* victim, std::vector<ObjectGuid> const& attackers);
void GI_CallWarlordBeast(Creature* warlord);
bool GI_HasRoomForWarBeast(Map* map);

// Implemented by the orchestrator, called from the war front
// (dc_giant_isles_warfront.cpp).
uint32 GI_GetCampaignFoothold();
void GI_AddWarEffort(uint32 points);
void GI_NotifyWarGodSlain(Map* map);
std::string GI_BuildWarStatus();

// Implemented by the war front, called from the orchestrator. Spawning a game
// event touches global spawn data, so the map thread only records the wanted
// tier and the world thread applies it.
void GI_RequestFootholdSync(uint32 foothold);
void GI_RegisterWarFront();

// Implemented by the NPC unit (dc_giant_isles_invasion_npcs.cpp), called from
// the orchestrator. LeaderSay drives the ship leader's narration; the register
// hook lets the single AddSC entry point construct every invasion creature AI.
void GI_LeaderSay(Creature* leader, uint8 textGroup);
void GI_RegisterInvasionNpcs();

#endif // DC_GIANT_ISLES_INVASION_INTERNAL_H
