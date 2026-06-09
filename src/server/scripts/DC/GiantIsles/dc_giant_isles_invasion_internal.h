/*
 * Giant Isles - Invasion: internal bridge between the orchestrator and its NPCs
 * ==========================================================================
 * The invasion is split across two translation units:
 *   - dc_giant_isles_invasion.cpp      : the WorldMapScript orchestrator
 *                                        (waves, spawning, scoring, InfoBar)
 *                                        + the trigger horn.
 *   - dc_giant_isles_invasion_npcs.cpp : the creature AIs (invaders, ship
 *                                        leader, warlord boss, questgiver).
 * This header declares the small set of functions they call across the split
 * plus the entry ids / factions both sides need.
 * ==========================================================================
 */

#ifndef DC_GIANT_ISLES_INVASION_INTERNAL_H
#define DC_GIANT_ISLES_INVASION_INTERNAL_H

#include "ObjectGuid.h"

#include "dc_giant_isles_invasion.h"

class Creature;
class Map;

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

        // Defenders (neutral-friendly camp units summoned by the orchestrator)
        NPC_BEAST_HUNTER                = 401004,
        NPC_BEAST_HUNTER_VETERAN        = 401005,
        NPC_BEAST_HUNTER_TRAPPER        = 401006,
        NPC_BEAST_HUNTER_WARLORD        = 401007,
    };

    enum InvasionFaction : uint32
    {
        // See dc_giant_isles_invasion.cpp for the full faction rationale.
        INVADER_FACTION                 = 16, // hostile to all players
        DEFENDER_FACTION                = 35, // friendly to all players
    };
}

// Implemented by the orchestrator (dc_giant_isles_invasion.cpp), called from
// the NPC AIs (dc_giant_isles_invasion_npcs.cpp).
bool GI_IsInvasionActive();
void GI_TrackPlayerKill(ObjectGuid playerGuid);
void GI_RegisterSummonedInvader(Creature* creature);
void GI_MaintainBossGuards(Map* map);
void GI_NotifyBossDeath();

// Implemented by the NPC unit (dc_giant_isles_invasion_npcs.cpp), called from
// the orchestrator. LeaderYell drives the ship leader's narration; the register
// hook lets the single AddSC entry point construct every invasion creature AI.
void GI_LeaderYell(Creature* leader, uint8 stage);
void GI_RegisterInvasionNpcs();

#endif // DC_GIANT_ISLES_INVASION_INTERNAL_H
