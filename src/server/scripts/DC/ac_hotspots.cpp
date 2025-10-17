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
    uint32 auraSpell = 24171;                // Entry visual (cloud)
    uint32 buffSpell = 23768;                // Persistent buff (flag icon)
    uint32 minimapIcon = 1;                  // 1=arrow, 2=cross
    float announceRadius = 500.0f;           // yards
    std::vector<uint32> enabledMaps;
    std::vector<uint32> enabledZones;
    std::vector<uint32> excludedZones;
    bool announceSpawn = true;
    bool announceExpire = true;
    bool spawnVisualMarker = true;           // Spawn GameObject marker
    uint32 markerGameObjectEntry = 179976;   // Alliance Flag (shows on map)
};

static HotspotsConfig sHotspotsConfig;

// Minimal server-side map bounds used to normalize world coordinates into 0..1 for client helpers.
// These are approximate and can be improved later with DBC-driven values.
static std::unordered_map<uint32, std::array<float,4>> sMapBounds;

// Build map bounds from DBC WorldMapArea entries. This attempts to compute accurate
// map extents by aggregating all WorldMapArea entries for a given map_id.
static void BuildMapBoundsFromDBC()
{
    sMapBounds.clear();

    // Iterate all WorldMapArea entries and aggregate extents per map_id
    for (WorldMapAreaEntry const* entry : sWorldMapAreaStore)
    {
        if (!entry)
            continue;

        uint32 mapId = entry->map_id;
        float x1 = entry->x1;
        float x2 = entry->x2;
        float y1 = entry->y1;
        float y2 = entry->y2;

        // Some entries may be invalid; skip them
        if (!(x2 > x1 && y2 > y1))
            continue;

        auto it = sMapBounds.find(mapId);
        if (it == sMapBounds.end())
        {
            sMapBounds.emplace(mapId, std::array<float,4>{x1, x2, y1, y2});
        }
        else
        {
            auto &b = it->second;
            b[0] = std::min(b[0], x1);
            b[1] = std::max(b[1], x2);
            b[2] = std::min(b[2], y1);
            b[3] = std::max(b[3], y2);
        }
    }

    LOG_INFO("scripts", "Built map bounds from WorldMapArea.dbc for {} maps", sMapBounds.size());
    // Log top maps for quick inspection
    int printed = 0;
    for (auto const& kv : sMapBounds)
    {
        if (printed >= 12) break;
        uint32 mapId = kv.first;
        auto const& b = kv.second;
        LOG_INFO("scripts", "MapBounds mapId={} minX={} maxX={} minY={} maxY={}", mapId, b[0], b[1], b[2], b[3]);
        ++printed;
    }

    // Dump full map bounds to file for offline inspection
    std::string dumpPath = "var/log/hotspot_map_bounds.log";
    std::ofstream ofs(dumpPath, std::ios::out | std::ios::trunc);
    if (ofs)
    {
        ofs << "mapId,minX,maxX,minY,maxY\n";
        for (auto const& kv : sMapBounds)
        {
            auto const& b = kv.second;
            ofs << kv.first << "," << b[0] << "," << b[1] << "," << b[2] << "," << b[3] << "\n";
        }
        ofs.close();
        LOG_INFO("scripts", "Wrote full map bounds dump to {}", dumpPath);
    }
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
    if (std::getline(ifs, line))
    {
        if (line.rfind("mapId", 0) != 0)
            ; // first line is data
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
        if (Optional<uint32> mv = Acore::StringTo<uint32>(cols[0]))
            mapId = *mv;
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
            if (me->name && me->name[0] && mapName == me->name)
            {
                mapId = me->ID;
                break;
            }
        }

        if (mapId == 0)
            continue;

        // If we already have bounds (from DBC or CSV) skip
        if (sMapBounds.find(mapId) != sMapBounds.end())
            continue;

        // Compose WDT path
        std::string wdtPath = mapsRoot + mapName + "/" + mapName + ".wdt";
        if (!std::filesystem::exists(wdtPath))
            continue;

        // Use WDTFile to detect existing tiles if extractor headers are available.
#if defined(__has_include)
#if __has_include(<wdtfile.h>) && __has_include(<adtfile.h>)
#include <wdtfile.h>
#include <adtfile.h>
        char wdtCStr[1024]; strcpy(wdtCStr, wdtPath.c_str());
        char mapNameCStr[256]; strcpy(mapNameCStr, mapName.c_str());
        WDTFile WDT(wdtCStr, mapNameCStr);
        if (!WDT.init(mapId))
        {
            continue;
        }

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
#else
        LOG_WARN("scripts", "Compiler does not support __has_include; skipping ADT/WDT runtime parsing for {}", mapName);
#endif
    }
}

// Compute normalized 0..1 coordinates for a world position using DBC WorldMapArea entries when possible.
// Returns true if normalized coords were computed, false if caller should fallback.
static bool ComputeNormalizedCoords(uint32 mapId, uint32 zoneId, float x, float y, float& outNx, float& outNy)
{
    // Try DBC WorldMapArea for the zone
    if (WorldMapAreaEntry const* maEntry = sWorldMapAreaStore.LookupEntry(zoneId))
    {
        // Use maEntry bounds: x1..x2 and y1..y2
        float x1 = maEntry->x1;
        float x2 = maEntry->x2;
        float y1 = maEntry->y1;
        float y2 = maEntry->y2;

        if (x2 > x1 && y2 > y1)
        {
            float nx = (x - x1) / (x2 - x1);
            float ny = (y - y1) / (y2 - y1);
            // clamp
            nx = std::max(0.0f, std::min(1.0f, nx));
            ny = std::max(0.0f, std::min(1.0f, ny));
            outNx = nx;
            outNy = ny;
            return true;
        }
    }

    // Fallback: check sMapBounds for approximate map extents
    auto it = sMapBounds.find(mapId);
    if (it != sMapBounds.end())
    {
        auto b = it->second;
        float minX = b[0]; float maxX = b[1];
        float minY = b[2]; float maxY = b[3];
        if (maxX > minX && maxY > minY)
        {
            float nx = (x - minX) / (maxX - minX);
            float ny = (y - minY) / (maxY - minY);
            nx = std::max(0.0f, std::min(1.0f, nx));
            ny = std::max(0.0f, std::min(1.0f, ny));
            outNx = nx;
            outNy = ny;
            return true;
        }
    }

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
        if (!player || player->GetMapId() != mapId)
            return false;

        float dist = std::sqrt(
            std::pow(player->GetPositionX() - x, 2) +
            std::pow(player->GetPositionY() - y, 2) +
            std::pow(player->GetPositionZ() - z, 2)
        );

        return dist <= sHotspotsConfig.radius;
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

// Load configuration
static void LoadHotspotsConfig()
{
    sHotspotsConfig.enabled = sConfigMgr->GetOption<bool>("Hotspots.Enable", true);
    sHotspotsConfig.duration = sConfigMgr->GetOption<uint32>("Hotspots.Duration", 60);
    sHotspotsConfig.experienceBonus = sConfigMgr->GetOption<uint32>("Hotspots.ExperienceBonus", 100);
    sHotspotsConfig.radius = sConfigMgr->GetOption<float>("Hotspots.Radius", 150.0f);
    sHotspotsConfig.maxActive = sConfigMgr->GetOption<uint32>("Hotspots.MaxActive", 5);
    sHotspotsConfig.respawnDelay = sConfigMgr->GetOption<uint32>("Hotspots.RespawnDelay", 30);
    sHotspotsConfig.auraSpell = sConfigMgr->GetOption<uint32>("Hotspots.AuraSpell", 24171);
    sHotspotsConfig.buffSpell = sConfigMgr->GetOption<uint32>("Hotspots.BuffSpell", 23768);
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

// Helper: check if zone is allowed
static bool IsZoneAllowed(uint32 zoneId)
{
    // Check excluded zones first
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

    for (uint32 candidateMapId : maps)
    {
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
            if (IsZoneAllowed(coord.zoneId))
                allowedCoords.push_back(coord);
        }

        if (allowedCoords.empty())
        {
            LOG_WARN("scripts", "GetRandomHotspotPosition: no allowed coordinates after filtering zones for map {}. enabledZones={} excludedZones={}",
                     candidateMapId, sHotspotsConfig.enabledZones.size(), sHotspotsConfig.excludedZones.size());
            continue;
        }

        // Shuffle rectangles to try them in random order
        std::shuffle(allowedCoords.begin(), allowedCoords.end(), gen);

        Map* map = sMapMgr->FindMap(candidateMapId, 0);
        if (!map)
        {
            LOG_WARN("scripts", "GetRandomHotspotPosition: could not find Map object for map id {} (skipping)", candidateMapId);
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
        if (Map* map = sMapMgr->FindMap(mapId, 0))
        {
            // Create GameObject from template
            if (GameObjectTemplate const* goInfo = sObjectMgr->GetGameObjectTemplate(sHotspotsConfig.markerGameObjectEntry))
            {
                GameObject* go = new GameObject();
                // Create expects: guidlow, entry, map, phaseMask, x,y,z, ang, rotation, animprogress, go_state
                float ang = 0.0f;
                // Map doesn't expose a GetPhaseMask(); use default phase mask (0) for world markers.
                uint32 phaseMask = 0;
                if (go->Create(map->GenerateLowGuid<HighGuid::GameObject>(), sHotspotsConfig.markerGameObjectEntry,
                              map, phaseMask, x, y, z, ang, G3D::Quat(), 255, GO_STATE_READY))
                {
                    go->SetRespawnTime(sHotspotsConfig.duration * MINUTE);
                    map->AddToMap(go);
                    hotspot.gameObjectGuid = go->GetGUID();
                    
                    LOG_DEBUG("scripts", "Hotspot #{} spawned GameObject marker (GUID: {}) at ({}, {}, {}) on map {}",
                              hotspot.id, go->GetGUID().ToString(), x, y, z, mapId);
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
          << "|icon:" << sHotspotsConfig.buffSpell;

    // Compute normalized coordinates (nx, ny) using DBC when possible, fallback to map bounds
    float nx = 0.0f, ny = 0.0f;
    if (ComputeNormalizedCoords(hotspot.mapId, hotspot.zoneId, hotspot.x, hotspot.y, nx, ny))
    {
        addon << "|nx:" << std::fixed << std::setprecision(4) << nx
            << "|ny:" << std::fixed << std::setprecision(4) << ny;
    }

      // Send structured addon packet to relevant sessions so addons receive CHAT_MSG_ADDON-style events
      // Compose message with short prefix and tab separator (clients expect prefix\tpayload)
      std::string addonMsg = std::string("HOTSPOT\t") + addon.str();
      WorldPacket data;
      ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, nullptr, nullptr, addonMsg);

      // Broadcast only to players on the same map and (optionally) within announce radius
      WorldSessionMgr::SessionMap const& sessions = sWorldSessionMgr->GetAllSessions();
      const float announceRadius = sHotspotsConfig.announceRadius;
      const float announceRadius2 = announceRadius * announceRadius;
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

          // If announceRadius <= 0, notify all players on the same map
          if (announceRadius <= 0.0f)
          {
              sess->SendPacket(&data);
              continue;
          }

          // Distance squared check (3D)
          float dx = plr->GetPositionX() - hotspot.x;
          float dy = plr->GetPositionY() - hotspot.y;
          float dz = plr->GetPositionZ() - hotspot.z;
          float dist2 = dx*dx + dy*dy + dz*dz;
          if (dist2 <= announceRadius2)
              sess->SendPacket(&data);
      }
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
                if (Map* m = sMapMgr->FindMap(it->mapId, 0))
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

            // Load optional CSV-provided bounds (var/map_bounds.csv) which can override or provide missing maps
            LoadMapBoundsFromCSV();

            // Try runtime ADT/WDT parsing of client data path to fill missing maps
            // Config option: Hotspots.ClientDataPath (default: "Data" or server's data dir)
            std::string clientDataPath = sConfigMgr->GetOption<std::string>("Hotspots.ClientDataPath", "Data");
            TryLoadBoundsFromClientData(clientDataPath);

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

private:
    void CheckPlayerHotspotStatus(Player* player)
    {
        if (!player)
            return;

        Hotspot const* hotspot = GetPlayerHotspot(player);
        bool hasBuffAura = player->HasAura(sHotspotsConfig.buffSpell);

        if (hotspot && !hasBuffAura)
        {
            // Player entered hotspot
            // Apply entry visual (temporary cloud aura)
            if (SpellInfo const* auraInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.auraSpell))
                player->CastSpell(player, sHotspotsConfig.auraSpell, true);

            // Apply persistent buff (flag icon)
            if (SpellInfo const* buffInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.buffSpell))
                player->CastSpell(player, sHotspotsConfig.buffSpell, true);

            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFFD700[Hotspot]|r You have entered an XP Hotspot! +{}%% experience from kills!",
                sHotspotsConfig.experienceBonus
            );
        }
        else if (!hotspot && hasBuffAura)
        {
            // Player left hotspot
            player->RemoveAura(sHotspotsConfig.buffSpell);

            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFFD700[Hotspot]|r You have left the XP Hotspot."
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

        // Check if player is in hotspot
        if (player->HasAura(sHotspotsConfig.buffSpell))
        {
            uint32 bonus = (amount * sHotspotsConfig.experienceBonus) / 100;
            amount += bonus;
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
            ChatCommandBuilder("clear",  HandleHotspotsClearCommand,  SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("reload", HandleHotspotsReloadCommand, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("tp",     HandleHotspotsTeleportCommand, SEC_GAMEMASTER,  Console::No),
        };

        static ChatCommandTable commandTable =
        {
            ChatCommandBuilder("hotspots", hotspotsCommandTable)
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

    handler->PSendSysMessage("Active Hotspots: %u", sActiveHotspots.size());
        for (auto const& hotspot : sActiveHotspots)
        {
            time_t remaining = hotspot.expireTime - GameTime::GetGameTime().count();
            handler->PSendSysMessage(
                "  ID: %u | Map: %u | Zone: %u | Pos: (%.1f, %.1f, %.1f) | Time Left: %um",
                hotspot.id, hotspot.mapId, hotspot.zoneId,
                hotspot.x, hotspot.y, hotspot.z,
                remaining / 60
            );
        }

        return true;
    }

    static bool HandleHotspotsSpawnCommand(ChatHandler* handler, char const* /*args*/)
    {
        if (SpawnHotspot())
            handler->SendSysMessage("Spawned a new hotspot.");
        else
            handler->SendSysMessage("Failed to spawn a new hotspot (see server logs for details).");
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
            handler->PSendSysMessage("Teleported to Hotspot ID %u on map %u at (%.1f, %.1f, %.1f)",
                                    targetHotspot->id, targetHotspot->mapId,
                                    targetHotspot->x, targetHotspot->y, targetHotspot->z);
        }
        else
        {
            handler->SendSysMessage("Failed to teleport to hotspot.");
        }

        return true;
    }
};

void AddSC_ac_hotspots()
{
    new HotspotsWorldScript();
    new HotspotsPlayerScript();
    new HotspotsPlayerGainXP();
    new HotspotsCommandScript();
}
