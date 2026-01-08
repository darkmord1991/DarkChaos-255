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
#include "DatabaseEnv.h"
#include <unordered_map>
#include <algorithm>

// Forward declaration for S2C logging (defined later in file)
static bool g_S2CLoggingEnabled = false;
static void LogS2CMessageGlobal(Player* player, const std::string& module, uint8 opcode, size_t dataSize);

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

    void Message::Send(Player* player) const
    {
        if (!player || !player->GetSession())
            return;

        std::string fullMessage = Build();

        // Log S2C message if enabled
        if (g_S2CLoggingEnabled)
        {
            LogS2CMessageGlobal(player, _module, _opcode, fullMessage.length());
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
    }

    static void SendRaw(Player* player, const std::string& msg)
    {
        // Build addon message using proper CHAT_MSG_WHISPER format
        // Format: "DC\t<payload>" - client parses prefix "DC" and message is the payload
        std::string fullMsg = std::string(DC_PREFIX) + "\t" + msg;
        WorldPacket data;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, fullMsg);
        player->SendDirectMessage(&data);
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
    bool EnableGroupFinder;
    bool EnableHotspot;
    bool EnableWorld;
    bool EnableEvents;
    bool EnableQoS;
    bool EnableCollection;

    // Security settings
    bool EnableDebugLog;
    bool EnableProtocolLogging;  // Log to dc_addon_protocol_log table
    uint32 MaxMessagesPerSecond;
    uint32 RateLimitAction;
    uint32 ChunkTimeoutMs;
    uint32 MinGOMoveSecurity;

    // Version
    std::string ProtocolVersion;
};

static DCAddonProtocolConfig s_AddonConfig;

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
    s_AddonConfig.EnableGroupFinder = sConfigMgr->GetOption<bool>("DC.AddonProtocol.GroupFinder.Enable", true);
    s_AddonConfig.EnableHotspot     = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Hotspot.Enable", true);
    s_AddonConfig.EnableWorld       = sConfigMgr->GetOption<bool>("DC.AddonProtocol.World.Enable", true);
    s_AddonConfig.EnableEvents      = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Events.Enable", true);
    s_AddonConfig.EnableQoS         = sConfigMgr->GetOption<bool>("DC.AddonProtocol.QoS.Enable", true);
    s_AddonConfig.EnableCollection  = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Collection.Enable", true);

    s_AddonConfig.EnableDebugLog        = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Debug.Enable", false);
    s_AddonConfig.EnableProtocolLogging = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Logging.Enable", false);
    s_AddonConfig.MaxMessagesPerSecond  = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.RateLimit.Messages", 30);
    s_AddonConfig.RateLimitAction       = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.RateLimit.Action", 0);
    s_AddonConfig.ChunkTimeoutMs        = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.ChunkTimeout", 5000);
    s_AddonConfig.MinGOMoveSecurity     = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.GOMove.MinSecurity", 1);

    // Set global flag for S2C logging (needed by Message::Send before config is accessible)
    g_S2CLoggingEnabled = s_AddonConfig.EnableProtocolLogging;

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
    router.SetModuleEnabled(DCAddon::Module::GROUP_FINDER, s_AddonConfig.EnableGroupFinder);
    router.SetModuleEnabled(DCAddon::Module::HOTSPOT, s_AddonConfig.EnableHotspot);
    router.SetModuleEnabled(DCAddon::Module::WORLD, s_AddonConfig.EnableWorld);
    router.SetModuleEnabled(DCAddon::Module::EVENTS, s_AddonConfig.EnableEvents);
    router.SetModuleEnabled(DCAddon::Module::QOS, s_AddonConfig.EnableQoS);
    router.SetModuleEnabled(DCAddon::Module::COLLECTION, s_AddonConfig.EnableCollection);
    router.SetModuleMinSecurity(DCAddon::Module::GOMOVE, s_AddonConfig.MinGOMoveSecurity);
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
        || opcode == DCAddon::Opcode::Collection::CMSG_COMMUNITY_GET_LIST
        || opcode == DCAddon::Opcode::Collection::CMSG_APPLY_TRANSMOG_PREVIEW
        || opcode == DCAddon::Opcode::Collection::CMSG_SET_TRANSMOG
        || opcode == DCAddon::Opcode::Collection::CMSG_GET_TRANSMOG_STATE;
}

static std::string DetectRequestType(const std::string& payload)
{
    if (payload.empty()) return "STANDARD";

    std::string moduleCode = ExtractModuleCode(payload);
    if (moduleCode == "SPOT" || moduleCode == "SEAS" || moduleCode == "MHUD")
        return "AIO";

    // Check for DC Native format (pipe)
    if (payload.find('|') != std::string::npos)
    {
        // Simple heuristic: if it has pipes, it's likely DC protocol
        return "DC_PLAIN"; // Can't easily distinguish JSON without parsing more, but that's fine
    }

    // Check for DC JSON/Legacy format (colon)
    if (payload.find(':') != std::string::npos)
    {
        if (payload.find('{') != std::string::npos || payload.find('[') != std::string::npos)
            return "DC_JSON";
        return "DC_PLAIN";
    }

    return "STANDARD";
}

static std::string EscapeSQLString(std::string s)
{
    size_t pos = 0;
    while ((pos = s.find("'", pos)) != std::string::npos)
    {
        s.replace(pos, 1, "''");
        pos += 2;
    }
    return s;
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
    time_t lastRequest = 0;
    bool dirty = false;
};

// Map: Guid -> Module -> StatsEntry
static std::unordered_map<uint32, std::unordered_map<std::string, StatsEntry>> s_StatsBuffer;
static std::mutex s_StatsMutex;

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

        for (auto& [module, stats] : it->second)
        {
            if (!stats.dirty) continue;

            // To avoid SQL injection risks on Module, sanitize it strictly or use parameters.
            // Since we can't define new PreparedStatements in core enum dynamically, we will simulate it safely.

            trans->Append("INSERT INTO dc_addon_protocol_stats "
                "(guid, module, total_requests, total_responses, total_timeouts, total_errors, avg_response_time_ms, max_response_time_ms, last_request) "
                "VALUES ({}, '{}', {}, {}, {}, {}, {}, {}, FROM_UNIXTIME({})) "
                "ON DUPLICATE KEY UPDATE "
                "total_requests = total_requests + {}, "
                "total_responses = total_responses + {}, "
                "total_timeouts = total_timeouts + {}, "
                "total_errors = total_errors + {}, "
                "avg_response_time_ms = (avg_response_time_ms * total_responses + {}) / GREATEST(1, total_responses + {}), "
                "max_response_time_ms = GREATEST(max_response_time_ms, {}), "
                "last_request = FROM_UNIXTIME({})",
                currentGuid, module,
                stats.totalRequests, stats.totalResponses, stats.totalTimeouts, stats.totalErrors,
                (stats.totalResponses > 0 ? stats.sumResponseTime / stats.totalResponses : 0),
                stats.maxResponseTime, stats.lastRequest,
                // Update part
                stats.totalRequests, stats.totalResponses, stats.totalTimeouts, stats.totalErrors,
                stats.sumResponseTime, stats.totalResponses,
                stats.maxResponseTime,
                stats.lastRequest
            );

            stats = StatsEntry(); // Reset delta stats
        }

        // If flushing specific player, remove them from memory
        it = (guid != 0) ? s_StatsBuffer.erase(it) : ++it;
    }
    CharacterDatabase.CommitTransaction(trans);
}

// Update player statistics in buffer
static void UpdateProtocolStats(Player* player, const std::string& moduleCode, bool isRequest, bool isTimeout = false, bool isError = false, uint32 responseTimeMs = 0)
{
    if (!s_AddonConfig.EnableProtocolLogging || !player) return;

    // Sanitize module code
    std::string safeModule = moduleCode;
    safeModule.erase(std::remove_if(safeModule.begin(), safeModule.end(),
        [](char c) { return !isalnum(c) && c != '_'; }), safeModule.end());
    if (safeModule.length() > 16) safeModule = safeModule.substr(0, 16);

    std::lock_guard<std::mutex> lock(s_StatsMutex);
    auto& stats = s_StatsBuffer[player->GetGUID().GetCounter()][safeModule];

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
    stats.lastRequest = time(nullptr);
    stats.dirty = true;
}

static void LogProtocolErrorEvent(Player* player, const std::string& payload, const std::string& eventType, const std::string& message)
{
    if (!s_AddonConfig.EnableProtocolLogging)
        return;

    std::string moduleCode = ExtractModuleCode(payload);
    uint8 opcode = ExtractOpcode(payload);
    std::string requestType = DetectRequestType(payload);
    std::string preview = payload.length() > 255 ? payload.substr(0, 255) : payload;

    moduleCode.erase(std::remove_if(moduleCode.begin(), moduleCode.end(), [](char c) { return !isalnum(c) && c != '_'; }), moduleCode.end());
    if (moduleCode.length() > 16) moduleCode = moduleCode.substr(0, 16);

    std::string safeEventType = eventType;
    safeEventType.erase(std::remove_if(safeEventType.begin(), safeEventType.end(), [](char c) { return !isalnum(c) && c != '_' && c != '-'; }), safeEventType.end());
    if (safeEventType.length() > 32) safeEventType = safeEventType.substr(0, 32);

    uint32 guidCounter = player ? player->GetGUID().GetCounter() : 0;
    uint32 accountId = (player && player->GetSession()) ? player->GetSession()->GetAccountId() : 0;
    std::string name = player ? player->GetName() : std::string();

    CharacterDatabase.Execute(
        "INSERT INTO dc_addon_protocol_errors "
        "(guid, account_id, character_name, direction, request_type, module, opcode, event_type, message, payload_preview) "
        "VALUES ({}, {}, '{}', 'C2S', '{}', '{}', {}, '{}', '{}', '{}')",
        guidCounter,
        accountId,
        EscapeSQLString(name),
        requestType,
        moduleCode,
        opcode,
        EscapeSQLString(safeEventType),
        EscapeSQLString(message),
        EscapeSQLString(preview)
    );
}

static void LogC2SMessage(Player* player, const std::string& payload, bool handled, const std::string& errorMsg = "")
{
    if (!s_AddonConfig.EnableProtocolLogging || !player || !player->GetSession()) return;

    std::string moduleCode = ExtractModuleCode(payload);
    uint8 opcode = ExtractOpcode(payload);
    std::string requestType = DetectRequestType(payload);
    std::string status = handled ? "completed" : (errorMsg.empty() ? "pending" : "error");
    std::string preview = payload.length() > 255 ? payload.substr(0, 255) : payload;

    // Sanitize inputs for raw query safety (as we can't add PreparedStatements)
    // For module: alphanumeric only
    moduleCode.erase(std::remove_if(moduleCode.begin(), moduleCode.end(), [](char c) { return !isalnum(c) && c != '_'; }), moduleCode.end());
    if (moduleCode.length() > 16) moduleCode = moduleCode.substr(0, 16);

    CharacterDatabase.Execute(
        "INSERT INTO dc_addon_protocol_log "
        "(guid, account_id, character_name, direction, request_type, module, opcode, data_size, data_preview, status, error_message) "
        "VALUES ({}, {}, '{}', 'C2S', '{}', '{}', {}, {}, '{}', '{}', '{}')",
        player->GetGUID().GetCounter(),
        player->GetSession()->GetAccountId(),
        EscapeSQLString(player->GetName()),
        requestType,
        moduleCode,
        opcode,
        payload.length(),
        EscapeSQLString(preview),
        status,
        EscapeSQLString(errorMsg)
    );
}

static void LogS2CMessageGlobal(Player* player, const std::string& module, uint8 opcode, size_t dataSize)
{
    if (!player || !player->GetSession()) return;

    std::string safeModule = module;
    safeModule.erase(std::remove_if(safeModule.begin(), safeModule.end(), [](char c) { return !isalnum(c) && c != '_'; }), safeModule.end());
    if (safeModule.length() > 16) safeModule = safeModule.substr(0, 16);

    std::string requestType = (safeModule == "SPOT" || safeModule == "SEAS" || safeModule == "MHUD") ? "AIO" : (safeModule == "LBRD" ? "JSON" : "STANDARD");

    CharacterDatabase.Execute(
        "INSERT INTO dc_addon_protocol_log "
        "(guid, account_id, character_name, direction, request_type, module, opcode, data_size, data_preview, status) "
        "VALUES ({}, {}, '{}', 'S2C', '{}', '{}', {}, {}, '', 'completed')",
        player->GetGUID().GetCounter(),
        player->GetSession()->GetAccountId(),
        player->GetName(), // Name update assumed safe or handled by Execute format in newer TC
        requestType,
        safeModule,
        opcode,
        dataSize
    );

    UpdateProtocolStats(player, safeModule, false, false, false, 0); // isResponse=true implicit
}

// ============================================================================
// RATE LIMITING
// ============================================================================

struct PlayerMessageTracker
{
    uint32 messageCount;
    uint32 lastResetTime;
    bool isMuted;
    uint32 muteExpireTime;
    uint32 violationCount;     // Track repeated violations for exponential backoff
    uint32 lastViolationTime;  // For violation decay
};

static std::unordered_map<uint32, PlayerMessageTracker> s_MessageTrackers;

static bool CheckRateLimit(Player* player)
{
    uint32 accountId = player->GetSession()->GetAccountId();
    uint32 now = GameTime::GetGameTime().count();

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
    std::string clientVersionStr = msg.GetString(0);

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

    // Send acknowledgment with server version and negotiated capabilities
    DCAddon::Message(DCAddon::Module::CORE, DCAddon::Opcode::Core::SMSG_HANDSHAKE_ACK)
        .Add(DCAddon::ProtocolVersion::BuildVersionString(serverVersion))
        .Add(compatible)
        .Add(negotiatedCaps)  // Negotiated capability flags
        .Send(player);

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

    DCAddon::Message(DCAddon::Module::CORE, DCAddon::Opcode::Core::SMSG_VERSION_RESULT)
        .Add(compatible)
        .Add(s_AddonConfig.ProtocolVersion)
        .Add(compatible ? "OK" : "Version mismatch - please update addon")
        .Send(player);
}

static void HandleCoreFeatureQuery(Player* player, const DCAddon::ParsedMessage& /*msg*/)
{
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
    for (const auto& entry : entries)
    {
        // Reconstruct the message string: MODULE|OPCODE|data1|data2|...
        std::string subMsg = entry.module + DCAddon::DELIMITER + std::to_string(entry.opcode);
        for (const auto& d : entry.data)
        {
            subMsg += DCAddon::DELIMITER;
            subMsg += d;
        }

        // Route through MessageRouter (excluding BATCH to prevent recursion)
        if (entry.module != DCAddon::Batch::MODULE)
        {
            DCAddon::MessageRouter::Instance().Route(player, subMsg);
        }
    }
}

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

static void CleanupExpiredChunks()
{
    uint32 now = GameTime::GetGameTime().count() * 1000;  // Convert to ms

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
        if (s_AddonConfig.EnableProtocolLogging && s_ChunkStartTimes.find(accountId) != s_ChunkStartTimes.end())
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_addon_protocol_errors "
                "(guid, account_id, character_name, direction, request_type, module, opcode, event_type, message) "
                "VALUES ({}, {}, '{}', 'C2S', 'DC_PLAIN', 'CHUNK', 0, 'chunk_abandoned', 'Player logout with incomplete chunked message')",
                player->GetGUID().GetCounter(),
                accountId,
                EscapeSQLString(player->GetName())
            );

            UpdateProtocolStats(player, "CHUNK", true, true, false);
        }

        s_ChunkedMessages.erase(accountId);
        s_ChunkStartTimes.erase(accountId);
        s_MessageTrackers.erase(accountId);

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
            return false;  // Not a valid chunk format
        }

        // Validate chunk parameters
        if (totalChunks == 0 || chunkIndex >= totalChunks)
            return false;

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

        // Store chunk
        auto& chunkedMsg = s_ChunkedMessages[accountId];
        if (chunkIndex == 0)
        {
            // First chunk - reset buffer
            chunkedMsg = DCAddon::ChunkedMessage();
            s_ChunkStartTimes[accountId] = GameTime::GetGameTime().count() * 1000;
        }

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
            LOG_INFO("module.dc", "[DC-CHUNK] player={}, reassembled message ready, len={}",
                player->GetName(), rawPayload.length());
        }

        std::string payload = rawPayload;
        
        // Early logging: show ALL incoming DC messages
        uint8 incomingOpcode = ExtractOpcode(payload);
        LOG_INFO("module.dc", "[DC-INCOMING] player={}, module={}, opcode=0x{:02X}, payloadLen={}",
            player->GetName(), ExtractModuleCode(payload), incomingOpcode, payload.length());

        // Check rate limit before processing. Allow a small bypass list for UI-critical requests.
        bool shouldBypass = ShouldBypassRateLimit(payload);
        bool passedRateLimit = CheckRateLimit(player);
        
        if (!shouldBypass && !passedRateLimit)
        {
            // Log dropped messages for diagnostics
            uint8 droppedOpcode = ExtractOpcode(payload);
            LOG_INFO("module.dc", "[RateLimit] DROPPED message from {}: module={}, opcode=0x{:02X} (bypass={}, rateOk={})",
                player->GetName(), ExtractModuleCode(payload), droppedOpcode, shouldBypass, passedRateLimit);
            msg.clear();
            return;
        }

        if (s_AddonConfig.EnableDebugLog)
            LOG_DEBUG("dc.addon", "Routing DC message from {}: {}", player->GetName(), payload);

        // Parse module and opcode for logging
        // Note: We use the extracted module code which might be formatted nicely or raw
        std::string moduleStr = ExtractModuleCode(payload);

        // Route the message
        bool handled = DCAddon::MessageRouter::Instance().Route(player, payload);

        // Log to database if protocol logging is enabled
        if (s_AddonConfig.EnableProtocolLogging && !moduleStr.empty())
        {
            std::string errorMsg;
            if (!handled)
                errorMsg = "No handler for module/opcode";

            LogC2SMessage(player, payload, handled, errorMsg);
            UpdateProtocolStats(player, moduleStr, true, false, !handled);  // request-side errors are tracked

            if (!handled)
                LogProtocolErrorEvent(player, payload, "unhandled", errorMsg);
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

class DCAddonWorldScript : public WorldScript
{
public:
    DCAddonWorldScript() : WorldScript("DCAddonWorldScript") {}

    void OnShutdown() override
    {
        // Flush all pending stats on server shutdown
        FlushStats();
    }

    void OnStartup() override
    {
        LoadAddonConfig();
        RegisterCoreHandlers();

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
};

// ============================================================================
// SCRIPT REGISTRATION
// ============================================================================

void AddSC_dc_addon_protocol()
{
    new DCAddonProtocolScript();
    new DCAddonMessageRouterScript();
    new DCAddonWorldScript();
}
