/*
 * Dark Chaos - Addon Protocol Core Implementation
 * ================================================
 * 
 * Main protocol handler that routes all DC addon messages.
 * Uses unified "DC" prefix with module-based routing.
 * 
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "DCAddonNamespace.h"
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
            for (const auto& chunk : chunks)
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
    
    // Security settings
    bool EnableDebugLog;
    bool EnableProtocolLogging;  // Log to dc_addon_protocol_log table
    uint32 MaxMessagesPerSecond;
    uint32 RateLimitAction;
    uint32 ChunkTimeoutMs;
    
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
    
    s_AddonConfig.EnableDebugLog        = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Debug.Enable", false);
    s_AddonConfig.EnableProtocolLogging = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Logging.Enable", false);
    s_AddonConfig.MaxMessagesPerSecond  = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.RateLimit.Messages", 30);
    s_AddonConfig.RateLimitAction       = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.RateLimit.Action", 0);
    s_AddonConfig.ChunkTimeoutMs        = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.ChunkTimeout", 5000);
    
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
}

// ============================================================================
// PROTOCOL LOGGING (to dc_addon_protocol_log table)
// ============================================================================

// Extract module code from payload (everything before first colon, max 8 chars)
static std::string ExtractModuleCode(const std::string& payload)
{
    if (payload.empty())
        return "UNKN";
    
    size_t colonPos = payload.find(':');
    if (colonPos != std::string::npos && colonPos > 0)
    {
        // Truncate to 8 chars max to fit the database column
        return payload.substr(0, std::min(colonPos, static_cast<size_t>(8)));
    }
    
    // No colon found, return first 8 chars or less
    return payload.substr(0, std::min(payload.length(), static_cast<size_t>(8)));
}

// Extract opcode from payload (number after first colon)
static uint8 ExtractOpcode(const std::string& payload)
{
    size_t colonPos = payload.find(':');
    if (colonPos == std::string::npos || colonPos + 1 >= payload.length())
        return 0;
    
    // Find the end of the opcode (next colon or end of string)
    size_t opcodeStart = colonPos + 1;
    size_t opcodeEnd = payload.find(':', opcodeStart);
    if (opcodeEnd == std::string::npos)
        opcodeEnd = payload.length();
    
    std::string opcodeStr = payload.substr(opcodeStart, opcodeEnd - opcodeStart);
    try {
        return static_cast<uint8>(std::stoul(opcodeStr));
    } catch (...) {
        return 0;
    }
}

// Detect request type from payload content
// Request types:
//   STANDARD  = Plain Blizzard addon message (no special format, just text)
//   DC_JSON   = DC Protocol with JSON payload (MODULE:OPCODE:{...} or MODULE[OPCODE]:{...})
//   DC_PLAIN  = DC Protocol with plain data (MODULE:OPCODE:data)
//   AIO       = AIO framework modules (SPOT, SEAS, MHUD)
static std::string DetectRequestType(const std::string& payload)
{
    if (payload.empty())
        return "STANDARD";
    
    // Check for AIO modules first (known AIO modules: SPOT = Spectator, SEAS = Seasonal, MHUD = M+ HUD)
    std::string moduleCode = ExtractModuleCode(payload);
    if (moduleCode == "SPOT" || moduleCode == "SEAS" || moduleCode == "MHUD")
        return "AIO";
    
    // Find where the data portion starts (after module and opcode)
    // Format 1: MODULE:OPCODE:DATA (colon delimited)
    // Format 2: MODULE[OPCODE]:DATA (bracket opcode)
    size_t dataStart = std::string::npos;
    
    // Check for bracket format first: MODULE[x]:
    size_t bracketClose = payload.find(']');
    if (bracketClose != std::string::npos && bracketClose + 1 < payload.length())
    {
        if (payload[bracketClose + 1] == ':')
            dataStart = bracketClose + 2;
    }
    
    // Check for double-colon format: MODULE:OPCODE:
    if (dataStart == std::string::npos)
    {
        size_t firstColon = payload.find(':');
        if (firstColon != std::string::npos)
        {
            size_t secondColon = payload.find(':', firstColon + 1);
            if (secondColon != std::string::npos && secondColon + 1 < payload.length())
                dataStart = secondColon + 1;
        }
    }
    
    // If we found a data portion, it's DC protocol
    if (dataStart != std::string::npos && dataStart < payload.length())
    {
        char firstDataChar = payload[dataStart];
        // Check if data portion starts with JSON
        if (firstDataChar == '{' || firstDataChar == '[')
            return "DC_JSON";
        else
            return "DC_PLAIN";
    }
    
    // Check if it looks like DC protocol at all (has MODULE:OPCODE format even without data)
    size_t firstColon = payload.find(':');
    if (firstColon != std::string::npos && firstColon < 8)
    {
        // Has a short module code followed by colon - likely DC protocol
        return "DC_PLAIN";
    }
    
    // Plain Blizzard addon message (no DC protocol format detected)
    return "STANDARD";
}
// Log C2S (Client to Server) message to database
static void LogC2SMessage(Player* player, const std::string& payload, bool handled, const std::string& errorMsg = "")
{
    if (!s_AddonConfig.EnableProtocolLogging || !player || !player->GetSession())
        return;

    std::string moduleCode = ExtractModuleCode(payload);
    // Ensure module code is safe for SQL and fits column (max 16 chars)
    if (moduleCode.length() > 16)
        moduleCode = moduleCode.substr(0, 16);
    // Remove any single quotes from module code
    moduleCode.erase(std::remove(moduleCode.begin(), moduleCode.end(), '\''), moduleCode.end());
    
    uint8 opcode = ExtractOpcode(payload);
    std::string requestType = DetectRequestType(payload);
    std::string status = handled ? "completed" : (errorMsg.empty() ? "pending" : "error");
    std::string preview = payload.length() > 255 ? payload.substr(0, 255) : payload;
    
    // Escape single quotes in preview
    size_t pos = 0;
    while ((pos = preview.find("'", pos)) != std::string::npos)
    {
        preview.replace(pos, 1, "''");
        pos += 2;
    }
    
    // Escape error message
    std::string safeError = errorMsg;
    pos = 0;
    while ((pos = safeError.find("'", pos)) != std::string::npos)
    {
        safeError.replace(pos, 1, "''");
        pos += 2;
    }

    CharacterDatabase.Execute(
        "INSERT INTO dc_addon_protocol_log "
        "(guid, account_id, character_name, direction, request_type, module, opcode, data_size, data_preview, status, error_message) "
        "VALUES ({}, {}, '{}', 'C2S', '{}', '{}', {}, {}, '{}', '{}', '{}')",
        player->GetGUID().GetCounter(),
        player->GetSession()->GetAccountId(),
        player->GetName(),
        requestType,
        moduleCode,
        opcode,
        payload.length(),
        preview,
        status,
        safeError);
}

// Log S2C (Server to Client) message to database
static void LogS2CMessage(Player* player, const std::string& payload)
{
    if (!s_AddonConfig.EnableProtocolLogging || !player || !player->GetSession())
        return;

    std::string moduleCode = ExtractModuleCode(payload);
    // Ensure module code is safe for SQL and fits column (max 16 chars)
    if (moduleCode.length() > 16)
        moduleCode = moduleCode.substr(0, 16);
    moduleCode.erase(std::remove(moduleCode.begin(), moduleCode.end(), '\''), moduleCode.end());
    
    uint8 opcode = ExtractOpcode(payload);
    std::string requestType = DetectRequestType(payload);
    std::string preview = payload.length() > 255 ? payload.substr(0, 255) : payload;
    
    // Escape single quotes in preview
    size_t pos = 0;
    while ((pos = preview.find("'", pos)) != std::string::npos)
    {
        preview.replace(pos, 1, "''");
        pos += 2;
    }

    CharacterDatabase.Execute(
        "INSERT INTO dc_addon_protocol_log "
        "(guid, account_id, character_name, direction, request_type, module, opcode, data_size, data_preview, status) "
        "VALUES ({}, {}, '{}', 'S2C', '{}', '{}', {}, {}, '{}', 'completed')",
        player->GetGUID().GetCounter(),
        player->GetSession()->GetAccountId(),
        player->GetName(),
        requestType,
        moduleCode,
        opcode,
        payload.length(),
        preview);
}

// Update player statistics in dc_addon_protocol_stats
static void UpdateProtocolStats(Player* player, const std::string& moduleCode, bool isRequest, bool isTimeout = false, bool isError = false, uint32 responseTimeMs = 0)
{
    if (!s_AddonConfig.EnableProtocolLogging || !player)
        return;

    // Ensure module code is safe for SQL
    std::string safeModuleCode = moduleCode;
    if (safeModuleCode.length() > 16)
        safeModuleCode = safeModuleCode.substr(0, 16);
    safeModuleCode.erase(std::remove(safeModuleCode.begin(), safeModuleCode.end(), '\''), safeModuleCode.end());

    uint32 guid = player->GetGUID().GetCounter();
    
    if (isRequest)
    {
        CharacterDatabase.Execute(
            "INSERT INTO dc_addon_protocol_stats (guid, module, total_requests, first_request, last_request) "
            "VALUES ({}, '{}', 1, NOW(), NOW()) "
            "ON DUPLICATE KEY UPDATE total_requests = total_requests + 1, last_request = NOW()",
            guid, safeModuleCode);
    }
    else
    {
        std::string updateFields = "total_responses = total_responses + 1";
        if (isTimeout)
            updateFields = "total_timeouts = total_timeouts + 1";
        else if (isError)
            updateFields = "total_errors = total_errors + 1";
        
        if (responseTimeMs > 0)
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_addon_protocol_stats (guid, module, {}, avg_response_time_ms, max_response_time_ms, last_request) "
                "VALUES ({}, '{}', 1, {}, {}, NOW()) "
                "ON DUPLICATE KEY UPDATE {} = {} + 1, "
                "avg_response_time_ms = (avg_response_time_ms * (total_responses - 1) + {}) / total_responses, "
                "max_response_time_ms = GREATEST(max_response_time_ms, {}), "
                "last_request = NOW()",
                isTimeout ? "total_timeouts" : (isError ? "total_errors" : "total_responses"),
                guid, safeModuleCode, responseTimeMs, responseTimeMs,
                isTimeout ? "total_timeouts" : (isError ? "total_errors" : "total_responses"),
                isTimeout ? "total_timeouts" : (isError ? "total_errors" : "total_responses"),
                responseTimeMs, responseTimeMs);
        }
        else
        {
            CharacterDatabase.Execute(
                "UPDATE dc_addon_protocol_stats SET {}, last_request = NOW() "
                "WHERE guid = {} AND module = '{}'",
                updateFields, guid, safeModuleCode);
        }
    }
}

// Global S2C logging function (called from Message::Send)
// Determines request type based on module (AIO modules use AIO, LBRD uses JSON, others STANDARD)
static void LogS2CMessageGlobal(Player* player, const std::string& module, uint8 opcode, size_t dataSize)
{
    if (!player || !player->GetSession())
        return;
    
    // Ensure module code is safe for SQL and fits column (max 16 chars)
    std::string safeModule = module;
    if (safeModule.length() > 16)
        safeModule = safeModule.substr(0, 16);
    safeModule.erase(std::remove(safeModule.begin(), safeModule.end(), '\''), safeModule.end());
    
    // Determine request type based on module
    std::string requestType = "STANDARD";
    if (safeModule == "SPOT" || safeModule == "SEAS" || safeModule == "MHUD")
        requestType = "AIO";
    else if (safeModule == "LBRD")
        requestType = "JSON";
    
    CharacterDatabase.Execute(
        "INSERT INTO dc_addon_protocol_log "
        "(guid, account_id, character_name, direction, request_type, module, opcode, data_size, data_preview, status) "
        "VALUES ({}, {}, '{}', 'S2C', '{}', '{}', {}, {}, '', 'completed')",
        player->GetGUID().GetCounter(),
        player->GetSession()->GetAccountId(),
        player->GetName(),
        requestType,
        safeModule,
        opcode,
        dataSize);
    
    // Also update stats for S2C
    CharacterDatabase.Execute(
        "INSERT INTO dc_addon_protocol_stats (guid, module, total_responses, first_request, last_request) "
        "VALUES ({}, '{}', 1, NOW(), NOW()) "
        "ON DUPLICATE KEY UPDATE total_responses = total_responses + 1, last_request = NOW()",
        player->GetGUID().GetCounter(), safeModule);
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
};

static std::unordered_map<uint32, PlayerMessageTracker> s_MessageTrackers;

[[maybe_unused]]
static bool CheckRateLimit(Player* player)
{
    uint32 accountId = player->GetSession()->GetAccountId();
    uint32 now = GameTime::GetGameTime().count();
    
    auto& tracker = s_MessageTrackers[accountId];
    
    // Check if muted
    if (tracker.isMuted && now < tracker.muteExpireTime)
        return false;
    else if (tracker.isMuted)
        tracker.isMuted = false;
    
    // Reset counter if second has passed
    if (now > tracker.lastResetTime)
    {
        tracker.messageCount = 0;
        tracker.lastResetTime = now;
    }
    
    tracker.messageCount++;
    
    if (tracker.messageCount > s_AddonConfig.MaxMessagesPerSecond)
    {
        switch (s_AddonConfig.RateLimitAction)
        {
            case 1:  // Disconnect
                player->GetSession()->KickPlayer("Addon message spam");
                LOG_WARN("dc.addon", "Player {} kicked for addon message spam", player->GetName());
                break;
            case 2:  // Mute for 60 seconds
                tracker.isMuted = true;
                tracker.muteExpireTime = now + 60;
                LOG_WARN("dc.addon", "Player {} muted for addon message spam", player->GetName());
                break;
            default:  // Log and drop
                if (s_AddonConfig.EnableDebugLog)
                    LOG_DEBUG("dc.addon", "Rate limit exceeded for player {}", player->GetName());
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
    // Client says hello, server acknowledges with version and enabled features
    std::string clientVersion = msg.GetString(0);
    
    if (s_AddonConfig.EnableDebugLog)
        LOG_DEBUG("dc.addon", "Handshake from {} with client version {}", 
                  player->GetName(), clientVersion);
    
    // Send acknowledgment with server protocol version
    DCAddon::Message(DCAddon::Module::CORE, DCAddon::Opcode::Core::SMSG_HANDSHAKE_ACK)
        .Add(s_AddonConfig.ProtocolVersion)
        .Add(true)  // Handshake success
        .Send(player);
    
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
    featureMsg.Send(player);
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
    featureMsg.Send(player);
}

static void RegisterCoreHandlers()
{
    using namespace DCAddon;
    
    DC_REGISTER_HANDLER(Module::CORE, Opcode::Core::CMSG_HANDSHAKE, HandleCoreHandshake);
    DC_REGISTER_HANDLER(Module::CORE, Opcode::Core::CMSG_VERSION_CHECK, HandleCoreVersionCheck);
    DC_REGISTER_HANDLER(Module::CORE, Opcode::Core::CMSG_FEATURE_QUERY, HandleCoreFeatureQuery);
}

// ============================================================================
// CHUNKED MESSAGE TRACKING
// ============================================================================

static std::unordered_map<uint32, DCAddon::ChunkedMessage> s_ChunkedMessages;
static std::unordered_map<uint32, uint32> s_ChunkStartTimes;

[[maybe_unused]]
static void CleanupExpiredChunks()
{
    uint32 now = GameTime::GetGameTime().count() * 1000;  // Convert to ms
    
    std::vector<uint32> toRemove;
    for (const auto& [accountId, startTime] : s_ChunkStartTimes)
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
        // Clean up any pending chunked messages
        uint32 accountId = player->GetSession()->GetAccountId();
        s_ChunkedMessages.erase(accountId);
        s_ChunkStartTimes.erase(accountId);
        s_MessageTrackers.erase(accountId);
    }
};

class DCAddonMessageRouterScript : public PlayerScript
{
public:
    DCAddonMessageRouterScript() : PlayerScript("DCAddonMessageRouterScript") {}
    
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
        
        // Skip the "DC\t" prefix and route to handler
        std::string payload = msg.substr(3);  // Everything after "DC\t"
        
        if (s_AddonConfig.EnableDebugLog)
            LOG_DEBUG("dc.addon", "Routing DC message from {}: {}", player->GetName(), payload);
        
        // Parse module and opcode for logging (format: "MODULE:OPCODE:DATA" or "MODULE:OPCODE")
        std::string moduleStr, opcodeStr, dataStr;
        size_t firstColon = payload.find(':');
        if (firstColon != std::string::npos)
        {
            moduleStr = payload.substr(0, firstColon);
            size_t secondColon = payload.find(':', firstColon + 1);
            if (secondColon != std::string::npos)
            {
                opcodeStr = payload.substr(firstColon + 1, secondColon - firstColon - 1);
                dataStr = payload.substr(secondColon + 1);
            }
            else
            {
                opcodeStr = payload.substr(firstColon + 1);
            }
        }
        
        // Route the message
        bool handled = DCAddon::MessageRouter::Instance().Route(player, payload);
        
        // Log to database if protocol logging is enabled
        if (s_AddonConfig.EnableProtocolLogging && !moduleStr.empty())
        {
            LogC2SMessage(player, payload, handled);
            UpdateProtocolStats(player, moduleStr, true);  // true = isRequest
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
    
    void OnStartup() override
    {
        LoadAddonConfig();
        RegisterCoreHandlers();
        
        LOG_INFO("dc.addon", "===========================================");
        LOG_INFO("dc.addon", "Dark Chaos Addon Protocol v{} loaded", s_AddonConfig.ProtocolVersion);
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
