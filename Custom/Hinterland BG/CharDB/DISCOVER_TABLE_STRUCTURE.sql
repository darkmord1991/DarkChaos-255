-- HLBG Database Structure Discovery and Fix
-- This script first checks your EXACT table structure, then fixes it properly
-- Run this to see what columns your tables actually have

-- ==================================================
-- STEP 1: DISCOVER YOUR ACTUAL TABLE STRUCTURE
-- ==================================================

SELECT 'Checking hlbg_seasons table structure...' as Info;
DESCRIBE hlbg_seasons;

SELECT 'Checking hlbg_weather table structure...' as Info;  
DESCRIBE hlbg_weather;

SELECT 'Checking hlbg_affixes table structure...' as Info;
DESCRIBE hlbg_affixes;

-- Check what data is already in the tables
SELECT 'Current data in hlbg_seasons:' as Info;
SELECT * FROM hlbg_seasons LIMIT 5;

SELECT 'Current data in hlbg_weather:' as Info;
SELECT * FROM hlbg_weather LIMIT 5;

SELECT 'Current data in hlbg_affixes:' as Info; 
SELECT id, name, description FROM hlbg_affixes ORDER BY id LIMIT 10;

-- ==================================================
-- STEP 2: SHOW REQUIRED FIELDS (WHAT'S CAUSING ERRORS)
-- ==================================================

-- This will show us which fields are required (NOT NULL) and don't have defaults
SELECT 
    COLUMN_NAME,
    DATA_TYPE, 
    IS_NULLABLE,
    COLUMN_DEFAULT,
    COLUMN_COMMENT
FROM information_schema.columns 
WHERE table_schema = DATABASE() 
AND table_name = 'hlbg_seasons'
AND IS_NULLABLE = 'NO' 
AND COLUMN_DEFAULT IS NULL
ORDER BY ORDINAL_POSITION;

SELECT 'Required fields in hlbg_weather (causing errors):' as Info;
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE, 
    COLUMN_DEFAULT,
    COLUMN_COMMENT
FROM information_schema.columns 
WHERE table_schema = DATABASE() 
AND table_name = 'hlbg_weather'
AND IS_NULLABLE = 'NO'
AND COLUMN_DEFAULT IS NULL  
ORDER BY ORDINAL_POSITION;

-- ==================================================
-- STEP 3: SAFE COLUMN ADDITION (ONE BY ONE)
-- ==================================================

-- Add columns to hlbg_seasons one by one (ignore errors if they exist)
SELECT 'Adding columns to hlbg_seasons...' as Info;

-- Try to add start_datetime
SET @sql = 'ALTER TABLE hlbg_seasons ADD COLUMN start_datetime DATETIME DEFAULT "2025-01-01 00:00:00"';
SET @sql_check = CONCAT('SELECT COUNT(*) as col_exists FROM information_schema.columns WHERE table_schema = "', DATABASE(), '" AND table_name = "hlbg_seasons" AND column_name = "start_datetime"');

-- Try to add end_datetime  
SET @sql2 = 'ALTER TABLE hlbg_seasons ADD COLUMN end_datetime DATETIME DEFAULT "2025-12-31 23:59:59"';

-- Add columns to hlbg_weather one by one
SELECT 'Adding columns to hlbg_weather...' as Info;

SET @sql3 = 'ALTER TABLE hlbg_weather ADD COLUMN weather_intensity INT DEFAULT 1';
SET @sql4 = 'ALTER TABLE hlbg_weather ADD COLUMN duration_mins INT DEFAULT 5'; 
SET @sql5 = 'ALTER TABLE hlbg_weather ADD COLUMN is_enabled TINYINT(1) DEFAULT 1';

-- Execute the ALTER TABLE statements (will give error if column exists, that's OK)
-- hlbg_seasons columns
ALTER TABLE hlbg_seasons ADD COLUMN start_datetime DATETIME DEFAULT '2025-01-01 00:00:00';
ALTER TABLE hlbg_seasons ADD COLUMN end_datetime DATETIME DEFAULT '2025-12-31 23:59:59';

-- hlbg_weather columns  
ALTER TABLE hlbg_weather ADD COLUMN weather_intensity INT DEFAULT 1;
ALTER TABLE hlbg_weather ADD COLUMN duration_mins INT DEFAULT 5;
ALTER TABLE hlbg_weather ADD COLUMN is_enabled TINYINT(1) DEFAULT 1;

-- ==================================================
-- STEP 4: CHECK TABLE STRUCTURE AFTER CHANGES
-- ==================================================

SELECT 'hlbg_seasons structure after adding columns:' as Info;
DESCRIBE hlbg_seasons;

SELECT 'hlbg_weather structure after adding columns:' as Info;
DESCRIBE hlbg_weather;

-- ==================================================
-- STEP 5: INSERT DATA BASED ON ACTUAL STRUCTURE
-- ==================================================

-- Now we need to see what the actual required columns are and insert accordingly
-- First, let's see what columns we have now in hlbg_seasons

SELECT 'Available columns in hlbg_seasons:' as Info;
SELECT COLUMN_NAME 
FROM information_schema.columns 
WHERE table_schema = DATABASE() 
AND table_name = 'hlbg_seasons' 
ORDER BY ORDINAL_POSITION;

SELECT 'Available columns in hlbg_weather:' as Info;
SELECT COLUMN_NAME
FROM information_schema.columns  
WHERE table_schema = DATABASE()
AND table_name = 'hlbg_weather'
ORDER BY ORDINAL_POSITION;

-- ==================================================
-- STEP 6: NOTES AND NEXT STEPS
-- ==================================================

SELECT 'DISCOVERY COMPLETE!' as Status;
SELECT 'Look at the table structures above to see what columns exist.' as Instructions;
SELECT 'If there are required fields without defaults, we need to specify them in INSERT statements.' as Instructions2;
SELECT 'Run the next script after reviewing the table structure.' as Instructions3;

-- ==================================================
-- COMMON ISSUES AND SOLUTIONS:
-- 
-- Error: "Field 'season' doesn't have a default value"
-- Solution: Your hlbg_seasons table has a required 'season' column we need to specify
--
-- Error: "Field 'weather' doesn't have a default value"  
-- Solution: Your hlbg_weather table has a required 'weather' column we need to specify
--
-- After running this discovery script, look at the DESCRIBE output
-- and create INSERT statements that include ALL required columns
-- ==================================================