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
#include "Log.h"
#include "Grids/GridDefines.h"
#include "GameTime.h"
#include "DatabaseEnv.h"
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

bool PartitionManager::IsMapPartitioned(uint32 mapId) const
{
    std::lock_guard<std::mutex> guard(_lock);
    return _partitionedMaps.find(mapId) != _partitionedMaps.end();
}

uint32 PartitionManager::GetPartitionIdForPosition(uint32 mapId, float x, float y) const
{
    uint32 count = GetPartitionCount(mapId);
    if (count <= 1)
        return 1;

    uint32 cols = static_cast<uint32>(std::floor(std::sqrt(static_cast<float>(count))));
    if (cols == 0)
        cols = 1;
    uint32 rows = (count + cols - 1) / cols;

    uint32 gridMax = MAX_NUMBER_OF_GRIDS;
    uint32 cellWidth = (gridMax + cols - 1) / cols;
    uint32 cellHeight = (gridMax + rows - 1) / rows;

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
            std::lock_guard<std::mutex> guard(_lock);
            auto ownership = _partitionOwnership.find(guid.GetCounter());
            if (ownership != _partitionOwnership.end() && ownership->second.mapId == mapId)
                return ownership->second.partitionId;
        }

        uint64 nowMs = GameTime::GetGameTimeMS().count();
        std::lock_guard<std::mutex> guard(_lock);
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

bool PartitionManager::IsNearPartitionBoundary(uint32 mapId, float x, float y) const
{
    uint32 count = GetPartitionCount(mapId);
    if (count <= 1)
        return false;

    float overlap = GetBorderOverlap();
    uint32 overlapGrids = static_cast<uint32>(std::ceil(overlap / SIZE_OF_GRIDS));
    if (overlapGrids == 0)
        overlapGrids = 1;

    uint32 cols = static_cast<uint32>(std::floor(std::sqrt(static_cast<float>(count))));
    if (cols == 0)
        cols = 1;
    uint32 rows = (count + cols - 1) / cols;

    uint32 gridMax = MAX_NUMBER_OF_GRIDS;
    uint32 cellWidth = (gridMax + cols - 1) / cols;
    uint32 cellHeight = (gridMax + rows - 1) / rows;

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
    std::lock_guard<std::mutex> guard(_lock);

    auto it = _partitionsByMap.find(mapId);
    if (it == _partitionsByMap.end())
        return 0;

    return static_cast<uint32>(it->second.size());
}

void PartitionManager::RegisterPartition(std::unique_ptr<MapPartition> partition)
{
    if (!partition)
        return;

    std::lock_guard<std::mutex> guard(_lock);
    _partitionsByMap[partition->GetMapId()].push_back(std::move(partition));
}

void PartitionManager::ClearPartitions(uint32 mapId)
{
    std::lock_guard<std::mutex> guard(_lock);
    _partitionsByMap.erase(mapId);
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
        std::lock_guard<std::mutex> guard(_lock);
        _partitionedMaps.clear();
        _partitionsByMap.clear();
        _partitionOwnership.clear();
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
            std::lock_guard<std::mutex> guard(_lock);
            _partitionedMaps.insert(mapId);
        }

        ClearPartitions(mapId);
        for (uint32 i = 0; i < defaultCount; ++i)
        {
            auto name = "Partition " + std::to_string(i + 1);
            RegisterPartition(std::make_unique<MapPartition>(mapId, i + 1, name));
        }

        LOG_INFO("map.partition", "Initialized {} partitions for map {}", defaultCount, mapId);
    }

    if (IsEnabled())
    {
        QueryResult result = CharacterDatabase.Query("SELECT guid, map_id, partition_id FROM dc_character_partition_ownership");
        if (result)
        {
            std::lock_guard<std::mutex> guard(_lock);
            do
            {
                Field* fields = result->Fetch();
                ObjectGuid::LowType guid = fields[0].Get<uint64>();
                uint32 mapId = fields[1].Get<uint32>();
                uint32 partitionId = fields[2].Get<uint32>();
                if (partitionId == 0)
                    continue;
                if (_partitionedMaps.find(mapId) == _partitionedMaps.end())
                    continue;
                _partitionOwnership[guid] = { mapId, partitionId };
            } while (result->NextRow());
        }
    }
}

bool PartitionManager::GetPersistentPartition(ObjectGuid const& guid, uint32 mapId, uint32& outPartitionId) const
{
    if (!guid)
        return false;

    std::lock_guard<std::mutex> guard(_lock);
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
    {
        std::lock_guard<std::mutex> guard(_lock);
        auto& ownership = _partitionOwnership[guid.GetCounter()];
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
}

void PartitionManager::UpdatePartitionsForMap(uint32 mapId, uint32 diff)
{
    std::lock_guard<std::mutex> guard(_lock);
    auto it = _partitionsByMap.find(mapId);
    if (it == _partitionsByMap.end())
        return;

    for (auto const& partition : it->second)
    {
        if (partition)
            partition->Update(diff);
    }
}

void PartitionManager::UpdatePartitionStats(uint32 mapId, uint32 partitionId, uint32 players, uint32 creatures, uint32 boundaryObjects)
{
    std::lock_guard<std::mutex> guard(_lock);
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

// RecordBoundaryObject removed - use RegisterBoundaryObject instead

void PartitionManager::UpdatePartitionPlayerCount(uint32 mapId, uint32 partitionId, uint32 players)
{
    std::lock_guard<std::mutex> guard(_lock);
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
    std::lock_guard<std::mutex> guard(_lock);
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
    std::lock_guard<std::mutex> guard(_lock);
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
    std::lock_guard<std::mutex> guard(_lock);
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
        std::lock_guard<std::mutex> guard(_lock);
        _visibilitySets[mapId][partitionId].insert(guid.GetCounter());
    }
    LOG_DEBUG("visibility.partition", "Attach visibility guid {} map {} partition {}", guid.GetCounter(), mapId, partitionId);
}

void PartitionManager::NotifyVisibilityDetach(ObjectGuid const& guid, uint32 mapId, uint32 partitionId)
{
    {
        std::lock_guard<std::mutex> guard(_lock);
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
    std::lock_guard<std::mutex> guard(_lock);
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
    std::lock_guard<std::mutex> guard(_lock);
    ++_combatHandoffCounts[mapId];
}

void PartitionManager::RecordPathHandoff(uint32 mapId)
{
    std::lock_guard<std::mutex> guard(_lock);
    ++_pathHandoffCounts[mapId];
}

uint32 PartitionManager::ConsumeCombatHandoffCount(uint32 mapId)
{
    std::lock_guard<std::mutex> guard(_lock);
    uint32 count = _combatHandoffCounts[mapId];
    _combatHandoffCounts[mapId] = 0;
    return count;
}

uint32 PartitionManager::ConsumePathHandoffCount(uint32 mapId)
{
    std::lock_guard<std::mutex> guard(_lock);
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

    std::lock_guard<std::mutex> guard(_lock);
    _partitionOverrides[guid.GetCounter()] = entry;
}

// RecordBoundaryPlayer removed - use RegisterBoundaryObject instead

uint32 PartitionManager::GetBoundaryCount(uint32 mapId, uint32 partitionId) const
{
    std::lock_guard<std::mutex> guard(_lock);
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
    std::lock_guard<std::mutex> guard(_lock);
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
    std::lock_guard<std::mutex> guard(_lock);
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
    std::lock_guard<std::mutex> guard(_lock);
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

std::vector<uint32> PartitionManager::GetAdjacentPartitions(uint32 mapId, uint32 partitionId) const
{
    std::vector<uint32> result;
    uint32 count = GetPartitionCount(mapId);
    if (count <= 1)
        return result;

    // Calculate grid layout (same logic as GetPartitionIdForPosition)
    uint32 cols = static_cast<uint32>(std::floor(std::sqrt(static_cast<float>(count))));
    if (cols == 0)
        cols = 1;
    uint32 rows = (count + cols - 1) / cols;

    // Convert partition ID to row/col (0-indexed internally, 1-indexed for partition IDs)
    uint32 index = partitionId - 1;
    uint32 partitionRow = index / cols;
    uint32 partitionCol = index % cols;

    // Check all 8 neighbors
    for (int32 dRow = -1; dRow <= 1; ++dRow)
    {
        for (int32 dCol = -1; dCol <= 1; ++dCol)
        {
            if (dRow == 0 && dCol == 0)
                continue; // Skip self

            int32 neighborRow = static_cast<int32>(partitionRow) + dRow;
            int32 neighborCol = static_cast<int32>(partitionCol) + dCol;

            // Bounds check
            if (neighborRow < 0 || neighborCol < 0)
                continue;
            if (static_cast<uint32>(neighborRow) >= rows || static_cast<uint32>(neighborCol) >= cols)
                continue;

            uint32 neighborIndex = static_cast<uint32>(neighborRow) * cols + static_cast<uint32>(neighborCol);
            if (neighborIndex >= count)
                continue;

            result.push_back(neighborIndex + 1); // Convert back to 1-indexed partition ID
        }
    }

    return result;
}

std::vector<ObjectGuid> PartitionManager::GetBoundaryObjectGuids(uint32 mapId, uint32 partitionId) const
{
    std::vector<ObjectGuid> result;
    std::lock_guard<std::mutex> guard(_lock);

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

    std::lock_guard<std::mutex> guard(_lock);
    _boundaryObjects[mapId][partitionId].insert(guid);

    LOG_DEBUG("map.partition", "Registered boundary object {} in map {} partition {}", guid.ToString(), mapId, partitionId);
}

void PartitionManager::UnregisterBoundaryObject(uint32 mapId, uint32 partitionId, ObjectGuid const& guid)
{
    if (!guid)
        return;

    std::lock_guard<std::mutex> guard(_lock);
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

    std::lock_guard<std::mutex> guard(_lock);
    auto mapIt = _boundaryObjects.find(mapId);
    if (mapIt == _boundaryObjects.end())
        return false;

    auto partitionIt = mapIt->second.find(partitionId);
    if (partitionIt == mapIt->second.end())
        return false;

    return partitionIt->second.find(guid) != partitionIt->second.end();
}
