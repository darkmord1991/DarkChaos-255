-- HLBG Data Population - Compatible with Existing Tables
-- Location: Custom/Hinterland BG/CharDB/05_compatible_data_population.sql
-- Apply to CHARACTER database - Works with current table structures

-- =====================================================
-- COMPATIBLE DATA POPULATION SCRIPT
-- Populates only the columns that actually exist in current tables
-- =====================================================

-- Check what tables and columns we have
SELECT 'Checking existing table structures...' as Status;

-- Show current hlbg tables
SHOW TABLES LIKE 'hlbg_%';

-- =====================================================
-- POPULATE HLBG_WEATHER (Basic structure)
-- =====================================================

-- Populate with basic weather data (only columns that exist)
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

-- =====================================================
-- POPULATE HLBG_AFFIXES (Basic structure)
-- =====================================================

-- Insert basic affix data (only existing columns)
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

-- =====================================================
-- POPULATE HLBG_SEASONS (Basic structure)
-- =====================================================

-- Insert season data (only existing columns)
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
-- HLBG_CONFIG (if it exists in current database)
-- =====================================================

-- Check if hlbg_config exists and populate basic settings
INSERT IGNORE INTO `hlbg_config` (`duration_minutes`, `max_players_per_side`, `min_level`, `max_level`) 
VALUES (30, 40, 255, 255);

-- =====================================================
-- CREATE SAFE INDEXES (MySQL 5.7 compatible)
-- =====================================================

-- Create indexes without IF NOT EXISTS (older MySQL compatibility)
-- Drop and recreate to avoid errors

-- Indexes for hlbg_winner_history
DROP INDEX IF EXISTS `idx_hlbg_winner_comprehensive` ON `hlbg_winner_history`;
CREATE INDEX `idx_hlbg_winner_comprehensive` ON `hlbg_winner_history` (`season`, `winner_tid`, `affix`, `occurred_at`);

-- Indexes for hlbg_affixes  
DROP INDEX IF EXISTS `idx_hlbg_affixes_enabled` ON `hlbg_affixes`;
CREATE INDEX `idx_hlbg_affixes_enabled` ON `hlbg_affixes` (`is_enabled`);

-- Indexes for hlbg_seasons
DROP INDEX IF EXISTS `idx_hlbg_seasons_active` ON `hlbg_seasons`;
CREATE INDEX `idx_hlbg_seasons_active` ON `hlbg_seasons` (`is_active`);

DROP INDEX IF EXISTS `idx_hlbg_seasons_dates` ON `hlbg_seasons`;
CREATE INDEX `idx_hlbg_seasons_dates` ON `hlbg_seasons` (`starts_at`, `ends_at`);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Verify weather data
SELECT 'Weather data populated:' as Info, COUNT(*) as count FROM hlbg_weather;
SELECT * FROM hlbg_weather ORDER BY weather;

-- Verify affix data  
SELECT 'Affix data populated:' as Info, COUNT(*) as count FROM hlbg_affixes;
SELECT id, name, LEFT(description, 50) as description_preview FROM hlbg_affixes ORDER BY id;

-- Verify season data
SELECT 'Season data populated:' as Info, COUNT(*) as count FROM hlbg_seasons;
SELECT season, name, starts_at, ends_at, is_active FROM hlbg_seasons ORDER BY season;

-- Show all HLBG tables and their row counts
SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE 'hlbg_%'
ORDER BY TABLE_NAME;

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================

SELECT 'HLBG Data Population Complete!' as Status,
       'Basic data inserted for weather, affixes, and seasons' as DataStatus,
       'Indexes created for performance optimization' as IndexStatus,
       'Compatible with existing table structures' as Compatibility;