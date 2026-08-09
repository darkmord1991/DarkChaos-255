#include "HotspotJson.h"
#include "DBCStores.h"
#include "DBCStructure.h"

namespace DCHotspotJson
{

std::string ZoneName(uint32 zoneId)
{
    if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(zoneId))
        if (area->area_name[0] && area->area_name[0][0])
            return area->area_name[0];

    return "Unknown Zone";
}

// Seconds until expiry, clamped at 0 so a hotspot that dies between the caller's
// filter and this call cannot underflow into a huge uint32.
static uint32 SecondsRemaining(Hotspot const& hotspot, time_t now)
{
    if (hotspot.expireTime <= now)
        return 0;

    return static_cast<uint32>(hotspot.expireTime - now);
}

DCAddon::JsonValue Compact(Hotspot const& hotspot, uint32 xpBonus, time_t now)
{
    DCAddon::JsonValue h;
    h.SetObject();
    h.Set("i", DCAddon::JsonValue(hotspot.id));
    h.Set("m", DCAddon::JsonValue(hotspot.mapId));
    h.Set("z", DCAddon::JsonValue(hotspot.zoneId));
    h.Set("n", DCAddon::JsonValue(ZoneName(hotspot.zoneId)));
    h.Set("x", DCAddon::JsonValue(hotspot.x));
    h.Set("y", DCAddon::JsonValue(hotspot.y));
    h.Set("h", DCAddon::JsonValue(hotspot.z));
    h.Set("t", DCAddon::JsonValue(SecondsRemaining(hotspot, now)));
    h.Set("b", DCAddon::JsonValue(xpBonus));
    return h;
}

DCAddon::JsonValue Verbose(Hotspot const& hotspot, uint32 xpBonus, time_t now)
{
    DCAddon::JsonValue h;
    h.SetObject();
    h.Set("id", DCAddon::JsonValue(hotspot.id));
    h.Set("mapId", DCAddon::JsonValue(hotspot.mapId));
    h.Set("zoneId", DCAddon::JsonValue(hotspot.zoneId));
    h.Set("zoneName", DCAddon::JsonValue(ZoneName(hotspot.zoneId)));
    h.Set("x", DCAddon::JsonValue(hotspot.x));
    h.Set("y", DCAddon::JsonValue(hotspot.y));
    h.Set("z", DCAddon::JsonValue(hotspot.z));
    h.Set("timeRemaining", DCAddon::JsonValue(SecondsRemaining(hotspot, now)));
    h.Set("bonusPercent", DCAddon::JsonValue(xpBonus));
    h.Set("name", DCAddon::JsonValue("Hotspot"));
    return h;
}

DCAddon::JsonValue SpawnEvent(Hotspot const& hotspot)
{
    DCAddon::JsonValue h;
    h.SetObject();
    h.Set("id", DCAddon::JsonValue(hotspot.id));
    h.Set("mapId", DCAddon::JsonValue(hotspot.mapId));
    h.Set("zoneId", DCAddon::JsonValue(hotspot.zoneId));
    h.Set("x", DCAddon::JsonValue(hotspot.x));
    h.Set("y", DCAddon::JsonValue(hotspot.y));
    h.Set("z", DCAddon::JsonValue(hotspot.z));
    h.Set("action", DCAddon::JsonValue("spawn"));
    return h;
}

DCAddon::JsonValue ExpireEvent(uint32 hotspotId)
{
    DCAddon::JsonValue h;
    h.SetObject();
    h.Set("id", DCAddon::JsonValue(hotspotId));
    h.Set("action", DCAddon::JsonValue("expire"));
    return h;
}

} // namespace DCHotspotJson
