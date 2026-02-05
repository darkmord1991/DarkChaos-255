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

#include "SharedDefines.h"
#include "MapPartition.h"
#include "PartitionRelocationTxn.h"
#include "ObjectGuid.h"
#include <map>
#include <unordered_map>
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

    // Zone exclusion - zones where partitioning is disabled (e.g., cities)
    bool IsZoneExcluded(uint32_t zoneId) const;

    // Layering support (for high-population areas) - DISABLED by default
    bool IsLayeringEnabled() const;
    uint32_t GetLayerCapacity() const;
    bool IsRuntimeDiagnosticsEnabled() const;
    void SetRuntimeDiagnosticsEnabled(bool enabled);
    bool ShouldEmitRegenMetrics() const;
    uint64 GetRuntimeDiagnosticsRemainingMs() const;
    uint32_t GetLayerForPlayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid) const;
    uint32 GetPlayerLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& playerGuid) const; // Back-compat alias
    uint32_t GetLayerCount(uint32_t mapId, uint32_t zoneId) const;
    void AssignPlayerToLayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid, uint32_t layerId);
    void RemovePlayerFromLayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid);
    void AutoAssignPlayerToLayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid);
    // Thread-safe: Force remove player from all layers (for logout)
    void ForceRemovePlayerFromAllLayers(ObjectGuid const& playerGuid);
    // Thread-safe: Get layers for two players in one call (for visibility check)
    std::pair<uint32_t, uint32_t> GetLayersForTwoPlayers(uint32_t mapId, uint32_t zoneId, 
        ObjectGuid const& player1, ObjectGuid const& player2) const;

    // Cleanup methods
    void CleanupStaleRelocations();    // Thread-safe: Remove timed-out relocations
    void CleanupExpiredOverrides();    // Thread-safe: Remove expired partition overrides
    void CleanupBoundaryObjects(uint32 mapId, uint32 partitionId, std::unordered_set<ObjectGuid> const& validGuids);

    // Persistent layer assignment (Feature 1)
    void LoadPersistentLayerAssignment(ObjectGuid const& playerGuid);
    void SavePersistentLayerAssignment(ObjectGuid const& playerGuid, uint32 mapId, uint32 zoneId, uint32 layerId);

    // Cross-layer party communication (Feature 2)
    uint32 GetPartyTargetLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& playerGuid);

    // NPC Layering (Feature 3)
    bool IsNPCLayeringEnabled() const;
    void AssignNPCToLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& npcGuid, uint32 layerId);
    void RemoveNPCFromLayer(ObjectGuid const& npcGuid);
    uint32 GetLayerForNPC(uint32 mapId, uint32 zoneId, ObjectGuid const& npcGuid) const;
    uint32 GetLayerForNPC(ObjectGuid const& npcGuid) const; // Back-compat overload

    // Dynamic Partition Resizing (Feature 4)
    // Returns density metric for a partition (players + creatures normalized by cell size)
    float GetPartitionDensity(uint32 mapId, uint32 partitionId) const;
    // Evaluates if any partitions need splitting/merging based on density thresholds
    void EvaluatePartitionDensity(uint32 mapId);
    // Configuration thresholds for split/merge
    float GetDensitySplitThreshold() const;
    float GetDensityMergeThreshold() const;

    // Adjacent Partition Pre-caching (Feature 5)
    // Checks if player is approaching a partition boundary and queues precache
    void CheckBoundaryApproach(ObjectGuid const& playerGuid, uint32 mapId, float x, float y, float dx, float dy);
    // Process pending precache requests (called from worker thread)
    void ProcessPrecacheQueue(uint32 mapId);

private:
    PartitionManager() = default;

    // Fine-grained locks for different data structures
    mutable std::shared_mutex _partitionLock;     // Protects _partitionsByMap, _partitionedMaps, _gridLayouts
    mutable std::mutex _boundaryLock;             // Protects _boundaryObjects
    mutable std::mutex _layerLock;                // Protects _layers, _playerLayers
    mutable std::mutex _relocationLock;           // Protects _relocations
    mutable std::mutex _overrideLock;             // Protects _partitionOverrides, _partitionOwnership
    mutable std::mutex _visibilityLock;           // Protects _visibilitySets
    mutable std::mutex _handoffLock;              // Protects handoff counts
    mutable std::mutex _precacheLock;             // Protects precache queue

    // Cached grid layouts for each map (computed once at Initialize)
    std::unordered_map<uint32, PartitionGridLayout> _gridLayouts;

    std::unordered_map<uint32_t, std::vector<std::unique_ptr<MapPartition>>> _partitionsByMap;
    std::unordered_set<uint32_t> _partitionedMaps;
    std::unordered_set<uint32_t> _excludedZones;
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
    mutable std::unordered_map<ObjectGuid::LowType, PartitionOverride> _partitionOverrides;
    std::unordered_map<ObjectGuid::LowType, PartitionOwnership> _partitionOwnership;
    // Map -> PartitionId -> Set of boundary object GUIDs
    std::unordered_map<uint32, std::unordered_map<uint32, std::unordered_set<ObjectGuid>>> _boundaryObjects;
    
    // Layering data: Map -> Zone -> Layer -> Set of player GUIDs
    std::unordered_map<uint32, std::unordered_map<uint32, std::unordered_map<uint32, std::unordered_set<ObjectGuid::LowType>>>> _layers;
    // Player -> Layer assignment: PlayerGUID -> {mapId, zoneId, layerId}
    struct LayerAssignment
    {
        uint32 mapId = 0;
        uint32 zoneId = 0;
        uint32 layerId = 0;
    };
    std::unordered_map<ObjectGuid::LowType, LayerAssignment> _playerLayers;

    // NPC Layering data (Feature 3)
    std::unordered_map<ObjectGuid::LowType, LayerAssignment> _npcLayers;

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

    // Helper to get cached grid layout (lock must be held)
    PartitionGridLayout const* GetGridLayout(uint32 mapId) const;

public:
    // Back-compat helper for scripts
    PartitionGridLayout const* GetCachedLayout(uint32 mapId) const;

private:
    std::atomic<bool> _runtimeDiagnostics{false};
    std::atomic<uint64> _runtimeDiagnosticsUntilMs{0};
};

#define sPartitionMgr PartitionManager::instance()

#endif // AC_PARTITION_MANAGER_H
