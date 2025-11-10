# CRITICAL BUG FOUND: Server-Side Stat Application Completely Broken

## Problem Summary

**Stats are NOT being applied to players because the enchants table is missing!**

The server code `ItemUpgradeStatApplication.cpp` tries to verify that upgrade enchants exist in a table called `dc_item_upgrade_enchants`, but:

1. ✗ **Table doesn't exist in database**
2. ✗ **No SQL script creates this table**
3. ✗ **When VerifyEnchantExists() returns false, stat application fails silently**

### Impact
- ✓ Client UI shows upgrade levels correctly
- ✗ **Server never applies enchantments to items**
- ✗ **Stats don't increase on player**
- ✗ Upgrades appear to work, but provide zero bonus

---

## Root Cause Analysis

### 1. Server Code Expected Behavior
`ItemUpgradeStatApplication.cpp` (line 35-42):
```cpp
uint32 GetUpgradeEnchantId(uint8 tier_id, uint8 upgrade_level)
{
    // Enchant ID format: 80000 + (tier * 100) + level
    // Example: Tier 3 Level 10 = 80310
    if (tier_id < 1 || tier_id > 5 || upgrade_level < 1 || upgrade_level > 15)
        return 0;
    
    return 80000 + (tier_id * 100) + upgrade_level;
}
```

### 2. Stat Application Pipeline (Lines 87-128)
When player equips an upgraded item:
```
OnPlayerEquip()
  → ApplyUpgradeEnchant()
    → GetUpgradeEnchantId() calculates enchant ID
    → VerifyEnchantExists() checks table ❌ FAILS
    → If table empty → returns false
    → Stats never applied
```

### 3. Verification Failure (Line 150-170)
```cpp
static bool VerifyEnchantExists(uint32 enchant_id)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT 1 FROM dc_item_upgrade_enchants WHERE enchant_id = {}", 
        enchant_id);
    
    if (result)
        return true;
    
    return false;  // ❌ Table empty or doesn't exist = false
}
```

### 4. Database State
**Missing:** `dc_item_upgrade_enchants` table
- Not in `dc_item_upgrade_schema.sql`
- Not populated by `dc_item_upgrade_import_WINDOWS.sql`
- **When code queries it: No rows = VerifyEnchantExists() always returns false**

---

## Solution

### Required Enchant IDs

The system needs enchants for all tier/level combinations:
- **5 Tiers** (1 = Tier 1, ... 5 = Mythic+)
- **15 Upgrade Levels** (per tier)
- **Total: 75 enchants**

**ID Format:** `80000 + (tier * 100) + upgrade_level`

| Tier | Level | Enchant ID | Example |
|------|-------|-----------|---------|
| 1 | 1-15 | 80101-80115 | Tier 1 Level 5 = 80105 |
| 2 | 1-15 | 80201-80215 | Tier 2 Level 10 = 80210 |
| 3 | 1-15 | 80301-80315 | Tier 3 Level 15 = 80315 |
| 4 | 1-15 | 80401-80415 | Tier 4 Level 3 = 80403 |
| 5 | 1-15 | 80501-80515 | Tier 5 Level 12 = 80512 |

### How to Fix

**Run this SQL script:**
```sql
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_enchants` (
  `enchant_id` INT UNSIGNED PRIMARY KEY,
  `tier_id` TINYINT UNSIGNED NOT NULL,
  `upgrade_level` TINYINT UNSIGNED NOT NULL,
  `created_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE KEY `uk_tier_level` (`tier_id`, `upgrade_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert all 75 enchant combinations
INSERT IGNORE INTO `dc_item_upgrade_enchants` VALUES
-- Tier 1
(80101, 1, 1), (80102, 1, 2), ..., (80115, 1, 15),
-- Tier 2
(80201, 2, 1), (80202, 2, 2), ..., (80215, 2, 15),
-- Tier 3
(80301, 3, 1), (80302, 3, 2), ..., (80315, 3, 15),
-- Tier 4
(80401, 4, 1), (80402, 4, 2), ..., (80415, 4, 15),
-- Tier 5
(80501, 5, 1), (80502, 5, 2), ..., (80515, 5, 15);
```

**File Location:**
```
Custom/Custom feature SQLs/worlddb/ItemUpgrades/
└── dc_item_upgrade_enchants_CREATE.sql
```

### Execution Steps

1. **In your MySQL client, connect to the world database:**
   ```sql
   USE acore_world;
   ```

2. **Run the SQL script:**
   ```sql
   SOURCE /path/to/dc_item_upgrade_enchants_CREATE.sql;
   ```

3. **Verify the table was created:**
   ```sql
   SELECT tier_id, COUNT(*) FROM dc_item_upgrade_enchants GROUP BY tier_id;
   ```
   Expected output:
   ```
   tier_id | COUNT(*)
   --------|----------
   1       | 15
   2       | 15
   3       | 15
   4       | 15
   5       | 15
   ```

4. **Restart the world server**

---

## What Happens After Fix

Once the table exists:

1. **OnPlayerEquip** triggered
2. **GetUpgradeEnchantId()** calculates enchant ID (e.g., 80310)
3. **VerifyEnchantExists()** queries table → **FINDS ROW** ✓
4. **ApplyEnchantment()** applies stats to player ✓
5. **Player stats increase** ✓

### Testing After Fix

```
1. Upgrade an item to level 5
2. Equip the item
3. Check character stats → should see bonus stats
4. Unequip item → stats should decrease
5. Re-equip item → stats should increase again
6. Log out and back in → stats should persist
```

---

## Why This Bug Wasn't Caught

1. **Schema exists** but enchants table missing
2. **Server code assumes table exists** (doesn't create it)
3. **VerifyEnchantExists() fails silently** (just returns false)
4. **Client UI works** (shows upgrade levels) - hides server-side failure
5. **User only notices in-game** when stats don't increase

---

## Files Affected

### Server-Side (Expects Table)
- `src/server/scripts/DC/ItemUpgrades/ItemUpgradeStatApplication.cpp`
  - Line 160: `SELECT 1 FROM dc_item_upgrade_enchants WHERE enchant_id = {}`
  - Line 114: `if (!VerifyEnchantExists(enchant_id))`

### Database Schema (Missing)
- `Custom/Custom feature SQLs/worlddb/ItemUpgrades/dc_item_upgrade_schema.sql`
  - ❌ Does NOT include dc_item_upgrade_enchants table

### Fix File (NEW)
- `Custom/Custom feature SQLs/worlddb/ItemUpgrades/dc_item_upgrade_enchants_CREATE.sql`
  - ✓ Creates table with all 75 enchants

---

## Prevention for Future

1. **Add dc_item_upgrade_enchants to dc_item_upgrade_schema.sql**
2. **Add enchant population to dc_item_upgrade_import_WINDOWS.sql**
3. **Add verification query to startup** to ensure table exists and has data
4. **Server should create missing enchants on first run** instead of failing silently

---

## CRITICAL NOTE

**This table MUST be created and populated for ANY item upgrade stats to apply to players.**

Without it:
- UI shows correct upgrade levels ✓
- Server reports upgrades working ✓
- **But player receives ZERO stat bonuses** ✗

This is why you saw upgraded items in inventory but stats didn't increase!
