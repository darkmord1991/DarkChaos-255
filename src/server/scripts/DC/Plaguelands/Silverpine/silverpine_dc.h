/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
 * more details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#pragma once

// Silverpine Forest on map 751 (DC Plaguelands, the Lordaeron extension, zone 4935).
//
// Ported from Project Neltharion's 4.3.4 zone_silverpine_forest.cpp (the core that nelt_world,
// the 751 import's movement/addon source, came from). Behaviour is re-implemented on
// AzerothCore's API; ids follow the 751 import:
//   - creatures imported from cata_world sit at entry + 4,100,000 (62_/63_),
//   - gameobjects at entry + 4,600,000,
//   - creatures that spells summon by id were imported at their PLAIN Cata id (100_), because
//     a summon effect names that id. Check creature_template before picking either form.
//   - quest, spell, vehicle and text ids are not offset.
// The two Horde Haulers are deliberately not ported: 79_/83_/84_ made them persistent looping
// waypoint vehicles, where the source despawns them at the end of each run.

#include "Define.h"
#include "MotionMaster.h"
#include "MoveSplineInitArgs.h"
#include "Unit.h"

namespace SilverpineDC
{
    constexpr uint32 MAP_LORDAERON_751 = 751;
    constexpr uint32 ZONE_SILVERPINE_751 = 4935;

    constexpr uint32 CREATURE_OFFSET_751 = 4100000;
    constexpr uint32 GAMEOBJECT_OFFSET_751 = 4600000;

    // Entry of an imported (spawned) Cata creature on 751.
    constexpr uint32 Creature751(uint32 cataEntry) { return cataEntry + CREATURE_OFFSET_751; }

    // Entry of an imported Cata gameobject on 751.
    constexpr uint32 GameObject751(uint32 cataEntry) { return cataEntry + GAMEOBJECT_OFFSET_751; }

    // TrinityCore's MoveSmoothPath(Vector3[], size) does not exist here. Same shim as
    // MountHyjal/zone_azshara_cata.cpp: element 0 MUST be the unit's current position, because
    // MoveSplineInit::Launch overwrites args.path[0] with it and SplineHandler reports
    // currentPathIdx() - 1; the leading node makes the reported point ids match the source's
    // 1-based indices, so MovementInform(SPLINE_CHAIN/ESCORT...) still fires on the last node.
    inline void DoMoveSmoothPath(Unit* who, G3D::Vector3 const* path, uint32 size)
    {
        if (!who || !path || !size)
            return;

        Movement::PointsArray points;
        points.reserve(size + 1);
        points.push_back(G3D::Vector3(who->GetPositionX(), who->GetPositionY(), who->GetPositionZ()));
        for (uint32 i = 0; i < size; ++i)
            points.push_back(path[i]);

        who->GetMotionMaster()->MoveSplinePath(&points);
    }
}
