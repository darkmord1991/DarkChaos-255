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

#ifndef AC_LAYER_MANAGER_H
#define AC_LAYER_MANAGER_H

#include "DatabaseEnvFwd.h"
#include "Define.h"
#include "ObjectGuid.h"
#include "PartitionConstants.h"
#include <atomic>
#include <map>
#include <memory>
#include <mutex>
#include <shared_mutex>
#include <unordered_map>
#include <unordered_set>
#include <vector>

/**
 * @brief LayerManager handles all layering logic for high-population areas.
 * 
 * Layering creates virtual copies of maps (continents) to prevent overcrowding:
 * - Players are assigned to layers on map entry (Blizzard-style, map-wide)
 * - Zone changes do NOT trigger layer reassignment
 * - NPCs and GameObjects can optionally be layered
 * - Parties sync to leader's layer
 * - Automatic rebalancing consolidates sparse layers
 */
class LayerManager
{
public:
    static LayerManager* instance();

    // ======================== CONFIGURATION ========================
    bool IsLayeringEnabled() const;
    uint32 GetLayerCapacity() const;           // Global default
    uint32 GetLayerCapacity(uint32 mapId) const; // Per-map override (falls back to global)
    uint32 GetLayerMax() const;
    bool IsNPCLayeringEnabled() const;
    bool IsGOLayeringEnabled() const;
    bool SkipCloneSpawnsIfNoPlayers() const;
    bool EmitPerLayerCloneMetrics() const;
    bool LazyCloneLoadingEnabled() const;
    bool IsSoftTransfersEnabled() const;
    uint32 GetSoftTransferTimeoutMs() const;
    uint32 GetHysteresisCreationWarmupMs() const;
    uint32 GetHysteresisDestructionCooldownMs() const;
    void ParsePerMapCapacityOverrides();
    void LoadConfig();
    
    // ======================== PLAYER LAYER QUERIES ========================
    // Blizzard-style: layers are map-wide (continent-wide), not per-zone.
    // Players stay on the same layer across all zones of a map.
    uint32 GetLayerForPlayer(uint32 mapId, ObjectGuid const& playerGuid) const;
    uint32 GetPlayerLayer(uint32 mapId, ObjectGuid const& playerGuid) const; // Alias
    uint32 GetLayerCount(uint32 mapId) const;
    std::vector<uint32> GetLayerIds(uint32 mapId) const;
    void GetActiveLayerIds(uint32 mapId, std::vector<uint32>& out) const;
    bool HasPlayersOnMap(uint32 mapId) const;
    
    // Combined lookups (single lock acquisition)
    std::pair<uint32, uint32> GetLayersForTwoPlayers(uint32 mapId,
        ObjectGuid const& player1, ObjectGuid const& player2) const;
    void GetPlayerAndNPCLayer(uint32 mapId, ObjectGuid const& playerGuid,
        ObjectGuid const& npcGuid, uint32& outPlayerLayer, uint32& outNpcLayer) const;
    void GetPlayerAndGOLayer(uint32 mapId, ObjectGuid const& playerGuid,
        ObjectGuid const& goGuid, uint32& outPlayerLayer, uint32& outGoLayer) const;

    // ======================== PLAYER LAYER ASSIGNMENT ========================
    void AssignPlayerToLayer(uint32 mapId, ObjectGuid const& playerGuid, uint32 layerId);
    void RemovePlayerFromLayer(uint32 mapId, ObjectGuid const& playerGuid);
    void AutoAssignPlayerToLayer(uint32 mapId, ObjectGuid const& playerGuid);
    void ForceRemovePlayerFromAllLayers(ObjectGuid const& playerGuid);

    // ======================== NPC LAYERING ========================
    void AssignNPCToLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& npcGuid, uint32 layerId);
    void RemoveNPCFromLayer(uint32 mapId, ObjectGuid const& npcGuid);
    uint32 GetLayerForNPC(uint32 mapId, ObjectGuid const& npcGuid) const;
    uint32 GetLayerForNPC(ObjectGuid const& npcGuid) const; // Back-compat
    uint32 GetDefaultLayerForMap(uint32 mapId, uint64 seed) const;

    // ======================== GAMEOBJECT LAYERING ========================
    void AssignGOToLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& goGuid, uint32 layerId);
    void RemoveGOFromLayer(uint32 mapId, ObjectGuid const& goGuid);
    uint32 GetLayerForGO(uint32 mapId, ObjectGuid const& goGuid) const;
    uint32 GetLayerForGO(ObjectGuid const& goGuid) const;

    // ======================== LAYER STATISTICS ========================
    using LayerCountByZone = std::map<uint32, std::map<uint32, uint32>>;
    void GetNPCLayerCountsByZone(uint32 mapId, LayerCountByZone& out) const;
    void GetGOLayerCountsByZone(uint32 mapId, LayerCountByZone& out) const;
    void GetLayerPlayerCountsByLayer(uint32 mapId, std::map<uint32, uint32>& out) const;
    std::vector<uint32> GetLayerPlayerCounts(uint32 mapId) const;

    // ======================== PARTY SYNC ========================
    uint32 GetPartyTargetLayer(uint32 mapId, ObjectGuid const& playerGuid);

    // ======================== LAYER SWITCHING (WoW-style) ========================
    bool CanSwitchLayer(ObjectGuid const& playerGuid) const;
    uint32 GetLayerSwitchCooldownMs(ObjectGuid const& playerGuid) const;
    bool SwitchPlayerToLayer(ObjectGuid const& playerGuid, uint32 targetLayer, std::string const& reason);
    bool CreateLayer(uint32 mapId, uint32 layerId, std::string const& reason);

    // ======================== LAYER PERSISTENCE ========================
    void LoadPersistentLayerAssignment(ObjectGuid const& playerGuid);
    void SavePersistentLayerAssignment(ObjectGuid const& playerGuid, uint32 mapId, uint32 layerId);
    void SetLayerPersistenceEnabled(bool enabled) { _layerPersistenceEnabled.store(enabled, std::memory_order_relaxed); }
    bool IsLayerPersistenceEnabled() const { return _layerPersistenceEnabled.load(std::memory_order_relaxed); }

    // ======================== LAYER REBALANCING ========================
    // Note: LayerRebalancingConfig and RebalancingMetrics are defined in PartitionConstants.h
    
    void LoadRebalancingConfig();
    void EvaluateLayerRebalancing(uint32 mapId);
    void ConsolidateLayers(uint32 mapId, uint32 sourceLayerId, uint32 targetLayerId);
    LayerRebalancingConfig const& GetRebalancingConfig() const;
    RebalancingMetrics const& GetRebalancingMetrics() const;

    // ======================== SOFT TRANSFERS ========================
    // Queue layer moves for next loading screen instead of instant switches.
    void ProcessPendingSoftTransfers();
    void ProcessSoftTransferForPlayer(ObjectGuid const& playerGuid);
    bool HasPendingSoftTransfer(ObjectGuid const& playerGuid) const;
    uint32 GetPendingSoftTransferCount() const;

    // ======================== UPDATE ========================
    void Update(uint32 mapId, uint32 diff);

    // ======================== DIAGNOSTICS ========================
    bool IsRuntimeDiagnosticsEnabled() const;
    void SetRuntimeDiagnosticsEnabled(bool enabled);
    bool ShouldEmitRegenMetrics() const;
    uint64 GetRuntimeDiagnosticsRemainingMs() const;

private:
    LayerManager() = default;

    // Helper functions
    void SyncControlledToLayer(uint32 mapId, ObjectGuid const& playerGuid, uint32 layerId);
    void ReassignNPCsForNewLayer(uint32 mapId, uint32 layerId);
    void ReassignGOsForNewLayer(uint32 mapId, uint32 layerId);
    void HandlePersistentLayerAssignmentLoad(ObjectGuid const& playerGuid, PreparedQueryResult result);
    bool CleanupEmptyLayers(uint32 mapId, uint32 layerId);
    void DespawnLayerClones(uint32 mapId, uint32 layerId);
    void BalanceLayersAtMax(uint32 mapId);
    void RebalanceBotLayers(uint32 mapId);
    void ProcessPendingLayerAssignments();

    // Persistence toggle (used inline, so kept here)
    std::atomic<bool> _layerPersistenceEnabled{true};

    // ======================== DATA STRUCTURES (Moved from PartitionManager) ========================
private:
    using LayerKey = uint64;

    static LayerKey MakeLayerKey(uint32 mapId, ObjectGuid const& guid)
    {
        return (static_cast<LayerKey>(mapId) << 32) |
               static_cast<LayerKey>(guid.GetCounter());
    }

    struct LayerAssignment
    {
        uint32 mapId = 0;
        uint32 zoneId = 0;
        uint32 layerId = 0;
        uint32 entry = 0;
    };

    struct AtomicLayerAssignment
    {
        // Packs map/layer into a single atomic uint64 for lock-free reads.
        // Blizzard-style: layers are map-wide, so no zoneId needed.
        std::atomic<uint64> packed{0};  // [mapId:32][layerId:32]
        
        void Store(uint32 mapId, uint32 layerId) {
            uint64 value = (static_cast<uint64>(mapId) << 32) |
                          static_cast<uint64>(layerId);
            packed.store(value, std::memory_order_release);
        }
        
        void Load(uint32& mapId, uint32& layerId) const {
            uint64 value = packed.load(std::memory_order_acquire);
            mapId = static_cast<uint32>(value >> 32);
            layerId = static_cast<uint32>(value & 0xFFFFFFFF);
        }
        
        void Clear() {
            packed.store(0, std::memory_order_release);
        }
        
        bool IsValid() const {
            return packed.load(std::memory_order_relaxed) != 0;
        }
    };

    struct PartyTargetLayerCacheEntry
    {
        uint32 mapId = 0;
        uint32 layerId = 0;
        uint64 expiresMs = 0;
    };

    struct LayerPairCacheKey
    {
        uint32 mapId = 0;
        ObjectGuid::LowType a = 0;
        ObjectGuid::LowType b = 0;

        bool operator==(LayerPairCacheKey const& other) const
        {
            return mapId == other.mapId && a == other.a && b == other.b;
        }
    };

    struct LayerPairCacheKeyHash
    {
        size_t operator()(LayerPairCacheKey const& key) const
        {
            size_t h1 = std::hash<uint32>{}(key.mapId);
            size_t h3 = std::hash<ObjectGuid::LowType>{}(key.a);
            size_t h4 = std::hash<ObjectGuid::LowType>{}(key.b);
            return (h1 * 2654435761u) ^ (h3 + (h4 << 1));
        }
    };

    struct LayerPairCacheEntry
    {
        uint32 layer1 = 0;
        uint32 layer2 = 0;
        uint64 expiresMs = 0;
    };

    struct LayerSwitchCooldown
    {
        uint64 lastSwitchMs = 0;       // Timestamp of last switch
        uint32 switchCount = 0;        // Number of switches in cooldown window
        static constexpr uint64 COOLDOWN_WINDOW_MS = 3600000;  // 1 hour window
        
        uint32 GetCurrentCooldownMs() const {
            if (switchCount == 0) return 0;
            if (switchCount == 1) return static_cast<uint32>(PartitionConst::LAYER_SWITCH_COOLDOWN_BASE_MS);
            if (switchCount == 2) return static_cast<uint32>(PartitionConst::LAYER_SWITCH_COOLDOWN_TIER2_MS);
            if (switchCount <= 5) return static_cast<uint32>(PartitionConst::LAYER_SWITCH_COOLDOWN_TIER3_MS);
            return static_cast<uint32>(PartitionConst::LAYER_SWITCH_COOLDOWN_MAX_MS);
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

        // Returns true when cooldown window has fully elapsed (used for cleanup sweeps)
        bool IsReady(uint64 nowMs) const {
            if (switchCount == 0) return true;
            return (nowMs - lastSwitchMs) > COOLDOWN_WINDOW_MS;
        }
    };

    struct PendingLayerAssignment
    {
        uint32 mapId = 0;
        uint32 layerId = 0;
        uint64 readyMs = 0;
        uint32 retryCount = 0;
        static constexpr uint32 MAX_RETRIES = 30; // ~30 seconds at 1s retry interval
    };

    // Soft transfer: queued layer move applied on next loading screen (teleport / map change)
    struct SoftTransferEntry
    {
        uint32 mapId = 0;
        uint32 sourceLayerId = 0;
        uint32 targetLayerId = 0;
        uint64 queuedMs = 0;        // When the transfer was queued
        std::string reason;
    };

    // Hysteresis: timestamps tracking when a layer creation/destruction was first requested
    struct HysteresisState
    {
        uint64 creationRequestMs = 0;     // 0 = no pending creation
        uint64 destructionRequestMs = 0;  // 0 = no pending destruction
    };

    // Layering data: Map -> Layer -> Set of player GUIDs
    // Blizzard-style: layers are map-wide (continent-wide), not per-zone.
    std::unordered_map<uint32, std::unordered_map<uint32, std::unordered_set<ObjectGuid::LowType>>> _layers;
    std::unordered_map<ObjectGuid::LowType, LayerAssignment> _playerLayers;
    std::unordered_map<ObjectGuid::LowType, AtomicLayerAssignment> _atomicPlayerLayers;
    std::unordered_map<ObjectGuid::LowType, PartyTargetLayerCacheEntry> _partyTargetLayerCache;
    std::unordered_map<LayerKey, LayerAssignment> _npcLayers;
    std::unordered_map<LayerKey, LayerAssignment> _goLayers;
    // Reverse index: (mapId, layerId) -> set of LayerKeys for O(1) cleanup in CleanupEmptyLayers
    std::unordered_map<uint64, std::unordered_set<LayerKey>> _npcLayerIndex; // key = (mapId<<32)|layerId
    std::unordered_map<uint64, std::unordered_set<LayerKey>> _goLayerIndex;  // key = (mapId<<32)|layerId
    std::unordered_map<ObjectGuid::LowType, PendingLayerAssignment> _pendingLayerAssignments;
    std::unordered_map<ObjectGuid::LowType, LayerSwitchCooldown> _layerSwitchCooldowns;
    std::unordered_map<ObjectGuid::LowType, SoftTransferEntry> _pendingSoftTransfers;
    std::unordered_map<uint32, HysteresisState> _hysteresisState; // mapId -> state
    std::unordered_map<uint32, uint32> _perMapCapacity;           // mapId -> capacity override

    // Locks
    // LOCK ORDER INVARIANT (always acquire in this order to prevent deadlock):
    //   _layerLock  ->  _cooldownLock  (via ForceRemovePlayerFromAllLayers)
    //   _layerLock  ->  _partyLayerCacheLock  (via ForceRemovePlayerFromAllLayers)
    //   _layerLock  ->  _hysteresisLock  (via AutoAssignPlayerToLayer, EvaluateLayerRebalancing)
    //   _softTransferLock is independent (never held together with _layerLock)
    //   _rebalanceCheckLock is independent (lightweight timestamp guard)
    // NEVER acquire _layerLock while already holding a Map/MapMgr lock.
    mutable std::shared_mutex _layerLock;
    mutable std::mutex _partyLayerCacheLock;
    mutable std::mutex _pendingLayerAssignmentLock;
    mutable std::mutex _cooldownLock;
    mutable std::mutex _softTransferLock;
    mutable std::mutex _hysteresisLock;

    // Rebalancing
    LayerRebalancingConfig _rebalancingConfig;
    mutable RebalancingMetrics _rebalancingMetrics;
    mutable std::mutex _rebalanceCheckLock;
    std::unordered_map<uint32, uint64> _lastRebalanceCheck;
    
    // Diagnostics
    std::atomic<bool> _runtimeDiagnostics{false};
    std::atomic<uint64> _runtimeDiagnosticsUntilMs{0};
    std::atomic<uint64> _lastCleanupMs{0};
    std::atomic<uint64> _lastSoftTransferCheckMs{0};

    struct Config
    {
        bool enabled = false;
        uint32 capacity = 0;
        uint32 maxLayers = 0;
        bool npcLayering = false;
        bool goLayering = false;
        bool skipCloneSpawnsIfNoPlayers = false;
        bool emitPerLayerCloneMetrics = false;
        bool lazyCloneLoading = false;
        bool softTransfersEnabled = false;
        uint32 softTransferTimeoutMs = 0;
        uint32 hysteresisCreationWarmupMs = 0;
        uint32 hysteresisDestructionCooldownMs = 0;
    } _config;

    void PeriodicCacheSweep();
};

#define sLayerMgr LayerManager::instance()

#endif // AC_LAYER_MANAGER_H
