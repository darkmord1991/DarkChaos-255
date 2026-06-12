/*
 * Dark Chaos - Quality of Service (QoS) Addon Handler
 * ====================================================
 *
 * Server-side handler for the DC-QoS addon.
 * Provides QoL feature settings sync and extended item/NPC information.
 *
 * Features:
 * - Settings synchronization between client and server
 * - Extended item information (custom DB data)
 * - Extended NPC information (DB GUID, spawn info)
 * - Extended spell information (custom modifications)
 * - Server-side feature notifications
 *
 * Message Format:
 * - JSON format: QOS|OPCODE|J|{json}
 * - Simple format: QOS|OPCODE|DATA1|DATA2|...
 *
 * Opcodes:
 * - CMSG: 0x01 (SYNC_SETTINGS), 0x02 (UPDATE_SETTING), 0x03 (GET_ITEM_INFO),
 *         0x04 (GET_NPC_INFO), 0x05 (GET_SPELL_INFO), 0x06 (REQUEST_FEATURE),
 *         0x08 (REQUEST_SPELL_TOOLTIP_ENRICHMENT)
 * - SMSG: 0x10 (SETTINGS_SYNC), 0x11 (SETTING_UPDATED), 0x12 (ITEM_INFO),
 *         0x13 (NPC_INFO), 0x14 (SPELL_INFO), 0x15 (FEATURE_DATA), 0x16 (NOTIFICATION),
 *         0x17 (SPELL_TOOLTIP_ENRICHMENT)
 *
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "WorldSession.h"
#include "Chat.h"
#include "WorldPacket.h"
#include "DatabaseEnv.h"
#include "dc_addon_namespace.h"
#include "Config.h"
#include "Log.h"
#include "Creature.h"
#include "GameObject.h"
#include "ObjectMgr.h"
#include "ObjectAccessor.h"
#include "SpellMgr.h"
#include "SpellInfo.h"
#include "DBCStores.h"
#include "ItemTemplate.h"
#include "Group.h"
#include "Map.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "DC/ItemUpgrades/ItemUpgradeUIHelpers.h"
#include <atomic>
#include <chrono>
#include <string>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <cctype>
#include <cmath>
#include <set>
#include <mutex>
#include <unordered_map>
#include <vector>
#include "Mail.h"
#include "TradeData.h"

namespace DCQoS
{
    // Module identifier - must match client-side Protocol.lua
    constexpr const char* MODULE = "QOS";

    // Opcodes - must match client-side Protocol.lua
    namespace Opcode
    {
        // Client -> Server
        constexpr uint8 CMSG_SYNC_SETTINGS      = 0x01;  // Request full settings sync
        constexpr uint8 CMSG_UPDATE_SETTING     = 0x02;  // Update a single setting
        constexpr uint8 CMSG_GET_ITEM_INFO      = 0x03;  // Request custom item info
        constexpr uint8 CMSG_GET_NPC_INFO       = 0x04;  // Request custom NPC info (DB GUID)
        constexpr uint8 CMSG_GET_SPELL_INFO     = 0x05;  // Request custom spell info
        constexpr uint8 CMSG_REQUEST_FEATURE    = 0x06;  // Request specific feature data
        constexpr uint8 CMSG_COLLECT_ALL_MAIL   = 0x07;  // Request to collect all mail
        constexpr uint8 CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT = 0x08;  // Request server-enriched spell tooltip line

        // Server -> Client
        constexpr uint8 SMSG_SETTINGS_SYNC      = 0x10;  // Full settings sync
        constexpr uint8 SMSG_SETTING_UPDATED    = 0x11;  // Confirmation of setting update
        constexpr uint8 SMSG_ITEM_INFO          = 0x12;  // Custom item information
        constexpr uint8 SMSG_NPC_INFO           = 0x13;  // Custom NPC information
        constexpr uint8 SMSG_SPELL_INFO         = 0x14;  // Custom spell information
        constexpr uint8 SMSG_FEATURE_DATA       = 0x15;  // Feature-specific data
        constexpr uint8 SMSG_NOTIFICATION       = 0x16;  // Server notification
        constexpr uint8 SMSG_SPELL_TOOLTIP_ENRICHMENT = 0x17;  // requestId|spellId|contextHash|status|line
    }

    // Bridge reference to the custom client packet opcodes used by WotLK-Extensions.
    // AddonProtocol transport stays MODULE+uint8 opcode based, but payload fields are aligned.
    namespace BridgeOpcode
    {
        enum : uint16
        {
            CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT = ::CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT,
            SMSG_SPELL_TOOLTIP_ENRICHMENT = ::SMSG_SPELL_TOOLTIP_ENRICHMENT,
            CMSG_REQUEST_ITEM_UPGRADE_TOOLTIP = ::CMSG_REQUEST_ITEM_UPGRADE_TOOLTIP,
            SMSG_ITEM_UPGRADE_TOOLTIP = ::SMSG_ITEM_UPGRADE_TOOLTIP,
            CMSG_REQUEST_ITEM_TOOLTIP_SNAPSHOT = ::CMSG_REQUEST_ITEM_TOOLTIP_SNAPSHOT,
            SMSG_ITEM_TOOLTIP_SNAPSHOT = ::SMSG_ITEM_TOOLTIP_SNAPSHOT,
            CMSG_REQUEST_NPC_TOOLTIP_INFO = ::CMSG_REQUEST_NPC_TOOLTIP_INFO,
            SMSG_NPC_TOOLTIP_INFO = ::SMSG_NPC_TOOLTIP_INFO,
            CMSG_REQUEST_PING_RELAY = ::CMSG_REQUEST_QOS_PING_RELAY,
            SMSG_PING_RELAY = ::SMSG_QOS_PING_RELAY,
        };
    }

    namespace NativeEnvelopeFeature
    {
        constexpr char PING[] = "ping";
        constexpr char PING_STATE[] = "ping_state";
        constexpr char GRAPHICS_PROFILE[] = "graphics_profile";
        constexpr char GRAPHICS_PROFILE_STATE[] = "graphics_profile_state";
        constexpr char SERVER_TIME[] = "server_time";
        constexpr char PLAYER_STATS[] = "player_stats";
        constexpr char ACTION_RELAY[] = "relay";
        constexpr char ACTION_RELAY_ACK[] = "relay_ack";
        constexpr char ACTION_APPLY[] = "apply";
        constexpr char ACTION_INVALIDATE[] = "invalidate";
        constexpr char ACTION_RESPONSE[] = "response";
    }

    namespace RuntimeProfile
    {
        constexpr char SAFE[] = "SAFE";
        constexpr char WORLD[] = "WORLD";
        constexpr char RAID[] = "RAID";
        constexpr char BATTLEGROUND[] = "BATTLEGROUND";
    }

    struct RuntimeProfileSelection
    {
        std::string profileKey;
        std::string context;
    };

    static std::atomic<uint32> s_RuntimeProfileRevision{0};
    static std::atomic<uint32> s_FeatureResponseRevision{0};
    static std::unordered_map<uint32, std::string> s_LastRuntimeProfileByGuid;
    static std::mutex s_RuntimeProfileMutex;

    enum class SpellTooltipTransport
    {
        AddonJson,
        NativeBridge,
    };

    enum class SpellTooltipTransportPreference
    {
        Auto,
        ForceNativeBridge,
    };

    static CreatureData const* ResolveNpcTooltipSpawnData(Player* player,
        ObjectGuid const& guid, uint32 entry, uint32& spawnId);
    static void HandleItemUpgradeTooltipNativeRequest(Player* player,
        uint8 bag, uint8 slot);
    static void HandleItemTooltipSnapshotNativeRequest(Player* player,
        uint32 requestId, uint32 itemGuidLow, uint32 knownRevision,
        uint32 itemEntry, uint32 contextHash, uint32 ownerGuidLow,
        uint8 contextKind, uint8 bag, uint8 slot, uint8 flags);
    static void HandleNpcTooltipInfoNativeRequest(Player* player,
        std::string const& guidStr);
    static void HandlePingRelayNativeRequest(Player* player,
        std::string const& requestedDistribution,
        std::string const& payload);

    static bool SupportsNativeEnvelopeTransport(Player* player)
    {
        DCAddon::TransportPolicyRequest request;
        request.featureName = "dc-native-envelope";
        request.nativeCapability =
            DCAddon::ProtocolVersion::Capability::GENERIC_NATIVE_ENVELOPE;
        return DCAddon::ResolveTransportPolicy(player, request).UsesNative();
    }

    static uint32 NextRuntimeProfileRevision()
    {
        uint32 revision = ++s_RuntimeProfileRevision;
        if (revision == 0)
            revision = ++s_RuntimeProfileRevision;
        return revision;
    }

    static uint32 NextFeatureResponseRevision()
    {
        uint32 revision = ++s_FeatureResponseRevision;
        if (revision == 0)
            revision = ++s_FeatureResponseRevision;
        return revision;
    }

    static RuntimeProfileSelection SelectRuntimeProfile(Player* player)
    {
        RuntimeProfileSelection selection;
        selection.profileKey = RuntimeProfile::SAFE;
        selection.context = "fallback";

        if (!player)
            return selection;

        Map* map = player->GetMap();
        if (!map)
        {
            selection.context = "missing-map";
            return selection;
        }

        if (map->IsBattlegroundOrArena())
        {
            selection.profileKey = RuntimeProfile::BATTLEGROUND;
            selection.context = "battleground";
            return selection;
        }

        if (map->IsRaid())
        {
            selection.profileKey = RuntimeProfile::RAID;
            selection.context = "raid";
            return selection;
        }

        if (map->IsDungeon())
        {
            selection.profileKey = RuntimeProfile::WORLD;
            selection.context = "dungeon";
            return selection;
        }

        selection.profileKey = RuntimeProfile::WORLD;
        selection.context = "world";
        return selection;
    }

    static DCAddon::JsonValue BuildRuntimeProfileStatePayload(Player* player,
        RuntimeProfileSelection const& selection)
    {
        DCAddon::JsonValue payload;
        payload.SetObject();
        payload.Set("profile", selection.profileKey);
        payload.Set("profileContext", selection.context);

        if (!player)
            return payload;

        payload.Set("level", static_cast<int32>(player->GetLevel()));
        payload.Set("areaId", static_cast<int32>(player->GetAreaId()));
        payload.Set("zoneId", static_cast<int32>(player->GetZoneId()));

        Group* group = player->GetGroup();
        payload.Set("inGroup", group != nullptr);
        payload.Set("inRaidGroup", group && group->isRaidGroup());

        Map* map = player->GetMap();
        payload.Set("hasMap", map != nullptr);
        if (!map)
            return payload;

        payload.Set("mapId", static_cast<int32>(map->GetId()));
        payload.Set("instanceId", static_cast<int32>(map->GetInstanceId()));
        payload.Set("isDungeon", map->IsDungeon());
        payload.Set("isRaid", map->IsRaid());
        payload.Set("isBattleground", map->IsBattlegroundOrArena());
        payload.Set("isWorldMap",
            !map->IsDungeon() && !map->IsRaid()
                && !map->IsBattlegroundOrArena());

        return payload;
    }

    static void SendRuntimeProfileFallback(Player* player,
        std::string const& action, RuntimeProfileSelection const& selection,
        uint32 revision)
    {
        if (!player)
            return;

        DCAddon::JsonMessage message(MODULE, Opcode::SMSG_FEATURE_DATA);
        message.Set("feature", NativeEnvelopeFeature::GRAPHICS_PROFILE);
        message.Set("action", action);
        message.Set("profile", selection.profileKey);
        message.Set("context", selection.context);
        message.Set("revision", static_cast<int32>(revision));
        message.Send(player);
    }

    static void SendRuntimeProfileNative(Player* player,
        std::string const& action, RuntimeProfileSelection const& selection,
        uint32 revision)
    {
        DCAddon::SendNativeEnvelope(player, MODULE, Opcode::SMSG_FEATURE_DATA,
            NativeEnvelopeFeature::GRAPHICS_PROFILE, action, revision,
            selection.profileKey, selection.context);
    }

    static void SendRuntimeProfileMessage(Player* player,
        std::string const& action, RuntimeProfileSelection const& selection,
        uint32 revision)
    {
        if (!player)
            return;

        if (SupportsNativeEnvelopeTransport(player))
        {
            SendRuntimeProfileNative(player, action, selection, revision);
            return;
        }

        SendRuntimeProfileFallback(player, action, selection, revision);
    }

    static DCAddon::JsonValue BuildFeatureEnvelope(
        std::string const& feature, std::string const& action,
        uint32 revision, std::string const& context,
        DCAddon::JsonValue const& payload)
    {
        DCAddon::JsonValue envelope;
        envelope.SetObject();

        if (payload.IsObject())
        {
            for (auto const& [key, value] : payload.AsObject())
                envelope.Set(key, value);
        }

        if (!payload.IsObject())
            envelope.Set("data", payload);

        envelope.Set("feature", feature);
        envelope.Set("action", action);
        envelope.Set("revision", static_cast<int32>(revision));
        if (!context.empty())
            envelope.Set("context", context);
        return envelope;
    }

    static void SendFeatureFallback(Player* player,
        std::string const& feature, std::string const& action,
        uint32 revision, std::string const& context,
        DCAddon::JsonValue const& payload)
    {
        if (!player)
            return;

        DCAddon::JsonMessage(MODULE, Opcode::SMSG_FEATURE_DATA,
            BuildFeatureEnvelope(feature, action, revision, context,
                payload)).Send(player);
    }

    static void SendFeatureNative(Player* player,
        std::string const& feature, std::string const& action,
        uint32 revision, DCAddon::JsonValue const& payload,
        std::string const& context)
    {
        if (!player)
            return;

        DCAddon::SendNativeEnvelope(player, MODULE, Opcode::SMSG_FEATURE_DATA,
            feature, action, revision, payload.Encode(), context);
    }

    static void SendFeatureMessage(Player* player,
        std::string const& feature, std::string const& action,
        DCAddon::JsonValue const& payload, std::string const& context)
    {
        if (!player)
            return;

        uint32 revision = NextFeatureResponseRevision();

        if (SupportsNativeEnvelopeTransport(player))
        {
            SendFeatureNative(player, feature, action, revision, payload,
                context);
            return;
        }

        SendFeatureFallback(player, feature, action, revision, context,
            payload);
    }

    static void SendFeatureResponse(Player* player,
        std::string const& feature, DCAddon::JsonValue const& payload,
        std::string const& context)
    {
        SendFeatureMessage(player, feature,
            NativeEnvelopeFeature::ACTION_RESPONSE, payload, context);
    }

    static void PushRuntimeProfile(Player* player, bool forceResend,
        std::string const& triggerContext)
    {
        if (!player)
            return;

        RuntimeProfileSelection selection = SelectRuntimeProfile(player);
        if (!triggerContext.empty())
            selection.context = triggerContext + ":" + selection.context;

        uint32 guidLow = player->GetGUID().GetCounter();
        std::string previousProfile;
        bool shouldSend = forceResend;

        {
            std::lock_guard<std::mutex> lock(s_RuntimeProfileMutex);
            auto itr = s_LastRuntimeProfileByGuid.find(guidLow);
            if (itr != s_LastRuntimeProfileByGuid.end())
                previousProfile = itr->second;

            if (!shouldSend)
                shouldSend = previousProfile != selection.profileKey;

            s_LastRuntimeProfileByGuid[guidLow] = selection.profileKey;
        }

        if (!shouldSend)
            return;

        if (!previousProfile.empty() && previousProfile != selection.profileKey)
        {
            RuntimeProfileSelection invalidation;
            invalidation.profileKey = previousProfile;
            invalidation.context = triggerContext + ":profile-changed";
            SendRuntimeProfileMessage(player,
                NativeEnvelopeFeature::ACTION_INVALIDATE,
                invalidation, NextRuntimeProfileRevision());
        }

        SendRuntimeProfileMessage(player, NativeEnvelopeFeature::ACTION_APPLY,
            selection, NextRuntimeProfileRevision());
    }

    // Configuration keys
    namespace Config
    {
        constexpr const char* ENABLED = "DC.AddonProtocol.QoS.Enable";
        constexpr const char* TOOLTIP_TRANSPORT_DEBUG =
            "DC.QoS.TooltipTransport.Debug";
    }

    // =======================================================================
    // Settings Storage
    // =======================================================================

    // Per-player QoS settings (stored in dc_player_qos_settings table)
    struct QoSSettings
    {
        // Tooltip settings
        bool tooltipsEnabled = true;
        bool showItemId = true;
        bool showItemLevel = true;
        bool showNpcId = true;
        bool showSpellId = true;
        bool showSpellFamilyMetadata = false;
        bool showGuildRank = true;
        bool showTarget = true;
        bool hideHealthBar = false;
        bool hideInCombat = false;
        float tooltipScale = 1.0f;

        // Automation settings
        bool automationEnabled = true;
        bool autoRepair = true;
        bool autoRepairGuild = false;
        bool autoSellJunk = true;
        bool autoDismount = false;
        bool autoAcceptSummon = false;
        bool autoAcceptResurrect = false;
        bool autoDeclineDuels = false;
        bool autoAcceptQuests = false;
        bool autoTurnInQuests = false;

        // Chat settings
        bool chatEnabled = true;
        bool hideChannelNames = false;
        bool stickyChannels = true;

        // Interface settings
        bool interfaceEnabled = true;
        bool combatPlates = false;
        bool questLevelText = true;
    };

    static std::unordered_map<uint32, QoSSettings> s_PlayerSettingsCache;
    static std::mutex s_PlayerSettingsCacheMutex;

    // Spell-tooltip enrichment line cache.
    // SMSG_SPELL_TOOLTIP_ENRICHMENT is by far the highest-volume DC addon
    // message (~58% of all protocol traffic), and BuildSpellTooltipEnrichmentLine()
    // is its expensive step (description-template rendering + per-effect
    // formatting from live player stats). The line depends on the player's
    // spell power / attack power (gear), which the protocol contextHash does
    // NOT capture (it folds in spellId/level/class/form/talentGroup only), so
    // the cache is keyed PER PLAYER -- sharing across players would leak one
    // player's gear-scaled numbers to another with the same context. A short
    // TTL bounds staleness when gear changes without a contextHash change.
    struct SpellTooltipLineKey
    {
        uint32 guid;
        uint32 spellId;
        uint32 contextHash;

        bool operator==(SpellTooltipLineKey const& other) const
        {
            return guid == other.guid && spellId == other.spellId
                && contextHash == other.contextHash;
        }
    };

    struct SpellTooltipLineKeyHash
    {
        std::size_t operator()(SpellTooltipLineKey const& key) const
        {
            std::size_t hash = 1469598103934665603ULL;
            for (uint32 part : { key.guid, key.spellId, key.contextHash })
            {
                hash ^= part;
                hash *= 1099511628211ULL;
            }
            return hash;
        }
    };

    struct SpellTooltipLineCacheEntry
    {
        std::string line;
        time_t expiresAt = 0;
    };

    static std::unordered_map<SpellTooltipLineKey, SpellTooltipLineCacheEntry,
        SpellTooltipLineKeyHash> s_SpellTooltipLineCache;
    static std::mutex s_SpellTooltipLineCacheMutex;
    static constexpr std::size_t SPELL_TOOLTIP_LINE_CACHE_SOFT_CAP = 8192;

    // =======================================================================
    // Helper Functions
    // =======================================================================

    static bool IsEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::ENABLED, true);
    }

    static bool IsTooltipTransportDebugEnabled()
    {
        return sConfigMgr->GetOption<bool>(Config::TOOLTIP_TRANSPORT_DEBUG,
            false);
    }

    struct SpellTooltipTransportDecision
    {
        SpellTooltipTransport transport = SpellTooltipTransport::AddonJson;
        std::string reason = "default-addon";
        DCAddon::SessionCapabilityState capabilityState;
        bool hasCapabilityState = false;
    };

    static char const* ToString(SpellTooltipTransport transport)
    {
        switch (transport)
        {
            case SpellTooltipTransport::NativeBridge:
                return "native-bridge";
            case SpellTooltipTransport::AddonJson:
            default:
                return "addon-json";
        }
    }

    static SpellTooltipTransportDecision ResolveSpellTooltipTransportDecision(
        Player* player,
        std::string const& protocolRequestId,
        SpellTooltipTransportPreference preference =
            SpellTooltipTransportPreference::Auto)
    {
        DCAddon::TransportPolicyRequest request;
        request.featureName = "spell-tooltip";
        request.nativeCapability =
            DCAddon::ProtocolVersion::Capability::TOOLTIP_NATIVE_RESPONSE;
        request.forceNative =
            preference == SpellTooltipTransportPreference::ForceNativeBridge;
        request.forceNativeReason = "forced-native";
        request.forceAddon = !protocolRequestId.empty();
        request.forceAddonReason = "addon-request-id";
        request.versionIncompatibleReason = "version-incompatible";
        request.negotiatedCapabilityMissingReason =
            "native-capability-missing";
        request.nativeReadyReason = "negotiated-native";

        DCAddon::TransportPolicyDecision policy =
            DCAddon::ResolveTransportPolicy(player, request);

        SpellTooltipTransportDecision decision;
        decision.transport = policy.UsesNative()
            ? SpellTooltipTransport::NativeBridge
            : SpellTooltipTransport::AddonJson;
        decision.reason = policy.reason;
        decision.capabilityState = policy.capabilityState;
        decision.hasCapabilityState = policy.hasCapabilityState;
        return decision;
    }

    static void AuditNpcTooltipTransport(Player* player, bool forceNative)
    {
        if (!player)
            return;

        DCAddon::TransportPolicyRequest request;
        request.featureName = "npc-tooltip";
        request.nativeCapability =
            DCAddon::ProtocolVersion::Capability::NPC_TOOLTIP_NATIVE;
        request.forceNative = forceNative;
        request.forceNativeReason = "forced-native";
        request.forceAddon = !forceNative;
        request.forceAddonReason = "addon-tooltip-request";
        request.versionIncompatibleReason = "version-incompatible";
        request.negotiatedCapabilityMissingReason =
            "native-capability-missing";
        request.nativeReadyReason = "negotiated-native";
        DCAddon::ResolveTransportPolicy(player, request);
    }

    static void AuditItemUpgradeTooltipTransport(Player* player,
        bool forceNative)
    {
        if (!player)
            return;

        DCAddon::TransportPolicyRequest request;
        request.featureName = "item-upgrade-tooltip";
        request.nativeCapability =
            DCAddon::ProtocolVersion::Capability::ITEM_UPGRADE_NATIVE;
        request.forceNative = forceNative;
        request.forceNativeReason = "forced-native";
        request.forceAddon = !forceNative;
        request.forceAddonReason = "addon-tooltip-request";
        request.versionIncompatibleReason = "version-incompatible";
        request.negotiatedCapabilityMissingReason =
            "native-capability-missing";
        request.nativeReadyReason = "negotiated-native";
        DCAddon::ResolveTransportPolicy(player, request);
    }

    static void AuditItemTooltipSnapshotTransport(Player* player,
        bool forceNative)
    {
        if (!player)
            return;

        DCAddon::TransportPolicyRequest request;
        request.featureName = "item-tooltip-snapshot";
        request.nativeCapability =
            DCAddon::ProtocolVersion::Capability::ITEM_TOOLTIP_REPLACEMENT_NATIVE;
        request.forceNative = forceNative;
        request.forceNativeReason = "forced-native";
        request.forceAddon = !forceNative;
        request.forceAddonReason = "addon-tooltip-request";
        request.versionIncompatibleReason = "version-incompatible";
        request.negotiatedCapabilityMissingReason =
            "native-capability-missing";
        request.nativeReadyReason = "negotiated-native";
        DCAddon::ResolveTransportPolicy(player, request);
    }

    static void SendSpellTooltipEnrichmentNative(Player* player,
        uint32 requestId, uint32 spellId, uint32 contextHash, uint8 status,
        std::string const& line,
        DCAddon::JsonValue const* structuredLines = nullptr)
    {
        if (!player || !player->GetSession())
            return;

        std::size_t lineCount = structuredLines && structuredLines->IsArray()
            ? structuredLines->Size()
            : 0;
        WorldPacket data(BridgeOpcode::SMSG_SPELL_TOOLTIP_ENRICHMENT,
            line.size() + 28 + (lineCount * 64));
        data << int32(requestId);
        data << int32(spellId);
        data << int32(contextHash);
        data << int32(status);
        data << line;

        data << int32(lineCount);
        for (std::size_t index = 0; index < lineCount; ++index)
        {
            DCAddon::JsonValue const& entry = (*structuredLines)[index];
            std::string left = entry.IsObject() && entry.HasKey("left")
                && entry["left"].IsString()
                    ? entry["left"].AsString()
                    : "";
            std::string right = entry.IsObject() && entry.HasKey("right")
                && entry["right"].IsString()
                    ? entry["right"].AsString()
                    : "";
            std::string kind = entry.IsObject() && entry.HasKey("kind")
                && entry["kind"].IsString()
                    ? entry["kind"].AsString()
                    : "";
            data << left;
            data << right;
            data << kind;
        }

        player->GetSession()->SendPacket(&data);
        std::string preview = "req=" + std::to_string(requestId)
            + "|spell=" + std::to_string(spellId)
            + "|ctx=" + std::to_string(contextHash)
            + "|status=" + std::to_string(status)
            + "|lines=" + std::to_string(lineCount);
        DCAddon::LogNativeS2CMessage(player, MODULE,
            Opcode::SMSG_SPELL_TOOLTIP_ENRICHMENT,
            BridgeOpcode::SMSG_SPELL_TOOLTIP_ENRICHMENT, data.size(),
            preview, true, 0);
    }

    static void SendItemUpgradeInfoNativeError(Player* player, uint8 bag,
        uint8 slot, std::string const& error)
    {
        if (!player || !player->GetSession())
            return;

        WorldPacket data(BridgeOpcode::SMSG_ITEM_UPGRADE_TOOLTIP,
            error.size() + 48);
        data << int32(bag);
        data << int32(slot);
        data << int32(0);
        data << int32(0);
        data << int32(0);
        data << int32(0);
        data << int32(10000);
        data << int32(0);
        data << int32(0);
        data << error;
        player->GetSession()->SendPacket(&data);
        std::string preview = "bag=" + std::to_string(bag)
            + "|slot=" + std::to_string(slot)
            + "|error=" + error;
        DCAddon::LogNativeS2CMessage(player, MODULE, Opcode::SMSG_ITEM_INFO,
            BridgeOpcode::SMSG_ITEM_UPGRADE_TOOLTIP, data.size(), preview,
            true, 0);
    }

    namespace ItemTooltipSnapshotStatus
    {
        constexpr uint32 OK = 0;
        constexpr uint32 NOT_MODIFIED = 1;
        constexpr uint32 ITEM_NOT_FOUND = 2;
        constexpr uint32 NOT_VISIBLE = 3;
        constexpr uint32 UNSUPPORTED_CONTEXT = 4;
        constexpr uint32 SERVER_ERROR = 5;
    }

    namespace ItemTooltipSnapshotContextKind
    {
        constexpr uint8 BAG = 0;
        constexpr uint8 EQUIPPED = 1;
        constexpr uint8 COMPARE = 2;
        constexpr uint8 INSPECT = 3;
        constexpr uint8 TRADE = 4;
        constexpr uint8 MAIL = 5;
        constexpr uint8 LINK = 6;
    }

    struct ItemTooltipSnapshotNativeRequest
    {
        uint32 requestId = 0;
        uint32 itemGuidLow = 0;
        uint32 knownRevision = 0;
        uint32 itemEntry = 0;
        uint32 contextHash = 0;
        uint32 ownerGuidLow = 0;
        uint8 contextKind = ItemTooltipSnapshotContextKind::BAG;
        uint8 bag = 0;
        uint8 slot = 0;
        uint8 flags = 0;
    };

    struct ItemTooltipSnapshotRow
    {
        std::string left;
        std::string right;
        std::string kind;
        std::string classification;
    };

    static std::string GetSpellDescriptionTemplate(uint32 spellId);
    static std::string RenderSpellDescriptionTemplate(Player* player,
        SpellInfo const* spellInfo, std::string const& sourceTemplate);

    static void AppendItemTooltipSnapshotRow(
        std::vector<ItemTooltipSnapshotRow>& rows,
        std::string const& left, std::string const& right,
        char const* kind, char const* classification)
    {
        if (left.empty() && right.empty())
            return;

        rows.push_back({ left, right, kind ? kind : "",
            classification ? classification : "" });
    }

    static std::string FormatItemSellPrice(uint32 copper)
    {
        uint32 gold = copper / 10000;
        uint32 silver = (copper % 10000) / 100;
        uint32 copperRemainder = copper % 100;
        std::ostringstream price;
        bool hasValue = false;

        if (gold > 0)
        {
            price << gold << "g";
            hasValue = true;
        }

        if (silver > 0 || (hasValue && copperRemainder > 0))
        {
            if (hasValue)
                price << ' ';

            price << silver << "s";
            hasValue = true;
        }

        if (copperRemainder > 0 || !hasValue)
        {
            if (hasValue)
                price << ' ';

            price << copperRemainder << "c";
        }

        return price.str();
    }

    static bool BuildAllowableClassText(uint32 allowableClass,
        std::string& outText)
    {
        if (allowableClass == 0 || allowableClass == uint32(-1)
            || allowableClass == CLASSMASK_ALL_PLAYABLE)
        {
            return false;
        }

        std::ostringstream text;
        bool foundAny = false;
        text << "Classes: ";

        for (uint32 classId = CLASS_WARRIOR; classId < MAX_CLASSES; ++classId)
        {
            uint32 classMask = 1u << (classId - 1);
            if ((allowableClass & classMask) == 0)
                continue;

            ChrClassesEntry const* classEntry =
                sChrClassesStore.LookupEntry(classId);
            if (foundAny)
                text << ", ";

            if (classEntry && classEntry->name[0] && *classEntry->name[0])
                text << classEntry->name[0];
            else
                text << "Class " << classId;

            foundAny = true;
        }

        if (!foundAny)
            return false;

        outText = text.str();
        return true;
    }

    static bool BuildAllowableRaceText(uint32 allowableRace,
        std::string& outText)
    {
        if (allowableRace == 0 || allowableRace == uint32(-1))
            return false;

        std::ostringstream text;
        bool foundAny = false;
        text << "Races: ";

        for (auto const* raceEntry : sChrRacesStore)
        {
            if (!raceEntry || raceEntry->RaceID == 0 || raceEntry->RaceID > 32)
                continue;

            uint32 raceMask = 1u << (raceEntry->RaceID - 1);
            if ((allowableRace & raceMask) == 0)
                continue;

            if (foundAny)
                text << ", ";

            if (raceEntry->name[0] && *raceEntry->name[0])
                text << raceEntry->name[0];
            else
                text << "Race " << raceEntry->RaceID;

            foundAny = true;
        }

        if (!foundAny)
            return false;

        outText = text.str();
        return true;
    }

    static char const* GetItemStatLabel(uint32 statType)
    {
        switch (statType)
        {
            case ITEM_MOD_MANA: return "Mana";
            case ITEM_MOD_HEALTH: return "Health";
            case ITEM_MOD_AGILITY: return "Agility";
            case ITEM_MOD_STRENGTH: return "Strength";
            case ITEM_MOD_INTELLECT: return "Intellect";
            case ITEM_MOD_SPIRIT: return "Spirit";
            case ITEM_MOD_STAMINA: return "Stamina";
            case ITEM_MOD_DEFENSE_SKILL_RATING: return "Defense Rating";
            case ITEM_MOD_DODGE_RATING: return "Dodge Rating";
            case ITEM_MOD_PARRY_RATING: return "Parry Rating";
            case ITEM_MOD_BLOCK_RATING: return "Block Rating";
            case ITEM_MOD_HIT_RATING: return "Hit Rating";
            case ITEM_MOD_CRIT_RATING: return "Crit Rating";
            case ITEM_MOD_RESILIENCE_RATING: return "Resilience Rating";
            case ITEM_MOD_HASTE_RATING: return "Haste Rating";
            case ITEM_MOD_EXPERTISE_RATING: return "Expertise Rating";
            case ITEM_MOD_ATTACK_POWER: return "Attack Power";
            case ITEM_MOD_RANGED_ATTACK_POWER: return "Ranged Attack Power";
            case ITEM_MOD_MANA_REGENERATION: return "Mana per 5 sec";
            case ITEM_MOD_ARMOR_PENETRATION_RATING:
                return "Armor Penetration Rating";
            case ITEM_MOD_SPELL_POWER: return "Spell Power";
            case ITEM_MOD_HEALTH_REGEN: return "Health per 5 sec";
            case ITEM_MOD_SPELL_PENETRATION: return "Spell Penetration";
            case ITEM_MOD_BLOCK_VALUE: return "Block Value";
            case ITEM_MOD_HIT_MELEE_RATING: return "Hit Rating (Melee)";
            case ITEM_MOD_HIT_RANGED_RATING: return "Hit Rating (Ranged)";
            case ITEM_MOD_HIT_SPELL_RATING: return "Hit Rating (Spell)";
            case ITEM_MOD_CRIT_MELEE_RATING: return "Crit Rating (Melee)";
            case ITEM_MOD_CRIT_RANGED_RATING: return "Crit Rating (Ranged)";
            case ITEM_MOD_CRIT_SPELL_RATING: return "Crit Rating (Spell)";
            case ITEM_MOD_HASTE_MELEE_RATING:
                return "Haste Rating (Melee)";
            case ITEM_MOD_HASTE_RANGED_RATING:
                return "Haste Rating (Ranged)";
            case ITEM_MOD_HASTE_SPELL_RATING:
                return "Haste Rating (Spell)";
            default:
                return nullptr;
        }
    }

    static std::string FormatSignedItemStat(int32 value, char const* label)
    {
        if (!label || value == 0)
            return "";

        std::ostringstream out;
        if (value > 0)
            out << '+';
        out << value << ' ' << label;
        return out.str();
    }

    static std::string FormatUpgradeBonusPercent(uint32 basisPoints)
    {
        double bonusPercent =
            (static_cast<double>(basisPoints) - 10000.0) / 100.0;
        std::ostringstream out;
        out << std::fixed;
        if (std::fabs(std::round(bonusPercent) - bonusPercent) < 0.01)
            out << std::setprecision(0);
        else
            out << std::setprecision(1);
        out << '+' << bonusPercent << '%';
        return out.str();
    }

    static char const* GetReputationRankLabel(uint32 rank)
    {
        switch (rank)
        {
            case REP_HATED: return "Hated";
            case REP_HOSTILE: return "Hostile";
            case REP_UNFRIENDLY: return "Unfriendly";
            case REP_NEUTRAL: return "Neutral";
            case REP_FRIENDLY: return "Friendly";
            case REP_HONORED: return "Honored";
            case REP_REVERED: return "Revered";
            case REP_EXALTED: return "Exalted";
            default: return "Unknown";
        }
    }

    static std::string GetSocketColorLabel(uint32 socketColor)
    {
        switch (socketColor)
        {
            case SOCKET_COLOR_META: return "Meta Socket";
            case SOCKET_COLOR_RED: return "Red Socket";
            case SOCKET_COLOR_YELLOW: return "Yellow Socket";
            case SOCKET_COLOR_BLUE: return "Blue Socket";
            default: return "Socket";
        }
    }

    static std::string GetSocketGemName(Item* item,
        EnchantmentSlot socketSlot)
    {
        if (!item)
            return "";

        uint32 enchantId = item->GetEnchantmentId(socketSlot);
        if (!enchantId)
            return "";

        SpellItemEnchantmentEntry const* enchant =
            sSpellItemEnchantmentStore.LookupEntry(enchantId);
        if (!enchant || !enchant->GemID)
            return "";

        if (ItemTemplate const* gemTemplate =
                sObjectMgr->GetItemTemplate(enchant->GemID))
        {
            return gemTemplate->Name1;
        }

        return "";
    }

    static char const* GetItemSpellTriggerPrefix(uint32 trigger)
    {
        switch (trigger)
        {
            case ITEM_SPELLTRIGGER_ON_USE:
            case ITEM_SPELLTRIGGER_ON_NO_DELAY_USE:
            case ITEM_SPELLTRIGGER_SOULSTONE:
                return "Use: ";
            case ITEM_SPELLTRIGGER_ON_EQUIP:
                return "Equip: ";
            case ITEM_SPELLTRIGGER_CHANCE_ON_HIT:
                return "Chance on hit: ";
            case ITEM_SPELLTRIGGER_LEARN_SPELL_ID:
                return "Teaches: ";
            default:
                return "";
        }
    }

    static std::string BuildItemSpellTooltipText(Player* player,
        int32 spellId, uint32 trigger)
    {
        if (spellId <= 0)
            return "";

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(uint32(spellId));
        if (!spellInfo)
            return "";

        std::string rendered = RenderSpellDescriptionTemplate(player,
            spellInfo, GetSpellDescriptionTemplate(uint32(spellId)));
        if (rendered.empty() && spellInfo->SpellName[0]
            && *spellInfo->SpellName[0])
        {
            rendered = spellInfo->SpellName[0];
        }

        if (rendered.empty())
            return "";

        return std::string(GetItemSpellTriggerPrefix(trigger)) + rendered;
    }

    static uint32 CountItemSetPiecesEquipped(Player* player, uint32 itemSetId)
    {
        if (!player || !itemSetId)
            return 0;

        uint32 equippedPieces = 0;
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END;
             ++slot)
        {
            Item* equippedItem =
                player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!equippedItem)
                continue;

            ItemTemplate const* equippedTemplate = equippedItem->GetTemplate();
            if (!equippedTemplate || equippedTemplate->ItemSet != itemSetId)
                continue;

            ++equippedPieces;
        }

        return equippedPieces;
    }

    static uint32 CountItemSetPieces(ItemSetEntry const* itemSet)
    {
        if (!itemSet)
            return 0;

        uint32 totalPieces = 0;
        for (uint32 itemId : itemSet->itemId)
        {
            if (itemId != 0)
                ++totalPieces;
        }

        return totalPieces;
    }

    struct HeirloomPackageDefinition
    {
        char const* name;
        char const* statNames[3];
        uint8 statCount;
    };

    struct HeirloomPackageTooltipState
    {
        uint32 packageId = 0;
        uint32 upgradeLevel = 0;
    };

    static bool TryGetHeirloomPackageDefinition(uint32 packageId,
        HeirloomPackageDefinition& out)
    {
        using namespace DarkChaos::ItemUpgrade::UI;

        static HeirloomPackageDefinition const definitions[
            HEIRLOOM_MAX_PACKAGE_ID + 1] =
        {
            { "", { nullptr, nullptr, nullptr }, 0 },
            { "Fury", { "Crit Rating", "Haste Rating", nullptr }, 2 },
            { "Precision", { "Hit Rating", "Expertise Rating", nullptr }, 2 },
            { "Devastation", { "Crit Rating", "Armor Pen", nullptr }, 2 },
            { "Swiftblade", { "Haste Rating", "Armor Pen", nullptr }, 2 },
            { "Spellfire", { "Spell Crit", "Spell Haste", "Spell Power" }, 3 },
            { "Arcane", { "Spell Hit", "Spell Haste", "Spell Power" }, 3 },
            { "Bulwark", { "Dodge Rating", "Parry Rating", "Block Rating" }, 3 },
            { "Fortress", { "Defense Rating", "Block Rating", "Stamina" }, 3 },
            { "Survivor", { "Dodge Rating", "Stamina", nullptr }, 2 },
            { "Gladiator", { "Resilience", "Crit Rating", nullptr }, 2 },
            { "Warlord", { "Resilience", "Stamina", nullptr }, 2 },
            { "Balanced", { "Crit Rating", "Hit Rating", "Haste Rating" }, 3 },
        };

        if (packageId == 0 || packageId > HEIRLOOM_MAX_PACKAGE_ID)
            return false;

        out = definitions[packageId];
        return out.name && *out.name && out.statCount > 0;
    }

    static uint32 GetHeirloomPackageBudget(uint32 upgradeLevel)
    {
        using namespace DarkChaos::ItemUpgrade::UI;

        static uint32 const budgets[HEIRLOOM_MAX_LEVEL + 1] =
        {
            0,
            6,
            14,
            22,
            32,
            43,
            55,
            67,
            80,
            95,
            110,
            126,
            142,
            157,
            168,
            168,
        };

        if (upgradeLevel == 0 || upgradeLevel > HEIRLOOM_MAX_LEVEL)
            return 0;

        return budgets[upgradeLevel];
    }

    static HeirloomPackageTooltipState ResolveHeirloomPackageTooltipState(
        Item* item,
        DarkChaos::ItemUpgrade::ItemUpgradeTooltipSnapshot const& snapshot)
    {
        using namespace DarkChaos::ItemUpgrade::UI;

        HeirloomPackageTooltipState state;
        if (!item || !IsHeirloomEntry(item->GetEntry()))
            return state;

        uint32 enchantId = item->GetEnchantmentId(PERM_ENCHANTMENT_SLOT);
        // Determine which enchant range this item uses (Frontier tier 10 vs standard).
        uint32 resolvedBase = 0;
        if (enchantId >= FRONTIER_HEIRLOOM_ENCHANT_BASE_ID
            && enchantId < FRONTIER_HEIRLOOM_ENCHANT_BASE_ID + 20000)
            resolvedBase = FRONTIER_HEIRLOOM_ENCHANT_BASE_ID;
        else if (enchantId > HEIRLOOM_ENCHANT_BASE_ID
            && enchantId < HEIRLOOM_ENCHANT_BASE_ID + 20000)
            resolvedBase = HEIRLOOM_ENCHANT_BASE_ID;

        if (resolvedBase > 0)
        {
            uint32 encodedState = enchantId - resolvedBase;
            uint32 packageId = encodedState / 100;
            uint32 upgradeLevel = encodedState % 100;

            if (packageId >= 1 && packageId <= HEIRLOOM_MAX_PACKAGE_ID
                && upgradeLevel >= 1 && upgradeLevel <= HEIRLOOM_MAX_LEVEL)
            {
                state.packageId = packageId;
                state.upgradeLevel = upgradeLevel;
                return state;
            }
        }

        if (snapshot.upgrade_level >= 1
            && snapshot.upgrade_level <= HEIRLOOM_MAX_LEVEL)
        {
            state.upgradeLevel = snapshot.upgrade_level;
        }

        return state;
    }

    static void AppendHeirloomPackageTooltipRows(
        std::vector<ItemTooltipSnapshotRow>& rows,
        HeirloomPackageTooltipState const& state)
    {
        HeirloomPackageDefinition definition{};
        if (state.packageId == 0 || state.upgradeLevel == 0
            || !TryGetHeirloomPackageDefinition(state.packageId, definition))
        {
            return;
        }

        uint32 totalBudget = GetHeirloomPackageBudget(state.upgradeLevel);
        if (totalBudget == 0)
            return;

        AppendItemTooltipSnapshotRow(rows, "Package", definition.name,
            "append-body", "set-name");
        AppendItemTooltipSnapshotRow(rows, "-- Package Stats --", "",
            "append-body", "meta");

        uint32 perStat = totalBudget / definition.statCount;
        uint32 remainder = totalBudget - (perStat * definition.statCount);

        for (uint32 statIndex = 0; statIndex < definition.statCount;
             ++statIndex)
        {
            uint32 value = perStat + (statIndex < remainder ? 1u : 0u);
            std::string line = FormatSignedItemStat(static_cast<int32>(value),
                definition.statNames[statIndex]);
            if (!line.empty())
                AppendItemTooltipSnapshotRow(rows, line, "",
                    "append-body", "stat");
        }
    }

    static std::vector<ItemTooltipSnapshotRow> BuildItemTooltipSnapshotRows(
        Player* player,
        Item* item,
        DarkChaos::ItemUpgrade::ItemUpgradeTooltipSnapshot const& snapshot)
    {
        std::vector<ItemTooltipSnapshotRow> rows;
        if (!item)
            return rows;

        ItemTemplate const* itemTemplate = item->GetTemplate();
        HeirloomPackageTooltipState const heirloomPackageState =
            ResolveHeirloomPackageTooltipState(item, snapshot);

        uint32 displayUpgradeLevel = snapshot.upgrade_level;
        if (heirloomPackageState.upgradeLevel > displayUpgradeLevel)
            displayUpgradeLevel = heirloomPackageState.upgradeLevel;

        uint32 displayMaxUpgrade = snapshot.max_upgrade;
        if (displayMaxUpgrade == 0
            && DarkChaos::ItemUpgrade::UI::IsHeirloomEntry(item->GetEntry()))
        {
            displayMaxUpgrade = DarkChaos::ItemUpgrade::UI::GetHeirloomMaxLevel(item->GetEntry());
        }
        if (displayMaxUpgrade == 0 && displayUpgradeLevel > 0)
            displayMaxUpgrade = displayUpgradeLevel;

        if (!snapshot.has_persisted_state)
        {
            AppendHeirloomPackageTooltipRows(rows, heirloomPackageState);

            if (displayMaxUpgrade > 0)
            {
                AppendItemTooltipSnapshotRow(rows, "Upgrade",
                    std::to_string(displayUpgradeLevel) + "/"
                        + std::to_string(displayMaxUpgrade),
                    "append-meta", "upgrade");
            }

            return rows;
        }

        double multiplier =
            static_cast<double>(snapshot.stat_multiplier_basis_points) / 10000.0;

        if (snapshot.upgraded_ilvl > 0)
        {
            AppendItemTooltipSnapshotRow(rows, "Item Level",
                std::to_string(snapshot.upgraded_ilvl), "replace-stat",
                "item-level");
        }

        if (itemTemplate)
        {
            if (itemTemplate->Armor > 0)
            {
                uint32 scaledArmor = static_cast<uint32>(std::max<int64>(0,
                    static_cast<int64>(std::lround(
                        static_cast<double>(itemTemplate->Armor) * multiplier))));
                AppendItemTooltipSnapshotRow(rows,
                    std::to_string(scaledArmor) + " Armor", "",
                    "replace-stat", "armor");
            }

            if (itemTemplate->Block > 0)
            {
                uint32 scaledBlock = static_cast<uint32>(std::max<int64>(0,
                    static_cast<int64>(std::lround(
                        static_cast<double>(itemTemplate->Block) * multiplier))));
                AppendItemTooltipSnapshotRow(rows,
                    std::to_string(scaledBlock) + " Block", "",
                    "replace-stat", "armor");
            }

            struct ResistanceRow
            {
                int32 value;
                char const* label;
            };

            ResistanceRow const resistances[] =
            {
                { itemTemplate->HolyRes, "Holy Resistance" },
                { itemTemplate->FireRes, "Fire Resistance" },
                { itemTemplate->NatureRes, "Nature Resistance" },
                { itemTemplate->FrostRes, "Frost Resistance" },
                { itemTemplate->ShadowRes, "Shadow Resistance" },
                { itemTemplate->ArcaneRes, "Arcane Resistance" },
            };

            for (ResistanceRow const& resistance : resistances)
            {
                if (resistance.value == 0)
                    continue;

                int32 scaledValue = static_cast<int32>(std::lround(
                    static_cast<double>(resistance.value) * multiplier));
                std::string line =
                    FormatSignedItemStat(scaledValue, resistance.label);
                if (!line.empty())
                    AppendItemTooltipSnapshotRow(rows, line, "",
                        "replace-stat", "resistance");
            }

            for (uint32 damageIndex = 0;
                 damageIndex < MAX_ITEM_PROTO_DAMAGES; ++damageIndex)
            {
                _Damage const& damage = itemTemplate->Damage[damageIndex];
                if (damage.DamageMax <= 0.0f)
                    continue;

                int32 scaledMin = static_cast<int32>(std::lround(
                    static_cast<double>(damage.DamageMin) * multiplier));
                int32 scaledMax = static_cast<int32>(std::lround(
                    static_cast<double>(damage.DamageMax) * multiplier));

                std::ostringstream left;
                left << scaledMin << " - " << scaledMax << " Damage";

                std::ostringstream right;
                if (itemTemplate->Delay > 0)
                    right << "Speed " << std::fixed << std::setprecision(2)
                        << (static_cast<double>(itemTemplate->Delay) / 1000.0);

                AppendItemTooltipSnapshotRow(rows, left.str(), right.str(),
                    "replace-stat", "weapon-damage");
            }

            uint32 statCount =
                std::min<uint32>(itemTemplate->StatsCount, MAX_ITEM_PROTO_STATS);
            for (uint32 statIndex = 0; statIndex < statCount; ++statIndex)
            {
                _ItemStat const& stat = itemTemplate->ItemStat[statIndex];
                if (stat.ItemStatValue == 0)
                    continue;

                char const* label = GetItemStatLabel(stat.ItemStatType);
                if (!label)
                    continue;

                int32 scaledValue = static_cast<int32>(std::lround(
                    static_cast<double>(stat.ItemStatValue) * multiplier));
                std::string line = FormatSignedItemStat(scaledValue, label);
                if (!line.empty())
                    AppendItemTooltipSnapshotRow(rows, line, "",
                        "replace-stat", "stat");
            }

            AppendHeirloomPackageTooltipRows(rows, heirloomPackageState);

            EnchantmentSlot const socketEnchantSlots[MAX_GEM_SOCKETS] =
            {
                SOCK_ENCHANTMENT_SLOT,
                SOCK_ENCHANTMENT_SLOT_2,
                SOCK_ENCHANTMENT_SLOT_3,
            };

            for (uint32 socketIndex = 0;
                 socketIndex < MAX_ITEM_PROTO_SOCKETS; ++socketIndex)
            {
                _Socket const& socket = itemTemplate->Socket[socketIndex];
                if (socket.Color == 0)
                    continue;

                std::string right =
                    GetSocketGemName(item, socketEnchantSlots[socketIndex]);
                AppendItemTooltipSnapshotRow(rows,
                    GetSocketColorLabel(socket.Color), right,
                    "append-body",
                    right.empty() ? "socket-empty" : "socket-filled");
            }

            if (item->GetEnchantmentId(PRISMATIC_ENCHANTMENT_SLOT) != 0)
            {
                AppendItemTooltipSnapshotRow(rows, "Prismatic Socket", "",
                    "append-body", "socket-empty");
            }

            if (itemTemplate->socketBonus != 0)
            {
                SpellItemEnchantmentEntry const* socketBonus =
                    sSpellItemEnchantmentStore.LookupEntry(
                        itemTemplate->socketBonus);

                std::string socketBonusText = "Socket Bonus";
                if (socketBonus && socketBonus->description[0]
                    && *socketBonus->description[0])
                {
                    socketBonusText += ": ";
                    socketBonusText += socketBonus->description[0];
                }

                AppendItemTooltipSnapshotRow(rows, socketBonusText, "",
                    "append-body",
                    item->GemsFitSockets()
                        ? "socket-bonus-active"
                        : "socket-bonus-inactive");
            }

            if (itemTemplate->MaxDurability > 0)
            {
                uint32 currentDurability =
                    item->GetUInt32Value(ITEM_FIELD_DURABILITY);
                uint32 maxDurability =
                    item->GetUInt32Value(ITEM_FIELD_MAXDURABILITY);
                if (maxDurability == 0)
                    maxDurability = itemTemplate->MaxDurability;

                std::ostringstream durability;
                durability << "Durability " << currentDurability << " / "
                    << maxDurability;
                AppendItemTooltipSnapshotRow(rows, durability.str(), "",
                    "append-body",
                    item->IsBroken() ? "requirement-unmet" : "durability");
            }

            if (itemTemplate->RequiredLevel > 1)
            {
                AppendItemTooltipSnapshotRow(rows,
                    "Requires Level "
                        + std::to_string(itemTemplate->RequiredLevel),
                    "", "append-body",
                    (!player || player->GetLevel() >= itemTemplate->RequiredLevel)
                        ? "requirement"
                        : "requirement-unmet");
            }

            if (itemTemplate->RequiredSkill != 0
                && itemTemplate->RequiredSkillRank > 0)
            {
                std::ostringstream requirement;
                requirement << "Requires ";

                SkillLineEntry const* skill =
                    sSkillLineStore.LookupEntry(itemTemplate->RequiredSkill);
                if (skill && skill->name[0] && *skill->name[0])
                    requirement << skill->name[0];
                else
                    requirement << "Skill " << itemTemplate->RequiredSkill;

                requirement << " (" << itemTemplate->RequiredSkillRank << ')';
                AppendItemTooltipSnapshotRow(rows, requirement.str(), "",
                    "append-body",
                    (!player || player->GetSkillValue(itemTemplate->RequiredSkill)
                            >= itemTemplate->RequiredSkillRank)
                        ? "requirement"
                        : "requirement-unmet");
            }

            if (itemTemplate->RequiredSpell != 0)
            {
                std::string requiredSpell = "Requires Spell";
                SpellInfo const* spellInfo =
                    sSpellMgr->GetSpellInfo(itemTemplate->RequiredSpell);
                if (spellInfo && spellInfo->SpellName[0]
                    && *spellInfo->SpellName[0])
                {
                    requiredSpell += ": ";
                    requiredSpell += spellInfo->SpellName[0];
                }

                AppendItemTooltipSnapshotRow(rows, requiredSpell, "",
                    "append-body",
                    (!player || player->HasSpell(itemTemplate->RequiredSpell))
                        ? "requirement"
                        : "requirement-unmet");
            }

            if (itemTemplate->RequiredReputationFaction != 0)
            {
                std::ostringstream reputation;
                reputation << "Requires ";

                FactionEntry const* faction = sFactionStore.LookupEntry(
                    itemTemplate->RequiredReputationFaction);
                if (faction && faction->name[0] && *faction->name[0])
                    reputation << faction->name[0];
                else
                    reputation << "Faction "
                        << itemTemplate->RequiredReputationFaction;

                reputation << " - " << GetReputationRankLabel(
                    itemTemplate->RequiredReputationRank);
                AppendItemTooltipSnapshotRow(rows, reputation.str(), "",
                    "append-body",
                    (!player || uint32(player->GetReputationRank(
                            itemTemplate->RequiredReputationFaction))
                            >= itemTemplate->RequiredReputationRank)
                        ? "requirement"
                        : "requirement-unmet");
            }

            std::string allowableClassText;
            if (BuildAllowableClassText(itemTemplate->AllowableClass,
                allowableClassText))
            {
                bool const meetsClassRequirement = !player
                    || (itemTemplate->AllowableClass
                        & (1u << (player->getClass() - 1))) != 0;
                AppendItemTooltipSnapshotRow(rows, allowableClassText, "",
                    "append-body",
                    meetsClassRequirement
                        ? "requirement"
                        : "requirement-unmet");
            }

            std::string allowableRaceText;
            if (BuildAllowableRaceText(itemTemplate->AllowableRace,
                allowableRaceText))
            {
                bool const meetsRaceRequirement = !player
                    || (itemTemplate->AllowableRace
                        & (1u << (player->getRace() - 1))) != 0;
                AppendItemTooltipSnapshotRow(rows, allowableRaceText, "",
                    "append-body",
                    meetsRaceRequirement
                        ? "requirement"
                        : "requirement-unmet");
            }

            if (itemTemplate->ItemSet != 0)
            {
                ItemSetEntry const* itemSet =
                    sItemSetStore.LookupEntry(itemTemplate->ItemSet);
                if (itemSet)
                {
                    uint32 equippedPieces =
                        CountItemSetPiecesEquipped(player, itemTemplate->ItemSet);
                    uint32 totalPieces = CountItemSetPieces(itemSet);

                    std::string setName = "Item Set";
                    if (itemSet->name[0] && *itemSet->name[0])
                        setName = itemSet->name[0];

                    std::string setCount;
                    if (totalPieces > 0)
                    {
                        setCount = std::to_string(equippedPieces) + "/"
                            + std::to_string(totalPieces);
                    }

                    AppendItemTooltipSnapshotRow(rows, setName, setCount,
                        "append-body", "set-name");

                    for (uint32 setIndex = 0; setIndex < MAX_ITEM_SET_SPELLS;
                         ++setIndex)
                    {
                        uint32 spellId = itemSet->spells[setIndex];
                        uint32 threshold =
                            itemSet->items_to_triggerspell[setIndex];
                        if (spellId == 0 || threshold == 0)
                            continue;

                        std::string text = BuildItemSpellTooltipText(player,
                            int32(spellId), ITEM_SPELLTRIGGER_ON_EQUIP);
                        if (text.empty())
                            continue;

                        std::ostringstream bonus;
                        bonus << '(' << threshold << ") Set: " << text;
                        AppendItemTooltipSnapshotRow(rows, bonus.str(), "",
                            "append-body",
                            equippedPieces >= threshold
                                ? "set-bonus-active"
                                : "set-bonus-inactive");
                    }
                }
            }

            for (uint32 spellIndex = 0; spellIndex < MAX_ITEM_PROTO_SPELLS;
                 ++spellIndex)
            {
                _Spell const& itemSpell = itemTemplate->Spells[spellIndex];
                if (itemSpell.SpellId <= 0
                    || itemSpell.SpellTrigger >= MAX_ITEM_SPELLTRIGGER)
                {
                    continue;
                }

                std::string text = BuildItemSpellTooltipText(player,
                    itemSpell.SpellId, itemSpell.SpellTrigger);
                if (text.empty())
                    continue;

                char const* classification = "spell";
                switch (itemSpell.SpellTrigger)
                {
                    case ITEM_SPELLTRIGGER_ON_USE:
                    case ITEM_SPELLTRIGGER_ON_NO_DELAY_USE:
                    case ITEM_SPELLTRIGGER_SOULSTONE:
                        classification = "spell-use";
                        break;
                    case ITEM_SPELLTRIGGER_ON_EQUIP:
                        classification = "spell-equip";
                        break;
                    case ITEM_SPELLTRIGGER_CHANCE_ON_HIT:
                        classification = "spell-proc";
                        break;
                    case ITEM_SPELLTRIGGER_LEARN_SPELL_ID:
                        classification = "spell-learn";
                        break;
                    default:
                        break;
                }

                AppendItemTooltipSnapshotRow(rows, text, "", "append-body",
                    classification);
            }

            if (!itemTemplate->Description.empty())
            {
                AppendItemTooltipSnapshotRow(rows,
                    std::string("\"") + itemTemplate->Description + "\"",
                    "", "append-body", "description");
            }

            if (itemTemplate->SellPrice > 0)
            {
                AppendItemTooltipSnapshotRow(rows, "Sell Price",
                    FormatItemSellPrice(itemTemplate->SellPrice),
                    "append-body", "sell-price");
            }
        }

        if (displayMaxUpgrade > 0)
        {
            AppendItemTooltipSnapshotRow(rows, "Upgrade",
                std::to_string(displayUpgradeLevel) + "/"
                    + std::to_string(displayMaxUpgrade),
                "append-meta", "upgrade");
        }

        if (snapshot.stat_multiplier_basis_points > 10000)
        {
            AppendItemTooltipSnapshotRow(rows, "Bonus",
                FormatUpgradeBonusPercent(
                    snapshot.stat_multiplier_basis_points),
                "append-meta", "upgrade");
        }

        return rows;
    }

    static Player* ResolveItemTooltipSnapshotOwner(Player* player,
        ItemTooltipSnapshotNativeRequest const& request, uint32& outStatus)
    {
        if (!player)
        {
            outStatus = ItemTooltipSnapshotStatus::NOT_VISIBLE;
            return nullptr;
        }

        if (request.ownerGuidLow == 0
            || request.ownerGuidLow == player->GetGUID().GetCounter())
        {
            return player;
        }

        Player* owner = ObjectAccessor::FindConnectedPlayer(
            ObjectGuid::Create<HighGuid::Player>(request.ownerGuidLow));
        if (!owner)
        {
            outStatus = ItemTooltipSnapshotStatus::NOT_VISIBLE;
            return nullptr;
        }

        return owner;
    }

    static Item* ResolveItemTooltipSnapshotTradeItem(Player* player,
        ItemTooltipSnapshotNativeRequest const& request)
    {
        if (!player)
            return nullptr;

        TradeData* tradeData = player->GetTradeData();
        if (!tradeData)
            return nullptr;

        auto resolveFromTradeSide = [&](TradeData* sideData,
            uint32 ownerGuidLow) -> Item*
        {
            if (!sideData)
                return nullptr;

            if (request.ownerGuidLow != 0
                && request.ownerGuidLow != ownerGuidLow)
            {
                return nullptr;
            }

            if (request.itemGuidLow == 0)
                return nullptr;

            TradeSlots tradeSlot = sideData->GetTradeSlotForItem(
                ObjectGuid::Create<HighGuid::Item>(request.itemGuidLow));
            if (tradeSlot == TRADE_SLOT_INVALID)
                return nullptr;

            return sideData->GetItem(tradeSlot);
        };

        if (Item* item = resolveFromTradeSide(tradeData,
                player->GetGUID().GetCounter()))
        {
            return item;
        }

        Player* trader = tradeData->GetTrader();
        if (!trader)
            return nullptr;

        return resolveFromTradeSide(tradeData->GetTraderData(),
            trader->GetGUID().GetCounter());
    }

    static Item* ResolveItemTooltipSnapshotItemFromOwner(Player* owner,
        ItemTooltipSnapshotNativeRequest const& request)
    {
        if (!owner)
            return nullptr;

        if (request.itemGuidLow != 0)
        {
            if (Item* item = owner->GetItemByGuid(
                    ObjectGuid::Create<HighGuid::Item>(request.itemGuidLow)))
            {
                return item;
            }

            if (Item* mailItem = owner->GetMItem(request.itemGuidLow))
                return mailItem;
        }

        if (request.bag != 0 || request.slot != 0)
            return owner->GetItemByPos(request.bag, request.slot);

        return nullptr;
    }

    static Item* ResolveItemTooltipSnapshotItem(Player* player,
        ItemTooltipSnapshotNativeRequest const& request, uint32& outStatus)
    {
        outStatus = ItemTooltipSnapshotStatus::ITEM_NOT_FOUND;
        if (!player)
        {
            outStatus = ItemTooltipSnapshotStatus::NOT_VISIBLE;
            return nullptr;
        }

        if (request.contextKind > ItemTooltipSnapshotContextKind::LINK)
        {
            outStatus = ItemTooltipSnapshotStatus::UNSUPPORTED_CONTEXT;
            return nullptr;
        }

        if (Item* item = ResolveItemTooltipSnapshotTradeItem(player, request))
            return item;

        Player* owner = ResolveItemTooltipSnapshotOwner(player, request,
            outStatus);
        if (!owner)
            return nullptr;

        if (Item* item = ResolveItemTooltipSnapshotItemFromOwner(owner,
                request))
        {
            return item;
        }

        switch (request.contextKind)
        {
            case ItemTooltipSnapshotContextKind::BAG:
            case ItemTooltipSnapshotContextKind::EQUIPPED:
            case ItemTooltipSnapshotContextKind::COMPARE:
            case ItemTooltipSnapshotContextKind::INSPECT:
            case ItemTooltipSnapshotContextKind::TRADE:
            case ItemTooltipSnapshotContextKind::MAIL:
            case ItemTooltipSnapshotContextKind::LINK:
                outStatus = ItemTooltipSnapshotStatus::ITEM_NOT_FOUND;
                return nullptr;
            default:
                outStatus = ItemTooltipSnapshotStatus::UNSUPPORTED_CONTEXT;
                return nullptr;
        }
    }

    static void SendItemTooltipSnapshotNative(Player* player,
        ItemTooltipSnapshotNativeRequest const& request,
        DarkChaos::ItemUpgrade::ItemUpgradeTooltipSnapshot const* snapshot,
        std::vector<ItemTooltipSnapshotRow> const& rows,
        uint32 status, std::string const& error)
    {
        if (!player || !player->GetSession())
            return;

        uint32 responseItemGuid = snapshot ? snapshot->item_guid
            : request.itemGuidLow;
        uint32 responseRevision = snapshot ? snapshot->revision : 0;
        uint32 responseItemEntry = snapshot ? snapshot->item_entry
            : request.itemEntry;
        uint32 responseTierId = snapshot ? snapshot->tier_id : 0;
        uint32 responseUpgradeLevel = snapshot ? snapshot->upgrade_level : 0;
        uint32 responseMaxUpgrade = snapshot ? snapshot->max_upgrade : 0;
        uint32 responseMultiplier = snapshot
            ? snapshot->stat_multiplier_basis_points
            : 10000;
        uint32 responseBaseIlvl = snapshot ? snapshot->base_ilvl : 0;
        uint32 responseUpgradedIlvl = snapshot ? snapshot->upgraded_ilvl : 0;

        WorldPacket data(BridgeOpcode::SMSG_ITEM_TOOLTIP_SNAPSHOT,
            80 + error.size() + (rows.size() * 96));
        data << int32(request.requestId);
        data << int32(responseItemGuid);
        data << int32(responseRevision);
        data << int32(status);
        data << int32(responseItemEntry);
        data << int32(responseTierId);
        data << int32(responseUpgradeLevel);
        data << int32(responseMaxUpgrade);
        data << int32(responseMultiplier);
        data << int32(responseBaseIlvl);
        data << int32(responseUpgradedIlvl);
        data << int32(rows.size());
        for (ItemTooltipSnapshotRow const& row : rows)
        {
            data << row.left;
            data << row.right;
            data << row.kind;
            data << row.classification;
        }
        data << error;

        player->GetSession()->SendPacket(&data);
        std::string preview = "req=" + std::to_string(request.requestId)
            + "|guid=" + std::to_string(responseItemGuid)
            + "|rev=" + std::to_string(responseRevision)
            + "|status=" + std::to_string(status)
            + "|rows=" + std::to_string(rows.size());
        DCAddon::LogNativeS2CMessage(player, MODULE, Opcode::SMSG_ITEM_INFO,
            BridgeOpcode::SMSG_ITEM_TOOLTIP_SNAPSHOT, data.size(), preview,
            true, 0);
    }

    static void SendItemUpgradeInfoNative(Player* player, Item* item,
        uint8 bag, uint8 slot)
    {
        if (!player || !player->GetSession() || !item)
            return;

        DarkChaos::ItemUpgrade::ItemUpgradeTooltipSnapshot snapshot;
        if (DarkChaos::ItemUpgrade::UpgradeManager* mgr =
                DarkChaos::ItemUpgrade::GetUpgradeManager())
            mgr->BuildTooltipSnapshot(item, snapshot);

        WorldPacket data(BridgeOpcode::SMSG_ITEM_UPGRADE_TOOLTIP, 64);
        data << int32(bag);
        data << int32(slot);
        data << int32(snapshot.item_entry);
        data << int32(snapshot.tier_id);
        data << int32(snapshot.upgrade_level);
        data << int32(snapshot.max_upgrade);
        data << int32(snapshot.stat_multiplier_basis_points);
        data << int32(snapshot.base_ilvl);
        data << int32(snapshot.upgraded_ilvl);
        data << std::string();
        player->GetSession()->SendPacket(&data);
        std::string preview = "bag=" + std::to_string(bag)
            + "|slot=" + std::to_string(slot)
            + "|item=" + std::to_string(snapshot.item_entry)
            + "|tier=" + std::to_string(snapshot.tier_id)
            + "|upgrade=" + std::to_string(snapshot.upgrade_level)
            + "|max=" + std::to_string(snapshot.max_upgrade);
        DCAddon::LogNativeS2CMessage(player, MODULE, Opcode::SMSG_ITEM_INFO,
            BridgeOpcode::SMSG_ITEM_UPGRADE_TOOLTIP, data.size(), preview,
            true, 0);
    }

    static void SendNpcTooltipInfoNativeError(Player* player,
        std::string const& guidStr, std::string const& error)
    {
        if (!player || !player->GetSession())
            return;

        WorldPacket data(BridgeOpcode::SMSG_NPC_TOOLTIP_INFO,
            guidStr.size() + error.size() + 24);
        data << guidStr;
        data << int32(0);
        data << int32(0);
        data << int32(0);
        data << error;
        player->GetSession()->SendPacket(&data);
        std::string preview = "guid=" + guidStr + "|error=" + error;
        DCAddon::LogNativeS2CMessage(player, MODULE, Opcode::SMSG_NPC_INFO,
            BridgeOpcode::SMSG_NPC_TOOLTIP_INFO, data.size(), preview, true,
            0);
    }

    static void SendNpcTooltipInfoNative(Player* player,
        std::string const& guidStr)
    {
        if (!player || !player->GetSession())
            return;

        ObjectGuid guid;
        try
        {
            uint64 guidRaw = std::stoull(guidStr, nullptr, 16);
            guid = ObjectGuid(guidRaw);
        }
        catch (...)
        {
            SendNpcTooltipInfoNativeError(player, guidStr,
                "Invalid GUID format");
            return;
        }

        uint32 entry = guid.GetEntry();
        CreatureTemplate const* creatureTemplate =
            sObjectMgr->GetCreatureTemplate(entry);
        if (!creatureTemplate)
        {
            SendNpcTooltipInfoNativeError(player, guidStr,
                "Creature template not found");
            return;
        }

        uint32 spawnId = 0;
        CreatureData const* spawnData = ResolveNpcTooltipSpawnData(player,
            guid, entry, spawnId);
        uint32 dbGuid = 0;
        if (spawnData)
            dbGuid = spawnData->spawnId;
        else if (spawnId > 0)
            dbGuid = spawnId;

        WorldPacket data(BridgeOpcode::SMSG_NPC_TOOLTIP_INFO,
            guidStr.size() + 32);
        data << guidStr;
        data << int32(entry);
        data << int32(spawnId);
        data << int32(dbGuid);
        data << std::string();
        player->GetSession()->SendPacket(&data);
        std::string preview = "guid=" + guidStr
            + "|entry=" + std::to_string(entry)
            + "|spawn=" + std::to_string(spawnId)
            + "|dbGuid=" + std::to_string(dbGuid);
        DCAddon::LogNativeS2CMessage(player, MODULE, Opcode::SMSG_NPC_INFO,
            BridgeOpcode::SMSG_NPC_TOOLTIP_INFO, data.size(), preview, true,
            0);
    }

    static std::string NormalizeRelayDistribution(std::string distribution, bool isRaidGroup)
    {
        std::transform(distribution.begin(), distribution.end(), distribution.begin(),
            [](unsigned char c) { return std::toupper(c); });

        if (distribution == "RAID")
            return isRaidGroup ? "RAID" : "PARTY";

        if (distribution == "PARTY")
            return "PARTY";

        // AUTO / GROUP / unknown fallback follows client logic:
        // raid if in raid, otherwise party.
        return isRaidGroup ? "RAID" : "PARTY";
    }

    static bool CollectRelayRecipients(Player* sender,
                                       const std::string& requestedDistribution,
                                       std::string& resolvedDistribution,
                                       std::vector<Player*>& recipients,
                                       std::string& error)
    {
        if (!sender)
        {
            error = "Invalid relay sender.";
            return false;
        }

        Group* group = sender->GetGroup();
        if (!group)
        {
            error = "You are not in a party or raid.";
            return false;
        }

        bool isRaidGroup = group->isRaidGroup();
        resolvedDistribution = NormalizeRelayDistribution(requestedDistribution, isRaidGroup);
        bool sameSubGroupOnly = isRaidGroup && resolvedDistribution == "PARTY";
        uint8 senderSubGroup = group->GetMemberGroup(sender->GetGUID());

        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            Player* member = ref->GetSource();
            if (!member || !member->GetSession() || !member->IsInWorld())
                continue;

            if (member->GetGUID() == sender->GetGUID())
                continue;

            if (sameSubGroupOnly && group->GetMemberGroup(member->GetGUID()) != senderSubGroup)
                continue;

            recipients.push_back(member);
        }

        if (recipients.empty())
        {
            error = (resolvedDistribution == "RAID")
                ? "No other raid members available for relay."
                : "No other party members available for relay.";
            return false;
        }

        return true;
    }

    static bool SupportsNativePingRelayTransport(Player* player)
    {
        DCAddon::TransportPolicyRequest request;
        request.featureName = "ping-relay";
        request.nativeCapability =
            DCAddon::ProtocolVersion::Capability::PING_RELAY_NATIVE;
        return DCAddon::ResolveTransportPolicy(player, request).UsesNative();
    }

    static DCAddon::JsonValue BuildPingRelayStatePayload(Player* player,
        std::string requestedDistribution)
    {
        DCAddon::JsonValue payload;
        payload.SetObject();

        if (requestedDistribution.empty())
            requestedDistribution = "AUTO";

        std::transform(requestedDistribution.begin(),
            requestedDistribution.end(), requestedDistribution.begin(),
            [](unsigned char c) { return std::toupper(c); });

        if (requestedDistribution != "RAID"
            && requestedDistribution != "PARTY")
        {
            requestedDistribution = "AUTO";
        }

        payload.Set("requestedDistribution", requestedDistribution);

        if (!player)
        {
            payload.Set("canRelay", false);
            payload.Set("inGroup", false);
            payload.Set("inRaidGroup", false);
            payload.Set("recipientCount", static_cast<int32>(0));
            payload.Set("connectedMemberCount", static_cast<int32>(0));
            payload.Set("nativePingRelayTransport", false);
            payload.Set("nativeEnvelopeTransport", false);
            payload.Set("error", std::string("Invalid relay sender."));
            return payload;
        }

        payload.Set("nativePingRelayTransport",
            SupportsNativePingRelayTransport(player));
        payload.Set("nativeEnvelopeTransport",
            SupportsNativeEnvelopeTransport(player));

        Group* group = player->GetGroup();
        payload.Set("inGroup", group != nullptr);
        payload.Set("inRaidGroup", group && group->isRaidGroup());

        if (!group)
        {
            payload.Set("canRelay", false);
            payload.Set("recipientCount", static_cast<int32>(0));
            payload.Set("connectedMemberCount", static_cast<int32>(0));
            payload.Set("error",
                std::string("You are not in a party or raid."));
            return payload;
        }

        bool isRaidGroup = group->isRaidGroup();
        std::string resolvedDistribution = NormalizeRelayDistribution(
            requestedDistribution, isRaidGroup);
        bool sameSubGroupOnly = isRaidGroup
            && resolvedDistribution == "PARTY";
        uint8 senderSubGroup = group->GetMemberGroup(player->GetGUID());
        uint32 connectedMemberCount = 0;
        uint32 recipientCount = 0;

        payload.Set("resolvedDistribution", resolvedDistribution);
        payload.Set("subGroupScoped", sameSubGroupOnly);
        payload.Set("senderSubGroup", static_cast<int32>(senderSubGroup));

        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr;
             ref = ref->next())
        {
            Player* member = ref->GetSource();
            if (!member || !member->GetSession() || !member->IsInWorld())
                continue;

            ++connectedMemberCount;

            if (member->GetGUID() == player->GetGUID())
                continue;

            if (sameSubGroupOnly
                && group->GetMemberGroup(member->GetGUID())
                    != senderSubGroup)
            {
                continue;
            }

            ++recipientCount;
        }

        payload.Set("connectedMemberCount",
            static_cast<int32>(connectedMemberCount));
        payload.Set("recipientCount", static_cast<int32>(recipientCount));
        payload.Set("canRelay", recipientCount > 0);

        if (recipientCount == 0)
        {
            payload.Set("error", resolvedDistribution == "RAID"
                ? std::string("No other raid members available for relay.")
                : std::string("No other party members available for relay."));
        }

        return payload;
    }

    static void SendFeatureInvalidation(Player* player,
        std::string const& feature, std::string const& context)
    {
        if (!player)
            return;

        DCAddon::JsonValue payload;
        payload.SetObject();
        SendFeatureMessage(player, feature,
            NativeEnvelopeFeature::ACTION_INVALIDATE, payload, context);
    }

    static void ScheduleFeatureInvalidation(Player* player,
        std::string const& feature, std::string const& context,
        std::chrono::milliseconds delay = std::chrono::milliseconds(250))
    {
        if (!player)
            return;

        ObjectGuid guid = player->GetGUID();
        player->m_Events.AddEventAtOffset([guid, feature, context]
        {
            if (Player* online = ObjectAccessor::FindConnectedPlayer(guid))
                SendFeatureInvalidation(online, feature, context);
        }, delay);
    }

    static void ScheduleFeatureInvalidation(ObjectGuid guid,
        std::string const& feature, std::string const& context,
        std::chrono::milliseconds delay = std::chrono::milliseconds(250))
    {
        if (guid.IsEmpty())
            return;

        if (Player* player = ObjectAccessor::FindConnectedPlayer(guid))
            ScheduleFeatureInvalidation(player, feature, context, delay);
    }

    static void ScheduleFeatureInvalidationForGroup(Group* group,
        std::string const& feature, std::string const& context,
        std::chrono::milliseconds delay = std::chrono::milliseconds(250),
        ObjectGuid skipGuid = ObjectGuid::Empty)
    {
        if (!group)
            return;

        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr;
             ref = ref->next())
        {
            Player* member = ref->GetSource();
            if (!member || !member->GetSession() || !member->IsInWorld())
                continue;

            if (!skipGuid.IsEmpty() && member->GetGUID() == skipGuid)
                continue;

            ScheduleFeatureInvalidation(member, feature, context, delay);
        }
    }

    static void SchedulePingRelayStateInvalidation(Player* player,
        std::string const& context,
        std::chrono::milliseconds delay = std::chrono::milliseconds(250))
    {
        ScheduleFeatureInvalidation(player, NativeEnvelopeFeature::PING_STATE,
            context, delay);
    }

    static void SchedulePingRelayStateInvalidation(ObjectGuid guid,
        std::string const& context,
        std::chrono::milliseconds delay = std::chrono::milliseconds(250))
    {
        ScheduleFeatureInvalidation(guid, NativeEnvelopeFeature::PING_STATE,
            context, delay);
    }

    static void SchedulePingRelayStateInvalidationForGroup(Group* group,
        std::string const& context,
        std::chrono::milliseconds delay = std::chrono::milliseconds(250),
        ObjectGuid skipGuid = ObjectGuid::Empty)
    {
        ScheduleFeatureInvalidationForGroup(group,
            NativeEnvelopeFeature::PING_STATE, context, delay, skipGuid);
    }

    static void ScheduleRuntimeProfileStateInvalidation(Player* player,
        std::string const& context,
        std::chrono::milliseconds delay = std::chrono::milliseconds(250))
    {
        ScheduleFeatureInvalidation(player,
            NativeEnvelopeFeature::GRAPHICS_PROFILE_STATE, context, delay);
    }

    static void ScheduleRuntimeProfileStateInvalidation(ObjectGuid guid,
        std::string const& context,
        std::chrono::milliseconds delay = std::chrono::milliseconds(250))
    {
        ScheduleFeatureInvalidation(guid,
            NativeEnvelopeFeature::GRAPHICS_PROFILE_STATE, context, delay);
    }

    static void ScheduleRuntimeProfileStateInvalidationForGroup(Group* group,
        std::string const& context,
        std::chrono::milliseconds delay = std::chrono::milliseconds(250),
        ObjectGuid skipGuid = ObjectGuid::Empty)
    {
        ScheduleFeatureInvalidationForGroup(group,
            NativeEnvelopeFeature::GRAPHICS_PROFILE_STATE, context, delay,
            skipGuid);
    }

    static void SendNativePingRelayPayload(Player* player,
        std::string const& payload)
    {
        if (!player || !player->GetSession() || payload.empty())
            return;

        WorldPacket data(BridgeOpcode::SMSG_PING_RELAY,
            payload.size() + 1);
        data << payload;
        player->GetSession()->SendPacket(&data);
        std::string preview = "bytes=" + std::to_string(payload.size());
        DCAddon::LogNativeS2CMessage(player, MODULE, 0,
            BridgeOpcode::SMSG_PING_RELAY, data.size(), preview, true, 0);
    }

    static void SendPingRelayAck(Player* player, bool ok,
        std::string const& resolvedDistribution, uint32 recipients,
        std::string const& error)
    {
        if (!player)
            return;

        if (SupportsNativePingRelayTransport(player))
        {
            DCAddon::JsonValue payload;
            payload.SetObject();
            payload.Set("feature", std::string("ping_relay_ack"));
            payload.Set("action", std::string("relay_ack"));
            payload.Set("ok", ok);
            payload.Set("distribution", resolvedDistribution);
            payload.Set("recipients", recipients);
            if (!error.empty())
                payload.Set("error", error);

            SendNativePingRelayPayload(player, payload.Encode());
            return;
        }

        DCAddon::JsonMessage ack(MODULE, Opcode::SMSG_FEATURE_DATA);
        ack.Set("feature", "ping_relay_ack");
        ack.Set("action", "relay_ack");
        ack.Set("ok", ok);
        ack.Set("distribution", resolvedDistribution);
        ack.Set("recipients", recipients);
        if (!error.empty())
            ack.Set("error", error);
        ack.Send(player);
    }

    static void SendPingRelayFeatureResponse(Player* player, bool ok,
        std::string const& resolvedDistribution, uint32 recipients,
        std::string const& error)
    {
        if (!player)
            return;

        DCAddon::JsonValue payload;
        payload.SetObject();
        payload.Set("action",
            std::string(NativeEnvelopeFeature::ACTION_RELAY_ACK));
        payload.Set("ok", ok);
        payload.Set("distribution", resolvedDistribution);
        payload.Set("recipients", recipients);
        if (!error.empty())
            payload.Set("error", error);

        SendFeatureResponse(player, NativeEnvelopeFeature::PING, payload,
            "feature-request:relay_ack");
    }

    static void SendPingRelayMessage(Player* recipient, Player* sender,
        std::string const& resolvedDistribution,
        std::string const& payload)
    {
        if (!recipient || payload.empty())
            return;

        std::string source = sender ? sender->GetName() : "";
        uint32 sourceGuid = sender
            ? static_cast<uint32>(sender->GetGUID().GetCounter())
            : 0;
        uint32 timestamp = static_cast<uint32>(time(nullptr));

        if (SupportsNativePingRelayTransport(recipient))
        {
            DCAddon::JsonValue nativePayload;
            nativePayload.SetObject();
            nativePayload.Set("feature",
                std::string(NativeEnvelopeFeature::PING));
            nativePayload.Set("action",
                std::string(NativeEnvelopeFeature::ACTION_RELAY));
            nativePayload.Set("distribution", resolvedDistribution);
            nativePayload.Set("payload", payload);
            nativePayload.Set("syncPayload", payload);
            nativePayload.Set("source", source);
            nativePayload.Set("sourceGuid", sourceGuid);
            nativePayload.Set("timestamp", timestamp);

            SendNativePingRelayPayload(recipient, nativePayload.Encode());
            return;
        }

        DCAddon::JsonMessage relay(MODULE, Opcode::SMSG_FEATURE_DATA);
        relay.Set("feature", NativeEnvelopeFeature::PING);
        relay.Set("action", NativeEnvelopeFeature::ACTION_RELAY);
        relay.Set("distribution", resolvedDistribution);
        relay.Set("payload", payload);
        relay.Set("syncPayload", payload);
        relay.Set("source", source);
        relay.Set("sourceGuid", sourceGuid);
        relay.Set("timestamp", timestamp);
        relay.Send(recipient);
    }

    static void RelayPingPayload(Player* player,
        std::string const& requestedDistribution,
        std::string const& payload,
        bool useFeatureResponseAck = false)
    {
        if (!player)
            return;

        auto sendAck = [player, useFeatureResponseAck](bool ok,
            std::string const& resolvedDistribution, uint32 recipients,
            std::string const& error)
        {
            if (useFeatureResponseAck)
            {
                SendPingRelayFeatureResponse(player, ok,
                    resolvedDistribution, recipients, error);
                return;
            }

            SendPingRelayAck(player, ok, resolvedDistribution,
                recipients, error);
        };

        if (payload.empty())
        {
            sendAck(false, "", 0,
                "Missing ping relay payload.");
            return;
        }

        std::string resolvedDistribution;
        std::vector<Player*> recipients;
        std::string relayError;

        if (!CollectRelayRecipients(player, requestedDistribution,
                resolvedDistribution, recipients, relayError))
        {
            sendAck(false, resolvedDistribution, 0,
                relayError);
            return;
        }

        for (Player* recipient : recipients)
            SendPingRelayMessage(recipient, player, resolvedDistribution,
                payload);

        sendAck(true, resolvedDistribution,
            static_cast<uint32>(recipients.size()), "");
    }

    // =======================================================================
    // Settings Database Functions
    // =======================================================================

    static void ApplyPlayerSetting(QoSSettings& settings,
                                   std::string const& key,
                                   std::string const& value)
    {
        if (key == "tooltips.enabled") settings.tooltipsEnabled = (value == "1");
        else if (key == "tooltips.showItemId") settings.showItemId = (value == "1");
        else if (key == "tooltips.showItemLevel") settings.showItemLevel = (value == "1");
        else if (key == "tooltips.showNpcId") settings.showNpcId = (value == "1");
        else if (key == "tooltips.showSpellId") settings.showSpellId = (value == "1");
        else if (key == "tooltips.showSpellFamilyMetadata") settings.showSpellFamilyMetadata = (value == "1");
        else if (key == "tooltips.showGuildRank") settings.showGuildRank = (value == "1");
        else if (key == "tooltips.showTarget") settings.showTarget = (value == "1");
        else if (key == "tooltips.hideHealthBar") settings.hideHealthBar = (value == "1");
        else if (key == "tooltips.hideInCombat") settings.hideInCombat = (value == "1");
        else if (key == "tooltips.scale")
        {
            try
            {
                settings.tooltipScale = std::stof(value);
            }
            catch (...)
            {
            }
        }
        else if (key == "automation.enabled") settings.automationEnabled = (value == "1");
        else if (key == "automation.autoRepair") settings.autoRepair = (value == "1");
        else if (key == "automation.autoRepairGuild") settings.autoRepairGuild = (value == "1");
        else if (key == "automation.autoSellJunk") settings.autoSellJunk = (value == "1");
        else if (key == "automation.autoDismount") settings.autoDismount = (value == "1");
        else if (key == "automation.autoAcceptSummon") settings.autoAcceptSummon = (value == "1");
        else if (key == "automation.autoAcceptResurrect") settings.autoAcceptResurrect = (value == "1");
        else if (key == "automation.autoDeclineDuels") settings.autoDeclineDuels = (value == "1");
        else if (key == "automation.autoAcceptQuests") settings.autoAcceptQuests = (value == "1");
        else if (key == "automation.autoTurnInQuests") settings.autoTurnInQuests = (value == "1");
        else if (key == "chat.enabled") settings.chatEnabled = (value == "1");
        else if (key == "chat.hideChannelNames") settings.hideChannelNames = (value == "1");
        else if (key == "chat.stickyChannels") settings.stickyChannels = (value == "1");
        else if (key == "interface.enabled") settings.interfaceEnabled = (value == "1");
        else if (key == "interface.combatPlates") settings.combatPlates = (value == "1");
        else if (key == "interface.questLevelText") settings.questLevelText = (value == "1");
    }

    QoSSettings LoadPlayerSettingsFromDb(Player* player)
    {
        QoSSettings settings;

        if (!player)
            return settings;

        QueryResult result = CharacterDatabase.Query(
            "SELECT setting_key, setting_value FROM dc_player_qos_settings WHERE guid = {}",
            player->GetGUID().GetCounter()
        );

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                std::string key = fields[0].Get<std::string>();
                std::string value = fields[1].Get<std::string>();

                ApplyPlayerSetting(settings, key, value);
            } while (result->NextRow());
        }

        return settings;
    }

    QoSSettings GetPlayerSettingsCached(Player* player)
    {
        QoSSettings settings;

        if (!player)
            return settings;

        uint32 guid = player->GetGUID().GetCounter();

        {
            std::lock_guard<std::mutex> lock(s_PlayerSettingsCacheMutex);
            auto itr = s_PlayerSettingsCache.find(guid);
            if (itr != s_PlayerSettingsCache.end())
                return itr->second;
        }

        settings = LoadPlayerSettingsFromDb(player);

        std::lock_guard<std::mutex> lock(s_PlayerSettingsCacheMutex);
        s_PlayerSettingsCache[guid] = settings;
        return settings;
    }

    void InvalidatePlayerSettingsCache(uint32 guid)
    {
        if (!guid)
            return;

        std::lock_guard<std::mutex> lock(s_PlayerSettingsCacheMutex);
        s_PlayerSettingsCache.erase(guid);
    }

    void SavePlayerSetting(Player* player, const std::string& key, const std::string& value)
    {
        if (!player)
            return;

        std::string escapedKey = key;
        std::string escapedValue = value;
        CharacterDatabase.EscapeString(escapedKey);
        CharacterDatabase.EscapeString(escapedValue);

        CharacterDatabase.Execute(
            "INSERT INTO dc_player_qos_settings (guid, setting_key, setting_value) "
            "VALUES ({}, '{}', '{}') "
            "ON DUPLICATE KEY UPDATE setting_value = '{}'",
            player->GetGUID().GetCounter(),
            escapedKey,
            escapedValue,
            escapedValue
        );

        InvalidatePlayerSettingsCache(player->GetGUID().GetCounter());
    }

    // =======================================================================
    // Send Functions
    // =======================================================================

    void SendSettingsSync(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        QoSSettings settings = GetPlayerSettingsCached(player);

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_SETTINGS_SYNC);

        // Tooltip settings
        msg.Set("tooltipsEnabled", settings.tooltipsEnabled);
        msg.Set("showItemId", settings.showItemId);
        msg.Set("showItemLevel", settings.showItemLevel);
        msg.Set("showNpcId", settings.showNpcId);
        msg.Set("showSpellId", settings.showSpellId);
        msg.Set("showSpellFamilyMetadata", settings.showSpellFamilyMetadata);
        msg.Set("showGuildRank", settings.showGuildRank);
        msg.Set("showTarget", settings.showTarget);
        msg.Set("hideHealthBar", settings.hideHealthBar);
        msg.Set("hideInCombat", settings.hideInCombat);
        msg.Set("tooltipScale", settings.tooltipScale);

        // Automation settings
        msg.Set("automationEnabled", settings.automationEnabled);
        msg.Set("autoRepair", settings.autoRepair);
        msg.Set("autoRepairGuild", settings.autoRepairGuild);
        msg.Set("autoSellJunk", settings.autoSellJunk);
        msg.Set("autoDismount", settings.autoDismount);
        msg.Set("autoAcceptSummon", settings.autoAcceptSummon);
        msg.Set("autoAcceptResurrect", settings.autoAcceptResurrect);
        msg.Set("autoDeclineDuels", settings.autoDeclineDuels);
        msg.Set("autoAcceptQuests", settings.autoAcceptQuests);
        msg.Set("autoTurnInQuests", settings.autoTurnInQuests);

        // Chat settings
        msg.Set("chatEnabled", settings.chatEnabled);
        msg.Set("hideChannelNames", settings.hideChannelNames);
        msg.Set("stickyChannels", settings.stickyChannels);

        // Interface settings
        msg.Set("interfaceEnabled", settings.interfaceEnabled);
        msg.Set("combatPlates", settings.combatPlates);
        msg.Set("questLevelText", settings.questLevelText);

        msg.Send(player);
    }

    void SendItemInfo(Player* player, uint32 itemId)
    {
        if (!player || !player->GetSession())
            return;

        const ItemTemplate* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
        if (!itemTemplate)
        {
            // Item not found - send error
            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_ITEM_INFO);
            msg.Set("itemId", itemId);
            msg.Set("error", "Item not found");
            msg.Send(player);
            return;
        }

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_ITEM_INFO);
        msg.Set("itemId", itemId);
        msg.Set("name", itemTemplate->Name1);
        msg.Set("quality", itemTemplate->Quality);
        msg.Set("itemLevel", itemTemplate->ItemLevel);
        msg.Set("requiredLevel", itemTemplate->RequiredLevel);
        msg.Set("class", itemTemplate->Class);
        msg.Set("subclass", itemTemplate->SubClass);
        msg.Set("inventoryType", itemTemplate->InventoryType);
        msg.Set("maxStack", itemTemplate->GetMaxStackSize());
        msg.Set("sellPrice", itemTemplate->SellPrice);
        msg.Set("buyPrice", itemTemplate->BuyPrice);

        // Check for custom item data
        QueryResult customResult = WorldDatabase.Query(
            "SELECT custom_note, custom_source, is_custom FROM dc_item_custom_data WHERE item_id = {}",
            itemId
        );

        if (customResult)
        {
            Field* fields = customResult->Fetch();
            msg.Set("customNote", fields[0].Get<std::string>());
            msg.Set("customSource", fields[1].Get<std::string>());
            msg.Set("isCustom", fields[2].Get<bool>());
        }

        msg.Send(player);
    }

    // Send item upgrade/tier information for tooltip display
    void SendItemUpgradeInfo(Player* player, Item* item, uint8 bag, uint8 slot)
    {
        if (!player || !player->GetSession() || !item)
            return;

        ObjectGuid itemGuid = item->GetGUID();
        DarkChaos::ItemUpgrade::ItemUpgradeTooltipSnapshot snapshot;
        if (DarkChaos::ItemUpgrade::UpgradeManager* mgr =
                DarkChaos::ItemUpgrade::GetUpgradeManager())
            mgr->BuildTooltipSnapshot(item, snapshot);

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_ITEM_INFO);
        msg.Set("bag", static_cast<int32>(bag));
        msg.Set("slot", static_cast<int32>(slot));
        msg.Set("itemId", static_cast<int32>(snapshot.item_entry));
        msg.Set("guid", itemGuid.GetCounter());

        if (snapshot.has_persisted_state)
        {
            msg.Set("tier", static_cast<int32>(snapshot.tier_id));
            msg.Set("upgradeLevel", static_cast<int32>(snapshot.upgrade_level));
            msg.Set("maxUpgrade", static_cast<int32>(snapshot.max_upgrade));
            msg.Set("statMultiplier",
                static_cast<double>(snapshot.stat_multiplier_basis_points) /
                    10000.0);

            if (snapshot.base_ilvl > 0)
            {
                msg.Set("baseIlvl", static_cast<int32>(snapshot.base_ilvl));
                msg.Set("upgradedIlvl",
                    static_cast<int32>(snapshot.upgraded_ilvl));
            }
        }
        else
        {
            // No upgrade data - check if item is upgradeable
            msg.Set("upgradeLevel", 0);
            msg.Set("tier", 0);
            msg.Set("maxUpgrade", static_cast<int32>(snapshot.max_upgrade));
            msg.Set("statMultiplier", 1.0f);
        }

        msg.Send(player);
    }

    static CreatureData const* FindCachedCreatureSpawnData(uint32 entry)
    {
        for (auto const& pair : sObjectMgr->GetAllCreatureData())
        {
            CreatureData const& creatureData = pair.second;
            if (creatureData.id1 == entry || creatureData.id2 == entry || creatureData.id3 == entry)
                return &creatureData;
        }

        return nullptr;
    }

    static CreatureData const* ResolveNpcTooltipSpawnData(Player* player,
        ObjectGuid const& guid,
        uint32 entry,
        uint32& spawnId)
    {
        if (player && guid.IsCreatureOrVehicle())
        {
            if (Creature* creature = ObjectAccessor::GetCreature(*player, guid))
            {
                spawnId = creature->GetSpawnId();

                if (CreatureData const* creatureData = creature->GetCreatureData())
                    return creatureData;

                if (spawnId > 0)
                {
                    if (CreatureData const* creatureData = sObjectMgr->GetCreatureData(spawnId))
                        return creatureData;
                }
            }
        }

        if (CreatureData const* creatureData = FindCachedCreatureSpawnData(entry))
        {
            if (spawnId == 0)
                spawnId = creatureData->spawnId;

            return creatureData;
        }

        return nullptr;
    }

    void SendNpcInfo(Player* player, const std::string& guidStr)
    {
        if (!player || !player->GetSession())
            return;

        // Parse GUID from the string
        // Format in WoW 3.3.5a is typically like: 0xF13000XXXXXX0000
        ObjectGuid guid;
        try
        {
            // Extract NPC entry ID from GUID (simplified parsing)
            // The actual GUID parsing may vary based on your implementation
            uint64 guidRaw = std::stoull(guidStr, nullptr, 16);
            guid = ObjectGuid(guidRaw);
        }
        catch (...)
        {
            // Invalid GUID format
            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_NPC_INFO);
            msg.Set("guid", guidStr);
            msg.Set("error", "Invalid GUID format");
            msg.Send(player);
            return;
        }

        uint32 entry = guid.GetEntry();

        const CreatureTemplate* creatureTemplate = sObjectMgr->GetCreatureTemplate(entry);
        if (!creatureTemplate)
        {
            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_NPC_INFO);
            msg.Set("guid", guidStr);
            msg.Set("error", "Creature template not found");
            msg.Send(player);
            return;
        }

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_NPC_INFO);
        msg.Set("guid", guidStr);
        msg.Set("entry", entry);
        msg.Set("name", creatureTemplate->Name);
        msg.Set("subname", creatureTemplate->SubName);
        msg.Set("minLevel", creatureTemplate->minlevel);
        msg.Set("maxLevel", creatureTemplate->maxlevel);
        msg.Set("rank", creatureTemplate->rank);
        msg.Set("faction", creatureTemplate->faction);
        msg.Set("npcFlags", creatureTemplate->npcflag);
        msg.Set("unitClass", creatureTemplate->unit_class);
        msg.Set("type", creatureTemplate->type);
        uint32 spawnId = 0;
        CreatureData const* spawnData = ResolveNpcTooltipSpawnData(player, guid, entry, spawnId);

        // Include spawn ID if available (used by DC-Welcome addon for tooltips)
        if (spawnId > 0)
            msg.Set("spawnId", static_cast<int32>(spawnId));

        if (spawnData)
        {
            msg.Set("dbGuid", static_cast<int32>(spawnData->spawnId));
            msg.Set("spawnGuid", static_cast<int32>(spawnData->spawnId));
            msg.Set("mapId", static_cast<int32>(spawnData->mapid));
            msg.Set("spawnX", spawnData->posX);
            msg.Set("spawnY", spawnData->posY);
            msg.Set("spawnZ", spawnData->posZ);
            msg.Set("spawnTime", static_cast<int32>(spawnData->spawntimesecs));
        }

        msg.Send(player);
    }

    void SendSpellInfo(Player* player, uint32 spellId)
    {
        if (!player || !player->GetSession())
            return;

        const SpellInfo* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
        {
            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_SPELL_INFO);
            msg.Set("spellId", spellId);
            msg.Set("error", "Spell not found");
            msg.Send(player);
            return;
        }

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_SPELL_INFO);
        msg.Set("spellId", spellId);
        msg.Set("name", spellInfo->SpellName[0]);  // Assuming index 0 for English
        msg.Set("rank", spellInfo->Rank[0]);
        msg.Set("school", spellInfo->SchoolMask);
        msg.Set("powerType", spellInfo->PowerType);
        msg.Set("castTime", spellInfo->CastTimeEntry ? spellInfo->CastTimeEntry->CastTime : 0);
        msg.Set("cooldown", spellInfo->RecoveryTime);
        msg.Set("category", spellInfo->GetCategory());

        // Check for custom spell modifications
        QueryResult customResult = WorldDatabase.Query(
            "SELECT custom_note, modified_values FROM dc_spell_custom_data WHERE spell_id = {}",
            spellId
        );

        if (customResult)
        {
            Field* fields = customResult->Fetch();
            msg.Set("customNote", fields[0].Get<std::string>());
            msg.Set("modifiedValues", fields[1].Get<std::string>());
        }

        msg.Send(player);
    }

    static std::string FormatSpellSeconds(uint32 milliseconds)
    {
        std::ostringstream out;
        out << std::fixed << std::setprecision((milliseconds % 1000) != 0 ? 1 : 0)
            << (static_cast<double>(milliseconds) / 1000.0)
            << " sec";
        return out.str();
    }

    static std::string GetPowerTypeLabel(uint32 powerType)
    {
        switch (powerType)
        {
            case POWER_MANA: return "Mana";
            case POWER_RAGE: return "Rage";
            case POWER_FOCUS: return "Focus";
            case POWER_ENERGY: return "Energy";
            case POWER_HAPPINESS: return "Happiness";
            case POWER_RUNE: return "Rune";
            case POWER_RUNIC_POWER: return "Runic Power";
            case POWER_HEALTH: return "Health";
            default: return "Power";
        }
    }

    // Inline color for dynamic values in description bodies. The Lua tooltip
    // renderer honors |c escapes; the DLL/engine path flattens them to the
    // line color, so this is safe on both transports. The hex must avoid
    // decimal digits ("ffffff" qualifies) so the $l singular/plural detector
    // (ExtractLastTemplateQuantity) never matches digits inside the escape.
    static std::string ColorizeTooltipValue(std::string const& value)
    {
        if (value.empty()
            || !sConfigMgr->GetOption<bool>("DC.QoS.TooltipEnrichment.ColorValues", true))
            return value;

        return "|cffffffff" + value + "|r";
    }

    // "1 Blood, 1 Unholy" for Death Knight spells (flat power cost is 0).
    static std::string BuildRuneCostText(SpellInfo const* spellInfo)
    {
        if (!spellInfo || !spellInfo->RuneCostID)
            return "";

        SpellRuneCostEntry const* runeCost =
            sSpellRuneCostStore.LookupEntry(spellInfo->RuneCostID);
        if (!runeCost || runeCost->NoRuneCost())
            return "";

        static char const* runeNames[3] = { "Blood", "Frost", "Unholy" };
        std::string text;
        for (uint8 i = 0; i < 3; ++i)
        {
            if (!runeCost->RuneCost[i])
                continue;

            if (!text.empty())
                text += ", ";
            text += std::to_string(runeCost->RuneCost[i]);
            text += " ";
            text += runeNames[i];
        }

        return text;
    }

    // "Ankh" / "Wild Berries (2), Ankh" -- mirrors the native reagents line
    // the rebuilt hyperlink tooltip bodies lose.
    static std::string BuildReagentsText(SpellInfo const* spellInfo)
    {
        if (!spellInfo)
            return "";

        std::string text;
        for (uint8 i = 0; i < MAX_SPELL_REAGENTS; ++i)
        {
            if (spellInfo->Reagent[i] <= 0 || !spellInfo->ReagentCount[i])
                continue;

            ItemTemplate const* proto = sObjectMgr->GetItemTemplate(
                static_cast<uint32>(spellInfo->Reagent[i]));
            if (!proto)
                continue;

            if (!text.empty())
                text += ", ";
            text += proto->Name1;
            if (spellInfo->ReagentCount[i] > 1)
                text += " (" + std::to_string(spellInfo->ReagentCount[i]) + ")";
        }

        return text;
    }

    // "Requires Battle Stance" from the Stances mask.
    static std::string BuildRequiredFormText(SpellInfo const* spellInfo)
    {
        if (!spellInfo || !spellInfo->Stances)
            return "";

        struct FormName
        {
            uint32 form;
            char const* name;
        };
        static FormName const formNames[] =
        {
            { FORM_CAT, "Cat Form" },
            { FORM_TREE, "Tree of Life" },
            { FORM_TRAVEL, "Travel Form" },
            { FORM_AQUA, "Aquatic Form" },
            { FORM_BEAR, "Bear Form" },
            { FORM_DIREBEAR, "Dire Bear Form" },
            { FORM_GHOSTWOLF, "Ghost Wolf" },
            { FORM_BATTLESTANCE, "Battle Stance" },
            { FORM_DEFENSIVESTANCE, "Defensive Stance" },
            { FORM_BERSERKERSTANCE, "Berserker Stance" },
            { FORM_METAMORPHOSIS, "Metamorphosis" },
            { FORM_FLIGHT_EPIC, "Swift Flight Form" },
            { FORM_SHADOW, "Shadowform" },
            { FORM_FLIGHT, "Flight Form" },
            { FORM_STEALTH, "Stealth" },
            { FORM_MOONKIN, "Moonkin Form" },
        };

        std::string text;
        for (FormName const& entry : formNames)
        {
            if (!(spellInfo->Stances & (1u << (entry.form - 1))))
                continue;

            if (!text.empty())
                text += ", ";
            text += entry.name;
        }

        if (text.empty())
            return "";
        return "Requires " + text;
    }

    // "Requires Daggers" / "Requires Shields" from the equipped-item rules.
    static std::string BuildRequiredEquipText(SpellInfo const* spellInfo)
    {
        if (!spellInfo)
            return "";

        if (spellInfo->EquippedItemClass == ITEM_CLASS_ARMOR)
        {
            if (spellInfo->EquippedItemSubClassMask
                & (1 << ITEM_SUBCLASS_ARMOR_SHIELD))
                return "Requires Shields";
            return "";
        }

        if (spellInfo->EquippedItemClass != ITEM_CLASS_WEAPON
            || spellInfo->EquippedItemSubClassMask <= 0)
            return "";

        static char const* weaponNames[MAX_ITEM_SUBCLASS_WEAPON] =
        {
            "Axes", "Two-Handed Axes", "Bows", "Guns", "Maces",
            "Two-Handed Maces", "Polearms", "Swords", "Two-Handed Swords",
            nullptr, "Staves", nullptr, nullptr, "Fist Weapons", nullptr,
            "Daggers", "Thrown", "Spears", "Crossbows", "Wands",
            "Fishing Poles"
        };

        std::string text;
        uint32 named = 0;
        for (uint8 i = 0; i < MAX_ITEM_SUBCLASS_WEAPON; ++i)
        {
            if (!(spellInfo->EquippedItemSubClassMask & (1 << i))
                || !weaponNames[i])
                continue;

            if (!text.empty())
                text += ", ";
            text += weaponNames[i];
            ++named;
        }

        if (!named)
            return "";

        // Broad masks (e.g. "any melee weapon") would produce a wall of
        // names; summarize instead.
        if (named > 4)
            return "Requires Melee Weapon";
        return "Requires " + text;
    }

    static void PushTooltipLine(DCAddon::JsonValue& lines,
                                std::string const& left,
                                std::string const& right = "",
                                double r = 0.8,
                                double g = 0.8,
                                double b = 0.8,
                                std::string const& kind = "")
    {
        DCAddon::JsonValue entry;
        entry.SetObject();
        entry.Set("left", left);
        if (!right.empty())
            entry.Set("right", right);
        entry.Set("r", r);
        entry.Set("g", g);
        entry.Set("b", b);
        if (!kind.empty())
            entry.Set("kind", kind);
        lines.Push(entry);
    }

    static std::vector<std::string> WrapTooltipText(std::string const& text, std::size_t maxWidth)
    {
        std::vector<std::string> wrapped;
        if (text.empty() || maxWidth < 8)
        {
            wrapped.push_back(text);
            return wrapped;
        }

        std::string remaining = text;
        while (remaining.size() > maxWidth)
        {
            std::size_t split = remaining.rfind(' ', maxWidth);
            if (split == std::string::npos || split < maxWidth / 2)
                split = maxWidth;

            wrapped.push_back(remaining.substr(0, split));

            if (split < remaining.size() && remaining[split] == ' ')
                ++split;
            remaining.erase(0, split);
        }

        if (!remaining.empty())
            wrapped.push_back(remaining);

        if (wrapped.empty())
            wrapped.push_back(text);

        return wrapped;
    }

    static void PushWrappedTooltipLine(DCAddon::JsonValue& lines,
                                       std::string const& left,
                                       double r,
                                       double g,
                                       double b,
                                       std::string const& kind,
                                       std::size_t maxWidth = 92)
    {
        for (std::string const& chunk : WrapTooltipText(left, maxWidth))
            PushTooltipLine(lines, chunk, "", r, g, b, kind);
    }

    static std::string GetSpellFamilyLabel(uint32 family)
    {
        switch (family)
        {
            case SPELLFAMILY_GENERIC: return "Generic";
            case SPELLFAMILY_UNK1: return "Event/Holiday";
            case SPELLFAMILY_MAGE: return "Mage";
            case SPELLFAMILY_WARRIOR: return "Warrior";
            case SPELLFAMILY_WARLOCK: return "Warlock";
            case SPELLFAMILY_PRIEST: return "Priest";
            case SPELLFAMILY_DRUID: return "Druid";
            case SPELLFAMILY_ROGUE: return "Rogue";
            case SPELLFAMILY_HUNTER: return "Hunter";
            case SPELLFAMILY_PALADIN: return "Paladin";
            case SPELLFAMILY_SHAMAN: return "Shaman";
            case SPELLFAMILY_UNK2: return "Unknown-12";
            case SPELLFAMILY_POTION: return "Potion";
            case SPELLFAMILY_DEATHKNIGHT: return "Death Knight";
            case SPELLFAMILY_PET: return "Pet";
            default: return "Unknown";
        }
    }

    static std::string FormatSpellFamilyInfo(SpellInfo const* spellInfo)
    {
        if (!spellInfo)
            return "";

        std::ostringstream out;
        out << "Spell Family: " << GetSpellFamilyLabel(spellInfo->SpellFamilyName)
            << " (" << spellInfo->SpellFamilyName << ")"
            << " | Flags "
            << "0x" << std::hex << std::uppercase << std::setw(8) << std::setfill('0') << spellInfo->SpellFamilyFlags[0]
            << ":0x" << std::hex << std::uppercase << std::setw(8) << std::setfill('0') << spellInfo->SpellFamilyFlags[1]
            << ":0x" << std::hex << std::uppercase << std::setw(8) << std::setfill('0') << spellInfo->SpellFamilyFlags[2];
        return out.str();
    }

    static std::unordered_map<uint32, std::string> sSpellTemplateCache;

    static std::string GetSpellDescriptionTemplate(uint32 spellId)
    {
        auto itr = sSpellTemplateCache.find(spellId);
        if (itr != sSpellTemplateCache.end())
            return itr->second;

        std::string description;
        SpellEntry const* spellEntry = sSpellStore.LookupEntry(spellId);
        if (spellEntry)
        {
            if (spellEntry->Description[0] && *spellEntry->Description[0])
                description = spellEntry->Description[0];

            if (description.empty() && spellEntry->ToolTip[0] && *spellEntry->ToolTip[0])
                description = spellEntry->ToolTip[0];
        }

        sSpellTemplateCache[spellId] = description;
        return description;
    }

    struct TooltipAmountRange
    {
        int32 Min = 0;
        int32 Max = 0;

        bool IsValid() const
        {
            return Min != 0 || Max != 0;
        }
    };

    static uint32 GetTooltipTickCount(SpellInfo const* spellInfo, SpellEffectInfo const& effect);

    static int32 GetTooltipBasePoints(Player* player,
                                      SpellInfo const* spellInfo,
                                      SpellEffectInfo const& effect)
    {
        if (!spellInfo)
            return effect.BasePoints;

        int32 basePoints = effect.BasePoints;

        if (player && effect.RealPointsPerLevel != 0.0f)
        {
            int32 level = int32(player->GetLevel());
            if (level > int32(spellInfo->MaxLevel) && spellInfo->MaxLevel > 0)
                level = int32(spellInfo->MaxLevel);
            else if (level < int32(spellInfo->BaseLevel))
                level = int32(spellInfo->BaseLevel);

            level -= int32(std::max(spellInfo->BaseLevel, spellInfo->SpellLevel));
            basePoints += int32(level * effect.RealPointsPerLevel);
        }

        return basePoints;
    }

    static TooltipAmountRange GetTooltipAmountRange(Player* player,
                                                    SpellInfo const* spellInfo,
                                                    SpellEffectInfo const& effect)
    {
        TooltipAmountRange range;
        int32 basePoints = GetTooltipBasePoints(player, spellInfo, effect);
        int32 dieSides = effect.DieSides;

        range.Min = basePoints;
        range.Max = basePoints;

        if (dieSides == 1)
        {
            range.Min += 1;
            range.Max += 1;
        }
        else if (dieSides > 1)
        {
            range.Min += 1;
            range.Max += dieSides;
        }
        else if (dieSides < 0)
        {
            range.Min += dieSides;
            range.Max += 1;
        }

        if (range.Min > range.Max)
            std::swap(range.Min, range.Max);

        return range;
    }

    static TooltipAmountRange ApplyDamageBonusToRange(Player* player,
                                                      SpellInfo const* spellInfo,
                                                      SpellEffectInfo const& effect,
                                                      TooltipAmountRange range,
                                                      DamageEffectType damageType)
    {
        if (!player || !spellInfo || !range.IsValid())
            return range;

        auto applySingle = [player, spellInfo, &effect, damageType](int32 value) -> int32
        {
            if (value <= 0)
                return value;

            return int32(player->SpellDamageBonusDone(player,
                spellInfo,
                uint32(value),
                damageType,
                effect.EffectIndex));
        };

        range.Min = applySingle(range.Min);
        range.Max = applySingle(range.Max);
        if (range.Min > range.Max)
            std::swap(range.Min, range.Max);
        return range;
    }

    static TooltipAmountRange ApplyHealingBonusToRange(Player* player,
                                                       SpellInfo const* spellInfo,
                                                       SpellEffectInfo const& effect,
                                                       TooltipAmountRange range,
                                                       DamageEffectType damageType)
    {
        if (!player || !spellInfo || !range.IsValid())
            return range;

        auto applySingle = [player, spellInfo, &effect, damageType](int32 value) -> int32
        {
            if (value <= 0)
                return value;

            return int32(player->SpellHealingBonusDone(player,
                spellInfo,
                uint32(value),
                damageType,
                effect.EffectIndex));
        };

        range.Min = applySingle(range.Min);
        range.Max = applySingle(range.Max);
        if (range.Min > range.Max)
            std::swap(range.Min, range.Max);
        return range;
    }

    static std::string FormatSignedAmountRange(TooltipAmountRange const& range, bool absolute = false)
    {
        int32 minValue = absolute ? std::abs(range.Min) : range.Min;
        int32 maxValue = absolute ? std::abs(range.Max) : range.Max;

        if (minValue > maxValue)
            std::swap(minValue, maxValue);

        std::ostringstream out;
        if (minValue == maxValue)
            out << minValue;
        else
            out << minValue << " to " << maxValue;
        return out.str();
    }

    static std::string FormatDurationTemplate(uint32 milliseconds)
    {
        if (milliseconds == 0)
            return "0 sec";

        if (milliseconds % 60000 == 0)
        {
            uint32 minutes = milliseconds / 60000;
            return std::to_string(minutes) + " min";
        }

        if (milliseconds % 1000 == 0)
        {
            uint32 seconds = milliseconds / 1000;
            return std::to_string(seconds) + " sec";
        }

        return FormatSpellSeconds(milliseconds);
    }

    static TooltipAmountRange GetTemplateScaledAmountRange(Player* player,
                                                           SpellInfo const* spellInfo,
                                                           SpellEffectInfo const& effect)
    {
        TooltipAmountRange amount = GetTooltipAmountRange(player, spellInfo, effect);

        switch (effect.Effect)
        {
            case SPELL_EFFECT_SCHOOL_DAMAGE:
            case SPELL_EFFECT_HEALTH_LEECH:
                return ApplyDamageBonusToRange(player, spellInfo, effect, amount, SPELL_DIRECT_DAMAGE);
            case SPELL_EFFECT_HEAL:
            case SPELL_EFFECT_HEAL_MECHANICAL:
                return ApplyHealingBonusToRange(player, spellInfo, effect, amount, HEAL);
            default:
                break;
        }

        if (effect.IsAura())
        {
            switch (effect.ApplyAuraName)
            {
                case SPELL_AURA_PERIODIC_DAMAGE:
                case SPELL_AURA_PERIODIC_LEECH:
                case SPELL_AURA_PERIODIC_DAMAGE_PERCENT:
                    return ApplyDamageBonusToRange(player, spellInfo, effect, amount, DOT);
                case SPELL_AURA_PERIODIC_HEAL:
                case SPELL_AURA_PERIODIC_HEALTH_FUNNEL:
                    return ApplyHealingBonusToRange(player, spellInfo, effect, amount, DOT);
                default:
                    break;
            }
        }

        return amount;
    }

    static bool GetTemplateEffect(SpellInfo const* spellInfo, uint32 effectNumber, SpellEffectInfo const*& effect)
    {
        if (!spellInfo || effectNumber == 0 || effectNumber > MAX_SPELL_EFFECTS)
            return false;

        SpellEffectInfo const& candidate = spellInfo->Effects[effectNumber - 1];
        if (!candidate.IsEffect())
            return false;

        effect = &candidate;
        return true;
    }

    static std::string ReplaceNamedSpellTemplateToken(Player* player,
                                                      SpellInfo const* spellInfo,
                                                      std::string const& tokenName)
    {
        if (!player || !spellInfo)
            return "";

        if (tokenName == "AP")
        {
            int32 ap = player->GetTotalAttackPowerValue(BASE_ATTACK);
            return std::to_string(std::max<int32>(0, ap));
        }

        if (tokenName == "SP")
        {
            int32 sp = player->SpellBaseDamageBonusDone(spellInfo->GetSchoolMask());
            return std::to_string(std::max<int32>(0, sp));
        }

        return "";
    }

    static std::string ReplaceSpellTemplateToken(Player* player,
                                                 SpellInfo const* spellInfo,
                                                 char token,
                                                 uint32 effectNumber)
    {
        if (!spellInfo)
            return "";

        if (token == 'n')
        {
            if (spellInfo->SpellName[0] && *spellInfo->SpellName[0])
                return spellInfo->SpellName[0];
            return "";
        }

        if (token == 'r')
        {
            float maxRange = spellInfo->GetMaxRange(false, player);
            if (maxRange <= 0.0f)
                return "0";

            std::ostringstream out;
            out << std::fixed << std::setprecision(0) << maxRange;
            return out.str();
        }

        if (token == 'd')
        {
            int32 durationMs = spellInfo->GetMaxDuration();
            if (durationMs <= 0)
                return "0 sec";
            return FormatDurationTemplate(static_cast<uint32>(durationMs));
        }

        if (effectNumber == 0)
            effectNumber = 1;

        SpellEffectInfo const* effect = nullptr;
        if (!GetTemplateEffect(spellInfo, effectNumber, effect))
            return "";

        TooltipAmountRange amount = GetTemplateScaledAmountRange(player, spellInfo, *effect);
        if (!amount.IsValid())
            return "0";

        TooltipAmountRange baseAmount = GetTooltipAmountRange(player, spellInfo, *effect);

        switch (token)
        {
            case 's':
                return FormatSignedAmountRange(amount, true);
            case 'm':
                return std::to_string(std::abs(amount.Min));
            case 'M':
                return std::to_string(std::abs(amount.Max));
            case 'b':
                return baseAmount.IsValid() ? FormatSignedAmountRange(baseAmount, true) : std::string("0");
            case 'o':
            {
                uint32 ticks = GetTooltipTickCount(spellInfo, *effect);
                if (ticks == 0)
                    return FormatSignedAmountRange(amount, true);

                TooltipAmountRange total;
                total.Min = amount.Min * int32(ticks);
                total.Max = amount.Max * int32(ticks);
                return FormatSignedAmountRange(total, true);
            }
            case 't':
            {
                if (effect->Amplitude == 0)
                    return "0 sec";
                return FormatDurationTemplate(effect->Amplitude);
            }
            case 'a':
            {
                float radius = effect->CalcRadius(player);
                if (radius <= 0.0f)
                    return "0";

                std::ostringstream out;
                out << std::fixed << std::setprecision(0) << radius;
                return out.str();
            }
            case 'u':
            {
                float combo = effect->PointsPerComboPoint;
                if (combo == 0.0f)
                    return "0";

                std::ostringstream out;
                out << std::fixed << std::setprecision(0) << std::abs(combo);
                return out.str();
            }
            default:
                break;
        }

        return "";
    }

    static std::string TrimTemplateText(std::string value)
    {
        auto isSpace = [](unsigned char c) { return std::isspace(c) != 0; };

        while (!value.empty() && isSpace(static_cast<unsigned char>(value.front())))
            value.erase(value.begin());
        while (!value.empty() && isSpace(static_cast<unsigned char>(value.back())))
            value.pop_back();

        return value;
    }

    static bool TryParseStrictDouble(std::string const& text, double& out)
    {
        std::string trimmed = TrimTemplateText(text);
        if (trimmed.empty())
            return false;

        try
        {
            std::size_t index = 0;
            out = std::stod(trimmed, &index);
            return index == trimmed.size();
        }
        catch (...)
        {
            return false;
        }
    }

    static bool TryParseLeadingDouble(std::string const& text, double& out)
    {
        std::string trimmed = TrimTemplateText(text);
        if (trimmed.empty())
            return false;

        try
        {
            std::size_t index = 0;
            out = std::stod(trimmed, &index);
            return index > 0;
        }
        catch (...)
        {
            return false;
        }
    }

    static std::string FormatTemplateNumericValue(double value)
    {
        double rounded = std::round(value);
        if (std::fabs(value - rounded) < 0.0001)
            return std::to_string(static_cast<int64>(rounded));

        std::ostringstream out;
        out << std::fixed << std::setprecision(2) << value;

        std::string text = out.str();
        while (!text.empty() && text.back() == '0')
            text.pop_back();
        if (!text.empty() && text.back() == '.')
            text.pop_back();

        return text.empty() ? "0" : text;
    }

    static bool TryEvaluateTemplateOperand(Player* player,
                                           SpellInfo const* spellInfo,
                                           std::string const& operand,
                                           double& out)
    {
        std::string trimmed = TrimTemplateText(operand);
        if (trimmed.empty())
            return false;

        if (trimmed.front() != '$')
            return TryParseStrictDouble(trimmed, out);

        if (trimmed.size() >= 3
            && std::isalpha(static_cast<unsigned char>(trimmed[1]))
            && std::isalpha(static_cast<unsigned char>(trimmed[2])))
        {
            std::string namedToken;
            namedToken.push_back(trimmed[1]);
            namedToken.push_back(trimmed[2]);

            std::string replacement =
                ReplaceNamedSpellTemplateToken(player, spellInfo, namedToken);
            return TryParseLeadingDouble(replacement, out);
        }

        char token = trimmed.size() > 1 ? trimmed[1] : '\0';
        uint32 effectNumber = 0;

        if (std::isdigit(static_cast<unsigned char>(token)))
        {
            token = 's';
            std::size_t indexEnd = 1;
            while (indexEnd < trimmed.size()
                && std::isdigit(static_cast<unsigned char>(trimmed[indexEnd])))
            {
                ++indexEnd;
            }

            effectNumber =
                static_cast<uint32>(std::stoul(trimmed.substr(1, indexEnd - 1)));
        }
        else if (trimmed.size() > 2)
        {
            std::size_t indexEnd = 2;
            while (indexEnd < trimmed.size()
                && std::isdigit(static_cast<unsigned char>(trimmed[indexEnd])))
            {
                ++indexEnd;
            }

            if (indexEnd > 2)
            {
                effectNumber = static_cast<uint32>(
                    std::stoul(trimmed.substr(2, indexEnd - 2)));
            }
        }

        std::string replacement =
            ReplaceSpellTemplateToken(player, spellInfo, token, effectNumber);
        return TryParseLeadingDouble(replacement, out);
    }

    static bool TryEvaluateSimpleTemplateExpression(Player* player,
                                                    SpellInfo const* spellInfo,
                                                    std::string const& expression,
                                                    std::string& out)
    {
        std::string expr = TrimTemplateText(expression);
        if (expr.empty())
            return false;

        std::vector<std::string> operands;
        std::vector<char> operators;

        std::size_t tokenStart = 0;
        for (std::size_t j = 0; j < expr.size(); ++j)
        {
            char c = expr[j];
            bool isOperator = (c == '*' || c == '/' || c == '+' || c == '-');

            if (!isOperator)
                continue;

            if (j == 0)
                continue;

            operands.push_back(expr.substr(tokenStart, j - tokenStart));
            operators.push_back(c);
            tokenStart = j + 1;
        }

        operands.push_back(expr.substr(tokenStart));
        if (operands.empty())
            return false;

        std::vector<double> values;
        values.reserve(operands.size());
        for (std::string const& operandText : operands)
        {
            double value = 0.0;
            if (!TryEvaluateTemplateOperand(player, spellInfo, operandText, value))
                return false;

            values.push_back(value);
        }

        if (values.empty())
            return false;

        // First pass: */ with precedence.
        std::vector<double> reducedValues;
        std::vector<char> reducedOperators;
        reducedValues.push_back(values[0]);

        for (std::size_t opIndex = 0; opIndex < operators.size(); ++opIndex)
        {
            char op = operators[opIndex];
            double rhs = values[opIndex + 1];

            if (op == '*' || op == '/')
            {
                double lhs = reducedValues.back();
                if (op == '/')
                {
                    if (std::fabs(rhs) < 0.000001)
                        return false;
                    reducedValues.back() = lhs / rhs;
                }
                else
                {
                    reducedValues.back() = lhs * rhs;
                }
            }
            else
            {
                reducedOperators.push_back(op);
                reducedValues.push_back(rhs);
            }
        }

        // Second pass: +- left-to-right.
        double result = reducedValues[0];
        for (std::size_t opIndex = 0; opIndex < reducedOperators.size(); ++opIndex)
        {
            char op = reducedOperators[opIndex];
            double rhs = reducedValues[opIndex + 1];
            if (op == '+')
                result += rhs;
            else if (op == '-')
                result -= rhs;
            else
                return false;
        }

        out = FormatTemplateNumericValue(result);
        return true;
    }

    static double ExtractLastTemplateQuantity(std::string const& renderedText)
    {
        for (std::size_t pos = renderedText.size(); pos > 0; --pos)
        {
            if (!std::isdigit(static_cast<unsigned char>(renderedText[pos - 1])))
                continue;

            std::size_t end = pos;
            std::size_t start = pos - 1;
            while (start > 0)
            {
                char c = renderedText[start - 1];
                if (std::isdigit(static_cast<unsigned char>(c))
                    || c == '.' || c == '-' || c == '+')
                {
                    --start;
                }
                else
                {
                    break;
                }
            }

            double value = 0.0;
            if (TryParseStrictDouble(renderedText.substr(start, end - start),
                                     value))
            {
                return value;
            }
        }

        return 2.0;
    }

    static std::string RenderSpellDescriptionTemplate(Player* player,
                                                      SpellInfo const* spellInfo,
                                                      std::string const& sourceTemplate)
    {
        if (!spellInfo || sourceTemplate.empty())
            return "";

        std::string rendered;
        rendered.reserve(sourceTemplate.size() + 32);

        std::size_t i = 0;
        while (i < sourceTemplate.size())
        {
            char ch = sourceTemplate[i];
            if (ch != '$')
            {
                rendered.push_back(ch);
                ++i;
                continue;
            }

            if (i + 1 >= sourceTemplate.size())
            {
                rendered.push_back(ch);
                ++i;
                continue;
            }

            char token = sourceTemplate[i + 1];
            if (token == '$')
            {
                rendered.push_back('$');
                i += 2;
                continue;
            }

            if (token == '{')
            {
                std::size_t closeBrace = sourceTemplate.find('}', i + 2);
                if (closeBrace != std::string::npos)
                {
                    std::string expression =
                        sourceTemplate.substr(i + 2, closeBrace - (i + 2));

                    std::string expressionValue;
                    if (TryEvaluateSimpleTemplateExpression(player,
                                                            spellInfo,
                                                            expression,
                                                            expressionValue))
                    {
                        rendered += ColorizeTooltipValue(expressionValue);
                    }
                    else
                    {
                        rendered.append(sourceTemplate, i, closeBrace - i + 1);
                    }

                    i = closeBrace + 1;
                    continue;
                }

                rendered.push_back('$');
                ++i;
                continue;
            }

            if (token == 'l')
            {
                std::size_t variantStart = i + 2;
                std::size_t colonPos = sourceTemplate.find(':', variantStart);
                std::size_t semiPos = sourceTemplate.find(';', variantStart);
                if (colonPos != std::string::npos
                    && semiPos != std::string::npos
                    && colonPos < semiPos)
                {
                    std::string singular = sourceTemplate.substr(variantStart,
                                                                 colonPos - variantStart);
                    std::string plural = sourceTemplate.substr(colonPos + 1,
                                                               semiPos - (colonPos + 1));

                    double quantity = ExtractLastTemplateQuantity(rendered);
                    rendered += (std::fabs(quantity - 1.0) < 0.0001)
                        ? singular
                        : plural;

                    i = semiPos + 1;
                    continue;
                }
            }

            if (std::isdigit(static_cast<unsigned char>(token)))
            {
                std::size_t indexEnd = i + 1;
                while (indexEnd < sourceTemplate.size()
                    && std::isdigit(static_cast<unsigned char>(sourceTemplate[indexEnd])))
                {
                    ++indexEnd;
                }

                uint32 effectNumber = static_cast<uint32>(
                    std::stoul(sourceTemplate.substr(i + 1,
                                                     indexEnd - (i + 1))));

                std::string replacement = ReplaceSpellTemplateToken(player,
                                                                    spellInfo,
                                                                    's',
                                                                    effectNumber);
                if (!replacement.empty())
                {
                    rendered += ColorizeTooltipValue(replacement);
                    i = indexEnd;
                    continue;
                }
            }

            if (std::isalpha(static_cast<unsigned char>(token))
                && i + 2 < sourceTemplate.size()
                && std::isalpha(static_cast<unsigned char>(sourceTemplate[i + 2])))
            {
                std::string namedToken;
                namedToken.push_back(token);
                namedToken.push_back(sourceTemplate[i + 2]);

                std::string namedReplacement = ReplaceNamedSpellTemplateToken(player, spellInfo, namedToken);
                if (!namedReplacement.empty())
                {
                    rendered += ColorizeTooltipValue(namedReplacement);
                    i += 3;
                    continue;
                }
            }

            std::size_t indexStart = i + 2;
            std::size_t indexEnd = indexStart;
            while (indexEnd < sourceTemplate.size() && std::isdigit(static_cast<unsigned char>(sourceTemplate[indexEnd])))
                ++indexEnd;

            uint32 effectNumber = 0;
            if (indexEnd > indexStart)
                effectNumber = static_cast<uint32>(std::stoul(sourceTemplate.substr(indexStart, indexEnd - indexStart)));

            bool tokenSupported = (token == 'd') || (token == 'n') || (token == 'r')
                || (token == 's') || (token == 'm') || (token == 'M')
                || (token == 'b') || (token == 'o') || (token == 't')
                || (token == 'a') || (token == 'u');
            if (!tokenSupported)
            {
                rendered.push_back('$');
                ++i;
                continue;
            }

            std::string replacement = ReplaceSpellTemplateToken(player, spellInfo, token, effectNumber);
            if (replacement.empty())
            {
                rendered.append(sourceTemplate, i, indexEnd - i);
            }
            else
            {
                // $n resolves to the spell NAME -- never color it.
                rendered += (token == 'n') ? replacement
                    : ColorizeTooltipValue(replacement);
            }

            i = indexEnd;
        }

        return rendered;
    }

    static bool HasUnresolvedTemplateTokens(std::string const& text)
    {
        for (std::size_t i = 0; i + 1 < text.size(); ++i)
        {
            if (text[i] != '$')
                continue;

            char token = text[i + 1];
            if (token == '$')
            {
                ++i;
                continue;
            }

            if (token == '{' || token == 'l'
                || std::isdigit(static_cast<unsigned char>(token)))
            {
                return true;
            }

            if (std::isalpha(static_cast<unsigned char>(token)))
            {
                if (i + 2 < text.size())
                {
                    char next = text[i + 2];
                    if (std::isalpha(static_cast<unsigned char>(next))
                        || std::isdigit(static_cast<unsigned char>(next)))
                    {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    static uint32 GetTooltipTickCount(SpellInfo const* spellInfo, SpellEffectInfo const& effect)
    {
        if (!spellInfo || effect.Amplitude == 0)
            return 0;

        int32 durationMs = spellInfo->GetMaxDuration();
        if (durationMs <= 0)
            return 0;

        return std::max<uint32>(1u, static_cast<uint32>(durationMs / int32(effect.Amplitude)));
    }

    static std::string FormatPeriodicTotalLine(Player* player,
                                               SpellInfo const* spellInfo,
                                               SpellEffectInfo const& effect,
                                               char const* singularVerb,
                                               char const* totalNoun,
                                               bool healing)
    {
        TooltipAmountRange perTick = GetTooltipAmountRange(player, spellInfo, effect);
        if (healing)
            perTick = ApplyHealingBonusToRange(player, spellInfo, effect, perTick, DOT);
        else
            perTick = ApplyDamageBonusToRange(player, spellInfo, effect, perTick, DOT);

        uint32 tickCount = GetTooltipTickCount(spellInfo, effect);
        if (!perTick.IsValid() || tickCount == 0)
            return "";

        TooltipAmountRange total;
        total.Min = perTick.Min * int32(tickCount);
        total.Max = perTick.Max * int32(tickCount);

        std::ostringstream line;
        line << singularVerb << " " << FormatSignedAmountRange(total, true)
             << " " << totalNoun << " over "
             << FormatSpellSeconds(static_cast<uint32>(spellInfo->GetMaxDuration()));
        return line.str();
    }

    static std::string BuildSpellEffectTooltipLine(Player* player,
                                                   SpellInfo const* spellInfo,
                                                   SpellEffectInfo const& effect)
    {
        TooltipAmountRange amount = GetTooltipAmountRange(player, spellInfo, effect);

        if (effect.Effect == SPELL_EFFECT_WEAPON_DAMAGE
            || effect.Effect == SPELL_EFFECT_WEAPON_DAMAGE_NOSCHOOL
            || effect.Effect == SPELL_EFFECT_NORMALIZED_WEAPON_DMG)
        {
            if (amount.IsValid())
                return "Weapon damage plus " + FormatSignedAmountRange(amount, true) + ".";
            return "Deals weapon damage.";
        }

        if (effect.Effect == SPELL_EFFECT_WEAPON_PERCENT_DAMAGE)
        {
            if (amount.IsValid())
                return "Deals " + FormatSignedAmountRange(amount, true) + "% weapon damage.";
            return "Deals weapon damage based on a percentage modifier.";
        }

        if ((effect.Effect == SPELL_EFFECT_TRIGGER_SPELL
            || effect.Effect == SPELL_EFFECT_TRIGGER_SPELL_2
            || effect.Effect == SPELL_EFFECT_TRIGGER_SPELL_WITH_VALUE
            || effect.Effect == SPELL_EFFECT_TRIGGER_MISSILE
            || effect.Effect == SPELL_EFFECT_TRIGGER_MISSILE_SPELL_WITH_VALUE)
            && effect.TriggerSpell > 0)
        {
            SpellInfo const* triggered = sSpellMgr->GetSpellInfo(effect.TriggerSpell);
            if (triggered && triggered->SpellName[0] && *triggered->SpellName[0])
            {
                std::ostringstream out;
                out << "Triggers " << triggered->SpellName[0]
                    << " (Spell " << effect.TriggerSpell << ")";
                if (triggered->Rank[0] && *triggered->Rank[0])
                    out << ", " << triggered->Rank[0];
                out << ".";
                return out.str();
            }

            return "Triggers Spell " + std::to_string(effect.TriggerSpell) + ".";
        }

        switch (effect.Effect)
        {
            case SPELL_EFFECT_SCHOOL_DAMAGE:
            case SPELL_EFFECT_HEALTH_LEECH:
                amount = ApplyDamageBonusToRange(player, spellInfo, effect, amount, SPELL_DIRECT_DAMAGE);
                if (amount.IsValid())
                    return "Causes " + FormatSignedAmountRange(amount, true) + " damage.";
                break;
            case SPELL_EFFECT_HEAL:
            case SPELL_EFFECT_HEAL_MECHANICAL:
                amount = ApplyHealingBonusToRange(player, spellInfo, effect, amount, HEAL);
                if (amount.IsValid())
                    return "Heals a friendly target for " + FormatSignedAmountRange(amount, true) + ".";
                break;
            case SPELL_EFFECT_ENERGIZE:
                if (amount.IsValid())
                    return "Restores " + FormatSignedAmountRange(amount, true) + " " + GetPowerTypeLabel(spellInfo->PowerType) + ".";
                break;
            default:
                break;
        }

        if (!effect.IsAura())
            return "";

        switch (effect.ApplyAuraName)
        {
            case SPELL_AURA_PERIODIC_DAMAGE:
            case SPELL_AURA_PERIODIC_LEECH:
            case SPELL_AURA_PERIODIC_DAMAGE_PERCENT:
                return FormatPeriodicTotalLine(player, spellInfo, effect, "Causes", "damage", false);
            case SPELL_AURA_PERIODIC_HEAL:
            case SPELL_AURA_PERIODIC_HEALTH_FUNNEL:
                return FormatPeriodicTotalLine(player, spellInfo, effect, "Heals", "health", true);
            case SPELL_AURA_PERIODIC_TRIGGER_SPELL:
                if (effect.TriggerSpell > 0)
                {
                    SpellInfo const* triggered = sSpellMgr->GetSpellInfo(effect.TriggerSpell);
                    if (triggered && triggered->SpellName[0] && *triggered->SpellName[0])
                    {
                        std::ostringstream out;
                        out << "Periodically triggers " << triggered->SpellName[0]
                            << " (Spell " << effect.TriggerSpell << ").";
                        return out.str();
                    }
                    return "Periodically triggers Spell " + std::to_string(effect.TriggerSpell) + ".";
                }
                break;
            case SPELL_AURA_SCHOOL_ABSORB:
            case SPELL_AURA_MANA_SHIELD:
                if (amount.IsValid())
                    return "Absorbs " + FormatSignedAmountRange(amount, true) + " damage.";
                break;
            case SPELL_AURA_MOD_STUN:
                return "Stuns the target.";
            case SPELL_AURA_MOD_ROOT:
                return "Roots the target in place.";
            case SPELL_AURA_MOD_FEAR:
                return "Causes the target to flee in fear.";
            case SPELL_AURA_MOD_CONFUSE:
                return "Disorients the target.";
            case SPELL_AURA_MOD_SILENCE:
                return "Silences the target.";
            case SPELL_AURA_MOD_INCREASE_SPEED:
                if (amount.IsValid())
                    return "Increases movement speed by " + FormatSignedAmountRange(amount, true) + "%.";
                break;
            case SPELL_AURA_MOD_DECREASE_SPEED:
                if (amount.IsValid())
                    return "Reduces movement speed by " + FormatSignedAmountRange(amount, true) + "%.";
                break;
            case SPELL_AURA_MOD_DAMAGE_DONE:
            case SPELL_AURA_MOD_DAMAGE_PERCENT_DONE:
                if (amount.IsValid())
                    return "Increases damage done by " + FormatSignedAmountRange(amount, true) + ".";
                break;
            case SPELL_AURA_MOD_HEALING:
                if (amount.IsValid())
                    return "Increases healing done by " + FormatSignedAmountRange(amount, true) + ".";
                break;
            case SPELL_AURA_MOD_STAT:
            case SPELL_AURA_MOD_PERCENT_STAT:
                if (amount.IsValid())
                    return "Modifies stats by " + FormatSignedAmountRange(amount, true) + ".";
                break;
            default:
                break;
        }

        return "";
    }

    static std::string BuildSpellTooltipEnrichmentLine(Player* player,
                                                       uint32 spellId,
                                                       SpellInfo const* spellInfo);

    static bool AppendSpellDescriptionLines(Player* player,
                                            SpellInfo const* spellInfo,
                                            DCAddon::JsonValue& lines,
                                            bool includeFamilyMetadata)
    {
        if (!spellInfo)
            return false;

        std::set<std::string> seen;
        bool addedBody = false;

        std::string familyInfo = includeFamilyMetadata ? FormatSpellFamilyInfo(spellInfo) : "";
        if (!familyInfo.empty())
            PushWrappedTooltipLine(lines, familyInfo, 0.70, 0.92, 1.00, "meta");

        std::string descriptionTemplate = GetSpellDescriptionTemplate(spellInfo->Id);
        std::string renderedDescription = RenderSpellDescriptionTemplate(player, spellInfo, descriptionTemplate);
        if (!renderedDescription.empty()
            && !HasUnresolvedTemplateTokens(renderedDescription))
        {
            PushWrappedTooltipLine(lines, renderedDescription, 0.95, 0.82, 0.55, "body");
            return true;
        }

        for (SpellEffectInfo const& effect : spellInfo->Effects)
        {
            if (!effect.IsEffect())
                continue;

            std::string description = BuildSpellEffectTooltipLine(player, spellInfo, effect);
            if (description.empty() || !seen.insert(description).second)
                continue;

            PushWrappedTooltipLine(lines, description, 0.95, 0.82, 0.55, "body");
            addedBody = true;
        }

        return addedBody;
    }

    static void AppendMountMetadataLines(Player* player,
                                         SpellInfo const* spellInfo,
                                         DCAddon::JsonValue& lines)
    {
        if (!spellInfo)
            return;

        bool hasGroundMount = false;
        bool hasFlyingMount = false;
        int32 bestGroundSpeed = 0;
        int32 bestFlyingSpeed = 0;

        for (SpellEffectInfo const& effect : spellInfo->Effects)
        {
            if (!effect.IsEffect() || !effect.IsAura())
                continue;

            int32 value = effect.CalcValue(player);
            if (value < 0)
                value = -value;

            switch (effect.ApplyAuraName)
            {
                case SPELL_AURA_MOD_INCREASE_MOUNTED_SPEED:
                case SPELL_AURA_MOD_MOUNTED_SPEED_ALWAYS:
                case SPELL_AURA_MOD_MOUNTED_SPEED_NOT_STACK:
                    hasGroundMount = true;
                    if (value > bestGroundSpeed)
                        bestGroundSpeed = value;
                    break;
                case SPELL_AURA_MOD_INCREASE_MOUNTED_FLIGHT_SPEED:
                case SPELL_AURA_MOD_MOUNTED_FLIGHT_SPEED_ALWAYS:
                    hasFlyingMount = true;
                    if (value > bestFlyingSpeed)
                        bestFlyingSpeed = value;
                    break;
                default:
                    break;
            }
        }

        if (!hasGroundMount && !hasFlyingMount)
            return;

        if (hasGroundMount && hasFlyingMount)
            PushTooltipLine(lines, "Mount Type", "Ground & Flying", 0.75, 0.92, 1.0, "meta");
        else if (hasFlyingMount)
            PushTooltipLine(lines, "Mount Type", "Flying", 0.75, 0.92, 1.0, "meta");
        else
            PushTooltipLine(lines, "Mount Type", "Ground", 0.75, 0.92, 1.0, "meta");

        if (bestGroundSpeed > 0)
            PushTooltipLine(lines, "Ground Speed", "+" + std::to_string(bestGroundSpeed) + "%", 0.75, 0.92, 1.0, "meta");

        if (bestFlyingSpeed > 0)
            PushTooltipLine(lines, "Flight Speed", "+" + std::to_string(bestFlyingSpeed) + "%", 0.75, 0.92, 1.0, "meta");
    }

    static DCAddon::JsonValue BuildSpellTooltipEnrichmentLines(Player* player,
                                                               uint32 /*spellId*/,
                                                               uint32 /*contextHash*/,
                                                               SpellInfo const* spellInfo,
                                                               std::string const& /*line*/,
                                                               bool includeFamilyMetadata)
    {
        DCAddon::JsonValue lines;
        lines.SetArray();

        if (!spellInfo)
            return lines;

        if (spellInfo->Rank[0] && *spellInfo->Rank[0])
            PushTooltipLine(lines, spellInfo->Rank[0]);

        // Row: Cost (left) | Range (right) — matches Blizzard tooltip layout
        int32 powerCost = player ? spellInfo->CalcPowerCost(player, spellInfo->GetSchoolMask()) : 0;
        std::string costStr;
        if (powerCost > 0)
        {
            std::ostringstream costLine;
            costLine << powerCost << " " << GetPowerTypeLabel(spellInfo->PowerType);
            costStr = costLine.str();
        }

        // Death Knight spells cost runes instead of a flat power amount.
        if (costStr.empty())
            costStr = BuildRuneCostText(spellInfo);

        // Channeled/periodic power drain ("X Mana per sec").
        uint32 powerPerSecond = spellInfo->ManaPerSecond
            + spellInfo->ManaPerSecondPerLevel
                * (player ? player->GetLevel() : 0);
        if (powerPerSecond > 0)
        {
            if (costStr.empty())
                costStr = std::to_string(powerPerSecond) + " "
                    + GetPowerTypeLabel(spellInfo->PowerType) + " per sec";
            else
                costStr += ", plus " + std::to_string(powerPerSecond)
                    + " per sec";
        }

        float minRange = spellInfo->GetMinRange(false);
        float maxRange = spellInfo->GetMaxRange(false, player);
        std::string rangeStr;
        if (maxRange > 0.0f)
        {
            std::ostringstream rangeLine;
            rangeLine << std::fixed << std::setprecision(0);
            if (minRange > 0.0f)
                rangeLine << minRange << "-" << maxRange << " yd range";
            else
                rangeLine << maxRange << " yd range";
            rangeStr = rangeLine.str();
        }

        if (!costStr.empty() || !rangeStr.empty())
            PushTooltipLine(lines, costStr, rangeStr);

        // Row: Cast time (left) | Cooldown (right) — matches Blizzard tooltip layout
        uint32 castTimeMs = spellInfo->CalcCastTime(player);
        std::string castStr = (castTimeMs == 0) ? "Instant cast" : (FormatSpellSeconds(castTimeMs) + " cast");

        uint32 cooldownMs = spellInfo->GetRecoveryTime();
        std::string cooldownStr;
        if (cooldownMs > 0)
            cooldownStr = FormatSpellSeconds(cooldownMs) + " cooldown";

        PushTooltipLine(lines, castStr, cooldownStr);

        int32 durationMs = spellInfo->GetMaxDuration();
        if (durationMs > 0)
            PushTooltipLine(lines, "Duration", FormatSpellSeconds(static_cast<uint32>(durationMs)));

        // Native-tooltip extras lost by the rebuilt hyperlink bodies.
        std::string reagents = BuildReagentsText(spellInfo);
        if (!reagents.empty())
            PushWrappedTooltipLine(lines, "Reagents: " + reagents,
                1.0, 1.0, 1.0, "");

        std::string requiredForm = BuildRequiredFormText(spellInfo);
        if (!requiredForm.empty())
            PushTooltipLine(lines, requiredForm, "", 1.0, 1.0, 1.0);

        std::string requiredEquip = BuildRequiredEquipText(spellInfo);
        if (!requiredEquip.empty())
            PushTooltipLine(lines, requiredEquip, "", 1.0, 1.0, 1.0);

        AppendMountMetadataLines(player, spellInfo, lines);

        bool hasBodyLines = AppendSpellDescriptionLines(player,
                                                        spellInfo,
                                                        lines,
                                                        includeFamilyMetadata);
        if (!hasBodyLines)
        {
            std::string fallbackBody = BuildSpellTooltipEnrichmentLine(player,
                                                                        spellInfo->Id,
                                                                        spellInfo);
            if (!fallbackBody.empty())
                PushWrappedTooltipLine(lines, fallbackBody, 0.95, 0.82, 0.55, "body");
        }

        return lines;
    }

    // AddonProtocol skeleton for the mixed tooltip architecture:
    // request payload order: requestId, spellId, contextHash
    // JSON response fields: requestId, spellId, contextHash, status, line, lines[]
    void SendSpellTooltipEnrichment(Player* player,
                                    uint32 requestId,
                                    uint32 spellId,
                                    uint32 contextHash,
                                    uint8 status,
                                    std::string const& line,
                                    std::string const& protocolRequestId,
                                    SpellInfo const* spellInfo = nullptr,
                                    bool includeFamilyMetadata = false,
                                    SpellTooltipTransportPreference
                                        transportPreference =
                                            SpellTooltipTransportPreference::Auto)
    {
        if (!player || !player->GetSession())
            return;

        SpellTooltipTransportDecision transportDecision =
            ResolveSpellTooltipTransportDecision(player, protocolRequestId,
                transportPreference);
        DCAddon::JsonValue structuredLines;
        DCAddon::JsonValue const* structuredLinesPtr = nullptr;

        if (status == 0 && spellInfo)
        {
            structuredLines = BuildSpellTooltipEnrichmentLines(player, spellId,
                contextHash, spellInfo, line, includeFamilyMetadata);
            structuredLinesPtr = &structuredLines;
        }

        if (IsTooltipTransportDebugEnabled())
        {
            LOG_INFO("module.dc",
                "QoS tooltip transport account={} player='{}' spellId={} requestId={} contextHash={} protocolRid='{}' status={} transport={} reason={} clientCaps=0x{:X} negotiatedCaps=0x{:X} compatible={}",
                player->GetSession()->GetAccountId(), player->GetName(),
                spellId, requestId, contextHash,
                protocolRequestId.empty() ? "<none>" : protocolRequestId,
                status, ToString(transportDecision.transport),
                transportDecision.reason,
                transportDecision.hasCapabilityState
                    ? transportDecision.capabilityState.clientCapabilities
                    : 0,
                transportDecision.hasCapabilityState
                    ? transportDecision.capabilityState.negotiatedCapabilities
                    : 0,
                transportDecision.hasCapabilityState
                    ? transportDecision.capabilityState.versionCompatible
                    : false);
        }

        if (transportDecision.transport == SpellTooltipTransport::NativeBridge)
        {
            // Keep the legacy `line` field first for existing native render
            // paths, then append structured lines for Lua-driven tooltips.
            SendSpellTooltipEnrichmentNative(player, requestId, spellId,
                contextHash, status, line, structuredLinesPtr);
            return;
        }

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_SPELL_TOOLTIP_ENRICHMENT);
        if (!protocolRequestId.empty())
            msg.SetRequestId(protocolRequestId);

        msg.Set("requestId", requestId);
        msg.Set("spellId", spellId);
        msg.Set("contextHash", contextHash);
        msg.Set("status", static_cast<uint32>(status));
        msg.Set("line", line);

        if (structuredLinesPtr)
        {
            msg.Set("source", "server-v2");
            msg.Set("lines", structuredLines);
        }

        msg.Send(player);
    }

    // Returns the enrichment line for (player, spellId, contextHash), building
    // it on a cache miss. See s_SpellTooltipLineCache for the keying rationale.
    // Set DC.QoS.TooltipEnrichment.CacheTtlSeconds = 0 to bypass the cache.
    static std::string GetOrBuildSpellTooltipLine(Player* player, uint32 spellId,
        uint32 contextHash, SpellInfo const* spellInfo)
    {
        uint32 const ttlSeconds = sConfigMgr->GetOption<uint32>(
            "DC.QoS.TooltipEnrichment.CacheTtlSeconds", 60);
        if (ttlSeconds == 0 || !player)
            return BuildSpellTooltipEnrichmentLine(player, spellId, spellInfo);

        SpellTooltipLineKey const key{ player->GetGUID().GetCounter(), spellId,
            contextHash };
        time_t const now = time(nullptr);

        {
            std::lock_guard<std::mutex> lock(s_SpellTooltipLineCacheMutex);
            auto itr = s_SpellTooltipLineCache.find(key);
            if (itr != s_SpellTooltipLineCache.end() && itr->second.expiresAt > now)
                return itr->second.line;
        }

        std::string line = BuildSpellTooltipEnrichmentLine(player, spellId,
            spellInfo);

        {
            std::lock_guard<std::mutex> lock(s_SpellTooltipLineCacheMutex);
            if (s_SpellTooltipLineCache.size() >= SPELL_TOOLTIP_LINE_CACHE_SOFT_CAP)
            {
                for (auto itr = s_SpellTooltipLineCache.begin();
                    itr != s_SpellTooltipLineCache.end(); )
                {
                    if (itr->second.expiresAt <= now)
                        itr = s_SpellTooltipLineCache.erase(itr);
                    else
                        ++itr;
                }

                // Still oversized after pruning expired entries: drop all to
                // keep memory bounded (rare with a short TTL).
                if (s_SpellTooltipLineCache.size()
                    >= SPELL_TOOLTIP_LINE_CACHE_SOFT_CAP * 2)
                    s_SpellTooltipLineCache.clear();
            }

            s_SpellTooltipLineCache[key] = SpellTooltipLineCacheEntry{
                line, now + static_cast<time_t>(ttlSeconds) };
        }

        return line;
    }

    void HandleSpellTooltipEnrichmentRequest(Player* player,
                                             uint32 requestId,
                                             uint32 spellId,
                                             uint32 contextHash,
                                             std::string const& protocolRequestId,
                                             SpellTooltipTransportPreference
                                                 transportPreference =
                                                     SpellTooltipTransportPreference::Auto)
    {
        if (!player)
            return;

        // Status map (matches client expectations):
        // 0 = success (line present)
        // 1 = spell not found
        // 2 = invalid request payload
        // 3 = no enrichment data available
        if (requestId == 0 || spellId == 0 || contextHash == 0)
        {
            SendSpellTooltipEnrichment(player, requestId, spellId,
                contextHash, 2, "invalid-request", protocolRequestId,
                nullptr, false, transportPreference);
            return;
        }

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
        {
            SendSpellTooltipEnrichment(player, requestId, spellId,
                contextHash, 1, "spell-not-found", protocolRequestId,
                nullptr, false, transportPreference);
            return;
        }

        std::string line = GetOrBuildSpellTooltipLine(player, spellId,
            contextHash, spellInfo);
        if (line.empty())
        {
            SendSpellTooltipEnrichment(player, requestId, spellId,
                contextHash, 3, "no-enrichment-data", protocolRequestId,
                nullptr, false, transportPreference);
            return;
        }

        QoSSettings settings = GetPlayerSettingsCached(player);
        bool includeFamilyMetadata = settings.showSpellFamilyMetadata;

        SendSpellTooltipEnrichment(player, requestId, spellId, contextHash,
            0, line, protocolRequestId, spellInfo, includeFamilyMetadata,
            transportPreference);
    }

    static std::string BuildSpellTooltipEnrichmentLine(Player* player,
                                                       uint32 spellId,
                                                       SpellInfo const* spellInfo)
    {
        if (!player || !spellInfo)
            return "";

        // Legacy transport compatibility: older clients/transports may only
        // consume the single `line` field and ignore structured `lines[]`.
        // Return one human-readable body line instead of protocol metadata.
        std::string descriptionTemplate = GetSpellDescriptionTemplate(spellId);
        std::string renderedDescription = RenderSpellDescriptionTemplate(player,
                                                                         spellInfo,
                                                                         descriptionTemplate);
        if (!renderedDescription.empty()
            && !HasUnresolvedTemplateTokens(renderedDescription))
        {
            return renderedDescription;
        }

        for (SpellEffectInfo const& effect : spellInfo->Effects)
        {
            if (!effect.IsEffect())
                continue;

            std::string effectLine = BuildSpellEffectTooltipLine(player,
                                                                 spellInfo,
                                                                 effect);
            if (!effectLine.empty())
                return effectLine;
        }

        // Ensure request handler can still return success for spells whose
        // effect patterns are not covered by BuildSpellEffectTooltipLine.
        // This keeps structured lines[] delivery active for modern clients
        // and avoids status=3 for valid spells.
        uint32 castTimeMs = spellInfo->CalcCastTime(player);
        if (castTimeMs == 0)
            return "Instant cast.";

        return "Cast time: " + FormatSpellSeconds(castTimeMs) + ".";

        return "";
    }

    void SendNotification(Player* player, const std::string& type, const std::string& message)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_NOTIFICATION);
        msg.Set("type", type);
        msg.Set("message", message);
        msg.Send(player);
    }

    // =======================================================================
    // Message Handlers
    // =======================================================================

    void HandleSyncSettings(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        SendSettingsSync(player);
    }

    void HandleUpdateSetting(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (json.IsNull())
            return;

        std::string path = json["path"].AsString();
        std::string value;

        // Handle different value types
        if (json.HasKey("value"))
        {
            auto& val = json["value"];
            if (val.IsBool())
                value = val.AsBool() ? "1" : "0";
            else if (val.IsNumber())
                value = std::to_string(val.AsNumber());
            else
                value = val.AsString();
        }

        if (!path.empty())
        {
            SavePlayerSetting(player, path, value);

            // Send confirmation
            DCAddon::JsonMessage response(MODULE, Opcode::SMSG_SETTING_UPDATED);
            response.Set("path", path);
            response.Set("value", value);
            response.Set("success", true);
            response.Send(player);
        }
    }

    void HandleGetItemInfo(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);

        // Check if this is an upgrade info request (has bag/slot)
        if (!json.IsNull() && json.HasKey("bag") && json.HasKey("slot"))
        {
            int32 rawBag = static_cast<int32>(json["bag"].AsNumber());
            int32 rawSlot = static_cast<int32>(json["slot"].AsNumber());

            // Backward-compat: older clients sent equipment pseudo-bag as -2,
            // which can arrive as uint8 254 after transport coercion.
            if (rawBag == -2 || rawBag == 254)
                rawBag = INVENTORY_SLOT_BAG_0;

            if (rawBag < 0 || rawBag > 255 || rawSlot < 0 || rawSlot > 255)
            {
                DCAddon::JsonMessage response(MODULE, Opcode::SMSG_ITEM_INFO);
                response.Set("bag", rawBag);
                response.Set("slot", rawSlot);
                response.Set("error", "Invalid bag/slot in request");
                response.Send(player);
                return;
            }

            uint8 bag = static_cast<uint8>(rawBag);
            uint8 slot = static_cast<uint8>(rawSlot);

            AuditItemUpgradeTooltipTransport(player, false);

            // Get item from player's inventory
            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
            {
                DCAddon::JsonMessage response(MODULE, Opcode::SMSG_ITEM_INFO);
                response.Set("bag", static_cast<int32>(bag));
                response.Set("slot", static_cast<int32>(slot));
                response.Set("error", "Item not found at location");
                response.Send(player);
                return;
            }

            SendItemUpgradeInfo(player, item, bag, slot);
            return;
        }

        // Try to get item ID from message data
        uint32 itemId = 0;

        if (!json.IsNull() && json.HasKey("itemId"))
        {
            itemId = static_cast<uint32>(json["itemId"].AsNumber());
        }
        else if (msg.GetDataCount() > 0)
        {
            // Simple format: QOS|0x03|itemId
            itemId = msg.GetUInt32(0);
        }

        if (itemId > 0)
        {
            SendItemInfo(player, itemId);
        }
    }

    void HandleGetNpcInfo(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        std::string guidStr;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.IsNull() && json.HasKey("guid"))
        {
            guidStr = json["guid"].AsString();
        }
        else if (msg.GetDataCount() > 0)
        {
            guidStr = msg.GetString(0);
        }

        if (!guidStr.empty())
        {
            AuditNpcTooltipTransport(player, false);
            SendNpcInfo(player, guidStr);
        }
    }

    static void HandleItemUpgradeTooltipNativeRequest(Player* player,
        uint8 bag, uint8 slot)
    {
        if (!player)
            return;

        AuditItemUpgradeTooltipTransport(player, true);

        Item* item = player->GetItemByPos(bag, slot);
        if (!item)
        {
            SendItemUpgradeInfoNativeError(player, bag, slot,
                "Item not found at location");
            return;
        }

        SendItemUpgradeInfoNative(player, item, bag, slot);
    }

    static void HandleItemTooltipSnapshotNativeRequest(Player* player,
        uint32 requestId, uint32 itemGuidLow, uint32 knownRevision,
        uint32 itemEntry, uint32 contextHash, uint32 ownerGuidLow,
        uint8 contextKind, uint8 bag, uint8 slot, uint8 flags)
    {
        if (!player)
            return;

        AuditItemTooltipSnapshotTransport(player, true);

        ItemTooltipSnapshotNativeRequest snapshotRequest;
        snapshotRequest.requestId = requestId;
        snapshotRequest.itemGuidLow = itemGuidLow;
        snapshotRequest.knownRevision = knownRevision;
        snapshotRequest.itemEntry = itemEntry;
        snapshotRequest.contextHash = contextHash;
        snapshotRequest.ownerGuidLow = ownerGuidLow;
        snapshotRequest.contextKind = contextKind;
        snapshotRequest.bag = bag;
        snapshotRequest.slot = slot;
        snapshotRequest.flags = flags;

        uint32 resolveStatus = ItemTooltipSnapshotStatus::ITEM_NOT_FOUND;
        Item* item = ResolveItemTooltipSnapshotItem(player, snapshotRequest,
            resolveStatus);
        if (!item)
        {
            SendItemTooltipSnapshotNative(player, snapshotRequest, nullptr, {},
                resolveStatus,
                resolveStatus == ItemTooltipSnapshotStatus::UNSUPPORTED_CONTEXT
                    ? "Tooltip context is not supported yet"
                    : "Item not found for tooltip snapshot");
            return;
        }

        if (DarkChaos::ItemUpgrade::UpgradeManager* mgr =
                DarkChaos::ItemUpgrade::GetUpgradeManager())
        {
            DarkChaos::ItemUpgrade::ItemUpgradeTooltipSnapshot snapshot;
            if (!mgr->BuildTooltipSnapshot(item, snapshot))
            {
                SendItemTooltipSnapshotNative(player, snapshotRequest, nullptr, {},
                    ItemTooltipSnapshotStatus::SERVER_ERROR,
                    "Failed to build item tooltip snapshot");
                return;
            }

            if (snapshotRequest.knownRevision != 0
                && snapshotRequest.knownRevision == snapshot.revision)
            {
                SendItemTooltipSnapshotNative(player, snapshotRequest,
                    &snapshot, {},
                    ItemTooltipSnapshotStatus::NOT_MODIFIED, "");
                return;
            }

            SendItemTooltipSnapshotNative(player, snapshotRequest, &snapshot,
                BuildItemTooltipSnapshotRows(player, item, snapshot),
                ItemTooltipSnapshotStatus::OK, "");
            return;
        }

        SendItemTooltipSnapshotNative(player, snapshotRequest, nullptr, {},
            ItemTooltipSnapshotStatus::SERVER_ERROR,
            "Upgrade manager is unavailable");
    }

    static void HandleNpcTooltipInfoNativeRequest(Player* player,
        std::string const& guidStr)
    {
        if (!player || guidStr.empty())
            return;

        AuditNpcTooltipTransport(player, true);
        SendNpcTooltipInfoNative(player, guidStr);
    }

    static void HandlePingRelayNativeRequest(Player* player,
        std::string const& requestedDistribution,
        std::string const& payload)
    {
        RelayPingPayload(player, requestedDistribution, payload);
    }

    void HandleGetSpellInfo(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        uint32 spellId = 0;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.IsNull() && json.HasKey("spellId"))
        {
            spellId = static_cast<uint32>(json["spellId"].AsNumber());
        }
        else if (msg.GetDataCount() > 0)
        {
            spellId = msg.GetUInt32(0);
        }

        if (spellId > 0)
        {
            SendSpellInfo(player, spellId);
        }
    }

    void HandleRequestSpellTooltipEnrichment(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        uint32 requestId = 0;
        uint32 spellId = 0;
        uint32 contextHash = 0;
        std::string protocolRequestId = msg.GetRequestId();

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (!json.IsNull() && json.HasKey("requestId") && json.HasKey("spellId") && json.HasKey("contextHash"))
        {
            requestId = static_cast<uint32>(json["requestId"].AsNumber());
            spellId = static_cast<uint32>(json["spellId"].AsNumber());
            contextHash = static_cast<uint32>(json["contextHash"].AsNumber());
        }
        else if (msg.GetDataCount() >= 3)
        {
            // Simple format: QOS|0x08|requestId|spellId|contextHash
            // Some clients include a protocol request id prefix in payload:
            // QOS|0x08|RID:...|requestId|spellId|contextHash
            uint8 dataIndex = 0;
            if (msg.GetDataCount() >= 4)
            {
                std::string firstField = msg.GetString(0);
                if (!firstField.empty() && firstField.rfind("RID:", 0) == 0)
                {
                    dataIndex = 1;
                    if (protocolRequestId.empty())
                        protocolRequestId = firstField;
                }
            }

            requestId = msg.GetUInt32(dataIndex + 0);
            spellId = msg.GetUInt32(dataIndex + 1);
            contextHash = msg.GetUInt32(dataIndex + 2);
        }

        HandleSpellTooltipEnrichmentRequest(player, requestId, spellId,
            contextHash, protocolRequestId);
    }

    void HandleRequestFeature(Player* player, const DCAddon::ParsedMessage& msg)
    {
        if (!player)
            return;

        DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
        if (json.IsNull())
            return;

        std::string feature = json["feature"].AsString();

        if (feature == NativeEnvelopeFeature::PING)
        {
            std::string action = json.HasKey("action") ? json["action"].AsString() : "";

            if (action != NativeEnvelopeFeature::ACTION_RELAY)
            {
                SendPingRelayFeatureResponse(player, false, "", 0,
                    "Unsupported ping feature action.");
                return;
            }

            std::string payload = json.HasKey("payload") ? json["payload"].AsString() : "";
            if (payload.empty() && json.HasKey("syncPayload"))
                payload = json["syncPayload"].AsString();

            std::string requestedDistribution = json.HasKey("distribution") ? json["distribution"].AsString() : "AUTO";
            RelayPingPayload(player, requestedDistribution, payload, true);
            return;
        }

        if (feature == NativeEnvelopeFeature::PING_STATE)
        {
            std::string requestedDistribution = json.HasKey("distribution")
                ? json["distribution"].AsString()
                : "AUTO";
            SendFeatureResponse(player, feature,
                BuildPingRelayStatePayload(player, requestedDistribution),
                "feature-request:ping-state");
            return;
        }

        if (feature == NativeEnvelopeFeature::GRAPHICS_PROFILE)
        {
            PushRuntimeProfile(player, true, "feature-request");
            return;
        }

        if (feature == NativeEnvelopeFeature::GRAPHICS_PROFILE_STATE)
        {
            RuntimeProfileSelection selection = SelectRuntimeProfile(player);
            SendFeatureResponse(player, feature,
                BuildRuntimeProfileStatePayload(player, selection),
                "feature-request:profile-state");
            return;
        }

        if (feature == NativeEnvelopeFeature::SERVER_TIME)
        {
            DCAddon::JsonValue payload;
            payload.SetObject();
            payload.Set("serverTime", static_cast<int32>(time(nullptr)));
            SendFeatureResponse(player, feature, payload, "feature-request");
            return;
        }

        if (feature == NativeEnvelopeFeature::PLAYER_STATS)
        {
            DCAddon::JsonValue payload;
            payload.SetObject();
            payload.Set("level", static_cast<int32>(player->GetLevel()));
            payload.Set("maxLevel",
                static_cast<int32>(sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL)));
            payload.Set("gold", static_cast<int32>(player->GetMoney()));
            SendFeatureResponse(player, feature, payload, "feature-request");
            return;
        }

        // Handle specific feature requests
        DCAddon::JsonMessage response(MODULE, Opcode::SMSG_FEATURE_DATA);
        response.Set("feature", feature);

        if (feature != NativeEnvelopeFeature::SERVER_TIME
            && feature != NativeEnvelopeFeature::PLAYER_STATS)
        {
            response.Set("error", "Unknown feature: " + feature);
        }

        response.Send(player);
    }

    void HandleCollectAllMail(Player* player, const DCAddon::ParsedMessage& /*msg*/)
    {
        if (!player || !player->GetSession())
            return;

        // Iterate over player's mail
        PlayerMails const& mailCache = player->GetMails();

        uint32 collectedGold = 0;

        // Transaction safety:
        // We will execute DB updates directly but we must be careful with in-memory state.
        // It's safer to process one by one in a loop that simulates standard taking.

        // Note: Direct manipulation of mail is risky. We should check if we can call "TakeMoney" and "TakeItem" methods.
        // But since we are inside a script, let's try to be respectful of core logic.

        // LIMITATION: Use a naive approach that just collects money and returns success message.
        // Implementing full item collection safely without access to core headers/methods for "AutoStoreMailItem" is hard.
        // However, we can try to implement the logic for Money at least, which is the most common use case.

        SQLTransaction trans = CharacterDatabase.BeginTransaction();
        bool changes = false;

        for (Mail* mail : mailCache)
        {
            uint32 mailId = mail->messageID;
            // Collect Money
            if (mail->money > 0)
            {
                // Give money
                player->ModifyMoney(mail->money);
                collectedGold += mail->money;

                // Update DB
                trans->Append("UPDATE mail SET money = 0 WHERE id = {}", mailId);

                // Update in-memory
                // const_cast is ugly but necessary here if we don't have a specific setter
                const_cast<Mail*>(mail)->money = 0;

                changes = true;
            }

            // Collect Items
            // This is complex because of bag space.
            // Simplified logic: If we have space, take it.

            // For now, let's stick to money and maybe simple items if we can access the item list securely.
            // Accessing items inside a Mail object depends on the core version.

            /*
            if (!mail->items.empty())
            {
               // ... item logic would go here ...
            }
            */

            // If mail is now empty (no items, no money, no COD, no text), mark for deletion?
            // Usually we don't delete automatically unless it's a temp mail.
        }

        if (changes)
        {
            CharacterDatabase.CommitTransaction(trans);

            // Send client update
            player->SendMailResult(0, MAIL_SEND, MAIL_OK);

            DCAddon::JsonMessage notification(MODULE, Opcode::SMSG_NOTIFICATION);
            notification.Set("type", "success");

            std::string msg = "Collected " + std::to_string(collectedGold / 10000) + "g";
            notification.Set("message", msg);
            notification.Send(player);
        }
    }

    // -----------------------------------------------------------------------
    // Login spell enrichment pre-push helpers
    // -----------------------------------------------------------------------

    // Mirrors the Lua FNV-1a-style hash used by BuildSpellTooltipContextHash.
    // Keep in sync with DC-QOS/Modules/Tooltips.lua constants:
    //   SEED  = 2166136261, PRIME = 16777619, MOD = 4294967296
    static uint32 MixSpellTooltipContext(uint32 hash, uint32 value)
    {
        uint64 h = (static_cast<uint64>(hash) + value) % 4294967296ULL;
        h = (h * 16777619ULL) % 4294967296ULL;
        return static_cast<uint32>(h);
    }

    // Replicates client-side BuildSpellTooltipContextHash(spellId) at login.
    // activeTalentGroup is 1-indexed on the client (GetActiveTalentGroup returns 1 or 2).
        static uint32 BuildSpellTooltipContextHashForPlayer(uint32 spellId,
                                                            uint8 level,
                                                            uint8 classId,
                                                            uint8 shapeshiftForm,
                                                            uint8 activeTalentGroup)
    {
        uint32 hash = 2166136261U;
        hash = MixSpellTooltipContext(hash, spellId);
        hash = MixSpellTooltipContext(hash, level);
        hash = MixSpellTooltipContext(hash, classId);
            hash = MixSpellTooltipContext(hash, shapeshiftForm);
        hash = MixSpellTooltipContext(hash, activeTalentGroup);
        if (hash == 0) hash = 1;
        return hash;
    }

    // Push enrichment data for spells the player is likely to hover soon.
    // Scope "actionbar" (default) covers the current spec's action bars only;
    // "full" pushes every active, non-passive spell in the spellbook. The
    // client caches entries for ~3 minutes, so the full-spellbook push mostly
    // expires unused -- action bars cover first-hover for a fraction of the bytes.
    // Uses requestId=0 as the server-push sentinel (no pending client request to resolve).
    static void PushAllSpellEnrichments(Player* player)
    {
        if (!player || !player->IsInWorld())
            return;

        QoSSettings settings = GetPlayerSettingsCached(player);
        if (!settings.tooltipsEnabled)
            return;

        bool includeFamilyMetadata = settings.showSpellFamilyMetadata;

        bool actionBarScope = sConfigMgr->GetOption<std::string>(
            "DC.QoS.TooltipEnrichment.PreWarmScope", "actionbar") != "full";
        std::set<uint32> actionBarSpells;
        if (actionBarScope)
            for (uint16 button = 0; button < MAX_ACTION_BUTTONS; ++button)
                if (ActionButton const* actionButton = player->GetActionButton(static_cast<uint8>(button)))
                    if (actionButton->GetType() == ACTION_BUTTON_SPELL && actionButton->GetAction())
                        actionBarSpells.insert(actionButton->GetAction());

        uint8 level            = static_cast<uint8>(player->GetLevel());
        uint8 classId          = static_cast<uint8>(player->getClass());
        uint8 shapeshiftForm   = static_cast<uint8>(player->GetShapeshiftForm());
        // Client GetActiveTalentGroup() is 1-indexed; server GetActiveSpec() is 0-indexed.
        uint8 activeTalentGroup = static_cast<uint8>(player->GetActiveSpec() + 1);

        uint32 pushed = 0;
        for (auto const& [spellId, spellState] : player->GetSpellMap())
        {
            if (!spellState || spellState->State == PLAYERSPELL_REMOVED || !spellState->Active)
                continue;

            if (actionBarScope && actionBarSpells.find(spellId) == actionBarSpells.end())
                continue;

            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (!spellInfo || spellInfo->IsPassive())
                continue;

            uint32 contextHash = BuildSpellTooltipContextHashForPlayer(spellId,
                level, classId, shapeshiftForm, activeTalentGroup);

            std::string line = GetOrBuildSpellTooltipLine(player, spellId, contextHash, spellInfo);
            if (line.empty())
                continue;

            // requestId=0 → server-initiated push; client caches without requiring a pending entry.
            SendSpellTooltipEnrichment(player, 0, spellId, contextHash, 0, line, "", spellInfo, includeFamilyMetadata);
            ++pushed;
        }

        LOG_DEBUG("module.dc", "DCQoS: Pre-pushed {} spell enrichments to player '{}'", pushed, player->GetName());
    }

}  // namespace DCQoS

// ============================================================================
// REGISTER HANDLERS
// ============================================================================

// Delayed event: fires 3 s after login to give the DC-QOS addon time to
// connect and register its protocol handlers before we flood it with data.
class DCQoS_SpellEnrichmentPushEvent : public BasicEvent
{
public:
    explicit DCQoS_SpellEnrichmentPushEvent(ObjectGuid guid) : _guid(guid) {}

    bool Execute(uint64 /*e_time*/, uint32 /*p_time*/) override
    {
        if (Player* player = ObjectAccessor::FindConnectedPlayer(_guid))
            DCQoS::PushAllSpellEnrichments(player);
        return true; // consumed – do not repeat
    }

private:
    ObjectGuid _guid;
};

class DCQoSPlayerScript : public PlayerScript
{
public:
    DCQoSPlayerScript() : PlayerScript("DCQoSPlayerScript") {}

    void OnPlayerLogin(Player* player) override
    {
        if (!DCQoS::IsEnabled() || !player)
            return;

        // Pre-push spell enrichment data so first-hover tooltips are instant.
        // Delayed 3 s to let the addon initialize and open its protocol channel.
        // Scope is controlled by DC.QoS.TooltipEnrichment.PreWarmScope
        // ("actionbar" default, "full" for the whole spellbook). Admins can
        // disable it entirely: clients then fetch enrichment lazily on first
        // hover via the deduped on-demand path, trading a brief first-hover
        // delay for a large drop in login volume.
        if (sConfigMgr->GetOption<bool>("DC.QoS.TooltipEnrichment.PreWarmPush", true))
        {
            player->m_Events.AddEvent(
                new DCQoS_SpellEnrichmentPushEvent(player->GetGUID()),
                player->m_Events.CalculateTime(3000)
            );
        }

        player->m_Events.AddEventAtOffset([guid = player->GetGUID()]
        {
            if (Player* online = ObjectAccessor::FindConnectedPlayer(guid))
            {
                DCQoS::PushRuntimeProfile(online, true, "login");
                DCQoS::ScheduleRuntimeProfileStateInvalidation(online,
                    "login");
                DCQoS::SchedulePingRelayStateInvalidation(online, "login");
                DCQoS::SchedulePingRelayStateInvalidationForGroup(
                    online->GetGroup(), "group-login",
                    std::chrono::milliseconds(250), online->GetGUID());
            }
        }, std::chrono::milliseconds(4500));
    }

    void OnPlayerMapChanged(Player* player) override
    {
        if (!DCQoS::IsEnabled() || !player)
            return;

        player->m_Events.AddEventAtOffset([guid = player->GetGUID()]
        {
            if (Player* online = ObjectAccessor::FindConnectedPlayer(guid))
            {
                DCQoS::PushRuntimeProfile(online, false, "map-change");
                DCQoS::ScheduleRuntimeProfileStateInvalidation(online,
                    "map-change");
            }
        }, std::chrono::milliseconds(1250));
    }

    void OnPlayerUpdateZone(Player* player, uint32 /*newZone*/,
        uint32 /*newArea*/) override
    {
        if (!DCQoS::IsEnabled() || !player)
            return;

        DCQoS::ScheduleRuntimeProfileStateInvalidation(player,
            "zone-change", std::chrono::milliseconds(350));
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!player)
            return;

        DCQoS::SchedulePingRelayStateInvalidationForGroup(player->GetGroup(),
            "group-logout", std::chrono::milliseconds(250),
            player->GetGUID());

        DCQoS::InvalidatePlayerSettingsCache(player->GetGUID().GetCounter());

        std::lock_guard<std::mutex> lock(DCQoS::s_RuntimeProfileMutex);
        DCQoS::s_LastRuntimeProfileByGuid.erase(
            player->GetGUID().GetCounter());
    }
};

class DCQoSGroupScript : public GroupScript
{
public:
    DCQoSGroupScript() : GroupScript("DCQoSGroupScript") {}

    void OnAddMember(Group* group, ObjectGuid /*guid*/) override
    {
        if (!DCQoS::IsEnabled() || !group)
            return;

        DCQoS::ScheduleRuntimeProfileStateInvalidationForGroup(group,
            "group-add");
        DCQoS::SchedulePingRelayStateInvalidationForGroup(group,
            "group-add");
    }

    void OnRemoveMember(Group* group, ObjectGuid guid,
        RemoveMethod /*method*/, ObjectGuid /*kicker*/, char const* /*reason*/)
        override
    {
        if (!DCQoS::IsEnabled())
            return;

        DCQoS::ScheduleRuntimeProfileStateInvalidationForGroup(group,
            "group-remove");
        DCQoS::ScheduleRuntimeProfileStateInvalidation(guid,
            "group-remove:self");
        DCQoS::SchedulePingRelayStateInvalidationForGroup(group,
            "group-remove");
        DCQoS::SchedulePingRelayStateInvalidation(guid,
            "group-remove:self");
    }

    void OnDisband(Group* group) override
    {
        if (!DCQoS::IsEnabled() || !group)
            return;

        DCQoS::ScheduleRuntimeProfileStateInvalidationForGroup(group,
            "group-disband");
        DCQoS::SchedulePingRelayStateInvalidationForGroup(group,
            "group-disband");
    }

    void OnConvertToRaid(Group* group) override
    {
        if (!DCQoS::IsEnabled() || !group)
            return;

        DCQoS::ScheduleRuntimeProfileStateInvalidationForGroup(group,
            "group-convert-raid");
        DCQoS::SchedulePingRelayStateInvalidationForGroup(group,
            "group-convert-raid");
    }

    void OnChangeMemberSubGroup(Group* group, ObjectGuid /*guid*/,
        uint8 previousSubGroup, uint8 newSubGroup) override
    {
        if (!DCQoS::IsEnabled() || !group)
            return;

        std::string context = "group-subgroup:"
            + std::to_string(previousSubGroup) + "-"
            + std::to_string(newSubGroup);
        DCQoS::SchedulePingRelayStateInvalidationForGroup(group, context);
    }
};

class DCQoSServerScript : public ServerScript
{
public:
    DCQoSServerScript()
        : ServerScript("DCQoSServerScript",
            { SERVERHOOK_CAN_PACKET_RECEIVE })
    {
    }

private:
    bool CanPacketReceive(WorldSession* session,
        WorldPacket const& packet) override
    {
        uint16 opcode = packet.GetOpcode();
        if (opcode != DCQoS::BridgeOpcode::CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT &&
            opcode != DCQoS::BridgeOpcode::CMSG_REQUEST_ITEM_TOOLTIP_SNAPSHOT &&
            opcode != DCQoS::BridgeOpcode::CMSG_REQUEST_ITEM_UPGRADE_TOOLTIP &&
            opcode != DCQoS::BridgeOpcode::CMSG_REQUEST_NPC_TOOLTIP_INFO &&
            opcode != DCQoS::BridgeOpcode::CMSG_REQUEST_PING_RELAY)
            return true;

        if (!session)
            return false;

        Player* player = session->GetPlayer();
        if (!player || !player->IsInWorld())
            return false;

        if (opcode == DCQoS::BridgeOpcode::CMSG_REQUEST_ITEM_TOOLTIP_SNAPSHOT)
        {
            uint32 requestId = 0;
            uint32 itemGuidLow = 0;
            uint32 knownRevision = 0;
            uint32 itemEntry = 0;
            uint32 contextHash = 0;
            uint32 ownerGuidLow = 0;
            uint8 contextKind = 0;
            uint8 bag = 0;
            uint8 slot = 0;
            uint8 flags = 0;
            bool parseOk = true;

            if (packet.size() >= (sizeof(uint32) * 6 + sizeof(uint8) * 4))
            {
                WorldPacket nativePacket(packet);
                nativePacket.rpos(0);

                try
                {
                    nativePacket >> requestId;
                    nativePacket >> itemGuidLow;
                    nativePacket >> knownRevision;
                    nativePacket >> itemEntry;
                    nativePacket >> contextHash;
                    nativePacket >> ownerGuidLow;
                    nativePacket >> contextKind;
                    nativePacket >> bag;
                    nativePacket >> slot;
                    nativePacket >> flags;
                }
                catch (ByteBufferException const&)
                {
                    parseOk = false;
                    requestId = 0;
                    itemGuidLow = 0;
                    knownRevision = 0;
                    itemEntry = 0;
                    contextHash = 0;
                    ownerGuidLow = 0;
                    contextKind = 0;
                    bag = 0;
                    slot = 0;
                    flags = 0;
                }
            }
            else
            {
                parseOk = false;
            }

            std::string preview = "req="
                + std::to_string(requestId)
                + "|guid=" + std::to_string(itemGuidLow)
                + "|rev=" + std::to_string(knownRevision)
                + "|owner=" + std::to_string(ownerGuidLow)
                + "|ctx=" + std::to_string(contextKind)
                + "|bag=" + std::to_string(bag)
                + "|slot=" + std::to_string(slot);
            DCQoS::HandleItemTooltipSnapshotNativeRequest(player,
                requestId, itemGuidLow, knownRevision, itemEntry,
                contextHash, ownerGuidLow, contextKind, bag, slot, flags);
            DCAddon::AuditNativeC2SRequest(player, DCQoS::MODULE,
                DCQoS::Opcode::CMSG_GET_ITEM_INFO,
                DCQoS::BridgeOpcode::CMSG_REQUEST_ITEM_TOOLTIP_SNAPSHOT,
                packet.size(), preview, true, "",
                parseOk ? "" : "native_bad_format",
                parseOk ? ""
                    : "Malformed native item tooltip snapshot request");
            return false;
        }

        if (opcode == DCQoS::BridgeOpcode::CMSG_REQUEST_ITEM_UPGRADE_TOOLTIP)
        {
            uint32 bag = 0;
            uint32 slot = 0;
            bool parseOk = true;

            if (packet.size() >= sizeof(uint32) * 2)
            {
                WorldPacket nativePacket(packet);
                nativePacket.rpos(0);

                try
                {
                    nativePacket >> bag;
                    nativePacket >> slot;
                }
                catch (ByteBufferException const&)
                {
                    parseOk = false;
                    bag = 0;
                    slot = 0;
                }
            }

            std::string preview = "bag=" + std::to_string(bag)
                + "|slot=" + std::to_string(slot);
            DCQoS::HandleItemUpgradeTooltipNativeRequest(player,
                static_cast<uint8>(bag), static_cast<uint8>(slot));
            DCAddon::AuditNativeC2SRequest(player, DCQoS::MODULE,
                DCQoS::Opcode::CMSG_GET_ITEM_INFO,
                DCQoS::BridgeOpcode::CMSG_REQUEST_ITEM_UPGRADE_TOOLTIP,
                packet.size(), preview, true, "",
                parseOk ? "" : "native_bad_format",
                parseOk ? "" : "Malformed native item-upgrade tooltip request");
            return false;
        }

        if (opcode == DCQoS::BridgeOpcode::CMSG_REQUEST_NPC_TOOLTIP_INFO)
        {
            std::string guidStr;
            bool parseOk = true;

            if (packet.size() > 0)
            {
                WorldPacket nativePacket(packet);
                nativePacket.rpos(0);

                try
                {
                    nativePacket >> guidStr;
                }
                catch (ByteBufferException const&)
                {
                    parseOk = false;
                    guidStr.clear();
                }
            }

            std::string preview = "guid=" + guidStr;
            DCQoS::HandleNpcTooltipInfoNativeRequest(player, guidStr);
            DCAddon::AuditNativeC2SRequest(player, DCQoS::MODULE,
                DCQoS::Opcode::CMSG_GET_NPC_INFO,
                DCQoS::BridgeOpcode::CMSG_REQUEST_NPC_TOOLTIP_INFO,
                packet.size(), preview, true, "",
                parseOk ? "" : "native_bad_format",
                parseOk ? "" : "Malformed native NPC tooltip request");
            return false;
        }

        if (opcode == DCQoS::BridgeOpcode::CMSG_REQUEST_PING_RELAY)
        {
            std::string distribution;
            std::string payload;
            bool parseOk = true;

            if (packet.size() > 0)
            {
                WorldPacket nativePacket(packet);
                nativePacket.rpos(0);

                try
                {
                    nativePacket >> distribution;
                    nativePacket >> payload;
                }
                catch (ByteBufferException const&)
                {
                    parseOk = false;
                    distribution.clear();
                    payload.clear();
                }
            }

            std::string preview = "distribution=" + distribution
                + "|bytes=" + std::to_string(payload.size());
            DCQoS::HandlePingRelayNativeRequest(player, distribution,
                payload);
            DCAddon::AuditNativeC2SRequest(player, DCQoS::MODULE, 0,
                DCQoS::BridgeOpcode::CMSG_REQUEST_PING_RELAY, packet.size(),
                preview, true, "",
                parseOk ? "" : "native_bad_format",
                parseOk ? "" : "Malformed native ping relay request");
            return false;
        }

        uint32 requestId = 0;
        uint32 spellId = 0;
        uint32 contextHash = 0;
        bool parseOk = true;

        if (packet.size() >= sizeof(uint32) * 3)
        {
            WorldPacket nativePacket(packet);
            nativePacket.rpos(0);

            try
            {
                nativePacket >> requestId;
                nativePacket >> spellId;
                nativePacket >> contextHash;
            }
            catch (ByteBufferException const&)
            {
                parseOk = false;
                requestId = 0;
                spellId = 0;
                contextHash = 0;
            }
        }

        std::string preview = "req=" + std::to_string(requestId)
            + "|spell=" + std::to_string(spellId)
            + "|ctx=" + std::to_string(contextHash);
        DCQoS::HandleSpellTooltipEnrichmentRequest(player, requestId,
            spellId, contextHash, "",
            DCQoS::SpellTooltipTransportPreference::ForceNativeBridge);
        DCAddon::AuditNativeC2SRequest(player, DCQoS::MODULE,
            DCQoS::Opcode::CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT,
            DCQoS::BridgeOpcode::CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT,
            packet.size(), preview, true, "",
            parseOk ? "" : "native_bad_format",
            parseOk ? "" : "Malformed native spell-tooltip request");
        return false;
    }
};

// Message handler registration - called from dc_addon_protocol.cpp
namespace DCAddon
{
    void RegisterQoSHandlers()
    {
        using namespace DCQoS;

        // Register module "QOS" handlers
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_SYNC_SETTINGS, HandleSyncSettings);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_UPDATE_SETTING, HandleUpdateSetting);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_GET_ITEM_INFO, HandleGetItemInfo);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_GET_NPC_INFO, HandleGetNpcInfo);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_GET_SPELL_INFO, HandleGetSpellInfo);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_REQUEST_FEATURE, HandleRequestFeature);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_COLLECT_ALL_MAIL, HandleCollectAllMail);
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT, HandleRequestSpellTooltipEnrichment);
    }
}

void AddDCQoSScripts()
{
    DCAddon::RegisterQoSHandlers();

    auto& router = DCAddon::MessageRouter::Instance();
    bool hasTooltipHandler = router.HasHandler(DCQoS::MODULE, DCQoS::Opcode::CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT);

    if (hasTooltipHandler)
    {
        LOG_INFO(
            "module.dc",
            "DCQoS handler registration verified (module={}, opcode=0x{:02X})",
            DCQoS::MODULE,
            DCQoS::Opcode::CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT);
    }
    else
    {
        LOG_ERROR(
            "module.dc",
            "DCQoS handler registration missing (module={}, opcode=0x{:02X})",
            DCQoS::MODULE,
            DCQoS::Opcode::CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT);
    }

    new DCQoSPlayerScript();
    new DCQoSGroupScript();
    new DCQoSServerScript();
}
