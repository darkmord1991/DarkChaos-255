#include "HotspotGrid.h"
#include "Player.h"
#include <algorithm>
#include <cmath>

HotspotGrid::GridKey HotspotGrid::GetKey(uint32 mapId, float x, float y) const
{
    // Offset coords to handle negatives (min -17066)
    int16_t cx = static_cast<int16_t>((x + 20000.0f) / CELL_SIZE);
    int16_t cy = static_cast<int16_t>((y + 20000.0f) / CELL_SIZE);
    return (static_cast<uint64_t>(mapId) << 32) | (static_cast<uint32>(cx) & 0xFFFF) << 16 | (static_cast<uint32>(cy) & 0xFFFF);
}

void HotspotGrid::GetKeysInRange(uint32 mapId, float x, float y, float radius, std::vector<GridKey>& keys) const
{
    // Get all cells that the radius touches
    float minX = x - radius;
    float maxX = x + radius;
    float minY = y - radius;
    float maxY = y + radius;

    int16_t startCX = static_cast<int16_t>((minX + 20000.0f) / CELL_SIZE);
    int16_t endCX   = static_cast<int16_t>((maxX + 20000.0f) / CELL_SIZE);
    int16_t startCY = static_cast<int16_t>((minY + 20000.0f) / CELL_SIZE);
    int16_t endCY   = static_cast<int16_t>((maxY + 20000.0f) / CELL_SIZE);

    for (int16_t cx = startCX; cx <= endCX; ++cx)
    {
        for (int16_t cy = startCY; cy <= endCY; ++cy)
        {
            keys.push_back((static_cast<uint64_t>(mapId) << 32) | (static_cast<uint32>(cx) & 0xFFFF) << 16 | (static_cast<uint32>(cy) & 0xFFFF));
        }
    }
}

void HotspotGrid::Add(Hotspot const& hotspot)
{
    _hotspots[hotspot.id] = hotspot;
    
    // Register in all overlapping cells (radius + minimal buffer)
    std::vector<GridKey> keys;
    GetKeysInRange(hotspot.mapId, hotspot.x, hotspot.y, sHotspotsConfig.announceRadius, keys);

    for (GridKey key : keys)
    {
        _grid[key].hotspotIds.push_back(hotspot.id);
    }
}

void HotspotGrid::Remove(uint32 id)
{
    auto it = _hotspots.find(id);
    if (it == _hotspots.end()) return;

    Hotspot const& hotspot = it->second;
    std::vector<GridKey> keys;
    GetKeysInRange(hotspot.mapId, hotspot.x, hotspot.y, sHotspotsConfig.announceRadius, keys);

    for (GridKey key : keys)
    {
        auto& cell = _grid[key];
        auto& ids = cell.hotspotIds;
        ids.erase(std::remove(ids.begin(), ids.end(), id), ids.end());
        if (ids.empty())
            _grid.erase(key);
    }

    _hotspots.erase(it);
}

Hotspot const* HotspotGrid::GetById(uint32 id) const
{
    auto it = _hotspots.find(id);
    return it != _hotspots.end() ? &it->second : nullptr;
}

Hotspot const* HotspotGrid::GetForPlayer(Player* player) const
{
    if (!player) return nullptr;
    uint32 mapId = player->GetMapId();
    float x = player->GetPositionX();
    float y = player->GetPositionY();

    GridKey key = GetKey(mapId, x, y);
    auto it = _grid.find(key);
    if (it == _grid.end()) return nullptr;

    for (uint32 id : it->second.hotspotIds)
    {
        auto hit = _hotspots.find(id);
        if (hit != _hotspots.end())
        {
            if (hit->second.IsPlayerInRange(player))
                return &hit->second;
        }
    }
    return nullptr;
}

std::vector<Hotspot> HotspotGrid::GetAll() const
{
    std::vector<Hotspot> all;
    all.reserve(_hotspots.size());
    for (auto const& kv : _hotspots)
        all.push_back(kv.second);
    return all;
}
