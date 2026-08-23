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

// Walk-through portals for the DarkChaos Stratholme clone (map 821).
//
// Four invisible trigger creatures: three entrances on map 751 and one exit inside the
// dungeon, standing exactly where stock Stratholme's own areatriggers are (6823, 6824,
// 6822 and 2221). No click, and no polling -- this hooks MoveInLineOfSight, which the grid
// notifier fires when a unit actually moves nearby (GridNotifiers.cpp:138), so nothing runs
// at all while a doorway is empty.
//
// WHY NOT AREATRIGGERS
// They were built end-to-end for the Shadowfang clone -- rows in `areatrigger` and
// `areatrigger_teleport`, ids appended to AreaTrigger.dbc, deployed to patch-4,
// patch-enGB-3 and all three WarcraftXLHost candidate directories -- and they never fire on
// this fork's custom maps. Standing 2.01 yards from the centre of a radius-7 trigger on map
// 751, with the server-side row present and correct, the client sends no CMSG_AREATRIGGER
// at all, while stock triggers on maps 0 and 33 fire normally from the same client and the
// same DBC. Cloning the WMO would not help: areatriggers have no WMO component.
//
// WHY MoveInLineOfSight IS AVAILABLE HERE, DESPITE THESE BEING TRIGGERS
// Creature::UpdateMoveInLineOfSightState (Creature.cpp:2631) would normally switch it off
// for a trigger creature -- `if (IsTrigger() || IsCivilian() || ...)` sets
// m_moveInLineOfSightStrictlyDisabled. But the check ABOVE it returns first:
//     if (IsPet() || ... || GetScriptId() || GetAIName() == "SmartAI")
//         { strictlyDisabled = false; disabled = false; return; }
// A creature with a ScriptName has a non-zero GetScriptId(), so that keeps the hook enabled
// even though flags_extra carries CREATURE_FLAG_EXTRA_TRIGGER. Remove the ScriptName from
// 07_portals.sql and all four portals go dead silently.

#include "Player.h"
#include "ScriptedCreature.h"
#include "ScriptMgr.h"
#include "stratholme_dc.h"

namespace StratholmeDC
{
// ---------------------------------------------------------------------------------
// RADII -- PER PORTAL, and sized from the stock trigger volumes they replace
// ---------------------------------------------------------------------------------
// These are NOT one shared number. The four portals replace areatriggers whose box volumes
// differ by a factor of three, and a single radius gets one end or the other wrong:
//
//   portal        stock box  L / W / H      half-extents        radius here
//   front right   22.83 / 20   / 34.69      11.4 x 10 x 17.3       11.0
//   front left    27.94 / 20   / 35.19      14.0 x 10 x 17.6       11.0
//   back          10    / 10   / 10          5.0 x  5 x  5.0        5.0
//   exit           9.78 / 17.94 / 27.92      4.9 x  9 x 14.0        5.0
//
// THE FRONT GATES ARE THE REASON THIS IS PER-PORTAL. A first revision used 5.0 everywhere.
// Against a stock volume reaching 11-14 yards through the gate and 10 across it, that
// leaves a player walking through the main gate more than 5 yards off-centre passing
// through nothing at all -- which in game looks exactly like the Shadowfang "portal does
// nothing" symptom while having a completely different cause.
//
// WHAT CONSTRAINS EACH VALUE
// A trigger must not reach the point another one drops players at, or they are teleported
// straight back the instant they arrive. Measured from the stock coordinates inherited here:
//
//   front gates <-> nearest arrival point on 751 : 679 yd   -- effectively unconstrained
//   exit trigger <-> back-entrance arrival in 821:  13.23 yd -- caps the exit
//   back trigger <-> where the exit drops you, 751:  10.80 yd -- caps the back entrance
//
// So the front pair is free to match stock, while back and exit stay at 5.0 and keep 8.2
// and 5.8 yards of clearance respectively. (The Shadowfang portals ship on a 3.72 yd margin
// and work, so those two are comfortable.)
//
// The two front triggers sit 20.2 yd apart, so at 11.0 they overlap by ~1.8 yd in the
// middle. That is deliberate: a gap there would be a dead strip straight down the centre of
// the gate. Whichever fires first wins, and both lead into map 821 -- just to the two stock
// arrival points, 25 yd apart just inside the door.

// Distance is measured with GetExactDist, NOT IsWithinDistInMap. The latter adds BOTH
// objects' bounding radii, which inflates a nominal 3.0 to roughly 5.0 once a player's
// combat reach counts -- on Shadowfang that swallowed the arrival gap and ported players
// straight back out the moment they landed. That inflation is exactly what this comment
// exists to stop someone reintroducing.

struct PortalDest
{
    uint32 entry;
    float  radius;      // see the RADII block above -- per portal, not a shared constant
    uint32 map;
    float x, y, z, o;
};

// Destinations are the stock areatriggers' own target coordinates, so the clone's doors put
// players exactly where the real dungeon does. The ONE substitution is the exit's map:
// stock trigger 2221 sends players to map 0, and this sends them to 751 instead.
PortalDest const Portals[] =
{
    { NPC_STRAT_DC_PORTAL_FRONT_RIGHT, 11.0f, MAP_STRATHOLME_DC, 3393.27f, -3392.00f, 143.15f, 1.571f },
    { NPC_STRAT_DC_PORTAL_FRONT_LEFT,  11.0f, MAP_STRATHOLME_DC, 3393.00f, -3366.90f, 142.84f, 4.712f },
    { NPC_STRAT_DC_PORTAL_BACK,         5.0f, MAP_STRATHOLME_DC, 3590.87f, -3643.22f, 138.49f, 5.498f },
    { NPC_STRAT_DC_PORTAL_EXIT,         5.0f, MAP_LORDAERON_751, 3235.46f, -4050.60f, 108.45f, 1.935f }
};

// Resolve the row for one entry, or nullptr if this creature is not one of the four.
inline PortalDest const* FindPortal(uint32 entry)
{
    for (PortalDest const& p : Portals)
        if (p.entry == entry)
            return &p;

    return nullptr;
}

struct npc_stratholme_dc_portal_triggerAI : public ScriptedAI
{
    explicit npc_stratholme_dc_portal_triggerAI(Creature* creature)
        : ScriptedAI(creature), _dest(FindPortal(creature->GetEntry())) { }

    // Scenery: never engage, never chase, never tick.
    void AttackStart(Unit*) override { }
    void UpdateAI(uint32) override { }

    void MoveInLineOfSight(Unit* who) override
    {
        // Resolved once at spawn rather than per call. Null means a creature carries this
        // ScriptName but is not one of the four portals -- without this check it would
        // teleport players to wherever the first table row happens to point.
        if (!_dest)
            return;

        if (!who || !who->IsPlayer())
            return;

        // The radius comes from the row, NOT from a shared constant: the front gates use
        // 11.0 and the back/exit pair 5.0. This lookup therefore has to happen BEFORE the
        // distance test, which is why it is cached rather than done further down.
        if (me->GetExactDist(who) > _dest->radius)
            return;

        Player* player = who->ToPlayer();

        // A player mid-teleport is briefly still in range; without this they are grabbed
        // again before the first teleport resolves and the destination never settles.
        if (player->IsBeingTeleported() || !player->IsAlive())
            return;

        // NO level check here on purpose, in either direction. Player::TeleportTo already
        // calls MapMgr::PlayerCannotEnter (Player.cpp:1575), which enforces the
        // dungeon_access_template row for map 821 and sends the player the standard
        // "you must be level N" message. Repeating it here would be a second copy of the
        // number to keep in step through the 130-160 rescale, and a worse message.
        //
        // The exit is never gated -- someone inside must always be able to leave.
        player->TeleportTo(_dest->map, _dest->x, _dest->y, _dest->z, _dest->o);
    }

private:
    // Points into the static Portals table, so it outlives the creature and is never freed.
    PortalDest const* const _dest;
};

class npc_stratholme_dc_portal_trigger : public CreatureScript
{
public:
    npc_stratholme_dc_portal_trigger() : CreatureScript("npc_stratholme_dc_portal_trigger") { }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_stratholme_dc_portal_triggerAI(creature);
    }
};
}

void AddSC_npc_stratholme_dc_portal_trigger()
{
    using namespace StratholmeDC;
    new npc_stratholme_dc_portal_trigger();
}
