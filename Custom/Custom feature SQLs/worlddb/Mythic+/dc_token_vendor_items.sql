-- Mythic+ Token Vendor Item Pool
-- Maps class -> slot -> item_level -> item_id for token exchanges

DROP TABLE IF EXISTS `dc_token_vendor_items`;

CREATE TABLE `dc_token_vendor_items` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `class` TINYINT UNSIGNED NOT NULL COMMENT 'Class ID (1=Warrior, 2=Paladin, etc)',
  `slot` TINYINT UNSIGNED NOT NULL COMMENT 'Gear slot (1=Head, 2=Neck, 3=Shoulders, etc)',
  `item_id` INT UNSIGNED NOT NULL COMMENT 'Item template ID',
  `item_level` SMALLINT UNSIGNED NOT NULL COMMENT 'Item level (200, 213, 226, 239, 252, etc)',
  `spec` TINYINT UNSIGNED DEFAULT 0 COMMENT 'Talent spec (0=all specs, 1=primary, 2=secondary, 3=tertiary)',
  `token_cost` TINYINT UNSIGNED NOT NULL DEFAULT 11 COMMENT 'Token cost (overrides default)',
  `priority` TINYINT UNSIGNED DEFAULT 1 COMMENT 'Selection priority (higher = preferred)',
  PRIMARY KEY (`id`),
  KEY `idx_class_slot_ilvl` (`class`, `slot`, `item_level`),
  KEY `idx_item_id` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Token vendor item pool for Mythic+ rewards';

-- Example entries (placeholder - replace with actual item IDs from your database)
-- Format: class, slot, item_id, item_level, spec, token_cost, priority

-- Warrior Plate (example)
-- INSERT INTO dc_token_vendor_items VALUES 
-- (NULL, 1, 1, 40000, 200, 0, 11, 1), -- Head
-- (NULL, 1, 2, 40001, 200, 0, 11, 1), -- Neck
-- (NULL, 1, 3, 40002, 200, 0, 11, 1); -- Shoulders

-- Paladin Plate (example)
-- INSERT INTO dc_token_vendor_items VALUES 
-- (NULL, 2, 1, 40010, 200, 0, 11, 1), -- Head
-- (NULL, 2, 2, 40011, 200, 0, 11, 1); -- Neck

-- TODO: Populate with actual item IDs for all classes/slots/ilvls
-- You can query your item_template table to find appropriate items:
-- SELECT entry, name, ItemLevel, class, subclass, displayid 
-- FROM item_template 
-- WHERE ItemLevel BETWEEN 200 AND 260 
-- AND Quality >= 4 -- Epic+
-- AND class IN (2, 4) -- Weapons and Armor
-- ORDER BY class, subclass, ItemLevel;
