#include "HotspotDefines.h"
#include "Player.h"

// Define global config instance
HotspotsConfig sHotspotsConfig;

bool Hotspot::IsPlayerInRange(Player* player) const
{
    if (!player)
        return false;

    if (player->GetMapId() != mapId)
        return false;

    float dx = player->GetPositionX() - x;
    float dy = player->GetPositionY() - y;
    float dz = player->GetPositionZ() - z;
    float dist2 = dx*dx + dy*dy + dz*dz;

    return dist2 <= (sHotspotsConfig.radius * sHotspotsConfig.radius);
}
