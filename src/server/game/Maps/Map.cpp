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
#include "Maps/Partitioning/PartitionManager.h"
#include "Maps/Partitioning/LayerManager.h"
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
    constexpr size_t kPartitionRelayLimit = 1024;
    thread_local std::unordered_map<Map const*, uint32> sActivePartitionContext;
    thread_local bool sProcessingPartitionRelays = false;
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
    std::lock_guard<std::mutex> guard(_preloadedGridGuidsLock);
    if (_preloadedGridGuids.find(gridId) != _preloadedGridGuids.end())
        return;

    CellObjectGuids cellGuids = sObjectMgr->GetGridObjectGuids(GetId(), GetSpawnMode(), gridId);
    _preloadedGridGuids.emplace(gridId, std::make_shared<CellObjectGuids>(std::move(cellGuids)));
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
    CellCoord cellCoord = Acore::ComputeCellCoord(player->GetPositionX(), player->GetPositionY());
    if (!cellCoord.IsCoordValid())
    {
        LOG_ERROR("maps", "Map::Add: Player ({}) has invalid coordinates X:{} Y:{} grid cell [{}:{}]",
            player->GetGUID().ToString(), player->GetPositionX(), player->GetPositionY(), cellCoord.x_coord, cellCoord.y_coord);
        return false;
    }

    Cell cell(cellCoord);
    LoadGridsInRange(*player, MAX_VISIBILITY_DISTANCE);
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

void Map::QueuePartitionThreatRelay(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& victimGuid, float threat, SpellSchoolMask schoolMask, uint32 spellId)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionThreatRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} threat relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionThreatRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.victimGuid = victimGuid;
    relay.threat = threat;
    relay.schoolMask = schoolMask;
    relay.spellId = spellId;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionThreatClearAll(uint32 partitionId, ObjectGuid const& ownerGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionThreatActionRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} threat-action relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionThreatActionRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.action = 1;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionThreatResetAll(uint32 partitionId, ObjectGuid const& ownerGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionThreatActionRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} threat-action relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionThreatActionRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.action = 2;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}
void Map::QueuePartitionThreatTargetClear(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& targetGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionThreatTargetActionRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} threat-target relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionThreatTargetActionRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.targetGuid = targetGuid;
    relay.action = 1;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionThreatTargetReset(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& targetGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionThreatTargetActionRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} threat-target relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionThreatTargetActionRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.targetGuid = targetGuid;
    relay.action = 2;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionCombatRelay(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& victimGuid, bool initialAggro)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionCombatRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} combat relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionCombatRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.victimGuid = victimGuid;
    relay.initialAggro = initialAggro;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionLootRelay(uint32 partitionId, ObjectGuid const& creatureGuid, ObjectGuid const& unitGuid, bool withGroup)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionLootRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} loot relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionLootRelay relay;
    relay.creatureGuid = creatureGuid;
    relay.unitGuid = unitGuid;
    relay.withGroup = withGroup;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionDynObjectRelay(uint32 partitionId, ObjectGuid const& dynObjGuid, uint8 action)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionDynObjectRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} dynobject relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionDynObjectRelay relay;
    relay.dynObjGuid = dynObjGuid;
    relay.action = action;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionMinionRelay(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& minionGuid, bool apply)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionMinionRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} minion relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionMinionRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.minionGuid = minionGuid;
    relay.apply = apply;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionCharmRelay(uint32 partitionId, ObjectGuid const& charmerGuid, ObjectGuid const& targetGuid, uint8 charmType, uint32 auraSpellId, bool apply)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionCharmRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} charm relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionCharmRelay relay;
    relay.charmerGuid = charmerGuid;
    relay.targetGuid = targetGuid;
    relay.charmType = charmType;
    relay.auraSpellId = auraSpellId;
    relay.apply = apply;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionGameObjectRelay(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& gameObjGuid, uint32 spellId, bool del, uint8 action)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionGameObjectRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} gameobject relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionGameObjectRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.gameObjGuid = gameObjGuid;
    relay.spellId = spellId;
    relay.del = del;
    relay.action = action;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionCombatStateRelay(uint32 partitionId, ObjectGuid const& unitGuid, ObjectGuid const& enemyGuid, bool pvp, uint32 duration)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionCombatStateRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} combat-state relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionCombatStateRelay relay;
    relay.unitGuid = unitGuid;
    relay.enemyGuid = enemyGuid;
    relay.pvp = pvp;
    relay.duration = duration;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionAttackRelay(uint32 partitionId, ObjectGuid const& attackerGuid, ObjectGuid const& victimGuid, bool meleeAttack)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionAttackRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} attack relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionAttackRelay relay;
    relay.attackerGuid = attackerGuid;
    relay.victimGuid = victimGuid;
    relay.meleeAttack = meleeAttack;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionEvadeRelay(uint32 partitionId, ObjectGuid const& unitGuid, uint8 reason)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionEvadeRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} evade relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionEvadeRelay relay;
    relay.unitGuid = unitGuid;
    relay.reason = reason;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionTauntApply(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& taunterGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionTauntRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} taunt relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionTauntRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.taunterGuid = taunterGuid;
    relay.action = 1;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionTauntFade(uint32 partitionId, ObjectGuid const& ownerGuid, ObjectGuid const& taunterGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionTauntRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} taunt relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionTauntRelay relay;
    relay.ownerGuid = ownerGuid;
    relay.taunterGuid = taunterGuid;
    relay.action = 2;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionMotionRelay(uint32 partitionId, PartitionMotionRelay const& relay)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionMotionRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} motion relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    queue.push_back(relay);
}

void Map::QueuePartitionProcRelay(uint32 partitionId, ObjectGuid const& actorGuid, ObjectGuid const& targetGuid, bool isVictim, uint32 procFlag, uint32 procExtra, uint32 amount, WeaponAttackType attackType, uint32 procSpellId, uint32 procAuraId, int8 procAuraEffectIndex, uint32 procPhase)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    if (!procFlag)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionProcRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} proc relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionProcRelay relay;
    relay.actorGuid = actorGuid;
    relay.targetGuid = targetGuid;
    relay.isVictim = isVictim;
    relay.procFlag = procFlag;
    relay.procExtra = procExtra;
    relay.amount = amount;
    relay.attackType = attackType;
    relay.procSpellId = procSpellId;
    relay.procAuraId = procAuraId;
    relay.procAuraEffectIndex = procAuraEffectIndex;
    relay.procPhase = procPhase;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionAuraRelay(uint32 partitionId, ObjectGuid const& casterGuid, ObjectGuid const& targetGuid, uint32 spellId, uint8 effMask, bool apply, AuraRemoveMode removeMode)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionAuraRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} aura relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionAuraRelay relay;
    relay.casterGuid = casterGuid;
    relay.targetGuid = targetGuid;
    relay.spellId = spellId;
    relay.effMask = effMask;
    relay.apply = apply;
    relay.removeMode = removeMode;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionPathRelay(uint32 partitionId, ObjectGuid const& moverGuid, ObjectGuid const& targetGuid)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionPathRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} path relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionPathRelay relay;
    relay.moverGuid = moverGuid;
    relay.targetGuid = targetGuid;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionPointRelay(uint32 partitionId, ObjectGuid const& moverGuid, uint32 pointId, float x, float y, float z, ForcedMovement forcedMovement, float speed, float orientation, bool generatePath, bool forceDestination, MovementSlot slot, bool hasAnimTier, AnimTier animTier)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionPointRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} point relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionPointRelay relay;
    relay.moverGuid = moverGuid;
    relay.pointId = pointId;
    relay.x = x;
    relay.y = y;
    relay.z = z;
    relay.forcedMovement = forcedMovement;
    relay.speed = speed;
    relay.orientation = orientation;
    relay.generatePath = generatePath;
    relay.forceDestination = forceDestination;
    relay.slot = slot;
    relay.hasAnimTier = hasAnimTier;
    relay.animTier = animTier;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionAssistRelay(uint32 partitionId, ObjectGuid const& moverGuid, float x, float y, float z)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionAssistRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} assist relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionAssistRelay relay;
    relay.moverGuid = moverGuid;
    relay.x = x;
    relay.y = y;
    relay.z = z;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

void Map::QueuePartitionAssistDistractRelay(uint32 partitionId, ObjectGuid const& moverGuid, uint32 timeMs)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
    auto& queue = _partitionAssistDistractRelays[partitionId];
    if (queue.size() >= kPartitionRelayLimit)
    {
        LOG_WARN("maps.partition", "Map {} partition {} assist-distract relay queue full ({}), dropping relay", GetId(), partitionId, kPartitionRelayLimit);
        return;
    }

    PartitionAssistDistractRelay relay;
    relay.moverGuid = moverGuid;
    relay.timeMs = timeMs;
    relay.queuedMs = GameTime::GetGameTimeMS().count();
    queue.push_back(relay);
}

uint32 Map::GetActivePartitionContext() const
{
    auto it = sActivePartitionContext.find(this);
    if (it == sActivePartitionContext.end())
        return 0;
    return it->second;
}

bool Map::IsProcessingPartitionRelays() const
{
    return sProcessingPartitionRelays;
}

std::mutex& Map::GetRelayLock(uint32 partitionId)
{
    return _relayLocks[partitionId % kRelayLockStripes];
}

void Map::SetActivePartitionContext(uint32 partitionId)
{
    if (partitionId == 0)
    {
        sActivePartitionContext.erase(this);
        return;
    }

    sActivePartitionContext[this] = partitionId;
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

void Map::ProcessPartitionRelays(uint32 partitionId)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    struct RelayGuard
    {
        RelayGuard() { sProcessingPartitionRelays = true; }
        ~RelayGuard() { sProcessingPartitionRelays = false; }
    } guard;

    std::vector<PartitionThreatRelay> threatRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto threatIt = _partitionThreatRelays.find(partitionId);
        if (threatIt != _partitionThreatRelays.end())
        {
            threatRelays.swap(threatIt->second);
            threatIt->second.reserve(std::min<size_t>(threatRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!threatRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionThreatRelay const& relay : threatRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            Unit* victim = GetUnitByGuid(relay.victimGuid);
            if (!owner || !victim)
                continue;

            SpellInfo const* threatSpell = relay.spellId ? sSpellMgr->GetSpellInfo(relay.spellId) : nullptr;
            owner->AddThreat(victim, relay.threat, relay.schoolMask, threatSpell);
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!threatRelays.empty())
        {
            uint64 avgLatency = totalLatency / threatRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "threat"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "threat"));
        }
    }

    std::vector<PartitionThreatActionRelay> threatActionRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto threatActionIt = _partitionThreatActionRelays.find(partitionId);
        if (threatActionIt != _partitionThreatActionRelays.end())
        {
            threatActionRelays.swap(threatActionIt->second);
            threatActionIt->second.reserve(std::min<size_t>(threatActionRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!threatActionRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionThreatActionRelay const& relay : threatActionRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            if (!owner)
                continue;

            if (relay.action == 1)
                owner->GetThreatMgr().ClearAllThreat();
            else if (relay.action == 2)
                owner->GetThreatMgr().ResetAllThreat();

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!threatActionRelays.empty())
        {
            uint64 avgLatency = totalLatency / threatActionRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "threat_action"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "threat_action"));
        }
    }

    std::vector<PartitionProcRelay> procRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto procIt = _partitionProcRelays.find(partitionId);
        if (procIt != _partitionProcRelays.end())
        {
            procRelays.swap(procIt->second);
            procIt->second.reserve(std::min<size_t>(procRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!procRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionProcRelay const& relay : procRelays)
        {
            Unit* actor = GetUnitByGuid(relay.actorGuid);
            Unit* target = GetUnitByGuid(relay.targetGuid);
            if (!actor || !target)
                continue;

            SpellInfo const* procSpellInfo = relay.procSpellId ? sSpellMgr->GetSpellInfo(relay.procSpellId) : nullptr;
            SpellInfo const* procAuraInfo = relay.procAuraId ? sSpellMgr->GetSpellInfo(relay.procAuraId) : nullptr;
            if (relay.isVictim)
                actor->ProcDamageAndSpellFor(true, target, relay.procFlag, relay.procExtra, relay.attackType, procSpellInfo, relay.amount, procAuraInfo, relay.procAuraEffectIndex, nullptr, nullptr, nullptr, relay.procPhase);
            else
                actor->ProcDamageAndSpellFor(false, target, relay.procFlag, relay.procExtra, relay.attackType, procSpellInfo, relay.amount, procAuraInfo, relay.procAuraEffectIndex, nullptr, nullptr, nullptr, relay.procPhase);
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!procRelays.empty())
        {
            uint64 avgLatency = totalLatency / procRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "proc"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "proc"));
        }
    }

    std::vector<PartitionAuraRelay> auraRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto auraIt = _partitionAuraRelays.find(partitionId);
        if (auraIt != _partitionAuraRelays.end())
        {
            auraRelays.swap(auraIt->second);
            auraIt->second.reserve(std::min<size_t>(auraRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!auraRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionAuraRelay const& relay : auraRelays)
        {
            Unit* caster = GetUnitByGuid(relay.casterGuid);
            Unit* target = GetUnitByGuid(relay.targetGuid);
            if (!target)
                continue;

            if (relay.apply)
            {
                if (!caster)
                    continue;

                if (target->HasAura(relay.spellId, relay.casterGuid))
                    continue;

                SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(relay.spellId);
                if (!spellInfo)
                    continue;

                caster->AddAura(spellInfo, relay.effMask, target);
            }
            else
            {
                target->RemoveAura(relay.spellId, relay.casterGuid, relay.effMask, relay.removeMode);
            }
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!auraRelays.empty())
        {
            uint64 avgLatency = totalLatency / auraRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "aura"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "aura"));
        }
    }

    std::vector<PartitionPathRelay> pathRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto pathIt = _partitionPathRelays.find(partitionId);
        if (pathIt != _partitionPathRelays.end())
        {
            pathRelays.swap(pathIt->second);
            pathIt->second.reserve(std::min<size_t>(pathRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!pathRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionPathRelay const& relay : pathRelays)
        {
            Unit* mover = GetUnitByGuid(relay.moverGuid);
            Unit* target = GetUnitByGuid(relay.targetGuid);
            if (!mover || !target || !mover->IsInWorld() || !mover->GetMotionMaster())
                continue;

            uint32 moverPartition = GetPartitionIdForUnit(mover);
            if (moverPartition && moverPartition != partitionId)
            {
                QueuePartitionPathRelay(moverPartition, relay.moverGuid, relay.targetGuid);
                continue;
            }

            mover->GetMotionMaster()->MoveChase(target);
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!pathRelays.empty())
        {
            uint64 avgLatency = totalLatency / pathRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "path"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "path"));
        }
    }

    std::vector<PartitionPointRelay> pointRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto pointIt = _partitionPointRelays.find(partitionId);
        if (pointIt != _partitionPointRelays.end())
        {
            pointRelays.swap(pointIt->second);
            pointIt->second.reserve(std::min<size_t>(pointRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!pointRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionPointRelay const& relay : pointRelays)
        {
            Unit* mover = GetUnitByGuid(relay.moverGuid);
            if (!mover || !mover->IsInWorld() || !mover->GetMotionMaster())
                continue;

            uint32 moverPartition = GetPartitionIdForUnit(mover);
            if (moverPartition && moverPartition != partitionId)
            {
                QueuePartitionPointRelay(moverPartition, relay.moverGuid, relay.pointId, relay.x, relay.y, relay.z,
                    relay.forcedMovement, relay.speed, relay.orientation, relay.generatePath, relay.forceDestination,
                    relay.slot, relay.hasAnimTier, relay.animTier);
                continue;
            }

            std::optional<AnimTier> animTier;
            if (relay.hasAnimTier)
                animTier = relay.animTier;

            mover->GetMotionMaster()->MovePoint(relay.pointId, relay.x, relay.y, relay.z, relay.forcedMovement, relay.speed, relay.orientation, relay.generatePath, relay.forceDestination, relay.slot, animTier);
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!pointRelays.empty())
        {
            uint64 avgLatency = totalLatency / pointRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "point"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "point"));
        }
    }

    std::vector<PartitionMotionRelay> motionRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto motionIt = _partitionMotionRelays.find(partitionId);
        if (motionIt != _partitionMotionRelays.end())
        {
            motionRelays.swap(motionIt->second);
            motionIt->second.reserve(std::min<size_t>(motionRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!motionRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionMotionRelay const& relay : motionRelays)
        {
            Unit* mover = GetUnitByGuid(relay.moverGuid);
            if (!mover || !mover->IsInWorld() || !mover->GetMotionMaster())
                continue;

            uint32 moverPartition = GetPartitionIdForUnit(mover);
            if (moverPartition && moverPartition != partitionId)
            {
                QueuePartitionMotionRelay(moverPartition, relay);
                continue;
            }

            switch (relay.action)
            {
                case MOTION_RELAY_JUMP:
                {
                    Unit* target = relay.targetGuid ? GetUnitByGuid(relay.targetGuid) : nullptr;
                    mover->GetMotionMaster()->MoveJump(relay.x, relay.y, relay.z, relay.speedXY, relay.speedZ, relay.id, target);
                    break;
                }
                case MOTION_RELAY_FALL:
                {
                    mover->GetMotionMaster()->MoveFall(relay.id, relay.addFlagForNPC);
                    break;
                }
                case MOTION_RELAY_CHARGE:
                {
                    Movement::PointsArray pathPoints;
                    if (!relay.pathPoints.empty())
                    {
                        pathPoints.assign(relay.pathPoints.begin(), relay.pathPoints.end());
                        mover->GetMotionMaster()->MoveCharge(relay.x, relay.y, relay.z, relay.speed, relay.id, &pathPoints, relay.generatePath, relay.orientation, relay.targetGuid);
                    }
                    else
                    {
                        mover->GetMotionMaster()->MoveCharge(relay.x, relay.y, relay.z, relay.speed, relay.id, nullptr, relay.generatePath, relay.orientation, relay.targetGuid);
                    }
                    break;
                }
                case MOTION_RELAY_CHARGE_PATH:
                {
                    Movement::PointsArray pathPoints;
                    pathPoints.assign(relay.pathPoints.begin(), relay.pathPoints.end());
                    if (pathPoints.empty())
                        break;
                    mover->GetMotionMaster()->MoveCharge(relay.x, relay.y, relay.z, relay.speed, relay.id, nullptr, false, relay.orientation, relay.targetGuid);

                    Movement::MoveSplineInit init(mover);
                    init.MovebyPath(pathPoints);
                    init.SetVelocity(relay.speed);
                    init.Launch();
                    break;
                }
                case MOTION_RELAY_FLEE:
                {
                    Unit* enemy = relay.targetGuid ? GetUnitByGuid(relay.targetGuid) : nullptr;
                    if (enemy)
                        mover->GetMotionMaster()->MoveFleeing(enemy, relay.timeMs);
                    break;
                }
                case MOTION_RELAY_DISTRACT:
                {
                    mover->GetMotionMaster()->MoveDistract(relay.timeMs);
                    break;
                }
                case MOTION_RELAY_BACKWARDS:
                {
                    Unit* target = relay.targetGuid ? GetUnitByGuid(relay.targetGuid) : nullptr;
                    if (target)
                        mover->GetMotionMaster()->MoveBackwards(target, relay.dist);
                    break;
                }
                case MOTION_RELAY_FORWARDS:
                {
                    Unit* target = relay.targetGuid ? GetUnitByGuid(relay.targetGuid) : nullptr;
                    if (target)
                        mover->GetMotionMaster()->MoveForwards(target, relay.dist);
                    break;
                }
                case MOTION_RELAY_CIRCLE:
                {
                    Unit* target = relay.targetGuid ? GetUnitByGuid(relay.targetGuid) : nullptr;
                    if (target)
                        mover->GetMotionMaster()->MoveCircleTarget(target);
                    break;
                }
                case MOTION_RELAY_SPLINE_PATH:
                {
                    Movement::PointsArray pathPoints;
                    pathPoints.assign(relay.pathPoints.begin(), relay.pathPoints.end());
                    if (pathPoints.empty())
                        break;
                    mover->GetMotionMaster()->MoveSplinePath(&pathPoints, relay.forcedMovement);
                    break;
                }
                case MOTION_RELAY_PATH:
                {
                    mover->GetMotionMaster()->MovePath(relay.pathId, relay.forcedMovement, static_cast<PathSource>(relay.pathSource));
                    break;
                }
                case MOTION_RELAY_LAND:
                {
                    mover->GetMotionMaster()->MoveLand(relay.id, relay.x, relay.y, relay.z, relay.speed);
                    break;
                }
                case MOTION_RELAY_TAKEOFF:
                {
                    mover->GetMotionMaster()->MoveTakeoff(relay.id, relay.x, relay.y, relay.z, relay.speed, relay.skipAnimation);
                    break;
                }
                case MOTION_RELAY_KNOCKBACK:
                {
                    mover->GetMotionMaster()->MoveKnockbackFrom(relay.x, relay.y, relay.speedXY, relay.speedZ);
                    break;
                }
                case MOTION_RELAY_STOP:
                {
                    mover->StopMoving();
                    break;
                }
                case MOTION_RELAY_STOP_ON_POS:
                {
                    mover->StopMovingOnCurrentPos();
                    break;
                }
                case MOTION_RELAY_FACE_ORIENTATION:
                {
                    mover->SetFacingTo(relay.orientation);
                    break;
                }
                case MOTION_RELAY_FACE_OBJECT:
                {
                    WorldObject* target = relay.targetGuid ? ObjectAccessor::GetWorldObject(*mover, relay.targetGuid) : nullptr;
                    if (target)
                        mover->SetFacingToObject(target, Milliseconds(relay.timeMs));
                    break;
                }
                case MOTION_RELAY_MONSTER_MOVE:
                {
                    mover->MonsterMoveWithSpeed(relay.x, relay.y, relay.z, relay.speed);
                    break;
                }
                case MOTION_RELAY_TRANSPORT_ENTER:
                {
                    Movement::MoveSplineInit init(mover);
                    init.DisableTransportPathTransformations();
                    init.MoveTo(relay.x, relay.y, relay.z, false, true);
                    init.SetFacing(relay.orientation);
                    init.SetTransportEnter();
                    init.Launch();
                    break;
                }
                case MOTION_RELAY_TRANSPORT_EXIT:
                {
                    Movement::MoveSplineInit init(mover);
                    init.MoveTo(relay.x, relay.y, relay.z);
                    init.SetFacing(relay.orientation);
                    init.SetTransportExit();
                    init.Launch();
                    if (relay.disableSpline)
                        mover->DisableSpline();
                    if (relay.speedXY > 0.0f)
                        mover->KnockbackFrom(relay.srcX, relay.srcY, relay.speedXY, relay.speedZ);
                    if (relay.spellId)
                        mover->CastSpell(mover, relay.spellId, true);
                    break;
                }
                case MOTION_RELAY_PASSENGER_RELOCATE:
                {
                    mover->UpdatePosition(relay.x, relay.y, relay.z, relay.orientation);
                    break;
                }
                default:
                    break;
            }

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!motionRelays.empty())
        {
            uint64 avgLatency = totalLatency / motionRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "motion"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "motion"));
        }
    }

    std::vector<PartitionAssistRelay> assistRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto assistIt = _partitionAssistRelays.find(partitionId);
        if (assistIt != _partitionAssistRelays.end())
        {
            assistRelays.swap(assistIt->second);
            assistIt->second.reserve(std::min<size_t>(assistRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!assistRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionAssistRelay const& relay : assistRelays)
        {
            Unit* mover = GetUnitByGuid(relay.moverGuid);
            if (!mover || !mover->IsInWorld() || !mover->GetMotionMaster())
                continue;

            uint32 moverPartition = GetPartitionIdForUnit(mover);
            if (moverPartition && moverPartition != partitionId)
            {
                QueuePartitionAssistRelay(moverPartition, relay.moverGuid, relay.x, relay.y, relay.z);
                continue;
            }

            mover->GetMotionMaster()->MoveSeekAssistance(relay.x, relay.y, relay.z);
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!assistRelays.empty())
        {
            uint64 avgLatency = totalLatency / assistRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "assist"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "assist"));
        }
    }

    std::vector<PartitionAssistDistractRelay> distractRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto distractIt = _partitionAssistDistractRelays.find(partitionId);
        if (distractIt != _partitionAssistDistractRelays.end())
        {
            distractRelays.swap(distractIt->second);
            distractIt->second.reserve(std::min<size_t>(distractRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!distractRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionAssistDistractRelay const& relay : distractRelays)
        {
            Unit* mover = GetUnitByGuid(relay.moverGuid);
            if (!mover || !mover->IsInWorld() || !mover->GetMotionMaster())
                continue;

            uint32 moverPartition = GetPartitionIdForUnit(mover);
            if (moverPartition && moverPartition != partitionId)
            {
                QueuePartitionAssistDistractRelay(moverPartition, relay.moverGuid, relay.timeMs);
                continue;
            }

            mover->GetMotionMaster()->MoveSeekAssistanceDistract(relay.timeMs);
            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!distractRelays.empty())
        {
            uint64 avgLatency = totalLatency / distractRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "assist_distract"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "assist_distract"));
        }
    }

    // BUG-1 FIX: Process threat-target-action relays (were previously queued but never consumed)
    std::vector<PartitionThreatTargetActionRelay> threatTargetRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto threatTargetIt = _partitionThreatTargetActionRelays.find(partitionId);
        if (threatTargetIt != _partitionThreatTargetActionRelays.end())
        {
            threatTargetRelays.swap(threatTargetIt->second);
            threatTargetIt->second.reserve(std::min<size_t>(threatTargetRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!threatTargetRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionThreatTargetActionRelay const& relay : threatTargetRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            Unit* target = GetUnitByGuid(relay.targetGuid);
            if (!owner || !target)
                continue;

            if (relay.action == 1) // ClearTarget
                owner->GetThreatMgr().ModifyThreatByPercent(target, -100);
            else if (relay.action == 2) // ResetTarget
                owner->GetThreatMgr().ModifyThreatByPercent(target, -100);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!threatTargetRelays.empty())
        {
            uint64 avgLatency = totalLatency / threatTargetRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "threat_target_action"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "threat_target_action"));
        }
    }

    std::vector<PartitionCombatRelay> combatRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto combatIt = _partitionCombatRelays.find(partitionId);
        if (combatIt != _partitionCombatRelays.end())
        {
            combatRelays.swap(combatIt->second);
            combatIt->second.reserve(std::min<size_t>(combatRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!combatRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionCombatRelay const& relay : combatRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            Unit* victim = GetUnitByGuid(relay.victimGuid);
            if (!owner || !victim)
                continue;

            owner->CombatStart(victim, relay.initialAggro);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!combatRelays.empty())
        {
            uint64 avgLatency = totalLatency / combatRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "combat"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "combat"));
        }
    }

    std::vector<PartitionLootRelay> lootRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto lootIt = _partitionLootRelays.find(partitionId);
        if (lootIt != _partitionLootRelays.end())
        {
            lootRelays.swap(lootIt->second);
            lootIt->second.reserve(std::min<size_t>(lootRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!lootRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionLootRelay const& relay : lootRelays)
        {
            Creature* creature = GetCreature(relay.creatureGuid);
            if (!creature)
                continue;

            Unit* unit = relay.unitGuid ? GetUnitByGuid(relay.unitGuid) : nullptr;
            creature->SetLootRecipient(unit, relay.withGroup);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!lootRelays.empty())
        {
            uint64 avgLatency = totalLatency / lootRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "loot"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "loot"));
        }
    }

    std::vector<PartitionDynObjectRelay> dynObjectRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto dynObjIt = _partitionDynObjectRelays.find(partitionId);
        if (dynObjIt != _partitionDynObjectRelays.end())
        {
            dynObjectRelays.swap(dynObjIt->second);
            dynObjIt->second.reserve(std::min<size_t>(dynObjectRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!dynObjectRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionDynObjectRelay const& relay : dynObjectRelays)
        {
            DynamicObject* dynObj = GetDynamicObject(relay.dynObjGuid);
            if (!dynObj)
                continue;

            if (relay.action == 1)
                dynObj->Remove();

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!dynObjectRelays.empty())
        {
            uint64 avgLatency = totalLatency / dynObjectRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "dynobject"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "dynobject"));
        }
    }

    std::vector<PartitionMinionRelay> minionRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto minionIt = _partitionMinionRelays.find(partitionId);
        if (minionIt != _partitionMinionRelays.end())
        {
            minionRelays.swap(minionIt->second);
            minionIt->second.reserve(std::min<size_t>(minionRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!minionRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionMinionRelay const& relay : minionRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            Unit* minionUnit = GetUnitByGuid(relay.minionGuid);
            Creature* minionCreature = minionUnit ? minionUnit->ToCreature() : nullptr;
            Minion* minion = (minionCreature && minionCreature->HasUnitTypeMask(UNIT_MASK_MINION)) ? static_cast<Minion*>(minionCreature) : nullptr;
            if (!owner || !minion)
                continue;

            uint32 ownerPartition = GetPartitionIdForUnit(owner);
            if (ownerPartition && ownerPartition != partitionId)
            {
                QueuePartitionMinionRelay(ownerPartition, relay.ownerGuid, relay.minionGuid, relay.apply);
                continue;
            }

            owner->SetMinion(minion, relay.apply);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!minionRelays.empty())
        {
            uint64 avgLatency = totalLatency / minionRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "minion"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "minion"));
        }
    }

    std::vector<PartitionCharmRelay> charmRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto charmIt = _partitionCharmRelays.find(partitionId);
        if (charmIt != _partitionCharmRelays.end())
        {
            charmRelays.swap(charmIt->second);
            charmIt->second.reserve(std::min<size_t>(charmRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!charmRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionCharmRelay const& relay : charmRelays)
        {
            Unit* charmer = GetUnitByGuid(relay.charmerGuid);
            Unit* target = GetUnitByGuid(relay.targetGuid);
            if (!charmer || !target)
                continue;

            uint32 targetPartition = GetPartitionIdForUnit(target);
            if (targetPartition && targetPartition != partitionId)
            {
                QueuePartitionCharmRelay(targetPartition, relay.charmerGuid, relay.targetGuid, relay.charmType, relay.auraSpellId, relay.apply);
                continue;
            }

            if (relay.apply)
            {
                if (relay.auraSpellId && !target->HasAura(relay.auraSpellId, relay.charmerGuid))
                    continue;
                target->SetCharmedBy(charmer, static_cast<CharmType>(relay.charmType), nullptr);
            }
            else
            {
                target->RemoveCharmedBy(charmer);
            }

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!charmRelays.empty())
        {
            uint64 avgLatency = totalLatency / charmRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "charm"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "charm"));
        }
    }

    std::vector<PartitionGameObjectRelay> gameObjectRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto goIt = _partitionGameObjectRelays.find(partitionId);
        if (goIt != _partitionGameObjectRelays.end())
        {
            gameObjectRelays.swap(goIt->second);
            goIt->second.reserve(std::min<size_t>(gameObjectRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!gameObjectRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionGameObjectRelay const& relay : gameObjectRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            if (!owner)
                continue;

            uint32 ownerPartition = GetPartitionIdForUnit(owner);
            if (ownerPartition && ownerPartition != partitionId)
            {
                QueuePartitionGameObjectRelay(ownerPartition, relay.ownerGuid, relay.gameObjGuid, relay.spellId, relay.del, relay.action);
                continue;
            }

            if (relay.action == 1)
            {
                if (relay.gameObjGuid)
                {
                    if (GameObject* go = GetGameObject(relay.gameObjGuid))
                        owner->RemoveGameObject(go, relay.del);
                }
            }
            else if (relay.action == 2)
            {
                owner->RemoveGameObject(relay.spellId, relay.del);
            }
            else if (relay.action == 3)
            {
                owner->RemoveAllGameObjects();
            }

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!gameObjectRelays.empty())
        {
            uint64 avgLatency = totalLatency / gameObjectRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "gameobject"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "gameobject"));
        }
    }

    std::vector<PartitionCombatStateRelay> combatStateRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto combatStateIt = _partitionCombatStateRelays.find(partitionId);
        if (combatStateIt != _partitionCombatStateRelays.end())
        {
            combatStateRelays.swap(combatStateIt->second);
            combatStateIt->second.reserve(std::min<size_t>(combatStateRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!combatStateRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionCombatStateRelay const& relay : combatStateRelays)
        {
            Unit* unit = GetUnitByGuid(relay.unitGuid);
            if (!unit)
                continue;

            Unit* enemy = relay.enemyGuid ? GetUnitByGuid(relay.enemyGuid) : nullptr;
            unit->SetInCombatState(relay.pvp, enemy, relay.duration);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!combatStateRelays.empty())
        {
            uint64 avgLatency = totalLatency / combatStateRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "combat_state"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "combat_state"));
        }
    }

    std::vector<PartitionAttackRelay> attackRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto attackIt = _partitionAttackRelays.find(partitionId);
        if (attackIt != _partitionAttackRelays.end())
        {
            attackRelays.swap(attackIt->second);
            attackIt->second.reserve(std::min<size_t>(attackRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!attackRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionAttackRelay const& relay : attackRelays)
        {
            Unit* attacker = GetUnitByGuid(relay.attackerGuid);
            Unit* victim = GetUnitByGuid(relay.victimGuid);
            if (!attacker || !victim)
                continue;

            attacker->Attack(victim, relay.meleeAttack);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!attackRelays.empty())
        {
            uint64 avgLatency = totalLatency / attackRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "attack"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "attack"));
        }
    }

    std::vector<PartitionEvadeRelay> evadeRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto evadeIt = _partitionEvadeRelays.find(partitionId);
        if (evadeIt != _partitionEvadeRelays.end())
        {
            evadeRelays.swap(evadeIt->second);
            evadeIt->second.reserve(std::min<size_t>(evadeRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!evadeRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionEvadeRelay const& relay : evadeRelays)
        {
            Unit* unit = GetUnitByGuid(relay.unitGuid);
            Creature* creature = unit ? unit->ToCreature() : nullptr;
            if (!creature || !creature->IsAIEnabled)
                continue;

            creature->AI()->EnterEvadeMode(static_cast<CreatureAI::EvadeReason>(relay.reason));

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!evadeRelays.empty())
        {
            uint64 avgLatency = totalLatency / evadeRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "evade"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "evade"));
        }
    }

    // BUG-2 FIX: Process taunt relays (were previously in dead code in UpdateNonPlayerObjects)
    std::vector<PartitionTauntRelay> tauntRelays;
    {
        std::lock_guard<std::mutex> lock(GetRelayLock(partitionId));
        auto tauntIt = _partitionTauntRelays.find(partitionId);
        if (tauntIt != _partitionTauntRelays.end())
        {
            tauntRelays.swap(tauntIt->second);
            tauntIt->second.reserve(std::min<size_t>(tauntRelays.size(), kPartitionRelayLimit));
        }
    }
    if (!tauntRelays.empty())
    {
        uint64 nowMs = GameTime::GetGameTimeMS().count();
        uint64 totalLatency = 0;
        uint64 maxLatency = 0;
        for (PartitionTauntRelay const& relay : tauntRelays)
        {
            Unit* owner = GetUnitByGuid(relay.ownerGuid);
            Unit* taunter = GetUnitByGuid(relay.taunterGuid);
            if (!owner || !taunter)
                continue;

            if (relay.action == 1)
                owner->GetThreatMgr().tauntApply(taunter);
            else if (relay.action == 2)
                owner->GetThreatMgr().tauntFadeOut(taunter);

            if (relay.queuedMs)
            {
                uint64 latency = nowMs - relay.queuedMs;
                totalLatency += latency;
                maxLatency = std::max(maxLatency, latency);
            }
        }
        if (!tauntRelays.empty())
        {
            uint64 avgLatency = totalLatency / tauntRelays.size();
            METRIC_VALUE("partition_relay_latency_ms", avgLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "taunt"));
            METRIC_VALUE("partition_relay_latency_max_ms", maxLatency,
                METRIC_TAG("map_id", std::to_string(GetId())),
                METRIC_TAG("partition_id", std::to_string(partitionId)),
                METRIC_TAG("type", "taunt"));
        }
    }
}

void Map::Update(const uint32 t_diff, const uint32 s_diff, bool  /*thread*/)
{
    ++_updateCounter;
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
        std::unique_lock<std::shared_mutex> lock(_dynamicTreeLock);
        _dynamicTree.update(t_diff);
    }

    bool runSessionUpdatesInWorkers = _isPartitioned && _useParallelPartitions && t_diff;

    // Update world sessions and players
    for (m_mapRefIter = m_mapRefMgr.begin(); m_mapRefIter != m_mapRefMgr.end(); ++m_mapRefIter)
    {
        Player* player = m_mapRefIter->GetSource();
        if (player && player->IsInWorld())
        {
            // Update session on the main thread unless partition workers handle it.
            if (!runSessionUpdatesInWorkers)
            {
                WorldSession* session = player->GetSession();
                MapSessionFilter updater(session);
                session->Update(s_diff, updater);
            }

            // update players at tick
            if (!t_diff)
                player->Update(s_diff);
        }
    }

    Events.Update(t_diff);

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
            SchedulePartitionUpdates(t_diff, s_diff);
            _markNearbyCellsThisTick.store(false, std::memory_order_relaxed);

            // Deferred ownership updates must run on the main thread after all
            // workers complete so they don't race with CollectPartitionedUpdatableGuids.
            ApplyQueuedPartitionedOwnershipUpdates();
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
    }

    ProcessDeferredVisibilityUpdates();
    SendObjectUpdates();

    ///- Process necessary scripts
    {
        bool expected = false;
        if (i_scriptLock.compare_exchange_strong(expected, true))
        {
            ScriptsProcess();
            i_scriptLock.store(false);
        }
    }

    MoveAllCreaturesInMoveList();
    MoveAllGameObjectsInMoveList();
    MoveAllDynamicObjectsInMoveList();

    HandleDelayedVisibility();

    UpdateWeather(t_diff);
    UpdateExpiredCorpses(t_diff);

    sScriptMgr->OnMapUpdate(this, t_diff);

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

void Map::SchedulePartitionUpdates(uint32 t_diff, uint32 s_diff)
{
    if (!_isPartitioned || !_useParallelPartitions)
        return;

    MapUpdater* updater = sMapMgr->GetMapUpdater();
    if (!updater || !updater->activated())
    {
        LOG_WARN("map.partition", "Map {}: SchedulePartitionUpdates called but MapUpdater is not active", GetId());
        return;
    }

    uint32 partitionCount = sPartitionMgr->GetPartitionCount(GetId());
    if (partitionCount == 0)
        partitionCount = 1;

    FlushPendingUpdateListAdds();
    BuildPartitionPlayerBuckets();

    LOG_DEBUG("map.partition", "Map {}: Scheduling {} partition updates in parallel", GetId(), partitionCount);

    std::atomic<uint32> remaining{partitionCount};

    for (uint32 partitionId = 1; partitionId <= partitionCount; ++partitionId)
    {
        updater->schedule_partition_update(*this, partitionId, t_diff, s_diff, [&remaining]()
        {
            remaining.fetch_sub(1, std::memory_order_acq_rel);
        });
    }

    // Cooperative wait: run queued tasks to avoid worker thread starvation.
    updater->run_partition_tasks_until([&remaining]()
    {
        return remaining.load(std::memory_order_acquire) == 0;
    });

    ClearPartitionPlayerBuckets();
}

void Map::UpdateNonPlayerObjects(uint32 const diff)
{
    FlushPendingUpdateListAdds();

    bool recheck = _updatableObjectListRecheckTimer.Passed();

    if (_isPartitioned)
    {
        uint32 partitionCount = sPartitionMgr->GetPartitionCount(GetId());
        if (partitionCount == 0)
            partitionCount = 1;

        std::vector<uint32> partitionCreatureCounts(partitionCount, 0);
        std::vector<uint32> partitionBoundaryObjectCounts(partitionCount, 0);

        for (uint32 partitionId = 1; partitionId <= partitionCount; ++partitionId)
        {
            SetActivePartitionContext(partitionId);
            uint32 index = partitionId - 1;
            std::vector<PartitionManager::BoundaryPositionUpdate> boundaryUpdates;
            std::vector<ObjectGuid> boundaryUnregisters;
            std::vector<ObjectGuid> boundaryOverrides;
            std::vector<std::pair<ObjectGuid, uint8>> objects;
            CollectPartitionedUpdatableGuids(partitionId, objects);
            boundaryUpdates.reserve(objects.size());
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

                obj->Update(diff);

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

    UpdatableMapObject* mapUpdatableObject = dynamic_cast<UpdatableMapObject*>(obj);
    {
        std::lock_guard<std::mutex> lock(_pendingUpdateListLock);
        if (!mapUpdatableObject || mapUpdatableObject->GetUpdateState() != UpdatableMapObject::UpdateState::NotUpdating)
            return;
        mapUpdatableObject->SetUpdateState(UpdatableMapObject::UpdateState::PendingAdd);
        _pendingAddUpdatableObjectList.insert(obj);
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
        UpdatableMapObject* mapUpdatableObject = dynamic_cast<UpdatableMapObject*>(obj);
        if (!mapUpdatableObject || mapUpdatableObject->GetUpdateState() != UpdatableMapObject::UpdateState::PendingAdd)
            continue;
        _AddObjectToUpdateList(obj);
    }
}

// Internal use only
void Map::_AddObjectToUpdateList(WorldObject* obj)
{
    UpdatableMapObject* mapUpdatableObject = dynamic_cast<UpdatableMapObject*>(obj);
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
    UpdatableMapObject* mapUpdatableObject = dynamic_cast<UpdatableMapObject*>(obj);
    if (!mapUpdatableObject)
        return;

    {
        std::lock_guard<std::mutex> lock(_updatableObjectListLock);

        // Re-check state under lock — another partition worker may have already removed this object.
        if (mapUpdatableObject->GetUpdateState() != UpdatableMapObject::UpdateState::Updating)
            return;

        if (obj != _updatableObjectList.back())
        {
            UpdatableMapObject* backObj = dynamic_cast<UpdatableMapObject*>(_updatableObjectList.back());
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

    auto lock = AcquirePartitionedUpdateListWriteLock();
    auto it = _partitionedUpdatableIndex.find(obj);
    if (it == _partitionedUpdatableIndex.end())
        return;

    uint32 partitionId = it->second.partitionId;
    size_t index = it->second.index;
    auto listIt = _partitionedUpdatableObjectLists.find(partitionId);
    if (listIt == _partitionedUpdatableObjectLists.end())
    {
        _partitionedUpdatableIndex.erase(it);
        return;
    }

    auto& list = listIt->second;
    if (list.empty() || index >= list.size())
    {
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
    uint32 zoneId = GetZoneId(obj->GetPhaseMask(), obj->GetPositionX(), obj->GetPositionY(), obj->GetPositionZ());
    uint32 newPartitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), obj->GetPositionX(), obj->GetPositionY(), zoneId, obj->GetGUID());
    auto it = _partitionedUpdatableIndex.find(obj);
    if (it == _partitionedUpdatableIndex.end())
    {
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
        if (listIt != _partitionedUpdatableObjectLists.end())
        {
            auto& list = listIt->second;
            if (!list.empty() && index < list.size())
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
            }
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

    std::shared_lock<std::shared_mutex> listLock(_partitionedUpdateListLock);
    auto listIt = _partitionedUpdatableObjectLists.find(partitionId);
    if (listIt == _partitionedUpdatableObjectLists.end())
        return;

    auto& objectList = listIt->second;
    out.reserve(out.size() + objectList.size());
    for (size_t i = 0; i < objectList.size(); ++i)
    {
        WorldObject* obj = objectList[i];
        auto idxIt = _partitionedUpdatableIndex.find(obj);
        if (idxIt == _partitionedUpdatableIndex.end())
            continue;
        if (idxIt->second.partitionId != partitionId || idxIt->second.index != i)
            continue;

        out.emplace_back(idxIt->second.guid, idxIt->second.typeId);
    }
}

void Map::CollectPartitionedUpdatableObjects(uint32 partitionId, std::vector<WorldObject*>& out)
{
    if (!_isPartitioned || partitionId == 0)
        return;

    std::shared_lock<std::shared_mutex> listLock(_partitionedUpdateListLock);
    auto listIt = _partitionedUpdatableObjectLists.find(partitionId);
    if (listIt == _partitionedUpdatableObjectLists.end())
        return;

    auto& objectList = listIt->second;
    out.reserve(out.size() + objectList.size());
    for (size_t i = 0; i < objectList.size(); ++i)
    {
        WorldObject* obj = objectList[i];
        auto idxIt = _partitionedUpdatableIndex.find(obj);
        if (idxIt == _partitionedUpdatableIndex.end())
            continue;
        if (idxIt->second.partitionId != partitionId || idxIt->second.index != i)
            continue;

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

    {
        std::unique_lock<std::shared_mutex> lock(_partitionedObjectStoreLock);
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
        auto it = _partitionedObjectIndex.find(guid);
        if (it == _partitionedObjectIndex.end())
            return;

        partitionId = it->second;
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
        auto it = _partitionedObjectIndex.find(guid);
        if (it != _partitionedObjectIndex.end() && it->second == newPartitionId)
            return; // No partition change needed
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

    struct PartitionRebuildWorker
    {
        Map& map;
        explicit PartitionRebuildWorker(Map& mapRef) : map(mapRef) { }

        void Visit(std::unordered_map<ObjectGuid, Creature*>& container)
        {
            for (auto& pair : container)
                if (pair.second && pair.second->IsInWorld())
                    map.UpdatePartitionedOwnership(pair.second);
        }

        void Visit(std::unordered_map<ObjectGuid, GameObject*>& container)
        {
            for (auto& pair : container)
                if (pair.second && pair.second->IsInWorld())
                    map.UpdatePartitionedOwnership(pair.second);
        }

        void Visit(std::unordered_map<ObjectGuid, DynamicObject*>& container)
        {
            for (auto& pair : container)
                if (pair.second && pair.second->IsInWorld())
                    map.UpdatePartitionedOwnership(pair.second);
        }

        void Visit(std::unordered_map<ObjectGuid, Corpse*>& container)
        {
            for (auto& pair : container)
                if (pair.second && pair.second->IsInWorld())
                    map.UpdatePartitionedOwnership(pair.second);
        }
    };

    PartitionRebuildWorker worker(*this);
    TypeContainerVisitor<PartitionRebuildWorker, MapStoredObjectTypesContainer> visitor(worker);
    VisitAllObjectStores([&visitor](MapStoredObjectTypesContainer& store)
    {
        visitor.Visit(store);
    });

    for (MapRefMgr::iterator iter = m_mapRefMgr.begin(); iter != m_mapRefMgr.end(); ++iter)
    {
        Player* player = iter->GetSource();
        if (player && player->IsInWorld())
            UpdatePartitionedObjectStore(player);
    }
}

void Map::BuildPartitionPlayerBuckets()
{
    uint32 partitionCount = sPartitionMgr->GetPartitionCount(GetId());
    if (partitionCount == 0)
        partitionCount = 1;

    std::unique_lock<std::shared_mutex> guard(_partitionPlayerBucketsLock);
    if (_partitionPlayerBuckets.size() != partitionCount)
        _partitionPlayerBuckets.resize(partitionCount);
    for (auto& bucket : _partitionPlayerBuckets)
        bucket.clear();

    for (MapRefMgr::iterator iter = m_mapRefMgr.begin(); iter != m_mapRefMgr.end(); ++iter)
    {
        Player* player = iter->GetSource();
        if (!player || !player->IsInWorld())
            continue;

        uint32 zoneId = player->GetZoneId();
        uint32 partitionId = sPartitionMgr->GetPartitionIdForPosition(GetId(), player->GetPositionX(), player->GetPositionY(), zoneId, player->GetGUID());
        uint32 index = partitionId > 0 ? partitionId - 1 : 0;
        if (index >= _partitionPlayerBuckets.size())
            index = _partitionPlayerBuckets.size() - 1;
        _partitionPlayerBuckets[index].push_back(player);
    }

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
        pending.swap(_deferredVisibilityUpdates);
        _deferredVisibilitySet.clear();
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

template<class T>
T* Map::FindPartitionedObject(ObjectGuid const& guid)
{
    if (!_isPartitioned)
        return nullptr;

    std::shared_lock<std::shared_mutex> lock(_partitionedObjectStoreLock);
    auto it = _partitionedObjectIndex.find(guid);
    if (it == _partitionedObjectIndex.end())
        return nullptr;

    auto storeIt = _partitionedObjectsStore.find(it->second);
    if (storeIt == _partitionedObjectsStore.end())
        return nullptr;

    return storeIt->second.Find<T>(guid);
}

void Map::RemoveObjectFromMapUpdateList(WorldObject* obj)
{
    if (!obj->CanBeAddedToMapUpdateList())
        return;

    UpdatableMapObject* mapUpdatableObject = dynamic_cast<UpdatableMapObject*>(obj);
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
        _pendingAddUpdatableObjectList.erase(obj);
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
    std::shared_lock<std::shared_mutex> lock(_zoneWideVisibleLock);
    ZoneWideVisibleWorldObjectsMap::const_iterator itr = _zoneWideVisibleWorldObjectsMap.find(zoneId);
    if (itr == _zoneWideVisibleWorldObjectsMap.end())
        return nullptr;

    // Return a thread-local snapshot to avoid exposing the internal container without a lock.
    thread_local ZoneWideVisibleWorldObjectsSet snapshot;
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
    // Extract objects under lock, then process outside lock
    std::vector<ObjectGuid> unitsToProcess;
    {
        std::lock_guard<std::mutex> lock(_delayedVisibilityLock);
        if (_objectsForDelayedVisibility.empty())
            return;
        unitsToProcess.swap(_objectsForDelayedVisibility);
    }

    std::sort(unitsToProcess.begin(), unitsToProcess.end());
    unitsToProcess.erase(std::unique(unitsToProcess.begin(), unitsToProcess.end()), unitsToProcess.end());

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

    if (_isPartitioned)
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

    if (gridChanged)
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

    if (_isPartitioned)
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

    if (_isPartitioned)
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

    if (_isPartitioned)
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
        (G3D::fuzzyLt(z, vmapData.floorZ - GROUND_HEIGHT_TOLERANCE) || dynData.floorZ > vmapData.floorZ))
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
        for (Transport::PassengerSet::const_iterator itr = transport->GetPassengers().begin(); itr != transport->GetPassengers().end(); ++itr)
            if (player != (*itr) && player->HaveAtClient(*itr))
                (*itr)->BuildCreateUpdateBlockForPlayer(&data, player);

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

    // Extract all pending updates under lock, then process outside lock
    std::vector<Object*> objectsToUpdate;
    {
        std::lock_guard<std::mutex> lock(_updateObjectsLock);
        objectsToUpdate.reserve(_updateObjects.size());
        for (Object* obj : _updateObjects)
            objectsToUpdate.push_back(obj);
        _updateObjects.clear();
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
                ASSERT(obj->IsInWorld());
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
    for (;;)
    {
        WorldObject* obj = nullptr;
        {
            std::lock_guard<std::mutex> guard(_objectsToRemoveLock);
            if (i_objectsToRemove.empty())
                break;

            std::unordered_set<WorldObject*>::iterator itr = i_objectsToRemove.begin();
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
        if (!(*itr)->GetPassengers().empty())
            return false;

    return true;
}

void Map::AllTransportsRemovePassengers()
{
    for (TransportsContainer::const_iterator itr = _transports.begin(); itr != _transports.end(); ++itr)
        while (!(*itr)->GetPassengers().empty())
            (*itr)->RemovePassenger(*((*itr)->GetPassengers().begin()), true);
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
