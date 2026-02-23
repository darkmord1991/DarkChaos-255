/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "MapUpdater.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "LFGMgr.h"
#include "Log.h"
#include "Map.h"
#include "MapMgr.h"
#include "Metric.h"
#include "PartitionUpdateWorker.h"
#include <algorithm>
#include <cmath>
#include <limits>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <vector>
#include <functional>

namespace
{
    constexpr int64 kSlowMapUpdateMs = 40;
    constexpr int64 kSlowPartitionWorkerMs = 200;
    constexpr int64 kSlowLfgUpdateMs = 20;
    constexpr uint64 kPartitionPercentileSummaryPeriodMs = 30000;
    constexpr size_t kPartitionPercentileSampleCap = 2048;

    struct PartitionLatencySummary
    {
        std::vector<uint32> queueWaitSamples;
        std::vector<uint32> runSamples;
        std::vector<uint32> totalSamples;
        size_t nextQueueWaitIndex = 0;
        size_t nextRunIndex = 0;
        size_t nextTotalIndex = 0;
        uint64 windowSamples = 0;
        uint64 lastLogMs = 0;
    };

    std::mutex gPartitionSummaryLock;
    std::unordered_map<uint64, PartitionLatencySummary> gPartitionSummaryByMapPartition;
    std::mutex gSlowMapUpdateLogGateLock;
    std::unordered_map<uint64, uint64> gSlowMapUpdateNextLogAtMs;
    std::mutex gPartitionExecutionLockMapLock;
    std::unordered_map<uint64, std::shared_ptr<std::mutex>> gPartitionExecutionLocksByMapInstance;

    std::shared_ptr<std::mutex> GetPartitionExecutionMutex(uint32 mapId, uint32 instanceId)
    {
        uint64 const key = (static_cast<uint64>(mapId) << 32) | instanceId;
        std::lock_guard<std::mutex> guard(gPartitionExecutionLockMapLock);
        auto& entry = gPartitionExecutionLocksByMapInstance[key];
        if (!entry)
            entry = std::make_shared<std::mutex>();
        return entry;
    }

    uint64 GetSteadyNowMs()
    {
        return static_cast<uint64>(std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()).count());
    }

    bool IsPartitionPercentileSamplingEnabled()
    {
        static bool const enabled = sConfigMgr->GetOption<bool>("System.PartitionMetrics.EnablePercentiles", false);
        return enabled;
    }

    bool IsPartitionQueueAgeTrackingEnabled()
    {
        static bool const enabled = sConfigMgr->GetOption<bool>("System.SlowPartitionCycle.TrackQueueAge", false);
        return enabled;
    }

    uint32 GetPartitionBurstBeforeGeneral()
    {
        static uint32 const burst = static_cast<uint32>(std::max<int64>(1,
            sConfigMgr->GetOption<int64>("MapUpdate.PartitionBurstBeforeGeneral", 3)));
        return burst;
    }

    int64 GetSlowMapUpdateTaskThresholdMs()
    {
        static int64 const thresholdMs = std::max<int64>(1, sConfigMgr->GetOption<int64>("System.SlowMapUpdateTask.ThresholdMs", kSlowMapUpdateMs));
        return thresholdMs;
    }

    uint64 GetSlowMapUpdateTaskLogIntervalMs()
    {
        static uint64 const intervalMs = static_cast<uint64>(std::max<int64>(0, sConfigMgr->GetOption<int64>("System.SlowMapUpdateTask.LogIntervalMs", 3000)));
        return intervalMs;
    }

    bool ShouldEmitSlowMapUpdateLog(Map const& map, uint64 nowMs, uint64 intervalMs)
    {
        if (intervalMs == 0)
            return true;

        uint64 const key = (static_cast<uint64>(map.GetId()) << 32) | map.GetInstanceId();
        std::lock_guard<std::mutex> guard(gSlowMapUpdateLogGateLock);
        uint64& nextAllowed = gSlowMapUpdateNextLogAtMs[key];
        if (nowMs < nextAllowed)
            return false;

        nextAllowed = nowMs + intervalMs;
        return true;
    }

    int64 GetSlowPartitionWorkerThresholdMs()
    {
        static int64 const thresholdMs = std::max<int64>(1, sConfigMgr->GetOption<int64>("System.SlowPartitionWorker.ThresholdMs", kSlowPartitionWorkerMs));
        return thresholdMs;
    }

    int AtomicSubtractClamped(std::atomic<int>& value, int delta)
    {
        if (delta <= 0)
            return value.load(std::memory_order_acquire);

        int observed = value.load(std::memory_order_acquire);
        while (true)
        {
            int const desired = std::max(0, observed - delta);
            if (value.compare_exchange_weak(observed, desired, std::memory_order_acq_rel, std::memory_order_acquire))
                return desired;
        }
    }

    uint32 ComputePercentile(std::vector<uint32> samples, double percentile)
    {
        if (samples.empty())
            return 0;

        percentile = std::clamp(percentile, 0.0, 1.0);
        size_t const index = static_cast<size_t>(std::ceil(percentile * static_cast<double>(samples.size() - 1)));
        std::nth_element(samples.begin(), samples.begin() + index, samples.end());
        return samples[index];
    }

    // O(1) ring-buffer insertion instead of O(N) std::move shift.
    void AddSample(std::vector<uint32>& samples, size_t& nextIndex, uint32 value)
    {
        if (samples.size() < kPartitionPercentileSampleCap)
        {
            samples.push_back(value);
            return;
        }

        samples[nextIndex % kPartitionPercentileSampleCap] = value;
        ++nextIndex;
    }

    void RecordPartitionPercentileSample(uint32 mapId, uint32 partitionId, uint32 queueWaitMs, uint32 runMs, uint64 nowMs)
    {
        uint32 const totalMs = queueWaitMs + runMs;
        uint64 const key = (static_cast<uint64>(mapId) << 32) | partitionId;

        std::lock_guard<std::mutex> guard(gPartitionSummaryLock);
        PartitionLatencySummary& summary = gPartitionSummaryByMapPartition[key];
        AddSample(summary.queueWaitSamples, summary.nextQueueWaitIndex, queueWaitMs);
        AddSample(summary.runSamples, summary.nextRunIndex, runMs);
        AddSample(summary.totalSamples, summary.nextTotalIndex, totalMs);
        ++summary.windowSamples;

        if (summary.lastLogMs == 0)
            summary.lastLogMs = nowMs;

        if ((nowMs - summary.lastLogMs) < kPartitionPercentileSummaryPeriodMs)
            return;

        LOG_INFO("map.partition.summary",
            "Partition latency summary: map={} partition={} samples={} queue_wait_ms(p50/p95/p99)={}/{}/{} run_ms(p50/p95/p99)={}/{}/{} total_ms(p50/p95/p99)={}/{}/{}",
            mapId,
            partitionId,
            summary.windowSamples,
            ComputePercentile(summary.queueWaitSamples, 0.50),
            ComputePercentile(summary.queueWaitSamples, 0.95),
            ComputePercentile(summary.queueWaitSamples, 0.99),
            ComputePercentile(summary.runSamples, 0.50),
            ComputePercentile(summary.runSamples, 0.95),
            ComputePercentile(summary.runSamples, 0.99),
            ComputePercentile(summary.totalSamples, 0.50),
            ComputePercentile(summary.totalSamples, 0.95),
            ComputePercentile(summary.totalSamples, 0.99));

        summary.queueWaitSamples.clear();
        summary.runSamples.clear();
        summary.totalSamples.clear();
        summary.nextQueueWaitIndex = 0;
        summary.nextRunIndex = 0;
        summary.nextTotalIndex = 0;
        summary.windowSamples = 0;
        summary.lastLogMs = nowMs;
    }
}

struct UpdateRequest
{
public:
    static constexpr uint64 REQUEST_MAGIC_ALIVE = 0xAC0DEF00D00DFEED;
    static constexpr uint64 REQUEST_MAGIC_FREED = 0xDEADDEADDEADDEAD;

    using CallFn = void(*)(UpdateRequest*) noexcept;
    using DestroyFn = void(*)(UpdateRequest*) noexcept;

    UpdateRequest(MapUpdater& owner, MapUpdater::UpdateRequestType type, CallFn callFn, DestroyFn destroyFn)
        : _magic(REQUEST_MAGIC_ALIVE), _callFn(callFn), _destroyFn(destroyFn), _owner(&owner), _type(type)
    {
    }

    UpdateRequest(UpdateRequest const&) = delete;
    UpdateRequest& operator=(UpdateRequest const&) = delete;

    void Finish() noexcept
    {
        if (_finished)
            return;

        _finished = true;

        if (_owner)
            _owner->update_finished(_type);
    }

    bool Execute(char const* name) noexcept
    {
        if (!ValidateMagic(name))
        {
            Finish();
            return false;
        }

        if (!_callFn)
        {
            LOG_ERROR("maps", "{}: UpdateRequest has null call function (magic=0x{:X})", name, _magic);
            Finish();
            return false;
        }

        _callFn(this);
        return true;
    }

    void Destroy() noexcept
    {
        // Ensure counters are updated if the request was cancelled/dropped
        Finish();

        // Avoid double-destroy if called multiple times from cancellation paths
        if (_magic == REQUEST_MAGIC_FREED)
            return;

        _magic = REQUEST_MAGIC_FREED;

        // If the deleter is corrupted, fall back to raw operator delete to
        // avoid a crash. This is best-effort cleanup.
        if (_destroyFn)
            _destroyFn(this);
        else
            ::operator delete(this);
    }

    [[nodiscard]] MapUpdater::UpdateRequestType GetType() const { return _type; }

protected:
    bool ValidateMagic(char const* name) const
    {
        if (_magic != REQUEST_MAGIC_ALIVE)
        {
            LOG_ERROR("maps", "{}: UpdateRequest magic corrupted (magic=0x{:X})", name, _magic);
            return false;
        }
        return true;
    }

    [[nodiscard]] MapUpdater* GetOwner() const { return _owner; }

private:
    uint64 _magic;
    CallFn _callFn;
    DestroyFn _destroyFn;
    MapUpdater* _owner;
    MapUpdater::UpdateRequestType _type;
    bool _finished = false;
};

class MapUpdateRequest final : public UpdateRequest
{
public:
    MapUpdateRequest(Map& m, MapUpdater& u, uint32 d, uint32 sd)
                : UpdateRequest(u, MapUpdater::UpdateRequestType::General, &MapUpdateRequest::DoCall, &MapUpdateRequest::DoDestroy),
          m_map(m), m_diff(d), s_diff(sd)
    {
    }

    static void DoCall(UpdateRequest* base) noexcept
    {
        auto* self = static_cast<MapUpdateRequest*>(base);
        auto const start = std::chrono::steady_clock::now();
        METRIC_TIMER("map_update_time_diff", METRIC_TAG("map_id", std::to_string(self->m_map.GetId())));
        self->m_map.Update(self->m_diff, self->s_diff);

        int64 const elapsedMs = std::chrono::duration_cast<Milliseconds>(std::chrono::steady_clock::now() - start).count();
        uint64 const nowMs = GetSteadyNowMs();
        uint64 const logIntervalMs = GetSlowMapUpdateTaskLogIntervalMs();
        if (elapsedMs >= GetSlowMapUpdateTaskThresholdMs() && ShouldEmitSlowMapUpdateLog(self->m_map, nowMs, logIntervalMs))
        {
            LOG_WARN("map.update.slow",
                "Slow map update task: map={} diff={} s_diff={} elapsed_ms={}",
                self->m_map.GetId(), self->m_diff, self->s_diff, elapsedMs);
        }

        self->Finish();
    }

    static void DoDestroy(UpdateRequest* base) noexcept
    {
        delete static_cast<MapUpdateRequest*>(base);
    }

private:
    Map& m_map;
    uint32 m_diff;
    uint32 s_diff;
};

class MapPreloadRequest : public UpdateRequest
{
public:
    MapPreloadRequest(uint32 mapId, MapUpdater& updater)
                : UpdateRequest(updater, MapUpdater::UpdateRequestType::General, &MapPreloadRequest::DoCall, &MapPreloadRequest::DoDestroy),
          _mapId(mapId)
    {
    }

    static void DoCall(UpdateRequest* base) noexcept
    {
        auto* self = static_cast<MapPreloadRequest*>(base);
        Map* map = sMapMgr->CreateBaseMap(self->_mapId);
        LOG_INFO("server.loading", ">> Loading All Grids For Map {} ({})", map->GetId(), map->GetMapName());
        map->LoadAllGrids();
        self->Finish();
    }

    static void DoDestroy(UpdateRequest* base) noexcept
    {
        delete static_cast<MapPreloadRequest*>(base);
    }

private:
    uint32 _mapId;
};

class GridObjectPreloadRequest : public UpdateRequest
{
public:
    GridObjectPreloadRequest(uint32 mapId, uint32 instanceId, MapUpdater& updater, std::vector<uint32> gridIds)
                : UpdateRequest(updater, MapUpdater::UpdateRequestType::General, &GridObjectPreloadRequest::DoCall, &GridObjectPreloadRequest::DoDestroy),
          _mapId(mapId), _instanceId(instanceId), _gridIds(std::move(gridIds))
    {
    }

    static void DoCall(UpdateRequest* base) noexcept
    {
        auto* self = static_cast<GridObjectPreloadRequest*>(base);
        if (!self->ValidateMagic("GridObjectPreloadRequest"))
        {
            self->Finish();
            return;
        }

        Map* map = sMapMgr->FindMap(self->_mapId, self->_instanceId);
        if (!map)
        {
            LOG_ERROR("maps", "GridObjectPreloadRequest: Map not found (mapId={}, instanceId={})", self->_mapId, self->_instanceId);
            self->Finish();
            return;
        }

        uint32 const maxGridId = MAX_NUMBER_OF_GRIDS * MAX_NUMBER_OF_GRIDS;
        if (self->_gridIds.size() > maxGridId)
        {
            LOG_ERROR("maps", "GridObjectPreloadRequest: gridId list size {} exceeds max {} (mapId={}, instanceId={})",
                self->_gridIds.size(), maxGridId, self->_mapId, self->_instanceId);
            self->Finish();
            return;
        }

        for (uint32 gridId : self->_gridIds)
        {
            if (gridId >= maxGridId)
            {
                LOG_ERROR("maps", "GridObjectPreloadRequest: invalid gridId {} (max {}), mapId={}, instanceId={}",
                    gridId, maxGridId, self->_mapId, self->_instanceId);
                continue;
            }
            map->PreloadGridObjectGuids(gridId);
        }
        self->Finish();
    }

    static void DoDestroy(UpdateRequest* base) noexcept
    {
        delete static_cast<GridObjectPreloadRequest*>(base);
    }

private:
    uint32 _mapId;
    uint32 _instanceId;
    std::vector<uint32> _gridIds;
};

class LFGUpdateRequest : public UpdateRequest
{
public:
    LFGUpdateRequest(MapUpdater& u, uint32 d)
        : UpdateRequest(u, MapUpdater::UpdateRequestType::General, &LFGUpdateRequest::DoCall, &LFGUpdateRequest::DoDestroy), m_diff(d) {}

    static void DoCall(UpdateRequest* base) noexcept
    {
        auto* self = static_cast<LFGUpdateRequest*>(base);
        auto const start = std::chrono::steady_clock::now();
        sLFGMgr->Update(self->m_diff, 1);

        int64 const elapsedMs = std::chrono::duration_cast<Milliseconds>(std::chrono::steady_clock::now() - start).count();
        if (elapsedMs >= kSlowLfgUpdateMs)
            LOG_WARN("system.slow", "Slow LFG update task: diff={} elapsed_ms={}", self->m_diff, elapsedMs);

        self->Finish();
    }

    static void DoDestroy(UpdateRequest* base) noexcept
    {
        delete static_cast<LFGUpdateRequest*>(base);
    }
private:
    uint32 m_diff;
};

class PartitionUpdateRequest : public UpdateRequest
{
public:
    PartitionUpdateRequest(Map& map, MapUpdater& updater, uint32 partitionId, uint32 diff, uint32 s_diff,
                std::function<void(MapUpdater::PartitionTaskTiming const&)> onDone, uint64 enqueueMs)
                : UpdateRequest(updater, MapUpdater::UpdateRequestType::Partition, &PartitionUpdateRequest::DoCall, &PartitionUpdateRequest::DoDestroy),
          _map(map), _partitionId(partitionId), _diff(diff), _sDiff(s_diff),
                    _onDone(std::move(onDone)), _enqueueMs(enqueueMs)
    {
    }

    static void DoCall(UpdateRequest* base) noexcept
    {
        auto* self = static_cast<PartitionUpdateRequest*>(base);
        auto startTime = std::chrono::steady_clock::now();
        uint64 const startMs = GetSteadyNowMs();
        MapUpdater* owner = self->GetOwner();
        if (owner)
            owner->OnPartitionWorkerStart();

        struct FinishGuard
        {
            FinishGuard(PartitionUpdateRequest* request,
                std::function<void(MapUpdater::PartitionTaskTiming const&)>& onDone,
                uint32 mapId,
                uint32 partitionId,
                std::chrono::steady_clock::time_point start,
                uint64 enqueueMs,
                uint64 startMs,
                MapUpdater* owner)
                : _request(request), _onDone(onDone), _mapId(mapId), _partitionId(partitionId), _start(start), _enqueueMs(enqueueMs), _startMs(startMs), _owner(owner) {}

            ~FinishGuard()
            {
                uint64 const endMs = GetSteadyNowMs();
                int64 const elapsedMs = std::chrono::duration_cast<Milliseconds>(
                    std::chrono::steady_clock::now() - _start).count();
                uint32 const runMs = elapsedMs > 0 ? static_cast<uint32>(elapsedMs) : 0;
                uint32 const queueWaitMs = (_startMs >= _enqueueMs) ? static_cast<uint32>(_startMs - _enqueueMs) : 0;

                if (IsPartitionPercentileSamplingEnabled())
                    RecordPartitionPercentileSample(_mapId, _partitionId, queueWaitMs, runMs, endMs);

                if (elapsedMs >= GetSlowPartitionWorkerThresholdMs())
                {
                    LOG_WARN("map.partition.slow",
                        "Slow partition worker: map={} partition={} elapsed_ms={}",
                        _mapId, _partitionId, elapsedMs);
                }

                try
                {
                    if (_onDone)
                    {
                        MapUpdater::PartitionTaskTiming timing;
                        timing.enqueueMs = _enqueueMs;
                        timing.startMs = _startMs;
                        timing.endMs = endMs;
                        timing.queueWaitMs = queueWaitMs;
                        timing.runMs = runMs;
                        _onDone(timing);
                    }
                }
                catch (std::exception const& e)
                {
                    LOG_ERROR("map.partition",
                        "PartitionUpdateWorker onDone exception map {} partition {}: {}",
                        _mapId, _partitionId, e.what());
                }
                catch (...)
                {
                    LOG_ERROR("map.partition",
                        "PartitionUpdateWorker onDone unknown exception map {} partition {}",
                        _mapId, _partitionId);
                }

                if (_owner)
                    _owner->OnPartitionWorkerDone(runMs);

                if (_request)
                    _request->Finish();
            }

            PartitionUpdateRequest* _request;
            std::function<void(MapUpdater::PartitionTaskTiming const&)>& _onDone;
            uint32 _mapId;
            uint32 _partitionId;
            std::chrono::steady_clock::time_point _start;
            uint64 _enqueueMs;
            uint64 _startMs;
            MapUpdater* _owner;
        } finishGuard(self, self->_onDone, self->_map.GetId(), self->_partitionId, startTime, self->_enqueueMs, startMs, owner);

        METRIC_TIMER("partition_update_time_diff",
            METRIC_TAG("map_id", std::to_string(self->_map.GetId())),
            METRIC_TAG("partition_id", std::to_string(self->_partitionId)));

        try
        {
            std::shared_ptr<std::mutex> executionMutex = GetPartitionExecutionMutex(self->_map.GetId(), self->_map.GetInstanceId());
            std::lock_guard<std::mutex> executionGuard(*executionMutex);
            PartitionUpdateWorker worker(self->_map, self->_partitionId, self->_diff, self->_sDiff);
            worker.Execute();
        }
        catch (std::exception const& e)
        {
            LOG_ERROR("map.partition", "PartitionUpdateWorker EXCEPTION map {} partition {}: {}",
                self->_map.GetId(), self->_partitionId, e.what());
        }
        catch (...)
        {
            LOG_ERROR("map.partition", "PartitionUpdateWorker UNKNOWN EXCEPTION map {} partition {}",
                self->_map.GetId(), self->_partitionId);
        }
    }

    static void DoDestroy(UpdateRequest* base) noexcept
    {
        delete static_cast<PartitionUpdateRequest*>(base);
    }

private:
    Map& _map;
    uint32 _partitionId;
    uint32 _diff;
    uint32 _sDiff;
    std::function<void(MapUpdater::PartitionTaskTiming const&)> _onDone;
    uint64 _enqueueMs;
};

MapUpdater::MapUpdater() : pending_requests(0), pending_partition_requests(0), _cancelationToken(false)
{
}

void MapUpdater::activate(std::size_t num_threads)
{
    uint32 dedicatedPartitionWorkers = 0;
    if (num_threads >= 4)
    {
        // Scale dedicated partition workers more aggressively for larger thread pools.
        // With many partitioned maps (e.g. 6+ continent maps with 10-12 partitions each),
        // 4 dedicated workers is insufficient to drain partition queues fast enough.
        // Formula: ~40% of threads for dedicated partition work, capped at 8.
        dedicatedPartitionWorkers = std::clamp<uint32>(
            static_cast<uint32>((num_threads * 2 + 4) / 5), // ~40% rounded
            2u,
            std::min<uint32>(8u, static_cast<uint32>(num_threads - 2)));
    }

    _dedicatedPartitionWorkers.store(dedicatedPartitionWorkers, std::memory_order_release);
    _workerDebugStates.clear();
    _workerDebugStates.reserve(num_threads);
    _workerThreads.reserve(num_threads);
    for (std::size_t i = 0; i < num_threads; ++i)
    {
        bool const partitionOnly = i < dedicatedPartitionWorkers;
        auto debugState = std::make_shared<WorkerDebugState>();
        debugState->partitionOnly.store(partitionOnly ? 1u : 0u, std::memory_order_release);
        debugState->lastBeatMs.store(GetSteadyNowMs(), std::memory_order_release);
        _workerDebugStates.push_back(debugState);
        _workerThreads.push_back(std::thread(&MapUpdater::WorkerThread, this, i, partitionOnly));
    }
}

void MapUpdater::deactivate()
{
    _cancelationToken = true;

    _queue.Cancel();  // Cancel queues first so workers can wake up and exit
    _partitionQueue.Cancel();

    wait();  // Now wait for any in-progress tasks to complete

    // Join all worker threads
    for (auto& thread : _workerThreads)
    {
        if (thread.joinable())
        {
            thread.join();
        }
    }
}

void MapUpdater::wait()
{
    std::unique_lock<std::mutex> guard(_lock);  // Guard lock for safe waiting

    // Wait until there are no pending requests, with periodic diagnostic logging
    auto start = std::chrono::steady_clock::now();
    while (!_condition.wait_for(guard, std::chrono::seconds(30), [this] {
        return pending_requests.load(std::memory_order_acquire) == 0;
    }))
    {
        int const pendingPartition = pending_partition_requests.load(std::memory_order_acquire);
        int const pendingTotal = pending_requests.load(std::memory_order_acquire);
        uint32 const activeWorkers = _activePartitionWorkers.load(std::memory_order_acquire);
        size_t const partitionQueued = _partitionQueue.Size();
        size_t const generalQueued = _queue.Size();
        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::steady_clock::now() - start).count();
        LOG_ERROR("maps.update",
            "MapUpdater::wait() stalled for {} seconds! pending_requests={} pending_partition_requests={} active_partition_workers={} queue_partition={} queue_general={} "
            "— possible deadlock/hung worker. Capture thread dump (GDB on Linux, ProcDump/VS on Windows).",
            elapsed, pendingTotal, pendingPartition, activeWorkers, partitionQueued, generalQueued);
        LogWorkerDebugState("MapUpdater::wait");

        if (pendingTotal > 0 && pendingPartition >= 0 && activeWorkers == 0 && partitionQueued == 0 && generalQueued == 0)
        {
            int const reclaimedPartition = pending_partition_requests.exchange(0, std::memory_order_acq_rel);
            int const reclaimedTotal = pending_requests.exchange(0, std::memory_order_acq_rel);

            LOG_ERROR("maps.update",
                "MapUpdater::wait() recovered stale pending counters: reclaimed_total={} reclaimed_partition={} (no active workers, empty queues)",
                reclaimedTotal, reclaimedPartition);

            _condition.notify_all();
            break;
        }
    }
}

void MapUpdater::schedule_task(UpdateRequest* request)
{
    // Atomic increment for pending_requests
    pending_requests.fetch_add(1, std::memory_order_release);
    _queue.Push(request);
}

void MapUpdater::schedule_update(Map& map, uint32 diff, uint32 s_diff)
{
    schedule_task(new MapUpdateRequest(map, *this, diff, s_diff));
}

void MapUpdater::schedule_map_preload(uint32 mapid)
{
    schedule_task(new MapPreloadRequest(mapid, *this));
}

void MapUpdater::schedule_grid_object_preload(Map& map, std::vector<uint32> const& gridIds)
{
    if (gridIds.empty())
        return;

    schedule_task(new GridObjectPreloadRequest(map.GetId(), map.GetInstanceId(), *this, gridIds));
}

void MapUpdater::schedule_lfg_update(uint32 diff)
{
    schedule_task(new LFGUpdateRequest(*this, diff));
}

void MapUpdater::schedule_partition_update(Map& map, uint32 partitionId, uint32 diff, uint32 s_diff,
    std::function<void(PartitionTaskTiming const&)> onDone)
{
    uint64 const enqueueMs = GetSteadyNowMs();
    pending_requests.fetch_add(1, std::memory_order_release);
    pending_partition_requests.fetch_add(1, std::memory_order_release);

    auto* request = new PartitionUpdateRequest(map, *this, partitionId, diff, s_diff, std::move(onDone), enqueueMs);
    if (IsPartitionQueueAgeTrackingEnabled())
        OnPartitionRequestEnqueued(request, enqueueMs);
    _partitionQueue.Push(request);
}

void MapUpdater::run_tasks_until(std::function<bool()> done)
{
    auto start = std::chrono::steady_clock::now();
    auto lastWarn = start;
    constexpr auto kWarnInterval = std::chrono::seconds(30);

    while (!done())
    {
        if (_cancelationToken)
            break;

        auto now = std::chrono::steady_clock::now();
        if (now - lastWarn >= kWarnInterval)
        {
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start).count();
            LOG_ERROR("map.partition",
                "run_tasks_until: STALLED for {} seconds! pending_requests={} "
                "— possible deadlock or hung partition worker. Capture thread dump (GDB on Linux, ProcDump/VS on Windows).",
                elapsed, pending_requests.load(std::memory_order_acquire));
            LogWorkerDebugState("run_tasks_until");
            lastWarn = now;
        }

        UpdateRequest* request = nullptr;
        if (_queue.WaitAndPopFor(request, std::chrono::milliseconds(2)))
        {
            if (request)
            {
                if (!_cancelationToken)
                    request->Execute("MapUpdater::run_tasks_until");
                request->Destroy();
            }
            continue;
        }
    }
}

void MapUpdater::run_partition_tasks_until(std::function<bool()> done)
{
    auto start = std::chrono::steady_clock::now();
    auto lastWarn = start;
    constexpr auto kWarnInterval = std::chrono::seconds(30);

    while (!done())
    {
        if (_cancelationToken)
            break;

        auto now = std::chrono::steady_clock::now();
        if (now - lastWarn >= kWarnInterval)
        {
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start).count();
            int const pendingPartition = pending_partition_requests.load(std::memory_order_acquire);
            int const pendingTotal = pending_requests.load(std::memory_order_acquire);
            uint32 const activeWorkers = _activePartitionWorkers.load(std::memory_order_acquire);
            size_t const partitionQueued = _partitionQueue.Size();
            size_t const generalQueued = _queue.Size();
            LOG_ERROR("map.partition",
                "run_partition_tasks_until: STALLED for {} seconds! pending_partition_requests={} pending_requests={} active_partition_workers={} queue_partition={} queue_general={} "
                "— possible deadlock or hung partition worker. Capture thread dump (GDB on Linux, ProcDump/VS on Windows).",
                elapsed, pendingPartition, pendingTotal, activeWorkers, partitionQueued, generalQueued);
            LogWorkerDebugState("run_partition_tasks_until");

            // If counters are non-zero but there is no queued work and no worker
            // currently executing partition updates, recover from stale counters
            // to avoid permanent wait loops.
            if (pendingPartition > 0 && activeWorkers == 0 && partitionQueued == 0)
            {
                int const reclaimedPartition = pending_partition_requests.exchange(0, std::memory_order_acq_rel);
                int const remainingTotal = AtomicSubtractClamped(pending_requests, reclaimedPartition);
                LOG_ERROR("map.partition",
                    "Recovered stale partition counters after stall: reclaimed_partition={} remaining_pending_requests={}",
                    reclaimedPartition, remainingTotal);

                std::lock_guard<std::mutex> lock(_lock);
                _condition.notify_all();
            }
            lastWarn = now;
        }

        UpdateRequest* request = nullptr;
        if (_partitionQueue.WaitAndPopFor(request, std::chrono::milliseconds(2)))
        {
            if (request)
            {
                if (request->GetType() == UpdateRequestType::Partition)
                    OnPartitionRequestDequeued(request);

                if (!_cancelationToken)
                    request->Execute("MapUpdater::run_partition_tasks_until");
                request->Destroy();
            }
            continue;
        }
    }
}

bool MapUpdater::activated()
{
    return !_workerThreads.empty();
}

std::size_t MapUpdater::GetWorkerCount() const
{
    return _workerThreads.size();
}

MapUpdater::PartitionPoolHealth MapUpdater::GetPartitionPoolHealth() const
{
    PartitionPoolHealth health;
    health.activeWorkers = _activePartitionWorkers.load(std::memory_order_acquire);
    int const pendingPartition = pending_partition_requests.load(std::memory_order_acquire);
    int const pendingTotal = pending_requests.load(std::memory_order_acquire);
    health.pendingJobs = static_cast<uint32>(std::max(0, pendingPartition));
    health.pendingGeneralJobs = static_cast<uint32>(std::max(0, pendingTotal - pendingPartition));
    health.maxPartitionRunMs = _maxPartitionRuntimeMs.load(std::memory_order_acquire);

    if (!IsPartitionQueueAgeTrackingEnabled())
        return health;

    uint64 oldestEnqueueMs = 0;
    {
        std::lock_guard<std::mutex> guard(_partitionQueueStateLock);
        if (!_partitionQueuedEnqueueTimes.empty())
            oldestEnqueueMs = *_partitionQueuedEnqueueTimes.begin();
    }

    if (oldestEnqueueMs > 0)
    {
        uint64 const nowMs = GetSteadyNowMs();
        if (nowMs >= oldestEnqueueMs)
            health.oldestQueuedAgeMs = static_cast<uint32>(nowMs - oldestEnqueueMs);
    }

    return health;
}

void MapUpdater::OnPartitionRequestEnqueued(UpdateRequest* request, uint64 enqueueMs)
{
    if (!IsPartitionQueueAgeTrackingEnabled())
        return;

    std::lock_guard<std::mutex> guard(_partitionQueueStateLock);
    _partitionEnqueueByRequest[request] = enqueueMs;
    _partitionQueuedEnqueueTimes.insert(enqueueMs);
}

void MapUpdater::OnPartitionRequestDequeued(UpdateRequest* request)
{
    if (!IsPartitionQueueAgeTrackingEnabled())
        return;

    std::lock_guard<std::mutex> guard(_partitionQueueStateLock);
    auto itr = _partitionEnqueueByRequest.find(request);
    if (itr == _partitionEnqueueByRequest.end())
        return;

    auto range = _partitionQueuedEnqueueTimes.equal_range(itr->second);
    if (range.first != range.second)
        _partitionQueuedEnqueueTimes.erase(range.first);

    _partitionEnqueueByRequest.erase(itr);
}

void MapUpdater::OnPartitionWorkerStart()
{
    _activePartitionWorkers.fetch_add(1, std::memory_order_acq_rel);
}

void MapUpdater::OnPartitionWorkerDone(uint64 runMs)
{
    _activePartitionWorkers.fetch_sub(1, std::memory_order_acq_rel);

    uint32 const runMs32 = static_cast<uint32>(std::min<uint64>(runMs, std::numeric_limits<uint32>::max()));
    uint32 observed = _maxPartitionRuntimeMs.load(std::memory_order_acquire);
    while (runMs32 > observed && !_maxPartitionRuntimeMs.compare_exchange_weak(observed, runMs32, std::memory_order_acq_rel))
    {
    }
}

void MapUpdater::update_finished(UpdateRequestType type)
{
    // Atomic decrement for pending_requests — use acq_rel for proper visibility of completed work
    if (type == UpdateRequestType::Partition)
        pending_partition_requests.fetch_sub(1, std::memory_order_acq_rel);

    if (pending_requests.fetch_sub(1, std::memory_order_acq_rel) == 1)
    {
        // Only notify when pending_requests becomes 0 (i.e., all tasks are finished)
        std::lock_guard<std::mutex> lock(_lock);  // Lock only for condition variable notification
        _condition.notify_all();  // Notify waiting threads that all requests are complete
    }
}

void MapUpdater::LogWorkerDebugState(char const* sourceTag) const
{
    if (_workerDebugStates.empty())
        return;

    uint64 const nowMs = GetSteadyNowMs();
    for (std::size_t i = 0; i < _workerDebugStates.size(); ++i)
    {
        std::shared_ptr<WorkerDebugState> const& state = _workerDebugStates[i];
        if (!state)
            continue;

        int32 const currentType = state->currentType.load(std::memory_order_acquire);
        char const* typeName = "idle";
        if (currentType == 0)
            typeName = "general";
        else if (currentType == 1)
            typeName = "partition";

        uint64 const lastStartMs = state->lastStartMs.load(std::memory_order_acquire);
        uint64 const lastFinishMs = state->lastFinishMs.load(std::memory_order_acquire);
        uint64 const lastBeatMs = state->lastBeatMs.load(std::memory_order_acquire);
        uint64 const runningForMs = (lastStartMs > 0 && nowMs >= lastStartMs)
            ? (nowMs - lastStartMs)
            : 0;
        uint64 const sinceFinishMs = (lastFinishMs > 0 && nowMs >= lastFinishMs)
            ? (nowMs - lastFinishMs)
            : 0;
        uint64 const sinceBeatMs = (lastBeatMs > 0 && nowMs >= lastBeatMs)
            ? (nowMs - lastBeatMs)
            : 0;

        LOG_ERROR("maps.update",
            "{} worker_state: idx={} partition_only={} active={} type={} request_ptr=0x{:X} thread_hash={} running_for_ms={} since_finish_ms={} since_heartbeat_ms={}",
            sourceTag,
            i,
            state->partitionOnly.load(std::memory_order_acquire),
            state->active.load(std::memory_order_acquire),
            typeName,
            static_cast<uint64>(state->requestPtr.load(std::memory_order_acquire)),
            state->threadIdHash.load(std::memory_order_acquire),
            runningForMs,
            sinceFinishMs,
            sinceBeatMs);
    }
}

void MapUpdater::WorkerThread(std::size_t workerIndex, bool partitionOnly)
{
    LoginDatabase.WarnAboutSyncQueries(true);
    CharacterDatabase.WarnAboutSyncQueries(true);
    WorldDatabase.WarnAboutSyncQueries(true);

    std::shared_ptr<WorkerDebugState> debugState;
    if (workerIndex < _workerDebugStates.size())
        debugState = _workerDebugStates[workerIndex];

    if (debugState)
    {
        uint64 const threadHash = static_cast<uint64>(std::hash<std::thread::id>{}(std::this_thread::get_id()));
        debugState->threadIdHash.store(threadHash, std::memory_order_release);
        debugState->partitionOnly.store(partitionOnly ? 1u : 0u, std::memory_order_release);
        debugState->lastBeatMs.store(GetSteadyNowMs(), std::memory_order_release);
    }

    uint32 partitionBurstSinceGeneral = 0;
    uint32 const partitionBurstBeforeGeneral = GetPartitionBurstBeforeGeneral();

    while (!_cancelationToken)
    {
        if (debugState)
            debugState->lastBeatMs.store(GetSteadyNowMs(), std::memory_order_release);

        UpdateRequest* request = nullptr;

        if (partitionOnly)
        {
            if (!_partitionQueue.WaitAndPopFor(request, std::chrono::milliseconds(1)))
                continue;
        }
        else
        {
            int const pendingPartition = pending_partition_requests.load(std::memory_order_acquire);
            int const pendingTotal = pending_requests.load(std::memory_order_acquire);
            int const pendingGeneral = std::max(0, pendingTotal - pendingPartition);
            bool const preferGeneral = pendingGeneral > 0 &&
                (partitionBurstSinceGeneral >= partitionBurstBeforeGeneral || pendingPartition <= 0);

            if (preferGeneral && _queue.Pop(request))
            {
                // got general task
            }
            else if (_partitionQueue.Pop(request))
            {
                // got partition task
            }
            else if (_queue.Pop(request))
            {
                // got general task
            }
            else
            {
                if (preferGeneral)
                {
                    if (!_queue.WaitAndPopFor(request, std::chrono::milliseconds(1)))
                        _partitionQueue.WaitAndPopFor(request, std::chrono::milliseconds(1));
                }
                else
                {
                    if (!_partitionQueue.WaitAndPopFor(request, std::chrono::milliseconds(1)))
                        _queue.WaitAndPopFor(request, std::chrono::milliseconds(1));
                }
            }
        }

        if (request)
        {
            UpdateRequestType const requestType = request->GetType();

            if (debugState)
            {
                debugState->active.store(1u, std::memory_order_release);
                debugState->currentType.store(requestType == UpdateRequestType::Partition ? 1 : 0, std::memory_order_release);
                debugState->requestPtr.store(reinterpret_cast<uintptr_t>(request), std::memory_order_release);
                debugState->lastStartMs.store(GetSteadyNowMs(), std::memory_order_release);
            }

            if (requestType == UpdateRequestType::Partition)
                OnPartitionRequestDequeued(request);

            if (!partitionOnly)
            {
                if (requestType == UpdateRequestType::Partition)
                    ++partitionBurstSinceGeneral;
                else
                    partitionBurstSinceGeneral = 0;
            }

            if (!_cancelationToken)
            {
                request->Execute("MapUpdater::WorkerThread");  // Execute the request
            }
            request->Destroy();  // Always clean up to prevent memory leak

            if (debugState)
            {
                uint64 const nowMs = GetSteadyNowMs();
                debugState->active.store(0u, std::memory_order_release);
                debugState->currentType.store(-1, std::memory_order_release);
                debugState->requestPtr.store(0, std::memory_order_release);
                debugState->lastFinishMs.store(nowMs, std::memory_order_release);
                debugState->lastBeatMs.store(nowMs, std::memory_order_release);
            }
        }
    }
}
