-- ============================================================================
-- DC Collection System - World Database Tables
-- ============================================================================
-- Version: 2.0.0
-- Author: DarkChaos-255
-- Updated: Copilot
-- Description:
--   Keeps the existing per-type definition tables and adds the generic tables
--   used by the C++ handler:
--   - dc_collection_definitions (totals + optional unified definitions)
--   - dc_collection_shop (schema expected by dc_addon_collection.cpp)
-- ============================================================================

-- ============================================================================
-- GENERIC COLLECTION DEFINITIONS (used for totals)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_collection_definitions` (
    `collection_type` TINYINT UNSIGNED NOT NULL COMMENT '1=mount,2=pet,3=toy,4=heirloom,5=title,6=transmog',
    `entry_id` INT UNSIGNED NOT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`collection_type`, `entry_id`),
    KEY `idx_enabled` (`collection_type`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Generic collection definition index';

-- ============================================================================
-- MOUNT DEFINITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_mount_definitions` (
    `spell_id` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Mount spell ID',
    `name` VARCHAR(100) NOT NULL COMMENT 'Mount name',
    `mount_type` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=ground, 1=flying, 2=aquatic, 3=all',
    `source` TEXT DEFAULT NULL COMMENT 'JSON source info',
    `faction` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=both, 1=alliance, 2=horde',
    `class_mask` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=all, else class bitmask',
    `display_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `icon` VARCHAR(255) DEFAULT '' COMMENT 'Icon path override',
    `rarity` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=common, 1=uncommon, 2=rare, 3=epic, 4=legendary',
    `speed` SMALLINT UNSIGNED NOT NULL DEFAULT 100 COMMENT 'Speed percentage',
    `expansion` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '0=vanilla, 1=tbc, 2=wotlk',
    `is_tradeable` TINYINT(1) NOT NULL DEFAULT 0,
    `profession_required` TINYINT UNSIGNED DEFAULT NULL,
    `skill_required` SMALLINT UNSIGNED DEFAULT NULL,
    `flags` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Custom flags',
    KEY `idx_mount_type` (`mount_type`),
    KEY `idx_rarity` (`rarity`),
    KEY `idx_faction` (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Mount definitions';

-- ============================================================================
-- PET DEFINITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_pet_definitions` (
    `pet_entry` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Pet entry or spell ID',
    `name` VARCHAR(100) NOT NULL,
    `pet_type` ENUM('companion', 'minipet') NOT NULL DEFAULT 'companion',
    `pet_spell_id` INT UNSIGNED DEFAULT NULL COMMENT 'Summon spell if different',
    `source` TEXT DEFAULT NULL COMMENT 'JSON source info',
    `faction` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `display_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `icon` VARCHAR(255) DEFAULT '',
    `rarity` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `expansion` TINYINT UNSIGNED NOT NULL DEFAULT 2,
    `flags` INT UNSIGNED NOT NULL DEFAULT 0,
    KEY `idx_rarity` (`rarity`),
    KEY `idx_faction` (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Pet definitions';

-- ============================================================================
-- TOY DEFINITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_toy_definitions` (
    `item_id` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Toy item ID',
    `name` VARCHAR(100) NOT NULL,
    `category` VARCHAR(50) DEFAULT 'General',
    `source` TEXT DEFAULT NULL COMMENT 'JSON source info',
    `cooldown` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Cooldown in seconds',
    `icon` VARCHAR(255) DEFAULT '',
    `rarity` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `expansion` TINYINT UNSIGNED NOT NULL DEFAULT 2,
    `flags` INT UNSIGNED NOT NULL DEFAULT 0,
    KEY `idx_category` (`category`),
    KEY `idx_rarity` (`rarity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Toy definitions';

-- ============================================================================
-- HEIRLOOM DEFINITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_heirloom_definitions` (
    `item_id` INT UNSIGNED NOT NULL PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `slot` TINYINT UNSIGNED NOT NULL COMMENT 'Equipment slot',
    `armor_type` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=misc, 1=cloth, 2=leather, 3=mail, 4=plate',
    `max_upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 3,
    `scaling_type` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `icon` VARCHAR(255) DEFAULT '',
    `source` TEXT DEFAULT NULL,
    KEY `idx_slot` (`slot`),
    KEY `idx_armor_type` (`armor_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Heirloom definitions';

-- ============================================================================
-- COLLECTION SHOP (schema used by dc_addon_collection.cpp)
-- ============================================================================

DROP TABLE IF EXISTS `dc_collection_shop`;

CREATE TABLE `dc_collection_shop` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `collection_type` TINYINT UNSIGNED NOT NULL COMMENT '1..6 (see dc_collection_items.collection_type)',
    `entry_id` INT UNSIGNED NOT NULL,
    `price_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
    `price_emblems` INT UNSIGNED NOT NULL DEFAULT 0,
    `discount_percent` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `available_from` DATETIME DEFAULT NULL,
    `available_until` DATETIME DEFAULT NULL,
    `stock_remaining` INT DEFAULT NULL COMMENT 'NULL or <0 for unlimited',
    `featured` TINYINT(1) NOT NULL DEFAULT 0,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    KEY `idx_enabled_time` (`enabled`, `available_from`, `available_until`),
    KEY `idx_type` (`collection_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Collection shop (generic)';

-- ============================================================================
-- COLLECTION ACHIEVEMENT DEFINITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_collection_achievement_defs` (
    `achievement_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `description` TEXT,
    `collection_type` ENUM('mount', 'pet', 'toy', 'transmog', 'title', 'heirloom', 'total') NOT NULL,
    `required_count` INT UNSIGNED NOT NULL,
    `reward_type` ENUM('title', 'mount', 'pet', 'item', 'currency', 'spell') DEFAULT NULL,
    `reward_id` INT UNSIGNED DEFAULT NULL,
    `reward_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
    `reward_emblems` INT UNSIGNED NOT NULL DEFAULT 0,
    `icon` VARCHAR(255) DEFAULT NULL,
    `points` INT UNSIGNED NOT NULL DEFAULT 10,
    `sort_order` INT UNSIGNED NOT NULL DEFAULT 0,
    KEY `idx_type` (`collection_type`),
    KEY `idx_count` (`required_count`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Collection achievement definitions';

-- ============================================================================
-- MOUNT SPEED SPELL ENTRIES
-- ============================================================================
-- These need to be added to spell_dbc for the mount speed system

-- Note: Add these via a separate DBC loader or spell_dbc_template table
-- SPELL_COLLECTOR_MOUNT_SPEED_1 = 300510 (+2%)
-- SPELL_COLLECTOR_MOUNT_SPEED_2 = 300511 (+3%)
-- SPELL_COLLECTOR_MOUNT_SPEED_3 = 300512 (+3%)
-- SPELL_COLLECTOR_MOUNT_SPEED_4 = 300513 (+2%)

-- NOTE:
-- Sample shop data from v1 was removed because it used an incompatible schema.
-- Insert rows into dc_collection_shop using (collection_type, entry_id, prices).

-- ============================================================================
-- SAMPLE DATA: COLLECTION ACHIEVEMENTS
-- ============================================================================

INSERT INTO `dc_collection_achievement_defs`
(`name`, `description`, `collection_type`, `required_count`, `reward_tokens`, `reward_emblems`, `icon`, `points`, `sort_order`) VALUES

-- Mount achievements
('Stable Keeper', 'Collect 10 mounts.', 'mount', 10, 100, 0, 'Interface\\Icons\\Ability_Mount_RidingHorse', 10, 10),
('Mount Enthusiast', 'Collect 25 mounts.', 'mount', 25, 250, 5, 'Interface\\Icons\\Ability_Mount_Kodo_01', 10, 20),
('Stable Master', 'Collect 50 mounts.', 'mount', 50, 500, 10, 'Interface\\Icons\\Ability_Mount_Drake_Blue', 10, 30),
('Mount Collector', 'Collect 100 mounts.', 'mount', 100, 1000, 25, 'Interface\\Icons\\Ability_Mount_Drake_Proto', 25, 40),
('Lord of Reins', 'Collect 150 mounts.', 'mount', 150, 2000, 50, 'Interface\\Icons\\Ability_Mount_Drake_Twilight', 50, 50),

-- Pet achievements
('Pet Owner', 'Collect 10 companion pets.', 'pet', 10, 100, 0, 'Interface\\Icons\\INV_Box_PetCarrier_01', 10, 110),
('Pet Collector', 'Collect 25 companion pets.', 'pet', 25, 250, 5, 'Interface\\Icons\\INV_Pet_BabyBlizzardBear', 10, 120),
('Crazy Cat Person', 'Collect 50 companion pets.', 'pet', 50, 500, 10, 'Interface\\Icons\\Spell_Shadow_SummonFelHunter', 10, 130),

-- Total collection achievements
('Collector', 'Collect 50 total items across all categories.', 'total', 50, 500, 10, 'Interface\\Icons\\INV_Misc_Coin_02', 10, 200),
('Hoarder', 'Collect 100 total items across all categories.', 'total', 100, 1000, 25, 'Interface\\Icons\\INV_Misc_Coin_03', 25, 210),
('Master Collector', 'Collect 200 total items across all categories.', 'total', 200, 2000, 50, 'Interface\\Icons\\INV_Misc_Coin_04', 50, 220);

-- ============================================================================
-- AUTO-POPULATE MOUNT DEFINITIONS (run this to import from loot tables)
-- ============================================================================

-- Create view for mount items
CREATE OR REPLACE VIEW `v_mount_items` AS
SELECT i.entry AS item_id, i.name AS item_name, i.spellid_1 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
FROM item_template i
WHERE i.class = 15 AND i.subclass = 5 AND i.spellid_1 > 0
UNION ALL
SELECT i.entry AS item_id, i.name AS item_name, i.spellid_2 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
FROM item_template i
WHERE i.class = 15 AND i.subclass = 5 AND i.spellid_2 > 0
UNION ALL
SELECT i.entry AS item_id, i.name AS item_name, i.spellid_3 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
FROM item_template i
WHERE i.class = 15 AND i.subclass = 5 AND i.spellid_3 > 0
UNION ALL
SELECT i.entry AS item_id, i.name AS item_name, i.spellid_4 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
FROM item_template i
WHERE i.class = 15 AND i.subclass = 5 AND i.spellid_4 > 0
UNION ALL
SELECT i.entry AS item_id, i.name AS item_name, i.spellid_5 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
FROM item_template i
WHERE i.class = 15 AND i.subclass = 5 AND i.spellid_5 > 0;

-- Create view for pet items
CREATE OR REPLACE VIEW `v_pet_items` AS
SELECT i.entry AS item_id, i.name AS item_name, i.spellid_1 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
FROM item_template i
WHERE i.class = 15 AND i.subclass = 2 AND i.spellid_1 > 0
UNION ALL
SELECT i.entry AS item_id, i.name AS item_name, i.spellid_2 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
FROM item_template i
WHERE i.class = 15 AND i.subclass = 2 AND i.spellid_2 > 0
UNION ALL
SELECT i.entry AS item_id, i.name AS item_name, i.spellid_3 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
FROM item_template i
WHERE i.class = 15 AND i.subclass = 2 AND i.spellid_3 > 0
UNION ALL
SELECT i.entry AS item_id, i.name AS item_name, i.spellid_4 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
FROM item_template i
WHERE i.class = 15 AND i.subclass = 2 AND i.spellid_4 > 0
UNION ALL
SELECT i.entry AS item_id, i.name AS item_name, i.spellid_5 AS spell_id, i.Quality AS rarity, i.displayid AS display_id
FROM item_template i
WHERE i.class = 15 AND i.subclass = 2 AND i.spellid_5 > 0;

-- Create view for heirloom items
CREATE OR REPLACE VIEW `v_heirloom_items` AS
SELECT 
    i.entry AS item_id,
    i.name AS item_name,
    i.Quality AS rarity,
    i.InventoryType AS slot,
    i.subclass AS armor_type,
    i.displayid AS display_id
FROM item_template i
WHERE i.Quality = 7;  -- ITEM_QUALITY_HEIRLOOM

-- ============================================================================
-- STORED PROCEDURE: Auto-populate mount definitions from item_template
-- ============================================================================

DROP PROCEDURE IF EXISTS `PopulateMountDefinitions`;
DROP PROCEDURE IF EXISTS `PopulatePetDefinitions`;
DROP PROCEDURE IF EXISTS `PopulateHeirloomDefinitions`;
DROP PROCEDURE IF EXISTS `PopulateMountSourcesFromLoot`;

DELIMITER //

CREATE PROCEDURE `PopulateMountDefinitions`()
BEGIN
    -- Insert mounts from item_template that aren't already defined
    INSERT IGNORE INTO dc_mount_definitions (spell_id, name, rarity, display_id, source)
    SELECT 
        m.spell_id,
        m.item_name,
        m.rarity,
        m.display_id,
        JSON_OBJECT('type', 'unknown', 'item_id', m.item_id)
    FROM v_mount_items m
    WHERE m.spell_id NOT IN (SELECT spell_id FROM dc_mount_definitions);
    
    SELECT ROW_COUNT() AS mounts_added;
END //

CREATE PROCEDURE `PopulatePetDefinitions`()
BEGIN
    INSERT IGNORE INTO dc_pet_definitions (pet_entry, name, pet_spell_id, rarity, display_id, source)
    SELECT 
        p.item_id,
        p.item_name,
        p.spell_id,
        p.rarity,
        p.display_id,
        JSON_OBJECT('type', 'unknown', 'item_id', p.item_id)
    FROM v_pet_items p
    WHERE p.item_id NOT IN (SELECT pet_entry FROM dc_pet_definitions);
    
    SELECT ROW_COUNT() AS pets_added;
END //

CREATE PROCEDURE `PopulateHeirloomDefinitions`()
BEGIN
    INSERT IGNORE INTO dc_heirloom_definitions (item_id, name, slot, armor_type)
    SELECT 
        h.item_id,
        h.item_name,
        h.slot,
        h.armor_type
    FROM v_heirloom_items h
    WHERE h.item_id NOT IN (SELECT item_id FROM dc_heirloom_definitions);
    
    SELECT ROW_COUNT() AS heirlooms_added;
END //

-- Populate source info from loot tables
CREATE PROCEDURE `PopulateMountSourcesFromLoot`()
BEGIN
    -- Update mount sources from creature loot
    UPDATE dc_mount_definitions md
    JOIN (
        SELECT 
            mi.spell_id,
            JSON_OBJECT(
                'type', 'drop',
                -- Pick a representative boss for this spell_id.
                -- Aggregation avoids ONLY_FULL_GROUP_BY issues.
                'boss', MIN(ct.name),
                'dropRate', ROUND(MAX(clt.Chance), 1),
                'creature_entry', MIN(ct.entry)
            ) AS source_json
        FROM v_mount_items mi
        JOIN creature_loot_template clt ON clt.Item = mi.item_id
        JOIN creature_template ct ON ct.lootid = clt.Entry
        WHERE ct.rank >= 3 OR (ct.unit_flags & 32768) > 0  -- Boss flag
        GROUP BY mi.spell_id
    ) src ON md.spell_id = src.spell_id
    SET md.source = src.source_json
    WHERE md.source IS NULL OR JSON_EXTRACT(md.source, '$.type') = 'unknown';
    
    -- Update mount sources from vendors
    UPDATE dc_mount_definitions md
    JOIN (
        SELECT 
            mi.spell_id,
            JSON_OBJECT(
                'type', 'vendor',
                -- Pick a representative vendor for this spell_id.
                'npc', MIN(ct.name),
                'cost', MIN(i.BuyPrice)
            ) AS source_json
        FROM v_mount_items mi
        JOIN item_template i ON i.entry = mi.item_id
        JOIN npc_vendor nv ON nv.item = mi.item_id
        JOIN creature_template ct ON ct.entry = nv.entry
        GROUP BY mi.spell_id
    ) src ON md.spell_id = src.spell_id
    SET md.source = src.source_json
    WHERE md.source IS NULL OR JSON_EXTRACT(md.source, '$.type') = 'unknown';
    
    SELECT 'Mount sources updated' AS status;
END //

DELIMITER ;

-- ============================================================================
-- POPULATE DEFINITIONS (runs once, safe to re-run)
-- ============================================================================
-- This file defines the population stored procedures above, but procedures do
-- not run automatically just because they exist. These CALLs will actually
-- populate/refresh the tables right after import.

CALL PopulateMountDefinitions();
CALL PopulatePetDefinitions();
CALL PopulateHeirloomDefinitions();
CALL PopulateMountSourcesFromLoot();
