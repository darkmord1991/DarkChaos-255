/*
 * Dark Chaos - Map POI Addon Handler (MPOI)
 * =========================================
 *
 * Serves world-map / minimap POI markers to the client (DC-QOS renders them:
 * QuestMapPins on the world map, MapPOIMinimap on the minimap). This exists
 * mainly for the custom maps that have no client-side service art at all
 * (Azshara Crater 37, DC Hyjal 750, DC Plaguelands 751, Hyjal Frontier 1410),
 * where a flight master or innkeeper is otherwise invisible until you walk
 * into it.
 *
 * Everything is detected from live spawn data, so new spawns appear without
 * any server or client change:
 *  - "flight"     creature npcflag & UNIT_NPC_FLAG_FLIGHTMASTER, or a script
 *                 name containing "flightmaster" (gossip-driven custom flight
 *                 masters such as acflightmaster*, npc_dc_downport_flightmaster).
 *  - "inn"        creature npcflag & UNIT_NPC_FLAG_INNKEEPER.
 *  - "teleporter" creature with one of the teleporter script names below.
 *                 Matched EXACTLY, never by name text: the world is full of
 *                 "... Teleport Bunny" / "Invisible Stalker ... teleport" /
 *                 "Portal Trainer" entries that must not become map markers.
 *  - "mail"       gameobject_template.type == GAMEOBJECT_TYPE_MAILBOX.
 *
 * The POI list is static world data: it is scanned once on first request and
 * cached. Requests are answered from memory (no DB round-trip); responses are
 * paged like the TELE list and faction-filtered per player.
 *
 * A POI whose name matches its type's default label is sent without a name
 * (every mailbox is called "Mailbox"); both renderers already fall back to the
 * type label, which keeps the once-per-session payload down.
 *
 * Flight POIs additionally carry the TaxiNodes.dbc id they stand on, and
 * CMSG_REQUEST_KNOWN_TAXI answers with the subset this character has already
 * discovered. That is the only way the addon can tell the two apart: the client
 * marks an UNDISCOVERED flight point itself but exposes no taxi mask to Lua, so
 * the minimap layer waits for discovery before drawing its own pin.
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "Config.h"
#include "DBCStores.h"
#include "GameObjectData.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SharedDefines.h"
#include "UnitDefines.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <string>
#include <vector>

namespace DCAddon
{
namespace MapPOIs
{
    // POI type keys. Must match the entries in the client-side registry
    // (DC-QOS/Modules/MapPOIData.lua -> MapPOIData.TYPES).
    namespace PoiType
    {
        constexpr char const* FLIGHT     = "flight";
        constexpr char const* INN        = "inn";
        constexpr char const* MAIL       = "mail";
        constexpr char const* TELEPORTER = "teleporter";
    }

    // Default label per type; a POI named exactly this is sent without a name.
    // Keep in sync with the `label` fields in the client registry.
    static char const* DefaultLabelFor(char const* type)
    {
        if (std::strcmp(type, PoiType::FLIGHT) == 0)
            return "Flight Master";
        if (std::strcmp(type, PoiType::INN) == 0)
            return "Innkeeper";
        if (std::strcmp(type, PoiType::MAIL) == 0)
            return "Mailbox";
        if (std::strcmp(type, PoiType::TELEPORTER) == 0)
            return "Teleporter";
        return "";
    }

    // Exact creature ScriptName values that mark a usable teleporter NPC.
    static constexpr char const* kTeleporterScripts[] =
    {
        "dc_teleporter_creature_script", // DC-WoW Teleporter (entry 800002)
        "npc_dungeon_portal_selector",   // Portal Keeper / Dungeon Teleporter
    };

    struct MapPOI
    {
        std::string name;           // empty => client falls back to the type label
        char const* type = nullptr;
        uint32 entry = 0;           // spawn template entry, for duplicate collapsing
        uint32 map = 0;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        uint32 hostileMask = 0;     // FactionTemplate hostile mask (0 = visible to everyone)
        uint32 taxiNode = 0;        // flight POIs: TaxiNodes.dbc id, 0 when unmatched
    };

    // Two spawns of the same template closer than this are one map marker
    // (paired/duplicate spawns at the same taxi node or doorway).
    constexpr float DUPLICATE_SPAWN_RANGE = 25.0f;

    // A flight master stands at the taxi node it serves, so the nearest node on
    // the same map within this range is that master's node. Generous enough for
    // masters posted a little away from the landing pad, tight enough that two
    // nodes in one settlement do not cross-match.
    constexpr float TAXI_NODE_MATCH_RANGE = 60.0f;

    static std::string ToLower(std::string const& value)
    {
        std::string lowered(value);
        std::transform(lowered.begin(), lowered.end(), lowered.begin(),
            [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        return lowered;
    }

    static bool IsFlightMasterScriptName(std::string const& scriptName)
    {
        if (scriptName.empty())
            return false;

        std::string const lowered = ToLower(scriptName);
        return lowered.find("flightmaster") != std::string::npos
            || lowered.find("flight_master") != std::string::npos;
    }

    static bool IsTeleporterScriptName(std::string const& scriptName)
    {
        if (scriptName.empty())
            return false;

        for (char const* candidate : kTeleporterScripts)
            if (scriptName == candidate)
                return true;

        return false;
    }

    // Classify a creature spawn. Returns nullptr when it is not a POI.
    // A creature that is several things at once (an innkeeper who is also a
    // flight master) is reported as the most travel-relevant one.
    static char const* ClassifyCreature(CreatureTemplate const* proto, CreatureData const& data)
    {
        // Effective flags, matching ObjectMgr::ChooseCreatureFlags: a non-zero
        // spawn npcflag REPLACES the template's rather than adding to it, so a
        // spawn that overrides the flags away must not be marked.
        uint32 const npcflag = data.npcflag ? data.npcflag : proto->npcflag;
        std::string const& templateScript = sObjectMgr->GetScriptName(proto->ScriptID);
        std::string const& spawnScript = sObjectMgr->GetScriptName(data.ScriptId);

        if ((npcflag & UNIT_NPC_FLAG_FLIGHTMASTER)
            || IsFlightMasterScriptName(templateScript)
            || IsFlightMasterScriptName(spawnScript))
            return PoiType::FLIGHT;

        if (IsTeleporterScriptName(templateScript) || IsTeleporterScriptName(spawnScript))
            return PoiType::TELEPORTER;

        if (npcflag & UNIT_NPC_FLAG_INNKEEPER)
            return PoiType::INN;

        return nullptr;
    }

    // TaxiNodes.dbc id a flight master serves, or 0 when nothing is close enough.
    // The client cannot read its own taxi mask on 3.3.5, so this is what lets it
    // tell a discovered flight point from an undiscovered one (see
    // HandleRequestKnownTaxi).
    static uint32 FindTaxiNodeAt(uint32 mapId, float x, float y, float z)
    {
        uint32 bestNode = 0;
        float bestDistanceSq = TAXI_NODE_MATCH_RANGE * TAXI_NODE_MATCH_RANGE;

        for (uint32 i = 1; i < sTaxiNodesStore.GetNumRows(); ++i)
        {
            TaxiNodesEntry const* node = sTaxiNodesStore.LookupEntry(i);
            if (!node || node->map_id != mapId)
                continue;

            float const dx = node->x - x;
            float const dy = node->y - y;
            float const dz = node->z - z;
            float const distanceSq = (dx * dx) + (dy * dy) + (dz * dz);
            if (distanceSq < bestDistanceSq)
            {
                bestDistanceSq = distanceSq;
                bestNode = node->ID;
            }
        }

        return bestNode;
    }

    static bool IsDuplicateOf(std::vector<MapPOI> const& pois, MapPOI const& candidate)
    {
        for (MapPOI const& existing : pois)
        {
            if (existing.entry != candidate.entry || existing.map != candidate.map
                || std::strcmp(existing.type, candidate.type) != 0)
                continue;

            float const dx = existing.x - candidate.x;
            float const dy = existing.y - candidate.y;
            if ((dx * dx) + (dy * dy) <= DUPLICATE_SPAWN_RANGE * DUPLICATE_SPAWN_RANGE)
                return true;
        }

        return false;
    }

    static void AddPOI(std::vector<MapPOI>& pois, MapPOI&& poi)
    {
        if (IsDuplicateOf(pois, poi))
            return;

        // Drop a name that only repeats the type label the client already shows.
        if (poi.name == DefaultLabelFor(poi.type))
            poi.name.clear();

        pois.push_back(std::move(poi));
    }

    static std::vector<MapPOI> BuildPOIList()
    {
        std::vector<MapPOI> pois;

        for (auto const& [spawnId, data] : sObjectMgr->GetAllCreatureData())
        {
            CreatureTemplate const* proto = sObjectMgr->GetCreatureTemplate(data.id);
            if (!proto)
                continue;

            char const* type = ClassifyCreature(proto, data);
            if (!type)
                continue;

            MapPOI poi;
            poi.name = proto->Name;
            poi.type = type;
            poi.entry = data.id;
            poi.map = data.mapid;
            poi.x = data.posX;
            poi.y = data.posY;
            poi.z = data.posZ;
            if (FactionTemplateEntry const* faction = sFactionTemplateStore.LookupEntry(proto->faction))
                poi.hostileMask = faction->hostileMask;

            if (std::strcmp(type, PoiType::FLIGHT) == 0)
                poi.taxiNode = FindTaxiNodeAt(data.mapid, data.posX, data.posY, data.posZ);

            AddPOI(pois, std::move(poi));
        }

        for (auto const& [spawnId, data] : sObjectMgr->GetAllGOData())
        {
            GameObjectTemplate const* proto = sObjectMgr->GetGameObjectTemplate(data.id);
            if (!proto || proto->type != GAMEOBJECT_TYPE_MAILBOX)
                continue;

            MapPOI poi;
            poi.name = proto->name;
            poi.type = PoiType::MAIL;
            poi.entry = data.id;
            poi.map = data.mapid;
            poi.x = data.posX;
            poi.y = data.posY;
            poi.z = data.posZ;
            // Gameobjects carry no faction template, so mailboxes are shown to
            // everyone. Faction-restricted mailboxes are handled by the client
            // never being told about spawns it cannot reach anyway.

            AddPOI(pois, std::move(poi));
        }

        uint32 flightCount = 0;
        uint32 flightWithoutNode = 0;
        uint32 innCount = 0;
        uint32 mailCount = 0;
        uint32 teleporterCount = 0;
        for (MapPOI const& poi : pois)
        {
            if (std::strcmp(poi.type, PoiType::FLIGHT) == 0)
            {
                ++flightCount;
                if (!poi.taxiNode)
                    ++flightWithoutNode;
            }
            else if (std::strcmp(poi.type, PoiType::INN) == 0)
                ++innCount;
            else if (std::strcmp(poi.type, PoiType::MAIL) == 0)
                ++mailCount;
            else if (std::strcmp(poi.type, PoiType::TELEPORTER) == 0)
                ++teleporterCount;
        }

        LOG_INFO("dc.addon",
            "MapPOI (MPOI): cached {} map markers ({} flight, {} inn, {} mail, {} teleporter)",
            pois.size(), flightCount, innCount, mailCount, teleporterCount);

        // A flight master with no taxi node cannot be discovery-gated, so the
        // client falls back to always drawing it. Worth surfacing: it usually
        // means the node is missing from TaxiNodes.dbc or sits too far away.
        if (flightWithoutNode)
            LOG_WARN("dc.addon",
                "MapPOI (MPOI): {} of {} flight markers matched no TaxiNodes.dbc entry within {} yards",
                flightWithoutNode, flightCount, TAXI_NODE_MATCH_RANGE);

        return pois;
    }

    // Built on first request (world thread), immutable afterwards.
    static std::vector<MapPOI> const& GetPOIs()
    {
        static std::vector<MapPOI> const pois = BuildPOIList();
        return pois;
    }

    // Content signature of the per-team visible POI list. The list is
    // immutable for the lifetime of the world process, so this is computed
    // once per team and lets clients skip re-downloading a list they already
    // have cached (they echo the version back with the request).
    static uint32 ComputeVisibleListVersion(uint32 teamMask)
    {
        uint32 hash = 5381;
        auto mix = [&hash](uint32 value)
        {
            hash = ((hash * 131) + value + 17) % 2147483647u;
            if (hash == 0)
                hash = 1;
        };

        for (MapPOI const& poi : GetPOIs())
        {
            if (poi.hostileMask & teamMask)
                continue;

            for (char const* ch = poi.type; ch && *ch; ++ch)
                mix(static_cast<unsigned char>(*ch));
            for (unsigned char ch : poi.name)
                mix(ch);
            mix(poi.map);
            mix(static_cast<uint32>(static_cast<int32>(poi.x)));
            mix(static_cast<uint32>(static_cast<int32>(poi.y)));
            mix(static_cast<uint32>(static_cast<int32>(poi.z)));
            mix(poi.taxiNode);
        }

        return hash;
    }

    static uint32 GetVisibleListVersion(uint32 teamMask)
    {
        static uint32 const allianceVersion =
            ComputeVisibleListVersion(FACTION_MASK_ALLIANCE);
        static uint32 const hordeVersion =
            ComputeVisibleListVersion(FACTION_MASK_HORDE);
        return (teamMask == FACTION_MASK_ALLIANCE)
            ? allianceVersion : hordeVersion;
    }

    static void HandleRequestList(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        uint32 offset = 0;
        uint32 limit = 60;
        bool reset = true;
        uint32 clientVersion = 0;

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
                if (req.HasKey("v") && req["v"].IsNumber())
                    clientVersion = req["v"].AsUInt32();
            }
        }

        if (limit < 10)
            limit = 10;
        if (limit > 100)
            limit = 100;

        // Hide markers whose faction is hostile to the player's team.
        uint32 const teamMask = (player->GetTeamId(true) == TEAM_ALLIANCE)
            ? FACTION_MASK_ALLIANCE : FACTION_MASK_HORDE;

        uint32 const listVersion = GetVisibleListVersion(teamMask);

        // Version short-circuit: the client already holds this exact list in
        // its SavedVariables cache; skip the multi-page payload entirely.
        if (clientVersion != 0 && clientVersion == listVersion && offset == 0)
        {
            JsonMessage ack(Module::MAP_POI, Opcode::MapPOI::SMSG_SEND_LIST);
            ack.Set("upToDate", true);
            ack.Set("v", listVersion);
            ack.Set("offset", 0u);
            ack.Set("total", 0u);
            ack.Set("done", true);
            ack.Send(player);
            return;
        }

        std::vector<MapPOI const*> visible;
        for (MapPOI const& poi : GetPOIs())
            if (!(poi.hostileMask & teamMask))
                visible.push_back(&poi);

        uint32 const total = static_cast<uint32>(visible.size());

        JsonMessage response(Module::MAP_POI, Opcode::MapPOI::SMSG_SEND_LIST);
        response.Set("offset", offset);
        response.Set("limit", limit);
        response.Set("reset", reset);
        response.Set("v", listVersion);

        JsonValue arr;
        arr.SetArray();
        for (uint32 i = offset; i < total && i < offset + limit; ++i)
        {
            MapPOI const* poi = visible[i];
            JsonValue obj;
            obj.SetObject();
            obj.Set("t", JsonValue(poi->type));
            if (!poi->name.empty())
                obj.Set("n", JsonValue(poi->name));
            obj.Set("m", JsonValue(poi->map));
            obj.Set("x", JsonValue(static_cast<double>(poi->x)));
            obj.Set("y", JsonValue(static_cast<double>(poi->y)));
            obj.Set("z", JsonValue(static_cast<double>(poi->z)));
            if (poi->taxiNode)
                obj.Set("k", JsonValue(poi->taxiNode));
            arr.Push(obj);
        }

        uint32 const returned = static_cast<uint32>(arr.Size());
        response.Set("total", total);
        response.Set("pois", arr);
        response.Set("done", (total == 0) ? true : ((offset + returned) >= total));
        response.Send(player);
    }

    // Which of the flight POIs this player has already discovered.
    //
    // The 3.3.5 client has no Lua access to its own taxi mask outside an open
    // taxi map, but it draws its own marker over an UNDISCOVERED flight point.
    // The addon uses this list to stay out of the way of that marker and only
    // draw its own flight pin once the point is known. Per player and cheap
    // (a few hundred bits), so it is answered live rather than cached.
    static void HandleRequestKnownTaxi(Player* player, ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        uint32 const teamMask = (player->GetTeamId(true) == TEAM_ALLIANCE)
            ? FACTION_MASK_ALLIANCE : FACTION_MASK_HORDE;

        JsonValue nodes;
        nodes.SetArray();
        for (MapPOI const& poi : GetPOIs())
        {
            if (!poi.taxiNode || (poi.hostileMask & teamMask))
                continue;
            if (player->m_taxi.IsTaximaskNodeKnown(poi.taxiNode))
                nodes.Push(JsonValue(poi.taxiNode));
        }

        JsonMessage response(Module::MAP_POI, Opcode::MapPOI::SMSG_KNOWN_TAXI);
        response.Set("nodes", nodes);
        response.Send(player);
    }

    void RegisterHandlers()
    {
        bool const enabled = sConfigMgr->GetOption<bool>("DC.AddonProtocol.MapPOI.Enable", true);

        MessageRouter::Instance().SetModuleEnabled(Module::MAP_POI, enabled);
        if (!enabled)
            return;

        DC_REGISTER_HANDLER(Module::MAP_POI, Opcode::MapPOI::CMSG_REQUEST_LIST, HandleRequestList);
        DC_REGISTER_HANDLER(Module::MAP_POI, Opcode::MapPOI::CMSG_REQUEST_KNOWN_TAXI, HandleRequestKnownTaxi);
        LOG_INFO("dc.addon", "MapPOI (MPOI) module handlers registered");
    }

} // namespace MapPOIs
} // namespace DCAddon

void AddSC_dc_addon_mappois()
{
    DCAddon::MapPOIs::RegisterHandlers();
}
