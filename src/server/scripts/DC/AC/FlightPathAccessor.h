#pragma once
#include "ac_flightmasters_data.h"
#include <optional>
#include <cstdint>

/*
 * FlightPathAccessor.h
 * 
 * Safe accessor for flight path arrays with bounds checking.
 * Prevents array out-of-bounds errors and provides clear error handling.
 * 
 * Usage:
 *   Position pos = FlightPathAccessor::GetSafePosition(index).value_or(fallback);
 *   if (FlightPathAccessor::IsValidIndex(index)) { ... }
 */

namespace DC_AC_Flight
{

class FlightPathAccessor
{
public:
    // Check if an index is within valid bounds
    static bool IsValidIndex(uint8 index)
    {
        return index < kPathLength;
    }
    
    // Get a position with bounds checking
    // Returns std::nullopt if index is out of bounds
    static std::optional<Position> GetSafePosition(uint8 index)
    {
        if (!IsValidIndex(index))
            return std::nullopt;
        
        return kPath[index];
    }
    
    // Get a position with fallback to a default if out of bounds
    static Position GetPositionOrDefault(uint8 index, Position const& defaultPos)
    {
        if (!IsValidIndex(index))
            return defaultPos;
        
        return kPath[index];
    }
    
    // Get a position, clamping index to valid range
    static Position GetPositionClamped(uint8 index)
    {
        if (index >= kPathLength)
            index = static_cast<uint8>(kPathLength - 1);
        
        return kPath[index];
    }
    
    // Validate multiple indices at once
    static bool AreValidIndices(uint8 index1, uint8 index2)
    {
        return IsValidIndex(index1) && IsValidIndex(index2);
    }
    
    static bool AreValidIndices(uint8 index1, uint8 index2, uint8 index3)
    {
        return IsValidIndex(index1) && IsValidIndex(index2) && IsValidIndex(index3);
    }
    
    // Get the maximum valid index
    static uint8 GetMaxIndex()
    {
        return kPathLength > 0 ? static_cast<uint8>(kPathLength - 1) : 0;
    }
    
    // Get total path length
    static uint8 GetPathLength()
    {
        return kPathLength;
    }
    
    // Clamp an index to valid range [0, kPathLength-1]
    static uint8 ClampIndex(uint8 index)
    {
        if (index >= kPathLength)
            return GetMaxIndex();
        return index;
    }
    
    // Get next index with wraparound protection
    static std::optional<uint8> GetNextIndex(uint8 current)
    {
        if (!IsValidIndex(current))
            return std::nullopt;
        
        if (current + 1 >= kPathLength)
            return std::nullopt; // No next index
        
        return static_cast<uint8>(current + 1);
    }
    
    // Get previous index with wraparound protection
    static std::optional<uint8> GetPreviousIndex(uint8 current)
    {
        if (!IsValidIndex(current))
            return std::nullopt;
        
        if (current == 0)
            return std::nullopt; // No previous index
        
        return static_cast<uint8>(current - 1);
    }
    
    // Get distance between two waypoints (2D)
    static std::optional<float> GetDistance2D(uint8 index1, uint8 index2)
    {
        if (!AreValidIndices(index1, index2))
            return std::nullopt;
        
        float dx = kPath[index1].GetPositionX() - kPath[index2].GetPositionX();
        float dy = kPath[index1].GetPositionY() - kPath[index2].GetPositionY();
        return std::sqrt(dx * dx + dy * dy);
    }
    
    // Get distance between two waypoints (3D)
    static std::optional<float> GetDistance3D(uint8 index1, uint8 index2)
    {
        if (!AreValidIndices(index1, index2))
            return std::nullopt;
        
        float dx = kPath[index1].GetPositionX() - kPath[index2].GetPositionX();
        float dy = kPath[index1].GetPositionY() - kPath[index2].GetPositionY();
        float dz = kPath[index1].GetPositionZ() - kPath[index2].GetPositionZ();
        return std::sqrt(dx * dx + dy * dy + dz * dz);
    }
    
    // Calculate distance from a position to a waypoint
    static std::optional<float> GetDistanceToWaypoint(float x, float y, float z, uint8 waypointIndex, bool use3D = true)
    {
        if (!IsValidIndex(waypointIndex))
            return std::nullopt;
        
        float dx = x - kPath[waypointIndex].GetPositionX();
        float dy = y - kPath[waypointIndex].GetPositionY();
        
        if (!use3D)
            return std::sqrt(dx * dx + dy * dy);
        
        float dz = z - kPath[waypointIndex].GetPositionZ();
        return std::sqrt(dx * dx + dy * dy + dz * dz);
    }
    
    // Find nearest waypoint to a given position
    static uint8 FindNearestWaypoint(float x, float y, float z, uint8 maxSearchIndex = 255)
    {
        uint8 searchMax = (maxSearchIndex < kPathLength) ? maxSearchIndex : GetMaxIndex();
        
        float bestDist = std::numeric_limits<float>::max();
        uint8 nearest = 0;
        
        for (uint8 i = 0; i <= searchMax; ++i)
        {
            float dx = x - kPath[i].GetPositionX();
            float dy = y - kPath[i].GetPositionY();
            float dz = z - kPath[i].GetPositionZ();
            float dist = dx*dx + dy*dy + dz*dz; // Use squared distance to avoid sqrt
            
            if (dist < bestDist)
            {
                bestDist = dist;
                nearest = i;
            }
        }
        
        return nearest;
    }
};

} // namespace DC_AC_Flight
