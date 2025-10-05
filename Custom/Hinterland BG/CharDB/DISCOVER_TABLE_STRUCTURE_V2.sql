-- Enhanced Table Structure Discovery Script
-- This will show us the exact column structure for all HLBG tables

-- Show all HLBG related tables
SELECT TABLE_NAME, TABLE_COMMENT 
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME LIKE '%hlbg%'
ORDER BY TABLE_NAME;

-- Get detailed column information for each table
SELECT 'hlbg_seasons COLUMNS:' as Info;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_COMMENT
FROM information_schema.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME = 'hlbg_seasons'
ORDER BY ORDINAL_POSITION;

SELECT 'hlbg_weather COLUMNS:' as Info;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_COMMENT
FROM information_schema.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME = 'hlbg_weather'
ORDER BY ORDINAL_POSITION;

SELECT 'hlbg_affixes COLUMNS:' as Info;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_COMMENT
FROM information_schema.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME = 'hlbg_affixes'
ORDER BY ORDINAL_POSITION;

SELECT 'hlbg_config COLUMNS:' as Info;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_COMMENT
FROM information_schema.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME = 'hlbg_config'
ORDER BY ORDINAL_POSITION;

SELECT 'hlbg_statistics COLUMNS:' as Info;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_COMMENT
FROM information_schema.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME = 'hlbg_statistics'
ORDER BY ORDINAL_POSITION;

SELECT 'hlbg_battle_history COLUMNS:' as Info;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_COMMENT
FROM information_schema.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME = 'hlbg_battle_history'
ORDER BY ORDINAL_POSITION;

SELECT 'hlbg_player_stats COLUMNS:' as Info;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_COMMENT
FROM information_schema.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME = 'hlbg_player_stats'
ORDER BY ORDINAL_POSITION;

-- Show current data in each table
SELECT 'CURRENT DATA OVERVIEW:' as Info;

SELECT 'hlbg_seasons data:' as Info;
SELECT * FROM hlbg_seasons LIMIT 3;

SELECT 'hlbg_weather data:' as Info;
SELECT * FROM hlbg_weather LIMIT 5;

SELECT 'hlbg_affixes data:' as Info;
SELECT * FROM hlbg_affixes LIMIT 5;

-- Show table creation statements (if possible)
SELECT 'hlbg_seasons CREATE:' as Info;
SHOW CREATE TABLE hlbg_seasons;

SELECT 'hlbg_weather CREATE:' as Info;
SHOW CREATE TABLE hlbg_weather;

SELECT 'hlbg_affixes CREATE:' as Info;
SHOW CREATE TABLE hlbg_affixes;