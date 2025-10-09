/*
 * DarkChaos Custom: Multi Flightmasters for Azshara Crater taxi
 *
 * ScriptNames:
 *   - acflightmaster0   -> Camp flightmaster (NPC 800010)
 *   - acflightmaster25  -> Level 25+ flightmaster (NPC 800012)
 *   - acflightmaster40  -> Level 40+ flightmaster (NPC 800013)
 *   - acflightmaster60  -> Level 60+ flightmaster (NPC 800014)
 *   - ac_gryphon_taxi_800011 (vehicle AI)
 *
 * Behavior:
 * - Each flightmaster offers routes appropriate for its tier:
 *   Camp:         to Level 25+, to Level 40+, to Level 60+
 *   Level 25+:    to Camp, to Level 40+, to Level 60+
 *   Level 40+:    to Camp, to Level 25+, to Level 60+
 *   Level 60+:    to Camp, to Level 25+, to Level 40+
 * - Selecting a route summons a temporary gryphon vehicle and auto-boards the player.
 * - The gryphon follows predefined waypoints with stability features: proximity arrival fallback,
 *   hop/final-hop watchdogs, stuck detection, turn-aware speed, and corner smoothing.
 * - Debug lines prefixed with "[Flight Debug]" are shown to Game Masters only.
 *
 * Vehicle creature template required:
 * - Create/clone a vehicle-capable gryphon template in DB (suggested entry 800011) with VehicleId set
 *   to a gryphon seat layout. Set ScriptName = "ac_gryphon_taxi_800011".
 */

#include "Creature.h"
#include "CreatureAI.h"
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
#include "MoveSplineInit.h"
#include <type_traits>
#include <chrono>
#include <string>
#include <cmath>
#include <numeric>
#include <deque>

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

// Simple scenic route in Azshara Crater (map 37) for levels 1-25+
static Position const kPath[] = {
    { 137.1860f, 954.9300f, 327.5140f, 0.327798f },  // acfm1
    { 269.8730f, 827.0230f, 289.0940f, 5.185540f },  // acfm2
    { 267.8360f, 717.6040f, 291.3220f, 4.173980f },  // acfm3
    { 198.4970f, 627.0770f, 293.5140f, 4.087590f },  // acfm4
    { 117.5790f, 574.0660f, 297.4290f, 2.723360f },  // acfm5
    {  11.1490f, 598.8440f, 284.8780f, 4.851790f },  // acfm6
    {  33.1020f, 542.8160f, 291.3630f, 5.169860f },  // acfm7
    {  42.6800f, 499.4120f, 315.3510f, 5.323030f },  // acfm8
    {  64.4858f, 485.8540f, 328.2840f, 5.758730f },  // acfm9
    {  80.5593f, 444.3300f, 338.0710f, 4.785630f },  // acfm10
    {  69.1581f, 403.6100f, 335.2570f, 4.257060f },  // acfm11
    {  36.7813f, 383.8160f, 320.9390f, 3.294960f },  // acfm12
    {   4.0747f, 388.9040f, 310.3970f, 2.729470f },  // acfm13
    { -12.7592f, 405.7640f, 307.0690f, 2.060310f },  // acfm14
    { -18.4005f, 416.3530f, 307.4260f, 2.060310f },  // acfm15
    // Additional nodes
    {  -20.3265f, 419.0570f, 308.2240f, 5.91598f  }, // acfm19
    {    0.70243f,403.3250f, 313.2740f, 5.59253f  }, // acfm20
    {   69.2940f, 343.8420f, 308.4380f, 5.55719f  }, // acfm21
    {  139.4370f, 304.9340f, 302.6710f, 5.87920f  }, // acfm22
    {  197.2580f, 251.1890f, 294.5420f, 5.32078f  }, // acfm23
    {  253.7330f, 174.3900f, 275.8360f, 5.54068f  }, // acfm24
    {  250.0990f, 108.0630f, 266.0210f, 5.06001f  }, // acfm25
    {  288.0720f,  35.7399f, 288.2950f, 5.28778f  }, // acfm26
    {  339.6580f, -39.0153f, 299.9640f, 5.07650f  }, // acfm27
    {  348.2650f, -99.4286f, 298.4710f, 4.86836f  }, // acfm28
    {  369.2020f,-154.2740f, 299.7370f, 5.45034f  }, // acfm29
    {  417.6860f,-179.9230f, 300.9320f, 6.21375f  }, // acfm30
    {  474.4610f,-156.4080f, 302.2410f, 0.538461f }, // acfm31
    {  530.1590f, -71.5742f, 295.4710f, 1.32386f  }, // acfm32
    {  563.7880f,  51.9529f, 288.2520f, 1.23747f  }, // acfm33
    {  601.5580f, 112.9140f, 282.8300f, 0.852621f }, // acfm34
    {  620.9780f, 126.0180f, 282.5800f, 4.24868f  }, // acfm35
    // Newly added extended waypoints
    {  623.2570f, 125.9740f, 282.3190f, 5.18330f  }, // acfm40
    {  626.1070f, 115.0240f, 284.6130f, 5.26654f  }, // acfm41
    {  656.0900f, 107.7920f, 282.0520f, 0.0719209f}, // acfm42
    {  684.2030f, 109.8170f, 283.2330f, 0.0719209f}, // acfm43
    {  702.2520f, 111.1180f, 292.5510f, 0.342098f }, // acfm44
    {  733.9850f, 135.3200f, 294.2670f, 1.05367f  }, // acfm45
    {  741.5040f, 164.3300f, 295.5340f, 1.39060f  }, // acfm46
    {  767.9480f, 227.9190f, 298.4810f, 1.08823f  }, // acfm47
    {  813.1940f, 285.8880f, 301.7320f, 6.21452f  }, // acfm48
    {  897.0600f, 294.0240f, 321.7490f, 6.24751f  }, // acfm49
    {  961.4010f, 280.4980f, 367.4450f, 5.97262f  }, // acfm50
    { 1059.9800f, 237.4870f, 384.4350f, 5.46057f  }, // acfm51
    { 1079.8700f, 190.0100f, 379.8740f, 4.87623f  }, // acfm52
    { 1085.7700f, 129.3060f, 368.2810f, 4.67989f  }, // acfm53
    { 1070.5100f,  86.2029f, 351.1760f, 4.25813f  }, // acfm54
    { 1051.0700f,  39.0495f, 334.1950f, 4.45447f  }, // acfm55
    { 1049.7600f,  13.1380f, 330.9040f, 4.90214f  }, // acfm56
    { 1070.1400f, -23.4705f, 330.2390f, 3.66827f  }, // acfm57
    {   73.2833f, 938.1900f, 341.0360f, 3.309180f }   // acfm0 (Startcamp, final)
};

// Robust path length (avoid toolchain issues with std::extent)
static constexpr uint8 kPathLength = static_cast<uint8>(sizeof(kPath) / sizeof(kPath[0]));
static constexpr uint8 kIndex_startcamp = static_cast<uint8>(kPathLength - 1);
static inline uint8 LastScenicIndex()
{
    // Last index before Startcamp is the final scenic node
    return static_cast<uint8>(kPathLength - 2);
}
// Fixed anchor for the legacy midpoint (acfm15) used by the return route
static constexpr uint8 kIndex_acfm15 = 14; // 0-based index for acfm15
static constexpr uint8 kIndex_acfm19 = 15; // first of the extended scenic nodes
static constexpr uint8 kIndex_acfm35 = 31; // last node for Level 40+ route
static constexpr uint8 kIndex_acfm40 = 32; // start of 40+ scenic sub-route
static constexpr uint8 kIndex_acfm57 = 49; // last of extended set (60+)

// Human-friendly label for a path node (handles the non-contiguous numbering after acfm15)
static inline std::string NodeLabel(uint8 idx)
{
    if (idx == kIndex_startcamp)
        return "Startcamp";
    // 0..14 => acfm1..acfm15
    if (idx <= 14)
        return std::string("acfm") + std::to_string(static_cast<unsigned>(idx + 1));
    // 15..31 => acfm19..acfm35
    if (idx >= 15 && idx <= 31)
    {
        unsigned n = 19u + static_cast<unsigned>(idx - 15);
        return std::string("acfm") + std::to_string(n);
    }
    // 32..48 => acfm40..acfm56, 49 => acfm57
    if (idx >= 32 && idx <= 48)
    {
        unsigned n = 40u + static_cast<unsigned>(idx - 32);
        return std::string("acfm") + std::to_string(n);
    }
    if (idx == 49)
        return std::string("acfm57");
    // Fallback
    return std::string("acfm?");
}

// Gryphon vehicle AI that follows the above path with the boarded player in seat 0
struct ac_gryphon_taxi_800011AI : public VehicleAI
{
    enum : uint32 { POINT_TAKEOFF = 9000, POINT_LAND_FINAL = 9001 };
    // Route mode declared early to ensure visibility in all in-class method bodies
    FlightRouteMode _routeMode = ROUTE_TOUR; // default to tour unless overridden by gossip

    ac_gryphon_taxi_800011AI(Creature* creature) : VehicleAI(creature) { }

    void SetData(uint32 id, uint32 value) override
    {
        // id 1: route mode
        if (id == 1)
        {
            if (value == ROUTE_RETURN)
                _routeMode = ROUTE_RETURN;
            else if (value == ROUTE_L40_DIRECT)
                _routeMode = ROUTE_L40_DIRECT;
            else if (value == ROUTE_L40_RETURN25)
                _routeMode = ROUTE_L40_RETURN25;
            else if (value == ROUTE_L40_RETURN0)
                _routeMode = ROUTE_L40_RETURN0;
            else if (value == ROUTE_L40_SCENIC)
                _routeMode = ROUTE_L40_SCENIC;
            else if (value == ROUTE_L60_RETURN40)
                _routeMode = ROUTE_L60_RETURN40;
            else if (value == ROUTE_L60_RETURN0)
                _routeMode = ROUTE_L60_RETURN0;
            else if (value == ROUTE_L60_RETURN19)
                _routeMode = ROUTE_L60_RETURN19;
            else if (value == ROUTE_L25_TO_40)
                _routeMode = ROUTE_L25_TO_40;
            else if (value == ROUTE_L25_TO_60)
                _routeMode = ROUTE_L25_TO_60;
            else if (value == ROUTE_L0_TO_57)
                _routeMode = ROUTE_L0_TO_57;
            else
                _routeMode = ROUTE_TOUR;
        }
    }

    void IsSummonedBy(WorldObject* summoner) override
    {
        // Prepare flight capabilities at spawn
        me->SetCanFly(true);
        me->SetDisableGravity(true);
        me->SetHover(true);
        me->SetSpeedRate(MOVE_FLIGHT, 2.0f);
        me->SetReactState(REACT_PASSIVE);
        me->SetFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_ATTACKABLE_1 | UNIT_FLAG_IMMUNE_TO_PC);

        // Face summoner (flightmaster or player)
        me->SetFacingToObject(summoner);

        // Initialize pathfinding system
        _pathGenerator = nullptr; // Will be created on first use
        _useSmartPathfinding = false;
        _pathfindingRetries = 0;

        // Small lift-off point above current pos to avoid ground clipping
        Position takeoff = me->GetPosition();
        takeoff.m_positionZ += 4.0f;
        me->GetMotionMaster()->MovePoint(POINT_TAKEOFF, takeoff);
    }

    void PassengerBoarded(Unit* passenger, int8 seatId, bool apply) override
    {
        if (!apply)
        {
            // If the last passenger disembarked, clean up quickly
            if (_started && !GetPassengerPlayer())
            {
                me->SetHover(false);
                me->SetDisableGravity(false);
                me->SetCanFly(false);
                DismountAndDespawn();
            }
            return;
        }

        // Start the scenic route once the first player sits (any passenger seat)
        if (!_started)
        {
            _started = true;
            // Record flight start position (snap to ground Z), used for stuck recovery
            {
                _flightStartPos = me->GetPosition();
                float gz = _flightStartPos.GetPositionZ();
                me->UpdateGroundPositionZ(_flightStartPos.GetPositionX(), _flightStartPos.GetPositionY(), gz);
                _flightStartPos.m_positionZ = gz;
                _lastPosX = me->GetPositionX();
                _lastPosY = me->GetPositionY();
                _stuckMs = 0;
            }
            // Ensure we are in flying mode when starting the route
            me->SetCanFly(true);
            me->SetDisableGravity(true);
            me->SetHover(true);

            Player* p = passenger ? passenger->ToPlayer() : nullptr;

            if (_routeMode == ROUTE_RETURN)
            {
                // Start the return path from the nearest scenic node at or below acfm15
                if (p && p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Starting Level 25+ → Camp return.", (int)seatId);

                // Find the nearest kPath index
                uint8 nearest = 0;
                float bestD2 = std::numeric_limits<float>::max();
                for (uint8 i = 0; i < kPathLength - 1; ++i) // exclude Startcamp index
                {
                    float dx = me->GetPositionX() - kPath[i].GetPositionX();
                    float dy = me->GetPositionY() - kPath[i].GetPositionY();
                    float d2 = dx * dx + dy * dy;
                    if (d2 < bestD2)
                    {
                        bestD2 = d2;
                        nearest = i;
                    }
                }
                // Clamp to at most acfm15, so we descend the classic section
                uint8 startIdx = nearest > kIndex_acfm15 ? kIndex_acfm15 : nearest;
                // We want to move to the next lower node first (if possible)
                _index = (startIdx > 0) ? static_cast<uint8>(startIdx - 1) : 0;
                if (p && p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Nearest node is {}. Beginning descent at {}.", NodeLabel(nearest), NodeLabel(_index));
                MoveToIndexWithSmartPath(_index);
                return;
            }

            if (_routeMode == ROUTE_L40_DIRECT)
            {
                // Level 40+ (option 3): Start at acfm1 and traverse forward to acfm35
                // This avoids a long single hop and guarantees proper waypoint sequencing.
                _index = 0;
                if (p && p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Level 40+ route: starting at {} and heading to {}.", (int)seatId, NodeLabel(_index), NodeLabel(kIndex_acfm35));
                MoveToIndexWithSmartPath(_index);
                return;
            }

            if (_routeMode == ROUTE_L40_RETURN25)
            {
                // If we're near acfm35, start reverse immediately toward acfm34; otherwise head to acfm35 first
                uint8 topIdx = kIndex_acfm35;
                float dx = me->GetPositionX() - kPath[topIdx].GetPositionX();
                float dy = me->GetPositionY() - kPath[topIdx].GetPositionY();
                float dist2d = sqrtf(dx * dx + dy * dy);
                if (p && p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Return to Level 25+ route.", (int)seatId);
                if (dist2d < 80.0f)
                {
                    _index = static_cast<uint8>(topIdx - 1);
                    if (p && p->IsGameMaster())
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Near {}. Departing immediately to {}.", NodeLabel(topIdx), NodeLabel(_index));
                    MoveToIndex(_index);
                    return;
                }
                _index = topIdx;
                if (p && p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Heading to {} to start the return-to-25+ path.", NodeLabel(_index));
                MoveToIndex(_index);
                return;
            }

            if (_routeMode == ROUTE_L40_RETURN0)
            {
                // Level 40+ to Camp: if near acfm35, step down immediately; else go to acfm35 first
                uint8 topIdx = kIndex_acfm35;
                float dx = me->GetPositionX() - kPath[topIdx].GetPositionX();
                float dy = me->GetPositionY() - kPath[topIdx].GetPositionY();
                float dist2d = sqrtf(dx * dx + dy * dy);
                if (p && p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Level 40+ → Camp route.", (int)seatId);
                if (dist2d < 80.0f)
                {
                    _index = static_cast<uint8>(topIdx - 1);
                    if (p && p->IsGameMaster())
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Near {}. Departing immediately to {}.", NodeLabel(topIdx), NodeLabel(_index));
                    MoveToIndex(_index);
                    return;
                }
                _index = topIdx;
                if (p && p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Heading to {} to start the Level 40+ → Camp path.", NodeLabel(_index));
                MoveToIndex(_index);
                return;
            }

            if (_routeMode == ROUTE_L40_SCENIC)
            {
                // Prefer to start at acfm40 if we're already nearby, otherwise traverse forward from acfm1 to acfm40 first
                float dx = me->GetPositionX() - kPath[kIndex_acfm40].GetPositionX();
                float dy = me->GetPositionY() - kPath[kIndex_acfm40].GetPositionY();
                float dist2d = sqrtf(dx * dx + dy * dy);
                // If already near the anchor (acfm40), skip it and start at acfm41 to avoid start-of-route stalls
                _index = (dist2d < 80.0f) ? static_cast<uint8>(kIndex_acfm40 + 1) : 0;
                if (p && p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Level 40+ scenic: starting at {} and heading to {}.", (int)seatId, NodeLabel(_index), NodeLabel(kIndex_acfm57));
                MoveToIndex(_index);
                return;
            }

            if (_routeMode == ROUTE_L0_TO_57)
            {
                // Startcamp -> step through all nodes up to acfm57
                _index = 0; // acfm1 is first scenic node; we will traverse forward up to acfm57
                if (p && p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Startcamp to 60+: starting at {} and heading to {}.", (int)seatId, NodeLabel(_index), NodeLabel(kIndex_acfm57));
                MoveToIndex(_index);
                return;
            }

            if (_routeMode == ROUTE_L60_RETURN40 || _routeMode == ROUTE_L60_RETURN19 || _routeMode == ROUTE_L60_RETURN0)
            {
                // Ensure we start from acfm57 or immediately step down if already there
                float dx = me->GetPositionX() - kPath[kIndex_acfm57].GetPositionX();
                float dy = me->GetPositionY() - kPath[kIndex_acfm57].GetPositionY();
                float dist2d = sqrtf(dx * dx + dy * dy);
                if (p && p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Level 60+ return.", (int)seatId);
                if (dist2d < 80.0f)
                {
                    _index = static_cast<uint8>(kIndex_acfm57 - 1);
                    if (p && p->IsGameMaster())
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Near {}. Departing immediately to {}.", NodeLabel(kIndex_acfm57), NodeLabel(_index));
                    MoveToIndex(_index);
                    return;
                }
                _index = kIndex_acfm57;
                if (p && p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Heading to {} to start the Level 60+ return.", NodeLabel(_index));
                MoveToIndex(_index);
                return;
            }

            if (_routeMode == ROUTE_L25_TO_40 || _routeMode == ROUTE_L25_TO_60)
            {
                // Prefer to start at acfm19 if we're already nearby, otherwise traverse forward from acfm1 up to acfm19 first
                float dx = me->GetPositionX() - kPath[kIndex_acfm19].GetPositionX();
                float dy = me->GetPositionY() - kPath[kIndex_acfm19].GetPositionY();
                float dist2d = sqrtf(dx * dx + dy * dy);
                // If already near the anchor (acfm19), skip it and start at acfm20 to avoid start-of-route stalls
                _index = (dist2d < 80.0f) ? static_cast<uint8>(kIndex_acfm19 + 1) : 0;
                // If the request is specifically 25 -> 40 and we are already very close to the endpoint (acfm35),
                // start one node earlier (acfm34) to avoid a single long hop and ensure proper sequencing.
                if (_routeMode == ROUTE_L25_TO_40)
                {
                    _l25to40ResetApplied = false; // fresh run; allow at most one sanity reset
                    float dx35 = me->GetPositionX() - kPath[kIndex_acfm35].GetPositionX();
                    float dy35 = me->GetPositionY() - kPath[kIndex_acfm35].GetPositionY();
                    float d35 = sqrtf(dx35 * dx35 + dy35 * dy35);
                    if (d35 < 80.0f)
                        _index = static_cast<uint8>(kIndex_acfm35 - 1);
                }
                if (p && p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Level 25+ route: starting at {} and heading to {}.", (int)seatId, NodeLabel(_index), _routeMode == ROUTE_L25_TO_40 ? NodeLabel(kIndex_acfm35) : NodeLabel(kIndex_acfm57));
                // Clear any pre-flight motion and perform a small vertical lift if far, to prevent start stalls
                me->GetMotionMaster()->Clear();
                float tdx = me->GetPositionX() - kPath[_index].GetPositionX();
                float tdy = me->GetPositionY() - kPath[_index].GetPositionY();
                float tdist = sqrtf(tdx * tdx + tdy * tdy);
                if (tdist > 120.0f)
                {
                    Position lift = me->GetPosition();
                    lift.m_positionZ += 18.0f;
                    me->GetMotionMaster()->MovePoint(POINT_TAKEOFF, lift);
                    // enqueue the first hop shortly after to avoid queuing conflicts
                    _scheduler.Schedule(std::chrono::milliseconds(300), [this](TaskContext /*ctx*/)
                    {
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

            // TOUR route: start from acfm1
            _index = 0;
            if (p && p->IsGameMaster())
                ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Starting at {}.", (int)seatId, NodeLabel(_index));
            MoveToIndex(_index);
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
        _scheduler.Schedule(std::chrono::milliseconds(5000), [this](TaskContext /*ctx*/)
        {
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

    // Forward declaration so methods defined earlier (like UpdateAI) can call it.
    bool IsFinalNodeOfCurrentRoute(uint8 idx) const;

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
                float near2d = (_index >= kIndex_acfm40) ? 10.0f : 6.0f; // allow a bit more tolerance on the 40+ segment
                // Known anchor: acfm19 can be sticky when descending from 40+ → Camp; accept a wider proximity
                if (_routeMode == ROUTE_L40_RETURN0 && _index == kIndex_acfm19)
                    near2d = 12.0f;
                if (dist2d < near2d && dz < 18.0f)
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
                        hopTimeout = 3000u; // short smoothing hop should resolve quickly
                    if (_hopElapsedMs > hopTimeout && !_isLanding)
                    {
                        // Hop timeout: try to reissue movement, a few times; then hard-snap to target to avoid loops
                        if (_hopRetries < 2)
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
                        _scheduler.Schedule(std::chrono::milliseconds(6000), [this](TaskContext /*ctx*/)
                        {
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
                std::vector<Position> recoveryPath;
                if (CalculateSmartPath(dest, recoveryPath) && !recoveryPath.empty())
                {
                    // Queue path and start moving along it
                    _smartPathQueue.clear();
                    for (auto const& rp : recoveryPath)
                    {
                        float dx2 = me->GetPositionX() - rp.GetPositionX();
                        float dy2 = me->GetPositionY() - rp.GetPositionY();
                        if ((dx2*dx2 + dy2*dy2) > 9.0f)
                            _smartPathQueue.push_back(rp);
                    }
                    if (!_smartPathQueue.empty())
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
        me->GetMotionMaster()->MovePoint(_currentPointId, _customTarget);
        _awaitingArrival = true;
        _sinceMoveMs = 0;
        _hopElapsedMs = 0;
        _hopRetries = 0;
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

    void DismountAndDespawn()
    {
        if (Vehicle* kit = me->GetVehicleKit())
        {
            for (int i = 0; i < 8; ++i)
                if (Unit* u = kit->GetPassenger(i))
                {
                    u->ExitVehicle();
                    if (Player* p = u->ToPlayer())
                        ChatHandler(p->GetSession()).SendSysMessage("You have arrived at your destination.");
                }
        }
    // Faster cleanup after dismount
    me->DespawnOrUnsummon(500);
    }

    uint8 _index = 0;
    uint32 _currentPointId = 0;
    bool _started = false;
    bool _awaitingArrival = false;
    bool _landingScheduled = false;
    bool _isLanding = false;
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
    // Corner smoothing state
    bool _movingToCustom = false;
    Position _customTarget;
    uint32 _customPointSeq = 0;
    
    // Enhanced pathfinding
    std::unique_ptr<PathGenerator> _pathGenerator;
    bool _useSmartPathfinding = false;
    uint32 _pathfindingRetries = 0;
    std::deque<Position> _smartPathQueue; // queued intermediate positions from PathGenerator

    // Smart pathfinding method - calculates intelligent path to destination
    bool CalculateSmartPath(Position const& destination, std::vector<Position>& outPath)
    {
        if (!_pathGenerator)
            _pathGenerator = std::make_unique<PathGenerator>(me);
            
        // Configure pathfinder for aerial movement
        _pathGenerator->SetUseStraightPath(false);
        _pathGenerator->SetUseRaycast(true);  // Use raycast for flying creatures
        _pathGenerator->SetPathLengthLimit(200.0f);  // Reasonable limit for flights
        
        bool success = _pathGenerator->CalculatePath(destination.GetPositionX(), 
                                                    destination.GetPositionY(), 
                                                    destination.GetPositionZ(), 
                                                    true);  // force destination
        
        if (success)
        {
            Movement::PointsArray const& points = _pathGenerator->GetPath();
            outPath.clear();
            
            // Convert PathGenerator points to Position objects
            for (auto const& point : points)
            {
                Position pos(point.x, point.y, point.z + 6.0f, 0.0f); // Add height for flight (smaller offset for smoother Z)
                outPath.push_back(pos);
            }
            
            if (Player* p = GetPassengerPlayer())
                if (p->IsGameMaster())
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Smart path calculated with {} points", outPath.size());
            
            return !outPath.empty();
        }
        
        return false;
    }
    
    // Enhanced pathfinding with fallback to waypoints
    void MoveToIndexWithSmartPath(uint8 idx)
    {
        Position destination(kPath[idx].GetPositionX(), kPath[idx].GetPositionY(), 
                           kPath[idx].GetPositionZ(), kPath[idx].GetOrientation());
        
        // Calculate distance to see if smart pathfinding is needed
        float dx = me->GetPositionX() - destination.GetPositionX();
        float dy = me->GetPositionY() - destination.GetPositionY();
        float dz = me->GetPositionZ() - destination.GetPositionZ();
        float dist3D = sqrtf(dx*dx + dy*dy + dz*dz);
        
        // Use smart pathfinding for medium/long distances or when stuck recovery is needed
        if (dist3D > 120.0f || _pathfindingRetries > 0)
        {
            std::vector<Position> smartPath;
            if (CalculateSmartPath(destination, smartPath))
            {
                // Queue useful intermediate points for chained movement. Skip points that are very close.
                _smartPathQueue.clear();
                for (auto const& sp : smartPath)
                {
                    float dx2 = me->GetPositionX() - sp.GetPositionX();
                    float dy2 = me->GetPositionY() - sp.GetPositionY();
                    float d2 = dx2*dx2 + dy2*dy2;
                    if (d2 > 9.0f) // skip tiny steps (3 units radius)
                        _smartPathQueue.push_back(sp);
                }
                if (!_smartPathQueue.empty())
                {
                    // Pop the first queued point and move to it; MovementInform chaining will continue
                    Position next = _smartPathQueue.front();
                    _smartPathQueue.pop_front();
                    _useSmartPathfinding = true;
                    MoveToCustom(next);
                    if (Player* p = GetPassengerPlayer())
                        if (p->IsGameMaster())
                            ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Using smart pathfinding to {} via {} smart points", NodeLabel(idx), (uint32)(_smartPathQueue.size() + 1));
                    return;
                }
            }
        }
        
        // Fallback to regular waypoint movement
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
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Aggressive bypass: remapped anchor acfm19 -> %s.", NodeLabel(nextIdx));
            }
            if (nextIdx == kIndex_acfm35)
            {
                // throttle repeated acfm35 remaps as well
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
                float d34 = sqrtf(dx34*dx34 + dy34*dy34);
                if (d34 < 150.0f)
                    nextIdx = altPrev;
                else if (kIndex_acfm35 + 1 < kPathLength)
                    nextIdx = static_cast<uint8>(kIndex_acfm35 + 1);
                _lastBypassedAnchor = kIndex_acfm35;
                _bypassMs = 0;
                if (Player* p = GetPassengerPlayer())
                    if (p->IsGameMaster())
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Aggressive bypass: remapped anchor acfm35 -> %s.", NodeLabel(nextIdx));
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
            _scheduler.Schedule(std::chrono::milliseconds(6000), [this](TaskContext /*ctx*/)
            {
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

private:
    // Is the given index the terminal node for the current route?
    bool IsFinalNodeOfCurrentRoute(uint8 idx) const
    {
        switch (_routeMode)
        {
            case ROUTE_L25_TO_40:
            case ROUTE_L40_DIRECT:
                return idx == kIndex_acfm35;
            case ROUTE_L25_TO_60:
            case ROUTE_L40_SCENIC:
            case ROUTE_L0_TO_57:
                return idx == kIndex_acfm57;
            case ROUTE_L60_RETURN40:
                return idx == kIndex_acfm40;
            case ROUTE_L60_RETURN19:
                return idx == kIndex_acfm19;
            case ROUTE_L60_RETURN0:
                return idx == 0 || idx == kIndex_startcamp;
            case ROUTE_L40_RETURN0:
                return idx == 0 || idx == kIndex_startcamp;
            default:
                return false;
        }
    }
    // Utility: quick 2D proximity check to a path index
    bool IsNearIndex(uint8 idx, float max2d) const
    {
        float dx = me->GetPositionX() - kPath[idx].GetPositionX();
        float dy = me->GetPositionY() - kPath[idx].GetPositionY();
        return sqrtf(dx * dx + dy * dy) < max2d;
    }
    // Compute the angle between (prev->curr) and (curr->next) in degrees
    float ComputeTurnAngleDeg(uint8 prevIdx, uint8 currIdx, uint8 nextIdx) const
    {
        const Position& p0 = kPath[prevIdx];
        const Position& p1 = kPath[currIdx];
        const Position& p2 = kPath[nextIdx];
        float v1x = p1.GetPositionX() - p0.GetPositionX();
        float v1y = p1.GetPositionY() - p0.GetPositionY();
        float v2x = p2.GetPositionX() - p1.GetPositionX();
        float v2y = p2.GetPositionY() - p1.GetPositionY();
        float len1 = sqrtf(v1x * v1x + v1y * v1y);
        float len2 = sqrtf(v2x * v2x + v2y * v2y);
        if (len1 < 0.001f || len2 < 0.001f)
            return 0.0f;
        float dot = (v1x * v2x + v1y * v2y) / (len1 * len2);
        if (dot > 1.0f) dot = 1.0f; else if (dot < -1.0f) dot = -1.0f;
        float rad = acosf(dot);
        return rad * 180.0f / 3.14159265f;
    }

    void AdjustSpeedForTurn(float angleDeg)
    {
        float rate = _baseFlightSpeed;
        if (angleDeg >  75.0f)
            rate = 1.2f;
        else if (angleDeg > 35.0f)
            rate = 1.6f;
        else
            rate = _baseFlightSpeed;
        // Apply a small smoothing filter to avoid abrupt camera/speed jumps between hops
        SmoothAndSetSpeed(rate);
    }

    float _baseFlightSpeed = 2.0f;
    // Small rolling window to smooth flight speed changes across hops
    std::deque<float> _speedHistory;
    static constexpr size_t kSpeedSmoothWindow = 3;

    // Smoothly blend recent speed targets and apply to the creature's flight speed.
    void SmoothAndSetSpeed(float targetRate)
    {
        // Push newest target
        _speedHistory.push_back(targetRate);
        // Trim history
        while (_speedHistory.size() > kSpeedSmoothWindow)
            _speedHistory.pop_front();

        // Compute simple average
        float sum = 0.0f;
        for (float v : _speedHistory)
            sum += v;
        float avg = sum / static_cast<float>(_speedHistory.size());

        // Apply averaged rate to the flight speed
        me->SetSpeedRate(MOVE_FLIGHT, avg);
    }
    // Anchor bypass throttling to avoid repeating remaps in quick succession
    uint8 _lastBypassedAnchor = 255;
    uint32 _bypassMs = 0; // ms since last bypass
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
    if (!taxi->GetVehicleKit())
    {
        ChatHandler(player->GetSession()).PSendSysMessage("[Flight] The summoned gryphon has no VehicleId. Please set creature_template.VehicleId for entry %u and ScriptName=ac_gryphon_taxi_800011.", static_cast<uint32>(taxi->GetEntry()));
        taxi->DespawnOrUnsummon(1000);
        return false;
    }
    if (CreatureAI* ai = taxi->AI())
        ai->SetData(1, static_cast<uint32>(mode));
    player->EnterVehicle(taxi, -1);
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

} // namespace DC_AC_Flight

void AddSC_flightmasters()
{
    // Register the four dedicated flightmaster scripts and the gryphon taxi
    new DC_AC_Flight::acflightmaster0();
    new DC_AC_Flight::acflightmaster25();
    new DC_AC_Flight::acflightmaster40();
    new DC_AC_Flight::acflightmaster60();
    new DC_AC_Flight::ac_gryphon_taxi_800011();
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
