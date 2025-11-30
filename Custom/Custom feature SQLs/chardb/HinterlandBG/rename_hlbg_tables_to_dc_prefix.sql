-- =============================================================================
-- Migration: Rename hlbg_* tables to dc_hlbg_* for naming consistency
-- Date: 2025-11-30
-- Database: acore_characters (CharDB)
-- 
-- This migration renames the following tables:
--   hlbg_player_stats   -> dc_hlbg_player_stats
--   hlbg_winner_history -> dc_hlbg_winner_history  
--   hlbg_seasons        -> dc_hlbg_seasons
--   hlbg_affixes        -> dc_hlbg_affixes
--
-- Run this ONCE on your characters database after backing up!
-- =============================================================================

-- Check if old tables exist before renaming

-- Rename hlbg_player_stats -> dc_hlbg_player_stats
SET @table_exists = (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'hlbg_player_stats');
SET @new_exists = (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'dc_hlbg_player_stats');
SET @sql = IF(@table_exists > 0 AND @new_exists = 0, 'RENAME TABLE hlbg_player_stats TO dc_hlbg_player_stats', 'SELECT "hlbg_player_stats already migrated or does not exist" AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Rename hlbg_winner_history -> dc_hlbg_winner_history
SET @table_exists = (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'hlbg_winner_history');
SET @new_exists = (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'dc_hlbg_winner_history');
SET @sql = IF(@table_exists > 0 AND @new_exists = 0, 'RENAME TABLE hlbg_winner_history TO dc_hlbg_winner_history', 'SELECT "hlbg_winner_history already migrated or does not exist" AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Rename hlbg_seasons -> dc_hlbg_seasons
SET @table_exists = (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'hlbg_seasons');
SET @new_exists = (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'dc_hlbg_seasons');
SET @sql = IF(@table_exists > 0 AND @new_exists = 0, 'RENAME TABLE hlbg_seasons TO dc_hlbg_seasons', 'SELECT "hlbg_seasons already migrated or does not exist" AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Rename hlbg_affixes -> dc_hlbg_affixes
SET @table_exists = (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'hlbg_affixes');
SET @new_exists = (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'dc_hlbg_affixes');
SET @sql = IF(@table_exists > 0 AND @new_exists = 0, 'RENAME TABLE hlbg_affixes TO dc_hlbg_affixes', 'SELECT "hlbg_affixes already migrated or does not exist" AS status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Verification: Show all dc_hlbg_* tables after migration
SELECT table_name, table_rows 
FROM information_schema.tables 
WHERE table_schema = DATABASE() 
  AND table_name LIKE 'dc_hlbg%'
ORDER BY table_name;

-- Also show if any old hlbg_* tables remain (should be empty after successful migration)
SELECT table_name AS 'OLD TABLES REMAINING (should be empty)'
FROM information_schema.tables 
WHERE table_schema = DATABASE() 
  AND table_name LIKE 'hlbg_%'
  AND table_name NOT LIKE 'dc_hlbg%'
ORDER BY table_name;
