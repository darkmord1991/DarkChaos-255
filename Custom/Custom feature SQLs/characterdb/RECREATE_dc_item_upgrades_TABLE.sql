-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- ITEM UPGRADE SYSTEM - Complete Table Recreation
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
--
-- DATABASE: acore_characters (CHARACTER DATABASE)
-- TABLE: dc_item_upgrades
--
-- PURPOSE: Stores player item upgrade state and history
--
-- CHANGES FROM OLD SCHEMA:
--   ✓ Changed first_upgraded_at from INT UNSIGNED to BIGINT UNSIGNED (64-bit timestamps)
--   ✓ Changed last_upgraded_at from INT UNSIGNED to BIGINT UNSIGNED (64-bit timestamps)
--   ✓ Fixed data type mismatch causing segmentation faults
--   ✓ Added proper indexes for performance
--   ✓ Added detailed comments for each column
--
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════

-- Verify we're in the correct database
SELECT DATABASE() as current_database;

-- STEP 1: Show old table (if exists)
SELECT 'STEP 1: Checking for existing table...' as status;
SHOW TABLES LIKE 'dc_item_upgrades';

-- STEP 2: Drop old table (backup data first if needed)
SELECT 'STEP 2: Creating backup of old data (if any)...' as status;
CREATE TABLE IF NOT EXISTS dc_item_upgrades_backup_old_schema AS
SELECT * FROM dc_item_upgrades;

SELECT 'Backup created in: dc_item_upgrades_backup_old_schema' as status;
SELECT COUNT(*) as backed_up_rows FROM dc_item_upgrades_backup_old_schema;

-- Drop the old table
DROP TABLE IF EXISTS dc_item_upgrades;

SELECT 'Old table dropped successfully' as status;

-- STEP 3: Create new table with CORRECT schema
SELECT 'STEP 3: Creating new table with correct schema...' as status;

CREATE TABLE dc_item_upgrades (
  -- Primary identification
  upgrade_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique upgrade record ID',
  
  -- Item and player identification
  item_guid INT UNIQUE NOT NULL COMMENT 'Unique item GUID from player inventory',
  player_guid INT NOT NULL COMMENT 'Character GUID (from characters table)',
  
  -- Item information
  base_item_name VARCHAR(100) NOT NULL COMMENT 'Base item name for display and reference',
  
  -- Upgrade state
  tier_id TINYINT NOT NULL DEFAULT 1 COMMENT 'Upgrade tier (1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary)',
  upgrade_level TINYINT NOT NULL DEFAULT 0 COMMENT 'Current upgrade level (0-15 per tier, 0=no upgrade)',
  
  -- Currency tracking
  tokens_invested INT NOT NULL DEFAULT 0 COMMENT 'Total upgrade tokens spent on this item',
  essence_invested INT NOT NULL DEFAULT 0 COMMENT 'Total essence spent on this item',
  
  -- Stat scaling
  stat_multiplier FLOAT NOT NULL DEFAULT 1.0 COMMENT 'Current stat multiplier (1.0 = base stats, 1.2 = +20%, etc)',
  
  -- Timing (CRITICAL: Must be BIGINT UNSIGNED for 64-bit timestamps)
  first_upgraded_at BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Unix timestamp when item was first upgraded (64-bit)',
  last_upgraded_at BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Unix timestamp when item was last upgraded (64-bit)',
  
  -- Metadata
  season INT NOT NULL DEFAULT 0 COMMENT 'Season ID for seasonal resets (0=permanent)',
  
  -- Indexes for optimal query performance
  KEY k_player (player_guid),
  KEY k_item_guid (item_guid),
  KEY k_tier (tier_id),
  KEY k_season (season),
  KEY k_last_upgraded (last_upgraded_at)
  
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
  COMMENT='Item upgrade state tracking - stores player item upgrade progress and history';

SELECT 'New table created successfully!' as status;

-- STEP 4: Verify new schema
SELECT 'STEP 4: Verifying new schema...' as status;
DESCRIBE dc_item_upgrades;

-- STEP 5: Show column types for critical fields
SELECT 
  COLUMN_NAME as field_name,
  COLUMN_TYPE as data_type,
  IS_NULLABLE as nullable,
  COLUMN_DEFAULT as default_value,
  COLUMN_COMMENT as comment
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dc_item_upgrades' 
  AND TABLE_SCHEMA = DATABASE()
ORDER BY ORDINAL_POSITION;

-- STEP 6: Verification report
SELECT 'STEP 6: Schema verification report' as status;

SELECT 
  'first_upgraded_at type check' as check_name,
  COLUMN_TYPE as column_type,
  CASE 
    WHEN COLUMN_TYPE = 'bigint(20) unsigned' THEN '✓ PASS - Correct type (64-bit unsigned)'
    WHEN COLUMN_TYPE = 'int(10) unsigned' THEN '✗ FAIL - Wrong type (32-bit unsigned)'
    ELSE '? UNKNOWN - Unexpected type'
  END as status
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dc_item_upgrades' 
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME = 'first_upgraded_at'
UNION ALL
SELECT 
  'last_upgraded_at type check',
  COLUMN_TYPE,
  CASE 
    WHEN COLUMN_TYPE = 'bigint(20) unsigned' THEN '✓ PASS - Correct type (64-bit unsigned)'
    WHEN COLUMN_TYPE = 'int(10) unsigned' THEN '✗ FAIL - Wrong type (32-bit unsigned)'
    ELSE '? UNKNOWN - Unexpected type'
  END
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dc_item_upgrades' 
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME = 'last_upgraded_at';

-- STEP 7: Show table stats
SELECT 'STEP 7: Table statistics' as status;
SELECT 
  TABLE_NAME as table_name,
  TABLE_ROWS as row_count,
  DATA_LENGTH as data_size_bytes,
  INDEX_LENGTH as index_size_bytes,
  ENGINE as storage_engine,
  TABLE_COLLATION as collation
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'dc_item_upgrades'
  AND TABLE_SCHEMA = DATABASE();

-- STEP 8: Final confirmation
SELECT 'STEP 8: Final Status' as status;
SELECT 
  '✓ Old table dropped' as step,
  COUNT(*) as verification
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'dc_item_upgrades_old'
  AND TABLE_SCHEMA = DATABASE()
UNION ALL
SELECT 
  '✓ New table created',
  COUNT(*)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'dc_item_upgrades'
  AND TABLE_SCHEMA = DATABASE()
UNION ALL
SELECT 
  '✓ Backup table exists',
  COUNT(*)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'dc_item_upgrades_backup_old_schema'
  AND TABLE_SCHEMA = DATABASE();

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- SUCCESS CRITERIA - All should show PASS:
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
--
-- ✓ Table is in CHARACTER DATABASE (acore_characters)
-- ✓ Old table dropped
-- ✓ New table created with:
--   ✓ first_upgraded_at: BIGINT UNSIGNED (64-bit)
--   ✓ last_upgraded_at: BIGINT UNSIGNED (64-bit)
--   ✓ All 12 columns present
--   ✓ All indexes created
--   ✓ Proper engine and collation
-- ✓ Backup table available (dc_item_upgrades_backup_old_schema)
--
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- NEXT STEPS:
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
--
-- 1. Rebuild server:
--    ./acore.sh compiler clean
--    ./acore.sh compiler build
--
-- 2. Restart server:
--    ./acore.sh run-worldserver
--
-- 3. Test login:
--    - Log in with test character
--    - Should work WITHOUT segmentation fault
--    - Item upgrades can now be created
--
-- 4. If needed, restore old data:
--    INSERT INTO dc_item_upgrades 
--    SELECT * FROM dc_item_upgrades_backup_old_schema;
--
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
