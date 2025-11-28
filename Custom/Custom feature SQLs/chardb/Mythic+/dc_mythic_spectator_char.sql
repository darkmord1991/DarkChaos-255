-- =====================================================================
-- DarkChaos Mythic+ Spectator System - CHARACTER Database Setup
-- =====================================================================
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

-- Replay Storage Table
-- Stores recorded M+ run replays
DROP TABLE IF EXISTS `dc_mythic_spectator_replays`;
CREATE TABLE `dc_mythic_spectator_replays` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `map_id` INT UNSIGNED NOT NULL,
    `keystone_level` TINYINT UNSIGNED NOT NULL,
    `leader_name` VARCHAR(12) NOT NULL,
    `start_time` BIGINT UNSIGNED NOT NULL,
    `end_time` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `completed` TINYINT(1) NOT NULL DEFAULT 0,
    `replay_data` LONGTEXT NOT NULL COMMENT 'JSON serialized replay events',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_map_level` (`map_id`, `keystone_level`),
    INDEX `idx_start_time` (`start_time` DESC),
    INDEX `idx_completed` (`completed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos M+ Spectator - Replay Storage';

-- Invite Links Table
-- Tracks active spectator invite codes
DROP TABLE IF EXISTS `dc_mythic_spectator_invites`;
CREATE TABLE `dc_mythic_spectator_invites` (
    `code` VARCHAR(8) NOT NULL,
    `instance_id` INT UNSIGNED NOT NULL,
    `created_by` INT UNSIGNED NOT NULL,
    `created_at` BIGINT UNSIGNED NOT NULL,
    `expires_at` BIGINT UNSIGNED NOT NULL,
    `max_uses` INT UNSIGNED NOT NULL DEFAULT 10,
    `use_count` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`code`),
    INDEX `idx_instance` (`instance_id`),
    INDEX `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos M+ Spectator - Invite Links';

-- =====================================================================
-- Sample Queries
-- =====================================================================

-- Get most spectated dungeon/level combinations:
-- SELECT 
--     p.map_id,
--     p.keystone_level,
--     p.total_spectators,
--     CONCAT(FLOOR(p.total_watch_time/3600), 'h ', FLOOR((p.total_watch_time%3600)/60), 'm') as total_watch_time
-- FROM dc_mythic_spectator_popularity p
-- ORDER BY p.total_spectators DESC
-- LIMIT 10;

-- Get recent replays:
-- SELECT id, map_id, keystone_level, leader_name, 
--        FROM_UNIXTIME(start_time) as start_time,
--        CASE WHEN completed THEN 'Completed' ELSE 'Failed' END as status
-- FROM dc_mythic_spectator_replays
-- ORDER BY start_time DESC
-- LIMIT 10;

-- Cleanup expired invites:
-- DELETE FROM dc_mythic_spectator_invites 
-- WHERE expires_at < UNIX_TIMESTAMP();
