-- HLBG Database Structure Check and Migration Script
-- Run this to see your current table structures and fix any issues
-- Updated: October 5, 2025

-- ==================================================
-- STEP 1: CHECK EXISTING TABLE STRUCTURES
-- ==================================================

-- Check what HLBG tables currently exist
SELECT TABLE_NAME, TABLE_COMMENT 
FROM information_schema.tables 
WHERE table_schema = DATABASE() 
AND table_name LIKE 'hlbg_%'
ORDER BY TABLE_NAME;

-- Check hlbg_seasons structure
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_COMMENT
FROM information_schema.columns 
WHERE table_schema = DATABASE() 
AND table_name = 'hlbg_seasons'
ORDER BY ORDINAL_POSITION;

-- Check hlbg_weather structure  
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_COMMENT
FROM information_schema.columns 
WHERE table_schema = DATABASE() 
AND table_name = 'hlbg_weather'
ORDER BY ORDINAL_POSITION;

-- Check existing indexes
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME, NON_UNIQUE
FROM information_schema.statistics 
WHERE table_schema = DATABASE() 
AND table_name LIKE 'hlbg_%'
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

-- ==================================================
-- STEP 2: MIGRATION FIXES BASED ON YOUR ERRORS
-- ==================================================

-- Fix 1: hlbg_seasons table - add missing columns if they don't exist
-- (Based on error: "Unknown column 'start_datetime'")

-- Check if start_datetime column exists, if not add it
SET @column_exists = 0;
SELECT COUNT(*) INTO @column_exists 
FROM information_schema.columns 
WHERE table_schema = DATABASE() 
AND table_name = 'hlbg_seasons' 
AND column_name = 'start_datetime';

-- Add start_datetime if it doesn't exist
SET @sql = IF(@column_exists = 0, 
    'ALTER TABLE hlbg_seasons ADD COLUMN start_datetime DATETIME NOT NULL DEFAULT "2025-01-01 00:00:00" COMMENT "Season start date and time"', 
    'SELECT "start_datetime column already exists" as Result');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Check if end_datetime column exists, if not add it
SET @column_exists = 0;
SELECT COUNT(*) INTO @column_exists 
FROM information_schema.columns 
WHERE table_schema = DATABASE() 
AND table_name = 'hlbg_seasons' 
AND column_name = 'end_datetime';

-- Add end_datetime if it doesn't exist
SET @sql = IF(@column_exists = 0, 
    'ALTER TABLE hlbg_seasons ADD COLUMN end_datetime DATETIME NOT NULL DEFAULT "2025-12-31 23:59:59" COMMENT "Season end date and time"', 
    'SELECT "end_datetime column already exists" as Result');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Fix 2: hlbg_weather table - add missing columns if they don't exist  
-- (Based on error: "Unknown column 'weather_intensity'")

-- Check if weather_intensity column exists, if not add it
SET @column_exists = 0;
SELECT COUNT(*) INTO @column_exists 
FROM information_schema.columns 
WHERE table_schema = DATABASE() 
AND table_name = 'hlbg_weather' 
AND column_name = 'weather_intensity';

-- Add weather_intensity if it doesn't exist
SET @sql = IF(@column_exists = 0, 
    'ALTER TABLE hlbg_weather ADD COLUMN weather_intensity INT DEFAULT 1 COMMENT "Weather intensity level 1-5"', 
    'SELECT "weather_intensity column already exists" as Result');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Check if duration_mins column exists, if not add it
SET @column_exists = 0;
SELECT COUNT(*) INTO @column_exists 
FROM information_schema.columns 
WHERE table_schema = DATABASE() 
AND table_name = 'hlbg_weather' 
AND column_name = 'duration_mins';

-- Add duration_mins if it doesn't exist
SET @sql = IF(@column_exists = 0, 
    'ALTER TABLE hlbg_weather ADD COLUMN duration_mins INT DEFAULT 5 COMMENT "How long weather lasts"', 
    'SELECT "duration_mins column already exists" as Result');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ==================================================
-- STEP 3: INSERT DATA SAFELY (IGNORE DUPLICATES)
-- ==================================================

-- Insert default season (using IGNORE to avoid duplicates)
INSERT IGNORE INTO `hlbg_seasons` 
(`name`, `start_datetime`, `end_datetime`, `description`, `is_active`) 
VALUES ('Season 1: Chaos Reborn', '2025-10-01 00:00:00', '2025-12-31 23:59:59', 'The inaugural season of Hinterland Battleground on DC-255', 1);

-- Insert default statistics row (using IGNORE to avoid duplicates)
INSERT IGNORE INTO `hlbg_statistics` 
(`total_runs`, `alliance_wins`, `horde_wins`, `draws`, `server_start_time`) 
VALUES (0, 0, 0, 0, CURRENT_TIMESTAMP);

-- Insert enhanced affixes (using IGNORE to avoid duplicates)
INSERT IGNORE INTO `hlbg_affixes` (`id`, `name`, `description`, `effect`, `is_enabled`) VALUES
(0, 'None', 'No active affix', 'Standard battleground rules apply with no special modifications.', 1),
(1, 'Bloodlust', 'Increased attack and movement speed for all players', 'All players gain 30% attack speed and 25% movement speed. Stacks with other speed effects.', 1),
(2, 'Regeneration', 'Passive health and mana regeneration boost', 'Players regenerate 2% health and mana per second while out of combat for 5+ seconds.', 1), 
(3, 'Speed Boost', 'Significant movement speed increase', 'Movement speed increased by 50% for all players. Mount speed also increased by 25%.', 1),
(4, 'Damage Shield', 'Reflects damage back to attackers', 'All players have a permanent damage shield that reflects 25% of received damage back to attackers.', 1),
(5, 'Mana Shield', 'Mana-based damage absorption', 'Players gain a mana shield that absorbs damage equal to 2x their current mana. Shield regenerates when mana regenerates.', 1),
(6, 'Storms', 'Periodic lightning storms that damage and stun', 'Every 60 seconds, lightning storms strike random locations dealing 15% max health damage and stunning for 3 seconds.', 1),
(7, 'Volcanic', 'Eruptions on the ground that knock back', 'Volcanic eruptions appear every 45 seconds at random locations, dealing damage and knocking players back 20 yards.', 1),
(8, 'Haste', 'Combatants gain periodic movement/attack speed boosts', 'Every 30 seconds, all players in combat gain 40% haste for 15 seconds.', 1),
(9, 'Berserker', 'Low health players deal increased damage', 'Players below 50% health deal 50% more damage. Players below 25% health deal 100% more damage.', 1),
(10, 'Fortified', 'All players receive damage reduction', 'All players take 30% less damage from all sources. Healing effects are reduced by 20%.', 1),
(11, 'Double Resources', 'Resource gains are doubled', 'All resource point gains are doubled. Honor kills give double points. Capture objectives give double rewards.', 1),
(12, 'Rapid Respawn', 'Decreased respawn times', 'Player respawn time reduced from 30 seconds to 10 seconds. Allows for more aggressive gameplay.', 1),
(13, 'Giant Growth', 'Players become larger and stronger', 'All players are scaled to 125% size and gain 25% more health and damage. Movement speed reduced by 15%.', 1),
(14, 'Invisibility Surge', 'Periodic stealth for all players', 'Every 2 minutes, all players become stealthed for 10 seconds. Breaking stealth grants 5 seconds of 50% damage boost.', 1),
(15, 'Chaos Magic', 'Random spell effects every 30 seconds', 'Every 30 seconds, a random beneficial or detrimental effect is applied to all players for 20 seconds.', 1);

-- Insert default weather effects (using IGNORE to avoid duplicates)
INSERT IGNORE INTO `hlbg_weather` (`name`, `description`, `weather_intensity`, `duration_mins`, `is_enabled`) VALUES
('Clear Skies', 'Perfect weather conditions', 1, 0, 1),
('Light Rain', 'Visibility slightly reduced', 2, 8, 1),
('Heavy Storm', 'Reduced visibility and movement', 4, 5, 1),
('Blizzard', 'Severe weather conditions', 5, 3, 0);

-- ==================================================
-- STEP 4: SAFE INDEX CREATION (IGNORE IF EXISTS)
-- ==================================================

-- Create indexes safely (will give "Duplicate key name" error if exists, but that's OK)

-- Seasons indexes (use actual column names that exist)
CREATE INDEX `idx_hlbg_seasons_active` ON `hlbg_seasons` (`is_active`);
-- Only create date index if the datetime columns exist
SET @has_datetime_cols = (
    SELECT COUNT(*) FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'hlbg_seasons' 
    AND column_name IN ('start_datetime', 'end_datetime')
) >= 2;

SET @sql = IF(@has_datetime_cols, 
    'CREATE INDEX `idx_hlbg_seasons_dates` ON `hlbg_seasons` (`start_datetime`, `end_datetime`)', 
    'SELECT "Skipping datetime index - columns do not exist" as Result');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Battle history indexes
CREATE INDEX `idx_hlbg_history_end` ON `hlbg_battle_history` (`battle_end`);
CREATE INDEX `idx_hlbg_history_winner` ON `hlbg_battle_history` (`winner_faction`);
CREATE INDEX `idx_hlbg_history_instance` ON `hlbg_battle_history` (`instance_id`);
CREATE INDEX `idx_hlbg_history_affix` ON `hlbg_battle_history` (`affix_id`);
CREATE INDEX `idx_hlbg_history_start` ON `hlbg_battle_history` (`battle_start`);

-- Player stats indexes
CREATE INDEX `idx_hlbg_player_name` ON `hlbg_player_stats` (`player_name`);
CREATE INDEX `idx_hlbg_player_faction` ON `hlbg_player_stats` (`faction`);
CREATE INDEX `idx_hlbg_player_battles` ON `hlbg_player_stats` (`battles_participated`);
CREATE INDEX `idx_hlbg_player_wins` ON `hlbg_player_stats` (`battles_won`);
CREATE INDEX `idx_hlbg_player_last_participation` ON `hlbg_player_stats` (`last_participation`);

-- Affix indexes
CREATE INDEX `idx_hlbg_affixes_enabled` ON `hlbg_affixes` (`is_enabled`);
CREATE INDEX `idx_hlbg_affixes_usage` ON `hlbg_affixes` (`usage_count`);

-- Weather indexes (check if is_enabled column exists)
SET @has_enabled_col = (
    SELECT COUNT(*) FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'hlbg_weather' 
    AND column_name = 'is_enabled'
) > 0;

SET @sql = IF(@has_enabled_col, 
    'CREATE INDEX `idx_hlbg_weather_enabled` ON `hlbg_weather` (`is_enabled`)', 
    'SELECT "Skipping weather enabled index - column does not exist" as Result');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ==================================================
-- STEP 5: VERIFICATION
-- ==================================================

-- Show final table structures
SELECT 'HLBG Database Migration Complete!' as Status;

SELECT TABLE_NAME, TABLE_ROWS, TABLE_COMMENT 
FROM information_schema.tables 
WHERE table_schema = DATABASE() 
AND table_name LIKE 'hlbg_%'
ORDER BY TABLE_NAME;

-- Show row counts
SELECT 
    'hlbg_config' as table_name, COUNT(*) as row_count FROM hlbg_config
UNION ALL SELECT 
    'hlbg_seasons' as table_name, COUNT(*) as row_count FROM hlbg_seasons
UNION ALL SELECT 
    'hlbg_statistics' as table_name, COUNT(*) as row_count FROM hlbg_statistics
UNION ALL SELECT 
    'hlbg_affixes' as table_name, COUNT(*) as row_count FROM hlbg_affixes
UNION ALL SELECT 
    'hlbg_weather' as table_name, COUNT(*) as row_count FROM hlbg_weather
UNION ALL SELECT 
    'hlbg_battle_history' as table_name, COUNT(*) as row_count FROM hlbg_battle_history
UNION ALL SELECT 
    'hlbg_player_stats' as table_name, COUNT(*) as row_count FROM hlbg_player_stats;

-- ==================================================
-- NOTES:
-- - This script checks your existing table structure
-- - Adds missing columns safely without data loss  
-- - Uses INSERT IGNORE to avoid duplicate data errors
-- - Creates indexes safely (ignores "Duplicate key name" errors)
-- - Works with any existing HLBG table structure
-- ==================================================