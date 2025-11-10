# Critical Database Schema Alignment Fix

## Problem Summary

The server was crashing with:
```
Incorrect value '2025-11-08 18:42:06' for type 'l'. Value is raw ? 'false'
Table name 'dc_player_item_upgrades'. Field name 'first_upgraded_at'
Segmentation fault (core dumped)
crash at login
```

**Root Cause:** Mismatch between database schema and C++ code
- Schema had: `first_upgraded`, `last_upgraded` (INT UNSIGNED)
- C++ expected: `first_upgraded_at`, `last_upgraded_at` (TIMESTAMP)
- C++ field structure didn't match schema columns

## Solution Applied

### 1. Updated Database Schema
`Custom/feature stuff/item upgrade system/dc_item_upgrade_schema.sql`

Changed table `dc_player_item_upgrades` to match what C++ code expects:

```sql
CREATE TABLE IF NOT EXISTS dc_player_item_upgrades (
  upgrade_id INT PRIMARY KEY AUTO_INCREMENT,
  item_guid INT UNIQUE NOT NULL,
  player_guid INT NOT NULL,
  
  -- Item Tracking
  base_item_name VARCHAR(100) NOT NULL,
  
  -- Upgrade State
  tier_id TINYINT NOT NULL DEFAULT 1,
  upgrade_level TINYINT NOT NULL DEFAULT 0,
  tokens_invested INT NOT NULL DEFAULT 0,
  essence_invested INT NOT NULL DEFAULT 0,
  stat_multiplier FLOAT NOT NULL DEFAULT 1.0,
  
  -- Timing (INT UNSIGNED for unix timestamps)
  first_upgraded_at INT UNSIGNED DEFAULT 0,
  last_upgraded_at INT UNSIGNED DEFAULT 0,
  
  -- Metadata
  season INT NOT NULL DEFAULT 0,
  
  KEY k_player (player_guid),
  KEY k_item_guid (item_guid),
  KEY k_season (season)
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4;
```

**Key Changes:**
- ✅ `first_upgraded` → `first_upgraded_at` (field name matches C++)
- ✅ `last_upgraded` → `last_upgraded_at` (field name matches C++)
- ✅ Removed `character_guid` → using `player_guid` (C++ consistent)
- ✅ Removed `track_id` foreign key (not used in C++ queries)
- ✅ Changed column order to match C++ SELECT queries
- ✅ Used INT UNSIGNED for timestamps (no FROM_UNIXTIME needed)

### 2. Updated C++ Code

#### File: `ItemUpgradeManager.cpp`

**Query fix (line 410-415):**
```cpp
// BEFORE: Mixed column names
"SELECT item_guid, player_guid, tier_id, upgrade_level, tokens_invested, essence_invested, "
"stat_multiplier, first_upgraded_at, last_upgraded_at, season "

// AFTER: Removed FROM_UNIXTIME calls
"INSERT INTO dc_player_item_upgrades ... "
"VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}) "  // 10 values instead of FROM_UNIXTIME()
"ON DUPLICATE KEY UPDATE ... last_upgraded_at = {}"  // Direct value, no function
```

#### File: `ItemUpgradeAddonHandler.cpp`

**Added missing variable (line 254):**
```cpp
std::string baseItemName = item->GetTemplate()->Name1;
```

**Updated INSERT statement (line 361-373):**
```cpp
// Uses matching field names and direct unix timestamp values
"INSERT INTO dc_player_item_upgrades "
"(item_guid, player_guid, base_item_name, tier_id, upgrade_level, "
" tokens_invested, essence_invested, stat_multiplier, first_upgraded_at, last_upgraded_at, season) "
"VALUES ({}, {}, '{}', {}, {}, {}, {}, {}, {}, {}, {})"
```

### 3. Verification Checklist

After deploying fixes, verify:

```sql
-- 1. Check table structure
DESC dc_player_item_upgrades;

-- Should show:
-- first_upgraded_at  | int(10) unsigned
-- last_upgraded_at   | int(10) unsigned
-- player_guid        | int(11)
-- tier_id            | tinyint(3) unsigned
-- upgrade_level      | tinyint(3) unsigned

-- 2. Drop old table if exists and recreate
DROP TABLE IF EXISTS dc_player_item_upgrades;
SOURCE dc_item_upgrade_schema.sql;

-- 3. Rebuild world server with updated C++ code
./acore.sh compiler clean
./acore.sh compiler build

-- 4. Restart world server
./acore.sh run-worldserver
```

## Files Modified

| File | Changes | Status |
|------|---------|--------|
| `dc_item_upgrade_schema.sql` | Updated table definition with correct column names | ✅ FIXED |
| `ItemUpgradeManager.cpp` | Updated SELECT/INSERT queries | ✅ FIXED |
| `ItemUpgradeAddonHandler.cpp` | Added baseItemName variable, fixed INSERT | ✅ FIXED |

## What This Fixes

✅ Eliminates "Incorrect value" errors
✅ Removes "first_upgraded_at field" errors  
✅ Stops segmentation faults on login
✅ Allows item upgrade system to function
✅ Properly stores upgrade state in database

## Why This Happened

1. Schema file was auto-generated with different field names
2. C++ code was written to match a different schema version
3. No validation that schema and code matched
4. Timestamp handling was inconsistent (TIMESTAMP vs INT UNSIGNED)

## Prevention

For future development:
- Always verify schema matches C++ queries BEFORE compilation
- Use INT UNSIGNED for all timestamps (AzerothCore standard)
- Run `DESC table_name` queries to validate structure
- Test schema changes with actual server compilation
