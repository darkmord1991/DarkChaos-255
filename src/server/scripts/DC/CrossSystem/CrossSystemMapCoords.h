#pragma once

#include "Define.h"

#include "DBCStores.h" // Map2ZoneCoordinates
#include "WorldPacket.h"
#include "Opcodes.h"

#include <algorithm>
#include <string>

class Player;

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
            // Note: bounds are (locLeft, locRight, locTop, locBottom) from WorldMapArea.csv
            // nx = (locLeft - x) / (locLeft - locRight)
            // ny = (locTop - y) / (locTop - locBottom)
            static constexpr WorldMapAreaBounds CustomBounds[] = {
                // Azshara Crater (MapID 37, AreaID 268)
                // WorldMapArea.csv: "613","37","268","AzsharaCrater","2427","-1884","1756","-1116"
                { 268u,  2427.0f,   -1884.0f,  1756.0f,   -1116.0f  },
                // Isles of Giants (MapID 1405, AreaID 5006)
                // WorldMapArea.csv: "1100","1405","5006","IslesofGiants","2132,02","2,91039","6932,32","5334,3"
                { 5006u, 2132.02f,  2.91039f,  6932.32f,  5334.3f   },
                // Stratholme Valley (MapID 850, AreaID 6000)
                // WorldMapArea.csv: "1200","850","6000","Strathlevel","-1766,667","-5166,667","4333,333","2066,667"
                { 6000u, -1766.667f,-5166.667f, 4333.333f, 2066.667f },
                // Hyjal Frontier (MapID 1410, AreaID 6100)
                // WorldMapArea.csv: "1202","1410","6100","Hyjal Frontier","-1525","-4025","6145,833","4479,167"
                { 6100u, -1525.0f,  -4025.0f,  6145.833f, 4479.167f },
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

    // Send a minimap / world-map Point of Interest packet to one player.
    // Unlike PlayerMenu::SendPointOfInterest this sends arbitrary coords without
    // requiring a DB-backed points_of_interest row.
    inline void SendPoiMarker(Player* player, float x, float y, uint32 icon,
                              uint32 flags, uint32 importance, std::string const& name)
    {
        if (!player || !player->GetSession())
            return;

        WorldPacket data(SMSG_GOSSIP_POI, 4 + 4 + 4 + 4 + 4 + 20);
        data << uint32(flags);
        data << float(x);
        data << float(y);
        data << uint32(icon);
        data << uint32(importance);
        data << name;
        player->GetSession()->SendPacket(&data);
    }
}
}

// Canonical namespace alias
namespace DarkChaos
{
namespace CrossSystem
{
    namespace MapCoords = ::DC::MapCoords;
}
}
