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

#ifndef AC_MAP_PARTITION_H
#define AC_MAP_PARTITION_H

#include "Define.h"
#include <string>
#include <atomic>

class MapPartition
{
public:
    MapPartition(uint32 mapId, uint32 partitionId, std::string name);

    uint32 GetMapId() const { return _mapId; }
    uint32 GetPartitionId() const { return _partitionId; }
    std::string const& GetName() const { return _name; }

    uint32 GetPlayersCount() const { return _playersCount.load(); }
    uint32 GetCreaturesCount() const { return _creaturesCount.load(); }
    uint32 GetBoundaryObjectCount() const { return _boundaryObjectsCount.load(); }

    void SetCounts(uint32 players, uint32 creatures, uint32 boundaryObjects);
    void SetPlayersCount(uint32 players) { _playersCount.store(players); }
    void SetCreaturesCount(uint32 creatures) { _creaturesCount.store(creatures); }
    void SetBoundaryObjectCount(uint32 boundaryObjects) { _boundaryObjectsCount.store(boundaryObjects); }
    virtual void Update(uint32 /*diff*/) { }

private:
    uint32 _mapId;
    uint32 _partitionId;
    std::string _name;

    std::atomic<uint32> _playersCount;
    std::atomic<uint32> _creaturesCount;
    std::atomic<uint32> _boundaryObjectsCount;
};

#endif // AC_MAP_PARTITION_H
