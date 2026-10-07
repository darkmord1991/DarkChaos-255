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
#include "RaceMgr.h"
#include "DC/AddonExtension/dc_addon_spell_template.h"
#include "DC/ItemUpgrades/HeirloomItemLevel.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "DC/ItemUpgrades/ItemUpgradeProcScaling.h"
#include "DC/ItemUpgrades/ItemUpgradeUIHelpers.h"
#include "DC/QOL/dc_item_cache_prime.h"
#include "Timer.h"
#include <atomic>
#include <chrono>
#include <memory>
#include <string>
#include <string_view>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <array>
#include <cctype>
#include <cmath>
#include <cstdlib>
#include <set>
#include <mutex>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include "Mail.h"
#include "TradeData.h"

namespace DCQoS
{
    // Module identifier - must match client-side Protocol.lua
    constexpr char const* MODULE = "QOS";

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
        constexpr uint8 CMSG_PREFETCH_ITEMS     = 0x09;  // {"ids":[entry,...]}: push their item cache records

        // Server -> Client
        constexpr uint8 SMSG_SETTINGS_SYNC      = 0x10;  // Full settings sync
        constexpr uint8 SMSG_SETTING_UPDATED    = 0x11;  // Confirmation of setting update
        constexpr uint8 SMSG_ITEM_INFO          = 0x12;  // Custom item information
        constexpr uint8 SMSG_NPC_INFO           = 0x13;  // Custom NPC information
        constexpr uint8 SMSG_SPELL_INFO         = 0x14;  // Custom spell information
        constexpr uint8 SMSG_FEATURE_DATA       = 0x15;  // Feature-specific data
        constexpr uint8 SMSG_NOTIFICATION       = 0x16;  // Server notification
        constexpr uint8 SMSG_SPELL_TOOLTIP_ENRICHMENT = 0x17;  // requestId|spellId|contextHash|status|line
        constexpr uint8 SMSG_PREFETCH_ITEMS_RESULT = 0x18;  // {"ids","sent","missing"} or {"ids","throttled"}
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
        ObjectGuid const& guid, uint32& spawnId);
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

        // Same reasoning as ScheduleFeatureInvalidation: bots have no client
        // to apply a runtime graphics profile to.
        if (DCAddon::IsBotRecipient(player))
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
        constexpr char const* ENABLED = "DC.AddonProtocol.QoS.Enable";
        constexpr char const* TOOLTIP_TRANSPORT_DEBUG =
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

    // One entry caches both halves of an enrichment response under a single
    // expiry: the flat `line`, and the structured v2 `lines[]` payload. The two
    // are filled by separate calls, so each carries its own validity flag
    // rather than relying on the order they happen to be requested in.
    struct SpellTooltipLineCacheEntry
    {
        std::string line;
        bool hasLine = false;

        // Shared so a cache hit costs a refcount bump: the JsonValue tree is a
        // vector of objects, each holding a std::map of strings.
        std::shared_ptr<DCAddon::JsonValue const> lines;
        bool linesFamilyMetadata = false;

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
        // Mirrors TransportPolicyDecision: only the capability bits and the
        // version flag are ever read (see the audit log below), so this holds
        // the slim summary rather than a copy of the whole session state.
        DCAddon::TransportCapabilitySummary capabilityState;
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
        // int32, not uint8: WotLKExtensions r18+ reads GetInt32. Older DLLs read
        // int8, misparse and reject every reply -- which keeps them from
        // drawing their duplicate "Server: ..." row, so do not "fix" this.
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
    // valueMultiplier scales the magnitude tokens ($s/$m/$M/$b/$o and ${} results)
    // so an item-upgrade proc prints the value it actually deals. 1.0f = verbatim.
    // colorizeValues wraps substituted values in white (|cffffffff...|r). That is
    // the look the SPELL tooltip enrichment wants, and wrong inside an item
    // tooltip: stock draws Equip:/Use: sentences in one uniform green, so a white
    // "2576" next to a green "322" on the line above reads as a rendering bug.
    static std::string RenderSpellDescriptionTemplate(Player* player,
        SpellInfo const* spellInfo, std::string const& sourceTemplate,
        float valueMultiplier = 1.0f, bool colorizeValues = true);

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

    // Mirrors the stock client: the "Classes:" line is shown only when some playable
    // class is EXCLUDED. Comparing the mask for equality with CLASSMASK_ALL_PLAYABLE
    // missed every item whose mask has extra bits -- Blackhorn Bludgeon carries 0x7FFF
    // (bit 10 = a class that does not exist in 3.3.5), which printed all ten classes
    // plus "Class 10" on one unwrapped line and stretched the tooltip across the screen.
    static bool BuildAllowableClassText(uint32 allowableClass,
        std::string& outText)
    {
        if (allowableClass == 0
            || (allowableClass & CLASSMASK_ALL_PLAYABLE) == CLASSMASK_ALL_PLAYABLE)
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

            // Only classes a player can be: a mask bit with no playable class
            // behind it restricts nobody and has nothing to be named.
            if ((CLASSMASK_ALL_PLAYABLE & classMask) == 0)
                continue;

            ChrClassesEntry const* classEntry =
                sChrClassesStore.LookupEntry(classId);
            if (!classEntry || !classEntry->name[0] || !*classEntry->name[0])
                continue;

            if (foundAny)
                text << ", ";

            text << classEntry->name[0];
            foundAny = true;
        }

        if (!foundAny)
            return false;

        outText = text.str();
        return true;
    }

    // Same rule as the class line, against the server's playable races (RaceMgr,
    // which includes the DC custom races) rather than the stock eleven.
    static bool BuildAllowableRaceText(uint32 allowableRace,
        std::string& outText)
    {
        if (allowableRace == 0 || allowableRace == uint32(-1))
            return false;

        uint32 const playableRaces = RaceMgr::GetPlayableRaceMask();
        if (playableRaces != 0 && (allowableRace & playableRaces) == playableRaces)
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

            if (playableRaces != 0 && (playableRaces & raceMask) == 0)
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

    // The stock tooltip draws only the primary stats (and flat mana/health) as
    // white "+N Stat" lines. Ratings, attack/spell power, regen, penetration and
    // block value are drawn further down as green "Equip: ..." sentences, in with
    // the item's spell lines. Returns nullptr for the white ones. Wording follows
    // the 3.3.5 ITEM_MOD_* global strings.
    static char const* GetEquipStatSentence(uint32 statType)
    {
        switch (statType)
        {
            case ITEM_MOD_DEFENSE_SKILL_RATING:
                return "Increases defense rating by {}.";
            case ITEM_MOD_DODGE_RATING:
                return "Increases your dodge rating by {}.";
            case ITEM_MOD_PARRY_RATING:
                return "Increases your parry rating by {}.";
            case ITEM_MOD_BLOCK_RATING:
                return "Increases your shield block rating by {}.";
            case ITEM_MOD_HIT_MELEE_RATING:
                return "Improves melee hit rating by {}.";
            case ITEM_MOD_HIT_RANGED_RATING:
                return "Improves ranged hit rating by {}.";
            case ITEM_MOD_HIT_SPELL_RATING:
                return "Improves spell hit rating by {}.";
            case ITEM_MOD_CRIT_MELEE_RATING:
                return "Improves melee critical strike rating by {}.";
            case ITEM_MOD_CRIT_RANGED_RATING:
                return "Improves ranged critical strike rating by {}.";
            case ITEM_MOD_CRIT_SPELL_RATING:
                return "Improves spell critical strike rating by {}.";
            case ITEM_MOD_HASTE_MELEE_RATING:
                return "Improves melee haste rating by {}.";
            case ITEM_MOD_HASTE_RANGED_RATING:
                return "Improves ranged haste rating by {}.";
            case ITEM_MOD_HASTE_SPELL_RATING:
                return "Improves spell haste rating by {}.";
            case ITEM_MOD_HIT_RATING:
                return "Improves hit rating by {}.";
            case ITEM_MOD_CRIT_RATING:
                return "Improves critical strike rating by {}.";
            case ITEM_MOD_RESILIENCE_RATING:
                return "Improves your resilience rating by {}.";
            case ITEM_MOD_HASTE_RATING:
                return "Improves haste rating by {}.";
            case ITEM_MOD_EXPERTISE_RATING:
                return "Increases your expertise rating by {}.";
            case ITEM_MOD_ATTACK_POWER:
                return "Increases attack power by {}.";
            case ITEM_MOD_RANGED_ATTACK_POWER:
                return "Increases ranged attack power by {}.";
            case ITEM_MOD_MANA_REGENERATION:
                return "Restores {} mana per 5 sec.";
            case ITEM_MOD_ARMOR_PENETRATION_RATING:
                return "Increases your armor penetration rating by {}.";
            case ITEM_MOD_SPELL_POWER:
                return "Increases spell power by {}.";
            case ITEM_MOD_HEALTH_REGEN:
                return "Restores {} health per 5 sec.";
            case ITEM_MOD_SPELL_PENETRATION:
                return "Increases spell penetration by {}.";
            case ITEM_MOD_BLOCK_VALUE:
                return "Increases the block value of your shield by {}.";
            default:
                return nullptr;
        }
    }

    static std::string FormatEquipItemStat(int32 value, uint32 statType)
    {
        char const* sentence = GetEquipStatSentence(statType);
        if (!sentence || value == 0)
            return "";

        std::string text = sentence;
        std::size_t const placeholder = text.find("{}");
        if (placeholder != std::string::npos)
            text.replace(placeholder, 2, std::to_string(value));

        return "Equip: " + text;
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

    // The stock client draws a socketed gem as the gem's STAT text ("+16 Agility"),
    // not as the gem's item name. Returning the name lost the stats entirely once
    // the native path took over rendering, so prefer the enchant description and
    // keep the item name only as a fallback for gems whose row has no description.
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

        if (enchant->description[0] && *enchant->description[0])
            return enchant->description[0];

        if (ItemTemplate const* gemTemplate =
                sObjectMgr->GetItemTemplate(enchant->GemID))
        {
            return gemTemplate->Name1;
        }

        return "";
    }

    // Mirrors Player::ApplyEnchantment's ITEM_ENCHANTMENT_TYPE_STAT branch: the
    // enchant row's own amount wins, and a zero amount means the magnitude comes
    // from the item's random-suffix allocation scaled by its suffix factor.
    static uint32 ResolveEnchantmentStatAmount(Item* item,
        SpellItemEnchantmentEntry const* enchant, uint32 effectIndex)
    {
        if (!enchant)
            return 0;

        uint32 amount = enchant->amount[effectIndex];
        if (amount != 0 || !item)
            return amount;

        ItemRandomSuffixEntry const* suffix = sItemRandomSuffixStore.LookupEntry(
            static_cast<uint32>(std::abs(item->GetItemRandomPropertyId())));
        if (!suffix)
            return 0;

        for (uint32 k = 0; k < MAX_ITEM_ENCHANTMENT_EFFECTS; ++k)
        {
            if (suffix->Enchantment[k] != enchant->ID)
                continue;

            return uint32((suffix->AllocationPct[k]
                * item->GetItemSuffixFactor()) / 10000);
        }

        return 0;
    }

    // One line per enchantment, the way the stock client draws it: the enchant's own
    // description when it has one, otherwise the stat lines it grants. Random
    // suffixes land in the second case -- their DBC rows carry no description and
    // their magnitude only exists once the item's suffix factor is applied.
    //
    // These are deliberately NOT scaled by the upgrade multiplier. The DC stat hooks
    // only touch _ApplyItemMods values sourced from item_template, and nothing
    // implements OnPlayerApplyEnchantmentItemModsBefore, so enchant stats are
    // applied verbatim at runtime and have to be printed verbatim here.
    static void AppendEnchantmentTooltipRows(
        std::vector<ItemTooltipSnapshotRow>& rows, Item* item, uint32 enchantId,
        char const* classification)
    {
        if (!enchantId)
            return;

        SpellItemEnchantmentEntry const* enchant =
            sSpellItemEnchantmentStore.LookupEntry(enchantId);
        if (!enchant)
            return;

        if (enchant->description[0] && *enchant->description[0])
        {
            AppendItemTooltipSnapshotRow(rows, enchant->description[0], "",
                "append-body", classification);
            return;
        }

        for (uint32 effectIndex = 0;
             effectIndex < MAX_SPELL_ITEM_ENCHANTMENT_EFFECTS; ++effectIndex)
        {
            if (enchant->type[effectIndex] != ITEM_ENCHANTMENT_TYPE_STAT)
                continue;

            uint32 const amount =
                ResolveEnchantmentStatAmount(item, enchant, effectIndex);
            if (amount == 0)
                continue;

            char const* label = GetItemStatLabel(enchant->spellid[effectIndex]);
            if (!label)
                continue;

            std::string line =
                FormatSignedItemStat(static_cast<int32>(amount), label);
            if (!line.empty())
                AppendItemTooltipSnapshotRow(rows, line, "", "append-body",
                    classification);
        }
    }

    // Rounds exactly like the runtime hooks (lround of value * multiplier).
    static uint32 ScaleEnchantAmount(uint32 amount, double multiplier)
    {
        if (amount == 0 || multiplier <= 1.0)
            return amount;

        return static_cast<uint32>(std::max<int64>(0, static_cast<int64>(
            std::lround(static_cast<double>(amount) * multiplier))));
    }

    // Scales every "+<number>" in an enchant description. Only the '+'-prefixed
    // numbers: "+8 mana every 5 sec." must not turn into "every 9 sec.".
    static std::string ScalePlusNumbersInText(std::string const& text, double multiplier)
    {
        if (multiplier <= 1.0)
            return text;

        std::string scaled;
        scaled.reserve(text.size() + 8);

        std::size_t i = 0;
        while (i < text.size())
        {
            if (text[i] == '+' && i + 1 < text.size()
                && std::isdigit(static_cast<unsigned char>(text[i + 1])))
            {
                std::size_t end = i + 1;
                while (end < text.size() && (end - i) <= 9
                    && std::isdigit(static_cast<unsigned char>(text[end])))
                {
                    ++end;
                }

                uint32 const value = static_cast<uint32>(
                    std::stoul(text.substr(i + 1, end - (i + 1))));
                scaled.push_back('+');
                scaled += std::to_string(ScaleEnchantAmount(value, multiplier));
                i = end;
                continue;
            }

            scaled.push_back(text[i]);
            ++i;
        }

        return scaled;
    }

    // The lines an item's random-enchant slots contribute, at `multiplier`.
    //
    // Upgrades scale what was rolled INTO the item (these slots) and leave alone what
    // the player added (permanent enchant, gems). How a line is produced follows what
    // the runtime can actually scale, so the text never promises more than is applied:
    //
    //   all effects STAT        -> generated "+N Stat" lines, N scaled
    //                              (ItemUpgradeStatApplication's enchant hook)
    //   all effects EQUIP_SPELL -> the description with its "+N" scaled, but only if
    //     with a scalable aura     every spell is one ItemUpgradeProcScaling scales
    //   anything else           -> the description verbatim (weapon-damage and
    //                              resistance enchants have no hook; mixed rows are
    //                              rare enough to under-state rather than guess)
    // The lines one random-enchant slot (PROP_ENCHANTMENT_SLOT_0 + propIndex) grants, by the
    // rules above. Empty for an empty slot.
    static std::vector<std::string> BuildRandomEnchantSlotLines(Item* item, uint32 propIndex,
        double multiplier)
    {
        std::vector<std::string> lines;
        if (!item || propIndex >= MAX_ITEM_ENCHANTMENT_EFFECTS)
            return lines;

        SpellItemEnchantmentEntry const* enchant = sSpellItemEnchantmentStore.LookupEntry(
            item->GetEnchantmentId(EnchantmentSlot(PROP_ENCHANTMENT_SLOT_0 + propIndex)));
        if (!enchant)
            return lines;

        uint32 statEffects = 0;
        uint32 scalableSpellEffects = 0;
        uint32 otherEffects = 0;
        for (uint32 i = 0; i < MAX_SPELL_ITEM_ENCHANTMENT_EFFECTS; ++i)
        {
            switch (enchant->type[i])
            {
                case ITEM_ENCHANTMENT_TYPE_NONE:
                    break;
                case ITEM_ENCHANTMENT_TYPE_STAT:
                    ++statEffects;
                    break;
                case ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL:
                    if (DarkChaos::ItemUpgrade::IsUpgradeScaledEquipSpell(enchant->spellid[i]))
                        ++scalableSpellEffects;
                    else
                        ++otherEffects;
                    break;
                default:
                    ++otherEffects;
                    break;
            }
        }

        bool const hasDescription = enchant->description[0] && *enchant->description[0];

        if (statEffects > 0 && scalableSpellEffects == 0 && otherEffects == 0)
        {
            for (uint32 i = 0; i < MAX_SPELL_ITEM_ENCHANTMENT_EFFECTS; ++i)
            {
                if (enchant->type[i] != ITEM_ENCHANTMENT_TYPE_STAT)
                    continue;

                uint32 const amount = ScaleEnchantAmount(
                    ResolveEnchantmentStatAmount(item, enchant, i), multiplier);
                char const* label = GetItemStatLabel(enchant->spellid[i]);
                if (amount == 0 || !label)
                    continue;

                std::string line = FormatSignedItemStat(static_cast<int32>(amount), label);
                if (!line.empty())
                    lines.push_back(std::move(line));
            }
            return lines;
        }

        if (!hasDescription)
            return lines;

        bool const descriptionScales =
            scalableSpellEffects > 0 && statEffects == 0 && otherEffects == 0;
        lines.push_back(descriptionScales
            ? ScalePlusNumbersInText(enchant->description[0], multiplier)
            : std::string(enchant->description[0]));
        return lines;
    }

    static std::vector<std::string> BuildRandomEnchantLines(Item* item, double multiplier)
    {
        std::vector<std::string> lines;
        if (!item)
            return lines;

        for (uint32 propIndex = 0; propIndex < MAX_ITEM_ENCHANTMENT_EFFECTS; ++propIndex)
        {
            for (std::string& line : BuildRandomEnchantSlotLines(item, propIndex, multiplier))
                lines.push_back(std::move(line));
        }

        return lines;
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

    // valueMultiplier is the item-upgrade proc multiplier for this spell. Pass 1.0f
    // for spells the proc hooks never touch (item-set bonuses), so their numbers are
    // not inflated by an unrelated equipped upgrade.
    // The spell's description as an item tooltip prints it: tokens resolved, no
    // value colouring, the spell name when the description is empty.
    static std::string BuildItemSpellDescriptionText(Player* player,
        int32 spellId, float valueMultiplier = 1.0f)
    {
        if (spellId <= 0)
            return "";

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(uint32(spellId));
        if (!spellInfo)
            return "";

        std::string rendered = RenderSpellDescriptionTemplate(player,
            spellInfo, GetSpellDescriptionTemplate(uint32(spellId)),
            valueMultiplier, /*colorizeValues=*/false);
        if (rendered.empty() && spellInfo->SpellName[0]
            && *spellInfo->SpellName[0])
        {
            rendered = spellInfo->SpellName[0];
        }

        return rendered;
    }

    static std::string BuildItemSpellTooltipText(Player* player,
        int32 spellId, uint32 trigger, float valueMultiplier = 1.0f)
    {
        std::string rendered =
            BuildItemSpellDescriptionText(player, spellId, valueMultiplier);
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

    // The item-set block in the stock layout (CGTooltip::SetItem, 0x62C972 to
    // 0x62CDA8 in Wow.exe): a blank line; "Name (worn/total)"; the set's required
    // skill, if any; every piece indented, light yellow when worn and grey when
    // not; another blank line; then the bonuses sorted by piece count. An active
    // bonus reads "Set: <text>", an inactive one "(N) Set: <text>". The text is
    // the bare spell description -- stock never prefixes "Equip: " -- and is not
    // scaled: set spells are not item procs, so no upgrade touches them.
    static void AppendItemSetTooltipRows(
        std::vector<ItemTooltipSnapshotRow>& rows, Player* player,
        uint32 itemSetId, ItemSetEntry const* itemSet)
    {
        if (!itemSet)
            return;

        uint32 const equippedPieces =
            CountItemSetPiecesEquipped(player, itemSetId);
        uint32 const totalPieces = CountItemSetPieces(itemSet);

        std::ostringstream setName;
        if (itemSet->name[0] && *itemSet->name[0])
            setName << itemSet->name[0];
        else
            setName << "Item Set";
        setName << " (" << equippedPieces << '/' << totalPieces << ')';

        // Rows with no text are dropped on the client, so a blank line is " ".
        AppendItemTooltipSnapshotRow(rows, " ", "", "append-body", "spacer");
        AppendItemTooltipSnapshotRow(rows, setName.str(), "", "append-body",
            "set-name");

        if (itemSet->required_skill_id != 0 && itemSet->required_skill_value > 0)
        {
            std::ostringstream requirement;
            requirement << "Requires ";

            SkillLineEntry const* skill =
                sSkillLineStore.LookupEntry(itemSet->required_skill_id);
            if (skill && skill->name[0] && *skill->name[0])
                requirement << skill->name[0];
            else
                requirement << "Skill " << itemSet->required_skill_id;

            requirement << " (" << itemSet->required_skill_value << ')';
            AppendItemTooltipSnapshotRow(rows, requirement.str(), "",
                "append-body",
                (!player || player->GetSkillValue(itemSet->required_skill_id)
                        >= itemSet->required_skill_value)
                    ? "requirement"
                    : "requirement-unmet");
        }

        // Which worn item stands in for each listed piece, matched the way the
        // client does it (0x6276E0): first the exact item ids, then any other worn
        // item of this set fills a still-open piece of the same inventory type
        // (chest and robe count as one) and lends it its NAME. DC's upgraded
        // clones (Sanctified 300160-300164) are set 890 without being in its
        // 51742-51746 list; matched by id alone every piece read grey at 5/5.
        std::array<ItemTemplate const*, MAX_ITEM_SET_ITEMS> wornFor{};
        std::array<bool, EQUIPMENT_SLOT_END> slotTaken{};
        auto const sameInventoryType = [](uint32 a, uint32 b)
        {
            return a == b
                || (a == INVTYPE_CHEST && b == INVTYPE_ROBE)
                || (a == INVTYPE_ROBE && b == INVTYPE_CHEST);
        };

        for (uint8 pass = 0; player && pass < 2; ++pass)
        {
            for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END;
                 ++slot)
            {
                Item* worn = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                ItemTemplate const* wornTemplate = worn ? worn->GetTemplate() : nullptr;
                if (slotTaken[slot] || !wornTemplate
                    || wornTemplate->ItemSet != itemSetId)
                {
                    continue;
                }

                for (uint8 index = 0; index < MAX_ITEM_SET_ITEMS; ++index)
                {
                    uint32 const pieceId = itemSet->itemId[index];
                    if (!pieceId || wornFor[index])
                        continue;

                    bool matches = pieceId == wornTemplate->ItemId;
                    if (!matches && pass == 1)
                    {
                        ItemTemplate const* piece =
                            sObjectMgr->GetItemTemplate(pieceId);
                        matches = piece && sameInventoryType(
                            piece->InventoryType, wornTemplate->InventoryType);
                    }

                    if (matches)
                    {
                        wornFor[index] = wornTemplate;
                        slotTaken[slot] = true;
                        break;
                    }
                }
            }
        }

        for (uint8 index = 0; index < MAX_ITEM_SET_ITEMS; ++index)
        {
            uint32 const pieceId = itemSet->itemId[index];
            ItemTemplate const* piece =
                pieceId ? sObjectMgr->GetItemTemplate(pieceId) : nullptr;
            if (!piece)
                continue;

            ItemTemplate const* shown = wornFor[index] ? wornFor[index] : piece;
            AppendItemTooltipSnapshotRow(rows, "  " + shown->Name1, "",
                "append-body",
                wornFor[index] ? "set-piece-equipped" : "set-piece-missing");
        }

        AppendItemTooltipSnapshotRow(rows, " ", "", "append-body", "spacer");

        // Ascending piece count, DBC order on ties -- the client's qsort
        // comparator (0x61A600) orders exactly this way.
        std::array<uint8, MAX_ITEM_SET_SPELLS> order{};
        for (uint8 index = 0; index < MAX_ITEM_SET_SPELLS; ++index)
            order[index] = index;
        std::stable_sort(order.begin(), order.end(),
            [itemSet](uint8 a, uint8 b)
            {
                return itemSet->items_to_triggerspell[a]
                    < itemSet->items_to_triggerspell[b];
            });

        for (uint8 index : order)
        {
            uint32 const spellId = itemSet->spells[index];
            uint32 const threshold = itemSet->items_to_triggerspell[index];
            if (spellId == 0 || threshold == 0)
                continue;

            std::string const text =
                BuildItemSpellDescriptionText(player, int32(spellId));
            if (text.empty())
                continue;

            bool const active = equippedPieces >= threshold;
            std::ostringstream bonus;
            if (!active)
                bonus << '(' << threshold << ") ";
            bonus << "Set: " << text;

            AppendItemTooltipSnapshotRow(rows, bonus.str(), "", "append-body",
                active ? "set-bonus-active" : "set-bonus-inactive");
        }
    }

    // Only the display name lives here now. The STATS a package grants are read
    // from the SpellItemEnchantment row that is actually applied to the item (see
    // AppendHeirloomPackageTooltipRows) rather than recomputed from a parallel
    // table: the old hand-written budget table disagreed with the DBC by 1-3 points
    // at standard levels 5/6/7/9/13, mis-split 3-stat packages, was 4x low for the
    // Frontier (tier 10) range it knew nothing about, and labelled packages 5/6
    // "Spell Crit"/"Spell Haste"/"Spell Hit" when the DBC applies plain
    // Crit/Haste/Hit rating.
    struct HeirloomPackageDefinition
    {
        char const* name;
    };

    struct HeirloomPackageTooltipState
    {
        uint32 packageId = 0;
        uint32 upgradeLevel = 0;
        // The enchant row actually applied to the item; 0 when none was decoded.
        uint32 enchantId = 0;
    };

    static bool TryGetHeirloomPackageDefinition(uint32 packageId,
        HeirloomPackageDefinition& out)
    {
        using namespace DarkChaos::ItemUpgrade::UI;

        static HeirloomPackageDefinition const definitions[
            HEIRLOOM_MAX_PACKAGE_ID + 1] =
        {
            { "" },
            { "Fury" },
            { "Precision" },
            { "Devastation" },
            { "Swiftblade" },
            { "Spellfire" },
            { "Arcane" },
            { "Bulwark" },
            { "Fortress" },
            { "Survivor" },
            { "Gladiator" },
            { "Warlord" },
            { "Balanced" },
        };

        if (packageId == 0 || packageId > HEIRLOOM_MAX_PACKAGE_ID)
            return false;

        out = definitions[packageId];
        return out.name && *out.name;
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
                state.enchantId = enchantId;
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

        // Single source of truth: the enchant row Player::ApplyEnchantment is
        // applying. Anything else is a second model that can drift out of step
        // with the stats the character actually has.
        SpellItemEnchantmentEntry const* enchant = state.enchantId
            ? sSpellItemEnchantmentStore.LookupEntry(state.enchantId)
            : nullptr;

        if (!enchant)
        {
            // No DBC row means ApplyEnchantment granted nothing, so printing any
            // stat line here would invent numbers the player does not have. This
            // is a deployment fault (SpellItemEnchantment.dbc out of date on the
            // server), not a tooltip fault -- say nothing and leave a trace.
            LOG_DEBUG("dc.addon",
                "Heirloom package tooltip: enchant {} (package {}, level {}) has no "
                "SpellItemEnchantment row; no stat rows emitted.",
                state.enchantId, state.packageId, state.upgradeLevel);
            return;
        }

        AppendItemTooltipSnapshotRow(rows, "Package", definition.name,
            "append-body", "set-name");
        AppendItemTooltipSnapshotRow(rows, "-- Package Stats --", "",
            "append-body", "meta");

        for (uint32 effectIndex = 0;
             effectIndex < MAX_SPELL_ITEM_ENCHANTMENT_EFFECTS; ++effectIndex)
        {
            if (enchant->type[effectIndex] != ITEM_ENCHANTMENT_TYPE_STAT)
                continue;

            if (enchant->amount[effectIndex] == 0)
                continue;

            // For ITEM_ENCHANTMENT_TYPE_STAT the DBC's effectArg column (spellid[])
            // carries the ItemModType, and effectPointsMin (amount[]) the value.
            char const* label = GetItemStatLabel(enchant->spellid[effectIndex]);
            if (!label)
                continue;

            std::string line = FormatSignedItemStat(
                static_cast<int32>(enchant->amount[effectIndex]), label);
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

        // A level-scaling (heirloom) item takes its stats, armor and first weapon
        // damage from ScalingStatDistribution / ScalingStatValues at its owner's
        // level; its template only carries placeholders. The rows below mirror
        // Player::_ApplyItemBonuses / _ApplyWeaponDamage for such an item.
        ScalingStatDistributionEntry const* scalingDistribution = nullptr;
        ScalingStatValuesEntry const* scalingValues = nullptr;
        uint32 scalingLevel = 0;
        if (DarkChaos::ItemUpgrade::IsLevelScalingItem(itemTemplate))
        {
            Player const* owner = item->GetOwner();
            if (!owner)
                owner = player;

            scalingLevel = DarkChaos::ItemUpgrade::GetItemScalingLevel(itemTemplate,
                owner ? owner->GetLevel() : 1);
            scalingDistribution = sScalingStatDistributionStore.LookupEntry(
                itemTemplate->ScalingStatDistribution);
            scalingValues =
                DarkChaos::ItemUpgrade::GetScalingStatValuesForLevel(scalingLevel);
        }

        // Emitted unconditionally, with fallbacks, because everything below this
        // point is "append-body" content that the baseline client ALSO draws
        // (sockets, durability, requirements, spells, description, sell price, and
        // the enchant/suffix rows added further down). The DLL only takes over
        // rendering -- and therefore only stops the client drawing its own copy --
        // when it sees at least one "replace-stat" row. Leaving this row out for an
        // upgraded item with no ilvl recorded would double every one of those lines.
        uint32 displayItemLevel = snapshot.upgraded_ilvl;
        if (displayItemLevel == 0)
            displayItemLevel = snapshot.base_ilvl;
        if (displayItemLevel == 0 && itemTemplate)
            displayItemLevel = itemTemplate->ItemLevel;

        // A scaling item's template item level is a placeholder: show what its
        // stats are worth at the owner's level (HeirloomItemLevel.h), plus the item
        // levels its upgrades added.
        if (scalingLevel)
        {
            uint32 const upgradeItemLevels = snapshot.upgraded_ilvl > snapshot.base_ilvl
                ? snapshot.upgraded_ilvl - snapshot.base_ilvl
                : 0;
            displayItemLevel =
                DarkChaos::ItemUpgrade::GetScalingItemLevelForLevel(scalingLevel)
                + upgradeItemLevels;
        }

        // Stock order is: damage, armor/block, white stats, resistances, enchants,
        // sockets, durability, requirements, "Item Level", then the green Equip:
        // lines (rating stats first, item spells after), the set block, flavour
        // text. Rows that belong further down are parked in these and spliced in
        // at the right point below.
        bool itemLevelRowEmitted = false;
        auto emitItemLevelRow = [&]()
        {
            if (itemLevelRowEmitted || displayItemLevel == 0)
                return;

            itemLevelRowEmitted = true;
            AppendItemTooltipSnapshotRow(rows, "Item Level",
                std::to_string(displayItemLevel), "replace-stat",
                "item-level");
        };
        std::vector<ItemTooltipSnapshotRow> equipStatRows;

        if (itemTemplate)
        {
            double scaledDamageSum = 0.0;
            for (uint32 damageIndex = 0;
                 damageIndex < MAX_ITEM_PROTO_DAMAGES; ++damageIndex)
            {
                _Damage const& damage = itemTemplate->Damage[damageIndex];
                float damageMin = damage.DamageMin;
                float damageMax = damage.DamageMax;

                // A scaling weapon's first damage entry is its ScalingStatValues DPS
                // per swing, spread 70-130% (two-hand 80-120%).
                if (scalingValues && damageIndex == 0)
                {
                    if (uint32 const scalingDps =
                            scalingValues->getDPSMod(itemTemplate->ScalingStatValue))
                    {
                        float const average = scalingDps * itemTemplate->Delay / 1000.0f;
                        float const spread =
                            scalingValues->IsTwoHand(itemTemplate->ScalingStatValue) ? 0.2f : 0.3f;
                        damageMin = (1.0f - spread) * average;
                        damageMax = (1.0f + spread) * average;
                    }
                }

                if (damageMax <= 0.0f)
                    continue;

                int32 scaledMin = static_cast<int32>(std::lround(
                    static_cast<double>(damageMin) * multiplier));
                int32 scaledMax = static_cast<int32>(std::lround(
                    static_cast<double>(damageMax) * multiplier));

                std::ostringstream left;
                left << scaledMin << " - " << scaledMax << " Damage";

                std::ostringstream right;
                if (itemTemplate->Delay > 0)
                    right << "Speed " << std::fixed << std::setprecision(2)
                        << (static_cast<double>(itemTemplate->Delay) / 1000.0);

                AppendItemTooltipSnapshotRow(rows, left.str(), right.str(),
                    "replace-stat", "weapon-damage");

                scaledDamageSum += (static_cast<double>(damageMin)
                    + static_cast<double>(damageMax)) * 0.5 * multiplier;
            }

            if (scaledDamageSum > 0.0 && itemTemplate->Delay > 0)
            {
                std::ostringstream dps;
                dps << '(' << std::fixed << std::setprecision(1)
                    << (scaledDamageSum
                        / (static_cast<double>(itemTemplate->Delay) / 1000.0))
                    << " damage per second)";
                AppendItemTooltipSnapshotRow(rows, dps.str(), "",
                    "replace-stat", "weapon-dps");
            }

            // A scaling item's armor comes from the ScalingStatValues armor column
            // its mask selects, when it selects one.
            uint32 armor = itemTemplate->Armor;
            if (uint32 const scalingArmor = scalingValues
                    ? scalingValues->getArmorMod(itemTemplate->ScalingStatValue)
                    : 0)
                armor = scalingArmor;

            if (armor > 0)
            {
                uint32 scaledArmor = static_cast<uint32>(std::max<int64>(0,
                    static_cast<int64>(std::lround(
                        static_cast<double>(armor) * multiplier))));
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

            auto const appendStatRow = [&](uint32 statType, int32 value)
            {
                char const* label = GetItemStatLabel(statType);
                if (!label || value == 0)
                    return;

                std::string equipLine = FormatEquipItemStat(value, statType);
                if (!equipLine.empty())
                {
                    AppendItemTooltipSnapshotRow(equipStatRows, equipLine, "",
                        "replace-stat", "stat-equip");
                    return;
                }

                std::string line = FormatSignedItemStat(value, label);
                if (!line.empty())
                    AppendItemTooltipSnapshotRow(rows, line, "",
                        "replace-stat", "stat");
            };

            auto const scaleStat = [multiplier](int32 value)
            {
                return static_cast<int32>(std::lround(
                    static_cast<double>(value) * multiplier));
            };

            if (scalingDistribution && scalingValues)
            {
                // The distribution names the stats and the budget column the mask
                // selects sizes them. A caster item's spell power comes from the
                // values row too, and the core applies it without the upgrade
                // multiplier.
                uint32 const budget =
                    scalingValues->getssdMultiplier(itemTemplate->ScalingStatValue);
                for (uint32 statIndex = 0; statIndex < MAX_ITEM_PROTO_STATS; ++statIndex)
                {
                    if (scalingDistribution->StatMod[statIndex] < 0)
                        continue;

                    appendStatRow(uint32(scalingDistribution->StatMod[statIndex]),
                        scaleStat(int32(budget * scalingDistribution->Modifier[statIndex] / 10000)));
                }

                appendStatRow(ITEM_MOD_SPELL_POWER,
                    int32(scalingValues->getSpellBonus(itemTemplate->ScalingStatValue)));
            }
            else
            {
                uint32 statCount =
                    std::min<uint32>(itemTemplate->StatsCount, MAX_ITEM_PROTO_STATS);
                for (uint32 statIndex = 0; statIndex < statCount; ++statIndex)
                {
                    _ItemStat const& stat = itemTemplate->ItemStat[statIndex];
                    appendStatRow(stat.ItemStatType, scaleStat(stat.ItemStatValue));
                }
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

            // Random-property / random-suffix stats. These live in enchantment
            // slots, not in item_template, so the stat loop above cannot see them --
            // an upgraded "of the Bear" item used to lose its suffix stats entirely
            // once the native path took over the body.
            // Classified "enchant" rather than "stat": these come from enchantment
            // rows and the baseline client draws them green, like any enchant.
            //
            // Scaled by the item's multiplier: upgrades carry what was rolled into the
            // item, and BuildRandomEnchantLines only scales what the runtime hooks do.
            for (std::string const& enchantLine : BuildRandomEnchantLines(item, multiplier))
            {
                AppendItemTooltipSnapshotRow(rows, enchantLine, "", "append-body",
                    "enchant");
            }

            // The permanent enchant ("+22 Agility", "Crusader", ...). Skipped when it
            // IS the heirloom stat package -- that occupies the same slot and
            // AppendHeirloomPackageTooltipRows already reports it in full.
            uint32 const permEnchantId =
                item->GetEnchantmentId(PERM_ENCHANTMENT_SLOT);
            if (permEnchantId != 0
                && permEnchantId != heirloomPackageState.enchantId)
            {
                AppendEnchantmentTooltipRows(rows, item, permEnchantId, "enchant");
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

            if (scalingDistribution)
            {
                // Stock draws a scaling item's level range and the level its stats
                // are shown at ("Requires level 1 to 255 (2)"), red when the viewer
                // is outside the range.
                uint32 const minLevel = std::max<uint32>(itemTemplate->RequiredLevel, 1);
                bool const inRange = !player
                    || (player->GetLevel() >= itemTemplate->RequiredLevel
                        && player->GetLevel() <= scalingDistribution->MaxLevel);
                AppendItemTooltipSnapshotRow(rows,
                    "Requires level " + std::to_string(minLevel) + " to "
                        + std::to_string(scalingDistribution->MaxLevel) + " ("
                        + std::to_string(scalingLevel) + ")",
                    "", "append-body",
                    inRange ? "requirement" : "requirement-unmet");
            }
            else if (itemTemplate->RequiredLevel > 1)
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

            // Everything above is the white/requirement half of the tooltip. The
            // item level closes it, and the green Equip: section opens with the
            // rating stats parked earlier.
            emitItemLevelRow();
            for (ItemTooltipSnapshotRow const& equipRow : equipStatRows)
                rows.push_back(equipRow);

            for (uint32 spellIndex = 0; spellIndex < MAX_ITEM_PROTO_SPELLS;
                 ++spellIndex)
            {
                _Spell const& itemSpell = itemTemplate->Spells[spellIndex];
                if (itemSpell.SpellId <= 0
                    || itemSpell.SpellTrigger >= MAX_ITEM_SPELLTRIGGER)
                {
                    continue;
                }

                // The runtime hooks in ItemUpgradeProcScaling scale this spell's
                // damage/healing/aura amounts by the source item's upgrade
                // multiplier, so the tooltip has to print the scaled value or it
                // contradicts the combat log. The registry answers whether the
                // spell is scaled for THIS entry; the magnitude is this item's own
                // multiplier, already resolved into the snapshot.
                float const procMultiplier =
                    DarkChaos::ItemUpgrade::IsProcScalingIndexed(item->GetEntry(),
                        uint32(itemSpell.SpellId))
                    ? static_cast<float>(multiplier)
                    : 1.0f;

                std::string text = BuildItemSpellTooltipText(player,
                    itemSpell.SpellId, itemSpell.SpellTrigger, procMultiplier);
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

            if (itemTemplate->ItemSet != 0)
            {
                AppendItemSetTooltipRows(rows, player, itemTemplate->ItemSet,
                    sItemSetStore.LookupEntry(itemTemplate->ItemSet));
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

        // No-op when the template branch above already placed it.
        emitItemLevelRow();

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

        // A chat link names someone else's item by owner + item guid (see
        // ExtendChatItemLinks). The link is public, so is what it points at --
        // but only what that player carries (equipped, bags, bank; never their
        // mail), and only the item the link is actually for.
        if (request.contextKind == ItemTooltipSnapshotContextKind::LINK
            && request.ownerGuidLow != 0
            && request.ownerGuidLow != player->GetGUID().GetCounter())
        {
            Player* owner = ResolveItemTooltipSnapshotOwner(player, request,
                outStatus);
            if (!owner)
                return nullptr;

            Item* item = request.itemGuidLow
                ? owner->GetItemByGuid(
                    ObjectGuid::Create<HighGuid::Item>(request.itemGuidLow))
                : nullptr;
            if (!item || item->GetEntry() != request.itemEntry)
            {
                outStatus = ItemTooltipSnapshotStatus::ITEM_NOT_FOUND;
                return nullptr;
            }

            return item;
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

    // ------------------------------------------------------------------
    // Chat item links that carry the item, not just the template
    // ------------------------------------------------------------------
    // A 3.3.5 item link is item:id:enchant:gem1:gem2:gem3:gem4:suffix:seed:level --
    // it names a template, so an upgraded item or DC RandomEnchants rolls looked
    // like a fresh drop to everyone who clicked it. For such items the link is
    // extended to ...:level:<ownerGuidLow>:<itemGuidLow>; WotLK-Extensions reads
    // the two fields and asks for the snapshot of that item (LINK context above).
    // The stock client stops parsing after the level (0x50F630), so it is
    // unaffected, and HyperlinkTags accepts the extended shape on re-link.

    // Whether the item's tooltip says more than its link can: anything the
    // upgrade system can raise, or random-enchant stats in the property slots of
    // an item whose link carries no random property id.
    static bool ItemTooltipExceedsLink(Item* item)
    {
        ItemTemplate const* proto = item ? item->GetTemplate() : nullptr;
        if (!proto)
            return false;

        if (item->GetItemRandomPropertyId() == 0)
        {
            for (uint8 slot = PROP_ENCHANTMENT_SLOT_0; slot <= PROP_ENCHANTMENT_SLOT_4;
                 ++slot)
            {
                if (item->GetEnchantmentId(EnchantmentSlot(slot)))
                    return true;
            }
        }

        if (proto->Class != ITEM_CLASS_WEAPON && proto->Class != ITEM_CLASS_ARMOR)
            return false;

        DarkChaos::ItemUpgrade::UpgradeManager* mgr =
            DarkChaos::ItemUpgrade::GetUpgradeManager();
        return mgr
            && mgr->GetItemTier(proto->ItemId) != DarkChaos::ItemUpgrade::TIER_INVALID;
    }

    // The sender's copy the link was made from: same entry, enchant, gems and
    // random property. Equipped first, then bags, then bank.
    static Item* FindLinkedItem(Player* player, uint32 entry, uint32 enchantId,
        std::array<uint32, 3> const& gemEnchantIds, int32 randomPropertyId)
    {
        auto const matches = [&](Item* item)
        {
            if (!item || item->GetEntry() != entry
                || item->GetEnchantmentId(PERM_ENCHANTMENT_SLOT) != enchantId
                || item->GetItemRandomPropertyId() != randomPropertyId)
            {
                return false;
            }

            for (uint8 i = 0; i < gemEnchantIds.size(); ++i)
            {
                if (item->GetEnchantmentId(EnchantmentSlot(SOCK_ENCHANTMENT_SLOT + i))
                    != gemEnchantIds[i])
                {
                    return false;
                }
            }

            return true;
        };

        auto const searchBag = [&](uint8 bagSlot) -> Item*
        {
            if (Bag* bag = player->GetBagByPos(bagSlot))
            {
                for (uint32 i = 0; i < bag->GetBagSize(); ++i)
                {
                    if (Item* item = bag->GetItemByPos(uint8(i)); matches(item))
                        return item;
                }
            }
            return nullptr;
        };

        for (uint8 slot = EQUIPMENT_SLOT_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
        {
            if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot); matches(item))
                return item;
        }

        for (uint8 slot = INVENTORY_SLOT_BAG_START; slot < INVENTORY_SLOT_BAG_END; ++slot)
        {
            if (Item* item = searchBag(slot))
                return item;
        }

        for (uint8 slot = BANK_SLOT_ITEM_START; slot < BANK_SLOT_ITEM_END; ++slot)
        {
            if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot); matches(item))
                return item;
        }

        for (uint8 slot = BANK_SLOT_BAG_START; slot < BANK_SLOT_BAG_END; ++slot)
        {
            if (Item* item = searchBag(slot))
                return item;
        }

        return nullptr;
    }

    // Rewrites every |Hitem:...|h link in `msg`: drops whatever the client sent
    // past the ninth field, then appends the sender's owner/item guids when the
    // sender carries that exact item and its tooltip exceeds the link. Tokens are
    // never passed through, so nobody can present another player's upgraded
    // item as their own.
    static void ExtendChatItemLinks(Player* sender, std::string& msg)
    {
        static std::string const kLinkStart = "|Hitem:";
        // The client accepts long chat lines, but stay well clear of anything
        // that could reach a fixed-size buffer on the way.
        static constexpr std::size_t kMaxRewrittenLength = 1000;

        std::string out;
        out.reserve(msg.size() + 32);

        std::size_t cursor = 0;
        bool changed = false;
        while (true)
        {
            std::size_t const start = msg.find(kLinkStart, cursor);
            if (start == std::string::npos)
                break;

            std::size_t const dataStart = start + kLinkStart.size();
            std::size_t const dataEnd = msg.find('|', dataStart);
            if (dataEnd == std::string::npos)
                break;

            std::vector<std::string_view> fields;
            std::string_view const data(msg.data() + dataStart, dataEnd - dataStart);
            for (std::size_t pos = 0; pos <= data.size();)
            {
                std::size_t const colon = data.find(':', pos);
                std::size_t const end = colon == std::string_view::npos ? data.size() : colon;
                fields.push_back(data.substr(pos, end - pos));
                pos = end + 1;
            }

            out.append(msg, cursor, dataStart - cursor);
            cursor = dataEnd;

            constexpr std::size_t kStandardFields = 9;
            if (fields.size() < kStandardFields)
            {
                out.append(data);
                continue;
            }

            std::string_view const standard = data.substr(0,
                fields[kStandardFields - 1].data() + fields[kStandardFields - 1].size()
                    - data.data());
            out.append(standard);
            changed = changed || fields.size() != kStandardFields;

            auto const toUInt = [](std::string_view text)
            {
                return static_cast<uint32>(std::strtoul(std::string(text).c_str(), nullptr, 10));
            };

            uint32 const entry = toUInt(fields[0]);
            std::array<uint32, 3> const gems = { toUInt(fields[2]), toUInt(fields[3]), toUInt(fields[4]) };
            int32 const randomPropertyId = static_cast<int32>(
                std::strtol(std::string(fields[6]).c_str(), nullptr, 10));

            Item* item = FindLinkedItem(sender, entry, toUInt(fields[1]), gems, randomPropertyId);
            if (!item || !ItemTooltipExceedsLink(item))
                continue;

            out += ':';
            out += std::to_string(sender->GetGUID().GetCounter());
            out += ':';
            out += std::to_string(item->GetGUID().GetCounter());
            changed = true;
        }

        if (!changed)
            return;

        out.append(msg, cursor, std::string::npos);
        if (out.size() <= kMaxRewrittenLength)
            msg = std::move(out);
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

    // Stats an item grants that its item LINK cannot carry, so a client scoring
    // items from links never sees them:
    //
    //  * DC RandomEnchants rolls. They sit in PROP_ENCHANTMENT_SLOT_0..4 with the
    //    random-property id left at 0, and a link only encodes that id. Scaled by
    //    the upgrade multiplier, exactly like the runtime enchant hook does.
    //    Skipped when the item has a real random property/suffix: then those
    //    slots hold the suffix, which the link DOES carry (double count).
    //  * The heirloom stat package. It is a permanent enchant and so is in the
    //    link, but its description is "Fury 15/15" -- nothing a stat parser can
    //    read. Not scaled: heirloom packages are not multiplied.
    //
    // STAT-type effects only. Equip-spell rolls such as "+33 Frost Spell Damage"
    // are school-specific and have no generic stat to be scored as.
    struct LinkInvisibleEnchantStat
    {
        uint32 statType;
        uint32 value;
    };

    static std::vector<LinkInvisibleEnchantStat> CollectLinkInvisibleEnchantStats(
        Item* item, DarkChaos::ItemUpgrade::ItemUpgradeTooltipSnapshot const& snapshot)
    {
        std::vector<LinkInvisibleEnchantStat> stats;
        if (!item)
            return stats;

        auto collect = [&](SpellItemEnchantmentEntry const* enchant, double multiplier)
        {
            if (!enchant)
                return;

            for (uint32 i = 0; i < MAX_SPELL_ITEM_ENCHANTMENT_EFFECTS; ++i)
            {
                if (enchant->type[i] != ITEM_ENCHANTMENT_TYPE_STAT)
                    continue;

                uint32 const amount = ScaleEnchantAmount(
                    ResolveEnchantmentStatAmount(item, enchant, i), multiplier);
                if (amount != 0)
                    stats.push_back({ enchant->spellid[i], amount });
            }
        };

        if (item->GetItemRandomPropertyId() == 0)
        {
            double const multiplier =
                static_cast<double>(snapshot.stat_multiplier_basis_points) / 10000.0;
            for (uint32 propIndex = 0; propIndex < MAX_ITEM_ENCHANTMENT_EFFECTS; ++propIndex)
            {
                collect(sSpellItemEnchantmentStore.LookupEntry(item->GetEnchantmentId(
                    EnchantmentSlot(PROP_ENCHANTMENT_SLOT_0 + propIndex))), multiplier);
            }
        }

        HeirloomPackageTooltipState const package =
            ResolveHeirloomPackageTooltipState(item, snapshot);
        if (package.enchantId)
            collect(sSpellItemEnchantmentStore.LookupEntry(package.enchantId), 1.0);

        return stats;
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

        // Appended after the error string on purpose: a client DLL that predates
        // this field stops reading at the string and never sees it.
        // Layout: int32 count, then count x (int32 ItemModType, int32 value).
        constexpr std::size_t MAX_LINK_INVISIBLE_STATS = 16;
        std::vector<LinkInvisibleEnchantStat> bonusStats =
            CollectLinkInvisibleEnchantStats(item, snapshot);
        if (bonusStats.size() > MAX_LINK_INVISIBLE_STATS)
            bonusStats.resize(MAX_LINK_INVISIBLE_STATS);

        data << int32(bonusStats.size());
        for (LinkInvisibleEnchantStat const& stat : bonusStats)
        {
            data << int32(stat.statType);
            data << int32(stat.value);
        }

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

    // A pet GUID (HighGuid::Pet) carries the pet number where a creature GUID
    // carries the entry, so GetEntry() on it names no creature_template row --
    // every hover on a hunter/warlock pet came back "Creature template not
    // found". Take the entry from the live pet instead (0 if not visible).
    static uint32 ResolveNpcTooltipEntry(Player* player, ObjectGuid const& guid)
    {
        if (!guid.IsPet())
            return guid.GetEntry();

        Creature* pet = player
            ? ObjectAccessor::GetCreatureOrPetOrVehicle(*player, guid)
            : nullptr;
        return pet ? pet->GetEntry() : 0;
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

        uint32 entry = ResolveNpcTooltipEntry(player, guid);
        CreatureTemplate const* creatureTemplate =
            sObjectMgr->GetCreatureTemplate(entry);
        if (!creatureTemplate)
        {
            SendNpcTooltipInfoNativeError(player, guidStr,
                "Creature template not found");
            return;
        }

        // Pets have no DB spawn; they keep the success reply so the client
        // gets their real entry (the GUID only carries the pet number).
        uint32 spawnId = 0;
        CreatureData const* spawnData = guid.IsPet() ? nullptr
            : ResolveNpcTooltipSpawnData(player, guid, spawnId);
        if (!guid.IsPet() && !spawnData && spawnId == 0)
        {
            // Summons and event spawns: say so, rather than an all-zero reply
            // the client reads as "not resolved yet" and re-asks for.
            SendNpcTooltipInfoNativeError(player, guidStr, "No DB spawn");
            return;
        }

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
                                       std::string const& requestedDistribution,
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

        // A roaming bot crosses zone borders constantly, and each crossing
        // would otherwise allocate a delayed event whose only job is to push a
        // graphics-profile invalidation at a session with no graphics. Drop it
        // here rather than at the send, so the event never gets scheduled.
        if (DCAddon::IsBotRecipient(player))
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

    // Pre-warm the per-player settings cache asynchronously at login so the
    // synchronous DB fallback in GetPlayerSettingsCached (world-thread stall
    // class) effectively never runs. A handler racing the warm still falls
    // back to the one-off sync read safely.
    void WarmPlayerSettingsCacheAsync(Player* player)
    {
        if (!player)
            return;

        uint32 guid = player->GetGUID().GetCounter();
        {
            std::lock_guard<std::mutex> lock(s_PlayerSettingsCacheMutex);
            if (s_PlayerSettingsCache.find(guid) != s_PlayerSettingsCache.end())
                return;
        }

        std::string const sql =
            "SELECT setting_key, setting_value FROM dc_player_qos_settings WHERE guid = "
            + std::to_string(guid);

        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(sql)
            .WithCallback([guid](QueryResult result)
        {
            QoSSettings settings;
            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    ApplyPlayerSetting(settings,
                        fields[0].Get<std::string>(),
                        fields[1].Get<std::string>());
                } while (result->NextRow());
            }

            std::lock_guard<std::mutex> lock(s_PlayerSettingsCacheMutex);
            s_PlayerSettingsCache.emplace(guid, std::move(settings));
        }));
    }

    void SavePlayerSetting(Player* player, std::string const& key, std::string const& value)
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

    // ------------------------------------------------------------------
    // Custom item/spell tooltip data caches.
    // dc_item_custom_data / dc_spell_custom_data are small, static world
    // tables, but SendItemInfo/SendSpellInfo fire on TOOLTIP HOVER -- the most
    // frequent request in the entire addon protocol -- and each issued a
    // synchronous WorldDatabase query on the world thread (the same class as
    // the observed 18s World.UpdateSessions stalls). Load each table once and
    // serve every hover from memory; the tables only change with world-DB
    // content updates, which require a restart anyway.
    // ------------------------------------------------------------------
    struct CustomItemTooltipData
    {
        std::string note;
        std::string source;
        bool isCustom = false;
    };

    struct CustomSpellTooltipData
    {
        std::string note;
        std::string modifiedValues;
    };

    // Both caches load on first use through a function-local static, whose initialisation C++ runs exactly once
    // even when several map threads reach it at the same time. The old `static bool loaded` flag let two threads
    // fill the same map concurrently, or let one read it while another was still inserting.
    static std::unordered_map<uint32, CustomItemTooltipData> const& GetCustomItemTooltipCache()
    {
        static std::unordered_map<uint32, CustomItemTooltipData> const cache = []()
        {
            std::unordered_map<uint32, CustomItemTooltipData> rows;
            if (QueryResult result = WorldDatabase.Query(
                "SELECT item_id, custom_note, custom_source, is_custom FROM dc_item_custom_data"))
            {
                do
                {
                    Field* fields = result->Fetch();
                    CustomItemTooltipData& entry = rows[fields[0].Get<uint32>()];
                    entry.note = fields[1].Get<std::string>();
                    entry.source = fields[2].Get<std::string>();
                    entry.isCustom = fields[3].Get<bool>();
                } while (result->NextRow());
            }
            LOG_INFO("module.dc", "[DCQoS] Cached {} custom item tooltip rows", rows.size());
            return rows;
        }();

        return cache;
    }

    static std::unordered_map<uint32, CustomSpellTooltipData> const& GetCustomSpellTooltipCache()
    {
        static std::unordered_map<uint32, CustomSpellTooltipData> const cache = []()
        {
            std::unordered_map<uint32, CustomSpellTooltipData> rows;
            if (QueryResult result = WorldDatabase.Query(
                "SELECT spell_id, custom_note, modified_values FROM dc_spell_custom_data"))
            {
                do
                {
                    Field* fields = result->Fetch();
                    CustomSpellTooltipData& entry = rows[fields[0].Get<uint32>()];
                    entry.note = fields[1].Get<std::string>();
                    entry.modifiedValues = fields[2].Get<std::string>();
                } while (result->NextRow());
            }
            LOG_INFO("module.dc", "[DCQoS] Cached {} custom spell tooltip rows", rows.size());
            return rows;
        }();

        return cache;
    }

    void SendItemInfo(Player* player, uint32 itemId)
    {
        if (!player || !player->GetSession())
            return;

        ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
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

        // Custom item data from the in-memory cache (never query the DB on the
        // tooltip-hover path).
        auto const& customItems = GetCustomItemTooltipCache();
        if (auto itr = customItems.find(itemId); itr != customItems.end())
        {
            msg.Set("customNote", itr->second.note);
            msg.Set("customSource", itr->second.source);
            msg.Set("isCustom", itr->second.isCustom);
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

    // No by-entry fallback when the creature has no spawn of its own (temp
    // summons, event spawns): there used to be one that scanned every creature
    // spawn row per request and then reported the first spawn sharing the
    // entry -- another creature's DB guid.
    static CreatureData const* ResolveNpcTooltipSpawnData(Player* player,
        ObjectGuid const& guid,
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

        return nullptr;
    }

    void SendNpcInfo(Player* player, std::string const& guidStr)
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

        uint32 entry = ResolveNpcTooltipEntry(player, guid);

        CreatureTemplate const* creatureTemplate = sObjectMgr->GetCreatureTemplate(entry);
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
        CreatureData const* spawnData = guid.IsPet() ? nullptr
            : ResolveNpcTooltipSpawnData(player, guid, spawnId);

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

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
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

        // Custom spell data from the in-memory cache (never query the DB on the
        // tooltip-hover path).
        auto const& customSpells = GetCustomSpellTooltipCache();
        if (auto itr = customSpells.find(spellId); itr != customSpells.end())
        {
            msg.Set("customNote", itr->second.note);
            msg.Set("modifiedValues", itr->second.modifiedValues);
        }

        msg.Send(player);
    }

    // Formatting primitives moved to dc_addon_spell_template.h so the
    // .stresstest harness can exercise these instead of private copies.
    // Pulled into DCQoS unqualified: every existing call site is unchanged.
    using DCAddon::SpellTemplate::ExtractLastTemplateQuantity;
    using DCAddon::SpellTemplate::FormatDurationTemplate;
    using DCAddon::SpellTemplate::FormatSpellSeconds;
    using DCAddon::SpellTemplate::FormatTemplateNumericValue;
    using DCAddon::SpellTemplate::GetPowerTypeLabel;
    using DCAddon::SpellTemplate::HasUnresolvedTemplateTokens;
    using DCAddon::SpellTemplate::TrimTemplateText;
    using DCAddon::SpellTemplate::TryParseLeadingDouble;
    using DCAddon::SpellTemplate::TryParseStrictDouble;
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

    // Read straight from the DBC. This used to go through a lock-free static cache that the tooltip push reaches
    // from every map update thread at once; a concurrent insert corrupted it and the next lookup looped forever,
    // freezing the world thread. The cache bought nothing: the string is returned by value either way and the DBC
    // text is already in memory.
    static std::string GetSpellDescriptionTemplate(uint32 spellId)
    {
        SpellEntry const* spellEntry = sSpellStore.LookupEntry(spellId);
        if (!spellEntry)
            return "";

        if (spellEntry->Description[0] && *spellEntry->Description[0])
            return spellEntry->Description[0];

        if (spellEntry->ToolTip[0] && *spellEntry->ToolTip[0])
            return spellEntry->ToolTip[0];

        return "";
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

    // Applies an item-upgrade proc multiplier to a tooltip magnitude. Kept to the
    // same lround-of-double shape the combat hooks use so the printed number
    // matches the damage/heal the player actually sees.
    static TooltipAmountRange ScaleTooltipAmountRange(TooltipAmountRange range,
                                                     float valueMultiplier)
    {
        if (valueMultiplier <= 1.0f)
            return range;

        range.Min = static_cast<int32>(std::lround(
            static_cast<double>(range.Min) * static_cast<double>(valueMultiplier)));
        range.Max = static_cast<int32>(std::lround(
            static_cast<double>(range.Max) * static_cast<double>(valueMultiplier)));
        return range;
    }

    static std::string ReplaceSpellTemplateToken(Player* player,
                                                 SpellInfo const* spellInfo,
                                                 char token,
                                                 uint32 effectNumber,
                                                 float valueMultiplier = 1.0f)
    {
        if (!spellInfo)
            return "";

        // Spell-level counts. Read against Spell.dbc text: "$h% chance" is the proc
        // chance, "after it has struck $n times" the proc charges, "Stacks up to $u
        // times" the stack limit. $n used to print the spell NAME and $u the
        // per-combo-point value, so set bonuses read "stacking up to 0 times".
        if (token == 'h')
            return std::to_string(spellInfo->ProcChance);

        if (token == 'n')
            return std::to_string(spellInfo->ProcCharges);

        if (token == 'u')
            return std::to_string(spellInfo->StackAmount);

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

        // "Affects $x1 total targets."
        if (token == 'x')
            return std::to_string(effect->ChainTarget);

        // Per combo point ("1 point: ${$m1+$b1*1}"), a magnitude like $s, so it
        // takes the proc multiplier too.
        if (token == 'b')
        {
            return std::to_string(std::lround(std::fabs(effect->PointsPerComboPoint)
                * valueMultiplier));
        }

        TooltipAmountRange amount = GetTemplateScaledAmountRange(player, spellInfo, *effect);
        if (!amount.IsValid())
            return "0";

        // Magnitude tokens only. Durations ($d/$t), radius ($r/$a), counts ($h/$n/
        // $u/$x) are untouched by proc scaling at runtime, so scaling them here
        // would print numbers the server never applies.
        amount = ScaleTooltipAmountRange(amount, valueMultiplier);

        switch (token)
        {
            case 's':
                return FormatSignedAmountRange(amount, true);
            case 'm':
                return std::to_string(std::abs(amount.Min));
            case 'M':
                return std::to_string(std::abs(amount.Max));
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
            default:
                break;
        }

        return "";
    }

    static bool TryEvaluateTemplateOperand(Player* player,
                                           SpellInfo const* spellInfo,
                                           std::string const& operand,
                                           double& out,
                                           float valueMultiplier = 1.0f)
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
            ReplaceSpellTemplateToken(player, spellInfo, token, effectNumber,
                                      valueMultiplier);
        return TryParseLeadingDouble(replacement, out);
    }

    static bool TryEvaluateSimpleTemplateExpression(Player* player,
                                                    SpellInfo const* spellInfo,
                                                    std::string const& expression,
                                                    std::string& out,
                                                    float valueMultiplier = 1.0f)
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
            if (!TryEvaluateTemplateOperand(player, spellInfo, operandText, value,
                                            valueMultiplier))
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

    static std::string RenderSpellDescriptionTemplate(Player* player,
                                                      SpellInfo const* spellInfo,
                                                      std::string const& sourceTemplate,
                                                      float valueMultiplier,
                                                      bool colorizeValues)
    {
        if (!spellInfo || sourceTemplate.empty())
            return "";

        auto const colorize = [colorizeValues](std::string const& value)
        {
            return colorizeValues ? ColorizeTooltipValue(value) : value;
        };

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
                                                            expressionValue,
                                                            valueMultiplier))
                    {
                        rendered += colorize(expressionValue);
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

                // "$<spellId><token>[effect]" points into ANOTHER spell:
                // $75456s1 is effect 1 of spell 75456, $75456d its duration. Item
                // procs are written this way almost universally -- the equip aura
                // describes the buff it triggers -- and without this branch the
                // digits were read as an effect number, the lookup failed and the
                // raw "$75456s1" text went out to the client.
                if (indexEnd < sourceTemplate.size()
                    && (indexEnd - (i + 1)) <= 9
                    && std::isalpha(
                        static_cast<unsigned char>(sourceTemplate[indexEnd])))
                {
                    uint32 const referencedSpellId = static_cast<uint32>(
                        std::stoul(sourceTemplate.substr(i + 1,
                                                         indexEnd - (i + 1))));
                    char const referencedToken = sourceTemplate[indexEnd];

                    std::size_t effectStart = indexEnd + 1;
                    std::size_t effectEnd = effectStart;
                    while (effectEnd < sourceTemplate.size()
                        && (effectEnd - effectStart) < 2
                        && std::isdigit(static_cast<unsigned char>(
                            sourceTemplate[effectEnd])))
                    {
                        ++effectEnd;
                    }

                    uint32 referencedEffect = 0;
                    if (effectEnd > effectStart)
                    {
                        referencedEffect = static_cast<uint32>(std::stoul(
                            sourceTemplate.substr(effectStart,
                                                  effectEnd - effectStart)));
                    }

                    if (SpellInfo const* referencedSpell =
                            sSpellMgr->GetSpellInfo(referencedSpellId))
                    {
                        std::string referencedValue = ReplaceSpellTemplateToken(
                            player, referencedSpell, referencedToken,
                            referencedEffect, valueMultiplier);
                        if (!referencedValue.empty())
                        {
                            rendered += colorize(referencedValue);
                            i = effectEnd;
                            continue;
                        }
                    }
                }

                uint32 effectNumber = static_cast<uint32>(
                    std::stoul(sourceTemplate.substr(i + 1,
                                                     indexEnd - (i + 1))));

                std::string replacement = ReplaceSpellTemplateToken(player,
                                                                    spellInfo,
                                                                    's',
                                                                    effectNumber,
                                                                    valueMultiplier);
                if (!replacement.empty())
                {
                    rendered += colorize(replacement);
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
                    rendered += colorize(namedReplacement);
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
                || (token == 'a') || (token == 'u') || (token == 'h')
                || (token == 'x');
            if (!tokenSupported)
            {
                rendered.push_back('$');
                ++i;
                continue;
            }

            std::string replacement = ReplaceSpellTemplateToken(player, spellInfo, token, effectNumber, valueMultiplier);
            if (replacement.empty())
                rendered.append(sourceTemplate, i, indexEnd - i);
            else
                rendered += colorize(replacement);

            i = indexEnd;
        }

        return rendered;
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

    // Drops expired entries once the cache passes its soft cap.
    // Caller holds s_SpellTooltipLineCacheMutex.
    static void PruneSpellTooltipCacheLocked(time_t now)
    {
        if (s_SpellTooltipLineCache.size() < SPELL_TOOLTIP_LINE_CACHE_SOFT_CAP)
            return;

        for (auto itr = s_SpellTooltipLineCache.begin();
            itr != s_SpellTooltipLineCache.end(); )
        {
            if (itr->second.expiresAt <= now)
                itr = s_SpellTooltipLineCache.erase(itr);
            else
                ++itr;
        }

        // Still oversized after pruning expired entries: drop all to keep
        // memory bounded (rare with a short TTL).
        if (s_SpellTooltipLineCache.size() >= SPELL_TOOLTIP_LINE_CACHE_SOFT_CAP * 2)
            s_SpellTooltipLineCache.clear();
    }

    // Returns the entry for `key`, resetting it first when it is new or expired
    // so both halves always share one expiry. Filling the second half of a live
    // entry deliberately does not extend that expiry - the TTL is what bounds
    // staleness after a gear change, and refreshing it on every touch would let
    // a frequently requested tooltip go stale indefinitely.
    // Caller holds s_SpellTooltipLineCacheMutex.
    static SpellTooltipLineCacheEntry& OpenSpellTooltipCacheEntryLocked(
        SpellTooltipLineKey const& key, time_t now, uint32 ttlSeconds)
    {
        // Before operator[]: pruning can clear the map and invalidate references.
        PruneSpellTooltipCacheLocked(now);

        SpellTooltipLineCacheEntry& entry = s_SpellTooltipLineCache[key];
        if (entry.expiresAt <= now)
        {
            entry = SpellTooltipLineCacheEntry();
            entry.expiresAt = now + static_cast<time_t>(ttlSeconds);
        }

        return entry;
    }

    // Structured (v2) counterpart of GetOrBuildSpellTooltipLine, sharing its
    // cache, key and TTL.
    //
    // BuildSpellTooltipEnrichmentLines() is the expensive half of an enrichment
    // response - power cost, cast time and range are recomputed from live player
    // stats and the description templates are rendered - and it used to run on
    // every single request even when the flat line came straight from the cache.
    // SMSG_SPELL_TOOLTIP_ENRICHMENT is the highest-volume message on the realm,
    // so that was the bulk of what the module cost.
    //
    // includeFamilyMetadata is an input to the build but not part of the key
    // (it is a per-player setting that rarely changes), so a mismatch counts as
    // a miss and rebuilds.
    static std::shared_ptr<DCAddon::JsonValue const> GetOrBuildSpellTooltipLines(
        Player* player, uint32 spellId, uint32 contextHash,
        SpellInfo const* spellInfo, std::string const& line,
        bool includeFamilyMetadata)
    {
        auto build = [&]()
        {
            return std::make_shared<DCAddon::JsonValue const>(
                BuildSpellTooltipEnrichmentLines(player, spellId, contextHash,
                    spellInfo, line, includeFamilyMetadata));
        };

        uint32 const ttlSeconds = sConfigMgr->GetOption<uint32>(
            "DC.QoS.TooltipEnrichment.CacheTtlSeconds", 60);
        if (ttlSeconds == 0 || !player)
            return build();

        SpellTooltipLineKey const key{ player->GetGUID().GetCounter(), spellId,
            contextHash };
        time_t const now = time(nullptr);

        {
            std::lock_guard<std::mutex> lock(s_SpellTooltipLineCacheMutex);
            auto itr = s_SpellTooltipLineCache.find(key);
            if (itr != s_SpellTooltipLineCache.end()
                && itr->second.expiresAt > now
                && itr->second.lines
                && itr->second.linesFamilyMetadata == includeFamilyMetadata)
                return itr->second.lines;
        }

        std::shared_ptr<DCAddon::JsonValue const> lines = build();

        {
            std::lock_guard<std::mutex> lock(s_SpellTooltipLineCacheMutex);
            SpellTooltipLineCacheEntry& entry =
                OpenSpellTooltipCacheEntryLocked(key, now, ttlSeconds);
            entry.lines = lines;
            entry.linesFamilyMetadata = includeFamilyMetadata;
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
        std::shared_ptr<DCAddon::JsonValue const> structuredLines;
        DCAddon::JsonValue const* structuredLinesPtr = nullptr;

        if (status == 0 && spellInfo)
        {
            structuredLines = GetOrBuildSpellTooltipLines(player, spellId,
                contextHash, spellInfo, line, includeFamilyMetadata);
            structuredLinesPtr = structuredLines.get();
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
            msg.Set("lines", *structuredLinesPtr);
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
            if (itr != s_SpellTooltipLineCache.end() && itr->second.expiresAt > now
                && itr->second.hasLine)
                return itr->second.line;
        }

        std::string line = BuildSpellTooltipEnrichmentLine(player, spellId,
            spellInfo);

        {
            std::lock_guard<std::mutex> lock(s_SpellTooltipLineCacheMutex);
            SpellTooltipLineCacheEntry& entry =
                OpenSpellTooltipCacheEntryLocked(key, now, ttlSeconds);
            entry.line = line;
            entry.hasLine = true;
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

    void SendNotification(Player* player, std::string const& type, std::string const& message)
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

    void HandleSyncSettings(Player* player, DCAddon::ParsedMessage const& /*msg*/)
    {
        SendSettingsSync(player);
    }

    void HandleUpdateSetting(Player* player, DCAddon::ParsedMessage const& msg)
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

    void HandleGetItemInfo(Player* player, DCAddon::ParsedMessage const& msg)
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

    void HandleGetNpcInfo(Player* player, DCAddon::ParsedMessage const& msg)
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

            // A chat link is usually someone else's item the viewer has never
            // seen, so its item record is still in flight: CMSG_ITEM_QUERY_SINGLE
            // is answered on the map tick, which under bot load took seconds
            // longer than this snapshot. The client could not draw the snapshot
            // without the record and sat on "Retrieving item information". Send
            // the record first; it is filed into the item cache unsolicited, as
            // for the vendor priming in dc_vendor_item_cache_prime.cpp.
            if (snapshotRequest.contextKind == ItemTooltipSnapshotContextKind::LINK)
            {
                if (WorldSession* session = player->GetSession())
                    session->SendItemQueryResponse(item->GetEntry());
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

    void HandleGetSpellInfo(Player* player, DCAddon::ParsedMessage const& msg)
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

    void HandleRequestSpellTooltipEnrichment(Player* player, DCAddon::ParsedMessage const& msg)
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

    void HandleRequestFeature(Player* player, DCAddon::ParsedMessage const& msg)
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

    void HandleCollectAllMail(Player* player, DCAddon::ParsedMessage const& /*msg*/)
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
    // Item prefetch
    // -----------------------------------------------------------------------

    // A client that is about to show a list of items (collection pages, loot
    // tables, vault rows) asks for all of them at once instead of letting each
    // row send its own CMSG_ITEM_QUERY_SINGLE, which is answered on the map tick.
    constexpr uint32 ITEM_PREFETCH_MAX_IDS = 50;
    constexpr uint32 ITEM_PREFETCH_MAX_REQUESTS_PER_SECOND = 3;
    constexpr uint32 ITEM_PREFETCH_WINDOW_MS = IN_MILLISECONDS;

    struct ItemPrefetchWindow
    {
        uint32 startMs = 0;
        uint32 requests = 0;
    };

    // guid low -> this second's request count. Erased on logout.
    static std::unordered_map<uint32, ItemPrefetchWindow> s_ItemPrefetchWindows;
    static std::mutex s_ItemPrefetchMutex;

    static bool AllowItemPrefetchRequest(Player* player)
    {
        uint32 const nowMs = getMSTime();
        std::lock_guard<std::mutex> lock(s_ItemPrefetchMutex);
        ItemPrefetchWindow& window = s_ItemPrefetchWindows[player->GetGUID().GetCounter()];
        if (window.requests == 0 || getMSTimeDiff(window.startMs, nowMs) >= ITEM_PREFETCH_WINDOW_MS)
        {
            window.startMs = nowMs;
            window.requests = 0;
        }

        if (window.requests >= ITEM_PREFETCH_MAX_REQUESTS_PER_SECOND)
            return false;

        ++window.requests;
        return true;
    }

    static void ForgetItemPrefetchWindow(uint32 guidLow)
    {
        std::lock_guard<std::mutex> lock(s_ItemPrefetchMutex);
        s_ItemPrefetchWindows.erase(guidLow);
    }

    // The distinct item entries of a {"ids":[...]} request, at most
    // ITEM_PREFETCH_MAX_IDS; anything that is not a whole number in uint32 range
    // is dropped.
    static std::vector<uint32> ReadItemPrefetchIds(DCAddon::JsonValue const& ids)
    {
        std::vector<uint32> entries;
        if (!ids.IsArray())
            return entries;

        std::unordered_set<uint32> seen;
        for (DCAddon::JsonValue const& value : ids.AsArray())
        {
            if (entries.size() >= ITEM_PREFETCH_MAX_IDS)
                break;

            if (!value.IsNumber())
                continue;

            double const number = value.AsNumber();
            if (!(number >= 1.0 && number <= static_cast<double>(std::numeric_limits<uint32>::max())))
                continue;

            uint32 const entry = static_cast<uint32>(number);
            if (static_cast<double>(entry) != number)
                continue;

            if (seen.insert(entry).second)
                entries.push_back(entry);
        }

        return entries;
    }

    // CMSG_PREFETCH_ITEMS {"ids":[entry,...]}. Every entry this session has not
    // been sent yet goes out as an unsolicited SMSG_ITEM_QUERY_SINGLE_RESPONSE,
    // which the client files in its item cache. SMSG_PREFETCH_ITEMS_RESULT
    // follows on the same session, so when it arrives every known entry is
    // cached client-side; "missing" lists the entries with no template, so the
    // client stops waiting for them. "ids" echoes the request because the native
    // transport carries no request id. A throttled request is answered with
    // "throttled" and nothing else, for the client to retry.
    void HandlePrefetchItems(Player* player, DCAddon::ParsedMessage const& msg)
    {
        if (!player || !player->GetSession())
            return;

        std::vector<uint32> const entries =
            ReadItemPrefetchIds(DCAddon::GetJsonData(msg)["ids"]);
        if (entries.empty())
            return;

        DCAddon::JsonValue echoed;
        echoed.SetArray(entries.size());
        for (uint32 entry : entries)
            echoed.Push(DCAddon::JsonValue(entry));

        DCAddon::JsonMessage reply(MODULE, Opcode::SMSG_PREFETCH_ITEMS_RESULT);
        reply.Set("ids", std::move(echoed));

        if (!AllowItemPrefetchRequest(player))
        {
            reply.Set("throttled", true);
            reply.Send(player);
            return;
        }

        using DarkChaos::ItemCachePrime::Result;

        uint32 sent = 0;
        DCAddon::JsonValue missing;
        missing.SetArray();
        for (uint32 entry : entries)
        {
            Result result = DarkChaos::ItemCachePrime::PrimeItem(player, entry);
            // The session's record was just reset; the entry is new to it now.
            if (result == Result::SessionFull)
                result = DarkChaos::ItemCachePrime::PrimeItem(player, entry);

            if (result == Result::Sent)
                ++sent;
            else if (result == Result::UnknownItem)
                missing.Push(DCAddon::JsonValue(entry));
        }

        reply.Set("sent", sent);
        reply.Set("missing", std::move(missing));
        reply.Send(player);
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

// Extends item links in outgoing chat so other clients can show the linked
// item's real tooltip; see DCQoS::ExtendChatItemLinks. Runs after the core has
// validated the links (ChatHandler), before the message is dispatched to any
// channel, so every chat type -- and the sender's own echo -- carries the result.
class DCQoSItemLinkScript : public PlayerScript
{
public:
    DCQoSItemLinkScript() : PlayerScript("DCQoSItemLinkScript",
    {
        PLAYERHOOK_ON_BEFORE_SEND_CHAT_MESSAGE
    }) {}

    void OnPlayerBeforeSendChatMessage(Player* player, uint32& /*type*/,
        uint32& lang, std::string& msg) override
    {
        if (!DCQoS::IsEnabled() || !player || lang == LANG_ADDON
            || msg.find("|Hitem:") == std::string::npos)
        {
            return;
        }

        DCQoS::ExtendChatItemLinks(player, msg);
    }
};

class DCQoSPlayerScript : public PlayerScript
{
public:
    DCQoSPlayerScript() : PlayerScript("DCQoSPlayerScript",
    {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_MAP_CHANGED, PLAYERHOOK_ON_UPDATE_ZONE
    }) {}

    void OnPlayerLogin(Player* player) override
    {
        if (!DCQoS::IsEnabled() || !player)
            return;

        // Async settings-cache warm: keeps GetPlayerSettingsCached off the
        // synchronous DB fallback for the whole session.
        DCQoS::WarmPlayerSettingsCacheAsync(player);

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
        DCQoS::ForgetItemPrefetchWindow(player->GetGUID().GetCounter());

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
        DCAddon::MessageRouter::Instance().RegisterHandler(MODULE, DCQoS::Opcode::CMSG_PREFETCH_ITEMS, HandlePrefetchItems);
    }
}

namespace DarkChaos
{
namespace ItemUpgrade
{
    std::vector<std::string> BuildScaledRandomEnchantLines(Item* item, float multiplier)
    {
        std::vector<std::string> changing;

        // The window previews what an upgrade CHANGES; a weapon-damage enchant that
        // reads the same at every level is left to the tooltip. The line structure
        // does not depend on the multiplier, so the three builds line up by index.
        std::vector<std::string> const base = DCQoS::BuildRandomEnchantLines(item, 1.0);
        std::vector<std::string> const probe = DCQoS::BuildRandomEnchantLines(item, 2.0);
        std::vector<std::string> const scaled =
            DCQoS::BuildRandomEnchantLines(item, static_cast<double>(multiplier));
        if (base.size() != probe.size() || base.size() != scaled.size())
            return changing;

        for (std::size_t i = 0; i < base.size(); ++i)
        {
            if (base[i] != probe[i])
                changing.push_back(scaled[i]);
        }

        return changing;
    }

    std::vector<std::string> BuildRandomEnchantLineText(Item* item, uint8 line, float multiplier)
    {
        return DCQoS::BuildRandomEnchantSlotLines(item, line, static_cast<double>(multiplier));
    }

    std::vector<std::string> BuildScaledItemProcLines(Player* player,
        uint32 itemEntry, float multiplier)
    {
        std::vector<std::string> lines;

        ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemEntry);
        if (!itemTemplate)
            return lines;

        for (uint32 spellIndex = 0; spellIndex < MAX_ITEM_PROTO_SPELLS; ++spellIndex)
        {
            _Spell const& itemSpell = itemTemplate->Spells[spellIndex];
            if (itemSpell.SpellId <= 0
                || itemSpell.SpellTrigger >= MAX_ITEM_SPELLTRIGGER
                || itemSpell.SpellTrigger == ITEM_SPELLTRIGGER_LEARN_SPELL_ID)
            {
                continue;
            }

            // Same gate the tooltip uses: no registry entry, no runtime scaling.
            if (!IsProcScalingIndexed(itemEntry, uint32(itemSpell.SpellId)))
                continue;

            std::string const baseText = DCQoS::BuildItemSpellTooltipText(player,
                itemSpell.SpellId, itemSpell.SpellTrigger, 1.0f);
            if (baseText.empty())
                continue;

            // A description without magnitude tokens reads the same at every level;
            // previewing it would only add noise. 2.0f is just "any multiplier that
            // would move a number if there were one".
            if (DCQoS::BuildItemSpellTooltipText(player, itemSpell.SpellId,
                    itemSpell.SpellTrigger, 2.0f) == baseText)
            {
                continue;
            }

            lines.push_back(multiplier > 1.0f
                ? DCQoS::BuildItemSpellTooltipText(player, itemSpell.SpellId,
                    itemSpell.SpellTrigger, multiplier)
                : baseText);
        }

        return lines;
    }
} // namespace ItemUpgrade
} // namespace DarkChaos

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
    new DCQoSItemLinkScript();
    new DCQoSGroupScript();
    new DCQoSServerScript();
}
