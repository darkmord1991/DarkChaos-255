/*
 * DarkChaos Custom: Flight masters (Option 2)
 *
 * ScriptName: ACFM1
 * DB bind: creature_template.entry = 800010 -> ScriptName = "ACFM1"
 *
 * Behavior:
 * - Gossip offers a scenic gryphon flight for low levels (1-25+) in Azshara Crater (map 37).
 * - When selected, the NPC summons a temporary gryphon vehicle and auto-boards the player.
 * - The gryphon flies through predefined waypoints, then lands and dismounts the player.
 *
 * Vehicle creature template required:
 * - Create a vehicle-capable gryphon template in DB (suggested entry 800011) with VehicleId set
 *   to a gryphon seat layout (1+ passenger seats). Set ScriptName = "ac_gryphon_taxi_800011".
 * - You can clone an existing gryphon vehicle from your DB (see notes at file end).
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
#include <type_traits>
#include <chrono>
#include <string>
#include <cmath>

namespace DC_AC_Flight
{
// NPCs
enum : uint32
{
    NPC_FLIGHTMASTER       = 800010,  // DB: ScriptName = ACFM1
    NPC_AC_GRYPHON_TAXI    = 800011   // DB: vehicle-capable gryphon, ScriptName = ac_gryphon_taxi_800011
};

// Route selection for the flight
enum FlightRouteMode : uint32
{
    ROUTE_TOUR = 0,     // acfm1 -> acfm15 (land at acfm15)
    ROUTE_RETURN = 1,   // acfm15 -> Startcamp (acfm0)
    ROUTE_L40_DIRECT = 2, // Startcamp (acfm0) -> acfm35 (direct)
    ROUTE_L40_RETURN25 = 3, // acfm35 -> acfm19 (reverse, land at acfm19)
    ROUTE_L40_SCENIC = 4,   // acfm40 -> acfm57 (ascending)
    ROUTE_L60_RETURN40 = 5, // acfm57 -> acfm40 (descending)
    ROUTE_L60_RETURN0  = 6, // acfm57 -> Startcamp (full descend to 0 then Startcamp)
    ROUTE_L60_RETURN19 = 7  // acfm57 -> acfm19 (descending)
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
    { 1068.2100f, -21.4253f, 331.4710f, 5.18095f  }, // acfm57
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
            else if (value == ROUTE_L40_SCENIC)
                _routeMode = ROUTE_L40_SCENIC;
            else if (value == ROUTE_L60_RETURN40)
                _routeMode = ROUTE_L60_RETURN40;
            else if (value == ROUTE_L60_RETURN0)
                _routeMode = ROUTE_L60_RETURN0;
            else if (value == ROUTE_L60_RETURN19)
                _routeMode = ROUTE_L60_RETURN19;
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

        // Small lift-off point above current pos to avoid ground clipping
        Position takeoff = me->GetPosition();
        takeoff.m_positionZ += 4.0f;
        me->GetMotionMaster()->MovePoint(POINT_TAKEOFF, takeoff);
    }

    void PassengerBoarded(Unit* passenger, int8 seatId, bool apply) override
    {
        if (!apply)
            return;

        // Start the scenic route once the first player sits (any passenger seat)
        if (!_started)
        {
            _started = true;
            // Ensure we are in flying mode when starting the route
            me->SetCanFly(true);
            me->SetDisableGravity(true);
            me->SetHover(true);

            Player* p = passenger ? passenger->ToPlayer() : nullptr;

            if (_routeMode == ROUTE_RETURN)
            {
                // If we are already near acfm15 (e.g., you took the tour and are at the end), start going backward immediately.
                float dx = me->GetPositionX() - kPath[kIndex_acfm15].GetPositionX();
                float dy = me->GetPositionY() - kPath[kIndex_acfm15].GetPositionY();
                float dist2d = sqrtf(dx * dx + dy * dy);
                if (p)
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Starting return route.", (int)seatId);

                if (dist2d < 80.0f)
                {
                    // We are at (or very close to) acfm15; go to acfm14 first
                    _index = static_cast<uint8>(kIndex_acfm15 - 1);
                    if (p)
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Near {}. Departing immediately to {}.", NodeLabel(kIndex_acfm15), NodeLabel(_index));
                    MoveToIndex(_index);
                    return;
                }
                // Otherwise, head to acfm15 to begin the reverse path
                _index = kIndex_acfm15;
                if (p)
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Heading to {} to start the return path.", NodeLabel(_index));
                MoveToIndex(_index);
                return;
            }

            if (_routeMode == ROUTE_L40_DIRECT)
            {
                // Level 40+ direct: fly straight to acfm35 from Startcamp
                _index = kIndex_acfm35;
                if (p)
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Level 40+ route to {}.", (int)seatId, NodeLabel(_index));
                MoveToIndex(_index);
                return;
            }

            if (_routeMode == ROUTE_L40_RETURN25)
            {
                // If we're near acfm35, start reverse immediately toward acfm34; otherwise head to acfm35 first
                uint8 topIdx = kIndex_acfm35;
                float dx = me->GetPositionX() - kPath[topIdx].GetPositionX();
                float dy = me->GetPositionY() - kPath[topIdx].GetPositionY();
                float dist2d = sqrtf(dx * dx + dy * dy);
                if (p)
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Return to Level 25+ route.", (int)seatId);
                if (dist2d < 80.0f)
                {
                    _index = static_cast<uint8>(topIdx - 1);
                    if (p)
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Near {}. Departing immediately to {}.", NodeLabel(topIdx), NodeLabel(_index));
                    MoveToIndex(_index);
                    return;
                }
                _index = topIdx;
                if (p)
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Heading to {} to start the return-to-25+ path.", NodeLabel(_index));
                MoveToIndex(_index);
                return;
            }

            if (_routeMode == ROUTE_L40_SCENIC)
            {
                // Start at acfm40 and go to acfm57
                _index = kIndex_acfm40;
                if (p)
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Level 40+ scenic: starting at {}.", (int)seatId, NodeLabel(_index));
                MoveToIndex(_index);
                return;
            }

            if (_routeMode == ROUTE_L60_RETURN40 || _routeMode == ROUTE_L60_RETURN19 || _routeMode == ROUTE_L60_RETURN0)
            {
                // Ensure we start from acfm57 or immediately step down if already there
                float dx = me->GetPositionX() - kPath[kIndex_acfm57].GetPositionX();
                float dy = me->GetPositionY() - kPath[kIndex_acfm57].GetPositionY();
                float dist2d = sqrtf(dx * dx + dy * dy);
                if (p)
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Level 60+ return.", (int)seatId);
                if (dist2d < 80.0f)
                {
                    _index = static_cast<uint8>(kIndex_acfm57 - 1);
                    if (p)
                        ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Near {}. Departing immediately to {}.", NodeLabel(kIndex_acfm57), NodeLabel(_index));
                    MoveToIndex(_index);
                    return;
                }
                _index = kIndex_acfm57;
                if (p)
                    ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Heading to {} to start the Level 60+ return.", NodeLabel(_index));
                MoveToIndex(_index);
                return;
            }

            // TOUR route: start from acfm1
            _index = 0;
            if (p)
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

        if (id == _currentPointId)
        {
            HandleArriveAtCurrentNode(false /*isProximity*/);
        }
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
            if (_sinceMoveMs > 300) // small debounce
            {
                float dx = me->GetPositionX() - kPath[_index].GetPositionX();
                float dy = me->GetPositionY() - kPath[_index].GetPositionY();
                float dz = fabs(me->GetPositionZ() - kPath[_index].GetPositionZ());
                float dist2d = sqrtf(dx * dx + dy * dy);
                if (dist2d < 6.0f && dz < 15.0f)
                {
                    HandleArriveAtCurrentNode(true /*isProximity*/);
                }
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
        if (Player* p = GetPassengerPlayer())
            ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Departing to {} (idx {}).", NodeLabel(idx), (uint32)idx);
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

    void HandleArriveAtCurrentNode(bool isProximity)
    {
        if (!_awaitingArrival)
            return; // already handled

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
                hasNext = false; // land at acfm35
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
        }

        if (hasNext)
        {
            uint8 arrivedIdx = _index; // index we just reached
            _awaitingArrival = false;
            _index = nextIdx; // move to next index
            if (Player* p = GetPassengerPlayer())
                ChatHandler(p->GetSession()).PSendSysMessage(isProximity ? "[Flight Debug] Reached waypoint {} (proximity)." : "[Flight Debug] Reached waypoint {}.", NodeLabel(arrivedIdx));
            MoveToIndex(_index);
            return;
        }

        // Final node reached: initiate a safe landing, then dismount at ground
        float x = kPath[_index].GetPositionX();
        float y = kPath[_index].GetPositionY();
        float z = kPath[_index].GetPositionZ();
        me->UpdateGroundPositionZ(x, y, z);
        Position landPos = { x, y, z + 0.5f, kPath[_index].GetOrientation() };
        _isLanding = true;
        me->GetMotionMaster()->MoveLand(POINT_LAND_FINAL, landPos, 7.0f);
        // Fallback: if landing inform does not trigger, force dismount/despawn quickly
        if (!_landingScheduled)
        {
            _landingScheduled = true;
            _scheduler.Schedule(std::chrono::milliseconds(4000), [this](TaskContext /*ctx*/)
            {
                if (!me->IsInWorld())
                    return;
                if (Player* p = GetPassengerPlayer())
                    ChatHandler(p->GetSession()).SendSysMessage("[Flight Debug] Landing fallback triggered. Forcing dismount and despawn.");
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

class ACFM1 : public CreatureScript
{
public:
    ACFM1() : CreatureScript("ACFM1") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        // Optional level gate (1-25+): currently available to all; uncomment to enforce <=25
        // if (player->getLevel() > 25 && !player->IsGameMaster())
        //     AddGossipItemFor(player, 0, "This flight is designed for newer adventurers.", GOSSIP_SENDER_MAIN, 0);

    AddGossipItemFor(player, 0, "Take the gryphon tour (levels 1-25+)", GOSSIP_SENDER_MAIN, 1);
    AddGossipItemFor(player, 0, "Return flight to Startcamp", GOSSIP_SENDER_MAIN, 2);
    AddGossipItemFor(player, 0, "Level 40+", GOSSIP_SENDER_MAIN, 3);
    AddGossipItemFor(player, 0, "Back to Level 25+", GOSSIP_SENDER_MAIN, 4);
    AddGossipItemFor(player, 0, "Level 40+ scenic (acfm40 → acfm57)", GOSSIP_SENDER_MAIN, 5);
    AddGossipItemFor(player, 0, "Level 60+: back to 40+ (acfm57 → acfm40)", GOSSIP_SENDER_MAIN, 6);
    AddGossipItemFor(player, 0, "Level 60+: back to 25+ (acfm57 → acfm19)", GOSSIP_SENDER_MAIN, 7);
    AddGossipItemFor(player, 0, "Level 60+: back to Startcamp (acfm57 → acfm0)", GOSSIP_SENDER_MAIN, 8);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        if (action < 1 || action > 8)
            return true;

        // Summon gryphon slightly above ground near the flightmaster
        Position where = creature->GetPosition();
        where.m_positionZ += 3.0f;
    TempSummon* taxi = creature->SummonCreature(NPC_AC_GRYPHON_TAXI, where, TEMPSUMMON_TIMED_DESPAWN, 300000); // 5 minutes
        if (!taxi)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("[Flight] Failed to summon gryphon (entry %u).", static_cast<uint32>(NPC_AC_GRYPHON_TAXI));
            return true;
        }

        if (!taxi->GetVehicleKit())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("[Flight] The summoned gryphon has no VehicleId. Please set creature_template.VehicleId for entry %u and ScriptName=ac_gryphon_taxi_800011.", static_cast<uint32>(taxi->GetEntry()));
            taxi->DespawnOrUnsummon(1000);
            return true;
        }

        // Select route mode: 1=tour, 2=return, 3=Level 40+ direct, 4=Level 40+ back to 25+, 5=40 scenic to 57, 6=57->40, 7=57->19, 8=57->0
        if (CreatureAI* ai = taxi->AI())
        {
            uint32 mode = ROUTE_TOUR;
            if (action == 2) mode = ROUTE_RETURN;
            else if (action == 3) mode = ROUTE_L40_DIRECT;
            else if (action == 4) mode = ROUTE_L40_RETURN25;
            else if (action == 5) mode = ROUTE_L40_SCENIC;
            else if (action == 6) mode = ROUTE_L60_RETURN40;
            else if (action == 7) mode = ROUTE_L60_RETURN19;
            else if (action == 8) mode = ROUTE_L60_RETURN0;
            ai->SetData(1, mode);
        }

        // Board the player, auto-select a suitable passenger seat (-1)
        player->EnterVehicle(taxi, -1);
        ChatHandler(player->GetSession()).SendSysMessage("[Flight Debug] Attempting to board gryphon (auto-seat). If you don't move, VehicleId/seat config may be wrong.");
        return true;
    }
};

} // namespace DC_AC_Flight

void AddSC_flightmasters()
{
    new DC_AC_Flight::ACFM1();
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
UPDATE creature_template SET ScriptName = 'ACFM1' WHERE entry = 800010;

*/
