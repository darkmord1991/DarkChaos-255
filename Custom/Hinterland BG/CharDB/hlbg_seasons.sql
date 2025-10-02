-- Migration: Create hlbg_seasons table and link to winner history via season number
-- Characters DB

CREATE TABLE IF NOT EXISTS `hlbg_seasons` (
  `season` INT UNSIGNED NOT NULL,
  `name` VARCHAR(64) NOT NULL,
  `description` TEXT NULL,
  `starts_at` DATETIME NULL,
  `ends_at` DATETIME NULL,
  PRIMARY KEY (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Optional seed for Season 1 if missing
INSERT INTO `hlbg_seasons` (`season`, `name`) SELECT 1, 'Season 1'
  WHERE NOT EXISTS (SELECT 1 FROM `hlbg_seasons` WHERE `season`=1);

-- Add a foreign key link if not already present (best-effort; MySQL requires index and exact types)
-- Ensure hlbg_winner_history.season exists and is indexed
SET @has_col := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_winner_history' AND COLUMN_NAME = 'season'
);
SET @has_fk := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_hlbg_history_season'
);
SET @stmt := IF(@has_col = 1 AND @has_fk = 0,
  'ALTER TABLE `hlbg_winner_history` ADD CONSTRAINT `fk_hlbg_history_season` FOREIGN KEY (`season`) REFERENCES `hlbg_seasons`(`season`) ON UPDATE CASCADE ON DELETE RESTRICT',
  'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;
