# 🔧 HEIRLOOM TIER 3 SQL - COMPLETE FIX GUIDE

**File:** `HEIRLOOM_TIER3_SYSTEM_WORLD.sql`  
**Status:** Multiple schema mismatches - requires fixes before execution

---

## ✅ FIXES REQUIRED

### 1. Database Schema Preparation

**Run THIS FIRST:**
```sql
USE acore_world;

-- Add missing columns to dc_item_upgrade_costs
ALTER TABLE `dc_item_upgrade_costs`
    ADD COLUMN IF NOT EXISTS `ilvl_increase` SMALLINT UNSIGNED DEFAULT 0 AFTER `essence_cost`,
    ADD COLUMN IF NOT EXISTS `stat_increase_percent` FLOAT DEFAULT 0.0 AFTER `ilvl_increase`;
```

**File created:** `FIX_heirloom_schema_prep.sql` (run this first!)

---

### 2. Gameobject Template Fixes

**Problem:** Data0 must equal the loot table ID (entry number)

**Current (WRONG):**
```sql
(191002, 3, 119, 'Rusted Weapon Mount - Stormfury', 1.0,
   0, 0, 0, 50000, ...  -- Data0 = 0 is WRONG!
```

**Should be:**
```sql
(191002, 3, 119, 'Rusted Weapon Mount - Stormfury', 1.0,
   191002, 0, 0, 50000, ...  -- Data0 = 191002 (loot table ID)
```

**Fix:** Change Data0 from `0` to match the entry ID for all 33 gameobjects (191001-191033)

---

### 3. Quest Template Fix (SKIP THIS - Quest not needed)

**Problem:** `quest_template` columns are completely different

**The quest system in this SQL file is NOT needed.** The loot system works fine without it.

**Action:** Comment out or remove the entire SECTION 5 (quest_template INSERT)

---

### 4. Loot Table Duplicate Fix

**Problem:** Duplicate PRIMARY KEY error

```
SQL-Fehler (1062): Duplicate entry '191001-191101' for key 'gameobject_loot_template.PRIMARY'
```

**Action:** Check if loot entries already exist:
```sql
SELECT Entry FROM gameobject_loot_template WHERE Entry BETWEEN 191001 AND 191033;
```

If they exist, use `INSERT IGNORE` or `REPLACE INTO` instead of `INSERT INTO`:
```sql
REPLACE INTO gameobject_loot_template (...) VALUES ...
```

---

### 5. Upgrade Costs - Column Name Fix

**Current schema columns:**
- `tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `gold_cost`

**SQL uses (WRONG):**
- `ilvl_bonus`, `stat_multiplier`, `season`

**After running FIX_heirloom_schema_prep.sql, use:**
- `ilvl_increase` (instead of `ilvl_bonus`)
- `stat_increase_percent` (instead of `stat_multiplier`)
- Remove `season` column references (not in schema)

---

## 🚀 CORRECTED SQL SNIPPETS

### Gameobject Template (Section 2) - Fix Data0:

```sql
INSERT INTO gameobject_template
  (entry, type, displayId, name, size, Data0, Data1, Data2, Data3, ...)
VALUES
  (191001, 3, 119, 'Ancient Weapon Rack - Flamefury Blade', 1.0,
   191001, 0, 0, 50000, ...),  -- Data0 = 191001
   
  (191002, 3, 119, 'Rusted Weapon Mount - Stormfury', 1.0,
   191002, 0, 0, 50000, ...),  -- Data0 = 191002
   
  -- Continue for all 33 entries...
```

### Upgrade Costs (Section 6) - Fixed Columns:

```sql
INSERT INTO dc_item_upgrade_costs 
  (tier_id, upgrade_level, token_cost, essence_cost, ilvl_increase, stat_increase_percent)
VALUES
  -- Tier 3 Heirloom upgrades
  (3, 0, 0, 0, 0, 0.00),     -- Level 0: Base
  (3, 1, 0, 75, 2, 0.02),    -- Level 1: +2 ilvl, +2% stats
  (3, 2, 0, 82, 4, 0.04),    -- Level 2: +4 ilvl, +4% stats
  -- ... continue to level 80
  (3, 80, 0, 500, 160, 0.80); -- Level 80: +160 ilvl, +80% stats
```

**Notes:**
- Removed `season` column (not in schema)
- Changed `ilvl_bonus` → `ilvl_increase`
- Changed `stat_multiplier` → `stat_increase_percent`
- Changed multipliers (1.07 = 7% = 0.07) to percentages (7% = 0.07)

---

## 📝 EXECUTION ORDER

1. **Run:** `FIX_heirloom_schema_prep.sql` (adds missing columns)
2. **Edit:** `HEIRLOOM_TIER3_SYSTEM_WORLD.sql`:
   - Fix all Data0 values in Section 2 (191001-191033)
   - Comment out Section 5 (quest_template - not needed)
   - Fix Section 6 upgrade costs (column names + remove season)
3. **Check for duplicates:**
   ```sql
   DELETE FROM gameobject_loot_template WHERE Entry BETWEEN 191001 AND 191033;
   ```
4. **Run:** Modified `HEIRLOOM_TIER3_SYSTEM_WORLD.sql`

---

## ⚠️ IMPORTANT NOTES

### Why 80 Levels Now?

The heirloom SQL was created for 15 levels, but you've now changed Tier 3 to 80 levels.

**You need 80 cost rows:**
```sql
(3, 1, 0, essence_cost, ilvl, stat_pct),
(3, 2, 0, essence_cost, ilvl, stat_pct),
-- ... continue to ...
(3, 80, 0, essence_cost, ilvl, stat_pct);
```

**Example scaling:**
- Level 1-20: Small essence cost (50-150)
- Level 21-40: Medium cost (150-300)
- Level 41-60: High cost (300-500)
- Level 61-80: Very high cost (500-800)

Total essence to max: ~25,000-30,000 essence

---

## ✅ SUMMARY

**Critical Fixes:**
1. ✅ Add `ilvl_increase` and `stat_increase_percent` columns (FIX_heirloom_schema_prep.sql)
2. ⚠️ Fix Data0 values in gameobject_template (all 33 entries)
3. ⚠️ Remove quest_template INSERT (Section 5 - not needed)
4. ⚠️ Fix upgrade costs column names and extend to 80 levels
5. ⚠️ Handle duplicate loot table entries

**After all fixes, the system will work correctly!**

---

**END OF FIX GUIDE**
