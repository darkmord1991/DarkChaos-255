-- Create Hinterland BG winner history table in characters DB

CREATE TABLE IF NOT EXISTS `hlbg_winner_history` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `occurred_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `zone_id` INT UNSIGNED NOT NULL DEFAULT 47,
  `map_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `season` INT UNSIGNED NOT NULL DEFAULT 1,
  `winner_tid` TINYINT UNSIGNED NOT NULL, -- 0=Alliance,1=Horde,2=Neutral (TeamId)
  `score_alliance` INT UNSIGNED NOT NULL DEFAULT 0,
  `score_horde` INT UNSIGNED NOT NULL DEFAULT 0,
  `win_reason` ENUM('depletion','tiebreaker','draw','manual') NOT NULL DEFAULT 'tiebreaker',
  `affix` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `weather` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `weather_intensity` FLOAT NOT NULL DEFAULT 0,
  `duration_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  INDEX `idx_time` (`occurred_at`),
  INDEX `idx_winner` (`winner_tid`),
  INDEX `idx_affix` (`affix`),
  INDEX `idx_weather` (`weather`),
  INDEX `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
