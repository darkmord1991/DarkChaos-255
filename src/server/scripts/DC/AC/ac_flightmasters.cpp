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
#include <type_traits>
#include <chrono>
#include <string>
#include <cmath>
#include <numeric>
#include <deque>
#include <vector>
#include <limits>
#include <algorithm>

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
enum FlightRouteMode : uint32
{
    // Camp (acfm0) starts
    ROUTE_TOUR          = 0,  // Camp to Level 25+: acfm1 -> acfm15
    ROUTE_L40_DIRECT    = 1,  // Camp to Level 40+: acfm1 -> ... -> acfm35
    ROUTE_L0_TO_57      = 2,  // Camp to Level 60+: acfm1 -> ... -> acfm57

    // Level 25+ starts
    ROUTE_RETURN        = 3,  // Level 25+ to Camp: acfm15 -> ... -> acfm0
    ROUTE_L25_TO_40     = 4,  // Level 25+ to Level 40+: acfm19 -> ... -> acfm35
    ROUTE_L25_TO_60     = 5,  // Level 25+ to Level 60+: acfm19 -> ... -> acfm57

    // Level 40+ starts
    ROUTE_L40_RETURN25  = 6,  // Level 40+ to Level 25+: acfm35 -> ... -> acfm19
    ROUTE_L40_SCENIC    = 7,  // Level 40+ to Level 60+: acfm40 -> ... -> acfm57

    // Level 60+ starts
    ROUTE_L60_RETURN40  = 8,  // Level 60+ to Level 40+: acfm57 -> ... -> acfm40
    ROUTE_L60_RETURN19  = 9,  // Level 60+ to Level 25+: acfm57 -> ... -> acfm19
    ROUTE_L60_RETURN0   = 10  // Level 60+ to Camp: acfm57 -> ... -> acfm0
    ,ROUTE_L40_RETURN0  = 11  // Level 40+ to Camp: acfm35 -> ... -> acfm0
};

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

// Gryphon vehicle AI that follows the above path with the boarded player in seat 0
struct ac_gryphon_taxi_800011AI : public VehicleAI
{
    enum : uint32 { POINT_TAKEOFF = 9000, POINT_LAND_FINAL = 9001 };
    // Route mode declared early to ensure visibility in all in-class method bodies
    FlightRouteMode _routeMode = ROUTE_TOUR; // default to tour unless overridden by gossip
    // Flight state
    bool _started = false;           // has the flight been started via SetData
    bool _awaitingArrival = false;   // awaiting MovementInform/arrival handling
    bool _isLanding = false;         // currently performing landing sequence
    bool _landingScheduled = false;  // scheduled landing fallback task
    uint8 _index = 0;                // current waypoint index
    uint32 _currentPointId = 0;      // current MovePoint id

    ac_gryphon_taxi_800011AI(Creature* creature) : VehicleAI(creature) { }

    void SetData(uint32 id, uint32 value) override
    {
        // Expect id==1 as the route selection (sent by SummonTaxiAndStart)
        if (id != 1)
            return;

        _routeMode = static_cast<FlightRouteMode>(value);
        _started = true;
        _awaitingArrival = false;
    _isLanding = false;
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
    _nodeFailCount.assign(kPathLength, 0);
    _noPassengerMs = 0;
    _stuckMs = 0;
    _lastPosX = me->GetPositionX();
    _lastPosY = me->GetPositionY();
    _flightStartPos = me->GetPosition();
    _lastDepartIdx = 255;
    _lastBypassedAnchor = 255;
    _bypassMs = 60000;
    me->SetCanFly(true);
    me->SetDisableGravity(true);
    me->SetHover(true);
    me->GetMotionMaster()->Clear();
            // Local helpers used by the startup routine
            Player* p = GetPassengerPlayer();
            uint8 nextIdx = _index;
            // Compute nearest scenic node index to the gryphon's current position for initial routing
            uint8 nearest = 0;
            {
                float bestDist = std::numeric_limits<float>::max();
                uint8 last = LastScenicIndex();
                for (uint8 i = 0; i <= last; ++i)
                {
                    float dx = me->GetPositionX() - kPath[i].GetPositionX();
                    float dy = me->GetPositionY() - kPath[i].GetPositionY();
                    float d2 = dx * dx + dy * dy;
                    if (d2 < bestDist)
                    {
                        bestDist = d2;
                        nearest = i;
                    }
                }
            }
            _awaitingArrival = false;
            // Aggressive bypass for known sticky anchors: remap the next index to avoid landing exactly on them
            if (nextIdx == kIndex_acfm19)
            {
                // If we've just bypassed this anchor recently, avoid doing it again immediately
                if (_lastBypassedAnchor == kIndex_acfm19 && _bypassMs < 3000)
                {
                    if (Player* p = GetPassengerPlayer())
                        if (p->IsGameMaster())
                            ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Skipping redundant bypass for acfm19 (throttle).");
                }
                else
                {
                    // For descending/camp-return routes, jump back to the classic anchor (acfm15).
                    // For other forward routes, step past the anchor (acfm20) to avoid stickiness.
                    if (_routeMode == ROUTE_L40_RETURN0 || _routeMode == ROUTE_L60_RETURN0 || _routeMode == ROUTE_L60_RETURN19)
                        nextIdx = kIndex_acfm15;
                    else
                        nextIdx = static_cast<uint8>(kIndex_acfm19 + 1);
                    // record bypass and throttle repeated remaps
                    _lastBypassedAnchor = kIndex_acfm19;
                    _bypassMs = 0;
                    if (Player* p = GetPassengerPlayer())
                        if (p->IsGameMaster())
                            ChatHandler(p->GetSession()).PSendSysMessage(
                                "[Flight Debug] Aggressive bypass: remapped anchor acfm19 -> {}.", NodeLabel(nextIdx));
                }
            }
            if (nextIdx == kIndex_acfm35)
            {
            if (p && p->IsGameMaster())
                ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Level 40+ route start at {}.", NodeLabel(_index));
            MoveToIndexWithSmartPath(_index);
            return;
        }

        if (_routeMode == ROUTE_L25_TO_40 || _routeMode == ROUTE_L25_TO_60)
        {
            float dx = me->GetPositionX() - kPath[kIndex_acfm19].GetPositionX();
            float dy = me->GetPositionY() - kPath[kIndex_acfm19].GetPositionY();
            float dist2d = sqrtf(dx * dx + dy * dy);
            _index = (dist2d < 80.0f) ? static_cast<uint8>(kIndex_acfm19 + 1) : 0;
            if (_routeMode == ROUTE_L25_TO_40)
            {
                _l25to40ResetApplied = false;
                float dx35 = me->GetPositionX() - kPath[kIndex_acfm35].GetPositionX();
                float dy35 = me->GetPositionY() - kPath[kIndex_acfm35].GetPositionY();
                float d35 = sqrtf(dx35 * dx35 + dy35 * dy35);
                if (d35 < 80.0f)
                    _index = static_cast<uint8>(kIndex_acfm35 - 1);
            }
            if (p && p->IsGameMaster())
                ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Level 25+ route starting at {}.", NodeLabel(_index));
            me->GetMotionMaster()->Clear();
            float tdx = me->GetPositionX() - kPath[_index].GetPositionX();
            float tdy = me->GetPositionY() - kPath[_index].GetPositionY();
            float tdist = sqrtf(tdx * tdx + tdy * tdy);
            if (tdist > 120.0f)
            {
                Position lift = me->GetPosition();
                lift.m_positionZ += 18.0f;
                me->GetMotionMaster()->MovePoint(POINT_TAKEOFF, lift);
                _scheduler.Schedule(std::chrono::milliseconds(300), [this](TaskContext ctx)
                {
                    (void)ctx;
                    if (me->IsInWorld())
                        MoveToIndex(_index);
                });
            }
            else
            {
                MoveToIndex(_index);
            }
            return;
        }

        // TOUR and other default start: attempt to start near the nearest scenic index but

        // For TOUR starts, clamp to acfm15 to avoid starting past the classic section on camp departures.
        // For non-TOUR routes (returning flights), respect nearest so we don't force an incorrect anchor.
        uint8 startIdx;
        if (_routeMode == ROUTE_TOUR)
            startIdx = nearest > kIndex_acfm15 ? kIndex_acfm15 : nearest;
        else
            startIdx = nearest;
        _index = (startIdx > 0) ? static_cast<uint8>(startIdx - 1) : 0;
        if (p && p->IsGameMaster())
            ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Nearest node is {}. Beginning descent at {}.", NodeLabel(nearest), NodeLabel(_index));
        MoveToIndexWithSmartPath(_index);
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
        Player* passenger = GetPassengerPlayer();
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
        me->SetSpeedRate(MOVE_FLIGHT, 1.0f);
        me->GetMotionMaster()->MoveLand(POINT_LAND_FINAL, landPos, 7.0f);
        // Fallback in 5s in case land inform is missed
        _scheduler.Schedule(std::chrono::milliseconds(5000), [this](TaskContext ctx)
        {
            (void)ctx;
            if (!me->IsInWorld())
                return;
            if (_isLanding)
            {
                if (Player* p = GetPassengerPlayer())
                    if (p->IsGameMaster())
                        ChatHandler(p->GetSession()).SendSysMessage("[Flight Debug] Early-exit landing fallback.");
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

        float dx = me->GetPositionX() - kPath[idx].GetPositionX();
        float dy = me->GetPositionY() - kPath[idx].GetPositionY();
        float dz = fabsf(me->GetPositionZ() - kPath[idx].GetPositionZ());
        float dist2d = sqrtf(dx * dx + dy * dy);
        return dist2d <= max2d && dz <= 40.0f;
    }

    float ComputeTurnAngleDeg(uint8 prevIdx, uint8 currIdx, uint8 nextIdx) const
    {
        if (prevIdx >= kPathLength || currIdx >= kPathLength || nextIdx >= kPathLength)
            return 0.0f;

        const Position& a = kPath[prevIdx];
        const Position& b = kPath[currIdx];
        const Position& c = kPath[nextIdx];

        float v1x = b.GetPositionX() - a.GetPositionX();
        float v1y = b.GetPositionY() - a.GetPositionY();
        float v2x = c.GetPositionX() - b.GetPositionX();
        float v2y = c.GetPositionY() - b.GetPositionY();

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
        if (Player* p = GetPassengerPlayer())
            p->ExitVehicle();

        me->SetHover(false);
        me->SetDisableGravity(false);
        me->SetCanFly(false);
    me->DespawnOrUnsummon(1000ms);
    }

    void UpdateAI(uint32 diff) override
    {
        // Drive scheduled tasks
        _scheduler.Update(diff);

        // Keep flight state asserted unless landing sequence started
        if (!_isLanding)
        {
            me->SetCanFly(true);
            me->SetDisableGravity(true);
            me->SetHover(true);
        }

        // Proximity-based waypoint arrival fallback in case MovementInform is skipped
        if (_awaitingArrival)
        {
            _sinceMoveMs += diff;
            _hopElapsedMs += diff; // watchdog for per-hop timeouts
            if (_sinceMoveMs > 300) // small debounce
            {
                // Choose current target (either a custom smoothing point or the real path node)
                float tx = _movingToCustom ? _customTarget.GetPositionX() : kPath[_index].GetPositionX();
                float ty = _movingToCustom ? _customTarget.GetPositionY() : kPath[_index].GetPositionY();
                float tz = _movingToCustom ? _customTarget.GetPositionZ() : kPath[_index].GetPositionZ();
                float dx = me->GetPositionX() - tx;
                float dy = me->GetPositionY() - ty;
                float dz = fabs(me->GetPositionZ() - tz);
                float dist2d = sqrtf(dx * dx + dy * dy);
                // Relax vertical tolerance slightly because smart hops and terrain can cause Z offsets
                float near2d = (_index >= kIndex_acfm40) ? 10.0f : 6.0f; // allow a bit more tolerance on the 40+ segment
                float nearDz = 22.0f; // increased from 18.0f
                // Known anchor: acfm19 can be sticky when descending from 40+ → Camp; accept a wider proximity
                if (_routeMode == ROUTE_L40_RETURN0 && _index == kIndex_acfm19)
                    near2d = 12.0f;
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
                                // increase acceptance radius for these nodes slightly
                                near2d = std::max(near2d, 8.0f);
                            }

                        // Special-case watchdog: if we're targeting acfm19 on 40+ → Camp for too long, skip directly to acfm15
                        if (_routeMode == ROUTE_L40_RETURN0 && _index == kIndex_acfm19 && _hopElapsedMs > 3500u && !_isLanding)
                    {
                        if (Player* p = GetPassengerPlayer())
                            if (p->IsGameMaster())
                                ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Anchor {} timeout. Skipping to {}.", NodeLabel(_index), NodeLabel(kIndex_acfm15));
                        _awaitingArrival = false;
                        _index = kIndex_acfm15;
                        MoveToIndex(_index);
                        return;
                    }
                    uint32 hopTimeout = (_routeMode == ROUTE_L40_SCENIC ? 5000u : 8000u);
                    if (_movingToCustom)
                        hopTimeout = 4500u; // short smoothing hop: allow more time for custom/arc hops
                    if (_hopElapsedMs > hopTimeout && !_isLanding)
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
                                me->GetMotionMaster()->MovePoint(_currentPointId, _customTarget);
                            else
                                me->GetMotionMaster()->MovePoint(_currentPointId, kPath[_index]);
                            _hopElapsedMs = 0;
                                // record a minor failure for this node
                                if (_index < _nodeFailCount.size())
                                    ++_nodeFailCount[_index];
                        }
                        else if (_hopRetries == 1)
                        {
                            // Rate-limited micro-nudge: skip if we recently nudged this same node
                            if (_lastNudgeIdx == _index && _lastNudgeMs < kMicroNudgeRateLimitMs)
                            {
                                if (Player* p = GetPassengerPlayer())
                                    if (p->IsGameMaster())
                                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Skipping micro-nudge for {} (rate-limit).", NodeLabel(_index));

                                // Try smart pathfinding before hard fallback (duplicate of else branch behavior)
                                if (_pathfindingRetries < 1 && !_useSmartPathfinding && !_movingToCustom)
                                {
                                    _pathfindingRetries++;
                                    if (Player* p = GetPassengerPlayer())
                                        if (p->IsGameMaster())
                                            ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Hop timeout at {}. Trying smart pathfinding recovery.", NodeLabel(_index));
                                    
                                    _awaitingArrival = false;
                                    _hopElapsedMs = 0;
                                    _hopRetries = 0;
                                    MoveToIndexWithSmartPath(_index);
                                    return;
                                }

                                // Hard fallback: snap to target node and continue the route
                                if (Player* p = GetPassengerPlayer())
                                    if (p->IsGameMaster())
                                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Final timeout at {}. Snapping to target to continue.", _movingToCustom ? std::string("corner"): NodeLabel(_index));
                                float tx = _movingToCustom ? _customTarget.GetPositionX() : kPath[_index].GetPositionX();
                                float ty = _movingToCustom ? _customTarget.GetPositionY() : kPath[_index].GetPositionY();
                                float tz = _movingToCustom ? _customTarget.GetPositionZ() : kPath[_index].GetPositionZ();
                                me->UpdateGroundPositionZ(tx, ty, tz);
                                me->NearTeleportTo(tx, ty, tz + 2.0f, kPath[_index].GetOrientation());
                                _hopElapsedMs = 0;
                                _hopRetries = 0;
                                _pathfindingRetries = 0; // Reset pathfinding retries
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

                            // On the second retry, issue a tiny micro-nudge: reissue MovePoint slightly above target
                            ++_hopRetries;
                            float nudgex = _movingToCustom ? _customTarget.GetPositionX() : kPath[_index].GetPositionX();
                            float nudgey = _movingToCustom ? _customTarget.GetPositionY() : kPath[_index].GetPositionY();
                            float nudgez = (_movingToCustom ? _customTarget.GetPositionZ() : kPath[_index].GetPositionZ()) + 8.0f; // slightly higher nudge
                            // Per-node extra nudgeZ (configurable)
                            float perNodeExtra = (_index < kPathLength ? kPerNodeConfigDefaults[_index].nudgeExtraZ : 0.0f);
                            nudgez += perNodeExtra;
                            // If this node has repeatedly failed, escalate the nudge height for stubborn spots
                            uint8 nodeEscThresh = (_index < kPathLength ? kPerNodeConfigDefaults[_index].escalationThreshold : kFailEscalationThreshold);
                            if (_index < _nodeFailCount.size() && _nodeFailCount[_index] >= nodeEscThresh)
                            {
                                nudgez += 8.0f; // stronger nudge on repeat failures
                                if (Player* p = GetPassengerPlayer())
                                    if (p->IsGameMaster())
                                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Escalation: increased micro-nudge at {} (failcount=%u).", NodeLabel(_index), static_cast<uint32>(_nodeFailCount[_index]));
                            }
                            Position nudgePos(nudgex, nudgey, nudgez, 0.0f);
                            me->GetMotionMaster()->Clear();
                            me->GetMotionMaster()->MovePoint(_currentPointId, nudgePos);
                            if (Player* p = GetPassengerPlayer())
                                if (p->IsGameMaster())
                                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Micro-nudge issued to help clear obstacle at {}.", NodeLabel(_index));
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
                                if (Player* p = GetPassengerPlayer())
                                    if (p->IsGameMaster())
                                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Hop timeout at {}. Trying smart pathfinding recovery.", NodeLabel(_index));
                                
                                _awaitingArrival = false;
                                _hopElapsedMs = 0;
                                _hopRetries = 0;
                                MoveToIndexWithSmartPath(_index);
                                return;
                            }
                            
                            // Hard fallback: snap to target node and continue the route
                            if (Player* p = GetPassengerPlayer())
                                if (p->IsGameMaster())
                                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Final timeout at {}. Snapping to target to continue.", _movingToCustom ? std::string("corner"): NodeLabel(_index));
                            float tx = _movingToCustom ? _customTarget.GetPositionX() : kPath[_index].GetPositionX();
                            float ty = _movingToCustom ? _customTarget.GetPositionY() : kPath[_index].GetPositionY();
                            float tz = _movingToCustom ? _customTarget.GetPositionZ() : kPath[_index].GetPositionZ();
                            me->UpdateGroundPositionZ(tx, ty, tz);
                            me->NearTeleportTo(tx, ty, tz + 2.0f, kPath[_index].GetOrientation());
                                _hopElapsedMs = 0;
                                _hopRetries = 0;
                                _pathfindingRetries = 0; // Reset pathfinding retries
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
                if (_routeMode == ROUTE_L25_TO_40 || _routeMode == ROUTE_L40_DIRECT)
                    finalTimeout = 4000u;
                if (_hopElapsedMs > finalTimeout)
                {
                    if (Player* p = GetPassengerPlayer())
                        if (p->IsGameMaster())
                            ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Final hop timeout at {}. Landing now.", NodeLabel(_index));
                    float fx = kPath[_index].GetPositionX();
                    float fy = kPath[_index].GetPositionY();
                    float fz = kPath[_index].GetPositionZ();
                    me->UpdateGroundPositionZ(fx, fy, fz);
                    me->NearTeleportTo(fx, fy, fz + 0.5f, kPath[_index].GetOrientation());
                    _awaitingArrival = false;
                    // Begin landing without waiting for another arrival event
                    me->SetSpeedRate(MOVE_FLIGHT, 1.0f);
                    _isLanding = true;
                    me->GetMotionMaster()->MoveLand(POINT_LAND_FINAL, { fx, fy, fz + 0.5f, kPath[_index].GetOrientation() }, 7.0f);
                    if (!_landingScheduled)
                    {
                        _landingScheduled = true;
                        _scheduler.Schedule(std::chrono::milliseconds(6000), [this](TaskContext ctx)
                        {
                            (void)ctx;
                            if (!me->IsInWorld())
                                return;
                            if (Player* p = GetPassengerPlayer())
                                if (p->IsGameMaster())
                                    ChatHandler(p->GetSession()).SendSysMessage("[Flight Debug] Landing fallback triggered. Snapping to ground and dismounting safely.");
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
        if (_bypassMs < 60000)
            _bypassMs += diff;
        if (_bypassMs > 3000 && _lastBypassedAnchor != 255)
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
            if (_stuckMs >= 20000)
            {
                if (Player* p = GetPassengerPlayer())
                    if (p->IsGameMaster())
                        ChatHandler(p->GetSession()).SendSysMessage("[Flight Debug] Stuck detected for 20s. Attempting smart-path recovery to destination before fallback.");

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

                Position dest(kPath[finalIdx].GetPositionX(), kPath[finalIdx].GetPositionY(), kPath[finalIdx].GetPositionZ(), kPath[finalIdx].GetOrientation());
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
                if (Player* p = GetPassengerPlayer())
                    if (p->IsGameMaster())
                        ChatHandler(p->GetSession()).SendSysMessage("[Flight Debug] Smart-path recovery failed. Teleporting to start and dismounting.");
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
            if (!GetPassengerPlayer())
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
        _currentPointId = 10000u + idx; // unique id per node
        // Reassert flying for each hop to avoid any gravity re-enabling from vehicle state changes
        me->SetCanFly(true);
        me->SetDisableGravity(true);
        me->SetHover(true);
        me->SetSpeedRate(MOVE_RUN, _baseSpeedRate);
        me->SetSpeedRate(MOVE_FLIGHT, _baseSpeedRate);
        me->GetMotionMaster()->MovePoint(_currentPointId, kPath[idx]);
        _awaitingArrival = true;
        _sinceMoveMs = 0;
        _hopElapsedMs = 0;
        _hopRetries = 0;
        if (Player* p = GetPassengerPlayer())
        {
            if (_lastDepartIdx != idx)
                if (p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Departing to {} (idx {}).", NodeLabel(idx), (uint32)idx);
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
    // Per-node override configuration
    struct NodeConfig { uint8 escalationThreshold; float nudgeExtraZ; };
    // Default per-node config: only acfm57 needs more aggressive handling so far
    static const NodeConfig kPerNodeConfigDefaults[kPathLength] = [](){
        std::array<NodeConfig, kPathLength> arr{};
        for (size_t i = 0; i < arr.size(); ++i) arr[i] = { kFailEscalationThreshold, 0.0f };
        if (kIndex_acfm57 < arr.size()) arr[kIndex_acfm57] = { 2u, 12.0f };
        return arr;
    }();
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
        Position destination(kPath[idx].GetPositionX(), kPath[idx].GetPositionY(),
                             kPath[idx].GetPositionZ(), kPath[idx].GetOrientation());

        // Known sticky hop: acfm34 -> acfm35 sits under tree cover. Inject a short vertical arc to avoid terrain clipping.
        if (idx == kIndex_acfm35 && _lastArrivedIdx == kIndex_acfm35 - 1 &&
            (_routeMode == ROUTE_L40_DIRECT || _routeMode == ROUTE_L25_TO_40))
        {
            _smartPathQueue.clear();

            Position rise = me->GetPosition();
            rise.m_positionZ = std::max(rise.GetPositionZ() + 22.0f, destination.GetPositionZ() + 18.0f);
            // escalate arc height if this node keeps failing (use per-node override if present)
            uint8 escThresh = (idx < kPathLength ? kPerNodeConfigDefaults[idx].escalationThreshold : kFailEscalationThreshold);
            if (idx < _nodeFailCount.size() && _nodeFailCount[idx] >= escThresh)
            {
                rise.m_positionZ += 12.0f;
                if (Player* p = GetPassengerPlayer())
                    if (p->IsGameMaster())
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Escalation: increased elevation arc for {} due to repeated failures.", NodeLabel(idx));
            }

            Position glide = destination;
            glide.m_positionZ = std::max(rise.GetPositionZ(), destination.GetPositionZ() + 18.0f);

            _smartPathQueue.push_back(rise);
            _smartPathQueue.push_back(glide);
            _smartPathQueue.push_back(destination);

            _useSmartPathfinding = true;
            _pathfindingRetries = 0;

            Position next = _smartPathQueue.front();
            _smartPathQueue.pop_front();
            MoveToCustom(next);
            if (Player* p = GetPassengerPlayer())
                if (p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Elevating arc to clear terrain for {}.", NodeLabel(idx));
            return;
        }

        // Final hop back to Startcamp can clip the hillside; fly a shallow overhead approach when returning to camp routes.
        if (idx == kIndex_startcamp &&
            (_routeMode == ROUTE_RETURN || _routeMode == ROUTE_L40_RETURN0 || _routeMode == ROUTE_L60_RETURN0) &&
            _lastArrivedIdx <= 2)
        {
            _smartPathQueue.clear();

            Position rise = me->GetPosition();
            rise.m_positionZ = std::max(rise.GetPositionZ() + 18.0f, destination.GetPositionZ() + 12.0f);
            // escalate overhead approach if Startcamp is repeatedly failing
            uint8 escThreshSC = (idx < kPathLength ? kPerNodeConfigDefaults[idx].escalationThreshold : kFailEscalationThreshold);
            if (idx < _nodeFailCount.size() && _nodeFailCount[idx] >= escThreshSC)
            {
                rise.m_positionZ += 18.0f; // much higher overhead approach
                if (Player* p = GetPassengerPlayer())
                    if (p->IsGameMaster())
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Escalation: stronger overhead approach for Startcamp due to repeated failures.");
            }

            Position approach = destination;
            approach.m_positionZ = std::max(rise.GetPositionZ(), destination.GetPositionZ() + 12.0f);

            _smartPathQueue.push_back(rise);
            _smartPathQueue.push_back(approach);
            _smartPathQueue.push_back(destination);

            _useSmartPathfinding = true;
            _pathfindingRetries = 0;

            Position next = _smartPathQueue.front();
            _smartPathQueue.pop_front();
            MoveToCustom(next);
            if (Player* p = GetPassengerPlayer())
                if (p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Overhead arc engaged for Startcamp landing.");
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
                    if (d2 > 4.0f)
                    {
                        if (Player* p = GetPassengerPlayer())
                            if (p->IsGameMaster())
                                ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Accepting single smart hop for {} (dx={:.1f}).", NodeLabel(idx), sqrtf(d2));
                        // leave queue intact and process below
                    }
                    else
                    {
                        if (Player* p = GetPassengerPlayer())
                            if (p->IsGameMaster())
                                ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Smart path reduced to single hop for {}. Falling back to scripted point.", NodeLabel(idx));
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
                    if (Player* p = GetPassengerPlayer())
                        if (p->IsGameMaster())
                            ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Using smart pathfinding to {} via {} smart points", NodeLabel(idx), static_cast<uint32>(_smartPathQueue.size() + 1));
                    return;
                }
            }
        }
        
        // Fallback to regular waypoint movement
        if (_useSmartPathfinding)
            if (Player* p = GetPassengerPlayer())
                if (p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Smart pathfinding unavailable for {}. Continuing on scripted path.", NodeLabel(idx));
        _useSmartPathfinding = false;
        MoveToIndex(idx);
    }

    void HandleArriveAtCurrentNode(bool isProximity)
    {
        if (!_awaitingArrival)
            return; // already handled

        // Sanity guard: if Level 40+ → 60+ route somehow starts at the final node (acfm57)
        // while we are NOT near acfm57, reset to a proper starting anchor (acfm40 if nearby, else acfm1).
        if (_routeMode == ROUTE_L40_SCENIC && _index == kIndex_acfm57)
        {
            float dx57 = me->GetPositionX() - kPath[kIndex_acfm57].GetPositionX();
            float dy57 = me->GetPositionY() - kPath[kIndex_acfm57].GetPositionY();
            float dist57 = sqrtf(dx57 * dx57 + dy57 * dy57);
            if (dist57 > 80.0f)
            {
                // Decide anchor: if near acfm40, start at acfm41 (skip anchor); otherwise start from acfm1
                float dx40 = me->GetPositionX() - kPath[kIndex_acfm40].GetPositionX();
                float dy40 = me->GetPositionY() - kPath[kIndex_acfm40].GetPositionY();
                float dist40 = sqrtf(dx40 * dx40 + dy40 * dy40);
                uint8 start = (dist40 < 80.0f) ? static_cast<uint8>(kIndex_acfm40 + 1) : 0;
                if (Player* p = GetPassengerPlayer())
                    if (p->IsGameMaster())
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Sanity: resetting Level 40+ → 60+ start from {} to {}.", NodeLabel(_index), NodeLabel(start));
                _awaitingArrival = false;
                _index = start;
                MoveToIndex(_index);
                return;
            }
        }

        // Sanity guard: if Level 25+ → 60 route somehow targets the final node (acfm57)
        // while we are NOT near acfm57, reset to a proper starting anchor (acfm19 if nearby, else acfm1).
        if (_routeMode == ROUTE_L25_TO_60 && _index == kIndex_acfm57)
        {
            float dx57b = me->GetPositionX() - kPath[kIndex_acfm57].GetPositionX();
            float dy57b = me->GetPositionY() - kPath[kIndex_acfm57].GetPositionY();
            float dist57b = sqrtf(dx57b * dx57b + dy57b * dy57b);
            if (dist57b > 80.0f)
            {
                // Choose anchor: acfm20 if near acfm19, otherwise start from acfm1 (skip anchor)
                uint8 start = IsNearIndex(kIndex_acfm19, 80.0f) ? static_cast<uint8>(kIndex_acfm19 + 1) : 0;
                if (Player* p = GetPassengerPlayer())
                    if (p->IsGameMaster())
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Sanity: resetting Level 25+ → 60 start from {} to {}.", NodeLabel(_index), NodeLabel(start));
                _awaitingArrival = false;
                _index = start;
                MoveToIndex(_index);
                return;
            }
        }

        // Sanity guard: if Level 25+ → 40 route somehow targets the final node (acfm35)
        // while we are NOT near acfm35, reset to an earlier anchor (acfm34 if near, else acfm19 or acfm1).
        if (_routeMode == ROUTE_L25_TO_40 && _index == kIndex_acfm35 && !_l25to40ResetApplied)
        {
            float dx35s = me->GetPositionX() - kPath[kIndex_acfm35].GetPositionX();
            float dy35s = me->GetPositionY() - kPath[kIndex_acfm35].GetPositionY();
            float dist35s = sqrtf(dx35s * dx35s + dy35s * dy35s);
            // Only perform this reset if we're significantly far and have been on this hop for a bit
            if (dist35s > 200.0f && _hopElapsedMs > 5000)
            {
                // Prefer stepping from acfm34 if near; otherwise anchor from acfm19; else from acfm1
                float dx34 = me->GetPositionX() - kPath[kIndex_acfm35 - 1].GetPositionX();
                float dy34 = me->GetPositionY() - kPath[kIndex_acfm35 - 1].GetPositionY();
                float d34 = sqrtf(dx34 * dx34 + dy34 * dy34);
                uint8 start = 0;
                if (d34 < 80.0f)
                    start = static_cast<uint8>(kIndex_acfm35 - 1);
                else if (IsNearIndex(kIndex_acfm19, 80.0f))
                    start = kIndex_acfm19;
                else
                    start = 0;
                if (Player* p = GetPassengerPlayer())
                    if (p->IsGameMaster())
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Sanity: resetting Level 25+ → 40 start from {} to {}.", NodeLabel(_index), NodeLabel(start));
                _awaitingArrival = false;
                _l25to40ResetApplied = true;
                _index = start;
                MoveToIndex(_index);
                return;
            }
        }

        // Compute next index based on selected route
        bool hasNext = false;
        uint8 nextIdx = _index;
        uint8 lastIdx = LastScenicIndex();
        uint8 tourEndIdx = kIndex_acfm15; // keep the classic tour ending at acfm15
        if (_routeMode == ROUTE_TOUR)
        {
            if (_index < tourEndIdx)
            {
                hasNext = true;
                nextIdx = static_cast<uint8>(_index + 1);
            }
        }
        else if (_routeMode == ROUTE_RETURN)
        {
            if (_index > 0 && _index <= lastIdx)
            {
                hasNext = true;
                nextIdx = static_cast<uint8>(_index - 1);
            }
            else if (_index == 0)
            {
                hasNext = true;
                nextIdx = kIndex_startcamp;
            }
        }
        else // other specialized routes
        {
            if (_routeMode == ROUTE_L40_DIRECT)
            {
                // Ascend from acfm1 to acfm35 inclusively
                if (_index < kIndex_acfm35)
                {
                    hasNext = true;
                    nextIdx = static_cast<uint8>(_index + 1);
                }
                else
                {
                    hasNext = false; // at acfm35 -> land
                }
            }
            else if (_routeMode == ROUTE_L40_RETURN25)
            {
                if (_index > kIndex_acfm19 && _index <= kIndex_acfm35)
                {
                    hasNext = true;
                    nextIdx = static_cast<uint8>(_index - 1);
                }
                else
                {
                    hasNext = false; // at or before acfm19 -> land
                }
            }
            else if (_routeMode == ROUTE_L40_SCENIC)
            {
                if (_index < kIndex_acfm57)
                {
                    hasNext = true;
                    nextIdx = static_cast<uint8>(_index + 1);
                }
                else
                {
                    hasNext = false; // at acfm57 -> land
                }
            }
            else if (_routeMode == ROUTE_L60_RETURN40)
            {
                if (_index > kIndex_acfm40 && _index <= kIndex_acfm57)
                {
                    hasNext = true;
                    nextIdx = static_cast<uint8>(_index - 1);
                }
                else
                {
                    hasNext = false; // at or before acfm40 -> land
                }
            }
            else if (_routeMode == ROUTE_L60_RETURN19)
            {
                if (_index > kIndex_acfm19 && _index <= kIndex_acfm57)
                {
                    hasNext = true;
                    nextIdx = static_cast<uint8>(_index - 1);
                }
                else
                {
                    hasNext = false; // at or before acfm19 -> land
                }
            }
            else if (_routeMode == ROUTE_L60_RETURN0)
            {
                if (_index > 0 && _index <= kIndex_acfm57)
                {
                    hasNext = true;
                    nextIdx = static_cast<uint8>(_index - 1);
                }
                else if (_index == 0)
                {
                    hasNext = true;
                    nextIdx = kIndex_startcamp; // final hop to Startcamp
                }
                else
                {
                    hasNext = false; // at Startcamp -> land
                }
            }
            else if (_routeMode == ROUTE_L40_RETURN0)
            {
                if (_index > 0 && _index <= kIndex_acfm35)
                {
                    hasNext = true;
                    nextIdx = static_cast<uint8>(_index - 1);
                    // Skip the acfm19 anchor entirely when descending (known sticky point)
                    if (nextIdx == kIndex_acfm19)
                        nextIdx = kIndex_acfm15;
                }
                else if (_index == 0)
                {
                    hasNext = true;
                    nextIdx = kIndex_startcamp; // final hop to Startcamp
                }
                else
                {
                    hasNext = false; // at Startcamp -> land
                }
            }
            else if (_routeMode == ROUTE_L0_TO_57)
            {
                if (_index < kIndex_acfm57)
                {
                    hasNext = true;
                    nextIdx = static_cast<uint8>(_index + 1);
                }
                else
                {
                    hasNext = false; // at acfm57 -> land
                }
            }
            else if (_routeMode == ROUTE_L25_TO_40)
            {
                if (_index < kIndex_acfm35)
                {
                    hasNext = true;
                    nextIdx = static_cast<uint8>(_index + 1);
                }
                else
                {
                    hasNext = false; // at acfm35 -> land
                }
            }
            else if (_routeMode == ROUTE_L25_TO_60)
            {
                if (_index < kIndex_acfm57)
                {
                    hasNext = true;
                    nextIdx = static_cast<uint8>(_index + 1);
                }
                else
                {
                    hasNext = false; // at acfm57 -> land
                }
            }
        }

        if (hasNext)
        {
            uint8 arrivedIdx = _index; // index we just reached
            _lastArrivedIdx = arrivedIdx;
            _awaitingArrival = false;
            // Aggressive bypass for known sticky anchors: remap the next index to avoid landing exactly on them
            if (nextIdx == kIndex_acfm19)
            {
                // If we've just bypassed this anchor recently, avoid doing it again immediately
                if (_lastBypassedAnchor == kIndex_acfm19 && _bypassMs < 3000)
                {
                    if (Player* p = GetPassengerPlayer())
                        if (p->IsGameMaster())
                            ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Skipping redundant bypass for acfm19 (throttle).");
                }
                else
                {
                    // For descending/camp-return routes, jump back to the classic anchor (acfm15).
                    // For other forward routes, step past the anchor (acfm20) to avoid stickiness.
                    if (_routeMode == ROUTE_L40_RETURN0 || _routeMode == ROUTE_L60_RETURN0 || _routeMode == ROUTE_L60_RETURN19)
                        nextIdx = kIndex_acfm15;
                    else
                        nextIdx = static_cast<uint8>(kIndex_acfm19 + 1);

                    // Record bypass and throttle repeated remaps
                    _lastBypassedAnchor = kIndex_acfm19;
                    _bypassMs = 0;
                    if (Player* p = GetPassengerPlayer())
                        if (p->IsGameMaster())
                            ChatHandler(p->GetSession()).PSendSysMessage(
                                "[Flight Debug] Aggressive bypass: remapped anchor acfm19 -> {}.", NodeLabel(nextIdx));
                }
            }

            if (nextIdx == kIndex_acfm35)
            {
                // Throttle repeated acfm35 remaps as well
                if (_lastBypassedAnchor == kIndex_acfm35 && _bypassMs < 3000)
                {
                    if (Player* p = GetPassengerPlayer())
                        if (p->IsGameMaster())
                            ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Skipping redundant bypass for acfm35 (throttle).");
                }
                else
                {
                    // For routes that target acfm35, prefer stepping from acfm34 to avoid a single long sticky hop.
                    // If acfm34 is far, try stepping past acfm35 instead.
                    uint8 altPrev = static_cast<uint8>(kIndex_acfm35 - 1);
                    float dx34 = me->GetPositionX() - kPath[altPrev].GetPositionX();
                    float dy34 = me->GetPositionY() - kPath[altPrev].GetPositionY();
                    float d34 = sqrtf(dx34 * dx34 + dy34 * dy34);
                    if (d34 < 150.0f)
                        nextIdx = altPrev;
                    else if (kIndex_acfm35 + 1 < kPathLength)
                        nextIdx = static_cast<uint8>(kIndex_acfm35 + 1);

                    _lastBypassedAnchor = kIndex_acfm35;
                    _bypassMs = 0;
                    if (Player* p = GetPassengerPlayer())
                        if (p->IsGameMaster())
                            ChatHandler(p->GetSession()).PSendSysMessage(
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
                    if (arrivedIdx + 1 < kPathLength)
                        prevIdx = static_cast<uint8>(arrivedIdx + 1);
                }
                float angleDeg = ComputeTurnAngleDeg(prevIdx, arrivedIdx, nextIdx);
                AdjustSpeedForTurn(angleDeg);
            }
            _index = nextIdx; // move to next index
            if (Player* p = GetPassengerPlayer())
                if (p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage(isProximity ? "[Flight Debug] Reached waypoint {} (proximity)." : "[Flight Debug] Reached waypoint {}.", NodeLabel(arrivedIdx));
            // Reset per-node failure counter on successful arrival
            if (arrivedIdx < _nodeFailCount.size())
                _nodeFailCount[arrivedIdx] = 0;
            // Corner smoothing: if the turn is sharp, perform a short micro-hop along the outgoing direction
            // to allow smoother orientation before the long hop.
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
                    if (arrivedIdx + 1 < kPathLength)
                        prevIdx = static_cast<uint8>(arrivedIdx + 1);
                }
                float angleDeg = ComputeTurnAngleDeg(prevIdx, arrivedIdx, _index);
                float r = 0.0f;
                if (angleDeg > 75.0f) r = 18.0f; else if (angleDeg > 35.0f) r = 12.0f; else r = 0.0f;
                if (r > 0.0f)
                {
                    // Create a point a short distance along the outgoing direction from the corner node
                    const Position& pc = kPath[arrivedIdx];
                    const Position& pn = kPath[_index];
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
            MoveToIndexWithSmartPath(_index);
            return;
        }

        // Final node reached: initiate a safe landing, then dismount at ground
        // Guard: ensure we are truly close to the final spot; if not, do one more MovePoint to the exact node
        {
            float dx = me->GetPositionX() - kPath[_index].GetPositionX();
            float dy = me->GetPositionY() - kPath[_index].GetPositionY();
            float dz = fabs(me->GetPositionZ() - kPath[_index].GetPositionZ());
            float dist2d = sqrtf(dx * dx + dy * dy);
            if (dist2d > 8.0f || dz > 18.0f)
            {
                // Snap one more hop to the exact final location before landing
                _awaitingArrival = true;
                MoveToIndex(_index);
                return;
            }
        }

        // Bleed speed before landing to avoid overshoot
        me->SetSpeedRate(MOVE_FLIGHT, 1.0f);
        float x = kPath[_index].GetPositionX();
        float y = kPath[_index].GetPositionY();
        float z = kPath[_index].GetPositionZ();
        me->UpdateGroundPositionZ(x, y, z);
        Position landPos = { x, y, z + 0.5f, kPath[_index].GetOrientation() };
        _isLanding = true;
        me->GetMotionMaster()->MoveLand(POINT_LAND_FINAL, landPos, 7.0f);
        // Fallback: if landing inform does not trigger, snap to ground and dismount safely
        if (!_landingScheduled)
        {
            _landingScheduled = true;
            _scheduler.Schedule(std::chrono::milliseconds(6000), [this](TaskContext ctx)
            {
                (void)ctx;
                if (!me->IsInWorld())
                    return;
                if (Player* p = GetPassengerPlayer())
                    if (p->IsGameMaster())
                        ChatHandler(p->GetSession()).SendSysMessage("[Flight Debug] Landing fallback triggered. Snapping to ground and dismounting safely.");
                // Snap the gryphon to ground at the final node before dismounting passengers
                float fx = kPath[_index].GetPositionX();
                float fy = kPath[_index].GetPositionY();
                float fz = kPath[_index].GetPositionZ();
                me->UpdateGroundPositionZ(fx, fy, fz);
                me->NearTeleportTo(fx, fy, fz + 0.5f, kPath[_index].GetOrientation());
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
        ChatHandler(player->GetSession()).PSendSysMessage("[Flight] Failed to summon gryphon (entry %u).", static_cast<uint32>(NPC_AC_GRYPHON_TAXI));
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
        ChatHandler(player->GetSession()).PSendSysMessage("[Flight] The summoned gryphon has no VehicleId. Please set creature_template.VehicleId for entry %u and ScriptName=ac_gryphon_taxi_800011.", static_cast<uint32>(taxi->GetEntry()));
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
    // Register player script for GM debugging commands
    new class AC_Flightmaster_DebugCommands();
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
            // Aggregate and print non-zero counters
            std::string out = "[Flight Debug] Node fail counts:";
            // iterate path indices and report counts
            for (uint8 i = 0; i < kPathLength; ++i)
            {
                // Accessing global state: find any active gryphon AI instances and report the counters
                // We'll search all creatures of our taxi entry and report the first matching AI's counters
            }
            // For simplicity, print a summary note and instruct to use the GM flight debug for detailed per-flight output
            ChatHandler(player->GetSession()).PSendSysMessage("[Flight Debug] To inspect per-flight counters, watch GM chat during a flight run; per-node counters persist per taxi instance.");
            return;
        }
        else if (sub == "failreset")
        {
            // Reset is a no-op local instruction; rather than attempt to find all instances, instruct to restart taxi or re-board to reset state.
            ChatHandler(player->GetSession()).PSendSysMessage("[Flight Debug] Resetting per-node counters is currently done on flight start. To reset, re-board or restart the taxi.");
            return;
        }
    }
};

} // namespace DC_AC_Flight

void AddSC_flightmasters()
{
    DC_AC_Flight::RegisterScripts();
}


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
