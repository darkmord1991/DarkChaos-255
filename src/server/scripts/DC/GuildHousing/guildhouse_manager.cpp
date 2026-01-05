#include "guildhouse.h"

#include "Chat.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "MapMgr.h"
#include "ObjectMgr.h"

bool GuildHouseManager::TeleportToGuildHouse(Player* player, uint32 guildId)
{
    if (!player)
        return false;

    if (!guildId)
        return false;

    QueryResult result = CharacterDatabase.Query(
        "SELECT `phase`, `map`, `positionX`, `positionY`, `positionZ`, `orientation` "
        "FROM `dc_guild_house` WHERE `guild` = {}",
        guildId);

    if (!result)
        return false;

    Field* fields = result->Fetch();
    uint32 phase = fields[0].Get<uint32>();
    uint32 map = fields[1].Get<uint32>();
    float posX = fields[2].Get<float>();
    float posY = fields[3].Get<float>();
    float posZ = fields[4].Get<float>();
    float ori = fields[5].Get<float>();

    // This guild housing implementation currently uses phasing on a shared map.
    // Setting phase mask before teleport helps ensure correct visibility immediately on arrival.
    if (phase)
        player->SetPhaseMask(phase, true);

    player->TeleportTo(map, posX, posY, posZ, ori);
    return true;
}

bool GuildHouseManager::RemoveGuildHouse(Guild* guild)
{
    if (!guild)
        return false;

    uint32 guildId = guild->GetId();
    uint32 guildPhase = GetGuildPhase(guildId);

    // Remove any spawned objects/creatures tied to the guild phase on the shared housing map.
    // This mirrors the cleanup logic used when selling a guild house.
    Map* map = sMapMgr->FindMap(1, 0);

    if (map)
    {
        QueryResult creatureResult = WorldDatabase.Query(
            "SELECT `guid` FROM `creature` WHERE `map` = 1 AND `phaseMask` = {}",
            guildPhase);

        QueryResult gameobjResult = WorldDatabase.Query(
            "SELECT `guid` FROM `gameobject` WHERE `map` = 1 AND `phaseMask` = {}",
            guildPhase);

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

    // Delete the guild house ownership record.
    CharacterDatabase.Query("DELETE FROM `dc_guild_house` WHERE `guild` = {}", guildId);
    return true;
}
