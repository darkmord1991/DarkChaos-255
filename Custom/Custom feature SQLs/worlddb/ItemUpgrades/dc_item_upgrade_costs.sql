-- DarkChaos Item Upgrade System - World Database
-- Upgrade cost configuration table (global, not per-character)
-- Run this on WORLD database (acore_world)

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_costs` (
    `tier_id` TINYINT UNSIGNED NOT NULL,
    `upgrade_level` TINYINT UNSIGNED NOT NULL COMMENT 'Target level (1-15)',
    `token_cost` INT UNSIGNED NOT NULL DEFAULT 0,
    `essence_cost` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Only for Tier 5',
    `ilvl_increase` SMALLINT UNSIGNED NOT NULL DEFAULT 3 COMMENT 'iLevel increase per upgrade',
    `stat_increase_percent` FLOAT NOT NULL DEFAULT 2.0 COMMENT 'Stat % increase per level',
    `season` INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`tier_id`, `upgrade_level`, `season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Upgrade cost configuration per tier and level';

-- Insert default costs for Season 1 (will skip if already exists)
-- Tier 1: Leveling (1-60)
INSERT IGNORE INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_increase`, `stat_increase_percent`, `season`) VALUES
(1, 1, 5, 0, 3, 2.0, 1),
(1, 2, 5, 0, 3, 2.0, 1),
(1, 3, 5, 0, 3, 2.0, 1),
(1, 4, 10, 0, 3, 2.0, 1),
(1, 5, 10, 0, 3, 2.0, 1),
(1, 6, 10, 0, 3, 2.0, 1),
(1, 7, 15, 0, 3, 2.0, 1),
(1, 8, 15, 0, 3, 2.0, 1),
(1, 9, 15, 0, 3, 2.0, 1),
(1, 10, 20, 0, 3, 2.0, 1),
(1, 11, 20, 0, 3, 2.0, 1),
(1, 12, 20, 0, 3, 2.0, 1),
(1, 13, 25, 0, 3, 2.0, 1),
(1, 14, 25, 0, 3, 2.0, 1),
(1, 15, 30, 0, 3, 2.0, 1);

-- Tier 2: Heroic Dungeons
INSERT IGNORE INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_increase`, `stat_increase_percent`, `season`) VALUES
(2, 1, 10, 0, 3, 2.0, 1),
(2, 2, 10, 0, 3, 2.0, 1),
(2, 3, 10, 0, 3, 2.0, 1),
(2, 4, 15, 0, 3, 2.0, 1),
(2, 5, 15, 0, 3, 2.0, 1),
(2, 6, 15, 0, 3, 2.0, 1),
(2, 7, 20, 0, 3, 2.0, 1),
(2, 8, 20, 0, 3, 2.0, 1),
(2, 9, 20, 0, 3, 2.0, 1),
(2, 10, 25, 0, 3, 2.0, 1),
(2, 11, 25, 0, 3, 2.0, 1),
(2, 12, 25, 0, 3, 2.0, 1),
(2, 13, 30, 0, 3, 2.0, 1),
(2, 14, 30, 0, 3, 2.0, 1),
(2, 15, 35, 0, 3, 2.0, 1);

-- Tier 3: Raid
INSERT IGNORE INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_increase`, `stat_increase_percent`, `season`) VALUES
(3, 1, 15, 0, 3, 2.0, 1),
(3, 2, 15, 0, 3, 2.0, 1),
(3, 3, 15, 0, 3, 2.0, 1),
(3, 4, 20, 0, 3, 2.0, 1),
(3, 5, 20, 0, 3, 2.0, 1),
(3, 6, 20, 0, 3, 2.0, 1),
(3, 7, 25, 0, 3, 2.0, 1),
(3, 8, 25, 0, 3, 2.0, 1),
(3, 9, 25, 0, 3, 2.0, 1),
(3, 10, 30, 0, 3, 2.0, 1),
(3, 11, 30, 0, 3, 2.0, 1),
(3, 12, 30, 0, 3, 2.0, 1),
(3, 13, 35, 0, 3, 2.0, 1),
(3, 14, 35, 0, 3, 2.0, 1),
(3, 15, 40, 0, 3, 2.0, 1);

-- Tier 4: Mythic
INSERT IGNORE INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_increase`, `stat_increase_percent`, `season`) VALUES
(4, 1, 20, 0, 3, 2.0, 1),
(4, 2, 20, 0, 3, 2.0, 1),
(4, 3, 20, 0, 3, 2.0, 1),
(4, 4, 25, 0, 3, 2.0, 1),
(4, 5, 25, 0, 3, 2.0, 1),
(4, 6, 25, 0, 3, 2.0, 1),
(4, 7, 30, 0, 3, 2.0, 1),
(4, 8, 30, 0, 3, 2.0, 1),
(4, 9, 30, 0, 3, 2.0, 1),
(4, 10, 35, 0, 3, 2.0, 1),
(4, 11, 35, 0, 3, 2.0, 1),
(4, 12, 35, 0, 3, 2.0, 1),
(4, 13, 40, 0, 3, 2.0, 1),
(4, 14, 40, 0, 3, 2.0, 1),
(4, 15, 50, 0, 3, 2.0, 1);

-- Tier 5: Artifact (requires both tokens AND essence)
INSERT IGNORE INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `ilvl_increase`, `stat_increase_percent`, `season`) VALUES
(5, 1, 30, 10, 3, 2.0, 1),
(5, 2, 30, 10, 3, 2.0, 1),
(5, 3, 30, 10, 3, 2.0, 1),
(5, 4, 35, 15, 3, 2.0, 1),
(5, 5, 35, 15, 3, 2.0, 1),
(5, 6, 35, 15, 3, 2.0, 1),
(5, 7, 40, 20, 3, 2.0, 1),
(5, 8, 40, 20, 3, 2.0, 1),
(5, 9, 40, 20, 3, 2.0, 1),
(5, 10, 45, 25, 3, 2.0, 1),
(5, 11, 45, 25, 3, 2.0, 1),
(5, 12, 45, 25, 3, 2.0, 1),
(5, 13, 50, 30, 3, 2.0, 1),
(5, 14, 50, 30, 3, 2.0, 1),
(5, 15, 60, 40, 3, 2.0, 1);
