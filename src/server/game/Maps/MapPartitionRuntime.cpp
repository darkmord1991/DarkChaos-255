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
#include "ObjectAccessor.h"
#include "Corpse.h"
#include "DynamicObject.h"
#include "PartitionManager.h"
#include "Player.h"
#include "World.h"
#include <algorithm>
#include <chrono>
#include <limits>

namespace
{
    constexpr uint64 kSlowPartitionUpdateCycleMsDefault = 90;
    constexpr uint64 kSlowPartitionLogIntervalMsDefault = 5000;

    uint64 GetSteadyNowMs()
    {
        return static_cast<uint64>(std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()).count());
    }

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
        PreparePartitionObjectUpdateBudget(partitionCount, t_diff);

        LOG_DEBUG("map.partition", "Map {}: Scheduling {} partition updates in pipelined parallel mode", GetId(), partitionCount);

        _partitionUpdatesInProgress = true;
        _partitionUpdatesStartMs = GetSteadyNowMs();
        _partitionUpdatesTotal = partitionCount;
        _partitionUpdatesScheduled = 0;
        _partitionPrioritySchedule.clear();
        _partitionDeferredSchedule.clear();

        _partitionPrioritySchedule.reserve(partitionCount);
        _partitionDeferredSchedule.reserve(partitionCount);
        for (uint32 partitionId = 1; partitionId <= partitionCount; ++partitionId)
        {
            bool hasPlayers = false;
            if (std::vector<Player*> const* bucket = GetPartitionPlayerBucket(partitionId))
                hasPlayers = !bucket->empty();

            bool const hasRelayWork = HasPendingPartitionRelayWork(partitionId);
            if (hasPlayers || hasRelayWork)
                _partitionPrioritySchedule.push_back(partitionId);
            else
                _partitionDeferredSchedule.push_back(partitionId);
        }

        uint32 const configuredThreads = std::max<uint32>(1, sWorld->getIntConfig(CONFIG_NUMTHREADS));
        uint32 const updaterWorkers = std::max<uint32>(1, static_cast<uint32>(updater->GetWorkerCount()));
        uint32 const workerCapacity = std::max<uint32>(configuredThreads, updaterWorkers);
        MapUpdater::PartitionPoolHealth const poolHealth = updater->GetPartitionPoolHealth();

        uint32 adaptiveBaseline = std::max<uint32>(1, _adaptivePartitionInFlightLimit);
        if (workerCapacity >= 8)
            adaptiveBaseline = std::max<uint32>(adaptiveBaseline, workerCapacity / 2);
        if (workerCapacity >= 12)
            adaptiveBaseline = std::max<uint32>(adaptiveBaseline, (workerCapacity * 2) / 3);

        uint32 backlogBoost = 0;
        if (poolHealth.pendingJobs > workerCapacity)
        {
            uint32 const backlogOverWorkers = poolHealth.pendingJobs - workerCapacity;
            backlogBoost = std::min<uint32>(workerCapacity / 2, (backlogOverWorkers + workerCapacity - 1) / workerCapacity);
        }

        uint32 targetInFlight = std::min<uint32>(partitionCount, std::min<uint32>(workerCapacity, adaptiveBaseline + backlogBoost));

        if (poolHealth.pendingJobs > (workerCapacity * 6))
            targetInFlight = std::max<uint32>(1, targetInFlight - std::max<uint32>(1, workerCapacity / 4));

        static bool const dynamicInFlightEnabled = sConfigMgr->GetOption<bool>("MapPartitions.Worker.DynamicInFlight.Enable", true);
        static uint32 const dynamicHotRunThresholdMs = static_cast<uint32>(std::max<int64>(1,
            sConfigMgr->GetOption<int64>("MapPartitions.Worker.DynamicInFlight.HotRunThresholdMs", 320)));
        static uint32 const dynamicHotQueueWaitThresholdMs = static_cast<uint32>(std::max<int64>(1,
            sConfigMgr->GetOption<int64>("MapPartitions.Worker.DynamicInFlight.HotQueueWaitThresholdMs", 20)));
        static uint32 const dynamicReduceBy = static_cast<uint32>(std::max<int64>(1,
            sConfigMgr->GetOption<int64>("MapPartitions.Worker.DynamicInFlight.ReduceBy", 3)));

        if (dynamicInFlightEnabled &&
            (_lastPartitionCycleMaxRunMs >= dynamicHotRunThresholdMs ||
             _lastPartitionCycleMaxQueueWaitMs >= dynamicHotQueueWaitThresholdMs))
        {
            targetInFlight = std::max<uint32>(1, targetInFlight - dynamicReduceBy);
        }

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
        ++_partitionUpdatesScheduled;

        uint32 partitionId = 0;
        if (_partitionUpdatesScheduled <= _partitionPrioritySchedule.size())
        {
            partitionId = _partitionPrioritySchedule[_partitionUpdatesScheduled - 1];
        }
        else
        {
            size_t const deferredIndex = static_cast<size_t>(_partitionUpdatesScheduled - _partitionPrioritySchedule.size() - 1);
            if (deferredIndex < _partitionDeferredSchedule.size())
                partitionId = _partitionDeferredSchedule[deferredIndex];
        }

        if (partitionId == 0)
            continue;

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
        uint64 const nowMs = GetSteadyNowMs();
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
            uint64 const activeCycleMs = (_partitionUpdatesStartMs > 0 && lastTaskEndMs >= _partitionUpdatesStartMs)
                ? (lastTaskEndMs - _partitionUpdatesStartMs)
                : cycleMs;
            uint64 const detectionLagMs = (lastTaskEndMs > 0 && nowMs > lastTaskEndMs)
                ? (nowMs - lastTaskEndMs)
                : 0;
            uint64 const barrierBlockedMs = activeCycleMs > busyWindowMs ? (activeCycleMs - busyWindowMs) : 0;
            MapUpdater::PartitionPoolHealth const poolHealth = updater->GetPartitionPoolHealth();

            LOG_WARN("map.partition.slow",
                "Slow partition update cycle: map={} partitions={} completed={} scheduled={} in_flight_limit={} cycle_ms={} active_cycle_ms={} completion_detection_lag_ms={} enqueue_wait_ms={} run_ms={} barrier_blocked_ms={} max_partition_run_ms={} max_queue_wait_ms={} active_workers={} pending_jobs={} pending_general_jobs={} oldest_queued_age_ms={} pool_max_partition_run_ms={}",
                GetId(), _partitionUpdatesTotal, completed, _partitionUpdatesScheduled, _partitionUpdatesMaxInFlight, cycleMs,
                activeCycleMs, detectionLagMs, totalQueueWaitMs, totalRunMs, barrierBlockedMs, maxRunMs, maxQueueWaitMs,
                poolHealth.activeWorkers, poolHealth.pendingJobs, poolHealth.pendingGeneralJobs, poolHealth.oldestQueuedAgeMs, poolHealth.maxPartitionRunMs);

            if (slowPartitionLogIntervalMs > 0)
                _nextSlowPartitionLogAtMs = nowMs + slowPartitionLogIntervalMs;
        }

        ClearPartitionPlayerBuckets();
        _lastPartitionCycleMaxRunMs = static_cast<uint32>(std::min<uint64>(std::numeric_limits<uint32>::max(), _partitionCycleMaxRunMs.load(std::memory_order_acquire)));
        _lastPartitionCycleMaxQueueWaitMs = static_cast<uint32>(std::min<uint64>(std::numeric_limits<uint32>::max(), _partitionCycleMaxQueueWaitMs.load(std::memory_order_acquire)));
        _partitionUpdatesInProgress = false;
        _partitionUpdatesTotal = 0;
        _partitionUpdatesScheduled = 0;
        _partitionUpdatesMaxInFlight = 1;
        _partitionPrioritySchedule.clear();
        _partitionDeferredSchedule.clear();
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

void Map::PreparePartitionObjectUpdateBudget(uint32 partitionCount, uint32 tDiff)
{
    uint32 configuredBudget = static_cast<uint32>(std::max<int64>(0, sConfigMgr->GetOption<int64>("MapPartitions.Worker.ObjectUpdateBudget", 0)));
    bool const carryOver = sConfigMgr->GetOption<bool>("MapPartitions.Worker.ObjectUpdateBudgetCarryOver", true);
    uint32 const hotPartitionThresholdMs = static_cast<uint32>(std::max<int64>(1,
        sConfigMgr->GetOption<int64>("MapPartitions.Worker.ObjectUpdateBudget.HotPartitionThresholdMs", 320)));
    uint32 hotScalePct = static_cast<uint32>(sConfigMgr->GetOption<int64>("MapPartitions.Worker.ObjectUpdateBudget.HotPartitionScalePct", 50));
    if (hotScalePct > 100)
        hotScalePct = 100;

    if (configuredBudget == 0)
    {
        std::lock_guard<std::mutex> guard(_partitionObjectBudgetLock);
        _partitionObjectUpdateBudget = 0;
        _partitionObjectUpdateCarryOver = carryOver;
        _partitionObjectUpdateCursor.assign(partitionCount, 0);
        return;
    }

    if (configuredBudget > 0 && _lastPartitionCycleMaxRunMs >= hotPartitionThresholdMs && hotScalePct > 0)
    {
        configuredBudget = std::max<uint32>(1, (configuredBudget * hotScalePct) / 100);
    }

    if (configuredBudget > 0)
    {
        if (tDiff >= 300)
            configuredBudget = std::max<uint32>(1, configuredBudget / 3);
        else if (tDiff >= 180)
            configuredBudget = std::max<uint32>(1, configuredBudget / 2);
        else if (tDiff >= 120)
            configuredBudget = std::max<uint32>(1, (configuredBudget * 3) / 4);
    }

    std::lock_guard<std::mutex> guard(_partitionObjectBudgetLock);
    _partitionObjectUpdateBudget = configuredBudget;
    _partitionObjectUpdateCarryOver = carryOver;
    _partitionObjectUpdateCursor.assign(partitionCount, 0);
}

void Map::GetPartitionObjectUpdateWindow(uint32 partitionId, uint32 totalObjects, uint32& startIndex, uint32& objectCount)
{
    startIndex = 0;
    objectCount = totalObjects;

    if (partitionId == 0 || totalObjects == 0)
        return;

    std::lock_guard<std::mutex> guard(_partitionObjectBudgetLock);

    if (_partitionObjectUpdateBudget == 0 || _partitionObjectUpdateBudget >= totalObjects)
        return;

    objectCount = std::min<uint32>(_partitionObjectUpdateBudget, totalObjects);

    if (!_partitionObjectUpdateCarryOver)
        return;

    uint32 index = partitionId - 1;
    if (index >= _partitionObjectUpdateCursor.size())
        return;

    uint32& cursor = _partitionObjectUpdateCursor[index];
    cursor %= totalObjects;
    startIndex = cursor;
    cursor = (cursor + objectCount) % totalObjects;
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

void Map::QueueDeferredPlayerRelocation(ObjectGuid const& playerGuid, float x, float y, float z, float o)
{
    if (!playerGuid || !playerGuid.IsPlayer())
        return;

    std::lock_guard<std::mutex> guard(_deferredPlayerRelocationLock);
    auto [itr, inserted] = _deferredPlayerRelocations.emplace(playerGuid, DeferredPlayerRelocation{ playerGuid, x, y, z, o });
    if (!inserted)
    {
        itr->second.x = x;
        itr->second.y = y;
        itr->second.z = z;
        itr->second.o = o;
        return;
    }

    _deferredPlayerRelocationOrder.push_back(playerGuid);
}

void Map::ProcessDeferredPlayerRelocations()
{
    std::vector<DeferredPlayerRelocation> pending;
    size_t queueDepthBefore = 0;
    size_t queueDepthAfter = 0;
    size_t budgetUsed = 0;
    uint32 configuredBudget = 0;
    {
        std::lock_guard<std::mutex> guard(_deferredPlayerRelocationLock);
        if (_deferredPlayerRelocationOrder.empty())
            return;

        configuredBudget = static_cast<uint32>(std::max<int64>(0,
            sConfigMgr->GetOption<int64>("MapPartitions.DeferredPlayerRelocation.MaxPerTick", 0)));
        size_t budget = configuredBudget;
        if (budget == 0)
        {
            size_t adaptiveBudget = std::clamp<size_t>(_adaptiveDeferredVisibilityBudget, 128, 1024);
            size_t const queueDepth = _deferredPlayerRelocationOrder.size();

            if (queueDepth > adaptiveBudget)
            {
                size_t const backlogBudget = std::max<size_t>(adaptiveBudget, queueDepth / 2);
                adaptiveBudget = std::min<size_t>(2048, backlogBudget);
            }

            budget = adaptiveBudget;
        }

        queueDepthBefore = _deferredPlayerRelocationOrder.size();
        budgetUsed = budget;

        size_t const takeCount = std::min(budget, _deferredPlayerRelocationOrder.size());
        pending.reserve(takeCount);
        for (size_t i = 0; i < takeCount; ++i)
        {
            ObjectGuid const guid = _deferredPlayerRelocationOrder.front();
            _deferredPlayerRelocationOrder.pop_front();

            auto itr = _deferredPlayerRelocations.find(guid);
            if (itr == _deferredPlayerRelocations.end())
                continue;

            pending.push_back(itr->second);
            _deferredPlayerRelocations.erase(itr);
        }

        queueDepthAfter = _deferredPlayerRelocationOrder.size();
    }

    size_t applied = 0;
    size_t skipped = 0;
    for (DeferredPlayerRelocation const& relocation : pending)
    {
        Player* player = ObjectAccessor::FindPlayer(relocation.playerGuid);
        if (!player || !player->IsInWorld() || player->GetMap() != this)
        {
            ++skipped;
            continue;
        }

        PlayerRelocation(player, relocation.x, relocation.y, relocation.z, relocation.o);
        ++applied;
    }

    METRIC_VALUE("partition_deferred_player_relocation_queue", queueDepthBefore,
        METRIC_TAG("map_id", std::to_string(GetId())),
        METRIC_TAG("phase", "before"));
    METRIC_VALUE("partition_deferred_player_relocation_queue", queueDepthAfter,
        METRIC_TAG("map_id", std::to_string(GetId())),
        METRIC_TAG("phase", "after"));
    METRIC_VALUE("partition_deferred_player_relocation_batch", pending.size(),
        METRIC_TAG("map_id", std::to_string(GetId())),
        METRIC_TAG("phase", "drained"));

    static bool const telemetryEnabled = sConfigMgr->GetOption<bool>("MapPartitions.DeferredPlayerRelocation.Telemetry.Enable", true);
    static uint32 const telemetryWarnQueueDepth = static_cast<uint32>(std::max<int64>(1,
        sConfigMgr->GetOption<int64>("MapPartitions.DeferredPlayerRelocation.Telemetry.WarnQueueDepth", 128)));
    static uint64 const telemetryLogIntervalMs = static_cast<uint64>(std::max<int64>(0,
        sConfigMgr->GetOption<int64>("MapPartitions.DeferredPlayerRelocation.Telemetry.LogIntervalMs", 2000)));

    bool const saturatedDrain = queueDepthBefore > pending.size() && pending.size() >= budgetUsed;
    if (telemetryEnabled && (queueDepthBefore >= telemetryWarnQueueDepth || saturatedDrain))
    {
        uint64 const nowMs = GetSteadyNowMs();
        if (telemetryLogIntervalMs == 0 || nowMs >= _nextDeferredPlayerRelocationLogAtMs)
        {
            LOG_WARN("map.partition.defer",
                "Deferred player relocation queue pressure: map={} queue_before={} drained={} applied={} skipped={} queue_after={} budget={} configured_budget={} adaptive_visibility_budget={} saturated_drain={}",
                GetId(), queueDepthBefore, pending.size(), applied, skipped, queueDepthAfter, budgetUsed,
                configuredBudget, _adaptiveDeferredVisibilityBudget, saturatedDrain ? 1 : 0);

            if (telemetryLogIntervalMs > 0)
                _nextDeferredPlayerRelocationLogAtMs = nowMs + telemetryLogIntervalMs;
        }
    }
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
}

void Map::ClearPartitionPlayerBuckets()
{
    std::unique_lock<std::shared_mutex> guard(_partitionPlayerBucketsLock);
    _partitionPlayerBucketsReady = false;
}

bool Map::HasPendingPartitionRelayWork(uint32 partitionId)
{
    if (!_isPartitioned || partitionId == 0)
        return false;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto const hasRelayWork = [partitionId](auto const& relayMap)
    {
        auto itr = relayMap.find(partitionId);
        return itr != relayMap.end() && !itr->second.empty();
    };

    return hasRelayWork(_partitionThreatRelays) ||
        hasRelayWork(_partitionThreatActionRelays) ||
        hasRelayWork(_partitionThreatTargetActionRelays) ||
        hasRelayWork(_partitionTauntRelays) ||
        hasRelayWork(_partitionCombatRelays) ||
        hasRelayWork(_partitionLootRelays) ||
        hasRelayWork(_partitionDynObjectRelays) ||
        hasRelayWork(_partitionMinionRelays) ||
        hasRelayWork(_partitionCharmRelays) ||
        hasRelayWork(_partitionGameObjectRelays) ||
        hasRelayWork(_partitionCombatStateRelays) ||
        hasRelayWork(_partitionAttackRelays) ||
        hasRelayWork(_partitionEvadeRelays) ||
        hasRelayWork(_partitionMotionRelays) ||
        hasRelayWork(_partitionProcRelays) ||
        hasRelayWork(_partitionAuraRelays) ||
        hasRelayWork(_partitionPathRelays) ||
        hasRelayWork(_partitionPointRelays) ||
        hasRelayWork(_partitionAssistRelays) ||
        hasRelayWork(_partitionAssistDistractRelays);
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
