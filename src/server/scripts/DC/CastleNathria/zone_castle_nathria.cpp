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

// DarkChaos downport of the Shadowlands raid Castle Nathria (map 2296).
// Ported from the "shadowcore" (TrinityCore 9.x) implementation.
//
// Shadowcore's zone_castle_nathria.cpp was an empty registration stub — no zone-level
// scripts were ever authored upstream. Kept as the registration anchor for future
// zone content (story-NPC stage RP, trash packs, the Nightcloak shortcut trigger).

#include "ScriptMgr.h"
#include "castle_nathria.h"

void AddSC_zone_castle_nathria()
{
    // TODO(port): no zone scripts yet — the shadowcore original was empty.
}
