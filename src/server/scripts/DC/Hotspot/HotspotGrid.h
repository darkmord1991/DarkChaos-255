#ifndef DC_HOTSPOT_GRID_H
#define DC_HOTSPOT_GRID_H

#include "HotspotDefines.h"
#include <shared_mutex>
#include <unordered_map>
#include <vector>

// Thread contract: all writers (Add/Remove/UpdateGameObjectGuid) run on the
// world thread. Readers additionally run on map-worker threads --
// HotspotMgr::CheckPlayerHotspotStatus and OnPlayerGiveXP are reached from
// PlayerScript hooks inside Map::Update. The internal shared_mutex makes each
// call atomic; the POINTER-returning readers (GetById/GetForPlayer/View) are
// still world-thread-only, because the pointer outlives the lock and only the
// world thread is guaranteed no concurrent write follows. Cross-thread readers
// must use the *Snapshot copy-out variants.
class HotspotGrid
{
private:
    static constexpr float CELL_SIZE = 300.0f; // Large enough to cover most interaction ranges

    struct GridCell
    {
        std::vector<uint32> hotspotIds;
    };

    // key: (mapId << 32) | (cellX << 16) | cellY
    using GridKey = uint64_t;
    std::unordered_map<GridKey, GridCell> _grid;
    std::unordered_map<uint32, Hotspot> _hotspots; // All active hotspots by ID
    mutable std::shared_mutex _lock;

    GridKey GetKey(uint32 mapId, float x, float y) const;
    void GetKeysInRange(uint32 mapId, float x, float y, float radius, std::vector<GridKey>& keys) const;
    // Lookup without taking _lock; caller must hold it.
    Hotspot const* FindForPlayerUnlocked(Player* player) const;

public:
    void Add(Hotspot const& hotspot);
    void Remove(uint32 id);
    void UpdateGameObjectGuid(uint32 id, ObjectGuid guid);
    // World-thread-only (returns a pointer into the map; see class comment).
    Hotspot const* GetById(uint32 id) const;
    Hotspot const* GetForPlayer(Player* player) const;
    // Safe from any thread: copies the hotspot out under the shared lock.
    bool GetForPlayerSnapshot(Player* player, Hotspot& out) const;
    size_t Count() const;
    // Snapshot copy - use when the caller mutates the grid while iterating
    // (CleanupExpiredHotspots) or needs to sort/filter its own vector.
    std::vector<Hotspot> GetAll() const;
    // Read-only view for the common "just iterate" case; avoids copying every
    // hotspot on every capacity/distance check. World-thread-only.
    std::unordered_map<uint32, Hotspot> const& View() const { return _hotspots; }
};

#endif
