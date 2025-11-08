-- ═══════════════════════════════════════════════════════════════════════════════
-- DarkChaos Item Upgrade System - Player Item Upgrades Table
-- ═══════════════════════════════════════════════════════════════════════════════
-- CRITICAL: This replaces the old dc_player_item_upgrades table with correct schema
-- The timestamps MUST use INT UNSIGNED (not TIMESTAMP) to avoid MySQL auto-conversion
-- ═══════════════════════════════════════════════════════════════════════════════

-- Step 1: Backup old data (optional, comment out if not needed)
-- CREATE TABLE dc_player_item_upgrades_backup AS SELECT * FROM dc_player_item_upgrades;

-- Step 2: Drop the old table
DROP TABLE IF EXISTS dc_player_item_upgrades;

-- Step 3: Create the CORRECT schema with INT UNSIGNED for timestamps
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
  first_upgraded_at INT UNSIGNED DEFAULT 0 COMMENT 'Unix timestamp when first upgraded',
  last_upgraded_at INT UNSIGNED DEFAULT 0 COMMENT 'Unix timestamp when last upgraded',
  season INT NOT NULL DEFAULT 0 COMMENT 'Season ID for seasonal resets',
  
  -- Indexes for common queries
  KEY k_player (player_guid),
  KEY k_item_guid (item_guid),
  KEY k_season (season),
  KEY k_tier (tier_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player item upgrade state and history';

-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERY
-- ═══════════════════════════════════════════════════════════════════════════════
-- Run this to verify the schema is correct:
-- DESCRIBE dc_player_item_upgrades;

-- Expected output for timestamp fields:
-- first_upgraded_at  | int(10) unsigned | NO   | MUL | 0    | 
-- last_upgraded_at   | int(10) unsigned | NO   | MUL | 0    |

-- If you see "timestamp" type instead of "int(10) unsigned", the schema is WRONG!
-- ═══════════════════════════════════════════════════════════════════════════════
