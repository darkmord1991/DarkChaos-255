-- Migration: add duration_seconds column and idx_affix safely (idempotent)
-- Target DB: characters

-- Add duration_seconds column if missing
SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'hlbg_winner_history'
    AND column_name = 'duration_seconds'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE hlbg_winner_history ADD COLUMN duration_seconds INT UNSIGNED NOT NULL DEFAULT 0 AFTER affix',
  'DO 0'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Create idx_affix if missing
SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'hlbg_winner_history'
    AND index_name = 'idx_affix'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX idx_affix ON hlbg_winner_history (affix)',
  'DO 0'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
