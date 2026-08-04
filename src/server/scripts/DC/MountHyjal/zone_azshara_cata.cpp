/*
 * Copyright (C) 2016+ DarkChaos <www.azerothcore.org>, released under AGPL v3.
 *
 * Cataclysm-era Azshara choreography on the downported continent (map 750):
 * the Wings of Steel biplane flight to the runestone tower and Slinky
 * Sharpshiv's grapple-climb assassination run for quest 14464 "Lightning
 * Strike Assassination". Ported from Project-Neltharion zone_azshara.cpp;
 * clone entries carry the +3,600,000 Azshara offset.
 *
 * Deliberate departures from the Neltharion originals:
 *
 *  1. Their planes were summoned by a spellclick bunny and took off when a
 *     runway controller pinged them with spell 98914, picking a flight path
 *     by the controller's SOURCE-DB spawn guid (180136-180138). Neither the
 *     bunny nor those guids exist here. On map 750 the planes are world
 *     spawns with their own npc_spellclick_spells row, so boarding IS the
 *     trigger: the plane taxis to the nearest takeoff controller (3637141)
 *     and flies whichever of the three authored routes starts closest to it.
 *     npc_wings_of_steel_spellclick is therefore not ported at all.
 *  2. Spell 70988 (parachute visual) is not in this server's Spell.dbc, and
 *     the explosives (36758) and parachute (36761) props have no +3.6M clone
 *     template. Their casts/summons are guarded so the choreography plays
 *     through without the props instead of aborting.
 *  3. KilledMonsterCredit ids are remapped +3,600,000 like every other clone
 *     reference. Quest 14464 has no kill objectives in this DB, so the calls
 *     are kept for faithfulness only and are harmless no-ops.
 *
 * Delayed steps use TaskScheduler because AzerothCore has no CastWithDelay().
 */

#include "CreatureScript.h"
#include "MotionMaster.h"
#include "MoveSplineInitArgs.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "TaskScheduler.h"

#include <limits>

enum AzsharaCataShared
{
    // +3,600,000 Azshara-clone band
    NPC_SLINKY_SHARPSHIV        = 3636729,
    NPC_GRAPPLE_PLAYER          = 3636707,
    NPC_GRAPPLE_SHARPSHIV       = 3636738,
    NPC_CLIMB_PLAYER_1          = 3636716,
    NPC_CLIMB_PLAYER_2          = 3636718,
    NPC_CLIMB_PLAYER_3          = 3636720,
    NPC_CLIMB_SHARPSHIV_1       = 3636753,
    NPC_CLIMB_SHARPSHIV_2       = 3636754,
    NPC_CLIMB_SHARPSHIV_3       = 3636755,
    NPC_SHARPSHIV_EXPLOSIVES    = 3636758,  // no clone template yet -- summon is guarded
    NPC_CAPTAIN_GRUNWALD        = 3636680,
    NPC_MARIEL_DAWNSONG         = 3636687,
    NPC_WINGS_OF_STEEL          = 3637139,
    NPC_TAKEOFF_CONTROLLER      = 3637141,
    CREDIT_WINGS_OF_STEEL       = 3674960,  // no-op: 14464 has no objectives in this DB

    QUEST_LIGHTNING_STRIKE_ASSASSINATION = 14464,

    SPELL_RIDE_VEHICLE          = 46598,
    SPELL_EJECT_ALL_PASSENGERS  = 50630,
    SPELL_ROPE_TOWER            = 66206,
    SPELL_FLIGHT_SPEED_300      = 54422,
    SPELL_DUMMY_PING            = 98914,   // present in spell_dbc
    SPELL_DISMOUNT_CANCEL_FORMS = 151235,  // present in spell_dbc
    SPELL_SLINKY_DISGUISE       = 49414,
    SPELL_PLAYER_DISGUISE       = 49416,

    ACTION_REMOVE_HOOK_EFFECT   = 1,

    POINT_RUNWAY                = 1
};

// MoveSmoothPath(Vector3[], size) is gone; build a PointsArray and feed
// MoveSplinePath. Element 0 MUST be the unit's current position (see the
// identical shim in zone_molten_front.cpp): MoveSplineInit::Launch overwrites
// args.path[0] with the real position and SplineHandler reports
// currentPathIdx() - 1, so the leading node makes the reported ids match the
// authored 1-based indices and the last node actually gets reported.
static void DoMoveSmoothPath(Unit* who, G3D::Vector3 const* path, uint32 size)
{
    if (!who || !path || !size)
        return;

    Movement::PointsArray points;
    points.reserve(size + 1);
    points.push_back(G3D::Vector3(who->GetPositionX(), who->GetPositionY(), who->GetPositionZ()));
    for (uint32 i = 0; i < size; ++i)
        points.push_back(path[i]);

    who->GetMotionMaster()->MoveSplinePath(&points);
}

// ---------------------------------------------------------------------------
// Wings of Steel -- the three flight routes from the Southern Rocketway
// terminus to the runestone tower. Coordinates are Blizzard's, unchanged:
// map 750 preserves Kalimdor coordinates.
// ---------------------------------------------------------------------------
uint32 const kWingsPathLeftSize = 16;
G3D::Vector3 const kWingsPathLeft[kWingsPathLeftSize] =
{
    { 3598.143f, -6735.666f, 86.070f },
    { 3648.121f, -6766.064f, 94.818f },
    { 3693.572f, -6789.290f, 104.665f },
    { 3824.602f, -6802.274f, 121.540f },
    { 4004.728f, -6746.646f, 138.756f },
    { 4132.694f, -6334.678f, 128.979f },
    { 4137.262f, -5851.200f, 183.808f },
    { 4006.637f, -5585.204f, 165.369f },
    { 3800.970f, -5374.453f, 184.715f },
    { 3728.270f, -4977.077f, 185.488f },
    { 3616.378f, -4846.019f, 222.826f },
    { 3270.852f, -4921.681f, 249.234f },
    { 3012.903f, -4583.831f, 300.744f },
    { 3109.884f, -4310.421f, 272.732f },
    { 3001.062f, -4139.711f, 160.263f },
    { 2916.981f, -4084.540f, 173.505f }
};

uint32 const kWingsPathMiddleSize = 15;
G3D::Vector3 const kWingsPathMiddle[kWingsPathMiddleSize] =
{
    { 3519.417f, -6808.054f, 87.089f },
    { 3519.928f, -6841.252f, 94.768f },
    { 3519.587f, -6891.614f, 111.61f },
    { 3597.304f, -7006.590f, 124.23f },
    { 3744.396f, -7016.013f, 121.78f },
    { 3772.265f, -6852.322f, 111.03f },
    { 3568.662f, -6362.050f, 109.24f },
    { 3418.374f, -5780.766f, 85.755f },
    { 3272.783f, -5551.112f, 98.618f },
    { 3116.183f, -5360.431f, 170.67f },
    { 3013.380f, -4928.916f, 202.74f },
    { 3055.236f, -4435.231f, 201.91f },
    { 3104.567f, -4259.404f, 199.56f },
    { 3012.517f, -4150.576f, 149.03f },
    { 2893.900f, -4071.176f, 159.65f }
};

uint32 const kWingsPathRightSize = 17;
G3D::Vector3 const kWingsPathRight[kWingsPathRightSize] =
{
    { 3432.314f, -6752.930f, 84.633f },
    { 3403.952f, -6765.738f, 98.812f },
    { 3364.240f, -6774.331f, 108.80f },
    { 3312.277f, -6743.876f, 89.397f },
    { 3273.416f, -6563.988f, 70.778f },
    { 3321.541f, -6166.822f, 78.243f },
    { 3403.397f, -5840.697f, 92.472f },
    { 3593.539f, -5587.754f, 128.94f },
    { 3732.379f, -5407.935f, 166.37f },
    { 3750.813f, -5149.458f, 182.05f },
    { 3723.483f, -4926.706f, 220.39f },
    { 3678.779f, -4588.167f, 221.60f },
    { 3568.081f, -4239.049f, 214.76f },
    { 3473.672f, -4245.525f, 217.38f },
    { 3127.098f, -4245.295f, 185.17f },
    { 3012.521f, -4149.638f, 197.43f },
    { 2898.972f, -4071.174f, 173.59f }
};

struct WingsRoute
{
    G3D::Vector3 const* nodes;
    uint32 size;
};

WingsRoute const kWingsRoutes[3] =
{
    { kWingsPathLeft,   kWingsPathLeftSize },
    { kWingsPathMiddle, kWingsPathMiddleSize },
    { kWingsPathRight,  kWingsPathRightSize }
};

Position const kAirplaneDropOff = { 3001.557f, -4151.456f, 101.537f };

// ---------------------------------------------------------------------------
// Wings of Steel biplane (3637139, VehicleId 576) -- boarding via its
// npc_spellclick_spells row (46598) starts the flight.
// ---------------------------------------------------------------------------
struct npc_wings_of_steel_airplane : public ScriptedAI
{
    npc_wings_of_steel_airplane(Creature* creature) : ScriptedAI(creature) { }

    void PassengerBoarded(Unit* passenger, int8 /*seatId*/, bool apply) override
    {
        Player* player = passenger->ToPlayer();
        if (!player)
            return;

        if (apply)
        {
            _playerGUID = player->GetGUID();
            player->KilledMonsterCredit(CREDIT_WINGS_OF_STEEL);
            me->SetControlled(true, UNIT_STATE_ROOT);
            _scheduler.Schedule(2s, [this](TaskContext /*context*/) { TaxiToRunway(); });
        }
        else if (!_landing)
        {
            // The rider bailed out mid-sequence: recycle the plane so the
            // spawn point gets a fresh, clickable one on respawn.
            me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS, true);
            me->DespawnOrUnsummon(1s);
        }
    }

    void MovementInform(uint32 type, uint32 point) override
    {
        if (type == POINT_MOTION_TYPE && point == POINT_RUNWAY)
        {
            TakeOff();
        }
        // AC 3.3.5: MoveSplinePath reports per-segment ESCORT_MOTION_TYPE.
        // The original ejected one node before the end of each route (that is
        // where the tower landing strip is); with 1-based reporting that is
        // routeSize - 1.
        else if (type == ESCORT_MOTION_TYPE && _airborne && point == kWingsRoutes[_routeIndex].size - 1)
        {
            Land();
        }
    }

    void UpdateAI(uint32 diff) override
    {
        _scheduler.Update(diff);
    }

private:
    void TaxiToRunway()
    {
        me->SetControlled(false, UNIT_STATE_ROOT);

        if (Creature* controller = me->FindNearestCreature(NPC_TAKEOFF_CONTROLLER, 100.0f))
            me->GetMotionMaster()->MovePoint(POINT_RUNWAY, controller->GetPositionX(),
                controller->GetPositionY(), controller->GetPositionZ());
        else
            TakeOff();
    }

    void TakeOff()
    {
        if (_airborne)
            return;

        _airborne = true;
        me->SetDisableGravity(true);
        me->SetCanFly(true);
        me->GetMotionMaster()->Clear();
        me->CastSpell(me, SPELL_FLIGHT_SPEED_300, true);

        // The source picked left/middle/right by runway-controller spawn guid;
        // those guids do not exist here, so fly whichever route starts closest.
        float best = std::numeric_limits<float>::max();
        for (uint8 i = 0; i < 3; ++i)
        {
            G3D::Vector3 const& start = kWingsRoutes[i].nodes[0];
            float const dist = me->GetExactDist2dSq(start.x, start.y);
            if (dist < best)
            {
                best = dist;
                _routeIndex = i;
            }
        }

        DoMoveSmoothPath(me, kWingsRoutes[_routeIndex].nodes, kWingsRoutes[_routeIndex].size);
    }

    void Land()
    {
        _landing = true;
        me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS, true);

        if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
        {
            player->NearTeleportTo(me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), me->GetOrientation());
            player->GetMotionMaster()->MoveJump(kAirplaneDropOff, 20.0f, 20.0f);
        }

        me->DespawnOrUnsummon(6s);
    }

    TaskScheduler _scheduler;
    ObjectGuid _playerGUID;
    uint8 _routeIndex = 0;
    bool _airborne = false;
    bool _landing = false;
};

// ---------------------------------------------------------------------------
// Slinky Sharpshiv (3636729, VehicleId 543) -- quest 14464.
//
// The world spawn is the questgiver; picking "I'm ready" summons an ACTOR of
// the same entry that runs the event: both throw grappling hooks, ride the
// three tower-scaling seats up, clear Captain Grunwald and Mariel Dawnsong,
// plant the explosives, and glide off with the player aboard Slinky.
// ---------------------------------------------------------------------------
Position const kExplosivesPos[4] =
{
    { 2866.134f, -4025.855f, 179.77f, 0.0f },
    { 2869.959f, -4021.394f, 179.77f, 0.0f },
    { 2863.556f, -4031.413f, 179.77f, 0.0f },
    { 2873.211f, -4028.938f, 179.77f, 0.0f }
};

uint32 const kSlinkyEscapePathSize = 5;
G3D::Vector3 const kSlinkyEscapePath[kSlinkyEscapePathSize] =
{
    { 2889.279f, -4024.420f, 184.02f },
    { 2941.376f, -4079.742f, 154.12f },
    { 2978.739f, -4112.083f, 133.30f },
    { 2992.794f, -4136.739f, 121.41f },
    { 2974.877f, -4164.275f, 103.15f }
};

struct npc_slinky_sharpshivAI : public ScriptedAI
{
    npc_slinky_sharpshivAI(Creature* creature) : ScriptedAI(creature) { }

    // Only the gossip-summoned actor runs the event; the world spawn is never
    // summoned, so its AI stays idle.
    void IsSummonedBy(WorldObject* summoner) override
    {
        Player* player = summoner ? summoner->ToPlayer() : nullptr;
        if (!player)
            return;

        _playerGUID = player->GetGUID();
        me->RemoveAura(SPELL_SLINKY_DISGUISE);
        me->RemoveNpcFlag(NPCFlags(UNIT_NPC_FLAG_GOSSIP | UNIT_NPC_FLAG_QUESTGIVER));
        me->SetUnitFlag(UnitFlags(UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC));
        player->CastSpell(player, SPELL_DISMOUNT_CANCEL_FORMS, true);
        _scheduler.Schedule(1500ms, [this](TaskContext /*context*/) { ThrowGrapples(); });
    }

    void DoAction(int32 action) override
    {
        if (action != ACTION_REMOVE_HOOK_EFFECT)
            return;

        _reachedTop = true;
        me->RemoveUnitFlag(UnitFlags(UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC));
        RetractHook(_hookSharpshivGUID);
        RetractHook(_hookPlayerGUID);
    }

    // The player grabs on for the glide down (npc_spellclick_spells row added
    // together with this script; the flag itself is only set at "Hop on!").
    void PassengerBoarded(Unit* passenger, int8 /*seatId*/, bool apply) override
    {
        if (!apply || !passenger->IsPlayer())
            return;

        _scheduler.CancelGroup(GROUP_PICKUP_TIMEOUT);
        me->RemoveNpcFlag(UNIT_NPC_FLAG_SPELLCLICK);
        me->GetMotionMaster()->MoveJump(2882.671f, -4024.391f, 176.12f, 10.0f, 5.0f);
        _scheduler.Schedule(1s, [this](TaskContext /*context*/)
        {
            _gliding = true;
            // 70988 (parachute visual) is absent from this Spell.dbc and the
            // chute prop (36761) has no clone template -- the glide runs bare.
            DoMoveSmoothPath(me, kSlinkyEscapePath, kSlinkyEscapePathSize);
        });

        // Detonation ping for any planted crates (guarded summon, see below).
        std::list<Creature*> crates;
        me->GetCreatureListWithEntryInGrid(crates, NPC_SHARPSHIV_EXPLOSIVES, 50.0f);
        for (Creature* crate : crates)
            crate->CastSpell(crate, SPELL_DUMMY_PING, true);
    }

    void MovementInform(uint32 type, uint32 point) override
    {
        if (type == ESCORT_MOTION_TYPE && _gliding && point >= kSlinkyEscapePathSize)
        {
            _gliding = false;
            me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS, true);
            me->DespawnOrUnsummon(200ms);
        }
    }

    void UpdateAI(uint32 diff) override
    {
        _scheduler.Update(diff);

        // Tower cleared? Then hop back to the platform edge and set the charges.
        if (_reachedTop
            && !me->FindNearestCreature(NPC_CAPTAIN_GRUNWALD, 40.0f)
            && !me->FindNearestCreature(NPC_MARIEL_DAWNSONG, 30.0f))
        {
            _reachedTop = false;
            me->CombatStop();
            me->GetMotionMaster()->MoveJump(2867.256f, -4026.04f, 179.77f, 10.0f, 10.0f);
            Talk(1, ObjectAccessor::GetPlayer(*me, _playerGUID), 1s);
            _scheduler.Schedule(2500ms, [this](TaskContext /*context*/) { PlantExplosives(); });
        }

        DoMeleeAttackIfReady();
    }

private:
    enum { GROUP_PICKUP_TIMEOUT = 1 };

    void ThrowGrapples()
    {
        Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
        Talk(0, player);
        me->SetFacingTo(2.14f);
        me->HandleEmoteCommand(EMOTE_ONESHOT_ATTACK_THROWN);

        if (Creature* hook = me->SummonCreature(NPC_GRAPPLE_SHARPSHIV, me->GetPositionX(), me->GetPositionY(),
            me->GetPositionZ(), me->GetOrientation(), TEMPSUMMON_TIMED_DESPAWN, 30000))
        {
            _hookSharpshivGUID = hook->GetGUID();
            hook->CastSpell(me, SPELL_ROPE_TOWER, true);
            hook->GetMotionMaster()->MoveJump(2873.32f, -4037.46f, 187.42f, 25.0f, 15.0f);
        }

        if (player)
        {
            if (Creature* hook = player->SummonCreature(NPC_GRAPPLE_PLAYER, player->GetPositionX(),
                player->GetPositionY(), player->GetPositionZ(), player->GetOrientation(),
                TEMPSUMMON_TIMED_DESPAWN, 30000))
            {
                player->HandleEmoteCommand(EMOTE_ONESHOT_ATTACK_THROWN);
                _hookPlayerGUID = hook->GetGUID();
                hook->CastSpell(player, SPELL_ROPE_TOWER, true);
                hook->GetMotionMaster()->MoveJump(2870.18f, -4038.71f, 187.5f, 25.0f, 15.0f);
            }
        }

        _scheduler.Schedule(3s, [this](TaskContext /*context*/) { StartClimb(); });
    }

    void StartClimb()
    {
        if (Creature* seat = me->FindNearestCreature(NPC_CLIMB_SHARPSHIV_1, 60.0f))
            me->CastSpell(seat, SPELL_RIDE_VEHICLE, true);

        if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
            if (Creature* seat = me->FindNearestCreature(NPC_CLIMB_PLAYER_1, 60.0f))
                player->CastSpell(seat, SPELL_RIDE_VEHICLE, true);
    }

    void PlantExplosives()
    {
        me->HandleEmoteCommand(EMOTE_ONESHOT_USE_STANDING);
        _scheduler.Schedule(2s, [this](TaskContext /*context*/)
        {
            // The crate prop (36758) has no +3.6M clone template yet; keep the
            // scene moving without it rather than aborting the quest event.
            if (sObjectMgr->GetCreatureTemplate(NPC_SHARPSHIV_EXPLOSIVES))
                for (Position const& pos : kExplosivesPos)
                    me->SummonCreature(NPC_SHARPSHIV_EXPLOSIVES, pos, TEMPSUMMON_TIMED_DESPAWN, 90000);

            Talk(2, ObjectAccessor::GetPlayer(*me, _playerGUID));
            _scheduler.Schedule(1500ms, [this](TaskContext /*context*/)
            {
                me->GetMotionMaster()->MoveJump(2875.285f, -4025.164f, 180.944f, 10.0f, 8.0f);
                _scheduler.Schedule(1s, [this](TaskContext /*context*/) { OfferPickup(); });
            });
        });
    }

    void OfferPickup()
    {
        me->SetDisableGravity(true);
        me->SetCanFly(true);
        Talk(3, ObjectAccessor::GetPlayer(*me, _playerGUID));
        me->SetNpcFlag(UNIT_NPC_FLAG_SPELLCLICK);

        // Nobody grabbed on: fold the scene up instead of hovering forever.
        _scheduler.Schedule(20s, GROUP_PICKUP_TIMEOUT, [this](TaskContext /*context*/)
        {
            me->DespawnOrUnsummon();
        });
    }

    // Resolve by GUID at fire time -- a stored Creature* would dangle if the
    // 30s hook summon expired first.
    void RetractHook(ObjectGuid guid)
    {
        if (Creature* hook = ObjectAccessor::GetCreature(*me, guid))
        {
            hook->RemoveAura(SPELL_ROPE_TOWER);
            hook->DespawnOrUnsummon();
        }
    }

    TaskScheduler _scheduler;
    ObjectGuid _playerGUID;
    ObjectGuid _hookPlayerGUID;
    ObjectGuid _hookSharpshivGUID;
    bool _reachedTop = false;
    bool _gliding = false;
};

class npc_slinky_sharpshiv : public CreatureScript
{
public:
    npc_slinky_sharpshiv() : CreatureScript("npc_slinky_sharpshiv") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (player->GetQuestStatus(QUEST_LIGHTNING_STRIKE_ASSASSINATION) == QUEST_STATUS_INCOMPLETE)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "I'm ready, Slinky. Let's do this.",
                GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
        else if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);

        if (action == GOSSIP_ACTION_INFO_DEF)
        {
            CloseGossipMenuFor(player);
            player->RemoveAura(SPELL_PLAYER_DISGUISE);
            player->SummonCreature(NPC_SLINKY_SHARPSHIV, creature->GetPositionX(), creature->GetPositionY(),
                creature->GetPositionZ(), creature->GetOrientation(), TEMPSUMMON_TIMED_DESPAWN, 300000);
        }

        return true;
    }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_slinky_sharpshivAI(creature);
    }
};

// ---------------------------------------------------------------------------
// Tower-scaling seats (3636716/18/20 for the player, 3636753/54/55 for
// Slinky) -- each seat throws its passenger to the next one up the tower;
// the top seats fling them onto the platform. One AI, switched by entry,
// exactly like the source's npc_climbing_slinky_player.
// ---------------------------------------------------------------------------
struct npc_tower_scaling_seat : public ScriptedAI
{
    npc_tower_scaling_seat(Creature* creature) : ScriptedAI(creature) { }

    void PassengerBoarded(Unit* passenger, int8 /*seatId*/, bool apply) override
    {
        if (!apply)
            return;

        _passengerGUID = passenger->GetGUID();

        switch (me->GetEntry())
        {
            case NPC_CLIMB_PLAYER_1:
                ScheduleHop(1500ms, NPC_CLIMB_PLAYER_2);
                break;
            case NPC_CLIMB_PLAYER_2:
                ScheduleHop(2800ms, NPC_CLIMB_PLAYER_3);
                break;
            case NPC_CLIMB_PLAYER_3:
                // Top of the rope: fling the player onto the platform.
                _scheduler.Schedule(1800ms, [this](TaskContext /*context*/)
                {
                    me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS, true);
                    if (Player* player = ObjectAccessor::GetPlayer(*me, _passengerGUID))
                        player->GetMotionMaster()->MoveJump(2865.802f, -4032.34f, 179.77f, 10.0f, 7.0f);
                });
                break;
            case NPC_CLIMB_SHARPSHIV_1:
                ScheduleHop(2500ms, NPC_CLIMB_SHARPSHIV_2);
                break;
            case NPC_CLIMB_SHARPSHIV_2:
                ScheduleHop(2800ms, NPC_CLIMB_SHARPSHIV_3);
                break;
            case NPC_CLIMB_SHARPSHIV_3:
                _scheduler.Schedule(1500ms, [this](TaskContext /*context*/)
                {
                    me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS, true);
                    if (Creature* slinky = ObjectAccessor::GetCreature(*me, _passengerGUID))
                    {
                        slinky->GetMotionMaster()->MoveJump(2871.547f, -4033.58f, 180.93f, 17.0f, 4.0f);
                        slinky->SetHomePosition(2870.0197f, -4030.549f, 179.778f, 1.5054f);
                        slinky->AI()->DoAction(ACTION_REMOVE_HOOK_EFFECT);
                    }
                });
                break;
            default:
                break;
        }
    }

    void UpdateAI(uint32 diff) override
    {
        _scheduler.Update(diff);
    }

private:
    void ScheduleHop(Milliseconds delay, uint32 nextSeatEntry)
    {
        _scheduler.Schedule(delay, [this, nextSeatEntry](TaskContext /*context*/)
        {
            me->CastSpell(me, SPELL_EJECT_ALL_PASSENGERS, true);
            // 200ms breather standing in for the source's CastWithDelay: the
            // passenger has to finish leaving this seat before mounting the next.
            _scheduler.Schedule(200ms, [this, nextSeatEntry](TaskContext /*context*/)
            {
                Unit* passenger = ObjectAccessor::GetUnit(*me, _passengerGUID);
                Creature* next = me->FindNearestCreature(nextSeatEntry, 30.0f);
                if (passenger && next)
                    passenger->CastSpell(next, SPELL_RIDE_VEHICLE, true);
            });
        });
    }

    TaskScheduler _scheduler;
    ObjectGuid _passengerGUID;
};

void AddSC_dc_azshara_cata()
{
    RegisterCreatureAI(npc_wings_of_steel_airplane);
    new npc_slinky_sharpshiv();
    RegisterCreatureAI(npc_tower_scaling_seat);
}
