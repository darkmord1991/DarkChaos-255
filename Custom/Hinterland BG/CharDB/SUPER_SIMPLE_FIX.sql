-- SUPER SIMPLE HLBG Database Fix
-- Compatible with ANY MySQL version (even very old ones)
-- No advanced syntax, just basic ALTER TABLE and INSERT statements

-- ==================================================
-- ADD MISSING COLUMNS (ignore errors if they already exist)
-- ==================================================

-- Fix hlbg_seasons table
ALTER TABLE hlbg_seasons ADD COLUMN start_datetime DATETIME NOT NULL DEFAULT '2025-01-01 00:00:00';
-- If you get "Duplicate column name" error, that's OK - column already exists

ALTER TABLE hlbg_seasons ADD COLUMN end_datetime DATETIME NOT NULL DEFAULT '2025-12-31 23:59:59'; 
-- If you get "Duplicate column name" error, that's OK - column already exists

-- Fix hlbg_weather table  
ALTER TABLE hlbg_weather ADD COLUMN weather_intensity INT DEFAULT 1;
-- If you get "Duplicate column name" error, that's OK - column already exists

ALTER TABLE hlbg_weather ADD COLUMN duration_mins INT DEFAULT 5;
-- If you get "Duplicate column name" error, that's OK - column already exists

ALTER TABLE hlbg_weather ADD COLUMN is_enabled TINYINT(1) DEFAULT 1;
-- If you get "Duplicate column name" error, that's OK - column already exists

-- ==================================================
-- INSERT DATA (basic INSERT statements)
-- ==================================================

-- Insert season data - will fail if already exists, that's OK
INSERT INTO hlbg_seasons (name, start_datetime, end_datetime, description, is_active) 
VALUES ('Season 1: Chaos Reborn', '2025-10-01 00:00:00', '2025-12-31 23:59:59', 'The inaugural season of Hinterland Battleground on DC-255', 1);

-- Insert weather data - will fail if already exists, that's OK  
INSERT INTO hlbg_weather (name, description, weather_intensity, duration_mins, is_enabled) 
VALUES ('Clear Skies', 'Perfect weather conditions', 1, 0, 1);

INSERT INTO hlbg_weather (name, description, weather_intensity, duration_mins, is_enabled) 
VALUES ('Light Rain', 'Visibility slightly reduced', 2, 8, 1);

INSERT INTO hlbg_weather (name, description, weather_intensity, duration_mins, is_enabled) 
VALUES ('Heavy Storm', 'Reduced visibility and movement', 4, 5, 1);

INSERT INTO hlbg_weather (name, description, weather_intensity, duration_mins, is_enabled) 
VALUES ('Blizzard', 'Severe weather conditions', 5, 3, 0);

-- Update existing affixes with better descriptions (these should work)
UPDATE hlbg_affixes SET 
    name = 'None',
    description = 'No active affix', 
    effect = 'Standard battleground rules apply with no special modifications.'
WHERE id = 0;

UPDATE hlbg_affixes SET 
    name = 'Bloodlust',
    description = 'Increased attack and movement speed for all players', 
    effect = 'All players gain 30% attack speed and 25% movement speed. Stacks with other speed effects.'
WHERE id = 1;

UPDATE hlbg_affixes SET 
    name = 'Regeneration',
    description = 'Passive health and mana regeneration boost', 
    effect = 'Players regenerate 2% health and mana per second while out of combat for 5+ seconds.'
WHERE id = 2;

UPDATE hlbg_affixes SET 
    name = 'Speed Boost',
    description = 'Significant movement speed increase', 
    effect = 'Movement speed increased by 50% for all players. Mount speed also increased by 25%.'
WHERE id = 3;

UPDATE hlbg_affixes SET 
    name = 'Damage Shield',
    description = 'Reflects damage back to attackers', 
    effect = 'All players have a permanent damage shield that reflects 25% of received damage back to attackers.'
WHERE id = 4;

UPDATE hlbg_affixes SET 
    name = 'Mana Shield',
    description = 'Mana-based damage absorption', 
    effect = 'Players gain a mana shield that absorbs damage equal to 2x their current mana. Shield regenerates when mana regenerates.'
WHERE id = 5;

UPDATE hlbg_affixes SET 
    name = 'Storms',
    description = 'Periodic lightning storms that damage and stun', 
    effect = 'Every 60 seconds, lightning storms strike random locations dealing 15% max health damage and stunning for 3 seconds.'
WHERE id = 6;

UPDATE hlbg_affixes SET 
    name = 'Volcanic',
    description = 'Eruptions on the ground that knock back', 
    effect = 'Volcanic eruptions appear every 45 seconds at random locations, dealing damage and knocking players back 20 yards.'
WHERE id = 7;

UPDATE hlbg_affixes SET 
    name = 'Haste',
    description = 'Combatants gain periodic movement/attack speed boosts', 
    effect = 'Every 30 seconds, all players in combat gain 40% haste for 15 seconds.'
WHERE id = 8;

UPDATE hlbg_affixes SET 
    name = 'Berserker',
    description = 'Low health players deal increased damage', 
    effect = 'Players below 50% health deal 50% more damage. Players below 25% health deal 100% more damage.'
WHERE id = 9;

UPDATE hlbg_affixes SET 
    name = 'Fortified',
    description = 'All players receive damage reduction', 
    effect = 'All players take 30% less damage from all sources. Healing effects are reduced by 20%.'
WHERE id = 10;

UPDATE hlbg_affixes SET 
    name = 'Double Resources',
    description = 'Resource gains are doubled', 
    effect = 'All resource point gains are doubled. Honor kills give double points. Capture objectives give double rewards.'
WHERE id = 11;

UPDATE hlbg_affixes SET 
    name = 'Rapid Respawn',
    description = 'Decreased respawn times', 
    effect = 'Player respawn time reduced from 30 seconds to 10 seconds. Allows for more aggressive gameplay.'
WHERE id = 12;

UPDATE hlbg_affixes SET 
    name = 'Giant Growth',
    description = 'Players become larger and stronger', 
    effect = 'All players are scaled to 125% size and gain 25% more health and damage. Movement speed reduced by 15%.'
WHERE id = 13;

UPDATE hlbg_affixes SET 
    name = 'Invisibility Surge',
    description = 'Periodic stealth for all players', 
    effect = 'Every 2 minutes, all players become stealthed for 10 seconds. Breaking stealth grants 5 seconds of 50% damage boost.'
WHERE id = 14;

UPDATE hlbg_affixes SET 
    name = 'Chaos Magic',
    description = 'Random spell effects every 30 seconds', 
    effect = 'Every 30 seconds, a random beneficial or detrimental effect is applied to all players for 20 seconds.'
WHERE id = 15;

-- ==================================================
-- SIMPLE VERIFICATION
-- ==================================================

SELECT 'Basic HLBG Database Fix Complete!' as Status;
SELECT COUNT(*) as Total_Affixes FROM hlbg_affixes;
SELECT COUNT(*) as Total_Weather FROM hlbg_weather;  
SELECT COUNT(*) as Total_Seasons FROM hlbg_seasons;

-- ==================================================
-- INSTRUCTIONS:
-- 1. Run this script in your MySQL client
-- 2. Ignore any "Duplicate column name" errors - those are OK
-- 3. Ignore any "Duplicate entry" errors - those are OK  
-- 4. The important thing is that the tables get the missing columns
-- 5. After this, the addon should work properly
-- ==================================================