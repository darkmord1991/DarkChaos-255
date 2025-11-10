#include "CreatureScript.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "TaskScheduler.h"
#include "Vehicle.h"
#include "Chat.h"
#include "SharedDefines.h"
#include "PathGenerator.h"
#include "ac_flightmasters_data.h"
#include "ac_flightmasters_path.h"
#include "MoveSplineInit.h"
// === NEW: Refactoring includes ===
#include "FlightConstants.h"
#include "FlightStateMachine.h"
#include "FlightRouteStrategy.h"
#include "FlightPathAccessor.h"
#include "EmergencyLanding.h"
#include <type_traits>
#include <chrono>
#include <string>
#include <sstream>
#include <cmath>
#include <numeric>
#include <deque>
#include <vector>
#include <limits>
#include <algorithm>
#include <list>

namespace DC_AC_Flight
{
// NPCs
enum : uint32
{
    NPC_FLIGHTMASTER_CAMP  = 800010,  // DB: ScriptName = acflightmaster0
    NPC_FLIGHTMASTER_L25   = 800012,  // DB: ScriptName = acflightmaster25
    NPC_FLIGHTMASTER_L40   = 800013,  // DB: ScriptName = acflightmaster40
    NPC_FLIGHTMASTER_L60   = 800014,  // DB: ScriptName = acflightmaster60
    NPC_AC_GRYPHON_TAXI    = 800011   // DB: vehicle-capable gryphon, ScriptName = ac_gryphon_taxi_800011
};

// Route selection for the flight
// enum FlightRouteMode : uint32
// {
//     // Camp (acfm0) starts
//     ROUTE_TOUR          = 0,  // Camp to Level 25+: acfm1 -> acfm15
//     ROUTE_L40_DIRECT    = 1,  // Camp to Level 40+: acfm1 -> ... -> acfm35
//     ROUTE_L0_TO_57      = 2,  // Camp to Level 60+: acfm1 -> ... -> acfm57
//
//     // Level 25+ starts
//     ROUTE_RETURN        = 3,  // Level 25+ to Camp: acfm15 -> ... -> acfm0
//     ROUTE_L25_TO_40     = 4,  // Level 25+ to Level 40+: acfm19 -> ... -> acfm35
//     ROUTE_L25_TO_60     = 5,  // Level 25+ to Level 60+: acfm19 -> ... -> acfm57
//
//     // Level 40+ starts
//     ROUTE_L40_RETURN25  = 6,  // Level 40+ to Level 25+: acfm35 -> ... -> acfm19
//     ROUTE_L40_SCENIC    = 7,  // Level 40+ to Level 60+: acfm40 -> ... -> acfm57
//
//     // Level 60+ starts
//     ROUTE_L60_RETURN40  = 8,  // Level 60+ to Level 40+: acfm57 -> ... -> acfm40
//     ROUTE_L60_RETURN19  = 9,  // Level 60+ to Level 25+: acfm57 -> ... -> acfm19
//     ROUTE_L60_RETURN0   = 10  // Level 60+ to Camp: acfm57 -> ... -> acfm0
//     ,ROUTE_L40_RETURN0  = 11  // Level 40+ to Camp: acfm35 -> ... -> acfm0
// };

// Gossip action IDs for readability
enum GossipAction : uint32
{
    // Camp (acfm0)
    GA_TOUR_25              = 1,  // Camp to Level 25+ (acfm1 -> acfm15)
    GA_L40_DIRECT           = 2,  // Camp to Level 40+ (to acfm35)
    GA_L0_TO_57             = 3,  // Camp to Level 60+ (to acfm57)

    // Level 25+
    GA_RETURN_STARTCAMP     = 4,  // Level 25+ to Camp
    GA_L25_TO_40            = 5,  // Level 25+ to Level 40+
    GA_L25_TO_60            = 6,  // Level 25+ to Level 60+

    // Level 40+
    GA_L40_BACK_TO_25       = 7,  // Level 40+ to Level 25+
    GA_L40_SCENIC_40_TO_57  = 8,  // Level 40+ to Level 60+
    GA_L40_BACK_TO_0        = 12, // Level 40+ to Camp

    // Level 60+
    GA_L60_BACK_TO_40       = 9,  // Level 60+ to Level 40+
    GA_L60_BACK_TO_25       = 10, // Level 60+ to Level 25+
    GA_L60_BACK_TO_0        = 11  // Level 60+ to Camp
};

// Data and helpers moved to ac_flightmasters_data.h

// Per-node override configuration
struct NodeConfig { uint8 escalationThreshold; float nudgeExtraZ; };

// Gryphon vehicle AI that follows the above path with the boarded player in seat 0
class ac_gryphon_taxi_800011AI : public VehicleAI
{
    enum : uint32 { POINT_TAKEOFF = 9000, POINT_LAND_FINAL = 9001 };
    
    // === NEW: State machine replaces boolean flags ===
    FlightStateMachine _stateMachine;
    
    // === NEW: Route strategy replaces switch statements ===
    std::unique_ptr<IFlightRoute> _currentRoute;
    
    // === NEW: Cached passenger replaces 30+ GetPassengerPlayer calls ===
    std::optional<Player*> _cachedPassenger;
    uint32 _passengerCacheMs = 0;
    
    // Flight state (kept for gradual migration)
    bool _awaitingArrival = false;   // awaiting MovementInform/arrival handling
    bool _landingScheduled = false;  // scheduled landing fallback task
    uint8 _index = 0;                // current waypoint index
    uint32 _currentPointId = 0;      // current MovePoint id

    // Additional flight state variables
    bool _isLanding = false;         // whether the gryphon is currently landing
    bool _started = false;           // whether the flight has started
    FlightRouteMode _routeMode = ROUTE_TOUR; // current route mode

    // Default per-node config: only acfm57 needs more aggressive handling so far
    static const std::vector<NodeConfig> kPerNodeConfigDefaults;

public:
    ac_gryphon_taxi_800011AI(Creature* creature) : VehicleAI(creature) { }

    void SetData(uint32 id, uint32 value) override
    {
        // Expect id==1 as the route selection (sent by SummonTaxiAndStart)
        if (id != 1)
            return;

        // === NEW: Create route strategy ===
        FlightRouteMode mode = static_cast<FlightRouteMode>(value);
        _currentRoute = FlightRouteFactory::CreateRoute(mode);
        _routeMode = mode; // Store the route mode
        
        if (!_currentRoute)
        {
            UpdatePassengerCache();
            Player* routeFailPlayer = GetCachedPassenger();
            if (routeFailPlayer && routeFailPlayer->IsGameMaster())
                ChatHandler(routeFailPlayer->GetSession()).SendSysMessage("[Flight] Failed to create route.");
            return;
        }
        
        // === NEW: Transition to Preparing state ===
        if (!_stateMachine.TransitionTo(FlightState::Preparing, FlightEvent::StartFlight))
        {
            UpdatePassengerCache();
            Player* stateFailPlayer = GetCachedPassenger();
            if (stateFailPlayer && stateFailPlayer->IsGameMaster())
                ChatHandler(stateFailPlayer->GetSession()).SendSysMessage("[Flight] State transition failed.");
            return;
        }
        
        // === NEW: Update passenger cache ===
        UpdatePassengerCache();

        // Reset state
        _awaitingArrival = false;
        _landingScheduled = false;
        _movingToCustom = false;
        _smartPathQueue.clear();
        _scheduler.CancelAll();
        _customPointSeq = 0;
        _pathfindingRetries = 0;
        _useSmartPathfinding = false;
        _sinceMoveMs = 0;
        _hopElapsedMs = 0;
        _hopRetries = 0;
        _lastArrivedIdx = 255;
        // initialize per-node failure counters sized to path length
        _nodeFailCount.assign(FlightPathAccessor::GetPathLength(), 0);
        _noPassengerMs = 0;
        _stuckMs = 0;
        _lastPosX = me->GetPositionX();
        _lastPosY = me->GetPositionY();
        _flightStartPos = me->GetPosition();
        _lastDepartIdx = 255;
        _lastBypassedAnchor = 255;
        _bypassMs = Timeout::BYPASS_TIMEOUT_MS;
        me->SetCanFly(true);
        me->SetDisableGravity(true);
        me->SetHover(true);
        me->GetMotionMaster()->Clear();
        
        // === NEW: Get starting index from route strategy ===
        Player* startPlayer = GetCachedPassenger();
        _index = _currentRoute->GetStartIndex(me->GetPositionX(), me->GetPositionY(), me->GetPositionZ());
        
        // === NEW: Validate with bounds checking ===
        if (!FlightPathAccessor::IsValidIndex(_index))
        {
            if (startPlayer && startPlayer->IsGameMaster())
                ChatHandler(startPlayer->GetSession()).PSendSysMessage("[Flight] Invalid start index. Emergency landing to destination.");
            
            // Use route destination so player arrives where they wanted to go
            auto destination = EmergencyLandingSystem::GetRouteDestination(_currentRoute->GetMode());
            Position safeLand = destination.value_or(
                EmergencyLandingSystem::FindNearestSafeLanding(
                    me->GetPositionX(), me->GetPositionY(), me->GetPositionZ()));
            
            me->NearTeleportTo(safeLand.GetPositionX(), safeLand.GetPositionY(), 
                             safeLand.GetPositionZ(), safeLand.GetOrientation());
            _stateMachine.TransitionTo(FlightState::EmergencyLanding, FlightEvent::EmergencyTriggered);
            return;
        }
        
        // Check for anchor bypass using route strategy
        uint8 nextIdx = _index;
        uint8 bypassIdx = 0;
        if (_currentRoute->ShouldBypassAnchor(nextIdx, bypassIdx))
        {
            if (startPlayer && startPlayer->IsGameMaster())
                ChatHandler(startPlayer->GetSession()).PSendSysMessage(
                    "[Flight Debug] Bypassing sticky anchor {} -> {}.", NodeLabel(nextIdx), NodeLabel(bypassIdx));
            _index = bypassIdx;
        }
        
        // Debug output
        if (startPlayer && startPlayer->IsGameMaster())
            ChatHandler(startPlayer->GetSession()).PSendSysMessage(
                "[Flight Debug] Starting {} from {}.", _currentRoute->GetName(), NodeLabel(_index));
        
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
                    _started = true; // Flight has started
                    MoveToIndexWithSmartPath(_index);
                }
            });
        }
        else
        {
            // Start directly
            _stateMachine.TransitionTo(FlightState::Flying, FlightEvent::StartFlight);
            _started = true; // Flight has started
            MoveToIndexWithSmartPath(_index);
        }
    }

    void MovementInform(uint32 type, uint32 id) override
    {
        if (type != POINT_MOTION_TYPE)
            return;

        if (id == POINT_TAKEOFF)
            return; // ignore pre-flight lift

        if (id == POINT_LAND_FINAL)
        {
            // Landed: dismount any passengers and despawn gently
            // Allow gravity and disable hover so the creature settles properly
            me->SetHover(false);
            me->SetDisableGravity(false);
            me->SetCanFly(false);
            _isLanding = false;
            _started = false; // Flight has ended
            DismountAndDespawn();
            return;
        }

        // If we are aiming at a custom smoothing target, intercept arrival and proceed to next smart point or to real waypoint
        if (_movingToCustom && id == _currentPointId)
        {
            // If we have more smart-path points queued, continue chaining to the next one
            if (!_smartPathQueue.empty())
            {
                Position next = _smartPathQueue.front();
                _smartPathQueue.pop_front();
                // remain in custom-moving mode and issue next hop
                _movingToCustom = true;
                MoveToCustom(next);
                return;
            }

            // No more smart-path points: finish custom movement and continue to the planned waypoint
            _movingToCustom = false;
            _awaitingArrival = false;

            // Reset pathfinding retry counter on successful intermediate point arrival
            if (_useSmartPathfinding)
            {
                _pathfindingRetries = 0;
                _useSmartPathfinding = false;
            }

            // After finishing smart-path chain, continue to the planned real index
            MoveToIndex(_index);
            return;
        }

        if (id == _currentPointId)
        {
            HandleArriveAtCurrentNode(false /*isProximity*/);
        }
    }

    // Allow the passenger to trigger an early exit by emote (/wave or /salute)
    void ReceiveEmote(Player* player, uint32 emoteId) override
    {
        if (!_started || _isLanding)
            return;
        Player* passenger = GetCachedPassenger();
        if (!passenger || passenger->GetGUID() != player->GetGUID())
            return;
        // Accept both text and animation emotes for wave/salute
        bool wantsExit = (emoteId == TEXT_EMOTE_WAVE || emoteId == TEXT_EMOTE_SALUTE
                       || emoteId == EMOTE_ONESHOT_WAVE || emoteId == EMOTE_ONESHOT_SALUTE);
        if (!wantsExit)
            return;

        ChatHandler(player->GetSession()).SendSysMessage("[Flight] Early exit requested. Landing now.");
        // Stop following waypoints and attempt a smooth land at current XY
        _awaitingArrival = false;
        _landingScheduled = false;
        _isLanding = true;
        me->GetMotionMaster()->Clear();

        float x = me->GetPositionX();
        float y = me->GetPositionY();
        float z = me->GetPositionZ();
        me->UpdateGroundPositionZ(x, y, z);
        Position landPos = { x, y, z + 0.5f, me->GetOrientation() };
        me->SetSpeedRate(MOVE_FLIGHT, Speed::LANDING_RATE);
        me->GetMotionMaster()->MoveLand(POINT_LAND_FINAL, landPos, Speed::LAND_APPROACH_SPEED);
        // Fallback in 5s in case land inform is missed
        _scheduler.Schedule(std::chrono::milliseconds(Timeout::EARLY_EXIT_FALLBACK_MS), [this](TaskContext ctx)
        {
            (void)ctx;
            if (!me->IsInWorld())
                return;
            if (_isLanding)
            {
                Player* earlyExitPlayer = GetCachedPassenger();
                if (earlyExitPlayer && earlyExitPlayer->IsGameMaster())
                    ChatHandler(earlyExitPlayer->GetSession()).SendSysMessage("[Flight Debug] Early-exit landing fallback.");
                float fx = me->GetPositionX();
                float fy = me->GetPositionY();
                float fz = me->GetPositionZ();
                me->UpdateGroundPositionZ(fx, fy, fz);
                me->NearTeleportTo(fx, fy, fz + 0.5f, me->GetOrientation());
                me->SetHover(false);
                me->SetDisableGravity(false);
                me->SetCanFly(false);
                _isLanding = false;
                DismountAndDespawn();
            }
        });
    }

    bool IsFinalNodeOfCurrentRoute(uint8 idx) const
    {
        switch (_routeMode)
        {
            case ROUTE_TOUR:
                return idx >= kIndex_acfm15;
            case ROUTE_RETURN:
                return idx == kIndex_startcamp;
            case ROUTE_L40_DIRECT:
            case ROUTE_L25_TO_40:
                return idx >= kIndex_acfm35;
            case ROUTE_L0_TO_57:
            case ROUTE_L25_TO_60:
            case ROUTE_L40_SCENIC:
                return idx >= kIndex_acfm57;
            case ROUTE_L40_RETURN25:
            case ROUTE_L60_RETURN19:
                return idx <= kIndex_acfm19;
            case ROUTE_L60_RETURN40:
                return idx <= kIndex_acfm40;
            case ROUTE_L60_RETURN0:
            case ROUTE_L40_RETURN0:
                return idx == kIndex_startcamp;
            default:
                return idx >= LastScenicIndex();
        }
    }

    bool IsNearIndex(uint8 idx, float max2d) const
    {
        if (idx >= kPathLength)
            return false;

        auto pos = FlightPathAccessor::GetSafePosition(idx);
        if (!pos)
            return false;

        float dx = me->GetPositionX() - pos->GetPositionX();
        float dy = me->GetPositionY() - pos->GetPositionY();
        float dz = fabsf(me->GetPositionZ() - pos->GetPositionZ());
        float dist2d = sqrtf(dx * dx + dy * dy);
        return dist2d <= max2d && dz <= Distance::WAYPOINT_NEAR_Z_RELAXED;
    }

    float ComputeTurnAngleDeg(uint8 prevIdx, uint8 currIdx, uint8 nextIdx) const
    {
        auto a = FlightPathAccessor::GetSafePosition(prevIdx);
        auto b = FlightPathAccessor::GetSafePosition(currIdx);
        auto c = FlightPathAccessor::GetSafePosition(nextIdx);
        if (!a || !b || !c)
            return 0.0f;

        float v1x = b->GetPositionX() - a->GetPositionX();
        float v1y = b->GetPositionY() - a->GetPositionY();
        float v2x = c->GetPositionX() - b->GetPositionX();
        float v2y = c->GetPositionY() - b->GetPositionY();

        float len1 = sqrtf(v1x * v1x + v1y * v1y);
        float len2 = sqrtf(v2x * v2x + v2y * v2y);
        if (len1 < 0.001f || len2 < 0.001f)
            return 0.0f;

        float dot = (v1x * v2x) + (v1y * v2y);
        float cosTheta = dot / (len1 * len2);
        if (cosTheta > 1.0f)
            cosTheta = 1.0f;
        else if (cosTheta < -1.0f)
            cosTheta = -1.0f;

        float angleRad = acosf(cosTheta);
        return angleRad * 57.2957795f; // rad -> deg
    }
    // Gracefully dismount passengers and despawn the taxi
    void DismountAndDespawn()
    {
        if (Player* p = GetCachedPassenger())
            p->ExitVehicle();

        me->SetHover(false);
        me->SetDisableGravity(false);
        me->SetCanFly(false);
        
        // Reset flight state variables
        _isLanding = false;
        _started = false;
        _routeMode = ROUTE_TOUR;
        
        me->DespawnOrUnsummon(1000ms);
    }    void UpdateAI(uint32 diff) override
    {
        // Drive scheduled tasks
        _scheduler.Update(diff);
        
        // === NEW: Update passenger cache periodically ===
        _passengerCacheMs += diff;
        if (_passengerCacheMs >= 1000)
        {
            UpdatePassengerCache();
            _passengerCacheMs = 0;
        }

        // === NEW: Apply flight flags based on state machine ===
        if (_stateMachine.ShouldApplyFlightFlags())
        {
            me->SetCanFly(true);
            me->SetDisableGravity(true);
            me->SetHover(true);
        }

        // Proximity-based waypoint arrival fallback in case MovementInform is skipped
        if (_awaitingArrival)
        {
            Player* passenger = GetCachedPassenger();
            _sinceMoveMs += diff;
            _hopElapsedMs += diff; // watchdog for per-hop timeouts
            if (_sinceMoveMs > Timeout::PROXIMITY_CHECK_DEBOUNCE_MS)
            {
                // Choose current target (either a custom smoothing point or the real path node)
                auto targetPos = FlightPathAccessor::GetSafePosition(_index);
                if (!targetPos)
                {
                    // Invalid index - trigger emergency landing to destination
                    Player* invalidIndexPlayer = GetCachedPassenger();
                    if (invalidIndexPlayer && invalidIndexPlayer->IsGameMaster())
                        ChatHandler(invalidIndexPlayer->GetSession()).PSendSysMessage("[Flight] Invalid path index {}. Emergency landing to destination.", _index);
                    
                    auto destination = EmergencyLandingSystem::GetRouteDestination(_currentRoute->GetMode());
                    Position safeLand = destination.value_or(
                        EmergencyLandingSystem::FindNearestSafeLanding(
                            me->GetPositionX(), me->GetPositionY(), me->GetPositionZ()));
                    
                    me->NearTeleportTo(safeLand.GetPositionX(), safeLand.GetPositionY(), 
                                     safeLand.GetPositionZ(), safeLand.GetOrientation());
                    _stateMachine.TransitionTo(FlightState::EmergencyLanding, FlightEvent::EmergencyTriggered);
                    return;
                }
                
                float tx = _movingToCustom ? _customTarget.GetPositionX() : targetPos->GetPositionX();
                float ty = _movingToCustom ? _customTarget.GetPositionY() : targetPos->GetPositionY();
                float tz = _movingToCustom ? _customTarget.GetPositionZ() : targetPos->GetPositionZ();
                float dx = me->GetPositionX() - tx;
                float dy = me->GetPositionY() - ty;
                float dz = fabs(me->GetPositionZ() - tz);
                float dist2d = sqrtf(dx * dx + dy * dy);
                
                // Relax vertical tolerance slightly because smart hops and terrain can cause Z offsets
                float near2d = (_index >= kIndex_acfm40) ? Distance::WAYPOINT_NEAR_2D_L40 : Distance::WAYPOINT_NEAR_2D;
                float nearDz = Distance::WAYPOINT_NEAR_Z;
                
                // Known anchor: acfm19 can be sticky when descending from 40+ → Camp; accept a wider proximity
                if (_currentRoute && _currentRoute->GetMode() == ROUTE_L40_RETURN0 && _index == kIndex_acfm19)
                    near2d = Distance::WAYPOINT_NEAR_2D_STICKY;
                    
                if (dist2d < near2d && dz < nearDz)
                {
                    // If we were aiming at a custom smoothing target, chain to the real index
                    if (_movingToCustom)
                    {
                        _movingToCustom = false;
                        _awaitingArrival = false;
                        MoveToIndex(_index);
                    }
                    else
                    {
                        HandleArriveAtCurrentNode(true /*isProximity*/);
                    }
                }
                else
                {
                        // Per-node proximity tuning: nodes known to be sticky get relaxed near2d thresholds
                        if (_index == 2 || _index == 30 || _index == 13) // acfm3, acfm34, acfm14
                        {
                            near2d = std::max(near2d, Distance::NODE_STICKY_NEAR_2D);
                        }
                        // The L25 -> L40 final anchor (acfm15) can be finicky in some terrain; accept a wider proximity
                        if (_currentRoute && _currentRoute->GetMode() == ROUTE_L25_TO_40 && _index == kIndex_acfm15)
                        {
                            near2d = std::max(near2d, Distance::L25_TO_L40_FINAL_NEAR);
                        }

                        // Special-case watchdog: if we're targeting acfm19 on 40+ → Camp for too long, skip directly to acfm15
                        if (_currentRoute && _currentRoute->GetMode() == ROUTE_L40_RETURN0 && 
                            _index == kIndex_acfm19 && 
                            _hopElapsedMs > Timeout::ANCHOR19_SKIP_MS && 
                            !_stateMachine.IsDescending())
                    {
                        Player* anchorSkipPlayer = GetCachedPassenger();
                        if (anchorSkipPlayer && anchorSkipPlayer->IsGameMaster())
                            ChatHandler(anchorSkipPlayer->GetSession()).PSendSysMessage("[Flight Debug] Anchor {} timeout. Skipping to {}.", NodeLabel(_index), NodeLabel(kIndex_acfm15));
                        _awaitingArrival = false;
                        _index = kIndex_acfm15;
                        MoveToIndex(_index);
                        return;
                    }
                    uint32 hopTimeout = (_currentRoute && _currentRoute->GetMode() == ROUTE_L40_SCENIC ? Timeout::HOP_SCENIC_MS : Timeout::HOP_DEFAULT_MS);
                    if (_movingToCustom)
                        hopTimeout = Timeout::HOP_CUSTOM_MS;
                    if (_hopElapsedMs > hopTimeout && !_stateMachine.IsDescending())
                    {
                        // Hop timeout: try to reissue movement, a few times; then hard-snap to target to avoid loops
                        if (_hopRetries < 1)
                        {
                            ++_hopRetries;
                            // Reassert flight and reissue the same MovePoint without spamming chat
                            me->SetCanFly(true);
                            me->SetDisableGravity(true);
                            me->SetHover(true);
                            me->GetMotionMaster()->Clear();
                            if (_movingToCustom)
                            {
                                me->GetMotionMaster()->MovePoint(_currentPointId, _customTarget);
                            }
                            else
                            {
                                auto pos = FlightPathAccessor::GetSafePosition(_index);
                                if (pos)
                                    me->GetMotionMaster()->MovePoint(_currentPointId, *pos);
                            }
                            _hopElapsedMs = 0;
                            // record a minor failure for this node
                            if (_index < _nodeFailCount.size())
                                ++_nodeFailCount[_index];
                        }
                        else if (_hopRetries == 1)
                        {
                            // Rate-limited micro-nudge: skip if we recently nudged this same node
                            if (_lastNudgeIdx == _index && _lastNudgeMs < Timeout::MICRO_NUDGE_RATE_LIMIT_MS)
                            {
                                Player* skipNudgePlayer = GetCachedPassenger();
                                if (skipNudgePlayer && skipNudgePlayer->IsGameMaster())
                                    ChatHandler(skipNudgePlayer->GetSession()).PSendSysMessage("[Flight Debug] Skipping micro-nudge for {} (rate-limit).", NodeLabel(_index));

                                // Try smart pathfinding before hard fallback
                                if (_pathfindingRetries < 1 && !_useSmartPathfinding && !_movingToCustom)
                                {
                                    _pathfindingRetries++;
                                    if (passenger && passenger->IsGameMaster())
                                        ChatHandler(passenger->GetSession()).PSendSysMessage("[Flight Debug] Hop timeout at {}. Trying smart pathfinding recovery.", NodeLabel(_index));
                                    
                                    _awaitingArrival = false;
                                    _hopElapsedMs = 0;
                                    _hopRetries = 0;
                                    MoveToIndexWithSmartPath(_index);
                                    return;
                                }

                                // Hard fallback: snap to target node and continue the route
                                if (passenger && passenger->IsGameMaster())
                                    ChatHandler(passenger->GetSession()).PSendSysMessage("[Flight Debug] Final timeout at {}. Snapping to target to continue.", _movingToCustom ? std::string("corner"): NodeLabel(_index));
                                
                                auto targetPos = FlightPathAccessor::GetSafePosition(_index);
                                if (!targetPos)
                                {
                                    // Emergency landing to destination if invalid index
                                    auto destination = EmergencyLandingSystem::GetRouteDestination(_currentRoute->GetMode());
                                    Position safeLand = destination.value_or(
                                        EmergencyLandingSystem::FindNearestSafeLanding(
                                            me->GetPositionX(), me->GetPositionY(), me->GetPositionZ()));
                                    
                                    me->NearTeleportTo(safeLand.GetPositionX(), safeLand.GetPositionY(), 
                                                     safeLand.GetPositionZ(), safeLand.GetOrientation());
                                    _stateMachine.TransitionTo(FlightState::EmergencyLanding, FlightEvent::EmergencyTriggered);
                                    return;
                                }
                                
                                float tx = _movingToCustom ? _customTarget.GetPositionX() : targetPos->GetPositionX();
                                float ty = _movingToCustom ? _customTarget.GetPositionY() : targetPos->GetPositionY();
                                float tz = _movingToCustom ? _customTarget.GetPositionZ() : targetPos->GetPositionZ();
                                me->UpdateGroundPositionZ(tx, ty, tz);
                                me->NearTeleportTo(tx, ty, tz + Recovery::SNAP_HEIGHT_OFFSET, targetPos->GetOrientation());
                                _hopElapsedMs = 0;
                                _hopRetries = 0;
                                _pathfindingRetries = 0;
                                if (_movingToCustom)
                                {
                                    _movingToCustom = false;
                                    _useSmartPathfinding = false;
                                    _awaitingArrival = false;
                                    MoveToIndex(_index);
                                }
                                else
                                {
                                    HandleArriveAtCurrentNode(true /*isProximity*/);
                                }
                                return;
                            }

                            // On the second retry, issue a tiny micro-nudge: reissue MovePoint slightly above target
                            ++_hopRetries;
                            
                            auto targetPos = FlightPathAccessor::GetSafePosition(_index);
                            if (!targetPos)
                                return; // Can't nudge to invalid position
                                
                            float nudgex = _movingToCustom ? _customTarget.GetPositionX() : targetPos->GetPositionX();
                            float nudgey = _movingToCustom ? _customTarget.GetPositionY() : targetPos->GetPositionY();
                            float nudgez = (_movingToCustom ? _customTarget.GetPositionZ() : targetPos->GetPositionZ()) + Recovery::MICRO_NUDGE_HEIGHT;
                            
                            // Per-node extra nudgeZ (configurable)
                            float perNodeExtra = (_index < FlightPathAccessor::GetPathLength() ? _perNodeConfig[_index].nudgeExtraZ : 0.0f);
                            nudgez += perNodeExtra;
                            
                            // If this node has repeatedly failed, escalate the nudge height for stubborn spots
                            uint8 nodeEscThresh = (_index < FlightPathAccessor::GetPathLength() ? _perNodeConfig[_index].escalationThreshold : kFailEscalationThreshold);
                            if (_index < _nodeFailCount.size() && _nodeFailCount[_index] >= nodeEscThresh)
                            {
                                nudgez += Recovery::ESCALATED_NUDGE_HEIGHT;
                                Player* escalationPlayer = GetCachedPassenger();
                                if (escalationPlayer && escalationPlayer->IsGameMaster())
                                    ChatHandler(escalationPlayer->GetSession()).PSendSysMessage("[Flight Debug] Escalation: increased micro-nudge at {} (failcount={}).", NodeLabel(_index), static_cast<uint32>(_nodeFailCount[_index]));
                            }
                            Position nudgePos(nudgex, nudgey, nudgez, 0.0f);
                            me->GetMotionMaster()->Clear();
                            me->GetMotionMaster()->MovePoint(_currentPointId, nudgePos);
                            Player* nudgePlayer = GetCachedPassenger();
                            if (nudgePlayer && nudgePlayer->IsGameMaster())
                                ChatHandler(nudgePlayer->GetSession()).PSendSysMessage("[Flight Debug] Micro-nudge issued to help clear obstacle at {}.", NodeLabel(_index));
                            _lastNudgeIdx = _index;
                            _lastNudgeMs = 0;
                            _hopElapsedMs = 0;
                            // record this micro-nudge as a failure attempt for the node
                            if (_index < _nodeFailCount.size())
                                ++_nodeFailCount[_index];
                        }
                        else
                        {
                            // Try smart pathfinding before hard fallback
                            if (_pathfindingRetries < 1 && !_useSmartPathfinding && !_movingToCustom)
                            {
                                _pathfindingRetries++;
                                Player* smartRecoveryPlayer = GetCachedPassenger();
                                if (smartRecoveryPlayer && smartRecoveryPlayer->IsGameMaster())
                                    ChatHandler(smartRecoveryPlayer->GetSession()).PSendSysMessage("[Flight Debug] Hop timeout at {}. Trying smart pathfinding recovery.", NodeLabel(_index));
                                
                                _awaitingArrival = false;
                                _hopElapsedMs = 0;
                                _hopRetries = 0;
                                MoveToIndexWithSmartPath(_index);
                                return;
                            }
                            
                            // Hard fallback: snap to target node and continue the route
                            Player* hardFallbackPlayer = GetCachedPassenger();
                            if (hardFallbackPlayer && hardFallbackPlayer->IsGameMaster())
                                ChatHandler(hardFallbackPlayer->GetSession()).PSendSysMessage("[Flight Debug] Final timeout at {}. Snapping to target to continue.", _movingToCustom ? std::string("corner"): NodeLabel(_index));
                            
                            auto targetPos = FlightPathAccessor::GetSafePosition(_index);
                            if (!targetPos)
                            {
                                auto destination = EmergencyLandingSystem::GetRouteDestination(_currentRoute->GetMode());
                                Position safeLand = destination.value_or(
                                    EmergencyLandingSystem::FindNearestSafeLanding(
                                        me->GetPositionX(), me->GetPositionY(), me->GetPositionZ()));
                                
                                me->NearTeleportTo(safeLand.GetPositionX(), safeLand.GetPositionY(), 
                                                 safeLand.GetPositionZ(), safeLand.GetOrientation());
                                _stateMachine.TransitionTo(FlightState::EmergencyLanding, FlightEvent::EmergencyTriggered);
                                return;
                            }
                            
                            float tx = _movingToCustom ? _customTarget.GetPositionX() : targetPos->GetPositionX();
                            float ty = _movingToCustom ? _customTarget.GetPositionY() : targetPos->GetPositionY();
                            float tz = _movingToCustom ? _customTarget.GetPositionZ() : targetPos->GetPositionZ();
                            me->UpdateGroundPositionZ(tx, ty, tz);
                            me->NearTeleportTo(tx, ty, tz + Recovery::SNAP_HEIGHT_OFFSET, targetPos->GetOrientation());
                            _hopElapsedMs = 0;
                            _hopRetries = 0;
                            _pathfindingRetries = 0;
                            // On hard fallback, count this as a failure and consider escalation
                            if (_index < _nodeFailCount.size())
                                ++_nodeFailCount[_index];
                            if (_movingToCustom)
                            {
                                _movingToCustom = false;
                                _useSmartPathfinding = false;
                                _awaitingArrival = false;
                                MoveToIndex(_index);
                            }
                            else
                            {
                                // Consider this as arrival by proximity to advance the route
                                HandleArriveAtCurrentNode(true /*isProximity*/);
                            }
                            return;
                        }
                    }
                }
            }

            // Final-hop watchdog: if we are aiming at the final node of this route and it's taking too long,
            // snap to the node and immediately start landing to prevent loops/spam.
            if (!_isLanding && !_movingToCustom && IsFinalNodeOfCurrentRoute(_index))
            {
                uint32 finalTimeout = 6000u;
                // Level-25 -> Level-40 routes visit a number of close anchors in quick succession and
                // sometimes need a bit more time to settle into the final node; lengthen the timeout
                // so we don't prematurely trigger the landing fallback. Keep L40 direct routes stricter.
                if (_routeMode == ROUTE_L40_DIRECT)
                    finalTimeout = 4000u;
                else if (_routeMode == ROUTE_L25_TO_40)
                    finalTimeout = 8000u;
                if (_hopElapsedMs > finalTimeout)
                {
                    Player* finalHopPlayer = GetCachedPassenger();
                    if (finalHopPlayer && finalHopPlayer->IsGameMaster())
                        ChatHandler(finalHopPlayer->GetSession()).PSendSysMessage("[Flight Debug] Final hop timeout at {}. Landing now.", NodeLabel(_index));
                    
                    auto finalPos = FlightPathAccessor::GetSafePosition(_index);
                    if (!finalPos)
                    {
                        // Emergency landing if final position invalid
                        auto destination = EmergencyLandingSystem::GetRouteDestination(_routeMode);
                        Position safePos = destination.value_or(
                            EmergencyLandingSystem::FindNearestSafeLanding(
                                me->GetPositionX(), me->GetPositionY(), me->GetPositionZ()));
                        
                        me->NearTeleportTo(safePos.GetPositionX(), safePos.GetPositionY(), 
                                         safePos.GetPositionZ(), safePos.GetOrientation());
                        if (Player* p = GetCachedPassenger())
                            p->NearTeleportTo(safePos.GetPositionX(), safePos.GetPositionY(), 
                                            safePos.GetPositionZ(), safePos.GetOrientation());
                        DismountAndDespawn();
                        return;
                    }

                    float fx = finalPos->GetPositionX();
                    float fy = finalPos->GetPositionY();
                    float fz = finalPos->GetPositionZ();
                    me->UpdateGroundPositionZ(fx, fy, fz);
                    me->NearTeleportTo(fx, fy, fz + 0.5f, finalPos->GetOrientation());
                    _awaitingArrival = false;
                    // Begin landing without waiting for another arrival event
                    me->SetSpeedRate(MOVE_FLIGHT, Speed::LANDING_RATE);
                    _isLanding = true;
                    me->GetMotionMaster()->MoveLand(POINT_LAND_FINAL, { fx, fy, fz + 0.5f, finalPos->GetOrientation() }, Speed::LAND_APPROACH_SPEED);
                    if (!_landingScheduled)
                    {
                        _landingScheduled = true;
                        _scheduler.Schedule(std::chrono::milliseconds(Timeout::LANDING_FALLBACK_MS), [this](TaskContext ctx)
                        {
                            (void)ctx;
                            if (!me->IsInWorld())
                                return;
                            Player* landingFallbackPlayer = GetCachedPassenger();
                            if (landingFallbackPlayer && landingFallbackPlayer->IsGameMaster())
                                ChatHandler(landingFallbackPlayer->GetSession()).SendSysMessage("[Flight Debug] Landing fallback triggered. Snapping to ground and dismounting safely.");
                            float gx = me->GetPositionX();
                            float gy = me->GetPositionY();
                            float gz = me->GetPositionZ();
                            me->UpdateGroundPositionZ(gx, gy, gz);
                            me->NearTeleportTo(gx, gy, gz + 0.5f, me->GetOrientation());
                            me->SetHover(false);
                            me->SetDisableGravity(false);
                            me->SetCanFly(false);
                            _isLanding = false;
                            DismountAndDespawn();
                        });
                    }
                    return;
                }
            }
        }

        // Advance bypass timer (avoid remapping repeatedly)
        if (_bypassMs < Timeout::BYPASS_TIMEOUT_MS)
            _bypassMs += diff;
        if (_bypassMs > Timeout::BYPASS_THROTTLE_MS && _lastBypassedAnchor != 255)
            _lastBypassedAnchor = 255;

        // Advance micro-nudge timer (rate-limiting)
        if (_lastNudgeMs < 60000)
            _lastNudgeMs += diff;
        if (_lastNudgeMs >= kMicroNudgeRateLimitMs && _lastNudgeIdx != 255)
            _lastNudgeIdx = 255;

        // Stuck control: if the gryphon hasn't moved significantly for 20 seconds while flying, recover
        if (_started && !_isLanding)
        {
            float cX = me->GetPositionX();
            float cY = me->GetPositionY();
            float move2d = sqrtf((cX - _lastPosX) * (cX - _lastPosX) + (cY - _lastPosY) * (cY - _lastPosY));
            if (move2d < 0.5f)
            {
                if (_stuckMs < 60000) // cap to avoid overflow
                    _stuckMs += diff;
            }
            else
            {
                _stuckMs = 0;
                _lastPosX = cX;
                _lastPosY = cY;
            }
            if (_stuckMs >= Timeout::STUCK_DETECT_MS)
            {
                Player* stuckRecoveryPlayer = GetCachedPassenger();
                if (stuckRecoveryPlayer && stuckRecoveryPlayer->IsGameMaster())
                    ChatHandler(stuckRecoveryPlayer->GetSession()).SendSysMessage("[Flight Debug] Stuck detected for 20s. Attempting smart-path recovery to destination before fallback.");

                // Attempt smart path recovery to the current route's final destination
                uint8 finalIdx = _index; // default to current
                // Determine route final destination index
                if (IsFinalNodeOfCurrentRoute(_index))
                    finalIdx = _index;
                else
                {
                    // Choose nearest final node for route
                    switch (_routeMode)
                    {
                        case ROUTE_L25_TO_40:
                        case ROUTE_L40_DIRECT:
                            finalIdx = kIndex_acfm35; break;
                        case ROUTE_L25_TO_60:
                        case ROUTE_L40_SCENIC:
                        case ROUTE_L0_TO_57:
                            finalIdx = kIndex_acfm57; break;
                        case ROUTE_L60_RETURN40:
                            finalIdx = kIndex_acfm40; break;
                        case ROUTE_L60_RETURN19:
                            finalIdx = kIndex_acfm19; break;
                        case ROUTE_L60_RETURN0:
                        case ROUTE_L40_RETURN0:
                            finalIdx = kIndex_startcamp; break;
                        default:
                            finalIdx = LastScenicIndex(); break;
                    }
                }

                auto destPos = FlightPathAccessor::GetSafePosition(finalIdx);
                if (!destPos)
                {
                    // Emergency landing if destination invalid
                    auto dest = EmergencyLandingSystem::GetRouteDestination(_routeMode);
                    if (dest)
                    {
                        me->NearTeleportTo(dest->GetPositionX(), dest->GetPositionY(), dest->GetPositionZ(), dest->GetOrientation());
                        if (Player* p = GetCachedPassenger())
                            p->NearTeleportTo(dest->GetPositionX(), dest->GetPositionY(), dest->GetPositionZ(), dest->GetOrientation());
                    }
                    DismountAndDespawn();
                    return;
                }

                Position dest(destPos->GetPositionX(), destPos->GetPositionY(), destPos->GetPositionZ(), destPos->GetOrientation());
                if (!_pathHelper)
                    _pathHelper = std::make_unique<FlightPathHelper>(me);
                // Use centralized helper to calculate and queue intermediate smart-path points
                if (_pathHelper->CalculateAndQueue(dest, _smartPathQueue, me) && !_smartPathQueue.empty())
                {
                    Position next = _smartPathQueue.front();
                    _smartPathQueue.pop_front();
                    _useSmartPathfinding = true;
                    _awaitingArrival = false;
                    _hopElapsedMs = 0;
                    _stuckMs = 0;
                    MoveToCustom(next);
                    return;
                }

                // If smart path failed, fallback to previous behaviour: teleport back to start and dismount
                Player* passenger = GetCachedPassenger();
                if (passenger && passenger->IsGameMaster())
                    ChatHandler(passenger->GetSession()).SendSysMessage("[Flight Debug] Smart-path recovery failed. Teleporting to start and dismounting.");
                float sx = _flightStartPos.GetPositionX();
                float sy = _flightStartPos.GetPositionY();
                float sz = _flightStartPos.GetPositionZ();
                me->UpdateGroundPositionZ(sx, sy, sz);
                me->NearTeleportTo(sx, sy, sz + 0.5f, _flightStartPos.GetOrientation());
                me->SetHover(false);
                me->SetDisableGravity(false);
                me->SetCanFly(false);
                _isLanding = false;
                _awaitingArrival = false;
                _landingScheduled = false;
                DismountAndDespawn();
                return;
            }
        }

        // If no passenger remains, only despawn after a short grace (avoid transient seat updates)
        if (_started && !_isLanding)
        {
            if (!GetCachedPassenger())
            {
                if (_noPassengerMs < 60000)
                    _noPassengerMs += diff;
                if (_noPassengerMs >= 2000)
                {
                    float x = me->GetPositionX();
                    float y = me->GetPositionY();
                    float z = me->GetPositionZ();
                    me->UpdateGroundPositionZ(x, y, z);
                    me->NearTeleportTo(x, y, z + 0.5f, me->GetOrientation());
                    me->SetHover(false);
                    me->SetDisableGravity(false);
                    me->SetCanFly(false);
                    _awaitingArrival = false;
                    _isLanding = false;
                    _landingScheduled = false;
                    DismountAndDespawn();
                    return;
                }
            }
            else
            {
                _noPassengerMs = 0;
            }
        }
    }

    void MoveToIndex(uint8 idx)
    {
        auto pos = FlightPathAccessor::GetSafePosition(idx);
        if (!pos)
        {
            // Emergency landing if waypoint invalid
            auto dest = EmergencyLandingSystem::GetRouteDestination(_routeMode);
            if (dest)
            {
                me->NearTeleportTo(dest->GetPositionX(), dest->GetPositionY(), dest->GetPositionZ(), dest->GetOrientation());
                if (Player* p = GetCachedPassenger())
                    p->NearTeleportTo(dest->GetPositionX(), dest->GetPositionY(), dest->GetPositionZ(), dest->GetOrientation());
            }
            DismountAndDespawn();
            return;
        }

        _currentPointId = 10000u + idx; // unique id per node
        // Reassert flying for each hop to avoid any gravity re-enabling from vehicle state changes
        me->SetCanFly(true);
        me->SetDisableGravity(true);
        me->SetHover(true);
        me->SetSpeedRate(MOVE_RUN, _baseSpeedRate);
        me->SetSpeedRate(MOVE_FLIGHT, _baseSpeedRate);
        me->GetMotionMaster()->MovePoint(_currentPointId, *pos);
        _awaitingArrival = true;
        _sinceMoveMs = 0;
        _hopElapsedMs = 0;
        _hopRetries = 0;
        if (Player* departPlayer = GetCachedPassenger())
        {
            if (_lastDepartIdx != idx)
                if (departPlayer->IsGameMaster())
                    ChatHandler(departPlayer->GetSession()).PSendSysMessage("[Flight Debug] Departing to {} (idx {}).", NodeLabel(idx), (uint32)idx);
        }
        _lastDepartIdx = idx;
    }

    void MoveToCustom(Position const& pos)
    {
        _customTarget = pos;
        _movingToCustom = true;
        _currentPointId = 20000u + (++_customPointSeq); // unique id for custom targets
        me->SetCanFly(true);
        me->SetDisableGravity(true);
        me->SetHover(true);
        me->SetSpeedRate(MOVE_RUN, _baseSpeedRate);
        me->SetSpeedRate(MOVE_FLIGHT, _baseSpeedRate);
        me->GetMotionMaster()->MovePoint(_currentPointId, _customTarget);
        _awaitingArrival = true;
        _sinceMoveMs = 0;
        _hopElapsedMs = 0;
        _hopRetries = 0;
    }

    void AdjustSpeedForTurn(float angleDeg)
    {
        // Heuristic: map angle to speed multiplier. 0deg => 1.0, >90 => 0.8
        float rate = 1.0f;
        if (angleDeg > 75.0f) rate = 0.78f;
        else if (angleDeg > 35.0f) rate = 0.88f;
        else rate = 1.0f;
        SmoothAndSetSpeed(rate);
    }

    void SmoothAndSetSpeed(float targetRate)
    {
        if (!_pathHelper)
            _pathHelper = std::make_unique<FlightPathHelper>(me);
        // Clamp multiplier inside a sane window so sharp turns never stall completely.
        float clamped = std::max(0.6f, std::min(1.1f, targetRate));
        _pathHelper->SmoothAndSetSpeed(clamped * _baseSpeedRate);
    }

    Player* GetPassengerPlayer() const
    {
        if (Vehicle* kit = me->GetVehicleKit())
        {
            for (int i = 0; i < 8; ++i)
                if (Unit* u = kit->GetPassenger(i))
                    if (Player* p = u->ToPlayer())
                        return p;
        }
        return nullptr;
    }
    
    // === NEW: Cached passenger methods ===
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
    
    Player* GetCachedPassenger() const
    {
        return _cachedPassenger.value_or(nullptr);
    }

public:
    TaskScheduler _scheduler;
    uint32 _sinceMoveMs = 0; // time since last MovePoint for proximity fallback
    uint32 _hopElapsedMs = 0; // time since last hop started
    uint8 _hopRetries = 0;    // reissues before hard snap
    // Stuck detection
    float _lastPosX = 0.0f;
    float _lastPosY = 0.0f;
    uint32 _stuckMs = 0;
    Position _flightStartPos;
    uint32 _noPassengerMs = 0; // grace timer when no passenger aboard
    bool _l25to40ResetApplied = false; // ensure the L25→40 sanity reset runs at most once per flight
    uint8 _lastDepartIdx = 255;
    uint8 _lastArrivedIdx = 255;
    uint8 _lastNudgeIdx = 255;
    uint32 _lastNudgeMs = 0;
    // Configurable micro-nudge rate limit (ms)
    static constexpr uint32 kMicroNudgeRateLimitMs = 10000u; // default 10s
    // Number of failures on a node before escalation (force bypass/smart-path)
    static constexpr uint8 kFailEscalationThreshold = 3;
    // Per-instance copy of per-node config so we can tune active taxis at runtime
    std::vector<NodeConfig> _perNodeConfig;
    // Per-node persistent failure counters
    std::vector<uint8> _nodeFailCount;
    // Anchor bypass throttling to avoid repeating remaps in quick succession
    uint8 _lastBypassedAnchor = 255;
    uint32 _bypassMs = 0; // ms since last bypass
    // Corner smoothing state
    bool _movingToCustom = false;
    Position _customTarget;
    uint32 _customPointSeq = 0;
    float _baseSpeedRate = 3.0f;
    
    // Enhanced pathfinding helper (encapsulates PathGenerator and smoothing)
    std::unique_ptr<FlightPathHelper> _pathHelper;
    bool _useSmartPathfinding = false;
    uint32 _pathfindingRetries = 0;
    std::deque<Position> _smartPathQueue; // queued intermediate positions from PathHelper
    
    // Enhanced pathfinding with fallback to waypoints
    void MoveToIndexWithSmartPath(uint8 idx)
    {
        // initialize per-instance per-node config from defaults
        _perNodeConfig = kPerNodeConfigDefaults;

        auto destPos = FlightPathAccessor::GetSafePosition(idx);
        if (!destPos)
        {
            // Emergency landing if waypoint invalid
            auto dest = EmergencyLandingSystem::GetRouteDestination(_routeMode);
            if (dest)
            {
                me->NearTeleportTo(dest->GetPositionX(), dest->GetPositionY(), dest->GetPositionZ(), dest->GetOrientation());
                if (Player* p = GetCachedPassenger())
                    p->NearTeleportTo(dest->GetPositionX(), dest->GetPositionY(), dest->GetPositionZ(), dest->GetOrientation());
            }
            DismountAndDespawn();
            return;
        }

        Position destination(destPos->GetPositionX(), destPos->GetPositionY(),
                             destPos->GetPositionZ(), destPos->GetOrientation());

        // Known sticky hop: acfm34 -> acfm35 sits under tree cover. Inject a short vertical arc to avoid terrain clipping.
        if (idx == kIndex_acfm35 && _lastArrivedIdx == kIndex_acfm35 - 1 &&
            (_routeMode == ROUTE_L40_DIRECT || _routeMode == ROUTE_L25_TO_40))
        {
            _smartPathQueue.clear();

            Position rise = me->GetPosition();
            rise.m_positionZ = std::max(rise.GetPositionZ() + Recovery::ARC_RISE_HEIGHT, 
                                       destination.GetPositionZ() + Recovery::ARC_GLIDE_MIN_HEIGHT);
            // escalate arc height if this node keeps failing (use per-node override if present)
            uint8 escThresh = (idx < kPathLength ? _perNodeConfig[idx].escalationThreshold : kFailEscalationThreshold);
            if (idx < _nodeFailCount.size() && _nodeFailCount[idx] >= escThresh)
            {
                rise.m_positionZ += Recovery::ARC_ESCALATION_HEIGHT;
                Player* gmPlayer = GetCachedPassenger();
                if (gmPlayer && gmPlayer->IsGameMaster())
                    ChatHandler(gmPlayer->GetSession()).PSendSysMessage("[Flight Debug] Escalation: increased elevation arc for {} due to repeated failures.", NodeLabel(idx));
            }

            Position glide = destination;
            glide.m_positionZ = std::max(rise.GetPositionZ(), destination.GetPositionZ() + Recovery::ARC_GLIDE_MIN_HEIGHT);

            _smartPathQueue.push_back(rise);
            _smartPathQueue.push_back(glide);
            _smartPathQueue.push_back(destination);

            _useSmartPathfinding = true;
            _pathfindingRetries = 0;

            Position next = _smartPathQueue.front();
            _smartPathQueue.pop_front();
            MoveToCustom(next);
            Player* terrainArcPlayer = GetCachedPassenger();
            if (terrainArcPlayer && terrainArcPlayer->IsGameMaster())
                ChatHandler(terrainArcPlayer->GetSession()).PSendSysMessage("[Flight Debug] Elevating arc to clear terrain for {}.", NodeLabel(idx));
            return;
        }

        // Final hop back to Startcamp can clip the hillside; fly a shallow overhead approach when returning to camp routes.
        if (idx == kIndex_startcamp &&
            (_routeMode == ROUTE_RETURN || _routeMode == ROUTE_L40_RETURN0 || _routeMode == ROUTE_L60_RETURN0) &&
            _lastArrivedIdx <= 2)
        {
            _smartPathQueue.clear();

            Position rise = me->GetPosition();
            rise.m_positionZ = std::max(rise.GetPositionZ() + Recovery::OVERHEAD_APPROACH_HEIGHT, 
                                       destination.GetPositionZ() + Recovery::ARC_ESCALATION_HEIGHT);
            // escalate overhead approach if Startcamp is repeatedly failing
            uint8 escThreshSC = (idx < kPathLength ? _perNodeConfig[idx].escalationThreshold : kFailEscalationThreshold);
            if (idx < _nodeFailCount.size() && _nodeFailCount[idx] >= escThreshSC)
            {
                rise.m_positionZ += Recovery::OVERHEAD_ESCALATION_HEIGHT; // much higher overhead approach
                Player* gmPlayerSC = GetCachedPassenger();
                if (gmPlayerSC && gmPlayerSC->IsGameMaster())
                    ChatHandler(gmPlayerSC->GetSession()).PSendSysMessage("[Flight Debug] Escalation: stronger overhead approach for Startcamp due to repeated failures.");
            }

            Position approach = destination;
            approach.m_positionZ = std::max(rise.GetPositionZ(), destination.GetPositionZ() + Recovery::ARC_ESCALATION_HEIGHT);

            _smartPathQueue.push_back(rise);
            _smartPathQueue.push_back(approach);
            _smartPathQueue.push_back(destination);

            _useSmartPathfinding = true;
            _pathfindingRetries = 0;

            Position next = _smartPathQueue.front();
            _smartPathQueue.pop_front();
            MoveToCustom(next);
            Player* startcampArcPlayer = GetCachedPassenger();
            if (startcampArcPlayer && startcampArcPlayer->IsGameMaster())
                ChatHandler(startcampArcPlayer->GetSession()).PSendSysMessage("[Flight Debug] Overhead arc engaged for Startcamp landing.");
            return;
        }

        // Calculate distance to see if smart pathfinding is needed
        float dx = me->GetPositionX() - destination.GetPositionX();
        float dy = me->GetPositionY() - destination.GetPositionY();
        float dz = me->GetPositionZ() - destination.GetPositionZ();
        float dist3D = sqrtf(dx*dx + dy*dy + dz*dz);
        
        // Use smart pathfinding for medium/long distances or when stuck recovery is needed
        if (dist3D > 120.0f || _pathfindingRetries > 0)
        {
            if (!_pathHelper)
                _pathHelper = std::make_unique<FlightPathHelper>(me);
            if (_pathHelper->CalculateAndQueue(destination, _smartPathQueue, me) && !_smartPathQueue.empty())
            {
                if (_smartPathQueue.size() == 1 && dist3D < 220.0f)
                {
                    // One-step smart paths on short legs tend to oscillate; but some single-point fixes
                    // are valuable (e.g., to avoid small obstacles). Accept the single hop only when it
                    // meaningfully differs from the scripted waypoint to avoid oscillation.
                    Position candidate = _smartPathQueue.front();
                    float ddx = candidate.GetPositionX() - destination.GetPositionX();
                    float ddy = candidate.GetPositionY() - destination.GetPositionY();
                    float d2 = ddx * ddx + ddy * ddy;
                    // Require at least ~2.0 units horizontal difference to accept the single smart hop
                    // (be a bit more permissive to allow small obstacle corrections)
                    constexpr float minDeviationSq = Distance::SINGLE_SMART_HOP_MIN * Distance::SINGLE_SMART_HOP_MIN;
                    if (d2 > minDeviationSq)
                    {
                        Player* smartHopPlayer = GetCachedPassenger();
                        if (smartHopPlayer && smartHopPlayer->IsGameMaster())
                            ChatHandler(smartHopPlayer->GetSession()).PSendSysMessage("[Flight Debug] Accepting single smart hop for {} (dx={:.1f}).", NodeLabel(idx), sqrtf(d2));
                        // leave queue intact and process below
                    }
                    else
                    {
                        Player* fallbackPlayer = GetCachedPassenger();
                        if (fallbackPlayer && fallbackPlayer->IsGameMaster())
                            ChatHandler(fallbackPlayer->GetSession()).PSendSysMessage("[Flight Debug] Smart path reduced to single hop for {}. Falling back to scripted point.", NodeLabel(idx));
                        _smartPathQueue.clear();
                    }
                }
                else if (!_smartPathQueue.empty())
                {
                    // Pop the first queued point and move to it; MovementInform chaining will continue
                    Position next = _smartPathQueue.front();
                    _smartPathQueue.pop_front();
                    _useSmartPathfinding = true;
                    MoveToCustom(next);
                    Player* multiHopPlayer = GetCachedPassenger();
                    if (multiHopPlayer && multiHopPlayer->IsGameMaster())
                        ChatHandler(multiHopPlayer->GetSession()).PSendSysMessage("[Flight Debug] Using smart pathfinding to {} via {} smart points", NodeLabel(idx), static_cast<uint32>(_smartPathQueue.size() + 1));
                    return;
                }
            }
        }
        
        // Fallback to regular waypoint movement
        if (_useSmartPathfinding)
        {
            Player* fallbackPathPlayer = GetCachedPassenger();
            if (fallbackPathPlayer && fallbackPathPlayer->IsGameMaster())
                ChatHandler(fallbackPathPlayer->GetSession()).PSendSysMessage("[Flight Debug] Smart pathfinding unavailable for {}. Continuing on scripted path.", NodeLabel(idx));
        }
        _useSmartPathfinding = false;
        MoveToIndex(idx);
    }

    void HandleArriveAtCurrentNode(bool isProximity)
    {
        if (!_awaitingArrival)
            return; // already handled

        Player* handleArrivalPlayer = GetCachedPassenger();

        // Sanity guard: if Level 40+ → 60+ route somehow starts at the final node (acfm57)
        // while we are NOT near acfm57, reset to a proper starting anchor
        if (_currentRoute && _currentRoute->GetMode() == ROUTE_L40_SCENIC && _index == kIndex_acfm57)
        {
            auto pos57 = FlightPathAccessor::GetDistanceToWaypoint(
                me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), kIndex_acfm57, false);
            
            if (pos57.value_or(999.0f) > Distance::START_NEARBY_THRESHOLD)
            {
                // Decide anchor: if near acfm40, start at acfm41; otherwise start from acfm1
                auto pos40 = FlightPathAccessor::GetDistanceToWaypoint(
                    me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), kIndex_acfm40, false);
                
                uint8 start = (pos40.value_or(999.0f) < Distance::START_NEARBY_THRESHOLD) 
                    ? static_cast<uint8>(kIndex_acfm40 + 1) : 0;
                
                if (handleArrivalPlayer && handleArrivalPlayer->IsGameMaster())
                    ChatHandler(handleArrivalPlayer->GetSession()).PSendSysMessage("[Flight Debug] Sanity: resetting Level 40+ → 60+ start from {} to {}.", NodeLabel(_index), NodeLabel(start));
                _awaitingArrival = false;
                _index = start;
                MoveToIndex(_index);
                return;
            }
        }

        // Sanity guard: if Level 25+ → 60 route somehow targets the final node (acfm57)
        // while we are NOT near acfm57, reset to a proper starting anchor
        if (_currentRoute && _currentRoute->GetMode() == ROUTE_L25_TO_60 && _index == kIndex_acfm57)
        {
            auto pos57 = FlightPathAccessor::GetDistanceToWaypoint(
                me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), kIndex_acfm57, false);
            
            if (pos57.value_or(999.0f) > Distance::START_NEARBY_THRESHOLD)
            {
                // Choose anchor: acfm20 if near acfm19, otherwise start from acfm1
                uint8 start = IsNearIndex(kIndex_acfm19, Distance::START_NEARBY_THRESHOLD) 
                    ? static_cast<uint8>(kIndex_acfm19 + 1) : 0;
                
                if (handleArrivalPlayer && handleArrivalPlayer->IsGameMaster())
                    ChatHandler(handleArrivalPlayer->GetSession()).PSendSysMessage("[Flight Debug] Sanity: resetting Level 25+ → 60 start from {} to {}.", NodeLabel(_index), NodeLabel(start));
                _awaitingArrival = false;
                _index = start;
                MoveToIndex(_index);
                return;
            }
        }

        // Sanity guard: if Level 25+ → 40 route somehow targets the final node (acfm35)
        // while we are NOT near acfm35, reset to an earlier anchor
        if (_currentRoute && _currentRoute->GetMode() == ROUTE_L25_TO_40 && _index == kIndex_acfm35 && !_l25to40ResetApplied)
        {
            auto pos35 = FlightPathAccessor::GetDistanceToWaypoint(
                me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), kIndex_acfm35, false);
            
            // Only perform this reset if we're significantly far and have been on this hop for a bit
            if (pos35.value_or(0.0f) > Distance::SANITY_CHECK_DISTANCE && _hopElapsedMs > Timeout::HOP_SCENIC_MS)
            {
                // Prefer stepping from acfm34 if near; otherwise anchor from acfm19; else from acfm1
                auto pos34 = FlightPathAccessor::GetDistanceToWaypoint(
                    me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), 
                    static_cast<uint8>(kIndex_acfm35 - 1), false);
                
                uint8 start = 0;
                if (pos34.value_or(999.0f) < Distance::START_NEARBY_THRESHOLD)
                    start = static_cast<uint8>(kIndex_acfm35 - 1);
                else if (IsNearIndex(kIndex_acfm19, Distance::START_NEARBY_THRESHOLD))
                    start = kIndex_acfm19;
                else
                    start = 0;
                    
                if (handleArrivalPlayer && handleArrivalPlayer->IsGameMaster())
                    ChatHandler(handleArrivalPlayer->GetSession()).PSendSysMessage("[Flight Debug] Sanity: resetting Level 25+ → 40 start from {} to {}.", NodeLabel(_index), NodeLabel(start));
                _awaitingArrival = false;
                _l25to40ResetApplied = true;
                _index = start;
                MoveToIndex(_index);
                return;
            }
        }

        // === NEW: Use route strategy to determine next index ===
        Player* routePlayer = GetCachedPassenger();
        
        // Get next index from route strategy
        uint8 finalIdx = 0;
        uint8 nextIdx = _currentRoute->GetNextIndex(_index, finalIdx);
        bool hasNext = !_currentRoute->IsFinalIndex(_index);
        
        if (hasNext)
        {
            uint8 arrivedIdx = _index;
            _lastArrivedIdx = arrivedIdx;
            _awaitingArrival = false;
            
            // === NEW: Check for anchor bypass using route strategy ===
            uint8 bypassIdx = nextIdx;
            if (_currentRoute->ShouldBypassAnchor(nextIdx, bypassIdx))
            {
                // Throttle: skip if we recently bypassed this anchor
                if (_lastBypassedAnchor == nextIdx && _bypassMs < Timeout::BYPASS_THROTTLE_MS)
                {
                    if (routePlayer && routePlayer->IsGameMaster())
                        ChatHandler(routePlayer->GetSession()).PSendSysMessage("[Flight Debug] Skipping redundant bypass for {} (throttle).", NodeLabel(nextIdx));
                }
                else
                {
                    if (routePlayer && routePlayer->IsGameMaster())
                        ChatHandler(routePlayer->GetSession()).PSendSysMessage(
                            "[Flight Debug] Route bypass: {} -> {}.", NodeLabel(nextIdx), NodeLabel(bypassIdx));
                    
                    nextIdx = bypassIdx;
                    _lastBypassedAnchor = arrivedIdx;
                    _bypassMs = 0;
                }
            }
            
            // Check for anchor-specific bypass (acfm35)
            if (nextIdx == kIndex_acfm35)
            {
                // Throttle repeated acfm35 remaps as well
                if (_lastBypassedAnchor == kIndex_acfm35 && _bypassMs < Timeout::BYPASS_THROTTLE_MS)
                {
                    if (routePlayer && routePlayer->IsGameMaster())
                        ChatHandler(routePlayer->GetSession()).PSendSysMessage("[Flight Debug] Skipping redundant bypass for acfm35 (throttle).");
                }
                else
                {
                    // For routes that target acfm35, prefer stepping from acfm34 to avoid a single long sticky hop
                    uint8 altPrev = static_cast<uint8>(kIndex_acfm35 - 1);
                    auto dist34 = FlightPathAccessor::GetDistanceToWaypoint(
                        me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), altPrev, false);
                    
                    if (dist34.value_or(999.0f) < Distance::START_TAKEOFF_THRESHOLD)
                        nextIdx = altPrev;
                    else if (kIndex_acfm35 + 1 < FlightPathAccessor::GetPathLength())
                        nextIdx = static_cast<uint8>(kIndex_acfm35 + 1);

                    _lastBypassedAnchor = kIndex_acfm35;
                    _bypassMs = 0;
                    if (routePlayer && routePlayer->IsGameMaster())
                        ChatHandler(routePlayer->GetSession()).PSendSysMessage(
                            "[Flight Debug] Aggressive bypass: remapped anchor acfm35 -> {}.", NodeLabel(nextIdx));
                }
            }
            // Turn-aware speed smoothing: slow down on sharp turns to reduce camera shake
            {
                bool ascending = nextIdx > arrivedIdx;
                uint8 prevIdx = arrivedIdx;
                if (ascending)
                {
                    if (arrivedIdx > 0)
                        prevIdx = static_cast<uint8>(arrivedIdx - 1);
                }
                else
                {
                    if (arrivedIdx + 1 < FlightPathAccessor::GetPathLength())
                        prevIdx = static_cast<uint8>(arrivedIdx + 1);
                }
                float angleDeg = ComputeTurnAngleDeg(prevIdx, arrivedIdx, nextIdx);
                AdjustSpeedForTurn(angleDeg);
            }
            _index = nextIdx; // move to next index
            if (routePlayer && routePlayer->IsGameMaster())
                ChatHandler(routePlayer->GetSession()).PSendSysMessage(isProximity ? "[Flight Debug] Reached waypoint {} (proximity)." : "[Flight Debug] Reached waypoint {}.", NodeLabel(arrivedIdx));
            // Reset per-node failure counter on successful arrival
            if (arrivedIdx < _nodeFailCount.size())
                _nodeFailCount[arrivedIdx] = 0;
            // Corner smoothing: if the turn is sharp, perform a short micro-hop along the outgoing direction
            {
                // Recompute turn using prevIdx/arrivedIdx/nextIdx from the smoothing block above
                bool ascending = _index > arrivedIdx;
                uint8 prevIdx = arrivedIdx;
                if (ascending)
                {
                    if (arrivedIdx > 0)
                        prevIdx = static_cast<uint8>(arrivedIdx - 1);
                }
                else
                {
                    if (arrivedIdx + 1 < FlightPathAccessor::GetPathLength())
                        prevIdx = static_cast<uint8>(arrivedIdx + 1);
                }
                float angleDeg = ComputeTurnAngleDeg(prevIdx, arrivedIdx, _index);
                float r = 0.0f;
                if (angleDeg > Distance::CORNER_TURN_SHARP_DEG) 
                    r = Distance::CORNER_SMOOTH_SHARP;
                else if (angleDeg > Distance::CORNER_TURN_MEDIUM_DEG) 
                    r = Distance::CORNER_SMOOTH_MEDIUM;
                
                if (r > 0.0f)
                {
                    // Create a point a short distance along the outgoing direction from the corner node
                    auto posArrived = FlightPathAccessor::GetSafePosition(arrivedIdx);
                    auto posNext = FlightPathAccessor::GetSafePosition(_index);
                    
                    if (posArrived && posNext)
                    {
                        const Position& pc = *posArrived;
                        const Position& pn = *posNext;
                    float vx = pn.GetPositionX() - pc.GetPositionX();
                    float vy = pn.GetPositionY() - pc.GetPositionY();
                    float vz = pn.GetPositionZ() - pc.GetPositionZ();
                    float len = sqrtf(vx*vx + vy*vy);
                    if (len > 0.001f)
                    {
                        vx /= len; vy /= len;
                        Position corner = { pc.GetPositionX() + vx * r, pc.GetPositionY() + vy * r, pc.GetPositionZ() + (vz>0? std::min(vz, r*0.2f): std::max(vz, -r*0.2f)), me->GetOrientation() };
                        MoveToCustom(corner);
                        return;
                    }
                    }
                }
            }
            MoveToIndexWithSmartPath(_index);
            return;
        }

        // === NEW: Transition to descending state ===
        _stateMachine.TransitionTo(FlightState::Descending, FlightEvent::ApproachingAnchor);

        // Final node reached: initiate a safe landing, then dismount at ground
        // Guard: ensure we are truly close to the final spot; if not, do one more MovePoint to the exact node
        auto finalPos = FlightPathAccessor::GetSafePosition(_index);
        if (finalPos)
        {
            auto distToFinal = FlightPathAccessor::GetDistanceToWaypoint(
                me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), _index, true);
            
            if (distToFinal.value_or(0.0f) > Distance::NODE_STICKY_NEAR_2D || 
                fabs(me->GetPositionZ() - finalPos->GetPositionZ()) > Distance::WAYPOINT_NEAR_Z)
            {
                // Snap one more hop to the exact final location before landing
                _awaitingArrival = true;
                MoveToIndex(_index);
                return;
            }
        }

        // Bleed speed before landing to avoid overshoot
        me->SetSpeedRate(MOVE_FLIGHT, Speed::LANDING_RATE);
        
        if (finalPos)
        {
            float x = finalPos->GetPositionX();
            float y = finalPos->GetPositionY();
            float z = finalPos->GetPositionZ();
            me->UpdateGroundPositionZ(x, y, z);
            Position landPos = { x, y, z + Debug::LANDING_HEIGHT_OFFSET, finalPos->GetOrientation() };
            
            _stateMachine.TransitionTo(FlightState::Landing, FlightEvent::StartLanding);
            me->GetMotionMaster()->MoveLand(POINT_LAND_FINAL, landPos, Speed::LAND_APPROACH_SPEED);
            
            // Fallback: if landing inform does not trigger, snap to ground and dismount safely
            if (!_landingScheduled)
            {
                _landingScheduled = true;
                _scheduler.Schedule(std::chrono::milliseconds(Timeout::LANDING_FALLBACK_MS), [this](TaskContext ctx)
                {
                    (void)ctx;
                    if (!me->IsInWorld())
                        return;
                    Player* landingFallbackPlayer = GetCachedPassenger();
                    if (landingFallbackPlayer && landingFallbackPlayer->IsGameMaster())
                        ChatHandler(landingFallbackPlayer->GetSession()).SendSysMessage("[Flight Debug] Landing fallback triggered. Snapping to ground and dismounting safely.");
                    
                    // Snap the gryphon to ground at the final node before dismounting passengers
                    auto fallbackPos = FlightPathAccessor::GetSafePosition(_index);
                    if (!fallbackPos)
                    {
                        // Ultimate fallback - emergency landing
                        auto dest = EmergencyLandingSystem::GetRouteDestination(_routeMode);
                        if (dest)
                        {
                            me->NearTeleportTo(dest->GetPositionX(), dest->GetPositionY(), dest->GetPositionZ(), dest->GetOrientation());
                            if (Player* emergencyTeleportPlayer = GetCachedPassenger())
                                emergencyTeleportPlayer->NearTeleportTo(dest->GetPositionX(), dest->GetPositionY(), dest->GetPositionZ(), dest->GetOrientation());
                        }
                        DismountAndDespawn();
                        return;
                    }

                    float fx = fallbackPos->GetPositionX();
                    float fy = fallbackPos->GetPositionY();
                    float fz = fallbackPos->GetPositionZ();
                    me->UpdateGroundPositionZ(fx, fy, fz);
                    me->NearTeleportTo(fx, fy, fz + 0.5f, fallbackPos->GetOrientation());
                me->SetHover(false);
                me->SetDisableGravity(false);
                me->SetCanFly(false);
                _isLanding = false;
                DismountAndDespawn();
            });
        }
    }
};
// Script wrapper for the gryphon taxi AI
class ac_gryphon_taxi_800011 : public CreatureScript
{
public:
    ac_gryphon_taxi_800011() : CreatureScript("ac_gryphon_taxi_800011") { }
    CreatureAI* GetAI(Creature* creature) const override
    {
        return new ac_gryphon_taxi_800011AI(creature);
    }
};

// Shared helper to summon the gryphon taxi and start with a given route mode
static bool SummonTaxiAndStart(Player* player, Creature* creature, FlightRouteMode mode)
{
    Position where = creature->GetPosition();
    where.m_positionZ += 3.0f;
    Creature* taxi = creature->SummonCreature(NPC_AC_GRYPHON_TAXI, where, TEMPSUMMON_TIMED_DESPAWN, 300000);
    if (!taxi)
    {
        ChatHandler(player->GetSession()).PSendSysMessage("[Flight] Failed to summon gryphon (entry {}).", static_cast<uint32>(NPC_AC_GRYPHON_TAXI));
        return false;
    }
    taxi->setActive(true);
    taxi->SetReactState(REACT_PASSIVE);
    taxi->SetUnitFlag(UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE | UNIT_FLAG_PACIFIED | UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC);
    taxi->SetFaction(creature->GetFaction());
    taxi->SetDisableGravity(true);
    taxi->SetCanFly(true);
    taxi->SetHover(true);
    taxi->SetSpeedRate(MOVE_RUN, 3.0f);
    taxi->SetSpeedRate(MOVE_FLIGHT, 3.0f);
    taxi->SetHealth(taxi->GetMaxHealth());
    if (!taxi->GetVehicleKit())
    {
        ChatHandler(player->GetSession()).PSendSysMessage("[Flight] The summoned gryphon has no VehicleId. Please set creature_template.VehicleId for entry {} and ScriptName=ac_gryphon_taxi_800011.", static_cast<uint32>(taxi->GetEntry()));
    taxi->DespawnOrUnsummon(1000ms);
        return false;
    }
    player->EnterVehicle(taxi, -1);
    if (!player->GetVehicle())
        player->EnterVehicle(taxi, 0);
    if (!player->GetVehicle())
    {
        ChatHandler(player->GetSession()).SendSysMessage("[Flight] Could not place you on the gryphon. Check VehicleId seat 0 in the database.");
    taxi->DespawnOrUnsummon(1000ms);
        return false;
    }
    if (CreatureAI* ai = taxi->AI())
        ai->SetData(1, static_cast<uint32>(mode));
    if (player->IsGameMaster())
        ChatHandler(player->GetSession()).SendSysMessage("[Flight Debug] Attempting to board gryphon (auto-seat). If you don't move, VehicleId/seat config may be wrong.");
    return true;
}

// Camp flightmaster (NPC 800010)
class acflightmaster0 : public CreatureScript
{
public:
    acflightmaster0() : CreatureScript("acflightmaster0") {}

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());
        AddGossipItemFor(player, 0, "Camp to Level 25+", GOSSIP_SENDER_MAIN, GA_TOUR_25);
        AddGossipItemFor(player, 0, "Camp to Level 40+", GOSSIP_SENDER_MAIN, GA_L40_DIRECT);
        AddGossipItemFor(player, 0, "Camp to Level 60+", GOSSIP_SENDER_MAIN, GA_L0_TO_57);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);
        FlightRouteMode mode = ROUTE_TOUR;
        if (action == GA_TOUR_25) mode = ROUTE_TOUR;
        else if (action == GA_L40_DIRECT) mode = ROUTE_L40_DIRECT;
        else if (action == GA_L0_TO_57) mode = ROUTE_L0_TO_57;
        else return true;
        SummonTaxiAndStart(player, creature, mode);
        return true;
    }
};

// Level 25+ flightmaster (NPC 800012)
class acflightmaster25 : public CreatureScript
{
public:
    acflightmaster25() : CreatureScript("acflightmaster25") {}

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());
        AddGossipItemFor(player, 0, "Level 25+ to Camp", GOSSIP_SENDER_MAIN, GA_RETURN_STARTCAMP);
        AddGossipItemFor(player, 0, "Level 25+ to Level 40+", GOSSIP_SENDER_MAIN, GA_L25_TO_40);
        AddGossipItemFor(player, 0, "Level 25+ to Level 60+", GOSSIP_SENDER_MAIN, GA_L25_TO_60);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);
        FlightRouteMode mode = ROUTE_RETURN;
        if (action == GA_RETURN_STARTCAMP) mode = ROUTE_RETURN;
        else if (action == GA_L25_TO_40) mode = ROUTE_L25_TO_40;
        else if (action == GA_L25_TO_60) mode = ROUTE_L25_TO_60;
        else return true;
        SummonTaxiAndStart(player, creature, mode);
        return true;
    }
};

// Level 40+ flightmaster (NPC 800013)
class acflightmaster40 : public CreatureScript
{
public:
    acflightmaster40() : CreatureScript("acflightmaster40") {}

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());
        AddGossipItemFor(player, 0, "Level 40+ to Camp", GOSSIP_SENDER_MAIN, GA_L40_BACK_TO_0);
        AddGossipItemFor(player, 0, "Level 40+ to Level 25+", GOSSIP_SENDER_MAIN, GA_L40_BACK_TO_25);
        AddGossipItemFor(player, 0, "Level 40+ to Level 60+", GOSSIP_SENDER_MAIN, GA_L40_SCENIC_40_TO_57);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);
        FlightRouteMode mode = ROUTE_L40_RETURN0;
        if (action == GA_L40_BACK_TO_0) mode = ROUTE_L40_RETURN0;
        else if (action == GA_L40_BACK_TO_25) mode = ROUTE_L40_RETURN25;
        else if (action == GA_L40_SCENIC_40_TO_57) mode = ROUTE_L40_SCENIC;
        else return true;
        SummonTaxiAndStart(player, creature, mode);
        return true;
    }
};

// Level 60+ flightmaster (NPC 800014)
class acflightmaster60 : public CreatureScript
{ 
public:
    acflightmaster60() : CreatureScript("acflightmaster60") {}

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());
        AddGossipItemFor(player, 0, "Level 60+ to Camp", GOSSIP_SENDER_MAIN, GA_L60_BACK_TO_0);
        AddGossipItemFor(player, 0, "Level 60+ to Level 25+", GOSSIP_SENDER_MAIN, GA_L60_BACK_TO_25);
        AddGossipItemFor(player, 0, "Level 60+ to Level 40+", GOSSIP_SENDER_MAIN, GA_L60_BACK_TO_40);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);
        FlightRouteMode mode = ROUTE_L60_RETURN0;
        if (action == GA_L60_BACK_TO_0) mode = ROUTE_L60_RETURN0;
        else if (action == GA_L60_BACK_TO_25) mode = ROUTE_L60_RETURN19;
        else if (action == GA_L60_BACK_TO_40) mode = ROUTE_L60_RETURN40;
        else return true;
        SummonTaxiAndStart(player, creature, mode);
        return true;
    }
};

void RegisterScripts()
{
    new acflightmaster0();
    new acflightmaster25();
    new acflightmaster40();
    new acflightmaster60();
    new ac_gryphon_taxi_800011();
}

// PlayerScript for simple GM debug commands (.acfm failstats / .acfm failreset)
class AC_Flightmaster_DebugCommands : public PlayerScript
{
public:
    AC_Flightmaster_DebugCommands() : PlayerScript("AC_Flightmaster_DebugCommands", { PLAYERHOOK_ON_CHAT }) {}

    void OnPlayerChat(Player* player, uint32 /*type*/, uint32 /*lang*/, std::string& msg) override
    {
        if (!player || !player->IsGameMaster())
            return;

        if (msg.rfind(".acfm", 0) != 0)
            return;

        std::istringstream iss(msg);
        std::string cmd, sub;
        iss >> cmd >> sub;
        if (sub == "failstats")
        {
            // Iterate all creatures with the taxi entry and print per-instance fail counters
            uint32 found = 0;
            std::ostringstream oss;
            oss << "[Flight Debug] Active taxi failstats:\n";
            {
                std::list<Creature*> taxiList;
                player->GetCreatureListWithEntryInGrid(taxiList, NPC_AC_GRYPHON_TAXI, 200.0f);
                for (Creature* c : taxiList)
                {
                    if (!c)
                        continue;
                    if (!c->IsInWorld())
                        continue;
                    if (c->AI())
                    {
                        // Try to cast to our AI type
                        ac_gryphon_taxi_800011AI* ai = dynamic_cast<ac_gryphon_taxi_800011AI*>(c->AI());
                        if (!ai) // maybe another taxi; skip
                            continue;
                        ++found;
                        oss << "Instance GUID=" << c->GetGUID().GetRawValue() << " idx=" << static_cast<uint32>(ai->_index) << " failcounts=[";
                        // print counts compactly
                        for (size_t i = 0; i < ai->_nodeFailCount.size(); ++i)
                        {
                            if (i) oss << ',';
                            oss << static_cast<uint32>(ai->_nodeFailCount[i]);
                        }
                        oss << "]\n";
                    }
                }
            }
            if (found == 0)
                ChatHandler(player->GetSession()).PSendSysMessage("[Flight Debug] No active taxi instances found near you. Move near an active taxi or run the command from console.");
            else
                ChatHandler(player->GetSession()).PSendSysMessage(oss.str().c_str());
            return;
        }
        else if (sub == "set")
        {
            // Syntax: .acfm set <idx> <escThresh> <extraZ>
            uint32 idx = 0;
            uint32 esc = 0;
            float extraZ = 0.0f;
            iss >> idx >> esc >> extraZ;
            if (idx >= static_cast<uint32>(kPathLength))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("[Flight Debug] Invalid index {} (path length {}).", idx, static_cast<uint32>(kPathLength));
                return;
            }
            // Update global defaults vector (affects subsequent flights / instances reading defaults)
            // We intentionally allow small race here; it's a tuning helper, not a strict API.
            const_cast<NodeConfig&>(ac_gryphon_taxi_800011AI::kPerNodeConfigDefaults[idx]) = { static_cast<uint8>(esc), extraZ };
            ChatHandler(player->GetSession()).PSendSysMessage("[Flight Debug] Set node {}: escalation={} extraZ={:.1f} (applies to new flights/instances).", idx, esc, extraZ);
            // Also update any active taxi instances near the player (apply instantly)
            uint32 updated = 0;
            {
                std::list<Creature*> taxiList;
                player->GetCreatureListWithEntryInGrid(taxiList, NPC_AC_GRYPHON_TAXI, 200.0f);
                for (Creature* c : taxiList)
                {
                    if (!c || c->GetEntry() != NPC_AC_GRYPHON_TAXI)
                        continue;
                    if (ac_gryphon_taxi_800011AI* ai = dynamic_cast<ac_gryphon_taxi_800011AI*>(c->AI()))
                    {
                        if (idx < ai->_perNodeConfig.size())
                        {
                            ai->_perNodeConfig[idx] = { static_cast<uint8>(esc), extraZ };
                            ++updated;
                        }
                    }
                }
            }
            if (updated > 0)
                ChatHandler(player->GetSession()).PSendSysMessage("[Flight Debug] Applied config to {} active taxi instances near you.", updated);
            return;
        }
        else if (sub == "failreset")
        {
            // Reset is a no-op local instruction; rather than attempt to find all instances, instruct to restart taxi or re-board to reset state.
            ChatHandler(player->GetSession()).PSendSysMessage("[Flight Debug] Resetting per-node counters is currently done on flight start. To reset, re-board or restart the taxi.");
            return;
        }
    }
};  // Added semicolon after class definition

} // namespace DC_AC_Flight

// Define per-node config defaults (runtime-initialized)
const std::vector<DC_AC_Flight::NodeConfig> DC_AC_Flight::ac_gryphon_taxi_800011AI::kPerNodeConfigDefaults = [](){
    std::vector<DC_AC_Flight::NodeConfig> v(static_cast<size_t>(kPathLength), { kFailEscalationThreshold, 0.0f });
    if (kIndex_acfm57 < kPathLength)
        v[kIndex_acfm57] = { 2u, 12.0f };
    // Make acfm15 a bit more aggressive to avoid landing fallbacks on the L25->L40 route
    if (kIndex_acfm15 < kPathLength)
        v[kIndex_acfm15] = { 2u, 6.0f };
    return v;
}();

void AddSC_flightmasters()
{
    DC_AC_Flight::RegisterScripts();
    // Also register the GM debug player script (class is defined in the DC_AC_Flight namespace)
    new DC_AC_Flight::AC_Flightmaster_DebugCommands();
}

// Define per-node config defaults (runtime-initialized)
const std::vector<DC_AC_Flight::NodeConfig> DC_AC_Flight::ac_gryphon_taxi_800011AI::kPerNodeConfigDefaults = [](){
    std::vector<DC_AC_Flight::NodeConfig> v(static_cast<size_t>(kPathLength), { kFailEscalationThreshold, 0.0f });
    if (kIndex_acfm57 < kPathLength)
        v[kIndex_acfm57] = { 2u, 12.0f };
    // Make acfm15 a bit more aggressive to avoid landing fallbacks on the L25->L40 route
    if (kIndex_acfm15 < kPathLength)
        v[kIndex_acfm15] = { 2u, 6.0f };
    return v;
}();

// debug commands are instantiated in AddSC_flightmasters()


/*
DB Notes (example workflow):

-- 1) Find a gryphon vehicle template to clone
SELECT entry, name, VehicleId FROM creature_template WHERE VehicleId > 0 AND name LIKE '%Gryphon%';

-- 2) Clone it to entry 800011 and set ScriptName
-- Replace <source_entry> with one of the results from step 1
INSERT INTO creature_template (entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, KillCredit1, KillCredit2, modelid1, modelid2, modelid3, modelid4,
 name, subname, IconName, gossip_menu_id, minlevel, maxlevel, exp, faction, npcflag, speed_walk, speed_run, scale, rank, dmgschool, BaseAttackTime, RangeAttackTime,
 BaseVariance, RangeVariance, unit_class, unit_flags, unit_flags2, dynamicflags, family, trainer_type, trainer_spell, trainer_class, trainer_race, type, type_flags,
 lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, HealthModifier, ManaModifier, ArmorModifier,
 RacialLeader, questItem1, questItem2, questItem3, questItem4, questItem5, questItem6, movementId, RegenHealth, mechanic_immune_mask, flags_extra, ScriptName)
SELECT 800011, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, KillCredit1, KillCredit2, modelid1, modelid2, modelid3, modelid4,
       'AC Gryphon Taxi', '', IconName, 0, 80, 80, exp, 35, 0, speed_walk, speed_run, 1.0, rank, dmgschool, BaseAttackTime, RangeAttackTime,
       BaseVariance, RangeVariance, unit_class, (unit_flags | 0x00000002 | 0x00000200), unit_flags2, dynamicflags, family, trainer_type, trainer_spell, trainer_class, trainer_race, type, type_flags,
       lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, 0, 0, AIName, 0, HoverHeight, HealthModifier, ManaModifier, ArmorModifier,
       0, 0, 0, 0, 0, 0, 0, movementId, 1, mechanic_immune_mask, flags_extra, 'ac_gryphon_taxi_800011'
FROM creature_template WHERE entry = <source_entry>;

-- Ensure movement allows flying
REPLACE INTO creature_template_movement (CreatureId, Ground, Swim, Flight, Rooted, Chase, Random)
VALUES (800011, 0, 0, 1, 0, 0, 0);

-- Bind the flightmaster NPC to this script (entry 800010 must exist in your DB)
-- Bind each flightmaster NPC to its dedicated script
UPDATE creature_template SET ScriptName = 'acflightmaster0'  WHERE entry = 800010; -- Camp
UPDATE creature_template SET ScriptName = 'acflightmaster25' WHERE entry = 800012; -- Level 25+
UPDATE creature_template SET ScriptName = 'acflightmaster40' WHERE entry = 800013; -- Level 40+
UPDATE creature_template SET ScriptName = 'acflightmaster60' WHERE entry = 800014; -- Level 60+

*/
