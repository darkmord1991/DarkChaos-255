-- ============================================================================
-- DarkChaos Cross-System Integration Framework
-- Database Schema for acore_chars
-- ============================================================================
-- Purpose: Persistent storage for cross-system events, statistics, and config
-- Author: DarkChaos Development Team
-- Date: December 2025
-- ============================================================================
--
-- IMPORTANT: These tables are NEW ADDITIONS, not replacements!
-- 
-- The cross-system framework AGGREGATES data from existing system tables:
--   - dc_character_dungeon_statistics (dungeon stats)
--   - dc_player_seasonal_stats (seasonal stats)
--   - dc_mplus_scores (M+ ratings)
--   - dc_character_prestige (prestige levels)
--   - dc_player_upgrade_tokens (currencies)
--
-- DO NOT DROP existing tables - they remain the source of truth.
-- The cross-system tables provide a unified view across all systems.
-- ============================================================================

-- ============================================================================
-- Cross-System Event Log
-- ============================================================================
-- Logs all significant cross-system events for debugging and analytics
CREATE TABLE IF NOT EXISTS `dc_cross_system_events` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `event_type` TINYINT UNSIGNED NOT NULL COMMENT '0=DUNGEON_START, 1=DUNGEON_END, 2=BOSS_KILL, etc.',
    `source_system` VARCHAR(32) NOT NULL COMMENT 'System that generated the event',
    `player_guid` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Player GUID if applicable',
    `event_data` JSON NULL COMMENT 'Event-specific JSON data',
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_event_type` (`event_type`),
    KEY `idx_source_system` (`source_system`),
    KEY `idx_player_guid` (`player_guid`),
    KEY `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Cross-system event log for debugging and analytics';

-- ============================================================================
-- Player Cross-System Statistics
-- ============================================================================
-- Aggregated cross-system statistics per player
CREATE TABLE IF NOT EXISTS `dc_player_cross_system_stats` (
    `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    
    -- Session Statistics
    `total_dungeons_started` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_dungeons_completed` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_boss_kills` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_deaths` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_quests_completed` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_creatures_killed` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    
    -- Reward Statistics
    `total_gold_earned` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'In copper',
    `total_tokens_earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `total_essence_earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `total_xp_earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `total_honor_earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `total_arena_points_earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `total_rating_earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    
    -- Time Statistics
    `total_dungeon_time_seconds` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `fastest_dungeon_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    `average_dungeon_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    
    -- Best Performances
    `highest_mythic_level_cleared` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `highest_prestige_level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `best_seasonal_rank` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    
    -- Tracking Metadata
    `first_cross_system_event` TIMESTAMP NULL COMMENT 'When player first triggered cross-system',
    `last_cross_system_event` TIMESTAMP NULL COMMENT 'Last cross-system activity',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    PRIMARY KEY (`guid`),
    KEY `idx_dungeons_completed` (`total_dungeons_completed`),
    KEY `idx_boss_kills` (`total_boss_kills`),
    KEY `idx_mythic_level` (`highest_mythic_level_cleared`),
    KEY `idx_prestige` (`highest_prestige_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Aggregated cross-system statistics per player';

-- ============================================================================
-- Cross-System Configuration
-- ============================================================================
-- Configuration values for the cross-system framework
CREATE TABLE IF NOT EXISTS `dc_cross_system_config` (
    `key` VARCHAR(64) NOT NULL,
    `value` TEXT NOT NULL,
    `description` VARCHAR(255) NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Cross-system configuration values';

-- Insert default configuration
INSERT INTO `dc_cross_system_config` (`key`, `value`, `description`) VALUES
    ('enabled', '1', 'Master switch for cross-system framework'),
    ('event_logging_enabled', '1', 'Whether to log events to dc_cross_system_events'),
    ('event_log_retention_days', '30', 'Days to keep event logs before cleanup'),
    ('reward_multiplier_enabled', '1', 'Whether cross-system reward multipliers are active'),
    ('prestige_bonus_cap', '0.5', 'Maximum prestige bonus multiplier (50%)'),
    ('difficulty_bonus_cap', '1.0', 'Maximum difficulty bonus multiplier (100%)'),
    ('seasonal_bonus_cap', '0.25', 'Maximum seasonal bonus multiplier (25%)'),
    ('version', '1.0.0', 'Schema version for migration tracking')
ON DUPLICATE KEY UPDATE `key`=`key`;

-- ============================================================================
-- Cross-System Multiplier Overrides
-- ============================================================================
-- Allows per-player or per-system multiplier overrides
CREATE TABLE IF NOT EXISTS `dc_cross_system_multipliers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `target_type` ENUM('global', 'player', 'account', 'guild') NOT NULL DEFAULT 'global',
    `target_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Player/Account/Guild GUID or 0 for global',
    `source_system` VARCHAR(32) NULL COMMENT 'Specific system or NULL for all systems',
    `reward_type` TINYINT UNSIGNED NULL COMMENT 'Specific reward type or NULL for all',
    `multiplier` DECIMAL(5,3) NOT NULL DEFAULT 1.000,
    `reason` VARCHAR(255) NULL COMMENT 'Why this override exists',
    `expires_at` TIMESTAMP NULL COMMENT 'When this override expires, NULL = permanent',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_target` (`target_type`, `target_id`),
    KEY `idx_expires` (`expires_at`),
    KEY `idx_system` (`source_system`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Per-player or per-system multiplier overrides';

-- ============================================================================
-- Cross-System Achievement Triggers
-- ============================================================================
-- Defines cross-system achievement conditions
CREATE TABLE IF NOT EXISTS `dc_cross_system_achievement_triggers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `achievement_id` INT UNSIGNED NOT NULL COMMENT 'Custom achievement ID to grant',
    `trigger_type` ENUM('total_stat', 'single_run', 'threshold', 'combination') NOT NULL,
    `stat_key` VARCHAR(64) NOT NULL COMMENT 'Stat key from dc_player_cross_system_stats',
    `threshold_value` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `additional_conditions` JSON NULL COMMENT 'Additional conditions in JSON',
    `title_reward_id` INT UNSIGNED NULL COMMENT 'Title to grant, if any',
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `description` VARCHAR(255) NULL,
    PRIMARY KEY (`id`),
    KEY `idx_achievement` (`achievement_id`),
    KEY `idx_enabled` (`enabled`),
    KEY `idx_stat_key` (`stat_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Cross-system achievement trigger definitions';

-- Insert some example achievement triggers
INSERT INTO `dc_cross_system_achievement_triggers` 
    (`achievement_id`, `trigger_type`, `stat_key`, `threshold_value`, `description`) VALUES
    (800100, 'total_stat', 'total_dungeons_completed', 100, 'Complete 100 dungeons'),
    (800101, 'total_stat', 'total_boss_kills', 500, 'Kill 500 dungeon bosses'),
    (800102, 'total_stat', 'total_boss_kills', 1000, 'Kill 1000 dungeon bosses'),
    (800103, 'total_stat', 'highest_mythic_level_cleared', 10, 'Clear a Mythic+10 or higher'),
    (800104, 'total_stat', 'highest_mythic_level_cleared', 15, 'Clear a Mythic+15 or higher'),
    (800105, 'total_stat', 'highest_mythic_level_cleared', 20, 'Clear a Mythic+20 or higher')
ON DUPLICATE KEY UPDATE `id`=`id`;

-- ============================================================================
-- Cleanup: Scheduled Event for Old Event Logs
-- ============================================================================
-- Note: This requires event_scheduler=ON in MySQL config
DELIMITER //
DROP EVENT IF EXISTS `dc_cross_system_cleanup`//
CREATE EVENT IF NOT EXISTS `dc_cross_system_cleanup`
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DECLARE retention_days INT DEFAULT 30;
    
    -- Get retention period from config
    SELECT CAST(`value` AS UNSIGNED) INTO retention_days
    FROM `dc_cross_system_config`
    WHERE `key` = 'event_log_retention_days';
    
    -- Delete old event logs
    DELETE FROM `dc_cross_system_events`
    WHERE `timestamp` < DATE_SUB(NOW(), INTERVAL retention_days DAY);
    
    -- Delete expired multiplier overrides
    DELETE FROM `dc_cross_system_multipliers`
    WHERE `expires_at` IS NOT NULL AND `expires_at` < NOW();
END//
DELIMITER ;

-- ============================================================================
-- Views for Common Queries
-- ============================================================================

-- View: Player leaderboard by total dungeon completions
CREATE OR REPLACE VIEW `v_dc_dungeon_leaderboard` AS
SELECT 
    s.`guid`,
    c.`name` AS `character_name`,
    s.`total_dungeons_completed`,
    s.`total_boss_kills`,
    s.`highest_mythic_level_cleared`,
    s.`total_dungeon_time_seconds`,
    ROUND(s.`average_dungeon_seconds` / 60, 1) AS `avg_dungeon_minutes`
FROM `dc_player_cross_system_stats` s
JOIN `characters` c ON c.`guid` = s.`guid`
ORDER BY s.`total_dungeons_completed` DESC
LIMIT 100;

-- View: Recent cross-system events (last 24 hours)
CREATE OR REPLACE VIEW `v_dc_recent_events` AS
SELECT 
    e.`id`,
    e.`event_type`,
    e.`source_system`,
    c.`name` AS `character_name`,
    e.`event_data`,
    e.`timestamp`
FROM `dc_cross_system_events` e
LEFT JOIN `characters` c ON c.`guid` = e.`player_guid`
WHERE e.`timestamp` > DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY e.`timestamp` DESC
LIMIT 500;

-- ============================================================================
-- End of Schema
-- ============================================================================
