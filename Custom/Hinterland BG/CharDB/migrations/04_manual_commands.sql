-- HLBG Manual Cleanup Commands
-- Location: Custom/Hinterland BG/CharDB/04_manual_commands.sql
-- Run these commands one by one to avoid syntax errors

-- ==================================================
-- STEP 1: CHECK CURRENT TABLE STATUS
-- ==================================================

-- See what HLBG tables exist
SHOW TABLES LIKE 'hlbg_%';

-- Check hlbg_seasons structure
DESCRIBE hlbg_seasons;

-- See current seasons data
SELECT * FROM hlbg_seasons;

-- ==================================================
-- STEP 2: FIX DUPLICATE TIME COLUMNS IN HLBG_SEASONS
-- ==================================================

-- Check if duplicate columns exist
SELECT COLUMN_NAME 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME = 'hlbg_seasons' 
  AND COLUMN_NAME IN ('start_date', 'end_date', 'starts_at', 'ends_at');

-- If start_date column exists, drop it:
-- ALTER TABLE hlbg_seasons DROP COLUMN start_date;

-- If end_date column exists, drop it:  
-- ALTER TABLE hlbg_seasons DROP COLUMN end_date;

-- ==================================================
-- STEP 3: UPDATE SEASON DATA WITH CORRECT TIMESTAMPS
-- ==================================================

-- Fix Season 1 dates (using season column instead of id)
UPDATE hlbg_seasons 
SET starts_at = '2025-10-01 00:00:00' 
WHERE season = 1;

UPDATE hlbg_seasons 
SET ends_at = '2025-12-31 23:59:59' 
WHERE season = 1;

-- Fix Season 2 dates  
UPDATE hlbg_seasons 
SET starts_at = '2025-01-01 00:00:00' 
WHERE season = 2;

UPDATE hlbg_seasons 
SET ends_at = '2025-03-31 23:59:59' 
WHERE season = 2;

-- ==================================================
-- STEP 4: VERIFY RESULTS
-- ==================================================

-- Check final table structure
DESCRIBE hlbg_seasons;

-- Check final data
SELECT season, name, starts_at, ends_at, is_active FROM hlbg_seasons ORDER BY season;

-- Check if essential tables exist
SELECT TABLE_NAME, TABLE_ROWS 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME IN ('hlbg_winner_history', 'hlbg_affixes', 'hlbg_seasons');

-- ==================================================
-- TROUBLESHOOTING COMMANDS
-- ==================================================

-- If you need to recreate hlbg_seasons table properly:
/*
DROP TABLE IF EXISTS hlbg_seasons;

CREATE TABLE hlbg_seasons (
    season INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    rewards_alliance TEXT,
    rewards_horde TEXT, 
    rewards_participation TEXT,
    is_active BOOLEAN DEFAULT FALSE,
    starts_at DATETIME NULL,
    ends_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50) DEFAULT 'GM'
);

-- Reinsert the data
INSERT INTO hlbg_seasons (season, name, description, starts_at, ends_at, is_active) VALUES
(1, 'Season 1', 'Level 80 start', '2025-10-01 00:00:00', '2025-12-31 23:59:59', 1),
(2, 'Season2', 'test2', '2025-01-01 00:00:00', '2025-03-31 23:59:59', 0);
*/