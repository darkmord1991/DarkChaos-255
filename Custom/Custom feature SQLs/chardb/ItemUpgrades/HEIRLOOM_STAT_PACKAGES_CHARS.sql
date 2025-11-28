-- ═══════════════════════════════════════════════════════════════════════════════
-- HEIRLOOM SECONDARY STAT PACKAGE SYSTEM - CHARACTER DATABASE
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- FILE: HEIRLOOM_STAT_PACKAGES_CHARS.sql
-- DATABASE: acore_characters
-- 
-- OVERVIEW:
-- Tracks which stat package each player has chosen for their heirloom items,
-- and the current upgrade level of that package.
--
-- RELATED FILES:
-- - HEIRLOOM_STAT_PACKAGES_WORLD.sql (world database - package definitions)
-- - HEIRLOOM_SHIRT_PRIMARY_STATS.sql (item template updates)
--
-- C++ HANDLER: ItemUpgradeAddonHandler.cpp - HandleDCHeirloomCommand
-- COMMAND: .dcheirloom upgrade <bag> <slot> <level> <packageId>
--
-- ═══════════════════════════════════════════════════════════════════════════════

USE acore_chars;

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE 1: Heirloom Upgrades (Main State Table)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Tracks current upgrade state for each heirloom item
-- Used by C++ handler: HandleDCHeirloomCommand

DROP TABLE IF EXISTS `dc_heirloom_upgrades`;
CREATE TABLE `dc_heirloom_upgrades` (
    `item_guid` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Item instance GUID from item_instance',
    `player_guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `item_entry` INT UNSIGNED NOT NULL COMMENT 'Item template entry (e.g., 300365)',
    `upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Current upgrade level (1-15)',
    `package_id` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Chosen package (1-12)',
    `enchant_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Applied SpellItemEnchantment.dbc ID',
    `essence_invested` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total essence spent',
    `tokens_invested` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total tokens spent',
    `first_upgraded_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When first upgraded',
    `last_upgraded_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'When last upgraded',
    
    KEY `idx_player` (`player_guid`),
    KEY `idx_package` (`package_id`),
    KEY `idx_entry` (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Heirloom stat package upgrade state';


-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE 2: Player Package Selections (Legacy/Addon Sync)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Used for addon communication - tracks package selection before upgrade

DROP TABLE IF EXISTS `dc_heirloom_player_packages`;
CREATE TABLE `dc_heirloom_player_packages` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `item_guid` INT UNSIGNED NOT NULL COMMENT 'Item instance GUID from item_instance',
    `player_guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `item_entry` INT UNSIGNED NOT NULL COMMENT 'Item template entry (e.g., 300365)',
    `package_id` TINYINT UNSIGNED NOT NULL COMMENT 'Chosen package (1-12, FK to dc_heirloom_stat_packages)',
    `package_level` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Current upgrade level (1-15)',
    `essence_invested` INT UNSIGNED NOT NULL DEFAULT 50 COMMENT 'Total essence spent on this package',
    `times_respec` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Number of times player changed packages',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY `unique_item` (`item_guid`) COMMENT 'One package per item instance',
    KEY `idx_player` (`player_guid`),
    KEY `idx_package` (`package_id`),
    KEY `idx_entry` (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player heirloom stat package selections and progress';


-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE 3: Heirloom Upgrade Log
-- ═══════════════════════════════════════════════════════════════════════════════
-- Tracks individual upgrade transactions - used by C++ handler

DROP TABLE IF EXISTS `dc_heirloom_upgrade_log`;
CREATE TABLE `dc_heirloom_upgrade_log` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `player_guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `item_guid` INT UNSIGNED NOT NULL COMMENT 'Item instance GUID',
    `item_entry` INT UNSIGNED NOT NULL COMMENT 'Item template entry',
    `from_level` TINYINT UNSIGNED NOT NULL COMMENT 'Previous level',
    `to_level` TINYINT UNSIGNED NOT NULL COMMENT 'New level',
    `from_package` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Previous package ID',
    `to_package` TINYINT UNSIGNED NOT NULL COMMENT 'New package ID',
    `enchant_id` INT UNSIGNED NOT NULL COMMENT 'Applied enchantment ID',
    `token_cost` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Tokens spent for this upgrade',
    `essence_cost` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Essence spent for this upgrade',
    `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    KEY `idx_player` (`player_guid`),
    KEY `idx_item` (`item_guid`),
    KEY `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Heirloom upgrade transaction log';


-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE 4: Package Change History (Respec Log)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Tracks when players change their package selection

DROP TABLE IF EXISTS `dc_heirloom_package_history`;
CREATE TABLE `dc_heirloom_package_history` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `item_guid` INT UNSIGNED NOT NULL COMMENT 'Item instance GUID',
    `player_guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `old_package_id` TINYINT UNSIGNED NOT NULL COMMENT 'Previous package ID',
    `old_package_level` TINYINT UNSIGNED NOT NULL COMMENT 'Previous package level',
    `new_package_id` TINYINT UNSIGNED NOT NULL COMMENT 'New package ID',
    `new_package_level` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'New package level (usually 1)',
    `essence_refunded` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Essence refunded (50% of invested)',
    `respec_cost` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Gold cost for respec (if any)',
    `reason` VARCHAR(64) DEFAULT NULL COMMENT 'Optional reason (manual, spec_change, etc.)',
    `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    KEY `idx_player` (`player_guid`),
    KEY `idx_item` (`item_guid`),
    KEY `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='History of package changes for analytics';


-- ═══════════════════════════════════════════════════════════════════════════════
-- HELPER VIEW: Player Heirloom Summary
-- ═══════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS `v_player_heirloom_upgrades`;
CREATE VIEW `v_player_heirloom_upgrades` AS
SELECT 
    hu.player_guid,
    hu.item_guid,
    hu.item_entry,
    hu.upgrade_level,
    hu.package_id,
    hu.enchant_id,
    hu.essence_invested,
    hu.tokens_invested,
    hu.first_upgraded_at,
    hu.last_upgraded_at
FROM dc_heirloom_upgrades hu;


-- ═══════════════════════════════════════════════════════════════════════════════
-- STORED PROCEDURES
-- ═══════════════════════════════════════════════════════════════════════════════

DELIMITER //

-- Procedure: Select or change a package
DROP PROCEDURE IF EXISTS SelectHeirloomPackage//
CREATE PROCEDURE SelectHeirloomPackage(
    IN p_item_guid INT UNSIGNED,
    IN p_player_guid INT UNSIGNED,
    IN p_item_entry INT UNSIGNED,
    IN p_package_id TINYINT UNSIGNED,
    OUT p_result_code INT,
    OUT p_result_message VARCHAR(128)
)
BEGIN
    DECLARE v_existing_package TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_existing_level TINYINT UNSIGNED DEFAULT 1;
    DECLARE v_existing_essence INT UNSIGNED DEFAULT 0;
    DECLARE v_refund_essence INT UNSIGNED DEFAULT 0;
    
    -- Check if item already has a package
    SELECT package_id, package_level, essence_invested 
    INTO v_existing_package, v_existing_level, v_existing_essence
    FROM dc_heirloom_player_packages
    WHERE item_guid = p_item_guid AND player_guid = p_player_guid;
    
    IF v_existing_package IS NULL THEN
        -- First time selecting a package
        INSERT INTO dc_heirloom_player_packages 
            (item_guid, player_guid, item_entry, package_id, package_level, essence_invested)
        VALUES 
            (p_item_guid, p_player_guid, p_item_entry, p_package_id, 1, 50);
        
        SET p_result_code = 1;
        SET p_result_message = CONCAT('Package selected! Starting at level 1.');
        
    ELSEIF v_existing_package = p_package_id THEN
        -- Same package, no change needed
        SET p_result_code = 0;
        SET p_result_message = 'You already have this package selected.';
        
    ELSE
        -- Changing to different package - calculate 50% refund
        SET v_refund_essence = FLOOR(v_existing_essence / 2);
        
        -- Log the package change
        INSERT INTO dc_heirloom_package_history
            (item_guid, player_guid, old_package_id, old_package_level, 
             new_package_id, new_package_level, essence_refunded, reason)
        VALUES
            (p_item_guid, p_player_guid, v_existing_package, v_existing_level,
             p_package_id, 1, v_refund_essence, 'manual_respec');
        
        -- Update to new package at level 1
        UPDATE dc_heirloom_player_packages
        SET package_id = p_package_id,
            package_level = 1,
            essence_invested = 50,
            times_respec = times_respec + 1
        WHERE item_guid = p_item_guid AND player_guid = p_player_guid;
        
        SET p_result_code = 2;
        SET p_result_message = CONCAT('Package changed! Refunded ', v_refund_essence, ' essence (50%).');
    END IF;
END//


-- Procedure: Upgrade package level
DROP PROCEDURE IF EXISTS UpgradeHeirloomPackage//
CREATE PROCEDURE UpgradeHeirloomPackage(
    IN p_item_guid INT UNSIGNED,
    IN p_player_guid INT UNSIGNED,
    OUT p_result_code INT,
    OUT p_new_level TINYINT UNSIGNED,
    OUT p_essence_cost INT UNSIGNED,
    OUT p_result_message VARCHAR(128)
)
BEGIN
    DECLARE v_package_id TINYINT UNSIGNED;
    DECLARE v_current_level TINYINT UNSIGNED;
    DECLARE v_current_essence INT UNSIGNED;
    DECLARE v_upgrade_cost INT UNSIGNED;
    
    -- Get current package info
    SELECT package_id, package_level, essence_invested
    INTO v_package_id, v_current_level, v_current_essence
    FROM dc_heirloom_player_packages
    WHERE item_guid = p_item_guid AND player_guid = p_player_guid;
    
    IF v_package_id IS NULL THEN
        SET p_result_code = -1;
        SET p_new_level = 0;
        SET p_essence_cost = 0;
        SET p_result_message = 'No package selected for this item.';
        
    ELSEIF v_current_level >= 15 THEN
        SET p_result_code = -2;
        SET p_new_level = 15;
        SET p_essence_cost = 0;
        SET p_result_message = 'Package is already at maximum level (15).';
        
    ELSE
        -- Get upgrade cost for next level (query world database)
        -- Note: In production, this would query acore_world.dc_heirloom_package_levels
        -- For now, use the formula directly
        SET v_upgrade_cost = CASE v_current_level + 1
            WHEN 2 THEN 75 WHEN 3 THEN 100 WHEN 4 THEN 150 WHEN 5 THEN 200
            WHEN 6 THEN 275 WHEN 7 THEN 350 WHEN 8 THEN 450 WHEN 9 THEN 575
            WHEN 10 THEN 725 WHEN 11 THEN 900 WHEN 12 THEN 1100 WHEN 13 THEN 1350
            WHEN 14 THEN 1650 WHEN 15 THEN 2050 ELSE 0
        END;
        
        -- Log the upgrade
        INSERT INTO dc_heirloom_upgrade_log
            (item_guid, player_guid, package_id, from_level, to_level, essence_cost)
        VALUES
            (p_item_guid, p_player_guid, v_package_id, v_current_level, v_current_level + 1, v_upgrade_cost);
        
        -- Update package level
        UPDATE dc_heirloom_player_packages
        SET package_level = package_level + 1,
            essence_invested = essence_invested + v_upgrade_cost
        WHERE item_guid = p_item_guid AND player_guid = p_player_guid;
        
        SET p_result_code = 1;
        SET p_new_level = v_current_level + 1;
        SET p_essence_cost = v_upgrade_cost;
        SET p_result_message = CONCAT('Upgraded to level ', v_current_level + 1, '!');
    END IF;
END//

DELIMITER ;


-- ═══════════════════════════════════════════════════════════════════════════════
-- SAMPLE DATA (for testing)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Uncomment to insert test data:
/*
INSERT INTO dc_heirloom_player_packages 
    (item_guid, player_guid, item_entry, package_id, package_level, essence_invested)
VALUES
    (12345, 1, 300365, 1, 5, 575),   -- Player 1, Fury package level 5
    (12346, 1, 300365, 5, 10, 2950), -- Player 1, Spellfire package level 10
    (12347, 2, 300365, 7, 3, 225);   -- Player 2, Bulwark package level 3
*/


-- ═══════════════════════════════════════════════════════════════════════════════
-- END OF CHARACTER DATABASE FILE
-- ═══════════════════════════════════════════════════════════════════════════════
