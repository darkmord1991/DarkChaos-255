/*
 * Dark Chaos - Client lab probe relay (GM / lab only, read-only)
 * ==============================================================
 *
 * Lets a GM, the console or a SOAP client ask the DC-LabProbe addon of a
 * running lab client for a read-only UI fact (frame state and text, tooltip
 * lines, auras, target, CVars, addon versions, BugGrabber errors) without a
 * /reload. Re-implemented after Ascension CoA's probe relay
 * (docs/coa/client-lab-probe-relay.md), but on the DC addon protocol.
 *
 * Wire (DC addon protocol, module LABP, addon transport on both clients):
 *   S2C LABP|16|J|{"id":"<10 hex>","req":{"cmd":"frame","names":["PlayerFrame"]}}
 *   C2S LABP|1|J|{"id":"<10 hex>","i":<1..n>,"n":<1..128>,"d":"<base64, <=192 decoded bytes>"}
 * The addon base64-encodes slices of its JSON answer and paces them behind
 * the protocol's send throttle; the server keeps chunks only for requests it
 * sent to that same player, and reassembles them in index order.
 *
 * Commands (SEC_ADMINISTRATOR, console and SOAP):
 *   .dca probe send <character> <request-json>   -> "sent <id>"
 *   .dca probe result <id>                       -> "unknown" | "pending <got>/<total>"
 *                                                   | "abandoned" | "complete <base64 JSON>"
 *   .dca probe list                              -> one line per live request
 * In game, "result" prints the JSON itself instead of base64.
 *
 * Config (all off by default):
 *   DC.LabProbe.Enable            = 0
 *   DC.LabProbe.Accounts          = ""    account names that may be probed
 *   DC.LabProbe.ResultTtlSeconds  = 300
 *   DC.LabProbe.MaxResultBytes    = 16384
 *
 * Safety: off by default; administrators only; only accounts listed in
 * DC.LabProbe.Accounts can be probed; read-only allowlist on both ends (the
 * server refuses any other "cmd", the addon answers only its own list); no
 * memory access, no code execution, ordinary addon messages only.
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_lab_probe_core.h"
#include "AccountMgr.h"
#include "Base64.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Config.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "Timer.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include <chrono>
#include <mutex>

namespace DCLabProbe
{
    using namespace Acore::ChatCommands;

    namespace
    {
        std::mutex s_mutex;
        ResultBook s_book;
        bool s_enabled = false;
        std::vector<std::string> s_accounts;
        uint32 s_counter = 0;

        // In-game "result" output: chat lines of at most this many bytes.
        constexpr std::size_t ChatLineBytes = 240;
        constexpr std::size_t ChatMaxLines = 40;

        // Always the (string_view, bool) overload: a literal would otherwise
        // pick the printf-style template and pass `false` as a format argument.
        void Refuse(ChatHandler* handler, std::string_view message)
        {
            handler->SendErrorMessage(message, false);
        }

        uint64 NowMs()
        {
            return static_cast<uint64>(std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now().time_since_epoch()).count());
        }

        void LoadConfig()
        {
            bool const enabled = sConfigMgr->GetOption<bool>("DC.LabProbe.Enable", false);
            std::string const accounts = sConfigMgr->GetOption<std::string>("DC.LabProbe.Accounts", "");
            uint32 const ttlSeconds = sConfigMgr->GetOption<uint32>("DC.LabProbe.ResultTtlSeconds", 300);
            uint32 const maxBytes = sConfigMgr->GetOption<uint32>("DC.LabProbe.MaxResultBytes", 16384);

            std::size_t accountCount = 0;
            {
                std::lock_guard lock(s_mutex);
                s_enabled = enabled;
                s_accounts = ParseAccountList(accounts);
                accountCount = s_accounts.size();
                s_book.Configure(uint64(ttlSeconds) * 1000, std::min<uint32>(maxBytes, MaxChunks * MaxChunkBytes));
            }

            DCAddon::MessageRouter::Instance().SetModuleEnabled(MODULE, enabled);

            if (enabled)
                LOG_INFO("module.dc", "[LabProbe] enabled for {} account(s)", accountCount);
        }

        std::string NextRequestId()
        {
            uint64 const value = (uint64(rand32() & 0xFFFFF) << 20) | (++s_counter & 0xFFFFF);
            return Acore::StringFormat("{:010x}", value);
        }

        // A clean copy of the request with only allowlisted keys and safe
        // values; false (and `error`) when anything does not fit.
        bool BuildRequest(DCAddon::JsonValue const& input, DCAddon::JsonValue& out, std::string& command,
            std::string& error)
        {
            if (!input.IsObject())
            {
                error = "the request must be a JSON object";
                return false;
            }

            DCAddon::JsonValue const& cmd = input["cmd"];
            if (!cmd.IsString() || !IsReadOnlyCommand(cmd.AsString()))
            {
                error = "not a read-only probe request "
                    "(cmd: ping state frame tooltip auras target cvars addons errors)";
                return false;
            }

            out.SetObject();
            for (auto const& [key, value] : input.AsObject())
            {
                if (!IsAllowedRequestKey(key))
                {
                    error = "key not allowed: " + key.substr(0, 32);
                    return false;
                }

                if (value.IsString())
                {
                    if (!IsSafeRequestString(value.AsString()))
                    {
                        error = "value of '" + key + "' must be 1-96 chars of A-Z a-z 0-9 _ : . -";
                        return false;
                    }

                    out.Set(key, DCAddon::JsonValue(value.AsString()));
                }
                else if (value.IsNumber())
                {
                    double const number = value.AsNumber();
                    if (!(number >= 0.0 && number <= 1000.0))
                    {
                        error = "number of '" + key + "' must be 0-1000";
                        return false;
                    }

                    out.Set(key, DCAddon::JsonValue(static_cast<uint32>(number)));
                }
                else if (value.IsArray())
                {
                    if (value.Size() == 0 || value.Size() > MaxRequestArrayItems)
                    {
                        error = "array '" + key + "' must hold 1-32 strings";
                        return false;
                    }

                    DCAddon::JsonValue list;
                    list.SetArray(value.Size());
                    for (DCAddon::JsonValue const& item : value.AsArray())
                    {
                        if (!item.IsString() || !IsSafeRequestString(item.AsString()))
                        {
                            error = "array '" + key + "' must hold 1-32 strings of A-Z a-z 0-9 _ : . -";
                            return false;
                        }

                        list.Push(DCAddon::JsonValue(item.AsString()));
                    }

                    out.Set(key, std::move(list));
                }
                else
                {
                    error = "unsupported value type for '" + key + "'";
                    return false;
                }
            }

            if (out.Encode().size() > MaxRequestBytes)
            {
                error = Acore::StringFormat("request too long (max {} bytes encoded)", MaxRequestBytes);
                return false;
            }

            command = cmd.AsString();
            return true;
        }

        // C2S LABP|1: one base64 chunk of an answer.
        void HandleAnswerChunk(Player* player, DCAddon::ParsedMessage const& msg)
        {
            if (!player)
                return;

            DCAddon::JsonValue const json = DCAddon::GetJsonData(msg);
            if (!json.IsObject())
                return;

            DCAddon::JsonValue const& id = json["id"];
            DCAddon::JsonValue const& index = json["i"];
            DCAddon::JsonValue const& total = json["n"];
            DCAddon::JsonValue const& data = json["d"];
            if (!id.IsString() || !IsRequestId(id.AsString()) || !index.IsNumber() || !total.IsNumber()
                || !data.IsString() || data.AsString().size() > ((MaxChunkBytes + 2) / 3) * 4)
                return;

            Optional<std::vector<uint8>> const decoded = Acore::Encoding::Base64::Decode(data.AsString());
            if (!decoded)
                return;

            double const indexValue = index.AsNumber();
            double const totalValue = total.AsNumber();
            if (!(indexValue >= 1.0 && indexValue <= MaxChunks) || !(totalValue >= 1.0 && totalValue <= MaxChunks))
                return;

            std::string const bytes(decoded->begin(), decoded->end());
            AcceptResult result;
            {
                std::lock_guard lock(s_mutex);
                if (!s_enabled)
                    return;

                result = s_book.Accept(player->GetGUID().GetRawValue(), id.AsString(),
                    static_cast<uint32>(indexValue), static_cast<uint32>(totalValue), bytes, NowMs());
            }

            if (result == AcceptResult::Completed)
                LOG_INFO("module.dc", "[LabProbe] answer {} from {} complete", id.AsString(), player->GetName());
            else if (result != AcceptResult::Accepted && result != AcceptResult::Duplicate)
                LOG_DEBUG("module.dc", "[LabProbe] chunk for {} from {} refused ({})", id.AsString(),
                    player->GetName(), static_cast<uint32>(result));
        }

        Player* FindLabPlayer(ChatHandler* handler, std::string name)
        {
            {
                std::lock_guard lock(s_mutex);
                if (!s_enabled)
                {
                    Refuse(handler, "probe relay disabled (DC.LabProbe.Enable = 0)");
                    return nullptr;
                }
            }

            std::string const requested = name;
            Player* player = normalizePlayerName(name) ? ObjectAccessor::FindPlayerByName(name) : nullptr;
            if (!player || !player->GetSession())
            {
                Refuse(handler, requested + " is not online");
                return nullptr;
            }

            if (DCAddon::IsBotRecipient(player))
            {
                Refuse(handler, requested + " has no client (bot session)");
                return nullptr;
            }

            std::string account;
            bool const known = AccountMgr::GetName(player->GetSession()->GetAccountId(), account);
            bool listed = false;
            {
                std::lock_guard lock(s_mutex);
                listed = known && IsListedAccount(s_accounts, account);
            }

            if (!listed)
            {
                Refuse(handler, requested + " is not on a lab account (DC.LabProbe.Accounts)");
                return nullptr;
            }

            return player;
        }
    }

    class LabProbeWorldScript final : public WorldScript
    {
    public:
        LabProbeWorldScript() : WorldScript("dc_lab_probe_world", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            LoadConfig();
        }
    };

    class LabProbePlayerScript final : public PlayerScript
    {
    public:
        LabProbePlayerScript() : PlayerScript("dc_lab_probe_player", { PLAYERHOOK_ON_LOGOUT }) { }

        void OnPlayerLogout(Player* player) override
        {
            if (!player)
                return;

            std::lock_guard lock(s_mutex);
            s_book.AbandonPlayer(player->GetGUID().GetRawValue());
        }
    };

    class LabProbeCommandScript final : public CommandScript
    {
    public:
        LabProbeCommandScript() : CommandScript("dc_lab_probe_commands") { }

        ChatCommandTable GetCommands() const override
        {
            static ChatCommandTable probeTable =
            {
                { "send",   HandleSend,   SEC_ADMINISTRATOR, Console::Yes },
                { "result", HandleResult, SEC_ADMINISTRATOR, Console::Yes },
                { "list",   HandleList,   SEC_ADMINISTRATOR, Console::Yes }
            };
            // `.dca` is shared with cs_dc_addons.cpp; only a named sub-table is
            // added here, never a blank root handler.
            static ChatCommandTable dcaTable =
            {
                { "probe", probeTable }
            };
            static ChatCommandTable commandTable =
            {
                { "dca", dcaTable }
            };
            return commandTable;
        }

        static bool HandleSend(ChatHandler* handler, std::string character, Tail requestJson)
        {
            Player* player = FindLabPlayer(handler, character);
            if (!player)
                return false;

            std::string const text(requestJson);
            DCAddon::JsonValue request;
            std::string command;
            std::string error;
            if (text.empty() || !BuildRequest(DCAddon::JsonParser::Parse(text), request, command, error))
            {
                Refuse(handler, error.empty() ? std::string("missing request JSON") : error);
                return false;
            }

            std::string id;
            {
                std::lock_guard lock(s_mutex);
                id = NextRequestId();
                s_book.Arm(id, player->GetGUID().GetRawValue(), player->GetName(), command, NowMs());
            }

            DCAddon::JsonMessage(MODULE, SMSG_REQUEST)
                .Set("id", id)
                .Set("req", request)
                .Send(player);

            LOG_INFO("module.dc", "[LabProbe] {} sent {} '{}' to {}",
                handler->GetSession() ? handler->GetSession()->GetPlayerName() : std::string("console"),
                id, command, player->GetName());
            handler->PSendSysMessage("sent {}", id);
            return true;
        }

        static bool HandleResult(ChatHandler* handler, std::string id)
        {
            if (!IsRequestId(id))
            {
                Refuse(handler, "not a probe request id");
                return false;
            }

            ResultStatus status;
            {
                std::lock_guard lock(s_mutex);
                status = s_book.Status(id, NowMs());
            }

            switch (status.state)
            {
                case ResultState::Pending:
                    handler->PSendSysMessage("pending {}/{}", status.received, status.total);
                    return true;
                case ResultState::Abandoned:
                    handler->SendSysMessage("abandoned");
                    return true;
                case ResultState::Complete:
                    break;
                default:
                    handler->SendSysMessage("unknown");
                    return true;
            }

            if (!handler->GetSession())
            {
                handler->PSendSysMessage("complete {}", Acore::Encoding::Base64::Encode(
                    std::vector<uint8>(status.body.begin(), status.body.end())));
                return true;
            }

            handler->PSendSysMessage("complete: {} bytes from {} ({})", status.body.size(), status.player,
                status.command);
            std::size_t lines = 0;
            for (std::size_t pos = 0; pos < status.body.size() && lines < ChatMaxLines; pos += ChatLineBytes, ++lines)
                handler->SendSysMessage(status.body.substr(pos, ChatLineBytes), true);

            if (status.body.size() > ChatLineBytes * ChatMaxLines)
                handler->SendSysMessage("... (truncated in chat; read it over SOAP or the console for the full JSON)");

            return true;
        }

        static bool HandleList(ChatHandler* handler)
        {
            std::vector<std::pair<std::string, ResultStatus>> entries;
            {
                std::lock_guard lock(s_mutex);
                entries = s_book.List(NowMs());
            }

            if (entries.empty())
            {
                handler->SendSysMessage("no probe requests");
                return true;
            }

            for (auto const& [id, status] : entries)
                handler->PSendSysMessage("{} {} {} {} {}/{} {}s", id, status.player, status.command,
                    ResultStateName(status.state), status.received, status.total, status.ageMs / 1000);

            return true;
        }
    };
}

void AddSC_dc_lab_probe()
{
    DCLabProbe::LoadConfig();
    DC_REGISTER_HANDLER(DCLabProbe::MODULE, DCLabProbe::CMSG_ANSWER_CHUNK, DCLabProbe::HandleAnswerChunk);

    new DCLabProbe::LabProbeWorldScript();
    new DCLabProbe::LabProbePlayerScript();
    new DCLabProbe::LabProbeCommandScript();
}
