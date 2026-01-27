#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include "Guild.h"
#include "GuildMgr.h"
#include "../GuildHousing/dc_guildhouse.h"
#include "Maps/MapMgr.h"
#include "Map.h"
#include "Tokenize.h"

using namespace Acore::ChatCommands;

class GuildHouseCommandScript : public CommandScript
{
public:
    GuildHouseCommandScript() : CommandScript("GuildHouseCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable GuildHouseCommandTable =
        {
            { "teleport", HandleGuildHouseTeleCommand, SEC_PLAYER, Console::Yes },
            { "butler",   HandleSpawnButlerCommand,    SEC_PLAYER, Console::Yes },
            { "info",     HandleGuildHouseInfoCommand, SEC_PLAYER, Console::Yes },
            { "members",  HandleGuildHouseMembersCommand, SEC_PLAYER, Console::Yes },
            { "rank",     HandleRankCommand,            SEC_PLAYER, Console::Yes },
            { "undo",     HandleUndoCommand,            SEC_PLAYER, Console::Yes },
            { "move",     HandleMoveCommand,            SEC_PLAYER, Console::Yes },
            { "admin",    GetAdminCommands() },
        };

        static ChatCommandTable commandTable =
        {
            { "guildhouse", GuildHouseCommandTable },
            { "gh",         GuildHouseCommandTable }
        };

        return commandTable;
    }

    static ChatCommandTable const& GetAdminCommands()
    {
        static ChatCommandTable AdminCommandTable =
        {
            { "teleport", HandleAdminTeleportCommand, SEC_GAMEMASTER, Console::Yes },
            { "delete",   HandleAdminDeleteCommand,   SEC_GAMEMASTER, Console::Yes },
            { "buy",      HandleAdminBuyCommand,      SEC_GAMEMASTER, Console::Yes },
            { "reset",    HandleAdminResetCommand,    SEC_GAMEMASTER, Console::Yes },
            { "level",    HandleAdminLevelCommand,    SEC_GAMEMASTER, Console::Yes }
        };

        return AdminCommandTable;
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

        if (!player->GetGuildId())
        {
            handler->SendSysMessage("You are not in a guild!");
            handler->SetSentErrorMessage(true);
            return false;
        }

        if (!GuildHouseManager::TeleportToGuildHouse(player, player->GetGuildId()))
        {
            handler->SendSysMessage("Your guild does not own a Guild House!");
            handler->SetSentErrorMessage(true);
            return false;
        }

        return true;
    }

    static bool HandleSpawnButlerCommand(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!player->GetGuild() || (player->GetGuild()->GetLeaderGUID() != player->GetGUID()))
        {
            handler->SendSysMessage("You must be the Guild Master of a guild to use this command!");
            handler->SetSentErrorMessage(true);
            return false;
        }

        // Check if player is near the guild house arrival point or in correct zone
        // For multi-map, we check if they are in the guild house map/phase
        GuildHouseData* data = GuildHouseManager::GetGuildHouseData(player->GetGuildId());
        if (!data)
        {
            handler->SendSysMessage("Your guild does not own a Guild House!");
            handler->SetSentErrorMessage(true);
            return false;
        }

        if (player->GetMapId() != data->map || player->GetPhaseByAuras() != data->phase)
        {
             // If not in the correct phase/map, maybe they should teleport first?
             // Or at least be at GM Island if that's the default zone
             if (player->GetZoneId() != 876)
             {
                handler->SendSysMessage("You must be in your Guild House to use this command!");
                handler->SetSentErrorMessage(true);
                return false;
             }
        }

        if (player->FindNearestCreature(95104, VISIBLE_RANGE, true))
        {
            handler->SendSysMessage("You already have the Guild House Butler!");
            handler->SetSentErrorMessage(true);
            return false;
        }

        GuildHouseManager::SpawnButlerNPC(player);
        handler->SendSysMessage("Guild House Butler spawned.");
        return true;
    }

    static bool HandleGuildHouseInfoCommand(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!player->GetGuildId())
        {
            handler->SendSysMessage("You are not in a guild!");
            return true;
        }

        GuildHouseData* data = GuildHouseManager::GetGuildHouseData(player->GetGuildId());
        if (!data)
        {
            handler->SendSysMessage("Your guild does not own a Guild House.");
            return true;
        }

        handler->PSendSysMessage("Guild House Information:");
        handler->PSendSysMessage("- Phase: {}", data->phase);
        handler->PSendSysMessage("- Map ID: {}", data->map);
        handler->PSendSysMessage("- Arrival Position: X:{:.3f} Y:{:.3f} Z:{:.3f}", data->posX, data->posY, data->posZ);
        handler->PSendSysMessage("- Level: {}", data->level);

        return true;
    }

    static bool HandleGuildHouseMembersCommand(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        if (!player->GetGuildId())
        {
            handler->SendSysMessage("You are not in a guild!");
            return true;
        }

        GuildHouseData* data = GuildHouseManager::GetGuildHouseData(player->GetGuildId());
        if (!data)
        {
            handler->SendSysMessage("Your guild does not own a Guild House.");
            return true;
        }

        handler->PSendSysMessage("Members currently in the Guild House:");
        uint32 count = 0;

        Map* map = sMapMgr->FindMap(data->map, 0);
        if (map)
        {
             Map::PlayerList const& players = map->GetPlayers();
             for (Map::PlayerList::const_iterator itr = players.begin(); itr != players.end(); ++itr)
             {
                 Player* p = itr->GetSource();
                 if (p && p->GetPhaseByAuras() == data->phase)
                 {
                     handler->PSendSysMessage("- {}", p->GetName());
                     count++;
                 }
             }
        }

        if (count == 0)
            handler->SendSysMessage("No members found.");
        else
            handler->PSendSysMessage("Total: {} members", count);

        return true;
    }

    static bool HandleAdminResetCommand(ChatHandler* handler, const char* args)
    {
        if (!*args)
            return false;

        std::string guildName = args;
        Guild* guild = sGuildMgr->GetGuildByName(guildName);

        if (!guild)
        {
             handler->SendSysMessage("Guild not found.");
             return false;
        }

        GuildHouseData* data = GuildHouseManager::GetGuildHouseData(guild->GetId());
        if (!data)
        {
            handler->SendSysMessage("That guild does not own a Guild House.");
            return true;
        }

        GuildHouseManager::CleanupGuildHouseSpawns(data->map, data->phase);
        GuildHouseManager::SpawnTeleporterNPC(guild->GetId(), data->map, data->phase, data->posX, data->posY, data->posZ, data->ori);
        GuildHouseManager::SpawnButlerNPC(guild->GetId(), data->map, data->phase, data->posX + 2.0f, data->posY, data->posZ, data->ori);

        handler->PSendSysMessage("Reset spawns for guild '{}'.", guild->GetName());
        return true;
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

    static bool HandleAdminLevelCommand(ChatHandler* handler, const char* args)
    {
        if (!handler || !handler->GetSession() || !handler->GetSession()->GetPlayer())
            return false;

        if (!args || !*args)
        {
            handler->SendSysMessage("Usage: .gh admin level <guildName|guildId> [level 0-4]");
            return false;
        }

        std::string input = args;
        TrimString(input);
        if (input.empty())
            return false;

        uint32 guildId = 0;
        Guild* guild = nullptr;
        bool hasLevel = false;
        uint8 level = 1;

        std::string firstToken;
        std::string remainder;
        size_t spacePos = input.find_first_of(" \t");
        if (spacePos == std::string::npos)
        {
            firstToken = input;
        }
        else
        {
            firstToken = input.substr(0, spacePos);
            remainder = input.substr(spacePos + 1);
            TrimString(remainder);
        }

        if (IsAllDigits(firstToken))
        {
            guildId = static_cast<uint32>(std::stoul(firstToken));
            guild = sGuildMgr->GetGuildById(guildId);
            if (!remainder.empty() && IsAllDigits(remainder))
            {
                level = static_cast<uint8>(std::stoul(remainder));
                hasLevel = true;
            }
        }
        else
        {
            std::string guildName = input;
            size_t lastSpace = guildName.find_last_of(" \t");
            if (lastSpace != std::string::npos)
            {
                std::string maybeLevel = guildName.substr(lastSpace + 1);
                if (IsAllDigits(maybeLevel))
                {
                    level = static_cast<uint8>(std::stoul(maybeLevel));
                    hasLevel = true;
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

        GuildHouseData* data = GuildHouseManager::GetGuildHouseData(guildId);
        if (!data)
        {
            handler->SendSysMessage("That guild does not own a Guild House.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        if (!hasLevel)
        {
            handler->PSendSysMessage("Guild House level for '{}' is {}.", guild->GetName(), data->level);
            return true;
        }

        if (level > 4)
        {
            handler->SendSysMessage("Level must be between 0 and 4.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        if (!GuildHouseManager::SetGuildHouseLevel(guildId, level))
        {
            handler->SendSysMessage("Failed to update guild house level.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        handler->PSendSysMessage("Guild House level for '{}' set to {}.", guild->GetName(), level);
        return true;
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

        uint32 guildId = 0;
        uint32 locationId = 0;
        Guild* guild = nullptr;

        std::string firstToken;
        std::string remainder;
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

        if (IsAllDigits(firstToken))
        {
            guildId = static_cast<uint32>(std::stoul(firstToken));
            guild = sGuildMgr->GetGuildById(guildId);
            if (!remainder.empty() && IsAllDigits(remainder))
                locationId = static_cast<uint32>(std::stoul(remainder));
        }
        else
        {
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

        // Logic to buy it for them (admin command)
        // Check if already has
        QueryResult alreadyHas = CharacterDatabase.Query("SELECT `id` FROM `dc_guild_house` WHERE `guild` = {}", guildId);
        if (alreadyHas)
        {
            handler->SendSysMessage("That guild already owns a Guild House.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        // Load location
        QueryResult locationResult;
        if (locationId)
            locationResult = WorldDatabase.Query("SELECT `id`, `map`, `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_locations` WHERE `id` = {}", locationId);
        else
            locationResult = WorldDatabase.Query("SELECT `id`, `map`, `posX`, `posY`, `posZ`, `orientation` FROM `dc_guild_house_locations` ORDER BY `id` ASC LIMIT 1");

        if (!locationResult)
        {
            handler->SendSysMessage("Guild House location not found.");
            handler->SetSentErrorMessage(true);
            return false;
        }

        Field* fields = locationResult->Fetch();
        locationId = fields[0].Get<uint32>();
        uint32 map = fields[1].Get<uint32>();
        float posX = fields[2].Get<float>();
        float posY = fields[3].Get<float>();
        float posZ = fields[4].Get<float>();
        float ori = fields[5].Get<float>();

        uint32 guildPhase = ::GetGuildPhase(guildId);
        CharacterDatabase.Query("INSERT INTO `dc_guild_house` (guild, phase, map, positionX, positionY, positionZ, orientation, guildhouse_level) VALUES ({}, {}, {}, {}, {}, {}, {}, 0)",
            guildId, guildPhase, map, posX, posY, posZ, ori);

        // Update Cache
        GuildHouseManager::UpdateGuildHouseData(guildId, GuildHouseData(guildPhase, map, posX, posY, posZ, ori, 0));

        handler->PSendSysMessage("Purchased Guild House for guild '{}' at location {} (no cost).", guild->GetName(), locationId);
        return true;
    }

    static bool HandleRankCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player || !player->GetGuildId()) return false;

        if (!*args)
        {
            handler->SendSysMessage("Usage: .gh rank <rankId> <add/remove> <spawn/delete/move/admin>");
            return false;
        }

        // Only Guild Master or Admin can change permissions
        // Note: We check if they have ADMIN permission bit or are rank 0
        if (player->GetRank() != 0 && !GuildHouseManager::HasPermission(player, GH_PERM_ADMIN))
        {
             handler->SendSysMessage("You do not have permission to manage ranks.");
             return false;
        }

        // Parse args: rankId (0-9), action (add/remove), flagging
        std::vector<std::string_view> tokens = Acore::Tokenize(args, ' ', false);
        if (tokens.size() < 3)
        {
             handler->SendSysMessage("Usage: .gh rank <rankId> <add/remove> <spawn/delete/move/admin>");
             return false;
        }

        uint8 rankId = (uint8)atoi(std::string(tokens[0]).c_str());
        std::string_view action = tokens[1];
        std::string_view flagName = tokens[2];

        uint32 flag = 0;
        if (flagName == "spawn") flag = GH_PERM_SPAWN;
        else if (flagName == "delete") flag = GH_PERM_DELETE;
        else if (flagName == "move") flag = GH_PERM_MOVE;
        else if (flagName == "admin") flag = GH_PERM_ADMIN;
        else if (flagName == "workshop") flag = GH_PERM_WORKSHOP;
        else
        {
            handler->SendSysMessage("Unknown flag. valid: spawn, delete, move, admin, workshop");
            return false;
        }

        // Fetch current perm
        uint32 currentPerm = 0;
        QueryResult result = CharacterDatabase.Query("SELECT `permission` FROM `dc_guild_house_permissions` WHERE `guildId`={} AND `rankId`={}", player->GetGuildId(), rankId);
        if (result) currentPerm = result->Fetch()[0].Get<uint32>();

        if (action == "add")
            currentPerm |= flag;
        else if (action == "remove")
            currentPerm &= ~flag;
        else
        {
            handler->SendSysMessage("Unknown action. Use add or remove.");
            return false;
        }

        GuildHouseManager::SetPermission(player->GetGuildId(), rankId, currentPerm);
        handler->PSendSysMessage("Updated permissions for Rank {}. New Mask: {}", rankId, currentPerm);
        return true;
    }

    static bool HandleUndoCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player || !player->GetGuildId()) return false;

        // Check permission (Spawn/Delete implies ability to undo it, or specific admin?)
        // Let's require ADMIN or matching permission. For simplicity, SPAWN allowed spawning, so they can maybe undo?
        // Safest is to restrict to ADMIN permission or Rank 0.
        if (!GuildHouseManager::HasPermission(player, GH_PERM_ADMIN))
        {
             handler->SendSysMessage("You do not have permission to undo actions.");
             return false;
        }

        uint32 logId = 0;
        if (*args) logId = (uint32)atoi(args);

        if (GuildHouseManager::UndoAction(player, logId))
        {
            handler->SendSysMessage("Action reverted successfully.");
        }
        else
        {
            handler->SendSysMessage("Failed to undo action (log not found or error).");
        }
        return true;
    }

    static bool HandleMoveCommand(ChatHandler* handler, const char* args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player || !player->GetGuildId()) return false;

        if (!*args)
        {
            handler->SendSysMessage("Usage: .gh move <locationId>");
            return false;
        }

        // Permission Check: Guild Master or Admin
        if (player->GetRank() != 0 && !GuildHouseManager::HasPermission(player, GH_PERM_ADMIN))
        {
             handler->SendSysMessage("You do not have permission to move the Guild House.");
             return false;
        }

        uint32 locationId = (uint32)atoi(args);

        // Note: Command bypasses cost check? Or should we enforce it?
        // Let's enforce it unless they are GM
        bool free = player->IsGameMaster();
        uint32 moveCost = sConfigMgr->GetOption<uint32>("GuildHouse.MoveCost", 0);

        if (!free && moveCost && player->GetMoney() < moveCost)
        {
            handler->SendSysMessage("You do not have enough money to move your Guild House.");
            return false;
        }

        if (GuildHouseManager::MoveGuildHouse(player->GetGuildId(), locationId))
        {
            if (!free && moveCost) player->ModifyMoney(-static_cast<int64>(moveCost));
            handler->SendSysMessage("Guild House has been moved.");
        }
        else
        {
            handler->SendSysMessage("Error moving Guild House (invalid location or guild has no house).");
        }
        return true;
    }
};

void AddSC_cs_dc_guildhouse()
{
    new GuildHouseCommandScript();
}
