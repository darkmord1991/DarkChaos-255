-- Migration: Add weather columns to hlbg_winner_history and supporting index
-- Characters DB

SET @tbl := 'hlbg_winner_history';

-- Add weather column (type) if missing
SET @stmt := IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @tbl AND COLUMN_NAME = 'weather') = 0,
  'ALTER TABLE hlbg_winner_history ADD COLUMN `weather` TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER `affix`',
  'SELECT 1'
);
PREPARE s1 FROM @stmt; EXECUTE s1; DEALLOCATE PREPARE s1;

-- Add weather_intensity column if missing (0..1 float)
SET @stmt2 := IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @tbl AND COLUMN_NAME = 'weather_intensity') = 0,
  'ALTER TABLE hlbg_winner_history ADD COLUMN `weather_intensity` FLOAT NOT NULL DEFAULT 0 AFTER `weather`',
  'SELECT 1'
);
PREPARE s2 FROM @stmt2; EXECUTE s2; DEALLOCATE PREPARE s2;

-- Add index on weather if missing
SET @has_idx := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @tbl AND INDEX_NAME = 'idx_weather');
SET @stmt3 := IF(@has_idx = 0, 'ALTER TABLE hlbg_winner_history ADD INDEX `idx_weather` (`weather`)', 'SELECT 1');
PREPARE s3 FROM @stmt3; EXECUTE s3; DEALLOCATE PREPARE s3;
