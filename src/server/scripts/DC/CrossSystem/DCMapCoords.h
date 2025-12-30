#pragma once

#include "Define.h"

#include "DBCStores.h" // Map2ZoneCoordinates

#include <algorithm>

namespace DC
{
namespace MapCoords
{
    // Converts world coordinates into zone-normalized 0..1 values using Map2ZoneCoordinates.
    // Returns false if conversion bounds are unavailable for the given zone (tx/ty stay outside 0..100).
    inline bool TryComputeNormalized(uint32 zoneId, float x, float y, float& outNx, float& outNy)
    {
        if (zoneId == 0)
            return false;

        float tx = x;
        float ty = y;
        Map2ZoneCoordinates(tx, ty, zoneId);

        // If Map2ZoneCoordinates did not find bounds, tx/ty remain world coords (outside 0..100).
        if (tx < 0.0f || tx > 100.0f || ty < 0.0f || ty > 100.0f)
            return false;

        outNx = std::clamp(tx / 100.0f, 0.0f, 1.0f);
        outNy = std::clamp(ty / 100.0f, 0.0f, 1.0f);
        return true;
    }
}
}