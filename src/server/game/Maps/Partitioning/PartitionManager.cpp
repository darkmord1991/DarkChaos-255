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

#include "PartitionManager.h"
#include "World.h"
#include "WorldConfig.h"
#include "Log.h"
#include "Grids/GridDefines.h"
#include "GameTime.h"
#include "DatabaseEnv.h"
#include "QueryResult.h"
#include "Group.h"
#include "GroupMgr.h"
#include "Pet.h"
#include "Player.h"
#include "Chat.h"
#include "GridDefines.h"
#include "Map.h"
#include "MapMgr.h"
#include "ObjectAccessor.h"
#include "Position.h"
#include <algorithm>
#include <cmath>
#include <limits>
#include <sstream>

PartitionManager* PartitionManager::instance()
{
    static PartitionManager instance;
    return &instance;
}

bool PartitionManager::IsEnabled() const
{
    return sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_ENABLED);
}

float PartitionManager::GetBorderOverlap() const
{
    return sWorld->getFloatConfig(CONFIG_MAP_PARTITIONS_BORDER_OVERLAP);
}

bool PartitionManager::UsePartitionStoreOnly() const
{
    return sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_STORE_ONLY);
}

bool PartitionManager::IsZoneExcluded(uint32_t zoneId) const
{
    {
        std::lock_guard<std::mutex> cacheGuard(_excludedCacheLock);
        if (auto it = _zoneExcludedCache.find(zoneId); it != _zoneExcludedCache.end())
            return it->second;
    }

    bool excluded = false;
    {
        std::shared_lock<std::shared_mutex> guard(_partitionLock);
        excluded = _excludedZones.count(zoneId) > 0;
    }

    {
        std::lock_guard<std::mutex> cacheGuard(_excludedCacheLock);
        _zoneExcludedCache[zoneId] = excluded;
    }

    return excluded;
}

bool PartitionManager::IsLayeringEnabled() const
{
    return sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_LAYERS_ENABLED);
}

uint32_t PartitionManager::GetLayerCapacity() const
{
    return sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_CAPACITY);
}

uint32_t PartitionManager::GetLayerMax() const
{
    return sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_MAX);
}

bool PartitionManager::IsRuntimeDiagnosticsEnabled() const
{
    return _runtimeDiagnostics.load(std::memory_order_relaxed);
}

void PartitionManager::SetRuntimeDiagnosticsEnabled(bool enabled)
{
    _runtimeDiagnostics.store(enabled, std::memory_order_relaxed);
    if (enabled)
        _runtimeDiagnosticsUntilMs.store(GameTime::GetGameTimeMS().count() + 60000, std::memory_order_relaxed);
    else
        _runtimeDiagnosticsUntilMs.store(0, std::memory_order_relaxed);
    LOG_INFO("map.partition", "Runtime diagnostics {}", enabled ? "enabled" : "disabled");
}

void PartitionManager::SyncControlledToLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& playerGuid, uint32 layerId)
{
    if (!IsNPCLayeringEnabled())
        return;

    Player* player = ObjectAccessor::FindPlayer(playerGuid);
    if (!player || !player->IsInWorld())
        return;

    if (Pet* pet = player->GetPet())
        if (pet->IsInWorld())
            AssignNPCToLayer(mapId, zoneId, pet->GetGUID(), layerId);

    if (Guardian* guardian = player->GetGuardianPet())
        if (guardian->IsInWorld())
            AssignNPCToLayer(mapId, zoneId, guardian->GetGUID(), layerId);

    if (Unit* charmed = player->GetCharm())
        if (Creature* charmedCreature = charmed->ToCreature())
            if (charmedCreature->IsInWorld())
                AssignNPCToLayer(mapId, zoneId, charmedCreature->GetGUID(), layerId);
}

bool PartitionManager::ShouldEmitRegenMetrics() const
{
    if (!IsRuntimeDiagnosticsEnabled())
        return false;

    uint64 until = _runtimeDiagnosticsUntilMs.load(std::memory_order_relaxed);
    if (!until)
        return false;

    return static_cast<uint64>(GameTime::GetGameTimeMS().count()) <= until;
}

uint64 PartitionManager::GetRuntimeDiagnosticsRemainingMs() const
{
    if (!IsRuntimeDiagnosticsEnabled())
        return 0;

    uint64 until = _runtimeDiagnosticsUntilMs.load(std::memory_order_relaxed);
    if (!until)
        return 0;

    uint64 now = static_cast<uint64>(GameTime::GetGameTimeMS().count());
    return now >= until ? 0 : (until - now);
}

uint32_t PartitionManager::GetLayerForPlayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid) const
{
    struct PlayerLayerCache
    {
        ObjectGuid::LowType guid = 0;
        uint32 mapId = 0;
        uint32 zoneId = 0;
        uint32 layerId = 0;
        uint64 expiresMs = 0;
    };

    thread_local PlayerLayerCache cache;
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    if (cache.guid == playerGuid.GetCounter() && cache.mapId == mapId && cache.zoneId == zoneId && nowMs <= cache.expiresMs)
        return cache.layerId;

    // Fast path: try lock-free atomic read under shared_lock (protects the map container
    // while the atomic values inside are read without additional synchronization)
    {
        std::shared_lock<std::shared_mutex> guard(_layerLock);
        auto atomicIt = _atomicPlayerLayers.find(playerGuid.GetCounter());
        if (atomicIt != _atomicPlayerLayers.end())
        {
            uint32 storedMapId, storedZoneId, storedLayerId;
            atomicIt->second.Load(storedMapId, storedZoneId, storedLayerId);
            if (storedMapId == mapId && storedZoneId == zoneId)
            {
                cache = { playerGuid.GetCounter(), mapId, zoneId, storedLayerId, nowMs + 250 };
                return storedLayerId;
            }
        }

        // Fallback to regular lookup (different map/zone or not in atomic map)
        auto it = _playerLayers.find(playerGuid.GetCounter());
        if (it != _playerLayers.end())
        {
            if (it->second.mapId == mapId && it->second.zoneId == zoneId)
            {
                cache = { playerGuid.GetCounter(), mapId, zoneId, it->second.layerId, nowMs + 250 };
                return it->second.layerId;
            }
        }
    }
    cache = { playerGuid.GetCounter(), mapId, zoneId, 0, nowMs + 250 };
    return 0; // Default layer
}

uint32 PartitionManager::GetPlayerLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& playerGuid) const
{
    return GetLayerForPlayer(mapId, zoneId, playerGuid);
}

uint32_t PartitionManager::GetLayerCount(uint32_t mapId, uint32_t zoneId) const
{
    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto mapIt = _layers.find(mapId);
    if (mapIt != _layers.end())
    {
        auto zoneIt = mapIt->second.find(zoneId);
        if (zoneIt != mapIt->second.end())
            return zoneIt->second.size();
    }
    return 1; // Always at least default layer
}

void PartitionManager::AssignPlayerToLayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid, uint32_t layerId)
{
    {
        std::unique_lock<std::shared_mutex> guard(_layerLock);

        // Remove from old layer if exists
        auto it = _playerLayers.find(playerGuid.GetCounter());
        if (it != _playerLayers.end())
        {
            auto& oldLayer = _layers[it->second.mapId][it->second.zoneId][it->second.layerId];
            oldLayer.erase(playerGuid.GetCounter());
            CleanupEmptyLayers(it->second.mapId, it->second.zoneId, it->second.layerId);
        }

        // Assign to new
        _layers[mapId][zoneId][layerId].insert(playerGuid.GetCounter());
        _playerLayers[playerGuid.GetCounter()] = { mapId, zoneId, layerId };
        
        // Sync atomic for lock-free reads (Phase 1 optimization)
        _atomicPlayerLayers[playerGuid.GetCounter()].Store(mapId, zoneId, layerId);

        if (IsRuntimeDiagnosticsEnabled())
        {
            LOG_INFO("map.partition", "Diag: AssignPlayerToLayer player={} map={} zone={} layer={}",
                playerGuid.ToString(), mapId, zoneId, layerId);
        }
    }  // Release _layerLock before SyncControlledToLayer to avoid recursive lock deadlock

    SyncControlledToLayer(mapId, zoneId, playerGuid, layerId);
}

void PartitionManager::RemovePlayerFromLayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid)
{
    std::unique_lock<std::shared_mutex> guard(_layerLock);
    
    auto it = _playerLayers.find(playerGuid.GetCounter());
    if (it == _playerLayers.end())
        return;

    // Verify map/zone match
    if (it->second.mapId != mapId || it->second.zoneId != zoneId)
        return;

    auto& layer = _layers[mapId][zoneId][it->second.layerId];
    layer.erase(playerGuid.GetCounter());
    CleanupEmptyLayers(mapId, zoneId, it->second.layerId);

    _playerLayers.erase(it);
    
    // Clear atomic for lock-free reads (Phase 1 optimization)
    auto atomicIt = _atomicPlayerLayers.find(playerGuid.GetCounter());
    if (atomicIt != _atomicPlayerLayers.end())
        atomicIt->second.Clear();

    if (IsRuntimeDiagnosticsEnabled())
    {
        LOG_INFO("map.partition", "Diag: RemovePlayerFromLayer player={} map={} zone={}",
            playerGuid.ToString(), mapId, zoneId);
    }
}

void PartitionManager::AutoAssignPlayerToLayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid)
{
    if (!IsLayeringEnabled())
        return;

    // First check if party member should sync to leader's layer (outside of lock to avoid deadlock)
    uint32 partyTargetLayer = GetPartyTargetLayer(mapId, zoneId, playerGuid);

    uint32 assignedLayerId = 0;
    bool shouldSync = false;
    bool createdNewLayer = false;

    {
        std::unique_lock<std::shared_mutex> guard(_layerLock);

        // If player is already assigned to a layer in this zone, keep them there (stickiness)
        auto it = _playerLayers.find(playerGuid.GetCounter());
        if (it != _playerLayers.end() && it->second.mapId == mapId && it->second.zoneId == zoneId)
        {
            // If party leader is on a different layer, move to match them
            if (partyTargetLayer > 0 && it->second.layerId != partyTargetLayer)
            {
                // Remove from old layer
                auto& oldLayerPlayers = _layers[mapId][zoneId][it->second.layerId];
                uint32 oldLayerPartyId = it->second.layerId;
                oldLayerPlayers.erase(playerGuid.GetCounter());

                if (oldLayerPlayers.empty())
                    CleanupEmptyLayers(mapId, zoneId, oldLayerPartyId);
                
                // Assign to party leader's layer
                _layers[mapId][zoneId][partyTargetLayer].insert(playerGuid.GetCounter());
                _playerLayers[playerGuid.GetCounter()] = { mapId, zoneId, partyTargetLayer };
                
                LOG_DEBUG("map.partition", "Player {} moved to party leader's Layer {} in Map {} Zone {}", 
                    playerGuid.ToString(), partyTargetLayer, mapId, zoneId);

                if (IsRuntimeDiagnosticsEnabled())
                {
                    LOG_INFO("map.partition", "Diag: AutoAssignPlayerToLayer player={} map={} zone={} layer={} reason=party",
                        playerGuid.ToString(), mapId, zoneId, partyTargetLayer);
                }
                
                assignedLayerId = partyTargetLayer;
                shouldSync = true;
            }
            else
            {
                return;  // Already on correct layer
            }
        }

    // If they were in a different zone/map, remove old assignment first
    if (it != _playerLayers.end())
    {
        uint32 oldMapId = it->second.mapId;
        uint32 oldZoneId = it->second.zoneId;
        uint32 oldLayerId = it->second.layerId;

        auto& oldLayer = _layers[oldMapId][oldZoneId][oldLayerId];
        oldLayer.erase(playerGuid.GetCounter());

        if (oldLayer.empty())
            CleanupEmptyLayers(oldMapId, oldZoneId, oldLayerId);

        _playerLayers.erase(it);
    }

    uint32_t bestLayerId = 0;
    bool foundLayer = false;

    // Priority 1: Party leader's layer (if available)
    if (partyTargetLayer > 0)
    {
        bestLayerId = partyTargetLayer;
        foundLayer = true;
        LOG_DEBUG("map.partition", "Player {} joining party leader's Layer {} in Map {} Zone {}", 
            playerGuid.ToString(), bestLayerId, mapId, zoneId);
    }
    else
    {
        // Priority 2: Find first layer with capacity
        auto& zoneLayers = _layers[mapId][zoneId];
        
        // Check existing layers first (prioritize filling gaps)
        for (auto const& [layerId, players] : zoneLayers)
        {
            if (players.size() < GetLayerCapacity())
            {
                if (!foundLayer || layerId < bestLayerId)
                {
                    bestLayerId = layerId;
                    foundLayer = true;
                }
            }
        }

        if (!foundLayer)
        {
            // No existing layer has space. Create new one.
            // If no layers yet, use 0.
            if (zoneLayers.empty())
            {
                bestLayerId = 0;
            }
            else
            {
                uint32_t maxId = 0;
                for (auto const& [layerId, _] : zoneLayers)
                {
                    if (layerId > maxId) maxId = layerId;
                }

                uint32_t layerMax = GetLayerMax();
                if (layerMax == 0)
                    layerMax = 1;

                if (zoneLayers.size() >= layerMax)
                {
                    // All layers full; stick to the least populated existing layer.
                    uint32_t bestCount = std::numeric_limits<uint32_t>::max();
                    for (auto const& [layerId, players] : zoneLayers)
                    {
                        if (players.size() < bestCount)
                        {
                            bestCount = static_cast<uint32_t>(players.size());
                            bestLayerId = layerId;
                        }
                    }
                }
                else
                {
                    bestLayerId = maxId + 1;
                    createdNewLayer = true;
                }
            }
        }
    }

    // Assign
    _layers[mapId][zoneId][bestLayerId].insert(playerGuid.GetCounter());
    _playerLayers[playerGuid.GetCounter()] = { mapId, zoneId, bestLayerId };

    // Log new layer assignment if it's not the default layer 0
    if (bestLayerId > 0)
    {
        LOG_DEBUG("map.partition", "Player {} assigned to Layer {} in Map {} Zone {}", 
            playerGuid.ToString(), bestLayerId, mapId, zoneId);
    }

    if (IsRuntimeDiagnosticsEnabled())
    {
        LOG_INFO("map.partition", "Diag: AutoAssignPlayerToLayer player={} map={} zone={} layer={} reason=capacity",
            playerGuid.ToString(), mapId, zoneId, bestLayerId);
    }

        assignedLayerId = bestLayerId;
        shouldSync = true;
    }  // Release lock here

    // Perform DB I/O outside the lock to prevent deadlocks
    if (shouldSync)
    {
        // Save persistent assignment (async) - always save so we can restore on login
        SavePersistentLayerAssignment(playerGuid, mapId, zoneId, assignedLayerId);
        SyncControlledToLayer(mapId, zoneId, playerGuid, assignedLayerId);
    }

    if (createdNewLayer)
    {
        ReassignNPCsForNewLayer(mapId, zoneId);
        ReassignGOsForNewLayer(mapId, zoneId);
    }
}

void PartitionManager::ReassignNPCsForNewLayer(uint32 mapId, uint32 zoneId)
{
    if (!IsNPCLayeringEnabled())
        return;

    std::vector<uint32> layerIds;
    layerIds.reserve(4);

    {
        std::shared_lock<std::shared_mutex> guard(_layerLock);
        auto mapIt = _layers.find(mapId);
        if (mapIt == _layers.end())
            return;

        auto zoneIt = mapIt->second.find(zoneId);
        if (zoneIt == mapIt->second.end() || zoneIt->second.size() < 2)
            return;

        for (auto const& [layerId, _] : zoneIt->second)
            layerIds.push_back(layerId);
    }

    if (layerIds.size() < 2)
        return;

    std::sort(layerIds.begin(), layerIds.end());

    uint32 reassigned = 0;
    {
        std::unique_lock<std::shared_mutex> guard(_layerLock);
        for (auto& [npcLow, assignment] : _npcLayers)
        {
            if (assignment.mapId != mapId || assignment.zoneId != zoneId)
                continue;

            if (assignment.layerId != 0)
                continue;

            uint32 targetLayer = layerIds[static_cast<uint32>(npcLow % layerIds.size())];
            if (targetLayer != assignment.layerId)
            {
                assignment.layerId = targetLayer;
                ++reassigned;
            }
        }
    }

    if (IsRuntimeDiagnosticsEnabled() && reassigned > 0)
    {
        LOG_INFO("map.partition", "Diag: ReassignNPCsForNewLayer map={} zone={} reassigned={}",
            mapId, zoneId, reassigned);
    }
}


bool PartitionManager::IsMapPartitioned(uint32 mapId) const
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    return _partitionedMaps.find(mapId) != _partitionedMaps.end();
}

uint32 PartitionManager::GetPartitionIdForPosition(uint32 mapId, float x, float y) const
{
    PartitionGridLayout layout;
    {
        std::shared_lock<std::shared_mutex> guard(_partitionLock);
        auto it = _gridLayouts.find(mapId);
        if (it != _gridLayouts.end())
        {
            layout = it->second;
        }
        else
        {
            // Compute on-the-fly if not cached
            uint32 count = GetPartitionCount(mapId);
            if (count <= 1)
                return 1;
            layout = ComputeGridLayout(count);
        }
    }

    if (layout.count <= 1)
        return 1;

    GridCoord coord = Acore::ComputeGridCoord(x, y);
    uint32 col = std::min(coord.x_coord / layout.cellWidth, layout.cols - 1);
    uint32 row = std::min(coord.y_coord / layout.cellHeight, layout.rows - 1);

    uint32 index = row * layout.cols + col;
    if (index >= layout.count)
        index = layout.count - 1;

    return index + 1;
}

uint32 PartitionManager::GetPartitionIdForPosition(uint32 mapId, float x, float y, ObjectGuid const& guid) const
{
    if (guid)
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        
        // Fast path: shared lock for read-only lookups (hot path every tick per player)
        {
            std::shared_lock<std::shared_mutex> guard(_overrideLock);
            
            // Check persistent ownership first
            auto ownership = _partitionOwnership.find(guid.GetCounter());
            if (ownership != _partitionOwnership.end() && ownership->second.mapId == mapId)
                return ownership->second.partitionId;
            
            // Check temporary overrides
            auto it = _partitionOverrides.find(guid.GetCounter());
            if (it != _partitionOverrides.end())
            {
                if (it->second.expiresMs >= nowMs)
                    return it->second.partitionId;
                // Expired — will be cleaned up by CleanupExpiredOverrides()
            }
        }
    }

    return GetPartitionIdForPosition(mapId, x, y);
}

uint32 PartitionManager::GetPartitionIdForPosition(uint32 mapId, float x, float y, uint32 zoneId, ObjectGuid const& guid) const
{
    // If this zone is excluded from partitioning (e.g., cities), use partition 1
    if (IsZoneExcluded(zoneId))
        return 1;

    return GetPartitionIdForPosition(mapId, x, y, guid);
}

bool PartitionManager::IsNearPartitionBoundary(uint32 mapId, float x, float y) const
{
    PartitionGridLayout layout;
    {
        std::shared_lock<std::shared_mutex> guard(_partitionLock);
        auto it = _gridLayouts.find(mapId);
        if (it != _gridLayouts.end())
        {
            layout = it->second;
        }
        else
        {
            uint32 count = GetPartitionCount(mapId);
            if (count <= 1)
                return false;
            layout = ComputeGridLayout(count);
        }
    }

    if (layout.count <= 1)
        return false;

    float overlap = GetBorderOverlap();
    uint32 overlapGrids = static_cast<uint32>(std::ceil(overlap / SIZE_OF_GRIDS));
    if (overlapGrids == 0)
        overlapGrids = 1;

    GridCoord coord = Acore::ComputeGridCoord(x, y);
    uint32 col = std::min(coord.x_coord / layout.cellWidth, layout.cols - 1);
    uint32 row = std::min(coord.y_coord / layout.cellHeight, layout.rows - 1);

    uint32 gridMax = MAX_NUMBER_OF_GRIDS;
    uint32 startX = col * layout.cellWidth;
    uint32 endX = std::min(startX + layout.cellWidth - 1, gridMax - 1);
    uint32 startY = row * layout.cellHeight;
    uint32 endY = std::min(startY + layout.cellHeight - 1, gridMax - 1);

    if (coord.x_coord - startX < overlapGrids || endX - coord.x_coord < overlapGrids)
        return true;
    if (coord.y_coord - startY < overlapGrids || endY - coord.y_coord < overlapGrids)
        return true;

    return false;
}

uint32 PartitionManager::GetPartitionCount(uint32 mapId) const
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);

    auto it = _partitionsByMap.find(mapId);
    if (it == _partitionsByMap.end())
        return 0;

    return static_cast<uint32>(it->second.size());
}

void PartitionManager::RegisterPartition(std::unique_ptr<MapPartition> partition)
{
    if (!partition)
        return;

    std::unique_lock<std::shared_mutex> guard(_partitionLock);
    uint32 mapId = partition->GetMapId();
    uint32 partId = partition->GetPartitionId();
    _partitionIndex[mapId][partId] = partition.get();
    _partitionsByMap[mapId].push_back(std::move(partition));
}

void PartitionManager::ClearPartitions(uint32 mapId)
{
    std::unique_lock<std::shared_mutex> guard(_partitionLock);
    _partitionsByMap.erase(mapId);
    _partitionIndex.erase(mapId);
    _gridLayouts.erase(mapId);
    _layoutEpochByMap.erase(mapId);
    
    std::lock_guard<std::mutex> bGuard(_boundaryLock);
    _boundaryObjects.erase(mapId);
}

void PartitionManager::Initialize()
{
    if (!IsEnabled())
        return;

    LOG_WARN("map.partition", "Partitioning enabled. Global singleton safety audit is required.");

    uint32 defaultCount = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_DEFAULT_COUNT);
    if (defaultCount == 0)
        defaultCount = 1;

    std::string_view mapsView = sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_MAPS);
    std::string mapsString(mapsView.begin(), mapsView.end());

    {
        std::unique_lock<std::shared_mutex> guard(_partitionLock);
        _partitionedMaps.clear();
        _partitionsByMap.clear();
        _partitionIndex.clear();
        _gridLayouts.clear();
        _excludedZones.clear();
        _zoneExcludedCache.clear();
        _layoutEpochByMap.clear();
    }
    {
        std::unique_lock<std::shared_mutex> guard(_overrideLock);
        _partitionOwnership.clear();
    }

    // Load excluded zones (cities, hubs) - these zones use a single partition
    std::string_view excludeView = sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_EXCLUDE_ZONES);
    std::string excludeString(excludeView.begin(), excludeView.end());
    if (!excludeString.empty())
    {
        std::istringstream excludeStream(excludeString);
        std::string zoneToken;
        while (std::getline(excludeStream, zoneToken, ','))
        {
            std::string trimmed;
            trimmed.reserve(zoneToken.size());
            for (char c : zoneToken)
            {
                if (c != ' ' && c != '\t' && c != '\n' && c != '\r')
                    trimmed.push_back(c);
            }
            if (trimmed.empty())
                continue;

            try
            {
                uint32 zoneId = static_cast<uint32>(std::stoul(trimmed));
                std::unique_lock<std::shared_mutex> guard(_partitionLock);
                _excludedZones.insert(zoneId);
            }
            catch (std::exception const&)
            {
                LOG_WARN("map.partition", "Invalid zone id '{}' in MapPartitions.ExcludeZones", trimmed);
            }
        }
        LOG_INFO("map.partition", "Loaded {} excluded zones for partitioning", _excludedZones.size());
    }

    if (mapsString.empty())
    {
        LOG_INFO("map.partition", "MapPartitions.Enabled is true, but MapPartitions.Maps is empty.");
        return;
    }

    {
        std::lock_guard<std::mutex> guard(_partyLayerCacheLock);
        _partyTargetLayerCache.clear();
    }
    {
        std::lock_guard<std::mutex> guard(_layerPairCacheLock);
        _layerPairCache.clear();
    }
    {
        std::lock_guard<std::mutex> guard(_precacheLock);
        _boundaryApproachLastCheck.clear();
    }

    std::istringstream stream(mapsString);
    std::string token;
    while (std::getline(stream, token, ','))
    {
        std::string trimmed;
        trimmed.reserve(token.size());
        for (char c : token)
        {
            if (c != ' ' && c != '\t' && c != '\n' && c != '\r')
                trimmed.push_back(c);
        }

        if (trimmed.empty())
            continue;

        uint32 mapId = 0;
        try
        {
            mapId = static_cast<uint32>(std::stoul(trimmed));
        }
        catch (std::exception const&)
        {
            LOG_WARN("map.partition", "Invalid map id '{}' in MapPartitions.Maps", trimmed);
            continue;
        }

        {
            std::unique_lock<std::shared_mutex> guard(_partitionLock);
            _partitionedMaps.insert(mapId);
        }

        ClearPartitions(mapId);
        for (uint32 i = 0; i < defaultCount; ++i)
        {
            auto name = "Partition " + std::to_string(i + 1);
            RegisterPartition(std::make_unique<MapPartition>(mapId, i + 1, name));
        }

        // Cache grid layout for this map
        {
            std::unique_lock<std::shared_mutex> guard(_partitionLock);
            _gridLayouts[mapId] = ComputeGridLayout(defaultCount);
            _layoutEpochByMap[mapId] = 1;
        }

        LOG_INFO("map.partition", "Initialized {} partitions for map {}", defaultCount, mapId);
    }

    if (IsEnabled())
    {
        QueryResult result = CharacterDatabase.Query("SELECT guid, map_id, partition_id FROM dc_character_partition_ownership");
        if (result)
        {
            std::unique_lock<std::shared_mutex> guard(_overrideLock);
            do
            {
                Field* fields = result->Fetch();
                ObjectGuid::LowType guid = fields[0].Get<uint64>();
                uint32 mapId = fields[1].Get<uint32>();
                uint32 partitionId = fields[2].Get<uint32>();
                if (partitionId == 0)
                    continue;
                {
                    std::shared_lock<std::shared_mutex> mapGuard(_partitionLock);
                    if (_partitionedMaps.find(mapId) == _partitionedMaps.end())
                        continue;
                }
                _partitionOwnership[guid] = { mapId, partitionId };
            } while (result->NextRow());
        }
    }
}

bool PartitionManager::GetPersistentPartition(ObjectGuid const& guid, uint32 mapId, uint32& outPartitionId) const
{
    if (!guid)
        return false;

    std::shared_lock<std::shared_mutex> guard(_overrideLock);
    auto it = _partitionOwnership.find(guid.GetCounter());
    if (it == _partitionOwnership.end())
        return false;
    if (it->second.mapId != mapId)
        return false;
    outPartitionId = it->second.partitionId;
    return true;
}

void PartitionManager::PersistPartitionOwnership(ObjectGuid const& guid, uint32 mapId, uint32 partitionId)
{
    if (!guid || !guid.IsPlayer())
        return;

    if (!IsEnabled())
        return;

    bool changed = false;
    uint32 previousMapId = 0;
    bool hadOwnership = false;
    {
        std::unique_lock<std::shared_mutex> guard(_overrideLock);
        auto& ownership = _partitionOwnership[guid.GetCounter()];
        if (ownership.mapId != 0 || ownership.partitionId != 0)
        {
            hadOwnership = true;
            previousMapId = ownership.mapId;
        }
        if (ownership.mapId != mapId || ownership.partitionId != partitionId)
        {
            ownership.mapId = mapId;
            ownership.partitionId = partitionId;
            changed = true;
        }
    }

    if (!changed)
        return;

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_PARTITION_OWNERSHIP);
    stmt->SetData(0, guid.GetCounter());
    stmt->SetData(1, mapId);
    stmt->SetData(2, partitionId);
    CharacterDatabase.Execute(stmt);

    if (hadOwnership && previousMapId != mapId)
    {
        CharacterDatabasePreparedStatement* delStmt = CharacterDatabase.GetPreparedStatement(CHAR_DEL_PARTITION_OWNERSHIP_OTHER_MAPS);
        delStmt->SetData(0, guid.GetCounter());
        delStmt->SetData(1, mapId);
        CharacterDatabase.Execute(delStmt);
    }
}

void PartitionManager::UpdatePartitionsForMap(uint32 mapId, uint32 diff)
{
    // First, cleanup stale data
    CleanupStaleRelocations();
    CleanupExpiredOverrides();

    {
        std::shared_lock<std::shared_mutex> guard(_partitionLock);
        auto it = _partitionsByMap.find(mapId);
        if (it == _partitionsByMap.end())
            return;

        for (auto const& partition : it->second)
        {
            if (partition)
                partition->Update(diff);
        }
    }

    // Feature 4: Dynamic Resizing Evaluation (Periodically)
    // Check roughly once per second using global time to avoid per-map state
    // Use mapId as offset to spread load across frames
    uint64 now = GameTime::GetGameTimeMS().count();
    if ((now + mapId) % 1000 < diff)
    {
        EvaluatePartitionDensity(mapId);
    }

    ProcessPrecacheQueue(mapId);
}

void PartitionManager::UpdatePartitionStats(uint32 mapId, uint32 partitionId, uint32 players, uint32 creatures, uint32 boundaryObjects)
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    auto mapIt = _partitionIndex.find(mapId);
    if (mapIt == _partitionIndex.end())
        return;
    auto partIt = mapIt->second.find(partitionId);
    if (partIt == mapIt->second.end() || !partIt->second)
        return;
    partIt->second->SetCounts(players, creatures, boundaryObjects);
}



void PartitionManager::UpdatePartitionPlayerCount(uint32 mapId, uint32 partitionId, uint32 players)
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    auto mapIt = _partitionIndex.find(mapId);
    if (mapIt == _partitionIndex.end())
        return;
    auto partIt = mapIt->second.find(partitionId);
    if (partIt == mapIt->second.end() || !partIt->second)
        return;
    partIt->second->SetPlayersCount(players);
}

void PartitionManager::UpdatePartitionCreatureCount(uint32 mapId, uint32 partitionId, uint32 creatures)
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    auto mapIt = _partitionIndex.find(mapId);
    if (mapIt == _partitionIndex.end())
        return;
    auto partIt = mapIt->second.find(partitionId);
    if (partIt == mapIt->second.end() || !partIt->second)
        return;
    partIt->second->SetCreaturesCount(creatures);
}

void PartitionManager::UpdatePartitionBoundaryCount(uint32 mapId, uint32 partitionId, uint32 boundaryObjects)
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    auto mapIt = _partitionIndex.find(mapId);
    if (mapIt == _partitionIndex.end())
        return;
    auto partIt = mapIt->second.find(partitionId);
    if (partIt == mapIt->second.end() || !partIt->second)
        return;
    partIt->second->SetBoundaryObjectCount(boundaryObjects);
}

bool PartitionManager::GetPartitionStats(uint32 mapId, uint32 partitionId, PartitionStats& out) const
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    auto mapIt = _partitionIndex.find(mapId);
    if (mapIt == _partitionIndex.end())
        return false;
    auto partIt = mapIt->second.find(partitionId);
    if (partIt == mapIt->second.end() || !partIt->second)
        return false;
    out.players = partIt->second->GetPlayersCount();
    out.creatures = partIt->second->GetCreaturesCount();
    out.boundaryObjects = partIt->second->GetBoundaryObjectCount();
    return true;
}

void PartitionManager::NotifyVisibilityAttach(ObjectGuid const& guid, uint32 mapId, uint32 partitionId)
{
    {
        std::unique_lock<std::shared_mutex> guard(_visibilityLock);
        _visibilitySets[mapId][partitionId].insert(guid.GetCounter());
    }
    LOG_DEBUG("visibility.partition", "Attach visibility guid {} map {} partition {}", guid.GetCounter(), mapId, partitionId);
}

void PartitionManager::NotifyVisibilityDetach(ObjectGuid const& guid, uint32 mapId, uint32 partitionId)
{
    {
        std::unique_lock<std::shared_mutex> guard(_visibilityLock);
        auto mapIt = _visibilitySets.find(mapId);
        if (mapIt != _visibilitySets.end())
        {
            auto partIt = mapIt->second.find(partitionId);
            if (partIt != mapIt->second.end())
                partIt->second.erase(guid.GetCounter());
        }
    }
    LOG_DEBUG("visibility.partition", "Detach visibility guid {} map {} partition {}", guid.GetCounter(), mapId, partitionId);
}

uint32 PartitionManager::GetVisibilityCount(uint32 mapId, uint32 partitionId) const
{
    std::shared_lock<std::shared_mutex> guard(_visibilityLock);
    auto mapIt = _visibilitySets.find(mapId);
    if (mapIt == _visibilitySets.end())
        return 0;
    auto partIt = mapIt->second.find(partitionId);
    if (partIt == mapIt->second.end())
        return 0;
    return static_cast<uint32>(partIt->second.size());
}

void PartitionManager::RecordCombatHandoff(uint32 mapId)
{
    std::lock_guard<std::mutex> guard(_handoffLock);
    ++_combatHandoffCounts[mapId];
}

void PartitionManager::RecordPathHandoff(uint32 mapId)
{
    std::lock_guard<std::mutex> guard(_handoffLock);
    ++_pathHandoffCounts[mapId];
}

uint32 PartitionManager::ConsumeCombatHandoffCount(uint32 mapId)
{
    std::lock_guard<std::mutex> guard(_handoffLock);
    uint32 count = _combatHandoffCounts[mapId];
    _combatHandoffCounts[mapId] = 0;
    return count;
}

uint32 PartitionManager::ConsumePathHandoffCount(uint32 mapId)
{
    std::lock_guard<std::mutex> guard(_handoffLock);
    uint32 count = _pathHandoffCounts[mapId];
    _pathHandoffCounts[mapId] = 0;
    return count;
}

void PartitionManager::SetPartitionOverride(ObjectGuid const& guid, uint32 partitionId, uint32 durationMs)
{
    if (!guid)
        return;

    uint64 nowMs = GameTime::GetGameTimeMS().count();
    PartitionOverride entry;
    entry.partitionId = partitionId;
    entry.expiresMs = nowMs + durationMs;

    std::unique_lock<std::shared_mutex> guard(_overrideLock);
    _partitionOverrides[guid.GetCounter()] = entry;
}



uint32 PartitionManager::GetBoundaryCount(uint32 mapId, uint32 partitionId) const
{
    std::lock_guard<std::mutex> guard(_boundaryLock);
    auto mapIt = _boundaryObjects.find(mapId);
    if (mapIt == _boundaryObjects.end())
        return 0;
    auto partIt = mapIt->second.find(partitionId);
    if (partIt == mapIt->second.end())
        return 0;
    return static_cast<uint32>(partIt->second.size());
}

bool PartitionManager::BeginRelocation(ObjectGuid const& guid, uint32 mapId, uint32 fromPartition, uint32 toPartition)
{
    std::lock_guard<std::mutex> guard(_relocationLock);
    ObjectGuid::LowType low = guid.GetCounter();

    // Check if relocation is already in progress
    auto existing = _relocations.find(low);
    if (existing != _relocations.end())
    {
        LOG_WARN("map.partition", "BeginRelocation called for guid {} but relocation already in progress", low);
        return false;
    }

    uint64 nowMs = GameTime::GetGameTimeMS().count();

    PartitionRelocationTxn txn;
    txn.guidLow = low;
    txn.mapId = mapId;
    txn.fromPartition = fromPartition;
    txn.toPartition = toPartition;
    txn.state = RelocationState::LOCKED;
    txn.startTimeMs = nowMs;
    txn.lockTimeMs = nowMs;
    _relocations[low] = txn;

    LOG_DEBUG("map.partition", "Begin relocation guid {} map {} {} -> {} (locked at {}ms)", low, mapId, fromPartition, toPartition, nowMs);
    return true;
}

bool PartitionManager::CommitRelocation(ObjectGuid const& guid)
{
    std::lock_guard<std::mutex> guard(_relocationLock);
    ObjectGuid::LowType low = guid.GetCounter();
    auto it = _relocations.find(low);
    if (it == _relocations.end())
        return false;

    uint64 nowMs = GameTime::GetGameTimeMS().count();
    uint64 duration = nowMs - it->second.startTimeMs;

    it->second.state = RelocationState::COMMITTED;

    LOG_DEBUG("map.partition", "Commit relocation guid {} map {} {} -> {} (duration {}ms)", 
        low, it->second.mapId, it->second.fromPartition, it->second.toPartition, duration);
    _relocations.erase(it);
    return true;
}

void PartitionManager::RollbackRelocation(ObjectGuid const& guid)
{
    std::lock_guard<std::mutex> guard(_relocationLock);
    ObjectGuid::LowType low = guid.GetCounter();
    auto it = _relocations.find(low);
    if (it == _relocations.end())
        return;

    uint64 nowMs = GameTime::GetGameTimeMS().count();
    uint64 duration = nowMs - it->second.startTimeMs;

    it->second.state = RelocationState::ROLLED_BACK;

    LOG_WARN("map.partition", "Rollback relocation guid {} map {} {} -> {} (after {}ms, state was {})", 
        low, it->second.mapId, it->second.fromPartition, it->second.toPartition, 
        duration, static_cast<uint8>(it->second.state));
    _relocations.erase(it);
}

std::vector<ObjectGuid> PartitionManager::GetBoundaryObjectGuids(uint32 mapId, uint32 partitionId) const
{
    std::vector<ObjectGuid> result;
    std::lock_guard<std::mutex> guard(_boundaryLock);

    auto mapIt = _boundaryObjects.find(mapId);
    if (mapIt == _boundaryObjects.end())
        return result;

    auto partitionIt = mapIt->second.find(partitionId);
    if (partitionIt == mapIt->second.end())
        return result;

    for (auto const& guid : partitionIt->second)
    {
        result.push_back(guid);
    }

    return result;
}

void PartitionManager::RegisterBoundaryObject(uint32 mapId, uint32 partitionId, ObjectGuid const& guid)
{
    if (!guid)
        return;

    std::lock_guard<std::mutex> guard(_boundaryLock);
    _boundaryObjects[mapId][partitionId].insert(guid);

    LOG_DEBUG("map.partition", "Registered boundary object {} in map {} partition {}", guid.ToString(), mapId, partitionId);
}

void PartitionManager::UnregisterBoundaryObject(uint32 mapId, uint32 partitionId, ObjectGuid const& guid)
{
    if (!guid)
        return;

    std::lock_guard<std::mutex> guard(_boundaryLock);
    auto mapIt = _boundaryObjects.find(mapId);
    if (mapIt == _boundaryObjects.end())
        return;

    auto partitionIt = mapIt->second.find(partitionId);
    if (partitionIt == mapIt->second.end())
        return;

    partitionIt->second.erase(guid);

    LOG_DEBUG("map.partition", "Unregistered boundary object {} from map {} partition {}", guid.ToString(), mapId, partitionId);
}

bool PartitionManager::IsObjectInBoundarySet(uint32 mapId, uint32 partitionId, ObjectGuid const& guid) const
{
    if (!guid)
        return false;

    std::lock_guard<std::mutex> guard(_boundaryLock);
    auto mapIt = _boundaryObjects.find(mapId);
    if (mapIt == _boundaryObjects.end())
        return false;

    auto partitionIt = mapIt->second.find(partitionId);
    if (partitionIt == mapIt->second.end())
        return false;

    return partitionIt->second.find(guid) != partitionIt->second.end();
}

// ======================== SPATIAL HASH GRID BOUNDARY METHODS (Phase 2) ========================

void PartitionManager::RegisterBoundaryObjectWithPosition(uint32 mapId, uint32 partitionId, ObjectGuid const& guid, float x, float y)
{
    if (!guid)
        return;

    std::lock_guard<std::mutex> guard(_boundaryLock);
    _boundarySpatialGrids[mapId][partitionId].Insert(guid, x, y);
    // Also keep in legacy set for compatibility
    _boundaryObjects[mapId][partitionId].insert(guid);

    LOG_DEBUG("map.partition", "Registered boundary object {} with position ({:.1f}, {:.1f}) in map {} partition {}", 
        guid.ToString(), x, y, mapId, partitionId);
}

void PartitionManager::UpdateBoundaryObjectPosition(uint32 mapId, uint32 partitionId, ObjectGuid const& guid, float x, float y)
{
    if (!guid)
        return;

    std::lock_guard<std::mutex> guard(_boundaryLock);
    _boundarySpatialGrids[mapId][partitionId].Update(guid, x, y);
    _boundaryObjects[mapId][partitionId].insert(guid);
}

void PartitionManager::UnregisterBoundaryObjectFromGrid(uint32 mapId, uint32 partitionId, ObjectGuid const& guid)
{
    if (!guid)
        return;

    std::lock_guard<std::mutex> guard(_boundaryLock);
    auto mapIt = _boundarySpatialGrids.find(mapId);
    if (mapIt != _boundarySpatialGrids.end())
    {
        auto partIt = mapIt->second.find(partitionId);
        if (partIt != mapIt->second.end())
            partIt->second.Remove(guid);
    }
    
    // Also remove from legacy set
    auto legacyMapIt = _boundaryObjects.find(mapId);
    if (legacyMapIt != _boundaryObjects.end())
    {
        auto legacyPartIt = legacyMapIt->second.find(partitionId);
        if (legacyPartIt != legacyMapIt->second.end())
            legacyPartIt->second.erase(guid);
    }

    LOG_DEBUG("map.partition", "Unregistered boundary object {} from spatial grid in map {} partition {}", 
        guid.ToString(), mapId, partitionId);
}

std::vector<ObjectGuid> PartitionManager::GetNearbyBoundaryObjects(uint32 mapId, uint32 partitionId, float x, float y, float radius) const
{
    std::lock_guard<std::mutex> guard(_boundaryLock);
    
    auto mapIt = _boundarySpatialGrids.find(mapId);
    if (mapIt == _boundarySpatialGrids.end())
        return {};
    
    auto partIt = mapIt->second.find(partitionId);
    if (partIt == mapIt->second.end())
        return {};
    
    return partIt->second.QueryNearby(x, y, radius);
}

// ======================== NEW CLEANUP METHODS ========================

void PartitionManager::CleanupStaleRelocations()
{
    std::lock_guard<std::mutex> guard(_relocationLock);
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    
    for (auto it = _relocations.begin(); it != _relocations.end();)
    {
        if (nowMs - it->second.startTimeMs > it->second.timeoutMs)
        {
            LOG_WARN("map.partition", "Auto-rollback stale relocation guid {} (after {}ms)", 
                it->first, nowMs - it->second.startTimeMs);
            it = _relocations.erase(it);
        }
        else
            ++it;
    }
}

void PartitionManager::CleanupExpiredOverrides()
{
    std::unique_lock<std::shared_mutex> guard(_overrideLock);
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    
    for (auto it = _partitionOverrides.begin(); it != _partitionOverrides.end();)
    {
        if (nowMs > it->second.expiresMs)
            it = _partitionOverrides.erase(it);
        else
            ++it;
    }
}

void PartitionManager::CleanupBoundaryObjects(uint32 mapId, uint32 partitionId, std::unordered_set<ObjectGuid> const& validGuids)
{
    std::lock_guard<std::mutex> guard(_boundaryLock);
    auto mapIt = _boundaryObjects.find(mapId);
    if (mapIt == _boundaryObjects.end())
        return;

    auto partitionIt = mapIt->second.find(partitionId);
    if (partitionIt == mapIt->second.end())
        return;

    SpatialHashGrid* spatialGrid = nullptr;
    auto spatialMapIt = _boundarySpatialGrids.find(mapId);
    if (spatialMapIt != _boundarySpatialGrids.end())
    {
        auto spatialPartIt = spatialMapIt->second.find(partitionId);
        if (spatialPartIt != spatialMapIt->second.end())
            spatialGrid = &spatialPartIt->second;
    }

    for (auto it = partitionIt->second.begin(); it != partitionIt->second.end();)
    {
        if (validGuids.find(*it) == validGuids.end())
        {
            if (spatialGrid)
                spatialGrid->Remove(*it);
            it = partitionIt->second.erase(it);
        }
        else
            ++it;
    }
}

void PartitionManager::ForceRemovePlayerFromAllLayers(ObjectGuid const& playerGuid)
{
    std::unique_lock<std::shared_mutex> guard(_layerLock);
    auto it = _playerLayers.find(playerGuid.GetCounter());
    if (it != _playerLayers.end())
    {
        uint32 oldMapId = it->second.mapId;
        uint32 oldZoneId = it->second.zoneId;
        uint32 oldLayerId = it->second.layerId;

        auto& layer = _layers[oldMapId][oldZoneId][oldLayerId];
        layer.erase(playerGuid.GetCounter());

        // Clean up the empty layer and reassign orphaned NPCs
        CleanupEmptyLayers(oldMapId, oldZoneId, oldLayerId);

        _playerLayers.erase(it);
        
        // Clear atomic for lock-free reads (Phase 1 optimization)
        auto atomicIt = _atomicPlayerLayers.find(playerGuid.GetCounter());
        if (atomicIt != _atomicPlayerLayers.end())
            atomicIt->second.Clear();
        
        LOG_DEBUG("map.partition", "Force removed player {} from all layers", playerGuid.ToString());

        if (IsRuntimeDiagnosticsEnabled())
        {
            LOG_INFO("map.partition", "Diag: ForceRemovePlayerFromAllLayers player={}", playerGuid.ToString());
        }
    }

    // Clean up layer switch cooldown to prevent unbounded growth
    {
        std::lock_guard<std::mutex> cooldownGuard(_cooldownLock);
        _layerSwitchCooldowns.erase(playerGuid.GetCounter());
    }
}

std::pair<uint32_t, uint32_t> PartitionManager::GetLayersForTwoPlayers(
    uint32_t mapId, uint32_t zoneId, 
    ObjectGuid const& player1, ObjectGuid const& player2) const
{
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    ObjectGuid::LowType a = player1.GetCounter();
    ObjectGuid::LowType b = player2.GetCounter();
    if (a > b)
        std::swap(a, b);

    LayerPairCacheKey key{ mapId, zoneId, a, b };
    {
        std::lock_guard<std::mutex> guard(_layerPairCacheLock);
        auto it = _layerPairCache.find(key);
        if (it != _layerPairCache.end() && nowMs <= it->second.expiresMs)
            return { it->second.layer1, it->second.layer2 };
    }

    std::shared_lock<std::shared_mutex> guard(_layerLock);
    
    uint32_t layer1 = 0;
    uint32_t layer2 = 0;
    
    auto it1 = _playerLayers.find(player1.GetCounter());
    if (it1 != _playerLayers.end() && it1->second.mapId == mapId && it1->second.zoneId == zoneId)
        layer1 = it1->second.layerId;
    
    auto it2 = _playerLayers.find(player2.GetCounter());
    if (it2 != _playerLayers.end() && it2->second.mapId == mapId && it2->second.zoneId == zoneId)
        layer2 = it2->second.layerId;
    
    {
        std::lock_guard<std::mutex> cacheGuard(_layerPairCacheLock);
        _layerPairCache[key] = { layer1, layer2, nowMs + 200 };
        if (_layerPairCache.size() > 2048)
        {
            for (auto it = _layerPairCache.begin(); it != _layerPairCache.end();)
            {
                if (nowMs > it->second.expiresMs)
                    it = _layerPairCache.erase(it);
                else
                    ++it;
            }
        }
    }

    return {layer1, layer2};
}

PartitionManager::PartitionGridLayout const* PartitionManager::GetGridLayout(uint32 mapId) const
{
    // Lock should already be held by caller
    auto it = _gridLayouts.find(mapId);
    if (it == _gridLayouts.end())
        return nullptr;
    return &it->second;
}

PartitionManager::PartitionGridLayout const* PartitionManager::GetCachedLayout(uint32 mapId) const
{
    struct LayoutCache
    {
        uint32 mapId = 0;
        uint64 epoch = 0;
        PartitionGridLayout layout{};
        bool valid = false;
    };

    thread_local LayoutCache cache;

    uint64 epoch = 0;
    {
        std::shared_lock<std::shared_mutex> guard(_partitionLock);
        if (auto it = _layoutEpochByMap.find(mapId); it != _layoutEpochByMap.end())
            epoch = it->second;
    }

    if (cache.valid && cache.mapId == mapId && cache.epoch == epoch)
        return &cache.layout;

    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    if (PartitionGridLayout const* layout = GetGridLayout(mapId))
    {
        cache.mapId = mapId;
        cache.epoch = epoch;
        cache.layout = *layout;
        cache.valid = true;
        return &cache.layout;
    }

    cache.valid = false;
    return nullptr;
}

PartitionManager::PartitionGridLayout PartitionManager::ComputeGridLayout(uint32 count) const
{
    PartitionGridLayout layout;
    layout.count = count;
    layout.cols = static_cast<uint32>(std::floor(std::sqrt(static_cast<float>(count))));
    if (layout.cols == 0)
        layout.cols = 1;
    layout.rows = (count + layout.cols - 1) / layout.cols;
    uint32 gridMax = MAX_NUMBER_OF_GRIDS;
    layout.cellWidth = (gridMax + layout.cols - 1) / layout.cols;
    layout.cellHeight = (gridMax + layout.rows - 1) / layout.rows;
    return layout;
}

void PartitionManager::CleanupEmptyLayers(uint32 mapId, uint32 zoneId, uint32 layerId)
{
    // Note: _layerLock must already be held by caller
    auto& zoneLayers = _layers[mapId][zoneId];
    auto layerIt = zoneLayers.find(layerId);
    if (layerIt == zoneLayers.end())
        return;
    
    if (layerIt->second.empty())
    {
        zoneLayers.erase(layerId);

        // Reassign orphaned NPCs and GOs from the removed layer to a surviving layer
        if (!zoneLayers.empty())
        {
            // Collect surviving layer IDs for deterministic distribution
            std::vector<uint32> survivingLayers;
            survivingLayers.reserve(zoneLayers.size());
            for (auto const& [lid, _] : zoneLayers)
                survivingLayers.push_back(lid);
            std::sort(survivingLayers.begin(), survivingLayers.end());

            for (auto& [npcLow, assignment] : _npcLayers)
            {
                if (assignment.mapId == mapId && assignment.zoneId == zoneId && assignment.layerId == layerId)
                {
                    uint32 newLayer = survivingLayers[static_cast<uint32>(npcLow % survivingLayers.size())];
                    assignment.layerId = newLayer;
                }
            }

            for (auto& [goLow, assignment] : _goLayers)
            {
                if (assignment.mapId == mapId && assignment.zoneId == zoneId && assignment.layerId == layerId)
                {
                    uint32 newLayer = survivingLayers[static_cast<uint32>(goLow % survivingLayers.size())];
                    assignment.layerId = newLayer;
                }
            }
        }

        if (zoneLayers.empty())
        {
            _layers[mapId].erase(zoneId);
            if (_layers[mapId].empty())
                 _layers.erase(mapId);
        }
    }
}

// ======================== FEATURE 1: Persistent Layer Assignment ========================

void PartitionManager::LoadPersistentLayerAssignment(ObjectGuid const& playerGuid)
{
    if (!IsLayeringEnabled())
        return;

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_DC_LAYER_ASSIGNMENT);
    stmt->SetData(0, playerGuid.GetCounter());
    PreparedQueryResult result = CharacterDatabase.Query(stmt);
    
    if (!result)
        return;

    uint32 mapId = (*result)[0].Get<uint16>();
    uint32 zoneId = (*result)[1].Get<uint32>();
    uint32 layerId = (*result)[2].Get<uint16>();
    
    // Verify that this layer still exists
    std::unique_lock<std::shared_mutex> guard(_layerLock);
    auto mapIt = _layers.find(mapId);
    if (mapIt == _layers.end())
        return;
    auto zoneIt = mapIt->second.find(zoneId);
    if (zoneIt == mapIt->second.end())
        return;
    auto layerIt = zoneIt->second.find(layerId);
    if (layerIt == zoneIt->second.end())
        return;
    
    // Layer still exists, restore assignment
    _playerLayers[playerGuid.GetCounter()] = { mapId, zoneId, layerId };
    layerIt->second.insert(playerGuid.GetCounter());
    
    LOG_DEBUG("map.partition", "Restored persistent layer {} for player {} in map {} zone {}",
        layerId, playerGuid.ToString(), mapId, zoneId);
}

void PartitionManager::SavePersistentLayerAssignment(ObjectGuid const& playerGuid, uint32 mapId, uint32 zoneId, uint32 layerId)
{
    if (!IsLayeringEnabled())
        return;

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_DC_LAYER_ASSIGNMENT);
    stmt->SetData(0, playerGuid.GetCounter());
    stmt->SetData(1, static_cast<uint16>(mapId));
    stmt->SetData(2, zoneId);
    stmt->SetData(3, static_cast<uint16>(layerId));
    CharacterDatabase.Execute(stmt);
    
    LOG_DEBUG("map.partition", "Saved persistent layer {} for player {} in map {} zone {}",
        layerId, playerGuid.ToString(), mapId, zoneId);
}

// ======================== FEATURE 2: Cross-Layer Party Communication ========================

uint32 PartitionManager::GetPartyTargetLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& playerGuid)
{
    if (!IsLayeringEnabled())
        return 0;

    uint64 nowMs = GameTime::GetGameTimeMS().count();
    {
        std::lock_guard<std::mutex> guard(_partyLayerCacheLock);
        auto it = _partyTargetLayerCache.find(playerGuid.GetCounter());
        if (it != _partyTargetLayerCache.end() && nowMs <= it->second.expiresMs && it->second.mapId == mapId && it->second.zoneId == zoneId)
            return it->second.layerId;
    }

    Player* player = ObjectAccessor::FindPlayer(playerGuid);
    if (!player)
        return 0;

    Group* group = player->GetGroup();
    if (!group)
        return 0;

    ObjectGuid leaderGuid = group->GetLeaderGUID();
    if (leaderGuid == playerGuid)
        return 0; // Player is leader, no target layer

    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto it = _playerLayers.find(leaderGuid.GetCounter());
    if (it == _playerLayers.end())
        return 0;

    // Only return leader's layer if they're in the same map and zone
    if (it->second.mapId != mapId || it->second.zoneId != zoneId)
        return 0;

    LOG_DEBUG("map.partition", "Party sync: Player {} targeting leader {} layer {} in map {} zone {}",
        playerGuid.ToString(), leaderGuid.ToString(), it->second.layerId, mapId, zoneId);
    
    uint32 layerId = it->second.layerId;
    {
        std::lock_guard<std::mutex> guard(_partyLayerCacheLock);
        _partyTargetLayerCache[playerGuid.GetCounter()] = { mapId, zoneId, layerId, nowMs + 1000 };
    }

    return layerId;
}

// ======================== FEATURE 3: NPC Layering ========================

bool PartitionManager::IsNPCLayeringEnabled() const
{
    // Config option: MapPartitions.Layers.IncludeNPCs
    return IsLayeringEnabled() && sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_NPC_LAYERS);
}

void PartitionManager::AssignNPCToLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& npcGuid, uint32 layerId)
{
    if (!IsNPCLayeringEnabled())
        return;

    std::unique_lock<std::shared_mutex> guard(_layerLock);
    _npcLayers[npcGuid.GetCounter()] = { mapId, zoneId, layerId };
    
    LOG_DEBUG("map.partition", "Assigned NPC {} to layer {} in map {} zone {}",
        npcGuid.ToString(), layerId, mapId, zoneId);
}

void PartitionManager::RemoveNPCFromLayer(ObjectGuid const& npcGuid)
{
    std::unique_lock<std::shared_mutex> guard(_layerLock);
    _npcLayers.erase(npcGuid.GetCounter());
}

uint32 PartitionManager::GetLayerForNPC(uint32 mapId, uint32 zoneId, ObjectGuid const& npcGuid) const
{
    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto it = _npcLayers.find(npcGuid.GetCounter());
    if (it == _npcLayers.end())
        return 0;
    
    if (it->second.mapId != mapId || it->second.zoneId != zoneId)
        return 0;
    
    return it->second.layerId;
}

uint32 PartitionManager::GetLayerForNPC(ObjectGuid const& npcGuid) const
{
    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto it = _npcLayers.find(npcGuid.GetCounter());
    if (it == _npcLayers.end())
        return 0;

    return it->second.layerId;
}

uint32 PartitionManager::GetDefaultLayerForZone(uint32 mapId, uint32 zoneId, uint64 seed) const
{
    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto mapIt = _layers.find(mapId);
    if (mapIt == _layers.end())
        return 0;

    auto zoneIt = mapIt->second.find(zoneId);
    if (zoneIt == mapIt->second.end() || zoneIt->second.empty())
        return 0;

    std::vector<uint32> layerIds;
    layerIds.reserve(zoneIt->second.size());
    for (auto const& [layerId, _] : zoneIt->second)
        layerIds.push_back(layerId);

    std::sort(layerIds.begin(), layerIds.end());
    uint32 index = static_cast<uint32>(seed % layerIds.size());
    return layerIds[index];
}

// ======================== FEATURE 3b: GameObject Layering ========================

bool PartitionManager::IsGOLayeringEnabled() const
{
    return IsLayeringEnabled() && sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_GO_LAYERS);
}

void PartitionManager::AssignGOToLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& goGuid, uint32 layerId)
{
    if (!IsGOLayeringEnabled())
        return;

    std::unique_lock<std::shared_mutex> guard(_layerLock);
    _goLayers[goGuid.GetCounter()] = { mapId, zoneId, layerId };

    LOG_DEBUG("map.partition", "Assigned GO {} to layer {} in map {} zone {}",
        goGuid.ToString(), layerId, mapId, zoneId);
}

void PartitionManager::RemoveGOFromLayer(ObjectGuid const& goGuid)
{
    std::unique_lock<std::shared_mutex> guard(_layerLock);
    _goLayers.erase(goGuid.GetCounter());
}

uint32 PartitionManager::GetLayerForGO(uint32 mapId, uint32 zoneId, ObjectGuid const& goGuid) const
{
    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto it = _goLayers.find(goGuid.GetCounter());
    if (it == _goLayers.end())
        return 0;

    if (it->second.mapId != mapId || it->second.zoneId != zoneId)
        return 0;

    return it->second.layerId;
}

uint32 PartitionManager::GetLayerForGO(ObjectGuid const& goGuid) const
{
    std::shared_lock<std::shared_mutex> guard(_layerLock);
    auto it = _goLayers.find(goGuid.GetCounter());
    if (it == _goLayers.end())
        return 0;

    return it->second.layerId;
}

void PartitionManager::ReassignGOsForNewLayer(uint32 mapId, uint32 zoneId)
{
    if (!IsGOLayeringEnabled())
        return;

    std::vector<uint32> layerIds;
    layerIds.reserve(4);

    {
        std::shared_lock<std::shared_mutex> guard(_layerLock);
        auto mapIt = _layers.find(mapId);
        if (mapIt == _layers.end())
            return;

        auto zoneIt = mapIt->second.find(zoneId);
        if (zoneIt == mapIt->second.end() || zoneIt->second.size() < 2)
            return;

        for (auto const& [layerId, _] : zoneIt->second)
            layerIds.push_back(layerId);
    }

    if (layerIds.size() < 2)
        return;

    std::sort(layerIds.begin(), layerIds.end());

    uint32 reassigned = 0;
    {
        std::unique_lock<std::shared_mutex> guard(_layerLock);
        for (auto& [goLow, assignment] : _goLayers)
        {
            if (assignment.mapId != mapId || assignment.zoneId != zoneId)
                continue;

            if (assignment.layerId != 0)
                continue;

            uint32 targetLayer = layerIds[static_cast<uint32>(goLow % layerIds.size())];
            if (targetLayer != assignment.layerId)
            {
                assignment.layerId = targetLayer;
                ++reassigned;
            }
        }
    }

    if (IsRuntimeDiagnosticsEnabled() && reassigned > 0)
    {
        LOG_INFO("map.partition", "Diag: ReassignGOsForNewLayer map={} zone={} reassigned={}",
            mapId, zoneId, reassigned);
    }
}

// ======================== FEATURE 4: Dynamic Partition Resizing ========================

float PartitionManager::GetPartitionDensity(uint32 mapId, uint32 partitionId) const
{
    PartitionStats stats;
    if (!GetPartitionStats(mapId, partitionId, stats))
        return 0.0f;
    
    // Density = (players + creatures/10) per cell
    // Creatures counted at 1/10 weight since they're less impactful than players
    float density = static_cast<float>(stats.players) + static_cast<float>(stats.creatures) / 10.0f;
    
    // Normalize by grid cell size (assume 533x533 yard cells for WoW maps)
    // Higher density = more entities per unit area
    return density;
}

void PartitionManager::ResizeMapPartitions(uint32 mapId, uint32 newCount, char const* reason)
{
    if (!IsEnabled())
        return;

    if (newCount < 1)
        newCount = 1;

    uint64 nowMs = GameTime::GetGameTimeMS().count();
    uint32 oldCount = 0;

    {
        std::unique_lock<std::shared_mutex> guard(_partitionLock);
        auto it = _partitionsByMap.find(mapId);
        if (it == _partitionsByMap.end())
            return;

        oldCount = static_cast<uint32>(it->second.size());
        if (oldCount == 0 || newCount == oldCount)
            return;

        uint64& lastResize = _lastResizeMs[mapId];
        if (nowMs < lastResize + 10000)
            return;
        lastResize = nowMs;

        if (newCount > oldCount)
        {
            for (uint32 i = oldCount + 1; i <= newCount; ++i)
            {
                auto name = "Partition " + std::to_string(i);
                it->second.push_back(std::make_unique<MapPartition>(mapId, i, name));
            }
        }
        else
        {
            it->second.erase(std::remove_if(it->second.begin(), it->second.end(),
                [newCount](std::unique_ptr<MapPartition> const& partition)
                {
                    return partition && partition->GetPartitionId() > newCount;
                }), it->second.end());
        }

        PartitionGridLayout layout = ComputeGridLayout(newCount);
        _gridLayouts[mapId] = layout;
        _layoutEpochByMap[mapId] = _layoutEpochByMap[mapId] + 1;

        // Rebuild O(1) partition index for this map
        _partitionIndex.erase(mapId);
        for (auto const& partition : it->second)
        {
            if (partition)
                _partitionIndex[mapId][partition->GetPartitionId()] = partition.get();
        }
    }

    {
        std::lock_guard<std::mutex> guard(_boundaryLock);
        auto mapIt = _boundaryObjects.find(mapId);
        if (mapIt != _boundaryObjects.end())
        {
            for (auto it = mapIt->second.begin(); it != mapIt->second.end();)
            {
                if (it->first > newCount)
                    it = mapIt->second.erase(it);
                else
                {
                    it->second.clear();
                    ++it;
                }
            }
        }
    }

    {
        std::lock_guard<std::mutex> guard(_layerPairCacheLock);
        _layerPairCache.clear();
    }

    {
        std::unique_lock<std::shared_mutex> guard(_visibilityLock);
        auto mapIt = _visibilitySets.find(mapId);
        if (mapIt != _visibilitySets.end())
        {
            for (auto it = mapIt->second.begin(); it != mapIt->second.end();)
            {
                if (it->first > newCount)
                    it = mapIt->second.erase(it);
                else
                {
                    it->second.clear();
                    ++it;
                }
            }
        }
    }

    if (Map* map = sMapMgr->FindBaseMap(mapId))
        map->RebuildPartitionedObjectAssignments();

    LOG_INFO("map.partition", "Resized partitions on map {}: {} -> {} ({})",
        mapId, oldCount, newCount, reason ? reason : "auto");
}

void PartitionManager::EvaluatePartitionDensity(uint32 mapId)
{
    // NOTE: This is a placeholder for future dynamic resizing.
    // Full implementation would require:
    // 1. Track density over time (rolling average)
    // 2. Split partitions when density > split threshold
    // 3. Merge adjacent partitions when both < merge threshold
    // 4. Update all affected data structures atomically
    
    if (!IsEnabled())
        return;
        
    uint32 partitionCount = GetPartitionCount(mapId);
    if (partitionCount == 0)
        return;

    float splitThreshold = GetDensitySplitThreshold();
    float mergeThreshold = GetDensityMergeThreshold();

    float maxDensity = 0.0f;
    float minDensity = std::numeric_limits<float>::max();

    for (uint32 pid = 1; pid <= partitionCount; ++pid)
    {
        float density = GetPartitionDensity(mapId, pid);
        if (density > maxDensity)
            maxDensity = density;
        if (density < minDensity)
            minDensity = density;
    }

    uint32 maxPartitions = MAX_NUMBER_OF_GRIDS;

    if (maxDensity > splitThreshold && partitionCount < maxPartitions)
    {
        LOG_INFO("map.partition", "Partition density split: map {} maxDensity {} > {} (count {} -> {})",
            mapId, maxDensity, splitThreshold, partitionCount, partitionCount + 1);
        ResizeMapPartitions(mapId, partitionCount + 1, "split");
        return;
    }

    if (minDensity < mergeThreshold && partitionCount > 1 && maxDensity < mergeThreshold)
    {
        LOG_INFO("map.partition", "Partition density merge: map {} maxDensity {} < {} (count {} -> {})",
            mapId, maxDensity, mergeThreshold, partitionCount, partitionCount - 1);
        ResizeMapPartitions(mapId, partitionCount - 1, "merge");
        return;
    }
}

float PartitionManager::GetDensitySplitThreshold() const
{
    // Default: Split when more than 50 players equivalents per partition
    return sWorld->getFloatConfig(CONFIG_MAP_PARTITIONS_DENSITY_SPLIT_THRESHOLD);
}

float PartitionManager::GetDensityMergeThreshold() const
{
    // Default: Merge when fewer than 5 player equivalents per partition
    return sWorld->getFloatConfig(CONFIG_MAP_PARTITIONS_DENSITY_MERGE_THRESHOLD);
}

// ======================== FEATURE 5: Adjacent Partition Pre-caching ========================

std::vector<uint32> PartitionManager::GetAdjacentPartitions(uint32 mapId, uint32 partitionId) const
{
    std::vector<uint32> adjacent;
    
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    auto it = _gridLayouts.find(mapId);
    if (it == _gridLayouts.end() || it->second.count <= 1)
        return adjacent;
    
    const PartitionGridLayout& layout = it->second;
    
    // Calculate grid position
    uint32 col = (partitionId - 1) % layout.cols;
    uint32 row = (partitionId - 1) / layout.cols;
    
    // Add valid adjacent partitions (4-connected)
    if (col > 0)
        adjacent.push_back(partitionId - 1);  // Left
    if (col < layout.cols - 1)
        adjacent.push_back(partitionId + 1);  // Right
    if (row > 0)
        adjacent.push_back(partitionId - layout.cols);  // Up
    if (row < layout.rows - 1)
        adjacent.push_back(partitionId + layout.cols);  // Down
    
    return adjacent;
}

void PartitionManager::CheckBoundaryApproach(ObjectGuid const& playerGuid, uint32 mapId, float x, float y, float dx, float dy)
{
    // Check if player is moving toward a partition boundary
    // If so, queue the adjacent partition for precaching
    
    if (!IsEnabled())
        return;

    uint64 nowMs = GameTime::GetGameTimeMS().count();
    {
        std::lock_guard<std::mutex> guard(_precacheLock);
        uint64& lastCheck = _boundaryApproachLastCheck[playerGuid.GetCounter()];
        if (nowMs - lastCheck < 200)
            return;
        lastCheck = nowMs;
    }
    
    uint32 currentPartition = GetPartitionIdForPosition(mapId, x, y);
    
    // Predict position in ~5 seconds based on velocity
    float predictX = x + dx * 5.0f;
    float predictY = y + dy * 5.0f;
    uint32 predictedPartition = GetPartitionIdForPosition(mapId, predictX, predictY);
    
    if (predictedPartition != currentPartition && predictedPartition > 0)
    {
        // Player is approaching boundary
        LOG_DEBUG("map.partition", "Player {} approaching partition boundary: {} -> {}", 
            playerGuid.ToString(), currentPartition, predictedPartition);

        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 key = (static_cast<uint64>(mapId) << 32) | predictedPartition;

        std::lock_guard<std::mutex> guard(_precacheLock);
        if (auto it = _precacheRecent.find(key); it != _precacheRecent.end())
        {
            if (nowMs - it->second < 5000)
                return; // throttle per map+partition
        }

        constexpr size_t kPrecacheQueueLimit = 256;
        if (_precacheQueue.size() >= kPrecacheQueueLimit)
            return;

        _precacheQueue.push_back({ mapId, predictedPartition, predictX, predictY, nowMs });
        _precacheRecent[key] = nowMs;
    }
}

void PartitionManager::ProcessPrecacheQueue(uint32 mapId)
{
    if (!IsEnabled())
        return;

    Map* map = sMapMgr->FindBaseMap(mapId);
    if (!map)
        return;

    constexpr uint32 kMaxRequestsPerTick = 2;
    constexpr uint64 kMaxAgeMs = 15000;

    uint32 processed = 0;
    uint64 nowMs = GameTime::GetGameTimeMS().count();

    std::vector<PrecacheRequest> toProcess;
    {
        std::lock_guard<std::mutex> guard(_precacheLock);
        size_t queueSize = _precacheQueue.size();
        for (size_t i = 0; i < queueSize && processed < kMaxRequestsPerTick; ++i)
        {
            PrecacheRequest req = _precacheQueue.front();
            _precacheQueue.pop_front();

            if (req.mapId != mapId)
            {
                _precacheQueue.push_back(req);
                continue;
            }

            if (nowMs - req.queuedMs > kMaxAgeMs)
                continue;

            toProcess.push_back(req);
            ++processed;
        }

        // Prune stale entries from _precacheRecent to prevent unbounded growth
        if (_precacheRecent.size() > 512)
        {
            for (auto it = _precacheRecent.begin(); it != _precacheRecent.end();)
            {
                if (nowMs - it->second > 30000)
                    it = _precacheRecent.erase(it);
                else
                    ++it;
            }
        }
    }

    for (auto const& req : toProcess)
    {
        Position center(req.x, req.y, 0.0f, 0.0f);
        map->LoadGridsInRange(center, SIZE_OF_GRIDS * 1.5f);
    }
}

// Phase 5: Player-Initiated Layer Switching (WoW-style)
bool PartitionManager::CanSwitchLayer(ObjectGuid const& playerGuid) const
{
    if (!IsLayeringEnabled())
        return false;

    // Get player object to check combat and death status
    Player* player = ObjectAccessor::FindPlayer(playerGuid);
    if (!player)
        return false;
    
    // Combat check
    if (player->IsInCombat())
        return false;
    
    // Death check
    if (player->isDead())
        return false;
    
    // Cooldown check
    std::lock_guard<std::mutex> guard(_cooldownLock);
    auto it = _layerSwitchCooldowns.find(playerGuid.GetCounter());
    if (it != _layerSwitchCooldowns.end())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        if (!it->second.CanSwitch(nowMs))
            return false;
    }
    
    return true;
}

uint32 PartitionManager::GetLayerSwitchCooldownMs(ObjectGuid const& playerGuid) const
{
    std::lock_guard<std::mutex> guard(_cooldownLock);
    auto it = _layerSwitchCooldowns.find(playerGuid.GetCounter());
    if (it == _layerSwitchCooldowns.end())
        return 0;
    
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    return it->second.GetRemainingCooldownMs(nowMs);
}

bool PartitionManager::SwitchPlayerToLayer(ObjectGuid const& playerGuid, uint32 targetLayer, std::string const& reason)
{
    if (!IsLayeringEnabled())
        return false;

    Player* player = ObjectAccessor::FindPlayer(playerGuid);
    if (!player)
        return false;
    
    // Enforce restrictions
    if (!CanSwitchLayer(playerGuid))
        return false;
    
    uint32 mapId = player->GetMapId();
    uint32 zoneId = player->GetZoneId();
    
    // Check if target layer actually exists (layers have arbitrary IDs, not 0-indexed)
    {
        std::shared_lock<std::shared_mutex> guard(_layerLock);
        auto mapIt = _layers.find(mapId);
        if (mapIt == _layers.end())
            return false;
        auto zoneIt = mapIt->second.find(zoneId);
        if (zoneIt == mapIt->second.end())
            return false;
        if (zoneIt->second.find(targetLayer) == zoneIt->second.end())
            return false;
    }
    
    // Get current layer
    uint32 currentLayer = GetLayerForPlayer(mapId, zoneId, playerGuid);
    if (currentLayer == targetLayer)
        return false; // Already on target layer
    
    // Perform the switch
    AssignPlayerToLayer(mapId, zoneId, playerGuid, targetLayer);

    // Force visibility rebuild after layer change
    player->UpdateObjectVisibility(true, true);
    
    // Record the switch for cooldown tracking
    {
        std::lock_guard<std::mutex> guard(_cooldownLock);
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        _layerSwitchCooldowns[playerGuid.GetCounter()].RecordSwitch(nowMs);
    }
    
    // Log the switch
    LOG_DEBUG("map.partition", "Player {} switched from layer {} to layer {} (reason: {})",
        playerGuid.ToString(), currentLayer, targetLayer, reason);
    
    if (IsRuntimeDiagnosticsEnabled())
    {
        LOG_INFO("map.partition", "Diag: SwitchPlayerToLayer player={} from={} to={} reason={}",
            playerGuid.ToString(), currentLayer, targetLayer, reason);
    }
    
    return true;
}

// ======================== PHASE 6: LAYER REBALANCING ========================

void PartitionManager::EvaluateLayerRebalancing(uint32 mapId, uint32 zoneId)
{
    if (!_rebalancingConfig.enabled || !IsLayeringEnabled())
        return;
    
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    uint64 key = (static_cast<uint64>(mapId) << 32) | zoneId;
    
    // Throttle checks per zone
    auto it = _lastRebalanceCheck.find(key);
    if (it != _lastRebalanceCheck.end() && (nowMs - it->second) < _rebalancingConfig.checkIntervalMs)
        return;
    
    _lastRebalanceCheck[key] = nowMs;
    
    auto playerCounts = GetLayerPlayerCounts(mapId, zoneId);
    if (playerCounts.empty() || playerCounts.size() <= 1)
        return;  // Nothing to rebalance
    
    if (!ShouldRebalanceLayers(playerCounts))
        return;
    
    LOG_INFO("map.partition", "Layer rebalancing triggered for map {} zone {} - {} layers", 
        mapId, zoneId, playerCounts.size());
    
    // Calculate target distribution
    uint32 totalPlayers = 0;
    for (uint32 count : playerCounts)
        totalPlayers += count;
    
    uint32 targetLayers = std::max(1u, (totalPlayers + GetLayerCapacity() - 1) / GetLayerCapacity());
    if (targetLayers >= playerCounts.size())
        return; // No consolidation needed
    
    uint32 playersPerLayer = totalPlayers / targetLayers;
    std::vector<uint32> targetDistribution(targetLayers, playersPerLayer);
    
    // Distribute remainder
    for (uint32 i = 0; i < (totalPlayers % targetLayers); ++i)
        targetDistribution[i]++;
    
    ConsolidateLayers(mapId, zoneId, targetDistribution);
    
    _rebalancingMetrics.totalRebalances.fetch_add(1, std::memory_order_relaxed);
}

std::vector<uint32> PartitionManager::GetLayerPlayerCounts(uint32 mapId, uint32 zoneId) const
{
    std::shared_lock lock(_layerLock);
    
    auto mapIt = _layers.find(mapId);
    if (mapIt == _layers.end())
        return {};
    
    auto zoneIt = mapIt->second.find(zoneId);
    if (zoneIt == mapIt->second.end())
        return {};
    
    std::vector<uint32> counts;
    counts.reserve(zoneIt->second.size());
    
    for (auto const& [layerId, players] : zoneIt->second)
    {
        counts.push_back(static_cast<uint32>(players.size()));
    }
    
    return counts;
}

bool PartitionManager::ShouldRebalanceLayers(std::vector<uint32> const& playerCounts) const
{
    if (playerCounts.size() <= 1)
        return false;
    
    // Check for empty or very sparse layers
    uint32 sparseCount = 0;
    for (uint32 count : playerCounts)
    {
        if (count < _rebalancingConfig.minPlayersPerLayer)
            sparseCount++;
    }
    
    // If we have sparse layers, rebalance
    if (sparseCount > 0)
        return true;
    
    // Check for imbalance using coefficient of variation
    float total = 0.0f;
    for (uint32 count : playerCounts)
        total += static_cast<float>(count);
    
    float mean = total / playerCounts.size();
    if (mean < 1.0f)
        return false;  // Too few players to care
    
    float variance = 0.0f;
    for (uint32 count : playerCounts)
    {
        float diff = static_cast<float>(count) - mean;
        variance += diff * diff;
    }
    variance /= playerCounts.size();
    float stdDev = std::sqrt(variance);
    float coefficientOfVariation = stdDev / mean;
    
    return coefficientOfVariation > _rebalancingConfig.imbalanceThreshold;
}

void PartitionManager::ConsolidateLayers(uint32 mapId, uint32 zoneId, std::vector<uint32> const& targetDistribution)
{
    // Collect players to notify outside lock to avoid deadlock with ObjectAccessor
    std::vector<std::pair<ObjectGuid, uint32>> playersToNotify;

    {
    std::unique_lock lock(_layerLock);
    
    auto mapIt = _layers.find(mapId);
    if (mapIt == _layers.end())
        return;
    
    auto zoneIt = mapIt->second.find(zoneId);
    if (zoneIt == mapIt->second.end())
        return;
    
    // Collect all players from all layers
    std::vector<ObjectGuid::LowType> allPlayers;
    size_t originalLayerCount = zoneIt->second.size();
    
    for (auto const& [layerId, players] : zoneIt->second)
    {
        allPlayers.insert(allPlayers.end(), players.begin(), players.end());
    }
    
    if (allPlayers.empty())
        return;
    
    // Clear existing layer assignments
    zoneIt->second.clear();
    
    // Redistribute players according to target distribution
    size_t playerIdx = 0;
    uint32 migratedCount = 0;
    
    for (uint32 layerId = 0; layerId < targetDistribution.size() && playerIdx < allPlayers.size(); ++layerId)
    {
        auto& layer = zoneIt->second[layerId];
        
        for (uint32 i = 0; i < targetDistribution[layerId] && playerIdx < allPlayers.size(); ++i)
        {
            ObjectGuid::LowType playerLow = allPlayers[playerIdx];
            layer.insert(playerLow);
            
            // Update layer assignment tracking
            auto assignIt = _playerLayers.find(playerLow);
            if (assignIt != _playerLayers.end())
            {
                uint32 oldLayer = assignIt->second.layerId;
                if (oldLayer != layerId)
                {
                    assignIt->second.layerId = layerId;
                    migratedCount++;
                    
                    // Update atomic assignment
                    auto atomicIt = _atomicPlayerLayers.find(playerLow);
                    if (atomicIt != _atomicPlayerLayers.end())
                        atomicIt->second.Store(mapId, zoneId, layerId);
                    
                    // Queue notification for after lock release (avoids deadlock)
                    ObjectGuid playerGuid = ObjectGuid::Create<HighGuid::Player>(playerLow);
                    playersToNotify.emplace_back(playerGuid, layerId);
                }
            }
            
            playerIdx++;
        }
    }
    
    _rebalancingMetrics.playersMigrated.fetch_add(migratedCount, std::memory_order_relaxed);
    
    if (originalLayerCount > targetDistribution.size())
    {
        _rebalancingMetrics.layersConsolidated.fetch_add(
            static_cast<uint32>(originalLayerCount - targetDistribution.size()), 
            std::memory_order_relaxed);
    }
    
    LOG_INFO("map.partition", "Layer consolidation complete for map {} zone {} - {} layers -> {} layers, {} players migrated",
        mapId, zoneId, originalLayerCount, targetDistribution.size(), migratedCount);
    }  // Release _layerLock here

    // Send notifications outside the lock to avoid deadlock with ObjectAccessor
    for (auto const& [guid, layerId] : playersToNotify)
    {
        if (Player* player = ObjectAccessor::FindPlayer(guid))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "You have been moved to Layer %u for better population balance.", layerId);
        }
    }
}
