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
    auto const& playerList = _map.GetPlayers();
    
    for (auto itr = playerList.begin(); itr != playerList.end(); ++itr)
    {
        Player* player = itr->GetSource();
        if (!player || !player->IsInWorld())
            continue;

        uint32 playerPartition = sPartitionMgr->GetPartitionIdForPosition(
            _map.GetId(), player->GetPositionX(), player->GetPositionY(), player->GetGUID());
        
        if (playerPartition == _partitionId)
        {
            players.push_back(player);
        }
    }

    _playerCount = static_cast<uint32>(players.size());

    // Update each player in this partition
    for (Player* player : players)
    {
        if (sPartitionMgr->IsNearPartitionBoundary(_map.GetId(), player->GetPositionX(), player->GetPositionY()))
        {
            ++_boundaryPlayerCount;
            sPartitionMgr->RegisterBoundaryObject(_map.GetId(), _partitionId, player->GetGUID());
            sPartitionMgr->SetPartitionOverride(player->GetGUID(), _partitionId, 500);
        }

        player->Update(_sDiff);
        _map.MarkNearbyCellsOf(player);

        // If player is using far sight, update viewpoint
        if (WorldObject* viewPoint = player->GetViewpoint())
        {
            if (Creature* viewCreature = viewPoint->ToCreature())
                _map.MarkNearbyCellsOf(viewCreature);
            else if (DynamicObject* viewObject = viewPoint->ToDynObject())
                _map.MarkNearbyCellsOf(viewObject);
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

        if (obj->ToCreature())
            ++_creatureCount;

        if (sPartitionMgr->IsNearPartitionBoundary(_map.GetId(), obj->GetPositionX(), obj->GetPositionY()))
        {
            ++_boundaryObjectCount;
            sPartitionMgr->RegisterBoundaryObject(_map.GetId(), _partitionId, obj->GetGUID());
            sPartitionMgr->SetPartitionOverride(obj->GetGUID(), _partitionId, 500);
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
