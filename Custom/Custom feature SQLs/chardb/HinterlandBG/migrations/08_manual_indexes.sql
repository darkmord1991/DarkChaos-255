-- HLBG Manual Index Creation - No Syntax Errors
-- Location: Custom/Hinterland BG/CharDB/08_manual_indexes.sql  
-- Run these commands individually to create indexes safely

-- =====================================================
-- MANUAL INDEX CREATION COMMANDS
-- Run these one by one to avoid syntax errors
-- =====================================================

-- Check current indexes first
SELECT 'Current HLBG Indexes:' as Info;
SELECT 
    TABLE_NAME,
    INDEX_NAME,
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) as Columns
FROM INFORMATION_SCHEMA.STATISTICS 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE 'hlbg_%'
  AND INDEX_NAME != 'PRIMARY'
GROUP BY TABLE_NAME, INDEX_NAME
ORDER BY TABLE_NAME, INDEX_NAME;

-- =====================================================
-- CREATE INDEXES MANUALLY (Run each command separately)
-- =====================================================

-- Index for hlbg_winner_history (main queries)
-- CREATE INDEX idx_winner_season_affix ON hlbg_winner_history (season, winner_tid, affix);

-- Index for hlbg_winner_history (time-based queries) 
-- CREATE INDEX idx_winner_occurred_at ON hlbg_winner_history (occurred_at);

-- Index for hlbg_affixes (lookups)
-- CREATE INDEX idx_affixes_id_name ON hlbg_affixes (id, name);

-- Index for hlbg_seasons (active season queries)
-- CREATE INDEX idx_seasons_active_time ON hlbg_seasons (is_active, starts_at);

-- Index for hlbg_weather (weather lookups)
-- CREATE INDEX idx_weather_code_name ON hlbg_weather (weather, name);

-- =====================================================
-- ALTERNATIVE: SAFE INDEX CREATION WITH ERROR HANDLING
-- =====================================================

-- Method: Check if index exists before creating

-- Check and create winner_history index
SET @index_exists = (
    SELECT COUNT(*) 
    FROM INFORMATION_SCHEMA.STATISTICS 
    WHERE TABLE_SCHEMA = DATABASE() 
      AND TABLE_NAME = 'hlbg_winner_history' 
      AND INDEX_NAME = 'idx_winner_queries'
);

SELECT IF(@index_exists = 0, 'Creating winner_history index...', 'Index already exists') as IndexStatus;

-- Only create if it doesn't exist
SET @create_sql = IF(@index_exists = 0, 
    'CREATE INDEX idx_winner_queries ON hlbg_winner_history (season, winner_tid, occurred_at)',
    'SELECT "Skipped - index exists" as Result'
);
PREPARE stmt FROM @create_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Check and create affixes index
SET @affix_index_exists = (
    SELECT COUNT(*) 
    FROM INFORMATION_SCHEMA.STATISTICS 
    WHERE TABLE_SCHEMA = DATABASE() 
      AND TABLE_NAME = 'hlbg_affixes' 
      AND INDEX_NAME = 'idx_affixes_lookup'
);

SELECT IF(@affix_index_exists = 0, 'Creating affixes index...', 'Index already exists') as AffixIndexStatus;

SET @affix_sql = IF(@affix_index_exists = 0,
    'CREATE INDEX idx_affixes_lookup ON hlbg_affixes (id, name)', 
    'SELECT "Skipped - affix index exists" as Result'
);
PREPARE stmt2 FROM @affix_sql;
EXECUTE stmt2;  
DEALLOCATE PREPARE stmt2;

-- =====================================================
-- VERIFY RESULTS
-- =====================================================

-- Show final index status
SELECT 'Final Index Status:' as Info;
SELECT 
    TABLE_NAME,
    INDEX_NAME,
    NON_UNIQUE,
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) as IndexColumns
FROM INFORMATION_SCHEMA.STATISTICS 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE 'hlbg_%'
GROUP BY TABLE_NAME, INDEX_NAME
ORDER BY TABLE_NAME, INDEX_NAME;

-- Show table sizes with indexes
SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) as SizeMB,
    ROUND((INDEX_LENGTH / 1024 / 1024), 2) as IndexSizeMB
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE 'hlbg_%'
ORDER BY TABLE_NAME;

SELECT 'Index creation complete!' as Status;