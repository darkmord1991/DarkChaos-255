-- HLBG Cleanup Script - Remove Unused Tables and Fix Duplicates
-- Location: Custom/Hinterland BG/CharDB/02_cleanup_unused_tables.sql
-- Apply to CHARACTER database - Cleanup unnecessary tables

-- ==================================================
-- HLBG TABLE CLEANUP SCRIPT
-- Based on analysis: Some tables are unused and seasons has duplicate time tracking
-- ==================================================

-- ==================================================
-- 1. FIX HLBG_SEASONS DUPLICATE TIME COLUMNS
-- ==================================================

-- Check if hlbg_seasons table exists and has duplicate time columns
SELECT 'Fixing hlbg_seasons duplicate time columns...' as Status;

-- Safely remove duplicate time columns (keep starts_at/ends_at, remove start_date/end_date)
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_seasons' AND COLUMN_NAME = 'start_date') > 0,
    'ALTER TABLE hlbg_seasons DROP COLUMN start_date',
    'SELECT "start_date column does not exist" as Notice'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_seasons' AND COLUMN_NAME = 'end_date') > 0,
    'ALTER TABLE hlbg_seasons DROP COLUMN end_date',
    'SELECT "end_date column does not exist" as Notice'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Update existing season data to use proper starts_at/ends_at if they're NULL
UPDATE hlbg_seasons 
SET starts_at = '2025-10-01 00:00:00' 
WHERE season = 1 AND starts_at IS NULL;

UPDATE hlbg_seasons 
SET ends_at = '2025-12-31 23:59:59' 
WHERE season = 1 AND ends_at IS NULL;

-- ==================================================
-- 2. DROP UNUSED TABLES FROM WORLD DATABASE
-- ==================================================

-- Note: These tables were created in WorldDatabase but analysis shows they're not used
SELECT 'Cleaning up unused tables from World database...' as Status;

-- Drop hlbg_config (unused - no code references found)
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
     WHERE TABLE_SCHEMA = 'acore_world' AND TABLE_NAME = 'hlbg_config') > 0,
    'USE acore_world; DROP TABLE IF EXISTS hlbg_config',
    'SELECT "hlbg_config does not exist in world DB" as Notice'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Drop hlbg_weather (unused - no code references found)
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
     WHERE TABLE_SCHEMA = 'acore_world' AND TABLE_NAME = 'hlbg_weather') > 0,
    'USE acore_world; DROP TABLE IF EXISTS hlbg_weather',
    'SELECT "hlbg_weather does not exist in world DB" as Notice'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Keep hlbg_seasons in world DB if it exists there (move data to character DB)
-- First check if seasons data exists in world DB and migrate it
SET @migrate_seasons = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
     WHERE TABLE_SCHEMA = 'acore_world' AND TABLE_NAME = 'hlbg_seasons') > 0,
    'Seasons table exists in world DB - migration needed',
    'No seasons migration needed'
));
SELECT @migrate_seasons as SeasonsMigrationStatus;

-- ==================================================
-- 3. ENSURE PROPER TABLE LOCATIONS
-- ==================================================

-- Verify correct table placement after cleanup
SELECT 'Verifying table locations after cleanup...' as Status;

-- CharacterDatabase tables (should exist)
SELECT 
    'hlbg_winner_history' as TableName,
    'CharacterDB' as DatabaseName,
    CASE WHEN EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_winner_history'
    ) THEN 'EXISTS ✓' ELSE 'MISSING ✗' END as TableStatus,
    'CRITICAL - Required for existing system' as Importance;

SELECT 
    'hlbg_affixes' as TableName,
    'CharacterDB' as DatabaseName,
    CASE WHEN EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_affixes'
    ) THEN 'EXISTS ✓' ELSE 'MISSING ✗' END as TableStatus,
    'REQUIRED - Affix system needs this' as Importance;

SELECT 
    'hlbg_seasons' as TableName,
    'CharacterDB' as DatabaseName,
    CASE WHEN EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_seasons'
    ) THEN 'EXISTS ✓' ELSE 'MISSING ✗' END as TableStatus,
    'OPTIONAL - Season tracking' as Importance;

-- ==================================================
-- 4. CREATE MINIMAL ESSENTIAL SCHEMA
-- ==================================================

-- Ensure the essential tables exist with minimal required structure
CREATE TABLE IF NOT EXISTS `hlbg_winner_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `occurred_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `winner_tid` TINYINT DEFAULT 0 COMMENT '0=Alliance, 1=Horde, 2=Draw',
    `win_reason` ENUM('depletion', 'tiebreaker', 'manual', 'timeout') DEFAULT 'depletion',
    `score_alliance` INT DEFAULT 0,
    `score_horde` INT DEFAULT 0,
    `affix` VARCHAR(50) DEFAULT 'None',
    `duration_seconds` INT DEFAULT 0,
    `season` INT DEFAULT 1,
    `notes` TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Essential HLBG Battle Results - Required by Eluna AIO';

CREATE TABLE IF NOT EXISTS `hlbg_affixes` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL UNIQUE,
    `description` TEXT,
    `effect` TEXT,
    `season_id` INT DEFAULT NULL,
    `spell_id` INT DEFAULT 0,
    `icon` VARCHAR(100) DEFAULT '',
    `is_enabled` BOOLEAN DEFAULT TRUE,
    `usage_count` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='HLBG Affix Definitions - Required by Eluna AIO';

-- Only create seasons table if user wants season tracking (optional)
CREATE TABLE IF NOT EXISTS `hlbg_seasons` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `season` INT NOT NULL UNIQUE,
    `name` VARCHAR(100) NOT NULL,
    `description` TEXT,
    `rewards_alliance` TEXT COMMENT 'Alliance rewards (JSON or text)',
    `rewards_horde` TEXT COMMENT 'Horde rewards (JSON or text)', 
    `rewards_participation` TEXT COMMENT 'Participation rewards',
    `is_active` BOOLEAN DEFAULT FALSE,
    `starts_at` DATETIME NULL,
    `ends_at` DATETIME NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `created_by` VARCHAR(50) DEFAULT 'GM'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='HLBG Season Management - Optional Feature';

-- ==================================================
-- 5. POPULATE ESSENTIAL DATA
-- ==================================================

-- Insert essential affix data
INSERT INTO `hlbg_affixes` (`id`, `name`, `description`, `is_enabled`) VALUES
(0, 'None', 'No active affix - standard battleground rules', TRUE),
(1, 'Bloodlust', 'All players gain increased attack and movement speed', TRUE),
(2, 'Regeneration', 'Passive health and mana regeneration for all combatants', TRUE),
(3, 'Speed Boost', 'Significant movement speed increase for faster gameplay', TRUE),
(4, 'Damage Shield', 'Damage is reflected back to attackers', TRUE),
(5, 'Storms', 'Periodic lightning storms damage and stun players', TRUE),
(6, 'Volcanic', 'Ground eruptions knock players back and deal damage', TRUE),
(7, 'Haste', 'Periodic speed and haste buffs for all players', TRUE),
(8, 'Berserker', 'Players with low health deal significantly more damage', TRUE),
(9, 'Fortified', 'All players receive damage reduction bonuses', TRUE)
ON DUPLICATE KEY UPDATE 
    `description` = VALUES(`description`),
    `is_enabled` = VALUES(`is_enabled`);

-- Update season 1 with proper dates (fix existing data)
INSERT INTO `hlbg_seasons` (`season`, `name`, `description`, `starts_at`, `ends_at`, `is_active`) VALUES
(1, 'Season 1', 'Level 80 start', '2025-10-01 00:00:00', '2025-12-31 23:59:59', TRUE),
(2, 'Season2', 'test2', '2025-01-01 00:00:00', '2025-03-31 23:59:59', FALSE)
ON DUPLICATE KEY UPDATE
    `starts_at` = VALUES(`starts_at`),
    `ends_at` = VALUES(`ends_at`),
    `is_active` = VALUES(`is_active`);

-- ==================================================
-- CLEANUP COMPLETE
-- ==================================================

SELECT 'HLBG Cleanup Complete!' as Status;
SELECT 'Removed duplicate time columns from hlbg_seasons' as FixedDuplicates;
SELECT 'Dropped unused tables: hlbg_config, hlbg_weather' as RemovedTables;
SELECT 'Essential tables verified: hlbg_winner_history, hlbg_affixes' as EssentialTables;
SELECT 'Optional table cleaned: hlbg_seasons (fixed time columns)' as OptionalTables;

-- Show current table status
SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    CREATE_TIME,
    TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE 'hlbg_%'
ORDER BY TABLE_NAME;