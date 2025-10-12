#pragma once
#include <vector>
#include <deque>
#include "Position.h"
class Creature;
class WorldObject;

namespace DC_AC_Flight
{
class FlightPathHelper
{
public:
    explicit FlightPathHelper(Creature* owner) : _owner(owner) {}
    bool CalculateSmartPath(Position const& dest, std::vector<Position>& out);
    // Static helper variant for runtime testing: allow any WorldObject (Player, Creature, Unit)
    // to be used as the PathGenerator source. This does not depend on an instance _owner
    // and will not modify unit state. Returns true on a non-empty path in 'out'.
    static bool CalculateSmartPathForObject(WorldObject const* source, Position const& dest, std::vector<Position>& out);
    // Convenience: calculate smart path and filter tiny steps into an output queue
    bool CalculateAndQueue(Position const& dest, std::deque<Position>& outQueue, Creature* owner);
    void SmoothAndSetSpeed(float targetSpeed);

private:
    Creature* _owner = nullptr;
    std::deque<float> _speedHistory;
    static constexpr size_t kSpeedSmoothWindow = 4;
};
}


