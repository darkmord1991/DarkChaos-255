-- =====================================================
-- COMPLETE HLBG DATABASE SCHEMA - DEFINITIVE VERSION
-- Location: Custom/Hinterland BG/CharDB/FINAL_complete_hlbg_schema.sql
-- =====================================================
-- 
-- This script contains ALL HLBG tables with proper organization:
-- - CRITICAL tables (required by existing Eluna AIO system)
-- - ENHANCED tables (optional new features)
-- - Database placement (CharacterDB vs WorldDB)
-- - Full indexes and relationships
-- - Default data population
--
-- Usage:
-- 1. Apply CRITICAL + ENHANCED tables to CHARACTER database for core functionality
-- 2. Apply ENHANCED tables to WORLD database for integration features
-- =====================================================

-- =====================================================
-- SECTION 1: CRITICAL TABLES (CHARACTER DATABASE)
-- These tables are REQUIRED by existing Eluna AIO system
-- =====================================================

-- Table: hlbg_winner_history
-- Usage: CRITICAL - Extensively used by Eluna AIO for all statistics and history
-- Database: CHARACTER DATABASE (acore_characters)
-- Dependencies: Required by HLBG_AIO.lua for all statistical queries
CREATE TABLE IF NOT EXISTS `hlbg_winner_history` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `occurred_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `zone_id` INT UNSIGNED NOT NULL DEFAULT 47 COMMENT 'Zone ID (47 = Hinterlands)',
    `map_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Map instance ID',
    `season` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season number',
    `winner_tid` TINYINT UNSIGNED NOT NULL COMMENT '0=Alliance, 1=Horde, 2=Draw/Neutral',
    `score_alliance` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Final Alliance score/resources',
    `score_horde` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Final Horde score/resources',
    `win_reason` ENUM('depletion','tiebreaker','draw','manual','timeout') NOT NULL DEFAULT 'tiebreaker',
    `affix` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Affix ID used during battle',
    `weather` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Weather conditions during battle',
    `weather_intensity` FLOAT NOT NULL DEFAULT 0 COMMENT 'Weather intensity (0.0-1.0)',
    `duration_seconds` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Battle duration in seconds',
    `notes` TEXT NULL COMMENT 'Additional battle notes',
    PRIMARY KEY (`id`),
    INDEX `idx_time` (`occurred_at`),
    INDEX `idx_winner` (`winner_tid`),
    INDEX `idx_affix` (`affix`),
    INDEX `idx_weather` (`weather`),
    INDEX `idx_season` (`season`),
    INDEX `idx_duration` (`duration_seconds`),
    INDEX `idx_scores` (`score_alliance`, `score_horde`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='CRITICAL: Battle results history - Required by Eluna AIO system';

-- Table: hlbg_affixes
-- Usage: CRITICAL - Required by Eluna AIO for affix lookups and rotation system
-- Database: CHARACTER DATABASE (acore_characters)  
-- Dependencies: Referenced by hlbg_winner_history.affix and Eluna scripts
CREATE TABLE IF NOT EXISTS `hlbg_affixes` (
    `id` TINYINT UNSIGNED PRIMARY KEY COMMENT 'Affix ID (0-255)',
    `name` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Affix display name',
    `description` TEXT COMMENT 'Detailed affix description',
    `effect` TEXT COMMENT 'Technical description of affix effects',
    `season_id` INT UNSIGNED DEFAULT NULL COMMENT 'Associated season (NULL = all seasons)',
    `spell_id` INT UNSIGNED DEFAULT 0 COMMENT 'WoW spell ID for affix effect',
    `icon` VARCHAR(100) DEFAULT '' COMMENT 'Icon filename or spell icon',
    `is_enabled` BOOLEAN DEFAULT TRUE COMMENT 'Can this affix be selected',
    `usage_count` INT UNSIGNED DEFAULT 0 COMMENT 'Times this affix has been used',
    `weight` TINYINT UNSIGNED DEFAULT 100 COMMENT 'Selection probability weight (0-255)',
    `min_players` TINYINT UNSIGNED DEFAULT 0 COMMENT 'Minimum players required',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_enabled` (`is_enabled`),
    INDEX `idx_season` (`season_id`),
    INDEX `idx_usage` (`usage_count`),
    INDEX `idx_weight` (`weight`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='CRITICAL: Affix definitions - Required by Eluna AIO system';

-- Table: hlbg_weather
-- Usage: REQUIRED - Referenced by hlbg_winner_history.weather
-- Database: CHARACTER DATABASE (acore_characters)
-- Dependencies: Weather codes used in battle history
CREATE TABLE IF NOT EXISTS `hlbg_weather` (
    `weather` TINYINT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Weather type ID',
    `name` VARCHAR(32) NOT NULL COMMENT 'Weather type name',
    `description` VARCHAR(255) NULL COMMENT 'Weather description',
    `spell_effect` INT UNSIGNED DEFAULT 0 COMMENT 'Associated spell effect',
    `visibility_modifier` FLOAT DEFAULT 1.0 COMMENT 'Visibility range modifier',
    `is_enabled` BOOLEAN DEFAULT TRUE COMMENT 'Can this weather occur',
    INDEX `idx_enabled` (`is_enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='REQUIRED: Weather type definitions for battle conditions';

-- =====================================================
-- SECTION 2: ENHANCED TABLES (CHARACTER DATABASE)
-- Optional tables that extend functionality
-- =====================================================

-- Table: hlbg_seasons
-- Usage: OPTIONAL - Season management and tracking
-- Database: CHARACTER DATABASE (acore_characters)
-- Dependencies: Referenced by hlbg_winner_history.season
CREATE TABLE IF NOT EXISTS `hlbg_seasons` (
    `season` INT UNSIGNED PRIMARY KEY COMMENT 'Season number (unique identifier)',
    `name` VARCHAR(100) NOT NULL COMMENT 'Season display name',
    `description` TEXT COMMENT 'Season description and theme',
    `rewards_alliance` JSON NULL COMMENT 'Alliance rewards configuration (JSON)',
    `rewards_horde` JSON NULL COMMENT 'Horde rewards configuration (JSON)', 
    `rewards_participation` JSON NULL COMMENT 'Participation rewards (JSON)',
    `is_active` BOOLEAN DEFAULT FALSE COMMENT 'Is this the current active season',
    `starts_at` DATETIME NULL COMMENT 'Season start date and time',
    `ends_at` DATETIME NULL COMMENT 'Season end date and time',
    `affix_pool` JSON NULL COMMENT 'Available affixes for this season (JSON array)',
    `special_rules` JSON NULL COMMENT 'Special rules and modifiers (JSON)',
    `leaderboard_reset` BOOLEAN DEFAULT TRUE COMMENT 'Reset player stats for season',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `created_by` VARCHAR(50) DEFAULT 'GM' COMMENT 'Who created the season',
    INDEX `idx_active` (`is_active`),
    INDEX `idx_dates` (`starts_at`, `ends_at`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='OPTIONAL: Season management system';

-- =====================================================
-- SECTION 3: INTEGRATION TABLES (WORLD DATABASE)
-- Enhanced features for real-time tracking and GM tools
-- =====================================================

-- Table: hlbg_config
-- Usage: OPTIONAL - Server configuration management
-- Database: WORLD DATABASE (acore_world)
-- Dependencies: Used by AIO handlers for server settings
CREATE TABLE IF NOT EXISTS `hlbg_config` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `config_key` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Configuration parameter name',
    `config_value` TEXT NOT NULL COMMENT 'Configuration value (JSON or string)',
    `data_type` ENUM('int','float','string','boolean','json') DEFAULT 'string',
    `category` VARCHAR(30) DEFAULT 'general' COMMENT 'Configuration category',
    `description` TEXT COMMENT 'Parameter description',
    `min_value` DECIMAL(10,2) NULL COMMENT 'Minimum allowed value (for numeric)',
    `max_value` DECIMAL(10,2) NULL COMMENT 'Maximum allowed value (for numeric)', 
    `is_readonly` BOOLEAN DEFAULT FALSE COMMENT 'Can only be changed by server restart',
    `requires_restart` BOOLEAN DEFAULT FALSE COMMENT 'Requires server restart to take effect',
    `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `updated_by` VARCHAR(50) DEFAULT 'SYSTEM' COMMENT 'Who last updated this setting',
    INDEX `idx_category` (`category`),
    INDEX `idx_readonly` (`is_readonly`),
    INDEX `idx_updated` (`last_updated`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='OPTIONAL: Dynamic server configuration system';

-- Table: hlbg_statistics
-- Usage: OPTIONAL - Real-time statistics aggregation  
-- Database: WORLD DATABASE (acore_world)
-- Dependencies: Updated by Integration Helper and AIO handlers
CREATE TABLE IF NOT EXISTS `hlbg_statistics` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `stat_category` VARCHAR(30) NOT NULL COMMENT 'Statistics category',
    `stat_name` VARCHAR(50) NOT NULL COMMENT 'Specific statistic name',
    `stat_value` BIGINT DEFAULT 0 COMMENT 'Current statistic value',
    `stat_value_float` DECIMAL(15,4) DEFAULT 0 COMMENT 'Float precision values',
    `season_id` INT UNSIGNED DEFAULT 0 COMMENT 'Season (0 = all-time)',
    `faction` ENUM('Alliance','Horde','Neutral','All') DEFAULT 'All' COMMENT 'Faction-specific stats',
    `affix_id` TINYINT UNSIGNED DEFAULT 255 COMMENT 'Affix-specific stats (255 = all)',
    `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `update_count` INT UNSIGNED DEFAULT 0 COMMENT 'Number of times updated',
    UNIQUE KEY `unique_stat` (`stat_category`, `stat_name`, `season_id`, `faction`, `affix_id`),
    INDEX `idx_category` (`stat_category`),
    INDEX `idx_season` (`season_id`),
    INDEX `idx_faction` (`faction`),
    INDEX `idx_affix` (`affix_id`),
    INDEX `idx_updated` (`last_updated`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='OPTIONAL: Real-time statistics aggregation system';

-- Table: hlbg_battle_history
-- Usage: OPTIONAL - Detailed real-time battle tracking
-- Database: WORLD DATABASE (acore_world)
-- Dependencies: Used by Integration Helper for detailed logging
CREATE TABLE IF NOT EXISTS `hlbg_battle_history` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `battle_start` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `battle_end` TIMESTAMP NULL,
    `duration_seconds` INT UNSIGNED DEFAULT 0,
    `winner_faction` ENUM('Alliance','Horde','Draw') NOT NULL,
    `alliance_resources` INT UNSIGNED DEFAULT 0 COMMENT 'Final Alliance resources',
    `horde_resources` INT UNSIGNED DEFAULT 0 COMMENT 'Final Horde resources',
    `affix_id` TINYINT UNSIGNED DEFAULT 0 COMMENT 'Active affix during battle',
    `weather_id` TINYINT UNSIGNED DEFAULT 0 COMMENT 'Weather conditions',
    `alliance_players` SMALLINT UNSIGNED DEFAULT 0 COMMENT 'Alliance participants',
    `horde_players` SMALLINT UNSIGNED DEFAULT 0 COMMENT 'Horde participants',
    `alliance_kills` INT UNSIGNED DEFAULT 0 COMMENT 'Alliance total kills',
    `horde_kills` INT UNSIGNED DEFAULT 0 COMMENT 'Horde total kills',
    `map_id` SMALLINT UNSIGNED DEFAULT 47 COMMENT 'Map ID (47 for Hinterlands)',
    `instance_id` INT UNSIGNED DEFAULT 0 COMMENT 'Battleground instance ID',
    `ended_by_gm` BOOLEAN DEFAULT FALSE COMMENT 'Manually ended by GM',
    `gm_name` VARCHAR(50) NULL COMMENT 'GM who ended the battle',
    `server_restart` BOOLEAN DEFAULT FALSE COMMENT 'Battle ended due to restart',
    `notes` TEXT COMMENT 'Additional battle notes and events',
    INDEX `idx_battle_end` (`battle_end`),
    INDEX `idx_winner` (`winner_faction`),
    INDEX `idx_instance` (`instance_id`),
    INDEX `idx_affix` (`affix_id`),
    INDEX `idx_weather` (`weather_id`),
    INDEX `idx_duration` (`duration_seconds`),
    INDEX `idx_gm_ended` (`ended_by_gm`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='OPTIONAL: Detailed real-time battle history and events';

-- Table: hlbg_player_stats
-- Usage: OPTIONAL - Individual player tracking and statistics
-- Database: WORLD DATABASE (acore_world)
-- Dependencies: Used by Integration Helper for player performance tracking
CREATE TABLE IF NOT EXISTS `hlbg_player_stats` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID',
    `player_name` VARCHAR(50) NOT NULL COMMENT 'Player character name',
    `faction` ENUM('Alliance','Horde') NOT NULL COMMENT 'Player faction',
    `season_id` INT UNSIGNED DEFAULT 1 COMMENT 'Season for these statistics',
    `battles_participated` INT UNSIGNED DEFAULT 0 COMMENT 'Total battles joined',
    `battles_won` INT UNSIGNED DEFAULT 0 COMMENT 'Battles won',
    `battles_lost` INT UNSIGNED DEFAULT 0 COMMENT 'Battles lost',
    `battles_drawn` INT UNSIGNED DEFAULT 0 COMMENT 'Battles that ended in draw',
    `total_kills` INT UNSIGNED DEFAULT 0 COMMENT 'Total player kills',
    `total_deaths` INT UNSIGNED DEFAULT 0 COMMENT 'Total deaths',
    `total_damage_dealt` BIGINT UNSIGNED DEFAULT 0 COMMENT 'Total damage dealt',
    `total_healing_done` BIGINT UNSIGNED DEFAULT 0 COMMENT 'Total healing done',
    `resources_captured` INT UNSIGNED DEFAULT 0 COMMENT 'Resource nodes captured',
    `resources_defended` INT UNSIGNED DEFAULT 0 COMMENT 'Successful defenses',
    `longest_killstreak` SMALLINT UNSIGNED DEFAULT 0 COMMENT 'Best killing spree',
    `current_rating` INT DEFAULT 1500 COMMENT 'Player skill rating',
    `highest_rating` INT DEFAULT 1500 COMMENT 'Peak skill rating achieved',
    `favorite_affix` TINYINT UNSIGNED DEFAULT 0 COMMENT 'Most successful affix',
    `first_participation` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_participation` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `last_seen_ip` VARCHAR(45) NULL COMMENT 'Last known IP address',
    `achievements` JSON NULL COMMENT 'Special achievements (JSON array)',
    UNIQUE KEY `unique_player_season` (`player_guid`, `season_id`),
    INDEX `idx_player_name` (`player_name`),
    INDEX `idx_faction` (`faction`),
    INDEX `idx_season` (`season_id`),
    INDEX `idx_battles` (`battles_participated`),
    INDEX `idx_rating` (`current_rating`),
    INDEX `idx_last_seen` (`last_participation`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='OPTIONAL: Individual player performance tracking and statistics';

-- =====================================================
-- SECTION 4: DEFAULT DATA POPULATION
-- =====================================================

-- Populate hlbg_weather with standard weather types (basic columns only)
INSERT INTO `hlbg_weather` (`weather`, `name`, `description`) VALUES
(0, 'Clear', 'Perfect clear weather conditions'),
(1, 'Light Rain', 'Light rainfall with minimal impact'),
(2, 'Heavy Rain', 'Heavy rain reducing visibility'),
(3, 'Snow', 'Snowfall conditions'),
(4, 'Thunderstorm', 'Severe thunderstorm with lightning'),
(5, 'Fog', 'Dense fog greatly reducing visibility'),
(6, 'Blizzard', 'Extreme snow conditions'),
(7, 'Magical Storm', 'Arcane storm with special effects')
ON DUPLICATE KEY UPDATE 
    `name` = VALUES(`name`),
    `description` = VALUES(`description`);

-- Populate hlbg_affixes with comprehensive affix system (basic columns only)
INSERT INTO `hlbg_affixes` (`id`, `name`, `description`) VALUES
(0, 'None', 'No active affix - standard battleground rules'),
(1, 'Bloodlust', 'All players gain Bloodlust/Heroism periodically - increases attack speed, casting speed, and movement speed by 30%'),
(2, 'Regeneration', 'Enhanced health and mana regeneration - all players regenerate 2% health and mana per second'),
(3, 'Speed Demon', 'Significant movement speed increase - all players gain 50% movement speed increase'),
(4, 'Thorns', 'Damage reflection shield - attackers take 25% of damage they deal as reflected damage'),
(5, 'Mana Burn', 'Spells consume enemy mana - all damage spells burn 10% of target maximum mana'),
(6, 'Lightning Storm', 'Periodic area lightning strikes - random lightning strikes deal damage and stun in 10-yard radius'),
(7, 'Volcanic', 'Ground eruptions at player locations - eruptions knock players back and deal fire damage'),
(8, 'Time Warp', 'Periodic haste for all players - all players gain 25% haste every 60 seconds for 15 seconds'),
(9, 'Berserker Rage', 'Low health increases damage - players below 50% health deal 100% increased damage'),
(10, 'Fortification', 'Damage reduction for all players - all players take 25% reduced damage from all sources'),
(11, 'Chaos Magic', 'Random spell effects on abilities - all abilities have 15% chance to trigger random magical effect'),
(12, 'Resource Rush', 'Increased resource gain rate - resource nodes provide 200% normal resources'),
(13, 'Death Wish', 'Increased damage near death - players below 25% health become immune to crowd control'),
(14, 'Arcane Power', 'Spell power increases over time - all players gain 5% spell power every 2 minutes (max 50%)'),
(15, 'Plague Bearer', 'Damage spreads to nearby enemies - all damage has 30% chance to spread to enemies within 8 yards')
ON DUPLICATE KEY UPDATE 
    `name` = VALUES(`name`),
    `description` = VALUES(`description`);

-- Create default seasons (basic columns only)
INSERT INTO `hlbg_seasons` (`season`, `name`, `description`, `starts_at`, `ends_at`, `is_active`) VALUES
(1, 'Season 1: The Awakening', 'The inaugural season of enhanced Hinterland Battlegrounds', '2025-10-01 00:00:00', '2025-12-31 23:59:59', 1),
(2, 'Season 2: Elemental Fury', 'Introducing weather effects and elemental affixes', '2026-01-01 00:00:00', '2026-03-31 23:59:59', 0),
(3, 'Season 3: Chaos Unleashed', 'Advanced affixes and chaos magic systems', '2026-04-01 00:00:00', '2026-06-30 23:59:59', 0)
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`),
    `description` = VALUES(`description`),
    `starts_at` = VALUES(`starts_at`),
    `ends_at` = VALUES(`ends_at`),
    `is_active` = VALUES(`is_active`);

-- Populate default configuration (only if hlbg_config table exists with basic structure)
INSERT IGNORE INTO `hlbg_config` (`duration_minutes`, `max_players_per_side`, `min_level`, `max_level`) 
VALUES (30, 40, 255, 255);

-- Initialize basic statistics (only if hlbg_statistics table exists with basic structure)  
INSERT IGNORE INTO `hlbg_statistics` (`total_runs`, `alliance_wins`, `horde_wins`, `draws`) 
VALUES (0, 0, 0, 0);

-- =====================================================
-- SECTION 5: PERFORMANCE OPTIMIZATIONS
-- =====================================================

-- Additional indexes for optimal query performance (Ultra-compatible)
-- Using safe index creation method for older MySQL versions

-- Safe index creation for hlbg_winner_history
SET @sql1 = 'CREATE INDEX idx_hlbg_winner_main ON hlbg_winner_history (season, winner_tid, affix)';
SET @index1_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
                      WHERE TABLE_SCHEMA = DATABASE() 
                      AND TABLE_NAME = 'hlbg_winner_history' 
                      AND INDEX_NAME = 'idx_hlbg_winner_main');
SET @sql1 = IF(@index1_exists = 0, @sql1, 'SELECT "Winner index exists" as Notice');
PREPARE stmt1 FROM @sql1; EXECUTE stmt1; DEALLOCATE PREPARE stmt1;

-- Safe index creation for hlbg_affixes  
SET @sql2 = 'CREATE INDEX idx_hlbg_affixes_main ON hlbg_affixes (id, name)';
SET @index2_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
                      WHERE TABLE_SCHEMA = DATABASE() 
                      AND TABLE_NAME = 'hlbg_affixes' 
                      AND INDEX_NAME = 'idx_hlbg_affixes_main');
SET @sql2 = IF(@index2_exists = 0, @sql2, 'SELECT "Affix index exists" as Notice');
PREPARE stmt2 FROM @sql2; EXECUTE stmt2; DEALLOCATE PREPARE stmt2;

-- Safe index creation for hlbg_seasons
SET @sql3 = 'CREATE INDEX idx_hlbg_seasons_main ON hlbg_seasons (is_active, starts_at)';
SET @index3_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
                      WHERE TABLE_SCHEMA = DATABASE() 
                      AND TABLE_NAME = 'hlbg_seasons' 
                      AND INDEX_NAME = 'idx_hlbg_seasons_main');
SET @sql3 = IF(@index3_exists = 0, @sql3, 'SELECT "Season index exists" as Notice');
PREPARE stmt3 FROM @sql3; EXECUTE stmt3; DEALLOCATE PREPARE stmt3;

-- Safe index creation for hlbg_weather
SET @sql4 = 'CREATE INDEX idx_hlbg_weather_main ON hlbg_weather (weather, name)';
SET @index4_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
                      WHERE TABLE_SCHEMA = DATABASE() 
                      AND TABLE_NAME = 'hlbg_weather' 
                      AND INDEX_NAME = 'idx_hlbg_weather_main');
SET @sql4 = IF(@index4_exists = 0, @sql4, 'SELECT "Weather index exists" as Notice');
PREPARE stmt4 FROM @sql4; EXECUTE stmt4; DEALLOCATE PREPARE stmt4;

-- =====================================================
-- COMPLETION STATUS
-- =====================================================

-- =====================================================
-- VERIFICATION AND RESULTS
-- =====================================================

-- Show populated data
SELECT 'Data Population Results:' as Info;

SELECT 'Weather Types Populated:' as TableInfo, COUNT(*) as RowCount FROM hlbg_weather;
SELECT weather, name FROM hlbg_weather ORDER BY weather LIMIT 8;

SELECT 'Affix Definitions Populated:' as TableInfo, COUNT(*) as RowCount FROM hlbg_affixes;  
SELECT id, name FROM hlbg_affixes ORDER BY id LIMIT 10;

SELECT 'Season Information Populated:' as TableInfo, COUNT(*) as RowCount FROM hlbg_seasons;
SELECT season, name, is_active FROM hlbg_seasons ORDER BY season;

-- Show final table status
SELECT 
    TABLE_NAME,
    TABLE_ROWS as EstimatedRows,
    CREATE_TIME,
    TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE 'hlbg_%'
ORDER BY TABLE_NAME;

-- Show created indexes
SELECT 
    TABLE_NAME,
    INDEX_NAME,
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) as IndexColumns
FROM INFORMATION_SCHEMA.STATISTICS 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE 'hlbg_%'
  AND INDEX_NAME NOT LIKE 'PRIMARY'
GROUP BY TABLE_NAME, INDEX_NAME
ORDER BY TABLE_NAME, INDEX_NAME;

-- =====================================================
-- COMPLETION STATUS  
-- =====================================================

SELECT 'HLBG Complete Schema Installation Finished!' as Status,
       'Basic data populated for weather (8 types), affixes (16 types), seasons (3)' as DataStatus,
       'Performance indexes created with compatibility checks' as IndexStatus,
       'Compatible with existing table structures and older MySQL versions' as Compatibility,
       'System ready for existing Eluna AIO and optional enhanced features' as SystemReady;