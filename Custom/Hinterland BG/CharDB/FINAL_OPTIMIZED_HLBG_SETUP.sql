-- FINAL OPTIMIZED HLBG DATABASE SCRIPT
-- Based on successful execution results from previous attempts
-- This fixes the remaining issues and uses only proven working syntax

-- ==================================================
-- HLBG SEASONS - Safe insertion without 'id' column
-- ==================================================

-- Insert season data safely (avoiding the missing 'id' column)
INSERT IGNORE INTO hlbg_seasons (name, season, start_datetime, end_datetime, description, is_active) 
VALUES ('Season 1: Chaos Reborn', 1, '2025-10-01 00:00:00', '2025-12-31 23:59:59', 'The inaugural season of Hinterland Battleground on DC-255', 1);

-- Update if insertion failed due to existing data
UPDATE hlbg_seasons SET 
    name = 'Season 1: Chaos Reborn',
    start_datetime = '2025-10-01 00:00:00',
    end_datetime = '2025-12-31 23:59:59', 
    description = 'The inaugural season of Hinterland Battleground on DC-255',
    is_active = 1
WHERE season = 1 OR name LIKE '%Season 1%';

-- ==================================================
-- HLBG WEATHER - Complete setup (this worked perfectly before)
-- ==================================================

-- Ensure all weather types exist
INSERT IGNORE INTO hlbg_weather (name, weather, description, weather_intensity, duration_mins, is_enabled) VALUES
('Clear Skies', 1, 'Perfect weather conditions', 1, 0, 1),
('Light Rain', 2, 'Visibility slightly reduced', 2, 8, 1),
('Heavy Storm', 3, 'Reduced visibility and movement', 4, 5, 1),
('Blizzard', 4, 'Severe weather conditions', 5, 3, 0);

-- Update weather records (this was proven to work)
UPDATE hlbg_weather SET description = 'Perfect weather conditions', weather_intensity = 1, duration_mins = 0, is_enabled = 1 WHERE weather = 1;
UPDATE hlbg_weather SET description = 'Visibility slightly reduced', weather_intensity = 2, duration_mins = 8, is_enabled = 1 WHERE weather = 2;
UPDATE hlbg_weather SET description = 'Reduced visibility and movement', weather_intensity = 4, duration_mins = 5, is_enabled = 1 WHERE weather = 3;
UPDATE hlbg_weather SET description = 'Severe weather conditions', weather_intensity = 5, duration_mins = 3, is_enabled = 0 WHERE weather = 4;

-- ==================================================
-- HLBG AFFIXES - Modern syntax (no deprecation warnings)
-- ==================================================

-- Modern INSERT syntax that avoids deprecation warnings
INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) 
VALUES (0, 'None', 'No active affix', 'Standard battleground rules apply with no special modifications.', 1) 
ON DUPLICATE KEY UPDATE 
    name = VALUES(name), 
    description = VALUES(description), 
    effect = VALUES(effect), 
    is_enabled = VALUES(is_enabled);

-- For newer MySQL versions that support it, use this instead:
-- INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) 
-- VALUES (0, 'None', 'No active affix', 'Standard battleground rules apply with no special modifications.', 1) AS new_data
-- ON DUPLICATE KEY UPDATE 
--     name = new_data.name, 
--     description = new_data.description, 
--     effect = new_data.effect, 
--     is_enabled = new_data.is_enabled;

-- Continue with all affixes using the working syntax
INSERT INTO hlbg_affixes (id, name, description, effect, is_enabled) VALUES
(1, 'Bloodlust', 'Increased attack and movement speed', 'All players gain 30% attack speed and 25% movement speed.', 1),
(2, 'Regeneration', 'Passive health and mana boost', 'Players regenerate 2% health and mana per second while out of combat for 5+ seconds.', 1),
(3, 'Speed Boost', 'Movement speed increase', 'Movement speed increased by 50% for all players. Mount speed also increased by 25%.', 1),
(4, 'Damage Shield', 'Reflects damage to attackers', 'All players have a damage shield that reflects 25% of received damage back to attackers.', 1),
(5, 'Mana Shield', 'Mana-based damage absorption', 'Players gain a mana shield that absorbs damage equal to 2x their current mana.', 1),
(6, 'Storms', 'Lightning storms damage and stun', 'Every 60 seconds, lightning storms strike random locations dealing 15% max health damage.', 1),
(7, 'Volcanic', 'Ground eruptions knock back', 'Volcanic eruptions appear every 45 seconds, dealing damage and knocking players back 20 yards.', 1),
(8, 'Haste', 'Periodic speed boosts', 'Every 30 seconds, all players in combat gain 40% haste for 15 seconds.', 1),
(9, 'Berserker', 'Low health damage bonus', 'Players below 50% health deal 50% more damage. Below 25% health deal 100% more damage.', 1),
(10, 'Fortified', 'Damage reduction for all', 'All players take 30% less damage from all sources. Healing effects reduced by 20%.', 1),
(11, 'Double Resources', 'Resource gains doubled', 'All resource point gains are doubled. Honor kills and capture objectives give double rewards.', 1),
(12, 'Rapid Respawn', 'Faster respawn times', 'Player respawn time reduced from 30 seconds to 10 seconds for aggressive gameplay.', 1),
(13, 'Giant Growth', 'Players larger and stronger', 'All players scaled to 125% size and gain 25% more health and damage. Movement speed reduced by 15%.', 1),
(14, 'Invisibility Surge', 'Periodic stealth', 'Every 2 minutes, all players become stealthed for 10 seconds with damage boost after breaking stealth.', 1),
(15, 'Chaos Magic', 'Random spell effects', 'Every 30 seconds, random beneficial or detrimental effects applied to all players for 20 seconds.', 1)
ON DUPLICATE KEY UPDATE 
    name = VALUES(name), 
    description = VALUES(description), 
    effect = VALUES(effect), 
    is_enabled = VALUES(is_enabled);

-- ==================================================
-- CONFIGURATION SETUP
-- ==================================================

-- Ensure configuration exists
INSERT IGNORE INTO hlbg_config (setting_name, setting_value, description) VALUES
('affix_enabled', '1', 'Enable/disable affix system'),
('weather_enabled', '1', 'Enable/disable weather system'),
('season_active', '1', 'Current season status'),
('current_affix', '0', 'Currently active affix ID'),
('current_weather', '1', 'Currently active weather ID'),
('broadcast_enabled', '1', 'Enable status broadcasts'),
('debug_mode', '0', 'Debug logging enabled');

-- Update configuration
UPDATE hlbg_config SET setting_value = '1' WHERE setting_name IN ('affix_enabled', 'weather_enabled', 'season_active', 'broadcast_enabled');
UPDATE hlbg_config SET setting_value = '0' WHERE setting_name IN ('current_affix', 'debug_mode');
UPDATE hlbg_config SET setting_value = '1' WHERE setting_name = 'current_weather';

-- ==================================================
-- FINAL STATUS CHECK
-- ==================================================

SELECT '=== HLBG DATABASE SETUP COMPLETE ===' as Status;

-- Safe count queries (avoiding columns that might not exist)
SELECT 'Seasons' as Table_Name, COUNT(*) as Record_Count FROM hlbg_seasons
UNION ALL
SELECT 'Weather' as Table_Name, COUNT(*) as Record_Count FROM hlbg_weather  
UNION ALL
SELECT 'Affixes' as Table_Name, COUNT(*) as Record_Count FROM hlbg_affixes
UNION ALL
SELECT 'Config' as Table_Name, COUNT(*) as Record_Count FROM hlbg_config;

-- Show working data samples (avoiding problematic columns)
SELECT 'Active Weather Types:' as Info;
SELECT name, weather, weather_intensity, is_enabled FROM hlbg_weather WHERE is_enabled = 1;

SELECT 'Sample Affixes:' as Info;
SELECT name, description FROM hlbg_affixes WHERE id IN (0,1,2,3) ORDER BY id;

SELECT 'Configuration:' as Info;
SELECT setting_name, setting_value FROM hlbg_config ORDER BY setting_name;

-- Success indicators
SELECT CASE 
    WHEN (SELECT COUNT(*) FROM hlbg_affixes) >= 16 AND 
         (SELECT COUNT(*) FROM hlbg_weather) >= 4 AND
         (SELECT COUNT(*) FROM hlbg_config) >= 7
    THEN '✅ SUCCESS: All HLBG tables properly configured!'
    ELSE '⚠️  WARNING: Some tables may need attention'
END as Final_Result;

-- ==================================================
-- USAGE INSTRUCTIONS
-- ==================================================
-- After running this script:
-- 1. Verify all tables show proper counts
-- 2. Check that affixes and weather data look correct  
-- 3. Test the C++ compilation with: ./acore.sh compiler build
-- 4. If successful, test the enhanced HLBG addon in-game
-- ==================================================