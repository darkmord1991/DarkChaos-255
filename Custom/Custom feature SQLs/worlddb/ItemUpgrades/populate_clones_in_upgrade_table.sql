-- ═══════════════════════════════════════════════════════════════════════════════
-- POPULATE dc_item_templates_upgrade WITH ALL CLONED ITEMS
-- ═══════════════════════════════════════════════════════════════════════════════
-- Purpose: Register all cloned upgrade items with their tier so tier detection works
-- This ensures GetItemTier() always finds the correct tier for ANY item
-- ═══════════════════════════════════════════════════════════════════════════════

SET @season = 1;

-- First, check what we have
SELECT 'BEFORE INSERT' AS status;
SELECT tier_id, COUNT(*) AS count FROM `dc_item_templates_upgrade` GROUP BY tier_id;

-- Clear existing clone item entries (keep base items)
DELETE FROM `dc_item_templates_upgrade` 
WHERE item_id BETWEEN 2000000 AND 2999999;

-- Insert all cloned items from dc_item_upgrade_clones with their tier
INSERT INTO `dc_item_templates_upgrade` 
    (`item_id`, `tier_id`, `armor_type`, `item_slot`, `rarity`, `source_type`, `source_id`,
     `base_stat_value`, `cosmetic_variant`, `is_active`, `upgrade_category`, `season`)
SELECT 
    dc.clone_item_id AS item_id,
    dc.tier_id,
    'clone' AS armor_type,
    0 AS item_slot,
    0 AS rarity,
    'clone' AS source_type,
    dc.base_item_id AS source_id,
    ROUND(it.ItemLevel * dc.stat_multiplier) AS base_stat_value,
    0 AS cosmetic_variant,
    1 AS is_active,
    CASE dc.tier_id 
        WHEN 1 THEN 'common'
        WHEN 2 THEN 'uncommon'
        WHEN 3 THEN 'rare'
        WHEN 4 THEN 'epic'
        WHEN 5 THEN 'legendary'
        ELSE 'unknown'
    END AS upgrade_category,
    @season AS season
FROM `dc_item_upgrade_clones` dc
LEFT JOIN `item_template` it ON dc.base_item_id = it.entry
WHERE dc.clone_item_id BETWEEN 2000000 AND 2999999;

-- Verify results
SELECT 'AFTER INSERT' AS status;
SELECT tier_id, COUNT(*) AS count FROM `dc_item_templates_upgrade` WHERE item_id BETWEEN 2000000 AND 2999999 GROUP BY tier_id;

-- Show sample of cloned items by tier
SELECT 'TIER 1 CLONES (sample):' AS type;
SELECT item_id, tier_id, base_stat_value AS item_level
FROM `dc_item_templates_upgrade`
WHERE tier_id = 1 AND item_id BETWEEN 2000000 AND 2999999
ORDER BY item_id
LIMIT 10;

SELECT 'TIER 2 CLONES (sample):' AS type;
SELECT item_id, tier_id, base_stat_value AS item_level
FROM `dc_item_templates_upgrade`
WHERE tier_id = 2 AND item_id BETWEEN 2000000 AND 2999999
ORDER BY item_id
LIMIT 10;

-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTES
-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. All cloned items (2M-2.9M range) are now registered with their tier
-- 2. When server calls GetItemTier(cloneItemId), it will find the correct tier
-- 3. Client will query with correct tier for any cloned item
-- 4. After this, restart worldserver to reload tier cache from database
-- ═══════════════════════════════════════════════════════════════════════════════
