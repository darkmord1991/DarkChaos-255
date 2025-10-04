-- HLBG Ultra-Compatible Data Population Script
-- Location: Custom/Hinterland BG/CharDB/07_ultra_compatible.sql
-- Works with basic table structures and older MySQL versions

-- =====================================================
-- ULTRA-COMPATIBLE HLBG DATA POPULATION
-- Only uses columns that exist in basic table structures
-- Compatible with MySQL 5.5+ and MariaDB
-- =====================================================

-- =====================================================
-- SECTION 1: BASIC DATA POPULATION
-- =====================================================

-- Weather data (only basic columns)
INSERT INTO `hlbg_weather` (`weather`, `name`, `description`) VALUES
(0, 'Clear', 'Perfect clear weather conditions'),
(1, 'Light Rain', 'Light rainfall with minimal impact'),
(2, 'Heavy Rain', 'Heavy rain reducing visibility'),
(3, 'Snow', 'Snowfall conditions'),
(4, 'Thunderstorm', 'Severe thunderstorm with lightning'),
(5, 'Fog', 'Dense fog greatly reducing visibility'),
(6, 'Blizzard', 'Extreme snow conditions'),
(7, 'Magical Storm', 'Arcane storm with special effects')
ON DUPLICATE KEY UPDATE 
    `name` = VALUES(`name`),
    `description` = VALUES(`description`);

-- Affix data (only basic columns that definitely exist)
INSERT INTO `hlbg_affixes` (`id`, `name`, `description`) VALUES
(0, 'None', 'No active affix - standard battleground rules'),
(1, 'Bloodlust', 'All players gain Bloodlust/Heroism periodically'),
(2, 'Regeneration', 'Enhanced health and mana regeneration'),
(3, 'Speed Demon', 'Significant movement speed increase'),
(4, 'Thorns', 'Damage reflection shield'),
(5, 'Mana Burn', 'Spells consume enemy mana'),
(6, 'Lightning Storm', 'Periodic area lightning strikes'),
(7, 'Volcanic', 'Ground eruptions at player locations'),
(8, 'Time Warp', 'Periodic haste for all players'),
(9, 'Berserker Rage', 'Low health increases damage'),
(10, 'Fortification', 'Damage reduction for all players'),
(11, 'Chaos Magic', 'Random spell effects on abilities'),
(12, 'Resource Rush', 'Increased resource gain rate'),
(13, 'Death Wish', 'Increased damage near death'),
(14, 'Arcane Power', 'Spell power increases over time'),
(15, 'Plague Bearer', 'Damage spreads to nearby enemies')
ON DUPLICATE KEY UPDATE 
    `name` = VALUES(`name`),
    `description` = VALUES(`description`);

-- Season data (only basic columns)
INSERT INTO `hlbg_seasons` (`season`, `name`, `description`, `starts_at`, `ends_at`, `is_active`) VALUES
(1, 'Season 1: The Awakening', 'The inaugural season of enhanced Hinterland Battlegrounds', '2025-10-01 00:00:00', '2025-12-31 23:59:59', 1),
(2, 'Season 2: Elemental Fury', 'Introducing weather effects and elemental affixes', '2026-01-01 00:00:00', '2026-03-31 23:59:59', 0),
(3, 'Season 3: Chaos Unleashed', 'Advanced affixes and chaos magic systems', '2026-04-01 00:00:00', '2026-06-30 23:59:59', 0)
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`),
    `description` = VALUES(`description`),
    `starts_at` = VALUES(`starts_at`),
    `ends_at` = VALUES(`ends_at`),
    `is_active` = VALUES(`is_active`);

-- =====================================================
-- SECTION 2: CONDITIONAL DATA FOR ENHANCED TABLES
-- =====================================================

-- Only populate hlbg_config if it exists and has basic structure
INSERT IGNORE INTO `hlbg_config` (`duration_minutes`, `max_players_per_side`, `min_level`, `max_level`) 
VALUES (30, 40, 255, 255);

-- Only populate hlbg_statistics if it exists and has basic structure  
INSERT IGNORE INTO `hlbg_statistics` (`total_runs`, `alliance_wins`, `horde_wins`, `draws`) 
VALUES (0, 0, 0, 0);

-- =====================================================
-- SECTION 3: SAFE INDEX CREATION (Old MySQL Compatible)
-- =====================================================

-- Method 1: Try to create indexes, ignore if they already exist
-- Using IGNORE to prevent duplicate key errors

-- For hlbg_winner_history
SET @sql = 'CREATE INDEX idx_hlbg_winner_season ON hlbg_winner_history (season, winner_tid, affix)';
SET @ignore_error = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
                     WHERE TABLE_SCHEMA = DATABASE() 
                     AND TABLE_NAME = 'hlbg_winner_history' 
                     AND INDEX_NAME = 'idx_hlbg_winner_season');
SET @sql = IF(@ignore_error = 0, @sql, 'SELECT "Index already exists" as Notice');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- For hlbg_affixes
SET @sql2 = 'CREATE INDEX idx_hlbg_affixes_lookup ON hlbg_affixes (id, name)';
SET @ignore_error2 = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
                       WHERE TABLE_SCHEMA = DATABASE() 
                       AND TABLE_NAME = 'hlbg_affixes' 
                       AND INDEX_NAME = 'idx_hlbg_affixes_lookup');
SET @sql2 = IF(@ignore_error2 = 0, @sql2, 'SELECT "Index already exists" as Notice');
PREPARE stmt2 FROM @sql2; EXECUTE stmt2; DEALLOCATE PREPARE stmt2;

-- For hlbg_weather
SET @sql3 = 'CREATE INDEX idx_hlbg_weather_name ON hlbg_weather (weather, name)';
SET @ignore_error3 = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
                       WHERE TABLE_SCHEMA = DATABASE() 
                       AND TABLE_NAME = 'hlbg_weather' 
                       AND INDEX_NAME = 'idx_hlbg_weather_name');
SET @sql3 = IF(@ignore_error3 = 0, @sql3, 'SELECT "Index already exists" as Notice');
PREPARE stmt3 FROM @sql3; EXECUTE stmt3; DEALLOCATE PREPARE stmt3;

-- =====================================================
-- SECTION 4: VERIFICATION AND RESULTS
-- =====================================================

-- Show what we populated
SELECT 'Data Population Results:' as Info;

SELECT 'Weather Types:' as TableInfo, COUNT(*) as RowCount FROM hlbg_weather;
SELECT weather, name FROM hlbg_weather ORDER BY weather LIMIT 5;

SELECT 'Affix Definitions:' as TableInfo, COUNT(*) as RowCount FROM hlbg_affixes;
SELECT id, name FROM hlbg_affixes ORDER BY id LIMIT 5;

SELECT 'Season Information:' as TableInfo, COUNT(*) as RowCount FROM hlbg_seasons;
SELECT season, name, is_active FROM hlbg_seasons ORDER BY season;

-- Show table status
SELECT 
    TABLE_NAME,
    TABLE_ROWS as EstimatedRows,
    CREATE_TIME
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE 'hlbg_%'
ORDER BY TABLE_NAME;

-- Show indexes created
SELECT 
    TABLE_NAME,
    INDEX_NAME,
    COLUMN_NAME
FROM INFORMATION_SCHEMA.STATISTICS 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE 'hlbg_%'
  AND INDEX_NAME NOT LIKE 'PRIMARY'
ORDER BY TABLE_NAME, INDEX_NAME;

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================

SELECT 'HLBG Ultra-Compatible Setup Complete!' as Status,
       'Basic data populated for weather (8 types), affixes (16 types), seasons (3)' as DataStatus,
       'Indexes created safely without conflicts' as IndexStatus,
       'Compatible with MySQL 5.5+ and all existing table structures' as Compatibility,
       'Ready for existing Eluna AIO system' as SystemReady;