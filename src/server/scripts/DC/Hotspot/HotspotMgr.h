#ifndef DC_HOTSPOT_MGR_H
#define DC_HOTSPOT_MGR_H

#include "HotspotGrid.h"
#include <mutex>
#include <unordered_map>

// Pre-validated spawn location. Terrain/zone eligibility is static, so once a
// point is discovered it can be reused indefinitely without probing cold
// terrain on the world thread. Backed by acore_chars.dc_hotspot_spawn_points.
struct HotspotSpawnPoint
{
    uint32 dbId = 0;
    uint32 mapId = 0;
    uint32 zoneId = 0;
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
};

// World-space bounding box of an eligible zone, derived from the authored
// ZONE_BANDS table in HotspotMgr.cpp. Discovery samples inside these instead
// of blind map-wide points, which raises the hit rate by orders of magnitude
// on continent maps.
struct HotspotZoneSampleBox
{
    uint32 zoneId = 0;
    uint32 mapId = 0;
    float minX = 0.0f;
    float maxX = 0.0f;
    float minY = 0.0f;
    float maxY = 0.0f;
};

class HotspotMgr
{
private:
    HotspotMgr(); // Singleton private constructor
    ~HotspotMgr();

    HotspotGrid _grid;
    uint32 _nextHotspotId;
    bool _loaded = false;
    // Pre-validated spawn point pool (world-thread only; no lock needed)
    std::vector<HotspotSpawnPoint> _spawnPool;
    // Zone bounding boxes for targeted discovery; rebuilt on config (re)load
    std::vector<HotspotZoneSampleBox> _zoneSampleBoxes;
    // Per-player objectives tracking
    std::unordered_map<ObjectGuid, HotspotObjectives> _playerObjectives;
    // Last hotspot each player was told they joined; suppresses repeat
    // notifications when a player walks in and out of the same radius.
    std::unordered_map<ObjectGuid, uint32> _playerNotifiedHotspot;
    // Batched XP-bonus reporting so a kill streak does not emit one chat line
    // per mob.
    struct PlayerXpReport
    {
        time_t lastReport = 0;
        uint32 pendingBonus = 0;
    };
    std::unordered_map<ObjectGuid, PlayerXpReport> _playerXpReport;
    std::mutex _playerDataLock;

    // Pick a currently-eligible point from the pool (dynamic capacity/spacing
    // checks applied at pick time). Returns false if nothing is eligible.
    bool PickSpawnPoint(HotspotSpawnPoint& out);
    void SaveSpawnPointToDB(HotspotSpawnPoint const& point);
    void BuildZoneSampleBoxes();
    // Close a player's objective session and report the result to them.
    void EndObjectiveSession(Player* player, ObjectGuid guid);
    // Emit the batched "+N XP" line if one is due (or forced, e.g. on exit).
    void FlushPendingXpReport(Player* player, ObjectGuid guid, bool force);
    // Create markers for hotspots whose target grid has since been loaded by
    // a player; spawning itself never forces terrain off disk.
    void SpawnPendingMarkers();
    // Register a fully-populated hotspot: assign id, create the marker if the
    // grid is resident, persist, add to the grid and announce. Shared by the
    // pooled spawner and the explicit-coordinate (GM command) path.
    void RegisterHotspot(Hotspot& h);

public:
    static HotspotMgr* instance();

    HotspotGrid& GetGrid() { return _grid; }

    void LoadConfig();
    void LoadFromDB();
    bool SpawnHotspot();
    // Spawn a hotspot at explicit coordinates (GM command path). Bypasses the
    // pool/eligibility sampling; still validates the map exists and is a base map.
    bool SpawnHotspotAt(uint32 mapId, uint32 zoneId, float x, float y, float z);
    void CleanupExpiredHotspots();

    // Spawn point pool: load persisted points, and lazily discover new ones
    // with bounded disk I/O per call (throttled from OnUpdate).
    void LoadSpawnPointsFromDB();
    void RefillSpawnPool();

    // Player interactions
    // Pointer variant is world-thread-only; the snapshot variant is safe from
    // map-worker threads (PlayerScript hooks inside Map::Update).
    Hotspot const* GetPlayerHotspot(Player* player);
    bool GetPlayerHotspotSnapshot(Player* player, Hotspot& out);
    void CheckPlayerHotspotStatus(Player* player);
    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim);
    void OnPlayerLogout(Player* player);

    // Resolve the hotspot-facing zone id for a world position. On the DC
    // downport continents the terrain reports a single baked area id for the
    // whole map (750 -> 4923, 751 -> 4924), so the level bands are recovered
    // from the authored band table instead. Returns 0 when the map is banded
    // and the position falls outside every band; otherwise falls back to
    // terrainZoneId.
    uint32 ResolveZoneAt(uint32 mapId, float x, float y, uint32 terrainZoneId) const;
    uint32 ResolvePlayerZone(Player* player) const;

    // API for Commands/Scripts
    bool CanSpawnInZone(uint32 zoneId);
    uint32 GetZoneHotspotCount(uint32 zoneId);
    bool IsZoneHotspotActive(uint32 zoneId);
    void RecreateHotspotVisualMarkers();
    void ClearAll();

    // DB Helpers
    void SaveHotspotToDB(Hotspot const& hotspot);
    void DeleteHotspotFromDB(uint32 id);

    // Utils
    std::string GetZoneName(uint32 zoneId);
};

#define sHotspotMgr HotspotMgr::instance()

#endif
