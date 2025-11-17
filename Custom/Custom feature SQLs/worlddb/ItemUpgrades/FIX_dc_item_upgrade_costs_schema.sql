-- ═══════════════════════════════════════════════════════════════════════════════
-- FIX: dc_item_upgrade_costs TABLE SCHEMA
-- Issue: Missing columns ilvl_increase and stat_increase_percent
-- Solution: ALTER TABLE to add missing columns and remove unused gold_cost
-- ═══════════════════════════════════════════════════════════════════════════════

USE acore_world;

-- Step 1: Add missing columns that C++ code expects
ALTER TABLE `dc_item_upgrade_costs` 
    ADD COLUMN `ilvl_increase` SMALLINT UNSIGNED DEFAULT 0 AFTER `essence_cost`,
    ADD COLUMN `stat_increase_percent` FLOAT DEFAULT 0.0 AFTER `ilvl_increase`;

-- Step 2: (Optional) Remove unused gold_cost column
-- ALTER TABLE `dc_item_upgrade_costs` DROP COLUMN `gold_cost`;

-- Step 3: Add season column if it doesn't exist (C++ code expects it)
ALTER TABLE `dc_item_upgrade_costs`
    ADD COLUMN `season` INT UNSIGNED DEFAULT 1 AFTER `stat_increase_percent`;

-- Step 4: Fix primary key issue
-- First remove AUTO_INCREMENT from cost_id (it requires being in a key)
ALTER TABLE `dc_item_upgrade_costs` MODIFY `cost_id` INT UNSIGNED NOT NULL;

-- Now drop the old primary key
ALTER TABLE `dc_item_upgrade_costs` DROP PRIMARY KEY;

-- Add composite primary key (tier_id, upgrade_level, season)
ALTER TABLE `dc_item_upgrade_costs` 
    ADD PRIMARY KEY (`tier_id`, `upgrade_level`, `season`);

-- Step 5: (Optional) Drop cost_id column since it's no longer needed
ALTER TABLE `dc_item_upgrade_costs` DROP COLUMN `cost_id`;

-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERY
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'acore_world' 
  AND TABLE_NAME = 'dc_item_upgrade_costs'
ORDER BY ORDINAL_POSITION;

-- Expected columns after fix:
-- 1. cost_id (INT) - can be kept or removed
-- 2. tier_id (TINYINT) - Part of PK
-- 3. upgrade_level (TINYINT) - Part of PK  
-- 4. token_cost (INT)
-- 5. essence_cost (INT)
-- 6. ilvl_increase (SMALLINT) <- ADDED
-- 7. stat_increase_percent (FLOAT) <- ADDED
-- 8. gold_cost (INT) - can be kept or removed
-- 9. season (INT) <- ADDED

-- ═══════════════════════════════════════════════════════════════════════════════
-- TIER CONFIGURATION SUMMARY
-- ═══════════════════════════════════════════════════════════════════════════════

-- Tier 1 (Leveling): 6 upgrade levels
-- Tier 2 (Heroic):   15 upgrade levels  
-- Tier 3 (Heirloom): 80 upgrade levels (one per player level)

-- ═══════════════════════════════════════════════════════════════════════════════
-- POPULATE COSTS - EXAMPLE DATA
-- ═══════════════════════════════════════════════════════════════════════════════

/*
INSERT INTO dc_item_upgrade_costs 
    (tier_id, upgrade_level, token_cost, essence_cost, ilvl_increase, stat_increase_percent, season)
VALUES
    -- Tier 1: 6 levels
    (1, 1, 5, 0, 1, 0.05, 1),     -- Level 1: 5 tokens, +1 ilvl, +5% stats
    (1, 2, 6, 0, 1, 0.05, 1),     -- Level 2: 6 tokens, +1 ilvl, +5% stats
    (1, 3, 7, 0, 1, 0.05, 1),
    (1, 4, 8, 0, 1, 0.05, 1),
    (1, 5, 9, 0, 1, 0.05, 1),
    (1, 6, 10, 0, 1, 0.05, 1),    -- Level 6: 10 tokens, +1 ilvl, +5% stats
    
    -- Tier 2: 15 levels (example)
    (2, 1, 8, 0, 1, 0.03, 1),
    -- ... continue to level 15
    
    -- Tier 3: 80 levels (example)
    (3, 1, 0, 5, 0, 0.02, 1),     -- Uses essence instead of tokens
    -- ... continue to level 80
*/

-- ═══════════════════════════════════════════════════════════════════════════════
-- END OF FIX
-- ═══════════════════════════════════════════════════════════════════════════════
