-- ========================================================================
-- MIGRATION: Consolidate HLBG + M+ seasons into dc_seasons (acore_world)
-- ========================================================================
-- Purpose: Create dc_seasons, migrate data from world DB season tables,
--          then drop legacy dc_hlbg_seasons and dc_mplus_seasons.
--
-- Databases:
--   - Target: acore_world (dc_seasons)
--   - Sources: acore_world.dc_hlbg_seasons, acore_world.dc_mplus_seasons
--
-- NOTE:
--   - This script is SAFE to run multiple times.
--   - It handles both legacy M+ schema (season/name/start_date)
--     and newer M+ schema (season_id/label/start_ts).
-- ========================================================================

USE acore_world;

-- Create dc_seasons if missing (full schema expected by SeasonalSystem)
CREATE TABLE IF NOT EXISTS `dc_seasons` (
  `season_id` int unsigned NOT NULL,
  `season_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `season_description` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT 'Season description text',
  `season_type` tinyint unsigned DEFAULT '0' COMMENT '0=Normal, 1=Special, 2=Event',
  `season_state` tinyint unsigned DEFAULT '0' COMMENT '0=Inactive, 1=Active, 2=Transitioning, 3=Maintenance',
  `start_timestamp` bigint unsigned NOT NULL,
  `end_timestamp` bigint unsigned DEFAULT '0',
  `created_timestamp` bigint unsigned DEFAULT '0' COMMENT 'When season was created',
  `allow_carryover` tinyint(1) DEFAULT '0' COMMENT 'Allow stats to carry over to next season',
  `carryover_percentage` float DEFAULT '0' COMMENT 'Percentage of stats to carry over (0.0-1.0)',
  `reset_on_end` tinyint(1) DEFAULT '1' COMMENT 'Reset all stats when season ends',
  `theme_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT 'Season theme identifier',
  `banner_path` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT 'Path to season banner image',
  `is_active` tinyint(1) NOT NULL DEFAULT '0',
  `max_upgrade_level` tinyint unsigned NOT NULL DEFAULT '15',
  `cost_multiplier` float NOT NULL DEFAULT '1',
  `reward_multiplier` float NOT NULL DEFAULT '1',
  `theme` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `milestone_essence_cap` int unsigned NOT NULL DEFAULT '50000',
  `milestone_token_cap` int unsigned NOT NULL DEFAULT '25000',
  PRIMARY KEY (`season_id`),
  KEY `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Season configuration';

-- Procedure for safe migration (handles multiple source schemas)
DROP PROCEDURE IF EXISTS `dc_migrate_seasons`;
DELIMITER //
CREATE PROCEDURE `dc_migrate_seasons`()
BEGIN
  DROP TEMPORARY TABLE IF EXISTS `tmp_dc_seasons`;
  CREATE TEMPORARY TABLE `tmp_dc_seasons` (
    `season_id` int unsigned NOT NULL,
    `season_name` varchar(100) NOT NULL,
    `season_description` varchar(500) DEFAULT '',
    `start_timestamp` bigint unsigned DEFAULT 0,
    `end_timestamp` bigint unsigned DEFAULT 0,
    `is_active` tinyint unsigned DEFAULT 0
  ) ENGINE=MEMORY;

  -- HLBG seasons (legacy)
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
     WHERE table_schema = 'acore_world' AND table_name = 'dc_hlbg_seasons'
  ) THEN
    INSERT INTO `tmp_dc_seasons` (`season_id`, `season_name`, `season_description`, `start_timestamp`, `end_timestamp`, `is_active`)
    SELECT
      `season`,
      `name`,
      COALESCE(`description`, ''),
      UNIX_TIMESTAMP(`start_date`),
      IFNULL(UNIX_TIMESTAMP(`end_date`), 0),
      `is_active`
    FROM `dc_hlbg_seasons`;
  END IF;

  -- M+ seasons (new schema: season_id/label/start_ts)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'acore_world' AND table_name = 'dc_mplus_seasons' AND column_name = 'season_id'
  ) THEN
    INSERT INTO `tmp_dc_seasons` (`season_id`, `season_name`, `season_description`, `start_timestamp`, `end_timestamp`, `is_active`)
    SELECT
      `season_id`,
      `label`,
      '',
      `start_ts`,
      IFNULL(`end_ts`, 0),
      `is_active`
    FROM `dc_mplus_seasons`;
  ELSEIF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'acore_world' AND table_name = 'dc_mplus_seasons' AND column_name = 'season'
  ) THEN
    -- M+ seasons (legacy schema: season/name/start_date)
    INSERT INTO `tmp_dc_seasons` (`season_id`, `season_name`, `season_description`, `start_timestamp`, `end_timestamp`, `is_active`)
    SELECT
      `season`,
      `name`,
      COALESCE(`description`, ''),
      UNIX_TIMESTAMP(`start_date`),
      IFNULL(UNIX_TIMESTAMP(`end_date`), 0),
      `is_active`
    FROM `dc_mplus_seasons`;
  END IF;

  -- Merge into dc_seasons
  INSERT INTO `dc_seasons` (
    `season_id`,
    `season_name`,
    `season_description`,
    `season_type`,
    `season_state`,
    `start_timestamp`,
    `end_timestamp`,
    `created_timestamp`,
    `allow_carryover`,
    `carryover_percentage`,
    `reset_on_end`,
    `theme_name`,
    `banner_path`,
    `is_active`,
    `max_upgrade_level`,
    `cost_multiplier`,
    `reward_multiplier`,
    `theme`,
    `milestone_essence_cap`,
    `milestone_token_cap`
  )
  SELECT
    `season_id`,
    COALESCE(MAX(`season_name`), CONCAT('Season ', `season_id`)),
    COALESCE(MAX(`season_description`), ''),
    0,
    CASE WHEN MAX(`is_active`) = 1 THEN 1 ELSE 0 END,
    COALESCE(MIN(`start_timestamp`), 0),
    COALESCE(MAX(`end_timestamp`), 0),
    UNIX_TIMESTAMP(),
    0,
    0,
    1,
    '',
    '',
    MAX(`is_active`),
    15,
    1,
    1,
    NULL,
    50000,
    25000
  FROM `tmp_dc_seasons`
  GROUP BY `season_id`
  ON DUPLICATE KEY UPDATE
    `season_name` = VALUES(`season_name`),
    `season_description` = VALUES(`season_description`),
    `season_state` = VALUES(`season_state`),
    `start_timestamp` = VALUES(`start_timestamp`),
    `end_timestamp` = VALUES(`end_timestamp`),
    `is_active` = VALUES(`is_active`);

  DROP TEMPORARY TABLE IF EXISTS `tmp_dc_seasons`;
END//
DELIMITER ;

CALL `dc_migrate_seasons`();
DROP PROCEDURE IF EXISTS `dc_migrate_seasons`;

-- Drop legacy season tables (world DB)
DROP TABLE IF EXISTS `dc_hlbg_seasons`;
DROP TABLE IF EXISTS `dc_mplus_seasons`;

SELECT '✅ dc_seasons created and legacy tables dropped' AS status;
