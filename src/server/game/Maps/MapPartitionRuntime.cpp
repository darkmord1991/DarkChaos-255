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

#include "Map.h"

#include "GameTime.h"
#include "Log.h"
#include "MapMgr.h"
#include "PartitionManager.h"
#include "World.h"

namespace
{
    constexpr uint64 kSlowPartitionUpdateCycleMs = 40;
}

bool Map::SchedulePartitionUpdates(uint32 t_diff, uint32 s_diff)
{
    if (!_isPartitioned || !_useParallelPartitions)
        return true;

    MapUpdater* updater = sMapMgr->GetMapUpdater();
    if (!updater || !updater->activated())
    {
        LOG_WARN("map.partition", "Map {}: SchedulePartitionUpdates called but MapUpdater is not active", GetId());
        return true;
    }

    uint32 partitionCount = sPartitionMgr->GetPartitionCount(GetId());
    if (partitionCount == 0)
        partitionCount = 1;

    if (!_partitionUpdatesInProgress)
    {
        FlushPendingUpdateListAdds();

        // Drain any stale deferred partition modifications before launching workers.
        ApplyQueuedPartitionedOwnershipUpdates();
        ApplyQueuedPartitionedRemovals();

        BuildPartitionPlayerBuckets();

        LOG_DEBUG("map.partition", "Map {}: Scheduling {} partition updates in pipelined parallel mode", GetId(), partitionCount);

        _partitionUpdatesInProgress = true;
        _partitionUpdatesStartMs = GameTime::GetGameTimeMS().count();
        _partitionUpdatesTotal = partitionCount;
        _partitionUpdatesScheduled = 0;
        uint32 const configuredThreads = std::max<uint32>(1, sWorld->getIntConfig(CONFIG_NUMTHREADS));
        uint32 const contentionCap = 2;
        _partitionUpdatesMaxInFlight = std::min<uint32>(
            partitionCount,
            std::min<uint32>(contentionCap, std::min<uint32>(_adaptivePartitionInFlightLimit, configuredThreads)));
        _partitionUpdatesCompleted.store(0, std::memory_order_release);
        _partitionUpdateGeneration.fetch_add(1, std::memory_order_acq_rel);
    }

    uint32 completed = _partitionUpdatesCompleted.load(std::memory_order_acquire);
    uint32 inFlight = _partitionUpdatesScheduled > completed ? (_partitionUpdatesScheduled - completed) : 0;
    uint32 freeSlots = _partitionUpdatesMaxInFlight > inFlight ? (_partitionUpdatesMaxInFlight - inFlight) : 0;
    uint32 const generation = _partitionUpdateGeneration.load(std::memory_order_acquire);

    while (freeSlots > 0 && _partitionUpdatesScheduled < _partitionUpdatesTotal)
    {
        uint32 partitionId = ++_partitionUpdatesScheduled;
        updater->schedule_partition_update(*this, partitionId, t_diff, s_diff, [this, generation]()
        {
            if (_partitionUpdateGeneration.load(std::memory_order_acquire) == generation)
                _partitionUpdatesCompleted.fetch_add(1, std::memory_order_acq_rel);
        });

        --freeSlots;
    }

    completed = _partitionUpdatesCompleted.load(std::memory_order_acquire);
    if (completed >= _partitionUpdatesTotal)
    {
        uint64 const nowMs = GameTime::GetGameTimeMS().count();
        uint64 const cycleMs = (_partitionUpdatesStartMs > 0 && nowMs >= _partitionUpdatesStartMs) ? (nowMs - _partitionUpdatesStartMs) : 0;
        if (cycleMs >= kSlowPartitionUpdateCycleMs)
        {
            LOG_WARN("map.partition.slow",
                "Slow partition update cycle: map={} partitions={} completed={} scheduled={} in_flight_limit={} cycle_ms={}",
                GetId(), _partitionUpdatesTotal, completed, _partitionUpdatesScheduled, _partitionUpdatesMaxInFlight, cycleMs);
        }

        ClearPartitionPlayerBuckets();
        _partitionUpdatesInProgress = false;
        _partitionUpdatesTotal = 0;
        _partitionUpdatesScheduled = 0;
        _partitionUpdatesMaxInFlight = 1;
        _partitionUpdatesStartMs = 0;
        return true;
    }

    return false;
}

void Map::BuildPartitionPlayerBuckets()
{
    uint32 partitionCount = sPartitionMgr->GetPartitionCount(GetId());
    if (partitionCount == 0)
        partitionCount = 1;

    std::vector<std::vector<Player*>> newBuckets(partitionCount);

    for (MapRefMgr::iterator iter = m_mapRefMgr.begin(); iter != m_mapRefMgr.end(); ++iter)
    {
        Player* player = iter->GetSource();
        if (!player || !player->IsInWorld())
            continue;

        uint32 zoneId = player->GetZoneId();
        uint32 partitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), player->GetPositionX(), player->GetPositionY(), zoneId, player->GetGUID());
        uint32 index = partitionId > 0 ? partitionId - 1 : 0;
        if (index >= newBuckets.size())
            index = newBuckets.size() - 1;
        newBuckets[index].push_back(player);
    }

    std::unique_lock<std::shared_mutex> guard(_partitionPlayerBucketsLock);
    _partitionPlayerBuckets.swap(newBuckets);
    _partitionPlayerBucketsReady = true;
}

void Map::SetPartitionPlayerBuckets(std::vector<std::vector<Player*>> const& buckets)
{
    std::unique_lock<std::shared_mutex> guard(_partitionPlayerBucketsLock);
    if (_partitionPlayerBuckets.size() != buckets.size())
        _partitionPlayerBuckets.resize(buckets.size());

    for (size_t i = 0; i < buckets.size(); ++i)
        _partitionPlayerBuckets[i] = buckets[i];

    _partitionPlayerBucketsReady = true;
}

void Map::QueueDeferredVisibilityUpdate(ObjectGuid const& guid)
{
    if (!guid || guid.IsPlayer())
        return;

    std::lock_guard<std::mutex> guard(_deferredVisibilityLock);
    if (_deferredVisibilitySet.insert(guid).second)
        _deferredVisibilityUpdates.push_back(guid);
}

void Map::ProcessDeferredVisibilityUpdates()
{
    std::vector<ObjectGuid> pending;
    {
        std::lock_guard<std::mutex> guard(_deferredVisibilityLock);
        if (_deferredVisibilityUpdates.empty())
            return;

        size_t const takeCount = std::min(_adaptiveDeferredVisibilityBudget, _deferredVisibilityUpdates.size());
        pending.reserve(takeCount);
        for (size_t i = 0; i < takeCount; ++i)
        {
            ObjectGuid const guid = _deferredVisibilityUpdates.front();
            _deferredVisibilityUpdates.pop_front();
            pending.push_back(guid);
            _deferredVisibilitySet.erase(guid);
        }
    }

    for (ObjectGuid const& guid : pending)
    {
        WorldObject* obj = nullptr;
        switch (guid.GetHigh())
        {
            case HighGuid::Unit:
                obj = GetCreature(guid);
                break;
            case HighGuid::GameObject:
                obj = GetGameObject(guid);
                break;
            case HighGuid::DynamicObject:
                obj = GetDynamicObject(guid);
                break;
            case HighGuid::Corpse:
                obj = GetCorpse(guid);
                break;
            default:
                break;
        }

        if (!obj || !obj->IsInWorld())
            continue;

        obj->UpdateObjectVisibility(true, true);
    }
}

void Map::ClearPartitionPlayerBuckets()
{
    std::unique_lock<std::shared_mutex> guard(_partitionPlayerBucketsLock);
    for (auto& bucket : _partitionPlayerBuckets)
        bucket.clear();
    _partitionPlayerBucketsReady = false;
}

std::vector<Player*> const* Map::GetPartitionPlayerBucket(uint32 partitionId) const
{
    if (partitionId == 0)
        return nullptr;

    std::shared_lock<std::shared_mutex> guard(_partitionPlayerBucketsLock);
    if (!_partitionPlayerBucketsReady || _partitionPlayerBuckets.empty())
        return nullptr;

    uint32 index = partitionId - 1;
    if (index >= _partitionPlayerBuckets.size())
        return nullptr;
    return &_partitionPlayerBuckets[index];
}

bool Map::ShouldMarkNearbyCells() const
{
    return _markNearbyCellsThisTick.load(std::memory_order_relaxed);
}

uint32 Map::GetUpdateCounter() const
{
    return _updateCounter.load(std::memory_order_relaxed);
}
