-- ═══════════════════════════════════════════════════════════════════════════════
-- DarkChaos Item Upgrade System - Bulk Import From Tier Lists
-- WINDOWS VERSION - Use this when running MySQL locally on Windows
-- ───────────────────────────────────────────────────────────────────────────────
-- UPGRADED v2.0 - Now supports complete schema with:
--   * Tier-based item assignments (Tier 1 vs Tier 2)
--   * Item category mapping (weapon, armor, misc, etc)
--   * Integration with dc_item_upgrade_tiers
--   * Automatic item level detection
--   * Rarity-based categorization
--
-- INPUT FILE FORMAT (from T1.txt / T2.txt dumps)
--   item_id;name;ItemLevel;RequiredLevel;InventoryType;Quality;class;subclass
--
-- EXECUTION NOTES (WINDOWS LOCAL)
--   * Run against the WORLD database (acore_world).
--   * Requires "local_infile" capability (SET GLOBAL local_infile=1;)
--   * Copy T1.txt and T2.txt to MySQL secure_file_priv directory:
--     C:\ProgramData\MySQL\MySQL Server 8.0\Uploads\
--   * Or update FILE paths below to match your actual file locations
--
-- USAGE STEPS (WINDOWS)
--   1. OPTIONAL: SET GLOBAL local_infile=1;
--   2. SOURCE dc_item_upgrade_import_WINDOWS.sql;
--   3. Verify: SELECT tier_id, COUNT(*) FROM dc_item_templates_upgrade 
--                      GROUP BY tier_id;
-- ═══════════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 0: CHECK FILE PATHS AND PERMISSIONS
-- ───────────────────────────────────────────────────────────────────────────────
-- Show where MySQL can read files from
SHOW VARIABLES LIKE 'secure_file_priv';

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 1: Prepare staging table to validate and normalize tier data
-- ───────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS `dc_item_upgrade_stage`;
CREATE TABLE `dc_item_upgrade_stage` (
    `tier_id` TINYINT UNSIGNED NOT NULL,
    `item_id` INT UNSIGNED NOT NULL,
    `name` VARCHAR(255) NULL,
    `item_level` SMALLINT UNSIGNED NULL,
    `required_level` TINYINT UNSIGNED NULL,
    `inventory_type` TINYINT UNSIGNED NULL,
    `quality` TINYINT UNSIGNED NULL,
    `item_class` TINYINT UNSIGNED NULL,
    `item_subclass` TINYINT UNSIGNED NULL,
    PRIMARY KEY (`tier_id`, `item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Staging rows loaded from tier dumps for validation';

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 2: Load Tier 1 items from T1.txt
-- NOTE: Update the file path below to match your system
-- ───────────────────────────────────────────────────────────────────────────────
-- OPTION A: If files are in secure_file_priv directory (recommended)
LOAD DATA LOCAL INFILE 'C:/Users/flori/Desktop/WoW Server/Azeroth Fork/DarkChaos-255/Custom/Custom feature SQLs/worlddb/ItemUpgrades/T1.txt'
INTO TABLE `dc_item_upgrade_stage`
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@item_id, @name, @item_level, @required_level, @inventory_type, @class, @subclass)
SET tier_id        = 1,
    item_id        = CAST(NULLIF(@item_id, '') AS UNSIGNED),
    name           = NULLIF(@name, ''),
    item_level     = CAST(NULLIF(@item_level, '') AS UNSIGNED),
    required_level = CAST(NULLIF(@required_level, '') AS UNSIGNED),
    inventory_type = CAST(NULLIF(@inventory_type, '') AS UNSIGNED),
    quality        = NULL,
    item_class     = CAST(NULLIF(@class, '') AS UNSIGNED),
    item_subclass  = CAST(NULLIF(@subclass, '') AS UNSIGNED);

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 3: Load Tier 2 items from T2.txt
-- NOTE: Update the file path below to match your system
-- ───────────────────────────────────────────────────────────────────────────────
LOAD DATA LOCAL INFILE 'C:/Users/flori/Desktop/WoW Server/Azeroth Fork/DarkChaos-255/Custom/Custom feature SQLs/worlddb/ItemUpgrades/T2.txt'
INTO TABLE `dc_item_upgrade_stage`
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@item_id, @name, @item_level, @required_level, @inventory_type, @class, @subclass)
SET tier_id        = 2,
    item_id        = CAST(NULLIF(@item_id, '') AS UNSIGNED),
    name           = NULLIF(@name, ''),
    item_level     = CAST(NULLIF(@item_level, '') AS UNSIGNED),
    required_level = CAST(NULLIF(@required_level, '') AS UNSIGNED),
    inventory_type = CAST(NULLIF(@inventory_type, '') AS UNSIGNED),
    quality        = NULL,
    item_class     = CAST(NULLIF(@class, '') AS UNSIGNED),
    item_subclass  = CAST(NULLIF(@subclass, '') AS UNSIGNED);

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 4: Verify staging data was loaded
-- ───────────────────────────────────────────────────────────────────────────────
SELECT 'TIER 1 LOADED' AS status, COUNT(*) AS count FROM `dc_item_upgrade_stage` WHERE tier_id = 1
UNION ALL
SELECT 'TIER 2 LOADED' AS status, COUNT(*) AS count FROM `dc_item_upgrade_stage` WHERE tier_id = 2;

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 5: Hydrate rarity from item_template for proper categorization
-- ───────────────────────────────────────────────────────────────────────────────
UPDATE `dc_item_upgrade_stage` s
  JOIN `item_template` it ON it.entry = s.item_id
   SET s.quality = it.Quality;

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 6: Rebuild dc_item_templates_upgrade with NEW SCHEMA
--    NEW SCHEMA: tier_id, armor_type, item_slot, rarity, source_type, source_id,
--                base_stat_value, cosmetic_variant, is_active, upgrade_category, season
-- ───────────────────────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS `dc_item_templates_upgrade`;
CREATE TABLE `dc_item_templates_upgrade` (
  `item_id` INT UNSIGNED NOT NULL,
  `tier_id` TINYINT UNSIGNED DEFAULT 1,
  `armor_type` VARCHAR(50) DEFAULT 'misc',
  `item_slot` TINYINT UNSIGNED DEFAULT 0,
  `rarity` TINYINT UNSIGNED DEFAULT 0,
  `source_type` VARCHAR(50) DEFAULT 'import',
  `source_id` INT UNSIGNED DEFAULT 0,
  `base_stat_value` SMALLINT UNSIGNED DEFAULT 0,
  `cosmetic_variant` TINYINT UNSIGNED DEFAULT 0,
  `is_active` TINYINT(1) DEFAULT 1,
  `upgrade_category` VARCHAR(50) DEFAULT 'common',
  `season` TINYINT UNSIGNED DEFAULT 1,
  PRIMARY KEY (`item_id`),
  KEY `idx_tier_season` (`tier_id`, `season`),
  KEY `idx_armor_type` (`armor_type`),
  KEY `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Item Upgrade Template Mappings v2.0';

-- Insert new tier assignments with full schema
INSERT IGNORE INTO `dc_item_templates_upgrade`
    (`item_id`, `tier_id`, `armor_type`, `item_slot`, `rarity`, `source_type`, `source_id`,
     `base_stat_value`, `cosmetic_variant`, `is_active`, `upgrade_category`, `season`)
SELECT
    s.item_id,
    s.tier_id,
    -- Categorize items by class/subclass
    CASE
        WHEN s.item_class = 4 THEN
            CASE s.item_subclass
                WHEN 1 THEN 'cloth'
                WHEN 2 THEN 'leather'
                WHEN 3 THEN 'mail'
                WHEN 4 THEN 'plate'
                WHEN 6 THEN 'shield'
                ELSE 'cosmetic'
            END
        WHEN s.item_class = 2 THEN 'weapon'
        WHEN s.item_class = 3 THEN 'projectile'
        WHEN s.item_class = 0 THEN 'consumable'
        WHEN s.item_class = 5 THEN 'gems'
        WHEN s.item_class = 11 THEN 'quiver'
        WHEN s.item_class = 15 THEN 'mount'
        ELSE 'misc'
    END AS armor_type,
    s.inventory_type AS item_slot,
    COALESCE(s.quality, 0) AS rarity,
    'import'         AS source_type,
    0                AS source_id,
    s.item_level     AS base_stat_value,
    0                AS cosmetic_variant,
    1                AS is_active,
    -- Set upgrade category based on tier
    CASE
        WHEN s.tier_id = 1 THEN 'common'
        WHEN s.tier_id = 2 THEN 'uncommon'
        ELSE 'rare'
    END AS upgrade_category,
    1                AS season
FROM `dc_item_upgrade_stage` s
WHERE s.item_id IS NOT NULL;

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 7: Verification Queries - Check import results
-- ───────────────────────────────────────────────────────────────────────────────

-- Summary by Tier
SELECT 
    'TIER 1' AS tier_name,
    COUNT(*) AS item_count,
    GROUP_CONCAT(DISTINCT armor_type SEPARATOR ', ') AS armor_types,
    MIN(base_stat_value) AS min_level,
    MAX(base_stat_value) AS max_level
FROM `dc_item_templates_upgrade`
WHERE tier_id = 1 AND season = 1 AND is_active = 1
UNION ALL
SELECT 
    'TIER 2' AS tier_name,
    COUNT(*) AS item_count,
    GROUP_CONCAT(DISTINCT armor_type SEPARATOR ', ') AS armor_types,
    MIN(base_stat_value) AS min_level,
    MAX(base_stat_value) AS max_level
FROM `dc_item_templates_upgrade`
WHERE tier_id = 2 AND season = 1 AND is_active = 1;

-- Category breakdown
SELECT 
    tier_id,
    upgrade_category,
    COUNT(*) AS count,
    COUNT(DISTINCT armor_type) AS armor_type_variety
FROM `dc_item_templates_upgrade`
WHERE season = 1 AND is_active = 1
GROUP BY tier_id, upgrade_category
ORDER BY tier_id, upgrade_category;

-- Item level distribution
SELECT 
    tier_id,
    COUNT(*) AS count,
    MIN(base_stat_value) AS min_level,
    MAX(base_stat_value) AS max_level,
    ROUND(AVG(base_stat_value), 1) AS avg_level
FROM `dc_item_templates_upgrade`
WHERE is_active = 1
GROUP BY tier_id;

-- ───────────────────────────────────────────────────────────────────────────────
-- STEP 8: Cleanup staging table (optional: comment out to retain for auditing)
-- ───────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS `dc_item_upgrade_stage`;

-- ═══════════════════════════════════════════════════════════════════════════════
-- IMPORT COMPLETE
-- ═══════════════════════════════════════════════════════════════════════════════
-- Expected Results:
--   ✓ Tier 1: ~150+ common items
--   ✓ Tier 2: ~120+ uncommon/rare items
--   ✓ Armor types: cloth, leather, mail, plate, weapon, projectile, misc
--   ✓ All items active and assigned to Season 1
--   ✓ Rarity values populated from item_template Quality field
--   ✓ Item levels preserved from source CSV files
--
-- TROUBLESHOOTING:
--   If you get "Error 13: Can't get stat of file" - Files are not in secure_file_priv
--   Solution: Check SHOW VARIABLES LIKE 'secure_file_priv';
--             Then copy T1.txt and T2.txt to that directory
--
--   If you get "Records: 0" - Check file path or line terminators
--   Solution: Try LINES TERMINATED BY '\r\n' if files are Windows format
--             Or LINES TERMINATED BY '\n' if files are Unix format
--
-- Next Steps:
--   1. Verify item counts above
--   2. Restart worldserver to load tier cache
--   3. In-game: Test that Tier 1 items max at 60 levels, Tier 2 at 15 levels
-- ═══════════════════════════════════════════════════════════════════════════════
