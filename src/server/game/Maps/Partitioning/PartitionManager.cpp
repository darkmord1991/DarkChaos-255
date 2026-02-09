/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
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
#include "LayerManager.h"
#include "Define.h"
#include "World.h"
#include "WorldConfig.h"
#include "Log.h"
#include "Grids/GridDefines.h"
#include "GameTime.h"
#include "DatabaseEnv.h"
#include "QueryResult.h"
#include "Map.h"
#include "MapMgr.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Position.h"
#include <algorithm>
#include <cmath>
#include <cctype>
#include <filesystem>
#include <functional>
#include <limits>
#include <sstream>
#include <string>
#include <unordered_map>
namespace
{
    std::unordered_map<uint32, uint32> ParseTileOverrides(std::string_view overrides)
    {
        std::unordered_map<uint32, uint32> result;
        if (overrides.empty())
            return result;

        std::string copy(overrides.begin(), overrides.end());
        std::istringstream stream(copy);
        std::string token;
        while (std::getline(stream, token, ','))
        {
            auto start = token.find_first_not_of(" \t");
            auto end = token.find_last_not_of(" \t");
            if (start == std::string::npos)
                continue;
            token = token.substr(start, end - start + 1);

            auto colonPos = token.find(':');
            if (colonPos == std::string::npos || colonPos == 0 || colonPos == token.size() - 1)
                continue;

            try
            {
                uint32 mapId = static_cast<uint32>(std::stoul(token.substr(0, colonPos)));
                uint32 tilesPerPartition = static_cast<uint32>(std::stoul(token.substr(colonPos + 1)));
                if (tilesPerPartition == 0)
                    continue;
                result[mapId] = tilesPerPartition;
            }
            catch (std::exception const&)
            {
                continue;
            }
        }

        return result;
    }

    std::unordered_map<uint32, uint32> ParsePartitionCountOverrides(std::string_view overrides)
    {
        std::unordered_map<uint32, uint32> result;
        if (overrides.empty())
            return result;

        std::string copy(overrides.begin(), overrides.end());
        std::istringstream stream(copy);
        std::string token;
        while (std::getline(stream, token, ','))
        {
            auto start = token.find_first_not_of(" \t");
            auto end = token.find_last_not_of(" \t");
            if (start == std::string::npos)
                continue;
            token = token.substr(start, end - start + 1);

            auto colonPos = token.find(':');
            if (colonPos == std::string::npos || colonPos == 0 || colonPos == token.size() - 1)
                continue;

            try
            {
                uint32 mapId = static_cast<uint32>(std::stoul(token.substr(0, colonPos)));
                uint32 count = static_cast<uint32>(std::stoul(token.substr(colonPos + 1)));
                if (count == 0)
                    continue;
                result[mapId] = count;
            }
            catch (std::exception const&)
            {
                continue;
            }
        }

        return result;
    }

    std::unordered_map<uint32, uint32> BuildMapTileCounts(std::filesystem::path const& mapsPath)
    {
        std::unordered_map<uint32, uint32> counts;
        if (!std::filesystem::exists(mapsPath))
            return counts;

        for (auto const& entry : std::filesystem::directory_iterator(mapsPath))
        {
            if (!entry.is_regular_file())
                continue;

            auto name = entry.path().filename().string();
            if (name.size() < 5 || name.compare(name.size() - 4, 4, ".map") != 0)
                continue;

            size_t mapIdDigits = name.size() - 4;
            if (mapIdDigits == 0)
                continue;

            bool allDigits = true;
            for (char c : name)
            {
                if (!std::isdigit(static_cast<unsigned char>(c)))
                {
                    allDigits = false;
                    break;
                }
            }
            if (!allDigits)
                continue;

            uint32 mapId = 0;
            try
            {
                mapId = static_cast<uint32>(std::stoul(name.substr(0, mapIdDigits)));
            }
            catch (std::exception const&)
            {
                continue;
            }

            ++counts[mapId];
        }

        return counts;
    }
}



std::shared_mutex& PartitionManager::GetBoundaryLock(uint32 mapId) const
{
    return _boundaryLocks[mapId % kBoundaryLockStripes];
}

std::shared_mutex& PartitionManager::GetVisibilityLock(uint32 mapId) const
{
    return _visibilityLocks[mapId % kVisibilityLockStripes];
}

std::vector<std::unique_lock<std::shared_mutex>> PartitionManager::LockAllBoundaryStripes() const
{
    std::vector<std::unique_lock<std::shared_mutex>> locks;
    locks.reserve(kBoundaryLockStripes);
    for (size_t i = 0; i < kBoundaryLockStripes; ++i)
        locks.emplace_back(_boundaryLocks[i]);
    return locks;
}

std::vector<std::unique_lock<std::shared_mutex>> PartitionManager::LockAllVisibilityStripes() const
{
    std::vector<std::unique_lock<std::shared_mutex>> locks;
    locks.reserve(kVisibilityLockStripes);
    for (size_t i = 0; i < kVisibilityLockStripes; ++i)
        locks.emplace_back(_visibilityLocks[i]);
    return locks;
}

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

bool PartitionManager::IsRuntimeDiagnosticsEnabled() const
{
    return _runtimeDiagnostics.load(std::memory_order_relaxed);
}

// Layering implementations moved to LayerManager.cpp


bool PartitionManager::IsMapPartitioned(uint32 mapId) const
{
    std::shared_lock<std::shared_mutex> guard(_partitionLock);
    return _partitionedMaps.find(mapId) != _partitionedMaps.end();
}

uint32 PartitionManager::GetPartitionIdForPosition(uint32 mapId, float x, float y) const
{
    // Use thread_local cached layout to avoid acquiring _partitionLock every call
    PartitionGridLayout const* cachedLayout = GetCachedLayout(mapId);
    if (!cachedLayout || cachedLayout->count <= 1)
        return 1;

    PartitionGridLayout const& layout = *cachedLayout;

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
            if (it != _partitionOverrides.end() && it->second.mapId == mapId)
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
    // Use thread_local cached layout to avoid acquiring _partitionLock every call
    PartitionGridLayout const* cachedLayout = GetCachedLayout(mapId);
    if (!cachedLayout || cachedLayout->count <= 1)
        return false;

    PartitionGridLayout const& layout = *cachedLayout;

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

    // Defensive: if coord is outside partition cell bounds (extreme map edge), treat as boundary
    if (coord.x_coord < startX || coord.x_coord > endX ||
        coord.y_coord < startY || coord.y_coord > endY)
        return true;

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

    std::unique_lock<std::shared_mutex> bGuard(GetBoundaryLock(mapId));
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

    bool tileBased = sWorld->getBoolConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_ENABLED);
    uint32 tilesPerPartitionDefault = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_TILES_PER_PARTITION);
    uint32 minPartitions = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_MIN_PARTITIONS);
    uint32 maxPartitions = sWorld->getIntConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_MAX_PARTITIONS);
    if (minPartitions == 0)
        minPartitions = 1;
    if (maxPartitions == 0)
        maxPartitions = 1;

    std::unordered_map<uint32, uint32> tilesPerPartitionOverrides;
    std::unordered_map<uint32, uint32> mapTileCounts;
    std::unordered_map<uint32, uint32> partitionCountOverrides;
    {
        std::string_view countOverrides = sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_PARTITION_OVERRIDES);
        partitionCountOverrides = ParsePartitionCountOverrides(countOverrides);
    }
    if (tileBased && tilesPerPartitionDefault > 0)
    {
        tilesPerPartitionOverrides = ParseTileOverrides(
            sWorld->getStringConfig(CONFIG_MAP_PARTITIONS_TILE_BASED_TILES_PER_PARTITION_OVERRIDES));

        std::filesystem::path mapsPath = std::filesystem::path(sWorld->GetDataPath()) / "maps";
        mapTileCounts = BuildMapTileCounts(mapsPath);

        if (mapTileCounts.empty())
        {
            LOG_WARN("map.partition", "Tile-based partition sizing enabled, but no map tiles found in '{}'. Falling back to DefaultCount.",
                mapsPath.string());
        }
    }

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
        _partitionOverrides.clear();
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

        uint32 partitionCount = defaultCount;
        if (auto it = partitionCountOverrides.find(mapId); it != partitionCountOverrides.end())
        {
            partitionCount = it->second;
        }
        else if (tileBased && tilesPerPartitionDefault > 0)
        {
            uint32 tilesPerPartition = tilesPerPartitionDefault;
            if (auto it = tilesPerPartitionOverrides.find(mapId); it != tilesPerPartitionOverrides.end())
                tilesPerPartition = it->second;

            auto countIt = mapTileCounts.find(mapId);
            if (countIt != mapTileCounts.end() && tilesPerPartition > 0)
            {
                uint32 tileCount = countIt->second;
                partitionCount = (tileCount + tilesPerPartition - 1) / tilesPerPartition;
            }
        }

        if (partitionCount < minPartitions)
            partitionCount = minPartitions;
        if (partitionCount > maxPartitions)
            partitionCount = maxPartitions;

        ClearPartitions(mapId);
        for (uint32 i = 0; i < partitionCount; ++i)
        {
            auto name = "Partition " + std::to_string(i + 1);
            RegisterPartition(std::make_unique<MapPartition>(mapId, i + 1, name));
        }

        // Cache grid layout for this map
        {
            std::unique_lock<std::shared_mutex> guard(_partitionLock);
            _gridLayouts[mapId] = ComputeGridLayout(partitionCount);
            _layoutEpochByMap[mapId] = 1;
        }

        LOG_INFO("map.partition", "Initialized {} partitions for map {}", partitionCount, mapId);
    }

    if (IsEnabled())
    {
        CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_PARTITION_OWNERSHIP);
        sWorld->GetQueryProcessor().AddCallback(CharacterDatabase.AsyncQuery(stmt).WithPreparedCallback(
            std::bind(&PartitionManager::HandlePartitionOwnershipLoad, this, std::placeholders::_1)));
    }
}

void PartitionManager::HandlePartitionOwnershipLoad(PreparedQueryResult result)
{
    if (!result)
        return;

    // Snapshot partitioned maps once to avoid nested lock acquisition per row
    std::unordered_set<uint32> partitionedMapsSnapshot;
    {
        std::shared_lock<std::shared_mutex> mapGuard(_partitionLock);
        partitionedMapsSnapshot = _partitionedMaps;
    }

    // Parse all rows without holding any lock
    std::vector<std::pair<ObjectGuid::LowType, PartitionOwnership>> entries;
    do
    {
        Field* fields = result->Fetch();
        ObjectGuid::LowType guid = fields[0].Get<uint64>();
        uint32 mapId = fields[1].Get<uint32>();
        uint32 partitionId = fields[2].Get<uint32>();
        if (partitionId == 0)
            continue;
        if (partitionedMapsSnapshot.find(mapId) == partitionedMapsSnapshot.end())
            continue;
        entries.emplace_back(guid, PartitionOwnership{ mapId, partitionId });
    } while (result->NextRow());

    // Single bulk write under lock
    uint32 loaded = 0;
    if (!entries.empty())
    {
        std::unique_lock<std::shared_mutex> guard(_overrideLock);
        for (auto const& [guid, ownership] : entries)
        {
            _partitionOwnership[guid] = ownership;
            ++loaded;
        }
    }

    if (loaded && IsRuntimeDiagnosticsEnabled())
    {
        LOG_INFO("map.partition", "Diag: Loaded {} partition ownership assignments", loaded);
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
    // Throttle cleanup to once per second (was running every tick per map)
    uint64 now = GameTime::GetGameTimeMS().count();
    uint64 lastCleanup = _lastCleanupMs.load(std::memory_order_relaxed);
    if (now - lastCleanup >= 1000)
    {
        _lastCleanupMs.store(now, std::memory_order_relaxed);
        CleanupStaleRelocations();
        CleanupExpiredOverrides();
        PeriodicCacheSweep();
    }

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
        std::unique_lock<std::shared_mutex> guard(GetVisibilityLock(mapId));
        _visibilitySets[mapId][partitionId].insert(guid.GetCounter());
    }
    LOG_DEBUG("visibility.partition", "Attach visibility guid {} map {} partition {}", guid.GetCounter(), mapId, partitionId);
}

void PartitionManager::NotifyVisibilityDetach(ObjectGuid const& guid, uint32 mapId, uint32 partitionId)
{
    {
        std::unique_lock<std::shared_mutex> guard(GetVisibilityLock(mapId));
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
    std::shared_lock<std::shared_mutex> guard(GetVisibilityLock(mapId));
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

void PartitionManager::SetPartitionOverride(ObjectGuid const& guid, uint32 mapId, uint32 partitionId, uint32 durationMs)
{
    if (!guid)
        return;

    uint64 nowMs = GameTime::GetGameTimeMS().count();
    uint64 expiresMs = nowMs + durationMs;

    // Fast read-first check: skip redundant writes when override is already set
    // with the same partition and still has >50% remaining duration.
    // This avoids taking the exclusive write lock on the hot tick-per-entity path.
    {
        std::shared_lock<std::shared_mutex> readGuard(_overrideLock);
        auto it = _partitionOverrides.find(guid.GetCounter());
        if (it != _partitionOverrides.end() &&
            it->second.mapId == mapId &&
            it->second.partitionId == partitionId &&
            it->second.expiresMs > nowMs + durationMs / 2)
        {
            return; // Already set with sufficient remaining time
        }
    }

    PartitionOverride entry;
    entry.mapId = mapId;
    entry.partitionId = partitionId;
    entry.expiresMs = expiresMs;

    std::unique_lock<std::shared_mutex> guard(_overrideLock);
    _partitionOverrides[guid.GetCounter()] = entry;
}



uint32 PartitionManager::GetBoundaryCount(uint32 mapId, uint32 partitionId) const
{
    std::shared_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));
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
    std::shared_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));

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

    std::unique_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));
    _boundaryObjects[mapId][partitionId].insert(guid);

    LOG_DEBUG("map.partition", "Registered boundary object {} in map {} partition {}", guid.ToString(), mapId, partitionId);
}

void PartitionManager::UnregisterBoundaryObject(uint32 mapId, uint32 partitionId, ObjectGuid const& guid)
{
    if (!guid)
        return;

    std::unique_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));
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

    std::shared_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));
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

    std::unique_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));
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

    std::unique_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));
    _boundarySpatialGrids[mapId][partitionId].Update(guid, x, y);
    _boundaryObjects[mapId][partitionId].insert(guid);
}

void PartitionManager::UnregisterBoundaryObjectFromGrid(uint32 mapId, uint32 partitionId, ObjectGuid const& guid)
{
    if (!guid)
        return;

    std::unique_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));
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
    std::shared_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));
    
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
    std::unique_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));
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

// ──────────────────────────────────────────────────────────────────────────
// Batch boundary operations — reduces per-entity lock overhead to a single
// lock per batch (called once per partition per tick instead of once per entity)
// ──────────────────────────────────────────────────────────────────────────

void PartitionManager::BatchUpdateBoundaryPositions(uint32 mapId, uint32 partitionId,
    std::vector<BoundaryPositionUpdate> const& updates)
{
    if (updates.empty())
        return;

    std::unique_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));
    auto& grid = _boundarySpatialGrids[mapId][partitionId];
    auto& legacySet = _boundaryObjects[mapId][partitionId];

    for (auto const& upd : updates)
    {
        grid.Update(upd.guid, upd.x, upd.y);
        legacySet.insert(upd.guid);
    }
}

void PartitionManager::BatchUnregisterBoundaryObjects(uint32 mapId, uint32 partitionId,
    std::vector<ObjectGuid> const& guids)
{
    if (guids.empty())
        return;

    std::unique_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));

    SpatialHashGrid* spatialGrid = nullptr;
    auto spatialMapIt = _boundarySpatialGrids.find(mapId);
    if (spatialMapIt != _boundarySpatialGrids.end())
    {
        auto spatialPartIt = spatialMapIt->second.find(partitionId);
        if (spatialPartIt != spatialMapIt->second.end())
            spatialGrid = &spatialPartIt->second;
    }

    auto mapIt = _boundaryObjects.find(mapId);
    std::unordered_set<ObjectGuid>* legacySet = nullptr;
    if (mapIt != _boundaryObjects.end())
    {
        auto partIt = mapIt->second.find(partitionId);
        if (partIt != mapIt->second.end())
            legacySet = &partIt->second;
    }

    for (auto const& guid : guids)
    {
        if (spatialGrid)
            spatialGrid->Remove(guid);
        if (legacySet)
            legacySet->erase(guid);
    }
}

void PartitionManager::BatchSetPartitionOverrides(
    std::vector<ObjectGuid> const& guids, uint32 mapId, uint32 partitionId, uint32 durationMs)
{
    if (guids.empty())
        return;

    uint64 nowMs = GameTime::GetGameTimeMS().count();
    uint64 expiresMs = nowMs + durationMs;
    uint64 skipThreshold = nowMs + durationMs / 2;

    // First pass: shared read to filter out entries that already have the same
    // partition with sufficient remaining time (avoids exclusive lock entirely
    // in the steady state where all boundary entities already have overrides).
    std::vector<ObjectGuid::LowType> needsUpdate;
    {
        std::shared_lock<std::shared_mutex> readGuard(_overrideLock);
        for (auto const& guid : guids)
        {
            auto it = _partitionOverrides.find(guid.GetCounter());
            if (it == _partitionOverrides.end() ||
                it->second.mapId != mapId ||
                it->second.partitionId != partitionId ||
                it->second.expiresMs <= skipThreshold)
            {
                needsUpdate.push_back(guid.GetCounter());
            }
        }
    }

    if (needsUpdate.empty())
        return;

    // Second pass: exclusive write only for entries that truly need updating
    PartitionOverride entry;
    entry.mapId = mapId;
    entry.partitionId = partitionId;
    entry.expiresMs = expiresMs;

    std::unique_lock<std::shared_mutex> guard(_overrideLock);
    for (auto low : needsUpdate)
        _partitionOverrides[low] = entry;
}

void PartitionManager::PeriodicCacheSweep()
{
    uint64 nowMs = GameTime::GetGameTimeMS().count();

    // 1. Sweep _boundaryApproachLastCheck (entries added per player, never removed)
    {
        std::lock_guard<std::mutex> guard(_precacheLock);
        for (auto it = _boundaryApproachLastCheck.begin(); it != _boundaryApproachLastCheck.end();)
        {
            // Remove entries older than threshold (player likely logged off or moved away)
            if (nowMs - it->second > PartitionConst::BOUNDARY_APPROACH_CACHE_TTL_MS)
                it = _boundaryApproachLastCheck.erase(it);
            else
                ++it;
        }

        // Also sweep _precacheRecent unconditionally (not just at >512)
        for (auto it = _precacheRecent.begin(); it != _precacheRecent.end();)
        {
            if (nowMs - it->second > PartitionConst::PRECACHE_RECENT_TTL_MS)
                it = _precacheRecent.erase(it);
            else
                ++it;
        }
    }

    // 2. Sweep _visibilitySets — remove empty inner containers
    {
        auto locks = LockAllVisibilityStripes();
        for (auto mapIt = _visibilitySets.begin(); mapIt != _visibilitySets.end();)
        {
            for (auto partIt = mapIt->second.begin(); partIt != mapIt->second.end();)
            {
                if (partIt->second.empty())
                    partIt = mapIt->second.erase(partIt);
                else
                    ++partIt;
            }
            if (mapIt->second.empty())
                mapIt = _visibilitySets.erase(mapIt);
            else
                ++mapIt;
        }
    }

    // 3. Sweep _zoneExcludedCache if it grows beyond reasonable size
    {
        std::lock_guard<std::mutex> guard(_excludedCacheLock);
        if (_zoneExcludedCache.size() > PartitionConst::ZONE_EXCLUDED_CACHE_LIMIT)
            _zoneExcludedCache.clear();
    }
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
    bool hasEpoch = false;
    {
        std::shared_lock<std::shared_mutex> guard(_partitionLock);
        if (auto it = _layoutEpochByMap.find(mapId); it != _layoutEpochByMap.end())
        {
            epoch = it->second;
            hasEpoch = true;
        }
    }

    if (!hasEpoch)
    {
        cache.valid = false;
        return nullptr;
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
        if (nowMs < lastResize + PartitionConst::RESIZE_COOLDOWN_MS)
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
        std::unique_lock<std::shared_mutex> guard(GetBoundaryLock(mapId));
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

        // Also clean up spatial hash grids for removed partitions
        auto spatialMapIt = _boundarySpatialGrids.find(mapId);
        if (spatialMapIt != _boundarySpatialGrids.end())
        {
            for (auto it = spatialMapIt->second.begin(); it != spatialMapIt->second.end();)
            {
                if (it->first > newCount)
                    it = spatialMapIt->second.erase(it);
                else
                {
                    it->second.Clear();
                    ++it;
                }
            }
        }
    }

    // Note: Layer pair cache is now managed by LayerManager.
    // Partition resize doesn't affect layer assignments directly.

    {
        std::unique_lock<std::shared_mutex> guard(GetVisibilityLock(mapId));
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
        if (nowMs - lastCheck < PartitionConst::BOUNDARY_APPROACH_CHECK_INTERVAL_MS)
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

        uint64 key = (static_cast<uint64>(mapId) << 32) | predictedPartition;

        std::lock_guard<std::mutex> guard(_precacheLock);
        if (auto it = _precacheRecent.find(key); it != _precacheRecent.end())
        {
            if (nowMs - it->second < 5000)
                return; // throttle per map+partition
        }

        if (_precacheQueue.size() >= PartitionConst::PRECACHE_QUEUE_LIMIT)
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

    uint32 processed = 0;
    uint64 nowMs = GameTime::GetGameTimeMS().count();

    std::vector<PrecacheRequest> toProcess;
    {
        std::lock_guard<std::mutex> guard(_precacheLock);
        size_t queueSize = _precacheQueue.size();
        for (size_t i = 0; i < queueSize && processed < PartitionConst::MAX_PRECACHE_REQUESTS_PER_TICK; ++i)
        {
            PrecacheRequest req = _precacheQueue.front();
            _precacheQueue.pop_front();

            if (req.mapId != mapId)
            {
                _precacheQueue.push_back(req);
                continue;
            }

            if (nowMs - req.queuedMs > PartitionConst::PRECACHE_REQUEST_MAX_AGE_MS)
                continue;

            toProcess.push_back(req);
            ++processed;
        }

        // Prune stale entries from _precacheRecent to prevent unbounded growth
        if (_precacheRecent.size() > PartitionConst::PRECACHE_QUEUE_LIMIT * 2)
        {
            for (auto it = _precacheRecent.begin(); it != _precacheRecent.end();)
            {
                if (nowMs - it->second > PartitionConst::PRECACHE_RECENT_TTL_MS)
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

