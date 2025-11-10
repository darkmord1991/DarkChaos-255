#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include "World.h"
#include "ac_flightmasters_path.h"
#include <sstream>

using namespace Acore::ChatCommands;

class flighthelper_commandscript : public CommandScript
{
public:
    flighthelper_commandscript() : CommandScript("flighthelper_commandscript") {}

    ChatCommandTable GetCommands() const override
    {
        // Nested subtables must persist for the lifetime of the command tree. Keep them in
        // named statics instead of temporary initializer lists to avoid dangling references.
        static ChatCommandTable flighthelperSubTable =
        {
            { "path", HandlePathCommand, SEC_GAMEMASTER, Console::Yes },
        };

        static ChatCommandTable table =
        {
            { "flighthelper", flighthelperSubTable },
        };
        return table;
    }

    static bool HandlePathCommand(ChatHandler* handler, Optional<std::string> args)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player || !player->IsGameMaster())
            return true;

        if (!args)
        {
            handler->PSendSysMessage("Usage: .flighthelper path <x> <y> <z>");
            return true;
        }

        std::istringstream iss(args.value());
        float x, y, z;
        if (!(iss >> x >> y >> z))
        {
            handler->PSendSysMessage("Invalid coordinates. Usage: .flighthelper path <x> <y> <z>");
            return true;
        }

        Position dest(x, y, z, 0.0f);
        std::vector<Position> path;
        if (FlightPathHelper::CalculateSmartPathForObject(player, dest, path) && !path.empty())
        {
            handler->PSendSysMessage("FlightHelper: path found with {} points.", (uint32)path.size());
            for (auto const& p : path)
            {
                player->SummonCreature(VISUAL_WAYPOINT, p.GetPositionX(), p.GetPositionY(), p.GetPositionZ(), 0.0f, TEMPSUMMON_TIMED_DESPAWN, 9000);
            }
        }
        else
        {
            handler->PSendSysMessage("FlightHelper: no path found to ({}, {}, {}).", x, y, z);
        }

        return true;
    }
};

void AddSC_flighthelper_test()
{
    new flighthelper_commandscript();
}
