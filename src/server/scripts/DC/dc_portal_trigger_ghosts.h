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

#pragma once

// Corpse runs through the walk-through portal triggers of the map-751 dungeon clones
// (Stratholme 821, Scholomance 822, Shadowfang Keep 825).
//
// Those triggers react in MoveInLineOfSight, and that hook never sees a ghost:
// CreatureUnitRelocationWorker (GridNotifiers.cpp) returns before calling it for any unit
// that is not alive. Since areatriggers do not fire on 751 (see the trigger files), the
// triggers are the only door these instances have, so a player who released after a wipe
// could not walk back in to their corpse.
//
// The entrances therefore also poll for ghosts in the doorway. Only released players whose
// corpse lies in the trigger's destination map count:
//   - a player lying dead in the doorway before releasing must not be moved;
//   - a ghost whose corpse is elsewhere would be refused by MapMgr::PlayerCannotEnter
//     (SMSG_CORPSE_NOT_IN_INSTANCE) on every poll, so it is never tried.
// On arrival WorldSession::HandleMoveWorldportAck resurrects the ghost at its corpse, as at
// any stock instance portal.

#include "CellImpl.h"
#include "Creature.h"
#include "Duration.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "Player.h"

#include <list>

namespace DCPortalTriggerGhosts
{
    // A ghost runs about 10 yards a second, so a doorway trigger 10 yards across is crossed
    // in about a second. Half a second catches a ghost walking straight through.
    constexpr Milliseconds POLL_INTERVAL = 500ms;

    // Ghosts within `radius` of `trigger` (exact distance, the same measure the triggers use
    // for the living) whose corpse is on `destMapId`.
    inline std::list<Player*> FindGhostsBoundFor(Creature* trigger, float radius, uint32 destMapId)
    {
        std::list<Player*> players;
        Acore::AnyPlayerInObjectRangeCheck check(trigger, radius, false);
        Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck> searcher(trigger, players, check);
        Cell::VisitObjects(trigger, searcher, radius);

        players.remove_if([trigger, radius, destMapId](Player* player)
        {
            return !player->HasPlayerFlag(PLAYER_FLAGS_GHOST)
                || player->IsBeingTeleported()
                || !player->HasCorpse()
                || player->GetCorpseLocation().GetMapId() != destMapId
                || trigger->GetExactDist(player) > radius;
        });

        return players;
    }
}
