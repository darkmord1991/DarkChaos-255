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
-- dc_hlbg_season_config (acore_chars)
-- Configuration settings for each HLBG season
-- Used by: HLBGSeasonalParticipant.cpp - InitializeSeasonData()
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_hlbg_season_config` (
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season identifier',
  `base_rating` INT UNSIGNED NOT NULL DEFAULT 1500 COMMENT 'Base rating for new players',
  `max_rating_change` INT UNSIGNED NOT NULL DEFAULT 50 COMMENT 'Maximum rating change per match',
  `min_players_per_team` TINYINT UNSIGNED NOT NULL DEFAULT 5 COMMENT 'Minimum players required per team',
  `max_players_per_team` TINYINT UNSIGNED NOT NULL DEFAULT 10 COMMENT 'Maximum players allowed per team',
  `match_duration` INT UNSIGNED NOT NULL DEFAULT 1800 COMMENT 'Match duration in seconds',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='HLBG season configuration';

-- -----------------------------------------------------------------------------
-- dc_hlbg_player_season_data (acore_chars)
-- Player statistics for each HLBG season
-- Used by: HLBGSeasonalParticipant.cpp - Multiple functions for player stats
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_hlbg_player_season_data` (
  `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID',
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season identifier',
  `joined_at` INT UNSIGNED NOT NULL COMMENT 'Unix timestamp when player joined season',
  `rating` INT UNSIGNED NOT NULL DEFAULT 1500 COMMENT 'Current rating',
  `completed_games` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total games completed',
  `wins` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total wins',
  `losses` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total losses',
  `highest_rating` INT UNSIGNED NOT NULL DEFAULT 1500 COMMENT 'Highest rating achieved this season',
  `lowest_rating` INT UNSIGNED NOT NULL DEFAULT 1500 COMMENT 'Lowest rating this season',
  `total_score` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Cumulative score from all games',
  `average_score` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Average score per game',
  PRIMARY KEY (`player_guid`, `season_id`),
  KEY `idx_season_rating` (`season_id`, `rating` DESC),
  KEY `idx_season_wins` (`season_id`, `wins` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='HLBG player seasonal statistics';

-- -----------------------------------------------------------------------------
-- dc_hlbg_player_history (acore_chars)
-- Archived player data from previous seasons
-- Used by: HLBGSeasonalParticipant.cpp - ArchivePlayerData()
-- Note: This is in DEPRECATED_TABLES in dc_table_checker.lua but still used
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_hlbg_player_history` (
  `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID',
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season identifier',
  `joined_at` INT UNSIGNED NOT NULL COMMENT 'Unix timestamp when player joined season',
  `rating` INT UNSIGNED NOT NULL DEFAULT 1500 COMMENT 'Final rating',
  `completed_games` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total games completed',
  `wins` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total wins',
  `losses` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total losses',
  `highest_rating` INT UNSIGNED NOT NULL DEFAULT 1500 COMMENT 'Highest rating achieved',
  `lowest_rating` INT UNSIGNED NOT NULL DEFAULT 1500 COMMENT 'Lowest rating',
  `total_score` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Cumulative score',
  `average_score` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Average score',
  `archived_at` INT UNSIGNED NOT NULL COMMENT 'Unix timestamp when archived',
  PRIMARY KEY (`player_guid`, `season_id`),
  KEY `idx_season` (`season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='HLBG archived player history';

-- -----------------------------------------------------------------------------
-- dc_hlbg_match_history (acore_chars)  
-- Archived match data from previous seasons
-- Used by: HLBGSeasonalParticipant.cpp - ArchiveSeasonData()
-- Note: This is in DEPRECATED_TABLES in dc_table_checker.lua but still used
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_hlbg_match_history` (
  `match_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `start_time` INT UNSIGNED NOT NULL COMMENT 'Match start timestamp',
  `end_time` INT UNSIGNED DEFAULT NULL COMMENT 'Match end timestamp',
  `winner_team` TINYINT DEFAULT NULL COMMENT 'Winning team (1 or 2)',
  `team1_score` INT NOT NULL DEFAULT 0,
  `team2_score` INT NOT NULL DEFAULT 0,
  `player_count` TINYINT NOT NULL DEFAULT 0,
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season this match belongs to',
  PRIMARY KEY (`match_id`),
  KEY `idx_season` (`season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='HLBG archived match history';
