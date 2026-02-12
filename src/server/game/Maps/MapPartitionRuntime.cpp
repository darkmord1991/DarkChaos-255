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

#include "Config.h"
#include "GameTime.h"
#include "Log.h"
#include "MapMgr.h"
#include "MapReference.h"
#include "Metric.h"
#include "Corpse.h"
#include "DynamicObject.h"
#include "PartitionManager.h"
#include "Player.h"
#include "World.h"
#include <limits>

namespace
{
    constexpr uint64 kSlowPartitionUpdateCycleMsDefault = 90;
    constexpr uint64 kSlowPartitionLogIntervalMsDefault = 5000;

    void AtomicMax(std::atomic<uint64>& target, uint64 value)
    {
        uint64 observed = target.load(std::memory_order_acquire);
        while (value > observed && !target.compare_exchange_weak(observed, value, std::memory_order_acq_rel))
        {
        }
    }

    void AtomicMin(std::atomic<uint64>& target, uint64 value)
    {
        uint64 observed = target.load(std::memory_order_acquire);
        while (value < observed && !target.compare_exchange_weak(observed, value, std::memory_order_acq_rel))
        {
        }
    }
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
        uint32 const updaterWorkers = std::max<uint32>(1, static_cast<uint32>(updater->GetWorkerCount()));
        uint32 const workerCapacity = std::max<uint32>(configuredThreads, updaterWorkers);
        MapUpdater::PartitionPoolHealth const poolHealth = updater->GetPartitionPoolHealth();

        uint32 targetInFlight = std::min<uint32>(
            partitionCount,
            std::max<uint32>(
                1,
                std::min<uint32>(workerCapacity, _adaptivePartitionInFlightLimit + (workerCapacity / 2))));

        if (poolHealth.pendingJobs > (workerCapacity * 2))
            targetInFlight = std::max<uint32>(1, targetInFlight / 2);

        _partitionUpdatesMaxInFlight = std::max<uint32>(1, targetInFlight);

        _partitionUpdatesCompleted.store(0, std::memory_order_release);
        _partitionCycleQueueWaitTotalMs.store(0, std::memory_order_release);
        _partitionCycleRunTotalMs.store(0, std::memory_order_release);
        _partitionCycleMaxRunMs.store(0, std::memory_order_release);
        _partitionCycleMaxQueueWaitMs.store(0, std::memory_order_release);
        _partitionCycleFirstTaskStartMs.store(std::numeric_limits<uint64>::max(), std::memory_order_release);
        _partitionCycleLastTaskEndMs.store(0, std::memory_order_release);
        _partitionUpdateGeneration.fetch_add(1, std::memory_order_acq_rel);
    }

    uint32 completed = _partitionUpdatesCompleted.load(std::memory_order_acquire);
    uint32 inFlight = _partitionUpdatesScheduled > completed ? (_partitionUpdatesScheduled - completed) : 0;
    uint32 freeSlots = _partitionUpdatesMaxInFlight > inFlight ? (_partitionUpdatesMaxInFlight - inFlight) : 0;
    uint32 const generation = _partitionUpdateGeneration.load(std::memory_order_acquire);

    while (freeSlots > 0 && _partitionUpdatesScheduled < _partitionUpdatesTotal)
    {
        uint32 partitionId = ++_partitionUpdatesScheduled;
        updater->schedule_partition_update(*this, partitionId, t_diff, s_diff, [this, generation](MapUpdater::PartitionTaskTiming const& timing)
        {
            if (_partitionUpdateGeneration.load(std::memory_order_acquire) == generation)
            {
                _partitionUpdatesCompleted.fetch_add(1, std::memory_order_acq_rel);
                _partitionCycleQueueWaitTotalMs.fetch_add(timing.queueWaitMs, std::memory_order_acq_rel);
                _partitionCycleRunTotalMs.fetch_add(timing.runMs, std::memory_order_acq_rel);
                AtomicMax(_partitionCycleMaxRunMs, timing.runMs);
                AtomicMax(_partitionCycleMaxQueueWaitMs, timing.queueWaitMs);
                AtomicMin(_partitionCycleFirstTaskStartMs, timing.startMs);
                AtomicMax(_partitionCycleLastTaskEndMs, timing.endMs);
            }
        });

        --freeSlots;
    }

    completed = _partitionUpdatesCompleted.load(std::memory_order_acquire);
    if (completed >= _partitionUpdatesTotal)
    {
        uint64 const nowMs = GameTime::GetGameTimeMS().count();
        uint64 const cycleMs = (_partitionUpdatesStartMs > 0 && nowMs >= _partitionUpdatesStartMs) ? (nowMs - _partitionUpdatesStartMs) : 0;
        static bool const slowPartitionLogEnabled = sConfigMgr->GetOption<bool>("System.SlowPartitionCycle.Enable", true);
        static uint64 const slowPartitionThresholdMs = static_cast<uint64>(std::max<int64>(1, sConfigMgr->GetOption<int64>("System.SlowPartitionCycle.ThresholdMs", kSlowPartitionUpdateCycleMsDefault)));
        static uint64 const slowPartitionLogIntervalMs = static_cast<uint64>(std::max<int64>(0, sConfigMgr->GetOption<int64>("System.SlowPartitionCycle.LogIntervalMs", kSlowPartitionLogIntervalMsDefault)));

        if (slowPartitionLogEnabled && cycleMs >= slowPartitionThresholdMs && (slowPartitionLogIntervalMs == 0 || nowMs >= _nextSlowPartitionLogAtMs))
        {
            uint64 const totalQueueWaitMs = _partitionCycleQueueWaitTotalMs.load(std::memory_order_acquire);
            uint64 const totalRunMs = _partitionCycleRunTotalMs.load(std::memory_order_acquire);
            uint64 const maxRunMs = _partitionCycleMaxRunMs.load(std::memory_order_acquire);
            uint64 const maxQueueWaitMs = _partitionCycleMaxQueueWaitMs.load(std::memory_order_acquire);
            uint64 const firstTaskStartMs = _partitionCycleFirstTaskStartMs.load(std::memory_order_acquire);
            uint64 const lastTaskEndMs = _partitionCycleLastTaskEndMs.load(std::memory_order_acquire);
            uint64 const busyWindowMs = (firstTaskStartMs != std::numeric_limits<uint64>::max() && lastTaskEndMs >= firstTaskStartMs)
                ? (lastTaskEndMs - firstTaskStartMs)
                : 0;
            uint64 const barrierBlockedMs = cycleMs > busyWindowMs ? (cycleMs - busyWindowMs) : 0;
            MapUpdater::PartitionPoolHealth const poolHealth = updater->GetPartitionPoolHealth();

            LOG_WARN("map.partition.slow",
                "Slow partition update cycle: map={} partitions={} completed={} scheduled={} in_flight_limit={} cycle_ms={} enqueue_wait_ms={} run_ms={} barrier_blocked_ms={} max_partition_run_ms={} max_queue_wait_ms={} active_workers={} pending_jobs={} oldest_queued_age_ms={} pool_max_partition_run_ms={}",
                GetId(), _partitionUpdatesTotal, completed, _partitionUpdatesScheduled, _partitionUpdatesMaxInFlight, cycleMs,
                totalQueueWaitMs, totalRunMs, barrierBlockedMs, maxRunMs, maxQueueWaitMs,
                poolHealth.activeWorkers, poolHealth.pendingJobs, poolHealth.oldestQueuedAgeMs, poolHealth.maxPartitionRunMs);

            if (slowPartitionLogIntervalMs > 0)
                _nextSlowPartitionLogAtMs = nowMs + slowPartitionLogIntervalMs;
        }

        ClearPartitionPlayerBuckets();
        _partitionUpdatesInProgress = false;
        _partitionUpdatesTotal = 0;
        _partitionUpdatesScheduled = 0;
        _partitionUpdatesMaxInFlight = 1;
        _partitionUpdatesStartMs = 0;
        _partitionCycleQueueWaitTotalMs.store(0, std::memory_order_release);
        _partitionCycleRunTotalMs.store(0, std::memory_order_release);
        _partitionCycleMaxRunMs.store(0, std::memory_order_release);
        _partitionCycleMaxQueueWaitMs.store(0, std::memory_order_release);
        _partitionCycleFirstTaskStartMs.store(0, std::memory_order_release);
        _partitionCycleLastTaskEndMs.store(0, std::memory_order_release);
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
    size_t const playerRefCountHint = static_cast<size_t>(std::max<uint32>(1, m_mapRefMgr.getSize()));
    size_t const perBucketReserve = (playerRefCountHint / partitionCount) + 1;
    for (auto& bucket : newBuckets)
        bucket.reserve(perBucketReserve);

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
    auto const slowLogStart = std::chrono::steady_clock::now();

    METRIC_TIMER("game_system_update_time",
        METRIC_TAG("system", "visibility"),
        METRIC_TAG("phase", "partition_deferred"),
        METRIC_TAG("map_id", std::to_string(GetId())));

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

    char const* workloadBucket = "small";
    if (pending.size() >= 512)
        workloadBucket = "huge";
    else if (pending.size() >= 128)
        workloadBucket = "large";
    else if (pending.size() >= 32)
        workloadBucket = "medium";

    METRIC_DETAILED_TIMER("slow_visibility_update_time",
        METRIC_TAG("phase", "partition_deferred"),
        METRIC_TAG("map_id", std::to_string(GetId())),
        METRIC_TAG("workload", workloadBucket));

    static bool const slowLogEnabled = sConfigMgr->GetOption<bool>("System.SlowLog.Enable", true);
    static int64 const slowVisibilityThresholdMs = sConfigMgr->GetOption<int64>("Metric.Threshold.slow_visibility_update_time", 6);
    if (slowLogEnabled)
    {
        int64 const elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - slowLogStart).count();
        if (elapsedMs >= slowVisibilityThresholdMs)
        {
            LOG_WARN("system.slow",
                "Slow partition deferred visibility: map_id={} workload={} batch={} budget={} elapsed_ms={} threshold_ms={}",
                GetId(), workloadBucket, pending.size(), _adaptiveDeferredVisibilityBudget, elapsedMs, slowVisibilityThresholdMs);
        }
    }

    METRIC_VALUE("game_system_batch_size", pending.size(),
        METRIC_TAG("system", "visibility"),
        METRIC_TAG("phase", "partition_deferred"),
        METRIC_TAG("map_id", std::to_string(GetId())));

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
