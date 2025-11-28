-- =====================================================================
-- DarkChaos AoE Loot Extensions - Database Setup
-- =====================================================================
-- This script creates the tables required for AoE Loot Extensions.
-- Run this on the `acore_characters` database.
-- =====================================================================

-- Player Loot Preferences Table
DROP TABLE IF EXISTS `dc_aoeloot_preferences`;
CREATE TABLE `dc_aoeloot_preferences` (
    `player_guid` INT UNSIGNED NOT NULL,
    `aoe_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `min_quality` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary',
    `auto_skin` TINYINT(1) NOT NULL DEFAULT 1,
    `smart_loot` TINYINT(1) NOT NULL DEFAULT 1,
    `ignored_items` TEXT COMMENT 'Comma-separated list of item IDs to ignore',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos AoE Loot - Player Preferences';

-- Detailed Loot Statistics Table
DROP TABLE IF EXISTS `dc_aoeloot_detailed_stats`;
CREATE TABLE `dc_aoeloot_detailed_stats` (
    `player_guid` INT UNSIGNED NOT NULL,
    `total_items` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_gold` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'In copper',
    `poor_vendored` INT UNSIGNED NOT NULL DEFAULT 0,
    `vendor_gold` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Gold from auto-vendoring',
    `skinned` INT UNSIGNED NOT NULL DEFAULT 0,
    `mined` INT UNSIGNED NOT NULL DEFAULT 0,
    `herbed` INT UNSIGNED NOT NULL DEFAULT 0,
    `upgrades` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Gear upgrades found',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos AoE Loot - Detailed Statistics';

-- Accumulated Gold Table (for the base AoE loot system)
-- This may already exist from ac_aoeloot.cpp - only create if not exists
CREATE TABLE IF NOT EXISTS `dc_aoeloot_accumulated` (
    `player_guid` INT UNSIGNED NOT NULL,
    `accumulated_gold` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total gold looted via AoE',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos AoE Loot - Accumulated Gold';

-- Quality Distribution Table (for analytics)
DROP TABLE IF EXISTS `dc_aoeloot_quality_distribution`;
CREATE TABLE `dc_aoeloot_quality_distribution` (
    `player_guid` INT UNSIGNED NOT NULL,
    `quality_poor` INT UNSIGNED NOT NULL DEFAULT 0,
    `quality_common` INT UNSIGNED NOT NULL DEFAULT 0,
    `quality_uncommon` INT UNSIGNED NOT NULL DEFAULT 0,
    `quality_rare` INT UNSIGNED NOT NULL DEFAULT 0,
    `quality_epic` INT UNSIGNED NOT NULL DEFAULT 0,
    `quality_legendary` INT UNSIGNED NOT NULL DEFAULT 0,
    `quality_artifact` INT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos AoE Loot - Quality Distribution';

-- =====================================================================
-- Sample Queries
-- =====================================================================

-- Get player's loot summary:
-- SELECT 
--     c.name,
--     s.total_items,
--     CONCAT(FLOOR(s.total_gold/10000), 'g ', FLOOR((s.total_gold%10000)/100), 's ', s.total_gold%100, 'c') as total_gold,
--     s.poor_vendored,
--     CONCAT(FLOOR(s.vendor_gold/10000), 'g') as vendor_gold,
--     s.skinned,
--     s.upgrades
-- FROM dc_aoeloot_detailed_stats s
-- INNER JOIN characters c ON c.guid = s.player_guid
-- ORDER BY s.total_gold DESC
-- LIMIT 20;

-- Get quality distribution for a player:
-- SELECT * FROM dc_aoeloot_quality_distribution WHERE player_guid = ?;

-- Get top gold farmers:
-- SELECT c.name, a.accumulated_gold,
--        CONCAT(FLOOR(a.accumulated_gold/10000), 'g') as formatted
-- FROM dc_aoeloot_accumulated a
-- INNER JOIN characters c ON c.guid = a.player_guid
-- ORDER BY a.accumulated_gold DESC
-- LIMIT 10;
