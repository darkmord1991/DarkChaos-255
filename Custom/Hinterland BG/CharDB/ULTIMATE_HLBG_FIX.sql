-- ULTIMATE HLBG DATABASE FIX
-- Based on the error analysis from the previous attempt
-- This handles the actual table structure discovered through errors

-- ==================================================
-- ANALYSIS OF ERRORS FROM PREVIOUS ATTEMPT
-- ==================================================
-- Error: "Unknown column 'id'" means the tables don't have 'id' columns
-- Success: hlbg_weather updates worked with 'weather', 'name' columns
-- Success: hlbg_affixes insertions worked with 'id' column
-- This suggests different table structures

-- ==================================================
-- SAFE INSERTIONS - HLBG SEASONS TABLE
-- ==================================================
-- Based on error: "Unknown column 'id'" - try without id
-- Try alternative column structures

-- Method 1: Try with minimal required fields only
INSERT IGNORE INTO hlbg_seasons (name, season) VALUES ('Season 1: Chaos Reborn', 1);

-- Method 2: If the above works, add more fields
UPDATE hlbg_seasons SET 
    start_datetime = '2025-10-01 00:00:00',
    end_datetime = '2025-12-31 23:59:59',
    description = 'The inaugural season of Hinterland Battleground on DC-255',
    is_active = 1
WHERE name = 'Season 1: Chaos Reborn' OR season = 1;

-- ==================================================
-- SAFE INSERTIONS - HLBG WEATHER TABLE  
-- ==================================================
-- The previous updates worked, so we know these columns exist:
-- 'weather', 'name', 'description', 'weather_intensity', 'duration_mins', 'is_enabled'

-- Insert missing weather types if they don't exist
INSERT IGNORE INTO hlbg_weather (name, weather) VALUES ('Clear Skies', 1);
INSERT IGNORE INTO hlbg_weather (name, weather) VALUES ('Light Rain', 2);  
INSERT IGNORE INTO hlbg_weather (name, weather) VALUES ('Heavy Storm', 3);
INSERT IGNORE INTO hlbg_weather (name, weather) VALUES ('Blizzard', 4);

-- Update all weather records with full details (this worked before)
UPDATE hlbg_weather SET 
    description = 'Perfect weather conditions', 
    weather_intensity = 1, 
    duration_mins = 0, 
    is_enabled = 1 
WHERE weather = 1 OR name = 'Clear Skies';

UPDATE hlbg_weather SET 
    description = 'Visibility slightly reduced', 
    weather_intensity = 2, 
    duration_mins = 8, 
    is_enabled = 1 
WHERE weather = 2 OR name = 'Light Rain';

UPDATE hlbg_weather SET 
    description = 'Reduced visibility and movement', 
    weather_intensity = 4, 
    duration_mins = 5, 
    is_enabled = 1 
WHERE weather = 3 OR name = 'Heavy Storm';

UPDATE hlbg_weather SET 
    description = 'Severe weather conditions', 
    weather_intensity = 5, 
    duration_mins = 3, 
    is_enabled = 0 
WHERE weather = 4 OR name = 'Blizzard';

-- ==================================================
-- COMPLETE AFFIX DATA - MODERN SYNTAX
-- ==================================================
-- The hlbg_affixes table worked with INSERT statements, so use modern syntax
-- Replace deprecated VALUES() function with alias syntax

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(0, 'None', 'No active affix', 'Standard battleground rules apply with no special modifications.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(1, 'Bloodlust', 'Increased attack and movement speed for all players', 'All players gain 30% attack speed and 25% movement speed. Stacks with other speed effects.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(2, 'Regeneration', 'Passive health and mana regeneration boost', 'Players regenerate 2% health and mana per second while out of combat for 5+ seconds.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(3, 'Speed Boost', 'Significant movement speed increase', 'Movement speed increased by 50% for all players. Mount speed also increased by 25%.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(4, 'Damage Shield', 'Reflects damage back to attackers', 'All players have a permanent damage shield that reflects 25% of received damage back to attackers.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(5, 'Mana Shield', 'Mana-based damage absorption', 'Players gain a mana shield that absorbs damage equal to 2x their current mana. Shield regenerates when mana regenerates.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(6, 'Storms', 'Periodic lightning storms that damage and stun', 'Every 60 seconds, lightning storms strike random locations dealing 15% max health damage and stunning for 3 seconds.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(7, 'Volcanic', 'Eruptions on the ground that knock back', 'Volcanic eruptions appear every 45 seconds at random locations, dealing damage and knocking players back 20 yards.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(8, 'Haste', 'Combatants gain periodic movement/attack speed boosts', 'Every 30 seconds, all players in combat gain 40% haste for 15 seconds.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(9, 'Berserker', 'Low health players deal increased damage', 'Players below 50% health deal 50% more damage. Players below 25% health deal 100% more damage.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(10, 'Fortified', 'All players receive damage reduction', 'All players take 30% less damage from all sources. Healing effects are reduced by 20%.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(11, 'Double Resources', 'Resource gains are doubled', 'All resource point gains are doubled. Honor kills give double points. Capture objectives give double rewards.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(12, 'Rapid Respawn', 'Decreased respawn times', 'Player respawn time reduced from 30 seconds to 10 seconds. Allows for more aggressive gameplay.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(13, 'Giant Growth', 'Players become larger and stronger', 'All players are scaled to 125% size and gain 25% more health and damage. Movement speed reduced by 15%.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(14, 'Invisibility Surge', 'Periodic stealth for all players', 'Every 2 minutes, all players become stealthed for 10 seconds. Breaking stealth grants 5 seconds of 50% damage boost.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(15, 'Chaos Magic', 'Random spell effects every 30 seconds', 'Every 30 seconds, a random beneficial or detrimental effect is applied to all players for 20 seconds.', 1) AS new_data
ON DUPLICATE KEY UPDATE 
    name = new_data.name, 
    description = new_data.description, 
    effect = new_data.effect, 
    is_enabled = new_data.is_enabled;

-- ==================================================
-- CONFIGURATION TABLE SETUP
-- ==================================================
-- Ensure proper configuration values exist
INSERT IGNORE INTO hlbg_config (setting_name, setting_value) VALUES ('affix_enabled', '1');
INSERT IGNORE INTO hlbg_config (setting_name, setting_value) VALUES ('weather_enabled', '1');
INSERT IGNORE INTO hlbg_config (setting_name, setting_value) VALUES ('season_active', '1');
INSERT IGNORE INTO hlbg_config (setting_name, setting_value) VALUES ('current_affix', '0');
INSERT IGNORE INTO hlbg_config (setting_name, setting_value) VALUES ('current_weather', '1');
INSERT IGNORE INTO hlbg_config (setting_name, setting_value) VALUES ('broadcast_enabled', '1');
INSERT IGNORE INTO hlbg_config (setting_name, setting_value) VALUES ('debug_mode', '0');

-- Update configuration if it exists
UPDATE hlbg_config SET setting_value = '1' WHERE setting_name = 'affix_enabled';
UPDATE hlbg_config SET setting_value = '1' WHERE setting_name = 'weather_enabled';
UPDATE hlbg_config SET setting_value = '1' WHERE setting_name = 'season_active';

-- ==================================================
-- VERIFICATION QUERIES
-- ==================================================
SELECT 'ULTIMATE HLBG FIX COMPLETED!' as Status;

-- Count records in each table
SELECT 'Table counts:' as Info;
SELECT 'hlbg_seasons' as Table_Name, COUNT(*) as Count FROM hlbg_seasons
UNION ALL
SELECT 'hlbg_weather' as Table_Name, COUNT(*) as Count FROM hlbg_weather  
UNION ALL
SELECT 'hlbg_affixes' as Table_Name, COUNT(*) as Count FROM hlbg_affixes
UNION ALL
SELECT 'hlbg_config' as Table_Name, COUNT(*) as Count FROM hlbg_config;

-- Show sample data (avoiding columns that might not exist)
SELECT 'Sample weather data:' as Info;
SELECT name, weather, weather_intensity FROM hlbg_weather LIMIT 3;

SELECT 'Sample affix data:' as Info;  
SELECT name, description FROM hlbg_affixes WHERE id IN (0,1,2) ORDER BY id;

SELECT 'Configuration settings:' as Info;
SELECT setting_name, setting_value FROM hlbg_config ORDER BY setting_name;

SELECT 'Setup complete! All HLBG tables should now have proper data.' as Final_Status;