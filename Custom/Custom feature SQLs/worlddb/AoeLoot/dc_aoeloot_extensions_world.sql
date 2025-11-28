-- =====================================================================
-- DarkChaos AoE Loot Extensions - WORLD Database Setup
-- =====================================================================
-- Run this on the `acore_world` database.
-- =====================================================================

-- AoE Loot Configuration Table
-- Global settings and zone-specific overrides
DROP TABLE IF EXISTS `dc_aoeloot_config`;
CREATE TABLE `dc_aoeloot_config` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `config_key` VARCHAR(64) NOT NULL,
    `config_value` VARCHAR(255) NOT NULL,
    `description` TEXT,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos AoE Loot - Global Configuration';

-- Insert default configuration
INSERT INTO `dc_aoeloot_config` (`config_key`, `config_value`, `description`) VALUES
('default_range', '45', 'Default AoE loot range in yards'),
('max_range', '100', 'Maximum allowed AoE loot range'),
('skinning_bonus', '1.0', 'Multiplier for skinning profession bonus'),
('mining_bonus', '1.0', 'Multiplier for mining profession bonus'),
('herbalism_bonus', '1.0', 'Multiplier for herbalism profession bonus'),
('mythic_bonus_chance', '0.10', 'Base chance for bonus loot in M+ (10%)'),
('mythic_bonus_per_level', '0.02', 'Additional chance per keystone level (2%)'),
('auto_vendor_enabled', '1', 'Allow players to enable auto-vendor'),
('smart_loot_enabled', '1', 'Allow smart loot detection'),
('upgrade_detection_enabled', '1', 'Enable gear upgrade detection');

-- Zone-Specific Loot Modifiers
DROP TABLE IF EXISTS `dc_aoeloot_zone_modifiers`;
CREATE TABLE `dc_aoeloot_zone_modifiers` (
    `zone_id` INT UNSIGNED NOT NULL,
    `zone_name` VARCHAR(64) NOT NULL,
    `gold_multiplier` FLOAT NOT NULL DEFAULT 1.0,
    `item_quality_bonus` TINYINT NOT NULL DEFAULT 0 COMMENT 'Added to quality roll',
    `mythic_bonus_multiplier` FLOAT NOT NULL DEFAULT 1.0,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`zone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos AoE Loot - Zone Modifiers';

-- Insert some example zone modifiers
INSERT INTO `dc_aoeloot_zone_modifiers` (`zone_id`, `zone_name`, `gold_multiplier`, `item_quality_bonus`, `mythic_bonus_multiplier`) VALUES
-- Northrend dungeons with higher rewards
(574, 'Utgarde Keep', 1.0, 0, 1.0),
(575, 'Utgarde Pinnacle', 1.1, 0, 1.1),
(576, 'The Nexus', 1.0, 0, 1.0),
(578, 'Oculus', 1.2, 0, 1.2),
(595, 'Culling of Stratholme', 1.2, 0, 1.2),
(599, 'Halls of Stone', 1.1, 0, 1.1),
(600, 'Drak''Tharon Keep', 1.0, 0, 1.0),
(601, 'Azjol-Nerub', 1.0, 0, 1.0),
(602, 'Halls of Lightning', 1.1, 0, 1.1),
(604, 'Gundrak', 1.1, 0, 1.1),
(608, 'Violet Hold', 1.0, 0, 1.0),
(619, 'Ahn''kahet', 1.1, 0, 1.1),
-- ICC 5-mans with best rewards
(632, 'Forge of Souls', 1.3, 1, 1.3),
(658, 'Pit of Saron', 1.3, 1, 1.3),
(668, 'Halls of Reflection', 1.4, 1, 1.4),
-- Trial with bonus
(650, 'Trial of the Champion', 1.2, 1, 1.2);

-- Item Blacklist Table
-- Items that should never be AoE looted (quest items, etc.)
DROP TABLE IF EXISTS `dc_aoeloot_blacklist`;
CREATE TABLE `dc_aoeloot_blacklist` (
    `item_id` INT UNSIGNED NOT NULL,
    `reason` VARCHAR(100) NOT NULL DEFAULT 'Blacklisted',
    PRIMARY KEY (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos AoE Loot - Item Blacklist';

-- Insert common items that shouldn't be auto-looted
INSERT INTO `dc_aoeloot_blacklist` (`item_id`, `reason`) VALUES
-- Quest items examples (add actual quest item IDs as needed)
(6948, 'Hearthstone - should not duplicate'),
(43824, 'Midsummer supplies quest item');

-- Smart Loot Item Categories
-- Defines which items are considered upgrades for which classes/specs
DROP TABLE IF EXISTS `dc_aoeloot_smart_categories`;
CREATE TABLE `dc_aoeloot_smart_categories` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `category_name` VARCHAR(64) NOT NULL,
    `stat_primary` VARCHAR(32) NOT NULL COMMENT 'e.g., INTELLECT, STRENGTH, AGILITY',
    `stat_secondary` VARCHAR(64) COMMENT 'Comma-separated secondary stats',
    `class_mask` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Class bitmask, 0 = all',
    `spec_id` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 = any spec',
    PRIMARY KEY (`id`),
    INDEX `idx_class` (`class_mask`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='DarkChaos AoE Loot - Smart Loot Categories';

-- Insert smart loot categories
INSERT INTO `dc_aoeloot_smart_categories` (`category_name`, `stat_primary`, `stat_secondary`, `class_mask`, `spec_id`) VALUES
('Plate DPS', 'STRENGTH', 'CRIT,HASTE,ARMOR_PEN', 1|2|32, 0),      -- Warrior, Paladin, DK
('Plate Tank', 'STAMINA', 'DEFENSE,DODGE,PARRY', 1|2|32, 0),       -- Tank specs
('Plate Holy', 'INTELLECT', 'SPELL_POWER,CRIT,MP5', 2, 0),          -- Holy Paladin
('Leather Agility', 'AGILITY', 'CRIT,HASTE,ATTACK_POWER', 4|8, 0), -- Rogue, Druid
('Leather Caster', 'INTELLECT', 'SPELL_POWER,CRIT,SPIRIT', 8, 0),  -- Balance/Resto Druid
('Mail Hunter', 'AGILITY', 'CRIT,HASTE,ATTACK_POWER', 64, 0),      -- Hunter
('Mail Shaman Enh', 'AGILITY', 'CRIT,HASTE,ATTACK_POWER', 256, 0), -- Enhancement
('Mail Shaman Caster', 'INTELLECT', 'SPELL_POWER,CRIT,MP5', 256, 0), -- Ele/Resto
('Cloth DPS', 'INTELLECT', 'SPELL_POWER,CRIT,HASTE', 16|128, 0),   -- Mage, Warlock
('Cloth Healer', 'INTELLECT', 'SPELL_POWER,SPIRIT,MP5', 16, 0);     -- Priest

-- =====================================================================
-- Sample Queries
-- =====================================================================

-- Get zone modifiers for a specific zone:
-- SELECT * FROM dc_aoeloot_zone_modifiers WHERE zone_id = ?;

-- Check if item is blacklisted:
-- SELECT reason FROM dc_aoeloot_blacklist WHERE item_id = ?;

-- Get smart loot category for a class:
-- SELECT * FROM dc_aoeloot_smart_categories 
-- WHERE class_mask = 0 OR (class_mask & ?) != 0;
