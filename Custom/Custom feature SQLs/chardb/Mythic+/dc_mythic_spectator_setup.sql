-- =====================================================================
-- DarkChaos Mythic+ Spectator System - Database Setup
-- =====================================================================
-- This script creates the tables required for the M+ Spectator system.
-- Run this on the `acore_characters` database.
-- =====================================================================

-- Spectator Session Log Table
-- Tracks who watched which runs and for how long
DROP TABLE IF EXISTS `dc_mythic_spectator_sessions`;
CREATE TABLE `dc_mythic_spectator_sessions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `spectator_guid` INT UNSIGNED NOT NULL,
    `instance_id` INT UNSIGNED NOT NULL,
    `map_id` INT UNSIGNED NOT NULL,
    `keystone_level` TINYINT UNSIGNED NOT NULL,
    `join_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `leave_time` TIMESTAMP NULL,
    `duration_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    `stream_mode` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=Normal, 1=Names Hidden, 2=Full Anonymous',
    PRIMARY KEY (`id`),
    INDEX `idx_spectator` (`spectator_guid`, `join_time` DESC),
    INDEX `idx_instance` (`instance_id`),
    INDEX `idx_time` (`join_time` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos M+ Spectator - Session Log';

-- Run Visibility Settings
-- Allows run leaders to control spectator access
DROP TABLE IF EXISTS `dc_mythic_spectator_settings`;
CREATE TABLE `dc_mythic_spectator_settings` (
    `player_guid` INT UNSIGNED NOT NULL,
    `allow_spectators` TINYINT(1) NOT NULL DEFAULT 1,
    `allow_public_listing` TINYINT(1) NOT NULL DEFAULT 1,
    `default_stream_mode` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `blocked_spectators` TEXT COMMENT 'Comma-separated list of blocked player GUIDs',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos M+ Spectator - Player Settings';

-- Popular Runs Statistics (for leaderboard/analytics)
DROP TABLE IF EXISTS `dc_mythic_spectator_popularity`;
CREATE TABLE `dc_mythic_spectator_popularity` (
    `map_id` INT UNSIGNED NOT NULL,
    `keystone_level` TINYINT UNSIGNED NOT NULL,
    `total_spectators` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_watch_time` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'In seconds',
    `last_spectated` TIMESTAMP NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`map_id`, `keystone_level`),
    INDEX `idx_popularity` (`total_spectators` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos M+ Spectator - Popularity Stats';

-- =====================================================================
-- Sample Queries
-- =====================================================================

-- Get most spectated dungeon/level combinations:
-- SELECT 
--     p.map_id,
--     m.name as dungeon_name,
--     p.keystone_level,
--     p.total_spectators,
--     CONCAT(FLOOR(p.total_watch_time/3600), 'h ', FLOOR((p.total_watch_time%3600)/60), 'm') as total_watch_time
-- FROM dc_mythic_spectator_popularity p
-- LEFT JOIN dc_mythic_dungeons m ON m.map_id = p.map_id
-- ORDER BY p.total_spectators DESC
-- LIMIT 10;

-- Get player's spectating history:
-- SELECT 
--     s.keystone_level,
--     s.join_time,
--     s.duration_seconds,
--     CASE s.stream_mode WHEN 0 THEN 'Normal' WHEN 1 THEN 'Names Hidden' ELSE 'Anonymous' END as mode
-- FROM dc_mythic_spectator_sessions s
-- WHERE s.spectator_guid = ?
-- ORDER BY s.join_time DESC
-- LIMIT 20;

-- Get currently active runs with spectator counts:
-- This would be done in-memory, but here's a historical query:
-- SELECT 
--     s.instance_id,
--     s.map_id,
--     s.keystone_level,
--     COUNT(*) as current_spectators
-- FROM dc_mythic_spectator_sessions s
-- WHERE s.leave_time IS NULL
-- GROUP BY s.instance_id, s.map_id, s.keystone_level;
