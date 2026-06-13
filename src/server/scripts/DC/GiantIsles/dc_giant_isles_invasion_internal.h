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

        // War-beasts (summoned by the war-beast surge chaos pulse)
        NPC_ZANDALARI_WAR_DIREHORN      = 400361,
        NPC_ZANDALARI_PTERRORDAX_BOMBER = 400362,
        NPC_PRIMAL_DEVILSAUR            = 400363,

        // Loa ritual objective (wave 3): a destructible effigy the witch doctors
        // channel. Destroy it in time or the invaders are empowered by the Loa.
        NPC_LOA_EFFIGY                  = 400364,

        // Lane objective: the war standard each beached longboat plants. Cut it
        // down to scuttle that landing and choke off the lane's reinforcements.
        NPC_ZANDALARI_WAR_STANDARD      = 400366,

        // Defenders (neutral-friendly camp units summoned by the orchestrator)
        NPC_BEAST_HUNTER                = 401004,
        NPC_BEAST_HUNTER_VETERAN        = 401005,
        NPC_BEAST_HUNTER_TRAPPER        = 401006,
        NPC_BEAST_HUNTER_WARLORD        = 401007,

        // War economy (Phase 3): the quartermaster trades War-Tokens for goods.
        NPC_WAR_QUARTERMASTER           = 400365,
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
        INVADER_FACTION                 = 16,  // Monster group; hostile to all players
        DEFENDER_FACTION                = 250, // Player group; friendly to all players, HOSTILE to monsters/invaders
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
