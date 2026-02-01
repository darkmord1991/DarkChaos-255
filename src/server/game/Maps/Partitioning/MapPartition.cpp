/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "MapPartition.h"

MapPartition::MapPartition(uint32 mapId, uint32 partitionId, std::string name)
    : _mapId(mapId)
    , _partitionId(partitionId)
    , _name(std::move(name))
    , _playersCount(0)
    , _creaturesCount(0)
    , _boundaryObjectsCount(0)
{
}

void MapPartition::SetCounts(uint32 players, uint32 creatures, uint32 boundaryObjects)
{
    _playersCount.store(players);
    _creaturesCount.store(creatures);
    _boundaryObjectsCount.store(boundaryObjects);
}
