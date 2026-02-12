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

#include "GridObjectLoader.h"
#include "CellImpl.h"
#include "Corpse.h"
#include "Creature.h"
#include "DynamicObject.h"
#include "GameObject.h"
#include "GridNotifiers.h"
#include "Metric.h"
#include "LayerManager.h"
#include "Transport.h"
#include "GameTime.h"
#include <unordered_map>
#include <memory>

namespace
{
    struct CloneSpawnSummary
    {
        uint64 npcMs = 0;
        uint64 goMs = 0;
        uint32 npcCount = 0;
        uint32 goCount = 0;

        void Reset()
        {
            npcMs = 0;
            goMs = 0;
            npcCount = 0;
            goCount = 0;
        }
    };

    thread_local CloneSpawnSummary g_cloneSpawnSummary;
    thread_local bool g_collectCloneSummary = false;
}

template <class T>
void GridObjectLoader::AddObjectHelper(Map* map, T* obj)
{
    if (!map || !obj)
    {
        LOG_ERROR("maps", "GridObjectLoader::AddObjectHelper called with null map or obj");
        return;
    }

    CellCoord cellCoord = Acore::ComputeCellCoord(obj->GetPositionX(), obj->GetPositionY());
    Cell cell(cellCoord);

    map->AddToGrid<T>(obj, cell);
    obj->AddToWorld();
}

void GridObjectLoader::LoadCreatures(CellGuidSet const& guid_set, Map* map)
{
    bool layerCloning = sLayerMgr->IsNPCLayeringEnabled();
    std::vector<uint32> layerIds;

    // Use cached active layer IDs if layering is enabled
    if (layerCloning)
    {
        if (sLayerMgr->SkipCloneSpawnsIfNoPlayers() && !sLayerMgr->HasPlayersOnMap(map->GetId()))
        {
            layerIds.push_back(0);
        }
        else
        {
            sLayerMgr->GetActiveLayerIds(map->GetId(), layerIds);
            
            // Ensure layer 0 is included even if GetActiveLayerIds returns empty or only clones
            bool hasBaseLayer = false;
            for (uint32 layerId : layerIds)
            {
                if (layerId == 0)
                {
                    hasBaseLayer = true;
                    break;
                }
            }
            if (!hasBaseLayer)
                layerIds.push_back(0);
        }
    }
    else
    {
        layerIds.push_back(0);
    }

    for (uint32 layerId : layerIds)
    {
        bool isClone = layerCloning && layerId != 0;
        LoadCreaturesImpl(guid_set, map, layerId, isClone);
    }
}

void GridObjectLoader::LoadGameObjects(CellGuidSet const& guid_set, Map* map)
{
    bool layerCloning = sLayerMgr->IsGOLayeringEnabled();
    std::vector<uint32> layerIds;

    // Use cached active layer IDs if layering is enabled
    if (layerCloning)
    {
        if (sLayerMgr->SkipCloneSpawnsIfNoPlayers() && !sLayerMgr->HasPlayersOnMap(map->GetId()))
        {
            layerIds.push_back(0);
        }
        else
        {
            sLayerMgr->GetActiveLayerIds(map->GetId(), layerIds);

            // Ensure layer 0 is included even if GetActiveLayerIds returns empty or only clones
            bool hasBaseLayer = false;
            for (uint32 layerId : layerIds)
            {
                if (layerId == 0)
                {
                    hasBaseLayer = true;
                    break;
                }
            }
            if (!hasBaseLayer)
                layerIds.push_back(0);
        }
    }
    else
    {
        layerIds.push_back(0);
    }

    for (uint32 layerId : layerIds)
    {
        bool isClone = layerCloning && layerId != 0;
        LoadGameObjectsImpl(guid_set, map, layerId, isClone);
    }
}

void GridObjectLoader::LoadLayerClones(uint32 layerId)
{
    if (!layerId)
        return;

    bool collectSummary = sLayerMgr->IsRuntimeDiagnosticsEnabled();
    if (collectSummary)
        g_cloneSpawnSummary.Reset();
    g_collectCloneSummary = collectSummary;

    std::shared_ptr<CellObjectGuids> cached = _map->GetPreloadedGridObjectGuids(_grid.GetId());
    CellObjectGuids const& cell_guids = cached ? *cached :
        sObjectMgr->GetGridObjectGuids(_map->GetId(), _map->GetSpawnMode(), _grid.GetId());

    if (sLayerMgr->IsGOLayeringEnabled())
        LoadGameObjectsForLayer(cell_guids.gameobjects, _map, layerId, true);
    if (sLayerMgr->IsNPCLayeringEnabled())
        LoadCreaturesForLayer(cell_guids.creatures, _map, layerId, true);

    if (collectSummary && (g_cloneSpawnSummary.npcCount || g_cloneSpawnSummary.goCount))
    {
        LOG_INFO("map.partition", "Diag: Grid {} map {} layer {} clone spawn summary npc_count={} npc_ms={} go_count={} go_ms={}",
            _grid.GetId(), _map->GetId(), layerId, g_cloneSpawnSummary.npcCount, g_cloneSpawnSummary.npcMs,
            g_cloneSpawnSummary.goCount, g_cloneSpawnSummary.goMs);
    }

    g_collectCloneSummary = false;
}

void GridObjectLoader::LoadCreaturesForLayer(CellGuidSet const& guid_set, Map* map, uint32 layerId, bool isClone)
{
    if (!sLayerMgr->IsNPCLayeringEnabled())
        return;

    LoadCreaturesImpl(guid_set, map, layerId, isClone);
}

void GridObjectLoader::LoadCreaturesImpl(CellGuidSet const& guid_set, Map* map, uint32 layerId, bool isClone)
{
    for (ObjectGuid::LowType const& guid : guid_set)
    {
        bool allowDuplicate = isClone;
        uint64 startMs = 0;
        uint32 spawned = 0;
        uint32 zoneId = 0;

        if (isClone && sLayerMgr->IsRuntimeDiagnosticsEnabled())
            startMs = GameTime::GetGameTimeMS().count();

        Creature* obj = new Creature();
        if (!obj->LoadCreatureFromDB(guid, map, false, allowDuplicate, isClone, layerId))
        {
            delete obj;
            continue;
        }

        AddObjectHelper<Creature>(map, obj);
        if (isClone)
        {
            ++spawned;
            if (zoneId == 0)
                zoneId = map->GetZoneId(obj->GetPhaseMask(), obj->GetPositionX(), obj->GetPositionY(), obj->GetPositionZ());
        }

        if (!obj->IsMoveInLineOfSightDisabled() && obj->GetDefaultMovementType() == IDLE_MOTION_TYPE && !obj->isNeedNotify(NOTIFY_VISIBILITY_CHANGED | NOTIFY_AI_RELOCATION))
        {
            // Avoid running grid scans while inside a partition worker update.
            // This can iterate containers that are being mutated as the partition updates progress.
            if (Map* m = obj->FindMap(); m && m->IsPartitioned() && m->GetActivePartitionContext() && !m->IsProcessingPartitionRelays())
            {
                // Defer to the normal update/visibility flow instead.
            }
            else if (obj->IsAlive() && !obj->HasUnitState(UNIT_STATE_SIGHTLESS) && obj->HasReactState(REACT_AGGRESSIVE) && !obj->IsImmuneToNPC())
            {
                Acore::AIRelocationNotifier notifier(*obj);
                Cell::VisitObjects(obj, notifier, 60.f);
            }
        }

        if (isClone && sLayerMgr->IsRuntimeDiagnosticsEnabled())
        {
            uint64 elapsedMs = GameTime::GetGameTimeMS().count() - startMs;
            if (g_collectCloneSummary)
            {
                g_cloneSpawnSummary.npcMs += elapsedMs;
                g_cloneSpawnSummary.npcCount += spawned;
            }
            if (sLayerMgr->EmitPerLayerCloneMetrics())
            {
                METRIC_VALUE("layer_clone_spawn_ms", elapsedMs,
                    METRIC_TAG("map_id", std::to_string(map->GetId())),
                    METRIC_TAG("zone_id", std::to_string(zoneId)),
                    METRIC_TAG("layer_id", std::to_string(layerId)),
                    METRIC_TAG("type", "npc"));
                METRIC_VALUE("layer_clone_spawn_count", uint64(spawned),
                    METRIC_TAG("map_id", std::to_string(map->GetId())),
                    METRIC_TAG("zone_id", std::to_string(zoneId)),
                    METRIC_TAG("layer_id", std::to_string(layerId)),
                    METRIC_TAG("type", "npc"));
            }
        }
    }
}

void GridObjectLoader::LoadGameObjectsForLayer(CellGuidSet const& guid_set, Map* map, uint32 layerId, bool isClone)
{
    if (!sLayerMgr->IsGOLayeringEnabled())
        return;

    LoadGameObjectsImpl(guid_set, map, layerId, isClone);
}

void GridObjectLoader::LoadGameObjectsImpl(CellGuidSet const& guid_set, Map* map, uint32 layerId, bool isClone)
{
    for (ObjectGuid::LowType const& guid : guid_set)
    {
        GameObjectData const* data = sObjectMgr->GetGameObjectData(guid);

        if (data && sObjectMgr->IsGameObjectStaticTransport(data->id))
        {
            if (isClone)
                continue;

            StaticTransport* transport = new StaticTransport();

            // Special case for static transports - we are loaded via grids
            // but we do not want to actually be stored in the grid
            if (!transport->LoadGameObjectFromDB(guid, map, true))
                delete transport;
            continue;
        }

        bool allowDuplicate = isClone;
        uint64 startMs = 0;
        uint32 spawned = 0;
        uint32 zoneId = 0;
        if (isClone && sLayerMgr->IsRuntimeDiagnosticsEnabled())
            startMs = GameTime::GetGameTimeMS().count();

        GameObject* obj = new GameObject();

        if (!obj->LoadGameObjectFromDB(guid, map, false, allowDuplicate, isClone, layerId))
        {
            delete obj;
            continue;
        }

        AddObjectHelper<GameObject>(map, obj);
        if (isClone)
        {
            ++spawned;
            if (zoneId == 0)
                zoneId = map->GetZoneId(obj->GetPhaseMask(), obj->GetPositionX(), obj->GetPositionY(), obj->GetPositionZ());
        }

        if (isClone && sLayerMgr->IsRuntimeDiagnosticsEnabled())
        {
            uint64 elapsedMs = GameTime::GetGameTimeMS().count() - startMs;
            if (g_collectCloneSummary)
            {
                g_cloneSpawnSummary.goMs += elapsedMs;
                g_cloneSpawnSummary.goCount += spawned;
            }
            if (sLayerMgr->EmitPerLayerCloneMetrics())
            {
                METRIC_VALUE("layer_clone_spawn_ms", elapsedMs,
                    METRIC_TAG("map_id", std::to_string(map->GetId())),
                    METRIC_TAG("zone_id", std::to_string(zoneId)),
                    METRIC_TAG("layer_id", std::to_string(layerId)),
                    METRIC_TAG("type", "go"));
                METRIC_VALUE("layer_clone_spawn_count", uint64(spawned),
                    METRIC_TAG("map_id", std::to_string(map->GetId())),
                    METRIC_TAG("zone_id", std::to_string(zoneId)),
                    METRIC_TAG("layer_id", std::to_string(layerId)),
                    METRIC_TAG("type", "go"));
            }
        }
    }
}

void GridObjectLoader::LoadAllCellsInGrid()
{
    bool collectSummary = sLayerMgr->IsRuntimeDiagnosticsEnabled();
    if (collectSummary)
        g_cloneSpawnSummary.Reset();
    g_collectCloneSummary = collectSummary;

    std::shared_ptr<CellObjectGuids> cached = _map->GetPreloadedGridObjectGuids(_grid.GetId());
    CellObjectGuids const& cell_guids = cached ? *cached :
        sObjectMgr->GetGridObjectGuids(_map->GetId(), _map->GetSpawnMode(), _grid.GetId());

    bool lazyCloneLoading = sLayerMgr->IsLayeringEnabled() && sLayerMgr->LazyCloneLoadingEnabled();
    if (lazyCloneLoading)
    {
        if (sLayerMgr->IsGOLayeringEnabled())
            LoadGameObjectsForLayer(cell_guids.gameobjects, _map, 0, false);
        else
            LoadGameObjects(cell_guids.gameobjects, _map);

        if (sLayerMgr->IsNPCLayeringEnabled())
            LoadCreaturesForLayer(cell_guids.creatures, _map, 0, false);
        else
            LoadCreatures(cell_guids.creatures, _map);
    }
    else
    {
        LoadGameObjects(cell_guids.gameobjects, _map);
        LoadCreatures(cell_guids.creatures, _map);
    }

    if (collectSummary && (g_cloneSpawnSummary.npcCount || g_cloneSpawnSummary.goCount))
    {
        LOG_INFO("map.partition", "Diag: Grid {} map {} clone spawn summary npc_count={} npc_ms={} go_count={} go_ms={}",
            _grid.GetId(), _map->GetId(), g_cloneSpawnSummary.npcCount, g_cloneSpawnSummary.npcMs,
            g_cloneSpawnSummary.goCount, g_cloneSpawnSummary.goMs);
    }

    g_collectCloneSummary = false;

    if (std::unordered_set<Corpse*> const* corpses = _map->GetCorpsesInGrid(_grid.GetId()))
    {
        for (Corpse* corpse : *corpses)
        {
            if (corpse->IsInGrid())
                continue;

            AddObjectHelper<Corpse>(_map, corpse);
        }
    }
}

template<class T>
void GridObjectUnloader::Visit(GridRefMgr<T>& m)
{
    while (!m.IsEmpty())
    {
        T* obj = m.getFirst()->GetSource();
        // if option set then object already saved at this moment
        //if (!sWorld->getBoolConfig(CONFIG_SAVE_RESPAWN_TIME_IMMEDIATELY))
        //    obj->SaveRespawnTime();
        //Some creatures may summon other temp summons in CleanupsBeforeDelete()
        //So we need this even after cleaner (maybe we can remove cleaner)
        //Example: Flame Leviathan Turret 33139 is summoned when a creature is deleted
        //TODO: Check if that script has the correct logic. Do we really need to summons something before deleting?
        obj->CleanupsBeforeDelete();

        obj->GetMap()->RemoveObjectFromMapUpdateList(obj);

        ///- object will get delinked from the manager when deleted
        delete obj;
    }
}

template<class T>
void GridObjectCleaner::Visit(GridRefMgr<T>& m)
{
    for (typename GridRefMgr<T>::iterator iter = m.begin(); iter != m.end(); ++iter)
        iter->GetSource()->CleanupsBeforeDelete();
}

template void GridObjectUnloader::Visit(CreatureMapType&);
template void GridObjectUnloader::Visit(GameObjectMapType&);
template void GridObjectUnloader::Visit(DynamicObjectMapType&);

template void GridObjectCleaner::Visit(CreatureMapType&);
template void GridObjectCleaner::Visit<GameObject>(GameObjectMapType&);
template void GridObjectCleaner::Visit<DynamicObject>(DynamicObjectMapType&);
template void GridObjectCleaner::Visit<Corpse>(CorpseMapType&);
