# 📋 Item Upgrade System - Table Cleanup Analysis

**Date:** November 17, 2025  
**Issue:** SQL error when modifying primary key - auto_increment column must be in key

---

## ❌ SQL ERROR RESOLVED

### Problem:
```sql
ALTER TABLE `dc_item_upgrade_costs` DROP PRIMARY KEY;
/* SQL-Fehler (1075): Incorrect table definition; 
   there can be only one auto column and it must be defined as a key */
```

### Root Cause:
- `cost_id` column is AUTO_INCREMENT
- MySQL requires AUTO_INCREMENT columns to be part of a key (PRIMARY or INDEX)
- Cannot drop PRIMARY KEY while `cost_id` has AUTO_INCREMENT

### Solution Applied:
```sql
-- Step 1: Remove AUTO_INCREMENT from cost_id first
ALTER TABLE `dc_item_upgrade_costs` MODIFY `cost_id` INT UNSIGNED NOT NULL;

-- Step 2: Now safe to drop old primary key
ALTER TABLE `dc_item_upgrade_costs` DROP PRIMARY KEY;

-- Step 3: Add new composite primary key
ALTER TABLE `dc_item_upgrade_costs` 
    ADD PRIMARY KEY (`tier_id`, `upgrade_level`, `season`);

-- Step 4: Drop cost_id since it's no longer needed
ALTER TABLE `dc_item_upgrade_costs` DROP COLUMN `cost_id`;
```

---

## 🗄️ DATABASE TABLE INVENTORY

### ✅ REQUIRED TABLES (Keep - Currently Used)

#### **World Database (acore_world):**

| Table | Purpose | Status | Used By |
|-------|---------|--------|---------|
| `dc_item_upgrade_costs` | Upgrade cost matrix (tier, level, costs) | ✅ ACTIVE | ItemUpgradeManager.cpp |
| `dc_item_templates_upgrade` | Maps items to tiers/metadata | ✅ ACTIVE | ItemUpgradeManager.cpp |
| `dc_chaos_artifact_items` | Artifact definitions | ✅ ACTIVE | ItemUpgradeManager.cpp |
| `dc_item_proc_spells` | Proc effects for upgraded items | ✅ ACTIVE | ItemUpgradeProcs.cpp |

#### **Character Database (acore_characters):**

| Table | Purpose | Status | Used By |
|-------|---------|--------|---------|
| `dc_player_item_upgrades` | Item upgrade state (RENAMED from dc_item_upgrade_state) | ✅ ACTIVE | ItemUpgradeManager.cpp |
| `dc_player_upgrade_tokens` | Player currency balances | ✅ ACTIVE | ItemUpgradeCommands.cpp |
| `dc_token_transaction_log` | Audit trail for currency | ✅ ACTIVE | ItemUpgradeManager.cpp |
| `dc_player_artifact_mastery` | Mastery progression system | ✅ ACTIVE | ItemUpgradeMastery.cpp |

---

## ⚠️ QUESTIONABLE TABLES (Review Needed)

### World Database:

| Table | Purpose | Status | Notes |
|-------|---------|--------|-------|
| `dc_item_upgrade_tiers` | Tier definitions | ⚠️ MAYBE | Data may be hardcoded in C++, check if table exists |
| `dc_item_upgrade_clones` | Clone item IDs for different levels | ⚠️ MAYBE | Check if clone system is implemented |
| `dc_item_upgrade_stage` | Staging area for tier dumps | 🔧 UTILITY | Can be dropped after initial import |
| `dc_item_upgrade_state` | **DUPLICATE?** Should be in characters DB | ❌ WRONG DB | Move to characters DB or drop |
| `dc_item_upgrade_synthesis_recipes` | Synthesis crafting recipes | ⚠️ ADVANCED | Phase 4 feature - may not be implemented |
| `dc_item_upgrade_synthesis_inputs` | Synthesis material inputs | ⚠️ ADVANCED | Phase 4 feature - may not be implemented |
| `dc_item_upgrade_enchants` | Custom enchants for upgrades | ⚠️ ADVANCED | V2.0 feature - may not be implemented |

### Character Database:

| Table | Purpose | Status | Notes |
|-------|---------|--------|-------|
| `dc_weekly_spending` | Weekly cap tracking | ⚠️ MAYBE | Check if weekly caps implemented |
| `dc_player_tier_unlocks` | Tier unlock progression | ⚠️ MAYBE | Check if tier gating implemented |
| `dc_player_tier_caps` | Per-tier level caps | ⚠️ MAYBE | Check if tier caps implemented |
| `dc_artifact_mastery_events` | Mastery event history | 🔧 AUDIT | Audit table - can be trimmed periodically |
| `dc_player_transmutation_cooldowns` | Transmutation cooldown tracking | ⚠️ ADVANCED | Phase 4 feature - may not be implemented |
| `dc_item_upgrade_transmutation_sessions` | Active transmutation sessions | ⚠️ ADVANCED | Phase 4 feature - may not be implemented |
| `dc_tier_conversion_log` | Tier conversion audit | 🔧 AUDIT | Audit table - can be trimmed periodically |
| `dc_player_artifact_discoveries` | Artifact discovery achievements | ⚠️ MAYBE | Check if discovery system implemented |
| `dc_season_history` | Season metadata | ⚠️ MAYBE | Check if seasons implemented |
| `dc_item_upgrade_currency` | **OLD SCHEMA** | ❌ DEPRECATED | Replaced by dc_player_upgrade_tokens |

---

## 🧹 CLEANUP RECOMMENDATIONS

### 1. **REMOVE IMMEDIATELY** (Deprecated/Duplicate):

```sql
-- Character DB
DROP TABLE IF EXISTS `dc_item_upgrade_currency`; -- Old schema, replaced by dc_player_upgrade_tokens

-- World DB (if exists in wrong database)
DROP TABLE IF EXISTS `dc_item_upgrade_state`;  -- Should only be in characters DB
```

---

### 2. **ARCHIVE (Not Yet Implemented)** - Move to backup folder:

**Phase 4 Advanced Features (Synthesis System):**
- `dc_item_upgrade_synthesis_recipes`
- `dc_item_upgrade_synthesis_inputs`
- `dc_player_transmutation_cooldowns`
- `dc_item_upgrade_transmutation_sessions`
- `dc_tier_conversion_log`

**V2.0 Features (Enchants):**
- `dc_item_upgrade_enchants`

**SQL to drop if not implemented:**
```sql
-- World DB
DROP TABLE IF EXISTS `dc_item_upgrade_synthesis_recipes`;
DROP TABLE IF EXISTS `dc_item_upgrade_synthesis_inputs`;
DROP TABLE IF EXISTS `dc_item_upgrade_enchants`;

-- Character DB
DROP TABLE IF EXISTS `dc_player_transmutation_cooldowns`;
DROP TABLE IF EXISTS `dc_item_upgrade_transmutation_sessions`;
DROP TABLE IF EXISTS `dc_tier_conversion_log`;
```

---

### 3. **VERIFY USAGE** - Check C++ code for references:

Run these searches to see if tables are actually used:

```bash
# Search for table references in C++ code
grep -r "dc_item_upgrade_tiers" src/server/scripts/DC/ItemUpgrades/
grep -r "dc_item_upgrade_clones" src/server/scripts/DC/ItemUpgrades/
grep -r "dc_weekly_spending" src/server/scripts/DC/ItemUpgrades/
grep -r "dc_player_tier_unlocks" src/server/scripts/DC/ItemUpgrades/
grep -r "dc_player_artifact_discoveries" src/server/scripts/DC/ItemUpgrades/
grep -r "dc_season_history" src/server/scripts/DC/ItemUpgrades/
```

**If NOT found in C++ code → Safe to drop**

---

### 4. **UTILITY TABLES** - Can be dropped after initial setup:

```sql
-- World DB
DROP TABLE IF EXISTS `dc_item_upgrade_stage`;  -- Only needed during tier dump imports
```

---

## 📊 ESTIMATED CLEANUP IMPACT

| Database | Current Tables | Required | Can Drop | Verify |
|----------|----------------|----------|----------|--------|
| **World** | ~10 tables | 4 core | 1-3 advanced | 3 tables |
| **Characters** | ~13 tables | 4 core | 1 deprecated | 5 tables |
| **Total** | **23 tables** | **8 core** | **2-4 drops** | **8 verify** |

**After Cleanup:**
- **Core System:** 8 tables (confirmed used)
- **Optional Features:** 3-5 tables (if implemented)
- **Total Active:** 11-13 tables

---

## ✅ VERIFICATION CHECKLIST

### Step 1: Check C++ References
```bash
cd src/server/scripts/DC/ItemUpgrades/
grep -l "dc_" *.cpp | sort | uniq
```

### Step 2: Query Actual Table Usage
```sql
-- See which tables have data
SELECT TABLE_NAME, TABLE_ROWS 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'acore_world' 
  AND TABLE_NAME LIKE 'dc_%upgrade%'
ORDER BY TABLE_ROWS DESC;

SELECT TABLE_NAME, TABLE_ROWS 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'acore_characters' 
  AND TABLE_NAME LIKE 'dc_%'
ORDER BY TABLE_ROWS DESC;
```

### Step 3: Check for Empty Tables
```sql
-- Tables with 0 rows are likely unused
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA IN ('acore_world', 'acore_characters')
  AND TABLE_NAME LIKE 'dc_%'
  AND TABLE_ROWS = 0;
```

---

## 🚀 RECOMMENDED CLEANUP SEQUENCE

### Phase 1: Safe Drops (Do Now)
```sql
-- 1. Drop deprecated tables
DROP TABLE IF EXISTS `acore_characters`.`dc_item_upgrade_currency`;

-- 2. Drop utility tables (after initial import complete)
DROP TABLE IF EXISTS `acore_world`.`dc_item_upgrade_stage`;
```

### Phase 2: Verify Then Drop (After C++ Code Check)
```sql
-- Only drop if grep shows NO references in C++ code
DROP TABLE IF EXISTS `acore_world`.`dc_item_upgrade_synthesis_recipes`;
DROP TABLE IF EXISTS `acore_world`.`dc_item_upgrade_synthesis_inputs`;
DROP TABLE IF EXISTS `acore_world`.`dc_item_upgrade_enchants`;
DROP TABLE IF EXISTS `acore_characters`.`dc_player_transmutation_cooldowns`;
DROP TABLE IF EXISTS `acore_characters`.`dc_item_upgrade_transmutation_sessions`;
DROP TABLE IF EXISTS `acore_characters`.`dc_tier_conversion_log`;
```

### Phase 3: Export Then Archive (Keep Backups)
```bash
# Backup before dropping
mysqldump acore_world dc_item_upgrade_synthesis_recipes > backup_synthesis_recipes.sql
mysqldump acore_world dc_item_upgrade_synthesis_inputs > backup_synthesis_inputs.sql
# ... etc

# Then drop tables
```

---

## 📝 NOTES

1. **Don't drop tables with data** - Always check TABLE_ROWS first
2. **Backup before cleanup** - Export any table before dropping
3. **Check C++ code** - Grep for table names in src/server/scripts/DC/ItemUpgrades/
4. **Test after cleanup** - Verify system still works after drops

---

**END OF ANALYSIS**
