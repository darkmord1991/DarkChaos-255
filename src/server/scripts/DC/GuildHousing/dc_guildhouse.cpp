#include "ScriptMgr.h"
#include "Player.h"
#include "Configuration/Config.h"
#include "Creature.h"
#include "Guild.h"
#include "SpellAuraEffects.h"
#include "Chat.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "GuildMgr.h"
#include "Define.h"
#include "GossipDef.h"
#include "GameObject.h"
#include "GameGraveyard.h"
#include "Transport.h"
#include "Maps/MapMgr.h"
#include "dc_guildhouse.h"

#include <algorithm>
#include <cctype>
#include <limits>
#include <string>

namespace
{
    constexpr float GUILD_HOUSE_GRAVEYARD_OVERRIDE_RADIUS = 400.0f;

    GraveyardStruct const* FindNearestGraveyardOnMap(uint32 mapId, float x, float y,
                                                     float z)
    {
        GraveyardStruct const* nearestGraveyard = nullptr;
        float nearestDistance = std::numeric_limits<float>::max();

        for (auto const& graveyardEntry : sGraveyard->GetGraveyardData())
        {
            GraveyardStruct const& graveyard = graveyardEntry.second;
            if (graveyard.Map != mapId)
                continue;

            float dx = graveyard.x - x;
            float dy = graveyard.y - y;
            float dz = graveyard.z - z;
            float distance = dx * dx + dy * dy + dz * dz;
            if (distance < nearestDistance)
            {
                nearestDistance = distance;
                nearestGraveyard = &graveyard;
            }
        }

        return nearestGraveyard;
    }

    bool IsWithinGuildHouseRespawnRange(WorldLocation const& location,
                                        GuildHouseData const& houseData)
    {
        float dx = location.GetPositionX() - houseData.posX;
        float dy = location.GetPositionY() - houseData.posY;
        float dz = location.GetPositionZ() - houseData.posZ;
        float distance = dx * dx + dy * dy + dz * dz;
        return distance <=
            GUILD_HOUSE_GRAVEYARD_OVERRIDE_RADIUS *
            GUILD_HOUSE_GRAVEYARD_OVERRIDE_RADIUS;
    }

    bool TryGetGuildHouseRespawnContext(Player* player, bool nearCorpse,
                                        GuildHouseData const*& houseData,
                                        WorldLocation& location)
    {
        houseData = nullptr;

        if (!player || !player->GetGuildId())
            return false;

        houseData = GuildHouseManager::GetGuildHouseData(player->GetGuildId());
        if (!houseData)
            return false;

        WorldLocation primary = nearCorpse ? player->GetCorpseLocation()
                                           : player->GetWorldLocation();
        if (primary.GetMapId() == houseData->map &&
            IsWithinGuildHouseRespawnRange(primary, *houseData))
        {
            location = primary;
            return true;
        }

        WorldLocation secondary = nearCorpse ? player->GetWorldLocation()
                                             : player->GetCorpseLocation();
        if (secondary.GetMapId() == houseData->map &&
            IsWithinGuildHouseRespawnRange(secondary, *houseData))
        {
            location = secondary;
            return true;
        }

        return false;
    }

    GraveyardStruct const* GetGuildHouseRespawnGraveyard(Player* player,
                                                         bool nearCorpse)
    {
        GuildHouseData const* houseData = nullptr;
        WorldLocation location;
        if (!TryGetGuildHouseRespawnContext(player, nearCorpse, houseData,
                                            location))
            return nullptr;

        return FindNearestGraveyardOnMap(location.GetMapId(),
                                         location.GetPositionX(),
                                         location.GetPositionY(),
                                         location.GetPositionZ());
    }

    void ReviveAtGuildHouseRespawn(Player* player,
                                   GuildHouseData const& houseData,
                                   GraveyardStruct const* graveyard,
                                   char const* message)
    {
        float targetX = houseData.posX;
        float targetY = houseData.posY;
        float targetZ = houseData.posZ;
        float targetO = houseData.ori;

        if (graveyard)
        {
            targetX = graveyard->x;
            targetY = graveyard->y;
            targetZ = graveyard->z;
            targetO = player->GetOrientation();
        }

        player->ResurrectPlayer(0.5f);
        player->RemoveByteFlag(PLAYER_FIELD_BYTES, 0,
                               PLAYER_FIELD_BYTE_RELEASE_TIMER);
        player->SpawnCorpseBones();
        player->TeleportTo(houseData.map, targetX, targetY, targetZ, targetO);

        if (message && *message)
            ChatHandler(player->GetSession()).PSendSysMessage(message);
    }
}

class GuildHelper : public GuildScript
{

public:
    GuildHelper() : GuildScript("GuildHelper") {}

    void OnCreate(Guild* /*guild*/, Player* leader, const std::string& /*name*/)
    {
        ChatHandler(leader->GetSession()).PSendSysMessage("You now own a guild. You can purchase a Guild House!");
    }

    void OnDisband(Guild* guild)
    {

        if (RemoveGuildHouse(guild))
        {
            LOG_INFO("modules.dc", "GUILDHOUSE: Deleting Guild House data due to disbanding of guild...");
        }
        else
        {
            LOG_INFO("modules.dc", "GUILDHOUSE: Error deleting Guild House data during disbanding of guild!!");
        }
    }

    bool RemoveGuildHouse(Guild* guild)
    {
        return GuildHouseManager::RemoveGuildHouse(guild);
    }
};

void AddGuildHouseNpcScripts();

class GuildHousePlayerScript : public PlayerScript
{
public:
    GuildHousePlayerScript() : PlayerScript("GuildHousePlayerScript") {}

    void EnsureButlerSpawned(Player* player, uint32 guildPhase)
    {
        if (!player)
            return;

        // If a butler already exists in this phase, do nothing.
        if (player->FindNearestCreature(95104, VISIBLE_RANGE, true))
            return;

        Map* map = player->GetMap();
        if (!map)
            return;

        float posX = 16229.422f;
        float posY = 16283.675f;
        float posZ = 13.175704f;
        float ori = 3.036652f;

        Creature* creature = new Creature();
        if (!creature->Create(map->GenerateLowGuid<HighGuid::Unit>(), map, guildPhase, 95104, 0, posX, posY, posZ, ori))
        {
            delete creature;
            return;
        }

        creature->SaveToDB(map->GetId(), (1 << map->GetSpawnMode()), guildPhase);
        uint32 lowguid = creature->GetSpawnId();

        creature->CleanupsBeforeDelete();
        delete creature;

        creature = new Creature();
        if (!creature->LoadCreatureFromDB(lowguid, map))
        {
            delete creature;
            return;
        }

        sObjectMgr->AddCreatureToGrid(lowguid, sObjectMgr->GetCreatureData(lowguid));
    }

    void OnPlayerLogin(Player* player)
    {
        CheckPlayer(player);
    }

    void OnPlayerUpdateZone(Player* player, uint32 newZone, uint32 /*newArea*/)
    {
        if (newZone == 876)
            CheckPlayer(player);
        else
            player->SetPhaseMask(GetNormalPhase(player), true);
    }

    void OnPlayerBeforeChooseGraveyard(Player* player, TeamId /*teamId*/,
                                       bool nearCorpse,
                                       uint32& graveyardOverride) override
    {
        if (graveyardOverride || !player || !player->GetGuildId())
            return;

        if (GraveyardStruct const* graveyard =
                GetGuildHouseRespawnGraveyard(player, nearCorpse))
        {
            graveyardOverride = graveyard->ID;
        }
    }

    void OnPlayerJustDied(Player* player) override
    {
        if (!player)
            return;

        GuildHouseData const* houseData = nullptr;
        WorldLocation location;
        if (!TryGetGuildHouseRespawnContext(player, false, houseData, location))
            return;

        ReviveAtGuildHouseRespawn(
            player, *houseData,
            GetGuildHouseRespawnGraveyard(player, false),
            "Guild House: You were revived at your guild house graveyard.");
    }

    bool OnPlayerCanRepopAtGraveyard(Player* player) override
    {
        if (!player || player->IsAlive())
            return true;

        GuildHouseData const* houseData = nullptr;
        WorldLocation location;
        if (!TryGetGuildHouseRespawnContext(player, false, houseData, location))
            return true;

        ReviveAtGuildHouseRespawn(
            player, *houseData,
            GetGuildHouseRespawnGraveyard(player, false),
            "Guild House: You have been revived at your guild house.");
        return false;
    }

    bool OnPlayerBeforeTeleport(Player* player, uint32 mapid, float x, float y, float z, float orientation, uint32 options, Unit* target)
    {
        (void)mapid;
        (void)x;
        (void)y;
        (void)z;
        (void)orientation;
        (void)options;
        (void)target;

        if (player->GetZoneId() == 876 && player->GetAreaId() == 876) // GM Island
        {
            // Remove the rested state when teleporting from the guild house
            player->RemoveRestState();
        }

        return true;
    }

    uint32 GetNormalPhase(Player* player) const
    {
        if (player->IsGameMaster())
            return PHASEMASK_ANYWHERE;

        uint32 phase = player->GetPhaseByAuras();
        if (!phase)
            return PHASEMASK_NORMAL;
        else
            return phase;
    }

    void CheckPlayer(Player* player)
    {
        GuildHouseData const* houseData = GuildHouseManager::GetGuildHouseData(player->GetGuildId());
        uint32 guildPhase = houseData ? houseData->phase : GetGuildPhase(player);

        if (player->GetZoneId() == 876 && player->GetAreaId() == 876) // GM Island
        {
            // Set the guild house as a rested area
            player->SetRestState(0);

            // If player is not in a guild he doesnt have a guild house teleport away
            // TODO: What if they are in a guild, but somehow are in the wrong phaseMask and seeing someone else's area?

            if (!houseData || !player->GetGuild())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("Your guild does not own a Guild House.");
                TeleportToDefault(player);
                return;
            }

            player->SetPhaseMask(guildPhase, true);
            EnsureButlerSpawned(player, guildPhase);
        }
        else
            player->SetPhaseMask(GetNormalPhase(player), true);
    }

    void TeleportToDefault(Player* player)
    {
        if (player->GetTeamId() == TEAM_ALLIANCE)
            player->TeleportTo(0, -8833.379883f, 628.627991f, 94.006599f, 1.0f);
        else
            player->TeleportTo(1, 1486.048340f, -4415.140625f, 24.187496f, 0.13f);
    }
};

class GuildHouseGlobal : public GlobalScript
{
public:
    GuildHouseGlobal() : GlobalScript("GuildHouseGlobal") {}

    void OnBeforeWorldObjectSetPhaseMask(WorldObject const* worldObject, uint32 & /*oldPhaseMask*/, uint32 & /*newPhaseMask*/, bool &useCombinedPhases, bool & /*update*/) override
    {
        if (worldObject->GetZoneId() == 876)
            useCombinedPhases = false;
        else
            useCombinedPhases = true;
    }
};

void AddGuildHouseScripts()
{
    new GuildHelper();
    AddGuildHouseNpcScripts();
    new GuildHousePlayerScript();
    new GuildHouseGlobal();
}
