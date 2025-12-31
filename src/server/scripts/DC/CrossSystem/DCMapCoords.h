#pragma once

#include "Define.h"

#include "DBCStores.h" // Map2ZoneCoordinates

#include <algorithm>

namespace DC
{
namespace MapCoords
{
    struct WorldMapAreaBounds
    {
        uint32 zoneId;
        float locLeft;
        float locRight;
        float locTop;
        float locBottom;
    };

    // Fallback for custom zones whose WorldMapArea bounds are not available to the server
    // via DBCStores (Map2ZoneCoordinates).
    // Values are taken from Custom/CSV DBC/WorldMapArea.csv.
    inline bool TryComputeNormalizedFromBounds(WorldMapAreaBounds const& b, float x, float y, float& outNx, float& outNy)
    {
        float const width = (b.locLeft - b.locRight);
        float const height = (b.locTop - b.locBottom);
        if (width == 0.0f || height == 0.0f)
            return false;

        float const nx = (b.locLeft - x) / width;
        float const ny = (b.locTop - y) / height;

        if (nx < 0.0f || nx > 1.0f || ny < 0.0f || ny > 1.0f)
            return false;

        outNx = nx;
        outNy = ny;
        return true;
    }

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
        {
            // Custom zone fallback(s)
            static constexpr WorldMapAreaBounds CustomBounds[] = {
                // Isles of Giants (MapID 1405, AreaID 5006)
                { 5006u, 2132.02f, 2.91039f, 6932.32f, 5334.3f },
            };

            for (WorldMapAreaBounds const& b : CustomBounds)
            {
                if (b.zoneId == zoneId)
                    return TryComputeNormalizedFromBounds(b, x, y, outNx, outNy);
            }

            return false;
        }

        outNx = std::clamp(tx / 100.0f, 0.0f, 1.0f);
        outNy = std::clamp(ty / 100.0f, 0.0f, 1.0f);
        return true;
    }
}
}