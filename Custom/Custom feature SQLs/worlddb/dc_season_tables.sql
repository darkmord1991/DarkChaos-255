-- ============================================================================
-- DC Season Configuration Tables for acore_world
-- These are server config tables, not character data
-- ============================================================================

-- HLBG Seasons
DROP TABLE IF EXISTS `dc_hlbg_seasons`;
CREATE TABLE `dc_hlbg_seasons` (
    `season` SMALLINT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Season number',
    `name` VARCHAR(64) NOT NULL DEFAULT 'Season' COMMENT 'Display name',
    `start_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Season start',
    `end_date` DATETIME NULL DEFAULT NULL COMMENT 'Season end (NULL = ongoing)',
    `is_active` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 = current active season',
    `description` TEXT NULL DEFAULT NULL COMMENT 'Season description'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='HLBG Season configuration';

-- M+ Seasons
DROP TABLE IF EXISTS `dc_mplus_seasons`;
CREATE TABLE `dc_mplus_seasons` (
    `season` SMALLINT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Season number',
    `name` VARCHAR(64) NOT NULL DEFAULT 'Season' COMMENT 'Display name',
    `start_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Season start',
    `end_date` DATETIME NULL DEFAULT NULL COMMENT 'Season end (NULL = ongoing)',
    `is_active` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 = current active season',
    `description` TEXT NULL DEFAULT NULL COMMENT 'Season description'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='M+ Season configuration';

-- ============================================================================
-- Default Data - Active Season 1
-- ============================================================================

INSERT INTO `dc_hlbg_seasons` (`season`, `name`, `start_date`, `end_date`, `is_active`, `description`) VALUES
(1, 'Season 1 - Launch', '2025-01-01 00:00:00', NULL, 1, 'First Hinterland BG season');

INSERT INTO `dc_mplus_seasons` (`season`, `name`, `start_date`, `end_date`, `is_active`, `description`) VALUES
(1, 'Season 1 - Launch', '2025-01-01 00:00:00', NULL, 1, 'First Mythic+ season');

-- ============================================================================
-- Verify
-- ============================================================================
SELECT 'dc_hlbg_seasons' AS table_name, COUNT(*) AS row_count, 
       (SELECT name FROM dc_hlbg_seasons WHERE is_active = 1 LIMIT 1) AS active_season
FROM dc_hlbg_seasons
UNION ALL
SELECT 'dc_mplus_seasons', COUNT(*), 
       (SELECT name FROM dc_mplus_seasons WHERE is_active = 1 LIMIT 1)
FROM dc_mplus_seasons;
