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
#include "StringFormat.h"
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
        std::string const& error, uint32 lowguid = 0, uint32 refund = 0,
        uint64 rawGuid = 0)
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
        // Full 64-bit ObjectGuid as a hex string (does not fit the int32 Set
        // overload). The client strtoull's it (base 16, "0x" tolerated) to
        // auto-select the just-placed object - see HandleSelect.
        if (rawGuid)
            response.Set("guid", Acore::StringFormat("0x{:016X}", rawGuid));

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
        uint64 rawGuid = 0;
        bool const success = hasCoords
            ? GHD::PlaceAt(player, entry, x, y, z, o, error, &lowguid, &rawGuid)
            : GHD::Place(player, entry, error, &lowguid, &rawGuid);
        SendOpResult(player, Opcode::Decoration::SMSG_PLACE_RESULT, success,
            error, lowguid, 0, rawGuid);
    }

    static void HandleMove(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        uint32 lowguid = 0;
        std::string mode = "here";
        float x = 0.0f, y = 0.0f, z = 0.0f, o = 0.0f;
        float dx = 0.0f, dy = 0.0f, dz = 0.0f, dOrientation = 0.0f;
        float scale = 1.0f;

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
            if (json.HasKey("scale"))
                scale = static_cast<float>(json["scale"].AsNumber());
        }

        if (!lowguid)
        {
            SendError(player, Module::DECORATION, "Missing lowguid",
                ErrorCode::BAD_FORMAT, Opcode::Core::SMSG_ERROR);
            return;
        }

        std::string error;
        bool success = false;
        // GOMove respawns moved objects under a new GUID; capture it so the
        // client can re-target its gizmo. Scale keeps the same GUID (it edits
        // the live object in place), so it leaves rawGuid at 0.
        uint64 rawGuid = 0;
        if (mode == "rotate")
            success = GHD::Rotate(player, lowguid, error, &rawGuid);
        else if (mode == "to")
            success = GHD::MoveTo(player, lowguid, x, y, z, o, error,
                &rawGuid);
        else if (mode == "nudge")
            success = GHD::Nudge(player, lowguid, dx, dy, dz, dOrientation,
                error, &rawGuid);
        else if (mode == "scale")
            success = GHD::SetScale(player, lowguid, scale, error);
        else
            success = GHD::MoveHere(player, lowguid, error, &rawGuid);
        SendOpResult(player, Opcode::Decoration::SMSG_MOVE_RESULT, success,
            error, lowguid, 0, rawGuid);
    }

    static void HandleSelect(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        JsonValue json = GetJsonData(msg);
        uint64 rawGuid = 0;
        if (!json.IsNull())
        {
            // Cursor-pick path sends the full client GUID; the manage list
            // sends only the decoration row id, so resolve that to the live
            // object's GUID here.
            if (json.HasKey("guid"))
                rawGuid = std::strtoull(
                    json["guid"].AsString().c_str(), nullptr, 16);
            else if (json.HasKey("lowguid"))
            {
                uint32 const lowguid = json["lowguid"].AsUInt32();
                GHD::GetLiveGuidRaw(player, lowguid, rawGuid);
            }
        }

        if (!rawGuid)
        {
            JsonValue fail;
            fail.SetObject();
            fail.Set("success", false);
            fail.Set("error", std::string("That decoration could not be "
                "found nearby."));
            JsonMessage(Module::DECORATION,
                Opcode::Decoration::SMSG_SELECT_RESULT, fail).Send(player);
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
        // Echo the full GUID so a lowguid-based select (manage list) can attach
        // the client gizmo; the cursor-pick path already knew it but it is
        // harmless to send back.
        response.Set("guid", Acore::StringFormat("0x{:016X}", rawGuid));

        if (GHD::CatalogEntry const* item = GHD::FindCatalogEntry(entry))
        {
            response.Set("name", item->name);
            response.Set("weight", static_cast<int32>(item->budgetWeight));
        }

        float dx, dy, dz, dori, dscale;
        if (GHD::GetDecorationTransform(lowguid, dx, dy, dz, dori, dscale))
        {
            response.Set("x", JsonValue(dx));
            response.Set("y", JsonValue(dy));
            response.Set("z", JsonValue(dz));
            response.Set("o", JsonValue(dori));
            response.Set("scale", JsonValue(dscale));
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

    static void HandleResetAll(Player* player, ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        std::string error;
        uint32 removedCount = 0;
        uint32 totalRefund = 0;
        bool const success = GHD::RemoveAll(player, error,
            &removedCount, &totalRefund);

        JsonValue response;
        response.SetObject();
        response.Set("success", success);
        if (!success)
            response.Set("error", error);
        if (success)
        {
            response.Set("removed", static_cast<int32>(removedCount));
            response.Set("refund", static_cast<int32>(totalRefund));
        }
        JsonMessage(Module::DECORATION,
            Opcode::Decoration::SMSG_RESET_ALL_RESULT, response).Send(player);
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
            row.Set("scale", JsonValue(d.scale));
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
        DC_REGISTER_HANDLER(Module::DECORATION,
            Opcode::Decoration::CMSG_RESET_ALL, HandleResetAll);
    }
}
}

void AddSC_DCAddon_Decorations()
{
    DCAddon::Decorations::RegisterHandlers();
}
