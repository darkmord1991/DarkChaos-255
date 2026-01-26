#include "dc_guildhouse.h"

#include "Chat.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "MapMgr.h"
#include "ObjectMgr.h"

#include <cmath>
#include <optional>
#include <unordered_map>

static std::unordered_map<uint32, GuildHouseData> s_guildHouseCache;

namespace
{
    bool HasGuildHouseLevelColumn()
    {
        static std::optional<bool> cached;
        if (cached.has_value())
            return cached.value();

        QueryResult result = CharacterDatabase.Query(
            "SELECT COUNT(*) FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_guild_house' AND COLUMN_NAME = 'guildhouse_level'");

        if (!result)
        {
            cached = false;
            return false;
        }

        Field* fields = result->Fetch();
        cached = (fields[0].Get<uint64>() > 0);
        return cached.value();
    }
}

GuildHouseData* GuildHouseManager::GetGuildHouseData(uint32 guildId)
{
    // Check Cache
    auto it = s_guildHouseCache.find(guildId);
    if (it != s_guildHouseCache.end())
        return &it->second;

    // Load from DB
    QueryResult result;
    if (HasGuildHouseLevelColumn())
    {
        result = CharacterDatabase.Query(
            "SELECT `phase`, `map`, `positionX`, `positionY`, `positionZ`, `orientation`, `guildhouse_level` "
            "FROM `dc_guild_house` WHERE `guild` = {}",
            guildId);
    }
    else
    {
        result = CharacterDatabase.Query(
            "SELECT `phase`, `map`, `positionX`, `positionY`, `positionZ`, `orientation` "
            "FROM `dc_guild_house` WHERE `guild` = {}",
            guildId);
    }

    if (!result)
        return nullptr;

    Field* fields = result->Fetch();
    uint32 phase = fields[0].Get<uint32>();
    uint32 map = fields[1].Get<uint32>();
    float posX = fields[2].Get<float>();
    float posY = fields[3].Get<float>();
    float posZ = fields[4].Get<float>();
    float ori = fields[5].Get<float>();
    uint8 level = HasGuildHouseLevelColumn() ? fields[6].Get<uint8>() : 1;

    bool shouldUpdate = false;

    // Fix invalid or legacy phase values.
    uint32 expectedPhase = GetGuildPhase(guildId);
    if (phase == 0 || phase == PHASEMASK_NORMAL)
    {
        phase = expectedPhase;
        shouldUpdate = true;
    }

    // Fix missing coordinates (e.g., 0/0/0) by falling back to the first location on the same map.
    if (std::fabs(posX) < 0.001f && std::fabs(posY) < 0.001f)
    {
        QueryResult locationResult = WorldDatabase.Query(
            "SELECT `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_locations` WHERE `map` = {} ORDER BY `id` ASC LIMIT 1",
            map);

        if (locationResult)
        {
            Field* locFields = locationResult->Fetch();
            posX = locFields[0].Get<float>();
            posY = locFields[1].Get<float>();
            posZ = locFields[2].Get<float>();
            ori = locFields[3].Get<float>();
            shouldUpdate = true;
        }
    }

    if (shouldUpdate)
    {
        CharacterDatabase.Execute(
            "UPDATE `dc_guild_house` SET `phase` = {}, `positionX` = {}, `positionY` = {}, `positionZ` = {}, `orientation` = {} WHERE `guild` = {}",
            phase, posX, posY, posZ, ori, guildId);
    }

    // Store in Cache
    GuildHouseData& data = s_guildHouseCache[guildId];
    data = GuildHouseData(phase, map, posX, posY, posZ, ori, level);
    return &data;
}

void GuildHouseManager::UpdateGuildHouseData(uint32 guildId, GuildHouseData const& data)
{
    s_guildHouseCache[guildId] = data;
}

void GuildHouseManager::RemoveGuildHouseData(uint32 guildId)
{
    s_guildHouseCache.erase(guildId);
}

uint8 GuildHouseManager::GetGuildHouseLevel(uint32 guildId)
{
    GuildHouseData* data = GetGuildHouseData(guildId);
    if (!data)
        return 1;

    return data->level ? data->level : 1;
}

bool GuildHouseManager::SetGuildHouseLevel(uint32 guildId, uint8 level)
{
    if (!guildId)
        return false;

    if (!HasGuildHouseLevelColumn())
        return false;

    CharacterDatabase.Execute(
        "UPDATE `dc_guild_house` SET `guildhouse_level` = {} WHERE `guild` = {}",
        level, guildId);

    GuildHouseData* data = GetGuildHouseData(guildId);
    if (data)
        data->level = level;

    return true;
}

bool GuildHouseManager::TeleportToGuildHouse(Player* player, uint32 guildId)
{
    if (!player || !guildId)
        return false;

    GuildHouseData* data = GetGuildHouseData(guildId);
    if (!data)
        return false;

    // This guild housing implementation currently uses phasing on a shared map.
    // Setting phase mask before teleport helps ensure correct visibility immediately on arrival.
    if (data->phase)
        player->SetPhaseMask(data->phase, true);

    player->TeleportTo(data->map, data->posX, data->posY, data->posZ, data->ori);
    return true;
}

bool GuildHouseManager::RemoveGuildHouse(Guild* guild)
{
    if (!guild)
        return false;

    uint32 guildId = guild->GetId();

    // Fetch data first (will load from DB if not in cache)
    GuildHouseData* data = GetGuildHouseData(guildId);

    if (data)
    {
        uint32 mapId = data->map;
        uint32 guildPhase = data->phase ? data->phase : GetGuildPhase(guildId);
        CleanupGuildHouseSpawns(mapId, guildPhase);
    }
    else
    {
        // Fallback checks via DB handled in GetGuildHouseData mostly, but if we really have no record,
        // we might check purely for phase cleanup.
        // Assuming GetGuildPhase logic calculates default.
         CleanupGuildHouseSpawns(1, GetGuildPhase(guildId));
    }

    // Remove from Cache
    RemoveGuildHouseData(guildId);

    // Delete the guild house ownership record.
    CharacterDatabase.Query("DELETE FROM `dc_guild_house` WHERE `guild` = {}", guildId);
    return true;
}

void GuildHouseManager::CleanupGuildHouseSpawns(uint32 mapId, uint32 guildPhase)
{
    Map* map = sMapMgr->FindMap(mapId, 0);
    if (!map)
        return;

    QueryResult creatureResult = WorldDatabase.Query(
        "SELECT `guid` FROM `creature` WHERE `map` = {} AND `phaseMask` = {}",
        mapId, guildPhase);

    QueryResult gameobjResult = WorldDatabase.Query(
        "SELECT `guid` FROM `gameobject` WHERE `map` = {} AND `phaseMask` = {}",
        mapId, guildPhase);

    if (creatureResult)
    {
        do
        {
            Field* fields = creatureResult->Fetch();
            uint32 lowguid = fields[0].Get<uint32>();

            if (CreatureData const* crData = sObjectMgr->GetCreatureData(lowguid))
            {
                if (Creature* creature = map->GetCreature(ObjectGuid::Create<HighGuid::Unit>(crData->id1, lowguid)))
                {
                    creature->CombatStop();
                    creature->DeleteFromDB();
                    creature->AddObjectToRemoveList();
                }
            }
        } while (creatureResult->NextRow());
    }

    if (gameobjResult)
    {
        do
        {
            Field* fields = gameobjResult->Fetch();
            uint32 lowguid = fields[0].Get<uint32>();

            if (GameObjectData const* goData = sObjectMgr->GetGameObjectData(lowguid))
            {
                if (GameObject* gobject = map->GetGameObject(ObjectGuid::Create<HighGuid::GameObject>(goData->id, lowguid)))
                {
                    gobject->SetRespawnTime(0);
                    gobject->Delete();
                    gobject->DeleteFromDB();
                    gobject->CleanupsBeforeDelete();
                }
            }
        } while (gameobjResult->NextRow());
    }
}

bool GuildHouseManager::HasSpawn(uint32 mapId, uint32 phase, uint32 entry, bool isGameObject)
{
    if (isGameObject)
    {
        QueryResult result = WorldDatabase.Query("SELECT COUNT(*) FROM `gameobject` WHERE `map`={} AND `id`={} AND `phaseMask`={}", mapId, entry, phase);
        if (result)
            return result->Fetch()[0].Get<uint32>() > 0;
    }
    else
    {
        // Note: creature table uses `id1` for the entry column, not `id`
        QueryResult result = WorldDatabase.Query("SELECT COUNT(*) FROM `creature` WHERE `map`={} AND `id1`={} AND `phaseMask`={}", mapId, entry, phase);
        if (result)
            return result->Fetch()[0].Get<uint32>() > 0;
    }
    return false;
}

void GuildHouseManager::SpawnTeleporterNPC(Player* player)
{
    if (!player || !player->GetGuildId()) return;

    GuildHouseData* data = GetGuildHouseData(player->GetGuildId());
    if (data)
         SpawnTeleporterNPC(player->GetGuildId(), data->map, data->phase, data->posX, data->posY, data->posZ, data->ori);
    else
         SpawnTeleporterNPC(player->GetGuildId(), 1, GetGuildPhase(player->GetGuildId()), 16222.0f, 16270.0f, 13.1f, 4.7f);
}

void GuildHouseManager::SpawnTeleporterNPC(uint32 /*guildId*/, uint32 mapId, uint32 phase, float x, float y, float z, float o)
{
    Map* map = sMapMgr->FindMap(mapId, 0);
    if (!map) return;

    Creature* creature = new Creature();
    if (!creature->Create(map->GenerateLowGuid<HighGuid::Unit>(), map, phase, 800002, 0, x, y, z, o))
    {
        delete creature;
        LOG_INFO("modules.dc", "GUILDHOUSE: Unable to create Teleporter NPC!");
        return;
    }

    creature->SaveToDB(map->GetId(), (1 << map->GetSpawnMode()), phase);
    uint32 lowguid = creature->GetSpawnId();

    creature->CleanupsBeforeDelete();
    delete creature;
    creature = new Creature();
    if (creature->LoadCreatureFromDB(lowguid, map))
        sObjectMgr->AddCreatureToGrid(lowguid, sObjectMgr->GetCreatureData(lowguid));
}

void GuildHouseManager::SpawnButlerNPC(Player* player)
{
    if (!player || !player->GetGuildId()) return;

    GuildHouseData* data = GetGuildHouseData(player->GetGuildId());
    if (data)
         SpawnButlerNPC(player->GetGuildId(), data->map, data->phase, data->posX + 2.0f, data->posY, data->posZ, data->ori);
    else
         SpawnButlerNPC(player->GetGuildId(), 1, GetGuildPhase(player->GetGuildId()), 16229.422f, 16283.675f, 13.175704f, 3.036652f);
}

void GuildHouseManager::SpawnButlerNPC(uint32 /*guildId*/, uint32 mapId, uint32 phase, float x, float y, float z, float o)
{
    Map* map = sMapMgr->FindMap(mapId, 0);
    if (!map) return;

    Creature* creature = new Creature();
    if (!creature->Create(map->GenerateLowGuid<HighGuid::Unit>(), map, phase, 95104, 0, x, y, z, o))
    {
        delete creature;
        LOG_INFO("modules.dc", "GUILDHOUSE: Unable to create Butler NPC!");
        return;
    }

    creature->SaveToDB(map->GetId(), (1 << map->GetSpawnMode()), phase);
    uint32 lowguid = creature->GetSpawnId();

    creature->CleanupsBeforeDelete();
    delete creature;
    creature = new Creature();
    if (creature->LoadCreatureFromDB(lowguid, map))
        sObjectMgr->AddCreatureToGrid(lowguid, sObjectMgr->GetCreatureData(lowguid));
}

bool GuildHouseManager::HasPermission(Player* player, uint32 permission)
{
    if (!player || !player->GetGuildId()) return false;

    // Guild Master always has permission
    if (player->GetRank() == 0) return true;

    // Check custom permissions from DB
    QueryResult result = CharacterDatabase.Query(
        "SELECT `permission` FROM `dc_guild_house_permissions` WHERE `guildId`={} AND `rankId`={}",
        player->GetGuildId(), player->GetRank());

    if (result)
    {
        uint32 perms = result->Fetch()[0].Get<uint32>();
        if (perms & GH_PERM_ADMIN) return true; // Admin has all rights
        return (perms & permission) != 0;
    }

    return false;
}

void GuildHouseManager::SetPermission(uint32 guildId, uint8 rankId, uint32 permission)
{
    CharacterDatabase.Execute(
        "INSERT INTO `dc_guild_house_permissions` (`guildId`, `rankId`, `permission`) VALUES ({}, {}, {}) "
        "ON DUPLICATE KEY UPDATE `permission` = VALUES(`permission`)",
        guildId, rankId, permission);
}

void GuildHouseManager::LogAction(Player* player, uint8 actionType, uint8 entityType, uint32 entry, uint32 guid, float x, float y, float z, float o)
{
    if (!player) return;

    CharacterDatabase.Execute(
        "INSERT INTO `dc_guild_house_log` (`guildId`, `playerGuid`, `actionType`, `entityType`, `entityEntry`, `entityGuid`, `mapId`, `posX`, `posY`, `posZ`, `orientation`, `timestamp`) "
        "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {})",
        player->GetGuildId(), player->GetGUID().GetCounter(), actionType, entityType, entry, guid, player->GetMapId(), x, y, z, o, (uint32)time(nullptr));
}

bool GuildHouseManager::UndoAction(Player* player, uint32 logId)
{
    if (!player) return false;

    // Fetch Log Entry
    QueryResult result;
    if (logId > 0)
    {
        result = CharacterDatabase.Query("SELECT * FROM `dc_guild_house_log` WHERE `id` = {} AND `guildId` = {}", logId, player->GetGuildId());
    }
    else
    {
         // Get Last Action
        result = CharacterDatabase.Query("SELECT * FROM `dc_guild_house_log` WHERE `guildId` = {} ORDER BY `id` DESC LIMIT 1", player->GetGuildId());
    }

    if (!result) return false;

    Field* fields = result->Fetch();
    uint32 id = fields[0].Get<uint32>();
    uint8 actionType = fields[3].Get<uint8>();
    uint8 entityType = fields[4].Get<uint8>();
    uint32 entityEntry = fields[5].Get<uint32>();
    uint32 entityGuid = fields[6].Get<uint32>(); // Logic uses LowGuid for tracking
    uint32 mapId = fields[7].Get<uint32>();
    float x = fields[8].Get<float>();
    float y = fields[9].Get<float>();
    float z = fields[10].Get<float>();
    float o = fields[11].Get<float>();

    uint32 phase = GetGuildPhase(player);

    Map* map = sMapMgr->FindMap(mapId, 0);
    if (!map) return false;

    // REVERT SPAWN -> DELETE
    if (actionType == GH_ACTION_SPAWN)
    {
        if (entityType == GH_ENTITY_CREATURE)
        {
            if (CreatureData const* crData = sObjectMgr->GetCreatureData(entityGuid))
            {
               if (Creature* creature = map->GetCreature(ObjectGuid::Create<HighGuid::Unit>(crData->id1, entityGuid)))
               {
                   creature->CombatStop();
                   creature->DeleteFromDB();
                   creature->AddObjectToRemoveList();
               }
            }
        }
        else if (entityType == GH_ENTITY_GAMEOBJECT)
        {
            if (GameObjectData const* goData = sObjectMgr->GetGameObjectData(entityGuid))
            {
                 if (GameObject* go = map->GetGameObject(ObjectGuid::Create<HighGuid::GameObject>(goData->id, entityGuid)))
                 {
                     go->DeleteFromDB();
                     go->Delete();
                 }
            }
        }
    }
    // REVERT DELETE -> SPAWN
    else if (actionType == GH_ACTION_DELETE)
    {
        if (entityType == GH_ENTITY_CREATURE)
        {
            Creature* creature = new Creature();
            if (creature->Create(map->GenerateLowGuid<HighGuid::Unit>(), map, phase, entityEntry, 0, x, y, z, o))
            {
                creature->SaveToDB(map->GetId(), (1 << map->GetSpawnMode()), phase);
                uint32 lowguid = creature->GetSpawnId();
                creature->CleanupsBeforeDelete();
                delete creature;
                creature = new Creature();
                if (creature->LoadCreatureFromDB(lowguid, map))
                    sObjectMgr->AddCreatureToGrid(lowguid, sObjectMgr->GetCreatureData(lowguid));
            }
        }
        // Objects similar... logic omitted for brevity, focusing on core
    }

    // Remove Log Entry
    CharacterDatabase.Execute("DELETE FROM `dc_guild_house_log` WHERE `id` = {}", id);
    return true;
}

bool GuildHouseManager::MoveGuildHouse(uint32 guildId, uint32 locationId)
{
    if (!guildId || !locationId)
        return false;

    // Get current data first for cleanup
    GuildHouseData* currentData = GetGuildHouseData(guildId);
    if (!currentData)
        return false; // Cannot move what doesn't exist

    // Fetch New Location Data
    QueryResult locationResult = WorldDatabase.Query(
        "SELECT `map`, `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_locations` WHERE `id` = {}",
        locationId);

    if (!locationResult)
        return false; // Invalid location

    Field* fields = locationResult->Fetch();
    uint32 newMap = fields[0].Get<uint32>();
    float posX = fields[1].Get<float>();
    float posY = fields[2].Get<float>();
    float posZ = fields[3].Get<float>();
    float ori = fields[4].Get<float>();

    // 1. Cleanup OLD location spawns
    CleanupGuildHouseSpawns(currentData->map, currentData->phase);

    // 2. Update DB with new location
    CharacterDatabase.Execute(
        "UPDATE `dc_guild_house` SET `map`={}, `positionX`={}, `positionY`={}, `positionZ`={}, `orientation`={} WHERE `guild`={}",
        newMap, posX, posY, posZ, ori, guildId);

    // 3. Update Cache & Spawn at NEW location
    // Note: Phase remains valid (guildId + 10)
    GuildHouseData newData(currentData->phase, newMap, posX, posY, posZ, ori, currentData->level);
    UpdateGuildHouseData(guildId, newData);

    // 4. Ensure NEW location is also clean (in case we moved back to a map that had orphans)
    CleanupGuildHouseSpawns(newMap, currentData->phase);

    // 5. Respawn Core NPCs
    SpawnTeleporterNPC(guildId, newMap, currentData->phase, posX, posY, posZ, ori);
    SpawnButlerNPC(guildId, newMap, currentData->phase, posX + 2.0f, posY, posZ, ori);

    return true;
}
