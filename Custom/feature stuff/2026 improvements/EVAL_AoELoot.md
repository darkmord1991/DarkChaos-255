# DC AoELoot System Evaluation
## 2026 Improvements Analysis

**Files Analyzed:** 2 files (75KB+ total)
**Last Analyzed:** January 1, 2026

---

## System Overview

The AoELoot system enables looting multiple nearby corpses with a single action, with quality filtering and profession integration.

### Core Components
| File | Size | Purpose |
|------|------|---------|
| `ac_aoeloot.cpp` | 38KB | Core AoE loot mechanics |
| `dc_aoeloot_extensions.cpp` | 38KB | Quality filter, skinning, stats |

---

## 🔴 CRITICAL: Duplicate Code Issue

### **ac_aoeloot.cpp vs dc_aoeloot_extensions.cpp**

Both files are **nearly identical in size (38KB each)** and contain overlapping functionality:

**Duplicated Elements:**
1. Configuration structures (`AoELootConfig` vs `AoELootExtConfig`)
2. Player data tracking (`PlayerAoELootData` vs `PlayerLootPreferences`)
3. Quality filtering logic (implemented in both)
4. Player scripts (both have login/logout handlers)
5. Command scripts (overlapping commands)

**Root Cause:**
Original `ac_aoeloot.cpp` was from AzerothCore, then `dc_aoeloot_extensions.cpp` was created to add features, but now both contain similar functionality.

**Recommendation:** **MERGE INTO SINGLE FILE**
```cpp
// Proposed: dc_aoeloot_unified.cpp
// Contains:
// - Core loot merging (from ac_aoeloot)
// - Quality filtering (from extensions)
// - Profession integration (from extensions)
// - All stats tracking (unified)
// - Single player script
// - Single command script
```

---

## 🔴 Other Issues Found

### 1. **Try-Catch Exception Handling is Expensive**
```cpp
try {
    return DCAoELootExt::GetPlayerShowMessages(player->GetGUID());
} catch (...) {
    // Fallback
}
```
**Recommendation:** Check if function exists at compile time or use optional pattern.

### 2. **Excessive Logging in Hot Path**
```cpp
LOG_INFO("scripts", "AoELoot: Player {} has minQuality filter set to {}",
         player->GetName(), playerMinQuality);
```
This runs EVERY LOOT attempt.
**Recommendation:** Change to `LOG_DEBUG` or add config toggle.

### 3. **No Batch Database Updates**
Each stat update is a separate query:
```cpp
CharacterDatabase.Execute("REPLACE INTO dc_aoeloot_preferences...");
CharacterDatabase.Execute("REPLACE INTO dc_aoeloot_detailed_stats...");
```
**Recommendation:** Batch updates on logout or periodically.

### 4. **Quality Names Hardcoded Multiple Times**
```cpp
const char* qualityNames[] = {"Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact"};
// Appears in multiple places
```
**Recommendation:** Define once as constexpr array.

---

## 🟡 Improvements Suggested

### 1. **Loot Filter Presets**
Quick-switch between filter configurations:
```cpp
enum LootPreset {
    EVERYTHING,     // All items
    VENDOR_TRASH,   // Common+
    ADVENTURER,     // Uncommon+
    RAIDER,         // Rare+
    COLLECTOR,      // Epic+
    CUSTOM
};
```

### 2. **Auto-Vendor Integration**
Automatic vendor of filtered items:
- Poor items → instant gold credit
- Track gold from auto-vendor in stats

### 3. **Loot Sound Customization**
Different sounds for quality tiers:
- Epic+ : Special notification sound
- Upgrade : Distinct upgrade sound

### 4. **Smart Item Detection**
Highlight items that are upgrades:
```cpp
struct LootItemHighlight {
    bool isUpgrade;
    bool isTransmogNew;
    bool isCollectionNew;
};
```

### 5. **Loot History Log**
Recent loot history accessible via command:
```
.aoeloot history 10
```

---

## 🟢 Extensions Recommended

### 1. **Party Loot Sync**
Broadcast loot to party:
- "[Player] looted [Epic Item]"
- Configurable threshold

### 2. **Loot Timer Statistics**
Track looting efficiency:
- Items per minute
- Average loot value
- Peak looting performance

### 3. **Favorite Items List**
Auto-loot only specific items:
```cpp
std::unordered_set<uint32> favoriteItemIds;
bool onlyLootFavorites;
```

### 4. **Loot Gambling Mini-Game**
Optional gamble on loot quality:
- Risk current loot for chance at upgrade
- House edge configurable

---

## 📊 Technical Upgrades

### Proposed Unified Structure

```cpp
// dc_aoeloot_unified.cpp (~50KB max)

namespace DCAoELoot {
    // Configuration
    struct Config { ... };
    
    // Player State
    struct PlayerData {
        Preferences prefs;
        Statistics stats;
        LootSession current;
    };
    
    // Core Functions
    bool PerformAoELoot(Player* player, Creature* mainTarget);
    
    // Scripts (Single instances)
    class ServerScript;
    class PlayerScript;
    class CommandScript;
}
```

### Database Consolidation
```sql
-- Merge tables
CREATE TABLE dc_aoeloot_player (
    player_guid INT PRIMARY KEY,
    -- Preferences
    aoe_enabled BOOL,
    min_quality TINYINT,
    show_messages BOOL,
    auto_skin BOOL,
    smart_loot BOOL,
    -- Statistics
    total_items INT,
    total_gold BIGINT,
    quality_poor INT,
    quality_common INT,
    quality_uncommon INT,
    quality_rare INT,
    quality_epic INT,
    quality_legendary INT,
    -- Session
    last_loot_time DATETIME,
    session_items INT
);
```

---

## Migration Plan

1. **Phase 1:** Create `dc_aoeloot_unified.cpp`
2. **Phase 2:** Migrate functionality from both files
3. **Phase 3:** Update `CMakeLists.txt` to exclude old files
4. **Phase 4:** Delete `ac_aoeloot.cpp` and `dc_aoeloot_extensions.cpp`
5. **Phase 5:** Consolidate database tables

---

## Priority Actions

1. **CRITICAL:** Merge ac_aoeloot.cpp and dc_aoeloot_extensions.cpp
2. **HIGH:** Remove try-catch in hot path
3. **HIGH:** Reduce logging verbosity
4. **MEDIUM:** Batch database updates
5. **MEDIUM:** Add loot presets
6. **LOW:** Party loot sync
