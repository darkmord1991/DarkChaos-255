# DC Remaining Systems Evaluation
## 2026 Improvements Analysis

**Systems Covered:** GiantIsles, GreatVault, ChallengeMode, DungeonQuests, GOMove, Gilneas, Jadeforest, AC, AIO, Achievements, FirstStart, PhasedDuels, Teleporters, Commands, Shared
**Last Analyzed:** January 1, 2026

---

## GiantIsles (8 files, 252KB)

### Overview
Custom zone with world bosses (Oondasta, Thok, Nalak) and invasion events.

### Issues
- `dc_giant_isles_invasion.cpp` is 108KB (too large)
- Boss scripts have similar patterns - could use base class

### Improvements
- Add invasion difficulty scaling
- Add invasion timer UI via addon
- Add loot tables progression

### Priority: **MEDIUM** - Split invasion.cpp

---

## GreatVault (4 files, 18KB)

### Overview
Weekly vault reward system for M+ and other activities.

### Issues
- Minimal implementation
- `GreatVaultUtils.h` is nearly empty (144 bytes)

### Improvements
- Add vault preview UI
- Add token exchange for unwanted items
- Add vault history tracking

### Priority: **LOW** - Expand functionality

---

## ChallengeMode (7 files, 137KB)

### Overview
Equipment restrictions and challenge enforcement.

### Issues
- `dc_challenge_modes_customized.cpp` is 80KB (needs split)
- Enforcement logic spread across files

### Improvements
- Add custom challenge creation
- Add challenge leaderboards
- Add challenge achievements

### Priority: **MEDIUM** - Refactor large file

---

## DungeonQuests (8 files, 100KB)

### Overview
Daily/weekly dungeon quest system with token rewards.

### Issues
- Token config spread across files
- Phasing implementation complex

### Improvements
- Add quest chain support
- Add bonus objectives
- Add mythic quest variants

### Priority: **LOW** - Well structured

---

## GOMove (4 files, 20KB)

### Overview
GameObject movement system for GMs.

### Issues
- Limited documentation
- No undo functionality

### Improvements
- Add undo/redo stack
- Add bulk operations
- Add position presets

### Priority: **LOW** - Niche feature

---

## Gilneas (3 files, 45KB)

### Overview
Battle for Gilneas battleground implementation.

### Issues
- Standard BG approach
- Minimal unique features

### Improvements
- Add unique mechanics
- Add capture point variants
- Add seasonal themes

### Priority: **LOW** - Stable

---

## Jadeforest (2 files, 6KB)

### Overview
Basic zone scripts (flightmaster, guards).

### Issues
- Very minimal implementation
- No zone-specific content

### Improvements
- Add zone events
- Add custom NPCs
- Add questlines

### Priority: **LOW** - Needs content design first

---

## AC (3 files, 28KB)

### Overview
AzerothCore base scripts (flightmasters, guards, quest NPC).

### Issues
- Files prefixed "ac_" but in DC folder

### Improvements
- Rename or move to appropriate location
- Document AC vs DC distinction

### Priority: **LOW** - Organizational

---

## AIO (1 file, 4KB)

### Overview
AIO addon bridge for legacy support.

### Issues
- Minimal - just bridge code

### Improvements
- Consider deprecation if AIO unused
- Document AIO requirements

### Priority: **LOW** - May be obsolete

---

## Achievements (1 file, 20KB)

### Overview
Custom achievement handling.

### Issues
- Single file handling everything

### Improvements
- Split by achievement category
- Add custom achievement creation
- Add progressive achievements

### Priority: **LOW** - Works as-is

---

## FirstStart (1 file, 25KB)

### Overview
New player experience handling.

### Issues
- Coupled with starting zone selection

### Improvements
- Add tutorial quests
- Add UI onboarding
- Add class-specific starts

### Priority: **MEDIUM** - New player experience critical

---

## PhasedDuels (1 file, 22KB)

### Overview
Phased dueling arena system.

### Issues
- No spectator support
- Limited arena options

### Improvements
- Add spectator mode
- Add arena variants
- Add ranked dueling

### Priority: **LOW** - Niche feature

---

## Teleporters (1 file, 8KB)

### Overview
Teleporter NPC scripts.

### Issues
- Locations hardcoded

### Improvements
- Database-driven locations
- Add permission levels
- Add cooldowns

### Priority: **LOW** - Simple system

---

## Commands (2 files, 43KB)

### Overview
GM command implementations.

### Issues
- Commands spread between files
- Some commands in other system files

### Improvements
- Centralize all DC commands
- Add command documentation
- Add permission matrix

### Priority: **LOW** - Works as-is

---

## Shared (Empty folder)

### Issues
- Empty folder with no files
- Intended for shared utilities

### Improvements
- Move common utilities here
- Create shared type definitions
- Add documentation

### Priority: **HIGH** - Use for refactoring shared code

---

## Root Files Summary

| File | Size | Status |
|------|------|--------|
| `dc_script_loader.cpp` | 50KB | OK - Just registrations |
| `ac_aoeloot.cpp` | 38KB | ⚠️ DUPLICATE - See EVAL_AoELoot.md |
| `dc_aoeloot_extensions.cpp` | 38KB | ⚠️ DUPLICATE - See EVAL_AoELoot.md |
| `heirloom_scaling_255.cpp` | 11KB | OK |
| `dc_login_announce.cpp` | 2KB | OK |
| `go_heirloom_cache.cpp` | 2KB | OK |
| `dc_challenge_modes_loader.cpp` | 1KB | OK |

---

## Cross-Cutting Issues Identified

### 1. **Naming Inconsistency**
- `ac_*` vs `dc_*` prefix confusion
- Some files use underscores, others use CamelCase

### 2. **Empty Shared Folder**
- Should contain common utilities
- Currently utilities duplicated across files

### 3. **No Consistent Code Style**
- Some files have extensive documentation
- Others have minimal comments

### 4. **Test Coverage**
- Only one test file found (`SeasonalSystemTest.cpp`)
- No unit tests for most systems

---

## Priority Actions Summary

1. **CRITICAL:** Split `dc_giant_isles_invasion.cpp` (108KB)
2. **CRITICAL:** Split `dc_challenge_modes_customized.cpp` (80KB)  
3. **HIGH:** Populate Shared folder with common utilities
4. **MEDIUM:** Improve FirstStart experience
5. **LOW:** All other systems working as-is
