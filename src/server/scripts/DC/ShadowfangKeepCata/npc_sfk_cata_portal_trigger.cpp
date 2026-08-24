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

// Walk-through portals for the Cataclysm Shadowfang Keep clone (map 825).
//
// An invisible trigger creature stands in the doorway and teleports anyone who walks into
// it. No click, and no polling: this hooks MoveInLineOfSight, which the grid notifier
// fires when a unit actually moves near (GridNotifiers.cpp:138), so there is no periodic
// work at all and nothing runs while the doorway is empty.
//
// This is the ONLY portal mechanism. An earlier revision also spawned a clickable portal
// gameobject alongside it; that was removed (20_remove_portal_gameobjects.sql) because two
// ways in meant two places to keep the destinations and the level gate in step.
//
// WHY MoveInLineOfSight IS AVAILABLE HERE, DESPITE THESE BEING TRIGGERS
// Creature::UpdateMoveInLineOfSightState (Creature.cpp:2631) would normally switch it off
// for a trigger creature -- `if (IsTrigger() || IsCivilian() || ...)` sets
// m_moveInLineOfSightStrictlyDisabled. But the check ABOVE it returns first:
//     if (IsPet() || ... || GetScriptId() || GetAIName() == "SmartAI")
//         { strictlyDisabled = false; disabled = false; return; }
// A creature with a ScriptName has a non-zero GetScriptId(), so these two keep the hook
// enabled even though flags_extra carries CREATURE_FLAG_EXTRA_TRIGGER. Remove the
// ScriptName and the portals go dead silently -- the flags alone would disable them.
//
// WHY NOT AN AREATRIGGER
// It was built first and fully -- rows in `areatrigger` + `areatrigger_teleport`, ids in
// AreaTrigger.dbc, deployed to patch-4, patch-enGB-3 and all three WarcraftXLHost
// candidate dirs. It never fires. Standing 2.01 yards from the centre of a radius-7
// trigger on map 751, with the server-side row loaded and correct, the client sends no
// CMSG_AREATRIGGER at all, while stock triggers on maps 0 and 33 fire normally from the
// same client and the same DBC. Cloning the WMO would not change this: areatriggers live
// entirely in AreaTrigger.dbc and have no WMO component to edit.

#include "Player.h"
#include "ScriptedCreature.h"
#include "ScriptMgr.h"
#include "sfk_cata.h"

namespace ShadowfangKeepCata
{
// Entry ids of the two trigger creatures; see 19_portal_triggers.sql.
uint32 const NPC_SFK_CATA_PORTAL_IN  = 5420000;   // stands at the door on map 751
uint32 const NPC_SFK_CATA_PORTAL_OUT = 5420001;   // stands inside, on map 825

// ---------------------------------------------------------------------------------
// RADII -- these are set from the measured separations, not picked by feel
// ---------------------------------------------------------------------------------
// Each trigger must NOT reach the point the other one drops you at, or you are teleported
// straight back the instant you arrive. Measured distances between the two pairs:
//
//     exit trigger      <-> where the entrance drops you :  4.50 yd   <-- the tight one
//     entrance trigger  <-> where the exit drops you     :  8.72 yd
//
// The exit therefore needs a radius comfortably under 4.50; 2.5 leaves a 2.0 yd margin on
// arrival while still being impossible to squeeze past in a doorway.
//
// The entrance has far more room, so it is deliberately generous at 5.0 (3.72 yd still
// clear of where the exit drops you). It sits at the top of an outdoor stair where the
// walkable floor is about 1.4 yd above the spawn Z -- a tight sphere there is easy to step
// over without ever entering it.
float const PORTAL_RADIUS_IN  = 5.0f;   // entrance, map 751 -- 3.72 yd still clear
float const PORTAL_RADIUS_OUT = 2.5f;   // exit, map 825      -- 2.00 yd still clear

// Distance is measured with GetExactDist, NOT IsWithinDistInMap. The latter adds BOTH
// objects' bounding radii, which turns a nominal 3.0 into roughly 5.0 once a player's
// combat reach is counted -- enough to swallow the 4.50 yd arrival gap and port you out
// the moment you land. That inflation is exactly the bug this comment exists to prevent
// someone reintroducing.

struct npc_sfk_cata_portal_triggerAI : public ScriptedAI
{
    explicit npc_sfk_cata_portal_triggerAI(Creature* creature) : ScriptedAI(creature) { }

    // Scenery: never engage, never chase, never tick.
    void AttackStart(Unit*) override { }
    void UpdateAI(uint32) override { }

    void MoveInLineOfSight(Unit* who) override
    {
        if (!who || !who->IsPlayer())
            return;

        bool const isEntrance = me->GetEntry() == NPC_SFK_CATA_PORTAL_IN;

        if (me->GetExactDist(who) > (isEntrance ? PORTAL_RADIUS_IN : PORTAL_RADIUS_OUT))
            return;

        Player* player = who->ToPlayer();

        // A player mid-teleport is briefly still in range; without this they are grabbed
        // again before the first teleport resolves and the destination never settles.
        //
        // NO IsAlive() check. It used to be here and it stranded ghosts in BOTH
        // directions: a player who releases after a wipe inside cannot walk out, and --
        // worse, because the graveyard is outside -- cannot walk back IN to reach their
        // corpse either. Since the areatriggers do not fire on this fork's custom maps
        // (see the header), these two NPCs are the only door the instance has, so
        // refusing a corpse run here means the run is over. A dead player teleports
        // fine; this is how every stock instance portal behaves.
        if (player->IsBeingTeleported())
            return;

        if (isEntrance)
        {
            // NO level check here on purpose. Player::TeleportTo already calls
            // MapMgr::PlayerCannotEnter (Player.cpp:1575), which enforces
            // dungeon_access_template rows 158/159/160 for map 825 and sends the player the
            // standard "you must be level N" message. Repeating the check here would be a
            // second copy of the number to keep in step through the level rescale, and a
            // worse message.
            player->TeleportTo(MapShadowfangKeepCata,
                               SFK_INSIDE_X, SFK_INSIDE_Y, SFK_INSIDE_Z, SFK_INSIDE_O);
        }
        else
        {
            // No level gate on the way out -- someone inside must always be able to leave.
            player->TeleportTo(MAP_SILVERPINE_751,
                               SFK_OUTSIDE_X, SFK_OUTSIDE_Y, SFK_OUTSIDE_Z, SFK_OUTSIDE_O);
        }
    }
};

class npc_sfk_cata_portal_trigger : public CreatureScript
{
public:
    npc_sfk_cata_portal_trigger() : CreatureScript("npc_sfk_cata_portal_trigger") { }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_sfk_cata_portal_triggerAI(creature);
    }
};
}

void AddSC_npc_sfk_cata_portal_trigger()
{
    using namespace ShadowfangKeepCata;
    new npc_sfk_cata_portal_trigger();
}
