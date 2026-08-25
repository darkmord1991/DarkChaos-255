/*
 * Dark Chaos - Teleport Addon Handler
 * ===================================
 *
 * Handles teleport list requests from the client.
 *
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Config.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "WorldSession.h"
#include "DatabaseEnv.h"
#include "Log.h"

namespace DCAddon
{
    static void HandleRequestList(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        uint32 offset = 0;
        uint32 limit = 50;
        bool reset = true;

        if (IsJsonMessage(msg))
        {
            JsonValue req = GetJsonData(msg);
            if (req.IsObject())
            {
                if (req.HasKey("offset") && req["offset"].IsNumber())
                    offset = req["offset"].AsUInt32();
                if (req.HasKey("limit") && req["limit"].IsNumber())
                    limit = req["limit"].AsUInt32();
                if (req.HasKey("reset") && req["reset"].IsBool())
                    reset = req["reset"].AsBool();
            }
        }

        // Hard bounds for safety.
        if (limit < 10)
            limit = 10;
        if (limit > 200)
            limit = 200;

        // ASYNC page fetch. This used to run TWO synchronous WorldDatabase
        // queries (count + page) on the world thread per UI open -- the same
        // class as the observed 18s World.UpdateSessions stalls. One async
        // round-trip carries the total as a subquery column.
        ObjectGuid playerGuid = player->GetGUID();
        std::string const pageSql =
            "SELECT id, name, map, position_x, position_y, position_z, orientation, "
            "(SELECT COUNT(*) FROM game_tele) AS total "
            "FROM game_tele ORDER BY name LIMIT "
            + std::to_string(offset) + "," + std::to_string(limit);

        DCAddon::EnqueueQueryCallback(WorldDatabase.AsyncQuery(pageSql)
            .WithCallback([playerGuid, offset, limit, reset](QueryResult result)
        {
            Player* player = ObjectAccessor::FindPlayer(playerGuid);
            if (!player || !player->GetSession())
                return;

            JsonMessage response(Module::TELEPORTS, Opcode::Teleports::SMSG_SEND_LIST);
            response.Set("offset", offset);
            response.Set("limit", limit);
            response.Set("reset", reset);

            JsonValue arr;
            arr.SetArray();

            uint32 total = 0;
            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    uint32 id = fields[0].Get<uint32>();
                    std::string name = fields[1].Get<std::string>();
                    uint16 map = fields[2].Get<uint16>();
                    float x = fields[3].Get<float>();
                    float y = fields[4].Get<float>();
                    float z = fields[5].Get<float>();
                    float o = fields[6].Get<float>();
                    total = fields[7].Get<uint32>();

                    JsonValue obj;
                    obj.SetObject();
                    obj.Set("id", JsonValue(id));
                    obj.Set("name", JsonValue(name));
                    obj.Set("map", JsonValue(static_cast<uint32>(map)));
                    obj.Set("x", JsonValue(static_cast<double>(x)));
                    obj.Set("y", JsonValue(static_cast<double>(y)));
                    obj.Set("z", JsonValue(static_cast<double>(z)));
                    obj.Set("o", JsonValue(static_cast<double>(o)));
                    arr.Push(obj);

                } while (result->NextRow());
            }

            response.Set("total", total);
            response.Set("teleports", arr);
            uint32 returned = static_cast<uint32>(arr.Size());
            bool done = (total == 0) ? true : ((offset + returned) >= total);
            response.Set("done", done);
            response.Send(player);
        }));
    }

    void RegisterHandlers()
    {
        // Load config-based enable flags/min security if desired in future
        // For now, ensure module enabled in router
        bool enabled = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Teleports.Enable", true);
        if (!enabled)
            return;
        DC_REGISTER_HANDLER(Module::TELEPORTS, Opcode::Teleports::CMSG_REQUEST_LIST, HandleRequestList);
    }
}

// Register the handler(s) during script load
namespace DCAddon
{
    void AddTeleportScripts()
    {
        RegisterHandlers();
    }
}
