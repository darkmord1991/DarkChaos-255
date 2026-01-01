/*
 * Dark Chaos - Hotspot Addon Module Handler
 * ==========================================
 *
 * Handles DC|SPOT|... messages for Hotspot XP bonus zones.
 * Integrates with ac_hotspots.cpp
 *
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "DCAddonNamespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Log.h"
#include "GameTime.h"
#include "DBCStores.h"
#include "World.h"

// External functions from ac_hotspots.cpp
extern uint32 GetHotspotXPBonusPercentage();

// Helper to get zone name from DBC (like .gps command does)
static std::string GetZoneNameFromDBC(uint32 zoneId)
{
    if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(zoneId))
    {
        // area_name[0] is the default English name
        if (area->area_name[0] && area->area_name[0][0])
            return area->area_name[0];
    }
    return "Unknown Zone";
}

namespace DCAddon
{
namespace Hotspot
{
    // Module identifier
    constexpr const char* MODULE_HOTSPOT = Module::HOTSPOT;

    static uint32 ReadHotspotId(const ParsedMessage& msg)
    {
        if (IsJsonMessage(msg))
        {
            JsonValue json = GetJsonData(msg);
            if (json.IsObject())
            {
                if (json.HasKey("id"))
                    return static_cast<uint32>(json["id"].AsUInt32());
                if (json.HasKey("hotspotId"))
                    return static_cast<uint32>(json["hotspotId"].AsUInt32());
            }
            return 0;
        }

        return msg.GetUInt32(0);
    }

    static JsonValue BuildHotspotObject(uint32 id, uint32 mapId, uint32 zoneId, std::string const& zoneName,
        float x, float y, float z, uint32 timeRemaining, uint32 bonusPercent)
    {
        // Use short key names to reduce payload size (saves ~100-150 bytes per hotspot)
        // Client maps: i=id, m=mapId, z=zoneId, n=zoneName, x/y/h=coords, t=timeRemaining, b=bonusPercent
        JsonValue h; h.SetObject();
        h.Set("i", JsonValue(id));
        h.Set("m", JsonValue(mapId));
        h.Set("z", JsonValue(zoneId));
        h.Set("n", JsonValue(zoneName));
        h.Set("x", JsonValue(x));
        h.Set("y", JsonValue(y));
        h.Set("h", JsonValue(z));  // 'h' for height (z was taken by zoneId)
        h.Set("t", JsonValue(timeRemaining));
        h.Set("b", JsonValue(bonusPercent));
        return h;
    }

    // Handler: Get list of active hotspots
    static void HandleGetList(Player* player, const ParsedMessage& /*msg*/)
    {
        // Query from dc_hotspots_active table (correct table name)
        // expire_time is unix timestamp, compare with current time
        QueryResult result = WorldDatabase.Query(
            "SELECT id, map_id, zone_id, x, y, z, "
            "(expire_time - UNIX_TIMESTAMP()) as dur "
            "FROM dc_hotspots_active "
            "WHERE expire_time > UNIX_TIMESTAMP()");

        // Get XP bonus from config (same for all hotspots)
        uint32 xpBonus = GetHotspotXPBonusPercentage();

        JsonValue hotspots; hotspots.SetArray();

        if (result)
        {
            do
            {
                uint32 id = (*result)[0].Get<uint32>();
                uint32 mapId = (*result)[1].Get<uint32>();
                uint32 zoneId = (*result)[2].Get<uint32>();
                float x = (*result)[3].Get<float>();
                float y = (*result)[4].Get<float>();
                float z = (*result)[5].Get<float>();
                int64 dur = (*result)[6].Get<int64>();
                if (dur <= 0)
                    continue;

                std::string zoneName = GetZoneNameFromDBC(zoneId);
                hotspots.Push(BuildHotspotObject(id, mapId, zoneId, zoneName, x, y, z, static_cast<uint32>(dur), xpBonus));
            } while (result->NextRow());
        }

        JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_HOTSPOT_LIST)
            .Set("hotspots", hotspots)
            .Send(player);
    }

    // Handler: Get specific hotspot info
    static void HandleGetInfo(Player* player, const ParsedMessage& msg)
    {
        uint32 hotspotId = ReadHotspotId(msg);
        if (!hotspotId)
        {
            JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_HOTSPOT_INFO)
                .Set("found", false)
                .Set("error", "Missing hotspot id")
                .Send(player);
            return;
        }

        QueryResult result = WorldDatabase.Query(
            "SELECT id, map_id, zone_id, x, y, z, "
            "(expire_time - UNIX_TIMESTAMP()) as dur "
            "FROM dc_hotspots_active "
            "WHERE id = {} AND expire_time > UNIX_TIMESTAMP()",
            hotspotId);

        if (!result)
        {
            JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_HOTSPOT_INFO)
                .Set("found", false)
                .Set("id", hotspotId)
                .Send(player);
            return;
        }

        // Get XP bonus from config
        uint32 xpBonus = GetHotspotXPBonusPercentage();

        uint32 mapId = (*result)[1].Get<uint32>();
        uint32 zoneId = (*result)[2].Get<uint32>();
        float x = (*result)[3].Get<float>();
        float y = (*result)[4].Get<float>();
        float z = (*result)[5].Get<float>();
        int64 dur = (*result)[6].Get<int64>();
        std::string zoneName = GetZoneNameFromDBC(zoneId);

        JsonValue hs = BuildHotspotObject(hotspotId, mapId, zoneId, zoneName, x, y, z, static_cast<uint32>(dur), xpBonus);

        JsonMessage reply(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_HOTSPOT_INFO);
        reply.Set("found", true);
        // Flatten hotspot fields at top-level for legacy consumers.
        for (auto const& [k, v] : hs.AsObject())
            reply.Set(k, v);
        reply.Send(player);
    }

    // Handler: Teleport to hotspot (GM only or with item)
    static void HandleTeleport(Player* player, const ParsedMessage& msg)
    {
        uint32 hotspotId = ReadHotspotId(msg);
        if (!hotspotId)
        {
            JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_TELEPORT_RESULT)
                .Set("success", false)
                .Set("error", "Missing hotspot id")
                .Send(player);
            return;
        }

        // Check if player has permission (GM level 1+ or special item)
        bool canTeleport = player->GetSession()->GetSecurity() >= SEC_MODERATOR;

        // Could also check for teleport item here
        // uint32 teleportItemId = sConfigMgr->GetOption<uint32>("Hotspot.TeleportItemId", 0);
        // if (teleportItemId > 0 && player->HasItemCount(teleportItemId, 1))
        //     canTeleport = true;

        if (!canTeleport)
        {
            JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_TELEPORT_RESULT)
                .Set("success", false)
                .Set("id", hotspotId)
                .Set("error", "No permission to teleport")
                .Send(player);
            return;
        }

        QueryResult result = WorldDatabase.Query(
            "SELECT map_id, x, y, z FROM dc_hotspots_active WHERE id = {} AND expire_time > UNIX_TIMESTAMP()",
            hotspotId);

        if (!result)
        {
            JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_TELEPORT_RESULT)
                .Set("success", false)
                .Set("id", hotspotId)
                .Set("error", "Hotspot not found or expired")
                .Send(player);
            return;
        }

        uint32 mapId = (*result)[0].Get<uint32>();
        float x = (*result)[1].Get<float>();
        float y = (*result)[2].Get<float>();
        float z = (*result)[3].Get<float>();

        player->TeleportTo(mapId, x, y, z, player->GetOrientation());

        JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_TELEPORT_RESULT)
            .Set("success", true)
            .Set("id", hotspotId)
            .Send(player);
    }

    // Broadcast hotspot spawn to all players
    void BroadcastHotspotSpawn(uint32 id, uint32 mapId, uint32 zoneId,
                               const std::string& zoneName, float x, float y, float z,
                               uint32 duration, uint32 bonus)
    {
        // Build hotspot object with all fields
        JsonValue hs = BuildHotspotObject(id, mapId, zoneId, zoneName, x, y, z, duration, bonus);
        
        // Build message
        JsonMessage msg(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_HOTSPOT_SPAWN);
        msg.Set("hotspot", hs);
        
        // Send to all online players
        sWorld->DoForAllSessions([&msg](WorldSession* session) {
            if (Player* player = session->GetPlayer())
                msg.Send(player);
        });
        
        LOG_DEBUG("dc.addon", "Broadcast hotspot spawn: id={} map={} zone={}", id, mapId, zoneId);
    }

    // Broadcast hotspot expiration
    void BroadcastHotspotExpire(uint32 id)
    {
        JsonMessage msg(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_HOTSPOT_EXPIRE);
        msg.Set("id", id);
        
        // Send to all online players
        sWorld->DoForAllSessions([&msg](WorldSession* session) {
            if (Player* player = session->GetPlayer())
                msg.Send(player);
        });
        
        LOG_DEBUG("dc.addon", "Broadcast hotspot expire: id={}", id);
    }

    // Register all handlers
    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(MODULE_HOTSPOT, Opcode::Hotspot::CMSG_GET_LIST, HandleGetList);
        DC_REGISTER_HANDLER(MODULE_HOTSPOT, Opcode::Hotspot::CMSG_GET_INFO, HandleGetInfo);
        DC_REGISTER_HANDLER(MODULE_HOTSPOT, Opcode::Hotspot::CMSG_TELEPORT, HandleTeleport);

        LOG_INFO("dc.addon", "Hotspot module handlers registered");
    }

}  // namespace Hotspot
}  // namespace DCAddon

void AddSC_dc_addon_hotspot()
{
    DCAddon::Hotspot::RegisterHandlers();
}
