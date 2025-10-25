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
            { "dcrxp", HandleDCRXPCommand, SEC_GAMEMASTER, Console::No },
            { "dcxrp", HandleDCRXPCommand, SEC_GAMEMASTER, Console::No } // common typo alias
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
        // Normalize subcommand: lowercase and strip common punctuation so users
        // can use variants like "sendforce-self" or typos like "dcxrp" when
        // attempting subcommands. Do not modify the original arg list.
        std::string subNorm;
        subNorm.reserve(sub.size());
        for (char c : sub)
        {
            if (c == '-' || c == '_' || c == ' ') continue;
            subNorm.push_back(std::tolower(static_cast<unsigned char>(c)));
        }
    if (subNorm == "send")
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
        else if (subNorm == "sendforce" || subNorm == "sendforceself")
        {
            ++it;
            // If the subcommand included a "self" suffix (sendforce-self) we allow
            // omitting the target name and send to the GM's player directly.
            bool targetIsSelf = (subNorm.find("self") != std::string::npos);
            if (!targetIsSelf && it == args.end())
            {
                handler->PSendSysMessage("Usage: .dcrxp sendforce <playername>");
                handler->SetSentErrorMessage(true);
                return false;
            }
            Player* target = nullptr;
            if (targetIsSelf)
            {
                target = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
            }
            else
            {
                std::string playerName((*it).data(), (*it).size());
                target = ObjectAccessor::FindPlayerByName(playerName, false);
            }

            if (!target)
            {
                handler->PSendSysMessage("Player not found or invalid target.");
                handler->SetSentErrorMessage(true);
                return false;
            }

            // Immediately send a DCRXP addon packet to the player, bypassing any throttles.
            uint32 xp = target->GetUInt32Value(PLAYER_XP);
            uint32 xpMax = target->GetUInt32Value(PLAYER_NEXT_LEVEL_XP);
            uint32 level = target->GetLevel();
            SendXPAddonToPlayer(target, xp, xpMax, level);
            handler->PSendSysMessage("Force-sent DCRXP addon message to %s (xp=%u xpMax=%u level=%u)", playerName.c_str(), xp, xpMax, level);
            return true;
        }
    else if (subNorm == "grant")
        {
            // Expect: grant <playername> <amount>
            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dcrxp grant <playername> <amount>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string playerName((*it).data(), (*it).size());

            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dcrxp grant <playername> <amount>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string amountStr((*it).data(), (*it).size());
            uint64 amount = 0;
            try
            {
                amount = std::stoull(amountStr);
            }
            catch (...) { amount = 0; }

            if (amount == 0)
            {
                handler->PSendSysMessage("Invalid amount '%s'", amountStr.c_str());
                handler->SetSentErrorMessage(true);
                return false;
            }

            Player* receiver = ObjectAccessor::FindPlayerByName(playerName, false);
            if (!receiver)
            {
                handler->PSendSysMessage("Player '%s' not found.", playerName.c_str());
                handler->SetSentErrorMessage(true);
                return false;
            }

            // Give real XP via the server GiveXP path. Use nullptr victim and default rates.
            receiver->GiveXP(uint32(amount), nullptr, 1.0f, false);

            handler->PSendSysMessage("Granted %u XP to %s", uint32(amount), playerName.c_str());
            return true;
        }
    else if (subNorm == "grantself")
        {
            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dcrxp grantself <amount>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string amountStr((*it).data(), (*it).size());
            uint64 amount = 0;
            try
            {
                amount = std::stoull(amountStr);
            }
            catch (...) { amount = 0; }

            if (amount == 0)
            {
                handler->PSendSysMessage("Invalid amount '%s'", amountStr.c_str());
                handler->SetSentErrorMessage(true);
                return false;
            }

            Player* self = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
            if (!self)
            {
                handler->PSendSysMessage("Couldn't identify your player session.");
                handler->SetSentErrorMessage(true);
                return false;
            }

            self->GiveXP(uint32(amount), nullptr, 1.0f, false);
            handler->PSendSysMessage("Granted %u XP to yourself", uint32(amount));
            return true;
        }

    handler->PSendSysMessage("Unknown subcommand. Usage: .dcrxp send <playername> | sendforce <playername>|sendforce-self | grant <player> <amt> | grantself <amt>");
        handler->SetSentErrorMessage(true);
        return false;
    }
};

void AddSC_dcrxp_commandscript()
{
    new dcrxp_commandscript();
}
