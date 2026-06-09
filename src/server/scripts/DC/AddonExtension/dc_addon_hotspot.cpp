/*
 * Dark Chaos - Hotspot Addon Module Handler
 * ==========================================
 *
 * Handles DC|SPOT|... messages for Hotspot XP bonus zones.
 * Integrates with ac_hotspots.cpp
 *
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "WorldSession.h"
#include "WorldPacket.h"
#include "Opcodes.h"
#include "Log.h"
#include "GameTime.h"
#include "DBCStores.h"
#include "World.h"
#include "WorldSessionMgr.h"
#include "../Hotspot/HotspotMgr.h"
#include <algorithm>

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

    // =======================================================================
    // Native transport bridge (CMSG_REQUEST_HOTSPOT / SMSG_HOTSPOT). Falls back
    // to the addon (chat) protocol when HOTSPOT_NATIVE is not negotiated. Both
    // request responses and spawn/expire broadcasts pick transport per-player.
    // =======================================================================
    namespace BridgeOpcode
    {
        enum : uint16
        {
            CMSG_REQUEST_HOTSPOT = ::CMSG_REQUEST_HOTSPOT,
            SMSG_HOTSPOT         = ::SMSG_HOTSPOT,
        };
    }

    static DCAddon::TransportPolicyDecision ResolveHotspotTransport(Player* player)
    {
        DCAddon::TransportPolicyRequest request;
        request.featureName = "hotspot";
        request.nativeCapability =
            DCAddon::ProtocolVersion::Capability::HOTSPOT_NATIVE;
        return DCAddon::ResolveTransportPolicy(player, request);
    }

    static void SendNativeHotspotPayload(Player* player, uint8 logicalOpcode,
        std::string const& payload)
    {
        if (!player || !player->GetSession() || payload.empty())
            return;

        WorldPacket data(BridgeOpcode::SMSG_HOTSPOT,
            sizeof(uint32) + payload.size() + 1);
        data << uint32(logicalOpcode);
        data << payload;
        player->GetSession()->SendPacket(&data);

        std::string preview = "logical="
            + std::to_string(static_cast<uint32>(logicalOpcode))
            + "|bytes=" + std::to_string(payload.size());
        DCAddon::LogNativeS2CMessage(player, MODULE_HOTSPOT, logicalOpcode,
            BridgeOpcode::SMSG_HOTSPOT, data.size(), preview, true, 0);
    }

    // Transport-aware send: native dedicated opcode when negotiated, else addon.
    static void SendHotspotMessage(Player* player,
        DCAddon::JsonMessage const& msg)
    {
        if (ResolveHotspotTransport(player).UsesNative())
        {
            SendNativeHotspotPayload(player, msg.GetOpcode(), msg.Encode());
            return;
        }

        msg.Send(player);
    }

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

    // Active hotspots sorted by id, expired entries dropped. (::Hotspot is the
    // global struct; unqualified it would resolve to this namespace.)
    static std::vector<::Hotspot> GetActiveHotspotsSorted()
    {
        std::vector<::Hotspot> active = sHotspotMgr->GetGrid().GetAll();
        time_t now = GameTime::GetGameTime().count();
        active.erase(std::remove_if(active.begin(), active.end(),
            [now](::Hotspot const& hotspot) { return hotspot.expireTime <= now; }),
            active.end());
        std::sort(active.begin(), active.end(),
            [](::Hotspot const& a, ::Hotspot const& b) { return a.id < b.id; });
        return active;
    }

    // List version: changes whenever the active set changes (spawn, expire,
    // admin clear). Lets clients poll cheaply -- a request echoing the current
    // version gets a tiny "unchanged" reply instead of the full list.
    static uint32 ComputeHotspotListVersion(std::vector<::Hotspot> const& hotspots)
    {
        uint32 version = 2166136261u;
        auto mix = [&version](uint32 value)
        {
            version ^= value;
            version *= 16777619u;
        };

        mix(static_cast<uint32>(hotspots.size()));
        for (::Hotspot const& hotspot : hotspots)
        {
            mix(hotspot.id);
            mix(static_cast<uint32>(hotspot.expireTime));
        }

        return version ? version : 1u;
    }

    // Handler: Get list of active hotspots (served from the in-memory grid;
    // no world-thread DB roundtrip).
    static void HandleGetList(Player* player, const ParsedMessage& msg)
    {
        std::vector<::Hotspot> active = GetActiveHotspotsSorted();
        uint32 version = ComputeHotspotListVersion(active);

        uint32 clientVersion = 0;
        if (IsJsonMessage(msg))
        {
            JsonValue json = GetJsonData(msg);
            if (json.IsObject() && json.HasKey("v"))
                clientVersion = json["v"].AsUInt32();
        }

        if (clientVersion && clientVersion == version)
        {
            SendHotspotMessage(player,
                JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_HOTSPOT_LIST)
                    .Set("unchanged", true)
                    .Set("v", version));
            return;
        }

        // Get XP bonus from config (same for all hotspots)
        uint32 xpBonus = GetHotspotXPBonusPercentage();
        time_t now = GameTime::GetGameTime().count();

        JsonValue hotspots; hotspots.SetArray();
        for (::Hotspot const& hotspot : active)
        {
            std::string zoneName = GetZoneNameFromDBC(hotspot.zoneId);
            hotspots.Push(BuildHotspotObject(hotspot.id, hotspot.mapId,
                hotspot.zoneId, zoneName, hotspot.x, hotspot.y, hotspot.z,
                static_cast<uint32>(hotspot.expireTime - now), xpBonus));
        }

        SendHotspotMessage(player,
            JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_HOTSPOT_LIST)
                .Set("hotspots", hotspots)
                .Set("v", version));
    }

    // Handler: Get specific hotspot info
    static void HandleGetInfo(Player* player, const ParsedMessage& msg)
    {
        uint32 hotspotId = ReadHotspotId(msg);
        if (!hotspotId)
        {
            SendHotspotMessage(player,
                JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_HOTSPOT_INFO)
                    .Set("found", false)
                    .Set("error", "Missing hotspot id"));
            return;
        }

        ::Hotspot const* hotspot = sHotspotMgr->GetGrid().GetById(hotspotId);
        time_t now = GameTime::GetGameTime().count();
        if (!hotspot || hotspot->expireTime <= now)
        {
            SendHotspotMessage(player,
                JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_HOTSPOT_INFO)
                    .Set("found", false)
                    .Set("id", hotspotId));
            return;
        }

        // Get XP bonus from config
        uint32 xpBonus = GetHotspotXPBonusPercentage();

        std::string zoneName = GetZoneNameFromDBC(hotspot->zoneId);

        JsonValue hs = BuildHotspotObject(hotspotId, hotspot->mapId,
            hotspot->zoneId, zoneName, hotspot->x, hotspot->y, hotspot->z,
            static_cast<uint32>(hotspot->expireTime - now), xpBonus);

        JsonMessage reply(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_HOTSPOT_INFO);
        reply.Set("found", true);
        // Flatten hotspot fields at top-level for legacy consumers.
        for (auto const& [k, v] : hs.AsObject())
            reply.Set(k, v);
        SendHotspotMessage(player, reply);
    }

    // Handler: Teleport to hotspot (GM only or with item)
    static void HandleTeleport(Player* player, const ParsedMessage& msg)
    {
        uint32 hotspotId = ReadHotspotId(msg);
        if (!hotspotId)
        {
            SendHotspotMessage(player,
                JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_TELEPORT_RESULT)
                    .Set("success", false)
                    .Set("error", "Missing hotspot id"));
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
            SendHotspotMessage(player,
                JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_TELEPORT_RESULT)
                    .Set("success", false)
                    .Set("id", hotspotId)
                    .Set("error", "No permission to teleport"));
            return;
        }

        ::Hotspot const* hotspot = sHotspotMgr->GetGrid().GetById(hotspotId);
        if (!hotspot || !hotspot->IsActive())
        {
            SendHotspotMessage(player,
                JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_TELEPORT_RESULT)
                    .Set("success", false)
                    .Set("id", hotspotId)
                    .Set("error", "Hotspot not found or expired"));
            return;
        }

        player->TeleportTo(hotspot->mapId, hotspot->x, hotspot->y, hotspot->z, player->GetOrientation());

        SendHotspotMessage(player,
            JsonMessage(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_TELEPORT_RESULT)
                .Set("success", true)
                .Set("id", hotspotId));
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
        sWorldSessionMgr->DoForAllOnlinePlayers([&msg](Player* player) {
            SendHotspotMessage(player, msg);
        });

        LOG_DEBUG("dc.addon", "Broadcast hotspot spawn: id={} map={} zone={}", id, mapId, zoneId);
    }

    // Broadcast hotspot expiration
    void BroadcastHotspotExpire(uint32 id)
    {
        JsonMessage msg(MODULE_HOTSPOT, Opcode::Hotspot::SMSG_HOTSPOT_EXPIRE);
        msg.Set("id", id);

        // Send to all online players
        sWorldSessionMgr->DoForAllOnlinePlayers([&msg](Player* player) {
            SendHotspotMessage(player, msg);
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

// Native transport receive hook: decodes CMSG_REQUEST_HOTSPOT and routes it
// through the shared MessageRouter so native and addon clients hit the same
// handlers. Responses pick their transport in SendHotspotMessage().
class HotspotNativeServerScript : public ServerScript
{
public:
    HotspotNativeServerScript()
        : ServerScript("HotspotNativeServerScript",
            { SERVERHOOK_CAN_PACKET_RECEIVE })
    {
    }

private:
    bool CanPacketReceive(WorldSession* session,
        WorldPacket const& packet) override
    {
        if (packet.GetOpcode()
            != DCAddon::Hotspot::BridgeOpcode::CMSG_REQUEST_HOTSPOT)
        {
            return true;
        }

        return DCAddon::HandleNativeModuleRequest(session, packet,
            DCAddon::Hotspot::BridgeOpcode::CMSG_REQUEST_HOTSPOT,
            DCAddon::Hotspot::MODULE_HOTSPOT);
    }
};

void AddSC_dc_addon_hotspot()
{
    DCAddon::Hotspot::RegisterHandlers();
    new HotspotNativeServerScript();
}
