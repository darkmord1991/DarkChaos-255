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

#ifndef _MAP_UPDATER_H_INCLUDED
#define _MAP_UPDATER_H_INCLUDED

#include "Define.h"
#include "PCQueue.h"
#include <condition_variable>
#include <functional>
#include <thread>
#include <atomic>
#include <mutex>
#include <set>
#include <unordered_map>
#include <vector>

class Map;
class UpdateRequest;

class MapUpdater
{
public:
    struct PartitionTaskTiming
    {
        uint64 enqueueMs = 0;
        uint64 startMs = 0;
        uint64 endMs = 0;
        uint32 queueWaitMs = 0;
        uint32 runMs = 0;
    };

    struct PartitionPoolHealth
    {
        uint32 activeWorkers = 0;
        uint32 pendingJobs = 0;
        uint32 oldestQueuedAgeMs = 0;
        uint32 maxPartitionRunMs = 0;
    };

    enum class UpdateRequestType
    {
        General,
        Partition
    };

    MapUpdater();
    ~MapUpdater() = default;

    void schedule_task(UpdateRequest* request);
    void schedule_update(Map& map, uint32 diff, uint32 s_diff);
    void schedule_map_preload(uint32 mapid);
    void schedule_grid_object_preload(Map& map, std::vector<uint32> const& gridIds);
    void schedule_lfg_update(uint32 diff);
    void schedule_partition_update(Map& map, uint32 partitionId, uint32 diff, uint32 s_diff,
        std::function<void(PartitionTaskTiming const&)> onDone = {});
    void run_tasks_until(std::function<bool()> done);
    void run_partition_tasks_until(std::function<bool()> done);
    void wait();
    void activate(std::size_t num_threads);
    void deactivate();
    bool activated();
    std::size_t GetWorkerCount() const;
    PartitionPoolHealth GetPartitionPoolHealth() const;
    void update_finished(UpdateRequestType type);

    void OnPartitionRequestEnqueued(UpdateRequest* request, uint64 enqueueMs);
    void OnPartitionRequestDequeued(UpdateRequest* request);
    void OnPartitionWorkerStart();
    void OnPartitionWorkerDone(uint64 runMs);

private:
    void WorkerThread();
    ProducerConsumerQueue<UpdateRequest*> _queue;
    ProducerConsumerQueue<UpdateRequest*> _partitionQueue;
    std::atomic<int> pending_requests;  // Use std::atomic for pending_requests to avoid lock contention
    std::atomic<int> pending_partition_requests;
    std::atomic<bool> _cancelationToken;  // Atomic flag for cancellation to avoid race conditions
    std::vector<std::thread> _workerThreads;
    std::mutex _lock; // Mutex and condition variable for synchronization
    std::condition_variable _condition;

    mutable std::mutex _partitionQueueStateLock;
    std::unordered_map<UpdateRequest*, uint64> _partitionEnqueueByRequest;
    std::multiset<uint64> _partitionQueuedEnqueueTimes;
    std::atomic<uint32> _activePartitionWorkers{0};
    std::atomic<uint32> _maxPartitionRuntimeMs{0};
};

#endif //_MAP_UPDATER_H_INCLUDED
