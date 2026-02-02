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
#include "Player.h"
#include "ObjectAccessor.h"
#include <cmath>
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
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    return _excludedZones.count(zoneId) > 0;
}

bool PartitionManager::IsLayeringEnabled() const
{
    return sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_LAYERS_ENABLED);
}

uint32_t PartitionManager::GetLayerCapacity() const
{
    return sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_LAYER_CAPACITY);
}

uint32_t PartitionManager::GetLayerForPlayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid) const
{
    std::lock_guard<std::mutex> guard(_layerLock);
    auto it = _playerLayers.find(playerGuid.GetCounter());
    if (it != _playerLayers.end())
    {
        // Optional: Verify map/zone match?
        if (it->second.mapId == mapId && it->second.zoneId == zoneId)
            return it->second.layerId;
    }
    return 0; // Default layer
}

uint32 PartitionManager::GetPlayerLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& playerGuid) const
{
    return GetLayerForPlayer(mapId, zoneId, playerGuid);
}

uint32_t PartitionManager::GetLayerCount(uint32_t mapId, uint32_t zoneId) const
{
    std::lock_guard<std::mutex> guard(_layerLock);
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
    std::lock_guard<std::mutex> guard(_layerLock);
    
    // Remove from old layer if exists
    auto it = _playerLayers.find(playerGuid.GetCounter());
    if (it != _playerLayers.end())
    {
        auto& oldLayer = _layers[it->second.mapId][it->second.zoneId][it->second.layerId];
        oldLayer.erase(playerGuid.GetCounter());
    }

    // Assign to new
    _layers[mapId][zoneId][layerId].insert(playerGuid.GetCounter());
    _playerLayers[playerGuid.GetCounter()] = { mapId, zoneId, layerId };
}

void PartitionManager::RemovePlayerFromLayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid)
{
    std::lock_guard<std::mutex> guard(_layerLock);
    auto it = _playerLayers.find(playerGuid.GetCounter());
    if (it == _playerLayers.end())
        return;

    if (it->second.mapId != mapId || it->second.zoneId != zoneId)
        return;

    auto& oldLayer = _layers[it->second.mapId][it->second.zoneId][it->second.layerId];
    oldLayer.erase(playerGuid.GetCounter());
    _playerLayers.erase(it);
}

void PartitionManager::AutoAssignPlayerToLayer(uint32_t mapId, uint32_t zoneId, ObjectGuid const& playerGuid)
{
    if (!IsLayeringEnabled())
        return;

    // First check if party member should sync to leader's layer (outside of lock to avoid deadlock)
    uint32 partyTargetLayer = GetPartyTargetLayer(mapId, zoneId, playerGuid);

    std::lock_guard<std::mutex> guard(_layerLock);

    // If player is already assigned to a layer in this zone, keep them there (stickiness)
    auto it = _playerLayers.find(playerGuid.GetCounter());
    if (it != _playerLayers.end() && it->second.mapId == mapId && it->second.zoneId == zoneId)
    {
        // If party leader is on a different layer, move to match them
        if (partyTargetLayer > 0 && it->second.layerId != partyTargetLayer)
        {
            // Remove from old layer
            auto& oldLayerPlayers = _layers[mapId][zoneId][it->second.layerId];
            oldLayerPlayers.erase(playerGuid.GetCounter());
            
            // Assign to party leader's layer
            _layers[mapId][zoneId][partyTargetLayer].insert(playerGuid.GetCounter());
            _playerLayers[playerGuid.GetCounter()] = { mapId, zoneId, partyTargetLayer };
            
            LOG_DEBUG("map.partition", "Player {} moved to party leader's Layer {} in Map {} Zone {}", 
                playerGuid.ToString(), partyTargetLayer, mapId, zoneId);
            
            // Save persistent assignment (async)
            SavePersistentLayerAssignment(playerGuid, mapId, zoneId, partyTargetLayer);
        }
        return;
    }

    // If they were in a different zone/map, remove old assignment first
    if (it != _playerLayers.end())
    {
        auto& oldLayer = _layers[it->second.mapId][it->second.zoneId][it->second.layerId];
        oldLayer.erase(playerGuid.GetCounter());
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
        for (auto& [layerId, players] : zoneLayers)
        {
            if (players.size() < GetLayerCapacity())
            {
                bestLayerId = layerId;
                foundLayer = true;
                break;
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
                bestLayerId = maxId + 1;
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

    // Save persistent assignment (async) - always save so we can restore on login
    SavePersistentLayerAssignment(playerGuid, mapId, zoneId, bestLayerId);
}


bool PartitionManager::IsMapPartitioned(uint32 mapId) const
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    return _partitionedMaps.find(mapId) != _partitionedMaps.end();
}

uint32 PartitionManager::GetPartitionIdForPosition(uint32 mapId, float x, float y) const
{
    PartitionGridLayout layout;
    bool hasLayout = false;
    {
        std::shared_lock<std::shared_mutex> guard(_partitionLock);
        auto it = _gridLayouts.find(mapId);
        if (it != _gridLayouts.end())
        {
            layout = it->second;
            hasLayout = true;
        }
    }

    uint32 count = hasLayout ? layout.count : GetPartitionCount(mapId);
    if (count <= 1)
        return 1;

    uint32 cols = hasLayout ? layout.cols : static_cast<uint32>(std::floor(std::sqrt(static_cast<float>(count))));
    if (cols == 0)
        cols = 1;
    uint32 rows = hasLayout ? layout.rows : (count + cols - 1) / cols;

    uint32 gridMax = MAX_NUMBER_OF_GRIDS;
    uint32 cellWidth = hasLayout ? layout.cellWidth : (gridMax + cols - 1) / cols;
    uint32 cellHeight = hasLayout ? layout.cellHeight : (gridMax + rows - 1) / rows;

    GridCoord coord = Acore::ComputeGridCoord(x, y);
    uint32 col = std::min(coord.x_coord / cellWidth, cols - 1);
    uint32 row = std::min(coord.y_coord / cellHeight, rows - 1);

    uint32 index = row * cols + col;
    if (index >= count)
        index = count - 1;

    return index + 1;
}

uint32 PartitionManager::GetPartitionIdForPosition(uint32 mapId, float x, float y, ObjectGuid const& guid) const
{
    if (guid)
    {
        {
            std::lock_guard<std::mutex> guard(_overrideLock);
            auto ownership = _partitionOwnership.find(guid.GetCounter());
            if (ownership != _partitionOwnership.end() && ownership->second.mapId == mapId)
                return ownership->second.partitionId;
        }

        uint64 nowMs = GameTime::GetGameTimeMS().count();
        std::lock_guard<std::mutex> guard(_overrideLock);
        auto it = _partitionOverrides.find(guid.GetCounter());
        if (it != _partitionOverrides.end())
        {
            if (it->second.expiresMs >= nowMs)
                return it->second.partitionId;

            _partitionOverrides.erase(it);
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
    bool hasLayout = false;
    {
        std::shared_lock<std::shared_mutex> guard(_partitionLock);
        auto it = _gridLayouts.find(mapId);
        if (it != _gridLayouts.end())
        {
            layout = it->second;
            hasLayout = true;
        }
    }

    uint32 count = hasLayout ? layout.count : GetPartitionCount(mapId);
    if (count <= 1)
        return false;

    float overlap = GetBorderOverlap();
    uint32 overlapGrids = static_cast<uint32>(std::ceil(overlap / SIZE_OF_GRIDS));
    if (overlapGrids == 0)
        overlapGrids = 1;

    uint32 cols = hasLayout ? layout.cols : static_cast<uint32>(std::floor(std::sqrt(static_cast<float>(count))));
    if (cols == 0)
        cols = 1;
    uint32 rows = hasLayout ? layout.rows : (count + cols - 1) / cols;

    uint32 gridMax = MAX_NUMBER_OF_GRIDS;
    uint32 cellWidth = hasLayout ? layout.cellWidth : (gridMax + cols - 1) / cols;
    uint32 cellHeight = hasLayout ? layout.cellHeight : (gridMax + rows - 1) / rows;

    GridCoord coord = Acore::ComputeGridCoord(x, y);
    uint32 col = std::min(coord.x_coord / cellWidth, cols - 1);
    uint32 row = std::min(coord.y_coord / cellHeight, rows - 1);

    uint32 startX = col * cellWidth;
    uint32 endX = std::min(startX + cellWidth - 1, gridMax - 1);
    uint32 startY = row * cellHeight;
    uint32 endY = std::min(startY + cellHeight - 1, gridMax - 1);

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
    _partitionsByMap[partition->GetMapId()].push_back(std::move(partition));
}

void PartitionManager::ClearPartitions(uint32 mapId)
{
    std::unique_lock<std::shared_mutex> guard(_partitionLock);
    _partitionsByMap.erase(mapId);
    _gridLayouts.erase(mapId);
    
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
        _gridLayouts.clear();
        _excludedZones.clear();
    }
    {
        std::lock_guard<std::mutex> guard(_overrideLock);
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
            PartitionGridLayout layout;
            layout.count = defaultCount;
            layout.cols = static_cast<uint32>(std::floor(std::sqrt(static_cast<float>(layout.count))));
            if (layout.cols == 0)
                layout.cols = 1;
            layout.rows = (layout.count + layout.cols - 1) / layout.cols;
            uint32 gridMax = MAX_NUMBER_OF_GRIDS;
            layout.cellWidth = (gridMax + layout.cols - 1) / layout.cols;
            layout.cellHeight = (gridMax + layout.rows - 1) / layout.rows;
            _gridLayouts[mapId] = layout;
        }

        LOG_INFO("map.partition", "Initialized {} partitions for map {}", defaultCount, mapId);
    }

    if (IsEnabled())
    {
        QueryResult result = CharacterDatabase.Query("SELECT guid, map_id, partition_id FROM dc_character_partition_ownership");
        if (result)
        {
            std::lock_guard<std::mutex> guard(_overrideLock);
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

    std::lock_guard<std::mutex> guard(_overrideLock);
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
        std::lock_guard<std::mutex> guard(_overrideLock);
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

    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    auto it = _partitionsByMap.find(mapId);
    if (it == _partitionsByMap.end())
        return;

    for (auto const& partition : it->second)
    {
        if (partition)
            partition->Update(diff);
    }
    
    // Feature 4: Dynamic Resizing Evaluation (Periodically)
    // Check roughly once per second using global time to avoid per-map state
    // Use mapId as offset to spread load across frames
    uint64 now = GameTime::GetGameTimeMS().count();
    if ((now + mapId) % 1000 < diff)
    {
        EvaluatePartitionDensity(mapId);
    }
}

void PartitionManager::UpdatePartitionStats(uint32 mapId, uint32 partitionId, uint32 players, uint32 creatures, uint32 boundaryObjects)
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    auto it = _partitionsByMap.find(mapId);
    if (it == _partitionsByMap.end())
        return;

    for (auto const& partition : it->second)
    {
        if (partition && partition->GetPartitionId() == partitionId)
        {
            partition->SetCounts(players, creatures, boundaryObjects);
            return;
        }
    }
}



void PartitionManager::UpdatePartitionPlayerCount(uint32 mapId, uint32 partitionId, uint32 players)
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    auto it = _partitionsByMap.find(mapId);
    if (it == _partitionsByMap.end())
        return;

    for (auto const& partition : it->second)
    {
        if (partition && partition->GetPartitionId() == partitionId)
        {
            partition->SetPlayersCount(players);
            return;
        }
    }
}

void PartitionManager::UpdatePartitionCreatureCount(uint32 mapId, uint32 partitionId, uint32 creatures)
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    auto it = _partitionsByMap.find(mapId);
    if (it == _partitionsByMap.end())
        return;

    for (auto const& partition : it->second)
    {
        if (partition && partition->GetPartitionId() == partitionId)
        {
            partition->SetCreaturesCount(creatures);
            return;
        }
    }
}

void PartitionManager::UpdatePartitionBoundaryCount(uint32 mapId, uint32 partitionId, uint32 boundaryObjects)
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    auto it = _partitionsByMap.find(mapId);
    if (it == _partitionsByMap.end())
        return;

    for (auto const& partition : it->second)
    {
        if (partition && partition->GetPartitionId() == partitionId)
        {
            partition->SetBoundaryObjectCount(boundaryObjects);
            return;
        }
    }
}

bool PartitionManager::GetPartitionStats(uint32 mapId, uint32 partitionId, PartitionStats& out) const
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    auto it = _partitionsByMap.find(mapId);
    if (it == _partitionsByMap.end())
        return false;

    for (auto const& partition : it->second)
    {
        if (partition && partition->GetPartitionId() == partitionId)
        {
            out.players = partition->GetPlayersCount();
            out.creatures = partition->GetCreaturesCount();
            out.boundaryObjects = partition->GetBoundaryObjectCount();
            return true;
        }
    }
    return false;
}

void PartitionManager::NotifyVisibilityAttach(ObjectGuid const& guid, uint32 mapId, uint32 partitionId)
{
    {
        std::lock_guard<std::mutex> guard(_visibilityLock);
        _visibilitySets[mapId][partitionId].insert(guid.GetCounter());
    }
    LOG_DEBUG("visibility.partition", "Attach visibility guid {} map {} partition {}", guid.GetCounter(), mapId, partitionId);
}

void PartitionManager::NotifyVisibilityDetach(ObjectGuid const& guid, uint32 mapId, uint32 partitionId)
{
    {
        std::lock_guard<std::mutex> guard(_visibilityLock);
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
    std::lock_guard<std::mutex> guard(_visibilityLock);
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

    std::lock_guard<std::mutex> guard(_overrideLock);
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
    std::lock_guard<std::mutex> guard(_overrideLock);
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

    for (auto it = partitionIt->second.begin(); it != partitionIt->second.end();)
    {
        if (validGuids.find(*it) == validGuids.end())
            it = partitionIt->second.erase(it);
        else
            ++it;
    }
}

void PartitionManager::ForceRemovePlayerFromAllLayers(ObjectGuid const& playerGuid)
{
    std::lock_guard<std::mutex> guard(_layerLock);
    auto it = _playerLayers.find(playerGuid.GetCounter());
    if (it != _playerLayers.end())
    {
        auto& layer = _layers[it->second.mapId][it->second.zoneId][it->second.layerId];
        layer.erase(playerGuid.GetCounter());
        _playerLayers.erase(it);
        LOG_DEBUG("map.partition", "Force removed player {} from all layers", playerGuid.ToString());
    }
}

std::pair<uint32_t, uint32_t> PartitionManager::GetLayersForTwoPlayers(
    uint32_t mapId, uint32_t zoneId, 
    ObjectGuid const& player1, ObjectGuid const& player2) const
{
    std::lock_guard<std::mutex> guard(_layerLock);
    
    uint32_t layer1 = 0;
    uint32_t layer2 = 0;
    
    auto it1 = _playerLayers.find(player1.GetCounter());
    if (it1 != _playerLayers.end() && it1->second.mapId == mapId && it1->second.zoneId == zoneId)
        layer1 = it1->second.layerId;
    
    auto it2 = _playerLayers.find(player2.GetCounter());
    if (it2 != _playerLayers.end() && it2->second.mapId == mapId && it2->second.zoneId == zoneId)
        layer2 = it2->second.layerId;
    
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
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    return GetGridLayout(mapId);
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
    std::lock_guard<std::mutex> guard(_layerLock);
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
    stmt->SetData(4, static_cast<uint32>(GameTime::GetGameTime().count()));
    CharacterDatabase.Execute(stmt);
    
    LOG_DEBUG("map.partition", "Saved persistent layer {} for player {} in map {} zone {}",
        layerId, playerGuid.ToString(), mapId, zoneId);
}

// ======================== FEATURE 2: Cross-Layer Party Communication ========================

uint32 PartitionManager::GetPartyTargetLayer(uint32 mapId, uint32 zoneId, ObjectGuid const& playerGuid)
{
    if (!IsLayeringEnabled())
        return 0;

    Player* player = ObjectAccessor::FindPlayer(playerGuid);
    if (!player)
        return 0;

    Group* group = player->GetGroup();
    if (!group)
        return 0;

    ObjectGuid leaderGuid = group->GetLeaderGUID();
    if (leaderGuid == playerGuid)
        return 0; // Player is leader, no target layer

    std::lock_guard<std::mutex> guard(_layerLock);
    auto it = _playerLayers.find(leaderGuid.GetCounter());
    if (it == _playerLayers.end())
        return 0;

    // Only return leader's layer if they're in the same map and zone
    if (it->second.mapId != mapId || it->second.zoneId != zoneId)
        return 0;

    LOG_DEBUG("map.partition", "Party sync: Player {} targeting leader {} layer {} in map {} zone {}",
        playerGuid.ToString(), leaderGuid.ToString(), it->second.layerId, mapId, zoneId);
    
    return it->second.layerId;
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

    std::lock_guard<std::mutex> guard(_layerLock);
    _npcLayers[npcGuid.GetCounter()] = { mapId, zoneId, layerId };
    
    LOG_DEBUG("map.partition", "Assigned NPC {} to layer {} in map {} zone {}",
        npcGuid.ToString(), layerId, mapId, zoneId);
}

void PartitionManager::RemoveNPCFromLayer(ObjectGuid const& npcGuid)
{
    std::lock_guard<std::mutex> guard(_layerLock);
    _npcLayers.erase(npcGuid.GetCounter());
}

uint32 PartitionManager::GetLayerForNPC(uint32 mapId, uint32 zoneId, ObjectGuid const& npcGuid) const
{
    std::lock_guard<std::mutex> guard(_layerLock);
    auto it = _npcLayers.find(npcGuid.GetCounter());
    if (it == _npcLayers.end())
        return 0;
    
    if (it->second.mapId != mapId || it->second.zoneId != zoneId)
        return 0;
    
    return it->second.layerId;
}

uint32 PartitionManager::GetLayerForNPC(ObjectGuid const& npcGuid) const
{
    std::lock_guard<std::mutex> guard(_layerLock);
    auto it = _npcLayers.find(npcGuid.GetCounter());
    if (it == _npcLayers.end())
        return 0;

    return it->second.layerId;
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
    float splitThreshold = GetDensitySplitThreshold();
    float mergeThreshold = GetDensityMergeThreshold();
    
    for (uint32 pid = 1; pid <= partitionCount; ++pid)
    {
        float density = GetPartitionDensity(mapId, pid);
        
        if (density > splitThreshold)
        {
            LOG_DEBUG("map.partition", "Partition {} on map {} density {} exceeds split threshold {}", 
                pid, mapId, density, splitThreshold);
            // TODO: Implement split logic
        }
        else if (density < mergeThreshold)
        {
            LOG_DEBUG("map.partition", "Partition {} on map {} density {} below merge threshold {}", 
                pid, mapId, density, mergeThreshold);
            // TODO: Implement merge logic with adjacent low-density partitions
        }
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
        
        // TODO: Queue precache request for predictedPartition
        // This would involve loading creature/GO data for that partition
        // into a ready cache so the transition is seamless
    }
}

void PartitionManager::ProcessPrecacheQueue()
{
    // NOTE: Placeholder for processing precache queue
    // Full implementation would:
    // 1. Process queue of partition precache requests
    // 2. Load creature/GO templates for target partition
    // 3. Warm visibility caches
    // 4. Limit work per frame to avoid spikes
    
    // Currently no-op - precaching not yet implemented
}
