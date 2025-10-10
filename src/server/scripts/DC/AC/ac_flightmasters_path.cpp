#include "ac_flightmasters_path.h"
#include "PathGenerator.h"
#include "Chat.h"
#include <numeric>

namespace DC_AC_Flight
{
bool FlightPathHelper::CalculateSmartPath(Position const& dest, std::vector<Position>& out)
{
    if (!_owner)
        return false;

    std::unique_ptr<PathGenerator> pathGen = std::make_unique<PathGenerator>(_owner);
    pathGen->SetUseStraightPath(false);
    pathGen->SetUseRaycast(true);
    pathGen->SetPathLengthLimit(200.0f);

    bool success = pathGen->CalculatePath(dest.GetPositionX(), dest.GetPositionY(), dest.GetPositionZ(), true);
    if (!success)
        return false;

    Movement::PointsArray const& points = pathGen->GetPath();
    out.clear();
    for (auto const& p : points)
    {
        // Small Z offset for flight altitude
        out.emplace_back(p.x, p.y, p.z + 6.0f, 0.0f);
    }

    if (Player* p = nullptr)
    {
        // No owner->GetVehicleKit() here; keep debug light.
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
    pathGen->SetPathLengthLimit(200.0f);

    bool success = pathGen->CalculatePath(dest.GetPositionX(), dest.GetPositionY(), dest.GetPositionZ(), true);
    if (!success)
        return false;

    Movement::PointsArray const& points = pathGen->GetPath();
    out.clear();
    for (auto const& p : points)
        out.emplace_back(p.x, p.y, p.z + 6.0f, 0.0f);

    return !out.empty();
}

bool FlightPathHelper::CalculateAndQueue(Position const& dest, std::deque<Position>& outQueue, Creature* owner)
{
    std::vector<Position> tmp;
    if (!CalculateSmartPath(dest, tmp) || tmp.empty())
        return false;

    outQueue.clear();
    for (auto const& p : tmp)
    {
        float dx = owner->GetPositionX() - p.GetPositionX();
        float dy = owner->GetPositionY() - p.GetPositionY();
        if ((dx*dx + dy*dy) > 9.0f)
            outQueue.push_back(p);
    }

    if (Player* p = nullptr) { /* no-op debug placeholder */ }
    return !outQueue.empty();
}

void FlightPathHelper::SmoothAndSetSpeed(float targetRate)
{
    if (!_owner)
        return;
    _speedHistory.push_back(targetRate);
    if (_speedHistory.size() > kSpeedSmoothWindow)
        _speedHistory.pop_front();
    float sum = std::accumulate(_speedHistory.begin(), _speedHistory.end(), 0.0f);
    float avg = sum / static_cast<float>(_speedHistory.size());
    _owner->SetSpeedRate(MOVE_FLIGHT, avg);
}

} // namespace DC_AC_Flight
