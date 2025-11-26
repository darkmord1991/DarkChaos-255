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
#include "DatabaseEnv.h"

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
    uint32 minActive = 1;                    // minimum hotspots to maintain (crash persistence)
    uint32 maxPerZone = 2;                   // max hotspots allowed in same zone (0 = unlimited)
    uint32 respawnDelay = 30;                // minutes
    uint32 initialPopulateCount = 0;         // 0 = disabled (default: 0 -> populate to maxActive)
    uint32 auraSpell = 800001;               // Custom hotspot XP buff spell
    uint32 buffSpell = 800001;               // Custom hotspot XP buff spell with spellscript that handles XP multiplication
                                             // Spell ID 800001 must have a spellscript that applies the XP bonus
                                             // See: src/server/scripts/DC/spell_hotspot_buff_800001.cpp
    uint32 minimapIcon = 1;                  // 1=arrow, 2=cross
    float announceRadius = 500.0f;           // yards
    bool includeTextureInAddon = false;      // include a |tex:<path> field in addon payload if provided
    std::string buffTexture = "";          // explicit texture path to include (e.g. Interface\\Icons\\INV_Misc_Map_01)
    std::vector<uint32> enabledMaps;
    std::vector<uint32> enabledZones;
    std::vector<uint32> excludedZones;
    // Per-map zone allow list: mapId -> list of allowed zone IDs (if present, this overrides global enabled/excluded lists)
    std::unordered_map<uint32, std::vector<uint32>> enabledZonesPerMap;
    bool announceSpawn = true;
    bool announceExpire = true;
    bool spawnVisualMarker = true;           // Spawn GameObject marker
    uint32 markerGameObjectEntry = 179976;   // Alliance Flag (shows on map)
    bool sendAddonPackets = false;           // whether to send CHAT_MSG_ADDON packets (unsafe on some clients)
    bool gmBypassLimit = true;                // allow GM/manual spawns to bypass maxActive limit
    bool allowWorldwideSpawn = true;          // allow spawning hotspots across all enabled maps via command
    
    // Anti-camping settings
    bool antiCampingEnabled = true;           // enable diminishing returns for camping
    uint32 antiCampingInterval = 600;         // seconds before diminishing returns kick in (10 minutes)
    std::vector<float> antiCampingTiers = {1.0f, 0.75f, 0.50f, 0.25f}; // multipliers for each tier
};

static HotspotsConfig sHotspotsConfig;

// Minimal server-side map bounds used to normalize world coordinates into 0..1 for client helpers.
// These are approximate and can be improved later with DBC-driven values.
static std::unordered_map<uint32, std::array<float,4>> sMapBounds;

// Hotspot data structure (defined here so it can be used by functions below)
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

        // Use squared-distance comparison to avoid costly sqrt() calls
        float dx = player->GetPositionX() - x;
        float dy = player->GetPositionY() - y;
        float dz = player->GetPositionZ() - z;
        float dist2 = dx*dx + dy*dy + dz*dz;

        return dist2 <= (sHotspotsConfig.radius * sHotspotsConfig.radius);
    }

    bool IsPlayerNearby(Player* player) const
    {
        if (!player || player->GetMapId() != mapId)
            return false;

        // squared-distance check (3D)
        float dx = player->GetPositionX() - x;
        float dy = player->GetPositionY() - y;
        float dz = player->GetPositionZ() - z;
        float dist2 = dx*dx + dy*dy + dz*dz;

        return dist2 <= (sHotspotsConfig.announceRadius * sHotspotsConfig.announceRadius);
    }
};

// Active hotspots currently spawned on the server
static std::vector<Hotspot> sActiveHotspots;
static uint32 sNextHotspotId = 1;

// Anti-camping tracking: GUID -> {hotspotId, entryTime, lastXPGain}
struct PlayerHotspotTracking
{
    uint32 hotspotId;
    time_t entryTime;
    time_t lastXPGain;
};
static std::unordered_map<ObjectGuid, PlayerHotspotTracking> sPlayerHotspotTracking;

// Forward declaration for EscapeBraces used by logging in helpers defined earlier
static std::string EscapeBraces(std::string const& s);

// Helper: create or get a base (non-instanced) Map object safely and log on failure.
static Map* GetBaseMapSafe(uint32 mapId)
{
    if (!sMapMgr)
    {
        LOG_ERROR("scripts", "GetBaseMapSafe: sMapMgr is null!");
        return nullptr;
    }
    
    Map* map = sMapMgr->CreateBaseMap(mapId);
    if (!map)
    {
        LOG_ERROR("scripts", "GetBaseMapSafe: could not create/find Map object for map id {}", mapId);
        return nullptr;
    }
    return map;
}

// Build map bounds from DBC WorldMapArea entries. This computes map extents by
// aggregating all WorldMapArea entries for a given map_id. It prefers DBC data
// only (no CSV/client fallbacks) when called.
static void BuildMapBoundsFromDBC()
{
    sMapBounds.clear();

    // The global DBC storage for WorldMapArea may not be exported in some builds
    // via DBCStores.h; declare it here to link against the symbol defined in
    // the core's DBCStores.cpp. If the symbol is not present at link time the
    // build will fail — in that case the previous CSV/client-data fallbacks
    // should be used instead. For current environments where WorldMapArea.dbc
    // is available (e.g. Hyjal/Azshara entries present), this will populate
    // sMapBounds.
    extern DBCStorage<WorldMapAreaEntry> sWorldMapAreaStore;

    uint32 loaded = 0;
    try
    {
        for (auto it = sWorldMapAreaStore.begin(); it != sWorldMapAreaStore.end(); ++it)
        {
            WorldMapAreaEntry const* wma = *it;
            if (!wma) continue;

            uint32 mapId = wma->map_id;

            // worldmaparea entries store x1/x2/y1/y2 (note ordering may vary)
            float x1 = wma->x1;
            float x2 = wma->x2;
            float y1 = wma->y1;
            float y2 = wma->y2;

            float minX = std::min(x1, x2);
            float maxX = std::max(x1, x2);
            float minY = std::min(y1, y2);
            float maxY = std::max(y1, y2);

            auto found = sMapBounds.find(mapId);
            if (found == sMapBounds.end())
            {
                sMapBounds.emplace(mapId, std::array<float,4>{minX, maxX, minY, maxY});
                ++loaded;
            }
            else
            {
                auto &arr = found->second;
                arr[0] = std::min(arr[0], minX);
                arr[1] = std::max(arr[1], maxX);
                arr[2] = std::min(arr[2], minY);
                arr[3] = std::max(arr[3], maxY);
            }
        }
    }
    catch (...) {
        LOG_WARN("scripts", "Exception while building map bounds from WorldMapArea DBC - aborting DBC-derived bounds");
        sMapBounds.clear();
        return;
    }

    LOG_INFO("scripts", "Loaded {} DBC-derived map bounds entries", loaded);
}

// Forward declarations for database functions
static void DeleteHotspotFromDB(uint32 hotspotId);

// Database: Ensure the hotspots table exists (auto-create if missing)
static void EnsureHotspotTableExists()
{
    // Create table if it doesn't exist
    WorldDatabase.Execute(
        "CREATE TABLE IF NOT EXISTS `dc_hotspots_active` ("
        "  `id` INT UNSIGNED NOT NULL COMMENT 'Unique hotspot ID',"
        "  `map_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Map ID where hotspot is located',"
        "  `zone_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Zone ID where hotspot is located',"
        "  `x` FLOAT NOT NULL DEFAULT 0 COMMENT 'X coordinate',"
        "  `y` FLOAT NOT NULL DEFAULT 0 COMMENT 'Y coordinate',"
        "  `z` FLOAT NOT NULL DEFAULT 0 COMMENT 'Z coordinate',"
        "  `spawn_time` BIGINT NOT NULL DEFAULT 0 COMMENT 'Unix timestamp when hotspot was spawned',"
        "  `expire_time` BIGINT NOT NULL DEFAULT 0 COMMENT 'Unix timestamp when hotspot expires',"
        "  `gameobject_guid` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'GUID of visual marker GameObject',"
        "  PRIMARY KEY (`id`),"
        "  KEY `idx_expire_time` (`expire_time`),"
        "  KEY `idx_map_zone` (`map_id`, `zone_id`)"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );
    LOG_INFO("scripts", "Hotspots: Database table dc_hotspots_active verified/created");
}

// Database: Save hotspot to database
static void SaveHotspotToDB(Hotspot const& hotspot)
{
    // Use REPLACE INTO to handle both insert and update
    std::string query = Acore::StringFormat(
        "REPLACE INTO dc_hotspots_active (id, map_id, zone_id, x, y, z, spawn_time, expire_time, gameobject_guid) "
        "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {})",
        hotspot.id, hotspot.mapId, hotspot.zoneId, hotspot.x, hotspot.y, hotspot.z,
        hotspot.spawnTime, hotspot.expireTime, 
        hotspot.gameObjectGuid.IsEmpty() ? 0 : hotspot.gameObjectGuid.GetCounter()
    );
    
    WorldDatabase.Execute(query.c_str());
    LOG_DEBUG("scripts", "Saved hotspot #{} to database", hotspot.id);
}

// Database: Load hotspots from database
static void LoadHotspotsFromDB()
{
    QueryResult result = WorldDatabase.Query("SELECT id, map_id, zone_id, x, y, z, spawn_time, expire_time, gameobject_guid FROM dc_hotspots_active");
    
    if (!result)
    {
        LOG_INFO("scripts", "No hotspots found in database (table may be empty)");
        return;
    }
    
    uint32 count = 0;
    uint32 expired = 0;
    time_t now = GameTime::GetGameTime().count();
    
    do
    {
        Field* fields = result->Fetch();
        
        Hotspot hotspot;
        hotspot.id = fields[0].Get<uint32>();
        hotspot.mapId = fields[1].Get<uint16>();
        hotspot.zoneId = fields[2].Get<uint16>();
        hotspot.x = fields[3].Get<float>();
        hotspot.y = fields[4].Get<float>();
        hotspot.z = fields[5].Get<float>();
        hotspot.spawnTime = fields[6].Get<int64>();
        hotspot.expireTime = fields[7].Get<int64>();
        
        // We ignore the stored gameobject_guid since GameObjects don't persist across restarts
        // Visual markers will be recreated below
        
        // Skip expired hotspots and delete them from DB
        if (hotspot.expireTime <= now)
        {
            LOG_DEBUG("scripts", "Deleting expired hotspot #{} from database (expired {}s ago)", 
                     hotspot.id, now - hotspot.expireTime);
            DeleteHotspotFromDB(hotspot.id);
            expired++;
            continue;
        }
        
        sActiveHotspots.push_back(hotspot);
        count++;
        
        // Update next hotspot ID to avoid collisions
        if (hotspot.id >= sNextHotspotId)
            sNextHotspotId = hotspot.id + 1;
            
        LOG_DEBUG("scripts", "Loaded hotspot #{} from database (map {}, zone {}, expires in {}s)", 
                  hotspot.id, hotspot.mapId, hotspot.zoneId, hotspot.expireTime - now);
        
    } while (result->NextRow());
    
    LOG_INFO("scripts", "Loaded {} hotspots from database ({} expired and deleted)", count, expired);
}

// Database: Recreate visual markers for loaded hotspots (call after maps are ready)
static void RecreateHotspotVisualMarkers()
{
    if (!sHotspotsConfig.spawnVisualMarker)
        return;
        
    uint32 created = 0;
    time_t now = GameTime::GetGameTime().count();
    
    for (auto& hotspot : sActiveHotspots)
    {
        // Skip if already has a marker or is expired
        if (!hotspot.gameObjectGuid.IsEmpty() || hotspot.expireTime <= now)
            continue;
            
        Map* map = GetBaseMapSafe(hotspot.mapId);
        if (!map)
        {
            LOG_WARN("scripts", "RecreateHotspotVisualMarkers: Could not get map {} for hotspot #{}", 
                     hotspot.mapId, hotspot.id);
            continue;
        }
        
        if (GameObjectTemplate const* goInfo = sObjectMgr->GetGameObjectTemplate(sHotspotsConfig.markerGameObjectEntry))
        {
            GameObject* go = new GameObject();
            float ang = 0.0f;
            uint32 phaseMask = 0;
            
            // Calculate remaining time for respawn timer
            time_t remaining = hotspot.expireTime - now;
            
            uint32 lowGuid = map->GenerateLowGuid<HighGuid::GameObject>();
            if (go->Create(lowGuid, sHotspotsConfig.markerGameObjectEntry,
                          map, phaseMask, hotspot.x, hotspot.y, hotspot.z, ang, G3D::Quat(), 255, GO_STATE_READY))
            {
                go->SetRespawnTime(static_cast<int32>(remaining));
                if (map->AddToMap(go))
                {
                    hotspot.gameObjectGuid = go->GetGUID();
                    // Update DB with new GO guid
                    SaveHotspotToDB(hotspot);
                    created++;
                    LOG_DEBUG("scripts", "Recreated visual marker for hotspot #{} (GUID: {})", 
                              hotspot.id, go->GetGUID().ToString());
                }
                else
                {
                    delete go;
                    LOG_ERROR("scripts", "RecreateHotspotVisualMarkers: AddToMap failed for hotspot #{}", hotspot.id);
                }
            }
            else
            {
                delete go;
                LOG_ERROR("scripts", "RecreateHotspotVisualMarkers: Create failed for hotspot #{}", hotspot.id);
            }
        }
    }
    
    if (created > 0)
        LOG_INFO("scripts", "Recreated {} visual markers for persistent hotspots", created);
}

// Database: Delete hotspot from database
static void DeleteHotspotFromDB(uint32 hotspotId)
{
    std::string query = Acore::StringFormat("DELETE FROM dc_hotspots_active WHERE id = {}", hotspotId);
    WorldDatabase.Execute(query.c_str());
    LOG_DEBUG("scripts", "Deleted hotspot #{} from database", hotspotId);
}

// Database: Clear all hotspots from database
static void ClearHotspotsDB()
{
    WorldDatabase.Execute("DELETE FROM dc_hotspots_active");
    LOG_INFO("scripts", "Cleared all hotspots from database");
}

// Anti-camping: Calculate diminishing returns multiplier
static float GetAntiCampingMultiplier(Player* player, uint32 currentHotspotId)
{
    if (!sHotspotsConfig.antiCampingEnabled)
        return 1.0f;
    
    ObjectGuid guid = player->GetGUID();
    auto it = sPlayerHotspotTracking.find(guid);
    
    // Player not tracked or in different hotspot
    if (it == sPlayerHotspotTracking.end() || it->second.hotspotId != currentHotspotId)
        return 1.0f;
    
    time_t now = GameTime::GetGameTime().count();
    time_t timeInHotspot = now - it->second.entryTime;
    
    // Calculate tier based on time spent
    uint32 tier = static_cast<uint32>(timeInHotspot / sHotspotsConfig.antiCampingInterval);
    
    // Cap at max tier
    if (tier >= sHotspotsConfig.antiCampingTiers.size())
        tier = static_cast<uint32>(sHotspotsConfig.antiCampingTiers.size()) - 1;
    
    float multiplier = sHotspotsConfig.antiCampingTiers[tier];
    
    // Log diminishing returns application (throttled to once per tier change)
    static std::unordered_map<ObjectGuid, uint32> sLastLoggedTier;
    if (sLastLoggedTier[guid] != tier && tier > 0)
    {
        sLastLoggedTier[guid] = tier;
        LOG_DEBUG("scripts", "Anti-camping tier {} applied to {} ({}% bonus) after {} seconds in hotspot #{}",
                  tier, player->GetName(), static_cast<uint32>(multiplier * 100), timeInHotspot, currentHotspotId);
    }
    
    return multiplier;
}

// Anti-camping: Update player tracking
static void UpdatePlayerHotspotTracking(Player* player, uint32 hotspotId)
{
    if (!sHotspotsConfig.antiCampingEnabled)
        return;
    
    ObjectGuid guid = player->GetGUID();
    auto it = sPlayerHotspotTracking.find(guid);
    time_t now = GameTime::GetGameTime().count();
    
    if (it == sPlayerHotspotTracking.end() || it->second.hotspotId != hotspotId)
    {
        // New hotspot or first entry
        sPlayerHotspotTracking[guid] = {hotspotId, now, now};
        LOG_DEBUG("scripts", "Started tracking {} in hotspot #{}", player->GetName(), hotspotId);
    }
    else
    {
        // Update last XP gain time
        it->second.lastXPGain = now;
    }
}

// Anti-camping: Clear player tracking (when leaving hotspot)
static void ClearPlayerHotspotTracking(Player* player)
{
    sPlayerHotspotTracking.erase(player->GetGUID());
}

// Load additional map bounds from an optional CSV file: var/map_bounds.csv
// CSV format: mapId,minX,maxX,minY,maxY,source
[[maybe_unused]] static void LoadMapBoundsFromCSV()
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
[[maybe_unused]] static void TryLoadBoundsFromClientData(const std::string& clientDataPath)
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

        // Special case for Azshara Crater (map 37): Both axes are flipped
        // The map texture orientation doesn't match world coordinate orientation
        if (mapId == 37)
        {
            outNx = (maxX - x) / (maxX - minX);  // Flip X: (500 - x) / 1500
            outNy = (maxY - y) / (maxY - minY);  // Flip Y: (1500 - y) / 2000
        }
        else
        {
            outNx = (x - minX) / (maxX - minX);
            outNy = (y - minY) / (maxY - minY);
        }
        
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

// Build a standardized addon payload string for a hotspot. Includes optional texture field if configured.
static std::string BuildHotspotAddonPayload(const Hotspot& hotspot, int32 durationSeconds)
{
    std::ostringstream addon;
    addon << "HOTSPOT_ADDON|map:" << hotspot.mapId
          << "|zone:" << hotspot.zoneId
          << "|x:" << std::fixed << std::setprecision(2) << hotspot.x
          << "|y:" << std::fixed << std::setprecision(2) << hotspot.y
          << "|z:" << std::fixed << std::setprecision(2) << hotspot.z
          << "|id:" << hotspot.id
          << "|dur:" << durationSeconds
          << "|icon:" << sHotspotsConfig.buffSpell
          << "|bonus:" << sHotspotsConfig.experienceBonus;

    float nx = 0.0f, ny = 0.0f;
    if (ComputeNormalizedCoords(hotspot.mapId, hotspot.zoneId, hotspot.x, hotspot.y, nx, ny))
    {
        addon << "|nx:" << std::fixed << std::setprecision(4) << nx
              << "|ny:" << std::fixed << std::setprecision(4) << ny;
    }

    // Optionally include an explicit texture path to help clients without spell texture DB
    if (sHotspotsConfig.includeTextureInAddon)
    {
        // Prefer configured explicit texture path if present
        if (!sHotspotsConfig.buffTexture.empty())
        {
            addon << "|tex:" << sHotspotsConfig.buffTexture;
            LOG_DEBUG("scripts", "BuildHotspotAddonPayload: using explicit buffTexture='{}' for hotspot id {}", sHotspotsConfig.buffTexture, hotspot.id);
        }
        else
        {
            // Try to derive from spell icon id
            SpellInfo const* si = sSpellMgr->GetSpellInfo(sHotspotsConfig.buffSpell);
            if (si && si->SpellIconID)
            {
                addon << "|texid:" << si->SpellIconID;
                LOG_DEBUG("scripts", "BuildHotspotAddonPayload: using texid={} (spell {}) for hotspot id {}", si->SpellIconID, sHotspotsConfig.buffSpell, hotspot.id);
            }
            else
            {
                // Fallback to a safe default texture path so addons have something to show
                const std::string fallbackTex = "Interface\\Icons\\INV_Misc_Map_01";
                addon << "|tex:" << fallbackTex;
                LOG_WARN("scripts", "BuildHotspotAddonPayload: no spell icon id and no buffTexture configured for buffSpell {} - sending fallback tex {} for hotspot id {}", sHotspotsConfig.buffSpell, fallbackTex, hotspot.id);
            }
        }
    }

    std::string raw = addon.str();
    for (char &ch : raw)
        if (ch == '\n' || ch == '\r' || ch == '\t') ch = ' ';
    // Debug: log constructed addon payload so server operators can verify texture/icon fields
    LOG_INFO("scripts", "BuildHotspotAddonPayload -> {}", EscapeBraces(raw));
    return raw;
}


static time_t sLastSpawnCheck = 0;
// Per-player apply retries: when a buff cast does not result in an aura, retry a few times
static std::unordered_map<ObjectGuid, int> sBuffApplyRetries;
// Per-player hotspot expiry map: GUID -> expireTime (time_t). This acts as a server-side
// persistent flag indicating the player is considered 'in a hotspot' until expireTime.
static std::unordered_map<ObjectGuid, time_t> sPlayerHotspotExpiry;

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
    float radius2 = sHotspotsConfig.radius * sHotspotsConfig.radius;

    for (const auto& hotspot : sActiveHotspots)
    {
        if (hotspot.mapId != mapId)
            continue;
        float dx = x - hotspot.x;
        float dy = y - hotspot.y;
        float dist2 = dx*dx + dy*dy;
        if (dist2 <= radius2)
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
        // trim
        size_t start = token.find_first_not_of(" \t\r\n");
        if (start == std::string::npos)
            continue;
        size_t end = token.find_last_not_of(" \t\r\n");
        std::string t = token.substr(start, end - start + 1);
        if (t.empty())
            continue;

        if (Optional<uint32> val = Acore::StringTo<uint32>(t))
            result.push_back(*val);
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

// Helper: Trim addon payload by removing texture tokens
static std::string TrimAddonPayload(std::string const& rawPayload)
{
    std::string trimmedPayload;
    trimmedPayload.reserve(rawPayload.size());
    size_t pos = 0;
    
    while (pos < rawPayload.size())
    {
        // Find next occurrence of either token
        size_t tpos_tex = rawPayload.find("|tex:", pos);
        size_t tpos_texid = rawPayload.find("|texid:", pos);
        size_t tpos;
        size_t tokenLen;
        
        if (tpos_tex == std::string::npos && tpos_texid == std::string::npos)
        {
            // No tokens left
            trimmedPayload.append(rawPayload.substr(pos));
            break;
        }
        
        if (tpos_tex == std::string::npos) 
        { 
            tpos = tpos_texid; 
            tokenLen = 7; 
        }
        else if (tpos_texid == std::string::npos) 
        { 
            tpos = tpos_tex; 
            tokenLen = 5; 
        }
        else if (tpos_tex < tpos_texid) 
        { 
            tpos = tpos_tex; 
            tokenLen = 5; 
        }
        else 
        { 
            tpos = tpos_texid; 
            tokenLen = 7; 
        }

        // Append up to the token
        trimmedPayload.append(rawPayload.substr(pos, tpos - pos));

        // Skip the token and its value until next '|' or end
        size_t valStart = tpos + tokenLen;
        size_t nextPipe = rawPayload.find('|', valStart);
        if (nextPipe == std::string::npos)
            pos = rawPayload.size();
        else
            pos = nextPipe;
    }
    
    return trimmedPayload;
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

// Helper: safely get zone name from zone ID with DBC null check
static std::string GetSafeZoneName(uint32 zoneId)
{
    if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(zoneId))
    {
        if (area->area_name[0])
            return area->area_name[0];
    }
    return "Unknown Zone";
}

// Helper: get map name from map ID
static std::string GetMapName(uint32 mapId)
{
    switch (mapId)
    {
        case 0: return "Eastern Kingdoms";
        case 1: return "Kalimdor";
        case 530: return "Outland";
        case 571: return "Northrend";
        case 37: return "Azshara Crater";
        default: return "Unknown Map";
    }
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
    sHotspotsConfig.minActive = sConfigMgr->GetOption<uint32>("Hotspots.MinActive", 1);
    sHotspotsConfig.maxPerZone = sConfigMgr->GetOption<uint32>("Hotspots.MaxPerZone", 2);
    sHotspotsConfig.respawnDelay = sConfigMgr->GetOption<uint32>("Hotspots.RespawnDelay", 30);
    sHotspotsConfig.auraSpell = sConfigMgr->GetOption<uint32>("Hotspots.AuraSpell", 800001);
    sHotspotsConfig.buffSpell = sConfigMgr->GetOption<uint32>("Hotspots.BuffSpell", 800001);
    sHotspotsConfig.minimapIcon = sConfigMgr->GetOption<uint32>("Hotspots.MinimapIcon", 1);
    sHotspotsConfig.announceRadius = sConfigMgr->GetOption<float>("Hotspots.AnnounceRadius", 500.0f);
    sHotspotsConfig.announceSpawn = sConfigMgr->GetOption<bool>("Hotspots.AnnounceSpawn", true);
    sHotspotsConfig.announceExpire = sConfigMgr->GetOption<bool>("Hotspots.AnnounceExpire", true);
    sHotspotsConfig.spawnVisualMarker = sConfigMgr->GetOption<bool>("Hotspots.SpawnVisualMarker", true);
    sHotspotsConfig.markerGameObjectEntry = sConfigMgr->GetOption<uint32>("Hotspots.MarkerGameObjectEntry", 179976);
    sHotspotsConfig.sendAddonPackets = sConfigMgr->GetOption<bool>("Hotspots.SendAddonPackets", false);
    sHotspotsConfig.includeTextureInAddon = sConfigMgr->GetOption<bool>("Hotspots.IncludeTextureInAddon", false);
    sHotspotsConfig.buffTexture = sConfigMgr->GetOption<std::string>("Hotspots.BuffTexture", std::string(""));
    sHotspotsConfig.gmBypassLimit = sConfigMgr->GetOption<bool>("Hotspots.GmBypassLimit", true);
    sHotspotsConfig.allowWorldwideSpawn = sConfigMgr->GetOption<bool>("Hotspots.AllowWorldwideSpawn", true);

    std::string mapsStr = sConfigMgr->GetOption<std::string>("Hotspots.EnabledMaps", "0,1,530,571");
    sHotspotsConfig.enabledMaps = ParseUInt32List(mapsStr);

    std::string zonesStr = sConfigMgr->GetOption<std::string>("Hotspots.EnabledZones", "");
    sHotspotsConfig.enabledZones = ParseUInt32List(zonesStr);

    std::string excludedStr = sConfigMgr->GetOption<std::string>("Hotspots.ExcludedZones", "");
    sHotspotsConfig.excludedZones = ParseUInt32List(excludedStr);

    std::string perMapStr = sConfigMgr->GetOption<std::string>("Hotspots.EnabledZonesPerMap", "");
    sHotspotsConfig.enabledZonesPerMap = ParseZonesPerMap(perMapStr);

    sHotspotsConfig.initialPopulateCount = sConfigMgr->GetOption<uint32>("Hotspots.InitialPopulateCount", 0);

    // Anti-camping configuration
    sHotspotsConfig.antiCampingEnabled = sConfigMgr->GetOption<bool>("Hotspots.AntiCamping.Enabled", true);
    sHotspotsConfig.antiCampingInterval = sConfigMgr->GetOption<uint32>("Hotspots.AntiCamping.Interval", 600);
    
    // Parse anti-camping tiers (comma-separated floats)
    std::string tiersStr = sConfigMgr->GetOption<std::string>("Hotspots.AntiCamping.Tiers", "1.0,0.75,0.50,0.25");
    sHotspotsConfig.antiCampingTiers.clear();
    if (!tiersStr.empty())
    {
        std::istringstream ss(tiersStr);
        std::string token;
        while (std::getline(ss, token, ','))
        {
            try {
                float val = std::stof(token);
                sHotspotsConfig.antiCampingTiers.push_back(val);
            } catch (...) {
                LOG_WARN("config", "Invalid anti-camping tier value: {}", token);
            }
        }
    }
    if (sHotspotsConfig.antiCampingTiers.empty())
    {
        // Fallback to default tiers
        sHotspotsConfig.antiCampingTiers = {1.0f, 0.75f, 0.50f, 0.25f};
    }

    // Validate configuration values
    bool hasError = false;
    
    if (sHotspotsConfig.radius <= 0.0f)
    {
        LOG_ERROR("config", "Hotspots.Radius ({}) must be positive, using default 150.0", sHotspotsConfig.radius);
        sHotspotsConfig.radius = 150.0f;
        hasError = true;
    }
    
    if (sHotspotsConfig.duration == 0)
    {
        LOG_ERROR("config", "Hotspots.Duration cannot be 0, using default 60 minutes");
        sHotspotsConfig.duration = 60;
        hasError = true;
    }
    
    if (sHotspotsConfig.respawnDelay == 0)
    {
        LOG_ERROR("config", "Hotspots.RespawnDelay cannot be 0, using default 30 minutes");
        sHotspotsConfig.respawnDelay = 30;
        hasError = true;
    }
    
    if (sHotspotsConfig.maxActive == 0)
    {
        LOG_WARN("config", "Hotspots.MaxActive is 0, no hotspots will spawn! Consider setting to 1 or more.");
    }
    
    if (sHotspotsConfig.minActive > sHotspotsConfig.maxActive)
    {
        LOG_ERROR("config", "Hotspots.MinActive ({}) > Hotspots.MaxActive ({}), clamping to maxActive", 
                  sHotspotsConfig.minActive, sHotspotsConfig.maxActive);
        sHotspotsConfig.minActive = sHotspotsConfig.maxActive;
        hasError = true;
    }
    
    if (sHotspotsConfig.experienceBonus > 10000)
    {
        LOG_WARN("config", "Hotspots.ExperienceBonus ({}) is extremely high (>10000%), this may cause overflow issues", sHotspotsConfig.experienceBonus);
    }
    
    if (sHotspotsConfig.announceRadius < 0.0f)
    {
        LOG_ERROR("config", "Hotspots.AnnounceRadius cannot be negative ({}), using default 500.0", sHotspotsConfig.announceRadius);
        sHotspotsConfig.announceRadius = 500.0f;
        hasError = true;
    }
    
    if (hasError)
    {
        LOG_INFO("config", "Hotspots configuration loaded with errors - some values were corrected to safe defaults");
    }
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

// Helper: count active hotspots in a specific zone
static uint32 GetHotspotCountInZone(uint32 zoneId)
{
    uint32 count = 0;
    for (auto const& hotspot : sActiveHotspots)
    {
        if (hotspot.zoneId == zoneId && hotspot.IsActive())
            ++count;
    }
    return count;
}

// Helper: check if zone can accept another hotspot (respects maxPerZone limit)
static bool CanSpawnInZone(uint32 zoneId)
{
    // If maxPerZone is 0, unlimited hotspots per zone allowed
    if (sHotspotsConfig.maxPerZone == 0)
        return true;
    
    uint32 currentCount = GetHotspotCountInZone(zoneId);
    return currentCount < sHotspotsConfig.maxPerZone;
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

    const int attemptsPerRect = 48; // higher attempts per rectangle (increased for better chance on irregular terrain)
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
                // Sample a few representative rectangles in Outland (map 530)
                coords = {
                    { 2200.0f, 5200.0f, -3500.0f, -1500.0f, 100.0f, 3524 }, // Hellfire Peninsula-like area
                    { 600.0f, 2600.0f, 400.0f, 2600.0f, 150.0f, 3520 }     // Shadowmoon-like area
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

        // Filter by allowed zones and maxPerZone limit
        std::vector<MapCoords> allowedCoords;
        for (auto const& coord : coords)
        {
            if (IsZoneAllowed(candidateMapId, coord.zoneId) && CanSpawnInZone(coord.zoneId))
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
                    const int fallbackAttempts = 2048; // increase attempts to improve chance of finding valid ground

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

                        // Record first few sampled points for diagnostic when sampling ultimately fails
                        if (fa < 12)
                        {
                            LOG_DEBUG("scripts", "GetRandomHotspotPosition: sample map {} cand#{} ({:.1f},{:.1f}) -> groundZ={}", candidateMapId, fa, candX, candY, groundZ);
                        }

                        if (groundZ > MIN_HEIGHT && std::isfinite(groundZ))
                        {
                            // Skip positions in or under water
                            constexpr float PLAYER_HEIGHT_APPROX = 2.0f; // approximate player height
                            if (map->IsInWater(PHASEMASK_NORMAL, candX, candY, groundZ, PLAYER_HEIGHT_APPROX) ||
                                map->IsUnderWater(PHASEMASK_NORMAL, candX, candY, groundZ, PLAYER_HEIGHT_APPROX))
                            {
                                LOG_DEBUG("scripts", "GetRandomHotspotPosition: skipping water position at ({:.1f},{:.1f},{:.1f}) on map {}", candX, candY, groundZ, candidateMapId);
                                continue;
                            }

                            // Resolve zone id for sampled point
                            uint32 resolvedZone = sMapMgr->GetZoneId(PHASEMASK_NORMAL, candidateMapId, candX, candY, groundZ);
                            LOG_DEBUG("scripts", "GetRandomHotspotPosition: sampled point resolved to zone {} on map {}", resolvedZone, candidateMapId);
                            // Only accept sampled point if zone is allowed by per-map config (respecting zone 0 = all) and respects maxPerZone
                            if (IsZoneAllowed(candidateMapId, resolvedZone) && CanSpawnInZone(resolvedZone))
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
                    LOG_WARN("scripts", "GetRandomHotspotPosition: per-map enabled zones present for map {} but fallback sampling found no valid ground. See previous DEBUG lines for sampled candidates and groundZ values. Bounds used: [{}, {}, {}, {}]", candidateMapId, b[0], b[1], b[2], b[3]);
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
                    // Skip positions in or under water
                    constexpr float PLAYER_HEIGHT_APPROX = 2.0f; // approximate player height
                    if (map->IsInWater(PHASEMASK_NORMAL, candX, candY, groundZ, PLAYER_HEIGHT_APPROX) ||
                        map->IsUnderWater(PHASEMASK_NORMAL, candX, candY, groundZ, PLAYER_HEIGHT_APPROX))
                    {
                        LOG_DEBUG("scripts", "GetRandomHotspotPosition: skipping water position at ({:.1f},{:.1f},{:.1f}) on map {}", candX, candY, groundZ, candidateMapId);
                        continue;
                    }

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
        Map* map = GetBaseMapSafe(mapId);
        if (!map)
        {
            LOG_ERROR("scripts", "SpawnHotspot: Failed to get map {} for hotspot #{} visual marker", mapId, hotspot.id);
        }
        else
        {
            // Create GameObject from template
            if (!sObjectMgr)
            {
                LOG_ERROR("scripts", "SpawnHotspot: sObjectMgr is null!");
            }
            else if (GameObjectTemplate const* goInfo = sObjectMgr->GetGameObjectTemplate(sHotspotsConfig.markerGameObjectEntry))
            {
                GameObject* go = new GameObject();
                // Create expects: guidlow, entry, map, phaseMask, x,y,z, ang, rotation, animprogress, go_state
                float ang = 0.0f;
                // Map doesn't expose a GetPhaseMask(); use default phase mask (0) for world markers.
                uint32 phaseMask = 0;

                // Prefer ground-sampled Z to avoid placing markers underwater or inside terrain.
                float markerZ = z;
                float sampledZ = map->GetHeight(x, y, z);
                if (std::isfinite(sampledZ) && sampledZ > MIN_HEIGHT)
                {
                    markerZ = sampledZ + 0.5f; // lift slightly above ground
                    hotspot.z = markerZ; // update hotspot record so in-range checks and messages use ground Z
                }
                else
                {
                    LOG_WARN("scripts", "SpawnHotspot: GetHeight returned invalid Z ({}) for hotspot #{} at ({:.1f},{:.1f})", 
                             sampledZ, hotspot.id, x, y);
                }

                // Generate a low guid once and reuse it for logging and creation
                uint32 lowGuid = map->GenerateLowGuid<HighGuid::GameObject>();
                LOG_DEBUG("scripts", "Attempting to create hotspot marker GO entry={} lowGuid={} on map {} at ({:.1f},{:.1f},{:.1f})",
                          sHotspotsConfig.markerGameObjectEntry, lowGuid, mapId, x, y, markerZ);

                if (go->Create(lowGuid, sHotspotsConfig.markerGameObjectEntry,
                              map, phaseMask, x, y, markerZ, ang, G3D::Quat(), 255, GO_STATE_READY))
                {
                    go->SetRespawnTime(sHotspotsConfig.duration * MINUTE);
                    if (!map->AddToMap(go))
                    {
                        delete go;
                        LOG_ERROR("scripts", "SpawnHotspot: AddToMap failed for hotspot #{} marker (entry={} lowGuid={} map={})",
                                  hotspot.id, sHotspotsConfig.markerGameObjectEntry, lowGuid, mapId);
                    }
                    else
                    {
                        hotspot.gameObjectGuid = go->GetGUID();
                        LOG_DEBUG("scripts", "Hotspot #{} spawned GameObject marker (GUID: {}) at ({}, {}, {}) on map {}",
                                  hotspot.id, go->GetGUID().ToString(), hotspot.x, hotspot.y, hotspot.z, mapId);
                    }
                }
                else
                {
                    delete go;
                    LOG_ERROR("scripts", "Failed to create hotspot marker GameObject (entry={} lowGuid={} map={})", 
                              sHotspotsConfig.markerGameObjectEntry, lowGuid, mapId);
                }
            }
            else
            {
                LOG_ERROR("scripts", "SpawnHotspot: GameObject template {} not found!", sHotspotsConfig.markerGameObjectEntry);
            }
        }
    }

    sActiveHotspots.push_back(hotspot);

    // Save to database for persistence
    SaveHotspotToDB(hotspot);

    // Log spawn details for debugging and persistence validation
    LOG_INFO("scripts", "Spawned Hotspot #{} on map {} (zone {}) at ({:.1f}, {:.1f}, {:.1f}) expiring in {}s",
             hotspot.id, hotspot.mapId, hotspot.zoneId, hotspot.x, hotspot.y, hotspot.z,
             static_cast<int32>(hotspot.expireTime - hotspot.spawnTime));

    if (sHotspotsConfig.announceSpawn)
    {
        // Resolve human friendly names where possible
        std::string mapName = GetMapName(mapId);
        std::string zoneName = GetSafeZoneName(hotspot.zoneId);

        std::ostringstream ss;
        ss << "|cFFFFD700[Hotspot]|r A new XP Hotspot has appeared in " << mapName
           << " (" << zoneName << ") at (" << std::fixed << std::setprecision(1)
           << hotspot.x << ", " << hotspot.y << ", " << hotspot.z << ")"
           << "! (+" << sHotspotsConfig.experienceBonus << "% XP)";

      sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, ss.str());

      // Send a structured message for addons to parse reliably
      // Format: HOTSPOT_ADDON|map:<mapId>|zone:<zoneId>|x:<x>|y:<y>|z:<z>|id:<id>|dur:<seconds>|icon:<spellId>
        std::string rawPayload = BuildHotspotAddonPayload(hotspot, static_cast<int32>(sHotspotsConfig.duration * MINUTE));
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
              
              // Optionally send addon packet to enable addon visualization (disabled by default)
              if (sHotspotsConfig.sendAddonPackets)
              {
                  // Guard payload length to avoid sending oversized addon messages that
                  // could break some clients. If payload is too large, skip the ADDON packet
                  // and rely on the system-text fallback which was already sent above.
                  const size_t MAX_ADDON_PAYLOAD = 512; // conservative limit in bytes
                  // Build a trimmed payload that omits optional texture tokens (|tex:... and |texid:...) to keep ADDON packets compact
                  std::string trimmedPayload = TrimAddonPayload(rawPayload);
                  
                  if (trimmedPayload.size() <= MAX_ADDON_PAYLOAD)
                  {
                      std::string addonMsgTrimmed = std::string("HOTSPOT\t") + trimmedPayload;
                      WorldPacket pkt;
                      ChatHandler::BuildChatPacket(pkt, CHAT_MSG_ADDON, LANG_ADDON, plr, plr, addonMsgTrimmed);
                      plr->SendDirectMessage(&pkt);
                  }
                  else
                  {
                      LOG_WARN("scripts", "Hotspot #{} trimmed payload too long ({} bytes) — skipping CHAT_MSG_ADDON send to {}", hotspot.id, trimmedPayload.size(), plr->GetName());
                      std::string preview = rawPayload.substr(0, std::min<size_t>(rawPayload.size(), 400));
                      LOG_INFO("scripts", "Hotspot #{} payload preview (first {} chars): {}", hotspot.id, preview.size(), EscapeBraces(preview));
                  }
              }
              announcedCount++;
              // INFO log for operator visibility: indicate this player was notified
              LOG_INFO("scripts", "Hotspot #{} announce: sent payload to player {} (guid {}) on map {}", hotspot.id, plr->GetName(), plr->GetGUID().ToString(), plr->GetMapId());
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
                        LOG_DEBUG("scripts", "Cleaned up hotspot #{} visual marker (GUID: {})", it->id, it->gameObjectGuid.ToString());
                    }
                    else
                    {
                        LOG_WARN("scripts", "CleanupExpiredHotspots: GameObject GUID {} not found on map {} for hotspot #{}", 
                                 it->gameObjectGuid.ToString(), it->mapId, it->id);
                    }
                }
                else
                {
                    LOG_ERROR("scripts", "CleanupExpiredHotspots: Failed to get map {} for hotspot #{} cleanup", it->mapId, it->id);
                }
            }

            // Delete from database
            DeleteHotspotFromDB(it->id);

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

    // Clean up per-player server-side hotspot expiry flags that have passed
    time_t now = GameTime::GetGameTime().count();
    for (auto itr = sPlayerHotspotExpiry.begin(); itr != sPlayerHotspotExpiry.end(); )
    {
        if (itr->second <= now)
            itr = sPlayerHotspotExpiry.erase(itr);
        else
            ++itr;
    }

    // Maintain minimum active hotspots: if we've fallen below minActive, spawn new ones immediately
    if (sHotspotsConfig.minActive > 0)
    {
        uint32 currentActive = static_cast<uint32>(sActiveHotspots.size());
        if (currentActive < sHotspotsConfig.minActive)
        {
            uint32 toSpawn = sHotspotsConfig.minActive - currentActive;
            LOG_INFO("scripts", "CleanupExpiredHotspots: Active hotspots ({}) below minimum ({}), spawning {} new hotspot(s)",
                     currentActive, sHotspotsConfig.minActive, toSpawn);
            
            for (uint32 i = 0; i < toSpawn; ++i)
            {
                if (!SpawnHotspot())
                {
                    LOG_WARN("scripts", "CleanupExpiredHotspots: Failed to spawn replacement hotspot ({}/{})", i + 1, toSpawn);
                    break;
                }
            }
        }
    }
}

// Check if player is in any hotspot
static Hotspot const* GetPlayerHotspot(Player* player)
{
    if (!player || !sHotspotsConfig.enabled)
        return nullptr;

    for (const Hotspot& hotspot : sActiveHotspots)
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

    LOG_DEBUG("scripts", "=== CheckPlayerHotspotStatusImmediate START for {} ===", player->GetName());
    LOG_DEBUG("scripts", "Player: map={} pos=({:.1f},{:.1f},{:.1f})", 
             player->GetMapId(), player->GetPositionX(), player->GetPositionY(), player->GetPositionZ());
    LOG_DEBUG("scripts", "Active hotspots: {}", sActiveHotspots.size());

    Hotspot const* hotspot = GetPlayerHotspot(player);
    bool hasBuffAura = player->HasAura(sHotspotsConfig.buffSpell);

    LOG_DEBUG("scripts", "Result: hotspot={} hasBuffAura={}", hotspot != nullptr, hasBuffAura);

    if (hotspot && !hasBuffAura)
    {
        LOG_DEBUG("scripts", "APPLYING BUFF: Player in hotspot but no aura yet");
            ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[Hotspot DEBUG]|r immediate detected hotspot ID {} nearby (zone {})", hotspot->id, hotspot->zoneId);
        if (SpellInfo const* auraInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.auraSpell))
        {
            LOG_DEBUG("scripts", "Casting aura spell {}", sHotspotsConfig.auraSpell);
            player->CastSpell(player, sHotspotsConfig.auraSpell, true);
        }
        else
            LOG_WARN("scripts", "Aura spell {} not found", sHotspotsConfig.auraSpell);
            
        if (SpellInfo const* buffInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.buffSpell))
        {
            LOG_DEBUG("scripts", "Casting buff spell {}", sHotspotsConfig.buffSpell);
            player->CastSpell(player, sHotspotsConfig.buffSpell, true);
        }
        else
            LOG_WARN("scripts", "Buff spell {} not found", sHotspotsConfig.buffSpell);
            
                ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[Hotspot DEBUG]|r immediate applied buff spell id {}", sHotspotsConfig.buffSpell);
    }
    else if (!hotspot && hasBuffAura)
    {
        LOG_DEBUG("scripts", "REMOVING BUFF: Player not in hotspot but has aura");
        player->RemoveAura(sHotspotsConfig.buffSpell);
                ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[Hotspot DEBUG]|r immediate removed buff spell id {}", sHotspotsConfig.buffSpell);
    }
    else if (hotspot && hasBuffAura)
    {
        LOG_DEBUG("scripts", "ALREADY BUFFED: Player in hotspot and has aura");
    }
    else
    {
        LOG_DEBUG("scripts", "NO ACTION: Player not in any hotspot");
    }
    LOG_DEBUG("scripts", "=== CheckPlayerHotspotStatusImmediate END ===");
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
            LOG_INFO("server.loading", ">> - Min Active: {}", sHotspotsConfig.minActive);
            LOG_INFO("server.loading", ">> - Max Per Zone: {} {}", sHotspotsConfig.maxPerZone, sHotspotsConfig.maxPerZone == 0 ? "(unlimited)" : "");
            LOG_INFO("server.loading", ">> - Enabled Maps: {}", sHotspotsConfig.enabledMaps.size());
            LOG_INFO("server.loading", ">> - Database Persistence: Enabled");
            LOG_INFO("server.loading", ">> - Anti-Camping: {}", sHotspotsConfig.antiCampingEnabled ? "Enabled" : "Disabled");
            if (sHotspotsConfig.antiCampingEnabled)
            {
                LOG_INFO("server.loading", ">>   - Interval: {} seconds", sHotspotsConfig.antiCampingInterval);
                std::ostringstream tss;
                for (size_t i = 0; i < sHotspotsConfig.antiCampingTiers.size(); ++i)
                {
                    if (i > 0) tss << ", ";
                    tss << static_cast<uint32>(sHotspotsConfig.antiCampingTiers[i] * 100) << "%";
                }
                LOG_INFO("server.loading", ">>   - Tiers: {}", tss.str());
            }
            
            // Initialize spawn timer origin so respawnDelay is measured from server start
            sLastSpawnCheck = GameTime::GetGameTime().count();

            // Build DBC-derived map bounds used for normalized coordinates
            BuildMapBoundsFromDBC();

            // Ensure database table exists (auto-create if missing)
            EnsureHotspotTableExists();

            // Load persistent hotspots from database
            LoadHotspotsFromDB();

            // Only use DBC-derived bounds in this configuration (Hyjal/Azshara DBC entries expected)

            // Debug: report loaded map bounds count and presence of map 37
            {
                size_t count = sMapBounds.size();
                bool has37 = (sMapBounds.find(37) != sMapBounds.end());
                LOG_INFO("scripts", "Hotspots: loaded map bounds count = {} ; map 37 present = {}", count, has37);
                if (!has37)
                    LOG_WARN("scripts", "Hotspots: map 37 not found in DBC-derived map bounds - ensure WorldMapArea.dbc contains entries for this map");
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

            // If initialPopulateCount is 0, populate up to maxActive (respecting minActive as a floor)
            uint32 toSpawn = sHotspotsConfig.initialPopulateCount == 0 ? sHotspotsConfig.maxActive : sHotspotsConfig.initialPopulateCount;
            toSpawn = std::min<uint32>(toSpawn, sHotspotsConfig.maxActive);
            // Ensure we at least reach minActive
            toSpawn = std::max<uint32>(toSpawn, sHotspotsConfig.minActive);
            
            LOG_INFO("scripts", "Hotspots: Startup population config: initialPopulateCount={}, maxActive={}, minActive={}, target={}",
                     sHotspotsConfig.initialPopulateCount, sHotspotsConfig.maxActive, sHotspotsConfig.minActive, toSpawn);
            
            // Recreate visual markers for any hotspots loaded from database
            RecreateHotspotVisualMarkers();
            
            // Only spawn if we have fewer hotspots than target (after loading from DB)
            uint32 currentCount = static_cast<uint32>(sActiveHotspots.size());
            if (currentCount < toSpawn)
            {
                uint32 needToSpawn = toSpawn - currentCount;
                LOG_INFO("scripts", "Hotspots: Need to spawn {} hotspot(s) to reach target of {} (current: {}, minActive: {})", 
                         needToSpawn, toSpawn, currentCount, sHotspotsConfig.minActive);
                uint32 spawned = 0;
                for (uint32 i = 0; i < needToSpawn; ++i)
                {
                    if (SpawnHotspot())
                    {
                        spawned++;
                    }
                    else
                    {
                        LOG_WARN("scripts", "SpawnHotspot() returned false during initial population (attempt {}/{})", i + 1, needToSpawn);
                    }
                }
                LOG_INFO("scripts", "Hotspots: Startup spawning complete - spawned {}/{} hotspots, total active now: {}",
                         spawned, needToSpawn, sActiveHotspots.size());
            }
            else
            {
                LOG_INFO("scripts", "Hotspots: {} hotspot(s) already active (target: {}), no additional spawning needed", 
                         currentCount, toSpawn);
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
                // Build a canonical payload via the centralized helper so both
                // login-time sends and live spawn broadcasts remain identical.
                Hotspot tmp = hotspot; // copy to pass into helper
                std::string rawPayload = BuildHotspotAddonPayload(tmp, static_cast<int32>(hotspot.expireTime - GameTime::GetGameTime().count()));
                ChatHandler(player->GetSession()).SendSysMessage(rawPayload);
                LOG_INFO("scripts", "Login: sent hotspot payload to {} -> {}", player->GetName(), rawPayload);
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
            // If there are pending retries for this player and player still lacks aura, try again
            auto it = sBuffApplyRetries.find(guid);
            if (it != sBuffApplyRetries.end())
            {
                if (!player->HasAura(sHotspotsConfig.buffSpell) && it->second > 0)
                {
                    LOG_INFO("scripts", "Retrying hotspot buff application for {} ({} retries left)", player->GetName(), it->second);
                    if (SpellInfo const* auraInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.auraSpell))
                        player->CastSpell(player, sHotspotsConfig.auraSpell, true);
                    if (SpellInfo const* buffInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.buffSpell))
                        player->CastSpell(player, sHotspotsConfig.buffSpell, true);
                    it->second -= 1;
                }
                else
                {
                    // Aura applied or retries exhausted: clear entry
                    sBuffApplyRetries.erase(it);
                }
            }
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
            LOG_DEBUG("scripts", "Player {} entered Hotspot #{} (zone {}, map {})", player->GetName(), hotspot->id, hotspot->zoneId, hotspot->mapId);
            
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
            if (SpellInfo const* auraInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.auraSpell))
            {
                LOG_DEBUG("scripts", "Casting aura spell {} on player {}", sHotspotsConfig.auraSpell, player->GetName());
                player->CastSpell(player, sHotspotsConfig.auraSpell, true);
            }
            if (SpellInfo const* buffInfo = sSpellMgr->GetSpellInfo(buffSpellId))
            {
                LOG_DEBUG("scripts", "Casting buff spell {} on player {}", buffSpellId, player->GetName());
                player->CastSpell(player, buffSpellId, true);
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700[Hotspot]|r You have entered an XP Hotspot! +{}% experience from kills!", sHotspotsConfig.experienceBonus);

                // If the aura was not registered immediately, schedule retries (up to 3 attempts)
                if (!player->HasAura(buffSpellId))
                {
                    LOG_WARN("scripts", "Initial buff cast did not result in aura for {} — scheduling retries", player->GetName());
                    sBuffApplyRetries[player->GetGUID()] = 3;
                }
                // Server-side persistent flag: mark player as in-hotspot until hotspot expire time
                sPlayerHotspotExpiry[player->GetGUID()] = hotspot->expireTime;
            }
            else
            {
                LOG_WARN("scripts", "Buff spell {} not found in spell manager", buffSpellId);
            }
        }
        else if (!hotspot && hasBuffAura)
        {
            // Player left hotspot
            LOG_DEBUG("scripts", "Player {} left Hotspot (no longer in range)", player->GetName());
            player->RemoveAura(sHotspotsConfig.buffSpell);
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF6347[Hotspot Notice]|r You have left the XP Hotspot zone. XP bonus deactivated."
            );
            // Remove any pending retries
            sBuffApplyRetries.erase(player->GetGUID());
            // Clear server-side persistent hotspot flag
            sPlayerHotspotExpiry.erase(player->GetGUID());
            // Clear anti-camping tracking
            ClearPlayerHotspotTracking(player);
        }
    }
};

// Modify XP gain when in hotspot
class HotspotsPlayerGainXP : public PlayerScript
{
public:
    HotspotsPlayerGainXP() : PlayerScript("HotspotsPlayerGainXP") { }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 /*xpSource*/) override
    {
        if (!sHotspotsConfig.enabled || !player)
            return;
        // Debug entry: log XP events only at DEBUG level to avoid flooding logs
        uint32 buffCount = player->GetAuraCount(sHotspotsConfig.buffSpell);
        uint32 auraCount = player->GetAuraCount(sHotspotsConfig.auraSpell);
        std::string victimName = "<none>";
        if (victim)
        {
            // Use the instance method GetTypeId() on the victim to determine its runtime type
            if (victim->GetTypeId() == TYPEID_UNIT)
            {
                if (Creature* c = victim->ToCreature())
                    victimName = c->GetName();
            }
            else if (victim->GetTypeId() == TYPEID_PLAYER)
            {
                if (Player* pVictim = victim->ToPlayer())
                    victimName = pVictim->GetName();
            }
        }

        LOG_DEBUG("scripts", "OnGiveXP: player {} gaining {} XP from victim {} (buffCount={} auraCount={}) pos=({:.1f},{:.1f},{:.1f}) map={}",
             player->GetName(), amount, victimName.c_str(), buffCount, auraCount,
             player->GetPositionX(), player->GetPositionY(), player->GetPositionZ(), player->GetMapId());

        // Check if player has hotspot buff aura or the auxiliary aura (some spell setups apply one or the other)
        bool hasHotspotBuff = player->HasAura(sHotspotsConfig.buffSpell);
        bool hasHotspotAura = player->HasAura(sHotspotsConfig.auraSpell);

        // Consider player 'buffed' if either the buff or the aura is present
        bool isBuffed = hasHotspotBuff || hasHotspotAura;

        // Also consider server-side persistent flag as a fallback: if the player has an
        // active expiry entry in sPlayerHotspotExpiry and it hasn't expired, treat them as buffed.
        auto itExpiry = sPlayerHotspotExpiry.find(player->GetGUID());
        if (!isBuffed && itExpiry != sPlayerHotspotExpiry.end())
        {
            time_t now = GameTime::GetGameTime().count();
            if (itExpiry->second > now)
            {
                isBuffed = true;
                LOG_DEBUG("scripts", "OnGiveXP: player {} treated as in-hotspot via server-side expiry (expire at {})", player->GetName(), itExpiry->second);
            }
            else
            {
                // expiry passed: clear stale entry
                sPlayerHotspotExpiry.erase(itExpiry);
            }
        }

        if (isBuffed)
        {
            uint32 originalAmount = amount;
            uint32 bonus = (amount * sHotspotsConfig.experienceBonus) / 100;
            
            // Apply anti-camping diminishing returns
            float antiCampMultiplier = 1.0f;
            if (sHotspotsConfig.antiCampingEnabled)
            {
                Hotspot const* hotspot = GetPlayerHotspot(player);
                if (hotspot)
                {
                    antiCampMultiplier = GetAntiCampingMultiplier(player, hotspot->id);
                    UpdatePlayerHotspotTracking(player, hotspot->id);
                }
            }
            
            // Apply multiplier to bonus
            bonus = static_cast<uint32>(bonus * antiCampMultiplier);
            amount += bonus;

            // Send visible notification to player about the bonus
            if (antiCampMultiplier < 1.0f)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFFFFD700[Hotspot XP]|r +{} XP ({} base + {}% bonus x {:.0f}% = {} total)",
                    bonus, originalAmount, sHotspotsConfig.experienceBonus, antiCampMultiplier * 100, amount);
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFFFFD700[Hotspot XP]|r +{} XP ({} base + {}% bonus = {} total)",
                    bonus, originalAmount, sHotspotsConfig.experienceBonus, amount);
            }

            LOG_DEBUG("scripts", "Hotspot XP Bonus applied to {}: victim={} base={} bonus={} anticamp={:.2f} final={} (serverFlag={})",
                    player->GetName(), victimName.c_str(), originalAmount, bonus, antiCampMultiplier, amount,
                    (sPlayerHotspotExpiry.find(player->GetGUID()) != sPlayerHotspotExpiry.end()));
        }
        else
        {
            // Player is not considered buffed. Log comprehensive diagnostic info to trace why.
            bool hasServerFlag = (sPlayerHotspotExpiry.find(player->GetGUID()) != sPlayerHotspotExpiry.end());
            Hotspot const* nearby = GetPlayerHotspot(player);
            int nearbyId = nearby ? nearby->id : 0;
            LOG_DEBUG("scripts", "Hotspot: {} gained {} XP (NOT buffed). buffCount={} auraCount={} serverFlag={} nearbyHotspotId={} pos=({:.1f},{:.1f},{:.1f}) map={}",
                     player->GetName(), amount, buffCount, auraCount, hasServerFlag, nearbyId,
                     player->GetPositionX(), player->GetPositionY(), player->GetPositionZ(), player->GetMapId());
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
            ChatCommandBuilder("spawnworld", HandleHotspotsSpawnWorldCommand, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("testmsg", HandleHotspotsTestMsgCommand, SEC_GAMEMASTER, Console::No),
            ChatCommandBuilder("testpayload", HandleHotspotsTestPayloadCommand, SEC_GAMEMASTER, Console::No),
            ChatCommandBuilder("testxp", HandleHotspotsTestXPCommand, SEC_GAMEMASTER, Console::No),
            ChatCommandBuilder("setbonus", HandleHotspotsSetBonusCommand, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("bonus", HandleHotspotsShowBonusCommand, SEC_PLAYER, Console::No),
            ChatCommandBuilder("addonpackets", HandleHotspotsAddonPacketsCommand, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("dump",   HandleHotspotsDumpCommand,   SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("clear",  HandleHotspotsClearCommand,  SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("reload", HandleHotspotsReloadCommand, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("tp",     HandleHotspotsTeleportCommand, SEC_GAMEMASTER,  Console::No),
            ChatCommandBuilder("forcebuff", HandleHotspotsForceBuffCommand, SEC_ADMINISTRATOR, Console::No),
            ChatCommandBuilder("status", HandleHotspotsStatusCommand, SEC_PLAYER, Console::No)
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
            std::string zoneName = GetSafeZoneName(hotspot.zoneId);
            
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

        // Allow GM bypass of the active limit when configured
        if (sActiveHotspots.size() >= sHotspotsConfig.maxActive && !sHotspotsConfig.gmBypassLimit)
        {
            handler->SendSysMessage("Cannot spawn hotspot: max active hotspots reached.");
            return true;
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

        sActiveHotspots.push_back(hotspot);

        // Spawn visual marker GameObject if enabled (mirror SpawnHotspot behavior)
        if (sHotspotsConfig.spawnVisualMarker)
        {
            if (Map* map = GetBaseMapSafe(mapId))
            {
                if (GameObjectTemplate const* goInfo = sObjectMgr->GetGameObjectTemplate(sHotspotsConfig.markerGameObjectEntry))
                {
                    GameObject* go = new GameObject();
                    float ang = 0.0f;
                    uint32 phaseMask = 0;

                    // Prefer ground-sampled Z to avoid placing markers underwater or inside terrain.
                    float markerZ = z;
                    float sampledZ = map->GetHeight(x, y, z);
                    if (!std::isnan(sampledZ) && std::isfinite(sampledZ))
                    {
                        markerZ = sampledZ + 0.5f;
                        // update hotspot z for consistency
                        sActiveHotspots.back().z = markerZ;
                    }

                    uint32 lowGuid = map->GenerateLowGuid<HighGuid::GameObject>();
                    LOG_DEBUG("scripts", "Attempting to create hotspot marker GO entry={} lowGuid={} on map {} at ({:.1f},{:.1f},{:.1f}) (spawnhere)",
                              sHotspotsConfig.markerGameObjectEntry, lowGuid, mapId, x, y, markerZ);

                    if (go->Create(lowGuid, sHotspotsConfig.markerGameObjectEntry,
                                  map, phaseMask, x, y, markerZ, ang, G3D::Quat(), 255, GO_STATE_READY))
                    {
                        go->SetRespawnTime(sHotspotsConfig.duration * MINUTE);
                        map->AddToMap(go);
                        sActiveHotspots.back().gameObjectGuid = go->GetGUID();
                        LOG_DEBUG("scripts", "Hotspot #{} spawned GameObject marker (GUID: {}) at ({}, {}, {}) on map {}",
                                  sActiveHotspots.back().id, go->GetGUID().ToString(), sActiveHotspots.back().x, sActiveHotspots.back().y, sActiveHotspots.back().z, mapId);
                    }
                    else
                    {
                        delete go;
                        LOG_ERROR("scripts", "Failed to create hotspot marker GameObject (spawnhere) entry={} lowGuid={} map={}", sHotspotsConfig.markerGameObjectEntry, lowGuid, mapId);
                    }
                }
            }
        }

        std::string zoneName = GetSafeZoneName(zoneId);

        handler->PSendSysMessage("Spawned hotspot {} at {}: {}, {:.1f}, {:.1f}, {:.1f}", 
                                hotspot.id, zoneName, mapId, x, y, z);

    // Broadcast to all players (human-friendly) and include the configured bonus percent
    std::ostringstream ss;
    ss << "Hotspot spawned in " << zoneName << " (+" << sHotspotsConfig.experienceBonus << "% XP)!";
    sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, ss.str());

        // Send addon message to all players. GetAllSessions() returns a map<id, WorldSession*>,
        // so iterate pairs and use .second to access the WorldSession*.
        // Send messages to sessions and collect players that should be buffed, apply buffs after loop
        std::vector<Player*> playersToBuff;
        for (auto const& kv : sWorldSessionMgr->GetAllSessions())
        {
            WorldSession* sess = kv.second;
            if (!sess)
                continue;
            Player* p = sess->GetPlayer();
            if (!p)
                continue;

            Hotspot tmp = hotspot; // copy for helper
            std::string rawPayload = BuildHotspotAddonPayload(tmp, static_cast<int32>(sHotspotsConfig.duration * MINUTE));

            // Send system fallback message only for the interactive spawnhere command
            ChatHandler(sess).SendSysMessage(rawPayload);
            // For safety, do not send ADDON packets from the interactive spawnhere loop as some clients
            // have proved unstable when receiving ad-hoc ADDON packets from GM commands.
            if (sHotspotsConfig.sendAddonPackets)
                LOG_INFO("scripts", "Hotspot spawnhere: sHotspotsConfig.sendAddonPackets enabled but ADDON packet suppressed for safety for player {}", p->GetName());

            // If the player is within hotspot radius, record them for buff application
            float dx = p->GetPositionX() - x;
            float dy = p->GetPositionY() - y;
            float dz = p->GetPositionZ() - z;
            float dist2 = dx*dx + dy*dy + dz*dz;
            float radius2 = sHotspotsConfig.radius * sHotspotsConfig.radius;
            if (dist2 <= radius2)
                playersToBuff.push_back(p);
        }

        // Apply buffs after we've finished iterating sessions to avoid side-effects while iterating
        for (Player* p : playersToBuff)
        {
            if (!p || !p->IsInWorld())
                continue;

            if (SpellInfo const* auraInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.auraSpell))
                p->CastSpell(p, sHotspotsConfig.auraSpell, true);
            if (SpellInfo const* buffInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.buffSpell))
                p->CastSpell(p, sHotspotsConfig.buffSpell, true);

            if (p->GetSession())
                ChatHandler(p->GetSession()).PSendSysMessage("|cFFFFD700[Hotspot]|r You have entered an XP Hotspot! +{}% experience from kills!", sHotspotsConfig.experienceBonus);
            // mark player server-side as in-hotspot until hotspot expiry
            sPlayerHotspotExpiry[p->GetGUID()] = hotspot.expireTime;
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

        Hotspot tmp;
        tmp.id = 9999;
        tmp.mapId = mapId;
        tmp.zoneId = zoneId;
        tmp.x = x;
        tmp.y = y;
        tmp.z = z;

        std::string rawPayload = BuildHotspotAddonPayload(tmp, 60);

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

    static bool HandleHotspotsTestPayloadCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            handler->SendSysMessage("No player session available to test payload.");
            return true;
        }

        // Build a synthetic hotspot payload for testing
        Hotspot tmp;
        tmp.id = 99999;
        tmp.mapId = player->GetMapId();
        tmp.zoneId = player->GetZoneId();
        tmp.x = player->GetPositionX();
        tmp.y = player->GetPositionY();
        tmp.z = player->GetPositionZ();

        std::string rawPayload = BuildHotspotAddonPayload(tmp, 3600);

        // Trim optional texture tokens (|tex: and |texid:) using the same algorithm as sending code
        std::string trimmedPayload;
        trimmedPayload.reserve(rawPayload.size());
        size_t pos = 0;
        while (pos < rawPayload.size())
        {
            size_t tpos_tex = rawPayload.find("|tex:", pos);
            size_t tpos_texid = rawPayload.find("|texid:", pos);
            size_t tpos;
            size_t tokenLen;
            if (tpos_tex == std::string::npos && tpos_texid == std::string::npos)
            {
                trimmedPayload.append(rawPayload.substr(pos));
                break;
            }
            if (tpos_tex == std::string::npos) { tpos = tpos_texid; tokenLen = 7; }
            else if (tpos_texid == std::string::npos) { tpos = tpos_tex; tokenLen = 5; }
            else if (tpos_tex < tpos_texid) { tpos = tpos_tex; tokenLen = 5; }
            else { tpos = tpos_texid; tokenLen = 7; }

            trimmedPayload.append(rawPayload.substr(pos, tpos - pos));
            size_t valStart = tpos + tokenLen;
            size_t nextPipe = rawPayload.find('|', valStart);
            if (nextPipe == std::string::npos)
                pos = rawPayload.size();
            else
                pos = nextPipe;
        }

        const size_t MAX_ADDON_PAYLOAD = 512;
        handler->PSendSysMessage("Hotspot test payload (raw length={}, trimmed length={})", (unsigned)rawPayload.size(), (unsigned)trimmedPayload.size());
        if (trimmedPayload.size() <= MAX_ADDON_PAYLOAD)
            handler->PSendSysMessage("Trimmed payload would be sent as ADDON (<= {} bytes)", (unsigned)MAX_ADDON_PAYLOAD);
        else
            handler->PSendSysMessage("Trimmed payload still too long for ADDON (limit {} bytes)", (unsigned)MAX_ADDON_PAYLOAD);

        // show preview of trimmed payload to help debug
        std::string preview = trimmedPayload.substr(0, std::min<size_t>(trimmedPayload.size(), 400));
        handler->PSendSysMessage("Trimmed payload preview: {}", preview);

        return true;
    }

    static bool HandleHotspotsTestXPCommand(ChatHandler* handler, char const* args)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            handler->SendSysMessage("No player session available to test XP on.");
            return true;
        }

        if (!args || !*args)
        {
            handler->PSendSysMessage("Usage: .hotspot testxp <amount>");
            return true;
        }

        if (Optional<uint32> maybe = Acore::StringTo<uint32>(args))
        {
            uint32 base = *maybe;
            bool hasBuff = player->HasAura(sHotspotsConfig.buffSpell);
            uint32 bonus = 0;
            uint32 total = base;
            if (hasBuff && sHotspotsConfig.enabled)
            {
                bonus = (base * sHotspotsConfig.experienceBonus) / 100;
                total = base + bonus;
            }

            handler->PSendSysMessage("Hotspot Test XP: base={} hasBuff={} bonus={} total={}", base, hasBuff ? "YES" : "NO", bonus, total);
            LOG_INFO("scripts", "Hotspot TestXP for {}: base={} hasBuff={} bonus={} total={}", player->GetName(), base, hasBuff, bonus, total);
        }
        else
        {
            handler->PSendSysMessage("Invalid amount '{}'", args);
        }

        return true;
    }

    static bool HandleHotspotsSetBonusCommand(ChatHandler* handler, char const* args)
    {
        // Usage: .hotspot setbonus <percent|off>
        if (!args || !*args)
        {
            handler->PSendSysMessage("Usage: .hotspot setbonus <percent|off>");
            handler->PSendSysMessage("Current hotspot XP bonus = {}%", sHotspotsConfig.experienceBonus);
            return true;
        }

        std::string arg = args;
        // Determine actor (player name) for logging; console handlers won't have a player session
        std::string actor = "Console";
        if (handler && handler->GetSession() && handler->GetSession()->GetPlayer())
            actor = handler->GetSession()->GetPlayer()->GetName();
        // allow common tokens
        if (arg == "off" || arg == "disable" || arg == "0")
        {
            sHotspotsConfig.experienceBonus = 0;
            handler->PSendSysMessage("Hotspot XP bonus disabled (set to 0%).");
            LOG_INFO("scripts", "Hotspots: runtime set experienceBonus = 0 by {}", actor);
            // Broadcast to all players
            {
                std::ostringstream ss;
                ss << "|cFF00FF00[Hotspots]|r " << actor << " has disabled hotspot XP bonus (set to 0%).";
                ChatHandler(nullptr).SendGlobalSysMessage(ss.str().c_str());
            }
            return true;
        }

        if (arg == "on" || arg == "enable")
        {
            // restore to configured value from config file if available
            uint32 cfg = sConfigMgr->GetOption<uint32>("Hotspots.ExperienceBonus", 100);
            sHotspotsConfig.experienceBonus = cfg;
            handler->PSendSysMessage("Hotspot XP bonus enabled (set to {}%).", sHotspotsConfig.experienceBonus);
            LOG_INFO("scripts", "Hotspots: runtime restored experienceBonus = {} by {}", sHotspotsConfig.experienceBonus, actor);
            // Broadcast to all players
            {
                std::ostringstream ss;
                ss << "|cFF00FF00[Hotspots]|r " << actor << " restored hotspot XP bonus to " << sHotspotsConfig.experienceBonus << "%";
                ChatHandler(nullptr).SendGlobalSysMessage(ss.str().c_str());
            }
            return true;
        }

        if (Optional<uint32> maybe = Acore::StringTo<uint32>(arg))
        {
            uint32 val = *maybe;
            sHotspotsConfig.experienceBonus = val;
            handler->PSendSysMessage("Hotspot XP bonus set to {}%", val);
            LOG_INFO("scripts", "Hotspots: runtime set experienceBonus = {} by {}", val, actor);
            // Broadcast to all players
            {
                std::ostringstream ss;
                ss << "|cFF00FF00[Hotspots]|r " << actor << " set hotspot XP bonus to " << val << "%";
                ChatHandler(nullptr).SendGlobalSysMessage(ss.str().c_str());
            }
            return true;
        }

        handler->PSendSysMessage("Invalid argument '{}'. Use a number, 'off' or 'on'.", args);
        return true;
    }

    static bool HandleHotspotsShowBonusCommand(ChatHandler* handler, char const* /*args*/)
    {
        // Show current hotspot configuration to player
        handler->PSendSysMessage("Hotspots enabled = {}", sHotspotsConfig.enabled ? "YES" : "NO");
        handler->PSendSysMessage("Current hotspot XP bonus = {}%", sHotspotsConfig.experienceBonus);
        handler->PSendSysMessage("Hotspot radius = {} yards", static_cast<uint32>(sHotspotsConfig.radius));
        return true;
    }

    static bool HandleHotspotsClearCommand(ChatHandler* handler, char const* /*args*/)
    {
        // Clean up visual markers before clearing
        for (auto const& hotspot : sActiveHotspots)
        {
            if (!hotspot.gameObjectGuid.IsEmpty())
            {
                if (Map* m = GetBaseMapSafe(hotspot.mapId))
                {
                    if (GameObject* go = m->GetGameObject(hotspot.gameObjectGuid))
                    {
                        go->SetRespawnTime(0);
                        go->Delete();
                    }
                }
            }
        }
        
        size_t count = sActiveHotspots.size();
        sActiveHotspots.clear();
        ClearHotspotsDB();
        handler->PSendSysMessage("Cleared {} hotspot(s) from memory and database.", count);
        
        // Immediately spawn minimum hotspots if configured
        if (sHotspotsConfig.minActive > 0)
        {
            handler->PSendSysMessage("Respawning {} minimum hotspot(s)...", sHotspotsConfig.minActive);
            for (uint32 i = 0; i < sHotspotsConfig.minActive; ++i)
            {
                if (!SpawnHotspot())
                {
                    handler->PSendSysMessage("Failed to spawn hotspot {}/{}", i + 1, sHotspotsConfig.minActive);
                    break;
                }
            }
            handler->PSendSysMessage("Active hotspots after respawn: {}", sActiveHotspots.size());
        }
        
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

        // Dump configuration values
        handler->SendSysMessage("Configuration:");
        handler->PSendSysMessage("  enabled={} maxActive={} minActive={} maxPerZone={}",
                                sHotspotsConfig.enabled ? "YES" : "NO",
                                sHotspotsConfig.maxActive,
                                sHotspotsConfig.minActive,
                                sHotspotsConfig.maxPerZone);
        handler->PSendSysMessage("  duration={}min radius={:.1f} respawnDelay={}min",
                                sHotspotsConfig.duration,
                                sHotspotsConfig.radius,
                                sHotspotsConfig.respawnDelay);
        handler->PSendSysMessage("  Active hotspots: {} (db persistence enabled)", sActiveHotspots.size());

        // Dump per-zone hotspot counts
        handler->SendSysMessage("Per-zone hotspot counts:");
        std::unordered_map<uint32, uint32> zoneCounts;
        for (auto const& hotspot : sActiveHotspots)
        {
            zoneCounts[hotspot.zoneId]++;
        }
        if (zoneCounts.empty())
        {
            handler->SendSysMessage("  (no active hotspots)");
        }
        else
        {
            for (auto const& kv : zoneCounts)
            {
                std::string zoneName = GetSafeZoneName(kv.first);
                handler->PSendSysMessage("  zone {} ({}): {} hotspot(s)", kv.first, zoneName, kv.second);
            }
        }

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
                handler->PSendSysMessage("Hotspot ID {} not found.", hotspotId);
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
            std::string zoneName = GetSafeZoneName(targetHotspot->zoneId);

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

    static bool HandleHotspotsForceBuffCommand(ChatHandler* handler, char const* args)
    {
        if (!handler->GetSession())
            return false;

        Player* src = handler->GetSession()->GetPlayer();
        if (!src)
            return false;

        // usage: .hotspot forcebuff me | <playername>
        if (!args || !*args)
        {
            handler->PSendSysMessage("Usage: .hotspot forcebuff me | <playername>");
            return true;
        }

        std::string a = args;
        if (a == "me")
        {
            if (SpellInfo const* auraInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.auraSpell))
                src->CastSpell(src, sHotspotsConfig.auraSpell, true);
            if (SpellInfo const* buffInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.buffSpell))
                src->CastSpell(src, sHotspotsConfig.buffSpell, true);
            // set server-side hotspot expiry for the caller (duration from now)
            sPlayerHotspotExpiry[src->GetGUID()] = GameTime::GetGameTime().count() + (sHotspotsConfig.duration * MINUTE);
            handler->SendSysMessage("Applied hotspot aura/buff to yourself.");
            return true;
        }

        // find player by name
        Player* target = ObjectAccessor::FindPlayerByName(a.c_str(), false);
        if (!target)
        {
            handler->PSendSysMessage("Player '{}' not found or not online.", args);
            return true;
        }

        if (SpellInfo const* auraInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.auraSpell))
            target->CastSpell(target, sHotspotsConfig.auraSpell, true);
        if (SpellInfo const* buffInfo = sSpellMgr->GetSpellInfo(sHotspotsConfig.buffSpell))
            target->CastSpell(target, sHotspotsConfig.buffSpell, true);
        // set server-side hotspot expiry for target
        sPlayerHotspotExpiry[target->GetGUID()] = GameTime::GetGameTime().count() + (sHotspotsConfig.duration * MINUTE);

    handler->PSendSysMessage("Applied hotspot aura/buff to {}.", target->GetName().c_str());
        return true;
    }

    static bool HandleHotspotsSpawnWorldCommand(ChatHandler* handler, char const* /*args*/)
    {
        if (!sHotspotsConfig.allowWorldwideSpawn)
        {
            handler->SendSysMessage("Worldwide spawn command is disabled in configuration.");
            return true;
        }

        if (sHotspotsConfig.enabledMaps.empty())
        {
            handler->SendSysMessage("No enabled maps configured for hotspots.");
            return true;
        }

        int created = 0;
        for (uint32 mapId : sHotspotsConfig.enabledMaps)
        {
            // Avoid creating duplicates on maps that already have an active hotspot
            bool already = false;
            for (auto const& h : sActiveHotspots)
            {
                if (h.mapId == mapId) { already = true; break; }
            }
            if (already) continue;

            float cx = 0.0f, cy = 0.0f, cz = 0.0f;
            uint32 zid = 0;
            auto it = sMapBounds.find(mapId);
            if (it != sMapBounds.end())
            {
                auto const& b = it->second;
                cx = (b[0] + b[1]) * 0.5f;
                cy = (b[2] + b[3]) * 0.5f;
                // try to sample ground Z via a base map if available
                if (Map* map = GetBaseMapSafe(mapId))
                {
                    float g = map->GetHeight(cx, cy, MAX_HEIGHT);
                    if (std::isfinite(g) && g > MIN_HEIGHT) cz = g;
                }
            }
            else
            {
                // skip maps without bounds to avoid spawning in unknown coords
                LOG_WARN("scripts", "SpawnWorld: skipping map {} (no bounds entry)", mapId);
                continue;
            }

            Hotspot hotspot;
            hotspot.id = sNextHotspotId++;
            hotspot.mapId = mapId;
            hotspot.zoneId = zid;
            hotspot.x = cx;
            hotspot.y = cy;
            hotspot.z = cz;
            hotspot.spawnTime = GameTime::GetGameTime().count();
            hotspot.expireTime = hotspot.spawnTime + (sHotspotsConfig.duration * MINUTE);

            // spawn visual marker if enabled
            if (sHotspotsConfig.spawnVisualMarker)
            {
                if (Map* map = GetBaseMapSafe(mapId))
                {
                    if (GameObjectTemplate const* goInfo = sObjectMgr->GetGameObjectTemplate(sHotspotsConfig.markerGameObjectEntry))
                    {
                        GameObject* go = new GameObject();
                        float ang = 0.0f; uint32 phaseMask = 0;
                        float markerZ = hotspot.z;
                        if (std::isnan(markerZ) || !std::isfinite(markerZ)) markerZ = 0.0f;
                        uint32 lowGuid = map->GenerateLowGuid<HighGuid::GameObject>();
                        LOG_DEBUG("scripts", "SpawnWorld: creating hotspot GO entry={} lowGuid={} map={} at ({:.1f},{:.1f},{:.1f})",
                                  sHotspotsConfig.markerGameObjectEntry, lowGuid, mapId, hotspot.x, hotspot.y, markerZ);

                        if (go->Create(lowGuid, sHotspotsConfig.markerGameObjectEntry,
                                      map, phaseMask, hotspot.x, hotspot.y, markerZ, ang, G3D::Quat(), 255, GO_STATE_READY))
                        {
                            go->SetRespawnTime(sHotspotsConfig.duration * MINUTE);
                            map->AddToMap(go);
                            hotspot.gameObjectGuid = go->GetGUID();
                        }
                        else
                        {
                            delete go;
                            LOG_ERROR("scripts", "SpawnWorld: failed to create hotspot GO entry={} lowGuid={} map={}", sHotspotsConfig.markerGameObjectEntry, lowGuid, mapId);
                        }
                    }
                }
            }

            sActiveHotspots.push_back(hotspot);
            // Prepare addon payload and announce to players on this map
            Hotspot tmp = hotspot;
            std::string rawPayload = BuildHotspotAddonPayload(tmp, static_cast<int32>(sHotspotsConfig.duration * MINUTE));
            std::string humanMsg;
            {
                std::ostringstream ss2;
                std::string zoneName = "Unknown";
                if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(hotspot.zoneId))
                    zoneName = area->area_name[0] ? area->area_name[0] : zoneName;
                ss2 << "Hotspot spawned in " << zoneName << " (" << hotspot.mapId << ") (+" << sHotspotsConfig.experienceBonus << "% XP)!";
                humanMsg = ss2.str();
            }

            int announced = 0;
            for (auto const& kv : sWorldSessionMgr->GetAllSessions())
            {
                WorldSession* sess = kv.second;
                if (!sess) continue;
                Player* p = sess->GetPlayer();
                if (!p) continue;
                if (p->GetMapId() != mapId) continue;

                // Send human-friendly system message to players on this map
                sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, humanMsg, p);

                // Send structured payload as system fallback
                ChatHandler(sess).SendSysMessage(rawPayload);

                // Optionally send CHAT_MSG_ADDON packet
                if (sHotspotsConfig.sendAddonPackets)
                {
                    const size_t MAX_ADDON_PAYLOAD = 512;
                    // Trim optional texture tokens (|tex: and |texid:) from the raw payload before sending
                    std::string trimmedPayload;
                    {
                        trimmedPayload.reserve(rawPayload.size());
                        size_t pos = 0;
                        while (pos < rawPayload.size())
                        {
                            size_t tpos_tex = rawPayload.find("|tex:", pos);
                            size_t tpos_texid = rawPayload.find("|texid:", pos);
                            size_t tpos;
                            size_t tokenLen;
                            if (tpos_tex == std::string::npos && tpos_texid == std::string::npos)
                            {
                                trimmedPayload.append(rawPayload.substr(pos));
                                break;
                            }
                            if (tpos_tex == std::string::npos) { tpos = tpos_texid; tokenLen = 7; }
                            else if (tpos_texid == std::string::npos) { tpos = tpos_tex; tokenLen = 5; }
                            else if (tpos_tex < tpos_texid) { tpos = tpos_tex; tokenLen = 5; }
                            else { tpos = tpos_texid; tokenLen = 7; }

                            trimmedPayload.append(rawPayload.substr(pos, tpos - pos));

                            size_t valStart = tpos + tokenLen;
                            size_t nextPipe = rawPayload.find('|', valStart);
                            if (nextPipe == std::string::npos)
                                pos = rawPayload.size();
                            else
                                pos = nextPipe;
                        }
                    }

                    if (trimmedPayload.size() <= MAX_ADDON_PAYLOAD)
                    {
                        std::string addonMsg = std::string("HOTSPOT\t") + trimmedPayload;
                        WorldPacket pkt;
                        ChatHandler::BuildChatPacket(pkt, CHAT_MSG_ADDON, LANG_ADDON, p, p, addonMsg);
                        p->SendDirectMessage(&pkt);
                    }
                    else
                    {
                        LOG_WARN("scripts", "SpawnWorld: hotspot #{} trimmed payload too long ({} bytes) — skipping CHAT_MSG_ADDON send", hotspot.id, trimmedPayload.size());
                        std::string preview = rawPayload.substr(0, std::min<size_t>(rawPayload.size(), 400));
                        LOG_INFO("scripts", "SpawnWorld hotspot #{} payload preview (first {} chars): {}", hotspot.id, preview.size(), EscapeBraces(preview));
                    }
                }

                announced++;
            }

            LOG_DEBUG("scripts", "SpawnWorld: hotspot #{} on map {} announced to {} players", hotspot.id, mapId, announced);

            created++;
        }

    handler->PSendSysMessage("Spawned worldwide hotspots on {} map(s)", created);
        return true;
    }

    static bool HandleHotspotsAddonPacketsCommand(ChatHandler* handler, char const* args)
    {
        if (!args || !*args)
        {
            handler->PSendSysMessage("Hotspots.SendAddonPackets is currently: {}", sHotspotsConfig.sendAddonPackets ? "ON" : "OFF");
            handler->PSendSysMessage("Usage: .hotspot addonpackets on|off");
            return true;
        }

        std::string a = args;
        for (auto &c : a) c = std::tolower(c);
        if (a == "on")
        {
            sHotspotsConfig.sendAddonPackets = true;
            handler->SendSysMessage("Hotspot addon packet sending ENABLED (will persist until restart unless you change config).");
        }
        else if (a == "off")
        {
            sHotspotsConfig.sendAddonPackets = false;
            handler->SendSysMessage("Hotspot addon packet sending DISABLED.");
        }
        else
        {
            handler->PSendSysMessage("Unknown argument '{}' — use on or off", args);
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
            std::string zoneName = GetSafeZoneName(nearbyHotspot->zoneId);
                
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
    // Populate map bounds from DBC only (WorldMapArea.dbc must contain entries for the maps you need)
    BuildMapBoundsFromDBC();

    new HotspotsWorldScript();
    new HotspotsPlayerScript();
    new HotspotsPlayerGainXP();
    new HotspotsCommandScript();
}
