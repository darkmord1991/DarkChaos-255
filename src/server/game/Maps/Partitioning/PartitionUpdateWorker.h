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

#ifndef AC_PARTITION_UPDATE_WORKER_H
#define AC_PARTITION_UPDATE_WORKER_H

#include "Define.h"
#include "ObjectGuid.h"
#include <vector>

class Map;
class Player;
class WorldObject;

/**
 * @class PartitionUpdateWorker
 * @brief Encapsulates the work of updating a single partition within a map.
 *
 * This class is designed to be called from worker threads. It handles:
 * - Player updates within the partition
 * - Non-player object updates within the partition
 * - Relay processing for cross-partition events
 * - Boundary detection and recording
 */
class PartitionUpdateWorker
{
public:
    PartitionUpdateWorker(Map& map, uint32 partitionId, uint32 diff, uint32 s_diff);

    /// Execute the partition update. Thread-safe.
    void Execute();

    /// Get results after execution
    uint32 GetBoundaryPlayerCount() const { return _boundaryPlayerCount; }
    uint32 GetBoundaryObjectCount() const { return _boundaryObjectCount; }
    uint32 GetPlayerCount() const { return _playerCount; }
    uint32 GetCreatureCount() const { return _creatureCount; }

private:
    void UpdatePlayers();
    void UpdateNonPlayerObjects();
    void ProcessRelays();
    void RecordStats();

    Map& _map;
    uint32 _partitionId;
    uint32 _diff;
    uint32 _sDiff;

    // Results
    uint32 _boundaryPlayerCount = 0;
    uint32 _boundaryObjectCount = 0;
    uint32 _playerCount = 0;
    uint32 _creatureCount = 0;

    std::vector<ObjectGuid> _boundaryValidGuids;
};

#endif // AC_PARTITION_UPDATE_WORKER_H
