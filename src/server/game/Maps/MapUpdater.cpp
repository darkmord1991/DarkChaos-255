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

class UpdateRequest
{
public:
    UpdateRequest() = default;
    virtual ~UpdateRequest() = default;

    virtual void call() = 0;
};

class MapUpdateRequest : public UpdateRequest
{
public:
    MapUpdateRequest(Map& m, MapUpdater& u, uint32 d, uint32 sd)
        : m_map(m), m_updater(u), m_diff(d), s_diff(sd)
    {
    }

    void call() override
    {
        METRIC_TIMER("map_update_time_diff", METRIC_TAG("map_id", std::to_string(m_map.GetId())));
        m_map.Update(m_diff, s_diff);
        m_updater.update_finished();
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
        : _mapId(mapId), _updater(updater)
    {
    }

    void call() override
    {
        Map* map = sMapMgr->CreateBaseMap(_mapId);
        LOG_INFO("server.loading", ">> Loading All Grids For Map {} ({})", map->GetId(), map->GetMapName());
        map->LoadAllGrids();
        _updater.update_finished();
    }

private:
    uint32 _mapId;
    MapUpdater& _updater;
};

class GridObjectPreloadRequest : public UpdateRequest
{
public:
    GridObjectPreloadRequest(Map& map, MapUpdater& updater, std::vector<uint32> gridIds)
        : _map(map), _updater(updater), _gridIds(std::move(gridIds))
    {
    }

    void call() override
    {
        for (uint32 gridId : _gridIds)
            _map.PreloadGridObjectGuids(gridId);
        _updater.update_finished();
    }

private:
    Map& _map;
    MapUpdater& _updater;
    std::vector<uint32> _gridIds;
};

class LFGUpdateRequest : public UpdateRequest
{
public:
    LFGUpdateRequest(MapUpdater& u, uint32 d) : m_updater(u), m_diff(d) {}

    void call() override
    {
        sLFGMgr->Update(m_diff, 1);
        m_updater.update_finished();
    }
private:
    MapUpdater& m_updater;
    uint32 m_diff;
};

class PartitionUpdateRequest : public UpdateRequest
{
public:
    PartitionUpdateRequest(Map& map, MapUpdater& updater, uint32 partitionId, uint32 diff, uint32 s_diff)
        : _map(map), _updater(updater), _partitionId(partitionId), _diff(diff), _sDiff(s_diff)
    {
    }

    void call() override
    {
        METRIC_TIMER("partition_update_time_diff",
            METRIC_TAG("map_id", std::to_string(_map.GetId())),
            METRIC_TAG("partition_id", std::to_string(_partitionId)));

        PartitionUpdateWorker worker(_map, _partitionId, _diff, _sDiff);
        worker.Execute();
        _updater.update_finished();
    }

private:
    Map& _map;
    MapUpdater& _updater;
    uint32 _partitionId;
    uint32 _diff;
    uint32 _sDiff;
};

MapUpdater::MapUpdater() : pending_requests(0), _cancelationToken(false)
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

    _queue.Cancel();  // Cancel queue first so workers can wake up and exit

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

    // Wait until there are no pending requests
    _condition.wait(guard, [this] {
        return pending_requests.load(std::memory_order_acquire) == 0;
    });
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

    schedule_task(new GridObjectPreloadRequest(map, *this, gridIds));
}

void MapUpdater::schedule_lfg_update(uint32 diff)
{
    schedule_task(new LFGUpdateRequest(*this, diff));
}

void MapUpdater::schedule_partition_update(Map& map, uint32 partitionId, uint32 diff, uint32 s_diff)
{
    schedule_task(new PartitionUpdateRequest(map, *this, partitionId, diff, s_diff));
}

bool MapUpdater::activated()
{
    return !_workerThreads.empty();
}

void MapUpdater::update_finished()
{
    // Atomic decrement for pending_requests — use acq_rel for proper visibility of completed work
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

        _queue.WaitAndPop(request);  // Wait for and pop a request from the queue

        if (request)
        {
            if (!_cancelationToken)
            {
                request->call();  // Execute the request
            }
            delete request;  // Always clean up to prevent memory leak
        }
    }
}
