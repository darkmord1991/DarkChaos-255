/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * 
 * DarkChaos MapExtension System - Automatic GPS Tracking
 * 
 * Provides real-time player position updates to client addons via AIO.
 * Features:
 * - Automatic GPS updates with configurable throttling
 * - Zone change detection for immediate updates
 * - DBC-based map bounds (no hardcoded values)
 * - Enhanced payload with orientation, speed, combat status, etc.
 * - Performance-optimized with per-player update tracking
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "GameTime.h"
#include "Map.h"
#include "AreaTableEntry.h"
#include "DBCStores.h"
#include "MapExtensionConstants.h"
#include <unordered_map>
#include <unordered_set>
#include <sstream>
#include <iomanip>

#ifdef HAS_AIO
#include "AIO.h"
#endif

using namespace MapExtensionConstants;

// =====================================================================
// Configuration Variables
// =====================================================================
static bool sMapExtensionEnabled = false;
static uint32 sGPSUpdateIntervalMS = GPS_UPDATE_INTERVAL_MS;
static std::unordered_set<uint32> sEnabledMaps;
static uint32 sLogLevel = 0; // 0=None, 1=Errors, 2=Warnings, 3=Debug

// =====================================================================
// External Map Bounds (from Hotspots system)
// =====================================================================
// Map bounds are populated by BuildMapBoundsFromDBC() in the Hotspots script
extern std::unordered_map<uint32, std::array<float,4>> sMapBounds;
extern void BuildMapBoundsFromDBC();

// =====================================================================
// Per-Player Tracking Data
// =====================================================================
struct PlayerGPSData
{
    uint32 lastUpdateTime = 0;      // GameTime in milliseconds
    uint32 lastZoneId = 0;           // Last known zone ID for change detection
    bool initialized = false;
};

static std::unordered_map<ObjectGuid, PlayerGPSData> sPlayerGPSTracking;

// =====================================================================
// Configuration Loading
// =====================================================================
static void LoadMapExtensionConfig()
{
    sMapExtensionEnabled = sConfigMgr->GetOption<bool>("MapExtension.Enable", true);
    sGPSUpdateIntervalMS = sConfigMgr->GetOption<uint32>("MapExtension.UpdateInterval", GPS_UPDATE_INTERVAL_MS);
    sLogLevel = sConfigMgr->GetOption<uint32>("MapExtension.LogLevel", 0);
    
    // Clamp update interval to valid range
    if (sGPSUpdateIntervalMS < MIN_UPDATE_INTERVAL_MS)
        sGPSUpdateIntervalMS = MIN_UPDATE_INTERVAL_MS;
    if (sGPSUpdateIntervalMS > MAX_UPDATE_INTERVAL_MS)
        sGPSUpdateIntervalMS = MAX_UPDATE_INTERVAL_MS;
    
    // Parse enabled maps
    std::string enabledMapsStr = sConfigMgr->GetOption<std::string>("MapExtension.EnabledMaps", "0,1,530,571,37");
    sEnabledMaps.clear();
    
    std::istringstream iss(enabledMapsStr);
    std::string token;
    while (std::getline(iss, token, ','))
    {
        try
        {
            uint32 mapId = std::stoul(token);
            sEnabledMaps.insert(mapId);
        }
        catch (...)
        {
            if (sLogLevel >= 2)
                LOG_WARN("scripts", "MapExtension: Invalid map ID '{}' in EnabledMaps config", token);
        }
    }
    
    if (sEnabledMaps.empty())
    {
        // Fallback to defaults
        for (size_t i = 0; i < DEFAULT_ENABLED_MAPS_COUNT; ++i)
            sEnabledMaps.insert(DEFAULT_ENABLED_MAPS[i]);
    }
    
    if (sLogLevel >= 3)
    {
        LOG_DEBUG("scripts", "MapExtension: Loaded config - Enabled={}, UpdateInterval={}ms, EnabledMaps={}",
            sMapExtensionEnabled, sGPSUpdateIntervalMS, enabledMapsStr);
    }
}

// =====================================================================
// Map Bounds Helper
// =====================================================================
// Compute normalized coordinates using DBC-derived map bounds
// Returns false if map has no bounds data
static bool ComputeNormalizedCoords(uint32 mapId, float x, float y, float& outNx, float& outNy)
{
    auto it = sMapBounds.find(mapId);
    if (it == sMapBounds.end())
        return false;
    
    auto const& b = it->second;
    float minX = b[0];
    float maxX = b[1];
    float minY = b[2];
    float maxY = b[3];
    
    if (maxX <= minX || maxY <= minY)
        return false;
    
    // Special case for Azshara Crater (map 37): Both axes are flipped
    // The map texture orientation doesn't match world coordinate orientation
    if (mapId == 37)
    {
        outNx = (maxX - x) / (maxX - minX);  // Flip X
        outNy = (maxY - y) / (maxY - minY);  // Flip Y
    }
    else
    {
        outNx = (x - minX) / (maxX - minX);
        outNy = (y - minY) / (maxY - minY);
    }
    
    // Clamp to 0-1 range
    outNx = std::max(0.0f, std::min(1.0f, outNx));
    outNy = std::max(0.0f, std::min(1.0f, outNy));
    
    return true;
}

// =====================================================================
// GPS Payload Construction
// =====================================================================
// Build GPS JSON payload with enhanced data
// Uses sprintf for performance and safety (no complex JSON library needed)
static std::string BuildGPSPayload(Player* player)
{
    if (!player)
        return "{}";
    
    uint32 mapId = player->GetMapId();
    uint32 zoneId = player->GetZoneId();
    uint32 areaId = player->GetAreaId();
    float x = player->GetPositionX();
    float y = player->GetPositionY();
    float z = player->GetPositionZ();
    float orientation = player->GetOrientation();
    
    // Compute normalized coordinates
    float nx = 0.0f, ny = 0.0f;
    bool hasNormalizedCoords = ComputeNormalizedCoords(mapId, x, y, nx, ny);
    
    // Enhanced data
    bool inCombat = player->IsInCombat();
    bool isMounted = player->IsMounted();
    bool isDead = !player->IsAlive();
    float speed = player->GetSpeed(MOVE_RUN);
    uint32 areaLevel = 0;
    
    // Get area level from DBC if available
    if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(areaId))
    {
        areaLevel = area->area_level;
    }
    
    // Build JSON with sprintf (safe and performant)
    // Format: {"mapId":X,"zoneId":X,"areaId":X,"x":X.XX,"y":X.XX,"z":X.XX,"nx":X.XXX,"ny":X.XXX,"o":X.XX,"speed":X.XX,"combat":0/1,"mounted":0/1,"dead":0/1,"areaLevel":X}
    char buffer[MAX_GPS_PAYLOAD_BYTES];
    int written = std::snprintf(buffer, sizeof(buffer),
        "{\"mapId\":%u,\"zoneId\":%u,\"areaId\":%u,"
        "\"x\":%.2f,\"y\":%.2f,\"z\":%.2f,"
        "\"nx\":%.3f,\"ny\":%.3f,\"o\":%.2f,"
        "\"speed\":%.2f,\"combat\":%d,\"mounted\":%d,\"dead\":%d,\"areaLevel\":%u,"
        "\"hasCoords\":%d}",
        mapId, zoneId, areaId,
        x, y, z,
        nx, ny, orientation,
        speed, inCombat ? 1 : 0, isMounted ? 1 : 0, isDead ? 1 : 0, areaLevel,
        hasNormalizedCoords ? 1 : 0
    );
    
    if (written < 0 || written >= (int)sizeof(buffer))
    {
        if (sLogLevel >= 1)
            LOG_ERROR("scripts", "MapExtension: GPS payload buffer overflow for player {} (GUID: {})",
                player->GetName(), player->GetGUID().ToString());
        return "{}";
    }
    
    return std::string(buffer);
}

// =====================================================================
// GPS Update Sender
// =====================================================================
static void SendGPSUpdate(Player* player, bool isZoneChange = false)
{
    if (!player || !sMapExtensionEnabled)
        return;
    
#ifndef HAS_AIO
    return; // AIO not available, cannot send updates
#endif
    
    uint32 mapId = player->GetMapId();
    
    // Check if map is enabled
    if (sEnabledMaps.find(mapId) == sEnabledMaps.end())
        return;
    
    try
    {
        std::string payload = BuildGPSPayload(player);
        
        if (payload.size() > MAX_GPS_PAYLOAD_BYTES)
        {
            if (sLogLevel >= 2)
                LOG_WARN("scripts", "MapExtension: GPS payload too large ({} bytes) for player {}",
                    payload.size(), player->GetName());
            return;
        }
        
#ifdef HAS_AIO
        const char* msgType = isZoneChange ? AIO_MSG_ZONE_CHANGE : AIO_MSG_UPDATE;
        AIO().Msg(player, AIO_ADDON_NAME, msgType, payload);
        
        if (sLogLevel >= 3)
        {
            LOG_DEBUG("scripts", "MapExtension: Sent GPS {} to player {} (GUID: {}) - Map:{} Zone:{} Payload:{} bytes",
                msgType, player->GetName(), player->GetGUID().ToString(),
                mapId, player->GetZoneId(), payload.size());
        }
#endif
    }
    catch (std::exception const& e)
    {
        if (sLogLevel >= 1)
            LOG_ERROR("scripts", "MapExtension: Exception sending GPS update to player {}: {}",
                player->GetName(), e.what());
    }
    catch (...)
    {
        if (sLogLevel >= 1)
            LOG_ERROR("scripts", "MapExtension: Unknown exception sending GPS update to player {}",
                player->GetName());
    }
}

// =====================================================================
// PlayerScript Implementation
// =====================================================================
class PlayerScript_MapExtension : public PlayerScript
{
public:
    PlayerScript_MapExtension() : PlayerScript("PlayerScript_MapExtension") { }
    
    // Initialize player tracking on login
    void OnLogin(Player* player) override
    {
        if (!sMapExtensionEnabled)
            return;
        
        ObjectGuid guid = player->GetGUID();
        PlayerGPSData& data = sPlayerGPSTracking[guid];
        data.lastUpdateTime = 0;
        data.lastZoneId = player->GetZoneId();
        data.initialized = true;
        
        // Send initial GPS update after 1 second
        SendGPSUpdate(player, false);
        
        if (sLogLevel >= 3)
        {
            LOG_DEBUG("scripts", "MapExtension: Initialized GPS tracking for player {} (GUID: {})",
                player->GetName(), guid.ToString());
        }
    }
    
    // Clean up tracking on logout
    void OnLogout(Player* player) override
    {
        ObjectGuid guid = player->GetGUID();
        sPlayerGPSTracking.erase(guid);
        
        if (sLogLevel >= 3)
        {
            LOG_DEBUG("scripts", "MapExtension: Removed GPS tracking for player {} (GUID: {})",
                player->GetName(), guid.ToString());
        }
    }
    
    // Automatic GPS updates with throttling
    void OnUpdate(Player* player, uint32 diff) override
    {
        if (!sMapExtensionEnabled)
            return;
        
        ObjectGuid guid = player->GetGUID();
        auto it = sPlayerGPSTracking.find(guid);
        if (it == sPlayerGPSTracking.end())
            return; // Not initialized
        
        PlayerGPSData& data = it->second;
        uint32 currentTime = GameTime::GetGameTimeMS().count();
        
        // Check if enough time has passed since last update
        if (currentTime - data.lastUpdateTime >= sGPSUpdateIntervalMS)
        {
            SendGPSUpdate(player, false);
            data.lastUpdateTime = currentTime;
        }
    }
    
    // Immediate GPS update on zone change
    void OnUpdateZone(Player* player, uint32 newZone, uint32 /*newArea*/) override
    {
        if (!sMapExtensionEnabled)
            return;
        
        ObjectGuid guid = player->GetGUID();
        auto it = sPlayerGPSTracking.find(guid);
        if (it == sPlayerGPSTracking.end())
            return;
        
        PlayerGPSData& data = it->second;
        
        // Only send update if zone actually changed
        if (data.lastZoneId != newZone)
        {
            SendGPSUpdate(player, true);
            data.lastZoneId = newZone;
            data.lastUpdateTime = GameTime::GetGameTimeMS().count(); // Reset throttle timer
            
            if (sLogLevel >= 3)
            {
                LOG_DEBUG("scripts", "MapExtension: Zone change detected for player {} - Old:{} New:{}",
                    player->GetName(), data.lastZoneId, newZone);
            }
        }
    }
};

// =====================================================================
// World Script for System Initialization
// =====================================================================
class WorldScript_MapExtension : public WorldScript
{
public:
    WorldScript_MapExtension() : WorldScript("WorldScript_MapExtension") { }
    
    void OnStartup() override
    {
        // Load configuration
        LoadMapExtensionConfig();
        
        if (!sMapExtensionEnabled)
        {
            LOG_INFO("scripts", "MapExtension: System DISABLED by config");
            return;
        }
        
#ifndef HAS_AIO
        LOG_ERROR("scripts", "MapExtension: System enabled but AIO (HAS_AIO) is NOT compiled! GPS updates will not work.");
        return;
#endif
        
        // Initialize map bounds from DBC if not already done
        if (sMapBounds.empty())
        {
            LOG_INFO("scripts", "MapExtension: Building map bounds from DBC...");
            BuildMapBoundsFromDBC();
            LOG_INFO("scripts", "MapExtension: Map bounds loaded ({} maps)", sMapBounds.size());
        }
        
        LOG_INFO("scripts", "MapExtension: System initialized - UpdateInterval={}ms, EnabledMaps={} maps",
            sGPSUpdateIntervalMS, sEnabledMaps.size());
    }
    
    void OnConfigLoad(bool /*reload*/) override
    {
        LoadMapExtensionConfig();
        
        if (sLogLevel >= 2)
            LOG_WARN("scripts", "MapExtension: Configuration reloaded");
    }
};

// =====================================================================
// Script Registration
// =====================================================================
void AddSC_PlayerScript_MapExtension()
{
    new PlayerScript_MapExtension();
    new WorldScript_MapExtension();
}
