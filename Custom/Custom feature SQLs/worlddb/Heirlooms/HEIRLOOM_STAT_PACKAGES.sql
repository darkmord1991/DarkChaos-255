-- ═══════════════════════════════════════════════════════════════════════════════
-- HEIRLOOM SECONDARY STAT PACKAGE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- OVERVIEW:
-- Players choose a "package" of 2-3 secondary stats for their heirloom items.
-- Each package has 15 upgrade levels (matching the standard upgrade system).
-- Stats in the package scale together as the player upgrades.
--
-- PACKAGES AVAILABLE (12 total):
-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ ID │ Name        │ Stat 1     │ Stat 2     │ Stat 3      │ Best For        │
-- ├────┼─────────────┼────────────┼────────────┼─────────────┼─────────────────┤
-- │ 1  │ Fury        │ Crit       │ Haste      │ -           │ Melee DPS       │
-- │ 2  │ Precision   │ Hit        │ Expertise  │ -           │ Melee DPS       │
-- │ 3  │ Devastation │ Crit       │ Armor Pen  │ -           │ Physical DPS    │
-- │ 4  │ Swiftblade  │ Haste      │ Armor Pen  │ -           │ Fast attackers  │
-- │ 5  │ Spellfire   │ Crit       │ Haste      │ Spell Power │ Caster DPS      │
-- │ 6  │ Arcane      │ Hit        │ Haste      │ Spell Power │ Caster DPS      │
-- │ 7  │ Bulwark     │ Dodge      │ Parry      │ Block       │ Tank avoidance  │
-- │ 8  │ Fortress    │ Defense    │ Block      │ Stamina     │ Tank mitigation │
-- │ 9  │ Survivor    │ Dodge      │ Stamina    │ -           │ Druid/DK Tank   │
-- │ 10 │ Gladiator   │ Resilience │ Crit       │ -           │ PvP Offense     │
-- │ 11 │ Warlord     │ Resilience │ Stamina    │ -           │ PvP Defense     │
-- │ 12 │ Balanced    │ Crit       │ Hit        │ Haste       │ All-rounder     │
-- └─────────────────────────────────────────────────────────────────────────────┘
--
-- STAT TYPE IDs (from ItemModType enum):
--   3  = ITEM_MOD_AGILITY
--   4  = ITEM_MOD_STRENGTH
--   5  = ITEM_MOD_INTELLECT
--   6  = ITEM_MOD_SPIRIT
--   7  = ITEM_MOD_STAMINA
--   12 = ITEM_MOD_DEFENSE_SKILL_RATING
--   13 = ITEM_MOD_DODGE_RATING
--   14 = ITEM_MOD_PARRY_RATING
--   15 = ITEM_MOD_BLOCK_RATING
--   31 = ITEM_MOD_HIT_RATING
--   32 = ITEM_MOD_CRIT_RATING
--   35 = ITEM_MOD_RESILIENCE_RATING
--   36 = ITEM_MOD_HASTE_RATING
--   37 = ITEM_MOD_EXPERTISE_RATING
--   44 = ITEM_MOD_ARMOR_PENETRATION_RATING
--   45 = ITEM_MOD_SPELL_POWER
--
-- ═══════════════════════════════════════════════════════════════════════════════

USE acore_world;

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE 1: Package Definitions
-- ═══════════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS `dc_heirloom_stat_packages`;
CREATE TABLE `dc_heirloom_stat_packages` (
    `package_id` TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    `package_name` VARCHAR(32) NOT NULL,
    `description` VARCHAR(128) NOT NULL,
    `stat_type_1` TINYINT UNSIGNED NOT NULL COMMENT 'Primary stat type (ItemModType)',
    `stat_type_2` TINYINT UNSIGNED NOT NULL COMMENT 'Secondary stat type (ItemModType)',
    `stat_type_3` TINYINT UNSIGNED DEFAULT NULL COMMENT 'Tertiary stat type (optional)',
    `stat_weight_1` FLOAT NOT NULL DEFAULT 1.0 COMMENT 'Weight multiplier for stat 1',
    `stat_weight_2` FLOAT NOT NULL DEFAULT 1.0 COMMENT 'Weight multiplier for stat 2',
    `stat_weight_3` FLOAT NOT NULL DEFAULT 0.5 COMMENT 'Weight multiplier for stat 3 (if exists)',
    `icon_id` INT UNSIGNED DEFAULT 0 COMMENT 'Icon display ID for addon',
    `recommended_classes` VARCHAR(64) DEFAULT NULL COMMENT 'Recommended class mask or names',
    `is_enabled` BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Heirloom secondary stat package definitions';

-- Insert package definitions
INSERT INTO `dc_heirloom_stat_packages` 
    (`package_id`, `package_name`, `description`, `stat_type_1`, `stat_type_2`, `stat_type_3`, `stat_weight_1`, `stat_weight_2`, `stat_weight_3`, `recommended_classes`) 
VALUES
    -- DPS Packages
    (1,  'Fury',        'Critical Strike + Haste for aggressive melee DPS',           32, 36, NULL, 1.0, 1.0, 0.0, 'Warrior, Rogue, DK, Paladin'),
    (2,  'Precision',   'Hit + Expertise for reliable damage output',                 31, 37, NULL, 1.0, 1.0, 0.0, 'All melee'),
    (3,  'Devastation', 'Critical Strike + Armor Penetration for burst damage',       32, 44, NULL, 1.0, 1.0, 0.0, 'Warrior, Rogue, Hunter'),
    (4,  'Swiftblade',  'Haste + Armor Penetration for fast sustained damage',        36, 44, NULL, 1.0, 1.0, 0.0, 'Rogue, Feral Druid'),
    
    -- Caster Packages
    (5,  'Spellfire',   'Critical Strike + Haste + Spell Power for caster DPS',       32, 36, 45,  1.0, 1.0, 0.5, 'Mage, Warlock, Elemental'),
    (6,  'Arcane',      'Hit + Haste + Spell Power for spell hit cap focus',          31, 36, 45,  1.0, 1.0, 0.5, 'All casters'),
    
    -- Tank Packages
    (7,  'Bulwark',     'Dodge + Parry + Block for maximum avoidance',                13, 14, 15,  1.0, 1.0, 0.5, 'Warrior, Paladin'),
    (8,  'Fortress',    'Defense + Block + Stamina for mitigation and health',        12, 15, 7,   1.0, 1.0, 0.5, 'Warrior, Paladin'),
    (9,  'Survivor',    'Dodge + Stamina for leather/plate tanks without block',      13, 7,  NULL, 1.0, 1.0, 0.0, 'Druid, DK'),
    
    -- PvP Packages
    (10, 'Gladiator',   'Resilience + Critical Strike for offensive PvP',             35, 32, NULL, 1.0, 1.0, 0.0, 'All DPS in PvP'),
    (11, 'Warlord',     'Resilience + Stamina for defensive PvP survival',            35, 7,  NULL, 1.0, 1.0, 0.0, 'Healers, Flag carriers'),
    
    -- Hybrid Package
    (12, 'Balanced',    'Critical Strike + Hit + Haste for flexible builds',          32, 31, 36,  1.0, 0.8, 0.8, 'All classes');


-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE 2: Package Level Scaling (15 levels)
-- ═══════════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS `dc_heirloom_package_levels`;
CREATE TABLE `dc_heirloom_package_levels` (
    `level` TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    `base_stat_value` INT UNSIGNED NOT NULL COMMENT 'Base stat value at this level (before weight)',
    `essence_cost` INT UNSIGNED NOT NULL COMMENT 'Essence cost to upgrade TO this level',
    `total_essence` INT UNSIGNED NOT NULL COMMENT 'Total essence invested at this level',
    `stat_multiplier` FLOAT NOT NULL COMMENT 'Display multiplier for progression feel'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Stat values and costs per upgrade level';

-- Stat scaling: roughly +30% per level with diminishing returns at high levels
-- Total cost to max: 10,000 essence (reasonable grind)
INSERT INTO `dc_heirloom_package_levels` (`level`, `base_stat_value`, `essence_cost`, `total_essence`, `stat_multiplier`) VALUES
    (1,   5,    50,    50,    1.00),   -- Entry level
    (2,   10,   75,    125,   1.15),
    (3,   16,   100,   225,   1.30),
    (4,   23,   150,   375,   1.45),
    (5,   31,   200,   575,   1.60),   -- Milestone 1
    (6,   40,   275,   850,   1.75),
    (7,   50,   350,   1200,  1.90),
    (8,   62,   450,   1650,  2.05),
    (9,   75,   575,   2225,  2.20),
    (10,  90,   725,   2950,  2.35),   -- Milestone 2 (halfway)
    (11,  107,  900,   3850,  2.50),
    (12,  126,  1100,  4950,  2.65),
    (13,  148,  1350,  6300,  2.80),
    (14,  172,  1650,  7950,  2.95),
    (15,  200,  2050,  10000, 3.10);   -- Maximum


-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE 3: Player Package Selections (Character Database)
-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTE: This table goes in acore_characters database!

-- Run this on acore_characters:
/*
USE acore_characters;

DROP TABLE IF EXISTS `dc_heirloom_player_packages`;
CREATE TABLE `dc_heirloom_player_packages` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `item_guid` INT UNSIGNED NOT NULL COMMENT 'Item instance GUID',
    `player_guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
    `package_id` TINYINT UNSIGNED NOT NULL COMMENT 'Chosen package (FK to dc_heirloom_stat_packages)',
    `package_level` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Current upgrade level (1-15)',
    `essence_invested` INT UNSIGNED NOT NULL DEFAULT 50 COMMENT 'Total essence spent',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY `unique_item` (`item_guid`),
    KEY `idx_player` (`player_guid`),
    KEY `idx_package` (`package_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player heirloom package selections and progress';
*/


-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE 4: DBC Enchantment ID Mapping
-- ═══════════════════════════════════════════════════════════════════════════════
-- Maps package_id + level to SpellItemEnchantment.dbc ID
-- Formula: 900000 + (package_id * 100) + level

DROP TABLE IF EXISTS `dc_heirloom_enchant_mapping`;
CREATE TABLE `dc_heirloom_enchant_mapping` (
    `package_id` TINYINT UNSIGNED NOT NULL,
    `level` TINYINT UNSIGNED NOT NULL,
    `enchant_id` INT UNSIGNED NOT NULL COMMENT 'SpellItemEnchantment.dbc ID',
    `stat_1_value` INT UNSIGNED NOT NULL,
    `stat_2_value` INT UNSIGNED NOT NULL,
    `stat_3_value` INT UNSIGNED DEFAULT NULL,
    `display_text` VARCHAR(128) NOT NULL COMMENT 'Tooltip text',
    
    PRIMARY KEY (`package_id`, `level`),
    KEY `idx_enchant` (`enchant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Mapping between packages and DBC enchant IDs';

-- Generate mappings for all 12 packages × 15 levels = 180 entries
-- Using a stored procedure for cleaner generation

DELIMITER //

DROP PROCEDURE IF EXISTS GenerateHeirloomEnchantMappings//

CREATE PROCEDURE GenerateHeirloomEnchantMappings()
BEGIN
    DECLARE pkg_id INT;
    DECLARE lvl INT;
    DECLARE base_val INT;
    DECLARE stat1_type INT;
    DECLARE stat2_type INT;
    DECLARE stat3_type INT;
    DECLARE weight1 FLOAT;
    DECLARE weight2 FLOAT;
    DECLARE weight3 FLOAT;
    DECLARE pkg_name VARCHAR(32);
    DECLARE stat1_val INT;
    DECLARE stat2_val INT;
    DECLARE stat3_val INT;
    DECLARE enc_id INT;
    DECLARE display_txt VARCHAR(128);
    
    -- Clear existing mappings
    TRUNCATE TABLE dc_heirloom_enchant_mapping;
    
    -- Loop through all packages
    SET pkg_id = 1;
    WHILE pkg_id <= 12 DO
        -- Get package definition
        SELECT package_name, stat_type_1, stat_type_2, stat_type_3, stat_weight_1, stat_weight_2, stat_weight_3
        INTO pkg_name, stat1_type, stat2_type, stat3_type, weight1, weight2, weight3
        FROM dc_heirloom_stat_packages
        WHERE package_id = pkg_id;
        
        -- Loop through all levels
        SET lvl = 1;
        WHILE lvl <= 15 DO
            -- Get base value for this level
            SELECT base_stat_value INTO base_val
            FROM dc_heirloom_package_levels
            WHERE level = lvl;
            
            -- Calculate stat values
            SET stat1_val = ROUND(base_val * weight1);
            SET stat2_val = ROUND(base_val * weight2);
            SET stat3_val = IF(stat3_type IS NOT NULL, ROUND(base_val * weight3), NULL);
            
            -- Calculate enchant ID: 900000 + (pkg_id * 100) + level
            SET enc_id = 900000 + (pkg_id * 100) + lvl;
            
            -- Build display text
            SET display_txt = CONCAT(pkg_name, ' ', lvl, '/15');
            
            -- Insert mapping
            INSERT INTO dc_heirloom_enchant_mapping 
                (package_id, level, enchant_id, stat_1_value, stat_2_value, stat_3_value, display_text)
            VALUES 
                (pkg_id, lvl, enc_id, stat1_val, stat2_val, stat3_val, display_txt);
            
            SET lvl = lvl + 1;
        END WHILE;
        
        SET pkg_id = pkg_id + 1;
    END WHILE;
END//

DELIMITER ;

-- Execute the procedure
CALL GenerateHeirloomEnchantMappings();

-- Verify the mappings
SELECT 
    p.package_name,
    m.level,
    m.enchant_id,
    m.stat_1_value AS 'Stat1',
    m.stat_2_value AS 'Stat2',
    m.stat_3_value AS 'Stat3',
    m.display_text
FROM dc_heirloom_enchant_mapping m
JOIN dc_heirloom_stat_packages p ON m.package_id = p.package_id
ORDER BY m.package_id, m.level;


-- ═══════════════════════════════════════════════════════════════════════════════
-- EXAMPLE: What the Fury Package looks like at each level
-- ═══════════════════════════════════════════════════════════════════════════════
/*
SELECT 
    CONCAT('Fury Level ', m.level) AS 'Package',
    CONCAT('+', m.stat_1_value, ' Crit') AS 'Stat 1',
    CONCAT('+', m.stat_2_value, ' Haste') AS 'Stat 2',
    CONCAT(l.essence_cost, ' Essence') AS 'Cost',
    CONCAT(l.total_essence, ' Total') AS 'Invested'
FROM dc_heirloom_enchant_mapping m
JOIN dc_heirloom_package_levels l ON m.level = l.level
WHERE m.package_id = 1
ORDER BY m.level;

Expected output:
+----------------+-----------+-----------+---------------+-----------+
| Package        | Stat 1    | Stat 2    | Cost          | Invested  |
+----------------+-----------+-----------+---------------+-----------+
| Fury Level 1   | +5 Crit   | +5 Haste  | 50 Essence    | 50 Total  |
| Fury Level 2   | +10 Crit  | +10 Haste | 75 Essence    | 125 Total |
| Fury Level 3   | +16 Crit  | +16 Haste | 100 Essence   | 225 Total |
| ...            | ...       | ...       | ...           | ...       |
| Fury Level 15  | +200 Crit | +200 Haste| 2050 Essence  | 10000 Total|
+----------------+-----------+-----------+---------------+-----------+
*/


-- ═══════════════════════════════════════════════════════════════════════════════
-- HELPER VIEWS
-- ═══════════════════════════════════════════════════════════════════════════════

-- View: Complete package info with stat names
DROP VIEW IF EXISTS `v_heirloom_packages_detailed`;
CREATE VIEW `v_heirloom_packages_detailed` AS
SELECT 
    p.package_id,
    p.package_name,
    p.description,
    CASE p.stat_type_1
        WHEN 7 THEN 'Stamina' WHEN 12 THEN 'Defense' WHEN 13 THEN 'Dodge'
        WHEN 14 THEN 'Parry' WHEN 15 THEN 'Block' WHEN 31 THEN 'Hit'
        WHEN 32 THEN 'Crit' WHEN 35 THEN 'Resilience' WHEN 36 THEN 'Haste'
        WHEN 37 THEN 'Expertise' WHEN 44 THEN 'Armor Pen' WHEN 45 THEN 'Spell Power'
        ELSE CONCAT('Stat ', p.stat_type_1)
    END AS stat_1_name,
    CASE p.stat_type_2
        WHEN 7 THEN 'Stamina' WHEN 12 THEN 'Defense' WHEN 13 THEN 'Dodge'
        WHEN 14 THEN 'Parry' WHEN 15 THEN 'Block' WHEN 31 THEN 'Hit'
        WHEN 32 THEN 'Crit' WHEN 35 THEN 'Resilience' WHEN 36 THEN 'Haste'
        WHEN 37 THEN 'Expertise' WHEN 44 THEN 'Armor Pen' WHEN 45 THEN 'Spell Power'
        ELSE CONCAT('Stat ', p.stat_type_2)
    END AS stat_2_name,
    CASE p.stat_type_3
        WHEN 7 THEN 'Stamina' WHEN 12 THEN 'Defense' WHEN 13 THEN 'Dodge'
        WHEN 14 THEN 'Parry' WHEN 15 THEN 'Block' WHEN 31 THEN 'Hit'
        WHEN 32 THEN 'Crit' WHEN 35 THEN 'Resilience' WHEN 36 THEN 'Haste'
        WHEN 37 THEN 'Expertise' WHEN 44 THEN 'Armor Pen' WHEN 45 THEN 'Spell Power'
        WHEN NULL THEN NULL
        ELSE CONCAT('Stat ', p.stat_type_3)
    END AS stat_3_name,
    p.recommended_classes
FROM dc_heirloom_stat_packages p
WHERE p.is_enabled = TRUE;


-- ═══════════════════════════════════════════════════════════════════════════════
-- END OF FILE
-- ═══════════════════════════════════════════════════════════════════════════════
