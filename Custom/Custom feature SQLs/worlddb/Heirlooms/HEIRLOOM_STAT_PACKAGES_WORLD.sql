-- ═══════════════════════════════════════════════════════════════════════════════
-- HEIRLOOM SECONDARY STAT PACKAGE SYSTEM - WORLD DATABASE
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- FILE: HEIRLOOM_STAT_PACKAGES_WORLD.sql
-- DATABASE: acore_world
-- 
-- OVERVIEW:
-- Players choose a "package" of 2-3 secondary stats for their heirloom items.
-- Each package has 15 upgrade levels (matching the standard upgrade system).
-- Stats in the package scale together as the player upgrades.
--
-- RELATED FILES:
-- - HEIRLOOM_STAT_PACKAGES_CHARS.sql (character database tables)
-- - HEIRLOOM_SHIRT_PRIMARY_STATS.sql (item template updates)
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
    `package_icon` VARCHAR(64) NOT NULL DEFAULT 'Interface\\Icons\\INV_Misc_QuestionMark' COMMENT 'Icon path for addon',
    `description` VARCHAR(255) NOT NULL,
    `stat_type_1` TINYINT UNSIGNED NOT NULL COMMENT 'Primary stat type (ItemModType)',
    `stat_type_2` TINYINT UNSIGNED NOT NULL COMMENT 'Secondary stat type (ItemModType)',
    `stat_type_3` TINYINT UNSIGNED DEFAULT NULL COMMENT 'Tertiary stat type (optional)',
    `stat_weight_1` FLOAT NOT NULL DEFAULT 1.0 COMMENT 'Weight multiplier for stat 1',
    `stat_weight_2` FLOAT NOT NULL DEFAULT 1.0 COMMENT 'Weight multiplier for stat 2',
    `stat_weight_3` FLOAT NOT NULL DEFAULT 0.5 COMMENT 'Weight multiplier for stat 3 (if exists)',
    `color_r` TINYINT UNSIGNED DEFAULT 255 COMMENT 'Package color red component',
    `color_g` TINYINT UNSIGNED DEFAULT 255 COMMENT 'Package color green component',
    `color_b` TINYINT UNSIGNED DEFAULT 255 COMMENT 'Package color blue component',
    `recommended_classes` VARCHAR(128) DEFAULT NULL COMMENT 'Recommended class names',
    `recommended_specs` VARCHAR(128) DEFAULT NULL COMMENT 'Recommended spec names',
    `sort_order` TINYINT UNSIGNED DEFAULT 0 COMMENT 'Display order in addon',
    `is_enabled` BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Heirloom secondary stat package definitions';

-- Insert package definitions with icons and colors
INSERT INTO `dc_heirloom_stat_packages` 
    (`package_id`, `package_name`, `package_icon`, `description`, 
     `stat_type_1`, `stat_type_2`, `stat_type_3`, 
     `stat_weight_1`, `stat_weight_2`, `stat_weight_3`,
     `color_r`, `color_g`, `color_b`,
     `recommended_classes`, `recommended_specs`, `sort_order`) 
VALUES
    -- DPS Packages (sort 1-4)
    (1,  'Fury',        'Interface\\Icons\\Ability_Warrior_Rampage',
         'Critical Strike + Haste for aggressive damage dealing. Best for warriors, rogues, and death knights who want maximum burst potential.',
         32, 36, NULL, 1.0, 1.0, 0.0,
         255, 100, 100,
         'Warrior, Rogue, Death Knight, Paladin, Hunter', 'Arms, Fury, Combat, Assassination, Unholy, Frost DK, Retribution', 1),
         
    (2,  'Precision',   'Interface\\Icons\\Ability_Marksmanship',
         'Hit + Expertise for reliable damage output. Ensures your attacks always land. Essential for raid DPS optimization.',
         31, 37, NULL, 1.0, 1.0, 0.0,
         255, 200, 100,
         'All Melee DPS', 'All melee specs until hit/expertise capped', 2),
         
    (3,  'Devastation', 'Interface\\Icons\\Ability_Warrior_BloodFrenzy',
         'Critical Strike + Armor Penetration for devastating physical damage. Ignores enemy armor for brutal efficiency.',
         32, 44, NULL, 1.0, 1.0, 0.0,
         200, 50, 50,
         'Warrior, Rogue, Hunter, Feral Druid', 'Arms, Fury, Combat, Marksmanship, Survival, Feral', 3),
         
    (4,  'Swiftblade',  'Interface\\Icons\\Ability_Rogue_SliceDice',
         'Haste + Armor Penetration for rapid sustained damage. Attack faster while shredding through armor.',
         36, 44, NULL, 1.0, 1.0, 0.0,
         100, 255, 100,
         'Rogue, Feral Druid, Enhancement Shaman', 'Combat, Assassination, Feral, Enhancement', 4),
    
    -- Caster Packages (sort 5-6)
    (5,  'Spellfire',   'Interface\\Icons\\Spell_Fire_FlameBolt',
         'Critical Strike + Haste + Spell Power for explosive caster DPS. Bigger crits, faster casts, more power.',
         32, 36, 45, 1.0, 1.0, 0.5,
         255, 150, 50,
         'Mage, Warlock, Elemental Shaman, Balance Druid, Shadow Priest', 'Fire, Arcane, Frost Mage, Affliction, Destruction, Demonology, Elemental, Balance, Shadow', 5),
         
    (6,  'Arcane',      'Interface\\Icons\\Spell_Arcane_Blast',
         'Hit + Haste + Spell Power for spell hit cap focus. Never miss a spell while casting faster.',
         31, 36, 45, 1.0, 1.0, 0.5,
         150, 150, 255,
         'All Casters', 'All caster specs until spell hit capped', 6),
    
    -- Tank Packages (sort 7-9)
    (7,  'Bulwark',     'Interface\\Icons\\Ability_Defend',
         'Dodge + Parry + Block for maximum avoidance. Become untouchable through pure evasion.',
         13, 14, 15, 1.0, 1.0, 0.5,
         100, 100, 255,
         'Warrior, Paladin', 'Protection Warrior, Protection Paladin', 7),
         
    (8,  'Fortress',    'Interface\\Icons\\Spell_Holy_DevineAegis',
         'Defense + Block + Stamina for mitigation and health. Take less damage and survive bigger hits.',
         12, 15, 7, 1.0, 1.0, 0.5,
         150, 200, 255,
         'Warrior, Paladin', 'Protection Warrior, Protection Paladin', 8),
         
    (9,  'Survivor',    'Interface\\Icons\\Ability_Druid_Enrage',
         'Dodge + Stamina for leather/plate tanks. Perfect for bear druids and death knights without block.',
         13, 7, NULL, 1.0, 1.0, 0.0,
         100, 200, 100,
         'Druid, Death Knight', 'Feral (Bear), Blood, Frost Tank', 9),
    
    -- PvP Packages (sort 10-11)
    (10, 'Gladiator',   'Interface\\Icons\\Achievement_Arena_2v2_7',
         'Resilience + Critical Strike for offensive PvP. Survive while dealing devastating crits.',
         35, 32, NULL, 1.0, 1.0, 0.0,
         255, 50, 255,
         'All DPS Classes', 'All DPS specs in PvP', 10),
         
    (11, 'Warlord',     'Interface\\Icons\\Achievement_Arena_3v3_7',
         'Resilience + Stamina for defensive PvP survival. Become nearly unkillable in battlegrounds and arenas.',
         35, 7, NULL, 1.0, 1.0, 0.0,
         200, 100, 255,
         'Healers, Flag Carriers, Tanks', 'All healers, Protection specs, Feral Bear', 11),
    
    -- Hybrid Package (sort 12)
    (12, 'Balanced',    'Interface\\Icons\\INV_Misc_Gem_Variety_02',
         'Critical Strike + Hit + Haste for flexible builds. A well-rounded package that works for any situation.',
         32, 31, 36, 1.0, 0.8, 0.8,
         255, 255, 150,
         'All Classes', 'All specs - great for leveling and general use', 12);


-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE 2: Package Level Scaling (15 levels)
-- ═══════════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS `dc_heirloom_package_levels`;
CREATE TABLE `dc_heirloom_package_levels` (
    `level` TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    `base_stat_value` INT UNSIGNED NOT NULL COMMENT 'Base stat value at this level (before weight)',
    `essence_cost` INT UNSIGNED NOT NULL COMMENT 'Essence cost to upgrade TO this level',
    `total_essence` INT UNSIGNED NOT NULL COMMENT 'Total essence invested at this level',
    `stat_multiplier` FLOAT NOT NULL COMMENT 'Display multiplier for progression feel',
    `milestone_name` VARCHAR(32) DEFAULT NULL COMMENT 'Special name for milestone levels'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Stat values and costs per upgrade level';

-- Stat scaling: roughly +30% per level with diminishing returns at high levels
-- Total cost to max: 10,000 essence (reasonable grind)
INSERT INTO `dc_heirloom_package_levels` (`level`, `base_stat_value`, `essence_cost`, `total_essence`, `stat_multiplier`, `milestone_name`) VALUES
    (1,   5,    50,    50,    1.00,  'Initiate'),
    (2,   10,   75,    125,   1.15,  NULL),
    (3,   16,   100,   225,   1.30,  NULL),
    (4,   23,   150,   375,   1.45,  NULL),
    (5,   31,   200,   575,   1.60,  'Adept'),
    (6,   40,   275,   850,   1.75,  NULL),
    (7,   50,   350,   1200,  1.90,  NULL),
    (8,   62,   450,   1650,  2.05,  NULL),
    (9,   75,   575,   2225,  2.20,  NULL),
    (10,  90,   725,   2950,  2.35,  'Expert'),
    (11,  107,  900,   3850,  2.50,  NULL),
    (12,  126,  1100,  4950,  2.65,  NULL),
    (13,  148,  1350,  6300,  2.80,  NULL),
    (14,  172,  1650,  7950,  2.95,  NULL),
    (15,  200,  2050,  10000, 3.10,  'Master');


-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE 3: DBC Enchantment ID Mapping
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


-- ═══════════════════════════════════════════════════════════════════════════════
-- PROCEDURE: Generate all enchantment mappings
-- ═══════════════════════════════════════════════════════════════════════════════

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

-- Execute the procedure to generate mappings
CALL GenerateHeirloomEnchantMappings();


-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE 4: Heirloom Upgrade Costs (C++ Handler Compatible)
-- ═══════════════════════════════════════════════════════════════════════════════
-- This table is used by the C++ .dcheirloom command handler to determine costs
-- Uses the same token/essence currency system as the main item upgrade system

DROP TABLE IF EXISTS `dc_heirloom_upgrade_costs`;
CREATE TABLE `dc_heirloom_upgrade_costs` (
    `upgrade_level` TINYINT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'Target upgrade level (1-15)',
    `token_cost` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Upgrade Tokens required',
    `essence_cost` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Upgrade Essence required',
    `description` VARCHAR(64) DEFAULT NULL COMMENT 'Level description'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Costs for heirloom stat package upgrades';

-- Insert costs: Uses same progression as regular upgrades but cheaper
-- Level 1 is free (initial selection), levels 2-15 have escalating costs
INSERT INTO `dc_heirloom_upgrade_costs` (`upgrade_level`, `token_cost`, `essence_cost`, `description`) VALUES
    (1,   0,    50,    'Initiate - Package Selection'),
    (2,   0,    75,    NULL),
    (3,   0,    100,   NULL),
    (4,   0,    150,   NULL),
    (5,   1,    200,   'Adept'),
    (6,   1,    275,   NULL),
    (7,   1,    350,   NULL),
    (8,   2,    450,   NULL),
    (9,   2,    575,   NULL),
    (10,  3,    725,   'Expert'),
    (11,  3,    900,   NULL),
    (12,  4,    1100,  NULL),
    (13,  4,    1350,  NULL),
    (14,  5,    1650,  NULL),
    (15,  5,    2050,  'Master - Maximum Level');


-- ═══════════════════════════════════════════════════════════════════════════════
-- HELPER VIEW: Complete package info with stat names
-- ═══════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS `v_heirloom_packages_detailed`;
CREATE VIEW `v_heirloom_packages_detailed` AS
SELECT 
    p.package_id,
    p.package_name,
    p.package_icon,
    p.description,
    p.stat_type_1,
    p.stat_type_2,
    p.stat_type_3,
    CASE p.stat_type_1
        WHEN 3 THEN 'Agility' WHEN 4 THEN 'Strength' WHEN 5 THEN 'Intellect'
        WHEN 6 THEN 'Spirit' WHEN 7 THEN 'Stamina' WHEN 12 THEN 'Defense'
        WHEN 13 THEN 'Dodge' WHEN 14 THEN 'Parry' WHEN 15 THEN 'Block'
        WHEN 31 THEN 'Hit' WHEN 32 THEN 'Crit' WHEN 35 THEN 'Resilience'
        WHEN 36 THEN 'Haste' WHEN 37 THEN 'Expertise' WHEN 44 THEN 'Armor Pen'
        WHEN 45 THEN 'Spell Power'
        ELSE CONCAT('Stat ', p.stat_type_1)
    END AS stat_1_name,
    CASE p.stat_type_2
        WHEN 3 THEN 'Agility' WHEN 4 THEN 'Strength' WHEN 5 THEN 'Intellect'
        WHEN 6 THEN 'Spirit' WHEN 7 THEN 'Stamina' WHEN 12 THEN 'Defense'
        WHEN 13 THEN 'Dodge' WHEN 14 THEN 'Parry' WHEN 15 THEN 'Block'
        WHEN 31 THEN 'Hit' WHEN 32 THEN 'Crit' WHEN 35 THEN 'Resilience'
        WHEN 36 THEN 'Haste' WHEN 37 THEN 'Expertise' WHEN 44 THEN 'Armor Pen'
        WHEN 45 THEN 'Spell Power'
        ELSE CONCAT('Stat ', p.stat_type_2)
    END AS stat_2_name,
    CASE p.stat_type_3
        WHEN 3 THEN 'Agility' WHEN 4 THEN 'Strength' WHEN 5 THEN 'Intellect'
        WHEN 6 THEN 'Spirit' WHEN 7 THEN 'Stamina' WHEN 12 THEN 'Defense'
        WHEN 13 THEN 'Dodge' WHEN 14 THEN 'Parry' WHEN 15 THEN 'Block'
        WHEN 31 THEN 'Hit' WHEN 32 THEN 'Crit' WHEN 35 THEN 'Resilience'
        WHEN 36 THEN 'Haste' WHEN 37 THEN 'Expertise' WHEN 44 THEN 'Armor Pen'
        WHEN 45 THEN 'Spell Power'
        WHEN NULL THEN NULL
        ELSE CONCAT('Stat ', p.stat_type_3)
    END AS stat_3_name,
    CONCAT('rgb(', p.color_r, ',', p.color_g, ',', p.color_b, ')') AS color_css,
    p.recommended_classes,
    p.recommended_specs,
    p.sort_order
FROM dc_heirloom_stat_packages p
WHERE p.is_enabled = TRUE
ORDER BY p.sort_order;


-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Show all packages with their stat names
SELECT * FROM v_heirloom_packages_detailed;

-- Show Fury package at all levels
SELECT 
    CONCAT('Fury Level ', m.level) AS 'Package',
    CONCAT('+', m.stat_1_value, ' Crit') AS 'Stat 1',
    CONCAT('+', m.stat_2_value, ' Haste') AS 'Stat 2',
    CONCAT(l.essence_cost, ' Essence') AS 'Cost',
    CONCAT(l.total_essence, ' Total') AS 'Invested',
    l.milestone_name AS 'Rank'
FROM dc_heirloom_enchant_mapping m
JOIN dc_heirloom_package_levels l ON m.level = l.level
WHERE m.package_id = 1
ORDER BY m.level;


-- ═══════════════════════════════════════════════════════════════════════════════
-- END OF WORLD DATABASE FILE
-- ═══════════════════════════════════════════════════════════════════════════════
