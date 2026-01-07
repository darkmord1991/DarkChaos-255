#include "guildhouse.h"

#include "Chat.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "MapMgr.h"
#include "ObjectMgr.h"

#include <unordered_map>

static std::unordered_map<uint32, GuildHouseData> s_GuildHouseCache;

GuildHouseData* GuildHouseManager::GetGuildHouseData(uint32 guildId)
{
    // Check Cache
    auto it = s_GuildHouseCache.find(guildId);
    if (it != s_GuildHouseCache.end())
        return &it->second;

    // Load from DB
    QueryResult result = CharacterDatabase.Query(
        "SELECT `phase`, `map`, `positionX`, `positionY`, `positionZ`, `orientation` "
        "FROM `dc_guild_house` WHERE `guild` = {}",
        guildId);

    if (!result)
        return nullptr;

    Field* fields = result->Fetch();
    uint32 phase = fields[0].Get<uint32>();
    uint32 map = fields[1].Get<uint32>();
    float posX = fields[2].Get<float>();
    float posY = fields[3].Get<float>();
    float posZ = fields[4].Get<float>();
    float ori = fields[5].Get<float>();

    // Store in Cache
    GuildHouseData& data = s_GuildHouseCache[guildId];
    data = GuildHouseData(phase, map, posX, posY, posZ, ori);
    return &data;
}

void GuildHouseManager::UpdateGuildHouseData(uint32 guildId, GuildHouseData const& data)
{
    s_GuildHouseCache[guildId] = data;
}

void GuildHouseManager::RemoveGuildHouseData(uint32 guildId)
{
    s_GuildHouseCache.erase(guildId);
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
        QueryResult result = WorldDatabase.Query("SELECT COUNT(*) FROM `creature` WHERE `map`={} AND `id`={} AND `phaseMask`={}", mapId, entry, phase);
        if (result)
            return result->Fetch()[0].Get<uint32>() > 0;
    }
    return false;
}
