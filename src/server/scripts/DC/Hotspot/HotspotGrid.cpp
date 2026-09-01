#include "HotspotGrid.h"
#include "Player.h"
#include <algorithm>
#include <cmath>
#include <mutex>

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
    std::unique_lock<std::shared_mutex> guard(_lock);
    _hotspots[hotspot.id] = hotspot;

    // Register in the hotspot's own cell only. Registration must not depend on
    // any runtime-reloadable config value: Remove() would then compute a
    // different key set than Add() did and leak ids into cells forever. The
    // query side (GetForPlayer) expands its search instead.
    _grid[GetKey(hotspot.mapId, hotspot.x, hotspot.y)].hotspotIds.push_back(hotspot.id);
}

void HotspotGrid::Remove(uint32 id)
{
    std::unique_lock<std::shared_mutex> guard(_lock);
    auto it = _hotspots.find(id);
    if (it == _hotspots.end()) return;

    Hotspot const& hotspot = it->second;
    GridKey key = GetKey(hotspot.mapId, hotspot.x, hotspot.y);

    auto cellIt = _grid.find(key);
    if (cellIt != _grid.end())
    {
        auto& ids = cellIt->second.hotspotIds;
        ids.erase(std::remove(ids.begin(), ids.end(), id), ids.end());
        if (ids.empty())
            _grid.erase(cellIt);
    }

    _hotspots.erase(it);
}

void HotspotGrid::UpdateGameObjectGuid(uint32 id, ObjectGuid guid)
{
    std::unique_lock<std::shared_mutex> guard(_lock);
    auto it = _hotspots.find(id);
    if (it != _hotspots.end())
        it->second.gameObjectGuid = guid;
}

Hotspot const* HotspotGrid::GetById(uint32 id) const
{
    std::shared_lock<std::shared_mutex> guard(_lock);
    auto it = _hotspots.find(id);
    return it != _hotspots.end() ? &it->second : nullptr;
}

Hotspot const* HotspotGrid::FindForPlayerUnlocked(Player* player) const
{
    if (!player) return nullptr;
    uint32 mapId = player->GetMapId();
    float x = player->GetPositionX();
    float y = player->GetPositionY();

    // A hotspot is registered in its own cell only, so a player standing up to
    // `radius` away can sit in a neighbouring cell. Sweep every cell the
    // interaction radius touches.
    std::vector<GridKey> keys;
    GetKeysInRange(mapId, x, y, sHotspotsConfig.radius, keys);

    for (GridKey key : keys)
    {
        auto it = _grid.find(key);
        if (it == _grid.end())
            continue;

        for (uint32 id : it->second.hotspotIds)
        {
            auto hit = _hotspots.find(id);
            if (hit != _hotspots.end() && hit->second.IsPlayerInRange(player))
                return &hit->second;
        }
    }
    return nullptr;
}

Hotspot const* HotspotGrid::GetForPlayer(Player* player) const
{
    std::shared_lock<std::shared_mutex> guard(_lock);
    return FindForPlayerUnlocked(player);
}

bool HotspotGrid::GetForPlayerSnapshot(Player* player, Hotspot& out) const
{
    std::shared_lock<std::shared_mutex> guard(_lock);
    if (Hotspot const* hotspot = FindForPlayerUnlocked(player))
    {
        out = *hotspot;
        return true;
    }
    return false;
}

size_t HotspotGrid::Count() const
{
    std::shared_lock<std::shared_mutex> guard(_lock);
    return _hotspots.size();
}

std::vector<Hotspot> HotspotGrid::GetAll() const
{
    std::shared_lock<std::shared_mutex> guard(_lock);
    std::vector<Hotspot> all;
    all.reserve(_hotspots.size());
    for (auto const& kv : _hotspots)
        all.push_back(kv.second);
    return all;
}
