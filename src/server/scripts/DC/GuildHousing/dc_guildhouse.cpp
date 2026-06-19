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

};

void AddGuildHouseScripts()
{
    new GuildHelper();
    AddGuildHouseNpcScripts();
    new GuildHousePlayerScript();
}
