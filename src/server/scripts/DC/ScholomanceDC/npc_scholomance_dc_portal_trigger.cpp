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

// Walk-through portals for the DarkChaos Scholomance clone (map 822).
//
// Five invisible trigger creatures: one entrance on map 751 and four exits inside, standing
// exactly where stock Scholomance's own areatriggers are (6828 in, and 2547 / 2548 / 2549 /
// 2568 out). No click, and no polling -- this hooks MoveInLineOfSight, which the grid
// notifier fires when a unit actually moves nearby (GridNotifiers.cpp:138), so nothing runs
// at all while a doorway is empty.
//
// WHY NOT AREATRIGGERS
// They were built end-to-end for the Shadowfang clone -- rows in `areatrigger` and
// `areatrigger_teleport`, ids appended to AreaTrigger.dbc, deployed to patch-4,
// patch-enGB-3 and all three WarcraftXLHost candidate directories -- and they never fire on
// this fork's custom maps. Standing 2.01 yards from the centre of a radius-7 trigger on map
// 751, with the server-side row present and correct, the client sends no CMSG_AREATRIGGER
// at all, while stock triggers on maps 0 and 33 fire normally from the same client.
//
// WHY MoveInLineOfSight IS AVAILABLE HERE, DESPITE THESE BEING TRIGGERS
// Creature::UpdateMoveInLineOfSightState (Creature.cpp:2631) would normally switch it off
// for a trigger creature, but the check above it returns first:
//     if (IsPet() || ... || GetScriptId() || GetAIName() == "SmartAI")
//         { strictlyDisabled = false; disabled = false; return; }
// A creature with a ScriptName has a non-zero GetScriptId(), so that keeps the hook enabled
// even though flags_extra carries CREATURE_FLAG_EXTRA_TRIGGER. Remove the ScriptName from
// 07_portals.sql and all five portals go dead silently.

#include "Player.h"
#include "ScriptedCreature.h"
#include "ScriptMgr.h"
#include "scholomance_dc.h"

namespace ScholomanceDC
{
// ---------------------------------------------------------------------------------
// RADII -- PER PORTAL, and here the ENTRANCE is the constrained one
// ---------------------------------------------------------------------------------
// Each radius is sized from the stock areatrigger box it replaces, then capped by the rule
// that no trigger may reach the point another one drops players at -- or they are
// teleported straight back the instant they arrive.
//
//   portal       stock box L/W/H      half-extents        radius  nearest arrival  margin
//   entrance     10.6 / 13   / 21.7   5.3 x 6.5 x 10.85    5.5      9.21 yd        +3.71
//   porch A       8.2 / 38.4 / 60.4   4.1 x 19.2 x 30.2   12.0    144.17 yd      +132.17
//   porch B      11.2 / 37.4 / 44     5.6 x 18.7 x 22     12.0    129.94 yd      +117.94
//   porch C       9.7 / 31.4 / 54.2   4.85 x 15.7 x 27.1  12.0    141.98 yd      +131.98
//   main door    12.3 /  8.9 / 16.4   6.15 x 4.45 x 8.2    6.0     18.43 yd       +12.43
//
// THE ENTRANCE IS THE TIGHT ONE, which is the reverse of the Stratholme clone. The main-door
// exit drops players on 751 only 9.21 yards from the entrance trigger, so the entrance
// cannot be widened toward stock's 6.5 half-width. 5.5 leaves a 3.71 yd margin -- exactly
// the margin the Shadowfang portals ship on and work with.
//
// The three porch exits are unconstrained (nearest arrival on their own map is 130+ yd), so
// they are sized purely for coverage. Stock used very wide boxes there and a sphere cannot
// reproduce that shape, so the three are sized to form a CONTINUOUS chain instead: B and C
// sit 36.9 yd apart at opposite ends of the porch with A between them (A-B 21.4, A-C 20.3).
// At 12.0 the chain B-A-C overlaps at both joints (2.6 and 3.7 yd) with no gap to walk
// through; at 10.0 it leaves 1.4 and 0.3 yd dead strips. That is why this is 12.0.
//
// Distance is measured with GetExactDist, NOT IsWithinDistInMap. The latter adds BOTH
// objects' bounding radii, which inflates a nominal 3.0 to roughly 5.0 once a player's
// combat reach counts -- on Shadowfang that swallowed the arrival gap and ported players
// straight back out the moment they landed.

struct PortalDest
{
    uint32 entry;
    float  radius;      // per portal, not a shared constant -- see the table above
    uint32 map;
    float x, y, z, o;
};

// Destinations are the stock areatriggers' own target coordinates, so the clone's doors put
// players exactly where the real dungeon does. The ONE substitution is the exits' map:
// stock sends players to map 0, and these send them to 751 instead.
PortalDest const Portals[] =
{
    { NPC_SCHOLO_DC_PORTAL_ENTRANCE,   5.5f, MAP_SCHOLOMANCE_DC,  199.88f,   125.35f,  138.43f, 4.677f },
    { NPC_SCHOLO_DC_PORTAL_PORCH_A,   12.0f, MAP_LORDAERON_751,  1399.42f, -2574.59f,  107.79f, 6.283f },
    { NPC_SCHOLO_DC_PORTAL_PORCH_B,   12.0f, MAP_LORDAERON_751,  1399.42f, -2574.59f,  107.79f, 6.283f },
    { NPC_SCHOLO_DC_PORTAL_PORCH_C,   12.0f, MAP_LORDAERON_751,  1399.42f, -2574.59f,  107.79f, 6.283f },
    { NPC_SCHOLO_DC_PORTAL_MAIN_DOOR,  6.0f, MAP_LORDAERON_751,  1275.05f, -2552.03f,   90.40f, 3.663f }
};

// Resolve the row for one entry, or nullptr if this creature is not one of the five.
inline PortalDest const* FindPortal(uint32 entry)
{
    for (PortalDest const& p : Portals)
        if (p.entry == entry)
            return &p;

    return nullptr;
}

struct npc_scholomance_dc_portal_triggerAI : public ScriptedAI
{
    explicit npc_scholomance_dc_portal_triggerAI(Creature* creature)
        : ScriptedAI(creature), _dest(FindPortal(creature->GetEntry())) { }

    // Scenery: never engage, never chase, never tick.
    void AttackStart(Unit*) override { }
    void UpdateAI(uint32) override { }

    void MoveInLineOfSight(Unit* who) override
    {
        // Resolved once at spawn rather than per call. Null means a creature carries this
        // ScriptName but is not one of the five portals -- without this check it would
        // teleport players to wherever the first table row happens to point.
        if (!_dest)
            return;

        if (!who || !who->IsPlayer())
            return;

        // The radius comes from the row, NOT from a shared constant, so this lookup has to
        // happen BEFORE the distance test -- which is why it is cached in the constructor.
        if (me->GetExactDist(who) > _dest->radius)
            return;

        Player* player = who->ToPlayer();

        // A player mid-teleport is briefly still in range; without this they are grabbed
        // again before the first teleport resolves and the destination never settles.
        if (player->IsBeingTeleported() || !player->IsAlive())
            return;

        // NO level check here on purpose, in either direction. Player::TeleportTo already
        // calls MapMgr::PlayerCannotEnter (Player.cpp:1575), which enforces the
        // dungeon_access_template row for map 822 and sends the player the standard
        // "you must be level N" message. Repeating it here would be a second copy of the
        // number to keep in step through the 130-160 rescale, and a worse message.
        //
        // The exits are never gated -- someone inside must always be able to leave.
        player->TeleportTo(_dest->map, _dest->x, _dest->y, _dest->z, _dest->o);
    }

private:
    // Points into the static Portals table, so it outlives the creature and is never freed.
    PortalDest const* const _dest;
};

class npc_scholomance_dc_portal_trigger : public CreatureScript
{
public:
    npc_scholomance_dc_portal_trigger() : CreatureScript("npc_scholomance_dc_portal_trigger") { }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_scholomance_dc_portal_triggerAI(creature);
    }
};
}

void AddSC_npc_scholomance_dc_portal_trigger()
{
    using namespace ScholomanceDC;
    new npc_scholomance_dc_portal_trigger();
}
