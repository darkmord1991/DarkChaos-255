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

// Clickable portals in and out of the Cataclysm Shadowfang Keep clone (map 825).
//
// WHY NOT AN AREATRIGGER
// The obvious implementation is an areatrigger pair, and that was tried first: rows in
// `areatrigger` + `areatrigger_teleport`, ids added to AreaTrigger.dbc, deployed to every
// archive the client reads. It does not work. Standing 2.01 yards from the centre of a
// radius-7 trigger on map 751, with the server-side row loaded and correct, the client
// never sends CMSG_AREATRIGGER at all -- while stock triggers on maps 0 and 33 fire
// normally from the same client and the same DBC file. New areatriggers cannot be made to
// fire on these maps without client-side edits beyond the DBC.
//
// The rest of DarkChaos already works around this: there are 178 GameObject templates with
// a ScriptName across maps 750/751 and not one working custom areatrigger. Naxxramas-40's
// entrance is the direct precedent -- GO 361001, script `gobject_naxx40_tele` -- and this
// is the same shape.
//
// The GO also gives the level gate somewhere sensible to live. dungeon_access_template
// still carries placeholder levels (80/85/85) pending the rescale, so the check here is
// intentionally lenient and reads the same constant, not a second hard-coded number.

#include "GameObjectAI.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Chat.h"
#include "sfk_cata.h"

namespace ShadowfangKeepCata
{
// Kept in step with dungeon_access_template rows 158/159/160 (02_map825_registration.sql).
// Revisit together with the level rescale, not on its own.
uint8 const SFK_CATA_MIN_LEVEL = 80;

// Where the entrance drops you: the arrival point stock Shadowfang Keep uses, which 825
// shares because the two maps share a coordinate space.
constexpr float SFK_INSIDE_X = -229.135f, SFK_INSIDE_Y = 2109.18f,
                SFK_INSIDE_Z = 76.8898f, SFK_INSIDE_O = 1.267f;

// And where the exit puts you back: just outside the door in Silverpine on map 751.
constexpr float SFK_OUTSIDE_X = -232.796f, SFK_OUTSIDE_Y = 1568.28f,
                SFK_OUTSIDE_Z = 76.8909f, SFK_OUTSIDE_O = 4.398f;

uint32 const MAP_SILVERPINE_751 = 751;

class gobject_sfk_cata_enter : public GameObjectScript
{
public:
    gobject_sfk_cata_enter() : GameObjectScript("gobject_sfk_cata_enter") { }

    bool OnGossipHello(Player* player, GameObject* /*go*/) override
    {
        if (player->GetLevel() < SFK_CATA_MIN_LEVEL)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "You must be level %u or higher to enter Shadowfang Keep.", SFK_CATA_MIN_LEVEL);
            return true;
        }

        player->TeleportTo(MapShadowfangKeepCata, SFK_INSIDE_X, SFK_INSIDE_Y, SFK_INSIDE_Z, SFK_INSIDE_O);
        return true;
    }
};

class gobject_sfk_cata_exit : public GameObjectScript
{
public:
    gobject_sfk_cata_exit() : GameObjectScript("gobject_sfk_cata_exit") { }

    // No gate on the way out -- a player who is inside must always be able to leave, even
    // if they somehow no longer satisfy the entry requirement.
    bool OnGossipHello(Player* player, GameObject* /*go*/) override
    {
        player->TeleportTo(MAP_SILVERPINE_751, SFK_OUTSIDE_X, SFK_OUTSIDE_Y, SFK_OUTSIDE_Z, SFK_OUTSIDE_O);
        return true;
    }
};
}

void AddSC_gobject_sfk_cata_portal()
{
    using namespace ShadowfangKeepCata;
    new gobject_sfk_cata_enter();
    new gobject_sfk_cata_exit();
}
