/*
 * Giant Isles - Invasion: battlefield layout
 * ==========================================================================
 * Every position the invasion uses, in one place. They follow the real map:
 *
 *   West  Warden's Landing -- Seeping Shores -- the south plain -- Slimer Bay
 *         (defender line)     (landing lanes)    (the Warpath)     (canoes)
 *                                                                      |
 *   East  Ritual Grounds -- Bunker -- Bunker -- Zandalari War Camp ----+
 *
 * The flagship sits off the south-east shore, the tar pits fill the central
 * basin, and a cliff line separates that basin from the plain, so the two can
 * only be crossed on foot the long way round the island.
 *
 * March routes were derived from the server navmesh with legs short enough for
 * PathGenerator, and heights come from the terrain grid.
 * ==========================================================================
 */

#ifndef DC_GIANT_ISLES_INVASION_DATA_H
#define DC_GIANT_ISLES_INVASION_DATA_H

#include "Define.h"

#include <array>

namespace DCGiantIsles
{
    struct InvasionPoint
    {
        float x;
        float y;
        float z;
        float o;
    };

    // ----- Seeping Shores: the landing lanes and the defender line ------------

    // User-provided invader landing positions.
    inline constexpr std::array<InvasionPoint, 4> InvaderSpawnPoints =
    {{
        { 5764.2870f, 1156.7125f, 1.5225310f, 1.0770167f },
        { 5785.9243f, 1195.3062f, 2.9915880f, 1.2560875f },
        { 5811.5054f, 1164.1709f, 6.3400393f, 1.3785971f },
        { 5835.3057f, 1185.9261f, 7.4619540f, 2.1522145f },
    }};

    // User-provided defender setup points.
    inline constexpr std::array<InvasionPoint, 5> DefenderSpawnPoints =
    {{
        { 5773.8545f, 1279.0825f, 9.0212740f, 4.8602786f },
        { 5767.0710f, 1267.4742f, 4.4330260f, 5.5907025f },
        { 5783.7056f, 1274.3718f, 8.9616880f, 4.9522200f },
        { 5795.2460f, 1275.0509f, 8.3642630f, 4.2979894f },
        { 5772.1035f, 1290.6915f, 12.275494f, 4.8210610f },
    }};

    inline constexpr std::array<InvasionPoint, 4> LaneObjectives =
    {{
        { 5767.0710f, 1267.4742f, 4.4330260f, 5.5907025f },
        { 5773.8545f, 1279.0825f, 9.0212740f, 4.8602786f },
        { 5783.7056f, 1274.3718f, 8.9616880f, 4.9522200f },
        { 5795.2460f, 1275.0509f, 8.3642630f, 4.2979894f },
    }};

    inline constexpr InvasionPoint FrontlineAnchor =
        { 5772.1035f, 1290.6915f, 12.275494f, 4.8210610f };

    // Where the defenders push to once Elder Zul'jin orders the counter-charge.
    inline constexpr std::array<InvasionPoint, 4> AdvancedLine =
    {{
        { 5790.0f, 1235.0f, 5.1f, 4.9f },
        { 5806.0f, 1238.0f, 7.0f, 4.9f },
        { 5778.0f, 1238.0f, 2.2f, 4.9f },
        { 5814.0f, 1226.0f, 8.4f, 4.9f },
    }};

    // Fresh defenders jog down from the camp behind the line.
    inline constexpr InvasionPoint DefenderRallyPoint =
        { 5779.0f, 1322.0f, 24.1f, 4.75f };

    // Mid-beach contested ground (between the invader landing and the defender
    // line), so reaching the Loa effigy means pushing into the fight.
    inline constexpr InvasionPoint LoaRitualPos =
        { 5794.8f, 1230.3f, 6.1f, 4.95f };

    inline constexpr std::array<InvasionPoint, 3> LoaChannelerPoints =
    {{
        { 5806.0f, 1224.0f, 6.2f, 2.60f },
        { 5784.0f, 1222.0f, 2.4f, 0.70f },
        { 5796.0f, 1244.0f, 7.3f, 4.60f },
    }};

    // General Rak'zor's walk down the ramp when he comes ashore himself.
    inline constexpr InvasionPoint RakzorAshorePoint =
        { 5790.0f, 1195.0f, 2.9f, 1.25f };

    // ----- March routes -------------------------------------------------------

    enum MarchRoute : int32
    {
        ROUTE_NONE          = -1,
        ROUTE_LANE_0        = 0,
        ROUTE_LANE_1        = 1,
        ROUTE_LANE_2        = 2,
        ROUTE_LANE_3        = 3,
        ROUTE_WARPATH       = 4,    // Slimer Bay canoes, 600 yards along the plain
        ROUTE_EAST_FLANK    = 5,    // the last stretch of the Warpath
        ROUTE_TERRACE       = 6,    // down from the terrace above the line
        ROUTE_STAMPEDE_A    = 7,
        ROUTE_STAMPEDE_B    = 8,
        ROUTE_STAMPEDE_C    = 9,
        ROUTE_COUNT
    };

    struct MarchRouteView
    {
        InvasionPoint const* points;
        uint8 count;
    };

    inline constexpr std::array<InvasionPoint, 2> RouteLane0 =
    {{
        { 5783.0f, 1215.0f, 2.4f, 0.0f }, LaneObjectives[0],
    }};

    inline constexpr std::array<InvasionPoint, 2> RouteLane1 =
    {{
        { 5790.0f, 1240.0f, 5.6f, 0.0f }, LaneObjectives[1],
    }};

    inline constexpr std::array<InvasionPoint, 2> RouteLane2 =
    {{
        { 5805.0f, 1225.0f, 5.8f, 0.0f }, LaneObjectives[2],
    }};

    inline constexpr std::array<InvasionPoint, 2> RouteLane3 =
    {{
        { 5820.0f, 1235.0f, 8.8f, 0.0f }, LaneObjectives[3],
    }};

    inline constexpr std::array<InvasionPoint, 12> RouteWarpath =
    {{
        { 5790.4f,  822.2f,  3.7f, 0.0f },
        { 5834.7f,  864.0f, 13.2f, 0.0f },
        { 5834.7f,  906.7f, 17.1f, 0.0f },
        { 5834.7f,  970.7f, 23.5f, 0.0f },
        { 5834.7f,  992.0f, 24.0f, 0.0f },
        { 5795.9f, 1021.5f, 21.5f, 0.0f },
        { 5796.4f, 1062.3f,  6.2f, 0.0f },
        { 5834.7f, 1098.7f,  6.4f, 0.0f },
        { 5834.7f, 1162.7f,  9.5f, 0.0f },
        { 5816.5f, 1214.1f,  8.3f, 0.0f },
        { 5800.4f, 1272.0f,  9.3f, 0.0f },
        { 5792.0f, 1272.5f,  8.6f, 0.0f },
    }};

    inline constexpr std::array<InvasionPoint, 5> RouteEastFlank =
    {{
        { 5834.7f, 1098.7f,  6.4f, 0.0f },
        { 5834.7f, 1162.7f,  9.5f, 0.0f },
        { 5816.5f, 1214.1f,  8.3f, 0.0f },
        { 5800.4f, 1272.0f,  9.3f, 0.0f },
        { 5792.0f, 1272.5f,  8.6f, 0.0f },
    }};

    inline constexpr std::array<InvasionPoint, 3> RouteTerrace =
    {{
        { 5856.0f, 1269.3f, 38.8f, 0.0f },
        { 5801.5f, 1295.3f, 25.0f, 0.0f },
        { 5792.0f, 1272.5f,  8.6f, 0.0f },
    }};

    inline constexpr std::array<InvasionPoint, 3> RouteStampedeA =
    {{
        { 5868.0f, 1118.0f, 12.1f, 0.0f },
        { 5838.0f, 1190.0f,  7.5f, 0.0f },
        { 5805.0f, 1262.0f,  8.3f, 0.0f },
    }};

    inline constexpr std::array<InvasionPoint, 3> RouteStampedeB =
    {{
        { 5850.0f, 1108.0f,  8.5f, 0.0f },
        { 5822.0f, 1190.0f,  7.9f, 0.0f },
        { 5795.0f, 1262.0f,  7.1f, 0.0f },
    }};

    inline constexpr std::array<InvasionPoint, 3> RouteStampedeC =
    {{
        { 5832.0f, 1102.0f,  5.3f, 0.0f },
        { 5806.0f, 1190.0f,  5.8f, 0.0f },
        { 5782.0f, 1262.0f,  6.6f, 0.0f },
    }};

    inline MarchRouteView GetMarchRoute(int32 route)
    {
        switch (route)
        {
            case ROUTE_LANE_0:      return { RouteLane0.data(), static_cast<uint8>(RouteLane0.size()) };
            case ROUTE_LANE_1:      return { RouteLane1.data(), static_cast<uint8>(RouteLane1.size()) };
            case ROUTE_LANE_2:      return { RouteLane2.data(), static_cast<uint8>(RouteLane2.size()) };
            case ROUTE_LANE_3:      return { RouteLane3.data(), static_cast<uint8>(RouteLane3.size()) };
            case ROUTE_WARPATH:     return { RouteWarpath.data(), static_cast<uint8>(RouteWarpath.size()) };
            case ROUTE_EAST_FLANK:  return { RouteEastFlank.data(), static_cast<uint8>(RouteEastFlank.size()) };
            case ROUTE_TERRACE:     return { RouteTerrace.data(), static_cast<uint8>(RouteTerrace.size()) };
            case ROUTE_STAMPEDE_A:  return { RouteStampedeA.data(), static_cast<uint8>(RouteStampedeA.size()) };
            case ROUTE_STAMPEDE_B:  return { RouteStampedeB.data(), static_cast<uint8>(RouteStampedeB.size()) };
            case ROUTE_STAMPEDE_C:  return { RouteStampedeC.data(), static_cast<uint8>(RouteStampedeC.size()) };
            default:                return { nullptr, 0 };
        }
    }

    // ----- War plan objectives ------------------------------------------------

    // Stampede: the beastmasters drive the herd up the plain from the east.
    inline constexpr std::array<InvasionPoint, 3> BeastmasterPoints =
    {{
        { 5862.0f, 1130.0f, 9.6f, 2.20f },
        { 5842.0f, 1122.0f, 5.5f, 1.90f },
        { 5822.0f, 1118.0f, 6.0f, 1.60f },
    }};

    // Sky raid: the terrace above Warden's Landing, where MoP's dinomancers stood.
    inline constexpr InvasionPoint SkyCallerPoint =
        { 5857.5f, 1265.6f, 38.6f, 3.40f };

    inline constexpr InvasionPoint BomberOrbitCentre =
        { 5795.0f, 1262.0f, 34.0f, 0.0f };

    // Iron rain: beside the real zandalari_siegeweapon_01 doodads at the War Camp
    // and the lower bunker. The upper bunker's doodad stands inside the Alliance
    // camp's guard line, where the Primal Wardens would kill an engine unprompted,
    // so the third engine sits up the torch path instead.
    inline constexpr std::array<InvasionPoint, 3> WarEnginePoints =
    {{
        { 5861.0f, 759.0f, 17.7f, 3.14f },  // War Camp
        { 5930.0f, 836.0f, 44.5f, 3.14f },  // Lower bunker
        { 5958.0f, 774.0f, 37.5f, 3.14f },  // Torch path
    }};

    inline constexpr std::array<InvasionPoint, 6> EngineCrewPoints =
    {{
        { 5866.0f, 762.0f, 17.3f, 3.14f },
        { 5854.0f, 760.0f, 17.5f, 0.00f },
        { 5936.0f, 838.0f, 44.4f, 3.14f },
        { 5925.0f, 840.0f, 44.4f, 0.00f },
        { 5952.0f, 778.0f, 37.2f, 0.00f },
        { 5964.0f, 770.0f, 37.7f, 3.14f },
    }};

    // King's binding: the tar pits, on MoP's dinomancer ring.
    inline constexpr std::array<InvasionPoint, 4> BindingPylonPoints =
    {{
        { 6072.4f, 1120.0f, 56.0f, 3.33f },
        { 6010.1f, 1159.3f, 55.8f, 4.86f },
        { 6032.2f, 1054.5f, 56.9f, 1.77f },
        { 6060.8f, 1064.8f, 56.3f, 2.26f },
    }};

    // The bound behemoth throws itself off the basin rim onto the plain.
    inline constexpr InvasionPoint BehemothCliffPoint =
        { 5935.0f, 1180.0f, 70.7f, 3.40f };
    inline constexpr InvasionPoint BehemothLandingPoint =
        { 5840.0f, 1205.0f, 9.1f, 3.40f };

    // Bozzle's wreck: where the east flank comes ashore.
    inline constexpr InvasionPoint EastFlankLanding =
        { 5834.7f, 1098.7f, 6.4f, 1.57f };

    // Slimer Bay: where the Warpath column leaves the canoes.
    inline constexpr InvasionPoint WarpathLanding =
        { 5790.4f, 822.2f, 3.7f, 1.20f };

    // The terrace above the line, for the ambush chaos pulse.
    inline constexpr InvasionPoint TerraceAmbushPoint =
        { 5856.0f, 1269.3f, 38.8f, 3.40f };

    // Scout markers for "Smoke on the Horizon" live in the database; these are
    // only the spots a rogue devilsaur crashes in from.
    inline constexpr std::array<InvasionPoint, 2> RogueTyrantEntryPoints =
    {{
        { 5838.0f, 1190.0f, 7.5f, 2.10f },
        { 5822.0f, 1118.0f, 6.0f, 1.60f },
    }};
}

#endif // DC_GIANT_ISLES_INVASION_DATA_H
