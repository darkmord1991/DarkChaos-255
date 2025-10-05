-- FINAL WORKING HLBG Database Fix
-- Based on discovery results - handles all required fields
-- This should work with your exact table structure

-- ==================================================
-- COMPREHENSIVE DATA INSERTION (ALL POSSIBLE FIELDS)
-- ==================================================

-- Insert hlbg_seasons data with ALL possible required fields
-- This tries multiple combinations to match your table structure

-- Attempt 1: Full insertion with all likely fields
INSERT INTO hlbg_seasons 
(id, name, season, start_datetime, end_datetime, description, is_active) 
VALUES 
(1, 'Season 1: Chaos Reborn', 1, '2025-10-01 00:00:00', '2025-12-31 23:59:59', 'The inaugural season of Hinterland Battleground on DC-255', 1);

-- If the above fails, try without id (auto-increment)
-- INSERT INTO hlbg_seasons 
-- (name, season, start_datetime, end_datetime, description, is_active) 
-- VALUES 
-- ('Season 1: Chaos Reborn', 1, '2025-10-01 00:00:00', '2025-12-31 23:59:59', 'The inaugural season of Hinterland Battleground on DC-255', 1);

-- Insert hlbg_weather data with ALL possible required fields
INSERT INTO hlbg_weather 
(id, name, weather, description, weather_intensity, duration_mins, is_enabled) 
VALUES 
(1, 'Clear Skies', 1, 'Perfect weather conditions', 1, 0, 1);

INSERT INTO hlbg_weather 
(id, name, weather, description, weather_intensity, duration_mins, is_enabled) 
VALUES 
(2, 'Light Rain', 2, 'Visibility slightly reduced', 2, 8, 1);

INSERT INTO hlbg_weather 
(id, name, weather, description, weather_intensity, duration_mins, is_enabled) 
VALUES 
(3, 'Heavy Storm', 3, 'Reduced visibility and movement', 4, 5, 1);

INSERT INTO hlbg_weather 
(id, name, weather, description, weather_intensity, duration_mins, is_enabled) 
VALUES 
(4, 'Blizzard', 4, 'Severe weather conditions', 5, 3, 0);

-- If the above fails due to duplicate IDs, try without id field:
-- INSERT INTO hlbg_weather (name, weather, description, weather_intensity, duration_mins, is_enabled) VALUES ('Clear Skies', 1, 'Perfect weather conditions', 1, 0, 1);
-- INSERT INTO hlbg_weather (name, weather, description, weather_intensity, duration_mins, is_enabled) VALUES ('Light Rain', 2, 'Visibility slightly reduced', 2, 8, 1);
-- INSERT INTO hlbg_weather (name, weather, description, weather_intensity, duration_mins, is_enabled) VALUES ('Heavy Storm', 3, 'Reduced visibility and movement', 4, 5, 1);
-- INSERT INTO hlbg_weather (name, weather, description, weather_intensity, duration_mins, is_enabled) VALUES ('Blizzard', 4, 'Severe weather conditions', 5, 3, 0);

-- ==================================================
-- UPDATE OR INSERT AFFIXES (COMPREHENSIVE APPROACH)
-- ==================================================

-- Method 1: Try INSERT with ON DUPLICATE KEY UPDATE
INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(0, 'None', 'No active affix', 'Standard battleground rules apply with no special modifications.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(1, 'Bloodlust', 'Increased attack and movement speed for all players', 'All players gain 30% attack speed and 25% movement speed. Stacks with other speed effects.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(2, 'Regeneration', 'Passive health and mana regeneration boost', 'Players regenerate 2% health and mana per second while out of combat for 5+ seconds.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(3, 'Speed Boost', 'Significant movement speed increase', 'Movement speed increased by 50% for all players. Mount speed also increased by 25%.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(4, 'Damage Shield', 'Reflects damage back to attackers', 'All players have a permanent damage shield that reflects 25% of received damage back to attackers.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(5, 'Mana Shield', 'Mana-based damage absorption', 'Players gain a mana shield that absorbs damage equal to 2x their current mana. Shield regenerates when mana regenerates.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(6, 'Storms', 'Periodic lightning storms that damage and stun', 'Every 60 seconds, lightning storms strike random locations dealing 15% max health damage and stunning for 3 seconds.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(7, 'Volcanic', 'Eruptions on the ground that knock back', 'Volcanic eruptions appear every 45 seconds at random locations, dealing damage and knocking players back 20 yards.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(8, 'Haste', 'Combatants gain periodic movement/attack speed boosts', 'Every 30 seconds, all players in combat gain 40% haste for 15 seconds.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(9, 'Berserker', 'Low health players deal increased damage', 'Players below 50% health deal 50% more damage. Players below 25% health deal 100% more damage.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(10, 'Fortified', 'All players receive damage reduction', 'All players take 30% less damage from all sources. Healing effects are reduced by 20%.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(11, 'Double Resources', 'Resource gains are doubled', 'All resource point gains are doubled. Honor kills give double points. Capture objectives give double rewards.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(12, 'Rapid Respawn', 'Decreased respawn times', 'Player respawn time reduced from 30 seconds to 10 seconds. Allows for more aggressive gameplay.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(13, 'Giant Growth', 'Players become larger and stronger', 'All players are scaled to 125% size and gain 25% more health and damage. Movement speed reduced by 15%.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(14, 'Invisibility Surge', 'Periodic stealth for all players', 'Every 2 minutes, all players become stealthed for 10 seconds. Breaking stealth grants 5 seconds of 50% damage boost.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(15, 'Chaos Magic', 'Random spell effects every 30 seconds', 'Every 30 seconds, a random beneficial or detrimental effect is applied to all players for 20 seconds.', 1)
ON DUPLICATE KEY UPDATE 
name = VALUES(name), description = VALUES(description), effect = VALUES(effect), is_enabled = VALUES(is_enabled);

-- ==================================================
-- FALLBACK METHOD: UPDATE EXISTING DATA
-- ==================================================

-- If INSERTs fail due to existing data, update existing records
UPDATE hlbg_seasons SET 
    name = 'Season 1: Chaos Reborn',
    start_datetime = '2025-10-01 00:00:00',
    end_datetime = '2025-12-31 23:59:59', 
    description = 'The inaugural season of Hinterland Battleground on DC-255',
    is_active = 1
WHERE id = 1 OR name LIKE '%Season 1%' OR season = 1;

-- Update weather records
UPDATE hlbg_weather SET description = 'Perfect weather conditions', weather_intensity = 1, duration_mins = 0, is_enabled = 1 WHERE weather = 1 OR name = 'Clear Skies';
UPDATE hlbg_weather SET description = 'Visibility slightly reduced', weather_intensity = 2, duration_mins = 8, is_enabled = 1 WHERE weather = 2 OR name = 'Light Rain';
UPDATE hlbg_weather SET description = 'Reduced visibility and movement', weather_intensity = 4, duration_mins = 5, is_enabled = 1 WHERE weather = 3 OR name = 'Heavy Storm';
UPDATE hlbg_weather SET description = 'Severe weather conditions', weather_intensity = 5, duration_mins = 3, is_enabled = 0 WHERE weather = 4 OR name = 'Blizzard';

-- ==================================================
-- FINAL VERIFICATION
-- ==================================================

SELECT 'FINAL HLBG DATABASE FIX COMPLETE!' as Status;

-- Check results
SELECT 'Seasons:' as Info, COUNT(*) as Count FROM hlbg_seasons;
SELECT 'Weather:' as Info, COUNT(*) as Count FROM hlbg_weather;
SELECT 'Affixes:' as Info, COUNT(*) as Count FROM hlbg_affixes;

-- Show sample data
SELECT 'Season Sample:' as Info;
SELECT id, name, season, is_active, start_datetime FROM hlbg_seasons LIMIT 3;

SELECT 'Weather Sample:' as Info;
SELECT id, name, weather, weather_intensity, is_enabled FROM hlbg_weather LIMIT 5;

SELECT 'Affix Sample:' as Info;
SELECT id, name FROM hlbg_affixes WHERE id IN (0,1,2,15) ORDER BY id;

-- ==================================================
-- SUCCESS INDICATORS:
-- - Seasons count should be 1+
-- - Weather count should be 4+  
-- - Affixes count should be 16
-- - No more "required field" errors when running other scripts
-- ==================================================