#include "CommandScript.h"
#include "CharacterCache.h"
#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"
#include "ScriptMgr.h"

#include "../AddonExtension/dc_addon_breaking_news.h"
#include "../AddonExtension/dc_addon_namespace.h"

#include <ctime>
#include <sstream>

using namespace Acore::ChatCommands;

namespace
{
    constexpr char const* CONFIG_CAPABILITY_DEBUG =
        "DC.Addon.CapabilityDebug.Enable";
    constexpr char const* CONFIG_PROTOCOL_LOGGING =
        "DC.AddonProtocol.Logging.Enable";
    constexpr char const* CONFIG_TOOLTIP_TRANSPORT_DEBUG =
        "DC.QoS.TooltipTransport.Debug";
    constexpr char const* CONFIG_TRANSPORT_DEBUG =
        "DC.BreakingNews.TransportDebug";
    constexpr char const* TABLE_CAPABILITY_HISTORY =
        "dc_addon_client_caps_history";
    constexpr char const* TABLE_PROTOCOL_ERRORS =
        "dc_addon_protocol_errors";
    constexpr char const* TABLE_BREAKING_NEWS_DELIVERY_LOG =
        "dc_breaking_news_delivery_log";
    constexpr uint32 CAPABILITY_HISTORY_LIMIT = 5;
    constexpr uint32 CAPABILITY_HISTORY_MAX_LIMIT = 25;
    constexpr uint32 PROTOCOL_ERROR_RECENT_WINDOW_HOURS = 24;
    constexpr uint32 PROTOCOL_ERROR_BROWSE_LIMIT = 10;
    constexpr uint32 PROTOCOL_ERROR_BROWSE_MAX_LIMIT = 25;
    constexpr uint32 BREAKING_NEWS_DELIVERY_LIMIT = 5;
    constexpr uint32 BREAKING_NEWS_DELIVERY_MAX_LIMIT = 25;

    struct CapabilityDescriptor
    {
        char const* name;
        uint32 bit;
    };

    struct CapabilityTransportDescriptor
    {
        char const* name;
        uint32 bit;
    };

    struct ProtocolErrorSummary
    {
        bool tableExists = false;
        uint32 recentCount24h = 0;
        uint64 latestUnix = 0;
        std::string latestEventType;
        std::string latestModule;
        uint32 latestOpcode = 0;
        std::string latestMessage;
    };

    struct ProtocolErrorEntry
    {
        uint64 id = 0;
        uint64 timestampUnix = 0;
        std::string characterName;
        std::string direction;
        std::string requestType;
        std::string module;
        uint32 opcode = 0;
        std::string eventType;
        std::string message;
        std::string payloadPreview;
    };

    struct CapabilityBrowseTarget
    {
        std::string scope = "current";
        uint32 accountId = 0;
        uint64 characterGuid = 0;
        std::string playerName;
        uint32 limit = 0;
    };

    CapabilityDescriptor constexpr kCapabilityDescriptors[] =
    {
        { "json-messages",
            DCAddon::ProtocolVersion::Capability::JSON_MESSAGES },
        { "batch-messages",
            DCAddon::ProtocolVersion::Capability::BATCH_MESSAGES },
        { "tooltip-native",
            DCAddon::ProtocolVersion::Capability::TOOLTIP_NATIVE_RESPONSE },
        { "breaking-news-native",
            DCAddon::ProtocolVersion::Capability::BREAKING_NEWS_NATIVE },
    };

    CapabilityTransportDescriptor constexpr kCapabilityTransportDescriptors[] =
    {
        { "tooltip-native",
            DCAddon::ProtocolVersion::Capability::TOOLTIP_NATIVE_RESPONSE },
        { "breaking-news-native",
            DCAddon::ProtocolVersion::Capability::BREAKING_NEWS_NATIVE },
    };

    std::string TrimWhitespace(std::string value)
    {
        size_t first = value.find_first_not_of(" \t\r\n");
        if (first == std::string::npos)
            return "";

        size_t last = value.find_last_not_of(" \t\r\n");
        return value.substr(first, last - first + 1);
    }

    std::string FormatUnixTimestamp(uint64 unixTimestamp)
    {
        if (!unixTimestamp)
            return "0";

        std::time_t rawTime = static_cast<std::time_t>(unixTimestamp);
        std::tm timeInfo = {};

#ifdef _WIN32
        if (localtime_s(&timeInfo, &rawTime) != 0)
            return std::to_string(unixTimestamp);
#else
        if (!localtime_r(&rawTime, &timeInfo))
            return std::to_string(unixTimestamp);
#endif

        char buffer[32] = {};
        if (std::strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S",
                &timeInfo) == 0)
            return std::to_string(unixTimestamp);

        return buffer;
    }

    bool TryParsePositiveUInt32(std::string const& token, uint32& value)
    {
        if (token.empty())
            return false;

        std::istringstream stream(token);
        uint32 parsed = 0;
        char extra = '\0';
        if (!(stream >> parsed) || parsed == 0)
            return false;

        if (stream >> extra)
            return false;

        value = parsed;
        return true;
    }

    bool TryResolveCurrentCapabilityAccount(ChatHandler* handler,
        uint32& accountId, std::string& errorMessage)
    {
        WorldSession* session = handler ? handler->GetSession() : nullptr;
        if (!session)
        {
            errorMessage =
                "This form requires an active session or an explicit account/player target.";
            return false;
        }

        accountId = session->GetAccountId();
        return true;
    }

    bool TryResolvePlayerCapabilityLookup(std::string rawPlayerName,
        uint32& accountId, uint64& characterGuid, std::string& playerName,
        std::string& errorMessage,
        char const* usage = "Usage: .dccaps player <name>");

    bool TryReadOptionalBrowseLimit(std::istringstream& argStream,
        uint32 defaultLimit, uint32 maxLimit, uint32& limit,
        std::string& errorMessage)
    {
        limit = defaultLimit;

        std::string limitToken;
        if (!(argStream >> limitToken))
            return true;

        if (!TryParsePositiveUInt32(limitToken, limit))
        {
            errorMessage = "Limit must be a positive integer.";
            return false;
        }

        if (limit > maxLimit)
            limit = maxLimit;

        std::string extraToken;
        if (argStream >> extraToken)
        {
            errorMessage = "Too many arguments.";
            return false;
        }

        return true;
    }

    bool TryResolveCapabilityBrowseTarget(ChatHandler* handler,
        std::istringstream& argStream, uint32 defaultLimit,
        uint32 maxLimit, char const* usage,
        char const* playerUsage,
        CapabilityBrowseTarget& out, std::string& errorMessage)
    {
        out = CapabilityBrowseTarget();
        out.limit = defaultLimit;

        std::string firstToken;
        if (!(argStream >> firstToken))
            return TryResolveCurrentCapabilityAccount(handler, out.accountId,
                errorMessage);

        if (firstToken == "account")
        {
            out.scope = "account";
            if (!(argStream >> out.accountId) || out.accountId == 0)
            {
                errorMessage = usage;
                return false;
            }

            return TryReadOptionalBrowseLimit(argStream, defaultLimit,
                maxLimit, out.limit, errorMessage);
        }

        if (firstToken == "player")
        {
            out.scope = "player";

            std::string playerToken;
            if (!(argStream >> playerToken))
            {
                errorMessage = playerUsage;
                return false;
            }

            if (!TryResolvePlayerCapabilityLookup(playerToken, out.accountId,
                    out.characterGuid, out.playerName, errorMessage,
                    playerUsage))
            {
                return false;
            }

            return TryReadOptionalBrowseLimit(argStream, defaultLimit,
                maxLimit, out.limit, errorMessage);
        }

        if (!TryParsePositiveUInt32(firstToken, out.limit))
        {
            errorMessage = usage;
            return false;
        }

        if (out.limit > maxLimit)
            out.limit = maxLimit;

        if (!TryResolveCurrentCapabilityAccount(handler, out.accountId,
                errorMessage))
        {
            return false;
        }

        std::string extraToken;
        if (argStream >> extraToken)
        {
            errorMessage = usage;
            return false;
        }

        return true;
    }

    bool CharacterTableExists(char const* tableName)
    {
        if (!tableName || !*tableName)
            return false;

        return CharacterDatabase.Query(
            "SELECT 1 FROM information_schema.TABLES "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}' LIMIT 1",
            tableName) != nullptr;
    }

    ProtocolErrorSummary QueryProtocolErrorSummary(uint32 accountId)
    {
        ProtocolErrorSummary summary;
        summary.tableExists = CharacterTableExists(TABLE_PROTOCOL_ERRORS);
        if (!summary.tableExists)
            return summary;

        QueryResult countResult = accountId != 0
            ? CharacterDatabase.Query(
                "SELECT COUNT(*) FROM dc_addon_protocol_errors "
                "WHERE account_id = {} "
                "AND timestamp >= (NOW() - INTERVAL {} HOUR)",
                accountId, PROTOCOL_ERROR_RECENT_WINDOW_HOURS)
            : CharacterDatabase.Query(
                "SELECT COUNT(*) FROM dc_addon_protocol_errors "
                "WHERE timestamp >= (NOW() - INTERVAL {} HOUR)",
                PROTOCOL_ERROR_RECENT_WINDOW_HOURS);
        if (countResult)
            summary.recentCount24h = countResult->Fetch()[0].Get<uint32>();

        QueryResult latestResult = accountId != 0
            ? CharacterDatabase.Query(
                "SELECT event_type, module, opcode, message, "
                "UNIX_TIMESTAMP(timestamp) "
                "FROM dc_addon_protocol_errors "
                "WHERE account_id = {} "
                "ORDER BY id DESC LIMIT 1",
                accountId)
            : CharacterDatabase.Query(
                "SELECT event_type, module, opcode, message, "
                "UNIX_TIMESTAMP(timestamp) "
                "FROM dc_addon_protocol_errors "
                "ORDER BY id DESC LIMIT 1");
        if (!latestResult)
            return summary;

        Field* fields = latestResult->Fetch();
        summary.latestEventType = fields[0].Get<std::string>();
        summary.latestModule = fields[1].Get<std::string>();
        summary.latestOpcode = fields[2].Get<uint32>();
        summary.latestMessage = fields[3].Get<std::string>();
        summary.latestUnix = fields[4].Get<uint64>();
        return summary;
    }

    bool QueryRecentProtocolErrors(uint32 accountId, uint32 limit,
        std::vector<ProtocolErrorEntry>& out)
    {
        out.clear();
        if (!CharacterTableExists(TABLE_PROTOCOL_ERRORS) || limit == 0)
            return false;

        QueryResult result = accountId != 0
            ? CharacterDatabase.Query(
                "SELECT id, UNIX_TIMESTAMP(timestamp), character_name, "
                "direction, request_type, module, opcode, event_type, "
                "message, payload_preview "
                "FROM dc_addon_protocol_errors "
                "WHERE account_id = {} "
                "ORDER BY id DESC LIMIT {}",
                accountId, limit)
            : CharacterDatabase.Query(
                "SELECT id, UNIX_TIMESTAMP(timestamp), character_name, "
                "direction, request_type, module, opcode, event_type, "
                "message, payload_preview "
                "FROM dc_addon_protocol_errors "
                "ORDER BY id DESC LIMIT {}",
                limit);
        if (!result)
            return true;

        do
        {
            Field* fields = result->Fetch();
            ProtocolErrorEntry entry;
            entry.id = fields[0].Get<uint64>();
            entry.timestampUnix = fields[1].Get<uint64>();
            entry.characterName = fields[2].Get<std::string>();
            entry.direction = fields[3].Get<std::string>();
            entry.requestType = fields[4].Get<std::string>();
            entry.module = fields[5].Get<std::string>();
            entry.opcode = fields[6].Get<uint32>();
            entry.eventType = fields[7].Get<std::string>();
            entry.message = fields[8].Get<std::string>();
            entry.payloadPreview = fields[9].Get<std::string>();
            out.push_back(std::move(entry));
        } while (result->NextRow());

        return true;
    }

    void PrintCapabilityFeatureLines(ChatHandler* handler,
        char const* scope, DCAddon::SessionCapabilityState const& state)
    {
        for (CapabilityDescriptor const& descriptor : kCapabilityDescriptors)
        {
            handler->PSendSysMessage(
                "DC capability feature: scope={} name={} bit=0x{:X} client={} negotiated={}",
                scope,
                descriptor.name,
                descriptor.bit,
                state.HasClientCapability(descriptor.bit) ? 1 : 0,
                state.HasNegotiatedCapability(descriptor.bit) ? 1 : 0);
        }
    }

    char const* GetTransportReason(
        DCAddon::SessionCapabilityState const& state, uint32 capability)
    {
        if (!state.versionCompatible)
            return "incompatible-version";

        if (!state.HasClientCapability(capability))
            return "client-cap-missing";

        if (!state.HasNegotiatedCapability(capability))
            return "not-negotiated";

        return "native-ready";
    }

    void PrintCapabilityTransportLines(ChatHandler* handler,
        char const* scope, char const* source,
        DCAddon::SessionCapabilityState const& state)
    {
        for (CapabilityTransportDescriptor const& descriptor :
            kCapabilityTransportDescriptors)
        {
            char const* reason = GetTransportReason(state, descriptor.bit);
            handler->PSendSysMessage(
                "DC capability transport: scope={} source={} feature={} nativeReady={} reason={} client={} negotiated={}",
                scope,
                source,
                descriptor.name,
                std::string_view(reason) == "native-ready" ? 1 : 0,
                reason,
                state.HasClientCapability(descriptor.bit) ? 1 : 0,
                state.HasNegotiatedCapability(descriptor.bit) ? 1 : 0);
        }
    }

    void PrintBreakingNewsDecisionLine(ChatHandler* handler,
        char const* scope, char const* source, uint32 accountId,
        DCBreakingNews::TransportDecision const& decision)
    {
        handler->PSendSysMessage(
            "DC preworld feature: scope={} source={} account={} feature=breaking-news-native nativeReady={} reason={} capabilityState={} capabilitySource={} featureEnabled={} snapshotReady={} revision={} updatedAt='{}' updatedAtUnix={} bodyBytes={} clientCaps=0x{:X} negotiatedCaps=0x{:X} compatible={}",
            scope,
            source,
            accountId,
            decision.willSend ? 1 : 0,
            decision.reason,
            decision.hasCapabilityState ? 1 : 0,
            decision.capabilitySource,
            decision.featureEnabled ? 1 : 0,
            decision.snapshotReady ? 1 : 0,
            decision.snapshot.revision,
            FormatUnixTimestamp(decision.snapshot.updatedAt),
            decision.snapshot.updatedAt,
            decision.snapshot.body.size(),
            decision.clientCapabilities,
            decision.negotiatedCapabilities,
            decision.versionCompatible ? 1 : 0);

        if (!decision.snapshotError.empty())
        {
            handler->PSendSysMessage(
                "DC preworld feature detail: scope={} source={} account={} feature=breaking-news-native snapshotError='{}'",
                scope,
                source,
                accountId,
                decision.snapshotError);
        }
    }

    void PrintBreakingNewsSnapshotLine(ChatHandler* handler,
        char const* scope, DCBreakingNews::Snapshot const& snapshot)
    {
        handler->PSendSysMessage(
            "Breaking news: scope={} enabled={} revision={} updatedAt='{}' updatedAtUnix={} format={} title='{}' bodyBytes={}",
            scope,
            snapshot.enabled ? 1 : 0,
            snapshot.revision,
            FormatUnixTimestamp(snapshot.updatedAt),
            snapshot.updatedAt,
            snapshot.format,
            snapshot.title,
            snapshot.body.size());
    }

    bool TryGetBreakingNewsTargetDecision(uint32 accountId,
        DCBreakingNews::TransportDecision& decision, std::string& source)
    {
        DCAddon::SessionCapabilityState liveState;
        if (DCAddon::TryGetLiveSessionCapabilityState(accountId, liveState))
        {
            decision = DCBreakingNews::EvaluateTransportDecision(&liveState);
            source = "session-registry";
            return true;
        }

        DCAddon::SessionCapabilityState persistedState;
        if (DCAddon::TryGetPersistedCapabilityState(accountId, persistedState))
        {
            decision = DCBreakingNews::EvaluateTransportDecision(&persistedState);
            source = "db-fallback";
            return true;
        }

        decision = DCBreakingNews::EvaluateTransportDecision(
            static_cast<DCAddon::SessionCapabilityState const*>(nullptr));
        source = "none";
        return false;
    }

    void PrintBreakingNewsDeliveryRows(ChatHandler* handler,
        char const* scope, uint32 accountId, uint32 limit)
    {
        bool tableExists = CharacterTableExists(TABLE_BREAKING_NEWS_DELIVERY_LOG);
        handler->PSendSysMessage(
            "DC breaking news delivery: scope={} account={} table={} limit={}",
            scope,
            accountId,
            tableExists ? 1 : 0,
            limit);

        if (!tableExists || accountId == 0)
            return;

        std::vector<DCBreakingNews::DeliveryLogEntry> entries;
        DCBreakingNews::GetRecentDeliveryLog(accountId, limit, entries);

        handler->PSendSysMessage(
            "DC breaking news delivery: scope={} account={} rows={}",
            scope,
            accountId,
            entries.size());

        for (size_t index = 0; index < entries.size(); ++index)
        {
            DCBreakingNews::DeliveryLogEntry const& entry = entries[index];
            handler->PSendSysMessage(
                "DC breaking news delivery row: scope={} account={} index={} id={} at='{}' atUnix={} source={} sent={} reason={} characterGuid={} characterName='{}' capabilityState={} persistedCaps={} featureEnabled={} snapshotReady={} compatible={} revision={} updatedAt='{}' updatedAtUnix={} bodyBytes={} clientCaps=0x{:X} negotiatedCaps=0x{:X}",
                scope,
                accountId,
                index + 1,
                entry.id,
                FormatUnixTimestamp(entry.eventUnix),
                entry.eventUnix,
                entry.source,
                entry.sent ? 1 : 0,
                entry.reason,
                entry.characterGuid,
                entry.characterName,
                entry.hasCapabilityState ? 1 : 0,
                entry.capabilityFromPersistedFallback ? 1 : 0,
                entry.featureEnabled ? 1 : 0,
                entry.snapshotReady ? 1 : 0,
                entry.versionCompatible ? 1 : 0,
                entry.revision,
                FormatUnixTimestamp(entry.updatedAt),
                entry.updatedAt,
                entry.bodyBytes,
                entry.clientCapabilities,
                entry.negotiatedCapabilities);
        }
    }

    void PrintBreakingNewsStatusCurrent(ChatHandler* handler, uint32 limit)
    {
        DCBreakingNews::Snapshot snapshot = DCBreakingNews::GetSnapshot();
        PrintBreakingNewsSnapshotLine(handler, "current", snapshot);

        WorldSession* session = handler->GetSession();
        if (!session)
        {
            PrintBreakingNewsDecisionLine(handler, "current", "none", 0,
                DCBreakingNews::EvaluateTransportDecision(
                    static_cast<DCAddon::SessionCapabilityState const*>(nullptr)));
            return;
        }

        uint32 accountId = session->GetAccountId();
        DCBreakingNews::TransportDecision decision =
            DCBreakingNews::EvaluateTransportDecision(session);
        PrintBreakingNewsDecisionLine(handler, "current",
            decision.capabilitySource.c_str(), accountId, decision);
        PrintBreakingNewsDeliveryRows(handler, "current", accountId, limit);
    }

    void PrintBreakingNewsStatusForAccount(ChatHandler* handler,
        uint32 accountId, char const* scope, uint32 limit)
    {
        DCBreakingNews::Snapshot snapshot = DCBreakingNews::GetSnapshot();
        PrintBreakingNewsSnapshotLine(handler, scope, snapshot);

        DCBreakingNews::TransportDecision decision;
        std::string source;
        TryGetBreakingNewsTargetDecision(accountId, decision, source);
        PrintBreakingNewsDecisionLine(handler, scope, source.c_str(),
            accountId, decision);
        PrintBreakingNewsDeliveryRows(handler, scope, accountId, limit);
    }

    void PrintCapabilityHistory(ChatHandler* handler,
        char const* scope, uint32 accountId, uint32 limit)
    {
        bool tableExists = CharacterTableExists(TABLE_CAPABILITY_HISTORY);
        handler->PSendSysMessage(
            "DC capability history: scope={} account={} table={} limit={}",
            scope,
            accountId,
            tableExists ? 1 : 0,
            limit);

        if (!tableExists || accountId == 0)
            return;

        std::vector<DCAddon::CapabilityHistoryEntry> history;
        DCAddon::GetRecentCapabilityHistory(accountId, limit,
            history);

        handler->PSendSysMessage(
            "DC capability history: scope={} account={} entries={}",
            scope,
            accountId,
            history.size());

        for (size_t index = 0; index < history.size(); ++index)
        {
            DCAddon::CapabilityHistoryEntry const& entry = history[index];
            handler->PSendSysMessage(
                "DC capability history entry: scope={} account={} index={} seen='{}' seenUnix={} source={} compatible={} clientVersion='{}' clientCaps=0x{:X} negotiatedCaps=0x{:X} characterGuid={} characterName='{}'",
                scope,
                accountId,
                index + 1,
                FormatUnixTimestamp(entry.seenUnix),
                entry.seenUnix,
                entry.source,
                entry.versionCompatible ? 1 : 0,
                entry.clientVersionString,
                entry.clientCapabilities,
                entry.negotiatedCapabilities,
                entry.characterGuid,
                entry.characterName);
        }
    }

    void PrintProtocolErrorRows(ChatHandler* handler,
        char const* scope, uint32 accountId, uint32 limit)
    {
        bool tableExists = CharacterTableExists(TABLE_PROTOCOL_ERRORS);
        handler->PSendSysMessage(
            "DC protocol error browse: scope={} account={} table={} limit={}",
            scope,
            accountId,
            tableExists ? 1 : 0,
            limit);

        if (!tableExists)
            return;

        std::vector<ProtocolErrorEntry> entries;
        QueryRecentProtocolErrors(accountId, limit, entries);

        handler->PSendSysMessage(
            "DC protocol error browse: scope={} account={} rows={}",
            scope,
            accountId,
            entries.size());

        for (size_t index = 0; index < entries.size(); ++index)
        {
            ProtocolErrorEntry const& entry = entries[index];
            handler->PSendSysMessage(
                "DC protocol error row: scope={} account={} index={} id={} at='{}' atUnix={} character='{}' direction={} requestType={} module={} opcode=0x{:X} eventType={} message='{}' payload='{}'",
                scope,
                accountId,
                index + 1,
                entry.id,
                FormatUnixTimestamp(entry.timestampUnix),
                entry.timestampUnix,
                entry.characterName,
                entry.direction,
                entry.requestType,
                entry.module,
                entry.opcode,
                entry.eventType,
                entry.message,
                entry.payloadPreview);
        }
    }

    void PrintProtocolErrorSummary(ChatHandler* handler,
        char const* scope, uint32 accountId, bool protocolLoggingEnabled)
    {
        ProtocolErrorSummary summary = QueryProtocolErrorSummary(accountId);
        handler->PSendSysMessage(
            "DC protocol errors: scope={} account={} logging={} table={} recent24h={}",
            scope,
            accountId,
            protocolLoggingEnabled ? 1 : 0,
            summary.tableExists ? 1 : 0,
            summary.recentCount24h);

        if (summary.latestUnix != 0)
        {
            handler->PSendSysMessage(
                "DC protocol errors latest: scope={} account={} at='{}' atUnix={} eventType={} module={} opcode=0x{:X} message='{}'",
                scope,
                accountId,
                FormatUnixTimestamp(summary.latestUnix),
                summary.latestUnix,
                summary.latestEventType,
                summary.latestModule,
                summary.latestOpcode,
                summary.latestMessage);
        }
    }

    void PrintCapabilityComparisonWarnings(ChatHandler* handler,
        char const* scope, uint32 accountId,
        DCAddon::SessionCapabilityState const& liveState,
        DCAddon::SessionCapabilityState const& persistedState)
    {
        bool persistedOlderThanLive =
            liveState.lastSeenUnix != 0 && persistedState.lastSeenUnix != 0
            && persistedState.lastSeenUnix < liveState.lastSeenUnix;
        bool stateMismatch =
            liveState.clientVersionString != persistedState.clientVersionString
            || liveState.clientCapabilities != persistedState.clientCapabilities
            || liveState.negotiatedCapabilities
                != persistedState.negotiatedCapabilities
            || liveState.versionCompatible != persistedState.versionCompatible
            || liveState.lastCharacterGuid != persistedState.lastCharacterGuid
            || liveState.lastCharacterName != persistedState.lastCharacterName;

        if (!persistedOlderThanLive && !stateMismatch)
            return;

        handler->PSendSysMessage(
            "DC capability warning: scope={} account={} persistedStale={} stateMismatch={} deltaSeconds={} liveLastSeen='{}' persistedLastSeen='{}' liveNegotiatedCaps=0x{:X} persistedNegotiatedCaps=0x{:X} liveCharacter='{}' persistedCharacter='{}'",
            scope,
            accountId,
            persistedOlderThanLive ? 1 : 0,
            stateMismatch ? 1 : 0,
            persistedOlderThanLive
                ? (liveState.lastSeenUnix - persistedState.lastSeenUnix)
                : 0,
            FormatUnixTimestamp(liveState.lastSeenUnix),
            FormatUnixTimestamp(persistedState.lastSeenUnix),
            liveState.negotiatedCapabilities,
            persistedState.negotiatedCapabilities,
            liveState.lastCharacterName,
            persistedState.lastCharacterName);
    }

    bool TryResolvePlayerCapabilityLookup(std::string rawPlayerName,
        uint32& accountId, uint64& characterGuid, std::string& playerName,
        std::string& errorMessage, char const* usage)
    {
        std::string normalizedName = TrimWhitespace(std::move(rawPlayerName));
        if (normalizedName.empty())
        {
            errorMessage = usage;
            return false;
        }

        if (!normalizePlayerName(normalizedName))
        {
            errorMessage = "Invalid player name.";
            return false;
        }

        CharacterCacheEntry const* characterEntry =
            sCharacterCache->GetCharacterCacheByName(normalizedName);
        if (!characterEntry)
        {
            errorMessage = "Player not found in the character cache.";
            return false;
        }

        accountId = characterEntry->AccountId;
        characterGuid = characterEntry->Guid.GetCounter();
        playerName = characterEntry->Name;
        return true;
    }

    void PrintCapabilityStateLine(ChatHandler* handler, char const* scope,
        char const* source, uint32 accountId,
        DCAddon::SessionCapabilityState const& state,
        bool capabilityDebugEnabled,
        bool tooltipTransportDebugEnabled,
        bool breakingNewsTransportDebugEnabled)
    {
        handler->PSendSysMessage(
            "DC capability status: scope={} source={} account={} compatible={} clientVersion='{}' clientCaps=0x{:X} negotiatedCaps=0x{:X} capabilityDebug={} tooltipTransportDebug={} breakingNewsTransportDebug={}",
            scope,
            source,
            accountId,
            state.versionCompatible ? 1 : 0,
            state.clientVersionString,
            state.clientCapabilities,
            state.negotiatedCapabilities,
            capabilityDebugEnabled ? 1 : 0,
            tooltipTransportDebugEnabled ? 1 : 0,
            breakingNewsTransportDebugEnabled ? 1 : 0);

        if (state.lastSeenUnix != 0 || state.lastCharacterGuid != 0
            || !state.lastCharacterName.empty())
        {
            handler->PSendSysMessage(
                "DC capability metadata: scope={} lastSeen='{}' lastSeenUnix={} lastCharacterGuid={} lastCharacterName='{}'",
                scope,
                FormatUnixTimestamp(state.lastSeenUnix),
                state.lastSeenUnix,
                state.lastCharacterGuid,
                state.lastCharacterName);
        }

        PrintCapabilityFeatureLines(handler, scope, state);
        PrintCapabilityTransportLines(handler, scope, source, state);
    }

    void PrintCapabilityDiagnostics(ChatHandler* handler)
    {
        bool capabilityDebugEnabled =
            sConfigMgr->GetOption<bool>(CONFIG_CAPABILITY_DEBUG, false);
        bool protocolLoggingEnabled =
            sConfigMgr->GetOption<bool>(CONFIG_PROTOCOL_LOGGING, false);
        bool tooltipTransportDebugEnabled =
            sConfigMgr->GetOption<bool>(CONFIG_TOOLTIP_TRANSPORT_DEBUG, false);
        bool breakingNewsTransportDebugEnabled =
            sConfigMgr->GetOption<bool>(CONFIG_TRANSPORT_DEBUG, false);

        WorldSession* session = handler->GetSession();
        if (!session)
        {
            handler->PSendSysMessage(
                "DC capability lookup: scope=current session=0 account=0 liveRegistry=0 persisted=0 capabilityDebug={} protocolLogging={} tooltipTransportDebug={} breakingNewsTransportDebug={}",
                capabilityDebugEnabled ? 1 : 0,
                protocolLoggingEnabled ? 1 : 0,
                tooltipTransportDebugEnabled ? 1 : 0,
                breakingNewsTransportDebugEnabled ? 1 : 0);

            PrintBreakingNewsDecisionLine(handler, "effective", "none", 0,
                DCBreakingNews::EvaluateTransportDecision(
                    static_cast<DCAddon::SessionCapabilityState const*>(nullptr)));
            PrintProtocolErrorSummary(handler, "current", 0,
                protocolLoggingEnabled);
            return;
        }

        uint32 accountId = session->GetAccountId();
        DCAddon::SessionCapabilityState effectiveState;
        DCAddon::SessionCapabilityState liveState;
        DCAddon::SessionCapabilityState persistedState;
        bool hasEffectiveState =
            DCAddon::TryGetSessionCapabilityState(session, effectiveState);
        bool hasLiveState =
            DCAddon::TryGetLiveSessionCapabilityState(accountId, liveState);
        bool hasPersistedState =
            DCAddon::TryGetPersistedCapabilityState(accountId, persistedState);

        handler->PSendSysMessage(
            "DC capability lookup: scope=current session=1 account={} liveRegistry={} persisted={} capabilityDebug={} protocolLogging={} tooltipTransportDebug={} breakingNewsTransportDebug={}",
            accountId,
            hasLiveState ? 1 : 0,
            hasPersistedState ? 1 : 0,
            capabilityDebugEnabled ? 1 : 0,
            protocolLoggingEnabled ? 1 : 0,
            tooltipTransportDebugEnabled ? 1 : 0,
            breakingNewsTransportDebugEnabled ? 1 : 0);

        if (hasEffectiveState)
        {
            PrintCapabilityStateLine(handler, "effective",
                effectiveState.loadedFromPersistedFallback
                    ? "db-fallback"
                    : "session-registry",
                accountId, effectiveState, capabilityDebugEnabled,
                tooltipTransportDebugEnabled,
                breakingNewsTransportDebugEnabled);

            PrintBreakingNewsDecisionLine(handler, "effective",
                effectiveState.loadedFromPersistedFallback
                    ? "db-fallback"
                    : "session-registry",
                accountId,
                DCBreakingNews::EvaluateTransportDecision(&effectiveState));
        }
        else
        {
            PrintBreakingNewsDecisionLine(handler, "effective", "none",
                accountId,
                DCBreakingNews::EvaluateTransportDecision(
                    static_cast<DCAddon::SessionCapabilityState const*>(nullptr)));
        }

        if (hasPersistedState)
        {
            PrintCapabilityStateLine(handler, "persisted", "db-row",
                accountId, persistedState, capabilityDebugEnabled,
                tooltipTransportDebugEnabled,
                breakingNewsTransportDebugEnabled);

            PrintBreakingNewsDecisionLine(handler, "persisted", "db-row",
                accountId,
                DCBreakingNews::EvaluateTransportDecision(&persistedState));
        }

        if (hasLiveState && hasPersistedState)
            PrintCapabilityComparisonWarnings(handler, "current",
                accountId, liveState, persistedState);

        if (!hasEffectiveState && !hasPersistedState)
        {
            handler->SendSysMessage(
                "No DC capability state found for the current session/account.");
        }

        PrintCapabilityHistory(handler, "current", accountId,
            CAPABILITY_HISTORY_LIMIT);
        PrintProtocolErrorSummary(handler, "current", accountId,
            protocolLoggingEnabled);
    }

    void PrintCapabilityDiagnosticsForAccount(ChatHandler* handler,
        uint32 accountId, std::string const& playerName = "",
        uint64 characterGuid = 0)
    {
        bool capabilityDebugEnabled =
            sConfigMgr->GetOption<bool>(CONFIG_CAPABILITY_DEBUG, false);
        bool protocolLoggingEnabled =
            sConfigMgr->GetOption<bool>(CONFIG_PROTOCOL_LOGGING, false);
        bool tooltipTransportDebugEnabled =
            sConfigMgr->GetOption<bool>(CONFIG_TOOLTIP_TRANSPORT_DEBUG, false);
        bool breakingNewsTransportDebugEnabled =
            sConfigMgr->GetOption<bool>(CONFIG_TRANSPORT_DEBUG, false);

        DCAddon::SessionCapabilityState liveState;
        DCAddon::SessionCapabilityState persistedState;
        bool hasLiveState =
            DCAddon::TryGetLiveSessionCapabilityState(accountId, liveState);
        bool hasPersistedState =
            DCAddon::TryGetPersistedCapabilityState(accountId, persistedState);

        if (!playerName.empty() || characterGuid != 0)
        {
            handler->PSendSysMessage(
                "DC capability lookup: scope=player account={} characterGuid={} characterName='{}' liveRegistry={} persisted={} capabilityDebug={} protocolLogging={} tooltipTransportDebug={} breakingNewsTransportDebug={}",
                accountId,
                characterGuid,
                playerName,
                hasLiveState ? 1 : 0,
                hasPersistedState ? 1 : 0,
                capabilityDebugEnabled ? 1 : 0,
                protocolLoggingEnabled ? 1 : 0,
                tooltipTransportDebugEnabled ? 1 : 0,
                breakingNewsTransportDebugEnabled ? 1 : 0);
        }
        else
        {
            handler->PSendSysMessage(
                "DC capability lookup: scope=account account={} liveRegistry={} persisted={} capabilityDebug={} protocolLogging={} tooltipTransportDebug={} breakingNewsTransportDebug={}",
                accountId,
                hasLiveState ? 1 : 0,
                hasPersistedState ? 1 : 0,
                capabilityDebugEnabled ? 1 : 0,
                protocolLoggingEnabled ? 1 : 0,
                tooltipTransportDebugEnabled ? 1 : 0,
                breakingNewsTransportDebugEnabled ? 1 : 0);
        }

        if (hasLiveState)
        {
            PrintCapabilityStateLine(handler, "live", "session-registry",
                accountId, liveState, capabilityDebugEnabled,
                tooltipTransportDebugEnabled,
                breakingNewsTransportDebugEnabled);

            PrintBreakingNewsDecisionLine(handler, "live",
                "session-registry", accountId,
                DCBreakingNews::EvaluateTransportDecision(&liveState));
        }

        if (hasPersistedState)
        {
            PrintCapabilityStateLine(handler, "persisted", "db-row",
                accountId, persistedState, capabilityDebugEnabled,
                tooltipTransportDebugEnabled,
                breakingNewsTransportDebugEnabled);

            PrintBreakingNewsDecisionLine(handler, "persisted", "db-row",
                accountId,
                DCBreakingNews::EvaluateTransportDecision(&persistedState));
        }
        else if (!hasLiveState)
        {
            PrintBreakingNewsDecisionLine(handler,
                playerName.empty() ? "account" : "player",
                "none", accountId,
                DCBreakingNews::EvaluateTransportDecision(
                    static_cast<DCAddon::SessionCapabilityState const*>(nullptr)));
        }

        if (hasLiveState && hasPersistedState)
            PrintCapabilityComparisonWarnings(handler,
                playerName.empty() ? "account" : "player", accountId,
                liveState, persistedState);

        if (!hasLiveState && !hasPersistedState)
        {
            handler->SendSysMessage(
                "No DC capability state found for that account in either the live registry or the persisted fallback table.");
        }

        PrintCapabilityHistory(handler,
            playerName.empty() ? "account" : "player", accountId,
            CAPABILITY_HISTORY_LIMIT);
        PrintProtocolErrorSummary(handler,
            playerName.empty() ? "account" : "player", accountId,
            protocolLoggingEnabled);
    }

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
                ChatCommandBuilder("recent", HandleRecentCommand,
                    SEC_GAMEMASTER, Console::No),
                ChatCommandBuilder("push", HandlePushCommand,
                    SEC_GAMEMASTER, Console::No)
            };

            static ChatCommandTable commandTable =
            {
                ChatCommandBuilder("dccaps", HandleCapabilityStatusCommand,
                    SEC_GAMEMASTER, Console::No),
                ChatCommandBuilder("dcnews", breakingNewsSubCommands)
            };

            return commandTable;
        }

        static bool HandleCapabilityStatusCommand(ChatHandler* handler,
            char const* args)
        {
            std::string argsString = args ? args : "";
            std::istringstream argStream(argsString);
            std::string subcommand;

            if (!(argStream >> subcommand) || subcommand == "status")
            {
                PrintCapabilityDiagnostics(handler);
                return true;
            }

            if (subcommand == "account")
            {
                uint32 accountId = 0;
                if (!(argStream >> accountId) || accountId == 0)
                {
                    handler->SendSysMessage(
                        "Usage: .dccaps account <accountId>");
                    handler->SetSentErrorMessage(true);
                    return false;
                }

                PrintCapabilityDiagnosticsForAccount(handler, accountId);
                return true;
            }

            if (subcommand == "history")
            {
                CapabilityBrowseTarget target;
                std::string errorMessage;
                if (!TryResolveCapabilityBrowseTarget(handler, argStream,
                        CAPABILITY_HISTORY_LIMIT,
                        CAPABILITY_HISTORY_MAX_LIMIT,
                        "Usage: .dccaps history [limit] or .dccaps history account <accountId> [limit] or .dccaps history player <name> [limit]",
                        "Usage: .dccaps history player <name> [limit]",
                        target, errorMessage))
                {
                    handler->SendSysMessage(errorMessage);
                    handler->SetSentErrorMessage(true);
                    return false;
                }

                PrintCapabilityHistory(handler, target.scope.c_str(),
                    target.accountId, target.limit);
                return true;
            }

            if (subcommand == "errors")
            {
                CapabilityBrowseTarget target;
                std::string errorMessage;
                if (!TryResolveCapabilityBrowseTarget(handler, argStream,
                        PROTOCOL_ERROR_BROWSE_LIMIT,
                        PROTOCOL_ERROR_BROWSE_MAX_LIMIT,
                        "Usage: .dccaps errors [limit] or .dccaps errors account <accountId> [limit] or .dccaps errors player <name> [limit]",
                        "Usage: .dccaps errors player <name> [limit]",
                        target, errorMessage))
                {
                    handler->SendSysMessage(errorMessage);
                    handler->SetSentErrorMessage(true);
                    return false;
                }

                bool protocolLoggingEnabled = sConfigMgr->GetOption<bool>(
                    CONFIG_PROTOCOL_LOGGING, false);
                PrintProtocolErrorSummary(handler, target.scope.c_str(),
                    target.accountId, protocolLoggingEnabled);
                PrintProtocolErrorRows(handler, target.scope.c_str(),
                    target.accountId, target.limit);
                return true;
            }

            if (subcommand == "player")
            {
                std::string rawPlayerName;
                std::getline(argStream, rawPlayerName);

                uint32 accountId = 0;
                uint64 characterGuid = 0;
                std::string playerName;
                std::string errorMessage;
                if (!TryResolvePlayerCapabilityLookup(rawPlayerName, accountId,
                        characterGuid, playerName, errorMessage))
                {
                    handler->SendSysMessage(errorMessage);
                    handler->SetSentErrorMessage(true);
                    return false;
                }

                PrintCapabilityDiagnosticsForAccount(handler, accountId,
                    playerName, characterGuid);
                return true;
            }

            handler->SendSysMessage(
                "Usage: .dccaps [status] or .dccaps account <accountId> or .dccaps player <name> or .dccaps history ... or .dccaps errors ...");
            handler->SetSentErrorMessage(true);
            return false;
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
            char const* args)
        {
            std::string argsString = args ? args : "";
            std::istringstream argStream(argsString);
            CapabilityBrowseTarget target;
            std::string errorMessage;
            if (!TryResolveCapabilityBrowseTarget(handler, argStream,
                    BREAKING_NEWS_DELIVERY_LIMIT,
                    BREAKING_NEWS_DELIVERY_MAX_LIMIT,
                    "Usage: .dcnews status [limit] or .dcnews status account <accountId> [limit] or .dcnews status player <name> [limit]",
                    "Usage: .dcnews status player <name> [limit]",
                    target, errorMessage))
            {
                handler->SendSysMessage(errorMessage);
                handler->SetSentErrorMessage(true);
                return false;
            }

            if (target.scope == "current")
                PrintBreakingNewsStatusCurrent(handler, target.limit);
            else
                PrintBreakingNewsStatusForAccount(handler, target.accountId,
                    target.scope.c_str(), target.limit);

            return true;
        }

        static bool HandleRecentCommand(ChatHandler* handler,
            char const* args)
        {
            std::string argsString = args ? args : "";
            std::istringstream argStream(argsString);
            CapabilityBrowseTarget target;
            std::string errorMessage;
            if (!TryResolveCapabilityBrowseTarget(handler, argStream,
                    BREAKING_NEWS_DELIVERY_LIMIT,
                    BREAKING_NEWS_DELIVERY_MAX_LIMIT,
                    "Usage: .dcnews recent [limit] or .dcnews recent account <accountId> [limit] or .dcnews recent player <name> [limit]",
                    "Usage: .dcnews recent player <name> [limit]",
                    target, errorMessage))
            {
                handler->SendSysMessage(errorMessage);
                handler->SetSentErrorMessage(true);
                return false;
            }

            PrintBreakingNewsDeliveryRows(handler, target.scope.c_str(),
                target.accountId, target.limit);
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

            DCBreakingNews::TransportDecision decision =
                DCBreakingNews::EvaluateTransportDecision(handler->GetSession());
            if (!DCBreakingNews::SendToSession(handler->GetSession(),
                    "gm-push"))
            {
                handler->PSendSysMessage(
                    "No breaking news payload was sent: reason={} featureEnabled={} snapshotReady={} capabilitySource={} revision={} bodyBytes={}.",
                    decision.reason,
                    decision.featureEnabled ? 1 : 0,
                    decision.snapshotReady ? 1 : 0,
                    decision.capabilitySource,
                    decision.snapshot.revision,
                    decision.snapshot.body.size());
                handler->SetSentErrorMessage(true);
                return false;
            }

            handler->PSendSysMessage(
                "Breaking news packet sent to the native client cache for the current session: revision={} updatedAt='{}' updatedAtUnix={} bodyBytes={}. If the client is already in-world, it will apply the payload the next time Glue is active.",
                decision.snapshot.revision,
                FormatUnixTimestamp(decision.snapshot.updatedAt),
                decision.snapshot.updatedAt,
                decision.snapshot.body.size());
            return true;
        }
    };
}

void AddSC_dc_breaking_news_qol()
{
    new dc_breaking_news_command_script();
}