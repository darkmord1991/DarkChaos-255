-- Migration: Add season column to hlbg_winner_history and supporting indexes
-- Safe to run multiple times: checks for column existence before altering

SET @tbl := 'hlbg_winner_history';

-- Add season column if it doesn't exist (default 1)
SET @stmt := IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @tbl AND COLUMN_NAME = 'season') = 0,
  'ALTER TABLE hlbg_winner_history ADD COLUMN `season` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `map_id`',
  'SELECT 1'
);
PREPARE x FROM @stmt; EXECUTE x; DEALLOCATE PREPARE x;

-- Add index on season if it doesn't exist
SET @idx := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @tbl AND INDEX_NAME = 'idx_season');
SET @stmt2 := IF(@idx = 0, 'ALTER TABLE hlbg_winner_history ADD INDEX `idx_season` (`season`)', 'SELECT 1');
PREPARE y FROM @stmt2; EXECUTE y; DEALLOCATE PREPARE y;

-- Optional: backfill season for existing rows if you want a global default other than 1
-- UPDATE hlbg_winner_history SET season = 1 WHERE season IS NULL;
