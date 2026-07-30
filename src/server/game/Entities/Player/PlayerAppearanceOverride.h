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
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _PLAYER_APPEARANCE_OVERRIDE_H
#define _PLAYER_APPEARANCE_OVERRIDE_H

#include "Define.h"

class Player;

/**
 * @brief Seam for appearance systems that change what an equipment slot looks like without
 *        changing what is equipped.
 *
 * Transmog is replicated per observer while a unit's values-update block is serialised, so
 * PLAYER_VISIBLE_ITEM_*_ENTRYID keeps holding the real equipped item. A few consumers read
 * those fields directly and produce output that never passes through that path:
 *
 *  - the `characters.equipmentCache` blob, which renders the character-select screen;
 *  - the Dancing Rune Weapon copy, which mirrors the owner's weapon fields onto a creature.
 *
 * Both call Resolve() so they show the same appearance the world does.
 *
 * The game library cannot call into the script library, so a script installs the resolver at
 * startup. With none installed Resolve() returns the real entry unchanged, which is exactly
 * the stock behaviour.
 */
namespace Acore::AppearanceOverride
{
    /**
     * @param player     character whose slot is being resolved.
     * @param slot       EQUIPMENT_SLOT_* index.
     * @param realEntry  the real equipped item entry.
     * @return the item entry whose appearance should be shown (0 means "render nothing").
     */
    using Resolver = uint32 (*)(Player const* player, uint8 slot, uint32 realEntry);

    /** @brief Installs the resolver. Passing nullptr restores stock behaviour. */
    void SetResolver(Resolver resolver);

    /** @brief Applies the installed resolver, or returns realEntry when there is none. */
    [[nodiscard]] uint32 Resolve(Player const* player, uint8 slot, uint32 realEntry);
}

#endif // _PLAYER_APPEARANCE_OVERRIDE_H
