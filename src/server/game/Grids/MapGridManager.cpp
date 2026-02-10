#include "MapGridManager.h"
#include "GridObjectLoader.h"
#include "GridTerrainData.h"
#include "GridTerrainLoader.h"

void MapGridManager::CreateGrid(uint16 const x, uint16 const y)
{
    std::lock_guard<std::recursive_mutex> guard(_gridLock);
    if (IsGridCreated(x, y))
        return;

    std::unique_ptr<MapGridType> grid = std::make_unique<MapGridType>(x, y);
    grid->link(_map);

    GridTerrainLoader loader(*grid, _map);
    loader.LoadTerrain();

    _mapGrid[x][y] = std::move(grid);

    ++_createdGridsCount;
}

bool MapGridManager::LoadGrid(uint16 const x, uint16 const y)
{
    MapGridType* grid = nullptr;
    {
        std::lock_guard<std::recursive_mutex> guard(_gridLock);

        grid = GetGrid(x, y);
        if (!grid || grid->IsObjectDataLoaded())
            return false;

        // Must mark as loaded first, as GridObjectLoader spawning objects can attempt to recursively load the grid
        grid->SetObjectDataLoaded();

        ++_loadedGridsCount;
    }

    // Load cells OUTSIDE the lock to prevent AB-BA deadlock:
    //   Thread A: _gridLock (LoadGrid) → navmesh lock (Creature spawn → PathGenerator)
    //   Thread B: navmesh lock (PathGenerator) → _gridLock (NormalizePath → EnsureGridCreated)
    GridObjectLoader loader(*grid, _map);
    loader.LoadAllCellsInGrid();

    return true;
}

void MapGridManager::UnloadGrid(uint16 const x, uint16 const y)
{
    MapGridType* grid = GetGrid(x, y);
    if (!grid)
        return;

    {
        GridObjectCleaner worker;
        TypeContainerVisitor<GridObjectCleaner, GridTypeMapContainer> visitor(worker);
        grid->VisitAllCells(visitor);
    }

    _map->RemoveAllObjectsInRemoveList();

    {
        GridObjectUnloader worker;
        TypeContainerVisitor<GridObjectUnloader, GridTypeMapContainer> visitor(worker);
        grid->VisitAllCells(visitor);
    }

    GridTerrainUnloader terrainUnloader(*grid, _map);
    terrainUnloader.UnloadTerrain();

    {
        std::lock_guard<std::recursive_mutex> guard(_gridLock);
        _mapGrid[x][y] = nullptr;
    }
}

bool MapGridManager::IsGridCreated(uint16 const x, uint16 const y) const
{
    std::lock_guard<std::recursive_mutex> guard(_gridLock);
    if (!MapGridManager::IsValidGridCoordinates(x, y))
        return false;

    return _mapGrid[x][y] != nullptr;
}

bool MapGridManager::IsGridLoaded(uint16 const x, uint16 const y) const
{
    std::lock_guard<std::recursive_mutex> guard(_gridLock);
    if (!MapGridManager::IsValidGridCoordinates(x, y))
        return false;

    return _mapGrid[x][y] && _mapGrid[x][y]->IsObjectDataLoaded();
}

MapGridType* MapGridManager::GetGrid(uint16 const x, uint16 const y)
{
    std::lock_guard<std::recursive_mutex> guard(_gridLock);
    if (!MapGridManager::IsValidGridCoordinates(x, y))
        return nullptr;

    return _mapGrid[x][y].get();
}

uint32 MapGridManager::GetCreatedGridsCount()
{
    return _createdGridsCount;
}

std::shared_ptr<GridTerrainData> MapGridManager::GetGridTerrainData(uint16 const x, uint16 const y)
{
    std::lock_guard<std::recursive_mutex> guard(_gridLock);
    if (!MapGridManager::IsValidGridCoordinates(x, y))
        return nullptr;

    if (MapGridType* grid = _mapGrid[x][y].get())
        return grid->GetTerrainDataSharedPtr();

    return nullptr;
}

uint32 MapGridManager::GetLoadedGridsCount()
{
    return _loadedGridsCount;
}

uint32 MapGridManager::GetCreatedCellsInGridCount(uint16 const x, uint16 const y)
{
    MapGridType* grid = GetGrid(x, y);
    if (grid)
        return grid->GetCreatedCellsCount();

    return 0;
}

uint32 MapGridManager::GetCreatedCellsInMapCount()
{
    uint32 count = 0;
    for (uint32 gridX = 0; gridX < MAX_NUMBER_OF_GRIDS; ++gridX)
    {
        for (uint32 gridY = 0; gridY < MAX_NUMBER_OF_GRIDS; ++gridY)
        {
            if (MapGridType* grid = GetGrid(gridX, gridY))
                count += grid->GetCreatedCellsCount();
        }
    }
    return count;
}

bool MapGridManager::IsGridsFullyCreated() const
{
    return _createdGridsCount == (MAX_NUMBER_OF_GRIDS * MAX_NUMBER_OF_GRIDS);
}

bool MapGridManager::IsGridsFullyLoaded() const
{
    return _loadedGridsCount == (MAX_NUMBER_OF_GRIDS * MAX_NUMBER_OF_GRIDS);
}
