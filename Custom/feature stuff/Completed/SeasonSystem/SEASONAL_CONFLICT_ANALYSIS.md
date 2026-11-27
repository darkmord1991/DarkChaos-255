# Seasonal System Conflict Analysis & Resolution

> Historical note: this analysis captured the 2025 pre-consolidation state.
> HLBG no longer registers `HLBGSeasonalParticipant`, and the legacy HLBG
> season/archive tables referenced below were retired on 2026-05-23.

## Critical Issues Found

### 1. **DUPLICATE SEASONAL SYSTEMS** ⚠️
Two separate seasonal frameworks exist:
- `SeasonalSystem.h/.cpp` (DarkChaos::Seasonal - Generic framework for all systems)
- `SeasonalRewardSystem.h/.cpp` (DarkChaos::SeasonalRewards - Specific reward implementation)

**Problem:** These are separate systems that don't integrate with each other!

### 2. **M+ System Has Own Season Management** ⚠️
- `MythicPlusRunManager.cpp` has `GetCurrentSeasonId()`, `IsDungeonFeaturedThisSeason()`, season_id tracking
- `MythicDifficultyScaling.cpp` loads from `dc_mplus_seasons` table
- **Does NOT use** either SeasonalSystem or SeasonalRewardSystem

### 3. **Item Upgrade System Has Hardcoded Seasons** ⚠️
- `ItemUpgradeMechanicsImpl.cpp`: `Mechanics_GetCurrentSeason()` returns hardcoded `1`
- Comment: `// TODO: wire to seasons DB`
- Uses `season` field in upgrade states but not connected to seasonal framework

### 4. **HLBG System Had Separate Season Tracking** ⚠️
- Historical implementation: `HLBGSeasonalParticipant.cpp` implemented `SeasonalParticipant`
- Historical implementation used generic `SeasonalSystem`
- Historical implementation did not integrate with `SeasonalRewardSystem`
- Legacy tables `dc_hlbg_player_season_data`, `dc_hlbg_player_history`, `dc_hlbg_match_history`, and `dc_hlbg_season_config` were retired on 2026-05-23

### 5. **Obsolete Eluna Scripts** ⚠️
Four deprecated scripts still exist:
- `SeasonalRewards.lua` (450 lines) - Replaced by C++ SeasonalRewardSystem
- `SeasonalCommands.lua` (350 lines) - Replaced by C++ SeasonalRewardCommands
- `SeasonalCaps.lua` (300 lines) - Replaced by C++ cap management
- `SeasonalIntegration.lua` (250 lines) - Replaced by C++ hooks

### 6. **Database Table Conflicts** ⚠️
Multiple season-related tables with overlapping purposes:
- `dc_seasons` (Generic seasonal system)
- `dc_mplus_seasons` (M+ specific)
- `dc_player_seasonal_stats` (Reward system)
- `dc_hlbg_player_season_data` (HLBG specific)
- `dc_weekly_vault` (M+ weekly rewards)
- `dc_player_seasonal_chests` (Seasonal reward weekly chests)

## Proposed Solution

### Unified Architecture

```
DarkChaos::Seasonal (Core Framework)
└─ SeasonalManager (Generic season management)
   ├─ RegisterSystem("rewards") → SeasonalRewardSystem
   ├─ RegisterSystem("mythic_plus") → MythicPlusSeasonalParticipant  
   ├─ RegisterSystem("item_upgrades") → ItemUpgradeSeasonalParticipant
  └─ RegisterSystem("hlbg") → HLBGSeasonalParticipant (historical, now removed)
```

### Implementation Plan

#### Phase 1: Make SeasonalRewardSystem Use Generic Framework ✅ COMPLETE
- ✅ Change `SeasonalRewardSystem` to implement `SeasonalParticipant` interface
- ✅ Register with `SeasonalManager` during initialization
- ✅ Use `GetSeasonalManager()->GetCurrentSeasonId()` instead of config
- ✅ Keep reward-specific logic (tokens, essence, caps, chests)

#### Phase 2: Integrate M+ System ✅ COMPLETE
- ✅ Create `MythicPlusSeasonalIntegration.cpp`
- ✅ Make `MythicDifficultyScaling` use `SeasonalManager`
- ✅ Redirect `GetCurrentSeasonId()` to generic framework
- ✅ Keep M+ specific logic (affixes, scaling, vault)

#### Phase 3: Integrate Item Upgrade System ✅ COMPLETE
- ✅ Remove hardcoded season ID
- ✅ Wire `Mechanics_GetCurrentSeason()` to `SeasonalManager`
- ✅ Register as seasonal participant if needed

#### Phase 4: Consolidate Weekly Systems ✅ COMPLETE
- ✅ Create unified `dc_player_weekly_rewards` table
- ✅ Migrate M+ weekly vault data
- ✅ Migrate seasonal rewards chest data
- ✅ Create backward compatibility views
- ✅ Archive old tables for rollback safety

#### Phase 5: Delete Obsolete Files ✅ COMPLETE
- ✅ Remove 4 deprecated Eluna scripts
- ✅ Clean up old documentation references

#### Phase 6: Database Consolidation ✅ COMPLETE
- ✅ Add `season_type` column to dc_seasons
- ✅ Migrate dc_mplus_seasons → dc_seasons
- ✅ Create unified weekly reward tracking
- ✅ Update foreign key references
- ✅ Preserve backward compatibility via SQL views

## Benefits of Unified System

1. **Single Source of Truth** - One season ID for all systems
2. **Coordinated Transitions** - All systems transition together
3. **Shared Reset Logic** - Weekly resets coordinated
4. **Simplified Admin** - One set of season management commands
5. **No Conflicts** - M+ Season 1 = Reward Season 1 = Item Upgrade Season 1

## Database Schema Consolidation

### Unified Database Structure ✅ IMPLEMENTED

#### Master Season Table (Enhanced)
```sql
dc_seasons
  - season_id (PK)
  - season_name
  - season_type ('global', 'mythic_plus', 'pvp', 'rewards', 'hlbg')
  - season_state (0=Inactive, 1=Active, 2=Transitioning, 3=Maintenance)
  - start_timestamp, end_timestamp
  - custom_properties (JSON - system-specific config)
```

#### Unified Weekly Rewards Table (New)
```sql
dc_player_weekly_rewards
  - id (PK)
  - character_guid, season_id, week_start
  - system_type ('mythic_plus', 'seasonal_rewards', 'pvp', 'hlbg')
  - mplus_runs_completed, mplus_highest_level
  - tokens_earned, essence_earned
  - slot1/2/3_unlocked, slot1/2/3_tokens, slot1/2/3_essence, slot1/2/3_item_ilvl
  - reward_claimed, claimed_slot, claimed_tokens, claimed_at
```

#### Backward Compatibility Views
```sql
-- Old M+ code continues to work
CREATE VIEW dc_weekly_vault AS 
  SELECT * FROM dc_player_weekly_rewards WHERE system_type = 'mythic_plus';

-- Old reward code continues to work  
CREATE VIEW dc_player_seasonal_chests AS
  SELECT * FROM dc_player_weekly_rewards WHERE system_type = 'seasonal_rewards';
```

#### Archived Tables (Rollback Safety)
- `dc_mplus_seasons_archived_20251122` (old M+ seasons)
- `dc_weekly_vault_archived_20251122` (old M+ vault)
- `dc_player_seasonal_chests_archived_20251122` (old reward chests)

### Migration Benefits
1. **Single weekly reset logic** - All systems reset together
2. **Cross-system rewards** - M+ tokens + seasonal essence in same vault
3. **Reduced database fragmentation** - One table vs three
4. **Easier admin management** - Unified season commands
5. **Zero downtime** - Views maintain backward compatibility

## Configuration Changes

### Before (Fragmented)
```ini
SeasonalRewards.ActiveSeasonID = 1
MythicPlus.ActiveSeasonID = 1  # Different config key!
ItemUpgrades.Season = 1  # Hardcoded!
HLBG.SeasonID = 1  # Another config key!
```

### After (Unified) ✅ IMPLEMENTED
```ini
DarkChaos.ActiveSeasonID = 1  # Single source of truth
SeasonalRewards.ActiveSeasonID = 1  # Backward compatibility (deprecated)
# All systems read from DarkChaos.ActiveSeasonID OR from dc_seasons table via SeasonalManager
```

## Code Changes Summary

### Files Modified ✅ COMPLETE
1. ✅ `SeasonalRewardSystem.h` - Implements SeasonalParticipant interface
2. ✅ `SeasonalRewardSystem.cpp` - Interface methods + SeasonalManager integration
3. ✅ `SeasonalRewardScripts.cpp` - Registers with SeasonalManager on startup
4. ✅ `MythicDifficultyScaling.cpp` - Uses SeasonalManager with fallback
5. ✅ `ItemUpgradeMechanicsImpl.cpp` - Wired to SeasonalManager
6. ✅ `darkchaos-custom.conf.dist` - Added DarkChaos.ActiveSeasonID unified config

### Files Created ✅ COMPLETE
1. ✅ `MythicPlusSeasonalIntegration.cpp` - M+ seasonal helper (added to CMakeLists.txt)
2. ✅ `SEASONAL_CONFLICT_ANALYSIS.md` - This analysis document

### Files Deleted ✅ COMPLETE
1. ✅ `Custom/Eluna scripts/SeasonalRewards.lua` (450 lines)
2. ✅ `Custom/Eluna scripts/SeasonalCommands.lua` (350 lines)
3. ✅ `Custom/Eluna scripts/SeasonalCaps.lua` (300 lines)
4. ✅ `Custom/Eluna scripts/SeasonalIntegration.lua` (250 lines)

## Migration Path

### Step 1: Backup Current System
```sql
-- Backup season data from all systems
CREATE TABLE dc_seasons_backup AS SELECT * FROM dc_seasons;
CREATE TABLE dc_mplus_seasons_backup AS SELECT * FROM dc_mplus_seasons;
```

### Step 2: Deploy Unified Code
- Rebuild with integrated seasonal system
- Keep backward compatibility during transition

### Step 3: Migrate Data
```sql
-- Ensure all systems use same season ID
UPDATE dc_player_seasonal_stats SET season_id = 1;
UPDATE dc_mplus_runs SET season_id = 1;
-- Historical example before HLBG unified-table migration:
-- UPDATE dc_hlbg_player_season_data SET season_id = 1;
```

### Step 4: Remove Old Scripts
```powershell
Remove-Item "Custom/Eluna scripts/Seasonal*.lua"
```

### Step 5: Test Integration
- Verify all systems read same season ID
- Test season transitions
- Confirm weekly resets coordinate

## Risk Assessment

### LOW RISK ✅
- Deleting obsolete Eluna scripts (C++ already handles)
- Wiring ItemUpgrades to SeasonalManager (simple function redirect)
- Configuration consolidation (backward compatible)

### MEDIUM RISK ⚠️
- Integrating M+ system (active production system)
- Merging weekly vault systems (data loss risk)
- Database schema changes (require careful migration)

### HIGH RISK 🔴
- Changing active season IDs (can break player progress)
- Modifying core SeasonalSystem (affects multiple systems)

## Recommended Approach

1. **Phase 1 (Safe):** Delete obsolete Eluna scripts ✅
2. **Phase 2 (Safe):** Wire ItemUpgrades to SeasonalManager ✅
3. **Phase 3 (Medium):** Integrate M+ system ✅
4. **Phase 4 (Medium):** Make SeasonalRewardSystem use generic framework ✅
5. **Phase 5 (Low):** Consolidate configuration ✅
6. **Phase 6 (High):** Merge weekly systems (future enhancement) 🔮

## Immediate Actions Required

### Critical (Do Now) ✅ ALL COMPLETE
1. ✅ Delete 4 obsolete Eluna scripts
2. ✅ Wire ItemUpgrades `Mechanics_GetCurrentSeason()` to SeasonalManager
3. ✅ Document the dual-framework situation
4. ✅ Add integration layer between SeasonalRewardSystem and SeasonalManager

### Important (Do Soon) ✅ ALL COMPLETE
5. ✅ Create MythicPlusSeasonalIntegration helper
6. ✅ Integrate M+ GetCurrentSeasonId() with SeasonalManager
7. ✅ Consolidate configuration keys (DarkChaos.ActiveSeasonID)
8. ✅ Make SeasonalRewardSystem implement SeasonalParticipant
9. ✅ Register SeasonalRewardSystem with SeasonalManager

### Optional (Future) ✅ ALL COMPLETE
10. ✅ Merge weekly vault systems (M+ vault + seasonal chests) - IMPLEMENTED
11. ✅ Consolidate database tables (dc_mplus_seasons → dc_seasons) - IMPLEMENTED
12. ⏳ Unified admin interface for season management (future enhancement)
13. ⏳ Cross-system season transition validation (future enhancement)

---

**Status:** ✅ **FULL IMPLEMENTATION COMPLETE** - All critical, important, AND database consolidation finished!

**Database Migration:** Run `02_CONSOLIDATE_SEASONS_DATABASE.sql` to merge tables (rollback available via `03_ROLLBACK_CONSOLIDATION.sql`)

**Remaining Work:** Optional unified admin UI and cross-system validation (cosmetic improvements).
