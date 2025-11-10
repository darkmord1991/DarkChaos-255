#pragma once
#include <cstdint>

/*
 * FlightStateMachine.h
 * 
 * Explicit state machine for flight taxi system.
 * Replaces scattered boolean flags with clear state transitions.
 * 
 * States:
 * - Idle: Gryphon exists but flight not started
 * - Preparing: Initial takeoff/positioning
 * - Flying: Normal flight between waypoints
 * - CustomPath: Following smart pathfinding hops
 * - ArrivingAtWaypoint: Transitioning between waypoints
 * - Landing: Final descent sequence
 * - Stuck: Recovery mode (no movement detected)
 * - EmergencyLanding: Forced landing due to error
 * - Despawning: Cleanup in progress
 */

namespace DC_AC_Flight
{

enum class FlightState : uint8
{
    Idle = 0,              // Gryphon spawned, waiting for SetData
    Preparing,             // Takeoff or initial positioning
    Flying,                // Normal waypoint-to-waypoint flight
    CustomPath,            // Following smart pathfinding intermediate points
    ArrivingAtWaypoint,    // Arrived at waypoint, planning next hop
    Descending,            // Initiating descent to final destination
    Landing,               // Final landing sequence active
    Stuck,                 // No movement detected, recovery in progress
    EmergencyLanding,      // Forced landing due to failure
    Despawning             // Cleanup, about to despawn
};

enum class FlightEvent : uint8
{
    StartFlight,           // SetData called with route
    ReachedWaypoint,       // MovementInform or proximity arrival
    BeginCustomPath,       // Starting smart pathfinding hop
    CompleteCustomPath,    // Finished all smart path hops
    ApproachingAnchor,     // Starting approach to final destination
    StartLanding,          // Beginning final landing sequence
    LandingComplete,       // Touched ground
    StuckDetected,         // No movement for threshold time
    RecoverySucceeded,     // Stuck recovery worked
    RecoveryFailed,        // Stuck recovery exhausted
    PlayerDisconnected,    // Passenger left
    EmergencyTriggered,    // Critical error, force land
    Despawn                // Final cleanup
};

class FlightStateMachine
{
public:
    FlightStateMachine() : _currentState(FlightState::Idle), _previousState(FlightState::Idle) {}
    
    // Get current state
    FlightState GetState() const { return _currentState; }
    FlightState GetPreviousState() const { return _previousState; }
    
    // State queries (replace scattered boolean flags)
    bool IsIdle() const { return _currentState == FlightState::Idle; }
    bool IsPreparing() const { return _currentState == FlightState::Preparing; }
    bool IsFlying() const { return _currentState == FlightState::Flying; }
    bool IsFollowingCustomPath() const { return _currentState == FlightState::CustomPath; }
    bool IsArrivingAtWaypoint() const { return _currentState == FlightState::ArrivingAtWaypoint; }
    bool IsLanding() const { return _currentState == FlightState::Landing; }
    bool IsStuck() const { return _currentState == FlightState::Stuck; }
    bool IsEmergencyLanding() const { return _currentState == FlightState::EmergencyLanding; }
    bool IsDespawning() const { return _currentState == FlightState::Despawning; }
    
    // Grouped queries for logic convenience
    bool IsActivelyFlying() const 
    { 
        return _currentState == FlightState::Flying || 
               _currentState == FlightState::CustomPath ||
               _currentState == FlightState::ArrivingAtWaypoint;
    }
    
    bool IsDescending() const 
    { 
        return _currentState == FlightState::Descending ||
               _currentState == FlightState::Landing || 
               _currentState == FlightState::EmergencyLanding;
    }
    
    bool CanMove() const 
    { 
        return IsActivelyFlying() || IsPreparing();
    }
    
    bool ShouldApplyFlightFlags() const 
    { 
        return !IsDescending() && !IsDespawning();
    }
    
    // State transition
    bool TransitionTo(FlightState newState, FlightEvent trigger)
    {
        // Validate transition is allowed
        if (!IsTransitionValid(_currentState, newState, trigger))
            return false;
        
        _previousState = _currentState;
        _currentState = newState;
        _lastTransitionEvent = trigger;
        return true;
    }
    
    // Get state name for debug output
    const char* GetStateName() const
    {
        return GetStateName(_currentState);
    }
    
    static const char* GetStateName(FlightState state)
    {
        switch (state)
        {
            case FlightState::Idle: return "Idle";
            case FlightState::Preparing: return "Preparing";
            case FlightState::Flying: return "Flying";
            case FlightState::CustomPath: return "CustomPath";
            case FlightState::ArrivingAtWaypoint: return "ArrivingAtWaypoint";
            case FlightState::Descending: return "Descending";
            case FlightState::Landing: return "Landing";
            case FlightState::Stuck: return "Stuck";
            case FlightState::EmergencyLanding: return "EmergencyLanding";
            case FlightState::Despawning: return "Despawning";
            default: return "Unknown";
        }
    }
    
    static const char* GetEventName(FlightEvent event)
    {
        switch (event)
        {
            case FlightEvent::StartFlight: return "StartFlight";
            case FlightEvent::ReachedWaypoint: return "ReachedWaypoint";
            case FlightEvent::BeginCustomPath: return "BeginCustomPath";
            case FlightEvent::CompleteCustomPath: return "CompleteCustomPath";
            case FlightEvent::ApproachingAnchor: return "ApproachingAnchor";
            case FlightEvent::StartLanding: return "StartLanding";
            case FlightEvent::LandingComplete: return "LandingComplete";
            case FlightEvent::StuckDetected: return "StuckDetected";
            case FlightEvent::RecoverySucceeded: return "RecoverySucceeded";
            case FlightEvent::RecoveryFailed: return "RecoveryFailed";
            case FlightEvent::PlayerDisconnected: return "PlayerDisconnected";
            case FlightEvent::EmergencyTriggered: return "EmergencyTriggered";
            case FlightEvent::Despawn: return "Despawn";
            default: return "Unknown";
        }
    }
    
private:
    FlightState _currentState;
    FlightState _previousState;
    FlightEvent _lastTransitionEvent = FlightEvent::StartFlight;
    
    // State transition validation table
    bool IsTransitionValid(FlightState from, FlightState to, FlightEvent trigger) const
    {
        // Despawn is always valid from any state
        if (to == FlightState::Despawning)
            return true;
        
        // Emergency landing can happen from any active state
        if (to == FlightState::EmergencyLanding && from != FlightState::Idle && from != FlightState::Despawning)
            return true;
        
        // Define valid state transitions
        switch (from)
        {
            case FlightState::Idle:
                return to == FlightState::Preparing && trigger == FlightEvent::StartFlight;
                
            case FlightState::Preparing:
                return (to == FlightState::Flying && trigger == FlightEvent::StartFlight) ||
                       (to == FlightState::CustomPath && trigger == FlightEvent::BeginCustomPath);
                
            case FlightState::Flying:
                return (to == FlightState::ArrivingAtWaypoint && trigger == FlightEvent::ReachedWaypoint) ||
                       (to == FlightState::CustomPath && trigger == FlightEvent::BeginCustomPath) ||
                       (to == FlightState::Landing && trigger == FlightEvent::StartLanding) ||
                       (to == FlightState::Stuck && trigger == FlightEvent::StuckDetected);
                
            case FlightState::CustomPath:
                return (to == FlightState::Flying && trigger == FlightEvent::CompleteCustomPath) ||
                       (to == FlightState::ArrivingAtWaypoint && trigger == FlightEvent::ReachedWaypoint) ||
                       (to == FlightState::Stuck && trigger == FlightEvent::StuckDetected);
                
            case FlightState::ArrivingAtWaypoint:
                return (to == FlightState::Flying && trigger == FlightEvent::ReachedWaypoint) ||
                       (to == FlightState::CustomPath && trigger == FlightEvent::BeginCustomPath) ||
                       (to == FlightState::Descending && trigger == FlightEvent::ApproachingAnchor) ||
                       (to == FlightState::Landing && trigger == FlightEvent::StartLanding);
                
            case FlightState::Descending:
                return (to == FlightState::Landing && trigger == FlightEvent::StartLanding);
                
            case FlightState::Landing:
                return (to == FlightState::Despawning && trigger == FlightEvent::LandingComplete) ||
                       (to == FlightState::Despawning && trigger == FlightEvent::Despawn);
                
            case FlightState::Stuck:
                return (to == FlightState::Flying && trigger == FlightEvent::RecoverySucceeded) ||
                       (to == FlightState::CustomPath && trigger == FlightEvent::RecoverySucceeded) ||
                       (to == FlightState::EmergencyLanding && trigger == FlightEvent::RecoveryFailed);
                
            case FlightState::EmergencyLanding:
                return to == FlightState::Despawning;
                
            case FlightState::Despawning:
                return false; // No transitions from despawning
                
            default:
                return false;
        }
    }
};

} // namespace DC_AC_Flight
