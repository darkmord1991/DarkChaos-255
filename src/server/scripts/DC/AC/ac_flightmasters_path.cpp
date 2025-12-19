#include "ac_flightmasters_path.h"
#include "FlightPathAccessor.h"
#include "FlightConstants.h"
#include "Creature.h"
#include "Map.h"
#include "Chat.h"
#include <numeric>
#include <cmath>

namespace
{
    constexpr float kMinGroundZ = -500.0f;
    constexpr float kMaxGroundZ = 2000.0f;

    float ClampToSaneGroundZ(float z, float fallback)
    {
        if (!std::isfinite(z) || z < kMinGroundZ || z > kMaxGroundZ)
            return fallback;
        return z;
    }

    float ProbeGroundZ(Map const* map, uint32 phaseMask, float x, float y, float referenceZ)
    {
        if (!map)
            return referenceZ;

        // Search downwards from above the higher endpoint; allow a larger search range than default.
        float probeFromZ = referenceZ + 250.0f;
        float h = map->GetHeight(phaseMask, x, y, probeFromZ, true /*vmap*/, 400.0f /*maxSearchDist*/);
        return ClampToSaneGroundZ(h, referenceZ);
    }

    uint32 PickControlPointCount(float dist2d)
    {
        if (dist2d < 120.0f)
            return 0;
        if (dist2d < 220.0f)
            return 2;
        if (dist2d < 360.0f)
            return 3;
        if (dist2d < 520.0f)
            return 4;
        return 6;
    }

    // Fractions biased to include a near-destination point for a safer approach.
    void BuildFractions(uint32 n, std::vector<float>& out)
    {
        out.clear();
        if (n == 0)
            return;

        out.reserve(n);
        switch (n)
        {
            case 2: out = { 0.35f, 0.85f }; break;
            case 3: out = { 0.25f, 0.55f, 0.85f }; break;
            case 4: out = { 0.20f, 0.40f, 0.60f, 0.85f }; break;
            case 5: out = { 0.15f, 0.35f, 0.55f, 0.70f, 0.85f }; break;
            default: out = { 0.12f, 0.28f, 0.44f, 0.60f, 0.72f, 0.85f }; break;
        }
    }

    bool SegmentHasLOS(Map const* map, uint32 phaseMask, Position const& a, Position const& b)
    {
        if (!map)
            return true;

        return map->isInLineOfSight(
            a.GetPositionX(), a.GetPositionY(), a.GetPositionZ(),
            b.GetPositionX(), b.GetPositionY(), b.GetPositionZ(),
            phaseMask, LINEOFSIGHT_ALL_CHECKS, VMAP::ModelIgnoreFlags::Nothing);
    }
}

bool FlightPathHelper::CalculateSmartPath(Position const& dest, std::vector<Position>& out)
{
    if (!_owner)
        return false;

    Map const* map = _owner->GetMap();
    uint32 phaseMask = _owner->GetPhaseMask();

    Position start = _owner->GetPosition();
    float dx = dest.GetPositionX() - start.GetPositionX();
    float dy = dest.GetPositionY() - start.GetPositionY();
    float dist2d = std::sqrt(dx * dx + dy * dy);

    uint32 controlPoints = PickControlPointCount(dist2d);

    float referenceZ = std::max(start.GetPositionZ(), dest.GetPositionZ());

    // For short hops, only engage the corridor solver when direct LOS is blocked.
    // This prevents unnecessary micro-pathing while still handling tree/terrain lips.
    if (controlPoints == 0)
    {
        if (!map)
        {
            out.clear();
            return false;
        }

        Position a = start;
        Position b = dest;
        float aGround = ProbeGroundZ(map, phaseMask, a.GetPositionX(), a.GetPositionY(), referenceZ);
        float bGround = ProbeGroundZ(map, phaseMask, b.GetPositionX(), b.GetPositionY(), referenceZ);
        a.m_positionZ = std::max(a.GetPositionZ(), aGround + Pathfinding::MIN_FLIGHT_CLEARANCE);
        b.m_positionZ = std::max(b.GetPositionZ(), bGround + Pathfinding::MIN_FLIGHT_CLEARANCE);

        if (SegmentHasLOS(map, phaseMask, a, b))
        {
            out.clear();
            return false;
        }

        controlPoints = 2;
    }

    std::vector<float> fractions;
    BuildFractions(controlPoints, fractions);

    out.clear();
    out.reserve(controlPoints);
    for (float t : fractions)
    {
        float x = start.GetPositionX() + dx * t;
        float y = start.GetPositionY() + dy * t;
        float lerpZ = start.GetPositionZ() + (dest.GetPositionZ() - start.GetPositionZ()) * t;
        float groundZ = ProbeGroundZ(map, phaseMask, x, y, referenceZ);

        float clearance = Pathfinding::MIN_FLIGHT_CLEARANCE;
        // If we're crossing near-ground geometry (trees/hills), bias to higher clearance.
        if (groundZ > lerpZ - 5.0f)
            clearance = Pathfinding::MAX_FLIGHT_CLEARANCE;

        float z = std::max(groundZ + clearance, lerpZ + Pathfinding::MIN_FLIGHT_CLEARANCE);
        out.emplace_back(x, y, z, 0.0f);
    }

    // Validate LoS for the corridor; if any segment is blocked, raise the corridor up.
    // Keep it bounded to avoid runaway Z.
    constexpr uint32 kMaxBumps = 5;
    constexpr float kBumpStepZ = 20.0f;
    for (uint32 bump = 0; bump <= kMaxBumps; ++bump)
    {
        bool ok = true;

        Position prev = start;
        for (Position const& p : out)
        {
            if (!SegmentHasLOS(map, phaseMask, prev, p))
            {
                ok = false;
                break;
            }
            prev = p;
        }
        // Check the last segment to an elevated destination probe (not the final waypoint Z)
        // so we don't fail the corridor just because the endpoint is near the ground.
        Position destProbe = dest;
        float destGround = ProbeGroundZ(map, phaseMask, destProbe.GetPositionX(), destProbe.GetPositionY(), referenceZ);
        destProbe.m_positionZ = std::max(destGround + Pathfinding::MIN_FLIGHT_CLEARANCE, destProbe.GetPositionZ() + Pathfinding::MIN_FLIGHT_CLEARANCE);
        if (ok && !SegmentHasLOS(map, phaseMask, prev, destProbe))
            ok = false;

        if (ok)
            return true;

        for (Position& p : out)
            p.m_positionZ += kBumpStepZ;
    }

    return !out.empty();
}

bool FlightPathHelper::CalculateSmartPathForObject(WorldObject const* source, Position const& dest, std::vector<Position>& out)
{
    if (!source)
        return false;

    Map const* map = source->GetMap();
    uint32 phaseMask = source->GetPhaseMask();

    Position start = source->GetPosition();
    float dx = dest.GetPositionX() - start.GetPositionX();
    float dy = dest.GetPositionY() - start.GetPositionY();
    float dist2d = std::sqrt(dx * dx + dy * dy);

    uint32 controlPoints = PickControlPointCount(dist2d);

    float referenceZ = std::max(start.GetPositionZ(), dest.GetPositionZ());

    if (controlPoints == 0)
    {
        if (!map)
        {
            out.clear();
            return false;
        }

        Position a = start;
        Position b = dest;
        float aGround = ProbeGroundZ(map, phaseMask, a.GetPositionX(), a.GetPositionY(), referenceZ);
        float bGround = ProbeGroundZ(map, phaseMask, b.GetPositionX(), b.GetPositionY(), referenceZ);
        a.m_positionZ = std::max(a.GetPositionZ(), aGround + Pathfinding::MIN_FLIGHT_CLEARANCE);
        b.m_positionZ = std::max(b.GetPositionZ(), bGround + Pathfinding::MIN_FLIGHT_CLEARANCE);

        if (SegmentHasLOS(map, phaseMask, a, b))
        {
            out.clear();
            return false;
        }

        controlPoints = 2;
    }

    std::vector<float> fractions;
    BuildFractions(controlPoints, fractions);

    out.clear();
    out.reserve(controlPoints);
    for (float t : fractions)
    {
        float x = start.GetPositionX() + dx * t;
        float y = start.GetPositionY() + dy * t;
        float lerpZ = start.GetPositionZ() + (dest.GetPositionZ() - start.GetPositionZ()) * t;
        float groundZ = ProbeGroundZ(map, phaseMask, x, y, referenceZ);
        float z = std::max(groundZ + Pathfinding::MIN_FLIGHT_CLEARANCE, lerpZ + Pathfinding::MIN_FLIGHT_CLEARANCE);
        out.emplace_back(x, y, z, 0.0f);
    }

    return !out.empty();
}

bool FlightPathHelper::CalculateAndQueue(Position const& dest, std::deque<Position>& outQueue, Creature* owner)
{
    std::vector<Position> tmp;
    if (!CalculateSmartPath(dest, tmp) || tmp.empty())
        return false;

    outQueue.clear();
    constexpr float minDistSq = Pathfinding::WAYPOINT_MIN_DISTANCE_SQ;
    float lastX = owner->GetPositionX();
    float lastY = owner->GetPositionY();
    for (auto const& p : tmp)
    {
        float dx = lastX - p.GetPositionX();
        float dy = lastY - p.GetPositionY();
        if ((dx*dx + dy*dy) > minDistSq)
        {
            outQueue.push_back(p);
            lastX = p.GetPositionX();
            lastY = p.GetPositionY();
        }
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
