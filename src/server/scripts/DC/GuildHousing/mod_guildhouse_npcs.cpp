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

class GuildHouseSeller : public CreatureScript
{

public:
    GuildHouseSeller() : CreatureScript("GuildHouseSeller") {}

    // Gossip actions
    static constexpr uint32 ACTION_TELEPORT = 1;
    static constexpr uint32 ACTION_BUY_MENU = 2;
    static constexpr uint32 ACTION_SELL_DELETE = 3;
    static constexpr uint32 ACTION_MOVE_MENU = 4;
    static constexpr uint32 ACTION_CLOSE = 5;
    static constexpr uint32 ACTION_RESET = 6;

    static constexpr uint32 ACTION_ADMIN_MENU = 50;
    static constexpr uint32 ACTION_ADMIN_BUY_MENU = 51;
    static constexpr uint32 ACTION_ADMIN_MOVE_MENU = 52;
    static constexpr uint32 ACTION_ADMIN_RESET = 53;
    static constexpr uint32 ACTION_ADMIN_DELETE = 54;
    static constexpr uint32 ACTION_BACK_MAIN = 55;

    // Location list action ranges
    static constexpr uint32 ACTION_BUY_LOCATION_BASE = 1000;   // 1000 + locationId
    static constexpr uint32 ACTION_MOVE_LOCATION_BASE = 2000;  // 2000 + locationId
    static constexpr uint32 ACTION_ADMIN_BUY_LOCATION_BASE = 10000;  // 10000 + locationId
    static constexpr uint32 ACTION_ADMIN_MOVE_LOCATION_BASE = 11000; // 11000 + locationId

    struct GuildHouseSellerAI : public ScriptedAI
    {
        GuildHouseSellerAI(Creature* creature) : ScriptedAI(creature) {}

        void UpdateAI(uint32 /*diff*/) override
        {
            me->SetFlag(UNIT_NPC_FLAGS, UNIT_NPC_FLAG_GOSSIP);
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
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
            AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Teleport to Guild House", GOSSIP_SENDER_MAIN, ACTION_TELEPORT);

            // Only show "Sell" option if they have a guild house & have permission to sell it
            Guild* guild = sGuildMgr->GetGuildById(player->GetGuildId());
            Guild::Member const* memberMe = guild->GetMember(player->GetGUID());
            if (memberMe->IsRankNotLower(sConfigMgr->GetOption<int32>("GuildHouseSellRank", 0)))
            {
                AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Move Guild House", GOSSIP_SENDER_MAIN, ACTION_MOVE_MENU);

                uint32 resetCost = sConfigMgr->GetOption<uint32>("GuildHouse.ResetCost", 0);
                std::string resetConfirm = "Are you sure you want to reset your Guild House spawns?";
                if (resetCost)
                    resetConfirm += " This will cost gold.";
                AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Reset Guild House", GOSSIP_SENDER_MAIN, ACTION_RESET, resetConfirm, resetCost, false);

                AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Sell Guild House", GOSSIP_SENDER_MAIN, ACTION_SELL_DELETE, "Are you sure you want to sell your Guild House?", 0, false);
            }
        }
        else
        {
            // Only leader of the guild can buy guild house & only if they don't already have a guild house
            if (player->GetGuild()->GetLeaderGUID() == player->GetGUID())
            {
                AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Buy Guild House!", GOSSIP_SENDER_MAIN, ACTION_BUY_MENU);
            }
        }

        if (player->IsGameMaster())
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "GM/Admin Menu (free)", GOSSIP_SENDER_MAIN, ACTION_ADMIN_MENU);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool CanManageGuildHouse(Player* player) const
    {
        if (!player || !player->GetGuild())
            return false;

        Guild* guild = sGuildMgr->GetGuildById(player->GetGuildId());
        if (!guild)
            return false;

        Guild::Member const* memberMe = guild->GetMember(player->GetGUID());
        if (!memberMe)
            return false;

        return memberMe->IsRankNotLower(sConfigMgr->GetOption<int32>("GuildHouseSellRank", 0));
    }

    void ShowAdminMenu(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);

        QueryResult has_gh = CharacterDatabase.Query(
            "SELECT `id` FROM `dc_guild_house` WHERE `guild` = {}",
            player->GetGuildId());

        if (has_gh)
        {
            AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Teleport to Guild House", GOSSIP_SENDER_MAIN, ACTION_TELEPORT);
            AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Move Guild House (free)", GOSSIP_SENDER_MAIN, ACTION_ADMIN_MOVE_MENU);
            AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Reset Guild House (free)", GOSSIP_SENDER_MAIN, ACTION_ADMIN_RESET, "Reset all guild house spawns for this guild?", 0, false);
            AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Delete Guild House (free)", GOSSIP_SENDER_MAIN, ACTION_ADMIN_DELETE, "Delete the guild house for this guild?", 0, false);
        }
        else
        {
            AddGossipItemFor(player, GOSSIP_ICON_TABARD, "Buy Guild House (free)", GOSSIP_SENDER_MAIN, ACTION_ADMIN_BUY_MENU);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back", GOSSIP_SENDER_MAIN, ACTION_BACK_MAIN);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    bool CleanupGuildHouseSpawns(uint32 guildPhase)
    {
        QueryResult CreatureResult;
        QueryResult GameobjResult;
        Map* map = sMapMgr->FindMap(1, 0);
        if (!map)
            return false;

        GameobjResult = WorldDatabase.Query("SELECT `guid` FROM `gameobject` WHERE `map` = 1 AND `phaseMask` = '{}'", guildPhase);
        CreatureResult = WorldDatabase.Query("SELECT `guid` FROM `creature` WHERE `map` = 1 AND `phaseMask` = '{}'", guildPhase);

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
                    }
                }
            } while (GameobjResult->NextRow());
        }

        return true;
    }

    bool ResetGuildHouse(Player* player, bool free)
    {
        if (!player || !player->GetGuild())
            return false;

        if (!free && !CanManageGuildHouse(player))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You are not authorized to manage your Guild House.");
            return false;
        }

        QueryResult has_gh = CharacterDatabase.Query(
            "SELECT `id` FROM `dc_guild_house` WHERE `guild` = {}",
            player->GetGuildId());

        if (!has_gh)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Your guild does not own a Guild House!");
            return false;
        }

        uint32 resetCost = sConfigMgr->GetOption<uint32>("GuildHouse.ResetCost", 0);
        if (!free && resetCost)
        {
            if (player->GetMoney() < resetCost)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You do not have enough money to reset your Guild House.");
                return false;
            }
            player->ModifyMoney(-static_cast<int64>(resetCost));
        }

        uint32 guildPhase = GetGuildPhase(player);
        CleanupGuildHouseSpawns(guildPhase);
        SpawnTeleporterNPC(player);
        SpawnButlerNPC(player);
        ChatHandler(player->GetSession()).PSendSysMessage("Guild House has been reset.");
        return true;
    }

    bool MoveGuildHouse(Player* player, uint32 locationId, bool free)
    {
        if (!player || !player->GetGuild())
            return false;

        if (!free && !CanManageGuildHouse(player))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You are not authorized to manage your Guild House.");
            return false;
        }

        QueryResult has_gh = CharacterDatabase.Query(
            "SELECT `id` FROM `dc_guild_house` WHERE `guild` = {}",
            player->GetGuildId());

        if (!has_gh)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Your guild does not own a Guild House!");
            return false;
        }

        QueryResult locationResult = WorldDatabase.Query(
            "SELECT `map`, `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_locations` WHERE `id` = {}",
            locationId);

        if (!locationResult)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Error finding Guild House location.");
            return false;
        }

        uint32 moveCost = sConfigMgr->GetOption<uint32>("GuildHouse.MoveCost", 0);
        if (!free && moveCost)
        {
            if (player->GetMoney() < moveCost)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You do not have enough money to move your Guild House.");
                return false;
            }
            player->ModifyMoney(-static_cast<int64>(moveCost));
        }

        Field* fields = locationResult->Fetch();
        uint32 map = fields[0].Get<uint32>();
        float posX = fields[1].Get<float>();
        float posY = fields[2].Get<float>();
        float posZ = fields[3].Get<float>();
        float ori = fields[4].Get<float>();

        CharacterDatabase.Query(
            "UPDATE `dc_guild_house` SET `map` = {}, `positionX` = {}, `positionY` = {}, `positionZ` = {}, `orientation` = {} WHERE `guild` = {}",
            map, posX, posY, posZ, ori, player->GetGuildId());

        // Treat move like a reset as well (clean and respawn core NPCs)
        uint32 guildPhase = GetGuildPhase(player);
        CleanupGuildHouseSpawns(guildPhase);
        SpawnTeleporterNPC(player);
        SpawnButlerNPC(player);

        ChatHandler(player->GetSession()).PSendSysMessage("Guild House has been moved.");
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (!player)
            return false;

        // Buy (player) location selection
        if (action >= ACTION_BUY_LOCATION_BASE && action < ACTION_MOVE_LOCATION_BASE)
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

            uint32 locationId = action - ACTION_BUY_LOCATION_BASE;
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

        // Move (player) location selection
        if (action >= ACTION_MOVE_LOCATION_BASE && action < 3000)
        {
            uint32 locationId = action - ACTION_MOVE_LOCATION_BASE;
            MoveGuildHouse(player, locationId, false);
            CloseGossipMenuFor(player);
            return true;
        }

        // Buy (admin free) location selection
        if (action >= ACTION_ADMIN_BUY_LOCATION_BASE && action < ACTION_ADMIN_MOVE_LOCATION_BASE)
        {
            uint32 locationId = action - ACTION_ADMIN_BUY_LOCATION_BASE;

            // Admin buy: reuse the existing purchase logic, but without charging.
            if (!player->GetGuild())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You are not a member of a guild.");
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

            QueryResult locationResult = WorldDatabase.Query(
                "SELECT `map`, `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_locations` WHERE `id` = {}",
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

            CharacterDatabase.Query(
                "INSERT INTO `dc_guild_house` (guild, phase, map, positionX, positionY, positionZ, orientation) "
                "VALUES ({}, {}, {}, {}, {}, {}, {})",
                player->GetGuildId(), GetGuildPhase(player), map, posX, posY, posZ, ori);

            SpawnTeleporterNPC(player);
            SpawnButlerNPC(player);

            ChatHandler(player->GetSession()).PSendSysMessage("GM: Guild House purchased for free.");
            CloseGossipMenuFor(player);
            return true;
        }

        // Move (admin free) location selection
        if (action >= ACTION_ADMIN_MOVE_LOCATION_BASE && action < 12000)
        {
            uint32 locationId = action - ACTION_ADMIN_MOVE_LOCATION_BASE;
            MoveGuildHouse(player, locationId, true);
            CloseGossipMenuFor(player);
            return true;
        }

        switch (action)
        {
            case ACTION_TELEPORT: // teleport to guild house
                TeleportGuildHouse(player->GetGuild(), player, creature);
                break;
            case ACTION_BUY_MENU: // buy guild house
                BuyGuildHouse(player->GetGuild(), player, creature);
                break;
            case ACTION_MOVE_MENU:
                {
                    ClearGossipMenuFor(player);
                    QueryResult locations = WorldDatabase.Query("SELECT `id`, `name`, `cost`, `comment` FROM `dc_guild_house_locations`");
                    if (!locations)
                    {
                        ChatHandler(player->GetSession()).PSendSysMessage("No Guild House locations are currently available.");
                        CloseGossipMenuFor(player);
                        return false;
                    }

                    uint32 moveCost = sConfigMgr->GetOption<uint32>("GuildHouse.MoveCost", 0);
                    do
                    {
                        Field* fields = locations->Fetch();
                        uint32 id = fields[0].Get<uint32>();
                        std::string name = fields[1].Get<std::string>();
                        std::string comment = fields[3].Get<std::string>();

                        std::string text = name + " - " + comment;
                        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, text, GOSSIP_SENDER_MAIN, ACTION_MOVE_LOCATION_BASE + id,
                                         "Are you sure you want to move your Guild House to " + name + "?", moveCost, false);
                    } while (locations->NextRow());

                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back", GOSSIP_SENDER_MAIN, ACTION_BACK_MAIN);
                    SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
                }
                break;
            case ACTION_RESET:
                ResetGuildHouse(player, false);
                CloseGossipMenuFor(player);
                break;
            case ACTION_SELL_DELETE: // delete/sell guild house
            {
                if (!CanManageGuildHouse(player))
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("You are not authorized to manage your Guild House.");
                    CloseGossipMenuFor(player);
                    return false;
                }

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
            case ACTION_ADMIN_MENU:
                if (!player->IsGameMaster())
                {
                    CloseGossipMenuFor(player);
                    return false;
                }
                ShowAdminMenu(player, creature);
                break;
            case ACTION_ADMIN_BUY_MENU:
                if (!player->IsGameMaster())
                {
                    CloseGossipMenuFor(player);
                    return false;
                }
                // Show location list with admin-buy action ids
                {
                    ClearGossipMenuFor(player);
                    QueryResult locations = WorldDatabase.Query("SELECT `id`, `name`, `comment` FROM `dc_guild_house_locations`");
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
                        std::string comment = fields[2].Get<std::string>();
                        std::string text = name + " - " + comment;
                        AddGossipItemFor(player, GOSSIP_ICON_TABARD, text, GOSSIP_SENDER_MAIN, ACTION_ADMIN_BUY_LOCATION_BASE + id,
                                         "GM: Buy guild house for free at " + name + "?", 0, false);
                    } while (locations->NextRow());

                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back", GOSSIP_SENDER_MAIN, ACTION_ADMIN_MENU);
                    SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
                }
                break;
            case ACTION_ADMIN_MOVE_MENU:
                if (!player->IsGameMaster())
                {
                    CloseGossipMenuFor(player);
                    return false;
                }
                // Show location list with admin-move action ids
                {
                    ClearGossipMenuFor(player);
                    QueryResult locations = WorldDatabase.Query("SELECT `id`, `name`, `comment` FROM `dc_guild_house_locations`");
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
                        std::string comment = fields[2].Get<std::string>();
                        std::string text = name + " - " + comment;
                        AddGossipItemFor(player, GOSSIP_ICON_TABARD, text, GOSSIP_SENDER_MAIN, ACTION_ADMIN_MOVE_LOCATION_BASE + id,
                                         "GM: Move guild house for free to " + name + "?", 0, false);
                    } while (locations->NextRow());

                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<< Back", GOSSIP_SENDER_MAIN, ACTION_ADMIN_MENU);
                    SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
                }
                break;
            case ACTION_ADMIN_RESET:
                if (!player->IsGameMaster())
                {
                    CloseGossipMenuFor(player);
                    return false;
                }
                ResetGuildHouse(player, true);
                ShowAdminMenu(player, creature);
                break;
            case ACTION_ADMIN_DELETE:
                if (!player->IsGameMaster())
                {
                    CloseGossipMenuFor(player);
                    return false;
                }
                if (RemoveGuildHouse(player))
                    ChatHandler(player->GetSession()).PSendSysMessage("GM: Guild House deleted.");
                else
                    ChatHandler(player->GetSession()).PSendSysMessage("GM: Failed to delete Guild House.");
                ShowAdminMenu(player, creature);
                break;
            case ACTION_BACK_MAIN:
                OnGossipHello(player, creature);
                break;
            case ACTION_CLOSE: // close
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
        Map* map = sMapMgr->FindMap(1, 0);
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
        uint32 entry = 95104;
        float posX = 16202.185547f;
        float posY = 16255.916992f;
        float posZ = 21.160221f;
        float ori = 6.195375f;

        Map* map = sMapMgr->FindMap(1, 0);
        Creature* creature = new Creature();

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

void AddGuildHouseNpcScripts()
{
    new GuildHouseSeller();
}
