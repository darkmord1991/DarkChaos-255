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

class GuildHouseSeller : public CreatureScript
{

public:
    GuildHouseSeller() : CreatureScript("GuildHouseSeller") {}

    struct GuildHouseSellerAI : public ScriptedAI
    {
        GuildHouseSellerAI(Creature* creature) : ScriptedAI(creature) {}

        void UpdateAI(uint32 /*diff*/) override
        {
            me->SetFlag(UNIT_NPC_FLAGS, UNIT_NPC_FLAG_GOSSIP);
        }
    };

    CreatureAI * GetAI(Creature* creature) const override
    {
        return new GuildHouseSellerAI(creature);
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player->GetGuild())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You are not a member of a guild.");
            CloseGossipMenuFor(player);
            return false;
        }

        QueryResult has_gh = CharacterDatabase.Query("SELECT id, `guild` FROM `dc_guild_house` WHERE guild = {}", player->GetGuildId());

        // Only show Teleport option if guild owns a guild house
        if (has_gh)
        {
            AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Teleport to Guild House", GOSSIP_SENDER_MAIN, 1);

            // Only show "Sell" option if they have a guild house & have permission to sell it
            Guild* guild = sGuildMgr->GetGuildById(player->GetGuildId());
            Guild::Member const* memberMe = guild->GetMember(player->GetGUID());
            if (memberMe->IsRankNotLower(sConfigMgr->GetOption<int32>("GuildHouseSellRank", 0)))
            {
                AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Sell Guild House!", GOSSIP_SENDER_MAIN, 3, "Are you sure you want to sell your Guild House?", 0, false);
            }
        }
        else
        {
            // Only leader of the guild can buy guild house & only if they don't already have a guild house
            if (player->GetGuild()->GetLeaderGUID() == player->GetGUID())
            {
                AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Buy Guild House!", GOSSIP_SENDER_MAIN, 2);
            }
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, 5);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (!player)
            return false;

        // Location purchase actions are offset by 1000
        if (action >= 1000)
        {
            if (!player->GetGuild())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You are not a member of a guild.");
                CloseGossipMenuFor(player);
                return false;
            }

            // Only the guild master should be able to buy a house (also enforced in OnGossipHello)
            if (player->GetGuild()->GetLeaderGUID() != player->GetGUID())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("Only the Guild Master can purchase a Guild House.");
                CloseGossipMenuFor(player);
                return false;
            }

            QueryResult alreadyHas = CharacterDatabase.Query(
                "SELECT `id` FROM `dc_guild_house` WHERE `guild` = {}",
                player->GetGuildId());

            if (alreadyHas)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("Your guild already has a Guild House.");
                CloseGossipMenuFor(player);
                return false;
            }

            uint32 locationId = action - 1000;
            QueryResult locationResult = WorldDatabase.Query(
                "SELECT `map`, `posX`, `posY`, `posZ`, `orientation`, `cost` FROM `dc_guild_house_locations` WHERE `id` = {}",
                locationId);

            if (!locationResult)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("Error finding Guild House location.");
                CloseGossipMenuFor(player);
                return false;
            }

            Field* fields = locationResult->Fetch();
            uint32 map = fields[0].Get<uint32>();
            float posX = fields[1].Get<float>();
            float posY = fields[2].Get<float>();
            float posZ = fields[3].Get<float>();
            float ori = fields[4].Get<float>();
            uint32 cost = fields[5].Get<uint32>();

            if (player->GetMoney() < cost)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You do not have enough money to purchase this Guild House.");
                CloseGossipMenuFor(player);
                return false;
            }

            CharacterDatabase.Query(
                "INSERT INTO `dc_guild_house` (guild, phase, map, positionX, positionY, positionZ, orientation) "
                "VALUES ({}, {}, {}, {}, {}, {}, {})",
                player->GetGuildId(), GetGuildPhase(player), map, posX, posY, posZ, ori);

            player->ModifyMoney(-static_cast<int64>(cost));

            ChatHandler(player->GetSession()).PSendSysMessage("You have successfully purchased a Guild House");
            player->GetGuild()->BroadcastToGuild(player->GetSession(), false, "We now have a Guild House!", LANG_UNIVERSAL);
            player->GetGuild()->BroadcastToGuild(player->GetSession(), false, "In chat, type `.guildhouse teleport` or `.gh tele` to meet me there!", LANG_UNIVERSAL);
            LOG_INFO("modules", "GUILDHOUSE: GuildId: '{}' has purchased a guildhouse at location ID {}", player->GetGuildId(), locationId);

            // Spawn the portal and the guild house butler automatically as part of purchase.
            SpawnTeleporterNPC(player);
            SpawnButlerNPC(player);

            CloseGossipMenuFor(player);
            return true;
        }

        switch (action)
        {
            case 1: // teleport to guild house
                TeleportGuildHouse(player->GetGuild(), player, creature);
                break;
            case 2: // buy guild house
                BuyGuildHouse(player->GetGuild(), player, creature);
                break;
            case 3: // sell back guild house
            {
                QueryResult has_gh = CharacterDatabase.Query(
                    "SELECT `id` FROM `dc_guild_house` WHERE `guild` = {}",
                    player->GetGuildId());

                if (!has_gh)
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("Your guild does not own a Guild House!");
                    CloseGossipMenuFor(player);
                    return false;
                }

                if (RemoveGuildHouse(player))
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("You have successfully sold your Guild House.");
                    player->GetGuild()->BroadcastToGuild(player->GetSession(), false, "We just sold our Guild House.", LANG_UNIVERSAL);
                    player->ModifyMoney(+(sConfigMgr->GetOption<int32>("CostGuildHouse", 10000000) / 2));
                    LOG_INFO("modules", "GUILDHOUSE: Successfully returned money and sold Guild House");
                }
                else
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("There was an error selling your Guild House.");
                }

                CloseGossipMenuFor(player);
                break;
            }
            case 5: // close
                CloseGossipMenuFor(player);
                break;
            default:
                OnGossipHello(player, creature);
                break;
        }

        return true;
    }

    uint32 GetGuildPhase(Player* player)
    {
        return ::GetGuildPhase(player);
    }

    bool RemoveGuildHouse(Player* player)
    {

        uint32 guildPhase = GetGuildPhase(player);
        QueryResult CreatureResult;
        QueryResult GameobjResult;
        Map *map = sMapMgr->FindMap(1, 0);
        // Lets find all of the gameobjects to be removed
        GameobjResult = WorldDatabase.Query("SELECT `guid` FROM `gameobject` WHERE `map` = 1 AND `phaseMask` = '{}'", guildPhase);
        // Lets find all of the creatures to be removed
        CreatureResult = WorldDatabase.Query("SELECT `guid` FROM `creature` WHERE `map` = 1 AND `phaseMask` = '{}'", guildPhase);

        // Remove creatures from the deleted guild house map
        if (CreatureResult)
        {
            do
            {
                Field* fields = CreatureResult->Fetch();
                uint32 lowguid = fields[0].Get<uint32>();
                if (CreatureData const* cr_data = sObjectMgr->GetCreatureData(lowguid))
                {
                    if (Creature* creature = map->GetCreature(ObjectGuid::Create<HighGuid::Unit>(cr_data->id1, lowguid)))
                    {
                        creature->CombatStop();
                        creature->DeleteFromDB();
                        creature->AddObjectToRemoveList();
                    }
                }
            } while (CreatureResult->NextRow());
        }

        // Remove gameobjects from the deleted guild house map
        if (GameobjResult)
        {
            do
            {
                Field* fields = GameobjResult->Fetch();
                uint32 lowguid = fields[0].Get<uint32>();
                if (GameObjectData const* go_data = sObjectMgr->GetGameObjectData(lowguid))
                {
                    if (GameObject* gobject = map->GetGameObject(ObjectGuid::Create<HighGuid::GameObject>(go_data->id, lowguid)))
                    {
                        gobject->SetRespawnTime(0);
                        gobject->Delete();
                        gobject->DeleteFromDB();
                        gobject->CleanupsBeforeDelete();
                        // delete gobject;
                    }
                }

            } while (GameobjResult->NextRow());
        }

        // Delete actual guild_house data from characters database
        CharacterDatabase.Query("DELETE FROM `dc_guild_house` WHERE `guild`={}", player->GetGuildId());

        return true;
    }

    void SpawnTeleporterNPC(Player* player)
    {
        uint32 entry = 800002; // Teleporter NPC
        float posX = 16226.5f; // Default near center of GM island area
        float posY = 16258.8f;
        float posZ = 13.2f;
        float ori = 1.6f;

        // Try to verify coordinates from DB if possible, but fallback to defaults or use player position offset
        // For now, using hardcoded defaults similar to existing logic or relative to player
        
        // Actually, let's use the player's position + offset to be safe, OR valid GM island coords
        // The original logic checked `dc_guild_house_spawns` for portals. 
        // We can just spawn it near the Butler or player.
        
        // Let's spawn it at a fixed location on GM Island for consistency if map is 1
        // Original GM Island coords: 16222.972, 16267.802, 13.136777
        
        posX = 16222.0f; 
        posY = 16270.0f; 
        posZ = 13.1f; 
        ori = 4.7f;

        Map* map = sMapMgr->FindMap(1, 0); // GM Island Map
        Creature* creature = new Creature();

        if (!creature->Create(map->GenerateLowGuid<HighGuid::Unit>(), map, GetGuildPhase(player), entry, 0, posX, posY, posZ, ori))
        {
            delete creature;
            LOG_INFO("modules", "GUILDHOUSE: Unable to create Teleporter NPC!");
            return;
        }

        creature->SaveToDB(map->GetId(), (1 << map->GetSpawnMode()), GetGuildPhase(player));
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
        CloseGossipMenuFor(player);
    }

    void SpawnButlerNPC(Player* player)
    {
        uint32 entry = GetCreatureEntry(1);
        float posX = 16202.185547f;
        float posY = 16255.916992f;
        float posZ = 21.160221f;
        float ori = 6.195375f;

        Map* map = sMapMgr->FindMap(1, 0);
        Creature *creature = new Creature();

        if (!creature->Create(map->GenerateLowGuid<HighGuid::Unit>(), map, player->GetPhaseMaskForSpawn(), entry, 0, posX, posY, posZ, ori))
        {
            delete creature;
            return;
        }
        creature->SaveToDB(map->GetId(), (1 << map->GetSpawnMode()), GetGuildPhase(player));
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
        return;
    }

    bool BuyGuildHouse(Guild* guild, Player* player, Creature* creature)
    {
        QueryResult result = CharacterDatabase.Query("SELECT `id`, `guild` FROM `dc_guild_house` WHERE `guild`={}", guild->GetId());

        if (result)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Your guild already has a Guild House.");
            CloseGossipMenuFor(player);
            return false;
        }

        ClearGossipMenuFor(player);

        QueryResult locations = WorldDatabase.Query("SELECT `id`, `name`, `cost`, `comment` FROM `dc_guild_house_locations`");
        
        if (!locations)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("No Guild House locations are currently available.");
            CloseGossipMenuFor(player);
            return false;
        }

        do
        {
            Field* fields = locations->Fetch();
            uint32 id = fields[0].Get<uint32>();
            std::string name = fields[1].Get<std::string>();
            uint32 cost = fields[2].Get<uint32>();
            std::string comment = fields[3].Get<std::string>();

            std::string text = name + " (" + std::to_string(cost / 10000) + "g) - " + comment;
            
            // Action ID = 1000 + Location ID to allow adequate room for other menu options
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, text, GOSSIP_SENDER_MAIN, 1000 + id, "Are you sure you want to buy " + name + "?", cost, false);

        } while (locations->NextRow());

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    void TeleportGuildHouse(Guild* guild, Player* player, Creature* creature)
    {
        if (GuildHouseManager::TeleportToGuildHouse(player, guild->GetId()))
        {
            // Success
        }
        else
        {
            ClearGossipMenuFor(player);
            if (player->GetGuild()->GetLeaderGUID() == player->GetGUID())
            {
                AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Buy Guild House!", GOSSIP_SENDER_MAIN, 2);
            }
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, 5);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            ChatHandler(player->GetSession()).PSendSysMessage("Your Guild does not own a Guild House");
        }
    }
};

class GuildHousePlayerScript : public PlayerScript
{
public:
    GuildHousePlayerScript() : PlayerScript("GuildHousePlayerScript") {}

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

    static ChatCommandTable GetAdminCommands()
    {
        static ChatCommandTable AdminCommandTable =
        {
            {"teleport", HandleAdminTeleportCommand, SEC_GAMEMASTER, Console::Yes},
            {"delete", HandleAdminDeleteCommand, SEC_GAMEMASTER, Console::Yes}
        };

        return AdminCommandTable;
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

        if (player->FindNearestCreature(GetCreatureEntry(1), VISIBLE_RANGE, true))
        {
            handler->SendSysMessage("You already have the Guild House Butler!");
            handler->SetSentErrorMessage(true);
            return false;
        }

        float posX = 16202.185547f;
        float posY = 16255.916992f;
        float posZ = 21.160221f;
        float ori = 6.195375f;

        Creature* creature = new Creature();
        if (!creature->Create(map->GenerateLowGuid<HighGuid::Unit>(), map, GetGuildPhase(player), GetCreatureEntry(1), 0, posX, posY, posZ, ori))
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
    new GuildHouseSeller();
    new GuildHousePlayerScript();
    new GuildHouseCommand();
    new GuildHouseGlobal();
}
