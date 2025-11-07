-- =========================================================================
-- DarkChaos Item Upgrade System - Bulk Import From Tier Lists
-- -------------------------------------------------------------------------
-- This script ingests semicolon-separated dumps (T1.txt / T2.txt) and loads
-- them into dc_item_templates_upgrade with the refreshed 2-tier layout.
--
-- INPUT FILE FORMAT (matching the shared dumps)
--   item_id;name;ItemLevel;RequiredLevel;InventoryType;Quality
--
-- EXECUTION NOTES
--   * Run against the WORLD database (acore_world).
--   * Adjust @base_path below if the repo lives in a different location.
--   * Requires "local_infile" capability when using LOAD DATA LOCAL.
--
-- USAGE
--   1. SET GLOBAL local_infile=1;           -- if not already enabled
--   2. SOURCE dc_item_upgrade_import_from_lists.sql;
-- =========================================================================

-- -------------------------------------------------------------------------
-- 0) Configure file locations
--    Update the @file_* variables below if your checkout lives elsewhere.
-- -------------------------------------------------------------------------
SET @file_t1 := 'C:/Users/flori/Desktop/WoW Server/Azeroth Fork/DarkChaos-255/Custom/Custom feature SQLs/worlddb/ItemUpgrades/T1.txt';
SET @file_t2 := 'C:/Users/flori/Desktop/WoW Server/Azeroth Fork/DarkChaos-255/Custom/Custom feature SQLs/worlddb/ItemUpgrades/T2.txt';

-- -------------------------------------------------------------------------
-- 1) Prepare staging table
-- -------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_item_upgrade_stage`;
CREATE TABLE `dc_item_upgrade_stage` (
    `tier_id` TINYINT UNSIGNED NOT NULL,
    `item_id` INT UNSIGNED NOT NULL,
    `name` VARCHAR(255) NULL,
    `item_level` SMALLINT UNSIGNED NULL,
    `required_level` TINYINT UNSIGNED NULL,
    `inventory_type` TINYINT UNSIGNED NULL,
    `quality` TINYINT UNSIGNED NULL,
    PRIMARY KEY (`tier_id`, `item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Staging rows loaded from tier dumps';

LOAD DATA LOCAL INFILE 'C:/Users/flori/Desktop/WoW Server/Azeroth Fork/DarkChaos-255/Custom/Custom feature SQLs/worlddb/ItemUpgrades/T1.txt'
INTO TABLE `dc_item_upgrade_stage`
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(@item_id, @name, @item_level, @required_level, @inventory_type, @quality)
SET tier_id        = 1,
    item_id        = NULLIF(@item_id, ''),
    name           = NULLIF(@name, ''),
    item_level     = NULLIF(@item_level, ''),
    required_level = NULLIF(@required_level, ''),
    inventory_type = NULLIF(@inventory_type, ''),
    quality        = NULLIF(@quality, '');

LOAD DATA LOCAL INFILE 'C:/Users/flori/Desktop/WoW Server/Azeroth Fork/DarkChaos-255/Custom/Custom feature SQLs/worlddb/ItemUpgrades/T2.txt'
INTO TABLE `dc_item_upgrade_stage`
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(@item_id, @name, @item_level, @required_level, @inventory_type, @quality)
SET tier_id        = 2,
    item_id        = NULLIF(@item_id, ''),
    name           = NULLIF(@name, ''),
    item_level     = NULLIF(@item_level, ''),
    required_level = NULLIF(@required_level, ''),
    inventory_type = NULLIF(@inventory_type, ''),
    quality        = NULLIF(@quality, '');

-- -------------------------------------------------------------------------
-- 4) Rebuild world mapping for tiers 1 & 2 (Season 1)
-- -------------------------------------------------------------------------
DELETE FROM `dc_item_templates_upgrade`
 WHERE `season` = 1
   AND `tier_id` IN (1, 2);

INSERT INTO `dc_item_templates_upgrade`
    (`item_id`, `tier_id`, `armor_type`, `item_slot`, `rarity`, `source_type`, `source_id`,
     `base_stat_value`, `cosmetic_variant`, `is_active`, `season`)
SELECT
    s.item_id,
    s.tier_id,
    CASE
        WHEN it.class = 4 THEN
            CASE it.subclass
                WHEN 1 THEN 'cloth'
                WHEN 2 THEN 'leather'
                WHEN 3 THEN 'mail'
                WHEN 4 THEN 'plate'
                WHEN 6 THEN 'shield'
                ELSE 'cosmetic'
            END
        WHEN it.class = 2 THEN 'weapon'
        WHEN it.class = 3 THEN 'projectile'
        ELSE 'misc'
    END AS armor_type,
    it.InventoryType AS item_slot,
    it.Quality       AS rarity,
    'import'         AS source_type,
    0                AS source_id,
    it.ItemLevel     AS base_stat_value,
    0                AS cosmetic_variant,
    1                AS is_active,
    1                AS season
FROM `dc_item_upgrade_stage` s
JOIN `item_template` it ON it.entry = s.item_id;

-- -------------------------------------------------------------------------
-- 5) Cleanup (optional: keep stage table for auditing by commenting out)
-- -------------------------------------------------------------------------

-- =========================================================================
-- END OF SCRIPT
-- =========================================================================
