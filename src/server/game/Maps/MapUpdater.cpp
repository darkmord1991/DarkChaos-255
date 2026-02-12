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
#include "DatabaseEnv.h"
#include "LFGMgr.h"
#include "Log.h"
#include "Map.h"
#include "MapMgr.h"
#include "Metric.h"
#include "PartitionUpdateWorker.h"
#include <vector>

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
          m_map(m), m_updater(u), m_diff(d), s_diff(sd)
    {
    }

    static void DoCall(UpdateRequest* base) noexcept
    {
        auto* self = static_cast<MapUpdateRequest*>(base);
        METRIC_TIMER("map_update_time_diff", METRIC_TAG("map_id", std::to_string(self->m_map.GetId())));
        self->m_map.Update(self->m_diff, self->s_diff);
        self->Finish();
    }

    static void DoDestroy(UpdateRequest* base) noexcept
    {
        delete static_cast<MapUpdateRequest*>(base);
    }

private:
    Map& m_map;
    MapUpdater& m_updater;
    uint32 m_diff;
    uint32 s_diff;
};

class MapPreloadRequest : public UpdateRequest
{
public:
    MapPreloadRequest(uint32 mapId, MapUpdater& updater)
                : UpdateRequest(updater, MapUpdater::UpdateRequestType::General, &MapPreloadRequest::DoCall, &MapPreloadRequest::DoDestroy),
          _mapId(mapId), _updater(updater)
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
    MapUpdater& _updater;
};

class GridObjectPreloadRequest : public UpdateRequest
{
public:
    GridObjectPreloadRequest(uint32 mapId, uint32 instanceId, MapUpdater& updater, std::vector<uint32> gridIds)
                : UpdateRequest(updater, MapUpdater::UpdateRequestType::General, &GridObjectPreloadRequest::DoCall, &GridObjectPreloadRequest::DoDestroy),
          _mapId(mapId), _instanceId(instanceId), _updater(updater), _gridIds(std::move(gridIds))
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
    MapUpdater& _updater;
    std::vector<uint32> _gridIds;
};

class LFGUpdateRequest : public UpdateRequest
{
public:
    LFGUpdateRequest(MapUpdater& u, uint32 d)
        : UpdateRequest(u, MapUpdater::UpdateRequestType::General, &LFGUpdateRequest::DoCall, &LFGUpdateRequest::DoDestroy), m_updater(u), m_diff(d) {}

    static void DoCall(UpdateRequest* base) noexcept
    {
        auto* self = static_cast<LFGUpdateRequest*>(base);
        sLFGMgr->Update(self->m_diff, 1);
        self->Finish();
    }

    static void DoDestroy(UpdateRequest* base) noexcept
    {
        delete static_cast<LFGUpdateRequest*>(base);
    }
private:
    MapUpdater& m_updater;
    uint32 m_diff;
};

class PartitionUpdateRequest : public UpdateRequest
{
public:
    PartitionUpdateRequest(Map& map, MapUpdater& updater, uint32 partitionId, uint32 diff, uint32 s_diff,
        std::function<void()> onDone)
                : UpdateRequest(updater, MapUpdater::UpdateRequestType::Partition, &PartitionUpdateRequest::DoCall, &PartitionUpdateRequest::DoDestroy),
          _map(map), _updater(updater), _partitionId(partitionId), _diff(diff), _sDiff(s_diff),
          _onDone(std::move(onDone))
    {
    }

    static void DoCall(UpdateRequest* base) noexcept
    {
        auto* self = static_cast<PartitionUpdateRequest*>(base);
        auto startTime = std::chrono::steady_clock::now();

        struct FinishGuard
        {
            FinishGuard(PartitionUpdateRequest* request, std::function<void()>& onDone, uint32 mapId, uint32 partitionId,
                std::chrono::steady_clock::time_point start)
                : _request(request), _onDone(onDone), _mapId(mapId), _partitionId(partitionId), _start(start) {}

            ~FinishGuard()
            {
                auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
                    std::chrono::steady_clock::now() - _start);
                if (elapsed.count() >= 5)
                {
                    LOG_WARN("map.partition",
                        "PartitionUpdateWorker slow map {} partition {}: {}s",
                        _mapId, _partitionId, elapsed.count());
                }

                try
                {
                    if (_onDone)
                        _onDone();
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

                if (_request)
                    _request->Finish();
            }

            PartitionUpdateRequest* _request;
            std::function<void()>& _onDone;
            uint32 _mapId;
            uint32 _partitionId;
            std::chrono::steady_clock::time_point _start;
        } finishGuard(self, self->_onDone, self->_map.GetId(), self->_partitionId, startTime);

        METRIC_TIMER("partition_update_time_diff",
            METRIC_TAG("map_id", std::to_string(self->_map.GetId())),
            METRIC_TAG("partition_id", std::to_string(self->_partitionId)));

        try
        {
            PartitionUpdateWorker worker(self->_map, self->_partitionId, self->_diff, self->_sDiff);
            worker.Execute();
        }
        catch (std::exception const& e)
        {
            LOG_FATAL("map.partition", "PartitionUpdateWorker EXCEPTION map {} partition {}: {}",
                self->_map.GetId(), self->_partitionId, e.what());
        }
        catch (...)
        {
            LOG_FATAL("map.partition", "PartitionUpdateWorker UNKNOWN EXCEPTION map {} partition {}",
                self->_map.GetId(), self->_partitionId);
        }
    }

    static void DoDestroy(UpdateRequest* base) noexcept
    {
        delete static_cast<PartitionUpdateRequest*>(base);
    }

private:
    Map& _map;
    MapUpdater& _updater;
    uint32 _partitionId;
    uint32 _diff;
    uint32 _sDiff;
    std::function<void()> _onDone;
};

MapUpdater::MapUpdater() : pending_requests(0), pending_partition_requests(0), _cancelationToken(false)
{
}

void MapUpdater::activate(std::size_t num_threads)
{
    _workerThreads.reserve(num_threads);
    for (std::size_t i = 0; i < num_threads; ++i)
    {
        _workerThreads.push_back(std::thread(&MapUpdater::WorkerThread, this));
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
        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::steady_clock::now() - start).count();
        LOG_FATAL("maps.update",
            "MapUpdater::wait() stalled for {} seconds! pending_requests={} "
            "— possible deadlock. Attach GDB and run 'thread apply all bt'.",
            elapsed, pending_requests.load(std::memory_order_acquire));
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
    std::function<void()> onDone)
{
    pending_requests.fetch_add(1, std::memory_order_release);
    pending_partition_requests.fetch_add(1, std::memory_order_release);
    _partitionQueue.Push(new PartitionUpdateRequest(map, *this, partitionId, diff, s_diff, std::move(onDone)));
}

void MapUpdater::run_tasks_until(std::function<bool()> done)
{
    auto start = std::chrono::steady_clock::now();
    auto lastWarn = start;
    constexpr auto kWarnInterval = std::chrono::seconds(30);

    while (!done())
    {
        auto now = std::chrono::steady_clock::now();
        if (now - lastWarn >= kWarnInterval)
        {
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start).count();
            LOG_FATAL("map.partition",
                "run_tasks_until: STALLED for {} seconds! pending_requests={} "
                "— possible deadlock or hung partition worker. Use 'thread apply all bt' in GDB.",
                elapsed, pending_requests.load(std::memory_order_acquire));
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
        auto now = std::chrono::steady_clock::now();
        if (now - lastWarn >= kWarnInterval)
        {
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start).count();
            LOG_FATAL("map.partition",
                "run_partition_tasks_until: STALLED for {} seconds! pending_partition_requests={} "
                "— possible deadlock or hung partition worker. Use 'thread apply all bt' in GDB.",
                elapsed, pending_partition_requests.load(std::memory_order_acquire));
            lastWarn = now;
        }

        UpdateRequest* request = nullptr;
        if (_partitionQueue.WaitAndPopFor(request, std::chrono::milliseconds(2)))
        {
            if (request)
            {
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

void MapUpdater::WorkerThread()
{
    LoginDatabase.WarnAboutSyncQueries(true);
    CharacterDatabase.WarnAboutSyncQueries(true);
    WorldDatabase.WarnAboutSyncQueries(true);

    while (!_cancelationToken)
    {
        UpdateRequest* request = nullptr;

        // Priority: partition tasks first (they're latency-sensitive for the
        // cooperative main-thread spin in run_partition_tasks_until).
        if (_partitionQueue.Pop(request))
        {
            // got partition task
        }
        else if (_queue.Pop(request))
        {
            // got general task
        }
        else
        {
            // Neither queue has work — wait on general queue with a short timeout
            // then recheck partition queue. Using a single 2ms wait keeps latency
            // low while avoiding two consecutive timed waits (was 4ms worst case).
            if (!_queue.WaitAndPopFor(request, std::chrono::milliseconds(1)))
                _partitionQueue.WaitAndPopFor(request, std::chrono::milliseconds(1));
        }

        if (request)
        {
            if (!_cancelationToken)
            {
                request->Execute("MapUpdater::WorkerThread");  // Execute the request
            }
            request->Destroy();  // Always clean up to prevent memory leak
        }
    }
}
