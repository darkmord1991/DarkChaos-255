-- ═══════════════════════════════════════════════════════════════════════════════
-- TIER 1 & TIER 2 ITEM UPGRADES - Batch Import
-- ═══════════════════════════════════════════════════════════════════════════════
-- Purpose: Populate dc_item_templates_upgrade with T1 and T2 items from CSV exports
-- Generated: 2025-11-10
-- ═══════════════════════════════════════════════════════════════════════════════

-- Set season (update to current season if needed)
SET @season = 1;

-- ───────────────────────────────────────────────────────────────────────────────
-- TIER 1 ITEMS (Common - Item Level 0-100)
-- ───────────────────────────────────────────────────────────────────────────────

INSERT IGNORE INTO `dc_item_templates_upgrade` 
    (`item_id`, `tier_id`, `armor_type`, `item_slot`, `rarity`, `source_type`, `source_id`,
     `base_stat_value`, `cosmetic_variant`, `is_active`, `upgrade_category`, `season`)
VALUES
-- Cosmetic items (item level 0-1)
(27002, 1, 'cosmetic', 3, 3, 'import', 0, 0, 0, 1, 'common', @season),
(27007, 1, 'cosmetic', 10, 3, 'import', 0, 0, 0, 1, 'common', @season),
(40483, 1, 'misc', 12, 3, 'import', 0, 0, 0, 1, 'common', @season),
(14389, 1, 'misc', 3, 3, 'import', 0, 1, 0, 1, 'common', @season),
(21524, 1, 'cloth', 1, 2, 'import', 0, 1, 0, 1, 'common', @season),
(21525, 1, 'cloth', 1, 2, 'import', 0, 1, 0, 1, 'common', @season),
(22206, 1, 'misc', 23, 2, 'import', 0, 1, 0, 1, 'common', @season),
(23192, 1, 'cosmetic', 19, 2, 'import', 0, 1, 0, 1, 'common', @season),
(23705, 1, 'cosmetic', 19, 4, 'import', 0, 1, 0, 1, 'common', @season),
(23709, 1, 'cosmetic', 19, 4, 'import', 0, 1, 0, 1, 'common', @season),
(23716, 1, 'misc', 12, 4, 'import', 0, 1, 0, 1, 'common', @season),
(31404, 1, 'cosmetic', 19, 2, 'import', 0, 1, 0, 1, 'common', @season),
(31405, 1, 'cosmetic', 19, 2, 'import', 0, 1, 0, 1, 'common', @season),
(33292, 1, 'cloth', 1, 3, 'import', 0, 1, 0, 1, 'common', @season),
(35279, 1, 'cosmetic', 19, 3, 'import', 0, 1, 0, 1, 'common', @season),
(35280, 1, 'cosmetic', 19, 3, 'import', 0, 1, 0, 1, 'common', @season),
(36941, 1, 'cosmetic', 19, 3, 'import', 0, 1, 0, 1, 'common', @season),
(38309, 1, 'cosmetic', 19, 4, 'import', 0, 1, 0, 1, 'common', @season),
(38310, 1, 'cosmetic', 19, 4, 'import', 0, 1, 0, 1, 'common', @season),
(38311, 1, 'cosmetic', 19, 4, 'import', 0, 1, 0, 1, 'common', @season),
(38312, 1, 'cosmetic', 19, 4, 'import', 0, 1, 0, 1, 'common', @season),
(38313, 1, 'cosmetic', 19, 4, 'import', 0, 1, 0, 1, 'common', @season),
(38314, 1, 'cosmetic', 19, 4, 'import', 0, 1, 0, 1, 'common', @season),
(40643, 1, 'cosmetic', 19, 4, 'import', 0, 1, 0, 1, 'common', @season),
(43300, 1, 'cosmetic', 19, 4, 'import', 0, 1, 0, 1, 'common', @season),
(43348, 1, 'cosmetic', 19, 4, 'import', 0, 1, 0, 1, 'common', @season),
(43349, 1, 'cosmetic', 19, 4, 'import', 0, 1, 0, 1, 'common', @season),
(45037, 1, 'cloth', 4, 4, 'import', 0, 1, 0, 1, 'common', @season),
(46349, 1, 'cloth', 1, 3, 'import', 0, 1, 0, 1, 'common', @season),
(46874, 1, 'cosmetic', 19, 3, 'import', 0, 1, 0, 1, 'common', @season),
(49706, 1, 'weapon', 17, 4, 'import', 0, 1, 0, 1, 'common', @season),
(49715, 1, 'misc', 1, 3, 'import', 0, 1, 0, 1, 'common', @season),
(50287, 1, 'leather', 8, 3, 'import', 0, 1, 0, 1, 'common', @season),
(50840, 1, 'weapon', 17, 4, 'import', 0, 1, 0, 1, 'common', @season),
(52019, 1, 'cloth', 4, 2, 'import', 0, 1, 0, 1, 'common', @season),
(53891, 1, 'misc', 14, 4, 'import', 0, 1, 0, 1, 'common', @season),
(53924, 1, 'weapon', 13, 4, 'import', 0, 1, 0, 1, 'common', @season),
-- Low level items (5-21 item level)
(16604, 1, 'cloth', 20, 2, 'import', 0, 5, 0, 1, 'common', @season),
(16605, 1, 'cloth', 20, 2, 'import', 0, 5, 0, 1, 'common', @season),
(16606, 1, 'cloth', 20, 2, 'import', 0, 5, 0, 1, 'common', @season),
(16607, 1, 'cloth', 20, 2, 'import', 0, 5, 0, 1, 'common', @season),
(23924, 1, 'cloth', 20, 2, 'import', 0, 5, 0, 1, 'common', @season),
(23931, 1, 'cloth', 20, 2, 'import', 0, 5, 0, 1, 'common', @season),
(32912, 1, 'misc', 13, 3, 'import', 0, 5, 0, 1, 'common', @season),
(32915, 1, 'misc', 13, 3, 'import', 0, 5, 0, 1, 'common', @season),
(32917, 1, 'misc', 13, 3, 'import', 0, 5, 0, 1, 'common', @season),
(32918, 1, 'misc', 13, 3, 'import', 0, 5, 0, 1, 'common', @season),
(32919, 1, 'misc', 13, 3, 'import', 0, 5, 0, 1, 'common', @season),
(32920, 1, 'misc', 13, 3, 'import', 0, 5, 0, 1, 'common', @season);

-- Continue with more Tier 1 items...
-- (Additional items from T1.txt with item levels 5-100)

-- ───────────────────────────────────────────────────────────────────────────────
-- TIER 2 ITEMS (Uncommon/Rare - Item Level 200+)
-- ───────────────────────────────────────────────────────────────────────────────

INSERT IGNORE INTO `dc_item_templates_upgrade` 
    (`item_id`, `tier_id`, `armor_type`, `item_slot`, `rarity`, `source_type`, `source_id`,
     `base_stat_value`, `cosmetic_variant`, `is_active`, `upgrade_category`, `season`)
VALUES
-- Add T2 items here (items with level 200+)
-- These are placeholder values - actual items from T2.txt should be added with their proper levels
(32912, 2, 'misc', 13, 3, 'import', 0, 232, 0, 1, 'uncommon', @season),
(32913, 2, 'misc', 13, 3, 'import', 0, 245, 0, 1, 'uncommon', @season),
(32914, 2, 'misc', 13, 3, 'import', 0, 264, 0, 1, 'uncommon', @season);

-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Show import summary
SELECT 
    tier_id,
    COUNT(*) AS item_count,
    MIN(base_stat_value) AS min_level,
    MAX(base_stat_value) AS max_level,
    COUNT(DISTINCT armor_type) AS armor_types
FROM `dc_item_templates_upgrade`
WHERE season = @season AND is_active = 1
GROUP BY tier_id
ORDER BY tier_id;

-- Show Tier 2 items specifically
SELECT 
    item_id,
    tier_id,
    armor_type,
    base_stat_value AS item_level,
    is_active
FROM `dc_item_templates_upgrade`
WHERE tier_id = 2 AND season = @season
ORDER BY base_stat_value DESC
LIMIT 20;

-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTES
-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. This script imports T1 and T2 items into the tier mapping table
-- 2. base_stat_value is used to store the item_level from the CSV data
-- 3. Server uses this table to assign correct tiers to items
-- 4. After running this script, restart worldserver to reload the tier cache
-- 5. To see which items "Last Word" is, run:
--    SELECT * FROM item_template WHERE name LIKE '%Last Word%';
-- ═══════════════════════════════════════════════════════════════════════════════
