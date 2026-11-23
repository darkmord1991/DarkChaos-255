/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
 * more details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Silverpine Forest on map 751: Agatha, the Val'kyr companion of 27097 "Rise, Forsaken", the
// Fenris Keep scene of 27099 "No Escape", and Sylvanas's ride of 27098 "Lordaeron".
//
// Ported from Project Neltharion's 4.3.4 zone_silverpine_forest.cpp, lines 1091-1927:
//   npc_agatha1_silverpine, spell_notify_agatha_isle, npc_no_escape_controller,
//   npc_fenris_no_escape_camera, npc_agatha_resummon_controller, npc_forsaken_sylv_horse,
//   spell_kill_me_sylvanas, spell_dreadguard_salute.
// Event, point, text group and data ids keep the source's numbers.
//
// Where this differs from the source, and why (all checked against this server's data):
//  1. Spells 83990 (Notify Agatha), 84180 (Kill Me ping), 84199 (Dreadguard Salute ping),
//     83996, 83998-84005, 84054-84061, 84094-84099 and 84128 are in no DBC here, and the
//     Neltharion-custom 151235/151316/151321 have no handler. Nothing casts them:
//       - spell_notify_agatha_isle (bound to 83990, which the refugees' SmartAI cast on death)
//         is a kill-credit hook that hands the corpse to the nearest Agatha. Agatha grants the
//         44953 credit 83993 -> 83996 gave and raises one of the Forsaken Troopers 83998-84005
//         summoned.
//       - spell_kill_me_sylvanas / spell_dreadguard_salute (bound to the missing triggered
//         spells of auras 84181/84200) are timers on Sylvanas's horse with the auras' periods
//         (3 s / 1 s) and the triggered spells' radii (40 / 12 yd).
//       - 84053's eight actor summons and 84094-84099's worgen transforms are done directly.
//       - 151316 (owner ping) is DoAction(151316), 151235 removes mount and shapeshift auras.
//  2. None of the source's vehicles (1070, 1075, 1076, 1077) is in Vehicle.dbc, and an unknown
//     VehicleId hangs the client. The templates use stock vehicles the client has:
//     532 (Val'kyr Shadowguard carry seat) for Agatha, 747 (Camera Vehicle, hidden passenger)
//     for the camera, 636 (Argent Warhorse) for both horses. Seat 0 everywhere.
//  3. The source parked the player's horse in seat 1 of Sylvanas's horse (vehicle 1077, seat
//     offset 2.5 yd to the side). Without that seat the player's horse runs the same path 2.5 yd
//     to the left, launched in the same tick at the same speed.
//  4. Map 751 has no Fenris Keep subzone (the source tested area 235), so it is a position test.
//  5. Source bugs not carried over: npc_no_escape_controller stayed "active" forever after an
//     aborted scene and fell through into its completion step when Agatha was gone; the
//     resummon controller never noticed an aura that survived a relog without its summon;
//     Agatha's 1 s check ran every tick; the horse never despawned if its rider logged out.
//
// Data this needs (pending SQL): the templates of every creature below (none existed),
// SummonProperties 3030 (spell 83982 cannot summon Agatha without it), the creature_text
// rows, and the two controller bunnies at their Neltharion positions.

#include "CellImpl.h"
#include "CreatureScript.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "GridNotifiers.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "PlayerScript.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellAuraDefines.h"
#include "SpellInfo.h"
#include "TaskScheduler.h"
#include "TemporarySummon.h"
#include "Vehicle.h"
#include "silverpine_dc.h"

#include <array>
#include <cmath>
#include <list>
#include <map>
#include <set>

namespace
{
    using SilverpineDC::Creature751;

    // Quests: the source's ids, not offset. None of the three is in quest_template yet.
    constexpr uint32 QUEST_RISE_FORSAKEN            = 27097;
    constexpr uint32 QUEST_LORDAERON                = 27098;
    constexpr uint32 QUEST_NO_ESCAPE                = 27099;

    // Spells this file casts; each one is in Spell.dbc or the spell_dbc overlay.
    constexpr uint32 SPELL_DUMMY_PING               = 98914;
    constexpr uint32 SPELL_DUMMY_PING_2             = 98915;
    constexpr uint32 SPELL_SANCTUARY_NO_COMBAT      = 88467;
    constexpr uint32 SPELL_SUMMON_AGATHA1_AURA      = 83982;
    constexpr uint32 SPELL_DOOMHOWL                 = 84012;
    constexpr uint32 SPELL_UNHOLY_DARKNESS          = 84013;
    constexpr uint32 SPELL_UNHOLY_SMITE             = 84014;
    constexpr uint32 SPELL_CAMERA_CHANNEL_BEAM      = 82557;
    constexpr uint32 SPELL_HEARTSTRIKE              = 84182;
    constexpr uint32 SPELL_INVISIBILITY_DETECTION_2 = 49417;

    // Spells that exist in no DBC here; their ids name the code that stands in for them.
    constexpr int32 DATA_NOTIFY_AGATHA              = 83990;   // SetGUID id: refugee corpse
    constexpr int32 ACTION_OWNER_PING_AGATHA        = 151316;  // DoAction on the owner's Agatha
    constexpr int32 ACTION_END_LORDAERON_TRIP       = 1;       // DoAction on a stale 45057 trip

    // Plain ids: summoned, never spawned (see the pending SQL).
    constexpr uint32 NPC_AGATHA_GUARDIAN            = 44951;   // spell 83982 summons it
    constexpr uint32 NPC_NO_ESCAPE_CAMERA           = 45003;
    constexpr uint32 NPC_NO_ESCAPE_CROWLEY          = 44989;
    constexpr uint32 NPC_NO_ESCAPE_IVAR             = 44990;
    constexpr uint32 NPC_NO_ESCAPE_PHIN             = 44993;
    constexpr uint32 NPC_NO_ESCAPE_BARTOLO          = 44994;
    constexpr uint32 NPC_NO_ESCAPE_DIBBS            = 44995;
    constexpr uint32 NPC_NO_ESCAPE_MALEB            = 44996;
    constexpr uint32 NPC_NO_ESCAPE_SMITHERS         = 44997;
    constexpr uint32 NPC_NO_ESCAPE_SOPHIA           = 45002;
    constexpr uint32 NPC_FORSAKEN_TROOPER_FIRST     = 44958;
    constexpr uint32 NPC_FORSAKEN_TROOPER_LAST      = 44961;   // 44962-44965 have no display here
    constexpr uint32 NPC_PLAYER_HORSE               = 45041;
    constexpr uint32 NPC_LADY_SYLV_HORSE            = 45057;
    constexpr uint32 NPC_LADY_SYLVANAS_2            = 45051;

    // Spawned on 751: cata entry + 4,100,000 (the bunnies are Neltharion's own 74951/74952).
    constexpr uint32 NPC_HILLSBRAD_REFUGEE_751      = Creature751(44966);
    constexpr uint32 NPC_HILLSBRAD_REFUGEE_2_751    = Creature751(44954);
    constexpr uint32 NPC_WORGEN_RENEGADE_751        = Creature751(44793);
    constexpr uint32 NPC_DREADGUARD_751             = Creature751(44911);
    constexpr uint32 NPC_NO_ESCAPE_CONTROLLER_751   = Creature751(74952);

    // Quest objectives as cata_world/nelt_world name them (RequiredNpcOrGo1 of 27097/27099/27098).
    constexpr uint32 CREDIT_HUMAN_TO_FORSAKEN       = 44953;
    constexpr uint32 CREDIT_NO_ESCAPE               = 44951;
    constexpr uint32 CREDIT_LORDAERON               = 45051;

    // EventMap ids, numbered as in the source's SilverpineEvents.
    constexpr uint32 EVENT_DOOMHOWL                 = 11;
    constexpr uint32 EVENT_UNHOLY_SMITE             = 12;
    constexpr uint32 EVENT_NO_ESCAPE_1              = 14;
    constexpr uint32 EVENT_NO_ESCAPE_2              = 15;
    constexpr uint32 EVENT_NO_ESCAPE_3              = 16;
    constexpr uint32 EVENT_NO_ESCAPE_4              = 17;
    constexpr uint32 EVENT_WARHORSE_1               = 18;
    constexpr uint32 EVENT_WARHORSE_2               = 19;
    constexpr uint32 EVENT_WARHORSE_3               = 20;
    constexpr uint32 EVENT_NO_ESCAPE_WATCHDOG       = 100;     // new: ends a stuck scene

    // Movement point ids.
    constexpr uint32 POINT_AGATHA_TO_CONTROLLER     = 1;
    constexpr uint32 NODE_AGATHA_EJECT              = 23;      // last node of AgathaNoEscapePath
    constexpr uint32 POINT_LORDAERON_END            = 1;
    constexpr uint32 NODE_SYLV_HORSE_LAST           = 27;      // last node of SylvHorsePath

    // creature_text groups.
    constexpr uint8 TALK_AGATHA_IDLE                = 0;
    constexpr uint8 TALK_AGATHA_THIS_WAY            = 1;
    constexpr uint8 TALK_AGATHA_RUN                 = 2;
    constexpr uint8 TALK_AGATHA_RUN_2               = 3;
    constexpr uint8 TALK_SYLVANAS_FINAL             = 21;

    // TaskScheduler groups.
    constexpr uint32 GROUP_SCENE                    = 1;
    constexpr uint32 GROUP_KILL_ME                  = 2;
    constexpr uint32 GROUP_SALUTE                   = 3;
    constexpr uint32 GROUP_RIDE_CHECK               = 4;

    constexpr float AGATHA_FOLLOW_DIST              = 2.0f;
    constexpr float AGATHA_FOLLOW_ANGLE             = 0.7f * float(M_PI);
    constexpr float AGATHA_CARRY_SPEED_RATE         = 3.5f;
    constexpr float NOTIFY_AGATHA_RANGE             = 50.0f;   // refugee SmartAI: closest 44951 in 50 yd
    constexpr float KILL_ME_RADIUS                  = 40.0f;   // 84180: SpellRadius 23
    constexpr float SALUTE_RADIUS                   = 12.0f;   // 84199: SpellRadius 32
    constexpr float PLAYER_HORSE_SIDE_OFFSET        = 2.5f;    // Cata seat 8464 sat 2.5 yd to the left
    constexpr float FENRIS_KEEP_RADIUS              = 32.0f;

    constexpr Milliseconds RESUMMON_RETRY           = 10s;
    constexpr Milliseconds NO_ESCAPE_WATCHDOG       = 120s;

    // Source lines 1091-1118. The +2.6 on the first 16 nodes is the source's own hover offset.
    constexpr uint32 AgathaNoEscapePathSize = 24;
    G3D::Vector3 const AgathaNoEscapePath[AgathaNoEscapePathSize] =
    {
        { 980.142f, 686.44f, 77.026f + 2.6f },  //  0
        { 978.839f, 688.57f, 74.899f + 2.6f },  //  1
        { 979.800f, 671.40f, 74.899f + 2.6f },  //  2
        { 997.688f, 674.17f, 69.796f + 2.6f },  //  3
        { 998.099f, 683.46f, 69.796f + 2.6f },  //  4
        { 1002.66f, 683.53f, 69.543f + 2.6f },  //  5
        { 1012.79f, 684.41f, 64.903f + 2.6f },  //  6
        { 1012.05f, 694.98f, 60.975f + 2.6f },  //  7
        { 998.619f, 694.52f, 60.975f + 2.6f },  //  8
        { 995.953f, 699.57f, 60.975f + 2.6f },  //  9
        { 994.989f, 709.86f, 60.975f + 2.6f },  // 10
        { 987.366f, 712.31f, 60.975f + 2.6f },  // 11
        { 982.776f, 709.00f, 60.975f + 2.6f },  // 12
        { 983.372f, 691.54f, 59.476f + 2.6f },  // 13
        { 980.052f, 688.45f, 59.476f + 2.6f },  // 14
        { 963.991f, 688.75f, 59.736f + 2.6f },  // 15
        { 934.429f, 688.41f, 71.090f },         // 16
        { 883.916f, 705.75f, 91.623f },         // 17
        { 860.442f, 779.96f, 85.433f },         // 18
        { 958.342f, 909.26f, 73.901f },         // 19
        { 1056.32f, 985.70f, 72.973f },         // 20
        { 1227.49f, 1008.6f, 76.016f },         // 21
        { 1334.76f, 1026.9f, 65.716f },         // 22
        { 1373.21f, 1039.0f, 54.685f },         // 23 eject at Forsaken High Command
    };

    // Source lines 1607-1640.
    constexpr uint32 SylvHorsePathSize = 28;
    G3D::Vector3 const SylvHorsePath[SylvHorsePathSize] =
    {
        { 1389.32f, 1023.86f, 53.131f },  //  0
        { 1368.86f, 1018.633f, 52.815f }, //  1
        { 1355.18f, 1018.536f, 52.317f }, //  2
        { 1345.47f, 1017.014f, 53.769f }, //  3
        { 1326.83f, 1012.754f, 54.600f }, //  4
        { 1315.39f, 1027.269f, 54.600f }, //  5
        { 1288.42f, 1068.989f, 53.618f }, //  6
        { 1267.22f, 1095.244f, 51.750f }, //  7
        { 1225.00f, 1130.903f, 50.475f }, //  8
        { 1168.57f, 1169.004f, 48.617f }, //  9
        { 1134.93f, 1191.119f, 47.752f }, // 10
        { 1063.47f, 1249.424f, 46.168f }, // 11
        { 1028.99f, 1281.528f, 45.980f }, // 12
        { 971.798f, 1315.444f, 45.871f }, // 13
        { 914.948f, 1349.042f, 48.216f }, // 14
        { 865.714f, 1360.332f, 54.587f }, // 15
        { 811.999f, 1360.771f, 57.923f }, // 16
        { 754.691f, 1362.252f, 68.465f }, // 17
        { 707.478f, 1342.741f, 76.237f }, // 18
        { 675.207f, 1313.741f, 80.521f }, // 19
        { 643.180f, 1304.041f, 85.101f }, // 20
        { 634.199f, 1315.209f, 83.845f }, // 21
        { 614.233f, 1347.160f, 86.220f }, // 22
        { 592.504f, 1393.575f, 91.655f }, // 23
        { 572.768f, 1431.194f, 99.283f }, // 24
        { 544.507f, 1461.334f, 108.42f }, // 25
        { 515.305f, 1488.362f, 121.52f }, // 26
        { 497.88f, 1527.338f, 129.450f }, // 27
    };

    Position const NoEscapeCameraPos   = { 992.546f, 691.757f, 74.889f, 0.039f };
    Position const FenrisKeepCenter    = { 995.0f, 692.0f, 70.0f, 0.0f };
    Position const SylvHorseSummonPos  = { 1381.7f, 1041.26f, 54.3171f, 4.02848f };  // 84128's target
    Position const SylvHorseFinalPos   = { 497.17f, 1554.972f, 128.703f, 0.0f };
    Position const LordaeronJumpPos    = { 497.77f, 1559.04f, 128.29f, 0.0f };

    // One entry per summon spell of 84053 (84054-84061, positions from spell_target_position).
    // WorgenDisplay is the display of the creature 84094-84099 transforms the actor into.
    struct NoEscapeActor
    {
        uint32 Entry;
        Position Pos;
        uint32 WorgenDisplay;
    };

    std::array<NoEscapeActor, 8> const NoEscapeActors =
    {{
        { NPC_NO_ESCAPE_IVAR,     { 994.53f,  687.74f,  74.8984f, 0.0f    }, 0     },  // 84054
        { NPC_NO_ESCAPE_CROWLEY,  { 994.562f, 691.186f, 74.8984f, 0.0f    }, 0     },  // 84055
        { NPC_NO_ESCAPE_PHIN,     { 1002.52f, 693.027f, 76.1922f, 3.1939f }, 34212 },  // 84056, 84094
        { NPC_NO_ESCAPE_BARTOLO,  { 1002.76f, 687.195f, 76.1922f, 3.1939f }, 34213 },  // 84057, 84095
        { NPC_NO_ESCAPE_DIBBS,    { 1002.8f,  684.256f, 76.1922f, 3.1939f }, 34215 },  // 84058, 84096
        { NPC_NO_ESCAPE_MALEB,    { 1000.67f, 689.759f, 76.1922f, 3.1939f }, 34216 },  // 84059, 84097
        { NPC_NO_ESCAPE_SMITHERS, { 1002.7f,  695.775f, 76.1922f, 3.1939f }, 34217 },  // 84060, 84098
        { NPC_NO_ESCAPE_SOPHIA,   { 1004.53f, 688.619f, 76.1922f, 3.1939f }, 34218 },  // 84061, 84099
    }};

    // Only 34217 of the six worgen displays is in CreatureDisplayInfo.dbc; the others fall back
    // to the Worgen Renegade displays the live 4144793 already uses.
    std::array<uint32, 4> const WorgenFallbackDisplays = { 34078, 34079, 34080, 34081 };

    // Crowley's timed action list 4498900 (nelt_world): delay after the previous step.
    struct SpeechLine
    {
        uint32 DelayMs;
        uint32 Speaker;
        uint8 Group;
    };

    std::array<SpeechLine, 8> const CrowleySpeech =
    {{
        { 2000, NPC_NO_ESCAPE_CROWLEY, 0 },
        { 5500, NPC_NO_ESCAPE_CROWLEY, 1 },
        { 3500, NPC_NO_ESCAPE_CROWLEY, 2 },
        { 4000, NPC_NO_ESCAPE_CROWLEY, 3 },
        { 5500, NPC_NO_ESCAPE_CROWLEY, 4 },
        { 6500, NPC_NO_ESCAPE_CROWLEY, 5 },
        { 8500, NPC_NO_ESCAPE_MALEB,   0 },
        { 8000, NPC_NO_ESCAPE_MALEB,   1 },
    }};
    constexpr uint32 CROWLEY_TRANSFORM_DELAY_MS = 5000;  // then the six cross-casts 84094-84099
    constexpr uint32 CROWLEY_PING_DELAY_MS      = 4000;  // then Crowley casts 98914 on the controller

    // Sylvanas's lines on the ride: path node -> text group, delay (source lines 1706-1776).
    struct RideLine
    {
        uint32 Node;
        uint8 Group;
        uint32 DelayMs;
    };

    std::array<RideLine, 21> const SylvanasRideLines =
    {{
        { 1, 0, 0 },     { 3, 1, 0 },     { 5, 2, 0 },     { 6, 3, 1000 },   { 7, 4, 1500 },
        { 8, 5, 2000 },  { 9, 6, 1000 },  { 10, 7, 2000 }, { 11, 8, 1500 },  { 12, 9, 2000 },
        { 13, 10, 1000 }, { 14, 11, 500 }, { 15, 12, 1000 }, { 16, 13, 100 }, { 17, 14, 1500 },
        { 19, 15, 1000 }, { 22, 16, 100 }, { 23, 17, 500 }, { 24, 18, 1000 }, { 25, 19, 1000 },
        { 27, 20, 100 },
    }};

    // The source's MoveSmoothPath overwrote node 0 with the unit's position and reported node k
    // on reaching it. DoMoveSmoothPath keeps every node it is given and reports the reached
    // node's index, so passing nodes 1..n-1 reproduces the source motion and the reported
    // ESCORT_MOTION_TYPE id is the source node minus one.
    void MoveSourceSmoothPath(Unit* unit, G3D::Vector3 const* path, uint32 size)
    {
        if (size > 1)
            SilverpineDC::DoMoveSmoothPath(unit, path + 1, size - 1);
    }

    // Point `dist` yards to the left of something at `pos` facing `orientation`.
    Position LeftOf(Position const& pos, float orientation, float dist)
    {
        float const angle = orientation + float(M_PI) / 2.0f;
        return Position(pos.GetPositionX() + std::cos(angle) * dist, pos.GetPositionY() + std::sin(angle) * dist,
            pos.GetPositionZ(), orientation);
    }

    // Node `index` of `path`, moved `dist` yards to the left of the direction of travel there.
    G3D::Vector3 LeftOfNode(G3D::Vector3 const* path, uint32 size, uint32 index, float dist)
    {
        G3D::Vector3 const& prev = path[index > 0 ? index - 1 : index];
        G3D::Vector3 const& next = path[index + 1 < size ? index + 1 : index];
        float const dx = next.x - prev.x;
        float const dy = next.y - prev.y;
        float const length = std::sqrt(dx * dx + dy * dy);
        if (length < 0.01f)
            return path[index];

        return G3D::Vector3(path[index].x - dy / length * dist, path[index].y + dx / length * dist, path[index].z);
    }

    // Stand-in for 151235 "Dismount and Cancel Shapeshifts" (a Neltharion SCRIPT_EFFECT).
    // The ride spell 46598 carries SPELL_ATTR0_NOT_SHAPESHIFT, so this has to run before boarding.
    void DismountAndCancelShapeshifts(Player* player)
    {
        player->RemoveAurasByType(SPELL_AURA_MOUNTED);
        player->RemoveAurasByType(SPELL_AURA_MOD_SHAPESHIFT);
    }

    // The player's own Agatha. Summon properties 3030 put her in the quest summon slot.
    Creature* GetOwnedAgatha(Player* player)
    {
        if (!player)
            return nullptr;

        ObjectGuid const guid = player->m_SummonSlot[SUMMON_SLOT_QUEST];
        if (guid.IsEmpty())
            return nullptr;

        Creature* agatha = ObjectAccessor::GetCreature(*player, guid);
        if (!agatha || agatha->GetEntry() != NPC_AGATHA_GUARDIAN || !agatha->IsAlive())
            return nullptr;

        return agatha;
    }

    // 4.3.4 WorldObject::GetPlayersInRange is gone; same shim as MountHyjal/zone_molten_front.cpp.
    std::list<Player*> GetPlayersInRange(WorldObject* who, float range)
    {
        std::list<Player*> players;
        Acore::AnyPlayerInObjectRangeCheck checker(who, range, true);
        Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck> searcher(who, players, checker);
        Cell::VisitObjects(who, searcher, range);
        return players;
    }

    bool PlayerNeedsAgatha(Player const* player)
    {
        QuestStatus const rise = player->GetQuestStatus(QUEST_RISE_FORSAKEN);
        QuestStatus const escape = player->GetQuestStatus(QUEST_NO_ESCAPE);

        if (rise == QUEST_STATUS_INCOMPLETE || rise == QUEST_STATUS_COMPLETE)
            return true;

        return rise == QUEST_STATUS_REWARDED && (escape == QUEST_STATUS_NONE || escape == QUEST_STATUS_INCOMPLETE);
    }
}

// Agatha (44951), the guardian spell 83982 summons for the owner of 27097. Follows the player,
// joins the player's fights, heals the player once at 35% health, and carries the player from
// Fenris Keep to Forsaken High Command at the end of 27099.
struct npc_agatha1_silverpine : public ScriptedAI
{
    npc_agatha1_silverpine(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(WorldObject* summoner) override
    {
        me->SetReactState(REACT_PASSIVE);

        Player* player = summoner ? summoner->ToPlayer() : nullptr;
        if (!player)
            return;

        _playerGUID = player->GetGUID();
        me->GetMotionMaster()->MoveFollow(player, AGATHA_FOLLOW_DIST, AGATHA_FOLLOW_ANGLE);

        _scheduler.Schedule(1s, [this](TaskContext context)
        {
            CheckOwner();
            context.Repeat();
        });

        _scheduler.Schedule(28s, [this](TaskContext context)
        {
            if (!IsCarrying() && me->GetExactDist2d(&FenrisKeepCenter) > FENRIS_KEEP_RADIUS)
                if (Player* player = GetPlayer())
                    Talk(TALK_AGATHA_IDLE, player);

            context.Repeat(95s);
        });
    }

    void DamageTaken(Unit* attacker, uint32& /*damage*/, DamageEffectType /*damagetype*/,
        SpellSchoolMask /*damageSchoolMask*/) override
    {
        Unit* owner = me->GetOwner();
        if (attacker && attacker != me && owner && !owner->GetVictim() && !IsCarrying())
            AttackStart(attacker);
    }

    void SpellHit(Unit* /*caster*/, SpellInfo const* spellInfo) override
    {
        if (spellInfo->Id == SPELL_DUMMY_PING)
            if (Player* player = GetPlayer())
                Talk(TALK_AGATHA_THIS_WAY, player);
    }

    // 151316 in the source: the owner leaves the Fenris Keep camera and rides Agatha 1 s later.
    void DoAction(int32 action) override
    {
        if (action != ACTION_OWNER_PING_AGATHA)
            return;

        Player* player = GetPlayer();
        if (!player)
            return;

        player->ExitVehicle();
        me->GetMotionMaster()->Clear();

        _scheduler.Schedule(1s, [this](TaskContext /*context*/)
        {
            if (Player* player = GetPlayer())
            {
                DismountAndCancelShapeshifts(player);
                player->EnterVehicle(me, 0);
            }
        });
    }

    // spell_notify_agatha_isle: a Hillsbrad Refugee died within 50 yd of this Agatha.
    void SetGUID(ObjectGuid const& guid, int32 id) override
    {
        if (id != DATA_NOTIFY_AGATHA)
            return;

        Creature* refugee = ObjectAccessor::GetCreature(*me, guid);
        if (!refugee || refugee->IsAlive())
            return;

        // 83993 Raise Forsaken -> 83996 (KILL_CREDIT2, target: Agatha's master).
        if (Player* player = GetPlayer())
            player->RewardPlayerAndGroupAtEvent(CREDIT_HUMAN_TO_FORSAKEN, refugee);

        me->SetFacingToObject(refugee);
        me->HandleEmoteCommand(EMOTE_ONESHOT_SPELL_CAST_OMNI);

        // 2 s later the corpse casts one of 83998-84005: a Forsaken Trooper rises in its place.
        Position const corpsePos = refugee->GetPosition();
        _scheduler.Schedule(2s, [this, guid, corpsePos](TaskContext /*context*/)
        {
            if (Creature* corpse = ObjectAccessor::GetCreature(*me, guid))
            {
                if (corpse->IsAlive())
                    return;

                corpse->DespawnOrUnsummon();
            }

            uint32 const entry = urand(NPC_FORSAKEN_TROOPER_FIRST, NPC_FORSAKEN_TROOPER_LAST);
            if (Creature* trooper = me->SummonCreature(entry, corpsePos, TEMPSUMMON_TIMED_DESPAWN, 3000))
            {
                trooper->SetReactState(REACT_PASSIVE);
                trooper->SetFacingToObject(me);
            }
        });
    }

    void PassengerBoarded(Unit* passenger, int8 /*seatId*/, bool apply) override
    {
        if (!passenger || !passenger->IsPlayer())
            return;

        if (apply)
        {
            _savedRunRate = me->GetSpeedRate(MOVE_RUN);
            _savedFlightRate = me->GetSpeedRate(MOVE_FLIGHT);
            me->SetSpeed(MOVE_FLIGHT, AGATHA_CARRY_SPEED_RATE);
            me->SetSpeed(MOVE_RUN, AGATHA_CARRY_SPEED_RATE);
            Talk(TALK_AGATHA_RUN_2, passenger, 1s);
            // She starts on the Fenris Keep floor (hovering): flag the spline as a flight, as
            // Neltharion's MoveSmoothPath did for a unit that CanFly().
            me->SetDisableGravity(true);
            MoveSourceSmoothPath(me, AgathaNoEscapePath, AgathaNoEscapePathSize);
            me->SetImmuneToAll(true);
            return;
        }

        // Creature::UpdateMovementFlags drops the flight flag again once she is near the ground.
        me->SetImmuneToAll(false);
        me->SetSpeed(MOVE_RUN, _savedRunRate);
        me->SetSpeed(MOVE_FLIGHT, _savedFlightRate);
        if (Player* player = GetPlayer())
            me->GetMotionMaster()->MoveFollow(player, AGATHA_FOLLOW_DIST, AGATHA_FOLLOW_ANGLE);
    }

    void MovementInform(uint32 type, uint32 id) override
    {
        if (type != ESCORT_MOTION_TYPE || id + 1 != NODE_AGATHA_EJECT)
            return;

        if (Vehicle* kit = me->GetVehicleKit())
            kit->RemoveAllPassengers();

        me->SetImmuneToAll(false);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        if (me->GetReactState() == REACT_AGGRESSIVE && me->IsInCombat())
            ScheduleCombatEvents();
        else
            _events.Reset();
    }

    void UpdateAI(uint32 diff) override
    {
        _scheduler.Update(diff);

        if (!UpdateVictim())
            return;

        if (Player* player = GetPlayer())
        {
            if (player->GetHealthPct() <= 35.0f && !_lowHP)
            {
                _events.Reset();
                DoCast(player, SPELL_UNHOLY_DARKNESS);
                _lowHP = true;
                // The source never rescheduled the two attacks after this reset.
                ScheduleCombatEvents();
            }

            if (player->GetHealthPct() >= 36.0f && _lowHP)
                _lowHP = false;
        }

        _events.Update(diff);

        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        while (uint32 eventId = _events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_DOOMHOWL:
                    DoCastVictim(SPELL_DOOMHOWL);
                    _events.ScheduleEvent(EVENT_DOOMHOWL, 22s, 35s);
                    break;
                case EVENT_UNHOLY_SMITE:
                    DoCastVictim(SPELL_UNHOLY_SMITE);
                    _events.ScheduleEvent(EVENT_UNHOLY_SMITE, 3s, 7s);
                    break;
                default:
                    break;
            }
        }

        DoMeleeAttackIfReady();
    }

private:
    Player* GetPlayer() const
    {
        return ObjectAccessor::GetPlayer(*me, _playerGUID);
    }

    bool IsCarrying() const
    {
        Vehicle* kit = me->GetVehicleKit();
        return kit && kit->IsVehicleInUse();
    }

    void ScheduleCombatEvents()
    {
        _events.ScheduleEvent(EVENT_DOOMHOWL, 4s, 8s);
        _events.ScheduleEvent(EVENT_UNHOLY_SMITE, 1s, 4s);
    }

    void CheckOwner()
    {
        Player* player = GetPlayer();
        Unit* owner = me->GetOwner();
        if (!player || !owner || !owner->IsAlive())
        {
            me->DespawnOrUnsummon();
            return;
        }

        if (me->GetMapId() != SilverpineDC::MAP_LORDAERON_751 || me->GetZoneId() != SilverpineDC::ZONE_SILVERPINE_751)
        {
            me->DespawnOrUnsummon();
            return;
        }

        if (player->GetQuestStatus(QUEST_RISE_FORSAKEN) == QUEST_STATUS_NONE
            || player->GetQuestStatus(QUEST_NO_ESCAPE) == QUEST_STATUS_REWARDED)
        {
            me->DespawnOrUnsummon();
            return;
        }

        if (IsCarrying())
            return;

        if (!me->GetVictim() && me->GetReactState() != REACT_AGGRESSIVE && player->GetVictim() && player->IsInCombat())
        {
            me->SetReactState(REACT_AGGRESSIVE);
            AttackStart(player->GetVictim());
        }

        if (me->GetReactState() != REACT_PASSIVE && !player->GetVictim() && !player->IsInCombat())
        {
            me->SetReactState(REACT_PASSIVE);
            DoCastSelf(SPELL_SANCTUARY_NO_COMBAT, true);
            me->RemoveUnitFlag(UNIT_FLAG_PET_IN_COMBAT);
            me->GetMotionMaster()->MoveFollow(player, AGATHA_FOLLOW_DIST, AGATHA_FOLLOW_ANGLE);
        }
    }

    ObjectGuid _playerGUID;
    EventMap _events;
    TaskScheduler _scheduler;
    bool _lowHP = false;
    float _savedRunRate = 1.0f;
    float _savedFlightRate = 1.0f;
};

// Neltharion bunny 74951, spawned here as 4174951 at its five positions on Fenris Isle and at
// Forsaken High Command: re-summons Agatha for a player who should have her and does not.
struct npc_agatha_resummon_controller : public ScriptedAI
{
    npc_agatha_resummon_controller(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        me->SetReactState(REACT_PASSIVE);
    }

    void MoveInLineOfSight(Unit* who) override
    {
        Player* player = who ? who->ToPlayer() : nullptr;
        if (!player || !player->IsAlive() || player->GetVehicle() || !me->IsWithinDistInMap(player, 35.0f))
            return;

        if (!PlayerNeedsAgatha(player))
            return;

        // The aura outlives a relog, the guardian does not: the source only checked the aura.
        bool const hasAura = player->HasAura(SPELL_SUMMON_AGATHA1_AURA);
        if (hasAura && GetOwnedAgatha(player))
            return;

        Milliseconds const now = GameTime::GetGameTimeMS();
        auto itr = _lastAttempt.find(player->GetGUID());
        if (itr != _lastAttempt.end() && now - itr->second < RESUMMON_RETRY)
            return;

        _lastAttempt[player->GetGUID()] = now;

        if (hasAura)
            player->RemoveAurasDueToSpell(SPELL_SUMMON_AGATHA1_AURA);

        player->CastSpell(player, SPELL_SUMMON_AGATHA1_AURA, true);
    }

    void UpdateAI(uint32 /*diff*/) override { }

private:
    std::map<ObjectGuid, Milliseconds> _lastAttempt;
};

// Neltharion bunny 74952, spawned here as 4174952 on the top floor of Fenris Keep. A player on
// 27099 with Agatha walks in: the Fenris Keep humans and the worgen leaders appear, the player
// watches from the camera, Crowley offers the choice, the humans turn worgen, Agatha flies off.
struct npc_no_escape_controller : public ScriptedAI
{
    npc_no_escape_controller(Creature* creature) : ScriptedAI(creature), _summons(me) { }

    void Reset() override
    {
        me->SetReactState(REACT_PASSIVE);
    }

    void JustSummoned(Creature* summon) override
    {
        _summons.Summon(summon);
    }

    void MoveInLineOfSight(Unit* who) override
    {
        Player* player = who ? who->ToPlayer() : nullptr;
        if (!player || _cutsceneInProgress || _active)
            return;

        if (!me->IsWithinDistInMap(player, 12.0f) || player->IsInCombat() || player->GetVehicle())
            return;

        if (player->GetQuestStatus(QUEST_NO_ESCAPE) != QUEST_STATUS_INCOMPLETE
            || !player->HasAura(SPELL_SUMMON_AGATHA1_AURA))
            return;

        // The source took the nearest 44951 within 25 yd, whoever owned it.
        Creature* agatha = GetOwnedAgatha(player);
        if (!agatha || !me->IsWithinDistInMap(agatha, 25.0f))
            return;

        _playerGUID = player->GetGUID();
        _agathaGUID = agatha->GetGUID();
        _active = true;
        _cutsceneInProgress = true;
        _speechStarted = false;
        _events.ScheduleEvent(EVENT_NO_ESCAPE_1, 2s);
        _events.ScheduleEvent(EVENT_NO_ESCAPE_WATCHDOG, NO_ESCAPE_WATCHDOG);
    }

    void SpellHit(Unit* /*caster*/, SpellInfo const* spellInfo) override
    {
        // Crowley's last action: the speech is over.
        if (spellInfo->Id == SPELL_DUMMY_PING)
            OnCrowleyPing();

        // The camera lost its passenger: leave the cinematic.
        if (spellInfo->Id == SPELL_DUMMY_PING_2 && _cutsceneInProgress)
            EndScene();
    }

    // The camera has its passenger (the source pinged Crowley, whose SmartAI ran list 4498900).
    void DoAction(int32 action) override
    {
        if (action != int32(SPELL_DUMMY_PING) || !_cutsceneInProgress || _speechStarted)
            return;

        _speechStarted = true;

        uint32 at = 0;
        for (SpeechLine const& line : CrowleySpeech)
        {
            at += line.DelayMs;
            _scheduler.Schedule(Milliseconds(at), GROUP_SCENE, [this, line](TaskContext /*context*/)
            {
                if (Creature* speaker = GetActor(line.Speaker))
                    speaker->AI()->Talk(line.Group);
            });
        }

        at += CROWLEY_TRANSFORM_DELAY_MS;
        _scheduler.Schedule(Milliseconds(at), GROUP_SCENE, [this](TaskContext /*context*/)
        {
            TransformActors();
        });

        at += CROWLEY_PING_DELAY_MS;
        _scheduler.Schedule(Milliseconds(at), GROUP_SCENE, [this](TaskContext /*context*/)
        {
            if (Creature* crowley = GetActor(NPC_NO_ESCAPE_CROWLEY))
                crowley->CastSpell(me, SPELL_DUMMY_PING, true);
            else
                OnCrowleyPing();
        });
    }

    void UpdateAI(uint32 diff) override
    {
        _scheduler.Update(diff);
        _events.Update(diff);

        while (uint32 eventId = _events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_NO_ESCAPE_1:
                    SummonActors();
                    _events.ScheduleEvent(EVENT_NO_ESCAPE_2, 2s);
                    break;
                case EVENT_NO_ESCAPE_2:
                    StartScene();
                    break;
                case EVENT_NO_ESCAPE_3:
                    CompleteScene();
                    break;
                case EVENT_NO_ESCAPE_4:
                    _summons.DespawnAll();
                    _events.CancelEvent(EVENT_NO_ESCAPE_WATCHDOG);
                    _active = false;
                    break;
                case EVENT_NO_ESCAPE_WATCHDOG:
                    EndScene();
                    break;
                default:
                    break;
            }
        }
    }

private:
    Creature* GetActor(uint32 entry) const
    {
        for (std::size_t i = 0; i < NoEscapeActors.size(); ++i)
            if (NoEscapeActors[i].Entry == entry)
                return ObjectAccessor::GetCreature(*me, _actors[i]);

        return nullptr;
    }

    // 84053 "Summon Fenris Actors" -> 84054-84061.
    void SummonActors()
    {
        for (std::size_t i = 0; i < NoEscapeActors.size(); ++i)
        {
            _actors[i].Clear();
            if (Creature* actor = me->SummonCreature(NoEscapeActors[i].Entry, NoEscapeActors[i].Pos,
                TEMPSUMMON_MANUAL_DESPAWN))
            {
                actor->SetReactState(REACT_PASSIVE);
                actor->SetImmuneToAll(true);
                _actors[i] = actor->GetGUID();
            }
        }
    }

    // 84094-84099: the Fenris Keep humans take Crowley's offer.
    void TransformActors()
    {
        std::size_t fallback = 0;
        for (std::size_t i = 0; i < NoEscapeActors.size(); ++i)
        {
            uint32 display = NoEscapeActors[i].WorgenDisplay;
            if (!display)
                continue;

            Creature* actor = ObjectAccessor::GetCreature(*me, _actors[i]);
            if (!actor)
                continue;

            if (!sCreatureDisplayInfoStore.LookupEntry(display))
                display = WorgenFallbackDisplays[fallback++ % WorgenFallbackDisplays.size()];

            actor->SetDisplayId(display);
        }
    }

    void StartScene()
    {
        Creature* agatha = ObjectAccessor::GetCreature(*me, _agathaGUID);
        Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
        if (!agatha || !player)
        {
            EndScene();
            return;
        }

        me->CastSpell(agatha, SPELL_DUMMY_PING, true);
        agatha->GetMotionMaster()->MovePoint(POINT_AGATHA_TO_CONTROLLER, me->GetPositionX(), me->GetPositionY(),
            me->GetPositionZ());

        TempSummon* camera = player->SummonCreature(NPC_NO_ESCAPE_CAMERA, NoEscapeCameraPos, TEMPSUMMON_MANUAL_DESPAWN);
        if (camera)
        {
            DismountAndCancelShapeshifts(player);
            _cameraGUID = camera->GetGUID();
            _scheduler.Schedule(100ms, GROUP_SCENE, [this](TaskContext /*context*/)
            {
                Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
                Creature* camera = ObjectAccessor::GetCreature(*me, _cameraGUID);
                if (player && camera)
                    player->EnterVehicle(camera, 0);
            });
        }
    }

    void OnCrowleyPing()
    {
        Creature* camera = me->FindNearestCreature(NPC_NO_ESCAPE_CAMERA, 40.0f);
        Creature* agatha = ObjectAccessor::GetCreature(*me, _agathaGUID);
        if (!camera || !agatha)
            return;

        camera->SetFacingToObject(me);
        agatha->SetFacingTo(0.046f);
        agatha->AI()->Talk(TALK_AGATHA_RUN, 1s);
        _events.ScheduleEvent(EVENT_NO_ESCAPE_3, 3s);
    }

    void CompleteScene()
    {
        _cutsceneInProgress = false;

        Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
        Creature* camera = me->FindNearestCreature(NPC_NO_ESCAPE_CAMERA, 40.0f);
        if (player && camera)
        {
            NoEscapeCompletion();
            if (Vehicle* kit = camera->GetVehicleKit())
                kit->RemoveAllPassengers();

            camera->DespawnOrUnsummon();
        }

        _events.ScheduleEvent(EVENT_NO_ESCAPE_4, 3s);
    }

    void NoEscapeCompletion()
    {
        for (Player* player : GetPlayersInRange(me, 40.0f))
        {
            if (player->GetQuestStatus(QUEST_NO_ESCAPE) != QUEST_STATUS_INCOMPLETE
                || !player->HasAura(SPELL_SUMMON_AGATHA1_AURA))
                continue;

            player->KilledMonsterCredit(CREDIT_NO_ESCAPE);
            if (Creature* agatha = GetOwnedAgatha(player))
                agatha->AI()->DoAction(ACTION_OWNER_PING_AGATHA);
        }
    }

    void EndScene()
    {
        _summons.DespawnAll();
        _events.Reset();
        _scheduler.CancelAll();

        if (Creature* camera = ObjectAccessor::GetCreature(*me, _cameraGUID))
        {
            if (Vehicle* kit = camera->GetVehicleKit())
                kit->RemoveAllPassengers();

            camera->DespawnOrUnsummon();
        }

        _cutsceneInProgress = false;
        _speechStarted = false;
        _active = false;
    }

    SummonList _summons;
    EventMap _events;
    TaskScheduler _scheduler;
    std::array<ObjectGuid, 8> _actors;
    ObjectGuid _playerGUID;
    ObjectGuid _agathaGUID;
    ObjectGuid _cameraGUID;
    bool _active = false;
    bool _cutsceneInProgress = false;
    bool _speechStarted = false;
};

// Fenris Keep Camera (45003), summoned by the player and ridden (hidden) during the scene.
struct npc_fenris_no_escape_camera : public ScriptedAI
{
    npc_fenris_no_escape_camera(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        me->SetReactState(REACT_PASSIVE);
    }

    // The source also cast 80808 "Cosmetic - Alpha State 0%" on the player. Its only effect here
    // is a dummy aura; seat 7727 of vehicle 747 hides the passenger instead.
    void IsSummonedBy(WorldObject* summoner) override
    {
        if (Player* player = summoner ? summoner->ToPlayer() : nullptr)
            _playerGUID = player->GetGUID();
    }

    void PassengerBoarded(Unit* passenger, int8 /*seatId*/, bool apply) override
    {
        if (!passenger || !passenger->IsPlayer())
            return;

        if (apply)
        {
            _rpInProgress = true;
            if (Creature* controller = me->FindNearestCreature(NPC_NO_ESCAPE_CONTROLLER_751, 25.0f))
                controller->AI()->DoAction(int32(SPELL_DUMMY_PING));

            return;
        }

        if (!_rpInProgress)
            return;

        me->DespawnOrUnsummon(100ms);
        if (Creature* controller = me->FindNearestCreature(NPC_NO_ESCAPE_CONTROLLER_751, 20.0f))
            controller->CastSpell(controller, SPELL_DUMMY_PING_2, true);
    }

    void SpellHit(Unit* /*caster*/, SpellInfo const* spellInfo) override
    {
        if (spellInfo->Id != SPELL_DUMMY_PING_2)
            return;

        Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID);
        if (!player)
            return;

        _rpInProgress = false;
        player->CastSpell(me, SPELL_CAMERA_CHANNEL_BEAM, true);
        _scheduler.Schedule(3s, [this](TaskContext /*context*/)
        {
            if (Vehicle* kit = me->GetVehicleKit())
                kit->RemoveAllPassengers();
        });
    }

    void UpdateAI(uint32 diff) override
    {
        _scheduler.Update(diff);
    }

private:
    TaskScheduler _scheduler;
    ObjectGuid _playerGUID;
    bool _rpInProgress = false;
};

// Sylvanas's Forsaken Warhorse (45057) for 27098 "Lordaeron": Sylvanas rides it, the player rides
// a second horse beside her, and she tells the story of Lordaeron on the way north.
struct npc_forsaken_sylv_horse : public ScriptedAI
{
    npc_forsaken_sylv_horse(Creature* creature) : ScriptedAI(creature), _summons(me) { }

    void IsSummonedBy(WorldObject* summoner) override
    {
        me->SetReactState(REACT_PASSIVE);

        Player* player = summoner ? summoner->ToPlayer() : nullptr;
        if (!player)
            return;

        player->RemoveAurasDueToSpell(SPELL_INVISIBILITY_DETECTION_2);
        _summons.Summon(me);
        me->SetDisableGravity(false);
        me->SetCanFly(false);

        player->ExitVehicle();
        _playerGUID = player->GetGUID();

        if (Creature* sylvanas = me->SummonCreature(NPC_LADY_SYLVANAS_2, me->GetPosition(), TEMPSUMMON_MANUAL_DESPAWN))
        {
            sylvanas->SetReactState(REACT_PASSIVE);
            sylvanas->EnterVehicle(me, 0);
            _sylvanasGUID = sylvanas->GetGUID();
            _summons.Summon(sylvanas);
        }

        Position const horsePos = LeftOf(me->GetPosition(), me->GetOrientation(), PLAYER_HORSE_SIDE_OFFSET);
        if (Creature* playerHorse = player->SummonCreature(NPC_PLAYER_HORSE, horsePos, TEMPSUMMON_MANUAL_DESPAWN))
        {
            playerHorse->SetReactState(REACT_PASSIVE);
            _summons.Summon(playerHorse);
            _playerHorseGUID = playerHorse->GetGUID();
            DismountAndCancelShapeshifts(player);

            _scheduler.Schedule(500ms, [this](TaskContext /*context*/)
            {
                Player* player = GetPlayer();
                Creature* playerHorse = ObjectAccessor::GetCreature(*me, _playerHorseGUID);
                if (!player || !playerHorse)
                {
                    _summons.DespawnAll();
                    return;
                }

                player->EnterVehicle(playerHorse, 0);
                _events.ScheduleEvent(EVENT_WARHORSE_1, 1s);
            });
        }

        // The source waited forever for a rider who never boarded.
        _scheduler.Schedule(15s, [this](TaskContext /*context*/)
        {
            if (!_tripInProgress)
                _summons.DespawnAll();
        });
    }

    void MovementInform(uint32 type, uint32 id) override
    {
        if (type == ESCORT_MOTION_TYPE)
            PathNodeReached(id + 1);
        else if (type == POINT_MOTION_TYPE && id == POINT_LORDAERON_END)
            FinishRide();
    }

    void DoAction(int32 action) override
    {
        if (action != ACTION_END_LORDAERON_TRIP)
            return;

        _tripInProgress = false;
        _scheduler.CancelAll();
        _events.Reset();
        _summons.DespawnAll();
    }

    void UpdateAI(uint32 diff) override
    {
        _scheduler.Update(diff);
        _events.Update(diff);

        while (uint32 eventId = _events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_WARHORSE_1:
                    _tripInProgress = true;
                    _events.ScheduleEvent(EVENT_WARHORSE_2, 2s);
                    _scheduler.Schedule(1s, GROUP_RIDE_CHECK, [this](TaskContext context)
                    {
                        if (CheckRider())
                            context.Repeat();
                    });
                    break;
                case EVENT_WARHORSE_2:
                    StartRide();
                    break;
                case EVENT_WARHORSE_3:
                    WalkToTheEnd();
                    break;
                default:
                    break;
            }
        }
    }

private:
    Player* GetPlayer() const
    {
        return ObjectAccessor::GetPlayer(*me, _playerGUID);
    }

    bool IsRiderAboard() const
    {
        Player* player = GetPlayer();
        return player && _playerHorseGUID && player->GetVehicleBase()
            && player->GetVehicleBase()->GetGUID() == _playerHorseGUID
            && player->GetQuestStatus(QUEST_LORDAERON) == QUEST_STATUS_INCOMPLETE;
    }

    // The trip ends when the player leaves THIS trip's horse (or the world) or drops the quest.
    bool CheckRider()
    {
        if (!_tripInProgress)
            return false;

        if (IsRiderAboard())
            return true;

        _tripInProgress = false;
        _summons.DespawnAll();
        return false;
    }

    void StartRide()
    {
        MoveSourceSmoothPath(me, SylvHorsePath, SylvHorsePathSize);

        Creature* playerHorse = ObjectAccessor::GetCreature(*me, _playerHorseGUID);
        if (!playerHorse)
            return;

        std::array<G3D::Vector3, SylvHorsePathSize> beside;
        for (uint32 i = 0; i < SylvHorsePathSize; ++i)
            beside[i] = LeftOfNode(SylvHorsePath, SylvHorsePathSize, i, PLAYER_HORSE_SIDE_OFFSET);

        MoveSourceSmoothPath(playerHorse, beside.data(), SylvHorsePathSize);
    }

    void PathNodeReached(uint32 node)
    {
        Player* player = GetPlayer();
        Creature* sylvanas = ObjectAccessor::GetCreature(*me, _sylvanasGUID);
        if (!player || !sylvanas)
            return;

        switch (node)
        {
            case 1:
                StartKillMe();
                break;
            case 19:
                _scheduler.CancelGroup(GROUP_KILL_ME);
                StartDreadguardSalute();
                break;
            case 25:
                _scheduler.CancelGroup(GROUP_SALUTE);
                break;
            case NODE_SYLV_HORSE_LAST:
                _events.ScheduleEvent(EVENT_WARHORSE_3, 1s);
                break;
            default:
                break;
        }

        for (RideLine const& line : SylvanasRideLines)
            if (line.Node == node)
                sylvanas->AI()->Talk(line.Group, player, Milliseconds(line.DelayMs));
    }

    // spell_kill_me_sylvanas: aura 84181 pinged every 3 s (84180, 40 yd, Worgen Renegades) and
    // Sylvanas answered each hit with Heartstrike.
    void StartKillMe()
    {
        _scheduler.Schedule(3s, GROUP_KILL_ME, [this](TaskContext context)
        {
            if (Creature* sylvanas = ObjectAccessor::GetCreature(*me, _sylvanasGUID))
            {
                std::list<Creature*> worgen;
                sylvanas->GetCreatureListWithEntryInGrid(worgen, NPC_WORGEN_RENEGADE_751, KILL_ME_RADIUS);
                for (Creature* target : worgen)
                    if (target->IsAlive())
                        sylvanas->CastSpell(target, SPELL_HEARTSTRIKE, true);
            }

            context.Repeat();
        });
    }

    // spell_dreadguard_salute: aura 84200 pinged every 1 s (84199, 12 yd, Dreadguards); each
    // Dreadguard saluted once (151321 was the emote cooldown).
    void StartDreadguardSalute()
    {
        _scheduler.Schedule(1s, GROUP_SALUTE, [this](TaskContext context)
        {
            if (Creature* sylvanas = ObjectAccessor::GetCreature(*me, _sylvanasGUID))
            {
                std::list<Creature*> guards;
                sylvanas->GetCreatureListWithEntryInGrid(guards, NPC_DREADGUARD_751, SALUTE_RADIUS);
                for (Creature* guard : guards)
                    if (guard->IsAlive() && !guard->IsInCombat() && _saluted.insert(guard->GetGUID()).second)
                        guard->HandleEmoteCommand(EMOTE_ONESHOT_SALUTE);
            }

            context.Repeat();
        });
    }

    void WalkToTheEnd()
    {
        G3D::Vector3 const& last = SylvHorsePath[NODE_SYLV_HORSE_LAST];
        float const endX = SylvHorseFinalPos.GetPositionX();
        float const endY = SylvHorseFinalPos.GetPositionY();
        float const endZ = SylvHorseFinalPos.GetPositionZ();
        float const heading = std::atan2(endY - last.y, endX - last.x);

        // The source walked here without a generated path (MovePoint(..., false)).
        me->SetWalk(true);
        me->GetMotionMaster()->MovePoint(POINT_LORDAERON_END, endX, endY, endZ, FORCED_MOVEMENT_WALK, 0.0f, 0.0f,
            false);

        if (Creature* playerHorse = ObjectAccessor::GetCreature(*me, _playerHorseGUID))
        {
            Position const beside = LeftOf(SylvHorseFinalPos, heading, PLAYER_HORSE_SIDE_OFFSET);
            playerHorse->SetWalk(true);
            playerHorse->GetMotionMaster()->MovePoint(0, beside.GetPositionX(), beside.GetPositionY(),
                beside.GetPositionZ(), FORCED_MOVEMENT_WALK, 0.0f, 0.0f, false);
        }

        if (Creature* sylvanas = ObjectAccessor::GetCreature(*me, _sylvanasGUID))
            sylvanas->AI()->Talk(TALK_SYLVANAS_FINAL, GetPlayer(), 4s);
    }

    void FinishRide()
    {
        Player* player = GetPlayer();
        Creature* playerHorse = ObjectAccessor::GetCreature(*me, _playerHorseGUID);

        // Credit and the jump only for a rider still on this trip's horse.
        bool const aboard = IsRiderAboard();

        _tripInProgress = false;
        _scheduler.CancelAll();

        if (aboard && player && playerHorse)
        {
            player->KilledMonsterCredit(CREDIT_LORDAERON);
            if (Vehicle* kit = playerHorse->GetVehicleKit())
                kit->RemoveAllPassengers();

            // The source also cast 93425 'Update Zone Auras', which has no effect on this core.
            player->GetMotionMaster()->MoveJump(LordaeronJumpPos, 10.0f, 12.0f);
        }

        _summons.DespawnAll();
    }

    SummonList _summons;
    EventMap _events;
    TaskScheduler _scheduler;
    std::set<ObjectGuid> _saluted;
    ObjectGuid _playerGUID;
    ObjectGuid _playerHorseGUID;
    ObjectGuid _sylvanasGUID;
    bool _tripInProgress = false;
};

// The two triggers that were spells in the source.
class dc_silverpine_fenris_isle_player : public PlayerScript
{
public:
    dc_silverpine_fenris_isle_player() : PlayerScript("dc_silverpine_fenris_isle_player",
        { PLAYERHOOK_ON_CREATURE_KILL_CREDIT, PLAYERHOOK_ON_PLAYER_QUEST_ACCEPT }) { }

    // spell_notify_agatha_isle: the refugees' SmartAI cast 83990 at the closest Agatha within
    // 50 yd on death. 83990 is in no DBC, so the kill credit hook does the hand-over.
    void OnPlayerCreatureKillCredit(Player* /*player*/, Creature* killed) override
    {
        if (!killed || killed->GetMapId() != SilverpineDC::MAP_LORDAERON_751)
            return;

        uint32 const entry = killed->GetEntry();
        if (entry != NPC_HILLSBRAD_REFUGEE_751 && entry != NPC_HILLSBRAD_REFUGEE_2_751)
            return;

        if (Creature* agatha = killed->FindNearestCreature(NPC_AGATHA_GUARDIAN, NOTIFY_AGATHA_RANGE))
            if (agatha->IsAIEnabled)
                agatha->AI()->SetGUID(killed->GetGUID(), DATA_NOTIFY_AGATHA);
    }

    // Sylvanas's SmartAI cast 84128 (summon her horse) and 151235 on accepting 27098; 84128 is in
    // no DBC. Only at Forsaken High Command, where the ride starts.
    void OnPlayerQuestAccept(Player* player, Quest const* quest) override
    {
        if (!player || !quest || quest->GetQuestId() != QUEST_LORDAERON)
            return;

        if (player->GetMapId() != SilverpineDC::MAP_LORDAERON_751
            || !player->IsWithinDist2d(&SylvHorseSummonPos, 100.0f))
            return;

        // One trip per player: an accept/abandon loop would otherwise stack parallel trips.
        std::list<Creature*> previousTrips;
        player->GetCreatureListWithEntryInGrid(previousTrips, NPC_LADY_SYLV_HORSE, 250.0f);
        for (Creature* horse : previousTrips)
        {
            TempSummon const* summon = horse->ToTempSummon();
            if (summon && summon->GetSummonerGUID() == player->GetGUID() && horse->IsAIEnabled)
                horse->AI()->DoAction(ACTION_END_LORDAERON_TRIP);
        }

        DismountAndCancelShapeshifts(player);
        player->SummonCreature(NPC_LADY_SYLV_HORSE, SylvHorseSummonPos, TEMPSUMMON_MANUAL_DESPAWN);
    }
};

void AddSC_dc_silverpine_fenris_isle()
{
    RegisterCreatureAI(npc_agatha1_silverpine);
    RegisterCreatureAI(npc_agatha_resummon_controller);
    RegisterCreatureAI(npc_no_escape_controller);
    RegisterCreatureAI(npc_fenris_no_escape_camera);
    RegisterCreatureAI(npc_forsaken_sylv_horse);
    new dc_silverpine_fenris_isle_player();
}
