-- HLBG Table Structure Check
-- Location: Custom/Hinterland BG/CharDB/06_check_table_structures.sql
-- Run this to see what columns actually exist in your tables

-- =====================================================
-- TABLE STRUCTURE VERIFICATION
-- =====================================================

-- Show all HLBG tables
SELECT 'Current HLBG Tables:' as Info;
SHOW TABLES LIKE 'hlbg_%';

-- Check hlbg_winner_history structure
SELECT 'hlbg_winner_history structure:' as TableInfo;
DESCRIBE hlbg_winner_history;

-- Check hlbg_affixes structure  
SELECT 'hlbg_affixes structure:' as TableInfo;
DESCRIBE hlbg_affixes;

-- Check hlbg_seasons structure
SELECT 'hlbg_seasons structure:' as TableInfo;
DESCRIBE hlbg_seasons;

-- Check hlbg_weather structure
SELECT 'hlbg_weather structure:' as TableInfo;
DESCRIBE hlbg_weather;

-- Check hlbg_config structure (if exists)
SELECT 'hlbg_config structure:' as TableInfo;
DESCRIBE hlbg_config;

-- Check hlbg_statistics structure (if exists)
SELECT 'hlbg_statistics structure:' as TableInfo;  
DESCRIBE hlbg_statistics;

-- Check hlbg_battle_history structure (if exists)
SELECT 'hlbg_battle_history structure:' as TableInfo;
DESCRIBE hlbg_battle_history;

-- Check hlbg_player_stats structure (if exists)
SELECT 'hlbg_player_stats structure:' as TableInfo;
DESCRIBE hlbg_player_stats;

-- =====================================================
-- SHOW CURRENT DATA IN TABLES
-- =====================================================

-- Show current data counts
SELECT 
    TABLE_NAME,
    TABLE_ROWS as EstimatedRows,
    CREATE_TIME,
    TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE 'hlbg_%'
ORDER BY TABLE_NAME;

-- Show actual data in key tables
SELECT 'Current weather entries:' as Info;
SELECT * FROM hlbg_weather ORDER BY weather;

SELECT 'Current affix entries:' as Info;  
SELECT * FROM hlbg_affixes ORDER BY id;

SELECT 'Current season entries:' as Info;
SELECT * FROM hlbg_seasons ORDER BY season;

SELECT 'Recent winner history entries (last 5):' as Info;
SELECT id, occurred_at, winner_tid, win_reason, affix, season 
FROM hlbg_winner_history 
ORDER BY occurred_at DESC 
LIMIT 5;