/*
 * Dark Chaos - In-game bug reports (spool for the GitHub relay)
 * ==============================================================
 *
 * Players file a report from DC-QOS (/dcbug). The client sends it over the DC
 * addon protocol; the server validates it, rate limits per account and
 * appends one JSON line to a local spool file. The game server makes no HTTP
 * call and holds no GitHub credential: apps/bugreport_relay/dc_bugreport_relay.py
 * (a separate process) turns spool lines into GitHub issues. Re-implemented
 * after Ascension CoA's bug-report path (docs/coa/github-bug-reports.md).
 *
 * Wire (module BUGR, addon transport; the protocol chunks the upload):
 *   C2S BUGR|1|RID:n|J|{"title":"..","body":"..","category":"bug",
 *                      "client":{"build":"3.3.5 (12340)","fingerprint":"..","locale":"enUS",
 *                                "caps":"0x..","zoneText":"..","subZoneText":".."},
 *                      "addons":[{"n":"DC-QOS","v":"1.3.1"}],
 *                      "errors":[{"m":"..","c":3}]}
 *   S2C BUGR|16|J|{"ok":true,"id":".."} or {"ok":false,"error":"..","retryIn":N}
 *
 * Spool line (v1): {"v":1,"id","ts","core":{"hash","date"},"report":{title,body,category},
 *   "client":{...},"addons":[...],"errors":[...],
 *   "context":{map,mapName,zone,zoneName,area,areaName,x,y,z,o,level,class,race,instance,difficulty},
 *   "private":{"account":<id>,"guid":"<ObjectGuid::ToString()>"}}
 * "context" is filled by the server from the player object; "private" is for
 * administrators only and never leaves the spool (the relay drops it). No
 * account name, IP address or character name is written.
 *
 * Config (all off by default; read at startup and on .reload config):
 *   DC.BugReport.Enable              = 0
 *   DC.BugReport.SpoolFile           = ""        absolute path recommended; the folder must exist
 *   DC.BugReport.CooldownSeconds     = 120
 *   DC.BugReport.MaxPerAccountPerDay = 10
 *   DC.BugReport.MaxBytes            = 8192      largest accepted upload (JSON body)
 *   DC.BugReport.SpoolMaxBytes       = 52428800  refuse new reports once the spool is this big
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_bug_report_core.h"
#include "Chat.h"
#include "Config.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "GitRevision.h"
#include "Log.h"
#include "Map.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "Timer.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include <mutex>

namespace DCBugReport
{
    namespace
    {
        struct Settings
        {
            bool enabled = false;
            std::string spoolFile;
            uint32 cooldownSeconds = 120;
            uint32 maxPerDay = 10;
            uint32 maxBytes = 8192;
            uint64 spoolMaxBytes = 52428800;
        };

        std::mutex s_mutex;
        Settings s_settings;
        RateLimiter s_limiter;
        uint32 s_counter = 0;

        void LoadConfig()
        {
            Settings settings;
            settings.enabled = sConfigMgr->GetOption<bool>("DC.BugReport.Enable", false);
            settings.spoolFile = sConfigMgr->GetOption<std::string>("DC.BugReport.SpoolFile", "");
            settings.cooldownSeconds = sConfigMgr->GetOption<uint32>("DC.BugReport.CooldownSeconds", 120);
            settings.maxPerDay = sConfigMgr->GetOption<uint32>("DC.BugReport.MaxPerAccountPerDay", 10);
            settings.maxBytes = std::max<uint32>(sConfigMgr->GetOption<uint32>("DC.BugReport.MaxBytes", 8192), 1024);
            settings.spoolMaxBytes = sConfigMgr->GetOption<uint64>("DC.BugReport.SpoolMaxBytes", 52428800);

            if (settings.enabled && settings.spoolFile.empty())
            {
                LOG_ERROR("module.dc", "[BugReport] DC.BugReport.Enable = 1 but DC.BugReport.SpoolFile is empty; "
                    "bug reports stay disabled");
                settings.enabled = false;
            }

            bool const enabled = settings.enabled;
            {
                std::lock_guard lock(s_mutex);
                s_settings = std::move(settings);
            }

            // The module stays registered (and enabled) either way, so a
            // client always gets an answer instead of a generic "module is
            // disabled" error; the handler refuses while switched off.
            DCAddon::MessageRouter::Instance().SetModuleEnabled(MODULE, true);

            if (enabled)
                LOG_INFO("module.dc", "[BugReport] enabled, spooling to the configured file");
        }

        void SendResult(Player* player, bool ok, std::string const& idOrError, uint32 retryIn = 0)
        {
            DCAddon::JsonMessage msg(MODULE, SMSG_RESULT);
            msg.Set("ok", ok);
            msg.Set(ok ? "id" : "error", idOrError);
            if (retryIn)
                msg.Set("retryIn", retryIn);

            msg.Send(player);
        }

        std::string StringField(DCAddon::JsonValue const& object, std::string const& key, std::size_t maxBytes,
            bool multiline = false)
        {
            DCAddon::JsonValue const& value = object[key];
            return value.IsString() ? CleanText(value.AsString(), maxBytes, multiline) : std::string();
        }

        DCAddon::JsonValue BuildClient(DCAddon::JsonValue const& input)
        {
            DCAddon::JsonValue client;
            client.SetObject();
            if (!input.IsObject())
                return client;

            for (char const* key : { "build", "fingerprint", "locale", "caps", "zoneText", "subZoneText", "exe" })
            {
                std::string const value = StringField(input, key, MaxClientFieldBytes);
                if (!value.empty())
                    client.Set(key, DCAddon::JsonValue(value));
            }

            return client;
        }

        DCAddon::JsonValue BuildAddons(DCAddon::JsonValue const& input)
        {
            DCAddon::JsonValue addons;
            addons.SetArray();
            if (!input.IsArray())
                return addons;

            for (DCAddon::JsonValue const& item : input.AsArray())
            {
                if (addons.Size() >= MaxAddons)
                    break;

                std::string const name = item.IsObject() ? StringField(item, "n", MaxAddonFieldBytes) : std::string();
                if (name.empty())
                    continue;

                DCAddon::JsonValue entry;
                entry.SetObject();
                entry.Set("n", DCAddon::JsonValue(name));
                std::string const version = StringField(item, "v", MaxAddonFieldBytes);
                if (!version.empty())
                    entry.Set("v", DCAddon::JsonValue(version));

                addons.Push(std::move(entry));
            }

            return addons;
        }

        DCAddon::JsonValue BuildErrors(DCAddon::JsonValue const& input)
        {
            DCAddon::JsonValue errors;
            errors.SetArray();
            if (!input.IsArray())
                return errors;

            for (DCAddon::JsonValue const& item : input.AsArray())
            {
                if (errors.Size() >= MaxErrors)
                    break;

                std::string const message = item.IsObject()
                    ? StringField(item, "m", MaxErrorBytes, true) : std::string();
                if (message.empty())
                    continue;

                DCAddon::JsonValue entry;
                entry.SetObject();
                entry.Set("m", DCAddon::JsonValue(message));
                DCAddon::JsonValue const& count = item["c"];
                if (count.IsNumber() && count.AsNumber() >= 1.0 && count.AsNumber() <= 1000000.0)
                    entry.Set("c", DCAddon::JsonValue(static_cast<uint32>(count.AsNumber())));

                errors.Push(std::move(entry));
            }

            return errors;
        }

        std::string AreaName(uint32 areaId)
        {
            AreaTableEntry const* area = areaId ? sAreaTableStore.LookupEntry(areaId) : nullptr;
            if (!area || !area->area_name[0])
                return std::string();

            return CleanText(area->area_name[0], MaxClientFieldBytes, false);
        }

        DCAddon::JsonValue BuildContext(Player* player)
        {
            DCAddon::JsonValue context;
            context.SetObject();
            context.Set("map", DCAddon::JsonValue(player->GetMapId()));
            MapEntry const* mapEntry = sMapStore.LookupEntry(player->GetMapId());
            if (mapEntry && mapEntry->name[0])
                context.Set("mapName", DCAddon::JsonValue(CleanText(mapEntry->name[0], MaxClientFieldBytes, false)));

            context.Set("zone", DCAddon::JsonValue(player->GetZoneId()));
            context.Set("zoneName", DCAddon::JsonValue(AreaName(player->GetZoneId())));
            context.Set("area", DCAddon::JsonValue(player->GetAreaId()));
            context.Set("areaName", DCAddon::JsonValue(AreaName(player->GetAreaId())));
            context.Set("x", DCAddon::JsonValue(static_cast<double>(player->GetPositionX())));
            context.Set("y", DCAddon::JsonValue(static_cast<double>(player->GetPositionY())));
            context.Set("z", DCAddon::JsonValue(static_cast<double>(player->GetPositionZ())));
            context.Set("o", DCAddon::JsonValue(static_cast<double>(player->GetOrientation())));
            context.Set("level", DCAddon::JsonValue(static_cast<uint32>(player->GetLevel())));
            context.Set("class", DCAddon::JsonValue(static_cast<uint32>(player->getClass())));
            context.Set("race", DCAddon::JsonValue(static_cast<uint32>(player->getRace())));
            if (Map* map = player->GetMap())
            {
                context.Set("instance", DCAddon::JsonValue(map->Instanceable()));
                context.Set("difficulty", DCAddon::JsonValue(static_cast<uint32>(map->GetDifficulty())));
            }

            return context;
        }

        // C2S BUGR|1: one report.
        void HandleSubmit(Player* player, DCAddon::ParsedMessage const& msg)
        {
            if (!player || !player->GetSession())
                return;

            Settings settings;
            {
                std::lock_guard lock(s_mutex);
                settings = s_settings;
            }

            if (!settings.enabled)
            {
                SendResult(player, false, "Bug reports are not enabled on this realm.");
                return;
            }

            if (msg.GetDataBytes() > settings.maxBytes)
            {
                SendResult(player, false, "The report is too large. Shorten the description and try again.");
                return;
            }

            DCAddon::JsonValue const json = DCAddon::GetJsonData(msg);
            if (!json.IsObject())
            {
                SendResult(player, false, "The report could not be read.");
                return;
            }

            std::string const title = StringField(json, "title", MaxTitleBytes);
            std::string const body = StringField(json, "body", MaxBodyBytes, true);
            std::string category = StringField(json, "category", 16);
            if (title.size() < MinTitleBytes)
            {
                SendResult(player, false, "Please enter a title (at least 3 characters).");
                return;
            }

            if (body.size() < MinBodyBytes)
            {
                SendResult(player, false, "Please describe the problem (at least 10 characters).");
                return;
            }

            if (!IsValidCategory(category))
                category = "other";

            uint32 const accountId = player->GetSession()->GetAccountId();
            uint64 const now = static_cast<uint64>(GameTime::GetGameTime().count());

            std::string id;
            std::string error;
            bool stored = false;
            uint32 wait = 0;
            {
                std::lock_guard lock(s_mutex);
                wait = s_limiter.Check(accountId, now, settings.cooldownSeconds, settings.maxPerDay);
                if (!wait)
                {
                    id = MakeReportId(now, ++s_counter, rand32());

                    DCAddon::JsonValue report;
                    report.SetObject();
                    report.Set("title", DCAddon::JsonValue(title));
                    report.Set("body", DCAddon::JsonValue(body));
                    report.Set("category", DCAddon::JsonValue(category));

                    DCAddon::JsonValue core;
                    core.SetObject();
                    core.Set("hash", DCAddon::JsonValue(GitRevision::GetHash()));
                    core.Set("date", DCAddon::JsonValue(GitRevision::GetDate()));

                    DCAddon::JsonValue privateData;
                    privateData.SetObject();
                    privateData.Set("account", DCAddon::JsonValue(accountId));
                    privateData.Set("guid", DCAddon::JsonValue(player->GetGUID().ToString()));

                    DCAddon::JsonValue line;
                    line.SetObject();
                    line.Set("v", DCAddon::JsonValue(SpoolVersion));
                    line.Set("id", DCAddon::JsonValue(id));
                    line.Set("ts", DCAddon::JsonValue(static_cast<double>(now)));
                    line.Set("core", std::move(core));
                    line.Set("report", std::move(report));
                    line.Set("client", BuildClient(json["client"]));
                    line.Set("addons", BuildAddons(json["addons"]));
                    line.Set("errors", BuildErrors(json["errors"]));
                    line.Set("context", BuildContext(player));
                    line.Set("private", std::move(privateData));

                    stored = AppendSpoolLine(settings.spoolFile, line.Encode(), settings.spoolMaxBytes, error);
                    if (stored)
                        s_limiter.Record(accountId, now);
                }
            }

            if (wait)
            {
                SendResult(player, false, Acore::StringFormat(
                    "You sent a report recently. Please wait {} seconds.", wait), wait);
                return;
            }

            if (!stored)
            {
                LOG_ERROR("module.dc", "[BugReport] could not store report: {}", error);
                SendResult(player, false, "The report could not be stored right now. Please try again later.");
                return;
            }

            LOG_INFO("module.dc", "[BugReport] report {} queued (account {}, category {})", id, accountId, category);
            SendResult(player, true, id);
        }
    }

    class BugReportWorldScript final : public WorldScript
    {
    public:
        BugReportWorldScript() : WorldScript("dc_bug_report_world", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            LoadConfig();
        }
    };
}

void AddSC_dc_bug_report()
{
    DCBugReport::LoadConfig();
    DC_REGISTER_HANDLER(DCBugReport::MODULE, DCBugReport::CMSG_SUBMIT, DCBugReport::HandleSubmit);

    new DCBugReport::BugReportWorldScript();
}
