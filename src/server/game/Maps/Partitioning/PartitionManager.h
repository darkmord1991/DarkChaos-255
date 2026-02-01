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

#ifndef AC_PARTITION_MANAGER_H
#define AC_PARTITION_MANAGER_H

#include "Define.h"
#include "MapPartition.h"
#include "PartitionRelocationTxn.h"
#include "ObjectGuid.h"
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <memory>
#include <mutex>

class PartitionManager
{
public:
    struct PartitionStats
    {
        uint32 players = 0;
        uint32 creatures = 0;
        uint32 boundaryObjects = 0;
    };

    static PartitionManager* instance();

    bool IsEnabled() const;
    float GetBorderOverlap() const;
    bool IsMapPartitioned(uint32 mapId) const;
    bool UsePartitionStoreOnly() const;
    uint32 GetPartitionIdForPosition(uint32 mapId, float x, float y) const;
    uint32 GetPartitionIdForPosition(uint32 mapId, float x, float y, ObjectGuid const& guid) const;
    bool IsNearPartitionBoundary(uint32 mapId, float x, float y) const;

    uint32 GetPartitionCount(uint32 mapId) const;
    void RegisterPartition(std::unique_ptr<MapPartition> partition);
    void ClearPartitions(uint32 mapId);
    void Initialize();
    void UpdatePartitionsForMap(uint32 mapId, uint32 diff);
    void UpdatePartitionStats(uint32 mapId, uint32 partitionId, uint32 players, uint32 creatures, uint32 boundaryObjects);
    uint32 GetBoundaryCount(uint32 mapId, uint32 partitionId) const;
    void UpdatePartitionPlayerCount(uint32 mapId, uint32 partitionId, uint32 players);
    void UpdatePartitionCreatureCount(uint32 mapId, uint32 partitionId, uint32 creatures);
    void UpdatePartitionBoundaryCount(uint32 mapId, uint32 partitionId, uint32 boundaryObjects);
    bool GetPartitionStats(uint32 mapId, uint32 partitionId, PartitionStats& out) const;

    void NotifyVisibilityAttach(ObjectGuid const& guid, uint32 mapId, uint32 partitionId);
    void NotifyVisibilityDetach(ObjectGuid const& guid, uint32 mapId, uint32 partitionId);
    uint32 GetVisibilityCount(uint32 mapId, uint32 partitionId) const;

    // Cross-partition visibility helpers
    std::vector<uint32> GetAdjacentPartitions(uint32 mapId, uint32 partitionId) const;
    std::vector<ObjectGuid> GetBoundaryObjectGuids(uint32 mapId, uint32 partitionId) const;
    void RegisterBoundaryObject(uint32 mapId, uint32 partitionId, ObjectGuid const& guid);
    void UnregisterBoundaryObject(uint32 mapId, uint32 partitionId, ObjectGuid const& guid);
    bool IsObjectInBoundarySet(uint32 mapId, uint32 partitionId, ObjectGuid const& guid) const;

    bool GetPersistentPartition(ObjectGuid const& guid, uint32 mapId, uint32& outPartitionId) const;
    void PersistPartitionOwnership(ObjectGuid const& guid, uint32 mapId, uint32 partitionId);

    void RecordCombatHandoff(uint32 mapId);
    void RecordPathHandoff(uint32 mapId);
    uint32 ConsumeCombatHandoffCount(uint32 mapId);
    uint32 ConsumePathHandoffCount(uint32 mapId);

    void SetPartitionOverride(ObjectGuid const& guid, uint32 partitionId, uint32 durationMs);

    bool BeginRelocation(ObjectGuid const& guid, uint32 mapId, uint32 fromPartition, uint32 toPartition);
    bool CommitRelocation(ObjectGuid const& guid);
    void RollbackRelocation(ObjectGuid const& guid);

private:
    PartitionManager() = default;

    mutable std::mutex _lock;
    std::unordered_map<uint32, std::vector<std::unique_ptr<MapPartition>>> _partitionsByMap;
    std::unordered_set<uint32> _partitionedMaps;
    std::unordered_map<ObjectGuid::LowType, PartitionRelocationTxn> _relocations;
    std::unordered_map<uint32, uint32> _combatHandoffCounts;
    std::unordered_map<uint32, uint32> _pathHandoffCounts;
    std::unordered_map<uint32, std::unordered_map<uint32, std::unordered_set<ObjectGuid::LowType>>> _visibilitySets;
    struct PartitionOverride
    {
        uint32 partitionId = 0;
        uint64 expiresMs = 0;
    };
    struct PartitionOwnership
    {
        uint32 mapId = 0;
        uint32 partitionId = 0;
    };
    std::unordered_map<ObjectGuid::LowType, PartitionOverride> _partitionOverrides;
    std::unordered_map<ObjectGuid::LowType, PartitionOwnership> _partitionOwnership;
    // Map -> PartitionId -> Set of boundary object GUIDs
    std::unordered_map<uint32, std::unordered_map<uint32, std::unordered_set<ObjectGuid>>> _boundaryObjects;
};

#define sPartitionMgr PartitionManager::instance()

#endif // AC_PARTITION_MANAGER_H
