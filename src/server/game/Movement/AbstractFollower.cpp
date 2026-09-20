/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "AbstractFollower.h"
#include "Log.h"
#include "Unit.h"
#include <atomic>
#include <typeinfo>

namespace
{
    // Registering a follower on a unit that has already left the world is how a follower ends
    // up holding a dangling _target: RemoveAllFollowers() only ever runs from
    // Unit::RemoveFromWorld(), whose whole body is gated on IsInWorld(), so nothing would
    // clear the registration again. ~Unit() now sweeps the list, so this no longer crashes -
    // the log is here to name whoever issued the follow. Bounded because a caller that does
    // this once per tick (a pet AI re-issuing MoveFollow at a despawning target) would
    // otherwise flood Errors.log during a soak run.
    constexpr uint32 OutOfWorldTargetLogLimit = 50;
    std::atomic<uint32> OutOfWorldTargetLogCount = 0;
}

void AbstractFollower::SetTarget(Unit* unit)
{
    if (unit == _target)
        return;

    if (unit && !unit->IsInWorld())
    {
        // typeid reports AbstractFollower when the registration comes from the constructor (the
        // MotionMaster::MoveFollow/MoveChase path) and the concrete generator when an existing one is
        // re-targeted - that distinction is itself worth having.
        uint32 const seen = OutOfWorldTargetLogCount.fetch_add(1) + 1;
        if (seen <= OutOfWorldTargetLogLimit)
        {
            LOG_ERROR("movement", "AbstractFollower::SetTarget: {} registered on a target that is not in world{}. Target: {}",
                typeid(*this).name(),
                seen == OutOfWorldTargetLogLimit ? " (further occurrences suppressed)" : "",
                unit->GetDebugInfo());
        }
    }

    if (_target)
        _target->FollowerRemoved(this);

    _target = unit;
    if (_target)
        _target->FollowerAdded(this);
}
