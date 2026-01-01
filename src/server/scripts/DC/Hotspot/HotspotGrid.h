#ifndef DC_HOTSPOT_GRID_H
#define DC_HOTSPOT_GRID_H

#include "HotspotDefines.h"
#include <unordered_map>
#include <vector>

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

    GridKey GetKey(uint32 mapId, float x, float y) const;
    void GetKeysInRange(uint32 mapId, float x, float y, float radius, std::vector<GridKey>& keys) const;

public:
    void Add(Hotspot const& hotspot);
    void Remove(uint32 id);
    Hotspot const* GetById(uint32 id) const;
    Hotspot const* GetForPlayer(Player* player) const;
    size_t Count() const { return _hotspots.size(); }
    std::vector<Hotspot> GetAll() const;
};

#endif
