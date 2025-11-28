-- =====================================================================
-- DarkChaos AoE Loot Extensions - CHARACTER Database Setup
-- =====================================================================
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
    `auto_vendor_poor` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Auto-vendor poor quality items',
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
    `mythic_bonus_items` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Bonus items from M+ runs',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos AoE Loot - Detailed Statistics';

-- Accumulated Gold Table (for the base AoE loot system)
-- Uses CREATE IF NOT EXISTS in case base system already created it
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

-- Session Loot Summary (per-session tracking)
DROP TABLE IF EXISTS `dc_aoeloot_sessions`;
CREATE TABLE `dc_aoeloot_sessions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `session_start` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `session_end` TIMESTAMP NULL,
    `map_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `instance_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `items_looted` INT UNSIGNED NOT NULL DEFAULT 0,
    `gold_looted` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `vendor_gold` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `is_mythic` TINYINT(1) NOT NULL DEFAULT 0,
    `keystone_level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    INDEX `idx_player` (`player_guid`, `session_start` DESC),
    INDEX `idx_map` (`map_id`),
    INDEX `idx_mythic` (`is_mythic`, `keystone_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos AoE Loot - Session Tracking';

-- =====================================================================
-- Sample Queries
-- =====================================================================

-- Get player's loot summary:
-- SELECT 
--     c.name,
--     s.total_items,
--     CONCAT(FLOOR(s.total_gold/10000), 'g ', FLOOR((s.total_gold%10000)/100), 's') as total_gold,
--     s.poor_vendored,
--     CONCAT(FLOOR(s.vendor_gold/10000), 'g') as vendor_gold,
--     s.skinned,
--     s.upgrades,
--     s.mythic_bonus_items
-- FROM dc_aoeloot_detailed_stats s
-- INNER JOIN characters c ON c.guid = s.player_guid
-- ORDER BY s.total_gold DESC
-- LIMIT 20;

-- Get player preferences:
-- SELECT p.*, c.name FROM dc_aoeloot_preferences p
-- INNER JOIN characters c ON c.guid = p.player_guid
-- WHERE p.player_guid = ?;

-- Get session history for a player:
-- SELECT 
--     session_start, session_end,
--     items_looted, 
--     CONCAT(FLOOR(gold_looted/10000), 'g') as gold,
--     CASE WHEN is_mythic THEN CONCAT('+', keystone_level) ELSE 'Normal' END as type
-- FROM dc_aoeloot_sessions
-- WHERE player_guid = ?
-- ORDER BY session_start DESC
-- LIMIT 10;
