-- ========================================================================
-- FIX: dc_seasons table schema - Add missing columns
-- ========================================================================
-- Database: ac_chars
-- Purpose: Add columns expected by SeasonalSystem.cpp
-- Date: November 22, 2025
-- ========================================================================

USE acore_chars;

-- Add missing columns to dc_seasons table (one at a time to avoid IF NOT EXISTS issues)
ALTER TABLE `dc_seasons` ADD COLUMN `season_description` VARCHAR(500) DEFAULT '' COMMENT 'Season description text' AFTER `season_name`;
ALTER TABLE `dc_seasons` ADD COLUMN `season_type` TINYINT UNSIGNED DEFAULT 0 COMMENT '0=Normal, 1=Special, 2=Event' AFTER `season_description`;
ALTER TABLE `dc_seasons` ADD COLUMN `season_state` TINYINT UNSIGNED DEFAULT 0 COMMENT '0=Inactive, 1=Active, 2=Transitioning, 3=Maintenance' AFTER `season_type`;
ALTER TABLE `dc_seasons` ADD COLUMN `created_timestamp` BIGINT UNSIGNED DEFAULT 0 COMMENT 'When season was created' AFTER `end_timestamp`;
ALTER TABLE `dc_seasons` ADD COLUMN `allow_carryover` BOOLEAN DEFAULT FALSE COMMENT 'Allow stats to carry over to next season' AFTER `created_timestamp`;
ALTER TABLE `dc_seasons` ADD COLUMN `carryover_percentage` FLOAT DEFAULT 0.0 COMMENT 'Percentage of stats to carry over (0.0-1.0)' AFTER `allow_carryover`;
ALTER TABLE `dc_seasons` ADD COLUMN `reset_on_end` BOOLEAN DEFAULT TRUE COMMENT 'Reset all stats when season ends' AFTER `carryover_percentage`;
ALTER TABLE `dc_seasons` ADD COLUMN `theme_name` VARCHAR(100) DEFAULT '' COMMENT 'Season theme identifier' AFTER `reset_on_end`;
ALTER TABLE `dc_seasons` ADD COLUMN `banner_path` VARCHAR(255) DEFAULT '' COMMENT 'Path to season banner image' AFTER `theme_name`;

-- Update existing Season 1 with proper values
UPDATE `dc_seasons` 
SET 
  `season_description` = 'The beginning of artifact mastery and seasonal progression',
  `season_type` = 0,
  `season_state` = 1,  -- Active
  `created_timestamp` = `start_timestamp`,
  `allow_carryover` = FALSE,
  `carryover_percentage` = 0.0,
  `reset_on_end` = TRUE,
  `theme_name` = 'awakening',
  `banner_path` = ''
WHERE `season_id` = 1;

-- Rename is_active to maintain compatibility (optional - keeps both columns)
-- The code uses season_state instead of is_active

-- Verification
SELECT 
  season_id,
  season_name,
  season_description,
  season_type,
  season_state,
  is_active,
  IFNULL(theme_name, 'none') as theme
FROM dc_seasons;

SELECT '✅ dc_seasons schema updated successfully' AS status;
