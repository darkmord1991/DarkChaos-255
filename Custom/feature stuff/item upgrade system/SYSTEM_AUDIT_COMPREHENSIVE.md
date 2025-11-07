# 🔍 DC-ItemUpgrade System: COMPREHENSIVE AUDIT REPORT

**Date:** November 7, 2025  
**Status:** ⚠️ CRITICAL ISSUES FOUND - Multiple conflicting implementations & orphaned code  
**Severity:** HIGH - System has duplicate implementations with conflicting database schemas

---

## ⚠️ CRITICAL FINDINGS

### 1. **MULTIPLE CONFLICTING IMPLEMENTATIONS** 
The system has **AT LEAST 3 DIFFERENT ITEM UPGRADE IMPLEMENTATIONS** running simultaneously:

#### Implementation A: **ItemUpgradeAddonCommands** (ACTIVE - Current Focus)
- **File:** `ItemUpgradeCommands.cpp`
- **Purpose:** Simple item-based currency system
- **Tables Used:**
  - `dc_item_upgrade_state` (item upgrade progress)
  - `dc_item_upgrade_costs` (lookup for tier & level costs)
- **Currency:** Items 100998 & 100999 (from inventory)
- **Subcommands:** init, query, perform
- **Status:** ✅ Recently updated to item-based system

#### Implementation B: **ItemUpgradeProgressionImpl** (ACTIVE - CONFLICTING)
- **File:** `ItemUpgradeProgressionImpl.cpp` (~644 lines)
- **Purpose:** Advanced progression tracking with hardcoded test item IDs
- **Tables Used:**
  - `dc_player_upgrade_tokens` (DIFFERENT TABLE!)
  - Custom progression tracking
- **Currency:** Hardcoded items 900001 & 900002 (test items)
- **Subcommands:** Various progression commands
- **Status:** ⚠️ ACTIVE but using DIFFERENT database structure
- **Problem:** Uses DIFFERENT currency item IDs (900001, 900002 instead of 100998, 100999)

#### Implementation C: **Advanced/Professional System** (PARTIAL - UNUSED)
- **Files:** ItemUpgradeAdvancedImpl.cpp, ItemUpgradeMechanics.h, ItemUpgradeMechanicsImpl.cpp
- **Purpose:** Complex multi-tier system with synthesis, transmutation, tier conversion
- **Tables Used:**
  - `dc_item_upgrades` (different schema!)
  - `dc_item_upgrade_log`
  - `dc_item_upgrade_stat_scaling`
  - `dc_item_upgrade_synthesis_recipes`
  - `dc_item_upgrade_synthesis_inputs`
  - `dc_item_upgrade_synthesis_cooldowns`
  - `dc_item_upgrade_synthesis_log`
  - `dc_item_upgrade_transmutation_sessions`
  - `dc_item_upgrade_currency_exchange_log`
- **Status:** ⚠️ Compiled but may not be active/used

---

## 🗄️ DATABASE SCHEMA CHAOS

### Problem: Multiple Conflicting Table Schemas

#### **Current Active (ItemUpgradeCommands.cpp):**
```
dc_item_upgrade_state
├─ item_guid (INT UNSIGNED PRIMARY KEY)
├─ player_guid (INT UNSIGNED)
├─ tier (TINYINT)
├─ upgrade_level (TINYINT)
└─ tokens_invested (INT)

dc_item_upgrade_costs
├─ tier (TINYINT)
├─ upgrade_level (TINYINT)
├─ upgrade_tokens (INT)
└─ artifact_essence (INT)
```

#### **Phase 4A Schema (dc_item_upgrade_phase4a.sql - IN CONFLICT):**
```
dc_item_upgrades  ← DIFFERENT TABLE NAME!
├─ item_guid (INT PRIMARY KEY)
├─ player_guid (INT)
├─ upgrade_level (TINYINT)
├─ essence_invested (INT)
├─ tokens_invested (INT)
├─ base_item_level (SMALLINT)
├─ upgraded_item_level (SMALLINT)
├─ current_stat_multiplier (FLOAT)
└─ season_id (INT)

dc_item_upgrade_log
├─ log_id (INT AUTO_INCREMENT)
├─ player_guid (INT)
├─ item_guid (INT)
├─ upgrade_from/to (TINYINT)
├─ essence_cost (INT)
├─ token_cost (INT)
└─ timestamp (INT)

dc_item_upgrade_costs  ← DIFFERENT COLUMNS!
├─ tier_id (TINYINT PRIMARY KEY) ← ONLY tier_id, NO upgrade_level!
├─ tier_name (VARCHAR)
├─ base_essence_cost (FLOAT)
├─ base_token_cost (FLOAT)
├─ escalation_rate (FLOAT)
├─ cost_multiplier (FLOAT)
├─ stat_multiplier (FLOAT)
├─ ilvl_multiplier (FLOAT)
└─ max_upgrade_level (TINYINT)

dc_item_upgrade_stat_scaling
└─ Stat calculation config

```

#### **World Database Schemas (Multiple Files - CONFLICTING):**

**dc_item_upgrade_schema.sql (world):**
```
dc_item_upgrade_tiers
├─ tier_id (TINYINT PRIMARY KEY)
├─ tier_name (VARCHAR)
├─ min_ilvl, max_ilvl
├─ max_upgrade_level
└─ stat_multiplier_max

dc_item_upgrade_costs  ← AGAIN DIFFERENT!
├─ tier_id (TINYINT) ← No PK alone!
├─ upgrade_level (TINYINT) ← HAS THIS!
├─ token_cost (INT)
├─ essence_cost (INT)
├─ ilvl_increase (SMALLINT)
├─ stat_increase_percent (FLOAT)
└─ season (INT) ← PRIMARY KEY: (tier_id, upgrade_level, season)

dc_item_templates_upgrade
└─ Metadata about upgradeable items

dc_chaos_artifact_items
└─ Artifact-specific definitions
```

**dc_item_upgrade_costs.sql (world - simpler version):**
```
dc_item_upgrade_costs
├─ tier_id (TINYINT) ← No PRIMARY KEY spec in CREATE
├─ upgrade_level (TINYINT) ← Uses this for level
├─ token_cost (INT)
├─ essence_cost (INT)
└─ ... (75 INSERT statements)
```

---

## 🔴 IDENTIFIED CONFLICTS

### Conflict 1: Table Names
- **ItemUpgradeCommands.cpp** expects: `dc_item_upgrade_state`, `dc_item_upgrade_costs`
- **Phase 4A SQL** creates: `dc_item_upgrades` (different name!), `dc_item_upgrade_log`, `dc_item_upgrade_stat_scaling`
- **ItemUpgradeProgressionImpl** expects: `dc_player_upgrade_tokens`
- **Result:** ❌ Commands will fail if wrong tables exist

### Conflict 2: Cost Table Structure
- **ItemUpgradeCommands.cpp** queries: `WHERE tier = %u AND upgrade_level = %u` → expects columns `upgrade_tokens`, `artifact_essence`
- **Phase 4A SQL** creates: PRIMARY KEY `tier_id` ONLY → has columns `base_essence_cost`, `base_token_cost` (FLOAT!)
- **dc_item_upgrade_costs.sql** (world): Has tier_id + upgrade_level with INT values
- **Result:** ❌ Query will fail: column `upgrade_tokens` not in table

### Conflict 3: Currency Tracking
- **ItemUpgradeCommands.cpp:** Uses player inventory items (100998, 100999) via `GetItemCount()`
- **ItemUpgradeProgressionImpl:** Uses `dc_player_upgrade_tokens` table with DIFFERENT item IDs (900001, 900002)
- **Advanced System:** Uses additional tables for synthesis/transmutation
- **Result:** ❌ Multiple conflicting currency systems

### Conflict 4: Item IDs
- **ItemUpgradeCommands.cpp config:** `ItemUpgrade.Currency.EssenceId=100998`, `ItemUpgrade.Currency.TokenId=100999`
- **ItemUpgradeProgressionImpl hardcoded:** Lines 599-600: `essenceId=900001`, `tokenId=900002`
- **Result:** ❌ If both run, they reference different items

### Conflict 5: Database Location
- **setup_upgrade_costs.sql** (in Custom/) inserts into `dc_item_upgrade_costs` (assumes acore_world)
- **dc_item_upgrade_phase4a.sql** defines 4 different tables in CHARACTER database
- **dc_item_upgrade_costs.sql** (world) also defines `dc_item_upgrade_costs` (world)
- **Result:** ❌ Unclear which file should execute where

---

## 📋 TABLE INVENTORY

### Character Database (acore_characters)

| Table Name | Source File | Columns | Status | Used By |
|---|---|---|---|---|
| `dc_item_upgrade_currency` | addon_schema.sql | player_guid, currency_type, amount | ✅ Exists | OLD (not used in new code) |
| `dc_item_upgrade_state` | addon_schema.sql | item_guid, player_guid, tier, upgrade_level, tokens_invested, essence_invested, base_item_level, upgraded_item_level, stat_multiplier | ✅ Used | ItemUpgradeCommands.cpp ✓ |
| `dc_item_upgrades` | phase4a.sql | item_guid, player_guid, upgrade_level, essence_invested, tokens_invested, base_item_level, upgraded_item_level | ⚠️ MAY EXIST | Advanced system (?) |
| `dc_item_upgrade_log` | phase4a.sql | log_id, player_guid, item_guid, upgrade_from/to, essence_cost, token_cost | ⚠️ MAY EXIST | Advanced system (?) |
| `dc_item_upgrade_stat_scaling` | phase4a.sql | scaling_id, base_multiplier_per_level, enabled | ⚠️ MAY EXIST | Advanced system (?) |
| `dc_player_upgrade_tokens` | Unknown | player_guid, currency_type, amount, weekly_earned, season | ⚠️ ORPHANED | ItemUpgradeProgressionImpl ⚠️ |
| `dc_item_upgrade_synthesis_cooldowns` | transmutation_schema.sql | player_guid, recipe_id, cooldown_end | ⚠️ MAY EXIST | Synthesis system |
| `dc_item_upgrade_synthesis_log` | transmutation_schema.sql | player_guid, recipe_id, success, attempt_time | ⚠️ MAY EXIST | Synthesis system |
| `dc_item_upgrade_transmutation_sessions` | transmutation_schema.sql | session_id, player_guid, recipe_id, start_time, end_time, success | ⚠️ MAY EXIST | Transmutation system |
| `dc_item_upgrade_currency_exchange_log` | transmutation_schema.sql | exchange_id, player_guid, from_item_id, to_item_id, amount | ⚠️ MAY EXIST | Currency exchange (?) |

### World Database (acore_world)

| Table Name | Source File | Columns | Status | Used By |
|---|---|---|---|---|
| `dc_item_upgrade_costs` | dc_item_upgrade_costs.sql | tier_id, upgrade_level, token_cost, essence_cost, ilvl_increase, stat_increase_percent, season | ✅ Used | ItemUpgradeCommands.cpp ✓ |
| `dc_item_upgrade_tiers` | dc_item_upgrade_schema.sql | tier_id, tier_name, min_ilvl, max_ilvl, max_upgrade_level, stat_multiplier_max | ⚠️ MAY EXIST | ItemUpgradeManager.cpp |
| `dc_item_templates_upgrade` | dc_item_upgrade_schema.sql | item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id | ⚠️ MAY EXIST | Advanced system |
| `dc_chaos_artifact_items` | dc_item_upgrade_schema.sql | artifact_id, artifact_name, item_id, cosmetic_variant, rarity, location_name | ⚠️ MAY EXIST | Artifacts |
| `dc_item_upgrade_synthesis_recipes` | transmutation_schema.sql | recipe_id, recipe_name, input_item_id, output_item_id, cooldown_seconds | ⚠️ MAY EXIST | Synthesis |
| `dc_item_upgrade_synthesis_inputs` | transmutation_schema.sql | input_id, recipe_id, item_id, quantity | ⚠️ MAY EXIST | Synthesis |

---

## 🔧 C++ CODE ISSUES

### Issue 1: Query Mismatch in ItemUpgradeCommands.cpp

**Line 169:**
```cpp
QueryResult costResult = WorldDatabase.Query(
    "SELECT upgrade_tokens, artifact_essence FROM dc_item_upgrade_costs 
     WHERE tier = %u AND upgrade_level = %u",
    tier, targetLevel
);
```

**Problem:**
- Expects columns: `upgrade_tokens`, `artifact_essence`
- Actual columns in SQL: `token_cost`, `essence_cost`
- **Result:** ❌ Query will fail with "Unknown column 'upgrade_tokens'"

### Issue 2: ItemUpgradeProgressionImpl Hardcoded Test IDs

**Lines 599-600:**
```cpp
uint32 essenceId = 900001;  // Test item
uint32 tokenId = 900002;    // Test item
```

**Problem:**
- Should use config: `ItemUpgrade.Currency.EssenceId`, `ItemUpgrade.Currency.TokenId`
- Hardcoded to test item IDs instead of production IDs (100998, 100999)
- **Result:** ⚠️ Duplicate/competing system with different items

### Issue 3: Currency Table Doesn't Exist in ItemUpgradeCommands

**Expected by code:** Uses inventory items directly (`GetItemCount()`)  
**Actual database:** `dc_item_upgrade_currency` table exists but is NOT queried by this code  
**Result:** ⚠️ Orphaned table - either use it or delete it

### Issue 4: Multiple SQL File Conflicts

**Character Database Setup:**
- `dc_item_upgrade_addon_schema.sql` - Simple schema (100 lines)
- `dc_item_upgrade_phase4a.sql` - Advanced schema (221 lines)
- Both define different table structures!
- **Which one should execute?** Unknown.

**World Database Setup:**
- `dc_item_upgrade_costs.sql` - Simple costs (75 INSERTs)
- `dc_item_upgrade_schema.sql` - Complex schema with 4 tables
- **Which one should execute?** Unknown.

---

## ✅ RECOMMENDATIONS

### Priority 1: IMMEDIATE CLEANUP

#### Action 1.1: Choose ONE Implementation
```
Option A (Recommended - SIMPLE):
├─ Keep: ItemUpgradeCommands.cpp (simple, uses items)
├─ Keep: setup_upgrade_costs.sql (75 entries, clear structure)
├─ Keep: dc_item_upgrade_addon_schema.sql (minimal tables)
└─ DELETE: Phase 4A SQL, advanced implementations

Option B (Complex - NOT RECOMMENDED):
├─ Keep: Advanced system (Phase 4A + synthesis + transmutation)
├─ DELETE: ItemUpgradeCommands.cpp (too simple)
└─ Rewrite: Everything to use new schema
```

**CURRENT STATUS:** Option A is 90% done, but conflicting files remain.

#### Action 1.2: Fix Column Names
**File:** `ItemUpgradeCommands.cpp` Line 169  
**Current:**
```cpp
"SELECT upgrade_tokens, artifact_essence FROM dc_item_upgrade_costs ..."
```
**Must be:**
```cpp
"SELECT token_cost, essence_cost FROM dc_item_upgrade_costs ..."
```

#### Action 1.3: Remove ItemUpgradeProgressionImpl Hardcoded IDs
**File:** `ItemUpgradeProgressionImpl.cpp` Lines 599-600  
**Current:**
```cpp
uint32 essenceId = 900001;
uint32 tokenId = 900002;
```
**Should be:**
```cpp
uint32 essenceId = sConfigMgr->GetOption<uint32>("ItemUpgrade.Currency.EssenceId", 100998);
uint32 tokenId = sConfigMgr->GetOption<uint32>("ItemUpgrade.Currency.TokenId", 100999);
```

### Priority 2: ORGANIZE DATABASE FILES

#### Create One Authoritative Setup Script
**File:** `Custom/setup_itemupgrade_complete.sql`
```sql
-- ============================================
-- CHARACTERS DATABASE
-- ============================================
USE acore_characters;

-- Simple state tracking
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_state` (...);

-- ============================================
-- WORLD DATABASE
-- ============================================
USE acore_world;

-- Cost definitions
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_costs` (...);
```

**Then DELETE these conflicting files:**
- `Custom/Custom feature SQLs/chardb/ItemUpgrades/dc_item_upgrade_phase4a.sql` ← DELETE
- `Custom/Custom feature SQLs/chardb/ItemUpgrades/item_upgrade_transmutation_characters_schema.sql` ← DELETE
- `Custom/Custom feature SQLs/worlddb/ItemUpgrades/dc_item_upgrade_schema.sql` ← DELETE
- `Custom/Custom feature SQLs/worlddb/ItemUpgrades/item_upgrade_transmutation_schema.sql` ← DELETE

### Priority 3: IDENTIFY ACTIVE SCRIPTS
Determine which of these are ACTUALLY COMPILED AND RUNNING:
- ItemUpgradeManager.cpp (✓ Referenced)
- ItemUpgradeAdvancedImpl.cpp (✓ In CMakeLists.txt)
- ItemUpgradeSynthesisImpl.cpp (✓ In CMakeLists.txt)
- ItemUpgradeTierConversionImpl.cpp (✓ In CMakeLists.txt)
- ItemUpgradeTransmutationImpl.cpp (✓ In CMakeLists.txt)
- ItemUpgradeProgressionImpl.cpp (✓ In CMakeLists.txt - **HAS HARDCODED IDS**)

**Action:** Verify which are ACTUALLY NEEDED or if they're legacy code.

### Priority 4: VALIDATE SQL SCHEMAS
```sql
-- After setup, run diagnostics:
SHOW TABLES LIKE 'dc_item_upgrade%';
SHOW COLUMNS FROM dc_item_upgrade_state;
SHOW COLUMNS FROM dc_item_upgrade_costs;
SELECT COUNT(*) FROM dc_item_upgrade_costs;
```

**Expected Output:**
```
dc_item_upgrade_state     ← Item progress tracking
dc_item_upgrade_costs     ← Cost lookup (75 rows)
```

**Should NOT exist (if using simple approach):**
```
dc_item_upgrades          ← Delete if exists
dc_item_upgrade_log       ← Delete if exists
dc_player_upgrade_tokens  ← Delete if exists (orphaned)
```

---

## 📊 INVENTORY SUMMARY

### SQL Files to Review/Delete
- ❌ `dc_item_upgrade_phase4a.sql` - Conflicts with simple schema
- ❌ `dc_item_upgrade_schema.sql` (world) - Advanced schema, confusing
- ❌ `item_upgrade_transmutation_characters_schema.sql` - Extra features
- ❌ `item_upgrade_transmutation_schema.sql` (world) - Extra features
- ✅ `setup_upgrade_costs.sql` - Use this (75 entries, clear)
- ✅ `dc_item_upgrade_addon_schema.sql` - Use this (simple)

### C++ Files with Issues
- ⚠️ `ItemUpgradeCommands.cpp` - Column name mismatch (easy fix)
- ⚠️ `ItemUpgradeProgressionImpl.cpp` - Hardcoded item IDs (easy fix)
- ❓ `ItemUpgradeManager.cpp` - Unclear if used
- ❓ `ItemUpgradeAdvancedImpl.cpp` - Unclear if used
- ❓ `ItemUpgradeSynthesisImpl.cpp` - Extra features, possibly orphaned
- ❓ `ItemUpgradeTierConversionImpl.cpp` - Extra features, possibly orphaned
- ❓ `ItemUpgradeTransmutationImpl.cpp` - Extra features, possibly orphaned

### Configuration
- ✅ `acore.conf` - Has correct item IDs (100998, 100999)
- ⚠️ `ItemUpgradeProgressionImpl.cpp` - Ignores config, uses hardcoded (900001, 900002)

---

## 🎯 IMMEDIATE ACTION ITEMS

### Task 1: Fix Column Mismatch ⚠️ CRITICAL
```cpp
// File: ItemUpgradeCommands.cpp, Line 169
// BEFORE:
"SELECT upgrade_tokens, artifact_essence FROM dc_item_upgrade_costs ..."

// AFTER:
"SELECT token_cost, essence_cost FROM dc_item_upgrade_costs ..."
```
**Time:** 2 minutes  
**Impact:** ✅ Fixes runtime error

### Task 2: Remove Hardcoded IDs ⚠️ CRITICAL
```cpp
// File: ItemUpgradeProgressionImpl.cpp, Lines 599-600
// BEFORE:
uint32 essenceId = 900001;
uint32 tokenId = 900002;

// AFTER:
uint32 essenceId = sConfigMgr->GetOption<uint32>("ItemUpgrade.Currency.EssenceId", 100998);
uint32 tokenId = sConfigMgr->GetOption<uint32>("ItemUpgrade.Currency.TokenId", 100999);
```
**Time:** 2 minutes  
**Impact:** ✅ Unifies currency system

### Task 3: Create Consolidated Setup Script 📋 IMPORTANT
**File:** Create `Custom/ITEMUPGRADE_FINAL_SETUP.sql`
- Consolidates all necessary CREATE TABLE and INSERT statements
- References only `dc_item_upgrade_addon_schema.sql` schema
- Uses `setup_upgrade_costs.sql` data
- Has clear comments about what runs where
**Time:** 15 minutes  
**Impact:** ✅ Single source of truth

### Task 4: Backup & Archive Old Files 🗂️ CLEANUP
**Delete/Archive:**
- `dc_item_upgrade_phase4a.sql`
- `dc_item_upgrade_schema.sql` (world)
- `item_upgrade_transmutation_characters_schema.sql`
- `item_upgrade_transmutation_schema.sql` (world)

**Save copies:**
- Move to `Custom/ARCHIVE/ItemUpgrade_OldImplementations/`
- Add README explaining why archived

**Time:** 10 minutes  
**Impact:** ✅ Reduces confusion

---

## 📝 AUDIT CHECKLIST

- [ ] Review ItemUpgradeCommands.cpp column names vs. actual table columns
- [ ] Remove hardcoded item IDs from ItemUpgradeProgressionImpl.cpp
- [ ] Verify which C++ files are actually USED (not just compiled)
- [ ] Create single consolidated SQL setup file
- [ ] Document which SQL files should execute where (characters vs. world)
- [ ] Test: Run setup script and verify table structures match code
- [ ] Test: Run `/dcupgrade init` command and verify it doesn't error
- [ ] Archive old/conflicting SQL files
- [ ] Update documentation to reflect final system architecture

---

## CONCLUSION

**System Status:** ⚠️ **FUNCTIONAL BUT CHAOTIC**

The simple item-based system (ItemUpgradeCommands.cpp) is close to working, but:
1. ❌ Has column name mismatch with database
2. ❌ Competing implementations with hardcoded IDs
3. ❌ Multiple conflicting SQL schemas in Custom folder
4. ❌ Unclear which files are actually used vs. legacy

**Estimated Time to Full Cleanup:** 30-45 minutes  
**Estimated Time to Stability:** 60-90 minutes (including testing)

**Recommendation:** Follow Task 1-4 above to unify and stabilize the system.

