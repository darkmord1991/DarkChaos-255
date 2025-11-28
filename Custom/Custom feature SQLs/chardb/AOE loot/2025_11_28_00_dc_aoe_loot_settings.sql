-- AOE Loot settings table
CREATE TABLE IF NOT EXISTS `dc_aoe_loot_settings` (
    `character_guid` INT UNSIGNED PRIMARY KEY,
    `enabled` TINYINT(1) DEFAULT 1,
    `show_messages` TINYINT(1) DEFAULT 1,
    `min_quality` TINYINT UNSIGNED DEFAULT 0,
    `auto_skin` TINYINT(1) DEFAULT 0,
    `smart_loot` TINYINT(1) DEFAULT 1,
    `loot_range` FLOAT DEFAULT 30.0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AOE Loot addon settings per character';
