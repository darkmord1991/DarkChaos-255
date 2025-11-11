-- ═══════════════════════════════════════════════════════════════════════════════
-- CHARACTER DATABASE: RESET ALL ITEM UPGRADE DATA
-- ═══════════════════════════════════════════════════════════════════════════════
-- Purpose: Clear all character item upgrade records to force fresh queries with new item IDs
-- REASON: Tier mappings were updated AFTER items were upgraded, so old data is stale
-- WARNING: This will reset ALL item upgrades for ALL characters!
-- ═══════════════════════════════════════════════════════════════════════════════

-- Show current data before reset
SELECT 'BEFORE RESET' AS status;
SELECT 
    COUNT(*) AS total_upgrades,
    COUNT(DISTINCT item_guid) AS unique_items,
    COUNT(DISTINCT character_guid) AS unique_characters,
    MIN(upgrade_level) AS min_level,
    MAX(upgrade_level) AS max_level
FROM `dc_item_upgrades`;

-- Clear all upgrade records
DELETE FROM `dc_item_upgrades`;

-- Clear all upgrade logs (optional, but recommended)
DELETE FROM `dc_item_upgrade_log`;

-- Verify cleanup
SELECT 'AFTER RESET' AS status;
SELECT 
    COUNT(*) AS total_upgrades,
    COUNT(DISTINCT item_guid) AS unique_items,
    COUNT(DISTINCT character_guid) AS unique_characters
FROM `dc_item_upgrades`;

SELECT 'Upgrade log entries removed:' AS status, COUNT(*) AS count FROM `dc_item_upgrade_log`;

-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTES
-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. All character item upgrades have been cleared
-- 2. Next time you query an item in-game, it will:
--    a. Not find data in dc_item_upgrades (fresh query)
--    b. Fetch the item ID and level from player inventory
--    c. Look up the tier in dc_item_templates_upgrade
--    d. Create a NEW record with correct tier assignment
-- 3. After this script, you should:
--    a. Restart the worldserver to reload tier cache
--    b. Log in with your character
--    c. Open the item upgrade frame and select an item
--    d. The item will query fresh with new tier data
-- ═══════════════════════════════════════════════════════════════════════════════
