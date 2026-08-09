#ifndef DC_HOTSPOT_JSON_H
#define DC_HOTSPOT_JSON_H

#include "HotspotDefines.h"
#include "../AddonExtension/dc_addon_namespace.h"
#include <string>

// Single owner of every hotspot wire shape. Four call sites used to hand-roll
// these objects (dc_addon_hotspot, dc_addon_world, HotspotMgr's spawn/expire
// push and cs_dc_stresstest), which is how the stresstest ended up re-reading
// the table instead of the grid and how three separate zone-name helpers grew.
//
// The two payload shapes are NOT interchangeable - they are different client
// contracts and the key names are load-bearing:
//   Compact -> HOTSPOT module (short keys, sent per request; size matters)
//   Verbose -> WORLD  module (long keys, part of the content snapshot)
namespace DCHotspotJson
{
    // Localised zone name, "Unknown Zone" when the id is not in AreaTable.dbc.
    std::string ZoneName(uint32 zoneId);

    // HOTSPOT module: i=id, m=mapId, z=zoneId, n=zoneName, x/y/h=coords,
    // t=secondsRemaining, b=bonusPercent ('h' for height; 'z' was taken).
    DCAddon::JsonValue Compact(Hotspot const& hotspot, uint32 xpBonus, time_t now);

    // WORLD module content snapshot entry.
    DCAddon::JsonValue Verbose(Hotspot const& hotspot, uint32 xpBonus, time_t now);

    // WORLD module push entries (SMSG_UPDATE "hotspots" array).
    DCAddon::JsonValue SpawnEvent(Hotspot const& hotspot);
    DCAddon::JsonValue ExpireEvent(uint32 hotspotId);
}

#endif
