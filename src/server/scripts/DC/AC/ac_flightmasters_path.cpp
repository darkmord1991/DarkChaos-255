#include "ac_flightmasters_path.h"
#include "FlightPathAccessor.h"
#include "FlightConstants.h"
#include "PathGenerator.h"
#include "Chat.h"
#include <numeric>

namespace DC_AC_Flight
{
using namespace DC_AC_Flight::Pathfinding;

bool FlightPathHelper::CalculateSmartPath(Position const& dest, std::vector<Position>& out)
{
    if (!_owner)
        return false;

    std::unique_ptr<PathGenerator> pathGen = std::make_unique<PathGenerator>(_owner);
    pathGen->SetUseStraightPath(false);
    pathGen->SetUseRaycast(true);
    pathGen->SetPathLengthLimit(PATH_LENGTH_LIMIT);

    bool success = pathGen->CalculatePath(dest.GetPositionX(), dest.GetPositionY(), dest.GetPositionZ(), true);
    if (!success)
        return false;

    Movement::PointsArray const& points = pathGen->GetPath();
    out.clear();
    for (auto const& p : points)
    {
        // Dynamic Z offset for flight altitude with terrain awareness
        float groundZ = p.z;
        _owner->UpdateGroundPositionZ(p.x, p.y, groundZ);
        float clearance = MIN_FLIGHT_CLEARANCE;
        
        // Increase clearance over steep terrain or obstacles
        if (p.z > groundZ + 10.0f)
            clearance = MAX_FLIGHT_CLEARANCE;
        
        out.emplace_back(p.x, p.y, groundZ + clearance, 0.0f);
    }

    return !out.empty();
}

bool FlightPathHelper::CalculateSmartPathForObject(WorldObject const* source, Position const& dest, std::vector<Position>& out)
{
    if (!source)
        return false;

    std::unique_ptr<PathGenerator> pathGen = std::make_unique<PathGenerator>(source);
    pathGen->SetUseStraightPath(false);
    pathGen->SetUseRaycast(true);
    pathGen->SetPathLengthLimit(PATH_LENGTH_LIMIT);

    bool success = pathGen->CalculatePath(dest.GetPositionX(), dest.GetPositionY(), dest.GetPositionZ(), true);
    if (!success)
        return false;

    Movement::PointsArray const& points = pathGen->GetPath();
    out.clear();
    for (auto const& p : points)
    {
        // Use legacy fixed offset for static helper (no terrain context available)
        out.emplace_back(p.x, p.y, p.z + LEGACY_FIXED_OFFSET, 0.0f);
    }

    return !out.empty();
}

bool FlightPathHelper::CalculateAndQueue(Position const& dest, std::deque<Position>& outQueue, Creature* owner)
{
    std::vector<Position> tmp;
    if (!CalculateSmartPath(dest, tmp) || tmp.empty())
        return false;

    outQueue.clear();
    constexpr float minDistSq = WAYPOINT_MIN_DISTANCE_SQ;
    for (auto const& p : tmp)
    {
        float dx = owner->GetPositionX() - p.GetPositionX();
        float dy = owner->GetPositionY() - p.GetPositionY();
        if ((dx*dx + dy*dy) > minDistSq)
            outQueue.push_back(p);
    }

    return !outQueue.empty();
}

void FlightPathHelper::SmoothAndSetSpeed(float targetSpeed)
{
    if (!_owner)
        return;
    _speedHistory.push_back(targetSpeed);
    if (_speedHistory.size() > kSpeedSmoothWindow)
        _speedHistory.pop_front();
    float sum = std::accumulate(_speedHistory.begin(), _speedHistory.end(), 0.0f);
    float avg = sum / static_cast<float>(_speedHistory.size());
    _owner->SetSpeedRate(MOVE_FLIGHT, avg);
    _owner->SetSpeedRate(MOVE_RUN, avg);
}

} // namespace DC_AC_Flight
