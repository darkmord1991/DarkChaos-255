-- ========================================================================
-- DarkChaos Mythic+ System - Flag playerbot participants in run history
-- ========================================================================
-- Purpose: dc_mplus_runs gets one row per participant. Bots backfilled by
--          the Group Finder ride along in keystone runs and keep their rows;
--          this flag lets the leaderboards label them "BOT <name>".
-- Database: acore_characters
-- Date: September 2026
-- ========================================================================

USE acore_characters;

SET @exist := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = DATABASE()
               AND TABLE_NAME = 'dc_mplus_runs'
               AND COLUMN_NAME = 'is_bot');

SET @sqlstmt := IF(@exist = 0,
    'ALTER TABLE `dc_mplus_runs`
     ADD COLUMN `is_bot` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''1 = this participant row belongs to a playerbot'' AFTER `group_members`',
    'SELECT ''Column is_bot already exists, skipping...'' AS message');

PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
