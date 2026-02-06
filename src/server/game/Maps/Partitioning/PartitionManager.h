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
    void BatchSetPartitionOverrides(std::vector<ObjectGuid> const& guids, uint32 partitionId, uint32 durationMs);

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
    uint32_t GetLayerMax() const;
    bool IsRuntimeDiagnosticsEnabled() const;
    void SetRuntimeDiagnosticsEnabled(bool enabled);
    bool ShouldEmitRegenMetrics() const;
    uint64 GetRuntimeDiagnosticsRemainingMs() const;
    uint32_t GetLayerForPlayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid) const;
    uint32 GetPlayerLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& playerGuid) const; // Back-compat alias
    uint32_t GetLayerCount(uint32_t mapId, uint32_t zoneId) const;
    std::vector<uint32> GetLayerIds(uint32 mapId, uint32 zoneId) const;
    void GetActiveLayerIds(uint32 mapId, uint32 zoneId, std::vector<uint32>& out) const;
    using LayerCountByZone = std::map<uint32, std::map<uint32, uint32>>;
    void GetNPCLayerCountsByZone(uint32 mapId, LayerCountByZone& out) const;
    void GetGOLayerCountsByZone(uint32 mapId, LayerCountByZone& out) const;
    void GetLayerPlayerCountsByLayer(uint32 mapId, uint32 zoneId, std::map<uint32, uint32>& out) const;
    bool HasPlayersInZone(uint32 mapId, uint32 zoneId) const;
    bool SkipCloneSpawnsIfNoPlayers() const;
    bool EmitPerLayerCloneMetrics() const;
    void AssignPlayerToLayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid, uint32_t layerId);
    void RemovePlayerFromLayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid);
    void AutoAssignPlayerToLayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid);
    // Thread-safe: Force remove player from all layers (for logout)
    void ForceRemovePlayerFromAllLayers(ObjectGuid const& playerGuid);
    // Thread-safe: Get layers for two players in one call (for visibility check)
    std::pair<uint32_t, uint32_t> GetLayersForTwoPlayers(uint32_t mapId, uint32_t zoneId, 
        ObjectGuid const& player1, ObjectGuid const& player2) const;
    // Thread-safe: Get player + NPC layer with a single lock
    void GetPlayerAndNPCLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& playerGuid,
        ObjectGuid const& npcGuid, uint32& outPlayerLayer, uint32& outNpcLayer) const;
    // Thread-safe: Get player + GO layer with a single lock
    void GetPlayerAndGOLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& playerGuid,
        ObjectGuid const& goGuid, uint32& outPlayerLayer, uint32& outGoLayer) const;

    // Cleanup methods
    void CleanupStaleRelocations();    // Thread-safe: Remove timed-out relocations
    void CleanupExpiredOverrides();    // Thread-safe: Remove expired partition overrides
    void CleanupBoundaryObjects(uint32 mapId, uint32 partitionId, std::unordered_set<ObjectGuid> const& validGuids);
    void PeriodicCacheSweep();         // Thread-safe: Sweep all accumulated caches (called ~1/sec)

    // Persistent layer assignment (Feature 1)
    void LoadPersistentLayerAssignment(ObjectGuid const& playerGuid);
    void SavePersistentLayerAssignment(ObjectGuid const& playerGuid, uint32 mapId, uint32 zoneId, uint32 layerId);

    // Cross-layer party communication (Feature 2)
    uint32 GetPartyTargetLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& playerGuid);
    
    // Player-Initiated Layer Switching (Phase 5 - WoW-style)
    // Check if player can switch layers (combat check, cooldown, death check)
    bool CanSwitchLayer(ObjectGuid const& playerGuid) const;
    // Get remaining cooldown in milliseconds
    uint32 GetLayerSwitchCooldownMs(ObjectGuid const& playerGuid) const;
    // Switch player to target layer (for .dc partition join command)
    bool SwitchPlayerToLayer(ObjectGuid const& playerGuid, uint32 targetLayer, std::string const& reason);

    // NPC Layering (Feature 3)
    bool IsNPCLayeringEnabled() const;
    void AssignNPCToLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& npcGuid, uint32 layerId);
    void RemoveNPCFromLayer(ObjectGuid const& npcGuid);
    uint32 GetLayerForNPC(uint32 mapId, uint32 zoneId, ObjectGuid const& npcGuid) const;
    uint32 GetLayerForNPC(ObjectGuid const& npcGuid) const; // Back-compat overload
    uint32 GetDefaultLayerForZone(uint32 mapId, uint32 zoneId, uint64 seed) const;

    // GameObject Layering (Feature 3b)
    bool IsGOLayeringEnabled() const;
    void AssignGOToLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& goGuid, uint32 layerId);
    void RemoveGOFromLayer(ObjectGuid const& goGuid);
    uint32 GetLayerForGO(uint32 mapId, uint32 zoneId, ObjectGuid const& goGuid) const;
    uint32 GetLayerForGO(ObjectGuid const& goGuid) const;

    // Dynamic Partition Resizing (Feature 4)
    // Returns density metric for a partition (players + creatures normalized by cell size)
    float GetPartitionDensity(uint32 mapId, uint32 partitionId) const;
    // Evaluates if any partitions need splitting/merging based on density thresholds
    void EvaluatePartitionDensity(uint32 mapId);
    // Apply a new partition count and rebuild layout/object assignments
    void ResizeMapPartitions(uint32 mapId, uint32 newCount, char const* reason);
    // Configuration thresholds for split/merge
    float GetDensitySplitThreshold() const;
    float GetDensityMergeThreshold() const;

    // Adjacent Partition Pre-caching (Feature 5)
    // Checks if player is approaching a partition boundary and queues precache
    void CheckBoundaryApproach(ObjectGuid const& playerGuid, uint32 mapId, float x, float y, float dx, float dy);
    // Process pending precache requests (called from worker thread)
    void ProcessPrecacheQueue(uint32 mapId);
    
    // Phase 6: Layer Rebalancing
    // Evaluate and perform layer rebalancing if needed
    void EvaluateLayerRebalancing(uint32 mapId, uint32 zoneId);
    // Get player distribution across layers for a zone
    std::vector<uint32> GetLayerPlayerCounts(uint32 mapId, uint32 zoneId) const;
    // Check if rebalancing is needed based on configured thresholds
    bool ShouldRebalanceLayers(std::vector<uint32> const& playerCounts) const;
    // Migrate players from sparse layers to denser ones
    void ConsolidateLayers(uint32 mapId, uint32 zoneId, std::vector<uint32> const& targetDistribution);
    
    // Rebalancing configuration
    struct LayerRebalancingConfig
    {
        bool enabled{true};
        uint32 checkIntervalMs{300000};  // Check every 5 minutes
        uint32 minPlayersPerLayer{5};    // Minimum players to keep a layer alive
        float imbalanceThreshold{0.3f};  // Trigger if coefficient of variation > 30%
        uint32 migrationBatchSize{10};   // Max players to move per cycle
    };
    
    // Rebalancing metrics for monitoring
    struct RebalancingMetrics
    {
        std::atomic<uint32> totalRebalances{0};
        std::atomic<uint32> playersMigrated{0};
        std::atomic<uint32> layersConsolidated{0};
    };
    
    LayerRebalancingConfig const& GetRebalancingConfig() const { return _rebalancingConfig; }
    RebalancingMetrics const& GetRebalancingMetrics() const { return _rebalancingMetrics; }

private:
    PartitionManager() = default;

    void SyncControlledToLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& playerGuid, uint32 layerId);
    void ReassignNPCsForNewLayer(uint32 mapId, uint32 zoneId, uint32 layerId);
    void ReassignGOsForNewLayer(uint32 mapId, uint32 zoneId, uint32 layerId);

    // Fine-grained locks for different data structures
    mutable std::shared_mutex _partitionLock;     // Protects _partitionsByMap, _partitionedMaps, _gridLayouts
    mutable std::shared_mutex _boundaryLock;      // Protects _boundaryObjects (read/write optimized)
    mutable std::shared_mutex _layerLock;         // Protects _layers, _playerLayers (read/write optimized)
    mutable std::mutex _partyLayerCacheLock;      // Protects party target layer cache
    mutable std::mutex _layerPairCacheLock;       // Protects layer pair cache
    mutable std::mutex _excludedCacheLock;        // Protects zone exclusion cache
    mutable std::mutex _relocationLock;           // Protects _relocations
    mutable std::shared_mutex _overrideLock;       // Protects _partitionOverrides, _partitionOwnership
    mutable std::shared_mutex _visibilityLock;      // Protects _visibilitySets (read/write optimized)
    mutable std::mutex _handoffLock;              // Protects handoff counts
    mutable std::mutex _precacheLock;             // Protects precache queue

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
            uint32 cx = static_cast<uint32>(std::max(0.0f, x) / CELL_SIZE);
            uint32 cy = static_cast<uint32>(std::max(0.0f, y) / CELL_SIZE);
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
    
    // Layering data: Map -> Zone -> Layer -> Set of player GUIDs
    std::unordered_map<uint32, std::unordered_map<uint32, std::unordered_map<uint32, std::unordered_set<ObjectGuid::LowType>>>> _layers;
    // Player -> Layer assignment: PlayerGUID -> {mapId, zoneId, layerId}
    struct LayerAssignment
    {
        uint32 mapId = 0;
        uint32 zoneId = 0;
        uint32 layerId = 0;
        uint32 entry = 0;
    };
    std::unordered_map<ObjectGuid::LowType, LayerAssignment> _playerLayers;

    // Lock-free layer assignments for hot read path (Phase 1 optimization)
    // Uses atomic uint64 to pack mapId (16 bits), zoneId (16 bits), layerId (32 bits)
    // Read operations can use atomic load without acquiring _layerLock
    struct AtomicLayerAssignment
    {
        std::atomic<uint64> packed{0};  // [mapId:16][zoneId:16][layerId:32]
        
        void Store(uint32 mapId, uint32 zoneId, uint32 layerId) {
            uint64 value = (static_cast<uint64>(mapId & 0xFFFF) << 48) |
                          (static_cast<uint64>(zoneId & 0xFFFF) << 32) |
                          static_cast<uint64>(layerId);
            packed.store(value, std::memory_order_release);
        }
        
        void Load(uint32& mapId, uint32& zoneId, uint32& layerId) const {
            uint64 value = packed.load(std::memory_order_acquire);
            mapId = static_cast<uint32>((value >> 48) & 0xFFFF);
            zoneId = static_cast<uint32>((value >> 32) & 0xFFFF);
            layerId = static_cast<uint32>(value & 0xFFFFFFFF);
        }
        
        void Clear() {
            packed.store(0, std::memory_order_release);
        }
        
        bool IsValid() const {
            return packed.load(std::memory_order_relaxed) != 0;
        }
    };
    std::unordered_map<ObjectGuid::LowType, AtomicLayerAssignment> _atomicPlayerLayers;

    struct PartyTargetLayerCacheEntry
    {
        uint32 mapId = 0;
        uint32 zoneId = 0;
        uint32 layerId = 0;
        uint64 expiresMs = 0;
    };
    std::unordered_map<ObjectGuid::LowType, PartyTargetLayerCacheEntry> _partyTargetLayerCache;

    struct LayerPairCacheKey
    {
        uint32 mapId = 0;
        uint32 zoneId = 0;
        ObjectGuid::LowType a = 0;
        ObjectGuid::LowType b = 0;

        bool operator==(LayerPairCacheKey const& other) const
        {
            return mapId == other.mapId && zoneId == other.zoneId && a == other.a && b == other.b;
        }
    };

    struct LayerPairCacheKeyHash
    {
        size_t operator()(LayerPairCacheKey const& key) const
        {
            size_t h1 = std::hash<uint32>{}(key.mapId);
            size_t h2 = std::hash<uint32>{}(key.zoneId);
            size_t h3 = std::hash<ObjectGuid::LowType>{}(key.a);
            size_t h4 = std::hash<ObjectGuid::LowType>{}(key.b);
            return (((h1 * 1315423911u) ^ h2) * 2654435761u) ^ (h3 + (h4 << 1));
        }
    };

    struct LayerPairCacheEntry
    {
        uint32 layer1 = 0;
        uint32 layer2 = 0;
        uint64 expiresMs = 0;
    };
    mutable std::unordered_map<LayerPairCacheKey, LayerPairCacheEntry, LayerPairCacheKeyHash> _layerPairCache;

    // NPC Layering data (Feature 3)
    std::unordered_map<ObjectGuid::LowType, LayerAssignment> _npcLayers;

    // GameObject Layering data (Feature 3b)
    std::unordered_map<ObjectGuid::LowType, LayerAssignment> _goLayers;

    // Dynamic resize throttling
    std::unordered_map<uint32, uint64> _lastResizeMs;

    // Layer switch cooldown tracking (Phase 5 - WoW-style)
    // Escalating cooldowns: 1min -> 2min -> 5min -> 10min
    struct LayerSwitchCooldown
    {
        uint64 lastSwitchMs = 0;       // Timestamp of last switch
        uint32 switchCount = 0;        // Number of switches in cooldown window
        static constexpr uint64 COOLDOWN_WINDOW_MS = 3600000;  // 1 hour window
        static constexpr uint32 BASE_COOLDOWN_MS = 60000;      // 1 minute base
        
        uint32 GetCurrentCooldownMs() const {
            if (switchCount == 0) return 0;
            if (switchCount == 1) return BASE_COOLDOWN_MS;          // 1 min
            if (switchCount == 2) return BASE_COOLDOWN_MS * 2;      // 2 min
            if (switchCount <= 5) return BASE_COOLDOWN_MS * 5;      // 5 min
            return BASE_COOLDOWN_MS * 10;                           // 10 min max
        }
        
        bool CanSwitch(uint64 nowMs) const {
            if (switchCount == 0) return true;
            return (nowMs - lastSwitchMs) >= GetCurrentCooldownMs();
        }
        
        uint32 GetRemainingCooldownMs(uint64 nowMs) const {
            if (switchCount == 0) return 0;
            uint64 elapsed = nowMs - lastSwitchMs;
            uint32 cooldown = GetCurrentCooldownMs();
            return elapsed >= cooldown ? 0 : static_cast<uint32>(cooldown - elapsed);
        }
        
        void RecordSwitch(uint64 nowMs) {
            // Reset counter if outside cooldown window
            if (switchCount > 0 && (nowMs - lastSwitchMs) > COOLDOWN_WINDOW_MS)
                switchCount = 0;
            
            lastSwitchMs = nowMs;
            ++switchCount;
        }
    };
    mutable std::mutex _cooldownLock;
    std::unordered_map<ObjectGuid::LowType, LayerSwitchCooldown> _layerSwitchCooldowns;

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

    // Throttle for periodic cleanup (atomic for thread safety across map threads)
    std::atomic<uint64> _lastCleanupMs{0};

    // Helper to get cached grid layout (lock must be held)
    PartitionGridLayout const* GetGridLayout(uint32 mapId) const;
    
    // Helper to compute grid layout from partition count
    PartitionGridLayout ComputeGridLayout(uint32 count) const;
    
    // Helper to cleanup empty layer containers (lock must be held)
    void CleanupEmptyLayers(uint32 mapId, uint32 zoneId, uint32 layerId);

    std::atomic<bool> _layerPersistenceEnabled{true};

public:
    // Back-compat helper for scripts
    void SetLayerPersistenceEnabled(bool enabled) { _layerPersistenceEnabled.store(enabled, std::memory_order_relaxed); }
    bool IsLayerPersistenceEnabled() const { return _layerPersistenceEnabled.load(std::memory_order_relaxed); }
    PartitionGridLayout const* GetCachedLayout(uint32 mapId) const;

private:
    // Phase 6: Layer Rebalancing private members
    LayerRebalancingConfig _rebalancingConfig;
    mutable RebalancingMetrics _rebalancingMetrics;
    std::unordered_map<uint64, uint64> _lastRebalanceCheck;  // (mapId<<32|zoneId) -> timestampMs
    
    std::atomic<bool> _runtimeDiagnostics{false};
    std::atomic<uint64> _runtimeDiagnosticsUntilMs{0};
};

#define sPartitionMgr PartitionManager::instance()

#endif // AC_PARTITION_MANAGER_H
