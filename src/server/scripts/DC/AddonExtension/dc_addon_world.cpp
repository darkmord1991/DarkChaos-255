/*
 * Dark Chaos - World Content Addon Module Handler (WRLD)
 * ======================================================
 * Minimal aggregator for Hotspots, World Bosses, and Events
 * Returns JSON payloads for DC-InfoBar World tab and emits updates
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "WorldSession.h"
#include "WorldPacket.h"
#include "Opcodes.h"
#include "DBCStores.h"
#include "DBCStore.h"
#include "DBCStructure.h"
#include "GameTime.h"
#include "World.h"
#include "WorldState.h"
#include "Log.h"
#include "MapMgr.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"

#include "DC/CrossSystem/CrossSystemMapCoords.h"
#include "DC/CrossSystem/CrossSystemSpawnResolver.h"
#include "DC/CrossSystem/CrossSystemWorldBossMgr.h"

#include "dc_addon_world_bosses.h"
#include "dc_addon_death_markers.h"

#include <ctime>
#include <mutex>
#include <vector>

// Some builds comment out sWorldMapAreaStore in DBCStores.h, but still define it in DBCStores.cpp.
// Declare it here in the global namespace so we link against the correct symbol.
extern DBCStorage<WorldMapAreaEntry> sWorldMapAreaStore;

// Local includes to reuse hotspot helper functions
extern uint32 GetHotspotXPBonusPercentage();

// Worldstate IDs for Giant Isles invasion (used to detect active invasion state)
// These match values in dc_giant_isles_invasion.cpp
// constexpr uint32 WORLD_STATE_INVASION_ACTIVE = 20000;
// constexpr uint32 WORLD_STATE_INVASION_WAVE   = 20001;

namespace DCAddon
{
namespace World
{
    constexpr const char* MODULE_WORLD = Module::WORLD;
    constexpr int32 WORLD_SCHEMA_VERSION = 1;
    constexpr uint64 WORLD_CONTENT_CACHE_TTL_MS = 1000;

    // =======================================================================
    // Native transport bridge (CMSG_REQUEST_WORLD_CONTENT / SMSG_WORLD_CONTENT).
    // Falls back to the addon (chat) protocol when WORLD_NATIVE is not
    // negotiated. The native path avoids the 255-byte chunking the large world
    // content snapshot otherwise needs.
    // =======================================================================
    namespace BridgeOpcode
    {
        enum : uint16
        {
            CMSG_REQUEST_WORLD_CONTENT = ::CMSG_REQUEST_WORLD_CONTENT,
            SMSG_WORLD_CONTENT         = ::SMSG_WORLD_CONTENT,
        };
    }

    static DCAddon::TransportPolicyDecision ResolveWorldTransport(Player* player)
    {
        DCAddon::TransportPolicyRequest request;
        request.featureName = "world-content";
        request.nativeCapability =
            DCAddon::ProtocolVersion::Capability::WORLD_NATIVE;
        return DCAddon::ResolveTransportPolicy(player, request);
    }

    static void SendNativeWorldPayload(Player* player, uint8 logicalOpcode,
        std::string const& payload)
    {
        if (!player || !player->GetSession() || payload.empty())
            return;

        WorldPacket data(BridgeOpcode::SMSG_WORLD_CONTENT,
            sizeof(uint32) + payload.size() + 1);
        data << uint32(logicalOpcode);
        data << payload;
        player->GetSession()->SendPacket(&data);

        std::string preview = "logical="
            + std::to_string(static_cast<uint32>(logicalOpcode))
            + "|bytes=" + std::to_string(payload.size());
        DCAddon::LogNativeS2CMessage(player, MODULE_WORLD, logicalOpcode,
            BridgeOpcode::SMSG_WORLD_CONTENT, data.size(), preview, true, 0);
    }

    // Transport-aware send: native dedicated opcode when negotiated, else addon.
    static void SendWorldMessage(Player* player, DCAddon::JsonMessage const& msg)
    {
        if (ResolveWorldTransport(player).UsesNative())
        {
            SendNativeWorldPayload(player, msg.GetOpcode(), msg.Encode());
            return;
        }

        msg.Send(player);
    }

    struct CachedWorldContentPayload
    {
        std::string snapshotJson;
        std::vector<std::string> bossUpdateJsons;
        uint64 expiresAtMs = 0;
    };

    static std::mutex sWorldContentCacheLock;
    static CachedWorldContentPayload sCachedWorldContentPayload;

    // Helper: Build hotspots array using existing table
    static JsonValue BuildHotspotArray()
    {
        JsonValue arr; arr.SetArray();

        QueryResult result = WorldDatabase.Query(
            "SELECT id, map_id, zone_id, x, y, z, (expire_time - UNIX_TIMESTAMP()) as dur FROM dc_hotspots_active WHERE expire_time > UNIX_TIMESTAMP()"
        );

        uint32 xpBonus = GetHotspotXPBonusPercentage();

        if (!result)
            return arr;

        do
        {
            uint32 id = (*result)[0].Get<uint32>();
            uint32 mapId = (*result)[1].Get<uint32>();
            uint32 zoneId = (*result)[2].Get<uint32>();
            float x = (*result)[3].Get<float>();
            float y = (*result)[4].Get<float>();
            float z = (*result)[5].Get<float>();
            int64 dur = (*result)[6].Get<int64>();

            // Zone name via DBC
            std::string zoneName = "Unknown Zone";
            if (const AreaTableEntry* area = sAreaTableStore.LookupEntry(zoneId))
            {
                if (area->area_name[0] && area->area_name[0][0])
                    zoneName = area->area_name[0];
            }

            if (dur <= 0) continue;

            JsonValue h; h.SetObject();
            h.Set("id", JsonValue(id));
            h.Set("mapId", JsonValue(mapId));
            h.Set("zoneId", JsonValue(zoneId));
            h.Set("zoneName", JsonValue(zoneName));
            h.Set("x", JsonValue(x));
            h.Set("y", JsonValue(y));
            h.Set("z", JsonValue(z));
            h.Set("timeRemaining", JsonValue(static_cast<uint32>(dur)));
            h.Set("bonusPercent", JsonValue(xpBonus));
            h.Set("name", JsonValue("Hotspot"));
            arr.Push(h);
        } while (result->NextRow());

        return arr;
    }

    // Helper: Build events array (Stub for now)
    static JsonValue BuildEventsArray()
    {
        JsonValue arr; arr.SetArray();
        return arr;
    }

    static CachedWorldContentPayload BuildWorldContentPayload()
    {
        CachedWorldContentPayload payload;

        JsonValue hotspots = BuildHotspotArray();
        JsonValue bosses = sWorldBossMgr
            ? sWorldBossMgr->BuildBossesContentArray()
            : JsonValue();
        if (!bosses.IsArray())
            bosses.SetArray();
        JsonValue events = BuildEventsArray();
        JsonValue deaths = DCAddon::DeathMarkers::BuildDeathMarkersArray();

        JsonValue snapshot;
        snapshot.SetObject();
        snapshot.Set("schemaVersion", JsonValue(WORLD_SCHEMA_VERSION));
        snapshot.Set("serverTime", JsonValue(static_cast<uint32>(time(nullptr))));
        snapshot.Set("hotspots", hotspots);
        snapshot.Set("bosses", bosses);
        snapshot.Set("events", events);
        snapshot.Set("deaths", deaths);
        payload.snapshotJson = snapshot.Encode();

        if (bosses.IsArray())
        {
            for (auto const& boss : bosses.AsArray())
            {
                JsonValue one; one.SetArray();
                one.Push(boss);

                JsonValue update;
                update.SetObject();
                update.Set("bosses", one);
                payload.bossUpdateJsons.push_back(update.Encode());
            }
        }

        payload.expiresAtMs = static_cast<uint64>(
            GameTime::GetGameTimeMS().count()) + WORLD_CONTENT_CACHE_TTL_MS;
        return payload;
    }

    static CachedWorldContentPayload GetCachedWorldContentPayload()
    {
        uint64 const nowMs = static_cast<uint64>(
            GameTime::GetGameTimeMS().count());

        {
            std::lock_guard<std::mutex> lock(sWorldContentCacheLock);
            if (sCachedWorldContentPayload.expiresAtMs > nowMs)
                return sCachedWorldContentPayload;
        }

        CachedWorldContentPayload payload = BuildWorldContentPayload();

        std::lock_guard<std::mutex> lock(sWorldContentCacheLock);
        sCachedWorldContentPayload = payload;
        return payload;
    }

    void SendWorldContentSnapshot(Player* player)
    {
        CachedWorldContentPayload payload = GetCachedWorldContentPayload();

        JsonMessage response(Module::WORLD, Opcode::World::SMSG_CONTENT);
        response.SetPreEncodedJson(payload.snapshotJson);
        SendWorldMessage(player, response);

        // Compatibility / robustness:
        // Even with JSON chunking, some clients may fail to reassemble or may miss large snapshots.
        // Send each boss as a small SMSG_UPDATE payload so DC-InfoBar can always populate the list.
        for (std::string const& bossUpdateJson : payload.bossUpdateJsons)
        {
            JsonMessage upd(Module::WORLD, Opcode::World::SMSG_UPDATE);
            upd.SetPreEncodedJson(bossUpdateJson);
            SendWorldMessage(player, upd);
        }
    }

    // Handler: Client requests world content
    static void HandleGetContent(Player* player, const ParsedMessage& /*msg*/)
    {
        SendWorldContentSnapshot(player);
    }

    static void HandleResolveSpawn(Player* player, const ParsedMessage& msg)
    {
        using namespace DCAddon;

        JsonValue req = GetJsonData(msg);
        if (!req.IsObject())
        {
            JsonMessage err(Module::WORLD, Opcode::World::SMSG_RESOLVE_RESULT);
            err.Set("success", JsonValue(false));
            err.Set("error", JsonValue("bad_format"));
            SendWorldMessage(player, err);
            return;
        }

        uint32 entityId = req.HasKey("entityId") ? req["entityId"].AsUInt32() : 0;
        uint32 spawnId = req.HasKey("spawnId") ? req["spawnId"].AsUInt32() : 0;
        uint32 entry = req.HasKey("entry") ? req["entry"].AsUInt32() : 0;

        // Centralized spawn position resolution.
        // preferLive=true helps when the target is currently moving and loaded near the player.
        DarkChaos::CrossSystem::SpawnResolver::ResolvedPosition resolved = DarkChaos::CrossSystem::SpawnResolver::ResolveAny(
            DarkChaos::CrossSystem::SpawnResolver::Type::Creature, player, spawnId, entry, true);

        JsonMessage reply(Module::WORLD, Opcode::World::SMSG_RESOLVE_RESULT);
        reply.Set("entityId", JsonValue(entityId));
        reply.Set("spawnId", JsonValue(resolved.spawnId));
        reply.Set("entry", JsonValue(resolved.entry));

        if (!resolved.found)
        {
            reply.Set("success", JsonValue(false));
            reply.Set("error", JsonValue("not_found"));
            SendWorldMessage(player, reply);
            return;
        }

        // For client display, mapId is the server zone/area id (used to match client map views).
        reply.Set("success", JsonValue(true));
        uint32 mapKey = resolved.zoneId != 0 ? resolved.zoneId : resolved.areaId;
        reply.Set("mapId", JsonValue(static_cast<int32>(mapKey)));

        if (resolved.hasNormalized)
        {
            reply.Set("nx", JsonValue(resolved.nx));
            reply.Set("ny", JsonValue(resolved.ny));
        }
        else
        {
            reply.Set("error", JsonValue("no_bounds"));
        }

        SendWorldMessage(player, reply);
    }

    void RegisterHandlers()
    {
        DC_REGISTER_HANDLER(MODULE_WORLD, Opcode::World::CMSG_GET_CONTENT, HandleGetContent);
        DC_REGISTER_HANDLER(MODULE_WORLD, Opcode::World::CMSG_RESOLVE_SPAWN, HandleResolveSpawn);
        LOG_INFO("dc.addon", "World (WRLD) module handlers registered");
    }

} // namespace World
} // namespace DCAddon

// Native transport receive hook: decodes CMSG_REQUEST_WORLD_CONTENT and routes
// it through the shared MessageRouter so native and addon clients hit the same
// handlers. Responses pick their transport in SendWorldMessage().
class WorldContentNativeServerScript : public ServerScript
{
public:
    WorldContentNativeServerScript()
        : ServerScript("WorldContentNativeServerScript",
            { SERVERHOOK_CAN_PACKET_RECEIVE })
    {
    }

private:
    bool CanPacketReceive(WorldSession* session,
        WorldPacket const& packet) override
    {
        if (packet.GetOpcode()
            != DCAddon::World::BridgeOpcode::CMSG_REQUEST_WORLD_CONTENT)
        {
            return true;
        }

        return DCAddon::HandleNativeModuleRequest(session, packet,
            DCAddon::World::BridgeOpcode::CMSG_REQUEST_WORLD_CONTENT,
            DCAddon::World::MODULE_WORLD);
    }
};

void AddSC_dc_addon_world()
{
    DCAddon::World::RegisterHandlers();
    new WorldContentNativeServerScript();
}
