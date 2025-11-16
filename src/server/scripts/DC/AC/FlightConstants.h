#pragma once
#include <cstdint>

/*
 * FlightConstants.h
 * 
 * Centralized configuration constants for the AC Flight System.
 * All magic numbers extracted here for easy tuning and maintenance.
 * 
 * Categories:
 * - Distance thresholds
 * - Timeout values
 * - Speed multipliers
 * - Failure recovery settings
 * - Debug and safety limits
 */

// ============================================================================
// DISTANCE THRESHOLDS (in yards)
// ============================================================================

namespace Distance
{
    // Proximity detection for waypoint arrival
    constexpr float WAYPOINT_NEAR_2D = 6.0f;          // Horizontal arrival threshold
    constexpr float WAYPOINT_NEAR_2D_L40 = 10.0f;     // For L40+ segment (increased tolerance)
    constexpr float WAYPOINT_NEAR_2D_RELAXED = 10.0f; // For problematic nodes (acfm40+)
    constexpr float WAYPOINT_NEAR_2D_STICKY = 12.0f;  // For known sticky anchors (acfm19)
    constexpr float WAYPOINT_NEAR_Z = 22.0f;          // Vertical arrival threshold
    constexpr float WAYPOINT_NEAR_Z_RELAXED = 40.0f;  // Relaxed vertical threshold for manual checks
    
    // Specific node overrides
    constexpr float NODE_STICKY_NEAR_2D = 8.0f;       // For nodes 2, 13, 30
    constexpr float L25_TO_L40_FINAL_NEAR = 10.0f;    // For acfm15 on L25→L40 route
    
    // Starting point proximity checks
    constexpr float START_NEARBY_THRESHOLD = 80.0f;   // Consider "at start point" within this range
    constexpr float START_TAKEOFF_THRESHOLD = 120.0f; // Need takeoff if farther than this
    constexpr float SMART_PATH_THRESHOLD = 120.0f;    // Use smart pathfinding beyond this distance
    constexpr float SINGLE_HOP_MAX = 220.0f;          // Maximum for single-hop smart paths
    
    // Emergency and stuck detection
    constexpr float STUCK_MOVEMENT_MIN = 0.5f;        // Minimum movement to not be considered stuck
    constexpr float SINGLE_SMART_HOP_MIN = 2.0f;      // Minimum deviation to accept single smart hop
    constexpr float SANITY_CHECK_DISTANCE = 200.0f;   // Distance for route sanity checks
    
    // Corner smoothing
    constexpr float CORNER_SMOOTH_SHARP = 18.0f;      // Smoothing radius for sharp turns (>75°)
    constexpr float CORNER_SMOOTH_MEDIUM = 12.0f;     // Smoothing radius for medium turns (>35°)
    constexpr float CORNER_TURN_SHARP_DEG = 75.0f;    // Angle threshold for sharp turns
    constexpr float CORNER_TURN_MEDIUM_DEG = 35.0f;   // Angle threshold for medium turns
}

// ============================================================================
// TIMEOUT VALUES (in milliseconds)
// ============================================================================

namespace Timeout
{
    // Per-hop timeouts
    constexpr uint32 HOP_DEFAULT_MS = 8000;           // Default time allowed per waypoint hop
    constexpr uint32 HOP_SCENIC_MS = 5000;            // Faster timeout for L40 scenic route
    constexpr uint32 HOP_CUSTOM_MS = 4500;            // Timeout for custom smoothing hops
    constexpr uint32 HOP_FINAL_DEFAULT_MS = 6000;     // Default timeout for final hop
    constexpr uint32 HOP_FINAL_DIRECT_MS = 4000;      // L40 direct route final hop
    constexpr uint32 HOP_FINAL_L25_MS = 8000;         // L25→L40 final hop (more anchors)
    constexpr uint32 ANCHOR19_SKIP_MS = 3500;         // Skip to acfm15 if stuck at acfm19
    
    // Proximity fallback debounce
    constexpr uint32 PROXIMITY_CHECK_DEBOUNCE_MS = 300; // Wait before checking proximity arrival
    
    // Stuck detection
    constexpr uint32 STUCK_DETECT_MS = 20000;         // No movement for 20s triggers stuck recovery
    
    // No passenger grace period
    constexpr uint32 NO_PASSENGER_GRACE_MS = 2000;    // Wait 2s after losing passenger before despawn
    
    // Bypass throttling
    constexpr uint32 BYPASS_THROTTLE_MS = 3000;       // Minimum time between anchor bypasses
    constexpr uint32 BYPASS_TIMEOUT_MS = 60000;       // Max bypass timer value
    
    // Micro-nudge rate limiting
    constexpr uint32 MICRO_NUDGE_RATE_LIMIT_MS = 10000; // 10s between micro-nudges on same node
    
    // Landing fallbacks
    constexpr uint32 LANDING_FALLBACK_MS = 6000;      // Fallback timer for landing sequence
    constexpr uint32 EARLY_EXIT_FALLBACK_MS = 5000;   // Fallback for early exit landing
    constexpr uint32 SPLINE_WATCHDOG_MS = 15000;      // Max time allowed for a spline chain before forcing recovery
    
    // Scheduled task delays
    constexpr uint32 TAKEOFF_SCHEDULE_MS = 300;       // Delay before moving after takeoff
    constexpr uint32 INTRO_WHISPER_MS = 1000;         // Quest NPC intro whisper delay
    constexpr uint32 STATION_PAUSE_MS = 3000;         // Pause at each quest tour station
}

// ============================================================================
// SPEED MULTIPLIERS
// ============================================================================

namespace Speed
{
    constexpr float BASE_FLIGHT_RATE = 3.0f;          // Default flight speed multiplier
    constexpr float LANDING_RATE = 1.0f;              // Reduced speed when landing
    constexpr float LAND_APPROACH_SPEED = 7.0f;       // Speed for MoveLand approach
    
    // Turn-based speed adjustments
    constexpr float SHARP_TURN_RATE = 0.78f;          // Speed for sharp turns (>75°)
    constexpr float MEDIUM_TURN_RATE = 0.88f;         // Speed for medium turns (>35°)
    constexpr float STRAIGHT_RATE = 1.0f;             // Speed for straight flight
    
    // Safety clamping
    constexpr float MIN_RATE = 0.6f;                  // Never go below this speed
    constexpr float MAX_RATE = 1.1f;                  // Never exceed this speed
    
    // Turn angle thresholds (degrees)
    constexpr float SHARP_TURN_THRESHOLD_DEG = 75.0f; // Angle considered "sharp"
    constexpr float MEDIUM_TURN_THRESHOLD_DEG = 35.0f; // Angle considered "medium"
}

// ============================================================================
// FAILURE RECOVERY SETTINGS
// ============================================================================

namespace Recovery
{
    // Retry limits
    constexpr uint8 HOP_MAX_RETRIES = 3;              // Maximum reissue attempts per hop
    constexpr uint8 PATHFINDING_MAX_RETRIES = 1;      // Smart pathfinding retry limit
    
    // Escalation thresholds
    constexpr uint8 FAIL_ESCALATION_THRESHOLD = 3;    // Failures before escalating tactics
    constexpr uint8 NODE_57_ESCALATION = 2;           // acfm57 gets stricter threshold
    constexpr uint8 NODE_15_ESCALATION = 2;           // acfm15 gets stricter threshold
    
    // Nudge heights
    constexpr float MICRO_NUDGE_HEIGHT = 8.0f;        // Base extra height for micro-nudges
    constexpr float ESCALATED_NUDGE_HEIGHT = 8.0f;    // Additional height on escalation
    constexpr float ESCALATION_NUDGE_HEIGHT = 8.0f;   // Additional height on escalation (alias)
    constexpr float NODE_57_EXTRA_Z = 12.0f;          // Extra nudge for acfm57
    constexpr float NODE_15_EXTRA_Z = 6.0f;           // Extra nudge for acfm15
    constexpr float SNAP_HEIGHT_OFFSET = 2.0f;        // Z offset when snapping to target
    
    // Smart path recovery arcs
    constexpr float ARC_RISE_HEIGHT = 22.0f;          // Height gain for obstacle-clearing arcs
    constexpr float ARC_GLIDE_MIN_HEIGHT = 18.0f;     // Minimum glide altitude
    constexpr float ARC_ESCALATION_HEIGHT = 12.0f;    // Extra height on repeated failures
    constexpr float OVERHEAD_APPROACH_HEIGHT = 18.0f; // Base overhead approach altitude
    constexpr float OVERHEAD_ESCALATION_HEIGHT = 18.0f; // Extra height for escalated overhead
    
    // Smart path filtering
    constexpr float SMART_PATH_MIN_STEP_SQ = 9.0f;    // Minimum squared distance for path steps
}

// ============================================================================
// DEBUG AND SAFETY LIMITS
// ============================================================================

namespace Debug
{
    constexpr uint32 DESPAWN_DELAY_MS = 300000;       // 5 minutes max flight time before auto-despawn
    constexpr uint32 STATION_DESPAWN_MS = 60000;      // Quest tour duplicate despawn timer
    constexpr float LANDING_HEIGHT_OFFSET = 0.5f;     // Z offset when landing
    constexpr float TAKEOFF_HEIGHT_OFFSET = 18.0f;    // Initial lift before flight
    constexpr float SMART_PATH_Z_OFFSET = 6.0f;       // Z offset for smart pathfinding waypoints
    constexpr float LANDING_DESCENT_SPEED = 7.0f;     // MoveLand descent speed
}

// ============================================================================
// ROUTE-SPECIFIC SETTINGS
// ============================================================================

namespace Route
{
    // Anchor indices (from ac_flightmasters_data.h)
    constexpr uint8 INDEX_ACFM15 = 14;
    constexpr uint8 INDEX_ACFM19 = 15;
    constexpr uint8 INDEX_ACFM35 = 31;
    constexpr uint8 INDEX_ACFM40 = 32;
    constexpr uint8 INDEX_ACFM57 = 49;
    
    // Specific hop overrides
    constexpr uint32 ACFM19_HOP_TIMEOUT_MS = 3500;    // Special timeout for sticky acfm19
}

// ============================================================================
// HELPER SETTINGS
// ============================================================================

namespace Pathfinding
{
    // PathGenerator configuration
    constexpr float PATH_LENGTH_LIMIT = 300.0f;       // Maximum path calculation distance (increased from 200)
    constexpr float PATH_LENGTH_LIMIT_LEGACY = 200.0f; // Original limit for reference
    
    // Flight clearance heights
    constexpr float MIN_FLIGHT_CLEARANCE = 15.0f;     // Minimum height above terrain
    constexpr float MAX_FLIGHT_CLEARANCE = 35.0f;     // Maximum flight altitude over obstacles
    constexpr float LEGACY_FIXED_OFFSET = 6.0f;       // Old fixed Z-offset (deprecated)
    
    // Waypoint filtering
    constexpr float WAYPOINT_MIN_DISTANCE = 3.0f;     // Minimum distance between queued waypoints
    constexpr float WAYPOINT_MIN_DISTANCE_SQ = 9.0f;  // Squared for distance checks
    
    // Spline smoothing (future enhancement)
    constexpr uint32 SPLINE_SUBDIVISIONS = 3;         // Interpolation points between waypoints
}

namespace Helper
{
    constexpr size_t SPEED_SMOOTH_WINDOW = 4;         // Number of speed samples for smoothing
    constexpr float PATH_LENGTH_LIMIT = 200.0f;       // Max PathGenerator search distance
}
