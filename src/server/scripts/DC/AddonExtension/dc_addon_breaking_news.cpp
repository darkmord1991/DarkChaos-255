#include "dc_addon_breaking_news.h"

#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "dc_addon_namespace.h"
#include "WorldPacket.h"
#include "WorldSession.h"

#include <algorithm>
#include <cctype>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <sstream>

namespace DCBreakingNews
{
    namespace
    {
        constexpr std::time_t BREAKING_NEWS_CACHE_TTL_SECS = 30;

        constexpr char const* CONFIG_ENABLE = "DC.BreakingNews.Enable";
        constexpr char const* CONFIG_TITLE = "DC.BreakingNews.Title";
        constexpr char const* CONFIG_PATH = "DC.BreakingNews.ContentPath";
        constexpr char const* CONFIG_FORMAT = "DC.BreakingNews.Format";
        constexpr char const* CONFIG_CACHE = "DC.BreakingNews.Cache";
        constexpr char const* CONFIG_VERBOSE = "DC.BreakingNews.Verbose";
        constexpr char const* CONFIG_DELIVERY_LOG =
            "DC.BreakingNews.DeliveryLog.Enable";
        constexpr char const* CONFIG_TRANSPORT_DEBUG =
            "DC.BreakingNews.TransportDebug";
        constexpr char const* TABLE_DELIVERY_LOG =
            "dc_breaking_news_delivery_log";
        constexpr uint32 MAX_DELIVERY_LOG_ENTRIES = 25;

        struct CachedState
        {
            Snapshot snapshot;
            uint32 revisionCounter = 0;
            bool cacheEnabled = true;
            bool loadedOnce = false;
            std::time_t expiresAt = 0;
        };

        std::mutex sBreakingNewsLock;
        CachedState sBreakingNewsState;

        bool DoesCharacterTableExist(char const* tableName)
        {
            if (!tableName || !*tableName)
                return false;

            return CharacterDatabase.Query(
                "SELECT 1 FROM information_schema.TABLES "
                "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}' LIMIT 1",
                tableName) != nullptr;
        }

        bool IsDeliveryLogEnabled()
        {
            return sConfigMgr->GetOption<bool>(CONFIG_DELIVERY_LOG, true);
        }

        bool HasDeliveryLogTable()
        {
            static std::once_flag once;
            static bool exists = false;

            std::call_once(once, []()
            {
                exists = DoesCharacterTableExist(TABLE_DELIVERY_LOG);
                if (!exists)
                {
                    LOG_WARN("module.dc",
                        "Breaking news delivery log table '{}' not found; delivery auditing will stay disabled until the SQL migration is applied.",
                        TABLE_DELIVERY_LOG);
                }
            });

            return exists;
        }

        bool IsTransportDebugEnabled()
        {
            return sConfigMgr->GetOption<bool>(CONFIG_TRANSPORT_DEBUG, false);
        }

        std::string Trim(std::string value)
        {
            auto notSpace = [](unsigned char ch)
            {
                return !std::isspace(ch);
            };

            value.erase(value.begin(),
                std::find_if(value.begin(), value.end(), notSpace));
            value.erase(
                std::find_if(value.rbegin(), value.rend(), notSpace).base(),
                value.end());
            return value;
        }

        std::string ToLowerCopy(std::string value)
        {
            std::transform(value.begin(), value.end(), value.begin(),
                [](unsigned char ch)
                {
                    return static_cast<char>(std::tolower(ch));
                });
            return value;
        }

        void StripWrapperTag(std::string& text, std::string const& tagName)
        {
            std::string lower = ToLowerCopy(text);
            std::string openPrefix = "<" + tagName;
            std::string closeTag = "</" + tagName + ">";

            std::size_t openPos = lower.find(openPrefix);
            if (openPos == std::string::npos)
                return;

            std::size_t openEnd = lower.find('>', openPos);
            if (openEnd == std::string::npos)
                return;

            std::size_t closePos = lower.rfind(closeTag);
            if (closePos == std::string::npos || closePos <= openEnd)
                return;

            text = text.substr(openEnd + 1, closePos - openEnd - 1);
        }

        std::string NormalizeFormat(std::string format)
        {
            format = Trim(ToLowerCopy(format));

            if (format.empty() || format == "html")
                return "simplehtml";

            if (format == "simplehtml" || format == "plain")
                return format;

            return "simplehtml";
        }

        std::string NormalizeBody(std::string body, std::string const& format)
        {
            body.erase(std::remove(body.begin(), body.end(), '\r'), body.end());

            if (format == "simplehtml")
            {
                StripWrapperTag(body, "html");
                StripWrapperTag(body, "body");
            }

            return Trim(body);
        }

        void RecordDeliveryDecision(WorldSession* session, char const* source,
            TransportDecision const& decision, bool sent)
        {
            if (!session || !IsDeliveryLogEnabled() || !HasDeliveryLogTable())
                return;

            uint32 accountId = session->GetAccountId();
            if (accountId == 0)
                return;

            uint64 characterGuid = decision.characterGuid;
            std::string characterName = decision.characterName;
            if (Player* player = session->GetPlayer())
            {
                characterGuid = player->GetGUID().GetCounter();
                characterName = player->GetName();
            }

            std::string safeSource = source ? source : "unknown";
            std::string safeReason = decision.reason;
            std::string safeCharacterName = characterName;
            CharacterDatabase.EscapeString(safeSource);
            CharacterDatabase.EscapeString(safeReason);
            CharacterDatabase.EscapeString(safeCharacterName);

            CharacterDatabase.Execute(
                "INSERT INTO dc_breaking_news_delivery_log "
                "(account_id, character_guid, character_name, source, sent, reason, "
                "has_capability_state, used_persisted_caps, feature_enabled, snapshot_ready, "
                "compatible, client_caps, negotiated_caps, revision, updated_at, body_bytes) "
                "VALUES ({}, {}, '{}', '{}', {}, '{}', {}, {}, {}, {}, {}, {}, {}, {}, {}, {})",
                accountId,
                characterGuid,
                safeCharacterName,
                safeSource,
                sent ? 1 : 0,
                safeReason,
                decision.hasCapabilityState ? 1 : 0,
                decision.capabilityFromPersistedFallback ? 1 : 0,
                decision.featureEnabled ? 1 : 0,
                decision.snapshotReady ? 1 : 0,
                decision.versionCompatible ? 1 : 0,
                decision.clientCapabilities,
                decision.negotiatedCapabilities,
                decision.snapshot.revision,
                decision.snapshot.updatedAt,
                static_cast<uint32>(decision.snapshot.body.size()));

            CharacterDatabase.Execute(
                "DELETE FROM dc_breaking_news_delivery_log "
                "WHERE account_id = {} AND id NOT IN ("
                    "SELECT id FROM ("
                        "SELECT id FROM dc_breaking_news_delivery_log "
                        "WHERE account_id = {} "
                        "ORDER BY event_time DESC, id DESC LIMIT {}"
                    ") AS recent_rows"
                ")",
                accountId, accountId, MAX_DELIVERY_LOG_ENTRIES);
        }

        bool ReadContentFile(std::string const& path, std::string& content,
            std::string* errorMessage)
        {
            std::error_code errorCode;
            std::filesystem::path contentPath(path);

            if (std::filesystem::exists(contentPath, errorCode) &&
                std::filesystem::is_directory(contentPath, errorCode))
            {
                if (errorMessage)
                {
                    *errorMessage =
                        "Configured content path points to a directory; expected a file: " +
                        path;
                }
                return false;
            }

            std::ifstream input(path, std::ios::in | std::ios::binary);
            if (!input.is_open())
            {
                if (errorMessage)
                    *errorMessage = "Failed to open content file: " + path;
                return false;
            }

            std::ostringstream buffer;
            buffer << input.rdbuf();
            content = buffer.str();
            return true;
        }

        bool BuildSnapshotFromConfig(Snapshot& snapshot, bool& cacheEnabled,
            std::string* errorMessage)
        {
            snapshot = Snapshot();
            snapshot.enabled = sConfigMgr->GetOption<bool>(CONFIG_ENABLE, false);
            cacheEnabled = sConfigMgr->GetOption<bool>(CONFIG_CACHE, true);

            if (!snapshot.enabled)
                return true;

            std::string path = sConfigMgr->GetOption<std::string>(
                CONFIG_PATH, "./breakingnews.html");
            if (Trim(path).empty())
            {
                if (errorMessage)
                    *errorMessage = "Configured content path is empty.";
                return false;
            }

            snapshot.title = Trim(sConfigMgr->GetOption<std::string>(
                CONFIG_TITLE, "Breaking News"));
            if (snapshot.title.empty())
                snapshot.title = "Breaking News";

            snapshot.format = NormalizeFormat(sConfigMgr->GetOption<std::string>(
                CONFIG_FORMAT, "simplehtml"));

            std::string content;
            if (!ReadContentFile(path, content, errorMessage))
                return false;

            snapshot.body = NormalizeBody(std::move(content), snapshot.format);
            if (snapshot.body.empty())
            {
                if (errorMessage)
                    *errorMessage = "Configured content file is empty.";
                return false;
            }

            snapshot.updatedAt = static_cast<uint32>(std::time(nullptr));
            return true;
        }

        bool RefreshLocked(bool force, std::string* errorMessage)
        {
            std::time_t now = std::time(nullptr);
            if (!force && sBreakingNewsState.loadedOnce
                && sBreakingNewsState.cacheEnabled
                && sBreakingNewsState.expiresAt > now)
            {
                return true;
            }

            Snapshot nextSnapshot;
            bool cacheEnabled = true;
            if (!BuildSnapshotFromConfig(nextSnapshot, cacheEnabled, errorMessage))
                return false;

            if (!nextSnapshot.enabled)
            {
                sBreakingNewsState = CachedState();
                return true;
            }

            sBreakingNewsState.snapshot = std::move(nextSnapshot);
            sBreakingNewsState.cacheEnabled = cacheEnabled;
            sBreakingNewsState.loadedOnce = true;
            sBreakingNewsState.expiresAt = cacheEnabled
                ? now + BREAKING_NEWS_CACHE_TTL_SECS
                : 0;
            sBreakingNewsState.snapshot.revision = ++sBreakingNewsState.revisionCounter;

            if (sConfigMgr->GetOption<bool>(CONFIG_VERBOSE, false))
            {
                LOG_INFO("module.dc",
                    "Breaking news refreshed (revision={}, format={}, bodyBytes={})",
                    sBreakingNewsState.snapshot.revision,
                    sBreakingNewsState.snapshot.format,
                    sBreakingNewsState.snapshot.body.size());
            }

            return true;
        }

        TransportDecision BuildTransportDecision(
            DCAddon::SessionCapabilityState const* capabilityState,
            char const* missingCapabilityReason)
        {
            TransportDecision decision;

            if (capabilityState)
            {
                decision.hasCapabilityState = true;
                decision.capabilityFromPersistedFallback =
                    capabilityState->loadedFromPersistedFallback;
                decision.versionCompatible = capabilityState->versionCompatible;
                decision.clientCapabilities =
                    capabilityState->clientCapabilities;
                decision.negotiatedCapabilities =
                    capabilityState->negotiatedCapabilities;
                decision.characterGuid = capabilityState->lastCharacterGuid;
                decision.characterName = capabilityState->lastCharacterName;
                decision.capabilitySource =
                    capabilityState->loadedFromPersistedFallback
                    ? "db-fallback"
                    : "session-registry";
            }

            {
                std::lock_guard<std::mutex> lock(sBreakingNewsLock);
                if (!RefreshLocked(false, &decision.snapshotError))
                {
                    decision.reason = "snapshot-load-failed";
                    return decision;
                }

                decision.snapshot = sBreakingNewsState.snapshot;
            }

            decision.featureEnabled = decision.snapshot.enabled;
            decision.snapshotReady =
                decision.snapshot.enabled && !decision.snapshot.body.empty();

            if (!decision.snapshot.enabled)
            {
                decision.reason = "feature-disabled";
                return decision;
            }

            if (decision.snapshot.body.empty())
            {
                decision.reason = "payload-empty";
                return decision;
            }

            if (!capabilityState)
            {
                decision.reason = missingCapabilityReason;
                return decision;
            }

            DCAddon::TransportPolicyRequest request;
            request.featureName = "breaking-news";
            request.nativeCapability =
                DCAddon::ProtocolVersion::Capability::BREAKING_NEWS_NATIVE;
            request.noCapabilityStateReason = missingCapabilityReason
                ? missingCapabilityReason
                : "no-capability-state";
            request.versionIncompatibleReason = "incompatible-version";
            request.clientCapabilityMissingReason = "client-cap-missing";
            request.negotiatedCapabilityMissingReason = "not-negotiated";
            request.nativeReadyReason = "native-ready";

            DCAddon::TransportPolicyDecision transport =
                DCAddon::ResolveTransportPolicy(capabilityState, request);
            decision.willSend = transport.UsesNative();
            decision.reason = transport.reason;
            return decision;
        }
    }

    Snapshot GetSnapshot()
    {
        std::lock_guard<std::mutex> lock(sBreakingNewsLock);
        RefreshLocked(false, nullptr);
        return sBreakingNewsState.snapshot;
    }

    bool Reload(bool force, std::string* errorMessage)
    {
        std::lock_guard<std::mutex> lock(sBreakingNewsLock);
        return RefreshLocked(force, errorMessage);
    }

    TransportDecision EvaluateTransportDecision(WorldSession* session)
    {
        if (!session)
        {
            TransportDecision decision = BuildTransportDecision(nullptr,
                "no-session");
            decision.reason = "no-session";
            return decision;
        }

        TransportDecision decision;
        DCAddon::SessionCapabilityState capabilityState;
        if (DCAddon::TryGetSessionCapabilityState(session, capabilityState))
            decision = BuildTransportDecision(&capabilityState,
                "no-capability-state");
        else
            decision = BuildTransportDecision(nullptr, "no-capability-state");

        if (Player* player = session->GetPlayer())
        {
            decision.characterGuid = player->GetGUID().GetCounter();
            decision.characterName = player->GetName();
        }

        return decision;
    }

    TransportDecision EvaluateTransportDecision(
        DCAddon::SessionCapabilityState const* capabilityState)
    {
        return BuildTransportDecision(capabilityState, "no-capability-state");
    }

    bool GetRecentDeliveryLog(uint32 accountId, uint32 limit,
        std::vector<DeliveryLogEntry>& out)
    {
        out.clear();
        if (accountId == 0 || limit == 0 || !HasDeliveryLogTable())
            return false;

        QueryResult result = CharacterDatabase.Query(
            "SELECT id, account_id, character_guid, character_name, source, sent, "
            "reason, has_capability_state, used_persisted_caps, feature_enabled, "
            "snapshot_ready, compatible, client_caps, negotiated_caps, revision, "
            "updated_at, body_bytes, UNIX_TIMESTAMP(event_time) "
            "FROM dc_breaking_news_delivery_log "
            "WHERE account_id = {} ORDER BY event_time DESC, id DESC LIMIT {}",
            accountId, limit);
        if (!result)
            return true;

        do
        {
            Field* fields = result->Fetch();
            DeliveryLogEntry entry;
            entry.id = fields[0].Get<uint64>();
            entry.accountId = fields[1].Get<uint32>();
            entry.characterGuid = fields[2].Get<uint64>();
            entry.characterName = fields[3].Get<std::string>();
            entry.source = fields[4].Get<std::string>();
            entry.sent = fields[5].Get<uint8>() != 0;
            entry.reason = fields[6].Get<std::string>();
            entry.hasCapabilityState = fields[7].Get<uint8>() != 0;
            entry.capabilityFromPersistedFallback =
                fields[8].Get<uint8>() != 0;
            entry.featureEnabled = fields[9].Get<uint8>() != 0;
            entry.snapshotReady = fields[10].Get<uint8>() != 0;
            entry.versionCompatible = fields[11].Get<uint8>() != 0;
            entry.clientCapabilities = fields[12].Get<uint32>();
            entry.negotiatedCapabilities = fields[13].Get<uint32>();
            entry.revision = fields[14].Get<uint32>();
            entry.updatedAt = fields[15].Get<uint32>();
            entry.bodyBytes = fields[16].Get<uint32>();
            entry.eventUnix = fields[17].Get<uint64>();
            out.push_back(std::move(entry));
        } while (result->NextRow());

        return true;
    }

    bool SendToSession(WorldSession* session, char const* source)
    {
        TransportDecision decision = EvaluateTransportDecision(session);
        if (!session || !decision.willSend)
        {
            RecordDeliveryDecision(session, source, decision, false);

            if (session && !decision.snapshotError.empty())
            {
                std::string preview = std::string("source=")
                    + (source ? source : "unknown");
                DCAddon::LogNativeProtocolError(session,
                    DCAddon::ProtocolLogDirection::ServerToClient, "NEWS", 0,
                    ::SMSG_BREAKING_NEWS, "snapshot_error",
                    decision.snapshotError, preview);
            }

            if (IsTransportDebugEnabled())
            {
                LOG_INFO("module.dc",
                    "Breaking news native send suppressed account={} reason={} capabilitySource={} featureEnabled={} snapshotReady={} revision={} bodyBytes={} clientCaps=0x{:X} negotiatedCaps=0x{:X} compatible={}",
                    session ? session->GetAccountId() : 0,
                    decision.reason,
                    decision.capabilitySource,
                    decision.featureEnabled,
                    decision.snapshotReady,
                    decision.snapshot.revision,
                    decision.snapshot.body.size(),
                    decision.clientCapabilities,
                    decision.negotiatedCapabilities,
                    decision.versionCompatible);

                if (!decision.snapshotError.empty())
                {
                    LOG_INFO("module.dc",
                        "Breaking news native send snapshot error account={} error={}",
                        session ? session->GetAccountId() : 0,
                        decision.snapshotError);
                }
            }
            return false;
        }

        Snapshot const& snapshot = decision.snapshot;

        WorldPacket data(::SMSG_BREAKING_NEWS,
            snapshot.title.size() + snapshot.body.size() +
            snapshot.format.size() + 32);
        data << int32(snapshot.revision);
        data << int32(snapshot.updatedAt);
        data << snapshot.format;
        data << snapshot.title;
        data << snapshot.body;
        session->SendPacket(&data);
        std::string preview = std::string("source=")
            + (source ? source : "unknown")
            + "|revision=" + std::to_string(snapshot.revision)
            + "|updated=" + std::to_string(snapshot.updatedAt)
            + "|format=" + snapshot.format
            + "|bodyBytes=" + std::to_string(snapshot.body.size());
        DCAddon::LogNativeS2CMessage(session, "NEWS", 0,
            ::SMSG_BREAKING_NEWS, data.size(), preview, 0);
        RecordDeliveryDecision(session, source, decision, true);

        if (sConfigMgr->GetOption<bool>(CONFIG_VERBOSE, false)
            || IsTransportDebugEnabled())
        {
            LOG_INFO("module.dc",
                "Breaking news sent to account={} (revision={}, format={}, bodyBytes={}, negotiatedCaps=0x{:X}, capabilitySource={})",
                session->GetAccountId(), snapshot.revision,
                snapshot.format, snapshot.body.size(),
                decision.negotiatedCapabilities,
                decision.capabilitySource);
        }

        return true;
    }
}

namespace
{
    class DCBreakingNewsServerScript : public ServerScript
    {
    public:
        DCBreakingNewsServerScript()
            : ServerScript("DCBreakingNewsServerScript",
                { SERVERHOOK_CAN_PACKET_SEND })
        {
        }

    private:
        bool CanPacketSend(WorldSession* session,
            WorldPacket const& packet) override
        {
            if (packet.GetOpcode() == SMSG_CHAR_ENUM)
                DCBreakingNews::SendToSession(session, "char-enum");

            return true;
        }
    };

    class DCBreakingNewsWorldScript : public WorldScript
    {
    public:
        DCBreakingNewsWorldScript()
            : WorldScript("DCBreakingNewsWorldScript",
                { WORLDHOOK_ON_AFTER_CONFIG_LOAD })
        {
        }

    private:
        void OnAfterConfigLoad(bool /*reload*/) override
        {
            std::string errorMessage;
            if (!DCBreakingNews::Reload(true, &errorMessage))
                LOG_ERROR("module.dc", "Breaking news reload failed: {}",
                    errorMessage);
        }
    };
}

void AddSC_dc_addon_breaking_news()
{
    new DCBreakingNewsServerScript();
    new DCBreakingNewsWorldScript();
}