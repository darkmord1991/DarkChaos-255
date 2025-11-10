# ⚠️ CRITICAL: Fix Persisting Segmentation Fault

## Status
The schema in your screenshot is **STILL WRONG**:
- `first_upgraded_at` = INT (should be BIGINT UNSIGNED)
- `last_upgraded_at` = INT (should be BIGINT UNSIGNED)  
- Both have "Erlaubte NULL" checked (should be NOT NULL)

This is why the error persists: `Incorrect value '2025-11-08 18:42:06' for type 'l'`

## What Went Wrong

The FIX_TIMESTAMP_SCHEMA.sql script needs to be **executed on the database**, but it appears the old schema is still active. The database table needs to be completely dropped and recreated.

## Immediate Fix Required

### 1. Open MySQL/Database Client
Connect to your CHARACTER database (acore_characters)

### 2. Copy-Paste This Exact SQL
```sql
-- Drop old table with wrong schema
DROP TABLE IF EXISTS `dc_player_item_upgrades`;

-- Create new table with CORRECT schema
CREATE TABLE `dc_player_item_upgrades` (
  `upgrade_id` INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique upgrade record ID',
  `item_guid` INT UNIQUE NOT NULL COMMENT 'Unique item GUID from player inventory',
  `player_guid` INT NOT NULL COMMENT 'Character GUID (from characters table)',
  `base_item_name` VARCHAR(100) NOT NULL COMMENT 'Base item name for display',
  `tier_id` TINYINT NOT NULL DEFAULT 1 COMMENT 'Upgrade tier (1-5)',
  `upgrade_level` TINYINT NOT NULL DEFAULT 0 COMMENT 'Current upgrade level (0-15 per tier)',
  `tokens_invested` INT NOT NULL DEFAULT 0 COMMENT 'Total upgrade tokens spent',
  `essence_invested` INT NOT NULL DEFAULT 0 COMMENT 'Total essence spent',
  `stat_multiplier` FLOAT NOT NULL DEFAULT 1.0 COMMENT 'Current stat multiplier (1.0 = base stats)',
  `first_upgraded_at` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Unix timestamp when first upgraded',
  `last_upgraded_at` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Unix timestamp when last upgraded',
  `season` INT NOT NULL DEFAULT 0 COMMENT 'Season ID for seasonal resets',
  
  KEY `k_player` (`player_guid`),
  KEY `k_item_guid` (`item_guid`),
  KEY `k_season` (`season`),
  KEY `k_tier` (`tier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player item upgrade state and history (v2.0 - FIXED SCHEMA)';

-- Verify
DESCRIBE `dc_player_item_upgrades`;
```

### 3. Execute the SQL

You should see:
```
upgrade_id          | int(11)              | NO   | PRI | NULL | auto_increment
item_guid           | int(11)              | NO   | UNI | NULL | 
player_guid         | int(11)              | NO   | MUL | NULL |
base_item_name      | varchar(100)         | NO   |     | NULL |
tier_id             | tinyint(4)           | NO   |     | 1    |
upgrade_level       | tinyint(4)           | NO   |     | 0    |
tokens_invested     | int(11)              | NO   |     | 0    |
essence_invested    | int(11)              | NO   |     | 0    |
stat_multiplier     | float                | NO   |     | 1    |
first_upgraded_at   | bigint(20) unsigned  | NO   | MUL | 0    |  ← CORRECT!
last_upgraded_at    | bigint(20) unsigned  | NO   | MUL | 0    |  ← CORRECT!
season              | int(11)              | NO   |     | 0    |
```

✅ **CRITICAL:** Both timestamp fields must show `bigint(20) unsigned` and `NO` for NULL

### 4. Rebuild AzerothCore
```bash
cd /path/to/darkChaos
./acore.sh compiler clean
./acore.sh compiler build
```

### 5. Restart Server
```bash
./acore.sh run-worldserver
```

### 6. Test
- Create new character
- Login should work WITHOUT segmentation fault
- Error should be gone

## Why BIGINT UNSIGNED?

- `time_t` on 64-bit systems = 8 bytes (64-bit)
- `INT` = only 4 bytes (32-bit) - too small, causes overflow
- `BIGINT UNSIGNED` = 8 bytes, unsigned = supports full unix timestamp range

## Summary

| Issue | Old (WRONG) | New (CORRECT) |
|-------|-----------|---------------|
| Type | INT | BIGINT UNSIGNED |
| Allow NULL | YES ❌ | NO ✅ |
| Default | (none) | 0 |
| Max Value | 2,147,483,647 | 18,446,744,073,709,551,615 |
| Supports Current Timestamps | NO ❌ | YES ✅ |

The schema MUST be updated before rebuilding. The C++ code is already correct.
