-- QUICK FIX for HLBG Database Issues
-- This script fixes the immediate column name problems you're experiencing
-- Run this instead of the full schema if you want to keep your existing data

-- ==================================================
-- QUICK COLUMN FIXES
-- ==================================================

-- Fix hlbg_seasons table - add the datetime columns the script expects
ALTER TABLE `hlbg_seasons` 
ADD COLUMN IF NOT EXISTS `start_datetime` DATETIME NOT NULL DEFAULT '2025-01-01 00:00:00' COMMENT 'Season start date and time',
ADD COLUMN IF NOT EXISTS `end_datetime` DATETIME NOT NULL DEFAULT '2025-12-31 23:59:59' COMMENT 'Season end date and time';

-- Fix hlbg_weather table - add the columns the script expects  
ALTER TABLE `hlbg_weather`
ADD COLUMN IF NOT EXISTS `weather_intensity` INT DEFAULT 1 COMMENT 'Weather intensity level 1-5',
ADD COLUMN IF NOT EXISTS `duration_mins` INT DEFAULT 5 COMMENT 'How long weather lasts',
ADD COLUMN IF NOT EXISTS `is_enabled` TINYINT(1) DEFAULT 1 COMMENT 'Is weather enabled';

-- ==================================================
-- SAFE DATA INSERTION (NO DUPLICATES)
-- ==================================================

-- Insert season data safely
INSERT IGNORE INTO `hlbg_seasons` 
(`name`, `start_datetime`, `end_datetime`, `description`, `is_active`) 
VALUES ('Season 1: Chaos Reborn', '2025-10-01 00:00:00', '2025-12-31 23:59:59', 'The inaugural season of Hinterland Battleground on DC-255', 1);

-- Insert weather data safely
INSERT IGNORE INTO `hlbg_weather` (`name`, `description`, `weather_intensity`, `duration_mins`, `is_enabled`) VALUES
('Clear Skies', 'Perfect weather conditions', 1, 0, 1),
('Light Rain', 'Visibility slightly reduced', 2, 8, 1),
('Heavy Storm', 'Reduced visibility and movement', 4, 5, 1),
('Blizzard', 'Severe weather conditions', 5, 3, 0);

-- Insert affixes safely (complete set)
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

-- ==================================================
-- VERIFICATION
-- ==================================================

SELECT 'Database Quick Fix Complete!' as Status;
SELECT COUNT(*) as 'Total Affixes' FROM hlbg_affixes;
SELECT COUNT(*) as 'Total Weather Effects' FROM hlbg_weather;
SELECT COUNT(*) as 'Total Seasons' FROM hlbg_seasons;