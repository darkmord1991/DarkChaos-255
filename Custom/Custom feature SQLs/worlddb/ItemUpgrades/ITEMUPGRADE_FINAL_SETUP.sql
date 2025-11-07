-- ============================================================================
-- DarkChaos ItemUpgrade System - CONSOLIDATED SETUP
-- ============================================================================
-- This file contains ALL database changes needed for the item-based upgrade system.
-- Execute this file ONCE to set up the complete system.
--
-- System: Simple item-based currency (uses WoW inventory items)
-- Currency Items: 100998 (Artifact Essence), 100999 (Upgrade Token)
-- Configuration: ItemUpgrade.Currency.EssenceId=100998, ItemUpgrade.Currency.TokenId=100999
--
-- Date: November 7, 2025
-- Status: ✅ VERIFIED - Column names match C++ code
-- ============================================================================

-- ============================================================================
-- CHARACTERS DATABASE SCHEMA
-- ============================================================================
-- Run the following on: acore_characters

-- Table: dc_item_upgrade_state
-- Purpose: Tracks current upgrade level and investment for each item
-- Primary Key: item_guid (unique per item instance)
-- Foreign Key: player_guid → characters(guid)
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_state` (
    `item_guid` INT UNSIGNED NOT NULL COMMENT 'From item_instance.guid',
    `player_guid` INT UNSIGNED NOT NULL,
    `tier_id` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=Leveling, 2=Heroic, 3=Raid, 4=Mythic, 5=Artifact',
    `upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0-15, 0=base, 15=max',
    `tokens_invested` INT UNSIGNED NOT NULL DEFAULT 0,
    `essence_invested` INT UNSIGNED NOT NULL DEFAULT 0,
    `base_item_level` SMALLINT UNSIGNED NOT NULL,
    `upgraded_item_level` SMALLINT UNSIGNED NOT NULL,
    `stat_multiplier` FLOAT NOT NULL DEFAULT 1.0 COMMENT '1.0=base, 1.5=+50% stats, etc',
    `first_upgraded_at` INT UNSIGNED NOT NULL COMMENT 'Unix timestamp',
    `last_upgraded_at` INT UNSIGNED NOT NULL COMMENT 'Unix timestamp',
    `season` INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`item_guid`),
    INDEX `idx_player` (`player_guid`),
    INDEX `idx_tier_level` (`tier_id`, `upgrade_level`),
    INDEX `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Item upgrade states for each item';

-- ============================================================================
-- WORLD DATABASE SCHEMA
-- ============================================================================
-- Run the following on: acore_world

-- Table: dc_item_upgrade_costs
-- Purpose: Defines cost (tokens + essence) for each tier/level combination
-- Primary Key: (tier_id, upgrade_level, season)
-- Data: 75 entries (5 tiers × 15 levels)
-- NOTE: Column names MUST match C++ query in ItemUpgradeCommands.cpp:
--   "SELECT token_cost, essence_cost FROM dc_item_upgrade_costs ..."
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_costs` (
    `tier_id` TINYINT UNSIGNED NOT NULL COMMENT 'Item tier (1-5)',
    `upgrade_level` TINYINT UNSIGNED NOT NULL COMMENT 'Target level (1-15)',
    `token_cost` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Upgrade Token cost (item 100999)',
    `essence_cost` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Artifact Essence cost (item 100998)',
    `ilvl_increase` SMALLINT UNSIGNED NOT NULL DEFAULT 3 COMMENT 'iLevel increase per upgrade',
    `stat_increase_percent` FLOAT NOT NULL DEFAULT 2.0 COMMENT 'Stat % increase per level',
    `season` INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`tier_id`, `upgrade_level`, `season`),
    KEY `idx_tier_level` (`tier_id`, `upgrade_level`),
    KEY `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Upgrade cost configuration per tier and level';

-- Clear existing costs (if re-running setup)
DELETE FROM `dc_item_upgrade_costs` WHERE 1=1;

-- TIER 1 (iLvL 0-299): Budget friendly
INSERT INTO dc_item_upgrade_costs (tier_id, upgrade_level, token_cost, essence_cost) VALUES
(1, 1, 5, 2), (1, 2, 10, 4), (1, 3, 15, 6), (1, 4, 20, 8), (1, 5, 25, 10),
(1, 6, 30, 12), (1, 7, 35, 14), (1, 8, 40, 16), (1, 9, 45, 18), (1, 10, 50, 20),
(1, 11, 55, 22), (1, 12, 60, 24), (1, 13, 65, 26), (1, 14, 70, 28), (1, 15, 75, 30);

-- TIER 2 (iLvL 300-349): Moderate
INSERT INTO dc_item_upgrade_costs (tier_id, upgrade_level, token_cost, essence_cost) VALUES
(2, 1, 10, 5), (2, 2, 20, 10), (2, 3, 30, 15), (2, 4, 40, 20), (2, 5, 50, 25),
(2, 6, 60, 30), (2, 7, 70, 35), (2, 8, 80, 40), (2, 9, 90, 45), (2, 10, 100, 50),
(2, 11, 110, 55), (2, 12, 120, 60), (2, 13, 130, 65), (2, 14, 140, 70), (2, 15, 150, 75);

-- TIER 3 (iLvL 350-399): Standard
INSERT INTO dc_item_upgrade_costs (tier_id, upgrade_level, token_cost, essence_cost) VALUES
(3, 1, 15, 8), (3, 2, 30, 16), (3, 3, 45, 24), (3, 4, 60, 32), (3, 5, 75, 40),
(3, 6, 90, 48), (3, 7, 105, 56), (3, 8, 120, 64), (3, 9, 135, 72), (3, 10, 150, 80),
(3, 11, 165, 88), (3, 12, 180, 96), (3, 13, 195, 104), (3, 14, 210, 112), (3, 15, 225, 120);

-- TIER 4 (iLvL 400-449): Advanced
INSERT INTO dc_item_upgrade_costs (tier_id, upgrade_level, token_cost, essence_cost) VALUES
(4, 1, 25, 15), (4, 2, 50, 30), (4, 3, 75, 45), (4, 4, 100, 60), (4, 5, 125, 75),
(4, 6, 150, 90), (4, 7, 175, 105), (4, 8, 200, 120), (4, 9, 225, 135), (4, 10, 250, 150),
(4, 11, 275, 165), (4, 12, 300, 180), (4, 13, 325, 195), (4, 14, 350, 210), (4, 15, 375, 225);

-- TIER 5 (iLvL 450+): Premium/Artifact
INSERT INTO dc_item_upgrade_costs (tier_id, upgrade_level, token_cost, essence_cost) VALUES
(5, 1, 50, 30), (5, 2, 100, 60), (5, 3, 150, 90), (5, 4, 200, 120), (5, 5, 250, 150),
(5, 6, 300, 180), (5, 7, 350, 210), (5, 8, 400, 240), (5, 9, 450, 270), (5, 10, 500, 300),
(5, 11, 550, 330), (5, 12, 600, 360), (5, 13, 650, 390), (5, 14, 700, 420), (5, 15, 750, 450);

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these queries to verify setup:
-- 
-- SELECT COUNT(*) as 'State Entries' FROM acore_characters.dc_item_upgrade_state;
-- SELECT COUNT(*) as 'Cost Entries' FROM acore_world.dc_item_upgrade_costs;
-- SELECT DISTINCT tier_id FROM acore_world.dc_item_upgrade_costs ORDER BY tier_id;
--
-- Expected Results:
-- - State Entries: 0 (empty until players upgrade items)
-- - Cost Entries: 75 (5 tiers × 15 levels)
-- - Distinct tiers: 1, 2, 3, 4, 5

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================
-- System is ready! Items 100998 & 100999 are now the currency.
-- Commands available:
--   /dcupgrade init    - Check balance (shows inventory items)
--   /dcupgrade query <bag> <slot> - Check item upgrade state
--   /dcupgrade perform <bag> <slot> <level> - Upgrade item (deducts items)
-- ============================================================================
