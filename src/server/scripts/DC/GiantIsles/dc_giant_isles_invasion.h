/*
 * Giant Isles - Invasion: shared constants
 * ==========================================================================
 * Small, dependency-free header so the WRLD addon aggregator
 * (dc_addon_world.cpp) and the invasion script (dc_giant_isles_invasion.cpp)
 * agree on the event id and the world-state ids that describe the invasion.
 * ==========================================================================
 */

#ifndef DC_GIANT_ISLES_INVASION_H
#define DC_GIANT_ISLES_INVASION_H

#include "Define.h"

namespace DCGiantIsles
{
    // Map the invasion runs on (ported Isle of Giants) and its top-level zone.
    constexpr uint32 INVASION_MAP_ID    = 1405;
    constexpr uint32 INVASION_ZONE_ID   = 5006;

    // Stable id used by the DC-InfoBar Events feed so EVNT pushes and the WRLD
    // snapshot upsert the SAME record instead of duplicating it.
    constexpr uint32 INVASION_EVENT_ID  = 14050001;

    // Number of attack waves (3 assault waves + the warlord wave).
    constexpr uint32 INVASION_MAX_WAVES = 4;

    // World states mirrored by the invasion script. Read by the WRLD addon
    // aggregator to expose the invasion in the world-content snapshot.
    //
    // This block is private to the invasion on purpose: the 20000-range ids it
    // used before overlap the core's own timers in WorldStateDefines.h (20001
    // is the arena point distribution, 20002 the weekly quest reset).
    constexpr uint32 WS_INVASION_ACTIVE     = 14050000;
    constexpr uint32 WS_INVASION_WAVE       = 14050001;
    constexpr uint32 WS_INVASION_KILLS      = 14050002;
    constexpr uint32 WS_INVASION_LAST_END   = 14050003;
    // Persistent campaign progress: how deep a foothold the Zandalari hold.
    constexpr uint32 WS_INVASION_CAMPAIGN   = 14050004;
    // Persistent war effort banked by the war-camp dailies for the next assault.
    constexpr uint32 WS_INVASION_WAR_EFFORT = 14050005;
}

#endif // DC_GIANT_ISLES_INVASION_H
