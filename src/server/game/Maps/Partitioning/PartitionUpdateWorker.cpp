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
#include "Config.h"
#include "DynamicObject.h"
#include "Corpse.h"
#include "Log.h"
#include "Map.h"
#include "Object.h"
#include "PartitionManager.h"
#include "Player.h"
#include "Metric.h"
#include <chrono>
#include <cmath>
#include <unordered_set>

namespace
{
template <typename T>
auto TryBeginUpdateExecutionIfSupported(T* object, int) -> decltype(object->TryBeginUpdateExecution(), bool())
{
    return object->TryBeginUpdateExecution();
}

template <typename T>
bool TryBeginUpdateExecutionIfSupported(T*, long)
{
    return true;
}

template <typename T>
auto EndUpdateExecutionIfSupported(T* object, int) -> decltype(object->EndUpdateExecution(), void())
{
    object->EndUpdateExecution();
}

template <typename T>
void EndUpdateExecutionIfSupported(T*, long)
{
}
}

PartitionUpdateWorker::PartitionUpdateWorker(Map& map, uint32 partitionId, uint32 diff, uint32 s_diff)
    : _map(map), _partitionId(partitionId), _diff(diff), _sDiff(s_diff)
{
}

void PartitionUpdateWorker::Execute()
{
    METRIC_TIMER("partition_update_time", 
        METRIC_TAG("map_id", std::to_string(_map.GetId())),
        METRIC_TAG("partition_id", std::to_string(_partitionId)));

    auto const pwStart = std::chrono::steady_clock::now();
    auto pwLast = pwStart;
    int64 pwRelays = 0, pwPlayers = 0, pwNpcs = 0, pwBoundary = 0, pwStats = 0;
    auto pwSnap = [&](int64& target) {
        auto now = std::chrono::steady_clock::now();
        target = std::chrono::duration_cast<std::chrono::milliseconds>(now - pwLast).count();
        pwLast = now;
    };

    _map.SetActivePartitionContext(_partitionId);

    if (_map.HasPendingPartitionRelayWork(_partitionId))
        ProcessRelays();
    pwSnap(pwRelays);

    UpdatePlayers();
    pwSnap(pwPlayers);

    UpdateNonPlayerObjects();
    pwSnap(pwNpcs);

    // NOTE: ApplyQueuedPartitionedOwnershipUpdates is intentionally NOT called
    // here. Multiple workers would race on _partitionedUpdatableObjectLists and
    // _partitionedUpdatableIndex. The main thread applies deferred ownership
    // updates after all workers complete (see Map::Update parallel path).

    // Flush batched boundary operations (1 lock per batch instead of per-entity)
    FlushBoundaryBatches();
    pwSnap(pwBoundary);

    RecordStats();
    pwSnap(pwStats);

    _map.SetActivePartitionContext(0);

    // Emit sub-phase breakdown for slow partition workers
    int64 totalMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - pwStart).count();
    static uint32 sPwThresholdMs = sConfigMgr->GetOption<uint32>("System.SlowPartitionWorker.PhaseBreakdownMs", 80);
    if (totalMs >= sPwThresholdMs)
    {
        LOG_WARN("map.partition.slow",
            "Partition worker phase breakdown: map={} partition={} total={}ms "
            "relays={}ms players={}ms(n={}) npcs={}ms(n={}) boundary={}ms stats={}ms diff={}",
            _map.GetId(), _partitionId, totalMs,
            pwRelays, pwPlayers, _playerCount, pwNpcs, _creatureCount,
            pwBoundary, pwStats, _diff);
    }
}

void PartitionUpdateWorker::ProcessRelays()
{
    _map.ProcessPartitionRelays(_partitionId);
}

void PartitionUpdateWorker::UpdatePlayers()
{
    // Collect players in this partition
    _scratchPlayers.clear();
    std::vector<Player*> const* bucket = _map.GetPartitionPlayerBucket(_partitionId);
    if (!bucket)
    {
        auto const& playerList = _map.GetPlayers();

        for (auto itr = playerList.begin(); itr != playerList.end(); ++itr)
        {
            Player* player = itr->GetSource();
            if (!player || !player->IsInWorld())
                continue;

            uint32 zoneId = player->GetZoneId();
            uint32 playerPartition = sPartitionMgr->GetPartitionIdForPosition(
                _map.GetId(), player->GetPositionX(), player->GetPositionY(), zoneId, player->GetGUID());

            if (playerPartition == _partitionId)
                _scratchPlayers.push_back(player);
        }

        bucket = &_scratchPlayers;
    }

    _playerCount = static_cast<uint32>(bucket->size());

    // Update each player in this partition
    uint32 playerUpdateDiff = _sDiff ? _sDiff : _diff;
    bool markNearbyCells = _map.ShouldMarkNearbyCells();
    constexpr uint32 kBoundaryApproachEveryNTicks = 4;
    bool const checkBoundaryApproach = (_map.GetUpdateCounter() % kBoundaryApproachEveryNTicks) == 0;
    _scratchBoundaryByGrid.clear();
    for (Player* player : *bucket)
    {
        if (!player || !player->IsInWorld())
            continue;

        GridCoord gridCoord = Acore::ComputeGridCoord(player->GetPositionX(), player->GetPositionY());
        uint32 const gridKey = (gridCoord.x_coord << 16) | gridCoord.y_coord;
        bool nearBoundary = false;
        auto cacheItr = _scratchBoundaryByGrid.find(gridKey);
        if (cacheItr != _scratchBoundaryByGrid.end())
            nearBoundary = cacheItr->second;
        else
        {
            nearBoundary = sPartitionMgr->IsNearPartitionBoundary(_map.GetId(), player->GetPositionX(), player->GetPositionY());
            _scratchBoundaryByGrid.emplace(gridKey, nearBoundary);
        }

        if (nearBoundary)
        {
            ++_boundaryPlayerCount;

            ObjectGuid playerGuid = player->GetGUID();
            _batchBoundaryOverrides.push_back(playerGuid);

            bool needsPositionUpdate = !player->IsBoundaryTracked() || player->isMoving();
            if (needsPositionUpdate)
                _batchPosUpdates.push_back({playerGuid, player->GetPositionX(), player->GetPositionY()});

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
        if (checkBoundaryApproach && player->isMoving())
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
    struct UpdateExecutionGuard
    {
        explicit UpdateExecutionGuard(UpdatableMapObject* object) : _object(object) { }

        ~UpdateExecutionGuard()
        {
            if (_object)
                EndUpdateExecutionIfSupported(_object, 0);
        }

    private:
        UpdatableMapObject* _object;
    };

    // Collect GUIDs to avoid dangling pointer use when objects despawn mid-tick.
    _scratchObjects.clear();
    Map::VisibilityDeferGuard deferVisibility(_map);
    _map.CollectPartitionedUpdatableGuids(_partitionId, _scratchObjects);

    uint32 windowStart = 0;
    uint32 windowCount = static_cast<uint32>(_scratchObjects.size());
    _map.GetPartitionObjectUpdateWindow(_partitionId, static_cast<uint32>(_scratchObjects.size()), windowStart, windowCount);

    bool const partialSweep = windowCount < _scratchObjects.size();
    if (partialSweep)
    {
        for (auto const& entry : _scratchObjects)
        {
            if (entry.second == TYPEID_UNIT)
                ++_creatureCount;
        }
    }

    _scratchResolvedObjects.clear();
    _scratchResolvedObjects.reserve(windowCount);
    _scratchBoundaryByGrid.clear();

    auto resolveObject = [this](ObjectGuid const& guid, uint8 typeId) -> WorldObject*
    {
        switch (typeId)
        {
            case TYPEID_UNIT:
                return _map.GetCreature(guid);
            case TYPEID_GAMEOBJECT:
                return _map.GetGameObject(guid);
            case TYPEID_DYNAMICOBJECT:
                return _map.GetDynamicObject(guid);
            case TYPEID_CORPSE:
                return _map.GetCorpse(guid);
            default:
                return nullptr;
        }
    };

    for (uint32 offset = 0; offset < windowCount; ++offset)
    {
        auto const& entry = _scratchObjects[(windowStart + offset) % _scratchObjects.size()];
        ResolvedObject resolved;
        resolved.guid = entry.first;
        resolved.typeId = entry.second;
        resolved.isCreature = entry.second == TYPEID_UNIT;

        WorldObject* const object = resolveObject(resolved.guid, resolved.typeId);
        if (!object || !object->IsInWorld())
            continue;

        _scratchResolvedObjects.push_back(resolved);
    }

    for (ResolvedObject const& resolved : _scratchResolvedObjects)
    {
        WorldObject* obj = resolveObject(resolved.guid, resolved.typeId);
        if (!obj || !obj->IsInWorld())
            continue;

        bool const isCreature = resolved.isCreature;

        if (!partialSweep && isCreature)
            ++_creatureCount;

        GridCoord gridCoord = Acore::ComputeGridCoord(obj->GetPositionX(), obj->GetPositionY());
        uint32 const gridKey = (gridCoord.x_coord << 16) | gridCoord.y_coord;
        bool nearBoundary = false;
        auto cacheItr = _scratchBoundaryByGrid.find(gridKey);
        if (cacheItr != _scratchBoundaryByGrid.end())
            nearBoundary = cacheItr->second;
        else
        {
            nearBoundary = sPartitionMgr->IsNearPartitionBoundary(_map.GetId(), obj->GetPositionX(), obj->GetPositionY());
            _scratchBoundaryByGrid.emplace(gridKey, nearBoundary);
        }

        if (nearBoundary)
        {
            ++_boundaryObjectCount;

            ObjectGuid objectGuid = resolved.guid;
            _batchBoundaryOverrides.push_back(objectGuid);

            bool needsPositionUpdate = !obj->IsBoundaryTracked();
            if (!needsPositionUpdate && isCreature)
            {
                needsPositionUpdate = static_cast<Creature*>(obj)->isMoving();
            }

            if (needsPositionUpdate)
                _batchPosUpdates.push_back({objectGuid, obj->GetPositionX(), obj->GetPositionY()});

            if (!obj->IsBoundaryTracked())
                obj->SetBoundaryTracked(true);
        }
        else
        {
            if (obj->IsBoundaryTracked())
            {
                // Object left boundary zone - unregister to prevent memory leak
                _batchUnregisters.push_back(resolved.guid);
                obj->SetBoundaryTracked(false);
            }
        }

        if (!obj->IsInWorld())
            continue;

        if (isCreature && static_cast<Creature*>(obj)->IsDuringRemoveFromWorld())
            continue;

        UpdatableMapObject* updatableObject = obj->AsUpdatableMapObject();
        if (updatableObject && !TryBeginUpdateExecutionIfSupported(updatableObject, 0))
            continue;
        UpdateExecutionGuard updateGuard(updatableObject);

        // Tag the unit with our partition ID so that TryGetRelayTargetPartition
        // won't relay MotionMaster calls when the creature crosses a partition
        // boundary during its own UpdateSplineMovement within the same tick.
        if (isCreature)
        {
            static_cast<Unit*>(obj)->SetCurrentUpdatePartition(_partitionId);
            obj->Update(_diff);
            static_cast<Unit*>(obj)->SetCurrentUpdatePartition(0);
        }
        else
        {
            obj->Update(_diff);
        }

        // After updating, check if this object still needs further ticks.
        // If not, queue it for removal so we don't keep waking idle creatures.
        if (!obj->IsUpdateNeeded())
            _map.RemoveObjectFromMapUpdateList(obj);
    }

    sPartitionMgr->UpdatePartitionCreatureCount(_map.GetId(), _partitionId, _creatureCount);
    sPartitionMgr->UpdatePartitionBoundaryCount(_map.GetId(), _partitionId, _boundaryPlayerCount + _boundaryObjectCount);
}

void PartitionUpdateWorker::FlushBoundaryBatches()
{
    uint32 mapId = _map.GetId();
    static uint32 const sBoundaryOverrideDurationMs = static_cast<uint32>(std::max<int64>(100,
        sConfigMgr->GetOption<int64>("MapPartitions.Boundary.OverrideDurationMs", 500)));
    static uint32 const sNearbyMergeEveryNTicks = static_cast<uint32>(std::max<int64>(1,
        sConfigMgr->GetOption<int64>("MapPartitions.Boundary.NearbyMergeEveryNTicks", 1)));
    static uint32 const sNearbyMergeMaxQueries = static_cast<uint32>(std::max<int64>(0,
        sConfigMgr->GetOption<int64>("MapPartitions.Boundary.NearbyMergeMaxQueries", 0)));

    // Batch position updates → single _boundaryLock acquisition
    if (!_batchPosUpdates.empty())
    {
        _scratchBoundaryUpdates.clear();
        _scratchBoundaryUpdates.reserve(_batchPosUpdates.size());

        for (auto const& entry : _batchPosUpdates)
            _scratchBoundaryUpdates.push_back({entry.guid, entry.x, entry.y});

        sPartitionMgr->BatchUpdateBoundaryPositions(mapId, _partitionId, _scratchBoundaryUpdates);

        std::vector<std::vector<ObjectGuid>> nearbyBoundaryResults;
        bool const shouldMergeNearby = (_map.GetUpdateCounter() % sNearbyMergeEveryNTicks) == 0;
        if (shouldMergeNearby)
        {
            float const nearbyRadius = std::max(1.0f, sPartitionMgr->GetBorderOverlap());
            _scratchNearbyBoundaryQueries.clear();

            size_t queryCount = _batchPosUpdates.size();
            if (sNearbyMergeMaxQueries > 0)
                queryCount = std::min<size_t>(queryCount, sNearbyMergeMaxQueries);

            _scratchNearbyBoundaryQueries.reserve(queryCount);
            for (size_t i = 0; i < queryCount; ++i)
            {
                auto const& entry = _batchPosUpdates[i];
                _scratchNearbyBoundaryQueries.push_back({ _partitionId, entry.x, entry.y, nearbyRadius });
            }

            nearbyBoundaryResults = sPartitionMgr->BatchGetNearbyBoundaryObjects(mapId, _scratchNearbyBoundaryQueries);
        }

        _scratchMergedBoundaryOverrides.clear();
        _scratchMergedBoundaryOverrides.reserve(_batchBoundaryOverrides.size());

        std::unordered_set<ObjectGuid::LowType> seenOverrideGuids;
        seenOverrideGuids.reserve(_batchBoundaryOverrides.size() + _batchPosUpdates.size());

        auto appendUniqueOverride = [this, &seenOverrideGuids](ObjectGuid const& guid)
        {
            if (!guid)
                return;

            if (seenOverrideGuids.emplace(guid.GetCounter()).second)
                _scratchMergedBoundaryOverrides.push_back(guid);
        };

        for (ObjectGuid const& guid : _batchBoundaryOverrides)
            appendUniqueOverride(guid);

        for (std::vector<ObjectGuid> const& nearbyGuids : nearbyBoundaryResults)
        {
            for (ObjectGuid const& guid : nearbyGuids)
                appendUniqueOverride(guid);
        }
    }

    if (!_scratchMergedBoundaryOverrides.empty())
        sPartitionMgr->BatchSetPartitionOverrides(_scratchMergedBoundaryOverrides, mapId, _partitionId, sBoundaryOverrideDurationMs);
    else if (!_batchBoundaryOverrides.empty())
        sPartitionMgr->BatchSetPartitionOverrides(_batchBoundaryOverrides, mapId, _partitionId, sBoundaryOverrideDurationMs);

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
