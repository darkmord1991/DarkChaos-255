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
#include "Log.h"
#include "Config.h"
#include "GameTime.h"
#include <unordered_map>

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
        WorldPacket data;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, msg);
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
    
    // Security settings
    bool EnableDebugLog;
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
    
    s_AddonConfig.EnableDebugLog        = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Debug.Enable", false);
    s_AddonConfig.MaxMessagesPerSecond  = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.RateLimit.Messages", 30);
    s_AddonConfig.RateLimitAction       = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.RateLimit.Action", 0);
    s_AddonConfig.ChunkTimeoutMs        = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.ChunkTimeout", 5000);
    
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
    
    // Note: AzerothCore PlayerScript doesn't have OnBeforeSendChatMessage
    // Addon message handling is done via OnChat hooks or custom implementation
    // This script is a placeholder for future expansion
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
