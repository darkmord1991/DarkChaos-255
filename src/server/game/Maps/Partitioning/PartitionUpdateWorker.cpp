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
#include <unordered_set>

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
    if (!_boundaryValidGuids.empty())
    {
        std::unordered_set<ObjectGuid> validSet;
        validSet.reserve(_boundaryValidGuids.size());
        for (auto const& guid : _boundaryValidGuids)
            validSet.insert(guid);
        sPartitionMgr->CleanupBoundaryObjects(_map.GetId(), _partitionId, validSet);
    }
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
    uint32 playerUpdateDiff = _diff ? _diff : _sDiff;
    for (Player* player : *bucket)
    {
        _boundaryValidGuids.push_back(player->GetGUID());
        if (sPartitionMgr->IsNearPartitionBoundary(_map.GetId(), player->GetPositionX(), player->GetPositionY()))
        {
            ++_boundaryPlayerCount;
            // Only register if not already in boundary set (avoids duplicate registration spam)
            if (!sPartitionMgr->IsObjectInBoundarySet(_map.GetId(), _partitionId, player->GetGUID()))
                sPartitionMgr->RegisterBoundaryObject(_map.GetId(), _partitionId, player->GetGUID());
            sPartitionMgr->SetPartitionOverride(player->GetGUID(), _partitionId, 500);
        }
        else
        {
            // Player left boundary zone - unregister to prevent memory leak
            sPartitionMgr->UnregisterBoundaryObject(_map.GetId(), _partitionId, player->GetGUID());
        }

        player->Update(playerUpdateDiff);
        _map.MarkNearbyCellsOf(player);

        // If player is using far sight, update viewpoint
        if (WorldObject* viewPoint = player->GetViewpoint())
        {
            if (Creature* viewCreature = viewPoint->ToCreature())
                _map.MarkNearbyCellsOf(viewCreature);
            else if (DynamicObject* viewObject = viewPoint->ToDynObject())
                _map.MarkNearbyCellsOf(viewObject);
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
    sPartitionMgr->UpdatePartitionBoundaryCount(_map.GetId(), _partitionId, _boundaryPlayerCount);
}

void PartitionUpdateWorker::UpdateNonPlayerObjects()
{
    auto& partitionedLists = _map.GetPartitionedUpdatableObjectLists();
    auto listIt = partitionedLists.find(_partitionId);
    if (listIt == partitionedLists.end())
        return;

    auto& objectList = listIt->second;
    
    for (WorldObject* obj : objectList)
    {
        if (!obj || !obj->IsInWorld())
            continue;

        _boundaryValidGuids.push_back(obj->GetGUID());

        if (obj->ToCreature())
            ++_creatureCount;

        if (sPartitionMgr->IsNearPartitionBoundary(_map.GetId(), obj->GetPositionX(), obj->GetPositionY()))
        {
            ++_boundaryObjectCount;
            // Only register if not already in boundary set (avoids duplicate registration spam)
            if (!sPartitionMgr->IsObjectInBoundarySet(_map.GetId(), _partitionId, obj->GetGUID()))
                sPartitionMgr->RegisterBoundaryObject(_map.GetId(), _partitionId, obj->GetGUID());
            sPartitionMgr->SetPartitionOverride(obj->GetGUID(), _partitionId, 500);
        }
        else
        {
            // Object left boundary zone - unregister to prevent memory leak
            sPartitionMgr->UnregisterBoundaryObject(_map.GetId(), _partitionId, obj->GetGUID());
        }

        obj->Update(_diff);
    }

    sPartitionMgr->UpdatePartitionCreatureCount(_map.GetId(), _partitionId, _creatureCount);
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
