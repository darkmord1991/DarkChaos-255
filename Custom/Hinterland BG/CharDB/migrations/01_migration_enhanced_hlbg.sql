-- HLBG Enhanced Schema Migration - MySQL 5.7/8.0 Compatible
-- Location: Custom/Hinterland BG/CharDB/01_migration_enhanced_hlbg.sql
-- Apply to WORLD database - Migration-safe version

-- ==================================================
-- ENHANCED HLBG SYSTEM - MIGRATION SCRIPT
-- This script safely migrates from existing schema to enhanced version
-- ==================================================

-- 1. Create new tables that don't exist yet
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

-- ==================================================
-- MIGRATE EXISTING TABLES
-- ==================================================

-- 2. Enhance existing hlbg_affixes table (add missing columns)
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_affixes' AND COLUMN_NAME = 'description') = 0,
    'ALTER TABLE hlbg_affixes ADD COLUMN description TEXT AFTER name',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_affixes' AND COLUMN_NAME = 'spell_id') = 0,
    'ALTER TABLE hlbg_affixes ADD COLUMN spell_id INT DEFAULT 0 AFTER description',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_affixes' AND COLUMN_NAME = 'icon') = 0,
    'ALTER TABLE hlbg_affixes ADD COLUMN icon VARCHAR(100) DEFAULT \'\' AFTER spell_id',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_affixes' AND COLUMN_NAME = 'is_enabled') = 0,
    'ALTER TABLE hlbg_affixes ADD COLUMN is_enabled BOOLEAN DEFAULT TRUE AFTER icon',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_affixes' AND COLUMN_NAME = 'usage_count') = 0,
    'ALTER TABLE hlbg_affixes ADD COLUMN usage_count INT DEFAULT 0 COMMENT \'How many times this affix has been used\' AFTER is_enabled',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3. Enhance existing hlbg_seasons table (add missing columns)
-- Note: Using starts_at/ends_at instead of start_date/end_date to avoid duplicates
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_seasons' AND COLUMN_NAME = 'starts_at') = 0,
    'ALTER TABLE hlbg_seasons ADD COLUMN starts_at DATETIME NULL AFTER name',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_seasons' AND COLUMN_NAME = 'ends_at') = 0,
    'ALTER TABLE hlbg_seasons ADD COLUMN ends_at DATETIME NULL AFTER starts_at',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_seasons' AND COLUMN_NAME = 'rewards_alliance') = 0,
    'ALTER TABLE hlbg_seasons ADD COLUMN rewards_alliance TEXT COMMENT \'Alliance rewards (JSON or text)\' AFTER description',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_seasons' AND COLUMN_NAME = 'rewards_horde') = 0,
    'ALTER TABLE hlbg_seasons ADD COLUMN rewards_horde TEXT COMMENT \'Horde rewards (JSON or text)\' AFTER rewards_alliance',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_seasons' AND COLUMN_NAME = 'rewards_participation') = 0,
    'ALTER TABLE hlbg_seasons ADD COLUMN rewards_participation TEXT COMMENT \'Participation rewards\' AFTER rewards_horde',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_seasons' AND COLUMN_NAME = 'is_active') = 0,
    'ALTER TABLE hlbg_seasons ADD COLUMN is_active BOOLEAN DEFAULT FALSE COMMENT \'Is this the current active season\' AFTER rewards_participation',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_seasons' AND COLUMN_NAME = 'created_at') = 0,
    'ALTER TABLE hlbg_seasons ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP AFTER is_active',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_seasons' AND COLUMN_NAME = 'created_by') = 0,
    'ALTER TABLE hlbg_seasons ADD COLUMN created_by VARCHAR(50) DEFAULT \'GM\' COMMENT \'Who created the season\' AFTER created_at',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ==================================================
-- INSERT DEFAULT DATA (SAFE)
-- ==================================================

-- Insert default configuration
INSERT IGNORE INTO `hlbg_config` 
(`duration_minutes`, `max_players_per_side`, `min_level`, `max_level`, `affix_rotation_enabled`, `resource_cap`, `queue_type`) 
VALUES (30, 40, 255, 255, TRUE, 500, 'Level255Only');

-- Insert default season (update existing Season 1 if it exists)
INSERT INTO `hlbg_seasons` (`name`, `starts_at`, `ends_at`, `description`, `is_active`) 
VALUES ('Season 1: Chaos Reborn', '2025-10-01 00:00:00', '2025-12-31 23:59:59', 'The inaugural season of Hinterland Battleground', TRUE)
ON DUPLICATE KEY UPDATE 
    `starts_at` = VALUES(`starts_at`),
    `ends_at` = VALUES(`ends_at`),
    `description` = VALUES(`description`),
    `is_active` = TRUE;

-- Insert default statistics row
INSERT IGNORE INTO `hlbg_statistics` 
(`total_runs`, `alliance_wins`, `horde_wins`, `draws`, `server_start_time`) 
VALUES (0, 0, 0, 0, CURRENT_TIMESTAMP);

-- Insert enhanced affix data (update existing, add new)
INSERT INTO `hlbg_affixes` (`id`, `name`, `description`, `is_enabled`) VALUES
(0, 'None', 'No active affix', TRUE),
(1, 'Bloodlust', 'Increased attack and movement speed for all players', TRUE),
(2, 'Regeneration', 'Passive health and mana regeneration boost', TRUE), 
(3, 'Speed Boost', 'Significant movement speed increase', TRUE),
(4, 'Damage Shield', 'Reflects damage back to attackers', TRUE),
(5, 'Mana Shield', 'Mana-based damage absorption', TRUE),
(6, 'Storms', 'Periodic lightning storms that damage and stun', TRUE),
(7, 'Volcanic', 'Eruptions on the ground that knock back', TRUE),
(8, 'Haste', 'Combatants gain periodic movement/attack speed boosts', TRUE),
(9, 'Berserker', 'Low health players deal increased damage', TRUE),
(10, 'Fortified', 'All players receive damage reduction', TRUE)
ON DUPLICATE KEY UPDATE 
    `name` = VALUES(`name`),
    `description` = VALUES(`description`),
    `is_enabled` = VALUES(`is_enabled`);

-- ==================================================
-- CREATE INDEXES (MySQL 5.7/8.0 Compatible)
-- ==================================================

-- Check and create indexes safely
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_seasons' AND INDEX_NAME = 'idx_hlbg_seasons_active') = 0,
    'CREATE INDEX idx_hlbg_seasons_active ON hlbg_seasons (is_active)',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_battle_history' AND INDEX_NAME = 'idx_hlbg_history_end') = 0,
    'CREATE INDEX idx_hlbg_history_end ON hlbg_battle_history (battle_end)',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_battle_history' AND INDEX_NAME = 'idx_hlbg_history_winner') = 0,
    'CREATE INDEX idx_hlbg_history_winner ON hlbg_battle_history (winner_faction)',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_battle_history' AND INDEX_NAME = 'idx_hlbg_history_instance') = 0,
    'CREATE INDEX idx_hlbg_history_instance ON hlbg_battle_history (instance_id)',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_player_stats' AND INDEX_NAME = 'idx_hlbg_player_name') = 0,
    'CREATE INDEX idx_hlbg_player_name ON hlbg_player_stats (player_name)',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hlbg_player_stats' AND INDEX_NAME = 'idx_hlbg_player_faction') = 0,
    'CREATE INDEX idx_hlbg_player_faction ON hlbg_player_stats (faction)',
    'SELECT 1'
));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ==================================================
-- MIGRATION COMPLETE
-- ==================================================

SELECT 'HLBG Enhanced Schema Migration Complete!' as Status;
SELECT 'Your existing tables have been safely enhanced with new features.' as Message;
SELECT 'New tables: hlbg_config, hlbg_statistics, hlbg_battle_history, hlbg_player_stats' as NewTables;
SELECT 'Enhanced tables: hlbg_affixes, hlbg_seasons' as EnhancedTables;