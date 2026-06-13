/*
 * Dark Chaos - Guild House Decorations Addon Integration
 * ======================================================
 *
 * DECO module: player-facing decoration placement for guild houses over
 * the unified DC addon protocol. Unlike GOMV (raw GM object mover) every
 * operation here is validated server-side against guild membership, rank
 * permissions, house bounds, and the decoration budget - see
 * GuildHousing/dc_guildhouse_decorations.cpp.
 *
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "Chat.h"
#include "Config.h"
#include "GameObject.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "../GOMove/GOMove.h"
#include "../GuildHousing/dc_guildhouse.h"
#include "../GuildHousing/dc_guildhouse_decorations.h"

#include <cstdlib>

namespace DCAddon
{
namespace Decorations
{
    namespace GHD = DCGuildHouseDecorations;

    static void HandleGetCatalog(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        std::string category;
        uint32 offset = 0;
        uint32 limit = 25;

        JsonValue json = GetJsonData(msg);
        if (!json.IsNull())
        {
            if (json.HasKey("category"))
                category = json["category"].AsString();
            if (json.HasKey("offset"))
                offset = json["offset"].AsUInt32();
            if (json.HasKey("limit"))
                limit = std::min(50u, json["limit"].AsUInt32());
        }

        JsonValue response;
        response.SetObject();

        JsonValue categories;
        categories.SetArray();
        for (std::string const& name : GHD::GetCategories())
            categories.Push(JsonValue(name));
        response.Set("categories", categories);

        JsonValue items;
        items.SetArray();
        for (GHD::CatalogEntry const* item
            : GHD::GetCatalogPage(category, offset, limit))
        {
            JsonValue row;
            row.SetObject();
            row.Set("entry", static_cast<int32>(item->entry));
            row.Set("name", item->name);
            row.Set("category", item->category);
            row.Set("cost", static_cast<int32>(item->costCopper));
            row.Set("minLevel", static_cast<int32>(item->minHouseLevel));
            row.Set("weight", static_cast<int32>(item->budgetWeight));
            items.Push(row);
        }
        response.Set("items", items);
        response.Set("total",
            static_cast<int32>(GHD::GetCatalogSize(category)));
        response.Set("offset", static_cast<int32>(offset));

        JsonMessage(Module::DECORATION, Opcode::Decoration::SMSG_CATALOG,
            response).Send(player);
    }

    static void SendOpResult(Player* player, uint8 opcode, bool success,
        std::string const& error, uint32 lowguid = 0, uint32 refund = 0)
    {
        JsonValue response;
        response.SetObject();
        response.Set("success", success);
        if (!success)
            response.Set("error", error);
        if (lowguid)
            response.Set("lowguid", static_cast<int32>(lowguid));
        if (refund)
            response.Set("refund", static_cast<int32>(refund));

        JsonMessage(Module::DECORATION, opcode, response).Send(player);
    }

    static void HandlePlace(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        uint32 entry = 0;
        bool hasCoords = false;
        float x = 0.0f, y = 0.0f, z = 0.0f, o = 0.0f;

        JsonValue json = GetJsonData(msg);
        if (!json.IsNull())
        {
            if (json.HasKey("entry"))
                entry = json["entry"].AsUInt32();

            if (json.HasKey("x") && json.HasKey("y") && json.HasKey("z"))
            {
                hasCoords = true;
                x = static_cast<float>(json["x"].AsNumber());
                y = static_cast<float>(json["y"].AsNumber());
                z = static_cast<float>(json["z"].AsNumber());
                if (json.HasKey("o"))
                    o = static_cast<float>(json["o"].AsNumber());
            }
        }

        if (!entry)
        {
            SendError(player, Module::DECORATION, "Missing entry",
                ErrorCode::BAD_FORMAT, Opcode::Core::SMSG_ERROR);
            return;
        }

        std::string error;
        uint32 lowguid = 0;
        bool const success = hasCoords
            ? GHD::PlaceAt(player, entry, x, y, z, o, error, &lowguid)
            : GHD::Place(player, entry, error, &lowguid);
        SendOpResult(player, Opcode::Decoration::SMSG_PLACE_RESULT, success,
            error, lowguid);
    }

    static void HandleMove(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        uint32 lowguid = 0;
        std::string mode = "here";
        float x = 0.0f, y = 0.0f, z = 0.0f, o = 0.0f;
        float dx = 0.0f, dy = 0.0f, dz = 0.0f, dOrientation = 0.0f;

        JsonValue json = GetJsonData(msg);
        if (!json.IsNull())
        {
            if (json.HasKey("lowguid"))
                lowguid = json["lowguid"].AsUInt32();
            if (json.HasKey("mode"))
                mode = json["mode"].AsString();
            if (json.HasKey("x"))
                x = static_cast<float>(json["x"].AsNumber());
            if (json.HasKey("y"))
                y = static_cast<float>(json["y"].AsNumber());
            if (json.HasKey("z"))
                z = static_cast<float>(json["z"].AsNumber());
            if (json.HasKey("o"))
                o = static_cast<float>(json["o"].AsNumber());
            if (json.HasKey("dx"))
                dx = static_cast<float>(json["dx"].AsNumber());
            if (json.HasKey("dy"))
                dy = static_cast<float>(json["dy"].AsNumber());
            if (json.HasKey("dz"))
                dz = static_cast<float>(json["dz"].AsNumber());
            if (json.HasKey("do"))
                dOrientation = static_cast<float>(json["do"].AsNumber());
        }

        if (!lowguid)
        {
            SendError(player, Module::DECORATION, "Missing lowguid",
                ErrorCode::BAD_FORMAT, Opcode::Core::SMSG_ERROR);
            return;
        }

        std::string error;
        bool success = false;
        if (mode == "rotate")
            success = GHD::Rotate(player, lowguid, error);
        else if (mode == "to")
            success = GHD::MoveTo(player, lowguid, x, y, z, o, error);
        else if (mode == "nudge")
            success = GHD::Nudge(player, lowguid, dx, dy, dz, dOrientation,
                error);
        else
            success = GHD::MoveHere(player, lowguid, error);
        SendOpResult(player, Opcode::Decoration::SMSG_MOVE_RESULT, success,
            error, lowguid);
    }

    static void HandleSelect(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        std::string guidHex;
        JsonValue json = GetJsonData(msg);
        if (!json.IsNull() && json.HasKey("guid"))
            guidHex = json["guid"].AsString();

        uint64 const rawGuid =
            std::strtoull(guidHex.c_str(), nullptr, 16);
        if (!rawGuid)
        {
            SendError(player, Module::DECORATION, "Missing guid",
                ErrorCode::BAD_FORMAT, Opcode::Core::SMSG_ERROR);
            return;
        }

        JsonValue response;
        response.SetObject();

        std::string error;
        uint32 lowguid = 0;
        uint32 entry = 0;
        uint32 paidCopper = 0;
        if (!GHD::ResolveSelection(player, rawGuid, lowguid, entry,
            paidCopper, error))
        {
            response.Set("success", false);
            response.Set("error", error);
            JsonMessage(Module::DECORATION,
                Opcode::Decoration::SMSG_SELECT_RESULT, response)
                .Send(player);
            return;
        }

        response.Set("success", true);
        response.Set("lowguid", static_cast<int32>(lowguid));
        response.Set("entry", static_cast<int32>(entry));
        response.Set("paid", static_cast<int32>(paidCopper));

        if (GHD::CatalogEntry const* item = GHD::FindCatalogEntry(entry))
        {
            response.Set("name", item->name);
            response.Set("weight", static_cast<int32>(item->budgetWeight));
        }

        if (GameObject* object = ::GOMove::GetGameObject(player, lowguid))
        {
            response.Set("x", JsonValue(object->GetPositionX()));
            response.Set("y", JsonValue(object->GetPositionY()));
            response.Set("z", JsonValue(object->GetPositionZ()));
            response.Set("o", JsonValue(object->GetOrientation()));
        }

        JsonMessage(Module::DECORATION,
            Opcode::Decoration::SMSG_SELECT_RESULT, response).Send(player);
    }

    static void HandleRemove(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        uint32 lowguid = 0;
        JsonValue json = GetJsonData(msg);
        if (!json.IsNull() && json.HasKey("lowguid"))
            lowguid = json["lowguid"].AsUInt32();

        if (!lowguid)
        {
            SendError(player, Module::DECORATION, "Missing lowguid",
                ErrorCode::BAD_FORMAT, Opcode::Core::SMSG_ERROR);
            return;
        }

        std::string error;
        uint32 refund = 0;
        bool const success = GHD::Remove(player, lowguid, error, &refund);
        SendOpResult(player, Opcode::Decoration::SMSG_REMOVE_RESULT, success,
            error, lowguid, refund);
    }

    static void HandleGetBudget(Player* player, ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        uint32 const guildId = player->GetGuildId();
        uint8 const houseLevel =
            GuildHouseManager::GetGuildHouseLevel(guildId);

        JsonValue response;
        response.SetObject();
        response.Set("used", static_cast<int32>(GHD::GetUsedBudget(guildId)));
        response.Set("cap", static_cast<int32>(GHD::GetBudgetCap(houseLevel)));
        response.Set("houseLevel", static_cast<int32>(houseLevel));
        response.Set("canSpawn",
            GuildHouseManager::HasPermission(player, GH_PERM_SPAWN));
        response.Set("canMove",
            GuildHouseManager::HasPermission(player, GH_PERM_MOVE));
        response.Set("canDelete",
            GuildHouseManager::HasPermission(player, GH_PERM_DELETE));

        JsonMessage(Module::DECORATION, Opcode::Decoration::SMSG_BUDGET,
            response).Send(player);
    }

    static void HandleList(Player* player, ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        std::vector<GHD::PlacedDecoration> items;
        GHD::ListDecorations(player, items);

        JsonValue response;
        response.SetObject();
        JsonValue arr;
        arr.SetArray();
        for (GHD::PlacedDecoration const& d : items)
        {
            JsonValue row;
            row.SetObject();
            row.Set("lowguid", static_cast<int32>(d.lowguid));
            row.Set("entry", static_cast<int32>(d.entry));
            row.Set("name", d.name);
            row.Set("x", JsonValue(d.x));
            row.Set("y", JsonValue(d.y));
            row.Set("z", JsonValue(d.z));
            row.Set("mapId", static_cast<int32>(d.mapId));
            arr.Push(row);
        }
        response.Set("items", arr);
        response.Set("count", static_cast<int32>(items.size()));
        JsonMessage(Module::DECORATION, Opcode::Decoration::SMSG_LIST,
            response).Send(player);
    }

    void RegisterHandlers()
    {
        if (!sConfigMgr->GetOption<bool>(
            "DC.AddonProtocol.Decoration.Enable", true))
            return;

        DC_REGISTER_HANDLER(Module::DECORATION,
            Opcode::Decoration::CMSG_GET_CATALOG, HandleGetCatalog);
        DC_REGISTER_HANDLER(Module::DECORATION,
            Opcode::Decoration::CMSG_PLACE, HandlePlace);
        DC_REGISTER_HANDLER(Module::DECORATION,
            Opcode::Decoration::CMSG_MOVE, HandleMove);
        DC_REGISTER_HANDLER(Module::DECORATION,
            Opcode::Decoration::CMSG_REMOVE, HandleRemove);
        DC_REGISTER_HANDLER(Module::DECORATION,
            Opcode::Decoration::CMSG_GET_BUDGET, HandleGetBudget);
        DC_REGISTER_HANDLER(Module::DECORATION,
            Opcode::Decoration::CMSG_SELECT, HandleSelect);
        DC_REGISTER_HANDLER(Module::DECORATION,
            Opcode::Decoration::CMSG_LIST, HandleList);
    }
}
}

void AddSC_DCAddon_Decorations()
{
    DCAddon::Decorations::RegisterHandlers();
}
