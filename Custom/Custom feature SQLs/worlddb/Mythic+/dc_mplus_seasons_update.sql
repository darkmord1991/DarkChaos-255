-- ========================================================================
-- DC Missing Tables Update - World Database (acore_world)
-- ========================================================================
-- Purpose: Create tables that are missing from the current database
-- Database: acore_world
-- Date: November 29, 2025
-- ========================================================================
-- 
-- This script creates tables that are used by C++ code but might not exist:
--   - dc_mplus_seasons (M+ specific season config with JSON)
--
-- NOTE: dc_mplus_seasons is NOT obsolete - it contains M+-specific 
-- configuration (featured dungeons, affix schedule, reward curves) that
-- is intentionally separate from the generic dc_seasons table.
--
-- The MythicPlusSeasonalIntegration.cpp uses this as a FALLBACK when
-- the generic SeasonalManager is not available.
--
-- EXECUTION:
--   mysql -u root -p acore_world < "this_file.sql"
--
-- ========================================================================

USE acore_world;

-- ========================================================================
-- Mythic+ Season Configuration
-- ========================================================================
-- Referenced by: MythicDifficultyScaling.cpp, MythicPlusSeasonalIntegration.cpp
-- This table stores M+-SPECIFIC season config (affixes, dungeons, rewards)
-- NOT the same as dc_seasons which is generic season data

SELECT '📋 Creating Mythic+ Season Config Table...' AS step;

CREATE TABLE IF NOT EXISTS `dc_mplus_seasons` (
    `season_id` INT UNSIGNED NOT NULL,
    `label` VARCHAR(100) NOT NULL COMMENT 'Season display name',
    `is_active` TINYINT(1) NOT NULL DEFAULT 0,
    `start_ts` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Season start timestamp',
    `end_ts` BIGINT UNSIGNED DEFAULT 0 COMMENT 'Season end timestamp (0 = ongoing)',
    
    -- M+ specific configuration stored as JSON
    `featured_dungeons` JSON DEFAULT NULL COMMENT 'Array of featured dungeon IDs: [574, 575, 576, ...]',
    `affix_schedule` JSON DEFAULT NULL COMMENT 'Weekly affix rotation: [{week: 1, affixPairId: 1}, ...]',
    `reward_curve` JSON DEFAULT NULL COMMENT 'Level-based rewards: {1: {ilvl: 216, tokens: 30}, ...}',
    `scaling_config` JSON DEFAULT NULL COMMENT 'Difficulty scaling: {baseHealth: 1.0, baseDamage: 1.0, ...}',
    
    -- Metadata
    `description` TEXT DEFAULT NULL,
    `theme_color` VARCHAR(7) DEFAULT '#00ff00' COMMENT 'Hex color for UI',
    `icon_path` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`season_id`),
    KEY `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='M+ specific season config (affixes, dungeons, reward curves)';

-- Insert default season if table is empty
INSERT INTO `dc_mplus_seasons` 
    (`season_id`, `label`, `is_active`, `start_ts`, `featured_dungeons`, `reward_curve`, `description`)
SELECT 1, 'Season 1: The Beginning', 1, UNIX_TIMESTAMP(), 
    '[574, 575, 576, 578, 595, 599, 600, 601]',
    '{"2": {"ilvl": 200, "tokens": 10}, "5": {"ilvl": 213, "tokens": 20}, "10": {"ilvl": 226, "tokens": 40}, "15": {"ilvl": 239, "tokens": 80}}',
    'The first Mythic+ season featuring classic dungeons'
WHERE NOT EXISTS (SELECT 1 FROM `dc_mplus_seasons` LIMIT 1);

SELECT '✅ Mythic+ Season Config Table Created/Verified' AS status;

-- ========================================================================
-- Verify JSON columns work (MariaDB 10.2+ / MySQL 5.7+)
-- ========================================================================

SELECT '📋 Verifying JSON Support...' AS step;

-- Test JSON functions work
SELECT 
    season_id,
    label,
    is_active,
    JSON_LENGTH(featured_dungeons) AS dungeon_count,
    JSON_KEYS(reward_curve) AS reward_levels
FROM dc_mplus_seasons
WHERE is_active = 1
LIMIT 1;

SELECT '✅ JSON Support Verified' AS status;

-- ========================================================================
-- VERIFICATION
-- ========================================================================

SELECT '========================================' AS divider;
SELECT '✅ WORLD DB TABLES CREATED' AS final_status;
SELECT '========================================' AS divider;

SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024, 2) AS 'Size_KB',
    TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_world'
AND TABLE_NAME = 'dc_mplus_seasons'
ORDER BY TABLE_NAME;

-- Show the active season
SELECT 
    season_id,
    label,
    is_active,
    FROM_UNIXTIME(start_ts) AS start_date,
    description
FROM dc_mplus_seasons
WHERE is_active = 1;

SELECT '========================================' AS divider;
SELECT 'Table: dc_mplus_seasons' AS table_name;
SELECT 'Status: Ready for use' AS status;
SELECT '========================================' AS divider;
