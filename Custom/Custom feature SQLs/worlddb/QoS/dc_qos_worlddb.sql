-- DarkChaos QoS: Custom Data Tables
-- Database: acore_world
-- Stores custom metadata for items and spells used by the QoS module

-- ============================================================================
-- dc_item_custom_data - Custom item tooltips and sources
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_item_custom_data` (
    `item_id` INT UNSIGNED NOT NULL COMMENT 'Item entry ID',
    `custom_note` TEXT DEFAULT NULL COMMENT 'Custom text to show in tooltip',
    `custom_source` VARCHAR(255) DEFAULT NULL COMMENT 'Custom source text (e.g. "World Boss Drop")',
    `is_custom` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Flag for custom items',
    PRIMARY KEY (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Custom item metadata for QoS tooltips';

-- ============================================================================
-- dc_spell_custom_data - Custom spell tooltips and modifications
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_spell_custom_data` (
    `spell_id` INT UNSIGNED NOT NULL COMMENT 'Spell ID',
    `custom_note` TEXT DEFAULT NULL COMMENT 'Custom text to show in tooltip',
    `modified_values` TEXT DEFAULT NULL COMMENT 'JSON or comma-separated list of modified values',
    PRIMARY KEY (`spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Custom spell metadata for QoS tooltips';

-- Sample Data (Optional)
-- INSERT INTO `dc_item_custom_data` (`item_id`, `custom_note`, `custom_source`, `is_custom`) VALUES 
-- (50001, 'This item is part of the DarkChaos starter set.', 'Starter Quest', 1);
