#ifndef DC_HOTSPOT_MGR_H
#define DC_HOTSPOT_MGR_H

#include "HotspotGrid.h"
#include <mutex>
#include <unordered_map>
#include <unordered_set>

// Pre-validated spawn location. Terrain/zone eligibility is static, so once a
// point is discovered it can be reused indefinitely without probing cold
// terrain on the world thread. Backed by the dc_hotspot_spawn_points table.
struct HotspotSpawnPoint
{
    uint32 dbId = 0;
    uint32 mapId = 0;
    uint32 zoneId = 0;
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
};

// World-space bounding box of an eligible zone (from WorldMapArea data).
// Discovery samples inside these instead of blind map-wide points, which
// raises the hit rate by orders of magnitude on continent maps.
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
    std::unordered_map<uint32, std::array<float, 4>> _mapBounds;
    // Pre-validated spawn point pool (world-thread only; no lock needed)
    std::vector<HotspotSpawnPoint> _spawnPool;
    // Zone bounding boxes for targeted discovery; rebuilt on config (re)load
    std::vector<HotspotZoneSampleBox> _zoneSampleBoxes;
    // Per-player objectives tracking
    std::unordered_map<ObjectGuid, HotspotObjectives> _playerObjectives;
    // Per-player server-side expiry check
    std::unordered_map<ObjectGuid, time_t> _playerExpiry;
    // Per-player one-time hotspot grants (hotspotId or dungeon grant id)
    std::unordered_map<ObjectGuid, std::unordered_set<uint32>> _playerGrantedHotspots;
    // Per-player tracking for XP calc
    struct PlayerHotspotTracking
    {
        time_t entryTime;
        time_t lastXPGain;
    };
    std::unordered_map<ObjectGuid, PlayerHotspotTracking> _playerTracking;
    std::mutex _playerDataLock;

    // Pick a currently-eligible point from the pool (dynamic capacity/spacing
    // checks applied at pick time). Returns false if nothing is eligible.
    bool PickSpawnPoint(HotspotSpawnPoint& out);
    void SaveSpawnPointToDB(HotspotSpawnPoint const& point);
    void BuildZoneSampleBoxes();
    // Create markers for hotspots whose target grid has since been loaded by
    // a player; spawning itself never forces terrain off disk.
    void SpawnPendingMarkers();

public:
    static HotspotMgr* instance();

    HotspotGrid& GetGrid() { return _grid; }

    void LoadConfig();
    void LoadFromDB();
    bool SpawnHotspot();
    void CleanupExpiredHotspots();

    // Spawn point pool: load persisted points, and lazily discover new ones
    // with bounded disk I/O per call (throttled from OnUpdate).
    void LoadSpawnPointsFromDB();
    void RefillSpawnPool();

    // Player interactions
    Hotspot const* GetPlayerHotspot(Player* player);
    void CheckPlayerHotspotStatus(Player* player);
    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim);

    // API for Commands/Scripts
    bool CanSpawnInZone(uint32 zoneId);
    uint32 GetZoneHotspotCount(uint32 zoneId);
    bool IsZoneHotspotActive(uint32 zoneId);
    void RecreateHotspotVisualMarkers();
    uint32 GenerateNextId() { return _nextHotspotId++; }
    void ClearAll();

    // DB Helpers
    void SaveHotspotToDB(Hotspot const& hotspot);
    void DeleteHotspotFromDB(uint32 id);

    // Utils
    std::string GetZoneName(uint32 zoneId);
};

#define sHotspotMgr HotspotMgr::instance()

#endif
