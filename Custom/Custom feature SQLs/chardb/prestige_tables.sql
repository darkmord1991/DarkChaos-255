-- =====================================================================
-- DarkChaos-255 Prestige System - Character Database Tables
-- =====================================================================
-- Creates tables for tracking player prestige levels and history
-- =====================================================================

-- Table: character_prestige
-- Stores current prestige level for each character
DROP TABLE IF EXISTS `character_prestige`;
CREATE TABLE `character_prestige` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `prestige_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Current prestige level (0-10)',
  `prestige_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Date of last prestige',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Prestige levels for level 255 characters';

-- Table: character_prestige_log
-- Stores history of all prestige events for analytics
DROP TABLE IF EXISTS `character_prestige_log`;
CREATE TABLE `character_prestige_log` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Log entry ID',
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `prestige_level` TINYINT UNSIGNED NOT NULL COMMENT 'Prestige level achieved',
  `old_level` TINYINT UNSIGNED NOT NULL COMMENT 'Level before prestige',
  `new_level` TINYINT UNSIGNED NOT NULL COMMENT 'Level after prestige reset',
  `timestamp` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Prestige timestamp',
  PRIMARY KEY (`id`),
  KEY `idx_guid` (`guid`),
  KEY `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Prestige history log';

-- Table: character_prestige_stats
-- Stores aggregate statistics for leaderboards
DROP TABLE IF EXISTS `character_prestige_stats`;
CREATE TABLE `character_prestige_stats` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `total_prestiges` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total number of prestige resets',
  `highest_prestige` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Highest prestige level reached',
  `first_prestige_date` DATETIME NULL DEFAULT NULL COMMENT 'Date of first prestige',
  `last_prestige_date` DATETIME NULL DEFAULT NULL COMMENT 'Date of most recent prestige',
  `total_levels_gained` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total levels gained across all prestiges',
  PRIMARY KEY (`guid`),
  KEY `idx_highest_prestige` (`highest_prestige`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Prestige statistics and leaderboards';

-- =====================================================================
-- End of prestige tables
-- =====================================================================
