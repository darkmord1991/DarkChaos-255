/*
 * GPS Test Command - DEBUG ONLY
 * 
 * Administrative command for testing GPS tracking functionality.
 * Manually triggers GPS update with detailed logging and diagnostics.
 * 
 * Security: SEC_MODERATOR (prevents player spam)
 * Usage: .gpstest
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "Config.h"
#include "DBCStores.h"
#include "MapExtensionConstants.h"
#include <sstream>
#include <iomanip>

#ifdef HAS_AIO
#include "AIO.h"
#endif

using namespace Acore::ChatCommands;
using namespace MapExtensionConstants;

// External map bounds from Hotspots system
extern std::unordered_map<uint32, std::array<float,4>> sMapBounds;

class cs_gps_test : public CommandScript
{
public:
    cs_gps_test() : CommandScript("cs_gps_test") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            { "gpstest", HandleGPSTestCommand, SEC_MODERATOR, Console::No }
        };
        return commandTable;
    }

    static bool HandleGPSTestCommand(ChatHandler* handler, const char* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
        {
            handler->PSendSysMessage("|cFFFF0000[GPS Test]|r ERROR: No player session found");
            return false;
        }

        uint32 mapId = player->GetMapId();
        uint32 zoneId = player->GetZoneId();
        uint32 areaId = player->GetAreaId();
        float x = player->GetPositionX();
        float y = player->GetPositionY();
        float z = player->GetPositionZ();
        float orientation = player->GetOrientation();

        handler->PSendSysMessage("|cFF00FF00=== GPS Test - Diagnostic Mode ===|r");
        handler->PSendSysMessage("Player: %s (GUID: %lu)", player->GetName().c_str(), player->GetGUID().GetCounter());
        handler->PSendSysMessage("Map: %u, Zone: %u, Area: %u", mapId, zoneId, areaId);
        handler->PSendSysMessage("Position: %.2f, %.2f, %.2f", x, y, z);
        handler->PSendSysMessage("Orientation: %.2f radians", orientation);

        // Check configuration
        bool systemEnabled = sConfigMgr->GetOption<bool>("MapExtension.Enable", true);
        uint32 updateInterval = sConfigMgr->GetOption<uint32>("MapExtension.UpdateInterval", GPS_UPDATE_INTERVAL_MS);
        std::string enabledMaps = sConfigMgr->GetOption<std::string>("MapExtension.EnabledMaps", "0,1,530,571,37");
        
        handler->PSendSysMessage("Config: Enabled=%s, UpdateInterval=%ums", systemEnabled ? "YES" : "NO", updateInterval);
        handler->PSendSysMessage("Config: EnabledMaps=%s", enabledMaps.c_str());

#ifdef HAS_AIO
        handler->PSendSysMessage("|cFF00FF00[GPS Test]|r AIO is ENABLED (HAS_AIO defined)");
#else
        handler->PSendSysMessage("|cFFFF0000[GPS Test]|r AIO is NOT ENABLED (HAS_AIO not defined)");
        handler->PSendSysMessage("|cFFFF0000[GPS Test]|r GPS system will NOT work without AIO!");
        return true;
#endif
        
        // Check map bounds availability
        auto boundsIt = sMapBounds.find(mapId);
        bool hasBounds = (boundsIt != sMapBounds.end());
        
        handler->PSendSysMessage("Map Bounds: %s", hasBounds ? "AVAILABLE (from DBC)" : "NOT FOUND");
        
        if (!hasBounds)
        {
            handler->PSendSysMessage("|cFFFF0000[GPS Test]|r No map bounds for map %u!", mapId);
            handler->PSendSysMessage("|cFFFF0000[GPS Test]|r Normalized coordinates will NOT be available");
            handler->PSendSysMessage("|cFFFF0000[GPS Test]|r Check WorldMapArea.dbc for this map");
        }
        
        // Calculate normalized coordinates
        float nx = 0.0f, ny = 0.0f;
        
        if (hasBounds)
        {
            auto const& b = boundsIt->second;
            float minX = b[0];
            float maxX = b[1];
            float minY = b[2];
            float maxY = b[3];
            
            handler->PSendSysMessage("Bounds: X[%.2f, %.2f] Y[%.2f, %.2f]", minX, maxX, minY, maxY);
            
            // Special case for Azshara Crater (map 37): Both axes are flipped
            if (mapId == 37)
            {
                nx = (maxX - x) / (maxX - minX);  // Flip X
                ny = (maxY - y) / (maxY - minY);  // Flip Y
                handler->PSendSysMessage("Using Azshara Crater bounds (BOTH AXES FLIPPED)");
            }
            else
            {
                nx = (x - minX) / (maxX - minX);
                ny = (y - minY) / (maxY - minY);
                handler->PSendSysMessage("Using standard coordinate normalization");
            }
            
            // Clamp to 0-1 range
            nx = std::max(0.0f, std::min(1.0f, nx));
            ny = std::max(0.0f, std::min(1.0f, ny));
            
            handler->PSendSysMessage("Normalized: %.3f, %.3f (%.1f%%, %.1f%%)", nx, ny, nx * 100, ny * 100);
        }
        
        // Enhanced data
        bool inCombat = player->IsInCombat();
        bool isMounted = player->IsMounted();
        bool isDead = !player->IsAlive();
        float speed = player->GetSpeed(MOVE_RUN);
        uint32 areaLevel = 0;
        
        if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(areaId))
        {
            areaLevel = area->area_level;
        }
        
        handler->PSendSysMessage("Status: Combat=%s, Mounted=%s, Dead=%s, Speed=%.2f, AreaLevel=%u",
            inCombat ? "YES" : "NO", isMounted ? "YES" : "NO", isDead ? "YES" : "NO", speed, areaLevel);
        
        // Build GPS payload (enhanced JSON)
        char buffer[MAX_GPS_PAYLOAD_BYTES];
        int written = std::snprintf(buffer, sizeof(buffer),
            "{\"mapId\":%u,\"zoneId\":%u,\"areaId\":%u,"
            "\"x\":%.2f,\"y\":%.2f,\"z\":%.2f,"
            "\"nx\":%.3f,\"ny\":%.3f,\"o\":%.2f,"
            "\"speed\":%.2f,\"combat\":%d,\"mounted\":%d,\"dead\":%d,\"areaLevel\":%u,"
            "\"hasCoords\":%d}",
            mapId, zoneId, areaId,
            x, y, z,
            nx, ny, orientation,
            speed, inCombat ? 1 : 0, isMounted ? 1 : 0, isDead ? 1 : 0, areaLevel,
            hasBounds ? 1 : 0
        );
        
        if (written < 0 || written >= (int)sizeof(buffer))
        {
            handler->PSendSysMessage("|cFFFF0000[GPS Test]|r ERROR: JSON payload buffer overflow!");
            return false;
        }
        
        std::string jsonData(buffer);
        handler->PSendSysMessage("JSON Payload (%lu bytes):", jsonData.size());
        handler->PSendSysMessage("%s", jsonData.c_str());
        
        if (jsonData.size() > MAX_GPS_PAYLOAD_BYTES)
        {
            handler->PSendSysMessage("|cFFFF0000[GPS Test]|r WARNING: Payload exceeds maximum size (%lu bytes)!",
                MAX_GPS_PAYLOAD_BYTES);
        }
        
        // Send via AIO
#ifdef HAS_AIO
        try {
            AIO().Msg(player, AIO_ADDON_NAME, AIO_MSG_UPDATE, jsonData);
            handler->PSendSysMessage("|cFF00FF00[GPS Test]|r GPS data sent via AIO successfully!");
            handler->PSendSysMessage("AIO Message: Addon='%s', Func='%s'", AIO_ADDON_NAME, AIO_MSG_UPDATE);
        } catch (std::exception const& e) {
            handler->PSendSysMessage("|cFFFF0000[GPS Test]|r AIO exception: %s", e.what());
        } catch (...) {
            handler->PSendSysMessage("|cFFFF0000[GPS Test]|r AIO threw unknown exception!");
        }
#endif

        handler->PSendSysMessage("|cFF00FF00=== GPS Test Complete ===|r");
        return true;
    }
};

void AddSC_cs_gps_test()
{
    new cs_gps_test();
}
