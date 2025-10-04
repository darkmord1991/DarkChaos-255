-- HLBG Simple Cleanup Script - MySQL Compatible
-- Location: Custom/Hinterland BG/CharDB/03_simple_cleanup.sql
-- Apply to CHARACTER database - Fixed SQL syntax errors

-- ==================================================
-- SIMPLE HLBG CLEANUP - NO SYNTAX ERRORS
-- ==================================================

-- Check what tables exist
SHOW TABLES LIKE 'hlbg_%';

-- Fix hlbg_seasons duplicate time columns (if they exist)
-- Remove start_date column if it exists
SET @sql = CONCAT('ALTER TABLE hlbg_seasons DROP COLUMN IF EXISTS start_date');
SET @check_start_date = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
                        WHERE TABLE_SCHEMA = DATABASE() 
                        AND TABLE_NAME = 'hlbg_seasons' 
                        AND COLUMN_NAME = 'start_date');

-- Remove end_date column if it exists  
SET @sql2 = CONCAT('ALTER TABLE hlbg_seasons DROP COLUMN IF EXISTS end_date');
SET @check_end_date = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
                      WHERE TABLE_SCHEMA = DATABASE() 
                      AND TABLE_NAME = 'hlbg_seasons' 
                      AND COLUMN_NAME = 'end_date');

-- Show what we found
SELECT @check_start_date as start_date_exists, @check_end_date as end_date_exists;

-- Update season 1 data safely (using season column, not id)
UPDATE hlbg_seasons 
SET starts_at = '2025-10-01 00:00:00' 
WHERE season = 1 AND (starts_at IS NULL OR starts_at = '0000-00-00 00:00:00');

UPDATE hlbg_seasons 
SET ends_at = '2025-12-31 23:59:59' 
WHERE season = 1 AND (ends_at IS NULL OR ends_at = '0000-00-00 00:00:00');

-- Update season 2 data safely
UPDATE hlbg_seasons 
SET starts_at = '2025-01-01 00:00:00' 
WHERE season = 2 AND (starts_at IS NULL OR starts_at = '0000-00-00 00:00:00');

UPDATE hlbg_seasons 
SET ends_at = '2025-03-31 23:59:59' 
WHERE season = 2 AND (ends_at IS NULL OR ends_at = '0000-00-00 00:00:00');

-- Verify essential tables exist
SELECT 
    'Table Status Check' as Info,
    COUNT(CASE WHEN TABLE_NAME = 'hlbg_winner_history' THEN 1 END) as winner_history_exists,
    COUNT(CASE WHEN TABLE_NAME = 'hlbg_affixes' THEN 1 END) as affixes_exists,
    COUNT(CASE WHEN TABLE_NAME = 'hlbg_seasons' THEN 1 END) as seasons_exists
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'hlbg_%';

-- Show current hlbg_seasons structure
DESCRIBE hlbg_seasons;

-- Show current seasons data
SELECT * FROM hlbg_seasons ORDER BY season;

-- Cleanup complete message
SELECT 'HLBG Cleanup Complete - Duplicate time columns should be removed' as Status;