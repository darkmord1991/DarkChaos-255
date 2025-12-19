#pragma once
#include <cstdint>
#include <memory>
#include "ac_flightmasters_data.h"

/*
 * FlightRouteStrategy.h
 * 
 * Strategy pattern for flight route handling.
 * Replaces massive switch statements with polymorphic route classes.
 * 
 * Each route strategy knows:
 * - Starting index for the route
 * - How to compute the next waypoint
 * - When the route is complete
 * - Special handling for sticky anchors
 */

// Forward declarations
enum FlightRouteMode : uint32
{
    // Camp (StartCamp) starts
    ROUTE_TOUR          = 0,  // Camp to Level 25+: acfm1 -> L25_End
    ROUTE_L40_DIRECT    = 1,  // Camp to Level 40+: acfm1 -> ... -> L40_End
    ROUTE_L0_TO_57      = 2,  // Camp to Level 60+: acfm1 -> ... -> L60_End

    // Level 25+ starts
    ROUTE_RETURN        = 3,  // Level 25+ to Camp: L25_End -> ... -> StartCamp
    ROUTE_L25_TO_40     = 4,  // Level 25+ to Level 40+: L25_Start -> ... -> L40_End
    ROUTE_L25_TO_60     = 5,  // Level 25+ to Level 60+: L25_Start -> ... -> L60_End

    // Level 40+ starts
    ROUTE_L40_RETURN25  = 6,  // Level 40+ to Level 25+: L40_End -> ... -> L25_Start
    ROUTE_L40_SCENIC    = 7,  // Level 40+ to Level 60+: L40_Start -> ... -> L60_End

    // Level 60+ starts
    ROUTE_L60_RETURN40  = 8,  // Level 60+ to Level 40+: L60_End -> ... -> L40_Start
    ROUTE_L60_RETURN19  = 9,  // Level 60+ to Level 25+: L60_End -> ... -> L25_Start
    ROUTE_L60_RETURN0   = 10, // Level 60+ to Camp: L60_End -> ... -> StartCamp
    ROUTE_L40_RETURN0   = 11  // Level 40+ to Camp: L40_End -> ... -> StartCamp
};

// ============================================================================
// IFlightRoute - Strategy Interface
// ============================================================================

class IFlightRoute
{
public:
    virtual ~IFlightRoute() = default;
    
    // Get the starting waypoint index for this route given current position
    virtual uint8 GetStartIndex(float currentX, float currentY, float currentZ) const = 0;
    
    // Compute the next waypoint index from current, returns false if route complete
    virtual bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const = 0;
    
    // Check if we've reached the final destination
    virtual bool IsFinalIndex(uint8 index) const = 0;
    
    // Get route mode identifier
    virtual FlightRouteMode GetMode() const = 0;
    
    // Get route name for debug
    virtual const char* GetName() const = 0;
    
    // Check if this route should bypass a specific anchor
    virtual bool ShouldBypassAnchor(uint8 anchorIndex, uint8& outBypassIndex) const
    {
        // Default: no bypass
        (void)anchorIndex;
        (void)outBypassIndex;
        return false;
    }
};

// ============================================================================
// Concrete Route Implementations
// ============================================================================

// Camp to Level 25+ (acfm1 -> L25_End)
class RouteTour : public IFlightRoute
{
public:
    uint8 GetStartIndex(float currentX, float currentY, float currentZ) const override;
    bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const override;
    bool IsFinalIndex(uint8 index) const override;
    FlightRouteMode GetMode() const override;
    const char* GetName() const override { return "Camp to Level 25+"; }
};

// Camp to Level 40+ direct (acfm1 -> L40_End)
class RouteL40Direct : public IFlightRoute
{
public:
    uint8 GetStartIndex(float currentX, float currentY, float currentZ) const override;
    bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const override;
    bool IsFinalIndex(uint8 index) const override;
    FlightRouteMode GetMode() const override;
    const char* GetName() const override { return "Camp to Level 40+"; }
};

// Camp to Level 60+ (acfm1 -> L60_End)
class RouteL0To57 : public IFlightRoute
{
public:
    uint8 GetStartIndex(float currentX, float currentY, float currentZ) const override;
    bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const override;
    bool IsFinalIndex(uint8 index) const override;
    FlightRouteMode GetMode() const override;
    const char* GetName() const override { return "Camp to Level 60+"; }
};

// Level 25+ to Camp (L25_End -> StartCamp)
class RouteReturn : public IFlightRoute
{
public:
    uint8 GetStartIndex(float currentX, float currentY, float currentZ) const override;
    bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const override;
    bool IsFinalIndex(uint8 index) const override;
    FlightRouteMode GetMode() const override;
    const char* GetName() const override { return "Level 25+ to Camp"; }
};

// Level 25+ to Level 40+ (L25_Start -> L40_End)
class RouteL25To40 : public IFlightRoute
{
public:
    uint8 GetStartIndex(float currentX, float currentY, float currentZ) const override;
    bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const override;
    bool IsFinalIndex(uint8 index) const override;
    FlightRouteMode GetMode() const override;
    const char* GetName() const override { return "Level 25+ to Level 40+"; }
};

// Level 25+ to Level 60+ (L25_Start -> L60_End)
class RouteL25To60 : public IFlightRoute
{
public:
    uint8 GetStartIndex(float currentX, float currentY, float currentZ) const override;
    bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const override;
    bool IsFinalIndex(uint8 index) const override;
    FlightRouteMode GetMode() const override;
    const char* GetName() const override { return "Level 25+ to Level 60+"; }
};

// Level 40+ to Level 25+ (L40_End -> L25_Start)
class RouteL40Return25 : public IFlightRoute
{
public:
    uint8 GetStartIndex(float currentX, float currentY, float currentZ) const override;
    bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const override;
    bool IsFinalIndex(uint8 index) const override;
    FlightRouteMode GetMode() const override;
    const char* GetName() const override { return "Level 40+ to Level 25+"; }
    bool ShouldBypassAnchor(uint8 anchorIndex, uint8& outBypassIndex) const override;
};

// Level 40+ to Level 60+ (L40_Start -> L60_End)
class RouteL40Scenic : public IFlightRoute
{
public:
    uint8 GetStartIndex(float currentX, float currentY, float currentZ) const override;
    bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const override;
    bool IsFinalIndex(uint8 index) const override;
    FlightRouteMode GetMode() const override;
    const char* GetName() const override { return "Level 40+ to Level 60+"; }
};

// Level 60+ to Level 40+ (L60_End -> L40_Start)
class RouteL60Return40 : public IFlightRoute
{
public:
    uint8 GetStartIndex(float currentX, float currentY, float currentZ) const override;
    bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const override;
    bool IsFinalIndex(uint8 index) const override;
    FlightRouteMode GetMode() const override;
    const char* GetName() const override { return "Level 60+ to Level 40+"; }
};

// Level 60+ to Level 25+ (L60_End -> L25_Start)
class RouteL60Return19 : public IFlightRoute
{
public:
    uint8 GetStartIndex(float currentX, float currentY, float currentZ) const override;
    bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const override;
    bool IsFinalIndex(uint8 index) const override;
    FlightRouteMode GetMode() const override;
    const char* GetName() const override { return "Level 60+ to Level 25+"; }
    bool ShouldBypassAnchor(uint8 anchorIndex, uint8& outBypassIndex) const override;
};

// Level 60+ to Camp (L60_End -> StartCamp)
class RouteL60Return0 : public IFlightRoute
{
public:
    uint8 GetStartIndex(float currentX, float currentY, float currentZ) const override;
    bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const override;
    bool IsFinalIndex(uint8 index) const override;
    FlightRouteMode GetMode() const override;
    const char* GetName() const override { return "Level 60+ to Camp"; }
    bool ShouldBypassAnchor(uint8 anchorIndex, uint8& outBypassIndex) const override;
};

// Level 40+ to Camp (L40_End -> StartCamp)
class RouteL40Return0 : public IFlightRoute
{
public:
    uint8 GetStartIndex(float currentX, float currentY, float currentZ) const override;
    bool GetNextIndex(uint8 currentIndex, uint8& outNextIndex) const override;
    bool IsFinalIndex(uint8 index) const override;
    FlightRouteMode GetMode() const override;
    const char* GetName() const override { return "Level 40+ to Camp"; }
    bool ShouldBypassAnchor(uint8 anchorIndex, uint8& outBypassIndex) const override;
};

// ============================================================================
// Route Factory
// ============================================================================

class FlightRouteFactory
{
public:
    // Create appropriate route strategy based on mode
    static std::unique_ptr<IFlightRoute> CreateRoute(FlightRouteMode mode);
};
