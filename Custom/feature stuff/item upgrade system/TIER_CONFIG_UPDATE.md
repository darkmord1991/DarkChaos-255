# ✅ TIER CONFIGURATION UPDATE

**Date:** November 17, 2025  
**Status:** Updated tier max levels per user requirements

---

## 🎯 NEW TIER CONFIGURATION

### Tier 1: Leveling Items
- **Max Upgrade Levels:** 6
- **Item Level Range:** 1-212
- **Currency:** Upgrade Tokens
- **Purpose:** Quest and leveling gear
- **Stat Multiplier Max:** 1.30x (30% increase)

### Tier 2: Heroic Items
- **Max Upgrade Levels:** 15
- **Item Level Range:** 213-226
- **Currency:** Upgrade Tokens
- **Purpose:** Heroic dungeon gear
- **Stat Multiplier Max:** 1.50x (50% increase)

### Tier 3: Heirloom Items
- **Max Upgrade Levels:** 80 (one per player level)
- **Item Level Range:** Scales with player level
- **Currency:** Artifact Essence
- **Purpose:** Heirloom items that scale 1-80
- **Stat Multiplier Max:** 1.80x (80% increase)

---

## 📝 FILES UPDATED

### 1. ✅ C++ Source Code

**ItemUpgradeManager.h:**
```cpp
static const uint8 MAX_UPGRADE_LEVEL = 80;  // Updated from 15

enum UpgradeTier {
    TIER_LEVELING = 1,   // 6 levels
    TIER_HEROIC = 2,     // 15 levels
    TIER_HEIRLOOM = 3,   // 80 levels
};
```

### 2. ✅ Database Schema Fix

**FIX_dc_item_upgrade_costs_schema.sql:**
- Updated example data to show 6/15/80 level structure
- Updated comments to reflect new tier configuration

### 3. ✅ Tier Definitions SQL

**NEW FILE: POPULATE_tier_definitions.sql**
- Creates/populates `dc_item_upgrade_tiers` table
- Defines max_upgrade_level for each tier:
  - Tier 1: 6 levels
  - Tier 2: 15 levels
  - Tier 3: 80 levels

### 4. ✅ Documentation

**FIXES_APPLIED.md:**
- Updated all references to tier max levels
- Updated verification checklist
- Updated summary

---

## 🗄️ DATABASE REQUIREMENTS

### Step 1: Run Tier Definitions
```bash
mysql -u root -p acore_world < "Custom/Custom feature SQLs/worlddb/ItemUpgrades/POPULATE_tier_definitions.sql"
```

**This creates:**
```sql
dc_item_upgrade_tiers:
- Tier 1: max_upgrade_level = 6
- Tier 2: max_upgrade_level = 15
- Tier 3: max_upgrade_level = 80
```

### Step 2: Run Schema Fix
```bash
mysql -u root -p acore_world < "Custom/Custom feature SQLs/worlddb/ItemUpgrades/FIX_dc_item_upgrade_costs_schema.sql"
```

**This adds:**
- `ilvl_increase` column
- `stat_increase_percent` column
- `season` column
- Changes primary key to (tier_id, upgrade_level, season)

### Step 3: Populate Cost Data

You need to create cost entries:
- **Tier 1:** 6 rows (levels 1-6)
- **Tier 2:** 15 rows (levels 1-15)
- **Tier 3:** 80 rows (levels 1-80)

**Example for Tier 1:**
```sql
INSERT INTO dc_item_upgrade_costs 
    (tier_id, upgrade_level, token_cost, essence_cost, ilvl_increase, stat_increase_percent, season)
VALUES
    (1, 1, 5, 0, 1, 0.05, 1),   -- +5% stats per level
    (1, 2, 6, 0, 1, 0.05, 1),
    (1, 3, 7, 0, 1, 0.05, 1),
    (1, 4, 8, 0, 1, 0.05, 1),
    (1, 5, 9, 0, 1, 0.05, 1),
    (1, 6, 10, 0, 1, 0.05, 1);  -- Total: 6 levels, 30% stat increase
```

**Example for Tier 3 (Heirlooms):**
```sql
-- 80 rows for levels 1-80
INSERT INTO dc_item_upgrade_costs 
    (tier_id, upgrade_level, token_cost, essence_cost, ilvl_increase, stat_increase_percent, season)
VALUES
    (3, 1, 0, 5, 0, 0.01, 1),   -- 1% per level, uses essence
    (3, 2, 0, 5, 0, 0.01, 1),
    -- ... continue to level 80
    (3, 80, 0, 5, 0, 0.01, 1);  -- Total: 80% stat increase
```

---

## 🔄 MIGRATION SUMMARY

| Aspect | Old Value | New Value |
|--------|-----------|-----------|
| **Tier 1 Max Level** | 60 | 6 |
| **Tier 2 Max Level** | 15 | 15 ✅ (unchanged) |
| **Tier 3 Max Level** | 15 | 80 |
| **MAX_UPGRADE_LEVEL Constant** | 15 | 80 |
| **Total Cost Rows Needed** | 90 (60+15+15) | 101 (6+15+80) |

---

## ✅ VERIFICATION

After applying changes:

```sql
-- Check tier definitions
SELECT tier_id, tier_name, max_upgrade_level 
FROM dc_item_upgrade_tiers 
WHERE season = 1;

-- Expected:
-- 1 | Leveling  | 6
-- 2 | Heroic    | 15
-- 3 | Heirloom  | 80

-- Check cost data exists
SELECT tier_id, COUNT(*) AS level_count 
FROM dc_item_upgrade_costs 
WHERE season = 1 
GROUP BY tier_id;

-- Expected:
-- 1 | 6
-- 2 | 15
-- 3 | 80
```

---

## 💡 DESIGN RATIONALE

### Why 6 levels for Tier 1?
- **Fast progression** for leveling items
- Items are quickly replaced while leveling
- Prevents over-investment in temporary gear

### Why 15 levels for Tier 2?
- **Medium progression** for heroic gear
- Balances with endgame gear progression
- Standard for heroic dungeon reward items

### Why 80 levels for Tier 3?
- **Scales with player level** (1-80)
- Heirlooms stay relevant throughout entire leveling
- One upgrade per level = smooth progression curve
- Encourages long-term investment in heirlooms

---

## 🚀 NEXT STEPS

1. ✅ Run `POPULATE_tier_definitions.sql` on database
2. ✅ Run `FIX_dc_item_upgrade_costs_schema.sql` on database
3. ⏳ Create cost data for all 101 upgrade levels (6+15+80)
4. ⏳ Recompile server
5. ⏳ Test each tier in-game

---

**END OF REPORT**
