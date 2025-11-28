-- =====================================================================
-- DarkChaos Phased Dueling System - WORLD Database Setup
-- =====================================================================
-- Run this on the `acore_world` database.
-- =====================================================================

-- Note: The Phased Dueling system primarily uses character database for
-- player statistics. This file is included for future world database
-- tables if needed (e.g., duel zone configurations, tournament NPC data).

-- Duel Zone Configuration (Optional - for designated duel areas)
DROP TABLE IF EXISTS `dc_duel_zones`;
CREATE TABLE `dc_duel_zones` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `zone_id` INT UNSIGNED NOT NULL,
    `area_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `name` VARCHAR(64) NOT NULL,
    `description` TEXT,
    `min_level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `max_level` TINYINT UNSIGNED NOT NULL DEFAULT 255,
    `allowed_classes` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Bitmask, 0 = all classes',
    `phase_id_start` INT UNSIGNED NOT NULL DEFAULT 100000 COMMENT 'Starting phase ID for this zone',
    `phase_id_end` INT UNSIGNED NOT NULL DEFAULT 199999 COMMENT 'Ending phase ID for this zone',
    `rewards_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    `honor_multiplier` FLOAT NOT NULL DEFAULT 1.0,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_zone_area` (`zone_id`, `area_id`),
    INDEX `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos Phased Dueling - Zone Configuration';

-- Insert default duel zones (examples)
INSERT INTO `dc_duel_zones` (`zone_id`, `area_id`, `name`, `description`, `phase_id_start`, `phase_id_end`) VALUES
(1637, 0, 'Orgrimmar Dueling', 'Standard dueling area in Orgrimmar', 100000, 149999),
(1519, 0, 'Stormwind Dueling', 'Standard dueling area in Stormwind', 150000, 199999),
(3703, 0, 'Shattrath Dueling', 'Cross-faction dueling in Shattrath', 200000, 249999),
(4395, 0, 'Dalaran Dueling', 'High-level dueling in Dalaran', 250000, 299999);

-- Tournament NPC Data (Optional - for tournament system)
DROP TABLE IF EXISTS `dc_duel_tournament_npcs`;
CREATE TABLE `dc_duel_tournament_npcs` (
    `entry` INT UNSIGNED NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `subname` VARCHAR(100) DEFAULT 'Tournament Master',
    `tournament_type` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=Standard, 1=1v1, 2=Class-only',
    `min_level` TINYINT UNSIGNED NOT NULL DEFAULT 80,
    `entry_fee` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'In copper',
    `reward_item` INT UNSIGNED NOT NULL DEFAULT 0,
    `reward_count` INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos Phased Dueling - Tournament NPCs';

-- =====================================================================
-- Creature Template Updates (if using tournament NPCs)
-- =====================================================================
-- Note: Uncomment and modify entry IDs as needed
-- 
-- INSERT INTO creature_template (entry, name, subname, ScriptName) VALUES
-- (1000001, 'Tournament Master', 'Duel Tournament', 'npc_dc_tournament_master');
