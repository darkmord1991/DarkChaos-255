#ifndef DC_HOTSPOT_MGR_H
#define DC_HOTSPOT_MGR_H

#include "HotspotGrid.h"
#include <mutex>
#include <unordered_map>

class HotspotMgr
{
private:
    HotspotMgr(); // Singleton private constructor
    ~HotspotMgr();

    HotspotGrid _grid;
    uint32 _nextHotspotId;
    std::unordered_map<uint32, std::array<float, 4>> _mapBounds;
    // Per-player objectives tracking
    std::unordered_map<ObjectGuid, HotspotObjectives> _playerObjectives;
    // Per-player server-side expiry check
    std::unordered_map<ObjectGuid, time_t> _playerExpiry;
    // Per-player tracking for XP calc
    struct PlayerHotspotTracking
    {
        time_t entryTime;
        time_t lastXPGain;
    };
    std::unordered_map<ObjectGuid, PlayerHotspotTracking> _playerTracking;
    std::mutex _playerDataLock;

public:
    static HotspotMgr* instance();

    HotspotGrid& GetGrid() { return _grid; }

    void LoadConfig();
    void LoadFromDB();
    bool SpawnHotspot();
    void CleanupExpiredHotspots();

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
