#include "dc_guildhouse.h"
#include "dc_guildhouse_decorations.h"

#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "DC/CrossSystem/CrossSystemDbSchema.h"
#include "GameObject.h"
#include "InstanceSaveMgr.h"
#include "Map.h"
#include "MapMgr.h"
#include "ObjectMgr.h"
#include "TemporarySummon.h"

#include <cmath>
#include <optional>
#include <unordered_map>
#include <vector>

static std::unordered_map<uint32, GuildHouseData> s_guildHouseCache;

namespace
{
    // Live in-world handle to a summoned butler spawn, so it can be despawned on
    // remove. instanceId disambiguates the several instances loaded at once.
    struct ContentLiveRef
    {
        ObjectGuid guid;
        uint32 instanceId = 0;
        bool isGameObject = false;
    };
}

// rowId -> live butler object (for the currently-loaded instances).
static std::unordered_map<uint32, ContentLiveRef> s_butlerLive;

namespace
{
    // Summon one piece of guild content NON-persistently into an instance map.
    // No SaveToDB: the object lives until the instance unloads and is recreated
    // from dc_guild_house_instance_spawns on the next load. Map::SummonCreature/
    // SummonGameObject default to PHASEMASK_NORMAL (1), matching instance players.
    // Returns the spawned object's GUID (empty on failure).
    ObjectGuid SummonContentRow(Map* map, bool isGameObject, uint32 entry,
        float x, float y, float z, float o, float scale)
    {
        if (!map)
            return ObjectGuid::Empty;

        if (isGameObject)
        {
            // respawnTime 0 -> permanent (not flagged temporary), stays for the
            // instance lifetime.
            if (GameObject* go = map->SummonGameObject(entry, x, y, z, o, 0.0f, 0.0f, 0.0f, 0.0f, 0))
            {
                if (scale > 0.0f && std::fabs(scale - 1.0f) > 0.001f)
                    go->SetObjectScale(scale);
                return go->GetGUID();
            }
        }
        else
        {
            // duration 0 -> TEMPSUMMON_MANUAL_DESPAWN (never auto-despawns).
            if (TempSummon* creature = map->SummonCreature(entry, Position(x, y, z, o)))
            {
                if (scale > 0.0f && std::fabs(scale - 1.0f) > 0.001f)
                    creature->SetObjectScale(scale);
                return creature->GetGUID();
            }
        }

        return ObjectGuid::Empty;
    }

    bool HasGuildHouseLevelColumn()
    {
        static std::optional<bool> cached;
        if (cached.has_value())
            return cached.value();

        cached = DC::DbSchema::CharacterColumnExists("dc_guild_house", "guildhouse_level");
        return cached.value();
    }
}

bool GuildHouseManager::HasLocationEnabledColumn()
{
    static std::optional<bool> cached;
    if (cached.has_value())
        return cached.value();

    cached = DC::DbSchema::WorldColumnExists("dc_guild_house_locations", "enabled");
    return cached.value();
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
    uint8 level = HasGuildHouseLevelColumn() ? fields[6].Get<uint8>() : 0;

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
        return 0;

    return data->level;
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

uint32 GuildHouseManager::EnsureGuildInstanceId(uint32 guildId)
{
    if (!guildId)
        return 0;

    // The guild's house lives on whichever guild-house map it chose (1409, 1413, ...). Resolve it
    // from the guild's record; fall back to the default map if there is no/invalid stored map.
    GuildHouseData* data = GetGuildHouseData(guildId);
    uint32 const ghMap = (data && IsGuildHouseMap(data->map)) ? data->map : GUILD_HOUSE_MAP_ID;

    // Reuse the persisted instance if it is still alive and still belongs to THIS guild's house map
    // (instance ids are global and recycled, so a stale id may now point at an unrelated dungeon, or
    // at the guild's previous house map after a move).
    if (QueryResult result = CharacterDatabase.Query(
            "SELECT `instance_id` FROM `dc_guild_house_instance` WHERE `guild_id` = {}", guildId))
    {
        uint32 storedId = result->Fetch()[0].Get<uint32>();
        if (InstanceSave* save = sInstanceSaveMgr->GetInstanceSave(storedId))
        {
            if (save->GetMapId() == ghMap)
                return storedId;
        }
    }

    // First visit, or the normal-dungeon InstanceSave expired and was reset:
    // mint a fresh instance and persist the mapping.
    uint32 newId = sMapMgr->GenerateInstanceId();
    InstanceSave* save = sInstanceSaveMgr->AddInstanceSave(
        ghMap, newId, Difficulty(DUNGEON_DIFFICULTY_NORMAL));
    if (!save)
        return 0;

    CharacterDatabase.Execute(
        "REPLACE INTO `dc_guild_house_instance` (`guild_id`, `instance_id`) VALUES ({}, {})",
        guildId, newId);

    return newId;
}

uint32 GuildHouseManager::AllocateContentId()
{
    // World-thread only. Seed once from the table's high-water mark, then hand
    // out monotonically. Both butler and decoration inserts call this, so the
    // shared table only ever sees explicit ids (no AUTO_INCREMENT races).
    static uint32 s_next = 0;
    if (s_next == 0)
    {
        if (QueryResult result = CharacterDatabase.Query(
                "SELECT COALESCE(MAX(`id`), 0) FROM `dc_guild_house_instance_spawns`"))
            s_next = result->Fetch()[0].Get<uint32>();
    }

    return ++s_next;
}

uint32 GuildHouseManager::GetGuildByInstanceId(uint32 instanceId)
{
    if (!instanceId)
        return 0;

    if (QueryResult result = CharacterDatabase.Query(
            "SELECT `guild_id` FROM `dc_guild_house_instance` WHERE `instance_id` = {}", instanceId))
        return result->Fetch()[0].Get<uint32>();

    return 0;
}

uint32 GuildHouseManager::GetGuildInstanceId(uint32 guildId)
{
    if (!guildId)
        return 0;

    if (QueryResult result = CharacterDatabase.Query(
            "SELECT `instance_id` FROM `dc_guild_house_instance` WHERE `guild_id` = {}", guildId))
        return result->Fetch()[0].Get<uint32>();

    return 0;
}

bool GuildHouseManager::IsInOwnGuildHouse(Player* player)
{
    if (!player || !player->GetGuildId() || !player->GetMap())
        return false;

    // Accept any guild-house map (1409, 1413, ...); ownership is proven by the instance binding below.
    if (!IsGuildHouseMap(player->GetMapId()))
        return false;

    return GetGuildByInstanceId(player->GetMap()->GetInstanceId()) == player->GetGuildId();
}

void GuildHouseManager::LoadGuildContentIntoInstance(Map* map, uint32 guildId)
{
    if (!map || !guildId)
        return;

    // Only butler content here; decorations load+register themselves (they need
    // a live-object registry for the editor) via DCGuildHouseDecorations.
    QueryResult result = CharacterDatabase.Query(
        "SELECT `id`, `spawn_type`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `scale` "
        "FROM `dc_guild_house_instance_spawns` WHERE `guild_id` = {} AND `source` = 'BUTLER'", guildId);
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();
        uint32 rowId = fields[0].Get<uint32>();
        bool isGameObject = fields[1].Get<std::string>() == "GAMEOBJECT";
        uint32 entry = fields[2].Get<uint32>();
        float x = fields[3].Get<float>();
        float y = fields[4].Get<float>();
        float z = fields[5].Get<float>();
        float o = fields[6].Get<float>();
        float scale = fields[7].Get<float>();

        // Drop any stale live ref before re-summoning into the fresh instance.
        s_butlerLive.erase(rowId);
        ObjectGuid guid = SummonContentRow(map, isGameObject, entry, x, y, z, o, scale);
        if (guid)
            s_butlerLive[rowId] = ContentLiveRef{ guid, map->GetInstanceId(), isGameObject };
    } while (result->NextRow());
}

void GuildHouseManager::ClearGuildContent(uint32 guildId)
{
    if (!guildId)
        return;

    // Drop the guild's butler live-refs (objects vanish on next instance reload).
    if (QueryResult result = CharacterDatabase.Query(
            "SELECT `id` FROM `dc_guild_house_instance_spawns` "
            "WHERE `guild_id` = {} AND `source` = 'BUTLER'", guildId))
    {
        do
        {
            s_butlerLive.erase(result->Fetch()[0].Get<uint32>());
        } while (result->NextRow());
    }

    CharacterDatabase.Execute(
        "DELETE FROM `dc_guild_house_instance_spawns` WHERE `guild_id` = {}", guildId);
    DCGuildHouseDecorations::ForgetGuild(guildId);
}

void GuildHouseManager::ListButlerContent(uint32 guildId,
    std::vector<ButlerContentItem>& out)
{
    if (!guildId)
        return;

    QueryResult result = CharacterDatabase.Query(
        "SELECT `id`, `entry`, `spawn_type`, `paid_copper` "
        "FROM `dc_guild_house_instance_spawns` "
        "WHERE `guild_id` = {} AND `source` = 'BUTLER' ORDER BY `id`", guildId);
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();
        ButlerContentItem item;
        item.id = fields[0].Get<uint32>();
        item.entry = fields[1].Get<uint32>();
        item.isGameObject = fields[2].Get<std::string>() == "GAMEOBJECT";
        item.paidCopper = fields[3].Get<uint32>();

        if (item.isGameObject)
        {
            if (GameObjectTemplate const* tmpl = sObjectMgr->GetGameObjectTemplate(item.entry))
                item.name = tmpl->name;
        }
        else
        {
            if (CreatureTemplate const* tmpl = sObjectMgr->GetCreatureTemplate(item.entry))
                item.name = tmpl->Name;
        }
        if (item.name.empty())
            item.name = std::to_string(item.entry);

        out.push_back(item);
    } while (result->NextRow());
}

bool GuildHouseManager::RemoveButlerContent(Player* player, uint32 rowId,
    uint32* outRefundCopper)
{
    if (!player)
        return false;

    uint32 const guildId = player->GetGuildId();
    if (!guildId || !rowId)
        return false;

    QueryResult result = CharacterDatabase.Query(
        "SELECT `spawn_type`, `paid_copper` FROM `dc_guild_house_instance_spawns` "
        "WHERE `id` = {} AND `guild_id` = {} AND `source` = 'BUTLER'", rowId, guildId);
    if (!result)
        return false;

    Field* fields = result->Fetch();
    bool const isGameObject = fields[0].Get<std::string>() == "GAMEOBJECT";
    uint32 const paidCopper = fields[1].Get<uint32>();

    // Despawn the live object if it is in the player's current instance.
    auto it = s_butlerLive.find(rowId);
    if (it != s_butlerLive.end())
    {
        if (player->GetMap()
            && player->GetMap()->GetInstanceId() == it->second.instanceId)
        {
            if (isGameObject)
            {
                if (GameObject* go = player->GetMap()->GetGameObject(it->second.guid))
                    go->Delete();
            }
            else if (Creature* creature = player->GetMap()->GetCreature(it->second.guid))
            {
                creature->DespawnOrUnsummon();
            }
        }
        s_butlerLive.erase(it);
    }

    CharacterDatabase.Execute(
        "DELETE FROM `dc_guild_house_instance_spawns` WHERE `id` = {}", rowId);

    uint32 refundPercent =
        sConfigMgr->GetOption<uint32>("DC.GuildHouse.Butler.RefundPercent", 50);
    if (refundPercent > 100)
        refundPercent = 100;

    uint32 const refund = paidCopper * refundPercent / 100;
    if (refund)
        player->ModifyMoney(static_cast<int32>(refund));

    if (outRefundCopper)
        *outRefundCopper = refund;
    return true;
}

bool GuildHouseManager::GuildOwnsContent(uint32 guildId, uint32 entry, bool isGameObject)
{
    if (!guildId || !entry)
        return false;

    QueryResult result = CharacterDatabase.Query(
        "SELECT 1 FROM `dc_guild_house_instance_spawns` "
        "WHERE `guild_id` = {} AND `entry` = {} AND `spawn_type` = '{}' AND `source` = 'BUTLER' LIMIT 1",
        guildId, entry, isGameObject ? "GAMEOBJECT" : "CREATURE");

    return result != nullptr;
}

bool GuildHouseManager::PlaceGuildContent(Map* map, uint32 guildId, bool isGameObject, uint32 entry,
    float x, float y, float z, float o, float scale, uint32 paidCopper, uint64 placedBy)
{
    if (!map || !guildId || !entry)
        return false;

    uint32 const id = AllocateContentId();
    CharacterDatabase.Execute(
        "INSERT INTO `dc_guild_house_instance_spawns` "
        "(`id`, `guild_id`, `spawn_type`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `scale`, `source`, `paid_copper`, `placed_by`) "
        "VALUES ({}, {}, '{}', {}, {}, {}, {}, {}, {}, 'BUTLER', {}, {})",
        id, guildId, isGameObject ? "GAMEOBJECT" : "CREATURE", entry, x, y, z, o, scale, paidCopper, placedBy);

    ObjectGuid guid = SummonContentRow(map, isGameObject, entry, x, y, z, o, scale);
    if (guid)
        s_butlerLive[id] = ContentLiveRef{ guid, map->GetInstanceId(), isGameObject };
    return true;
}

bool GuildHouseManager::TeleportToGuildHouse(Player* player, uint32 guildId)
{
    if (!player || !guildId)
        return false;

    // The guild must own a house (row in dc_guild_house) to be teleported.
    GuildHouseData* data = GetGuildHouseData(guildId);
    if (!data)
        return false;

    uint32 instanceId = EnsureGuildInstanceId(guildId);
    if (!instanceId)
        return false;

    InstanceSave* save = sInstanceSaveMgr->GetInstanceSave(instanceId);
    if (!save)
        return false;

    // Permanent bind: in PlayerGetDestinationInstanceId the "self perm" bind has
    // the highest priority, so destination routing always lands the player in
    // their guild's instance even when grouped with members bound elsewhere.
    sInstanceSaveMgr->PlayerBindToInstance(player->GetGUID(), save, true, player);

    // Entrance inside the instanced guild-house map. The instance id alone provides isolation; the
    // MAP now depends on which guild-house skin the guild chose (1409 vs 1413, ...). The original
    // 1409 house keeps its exact hard-coded entrance (no change for existing guilds); secondary house
    // maps use the per-location entrance coords stored on the guild's record (from
    // dc_guild_house_locations, backfilled by GetGuildHouseData).
    uint32 const ghMap = IsGuildHouseMap(data->map) ? data->map : GUILD_HOUSE_MAP_ID;
    float x = GUILD_HOUSE_ENTRANCE_X, y = GUILD_HOUSE_ENTRANCE_Y,
          z = GUILD_HOUSE_ENTRANCE_Z, o = GUILD_HOUSE_ENTRANCE_O;
    if (ghMap != GUILD_HOUSE_MAP_ID)
    {
        x = data->posX; y = data->posY; z = data->posZ; o = data->ori;
    }
    return player->TeleportTo(ghMap, x, y, z, o);
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

    // Wipe the guild's dynamic instance content (butler + decorations) too.
    ClearGuildContent(guildId);

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
                if (Creature* creature = map->GetCreature(ObjectGuid::Create<HighGuid::Unit>(crData->id, lowguid)))
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
               if (Creature* creature = map->GetCreature(ObjectGuid::Create<HighGuid::Unit>(crData->id, entityGuid)))
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

bool GuildHouseManager::MoveGuildHouse(uint32 guildId, uint32 locationId, bool ignoreDisabled)
{
    if (!guildId || !locationId)
        return false;

    // Get current data first for cleanup
    GuildHouseData* currentData = GetGuildHouseData(guildId);
    if (!currentData)
        return false; // Cannot move what doesn't exist

    // Fetch New Location Data
    QueryResult locationResult;
    if (HasLocationEnabledColumn() && !ignoreDisabled)
    {
        locationResult = WorldDatabase.Query(
            "SELECT `map`, `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_locations` WHERE `id` = {} AND `enabled` = 1",
            locationId);
    }
    else
    {
        locationResult = WorldDatabase.Query(
            "SELECT `map`, `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_locations` WHERE `id` = {}",
            locationId);
    }

    if (!locationResult)
        return false; // Invalid location

    Field* fields = locationResult->Fetch();
    uint32 newMap = fields[0].Get<uint32>();
    float posX = fields[1].Get<float>();
    float posY = fields[2].Get<float>();
    float posZ = fields[3].Get<float>();
    float ori = fields[4].Get<float>();

    // 0. Capture everyone currently standing in the guild's OLD instance BEFORE we repoint the house,
    // so the switch pulls them across to the new map automatically (otherwise they'd be stranded in the
    // old instance until they re-teleported). This whole function runs synchronously on the world thread
    // and the steps below never despawn players, so the collected Player* stay valid until we teleport
    // them in step 6.
    std::vector<Player*> toMigrate;
    if (uint32 oldInstanceId = GetGuildInstanceId(guildId))
    {
        if (Map* oldInstance = sMapMgr->FindMap(currentData->map, oldInstanceId))
        {
            Map::PlayerList const& players = oldInstance->GetPlayers();
            for (Map::PlayerList::const_iterator it = players.begin(); it != players.end(); ++it)
                if (Player* p = it->GetSource())
                    toMigrate.push_back(p);
        }
    }

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

    // 6. Migrate any members who were inside the old instance to the new house. TeleportToGuildHouse
    // mints/reuses the guild's instance on the NEW map (EnsureGuildInstanceId sees the persisted
    // instance no longer matches the guild's map after the UPDATE above) and binds the player to it, so
    // everyone who was in the old house lands together in the new map's instance instead of being left
    // behind. The first teleport mints the new instance; the rest reuse it.
    for (Player* p : toMigrate)
        TeleportToGuildHouse(p, guildId);

    return true;
}
