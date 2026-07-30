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

#include "PlayerAppearanceOverride.h"

#include <atomic>

namespace
{
    // Installed once during script registration and read from the save path and from spell
    // scripts; atomic so the read is well-defined without paying for a lock on every slot.
    std::atomic<Acore::AppearanceOverride::Resolver> _resolver{nullptr};
}

void Acore::AppearanceOverride::SetResolver(Resolver resolver)
{
    _resolver.store(resolver, std::memory_order_release);
}

uint32 Acore::AppearanceOverride::Resolve(Player const* player, uint8 slot, uint32 realEntry)
{
    Resolver resolver = _resolver.load(std::memory_order_acquire);

    if (!resolver || !player)
        return realEntry;

    return resolver(player, slot, realEntry);
}
