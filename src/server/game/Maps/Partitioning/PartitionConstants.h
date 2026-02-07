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

#ifndef AC_PARTITION_CONSTANTS_H
#define AC_PARTITION_CONSTANTS_H

#include "Define.h"
#include <atomic>
#include <map>

// ======================== CACHE & TIMING CONSTANTS ========================
namespace PartitionConst
{
    // Thread-local cache TTL values (milliseconds)
    constexpr uint64 PLAYER_LAYER_CACHE_TTL_MS = 250;
    constexpr uint64 NPC_LAYER_CACHE_TTL_MS = 250;
    constexpr uint64 GO_LAYER_CACHE_TTL_MS = 250;
    constexpr uint64 PARTY_LAYER_CACHE_TTL_MS = 1000;
    constexpr uint64 LAYER_PAIR_CACHE_TTL_MS = 200;
    
    // Cleanup thresholds
    constexpr uint64 BOUNDARY_APPROACH_CACHE_TTL_MS = 30000;
    constexpr uint64 PRECACHE_RECENT_TTL_MS = 30000;
    constexpr uint64 PRECACHE_REQUEST_MAX_AGE_MS = 15000;
    constexpr size_t ZONE_EXCLUDED_CACHE_LIMIT = 1024;
    constexpr size_t LAYER_PAIR_CACHE_LIMIT = 2048;
    constexpr size_t PRECACHE_QUEUE_LIMIT = 256;
    
    // Processing limits per tick
    constexpr uint32 MAX_PRECACHE_REQUESTS_PER_TICK = 2;
    constexpr uint64 BOUNDARY_APPROACH_CHECK_INTERVAL_MS = 200;
    
    // Resize throttling
    constexpr uint64 RESIZE_COOLDOWN_MS = 10000;
    
    // Rebalance check interval (should match config but used for throttling)
    constexpr uint64 REBALANCE_CHECK_MIN_INTERVAL_MS = 5000;
    
    // Layer switching cooldowns (milliseconds)
    constexpr uint64 LAYER_SWITCH_COOLDOWN_BASE_MS = 60000;      // 1 minute
    constexpr uint64 LAYER_SWITCH_COOLDOWN_TIER2_MS = 120000;    // 2 minutes
    constexpr uint64 LAYER_SWITCH_COOLDOWN_TIER3_MS = 300000;    // 5 minutes
    constexpr uint64 LAYER_SWITCH_COOLDOWN_MAX_MS = 600000;      // 10 minutes
}

// ======================== THREAD-LOCAL CACHE TEMPLATE ========================
// Reusable template for layer lookup caches, reducing code duplication
template<typename KeyT>
struct ThreadLocalLayerCache
{
    KeyT key{};
    uint32 mapId = 0;
    uint32 layerId = 0;
    uint64 expiresMs = 0;
    bool valid = false;
    
    bool IsValid(KeyT checkKey, uint32 checkMap, uint64 nowMs) const
    {
        return valid && key == checkKey && mapId == checkMap && nowMs <= expiresMs;
    }
    
    void Set(KeyT newKey, uint32 newMap, uint32 newLayer, uint64 expiry)
    {
        key = newKey;
        mapId = newMap;
        layerId = newLayer;
        expiresMs = expiry;
        valid = true;
    }
    
    void Invalidate() { valid = false; }
};

// Simpler version for guid-only lookups
template<typename KeyT>
struct ThreadLocalSimpleLayerCache
{
    KeyT key{};
    uint32 layerId = 0;
    uint64 expiresMs = 0;
    
    bool IsValid(KeyT checkKey, uint64 nowMs) const
    {
        return key == checkKey && nowMs <= expiresMs;
    }
    
    void Set(KeyT newKey, uint32 newLayer, uint64 expiry)
    {
        key = newKey;
        layerId = newLayer;
        expiresMs = expiry;
    }
};

// ======================== SHARED LAYER TYPES ========================

// Layer rebalancing configuration (used by both LayerManager and PartitionManager)
struct LayerRebalancingConfig
{
    bool enabled{true};
    uint32 checkIntervalMs{300000};   // 5 minutes
    uint32 minPlayersPerLayer{5};
    float imbalanceThreshold{0.3f};   // CV > 30%
    uint32 migrationBatchSize{10};
};

// Rebalancing metrics for monitoring (uses atomics for thread-safe counters)
struct RebalancingMetrics
{
    std::atomic<uint32> totalRebalances{0};
    std::atomic<uint32> playersMigrated{0};
    std::atomic<uint32> layersConsolidated{0};
};

// Type alias for layer counts by zone: ZoneId -> LayerId -> Count
using LayerCountByZone = std::map<uint32, std::map<uint32, uint32>>;

#endif // AC_PARTITION_CONSTANTS_H
