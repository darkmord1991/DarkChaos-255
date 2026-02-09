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

#include "DatabaseEnvFwd.h"
#include "SharedDefines.h"
#include "MapPartition.h"
#include "PartitionRelocationTxn.h"
#include "PartitionConstants.h"
#include "ObjectGuid.h"
#include <array>
#include <map>
#include <unordered_map>
#include <unordered_set>
#include <deque>
#include <mutex>
#include <shared_mutex>
#include <set>
#include <vector>
#include <memory>

class PartitionManager
{
public:
    struct PartitionStats
    {
        uint32 players = 0;
        uint32 creatures = 0;
        uint32 boundaryObjects = 0;
    };

    // Cached partition grid layout for fast lookups
    struct PartitionGridLayout
    {
        uint32 count = 0;
        uint32 cols = 0;
        uint32 rows = 0;
        uint32 cellWidth = 0;
        uint32 cellHeight = 0;
    };

    static PartitionManager* instance();

    bool IsEnabled() const;
    float GetBorderOverlap() const;
    bool IsMapPartitioned(uint32 mapId) const;
    bool UsePartitionStoreOnly() const;
    uint32 GetPartitionIdForPosition(uint32 mapId, float x, float y) const;
    uint32 GetPartitionIdForPosition(uint32 mapId, float x, float y, ObjectGuid const& guid) const;
    uint32 GetPartitionIdForPosition(uint32 mapId, float x, float y, uint32 zoneId, ObjectGuid const& guid) const;
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
    
    // Spatial Hash Grid boundary methods (Phase 2 optimization)
    void RegisterBoundaryObjectWithPosition(uint32 mapId, uint32 partitionId, ObjectGuid const& guid, float x, float y);
    void UpdateBoundaryObjectPosition(uint32 mapId, uint32 partitionId, ObjectGuid const& guid, float x, float y);
    void UnregisterBoundaryObjectFromGrid(uint32 mapId, uint32 partitionId, ObjectGuid const& guid);
    std::vector<ObjectGuid> GetNearbyBoundaryObjects(uint32 mapId, uint32 partitionId, float x, float y, float radius) const;

    // Batched boundary operations (reduces per-entity lock overhead)
    struct BoundaryPositionUpdate { ObjectGuid guid; float x; float y; };
    void BatchUpdateBoundaryPositions(uint32 mapId, uint32 partitionId, std::vector<BoundaryPositionUpdate> const& updates);
    void BatchUnregisterBoundaryObjects(uint32 mapId, uint32 partitionId, std::vector<ObjectGuid> const& guids);
    void BatchSetPartitionOverrides(std::vector<ObjectGuid> const& guids, uint32 mapId, uint32 partitionId, uint32 durationMs);

    bool GetPersistentPartition(ObjectGuid const& guid, uint32 mapId, uint32& outPartitionId) const;
    void PersistPartitionOwnership(ObjectGuid const& guid, uint32 mapId, uint32 partitionId);

    void RecordCombatHandoff(uint32 mapId);
    void RecordPathHandoff(uint32 mapId);
    uint32 ConsumeCombatHandoffCount(uint32 mapId);
    uint32 ConsumePathHandoffCount(uint32 mapId);

    void SetPartitionOverride(ObjectGuid const& guid, uint32 mapId, uint32 partitionId, uint32 durationMs);

    bool BeginRelocation(ObjectGuid const& guid, uint32 mapId, uint32 fromPartition, uint32 toPartition);
    bool CommitRelocation(ObjectGuid const& guid);
    void RollbackRelocation(ObjectGuid const& guid);

    // Zone exclusion - zones where partitioning is disabled (e.g., cities)
    bool IsZoneExcluded(uint32_t zoneId) const;

    // Runtime diagnostics
    bool IsRuntimeDiagnosticsEnabled() const;

    // Adjacent partition pre-caching
    void CheckBoundaryApproach(ObjectGuid const& playerGuid, uint32 mapId, float x, float y, float dx, float dy);

    // Layering support moved to LayerManager.h

private:
    PartitionManager() = default;

    void HandlePartitionOwnershipLoad(PreparedQueryResult result);
    std::shared_mutex& GetBoundaryLock(uint32 mapId) const;
    std::shared_mutex& GetVisibilityLock(uint32 mapId) const;
    std::vector<std::unique_lock<std::shared_mutex>> LockAllBoundaryStripes() const;
    std::vector<std::unique_lock<std::shared_mutex>> LockAllVisibilityStripes() const;

    // Periodic maintenance
    void CleanupStaleRelocations();
    void CleanupExpiredOverrides();
    void CleanupBoundaryObjects(uint32 mapId, uint32 partitionId, std::unordered_set<ObjectGuid> const& validGuids);
    void PeriodicCacheSweep();

    // Dynamic partition resizing
    float GetPartitionDensity(uint32 mapId, uint32 partitionId) const;
    void ResizeMapPartitions(uint32 mapId, uint32 newCount, char const* reason);
    void EvaluatePartitionDensity(uint32 mapId);
    float GetDensitySplitThreshold() const;
    float GetDensityMergeThreshold() const;

    // Adjacent partition pre-caching
    void ProcessPrecacheQueue(uint32 mapId);

    // Fine-grained locks for different data structures
    mutable std::shared_mutex _partitionLock;     // Protects _partitionsByMap, _partitionedMaps, _gridLayouts
    static constexpr size_t kBoundaryLockStripes = 16;
    mutable std::array<std::shared_mutex, kBoundaryLockStripes> _boundaryLocks; // Protects _boundaryObjects (striped)
    // _layerLock moved to LayerManager
    // _partyLayerCacheLock moved to LayerManager
    // _layerPairCacheLock moved to LayerManager
    mutable std::mutex _excludedCacheLock;        // Protects zone exclusion cache
    mutable std::mutex _relocationLock;           // Protects _relocations
    mutable std::shared_mutex _overrideLock;       // Protects _partitionOverrides, _partitionOwnership
    static constexpr size_t kVisibilityLockStripes = 16;
    mutable std::array<std::shared_mutex, kVisibilityLockStripes> _visibilityLocks; // Protects _visibilitySets (striped)
    mutable std::mutex _handoffLock;              // Protects handoff counts
    mutable std::mutex _precacheLock;             // Protects precache queue
    // _pendingLayerAssignmentLock moved to LayerManager

    // Cached grid layouts for each map (computed once at Initialize)
    std::unordered_map<uint32, PartitionGridLayout> _gridLayouts;

    std::unordered_map<uint32_t, std::vector<std::unique_ptr<MapPartition>>> _partitionsByMap;
    // O(1) partition lookup index: mapId -> partitionId -> raw pointer (non-owning)
    std::unordered_map<uint32, std::unordered_map<uint32, MapPartition*>> _partitionIndex;
    std::unordered_set<uint32_t> _partitionedMaps;
    std::unordered_set<uint32_t> _excludedZones;
    mutable std::unordered_map<uint32, bool> _zoneExcludedCache;
    std::unordered_map<ObjectGuid::LowType, PartitionRelocationTxn> _relocations;
    std::unordered_map<uint32, uint32> _combatHandoffCounts;
    std::unordered_map<uint32, uint32> _pathHandoffCounts;
    std::unordered_map<uint32, std::unordered_map<uint32, std::unordered_set<ObjectGuid::LowType>>> _visibilitySets;
    struct PartitionOverride
    {
        uint32 mapId = 0;
        uint32 partitionId = 0;
        uint64 expiresMs = 0;
    };
    struct PartitionOwnership
    {
        uint32 mapId = 0;
        uint32 partitionId = 0;
    };
    mutable std::unordered_map<ObjectGuid::LowType, PartitionOverride> _partitionOverrides;
    std::unordered_map<ObjectGuid::LowType, PartitionOwnership> _partitionOwnership;

    // _pendingLayerAssignments moved to LayerManager
    // Map -> PartitionId -> Set of boundary object GUIDs (legacy)
    std::unordered_map<uint32, std::unordered_map<uint32, std::unordered_set<ObjectGuid>>> _boundaryObjects;
    
    // Phase 2: Spatial Hash Grid for O(1) boundary lookups
    struct SpatialHashGrid
    {
        static constexpr uint32 CELL_SIZE = 100;  // 100 yards per cell
        
        struct BoundaryEntry
        {
            ObjectGuid guid;
            float x, y;
        };
        
        // Cell key -> list of boundary objects in that cell
        std::unordered_map<uint64, std::vector<BoundaryEntry>> cells;
        
        // GUID -> cell key (for fast removal)
        std::unordered_map<ObjectGuid::LowType, uint64> objectCellMap;
        
        static uint64 GetCellKey(float x, float y) {
            // Offset by MAP_HALFSIZE (~17066) to ensure all world coordinates hash to positive cells.
            // Without offset, all negative coords collapse to cell 0, degrading spatial queries to O(N).
            static constexpr float COORD_OFFSET = 17066.6656f; // MAP_HALFSIZE
            uint32 cx = static_cast<uint32>((x + COORD_OFFSET) / CELL_SIZE);
            uint32 cy = static_cast<uint32>((y + COORD_OFFSET) / CELL_SIZE);
            return (static_cast<uint64>(cx) << 32) | cy;
        }
        
        void Insert(ObjectGuid const& guid, float x, float y) {
            uint64 key = GetCellKey(x, y);
            cells[key].push_back({guid, x, y});
            objectCellMap[guid.GetCounter()] = key;
        }

        void Update(ObjectGuid const& guid, float x, float y) {
            auto cellIt = objectCellMap.find(guid.GetCounter());
            if (cellIt == objectCellMap.end())
            {
                Insert(guid, x, y);
                return;
            }

            uint64 newKey = GetCellKey(x, y);
            if (newKey != cellIt->second)
            {
                Remove(guid);
                Insert(guid, x, y);
                return;
            }

            auto& cell = cells[cellIt->second];
            for (auto& entry : cell)
            {
                if (entry.guid == guid)
                {
                    entry.x = x;
                    entry.y = y;
                    break;
                }
            }
        }
        
        void Remove(ObjectGuid const& guid) {
            auto cellIt = objectCellMap.find(guid.GetCounter());
            if (cellIt == objectCellMap.end())
                return;
            
            uint64 cellKey = cellIt->second;
            auto& cell = cells[cellKey];
            cell.erase(std::remove_if(cell.begin(), cell.end(),
                [&guid](BoundaryEntry const& e) { return e.guid == guid; }), cell.end());
            
            // Clean up empty cell vector to prevent unbounded map growth
            if (cell.empty())
                cells.erase(cellKey);
            
            objectCellMap.erase(cellIt);
        }
        
        std::vector<ObjectGuid> QueryNearby(float x, float y, float radius) const {
            std::vector<ObjectGuid> result;
            float radiusSq = radius * radius;
            
            // Query 3x3 neighborhood of cells (covers up to ~150 yard radius)
            int32 cellRadius = static_cast<int32>(radius / CELL_SIZE) + 1;
            for (int dx = -cellRadius; dx <= cellRadius; ++dx) {
                for (int dy = -cellRadius; dy <= cellRadius; ++dy) {
                    uint64 key = GetCellKey(x + dx * CELL_SIZE, y + dy * CELL_SIZE);
                    auto it = cells.find(key);
                    if (it != cells.end()) {
                        for (auto const& entry : it->second) {
                            float distX = entry.x - x;
                            float distY = entry.y - y;
                            if ((distX * distX + distY * distY) <= radiusSq)
                                result.push_back(entry.guid);
                        }
                    }
                }
            }
            return result;
        }
        
        void Clear() {
            cells.clear();
            objectCellMap.clear();
        }
        
        size_t Size() const {
            size_t total = 0;
            for (auto const& [_, cell] : cells)
                total += cell.size();
            return total;
        }
    };
    
    // Map -> Partition -> Spatial Grid for boundary objects
    std::unordered_map<uint32, std::unordered_map<uint32, SpatialHashGrid>> _boundarySpatialGrids;
    
    // Layering data moved to LayerManager.h

    // NPC Layering data moved to LayerManager
    // GameObject Layering data moved to LayerManager
    // Dynamic resize throttling
    std::unordered_map<uint32, uint64> _lastResizeMs;

    // Layer switch cooldown tracking moved to LayerManager

    struct PrecacheRequest
    {
        uint32 mapId = 0;
        uint32 partitionId = 0;
        float x = 0.0f;
        float y = 0.0f;
        uint64 queuedMs = 0;
    };

    std::deque<PrecacheRequest> _precacheQueue;
    std::unordered_map<uint64, uint64> _precacheRecent;
    std::unordered_map<ObjectGuid::LowType, uint64> _boundaryApproachLastCheck;

    // Layout epoch tracking for fast per-thread layout caching
    std::unordered_map<uint32, uint64> _layoutEpochByMap;

    // Helper to get cached grid layout (lock must be held)
    PartitionGridLayout const* GetGridLayout(uint32 mapId) const;
    
    // Helper to compute grid layout from partition count
    PartitionGridLayout ComputeGridLayout(uint32 count) const;
    
public:
    PartitionGridLayout const* GetCachedLayout(uint32 mapId) const;

private:
    std::atomic<bool> _runtimeDiagnostics{false};
    std::atomic<uint64> _runtimeDiagnosticsUntilMs{0};
    std::atomic<uint64> _lastCleanupMs{0};
};

#define sPartitionMgr PartitionManager::instance()

#endif // AC_PARTITION_MANAGER_H
