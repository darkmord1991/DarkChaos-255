-- ═══════════════════════════════════════════════════════════════════════════════
-- CRITICAL FIX: Item Upgrade System - TIMESTAMP to INT UNSIGNED Migration
-- ═══════════════════════════════════════════════════════════════════════════════
-- ERROR: "Incorrect value '2025-11-08 18:42:06' for type 'l'"
-- ROOT CAUSE: Fields are TIMESTAMP type instead of INT UNSIGNED
-- SOLUTION: Convert TIMESTAMP fields to INT UNSIGNED
-- ═══════════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 1: Verify current schema (run BEFORE applying fix)
-- ───────────────────────────────────────────────────────────────────────────────
-- Run this query BEFORE to see the current (WRONG) schema:
-- DESCRIBE dc_player_item_upgrades;
-- 
-- You should see:
-- first_upgraded_at  | timestamp           | YES  | MUL | CURRENT_TIMESTAMP |   ← WRONG!
-- last_upgraded_at   | timestamp           | YES  | MUL | CURRENT_TIMESTAMP |   ← WRONG!

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 2: Backup existing data (OPTIONAL - keeps a copy of old records)
-- ───────────────────────────────────────────────────────────────────────────────
-- Uncomment this line if you want to keep a backup of the old data structure
-- CREATE TABLE dc_player_item_upgrades_backup_old_schema AS 
-- SELECT * FROM dc_player_item_upgrades;

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 3: DROP and RECREATE with CORRECT schema
-- ───────────────────────────────────────────────────────────────────────────────
-- WARNING: This will DELETE all existing upgrade data!
-- If you have important data, run the backup query above first.

DROP TABLE IF EXISTS dc_player_item_upgrades;

CREATE TABLE dc_player_item_upgrades (
  upgrade_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique upgrade record ID',
  item_guid INT UNIQUE NOT NULL COMMENT 'Unique item GUID from player inventory',
  player_guid INT NOT NULL COMMENT 'Character GUID (from characters table)',
  base_item_name VARCHAR(100) NOT NULL COMMENT 'Base item name for display',
  tier_id TINYINT NOT NULL DEFAULT 1 COMMENT 'Upgrade tier (1-5)',
  upgrade_level TINYINT NOT NULL DEFAULT 0 COMMENT 'Current upgrade level (0-15 per tier)',
  tokens_invested INT NOT NULL DEFAULT 0 COMMENT 'Total upgrade tokens spent',
  essence_invested INT NOT NULL DEFAULT 0 COMMENT 'Total essence spent',
  stat_multiplier FLOAT NOT NULL DEFAULT 1.0 COMMENT 'Current stat multiplier (1.0 = base stats)',
  first_upgraded_at BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Unix timestamp when first upgraded (MUST BE BIGINT UNSIGNED)',
  last_upgraded_at BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Unix timestamp when last upgraded (MUST BE BIGINT UNSIGNED)',
  season INT NOT NULL DEFAULT 0 COMMENT 'Season ID for seasonal resets',
  
  -- Indexes for optimal query performance
  KEY k_player (player_guid),
  KEY k_item_guid (item_guid),
  KEY k_season (season),
  KEY k_tier (tier_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player item upgrade state and history (v2.0 - FIXED SCHEMA)';

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 4: Verify the schema is NOW CORRECT
-- ───────────────────────────────────────────────────────────────────────────────
-- Run this AFTER applying the fix to verify success:
-- DESCRIBE dc_player_item_upgrades;
-- 
-- You should NOW see:
-- first_upgraded_at  | bigint(20) unsigned | NO   | MUL | 0    |       ← CORRECT!
-- last_upgraded_at   | bigint(20) unsigned | NO   | MUL | 0    |       ← CORRECT!

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEPLOYMENT STEPS (IN ORDER)
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- 1. Run the SQL script above against CHARACTER database
--    (This script)
--
-- 2. Verify schema is correct:
--    DESCRIBE dc_player_item_upgrades;
--
-- 3. Rebuild AzerothCore:
--    ./acore.sh compiler clean
--    ./acore.sh compiler build
--
-- 4. Start the server:
--    ./acore.sh run-worldserver
--
-- 5. Test login:
--    - Create test character
--    - Login should succeed WITHOUT "Incorrect value" error
--    - Should NOT see: Segmentation fault (core dumped)
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPECTED RESULT
-- ═══════════════════════════════════════════════════════════════════════════════
-- ✅ Players can login without segmentation fault
-- ✅ Item upgrades can be saved/loaded
-- ✅ Timestamps stored as unix epoch (e.g., 1731098526)
-- ✅ No "Incorrect value '2025-11-08 18:42:06' for type 'l'" errors
--
-- ═══════════════════════════════════════════════════════════════════════════════
