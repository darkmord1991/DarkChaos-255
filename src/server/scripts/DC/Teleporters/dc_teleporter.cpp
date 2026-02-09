#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "ScriptedGossip.h"
#include "WorldSession.h"
#include "Chat.h"
#include "CommandScript.h"
#include "DatabaseEnv.h"

#include <algorithm>
#include <unordered_map>
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
    LOG_INFO("server.loading", "Loaded {} teleporter options.", sTeleporterOptions.size());
}

class dc_teleporter_creature_script : public CreatureScript
{
public:
    dc_teleporter_creature_script() : CreatureScript("dc_teleporter_creature_script") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (WorldSession* session = player->GetSession(); session && session->IsBot())
            return true;

        ShowMenu(player, creature, 0);
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (WorldSession* session = player->GetSession(); session && session->IsBot())
        {
            CloseGossipMenuFor(player);
            return true;
        }

        if (action == 0) // Back to main menu (if parent was 0, though usually 0 is not a valid action for options unless specifically handled)
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
    /*
     * ShowMenu - builds gossip menu for teleporter NPC
     *
     * Notes about gossip buttons/icons:
     * - `option.Icon` is an integer stored in the `dc_teleporter` table and maps to
     *   GossipOptionIcon values (see `GossipDef.h`). Common icons and appearance:
     *     - GOSSIP_ICON_CHAT (0): white chat bubble — plain text/button
     *     - GOSSIP_ICON_VENDOR (1): brown bag — merchant-style action
     *     - GOSSIP_ICON_TAXI (2): paper plane — flight/taxi marker
     *     - GOSSIP_ICON_TRAINER (3): brown book — trainer-like action
     *     - GOSSIP_ICON_INTERACT_1/2 (4/5): golden interaction wheel
     *     - GOSSIP_ICON_MONEY_BAG (6): bag with coin — purchase/payment
     *     - GOSSIP_ICON_TALK (7): chat bubble with ellipsis — more info
     *     - GOSSIP_ICON_TABARD (8): tabard icon
     *     - GOSSIP_ICON_BATTLE (9): crossed swords — battle/duel
     *     - GOSSIP_ICON_DOT (10): small yellow dot — marker/indicator
     *
     * - Example usage:
     *     AddGossipItemFor(player, option.Icon, option.Name, 0, option.Id);
     *     AddGossipItemFor(player, GOSSIP_ICON_CHAT, "[Back]", 0, backId);
     */
    void ShowMenu(Player* player, Creature* creature, uint32 parentId)
    {
        ClearGossipMenuFor(player);
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

                AddGossipItemFor(player, option.Icon, option.Name, 0, option.Id);
            }
        }

        if (parentId != 0)
        {
            uint32 backId = 0;
            auto it = sTeleporterOptions.find(parentId);
            if (it != sTeleporterOptions.end())
            {
                backId = it->second.ParentId;
            }

            // If backId is 0, it means back to main menu.
            // If backId is not 0, it means back to parent menu.
            // We need to send an action that OnGossipSelect understands.
            // If we send 0, OnGossipSelect calls ShowMenu(0).
            // If we send backId (e.g. 5), OnGossipSelect calls ShowMenu(5).
            // However, if backId is 0, we send 0.
            // But wait, if we have an option with ID 0 (unlikely but possible), it would conflict.
            // Assuming no option with ID 0.

            // But wait, if backId is a MENU option, OnGossipSelect will find it in sTeleporterOptions and call ShowMenu(backId).
            // If backId is 0, it won't find it (unless ID 0 exists).
            // If not found, OnGossipSelect returns false?
            // No, I added a check: if (action == 0) ShowMenu(0).

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

    static ChatCommandTable GetTeleporterSubCommands()
    {
        static ChatCommandTable commandTable =
        {
            ChatCommandBuilder("reload", HandleReloadCommand, SEC_GAMEMASTER, Console::No)
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
