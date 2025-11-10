/*
 * ac_flightmasters_refactored.h
 * 
 * DEMONSTRATION FILE - Key architectural improvements for ac_gryphon_taxi_800011AI
 * 
 * This file shows how to integrate:
 * 1. FlightStateMachine - Replace boolean flags
 * 2. IFlightRoute strategy - Replace route switch statements
 * 3. Cached Player pointer - Replace 30+ GetPassengerPlayer() calls
 * 4. FlightPathAccessor - Safe array bounds checking
 * 5. FlightConstants - Replace magic numbers
 * 6. EmergencyLanding - Pre-defined safe landing spots
 * 
 * To integrate into ac_flightmasters.cpp:
 * - Replace boolean flags (_started, _isLanding, _awaitingArrival) with _stateMachine
 * - Replace _routeMode with _currentRoute (IFlightRoute*)
 * - Add _cachedPassenger member and UpdatePassengerCache() method
 * - Replace all kPath[index] with FlightPathAccessor::GetSafePosition(index)
 * - Replace all magic numbers with FlightConstants::*
 * - Add EmergencyLandingSystem calls in failure paths
 */

#pragma once
#include "ScriptedCreature.h"
#include "FlightStateMachine.h"
#include "FlightRouteStrategy.h"
#include "FlightConstants.h"
#include "FlightPathAccessor.h"
#include "EmergencyLanding.h"
#include "TaskScheduler.h"
#include <optional>
#include <memory>

namespace DC_AC_Flight
{

// ============================================================================
// REFACTORED AI CLASS - Key Changes Demonstrated
// ============================================================================

struct ac_gryphon_taxi_800011AI_Refactored : public VehicleAI
{
    // === NEW: Constructor ===
    ac_gryphon_taxi_800011AI_Refactored(Creature* creature) 
        : VehicleAI(creature)
        , _stateMachine()           // Replace boolean flags
        , _currentRoute(nullptr)    // Replace _routeMode
        , _cachedPassenger()        // Replace repeated GetPassengerPlayer() calls
    {
    }
    
    // === NEW: State Machine Integration ===
    FlightStateMachine _stateMachine;
    
    // === NEW: Route Strategy ===
    std::unique_ptr<IFlightRoute> _currentRoute;
    
    // === NEW: Cached Passenger ===
    std::optional<Player*> _cachedPassenger;
    uint32 _passengerCacheMs = 0; // Refresh cache every 1000ms
    
    // === NEW: Update passenger cache ===
    void UpdatePassengerCache()
    {
        Player* passenger = nullptr;
        if (Vehicle* kit = me->GetVehicleKit())
        {
            for (int i = 0; i < 8; ++i)
            {
                if (Unit* u = kit->GetPassenger(i))
                {
                    if (Player* p = u->ToPlayer())
                    {
                        passenger = p;
                        break;
                    }
                }
            }
        }
        _cachedPassenger = passenger;
    }
    
    // === NEW: Get cached passenger (replaces 30+ GetPassengerPlayer calls) ===
    Player* GetCachedPassenger() const
    {
        return _cachedPassenger.value_or(nullptr);
    }
    
    // === EXAMPLE: SetData refactored ===
    void SetData(uint32 id, uint32 value) override
    {
        if (id != 1)
            return;
        
        // Create route strategy from mode
        FlightRouteMode mode = static_cast<FlightRouteMode>(value);
        _currentRoute = FlightRouteFactory::CreateRoute(mode);
        
        if (!_currentRoute)
            return;
        
        // Update passenger cache
        UpdatePassengerCache();
        Player* passenger = GetCachedPassenger();
        
        // Transition to preparing state
        if (!_stateMachine.TransitionTo(FlightState::Preparing, FlightEvent::StartFlight))
        {
            if (passenger && passenger->IsGameMaster())
                ChatHandler(passenger->GetSession()).SendSysMessage("[Flight] State transition failed - cannot start flight.");
            return;
        }
        
        // Reset all state
        _index = 0;
        _awaitingArrival = false;
        _scheduler.CancelAll();
        
        // Get starting index from route strategy
        _index = _currentRoute->GetStartIndex(me->GetPositionX(), me->GetPositionY(), me->GetPositionZ());
        
        // Validate index with bounds checking
        if (!FlightPathAccessor::IsValidIndex(_index))
        {
            if (passenger && passenger->IsGameMaster())
                ChatHandler(passenger->GetSession()).PSendSysMessage("[Flight] Invalid start index {}. Using emergency landing.", _index);
            
            // Emergency landing at safe spot
            Position safeLand = EmergencyLandingSystem::FindNearestSafeLanding(
                me->GetPositionX(), me->GetPositionY(), me->GetPositionZ());
            me->NearTeleportTo(safeLand.GetPositionX(), safeLand.GetPositionY(), 
                             safeLand.GetPositionZ(), safeLand.GetOrientation());
            _stateMachine.TransitionTo(FlightState::EmergencyLanding, FlightEvent::EmergencyTriggered);
            return;
        }
        
        // Set flight flags
        me->SetCanFly(true);
        me->SetDisableGravity(true);
        me->SetHover(true);
        me->GetMotionMaster()->Clear();
        
        // Debug output using cached passenger
        if (passenger && passenger->IsGameMaster())
            ChatHandler(passenger->GetSession()).PSendSysMessage(
                "[Flight] Starting {} from {}.", _currentRoute->GetName(), NodeLabel(_index));
        
        // Check if need takeoff
        auto distToStart = FlightPathAccessor::GetDistanceToWaypoint(
            me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), _index, false);
        
        if (distToStart.value_or(0.0f) > Distance::START_TAKEOFF_THRESHOLD)
        {
            // Need takeoff
            Position lift = me->GetPosition();
            lift.m_positionZ += Debug::TAKEOFF_HEIGHT_OFFSET;
            me->GetMotionMaster()->MovePoint(POINT_TAKEOFF, lift);
            
            _scheduler.Schedule(std::chrono::milliseconds(Timeout::TAKEOFF_SCHEDULE_MS), 
                [this](TaskContext ctx)
            {
                (void)ctx;
                if (me->IsInWorld())
                {
                    _stateMachine.TransitionTo(FlightState::Flying, FlightEvent::StartFlight);
                    MoveToIndex(_index);
                }
            });
        }
        else
        {
            // Start directly
            _stateMachine.TransitionTo(FlightState::Flying, FlightEvent::StartFlight);
            MoveToIndex(_index);
        }
    }
    
    // === EXAMPLE: MoveToIndex refactored with bounds checking ===
    void MoveToIndex(uint8 idx)
    {
        // Validate index
        auto posOpt = FlightPathAccessor::GetSafePosition(idx);
        if (!posOpt)
        {
            Player* passenger = GetCachedPassenger();
            if (passenger && passenger->IsGameMaster())
                ChatHandler(passenger->GetSession()).PSendSysMessage(
                    "[Flight] Invalid waypoint index {}. Emergency landing.", idx);
            
            // Emergency land
            Position safeLand = EmergencyLandingSystem::FindNearestSafeLanding(
                me->GetPositionX(), me->GetPositionY(), me->GetPositionZ());
            _stateMachine.TransitionTo(FlightState::EmergencyLanding, FlightEvent::EmergencyTriggered);
            me->GetMotionMaster()->MoveLand(POINT_LAND_FINAL, safeLand, Debug::LANDING_DESCENT_SPEED);
            return;
        }
        
        _currentPointId = 10000u + idx;
        
        // Apply flight flags if state allows
        if (_stateMachine.ShouldApplyFlightFlags())
        {
            me->SetCanFly(true);
            me->SetDisableGravity(true);
            me->SetHover(true);
        }
        
        // Set speed using constants
        me->SetSpeedRate(MOVE_RUN, Speed::BASE_FLIGHT_RATE);
        me->SetSpeedRate(MOVE_FLIGHT, Speed::BASE_FLIGHT_RATE);
        
        // Move to position
        me->GetMotionMaster()->MovePoint(_currentPointId, posOpt.value());
        
        // Mark as awaiting arrival
        _stateMachine.TransitionTo(FlightState::Flying, FlightEvent::ReachedWaypoint);
        _awaitingArrival = true;
        _sinceMoveMs = 0;
        _hopElapsedMs = 0;
        _hopRetries = 0;
        
        // Debug output
        Player* passenger = GetCachedPassenger();
        if (passenger && passenger->IsGameMaster())
            ChatHandler(passenger->GetSession()).PSendSysMessage(
                "[Flight] Moving to {} (state: {}).", NodeLabel(idx), _stateMachine.GetStateName());
    }
    
    // === EXAMPLE: HandleArriveAtCurrentNode refactored with route strategy ===
    void HandleArriveAtCurrentNode(bool isProximity)
    {
        if (!_awaitingArrival)
            return;
        
        if (!_currentRoute)
        {
            // No route - emergency land
            _stateMachine.TransitionTo(FlightState::EmergencyLanding, FlightEvent::EmergencyTriggered);
            EmergencyLand();
            return;
        }
        
        Player* passenger = GetCachedPassenger();
        
        // Check for anchor bypass using route strategy
        uint8 nextIdx = _index;
        uint8 bypassIdx = 0;
        if (_currentRoute->ShouldBypassAnchor(nextIdx, bypassIdx))
        {
            if (passenger && passenger->IsGameMaster())
                ChatHandler(passenger->GetSession()).PSendSysMessage(
                    "[Flight] Bypassing sticky anchor {} -> {}.", NodeLabel(nextIdx), NodeLabel(bypassIdx));
            nextIdx = bypassIdx;
        }
        
        // Get next waypoint from route strategy
        if (_currentRoute->GetNextIndex(_index, nextIdx))
        {
            _awaitingArrival = false;
            _index = nextIdx;
            
            if (passenger && passenger->IsGameMaster())
                ChatHandler(passenger->GetSession()).PSendSysMessage(
                    "[Flight] {} at waypoint {}.", isProximity ? "Proximity arrival" : "Arrived", NodeLabel(_index));
            
            MoveToIndex(_index);
        }
        else
        {
            // Route complete - begin landing
            if (passenger && passenger->IsGameMaster())
                ChatHandler(passenger->GetSession()).PSendSysMessage(
                    "[Flight] Route complete at {}. Landing.", NodeLabel(_index));
            
            BeginLanding();
        }
    }
    
    // === NEW: Emergency landing helper ===
    void EmergencyLand()
    {
        Position safeLand = EmergencyLandingSystem::FindBestLanding(
            me->GetPositionX(), me->GetPositionY(), me->GetPositionZ());
        
        Player* passenger = GetCachedPassenger();
        if (passenger)
            ChatHandler(passenger->GetSession()).PSendSysMessage(
                "[Flight] Emergency landing at {}.", safeLand.ToString().c_str());
        
        me->SetSpeedRate(MOVE_FLIGHT, Speed::LANDING_RATE);
        me->GetMotionMaster()->MoveLand(POINT_LAND_FINAL, safeLand, Debug::LANDING_DESCENT_SPEED);
        
        _scheduler.Schedule(std::chrono::milliseconds(Timeout::LANDING_FALLBACK_MS), 
            [this](TaskContext ctx)
        {
            (void)ctx;
            if (me->IsInWorld())
                DismountAndDespawn();
        });
    }
    
    // === EXAMPLE: UpdateAI refactored with state machine ===
    void UpdateAI(uint32 diff) override
    {
        _scheduler.Update(diff);
        
        // Update passenger cache periodically
        _passengerCacheMs += diff;
        if (_passengerCacheMs > 1000) // Refresh every second
        {
            UpdatePassengerCache();
            _passengerCacheMs = 0;
        }
        
        // Apply flight flags based on state
        if (_stateMachine.ShouldApplyFlightFlags())
        {
            me->SetCanFly(true);
            me->SetDisableGravity(true);
            me->SetHover(true);
        }
        
        // State-specific logic
        if (_stateMachine.IsActivelyFlying())
        {
            // Check for proximity arrival
            _sinceMoveMs += diff;
            _hopElapsedMs += diff;
            
            if (_sinceMoveMs > Timeout::PROXIMITY_DEBOUNCE_MS)
            {
                // Use safe accessor for bounds checking
                auto targetPos = FlightPathAccessor::GetSafePosition(_index);
                if (targetPos)
                {
                    auto dist = FlightPathAccessor::GetDistanceToWaypoint(
                        me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), _index, false);
                    
                    if (dist && dist.value() < Distance::WAYPOINT_NEAR_2D)
                    {
                        HandleArriveAtCurrentNode(true);
                    }
                }
            }
            
            // Hop timeout check using constants
            if (_hopElapsedMs > Timeout::HOP_DEFAULT_MS)
            {
                Player* passenger = GetCachedPassenger();
                if (passenger && passenger->IsGameMaster())
                    ChatHandler(passenger->GetSession()).PSendSysMessage(
                        "[Flight] Hop timeout at {}. Attempting recovery.", NodeLabel(_index));
                
                _stateMachine.TransitionTo(FlightState::Stuck, FlightEvent::StuckDetected);
                // ... recovery logic ...
            }
        }
        
        // Check for no passenger
        if (_stateMachine.IsActivelyFlying() && !GetCachedPassenger())
        {
            _noPassengerMs += diff;
            if (_noPassengerMs >= Timeout::NO_PASSENGER_GRACE_MS)
            {
                _stateMachine.TransitionTo(FlightState::Despawning, FlightEvent::PlayerDisconnected);
                EmergencyLand();
            }
        }
        else
        {
            _noPassengerMs = 0;
        }
    }
    
    // === Other members (condensed for demonstration) ===
    enum : uint32 { POINT_TAKEOFF = 9000, POINT_LAND_FINAL = 9001 };
    TaskScheduler _scheduler;
    uint8 _index = 0;
    uint32 _currentPointId = 0;
    bool _awaitingArrival = false;
    uint32 _sinceMoveMs = 0;
    uint32 _hopElapsedMs = 0;
    uint8 _hopRetries = 0;
    uint32 _noPassengerMs = 0;
    
    void BeginLanding() { /* ... */ }
    void DismountAndDespawn() { /* ... */ }
};

} // namespace DC_AC_Flight

/*
 * INTEGRATION CHECKLIST:
 * 
 * 1. Add includes to ac_flightmasters.cpp:
 *    #include "FlightStateMachine.h"
 *    #include "FlightRouteStrategy.h"
 *    #include "FlightConstants.h"
 *    #include "FlightPathAccessor.h"
 *    #include "EmergencyLanding.h"
 * 
 * 2. Replace class members:
 *    - Remove: _started, _isLanding, _awaitingArrival, _movingToCustom
 *    - Add: FlightStateMachine _stateMachine;
 *    - Replace: FlightRouteMode _routeMode;
 *    - Add: std::unique_ptr<IFlightRoute> _currentRoute;
 *    - Add: std::optional<Player*> _cachedPassenger;
 *    - Add: uint32 _passengerCacheMs = 0;
 * 
 * 3. Replace all GetPassengerPlayer() calls with GetCachedPassenger()
 * 
 * 4. Replace all kPath[index] with FlightPathAccessor::GetSafePosition(index)
 * 
 * 5. Replace all magic numbers with FlightConstants:: equivalents
 * 
 * 6. Add UpdatePassengerCache() calls in UpdateAI (every ~1 second)
 * 
 * 7. Replace boolean flag checks:
 *    - _started -> !_stateMachine.IsIdle()
 *    - _isLanding -> _stateMachine.IsLanding() || _stateMachine.IsEmergencyLanding()
 *    - _awaitingArrival -> _stateMachine.IsArrivingAtWaypoint()
 *    - _movingToCustom -> _stateMachine.IsFollowingCustomPath()
 * 
 * 8. Add state transitions at key points:
 *    - Start flight: _stateMachine.TransitionTo(FlightState::Preparing, FlightEvent::StartFlight)
 *    - Begin flying: _stateMachine.TransitionTo(FlightState::Flying, FlightEvent::StartFlight)
 *    - Arrive at waypoint: _stateMachine.TransitionTo(FlightState::ArrivingAtWaypoint, FlightEvent::ReachedWaypoint)
 *    - Begin landing: _stateMachine.TransitionTo(FlightState::Landing, FlightEvent::BeginLanding)
 *    - Emergency: _stateMachine.TransitionTo(FlightState::EmergencyLanding, FlightEvent::EmergencyTriggered)
 *    - Despawn: _stateMachine.TransitionTo(FlightState::Despawning, FlightEvent::Despawn)
 * 
 * 9. Replace route switch statements with strategy pattern:
 *    - SetData: _currentRoute = FlightRouteFactory::CreateRoute(mode);
 *    - Get next: _currentRoute->GetNextIndex(current, next);
 *    - Check final: _currentRoute->IsFinalIndex(index);
 *    - Bypass: _currentRoute->ShouldBypassAnchor(anchor, bypass);
 * 
 * 10. Add emergency landing in failure paths:
 *     - Invalid index: EmergencyLand()
 *     - Stuck recovery exhausted: EmergencyLand()
 *     - No route: EmergencyLand()
 *     - Player disconnect: EmergencyLand()
 */
