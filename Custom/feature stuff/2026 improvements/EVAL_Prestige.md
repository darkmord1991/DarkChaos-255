# DC Prestige System Evaluation
## 2026 Improvements Analysis

**Files Analyzed:** 7 files (90KB+ total)
**Last Analyzed:** January 1, 2026

---

## System Overview

The Prestige system allows max-level (255) players to reset to level 1 with permanent stat bonuses, up to 10 prestige levels.

### Core Components
| File | Size | Purpose |
|------|------|---------|
| `dc_prestige_system.cpp` | 36KB | Main prestige logic |
| `dc_prestige_challenges.cpp` | 22KB | Prestige-specific challenges |
| `dc_prestige_chat.cpp` | 15KB | Chat badge/flair |
| `dc_prestige_alt_bonus.cpp` | 10KB | Alt character bonuses |
| `dc_prestige_api.h` | 1KB | Public API |

---

## 🔴 Issues Found

### 1. **Lookup Tables Duplicated**
Same spell/title arrays defined twice:
```cpp
// Line 45
constexpr uint32 PRESTIGE_SPELLS[MAX_PRESTIGE_LEVEL] = {...};
// Line 50
constexpr uint32 PRESTIGE_TITLES[MAX_PRESTIGE_LEVEL] = {...};

// Also in enum PrestigeSpells (line 55)
enum PrestigeSpells {
    SPELL_PRESTIGE_BONUS_1 = 800010,  // Duplicates array
```
**Recommendation:** Single source of truth.

### 2. **Race-Specific Teleport Incomplete**
```cpp
void TeleportToStartingLocation(Player* player)
{
    // ~90 lines of switch statements
    // Some races missing or defaulting
}
```
**Recommendation:** Database-driven starting locations.

### 3. **Gear Removal Doesn't Handle Bank**
```cpp
void RemoveAllGear(Player* player)
{
    // Only removes equipped and backpack
    // Bank items preserved
}
```
May be intentional but not documented.

### 4. **Profession Reset Too Aggressive**
```cpp
void ResetProfessions(Player* player)
{
    // Resets ALL skills to 0
    // Loses recipe knowledge
}
```
**Recommendation:** Optional profession preservation at cost.

---

## 🟡 Improvements Suggested

### 1. **Prestige Confirmation UI**
Multi-step confirmation:
1. Show what will be lost
2. Show what will be gained
3. Type "PRESTIGE" to confirm
4. 10-second countdown

### 2. **Prestige Loadouts**
Save gear configurations before prestige:
```cpp
struct PrestigeLoadout {
    uint32 prestigeLevel;
    std::map<uint8, uint32> gearSlots;
    std::string name;
};
```
Grant equivalent gear at certain levels.

### 3. **Prestige Milestones**
Bonus rewards at certain levels:
- Prestige 5: Special mount
- Prestige 10: Unique title + tabard

### 4. **Heritage Gear**
Transmog unlocks based on prestige:
- Each prestige unlocks class-themed set
- Persists across resets

### 5. **Prestige Leaderboard**
Track fastest prestige times:
- Time to max level per prestige
- Total prestige completions
- Most challenged prestige mode

---

## 🟢 Extensions Recommended

### 1. **Prestige Difficulty Modes**
Optional harder prestige:
```cpp
enum PrestigeMode {
    NORMAL,      // Standard bonuses
    HARDCORE,    // No deaths allowed
    IRONMAN,     // No trading, no AH
    SPEEDRUN     // Timer active
};
```

### 2. **Prestige Talents**
Permanent passive abilities:
```cpp
struct PrestigeTalent {
    uint32 id;
    std::string name;
    uint8 requiredPrestige;
    uint32 passiveSpellId;
};
// Examples:
// - 5% mount speed
// - Instant flight paths
// - Bonus rested XP
// - Vendor access anywhere
```

### 3. **Prestige Guild Bonuses**
Aggregate guild prestige:
- Total prestige of all members
- Unlock guild perks
- Prestige recruitment display

### 4. **Prestige Cosmetics**
Progressive cosmetic unlocks:
- Chat color/glow
- Nameplate effects
- Combat VFX
- Pet variations

### 5. **Seasonal Prestige**
Time-limited prestige race:
- New players only
- Season rewards based on speed
- Leaderboard placement rewards

---

## 📊 Technical Upgrades

### Database Improvements
```sql
-- Add prestige history
CREATE TABLE dc_prestige_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    player_guid INT,
    prestige_level TINYINT,
    mode ENUM('normal', 'hardcore', 'ironman', 'speedrun'),
    started_at DATETIME,
    completed_at DATETIME,
    total_time_seconds INT,
    deaths INT,
    achievements_earned INT
);

-- Add prestige talents
CREATE TABLE dc_prestige_talents (
    player_guid INT,
    talent_id INT,
    unlocked_at DATETIME,
    PRIMARY KEY (player_guid, talent_id)
);
```

### Performance Considerations
- Current prestige operation takes ~500ms
- Target: <100ms
- Main bottleneck: gear removal iterating all slots

---

## Integration Points

| System | Integration | Quality |
|--------|------------|---------|
| ItemUpgrades | Stat multipliers | ⭐⭐⭐⭐ |
| Seasons | Seasonal bonuses | ⭐⭐⭐ |
| CrossSystem | Event publishing | ⭐⭐⭐⭐ |
| AddonExtension | UI sync | ⭐⭐⭐⭐ |
| Chat System | Badges | ⭐⭐⭐⭐⭐ |
| Achievements | Tracking | ⭐⭐⭐ |

---

## Priority Actions

1. **HIGH:** Remove duplicate lookup tables
2. **HIGH:** Add prestige confirmation UI
3. **MEDIUM:** Database-driven starting locations
4. **MEDIUM:** Add profession preservation option
5. **LOW:** Prestige difficulty modes
6. **LOW:** Prestige talents system
