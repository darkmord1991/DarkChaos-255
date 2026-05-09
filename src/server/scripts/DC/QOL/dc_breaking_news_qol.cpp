#include "CommandScript.h"
#include "Chat.h"
#include "ScriptMgr.h"

#include "../AddonExtension/dc_addon_breaking_news.h"

using namespace Acore::ChatCommands;

namespace
{
    class dc_breaking_news_command_script : public CommandScript
    {
    public:
        dc_breaking_news_command_script()
            : CommandScript("dc_breaking_news_command_script")
        {
        }

        ChatCommandTable GetCommands() const override
        {
            static ChatCommandTable breakingNewsSubCommands =
            {
                ChatCommandBuilder("reload", HandleReloadCommand,
                    SEC_GAMEMASTER, Console::No),
                ChatCommandBuilder("status", HandleStatusCommand,
                    SEC_GAMEMASTER, Console::No),
                ChatCommandBuilder("push", HandlePushCommand,
                    SEC_GAMEMASTER, Console::No)
            };

            static ChatCommandTable commandTable =
            {
                ChatCommandBuilder("dcnews", breakingNewsSubCommands)
            };

            return commandTable;
        }

        static bool HandleReloadCommand(ChatHandler* handler,
            char const* /*args*/)
        {
            std::string errorMessage;
            if (!DCBreakingNews::Reload(true, &errorMessage))
            {
                handler->PSendSysMessage(
                    "Breaking news reload failed: {}", errorMessage);
                handler->SetSentErrorMessage(true);
                return false;
            }

            handler->SendSysMessage("Breaking news content reloaded.");
            return true;
        }

        static bool HandleStatusCommand(ChatHandler* handler,
            char const* /*args*/)
        {
            DCBreakingNews::Snapshot snapshot = DCBreakingNews::GetSnapshot();

            handler->PSendSysMessage(
                "Breaking news: enabled={} revision={} updatedAt={} format={} title='{}' bodyBytes={}",
                snapshot.enabled ? 1 : 0,
                snapshot.revision,
                snapshot.updatedAt,
                snapshot.format,
                snapshot.title,
                snapshot.body.size());
            return true;
        }

        static bool HandlePushCommand(ChatHandler* handler,
            char const* /*args*/)
        {
            if (!handler->GetSession())
            {
                handler->SendSysMessage(
                    "Breaking news push requires an in-game session.");
                handler->SetSentErrorMessage(true);
                return false;
            }

            if (!DCBreakingNews::SendToSession(handler->GetSession()))
            {
                handler->SendSysMessage(
                    "No breaking news payload was sent. Check enable flag and content file.");
                handler->SetSentErrorMessage(true);
                return false;
            }

            handler->SendSysMessage(
                "Breaking news packet sent to the current session.");
            return true;
        }
    };
}

void AddSC_dc_breaking_news_qol()
{
    new dc_breaking_news_command_script();
}