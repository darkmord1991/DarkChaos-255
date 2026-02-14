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

#include "Map.h"
#include "Battleground.h"
#include "CellImpl.h"
#include "Chat.h"
#include "Config.h"
#include "CreatureAI.h"
#include "DisableMgr.h"
#include "DynamicTree.h"
#include "GameTime.h"
#include "Geometry.h"
#include "GridNotifiers.h"
#include "GridObjectLoader.h"
#include "Group.h"
#include "InstanceScript.h"
#include "IVMapMgr.h"
#include "LFGMgr.h"
#include "Log.h"
#include "MoveSplineInitArgs.h"
#include "MoveSplineInit.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "Pet.h"
#include "Player.h"
#include "Maps/Partitioning/PartitionManager.h"
#include "Maps/Partitioning/LayerManager.h"
#include <cstring>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <algorithm>
#include <optional>
#include <condition_variable>
#include <functional>
#include <queue>
#include <thread>
#include "MapGrid.h"
#include "MapInstanced.h"
#include "Metric.h"
#include "MiscPackets.h"
#include "MMapFactory.h"
#include "Object.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Pet.h"
#include "ScriptMgr.h"
#include "SpellMgr.h"
#include "TypeContainerVisitor.h"
#include "Transport.h"
#include "VMapFactory.h"
#include "Vehicle.h"
#include "VMapMgr2.h"
#include "Weather.h"
#include "WeatherMgr.h"
#include "Unit.h"
#include "MapUpdater.h"

namespace
{
    constexpr size_t kGuidCleanupScanIndexLimit = 4096;
    // Maximum sane element / bucket count for any hash table.
    // Any value beyond this indicates heap-corruption of internal fields.
    constexpr size_t kHashMapSaneLimit = 50000000;

    /// Validate that an unordered_map / unordered_set is not obviously corrupted.
    /// Only reads size() and bucket_count() — plain field reads, no chain traversal —
    /// so this is safe even when the internal hash chains are damaged.
    /// Returns false (and logs) when corruption is detected.
    template<typename Container>
    bool IsHashContainerSane(Container const& c, char const* name, uint32 mapId)
    {
        size_t const bc = c.bucket_count();
        size_t const sz = c.size();
        if (bc == 0 || bc > kHashMapSaneLimit || sz > kHashMapSaneLimit)
        {
            LOG_ERROR("maps", "Map {}: {} corrupted (bucket_count={}, size={}) — "
                "skipping operation to prevent crash", mapId, name, bc, sz);
            return false;
        }
        return true;
    }

    /// Swap-and-leak: replace a corrupted hash container with a fresh empty one.
    /// The corrupted container is intentionally leaked because its internal nodes
    /// would crash if freed / iterated.
    template<typename Container>
    void SwapAndLeakCorrupted(Container& c, char const* name, uint32 mapId)
    {
        LOG_ERROR("maps", "Map {}: {} swap-and-leak (bucket_count={}, size={})",
            mapId, name, c.bucket_count(), c.size());
        auto* leaked = new Container();
        leaked->swap(c);
        // `leaked` is intentionally never freed.
    }

    uint64 GetThreadIdHash()
    {
        return static_cast<uint64>(std::hash<std::thread::id>{}(std::this_thread::get_id()));
    }

    void CheckPartitionStoreWriter(std::atomic<uint64>& writerHash, uint32 mapId, char const* op)
    {
        uint64 current = GetThreadIdHash();
        uint64 prev = writerHash.load(std::memory_order_relaxed);
        if (prev == 0)
        {
            writerHash.store(current, std::memory_order_relaxed);
            return;
        }
        if (prev != current)
        {
            LOG_ERROR("map.partition", "Partitioned store cross-thread mutation detected (map {}, op {}, prev=0x{:X}, now=0x{:X})",
                mapId, op, prev, current);
            writerHash.store(current, std::memory_order_relaxed);
        }
    }

    thread_local uint32 sNonPlayerVisibilityDeferDepth = 0;

    class SendUpdateWorkerPool
    {
    public:
        SendUpdateWorkerPool() = default;
        ~SendUpdateWorkerPool()
        {
            Stop();
        }

        void EnsureThreads(size_t threadCount)
        {
            if (threadCount == 0 || !_threads.empty())
                return;

            _threads.reserve(threadCount);
            for (size_t i = 0; i < threadCount; ++i)
                _threads.emplace_back([this]() { ThreadMain(); });
        }

        template <typename TaskFn>
        void RunTasks(size_t taskCount, TaskFn&& taskFn)
        {
            if (taskCount == 0)
                return;

            struct WorkGroup
            {
                explicit WorkGroup(size_t count) : pending(count) {}

                void Done()
                {
                    if (pending.fetch_sub(1, std::memory_order_acq_rel) == 1)
                    {
                        std::lock_guard<std::mutex> lock(mutex);
                        cv.notify_all();
                    }
                }

                void Wait()
                {
                    std::unique_lock<std::mutex> lock(mutex);
                    cv.wait(lock, [this]() { return pending.load(std::memory_order_acquire) == 0; });
                }

                std::atomic<size_t> pending;
                std::mutex mutex;
                std::condition_variable cv;
            };

            auto group = std::make_shared<WorkGroup>(taskCount);
            for (size_t index = 0; index < taskCount; ++index)
            {
                Enqueue([group, &taskFn, index]()
                {
                    taskFn(index);
                    group->Done();
                });
            }

            group->Wait();
        }

    private:
        void Enqueue(std::function<void()> task)
        {
            {
                std::lock_guard<std::mutex> lock(_mutex);
                _tasks.push(std::move(task));
            }
            _cv.notify_one();
        }

        void Stop()
        {
            {
                std::lock_guard<std::mutex> lock(_mutex);
                _stop = true;
            }
            _cv.notify_all();

            for (std::thread& thread : _threads)
            {
                if (thread.joinable())
                    thread.join();
            }
        }

        void ThreadMain()
        {
            while (true)
            {
                std::function<void()> task;
                {
                    std::unique_lock<std::mutex> lock(_mutex);
                    _cv.wait(lock, [this]() { return _stop || !_tasks.empty(); });
                    if (_stop && _tasks.empty())
                        return;

                    task = std::move(_tasks.front());
                    _tasks.pop();
                }

                if (task)
                    task();
            }
        }

        std::vector<std::thread> _threads;
        std::queue<std::function<void()>> _tasks;
        std::mutex _mutex;
        std::condition_variable _cv;
        bool _stop = false;
    };

    SendUpdateWorkerPool& GetSendUpdateWorkerPool()
    {
        static SendUpdateWorkerPool pool;
        return pool;
    }

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

#define MAP_INVALID_ZONE        0xFFFFFFFF

ZoneDynamicInfo::ZoneDynamicInfo() : MusicId(0), DefaultWeather(nullptr), WeatherId(WEATHER_STATE_FINE),
                                     WeatherGrade(0.0f), OverrideLightId(0), LightFadeInTime(0) { }

Map::~Map()
{
    // UnloadAll must be called before deleting the map

    // Kill all scheduled events without executing them, since the map and its objects are being destroyed.
    // This prevents events from running on invalid or deleted objects during map destruction.
    Events.KillAllEvents(false);

    sScriptMgr->OnDestroyMap(this);

    std::size_t pendingScripts = 0;
    {
        std::lock_guard<std::mutex> lock(_scriptScheduleLock);
        pendingScripts = m_scriptSchedule.size();
        m_scriptSchedule.clear();
    }
    if (pendingScripts)
        sScriptMgr->DecreaseScheduledScriptCount(pendingScripts);

    MMAP::MMapFactory::createOrGetMMapMgr()->unloadMapInstance(GetId(), i_InstanceId);
}

Map::Map(uint32 id, uint32 InstanceId, uint8 SpawnMode, Map* _parent) :
    _mapGridManager(this), i_mapEntry(sMapStore.LookupEntry(id)), i_spawnMode(SpawnMode), i_InstanceId(InstanceId),
    m_unloadTimer(0), m_VisibleDistance(DEFAULT_VISIBILITY_DISTANCE), _instanceResetPeriod(0),
    _transportsUpdateIter(_transports.end()), _markedCells(kMarkedCellWordCount), i_scriptLock(false),
    _defaultLight(GetDefaultMapLight(id))
{
    m_parentMap = (_parent ? _parent : this);

    _zonePlayerCountMap.clear();
    resetMarkedCells();
    _updatableObjectListRecheckTimer.SetInterval(UPDATABLE_OBJECT_LIST_RECHECK_TIMER);

    //lets initialize visibility distance for map
    Map::InitVisibilityDistance();

    _weatherUpdateTimer.SetInterval(1 * IN_MILLISECONDS);
    _corpseUpdateTimer.SetInterval(20 * MINUTE * IN_MILLISECONDS);
}

// Hook called after map is created AND after added to map list
void Map::OnCreateMap()
{
    // Instances load all grids by default (both base map and child maps)
    if (GetInstanceId())
        LoadAllGrids();

    sScriptMgr->OnCreateMap(this);
}

void Map::InitVisibilityDistance()
{
    //init visibility for continents
    m_VisibleDistance = World::GetMaxVisibleDistanceOnContinents();

    switch (GetId())
    {
        case MAP_EBON_HOLD: // Scarlet Enclave (DK starting zone)
            m_VisibleDistance = 125.0f;
            break;
        case MAP_SCOTT_TEST: // (box map)
            m_VisibleDistance = 200.0f;
            break;
    }
}

// Template specialization of utility methods
template<class T>
void Map::AddToGrid(T* obj, Cell const& cell)
{
    auto gridLock = AcquireGridObjectWriteLock();
    std::lock_guard<std::recursive_mutex> guard(_mapGridManager._gridLock);
    MapGridType* grid = GetMapGrid(cell.GridX(), cell.GridY());
    grid->AddGridObject<T>(cell.CellX(), cell.CellY(), obj);

    obj->SetCurrentCell(cell);
}

template<>
void Map::AddToGrid(Creature* obj, Cell const& cell)
{
    auto gridLock = AcquireGridObjectWriteLock();
    std::lock_guard<std::recursive_mutex> guard(_mapGridManager._gridLock);
    MapGridType* grid = GetMapGrid(cell.GridX(), cell.GridY());
    grid->AddGridObject(cell.CellX(), cell.CellY(), obj);
    if (obj->IsFarVisible())
        grid->AddFarVisibleObject(cell.CellX(), cell.CellY(), obj);

    obj->SetCurrentCell(cell);
}

template<>
void Map::AddToGrid(GameObject* obj, Cell const& cell)
{
    auto gridLock = AcquireGridObjectWriteLock();
    std::lock_guard<std::recursive_mutex> guard(_mapGridManager._gridLock);
    MapGridType* grid = GetMapGrid(cell.GridX(), cell.GridY());
    grid->AddGridObject(cell.CellX(), cell.CellY(), obj);
    if (obj->IsFarVisible())
        grid->AddFarVisibleObject(cell.CellX(), cell.CellY(), obj);

    obj->SetCurrentCell(cell);
}

template<>
void Map::AddToGrid(Player* obj, Cell const& cell)
{
    auto gridLock = AcquireGridObjectWriteLock();
    std::lock_guard<std::recursive_mutex> guard(_mapGridManager._gridLock);
    MapGridType* grid = GetMapGrid(cell.GridX(), cell.GridY());
    grid->AddGridObject(cell.CellX(), cell.CellY(), obj);
}

template<>
void Map::AddToGrid(Corpse* obj, Cell const& cell)
{
    auto gridLock = AcquireGridObjectWriteLock();
    std::lock_guard<std::recursive_mutex> guard(_mapGridManager._gridLock);
    MapGridType* grid = GetMapGrid(cell.GridX(), cell.GridY());
    // Corpses are a special object type - they can be added to grid via a call to AddToMap
    // or loaded through ObjectGridLoader.
    // Both corpses loaded from database and these freshly generated by Player::CreateCoprse are added to _corpsesByCell
    // ObjectGridLoader loads all corpses from _corpsesByCell even if they were already added to grid before it was loaded
    // so we need to explicitly check it here (Map::AddToGrid is only called from Player::BuildPlayerRepop, not from ObjectGridLoader)
    // to avoid failing an assertion in GridObject::AddToGrid
    if (grid->IsObjectDataLoaded())
        grid->AddGridObject(cell.CellX(), cell.CellY(), obj);
}

template<class T>
void Map::DeleteFromWorld(T* obj)
{
    // Note: In case resurrectable corpse and pet its removed from global lists in own destructor
    delete obj;
}

template<>
void Map::DeleteFromWorld(Player* player)
{
    ObjectAccessor::RemoveObject(player);

    RemoveUpdateObject(player); //TODO: I do not know why we need this, it should be removed in ~Object anyway
    delete player;
}

void Map::EnsureGridCreated(GridCoord const& gridCoord)
{
    _mapGridManager.CreateGrid(gridCoord.x_coord, gridCoord.y_coord);
}

bool Map::EnsureGridLoaded(Cell const& cell)
{
    EnsureGridCreated(GridCoord(cell.GridX(), cell.GridY()));

    if (_mapGridManager.LoadGrid(cell.GridX(), cell.GridY()))
    {
        Balance();
        uint32 gridId = GridCoord(cell.GridX(), cell.GridY()).GetId();
        {
            std::lock_guard<std::mutex> guard(_gridLayerLock);
            _gridLoadedLayers[gridId].insert(0);
        }
        return true;
    }

    return false;
}

void Map::EnsureGridLayerLoaded(Cell const& cell, uint32 layerId)
{
    if (!layerId)
        return;

    if (!_mapGridManager.IsGridLoaded(cell.GridX(), cell.GridY()))
        return;

    uint32 gridId = GridCoord(cell.GridX(), cell.GridY()).GetId();
    {
        std::lock_guard<std::mutex> guard(_gridLayerLock);
        auto& loadedLayers = _gridLoadedLayers[gridId];
        if (loadedLayers.find(layerId) != loadedLayers.end())
            return;
        loadedLayers.insert(layerId);
    }

    auto gridObjectLock = AcquireGridObjectWriteLock();
    std::lock_guard<std::recursive_mutex> guard(_mapGridManager._gridLock);
    MapGridType* grid = _mapGridManager.GetGrid(cell.GridX(), cell.GridY());
    if (!grid)
        return;

    GridObjectLoader loader(*grid, this);
    loader.LoadLayerClones(layerId);
}

void Map::ClearLoadedLayer(uint32 layerId)
{
    if (!layerId)
        return;

    std::lock_guard<std::mutex> guard(_gridLayerLock);
    for (auto& [_, loadedLayers] : _gridLoadedLayers)
        loadedLayers.erase(layerId);
}

void Map::MarkGridLayerLoaded(uint16 gridX, uint16 gridY, uint32 layerId)
{
    if (!layerId)
        return;

    uint32 gridId = GridCoord(gridX, gridY).GetId();
    std::lock_guard<std::mutex> guard(_gridLayerLock);
    _gridLoadedLayers[gridId].insert(layerId);
}

MapGridType* Map::GetMapGrid(uint16 const x, uint16 const y)
{
    return _mapGridManager.GetGrid(x, y);
}

bool Map::IsGridLoaded(GridCoord const& gridCoord) const
{
    return _mapGridManager.IsGridLoaded(gridCoord.x_coord, gridCoord.y_coord);
}

bool Map::IsGridCreated(GridCoord const& gridCoord) const
{
    return _mapGridManager.IsGridCreated(gridCoord.x_coord, gridCoord.y_coord);
}

void Map::LoadGrid(float x, float y)
{
    EnsureGridLoaded(Cell(x, y));
}

void Map::LoadAllGrids()
{
    for (uint32 cellX = 0; cellX < TOTAL_NUMBER_OF_CELLS_PER_MAP; cellX++)
        for (uint32 cellY = 0; cellY < TOTAL_NUMBER_OF_CELLS_PER_MAP; cellY++)
            LoadGrid((cellX + 0.5f - CENTER_GRID_CELL_ID) * SIZE_OF_GRID_CELL, (cellY + 0.5f - CENTER_GRID_CELL_ID) * SIZE_OF_GRID_CELL);
}

void Map::LoadGridsInRange(Position const& center, float radius)
{
    if (_mapGridManager.IsGridsFullyLoaded())
        return;

    QueueGridPreloadInRange(center, radius);

    float const x = center.GetPositionX();
    float const y = center.GetPositionY();

    CellCoord cellCoord(Acore::ComputeCellCoord(x, y));
    if (!cellCoord.IsCoordValid())
        return;

    if (radius > SIZE_OF_GRIDS)
        radius = SIZE_OF_GRIDS;

    CellArea area = Cell::CalculateCellArea(x, y, radius);
    if (!area)
        return;

    for (uint32 x = area.low_bound.x_coord; x <= area.high_bound.x_coord; ++x)
    {
        for (uint32 y = area.low_bound.y_coord; y <= area.high_bound.y_coord; ++y)
        {
            CellCoord cellCoord(x, y);
            Cell cell(cellCoord);
            EnsureGridLoaded(cell);
        }
    }
}

void Map::QueueGridPreloadInRange(Position const& center, float radius)
{
    if (_mapGridManager.IsGridsFullyLoaded())
        return;

    float const x = center.GetPositionX();
    float const y = center.GetPositionY();

    CellCoord cellCoord(Acore::ComputeCellCoord(x, y));
    if (!cellCoord.IsCoordValid())
        return;

    if (radius > SIZE_OF_GRIDS)
        radius = SIZE_OF_GRIDS;

    CellArea area = Cell::CalculateCellArea(x, y, radius);
    if (!area)
        return;

    std::unordered_set<uint32> gridIds;
    for (uint32 cellX = area.low_bound.x_coord; cellX <= area.high_bound.x_coord; ++cellX)
    {
        for (uint32 cellY = area.low_bound.y_coord; cellY <= area.high_bound.y_coord; ++cellY)
        {
            CellCoord coord(cellX, cellY);
            Cell cell(coord);
            gridIds.insert(GridCoord(cell.GridX(), cell.GridY()).GetId());
        }
    }

    std::vector<uint32> gridIdList;
    gridIdList.reserve(gridIds.size());
    for (uint32 gridId : gridIds)
        gridIdList.push_back(gridId);

    if (MapUpdater* updater = sMapMgr->GetMapUpdater(); updater && updater->activated())
        updater->schedule_grid_object_preload(*this, gridIdList);
    else
        for (uint32 gridId : gridIdList)
            PreloadGridObjectGuids(gridId);
}

void Map::PreloadGridObjectGuids(uint32 gridId)
{
    // Quick check under lock — if already preloaded, nothing to do
    {
        std::lock_guard<std::mutex> guard(_preloadedGridGuidsLock);
        if (_preloadedGridGuids.find(gridId) != _preloadedGridGuids.end())
            return;
    }

    // Expensive ObjectMgr query OUTSIDE the lock to avoid blocking the main thread
    // (GetPreloadedGridObjectGuids acquires the same mutex and is called from the world update loop)
    CellObjectGuids cellGuids = sObjectMgr->GetGridObjectGuids(GetId(), GetSpawnMode(), gridId);

    // Re-acquire lock and store — double-check in case another thread preloaded concurrently
    {
        std::lock_guard<std::mutex> guard(_preloadedGridGuidsLock);
        if (_preloadedGridGuids.find(gridId) == _preloadedGridGuids.end())
            _preloadedGridGuids.emplace(gridId, std::make_shared<CellObjectGuids>(std::move(cellGuids)));
    }
}

std::shared_ptr<CellObjectGuids> Map::GetPreloadedGridObjectGuids(uint32 gridId) const
{
    std::lock_guard<std::mutex> guard(_preloadedGridGuidsLock);
    auto it = _preloadedGridGuids.find(gridId);
    if (it != _preloadedGridGuids.end())
        return it->second;
    return {};
}

void Map::ClearPreloadedGridObjectGuids(uint32 gridId)
{
    std::lock_guard<std::mutex> guard(_preloadedGridGuidsLock);
    _preloadedGridGuids.erase(gridId);
}

void Map::LoadLayerClonesInRange(Player* player, float radius)
{
    if (!player || !sLayerMgr->IsLayeringEnabled())
        return;

    uint32 layerId = sLayerMgr->GetPlayerLayer(GetId(), player->GetGUID());
    if (!layerId)
        return;

    float const x = player->GetPositionX();
    float const y = player->GetPositionY();
    CellCoord cellCoord(Acore::ComputeCellCoord(x, y));
    if (!cellCoord.IsCoordValid())
        return;

    if (radius > SIZE_OF_GRIDS)
        radius = SIZE_OF_GRIDS;

    CellArea area = Cell::CalculateCellArea(x, y, radius);
    if (!area)
        return;

    for (uint32 cellX = area.low_bound.x_coord; cellX <= area.high_bound.x_coord; ++cellX)
    {
        for (uint32 cellY = area.low_bound.y_coord; cellY <= area.high_bound.y_coord; ++cellY)
        {
            CellCoord coord(cellX, cellY);
            Cell cell(coord);
            EnsureGridLayerLoaded(cell, layerId);
        }
    }
}

bool Map::AddPlayerToMap(Player* player)
{
    if (!player)
    {
        LOG_ERROR("maps", "Map::AddPlayerToMap called with null player!");
        return false;
    }

    CellCoord cellCoord = Acore::ComputeCellCoord(player->GetPositionX(), player->GetPositionY());
    if (!cellCoord.IsCoordValid())
    {
        LOG_ERROR("maps", "Map::Add: Player ({}) has invalid coordinates X:{} Y:{} grid cell [{}:{}]",
            player->GetGUID().ToString(), player->GetPositionX(), player->GetPositionY(), cellCoord.x_coord, cellCoord.y_coord);
        return false;
    }

    Cell cell(cellCoord);
    LoadGridsInRange(*player, MAX_VISIBILITY_DISTANCE);

    // Defensive: verify grid loading didn't invalidate our state
    if (!player->GetMap() || player->GetMap() != this)
    {
        LOG_ERROR("maps", "Map::AddPlayerToMap: player {} map changed during grid loading (expected map {})",
            player->GetGUID().ToString(), GetId());
        return false;
    }

    AddToGrid(player, cell);

    // Check if we are adding to correct map
    ASSERT (player->GetMap() == this);
    player->SetMap(this);
    player->AddToWorld();

    SendInitTransports(player);
    SendInitSelf(player);

    player->UpdateObjectVisibility(false);

    if (sLayerMgr->IsLayeringEnabled() && GetInstanceId() == 0)
    {
        // Process any pending soft transfer before auto-assignment
        // (this fires on loading screen transitions — teleport, map change)
        if (sLayerMgr->HasPendingSoftTransfer(player->GetGUID()))
            sLayerMgr->ProcessSoftTransferForPlayer(player->GetGUID());

        sLayerMgr->AutoAssignPlayerToLayer(GetId(), player->GetGUID());
        LoadLayerClonesInRange(player, MAX_VISIBILITY_DISTANCE);
    }

    if (player->IsAlive())
        ConvertCorpseToBones(player->GetGUID());

    sScriptMgr->OnPlayerEnterMap(this, player);
    return true;
}

template<class T>
void Map::InitializeObject(T* /*obj*/)
{
}

template<>
void Map::InitializeObject(Creature*  /*obj*/)
{
    //obj->_moveState = MAP_OBJECT_CELL_MOVE_NONE;
}

template<>
void Map::InitializeObject(GameObject*  /*obj*/)
{
    //obj->_moveState = MAP_OBJECT_CELL_MOVE_NONE;
}

template<class T>
bool Map::AddToMap(T* obj, bool checkTransport)
{
    //TODO: Needs clean up. An object should not be added to map twice.
    if (obj->IsInWorld())
    {
        ASSERT(obj->IsInGrid());
        obj->UpdateObjectVisibilityOnCreate();
        return true;
    }

    CellCoord cellCoord = Acore::ComputeCellCoord(obj->GetPositionX(), obj->GetPositionY());
    //It will create many problems (including crashes) if an object is not added to grid after creation
    //The correct way to fix it is to make AddToMap return false and delete the object if it is not added to grid
    //But now AddToMap is used in too many places, I will just see how many ASSERT failures it will cause
    ASSERT(cellCoord.IsCoordValid());
    if (!cellCoord.IsCoordValid())
    {
        LOG_ERROR("maps", "Map::AddToMap: Object {} has invalid coordinates X:{} Y:{} grid cell [{}:{}]",
            obj->GetGUID().ToString(), obj->GetPositionX(), obj->GetPositionY(), cellCoord.x_coord, cellCoord.y_coord);
        return false; //Should delete object
    }

    Cell cell(cellCoord);
    if (obj->isActiveObject())
        EnsureGridLoaded(cell);
    else
        EnsureGridCreated(GridCoord(cell.GridX(), cell.GridY()));

    AddToGrid(obj, cell);

    //Must already be set before AddToMap. Usually during obj->Create.
    //obj->SetMap(this);
    obj->AddToWorld();

    if (checkTransport)
        if (!(obj->IsGameObject() && obj->ToGameObject()->IsTransport())) // dont add transport to transport ;d
            if (Transport* transport = GetTransportForPos(obj->GetPhaseMask(), obj->GetPositionX(), obj->GetPositionY(), obj->GetPositionZ(), obj))
                transport->AddPassenger(obj, true);

    InitializeObject(obj);

    //something, such as vehicle, needs to be update immediately
    //also, trigger needs to cast spell, if not update, cannot see visual
    obj->UpdateObjectVisibility(true);

    // Xinef: little hack for vehicles, accessories have to be added after visibility update so they wont fall off the vehicle, moved from Creature::AIM_Initialize
    // Initialize vehicle, this is done only for summoned npcs, DB creatures are handled by grid loaders
    if (obj->IsCreature())
        if (Vehicle* vehicle = obj->ToCreature()->GetVehicleKit())
            vehicle->Reset();
    return true;
}

template<>
bool Map::AddToMap(Transport* obj, bool /*checkTransport*/)
{
    //TODO: Needs clean up. An object should not be added to map twice.
    if (obj->IsInWorld())
        return true;

    CellCoord cellCoord = Acore::ComputeCellCoord(obj->GetPositionX(), obj->GetPositionY());
    if (!cellCoord.IsCoordValid())
    {
        LOG_ERROR("maps", "Map::Add: Object {} has invalid coordinates X:{} Y:{} grid cell [{}:{}]",
            obj->GetGUID().ToString(), obj->GetPositionX(), obj->GetPositionY(), cellCoord.x_coord, cellCoord.y_coord);
        return false; //Should delete object
    }

    Cell cell(cellCoord);
    EnsureGridLoaded(cell);

    obj->AddToWorld();

    _transports.insert(obj);

    // Broadcast creation to players
    for (Map::PlayerList::const_iterator itr = GetPlayers().begin(); itr != GetPlayers().end(); ++itr)
    {
        if (itr->GetSource()->GetTransport() != obj)
        {
            UpdateData data;
            obj->BuildCreateUpdateBlockForPlayer(&data, itr->GetSource());
            WorldPacket packet;
            data.BuildPacket(packet);
            itr->GetSource()->SendDirectMessage(&packet);
        }
    }

    return true;
}

void Map::MarkNearbyCellsOf(WorldObject* obj)
{
    // Check for valid position
    if (!obj->IsPositionValid())
        return;

    // Update mobs/objects in ALL visible cells around object!
    CellArea area = Cell::CalculateCellArea(obj->GetPositionX(), obj->GetPositionY(), obj->GetGridActivationRange());
    for (uint32 x = area.low_bound.x_coord; x <= area.high_bound.x_coord; ++x)
    {
        for (uint32 y = area.low_bound.y_coord; y <= area.high_bound.y_coord; ++y)
        {
            // marked cells are those that have been visited
            uint32 cell_id = (y * TOTAL_NUMBER_OF_CELLS_PER_MAP) + x;
            markCell(cell_id);
        }
    }
}

void Map::UpdatePlayerZoneStats(uint32 oldZone, uint32 newZone)
{
    // Nothing to do if no change
    if (oldZone == newZone)
        return;

    std::lock_guard<std::mutex> lock(_zonePlayerCountLock);

    if (oldZone != MAP_INVALID_ZONE)
    {
        uint32& oldZoneCount = _zonePlayerCountMap[oldZone];
        if (oldZoneCount)
            --oldZoneCount;
    }

    if (newZone != MAP_INVALID_ZONE)
        ++_zonePlayerCountMap[newZone];
}

uint32 Map::GetPartitionIdForUnit(Unit const* unit) const
{
    if (!unit)
        return 0;

    return sPartitionMgr->GetPartitionIdForPosition(GetId(), unit->GetPositionX(), unit->GetPositionY(), unit->GetZoneId(), unit->GetGUID());
}

bool Map::TryGetRelayTargetPartition(Unit const* unit, uint32& relayPartitionId) const
{
    relayPartitionId = 0;
    if (!unit || !_isPartitioned)
        return false;

    uint32 const activePartition = GetActivePartitionContext();
    if (!activePartition || IsProcessingPartitionRelays())
        return false;

    // If this unit is currently being updated by the active partition's worker,
    // allow all MotionMaster calls to execute directly even when the unit's
    // position-based partition has changed (e.g. after crossing a boundary
    // during UpdateSplineMovement within the same tick).
    if (unit->GetCurrentUpdatePartition() == activePartition)
        return false;

    uint32 const ownerPartition = GetPartitionIdForUnit(unit);
    if (!ownerPartition || ownerPartition == activePartition)
        return false;

    relayPartitionId = ownerPartition;
    return true;
}

void Map::VisitAllObjectStores(std::function<void(MapStoredObjectTypesContainer&)> const& visitor)
{
    if (!visitor)
        return;

    if (!_isPartitioned)
    {
        std::shared_lock<std::shared_mutex> storeLock(_objectsStoreLock);
        visitor(_objectsStore);
        return;
    }

    // When using partition stores, only visit partition stores to avoid double-processing objects
    if (sPartitionMgr->UsePartitionStoreOnly() || !_partitionedObjectsStore.empty())
    {
        std::shared_lock<std::shared_mutex> storeLock(_partitionedObjectStoreLock);
        for (auto& pair : _partitionedObjectsStore)
            visitor(pair.second);
    }
    else
    {
        std::shared_lock<std::shared_mutex> storeLock(_objectsStoreLock);
        visitor(_objectsStore);
    }
}

Unit* Map::GetUnitByGuid(ObjectGuid const& guid) const
{
    if (!guid)
        return nullptr;

    if (guid.IsPlayer())
        return ObjectAccessor::GetPlayer(this, guid);

    if (guid.IsPet())
        return GetPet(guid);

    if (guid.IsCreatureOrVehicle())
        return GetCreature(guid);

    return nullptr;
}

std::vector<Creature*> Map::GetCreaturesBySpawnId(ObjectGuid::LowType spawnId) const
{
    std::vector<Creature*> creatures;
    std::shared_lock<std::shared_mutex> lock(_spawnIdStoreLock);
    auto bounds = _creatureBySpawnIdStore.equal_range(spawnId);
    for (auto itr = bounds.first; itr != bounds.second; ++itr)
        creatures.push_back(itr->second);
    return creatures;
}

std::vector<std::pair<ObjectGuid::LowType, Creature*>> Map::GetCreatureBySpawnIdStoreSnapshot() const
{
    std::vector<std::pair<ObjectGuid::LowType, Creature*>> snapshot;
    std::shared_lock<std::shared_mutex> lock(_spawnIdStoreLock);
    snapshot.reserve(_creatureBySpawnIdStore.size());
    for (auto const& entry : _creatureBySpawnIdStore)
        snapshot.push_back(entry);
    return snapshot;
}

void Map::AddCreatureToSpawnIdStore(ObjectGuid::LowType spawnId, Creature* creature)
{
    std::unique_lock<std::shared_mutex> lock(_spawnIdStoreLock);
    _creatureBySpawnIdStore.insert(std::make_pair(spawnId, creature));
}

void Map::RemoveCreatureFromSpawnIdStore(ObjectGuid::LowType spawnId, Creature* creature)
{
    std::unique_lock<std::shared_mutex> lock(_spawnIdStoreLock);
    auto bounds = _creatureBySpawnIdStore.equal_range(spawnId);
    for (auto itr = bounds.first; itr != bounds.second; ++itr)
    {
        if (itr->second == creature)
        {
            _creatureBySpawnIdStore.erase(itr);
            break;
        }
    }
}

std::vector<GameObject*> Map::GetGameObjectsBySpawnId(ObjectGuid::LowType spawnId) const
{
    std::vector<GameObject*> gameObjects;
    std::shared_lock<std::shared_mutex> lock(_spawnIdStoreLock);
    auto bounds = _gameobjectBySpawnIdStore.equal_range(spawnId);
    for (auto itr = bounds.first; itr != bounds.second; ++itr)
        gameObjects.push_back(itr->second);
    return gameObjects;
}

std::vector<std::pair<ObjectGuid::LowType, GameObject*>> Map::GetGameObjectBySpawnIdStoreSnapshot() const
{
    std::vector<std::pair<ObjectGuid::LowType, GameObject*>> snapshot;
    std::shared_lock<std::shared_mutex> lock(_spawnIdStoreLock);
    snapshot.reserve(_gameobjectBySpawnIdStore.size());
    for (auto const& entry : _gameobjectBySpawnIdStore)
        snapshot.push_back(entry);
    return snapshot;
}

void Map::AddGameObjectToSpawnIdStore(ObjectGuid::LowType spawnId, GameObject* gameObject)
{
    std::unique_lock<std::shared_mutex> lock(_spawnIdStoreLock);
    _gameobjectBySpawnIdStore.insert(std::make_pair(spawnId, gameObject));
}

void Map::RemoveGameObjectFromSpawnIdStore(ObjectGuid::LowType spawnId, GameObject* gameObject)
{
    std::unique_lock<std::shared_mutex> lock(_spawnIdStoreLock);
    auto bounds = _gameobjectBySpawnIdStore.equal_range(spawnId);
    for (auto itr = bounds.first; itr != bounds.second; ++itr)
    {
        if (itr->second == gameObject)
        {
            _gameobjectBySpawnIdStore.erase(itr);
            break;
        }
    }
}

void Map::Update(const uint32 t_diff, const uint32 s_diff, bool  /*thread*/)
{
    ++_updateCounter;

    // Phase timing for diagnostics — only evaluated when the tick ends slow.
    auto const _phaseStart = std::chrono::steady_clock::now();
    auto _phaseLast = _phaseStart;
    int64 _phSessions = 0, _phDynTree = 0, _phPartitions = 0, _phLegacyPlayers = 0;
    int64 _phNpcUpdate = 0, _phRelocate = 0, _phVisibility = 0, _phSendObj = 0;
    int64 _phScripts = 0, _phMoveList = 0, _phDelayedVis = 0, _phWeather = 0;
    auto _phaseSnap = [&](int64& target) {
        auto now = std::chrono::steady_clock::now();
        target = std::chrono::duration_cast<std::chrono::milliseconds>(now - _phaseLast).count();
        _phaseLast = now;
    };

    // Adaptive main-thread budgets for heavy load handling.
    // NOTE: In-flight limit controls how many partitions run concurrently.
    // Being too aggressive here starves parallelism and creates a negative
    // feedback loop (throttle -> work piles up -> higher diff -> more throttle).
    // With 16 threads and 12 partitions per continent, setting in-flight to 2
    // wastes most threads. Keep in-flight high enough that the thread pool stays
    // saturated even under pressure.
    if (t_diff >= 200)
    {
        _adaptiveSessionStrideTicks = 4;
        _adaptiveDeferredVisibilityBudget = 256;
        _adaptiveObjectUpdateBudget = 384;
        _adaptivePartitionInFlightLimit = 3;
    }
    else if (t_diff >= 120)
    {
        _adaptiveSessionStrideTicks = 3;
        _adaptiveDeferredVisibilityBudget = 384;
        _adaptiveObjectUpdateBudget = 768;
        _adaptivePartitionInFlightLimit = 4;
    }
    else if (t_diff <= 35)
    {
        _adaptiveSessionStrideTicks = 1;
        _adaptiveDeferredVisibilityBudget = 1024;
        _adaptiveObjectUpdateBudget = 3072;
        _adaptivePartitionInFlightLimit = 6;
    }
    else
    {
        _adaptiveSessionStrideTicks = 2;
        _adaptiveDeferredVisibilityBudget = 512;
        _adaptiveObjectUpdateBudget = 1536;
        _adaptivePartitionInFlightLimit = 5;
    }
    if (_isPartitioned && !_useParallelPartitions && !_partitionLogShown)
    {
        _partitionLogShown = true;
        LOG_WARN("map.partition", "Map {} is marked partitioned but uses legacy update routing (set UseParallelPartitions for threaded updates)", GetId());
    }

    if (_isPartitioned && t_diff)
    {
        // Instances share MapID but not partition state. Only base map (Id 0) should drive partition updates.
        if (GetInstanceId() == 0)
        {
            sPartitionMgr->UpdatePartitionsForMap(GetId(), t_diff);
            sLayerMgr->Update(GetId(), t_diff);
        }
    }

    if (t_diff)
    {
        constexpr uint32 kDynamicTreeUpdateStrideTicks = 3;
        constexpr uint32 kDynamicTreeMaxDeferredDiffMs = 100;
        _pendingDynamicTreeDiff += t_diff;

        if ((_updateCounter.load(std::memory_order_relaxed) % kDynamicTreeUpdateStrideTicks) == 0 ||
            _pendingDynamicTreeDiff >= kDynamicTreeMaxDeferredDiffMs)
        {
            std::unique_lock<std::shared_mutex> lock(_dynamicTreeLock);
            _dynamicTree.update(_pendingDynamicTreeDiff);
            _pendingDynamicTreeDiff = 0;
        }
    }
    _phaseSnap(_phDynTree);

    uint32 sessionIndex = 0;

    // Update world sessions and players
    for (m_mapRefIter = m_mapRefMgr.begin(); m_mapRefIter != m_mapRefMgr.end(); ++m_mapRefIter)
    {
        Player* player = m_mapRefIter->GetSource();
        if (player && player->IsInWorld())
        {
            // Always update session on main thread to reduce worker-thread contention.
            WorldSession* session = player->GetSession();
            bool doSessionUpdate = ((_updateCounter.load(std::memory_order_relaxed) + sessionIndex) % _adaptiveSessionStrideTicks) == 0;
            if (player->IsInCombat() || player->isMoving())
                doSessionUpdate = true;

            if (session && doSessionUpdate)
            {
                MapSessionFilter updater(session);
                session->Update(s_diff, updater);
            }

            ++sessionIndex;

            // update players at tick
            if (!t_diff && player->IsInWorld())
                player->Update(s_diff);
        }
    }

    Events.Update(t_diff);
    _phaseSnap(_phSessions);

    if (!t_diff)
    {
        HandleDelayedVisibility();
        return;
    }

    _updatableObjectListRecheckTimer.Update(t_diff);
    resetMarkedCells();

    bool useParallelPartitions = _isPartitioned && _useParallelPartitions;
    bool markNearbyCells = _updatableObjectListRecheckTimer.Passed();
    if (useParallelPartitions)
    {
        _markNearbyCellsThisTick.store(markNearbyCells, std::memory_order_relaxed);
        if (markNearbyCells)
            _updatableObjectListRecheckTimer.Reset();
    }
    else
    {
        _markNearbyCellsThisTick.store(false, std::memory_order_relaxed);
    }

    if (_isPartitioned)
    {
        if (useParallelPartitions)
        {
            // Parallel partitioned path: workers handle both player and NPC updates
            bool partitionCycleFinished = SchedulePartitionUpdates(t_diff, s_diff);
            MapUpdater* updater = sMapMgr->GetMapUpdater();

            if (!partitionCycleFinished && updater && updater->activated())
            {
                while (!partitionCycleFinished)
                {
                    uint32 const scheduledSnapshot = _partitionUpdatesScheduled;
                    updater->run_partition_tasks_until([this, scheduledSnapshot]()
                    {
                        return !_partitionUpdatesInProgress || _partitionUpdatesCompleted.load(std::memory_order_acquire) >= scheduledSnapshot;
                    });

                    partitionCycleFinished = SchedulePartitionUpdates(t_diff, s_diff);
                }
            }

            if (partitionCycleFinished)
            {
                _markNearbyCellsThisTick.store(false, std::memory_order_relaxed);

                // Deferred updates must run on the main thread after all
                // workers complete so they don't race with CollectPartitionedUpdatableGuids.
                ApplyQueuedPartitionedOwnershipUpdates();
                ApplyQueuedPartitionedRemovals();
            }
            _phaseSnap(_phPartitions);
        }
        else
        {
            // Serial partitioned path
            uint32 partitionCount = sPartitionMgr->GetPartitionCount(GetId());
            if (partitionCount == 0)
                partitionCount = 1;

            std::vector<std::vector<Player*>> partitionBuckets;
            uint32 totalPlayersChecked = 0;
            uint32 totalPlayersSkipped = 0;

            partitionBuckets.resize(partitionCount);

            for (m_mapRefIter = m_mapRefMgr.begin(); m_mapRefIter != m_mapRefMgr.end(); ++m_mapRefIter)
            {
                Player* player = m_mapRefIter->GetSource();
                ++totalPlayersChecked;
                if (!player || !player->IsInWorld())
                {
                    ++totalPlayersSkipped;
                    if (player)
                    {
                        LOG_ERROR("maps.partition", "Map::Update (Partitioned) - Skipping player {} ({}) because IsInWorld() = false, map: {}",
                            player->GetName(), player->GetGUID().ToString(), GetId());
                    }
                    continue;
                }

                uint32 zoneId = player->GetZoneId();
                uint32 partitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), player->GetPositionX(), player->GetPositionY(), zoneId, player->GetGUID());
                uint32 index = partitionId > 0 ? partitionId - 1 : 0;
                if (index >= partitionCount)
                    index = partitionCount - 1;
                partitionBuckets[index].push_back(player);
            }

            if (totalPlayersSkipped > 0)
            {
                LOG_ERROR("maps.partition", "Map::Update (Partitioned) - Map {} skipped {} out of {} players due to IsInWorld() check",
                    GetId(), totalPlayersSkipped, totalPlayersChecked);
            }

            SetPartitionPlayerBuckets(partitionBuckets);

            // Helper lambda to safely get queue size without auto-inserting empty vectors via operator[]
            auto safeQueueSize = [](auto const& map, uint32 id) -> uint64 {
                auto it = map.find(id);
                return it != map.end() ? uint64(it->second.size()) : 0;
            };

            for (uint32 partitionId = 1; partitionId <= partitionCount; ++partitionId)
            {
                METRIC_VALUE("partition_relay_queue_threat", safeQueueSize(_partitionThreatRelays, partitionId),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                METRIC_VALUE("partition_relay_queue_threat_action", safeQueueSize(_partitionThreatActionRelays, partitionId),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                METRIC_VALUE("partition_relay_queue_threat_target", safeQueueSize(_partitionThreatTargetActionRelays, partitionId),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                METRIC_VALUE("partition_relay_queue_taunt", safeQueueSize(_partitionTauntRelays, partitionId),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                METRIC_VALUE("partition_relay_queue_proc", safeQueueSize(_partitionProcRelays, partitionId),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                METRIC_VALUE("partition_relay_queue_aura", safeQueueSize(_partitionAuraRelays, partitionId),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                METRIC_VALUE("partition_relay_queue_path", safeQueueSize(_partitionPathRelays, partitionId),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                METRIC_VALUE("partition_relay_queue_point", safeQueueSize(_partitionPointRelays, partitionId),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                METRIC_VALUE("partition_relay_queue_assist", safeQueueSize(_partitionAssistRelays, partitionId),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                METRIC_VALUE("partition_relay_queue_assist_distract", safeQueueSize(_partitionAssistDistractRelays, partitionId),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                SetActivePartitionContext(partitionId);
                ProcessPartitionRelays(partitionId);
                auto& bucket = partitionBuckets[partitionId - 1];
                uint32 boundaryPlayers = 0;
                std::vector<PartitionManager::BoundaryPositionUpdate> boundaryUpdates;
                std::vector<ObjectGuid> boundaryUnregisters;
                std::vector<ObjectGuid> boundaryOverrides;
                boundaryUpdates.reserve(bucket.size());
                boundaryOverrides.reserve(bucket.size());
                for (Player* player : bucket)
                {
                    if (sPartitionMgr->IsNearPartitionBoundary(GetId(), player->GetPositionX(), player->GetPositionY()))
                    {
                        ++boundaryPlayers;
                        boundaryUpdates.push_back({player->GetGUID(), player->GetPositionX(), player->GetPositionY()});
                        boundaryOverrides.push_back(player->GetGUID());
                        if (!player->IsBoundaryTracked())
                            player->SetBoundaryTracked(true);
                    }
                    else
                    {
                        if (player->IsBoundaryTracked())
                        {
                            boundaryUnregisters.push_back(player->GetGUID());
                            player->SetBoundaryTracked(false);
                        }
                    }
                }
                if (!boundaryUpdates.empty())
                    sPartitionMgr->BatchUpdateBoundaryPositions(GetId(), partitionId, boundaryUpdates);
                if (!boundaryUnregisters.empty())
                    sPartitionMgr->BatchUnregisterBoundaryObjects(GetId(), partitionId, boundaryUnregisters);
                if (!boundaryOverrides.empty())
                    sPartitionMgr->BatchSetPartitionOverrides(boundaryOverrides, GetId(), partitionId, 500);
                sPartitionMgr->UpdatePartitionPlayerCount(GetId(), partitionId, static_cast<uint32>(bucket.size()));
                sPartitionMgr->UpdatePartitionBoundaryCount(GetId(), partitionId, boundaryPlayers);

                uint32 playerUpdateDiff = s_diff ? s_diff : t_diff;
                for (Player* player : bucket)
                {
                    if (!player->IsInWorld())
                        continue;

                    player->Update(playerUpdateDiff);

                    if (_updatableObjectListRecheckTimer.Passed())
                    {
                        MarkNearbyCellsOf(player);

                        // If player is using far sight, update viewpoint
                        if (WorldObject* viewPoint = player->GetViewpoint())
                        {
                            if (Creature* viewCreature = viewPoint->ToCreature())
                                MarkNearbyCellsOf(viewCreature);
                            else if (DynamicObject* viewObject = viewPoint->ToDynObject())
                                MarkNearbyCellsOf(viewObject);
                        }
                    }
                }
            }
            SetActivePartitionContext(0);

            // Serial partitioned NPC update + cleanup
            UpdateNonPlayerObjects(t_diff);
            ClearPartitionPlayerBuckets();

            // Flush deferred partition modifications — serial path must flush
            // like the parallel path to prevent stale entries and dangling
            // pointers accumulating in _partitionedUpdatableIndex.
            ApplyQueuedPartitionedOwnershipUpdates();
            ApplyQueuedPartitionedRemovals();
            _phaseSnap(_phPartitions);
            _phaseSnap(_phNpcUpdate); // included in partitions for serial path
        }
    }
    else
    {
        SetActivePartitionContext(0);
        // Update players (legacy path)
        for (m_mapRefIter = m_mapRefMgr.begin(); m_mapRefIter != m_mapRefMgr.end(); ++m_mapRefIter)
        {
            Player* player = m_mapRefIter->GetSource();

            if (!player || !player->IsInWorld())
                continue;

            player->Update(t_diff);

            if (_updatableObjectListRecheckTimer.Passed())
            {
                MarkNearbyCellsOf(player);

                // If player is using far sight, update viewpoint
                if (WorldObject* viewPoint = player->GetViewpoint())
                {
                    if (Creature* viewCreature = viewPoint->ToCreature())
                        MarkNearbyCellsOf(viewCreature);
                    else if (DynamicObject* viewObject = viewPoint->ToDynObject())
                        MarkNearbyCellsOf(viewObject);
                }
            }
        }

        // Legacy non-partitioned NPC update
        UpdateNonPlayerObjects(t_diff);
        _phaseSnap(_phLegacyPlayers);
        _phaseSnap(_phNpcUpdate); // included above for legacy path
    }

    _phaseSnap(_phRelocate); // reset before post-partition phases
    _phaseLast = std::chrono::steady_clock::now(); // reset
    ProcessDeferredPlayerRelocations();
    _phaseSnap(_phRelocate);
    ProcessDeferredVisibilityUpdates();
    _phaseSnap(_phVisibility);
    SendObjectUpdates();
    _phaseSnap(_phSendObj);

    ///- Process necessary scripts
    if (!m_scriptSchedule.empty())
    {
        bool expected = false;
        if (i_scriptLock.compare_exchange_strong(expected, true))
        {
            auto scriptLockGuard = [this]() { i_scriptLock.store(false); };
            try
            {
                ScriptsProcess();
            }
            catch (...)
            {
                scriptLockGuard();
                throw;
            }
            scriptLockGuard();
        }
    }

    _phaseSnap(_phScripts);

    MoveAllCreaturesInMoveList();
    MoveAllGameObjectsInMoveList();
    MoveAllDynamicObjectsInMoveList();
    _phaseSnap(_phMoveList);

    HandleDelayedVisibility();
    _phaseSnap(_phDelayedVis);

    UpdateWeather(t_diff);
    UpdateExpiredCorpses(t_diff);

    sScriptMgr->OnMapUpdate(this, t_diff);
    _phaseSnap(_phWeather);

    // Emit phase breakdown when total map update exceeds threshold.
    // This gives visibility into WHERE the time is spent rather than just
    // knowing the total is slow.
    {
        int64 totalMs = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - _phaseStart).count();
        static uint32 sPhaseBreakdownThresholdMs = sConfigMgr->GetOption<uint32>("System.SlowMapUpdateTask.PhaseBreakdownMs", 100);
        if (totalMs >= sPhaseBreakdownThresholdMs)
        {
            LOG_WARN("map.update.slow",
                "Map update phase breakdown: map={} total={}ms "
                "dynTree={}ms sessions={}ms partitions={}ms npcUpdate={}ms "
                "relocate={}ms visibility={}ms sendObj={}ms scripts={}ms "
                "moveList={}ms delayedVis={}ms weather={}ms diff={} s_diff={}",
                GetId(), totalMs,
                _phDynTree, _phSessions, _phPartitions, _phNpcUpdate,
                _phRelocate, _phVisibility, _phSendObj, _phScripts,
                _phMoveList, _phDelayedVis, _phWeather, t_diff, s_diff);
        }
    }

    if (_isPartitioned && !useParallelPartitions)
    {
        uint32 partitionCount = sPartitionMgr->GetPartitionCount(GetId());
        if (partitionCount == 0)
            partitionCount = 1;

        for (uint32 partitionId = 1; partitionId <= partitionCount; ++partitionId)
        {
            PartitionManager::PartitionStats stats;
            if (sPartitionMgr->GetPartitionStats(GetId(), partitionId, stats))
            {
                METRIC_VALUE("partition_players", uint64(stats.players),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                METRIC_VALUE("partition_creatures", uint64(stats.creatures),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                METRIC_VALUE("partition_boundary_objects", uint64(stats.boundaryObjects),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
                METRIC_VALUE("partition_visibility_count", uint64(sPartitionMgr->GetVisibilityCount(GetId(), partitionId)),
                    METRIC_TAG("map_id", std::to_string(GetId())),
                    METRIC_TAG("partition_id", std::to_string(partitionId)));
            }
        }

    }

    if (_isPartitioned)
    {
        METRIC_VALUE("partition_combat_handoffs", uint64(sPartitionMgr->ConsumeCombatHandoffCount(GetId())),
            METRIC_TAG("map_id", std::to_string(GetId())));
        METRIC_VALUE("partition_path_handoffs", uint64(sPartitionMgr->ConsumePathHandoffCount(GetId())),
            METRIC_TAG("map_id", std::to_string(GetId())));
    }

    uint64 creatureCount = 0;
    uint64 gameObjectCount = 0;
    if (_isPartitioned && sPartitionMgr->UsePartitionStoreOnly())
    {
        std::shared_lock<std::shared_mutex> storeLock(_partitionedObjectStoreLock);
        for (auto const& pair : _partitionedObjectsStore)
        {
            creatureCount += pair.second.Size<Creature>();
            gameObjectCount += pair.second.Size<GameObject>();
        }
    }
    else
    {
        std::shared_lock<std::shared_mutex> storeLock(_objectsStoreLock);
        creatureCount = _objectsStore.Size<Creature>();
        gameObjectCount = _objectsStore.Size<GameObject>();
    }

    METRIC_VALUE("map_creatures", creatureCount,
        METRIC_TAG("map_id", std::to_string(GetId())),
        METRIC_TAG("map_instanceid", std::to_string(GetInstanceId())));

    METRIC_VALUE("map_gameobjects", gameObjectCount,
        METRIC_TAG("map_id", std::to_string(GetId())),
        METRIC_TAG("map_instanceid", std::to_string(GetInstanceId())));
}

void Map::UpdateNonPlayerObjects(uint32 const diff)
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

    FlushPendingUpdateListAdds();

    bool recheck = _updatableObjectListRecheckTimer.Passed();

    if (_isPartitioned)
    {
        uint32 partitionCount = sPartitionMgr->GetPartitionCount(GetId());
        if (partitionCount == 0)
            partitionCount = 1;

        std::vector<uint32> partitionCreatureCounts(partitionCount, 0);
        std::vector<uint32> partitionBoundaryObjectCounts(partitionCount, 0);
        std::vector<PartitionManager::BoundaryPositionUpdate> boundaryUpdates;
        std::vector<ObjectGuid> boundaryUnregisters;
        std::vector<ObjectGuid> boundaryOverrides;
        std::vector<std::pair<ObjectGuid, uint8>> objects;

        for (uint32 partitionId = 1; partitionId <= partitionCount; ++partitionId)
        {
            SetActivePartitionContext(partitionId);
            uint32 index = partitionId - 1;
            boundaryUpdates.clear();
            boundaryUnregisters.clear();
            boundaryOverrides.clear();
            objects.clear();
            CollectPartitionedUpdatableGuids(partitionId, objects);
            if (objects.empty())
            {
                sPartitionMgr->UpdatePartitionCreatureCount(GetId(), partitionId, 0);
                sPartitionMgr->UpdatePartitionBoundaryCount(GetId(), partitionId, 0);
                continue;
            }

            boundaryUpdates.reserve(objects.size());
            boundaryUnregisters.reserve(objects.size());
            boundaryOverrides.reserve(objects.size());

            for (auto const& entry : objects)
            {
                WorldObject* obj = nullptr;
                switch (entry.second)
                {
                    case TYPEID_UNIT:
                        obj = GetCreature(entry.first);
                        break;
                    case TYPEID_GAMEOBJECT:
                        obj = GetGameObject(entry.first);
                        break;
                    case TYPEID_DYNAMICOBJECT:
                        obj = GetDynamicObject(entry.first);
                        break;
                    case TYPEID_CORPSE:
                        obj = GetCorpse(entry.first);
                        break;
                    default:
                        break;
                }

                if (!obj || !obj->IsInWorld())
                    continue;

                if (obj->ToCreature())
                    ++partitionCreatureCounts[index];

                if (sPartitionMgr->IsNearPartitionBoundary(GetId(), obj->GetPositionX(), obj->GetPositionY()))
                {
                    ++partitionBoundaryObjectCounts[index];
                    boundaryUpdates.push_back({obj->GetGUID(), obj->GetPositionX(), obj->GetPositionY()});
                    boundaryOverrides.push_back(obj->GetGUID());
                    if (!obj->IsBoundaryTracked())
                        obj->SetBoundaryTracked(true);
                }
                else
                {
                    if (obj->IsBoundaryTracked())
                    {
                        boundaryUnregisters.push_back(obj->GetGUID());
                        obj->SetBoundaryTracked(false);
                    }
                }

                if (!obj->IsInWorld())
                    continue;

                if (Creature* creature = obj->ToCreature(); creature && creature->IsDuringRemoveFromWorld())
                    continue;

                UpdatableMapObject* updatableObject = obj->AsUpdatableMapObject();
                if (updatableObject && !TryBeginUpdateExecutionIfSupported(updatableObject, 0))
                    continue;
                UpdateExecutionGuard updateGuard(updatableObject);

                Unit* unit = obj->ToUnit();
                if (unit)
                    unit->SetCurrentUpdatePartition(partitionId);

                obj->Update(diff);

                if (unit)
                    unit->SetCurrentUpdatePartition(0);

                if (!obj->IsUpdateNeeded())
                    RemoveObjectFromMapUpdateList(obj);
            }

            if (!boundaryUpdates.empty())
                sPartitionMgr->BatchUpdateBoundaryPositions(GetId(), partitionId, boundaryUpdates);
            if (!boundaryUnregisters.empty())
                sPartitionMgr->BatchUnregisterBoundaryObjects(GetId(), partitionId, boundaryUnregisters);
            if (!boundaryOverrides.empty())
                sPartitionMgr->BatchSetPartitionOverrides(boundaryOverrides, GetId(), partitionId, 500);

            sPartitionMgr->UpdatePartitionCreatureCount(GetId(), partitionId, partitionCreatureCounts[index]);
            PartitionManager::PartitionStats stats;
            uint32 boundaryTotal = partitionBoundaryObjectCounts[index];
            if (sPartitionMgr->GetPartitionStats(GetId(), partitionId, stats))
                boundaryTotal += stats.boundaryObjects;
            sPartitionMgr->UpdatePartitionBoundaryCount(GetId(), partitionId, boundaryTotal);
        }

        SetActivePartitionContext(0);

        if (recheck)
        {
            for (uint32 i = 0;;)
            {
                WorldObject* obj = nullptr;
                {
                    std::lock_guard<std::mutex> lock(_updatableObjectListLock);
                    if (i >= _updatableObjectList.size())
                        break;
                    obj = _updatableObjectList[i];
                }
                if (!obj->IsInWorld())
                {
                    RemoveObjectFromMapUpdateList(obj);
                    continue;
                }

                if (!obj->IsUpdateNeeded())
                {
                    RemoveObjectFromMapUpdateList(obj);
                }
                else
                {
                    ++i;
                }
            }
            _updatableObjectListRecheckTimer.Reset();
        }

        return;
    }

    if (recheck)
    {
        for (uint32 i = 0;;)
        {
            WorldObject* obj = nullptr;
            {
                std::lock_guard<std::mutex> lock(_updatableObjectListLock);
                if (i >= _updatableObjectList.size())
                    break;
                obj = _updatableObjectList[i];
            }
            if (!obj->IsInWorld())
            {
                ++i;
                continue;
            }

            if (Creature* creature = obj->ToCreature(); creature && creature->IsDuringRemoveFromWorld())
            {
                ++i;
                continue;
            }

            UpdatableMapObject* updatableObject = obj->AsUpdatableMapObject();
            if (updatableObject && !TryBeginUpdateExecutionIfSupported(updatableObject, 0))
            {
                ++i;
                continue;
            }
            UpdateExecutionGuard updateGuard(updatableObject);

            obj->Update(diff);

            if (!obj->IsUpdateNeeded())
            {
                    RemoveObjectFromMapUpdateList(obj);
                // Intentional no iteration here, obj is swapped with last element in
                // _updatableObjectList so next loop will update that object at the same index
            }
            else
                ++i;
        }
        _updatableObjectListRecheckTimer.Reset();
    }
    else
    {
        for (uint32 i = 0;; ++i)
        {
            WorldObject* obj = nullptr;
            {
                std::lock_guard<std::mutex> lock(_updatableObjectListLock);
                if (i >= _updatableObjectList.size())
                    break;
                obj = _updatableObjectList[i];
            }
            if (!obj->IsInWorld())
                continue;

            if (Creature* creature = obj->ToCreature(); creature && creature->IsDuringRemoveFromWorld())
                continue;

            UpdatableMapObject* updatableObject = obj->AsUpdatableMapObject();
            if (updatableObject && !TryBeginUpdateExecutionIfSupported(updatableObject, 0))
                continue;
            UpdateExecutionGuard updateGuard(updatableObject);

            obj->Update(diff);
        }
    }

    // NOTE: Taunt relays are now processed in ProcessPartitionRelays() where they belong.
    // The previous code here was dead (unreachable when _isPartitioned was true due to early return above).
}

void Map::AddObjectToPendingUpdateList(WorldObject* obj)
{
    if (!obj->CanBeAddedToMapUpdateList())
        return;

    UpdatableMapObject* mapUpdatableObject = obj->AsUpdatableMapObject();
    {
        std::lock_guard<std::mutex> lock(_pendingUpdateListLock);
        if (!mapUpdatableObject || mapUpdatableObject->GetUpdateState() != UpdatableMapObject::UpdateState::NotUpdating)
            return;
        mapUpdatableObject->SetUpdateState(UpdatableMapObject::UpdateState::PendingAdd);
        _pendingAddUpdatableObjectList.push_back(obj);
    }
}

void Map::FlushPendingUpdateListAdds()
{
    PendingAddUpdatableObjectList pending;
    {
        std::lock_guard<std::mutex> lock(_pendingUpdateListLock);
        if (_pendingAddUpdatableObjectList.empty())
            return;
        pending.swap(_pendingAddUpdatableObjectList);
    }

    for (WorldObject* obj : pending)
    {
        UpdatableMapObject* mapUpdatableObject = obj->AsUpdatableMapObject();
        if (!mapUpdatableObject || mapUpdatableObject->GetUpdateState() != UpdatableMapObject::UpdateState::PendingAdd)
            continue;
        _AddObjectToUpdateList(obj);
    }
}

// Internal use only
void Map::_AddObjectToUpdateList(WorldObject* obj)
{
    UpdatableMapObject* mapUpdatableObject = obj->AsUpdatableMapObject();
    ASSERT(mapUpdatableObject && mapUpdatableObject->GetUpdateState() == UpdatableMapObject::UpdateState::PendingAdd);

    std::lock_guard<std::mutex> lock(_updatableObjectListLock);
    mapUpdatableObject->SetUpdateState(UpdatableMapObject::UpdateState::Updating);
    mapUpdatableObject->SetMapUpdateListOffset(_updatableObjectList.size());
    _updatableObjectList.push_back(obj);
    AddToPartitionedUpdateList(obj);
}

// Internal use only
void Map::_RemoveObjectFromUpdateList(WorldObject* obj)
{
    UpdatableMapObject* mapUpdatableObject = obj->AsUpdatableMapObject();
    if (!mapUpdatableObject)
        return;

    {
        std::lock_guard<std::mutex> lock(_updatableObjectListLock);

        // Re-check state under lock — another partition worker may have already removed this object.
        if (mapUpdatableObject->GetUpdateState() != UpdatableMapObject::UpdateState::Updating)
            return;

        if (obj != _updatableObjectList.back())
        {
            UpdatableMapObject* backObj = _updatableObjectList.back()->AsUpdatableMapObject();
            if (backObj && backObj->GetUpdateState() == UpdatableMapObject::UpdateState::Updating)
                backObj->SetMapUpdateListOffset(mapUpdatableObject->GetMapUpdateListOffset());
            std::swap(_updatableObjectList[mapUpdatableObject->GetMapUpdateListOffset()], _updatableObjectList.back());
        }

        _updatableObjectList.pop_back();
        mapUpdatableObject->SetUpdateState(UpdatableMapObject::UpdateState::NotUpdating);
    }
    RemoveFromPartitionedUpdateList(obj);
}

void Map::AddToPartitionedUpdateList(WorldObject* obj)
{
    if (!_isPartitioned || !obj)
        return;

    auto lock = AcquirePartitionedUpdateListWriteLock();

    if (!IsHashContainerSane(_partitionedUpdatableIndex,
            "_partitionedUpdatableIndex (Add)", GetId()))
    {
        SwapAndLeakCorrupted(_partitionedUpdatableIndex,
            "_partitionedUpdatableIndex (Add)", GetId());
        return;
    }

    // Idempotent add: object may be re-added in the same tick while a
    // deferred removal is still queued. If it's already tracked, just refresh
    // ownership metadata instead of appending a duplicate list entry.
    if (_partitionedUpdatableIndex.find(obj) != _partitionedUpdatableIndex.end())
    {
        UpdatePartitionedOwnershipNoLock(obj);
        return;
    }

    // Defensive cleanup for stale entries with the same logical identity.
    // This path runs on every add; avoid O(n) GUID scans when the index is
    // large and rely on deferred removals/integrity rebuild paths instead.
    if (_partitionedUpdatableIndex.size() <= kGuidCleanupScanIndexLimit)
        RemoveFromPartitionedUpdateListByGuidNoLock(obj->GetGUID(), obj->GetTypeId(), 1);

    uint32 zoneId = GetZoneId(obj->GetPhaseMask(), obj->GetPositionX(), obj->GetPositionY(), obj->GetPositionZ());
    uint32 partitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), obj->GetPositionX(), obj->GetPositionY(), zoneId, obj->GetGUID());
    auto& list = _partitionedUpdatableObjectLists[partitionId];
    list.push_back(obj);
    PartitionedUpdatableEntry entry;
    entry.partitionId = partitionId;
    entry.index = list.size() - 1;
    entry.guid = obj->GetGUID();
    entry.typeId = obj->GetTypeId();
    _partitionedUpdatableIndex[obj] = entry;
}

void Map::RemoveFromPartitionedUpdateList(WorldObject* obj)
{
    if (!_isPartitioned || !obj)
        return;

    // Defer removal when called from partition workers to prevent concurrent
    // writes to _partitionedUpdatableIndex (same pattern as UpdatePartitionedOwnership).
    if (GetActivePartitionContext() != 0)
    {
        QueuePartitionedUpdateListRemoval(obj);
        return;
    }

    auto lock = AcquirePartitionedUpdateListWriteLock();
    RemoveFromPartitionedUpdateListNoLock(obj);
}

void Map::RemoveFromPartitionedUpdateListNoLock(WorldObject* obj)
{
    if (!IsHashContainerSane(_partitionedUpdatableIndex,
            "_partitionedUpdatableIndex (RemoveNoLock)", GetId()))
    {
        SwapAndLeakCorrupted(_partitionedUpdatableIndex,
            "_partitionedUpdatableIndex (RemoveNoLock)", GetId());
        return;
    }

    auto it = _partitionedUpdatableIndex.find(obj);
    if (it == _partitionedUpdatableIndex.end())
    {
        RemoveFromPartitionedUpdateListByGuidNoLock(obj->GetGUID(), obj->GetTypeId(), 1);
        return;
    }

    uint32 partitionId = it->second.partitionId;
    size_t index = it->second.index;

    auto removeByPointerFromList = [this, obj](UpdatableObjectList& list) -> bool
    {
        for (size_t i = 0; i < list.size(); ++i)
        {
            if (list[i] != obj)
                continue;

            if (i < list.size() - 1)
            {
                WorldObject* swapped = list.back();
                list[i] = swapped;
                auto swappedIt = _partitionedUpdatableIndex.find(swapped);
                if (swappedIt != _partitionedUpdatableIndex.end())
                    swappedIt->second.index = i;
            }

            list.pop_back();
            return true;
        }

        return false;
    };

    if (!IsHashContainerSane(_partitionedUpdatableObjectLists,
            "_partitionedUpdatableObjectLists (RemoveNoLock)", GetId()))
    {
        _partitionedUpdatableIndex.erase(it);
        return;
    }

    auto listIt = _partitionedUpdatableObjectLists.find(partitionId);
    if (listIt == _partitionedUpdatableObjectLists.end())
    {
        _partitionedUpdatableIndex.erase(it);
        return;
    }

    auto& list = listIt->second;
    if (list.empty() || index >= list.size())
    {
        if (!list.empty())
            removeByPointerFromList(list);
        _partitionedUpdatableIndex.erase(it);
        return;
    }

    if (list[index] != obj)
    {
        removeByPointerFromList(list);
        _partitionedUpdatableIndex.erase(it);
        return;
    }

    if (index < list.size() - 1)
    {
        WorldObject* swapped = list.back();
        list[index] = swapped;
        auto swappedIt = _partitionedUpdatableIndex.find(swapped);
        if (swappedIt != _partitionedUpdatableIndex.end())
            swappedIt->second.index = index;
    }
    list.pop_back();
    _partitionedUpdatableIndex.erase(it);
}

void Map::RemoveFromPartitionedUpdateListByGuidNoLock(ObjectGuid const& guid, TypeID typeId, size_t maxRemovals)
{
    if (!guid)
        return;

    if (!IsHashContainerSane(_partitionedUpdatableIndex,
            "_partitionedUpdatableIndex (RemoveByGuidNoLock)", GetId()))
    {
        SwapAndLeakCorrupted(_partitionedUpdatableIndex,
            "_partitionedUpdatableIndex (RemoveByGuidNoLock)", GetId());
        return;
    }

    // Bound cleanup work per call to avoid pathological hangs when the index
    // is partially corrupted but still passes the shallow sanity check.
    if (maxRemovals == 0)
        return;
    if (maxRemovals > _partitionedUpdatableIndex.size())
        maxRemovals = _partitionedUpdatableIndex.size();

    while (maxRemovals-- > 0)
    {
        auto it = _partitionedUpdatableIndex.end();
        for (auto itr = _partitionedUpdatableIndex.begin(); itr != _partitionedUpdatableIndex.end(); ++itr)
        {
            if (itr->second.guid != guid)
                continue;

            if (typeId != TYPEID_OBJECT && itr->second.typeId != typeId)
                continue;

            it = itr;
            break;
        }

        if (it == _partitionedUpdatableIndex.end())
            return;

        uint32 partitionId = it->second.partitionId;
        size_t index = it->second.index;

        if (!IsHashContainerSane(_partitionedUpdatableObjectLists,
                "_partitionedUpdatableObjectLists (RemoveByGuidNoLock)", GetId()))
        {
            _partitionedUpdatableIndex.erase(it);
            continue;
        }

        auto listIt = _partitionedUpdatableObjectLists.find(partitionId);
        if (listIt == _partitionedUpdatableObjectLists.end())
        {
            _partitionedUpdatableIndex.erase(it);
            continue;
        }

        auto& list = listIt->second;
        if (list.empty() || index >= list.size())
        {
            _partitionedUpdatableIndex.erase(it);
            continue;
        }

        if (index < list.size() - 1)
        {
            WorldObject* swapped = list.back();
            list[index] = swapped;
            auto swappedIt = _partitionedUpdatableIndex.find(swapped);
            if (swappedIt != _partitionedUpdatableIndex.end())
                swappedIt->second.index = index;
        }

        list.pop_back();
        _partitionedUpdatableIndex.erase(it);
    }

    // If we hit the cap, defer the rest to subsequent ticks instead of
    // monopolizing MapUpdater worker time.
}

void Map::QueuePartitionedUpdateListRemoval(WorldObject* obj)
{
    if (!obj)
        return;
    std::lock_guard<std::mutex> lock(_pendingPartitionRemovalLock);
    _pendingPartitionRemovals.push_back({obj->GetGUID(), obj->GetTypeId()});
}

void Map::ApplyQueuedPartitionedRemovals()
{
    std::vector<PendingPartitionRemovalUpdate> removals;
    {
        std::lock_guard<std::mutex> lock(_pendingPartitionRemovalLock);
        if (_pendingPartitionRemovals.empty())
            return;
        removals.swap(_pendingPartitionRemovals);
    }

    std::sort(removals.begin(), removals.end(), [](PendingPartitionRemovalUpdate const& lhs, PendingPartitionRemovalUpdate const& rhs)
    {
        if (lhs.guid.GetRawValue() != rhs.guid.GetRawValue())
            return lhs.guid.GetRawValue() < rhs.guid.GetRawValue();
        return static_cast<uint8>(lhs.typeId) < static_cast<uint8>(rhs.typeId);
    });
    removals.erase(std::unique(removals.begin(), removals.end(), [](PendingPartitionRemovalUpdate const& lhs, PendingPartitionRemovalUpdate const& rhs)
    {
        return lhs.guid == rhs.guid && lhs.typeId == rhs.typeId;
    }), removals.end());

    auto lock = AcquirePartitionedUpdateListWriteLock();

    // Integrity check: verify the index size matches the sum of all partition
    // lists.  A mismatch indicates stale entries or corruption; rebuild the
    // entire index from the authoritative partition lists.
    {
        size_t expectedSize = 0;
        for (auto const& p : _partitionedUpdatableObjectLists)
            expectedSize += p.second.size();

        if (_partitionedUpdatableIndex.size() != expectedSize)
        {
            LOG_ERROR("maps.partition", "Map {}: _partitionedUpdatableIndex corrupted "
                "(index size {} != list total {}).  Rebuilding index.",
                GetId(), _partitionedUpdatableIndex.size(), expectedSize);

            // Mismatch can come from logical drift (e.g. stale index entries),
            // not only heap corruption. Only swap-and-leak if sanity checks
            // fail; otherwise clear and rebuild normally to avoid unbounded
            // memory growth from leaking large maps repeatedly.
            if (IsHashContainerSane(_partitionedUpdatableIndex,
                    "_partitionedUpdatableIndex (ApplyQueuedPartitionedRemovals mismatch)", GetId()))
            {
                _partitionedUpdatableIndex.clear();
            }
            else
            {
                auto* leakedCorruptedMap = new std::decay_t<decltype(_partitionedUpdatableIndex)>();
                leakedCorruptedMap->swap(_partitionedUpdatableIndex);
                LOG_ERROR("maps.partition", "Map {}: Leaked corrupted index ({} entries) "
                    "to avoid allocator deadlock.", GetId(), leakedCorruptedMap->size());
            }

            _partitionedUpdatableObjectLists.clear();

            struct PartitionStoreCollector
            {
                Map& map;
                uint32 partitionId;
                UpdatableObjectList& list;

                void AddEntry(ObjectGuid const& guid, TypeID typeId, WorldObject* obj)
                {
                    if (!obj)
                        return;

                    PartitionedUpdatableEntry entry;
                    entry.partitionId = partitionId;
                    entry.index = list.size();
                    entry.guid = guid;
                    entry.typeId = static_cast<uint8>(typeId);

                    list.push_back(obj);
                    map._partitionedUpdatableIndex[obj] = entry;
                }

                void Visit(std::unordered_map<ObjectGuid, Creature*>& container)
                {
                    for (auto const& [guid, obj] : container)
                        AddEntry(guid, TYPEID_UNIT, obj);
                }

                void Visit(std::unordered_map<ObjectGuid, GameObject*>& container)
                {
                    for (auto const& [guid, obj] : container)
                        AddEntry(guid, TYPEID_GAMEOBJECT, obj);
                }

                void Visit(std::unordered_map<ObjectGuid, DynamicObject*>& container)
                {
                    for (auto const& [guid, obj] : container)
                        AddEntry(guid, TYPEID_DYNAMICOBJECT, obj);
                }

                void Visit(std::unordered_map<ObjectGuid, Corpse*>& container)
                {
                    for (auto const& [guid, obj] : container)
                        AddEntry(guid, TYPEID_CORPSE, obj);
                }
            };

            std::shared_lock<std::shared_mutex> storeLock(_partitionedObjectStoreLock);
            for (auto& [partitionId, store] : _partitionedObjectsStore)
            {
                auto& list = _partitionedUpdatableObjectLists[partitionId];
                PartitionStoreCollector collector{*this, partitionId, list};
                TypeContainerVisitor<PartitionStoreCollector, MapStoredObjectTypesContainer> visitor(collector);
                visitor.Visit(store);
            }
            // After rebuild, skip individual removals — objects that should be
            // removed were likely already absent from the authoritative lists.
            return;
        }
    }

    for (PendingPartitionRemovalUpdate const& removal : removals)
        RemoveFromPartitionedUpdateListByGuidNoLock(removal.guid, removal.typeId);
}

void Map::UpdatePartitionedOwnership(WorldObject* obj)
{
    if (!_isPartitioned || !obj)
        return;

    if (GetActivePartitionContext() != 0)
    {
        QueuePartitionedOwnershipUpdate(obj->GetGUID(), obj->GetTypeId());
        return;
    }

    auto lock = AcquirePartitionedUpdateListWriteLock();
    UpdatePartitionedOwnershipNoLock(obj);
}

void Map::UpdatePartitionedOwnershipNoLock(WorldObject* obj)
{
    if (!_isPartitioned || !obj)
        return;

    if (!IsHashContainerSane(_partitionedUpdatableIndex,
            "_partitionedUpdatableIndex (OwnershipNoLock)", GetId()))
    {
        SwapAndLeakCorrupted(_partitionedUpdatableIndex,
            "_partitionedUpdatableIndex (OwnershipNoLock)", GetId());
        return;
    }

    uint32 zoneId = GetZoneId(obj->GetPhaseMask(), obj->GetPositionX(), obj->GetPositionY(), obj->GetPositionZ());
    uint32 newPartitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), obj->GetPositionX(), obj->GetPositionY(), zoneId, obj->GetGUID());
    auto it = _partitionedUpdatableIndex.find(obj);
    if (it == _partitionedUpdatableIndex.end())
    {
        // Defensive cleanup for stale entries with reused guid/type before
        // inserting a fresh pointer mapping.
        if (_partitionedUpdatableIndex.size() <= kGuidCleanupScanIndexLimit)
            RemoveFromPartitionedUpdateListByGuidNoLock(obj->GetGUID(), obj->GetTypeId(), 1);

        auto& list = _partitionedUpdatableObjectLists[newPartitionId];
        list.push_back(obj);
        PartitionedUpdatableEntry entry;
        entry.partitionId = newPartitionId;
        entry.index = list.size() - 1;
        entry.guid = obj->GetGUID();
        entry.typeId = obj->GetTypeId();
        _partitionedUpdatableIndex[obj] = entry;
        return;
    }

    if (it->second.partitionId != newPartitionId)
    {
        uint32 oldPartitionId = it->second.partitionId;
        size_t index = it->second.index;
        auto listIt = _partitionedUpdatableObjectLists.find(oldPartitionId);
        bool removedOldEntry = false;

        auto removeByPointerFromList = [this, obj, &removedOldEntry](UpdatableObjectList& list)
        {
            for (size_t i = 0; i < list.size(); ++i)
            {
                if (list[i] != obj)
                    continue;

                if (i < list.size() - 1)
                {
                    WorldObject* swapped = list.back();
                    list[i] = swapped;
                    auto swappedIt = _partitionedUpdatableIndex.find(swapped);
                    if (swappedIt != _partitionedUpdatableIndex.end())
                        swappedIt->second.index = i;
                }

                list.pop_back();
                removedOldEntry = true;
                return;
            }
        };

        if (listIt != _partitionedUpdatableObjectLists.end())
        {
            auto& list = listIt->second;
            if (!list.empty() && index < list.size())
            {
                if (list[index] == obj)
                {
                    if (index < list.size() - 1)
                    {
                        WorldObject* swapped = list.back();
                        list[index] = swapped;
                        auto swappedIt = _partitionedUpdatableIndex.find(swapped);
                        if (swappedIt != _partitionedUpdatableIndex.end())
                            swappedIt->second.index = index;
                    }
                    list.pop_back();
                    removedOldEntry = true;
                }
            }

            if (!removedOldEntry)
                removeByPointerFromList(list);
        }

        auto& list = _partitionedUpdatableObjectLists[newPartitionId];
        list.push_back(obj);
        it->second.partitionId = newPartitionId;
        it->second.index = list.size() - 1;
    }

    UpdatePartitionedObjectStore(obj);
}


void Map::QueuePartitionedOwnershipUpdate(ObjectGuid const& guid, TypeID typeId)
{
    if (!guid)
        return;

    std::lock_guard<std::mutex> lock(_pendingPartitionOwnershipLock);
    _pendingPartitionOwnershipUpdates.push_back({guid, typeId});
}

void Map::ApplyQueuedPartitionedOwnershipUpdates()
{
    std::vector<PendingPartitionOwnershipUpdate> updates;
    {
        std::lock_guard<std::mutex> lock(_pendingPartitionOwnershipLock);
        if (_pendingPartitionOwnershipUpdates.empty())
            return;
        updates.swap(_pendingPartitionOwnershipUpdates);
    }

    std::sort(updates.begin(), updates.end(), [](PendingPartitionOwnershipUpdate const& lhs, PendingPartitionOwnershipUpdate const& rhs)
    {
        if (lhs.guid.GetRawValue() != rhs.guid.GetRawValue())
            return lhs.guid.GetRawValue() < rhs.guid.GetRawValue();
        return static_cast<uint8>(lhs.typeId) < static_cast<uint8>(rhs.typeId);
    });
    updates.erase(std::unique(updates.begin(), updates.end(), [](PendingPartitionOwnershipUpdate const& lhs, PendingPartitionOwnershipUpdate const& rhs)
    {
        return lhs.guid == rhs.guid && lhs.typeId == rhs.typeId;
    }), updates.end());

    auto lock = AcquirePartitionedUpdateListWriteLock();
    for (auto const& entry : updates)
    {
        WorldObject* obj = nullptr;
        switch (entry.typeId)
        {
            case TYPEID_PLAYER:
                obj = ObjectAccessor::GetPlayer(this, entry.guid);
                break;
            case TYPEID_UNIT:
                obj = GetCreature(entry.guid);
                break;
            case TYPEID_GAMEOBJECT:
                obj = GetGameObject(entry.guid);
                break;
            case TYPEID_DYNAMICOBJECT:
                obj = GetDynamicObject(entry.guid);
                break;
            case TYPEID_CORPSE:
                obj = GetCorpse(entry.guid);
                break;
            default:
                break;
        }

        if (!obj || !obj->IsInWorld())
            continue;

        UpdatePartitionedOwnershipNoLock(obj);
    }
}

void Map::CollectPartitionedUpdatableGuids(uint32 partitionId, std::vector<std::pair<ObjectGuid, uint8>>& out)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::shared_lock<std::shared_mutex> storeLock(_partitionedObjectStoreLock);

    if (!IsHashContainerSane(_partitionedObjectsStore,
            "_partitionedObjectsStore (CollectGuids)", GetId()))
        return;

    auto storeIt = _partitionedObjectsStore.find(partitionId);
    if (storeIt == _partitionedObjectsStore.end())
        return;

    struct GuidCollector
    {
        std::vector<std::pair<ObjectGuid, uint8>>& out;

        void Visit(std::unordered_map<ObjectGuid, Creature*>& container)
        {
            out.reserve(out.size() + container.size());
            for (auto const& [guid, obj] : container)
            {
                (void)obj;
                out.emplace_back(guid, TYPEID_UNIT);
            }
        }

        void Visit(std::unordered_map<ObjectGuid, GameObject*>& container)
        {
            out.reserve(out.size() + container.size());
            for (auto const& [guid, obj] : container)
            {
                (void)obj;
                out.emplace_back(guid, TYPEID_GAMEOBJECT);
            }
        }

        void Visit(std::unordered_map<ObjectGuid, DynamicObject*>& container)
        {
            out.reserve(out.size() + container.size());
            for (auto const& [guid, obj] : container)
            {
                (void)obj;
                out.emplace_back(guid, TYPEID_DYNAMICOBJECT);
            }
        }

        void Visit(std::unordered_map<ObjectGuid, Corpse*>& container)
        {
            out.reserve(out.size() + container.size());
            for (auto const& [guid, obj] : container)
            {
                (void)obj;
                out.emplace_back(guid, TYPEID_CORPSE);
            }
        }
    };

    GuidCollector collector{out};
    TypeContainerVisitor<GuidCollector, MapStoredObjectTypesContainer> visitor(collector);
    visitor.Visit(storeIt->second);
}

void Map::CollectPartitionedUpdatableObjects(uint32 partitionId, std::vector<WorldObject*>& out)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::shared_lock<std::shared_mutex> listLock(_partitionedUpdateListLock);

    if (!IsHashContainerSane(_partitionedUpdatableObjectLists,
            "_partitionedUpdatableObjectLists (CollectObjects)", GetId()))
        return;

    auto listIt = _partitionedUpdatableObjectLists.find(partitionId);
    if (listIt == _partitionedUpdatableObjectLists.end())
        return;

    auto& objectList = listIt->second;
    out.reserve(out.size() + objectList.size());
    for (WorldObject* obj : objectList)
    {
        if (obj && obj->IsInWorld())
            out.push_back(obj);
    }
}

void Map::RegisterPartitionedObject(WorldObject* obj)
{
    if (!_isPartitioned || !obj)
        return;

    ObjectGuid guid = obj->GetGUID();
    uint32 zoneId = GetZoneId(obj->GetPhaseMask(), obj->GetPositionX(), obj->GetPositionY(), obj->GetPositionZ());
    uint32 partitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), obj->GetPositionX(), obj->GetPositionY(), zoneId, obj->GetGUID());
    if (obj->IsPlayer())
    {
        uint32 persistedPartition = 0;
        if (!sPartitionMgr->IsZoneExcluded(zoneId) && sPartitionMgr->GetPersistentPartition(guid, GetId(), persistedPartition) && persistedPartition != 0)
            partitionId = persistedPartition;
    }

    uint32 partitionCount = sPartitionMgr->GetPartitionCount(GetId());
    if (partitionId == 0 || (partitionCount > 0 && partitionId > partitionCount))
    {
        LOG_ERROR("map.partition", "RegisterPartitionedObject: invalid partitionId {} (count {}) for guid {} map {} zone {}",
            partitionId, partitionCount, guid.ToString(), GetId(), zoneId);
        return;
    }

    {
        std::unique_lock<std::shared_mutex> lock(_partitionedObjectStoreLock);
        if (sPartitionMgr->IsRuntimeDiagnosticsEnabled())
            CheckPartitionStoreWriter(_partitionedObjectStoreWriter, GetId(), "RegisterPartitionedObject");

        if (!IsHashContainerSane(_partitionedObjectIndex,
                "_partitionedObjectIndex (RegisterPartitionedObject)", GetId()))
        {
            SwapAndLeakCorrupted(_partitionedObjectIndex,
                "_partitionedObjectIndex (RegisterPartitionedObject)", GetId());
            return;
        }

        if (!IsHashContainerSane(_partitionedObjectsStore,
                "_partitionedObjectsStore (RegisterPartitionedObject)", GetId()))
        {
            SwapAndLeakCorrupted(_partitionedObjectsStore,
                "_partitionedObjectsStore (RegisterPartitionedObject)", GetId());
            return;
        }

        _partitionedObjectIndex[guid] = partitionId;

        auto& store = _partitionedObjectsStore[partitionId];
        if (Creature* creature = obj->ToCreature())
            store.Insert<Creature>(guid, creature);
        else if (GameObject* go = obj->ToGameObject())
            store.Insert<GameObject>(guid, go);
        else if (DynamicObject* dynObj = obj->ToDynObject())
            store.Insert<DynamicObject>(guid, dynObj);
        else if (Corpse* corpse = obj->ToCorpse())
            store.Insert<Corpse>(guid, corpse);
    }

    sPartitionMgr->NotifyVisibilityAttach(guid, GetId(), partitionId);

    if (sLayerMgr->IsRuntimeDiagnosticsEnabled())
    {
        LOG_INFO("map.partition", "Diag: RegisterPartitionedObject guid={} type={} map={} zone={} partition={}",
            guid.ToString(), obj->GetTypeId(), GetId(), zoneId, partitionId);
    }

    if (obj->IsPlayer())
        sPartitionMgr->PersistPartitionOwnership(guid, GetId(), partitionId);
}

void Map::UnregisterPartitionedObject(WorldObject* obj)
{
    if (!_isPartitioned || !obj)
        return;

    ObjectGuid guid = obj->GetGUID();
    uint32 partitionId = 0;

    {
        std::unique_lock<std::shared_mutex> lock(_partitionedObjectStoreLock);
        if (sPartitionMgr->IsRuntimeDiagnosticsEnabled())
            CheckPartitionStoreWriter(_partitionedObjectStoreWriter, GetId(), "UnregisterPartitionedObject");

        if (!IsHashContainerSane(_partitionedObjectIndex,
                "_partitionedObjectIndex", GetId()))
        {
            SwapAndLeakCorrupted(_partitionedObjectIndex,
                "_partitionedObjectIndex (UnregisterPartitionedObject)", GetId());
            return;
        }

        auto it = _partitionedObjectIndex.find(guid);
        if (it == _partitionedObjectIndex.end())
            return;

        partitionId = it->second;

        if (!IsHashContainerSane(_partitionedObjectsStore,
                "_partitionedObjectsStore", GetId()))
        {
            SwapAndLeakCorrupted(_partitionedObjectsStore,
                "_partitionedObjectsStore (UnregisterPartitionedObject)", GetId());
            _partitionedObjectIndex.erase(it);
            return;
        }

        auto storeIt = _partitionedObjectsStore.find(partitionId);
        if (storeIt != _partitionedObjectsStore.end())
        {
            auto& store = storeIt->second;
            if (obj->ToCreature())
                store.Remove<Creature>(guid);
            else if (obj->ToGameObject())
                store.Remove<GameObject>(guid);
            else if (obj->ToDynObject())
                store.Remove<DynamicObject>(guid);
            else if (obj->ToCorpse())
                store.Remove<Corpse>(guid);
        }

        _partitionedObjectIndex.erase(it);
    }

    sPartitionMgr->UnregisterBoundaryObjectFromGrid(GetId(), partitionId, guid);
    obj->SetBoundaryTracked(false);
    sPartitionMgr->NotifyVisibilityDetach(guid, GetId(), partitionId);
}

void Map::UpdatePartitionedObjectStore(WorldObject* obj)
{
    if (!_isPartitioned || !obj)
        return;

    ObjectGuid guid = obj->GetGUID();
    uint32 zoneId = GetZoneId(obj->GetPhaseMask(), obj->GetPositionX(), obj->GetPositionY(), obj->GetPositionZ());
    uint32 newPartitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), obj->GetPositionX(), obj->GetPositionY(), zoneId, obj->GetGUID());

    {
        std::shared_lock<std::shared_mutex> lock(_partitionedObjectStoreLock);
        if (!IsHashContainerSane(_partitionedObjectIndex,
                "_partitionedObjectIndex (UpdatePartitionedObjectStore)", GetId()))
        {
            // Cannot swap-and-leak under shared_lock — just bail.
            // UnregisterPartitionedObject (unique_lock) will clean up later.
        }
        else
        {
            auto it = _partitionedObjectIndex.find(guid);
            if (it != _partitionedObjectIndex.end() && it->second == newPartitionId)
                return; // No partition change needed
        }
    }

    // Partition changed or object not registered — re-register
    UnregisterPartitionedObject(obj);
    RegisterPartitionedObject(obj);
    if (obj->IsPlayer())
        sPartitionMgr->PersistPartitionOwnership(guid, GetId(), newPartitionId);

    if (sLayerMgr->IsRuntimeDiagnosticsEnabled())
    {
        LOG_INFO("map.partition", "Diag: UpdatePartitionedObjectStore guid={} type={} map={} zone={} partition={}",
            guid.ToString(), obj->GetTypeId(), GetId(), zoneId, newPartitionId);
    }
}

void Map::RebuildPartitionedObjectAssignments()
{
    if (!_isPartitioned)
        return;

    std::vector<WorldObject*> rebuildSnapshot;

    struct PartitionRebuildCollector
    {
        std::vector<WorldObject*>& snapshot;
        explicit PartitionRebuildCollector(std::vector<WorldObject*>& snapshotRef) : snapshot(snapshotRef) { }

        void Visit(std::unordered_map<ObjectGuid, Creature*>& container)
        {
            for (auto& pair : container)
                if (pair.second && pair.second->IsInWorld())
                    snapshot.push_back(pair.second);
        }

        void Visit(std::unordered_map<ObjectGuid, GameObject*>& container)
        {
            for (auto& pair : container)
                if (pair.second && pair.second->IsInWorld())
                    snapshot.push_back(pair.second);
        }

        void Visit(std::unordered_map<ObjectGuid, DynamicObject*>& container)
        {
            for (auto& pair : container)
                if (pair.second && pair.second->IsInWorld())
                    snapshot.push_back(pair.second);
        }

        void Visit(std::unordered_map<ObjectGuid, Corpse*>& container)
        {
            for (auto& pair : container)
                if (pair.second && pair.second->IsInWorld())
                    snapshot.push_back(pair.second);
        }
    };

    PartitionRebuildCollector collector(rebuildSnapshot);
    TypeContainerVisitor<PartitionRebuildCollector, MapStoredObjectTypesContainer> visitor(collector);
    VisitAllObjectStores([&visitor](MapStoredObjectTypesContainer& store)
    {
        visitor.Visit(store);
    });

    {
        auto lock = AcquirePartitionedUpdateListWriteLock();

        if (!IsHashContainerSane(_partitionedUpdatableIndex,
                "_partitionedUpdatableIndex (RebuildPartitionedObjectAssignments)", GetId()))
        {
            SwapAndLeakCorrupted(_partitionedUpdatableIndex,
                "_partitionedUpdatableIndex (RebuildPartitionedObjectAssignments)", GetId());
        }

        if (!IsHashContainerSane(_partitionedUpdatableObjectLists,
                "_partitionedUpdatableObjectLists (RebuildPartitionedObjectAssignments)", GetId()))
        {
            SwapAndLeakCorrupted(_partitionedUpdatableObjectLists,
                "_partitionedUpdatableObjectLists (RebuildPartitionedObjectAssignments)", GetId());
        }

        _partitionedUpdatableObjectLists.clear();
        _partitionedUpdatableIndex.clear();
        _partitionedUpdatableIndex.reserve(rebuildSnapshot.size());

        for (WorldObject* obj : rebuildSnapshot)
        {
            if (!obj || !obj->IsInWorld())
                continue;

            uint32 zoneId = GetZoneId(obj->GetPhaseMask(), obj->GetPositionX(), obj->GetPositionY(), obj->GetPositionZ());
            uint32 partitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), obj->GetPositionX(), obj->GetPositionY(), zoneId, obj->GetGUID());

            auto& list = _partitionedUpdatableObjectLists[partitionId];
            PartitionedUpdatableEntry entry;
            entry.partitionId = partitionId;
            entry.index = list.size();
            entry.guid = obj->GetGUID();
            entry.typeId = obj->GetTypeId();

            list.push_back(obj);
            _partitionedUpdatableIndex[obj] = entry;
        }
    }

    for (WorldObject* obj : rebuildSnapshot)
        if (obj && obj->IsInWorld())
            UpdatePartitionedObjectStore(obj);

    for (MapRefMgr::iterator iter = m_mapRefMgr.begin(); iter != m_mapRefMgr.end(); ++iter)
    {
        Player* player = iter->GetSource();
        if (player && player->IsInWorld())
            UpdatePartitionedObjectStore(player);
    }
}

bool Map::ShouldDeferNonPlayerVisibility(WorldObject const* obj) const
{
    return obj && !obj->IsPlayer() && sNonPlayerVisibilityDeferDepth > 0;
}

void Map::PushDeferNonPlayerVisibility()
{
    ++sNonPlayerVisibilityDeferDepth;
}

void Map::PopDeferNonPlayerVisibility()
{
    if (sNonPlayerVisibilityDeferDepth > 0)
        --sNonPlayerVisibilityDeferDepth;
}

Map::VisibilityDeferGuard::VisibilityDeferGuard(Map& map)
    : _map(map), _active(true)
{
    _map.PushDeferNonPlayerVisibility();
}

Map::VisibilityDeferGuard::~VisibilityDeferGuard()
{
    if (_active)
        _map.PopDeferNonPlayerVisibility();
}

template<class T>
T* Map::FindPartitionedObject(ObjectGuid const& guid)
{
    if (!_isPartitioned)
        return nullptr;

    std::shared_lock<std::shared_mutex> lock(_partitionedObjectStoreLock);

    if (!IsHashContainerSane(_partitionedObjectsStore,
            "_partitionedObjectsStore", GetId()))
        return nullptr;

    // Hardening: avoid direct access to _partitionedObjectIndex here.
    // We observed crashes in unordered_map::find on that index under heavy load.
    // A bounded scan across per-partition stores is slower but safer.
    for (auto& [partitionId, store] : _partitionedObjectsStore)
    {
        (void)partitionId;
        if (T* object = store.Find<T>(guid))
            return object;
    }

    return nullptr;
}

void Map::RemoveObjectFromMapUpdateList(WorldObject* obj)
{
    if (!obj->CanBeAddedToMapUpdateList())
        return;

    UpdatableMapObject* mapUpdatableObject = obj->AsUpdatableMapObject();
    if (!mapUpdatableObject)
        return;

    // Check state under the appropriate lock to avoid TOCTOU races between partition workers.
    UpdatableMapObject::UpdateState state = mapUpdatableObject->GetUpdateState();
    if (state == UpdatableMapObject::UpdateState::PendingAdd)
    {
        std::lock_guard<std::mutex> lock(_pendingUpdateListLock);
        // Re-check under lock
        if (mapUpdatableObject->GetUpdateState() != UpdatableMapObject::UpdateState::PendingAdd)
            return;
        for (size_t i = 0; i < _pendingAddUpdatableObjectList.size(); ++i)
        {
            if (_pendingAddUpdatableObjectList[i] == obj)
            {
                _pendingAddUpdatableObjectList[i] = _pendingAddUpdatableObjectList.back();
                _pendingAddUpdatableObjectList.pop_back();
                break;
            }
        }
        mapUpdatableObject->SetUpdateState(UpdatableMapObject::UpdateState::NotUpdating);
    }
    else if (state == UpdatableMapObject::UpdateState::Updating)
        _RemoveObjectFromUpdateList(obj);
}

// Used in VisibilityDistanceType::Large and VisibilityDistanceType::Gigantic
void Map::AddWorldObjectToFarVisibleMap(WorldObject* obj)
{
    if (Creature* creature = obj->ToCreature())
    {
        if (!creature->IsInGrid())
            return;

        Cell curr_cell = creature->GetCurrentCell();
        MapGridType* grid = GetMapGrid(curr_cell.GridX(), curr_cell.GridY());
        if (!grid)
            return;
        grid->AddFarVisibleObject(curr_cell.CellX(), curr_cell.CellY(), creature);
    }
    else if (GameObject* go = obj->ToGameObject())
    {
        if (!go->IsInGrid())
            return;

        Cell curr_cell = go->GetCurrentCell();
        MapGridType* grid = GetMapGrid(curr_cell.GridX(), curr_cell.GridY());
        if (!grid)
            return;
        grid->AddFarVisibleObject(curr_cell.CellX(), curr_cell.CellY(), go);
    }
}

void Map::RemoveWorldObjectFromFarVisibleMap(WorldObject* obj)
{
    if (Creature* creature = obj->ToCreature())
    {
        Cell curr_cell = creature->GetCurrentCell();
        MapGridType* grid = GetMapGrid(curr_cell.GridX(), curr_cell.GridY());
        if (!grid)
            return;
        grid->RemoveFarVisibleObject(curr_cell.CellX(), curr_cell.CellY(), creature);
    }
    else if (GameObject* go = obj->ToGameObject())
    {
        Cell curr_cell = go->GetCurrentCell();
        MapGridType* grid = GetMapGrid(curr_cell.GridX(), curr_cell.GridY());
        if (!grid)
            return;
        grid->RemoveFarVisibleObject(curr_cell.CellX(), curr_cell.CellY(), go);
    }
}

// Used in VisibilityDistanceType::Infinite
void Map::AddWorldObjectToZoneWideVisibleMap(uint32 zoneId, WorldObject* obj)
{
    std::unique_lock<std::shared_mutex> lock(_zoneWideVisibleLock);
    _zoneWideVisibleWorldObjectsMap[zoneId].insert(obj);
}

void Map::RemoveWorldObjectFromZoneWideVisibleMap(uint32 zoneId, WorldObject* obj)
{
    std::unique_lock<std::shared_mutex> lock(_zoneWideVisibleLock);
    ZoneWideVisibleWorldObjectsMap::iterator itr = _zoneWideVisibleWorldObjectsMap.find(zoneId);
    if (itr == _zoneWideVisibleWorldObjectsMap.end())
        return;

    itr->second.erase(obj);
}

ZoneWideVisibleWorldObjectsSet const* Map::GetZoneWideVisibleWorldObjectsForZone(uint32 zoneId) const
{
    // NOTE: This returns a pointer to a thread-local copy. The pointer is only valid
    // until the next call to this function on the same thread. Prefer GetZoneWideVisibleWorldObjectsForZoneCopy().
    static thread_local ZoneWideVisibleWorldObjectsSet snapshot;
    std::shared_lock<std::shared_mutex> lock(_zoneWideVisibleLock);
    ZoneWideVisibleWorldObjectsMap::const_iterator itr = _zoneWideVisibleWorldObjectsMap.find(zoneId);
    if (itr == _zoneWideVisibleWorldObjectsMap.end())
    {
        snapshot.clear();
        return nullptr;
    }

    snapshot = itr->second;
    return &snapshot;
}

ZoneWideVisibleWorldObjectsSet Map::GetZoneWideVisibleWorldObjectsForZoneCopy(uint32 zoneId) const
{
    std::shared_lock<std::shared_mutex> lock(_zoneWideVisibleLock);
    auto itr = _zoneWideVisibleWorldObjectsMap.find(zoneId);
    if (itr == _zoneWideVisibleWorldObjectsMap.end())
        return {};

    return itr->second;
}

void Map::HandleDelayedVisibility()
{
    auto const slowLogStart = std::chrono::steady_clock::now();

    METRIC_TIMER("game_system_update_time",
        METRIC_TAG("system", "visibility"),
        METRIC_TAG("phase", "delayed"),
        METRIC_TAG("map_id", std::to_string(GetId())));

    // Extract objects under lock, then process outside lock
    std::vector<ObjectGuid> unitsToProcess;
    {
        std::lock_guard<std::mutex> lock(_delayedVisibilityLock);
        if (_objectsForDelayedVisibility.empty())
            return;
        unitsToProcess.swap(_objectsForDelayedVisibility);
    }

    if (unitsToProcess.size() > 1)
    {
        std::sort(unitsToProcess.begin(), unitsToProcess.end());
        unitsToProcess.erase(std::unique(unitsToProcess.begin(), unitsToProcess.end()), unitsToProcess.end());
    }

    // Budget-limit delayed visibility to prevent unbounded per-tick cost.
    // Each ExecuteDelayedUnitRelocationEvent does a full grid visit (expensive).
    static uint32 const kDelayedVisBudget = sConfigMgr->GetOption<uint32>("System.DelayedVisibility.BudgetPerTick", 256);
    if (unitsToProcess.size() > kDelayedVisBudget)
    {
        // Put excess back into the queue for next tick
        std::lock_guard<std::mutex> lock(_delayedVisibilityLock);
        _objectsForDelayedVisibility.insert(
            _objectsForDelayedVisibility.end(),
            unitsToProcess.begin() + kDelayedVisBudget,
            unitsToProcess.end());
        unitsToProcess.resize(kDelayedVisBudget);
    }

    char const* workloadBucket = "empty";
    if (!unitsToProcess.empty())
    {
        if (unitsToProcess.size() >= 512)
            workloadBucket = "huge";
        else if (unitsToProcess.size() >= 128)
            workloadBucket = "large";
        else if (unitsToProcess.size() >= 32)
            workloadBucket = "medium";
        else
            workloadBucket = "small";
    }

    METRIC_DETAILED_TIMER("slow_visibility_update_time",
        METRIC_TAG("phase", "delayed"),
        METRIC_TAG("map_id", std::to_string(GetId())),
        METRIC_TAG("workload", workloadBucket));

    METRIC_VALUE("game_system_batch_size", unitsToProcess.size(),
        METRIC_TAG("system", "visibility"),
        METRIC_TAG("phase", "delayed"),
        METRIC_TAG("map_id", std::to_string(GetId())));

    for (ObjectGuid const& guid : unitsToProcess)
    {
        Unit* unit = nullptr;
        if (guid.IsPlayer())
            unit = ObjectAccessor::GetPlayer(this, guid);
        else if (guid.IsPet())
            unit = GetPet(guid);
        else
            unit = GetCreature(guid);

        if (unit)
            unit->ExecuteDelayedUnitRelocationEvent();
    }

    // Slow log check AFTER the processing loop (grid visits are the expensive part)
    static bool const slowLogEnabled = sConfigMgr->GetOption<bool>("System.SlowLog.Enable", true);
    static int64 const slowVisibilityThresholdMs = sConfigMgr->GetOption<int64>("Metric.Threshold.slow_visibility_update_time", 6);
    if (slowLogEnabled)
    {
        int64 const elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - slowLogStart).count();
        if (elapsedMs >= slowVisibilityThresholdMs)
        {
            LOG_WARN("system.slow",
                "Slow delayed visibility update: map_id={} workload={} batch={} elapsed_ms={} threshold_ms={}",
                GetId(), workloadBucket, unitsToProcess.size(), elapsedMs, slowVisibilityThresholdMs);
        }
    }
}

struct ResetNotifier
{
    template<class T>inline void resetNotify(GridRefMgr<T>& m)
    {
        for (typename GridRefMgr<T>::iterator iter = m.begin(); iter != m.end(); ++iter)
            iter->GetSource()->ResetAllNotifies();
    }
    template<class T> void Visit(GridRefMgr<T>&) {}
    void Visit(CreatureMapType& m) { resetNotify<Creature>(m);}
    void Visit(PlayerMapType& m) { resetNotify<Player>(m);}
};

void Map::RemovePlayerFromMap(Player* player, bool remove)
{
    UpdatePlayerZoneStats(player->GetZoneId(), MAP_INVALID_ZONE);

    if (sLayerMgr->IsLayeringEnabled() && GetInstanceId() == 0)
        sLayerMgr->ForceRemovePlayerFromAllLayers(player->GetGUID());

    player->getHostileRefMgr().deleteReferences(true); // pussywizard: multithreading crashfix

    player->RemoveFromWorld();
    SendRemoveTransports(player);

    if (player->IsInGrid())
    {
        auto gridLock = AcquireGridObjectWriteLock();
        std::lock_guard<std::recursive_mutex> guard(_mapGridManager._gridLock);
        player->RemoveFromGrid();
    }
    else
        ASSERT(remove); //maybe deleted in logoutplayer when player is not in a map

    sScriptMgr->OnPlayerLeaveMap(this, player);
    if (remove)
    {
        DeleteFromWorld(player);
    }
}

void Map::AfterPlayerUnlinkFromMap()
{
}

template<class T>
void Map::RemoveFromMap(T* obj, bool remove)
{
    obj->RemoveFromWorld();

    RemoveObjectFromMapUpdateList(obj);

    {
        auto gridLock = AcquireGridObjectWriteLock();
        std::lock_guard<std::recursive_mutex> guard(_mapGridManager._gridLock);
        obj->RemoveFromGrid();
    }

    obj->ResetMap();

    if (remove)
    {
        DeleteFromWorld(obj);
    }
}

template<>
void Map::RemoveFromMap(Transport* obj, bool remove)
{
    obj->RemoveFromWorld();

    Map::PlayerList const& players = GetPlayers();
    if (!players.IsEmpty())
    {
        UpdateData data;
        obj->BuildOutOfRangeUpdateBlock(&data);
        WorldPacket packet;
        data.BuildPacket(packet);
        for (Map::PlayerList::const_iterator itr = players.begin(); itr != players.end(); ++itr)
            if (itr->GetSource()->GetTransport() != obj)
                itr->GetSource()->SendDirectMessage(&packet);
    }

    if (_transportsUpdateIter != _transports.end())
    {
        TransportsContainer::iterator itr = _transports.find(obj);
        if (itr == _transports.end())
            return;
        if (itr == _transportsUpdateIter)
            ++_transportsUpdateIter;
        _transports.erase(itr);
    }
    else
        _transports.erase(obj);

    obj->ResetMap();

    RemoveObjectFromMapUpdateList(obj);

    if (remove)
    {
        // if option set then object already saved at this moment
        if (!sWorld->getBoolConfig(CONFIG_SAVE_RESPAWN_TIME_IMMEDIATELY))
            obj->SaveRespawnTime();
        DeleteFromWorld(obj);
    }
}

void Map::PlayerRelocation(Player* player, float x, float y, float z, float o)
{
    uint32 oldPartitionId = 0;
    uint32 newPartitionId = 0;
    bool partitionChanged = false;

    // Skip expensive partition detection for transport passengers — they move with
    // the transport and don't independently cross partition boundaries.  This avoids
    // 2× GetZoneId (BIH ray-intersection) per passenger per tick.
    if (_isPartitioned && !player->GetTransport())
    {
        uint32 oldZoneId = GetZoneId(player->GetPhaseMask(), player->GetPositionX(), player->GetPositionY(), player->GetPositionZ());
        uint32 newZoneId = GetZoneId(player->GetPhaseMask(), x, y, z);
        oldPartitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), player->GetPositionX(), player->GetPositionY(), oldZoneId, player->GetGUID());
        newPartitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), x, y, newZoneId, player->GetGUID());
        partitionChanged = (oldPartitionId != newPartitionId);

        if (partitionChanged)
            sPartitionMgr->BeginRelocation(player->GetGUID(), GetId(), oldPartitionId, newPartitionId);
    }

    Cell old_cell(player->GetPositionX(), player->GetPositionY());
    Cell new_cell(x, y);

    if (GetActivePartitionContext() != 0 && old_cell.DiffGrid(new_cell) && player->GetSession() == nullptr && !player->IsInCombat())
    {
        GridCoord const targetGrid(new_cell.GridX(), new_cell.GridY());
        if (!IsGridLoaded(targetGrid))
        {
            if (MapUpdater* updater = sMapMgr->GetMapUpdater(); updater && updater->activated())
                updater->schedule_grid_object_preload(*this, std::vector<uint32>{ targetGrid.GetId() });

            QueueDeferredPlayerRelocation(player->GetGUID(), x, y, z, o);
            return;
        }
    }

    bool gridChanged = false;
    if (old_cell.DiffGrid(new_cell) || old_cell.DiffCell(new_cell))
    {
        {
            auto gridLock = AcquireGridObjectWriteLock();
            player->RemoveFromGrid();
        }

        if (old_cell.DiffGrid(new_cell))
        {
            EnsureGridLoaded(new_cell);
            gridChanged = true;
        }

        AddToGrid(player, new_cell);
    }

    player->Relocate(x, y, z, o);
    if (player->IsVehicle())
        player->GetVehicleKit()->RelocatePassengers();
    player->UpdatePositionData();
    player->UpdateObjectVisibility(false);

    if (gridChanged && GetActivePartitionContext() == 0)
        LoadLayerClonesInRange(player, MAX_VISIBILITY_DISTANCE);

    if (_isPartitioned && partitionChanged)
    {
        if (!player->IsInWorld())
        {
            sPartitionMgr->RollbackRelocation(player->GetGUID());
        }
        else
        {
            sPartitionMgr->CommitRelocation(player->GetGUID());
            sPartitionMgr->NotifyVisibilityDetach(player->GetGUID(), GetId(), oldPartitionId);
            sPartitionMgr->NotifyVisibilityAttach(player->GetGUID(), GetId(), newPartitionId);
            UpdatePartitionedOwnership(player);
            LOG_DEBUG("visibility.partition", "Player {} crossed partition {} -> {} on map {}", player->GetGUID().GetCounter(), oldPartitionId, newPartitionId, GetId());
            if (player->IsInCombat())
            {
                LOG_WARN("combat.partition", "Player {} crossed partition while in combat (handoff pending)", player->GetGUID().GetCounter());
                sPartitionMgr->RecordCombatHandoff(GetId());
                sPartitionMgr->SetPartitionOverride(player->GetGUID(), GetId(), newPartitionId, 2000);
                if (Unit* victim = player->GetVictim())
                    sPartitionMgr->SetPartitionOverride(victim->GetGUID(), GetId(), newPartitionId, 2000);
            }
        }
    }
}

void Map::CreatureRelocation(Creature* creature, float x, float y, float z, float o)
{
    uint32 oldPartitionId = 0;
    uint32 newPartitionId = 0;
    bool partitionChanged = false;

    // Skip expensive partition detection for transport passengers — they move with
    // the transport and don't independently cross partition boundaries.  This avoids
    // 2× GetZoneId (BIH ray-intersection) per passenger per tick.
    if (_isPartitioned && !creature->GetTransport())
    {
        uint32 oldZoneId = GetZoneId(creature->GetPhaseMask(), creature->GetPositionX(), creature->GetPositionY(), creature->GetPositionZ());
        uint32 newZoneId = GetZoneId(creature->GetPhaseMask(), x, y, z);
        oldPartitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), creature->GetPositionX(), creature->GetPositionY(), oldZoneId, creature->GetGUID());
        newPartitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), x, y, newZoneId, creature->GetGUID());
        partitionChanged = (oldPartitionId != newPartitionId);

        if (partitionChanged)
            sPartitionMgr->BeginRelocation(creature->GetGUID(), GetId(), oldPartitionId, newPartitionId);
    }

    Cell old_cell = creature->GetCurrentCell();
    Cell new_cell(x, y);

    if (old_cell.DiffGrid(new_cell) || old_cell.DiffCell(new_cell))
    {
        if (old_cell.DiffGrid(new_cell))
            EnsureGridLoaded(new_cell);

        AddCreatureToMoveList(creature);
    }
    else
        RemoveCreatureFromMoveList(creature);

    creature->Relocate(x, y, z, o);
    if (creature->IsVehicle())
        creature->GetVehicleKit()->RelocatePassengers();
    creature->UpdatePositionData();
    creature->UpdateObjectVisibility(false);

    if (_isPartitioned && partitionChanged)
    {
        if (!creature->IsInWorld())
        {
            sPartitionMgr->RollbackRelocation(creature->GetGUID());
        }
        else
        {
            sPartitionMgr->CommitRelocation(creature->GetGUID());
            sPartitionMgr->NotifyVisibilityDetach(creature->GetGUID(), GetId(), oldPartitionId);
            sPartitionMgr->NotifyVisibilityAttach(creature->GetGUID(), GetId(), newPartitionId);
            LOG_DEBUG("visibility.partition", "Creature {} crossed partition {} -> {} on map {}", creature->GetGUID().GetCounter(), oldPartitionId, newPartitionId, GetId());
            UpdatePartitionedOwnership(creature);
            if (creature->IsInCombat())
            {
                LOG_WARN("combat.partition", "Creature {} crossed partition while in combat (handoff pending)", creature->GetGUID().GetCounter());
                sPartitionMgr->RecordCombatHandoff(GetId());
                sPartitionMgr->SetPartitionOverride(creature->GetGUID(), GetId(), newPartitionId, 2000);
                if (Unit* victim = creature->GetVictim())
                {
                    sPartitionMgr->SetPartitionOverride(victim->GetGUID(), GetId(), newPartitionId, 2000);
                    QueuePartitionPathRelay(newPartitionId, creature->GetGUID(), victim->GetGUID());
                }
            }
            if (creature->GetMotionMaster())
            {
                LOG_DEBUG("path.partition", "Creature {} crossed partition; path handoff pending", creature->GetGUID().GetCounter());
                sPartitionMgr->RecordPathHandoff(GetId());
                sPartitionMgr->SetPartitionOverride(creature->GetGUID(), GetId(), newPartitionId, 1000);
            }
        }
    }
}

void Map::GameObjectRelocation(GameObject* go, float x, float y, float z, float o)
{
    uint32 oldPartitionId = 0;
    uint32 newPartitionId = 0;
    bool partitionChanged = false;

    // Skip expensive partition detection for transport passengers — they move with
    // the transport and don't independently cross partition boundaries.
    if (_isPartitioned && !go->GetTransport())
    {
        uint32 oldZoneId = GetZoneId(go->GetPhaseMask(), go->GetPositionX(), go->GetPositionY(), go->GetPositionZ());
        uint32 newZoneId = GetZoneId(go->GetPhaseMask(), x, y, z);
        oldPartitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), go->GetPositionX(), go->GetPositionY(), oldZoneId, go->GetGUID());
        newPartitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), x, y, newZoneId, go->GetGUID());
        partitionChanged = (oldPartitionId != newPartitionId);

        if (partitionChanged)
            sPartitionMgr->BeginRelocation(go->GetGUID(), GetId(), oldPartitionId, newPartitionId);
    }

    Cell old_cell = go->GetCurrentCell();
    Cell new_cell(x, y);

    if (old_cell.DiffGrid(new_cell) || old_cell.DiffCell(new_cell))
    {
        if (old_cell.DiffGrid(new_cell))
            EnsureGridLoaded(new_cell);

        AddGameObjectToMoveList(go);
    }
    else
        RemoveGameObjectFromMoveList(go);

    go->Relocate(x, y, z, o);
    go->UpdateModelPosition();
    go->SetPositionDataUpdate();
    go->UpdateObjectVisibility(false);

    if (_isPartitioned && partitionChanged)
    {
        if (!go->IsInWorld())
        {
            sPartitionMgr->RollbackRelocation(go->GetGUID());
        }
        else
        {
            sPartitionMgr->CommitRelocation(go->GetGUID());
            sPartitionMgr->NotifyVisibilityDetach(go->GetGUID(), GetId(), oldPartitionId);
            sPartitionMgr->NotifyVisibilityAttach(go->GetGUID(), GetId(), newPartitionId);
            LOG_DEBUG("visibility.partition", "GameObject {} crossed partition {} -> {} on map {}", go->GetGUID().GetCounter(), oldPartitionId, newPartitionId, GetId());
            UpdatePartitionedOwnership(go);
        }
    }
}

void Map::DynamicObjectRelocation(DynamicObject* dynObj, float x, float y, float z, float o)
{
    uint32 oldPartitionId = 0;
    uint32 newPartitionId = 0;
    bool partitionChanged = false;

    // Skip expensive partition detection for transport passengers.
    if (_isPartitioned && !dynObj->GetTransport())
    {
        uint32 oldZoneId = GetZoneId(dynObj->GetPhaseMask(), dynObj->GetPositionX(), dynObj->GetPositionY(), dynObj->GetPositionZ());
        uint32 newZoneId = GetZoneId(dynObj->GetPhaseMask(), x, y, z);
        oldPartitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), dynObj->GetPositionX(), dynObj->GetPositionY(), oldZoneId, dynObj->GetGUID());
        newPartitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), x, y, newZoneId, dynObj->GetGUID());
        partitionChanged = (oldPartitionId != newPartitionId);

        if (partitionChanged)
            sPartitionMgr->BeginRelocation(dynObj->GetGUID(), GetId(), oldPartitionId, newPartitionId);
    }

    Cell old_cell = dynObj->GetCurrentCell();
    Cell new_cell(x, y);

    if (old_cell.DiffGrid(new_cell) || old_cell.DiffCell(new_cell))
    {
        if (old_cell.DiffGrid(new_cell))
            EnsureGridLoaded(new_cell);

        AddDynamicObjectToMoveList(dynObj);
    }
    else
        RemoveDynamicObjectFromMoveList(dynObj);

    dynObj->Relocate(x, y, z, o);
    dynObj->SetPositionDataUpdate();
    dynObj->UpdateObjectVisibility(false);

    if (_isPartitioned && partitionChanged)
    {
        if (!dynObj->IsInWorld())
        {
            sPartitionMgr->RollbackRelocation(dynObj->GetGUID());
        }
        else
        {
            sPartitionMgr->CommitRelocation(dynObj->GetGUID());
            sPartitionMgr->NotifyVisibilityDetach(dynObj->GetGUID(), GetId(), oldPartitionId);
            sPartitionMgr->NotifyVisibilityAttach(dynObj->GetGUID(), GetId(), newPartitionId);
            LOG_DEBUG("visibility.partition", "DynamicObject {} crossed partition {} -> {} on map {}", dynObj->GetGUID().GetCounter(), oldPartitionId, newPartitionId, GetId());
            UpdatePartitionedOwnership(dynObj);
        }
    }
}

void Map::AddCreatureToMoveList(Creature* c)
{
    std::lock_guard<std::mutex> lock(_moveListLock);
    if (c->_moveState == MAP_OBJECT_CELL_MOVE_NONE)
        _creaturesToMove.push_back(c);
    c->_moveState = MAP_OBJECT_CELL_MOVE_ACTIVE;
}

void Map::RemoveCreatureFromMoveList(Creature* c)
{
    std::lock_guard<std::mutex> lock(_moveListLock);
    if (c->_moveState == MAP_OBJECT_CELL_MOVE_ACTIVE)
        c->_moveState = MAP_OBJECT_CELL_MOVE_INACTIVE;
}

void Map::AddGameObjectToMoveList(GameObject* go)
{
    std::lock_guard<std::mutex> lock(_moveListLock);
    if (go->_moveState == MAP_OBJECT_CELL_MOVE_NONE)
        _gameObjectsToMove.push_back(go);
    go->_moveState = MAP_OBJECT_CELL_MOVE_ACTIVE;
}

void Map::RemoveGameObjectFromMoveList(GameObject* go)
{
    std::lock_guard<std::mutex> lock(_moveListLock);
    if (go->_moveState == MAP_OBJECT_CELL_MOVE_ACTIVE)
        go->_moveState = MAP_OBJECT_CELL_MOVE_INACTIVE;
}

void Map::AddDynamicObjectToMoveList(DynamicObject* dynObj)
{
    std::lock_guard<std::mutex> lock(_moveListLock);
    if (dynObj->_moveState == MAP_OBJECT_CELL_MOVE_NONE)
        _dynamicObjectsToMove.push_back(dynObj);
    dynObj->_moveState = MAP_OBJECT_CELL_MOVE_ACTIVE;
}

void Map::RemoveDynamicObjectFromMoveList(DynamicObject* dynObj)
{
    std::lock_guard<std::mutex> lock(_moveListLock);
    if (dynObj->_moveState == MAP_OBJECT_CELL_MOVE_ACTIVE)
        dynObj->_moveState = MAP_OBJECT_CELL_MOVE_INACTIVE;
}

void Map::MoveAllCreaturesInMoveList()
{
    std::vector<Creature*> creaturesToMove;
    {
        std::lock_guard<std::mutex> lock(_moveListLock);
        creaturesToMove.swap(_creaturesToMove);
    }

    for (std::vector<Creature*>::iterator itr = creaturesToMove.begin(); itr != creaturesToMove.end(); ++itr)
    {
        Creature* c = *itr;
        if (c->FindMap() != this)
            continue;

        if (c->_moveState != MAP_OBJECT_CELL_MOVE_ACTIVE)
        {
            c->_moveState = MAP_OBJECT_CELL_MOVE_NONE;
            continue;
        }

        c->_moveState = MAP_OBJECT_CELL_MOVE_NONE;
        if (!c->IsInWorld())
            continue;

        Cell const& old_cell = c->GetCurrentCell();
        Cell new_cell(c->GetPositionX(), c->GetPositionY());
        if (c->IsFarVisible())
        {
            // Removes via GetCurrentCell, added back in AddToGrid
            RemoveWorldObjectFromFarVisibleMap(c);
        }

        {
            auto gridLock = AcquireGridObjectWriteLock();
            c->RemoveFromGrid();
        }
        if (old_cell.DiffGrid(new_cell))
            EnsureGridLoaded(new_cell);
        AddToGrid(c, new_cell);
    }
}

void Map::MoveAllGameObjectsInMoveList()
{
    std::vector<GameObject*> gameObjectsToMove;
    {
        std::lock_guard<std::mutex> lock(_moveListLock);
        gameObjectsToMove.swap(_gameObjectsToMove);
    }

    for (std::vector<GameObject*>::iterator itr = gameObjectsToMove.begin(); itr != gameObjectsToMove.end(); ++itr)
    {
        GameObject* go = *itr;
        if (go->FindMap() != this)
            continue;

        if (go->_moveState != MAP_OBJECT_CELL_MOVE_ACTIVE)
        {
            go->_moveState = MAP_OBJECT_CELL_MOVE_NONE;
            continue;
        }

        go->_moveState = MAP_OBJECT_CELL_MOVE_NONE;
        if (!go->IsInWorld())
            continue;

        Cell const& old_cell = go->GetCurrentCell();
        Cell new_cell(go->GetPositionX(), go->GetPositionY());

        if (go->IsFarVisible())
        {
            // Removes via GetCurrentCell, added back in AddToGrid
            RemoveWorldObjectFromFarVisibleMap(go);
        }

        {
            auto gridLock = AcquireGridObjectWriteLock();
            go->RemoveFromGrid();
        }
        if (old_cell.DiffGrid(new_cell))
            EnsureGridLoaded(new_cell);
        AddToGrid(go, new_cell);
    }
}

void Map::MoveAllDynamicObjectsInMoveList()
{
    std::vector<DynamicObject*> dynamicObjectsToMove;
    {
        std::lock_guard<std::mutex> lock(_moveListLock);
        dynamicObjectsToMove.swap(_dynamicObjectsToMove);
    }

    for (std::vector<DynamicObject*>::iterator itr = dynamicObjectsToMove.begin(); itr != dynamicObjectsToMove.end(); ++itr)
    {
        DynamicObject* dynObj = *itr;
        if (dynObj->FindMap() != this)
            continue;

        if (dynObj->_moveState != MAP_OBJECT_CELL_MOVE_ACTIVE)
        {
            dynObj->_moveState = MAP_OBJECT_CELL_MOVE_NONE;
            continue;
        }

        dynObj->_moveState = MAP_OBJECT_CELL_MOVE_NONE;
        if (!dynObj->IsInWorld())
            continue;

        Cell const& old_cell = dynObj->GetCurrentCell();
        Cell new_cell(dynObj->GetPositionX(), dynObj->GetPositionY());

        {
            auto gridLock = AcquireGridObjectWriteLock();
            dynObj->RemoveFromGrid();
        }
        if (old_cell.DiffGrid(new_cell))
            EnsureGridLoaded(new_cell);
        AddToGrid(dynObj, new_cell);
    }
}

bool Map::UnloadGrid(MapGridType& grid)
{
    {
        auto gridLock = AcquireGridObjectWriteLock();
        _mapGridManager.UnloadGrid(grid.GetX(), grid.GetY());
    }

    ClearPreloadedGridObjectGuids(GridCoord(grid.GetX(), grid.GetY()).GetId());

    {
        std::lock_guard<std::mutex> guard(_gridLayerLock);
        _gridLoadedLayers.erase(GridCoord(grid.GetX(), grid.GetY()).GetId());
    }

    {
        std::lock_guard<std::mutex> guard(_objectsToRemoveLock);
        ASSERT(i_objectsToRemove.empty());
    }
    LOG_DEBUG("maps", "Unloading grid[{}, {}] for map {} finished", grid.GetX(), grid.GetY(), GetId());
    return true;
}

void Map::RemoveAllPlayers()
{
    if (HavePlayers())
    {
        for (MapRefMgr::iterator itr = m_mapRefMgr.begin(); itr != m_mapRefMgr.end(); ++itr)
        {
            Player* player = itr->GetSource();
            if (!player->IsBeingTeleportedFar())
            {
                // this is happening for bg
                LOG_ERROR("maps", "Map::UnloadAll: player {} is still in map {} during unload, this should not happen!", player->GetName(), GetId());
                player->TeleportTo(player->m_homebindMapId, player->m_homebindX, player->m_homebindY, player->m_homebindZ, player->GetOrientation());
            }
        }
    }
}

void Map::UnloadAll()
{
    // clear all delayed moves, useless anyway do this moves before map unload.
    _creaturesToMove.clear();
    _gameObjectsToMove.clear();

    for (GridRefMgr<MapGridType>::iterator i = GridRefMgr<MapGridType>::begin(); i != GridRefMgr<MapGridType>::end();)
    {
        MapGridType& grid(*i->GetSource());
        ++i;
        UnloadGrid(grid); // deletes the grid and removes it from the GridRefMgr
    }

    // pussywizard: crashfix, some npc can be left on transport (not a default passenger)
    if (!AllTransportsEmpty())
        AllTransportsRemovePassengers();

    for (TransportsContainer::iterator itr = _transports.begin(); itr != _transports.end();)
    {
        Transport* transport = *itr;
        ++itr;

        RemoveFromMap<Transport>(transport, true);
    }

    _transports.clear();

    for (auto& cellCorpsePair : _corpsesByGrid)
    {
        for (Corpse* corpse : cellCorpsePair.second)
        {
            corpse->RemoveFromWorld();
            corpse->ResetMap();
            delete corpse;
        }
    }

    _corpsesByGrid.clear();
    _corpsesByPlayer.clear();
    _corpseBones.clear();
}

std::shared_ptr<GridTerrainData> Map::GetGridTerrainDataSharedPtr(GridCoord const& gridCoord)
{
    // ensure GridMap is created
    EnsureGridCreated(gridCoord);
    return _mapGridManager.GetGrid(gridCoord.x_coord, gridCoord.y_coord)->GetTerrainDataSharedPtr();
}

std::shared_ptr<GridTerrainData> Map::GetGridTerrainData(GridCoord const& gridCoord)
{
    if (!MapGridManager::IsValidGridCoordinates(gridCoord.x_coord, gridCoord.y_coord))
        return nullptr;

    // ensure GridMap is created
    EnsureGridCreated(gridCoord);
    return _mapGridManager.GetGridTerrainData(gridCoord.x_coord, gridCoord.y_coord);
}

std::shared_ptr<GridTerrainData> Map::GetGridTerrainData(float x, float y)
{
    GridCoord const gridCoord = Acore::ComputeGridCoord(x, y);
    return GetGridTerrainData(gridCoord);
}

float Map::GetWaterOrGroundLevel(uint32 phasemask, float x, float y, float z, float* ground /*= nullptr*/, bool /*swim = false*/, float collisionHeight) const
{
    // we need ground level (including grid height version) for proper return water level in point
    float ground_z = GetHeight(phasemask, x, y, z + Z_OFFSET_FIND_HEIGHT, true, 50.0f);
    if (ground)
        *ground = ground_z;

    LiquidData const& liquidData = const_cast<Map*>(this)->GetLiquidData(phasemask, x, y, ground_z, collisionHeight, {});
    switch (liquidData.Status)
    {
        case LIQUID_MAP_ABOVE_WATER:
            return std::max<float>(liquidData.Level, ground_z);
        case LIQUID_MAP_NO_WATER:
            return ground_z;
        default:
            return liquidData.Level;
    }

    return VMAP_INVALID_HEIGHT_VALUE;
}

Transport* Map::GetTransportForPos(uint32 phase, float x, float y, float z, WorldObject* worldobject)
{
    G3D::Vector3 v(x, y, z + 2.0f);
    G3D::Ray r(v, G3D::Vector3(0, 0, -1));
    for (TransportsContainer::const_iterator itr = _transports.begin(); itr != _transports.end(); ++itr)
        if ((*itr)->IsInWorld() && (*itr)->GetExactDistSq(x, y, z) < 75.0f * 75.0f && (*itr)->m_model)
        {
            float dist = 30.0f;
            bool hit = (*itr)->m_model->intersectRay(r, dist, false, phase, VMAP::ModelIgnoreFlags::Nothing);
            if (hit)
                return *itr;
        }

    if (worldobject)
        if (GameObject* staticTrans = worldobject->FindNearestGameObjectOfType(GAMEOBJECT_TYPE_TRANSPORT, 75.0f))
            if (staticTrans->m_model)
            {
                float dist = 10.0f;
                bool hit = staticTrans->m_model->intersectRay(r, dist, false, phase, VMAP::ModelIgnoreFlags::Nothing);
                if (hit)
                    if (GetHeight(phase, x, y, z, true, 30.0f) < (v.z - dist + 1.0f))
                        return staticTrans->ToTransport();
            }

    return nullptr;
}

float Map::GetHeight(float x, float y, float z, bool checkVMap /*= true*/, float maxSearchDist /*= DEFAULT_HEIGHT_SEARCH*/) const
{
    // find raw .map surface under Z coordinates
    float mapHeight = VMAP_INVALID_HEIGHT_VALUE;
    float gridHeight = GetGridHeight(x, y);
    if (G3D::fuzzyGe(z, gridHeight - GROUND_HEIGHT_TOLERANCE))
        mapHeight = gridHeight;

    float vmapHeight = VMAP_INVALID_HEIGHT_VALUE;
    if (checkVMap)
    {
        VMAP::IVMapMgr* vmgr = VMAP::VMapFactory::createOrGetVMapMgr();
        vmapHeight = vmgr->getHeight(GetId(), x, y, z, maxSearchDist);   // look from a bit higher pos to find the floor
    }

    // mapHeight set for any above raw ground Z or <= INVALID_HEIGHT
    // vmapheight set for any under Z value or <= INVALID_HEIGHT
    if (vmapHeight > INVALID_HEIGHT)
    {
        if (mapHeight > INVALID_HEIGHT)
        {
            // we have mapheight and vmapheight and must select more appropriate

            // we are already under the surface or vmap height above map heigt
            // or if the distance of the vmap height is less the land height distance
            if (vmapHeight > mapHeight || std::fabs(mapHeight - z) > std::fabs(vmapHeight - z))
                return vmapHeight;
            else
                return mapHeight;                           // better use .map surface height
        }
        else
            return vmapHeight;                              // we have only vmapHeight (if have)
    }

    return mapHeight;                               // explicitly use map data
}

float Map::GetGridHeight(float x, float y) const
{
    if (std::shared_ptr<GridTerrainData> gmap = const_cast<Map*>(this)->GetGridTerrainData(x, y))
        return gmap->getHeight(x, y);

    return INVALID_HEIGHT;
}

float Map::GetMinHeight(float x, float y) const
{
    if (std::shared_ptr<GridTerrainData> const grid = const_cast<Map*>(this)->GetGridTerrainData(x, y))
        return grid->getMinHeight(x, y);

    return MIN_HEIGHT;
}

static inline bool IsInWMOInterior(uint32 mogpFlags)
{
    return (mogpFlags & 0x2000) != 0;
}

bool Map::GetAreaInfo(uint32 phaseMask, float x, float y, float z, uint32& flags, int32& adtId, int32& rootId, int32& groupId) const
{
    // Guard: non-finite coordinates cause BIH ray-intersection to hang (infinite traversal)
    if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(z))
        return false;

    float check_z = z;
    VMAP::IVMapMgr* vmgr = VMAP::VMapFactory::createOrGetVMapMgr();
    VMAP::AreaAndLiquidData vdata;
    VMAP::AreaAndLiquidData ddata;

    bool hasVmapAreaInfo = vmgr->GetAreaAndLiquidData(GetId(), x, y, z, {}, vdata) && vdata.areaInfo.has_value();
    bool hasDynamicAreaInfo = false;
    {
        std::shared_lock<std::shared_mutex> lock(_dynamicTreeLock);
        hasDynamicAreaInfo = _dynamicTree.GetAreaAndLiquidData(x, y, z, phaseMask, {}, ddata) && ddata.areaInfo.has_value();
    }
    auto useVmap = [&] { check_z = vdata.floorZ; groupId = vdata.areaInfo->groupId; adtId = vdata.areaInfo->adtId; rootId = vdata.areaInfo->rootId; flags = vdata.areaInfo->mogpFlags; };
    auto useDyn = [&] { check_z = ddata.floorZ; groupId = ddata.areaInfo->groupId; adtId = ddata.areaInfo->adtId; rootId = ddata.areaInfo->rootId; flags = ddata.areaInfo->mogpFlags; };
    if (hasVmapAreaInfo)
    {
        if (hasDynamicAreaInfo && ddata.floorZ > vdata.floorZ)
            useDyn();
        else
            useVmap();
    }
    else if (hasDynamicAreaInfo)
    {
        useDyn();
    }

    if (hasVmapAreaInfo || hasDynamicAreaInfo)
    {
        // check if there's terrain between player height and object height
        if (std::shared_ptr<GridTerrainData> gmap = const_cast<Map*>(this)->GetGridTerrainData(x, y))
        {
            float mapHeight = gmap->getHeight(x, y);
            // z + 2.0f condition taken from GetHeight(), not sure if it's such a great choice...
            if (z + 2.0f > mapHeight && mapHeight > check_z)
                return false;
        }

        return true;
    }

    return false;
}

uint32 Map::GetAreaId(uint32 phaseMask, float x, float y, float z) const
{
    uint32 mogpFlags;
    int32 adtId, rootId, groupId;
    float vmapZ = z;
    bool hasVmapArea = GetAreaInfo(phaseMask, x, y, vmapZ, mogpFlags, adtId, rootId, groupId);

    uint32 gridAreaId    = 0;
    float  gridMapHeight = INVALID_HEIGHT;
    if (std::shared_ptr<GridTerrainData> gmap = const_cast<Map*>(this)->GetGridTerrainData(x, y))
    {
        gridAreaId    = gmap->getArea(x, y);
        gridMapHeight = gmap->getHeight(x, y);
    }

    uint16 areaId = 0;

    // floor is the height we are closer to (but only if above)
    if (hasVmapArea && G3D::fuzzyGe(z, vmapZ - GROUND_HEIGHT_TOLERANCE) && (G3D::fuzzyLt(z, gridMapHeight - GROUND_HEIGHT_TOLERANCE) || vmapZ > gridMapHeight))
    {
        // wmo found
        if (WMOAreaTableEntry const* wmoEntry = GetWMOAreaTableEntryByTripple(rootId, adtId, groupId))
            areaId = wmoEntry->areaId;

        if (!areaId)
            areaId = gridAreaId;
    }
    else
        areaId = gridAreaId;

    if (!areaId)
        areaId = i_mapEntry->linked_zone;

    return areaId;
}

uint32 Map::GetZoneId(uint32 phaseMask, float x, float y, float z) const
{
    uint32 areaId = GetAreaId(phaseMask, x, y, z);
    if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(areaId))
        if (area->zone)
            return area->zone;

    return areaId;
}

void Map::GetZoneAndAreaId(uint32 phaseMask, uint32& zoneid, uint32& areaid, float x, float y, float z) const
{
    areaid = zoneid = GetAreaId(phaseMask, x, y, z);
    if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(areaid))
        if (area->zone)
            zoneid = area->zone;
}

LiquidData const Map::GetLiquidData(uint32 phaseMask, float x, float y, float z, float collisionHeight, Optional<uint8> ReqLiquidType)
{
   LiquidData liquidData;
   liquidData.Status = LIQUID_MAP_NO_WATER;

    VMAP::IVMapMgr* vmgr = VMAP::VMapFactory::createOrGetVMapMgr();
    VMAP::AreaAndLiquidData vmapData;
    bool useGridLiquid = true;
    if (vmgr->GetAreaAndLiquidData(GetId(), x, y, z, ReqLiquidType, vmapData) && vmapData.liquidInfo)
    {
        useGridLiquid = !vmapData.areaInfo || !IsInWMOInterior(vmapData.areaInfo->mogpFlags);
        LOG_DEBUG("maps", "GetLiquidStatus(): vmap liquid level: {} ground: {} type: {}", vmapData.liquidInfo->level, vmapData.floorZ, vmapData.liquidInfo->type);
        // Check water level and ground level
        if (vmapData.liquidInfo->level > vmapData.floorZ && G3D::fuzzyGe(z, vmapData.floorZ - GROUND_HEIGHT_TOLERANCE))
        {
            // hardcoded in client like this
            if (GetId() == MAP_OUTLAND && vmapData.liquidInfo->type == 2)
                vmapData.liquidInfo->type = 15;

            uint32 liquidFlagType = 0;
            if (LiquidTypeEntry const* liq = sLiquidTypeStore.LookupEntry(vmapData.liquidInfo->type))
                liquidFlagType = liq->Type;

            if (vmapData.liquidInfo->type && vmapData.liquidInfo->type < 21)
            {
                if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(GetAreaId(phaseMask, x, y, z)))
                {
                    uint32 overrideLiquid = area->LiquidTypeOverride[liquidFlagType];
                    if (!overrideLiquid && area->zone)
                    {
                        area = sAreaTableStore.LookupEntry(area->zone);
                        if (area)
                            overrideLiquid = area->LiquidTypeOverride[liquidFlagType];
                    }

                    if (LiquidTypeEntry const* liq = sLiquidTypeStore.LookupEntry(overrideLiquid))
                    {
                        vmapData.liquidInfo->type = overrideLiquid;
                        liquidFlagType = liq->Type;
                    }
                }
            }

            liquidData.Level = vmapData.liquidInfo->level;
            liquidData.DepthLevel = vmapData.floorZ;
            liquidData.Entry = vmapData.liquidInfo->type;
            liquidData.Flags = 1 << liquidFlagType;
        }

        float delta = vmapData.liquidInfo->level - z;

        // Get position delta
        if (delta > collisionHeight)
            liquidData.Status = LIQUID_MAP_UNDER_WATER;
        else if (delta > 0.0f)
            liquidData.Status = LIQUID_MAP_IN_WATER;
        else if (delta > -0.1f)
            liquidData.Status = LIQUID_MAP_WATER_WALK;
        else
            liquidData.Status = LIQUID_MAP_ABOVE_WATER;
    }

    if (useGridLiquid)
    {
        if (std::shared_ptr<GridTerrainData> gmap = const_cast<Map*>(this)->GetGridTerrainData(x, y))
        {
            LiquidData const& map_data = gmap->GetLiquidData(x, y, z, collisionHeight, ReqLiquidType);
            // Not override LIQUID_MAP_ABOVE_WATER with LIQUID_MAP_NO_WATER:
            if (map_data.Status != LIQUID_MAP_NO_WATER && (map_data.Level > vmapData.floorZ))
            {
                // hardcoded in client like this
                uint32 liquidEntry = map_data.Entry;
                if (GetId() == MAP_OUTLAND && liquidEntry == 2)
                    liquidEntry = 15;

                liquidData = map_data;
                liquidData.Entry = liquidEntry;
            }
        }
    }

   return liquidData;
}

void Map::GetFullTerrainStatusForPosition(uint32 /*phaseMask*/, float x, float y, float z, float collisionHeight, PositionFullTerrainStatus& data, Optional<uint8> reqLiquidType)
{
    std::shared_ptr<GridTerrainData> gmap = GetGridTerrainData(x, y);

    VMAP::IVMapMgr* vmgr = VMAP::VMapFactory::createOrGetVMapMgr();
    VMAP::AreaAndLiquidData vmapData;
    // VMAP::AreaAndLiquidData dynData;
    VMAP::AreaAndLiquidData* wmoData = nullptr;
    vmgr->GetAreaAndLiquidData(GetId(), x, y, z, reqLiquidType, vmapData);
    // _dynamicTree.GetAreaAndLiquidData(x, y, z, phaseMask, reqLiquidType, dynData);

    uint32 gridAreaId = 0;
    float gridMapHeight = INVALID_HEIGHT;
    if (gmap)
    {
        gridAreaId = gmap->getArea(x, y);
        gridMapHeight = gmap->getHeight(x, y);
    }

    bool useGridLiquid = true;

    // floor is the height we are closer to (but only if above)
    data.floorZ = VMAP_INVALID_HEIGHT;
    if (gridMapHeight > INVALID_HEIGHT && G3D::fuzzyGe(z, gridMapHeight - GROUND_HEIGHT_TOLERANCE))
        data.floorZ = gridMapHeight;

    if (vmapData.floorZ > VMAP_INVALID_HEIGHT && G3D::fuzzyGe(z, vmapData.floorZ - GROUND_HEIGHT_TOLERANCE) &&
        (G3D::fuzzyLt(z, gridMapHeight - GROUND_HEIGHT_TOLERANCE) || vmapData.floorZ > gridMapHeight))
    {
        data.floorZ = vmapData.floorZ;
        wmoData = &vmapData;
    }

    // NOTE: Objects will not detect a case when a wmo providing area/liquid despawns from under them
    // but this is fine as these kind of objects are not meant to be spawned and despawned a lot
    // example: Lich King platform
    /*
    if (dynData.floorZ > VMAP_INVALID_HEIGHT && G3D::fuzzyGe(z, dynData.floorZ - GROUND_HEIGHT_TOLERANCE) &&
        (G3D::fuzzyLt(z, gridMapHeight - GROUND_HEIGHT_TOLERANCE) || dynData.floorZ > gridMapHeight) &&
    {
        data.floorZ = dynData.floorZ;
        wmoData = &dynData;
    }
    */

    if (wmoData)
    {
        if (wmoData->areaInfo)
        {
            // wmo found
            WMOAreaTableEntry const* wmoEntry = GetWMOAreaTableEntryByTripple(wmoData->areaInfo->rootId, wmoData->areaInfo->adtId, wmoData->areaInfo->groupId);
            data.outdoors = (wmoData->areaInfo->mogpFlags & 0x8) != 0;
            if (wmoEntry)
            {
                data.areaId = wmoEntry->areaId;
                if (wmoEntry->Flags & 4)
                    data.outdoors = true;
                else if (wmoEntry->Flags & 2)
                    data.outdoors = false;
            }

            if (!data.areaId)
                data.areaId = gridAreaId;

            useGridLiquid = !IsInWMOInterior(wmoData->areaInfo->mogpFlags);
        }
    }
    else
    {
        data.outdoors = true;
        data.areaId = gridAreaId;
        if (AreaTableEntry const* areaEntry = sAreaTableStore.LookupEntry(data.areaId))
            data.outdoors = (areaEntry->flags & (AREA_FLAG_INSIDE | AREA_FLAG_OUTSIDE)) != AREA_FLAG_INSIDE;
    }

    if (!data.areaId)
        data.areaId = i_mapEntry->linked_zone;

    AreaTableEntry const* areaEntry = sAreaTableStore.LookupEntry(data.areaId);

    // liquid processing
    if (wmoData && wmoData->liquidInfo && wmoData->liquidInfo->level > wmoData->floorZ)
    {
        uint32 liquidType = wmoData->liquidInfo->type;
        if (GetId() == MAP_OUTLAND && liquidType == 2) // gotta love blizzard hacks
            liquidType = 15;

        uint32 liquidFlagType = 0;
        if (LiquidTypeEntry const* liquidData = sLiquidTypeStore.LookupEntry(liquidType))
            liquidFlagType = liquidData->Type;

        if (liquidType && liquidType < 21 && areaEntry)
        {
            uint32 overrideLiquid = areaEntry->LiquidTypeOverride[liquidFlagType];
            if (!overrideLiquid && areaEntry->zone)
            {
                AreaTableEntry const* zoneEntry = sAreaTableStore.LookupEntry(areaEntry->zone);
                if (zoneEntry)
                    overrideLiquid = zoneEntry->LiquidTypeOverride[liquidFlagType];
            }

            if (LiquidTypeEntry const* overrideData = sLiquidTypeStore.LookupEntry(overrideLiquid))
            {
                liquidType = overrideLiquid;
                liquidFlagType = overrideData->Type;
            }
        }

        data.liquidInfo.Level = wmoData->liquidInfo->level;
        data.liquidInfo.DepthLevel = wmoData->floorZ;
        data.liquidInfo.Entry = liquidType;
        data.liquidInfo.Flags = 1 << liquidFlagType;

        // Get position delta
        float delta = wmoData->liquidInfo->level - z;

        if (delta > collisionHeight)
            data.liquidInfo.Status = LIQUID_MAP_UNDER_WATER;
        else if (delta > 0.0f)
            data.liquidInfo.Status = LIQUID_MAP_IN_WATER;
        else if (delta > -0.1f)
            data.liquidInfo.Status = LIQUID_MAP_WATER_WALK;
        else
            data.liquidInfo.Status = LIQUID_MAP_ABOVE_WATER;
    }

    // look up liquid data from grid map
    if (gmap && useGridLiquid)
    {
        LiquidData const& gridLiquidData = gmap->GetLiquidData(x, y, z, collisionHeight, reqLiquidType);
        if (gridLiquidData.Status != LIQUID_MAP_NO_WATER && (!wmoData || gridLiquidData.Level > wmoData->floorZ))
        {
            uint32 liquidEntry = gridLiquidData.Entry;
            if (GetId() == MAP_OUTLAND && liquidEntry == 2)
                liquidEntry = 15;

            data.liquidInfo = gridLiquidData;
            data.liquidInfo.Entry = liquidEntry;
        }
    }
}

float Map::GetWaterLevel(float x, float y) const
{
    if (std::shared_ptr<GridTerrainData> gmap = const_cast<Map*>(this)->GetGridTerrainData(x, y))
        return gmap->getLiquidLevel(x, y);

    return INVALID_HEIGHT;
}

bool Map::isInLineOfSight(float x1, float y1, float z1, float x2, float y2, float z2, uint32 phasemask, LineOfSightChecks checks, VMAP::ModelIgnoreFlags ignoreFlags) const
{
    if (!sWorld->getBoolConfig(CONFIG_VMAP_BLIZZLIKE_PVP_LOS))
    {
        if (IsBattlegroundOrArena())
        {
            ignoreFlags = VMAP::ModelIgnoreFlags::Nothing;
        }
    }

    if (!sWorld->getBoolConfig(CONFIG_VMAP_BLIZZLIKE_LOS_OPEN_WORLD))
    {
        if (IsWorldMap())
        {
            ignoreFlags = VMAP::ModelIgnoreFlags::Nothing;
        }
    }

    if ((checks & LINEOFSIGHT_CHECK_VMAP) && !VMAP::VMapFactory::createOrGetVMapMgr()->isInLineOfSight(GetId(), x1, y1, z1, x2, y2, z2, ignoreFlags))
    {
        return false;
    }

    if (sWorld->getBoolConfig(CONFIG_CHECK_GOBJECT_LOS) && (checks & LINEOFSIGHT_CHECK_GOBJECT_ALL))
    {
        ignoreFlags = VMAP::ModelIgnoreFlags::Nothing;
        if (!(checks & LINEOFSIGHT_CHECK_GOBJECT_M2))
        {
            ignoreFlags = VMAP::ModelIgnoreFlags::M2;
        }

        {
            std::shared_lock<std::shared_mutex> lock(_dynamicTreeLock);
            if (!_dynamicTree.isInLineOfSight(x1, y1, z1, x2, y2, z2, phasemask, ignoreFlags))
            {
                return false;
            }
        }
    }

    return true;
}

bool Map::GetObjectHitPos(uint32 phasemask, float x1, float y1, float z1, float x2, float y2, float z2, float& rx, float& ry, float& rz, float modifyDist)
{
    G3D::Vector3 startPos(x1, y1, z1);
    G3D::Vector3 dstPos(x2, y2, z2);

    G3D::Vector3 resultPos;
    std::shared_lock<std::shared_mutex> lock(_dynamicTreeLock);
    bool result = _dynamicTree.GetObjectHitPos(phasemask, startPos, dstPos, resultPos, modifyDist);

    rx = resultPos.x;
    ry = resultPos.y;
    rz = resultPos.z;
    return result;
}

float Map::GetHeight(uint32 phasemask, float x, float y, float z, bool vmap/*=true*/, float maxSearchDist /*= DEFAULT_HEIGHT_SEARCH*/) const
{
    float h1, h2;
    h1 = GetHeight(x, y, z, vmap, maxSearchDist);
    {
        std::shared_lock<std::shared_mutex> lock(_dynamicTreeLock);
        h2 = _dynamicTree.getHeight(x, y, z, maxSearchDist, phasemask);
    }
    return std::max<float>(h1, h2);
}

bool Map::IsInWater(uint32 phaseMask, float x, float y, float pZ, float collisionHeight) const
{
    LiquidData const& liquidData = const_cast<Map*>(this)->GetLiquidData(phaseMask, x, y, pZ, collisionHeight, {});
    return (liquidData.Status & MAP_LIQUID_STATUS_SWIMMING) != 0;
}

bool Map::IsUnderWater(uint32 phaseMask, float x, float y, float z, float collisionHeight) const
{
    LiquidData const& liquidData = const_cast<Map*>(this)->GetLiquidData(phaseMask, x, y, z, collisionHeight, MAP_LIQUID_TYPE_WATER | MAP_LIQUID_TYPE_OCEAN);
    return liquidData.Status == LIQUID_MAP_UNDER_WATER;
}

bool Map::HasEnoughWater(WorldObject const* searcher, float x, float y, float z) const
{
    LiquidData const& liquidData = const_cast<Map*>(this)->GetLiquidData(
        searcher->GetPhaseMask(), x, y, z, searcher->GetCollisionHeight(), MAP_ALL_LIQUIDS);

    if ((liquidData.Status & MAP_LIQUID_STATUS_SWIMMING) == 0)
        return false;

    float minHeightInWater = searcher->GetMinHeightInWater();
    return liquidData.Level > INVALID_HEIGHT &&
           liquidData.Level > liquidData.DepthLevel &&
           liquidData.Level - liquidData.DepthLevel >= minHeightInWater;
}

char const* Map::GetMapName() const
{
    return i_mapEntry ? i_mapEntry->name[sWorld->GetDefaultDbcLocale()] : "UNNAMEDMAP\x0";
}

void Map::SendInitSelf(Player* player)
{
    LOG_DEBUG("maps", "Creating player data for himself {}", player->GetGUID().ToString());

    WorldPacket packet;
    UpdateData data;

    // attach to player data current transport data
    if (Transport* transport = player->GetTransport())
        transport->BuildCreateUpdateBlockForPlayer(&data, player);

    // build data for self presence in world at own client (one time for map)
    player->BuildCreateUpdateBlockForPlayer(&data, player);

    // build and send self update packet before sending to player his own auras
    data.BuildPacket(packet);
    player->SendDirectMessage(&packet);

    // send to player his own auras (this is needed here for timely initialization of some fields on client)
    player->GetAurasForTarget(player, true);

    // clean buffers for further work
    packet.clear();
    data.Clear();

    // build other passengers at transport also (they always visible and marked as visible and will not send at visibility update at add to map
    if (Transport* transport = player->GetTransport())
    {
        Transport::PassengerSet passengers = transport->GetPassengerSnapshot();
        for (Transport::PassengerSet::const_iterator itr = passengers.begin(); itr != passengers.end(); ++itr)
            if (player != (*itr) && player->HaveAtClient(*itr))
                (*itr)->BuildCreateUpdateBlockForPlayer(&data, player);
    }

    data.BuildPacket(packet);
    player->SendDirectMessage(&packet);
}

void Map::UpdateExpiredCorpses(uint32 const diff)
{
    _corpseUpdateTimer.Update(diff);
    if (!_corpseUpdateTimer.Passed())
        return;

    RemoveOldCorpses();

    _corpseUpdateTimer.Reset();
}

void Map::SendInitTransports(Player* player)
{
    if (_transports.empty())
        return;

    // Hack to send out transports
    UpdateData transData;
    for (TransportsContainer::const_iterator itr = _transports.begin(); itr != _transports.end(); ++itr)
        if (*itr != player->GetTransport())
            (*itr)->BuildCreateUpdateBlockForPlayer(&transData, player);

    if (!transData.HasData())
        return;

    WorldPacket packet;
    transData.BuildPacket(packet);
    player->SendDirectMessage(&packet);
}

void Map::SendRemoveTransports(Player* player)
{
    if (_transports.empty())
        return;

    // Hack to send out transports
    UpdateData transData;
    for (TransportsContainer::const_iterator itr = _transports.begin(); itr != _transports.end(); ++itr)
        if (*itr != player->GetTransport())
            (*itr)->BuildOutOfRangeUpdateBlock(&transData);

    if (!transData.HasData())
        return;

    WorldPacket packet;
    transData.BuildPacket(packet);
    player->SendDirectMessage(&packet);
}

void Map::SendObjectUpdates()
{
    UpdateDataMapType update_players;

    // Extract pending updates under lock with a per-tick budget, then process outside lock
    std::vector<Object*> objectsToUpdate;
    {
        std::lock_guard<std::mutex> lock(_updateObjectsLock);
        size_t takeCount = std::min(_adaptiveObjectUpdateBudget, _updateObjects.size());
        objectsToUpdate.reserve(takeCount);

        auto it = _updateObjects.begin();
        while (it != _updateObjects.end() && objectsToUpdate.size() < takeCount)
        {
            Object* obj = *it;
            it = _updateObjects.erase(it);
            objectsToUpdate.push_back(obj);
        }
    }

    if (!objectsToUpdate.empty())
    {
        constexpr size_t kMinObjectsPerWorker = 64;
        uint32 maxWorkers = 1;
        if (MapUpdater* updater = sMapMgr->GetMapUpdater(); updater && updater->activated())
            maxWorkers = std::max<uint32>(1, sWorld->getIntConfig(CONFIG_NUMTHREADS));

        size_t desiredWorkers = objectsToUpdate.size() / kMinObjectsPerWorker;
        size_t workerCount = std::min<size_t>(maxWorkers, std::max<size_t>(1, desiredWorkers));

        if (workerCount <= 1)
        {
            for (Object* obj : objectsToUpdate)
            {
                if (!obj || !obj->IsInWorld())
                    continue;
                obj->BuildUpdate(update_players);
            }
        }
        else
        {
            SendUpdateWorkerPool& pool = GetSendUpdateWorkerPool();
            pool.EnsureThreads(workerCount);

            std::vector<UpdateDataMapType> workerUpdates(workerCount);
            size_t blockSize = (objectsToUpdate.size() + workerCount - 1) / workerCount;

            pool.RunTasks(workerCount, [&objectsToUpdate, &workerUpdates, blockSize](size_t workerIndex)
            {
                size_t beginIndex = workerIndex * blockSize;
                size_t endIndex = std::min(objectsToUpdate.size(), beginIndex + blockSize);
                if (beginIndex >= endIndex)
                    return;

                UpdateDataMapType& localUpdates = workerUpdates[workerIndex];
                for (size_t i = beginIndex; i < endIndex; ++i)
                {
                    Object* obj = objectsToUpdate[i];
                    if (!obj || !obj->IsInWorld())
                        continue;
                    obj->BuildUpdate(localUpdates);
                }
            });

            for (UpdateDataMapType& localUpdates : workerUpdates)
            {
                for (auto& pair : localUpdates)
                {
                    UpdateData& dest = update_players[pair.first];
                    dest.AddUpdateBlock(pair.second);
                }
            }
        }
    }

    struct UpdateSendJob
    {
        Player* player = nullptr;
        UpdateData data;
        bool send = false;
    };

    std::vector<UpdateSendJob> sendJobs;
    sendJobs.reserve(update_players.size());
    for (auto& pair : update_players)
    {
        bool send = sScriptMgr->OnPlayerbotCheckUpdatesToSend(pair.first);
        if (!send)
        {
            pair.second.Clear();
            continue;
        }

        sendJobs.push_back({pair.first, std::move(pair.second), true});
    }

    if (!sendJobs.empty())
    {
        constexpr size_t kMinPlayersPerWorker = 32;
        uint32 maxWorkers = 1;
        if (MapUpdater* updater = sMapMgr->GetMapUpdater(); updater && updater->activated())
            maxWorkers = std::max<uint32>(1, sWorld->getIntConfig(CONFIG_NUMTHREADS));

        size_t desiredWorkers = sendJobs.size() / kMinPlayersPerWorker;
        size_t workerCount = std::min<size_t>(maxWorkers, std::max<size_t>(1, desiredWorkers));

        std::vector<std::unique_ptr<WorldPacket>> packets(sendJobs.size());

        if (workerCount <= 1)
        {
            for (size_t i = 0; i < sendJobs.size(); ++i)
            {
                if (!sendJobs[i].send)
                    continue;
                packets[i] = std::make_unique<WorldPacket>();
                sendJobs[i].data.BuildPacket(*packets[i]);
            }
        }
        else
        {
            SendUpdateWorkerPool& pool = GetSendUpdateWorkerPool();
            pool.EnsureThreads(workerCount);

            size_t blockSize = (sendJobs.size() + workerCount - 1) / workerCount;
            pool.RunTasks(workerCount, [&sendJobs, &packets, blockSize](size_t workerIndex)
            {
                size_t beginIndex = workerIndex * blockSize;
                size_t endIndex = std::min(sendJobs.size(), beginIndex + blockSize);
                if (beginIndex >= endIndex)
                    return;

                for (size_t i = beginIndex; i < endIndex; ++i)
                {
                    if (!sendJobs[i].send)
                        continue;
                    auto packet = std::make_unique<WorldPacket>();
                    sendJobs[i].data.BuildPacket(*packet);
                    packets[i] = std::move(packet);
                }
            });
        }

        for (size_t i = 0; i < sendJobs.size(); ++i)
        {
            if (!sendJobs[i].send || !packets[i])
                continue;
            sendJobs[i].player->SendDirectMessage(packets[i].get());
        }
    }
}

uint32 Map::ApplyDynamicModeRespawnScaling(WorldObject const* obj, uint32 respawnDelay) const
{
    ASSERT(obj->GetMap() == this);

    float rate = sWorld->getFloatConfig(obj->IsGameObject() ? CONFIG_RESPAWN_DYNAMICRATE_GAMEOBJECT : CONFIG_RESPAWN_DYNAMICRATE_CREATURE);

    if (rate == 1.0f)
        return respawnDelay;

    // No instanced maps (dungeons, battlegrounds, arenas etc.)
    if (obj->GetMap()->Instanceable())
        return respawnDelay;

    // No quest givers or world bosses
    if (Creature const* creature = obj->ToCreature())
        if (creature->IsQuestGiver() || creature->isWorldBoss()
            || (creature->GetCreatureTemplate()->rank == CREATURE_ELITE_RARE)
            || (creature->GetCreatureTemplate()->rank == CREATURE_ELITE_RAREELITE))
            return respawnDelay;

    uint32 playerCount = 0;
    {
        std::lock_guard<std::mutex> lock(_zonePlayerCountLock);
        auto it = _zonePlayerCountMap.find(obj->GetZoneId());
        if (it == _zonePlayerCountMap.end())
            return respawnDelay;
        playerCount = it->second;
    }
    if (!playerCount)
        return respawnDelay;
    double const adjustFactor =  rate / playerCount;
    if (adjustFactor >= 1.0) // nothing to do here
        return respawnDelay;
    uint32 const timeMinimum = sWorld->getIntConfig(obj->IsGameObject() ? CONFIG_RESPAWN_DYNAMICMINIMUM_GAMEOBJECT : CONFIG_RESPAWN_DYNAMICMINIMUM_CREATURE);
    if (respawnDelay <= timeMinimum)
        return respawnDelay;

    return std::max<uint32>(std::ceil(respawnDelay * adjustFactor), timeMinimum);
}

void Map::DelayedUpdate(const uint32 t_diff)
{
    for (_transportsUpdateIter = _transports.begin(); _transportsUpdateIter != _transports.end();)
    {
        Transport* transport = *_transportsUpdateIter;
        ++_transportsUpdateIter;

        if (!transport->IsInWorld())
            continue;

        transport->DelayedUpdate(t_diff);
    }

    RemoveAllObjectsInRemoveList();
}

void Map::AddObjectToRemoveList(WorldObject* obj)
{
    ASSERT(obj->GetMapId() == GetId() && obj->GetInstanceId() == GetInstanceId());

    obj->CleanupsBeforeDelete(false);                            // remove or simplify at least cross referenced links

    {
        std::lock_guard<std::mutex> guard(_objectsToRemoveLock);
        i_objectsToRemove.insert(obj);
    }
    //LOG_DEBUG("maps", "Object ({}) added to removing list.", obj->GetGUID().ToString());
}

void Map::RemoveAllObjectsInRemoveList()
{
    while (true)
    {
        WorldObject* obj = nullptr;
        {
            std::lock_guard<std::mutex> guard(_objectsToRemoveLock);
            if (i_objectsToRemove.empty())
                break;

            auto itr = i_objectsToRemove.begin();
            obj = *itr;
            i_objectsToRemove.erase(itr);
        }

        if (!obj)
            continue;

        switch (obj->GetTypeId())
        {
            case TYPEID_CORPSE:
                {
                    Corpse* corpse = ObjectAccessor::GetCorpse(*obj, obj->GetGUID());
                    if (!corpse)
                        LOG_ERROR("maps", "Tried to delete corpse/bones {} that is not in map.", obj->GetGUID().ToString());
                    else
                        RemoveFromMap(corpse, true);
                    break;
                }
            case TYPEID_DYNAMICOBJECT:
                RemoveFromMap((DynamicObject*)obj, true);
                break;
            case TYPEID_GAMEOBJECT:
                if (Transport* transport = obj->ToGameObject()->ToTransport())
                    RemoveFromMap(transport, true);
                else
                    RemoveFromMap(obj->ToGameObject(), true);
                break;
            case TYPEID_UNIT:
                // in case triggered sequence some spell can continue casting after prev CleanupsBeforeDelete call
                // make sure that like sources auras/etc removed before destructor start
                obj->ToCreature()->CleanupsBeforeDelete();
                RemoveFromMap(obj->ToCreature(), true);
                break;
            default:
                LOG_ERROR("maps", "Non-grid object (TypeId: {}) is in grid object remove list, ignored.", obj->GetTypeId());
                break;
        }
    }
}

uint32 Map::GetPlayersCountExceptGMs() const
{
    uint32 count = 0;
    for (MapRefMgr::const_iterator itr = m_mapRefMgr.begin(); itr != m_mapRefMgr.end(); ++itr)
        if (!itr->GetSource()->IsGameMaster())
            ++count;
    return count;
}

void Map::SendToPlayers(WorldPacket const* data) const
{
    for (MapRefMgr::const_iterator itr = m_mapRefMgr.begin(); itr != m_mapRefMgr.end(); ++itr)
        itr->GetSource()->SendDirectMessage(data);
}

template bool Map::AddToMap(Corpse*, bool);
template bool Map::AddToMap(Creature*, bool);
template bool Map::AddToMap(GameObject*, bool);
template bool Map::AddToMap(DynamicObject*, bool);

template void Map::RemoveFromMap(Corpse*, bool);
template void Map::RemoveFromMap(Creature*, bool);
template void Map::RemoveFromMap(GameObject*, bool);
template void Map::RemoveFromMap(DynamicObject*, bool);

/* ******* Dungeon Instance Maps ******* */

InstanceMap::InstanceMap(uint32 id, uint32 InstanceId, uint8 SpawnMode, Map* _parent)
    : Map(id, InstanceId, SpawnMode, _parent),
      m_resetAfterUnload(false), m_unloadWhenEmpty(false),
      instance_data(nullptr), i_script_id(0)
{
    //lets initialize visibility distance for dungeons
    InstanceMap::InitVisibilityDistance();

    // the timer is started by default, and stopped when the first player joins
    // this make sure it gets unloaded if for some reason no player joins
    m_unloadTimer = std::max(sWorld->getIntConfig(CONFIG_INSTANCE_UNLOAD_DELAY), (uint32)MIN_UNLOAD_DELAY);

    // pussywizard:
    if (IsRaid())
        if (time_t resetTime = sInstanceSaveMgr->GetResetTimeFor(id, Difficulty(SpawnMode)))
            if (time_t extendedResetTime = sInstanceSaveMgr->GetExtendedResetTimeFor(id, Difficulty(SpawnMode)))
                _instanceResetPeriod = extendedResetTime - resetTime;
}

InstanceMap::~InstanceMap()
{
    delete instance_data;
    instance_data = nullptr;
    sInstanceSaveMgr->DeleteInstanceSaveIfNeeded(GetInstanceId(), true);
}

void InstanceMap::InitVisibilityDistance()
{
    //init visibility distance for instances
    m_VisibleDistance = World::GetMaxVisibleDistanceInInstances();

    // pussywizard: this CAN NOT exceed MAX_VISIBILITY_DISTANCE
    switch (GetId())
    {
        case 429: // Dire Maul
        case 550: // The Eye
        case 578: // The Nexus: The Oculus
            m_VisibleDistance = 175.0f;
            break;
        case 649: // Trial of the Crusader
        case 650: // Trial of the Champion
        case 595: // Culling of Startholme
        case 658: // Pit of Saron
            m_VisibleDistance = 150.0f;
            break;
        case 615: // Obsidian Sanctum
        case 616: // Eye of Eternity
        case 603: // Ulduar
        case 668: // Halls of Reflection
        case 631: // Icecrown Citadel
        case 724: // Ruby Sanctum
            m_VisibleDistance = 200.0f;
            break;
        case 531: // Ahn'Qiraj Temple
            m_VisibleDistance = 300.0f;
            break;
    }
}

/*
    Do map specific checks to see if the player can enter
*/
Map::EnterState InstanceMap::CannotEnter(Player* player, bool loginCheck)
{
    if (!loginCheck && player->GetMapRef().getTarget() == this)
    {
        LOG_ERROR("maps", "InstanceMap::CanEnter - player {} ({}) already in map {}, {}, {}!",
            player->GetName(), player->GetGUID().ToString(), GetId(), GetInstanceId(), GetSpawnMode());

        return CANNOT_ENTER_ALREADY_IN_MAP;
    }

    // allow GM's to enter
    if (player->IsGameMaster())
        return Map::CannotEnter(player, loginCheck);

    // cannot enter if the instance is full (player cap), GMs don't count
    uint32 maxPlayers = GetMaxPlayers();
    if (GetPlayersCountExceptGMs() >= (loginCheck ? maxPlayers + 1 : maxPlayers))
    {
        LOG_DEBUG("maps", "MAP: Instance '{}' of map '{}' cannot have more than '{}' players. Player '{}' rejected", GetInstanceId(), GetMapName(), maxPlayers, player->GetName());
        player->SendTransferAborted(GetId(), TRANSFER_ABORT_MAX_PLAYERS);
        return CANNOT_ENTER_MAX_PLAYERS;
    }

    // cannot enter while an encounter is in progress on raids
    bool checkProgress = (IsRaid() || GetId() == 668 /*HoR*/);
    if (checkProgress && GetInstanceScript() && GetInstanceScript()->IsEncounterInProgress())
    {
        player->SendTransferAborted(GetId(), TRANSFER_ABORT_ZONE_IN_COMBAT);
        return CANNOT_ENTER_ZONE_IN_COMBAT;
    }

    // xinef: dont allow LFG Group to enter other instance that is selected
    if (Group* group = player->GetGroup())
        if (group->isLFGGroup())
            if (!sLFGMgr->inLfgDungeonMap(group->GetGUID(), GetId(), GetDifficulty()))
            {
                player->SendTransferAborted(GetId(), TRANSFER_ABORT_MAP_NOT_ALLOWED);
                return CANNOT_ENTER_UNSPECIFIED_REASON;
            }

    // cannot enter if instance is in use by another party/soloer that have a permanent save in the same instance id
    PlayerList const& playerList = GetPlayers();
    if (!playerList.IsEmpty())
        for (PlayerList::const_iterator i = playerList.begin(); i != playerList.end(); ++i)
            if (Player* iPlayer = i->GetSource())
            {
                if (iPlayer == player) // login case, player already added to map
                    continue;
                if (iPlayer->IsGameMaster()) // bypass GMs
                    continue;
                if (!player->GetGroup()) // player has not group and there is someone inside, deny entry
                {
                    player->SendTransferAborted(GetId(), TRANSFER_ABORT_MAX_PLAYERS);
                    return CANNOT_ENTER_INSTANCE_BIND_MISMATCH;
                }
                // player inside instance has no group or his groups is different to entering player's one, deny entry
                if (!iPlayer->GetGroup() || iPlayer->GetGroup() != player->GetGroup())
                {
                    player->SendTransferAborted(GetId(), TRANSFER_ABORT_MAX_PLAYERS);
                    return CANNOT_ENTER_INSTANCE_BIND_MISMATCH;
                }
                break;
            }

    return Map::CannotEnter(player, loginCheck);
}

/*
    Do map specific checks and add the player to the map if successful.
*/
bool InstanceMap::AddPlayerToMap(Player* player)
{
    if (m_resetAfterUnload) // this instance has been reset, it's not meant to be used anymore
        return false;

    if (IsDungeon())
    {
        Group* group = player->GetGroup();

        // get an instance save for the map
        InstanceSave* mapSave = sInstanceSaveMgr->GetInstanceSave(GetInstanceId());
        if (!mapSave)
        {
            LOG_ERROR("maps", "InstanceMap::Add: InstanceSave does not exist for map {} spawnmode {} with instance id {}", GetId(), GetSpawnMode(), GetInstanceId());
            return false;
        }

        // check for existing instance binds
        InstancePlayerBind* playerBind = sInstanceSaveMgr->PlayerGetBoundInstance(player->GetGUID(), GetId(), Difficulty(GetSpawnMode()));
        if (playerBind && playerBind->perm)
        {
            if (playerBind->save != mapSave)
            {
                LOG_ERROR("maps", "InstanceMap::Add: player {} ({}) is permanently bound to instance {}, {}, {}, {} but he is being put into instance {}, {}, {}, {}",
                    player->GetName(), player->GetGUID().ToString(), playerBind->save->GetMapId(), playerBind->save->GetInstanceId(), playerBind->save->GetDifficulty(),
                    playerBind->save->CanReset(), mapSave->GetMapId(), mapSave->GetInstanceId(), mapSave->GetDifficulty(), mapSave->CanReset());
                return false;
            }
        }
        else if (player->GetSession()->PlayerLoading() && playerBind && playerBind->save != mapSave)
        {
            // Prevent "Convert to Raid" exploit to reset instances
            return false;
        }
        else
        {
            playerBind = sInstanceSaveMgr->PlayerBindToInstance(player->GetGUID(), mapSave, false, player);
            // pussywizard: bind lider also if not yet bound
            if (Group* g = player->GetGroup())
                if (g->GetLeaderGUID() != player->GetGUID())
                    if (!sInstanceSaveMgr->PlayerGetBoundInstance(g->GetLeaderGUID(), mapSave->GetMapId(), mapSave->GetDifficulty()))
                    {
                        sInstanceSaveMgr->PlayerCreateBoundInstancesMaps(g->GetLeaderGUID());
                        sInstanceSaveMgr->PlayerBindToInstance(g->GetLeaderGUID(), mapSave, false, ObjectAccessor::FindConnectedPlayer(g->GetLeaderGUID()));
                    }
        }

        // increase current instances (hourly limit)
        // xinef: specific instances are still limited
        if (!group || !group->isLFGGroup() || !group->IsLfgRandomInstance())
            player->AddInstanceEnterTime(GetInstanceId(), GameTime::GetGameTime().count());

        if (!playerBind->perm && !mapSave->CanReset() && group && !group->isLFGGroup() && !group->IsLfgRandomInstance())
        {
            WorldPacket data(SMSG_INSTANCE_LOCK_WARNING_QUERY, 9);
            data << uint32(60000);
            data << uint32(instance_data ? instance_data->GetCompletedEncounterMask() : 0);
            data << uint8(0);
            player->SendDirectMessage(&data);
            player->SetPendingBind(mapSave->GetInstanceId(), 60000);
        }
    }

    // initialize unload state
    m_unloadTimer = 0;
    m_resetAfterUnload = false;
    m_unloadWhenEmpty = false;

    // this will acquire the same mutex so it cannot be in the previous block
    Map::AddPlayerToMap(player);

    if (instance_data)
        instance_data->OnPlayerEnter(player);

    return true;
}

void InstanceMap::Update(const uint32 t_diff, const uint32 s_diff, bool /*thread*/)
{
    Map::Update(t_diff, s_diff);

    if (t_diff)
        if (instance_data)
            instance_data->Update(t_diff);
}

void InstanceMap::RemovePlayerFromMap(Player* player, bool remove)
{
    if (instance_data)
        instance_data->OnPlayerLeave(player);
    // pussywizard: moved m_unloadTimer to InstanceMap::AfterPlayerUnlinkFromMap(), in this function if 2 players run out at the same time the instance won't close
    //if (!m_unloadTimer && m_mapRefMgr.getSize() == 1)
    //    m_unloadTimer = m_unloadWhenEmpty ? MIN_UNLOAD_DELAY : std::max(sWorld->getIntConfig(CONFIG_INSTANCE_UNLOAD_DELAY), (uint32)MIN_UNLOAD_DELAY);
    Map::RemovePlayerFromMap(player, remove);

    // If remove == true - player already deleted.
    if (!remove)
        player->SetPendingBind(0, 0);
}

void InstanceMap::AfterPlayerUnlinkFromMap()
{
    if (!m_unloadTimer && !HavePlayers())
        m_unloadTimer = m_unloadWhenEmpty ? MIN_UNLOAD_DELAY : std::max(sWorld->getIntConfig(CONFIG_INSTANCE_UNLOAD_DELAY), (uint32)MIN_UNLOAD_DELAY);
    Map::AfterPlayerUnlinkFromMap();
}

void InstanceMap::CreateInstanceScript(bool load, std::string data, uint32 completedEncounterMask)
{
    if (instance_data)
    {
        return;
    }

    bool isOtherAI = false;

    sScriptMgr->OnBeforeCreateInstanceScript(this, &instance_data, load, data, completedEncounterMask);

    if (instance_data)
        isOtherAI = true;

    // if ALE AI was fetched succesfully we should not call CreateInstanceData nor set the unused scriptID
    if (!isOtherAI)
    {
        InstanceTemplate const* mInstance = sObjectMgr->GetInstanceTemplate(GetId());
        if (mInstance)
        {
            i_script_id = mInstance->ScriptId;
            instance_data = sScriptMgr->CreateInstanceScript(this);
        }
    }

    if (!instance_data)
        return;

    // use mangos behavior if we are dealing with ALE AI
    // initialize should then be called only if load is false
    if (!isOtherAI || !load)
    {
        instance_data->Initialize();
    }

    if (load)
    {
        instance_data->SetCompletedEncountersMask(completedEncounterMask, false);
        if (data != "")
            instance_data->Load(data.c_str());
    }

    instance_data->LoadInstanceSavedGameobjectStateData();
}

/*
    Returns true if there are no players in the instance
*/
bool InstanceMap::Reset(uint8 method, GuidList* globalResetSkipList)
{
    if (method == INSTANCE_RESET_GLOBAL)
    {
        // pussywizard: teleport out immediately
        for (MapRefMgr::iterator itr = m_mapRefMgr.begin(); itr != m_mapRefMgr.end(); ++itr)
        {
            // teleport players that are no longer bound (can be still bound if extended id)
            if (!globalResetSkipList || std::find(globalResetSkipList->begin(), globalResetSkipList->end(), itr->GetSource()->GetGUID()) == globalResetSkipList->end())
                itr->GetSource()->RepopAtGraveyard();
        }

        // reset map only if noone is bound
        if (!globalResetSkipList || globalResetSkipList->empty())
        {
            // pussywizard: setting both m_unloadWhenEmpty and m_unloadTimer intended, in case RepopAtGraveyard failed
            if (HavePlayers())
                m_unloadWhenEmpty = true;
            m_unloadTimer = MIN_UNLOAD_DELAY;
            m_resetAfterUnload = true;
        }

        return m_mapRefMgr.IsEmpty();
    }

    if (HavePlayers())
    {
        if (method == INSTANCE_RESET_ALL || method == INSTANCE_RESET_CHANGE_DIFFICULTY)
        {
            for (MapRefMgr::iterator itr = m_mapRefMgr.begin(); itr != m_mapRefMgr.end(); ++itr)
                itr->GetSource()->SendResetFailedNotify(GetId());
        }
    }
    else
    {
        m_unloadTimer = MIN_UNLOAD_DELAY;
        m_resetAfterUnload = true;
    }

    return m_mapRefMgr.IsEmpty();
}

std::string const& InstanceMap::GetScriptName() const
{
    return sObjectMgr->GetScriptName(i_script_id);
}

void InstanceMap::PermBindAllPlayers()
{
    if (!IsDungeon())
        return;

    InstanceSave* save = sInstanceSaveMgr->GetInstanceSave(GetInstanceId());
    if (!save)
    {
        LOG_ERROR("maps", "Cannot bind players because no instance save is available for instance map (Name: {}, Entry: {}, InstanceId: {})!", GetMapName(), GetId(), GetInstanceId());
        return;
    }

    Player* player;
    Group* group;
    // group members outside the instance group don't get bound
    for (MapRefMgr::iterator itr = m_mapRefMgr.begin(); itr != m_mapRefMgr.end(); ++itr)
    {
        player = itr->GetSource();
        group = player->GetGroup();

        // players inside an instance cannot be bound to other instances
        // some players may already be permanently bound, in this case nothing happens
        InstancePlayerBind* bind = sInstanceSaveMgr->PlayerGetBoundInstance(player->GetGUID(), save->GetMapId(), save->GetDifficulty());

        if (!bind || !bind->perm)
        {
            WorldPacket data(SMSG_INSTANCE_SAVE_CREATED, 4);
            data << uint32(0);
            player->SendDirectMessage(&data);
            sInstanceSaveMgr->PlayerBindToInstance(player->GetGUID(), save, true, player);
        }

        // Xinef: Difficulty change prevention
        if (group)
            group->SetDifficultyChangePrevention(DIFFICULTY_PREVENTION_CHANGE_BOSS_KILLED);
    }
}

void InstanceMap::UnloadAll()
{
    ASSERT(!HavePlayers());

    if (m_resetAfterUnload)
    {
        DeleteRespawnTimes();
        DeleteCorpseData();
    }

    Map::UnloadAll();
}

void InstanceMap::SendResetWarnings(uint32 timeLeft) const
{
    for (MapRefMgr::const_iterator itr = m_mapRefMgr.begin(); itr != m_mapRefMgr.end(); ++itr)
        itr->GetSource()->SendInstanceResetWarning(GetId(), itr->GetSource()->GetDifficulty(IsRaid()), timeLeft, false);
}

MapDifficulty const* Map::GetMapDifficulty() const
{
    return GetMapDifficultyData(GetId(), GetDifficulty());
}

uint32 InstanceMap::GetMaxPlayers() const
{
    MapDifficulty const* mapDiff = GetMapDifficulty();
    if (mapDiff && mapDiff->maxPlayers)
        return mapDiff->maxPlayers;

    return GetEntry()->maxPlayers;
}

uint32 InstanceMap::GetMaxResetDelay() const
{
    MapDifficulty const* mapDiff = GetMapDifficulty();
    return mapDiff ? mapDiff->resetTime : 0;
}

/* ******* Battleground Instance Maps ******* */

BattlegroundMap::BattlegroundMap(uint32 id, uint32 InstanceId, Map* _parent, uint8 spawnMode)
    : Map(id, InstanceId, spawnMode, _parent), m_bg(nullptr)
{
    //lets initialize visibility distance for BG/Arenas
    BattlegroundMap::InitVisibilityDistance();
}

BattlegroundMap::~BattlegroundMap()
{
    if (m_bg)
    {
        //unlink to prevent crash, always unlink all pointer reference before destruction
        m_bg->SetBgMap(nullptr);
        m_bg = nullptr;
    }
}

void BattlegroundMap::InitVisibilityDistance()
{
    //init visibility distance for BG/Arenas
    m_VisibleDistance = World::GetMaxVisibleDistanceInBGArenas();

    if (IsBattleArena()) // pussywizard: start with 30yd visibility range on arenas to ensure players can't get informations about the opponents in any way
        m_VisibleDistance = 30.0f;
}

Map::EnterState BattlegroundMap::CannotEnter(Player* player, bool loginCheck)
{
    if (!loginCheck && player->GetMapRef().getTarget() == this)
    {
        LOG_ERROR("maps", "BGMap::CanEnter - player {} is already in map!", player->GetGUID().ToString());
        ABORT();
        return CANNOT_ENTER_ALREADY_IN_MAP;
    }

    if (player->GetBattlegroundId() != GetInstanceId())
        return CANNOT_ENTER_INSTANCE_BIND_MISMATCH;

    // pussywizard: no need to check player limit here, invitations are limited by Battleground::GetFreeSlotsForTeam

    return Map::CannotEnter(player, loginCheck);
}

bool BattlegroundMap::AddPlayerToMap(Player* player)
{
    player->m_InstanceValid = true;
    if (IsBattleArena())
        player->CastSpell(player, 100102, true);
    return Map::AddPlayerToMap(player);
}

void BattlegroundMap::RemovePlayerFromMap(Player* player, bool remove)
{
    if (Battleground* bg = GetBG())
    {
        bg->RemovePlayerAtLeave(player);
        if (IsBattleArena())
            bg->RemoveSpectator(player);
    }
    if (IsBattleArena())
        player->RemoveAura(100102);
    Map::RemovePlayerFromMap(player, remove);
}

void BattlegroundMap::SetUnload()
{
    m_unloadTimer = MIN_UNLOAD_DELAY;
}

void BattlegroundMap::RemoveAllPlayers()
{
    if (HavePlayers())
        for (MapRefMgr::iterator itr = m_mapRefMgr.begin(); itr != m_mapRefMgr.end(); ++itr)
            if (Player* player = itr->GetSource())
                if (!player->IsBeingTeleportedFar())
                    player->TeleportTo(player->GetEntryPoint());
}

Corpse* Map::GetCorpse(ObjectGuid const& guid)
{
    if (_isPartitioned)
        if (Corpse* corpse = FindPartitionedObject<Corpse>(guid))
            return corpse;
    return FindObjectStore<Corpse>(guid);
}

Creature* Map::GetCreature(ObjectGuid const& guid)
{
    if (_isPartitioned)
        if (Creature* creature = FindPartitionedObject<Creature>(guid))
            return creature;
    return FindObjectStore<Creature>(guid);
}

Creature* Map::GetCreature(ObjectGuid const& guid) const
{
    return const_cast<Map*>(this)->GetCreature(guid);
}

GameObject* Map::GetGameObject(ObjectGuid const& guid)
{
    if (_isPartitioned)
        if (GameObject* go = FindPartitionedObject<GameObject>(guid))
            return go;
    return FindObjectStore<GameObject>(guid);
}

Pet* Map::GetPet(ObjectGuid const& guid)
{
    if (_isPartitioned)
        if (Creature* creature = FindPartitionedObject<Creature>(guid))
            return dynamic_cast<Pet*>(creature);
    return dynamic_cast<Pet*>(FindObjectStore<Creature>(guid));
}

Pet* Map::GetPet(ObjectGuid const& guid) const
{
    return const_cast<Map*>(this)->GetPet(guid);
}

Transport* Map::GetTransport(ObjectGuid const& guid)
{
    if (guid.GetHigh() != HighGuid::Mo_Transport && guid.GetHigh() != HighGuid::Transport)
        return nullptr;

    GameObject* go = GetGameObject(guid);
    return go ? go->ToTransport() : nullptr;
}

DynamicObject* Map::GetDynamicObject(ObjectGuid const& guid)
{
    if (_isPartitioned)
        if (DynamicObject* dynObj = FindPartitionedObject<DynamicObject>(guid))
            return dynObj;
    return FindObjectStore<DynamicObject>(guid);
}

void Map::UpdateIteratorBack(Player* player)
{
    if (m_mapRefIter == player->GetMapRef())
        m_mapRefIter = m_mapRefIter->nocheck_prev();
}

void Map::SaveCreatureRespawnTime(ObjectGuid::LowType spawnId, time_t& respawnTime)
{
    if (!respawnTime)
    {
        // Delete only
        RemoveCreatureRespawnTime(spawnId);
        return;
    }

    time_t now = GameTime::GetGameTime().count();
    if (GetInstanceResetPeriod() > 0 && respawnTime - now + 5 >= GetInstanceResetPeriod())
        respawnTime = now + YEAR;

    {
        std::lock_guard<std::mutex> lock(_respawnTimesLock);
        _creatureRespawnTimes[spawnId] = respawnTime;
    }

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_CREATURE_RESPAWN);
    stmt->SetData(0, spawnId);
    stmt->SetData(1, uint32(respawnTime));
    stmt->SetData(2, GetId());
    stmt->SetData(3, GetInstanceId());
    CharacterDatabase.Execute(stmt);
}

void Map::RemoveCreatureRespawnTime(ObjectGuid::LowType spawnId)
{
    {
        std::lock_guard<std::mutex> lock(_respawnTimesLock);
        _creatureRespawnTimes.erase(spawnId);
    }

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_DEL_CREATURE_RESPAWN);
    stmt->SetData(0, spawnId);
    stmt->SetData(1, GetId());
    stmt->SetData(2, GetInstanceId());
    CharacterDatabase.Execute(stmt);
}

void Map::SaveGORespawnTime(ObjectGuid::LowType spawnId, time_t& respawnTime)
{
    if (!respawnTime)
    {
        // Delete only
        RemoveGORespawnTime(spawnId);
        return;
    }

    time_t now = GameTime::GetGameTime().count();
    if (GetInstanceResetPeriod() > 0 && respawnTime - now + 5 >= GetInstanceResetPeriod())
        respawnTime = now + YEAR;

    {
        std::lock_guard<std::mutex> lock(_respawnTimesLock);
        _goRespawnTimes[spawnId] = respawnTime;
    }

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_GO_RESPAWN);
    stmt->SetData(0, spawnId);
    stmt->SetData(1, uint32(respawnTime));
    stmt->SetData(2, GetId());
    stmt->SetData(3, GetInstanceId());
    CharacterDatabase.Execute(stmt);
}

void Map::RemoveGORespawnTime(ObjectGuid::LowType spawnId)
{
    {
        std::lock_guard<std::mutex> lock(_respawnTimesLock);
        _goRespawnTimes.erase(spawnId);
    }

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_DEL_GO_RESPAWN);
    stmt->SetData(0, spawnId);
    stmt->SetData(1, GetId());
    stmt->SetData(2, GetInstanceId());
    CharacterDatabase.Execute(stmt);
}

void Map::LoadRespawnTimes()
{
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_CREATURE_RESPAWNS);
    stmt->SetData(0, GetId());
    stmt->SetData(1, GetInstanceId());
    if (PreparedQueryResult result = CharacterDatabase.Query(stmt))
    {
        do
        {
            Field* fields = result->Fetch();
            ObjectGuid::LowType lowguid = fields[0].Get<uint32>();
            uint32 respawnTime = fields[1].Get<uint32>();

            _creatureRespawnTimes[lowguid] = time_t(respawnTime);
        } while (result->NextRow());
    }

    stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_GO_RESPAWNS);
    stmt->SetData(0, GetId());
    stmt->SetData(1, GetInstanceId());
    if (PreparedQueryResult result = CharacterDatabase.Query(stmt))
    {
        do
        {
            Field* fields = result->Fetch();
            ObjectGuid::LowType lowguid = fields[0].Get<uint32>();
            uint32 respawnTime = fields[1].Get<uint32>();

            _goRespawnTimes[lowguid] = time_t(respawnTime);
        } while (result->NextRow());
    }
}

void Map::DeleteRespawnTimes()
{
    std::lock_guard<std::mutex> lock(_respawnTimesLock);
    _creatureRespawnTimes.clear();
    _goRespawnTimes.clear();

    DeleteRespawnTimesInDB(GetId(), GetInstanceId());
}

void Map::DeleteRespawnTimesInDB(uint16 mapId, uint32 instanceId)
{
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_DEL_CREATURE_RESPAWN_BY_INSTANCE);
    stmt->SetData(0, mapId);
    stmt->SetData(1, instanceId);
    CharacterDatabase.Execute(stmt);

    stmt = CharacterDatabase.GetPreparedStatement(CHAR_DEL_GO_RESPAWN_BY_INSTANCE);
    stmt->SetData(0, mapId);
    stmt->SetData(1, instanceId);
    CharacterDatabase.Execute(stmt);
}

void Map::UpdateEncounterState(EncounterCreditType type, uint32 creditEntry, Unit* source)
{
    Difficulty difficulty_fixed = (IsSharedDifficultyMap(GetId()) ? Difficulty(GetDifficulty() % 2) : GetDifficulty());
    DungeonEncounterList const* encounters;
    // 631 : ICC - 724 : Ruby Sanctum --- For heroic difficulties, for some reason, we don't have an encounter list, so we get the encounter list from normal diff. We shouldn't change difficulty_fixed variable.
    if ((GetId() == 631 || GetId() == 724) && IsHeroic())
    {
        encounters = sObjectMgr->GetDungeonEncounterList(GetId(), !Is25ManRaid() ? RAID_DIFFICULTY_10MAN_NORMAL : RAID_DIFFICULTY_25MAN_NORMAL);
    }
    else
    {
        encounters = sObjectMgr->GetDungeonEncounterList(GetId(), difficulty_fixed);
    }

    if (!encounters)
    {
        return;
    }

    uint32 dungeonId = 0;
    bool updated = false;

    for (DungeonEncounterList::const_iterator itr = encounters->begin(); itr != encounters->end(); ++itr)
    {
        DungeonEncounter const* encounter = *itr;
        if (encounter->creditType == type && encounter->creditEntry == creditEntry)
        {
            if (source)
                if (InstanceScript* instanceScript = source->GetInstanceScript())
                {
                    uint32 prevMask = instanceScript->GetCompletedEncounterMask();
                    instanceScript->SetCompletedEncountersMask((1 << encounter->dbcEntry->encounterIndex) | instanceScript->GetCompletedEncounterMask(), true);
                    if (prevMask != instanceScript->GetCompletedEncounterMask())
                        updated = true;
                }

            if (encounter->lastEncounterDungeon)
            {
                dungeonId = encounter->lastEncounterDungeon;
                break;
            }
        }
    }

    // pussywizard:
    LogEncounterFinished(type, creditEntry);

    sScriptMgr->OnAfterUpdateEncounterState(this, type, creditEntry, source, difficulty_fixed, encounters, dungeonId, updated);

    if (dungeonId)
    {
        Map::PlayerList const& players = GetPlayers();
        for (Map::PlayerList::const_iterator i = players.begin(); i != players.end(); ++i)
        {
            if (Player* player = i->GetSource())
                if (Group* grp = player->GetGroup())
                    if (grp->isLFGGroup())
                    {
                        sLFGMgr->FinishDungeon(grp->GetGUID(), dungeonId, this);
                        return;
                    }
        }
    }
}

void Map::LogEncounterFinished(EncounterCreditType type, uint32 creditEntry)
{
    if (!IsRaid() || !GetEntry() || GetEntry()->Expansion() < 2) // only for wotlk raids, because logs take up tons of mysql memory
        return;
    InstanceMap* map = ToInstanceMap();
    if (!map)
        return;
    std::string playersInfo;
    char buffer[16384], buffer2[255];
    Map::PlayerList const& pl = map->GetPlayers();
    for (Map::PlayerList::const_iterator itr = pl.begin(); itr != pl.end(); ++itr)
        if (Player* p = itr->GetSource())
        {
            std::string auraStr;
            const Unit::AuraApplicationMap& a = p->GetAppliedAuras();
            for (auto iterator = a.begin(); iterator != a.end(); ++iterator)
            {
                snprintf(buffer2, 255, "%u(%u) ", iterator->first, iterator->second->GetEffectMask());
                auraStr += buffer2;
            }

            snprintf(buffer, 16384, "%s (%s, acc: %u, ip: %s, guild: %u), xyz: (%.1f, %.1f, %.1f), auras: %s\n",
                p->GetName().c_str(), p->GetGUID().ToString().c_str(), p->GetSession()->GetAccountId(), p->GetSession()->GetRemoteAddress().c_str(), p->GetGuildId(), p->GetPositionX(), p->GetPositionY(), p->GetPositionZ(), auraStr.c_str());
            playersInfo += buffer;
        }
    CleanStringForMysqlQuery(playersInfo);
    CharacterDatabase.Execute("INSERT INTO log_encounter VALUES(NOW(), {}, {}, {}, {}, '{}')", GetId(), (uint32)GetDifficulty(), type, creditEntry, playersInfo);
}

bool Map::AllTransportsEmpty() const
{
    for (TransportsContainer::const_iterator itr = _transports.begin(); itr != _transports.end(); ++itr)
        if (!(*itr)->GetPassengerSnapshot().empty())
            return false;

    return true;
}

void Map::AllTransportsRemovePassengers()
{
    for (TransportsContainer::const_iterator itr = _transports.begin(); itr != _transports.end(); ++itr)
    {
        Transport::PassengerSet passengers = (*itr)->GetPassengerSnapshot();
        for (WorldObject* obj : passengers)
            (*itr)->RemovePassenger(obj, true);
    }
}

time_t Map::GetLinkedRespawnTime(ObjectGuid guid) const
{
    ObjectGuid linkedGuid = sObjectMgr->GetLinkedRespawnGuid(guid);
    switch (linkedGuid.GetHigh())
    {
        case HighGuid::Unit:
            return GetCreatureRespawnTime(linkedGuid.GetCounter());
        case HighGuid::GameObject:
            return GetGORespawnTime(linkedGuid.GetCounter());
        default:
            break;
    }

    return time_t(0);
}

void Map::AddCorpse(Corpse* corpse)
{
    corpse->SetMap(this);

    GridCoord const gridCoord = Acore::ComputeGridCoord(corpse->GetPositionX(), corpse->GetPositionY());
    _corpsesByGrid[gridCoord.GetId()].insert(corpse);
    if (corpse->GetType() != CORPSE_BONES)
        _corpsesByPlayer[corpse->GetOwnerGUID()] = corpse;
    else
        _corpseBones.insert(corpse);
}

void Map::RemoveCorpse(Corpse* corpse)
{
    ASSERT(corpse);
    GridCoord const gridCoord = Acore::ComputeGridCoord(corpse->GetPositionX(), corpse->GetPositionY());

    corpse->DestroyForVisiblePlayers();
    if (corpse->IsInGrid())
        RemoveFromMap(corpse, false);
    else
    {
        corpse->RemoveFromWorld();
        corpse->ResetMap();
    }

    _corpsesByGrid[gridCoord.GetId()].erase(corpse);
    if (corpse->GetType() != CORPSE_BONES)
        _corpsesByPlayer.erase(corpse->GetOwnerGUID());
    else
        _corpseBones.erase(corpse);
}

Corpse* Map::ConvertCorpseToBones(ObjectGuid const& ownerGuid, bool insignia /*= false*/)
{
    Corpse* corpse = GetCorpseByPlayer(ownerGuid);
    if (!corpse)
        return nullptr;

    RemoveCorpse(corpse);

    // remove corpse from DB
    CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
    corpse->DeleteFromDB(trans);
    CharacterDatabase.CommitTransaction(trans);

    Corpse* bones = NULL;

    // create the bones only if the map and the grid is loaded at the corpse's location
    // ignore bones creating option in case insignia
    if ((insignia ||
        (IsBattlegroundOrArena() ? sWorld->getBoolConfig(CONFIG_DEATH_BONES_BG_OR_ARENA) : sWorld->getBoolConfig(CONFIG_DEATH_BONES_WORLD))) &&
        IsGridLoaded(corpse->GetPositionX(), corpse->GetPositionY()))
    {
        // Create bones, don't change Corpse
        bones = new Corpse();
        bones->Create(corpse->GetGUID().GetCounter());

        for (uint8 i = OBJECT_FIELD_TYPE + 1; i < CORPSE_END; ++i)                    // don't overwrite guid and object type
            bones->SetUInt32Value(i, corpse->GetUInt32Value(i));

        bones->SetCellCoord(corpse->GetCellCoord());
        bones->Relocate(corpse->GetPositionX(), corpse->GetPositionY(), corpse->GetPositionZ(), corpse->GetOrientation());
        bones->SetPhaseMask(corpse->GetPhaseMask(), false);

        bones->SetUInt32Value(CORPSE_FIELD_FLAGS, CORPSE_FLAG_UNK2 | CORPSE_FLAG_BONES);
        bones->SetGuidValue(CORPSE_FIELD_OWNER, corpse->GetOwnerGUID());

        for (uint8 i = 0; i < EQUIPMENT_SLOT_END; ++i)
            if (corpse->GetUInt32Value(CORPSE_FIELD_ITEM + i))
                bones->SetUInt32Value(CORPSE_FIELD_ITEM + i, 0);

        AddCorpse(bones);

        bones->UpdatePositionData();

        // add bones in grid store if grid loaded where corpse placed
        AddToMap(bones);
    }

    // all references to the corpse should be removed at this point
    delete corpse;

    return bones;
}

void Map::RemoveOldCorpses()
{
    time_t now = GameTime::GetGameTime().count();

    std::vector<ObjectGuid> corpses;
    corpses.reserve(_corpsesByPlayer.size());

    for (auto const& p : _corpsesByPlayer)
        if (p.second->IsExpired(now))
            corpses.push_back(p.first);

    for (ObjectGuid const& ownerGuid : corpses)
        ConvertCorpseToBones(ownerGuid);

    std::vector<Corpse*> expiredBones;
    for (Corpse* bones : _corpseBones)
        if (bones->IsExpired(now))
            expiredBones.push_back(bones);

    for (Corpse* bones : expiredBones)
    {
        RemoveCorpse(bones);
        delete bones;
    }
}

void Map::ScheduleCreatureRespawn(ObjectGuid creatureGuid, Milliseconds respawnTimer, Position pos)
{
    Events.AddEventAtOffset([this, creatureGuid, pos]()
    {
        if (Creature* creature = GetCreature(creatureGuid))
            creature->Respawn();
        else
            SummonCreature(creatureGuid.GetEntry(), pos);
    }, respawnTimer);
}

/// Send a packet to all players (or players selected team) in the zone (except self if mentioned)
bool Map::SendZoneMessage(uint32 zone, WorldPacket const* packet, WorldSession const* self, TeamId teamId) const
{
    bool foundPlayerToSend = false;

    for (MapReference const& ref : GetPlayers())
    {
        Player* player = ref.GetSource();
        if (player->IsInWorld() &&
            player->GetZoneId() == zone &&
            player->GetSession() != self &&
            (teamId == TEAM_NEUTRAL || player->GetTeamId() == teamId))
        {
            player->SendDirectMessage(packet);
            foundPlayerToSend = true;
        }
    }

    return foundPlayerToSend;
}

/// Send a System Message to all players in the zone (except self if mentioned)
void Map::SendZoneText(uint32 zoneId, char const* text, WorldSession const* self, TeamId teamId) const
{
    WorldPacket data;
    ChatHandler::BuildChatPacket(data, CHAT_MSG_SYSTEM, LANG_UNIVERSAL, nullptr, nullptr, text);
    SendZoneMessage(zoneId, &data, self, teamId);
}

void Map::SendZoneDynamicInfo(uint32 zoneId, Player* player) const
{
    ZoneDynamicInfoMap::const_iterator itr = _zoneDynamicInfo.find(zoneId);
    if (itr == _zoneDynamicInfo.end())
        return;

    if (uint32 music = itr->second.MusicId)
        player->SendDirectMessage(WorldPackets::Misc::PlayMusic(music).Write());

    SendZoneWeather(itr->second, player);

    if (uint32 overrideLight = itr->second.OverrideLightId)
    {
        WorldPacket data(SMSG_OVERRIDE_LIGHT, 4 + 4 + 4);
        data << uint32(_defaultLight);
        data << uint32(overrideLight);
        data << uint32(itr->second.LightFadeInTime);
        player->SendDirectMessage(&data);
    }
}

void Map::SendZoneWeather(uint32 zoneId, Player* player) const
{
    ZoneDynamicInfoMap::const_iterator itr = _zoneDynamicInfo.find(zoneId);
    if (itr == _zoneDynamicInfo.end())
        return;

    SendZoneWeather(itr->second, player);
}

void Map::SendZoneWeather(ZoneDynamicInfo const& zoneDynamicInfo, Player* player) const
{
    if (WeatherState weatherId = zoneDynamicInfo.WeatherId)
    {
        WorldPackets::Misc::Weather weather(weatherId, zoneDynamicInfo.WeatherGrade);
        player->SendDirectMessage(weather.Write());
    }
    else if (zoneDynamicInfo.DefaultWeather)
        zoneDynamicInfo.DefaultWeather->SendWeatherUpdateToPlayer(player);
    else
        Weather::SendFineWeatherUpdateToPlayer(player);
}

void Map::UpdateWeather(uint32 const diff)
{
    _weatherUpdateTimer.Update(diff);
    if (!_weatherUpdateTimer.Passed())
        return;

    for (auto&& zoneInfo : _zoneDynamicInfo)
        if (zoneInfo.second.DefaultWeather && !zoneInfo.second.DefaultWeather->Update(_weatherUpdateTimer.GetInterval()))
            zoneInfo.second.DefaultWeather.reset();

    _weatherUpdateTimer.Reset();
}

void Map::PlayDirectSoundToMap(uint32 soundId, uint32 zoneId)
{
    Map::PlayerList const& players = GetPlayers();
    if (!players.IsEmpty())
    {
        WorldPacket data(SMSG_PLAY_SOUND, 4);
        data << uint32(soundId);

        for (Map::PlayerList::const_iterator itr = players.begin(); itr != players.end(); ++itr)
            if (Player* player = itr->GetSource())
                if (!zoneId || player->GetZoneId() == zoneId)
                    player->SendDirectMessage(&data);
    }
}

void Map::SetZoneMusic(uint32 zoneId, uint32 musicId)
{
    _zoneDynamicInfo[zoneId].MusicId = musicId;

    WorldPackets::Misc::PlayMusic playMusic(musicId);
    SendZoneMessage(zoneId, WorldPackets::Misc::PlayMusic(musicId).Write());
}

Weather* Map::GetOrGenerateZoneDefaultWeather(uint32 zoneId)
{
    WeatherData const* weatherData = WeatherMgr::GetWeatherData(zoneId);
    if (!weatherData)
        return nullptr;

    ZoneDynamicInfo& info = _zoneDynamicInfo[zoneId];

    if (!info.DefaultWeather)
    {
        info.DefaultWeather = std::make_unique<Weather>(this, zoneId, weatherData);
        info.DefaultWeather->ReGenerate();
        info.DefaultWeather->UpdateWeather();
    }

    return info.DefaultWeather.get();
}

void Map::SetZoneWeather(uint32 zoneId, WeatherState weatherId, float weatherGrade)
{
    ZoneDynamicInfo& info = _zoneDynamicInfo[zoneId];
    info.WeatherId = weatherId;
    info.WeatherGrade = weatherGrade;

    SendZoneMessage(zoneId, WorldPackets::Misc::Weather(weatherId, weatherGrade).Write());
}

void Map::SetZoneOverrideLight(uint32 zoneId, uint32 lightId, Milliseconds fadeInTime)
{
    ZoneDynamicInfo& info = _zoneDynamicInfo[zoneId];
    info.OverrideLightId = lightId;
    info.LightFadeInTime = static_cast<uint32>(fadeInTime.count());

    WorldPacket data(SMSG_OVERRIDE_LIGHT, 4 + 4 + 4);
    data << uint32(_defaultLight);
    data << uint32(lightId);
    data << uint32(static_cast<uint32>(fadeInTime.count()));
    SendZoneMessage(zoneId, &data);
}

void Map::DoForAllPlayers(std::function<void(Player*)> exec)
{
    for (auto const& it : GetPlayers())
    {
        if (Player* player = it.GetSource())
        {
            exec(player);
        }
    }
}

/**
 * @brief Check if a given source can reach a specific point following a path
 * and normalize the coords. Use this method for long paths, otherwise use the
 * overloaded method with the start coords when you need to do a quick check on small segments
 *
 */
bool Map::CanReachPositionAndGetValidCoords(WorldObject const* source, PathGenerator *path, float &destX, float &destY, float &destZ, bool failOnCollision, bool failOnSlopes) const
{
    G3D::Vector3 prevPath = path->GetStartPosition();
    for (auto& vector : path->GetPath())
    {
        float x = vector.x;
        float y = vector.y;
        float z = vector.z;

        if (!CanReachPositionAndGetValidCoords(source, prevPath.x, prevPath.y, prevPath.z, x, y, z, failOnCollision, failOnSlopes))
        {
            destX = x;
            destY = y;
            destZ = z;
            return false;
        }

        prevPath = vector;
    }

    destX = prevPath.x;
    destY = prevPath.y;
    destZ = prevPath.z;

    return true;
}

/**
 * @brief validate the new destination and set reachable coords
 * Check if a given unit can reach a specific point on a segment
 * and set the correct dest coords
 * NOTE: use this method with small segments.
 *
 * @param failOnCollision if true, the methods will return false when a collision occurs
 * @param failOnSlopes if true, the methods will return false when a non walkable slope is found
 *
 * @return true if the destination is valid, false otherwise
 *
 **/

bool Map::CanReachPositionAndGetValidCoords(WorldObject const* source, float& destX, float& destY, float& destZ, bool failOnCollision, bool failOnSlopes) const
{
    return CanReachPositionAndGetValidCoords(source, source->GetPositionX(), source->GetPositionY(), source->GetPositionZ(), destX, destY, destZ, failOnCollision, failOnSlopes);
}

bool Map::CanReachPositionAndGetValidCoords(WorldObject const* source, float startX, float startY, float startZ, float &destX, float &destY, float &destZ, bool failOnCollision, bool failOnSlopes) const
{
    if (!CheckCollisionAndGetValidCoords(source, startX, startY, startZ, destX, destY, destZ, failOnCollision))
    {
        return false;
    }

    Unit const* unit = source->ToUnit();
    // if it's not an unit (Object) then we do not have to continue
    // with walkable checks
    if (!unit)
    {
        return true;
    }

    /*
     * Walkable checks
     */
    bool isWaterNext = HasEnoughWater(unit, destX, destY, destZ);
    Creature const* creature = unit->ToCreature();
    bool cannotEnterWater = isWaterNext && (creature && !creature->CanEnterWater());
    bool cannotWalkOrFly = !isWaterNext && !source->ToPlayer() && !unit->CanFly() && (creature && !creature->CanWalk());
    if (cannotEnterWater || cannotWalkOrFly ||
        (failOnSlopes && !PathGenerator::IsWalkableClimb(startX, startY, startZ, destX, destY, destZ, source->GetCollisionHeight())))
    {
        return false;
    }

    return true;
}

/**
 * @brief validate the new destination and set coords
 * Check if a given unit can face collisions in a specific segment
 *
 * @return true if the destination is valid, false otherwise
 *
 **/
bool Map::CheckCollisionAndGetValidCoords(WorldObject const* source, float startX, float startY, float startZ, float &destX, float &destY, float &destZ, bool failOnCollision) const
{
    // Prevent invalid coordinates here, position is unchanged
    if (!Acore::IsValidMapCoord(startX, startY, startZ) || !Acore::IsValidMapCoord(destX, destY, destZ))
    {
        LOG_FATAL("maps", "Map::CheckCollisionAndGetValidCoords invalid coordinates startX: {}, startY: {}, startZ: {}, destX: {}, destY: {}, destZ: {}", startX, startY, startZ, destX, destY, destZ);
        return false;
    }

    bool isWaterNext = IsInWater(source->GetPhaseMask(), destX, destY, destZ, source->GetCollisionHeight());

    PathGenerator path(source);

    // Use a detour raycast to get our first collision point
    path.SetUseRaycast(true);
    bool result = path.CalculatePath(startX, startY, startZ, destX, destY, destZ, false);

    Unit const* unit = source->ToUnit();
    bool notOnGround = path.GetPathType() & PATHFIND_NOT_USING_PATH
        || isWaterNext || (unit && unit->IsFlying());

    // Check for valid path types before we proceed
    if (!result || (!notOnGround && path.GetPathType() & ~(PATHFIND_NORMAL | PATHFIND_SHORTCUT | PATHFIND_INCOMPLETE | PATHFIND_FARFROMPOLY_END)))
    {
        return false;
    }

    G3D::Vector3 endPos = path.GetPath().back();
    destX = endPos.x;
    destY = endPos.y;
    destZ = endPos.z;

    // collision check
    bool collided = false;

    // check static LOS
    float halfHeight = source->GetCollisionHeight() * 0.5f;

    // Unit is not on the ground, check for potential collision via vmaps
    if (notOnGround)
    {
        bool col = VMAP::VMapFactory::createOrGetVMapMgr()->GetObjectHitPos(source->GetMapId(),
            startX, startY, startZ + halfHeight,
            destX, destY, destZ + halfHeight,
            destX, destY, destZ, -CONTACT_DISTANCE);

        destZ -= halfHeight;

        // Collided with static LOS object, move back to collision point
        if (col)
        {
            collided = true;
        }
    }

    // check dynamic collision
    bool col = source->GetMap()->GetObjectHitPos(source->GetPhaseMask(),
        startX, startY, startZ + halfHeight,
        destX, destY, destZ + halfHeight,
        destX, destY, destZ, -CONTACT_DISTANCE);

    destZ -= halfHeight;

    // Collided with a gameobject, move back to collision point
    if (col)
    {
        collided = true;
    }

    float groundZ = VMAP_INVALID_HEIGHT_VALUE;
    source->UpdateAllowedPositionZ(destX, destY, destZ, &groundZ);

    // position has no ground under it (or is too far away)
    if (groundZ <= INVALID_HEIGHT && unit && !unit->CanFly())
    {
        // fall back to gridHeight if any
        float gridHeight = GetGridHeight(destX, destY);
        if (gridHeight > INVALID_HEIGHT)
        {
            destZ = gridHeight + unit->GetHoverHeight();
        }
        else
        {
            return false;
        }
    }

    return !failOnCollision || !collided;
}

void Map::LoadCorpseData()
{
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_CORPSES);
    stmt->SetData(0, GetId());
    stmt->SetData(1, GetInstanceId());

    //        0     1     2     3            4      5          6          7       8       9        10     11        12    13          14          15         16
    // SELECT posX, posY, posZ, orientation, mapId, displayId, itemCache, bytes1, bytes2, guildId, flags, dynFlags, time, corpseType, instanceId, phaseMask, guid FROM corpse WHERE mapId = ? AND instanceId = ?
    PreparedQueryResult result = CharacterDatabase.Query(stmt);
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();
        CorpseType type = CorpseType(fields[13].Get<uint8>());
        uint32 guid = fields[16].Get<uint32>();
        if (type >= MAX_CORPSE_TYPE || type == CORPSE_BONES)
        {
            LOG_ERROR("maps", "Corpse (guid: {}) have wrong corpse type ({}), not loading.", guid, type);
            continue;
        }

        Corpse* corpse = new Corpse(type);

        if (!corpse->LoadCorpseFromDB(GenerateLowGuid<HighGuid::Corpse>(), fields))
        {
            delete corpse;
            continue;
        }

        AddCorpse(corpse);

        corpse->UpdatePositionData();
    } while (result->NextRow());
}

void Map::DeleteCorpseData()
{
    // DELETE FROM corpse WHERE mapId = ? AND instanceId = ?
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_DEL_CORPSES_FROM_MAP);
    stmt->SetData(0, GetId());
    stmt->SetData(1, GetInstanceId());
    CharacterDatabase.Execute(stmt);
}

std::string Map::GetDebugInfo() const
{
    std::stringstream sstr;
    sstr << std::boolalpha
        << "Id: " << GetId() << " InstanceId: " << GetInstanceId() << " Difficulty: " << std::to_string(GetDifficulty())
        << " HasPlayers: " << HavePlayers();
    return sstr.str();
}

uint32 Map::GetCreatedGridsCount()
{
    return _mapGridManager.GetCreatedGridsCount();
}

uint32 Map::GetLoadedGridsCount()
{
    return _mapGridManager.GetLoadedGridsCount();
}

uint32 Map::GetCreatedCellsInGridCount(uint16 const x, uint16 const y)
{
    return _mapGridManager.GetCreatedCellsInGridCount(x, y);
}

uint32 Map::GetCreatedCellsInMapCount()
{
    return _mapGridManager.GetCreatedCellsInMapCount();
}

std::string InstanceMap::GetDebugInfo() const
{
    std::stringstream sstr;
    sstr << Map::GetDebugInfo() << "\n"
        << std::boolalpha
        << "ScriptId: " << GetScriptId() << " ScriptName: " << GetScriptName();
    return sstr.str();
}


