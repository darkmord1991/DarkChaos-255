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
    // Add opcode definitions for this module
    namespace Opcode
    {
        constexpr uint8 CMSG_GET_LIST       = 0x01;
        constexpr uint8 CMSG_GET_INFO       = 0x02;
        constexpr uint8 CMSG_TELEPORT       = 0x03;
        
        constexpr uint8 SMSG_HOTSPOT_LIST   = 0x10;
        constexpr uint8 SMSG_HOTSPOT_INFO   = 0x11;
        constexpr uint8 SMSG_HOTSPOT_SPAWN  = 0x12;
        constexpr uint8 SMSG_HOTSPOT_EXPIRE = 0x13;
        constexpr uint8 SMSG_TELEPORT_RESULT= 0x14;
    }
    
    // Module identifier
    constexpr const char* MODULE_HOTSPOT = "SPOT";
    
    // Handler: Get list of active hotspots
    static void HandleGetList(Player* player, const ParsedMessage& /*msg*/)
    {
        // Build hotspot list string
        // Format: count;id:map:zone:zoneName:x:y:dur:bonus;...
        
        // Query from dc_hotspots_active table (correct table name)
        // expire_time is unix timestamp, compare with current time
        QueryResult result = WorldDatabase.Query(
            "SELECT id, map_id, zone_id, x, y, z, "
            "(expire_time - UNIX_TIMESTAMP()) as dur "
            "FROM dc_hotspots_active "
            "WHERE expire_time > UNIX_TIMESTAMP()");
        
        // Get XP bonus from config (same for all hotspots)
        uint32 xpBonus = GetHotspotXPBonusPercentage();
        
        std::string list;
        uint32 count = 0;
        
        if (result)
        {
            do
            {
                if (count > 0) list += ";";
                
                uint32 id = (*result)[0].Get<uint32>();
                uint32 mapId = (*result)[1].Get<uint32>();
                uint32 zoneId = (*result)[2].Get<uint32>();
                float x = (*result)[3].Get<float>();
                float y = (*result)[4].Get<float>();
                // z is [5]
                int64 dur = (*result)[6].Get<int64>();
                std::string zoneName = GetZoneNameFromDBC(zoneId);
                
                if (dur <= 0) continue;
                
                std::ostringstream ss;
                ss << id << ":" << mapId << ":" << zoneId << ":" << zoneName 
                   << ":" << x << ":" << y << ":" << dur << ":" << xpBonus;
                list += ss.str();
                count++;
            } while (result->NextRow());
        }
        
        Message(MODULE_HOTSPOT, Opcode::SMSG_HOTSPOT_LIST)
            .Add(count)
            .Add(list)
            .Send(player);
    }
    
    // Handler: Get specific hotspot info
    static void HandleGetInfo(Player* player, const ParsedMessage& msg)
    {
        uint32 hotspotId = msg.GetUInt32(0);
        
        QueryResult result = WorldDatabase.Query(
            "SELECT id, map_id, zone_id, x, y, z, "
            "(expire_time - UNIX_TIMESTAMP()) as dur "
            "FROM dc_hotspots_active "
            "WHERE id = {} AND expire_time > UNIX_TIMESTAMP()",
            hotspotId);
        
        if (!result)
        {
            Message(MODULE_HOTSPOT, Opcode::SMSG_HOTSPOT_INFO)
                .Add(0)  // not found
                .Add(hotspotId)
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
        
        Message(MODULE_HOTSPOT, Opcode::SMSG_HOTSPOT_INFO)
            .Add(1)  // found
            .Add(hotspotId)
            .Add(mapId)
            .Add(zoneId)
            .Add(zoneName)
            .Add(x)
            .Add(y)
            .Add(z)
            .Add(static_cast<uint32>(dur))
            .Add(xpBonus)
            .Send(player);
    }
    
    // Handler: Teleport to hotspot (GM only or with item)
    static void HandleTeleport(Player* player, const ParsedMessage& msg)
    {
        uint32 hotspotId = msg.GetUInt32(0);
        
        // Check if player has permission (GM level 1+ or special item)
        bool canTeleport = player->GetSession()->GetSecurity() >= SEC_MODERATOR;
        
        // Could also check for teleport item here
        // uint32 teleportItemId = sConfigMgr->GetOption<uint32>("Hotspot.TeleportItemId", 0);
        // if (teleportItemId > 0 && player->HasItemCount(teleportItemId, 1))
        //     canTeleport = true;
        
        if (!canTeleport)
        {
            Message(MODULE_HOTSPOT, Opcode::SMSG_TELEPORT_RESULT)
                .Add(0)  // failed
                .Add("No permission to teleport")
                .Send(player);
            return;
        }
        
        QueryResult result = WorldDatabase.Query(
            "SELECT map_id, x, y, z FROM dc_hotspots_active WHERE id = {} AND expire_time > UNIX_TIMESTAMP()",
            hotspotId);
        
        if (!result)
        {
            Message(MODULE_HOTSPOT, Opcode::SMSG_TELEPORT_RESULT)
                .Add(0)
                .Add("Hotspot not found or expired")
                .Send(player);
            return;
        }
        
        uint32 mapId = (*result)[0].Get<uint32>();
        float x = (*result)[1].Get<float>();
        float y = (*result)[2].Get<float>();
        float z = (*result)[3].Get<float>();
        
        player->TeleportTo(mapId, x, y, z, player->GetOrientation());
        
        Message(MODULE_HOTSPOT, Opcode::SMSG_TELEPORT_RESULT)
            .Add(1)  // success
            .Add(hotspotId)
            .Send(player);
    }
    
    // Broadcast hotspot spawn to all players
    void BroadcastHotspotSpawn(uint32 id, uint32 mapId, uint32 zoneId, 
                               const std::string& zoneName, float x, float y, 
                               uint32 duration, float bonus)
    {
        // Build message
        Message msg(MODULE_HOTSPOT, Opcode::SMSG_HOTSPOT_SPAWN);
        msg.Add(id);
        msg.Add(mapId);
        msg.Add(zoneId);
        msg.Add(zoneName);
        msg.Add(x);
        msg.Add(y);
        msg.Add(duration);
        msg.Add(bonus);
        
        // Send to all online players
        // This would need access to SessionMgr - for now placeholder
        // SessionMgr::Instance().DoForAllSessions([&msg](WorldSession* session) {
        //     if (Player* player = session->GetPlayer())
        //         msg.Send(player);
        // });
    }
    
    // Broadcast hotspot expiration
    void BroadcastHotspotExpire(uint32 id)
    {
        // Similar to spawn broadcast
        Message msg(MODULE_HOTSPOT, Opcode::SMSG_HOTSPOT_EXPIRE);
        msg.Add(id);
        
        // Send to all online players
    }
    
    // Register all handlers
    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(MODULE_HOTSPOT, Opcode::CMSG_GET_LIST, HandleGetList);
        DC_REGISTER_HANDLER(MODULE_HOTSPOT, Opcode::CMSG_GET_INFO, HandleGetInfo);
        DC_REGISTER_HANDLER(MODULE_HOTSPOT, Opcode::CMSG_TELEPORT, HandleTeleport);
        
        LOG_INFO("dc.addon", "Hotspot module handlers registered");
    }

}  // namespace Hotspot
}  // namespace DCAddon

void AddSC_dc_addon_hotspot()
{
    DCAddon::Hotspot::RegisterHandlers();
}
