/*
 * Consolidated DC addon-related commands.
 *
 * Commands (single entry: .dc):
 *  - .dc send <playername>
 *      Send the current server XP snapshot to <playername> (addon-style whisper)
 *  - .dc sendforce <playername> | .dc sendforce-self
 *      Force-send the current server XP snapshot, bypassing throttles. Use -self to target yourself.
 *  - .dc grant <playername> <amount>
 *      Grant <amount> XP to <playername> using server GiveXP path.
 *  - .dc grantself <amount>
 *      Grant <amount> XP to your own character.
 *  - .dc givexp <playername> <amount>  (alias form exposed via .dc)
 *  - .dc givexp self <amount>
 *
 * Examples:
 *  .dc send Alice
 *  .dc sendforce-self
 *  .dc grant Bob 100000
 *  .dc givexp self 50000
 *
 * Notes:
 *  - This file consolidates DC-related GM commands into a single top-level command
 *    (".dc") to keep addon administration in one place. After changing this C++ file
 *    you must rebuild the server so the command is compiled and registered.
 */
#include "CommandScript.h"
#include "Chat.h"
#include "Player.h"
#include "ObjectAccessor.h"
#include "ScriptMgr.h"

// forward declaration of helper implemented in DC_AddonHelpers.cpp
void SendXPAddonToPlayer(Player* player, uint32 xp, uint32 xpMax, uint32 level);

using namespace Acore::ChatCommands;

class dc_addons_commandscript : public CommandScript
{
public:
    dc_addons_commandscript() : CommandScript("dc_addons_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            // Single consolidated entry: .dc <subcommand> ...
            { "dc", HandleDCRXPCommand, SEC_GAMEMASTER, Console::No }
        };
        return commandTable;
    }

    // DCRXP commands (send, sendforce, grant, grantself)
    static bool HandleDCRXPCommand(ChatHandler* handler, std::vector<std::string_view> args)
    {
        if (args.empty())
        {
            handler->PSendSysMessage("Usage: .dc send <playername> | sendforce <playername>|sendforce-self | grant <player> <amt> | grantself <amt> | givexp <player|self> <amt>");
            handler->SetSentErrorMessage(true);
            return false;
        }

        auto it = args.begin();
        std::string_view sub = *it;
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
                handler->PSendSysMessage("Usage: .dc send <playername>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string playerName((*it).data(), (*it).size());
            Player* target = ObjectAccessor::FindPlayerByName(playerName, false);
            if (!target)
            {
                handler->PSendSysMessage("Player '{}' not found.", playerName);
                handler->SetSentErrorMessage(true);
                return false;
            }

            uint32 xp = target->GetUInt32Value(PLAYER_XP);
            uint32 xpMax = target->GetUInt32Value(PLAYER_NEXT_LEVEL_XP);
            uint32 level = target->GetLevel();
            SendXPAddonToPlayer(target, xp, xpMax, level);
            handler->PSendSysMessage("Sent DCRXP addon message to {} (xp={} xpMax={} level={})", playerName, xp, xpMax, level);
            return true;
        }

        if (subNorm == "sendforce" || subNorm == "sendforceself")
        {
            ++it;
            bool targetIsSelf = (subNorm.find("self") != std::string::npos);
            if (!targetIsSelf && it == args.end())
            {
                handler->PSendSysMessage("Usage: .dc sendforce <playername>");
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

            uint32 xp = target->GetUInt32Value(PLAYER_XP);
            uint32 xpMax = target->GetUInt32Value(PLAYER_NEXT_LEVEL_XP);
            uint32 level = target->GetLevel();
            SendXPAddonToPlayer(target, xp, xpMax, level);
            handler->PSendSysMessage("Force-sent DCRXP addon message to {} (xp={} xpMax={} level={})", target->GetName(), xp, xpMax, level);
            return true;
        }

        if (subNorm == "grant")
        {
            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dc grant <playername> <amount>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string playerName((*it).data(), (*it).size());
            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dc grant <playername> <amount>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string amountStr((*it).data(), (*it).size());
            uint64 amount = 0;
            try { amount = std::stoull(amountStr); } catch (...) { amount = 0; }
            if (amount == 0)
            {
                handler->PSendSysMessage("Invalid amount '{}'", amountStr);
                handler->SetSentErrorMessage(true);
                return false;
            }

            Player* receiver = ObjectAccessor::FindPlayerByName(playerName, false);
            if (!receiver)
            {
                handler->PSendSysMessage("Player '{}' not found.", playerName);
                handler->SetSentErrorMessage(true);
                return false;
            }

            uint32 beforeXP = receiver->GetUInt32Value(PLAYER_XP);
            receiver->GiveXP(uint32(amount), nullptr, 1.0f, false);
            uint32 afterXP = receiver->GetUInt32Value(PLAYER_XP);
            if (afterXP == beforeXP)
            {
                handler->PSendSysMessage("No XP applied to {} (maybe at max level or XP blocked). Current xp={} xpMax={}", playerName, afterXP, receiver->GetUInt32Value(PLAYER_NEXT_LEVEL_XP));
            }
            else
            {
                // Immediately send an addon snapshot so client can update right away
                SendXPAddonToPlayer(receiver, afterXP, receiver->GetUInt32Value(PLAYER_NEXT_LEVEL_XP), receiver->GetLevel());
                handler->PSendSysMessage("Granted {} XP to {} (now xp={} xpMax={})", uint32(amount), playerName, afterXP, receiver->GetUInt32Value(PLAYER_NEXT_LEVEL_XP));
            }
            return true;
        }

        if (subNorm == "grantself")
        {
            ++it;
            if (it == args.end())
            {
                handler->PSendSysMessage("Usage: .dc grantself <amount>");
                handler->SetSentErrorMessage(true);
                return false;
            }

            std::string amountStr((*it).data(), (*it).size());
            uint64 amount = 0;
            try { amount = std::stoull(amountStr); } catch (...) { amount = 0; }
            if (amount == 0)
            {
                handler->PSendSysMessage("Invalid amount '{}'", amountStr);
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

            Player* selfPlayer = self;
            uint32 beforeSelfXP = selfPlayer->GetUInt32Value(PLAYER_XP);
            selfPlayer->GiveXP(uint32(amount), nullptr, 1.0f, false);
            uint32 afterSelfXP = selfPlayer->GetUInt32Value(PLAYER_XP);
            if (afterSelfXP == beforeSelfXP)
            {
                handler->PSendSysMessage("No XP applied to yourself (maybe at max level or XP blocked). Current xp={} xpMax={}", afterSelfXP, selfPlayer->GetUInt32Value(PLAYER_NEXT_LEVEL_XP));
            }
            else
            {
                SendXPAddonToPlayer(selfPlayer, afterSelfXP, selfPlayer->GetUInt32Value(PLAYER_NEXT_LEVEL_XP), selfPlayer->GetLevel());
                handler->PSendSysMessage("Granted {} XP to yourself (now xp={} xpMax={})", uint32(amount), afterSelfXP, selfPlayer->GetUInt32Value(PLAYER_NEXT_LEVEL_XP));
            }
            return true;
        }

        handler->PSendSysMessage("Unknown subcommand. Usage: .dc send <playername> | sendforce <playername>|sendforce-self | grant <player> <amt> | grantself <amt> | givexp <player|self> <amt>");
        handler->SetSentErrorMessage(true);
        return false;
    }

    // Givexp handler: .givexp <playername>|self <amount>
    static bool HandleGiveXPCommand(ChatHandler* handler, std::vector<std::string_view> args)
    {
        if (args.empty())
        {
            handler->PSendSysMessage("Usage: .givexp <playername> <amount>  OR  .givexp self <amount>");
            handler->SetSentErrorMessage(true);
            return false;
        }

        auto it = args.begin();
        std::string_view first = *it;
        Player* target = nullptr;

        if (first == "self")
        {
            ++it;
            target = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
            if (!target)
            {
                handler->PSendSysMessage("Couldn't identify your player session.");
                handler->SetSentErrorMessage(true);
                return false;
            }
        }
        else
        {
            std::string targetName(first.data(), first.size());
            ++it;
            target = ObjectAccessor::FindPlayerByName(targetName, false);
            if (!target)
            {
                handler->PSendSysMessage("Player '%s' not found.", targetName.c_str());
                handler->SetSentErrorMessage(true);
                return false;
            }
        }

        if (it == args.end())
        {
            handler->PSendSysMessage("Usage: .givexp <playername> <amount>  OR  .givexp self <amount>");
            handler->SetSentErrorMessage(true);
            return false;
        }

        std::string amountStr((*it).data(), (*it).size());
        uint64 amount = 0;
        try { amount = std::stoull(amountStr); } catch (...) { amount = 0; }
        if (amount == 0)
        {
            handler->PSendSysMessage("Invalid amount '%s'", amountStr.c_str());
            handler->SetSentErrorMessage(true);
            return false;
        }

    target->GiveXP(uint32(amount), nullptr, 1.0f, false);
    // after GiveXP, send snapshot so client updates immediately (grant via .givexp alias)
    uint32 curXP = target->GetUInt32Value(PLAYER_XP);
    uint32 nextXP = target->GetUInt32Value(PLAYER_NEXT_LEVEL_XP);
    SendXPAddonToPlayer(target, curXP, nextXP, target->GetLevel());
    handler->PSendSysMessage("Granted {} XP to {}", uint32(amount), target->GetName());
        return true;
    }
};

void AddSC_dc_addons_commandscript()
{
    new dc_addons_commandscript();
    LOG_INFO("scripts.dc_addons", "dc_addons command script registered");
}
