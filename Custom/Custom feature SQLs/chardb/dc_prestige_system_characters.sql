-- =====================================================================
-- DarkChaos-255 Prestige System - Character Database Tables
-- =====================================================================
-- This file contains SQL updates for the acore_characters database
-- Execute this on your character database
-- =====================================================================
-- =====================================================================
-- Main Prestige Tracking Table
-- =====================================================================
-- Stores current prestige level for each character
-- =====================================================================

CREATE TABLE IF NOT EXISTS `dc_character_prestige` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `prestige_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Current prestige level (0-10)',
  `total_prestiges` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total number of times prestiged',
  `last_prestige_time` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Unix timestamp of last prestige',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos: Tracks player prestige levels';

-- =====================================================================
-- Prestige History Log
-- =====================================================================
-- Logs every prestige event for audit trail and statistics
-- =====================================================================

CREATE TABLE IF NOT EXISTS `dc_character_prestige_log` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `prestige_level` TINYINT UNSIGNED NOT NULL COMMENT 'Prestige level achieved',
  `prestige_time` INT UNSIGNED NOT NULL COMMENT 'Unix timestamp',
  `from_level` TINYINT UNSIGNED NOT NULL COMMENT 'Level before prestige',
  `kept_gear` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Whether gear was kept',
  PRIMARY KEY (`id`),
  KEY `idx_guid` (`guid`),
  KEY `idx_time` (`prestige_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos: Log of all prestige events';

-- =====================================================================
-- Prestige Statistics
-- =====================================================================
-- Tracks how many players are at each prestige level (leaderboard data)
-- =====================================================================

CREATE TABLE IF NOT EXISTS `dc_character_prestige_stats` (
  `prestige_level` TINYINT UNSIGNED NOT NULL,
  `total_players` INT UNSIGNED NOT NULL DEFAULT 0,
  `last_updated` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`prestige_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos: Statistics for prestige levels';

-- =====================================================================
-- Initialize Statistics Table
-- =====================================================================
-- Pre-populate with all prestige levels (0-10)
-- =====================================================================

INSERT IGNORE INTO `dc_character_prestige_stats` (`prestige_level`, `total_players`, `last_updated`) VALUES
(0, 0, UNIX_TIMESTAMP()),
(1, 0, UNIX_TIMESTAMP()),
(2, 0, UNIX_TIMESTAMP()),
(3, 0, UNIX_TIMESTAMP()),
(4, 0, UNIX_TIMESTAMP()),
(5, 0, UNIX_TIMESTAMP()),
(6, 0, UNIX_TIMESTAMP()),
(7, 0, UNIX_TIMESTAMP()),
(8, 0, UNIX_TIMESTAMP()),
(9, 0, UNIX_TIMESTAMP()),
(10, 0, UNIX_TIMESTAMP());

-- =====================================================================
-- Verification Query
-- =====================================================================
-- After running this script, verify the tables were created:
-- SELECT * FROM dc_character_prestige;
-- SELECT * FROM dc_character_prestige_log;
-- SELECT * FROM dc_character_prestige_stats;
-- =====================================================================
