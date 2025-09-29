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

namespace DC_AC_Flight
{
// NPCs
enum : uint32
{
    NPC_FLIGHTMASTER       = 800010,  // DB: ScriptName = ACFM1
    NPC_AC_GRYPHON_TAXI    = 800011   // DB: vehicle-capable gryphon, ScriptName = ac_gryphon_taxi_800011
};

// Simple scenic route in Azshara Crater (map 37) for levels 1-25+
static Position const kPath[] = {
    { 137.186f, 954.930f, 327.514f, 0.327798f },  // acfm1
    { 269.873f, 827.023f, 289.094f, 5.185540f },  // acfm2
    { 267.836f, 717.604f, 291.322f, 4.173980f },  // acfm3
    { 198.497f, 627.077f, 293.514f, 4.087590f },  // acfm4
    { 117.579f, 574.066f, 297.429f, 2.723360f },  // acfm5
    {  11.149f, 598.844f, 284.878f, 4.851790f },  // acfm6
    {  33.102f, 542.816f, 291.363f, 5.169860f },  // acfm7
    {  42.680f, 499.412f, 315.351f, 5.323030f },  // acfm8
    {  77.031f, 432.792f, 323.848f, 4.612250f },  // acfm9
    {  -4.513f, 415.750f, 308.212f, 2.919730f }   // acfm10 (final)
};

// Robust path length (avoid toolchain issues with std::extent)
static constexpr uint8 kPathLength = static_cast<uint8>(sizeof(kPath) / sizeof(kPath[0]));

// Gryphon vehicle AI that follows the above path with the boarded player in seat 0
struct ac_gryphon_taxi_800011AI : public VehicleAI
{
    ac_gryphon_taxi_800011AI(Creature* creature) : VehicleAI(creature) { }

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
            _index = 0;
            // Ensure we are in flying mode when starting the route
            me->SetCanFly(true);
            me->SetDisableGravity(true);
            me->SetHover(true);
            if (Player* p = passenger ? passenger->ToPlayer() : nullptr)
                ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Boarded gryphon seat {}. Starting at acfm1.", (int)seatId);
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
        VehicleAI::UpdateAI(diff);
        _scheduler.Update(diff);

        // Keep flight flags asserted during the whole route to avoid gravity glitches
        if (_started && !_isLanding)
        {
            me->SetCanFly(true);
            me->SetDisableGravity(true);
            me->SetHover(true);
        }

        // Proximity-based arrival fallback in case MovementInform is flaky
        if (_awaitingArrival && _started)
        {
            _sinceMoveMs += diff;
            // avoid instant triggers; require a minimal travel time
            static constexpr uint32 kMinTravelForProxMs = 1200; // wait a bit to avoid cutting corners
            static constexpr float kArriveRadius = 3.0f; // tighter radius to reduce early triggers
            if (_sinceMoveMs > kMinTravelForProxMs)
            {
                float dist = me->GetDistance(kPath[_index].GetPositionX(), kPath[_index].GetPositionY(), kPath[_index].GetPositionZ());
                if (dist <= kArriveRadius)
                {
                    HandleArriveAtCurrentNode(true /*isProximity*/);
                }
            }
        }
    }

private:
    enum : uint32 { POINT_TAKEOFF = 9000, POINT_LAND_FINAL = 9001 };

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
            ChatHandler(p->GetSession()).PSendSysMessage("[Flight Debug] Departing to acfm{} (idx {}).", (uint32)(idx + 1), (uint32)idx);
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
    me->DespawnOrUnsummon(2000);
    }

    uint8 _index = 0;
    uint32 _currentPointId = 0;
    bool _started = false;
    bool _awaitingArrival = false;
    bool _landingScheduled = false;
    TaskScheduler _scheduler;
    uint32 _sinceMoveMs = 0; // time since last MovePoint for proximity fallback

    void HandleArriveAtCurrentNode(bool isProximity)
    {
        if (!_awaitingArrival)
            return; // already handled

        // Reached a path node; continue to next or start landing sequence at the last
        if (_index + 1 < kPathLength)
        {
            uint8 arrivedIdx = _index; // index we just reached
            _awaitingArrival = false;
            ++_index; // move to next index
            // Debug: announce waypoint reached to the passenger (human-friendly: acfm1..acfmN)
            if (Player* p = GetPassengerPlayer())
                ChatHandler(p->GetSession()).PSendSysMessage(isProximity ? "[Flight Debug] Reached waypoint acfm{} (proximity)." : "[Flight Debug] Reached waypoint acfm{}.", (uint32)(arrivedIdx + 1));
            MoveToIndex(_index);
        }
        else
        {
            // Final node reached: initiate a safe landing, then dismount at ground
            float x = kPath[_index].GetPositionX();
            float y = kPath[_index].GetPositionY();
            float z = kPath[_index].GetPositionZ();
            me->UpdateGroundPositionZ(x, y, z);
            Position landPos = { x, y, z + 0.5f, kPath[_index].GetOrientation() };
            _isLanding = true;
            me->GetMotionMaster()->MoveLand(POINT_LAND_FINAL, landPos, 7.0f);
            // Fallback: if landing inform does not trigger, force dismount/despawn after 10s
            if (!_landingScheduled)
            {
                _landingScheduled = true;
                _scheduler.Schedule(std::chrono::milliseconds(10000), [this](TaskContext /*ctx*/)
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
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        CloseGossipMenuFor(player);

        if (action != 1)
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
