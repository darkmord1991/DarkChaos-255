#pragma once
#include "Position.h"
#include "ac_flightmasters_data.h"
#include <vector>
#include <cstdint>
#include <optional>

/*
 * EmergencyLanding.h
 * 
 * Emergency landing system for flight path failures.
 * Primary strategy: Use route destination so player arrives where intended.
 * Fallback: Use nearest pre-defined safe landing spot.
 */

namespace DC_AC_Flight
{

// Emergency landing spot data
struct EmergencyLandingSpot
{
    const char* name;          // Debug name for the spot
    float x, y, z, o;          // Coordinates and orientation
    uint8 priority;            // 0 = highest priority (safest), 255 = last resort
    
    Position GetPosition() const { return Position(x, y, z, o); }
};

// ============================================================================
// Pre-defined Safe Landing Zones
// ============================================================================

class EmergencyLandingSystem
{
public:
    // Get emergency landing position based on route destination (PREFERRED)
    // Returns the intended destination for the route so player arrives where they wanted
    static std::optional<Position> GetRouteDestination(FlightRouteMode route)
    {
        switch (route)
        {
            case ROUTE_TOUR:           // Scenic tour returns to camp
            case ROUTE_RETURN:         // Return to camp
            case ROUTE_L40_RETURN0:    // L40+ return to camp
            case ROUTE_L60_RETURN0:    // L60+ return to camp
            case ROUTE_L60_RETURN19:   // L60+ alternate return
                return Position(kPath[0].GetPositionX(), kPath[0].GetPositionY(), 
                              kPath[0].GetPositionZ(), kPath[0].GetOrientation());
            
            case ROUTE_L25_TO_40:      // Camp to L40 zone
            case ROUTE_L40_DIRECT:     // Direct to L40
                return Position(kPath[kIndex_acfm35].GetPositionX(), kPath[kIndex_acfm35].GetPositionY(),
                              kPath[kIndex_acfm35].GetPositionZ(), kPath[kIndex_acfm35].GetOrientation());
            
            case ROUTE_L25_TO_60:      // Camp to L60 zone
            case ROUTE_L40_SCENIC:     // L40 to L60 zone
            case ROUTE_L0_TO_57:       // L60 scenic route
                return Position(kPath[kIndex_acfm57].GetPositionX(), kPath[kIndex_acfm57].GetPositionY(),
                              kPath[kIndex_acfm57].GetPositionZ(), kPath[kIndex_acfm57].GetOrientation());
            
            default:
                return std::nullopt;
        }
    }
    
    // Find the nearest safe landing spot to the given position (FALLBACK)
    static Position FindNearestSafeLanding(float x, float y, float z);
    
    // Find the best landing spot based on priority and distance
    static Position FindBestLanding(float x, float y, float z, uint8 maxPriority = 100);
    
    // Get emergency landing for specific route anchors
    static Position GetAnchorEmergencySpot(uint8 anchorIndex);
    
    // Check if position is near any safe landing spot
    static bool IsNearSafeLanding(float x, float y, float z, float maxDistance = 50.0f);
    
private:
    // Compute 3D distance between two points
    static float Distance3D(float x1, float y1, float z1, float x2, float y2, float z2);
    
    // Static array of all emergency landing spots
    static const std::vector<EmergencyLandingSpot> s_landingSpots;
};

// ============================================================================
// Landing Spot Database
// ============================================================================

inline const std::vector<EmergencyLandingSpot> EmergencyLandingSystem::s_landingSpots = {
    // === STARTCAMP AREA ===
    // Primary safe zone near the starting camp
    { "Startcamp Main",       131.0f, 1012.0f, 295.0f, 5.0f,    0 },   // Main camp center (highest priority)
    { "Startcamp North",      100.0f, 1037.0f, 297.1f, 2.56f,   5 },   // Near innkeeper
    { "Startcamp Flight",     72.5f,  932.3f,  339.4f, 0.068f, 10 },   // Flight master platform
    
    // === LEVEL 25+ AREA (acfm15 region) ===
    { "Level 25 Anchor",      -20.3f, 419.1f,  308.2f, 5.92f,  15 },   // acfm15 position
    { "Level 25 Approach",    -18.4f, 416.4f,  307.4f, 2.06f,  20 },   // acfm14 nearby
    { "Level 25 Backup",      -12.8f, 405.8f,  307.1f, 2.06f,  25 },   // acfm13 fallback
    
    // === LEVEL 40+ AREA (acfm35 region) ===
    { "Level 40 Anchor",      684.2f, 109.8f,  283.2f, 0.072f, 15 },   // acfm35 position
    { "Level 40 Approach",    656.1f, 107.8f,  282.1f, 0.072f, 20 },   // acfm34 nearby
    { "Level 40 Backup",      626.1f, 115.0f,  284.6f, 5.27f,  25 },   // acfm33 fallback
    
    // === LEVEL 60+ AREA (acfm57 region) ===
    { "Level 60 Anchor",     1070.1f, -23.5f,  330.2f, 3.67f,  15 },   // acfm57 position
    { "Level 60 Approach",   1049.8f,  13.1f,  330.9f, 4.90f,  20 },   // acfm48 nearby
    { "Level 60 Backup",     1051.1f,  39.0f,  334.2f, 4.45f,  25 },   // acfm47 fallback
    
    // === MID-ROUTE SAFE ZONES ===
    // Strategic points along the main flight path
    { "Mid Route Alpha",      267.8f, 717.6f,  291.3f, 4.17f,  30 },   // acfm2
    { "Mid Route Beta",       117.6f, 574.1f,  297.4f, 2.72f,  30 },   // acfm4
    { "Mid Route Gamma",       69.2f, 403.6f,  335.3f, 4.26f,  30 },   // acfm10
    { "Mid Route Delta",      253.7f, 174.4f,  275.8f, 5.54f,  30 },   // acfm20
    { "Mid Route Epsilon",    530.2f, -71.6f,  295.5f, 1.32f,  30 },   // acfm28
    { "Mid Route Zeta",       813.2f, 285.9f,  301.7f, 6.21f,  30 },   // acfm40
    
    // === EMERGENCY FALLBACKS ===
    // Last-resort spots if all else fails
    { "Emergency North",      269.9f, 827.0f,  289.1f, 5.19f,  90 },   // acfm1 (tour start)
    { "Emergency East",       897.1f, 294.0f,  321.7f, 6.25f,  90 },   // acfm41
    { "Emergency South",      348.3f, -99.4f,  298.5f, 4.87f,  90 },   // acfm24
    { "Emergency West",        33.1f, 542.8f,  291.4f, 5.17f,  90 },   // acfm6
};

// ============================================================================
// Implementation
// ============================================================================

inline float EmergencyLandingSystem::Distance3D(float x1, float y1, float z1, float x2, float y2, float z2)
{
    float dx = x1 - x2;
    float dy = y1 - y2;
    float dz = z1 - z2;
    return std::sqrt(dx*dx + dy*dy + dz*dz);
}

inline Position EmergencyLandingSystem::FindNearestSafeLanding(float x, float y, float z)
{
    if (s_landingSpots.empty())
        return Position(131.0f, 1012.0f, 295.0f, 5.0f); // Fallback to startcamp
    
    float bestDist = std::numeric_limits<float>::max();
    const EmergencyLandingSpot* nearest = &s_landingSpots[0];
    
    for (const auto& spot : s_landingSpots)
    {
        float dist = Distance3D(x, y, z, spot.x, spot.y, spot.z);
        if (dist < bestDist)
        {
            bestDist = dist;
            nearest = &spot;
        }
    }
    
    return nearest->GetPosition();
}

inline Position EmergencyLandingSystem::FindBestLanding(float x, float y, float z, uint8 maxPriority)
{
    if (s_landingSpots.empty())
        return Position(131.0f, 1012.0f, 295.0f, 5.0f);
    
    // Score = distance * (priority + 1)
    // Lower score is better
    float bestScore = std::numeric_limits<float>::max();
    const EmergencyLandingSpot* best = nullptr;
    
    for (const auto& spot : s_landingSpots)
    {
        if (spot.priority > maxPriority)
            continue;
        
        float dist = Distance3D(x, y, z, spot.x, spot.y, spot.z);
        float score = dist * (static_cast<float>(spot.priority) + 1.0f);
        
        if (score < bestScore)
        {
            bestScore = score;
            best = &spot;
        }
    }
    
    if (best)
        return best->GetPosition();
    
    // Fallback: find nearest regardless of priority
    return FindNearestSafeLanding(x, y, z);
}

inline Position EmergencyLandingSystem::GetAnchorEmergencySpot(uint8 anchorIndex)
{
    // Map specific anchor indices to their dedicated emergency spots
    switch (anchorIndex)
    {
        case 14: // acfm15
        case 15: // acfm19
            return Position(-20.3f, 419.1f, 308.2f, 5.92f); // Level 25 Anchor
            
        case 31: // acfm35
        case 32: // acfm40
            return Position(684.2f, 109.8f, 283.2f, 0.072f); // Level 40 Anchor
            
        case 49: // acfm57
            return Position(1070.1f, -23.5f, 330.2f, 3.67f); // Level 60 Anchor
            
        case 50: // startcamp
        default:
            return Position(131.0f, 1012.0f, 295.0f, 5.0f); // Startcamp Main
    }
}

inline bool EmergencyLandingSystem::IsNearSafeLanding(float x, float y, float z, float maxDistance)
{
    for (const auto& spot : s_landingSpots)
    {
        float dist = Distance3D(x, y, z, spot.x, spot.y, spot.z);
        if (dist <= maxDistance)
            return true;
    }
    return false;
}

} // namespace DC_AC_Flight
