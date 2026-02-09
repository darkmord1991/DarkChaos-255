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

#include "PartitionUpdateWorker.h"
#include "DynamicObject.h"
#include "Map.h"
#include "PartitionManager.h"
#include "Player.h"
#include "WorldSession.h"
#include "Metric.h"

PartitionUpdateWorker::PartitionUpdateWorker(Map& map, uint32 partitionId, uint32 diff, uint32 s_diff)
    : _map(map), _partitionId(partitionId), _diff(diff), _sDiff(s_diff)
{
}

void PartitionUpdateWorker::Execute()
{
    METRIC_TIMER("partition_update_time", 
        METRIC_TAG("map_id", std::to_string(_map.GetId())),
        METRIC_TAG("partition_id", std::to_string(_partitionId)));

    _map.SetActivePartitionContext(_partitionId);

    ProcessRelays();
    UpdatePlayers();
    UpdateNonPlayerObjects();

    // Flush batched boundary operations (1 lock per batch instead of per-entity)
    FlushBoundaryBatches();
    RecordStats();

    _map.SetActivePartitionContext(0);
}

void PartitionUpdateWorker::ProcessRelays()
{
    _map.ProcessPartitionRelays(_partitionId);
}

void PartitionUpdateWorker::UpdatePlayers()
{
    // Collect players in this partition
    std::vector<Player*> players;
    std::vector<Player*> const* bucket = _map.GetPartitionPlayerBucket(_partitionId);
    if (!bucket)
    {
        auto const& playerList = _map.GetPlayers();

        for (auto itr = playerList.begin(); itr != playerList.end(); ++itr)
        {
            Player* player = itr->GetSource();
            if (!player || !player->IsInWorld())
                continue;

            uint32 zoneId = _map.GetZoneId(player->GetPhaseMask(), player->GetPositionX(), player->GetPositionY(), player->GetPositionZ());
            uint32 playerPartition = sPartitionMgr->GetPartitionIdForPosition(
                _map.GetId(), player->GetPositionX(), player->GetPositionY(), zoneId, player->GetGUID());

            if (playerPartition == _partitionId)
                players.push_back(player);
        }

        bucket = &players;
    }

    _playerCount = static_cast<uint32>(bucket->size());

    // Update each player in this partition
    uint32 playerUpdateDiff = _sDiff ? _sDiff : _diff;
    bool markNearbyCells = _map.ShouldMarkNearbyCells();
    for (Player* player : *bucket)
    {
        if (sPartitionMgr->IsNearPartitionBoundary(_map.GetId(), player->GetPositionX(), player->GetPositionY()))
        {
            ++_boundaryPlayerCount;
            _batchPosUpdates.push_back({player->GetGUID(), player->GetPositionX(), player->GetPositionY()});
            if (!player->IsBoundaryTracked())
                player->SetBoundaryTracked(true);
        }
        else
        {
            if (player->IsBoundaryTracked())
            {
                // Player left boundary zone - unregister to prevent memory leak
                _batchUnregisters.push_back(player->GetGUID());
                player->SetBoundaryTracked(false);
            }
        }

        player->Update(playerUpdateDiff);
        if (markNearbyCells)
            _map.MarkNearbyCellsOf(player);

        // If player is using far sight, update viewpoint
        if (WorldObject* viewPoint = player->GetViewpoint())
        {
            if (Creature* viewCreature = viewPoint->ToCreature())
            {
                if (viewCreature->IsInWorld())
                {
                    if (markNearbyCells)
                        _map.MarkNearbyCellsOf(viewCreature);
                }
            }
            else if (DynamicObject* viewObject = viewPoint->ToDynObject())
            {
                if (viewObject->IsInWorld())
                {
                    if (markNearbyCells)
                        _map.MarkNearbyCellsOf(viewObject);
                }
            }
        }

        // Feature 5: Adjacent Partition Pre-caching
        // Check if player is moving toward a boundary
        if (player->isMoving())
        {
            float dx = 0.0f, dy = 0.0f;
            // Get approximate velocity vector (not exact, but good enough for prediction)
            // We can imply direction from orientation
            float orientation = player->GetOrientation();
            dx = std::cos(orientation) * player->GetSpeed(MOVE_RUN);
            dy = std::sin(orientation) * player->GetSpeed(MOVE_RUN);
            
            sPartitionMgr->CheckBoundaryApproach(player->GetGUID(), _map.GetId(), 
                player->GetPositionX(), player->GetPositionY(), dx, dy);
        }
    }

    sPartitionMgr->UpdatePartitionPlayerCount(_map.GetId(), _partitionId, _playerCount);
}

void PartitionUpdateWorker::UpdateNonPlayerObjects()
{
    auto listLock = _map.AcquirePartitionedUpdateListReadLock();
    auto& partitionedLists = _map.GetPartitionedUpdatableObjectLists();
    auto listIt = partitionedLists.find(_partitionId);
    if (listIt == partitionedLists.end())
        return;

    auto& objectList = listIt->second;
    
    for (WorldObject* obj : objectList)
    {
        if (!obj)
            continue;

        if (!obj->IsInWorld())
        {
            _batchUnregisters.push_back(obj->GetGUID());
            continue;
        }

        if (obj->ToCreature())
            ++_creatureCount;

        if (sPartitionMgr->IsNearPartitionBoundary(_map.GetId(), obj->GetPositionX(), obj->GetPositionY()))
        {
            ++_boundaryObjectCount;
            _batchPosUpdates.push_back({obj->GetGUID(), obj->GetPositionX(), obj->GetPositionY()});
            if (!obj->IsBoundaryTracked())
                obj->SetBoundaryTracked(true);
        }
        else
        {
            if (obj->IsBoundaryTracked())
            {
                // Object left boundary zone - unregister to prevent memory leak
                _batchUnregisters.push_back(obj->GetGUID());
                obj->SetBoundaryTracked(false);
            }
        }

        obj->Update(_diff);
    }

    sPartitionMgr->UpdatePartitionCreatureCount(_map.GetId(), _partitionId, _creatureCount);
    sPartitionMgr->UpdatePartitionBoundaryCount(_map.GetId(), _partitionId, _boundaryPlayerCount + _boundaryObjectCount);
}

void PartitionUpdateWorker::FlushBoundaryBatches()
{
    uint32 mapId = _map.GetId();

    // Batch position updates → single _boundaryLock acquisition
    if (!_batchPosUpdates.empty())
    {
        std::vector<PartitionManager::BoundaryPositionUpdate> updates;
        updates.reserve(_batchPosUpdates.size());
        std::vector<ObjectGuid> overrideGuids;
        overrideGuids.reserve(_batchPosUpdates.size());

        for (auto const& entry : _batchPosUpdates)
        {
            updates.push_back({entry.guid, entry.x, entry.y});
            overrideGuids.push_back(entry.guid);
        }

        sPartitionMgr->BatchUpdateBoundaryPositions(mapId, _partitionId, updates);
        sPartitionMgr->BatchSetPartitionOverrides(overrideGuids, mapId, _partitionId, 500);
    }

    // Batch unregistrations → single _boundaryLock acquisition
    if (!_batchUnregisters.empty())
        sPartitionMgr->BatchUnregisterBoundaryObjects(mapId, _partitionId, _batchUnregisters);
}

void PartitionUpdateWorker::RecordStats()
{
    PartitionManager::PartitionStats stats;
    if (sPartitionMgr->GetPartitionStats(_map.GetId(), _partitionId, stats))
    {
        METRIC_VALUE("partition_players", uint64(stats.players),
            METRIC_TAG("map_id", std::to_string(_map.GetId())),
            METRIC_TAG("partition_id", std::to_string(_partitionId)));
        METRIC_VALUE("partition_creatures", uint64(stats.creatures),
            METRIC_TAG("map_id", std::to_string(_map.GetId())),
            METRIC_TAG("partition_id", std::to_string(_partitionId)));
        METRIC_VALUE("partition_boundary_objects", uint64(stats.boundaryObjects),
            METRIC_TAG("map_id", std::to_string(_map.GetId())),
            METRIC_TAG("partition_id", std::to_string(_partitionId)));
        METRIC_VALUE("partition_visibility_count", uint64(sPartitionMgr->GetVisibilityCount(_map.GetId(), _partitionId)),
            METRIC_TAG("map_id", std::to_string(_map.GetId())),
            METRIC_TAG("partition_id", std::to_string(_partitionId)));
    }
}
