-- Database: acore_characters
-- Mythic Plus Optimization Tables
-- Mythic+ HUD Cache Table
CREATE TABLE IF NOT EXISTS `dc_mplus_hud_cache` (
  `instance_key` BIGINT UNSIGNED NOT NULL,
  `map_id` INT UNSIGNED NOT NULL,
  `instance_id` INT UNSIGNED NOT NULL,
  `owner_guid` INT UNSIGNED NOT NULL,
  `keystone_level` TINYINT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `payload` LONGTEXT NOT NULL,
  `updated_at` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`instance_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Optimization Indexes from Evaluation
ALTER TABLE dc_mplus_runs ADD INDEX idx_player_season (player_guid, season_id);
ALTER TABLE dc_mplus_runs ADD INDEX idx_map_level (map_id, keystone_level);
ALTER TABLE dc_mplus_runs ADD INDEX idx_completion (completed_at);
ALTER TABLE dc_mplus_scores ADD INDEX idx_season_score (season_id, best_score DESC);

-- New Tracking Tables
CREATE TABLE IF NOT EXISTS `dc_mythic_weekly_best` (
  `week_start` INT UNSIGNED NOT NULL,
  `player_guid` INT UNSIGNED NOT NULL,
  `map_id` INT UNSIGNED NOT NULL,
  `keystone_level` TINYINT UNSIGNED NOT NULL,
  `score` INT UNSIGNED NOT NULL,
  `completion_time` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`week_start`, `player_guid`, `map_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dc_mythic_dungeon_stats` (
  `season_id` INT UNSIGNED NOT NULL,
  `map_id` INT UNSIGNED NOT NULL,
  `keystone_level` TINYINT UNSIGNED NOT NULL,
  `runs_started` INT UNSIGNED DEFAULT 0,
  `runs_completed` INT UNSIGNED DEFAULT 0,
  `total_time` BIGINT UNSIGNED DEFAULT 0,
  `deaths_total` INT UNSIGNED DEFAULT 0,
  PRIMARY KEY (`season_id`, `map_id`, `keystone_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
