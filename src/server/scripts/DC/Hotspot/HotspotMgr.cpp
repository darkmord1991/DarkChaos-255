#include "HotspotMgr.h"
#include "HotspotDefines.h"
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
#include "DBCStores.h"
#include "DBCStructure.h"
#include "DC/CrossSystem/CrossSystemMapCoords.h"
#include "../AddonExtension/dc_addon_namespace.h"
#include "DBCStore.h"
#include "DatabaseEnv.h"
#include "DBCEnums.h"
#include "Random.h"
#include "Tokenize.h"
#include <cctype>
#include <sstream>
#include <iomanip>
#include <cmath>
#include <algorithm>
#include <unordered_set>

// Helper to get base map safely. CreateBaseMap ASSERTs (crashes) on map ids
// missing from Map.dbc, and instanceable maps return MapInstanced whose
// players live in private instance copies — neither can host world hotspots,
// and a config typo must not take the server down.
static Map* GetBaseMapSafe(uint32 mapId)
{
    MapEntry const* entry = sMapStore.LookupEntry(mapId);
    if (!entry || entry->Instanceable())
        return nullptr;

    return sMapMgr->CreateBaseMap(mapId);
}

static std::string GetSafeZoneName(uint32 zoneId)
{
    if (const AreaTableEntry* area = sAreaTableStore.LookupEntry(zoneId))
        if (area->area_name[0])
            return area->area_name[0];
    return "Unknown Zone";
}

static bool IsZoneAllowed(uint32 mapId, uint32 zoneId)
{
    // Global exclude check
    for (uint32 ex : sHotspotsConfig.excludedZones)
        if (ex == zoneId) return false;

    // Per-map enable check (overrides global enabled list)
    auto it = sHotspotsConfig.enabledZonesPerMap.find(mapId);
    if (it != sHotspotsConfig.enabledZonesPerMap.end())
    {
        // 0 means whole map allowed in this context? No, usually specific zones.
        for (uint32 en : it->second)
            if (en == zoneId || en == 0) return true;
        return false;
    }

    // Global enable check (if not map-specific)
    if (!sHotspotsConfig.enabledZones.empty())
    {
        bool found = false;
        for (uint32 en : sHotspotsConfig.enabledZones)
        {
            if (en == zoneId) { found = true; break; }
        }
        if (!found) return false;
    }

    return true;
}

static bool IsMapEnabled(uint32 mapId)
{
    for (uint32 id : sHotspotsConfig.enabledMaps)
        if (id == mapId) return true;
    return false;
}

// Parse a comma-separated ID list from a config string ("0, 1,530" → {0,1,530}).
static std::vector<uint32> ParseIdList(std::string csv)
{
    csv.erase(std::remove_if(csv.begin(), csv.end(),
        [](unsigned char c) { return std::isspace(c); }), csv.end());

    std::vector<uint32> ids;
    for (std::string_view token : Acore::Tokenize(csv, ',', false))
        if (Optional<uint32> id = Acore::StringTo<uint32>(token))
            ids.push_back(*id);
    return ids;
}

static bool IsFarEnoughFromExistingHotspots(uint32 mapId, float x, float y)
{
    float minDist = sHotspotsConfig.minDistance;
    if (minDist <= 0.0f)
        return true;

    float minDistSq = minDist * minDist;
    for (Hotspot const& h : sHotspotMgr->GetGrid().GetAll())
    {
        if (h.mapId != mapId)
            continue;

        float dx = h.x - x;
        float dy = h.y - y;
        if ((dx * dx + dy * dy) < minDistSq)
            return false;
    }

    return true;
}

static uint32 GetPrimaryHotspotAuraSpell()
{
    if (sHotspotsConfig.auraSpell)
        return sHotspotsConfig.auraSpell;

    return sHotspotsConfig.buffSpell;
}

static bool PlayerHasConfiguredHotspotAura(Player const* player, uint32 spellId)
{
    return player && spellId != 0 && player->HasAura(spellId);
}

static bool PlayerHasAnyHotspotAura(Player const* player)
{
    if (!player)
        return false;

    if (PlayerHasConfiguredHotspotAura(player, sHotspotsConfig.auraSpell))
        return true;

    return sHotspotsConfig.buffSpell != sHotspotsConfig.auraSpell &&
        PlayerHasConfiguredHotspotAura(player, sHotspotsConfig.buffSpell);
}

static bool EnsurePrimaryHotspotAura(Player* player)
{
    uint32 spellId = GetPrimaryHotspotAuraSpell();
    if (!player || spellId == 0 || player->HasAura(spellId))
        return false;

    player->CastSpell(player, spellId, true);
    return true;
}

static void RemoveSecondaryHotspotAuras(Player* player)
{
    if (!player)
        return;

    uint32 primarySpellId = GetPrimaryHotspotAuraSpell();

    if (sHotspotsConfig.auraSpell != 0 &&
        sHotspotsConfig.auraSpell != primarySpellId)
        player->RemoveAura(sHotspotsConfig.auraSpell);

    if (sHotspotsConfig.buffSpell != 0 &&
        sHotspotsConfig.buffSpell != primarySpellId)
        player->RemoveAura(sHotspotsConfig.buffSpell);
}

HotspotMgr* HotspotMgr::instance()
{
    static HotspotMgr instance;
    return &instance;
}

HotspotMgr::HotspotMgr() : _nextHotspotId(1) {}
HotspotMgr::~HotspotMgr() {}

void HotspotMgr::LoadConfig()
{
    sHotspotsConfig.enabled = sConfigMgr->GetOption<bool>("Hotspots.Enable", true);
    sHotspotsConfig.duration = sConfigMgr->GetOption<uint32>("Hotspots.Duration", 60);
    sHotspotsConfig.experienceBonus = sConfigMgr->GetOption<uint32>("Hotspots.ExperienceBonus", 100);
    sHotspotsConfig.radius = sConfigMgr->GetOption<float>("Hotspots.Radius", 150.0f);
    sHotspotsConfig.minDistance = sConfigMgr->GetOption<float>("Hotspots.MinDistance", sHotspotsConfig.radius * 2.0f);
    sHotspotsConfig.maxActive = sConfigMgr->GetOption<uint32>("Hotspots.MaxActive", 5);
    sHotspotsConfig.minActive = sConfigMgr->GetOption<uint32>("Hotspots.MinActive", 1);
    sHotspotsConfig.maxPerZone = sConfigMgr->GetOption<uint32>("Hotspots.MaxPerZone", 2);
    sHotspotsConfig.respawnDelay = sConfigMgr->GetOption<uint32>("Hotspots.RespawnDelay", 30);
    sHotspotsConfig.initialPopulateCount = sConfigMgr->GetOption<uint32>("Hotspots.InitialPopulateCount", 0);
    sHotspotsConfig.auraSpell = sConfigMgr->GetOption<uint32>("Hotspots.AuraSpell", 800001);
    sHotspotsConfig.buffSpell = sConfigMgr->GetOption<uint32>("Hotspots.BuffSpell", 800001);
    sHotspotsConfig.minimapIcon = sConfigMgr->GetOption<uint32>("Hotspots.MinimapIcon", 1);
    sHotspotsConfig.announceRadius = sConfigMgr->GetOption<float>("Hotspots.AnnounceRadius", 500.0f);
    sHotspotsConfig.includeTextureInAddon = sConfigMgr->GetOption<bool>("Hotspots.IncludeTextureInAddon", false);
    sHotspotsConfig.buffTexture = sConfigMgr->GetOption<std::string>("Hotspots.BuffTexture", "");
    sHotspotsConfig.announceSpawn = sConfigMgr->GetOption<bool>("Hotspots.AnnounceSpawn", true);
    sHotspotsConfig.announceExpire = sConfigMgr->GetOption<bool>("Hotspots.AnnounceExpire", true);
    sHotspotsConfig.spawnVisualMarker = sConfigMgr->GetOption<bool>("Hotspots.SpawnVisualMarker", true);
    sHotspotsConfig.markerGameObjectEntry = sConfigMgr->GetOption<uint32>("Hotspots.MarkerGameObjectEntry", 179976);
    sHotspotsConfig.sendAddonPackets = sConfigMgr->GetOption<bool>("Hotspots.SendAddonPackets", false);
    sHotspotsConfig.gmBypassLimit = sConfigMgr->GetOption<bool>("Hotspots.GMBypassLimit", true);
    sHotspotsConfig.allowWorldwideSpawn = sConfigMgr->GetOption<bool>("Hotspots.AllowWorldwideSpawn", true);

    // Objectives support
    sHotspotsConfig.objectivesEnabled = sConfigMgr->GetOption<bool>("Hotspots.Objectives.Enable", true);
    sHotspotsConfig.objectiveKillGoal = sConfigMgr->GetOption<uint32>("Hotspots.Objectives.KillGoal", 50);
    sHotspotsConfig.objectiveSurviveMinutes = sConfigMgr->GetOption<uint32>("Hotspots.Objectives.SurviveMinutes", 5);
    sHotspotsConfig.showObjectivesProgress = sConfigMgr->GetOption<bool>("Hotspots.Objectives.ShowProgress", true);

    // Comma-separated ID lists (ConfigMgr has no vector support). EnabledMaps
    // limits where hotspots may appear; EnabledZones (optional) narrows that
    // further, e.g. to the leveling path. Zone IDs are globally unique across
    // maps, so a flat zone list is sufficient (no per-map list needed).
    sHotspotsConfig.enabledMaps = ParseIdList(
        sConfigMgr->GetOption<std::string>("Hotspots.EnabledMaps", "0,1,530,571,37"));
    if (sHotspotsConfig.enabledMaps.empty())
        sHotspotsConfig.enabledMaps = { 0, 1, 530, 571, 37 };

    sHotspotsConfig.enabledZones = ParseIdList(
        sConfigMgr->GetOption<std::string>("Hotspots.EnabledZones", ""));
    sHotspotsConfig.excludedZones = ParseIdList(
        sConfigMgr->GetOption<std::string>("Hotspots.ExcludedZones", ""));
    sHotspotsConfig.enabledZonesPerMap.clear();

    // Harmless no-op before DBC stores load (first OnAfterConfigLoad during
    // boot); rebuilt with real data from OnStartup and on config reload.
    BuildZoneSampleBoxes();
}

void HotspotMgr::LoadFromDB()
{
    // Implementation: Load existing hotspots from DB, add to _grid
    QueryResult result = WorldDatabase.Query("SELECT id, map_id, zone_id, x, y, z, spawn_time, expire_time, gameobject_guid FROM dc_hotspots_active");
    if (!result) return;

    time_t now = GameTime::GetGameTime().count();
    uint32 loaded = 0;
    do
    {
        Field* fields = result->Fetch();
        Hotspot h;
        h.id = fields[0].Get<uint32>();
        h.mapId = fields[1].Get<uint32>();
        h.zoneId = fields[2].Get<uint32>();
        h.x = fields[3].Get<float>();
        h.y = fields[4].Get<float>();
        h.z = fields[5].Get<float>();
        h.spawnTime = static_cast<time_t>(fields[6].Get<uint64>());
        h.expireTime = static_cast<time_t>(fields[7].Get<uint64>());
        // Marker GOs are created dynamically and do not survive a restart;
        // clear the stale guid so SpawnPendingMarkers recreates the marker
        // once a player loads the area.
        h.gameObjectGuid = ObjectGuid::Empty;

        if (h.expireTime > now)
        {
            _grid.Add(h);
            if (h.id >= _nextHotspotId) _nextHotspotId = h.id + 1;
            loaded++;
        }
        else
        {
            // Clean up expired DB entry immediately
            DeleteHotspotFromDB(h.id);
        }

    } while (result->NextRow());

    LOG_INFO("server.loading", "Hotspots: Loaded {} active hotspots from database.", loaded);
}

void HotspotMgr::SaveHotspotToDB(Hotspot const& h)
{
    WorldDatabase.Execute("INSERT INTO dc_hotspots_active (id, map_id, zone_id, x, y, z, spawn_time, expire_time, gameobject_guid) VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {})",
        h.id, h.mapId, h.zoneId, h.x, h.y, h.z, static_cast<uint64>(h.spawnTime), static_cast<uint64>(h.expireTime), h.gameObjectGuid.GetRawValue());
}

void HotspotMgr::DeleteHotspotFromDB(uint32 id)
{
    WorldDatabase.Execute("DELETE FROM dc_hotspots_active WHERE id = {}", id);
}

// Spawn-time eligibility helpers (dynamic; depend on currently-active hotspots)
static bool IsZoneAtCapacity(uint32 zoneId)
{
    if (sHotspotsConfig.maxPerZone == 0)
        return false;

    return sHotspotMgr->GetZoneHotspotCount(zoneId) >= sHotspotsConfig.maxPerZone;
}

static bool IsCityLikeArea(uint32 areaId)
{
    if (!areaId)
        return false;

    AreaTableEntry const* area = sAreaTableStore.LookupEntry(areaId);
    if (!area)
        return false;

    auto isCityFlags = [](uint32 flags)
    {
        return (flags & (AREA_FLAG_CAPITAL | AREA_FLAG_CITY | AREA_FLAG_SLAVE_CAPITAL | AREA_FLAG_SLAVE_CAPITAL2 | AREA_FLAG_TOWN)) != 0;
    };

    if (isCityFlags(area->flags))
        return true;

    if (area->zone != 0)
        if (AreaTableEntry const* parentZone = sAreaTableStore.LookupEntry(area->zone))
            return isCityFlags(parentZone->flags);

    return false;
}

// Recover a zone's world-space bounding box by probing Zone2MapCoordinates
// with the client-space corners (0,0) and (100,100). If the zone has no
// WorldMapArea entry the inputs come back unchanged, which we detect.
static bool TryGetZoneWorldBox(uint32 zoneId, float& minX, float& maxX, float& minY, float& maxY)
{
    float ax = 0.0f, ay = 0.0f;
    float bx = 100.0f, by = 100.0f;
    Zone2MapCoordinates(ax, ay, zoneId);
    Zone2MapCoordinates(bx, by, zoneId);

    // Unchanged inputs = no WorldMapArea entry (a real 100x100yd zone box at
    // the exact map origin does not exist).
    if (ax == 0.0f && ay == 0.0f && bx == 100.0f && by == 100.0f)
        return false;

    minX = std::min(ax, bx);
    maxX = std::max(ax, bx);
    minY = std::min(ay, by);
    maxY = std::max(ay, by);

    // Reject degenerate boxes.
    return (maxX - minX) > 1.0f && (maxY - minY) > 1.0f;
}

// Fallback boxes for zones the server's WorldMapArea.dbc may not cover
// (values from Custom/CSV DBC/WorldMapArea.csv; columns after the name are
// y1,y2,x1,x2 with x = world X — convention verified against the live areas'
// game_tele and playercreateinfo coordinates). Only consulted when
// TryGetZoneWorldBox fails for the zone.
struct CustomZoneBox
{
    uint32 zoneId;
    float minX, maxX, minY, maxY;
};
static constexpr CustomZoneBox CUSTOM_ZONE_BOXES[] =
{
    { 268,  -1116.0f,  1756.0f,  -1884.0f,  2427.0f   }, // Azshara Crater (map 37)
    { 5006,  5334.3f,  6932.32f,  2.91f,    2132.02f  }, // Isles of Giants (map 1405)
    { 6000,  2066.67f, 4333.33f, -5166.67f, -1766.67f }, // Stratholme Valley (map 850)
    { 6100,  4479.17f, 6145.83f, -4025.0f,  -1525.0f  }, // Hyjal Frontier (map 1410)
};

void HotspotMgr::BuildZoneSampleBoxes()
{
    _zoneSampleBoxes.clear();

    // Surface config mistakes once DBC stores are loaded (GetBaseMapSafe
    // silently skips these at runtime, which would otherwise look like
    // hotspots randomly never spawning on a map).
    if (sMapStore.GetNumRows() > 0)
    {
        for (uint32 mapId : sHotspotsConfig.enabledMaps)
        {
            MapEntry const* entry = sMapStore.LookupEntry(mapId);
            if (!entry)
                LOG_WARN("scripts.dc", "Hotspots: enabled map {} does not exist in Map.dbc - it will be skipped.", mapId);
            else if (entry->Instanceable())
                LOG_WARN("scripts.dc", "Hotspots: enabled map {} is instanceable - it will be skipped.", mapId);
        }
    }

    for (uint32 i = 0; i < sAreaTableStore.GetNumRows(); ++i)
    {
        AreaTableEntry const* area = sAreaTableStore.LookupEntry(i);
        if (!area || area->zone != 0) // only top-level zones
            continue;

        if (!IsMapEnabled(area->mapid))
            continue;

        if (!IsZoneAllowed(area->mapid, area->ID) || IsCityLikeArea(area->ID))
            continue;

        HotspotZoneSampleBox box;
        box.zoneId = area->ID;
        box.mapId = area->mapid;

        if (TryGetZoneWorldBox(area->ID, box.minX, box.maxX, box.minY, box.maxY))
        {
            _zoneSampleBoxes.push_back(box);
            continue;
        }

        for (CustomZoneBox const& custom : CUSTOM_ZONE_BOXES)
        {
            if (custom.zoneId != area->ID)
                continue;
            box.minX = custom.minX;
            box.maxX = custom.maxX;
            box.minY = custom.minY;
            box.maxY = custom.maxY;
            _zoneSampleBoxes.push_back(box);
        }
        // Zones with no known bounds stay reachable via the periodic map-wide
        // probes in RefillSpawnPool.
    }

    LOG_INFO("server.loading", "Hotspots: prepared {} zone sampling box(es) for spawn discovery.",
        _zoneSampleBoxes.size());
}

// Static terrain/zone eligibility for a candidate position. Excludes the
// dynamic checks (zone capacity, distance-to-existing) on purpose: those depend
// on currently-active hotspots and are applied at spawn time in PickSpawnPoint,
// so the result here is stable and safe to cache in the spawn pool.
static bool EvaluateCandidateTerrain(Map* map, uint32 mapId, float cx, float cy,
    uint32& outZoneId, float& outZ)
{
    if (!MapMgr::IsValidMapCoord(mapId, cx, cy))
        return false;

    float gz = map->GetHeight(cx, cy, MAX_HEIGHT);
    if (!std::isfinite(gz) || gz <= MIN_HEIGHT)
        return false;

    if (!MapMgr::IsValidMapCoord(mapId, cx, cy, gz))
        return false;

    uint32 zoneId = map->GetZoneId(PHASEMASK_NORMAL, cx, cy, gz);
    if (!zoneId)
        return false;

    if (!IsZoneAllowed(mapId, zoneId) || !sHotspotMgr->CanSpawnInZone(zoneId))
        return false;

    uint32 areaId = map->GetAreaId(PHASEMASK_NORMAL, cx, cy, gz);
    if (IsCityLikeArea(areaId))
        return false;

    constexpr float collisionHeight = 2.0f;
    if (map->IsInWater(PHASEMASK_NORMAL, cx, cy, gz, collisionHeight))
        return false;

    float waterLevel = map->GetWaterLevel(cx, cy);
    if (std::isfinite(waterLevel) && waterLevel > gz - 1.0f)
        return false;

    outZoneId = zoneId;
    outZ = gz;
    return true;
}

void HotspotMgr::LoadSpawnPointsFromDB()
{
    _spawnPool.clear();

    QueryResult result = WorldDatabase.Query(
        "SELECT id, map_id, zone_id, x, y, z FROM dc_hotspot_spawn_points WHERE enabled = 1");
    if (!result)
    {
        LOG_INFO("server.loading", "Hotspots: No cached spawn points; will discover lazily.");
        return;
    }

    do
    {
        Field* fields = result->Fetch();
        HotspotSpawnPoint p;
        p.dbId   = fields[0].Get<uint32>();
        p.mapId  = fields[1].Get<uint32>();
        p.zoneId = fields[2].Get<uint32>();
        p.x      = fields[3].Get<float>();
        p.y      = fields[4].Get<float>();
        p.z      = fields[5].Get<float>();
        _spawnPool.push_back(p);
    } while (result->NextRow());

    LOG_INFO("server.loading", "Hotspots: Loaded {} cached spawn point(s).", _spawnPool.size());
}

void HotspotMgr::SaveSpawnPointToDB(HotspotSpawnPoint const& p)
{
    WorldDatabase.Execute(
        "INSERT INTO dc_hotspot_spawn_points (map_id, zone_id, x, y, z, enabled) VALUES ({}, {}, {}, {}, {}, 1)",
        p.mapId, p.zoneId, p.x, p.y, p.z);
}

void HotspotMgr::RefillSpawnPool()
{
    // Target variety so spawns rarely repeat the same spot.
    constexpr size_t POOL_TARGET = 100;
    if (_spawnPool.size() >= POOL_TARGET)
        return;

    if (sHotspotsConfig.enabledMaps.empty())
        return;

    // Bound disk I/O: every cold (unloaded) grid we probe pulls .map/.vmtile/
    // .mmtile off disk (~several ms each). Cap cold-grid loads per call so a
    // single world tick never stalls (2 loads stays under the 25ms profiler
    // threshold); probes into already-loaded grids are cheap and not budgeted.
    // The pool fills over many ticks and persists.
    constexpr uint32 COLD_GRID_BUDGET = 2;
    constexpr uint32 MAX_PROBES = 150;     // total random samples per call
    constexpr size_t MAX_NEW_POINTS = 5;   // stop early once this many are added
    constexpr float MIN_POINT_SPACING_SQ = 100.0f * 100.0f;

    std::vector<uint32> const& maps = sHotspotsConfig.enabledMaps;
    uint32 coldBudget = COLD_GRID_BUDGET;
    size_t added = 0;

    for (uint32 probe = 0; probe < MAX_PROBES; ++probe)
    {
        if (added >= MAX_NEW_POINTS)
            break;

        // Sample inside a known zone bounding box when available: far higher
        // hit rate than map-wide random points, and it concentrates the pool
        // in the configured (leveling) zones. Every 4th probe still samples
        // map-wide so zones without known bounds remain discoverable.
        uint32 mapId;
        float cx, cy;
        if (!_zoneSampleBoxes.empty() && (probe % 4) != 0)
        {
            HotspotZoneSampleBox const& box =
                _zoneSampleBoxes[urand(0, static_cast<uint32>(_zoneSampleBoxes.size()) - 1)];
            mapId = box.mapId;
            cx = frand(box.minX, box.maxX);
            cy = frand(box.minY, box.maxY);
        }
        else
        {
            mapId = maps[urand(0, static_cast<uint32>(maps.size()) - 1)];
            cx = frand(-MAP_HALFSIZE + 1.0f, MAP_HALFSIZE - 1.0f);
            cy = frand(-MAP_HALFSIZE + 1.0f, MAP_HALFSIZE - 1.0f);
        }

        if (!IsMapEnabled(mapId))
            continue;

        Map* map = GetBaseMapSafe(mapId);
        if (!map)
            continue;

        if (!MapMgr::IsValidMapCoord(mapId, cx, cy))
            continue;

        // Gate cold terrain: once the budget is spent, only probe grids that
        // are already resident (free), otherwise skip to the next sample.
        if (!map->IsGridLoaded(cx, cy))
        {
            if (coldBudget == 0)
                continue;
            --coldBudget; // this probe will trigger a disk load
        }

        uint32 zoneId;
        float gz;
        if (!EvaluateCandidateTerrain(map, mapId, cx, cy, zoneId, gz))
            continue;

        // Avoid clustering near an existing pool entry.
        bool tooClose = false;
        for (HotspotSpawnPoint const& existing : _spawnPool)
        {
            if (existing.mapId != mapId)
                continue;
            float dx = existing.x - cx;
            float dy = existing.y - cy;
            if ((dx * dx + dy * dy) < MIN_POINT_SPACING_SQ)
            {
                tooClose = true;
                break;
            }
        }
        if (tooClose)
            continue;

        HotspotSpawnPoint point;
        point.mapId = mapId;
        point.zoneId = zoneId;
        point.x = cx;
        point.y = cy;
        point.z = gz;
        _spawnPool.push_back(point);
        SaveSpawnPointToDB(point);
        ++added;
    }

    if (added)
        LOG_DEBUG("scripts.dc", "Hotspots: discovered {} new spawn point(s); pool size {}.",
            added, _spawnPool.size());
}

bool HotspotMgr::PickSpawnPoint(HotspotSpawnPoint& out)
{
    if (_spawnPool.empty())
        return false;

    // Collect points eligible right now (dynamic capacity + spacing checks).
    std::vector<HotspotSpawnPoint const*> eligible;
    eligible.reserve(_spawnPool.size());
    for (HotspotSpawnPoint const& p : _spawnPool)
    {
        if (!IsMapEnabled(p.mapId))
            continue;
        if (!IsZoneAllowed(p.mapId, p.zoneId) || !CanSpawnInZone(p.zoneId))
            continue;
        if (IsZoneAtCapacity(p.zoneId))
            continue;
        if (!IsFarEnoughFromExistingHotspots(p.mapId, p.x, p.y))
            continue;
        eligible.push_back(&p);
    }

    if (eligible.empty())
        return false;

    out = *eligible[urand(0, static_cast<uint32>(eligible.size()) - 1)];
    return true;
}

// Create the visual marker GameObject for a hotspot. Caller must ensure the
// grid at (x,y) is already loaded so this never triggers terrain disk I/O.
static ObjectGuid CreateHotspotMarker(Map* map, Hotspot const& h)
{
    if (!sObjectMgr->GetGameObjectTemplate(sHotspotsConfig.markerGameObjectEntry))
        return ObjectGuid::Empty;

    time_t now = GameTime::GetGameTime().count();
    if (h.expireTime <= now)
        return ObjectGuid::Empty;

    GameObject* go = new GameObject();
    if (!go->Create(map->GenerateLowGuid<HighGuid::GameObject>(),
        sHotspotsConfig.markerGameObjectEntry, map, 0,
        h.x, h.y, h.z + 0.5f, 0.0f, G3D::Quat(), 255, GO_STATE_READY))
    {
        delete go;
        return ObjectGuid::Empty;
    }

    go->SetRespawnTime(static_cast<int32>(h.expireTime - now));
    if (!map->AddToMap(go))
    {
        delete go;
        return ObjectGuid::Empty;
    }

    return go->GetGUID();
}

void HotspotMgr::SpawnPendingMarkers()
{
    if (!sHotspotsConfig.spawnVisualMarker)
        return;

    for (Hotspot const& h : _grid.GetAll())
    {
        if (!h.gameObjectGuid.IsEmpty())
            continue;

        Map* map = GetBaseMapSafe(h.mapId);
        if (!map || !map->IsGridLoaded(h.x, h.y))
            continue; // defer until a player loads the area

        ObjectGuid guid = CreateHotspotMarker(map, h);
        if (!guid.IsEmpty())
            _grid.UpdateGameObjectGuid(h.id, guid);
    }
}

bool HotspotMgr::SpawnHotspot()
{
    if (!sHotspotsConfig.enabled) return false;
    if (_grid.Count() >= sHotspotsConfig.maxActive) return false;

    HotspotSpawnPoint point;
    if (!PickSpawnPoint(point))
    {
        // Pool empty or nothing eligible right now; RefillSpawnPool (throttled
        // from OnUpdate) seeds/replenishes it without blocking the tick.
        return false;
    }

    uint32 mapId = point.mapId;
    uint32 zoneId = point.zoneId;
    float x = point.x;
    float y = point.y;
    float z = point.z;

    Hotspot h;
    h.id = _nextHotspotId++;
    h.mapId = mapId; h.zoneId = zoneId; h.x = x; h.y = y; h.z = z;
    h.spawnTime = GameTime::GetGameTime().count();
    h.expireTime = h.spawnTime + (sHotspotsConfig.duration * MINUTE);

    // Visual marker: created immediately only if the target grid is already
    // resident, so spawning never pulls terrain off disk. Otherwise
    // SpawnPendingMarkers (10s cleanup cadence) creates it once a player
    // loads the area — until then nobody is there to see it anyway.
    if (sHotspotsConfig.spawnVisualMarker)
        if (Map* m = GetBaseMapSafe(mapId))
            if (m->IsGridLoaded(x, y))
                h.gameObjectGuid = CreateHotspotMarker(m, h);

    _grid.Add(h);
    SaveHotspotToDB(h);

    LOG_INFO("scripts.dc", "Spawned Hotspot #{} on map {} zone {}", h.id, h.mapId, h.zoneId);

    if (sHotspotsConfig.announceSpawn)
    {
        std::string zoneName = GetSafeZoneName(h.zoneId);
        std::string mapName = "Unknown Map";
        if (const MapEntry* me = sMapStore.LookupEntry(h.mapId)) mapName = me->name[0];

        std::ostringstream ss;
        ss << "|cFFFFD700[Hotspot]|r A new XP Hotspot in " << mapName << " (" << zoneName << ")! +" << sHotspotsConfig.experienceBonus << "% XP";

        // One global announce; players on the map previously got it twice
        // (broadcast + per-map loop).
        sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, ss.str().c_str(), nullptr);

        // Send WRLD packet
        DCAddon::JsonValue hotspotsArr; hotspotsArr.SetArray();
        DCAddon::JsonValue j; j.SetObject();
        j.Set("id", DCAddon::JsonValue((int)h.id));
        j.Set("mapId", DCAddon::JsonValue((int)h.mapId));
        j.Set("zoneId", DCAddon::JsonValue((int)h.zoneId));
        j.Set("x", DCAddon::JsonValue(h.x));
        j.Set("y", DCAddon::JsonValue(h.y));
        j.Set("z", DCAddon::JsonValue(h.z));
        j.Set("action", DCAddon::JsonValue("spawn"));
        hotspotsArr.Push(j);

        DCAddon::JsonMessage wmsg(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
        wmsg.Set("hotspots", hotspotsArr);

        for (auto const& sess : sWorldSessionMgr->GetAllSessions())
            if (Player* p = sess.second->GetPlayer())
                wmsg.Send(p);
    }
    return true;
}

void HotspotMgr::CleanupExpiredHotspots()
{
    std::vector<Hotspot> all = _grid.GetAll();
    time_t now = GameTime::GetGameTime().count();

    // Create deferred visual markers for areas players have since loaded.
    SpawnPendingMarkers();

    for (const Hotspot& h : all)
    {
        if (h.expireTime <= now)
        {
            // Remove Visual
            if (!h.gameObjectGuid.IsEmpty())
            {
                if (Map* m = GetBaseMapSafe(h.mapId))
                    if (GameObject* go = m->GetGameObject(h.gameObjectGuid))
                    {
                        go->SetRespawnTime(0);
                        go->Delete();
                    }
            }

            DeleteHotspotFromDB(h.id);
            _grid.Remove(h.id);

            // Announce expire
            if (sHotspotsConfig.announceExpire)
            {
                // Send WRLD packet expire
                DCAddon::JsonValue hotspotsArr; hotspotsArr.SetArray();
                DCAddon::JsonValue j; j.SetObject();
                j.Set("id", DCAddon::JsonValue((int)h.id));
                j.Set("action", DCAddon::JsonValue("expire"));
                hotspotsArr.Push(j);
                DCAddon::JsonMessage wmsg(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
                wmsg.Set("hotspots", hotspotsArr);

                // Notify players
                for (auto const& sess : sWorldSessionMgr->GetAllSessions())
                {
                    if (Player* p = sess.second->GetPlayer())
                    {
                        wmsg.Send(p);
                        if (p->GetZoneId() == h.zoneId)
                           ChatHandler(p->GetSession()).PSendSysMessage("|cFFFFD700[Hotspot]|r A Hotspot has expired.");
                    }
                }
            }
        }
    }

    std::unordered_set<uint32> activeHotspotIds;
    for (Hotspot const& activeHotspot : _grid.GetAll())
        activeHotspotIds.insert(activeHotspot.id);

    // Clean player expiry and stale one-time grant entries.
    {
        std::lock_guard<std::mutex> lock(_playerDataLock);
        for (auto it = _playerExpiry.begin(); it != _playerExpiry.end(); )
        {
            if (it->second <= now) it = _playerExpiry.erase(it);
            else ++it;
        }

        for (auto playerIt = _playerGrantedHotspots.begin(); playerIt != _playerGrantedHotspots.end(); )
        {
            auto& granted = playerIt->second;
            for (auto grantIt = granted.begin(); grantIt != granted.end(); )
            {
                if (activeHotspotIds.find(*grantIt) != activeHotspotIds.end())
                    ++grantIt;
                else
                    grantIt = granted.erase(grantIt);
            }

            if (granted.empty())
                playerIt = _playerGrantedHotspots.erase(playerIt);
            else
                ++playerIt;
        }
    }

    // Respawn toward minActive, but only one per cleanup cycle: each spawn
    // places a GameObject marker (one grid load), so refilling N at once would
    // stack N disk loads into a single world tick. Cleanup runs every ~10s, so
    // the population recovers steadily without a spike.
    if (sHotspotsConfig.minActive > 0 && _grid.Count() < sHotspotsConfig.minActive)
        SpawnHotspot();
}

void HotspotMgr::CheckPlayerHotspotStatus(Player* player)
{
    if (!player) return;

    ObjectGuid const playerGuid = player->GetGUID();
    Hotspot const* hotspot = GetPlayerHotspot(player);
    bool isInHotspotContext = (hotspot != nullptr);
    bool hasHotspotAura = PlayerHasAnyHotspotAura(player);

    if (!hasHotspotAura)
    {
        uint32 kills = 0;
        uint32 mins = 0;
        bool hasResults = false;
        {
            std::lock_guard<std::mutex> lock(_playerDataLock);
            _playerExpiry.erase(playerGuid);

            // End objective session once the aura is gone and player is outside hotspot context.
            if (!isInHotspotContext && sHotspotsConfig.objectivesEnabled)
            {
                auto it = _playerObjectives.find(playerGuid);
                if (it != _playerObjectives.end())
                {
                    kills = it->second.killCount;
                    mins = it->second.GetSurvivalSeconds() / 60;
                    _playerObjectives.erase(it);
                    hasResults = true;
                }
            }
        }

        if (hasResults && player->GetSession())
            ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF6347[Hotspot Results]|r Session ended. Kills: {} | Survival: {} min", kills, mins);
    }

    if (!isInHotspotContext)
        return;

    if (!hotspot)
        return;

    RemoveSecondaryHotspotAuras(player);

    if (hasHotspotAura)
        return;

    uint32 targetId = hotspot->id;

    bool alreadyGranted = false;
    {
        std::lock_guard<std::mutex> lock(_playerDataLock);
        auto grantedIt = _playerGrantedHotspots.find(playerGuid);
        if (grantedIt != _playerGrantedHotspots.end())
            alreadyGranted = grantedIt->second.find(targetId) != grantedIt->second.end();
    }

    // One-time grant per hotspot: re-entering the same hotspot should never re-buff.
    if (alreadyGranted)
        return;

    if (!EnsurePrimaryHotspotAura(player))
        return;

    uint32 bonus = sHotspotsConfig.experienceBonus;

    if (player->GetSession())
        ChatHandler(player->GetSession()).SendNotification("Hotspot joined: +{}% experience", bonus);

    time_t expiryTime = hotspot->expireTime;
    {
        std::lock_guard<std::mutex> lock(_playerDataLock);
        _playerExpiry[playerGuid] = expiryTime;
        _playerGrantedHotspots[playerGuid].insert(targetId);

        if (sHotspotsConfig.objectivesEnabled)
        {
            auto& obj = _playerObjectives[playerGuid];
            if (obj.hotspotId != targetId)
            {
                obj = HotspotObjectives();
                obj.hotspotId = targetId;
                obj.entryTime = GameTime::GetGameTime().count();
            }
        }
    }
}

void HotspotMgr::OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim)
{
    if (!sHotspotsConfig.enabled || !player) return;

    bool isBuffed = PlayerHasAnyHotspotAura(player);

    if (!isBuffed)
        return;

    uint32 bonusPct = sHotspotsConfig.experienceBonus;

    uint32 bonus = (amount * bonusPct) / 100;
    amount += bonus;

    ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700[Hotspot XP]|r +{} XP ({}% bonus)", bonus, bonusPct);

    // Track objectives
    if (sHotspotsConfig.objectivesEnabled && victim) // victim might be null in some calls?
    {
         // Check valid context: Grid Hotspot
         Hotspot const* cur = GetPlayerHotspot(player);

         if (cur)
         {
             uint32 targetId = cur->id;

             uint32 killCount = 0;
             bool reportProgress = false;
             {
                 std::lock_guard<std::mutex> lock(_playerDataLock);
                 auto& obj = _playerObjectives[player->GetGUID()];
                 if (obj.hotspotId == targetId)
                 {
                     obj.killCount++;
                     killCount = obj.killCount;
                     reportProgress = sHotspotsConfig.showObjectivesProgress;
                 }
             }

             if (reportProgress)
             {
                 if (killCount == sHotspotsConfig.objectiveKillGoal)
                     ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[Objective] Killed {}/{} creatures!|r", killCount, sHotspotsConfig.objectiveKillGoal);
                 else if (killCount < sHotspotsConfig.objectiveKillGoal && (killCount % 10 == 0 || killCount == 1))
                     ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFFF00[Objective] Hotspot Kills: {}/{}|r", killCount, sHotspotsConfig.objectiveKillGoal);
             }
         }
    }
}

void HotspotMgr::ClearAll()
{
    std::vector<Hotspot> all = _grid.GetAll();
    for (const Hotspot& h : all)
    {
        // Remove Visual
        if (!h.gameObjectGuid.IsEmpty())
        {
            if (Map* m = GetBaseMapSafe(h.mapId))
                if (GameObject* go = m->GetGameObject(h.gameObjectGuid))
                {
                    go->SetRespawnTime(0);
                    go->Delete();
                }
        }

        DeleteHotspotFromDB(h.id);
        _grid.Remove(h.id);
    }

    // Reset ID if desired? No, keep incrementing safer.
}

void HotspotMgr::RecreateHotspotVisualMarkers()
{
    // Markers for grids that are not yet resident are created lazily by the
    // SpawnPendingMarkers pass in CleanupExpiredHotspots.
    SpawnPendingMarkers();
}

std::string HotspotMgr::GetZoneName(uint32 zoneId)
{
    return GetSafeZoneName(zoneId);
}

// ============================================================================
// Missing Function Implementations
// ============================================================================

uint32 GetHotspotXPBonusPercentage()
{
    return sHotspotsConfig.experienceBonus;
}

Hotspot* GetPlayerHotspot(Player* player)
{
    if (!player) return nullptr;
    return const_cast<Hotspot*>(sHotspotMgr->GetPlayerHotspot(player));
}

Hotspot const* HotspotMgr::GetPlayerHotspot(Player* player)
{
    if (!player) return nullptr;
    return _grid.GetForPlayer(player);
}

bool CanSpawnInZone(uint32 zoneId)
{
    return sHotspotMgr->CanSpawnInZone(zoneId);
}

uint32 HotspotMgr::GetZoneHotspotCount(uint32 zoneId)
{
    if (!zoneId)
        return 0;

    uint32 count = 0;
    for (Hotspot const& hotspot : _grid.GetAll())
        if (hotspot.zoneId == zoneId)
            ++count;

    return count;
}

bool HotspotMgr::IsZoneHotspotActive(uint32 zoneId)
{
    return GetZoneHotspotCount(zoneId) > 0;
}

bool HotspotMgr::CanSpawnInZone(uint32 zoneId)
{
    // Check if zone is in excluded list
    for (uint32 ex : sHotspotsConfig.excludedZones)
    {
        if (ex == zoneId)
            return false;
    }

    // If enabledZones is specified and not empty, zone must be in it
    if (!sHotspotsConfig.enabledZones.empty())
    {
        return std::find(sHotspotsConfig.enabledZones.begin(),
                        sHotspotsConfig.enabledZones.end(),
                        zoneId) != sHotspotsConfig.enabledZones.end();
    }

    return true;
}
