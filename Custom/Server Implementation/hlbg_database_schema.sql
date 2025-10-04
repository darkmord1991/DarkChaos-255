-- HLBG Database Schema Implementation
-- Location: data/sql/custom/db_world/

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

-- Insert default configuration
INSERT INTO `hlbg_config` 
(`duration_minutes`, `max_players_per_side`, `min_level`, `max_level`, `affix_rotation_enabled`, `resource_cap`, `queue_type`) 
VALUES (30, 40, 255, 255, TRUE, 500, 'Level255Only')
ON DUPLICATE KEY UPDATE `last_updated` = CURRENT_TIMESTAMP;

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

-- Insert default season
INSERT INTO `hlbg_seasons` 
(`name`, `start_date`, `end_date`, `description`, `is_active`) 
VALUES ('Season 1: Chaos Reborn', '2025-10-01 00:00:00', '2025-12-31 23:59:59', 'The inaugural season of Hinterland Battleground', TRUE)
ON DUPLICATE KEY UPDATE `is_active` = TRUE;

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

-- Insert default statistics row
INSERT INTO `hlbg_statistics` 
(`total_runs`, `alliance_wins`, `horde_wins`, `draws`, `server_start_time`) 
VALUES (0, 0, 0, 0, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE `last_updated` = CURRENT_TIMESTAMP;

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

-- Player participation tracking (optional, for advanced stats)
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
    `usage_count` INT DEFAULT 0 COMMENT 'How many times this affix has been used'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Hinterland Battleground Affix Definitions';

-- Insert default affixes
INSERT INTO `hlbg_affixes` (`id`, `name`, `description`, `is_enabled`) VALUES
(0, 'None', 'No active affix', TRUE),
(1, 'Bloodlust', 'Increased attack and movement speed for all players', TRUE),
(2, 'Regeneration', 'Passive health and mana regeneration boost', TRUE), 
(3, 'Speed Boost', 'Significant movement speed increase', TRUE),
(4, 'Damage Shield', 'Reflects damage back to attackers', TRUE),
(5, 'Mana Shield', 'Mana-based damage absorption', TRUE)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);
