# DC MythicPlus System Evaluation
## 2026 Improvements Analysis

**Files Analyzed:** 21 files (400KB+ total)
**Last Analyzed:** January 1, 2026

---

## System Overview

The MythicPlus system provides a complete retail-like Mythic+ dungeon experience with keystones, affixes, scoring, vaults, and spectator mode.

### Core Components
| File | Size | Purpose |
|------|------|---------|
| `MythicPlusRunManager.cpp` | 89KB | Main run manager (2500+ lines) |
| `dc_mythic_spectator.cpp` | 50KB | Live spectator system |
| `npc_mythic_token_vendor.cpp` | 47KB | Token vendor UI |
| `MythicDifficultyScaling.cpp` | 14KB | Creature/boss scaling |
| `MythicPlusAffixes.cpp` | 6KB | Affix application |

---

## 🔴 Issues Found

### 1. **MythicPlusRunManager Too Large**
2500+ lines in single file violates single-responsibility:
- Boss tracking mixed with run management
- HUD caching in run manager
- Vault logic intermixed

**Recommendation:** Split into:
- `MythicPlusRunState.cpp` - Run state management
- `MythicPlusBossTracker.cpp` - Boss kill tracking
- `MythicPlusHUD.cpp` - HUD caching/sync
- `MythicPlusVaultIntegration.cpp` - Vault hooks

### 2. **Redundant Boss Detection Logic**
Two separate methods doing similar checks:
```cpp
bool IsRecognizedBoss(uint32 mapId, uint32 bossEntry);
bool IsBossCreature(const Creature* creature);
```
**Recommendation:** Consolidate into single method with caching.

### 3. **HUD Cache Table Created at Runtime**
```cpp
void EnsureHudCacheTable()
{
    CharacterDatabase.Execute("CREATE TABLE IF NOT EXISTS...");
}
```
**Recommendation:** Move to SQL migration scripts.

### 4. **Missing Affix Validation**
No validation that affix combinations are valid:
```cpp
// Could potentially have conflicting affixes
std::vector<uint8> activeAffixes;
```
**Recommendation:** Add affix compatibility matrix.

### 5. **Spectator Memory Leak**
```cpp
static std::unordered_map<ObjectGuid, SpectatorData> spectators;
// No cleanup when player disconnects during spectate
```

---

## 🟡 Improvements Suggested

### 1. **Affix Rotation System**
Current affixes appear random. Add rotation schedule:
```cpp
struct AffixRotation {
    uint32 weekNumber;
    std::array<uint8, 4> affixes; // tyrannical/fortified, level 7, level 14, level 21
};
```

### 2. **Smart Keystone Distribution**
- Track player completion rates per dungeon
- Prefer giving keystones for less-completed dungeons
- Avoid repeat keys for 3+ weeks

### 3. **Group Rating Display**
Show combined group rating before run starts:
- Average rating
- Highest/lowest member
- Predicted score range

### 4. **Death Counter Improvements**
- Track deaths by player
- Track deaths by boss
- Show "death tax" (time lost)

### 5. **Route Optimization Hints**
Track optimal trash kill routes and suggest to players.

---

## 🟢 Extensions Recommended

### 1. **Challenge Mode Modifiers**
Add optional difficulty modifiers:
- No Combat Rez
- Speed Run (50% timer)
- No Deaths (instant fail)
- Undergeared (max ilvl cap)

### 2. **Weekly Best Tracking**
```cpp
struct WeeklyBestRun {
    uint32 weekNumber;
    uint32 mapId;
    uint8 keystoneLevel;
    uint32 completionTime;
    uint32 score;
    std::array<uint32, 5> partyGuids;
};
```

### 3. **Dungeon Statistics**
Track per-dungeon:
- Average completion time
- Most common fail point
- Best affixes for each dungeon
- Class/spec success rates

### 4. **Mythic+ Tournaments**
Organized competition system:
- Weekly qualifier events
- Bracket-style playoffs
- Seasonal rankings

### 5. **Replay System**
Record and replay runs:
- Movement paths
- Combat logs
- Death locations

---

## 📊 Technical Upgrades

### Performance Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Run state update | ~10ms | <2ms |
| Spectator sync | ~50ms | <10ms |
| Boss check | ~5ms | <0.5ms |
| HUD update | ~20ms | <5ms |

### Recommended Architecture

```
MythicPlusCore
├── RunManager (state machine)
├── BossTracker (boss events)
├── ScoreCalculator (rating math)
├── AffixManager (affix logic)
├── SpectatorManager (live view)
├── VaultBridge (Great Vault integration)
└── AddonBridge (client sync)
```

### Database Optimization
```sql
-- Add composite indexes
ALTER TABLE dc_mplus_runs
ADD INDEX idx_player_season (player_guid, season_id),
ADD INDEX idx_map_level (map_id, keystone_level),
ADD INDEX idx_completion (completed_at);

ALTER TABLE dc_mplus_scores
ADD INDEX idx_season_score (season_id, best_score DESC);
```

---

## Integration Points

| System | Integration Type | Quality |
|--------|-----------------|---------|
| GreatVault | Run tracking | ⭐⭐⭐⭐⭐ |
| ItemUpgrades | Loot upgrades | ⭐⭐⭐⭐⭐ |
| Seasons | Seasonal scoring | ⭐⭐⭐⭐⭐ |
| AddonExtension | Full UI | ⭐⭐⭐⭐⭐ |
| CrossSystem | Event publishing | ⭐⭐⭐⭐ |
| Leaderboards | Score tracking | ⭐⭐⭐⭐⭐ |

---

## Priority Actions

1. **CRITICAL:** Split MythicPlusRunManager.cpp into smaller modules
2. **HIGH:** Fix spectator memory leak
3. **HIGH:** Consolidate boss detection
4. **MEDIUM:** Add affix validation
5. **MEDIUM:** Implement affix rotation
6. **LOW:** Add replay system
