#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "ScriptedGossip.h"
#include "WorldSession.h"
#include "Chat.h"
#include "CommandScript.h"
#include "DatabaseEnv.h"

#include <algorithm>
#include <map>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "../GuildHousing/dc_guildhouse.h"

using namespace Acore::ChatCommands;

enum TeleporterTypes
{
    TELEPORTER_TYPE_MENU = 1,
    TELEPORTER_TYPE_TELEPORT = 2,
    TELEPORTER_TYPE_GUILDHOUSE = 3
};

struct TeleporterOption
{
    uint32 Id;
    uint32 ParentId;
    uint8 Type;
    int32 Faction;
    int32 SecurityLevel;
    uint8 Icon;
    std::string Name;
    uint32 MapId;
    float X, Y, Z, O;
};

std::map<uint32, TeleporterOption> sTeleporterOptions;
std::unordered_map<uint32, std::vector<uint32>> sTeleporterByParent;

void ValidateTeleporterOptions()
{
    uint32 orphanParentCount = 0;
    uint32 emptyMenuCount = 0;
    uint32 duplicateLabelCount = 0;

    for (auto const& [id, option] : sTeleporterOptions)
    {
        if (option.Type < TELEPORTER_TYPE_MENU || option.Type > TELEPORTER_TYPE_GUILDHOUSE)
            LOG_ERROR("server.loading", "dc_teleporter: invalid type {} for id {} ('{}').", option.Type, id, option.Name);

        if (option.ParentId != 0 && sTeleporterOptions.find(option.ParentId) == sTeleporterOptions.end())
        {
            ++orphanParentCount;
            LOG_WARN("server.loading", "dc_teleporter: id {} ('{}') references missing parent {}.", id, option.Name, option.ParentId);
        }

        if (option.Type == TELEPORTER_TYPE_MENU)
        {
            auto childIt = sTeleporterByParent.find(id);
            if (childIt == sTeleporterByParent.end() || childIt->second.empty())
            {
                ++emptyMenuCount;
                LOG_WARN("server.loading", "dc_teleporter: menu id {} ('{}') has no child entries.", id, option.Name);
            }
        }
    }

    for (auto const& [parentId, ids] : sTeleporterByParent)
    {
        std::unordered_set<std::string> seenPerParent;
        seenPerParent.reserve(ids.size());

        for (uint32 id : ids)
        {
            auto optIt = sTeleporterOptions.find(id);
            if (optIt == sTeleporterOptions.end())
                continue;

            TeleporterOption const& option = optIt->second;
            std::string duplicateKey = std::to_string(option.Faction) + ":" + std::to_string(option.SecurityLevel) + ":" + option.Name;
            if (!seenPerParent.insert(duplicateKey).second)
            {
                ++duplicateLabelCount;
                LOG_WARN("server.loading", "dc_teleporter: duplicate label '{}' under parent {} (id {}).", option.Name, parentId, option.Id);
            }
        }
    }

    if (orphanParentCount || emptyMenuCount || duplicateLabelCount)
    {
        LOG_WARN("server.loading", "dc_teleporter validation summary: {} orphan parent link(s), {} empty menu(s), {} duplicate label(s).",
            orphanParentCount, emptyMenuCount, duplicateLabelCount);
    }
}

void BuildTeleporterIndex()
{
    sTeleporterByParent.clear();
    sTeleporterByParent.reserve(sTeleporterOptions.size());

    for (auto const& [id, option] : sTeleporterOptions)
        sTeleporterByParent[option.ParentId].push_back(id);

    for (auto& [parentId, ids] : sTeleporterByParent)
    {
        std::sort(ids.begin(), ids.end());
    }
}

void LoadTeleporterOptions()
{
    sTeleporterOptions.clear();
    sTeleporterByParent.clear();
    QueryResult result = WorldDatabase.Query("SELECT id, parent, type, faction, security_level, icon, name, map, x, y, z, o FROM dc_teleporter");

    if (!result)
    {
        LOG_INFO("server.loading", "Loaded 0 teleporter options.");
        return;
    }

    do
    {
        Field* fields = result->Fetch();
        TeleporterOption option;
        option.Id = fields[0].Get<uint32>();
        option.ParentId = fields[1].Get<uint32>();
        option.Type = fields[2].Get<uint8>();
        option.Faction = fields[3].Get<int32>();
        option.SecurityLevel = fields[4].Get<int32>();
        option.Icon = fields[5].Get<uint8>();
        option.Name = fields[6].Get<std::string>();
        option.MapId = fields[7].Get<uint32>();
        option.X = fields[8].Get<float>();
        option.Y = fields[9].Get<float>();
        option.Z = fields[10].Get<float>();
        option.O = fields[11].Get<float>();

        sTeleporterOptions[option.Id] = option;

    } while (result->NextRow());

    BuildTeleporterIndex();
    ValidateTeleporterOptions();
    LOG_INFO("server.loading", "Loaded {} teleporter options.", sTeleporterOptions.size());
}

class dc_teleporter_creature_script : public CreatureScript
{
public:
    dc_teleporter_creature_script() : CreatureScript("dc_teleporter_creature_script") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ShowMenu(player, creature, 0);
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (action == 0)
        {
             ShowMenu(player, creature, 0);
             return true;
        }

        auto it = sTeleporterOptions.find(action);
        if (it == sTeleporterOptions.end())
            return false;

        TeleporterOption const& option = it->second;

        if (option.Type == TELEPORTER_TYPE_MENU)
        {
            ShowMenu(player, creature, option.Id);
        }
        else if (option.Type == TELEPORTER_TYPE_TELEPORT)
        {
            CloseGossipMenuFor(player);
            player->TeleportTo(option.MapId, option.X, option.Y, option.Z, option.O);
        }
        else if (option.Type == TELEPORTER_TYPE_GUILDHOUSE)
        {
            if (player->IsInCombat())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You can't use this while in combat.");
                ShowMenu(player, creature, option.ParentId);
                return true;
            }

            if (!player->GetGuild())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You are not in a guild.");
                ShowMenu(player, creature, option.ParentId);
                return true;
            }

            if (GuildHouseManager::TeleportToGuildHouse(player, player->GetGuildId()))
            {
                CloseGossipMenuFor(player);
                return true;
            }

            ChatHandler(player->GetSession()).PSendSysMessage("Your guild does not own a Guild House.");
            ShowMenu(player, creature, option.ParentId);
        }

        return true;
    }

private:
    void ShowMenu(Player* player, Creature* creature, uint32 parentId)
    {
        ClearGossipMenuFor(player);
        bool hasVisibleEntries = false;

        auto listIt = sTeleporterByParent.find(parentId);
        if (listIt != sTeleporterByParent.end())
        {
            for (uint32 optionId : listIt->second)
            {
                auto optIt = sTeleporterOptions.find(optionId);
                if (optIt == sTeleporterOptions.end())
                    continue;

                TeleporterOption const& option = optIt->second;

                if (option.Faction != -1 && static_cast<int32>(player->GetTeamId()) != option.Faction)
                    continue;

                if (player->GetSession()->GetSecurity() < option.SecurityLevel)
                    continue;

                hasVisibleEntries = true;
                AddGossipItemFor(player, option.Icon, option.Name, 0, option.Id);
            }
        }

        if (!hasVisibleEntries && parentId != 0)
            ChatHandler(player->GetSession()).PSendSysMessage("No destinations are available in this menu.");

        if (parentId != 0)
        {
            uint32 backId = 0;
            auto it = sTeleporterOptions.find(parentId);
            if (it != sTeleporterOptions.end())
            {
                backId = it->second.ParentId;
            }

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "[Back]", 0, backId);
        }

        SendGossipMenuFor(player, 1, creature->GetGUID());
    }
};

class dc_teleporter_command_script : public CommandScript
{
public:
    dc_teleporter_command_script() : CommandScript("dc_teleporter_command_script") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable teleporterSubCommands =
        {
            ChatCommandBuilder("reload", HandleReloadCommand, SEC_GAMEMASTER, Console::No)
        };

        static ChatCommandTable dcCommandTable =
        {
            ChatCommandBuilder("teleporter", teleporterSubCommands)
        };

        static ChatCommandTable commandTable =
        {
            ChatCommandBuilder("dc", dcCommandTable)
        };

        return commandTable;
    }

    static bool HandleReloadCommand(ChatHandler* handler, char const* /*args*/)
    {
        LoadTeleporterOptions();
        handler->SendSysMessage("DC Teleporter options reloaded.");
        return true;
    }
};

class dc_teleporter_world_script : public WorldScript
{
public:
    dc_teleporter_world_script() : WorldScript("dc_teleporter_world_script") { }

    void OnStartup() override
    {
        LoadTeleporterOptions();
    }
};

void AddSC_dc_teleporter()
{
    new dc_teleporter_creature_script();
    new dc_teleporter_command_script();
    new dc_teleporter_world_script();
}
