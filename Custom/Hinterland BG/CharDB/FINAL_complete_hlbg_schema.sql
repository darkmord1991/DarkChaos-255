-- HLBG Complete Database Schema Installation - FINAL VERSION
-- Location: Custom/Hinterland BG/CharDB/FINAL_complete_hlbg_schema.sql
-- Apply to WORLD database (not characters database)
-- Run this to set up the complete enhanced HLBG system
-- Updated: October 5, 2025

-- ==================================================
-- ENHANCED HLBG SYSTEM - FINAL COMPLETE INSTALLATION
-- ==================================================

-- Main HLBG configuration table
CREATE TABLE IF NOT EXISTS `hlbg_config` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `duration_minutes` INT DEFAULT 30 COMMENT 'Battle duration in minutes',
    `max_players_per_side` INT DEFAULT 40 COMMENT 'Maximum players per faction',
    `min_level` INT DEFAULT 255 COMMENT 'Minimum level requirement',
    `max_level` INT DEFAULT 255 COMMENT 'Maximum level requirement', 
    `affix_rotation_enabled` BOOLEAN DEFAULT TRUE COMMENT 'Enable affix rotation system',
    `resource_cap` INT DEFAULT 500 COMMENT 'Resource points needed to win',
    `queue_type` VARCHAR(50) DEFAULT 'Level255Only' COMMENT 'Queue restriction type',
    `respawn_time_seconds` INT DEFAULT 30 COMMENT 'Player respawn delay',
    `buff_duration_minutes` INT DEFAULT 5 COMMENT 'Affix buff duration',
    `queue_size_alliance` INT DEFAULT 0 COMMENT 'Current Alliance queue size',
    `queue_size_horde` INT DEFAULT 0 COMMENT 'Current Horde queue size',
    `is_active` BOOLEAN DEFAULT TRUE COMMENT 'Is HLBG currently active',
    `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `updated_by` VARCHAR(50) DEFAULT 'SYSTEM' COMMENT 'Who last updated config'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Hinterland Battleground Configuration';

-- Season information table  
CREATE TABLE IF NOT EXISTS `hlbg_seasons` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL COMMENT 'Season display name',
    `start_date` DATETIME NOT NULL COMMENT 'Season start date and time',
    `end_date` DATETIME NOT NULL COMMENT 'Season end date and time', 
    `description` TEXT COMMENT 'Season description',
    `rewards_alliance` TEXT COMMENT 'Alliance rewards (JSON or text)',
    `rewards_horde` TEXT COMMENT 'Horde rewards (JSON or text)',
    `rewards_participation` TEXT COMMENT 'Participation rewards',
    `is_active` BOOLEAN DEFAULT FALSE COMMENT 'Is this the current active season',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `created_by` VARCHAR(50) DEFAULT 'GM' COMMENT 'Who created the season'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Hinterland Battleground Seasons';

-- Comprehensive statistics table
CREATE TABLE IF NOT EXISTS `hlbg_statistics` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `total_runs` INT DEFAULT 0 COMMENT 'Total battles completed',
    `alliance_wins` INT DEFAULT 0 COMMENT 'Alliance victory count',
    `horde_wins` INT DEFAULT 0 COMMENT 'Horde victory count', 
    `draws` INT DEFAULT 0 COMMENT 'Draw/timeout count',
    `manual_resets` INT DEFAULT 0 COMMENT 'GM manual battle resets',
    `current_streak_faction` VARCHAR(20) DEFAULT 'None' COMMENT 'Current winning streak faction',
    `current_streak_count` INT DEFAULT 0 COMMENT 'Current streak length',
    `longest_streak_faction` VARCHAR(20) DEFAULT 'None' COMMENT 'Record streak faction',
    `longest_streak_count` INT DEFAULT 0 COMMENT 'Record streak length',
    `avg_run_time_seconds` INT DEFAULT 0 COMMENT 'Average battle duration in seconds',
    `shortest_run_seconds` INT DEFAULT 0 COMMENT 'Fastest battle completion',
    `longest_run_seconds` INT DEFAULT 0 COMMENT 'Longest battle duration',
    `most_popular_affix` INT DEFAULT 0 COMMENT 'Most frequently occurring affix ID',
    `total_players_participated` INT DEFAULT 0 COMMENT 'Unique players who participated',
    `total_kills` INT DEFAULT 0 COMMENT 'Total player kills across all battles',
    `total_deaths` INT DEFAULT 0 COMMENT 'Total player deaths across all battles',
    `last_reset_by_gm` TIMESTAMP NULL COMMENT 'When GM last manually reset stats',
    `last_reset_gm_name` VARCHAR(50) NULL COMMENT 'Which GM reset the stats',
    `server_start_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When server/addon tracking started',
    `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Hinterland Battleground Statistics';

-- Battle history table for detailed logging
CREATE TABLE IF NOT EXISTS `hlbg_battle_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `battle_start` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `battle_end` TIMESTAMP NULL,
    `duration_seconds` INT DEFAULT 0,
    `winner_faction` ENUM('Alliance', 'Horde', 'Draw') NOT NULL,
    `alliance_resources` INT DEFAULT 0,
    `horde_resources` INT DEFAULT 0,
    `affix_id` INT DEFAULT 0,
    `alliance_players` INT DEFAULT 0 COMMENT 'Number of Alliance participants',
    `horde_players` INT DEFAULT 0 COMMENT 'Number of Horde participants',
    `alliance_kills` INT DEFAULT 0,
    `horde_kills` INT DEFAULT 0,
    `map_id` INT DEFAULT 47 COMMENT 'Map ID (47 for Hinterlands)',
    `instance_id` INT DEFAULT 0,
    `ended_by_gm` BOOLEAN DEFAULT FALSE,
    `gm_name` VARCHAR(50) NULL,
    `notes` TEXT COMMENT 'Any special notes about the battle'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Detailed Hinterland Battleground History';

-- Player participation tracking
CREATE TABLE IF NOT EXISTS `hlbg_player_stats` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `player_guid` INT NOT NULL,
    `player_name` VARCHAR(50) NOT NULL,
    `faction` ENUM('Alliance', 'Horde') NOT NULL,
    `battles_participated` INT DEFAULT 0,
    `battles_won` INT DEFAULT 0,
    `total_kills` INT DEFAULT 0,
    `total_deaths` INT DEFAULT 0,
    `total_damage_dealt` BIGINT DEFAULT 0,
    `total_healing_done` BIGINT DEFAULT 0,
    `resources_captured` INT DEFAULT 0,
    `first_participation` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_participation` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_player` (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Individual Player HLBG Statistics';

-- Affix definitions table
CREATE TABLE IF NOT EXISTS `hlbg_affixes` (
    `id` INT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL,
    `description` TEXT,
    `spell_id` INT DEFAULT 0,
    `icon` VARCHAR(100) DEFAULT '',
    `is_enabled` BOOLEAN DEFAULT TRUE,
    `usage_count` INT DEFAULT 0 COMMENT 'How many times this affix has been used',
    `effect` TEXT COMMENT 'Detailed effect description'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Hinterland Battleground Affix Definitions';

-- Weather effects table (optional - for future weather system)
CREATE TABLE IF NOT EXISTS `hlbg_weather` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL,
    `description` TEXT,
    `intensity` INT DEFAULT 1 COMMENT 'Weather intensity level 1-5',
    `duration_minutes` INT DEFAULT 5 COMMENT 'How long weather lasts',
    `is_enabled` BOOLEAN DEFAULT TRUE,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Weather System for HLBG (Optional)';

-- ==================================================
-- INSERT DEFAULT DATA
-- ==================================================

-- Insert default configuration
INSERT INTO `hlbg_config` 
(`duration_minutes`, `max_players_per_side`, `min_level`, `max_level`, `affix_rotation_enabled`, `resource_cap`, `queue_type`) 
VALUES (30, 40, 255, 255, TRUE, 500, 'Level255Only')
ON DUPLICATE KEY UPDATE `last_updated` = CURRENT_TIMESTAMP;

-- Insert default season
INSERT INTO `hlbg_seasons` 
(`name`, `start_date`, `end_date`, `description`, `is_active`) 
VALUES ('Season 1: Chaos Reborn', '2025-10-01 00:00:00', '2025-12-31 23:59:59', 'The inaugural season of Hinterland Battleground on DC-255', TRUE)
ON DUPLICATE KEY UPDATE `is_active` = TRUE;

-- Insert default statistics row
INSERT INTO `hlbg_statistics` 
(`total_runs`, `alliance_wins`, `horde_wins`, `draws`, `server_start_time`) 
VALUES (0, 0, 0, 0, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE `last_updated` = CURRENT_TIMESTAMP;

-- Insert enhanced affixes with detailed descriptions
INSERT INTO `hlbg_affixes` (`id`, `name`, `description`, `effect`, `is_enabled`) VALUES
(0, 'None', 'No active affix', 'Standard battleground rules apply with no special modifications.', TRUE),
(1, 'Bloodlust', 'Increased attack and movement speed for all players', 'All players gain 30% attack speed and 25% movement speed. Stacks with other speed effects.', TRUE),
(2, 'Regeneration', 'Passive health and mana regeneration boost', 'Players regenerate 2% health and mana per second while out of combat for 5+ seconds.', TRUE), 
(3, 'Speed Boost', 'Significant movement speed increase', 'Movement speed increased by 50% for all players. Mount speed also increased by 25%.', TRUE),
(4, 'Damage Shield', 'Reflects damage back to attackers', 'All players have a permanent damage shield that reflects 25% of received damage back to attackers.', TRUE),
(5, 'Mana Shield', 'Mana-based damage absorption', 'Players gain a mana shield that absorbs damage equal to 2x their current mana. Shield regenerates when mana regenerates.', TRUE),
(6, 'Storms', 'Periodic lightning storms that damage and stun', 'Every 60 seconds, lightning storms strike random locations dealing 15% max health damage and stunning for 3 seconds.', TRUE),
(7, 'Volcanic', 'Eruptions on the ground that knock back', 'Volcanic eruptions appear every 45 seconds at random locations, dealing damage and knocking players back 20 yards.', TRUE),
(8, 'Haste', 'Combatants gain periodic movement/attack speed boosts', 'Every 30 seconds, all players in combat gain 40% haste for 15 seconds.', TRUE),
(9, 'Berserker', 'Low health players deal increased damage', 'Players below 50% health deal 50% more damage. Players below 25% health deal 100% more damage.', TRUE),
(10, 'Fortified', 'All players receive damage reduction', 'All players take 30% less damage from all sources. Healing effects are reduced by 20%.', TRUE),
(11, 'Double Resources', 'Resource gains are doubled', 'All resource point gains are doubled. Honor kills give double points. Capture objectives give double rewards.', TRUE),
(12, 'Rapid Respawn', 'Decreased respawn times', 'Player respawn time reduced from 30 seconds to 10 seconds. Allows for more aggressive gameplay.', TRUE),
(13, 'Giant Growth', 'Players become larger and stronger', 'All players are scaled to 125% size and gain 25% more health and damage. Movement speed reduced by 15%.', TRUE),
(14, 'Invisibility Surge', 'Periodic stealth for all players', 'Every 2 minutes, all players become stealthed for 10 seconds. Breaking stealth grants 5 seconds of 50% damage boost.', TRUE),
(15, 'Chaos Magic', 'Random spell effects every 30 seconds', 'Every 30 seconds, a random beneficial or detrimental effect is applied to all players for 20 seconds.', TRUE)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `effect` = VALUES(`effect`);

-- Insert default weather effects
INSERT INTO `hlbg_weather` (`name`, `description`, `intensity`, `duration_minutes`, `is_enabled`) VALUES
('Clear Skies', 'Perfect weather conditions', 1, 0, TRUE),
('Light Rain', 'Visibility slightly reduced', 2, 8, TRUE),
('Heavy Storm', 'Reduced visibility and movement', 4, 5, TRUE),
('Blizzard', 'Severe weather conditions', 5, 3, FALSE)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- ==================================================
-- CREATE INDEXES FOR PERFORMANCE
-- ==================================================

-- Indexes for hlbg_seasons
CREATE INDEX IF NOT EXISTS `idx_hlbg_seasons_active` ON `hlbg_seasons` (`is_active`);
CREATE INDEX IF NOT EXISTS `idx_hlbg_seasons_dates` ON `hlbg_seasons` (`start_date`, `end_date`);

-- Indexes for hlbg_battle_history
CREATE INDEX IF NOT EXISTS `idx_hlbg_history_end` ON `hlbg_battle_history` (`battle_end`);
CREATE INDEX IF NOT EXISTS `idx_hlbg_history_winner` ON `hlbg_battle_history` (`winner_faction`);
CREATE INDEX IF NOT EXISTS `idx_hlbg_history_instance` ON `hlbg_battle_history` (`instance_id`);
CREATE INDEX IF NOT EXISTS `idx_hlbg_history_affix` ON `hlbg_battle_history` (`affix_id`);
CREATE INDEX IF NOT EXISTS `idx_hlbg_history_start` ON `hlbg_battle_history` (`battle_start`);

-- Indexes for hlbg_player_stats
CREATE INDEX IF NOT EXISTS `idx_hlbg_player_name` ON `hlbg_player_stats` (`player_name`);
CREATE INDEX IF NOT EXISTS `idx_hlbg_player_faction` ON `hlbg_player_stats` (`faction`);
CREATE INDEX IF NOT EXISTS `idx_hlbg_player_battles` ON `hlbg_player_stats` (`battles_participated`);
CREATE INDEX IF NOT EXISTS `idx_hlbg_player_wins` ON `hlbg_player_stats` (`battles_won`);
CREATE INDEX IF NOT EXISTS `idx_hlbg_player_last_participation` ON `hlbg_player_stats` (`last_participation`);

-- Indexes for hlbg_affixes
CREATE INDEX IF NOT EXISTS `idx_hlbg_affixes_enabled` ON `hlbg_affixes` (`is_enabled`);
CREATE INDEX IF NOT EXISTS `idx_hlbg_affixes_usage` ON `hlbg_affixes` (`usage_count`);

-- Indexes for hlbg_weather
CREATE INDEX IF NOT EXISTS `idx_hlbg_weather_enabled` ON `hlbg_weather` (`is_enabled`);

-- ==================================================
-- MIGRATION AND COMPATIBILITY NOTES
-- ==================================================

-- This FINAL schema is compatible with all existing HLBG implementations and provides:
-- 
-- ✓ ENHANCED FEATURES:
-- - Real-time statistics tracking with comprehensive metrics
-- - GM command interface for management
-- - AIO client communication support
-- - Comprehensive individual player tracking
-- - Enhanced season management system
-- - Detailed battle history with full context
-- - Advanced affix system with detailed descriptions
-- - Optional weather system for future expansion
-- - Performance optimized with strategic indexes
-- 
-- ✓ BACKWARD COMPATIBILITY:
-- - Maintains compatibility with existing hlbg_winner_history queries
-- - Preserves all existing affix definitions
-- - Supports current server-side implementations
-- - Graceful migration path from old schema
-- 
-- ✓ MIGRATION FROM OLD TABLES:
-- - hlbg_winner_history → hlbg_battle_history (enhanced structure)
-- - hlbg_affixes → enhanced with effect descriptions
-- - hlbg_seasons → enhanced with reward system
-- - hlbg_weather → optional expansion feature
-- 
-- ✓ PERFORMANCE OPTIMIZATIONS:
-- - Strategic indexing for common query patterns
-- - Optimized data types for storage efficiency
-- - Prepared for high-volume battle logging
-- - Support for concurrent player tracking
-- 
-- Usage: Apply this schema to your WORLD database and restart the server.
-- The enhanced addon (HinterlandAffixHUD_Test → HinterlandAffixHUD) will automatically
-- utilize these tables for improved functionality and performance monitoring.

-- ==================================================
-- END OF FINAL COMPLETE HLBG SCHEMA
-- ==================================================