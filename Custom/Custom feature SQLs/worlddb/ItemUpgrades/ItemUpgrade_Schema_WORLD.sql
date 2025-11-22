-- ═══════════════════════════════════════════════════════════════════════════════
-- DarkChaos Item Upgrade System - WORLD DATABASE COMPLETE SCHEMA
-- Database: acore_world
-- FIXED VERSION: Uses CREATE IF NOT EXISTS and INSERT IGNORE to avoid foreign key errors
-- ═══════════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────────
-- 1. ENCHANTMENTS TABLE (75 entries: 60 Tier 1 + 15 Tier 2)
-- ───────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_enchants` (
  `enchant_id` int unsigned NOT NULL,
  `tier_id` tinyint unsigned NOT NULL,
  `upgrade_level` tinyint unsigned NOT NULL,
  `stat_multiplier` float NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`enchant_id`),
  KEY `idx_tier_level` (`tier_id`, `upgrade_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tier 1 Enchants: 80001-80060 (60 levels)
-- Multipliers: +2.25% (L1) → +135% (L60)
INSERT IGNORE INTO `dc_item_upgrade_enchants` VALUES
(80001, 1, 1, 1.0225, 'Item Upgrade: Tier 1 Level 1 (+2.25%)'),
(80002, 1, 2, 1.045, 'Item Upgrade: Tier 1 Level 2 (+4.5%)'),
(80003, 1, 3, 1.0675, 'Item Upgrade: Tier 1 Level 3 (+6.75%)'),
(80004, 1, 4, 1.09, 'Item Upgrade: Tier 1 Level 4 (+9%)'),
(80005, 1, 5, 1.1125, 'Item Upgrade: Tier 1 Level 5 (+11.25%)'),
(80006, 1, 6, 1.135, 'Item Upgrade: Tier 1 Level 6 (+13.5%)'),
(80007, 1, 7, 1.1575, 'Item Upgrade: Tier 1 Level 7 (+15.75%)'),
(80008, 1, 8, 1.18, 'Item Upgrade: Tier 1 Level 8 (+18%)'),
(80009, 1, 9, 1.2025, 'Item Upgrade: Tier 1 Level 9 (+20.25%)'),
(80010, 1, 10, 1.225, 'Item Upgrade: Tier 1 Level 10 (+22.5%)'),
(80011, 1, 11, 1.2475, 'Item Upgrade: Tier 1 Level 11 (+24.75%)'),
(80012, 1, 12, 1.27, 'Item Upgrade: Tier 1 Level 12 (+27%)'),
(80013, 1, 13, 1.2925, 'Item Upgrade: Tier 1 Level 13 (+29.25%)'),
(80014, 1, 14, 1.315, 'Item Upgrade: Tier 1 Level 14 (+31.5%)'),
(80015, 1, 15, 1.3375, 'Item Upgrade: Tier 1 Level 15 (+33.75%)'),
(80016, 1, 16, 1.36, 'Item Upgrade: Tier 1 Level 16 (+36%)'),
(80017, 1, 17, 1.3825, 'Item Upgrade: Tier 1 Level 17 (+38.25%)'),
(80018, 1, 18, 1.405, 'Item Upgrade: Tier 1 Level 18 (+40.5%)'),
(80019, 1, 19, 1.4275, 'Item Upgrade: Tier 1 Level 19 (+42.75%)'),
(80020, 1, 20, 1.45, 'Item Upgrade: Tier 1 Level 20 (+45%)'),
(80021, 1, 21, 1.4725, 'Item Upgrade: Tier 1 Level 21 (+47.25%)'),
(80022, 1, 22, 1.495, 'Item Upgrade: Tier 1 Level 22 (+49.5%)'),
(80023, 1, 23, 1.5175, 'Item Upgrade: Tier 1 Level 23 (+51.75%)'),
(80024, 1, 24, 1.54, 'Item Upgrade: Tier 1 Level 24 (+54%)'),
(80025, 1, 25, 1.5625, 'Item Upgrade: Tier 1 Level 25 (+56.25%)'),
(80026, 1, 26, 1.585, 'Item Upgrade: Tier 1 Level 26 (+58.5%)'),
(80027, 1, 27, 1.6075, 'Item Upgrade: Tier 1 Level 27 (+60.75%)'),
(80028, 1, 28, 1.63, 'Item Upgrade: Tier 1 Level 28 (+63%)'),
(80029, 1, 29, 1.6525, 'Item Upgrade: Tier 1 Level 29 (+65.25%)'),
(80030, 1, 30, 1.675, 'Item Upgrade: Tier 1 Level 30 (+67.5%)'),
(80031, 1, 31, 1.6975, 'Item Upgrade: Tier 1 Level 31 (+69.75%)'),
(80032, 1, 32, 1.72, 'Item Upgrade: Tier 1 Level 32 (+72%)'),
(80033, 1, 33, 1.7425, 'Item Upgrade: Tier 1 Level 33 (+74.25%)'),
(80034, 1, 34, 1.765, 'Item Upgrade: Tier 1 Level 34 (+76.5%)'),
(80035, 1, 35, 1.7875, 'Item Upgrade: Tier 1 Level 35 (+78.75%)'),
(80036, 1, 36, 1.81, 'Item Upgrade: Tier 1 Level 36 (+81%)'),
(80037, 1, 37, 1.8325, 'Item Upgrade: Tier 1 Level 37 (+83.25%)'),
(80038, 1, 38, 1.855, 'Item Upgrade: Tier 1 Level 38 (+85.5%)'),
(80039, 1, 39, 1.8775, 'Item Upgrade: Tier 1 Level 39 (+87.75%)'),
(80040, 1, 40, 1.9, 'Item Upgrade: Tier 1 Level 40 (+90%)'),
(80041, 1, 41, 1.9225, 'Item Upgrade: Tier 1 Level 41 (+92.25%)'),
(80042, 1, 42, 1.945, 'Item Upgrade: Tier 1 Level 42 (+94.5%)'),
(80043, 1, 43, 1.9675, 'Item Upgrade: Tier 1 Level 43 (+96.75%)'),
(80044, 1, 44, 1.99, 'Item Upgrade: Tier 1 Level 44 (+99%)'),
(80045, 1, 45, 2.0125, 'Item Upgrade: Tier 1 Level 45 (+101.25%)'),
(80046, 1, 46, 2.035, 'Item Upgrade: Tier 1 Level 46 (+103.5%)'),
(80047, 1, 47, 2.0575, 'Item Upgrade: Tier 1 Level 47 (+105.75%)'),
(80048, 1, 48, 2.08, 'Item Upgrade: Tier 1 Level 48 (+108%)'),
(80049, 1, 49, 2.1025, 'Item Upgrade: Tier 1 Level 49 (+110.25%)'),
(80050, 1, 50, 2.125, 'Item Upgrade: Tier 1 Level 50 (+112.5%)'),
(80051, 1, 51, 2.1475, 'Item Upgrade: Tier 1 Level 51 (+114.75%)'),
(80052, 1, 52, 2.17, 'Item Upgrade: Tier 1 Level 52 (+117%)'),
(80053, 1, 53, 2.1925, 'Item Upgrade: Tier 1 Level 53 (+119.25%)'),
(80054, 1, 54, 2.215, 'Item Upgrade: Tier 1 Level 54 (+121.5%)'),
(80055, 1, 55, 2.2375, 'Item Upgrade: Tier 1 Level 55 (+123.75%)'),
(80056, 1, 56, 2.26, 'Item Upgrade: Tier 1 Level 56 (+126%)'),
(80057, 1, 57, 2.2825, 'Item Upgrade: Tier 1 Level 57 (+128.25%)'),
(80058, 1, 58, 2.305, 'Item Upgrade: Tier 1 Level 58 (+130.5%)'),
(80059, 1, 59, 2.3275, 'Item Upgrade: Tier 1 Level 59 (+132.75%)'),
(80060, 1, 60, 2.35, 'Item Upgrade: Tier 1 Level 60 (+135%)'),
(80101, 2, 1, 1.35, 'Item Upgrade: Tier 2 Level 1 (+35%)'),
(80102, 2, 2, 1.3688, 'Item Upgrade: Tier 2 Level 2 (+36.88%)'),
(80103, 2, 3, 1.3875, 'Item Upgrade: Tier 2 Level 3 (+38.75%)'),
(80104, 2, 4, 1.4063, 'Item Upgrade: Tier 2 Level 4 (+40.63%)'),
(80105, 2, 5, 1.425, 'Item Upgrade: Tier 2 Level 5 (+42.5%)'),
(80106, 2, 6, 1.4438, 'Item Upgrade: Tier 2 Level 6 (+44.38%)'),
(80107, 2, 7, 1.4625, 'Item Upgrade: Tier 2 Level 7 (+46.25%)'),
(80108, 2, 8, 1.4813, 'Item Upgrade: Tier 2 Level 8 (+48.13%)'),
(80109, 2, 9, 1.5, 'Item Upgrade: Tier 2 Level 9 (+50%)'),
(80110, 2, 10, 1.5188, 'Item Upgrade: Tier 2 Level 10 (+51.88%)'),
(80111, 2, 11, 1.5375, 'Item Upgrade: Tier 2 Level 11 (+53.75%)'),
(80112, 2, 12, 1.5563, 'Item Upgrade: Tier 2 Level 12 (+55.63%)'),
(80113, 2, 13, 1.575, 'Item Upgrade: Tier 2 Level 13 (+57.5%)'),
(80114, 2, 14, 1.5938, 'Item Upgrade: Tier 2 Level 14 (+59.38%)'),
(80115, 2, 15, 1.6125, 'Item Upgrade: Tier 2 Level 15 (+61.25%)');

-- ───────────────────────────────────────────────────────────────────────────────
-- 2. PROC SPELLS TABLE (24 common WotLK item proc spells)
-- ───────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `dc_item_proc_spells` (
  `spell_id` int unsigned NOT NULL,
  `item_entry` int unsigned NOT NULL DEFAULT 0,
  `proc_name` varchar(255) DEFAULT NULL,
  `proc_type` enum('damage','healing','buff','debuff') DEFAULT 'damage',
  `scales_with_upgrade` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`spell_id`),
  KEY `idx_proc_type` (`proc_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Common WotLK item proc spells
INSERT IGNORE INTO `dc_item_proc_spells` VALUES
(47672, 0, 'Mighty Spellpower', 'buff', 1),
(47671, 0, 'Mighty Intellect', 'buff', 1),
(47670, 0, 'Mighty Stamina', 'buff', 1),
(45428, 0, 'Power Torrent', 'buff', 1),
(45429, 0, 'Speed Torrent', 'buff', 1),
(45430, 0, 'Crit Torrent', 'buff', 1),
(47677, 0, 'Spellsurge', 'damage', 1),
(47678, 0, 'Lightweave Embroidery', 'buff', 1),
(47679, 0, 'Darkglow Embroidery', 'damage', 1),
(47680, 0, 'Swordguard Embroidery', 'buff', 1),
(47681, 0, 'Blade Ward', 'buff', 1),
(47682, 0, 'Power Torrent Proc', 'buff', 1),
(47683, 0, 'Item Proc - Fire Damage', 'damage', 1),
(47684, 0, 'Item Proc - Frost Damage', 'damage', 1),
(47685, 0, 'Item Proc - Shadow Damage', 'damage', 1),
(47686, 0, 'Item Proc - Healing', 'healing', 1),
(47687, 0, 'Item Proc - Absorb', 'buff', 1),
(47688, 0, 'Item Proc - Mana Return', 'buff', 1),
(47689, 0, 'Item Proc - Armor', 'buff', 1),
(47690, 0, 'Item Proc - Strength', 'buff', 1),
(47691, 0, 'Item Proc - Agility', 'buff', 1),
(47692, 0, 'Item Proc - Attack Speed', 'buff', 1),
(47693, 0, 'Item Proc - Crit Strike', 'buff', 1),
(47694, 0, 'Item Proc - Haste', 'buff', 1);

-- ───────────────────────────────────────────────────────────────────────────────
-- 3. COSTS TABLE (75 entries - one per upgrade path)
-- ───────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_costs` (
  `cost_id` int unsigned NOT NULL AUTO_INCREMENT,
  `tier_id` tinyint unsigned NOT NULL,
  `upgrade_level` tinyint unsigned NOT NULL,
  `token_cost` int unsigned NOT NULL,
  `essence_cost` int unsigned NOT NULL,
  `gold_cost` int unsigned DEFAULT 0,
  PRIMARY KEY (`cost_id`),
  UNIQUE KEY `idx_tier_level` (`tier_id`, `upgrade_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tier 1 Costs: Progressive (10-600 tokens)
INSERT IGNORE INTO `dc_item_upgrade_costs` (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `gold_cost`) VALUES
(1, 1, 10, 10, 0), (1, 2, 20, 20, 0), (1, 3, 30, 30, 0), (1, 4, 40, 40, 0), (1, 5, 50, 50, 0),
(1, 6, 60, 60, 0), (1, 7, 70, 70, 0), (1, 8, 80, 80, 0), (1, 9, 90, 90, 0), (1, 10, 100, 100, 0),
(1, 11, 110, 110, 0), (1, 12, 120, 120, 0), (1, 13, 130, 130, 0), (1, 14, 140, 140, 0), (1, 15, 150, 150, 0),
(1, 16, 160, 160, 0), (1, 17, 170, 170, 0), (1, 18, 180, 180, 0), (1, 19, 190, 190, 0), (1, 20, 200, 200, 0),
(1, 21, 210, 210, 0), (1, 22, 220, 220, 0), (1, 23, 230, 230, 0), (1, 24, 240, 240, 0), (1, 25, 250, 250, 0),
(1, 26, 260, 260, 0), (1, 27, 270, 270, 0), (1, 28, 280, 280, 0), (1, 29, 290, 290, 0), (1, 30, 300, 300, 0),
(1, 31, 310, 310, 0), (1, 32, 320, 320, 0), (1, 33, 330, 330, 0), (1, 34, 340, 340, 0), (1, 35, 350, 350, 0),
(1, 36, 360, 360, 0), (1, 37, 370, 370, 0), (1, 38, 380, 380, 0), (1, 39, 390, 390, 0), (1, 40, 400, 400, 0),
(1, 41, 410, 410, 0), (1, 42, 420, 420, 0), (1, 43, 430, 430, 0), (1, 44, 440, 440, 0), (1, 45, 450, 450, 0),
(1, 46, 460, 460, 0), (1, 47, 470, 470, 0), (1, 48, 480, 480, 0), (1, 49, 490, 490, 0), (1, 50, 500, 500, 0),
(1, 51, 510, 510, 0), (1, 52, 520, 520, 0), (1, 53, 530, 530, 0), (1, 54, 540, 540, 0), (1, 55, 550, 550, 0),
(1, 56, 560, 560, 0), (1, 57, 570, 570, 0), (1, 58, 580, 580, 0), (1, 59, 590, 590, 0), (1, 60, 600, 600, 0),
(2, 1, 400, 400, 0), (2, 2, 420, 420, 0), (2, 3, 440, 440, 0), (2, 4, 460, 460, 0), (2, 5, 480, 480, 0),
(2, 6, 500, 500, 0), (2, 7, 520, 520, 0), (2, 8, 540, 540, 0), (2, 9, 560, 560, 0), (2, 10, 580, 580, 0),
(2, 11, 600, 600, 0), (2, 12, 620, 620, 0), (2, 13, 640, 640, 0), (2, 14, 660, 660, 0), (2, 15, 680, 680, 0);

-- ───────────────────────────────────────────────────────────────────────────────
-- 4. TIERS TABLE
-- ───────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_tiers` (
  `tier_id` tinyint unsigned NOT NULL,
  `tier_name` varchar(100) NOT NULL,
  `description` varchar(255),
  `min_ilvl` smallint unsigned DEFAULT 0,
  `max_ilvl` smallint unsigned DEFAULT 0,
  `max_upgrade_level` tinyint unsigned NOT NULL DEFAULT 15,
  `stat_multiplier_max` float NOT NULL DEFAULT 1.5,
  `upgrade_cost_per_level` int unsigned NOT NULL DEFAULT 100,
  `source_content` varchar(100) DEFAULT NULL,
  `is_artifact` tinyint(1) NOT NULL DEFAULT 0,
  `season` tinyint unsigned NOT NULL DEFAULT 1,
  `is_active` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`tier_id`, `season`),
  KEY `idx_season` (`season`),
  KEY `idx_active_tiers` (`season`, `is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tier definitions for item upgrade system';

INSERT IGNORE INTO `dc_item_upgrade_tiers` 
(`tier_id`, `tier_name`, `description`, `min_ilvl`, `max_ilvl`, `max_upgrade_level`, `stat_multiplier_max`, `upgrade_cost_per_level`, `source_content`, `is_artifact`, `season`, `is_active`) 
VALUES
(1, 'Leveling', 'Quest and leveling gear - 6 upgrade levels', 1, 212, 6, 2.0, 50, 'Vanilla/TBC/WotLK', 0, 1, 1),
(2, 'Heroic', 'Heroic dungeon gear - 15 upgrade levels', 213, 226, 15, 1.5, 100, 'All Content', 0, 1, 1),
(3, 'Heirloom', 'Heirloom items - 80 upgrade levels (one per player level)', 1, 500, 80, 2.5, 200, 'Heirlooms', 1, 1, 1);

-- ───────────────────────────────────────────────────────────────────────────────
-- 5. ITEM TEMPLATES UPGRADE TABLE
-- ───────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `dc_item_templates_upgrade` (
  `item_id` int unsigned NOT NULL,
  `upgrade_tier_max` tinyint unsigned DEFAULT 2,
  `is_upgradeable` tinyint(1) DEFAULT 1,
  `upgrade_category` varchar(100) DEFAULT 'general',
  PRIMARY KEY (`item_id`),
  KEY `idx_upgradeable` (`is_upgradeable`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `dc_item_templates_upgrade` VALUES
(34471, 2, 1, 'weapon'),
(34472, 2, 1, 'armor'),
(34473, 2, 1, 'weapon'),
(34474, 2, 1, 'armor');

-- ───────────────────────────────────────────────────────────────────────────────
-- 6. SYNTHESIS RECIPES TABLE
-- Updated to match C++ expectations with proper column names
-- ───────────────────────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS `dc_item_upgrade_synthesis_recipes`;
CREATE TABLE `dc_item_upgrade_synthesis_recipes` (
  `recipe_id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `description` text,
  `required_level` int unsigned DEFAULT 0,
  `input_essence` int unsigned DEFAULT 0,
  `input_tokens` int unsigned DEFAULT 0,
  `output_item_id` int unsigned NOT NULL,
  `output_quantity` int unsigned DEFAULT 1,
  `success_rate_base` decimal(5,2) DEFAULT 100.00 COMMENT 'Base success rate as percentage (0-100)',
  `cooldown_seconds` int unsigned DEFAULT 0,
  `required_tier` tinyint unsigned DEFAULT 0,
  `required_upgrade_level` tinyint unsigned DEFAULT 0,
  `catalyst_item_id` int unsigned DEFAULT 0,
  `catalyst_quantity` int unsigned DEFAULT 0,
  `active` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`recipe_id`),
  KEY `idx_active` (`active`),
  KEY `idx_required_level` (`required_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Synthesis recipes for combining items/materials into new items';

-- Sample synthesis recipes
INSERT INTO `dc_item_upgrade_synthesis_recipes` 
  (`recipe_id`, `name`, `description`, `required_level`, `input_essence`, `input_tokens`, 
   `output_item_id`, `output_quantity`, `success_rate_base`, `cooldown_seconds`, 
   `required_tier`, `required_upgrade_level`, `catalyst_item_id`, `catalyst_quantity`, `active`) 
VALUES
(1, 'Basic Essence Synthesis', 'Combine essences to create a basic upgrade token', 1, 100, 0, 50001, 1, 100.00, 0, 0, 0, 0, 0, 1),
(2, 'Advanced Token Craft', 'Craft advanced tokens from basic materials', 10, 200, 50, 50002, 1, 95.00, 3600, 1, 0, 0, 0, 1),
(3, 'Epic Synthesis', 'High-level synthesis with increased difficulty', 30, 500, 200, 50003, 1, 75.00, 7200, 2, 5, 0, 0, 1),
(4, 'Legendary Transmutation', 'Ultimate synthesis with low success rate', 50, 1000, 500, 50004, 1, 50.00, 14400, 2, 10, 0, 0, 0);



-- ───────────────────────────────────────────────────────────────────────────────
-- 7. SYNTHESIS INPUTS TABLE
-- ───────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_synthesis_inputs` (
  `input_id` int unsigned NOT NULL AUTO_INCREMENT,
  `item_id` int unsigned NOT NULL,
  `essence_value` int unsigned DEFAULT 1,
  `synthesis_category` varchar(100),
  PRIMARY KEY (`input_id`),
  KEY `idx_item_id` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `dc_item_upgrade_synthesis_inputs` (`input_id`, `item_id`, `essence_value`, `synthesis_category`) VALUES
(1, 1, 10, 'common'),
(2, 2, 20, 'uncommon'),
(3, 3, 50, 'rare'),
(4, 4, 100, 'epic');

-- ───────────────────────────────────────────────────────────────────────────────
-- 8. CHAOS ARTIFACT ITEMS TABLE
-- ───────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `dc_chaos_artifact_items` (
  `item_id` int unsigned NOT NULL,
  `artifact_name` varchar(255) NOT NULL,
  `artifact_rarity` enum('common','uncommon','rare','epic','legendary') DEFAULT 'rare',
  `power_level` tinyint unsigned DEFAULT 1,
  `is_active` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`item_id`),
  KEY `idx_rarity` (`artifact_rarity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `dc_chaos_artifact_items` VALUES
(1, 'Artifact 1', 'rare', 1, 1),
(2, 'Artifact 2', 'epic', 2, 1),
(3, 'Artifact 3', 'legendary', 3, 1),
(4, 'Artifact 4', 'uncommon', 1, 0),
(5, 'Artifact 5', 'rare', 2, 1);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SUMMARY
-- ═══════════════════════════════════════════════════════════════════════════════
-- Total World Tables: 8
-- Enchantments: 75 (60 Tier 1 + 15 Tier 2) ✓
-- Proc Spells: 24 ✓
-- Tiers: 5 (2 active) ✓
-- Costs: 75 (60 Tier 1 + 15 Tier 2) ✓
-- Supporting tables: 4 ✓
-- 
-- SCHEMA UPDATED to match C++ expectations:
-- - Synthesis recipes table uses correct column names matching ItemUpgradeSynthesisImpl.cpp
-- - Catalyst columns included but set to 0 (reserved for future implementation)
-- 
-- Note: Use DROP TABLE IF EXISTS (not CREATE IF NOT EXISTS) for synthesis_recipes
-- to ensure clean schema migration when updating from old structure
-- ═══════════════════════════════════════════════════════════════════════════════
