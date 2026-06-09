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
    // Map the invasion runs on (ported Isle of Giants).
    constexpr uint32 INVASION_MAP_ID    = 1405;

    // Stable id used by the DC-InfoBar Events feed so EVNT pushes and the WRLD
    // snapshot upsert the SAME record instead of duplicating it.
    constexpr uint32 INVASION_EVENT_ID  = 14050001;

    // Number of attack waves (3 assault waves + the warlord wave).
    constexpr uint32 INVASION_MAX_WAVES = 4;

    // World states mirrored by the invasion script. Read by the WRLD addon
    // aggregator to expose the invasion in the world-content snapshot.
    constexpr uint32 WS_INVASION_ACTIVE = 20000;
    constexpr uint32 WS_INVASION_WAVE   = 20001;
    constexpr uint32 WS_INVASION_KILLS  = 20002;
}

#endif // DC_GIANT_ISLES_INVASION_H
