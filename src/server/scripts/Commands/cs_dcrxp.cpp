/*
 * Simple command to send a DCRXP addon whisper to a player.
 * Usage (GM): .dcrxp send <playername>
 */
#include "CommandScript.h"
#include "Chat.h"
#include "Player.h"
#include "ObjectAccessor.h"
#include "ScriptMgr.h"

// forward declaration of helper implemented in DC_AddonHelpers.cpp
void SendXPAddonToPlayer(Player* player, uint32 xp, uint32 xpMax, uint32 level);

using namespace Acore::ChatCommands;

class dcrxp_commandscript : public CommandScript
{
public:
    dcrxp_commandscript() : CommandScript("dcrxp_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            { "dcrxp", HandleDCRXPCommand, SEC_GAMEMASTER, Console::No }
        };
        return commandTable;
    }

    static bool HandleDCRXPCommand(ChatHandler* handler, std::vector<std::string_view> args)
    {
        if (args.empty())
        {
            handler->PSendSysMessage("Usage: .dcrxp send <playername>");
            handler->SetSentErrorMessage(true);
            return false;
        }

        auto it = args.begin();
        std::string_view sub = *it;
        if (sub == "send")
        {
            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dcrxp send <playername>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string playerName((*it).data(), (*it).size());
            Player* target = ObjectAccessor::FindPlayerByName(playerName, false);
            if (!target)
            {
                handler->PSendSysMessage("Player '%s' not found.", playerName.c_str());
                handler->SetSentErrorMessage(true);
                return false;
            }

            // send current server-side XP info for that player
            uint32 xp = target->GetUInt32Value(PLAYER_XP);
            uint32 xpMax = target->GetUInt32Value(PLAYER_NEXT_LEVEL_XP);
            uint32 level = target->GetLevel();

            SendXPAddonToPlayer(target, xp, xpMax, level);
            handler->PSendSysMessage("Sent DCRXP addon message to %s (xp=%u xpMax=%u level=%u)", playerName.c_str(), xp, xpMax, level);
            return true;
        }

        handler->PSendSysMessage("Unknown subcommand. Usage: .dcrxp send <playername>");
        handler->SetSentErrorMessage(true);
        return false;
    }
};

void AddSC_dcrxp_commandscript()
{
    new dcrxp_commandscript();
}
