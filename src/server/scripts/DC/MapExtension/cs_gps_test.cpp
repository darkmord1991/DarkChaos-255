/*
 * GPS Test Command
 * Manually triggers GPS update for debugging
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include <sstream>
#include <iomanip>

#ifdef HAS_AIO
#include "AIO.h"
#endif

using namespace Acore::ChatCommands;

class cs_gps_test : public CommandScript
{
public:
    cs_gps_test() : CommandScript("cs_gps_test") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            { "gpstest", HandleGPSTestCommand, SEC_PLAYER, Console::No }
        };
        return commandTable;
    }

    static bool HandleGPSTestCommand(ChatHandler* handler, const char* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        uint32 mapId = player->GetMapId();
        uint32 zoneId = player->GetZoneId();
        float x = player->GetPositionX();
        float y = player->GetPositionY();
        float z = player->GetPositionZ();

        handler->PSendSysMessage("|cFF00FF00[GPS Test]|r Starting manual GPS test...");
        handler->PSendSysMessage("Map: %u, Zone: %u", mapId, zoneId);
        handler->PSendSysMessage("Position: %.2f, %.2f, %.2f", x, y, z);

#ifdef HAS_AIO
        handler->PSendSysMessage("|cFF00FF00[GPS Test]|r AIO is ENABLED");
        
        // Calculate normalized coordinates
        float nx = 0.0f, ny = 0.0f;
        
        if (mapId == 37) // Azshara Crater
        {
            const float minX = -1000.0f, maxX = 500.0f;
            const float minY = -500.0f, maxY = 1500.0f;
            nx = (x - minX) / (maxX - minX);
            ny = (y - minY) / (maxY - minY);
            handler->PSendSysMessage("Using Azshara Crater bounds");
        }
        else if (mapId == 1 && zoneId == 616) // Hyjal
        {
            const float minX = -5000.0f, maxX = -3000.0f;
            const float minY = -2000.0f, maxY = 0.0f;
            nx = (x - minX) / (maxX - minX);
            ny = (y - minY) / (maxY - minY);
            handler->PSendSysMessage("Using Hyjal bounds");
        }
        else
        {
            handler->PSendSysMessage("|cFFFF0000[GPS Test]|r Not in a custom zone!");
            return true;
        }
        
        // Clamp to 0-1 range
        nx = std::max(0.0f, std::min(1.0f, nx));
        ny = std::max(0.0f, std::min(1.0f, ny));
        
        handler->PSendSysMessage("Normalized: %.3f, %.3f (%.1f%%, %.1f%%)", nx, ny, nx * 100, ny * 100);
        
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
        
        std::string jsonData = oss.str();
        handler->PSendSysMessage("JSON: %s", jsonData.c_str());
        
        // Send via AIO
        try {
            AIO().Msg(player, "DCMapGPS", "Update", jsonData);
            handler->PSendSysMessage("|cFF00FF00[GPS Test]|r GPS data sent via AIO successfully!");
        } catch (...) {
            handler->PSendSysMessage("|cFFFF0000[GPS Test]|r AIO().Msg() threw an exception!");
        }
#else
        handler->PSendSysMessage("|cFFFF0000[GPS Test]|r AIO is NOT ENABLED (HAS_AIO not defined)");
        handler->PSendSysMessage("|cFFFF0000[GPS Test]|r GPS system will not work without AIO!");
#endif

        return true;
    }
};

void AddSC_cs_gps_test()
{
    new cs_gps_test();
}
