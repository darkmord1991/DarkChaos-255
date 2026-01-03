# DC Hotspot System Evaluation
## 2026 Improvements Analysis

**Files Analyzed:** 3 files (143KB+ total)
**Last Analyzed:** January 1, 2026

---

## System Overview

The Hotspot system spawns random XP bonus zones across maps where players receive bonuses for killing monsters.

### Core Components
| File | Size | Purpose |
|------|------|---------|
| `ac_hotspots.cpp` | 138KB | Main hotspot logic (3300+ lines!) |
| `HotspotConstants.h` | 3KB | Configuration constants |
| `spell_hotspot_buff_800001.cpp` | 2KB | Buff spell script |

---

## 🔴 Issues Found

### 1. **Monolithic File - ac_hotspots.cpp is 3300+ Lines**
Far too large for maintainability:
- Map bounds loading
- Hotspot spawning
- Anti-camping logic
- Addon integration
- Commands
- Scripts
All in single file!

**Recommendation:** Split into:
- `HotspotCore.cpp` (~800 lines) - Spawn/expire logic
- `HotspotMapBounds.cpp` (~400 lines) - Coordinate systems
- `HotspotAntiCamp.cpp` (~200 lines) - Anti-camping
- `HotspotAddon.cpp` (~300 lines) - Client sync
- `HotspotCommands.cpp` (~200 lines) - GM commands

### 2. **Inefficient Player Distance Checks**
```cpp
bool IsPlayerInRange(Player* player)
{
    float dx = player->GetPositionX() - x;
    float dy = player->GetPositionY() - y;
    float dz = player->GetPositionZ() - z;
    float dist2 = dx*dx + dy*dy + dz*dz;
    return dist2 <= (radius * radius);
}
```
Calculated for every player, every update tick.
**Recommendation:** Use spatial partitioning (grid cells).

### 3. **Map Bounds Hardcoded and Duplicated**
Multiple sources:
- `sMapBounds` static map
- CSV loading
- DBC loading
- Client ADT parsing

**Recommendation:** Single authoritative source from DBC.

### 4. **No Hotspot Instances for Dungeons**
Hotspots only work in world maps. Could enable for dungeons.

---

## 🟡 Improvements Suggested

### 1. **Hotspot Tiers**
Different bonus levels:
```cpp
enum HotspotTier {
    COMMON,     // 50% XP bonus
    RARE,       // 100% XP bonus  
    EPIC,       // 200% XP bonus
    LEGENDARY   // 300% XP bonus + special rewards
};
```

### 2. **Contested Hotspots**
PvP-enabled hotspots:
- Higher rewards
- Flagged for PvP while inside
- Faction control bonuses

### 3. **Hotspot Objectives**
Optional mini-objectives:
- Kill X creatures
- Survive for Y minutes
- Complete while below Z health

### 4. **Hotspot Events**
Special periodic hotspots:
- Boss spawn hotspots
- Treasure hunt hotspots
- Raid-size hotspots

### 5. **Hotspot Notifications**
Better discovery:
- Minimap pulse when nearby
- Zone-wide announcement
- World map markers

---

## 🟢 Extensions Recommended

### 1. **Personal Hotspots**
Player-summoned hotspots:
- Item/currency cost
- Smaller radius
- Shorter duration
- Solo benefit only

### 2. **Guild Hotspot Control**
Guilds can claim hotspots:
- Guild banner at center
- Guild-wide bonus
- Persists across sessions

### 3. **Hotspot Chains**
Linked hotspots:
- Complete one, next spawns nearby
- Increasing bonuses
- Final boss at end

### 4. **Seasonal Hotspots**
Season-themed locations:
- Special visual effects
- Unique rewards
- Limited availability

### 5. **Hotspot Achievements**
- Visit 100 hotspots
- Kill 1000 mobs in hotspots
- Find all zone hotspots
- Legendary hotspot survivor

---

## 📊 Technical Upgrades

### File Split Plan

| New File | Content | Est. Size |
|----------|---------|-----------|
| HotspotCore.cpp | Spawn, update, expire | 800 lines |
| HotspotMapBounds.cpp | Coordinate validation | 400 lines |
| HotspotAntiCamp.cpp | Diminishing returns | 200 lines |
| HotspotAddon.cpp | Client sync | 300 lines |
| HotspotCommands.cpp | GM commands | 200 lines |
| HotspotScripts.cpp | Player/Server scripts | 200 lines |
| HotspotDatabase.cpp | Persistence | 200 lines |

### Spatial Optimization
```cpp
// Use grid-based player lookup
class HotspotGrid {
    static constexpr float CELL_SIZE = 100.0f;
    std::unordered_map<uint64, std::vector<ObjectGuid>> cells;
    
    void RegisterPlayer(Player* player);
    void UnregisterPlayer(Player* player);
    std::vector<ObjectGuid> GetNearbyPlayers(float x, float y, float radius);
};
```

### Database Schema
```sql
-- Add hotspot history
CREATE TABLE dc_hotspot_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    map_id INT,
    zone_id INT,
    x FLOAT,
    y FLOAT,
    z FLOAT,
    tier TINYINT,
    spawn_time DATETIME,
    expire_time DATETIME,
    total_kills INT,
    unique_visitors INT
);
```

---

## Integration Points

| System | Integration | Quality |
|--------|------------|---------|
| AddonExtension | Map markers | ⭐⭐⭐⭐ |
| Prestige | XP multipliers | ⭐⭐⭐ |
| Seasons | Seasonal bonuses | ⭐⭐⭐ |
| CrossSystem | Events | ⭐⭐ |

---

## Priority Actions

1. **CRITICAL:** Split ac_hotspots.cpp (3300 lines too large)
2. **HIGH:** Implement spatial partitioning
3. **HIGH:** Consolidate map bounds sources
4. **MEDIUM:** Add hotspot tiers
5. **LOW:** Guild hotspot control
