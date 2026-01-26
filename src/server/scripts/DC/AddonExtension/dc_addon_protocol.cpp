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
#include "DC/CrossSystem/CrossSystemSeasonHelper.h"
#include "DC/CrossSystem/EventBus.h"
#include "DC/CrossSystem/CrossSystemCore.h"
#include "ObjectAccessor.h"
#include <unordered_map>
#include <algorithm>
#include <cctype>
#include <memory>
#include <ctime>

// Forward declaration for S2C logging (defined later in file)
static bool g_S2CLoggingEnabled = false;
static void LogS2CMessageGlobal(Player* player, const std::string& module, uint8 opcode, size_t dataSize, bool updateStats, const std::string& payloadPreview);
static void LogProtocolErrorEvent(Player* player, const std::string& payload, const std::string& eventType, const std::string& message);
static void UpdateProtocolStats(Player* player, const std::string& moduleCode, bool isRequest, bool isTimeout, bool isError, uint32 responseTimeMs = 0);
static std::string EscapeSQLString(std::string s);

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

static void StoreClientCaps(Player* player, const std::string& clientVersionStr, uint32 clientCaps, uint32 negotiatedCaps)
{
    if (!player || !player->GetSession())
        return;

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
            LogS2CMessageGlobal(player, _module, _opcode, fullMessage.length(), effectiveRequestId.empty(), preview);
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
    uint64 startTimeMs = 0;
};

static std::unordered_map<uint32, std::unordered_map<std::string, PendingAddonRequest>> s_PendingRequests;
static std::mutex s_PendingRequestsMutex;

static void RegisterPendingRequest(Player* player, const DCAddon::ParsedMessage& msg)
{
    if (!player || !player->GetSession() || !msg.HasRequestId())
        return;

    PendingAddonRequest pending;
    pending.requestId = msg.GetRequestId();
    pending.module = msg.GetModule();
    pending.opcode = msg.GetOpcode();
    pending.guid = player->GetGUID().GetCounter();
    pending.startTimeMs = GameTime::GetGameTimeMS().count();

    uint32 accountId = player->GetSession()->GetAccountId();
    std::lock_guard<std::mutex> lock(s_PendingRequestsMutex);
    s_PendingRequests[accountId][pending.requestId] = std::move(pending);
}

static void CleanupExpiredRequests(Player* player)
{
    if (!player || !player->GetSession())
        return;

    uint32 accountId = player->GetSession()->GetAccountId();
    uint64 nowMs = GameTime::GetGameTimeMS().count();

    std::lock_guard<std::mutex> lock(s_PendingRequestsMutex);
    auto it = s_PendingRequests.find(accountId);
    if (it == s_PendingRequests.end())
        return;

    auto& pendingMap = it->second;
    for (auto reqIt = pendingMap.begin(); reqIt != pendingMap.end(); )
    {
        if (nowMs - reqIt->second.startTimeMs > s_AddonConfig.RequestTimeoutMs)
        {
            std::string payload = reqIt->second.module + DCAddon::DELIMITER + std::to_string(reqIt->second.opcode) +
                DCAddon::DELIMITER + "RID:" + reqIt->second.requestId;

            LogProtocolErrorEvent(player, payload, "timeout", "Addon request timed out");
            UpdateProtocolStats(player, reqIt->second.module, true, true, false);
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

namespace DCAddon
{
    void NotifyResponseSent(Player* player, const std::string& requestId)
    {
        if (!player || !player->GetSession() || requestId.empty())
            return;

        uint32 accountId = player->GetSession()->GetAccountId();
        uint64 nowMs = GameTime::GetGameTimeMS().count();

        std::lock_guard<std::mutex> lock(s_PendingRequestsMutex);
        auto accountIt = s_PendingRequests.find(accountId);
        if (accountIt == s_PendingRequests.end())
            return;

        auto& pendingMap = accountIt->second;
        auto reqIt = pendingMap.find(requestId);
        if (reqIt == pendingMap.end())
            return;

        uint32 responseTimeMs = static_cast<uint32>(nowMs - reqIt->second.startTimeMs);
        UpdateProtocolStats(player, reqIt->second.module, false, false, false, responseTimeMs);
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

    s_AddonConfig.EnableDebugLog        = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Debug.Enable", false);
    s_AddonConfig.EnableProtocolLogging = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Logging.Enable", false);
    s_AddonConfig.MaxMessagesPerSecond  = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.RateLimit.Messages", 30);
    s_AddonConfig.RateLimitAction       = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.RateLimit.Action", 0);
    s_AddonConfig.ChunkTimeoutMs        = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.ChunkTimeout", 5000);
    s_AddonConfig.RequestTimeoutMs      = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.RequestTimeoutMs", 8000);
    s_AddonConfig.MinGOMoveSecurity     = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.GOMove.MinSecurity", 1);
    s_AddonConfig.MinNPCMoveSecurity    = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.NPCMove.MinSecurity", 1);

    // Security limits (must match client-side DC.MAX_CHUNKS_PER_MESSAGE and DC.MAX_JSON_PAYLOAD_SIZE)
    s_AddonConfig.MaxChunksPerMessage   = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.Security.MaxChunksPerMessage", 200);
    s_AddonConfig.MaxJsonPayloadSize    = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.Security.MaxJsonPayloadSize", 131072);
    s_AddonConfig.MaxPendingChunks      = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.Security.MaxPendingChunks", 5);

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
    router.SetModuleEnabled(DCAddon::Module::NPCMOVE, s_AddonConfig.EnableNPCMove);
    router.SetModuleEnabled(DCAddon::Module::GROUP_FINDER, s_AddonConfig.EnableGroupFinder);
    router.SetModuleEnabled(DCAddon::Module::HOTSPOT, s_AddonConfig.EnableHotspot);
    router.SetModuleEnabled(DCAddon::Module::WORLD, s_AddonConfig.EnableWorld);
    router.SetModuleEnabled(DCAddon::Module::EVENTS, s_AddonConfig.EnableEvents);
    router.SetModuleEnabled(DCAddon::Module::QOS, s_AddonConfig.EnableQoS);
    router.SetModuleEnabled(DCAddon::Module::COLLECTION, s_AddonConfig.EnableCollection);
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
static void UpdateProtocolStats(Player* player, const std::string& moduleCode, bool isRequest, bool isTimeout, bool isError, uint32 responseTimeMs)
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

static void LogS2CMessageGlobal(Player* player, const std::string& module, uint8 opcode, size_t dataSize, bool updateStats, const std::string& payloadPreview)
{
    if (!player || !player->GetSession()) return;

    std::string safeModule = module;
    safeModule.erase(std::remove_if(safeModule.begin(), safeModule.end(), [](char c) { return !isalnum(c) && c != '_'; }), safeModule.end());
    if (safeModule.length() > 16) safeModule = safeModule.substr(0, 16);

    std::string requestType = (safeModule == "SPOT" || safeModule == "SEAS" || safeModule == "MHUD") ? "AIO" : (safeModule == "LBRD" ? "JSON" : "STANDARD");

    std::string preview = payloadPreview.length() > 255 ? payloadPreview.substr(0, 255) : payloadPreview;

    CharacterDatabase.Execute(
        "INSERT INTO dc_addon_protocol_log "
        "(guid, account_id, character_name, direction, request_type, module, opcode, data_size, data_preview, status) "
        "VALUES ({}, {}, '{}', 'S2C', '{}', '{}', {}, {}, '{}', 'completed')",
        player->GetGUID().GetCounter(),
        player->GetSession()->GetAccountId(),
        EscapeSQLString(player->GetName()),
        requestType,
        safeModule,
        opcode,
        dataSize,
        EscapeSQLString(preview)
    );

    if (updateStats)
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
    std::string clientVersionStr = NormalizeHandshakeVersionString(msg);

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
    DCAddon::Message ackMsg(DCAddon::Module::CORE, DCAddon::Opcode::Core::SMSG_HANDSHAKE_ACK);
    if (msg.HasRequestId())
        ackMsg.SetRequestId(msg.GetRequestId());
    ackMsg.Add(DCAddon::ProtocolVersion::BuildVersionString(serverVersion))
        .Add(compatible)
        .Add(negotiatedCaps)  // Negotiated capability flags
        .Send(player);

    // Store client addon caps/version per account
    StoreClientCaps(player, clientVersionStr, clientVersion.capabilities, negotiatedCaps);

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
        {
            std::lock_guard<std::mutex> lock(s_PendingRequestsMutex);
            s_PendingRequests.erase(accountId);
        }

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

        // Security limit: prevent memory exhaustion via excessive chunk count
        if (totalChunks > s_AddonConfig.MaxChunksPerMessage)
        {
            LOG_WARN("module.dc", "[DC-CHUNK] player={}, REJECTED: totalChunks={} exceeds limit {}",
                player->GetName(), totalChunks, s_AddonConfig.MaxChunksPerMessage);
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

        // Store chunk
        auto& chunkedMsg = s_ChunkedMessages[accountId];
        if (chunkIndex == 0)
        {
            // Security: Check if adding this would exceed max pending chunks
            // Count how many accounts have pending chunks (simple approach)
            if (s_ChunkedMessages.find(accountId) == s_ChunkedMessages.end() &&
                s_ChunkedMessages.size() >= s_AddonConfig.MaxPendingChunks * 10)  // Global limit = per-account * 10
            {
                LOG_WARN("module.dc", "[DC-CHUNK] player={}, REJECTED: global pending chunks limit reached ({})",
                    player->GetName(), s_ChunkedMessages.size());
                return false;
            }

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

        // Security limit: reject oversized payloads to prevent JSON parsing attacks
        if (payload.length() > s_AddonConfig.MaxJsonPayloadSize)
        {
            LOG_WARN("module.dc", "[DC-SECURITY] player={}, REJECTED: payload size {} exceeds limit {}",
                player->GetName(), payload.length(), s_AddonConfig.MaxJsonPayloadSize);
            msg.clear();
            return;
        }

        // Cleanup expired async requests for this player
        CleanupExpiredRequests(player);

        // Early logging: show ALL incoming DC messages
        uint8 incomingOpcode = ExtractOpcode(payload);
        LOG_INFO("module.dc", "[DC-INCOMING] player={}, module={}, opcode=0x{:02X}, payloadLen={}",
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
                LOG_INFO("module.dc", "[RateLimit] DROPPED message from {}: module={}, opcode=0x{:02X}",
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
        if (parsed.IsValid())
        {
            RegisterPendingRequest(player, parsed);

            // Capture handshake caps even if CORE module is disabled
            if (parsed.GetModule() == DCAddon::Module::CORE && parsed.GetOpcode() == DCAddon::Opcode::Core::CMSG_HANDSHAKE)
            {
                std::string clientVersionStr = NormalizeHandshakeVersionString(parsed);
                auto clientVersion = DCAddon::ProtocolVersion::ParseClientVersion(clientVersionStr);
                auto serverVersion = DCAddon::ProtocolVersion::GetServerVersion();
                uint32 negotiatedCaps = clientVersion.capabilities & serverVersion.capabilities;
                StoreClientCaps(player, clientVersionStr, clientVersion.capabilities, negotiatedCaps);
            }
        }

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
