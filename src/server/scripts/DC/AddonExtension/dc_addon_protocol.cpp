/*
 * Dark Chaos - Addon Protocol Core Implementation
 * ================================================
 *
 * Main protocol handler that routes all DC addon messages.
 * Uses unified "DC" prefix with module-based routing.
 *
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "Common.h"
#include "dc_addon_collection.h"
#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "WorldSession.h"
#include "WorldPacket.h"
#include "Chat.h"
#include "SharedDefines.h"
#include "Log.h"
#include "Config.h"
#include "GameTime.h"
#include "Timer.h"
#include "DatabaseEnv.h"
#include "QueryCallback.h"
#include "AsyncCallbackProcessor.h"
#include "StringFormat.h"
#include "DC/CrossSystem/CrossSystemSeasonHelper.h"
#include "DC/CrossSystem/EventBus.h"
#include "DC/CrossSystem/CrossSystemCore.h"
#include "ObjectAccessor.h"
#include <unordered_map>
#include <algorithm>
#include <cctype>
#include <iomanip>
#include <memory>
#include <sstream>
#include <ctime>

// Forward declaration for S2C logging (defined later in file)
static bool g_S2CLoggingEnabled = false;
static void LogS2CMessageGlobal(Player* player, const std::string& module, uint8 opcode, size_t dataSize, bool updateStats, const std::string& payloadPreview, uint32 processingTimeMs = 0);
static void LogProtocolErrorEvent(Player* player, const std::string& payload, const std::string& eventType, const std::string& message);
static void UpdateProtocolStats(Player* player, const std::string& moduleCode, const std::string& transport, bool isRequest, bool isTimeout, bool isError, uint32 responseTimeMs = 0);
static uint32 PeekPendingRequestElapsedMs(Player* player, const std::string& requestId);
static std::string EscapeSQLString(std::string s);

namespace
{
    constexpr char const* CONFIG_CAPABILITY_DEBUG =
        "DC.Addon.CapabilityDebug.Enable";
    constexpr char const* TABLE_CLIENT_CAPS =
        "dc_addon_client_caps";
    constexpr char const* TABLE_CAPABILITY_HISTORY =
        "dc_addon_client_caps_history";
    constexpr char const* TABLE_FEATURE_TRANSPORT_AUDIT =
        "dc_addon_feature_transport_audit";
    constexpr char const* TABLE_PROTOCOL_ERRORS =
        "dc_addon_protocol_errors";
    constexpr char const* STATS_TRANSPORT_ADDON =
        "ADDON";
    constexpr char const* STATS_TRANSPORT_NATIVE =
        "NATIVE";
    constexpr char const* STATS_TRANSPORT_LEGACY_MIXED =
        "LEGACY_MIXED";
    constexpr char const* REQUEST_TYPE_NATIVE =
        "NATIVE";
    constexpr char const* COLUMN_NATIVE_BUILD_FINGERPRINT =
        "native_build_fingerprint";
    constexpr char const* COLUMN_DATA_REVISIONS_JSON =
        "data_revisions_json";
    constexpr uint32 MAX_CAPABILITY_HISTORY_ENTRIES = 12;

    // Resiliency fallback for tooltip enrichment requests.
    constexpr uint8 QOS_CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT = 0x08;
    constexpr uint8 QOS_SMSG_SPELL_TOOLTIP_ENRICHMENT = 0x17;
    constexpr uint32 QOS_ENRICHMENT_STATUS_NO_DATA = 3;

    bool IsCapabilityDebugEnabled()
    {
        return sConfigMgr->GetOption<bool>(CONFIG_CAPABILITY_DEBUG, false);
    }

    void LogCapabilityState(Player* player, char const* source,
        std::string const& clientVersionStr, uint32 clientCaps,
        uint32 negotiatedCaps, bool versionCompatible)
    {
        if (!IsCapabilityDebugEnabled() || !player || !player->GetSession())
            return;

        LOG_INFO("module.dc",
            "DC capability state source={} account={} player='{}' version='{}' clientCaps=0x{:X} negotiatedCaps=0x{:X} compatible={}",
            source, player->GetSession()->GetAccountId(), player->GetName(),
            clientVersionStr, clientCaps, negotiatedCaps, versionCompatible);
    }

    void LogCapabilityFallback(WorldSession* session,
        DCAddon::SessionCapabilityState const& state)
    {
        if (!IsCapabilityDebugEnabled() || !session)
            return;

        LOG_INFO("module.dc",
            "DC capability fallback source=db account={} version='{}' clientCaps=0x{:X} negotiatedCaps=0x{:X} compatible={}",
            session->GetAccountId(), state.clientVersionString,
            state.clientCapabilities, state.negotiatedCapabilities,
            state.versionCompatible);
    }

    bool DoesCharacterTableExist(char const* tableName)
    {
        if (!tableName || !*tableName)
            return false;

        return CharacterDatabase.Query(
            "SELECT 1 FROM information_schema.TABLES "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}' LIMIT 1",
            tableName) != nullptr;
    }

    bool DoesCharacterColumnExist(char const* tableName,
        char const* columnName)
    {
        if (!tableName || !*tableName || !columnName || !*columnName)
            return false;

        return CharacterDatabase.Query(
            "SELECT 1 FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{}' "
            "AND COLUMN_NAME = '{}' LIMIT 1",
            tableName, columnName) != nullptr;
    }

    bool HasFeatureTransportAuditTable()
    {
        static std::once_flag once;
        static bool exists = false;

        std::call_once(once, []()
        {
            exists = DoesCharacterTableExist(TABLE_FEATURE_TRANSPORT_AUDIT);
            if (!exists)
            {
                LOG_WARN("dc.addon",
                    "Feature transport audit table '{}' not found; "
                    "transport-fallback telemetry will stay disabled until "
                    "the SQL migration is applied.",
                    TABLE_FEATURE_TRANSPORT_AUDIT);
            }
        });

        return exists;
    }

    std::string SanitizeTransportAuditLabel(std::string value,
        std::size_t maxLength)
    {
        value.erase(std::remove_if(value.begin(), value.end(),
            [](unsigned char c)
            {
                return !(std::isalnum(c) || c == '-' || c == '_'
                    || c == '.');
            }), value.end());

        if (value.empty())
            value = "unknown";

        if (value.size() > maxLength)
            value.resize(maxLength);

        return value;
    }

    char const* ToTransportModeLabel(DCAddon::TransportMode transport)
    {
        switch (transport)
        {
            case DCAddon::TransportMode::NativeBridge:
                return "native";
            case DCAddon::TransportMode::Unavailable:
                return "unavailable";
            case DCAddon::TransportMode::AddonProtocol:
            default:
                return "addon";
        }
    }

    struct SessionTransportFeatureObservation
    {
        std::string transport;
        std::string reason;
        std::string capabilitySource;
        bool capabilityFromPersistedFallback = false;
    };

    static std::unordered_map<uint32,
        std::unordered_map<std::string, SessionTransportFeatureObservation>>
        s_SessionTransportFeatureObservations;
    static std::mutex s_SessionTransportFeatureObservationsMutex;

    bool ShouldRecordTransportObservation(
        DCAddon::TransportPolicyRequest const& request,
        DCAddon::TransportPolicyDecision const& decision)
    {
        if (!request.featureName || !*request.featureName)
            return false;

        if (!decision.hasCapabilityState
            && decision.reason == request.noCapabilityStateReason)
            return false;

        return true;
    }

    void RecordTransportObservation(Player* player,
        DCAddon::TransportPolicyRequest const& request,
        DCAddon::TransportPolicyDecision const& decision)
    {
        if (!player || !player->GetSession() || !ShouldRecordTransportObservation(
                request, decision) || !HasFeatureTransportAuditTable())
            return;

        uint32 accountId = player->GetSession()->GetAccountId();
        uint32 guid = player->GetGUID().GetCounter();
        if (accountId == 0 || guid == 0)
            return;

        std::string featureName = SanitizeTransportAuditLabel(
            request.featureName, 64);
        SessionTransportFeatureObservation observation;
        observation.transport = ToTransportModeLabel(decision.transport);
        observation.reason = SanitizeTransportAuditLabel(decision.reason, 64);
        observation.capabilitySource = SanitizeTransportAuditLabel(
            decision.capabilitySource, 32);
        observation.capabilityFromPersistedFallback =
            decision.capabilityFromPersistedFallback;

        {
            std::lock_guard<std::mutex> lock(
                s_SessionTransportFeatureObservationsMutex);
            auto& byFeature = s_SessionTransportFeatureObservations[accountId];
            auto itr = byFeature.find(featureName);
            if (itr != byFeature.end()
                && itr->second.transport == observation.transport
                && itr->second.reason == observation.reason
                && itr->second.capabilitySource == observation.capabilitySource
                && itr->second.capabilityFromPersistedFallback
                    == observation.capabilityFromPersistedFallback)
                return;

            byFeature[featureName] = observation;
        }

        uint32 nativeObservations =
            decision.transport == DCAddon::TransportMode::NativeBridge ? 1 : 0;
        uint32 addonObservations =
            decision.transport == DCAddon::TransportMode::AddonProtocol ? 1 : 0;
        uint32 unavailableObservations =
            decision.transport == DCAddon::TransportMode::Unavailable ? 1 : 0;
        uint32 clientCaps = decision.hasCapabilityState
            ? decision.capabilityState.clientCapabilities
            : 0;
        uint32 negotiatedCaps = decision.hasCapabilityState
            ? decision.capabilityState.negotiatedCapabilities
            : 0;
        std::string buildFingerprint = decision.hasCapabilityState
            ? SanitizeTransportAuditLabel(
                decision.capabilityState.nativeBuildFingerprint, 96)
            : std::string();
        std::string escapedName = EscapeSQLString(player->GetName());
        std::string escapedFeature = EscapeSQLString(featureName);
        std::string escapedTransport = EscapeSQLString(observation.transport);
        std::string escapedReason = EscapeSQLString(observation.reason);
        std::string escapedCapabilitySource =
            EscapeSQLString(observation.capabilitySource);
        std::string escapedFingerprint = EscapeSQLString(buildFingerprint);

        CharacterDatabase.Execute(
            "INSERT INTO dc_addon_feature_transport_audit "
            "(guid, account_id, character_name, feature_name, "
            "native_observations, addon_observations, "
            "unavailable_observations, last_transport, last_reason, "
            "last_capability_source, last_client_caps, "
            "last_negotiated_caps, last_native_build_fingerprint, "
            "capability_from_persisted_fallback) "
            "VALUES ({}, {}, '{}', '{}', {}, {}, {}, '{}', '{}', '{}', "
            "{}, {}, '{}', {}) "
            "ON DUPLICATE KEY UPDATE "
            "account_id = VALUES(account_id), "
            "character_name = VALUES(character_name), "
            "native_observations = native_observations + {}, "
            "addon_observations = addon_observations + {}, "
            "unavailable_observations = unavailable_observations + {}, "
            "last_transport = VALUES(last_transport), "
            "last_reason = VALUES(last_reason), "
            "last_capability_source = VALUES(last_capability_source), "
            "last_client_caps = VALUES(last_client_caps), "
            "last_negotiated_caps = VALUES(last_negotiated_caps), "
            "last_native_build_fingerprint = "
            "VALUES(last_native_build_fingerprint), "
            "capability_from_persisted_fallback = "
            "VALUES(capability_from_persisted_fallback), "
            "last_seen = CURRENT_TIMESTAMP",
            guid, accountId, escapedName, escapedFeature,
            nativeObservations, addonObservations, unavailableObservations,
            escapedTransport, escapedReason, escapedCapabilitySource,
            clientCaps, negotiatedCaps, escapedFingerprint,
            decision.capabilityFromPersistedFallback ? 1 : 0,
            nativeObservations, addonObservations, unavailableObservations);
    }

    void ClearTransportObservations(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        uint32 accountId = player->GetSession()->GetAccountId();
        if (accountId == 0)
            return;

        std::lock_guard<std::mutex> lock(
            s_SessionTransportFeatureObservationsMutex);
        s_SessionTransportFeatureObservations.erase(accountId);
    }

    bool HasClientCapsMetadataColumns()
    {
        static std::once_flag once;
        static bool exists = false;

        std::call_once(once, []()
        {
            exists = DoesCharacterColumnExist(TABLE_CLIENT_CAPS,
                COLUMN_NATIVE_BUILD_FINGERPRINT)
                && DoesCharacterColumnExist(TABLE_CLIENT_CAPS,
                    COLUMN_DATA_REVISIONS_JSON);
            if (!exists)
            {
                LOG_WARN("module.dc",
                    "DC capability metadata columns missing on '{}'; native build fingerprints and data revisions will stay session-only until the SQL migration is applied.",
                    TABLE_CLIENT_CAPS);
            }
        });

        return exists;
    }

    bool HasCapabilityHistoryMetadataColumns()
    {
        static std::once_flag once;
        static bool exists = false;

        std::call_once(once, []()
        {
            exists = DoesCharacterColumnExist(TABLE_CAPABILITY_HISTORY,
                COLUMN_NATIVE_BUILD_FINGERPRINT)
                && DoesCharacterColumnExist(TABLE_CAPABILITY_HISTORY,
                    COLUMN_DATA_REVISIONS_JSON);
            if (!exists)
            {
                LOG_WARN("module.dc",
                    "DC capability metadata columns missing on '{}'; handshake metadata history will stay session-only until the SQL migration is applied.",
                    TABLE_CAPABILITY_HISTORY);
            }
        });

        return exists;
    }

    bool HasCapabilityHistoryTable()
    {
        static std::once_flag once;
        static bool exists = false;

        std::call_once(once, []()
        {
            exists = DoesCharacterTableExist(TABLE_CAPABILITY_HISTORY);
            if (!exists)
            {
                LOG_WARN("module.dc",
                    "DC capability history table '{}' not found; capability-transition history will stay disabled until the SQL migration is applied.",
                    TABLE_CAPABILITY_HISTORY);
            }
        });

        return exists;
    }

    bool HasProtocolErrorTable()
    {
        static std::once_flag once;
        static bool exists = false;

        std::call_once(once, []()
        {
            exists = DoesCharacterTableExist(TABLE_PROTOCOL_ERRORS);
            if (!exists)
            {
                LOG_WARN("module.dc",
                    "DC addon protocol error table '{}' not found; protocol error events will not be persisted until the SQL schema is present.",
                    TABLE_PROTOCOL_ERRORS);
            }
        });

        return exists;
    }

    bool TrySendQoSTooltipFallback(Player* player, const DCAddon::ParsedMessage& parsed)
    {
        if (!player || !player->GetSession())
            return false;

        if (parsed.GetModule() != DCAddon::Module::QOS || parsed.GetOpcode() != QOS_CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT)
            return false;

        // Expected payload: requestId|spellId|contextHash.
        if (parsed.GetDataCount() < 3)
            return false;

        uint32 requestId = parsed.GetUInt32(0);
        uint32 spellId = parsed.GetUInt32(1);
        uint32 contextHash = parsed.GetUInt32(2);

        DCAddon::Message fallback(DCAddon::Module::QOS, QOS_SMSG_SPELL_TOOLTIP_ENRICHMENT);
        if (parsed.HasRequestId())
            fallback.SetRequestId(parsed.GetRequestId());

        fallback
            .Add(requestId)
            .Add(spellId)
            .Add(contextHash)
            .Add(QOS_ENRICHMENT_STATUS_NO_DATA)
            .Add(std::string(""));
        fallback.Send(player);

        LOG_ERROR(
            "module.dc",
            "QoS tooltip fallback responded for missing handler (module={}, opcode=0x{:02X}, rid={}, requestId={}, spellId={}, contextHash={})",
            parsed.GetModule(),
            parsed.GetOpcode(),
            parsed.GetRequestId(),
            requestId,
            spellId,
            contextHash);

        return true;
    }
}

static std::string NormalizeHandshakeVersionString(const DCAddon::ParsedMessage& msg)
{
    std::string version = msg.GetString(0);
    if (version.find('|') == std::string::npos && msg.GetDataCount() >= 2)
    {
        std::string caps = msg.GetString(1);
        if (!caps.empty() && std::all_of(caps.begin(), caps.end(), [](unsigned char c) { return std::isdigit(c); }))
        {
            version += "|" + caps;
        }
    }
    return version;
}

static uint32 ParseHandshakeRevisionValue(DCAddon::JsonValue const& value)
{
    if (value.IsNumber())
    {
        double parsed = value.AsNumber();
        return parsed > 0 ? static_cast<uint32>(parsed) : 0;
    }

    if (value.IsString())
    {
        std::string const raw = value.AsString();
        if (raw.empty())
            return 0;

        try
        {
            unsigned long parsed = std::stoul(raw);
            return parsed > 0 ? static_cast<uint32>(parsed) : 0;
        }
        catch (...)
        {
            return 0;
        }
    }

    return 0;
}

static DCAddon::ClientDataRevisionState ParseDataRevisionsJson(
    std::string const& revisionsJson)
{
    DCAddon::ClientDataRevisionState revisions;
    if (revisionsJson.empty() || revisionsJson.front() != '{')
        return revisions;

    DCAddon::JsonValue parsed = DCAddon::JsonParser::Parse(revisionsJson);
    if (!parsed.IsObject())
        return revisions;

    revisions.collectionCategories =
        ParseHandshakeRevisionValue(parsed["cc"]);
    revisions.collectionSources =
        ParseHandshakeRevisionValue(parsed["cs"]);
    revisions.collectionShop =
        ParseHandshakeRevisionValue(parsed["shop"]);
    revisions.collectionSets =
        ParseHandshakeRevisionValue(parsed["set"]);
    revisions.collectionTransmog =
        ParseHandshakeRevisionValue(parsed["xmog"]);

    if (revisions.collectionCategories == 0)
        revisions.collectionCategories =
            ParseHandshakeRevisionValue(parsed["collectionCategories"]);
    if (revisions.collectionSources == 0)
        revisions.collectionSources =
            ParseHandshakeRevisionValue(parsed["collectionSources"]);
    if (revisions.collectionShop == 0)
        revisions.collectionShop =
            ParseHandshakeRevisionValue(parsed["collectionShop"]);
    if (revisions.collectionSets == 0)
        revisions.collectionSets =
            ParseHandshakeRevisionValue(parsed["collectionSets"]);
    if (revisions.collectionTransmog == 0)
        revisions.collectionTransmog =
            ParseHandshakeRevisionValue(parsed["collectionTransmog"]);

    return revisions;
}

static std::string EncodeDataRevisionsJson(
    DCAddon::ClientDataRevisionState const& revisions)
{
    if (!revisions.HasAny())
        return std::string();

    DCAddon::JsonValue json;
    json.SetObject();
    if (revisions.collectionCategories != 0)
        json.Set("cc", static_cast<double>(revisions.collectionCategories));
    if (revisions.collectionSources != 0)
        json.Set("cs", static_cast<double>(revisions.collectionSources));
    if (revisions.collectionShop != 0)
        json.Set("shop", static_cast<double>(revisions.collectionShop));
    if (revisions.collectionSets != 0)
        json.Set("set", static_cast<double>(revisions.collectionSets));
    if (revisions.collectionTransmog != 0)
        json.Set("xmog", static_cast<double>(revisions.collectionTransmog));
    return json.Encode();
}

static std::string EncodeHandshakeMetadataJson(
    std::string const& nativeBuildFingerprint,
    DCAddon::ClientDataRevisionState const& revisions)
{
    if (nativeBuildFingerprint.empty() && !revisions.HasAny())
        return std::string();

    DCAddon::JsonValue json;
    json.SetObject();
    json.Set("v", 1.0);

    if (!nativeBuildFingerprint.empty())
        json.Set("b", nativeBuildFingerprint);

    if (revisions.HasAny())
    {
        DCAddon::JsonValue data;
        data.SetObject();
        if (revisions.collectionCategories != 0)
            data.Set("cc", static_cast<double>(revisions.collectionCategories));
        if (revisions.collectionSources != 0)
            data.Set("cs", static_cast<double>(revisions.collectionSources));
        if (revisions.collectionShop != 0)
            data.Set("shop", static_cast<double>(revisions.collectionShop));
        if (revisions.collectionSets != 0)
            data.Set("set", static_cast<double>(revisions.collectionSets));
        if (revisions.collectionTransmog != 0)
            data.Set("xmog", static_cast<double>(revisions.collectionTransmog));
        json.Set("d", std::move(data));
    }

    return json.Encode();
}

struct HandshakeDataFeatureDecision
{
    char const* state = "OK_RUNTIME_CACHE";
    char const* reason = "runtime-fallback";
    uint32 requiredRevision = 0;
    uint32 installedRevision = 0;
    bool fallbackAllowed = true;
};

static HandshakeDataFeatureDecision EvaluateRevisionedDataFeature(
    uint32 installedRevision, uint32 requiredRevision, bool fallbackAllowed)
{
    HandshakeDataFeatureDecision decision;
    decision.requiredRevision = requiredRevision;
    decision.installedRevision = installedRevision;
    decision.fallbackAllowed = fallbackAllowed;

    if (requiredRevision != 0 && installedRevision == requiredRevision)
    {
        decision.state = "OK_NATIVE_DBC";
        decision.reason = "revision-match";
        return decision;
    }

    if (fallbackAllowed)
    {
        decision.state = "OK_RUNTIME_CACHE";
        decision.reason = installedRevision != 0
            ? "runtime-fallback-revision-mismatch"
            : "runtime-fallback-no-client-revision";
        return decision;
    }

    if (installedRevision != 0)
    {
        decision.state = "DISABLED_STALE_CLIENT_DATA";
        decision.reason = "revision-mismatch";
        return decision;
    }

    decision.state = "DISABLED_UNSUPPORTED_CLIENT";
    decision.reason = "client-revision-missing";
    return decision;
}

static HandshakeDataFeatureDecision ForceRuntimeDataFeature(
    uint32 installedRevision, uint32 requiredRevision, char const* reason)
{
    HandshakeDataFeatureDecision decision;
    decision.state = "OK_RUNTIME_CACHE";
    decision.reason = reason;
    decision.requiredRevision = requiredRevision;
    decision.installedRevision = installedRevision;
    decision.fallbackAllowed = true;
    return decision;
}

static std::string EncodeHandshakeAckMetadataJson(
    DCAddon::ClientHandshakeMetadata const& metadata)
{
    HandshakeDataFeatureDecision categoriesDecision =
        EvaluateRevisionedDataFeature(
            metadata.dataRevisions.collectionCategories,
            DCCollection::GetCollectionCategoriesRevisionCached(), false);

    HandshakeDataFeatureDecision sourcesDecision =
        EvaluateRevisionedDataFeature(
            metadata.dataRevisions.collectionSources,
            DCCollection::GetCollectionSourcesRevisionCached(), true);

    HandshakeDataFeatureDecision shopDecision =
        EvaluateRevisionedDataFeature(
            metadata.dataRevisions.collectionShop,
            DCCollection::GetCollectionShopRevisionCached(), true);

    uint32 setsRequiredRevision =
        DCCollection::GetCollectionSetsRevisionCached();
    bool virtualSetsEnabled = sConfigMgr->GetOption<bool>(
        "DCCollection.Transmog.VirtualSets.Enabled", true);
    HandshakeDataFeatureDecision setsDecision = virtualSetsEnabled
        ? ForceRuntimeDataFeature(
            metadata.dataRevisions.collectionSets,
            setsRequiredRevision,
            "runtime-fallback-virtual-sets-enabled")
        : EvaluateRevisionedDataFeature(
            metadata.dataRevisions.collectionSets,
            setsRequiredRevision, true);

    HandshakeDataFeatureDecision transmogDecision =
        EvaluateRevisionedDataFeature(
            metadata.dataRevisions.collectionTransmog,
            DCCollection::GetTransmogDefinitionsSyncVersionCached(), true);

    DCAddon::JsonValue featureStates;
    featureStates.SetObject();

    auto addFeatureState = [&featureStates](char const* key,
        HandshakeDataFeatureDecision const& decision)
    {
        DCAddon::JsonValue featureEntry;
        featureEntry.SetObject();
        featureEntry.Set("state", decision.state);
        featureEntry.Set("requiredRevision",
            static_cast<double>(decision.requiredRevision));
        if (decision.installedRevision != 0)
        {
            featureEntry.Set("installedRevision",
                static_cast<double>(decision.installedRevision));
        }
        featureEntry.Set("fallbackAllowed", decision.fallbackAllowed);
        featureEntry.Set("reason", decision.reason);
        featureStates.Set(key, std::move(featureEntry));
    };

    addFeatureState("collectionCategories", categoriesDecision);
    addFeatureState("collectionSources", sourcesDecision);
    addFeatureState("collectionShop", shopDecision);
    addFeatureState("collectionSets", setsDecision);
    addFeatureState("collectionTransmog", transmogDecision);

    DCAddon::JsonValue root;
    root.SetObject();
    root.Set("v", 1.0);
    root.Set("dataFeatureStates", std::move(featureStates));
    return root.Encode();
}

static DCAddon::ClientHandshakeMetadata ParseHandshakeMetadataJson(
    std::string const& metadataJson)
{
    DCAddon::ClientHandshakeMetadata metadata;
    if (metadataJson.empty() || metadataJson.front() != '{')
        return metadata;

    DCAddon::JsonValue parsed = DCAddon::JsonParser::Parse(metadataJson);
    if (!parsed.IsObject())
        return metadata;

    metadata.metadataJson = metadataJson;

    DCAddon::JsonValue const& fingerprint = parsed["b"];
    if (fingerprint.IsString())
        metadata.nativeBuildFingerprint = fingerprint.AsString();
    else if (parsed["nativeBuildFingerprint"].IsString())
        metadata.nativeBuildFingerprint =
            parsed["nativeBuildFingerprint"].AsString();

    DCAddon::JsonValue const& dataRevisions = parsed["d"];
    if (dataRevisions.IsObject())
        metadata.dataRevisions = ParseDataRevisionsJson(dataRevisions.Encode());

    return metadata;
}

static DCAddon::ClientHandshakeMetadata ParseHandshakeMetadata(
    DCAddon::ParsedMessage const& msg)
{
    if (msg.GetDataCount() < 2)
        return DCAddon::ClientHandshakeMetadata();

    for (size_t index = 1; index < msg.GetDataCount(); ++index)
    {
        std::string metadataJson = msg.GetString(index);
        if (!metadataJson.empty() && metadataJson.front() == '{')
            return ParseHandshakeMetadataJson(metadataJson);
    }

    return DCAddon::ClientHandshakeMetadata();
}

static void StoreClientCaps(Player* player, const std::string& clientVersionStr,
    uint32 clientCaps, uint32 negotiatedCaps,
    DCAddon::ClientHandshakeMetadata const& metadata)
{
    if (!player || !player->GetSession())
        return;

    if (HasClientCapsMetadataColumns())
    {
        CharacterDatabase.Execute(
            "INSERT INTO dc_addon_client_caps "
            "(account_id, addon_name, version_string, capabilities, negotiated_caps, native_build_fingerprint, data_revisions_json, last_character_guid, last_character_name, last_seen) "
            "VALUES ({}, 'DC', '{}', {}, {}, '{}', '{}', {}, '{}', NOW()) "
            "ON DUPLICATE KEY UPDATE "
            "version_string = VALUES(version_string), "
            "capabilities = VALUES(capabilities), "
            "negotiated_caps = VALUES(negotiated_caps), "
            "native_build_fingerprint = VALUES(native_build_fingerprint), "
            "data_revisions_json = VALUES(data_revisions_json), "
            "last_character_guid = VALUES(last_character_guid), "
            "last_character_name = VALUES(last_character_name), "
            "last_seen = NOW()",
            player->GetSession()->GetAccountId(),
            EscapeSQLString(clientVersionStr),
            clientCaps,
            negotiatedCaps,
            EscapeSQLString(metadata.nativeBuildFingerprint),
            EscapeSQLString(EncodeDataRevisionsJson(metadata.dataRevisions)),
            player->GetGUID().GetCounter(),
            EscapeSQLString(player->GetName())
        );
        return;
    }

    CharacterDatabase.Execute(
        "INSERT INTO dc_addon_client_caps "
        "(account_id, addon_name, version_string, capabilities, negotiated_caps, last_character_guid, last_character_name, last_seen) "
        "VALUES ({}, 'DC', '{}', {}, {}, {}, '{}', NOW()) "
        "ON DUPLICATE KEY UPDATE "
        "version_string = VALUES(version_string), "
        "capabilities = VALUES(capabilities), "
        "negotiated_caps = VALUES(negotiated_caps), "
        "last_character_guid = VALUES(last_character_guid), "
        "last_character_name = VALUES(last_character_name), "
        "last_seen = NOW()",
        player->GetSession()->GetAccountId(),
        EscapeSQLString(clientVersionStr),
        clientCaps,
        negotiatedCaps,
        player->GetGUID().GetCounter(),
        EscapeSQLString(player->GetName())
    );
}

static void StoreCapabilityHistory(Player* player,
    std::string const& clientVersionStr, uint32 clientCaps,
    uint32 negotiatedCaps, bool versionCompatible, char const* source,
    DCAddon::ClientHandshakeMetadata const& metadata)
{
    if (!player || !player->GetSession() || !HasCapabilityHistoryTable())
        return;

    uint32 accountId = player->GetSession()->GetAccountId();
    uint64 characterGuid = player->GetGUID().GetCounter();
    std::string characterName = player->GetName();
    bool hasMetadataColumns = HasCapabilityHistoryMetadataColumns();
    std::string sourceStr = source ? source : "unknown";
    std::string fingerprint = metadata.nativeBuildFingerprint;
    std::string revisionsJson = EncodeDataRevisionsJson(metadata.dataRevisions);

    // History is telemetry only: nothing downstream waits on it, so run the
    // dedup SELECT async instead of blocking the handshake on a DB roundtrip
    // (this SELECT dominated CORE handshake latency).
    std::string selectSql = Acore::StringFormat(
        hasMetadataColumns
            ? "SELECT version_string, capabilities, negotiated_caps, compatible, "
              "character_guid, character_name, native_build_fingerprint, data_revisions_json "
              "FROM dc_addon_client_caps_history "
              "WHERE account_id = {} AND addon_name = 'DC' "
              "ORDER BY seen_at DESC, id DESC LIMIT 1"
            : "SELECT version_string, capabilities, negotiated_caps, compatible, "
              "character_guid, character_name "
              "FROM dc_addon_client_caps_history "
              "WHERE account_id = {} AND addon_name = 'DC' "
              "ORDER BY seen_at DESC, id DESC LIMIT 1",
        accountId);

    DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(selectSql)
        .WithCallback([accountId, characterGuid, characterName = std::move(characterName),
            clientVersionStr = clientVersionStr, clientCaps, negotiatedCaps,
            versionCompatible, hasMetadataColumns, sourceStr = std::move(sourceStr),
            fingerprint = std::move(fingerprint),
            revisionsJson = std::move(revisionsJson)](QueryResult latestResult)
    {
        if (latestResult)
        {
            Field* latestFields = latestResult->Fetch();
            if (latestFields[0].Get<std::string>() == clientVersionStr &&
                latestFields[1].Get<uint32>() == clientCaps &&
                latestFields[2].Get<uint32>() == negotiatedCaps &&
                (latestFields[3].Get<uint8>() != 0) == versionCompatible &&
                latestFields[4].Get<uint64>() == characterGuid &&
                latestFields[5].Get<std::string>() == characterName &&
                (!hasMetadataColumns
                    || (latestFields[6].Get<std::string>() == fingerprint
                        && latestFields[7].Get<std::string>() == revisionsJson)))
            {
                return;
            }
        }

        if (hasMetadataColumns)
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_addon_client_caps_history "
                "(account_id, addon_name, source, version_string, capabilities, negotiated_caps, compatible, character_guid, character_name, native_build_fingerprint, data_revisions_json) "
                "VALUES ({}, 'DC', '{}', '{}', {}, {}, {}, {}, '{}', '{}', '{}')",
                accountId,
                EscapeSQLString(sourceStr),
                EscapeSQLString(clientVersionStr),
                clientCaps,
                negotiatedCaps,
                versionCompatible ? 1 : 0,
                characterGuid,
                EscapeSQLString(characterName),
                EscapeSQLString(fingerprint),
                EscapeSQLString(revisionsJson));
        }
        else
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_addon_client_caps_history "
                "(account_id, addon_name, source, version_string, capabilities, negotiated_caps, compatible, character_guid, character_name) "
                "VALUES ({}, 'DC', '{}', '{}', {}, {}, {}, {}, '{}')",
                accountId,
                EscapeSQLString(sourceStr),
                EscapeSQLString(clientVersionStr),
                clientCaps,
                negotiatedCaps,
                versionCompatible ? 1 : 0,
                characterGuid,
                EscapeSQLString(characterName));
        }

        CharacterDatabase.Execute(
            "DELETE FROM dc_addon_client_caps_history "
            "WHERE account_id = {} AND addon_name = 'DC' AND id NOT IN ("
                "SELECT id FROM ("
                    "SELECT id FROM dc_addon_client_caps_history "
                    "WHERE account_id = {} AND addon_name = 'DC' "
                    "ORDER BY seen_at DESC, id DESC LIMIT {}"
                ") AS recent_rows"
            ")",
            accountId, accountId, MAX_CAPABILITY_HISTORY_ENTRIES);
    }));
}

namespace
{
    std::unordered_map<uint32, DCAddon::SessionCapabilityState> s_SessionCapabilityRegistry;
    std::mutex s_SessionCapabilityRegistryMutex;

    uint32 GetSessionCapabilityRegistryKey(WorldSession* session)
    {
        if (!session)
            return 0;

        return session->GetAccountId();
    }

    uint32 GetSessionCapabilityRegistryKey(Player* player)
    {
        if (!player || !player->GetSession())
            return 0;

        return GetSessionCapabilityRegistryKey(player->GetSession());
    }

    bool TryGetLiveSessionCapabilityStateByAccount(uint32 accountId,
        DCAddon::SessionCapabilityState& out)
    {
        if (accountId == 0)
            return false;

        std::lock_guard<std::mutex> lock(s_SessionCapabilityRegistryMutex);
        auto itr = s_SessionCapabilityRegistry.find(accountId);
        if (itr == s_SessionCapabilityRegistry.end())
            return false;

        out = itr->second;
        out.loadedFromPersistedFallback = false;
        return true;
    }

    bool TryGetPersistedCapabilityStateByAccount(uint32 accountId,
        DCAddon::SessionCapabilityState& out)
    {
        if (accountId == 0)
            return false;

        QueryResult result = CharacterDatabase.Query(
            HasClientCapsMetadataColumns()
                ? "SELECT version_string, capabilities, negotiated_caps, "
                  "last_character_guid, last_character_name, "
                  "UNIX_TIMESTAMP(last_seen), native_build_fingerprint, data_revisions_json "
                  "FROM dc_addon_client_caps "
                  "WHERE account_id = {} AND addon_name = 'DC' "
                  "ORDER BY last_seen DESC LIMIT 1"
                : "SELECT version_string, capabilities, negotiated_caps, "
                  "last_character_guid, last_character_name, "
                  "UNIX_TIMESTAMP(last_seen) "
                  "FROM dc_addon_client_caps "
                  "WHERE account_id = {} AND addon_name = 'DC' "
                  "ORDER BY last_seen DESC LIMIT 1",
            accountId);
        if (!result)
            return false;

        Field* fields = result->Fetch();
        out = DCAddon::SessionCapabilityState();
        out.clientVersionString = fields[0].Get<std::string>();
        out.clientCapabilities = fields[1].Get<uint32>();
        out.negotiatedCapabilities = fields[2].Get<uint32>();
        out.lastCharacterGuid = fields[3].Get<uint64>();
        out.lastCharacterName = fields[4].Get<std::string>();
        out.lastSeenUnix = fields[5].Get<uint64>();
        out.versionCompatible =
            DCAddon::ProtocolVersion::GetServerVersion().IsCompatible(
                DCAddon::ProtocolVersion::ParseClientVersion(
                    out.clientVersionString));
        out.loadedFromPersistedFallback = true;
        if (HasClientCapsMetadataColumns())
        {
            out.nativeBuildFingerprint = fields[6].Get<std::string>();
            out.dataRevisions = ParseDataRevisionsJson(
                fields[7].Get<std::string>());
            out.metadataJson = EncodeHandshakeMetadataJson(
                out.nativeBuildFingerprint, out.dataRevisions);
        }
        return true;
    }
}

namespace DCAddon
{
    void SetSessionCapabilityState(Player* player,
        const std::string& clientVersionStr, uint32 clientCaps,
        uint32 negotiatedCaps, bool versionCompatible,
        ClientHandshakeMetadata const& metadata)
    {
        uint32 key = GetSessionCapabilityRegistryKey(player);
        if (key == 0)
            return;

        SessionCapabilityState state;
        state.clientVersionString = clientVersionStr;
        state.clientCapabilities = clientCaps;
        state.negotiatedCapabilities = negotiatedCaps;
        state.versionCompatible = versionCompatible;
        state.loadedFromPersistedFallback = false;
        state.lastCharacterGuid = player->GetGUID().GetCounter();
        state.lastCharacterName = player->GetName();
        state.lastSeenUnix = GameTime::GetGameTime().count();
        state.nativeBuildFingerprint = metadata.nativeBuildFingerprint;
        state.dataRevisions = metadata.dataRevisions;
        state.metadataJson = metadata.metadataJson;

        std::lock_guard<std::mutex> lock(s_SessionCapabilityRegistryMutex);
        s_SessionCapabilityRegistry[key] = std::move(state);
    }

    bool TryGetLiveSessionCapabilityState(uint32 accountId,
        SessionCapabilityState& out)
    {
        return TryGetLiveSessionCapabilityStateByAccount(accountId, out);
    }

    bool TryGetPersistedCapabilityState(uint32 accountId,
        SessionCapabilityState& out)
    {
        return TryGetPersistedCapabilityStateByAccount(accountId, out);
    }

    bool GetRecentCapabilityHistory(uint32 accountId, uint32 limit,
        std::vector<CapabilityHistoryEntry>& out)
    {
        out.clear();

        if (accountId == 0 || limit == 0 || !HasCapabilityHistoryTable())
            return false;

        QueryResult result = CharacterDatabase.Query(
                        HasCapabilityHistoryMetadataColumns()
                                ? "SELECT source, version_string, capabilities, negotiated_caps, compatible, "
                                    "character_guid, character_name, UNIX_TIMESTAMP(seen_at), native_build_fingerprint, data_revisions_json "
                                    "FROM dc_addon_client_caps_history "
                                    "WHERE account_id = {} AND addon_name = 'DC' "
                                    "ORDER BY seen_at DESC, id DESC LIMIT {}"
                                : "SELECT source, version_string, capabilities, negotiated_caps, compatible, "
                                    "character_guid, character_name, UNIX_TIMESTAMP(seen_at) "
                                    "FROM dc_addon_client_caps_history "
                                    "WHERE account_id = {} AND addon_name = 'DC' "
                                    "ORDER BY seen_at DESC, id DESC LIMIT {}",
                        accountId, std::min(limit, MAX_CAPABILITY_HISTORY_ENTRIES));
        if (!result)
            return true;

        do
        {
            Field* fields = result->Fetch();
            CapabilityHistoryEntry entry;
            entry.source = fields[0].Get<std::string>();
            entry.clientVersionString = fields[1].Get<std::string>();
            entry.clientCapabilities = fields[2].Get<uint32>();
            entry.negotiatedCapabilities = fields[3].Get<uint32>();
            entry.versionCompatible = fields[4].Get<uint8>() != 0;
            entry.characterGuid = fields[5].Get<uint64>();
            entry.characterName = fields[6].Get<std::string>();
            entry.seenUnix = fields[7].Get<uint64>();
            if (HasCapabilityHistoryMetadataColumns())
            {
                entry.nativeBuildFingerprint = fields[8].Get<std::string>();
                entry.dataRevisions = ParseDataRevisionsJson(
                    fields[9].Get<std::string>());
                entry.metadataJson = EncodeHandshakeMetadataJson(
                    entry.nativeBuildFingerprint, entry.dataRevisions);
            }
            out.push_back(std::move(entry));
        } while (result->NextRow());

        return true;
    }

    bool TryGetSessionCapabilityState(Player* player,
        SessionCapabilityState& out)
    {
        return TryGetSessionCapabilityState(player ? player->GetSession() : nullptr,
            out);
    }

    bool TryGetSessionCapabilityState(WorldSession* session,
        SessionCapabilityState& out)
    {
        uint32 key = GetSessionCapabilityRegistryKey(session);
        if (key == 0)
            return false;

        if (TryGetLiveSessionCapabilityStateByAccount(key, out))
            return true;

        if (!TryGetPersistedCapabilityStateByAccount(key, out))
            return false;

        LogCapabilityFallback(session, out);
        return true;
    }

    SessionCapabilityState GetSessionCapabilityState(Player* player)
    {
        SessionCapabilityState state;
        TryGetSessionCapabilityState(player, state);
        return state;
    }

    SessionCapabilityState GetSessionCapabilityState(WorldSession* session)
    {
        SessionCapabilityState state;
        TryGetSessionCapabilityState(session, state);
        return state;
    }

    void ClearSessionCapabilityState(Player* player)
    {
        uint32 key = GetSessionCapabilityRegistryKey(player);
        if (key == 0)
            return;

        if (IsCapabilityDebugEnabled() && player && player->GetSession())
        {
            LOG_INFO("module.dc",
                "DC capability state cleared account={} player='{}'",
                player->GetSession()->GetAccountId(), player->GetName());
        }

        std::lock_guard<std::mutex> lock(s_SessionCapabilityRegistryMutex);
        s_SessionCapabilityRegistry.erase(key);
    }

    uint32 GetSessionNegotiatedCapabilities(Player* player)
    {
        SessionCapabilityState state;
        return TryGetSessionCapabilityState(player, state)
            ? state.negotiatedCapabilities
            : 0;
    }

    uint32 GetSessionNegotiatedCapabilities(WorldSession* session)
    {
        SessionCapabilityState state;
        return TryGetSessionCapabilityState(session, state)
            ? state.negotiatedCapabilities
            : 0;
    }

    bool SessionSupportsCapability(Player* player, uint32 capability)
    {
        SessionCapabilityState state;
        return TryGetSessionCapabilityState(player, state)
            && state.HasNegotiatedCapability(capability);
    }

    bool SessionSupportsCapability(WorldSession* session, uint32 capability)
    {
        SessionCapabilityState state;
        return TryGetSessionCapabilityState(session, state)
            && state.HasNegotiatedCapability(capability);
    }

    TransportPolicyDecision ResolveTransportPolicy(
        SessionCapabilityState const* capabilityState,
        TransportPolicyRequest const& request)
    {
        TransportPolicyDecision decision;

        if (capabilityState)
        {
            decision.hasCapabilityState = true;
            decision.capabilityState = *capabilityState;
            decision.capabilityFromPersistedFallback =
                capabilityState->loadedFromPersistedFallback;
            decision.capabilitySource =
                capabilityState->loadedFromPersistedFallback
                ? "db-fallback"
                : "session-registry";
        }

        if (request.forceNative)
        {
            decision.transport = TransportMode::NativeBridge;
            decision.reason = request.forceNativeReason;
            return decision;
        }

        if (request.forceAddon)
        {
            decision.transport = request.allowAddonFallback
                ? TransportMode::AddonProtocol
                : TransportMode::Unavailable;
            decision.reason = request.allowAddonFallback
                ? request.forceAddonReason
                : "addon-fallback-disabled";
            return decision;
        }

        if (!decision.hasCapabilityState)
        {
            decision.transport = request.allowAddonFallback
                ? TransportMode::AddonProtocol
                : TransportMode::Unavailable;
            decision.reason = request.noCapabilityStateReason;
            return decision;
        }

        if (!decision.capabilityState.versionCompatible)
        {
            decision.transport = request.allowAddonFallback
                ? TransportMode::AddonProtocol
                : TransportMode::Unavailable;
            decision.reason = request.versionIncompatibleReason;
            return decision;
        }

        if (!decision.capabilityState.HasClientCapability(
                request.nativeCapability))
        {
            decision.transport = request.allowAddonFallback
                ? TransportMode::AddonProtocol
                : TransportMode::Unavailable;
            decision.reason = request.clientCapabilityMissingReason;
            return decision;
        }

        if (!decision.capabilityState.HasNegotiatedCapability(
                request.nativeCapability))
        {
            decision.transport = request.allowAddonFallback
                ? TransportMode::AddonProtocol
                : TransportMode::Unavailable;
            decision.reason = request.negotiatedCapabilityMissingReason;
            return decision;
        }

        if (!request.nativeEligible)
        {
            decision.transport = request.allowAddonFallback
                ? TransportMode::AddonProtocol
                : TransportMode::Unavailable;
            decision.reason = request.nativeIneligibleReason;
            return decision;
        }

        decision.transport = TransportMode::NativeBridge;
        decision.reason = request.nativeReadyReason;
        return decision;
    }

    TransportPolicyDecision ResolveTransportPolicy(Player* player,
        TransportPolicyRequest const& request)
    {
        SessionCapabilityState capabilityState;
        TransportPolicyDecision decision;
        if (TryGetSessionCapabilityState(player, capabilityState))
            decision = ResolveTransportPolicy(&capabilityState, request);
        else
            decision = ResolveTransportPolicy(
                static_cast<SessionCapabilityState const*>(nullptr), request);

        RecordTransportObservation(player, request, decision);
        return decision;
    }

    TransportPolicyDecision ResolveTransportPolicy(WorldSession* session,
        TransportPolicyRequest const& request)
    {
        SessionCapabilityState capabilityState;
        TransportPolicyDecision decision;
        if (TryGetSessionCapabilityState(session, capabilityState))
            decision = ResolveTransportPolicy(&capabilityState, request);
        else
            decision = ResolveTransportPolicy(
                static_cast<SessionCapabilityState const*>(nullptr), request);

        if (session)
            RecordTransportObservation(session->GetPlayer(), request, decision);

        return decision;
    }
}

// ============================================================================
// PROTOCOL METRICS - Real-time statistics for monitoring
// ============================================================================

struct ProtocolMetrics
{
    std::atomic<uint64_t> messagesReceived{0};
    std::atomic<uint64_t> messagesSent{0};
    std::atomic<uint64_t> cacheHits{0};
    std::atomic<uint64_t> cacheMisses{0};
    std::atomic<uint64_t> rateLimitDrops{0};
    std::atomic<uint64_t> parseErrors{0};
    std::atomic<uint64_t> handlerErrors{0};

    void Reset()
    {
        messagesReceived = 0;
        messagesSent = 0;
        cacheHits = 0;
        cacheMisses = 0;
        rateLimitDrops = 0;
        parseErrors = 0;
        handlerErrors = 0;
    }
};

static ProtocolMetrics g_ProtocolMetrics;

// Accessor for external monitoring
const ProtocolMetrics& GetProtocolMetrics() { return g_ProtocolMetrics; }

namespace DCAddon
{
    // ========================================================================
    // MESSAGE SENDING IMPLEMENTATION
    // ========================================================================

    // Forward declaration
    static void SendRaw(Player* player, const std::string& msg);

    bool IsS2CProtocolLoggingEnabled()
    {
        return g_S2CLoggingEnabled;
    }

    uint32 GetPendingRequestElapsedMs(Player* player, const std::string& requestId)
    {
        return requestId.empty() ? 0 : PeekPendingRequestElapsedMs(player, requestId);
    }

    void LogS2CMessage(Player* player, const std::string& module, uint8 opcode,
        size_t dataSize, bool updateStats, const std::string& payloadPreview,
        uint32 processingTimeMs)
    {
        LogS2CMessageGlobal(player, module, opcode, dataSize, updateStats,
            payloadPreview, processingTimeMs);
    }

    void Message::Send(Player* player) const
    {
        if (!player || !player->GetSession())
            return;

        // Generic native bridge: route over the dedicated native opcode when this
        // module has a negotiated native capability. Body = pipe-joined fields,
        // so the client reconstructs an identical plain addon message.
        {
            std::string nativeBody;
            for (auto const& field : _data)
            {
                if (!nativeBody.empty())
                    nativeBody += DELIMITER;
                nativeBody += field;
            }
            if (TrySendModuleNativeMessage(player, _module, _opcode, nativeBody))
                return;
        }

        uint32 sendStartMs = getMSTime();

        std::string effectiveRequestId = _requestId;
        if (effectiveRequestId.empty())
        {
            const std::string& ctxReqId = GetCurrentRequestId();
            if (IsSafeRequestId(ctxReqId))
                effectiveRequestId = ctxReqId;
        }

        std::string fullMessage;
        if (!effectiveRequestId.empty() && effectiveRequestId != _requestId)
        {
            Message tmp = *this;
            tmp.SetRequestId(effectiveRequestId);
            fullMessage = tmp.Build();
        }
        else
        {
            fullMessage = Build();
        }

        // Log S2C message if enabled
        if (g_S2CLoggingEnabled)
        {
            std::string preview = fullMessage.length() > 255 ? fullMessage.substr(0, 255) : fullMessage;
            uint32 processingTimeMs = effectiveRequestId.empty() ? 0 : PeekPendingRequestElapsedMs(player, effectiveRequestId);
            if (processingTimeMs == 0)
            {
                processingTimeMs = getMSTimeDiff(sendStartMs, getMSTime());
                if (processingTimeMs == 0)
                    processingTimeMs = 1;
            }
            LogS2CMessageGlobal(player, _module, _opcode, fullMessage.length(), effectiveRequestId.empty(), preview, processingTimeMs);
        }

        // Check if chunking is needed
        if (fullMessage.length() > MAX_CLIENT_MSG_SIZE - 10)
        {
            auto chunks = ChunkedMessage::Chunk(fullMessage);
            for (auto const& chunk : chunks)
            {
                SendRaw(player, chunk);
            }
        }
        else
        {
            SendRaw(player, fullMessage);
        }

        if (!effectiveRequestId.empty())
        {
            NotifyResponseSent(player, effectiveRequestId);
        }
    }

    static void SendRaw(Player* player, const std::string& msg)
    {
        // Build addon message using proper CHAT_MSG_WHISPER format
        // Format: "DC\t<payload>" - client parses prefix "DC" and message is the payload
        std::string fullMsg = std::string(DC_PREFIX) + "\t" + msg;
        WorldPacket data;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, fullMsg);
        player->SendDirectMessage(&data);
        g_ProtocolMetrics.messagesSent++;
    }

}  // namespace DCAddon

// Forward declarations for cross-module snapshot pushes
namespace DCAddon
{
    namespace World
    {
        void SendWorldContentSnapshot(Player* player);
    }
}

// ============================================================================
// CONFIGURATION
// ============================================================================

struct DCAddonProtocolConfig
{
    // Module enables
    bool EnableCore;
    bool EnableAOELoot;
    bool EnableSpectator;
    bool EnableUpgrade;
    bool EnableDuels;
    bool EnableMythicPlus;
    bool EnablePrestige;
    bool EnableSeasonal;
    bool EnableHinterlandBG;
    bool EnableLeaderboard;
    bool EnableTeleports;
    bool EnableGOMove;
    bool EnableNPCMove;
    bool EnableGroupFinder;
    bool EnableHotspot;
    bool EnableWorld;
    bool EnableEvents;
    bool EnableQoS;
    bool EnableCollection;
    bool EnableDecoration;

    // Security settings
    bool EnableDebugLog;
    bool EnableProtocolLogging;  // Log to dc_addon_protocol_log table
    uint32 MaxMessagesPerSecond;
    uint32 RateLimitAction;
    uint32 ChunkTimeoutMs;
    uint32 RequestTimeoutMs;
    uint32 MinGOMoveSecurity;
    uint32 MinNPCMoveSecurity;

    // Security limits (configurable for flexibility)
    uint32 MaxChunksPerMessage;      // Maximum chunks allowed per message (memory protection)
    uint32 MaxJsonPayloadSize;       // Maximum JSON payload size in bytes
    uint32 MaxPendingChunks;         // Maximum concurrent pending chunked messages per account

    // Version
    std::string ProtocolVersion;
};

static DCAddonProtocolConfig s_AddonConfig;

// ============================================================================
// REQUEST CONTEXT & ASYNC TRACKING
// ============================================================================

namespace DCAddon
{
    static thread_local std::string s_CurrentRequestId;

    void SetCurrentRequestContext(const std::string& requestId)
    {
        s_CurrentRequestId = requestId;
    }

    void ClearCurrentRequestContext()
    {
        s_CurrentRequestId.clear();
    }

    const std::string& GetCurrentRequestId()
    {
        return s_CurrentRequestId;
    }
}

struct PendingAddonRequest
{
    std::string requestId;
    std::string module;
    uint8 opcode = 0;
    uint32 guid = 0;
    // Real-time (steady clock) millisecond stamp at request registration.
    // NOTE: must NOT use GameTime::GetGameTimeMS() -- that only advances
    // once per world tick, so any request answered inside the same tick
    // records a zero elapsed time and processing_time_ms gets dropped.
    uint32 startTimeMs = 0;
};

struct CompletedAddonRequestTiming
{
    uint32 responseTimeMs = 0;
    uint32 completedAtMs = 0;
};

static std::unordered_map<uint32, std::unordered_map<std::string, PendingAddonRequest>> s_PendingRequests;
static std::unordered_map<uint32, std::unordered_map<std::string, CompletedAddonRequestTiming>> s_CompletedRequestTimings;
static std::mutex s_PendingRequestsMutex;

static void CleanupCompletedRequestTimingsLocked(uint32 accountId,
    uint32 nowMs)
{
    auto accountIt = s_CompletedRequestTimings.find(accountId);
    if (accountIt == s_CompletedRequestTimings.end())
        return;

    auto& completedMap = accountIt->second;
    uint32 retentionMs = std::max<uint32>(s_AddonConfig.RequestTimeoutMs, 1000);
    for (auto timingIt = completedMap.begin(); timingIt != completedMap.end(); )
    {
        if (getMSTimeDiff(timingIt->second.completedAtMs, nowMs) > retentionMs)
            timingIt = completedMap.erase(timingIt);
        else
            ++timingIt;
    }

    if (completedMap.empty())
        s_CompletedRequestTimings.erase(accountIt);
}

static uint32 TakeCompletedRequestElapsedMs(Player* player,
    const std::string& requestId)
{
    if (!player || !player->GetSession() || requestId.empty())
        return 0;

    uint32 accountId = player->GetSession()->GetAccountId();
    uint32 nowMs = getMSTime();

    std::lock_guard<std::mutex> lock(s_PendingRequestsMutex);
    CleanupCompletedRequestTimingsLocked(accountId, nowMs);

    auto accountIt = s_CompletedRequestTimings.find(accountId);
    if (accountIt == s_CompletedRequestTimings.end())
        return 0;

    auto& completedMap = accountIt->second;
    auto reqIt = completedMap.find(requestId);
    if (reqIt == completedMap.end())
        return 0;

    uint32 responseTimeMs = reqIt->second.responseTimeMs;
    completedMap.erase(reqIt);

    if (completedMap.empty())
        s_CompletedRequestTimings.erase(accountIt);

    return responseTimeMs;
}

static bool ShouldTrackPendingRequest(const DCAddon::ParsedMessage& msg)
{
    if (!msg.HasRequestId())
        return false;

    // These COLL requests are intentionally fire-and-forget and may not emit
    // a response payload on success.
    if (msg.GetModule() == DCAddon::Module::COLLECTION)
    {
        switch (msg.GetOpcode())
        {
            case DCAddon::Opcode::Collection::CMSG_USE_ITEM:
            case DCAddon::Opcode::Collection::CMSG_SET_FAVORITE:
            case DCAddon::Opcode::Collection::CMSG_COMMUNITY_RATE:
            case DCAddon::Opcode::Collection::CMSG_COMMUNITY_VIEW:
                return false;
            default:
                break;
        }
    }

    return true;
}

static void RegisterPendingRequest(Player* player, const DCAddon::ParsedMessage& msg)
{
    if (!player || !player->GetSession() || !ShouldTrackPendingRequest(msg))
        return;

    PendingAddonRequest pending;
    pending.requestId = msg.GetRequestId();
    pending.module = msg.GetModule();
    pending.opcode = msg.GetOpcode();
    pending.guid = player->GetGUID().GetCounter();
    pending.startTimeMs = getMSTime();

    uint32 accountId = player->GetSession()->GetAccountId();
    std::lock_guard<std::mutex> lock(s_PendingRequestsMutex);
    s_PendingRequests[accountId][pending.requestId] = std::move(pending);
}

static void CleanupExpiredRequests(Player* player)
{
    if (!player || !player->GetSession())
        return;

    uint32 accountId = player->GetSession()->GetAccountId();
    uint32 nowMs = getMSTime();

    std::lock_guard<std::mutex> lock(s_PendingRequestsMutex);
    auto it = s_PendingRequests.find(accountId);
    if (it == s_PendingRequests.end())
        return;

    auto& pendingMap = it->second;
    for (auto reqIt = pendingMap.begin(); reqIt != pendingMap.end(); )
    {
        if (getMSTimeDiff(reqIt->second.startTimeMs, nowMs) > s_AddonConfig.RequestTimeoutMs)
        {
            std::string payload = reqIt->second.module + DCAddon::DELIMITER + std::to_string(reqIt->second.opcode) +
                DCAddon::DELIMITER + "RID:" + reqIt->second.requestId;

            LogProtocolErrorEvent(player, payload, "timeout", "Addon request timed out");
            UpdateProtocolStats(player, reqIt->second.module,
                STATS_TRANSPORT_ADDON, true, true, false);
            reqIt = pendingMap.erase(reqIt);
        }
        else
        {
            ++reqIt;
        }
    }

    if (pendingMap.empty())
        s_PendingRequests.erase(it);
}

static uint32 PeekPendingRequestElapsedMs(Player* player, const std::string& requestId)
{
    if (!player || !player->GetSession() || requestId.empty())
        return 0;

    uint32 accountId = player->GetSession()->GetAccountId();
    uint32 nowMs = getMSTime();

    std::lock_guard<std::mutex> lock(s_PendingRequestsMutex);
    auto accountIt = s_PendingRequests.find(accountId);
    if (accountIt == s_PendingRequests.end())
        return 0;

    auto const& pendingMap = accountIt->second;
    auto reqIt = pendingMap.find(requestId);
    if (reqIt == pendingMap.end())
        return 0;

    // Use wrap-safe diff (getMSTime() is a uint32 that wraps every ~49 days).
    // Guarantee at least 1 ms so log rows stamp a non-zero processing_time_ms
    // for instant in-tick replies (otherwise the logger drops the column).
    uint32 delta = getMSTimeDiff(reqIt->second.startTimeMs, nowMs);
    if (delta == 0)
        delta = 1;
    return delta;
}

static uint32 ResolveC2SLogProcessingTimeMs(Player* player,
    const std::string& payload)
{
    if (!player || !player->GetSession())
        return 0;

    DCAddon::ParsedMessage parsed(payload);
    if (!parsed.IsValid() || !ShouldTrackPendingRequest(parsed))
        return 0;

    uint32 processingTimeMs =
        TakeCompletedRequestElapsedMs(player, parsed.GetRequestId());
    if (processingTimeMs != 0)
        return processingTimeMs;

    return PeekPendingRequestElapsedMs(player, parsed.GetRequestId());
}

namespace DCAddon
{
    void NotifyResponseSent(Player* player, const std::string& requestId)
    {
        if (!player || !player->GetSession() || requestId.empty())
            return;

        uint32 accountId = player->GetSession()->GetAccountId();
        uint32 nowMs = getMSTime();

        std::lock_guard<std::mutex> lock(s_PendingRequestsMutex);
        auto accountIt = s_PendingRequests.find(accountId);
        if (accountIt == s_PendingRequests.end())
            return;

        auto& pendingMap = accountIt->second;
        auto reqIt = pendingMap.find(requestId);
        if (reqIt == pendingMap.end())
            return;

        // Wrap-safe real-time delta (matches PeekPendingRequestElapsedMs).
        uint32 responseTimeMs = getMSTimeDiff(reqIt->second.startTimeMs, nowMs);
        if (responseTimeMs == 0)
            responseTimeMs = 1;

        if (s_AddonConfig.EnableProtocolLogging)
        {
            CleanupCompletedRequestTimingsLocked(accountId, nowMs);
            s_CompletedRequestTimings[accountId][requestId] =
            {
                responseTimeMs,
                nowMs,
            };
        }

        UpdateProtocolStats(player, reqIt->second.module,
            STATS_TRANSPORT_ADDON, false, false, false, responseTimeMs);
        pendingMap.erase(reqIt);

        if (pendingMap.empty())
            s_PendingRequests.erase(accountIt);
    }
}

static void LoadAddonConfig()
{
    s_AddonConfig.EnableCore        = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Core.Enable", true);
    s_AddonConfig.EnableAOELoot     = sConfigMgr->GetOption<bool>("DC.AddonProtocol.AOELoot.Enable", true);
    s_AddonConfig.EnableSpectator   = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Spectator.Enable", true);
    s_AddonConfig.EnableUpgrade     = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Upgrade.Enable", true);
    s_AddonConfig.EnableDuels       = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Duels.Enable", true);
    s_AddonConfig.EnableMythicPlus  = sConfigMgr->GetOption<bool>("DC.AddonProtocol.MythicPlus.Enable", true);
    s_AddonConfig.EnablePrestige    = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Prestige.Enable", true);
    s_AddonConfig.EnableSeasonal    = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Seasonal.Enable", true);
    s_AddonConfig.EnableHinterlandBG= sConfigMgr->GetOption<bool>("DC.AddonProtocol.HinterlandBG.Enable", true);
    s_AddonConfig.EnableLeaderboard = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Leaderboard.Enable", true);
    s_AddonConfig.EnableTeleports   = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Teleports.Enable", true);
    s_AddonConfig.EnableGOMove     = sConfigMgr->GetOption<bool>("DC.AddonProtocol.GOMove.Enable", true);
    s_AddonConfig.EnableNPCMove    = sConfigMgr->GetOption<bool>("DC.AddonProtocol.NPCMove.Enable", true);
    s_AddonConfig.EnableGroupFinder = sConfigMgr->GetOption<bool>("DC.AddonProtocol.GroupFinder.Enable", true);
    s_AddonConfig.EnableHotspot     = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Hotspot.Enable", true);
    s_AddonConfig.EnableWorld       = sConfigMgr->GetOption<bool>("DC.AddonProtocol.World.Enable", true);
    s_AddonConfig.EnableEvents      = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Events.Enable", true);
    s_AddonConfig.EnableQoS         = sConfigMgr->GetOption<bool>("DC.AddonProtocol.QoS.Enable", true);
    s_AddonConfig.EnableCollection  = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Collection.Enable", true);
    s_AddonConfig.EnableDecoration  = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Decoration.Enable", true);

    s_AddonConfig.EnableDebugLog        = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Debug.Enable", false);
    s_AddonConfig.EnableProtocolLogging = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Logging.Enable", false);
    s_AddonConfig.MaxMessagesPerSecond  = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.RateLimit.Messages", 30);
    s_AddonConfig.RateLimitAction       = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.RateLimit.Action", 0);
    s_AddonConfig.ChunkTimeoutMs        = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.ChunkTimeout", 5000);
    s_AddonConfig.RequestTimeoutMs      = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.RequestTimeoutMs", 8000);
    s_AddonConfig.MinGOMoveSecurity     = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.GOMove.MinSecurity", 1);
    s_AddonConfig.MinNPCMoveSecurity    = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.NPCMove.MinSecurity", 1);

    // Security limits (must match client-side DC.MAX_CHUNKS_PER_MESSAGE and DC.MAX_JSON_PAYLOAD_SIZE)
    s_AddonConfig.MaxChunksPerMessage   = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.Security.MaxChunksPerMessage", 2048);
    s_AddonConfig.MaxJsonPayloadSize    = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.Security.MaxJsonPayloadSize", 524288);
    s_AddonConfig.MaxPendingChunks      = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.Security.MaxPendingChunks", 5);

    // Set global flag for S2C logging (needed by Message::Send before config is accessible)
    g_S2CLoggingEnabled = s_AddonConfig.EnableProtocolLogging;

    if (s_AddonConfig.EnableProtocolLogging)
        HasProtocolErrorTable();

    s_AddonConfig.ProtocolVersion = "1.0.0";

    // Update router module enables
    auto& router = DCAddon::MessageRouter::Instance();
    router.SetModuleEnabled(DCAddon::Module::CORE, s_AddonConfig.EnableCore);
    router.SetModuleEnabled(DCAddon::Module::AOE_LOOT, s_AddonConfig.EnableAOELoot);
    router.SetModuleEnabled(DCAddon::Module::SPECTATOR, s_AddonConfig.EnableSpectator);
    router.SetModuleEnabled(DCAddon::Module::UPGRADE, s_AddonConfig.EnableUpgrade);
    router.SetModuleEnabled(DCAddon::Module::PHASED_DUELS, s_AddonConfig.EnableDuels);
    router.SetModuleEnabled(DCAddon::Module::MYTHIC_PLUS, s_AddonConfig.EnableMythicPlus);
    router.SetModuleEnabled(DCAddon::Module::PRESTIGE, s_AddonConfig.EnablePrestige);
    router.SetModuleEnabled(DCAddon::Module::SEASONAL, s_AddonConfig.EnableSeasonal);
    router.SetModuleEnabled(DCAddon::Module::HINTERLAND_BG, s_AddonConfig.EnableHinterlandBG);
    router.SetModuleEnabled(DCAddon::Module::LEADERBOARD, s_AddonConfig.EnableLeaderboard);
    router.SetModuleEnabled(DCAddon::Module::TELEPORTS, s_AddonConfig.EnableTeleports);
    router.SetModuleEnabled(DCAddon::Module::GOMOVE, s_AddonConfig.EnableGOMove);
    router.SetModuleEnabled(DCAddon::Module::NPCMOVE, s_AddonConfig.EnableNPCMove);
    router.SetModuleEnabled(DCAddon::Module::GROUP_FINDER, s_AddonConfig.EnableGroupFinder);
    router.SetModuleEnabled(DCAddon::Module::HOTSPOT, s_AddonConfig.EnableHotspot);
    router.SetModuleEnabled(DCAddon::Module::WORLD, s_AddonConfig.EnableWorld);
    router.SetModuleEnabled(DCAddon::Module::EVENTS, s_AddonConfig.EnableEvents);
    router.SetModuleEnabled(DCAddon::Module::QOS, s_AddonConfig.EnableQoS);
    router.SetModuleEnabled(DCAddon::Module::COLLECTION, s_AddonConfig.EnableCollection);
    router.SetModuleEnabled(DCAddon::Module::DECORATION, s_AddonConfig.EnableDecoration);
    router.SetModuleMinSecurity(DCAddon::Module::GOMOVE, s_AddonConfig.MinGOMoveSecurity);
    router.SetModuleMinSecurity(DCAddon::Module::NPCMOVE, s_AddonConfig.MinNPCMoveSecurity);
}

// ============================================================================
// PROTOCOL LOGGING (to dc_addon_protocol_log table)
// ============================================================================

// ============================================================================
// PROTOCOL LOGGING & STATS
// ============================================================================

// Extract module code from payload (everything before first delimiter, max 8 chars)
// Supports both ':' (AIO/Legacy) and '|' (DC Native) delimiters
static std::string ExtractModuleCode(const std::string& payload)
{
    if (payload.empty())
        return "UNKN";

    size_t delimPos = payload.find_first_of(":|");
    if (delimPos != std::string::npos && delimPos > 0)
    {
        return payload.substr(0, std::min(delimPos, static_cast<size_t>(8)));
    }

    return payload.substr(0, std::min(payload.length(), static_cast<size_t>(8)));
}

// Extract opcode calling generic number parser
static uint8 ExtractOpcode(const std::string& payload)
{
    size_t delimPos = payload.find_first_of(":|");
    if (delimPos == std::string::npos || delimPos + 1 >= payload.length())
        return 0;

    size_t opcodeStart = delimPos + 1;
    size_t opcodeEnd = payload.find_first_of(":|", opcodeStart);
    if (opcodeEnd == std::string::npos)
        opcodeEnd = payload.length();

    std::string opcodeStr = payload.substr(opcodeStart, opcodeEnd - opcodeStart);
    try {
        return static_cast<uint8>(std::stoul(opcodeStr));
    } catch (...) {
        return 0;
    }
}

// Some small, UI-critical requests should bypass rate limiting.
// This prevents prior high-volume transfers (e.g., transmog paging) from starving Outfits/Community.
static bool ShouldBypassRateLimit(const std::string& payload)
{
    std::string moduleCode = ExtractModuleCode(payload);
    if (moduleCode != DCAddon::Module::COLLECTION)
        return false;

    uint8 opcode = ExtractOpcode(payload);
    return opcode == DCAddon::Opcode::Collection::CMSG_GET_SAVED_OUTFITS
        || opcode == DCAddon::Opcode::Collection::CMSG_SAVE_OUTFIT
        || opcode == DCAddon::Opcode::Collection::CMSG_COMMUNITY_GET_LIST
        || opcode == DCAddon::Opcode::Collection::CMSG_APPLY_TRANSMOG_PREVIEW
        || opcode == DCAddon::Opcode::Collection::CMSG_SET_TRANSMOG
        || opcode == DCAddon::Opcode::Collection::CMSG_GET_TRANSMOG_STATE;
}

static std::string DetectRequestType(const std::string& payload)
{
    if (payload.empty())
        return "STANDARD";

    // Explicit AIO markers in payload preview.
    if (payload.rfind("AIO", 0) == 0 || payload.find("AIO|") != std::string::npos)
        return "AIO";

    // Pipe-based protocol payloads are DC wire format.
    if (payload.find('|') != std::string::npos)
    {
        if (payload.find("|J|") != std::string::npos || payload.find("|JSON|") != std::string::npos)
            return "DC_JSON";
        return "DC_PLAIN";
    }

    // Colon payloads are legacy; treat JSON-ish content as DC_JSON.
    if (payload.find(':') != std::string::npos)
    {
        if (payload.find('{') != std::string::npos || payload.find('[') != std::string::npos)
            return "DC_JSON";
        return "DC_PLAIN";
    }

    return "STANDARD";
}

struct ProtocolLogContext
{
    uint32 guid = 0;
    uint32 accountId = 0;
    std::string characterName;
};

static ProtocolLogContext BuildProtocolLogContext(Player* player)
{
    ProtocolLogContext context;
    if (!player || !player->GetSession())
        return context;

    context.guid = player->GetGUID().GetCounter();
    context.accountId = player->GetSession()->GetAccountId();
    context.characterName = player->GetName();
    return context;
}

static ProtocolLogContext BuildProtocolLogContext(WorldSession* session)
{
    ProtocolLogContext context;
    if (!session)
        return context;

    context.accountId = session->GetAccountId();
    if (Player* player = session->GetPlayer())
    {
        context.guid = player->GetGUID().GetCounter();
        context.characterName = player->GetName();
    }

    return context;
}

static std::string SanitizeModuleCode(std::string moduleCode)
{
    moduleCode.erase(std::remove_if(moduleCode.begin(), moduleCode.end(),
        [](char c) { return !isalnum(c) && c != '_'; }),
        moduleCode.end());

    if (moduleCode.empty())
        moduleCode = "UNKN";

    if (moduleCode.length() > 16)
        moduleCode = moduleCode.substr(0, 16);

    return moduleCode;
}

static std::string FormatNativePayloadPreview(uint16 nativeOpcode,
    std::string const& payloadPreview)
{
    std::ostringstream stream;
    stream << "native=0x" << std::uppercase << std::hex
        << std::setw(4) << std::setfill('0') << nativeOpcode;
    if (!payloadPreview.empty())
        stream << '|' << payloadPreview;

    std::string preview = stream.str();
    if (preview.length() > 255)
        preview.resize(255);
    return preview;
}

static uint8 GetLoggedOpcode(uint8 logicalOpcode, uint16 nativeOpcode)
{
    return logicalOpcode != 0
        ? logicalOpcode
        : static_cast<uint8>(nativeOpcode & 0xFF);
}

static char const* ToDirectionLabel(DCAddon::ProtocolLogDirection direction)
{
    return direction == DCAddon::ProtocolLogDirection::ServerToClient
        ? "S2C"
        : "C2S";
}

static void InsertProtocolErrorRow(ProtocolLogContext const& context,
    char const* direction, std::string const& requestType,
    std::string const& moduleCode, uint8 opcode,
    std::string const& eventType, std::string const& message,
    std::string const& payloadPreview)
{
    if (context.accountId == 0 && context.guid == 0
        && context.characterName.empty())
        return;

    std::string safeEventType = eventType;
    safeEventType.erase(std::remove_if(safeEventType.begin(),
        safeEventType.end(), [](char c)
        {
            return !isalnum(c) && c != '_' && c != '-';
        }), safeEventType.end());
    if (safeEventType.length() > 32)
        safeEventType = safeEventType.substr(0, 32);

    CharacterDatabase.Execute(
        "INSERT INTO dc_addon_protocol_errors "
        "(guid, account_id, character_name, direction, request_type, "
        "module, opcode, event_type, message, payload_preview) "
        "VALUES ({}, {}, '{}', '{}', '{}', '{}', {}, '{}', '{}', '{}')",
        context.guid,
        context.accountId,
        EscapeSQLString(context.characterName),
        EscapeSQLString(direction ? direction : "C2S"),
        EscapeSQLString(requestType),
        EscapeSQLString(moduleCode),
        opcode,
        EscapeSQLString(safeEventType),
        EscapeSQLString(message),
        EscapeSQLString(payloadPreview));
}

static void InsertProtocolLogRow(ProtocolLogContext const& context,
    char const* direction, std::string const& requestType,
    std::string const& moduleCode, uint8 opcode, size_t dataSize,
    std::string const& payloadPreview, std::string const& status,
    std::string const& errorMessage, uint32 processingTimeMs)
{
    if (context.accountId == 0 && context.guid == 0
        && context.characterName.empty())
        return;

    CharacterDatabase.Execute(
        "INSERT INTO dc_addon_protocol_log "
        "(guid, account_id, character_name, direction, request_type, "
        "module, opcode, data_size, data_preview, status, error_message, "
        "processing_time_ms) "
        "VALUES ({}, {}, '{}', '{}', '{}', '{}', {}, {}, '{}', '{}', '{}', "
        "NULLIF({}, 0))",
        context.guid,
        context.accountId,
        EscapeSQLString(context.characterName),
        EscapeSQLString(direction ? direction : "C2S"),
        EscapeSQLString(requestType),
        EscapeSQLString(moduleCode),
        opcode,
        dataSize,
        EscapeSQLString(payloadPreview),
        EscapeSQLString(status),
        EscapeSQLString(errorMessage),
        processingTimeMs);
}

static std::string EscapeSQLString(std::string s)
{
    std::string escaped;
    escaped.reserve(s.size() * 2);

    for (unsigned char c : s)
    {
        switch (c)
        {
            case '\0':
                escaped += "\\0";
                break;
            case '\n':
                escaped += "\\n";
                break;
            case '\r':
                escaped += "\\r";
                break;
            case '\t':
                escaped += "\\t";
                break;
            case '\\':
                escaped += "\\\\";
                break;
            case '\'':
                escaped += "\\'";
                break;
            case '"':
                escaped += "\\\"";
                break;
            case '\x1A':
                escaped += "\\Z";
                break;
            default:
                escaped.push_back(static_cast<char>(c));
                break;
        }
    }

    return escaped;
}

static std::string SanitizeStatsTransport(std::string transport)
{
    if (transport == STATS_TRANSPORT_ADDON
        || transport == STATS_TRANSPORT_NATIVE
        || transport == STATS_TRANSPORT_LEGACY_MIXED)
        return transport;

    return STATS_TRANSPORT_ADDON;
}

// Buffered Stats System to reduce DB IO
struct StatsEntry
{
    uint32 totalRequests = 0;
    uint32 totalResponses = 0;
    uint32 totalTimeouts = 0;
    uint32 totalErrors = 0;
    uint32 sumResponseTime = 0;
    uint32 maxResponseTime = 0;
    time_t firstRequest = 0;
    time_t lastRequest = 0;
    bool dirty = false;
};

using StatsByTransport = std::unordered_map<std::string, StatsEntry>;
using StatsByModule = std::unordered_map<std::string, StatsByTransport>;

// Map: Guid -> Module -> Transport -> StatsEntry
static std::unordered_map<uint32, StatsByModule> s_StatsBuffer;
static std::mutex s_StatsMutex;
static constexpr uint32 STATS_FLUSH_INTERVAL_MS = 30 * IN_MILLISECONDS;

static void FlushStats(uint32 guid = 0)
{
    std::lock_guard<std::mutex> lock(s_StatsMutex);

    if (s_StatsBuffer.empty()) return;

    // Use transaction for bulk updates
    auto trans = CharacterDatabase.BeginTransaction();

    for (auto it = s_StatsBuffer.begin(); it != s_StatsBuffer.end(); )
    {
        uint32 currentGuid = it->first;
        // If specific guid requested, skip others
        if (guid != 0 && currentGuid != guid)
        {
            ++it;
            continue;
        }

        for (auto& [module, statsByTransport] : it->second)
        {
            for (auto& [transport, stats] : statsByTransport)
            {
                if (!stats.dirty)
                    continue;

                // To avoid SQL injection risks on Module/transport, sanitize
                // them strictly or use parameters. Since we can't define new
                // PreparedStatements in core enum dynamically, we will simulate
                // it safely.

                trans->Append("INSERT INTO dc_addon_protocol_stats "
                    "(guid, module, transport, total_requests, total_responses, total_timeouts, total_errors, avg_response_time_ms, max_response_time_ms, first_request, last_request) "
                    "VALUES ({}, '{}', '{}', {}, {}, {}, {}, {}, {}, FROM_UNIXTIME({}), FROM_UNIXTIME({})) "
                    "ON DUPLICATE KEY UPDATE "
                    "total_requests = total_requests + {}, "
                    "total_responses = total_responses + {}, "
                    "total_timeouts = total_timeouts + {}, "
                    "total_errors = total_errors + {}, "
                    "avg_response_time_ms = (avg_response_time_ms * total_responses + {}) / GREATEST(1, total_responses + {}), "
                    "max_response_time_ms = GREATEST(max_response_time_ms, {}), "
                    "first_request = COALESCE(first_request, FROM_UNIXTIME({})), "
                    "last_request = FROM_UNIXTIME({})",
                    currentGuid, module, transport,
                    stats.totalRequests, stats.totalResponses,
                    stats.totalTimeouts, stats.totalErrors,
                    (stats.totalResponses > 0 ? stats.sumResponseTime / stats.totalResponses : 0),
                    stats.maxResponseTime, stats.firstRequest,
                    stats.lastRequest,
                    stats.totalRequests, stats.totalResponses,
                    stats.totalTimeouts, stats.totalErrors,
                    stats.sumResponseTime, stats.totalResponses,
                    stats.maxResponseTime,
                    stats.firstRequest,
                    stats.lastRequest
                );

                stats = StatsEntry(); // Reset delta stats
            }
        }

        // If flushing specific player, remove them from memory
        it = (guid != 0) ? s_StatsBuffer.erase(it) : ++it;
    }
    CharacterDatabase.CommitTransaction(trans);
}

// Update player statistics in buffer
static void UpdateProtocolStats(Player* player, const std::string& moduleCode, const std::string& transport, bool isRequest, bool isTimeout, bool isError, uint32 responseTimeMs)
{
    if (!s_AddonConfig.EnableProtocolLogging || !player) return;

    // Sanitize module code
    std::string safeModule = moduleCode;
    safeModule.erase(std::remove_if(safeModule.begin(), safeModule.end(),
        [](char c) { return !isalnum(c) && c != '_'; }), safeModule.end());
    if (safeModule.length() > 16) safeModule = safeModule.substr(0, 16);
    std::string safeTransport = SanitizeStatsTransport(transport);

    std::lock_guard<std::mutex> lock(s_StatsMutex);
    auto& stats =
        s_StatsBuffer[player->GetGUID().GetCounter()][safeModule][safeTransport];

    time_t now = time(nullptr);

    if (stats.firstRequest == 0)
        stats.firstRequest = now;

    if (isRequest)
        stats.totalRequests++;
    else
        stats.totalResponses++;

    if (isTimeout)
        stats.totalTimeouts++;
    if (isError)
        stats.totalErrors++;

    if (!isRequest)
    {
        stats.sumResponseTime += responseTimeMs;
        if (responseTimeMs > stats.maxResponseTime) stats.maxResponseTime = responseTimeMs;
    }
    stats.lastRequest = now;
    stats.dirty = true;
}

static void LogProtocolErrorEvent(Player* player, const std::string& payload, const std::string& eventType, const std::string& message)
{
    if (!s_AddonConfig.EnableProtocolLogging || !HasProtocolErrorTable())
        return;

    std::string moduleCode = SanitizeModuleCode(ExtractModuleCode(payload));
    uint8 opcode = ExtractOpcode(payload);
    std::string requestType = DetectRequestType(payload);
    std::string preview = payload.length() > 255 ? payload.substr(0, 255) : payload;

    InsertProtocolErrorRow(BuildProtocolLogContext(player), "C2S",
        requestType, moduleCode, opcode, eventType, message, preview);
}

static void LogC2SMessage(Player* player, const std::string& payload, bool handled, const std::string& errorMsg = "")
{
    if (!s_AddonConfig.EnableProtocolLogging || !player || !player->GetSession()) return;

    std::string moduleCode = SanitizeModuleCode(ExtractModuleCode(payload));
    uint8 opcode = ExtractOpcode(payload);
    std::string requestType = DetectRequestType(payload);
    std::string status = handled ? "completed" : (errorMsg.empty() ? "pending" : "error");
    std::string preview = payload.length() > 255 ? payload.substr(0, 255) : payload;
    uint32 processingTimeMs = ResolveC2SLogProcessingTimeMs(player, payload);

    InsertProtocolLogRow(BuildProtocolLogContext(player), "C2S",
        requestType, moduleCode, opcode, payload.length(), preview, status,
        errorMsg, processingTimeMs);
}

static void LogS2CMessageGlobal(Player* player, const std::string& module, uint8 opcode, size_t dataSize, bool updateStats, const std::string& payloadPreview, uint32 processingTimeMs)
{
    if (!player || !player->GetSession()) return;

    std::string safeModule = SanitizeModuleCode(module);

    std::string preview = payloadPreview.length() > 255 ? payloadPreview.substr(0, 255) : payloadPreview;
    std::string requestType = DetectRequestType(preview);

    if (processingTimeMs == 0)
        processingTimeMs = 1;

    InsertProtocolLogRow(BuildProtocolLogContext(player), "S2C",
        requestType, safeModule, opcode, dataSize, preview, "completed", "",
        processingTimeMs);

    if (updateStats)
        UpdateProtocolStats(player, safeModule, STATS_TRANSPORT_ADDON,
            false, false, false, processingTimeMs); // isResponse=true implicit
}

namespace DCAddon
{
    void LogNativeC2SMessage(Player* player, const std::string& module,
        uint8 logicalOpcode, uint16 nativeOpcode, size_t dataSize,
        const std::string& payloadPreview, bool handled,
        const std::string& errorMsg)
    {
        std::string status = handled
            ? "completed"
            : (errorMsg.empty() ? "pending" : "error");
        LogNativeC2SMessageWithStatus(player, module, logicalOpcode,
            nativeOpcode, dataSize, payloadPreview, status, errorMsg,
            !handled);
    }

    void LogNativeC2SMessageWithStatus(Player* player,
        const std::string& module, uint8 logicalOpcode,
        uint16 nativeOpcode, size_t dataSize,
        const std::string& payloadPreview, const std::string& status,
        const std::string& errorMsg, bool countAsError)
    {
        if (!s_AddonConfig.EnableProtocolLogging || !player || !player->GetSession())
            return;

        std::string safeModule = SanitizeModuleCode(module);
        InsertProtocolLogRow(BuildProtocolLogContext(player), "C2S",
            REQUEST_TYPE_NATIVE, safeModule,
            GetLoggedOpcode(logicalOpcode, nativeOpcode), dataSize,
            FormatNativePayloadPreview(nativeOpcode, payloadPreview), status,
            errorMsg, 0);
        UpdateProtocolStats(player, safeModule, STATS_TRANSPORT_NATIVE,
            true, false, countAsError);
    }

    void LogNativeS2CMessage(Player* player, const std::string& module,
        uint8 logicalOpcode, uint16 nativeOpcode, size_t dataSize,
        const std::string& payloadPreview, bool updateStats,
        uint32 processingTimeMs)
    {
        if (!s_AddonConfig.EnableProtocolLogging || !player || !player->GetSession())
            return;

        std::string safeModule = SanitizeModuleCode(module);
        if (processingTimeMs == 0)
            processingTimeMs = 1;

        InsertProtocolLogRow(BuildProtocolLogContext(player), "S2C",
            REQUEST_TYPE_NATIVE, safeModule,
            GetLoggedOpcode(logicalOpcode, nativeOpcode), dataSize,
            FormatNativePayloadPreview(nativeOpcode, payloadPreview),
            "completed", "", processingTimeMs);

        if (updateStats)
            UpdateProtocolStats(player, safeModule, STATS_TRANSPORT_NATIVE,
                false, false, false,
                processingTimeMs);
    }

    void LogNativeS2CMessage(WorldSession* session,
        const std::string& module, uint8 logicalOpcode, uint16 nativeOpcode,
        size_t dataSize, const std::string& payloadPreview,
        uint32 processingTimeMs)
    {
        if (!s_AddonConfig.EnableProtocolLogging || !session)
            return;

        std::string safeModule = SanitizeModuleCode(module);
        if (processingTimeMs == 0)
            processingTimeMs = 1;

        InsertProtocolLogRow(BuildProtocolLogContext(session), "S2C",
            REQUEST_TYPE_NATIVE, safeModule,
            GetLoggedOpcode(logicalOpcode, nativeOpcode), dataSize,
            FormatNativePayloadPreview(nativeOpcode, payloadPreview),
            "completed", "", processingTimeMs);

        if (Player* player = session->GetPlayer())
            UpdateProtocolStats(player, safeModule, STATS_TRANSPORT_NATIVE,
                false, false, false, processingTimeMs);
    }

    void LogNativeProtocolError(Player* player,
        ProtocolLogDirection direction, const std::string& module,
        uint8 logicalOpcode, uint16 nativeOpcode,
        const std::string& eventType, const std::string& message,
        const std::string& payloadPreview)
    {
        if (!s_AddonConfig.EnableProtocolLogging || !HasProtocolErrorTable())
            return;

        InsertProtocolErrorRow(BuildProtocolLogContext(player),
            ToDirectionLabel(direction), REQUEST_TYPE_NATIVE,
            SanitizeModuleCode(module),
            GetLoggedOpcode(logicalOpcode, nativeOpcode), eventType, message,
            FormatNativePayloadPreview(nativeOpcode, payloadPreview));
    }

    void LogNativeProtocolError(WorldSession* session,
        ProtocolLogDirection direction, const std::string& module,
        uint8 logicalOpcode, uint16 nativeOpcode,
        const std::string& eventType, const std::string& message,
        const std::string& payloadPreview)
    {
        if (!s_AddonConfig.EnableProtocolLogging || !HasProtocolErrorTable())
            return;

        InsertProtocolErrorRow(BuildProtocolLogContext(session),
            ToDirectionLabel(direction), REQUEST_TYPE_NATIVE,
            SanitizeModuleCode(module),
            GetLoggedOpcode(logicalOpcode, nativeOpcode), eventType, message,
            FormatNativePayloadPreview(nativeOpcode, payloadPreview));
    }

    void AuditNativeC2SRequest(Player* player, const std::string& module,
        uint8 logicalOpcode, uint16 nativeOpcode, size_t dataSize,
        const std::string& payloadPreview, bool handled,
        const std::string& errorMsg, const std::string& eventType,
        const std::string& eventMessage)
    {
        std::string issueMessage = !eventMessage.empty()
            ? eventMessage
            : errorMsg;
        if (!eventType.empty() && !issueMessage.empty())
        {
            LogNativeProtocolError(player,
                ProtocolLogDirection::ClientToServer, module,
                logicalOpcode, nativeOpcode, eventType, issueMessage,
                payloadPreview);
        }

        LogNativeC2SMessage(player, module, logicalOpcode, nativeOpcode,
            dataSize, payloadPreview, handled, errorMsg);
    }

    bool HandleNativeModuleRequest(WorldSession* session,
        WorldPacket const& packet, uint16 nativeOpcode, const char* module)
    {
        if (!session)
            return false;

        Player* player = session->GetPlayer();
        if (!player || !player->IsInWorld())
            return false;

        uint32 logicalOpcodeValue = 0;
        std::string payload;
        bool parseOk = packet.size() > 0;

        if (parseOk)
        {
            WorldPacket nativePacket(packet);
            nativePacket.rpos(0);

            try
            {
                nativePacket >> logicalOpcodeValue;
                if (nativePacket.rpos() < nativePacket.size())
                    nativePacket >> payload;
            }
            catch (ByteBufferException const&)
            {
                parseOk = false;
                logicalOpcodeValue = 0;
                payload.clear();
            }
        }

        bool handled = false;
        std::string errorMsg;
        std::string eventType;
        std::string eventMessage;

        if (!parseOk
            || logicalOpcodeValue > std::numeric_limits<uint8>::max())
        {
            eventType = "native_bad_format";
            eventMessage = "Malformed native request";
        }
        else
        {
            uint8 logicalOpcode = static_cast<uint8>(logicalOpcodeValue);
            std::string raw = std::string(module)
                + "|" + std::to_string(static_cast<uint32>(logicalOpcode))
                + "|J|" + (payload.empty() ? "{}" : payload);
            ParsedMessage parsed(raw);

            if (!parsed.IsValid())
            {
                eventType = "native_bad_format";
                eventMessage = "Malformed native JSON payload";
            }
            else if (MessageRouter::Instance().Route(player, raw))
            {
                handled = true;
            }
            else
            {
                eventType = "native_unhandled_opcode";
                eventMessage = "No handler for native logical opcode";
            }
        }

        uint8 auditedLogicalOpcode = 0;
        if (logicalOpcodeValue <= std::numeric_limits<uint8>::max())
            auditedLogicalOpcode = static_cast<uint8>(logicalOpcodeValue);

        std::string preview = "logical="
            + std::to_string(logicalOpcodeValue)
            + "|payloadBytes=" + std::to_string(payload.size());
        AuditNativeC2SRequest(player, module, auditedLogicalOpcode,
            nativeOpcode, packet.size(), preview, handled, errorMsg,
            eventType, eventMessage);
        return false;
    }

    uint32 GetModuleNativeCapability(const std::string& module)
    {
        // Modules routed over the generic native message bridge. All share the
        // single GENERIC_MESSAGE_NATIVE capability (one client mechanism). Keep
        // in sync with DCAddonProtocol.lua DC._nativeBridges. Modules with their
        // own dedicated bridge (HUD/live snapshots) are unaffected: those send
        // via direct WorldPacket and never reach JsonMessage/Message::Send.
        static std::unordered_map<std::string, uint32> const s_map = {
            { Module::GROUP_FINDER, 1 }, { Module::UPGRADE, 1 },
            { Module::AOE_LOOT, 1 },     { Module::MYTHIC_PLUS, 1 },
            { Module::TELEPORTS, 1 },    { Module::EVENTS, 1 },
            { Module::PHASED_DUELS, 1 }, { Module::LEADERBOARD, 1 },
            { Module::WELCOME, 1 },      { Module::SPECTATOR, 1 },
            { Module::GOMOVE, 1 },       { Module::NPCMOVE, 1 },
            // Modules with their own dedicated bridge for hot flows (ping relay,
            // collection wave1, HLBG live snapshot). Those send via direct
            // WorldPacket and bypass JsonMessage/Message::Send; only their
            // request/response *remainder* (bare sends) routes here.
            { Module::QOS, 1 },          { Module::COLLECTION, 1 },
            { Module::HINTERLAND, 1 },
        };
        return s_map.find(module) != s_map.end()
            ? ProtocolVersion::Capability::GENERIC_MESSAGE_NATIVE : 0;
    }

    bool TrySendModuleNativeMessage(Player* player, const std::string& module,
        uint8 opcode, const std::string& body)
    {
        if (!player || !player->GetSession())
            return false;

        uint32 capability = GetModuleNativeCapability(module);
        if (capability == 0)
            return false;

        TransportPolicyRequest request;
        request.featureName = module.c_str();
        request.nativeCapability = capability;
        if (!ResolveTransportPolicy(player, request).UsesNative())
            return false;

        WorldPacket data(::SMSG_DC_NATIVE_MESSAGE,
            module.size() + body.size() + sizeof(uint32) + 2);
        data << module;
        data << uint32(opcode);
        data << body;
        player->GetSession()->SendPacket(&data);

        std::string preview = "module=" + module
            + "|opcode=" + std::to_string(static_cast<uint32>(opcode))
            + "|bytes=" + std::to_string(body.size());
        LogNativeS2CMessage(player, module, opcode, ::SMSG_DC_NATIVE_MESSAGE,
            data.size(), preview, true, 0);
        return true;
    }

    bool HandleNativeGenericRequest(WorldSession* session,
        WorldPacket const& packet)
    {
        if (!session)
            return false;

        Player* player = session->GetPlayer();
        if (!player || !player->IsInWorld())
            return false;

        std::string module;
        uint32 logicalOpcodeValue = 0;
        std::string body;
        bool parseOk = packet.size() > 0;

        if (parseOk)
        {
            WorldPacket nativePacket(packet);
            nativePacket.rpos(0);
            try
            {
                nativePacket >> module;
                nativePacket >> logicalOpcodeValue;
                if (nativePacket.rpos() < nativePacket.size())
                    nativePacket >> body;
            }
            catch (ByteBufferException const&)
            {
                parseOk = false;
                module.clear();
                logicalOpcodeValue = 0;
                body.clear();
            }
        }

        bool handled = false;
        std::string errorMsg;
        std::string eventType;
        std::string eventMessage;

        if (!parseOk || module.empty()
            || logicalOpcodeValue > std::numeric_limits<uint8>::max()
            || GetModuleNativeCapability(module) == 0)
        {
            eventType = "native_bad_format";
            eventMessage = "Malformed or unregistered native generic request";
        }
        else
        {
            uint8 logicalOpcode = static_cast<uint8>(logicalOpcodeValue);
            std::string canonicalBody = body.empty()
                ? std::string(JSON_MARKER) + DELIMITER + "{}"
                : body;
            std::string raw = module + DELIMITER
                + std::to_string(static_cast<uint32>(logicalOpcode))
                + DELIMITER + canonicalBody;
            ParsedMessage parsed(raw);
            if (!parsed.IsValid())
            {
                eventType = "native_bad_format";
                eventMessage = "Malformed native generic payload";
            }
            else if (MessageRouter::Instance().Route(player, raw))
            {
                handled = true;
            }
            else
            {
                eventType = "native_unhandled_opcode";
                eventMessage = "No handler for native generic opcode";
            }
        }

        uint8 auditedLogicalOpcode = 0;
        if (logicalOpcodeValue <= std::numeric_limits<uint8>::max())
            auditedLogicalOpcode = static_cast<uint8>(logicalOpcodeValue);
        std::string preview = "module=" + module
            + "|opcode=" + std::to_string(logicalOpcodeValue)
            + "|bodyBytes=" + std::to_string(body.size());
        AuditNativeC2SRequest(player, module.empty() ? "DCGEN" : module,
            auditedLogicalOpcode, ::CMSG_DC_NATIVE_REQUEST, packet.size(),
            preview, handled, errorMsg, eventType, eventMessage);
        return false;
    }

    bool SendNativeEnvelope(Player* player, const std::string& module,
        uint8 logicalOpcode, const std::string& feature,
        const std::string& action, uint32 revision,
        const std::string& payload, const std::string& context)
    {
        if (!player || !player->GetSession())
            return false;

        WorldPacket data(::SMSG_DC_NATIVE_ENVELOPE,
            module.size() + feature.size() + action.size() + payload.size()
                + context.size() + 5);
        data << module;
        data << feature;
        data << action;
        data << revision;
        data << payload;
        data << context;
        player->GetSession()->SendPacket(&data);

        std::string preview = "feature=" + feature
            + "|action=" + action
            + "|revision=" + std::to_string(revision)
            + "|bytes=" + std::to_string(payload.size());
        if (!context.empty())
            preview += "|context=" + context;

        LogNativeS2CMessage(player, module, logicalOpcode,
            ::SMSG_DC_NATIVE_ENVELOPE, data.size(), preview, true, 0);
        return true;
    }
}

// ============================================================================
// RATE LIMITING
// ============================================================================

struct PlayerMessageTracker
{
    uint32 messageCount = 0;
    uint32 lastResetTime = 0;
    bool isMuted = false;
    uint32 muteExpireTime = 0;
    uint32 violationCount = 0;     // Track repeated violations for exponential backoff
    uint32 lastViolationTime = 0;  // For violation decay
};

static std::unordered_map<uint32, PlayerMessageTracker> s_MessageTrackers;
static std::mutex s_MessageTrackersMutex;  // Thread safety for rate limiting

static bool CheckRateLimit(Player* player)
{
    uint32 accountId = player->GetSession()->GetAccountId();
    uint32 now = GameTime::GetGameTime().count();

    std::lock_guard<std::mutex> lock(s_MessageTrackersMutex);
    auto& tracker = s_MessageTrackers[accountId];

    // Decay violation count if no violations in 5 minutes
    if (tracker.violationCount > 0 && (now - tracker.lastViolationTime) > 300)
    {
        tracker.violationCount = 0;
        LOG_DEBUG("dc.addon", "Rate limit violations decayed for player {}", player->GetName());
    }

    // Check if muted (exponential backoff in effect)
    if (tracker.isMuted && now < tracker.muteExpireTime)
    {
        g_ProtocolMetrics.rateLimitDrops++;
        return false;
    }
    else if (tracker.isMuted)
    {
        tracker.isMuted = false;
        LOG_DEBUG("dc.addon", "Rate limit mute expired for player {}", player->GetName());
    }

    // Reset counter if second has passed
    if (now > tracker.lastResetTime)
    {
        tracker.messageCount = 0;
        tracker.lastResetTime = now;
    }

    tracker.messageCount++;

    if (tracker.messageCount > s_AddonConfig.MaxMessagesPerSecond)
    {
        // Increment violation count for exponential backoff
        tracker.violationCount++;
        tracker.lastViolationTime = now;
        g_ProtocolMetrics.rateLimitDrops++;

        // Calculate mute duration with exponential backoff: 30s * 2^(violations-1), max 30 min
        uint32 baseMuteSeconds = 30;
        uint32 muteDuration = baseMuteSeconds * (1 << std::min(tracker.violationCount - 1, 6u));
        muteDuration = std::min(muteDuration, 1800u);  // Cap at 30 minutes

        switch (s_AddonConfig.RateLimitAction)
        {
            case 1:  // Disconnect
                player->GetSession()->KickPlayer("Addon message spam");
                LOG_WARN("dc.addon", "Player {} kicked for addon message spam (violations: {})",
                        player->GetName(), tracker.violationCount);
                break;
            case 2:  // Mute with exponential backoff
                tracker.isMuted = true;
                tracker.muteExpireTime = now + muteDuration;
                LOG_WARN("dc.addon", "Player {} muted for {}s (violations: {}, backoff active)",
                        player->GetName(), muteDuration, tracker.violationCount);
                break;
            default:  // Log and drop
                if (s_AddonConfig.EnableDebugLog)
                    LOG_DEBUG("dc.addon", "Rate limit exceeded for player {} (violations: {})",
                             player->GetName(), tracker.violationCount);
                break;
        }
        return false;
    }

    return true;
}

// ============================================================================
// CORE HANDLERS (Handshake, Version, Feature Query)
// ============================================================================

static void HandleCoreHandshake(Player* player, const DCAddon::ParsedMessage& msg)
{
    // Client says hello with version string: "MAJOR.MINOR.PATCH" or "MAJOR.MINOR.PATCH|capabilities"
    std::string clientVersionStr = NormalizeHandshakeVersionString(msg);
    DCAddon::ClientHandshakeMetadata metadata =
        ParseHandshakeMetadata(msg);

    // Parse client version with capability flags
    auto clientVersion = DCAddon::ProtocolVersion::ParseClientVersion(clientVersionStr);
    auto serverVersion = DCAddon::ProtocolVersion::GetServerVersion();

    if (s_AddonConfig.EnableDebugLog)
        LOG_DEBUG("dc.addon", "Handshake from {} with client version {}.{}.{} caps=0x{:X}",
                  player->GetName(), clientVersion.major, clientVersion.minor,
                  clientVersion.patch, clientVersion.capabilities);

    // Check version compatibility (major must match)
    bool compatible = serverVersion.IsCompatible(clientVersion);

    // Negotiate capabilities (intersection of client and server)
    uint32 negotiatedCaps = clientVersion.capabilities & serverVersion.capabilities;
    std::string handshakeAckMetadata = compatible
        ? EncodeHandshakeAckMetadataJson(metadata)
        : std::string();

    // Send acknowledgment with server version and negotiated capabilities
    DCAddon::Message ackMsg(DCAddon::Module::CORE, DCAddon::Opcode::Core::SMSG_HANDSHAKE_ACK);
    if (msg.HasRequestId())
        ackMsg.SetRequestId(msg.GetRequestId());
    ackMsg.Add(DCAddon::ProtocolVersion::BuildVersionString(serverVersion))
        .Add(compatible)
        .Add(negotiatedCaps);  // Negotiated capability flags
    if (!handshakeAckMetadata.empty())
        ackMsg.Add(handshakeAckMetadata);
    ackMsg.Send(player);

    // Store client addon caps/version per account
    StoreClientCaps(player, clientVersionStr, clientVersion.capabilities,
        negotiatedCaps, metadata);
    DCAddon::SetSessionCapabilityState(player, clientVersionStr,
        clientVersion.capabilities, negotiatedCaps, compatible, metadata);
    StoreCapabilityHistory(player, clientVersionStr,
        clientVersion.capabilities, negotiatedCaps, compatible,
        "core-handshake", metadata);
    LogCapabilityState(player, "core-handshake", clientVersionStr,
        clientVersion.capabilities, negotiatedCaps, compatible);

    if (!compatible)
    {
        LOG_WARN("dc.addon", "Version mismatch for {}: client {}.{}.{} vs server {}.{}.{}",
                 player->GetName(), clientVersion.major, clientVersion.minor, clientVersion.patch,
                 serverVersion.major, serverVersion.minor, serverVersion.patch);
        return;  // Don't send features if incompatible
    }

    // Store negotiated capabilities for this player (could use a map for per-player caps)
    // For now, we log it - actual storage would be in PlayerScript or session

    // Automatically send feature list
    DCAddon::Message featureMsg(DCAddon::Module::CORE, DCAddon::Opcode::Core::SMSG_FEATURE_LIST);
    featureMsg.Add(s_AddonConfig.EnableAOELoot);
    featureMsg.Add(s_AddonConfig.EnableSpectator);
    featureMsg.Add(s_AddonConfig.EnableUpgrade);
    featureMsg.Add(s_AddonConfig.EnableDuels);
    featureMsg.Add(s_AddonConfig.EnableMythicPlus);
    featureMsg.Add(s_AddonConfig.EnablePrestige);
    featureMsg.Add(s_AddonConfig.EnableSeasonal);
    featureMsg.Add(s_AddonConfig.EnableHinterlandBG);
    featureMsg.Add(s_AddonConfig.EnableWorld);
    featureMsg.Send(player);

    // Send server context (season + phase) to all UI addons
    {
        uint32 seasonId = DarkChaos::GetActiveSeasonId();
        std::string seasonName = DarkChaos::GetActiveSeasonName();
        uint32 phaseMask = player->GetPhaseMask();

        DCAddon::JsonMessage ctxMsg(DCAddon::Module::CORE, DCAddon::Opcode::Core::SMSG_SERVER_CONTEXT);
        ctxMsg.Set("seasonId", seasonId);
        ctxMsg.Set("seasonName", seasonName);
        ctxMsg.Set("phaseMask", phaseMask);
        ctxMsg.Send(player);
    }

    // Proactively send WRLD content snapshot after handshake
    if (s_AddonConfig.EnableWorld)
    {
        DCAddon::World::SendWorldContentSnapshot(player);
    }
}

static void HandleCoreVersionCheck(Player* player, const DCAddon::ParsedMessage& msg)
{
    std::string clientVersion = msg.GetString(0);

    // Simple version comparison (could be made more sophisticated)
    bool compatible = (clientVersion == s_AddonConfig.ProtocolVersion);

    DCAddon::Message resultMsg(DCAddon::Module::CORE, DCAddon::Opcode::Core::SMSG_VERSION_RESULT);
    if (msg.HasRequestId())
        resultMsg.SetRequestId(msg.GetRequestId());
    resultMsg.Add(compatible)
        .Add(s_AddonConfig.ProtocolVersion)
        .Add(compatible ? "OK" : "Version mismatch - please update addon")
        .Send(player);
}

static void HandleCoreFeatureQuery(Player* player, const DCAddon::ParsedMessage& msg)
{
    DCAddon::Message featureMsg(DCAddon::Module::CORE, DCAddon::Opcode::Core::SMSG_FEATURE_LIST);
    if (msg.HasRequestId())
        featureMsg.SetRequestId(msg.GetRequestId());
    featureMsg.Add(s_AddonConfig.EnableAOELoot);
    featureMsg.Add(s_AddonConfig.EnableSpectator);
    featureMsg.Add(s_AddonConfig.EnableUpgrade);
    featureMsg.Add(s_AddonConfig.EnableDuels);
    featureMsg.Add(s_AddonConfig.EnableMythicPlus);
    featureMsg.Add(s_AddonConfig.EnablePrestige);
    featureMsg.Add(s_AddonConfig.EnableSeasonal);
    featureMsg.Add(s_AddonConfig.EnableHinterlandBG);
    featureMsg.Add(s_AddonConfig.EnableWorld);
    featureMsg.Add(s_AddonConfig.EnableQoS);
    featureMsg.Send(player);
}

// ============================================================================
// BATCH MESSAGE HANDLER
// ============================================================================

static void HandleBatch(Player* player, const DCAddon::ParsedMessage& msg)
{
    // Parse batch message into individual sub-messages
    auto entries = DCAddon::Batch::ParseBatch(msg);

    if (entries.empty())
    {
        if (s_AddonConfig.EnableDebugLog)
            LOG_DEBUG("dc.addon", "Empty or invalid batch message from {}", player->GetName());
        return;
    }

    if (s_AddonConfig.EnableDebugLog)
        LOG_DEBUG("dc.addon", "Processing batch of {} messages from {}",
                  entries.size(), player->GetName());

    // Route each sub-message through the normal handler
    for (auto const& entry : entries)
    {
        // Reconstruct the message string: MODULE|OPCODE|data1|data2|...
        std::string subMsg = entry.module + DCAddon::DELIMITER + std::to_string(entry.opcode);
        for (auto const& d : entry.data)
        {
            subMsg += DCAddon::DELIMITER;
            subMsg += d;
        }

        // Route through MessageRouter (excluding BATCH to prevent recursion)
        if (entry.module != DCAddon::Batch::MODULE)
        {
            // Apply rate limiting per logical sub-message to avoid bypass via batching.
            if (!ShouldBypassRateLimit(subMsg))
            {
                bool passedRateLimit = CheckRateLimit(player);
                if (!passedRateLimit)
                {
                    uint8 droppedOpcode = ExtractOpcode(subMsg);
                    LOG_WARN("module.dc", "[RateLimit] DROPPED batch sub-message from {}: module={}, opcode=0x{:02X}",
                        player->GetName(), entry.module, droppedOpcode);
                    continue;
                }
            }

            DCAddon::MessageRouter::Instance().Route(player, subMsg);
        }
    }
}

// ============================================================================
// CROSS-SYSTEM EVENT -> ADDON BROADCAST
// ============================================================================

static const char* EventTypeToString(DarkChaos::CrossSystem::EventType type)
{
    using namespace DarkChaos::CrossSystem;
    switch (type)
    {
        case EventType::PlayerLogin: return "PlayerLogin";
        case EventType::PlayerLogout: return "PlayerLogout";
        case EventType::PlayerLevelUp: return "PlayerLevelUp";
        case EventType::PlayerDeath: return "PlayerDeath";
        case EventType::PlayerPrestige: return "PlayerPrestige";
        case EventType::CreatureKill: return "CreatureKill";
        case EventType::BossKill: return "BossKill";
        case EventType::WorldBossKill: return "WorldBossKill";
        case EventType::PlayerKill: return "PlayerKill";
        case EventType::DungeonEnter: return "DungeonEnter";
        case EventType::DungeonLeave: return "DungeonLeave";
        case EventType::DungeonComplete: return "DungeonComplete";
        case EventType::DungeonFailed: return "DungeonFailed";
        case EventType::DungeonReset: return "DungeonReset";
        case EventType::MythicPlusStart: return "MythicPlusStart";
        case EventType::MythicPlusComplete: return "MythicPlusComplete";
        case EventType::MythicPlusFail: return "MythicPlusFail";
        case EventType::MythicPlusAbandon: return "MythicPlusAbandon";
        case EventType::KeystoneUpgrade: return "KeystoneUpgrade";
        case EventType::QuestComplete: return "QuestComplete";
        case EventType::DailyQuestComplete: return "DailyQuestComplete";
        case EventType::WeeklyQuestComplete: return "WeeklyQuestComplete";
        case EventType::TokensAwarded: return "TokensAwarded";
        case EventType::EssenceAwarded: return "EssenceAwarded";
        case EventType::ItemUpgraded: return "ItemUpgraded";
        case EventType::LootReceived: return "LootReceived";
        case EventType::WeeklyResetOccurred: return "WeeklyResetOccurred";
        case EventType::SeasonStart: return "SeasonStart";
        case EventType::SeasonEnd: return "SeasonEnd";
        case EventType::VaultClaimed: return "VaultClaimed";
        case EventType::AchievementUnlocked: return "AchievementUnlocked";
        case EventType::MilestoneReached: return "MilestoneReached";
        case EventType::DuelComplete: return "DuelComplete";
        case EventType::HLBGMatchComplete: return "HLBGMatchComplete";
        case EventType::ArenaMatchComplete: return "ArenaMatchComplete";
        default: return "Unknown";
    }
}

static void AppendEventDetails(DCAddon::JsonMessage& msg, const DarkChaos::CrossSystem::EventData& event)
{
    using namespace DarkChaos::CrossSystem;

    if (auto const* kill = dynamic_cast<const CreatureKillEvent*>(&event))
    {
        msg.Set("creatureEntry", kill->creatureEntry);
        msg.Set("isBoss", kill->isBoss);
        msg.Set("isRare", kill->isRare);
        msg.Set("isElite", kill->isElite);
        msg.Set("keystoneLevel", kill->keystoneLevel);
        msg.Set("partySize", kill->partySize);
        msg.Set("tokensAwarded", kill->tokensAwarded);
        msg.Set("essenceAwarded", kill->essenceAwarded);
    }
    else if (auto const* dungeon = dynamic_cast<const DungeonCompleteEvent*>(&event))
    {
        msg.Set("contentType", static_cast<uint32>(dungeon->contentType));
        msg.Set("difficulty", static_cast<uint32>(dungeon->difficulty));
        msg.Set("keystoneLevel", dungeon->keystoneLevel);
        msg.Set("completionTimeSeconds", dungeon->completionTimeSeconds);
        msg.Set("timerLimitSeconds", dungeon->timerLimitSeconds);
        msg.Set("deaths", dungeon->deaths);
        msg.Set("wipes", dungeon->wipes);
        msg.Set("timedSuccess", dungeon->timedSuccess);
        msg.Set("tokensAwarded", dungeon->tokensAwarded);
        msg.Set("essenceAwarded", dungeon->essenceAwarded);
    }
    else if (auto const* quest = dynamic_cast<const QuestCompleteEvent*>(&event))
    {
        msg.Set("questId", quest->questId);
        msg.Set("isDaily", quest->isDaily);
        msg.Set("isWeekly", quest->isWeekly);
        msg.Set("tokensAwarded", quest->tokensAwarded);
        msg.Set("essenceAwarded", quest->essenceAwarded);
    }
    else if (auto const* upgrade = dynamic_cast<const ItemUpgradeEvent*>(&event))
    {
        msg.Set("itemGuid", upgrade->itemGuid);
        msg.Set("itemEntry", upgrade->itemEntry);
        msg.Set("fromLevel", upgrade->fromLevel);
        msg.Set("toLevel", upgrade->toLevel);
        msg.Set("tierId", upgrade->tierId);
        msg.Set("tokensCost", upgrade->tokensCost);
        msg.Set("essenceCost", upgrade->essenceCost);
    }
    else if (auto const* prestige = dynamic_cast<const PrestigeEvent*>(&event))
    {
        msg.Set("fromPrestige", prestige->fromPrestige);
        msg.Set("toPrestige", prestige->toPrestige);
        msg.Set("fromLevel", prestige->fromLevel);
        msg.Set("keptGear", prestige->keptGear);
    }
    else if (auto const* vault = dynamic_cast<const VaultClaimEvent*>(&event))
    {
        msg.Set("seasonId", vault->seasonId);
        msg.Set("slotClaimed", vault->slotClaimed);
        msg.Set("itemId", vault->itemId);
        msg.Set("tokensClaimed", vault->tokensClaimed);
        msg.Set("essenceClaimed", vault->essenceClaimed);
    }
}

static void SendCrossEventToPlayer(Player* player, const DarkChaos::CrossSystem::EventData& event)
{
    if (!player || !player->GetSession())
        return;

    DCAddon::JsonMessage msg(DCAddon::Module::CORE, DCAddon::Opcode::Core::SMSG_CROSS_EVENT);
    msg.Set("eventType", static_cast<uint32>(event.type));
    msg.Set("eventName", EventTypeToString(event.type));
    msg.Set("timestamp", static_cast<uint32>(event.timestamp ? event.timestamp : time(nullptr)));
    msg.Set("playerGuid", static_cast<uint32>(event.playerGuid.GetCounter()));
    msg.Set("mapId", event.mapId);
    msg.Set("instanceId", event.instanceId);
    msg.Set("correlationId", static_cast<uint32>(event.correlationId));

    AppendEventDetails(msg, event);
    msg.Send(player);
}

class DCAddonCrossSystemBridge : public DarkChaos::CrossSystem::IEventHandler
{
public:
    DarkChaos::CrossSystem::SystemId GetSystemId() const override
    {
        return DarkChaos::CrossSystem::SystemId::None;
    }

    const char* GetSystemName() const override
    {
        return "AddonProtocol";
    }

    std::vector<DarkChaos::CrossSystem::EventType> GetSubscribedEvents() const override
    {
        using namespace DarkChaos::CrossSystem;
        return {
            EventType::PlayerLogin,
            EventType::PlayerLogout,
            EventType::PlayerLevelUp,
            EventType::PlayerDeath,
            EventType::PlayerPrestige,
            EventType::CreatureKill,
            EventType::BossKill,
            EventType::WorldBossKill,
            EventType::PlayerKill,
            EventType::DungeonEnter,
            EventType::DungeonLeave,
            EventType::DungeonComplete,
            EventType::DungeonFailed,
            EventType::DungeonReset,
            EventType::MythicPlusStart,
            EventType::MythicPlusComplete,
            EventType::MythicPlusFail,
            EventType::MythicPlusAbandon,
            EventType::KeystoneUpgrade,
            EventType::QuestComplete,
            EventType::DailyQuestComplete,
            EventType::WeeklyQuestComplete,
            EventType::TokensAwarded,
            EventType::EssenceAwarded,
            EventType::ItemUpgraded,
            EventType::LootReceived,
            EventType::WeeklyResetOccurred,
            EventType::SeasonStart,
            EventType::SeasonEnd,
            EventType::VaultClaimed,
            EventType::AchievementUnlocked,
            EventType::MilestoneReached,
            EventType::DuelComplete,
            EventType::HLBGMatchComplete,
            EventType::ArenaMatchComplete
        };
    }

    void OnEvent(const DarkChaos::CrossSystem::EventData& event) override
    {
        using namespace DarkChaos::CrossSystem;

        // If this event includes explicit participants, send to each
        if (auto const* dungeon = dynamic_cast<const DungeonCompleteEvent*>(&event))
        {
            if (!dungeon->participants.empty())
            {
                for (auto const& guid : dungeon->participants)
                {
                    if (Player* player = ObjectAccessor::FindConnectedPlayer(guid))
                        SendCrossEventToPlayer(player, event);
                }
                return;
            }
        }

        if (Player* player = ObjectAccessor::FindConnectedPlayer(event.playerGuid))
        {
            SendCrossEventToPlayer(player, event);
        }
    }
};

static std::unique_ptr<DCAddonCrossSystemBridge> s_CrossSystemBridge;

static void RegisterCoreHandlers()
{
    using namespace DCAddon;

    DC_REGISTER_HANDLER(Module::CORE, Opcode::Core::CMSG_HANDSHAKE, HandleCoreHandshake);
    DC_REGISTER_HANDLER(Module::CORE, Opcode::Core::CMSG_VERSION_CHECK, HandleCoreVersionCheck);
    DC_REGISTER_HANDLER(Module::CORE, Opcode::Core::CMSG_FEATURE_QUERY, HandleCoreFeatureQuery);

    // Register BATCH handler - opcode 0x00 means "process batch"
    DC_REGISTER_HANDLER(Batch::MODULE, 0x00, HandleBatch);
}

// ============================================================================
// CHUNKED MESSAGE TRACKING
// ============================================================================

static std::unordered_map<uint32, DCAddon::ChunkedMessage> s_ChunkedMessages;
static std::unordered_map<uint32, uint32> s_ChunkStartTimes;
static std::mutex s_ChunkedMessagesMutex;  // Thread safety for chunked message tracking

static void CleanupExpiredChunks()
{
    uint32 now = GameTime::GetGameTime().count() * 1000;  // Convert to ms

    std::lock_guard<std::mutex> lock(s_ChunkedMessagesMutex);
    std::vector<uint32> toRemove;
    for (auto const& [accountId, startTime] : s_ChunkStartTimes)
    {
        if (now - startTime > s_AddonConfig.ChunkTimeoutMs)
        {
            toRemove.push_back(accountId);
        }
    }

    for (uint32 id : toRemove)
    {
        s_ChunkedMessages.erase(id);
        s_ChunkStartTimes.erase(id);
    }
}

// ============================================================================
// MAIN MESSAGE ROUTER SCRIPT
// ============================================================================

class DCAddonProtocolScript : public PlayerScript
{
public:
    DCAddonProtocolScript() : PlayerScript("DCAddonProtocolScript") {}

    void OnPlayerLogin(Player* player) override
    {
        (void)player;  // Unused for now
        // Could send initial sync here if client addon is already known to be present
        // For now, we wait for client handshake
    }

    void OnPlayerLogout(Player* player) override
    {
        // Clean up any pending chunked messages for this player
        uint32 accountId = player->GetSession()->GetAccountId();

        // If this player had an in-flight chunked message, record it as an event
        bool hadPendingChunks = false;
        {
            std::lock_guard<std::mutex> lock(s_ChunkedMessagesMutex);
            hadPendingChunks = s_ChunkStartTimes.find(accountId) != s_ChunkStartTimes.end();
        }

        if (s_AddonConfig.EnableProtocolLogging && hadPendingChunks &&
            HasProtocolErrorTable())
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_addon_protocol_errors "
                "(guid, account_id, character_name, direction, request_type, module, opcode, event_type, message) "
                "VALUES ({}, {}, '{}', 'C2S', 'DC_PLAIN', 'CHUNK', 0, 'chunk_abandoned', 'Player logout with incomplete chunked message')",
                player->GetGUID().GetCounter(),
                accountId,
                EscapeSQLString(player->GetName())
            );

            UpdateProtocolStats(player, "CHUNK", STATS_TRANSPORT_ADDON,
                true, true, false);
        }

        {
            std::lock_guard<std::mutex> lock(s_ChunkedMessagesMutex);
            s_ChunkedMessages.erase(accountId);
            s_ChunkStartTimes.erase(accountId);
        }
        {
            std::lock_guard<std::mutex> lock(s_MessageTrackersMutex);
            s_MessageTrackers.erase(accountId);
        }
        {
            std::lock_guard<std::mutex> lock(s_PendingRequestsMutex);
            s_PendingRequests.erase(accountId);
        }

        ClearTransportObservations(player);
        DCAddon::ClearSessionCapabilityState(player);

        // FLUSH STATS for this player and remove from buffer
        FlushStats(player->GetGUID().GetCounter());

        // Also clean up any expired chunks from other players (opportunistic cleanup)
        CleanupExpiredChunks();
    }
};

class DCAddonMessageRouterScript : public PlayerScript
{
public:
    DCAddonMessageRouterScript() : PlayerScript("DCAddonMessageRouterScript") {}

    // Try to parse a message as a chunked message. Returns true if it's a chunk.
    // If complete, sets outPayload to the reassembled message. Otherwise clears it.
    bool TryReassembleChunk(Player* player, const std::string& payload, std::string& outPayload)
    {
        // Chunk format: INDEX|TOTAL|DATA
        // Check if starts with digit and has proper format
        if (payload.empty() || !std::isdigit(payload[0]))
            return false;

        size_t firstPipe = payload.find('|');
        if (firstPipe == std::string::npos || firstPipe >= payload.size() - 1)
            return false;

        size_t secondPipe = payload.find('|', firstPipe + 1);
        if (secondPipe == std::string::npos)
            return false;

        // Parse index and total
        uint32 chunkIndex = 0, totalChunks = 0;
        try
        {
            chunkIndex = std::stoul(payload.substr(0, firstPipe));
            totalChunks = std::stoul(payload.substr(firstPipe + 1, secondPipe - firstPipe - 1));
        }
        catch (...)
        {
            g_ProtocolMetrics.parseErrors++;
            if (s_AddonConfig.EnableProtocolLogging)
            {
                LogProtocolErrorEvent(player, payload, "chunk_parse", "Malformed chunk header");
            }
            return false;  // Not a valid chunk format
        }

        // Validate chunk parameters
        if (totalChunks == 0 || chunkIndex >= totalChunks)
        {
            g_ProtocolMetrics.parseErrors++;
            if (s_AddonConfig.EnableProtocolLogging)
            {
                LogProtocolErrorEvent(player, payload, "chunk_bounds", "Invalid chunk index/total");
            }
            return false;
        }

        // Security limit: prevent memory exhaustion via excessive chunk count
        if (totalChunks > s_AddonConfig.MaxChunksPerMessage)
        {
            g_ProtocolMetrics.parseErrors++;
            LOG_WARN("module.dc", "[DC-CHUNK] player={}, REJECTED: totalChunks={} exceeds limit {}",
                player->GetName(), totalChunks, s_AddonConfig.MaxChunksPerMessage);
            if (s_AddonConfig.EnableProtocolLogging)
            {
                LogProtocolErrorEvent(player, payload, "chunk_limit", "Chunk count exceeds server limit");
            }
            return false;
        }

        // Special case: if totalChunks == 1, this is a single-chunk message (short-circuit)
        // Just extract the data and return immediately without storing in buffer
        if (totalChunks == 1)
        {
            outPayload = payload.substr(secondPipe + 1);
            LOG_DEBUG("module.dc", "[DC-CHUNK] player={}, single-chunk message, dataLen={}",
                player->GetName(), outPayload.length());
            return true;
        }

        // It's a multi-chunk message
        std::string chunkData = payload.substr(secondPipe + 1);
        uint32 accountId = player->GetSession()->GetAccountId();

        LOG_DEBUG("module.dc", "[DC-CHUNK] player={}, chunk={}/{}, dataLen={}",
            player->GetName(), chunkIndex + 1, totalChunks, chunkData.length());

        // Store chunk with thread safety
        std::lock_guard<std::mutex> lock(s_ChunkedMessagesMutex);
        if (chunkIndex == 0)
        {
            // Security: bound how many DISTINCT accounts may have an in-flight
            // chunked message at once. s_ChunkedMessages is keyed by accountId,
            // so .size() is the number of accounts currently mid-reassembly (not
            // a chunk count). The global ceiling is MaxPendingChunks * 10.
            if (s_ChunkedMessages.find(accountId) == s_ChunkedMessages.end() &&
                s_ChunkedMessages.size() >= s_AddonConfig.MaxPendingChunks * 10)
            {
                g_ProtocolMetrics.parseErrors++;
                LOG_WARN("module.dc", "[DC-CHUNK] player={}, REJECTED: global pending chunks limit reached ({})",
                    player->GetName(), s_ChunkedMessages.size());
                if (s_AddonConfig.EnableProtocolLogging)
                {
                    LogProtocolErrorEvent(player, payload, "chunk_pending_limit", "Too many pending chunked messages");
                }
                return false;
            }

            // First chunk - reset buffer
            s_ChunkedMessages[accountId] = DCAddon::ChunkedMessage();
            s_ChunkStartTimes[accountId] = GameTime::GetGameTime().count() * 1000;
        }

        auto chunkIt = s_ChunkedMessages.find(accountId);
        if (chunkIt == s_ChunkedMessages.end())
        {
            s_ChunkedMessages[accountId] = DCAddon::ChunkedMessage();
            chunkIt = s_ChunkedMessages.find(accountId);
        }

        auto& chunkedMsg = chunkIt->second;

        bool complete = chunkedMsg.AddChunk(payload);

        if (complete)
        {
            outPayload = chunkedMsg.GetCompleteMessage();
            s_ChunkedMessages.erase(accountId);
            s_ChunkStartTimes.erase(accountId);

            LOG_DEBUG("module.dc", "[DC-CHUNK] player={}, COMPLETE! reassembledLen={}",
                player->GetName(), outPayload.length());
            return true;
        }

        // Still waiting for more chunks
        outPayload.clear();
        return true;
    }

    // Intercept addon messages with "DC" prefix and route to handlers
    void OnPlayerBeforeSendChatMessage(Player* player, uint32& type, uint32& lang, std::string& msg) override
    {
        // Only process addon whisper messages
        if (lang != LANG_ADDON || type != CHAT_MSG_WHISPER)
            return;

        // Addon messages are formatted as "PREFIX\tPAYLOAD"
        // Check if message starts with "DC\t"
        static const std::string dcPrefix = "DC\t";
        if (msg.rfind(dcPrefix, 0) != 0)
            return;

        // Skip the "DC\t" prefix
        std::string rawPayload = msg.substr(3);  // Everything after "DC\t"
        g_ProtocolMetrics.messagesReceived++;

        // Check if this is a chunked message that needs reassembly
        std::string reassembledPayload;
        if (TryReassembleChunk(player, rawPayload, reassembledPayload))
        {
            if (reassembledPayload.empty())
            {
                // Still waiting for more chunks - suppress this message and continue
                msg.clear();
                return;
            }
            // Use the reassembled payload
            rawPayload = reassembledPayload;
            if (s_AddonConfig.EnableDebugLog)
                LOG_DEBUG("module.dc", "[DC-CHUNK] player={}, reassembled message ready, len={}",
                    player->GetName(), rawPayload.length());
        }

        std::string payload = rawPayload;

        // Security limit: reject oversized payloads to prevent JSON parsing attacks
        if (payload.length() > s_AddonConfig.MaxJsonPayloadSize)
        {
            g_ProtocolMetrics.parseErrors++;
            LOG_WARN("module.dc", "[DC-SECURITY] player={}, REJECTED: payload size {} exceeds limit {}",
                player->GetName(), payload.length(), s_AddonConfig.MaxJsonPayloadSize);

            if (s_AddonConfig.EnableProtocolLogging)
            {
                LogProtocolErrorEvent(player, payload, "payload_too_large", "Payload exceeds configured size limit");
                UpdateProtocolStats(player, "CORE", STATS_TRANSPORT_ADDON,
                    true, false, true);
            }

            if (player && player->GetSession())
            {
                DCAddon::SendError(
                    player,
                    DCAddon::Module::CORE,
                    "Payload too large",
                    DCAddon::ErrorCode::BAD_FORMAT,
                    DCAddon::Opcode::Core::SMSG_ERROR);
            }

            msg.clear();
            return;
        }

        // Cleanup expired async requests for this player
        CleanupExpiredRequests(player);

        // Early logging: show ALL incoming DC messages
        uint8 incomingOpcode = ExtractOpcode(payload);
        if (s_AddonConfig.EnableDebugLog)
            LOG_DEBUG("module.dc", "[DC-INCOMING] player={}, module={}, opcode=0x{:02X}, payloadLen={}",
                player->GetName(), ExtractModuleCode(payload), incomingOpcode, payload.length());

        // Check rate limit before processing. Allow a small bypass list for UI-critical requests.
        // Bypassed messages don't count against the rate limit.
        bool shouldBypass = ShouldBypassRateLimit(payload);
        if (!shouldBypass)
        {
            bool passedRateLimit = CheckRateLimit(player);
            if (!passedRateLimit)
            {
                // Log dropped messages for diagnostics
                uint8 droppedOpcode = ExtractOpcode(payload);
                LOG_WARN("module.dc", "[RateLimit] DROPPED message from {}: module={}, opcode=0x{:02X}",
                    player->GetName(), ExtractModuleCode(payload), droppedOpcode);
                msg.clear();
                return;
            }
        }

        if (s_AddonConfig.EnableDebugLog)
            LOG_DEBUG("dc.addon", "Routing DC message from {}: {}", player->GetName(), payload);

        // Parse module and opcode for logging
        // Note: We use the extracted module code which might be formatted nicely or raw
        std::string moduleStr = ExtractModuleCode(payload);

        // Register pending request if request ID is present
        DCAddon::ParsedMessage parsed(payload);
        if (!parsed.IsValid())
        {
            g_ProtocolMetrics.parseErrors++;

            if (s_AddonConfig.EnableProtocolLogging)
            {
                LogProtocolErrorEvent(player, payload, "bad_format", "Malformed addon message");
                UpdateProtocolStats(player, moduleStr, STATS_TRANSPORT_ADDON,
                    true, false, true);
                LogC2SMessage(player, payload, false, "Malformed addon message");
            }

            DCAddon::SendError(
                player,
                DCAddon::Module::CORE,
                "Invalid message format",
                DCAddon::ErrorCode::BAD_FORMAT,
                DCAddon::Opcode::Core::SMSG_ERROR);

            msg.clear();
            return;
        }

        RegisterPendingRequest(player, parsed);

        auto& router = DCAddon::MessageRouter::Instance();
        bool moduleEnabled = router.IsModuleEnabled(parsed.GetModule());
        bool hadRegisteredHandler =
            router.HasHandler(parsed.GetModule(), parsed.GetOpcode());

        // Capture handshake caps only if the normal CORE handler will not run.
        if (parsed.GetModule() == DCAddon::Module::CORE &&
            parsed.GetOpcode() == DCAddon::Opcode::Core::CMSG_HANDSHAKE &&
            (!moduleEnabled || !hadRegisteredHandler))
        {
            std::string clientVersionStr = NormalizeHandshakeVersionString(parsed);
            auto clientVersion =
                DCAddon::ProtocolVersion::ParseClientVersion(clientVersionStr);
            auto serverVersion = DCAddon::ProtocolVersion::GetServerVersion();
            bool compatible = serverVersion.IsCompatible(clientVersion);
            uint32 negotiatedCaps =
                clientVersion.capabilities & serverVersion.capabilities;
            DCAddon::ClientHandshakeMetadata metadata =
                ParseHandshakeMetadata(parsed);

            StoreClientCaps(player, clientVersionStr,
                clientVersion.capabilities, negotiatedCaps, metadata);
            DCAddon::SetSessionCapabilityState(player, clientVersionStr,
                clientVersion.capabilities, negotiatedCaps, compatible,
                metadata);
            StoreCapabilityHistory(player, clientVersionStr,
                clientVersion.capabilities, negotiatedCaps, compatible,
                "pre-router-fallback", metadata);
            LogCapabilityState(player, "pre-router-fallback",
                clientVersionStr, clientVersion.capabilities,
                negotiatedCaps, compatible);
        }

        // Route the message
        bool handled = false;
        bool handlerException = false;
        try
        {
            handled = router.Route(player, payload);
        }
        catch (...)
        {
            handlerException = true;
            g_ProtocolMetrics.handlerErrors++;

            LOG_ERROR(
                "module.dc",
                "Unhandled exception while routing addon payload from {} (module={}, opcode=0x{:02X})",
                player->GetName(),
                parsed.GetModule(),
                parsed.GetOpcode());

            if (s_AddonConfig.EnableProtocolLogging)
            {
                LogProtocolErrorEvent(player, payload, "handler_exception", "Unhandled exception while routing addon message");
            }

            DCAddon::SendError(
                player,
                parsed.GetModule().empty() ? DCAddon::Module::CORE : parsed.GetModule(),
                "Internal handler error",
                DCAddon::ErrorCode::UNKNOWN,
                DCAddon::Opcode::Core::SMSG_ERROR);
        }

        // Temporary safety net: if the QoS tooltip endpoint is requested while the
        // handler table is stale/missing, emit a protocol-compatible response instead
        // of allowing request timeout churn.
        if (!handled && !handlerException && moduleEnabled && !hadRegisteredHandler)
            handled = TrySendQoSTooltipFallback(player, parsed);

        // Fallback completion path for handled requests:
        // if the handler consumed the request but did not emit a response packet
        // carrying RID, close the pending RID entry here to avoid false timeouts.
        if (handled && !handlerException && parsed.HasRequestId() && ShouldTrackPendingRequest(parsed))
            DCAddon::NotifyResponseSent(player, parsed.GetRequestId());

        // Log to database if protocol logging is enabled
        if (s_AddonConfig.EnableProtocolLogging && !moduleStr.empty())
        {
            std::string errorMsg;
            if (handlerException)
                errorMsg = "Unhandled handler exception";
            else if (!moduleEnabled)
                errorMsg = "Module is disabled";
            else if (!handled && hadRegisteredHandler)
                errorMsg = "Handler execution failed";
            else if (!handled)
                errorMsg = "No handler for module/opcode";

            LogC2SMessage(player, payload, handled, errorMsg);
            UpdateProtocolStats(player, moduleStr, STATS_TRANSPORT_ADDON,
                true, false, (handlerException || !handled));
                // request-side errors are tracked

            if (!handled && !handlerException && moduleEnabled && !hadRegisteredHandler)
                LogProtocolErrorEvent(player, payload, "unhandled", errorMsg);
            else if (!handled && !handlerException && moduleEnabled && hadRegisteredHandler)
                LogProtocolErrorEvent(player, payload, "handler_error", errorMsg);
        }

        if (handled)
        {
            // Message was handled by DC protocol - clear it to prevent normal processing
            msg.clear();
        }
        else if (s_AddonConfig.EnableDebugLog)
        {
            LOG_DEBUG("dc.addon", "No handler for DC message from {}: {}", player->GetName(), payload);
        }
    }
};

namespace
{
    // Async DB callback plumbing. A discarded QueryCallback never invokes its
    // continuation (see QueryCallback::~QueryCallback), so handlers route their
    // callbacks here. EnqueueQueryCallback() may be called from any thread (the
    // addon message handlers guard their session state with mutexes for the
    // same reason); the processor itself is only ever touched on the world
    // thread inside ProcessPendingQueryCallbacks().
    QueryCallbackProcessor s_DCAddonQueryProcessor;
    std::vector<QueryCallback> s_DCAddonPendingQueries;
    std::mutex s_DCAddonPendingQueriesMutex;
}

namespace DCAddon
{
    void EnqueueQueryCallback(QueryCallback&& callback)
    {
        std::lock_guard<std::mutex> lock(s_DCAddonPendingQueriesMutex);
        s_DCAddonPendingQueries.emplace_back(std::move(callback));
    }

    void ProcessPendingQueryCallbacks()
    {
        // World thread only. Move any queued callbacks into the processor,
        // then invoke those whose results are ready.
        std::vector<QueryCallback> pending;
        {
            std::lock_guard<std::mutex> lock(s_DCAddonPendingQueriesMutex);
            pending.swap(s_DCAddonPendingQueries);
        }

        for (QueryCallback& cb : pending)
            s_DCAddonQueryProcessor.AddCallback(std::move(cb));

        s_DCAddonQueryProcessor.ProcessReadyCallbacks();
    }
}

class DCAddonWorldScript : public WorldScript
{
public:
    DCAddonWorldScript() : WorldScript("DCAddonWorldScript") {}

    void OnUpdate(uint32 diff) override
    {
        // Drain queued async DB callbacks every tick on the world thread so
        // their .WithCallback() continuations actually run (a discarded
        // QueryCallback never fires). Cheap no-op when nothing is queued.
        DCAddon::ProcessPendingQueryCallbacks();

        _statsFlushTimer += diff;
        if (_statsFlushTimer < STATS_FLUSH_INTERVAL_MS)
            return;

        _statsFlushTimer = 0;
        FlushStats();
    }

    void OnShutdown() override
    {
        // Flush all pending stats on server shutdown
        FlushStats();

        if (s_CrossSystemBridge)
        {
            DarkChaos::CrossSystem::EventBus::instance()->UnsubscribeHandler(s_CrossSystemBridge.get());
            s_CrossSystemBridge.reset();
        }
    }

    void OnStartup() override
    {
        LoadAddonConfig();
        RegisterCoreHandlers();

        if (!s_CrossSystemBridge)
        {
            s_CrossSystemBridge = std::make_unique<DCAddonCrossSystemBridge>();
            DarkChaos::CrossSystem::EventBus::instance()->SubscribeHandler(s_CrossSystemBridge.get());
        }

        LOG_INFO("dc.addon", "===========================================");
        LOG_INFO("dc.addon", "Dark Chaos Addon Protocol v{} loaded", s_AddonConfig.ProtocolVersion);
        LOG_INFO("dc.addon", "RateLimit bypass enabled for: COLL|0x3B (SavedOutfits), COLL|0x53 (CommunityList), COLL|0x38 (ApplyTransmog), COLL|0x33 (SetTransmog), COLL|0x37 (GetTransmogState)");
        LOG_INFO("dc.addon", "Enabled modules:");
        LOG_INFO("dc.addon", "  Core:        {}", s_AddonConfig.EnableCore ? "Yes" : "No");
        LOG_INFO("dc.addon", "  AOE Loot:    {}", s_AddonConfig.EnableAOELoot ? "Yes" : "No");
        LOG_INFO("dc.addon", "  Spectator:   {}", s_AddonConfig.EnableSpectator ? "Yes" : "No");
        LOG_INFO("dc.addon", "  Upgrade:     {}", s_AddonConfig.EnableUpgrade ? "Yes" : "No");
        LOG_INFO("dc.addon", "  Duels:       {}", s_AddonConfig.EnableDuels ? "Yes" : "No");
        LOG_INFO("dc.addon", "  Mythic+:     {}", s_AddonConfig.EnableMythicPlus ? "Yes" : "No");
        LOG_INFO("dc.addon", "  Prestige:    {}", s_AddonConfig.EnablePrestige ? "Yes" : "No");
        LOG_INFO("dc.addon", "  Seasonal:    {}", s_AddonConfig.EnableSeasonal ? "Yes" : "No");
        LOG_INFO("dc.addon", "  Hinterland:  {}", s_AddonConfig.EnableHinterlandBG ? "Yes" : "No");
        LOG_INFO("dc.addon", "  Leaderboard: {}", s_AddonConfig.EnableLeaderboard ? "Yes" : "No");
        LOG_INFO("dc.addon", "  Events:      {}", s_AddonConfig.EnableEvents ? "Yes" : "No");
        LOG_INFO("dc.addon", "  World:       {}", s_AddonConfig.EnableWorld ? "Yes" : "No");
        LOG_INFO("dc.addon", "  QoS:         {}", s_AddonConfig.EnableQoS ? "Yes" : "No");
        LOG_INFO("dc.addon", "  DB Logging:  {}", s_AddonConfig.EnableProtocolLogging ? "Yes" : "No");
        LOG_INFO("dc.addon", "===========================================");
    }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        LoadAddonConfig();
    }

private:
    uint32 _statsFlushTimer = 0;
};

// Native transport receive hook for the generic DC native message bridge.
// Decodes CMSG_DC_NATIVE_REQUEST (module + opcode + body) and routes it through
// the shared MessageRouter, so any module with a registered native capability
// (GRPF/UPG/AOE) hits the same handlers as the addon path.
class DcNativeGenericServerScript : public ServerScript
{
public:
    DcNativeGenericServerScript()
        : ServerScript("DcNativeGenericServerScript",
            { SERVERHOOK_CAN_PACKET_RECEIVE })
    {
    }

private:
    bool CanPacketReceive(WorldSession* session,
        WorldPacket const& packet) override
    {
        if (packet.GetOpcode() != ::CMSG_DC_NATIVE_REQUEST)
            return true;

        return DCAddon::HandleNativeGenericRequest(session, packet);
    }
};

// ============================================================================
// SCRIPT REGISTRATION
// ============================================================================

void AddSC_dc_addon_protocol()
{
    new DCAddonProtocolScript();
    new DCAddonMessageRouterScript();
    new DCAddonWorldScript();
    new DcNativeGenericServerScript();
}
