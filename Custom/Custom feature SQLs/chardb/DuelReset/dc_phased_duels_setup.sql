-- =====================================================================
-- DarkChaos Phased Dueling System - Database Setup
-- =====================================================================
-- This script creates the tables required for the Phased Dueling system.
-- Run this on the `acore_characters` database.
-- =====================================================================

-- Duel Statistics Table
-- Stores win/loss records and statistics for each player
DROP TABLE IF EXISTS `dc_duel_statistics`;
CREATE TABLE `dc_duel_statistics` (
    `player_guid` INT UNSIGNED NOT NULL,
    `wins` INT UNSIGNED NOT NULL DEFAULT 0,
    `losses` INT UNSIGNED NOT NULL DEFAULT 0,
    `draws` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_damage_dealt` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `total_damage_taken` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `longest_duel_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    `shortest_win_seconds` INT UNSIGNED NOT NULL DEFAULT 4294967295,
    `last_duel_time` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `last_opponent_guid` INT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`player_guid`),
    INDEX `idx_wins` (`wins` DESC),
    INDEX `idx_last_duel` (`last_duel_time` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos Phased Dueling - Player Statistics';

-- Duel History Table (Optional - for detailed match history)
DROP TABLE IF EXISTS `dc_duel_history`;
CREATE TABLE `dc_duel_history` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `winner_guid` INT UNSIGNED NOT NULL,
    `loser_guid` INT UNSIGNED NOT NULL,
    `winner_class` TINYINT UNSIGNED NOT NULL,
    `loser_class` TINYINT UNSIGNED NOT NULL,
    `winner_spec` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `loser_spec` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `duration_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    `winner_damage_dealt` INT UNSIGNED NOT NULL DEFAULT 0,
    `loser_damage_dealt` INT UNSIGNED NOT NULL DEFAULT 0,
    `duel_type` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=Normal, 1=Tournament, 2=Rated',
    `zone_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `area_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `duel_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_winner` (`winner_guid`, `duel_time` DESC),
    INDEX `idx_loser` (`loser_guid`, `duel_time` DESC),
    INDEX `idx_time` (`duel_time` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos Phased Dueling - Match History';

-- Class Matchup Statistics (Optional - for balance analysis)
DROP TABLE IF EXISTS `dc_duel_class_matchups`;
CREATE TABLE `dc_duel_class_matchups` (
    `winner_class` TINYINT UNSIGNED NOT NULL,
    `loser_class` TINYINT UNSIGNED NOT NULL,
    `total_matches` INT UNSIGNED NOT NULL DEFAULT 0,
    `avg_duration_seconds` FLOAT NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`winner_class`, `loser_class`),
    INDEX `idx_matchups` (`winner_class`, `loser_class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos Phased Dueling - Class Matchup Stats';

-- =====================================================================
-- Sample Queries
-- =====================================================================

-- Get top 10 duelists by wins:
-- SELECT c.name, d.wins, d.losses, d.draws,
--        ROUND(d.wins * 100.0 / NULLIF(d.wins + d.losses + d.draws, 0), 1) as win_rate
-- FROM dc_duel_statistics d
-- INNER JOIN characters c ON c.guid = d.player_guid
-- ORDER BY d.wins DESC
-- LIMIT 10;

-- Get player's recent duel history:
-- SELECT 
--     CASE WHEN h.winner_guid = ? THEN 'WON' ELSE 'LOST' END as result,
--     CASE WHEN h.winner_guid = ? THEN (SELECT name FROM characters WHERE guid = h.loser_guid)
--          ELSE (SELECT name FROM characters WHERE guid = h.winner_guid) END as opponent,
--     h.duration_seconds,
--     h.duel_time
-- FROM dc_duel_history h
-- WHERE h.winner_guid = ? OR h.loser_guid = ?
-- ORDER BY h.duel_time DESC
-- LIMIT 10;

-- Get class matchup win rates:
-- SELECT 
--     m.winner_class,
--     m.loser_class,
--     m.total_matches,
--     ROUND(m.avg_duration_seconds, 1) as avg_duration
-- FROM dc_duel_class_matchups m
-- ORDER BY m.total_matches DESC;
