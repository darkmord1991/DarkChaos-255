-- ULTRA COMPATIBLE HLBG Database Fix
-- For MySQL 5.0+ / MariaDB - No modern syntax used
-- This script first checks what you have, then fixes it step by step
-- Run this instead of all other scripts

-- ==================================================
-- STEP 1: CHECK YOUR CURRENT TABLE STRUCTURE  
-- ==================================================

-- First, let's see exactly what columns you have
DESCRIBE hlbg_seasons;
DESCRIBE hlbg_weather;
DESCRIBE hlbg_affixes;

-- Show current data counts
SELECT 'Current Data Status:' as Info;
SELECT COUNT(*) as hlbg_seasons_rows FROM hlbg_seasons;
SELECT COUNT(*) as hlbg_weather_rows FROM hlbg_weather;
SELECT COUNT(*) as hlbg_affixes_rows FROM hlbg_affixes;

-- ==================================================
-- STEP 2: FIX hlbg_seasons TABLE
-- ==================================================

-- Add start_datetime column (MySQL 5.0 compatible)
-- First check if it exists, then add if needed

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.columns 
     WHERE table_schema = DATABASE() 
     AND table_name = 'hlbg_seasons' 
     AND column_name = 'start_datetime') > 0,
    'SELECT "start_datetime already exists" as result',
    'ALTER TABLE hlbg_seasons ADD COLUMN start_datetime DATETIME NOT NULL DEFAULT "2025-01-01 00:00:00"'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add end_datetime column
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.columns 
     WHERE table_schema = DATABASE() 
     AND table_name = 'hlbg_seasons' 
     AND column_name = 'end_datetime') > 0,
    'SELECT "end_datetime already exists" as result',
    'ALTER TABLE hlbg_seasons ADD COLUMN end_datetime DATETIME NOT NULL DEFAULT "2025-12-31 23:59:59"'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ==================================================
-- STEP 3: FIX hlbg_weather TABLE  
-- ==================================================

-- Add weather_intensity column
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.columns 
     WHERE table_schema = DATABASE() 
     AND table_name = 'hlbg_weather' 
     AND column_name = 'weather_intensity') > 0,
    'SELECT "weather_intensity already exists" as result',
    'ALTER TABLE hlbg_weather ADD COLUMN weather_intensity INT DEFAULT 1'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add duration_mins column
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.columns 
     WHERE table_schema = DATABASE() 
     AND table_name = 'hlbg_weather' 
     AND column_name = 'duration_mins') > 0,
    'SELECT "duration_mins already exists" as result',
    'ALTER TABLE hlbg_weather ADD COLUMN duration_mins INT DEFAULT 5'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add is_enabled column
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.columns 
     WHERE table_schema = DATABASE() 
     AND table_name = 'hlbg_weather' 
     AND column_name = 'is_enabled') > 0,
    'SELECT "is_enabled already exists" as result',
    'ALTER TABLE hlbg_weather ADD COLUMN is_enabled TINYINT(1) DEFAULT 1'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ==================================================
-- STEP 4: INSERT DATA WITH EXISTING COLUMN NAMES
-- ==================================================

-- Check what columns hlbg_seasons actually has now
SELECT 'hlbg_seasons table structure after fixes:' as Info;
DESCRIBE hlbg_seasons;

-- Insert season data using columns that now exist
-- Check if we have the datetime columns
SET @has_datetime = (SELECT COUNT(*) FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'hlbg_seasons' 
    AND column_name IN ('start_datetime', 'end_datetime')) >= 2;

-- Insert season based on available columns
SET @sql = IF(@has_datetime,
    'INSERT IGNORE INTO hlbg_seasons (name, start_datetime, end_datetime, description, is_active) VALUES ("Season 1: Chaos Reborn", "2025-10-01 00:00:00", "2025-12-31 23:59:59", "The inaugural season of Hinterland Battleground on DC-255", 1)',
    'INSERT IGNORE INTO hlbg_seasons (name, description, is_active) VALUES ("Season 1: Chaos Reborn", "The inaugural season of Hinterland Battleground on DC-255", 1)'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Check what columns hlbg_weather actually has now  
SELECT 'hlbg_weather table structure after fixes:' as Info;
DESCRIBE hlbg_weather;

-- Insert weather data using columns that now exist
-- Check if we have the new columns
SET @has_weather_cols = (SELECT COUNT(*) FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'hlbg_weather' 
    AND column_name IN ('weather_intensity', 'duration_mins', 'is_enabled')) >= 3;

-- Insert weather based on available columns
SET @sql = IF(@has_weather_cols,
    'INSERT IGNORE INTO hlbg_weather (name, description, weather_intensity, duration_mins, is_enabled) VALUES 
     ("Clear Skies", "Perfect weather conditions", 1, 0, 1),
     ("Light Rain", "Visibility slightly reduced", 2, 8, 1),  
     ("Heavy Storm", "Reduced visibility and movement", 4, 5, 1),
     ("Blizzard", "Severe weather conditions", 5, 3, 0)',
    'INSERT IGNORE INTO hlbg_weather (name, description) VALUES 
     ("Clear Skies", "Perfect weather conditions"),
     ("Light Rain", "Visibility slightly reduced"),
     ("Heavy Storm", "Reduced visibility and movement"), 
     ("Blizzard", "Severe weather conditions")'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- The affixes insert should work since it only had duplicate warnings (which IGNORE handles)
-- But let's do it more carefully by updating existing ones
INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(0, 'None', 'No active affix', 'Standard battleground rules apply with no special modifications.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(1, 'Bloodlust', 'Increased attack and movement speed', 'All players gain 30% attack speed and 25% movement speed. Stacks with other speed effects.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(2, 'Regeneration', 'Passive health and mana regeneration boost', 'Players regenerate 2% health and mana per second while out of combat for 5+ seconds.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(3, 'Speed Boost', 'Significant movement speed increase', 'Movement speed increased by 50% for all players. Mount speed also increased by 25%.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(4, 'Damage Shield', 'Reflects damage back to attackers', 'All players have a permanent damage shield that reflects 25% of received damage back to attackers.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(5, 'Mana Shield', 'Mana-based damage absorption', 'Players gain a mana shield that absorbs damage equal to 2x their current mana. Shield regenerates when mana regenerates.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(6, 'Storms', 'Periodic lightning storms that damage and stun', 'Every 60 seconds, lightning storms strike random locations dealing 15% max health damage and stunning for 3 seconds.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(7, 'Volcanic', 'Eruptions on the ground that knock back', 'Volcanic eruptions appear every 45 seconds at random locations, dealing damage and knocking players back 20 yards.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(8, 'Haste', 'Combatants gain periodic movement/attack speed boosts', 'Every 30 seconds, all players in combat gain 40% haste for 15 seconds.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(9, 'Berserker', 'Low health players deal increased damage', 'Players below 50% health deal 50% more damage. Players below 25% health deal 100% more damage.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(10, 'Fortified', 'All players receive damage reduction', 'All players take 30% less damage from all sources. Healing effects are reduced by 20%.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(11, 'Double Resources', 'Resource gains are doubled', 'All resource point gains are doubled. Honor kills give double points. Capture objectives give double rewards.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(12, 'Rapid Respawn', 'Decreased respawn times', 'Player respawn time reduced from 30 seconds to 10 seconds. Allows for more aggressive gameplay.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(13, 'Giant Growth', 'Players become larger and stronger', 'All players are scaled to 125% size and gain 25% more health and damage. Movement speed reduced by 15%.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(14, 'Invisibility Surge', 'Periodic stealth for all players', 'Every 2 minutes, all players become stealthed for 10 seconds. Breaking stealth grants 5 seconds of 50% damage boost.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(15, 'Chaos Magic', 'Random spell effects every 30 seconds', 'Every 30 seconds, a random beneficial or detrimental effect is applied to all players for 20 seconds.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), 
description = VALUES(description), 
effect = VALUES(effect);

-- ==================================================
-- STEP 5: FINAL VERIFICATION
-- ==================================================

SELECT 'HLBG Database Ultra-Compatible Fix Complete!' as Status;
SELECT 'Final table structures:' as Info;

DESCRIBE hlbg_seasons;
DESCRIBE hlbg_weather;  
DESCRIBE hlbg_affixes;

SELECT 'Final data counts:' as Info;
SELECT COUNT(*) as 'hlbg_seasons (should be 1+)' FROM hlbg_seasons;
SELECT COUNT(*) as 'hlbg_weather (should be 4+)' FROM hlbg_weather; 
SELECT COUNT(*) as 'hlbg_affixes (should be 16)' FROM hlbg_affixes;

SELECT 'Sample data:' as Info;
SELECT name, is_active FROM hlbg_seasons LIMIT 3;
SELECT name, description FROM hlbg_weather LIMIT 3;
SELECT id, name FROM hlbg_affixes WHERE id IN (0,1,2) ORDER BY id;

-- ==================================================
-- NOTE: This script is compatible with MySQL 5.0+ 
-- It checks your actual table structure before making changes
-- No modern syntax like "IF NOT EXISTS" is used
-- All errors about duplicate indexes/keys can be safely ignored
-- ==================================================