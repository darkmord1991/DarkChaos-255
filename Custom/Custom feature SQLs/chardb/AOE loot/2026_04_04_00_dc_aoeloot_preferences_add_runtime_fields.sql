-- Add AoE runtime preference fields to persistent character settings.
ALTER TABLE `dc_aoeloot_preferences`
    ADD COLUMN `gold_only` TINYINT(1) NOT NULL DEFAULT 0 AFTER `auto_vendor_poor`,
    ADD COLUMN `loot_range` FLOAT NOT NULL DEFAULT 30.0 AFTER `gold_only`,
    ADD COLUMN `active_preset` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Loot preset id (0-5)' AFTER `loot_range`;
