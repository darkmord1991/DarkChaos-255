-- =====================================================================
-- DarkChaos-255 Challenge Mode System - Character Database Tables
-- =====================================================================
-- Tracks challenge mode settings and complete activity history per character
-- =====================================================================

-- =====================================================================
-- TABLE 1: Active Challenge Mode Settings
-- =====================================================================
-- Stores current active challenge modes for each character
-- One row per character with bitwise flags for active modes
-- =====================================================================

DROP TABLE IF EXISTS `dc_character_challenge_modes`;
CREATE TABLE `dc_character_challenge_modes` (
    `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `active_modes` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Bitwise flags for active challenge modes (1=Hardcore, 2=Semi-Hardcore, 4=Self-Crafted, 8=Iron Man, 16=Solo, 32=Dungeon Only, 64=PvP Only, 128=Quest Only)',
    `activated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When challenge modes were last activated',
    `total_activations` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total number of times challenge modes have been activated',
    `total_deactivations` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total number of times challenge modes have been deactivated',
    `hardcore_deaths` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Number of hardcore deaths (if applicable)',
    `last_hardcore_death` TIMESTAMP NULL DEFAULT NULL COMMENT 'Timestamp of last hardcore death',
    `character_locked` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 if character is locked due to hardcore death, 0 otherwise',
    `locked_at` TIMESTAMP NULL DEFAULT NULL COMMENT 'When character was locked',
    `notes` VARCHAR(255) DEFAULT NULL COMMENT 'Optional notes or comments',
    PRIMARY KEY (`guid`),
    KEY `idx_active_modes` (`active_modes`),
    KEY `idx_locked` (`character_locked`),
    KEY `idx_hardcore_deaths` (`hardcore_deaths`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Current challenge mode settings per character';

-- =====================================================================
-- TABLE 2: Challenge Mode Activity Log
-- =====================================================================
-- Complete history of all challenge mode changes and events
-- Maintains audit trail of activations, deactivations, deaths, etc.
-- =====================================================================

DROP TABLE IF EXISTS `dc_character_challenge_mode_log`;
CREATE TABLE `dc_character_challenge_mode_log` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique log entry ID',
    `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `event_type` ENUM('ACTIVATE', 'DEACTIVATE', 'DEATH', 'LOCK', 'UNLOCK', 'MODIFY') NOT NULL COMMENT 'Type of event',
    `modes_before` INT UNSIGNED DEFAULT NULL COMMENT 'Active modes before this event (bitwise flags)',
    `modes_after` INT UNSIGNED DEFAULT NULL COMMENT 'Active modes after this event (bitwise flags)',
    `event_details` TEXT DEFAULT NULL COMMENT 'Detailed description of the event',
    `character_level` TINYINT UNSIGNED DEFAULT NULL COMMENT 'Character level at time of event',
    `map_id` SMALLINT UNSIGNED DEFAULT NULL COMMENT 'Map ID where event occurred',
    `zone_id` SMALLINT UNSIGNED DEFAULT NULL COMMENT 'Zone ID where event occurred',
    `position_x` FLOAT DEFAULT NULL COMMENT 'X coordinate',
    `position_y` FLOAT DEFAULT NULL COMMENT 'Y coordinate',
    `position_z` FLOAT DEFAULT NULL COMMENT 'Z coordinate',
    `killer_entry` INT UNSIGNED DEFAULT NULL COMMENT 'Creature entry that killed player (for DEATH events)',
    `killer_name` VARCHAR(100) DEFAULT NULL COMMENT 'Name of killer (for DEATH events)',
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When this event occurred',
    PRIMARY KEY (`id`),
    KEY `idx_guid` (`guid`),
    KEY `idx_event_type` (`event_type`),
    KEY `idx_timestamp` (`timestamp`),
    KEY `idx_guid_event` (`guid`, `event_type`),
    KEY `idx_deaths` (`guid`, `event_type`, `timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Complete history of challenge mode events per character';

-- =====================================================================
-- TABLE 3: Challenge Mode Statistics
-- =====================================================================
-- Aggregated statistics for challenge mode achievements and milestones
-- Used for leaderboards, achievements, and player comparisons
-- =====================================================================

DROP TABLE IF EXISTS `dc_character_challenge_mode_stats`;
CREATE TABLE `dc_character_challenge_mode_stats` (
    `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `mode_id` TINYINT UNSIGNED NOT NULL COMMENT 'Challenge mode ID (1-8)',
    `mode_name` VARCHAR(50) NOT NULL COMMENT 'Challenge mode name for reference',
    `times_activated` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Times this specific mode was activated',
    `total_playtime_seconds` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total playtime with this mode active',
    `max_level_reached` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Maximum level reached with this mode',
    `total_deaths` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total deaths while mode was active',
    `total_kills` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total creature kills with mode active',
    `dungeons_completed` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Dungeons completed with mode active',
    `quests_completed` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Quests completed with mode active',
    `pvp_kills` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'PvP kills with mode active',
    `first_activated` TIMESTAMP NULL DEFAULT NULL COMMENT 'First time this mode was activated',
    `last_activated` TIMESTAMP NULL DEFAULT NULL COMMENT 'Most recent activation',
    `last_deactivated` TIMESTAMP NULL DEFAULT NULL COMMENT 'Most recent deactivation',
    `achievements_earned` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Achievements earned while mode was active',
    `currently_active` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 if currently active, 0 otherwise',
    PRIMARY KEY (`guid`, `mode_id`),
    KEY `idx_mode_active` (`mode_id`, `currently_active`),
    KEY `idx_max_level` (`mode_id`, `max_level_reached`),
    KEY `idx_playtime` (`mode_id`, `total_playtime_seconds`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Challenge mode statistics per character per mode';

-- =====================================================================
-- Pre-populate mode names for reference
-- =====================================================================

INSERT INTO `dc_character_challenge_mode_stats` (`guid`, `mode_id`, `mode_name`, `currently_active`) VALUES
(0, 1, 'Hardcore', 0),
(0, 2, 'Semi-Hardcore', 0),
(0, 3, 'Self-Crafted', 0),
(0, 4, 'Iron Man', 0),
(0, 5, 'Solo', 0),
(0, 6, 'Dungeon Only', 0),
(0, 7, 'PvP Only', 0),
(0, 8, 'Quest Only', 0)
ON DUPLICATE KEY UPDATE `mode_name` = VALUES(`mode_name`);

-- =====================================================================
-- Stored Procedure: Log Challenge Mode Event
-- =====================================================================
-- Helper procedure to simplify logging challenge mode events
-- =====================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS `sp_LogChallengeModeEvent` //
CREATE PROCEDURE `sp_LogChallengeModeEvent`(
    IN p_guid INT UNSIGNED,
    IN p_event_type VARCHAR(20),
    IN p_modes_before INT UNSIGNED,
    IN p_modes_after INT UNSIGNED,
    IN p_event_details TEXT,
    IN p_character_level TINYINT UNSIGNED,
    IN p_map_id SMALLINT UNSIGNED,
    IN p_zone_id SMALLINT UNSIGNED,
    IN p_position_x FLOAT,
    IN p_position_y FLOAT,
    IN p_position_z FLOAT,
    IN p_killer_entry INT UNSIGNED,
    IN p_killer_name VARCHAR(100)
)
BEGIN
    INSERT INTO `dc_character_challenge_mode_log` (
        `guid`,
        `event_type`,
        `modes_before`,
        `modes_after`,
        `event_details`,
        `character_level`,
        `map_id`,
        `zone_id`,
        `position_x`,
        `position_y`,
        `position_z`,
        `killer_entry`,
        `killer_name`
    ) VALUES (
        p_guid,
        p_event_type,
        p_modes_before,
        p_modes_after,
        p_event_details,
        p_character_level,
        p_map_id,
        p_zone_id,
        p_position_x,
        p_position_y,
        p_position_z,
        p_killer_entry,
        p_killer_name
    );
END //

DELIMITER ;

-- =====================================================================
-- Example Queries for Reporting
-- =====================================================================

-- Query 1: Get all active challenge mode players
-- SELECT 
--     c.guid,
--     chars.name,
--     c.active_modes,
--     c.activated_at,
--     c.hardcore_deaths,
--     c.character_locked
-- FROM dc_character_challenge_modes c
-- INNER JOIN characters chars ON c.guid = chars.guid
-- WHERE c.active_modes > 0
-- ORDER BY c.activated_at DESC;

-- Query 2: Get challenge mode event history for a specific character
-- SELECT 
--     event_type,
--     modes_before,
--     modes_after,
--     event_details,
--     character_level,
--     timestamp
-- FROM dc_character_challenge_mode_log
-- WHERE guid = ?
-- ORDER BY timestamp DESC
-- LIMIT 50;

-- Query 3: Get hardcore death leaderboard
-- SELECT 
--     c.guid,
--     chars.name,
--     c.hardcore_deaths,
--     c.last_hardcore_death
-- FROM dc_character_challenge_modes c
-- INNER JOIN characters chars ON c.guid = chars.guid
-- WHERE c.hardcore_deaths > 0
-- ORDER BY c.hardcore_deaths DESC
-- LIMIT 100;

-- Query 4: Get challenge mode statistics for a character
-- SELECT 
--     mode_name,
--     times_activated,
--     total_playtime_seconds / 3600 AS hours_played,
--     max_level_reached,
--     total_deaths,
--     total_kills,
--     currently_active
-- FROM dc_character_challenge_mode_stats
-- WHERE guid = ?
-- ORDER BY mode_id;

-- Query 5: Get most popular challenge modes
-- SELECT 
--     mode_id,
--     mode_name,
--     COUNT(DISTINCT guid) AS unique_players,
--     SUM(times_activated) AS total_activations,
--     SUM(total_playtime_seconds) / 3600 AS total_hours,
--     AVG(max_level_reached) AS avg_max_level
-- FROM dc_character_challenge_mode_stats
-- WHERE guid > 0
-- GROUP BY mode_id, mode_name
-- ORDER BY unique_players DESC;

-- =====================================================================
-- Bitwise Flag Reference for active_modes column
-- =====================================================================
-- 1   (0x01) = Hardcore
-- 2   (0x02) = Semi-Hardcore
-- 4   (0x04) = Self-Crafted
-- 8   (0x08) = Iron Man
-- 16  (0x10) = Solo
-- 32  (0x20) = Dungeon Only
-- 64  (0x40) = PvP Only
-- 128 (0x80) = Quest Only
--
-- Example: active_modes = 5 means Hardcore (1) + Self-Crafted (4) are active
-- Check if specific mode is active: (active_modes & mode_flag) > 0
-- =====================================================================

-- =====================================================================
-- End of Challenge Mode Tracking Tables
-- =====================================================================
