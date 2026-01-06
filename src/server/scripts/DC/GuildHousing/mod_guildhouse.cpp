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
#include "DataMap.h"
#include "GameObject.h"
#include "Transport.h"
#include "Maps/MapMgr.h"
#include "guildhouse.h"

#include <algorithm>
#include <cctype>
#include <string>

class GuildData : public DataMap::Base
{
public:
    GuildData() {}
    GuildData(uint32 phase, float posX, float posY, float posZ, float ori) : phase(phase), posX(posX), posY(posY), posZ(posZ), ori(ori) {}
    uint32 phase;
    float posX;
    float posY;
    float posZ;
    float ori;
};

class GuildHelper : public GuildScript
{

public:
    GuildHelper() : GuildScript("GuildHelper") {}

    void OnCreate(Guild* /*guild*/, Player* leader, const std::string& /*name*/)
    {
        ChatHandler(leader->GetSession()).PSendSysMessage("You now own a guild. You can purchase a Guild House!");
    }

    uint32 GetGuildPhase(Guild* guild)
    {
        return ::GetGuildPhase(guild);
    }

    void OnDisband(Guild* guild)
    {

        if (RemoveGuildHouse(guild))
        {
            LOG_INFO("modules", "GUILDHOUSE: Deleting Guild House data due to disbanding of guild...");
        }
        else
        {
            LOG_INFO("modules", "GUILDHOUSE: Error deleting Guild House data during disbanding of guild!!");
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
        GuildData* guildData = player->CustomData.GetDefault<GuildData>("phase");
        QueryResult result = CharacterDatabase.Query("SELECT `id`, `guild`, `phase`, `map`,`positionX`, `positionY`, `positionZ`, `orientation` FROM dc_guild_house WHERE `guild` = {}", player->GetGuildId());

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                guildData->phase = fields[2].Get<uint32>();
            } while (result->NextRow());
        }

        if (player->GetZoneId() == 876 && player->GetAreaId() == 876) // GM Island
        {
            // Set the guild house as a rested area
            player->SetRestState(0);

            // If player is not in a guild he doesnt have a guild house teleport away
            // TODO: What if they are in a guild, but somehow are in the wrong phaseMask and seeing someone else's area?

            if (!result || !player->GetGuild())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("Your guild does not own a Guild House.");
                teleportToDefault(player);
                return;
            }

            player->SetPhaseMask(guildData->phase, true);
            EnsureButlerSpawned(player, guildData->phase);
        }
        else
            player->SetPhaseMask(GetNormalPhase(player), true);
    }

    void teleportToDefault(Player* player)
    {
        if (player->GetTeamId() == TEAM_ALLIANCE)
            player->TeleportTo(0, -8833.379883f, 628.627991f, 94.006599f, 1.0f);
        else
            player->TeleportTo(1, 1486.048340f, -4415.140625f, 24.187496f, 0.13f);
    }
};

using namespace Acore::ChatCommands;

class GuildHouseCommand : public CommandScript
{
public:
    GuildHouseCommand() : CommandScript("GuildHouseCommand") {}

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable GuildHouseCommandTable =
        {
            {"teleport", HandleGuildHouseTeleCommand, SEC_PLAYER, Console::Yes},
            {"butler", HandleSpawnButlerCommand, SEC_PLAYER, Console::Yes},
            {"admin", GetAdminCommands()},
        };

        static ChatCommandTable GuildHouseCommandBaseTable =
        {
            {"guildhouse", GuildHouseCommandTable},
            {"gh", GuildHouseCommandTable}
        };

        return GuildHouseCommandBaseTable;
    }

    static ChatCommandTable const& GetAdminCommands()
    {
        static ChatCommandTable AdminCommandTable =
        {
            {"teleport", HandleAdminTeleportCommand, SEC_GAMEMASTER, Console::Yes},
            {"delete", HandleAdminDeleteCommand, SEC_GAMEMASTER, Console::Yes},
            {"buy", HandleAdminBuyCommand, SEC_GAMEMASTER, Console::Yes}
        };

        return AdminCommandTable;
    }

    static void TrimString(std::string& str)
    {
        auto notSpace = [](unsigned char ch) { return !std::isspace(ch); };
        str.erase(str.begin(), std::find_if(str.begin(), str.end(), notSpace));
        str.erase(std::find_if(str.rbegin(), str.rend(), notSpace).base(), str.end());
    }

    static bool IsAllDigits(std::string const& str)
    {
        return !str.empty() && std::all_of(str.begin(), str.end(), [](unsigned char ch) { return std::isdigit(ch); });
    }

    static bool SpawnGuildHouseCreature(uint32 entry, float posX, float posY, float posZ, float ori, uint32 guildPhase)
    {
        Map* map = sMapMgr->FindMap(1, 0); // GM Island Map
        if (!map)
            return false;

        Creature* creature = new Creature();

        if (!creature->Create(map->GenerateLowGuid<HighGuid::Unit>(), map, guildPhase, entry, 0, posX, posY, posZ, ori))
        {
            delete creature;
            return false;
        }

        creature->SaveToDB(map->GetId(), (1 << map->GetSpawnMode()), guildPhase);
        uint32 lowguid = creature->GetSpawnId();

        creature->CleanupsBeforeDelete();
        delete creature;

        creature = new Creature();
        if (!creature->LoadCreatureFromDB(lowguid, map))
        {
            delete creature;
            return false;
        }

        sObjectMgr->AddCreatureToGrid(lowguid, sObjectMgr->GetCreatureData(lowguid));
        return true;
    }

    static bool SpawnGuildHouseTeleporter(uint32 guildPhase)
    {
        // Match the existing SpawnTeleporterNPC defaults
        uint32 entry = 800002;
        float posX = 16222.0f;
        float posY = 16270.0f;
        float posZ = 13.1f;
        float ori = 4.7f;
        return SpawnGuildHouseCreature(entry, posX, posY, posZ, ori, guildPhase);
    }

    static bool SpawnGuildHouseButler(uint32 guildPhase)
    {
        // Match the existing SpawnButlerNPC defaults
        uint32 entry = 95104;
        float posX = 16229.422f;
        float posY = 16283.675f;
        float posZ = 13.175704f;
        float ori = 3.036652f;
        return SpawnGuildHouseCreature(entry, posX, posY, posZ, ori, guildPhase);
    }

    static bool HandleAdminTeleportCommand(ChatHandler* handler, const char* args)
    {
        if (!*args)
            return false;

        std::string guildName = args;
        Guild* guild = sGuildMgr->GetGuildByName(guildName);

        if (!guild)
        {
             handler->SendSysMessage("Guild not found.");
             handler->SetSentErrorMessage(true);
             return false;
        }

        Player* player = handler->GetSession()->GetPlayer();
        if (!GuildHouseManager::TeleportToGuildHouse(player, guild->GetId()))
        {
            handler->SendSysMessage("That guild does not own a Guild House.");
            handler->SetSentErrorMessage(true);
            return false; 
        }

        return true;
    }

    static bool HandleAdminDeleteCommand(ChatHandler* handler, const char* args)
    {
        if (!*args)
            return false;

        std::string guildName = args;
        Guild* guild = sGuildMgr->GetGuildByName(guildName);

        if (!guild)
        {
             handler->SendSysMessage("Guild not found.");
             handler->SetSentErrorMessage(true);
             return false;
        }

        if (GuildHouseManager::RemoveGuildHouse(guild))
        {
            handler->SendSysMessage("Guild House deleted successfully.");
        }
        else
        {
            handler->SendSysMessage("Failed to delete Guild House (or they didn't have one).");
        }

        return true;
    }

    // .guildhouse admin buy <guildId> [locationId]
    // .guildhouse admin buy <guildName> [locationId]
    // Creates the guild house record with no cost and spawns teleporter/butler in the guild phase.
    static bool HandleAdminBuyCommand(ChatHandler* handler, const char* args)
    {
        if (!handler || !handler->GetSession() || !handler->GetSession()->GetPlayer())
            return false;

        if (!args || !*args)
            return false;

        std::string input = args;
        TrimString(input);
        if (input.empty())
            return false;

        // Parse optional locationId. Prefer guildId syntax when possible.
        uint32 guildId = 0;
        uint32 locationId = 0;
        Guild* guild = nullptr;

        // Split first token
        std::string firstToken;
        std::string remainder;
        {
            size_t spacePos = input.find_first_of(" \t");
            if (spacePos == std::string::npos)
            {
                firstToken = input;
                remainder.clear();
            }
            else
            {
                firstToken = input.substr(0, spacePos);
                remainder = input.substr(spacePos + 1);
                TrimString(remainder);
            }
        }

        if (IsAllDigits(firstToken))
        {
            guildId = static_cast<uint32>(std::stoul(firstToken));
            guild = sGuildMgr->GetGuildById(guildId);

            if (!remainder.empty() && IsAllDigits(remainder))
                locationId = static_cast<uint32>(std::stoul(remainder));
        }
        else
        {
            // Treat as guild name, optionally with trailing locationId
            std::string guildName = input;

            size_t lastSpace = guildName.find_last_of(" \t");
            if (lastSpace != std::string::npos)
            {
                std::string maybeId = guildName.substr(lastSpace + 1);
                if (IsAllDigits(maybeId))
                {
                    locationId = static_cast<uint32>(std::stoul(maybeId));
                    guildName = guildName.substr(0, lastSpace);
                    TrimString(guildName);
                }
            }

            guild = sGuildMgr->GetGuildByName(guildName);
            if (guild)
                guildId = guild->GetId();
        }

        if (!guild || !guildId)
        {
            handler->SendSysMessage("Guild not found.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        QueryResult alreadyHas = CharacterDatabase.Query(
            "SELECT `id` FROM `dc_guild_house` WHERE `guild` = {}",
            guildId);

        if (alreadyHas)
        {
            handler->SendSysMessage("That guild already owns a Guild House.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        // Load location
        uint32 map = 0;
        float posX = 0.0f;
        float posY = 0.0f;
        float posZ = 0.0f;
        float ori = 0.0f;

        QueryResult locationResult;
        if (locationId)
        {
            locationResult = WorldDatabase.Query(
                "SELECT `id`, `map`, `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_locations` WHERE `id` = {}",
                locationId);
        }
        else
        {
            // Default to the first configured location
            locationResult = WorldDatabase.Query(
                "SELECT `id`, `map`, `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_locations` ORDER BY `id` ASC LIMIT 1");
        }

        if (!locationResult)
        {
            handler->SendSysMessage("Guild House location not found.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        Field* fields = locationResult->Fetch();
        locationId = fields[0].Get<uint32>();
        map = fields[1].Get<uint32>();
        posX = fields[2].Get<float>();
        posY = fields[3].Get<float>();
        posZ = fields[4].Get<float>();
        ori = fields[5].Get<float>();

        uint32 guildPhase = ::GetGuildPhase(guildId);

        CharacterDatabase.Query(
            "INSERT INTO `dc_guild_house` (guild, phase, map, positionX, positionY, positionZ, orientation) "
            "VALUES ({}, {}, {}, {}, {}, {}, {})",
            guildId, guildPhase, map, posX, posY, posZ, ori);

        // Spawn portal/butler for that guild phase (no cost).
        if (!SpawnGuildHouseTeleporter(guildPhase))
            handler->SendSysMessage("Warning: Failed to spawn Guild House teleporter.");
        if (!SpawnGuildHouseButler(guildPhase))
            handler->SendSysMessage("Warning: Failed to spawn Guild House butler.");

        handler->PSendSysMessage("Purchased Guild House for guild '{}' at location {} (no cost).", guild->GetName(), locationId);
        LOG_INFO("modules", "GUILDHOUSE: Admin purchased guildhouse for GuildId: '{}' at location ID {}", guildId, locationId);
        return true;
    }

    static uint32 GetGuildPhase(Player* player)
    {
        return ::GetGuildPhase(player);
    }

    static bool HandleSpawnButlerCommand(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        Map* map = player->GetMap();

        if (!player->GetGuild() || (player->GetGuild()->GetLeaderGUID() != player->GetGUID()))
        {
            handler->SendSysMessage("You must be the Guild Master of a guild to use this command!");
            handler->SetSentErrorMessage(true);
            return false;
        }

        if (player->GetAreaId() != 876)
        {
            handler->SendSysMessage("You must be in your Guild House to use this command!");
            handler->SetSentErrorMessage(true);
            return false;
        }

        if (player->FindNearestCreature(95104, VISIBLE_RANGE, true))
        {
            handler->SendSysMessage("You already have the Guild House Butler!");
            handler->SetSentErrorMessage(true);
            return false;
        }

        float posX = 16229.422f;
        float posY = 16283.675f;
        float posZ = 13.175704f;
        float ori = 3.036652f;

        Creature* creature = new Creature();
        if (!creature->Create(map->GenerateLowGuid<HighGuid::Unit>(), map, GetGuildPhase(player), 95104, 0, posX, posY, posZ, ori))
        {
            handler->SendSysMessage("You already have the Guild House Butler!");
            handler->SetSentErrorMessage(true);
            delete creature;
            return false;
        }
        creature->SaveToDB(player->GetMapId(), (1 << player->GetMap()->GetSpawnMode()), GetGuildPhase(player));
        uint32 lowguid = creature->GetSpawnId();

        creature->CleanupsBeforeDelete();
        delete creature;
        creature = new Creature();
        if (!creature->LoadCreatureFromDB(lowguid, player->GetMap()))
        {
            handler->SendSysMessage("Something went wrong when adding the Butler.");
            handler->SetSentErrorMessage(true);
            delete creature;
            return false;
        }

        sObjectMgr->AddCreatureToGrid(lowguid, sObjectMgr->GetCreatureData(lowguid));
        return true;
    }

    static bool HandleGuildHouseTeleCommand(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();

        if (!player)
            return false;

        if (player->IsInCombat())
        {
            handler->SendSysMessage("You can't use this command while in combat!");
            handler->SetSentErrorMessage(true);
            return false;
        }

        GuildData* guildData = player->CustomData.GetDefault<GuildData>("phase");
        QueryResult result = CharacterDatabase.Query("SELECT `id`, `guild`, `phase`, `map`,`positionX`, `positionY`, `positionZ`, `orientation` FROM `dc_guild_house` WHERE `guild`={}", player->GetGuildId());

        if (!result)
        {
            handler->SendSysMessage("Your guild does not own a Guild House!");
            handler->SetSentErrorMessage(true);
            return false;
        }

        do
        {
            Field* fields = result->Fetch();
            guildData->phase = fields[2].Get<uint32>();
            uint32 map = fields[3].Get<uint32>();
            guildData->posX = fields[4].Get<float>();
            guildData->posY = fields[5].Get<float>();
            guildData->posZ = fields[6].Get<float>();
            guildData->ori = fields[7].Get<float>();

            player->TeleportTo(map, guildData->posX, guildData->posY, guildData->posZ, guildData->ori);

        } while (result->NextRow());

        return true;
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
    new GuildHouseCommand();
    new GuildHouseGlobal();
}
