-- ============================================================================
-- Phase 4A: Item Upgrade Mechanics - Database Migration
-- ============================================================================
-- DarkChaos Custom Database Schema
-- Date: November 4, 2025
-- 
-- This migration creates all tables required for Phase 4A item upgrade system.
-- All tables use the dc_ prefix as per DarkChaos naming convention.
-- 
-- Tables Created:
--   - dc_item_upgrades: Main upgrade state per item
--   - dc_item_upgrade_log: Audit trail of all upgrades
--   - dc_item_upgrade_costs: Tier cost configuration
--   - dc_item_upgrade_stat_scaling: Stat scaling configuration
-- ============================================================================

-- ============================================================================
-- Table: dc_item_upgrades
-- Purpose: Stores the current upgrade state for each item
-- Primary Key: item_guid (unique per item instance)
-- Foreign Key: player_guid → characters(guid)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_item_upgrades` (
    `item_guid` INT UNSIGNED PRIMARY KEY COMMENT 'Unique item identifier from item_instance table',
    `player_guid` INT UNSIGNED NOT NULL COMMENT 'Owner of the item',
    `upgrade_level` TINYINT UNSIGNED DEFAULT 0 COMMENT 'Current upgrade level (0-15)',
    `essence_invested` INT UNSIGNED DEFAULT 0 COMMENT 'Total essence spent on this item',
    `tokens_invested` INT UNSIGNED DEFAULT 0 COMMENT 'Total tokens spent on this item',
    `base_item_level` SMALLINT UNSIGNED NOT NULL COMMENT 'Original item level',
    `upgraded_item_level` SMALLINT UNSIGNED NOT NULL COMMENT 'Current item level with upgrades',
    `current_stat_multiplier` FLOAT DEFAULT 1.0 COMMENT 'Current stat scaling multiplier (1.0 = 0% bonus)',
    `last_upgraded_timestamp` INT UNSIGNED COMMENT 'Unix timestamp of last upgrade',
    `season_id` INT UNSIGNED DEFAULT 1 COMMENT 'Season during which upgrades were applied',
    
    KEY `idx_player` (`player_guid`),
    KEY `idx_season` (`season_id`),
    KEY `idx_player_season` (`player_guid`, `season_id`),
    CONSTRAINT `fk_dc_item_upgrades_player` FOREIGN KEY (`player_guid`) REFERENCES `characters`(`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='DarkChaos: Stores item upgrade states';

-- ============================================================================
-- Table: dc_item_upgrade_log
-- Purpose: Complete audit trail of every upgrade transaction
-- Primary Key: log_id (auto-increment)
-- Foreign Key: player_guid → characters(guid)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_log` (
    `log_id` INT UNSIGNED PRIMARY KEY AUTO_INCREMENT COMMENT 'Unique log entry ID',
    `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player performing upgrade',
    `item_guid` INT UNSIGNED NOT NULL COMMENT 'Item being upgraded',
    `item_id` INT UNSIGNED NOT NULL COMMENT 'Item template ID',
    `upgrade_from` TINYINT UNSIGNED NOT NULL COMMENT 'Previous upgrade level',
    `upgrade_to` TINYINT UNSIGNED NOT NULL COMMENT 'New upgrade level',
    `essence_cost` INT UNSIGNED NOT NULL COMMENT 'Essence paid for this upgrade',
    `token_cost` INT UNSIGNED NOT NULL COMMENT 'Tokens paid for this upgrade',
    `base_ilvl` SMALLINT UNSIGNED NOT NULL COMMENT 'Base item level',
    `old_ilvl` SMALLINT UNSIGNED NOT NULL COMMENT 'Item level before upgrade',
    `new_ilvl` SMALLINT UNSIGNED NOT NULL COMMENT 'Item level after upgrade',
    `old_stat_multiplier` FLOAT COMMENT 'Stat multiplier before upgrade',
    `new_stat_multiplier` FLOAT COMMENT 'Stat multiplier after upgrade',
    `timestamp` INT UNSIGNED NOT NULL COMMENT 'When this upgrade occurred',
    `season_id` INT UNSIGNED DEFAULT 1 COMMENT 'Season ID',
    
    KEY `idx_player` (`player_guid`),
    KEY `idx_timestamp` (`timestamp`),
    KEY `idx_season` (`season_id`),
    KEY `idx_player_timestamp` (`player_guid`, `timestamp`),
    CONSTRAINT `fk_dc_item_upgrade_log_player` FOREIGN KEY (`player_guid`) REFERENCES `characters`(`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='DarkChaos: Complete log of all item upgrades';

-- ============================================================================
-- Table: dc_item_upgrade_costs
-- Purpose: Configuration for tier-based upgrade costs
-- Primary Key: tier_id (1-5)
-- Notes: All costs per level use 10% escalation (1.1x multiplier)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_costs` (
    `tier_id` TINYINT UNSIGNED PRIMARY KEY COMMENT 'Item tier (1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary)',
    `tier_name` VARCHAR(50) NOT NULL COMMENT 'Human-readable tier name',
    `base_essence_cost` FLOAT NOT NULL COMMENT 'Base essence cost for level 0→1',
    `base_token_cost` FLOAT NOT NULL COMMENT 'Base token cost for level 0→1',
    `escalation_rate` FLOAT DEFAULT 1.1 COMMENT 'Cost multiplier per level (1.1 = 10% increase)',
    `cost_multiplier` FLOAT DEFAULT 1.0 COMMENT 'Overall cost adjustment for tier',
    `stat_multiplier` FLOAT DEFAULT 1.0 COMMENT 'Stat scaling multiplier for tier (0.9-1.25x)',
    `ilvl_multiplier` FLOAT DEFAULT 1.0 COMMENT 'Item level bonus multiplier (1.0-2.5x)',
    `max_upgrade_level` TINYINT UNSIGNED DEFAULT 15 COMMENT 'Maximum upgrade level for tier',
    `enabled` BOOLEAN DEFAULT TRUE COMMENT 'Enable/disable tier upgrades',
    `last_modified` INT UNSIGNED COMMENT 'Last modification timestamp'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='DarkChaos: Item upgrade cost configuration per tier';

-- ============================================================================
-- Initial Data: dc_item_upgrade_costs
-- ============================================================================
-- Tier Configuration:
--   Tier 1 (Common):    10-15 E/5-8 T base, max 10 levels, 0.8x cost, 0.9x stat, 1.0x ilvl
--   Tier 2 (Uncommon):  25-35 E/10-14 T base, max 12 levels, 1.0x cost, 0.95x stat, 1.0x ilvl
--   Tier 3 (Rare):      50-70 E/15-21 T base, max 15 levels, 1.2x cost, 1.0x stat, 1.5x ilvl
--   Tier 4 (Epic):      100-140 E/25-35 T base, max 15 levels, 1.5x cost, 1.15x stat, 2.0x ilvl
--   Tier 5 (Legendary): 200-280 E/50-70 T base, max 15 levels, 2.0x cost, 1.25x stat, 2.5x ilvl
-- ============================================================================
DELETE FROM `dc_item_upgrade_costs`;
INSERT INTO `dc_item_upgrade_costs` 
    (`tier_id`, `tier_name`, `base_essence_cost`, `base_token_cost`, `escalation_rate`, 
     `cost_multiplier`, `stat_multiplier`, `ilvl_multiplier`, `max_upgrade_level`, `enabled`) 
VALUES
    (1, 'Common', 10.0, 5.0, 1.1, 0.8, 0.9, 1.0, 10, TRUE),
    (2, 'Uncommon', 25.0, 10.0, 1.1, 1.0, 0.95, 1.0, 12, TRUE),
    (3, 'Rare', 50.0, 15.0, 1.1, 1.2, 1.0, 1.5, 15, TRUE),
    (4, 'Epic', 100.0, 25.0, 1.1, 1.5, 1.15, 2.0, 15, TRUE),
    (5, 'Legendary', 200.0, 50.0, 1.1, 2.0, 1.25, 2.5, 15, TRUE)
ON DUPLICATE KEY UPDATE 
    `base_essence_cost` = VALUES(`base_essence_cost`),
    `base_token_cost` = VALUES(`base_token_cost`),
    `cost_multiplier` = VALUES(`cost_multiplier`),
    `stat_multiplier` = VALUES(`stat_multiplier`),
    `ilvl_multiplier` = VALUES(`ilvl_multiplier`);

-- ============================================================================
-- Table: dc_item_upgrade_stat_scaling
-- Purpose: Configuration for stat scaling calculations
-- Primary Key: scaling_id (1)
-- Formula: Multiplier = (1.0 + level * base_multiplier_per_level) * tier_multiplier
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_stat_scaling` (
    `scaling_id` TINYINT UNSIGNED PRIMARY KEY COMMENT 'Unique scaling configuration ID',
    `base_multiplier_per_level` FLOAT DEFAULT 0.025 COMMENT 'Base stat multiplier per level (2.5% = 0.025)',
    `min_upgrade_level` TINYINT UNSIGNED DEFAULT 0 COMMENT 'Minimum level for scaling',
    `max_upgrade_level` TINYINT UNSIGNED DEFAULT 15 COMMENT 'Maximum level for scaling',
    `enabled` BOOLEAN DEFAULT TRUE COMMENT 'Enable/disable scaling',
    `last_modified` INT UNSIGNED COMMENT 'Last modification timestamp'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='DarkChaos: Item upgrade stat scaling configuration';

-- ============================================================================
-- Initial Data: dc_item_upgrade_stat_scaling
-- ============================================================================
-- Default Configuration:
--   Base multiplier: 0.025 per level (2.5%)
--   Min level: 0
--   Max level: 15
--   Enabled: TRUE
--
-- Stat Scaling Formula:
--   Multiplier = (1.0 + upgrade_level * base_multiplier_per_level) * tier_stat_multiplier
--   Example (Epic, level 10): (1.0 + 10 * 0.025) * 1.15 = 1.288x (+28.8% stats)
-- ============================================================================
DELETE FROM `dc_item_upgrade_stat_scaling`;
INSERT INTO `dc_item_upgrade_stat_scaling` 
    (`scaling_id`, `base_multiplier_per_level`, `min_upgrade_level`, `max_upgrade_level`, `enabled`) 
VALUES
    (1, 0.025, 0, 15, TRUE)
ON DUPLICATE KEY UPDATE 
    `base_multiplier_per_level` = VALUES(`base_multiplier_per_level`);

-- ============================================================================
-- Performance Indices
-- ============================================================================
CREATE INDEX `idx_dc_item_upgrades_player_season` ON `dc_item_upgrades`(`player_guid`, `season_id`);
CREATE INDEX `idx_dc_item_upgrade_log_player_timestamp` ON `dc_item_upgrade_log`(`player_guid`, `timestamp`);

-- ============================================================================
-- Analytics View: dc_player_upgrade_summary
-- Purpose: Aggregated upgrade statistics per player
-- ============================================================================
CREATE OR REPLACE VIEW `dc_player_upgrade_summary` AS
SELECT 
    `iu`.`player_guid`,
    COUNT(DISTINCT `iu`.`item_guid`) as `items_upgraded`,
    SUM(`iu`.`essence_invested`) as `total_essence_spent`,
    SUM(`iu`.`tokens_invested`) as `total_tokens_spent`,
    AVG(`iu`.`current_stat_multiplier`) as `average_stat_multiplier`,
    AVG(`iu`.`upgraded_item_level` - `iu`.`base_item_level`) as `average_ilvl_gain`,
    MAX(`iu`.`last_upgraded_timestamp`) as `last_upgraded`,
    SUM(CASE WHEN `iu`.`upgrade_level` = 15 THEN 1 ELSE 0 END) as `fully_upgraded_items`
FROM `dc_item_upgrades` `iu`
GROUP BY `iu`.`player_guid`;

-- ============================================================================
-- Analytics View: dc_upgrade_speed_stats
-- Purpose: Upgrade frequency and efficiency per player
-- ============================================================================
CREATE OR REPLACE VIEW `dc_upgrade_speed_stats` AS
SELECT 
    `player_guid`,
    COUNT(*) as `total_upgrades`,
    COUNT(*) / (UNIX_TIMESTAMP(MAX(`timestamp`)) - UNIX_TIMESTAMP(MIN(`timestamp`)) + 1) * 86400 as `upgrades_per_day`,
    MIN(`timestamp`) as `first_upgrade`,
    MAX(`timestamp`) as `last_upgrade`,
    AVG(`essence_cost` + `token_cost`) as `average_cost_per_upgrade`
FROM `dc_item_upgrade_log`
GROUP BY `player_guid`;

-- ============================================================================
-- Migration Summary
-- ============================================================================
-- Tables Created: 4
--   ✓ dc_item_upgrades (main state)
--   ✓ dc_item_upgrade_log (audit trail)
--   ✓ dc_item_upgrade_costs (tier configuration)
--   ✓ dc_item_upgrade_stat_scaling (scaling configuration)
--
-- Views Created: 2
--   ✓ dc_player_upgrade_summary (player statistics)
--   ✓ dc_upgrade_speed_stats (upgrade frequency)
--
-- Initial Data Populated:
--   ✓ 5 tier configurations (Common → Legendary)
--   ✓ Stat scaling configuration
--
-- Indices Created: 4
--   ✓ idx_player on dc_item_upgrades
--   ✓ idx_season on dc_item_upgrades
--   ✓ idx_player_season on dc_item_upgrades
--   ✓ idx_player_timestamp on dc_item_upgrade_log
--
-- Foreign Keys: 2
--   ✓ dc_item_upgrades → characters(guid)
--   ✓ dc_item_upgrade_log → characters(guid)
-- 
-- Status: Ready for Phase 4A Deployment ✓
-- ============================================================================
