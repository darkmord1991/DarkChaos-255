#include "FlightRouteStrategy.h"
#include "FlightConstants.h"
#include <cmath>

// Helper: compute 2D distance
static float Distance2D(float x1, float y1, float x2, float y2)
{
    float dx = x1 - x2;
    float dy = y1 - y2;
    return std::sqrt(dx * dx + dy * dy);
}

// Helper: find nearest waypoint index
static uint8 FindNearestIndex(float x, float y, uint8 maxIndex)
{
    float bestDist = std::numeric_limits<float>::max();
    uint8 nearest = 0;
    
    for (uint8 i = 0; i <= maxIndex && i < kPathLength; ++i)
    {
        float dist = Distance2D(x, y, kPath[i].GetPositionX(), kPath[i].GetPositionY());
        if (dist < bestDist)
        {
            bestDist = dist;
            nearest = i;
        }
    }
    
    return nearest;
}

// ============================================================================
// RouteTour: Camp to Level 25+ (acfm1 -> L25_End)
// ============================================================================

uint8 RouteTour::GetStartIndex(float currentX, float currentY, float currentZ) const
{
    (void)currentZ;
    uint8 nearest = FindNearestIndex(currentX, currentY, kIndex_L25_End);
    // Clamp to L25_End to avoid starting past classic section
    if (nearest > kIndex_L25_End)
        nearest = kIndex_L25_End;
    return (nearest > 0) ? static_cast<uint8>(nearest - 1) : 0;
}

bool RouteTour::GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const
{
    if (currentIndex < kIndex_L25_End)
    {
        outNextIndex = static_cast<uint8>(currentIndex + 1);
        return true;
    }
    return false;
}

bool RouteTour::IsFinalIndex(uint8 index) const
{
    return index >= kIndex_L25_End;
}

FlightRouteMode RouteTour::GetMode() const
{
    return ROUTE_TOUR;
}

// ============================================================================
// RouteL40Direct: Camp to Level 40+ (acfm1 -> L40_End)
// ============================================================================

uint8 RouteL40Direct::GetStartIndex(float currentX, float currentY, float currentZ) const
{
    (void)currentZ;
    // Check if near L40_End
    float dist35 = Distance2D(currentX, currentY, kPath[kIndex_L40_End].GetPositionX(), kPath[kIndex_L40_End].GetPositionY());
    if (dist35 < Distance::START_NEARBY_THRESHOLD)
        return kIndex_L40_End;
    
    // Otherwise start from beginning
    return 0;
}

bool RouteL40Direct::GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const
{
    if (currentIndex < kIndex_L40_End)
    {
        outNextIndex = static_cast<uint8>(currentIndex + 1);
        return true;
    }
    return false;
}

bool RouteL40Direct::IsFinalIndex(uint8 index) const
{
    return index >= kIndex_L40_End;
}

FlightRouteMode RouteL40Direct::GetMode() const
{
    return ROUTE_L40_DIRECT;
}

// ============================================================================
// RouteL0To57: Camp to Level 60+ (acfm1 -> L60_End)
// ============================================================================

uint8 RouteL0To57::GetStartIndex(float currentX, float currentY, float currentZ) const
{
    (void)currentX; (void)currentY; (void)currentZ;
    return 0;
}

bool RouteL0To57::GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const
{
    if (currentIndex < kIndex_L60_End)
    {
        outNextIndex = static_cast<uint8>(currentIndex + 1);
        return true;
    }
    return false;
}

bool RouteL0To57::IsFinalIndex(uint8 index) const
{
    return index >= kIndex_L60_End;
}

FlightRouteMode RouteL0To57::GetMode() const
{
    return ROUTE_L0_TO_57;
}

// ============================================================================
// RouteReturn: Level 25+ to Camp (L25_End -> StartCamp)
// ============================================================================

uint8 RouteReturn::GetStartIndex(float currentX, float currentY, float currentZ) const
{
    (void)currentX; (void)currentY; (void)currentZ;
    // Always start from the designated L25 end point (18) to ensure the full return path is flown,
    // even if the player is standing at the old L25 location (index 14).
    return kIndex_L25_End;
}

bool RouteReturn::GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const
{
    if (currentIndex > 0 && currentIndex <= LastScenicIndex())
    {
        outNextIndex = static_cast<uint8>(currentIndex - 1);
        return true;
    }
    else if (currentIndex == 0)
    {
        outNextIndex = kIndex_startcamp;
        return true;
    }
    return false;
}

bool RouteReturn::IsFinalIndex(uint8 index) const
{
    return index == kIndex_startcamp;
}

FlightRouteMode RouteReturn::GetMode() const
{
    return ROUTE_RETURN;
}

// ============================================================================
// RouteL25To40: Level 25+ to Level 40+ (L25_Start -> L40_End)
// ============================================================================

uint8 RouteL25To40::GetStartIndex(float currentX, float currentY, float currentZ) const
{
    (void)currentZ;
    float dist19 = Distance2D(currentX, currentY, kPath[kIndex_L25_Start].GetPositionX(), kPath[kIndex_L25_Start].GetPositionY());
    
    // If near L25_Start, start one past it
    if (dist19 < Distance::START_NEARBY_THRESHOLD)
        return static_cast<uint8>(kIndex_L25_Start + 1);
    
    // If near L40_End, start one before it
    float dist35 = Distance2D(currentX, currentY, kPath[kIndex_L40_End].GetPositionX(), kPath[kIndex_L40_End].GetPositionY());
    if (dist35 < Distance::START_NEARBY_THRESHOLD)
        return static_cast<uint8>(kIndex_L40_End - 1);
    
    // Default: start from beginning
    return 0;
}

bool RouteL25To40::GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const
{
    if (currentIndex < kIndex_L40_End)
    {
        outNextIndex = static_cast<uint8>(currentIndex + 1);
        return true;
    }
    return false;
}

bool RouteL25To40::IsFinalIndex(uint8 index) const
{
    return index >= kIndex_L40_End;
}

FlightRouteMode RouteL25To40::GetMode() const
{
    return ROUTE_L25_TO_40;
}

// ============================================================================
// RouteL25To60: Level 25+ to Level 60+ (L25_Start -> L60_End)
// ============================================================================

uint8 RouteL25To60::GetStartIndex(float currentX, float currentY, float currentZ) const
{
    (void)currentZ;
    float dist19 = Distance2D(currentX, currentY, kPath[kIndex_L25_Start].GetPositionX(), kPath[kIndex_L25_Start].GetPositionY());
    
    if (dist19 < Distance::START_NEARBY_THRESHOLD)
        return static_cast<uint8>(kIndex_L25_Start + 1);
    
    return 0;
}

bool RouteL25To60::GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const
{
    if (currentIndex < kIndex_L60_End)
    {
        outNextIndex = static_cast<uint8>(currentIndex + 1);
        return true;
    }
    return false;
}

bool RouteL25To60::IsFinalIndex(uint8 index) const
{
    return index >= kIndex_L60_End;
}

FlightRouteMode RouteL25To60::GetMode() const
{
    return ROUTE_L25_TO_60;
}

// ============================================================================
// RouteL40Return25: Level 40+ to Level 25+ (L40_End -> L25_Start)
// ============================================================================

uint8 RouteL40Return25::GetStartIndex(float currentX, float currentY, float currentZ) const
{
    (void)currentX; (void)currentY; (void)currentZ;
    return kIndex_L40_End;
}

bool RouteL40Return25::GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const
{
    if (currentIndex > kIndex_L25_Start && currentIndex <= kIndex_L40_End)
    {
        outNextIndex = static_cast<uint8>(currentIndex - 1);
        return true;
    }
    return false;
}

bool RouteL40Return25::IsFinalIndex(uint8 index) const
{
    return index <= kIndex_L25_Start;
}

FlightRouteMode RouteL40Return25::GetMode() const
{
    return ROUTE_L40_RETURN25;
}

bool RouteL40Return25::ShouldBypassAnchor(uint8 anchorIndex, uint8& outBypassIndex) const
{
    // Descending routes should bypass L25_Start -> L25_End
    if (anchorIndex == kIndex_L25_Start)
    {
        outBypassIndex = kIndex_L25_End;
        return true;
    }
    return false;
}

// ============================================================================
// RouteL40Scenic: Level 40+ to Level 60+ (L40_Start -> L60_End)
// ============================================================================

uint8 RouteL40Scenic::GetStartIndex(float currentX, float currentY, float currentZ) const
{
    (void)currentZ;
    float dist40 = Distance2D(currentX, currentY, kPath[kIndex_L40_Start].GetPositionX(), kPath[kIndex_L40_Start].GetPositionY());
    
    if (dist40 < Distance::START_NEARBY_THRESHOLD)
        return static_cast<uint8>(kIndex_L40_Start + 1);
    
    return 0;
}

bool RouteL40Scenic::GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const
{
    if (currentIndex < kIndex_L60_End)
    {
        outNextIndex = static_cast<uint8>(currentIndex + 1);
        return true;
    }
    return false;
}

bool RouteL40Scenic::IsFinalIndex(uint8 index) const
{
    return index >= kIndex_L60_End;
}

FlightRouteMode RouteL40Scenic::GetMode() const
{
    return ROUTE_L40_SCENIC;
}

// ============================================================================
// RouteL60Return40: Level 60+ to Level 40+ (L60_End -> L40_Start)
// ============================================================================

uint8 RouteL60Return40::GetStartIndex(float currentX, float currentY, float currentZ) const
{
    (void)currentX; (void)currentY; (void)currentZ;
    return kIndex_L60_End;
}

bool RouteL60Return40::GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const
{
    if (currentIndex > kIndex_L40_Start && currentIndex <= kIndex_L60_End)
    {
        outNextIndex = static_cast<uint8>(currentIndex - 1);
        return true;
    }
    return false;
}

bool RouteL60Return40::IsFinalIndex(uint8 index) const
{
    return index <= kIndex_L40_Start;
}

FlightRouteMode RouteL60Return40::GetMode() const
{
    return ROUTE_L60_RETURN40;
}

// ============================================================================
// RouteL60Return19: Level 60+ to Level 25+ (L60_End -> L25_Start)
// ============================================================================

uint8 RouteL60Return19::GetStartIndex(float currentX, float currentY, float currentZ) const
{
    (void)currentX; (void)currentY; (void)currentZ;
    return kIndex_L60_End;
}

bool RouteL60Return19::GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const
{
    if (currentIndex > kIndex_L25_Start && currentIndex <= kIndex_L60_End)
    {
        outNextIndex = static_cast<uint8>(currentIndex - 1);
        return true;
    }
    return false;
}

bool RouteL60Return19::IsFinalIndex(uint8 index) const
{
    return index <= kIndex_L25_Start;
}

FlightRouteMode RouteL60Return19::GetMode() const
{
    return ROUTE_L60_RETURN19;
}

bool RouteL60Return19::ShouldBypassAnchor(uint8 anchorIndex, uint8& outBypassIndex) const
{
    if (anchorIndex == kIndex_L25_Start)
    {
        outBypassIndex = kIndex_L25_End;
        return true;
    }
    return false;
}

// ============================================================================
// RouteL60Return0: Level 60+ to Camp (L60_End -> StartCamp)
// ============================================================================

uint8 RouteL60Return0::GetStartIndex(float currentX, float currentY, float currentZ) const
{
    (void)currentX; (void)currentY; (void)currentZ;
    return kIndex_L60_End;
}

bool RouteL60Return0::GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const
{
    if (currentIndex > 0 && currentIndex <= kIndex_L60_End)
    {
        outNextIndex = static_cast<uint8>(currentIndex - 1);
        return true;
    }
    else if (currentIndex == 0)
    {
        outNextIndex = kIndex_startcamp;
        return true;
    }
    return false;
}

bool RouteL60Return0::IsFinalIndex(uint8 index) const
{
    return index == kIndex_startcamp;
}

FlightRouteMode RouteL60Return0::GetMode() const
{
    return ROUTE_L60_RETURN0;
}

bool RouteL60Return0::ShouldBypassAnchor(uint8 anchorIndex, uint8& outBypassIndex) const
{
    if (anchorIndex == kIndex_L25_Start)
    {
        outBypassIndex = kIndex_L25_End;
        return true;
    }
    return false;
}

// ============================================================================
// RouteL40Return0: Level 40+ to Camp (L40_End -> StartCamp)
// ============================================================================

uint8 RouteL40Return0::GetStartIndex(float currentX, float currentY, float currentZ) const
{
    (void)currentX; (void)currentY; (void)currentZ;
    return kIndex_L40_End;
}

bool RouteL40Return0::GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const
{
    if (currentIndex > 0 && currentIndex <= kIndex_L40_End)
    {
        outNextIndex = static_cast<uint8>(currentIndex - 1);
        // Skip L25_Start when descending
        if (outNextIndex == kIndex_L25_Start)
            outNextIndex = kIndex_L25_End;
        return true;
    }
    else if (currentIndex == 0)
    {
        outNextIndex = kIndex_startcamp;
        return true;
    }
    return false;
}

bool RouteL40Return0::IsFinalIndex(uint8 index) const
{
    return index == kIndex_startcamp;
}

FlightRouteMode RouteL40Return0::GetMode() const
{
    return ROUTE_L40_RETURN0;
}

bool RouteL40Return0::ShouldBypassAnchor(uint8 anchorIndex, uint8& outBypassIndex) const
{
    if (anchorIndex == kIndex_L25_Start)
    {
        outBypassIndex = kIndex_L25_End;
        return true;
    }
    return false;
}

// ============================================================================
// FlightRouteFactory
// ============================================================================

std::unique_ptr<IFlightRoute> FlightRouteFactory::CreateRoute(FlightRouteMode mode)
{
    switch (mode)
    {
        case ROUTE_TOUR:          return std::make_unique<RouteTour>();
        case ROUTE_L40_DIRECT:    return std::make_unique<RouteL40Direct>();
        case ROUTE_L0_TO_57:      return std::make_unique<RouteL0To57>();
        case ROUTE_RETURN:        return std::make_unique<RouteReturn>();
        case ROUTE_L25_TO_40:     return std::make_unique<RouteL25To40>();
        case ROUTE_L25_TO_60:     return std::make_unique<RouteL25To60>();
        case ROUTE_L40_RETURN25:  return std::make_unique<RouteL40Return25>();
        case ROUTE_L40_SCENIC:    return std::make_unique<RouteL40Scenic>();
        case ROUTE_L60_RETURN40:  return std::make_unique<RouteL60Return40>();
        case ROUTE_L60_RETURN19:  return std::make_unique<RouteL60Return19>();
        case ROUTE_L60_RETURN0:   return std::make_unique<RouteL60Return0>();
        case ROUTE_L40_RETURN0:   return std::make_unique<RouteL40Return0>();
        default:                  return std::make_unique<RouteTour>(); // Fallback
    }
}
