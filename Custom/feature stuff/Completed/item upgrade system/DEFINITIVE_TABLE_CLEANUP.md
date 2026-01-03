# ✅ ITEM UPGRADE SYSTEM - DEFINITIVE TABLE CLEANUP REPORT

**Date:** November 17, 2025  
**Status:** C++ Code Verified

---

## 🎯 EXECUTIVE SUMMARY

**Total Tables Found:** 23+ tables  
**Core System (Keep):** 8 tables ✅  
**Advanced Features (Used):** 10 tables ✅  
**Deprecated (Drop Now):** 1 table ❌  
**Utility (Drop After Import):** 1 table 🔧

---

## ✅ CORE SYSTEM TABLES - DO NOT DROP (8 tables)

### World Database (acore_world):

| # | Table | Used By | Purpose |
|---|-------|---------|---------|
| 1 | `dc_item_upgrade_costs` | ItemUpgradeManager.cpp:932 | Cost matrix (tier/level/costs) |
| 2 | `dc_item_templates_upgrade` | ItemUpgradeManager.cpp:850+ | Item→tier mappings |
| 3 | `dc_chaos_artifact_items` | ItemUpgradeManager.cpp:1050+ | Artifact definitions |
| 4 | `dc_item_proc_spells` | ItemUpgradeProcs.cpp | Proc effects for upgraded items |

### Character Database (acore_characters):

| # | Table | Used By | Purpose |
|---|-------|---------|---------|
| 5 | `dc_player_item_upgrades` | ItemUpgradeManager.cpp:156+ | Item upgrade states |
| 6 | `dc_player_upgrade_tokens` | ItemUpgradeCommands.cpp:88+ | Currency balances |
| 7 | `dc_token_transaction_log` | ItemUpgradeManager.cpp:425+ | Audit trail |
| 8 | `dc_player_artifact_mastery` | ItemUpgradeMastery.cpp:52+ | Mastery progression |

---

## ✅ ADVANCED FEATURES - KEEP (Used in C++ Code) (10 tables)

### World Database:

| # | Table | Used By | Purpose | Needed For |
|---|-------|---------|---------|------------|
| 9 | `dc_item_upgrade_tiers` | ItemUpgradeManager.cpp:892<br>ItemUpgradeAddonHandler.cpp:508 | Tier definitions | Tier metadata queries |
| 10 | `dc_item_upgrade_clones` | ItemUpgradeAddonHandler.cpp:235,254,389,400,608,614 | Clone item IDs | Item swapping at each level |
| 11 | `dc_item_upgrade_synthesis_recipes` | ItemUpgradeTransmutationImpl.cpp:69<br>ItemUpgradeSynthesisImpl.cpp:45 | Synthesis recipes | Transmutation/crafting |
| 12 | `dc_item_upgrade_synthesis_inputs` | ItemUpgradeTransmutationImpl.cpp:110<br>ItemUpgradeSynthesisImpl.cpp:360 | Synthesis materials | Transmutation/crafting |

### Character Database:

| # | Table | Used By | Purpose | Needed For |
|---|-------|---------|---------|------------|
| 13 | `dc_weekly_spending` | ItemUpgradeManager.cpp:449,377<br>ItemUpgradeSeasonalImpl.cpp:83 | Weekly caps | Currency spending limits |
| 14 | `dc_artifact_mastery_events` | ItemUpgradeProgressionImpl.cpp:186,211,235 | Mastery events | Audit trail for mastery |
| 15 | `dc_player_tier_unlocks` | ItemUpgradeProgressionImpl.cpp:198,205,222,229,291,318 | Tier unlock gating | Progressive tier unlocks |
| 16 | `dc_tier_conversion_log` | ItemUpgradeTransmutationImpl.cpp:708 | Tier conversions | Audit trail |
| 17 | `dc_player_artifact_discoveries` | ItemUpgradeManager.cpp:869<br>ItemUpgradeNPC_Curator.cpp:92<br>ItemUpgradeTokenHooks.cpp:239,258 | Artifact discoveries | Achievement tracking |
| 18 | `dc_season_history` | ItemUpgradeSeasonalImpl.cpp:44 | Season metadata | Season resets |

---

## ❌ DROP IMMEDIATELY - DEPRECATED (1 table)

```sql
-- Character Database
DROP TABLE IF EXISTS `dc_item_upgrade_currency`;
```

**Reason:** Old schema replaced by `dc_player_upgrade_tokens`  
**Verification:** Not found in any C++ file  

---

## 🔧 DROP AFTER INITIAL IMPORT - UTILITY (1 table)

```sql
-- World Database
DROP TABLE IF EXISTS `dc_item_upgrade_stage`;
```

**Reason:** Staging table for tier dump imports, not needed after setup  
**When to Drop:** After initial item import is complete  

---

## ⚠️ ADDITIONAL TABLES NOT FOUND IN C++ (Review Database)

These tables may exist in your database but are **NOT referenced in C++ code**:

### World Database:
- `dc_item_upgrade_enchants` - Custom enchants (V2.0 feature, not implemented)

### Character Database:
- `dc_player_transmutation_cooldowns` - Transmutation cooldowns
- `dc_item_upgrade_transmutation_sessions` - Active transmutation sessions
- `dc_player_tier_caps` - Per-tier level caps

**Recommendation:** Query your database to check if these exist. If they do and have 0 rows, consider dropping them.

---

## 🔍 VERIFICATION QUERIES

### Step 1: Check Which Tables Actually Exist

```sql
-- World Database
SELECT TABLE_NAME, TABLE_ROWS, 
       ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Size_MB'
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_world' 
  AND TABLE_NAME LIKE 'dc_%upgrade%'
ORDER BY TABLE_ROWS DESC;

-- Character Database
SELECT TABLE_NAME, TABLE_ROWS,
       ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Size_MB'
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_characters'
  AND TABLE_NAME LIKE 'dc_%'
ORDER BY TABLE_ROWS DESC;
```

### Step 2: Find Empty Tables (Safe to Drop)

```sql
-- Empty tables in world DB
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_world'
  AND TABLE_NAME LIKE 'dc_%upgrade%'
  AND TABLE_ROWS = 0;

-- Empty tables in character DB
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_characters'
  AND TABLE_NAME LIKE 'dc_%'
  AND TABLE_ROWS = 0;
```

---

## 📋 CLEANUP SCRIPT (Safe to Run)

```sql
-- =============================================================================
-- SAFE CLEANUP - DROP DEPRECATED TABLES
-- =============================================================================

USE acore_characters;

-- 1. Drop deprecated currency table (replaced by dc_player_upgrade_tokens)
DROP TABLE IF EXISTS `dc_item_upgrade_currency`;

-- Verify it's gone
SELECT COUNT(*) AS 'Should be 0' 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'acore_characters' 
  AND TABLE_NAME = 'dc_item_upgrade_currency';

-- =============================================================================
-- OPTIONAL - DROP UTILITY TABLE (after initial import complete)
-- =============================================================================

USE acore_world;

-- 2. Drop staging table (only needed during initial setup)
-- DROP TABLE IF EXISTS `dc_item_upgrade_stage`;

-- =============================================================================
-- VERIFICATION - LIST REMAINING TABLES
-- =============================================================================

SELECT 'World DB Tables:' AS Info;
SELECT TABLE_NAME, TABLE_ROWS 
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_world'
  AND TABLE_NAME LIKE 'dc_%upgrade%'
ORDER BY TABLE_NAME;

SELECT 'Character DB Tables:' AS Info;
SELECT TABLE_NAME, TABLE_ROWS 
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_characters'
  AND (TABLE_NAME LIKE 'dc_player_%' 
       OR TABLE_NAME LIKE 'dc_token_%'
       OR TABLE_NAME LIKE 'dc_artifact_%'
       OR TABLE_NAME LIKE 'dc_tier_%'
       OR TABLE_NAME LIKE 'dc_weekly_%'
       OR TABLE_NAME LIKE 'dc_season_%')
ORDER BY TABLE_NAME;
```

---

## 📊 FINAL TABLE COUNT SUMMARY

| Database | Core | Advanced | Deprecated | Utility | Total |
|----------|------|----------|------------|---------|-------|
| **World** | 4 | 4 | 0 | 1 | 9 |
| **Characters** | 4 | 6 | 1 | 0 | 11 |
| **TOTAL** | **8** | **10** | **1** | **1** | **20** |

**After Cleanup:**
- ✅ **18 Active Tables** (8 core + 10 advanced)
- ❌ Drop 1 deprecated table (`dc_item_upgrade_currency`)
- 🔧 Optionally drop 1 utility table (`dc_item_upgrade_stage`)

---

## ⚠️ IMPORTANT NOTES

### DO NOT DROP:

1. ✅ **dc_item_upgrade_tiers** - Used by ItemUpgradeAddonHandler for tier metadata
2. ✅ **dc_item_upgrade_clones** - Critical for item swapping system
3. ✅ **dc_weekly_spending** - Active weekly cap tracking
4. ✅ **dc_player_tier_unlocks** - Active tier progression gating
5. ✅ **dc_artifact_mastery_events** - Active audit trail
6. ✅ **dc_player_artifact_discoveries** - Active achievement tracking
7. ✅ **dc_season_history** - Active season management
8. ✅ **dc_tier_conversion_log** - Active audit trail
9. ✅ **dc_item_upgrade_synthesis_recipes** - Active transmutation system
10. ✅ **dc_item_upgrade_synthesis_inputs** - Active transmutation system

### Safe to Drop:

- ❌ **dc_item_upgrade_currency** - Old schema, replaced
- 🔧 **dc_item_upgrade_stage** - Utility, drop after import

---

## 🚀 RECOMMENDED ACTION

**Run this single command to clean up:**

```sql
USE acore_characters;
DROP TABLE IF EXISTS `dc_item_upgrade_currency`;
```

**All other tables are actively used by the C++ code and should be kept.**

---

**END OF REPORT**
