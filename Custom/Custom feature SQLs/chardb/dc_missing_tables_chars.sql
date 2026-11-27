-- =============================================================================
-- DC Missing Tables - CREATE TABLE statements
-- Generated: 2026-01-03
--
-- Run this in acore_chars database to create missing tables
-- =============================================================================

-- -----------------------------------------------------------------------------
-- dc_character_prestige_stats (acore_chars)
-- Tracks prestige statistics for characters
-- Used by: Prestige system for statistics display and leaderboards
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_character_prestige_stats` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `total_prestiges` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total number of prestige resets',
  `highest_prestige` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Highest prestige level reached',
  `first_prestige_date` DATETIME DEFAULT NULL COMMENT 'Date of first prestige',
  `last_prestige_date` DATETIME DEFAULT NULL COMMENT 'Date of most recent prestige',
  `total_levels_gained` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total levels gained across all prestiges',
  PRIMARY KEY (`guid`),
  KEY `idx_highest_prestige` (`highest_prestige`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Prestige statistics and leaderboards';

-- -----------------------------------------------------------------------------
-- dc_hlbg_match_participants (acore_chars)
-- Unified per-match HLBG participant stats
-- Used by: HLBG addon seasonal/all-time fallback queries and leaderboard views
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_hlbg_match_participants` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique participant record ID',
  `match_id` INT UNSIGNED NOT NULL COMMENT 'Foreign key to dc_hlbg_winner_history.id (the match ID)',
  `guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID',
  `player_name` VARCHAR(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Player name (denormalized for convenience)',
  `account_id` INT UNSIGNED NOT NULL COMMENT 'Account ID (denormalized)',
  `account_name` VARCHAR(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Account name (denormalized)',
  `team` TINYINT NOT NULL COMMENT 'Team number (0=Alliance, 1=Horde)',
  `season_id` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season when match occurred',
  `match_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When match was played',
  `kills` INT UNSIGNED NOT NULL DEFAULT 0,
  `deaths` INT UNSIGNED NOT NULL DEFAULT 0,
  `healing_done` INT UNSIGNED NOT NULL DEFAULT 0,
  `damage_done` INT UNSIGNED NOT NULL DEFAULT 0,
  `resources_captured` INT UNSIGNED NOT NULL DEFAULT 0,
  `flags_returned` INT UNSIGNED NOT NULL DEFAULT 0,
  `objectives_completed` INT UNSIGNED NOT NULL DEFAULT 0,
  `rating_change` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_guid` (`guid`),
  KEY `idx_match_id` (`match_id`),
  KEY `idx_account` (`account_id`),
  KEY `idx_season` (`season_id`),
  KEY `idx_date` (`match_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tracks individual player statistics for each HLBG match';

-- -----------------------------------------------------------------------------
-- dc_hlbg_player_stats (acore_chars)
-- HLBG all-time player counters
-- Used by: HLBG all-time leaderboard queries
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_hlbg_player_stats` (
  `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID (unique identifier)',
  `player_name` VARCHAR(12) NOT NULL COMMENT 'Player character name',
  `faction` VARCHAR(16) NOT NULL DEFAULT 'Unknown' COMMENT 'Alliance or Horde',
  `battles_participated` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total battles joined',
  `battles_won` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total battles won',
  `last_participation` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Last battle timestamp',
  `total_kills` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total player kills',
  `total_deaths` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total deaths',
  `resources_captured` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total resources captured',
  PRIMARY KEY (`player_guid`),
  KEY `idx_player_name` (`player_name`),
  KEY `idx_faction` (`faction`),
  KEY `idx_battles_won` (`battles_won`),
  KEY `idx_total_kills` (`total_kills`),
  KEY `idx_last_participation` (`last_participation`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='HLBG player all-time statistics';

-- -----------------------------------------------------------------------------
-- dc_hlbg_winner_history (acore_chars)
-- Primary HLBG match result history
-- Used by: HLBG history, scoreboard, addon stats, and unified seasonal views
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_hlbg_winner_history` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique battle identifier',
  `season` SMALLINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season number',
  `occurred_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Battle end timestamp',
  `duration_seconds` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Battle duration in seconds',
  `zone_id` SMALLINT UNSIGNED NOT NULL DEFAULT 26 COMMENT 'Zone ID (26 = Hinterlands)',
  `map_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Map ID',
  `winner_tid` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT 'Winner: 0=Alliance, 1=Horde, 2=Draw',
  `win_reason` VARCHAR(32) NOT NULL DEFAULT 'depletion' COMMENT 'Win reason: depletion, tiebreaker, manual',
  `score_alliance` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Final Alliance resource count',
  `score_horde` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Final Horde resource count',
  `affix` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Affix ID',
  `weather` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Weather type',
  `weather_intensity` FLOAT NOT NULL DEFAULT 0 COMMENT 'Weather intensity (0.0-1.0)',
  PRIMARY KEY (`id`),
  KEY `idx_season` (`season`),
  KEY `idx_occurred_at` (`occurred_at`),
  KEY `idx_winner_tid` (`winner_tid`),
  KEY `idx_affix` (`affix`),
  KEY `idx_weather` (`weather`),
  KEY `idx_win_reason` (`win_reason`),
  KEY `idx_season_occurred` (`season`, `occurred_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='HLBG battle history';
