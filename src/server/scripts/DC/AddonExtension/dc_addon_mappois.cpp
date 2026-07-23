/*
 * Dark Chaos - Map POI Addon Handler (MPOI)
 * =========================================
 *
 * Serves world-map POI markers to the client (DC-QOS QuestMapPins renders
 * them). The first (and currently only) POI type is "flight": every
 * flight-master spawn in the world, so custom maps without a client taxi map
 * (Azshara Crater 37, DC Hyjal 750, DC Plaguelands 751, Hyjal Frontier 1410)
 * still show their flight masters on the world map with a name tooltip.
 *
 * Flight masters are detected from live spawn data, so new spawns appear
 * without any server or client change:
 *  - creature_template.npcflag & UNIT_NPC_FLAG_FLIGHTMASTER (DBC-taxi NPCs), or
 *  - a script name containing "flightmaster" (gossip-based custom flight
 *    masters such as acflightmaster*, npc_dc_downport_flightmaster).
 *
 * The POI list is static world data: it is scanned once on first request and
 * cached. Requests are answered from memory (no DB round-trip); responses are
 * paged like the TELE list and faction-filtered per player.
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "Config.h"
#include "DBCStores.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "UnitDefines.h"

#include <algorithm>
#include <cctype>
#include <vector>

namespace DCAddon
{
namespace MapPOIs
{
    struct MapPOI
    {
        std::string name;
        uint32 map = 0;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        uint32 hostileMask = 0;     // FactionTemplate hostile mask (0 = visible to everyone)
    };

    // Two spawns of the same entry closer than this are one map marker
    // (paired/duplicate spawns at the same taxi node).
    constexpr float DUPLICATE_SPAWN_RANGE = 25.0f;

    static bool IsFlightMasterScriptName(std::string const& scriptName)
    {
        if (scriptName.empty())
            return false;

        std::string lowered(scriptName);
        std::transform(lowered.begin(), lowered.end(), lowered.begin(),
            [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        return lowered.find("flightmaster") != std::string::npos
            || lowered.find("flight_master") != std::string::npos;
    }

    static std::vector<MapPOI> BuildFlightMasterList()
    {
        std::vector<MapPOI> pois;
        // entry per POI, parallel to pois: needed only for duplicate collapsing
        std::vector<uint32> poiEntries;

        for (auto const& [spawnId, data] : sObjectMgr->GetAllCreatureData())
        {
            CreatureTemplate const* proto = sObjectMgr->GetCreatureTemplate(data.id);
            if (!proto)
                continue;

            bool const flagged = (proto->npcflag & UNIT_NPC_FLAG_FLIGHTMASTER) != 0
                || (data.npcflag & UNIT_NPC_FLAG_FLIGHTMASTER) != 0;
            bool const scripted = IsFlightMasterScriptName(sObjectMgr->GetScriptName(proto->ScriptID))
                || IsFlightMasterScriptName(sObjectMgr->GetScriptName(data.ScriptId));
            if (!flagged && !scripted)
                continue;

            // Collapse duplicate spawns of the same NPC at the same taxi node.
            bool duplicate = false;
            for (size_t i = 0; i < pois.size(); ++i)
            {
                if (poiEntries[i] != data.id || pois[i].map != data.mapid)
                    continue;

                float const dx = pois[i].x - data.posX;
                float const dy = pois[i].y - data.posY;
                if ((dx * dx) + (dy * dy) <= DUPLICATE_SPAWN_RANGE * DUPLICATE_SPAWN_RANGE)
                {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate)
                continue;

            MapPOI poi;
            poi.name = proto->Name;
            poi.map = data.mapid;
            poi.x = data.posX;
            poi.y = data.posY;
            poi.z = data.posZ;
            if (FactionTemplateEntry const* faction = sFactionTemplateStore.LookupEntry(proto->faction))
                poi.hostileMask = faction->hostileMask;

            pois.push_back(std::move(poi));
            poiEntries.push_back(data.id);
        }

        LOG_INFO("dc.addon", "MapPOI (MPOI): cached {} flight-master map markers", pois.size());
        return pois;
    }

    // Built on first request (world thread), immutable afterwards.
    static std::vector<MapPOI> const& GetFlightMasterPOIs()
    {
        static std::vector<MapPOI> const pois = BuildFlightMasterList();
        return pois;
    }

    static void HandleRequestList(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        uint32 offset = 0;
        uint32 limit = 60;
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

        if (limit < 10)
            limit = 10;
        if (limit > 100)
            limit = 100;

        // Hide markers whose faction is hostile to the player's team.
        uint32 const teamMask = (player->GetTeamId(true) == TEAM_ALLIANCE)
            ? FACTION_MASK_ALLIANCE : FACTION_MASK_HORDE;

        std::vector<MapPOI const*> visible;
        for (MapPOI const& poi : GetFlightMasterPOIs())
            if (!(poi.hostileMask & teamMask))
                visible.push_back(&poi);

        uint32 const total = static_cast<uint32>(visible.size());

        JsonMessage response(Module::MAP_POI, Opcode::MapPOI::SMSG_SEND_LIST);
        response.Set("offset", offset);
        response.Set("limit", limit);
        response.Set("reset", reset);

        JsonValue arr;
        arr.SetArray();
        for (uint32 i = offset; i < total && i < offset + limit; ++i)
        {
            MapPOI const* poi = visible[i];
            JsonValue obj;
            obj.SetObject();
            obj.Set("t", JsonValue("flight"));
            obj.Set("n", JsonValue(poi->name));
            obj.Set("m", JsonValue(poi->map));
            obj.Set("x", JsonValue(static_cast<double>(poi->x)));
            obj.Set("y", JsonValue(static_cast<double>(poi->y)));
            obj.Set("z", JsonValue(static_cast<double>(poi->z)));
            arr.Push(obj);
        }

        uint32 const returned = static_cast<uint32>(arr.Size());
        response.Set("total", total);
        response.Set("pois", arr);
        response.Set("done", (total == 0) ? true : ((offset + returned) >= total));
        response.Send(player);
    }

    void RegisterHandlers()
    {
        bool const enabled = sConfigMgr->GetOption<bool>("DC.AddonProtocol.MapPOI.Enable", true);

        MessageRouter::Instance().SetModuleEnabled(Module::MAP_POI, enabled);
        if (!enabled)
            return;

        DC_REGISTER_HANDLER(Module::MAP_POI, Opcode::MapPOI::CMSG_REQUEST_LIST, HandleRequestList);
        LOG_INFO("dc.addon", "MapPOI (MPOI) module handlers registered");
    }

} // namespace MapPOIs
} // namespace DCAddon

void AddSC_dc_addon_mappois()
{
    DCAddon::MapPOIs::RegisterHandlers();
}
