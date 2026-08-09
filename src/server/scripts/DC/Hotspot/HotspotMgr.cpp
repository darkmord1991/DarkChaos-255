#include "HotspotMgr.h"
#include "HotspotDefines.h"
#include "HotspotJson.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "SpellAuras.h"
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
#include "../AddonExtension/dc_addon_namespace.h"
#include "DBCStore.h"
#include "DatabaseEnv.h"
#include "DBCEnums.h"
#include "Random.h"
#include "Tokenize.h"
#include <cctype>
#include <sstream>
#include <cmath>
#include <algorithm>
#include <limits>
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

// Zone ids are globally unique across maps, so the allow/deny lists are flat.
static bool IsZoneAllowed(uint32 zoneId)
{
    if (!zoneId)
        return false;

    for (uint32 ex : sHotspotsConfig.excludedZones)
        if (ex == zoneId)
            return false;

    if (sHotspotsConfig.enabledZones.empty())
        return true;

    return std::find(sHotspotsConfig.enabledZones.begin(),
        sHotspotsConfig.enabledZones.end(), zoneId) != sHotspotsConfig.enabledZones.end();
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
    for (auto const& [id, h] : sHotspotMgr->GetGrid().View())
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
    sHotspotsConfig.auraSpell = sConfigMgr->GetOption<uint32>("Hotspots.AuraSpell", 800001);
    sHotspotsConfig.buffSpell = sConfigMgr->GetOption<uint32>("Hotspots.BuffSpell", 800001);
    sHotspotsConfig.announceRadius = sConfigMgr->GetOption<float>("Hotspots.AnnounceRadius", 500.0f);
    sHotspotsConfig.announceSpawn = sConfigMgr->GetOption<bool>("Hotspots.AnnounceSpawn", true);
    sHotspotsConfig.announceExpire = sConfigMgr->GetOption<bool>("Hotspots.AnnounceExpire", true);
    sHotspotsConfig.spawnVisualMarker = sConfigMgr->GetOption<bool>("Hotspots.SpawnVisualMarker", false);
    sHotspotsConfig.markerGameObjectEntry = sConfigMgr->GetOption<uint32>("Hotspots.MarkerGameObjectEntry", 179976);

    // Objectives support
    sHotspotsConfig.objectivesEnabled = sConfigMgr->GetOption<bool>("Hotspots.Objectives.Enable", true);
    sHotspotsConfig.objectiveKillGoal = sConfigMgr->GetOption<uint32>("Hotspots.Objectives.KillGoal", 50);
    sHotspotsConfig.objectiveSurviveMinutes = sConfigMgr->GetOption<uint32>("Hotspots.Objectives.SurviveMinutes", 5);
    sHotspotsConfig.showObjectivesProgress = sConfigMgr->GetOption<bool>("Hotspots.Objectives.ShowProgress", true);

    // Comma-separated ID lists (ConfigMgr has no vector support). EnabledMaps
    // limits where hotspots may appear; EnabledZones (optional) narrows that
    // further, e.g. to the leveling path. Zone IDs are globally unique across
    // maps, so a flat zone list is sufficient (no per-map list needed).
    // Defaults mirror the shipped darkchaos-custom.conf.dist: the DC custom
    // leveling continents, not the stock ones.
    static char const* const DEFAULT_ENABLED_MAPS = "37,850,1410,750,751";
    sHotspotsConfig.enabledMaps = ParseIdList(
        sConfigMgr->GetOption<std::string>("Hotspots.EnabledMaps", DEFAULT_ENABLED_MAPS));
    if (sHotspotsConfig.enabledMaps.empty())
        sHotspotsConfig.enabledMaps = ParseIdList(DEFAULT_ENABLED_MAPS);

    sHotspotsConfig.enabledZones = ParseIdList(
        sConfigMgr->GetOption<std::string>("Hotspots.EnabledZones", ""));
    sHotspotsConfig.excludedZones = ParseIdList(
        sConfigMgr->GetOption<std::string>("Hotspots.ExcludedZones", ""));

    // Harmless no-op before DBC stores load (first OnAfterConfigLoad during
    // boot); rebuilt with real data from OnStartup and on config reload.
    BuildZoneSampleBoxes();
}

void HotspotMgr::LoadFromDB()
{
    // Runs even when the system is disabled: _nextHotspotId must clear any id
    // still present in the table, or enabling Hotspots via .hotspot reload
    // would start issuing ids that collide with live rows on INSERT.
    _loaded = true;

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_DC_HOTSPOTS_ACTIVE);
    PreparedQueryResult result = CharacterDatabase.Query(stmt);
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
    // REPLACE, not INSERT: a stale row left behind by an unclean shutdown would
    // otherwise fail the insert on the primary key and silently drop
    // persistence for that hotspot.
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_DC_HOTSPOT_ACTIVE);
    stmt->SetData(0, h.id);
    stmt->SetData(1, uint16(h.mapId));
    stmt->SetData(2, uint16(h.zoneId));
    stmt->SetData(3, h.x);
    stmt->SetData(4, h.y);
    stmt->SetData(5, h.z);
    stmt->SetData(6, uint64(h.spawnTime));
    stmt->SetData(7, uint64(h.expireTime));
    stmt->SetData(8, h.gameObjectGuid.GetRawValue());
    CharacterDatabase.Execute(stmt);
}

void HotspotMgr::DeleteHotspotFromDB(uint32 id)
{
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_DEL_DC_HOTSPOT_ACTIVE);
    stmt->SetData(0, id);
    CharacterDatabase.Execute(stmt);
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

// Authored world-space extents of the level bands hotspots may use.
//
// These are AUTHORITATIVE, not a hint: the DC terrain downport bakes a single
// area id into every ADT of a custom continent (map 750 -> 4923, map 751 ->
// 4924, map 861 -> 4925), so Map::GetZoneId() cannot distinguish the seven
// leveling bands that share map 750. Without this table every hotspot on 750
// reports zone 4923 "Hyjal Frontier (113-130)" - the announce text lies to
// level-80 players standing in the Darkshore band, and Hotspots.MaxPerZone
// caps the entire continent instead of each band.
//
// Consequences of a map appearing here at all:
//   * spawn discovery only samples inside these boxes on that map;
//   * a position outside every band on a banded map is rejected outright
//     (un-authored terrain), so Moonglade 4928 stays hotspot-free without
//     needing an exclude entry;
//   * the IsCityLikeArea guard is skipped. That guard exists to keep blind
//     map-wide discovery out of Stormwind; a hand-authored band is already an
//     explicit statement of intent. Isles of Giants 5006 carries the
//     SLAVE_CAPITAL flags and would otherwise be silently unusable.
// Boxes on the same map may overlap; ties resolve to the nearest box centre
// and BuildZoneSampleBoxes logs the overlapping pairs so the extents can be
// tightened against real spawn data.
struct HotspotZoneBand
{
    uint32 mapId;
    uint32 zoneId;
    float minX, maxX, minY, maxY;
};
static constexpr HotspotZoneBand ZONE_BANDS[] =
{
    // Azshara Crater (map 37): tightened from the full world-map image extent to
    // the actual creature/player spawn footprint so hotspots stop landing on the
    // crater's unreachable outer rim.
    {   37,  268,  -700.0f,  1250.0f,  -450.0f,   1200.0f   }, // Azshara Crater
    { 1405, 5006,  5334.3f,  6932.32f,   2.91f,   2132.02f  }, // Isles of Giants
    {  850, 6000,  2066.67f, 4333.33f, -5166.67f, -1766.67f }, // Stratholme Valley
    { 1410, 6100,  4479.17f, 6145.83f, -4025.0f,  -1525.0f  }, // Hyjal Frontier
    // DC Hyjal (map 750), one box per leveling-band zone. Extents from the
    // zone-tagged spawn footprints after HyjalCata/231_map750_zone_backfill.sql.
    // 4928 Moonglade is deliberately absent (sanctuary, no hotspots).
    {  750, 4923,  3390.0f,  5780.0f,  -4990.0f,  -1270.0f  }, // Hyjal Frontier (113-130)
    {  750, 4926,  4100.0f,  8000.0f,  -5330.0f,  -2200.0f  }, // Winterspring (104-115)
    {  750, 4927,  3800.0f,  7000.0f,  -2600.0f,   -400.0f  }, // Felwood (96-106)
    {  750, 4929,  4200.0f,  8300.0f,  -1700.0f,   1310.0f  }, // Darkshore (80-90)
    {  750, 4930,  1900.0f,  5100.0f,  -8430.0f,  -3900.0f  }, // Azshara (80-90)
    {  750, 4931,  1279.0f,  4267.0f,  -3800.0f,   2410.0f  }, // Ashenvale (88-98)
    // DC Plaguelands (map 751): single band covering the whole continent.
    {  751, 4924,   630.0f,  3500.0f,  -6140.0f,   -810.0f  }, // Plaguelands (130-160)
};

static bool MapHasBands(uint32 mapId)
{
    for (HotspotZoneBand const& band : ZONE_BANDS)
        if (band.mapId == mapId)
            return true;
    return false;
}

uint32 HotspotMgr::ResolveZoneAt(uint32 mapId, float x, float y, uint32 terrainZoneId) const
{
    bool banded = false;
    uint32 best = 0;
    float bestDistSq = 0.0f;

    for (HotspotZoneBand const& band : ZONE_BANDS)
    {
        if (band.mapId != mapId)
            continue;

        banded = true;
        if (x < band.minX || x > band.maxX || y < band.minY || y > band.maxY)
            continue;

        float dx = x - (band.minX + band.maxX) * 0.5f;
        float dy = y - (band.minY + band.maxY) * 0.5f;
        float distSq = dx * dx + dy * dy;
        if (!best || distSq < bestDistSq)
        {
            best = band.zoneId;
            bestDistSq = distSq;
        }
    }

    if (banded)
        return best; // 0 = outside every authored band

    return terrainZoneId;
}

uint32 HotspotMgr::ResolvePlayerZone(Player* player) const
{
    if (!player)
        return 0;

    return ResolveZoneAt(player->GetMapId(), player->GetPositionX(),
        player->GetPositionY(), player->GetZoneId());
}

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

    for (HotspotZoneBand const& band : ZONE_BANDS)
    {
        if (!IsMapEnabled(band.mapId) || !IsZoneAllowed(band.zoneId))
            continue;

        _zoneSampleBoxes.push_back({ band.zoneId, band.mapId, band.minX, band.maxX, band.minY, band.maxY });
    }

    // Overlapping bands make the announce name (and MaxPerZone accounting)
    // ambiguous in the shared region; report them so the extents get fixed.
    for (size_t i = 0; i < _zoneSampleBoxes.size(); ++i)
    {
        for (size_t j = i + 1; j < _zoneSampleBoxes.size(); ++j)
        {
            HotspotZoneSampleBox const& a = _zoneSampleBoxes[i];
            HotspotZoneSampleBox const& b = _zoneSampleBoxes[j];
            if (a.mapId != b.mapId)
                continue;
            if (a.maxX < b.minX || b.maxX < a.minX || a.maxY < b.minY || b.maxY < a.minY)
                continue;

            LOG_WARN("scripts.dc", "Hotspots: band boxes for zones {} and {} on map {} overlap; positions in the shared region resolve to the nearer box centre.",
                a.zoneId, b.zoneId, a.mapId);
        }
    }

    // Enabled maps with no authored band stay reachable through the map-wide
    // probes in RefillSpawnPool (lower hit rate, but correct).
    for (uint32 mapId : sHotspotsConfig.enabledMaps)
        if (!MapHasBands(mapId))
            LOG_INFO("server.loading", "Hotspots: map {} has no authored band box; discovery falls back to map-wide sampling.", mapId);

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

    // A zero terrain zone means the tile carries no area data at all - that is
    // a broken/unextracted tile, not just an unnamed spot.
    uint32 terrainZoneId = map->GetZoneId(PHASEMASK_NORMAL, cx, cy, gz);
    if (!terrainZoneId)
        return false;

    // Recover the level band on the DC downport continents (see ZONE_BANDS).
    uint32 zoneId = sHotspotMgr->ResolveZoneAt(mapId, cx, cy, terrainZoneId);
    if (!IsZoneAllowed(zoneId))
        return false;

    // The city/town guard protects blind map-wide discovery from dropping a
    // hotspot in Stormwind. On a banded map the band table already said yes to
    // this footprint, so applying it there would veto authored content (Isles
    // of Giants 5006 carries the SLAVE_CAPITAL flags).
    if (!MapHasBands(mapId))
    {
        uint32 areaId = map->GetAreaId(PHASEMASK_NORMAL, cx, cy, gz);
        if (IsCityLikeArea(areaId))
            return false;
    }

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

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_DC_HOTSPOT_SPAWN_POINTS);
    PreparedQueryResult result = CharacterDatabase.Query(stmt);
    if (!result)
    {
        LOG_INFO("server.loading", "Hotspots: No cached spawn points; will discover lazily.");
        return;
    }

    uint32 rebanded = 0;
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

        // Points cached before the band table existed carry the baked terrain
        // zone (every map-750 row says 4923). Re-resolve from the position so
        // MaxPerZone and the announce name track the real band; a point that
        // now falls outside every band resolves to 0 and is filtered out at
        // pick time rather than silently spawning in un-authored terrain.
        uint32 resolved = ResolveZoneAt(p.mapId, p.x, p.y, p.zoneId);
        if (resolved != p.zoneId)
        {
            p.zoneId = resolved;
            ++rebanded;
        }

        _spawnPool.push_back(p);
    } while (result->NextRow());

    LOG_INFO("server.loading", "Hotspots: Loaded {} cached spawn point(s) ({} re-resolved to their level band).",
        _spawnPool.size(), rebanded);
}

void HotspotMgr::SaveSpawnPointToDB(HotspotSpawnPoint const& p)
{
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_DC_HOTSPOT_SPAWN_POINT);
    stmt->SetData(0, uint16(p.mapId));
    stmt->SetData(1, uint16(p.zoneId));
    stmt->SetData(2, p.x);
    stmt->SetData(3, p.y);
    stmt->SetData(4, p.z);
    CharacterDatabase.Execute(stmt);
}

void HotspotMgr::RefillSpawnPool()
{
    // Target variety so spawns rarely repeat the same spot.
    constexpr size_t POOL_TARGET = 100;

    if (sHotspotsConfig.enabledMaps.empty())
        return;

    // Count only points that are usable under the CURRENT config. Counting the
    // raw pool size meant a DB full of points for maps that were later disabled
    // (or re-banded to 0) parked discovery forever, so hotspots never appeared
    // on a newly enabled map.
    size_t usable = 0;
    for (HotspotSpawnPoint const& p : _spawnPool)
        if (IsMapEnabled(p.mapId) && IsZoneAllowed(p.zoneId))
            ++usable;

    if (usable >= POOL_TARGET)
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
    std::vector<HotspotZoneSampleBox const*> boxesOnMap;
    boxesOnMap.reserve(_zoneSampleBoxes.size());

    for (uint32 probe = 0; probe < MAX_PROBES; ++probe)
    {
        if (added >= MAX_NEW_POINTS)
            break;

        // Pick the map first, then a band on it. Picking a band uniformly out
        // of the global list instead would give map 750 (six bands) six times
        // the probes of map 751 (one), starving the smaller continents.
        uint32 mapId = maps[urand(0, static_cast<uint32>(maps.size()) - 1)];

        boxesOnMap.clear();
        for (HotspotZoneSampleBox const& box : _zoneSampleBoxes)
            if (box.mapId == mapId)
                boxesOnMap.push_back(&box);

        float cx, cy;
        if (!boxesOnMap.empty())
        {
            // Sampling inside an authored band has a far higher hit rate than
            // map-wide random points and keeps the pool inside the leveling
            // zones. On banded maps everything outside a band is rejected by
            // EvaluateCandidateTerrain anyway, so there is nothing to gain
            // from map-wide probes here.
            HotspotZoneSampleBox const& box = *boxesOnMap[urand(0, static_cast<uint32>(boxesOnMap.size()) - 1)];
            cx = frand(box.minX, box.maxX);
            cy = frand(box.minY, box.maxY);
        }
        else
        {
            cx = frand(-MAP_HALFSIZE + 1.0f, MAP_HALFSIZE - 1.0f);
            cy = frand(-MAP_HALFSIZE + 1.0f, MAP_HALFSIZE - 1.0f);
        }

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
        if (!IsZoneAllowed(p.zoneId))
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

void HotspotMgr::RegisterHotspot(Hotspot& h)
{
    h.id = _nextHotspotId++;
    h.spawnTime = GameTime::GetGameTime().count();
    h.expireTime = h.spawnTime + (sHotspotsConfig.duration * MINUTE);
    h.gameObjectGuid = ObjectGuid::Empty;

    // Visual marker: created immediately only if the target grid is already
    // resident, so spawning never pulls terrain off disk. Otherwise
    // SpawnPendingMarkers (10s cleanup cadence) creates it once a player
    // loads the area — until then nobody is there to see it anyway.
    if (sHotspotsConfig.spawnVisualMarker)
        if (Map* m = GetBaseMapSafe(h.mapId))
            if (m->IsGridLoaded(h.x, h.y))
                h.gameObjectGuid = CreateHotspotMarker(m, h);

    _grid.Add(h);
    SaveHotspotToDB(h);

    LOG_INFO("scripts.dc", "Spawned Hotspot #{} on map {} zone {}", h.id, h.mapId, h.zoneId);

    // AnnounceSpawn gates the chat line only. The addon push must always go out
    // or map pins go stale on a server that merely turned the chat spam off.
    if (sHotspotsConfig.announceSpawn)
    {
        std::string zoneName = DCHotspotJson::ZoneName(h.zoneId);
        std::string mapName = "Unknown Map";
        if (MapEntry const* me = sMapStore.LookupEntry(h.mapId)) mapName = me->name[0];

        std::ostringstream ss;
        ss << "|cFFFFD700[Hotspot]|r A new XP Hotspot in " << mapName << " (" << zoneName << ")! +" << sHotspotsConfig.experienceBonus << "% XP";

        // One global announce; players on the map previously got it twice
        // (broadcast + per-map loop).
        sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, ss.str().c_str(), nullptr);
    }

    // Send WRLD packet
    DCAddon::JsonValue hotspotsArr; hotspotsArr.SetArray();
    hotspotsArr.Push(DCHotspotJson::SpawnEvent(h));

    DCAddon::JsonMessage wmsg(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
    wmsg.Set("hotspots", hotspotsArr);

    for (auto const& sess : sWorldSessionMgr->GetAllSessions())
        if (Player* p = sess.second->GetPlayer())
            wmsg.Send(p);
}

bool HotspotMgr::SpawnHotspot()
{
    if (!sHotspotsConfig.enabled || !_loaded) return false;
    if (_grid.Count() >= sHotspotsConfig.maxActive) return false;

    HotspotSpawnPoint point;
    if (!PickSpawnPoint(point))
    {
        // Pool empty or nothing eligible right now; RefillSpawnPool (throttled
        // from OnUpdate) seeds/replenishes it without blocking the tick.
        return false;
    }

    Hotspot h;
    h.mapId = point.mapId; h.zoneId = point.zoneId;
    h.x = point.x; h.y = point.y; h.z = point.z;
    RegisterHotspot(h);
    return true;
}

bool HotspotMgr::SpawnHotspotAt(uint32 mapId, uint32 zoneId, float x, float y, float z)
{
    if (!sHotspotsConfig.enabled || !_loaded)
        return false;

    // GM-placed hotspots skip the pool/eligibility sampling and the maxActive
    // cap, but the map must still exist as a hostable base map.
    if (!GetBaseMapSafe(mapId))
        return false;

    // Callers pass Player::GetZoneId(), which is the baked continent-wide area
    // id on the DC downport maps; recover the band so the announce name and
    // MaxPerZone accounting match a pool-spawned hotspot in the same spot.
    if (uint32 band = ResolveZoneAt(mapId, x, y, zoneId))
        zoneId = band;

    Hotspot h;
    h.mapId = mapId; h.zoneId = zoneId;
    h.x = x; h.y = y; h.z = z;
    RegisterHotspot(h);
    return true;
}

void HotspotMgr::CleanupExpiredHotspots()
{
    std::vector<Hotspot> all = _grid.GetAll();
    time_t now = GameTime::GetGameTime().count();

    // Create deferred visual markers for areas players have since loaded.
    SpawnPendingMarkers();

    for (Hotspot const& h : all)
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

            // The addon push is unconditional (AnnounceExpire only gates the
            // chat line); a client that never hears "expire" keeps a dead pin.
            DCAddon::JsonValue hotspotsArr; hotspotsArr.SetArray();
            hotspotsArr.Push(DCHotspotJson::ExpireEvent(h.id));
            DCAddon::JsonMessage wmsg(DCAddon::Module::WORLD, DCAddon::Opcode::World::SMSG_UPDATE);
            wmsg.Set("hotspots", hotspotsArr);

            for (auto const& sess : sWorldSessionMgr->GetAllSessions())
            {
                Player* p = sess.second->GetPlayer();
                if (!p)
                    continue;

                wmsg.Send(p);

                if (!sHotspotsConfig.announceExpire)
                    continue;

                // Who cared about this hotspot: anyone standing near it, plus
                // anyone in the same level band. The band comparison must be
                // band-aware - on maps 750/751 every player reports the single
                // baked zone id, so a raw GetZoneId() test would either message
                // the whole continent or (with banded hotspots) nobody.
                bool nearby = false;
                if (p->GetMapId() == h.mapId && sHotspotsConfig.announceRadius > 0.0f)
                {
                    float dx = p->GetPositionX() - h.x;
                    float dy = p->GetPositionY() - h.y;
                    nearby = (dx * dx + dy * dy) <= (sHotspotsConfig.announceRadius * sHotspotsConfig.announceRadius);
                }

                if (nearby || ResolvePlayerZone(p) == h.zoneId)
                    ChatHandler(p->GetSession()).PSendSysMessage("|cFFFFD700[Hotspot]|r A Hotspot has expired.");
            }
        }
    }

    std::unordered_set<uint32> activeHotspotIds;
    for (auto const& [id, activeHotspot] : _grid.View())
        activeHotspotIds.insert(id);

    // Drop "already told them about this one" markers for hotspots that are no
    // longer active, plus idle XP-report state. _playerObjectives is
    // deliberately NOT pruned here: CheckPlayerHotspotStatus owns its lifetime
    // and pruning it would race that 2s poll out of its end-of-session report.
    {
        time_t const staleBefore = now - 10 * MINUTE;
        std::lock_guard<std::mutex> lock(_playerDataLock);

        for (auto it = _playerNotifiedHotspot.begin(); it != _playerNotifiedHotspot.end(); )
        {
            if (activeHotspotIds.find(it->second) == activeHotspotIds.end())
                it = _playerNotifiedHotspot.erase(it);
            else
                ++it;
        }

        for (auto it = _playerXpReport.begin(); it != _playerXpReport.end(); )
        {
            if (it->second.pendingBonus == 0 && it->second.lastReport < staleBefore)
                it = _playerXpReport.erase(it);
            else
                ++it;
        }
    }

    // Respawn toward minActive, but only one per cleanup cycle: each spawn
    // places a GameObject marker (one grid load), so refilling N at once would
    // stack N disk loads into a single world tick. Cleanup runs every ~10s, so
    // the population recovers steadily without a spike.
    if (sHotspotsConfig.minActive > 0 && _grid.Count() < sHotspotsConfig.minActive)
        SpawnHotspot();
}

void HotspotMgr::EndObjectiveSession(Player* player, ObjectGuid guid)
{
    uint32 kills = 0;
    uint32 mins = 0;
    bool hadSession = false;
    {
        std::lock_guard<std::mutex> lock(_playerDataLock);
        auto it = _playerObjectives.find(guid);
        if (it != _playerObjectives.end())
        {
            kills = it->second.killCount;
            mins = it->second.GetSurvivalSeconds() / MINUTE;
            _playerObjectives.erase(it);
            hadSession = true;
        }
    }

    if (hadSession && player && player->GetSession())
        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF6347[Hotspot Results]|r Session ended. Kills: {} | Survival: {} min", kills, mins);
}

void HotspotMgr::CheckPlayerHotspotStatus(Player* player)
{
    if (!player) return;

    ObjectGuid const playerGuid = player->GetGUID();
    Hotspot const* hotspot = GetPlayerHotspot(player);

    if (!hotspot)
    {
        // Leash: the bonus is a *hotspot* bonus. Without this the aura outlived
        // the visit for its whole remaining duration, so a player could claim a
        // hotspot and then farm +100% XP anywhere in the world.
        if (PlayerHasAnyHotspotAura(player))
        {
            if (sHotspotsConfig.auraSpell)
                player->RemoveAura(sHotspotsConfig.auraSpell);
            if (sHotspotsConfig.buffSpell)
                player->RemoveAura(sHotspotsConfig.buffSpell);
        }

        FlushPendingXpReport(player, playerGuid, true);
        EndObjectiveSession(player, playerGuid);
        // _playerNotifiedHotspot is intentionally kept: stepping back into the
        // same hotspot must not re-fire the join notification. CleanupExpired-
        // Hotspots drops the entry when that hotspot expires.
        return;
    }

    RemoveSecondaryHotspotAuras(player);

    uint32 const targetId = hotspot->id;
    time_t const now = GameTime::GetGameTime().count();

    if (EnsurePrimaryHotspotAura(player))
    {
        // Clamp the buff to the hotspot's remaining lifetime. Spell 800001's own
        // DurationIndex would otherwise let the XP bonus outlive the hotspot the
        // player entered (and if that index is ever set to permanent, never expire).
        if (Aura* aura = player->GetAura(GetPrimaryHotspotAuraSpell()))
        {
            int32 remainingMs = static_cast<int32>((hotspot->expireTime - now) * IN_MILLISECONDS);
            if (remainingMs > 0 && (aura->GetDuration() <= 0 || aura->GetDuration() > remainingMs))
            {
                aura->SetMaxDuration(remainingMs);
                aura->SetDuration(remainingMs);
            }
        }
    }

    bool notify = false;
    bool surviveGoalHit = false;
    {
        std::lock_guard<std::mutex> lock(_playerDataLock);

        // Notify once per hotspot, not once per boundary crossing.
        auto& notified = _playerNotifiedHotspot[playerGuid];
        if (notified != targetId)
        {
            notified = targetId;
            notify = true;
        }

        if (sHotspotsConfig.objectivesEnabled)
        {
            auto& obj = _playerObjectives[playerGuid];
            if (obj.hotspotId != targetId)
            {
                obj = HotspotObjectives();
                obj.hotspotId = targetId;
                obj.entryTime = now;
            }

            // "Survive X minutes" - previously configured but never evaluated.
            if (!obj.surviveGoalReported && sHotspotsConfig.objectiveSurviveMinutes &&
                obj.GetSurvivalSeconds() >= sHotspotsConfig.objectiveSurviveMinutes * MINUTE)
            {
                obj.surviveGoalReported = true;
                surviveGoalHit = true;
            }
        }
    }

    if (!player->GetSession())
        return;

    if (notify)
        ChatHandler(player->GetSession()).SendNotification("Hotspot joined: +{}% experience", sHotspotsConfig.experienceBonus);

    if (surviveGoalHit && sHotspotsConfig.showObjectivesProgress)
        ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[Objective] Survived {} minutes in the hotspot!|r",
            sHotspotsConfig.objectiveSurviveMinutes);
}

void HotspotMgr::OnPlayerLogout(Player* player)
{
    if (!player)
        return;

    ObjectGuid const guid = player->GetGUID();
    std::lock_guard<std::mutex> lock(_playerDataLock);
    _playerObjectives.erase(guid);
    _playerNotifiedHotspot.erase(guid);
    _playerXpReport.erase(guid);
}

// One chat line per kill was both spam and per-kill packet traffic for every
// buffed player. Accumulate instead and report at most once per interval.
void HotspotMgr::FlushPendingXpReport(Player* player, ObjectGuid guid, bool force)
{
    constexpr time_t XP_REPORT_INTERVAL = 30; // seconds

    uint32 bonus = 0;
    {
        std::lock_guard<std::mutex> lock(_playerDataLock);
        auto it = _playerXpReport.find(guid);
        if (it == _playerXpReport.end() || it->second.pendingBonus == 0)
            return;

        time_t now = GameTime::GetGameTime().count();
        if (!force && (now - it->second.lastReport) < XP_REPORT_INTERVAL)
            return;

        bonus = it->second.pendingBonus;
        it->second.pendingBonus = 0;
        it->second.lastReport = now;
    }

    if (player && player->GetSession())
        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700[Hotspot XP]|r +{} bonus XP ({}%)",
            bonus, sHotspotsConfig.experienceBonus);
}

void HotspotMgr::OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim)
{
    if (!sHotspotsConfig.enabled || !player || !amount)
        return;

    if (!PlayerHasAnyHotspotAura(player))
        return;

    uint32 const bonusPct = sHotspotsConfig.experienceBonus;
    if (!bonusPct)
        return;

    // 64-bit intermediate: a misconfigured ExperienceBonus (or a very large
    // base award) overflows uint32 in the multiply and can *reduce* the XP.
    uint64 bonus64 = (static_cast<uint64>(amount) * bonusPct) / 100;
    uint64 headroom = std::numeric_limits<uint32>::max() - amount;
    uint32 bonus = static_cast<uint32>(std::min<uint64>(bonus64, headroom));
    amount += bonus;

    ObjectGuid const guid = player->GetGUID();
    {
        std::lock_guard<std::mutex> lock(_playerDataLock);
        _playerXpReport[guid].pendingBonus += bonus;
    }
    FlushPendingXpReport(player, guid, false);

    if (!sHotspotsConfig.objectivesEnabled || !victim)
        return;

    // Only kills inside the hotspot count toward the objective.
    Hotspot const* cur = GetPlayerHotspot(player);
    if (!cur)
        return;

    uint32 killCount = 0;
    bool goalReached = false;
    {
        std::lock_guard<std::mutex> lock(_playerDataLock);
        auto it = _playerObjectives.find(guid);
        if (it == _playerObjectives.end() || it->second.hotspotId != cur->id)
            return; // session is opened by CheckPlayerHotspotStatus, not here

        killCount = ++it->second.killCount;
        if (!it->second.killGoalReported && sHotspotsConfig.objectiveKillGoal &&
            killCount >= sHotspotsConfig.objectiveKillGoal)
        {
            it->second.killGoalReported = true;
            goalReached = true;
        }
    }

    if (!sHotspotsConfig.showObjectivesProgress || !player->GetSession())
        return;

    if (goalReached)
        ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00[Objective] Killed {}/{} creatures!|r",
            killCount, sHotspotsConfig.objectiveKillGoal);
    else if (killCount < sHotspotsConfig.objectiveKillGoal && (killCount % 10 == 0 || killCount == 1))
        ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFFF00[Objective] Hotspot Kills: {}/{}|r",
            killCount, sHotspotsConfig.objectiveKillGoal);
}

void HotspotMgr::ClearAll()
{
    std::vector<Hotspot> all = _grid.GetAll();
    for (Hotspot const& h : all)
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

    // Per-player state is keyed by hotspot id; with no hotspots left it is all
    // stale. Auras are stripped by the next CheckPlayerHotspotStatus poll.
    {
        std::lock_guard<std::mutex> lock(_playerDataLock);
        _playerNotifiedHotspot.clear();
        _playerObjectives.clear();
        _playerXpReport.clear();
    }

    // Ids keep incrementing on purpose - reusing them would confuse clients
    // that still hold a pin for the old hotspot.
}

void HotspotMgr::RecreateHotspotVisualMarkers()
{
    // Markers for grids that are not yet resident are created lazily by the
    // SpawnPendingMarkers pass in CleanupExpiredHotspots.
    SpawnPendingMarkers();
}

std::string HotspotMgr::GetZoneName(uint32 zoneId)
{
    return DCHotspotJson::ZoneName(zoneId);
}

// Exposed to other DC systems (stresstest, addon world/hotspot handlers).
uint32 GetHotspotXPBonusPercentage()
{
    return sHotspotsConfig.experienceBonus;
}

Hotspot const* HotspotMgr::GetPlayerHotspot(Player* player)
{
    if (!player) return nullptr;
    return _grid.GetForPlayer(player);
}

uint32 HotspotMgr::GetZoneHotspotCount(uint32 zoneId)
{
    if (!zoneId)
        return 0;

    uint32 count = 0;
    for (auto const& [id, hotspot] : _grid.View())
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
    return IsZoneAllowed(zoneId);
}
