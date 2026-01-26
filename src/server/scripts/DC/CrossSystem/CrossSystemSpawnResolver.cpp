#include "CrossSystemSpawnResolver.h"

#include "CrossSystemMapCoords.h"

#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "GameObject.h"
#include "MapMgr.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"

#include <algorithm>

namespace
{
    void FillZoneArea(uint32 phaseMask, uint32 mapId, float x, float y, float z, uint32& outZoneId, uint32& outAreaId)
    {
        outZoneId = 0;
        outAreaId = 0;
        sMapMgr->GetZoneAndAreaId(phaseMask, outZoneId, outAreaId, mapId, x, y, z);
    }
}

namespace DC
{
namespace SpawnResolver
{
    ResolvedPosition ResolveCreature(Player* contextPlayer, uint32 spawnId, uint32 entry, bool preferLive)
    {
        ResolvedPosition out;
        out.spawnId = spawnId;
        out.entry = entry;

        // 1) Prefer current/live position (works only if creature is loaded/near the player context)
        if (preferLive && contextPlayer && spawnId != 0)
        {
            uint32 resolvedEntry = entry;
            if (!resolvedEntry)
            {
                if (CreatureData const* cData = sObjectMgr->GetCreatureData(spawnId))
                    resolvedEntry = cData->id1;
            }

            if (resolvedEntry)
            {
                ObjectGuid guid = ObjectGuid::Create<HighGuid::Unit>(resolvedEntry, spawnId);
                if (Creature* c = ObjectAccessor::GetCreature(*contextPlayer, guid))
                {
                    out.found = true;
                    out.source = Source::Live;
                    out.spawnId = c->GetSpawnId();
                    out.entry = c->GetEntry();
                    out.mapId = c->GetMapId();
                    out.phaseMask = c->GetPhaseMask();
                    out.x = c->GetPositionX();
                    out.y = c->GetPositionY();
                    out.z = c->GetPositionZ();
                    c->GetZoneAndAreaId(out.zoneId, out.areaId);
                    out.hasNormalized = DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(out.zoneId, out.x, out.y, out.nx, out.ny);
                    return out;
                }
            }
        }

        // 2) Spawn cache (sObjectMgr)
        if (spawnId != 0)
        {
            if (CreatureData const* cData = sObjectMgr->GetCreatureData(spawnId))
            {
                out.found = true;
                out.source = Source::SpawnCache;
                out.entry = cData->id1;
                out.mapId = cData->mapid;
                out.phaseMask = cData->phaseMask;
                out.x = cData->posX;
                out.y = cData->posY;
                out.z = cData->posZ;
                FillZoneArea(out.phaseMask, out.mapId, out.x, out.y, out.z, out.zoneId, out.areaId);
                out.hasNormalized = DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(out.zoneId, out.x, out.y, out.nx, out.ny);
                return out;
            }
        }

        // 3) DB fallback
        QueryResult res;
        if (spawnId != 0)
        {
            res = WorldDatabase.Query(
                "SELECT guid, id1, map, zoneId, areaId, phaseMask, position_x, position_y, position_z "
                "FROM creature WHERE guid = {} LIMIT 1",
                spawnId);
        }
        else if (entry != 0)
        {
            res = WorldDatabase.Query(
                "SELECT guid, id1, map, zoneId, areaId, phaseMask, position_x, position_y, position_z "
                "FROM creature WHERE id1 = {} ORDER BY guid ASC LIMIT 1",
                entry);
        }

        if (!res)
            return out;

        out.found = true;
        out.source = Source::WorldDB;
        out.spawnId = (*res)[0].Get<uint32>();
        out.entry = (*res)[1].Get<uint32>();
        out.mapId = (*res)[2].Get<uint32>();
        out.zoneId = (*res)[3].Get<uint32>();
        out.areaId = (*res)[4].Get<uint32>();
        out.phaseMask = (*res)[5].Get<uint32>();
        out.x = (*res)[6].Get<float>();
        out.y = (*res)[7].Get<float>();
        out.z = (*res)[8].Get<float>();

        if (out.zoneId == 0 || out.areaId == 0)
            FillZoneArea(out.phaseMask, out.mapId, out.x, out.y, out.z, out.zoneId, out.areaId);

        out.hasNormalized = DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(out.zoneId, out.x, out.y, out.nx, out.ny);
        return out;
    }

    ResolvedPosition ResolveGameObject(Player* contextPlayer, uint32 spawnId, uint32 entry, bool preferLive)
    {
        ResolvedPosition out;
        out.spawnId = spawnId;
        out.entry = entry;

        // 1) Prefer live position if nearby/loaded
        if (preferLive && contextPlayer && spawnId != 0)
        {
            uint32 resolvedEntry = entry;
            if (!resolvedEntry)
            {
                if (GameObjectData const* gData = sObjectMgr->GetGameObjectData(spawnId))
                    resolvedEntry = gData->id;
            }

            if (resolvedEntry)
            {
                ObjectGuid guid = ObjectGuid::Create<HighGuid::GameObject>(resolvedEntry, spawnId);
                if (GameObject* go = ObjectAccessor::GetGameObject(*contextPlayer, guid))
                {
                    out.found = true;
                    out.source = Source::Live;
                    out.spawnId = go->GetSpawnId();
                    out.entry = go->GetEntry();
                    out.mapId = go->GetMapId();
                    out.phaseMask = go->GetPhaseMask();
                    out.x = go->GetPositionX();
                    out.y = go->GetPositionY();
                    out.z = go->GetPositionZ();
                    go->GetZoneAndAreaId(out.zoneId, out.areaId);
                    out.hasNormalized = DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(out.zoneId, out.x, out.y, out.nx, out.ny);
                    return out;
                }
            }
        }

        // 2) Spawn cache (sObjectMgr)
        if (spawnId != 0)
        {
            if (GameObjectData const* gData = sObjectMgr->GetGameObjectData(spawnId))
            {
                out.found = true;
                out.source = Source::SpawnCache;
                out.entry = gData->id;
                out.mapId = gData->mapid;
                out.phaseMask = gData->phaseMask;
                out.x = gData->posX;
                out.y = gData->posY;
                out.z = gData->posZ;
                FillZoneArea(out.phaseMask, out.mapId, out.x, out.y, out.z, out.zoneId, out.areaId);
                out.hasNormalized = DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(out.zoneId, out.x, out.y, out.nx, out.ny);
                return out;
            }
        }

        // 3) DB fallback
        QueryResult res;
        if (spawnId != 0)
        {
            res = WorldDatabase.Query(
                "SELECT guid, id, map, zoneId, areaId, phaseMask, position_x, position_y, position_z "
                "FROM gameobject WHERE guid = {} LIMIT 1",
                spawnId);
        }
        else if (entry != 0)
        {
            res = WorldDatabase.Query(
                "SELECT guid, id, map, zoneId, areaId, phaseMask, position_x, position_y, position_z "
                "FROM gameobject WHERE id = {} ORDER BY guid ASC LIMIT 1",
                entry);
        }

        if (!res)
            return out;

        out.found = true;
        out.source = Source::WorldDB;
        out.spawnId = (*res)[0].Get<uint32>();
        out.entry = (*res)[1].Get<uint32>();
        out.mapId = (*res)[2].Get<uint32>();
        out.zoneId = (*res)[3].Get<uint32>();
        out.areaId = (*res)[4].Get<uint32>();
        out.phaseMask = (*res)[5].Get<uint32>();
        out.x = (*res)[6].Get<float>();
        out.y = (*res)[7].Get<float>();
        out.z = (*res)[8].Get<float>();

        if (out.zoneId == 0 || out.areaId == 0)
            FillZoneArea(out.phaseMask, out.mapId, out.x, out.y, out.z, out.zoneId, out.areaId);

        out.hasNormalized = DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(out.zoneId, out.x, out.y, out.nx, out.ny);
        return out;
    }

    ResolvedPosition ResolvePlayer(Player* player)
    {
        ResolvedPosition out;
        if (!player)
            return out;

        out.found = true;
        out.source = Source::Live;
        out.mapId = player->GetMapId();
        out.phaseMask = player->GetPhaseMask();
        out.x = player->GetPositionX();
        out.y = player->GetPositionY();
        out.z = player->GetPositionZ();
        player->GetZoneAndAreaId(out.zoneId, out.areaId);
        out.hasNormalized = DarkChaos::CrossSystem::MapCoords::TryComputeNormalized(out.zoneId, out.x, out.y, out.nx, out.ny);
        return out;
    }

}
}
