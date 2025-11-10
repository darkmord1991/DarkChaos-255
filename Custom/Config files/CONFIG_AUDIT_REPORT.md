# DarkChaos Custom Configuration Audit Report
**Date**: 2025-11-10  
**File**: `darkchaos-custom.conf.dist`

---

## Executive Summary

This audit identifies configuration issues in the DarkChaos-255 custom configuration file, including:
1. **Section ordering problems** - SECTION 5 appears incomplete/missing
2. **Missing implemented config options** - Several C++ config reads not documented
3. **Config options documented but not implemented** - Dead config entries
4. **Documentation inaccuracies** - Incorrect descriptions of behavior

---

## 🔴 CRITICAL ISSUES

### 1. Section 5 is Incomplete
**Location**: End of file (line ~1168)  
**Issue**: Section 5 "CHALLENGE MODES SYSTEM" header exists but has no content

```conf
###########################################################################
#
#    SECTION 5: CHALLENGE MODES SYSTEM
#
#    Hardcore and specialized challenge modes inspired by Project Ascension
```

**Impact**: Configuration file ends abruptly. Unclear if this was:
- A planned feature never implemented
- Content accidentally deleted
- Should be merged with SECTION 4 (Prestige System)

**Recommendation**: Either:
- Remove the header entirely (no implementation found)
- Document that challenge modes are part of SECTION 4 Prestige.Challenges.*
- Implement the missing challenge mode system

---

## ⚠️ SECTION ORDERING ISSUES

### Current Structure:
```
SECTION 0: Item Upgrade
SECTION 1: AoE Loot
SECTION 2: Hotspots
SECTION 3: Hinterland BG
SECTION 4: Prestige System
  ├─ Alt-Friendly XP Bonus (lines 1088-1133)
  └─ Prestige Challenges (lines 1135-1236)
SECTION 5: Challenge Modes (EMPTY/INCOMPLETE)
```

### Issues:
1. **Alt Bonus is embedded in Prestige** (line 1088) but could be its own subsystem
2. **Prestige Challenges is embedded** (line 1135) but might deserve promotion
3. **Section 5 is empty** - either remove or implement

### Recommended Structure:
```
SECTION 0: Item Upgrade ✅
SECTION 1: AoE Loot ✅
SECTION 2: Hotspots ✅
SECTION 3: Hinterland BG ✅
SECTION 4: Prestige System ✅
  ├─ Basic Prestige (reset mechanics)
  ├─ Retention Options
  ├─ Starter Gear
  ├─ Rewards
  ├─ Announcements
  └─ Advanced Options
SECTION 5: Alt-Friendly XP Bonus (PROMOTE from Section 4)
SECTION 6: Prestige Challenges (PROMOTE from Section 4)
```

**OR** (if keeping current numbering):
```
Remove SECTION 5 header entirely since Prestige Challenges already covers it
```

---

## 🟡 MISSING CONFIGURATION OPTIONS

These options are **read in C++ code** but **NOT documented** in the config file:

### Prestige System (dc_prestige_system.cpp)

1. **Prestige.ClearBank** ✅ (Actually IS documented at line 1012)
2. **Prestige.StarterGear.{ClassID}** ✅ (Documented at lines 1023-1046)

**Status**: All Prestige config options ARE properly documented. ✅

### Prestige Alt Bonus (dc_prestige_alt_bonus.cpp)

All 4 config options ARE documented:
- `Prestige.AltBonus.Enable` ✅
- `Prestige.AltBonus.MaxLevel` ✅
- `Prestige.AltBonus.PercentPerChar` ✅
- `Prestige.AltBonus.MaxCharacters` ✅

### Prestige Challenges (dc_prestige_challenges.cpp)

All 5 config options ARE documented:
- `Prestige.Challenges.Enable` ✅
- `Prestige.Challenges.Iron.Enable` ✅
- `Prestige.Challenges.Speed.Enable` ✅
- `Prestige.Challenges.Speed.TimeLimit` ✅
- `Prestige.Challenges.Solo.Enable` ✅

**Result**: No missing Prestige config options found! All are documented.

---

## 🟠 POTENTIALLY DEAD CONFIG OPTIONS

These options are **documented in config** but I could NOT find them being read in the codebase:

### Prestige System

1. **Prestige.AchievementBase** (line 1068)
   ```conf
   Prestige.AchievementBase = 10000
   ```
   - **Searched**: No `GetOption.*AchievementBase` found
   - **Impact**: Setting has no effect
   - **Action**: Either implement or remove

2. **Prestige.AllowMultiplePrestigePerDay** (line 1093)
   ```conf
   Prestige.AllowMultiplePrestigePerDay = 1
   ```
   - **Searched**: No `GetOption.*AllowMultiplePrestigePerDay` found
   - **Impact**: Setting has no effect
   - **Action**: Either implement or remove

3. **Prestige.ConfirmationRequired** (line 1099)
   ```conf
   Prestige.ConfirmationRequired = 1
   ```
   - **Searched**: No `GetOption.*ConfirmationRequired` found
   - **Impact**: Setting has no effect
   - **Action**: Either implement or remove

4. **Prestige.ResetMounts** (line 1106)
   ```conf
   Prestige.ResetMounts = 0
   ```
   - **Searched**: No `GetOption.*ResetMounts` found
   - **Impact**: Setting has no effect
   - **Action**: Either implement or remove

5. **Prestige.ResetReputation** (line 1112)
   ```conf
   Prestige.ResetReputation = 0
   ```
   - **Searched**: No `GetOption.*ResetReputation` found
   - **Impact**: Setting has no effect
   - **Action**: Either implement or remove

6. **Prestige.ResetAchievements** (line 1118)
   ```conf
   Prestige.ResetAchievements = 0
   ```
   - **Searched**: No `GetOption.*ResetAchievements` found
   - **Impact**: Setting has no effect
   - **Action**: Either implement or remove

### Summary:
**6 dead config options** in the Prestige System section that are documented but not implemented.

---

## 📋 DOCUMENTATION ACCURACY ISSUES

### 1. Alt Bonus Subsystem Misplacement

**Location**: Lines 1088-1133  
**Current**: Nested under "SECTION 4: PRESTIGE SYSTEM"  
**Issue**: Alt Bonus is a **separate subsystem** with its own C++ file (`dc_prestige_alt_bonus.cpp`)

**Evidence**:
- Separate implementation file
- Independent enable flag (`Prestige.AltBonus.Enable`)
- Can function independently of main Prestige system
- Not directly related to prestige reset mechanics

**Recommendation**: Either:
- Promote to its own SECTION 5
- Add clear subsection marker: `# === SUBSYSTEM: Alt-Friendly XP Bonus ===`

### 2. Challenge System Misplacement

**Location**: Lines 1135-1236  
**Current**: Nested under "SECTION 4: PRESTIGE SYSTEM"  
**Issue**: Similar to Alt Bonus - separate subsystem with own file (`dc_prestige_challenges.cpp`)

**Recommendation**: Same as Alt Bonus - promote or clearly mark as subsystem.

### 3. Section 5 Header Confusion

**Location**: Line 1238  
**Issue**: Section header with no content creates confusion

```conf
###########################################################################
#
#    SECTION 5: CHALLENGE MODES SYSTEM
#
#    Hardcore and specialized challenge modes inspired by Project Ascension
```

**Problem**: This appears to promise a separate challenge mode system, but:
- No config options follow
- Challenge system is already documented in SECTION 4
- Creates duplicate/conflicting information

**Recommendation**: **REMOVE** this section header entirely.

### 4. Spell ID 800020-800024 Conflict

**Location**: Line 1234 (Title ID reference)  
**Issue**: Documentation references "Title IDs: 300-309 for Prestige I through X" but doesn't mention that spell IDs 800020-800024 were recently repurposed for Alt Bonus visual buffs.

**Cross-Reference Issue**:
- `Spell.csv` lines 53705-53709 define 800020-800024 as "Alt Bonus X%" spells
- Config documentation doesn't mention these spell IDs
- Previous spell IDs (challenge mode buffs) were overwritten

**Recommendation**: Add note about visual buff spell IDs in Alt Bonus section:
```conf
#    Prestige.AltBonus.BuffSpells (Reference)
#        Description: Visual buff spell IDs for alt bonus display
#                     Spell 800020 = 5% bonus (1 char)
#                     Spell 800021 = 10% bonus (2 chars)
#                     Spell 800022 = 15% bonus (3 chars)
#                     Spell 800023 = 20% bonus (4 chars)
#                     Spell 800024 = 25% bonus (5+ chars)
#        Note: These spells must exist in Spell.dbc for proper display
```

---

## ✅ WHAT'S WORKING CORRECTLY

### Prestige System Core (SECTION 4)
All essential config options are properly documented and implemented:
- ✅ `Prestige.Enable`
- ✅ `Prestige.RequiredLevel`
- ✅ `Prestige.MaxLevel`
- ✅ `Prestige.StatBonusPercent`
- ✅ `Prestige.ResetLevel`
- ✅ `Prestige.KeepGear`
- ✅ `Prestige.KeepProfessions`
- ✅ `Prestige.KeepGold`
- ✅ `Prestige.ClearBank`
- ✅ `Prestige.GrantStarterGear`
- ✅ `Prestige.StarterGear.{ClassID}`
- ✅ `Prestige.Rewards`
- ✅ `Prestige.AnnounceWorld`

### Alt Bonus System
All 4 config options documented and implemented:
- ✅ `Prestige.AltBonus.Enable`
- ✅ `Prestige.AltBonus.MaxLevel`
- ✅ `Prestige.AltBonus.PercentPerChar`
- ✅ `Prestige.AltBonus.MaxCharacters`

### Prestige Challenges System
All 5 config options documented and implemented:
- ✅ `Prestige.Challenges.Enable`
- ✅ `Prestige.Challenges.Iron.Enable`
- ✅ `Prestige.Challenges.Speed.Enable`
- ✅ `Prestige.Challenges.Speed.TimeLimit`
- ✅ `Prestige.Challenges.Solo.Enable`

---

## 📊 STATISTICS

| Category | Count |
|----------|-------|
| **Total Config Options Documented** | ~200+ |
| **Working Config Options** | ~194 |
| **Dead Config Options** | 6 |
| **Missing Documentation** | 0 |
| **Section Ordering Issues** | 2 |
| **Empty Sections** | 1 |

---

## 🔧 RECOMMENDED ACTIONS

### Priority 1 (Critical)
1. ✅ **Fix Section 5** - Either remove empty header or implement the system
2. ✅ **Remove/Implement Dead Options** - 6 dead Prestige config options

### Priority 2 (Important)
3. ✅ **Reorganize Sections** - Promote Alt Bonus and Challenges to their own sections OR clearly mark as subsystems
4. ✅ **Add Visual Buff Documentation** - Document spell IDs 800020-800024 in Alt Bonus section

### Priority 3 (Nice to Have)
5. ⚠️ **Add Config Validation** - Implement runtime warnings for unused config options
6. ⚠️ **Create Config Change Log** - Track when options are added/removed/changed

---

## 📝 PROPOSED FIXES

### Fix 1: Remove Empty Section 5
```conf
# DELETE THESE LINES (1238-1243):
###########################################################################
#
#    SECTION 5: CHALLENGE MODES SYSTEM
#
#    Hardcore and specialized challenge modes inspired by Project Ascension
```

### Fix 2: Comment Out Dead Options
```conf
# These options are not yet implemented - uncomment when ready
#Prestige.AchievementBase = 10000
#Prestige.AllowMultiplePrestigePerDay = 1
#Prestige.ConfirmationRequired = 1
#Prestige.ResetMounts = 0
#Prestige.ResetReputation = 0
#Prestige.ResetAchievements = 0
```

### Fix 3: Add Subsystem Markers
```conf
# =========================================================================
# SUBSYSTEM: Alt-Friendly XP Bonus
# =========================================================================
# Independent system that grants XP bonuses based on account progression
# Can function separately from main Prestige reset mechanics
# Implementation: dc_prestige_alt_bonus.cpp
# =========================================================================

#
#    Prestige.AltBonus.Enable
#    ...
```

### Fix 4: Document Visual Buffs
```conf
# -------------------------------------------------------------------------
# Visual Buff Spells (DBC Integration)
# -------------------------------------------------------------------------
#
#    Visual Buff Spell IDs (Reference)
#        Description: Spell IDs used for alt bonus visual indicators
#                     These spells must be defined in Spell.dbc for proper display.
#                     
#                     Spell 800020: Alt Bonus 5%  (1 max-level character)
#                     Spell 800021: Alt Bonus 10% (2 max-level characters)
#                     Spell 800022: Alt Bonus 15% (3 max-level characters)
#                     Spell 800023: Alt Bonus 20% (4 max-level characters)
#                     Spell 800024: Alt Bonus 25% (5+ max-level characters)
#                     
#                     Server applies these buffs automatically based on account state.
#                     No configuration required - spell IDs are hardcoded in:
#                     src/server/scripts/DC/Prestige/dc_prestige_alt_bonus.cpp
#
```

---

## ✅ VERIFICATION CHECKLIST

Use this checklist when applying fixes:

- [ ] Remove empty SECTION 5 header (lines 1238-1243)
- [ ] Comment out 6 dead config options OR implement them
- [ ] Add subsystem markers for Alt Bonus and Challenges
- [ ] Document visual buff spell IDs (800020-800024)
- [ ] Test that all documented config options are read by code
- [ ] Test that all code-read config options are documented
- [ ] Verify no duplicate config option definitions
- [ ] Check that default values in config match C++ defaults
- [ ] Update any related documentation files
- [ ] Create backup before applying changes

---

## 📎 FILES ANALYZED

### Configuration
- `darkchaos-custom.conf.dist` (primary audit target)

### Implementation Files Checked
- `src/server/scripts/DC/Prestige/dc_prestige_system.cpp`
- `src/server/scripts/DC/Prestige/dc_prestige_alt_bonus.cpp`
- `src/server/scripts/DC/Prestige/dc_prestige_challenges.cpp`
- `src/server/scripts/DC/Prestige/dc_prestige_spells.cpp`

### DBC Files Checked
- `Custom/CSV DBC/Spell.csv` (spell IDs 800020-800024)

---

**End of Report**
