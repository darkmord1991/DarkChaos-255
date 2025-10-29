/*
 * DC-MapExtension GPS System
 * Sends player coordinates for custom zones via AIO
 * Allows client addons to display accurate player position on custom maps
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Map.h"
#include "ScriptedCreature.h"
#include <sstream>
#include <iomanip>

#ifdef HAS_AIO
#include "AIO.h"
#endif

// Custom zone map IDs
constexpr uint32 AZSHARA_CRATER_MAP_ID = 37;  // Confirmed via .gps command
constexpr uint32 HYJAL_MAP_ID = 1;  // Kalimdor, but check zone ID

// Custom zone IDs (if using zone detection)
constexpr uint32 AZSHARA_CRATER_ZONE_ID = 268;
constexpr uint32 HYJAL_ZONE_ID = 616;

class dc_map_gps_worldscript : public WorldScript
{
public:
    dc_map_gps_worldscript() : WorldScript("dc_map_gps_worldscript") { }

    void OnUpdate(uint32 diff) override
    {
        _updateTimer += diff;
        
        // Send GPS updates every 2 seconds
        if (_updateTimer >= 2000)
        {
            _updateTimer = 0;
            BroadcastGPSUpdates();
        }
    }

private:
    uint32 _updateTimer = 0;

    void BroadcastGPSUpdates()
    {
#ifdef HAS_AIO
        // Iterate all players online
        SessionMap const& sessions = sWorld->GetAllSessions();
        for (SessionMap::const_iterator itr = sessions.begin(); itr != sessions.end(); ++itr)
        {
            if (Player* player = itr->second->GetPlayer())
            {
                if (!player->IsInWorld())
                    continue;

                uint32 mapId = player->GetMapId();
                uint32 zoneId = player->GetZoneId();
                
                // Only send GPS for custom zones
                bool isCustomZone = (mapId == AZSHARA_CRATER_MAP_ID) || 
                                   (mapId == HYJAL_MAP_ID && zoneId == HYJAL_ZONE_ID);
                
                if (!isCustomZone)
                    continue;

                // Get player position
                float x = player->GetPositionX();
                float y = player->GetPositionY();
                float z = player->GetPositionZ();
                
                // Normalize coordinates to 0-1 range for map display
                float nx = 0.0f, ny = 0.0f;
                
                if (mapId == AZSHARA_CRATER_MAP_ID)
                {
                    // Azshara Crater bounds: X roughly -1000 to 500, Y roughly -500 to 1500
                    const float minX = -1000.0f, maxX = 500.0f;
                    const float minY = -500.0f, maxY = 1500.0f;
                    nx = (x - minX) / (maxX - minX);
                    ny = (y - minY) / (maxY - minY);
                }
                else if (mapId == HYJAL_MAP_ID && zoneId == HYJAL_ZONE_ID)
                {
                    // Hyjal bounds (adjust as needed based on actual zone coordinates)
                    const float minX = -5000.0f, maxX = -3000.0f;
                    const float minY = -2000.0f, maxY = 0.0f;
                    nx = (x - minX) / (maxX - minX);
                    ny = (y - minY) / (maxY - minY);
                }
                
                // Clamp to 0-1 range
                nx = std::max(0.0f, std::min(1.0f, nx));
                ny = std::max(0.0f, std::min(1.0f, ny));
                
                // Build GPS payload
                std::ostringstream oss;
                oss << std::fixed << std::setprecision(3);
                oss << "{"
                    << "\"mapId\":" << mapId << ","
                    << "\"zoneId\":" << zoneId << ","
                    << "\"x\":" << x << ","
                    << "\"y\":" << y << ","
                    << "\"z\":" << z << ","
                    << "\"nx\":" << nx << ","
                    << "\"ny\":" << ny
                    << "}";
                
                // Send via AIO
                AIO().Msg(player, "DCMapGPS", "Update", oss.str());
            }
        }
#endif
    }
};

void AddSC_dc_map_gps()
{
    new dc_map_gps_worldscript();
}
