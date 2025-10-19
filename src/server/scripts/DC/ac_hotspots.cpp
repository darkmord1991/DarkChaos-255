/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * 
 * DarkChaos Hotspots System
 * 
 * Randomly spawns XP bonus zones ("hotspots") across configured maps/zones.
 * Players entering a hotspot receive:
 *   - Visual entry aura (cloud effect)
 *   - Persistent buff icon (flag)
 *   - 100% (or configured) XP bonus from kills
 * 
 * Hotspots show on minimap/map as golden arrows or green crosses when nearby.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "World.h"
#include "Chat.h"
#include "WorldSessionMgr.h"
#include "MapMgr.h"
#include "ObjectMgr.h"
#include "GameTime.h"
#include "StringConvert.h"
#include "GameObject.h"
#include "ObjectAccessor.h"
#include "DBCStores.h"
#include "DBCStore.h"

// Optional ADT/WDT parser headers (present in tools extractor). Guarded so file still
// compiles when extractor headers are not available in server include paths.
#if defined(__has_include)
# if __has_include(<wdtfile.h>) && __has_include(<adtfile.h>)
#  include <wdtfile.h>
#  include <adtfile.h>
#  define HOTSPOT_HAVE_ADT_WDT 1
# else
#  define HOTSPOT_HAVE_ADT_WDT 0
# endif
#else
# define HOTSPOT_HAVE_ADT_WDT 0
#endif
#include <sstream>
#include <iomanip>
#include <cmath>
#include <algorithm>
#include <unordered_map>
#include <vector>
#include <random>
#include <filesystem>
#include <fstream>

using namespace Acore::ChatCommands;

// Note: some builds (including this one) don't expose WorldMapArea DBC storage
// (sWorldMapAreaStore is commented out in DBCStores.h). We therefore do not
// rely on it; map bounds are loaded from CSV or computed via client ADT/WDT
// parsing when available.

// Configuration cache
struct HotspotsConfig
{
    bool enabled = true;
    uint32 duration = 60;                    // minutes
    uint32 experienceBonus = 100;            // percentage
    float radius = 150.0f;                   // yards
    uint32 maxActive = 5;
    uint32 respawnDelay = 30;                // minutes
    uint32 initialPopulateCount = 0;         // 0 = disabled (default: 0 -> populate to maxActive)
    uint32 auraSpell = 800001;               // Custom hotspot XP buff spell
    uint32 buffSpell = 800001;               // Custom hotspot XP buff spell with spellscript that handles XP multiplication
                                             // Spell ID 800001 must have a spellscript that applies the XP bonus
                                             // See: src/server/scripts/DC/spell_hotspot_buff_800001.cpp
    uint32 minimapIcon = 1;                  // 1=arrow, 2=cross
    float announceRadius = 500.0f;           // yards
    std::vector<uint32> enabledMaps;
    std::vector<uint32> enabledZones;
    std::vector<uint32> excludedZones;
    // Per-map zone allow list: mapId -> list of allowed zone IDs (if present, this overrides global enabled/excluded lists)
    std::unordered_map<uint32, std::vector<uint32>> enabledZonesPerMap;
    bool announceSpawn = true;
    bool announceExpire = true;
    bool spawnVisualMarker = true;           // Spawn GameObject marker
    uint32 markerGameObjectEntry = 179976;   // Alliance Flag (shows on map)
};

static HotspotsConfig sHotspotsConfig;

// Minimal server-side map bounds used to normalize world coordinates into 0..1 for client helpers.
// These are approximate and can be improved later with DBC-driven values.
static std::unordered_map<uint32, std::array<float,4>> sMapBounds;

// Helper: create or get a base (non-instanced) Map object safely and log on failure.
static Map* GetBaseMapSafe(uint32 mapId)
{
    Map* map = sMapMgr->CreateBaseMap(mapId);
    if (!map)
        LOG_WARN("scripts", "GetBaseMapSafe: could not create/find Map object for map id {}", mapId);
    return map;
}

// Build map bounds from DBC WorldMapArea entries. This attempts to compute accurate
// map extents by aggregating all WorldMapArea entries for a given map_id.
static void BuildMapBoundsFromDBC()
{
    // WorldMapArea.dbc-based bounds are not available in this build. sWorldMapAreaStore
    // is intentionally not exported in DBCStores.h. We'll rely on CSV and runtime
    // ADT/WDT parsing (if available) to populate sMapBounds instead.
    sMapBounds.clear();
    LOG_INFO("scripts", "Skipping DBC-derived map bounds: WorldMapArea DBC not available; rely on CSV or client data");
}

// Load additional map bounds from an optional CSV file: var/map_bounds.csv
// CSV format: mapId,minX,maxX,minY,maxY,source
static void LoadMapBoundsFromCSV()
{
    std::string csvPath = "var/map_bounds.csv";
    if (!std::filesystem::exists(csvPath))
        return;

    std::ifstream ifs(csvPath);
    if (!ifs)
    {
        LOG_WARN("scripts", "Could not open map bounds CSV {}", csvPath);
        return;
    }

    std::string line;
    // skip header if present
    auto trim = [](std::string s) {
        const char* ws = " \t\r\n";
        size_t a = s.find_first_not_of(ws);
        if (a == std::string::npos) return std::string();
        size_t b = s.find_last_not_of(ws);
        return s.substr(a, b - a + 1);
    };

    // Peek first non-empty line to detect header
    std::streampos pos = ifs.tellg();
    bool firstIsHeader = false;
    while (std::getline(ifs, line))
    {
        line = trim(line);
        if (line.empty()) continue;
        // check if header-like
        if (line.rfind("mapId", 0) == 0 || line.find("minX") != std::string::npos)
            firstIsHeader = true;
        break;
    }
    // rewind to beginning for normal processing
    ifs.clear();
    ifs.seekg(pos);
    if (firstIsHeader)
    {
        // consume header line
        std::getline(ifs, line);
    }

    while (std::getline(ifs, line))
    {
        if (line.empty()) continue;
        std::istringstream ss(line);
        std::string tok;
        uint32 mapId = 0;
        float minX=0, maxX=0, minY=0, maxY=0;

        // simple CSV split by comma
        std::vector<std::string> cols;
        while (std::getline(ss, tok, ',')) cols.push_back(tok);
        if (cols.size() < 5) continue;
        // trim columns
        for (auto &c : cols) c = trim(c);
        // first column may be a numeric mapId or a map name (internal folder name)
        if (Optional<uint32> mv = Acore::StringTo<uint32>(cols[0]))
            mapId = *mv;
        else
        {
            // try to resolve map name to id using sMapStore
            std::string mapName = cols[0];
            for (MapEntry const* me : sMapStore)
            {
                if (!me) continue;
                if (me->name[0] && mapName == std::string(me->name[0]))
                {
                    mapId = me->MapID;
                    break;
                }
            }
            if (mapId == 0)
            {
                LOG_WARN("scripts", "Map bounds CSV: could not resolve map name '{}' to id; skipping", mapName);
                continue;
            }
        }
        try { minX = std::stof(cols[1]); maxX = std::stof(cols[2]); minY = std::stof(cols[3]); maxY = std::stof(cols[4]); }
        catch (...) { continue; }

        // Do not overwrite existing DBC-derived bounds unless CSV explicitly intended to override
        if (sMapBounds.find(mapId) == sMapBounds.end())
        {
            sMapBounds.emplace(mapId, std::array<float,4>{minX, maxX, minY, maxY});
            LOG_INFO("scripts", "Loaded map bounds from CSV for map {} -> [{},{},{},{}]", mapId, minX, maxX, minY, maxY);
        }
    }

    ifs.close();
}

// Try runtime WDT/ADT parsing using included extractor headers to discover which ADT tiles exist
// and compute tile-based bounds for maps missing DBC rows.
// This is a conservative tile-based approach using ADT presence. It requires client data available
// under the configured data path (default: "Data/" or "data/World/Maps/").
static void TryLoadBoundsFromClientData(const std::string& clientDataPath)
{
    // Look for World/Maps folder inside clientDataPath
    std::string mapsRoot = clientDataPath;
    if (mapsRoot.back() != '/' && mapsRoot.back() != '\\')
        mapsRoot += '/';
    mapsRoot += "World/Maps/";

    if (!std::filesystem::exists(mapsRoot))
    {
        // Try lowercase 'data' layout
        mapsRoot = clientDataPath;
        if (mapsRoot.back() != '/' && mapsRoot.back() != '\\')
            mapsRoot += '/';
        mapsRoot += "data/World/Maps/";
        if (!std::filesystem::exists(mapsRoot))
        {
            LOG_INFO("scripts", "Client map data path not found for ADT/WDT parsing: {}", clientDataPath);
            return;
        }
    }

    // For each map directory present, try to open WDT and scan tiles
    for (auto const& mapDirEntry : std::filesystem::directory_iterator(mapsRoot))
    {
        if (!mapDirEntry.is_directory()) continue;
        std::string mapName = mapDirEntry.path().filename().string();

        // attempt to find map id from name via DBC (map name -> map id) by scanning sMapStore
        // We will scan sMapStore for an entry whose internal_name matches mapName
        uint32 mapId = 0;
        for (MapEntry const* me : sMapStore)
        {
            if (!me) continue;
            // MapEntry::name is an array of localized name pointers; compare against the primary name
            if (me->name[0] && mapName == std::string(me->name[0]))
            {
                mapId = me->MapID;
                break;
            }
        }

        if (mapId == 0)
            continue;

        // If we already have bounds (from DBC or CSV) skip
        if (sMapBounds.find(mapId) != sMapBounds.end())
            continue;

        // Compose WDT path
        std::string wdtPath = mapDirEntry.path().string();
        if (!wdtPath.empty() && wdtPath.back() != '/' && wdtPath.back() != '\\')
            wdtPath += '/';
        wdtPath += mapName + ".wdt";
        if (!std::filesystem::exists(wdtPath))
            continue;

#if HOTSPOT_HAVE_ADT_WDT
        // Use WDTFile to detect existing tiles if extractor headers are available.
        std::string wdtCStr = wdtPath;
        WDTFile WDT(wdtCStr.c_str(), mapName.c_str());
        if (!WDT.init(mapId))
            continue;

        int minTileX = INT_MAX, maxTileX = INT_MIN, minTileY = INT_MAX, maxTileY = INT_MIN;
        for (int tx = 0; tx < 64; ++tx)
        {
            for (int ty = 0; ty < 64; ++ty)
            {
                if (ADTFile* ADT = WDT.GetMap(tx, ty))
                {
                    // Tile exists
                    minTileX = std::min(minTileX, tx);
                    maxTileX = std::max(maxTileX, tx);
                    minTileY = std::min(minTileY, ty);
                    maxTileY = std::max(maxTileY, ty);
                    delete ADT;
                }
            }
        }

        if (minTileX <= maxTileX && minTileY <= maxTileY)
        {
            // World tile size in WoW units (approx). ADT tile is 533.3333333 units.
            const float TILE_SIZE = 533.3333333f;
            float minX = minTileX * TILE_SIZE;
            float maxX = (maxTileX + 1) * TILE_SIZE;
            float minY = minTileY * TILE_SIZE;
            float maxY = (maxTileY + 1) * TILE_SIZE;

            sMapBounds.emplace(mapId, std::array<float,4>{minX, maxX, minY, maxY});
            LOG_INFO("scripts", "Computed map bounds from WDT/ADT for map {} ({}): tiles x={}..{} y={}..{} -> bounds [{}, {}, {}, {}]",
                     mapId, mapName, minTileX, maxTileX, minTileY, maxTileY, minX, maxX, minY, maxY);
        }
#else
        LOG_WARN("scripts", "WDT/ADT parser headers not available at compile time; skipping ADT/WDT parse for {}", mapName);
#endif
    }
}

// Compute normalized 0..1 coordinates for a world position using DBC WorldMapArea entries when possible.
// Returns true if normalized coords were computed, false if caller should fallback.
static bool ComputeNormalizedCoords(uint32 mapId, uint32 zoneId, float x, float y, float& outNx, float& outNy)
{

    // First, try to use DBC-provided zone->map helpers to compute zone-relative coords
    // Map2ZoneCoordinates converts world map coords into zone-relative percentages (0..100).
    {
        float tx = x;
        float ty = y;
        Map2ZoneCoordinates(tx, ty, zoneId);
        // If Map2ZoneCoordinates found a mapping, tx/ty should be in ~0..100 range.
        if (tx >= 0.0f && tx <= 100.0f && ty >= 0.0f && ty <= 100.0f)
        {
            outNx = tx / 100.0f;
            outNy = ty / 100.0f;
            outNx = std::max(0.0f, std::min(1.0f, outNx));
            outNy = std::max(0.0f, std::min(1.0f, outNy));
            return true;
        }
    }

    // Use CSV/DBC-derived sMapBounds if present
    auto it = sMapBounds.find(mapId);
    if (it != sMapBounds.end())
    {
        auto const& b = it->second;
        float minX = b[0];
        float maxX = b[1];
        float minY = b[2];
        float maxY = b[3];

        if (maxX <= minX || maxY <= minY)
            return false;

        outNx = (x - minX) / (maxX - minX);
        outNy = (y - minY) / (maxY - minY);
        // clamp
        outNx = std::max(0.0f, std::min(1.0f, outNx));
        outNy = std::max(0.0f, std::min(1.0f, outNy));
        return true;
    }

    // No bounds available: log once and provide conservative defaults (center)
    static bool warned = false;
    if (!warned)
    {
    LOG_WARN("scripts", "Hotspots: no map bounds available for mapId {} — normalized coords unavailable; enable tools to generate var/map_bounds.csv or provide client data", mapId);
        warned = true;
    }
    outNx = 0.5f;
    outNy = 0.5f;
    return false;
}

// Hotspot data structure
struct Hotspot
{
    uint32 id;
    uint32 mapId;
    uint32 zoneId;
    float x;
    float y;
    float z;
    time_t spawnTime;
    time_t expireTime;
    ObjectGuid gameObjectGuid;  // Visual marker GameObject

    bool IsActive() const
    {
        return GameTime::GetGameTime().count() < expireTime;
    }

    bool IsPlayerInRange(Player* player) const
    {
        if (!player)
            return false;
        
        if (player->GetMapId() != mapId)
            return false;

        float dx = player->GetPositionX() - x;
        float dy = player->GetPositionY() - y;
        float dz = player->GetPositionZ() - z;
        float dist = std::sqrt(dx*dx + dy*dy + dz*dz);
        
        bool inRange = dist <= sHotspotsConfig.radius;
        
        return inRange;
    }

    bool IsPlayerNearby(Player* player) const
    {
        if (!player || player->GetMapId() != mapId)
            return false;

        float dist = std::sqrt(
            std::pow(player->GetPositionX() - x, 2) +
            std::pow(player->GetPositionY() - y, 2) +
            std::pow(player->GetPositionZ() - z, 2)
        );

        return dist <= sHotspotsConfig.announceRadius;
    }
};

// Global hotspots storage
static std::vector<Hotspot> sActiveHotspots;
static uint32 sNextHotspotId = 1;
static time_t sLastSpawnCheck = 0;

// Public accessor functions for other scripts to query hotspot state
uint32 GetHotspotXPBonusPercentage()
{
    return sHotspotsConfig.experienceBonus;
}

uint32 GetHotspotBuffSpellId()
{
    return sHotspotsConfig.buffSpell;
}

bool IsPlayerInHotspot(Player* player)
{
    if (!player || !sHotspotsConfig.enabled)
        return false;
    
    uint32 mapId = player->GetMapId();
    float x = player->GetPositionX();
    float y = player->GetPositionY();
    
    for (const auto& hotspot : sActiveHotspots)
    {
        if (hotspot.mapId != mapId)
            continue;
        
        float dist = std::sqrt((x - hotspot.x) * (x - hotspot.x) + 
                               (y - hotspot.y) * (y - hotspot.y));
        if (dist <= sHotspotsConfig.radius)
            return true;
    }
    
    return false;
}

// Helper: parse comma-separated uint32 list
static std::vector<uint32> ParseUInt32List(std::string const& str)
{
    std::vector<uint32> result;
    if (str.empty())
        return result;

    std::istringstream ss(str);
    std::string token;
    while (std::getline(ss, token, ','))
    {
        token.erase(0, token.find_first_not_of(" \t\r\n"));
        token.erase(token.find_last_not_of(" \t\r\n") + 1);
        if (!token.empty())
        {
            if (Optional<uint32> val = Acore::StringTo<uint32>(token))
                result.push_back(*val);
        }
    }
    return result;
}

// Parse per-map zone configuration string like "1:141,331,17;37:268".
// Returns map<mapId, vector<zoneIds>>. A zoneId of 0 means 'all zones' for that map.
static std::unordered_map<uint32, std::vector<uint32>> ParseZonesPerMap(std::string const& str)
{
    std::unordered_map<uint32, std::vector<uint32>> result;
    if (str.empty())
        return result;

    std::istringstream ss(str);
    std::string entry;

    auto trim = [](std::string s) {
        const char* ws = " \t\r\n";
        size_t a = s.find_first_not_of(ws);
        if (a == std::string::npos) return std::string();
        size_t b = s.find_last_not_of(ws);
        return s.substr(a, b - a + 1);
    };

    // Split by ';' into entries
    while (std::getline(ss, entry, ';'))
    {
        entry = trim(entry);
        if (entry.empty()) continue;

        size_t colon = entry.find(':');
        if (colon == std::string::npos) continue;

        std::string mapTok = trim(entry.substr(0, colon));
        std::string zonesTok = trim(entry.substr(colon + 1));

        if (mapTok.empty() || zonesTok.empty()) continue;

        if (Optional<uint32> maybeMap = Acore::StringTo<uint32>(mapTok))
        {
            uint32 mapId = *maybeMap;
            std::vector<uint32> zones = ParseUInt32List(zonesTok);
            if (!zones.empty())
                result.emplace(mapId, std::move(zones));
        }
    }

    return result;
}

// Return hard-coded preset zone IDs used by the hotspot rectangles for a given map.
// This mirrors the zone IDs assigned in the coordinate presets and is used for
// startup diagnostics to show which presets exist for a map.
static std::vector<uint32> GetPresetZoneIdsForMap(uint32 mapId)
{
    switch (mapId)
    {
        case 0:  return {1, 10, 85};           // Dun Morogh, Duskwood, Tirisfal Glades
        case 1:  return {141, 331, 17};        // Teldrassil, Ashenvale, Barrens
        case 530: return {3524, 3520};         // Hellfire, Shadowmoon
        case 571: return {3537, 495};          // Borean Tundra, Howling Fjord
        case 37: return {268};                 // Azshara Crater (zone 268)
        default: return {};
    }
}

    // Helper: escape braces for fmt-style logging when message may contain '{' or '}'
    static std::string EscapeBraces(std::string const& s)
    {
        std::string out;
        out.reserve(s.size());
        for (char c : s)
        {
            if (c == '{' || c == '}')
            {
                out.push_back(c);
                out.push_back(c);
            }
            else
                out.push_back(c);
        }
        return out;
    }
            // Use CSV/DBC-derived sMapBounds if present
// Load configuration
static void LoadHotspotsConfig()
{
    sHotspotsConfig.enabled = sConfigMgr->GetOption<bool>("Hotspots.Enable", true);
    sHotspotsConfig.duration = sConfigMgr->GetOption<uint32>("Hotspots.Duration", 60);
    sHotspotsConfig.experienceBonus = sConfigMgr->GetOption<uint32>("Hotspots.ExperienceBonus", 100);
    sHotspotsConfig.radius = sConfigMgr->GetOption<float>("Hotspots.Radius", 150.0f);
    sHotspotsConfig.maxActive = sConfigMgr->GetOption<uint32>("Hotspots.MaxActive", 5);
    sHotspotsConfig.respawnDelay = sConfigMgr->GetOption<uint32>("Hotspots.RespawnDelay", 30);
    sHotspotsConfig.auraSpell = sConfigMgr->GetOption<uint32>("Hotspots.AuraSpell", 800001);
    sHotspotsConfig.buffSpell = sConfigMgr->GetOption<uint32>("Hotspots.BuffSpell", 800001);
    sHotspotsConfig.minimapIcon = sConfigMgr->GetOption<uint32>("Hotspots.MinimapIcon", 1);
    sHotspotsConfig.announceRadius = sConfigMgr->GetOption<float>("Hotspots.AnnounceRadius", 500.0f);
    sHotspotsConfig.announceSpawn = sConfigMgr->GetOption<bool>("Hotspots.AnnounceSpawn", true);
    sHotspotsConfig.announceExpire = sConfigMgr->GetOption<bool>("Hotspots.AnnounceExpire", true);
    sHotspotsConfig.spawnVisualMarker = sConfigMgr->GetOption<bool>("Hotspots.SpawnVisualMarker", true);
    sHotspotsConfig.markerGameObjectEntry = sConfigMgr->GetOption<uint32>("Hotspots.MarkerGameObjectEntry", 179976);

    std::string mapsStr = sConfigMgr->GetOption<std::string>("Hotspots.EnabledMaps", "0,1,530,571");
    sHotspotsConfig.enabledMaps = ParseUInt32List(mapsStr);

    std::string zonesStr = sConfigMgr->GetOption<std::string>("Hotspots.EnabledZones", "");
    sHotspotsConfig.enabledZones = ParseUInt32List(zonesStr);

    std::string excludedStr = sConfigMgr->GetOption<std::string>("Hotspots.ExcludedZones", "");
    sHotspotsConfig.excludedZones = ParseUInt32List(excludedStr);

    std::string perMapStr = sConfigMgr->GetOption<std::string>("Hotspots.EnabledZonesPerMap", "");
    sHotspotsConfig.enabledZonesPerMap = ParseZonesPerMap(perMapStr);

    sHotspotsConfig.initialPopulateCount = sConfigMgr->GetOption<uint32>("Hotspots.InitialPopulateCount", 0);
}

// Helper: check if map is enabled
static bool IsMapEnabled(uint32 mapId)
{
    if (sHotspotsConfig.enabledMaps.empty())
        return true;

    return std::find(sHotspotsConfig.enabledMaps.begin(), sHotspotsConfig.enabledMaps.end(), mapId)
        != sHotspotsConfig.enabledMaps.end();
}

// Helper: check if zone is allowed for a specific map.
// If a per-map list exists for the map, it overrides global enabled/excluded lists.
static bool IsZoneAllowed(uint32 mapId, uint32 zoneId)
{
    // If per-map configuration exists for this map, use it
    auto it = sHotspotsConfig.enabledZonesPerMap.find(mapId);
    if (it != sHotspotsConfig.enabledZonesPerMap.end())
    {
        const std::vector<uint32>& v = it->second;
        // zone 0 means 'all zones' for this map
        if (v.size() == 1 && v[0] == 0)
            return true;

        return std::find(v.begin(), v.end(), zoneId) != v.end();
    }

    // Check global excluded zones first
    if (std::find(sHotspotsConfig.excludedZones.begin(), sHotspotsConfig.excludedZones.end(), zoneId)
        != sHotspotsConfig.excludedZones.end())
        return false;

    // If enabled zones list is empty, allow all (that aren't excluded)
    if (sHotspotsConfig.enabledZones.empty())
        return true;

    // Otherwise check if zone is in enabled list
    return std::find(sHotspotsConfig.enabledZones.begin(), sHotspotsConfig.enabledZones.end(), zoneId)
        != sHotspotsConfig.enabledZones.end();
}

// Helper: get random position in enabled zone
static bool GetRandomHotspotPosition(uint32& outMapId, uint32& outZoneId, float& outX, float& outY, float& outZ)
{
    if (sHotspotsConfig.enabledMaps.empty())
    {
    LOG_WARN("scripts", "GetRandomHotspotPosition: no enabled maps configured (Hotspots.EnabledMaps is empty)");
        return false;
    }

    std::random_device rd;
    std::mt19937 gen(rd());

    // Copy and shuffle enabled maps so we try maps in random order and can fall back
    std::vector<uint32> maps = sHotspotsConfig.enabledMaps;
    std::shuffle(maps.begin(), maps.end(), gen);

    struct MapCoords
    {
        float minX, maxX, minY, maxY, z;
        uint32 zoneId;
    };

    const int attemptsPerRect = 12; // higher attempts per rectangle
    const int rectsPerMap = 6; // not used directly but indicative
    (void)rectsPerMap;

    for (uint32 candidateMapId : maps)
    {
        if (!IsMapEnabled(candidateMapId))
            continue;
        std::vector<MapCoords> coords;

        switch (candidateMapId)
        {
            case 0: // Eastern Kingdoms - sample zones
                coords = {
                    {-9000.0f, -8000.0f, -1000.0f, 0.0f, 50.0f, 1},      // Dun Morogh
                    {-5000.0f, -4000.0f, -3000.0f, -2000.0f, 50.0f, 10}, // Duskwood
                    {-11000.0f, -10000.0f, 1000.0f, 2000.0f, 50.0f, 85}, // Tirisfal Glades
                };
                break;
            case 1: // Kalimdor - sample zones
                coords = {
                    {9000.0f, 10000.0f, 1000.0f, 2000.0f, 50.0f, 141},   // Teldrassil
                    {-3000.0f, -2000.0f, -5000.0f, -4000.0f, 50.0f, 331}, // Ashenvale
                    {-7000.0f, -6000.0f, -4000.0f, -3000.0f, 50.0f, 17},  // Barrens
                };
                break;
            case 530: // Outland - sample zones
                coords = {
                    {-2000.0f, -1000.0f, 5000.0f, 6000.0f, 100.0f, 3524}, // Hellfire Peninsula
                    {2000.0f, 3000.0f, 5000.0f, 6000.0f, 100.0f, 3520},   // Shadowmoon Valley
                };
                break;
            case 571: // Northrend - sample zones
                coords = {
                    {2000.0f, 3000.0f, 5000.0f, 6000.0f, 100.0f, 3537},  // Borean Tundra
                    {4000.0f, 5000.0f, 1000.0f, 2000.0f, 100.0f, 495},   // Howling Fjord
                };
                break;
            case 37: // Azshara Crater - sample sub-areas based on reported coordinates (zone 268)
                coords = {
                    // northern rim area
                    {0.0f, 300.0f, 900.0f, 1200.0f, 295.0f, 268},
                    // central crater near reported point
                    {50.0f, 200.0f, 980.0f, 1060.0f, 295.0f, 268},
                    // western approach
                    {-100.0f, 100.0f, 850.0f, 1050.0f, 295.0f, 268},
                    // eastern slope
                    {100.0f, 400.0f, 1000.0f, 1300.0f, 295.0f, 268},
                };
                break;
            default:
                LOG_WARN("scripts", "GetRandomHotspotPosition: unsupported map id {} (skipping)", candidateMapId);
                continue;
        }

        if (coords.empty())
        {
            LOG_WARN("scripts", "GetRandomHotspotPosition: no coordinate presets defined for map {} (skipping)", candidateMapId);
            continue;
        }

        // Filter by allowed zones
        std::vector<MapCoords> allowedCoords;
        for (auto const& coord : coords)
        {
            if (IsZoneAllowed(candidateMapId, coord.zoneId))
                allowedCoords.push_back(coord);
        }

        if (allowedCoords.empty())
        {
            // If a per-map enabledZones list exists for this map, attempt a fallback
            // by sampling random points across the map bounds (if available). This
            // allows admins to enable zones by config without code-side presets.
            if (sHotspotsConfig.enabledZonesPerMap.find(candidateMapId) != sHotspotsConfig.enabledZonesPerMap.end())
            {
                auto itb = sMapBounds.find(candidateMapId);
                if (itb != sMapBounds.end())
                {
                    const auto& b = itb->second;
                    std::uniform_real_distribution<float> xb(b[0], b[1]);
                    std::uniform_real_distribution<float> yb(b[2], b[3]);
                    const int fallbackAttempts = 512; // increase attempts to improve chance of finding valid ground

                    // We'll need a Map* for sampling; create it once and reuse below
                    Map* map = nullptr;

                    // If we also might use preset rectangles later, create the map only when needed.
                    // Here, allowedCoords is empty, so we only create the map for fallback sampling.
                    map = GetBaseMapSafe(candidateMapId);
                    if (!map)
                    {
                        LOG_WARN("scripts", "GetRandomHotspotPosition: could not create/find Map object for map id {} during fallback sampling (skipping)", candidateMapId);
                        continue;
                    }
                    (void)map; // keep the variable reference semantics; actual ownership handled by MapMgr

                    // Log bounds for debug
                    LOG_DEBUG("scripts", "GetRandomHotspotPosition: fallback sampling bounds for map {} -> [{}, {}, {}, {}]", candidateMapId, b[0], b[1], b[2], b[3]);

                    for (int fa = 0; fa < fallbackAttempts; ++fa)
                    {
                        float candX = xb(gen);
                        float candY = yb(gen);

                        // Try regular height lookup (vmap + grid)
                        float groundZ = map->GetHeight(candX, candY, MAX_HEIGHT);

                        // If no valid ground found, try again disabling VMAP search to use grid height
                        if ((!std::isfinite(groundZ) || groundZ <= MIN_HEIGHT))
                        {
                            float groundZNoVmap = map->GetHeight(candX, candY, MAX_HEIGHT, /*checkVMap=*/false);
                            if (std::isfinite(groundZNoVmap) && groundZNoVmap > MIN_HEIGHT)
                                groundZ = groundZNoVmap;
                        }

                        // If still no ground, check water level as a last resort
                        if ((!std::isfinite(groundZ) || groundZ <= MIN_HEIGHT))
                        {
                            float waterZ = map->GetWaterLevel(candX, candY);
                            if (std::isfinite(waterZ) && waterZ > MIN_HEIGHT)
                                groundZ = waterZ;
                        }

                        // Diagnostic: occasionally log sampled points that failed to find ground
                        if (fa < 6 && (!std::isfinite(groundZ) || groundZ <= MIN_HEIGHT))
                            LOG_DEBUG("scripts", "GetRandomHotspotPosition: sample failed map {} candidate ({:.1f},{:.1f}) -> groundZ={}", candidateMapId, candX, candY, groundZ);

                        if (groundZ > MIN_HEIGHT && std::isfinite(groundZ))
                        {
                            // Resolve zone id for sampled point
                            uint32 resolvedZone = sMapMgr->GetZoneId(PHASEMASK_NORMAL, candidateMapId, candX, candY, groundZ);
                            LOG_DEBUG("scripts", "GetRandomHotspotPosition: sampled point resolved to zone {} on map {}", resolvedZone, candidateMapId);
                            // Only accept sampled point if zone is allowed by per-map config (respecting zone 0 = all)
                            if (IsZoneAllowed(candidateMapId, resolvedZone))
                            {
                                outMapId = candidateMapId;
                                outX = candX;
                                outY = candY;
                                outZ = groundZ;
                                outZoneId = resolvedZone;
                                LOG_INFO("scripts", "GetRandomHotspotPosition: fallback sampling succeeded for map {} at ({:.1f},{:.1f},{:.1f}) zone {}", candidateMapId, outX, outY, outZ, outZoneId);
                                return true;
                            }
                            // otherwise continue sampling
                        }
                    }
                    LOG_WARN("scripts", "GetRandomHotspotPosition: per-map enabled zones present for map {} but fallback sampling found no valid ground", candidateMapId);
                    continue;
                }
                else
                {
                    LOG_WARN("scripts", "GetRandomHotspotPosition: per-map enabled zones present for map {} but no sMapBounds entry available (skipping)", candidateMapId);
                    continue;
                }
            }

            LOG_WARN("scripts", "GetRandomHotspotPosition: no allowed coordinates after filtering zones for map {}. enabledZones={} excludedZones={}",
                     candidateMapId, sHotspotsConfig.enabledZones.size(), sHotspotsConfig.excludedZones.size());
            continue;
        }

        // Shuffle rectangles to try them in random order
        std::shuffle(allowedCoords.begin(), allowedCoords.end(), gen);

    // Create a single base (non-instanced) Map object for this candidate so we can query terrain height
    Map* map = GetBaseMapSafe(candidateMapId);
        if (!map)
        {
            LOG_WARN("scripts", "GetRandomHotspotPosition: could not create/find Map object for map id {} (skipping)", candidateMapId);
            continue;
        }

        // For each rect try several random points and validate ground
        for (auto const& rect : allowedCoords)
        {
            std::uniform_real_distribution<float> xDist(rect.minX, rect.maxX);
            std::uniform_real_distribution<float> yDist(rect.minY, rect.maxY);

            for (int a = 0; a < attemptsPerRect; ++a)
            {
                float candX = xDist(gen);
                float candY = yDist(gen);

                float groundZ = map->GetHeight(candX, candY, MAX_HEIGHT);

                if (groundZ > MIN_HEIGHT && std::isfinite(groundZ))
                {
                    outMapId = candidateMapId;
                    outX = candX;
                    outY = candY;
                    outZ = groundZ;
                    outZoneId = rect.zoneId;
                    return true;
                }
            }
        }
        // Try next map if this one failed
    }

    LOG_WARN("scripts", "GetRandomHotspotPosition: no valid ground found across enabled maps");
    return false;
}

// Spawn a new hotspot
// Returns true if a hotspot was actually spawned, false otherwise
static bool SpawnHotspot()
{
    if (!sHotspotsConfig.enabled)
        return false;

    if (sActiveHotspots.size() >= sHotspotsConfig.maxActive)
        return false;

    uint32 mapId, zoneId;
    float x, y, z;

    if (!GetRandomHotspotPosition(mapId, zoneId, x, y, z))
    {
        // Log details to help diagnose why random position selection failed
        std::ostringstream ss;
        ss << "GetRandomHotspotPosition() failed. enabledMapsCount=" << sHotspotsConfig.enabledMaps.size();
        if (!sHotspotsConfig.enabledMaps.empty())
        {
            ss << " maps={";
            for (size_t i = 0; i < sHotspotsConfig.enabledMaps.size(); ++i)
            {
                if (i) ss << ",";
                ss << sHotspotsConfig.enabledMaps[i];
            }
            ss << "}";
        }
    LOG_ERROR("scripts", "{}", EscapeBraces(ss.str()));
        return false;
    }

    Hotspot hotspot;
    hotspot.id = sNextHotspotId++;
    hotspot.mapId = mapId;
    hotspot.zoneId = zoneId;
    hotspot.x = x;
    hotspot.y = y;
    hotspot.z = z;
    hotspot.spawnTime = GameTime::GetGameTime().count();
    hotspot.expireTime = hotspot.spawnTime + (sHotspotsConfig.duration * MINUTE);

    // Spawn visual marker GameObject if enabled
    if (sHotspotsConfig.spawnVisualMarker)
    {
    // Ensure base map exists when creating visual markers
    if (Map* map = GetBaseMapSafe(mapId))
        {
            // Create GameObject from template
            if (GameObjectTemplate const* goInfo = sObjectMgr->GetGameObjectTemplate(sHotspotsConfig.markerGameObjectEntry))
            {
                GameObject* go = new GameObject();
                // Create expects: guidlow, entry, map, phaseMask, x,y,z, ang, rotation, animprogress, go_state
                float ang = 0.0f;
                // Map doesn't expose a GetPhaseMask(); use default phase mask (0) for world markers.
                uint32 phaseMask = 0;

                // Prefer ground-sampled Z to avoid placing markers underwater or inside terrain.
                float markerZ = z;
                float sampledZ = map->GetHeight(x, y, z);
                if (!std::isnan(sampledZ) && std::isfinite(sampledZ))
                {
                    markerZ = sampledZ + 0.5f; // lift slightly above ground
                    hotspot.z = markerZ; // update hotspot record so in-range checks and messages use ground Z
                }

                if (go->Create(map->GenerateLowGuid<HighGuid::GameObject>(), sHotspotsConfig.markerGameObjectEntry,
                              map, phaseMask, x, y, markerZ, ang, G3D::Quat(), 255, GO_STATE_READY))
                {
                    go->SetRespawnTime(sHotspotsConfig.duration * MINUTE);
                    map->AddToMap(go);
                    hotspot.gameObjectGuid = go->GetGUID();

                    LOG_DEBUG("scripts", "Hotspot #{} spawned GameObject marker (GUID: {}) at ({}, {}, {}) on map {}",
                              hotspot.id, go->GetGUID().ToString(), hotspot.x, hotspot.y, hotspot.z, mapId);
                }
                else
                {
                    delete go;
                    LOG_ERROR("scripts", "Failed to create hotspot marker GameObject");
                }
            }
        }
    }

    sActiveHotspots.push_back(hotspot);

    // Log spawn details for debugging and persistence validation
    LOG_INFO("scripts", "Spawned Hotspot #{} on map {} (zone {}) at ({:.1f}, {:.1f}, {:.1f}) expiring in {}s",
             hotspot.id, hotspot.mapId, hotspot.zoneId, hotspot.x, hotspot.y, hotspot.z,
             static_cast<int32>(hotspot.expireTime - hotspot.spawnTime));

    if (sHotspotsConfig.announceSpawn)
    {
        // Resolve human friendly names where possible
        std::string mapName = "Unknown";
        switch (mapId)
        {
            case 0: mapName = "Eastern Kingdoms"; break;
            case 1: mapName = "Kalimdor"; break;
            case 530: mapName = "Outland"; break;
            case 571: mapName = "Northrend"; break;
        }

        std::string zoneName = "Unknown";
        if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(hotspot.zoneId))
            zoneName = area->area_name[0];

        std::ostringstream ss;
        ss << "|cFFFFD700[Hotspot]|r A new XP Hotspot has appeared in " << mapName
           << " (" << zoneName << ") at (" << std::fixed << std::setprecision(1)
           << hotspot.x << ", " << hotspot.y << ", " << hotspot.z << ")"
           << "! (+" << sHotspotsConfig.experienceBonus << "% XP)";

      sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, ss.str());

      // Send a structured message for addons to parse reliably
      // Format: HOTSPOT_ADDON|map:<mapId>|zone:<zoneId>|x:<x>|y:<y>|z:<z>|id:<id>|dur:<seconds>|icon:<spellId>
      std::ostringstream addon;
      addon << "HOTSPOT_ADDON|map:" << hotspot.mapId
          << "|zone:" << hotspot.zoneId
          << "|x:" << std::fixed << std::setprecision(2) << hotspot.x
          << "|y:" << std::fixed << std::setprecision(2) << hotspot.y
          << "|z:" << std::fixed << std::setprecision(2) << hotspot.z
          << "|id:" << hotspot.id
          << "|dur:" << (sHotspotsConfig.duration * MINUTE)
          << "|icon:" << sHotspotsConfig.buffSpell
          << "|bonus:" << sHotspotsConfig.experienceBonus;

    // Compute normalized coordinates (nx, ny) using DBC when possible, fallback to map bounds
    float nx = 0.0f, ny = 0.0f;
    if (ComputeNormalizedCoords(hotspot.mapId, hotspot.zoneId, hotspot.x, hotspot.y, nx, ny))
    {
        addon << "|nx:" << std::fixed << std::setprecision(4) << nx
            << "|ny:" << std::fixed << std::setprecision(4) << ny;
    }

            // Send structured addon packet to relevant sessions so addons receive CHAT_MSG_ADDON-style events
            // Compose message with short prefix and tab separator (clients expect prefix\tpayload)
        std::string rawPayload = addon.str();
        // Sanitize payload: remove any accidental control chars (tabs/newlines) which can confuse clients
        for (char &ch : rawPayload)
        {
                if (ch == '\n' || ch == '\r' || ch == '\t') ch = ' ';
        }
    std::string addonMsg = std::string("HOTSPOT\t") + rawPayload;

      // Broadcast only to players on the same map and (optionally) within announce radius
      WorldSessionMgr::SessionMap const& sessions = sWorldSessionMgr->GetAllSessions();
      const float announceRadius = sHotspotsConfig.announceRadius;
      const float announceRadius2 = announceRadius * announceRadius;
      int announcedCount = 0;
      for (WorldSessionMgr::SessionMap::const_iterator itr = sessions.begin(); itr != sessions.end(); ++itr)
      {
          WorldSession* sess = itr->second;
          if (!sess)
              continue;
          Player* plr = sess->GetPlayer();
          if (!plr)
              continue;

          // Only notify players on the same map
          if (plr->GetMapId() != hotspot.mapId)
              continue;

          bool shouldAnnounce = false;
          // If announceRadius <= 0, notify all players on the same map
          if (announceRadius <= 0.0f)
          {
              shouldAnnounce = true;
          }
          else
          {
              // Distance squared check (3D)
              float dx = plr->GetPositionX() - hotspot.x;
              float dy = plr->GetPositionY() - hotspot.y;
              float dz = plr->GetPositionZ() - hotspot.z;
              float dist2 = dx*dx + dy*dy + dz*dz;
              if (dist2 <= announceRadius2)
              {
                  shouldAnnounce = true;
              }
          }

          if (shouldAnnounce)
          {
              // Send system message so players know a hotspot appeared
              sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, ss.str(), plr);
              
              // Send addon packet to enable addon visualization
              WorldPacket pkt;
              ChatHandler::BuildChatPacket(pkt, CHAT_MSG_ADDON, LANG_ADDON, plr, plr, addonMsg);
              sess->SendPacket(&pkt);
              announcedCount++;
          }
      }
      LOG_DEBUG("scripts", "Hotspot #{} broadcast: {} players notified on map {}", hotspot.id, announcedCount, hotspot.mapId);
    }

    return true;
}

// Remove expired hotspots
static void CleanupExpiredHotspots()
{
    auto it = sActiveHotspots.begin();
    while (it != sActiveHotspots.end())
    {
        if (!it->IsActive())
        {
            // Remove visual marker GameObject if it exists
            if (!it->gameObjectGuid.IsEmpty())
            {
                // Ensure base map exists for cleanup operations
                if (Map* m = GetBaseMapSafe(it->mapId))
                {
                    if (GameObject* go = m->GetGameObject(it->gameObjectGuid))
                    {
                        go->SetRespawnTime(0);
                        go->Delete();
                    }
                }
            }

            if (sHotspotsConfig.announceExpire)
            {
                std::ostringstream ss;
                ss << "|cFFFFD700[Hotspot]|r A Hotspot has expired.";
                sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, ss.str());
            }

            it = sActiveHotspots.erase(it);
        }
        else
        {
            ++it;
        }
    }
}

// Check if player is in any hotspot
static Hotspot const* GetPlayerHotspot(Player* player)
{
    if (!player)
        return nullptr;

    for (auto const& hotspot : sActiveHotspots)
    {
        if (hotspot.IsPlayerInRange(player))
            return &hotspot;
    }

    return nullptr;
}

// Immediate helper to evaluate and apply hotspot effects for a player (used for teleport/GM checks)
static void CheckPlayerHotspotStatusImmediate(Player* player)
{
    if (!player || !sHotspotsConfig.enabled)
        return;

    LOG_INFO("scripts", "=== CheckPlayerHotspotStatusImmediate START for {} ===", player->GetName());
    LOG_INFO("scripts", "Player: map={} pos=({:.1f},{:.1f},{:.1f})", 
             player->GetMapId(), player->GetPositionX(), player->GetPositionY(), player->GetPositionZ());
    LOG_INFO("scripts", "Active hotspots: {}", sActiveHotspots.size());

    Hotspot const* hotspot = GetPlayerHotspot(player);
    bool hasBuffAura = player->HasAura(sHotspotsConfig.buffSpell);

    LOG_INFO("scripts", "Result: hotspot={} hasBuffAura={}", hotspot != nullptr, hasBuffAura);

    if (hotspot && !hasBuffAura)
    {
        LOG_INFO("scripts", "APPLYING BUFF: Player in hotspot but no aura yet");
        ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[Hotspot DEBUG]|r immediate detected hotspot ID {} nearby (zone {})", hotspot->id, hotspot->zoneId);
        if (SpellInfo const* auraInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.auraSpell))
        {
            LOG_INFO("scripts", "Casting aura spell {}", sHotspotsConfig.auraSpell);
            player->CastSpell(player, sHotspotsConfig.auraSpell, true);
        }
        else
            LOG_WARN("scripts", "Aura spell {} not found", sHotspotsConfig.auraSpell);
            
        if (SpellInfo const* buffInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.buffSpell))
        {
            LOG_INFO("scripts", "Casting buff spell {}", sHotspotsConfig.buffSpell);
            player->CastSpell(player, sHotspotsConfig.buffSpell, true);
        }
        else
            LOG_WARN("scripts", "Buff spell {} not found", sHotspotsConfig.buffSpell);
            
        ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[Hotspot DEBUG]|r immediate applied buff spell id {}", sHotspotsConfig.buffSpell);
    }
    else if (!hotspot && hasBuffAura)
    {
        LOG_INFO("scripts", "REMOVING BUFF: Player not in hotspot but has aura");
        player->RemoveAura(sHotspotsConfig.buffSpell);
        ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[Hotspot DEBUG]|r immediate removed buff spell id {}", sHotspotsConfig.buffSpell);
    }
    else if (hotspot && hasBuffAura)
    {
        LOG_INFO("scripts", "ALREADY BUFFED: Player in hotspot and has aura");
    }
    else
    {
        LOG_INFO("scripts", "NO ACTION: Player not in any hotspot");
    }
    LOG_INFO("scripts", "=== CheckPlayerHotspotStatusImmediate END ===");
}

// World script for periodic updates
class HotspotsWorldScript : public WorldScript
{
public:
    HotspotsWorldScript() : WorldScript("HotspotsWorldScript") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        LoadHotspotsConfig();
    }

    void OnStartup() override
    {
        LoadHotspotsConfig();

        if (sHotspotsConfig.enabled)
        {
            LOG_INFO("server.loading", ">> DarkChaos Hotspots System loaded");
            LOG_INFO("server.loading", ">> - Duration: {} minutes", sHotspotsConfig.duration);
            LOG_INFO("server.loading", ">> - XP Bonus: +{}%", sHotspotsConfig.experienceBonus);
            LOG_INFO("server.loading", ">> - Max Active: {}", sHotspotsConfig.maxActive);
            LOG_INFO("server.loading", ">> - Enabled Maps: {}", sHotspotsConfig.enabledMaps.size());
            // Initialize spawn timer origin so respawnDelay is measured from server start
            sLastSpawnCheck = GameTime::GetGameTime().count();

            // Build DBC-derived map bounds used for normalized coordinates
            BuildMapBoundsFromDBC();

            // Load optional DB-backed bounds (dc_map_bounds) which can override or provide missing maps
            // Note: user preference is DB-only storage for custom bounds; CSV loader intentionally omitted.
            auto LoadMapBoundsFromDB = []()
            {
                // Query world database table dc_map_bounds: mapid,minX,maxX,minY,maxY,source
                try
                {
                    QueryResult result = WorldDatabase.Query("SELECT mapid, minX, maxX, minY, maxY FROM dc_map_bounds");
                    if (!result)
                    {
                        LOG_INFO("scripts", "No dc_map_bounds rows found (or table missing)");
                        return;
                    }

                    do
                    {
                        Field* fields = result->Fetch();
                        uint32 mapId = fields[0].Get<uint32>();
                        double minX = fields[1].Get<double>();
                        double maxX = fields[2].Get<double>();
                        double minY = fields[3].Get<double>();
                        double maxY = fields[4].Get<double>();

                        // Only set bounds if not already present (DBC preferred)
                        if (sMapBounds.find(mapId) == sMapBounds.end())
                        {
                            sMapBounds.emplace(mapId, std::array<float,4>{static_cast<float>(minX), static_cast<float>(maxX), static_cast<float>(minY), static_cast<float>(maxY)});
                            LOG_INFO("scripts", "Loaded map bounds from DB for map {} -> [{},{},{},{}]", mapId, minX, maxX, minY, maxY);
                        }

                    } while (result->NextRow());
                }
                catch (...) {
                    LOG_WARN("scripts", "Exception while loading dc_map_bounds from DB - skipping");
                }
            };

            LoadMapBoundsFromDB();

            // Try runtime ADT/WDT parsing of client data path to fill missing maps
            // Config option: Hotspots.ClientDataPath (default: "Data" or server's data dir)
            std::string clientDataPath = sConfigMgr->GetOption<std::string>("Hotspots.ClientDataPath", "Data");
            TryLoadBoundsFromClientData(clientDataPath);

            // Debug: report loaded map bounds count and presence of map 37
            {
                size_t count = sMapBounds.size();
                bool has37 = (sMapBounds.find(37) != sMapBounds.end());
                LOG_INFO("scripts", "Hotspots: loaded map bounds count = {} ; map 37 present = {}", count, has37);
                if (!has37)
                    LOG_WARN("scripts", "Hotspots: map 37 not found in loaded map bounds - check dc_map_bounds or var/map_bounds.csv");
            }

            // Startup diagnostic: dump parsed per-map enabled zones and preset matches
            if (!sHotspotsConfig.enabledZonesPerMap.empty())
            {
                for (auto const& kv : sHotspotsConfig.enabledZonesPerMap)
                {
                    uint32 mid = kv.first;
                    std::ostringstream ss;
                    ss << "Hotspots.EnabledZonesPerMap parsed: map=" << mid << " zones={";
                    for (size_t i = 0; i < kv.second.size(); ++i)
                    {
                        if (i) ss << ",";
                        ss << kv.second[i];
                    }
                    ss << "}";
                    LOG_INFO("scripts", "{}", EscapeBraces(ss.str()));

                    // Compare against preset zone ids for this map
                    auto presets = GetPresetZoneIdsForMap(mid);
                    if (presets.empty())
                    {
                        LOG_INFO("scripts", "Hotspots: map {} has no built-in preset rectangles", mid);
                        continue;
                    }

                    std::ostringstream ps;
                    ps << "Hotspots: map " << mid << " preset zones={";
                    for (size_t i = 0; i < presets.size(); ++i)
                    {
                        if (i) ps << ",";
                        ps << presets[i];
                    }
                    ps << "}";
                    LOG_INFO("scripts", "{}", EscapeBraces(ps.str()));

                    // Which presets are allowed by the config?
                    std::vector<uint32> allowedPresetZones;
                    for (uint32 zid : presets)
                    {
                        if (IsZoneAllowed(mid, zid))
                            allowedPresetZones.push_back(zid);
                    }

                    std::ostringstream ap;
                    ap << "Hotspots: map " << mid << " allowed preset zones after config filter={";
                    for (size_t i = 0; i < allowedPresetZones.size(); ++i)
                    {
                        if (i) ap << ",";
                        ap << allowedPresetZones[i];
                    }
                    ap << "}";
                    LOG_INFO("scripts", "{}", EscapeBraces(ap.str()));
                }
            }

            // If initialPopulateCount is 0, populate up to maxActive
            uint32 toSpawn = sHotspotsConfig.initialPopulateCount == 0 ? sHotspotsConfig.maxActive : sHotspotsConfig.initialPopulateCount;
            toSpawn = std::min<uint32>(toSpawn, sHotspotsConfig.maxActive);
            for (uint32 i = 0; i < toSpawn; ++i)
            {
                if (!SpawnHotspot())
                    LOG_DEBUG("scripts", "SpawnHotspot() returned false during initial population (i=%u)", i);
            }
        }
    }

    void OnUpdate(uint32 /*diff*/) override
    {
        if (!sHotspotsConfig.enabled)
            return;

    time_t now = GameTime::GetGameTime().count();

        // Check for expired hotspots every 10 seconds
        static time_t sLastCleanup = 0;
        if (now - sLastCleanup >= 10)
        {
            sLastCleanup = now;
            CleanupExpiredHotspots();
        }

        // Check for spawning new hotspots
        if (now - sLastSpawnCheck >= (sHotspotsConfig.respawnDelay * MINUTE))
        {
            sLastSpawnCheck = now;
            if (!SpawnHotspot())
                LOG_DEBUG("scripts", "SpawnHotspot() returned false during periodic spawn check");
        }
    }
};

// Player script for hotspot detection and buff application
class HotspotsPlayerScript : public PlayerScript
{
public:
    HotspotsPlayerScript() : PlayerScript("HotspotsPlayerScript") { }

    void OnLogin(Player* player)
    {
        if (!sHotspotsConfig.enabled || !player)
            return;

        // Check if player logged in inside a hotspot
        CheckPlayerHotspotStatus(player);
        
        // Send all active hotspots to the addon when player logs in
        if (player->GetSession())
        {
            for (const auto& hotspot : sActiveHotspots)
            {
                std::ostringstream addon;
                addon << "HOTSPOT_ADDON|map:" << hotspot.mapId
                      << "|zone:" << hotspot.zoneId
                      << "|x:" << std::fixed << std::setprecision(2) << hotspot.x
                      << "|y:" << std::fixed << std::setprecision(2) << hotspot.y
                      << "|z:" << std::fixed << std::setprecision(2) << hotspot.z
                      << "|id:" << hotspot.id
                      << "|dur:" << (hotspot.expireTime - time(nullptr))
                      << "|icon:" << sHotspotsConfig.buffSpell
                      << "|bonus:" << sHotspotsConfig.experienceBonus;
                
                float nx = 0.0f, ny = 0.0f;
                if (ComputeNormalizedCoords(hotspot.mapId, hotspot.zoneId, hotspot.x, hotspot.y, nx, ny))
                {
                    addon << "|nx:" << std::fixed << std::setprecision(4) << nx
                          << "|ny:" << std::fixed << std::setprecision(4) << ny;
                }
                
                std::string rawPayload = addon.str();
                for (char &ch : rawPayload)
                {
                    if (ch == '\n' || ch == '\r' || ch == '\t') ch = ' ';
                }
                
                // Send via chat system message (fallback method - works like addon message)
                ChatHandler(player->GetSession()).SendSysMessage(rawPayload);
            }
        }
    }

    void OnUpdate(Player* player, uint32 /*diff*/)
    {
        if (!sHotspotsConfig.enabled || !player)
            return;

        // Check hotspot status every few seconds (throttled by update frequency)
        static std::unordered_map<ObjectGuid, time_t> sLastCheck;
    time_t now = GameTime::GetGameTime().count();

        ObjectGuid guid = player->GetGUID();
        if (now - sLastCheck[guid] >= 2)
        {
            sLastCheck[guid] = now;
            CheckPlayerHotspotStatus(player);
        }
    }

    void OnPlayerResurrect(Player* player, float /*restore_percent*/, bool /*applySickness*/) override
    {
        if (!sHotspotsConfig.enabled || !player)
            return;

        // Reapply buff after resurrection if player is in hotspot
        LOG_DEBUG("scripts", "Player {} resurrected, checking hotspot status", player->GetName());
        CheckPlayerHotspotStatus(player);
    }

    void OnTeleport(Player* player, uint32 /*mapid*/, float /*x*/, float /*y*/, float /*z*/, float /*ori*/, uint32 /*options*/, Unit* /*target*/)
    {
        if (!sHotspotsConfig.enabled || !player)
            return;

        // Check hotspot status after teleport (e.g., random teleport, hearthstone, portal)
        LOG_DEBUG("scripts", "Player {} teleported, checking hotspot status", player->GetName());
        CheckPlayerHotspotStatus(player);
    }

    private:
    void CheckPlayerHotspotStatus(Player* player)
    {
        if (!player)
            return;

        Hotspot const* hotspot = GetPlayerHotspot(player);
        bool hasBuffAura = player->HasAura(sHotspotsConfig.buffSpell);

        // Case 1: Player is in hotspot but doesn't have buff (needs to be applied or reapplied)
        if (hotspot && !hasBuffAura)
        {
            // Player entered hotspot
            LOG_INFO("scripts", "Player {} entered Hotspot #{} (zone {}, map {})", player->GetName(), hotspot->id, hotspot->zoneId, hotspot->mapId);
            
            // Remove any conflicting buffs that might interfere (e.g., Arcane Intellect if somehow applied)
            // This prevents buff replacement issues
            uint32 buffSpellId = sHotspotsConfig.buffSpell;
            if (SpellInfo const* existingBuff = sSpellMgr->GetSpellInfo(42995)) // Arcane Intellect
            {
                if (player->HasAura(42995))
                {
                    LOG_DEBUG("scripts", "Removing Arcane Intellect (42995) from {} to prevent buff conflicts", player->GetName());
                    player->RemoveAura(42995);
                }
            }
            
            // Apply persistent buff (this is the ONLY buff for XP bonus)
            if (SpellInfo const* buffInfo = sSpellMgr->GetSpellInfo(buffSpellId))
            {
                LOG_DEBUG("scripts", "Casting buff spell {} on player {}", buffSpellId, player->GetName());
                player->CastSpell(player, buffSpellId, true);
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700[Hotspot]|r You have entered an XP Hotspot! +{}% experience from kills!", sHotspotsConfig.experienceBonus);
            }
            else
            {
                LOG_WARN("scripts", "Buff spell {} not found in spell manager", buffSpellId);
            }
        }
        else if (!hotspot && hasBuffAura)
        {
            // Player left hotspot
            LOG_INFO("scripts", "Player {} left Hotspot (no longer in range)", player->GetName());
            player->RemoveAura(sHotspotsConfig.buffSpell);
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF6347[Hotspot Notice]|r You have left the XP Hotspot zone. XP bonus deactivated."
            );
        }
    }
};

// Modify XP gain when in hotspot
class HotspotsPlayerGainXP : public PlayerScript
{
public:
    HotspotsPlayerGainXP() : PlayerScript("HotspotsPlayerGainXP") { }

    void OnGiveXP(Player* player, uint32& amount, Unit* /*victim*/)
    {
        if (!sHotspotsConfig.enabled || !player)
            return;

        // Check if player has hotspot buff aura
        bool hasHotspotBuff = player->HasAura(sHotspotsConfig.buffSpell);
        
        if (hasHotspotBuff)
        {
            uint32 originalAmount = amount;
            uint32 bonus = (amount * sHotspotsConfig.experienceBonus) / 100;
            amount += bonus;
            
            // Send visible notification to player about the bonus
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFFD700[Hotspot XP]|r +{} XP ({} base + {}% bonus = {} total)",
                bonus, originalAmount, sHotspotsConfig.experienceBonus, amount);
            
            LOG_DEBUG("scripts", "Hotspot XP Bonus: {} gained +{} XP ({} -> {})", 
                    player->GetName(), bonus, originalAmount, amount);
        }
        else
        {
            // Debug: player gaining XP but no hotspot buff
            LOG_DEBUG("scripts", "Hotspot: {} gained {} XP (no hotspot buff, aura count: {})", 
                    player->GetName(), amount, player->GetAuraCount(sHotspotsConfig.buffSpell));
        }
    }
};

// GM commands
class HotspotsCommandScript : public CommandScript
{
public:
    HotspotsCommandScript() : CommandScript("HotspotsCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable hotspotsCommandTable =
        {
            ChatCommandBuilder("list",   HandleHotspotsListCommand,   SEC_GAMEMASTER,    Console::No),
            ChatCommandBuilder("spawn",  HandleHotspotsSpawnCommand,  SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("spawnhere", HandleHotspotsSpawnHereCommand, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("testmsg", HandleHotspotsTestMsgCommand, SEC_GAMEMASTER, Console::No),
            ChatCommandBuilder("dump",   HandleHotspotsDumpCommand,   SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("clear",  HandleHotspotsClearCommand,  SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("reload", HandleHotspotsReloadCommand, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("tp",     HandleHotspotsTeleportCommand, SEC_GAMEMASTER,  Console::No),
            ChatCommandBuilder("status", HandleHotspotsStatusCommand, SEC_PLAYER, Console::No),
        };

        static ChatCommandTable commandTable =
        {
            ChatCommandBuilder("hotspots", hotspotsCommandTable),
            // alias for convenience
            ChatCommandBuilder("hotspot", hotspotsCommandTable)
        };

        return commandTable;
    }

    static bool HandleHotspotsListCommand(ChatHandler* handler, char const* /*args*/)
    {
        if (sActiveHotspots.empty())
        {
            handler->SendSysMessage("No active hotspots.");
            return true;
        }

        handler->PSendSysMessage("Active Hotspots: {}", sActiveHotspots.size());
        for (auto const& hotspot : sActiveHotspots)
        {
            time_t remaining = hotspot.expireTime - GameTime::GetGameTime().count();
            std::string zoneName = "Unknown Zone";
            if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(hotspot.zoneId))
                zoneName = area->area_name;
            
            handler->PSendSysMessage(
                "  ID: {} | Map: {} | Zone: {} ({}) | Pos: ({:.1f}, {:.1f}, {:.1f}) | Time Left: {}m",
                hotspot.id, hotspot.mapId, zoneName, hotspot.zoneId,
                hotspot.x, hotspot.y, hotspot.z,
                remaining / 60
            );
        }

        return true;
    }

    static bool HandleHotspotsSpawnCommand(ChatHandler* handler, char const* /*args*/)
    {
        if (SpawnHotspot())
        {
            handler->SendSysMessage("Spawned a new hotspot.");
        }
        else
        {
            handler->SendSysMessage("Failed to spawn a new hotspot (see server logs for details).");
            // Provide extra immediate debug info to the GM to aid diagnosis
            handler->PSendSysMessage("Hotspots debug: enabledMapsCount={} mapBoundsCount={} maxActive={} active={}",
                                    sHotspotsConfig.enabledMaps.size(), sMapBounds.size(), sHotspotsConfig.maxActive, sActiveHotspots.size());
            handler->PSendSysMessage("Run 'hotspots dump' to get more detailed info.");
        }
        return true;
    }

    static bool HandleHotspotsSpawnHereCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            handler->SendSysMessage("No player session available.");
            return true;
        }

        // Create a hotspot at player's current location
        uint32 mapId = player->GetMapId();
        uint32 zoneId = player->GetZoneId();
        float x = player->GetPositionX();
        float y = player->GetPositionY();
        float z = player->GetPositionZ();

        Hotspot hotspot;
        hotspot.id = sNextHotspotId++;
        hotspot.mapId = mapId;
        hotspot.zoneId = zoneId;
        hotspot.x = x;
        hotspot.y = y;
        hotspot.z = z;
        hotspot.spawnTime = GameTime::GetGameTime().count();
        hotspot.expireTime = hotspot.spawnTime + (sHotspotsConfig.duration * MINUTE);

        sActiveHotspots.push_back(hotspot);

        std::string zoneName = "Unknown Zone";
        if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(zoneId))
            zoneName = area->area_name;

        handler->PSendSysMessage("Spawned hotspot {} at {}: {}, {:.1f}, {:.1f}, {:.1f}", 
                                hotspot.id, zoneName, mapId, x, y, z);

        // Broadcast to all players
        std::ostringstream ss;
        ss << "Hotspot spawned in " << zoneName << " (+{}% XP)!";
        sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, ss.str());

        // Send addon message to all players
        for (const auto& sess : sWorldSessionMgr->GetAllSessions())
        {
            if (sess->GetPlayer())
            {
                std::ostringstream addon;
                addon << "HOTSPOT_ADDON|map:" << mapId
                      << "|zone:" << zoneId
                      << "|x:" << std::fixed << std::setprecision(2) << x
                      << "|y:" << std::fixed << std::setprecision(2) << y
                      << "|z:" << std::fixed << std::setprecision(2) << z
                      << "|id:" << hotspot.id
                      << "|dur:" << (sHotspotsConfig.duration * MINUTE)
                      << "|icon:" << sHotspotsConfig.buffSpell
                      << "|bonus:" << sHotspotsConfig.experienceBonus;

                float nx = 0.0f, ny = 0.0f;
                if (ComputeNormalizedCoords(mapId, zoneId, x, y, nx, ny))
                {
                    addon << "|nx:" << std::fixed << std::setprecision(4) << nx
                          << "|ny:" << std::fixed << std::setprecision(4) << ny;
                }

                std::string rawPayload = addon.str();
                for (char &ch : rawPayload)
                {
                    if (ch == '\n' || ch == '\r' || ch == '\t') ch = ' ';
                }

                ChatHandler(sess).SendSysMessage(rawPayload);
            }
        }

        return true;
    }

    static bool HandleHotspotsTestMsgCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            handler->SendSysMessage("No player session available to send test message to.");
            return true;
        }

        // Compose a synthetic hotspot payload based on the player's current position
        uint32 mapId = player->GetMapId();
        uint32 zoneId = player->GetZoneId();
        float x = player->GetPositionX();
        float y = player->GetPositionY();
        float z = player->GetPositionZ();

        std::ostringstream addon;
        addon << "HOTSPOT_ADDON|map:" << mapId
              << "|zone:" << zoneId
              << "|x:" << std::fixed << std::setprecision(2) << x
              << "|y:" << std::fixed << std::setprecision(2) << y
              << "|z:" << std::fixed << std::setprecision(2) << z
              << "|id:9999|dur:60|icon:" << sHotspotsConfig.buffSpell
              << "|bonus:" << sHotspotsConfig.experienceBonus;

        // Compute normalized coords if possible
        float nx = 0.0f, ny = 0.0f;
        if (ComputeNormalizedCoords(mapId, zoneId, x, y, nx, ny))
        {
            addon << "|nx:" << std::fixed << std::setprecision(4) << nx
                  << "|ny:" << std::fixed << std::setprecision(4) << ny;
        }

        std::string rawPayload = addon.str();
        for (char &ch : rawPayload)
        {
            if (ch == '\n' || ch == '\r' || ch == '\t') ch = ' ';
        }

        // Safer test: only send the system-text fallback to the player's session to avoid triggering
        // CHAT_MSG_ADDON handling code paths that can crash some clients in test scenarios.
        if (WorldSession* sess = handler->GetSession())
        {
            sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, rawPayload, sess->GetPlayer());
            handler->SendSysMessage("Sent synthetic HOTSPOT_ADDON fallback test message to your client (system text).");
            LOG_INFO("scripts", "Hotspots: sent synthetic system-only test message to player {} (map={}, pos={:.1f},{:.1f})",
                     handler->GetSession()->GetPlayer() ? handler->GetSession()->GetPlayer()->GetName().c_str() : "<unknown>", mapId, x, y);
        }

        return true;
    }

    static bool HandleHotspotsClearCommand(ChatHandler* handler, char const* /*args*/)
    {
        size_t count = sActiveHotspots.size();
        sActiveHotspots.clear();
    handler->PSendSysMessage("Cleared %u hotspot(s).", count);
        return true;
    }

    static bool HandleHotspotsReloadCommand(ChatHandler* handler, char const* /*args*/)
    {
        LoadHotspotsConfig();
        handler->SendSysMessage("Reloaded hotspots configuration.");
        return true;
    }

    static bool HandleHotspotsDumpCommand(ChatHandler* handler, char const* /*args*/)
    {
        handler->SendSysMessage("--- Hotspots debug dump ---");

        // Dump sMapBounds
        handler->SendSysMessage("sMapBounds entries:");
        if (sMapBounds.empty())
        {
            handler->SendSysMessage("  (no map bounds loaded)");
        }
        else
        {
            for (auto const& kv : sMapBounds)
            {
                std::ostringstream ss;
                ss << "  map=" << kv.first << " -> [" << kv.second[0] << ", " << kv.second[1]
                   << ", " << kv.second[2] << ", " << kv.second[3] << "]";
                handler->SendSysMessage(ss.str().c_str());
            }
        }

        // Dump per-map enabled zones
        handler->SendSysMessage("enabledZonesPerMap entries:");
        if (sHotspotsConfig.enabledZonesPerMap.empty())
        {
            handler->SendSysMessage("  (no per-map enabled zones configured)");
        }
        else
        {
            for (auto const& kv : sHotspotsConfig.enabledZonesPerMap)
            {
                std::ostringstream ss;
                ss << "  map=" << kv.first << " zones={";
                for (size_t i = 0; i < kv.second.size(); ++i)
                {
                    if (i) ss << ",";
                    ss << kv.second[i];
                }
                ss << "}";
                handler->SendSysMessage(ss.str().c_str());
            }
        }

        handler->SendSysMessage("--- end dump ---");
        return true;
    }

    static bool HandleHotspotsTeleportCommand(ChatHandler* handler, char const* args)
    {
        if (sActiveHotspots.empty())
        {
            handler->SendSysMessage("No active hotspots to teleport to.");
            return true;
        }

        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
            return false;

        // Parse hotspot ID from args, or default to first hotspot
        uint32 hotspotId = 0;
        if (args && *args)
        {
            if (Optional<uint32> val = Acore::StringTo<uint32>(args))
                hotspotId = *val;
        }

        // Find hotspot
        Hotspot const* targetHotspot = nullptr;
        
        if (hotspotId > 0)
        {
            // Find by specific ID
            for (auto const& hotspot : sActiveHotspots)
            {
                if (hotspot.id == hotspotId)
                {
                    targetHotspot = &hotspot;
                    break;
                }
            }

            if (!targetHotspot)
            {
                handler->PSendSysMessage("Hotspot ID %u not found.", hotspotId);
                return true;
            }
        }
        else
        {
            // Default to first hotspot
            targetHotspot = &sActiveHotspots[0];
        }

        // Teleport player
        if (player->TeleportTo(targetHotspot->mapId, targetHotspot->x, targetHotspot->y,
                               targetHotspot->z, player->GetOrientation()))
        {
            std::string zoneName = "Unknown";
            if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(targetHotspot->zoneId))
                zoneName = area->area_name[0] ? area->area_name[0] : zoneName;

            handler->PSendSysMessage("Teleported to Hotspot ID {} on map {} (zone {}) at ({:.1f}, {:.1f}, {:.1f})",
                                    targetHotspot->id, targetHotspot->mapId, zoneName,
                                    targetHotspot->x, targetHotspot->y, targetHotspot->z);

            LOG_INFO("scripts", "Player {} teleported to Hotspot #{} at ({:.1f}, {:.1f}, {:.1f})", 
                     player->GetName(), targetHotspot->id, targetHotspot->x, targetHotspot->y, targetHotspot->z);

            // Immediately check hotspot status for the player (apply buff/debug messages)
            LOG_INFO("scripts", "About to call CheckPlayerHotspotStatusImmediate for player {}", player->GetName());
            CheckPlayerHotspotStatusImmediate(player);
            LOG_INFO("scripts", "Returned from CheckPlayerHotspotStatusImmediate");
        }
        else
        {
            handler->SendSysMessage("Failed to teleport to hotspot.");
        }

        return true;
    }

    static bool HandleHotspotsStatusCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            handler->SendSysMessage("You must be in-game to check hotspot status.");
            return true;
        }

        if (!sHotspotsConfig.enabled)
        {
            handler->SendSysMessage("Hotspot system is disabled.");
            return true;
        }

        handler->SendSysMessage("=== Your Hotspot Status ===");
        
        bool inHotspot = IsPlayerInHotspot(player);
        bool hasBuffAura = player->HasAura(sHotspotsConfig.buffSpell);
        
        handler->PSendSysMessage("In Hotspot: {}", inHotspot ? "YES" : "NO");
        handler->PSendSysMessage("Has Buff Aura: {}", hasBuffAura ? "YES" : "NO");
        
        if (hasBuffAura)
        {
            handler->PSendSysMessage("|cFFFFD700XP Bonus: +{}%|r", sHotspotsConfig.experienceBonus);
            float multiplier = 1.0f + (sHotspotsConfig.experienceBonus / 100.0f);
            handler->PSendSysMessage("-> All XP gains are multiplied by {:.1f}x!", multiplier);
        }
        
        Hotspot const* nearbyHotspot = GetPlayerHotspot(player);
        if (nearbyHotspot)
        {
            time_t remaining = nearbyHotspot->expireTime - GameTime::GetGameTime().count();
            std::string zoneName = "Unknown";
            if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(nearbyHotspot->zoneId))
                zoneName = area->area_name[0] ? area->area_name[0] : zoneName;
                
            handler->PSendSysMessage("Nearby Hotspot: ID {} (zone: {}, expires in {}m)",
                                    nearbyHotspot->id, zoneName, remaining / 60);
        }
        else if (!inHotspot)
        {
            handler->SendSysMessage("No hotspots nearby (>150 yards away).");
        }

        return true;
    }
};

void AddSC_ac_hotspots()
{
    // Populate map bounds from available sources so normalized coordinate helpers work.
    BuildMapBoundsFromDBC();
    LoadMapBoundsFromCSV();
    // Allow optional client data path via config (e.g., "Hotspots.ClientDataPath")
    std::string clientDataPath = sConfigMgr->GetOption<std::string>("Hotspots.ClientDataPath", std::string(""));
    if (!clientDataPath.empty())
        TryLoadBoundsFromClientData(clientDataPath);

    new HotspotsWorldScript();
    new HotspotsPlayerScript();
    new HotspotsPlayerGainXP();
    new HotspotsCommandScript();
}
