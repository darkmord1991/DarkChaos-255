/*
 * AzerothCore Command Script: .faq (faq_commandscript)
 *
 * Purpose / Feature Overview:
 * - Provides an in-game FAQ command with multiple subtopics for players.
 * - Default invocation `.faq` shows a compact help list (4 topics per line).
 * - Subcommands send short guidance via notification + chat to the invoker.
 *
 * Command names:
 * - .faq help | (no args)
 * - .faq buff | .faq discord | .faq dungeons | .faq hinterland
 * - .faq leveling | .faq maxlevel | .faq progression | .faq source
 * - .faq t11 | .faq t12 | .faq teleporter
 *
 * Script names and integration:
 * - Class: faq_commandscript (CommandScript)
 * - Registration: AddSC_faq_commandscript() (wired in Commands/cs_script_loader.cpp)
 * - DB: No ScriptName needed; CommandScripts are loaded globally via the loader.
 *
 * Notes:
 * - The `discord` topic currently sends a placeholder string; replace with your invite.
 * - All messages are intentionally concise; expand with PSendSysMessage if needed.
 */
#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include <string>

using namespace Acore::ChatCommands;

namespace
{
    // Forward declaration so it can be referenced by HandleFaqNoArg
    static bool HandleFaqHelp(ChatHandler* handler, char const* args);

    inline void NotifyAndChat(ChatHandler* handler, char const* msg)
    {
        if (!handler || !msg || !*msg)
            return;
        handler->SendNotification(msg);
        handler->SendSysMessage(msg);
    }

    static void PrintFaqList(ChatHandler* handler)
    {
        if (!handler)
            return;
        static char const* topics[] = {
            "buff", "leveling", "teleporter", "source",
            "progression", "discord", "maxlevel", "hinterland",
            "dungeons", "t11", "t12"
        };

        handler->SendSysMessage("This is a list of all commands related to FAQ. - use .faq <topic>");

        std::string line = " - ";
        int perLine = 0;
        for (char const* t : topics)
        {
            if (perLine > 0)
                line += "    "; // spacer between entries
            line += t;
            ++perLine;
            if (perLine == 4)
            {
                handler->SendSysMessage(line);
                line = " - ";
                perLine = 0;
            }
        }
        if (perLine != 0 && line.size() > 3)
            handler->SendSysMessage(line);
    }

    static bool HandleFaqNoArg(ChatHandler* handler, char const* /*args*/)
    {
        // Default: show help
        return HandleFaqHelp(handler, "");
    }

    static bool HandleFaqHelp(ChatHandler* handler, char const* /*args*/)
    {
        PrintFaqList(handler);
        return true;
    }

    static bool HandleFaqBuff(ChatHandler* handler, char const* /*args*/)
    {
        NotifyAndChat(handler, "Use .buff to get some buffs anywhere you are!");
        return true;
    }

    static bool HandleFaqDiscord(ChatHandler* handler, char const* /*args*/)
    {
        // TODO: Replace PLACEHOLDER with your actual Discord invite or URL
        NotifyAndChat(handler, "PLACEHOLDER");
        return true;
    }

    static bool HandleFaqDungeons(ChatHandler* handler, char const* /*args*/)
    {
        NotifyAndChat(handler, "We have some custom dungeons in place - more to come!");
        handler->PSendSysMessage("The Nexus - Level 100");
        handler->PSendSysMessage("The Oculus - Level 100");
        handler->PSendSysMessage("Gundrak - Level 130");
        handler->PSendSysMessage("AhnCahet - Level 130");
        handler->PSendSysMessage("Auchenai Crypts - Level 160");
        handler->PSendSysMessage("Mana Tombs - Level 160");
        handler->PSendSysMessage("Sethekk Halls - Level 160");
        handler->PSendSysMessage("Shadow Labyrinth - Level 160");
        return true;
    }

    static bool HandleFaqHinterland(ChatHandler* handler, char const* /*args*/)
    {
        NotifyAndChat(handler, "The Hinterland Battleground is an open battlefield for the current set maxlevel, with some special scripts, quests, events and more! Can be accessed by our teleporters!");
        return true;
    }

    static bool HandleFaqLeveling(ChatHandler* handler, char const* /*args*/)
    {
        NotifyAndChat(handler, "Please use the (mobile) teleporters to navigate to the correct leveling zone location.");
        return true;
    }

    static bool HandleFaqMaxLevel(ChatHandler* handler, char const* /*args*/)
    {
        NotifyAndChat(handler, "The current Max Level is set to 80!");
        return true;
    }

    static bool HandleFaqProgression(ChatHandler* handler, char const* /*args*/)
    {
        NotifyAndChat(handler, "Right now Max Level is set to 80! It will be extended to the next progression step soon.");
        return true;
    }

    static bool HandleFaqSource(ChatHandler* handler, char const* /*args*/)
    {
        NotifyAndChat(handler, "The sourcecode and full changelog can be found under https://github.com/darkmord1991/DarkChaos-255.");
        return true;
    }

    static bool HandleFaqT11(ChatHandler* handler, char const* /*args*/)
    {
        NotifyAndChat(handler, "For T11 you need 2500 tokens for each Tier 11 item.");
        return true;
    }

    static bool HandleFaqT12(ChatHandler* handler, char const* /*args*/)
    {
        NotifyAndChat(handler, "For T12 you need 7500 tokens for each Tier 12 item.");
        return true;
    }

    static bool HandleFaqTeleporter(ChatHandler* handler, char const* /*args*/)
    {
        NotifyAndChat(handler, "You can use a mobile teleporter with your pet or use the ones standing around everywhere.");
        return true;
    }
}

class faq_commandscript : public CommandScript
{
public:
    faq_commandscript() : CommandScript("faq_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable faqSubTable =
        {
            { "help",       HandleFaqHelp,       SEC_PLAYER, Console::No },
            { "buff",       HandleFaqBuff,       SEC_PLAYER, Console::No },
            { "discord",    HandleFaqDiscord,    SEC_PLAYER, Console::No },
            { "dungeons",   HandleFaqDungeons,   SEC_PLAYER, Console::No },
            { "hinterland", HandleFaqHinterland, SEC_PLAYER, Console::No },
            { "leveling",   HandleFaqLeveling,   SEC_PLAYER, Console::No },
            { "maxlevel",   HandleFaqMaxLevel,   SEC_PLAYER, Console::No },
            { "progression",HandleFaqProgression,SEC_PLAYER, Console::No },
            { "source",     HandleFaqSource,     SEC_PLAYER, Console::No },
            { "t11",        HandleFaqT11,        SEC_PLAYER, Console::No },
            { "t12",        HandleFaqT12,        SEC_PLAYER, Console::No },
            { "teleporter", HandleFaqTeleporter, SEC_PLAYER, Console::No },
            { "",           HandleFaqNoArg,      SEC_PLAYER, Console::No }, // .faq -> help
        };

        static ChatCommandTable commandTable =
        {
            { "faq", faqSubTable }
        };

        return commandTable;
    }
};

void AddSC_faq_commandscript()
{
    new faq_commandscript();
}
