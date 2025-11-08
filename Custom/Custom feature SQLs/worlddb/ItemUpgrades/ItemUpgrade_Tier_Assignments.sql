-- ═══════════════════════════════════════════════════════════════════════════════
-- DarkChaos Item Upgrade System - TIER ASSIGNMENTS FOR ITEMS
-- Database: acore_world
-- Purpose: Assign items to upgrade tiers
-- Tier 1: Common items - Max level 6
-- Tier 2: Uncommon+ items - Max level 15
-- ═══════════════════════════════════════════════════════════════════════════════

USE `acore_world`;

-- ───────────────────────────────────────────────────────────────────────────────
-- ENSURE TABLE STRUCTURE IS CORRECT
-- ───────────────────────────────────────────────────────────────────────────────

-- First, verify table exists with correct columns
ALTER TABLE `dc_item_templates_upgrade` 
ADD COLUMN `tier_id` TINYINT UNSIGNED DEFAULT 1 AFTER `item_id`,
ADD COLUMN `is_active` TINYINT(1) DEFAULT 1 AFTER `tier_id`;

-- ───────────────────────────────────────────────────────────────────────────────
-- CLEAR EXISTING DATA
-- ───────────────────────────────────────────────────────────────────────────────

DELETE FROM `dc_item_templates_upgrade`;

-- ───────────────────────────────────────────────────────────────────────────────
-- TIER 1 ITEMS - Common Quality Items (Max upgrade level: 6)
-- Include all common/quest items
-- ───────────────────────────────────────────────────────────────────────────────

INSERT INTO `dc_item_templates_upgrade` (item_id, tier_id, is_active, season) VALUES
-- Velen's Regalia Set (shown in screenshot - should be Tier 1)
(34472, 1, 1, 1),  -- Velen's Circlet
(34473, 1, 1, 1),  -- Velen's Handwraps
(34474, 1, 1, 1),  -- Velen's Mantle
(34475, 1, 1, 1),  -- Velen's Pants
(34476, 1, 1, 1),  -- Velen's Raiments

-- Additional common items (adjust item IDs to match your server)
(34470, 1, 1, 1),  -- Common Quest Item 1
(34471, 1, 1, 1),  -- Common Quest Item 2
(34480, 1, 1, 1),  -- Common Quest Item 3
(34481, 1, 1, 1),  -- Common Quest Item 4
(34482, 1, 1, 1),  -- Common Quest Item 5
(34483, 1, 1, 1),  -- Common Reward Item 1
(34484, 1, 1, 1),  -- Common Reward Item 2
(34485, 1, 1, 1),  -- Common Reward Item 3
(34486, 1, 1, 1),  -- Common Reward Item 4
(34487, 1, 1, 1),  -- Common Reward Item 5
(34488, 1, 1, 1),  -- Common Gear Item 1
(34489, 1, 1, 1),  -- Common Gear Item 2
(34490, 1, 1, 1),  -- Common Gear Item 3
(34491, 1, 1, 1),  -- Common Gear Item 4
(34492, 1, 1, 1),  -- Common Gear Item 5
(34493, 1, 1, 1),  -- Common Weapon 1
(34494, 1, 1, 1),  -- Common Weapon 2
(34495, 1, 1, 1),  -- Common Armor 1
(34496, 1, 1, 1),  -- Common Armor 2
(34497, 1, 1, 1),  -- Common Accessory 1;

-- ───────────────────────────────────────────────────────────────────────────────
-- TIER 2 ITEMS - Uncommon+ Quality Items (Max upgrade level: 15)
-- Include all rare, epic, and legendary items
-- ───────────────────────────────────────────────────────────────────────────────

INSERT INTO `dc_item_templates_upgrade` (item_id, tier_id, is_active, season) VALUES
-- Raid Gear
(34500, 2, 1, 1),  -- Tier 10 Item 1
(34501, 2, 1, 1),  -- Tier 10 Item 2
(34502, 2, 1, 1),  -- Tier 10 Item 3
(34503, 2, 1, 1),  -- Tier 10 Item 4
(34504, 2, 1, 1),  -- Tier 10 Item 5

-- Hard Mode Gear
(34510, 2, 1, 1),  -- Hard Mode Item 1
(34511, 2, 1, 1),  -- Hard Mode Item 2
(34512, 2, 1, 1),  -- Hard Mode Item 3
(34513, 2, 1, 1),  -- Hard Mode Item 4
(34514, 2, 1, 1),  -- Hard Mode Item 5

-- PvP Gear
(34520, 2, 1, 1),  -- PvP Weapon 1
(34521, 2, 1, 1),  -- PvP Weapon 2
(34522, 2, 1, 1),  -- PvP Armor 1
(34523, 2, 1, 1),  -- PvP Armor 2
(34524, 2, 1, 1),  -- PvP Armor 3

-- Reputation Gear
(34530, 2, 1, 1),  -- Rep Item 1
(34531, 2, 1, 1),  -- Rep Item 2
(34532, 2, 1, 1),  -- Rep Item 3
(34533, 2, 1, 1),  -- Rep Item 4
(34534, 2, 1, 1),  -- Rep Item 5

-- Unique Boss Drops
(34540, 2, 1, 1),  -- Unique Weapon 1
(34541, 2, 1, 1),  -- Unique Armor 1
(34542, 2, 1, 1),  -- Unique Armor 2
(34543, 2, 1, 1),  -- Unique Accessory 1
(34544, 2, 1, 1);  -- Unique Accessory 2

-- ───────────────────────────────────────────────────────────────────────────────
-- VERIFICATION QUERIES
-- ───────────────────────────────────────────────────────────────────────────────

-- Count items by tier:
/*
SELECT tier_id, COUNT(*) as item_count
FROM dc_item_templates_upgrade
WHERE is_active = 1 AND season = 1
GROUP BY tier_id;

Expected:
tier_id | item_count
1       | 20
2       | 25
*/

-- Verify Velen's items are Tier 1:
/*
SELECT item_id, tier_id, is_active
FROM dc_item_templates_upgrade
WHERE item_id IN (34472, 34473, 34474, 34475, 34476)
ORDER BY item_id;

Expected all to have tier_id = 1
*/

-- ───────────────────────────────────────────────────────────────────────────────
-- IMPORTANT: CUSTOMIZE THIS FILE FOR YOUR SERVER
-- ───────────────────────────────────────────────────────────────────────────────
-- 
-- Instructions:
-- 1. Get the correct item IDs from your server database:
--    SELECT entry, name, quality FROM item_template WHERE quality IN (0,1,2,3,4) LIMIT 100;
--
-- 2. Replace item IDs above with your actual item IDs
--
-- 3. Tier 1 items = Common quality (max level 6)
--    Tier 2 items = Uncommon+ quality (max level 15)
--
-- 4. Test that items show correct max levels when upgraded
--
-- 5. If items still show level 15 for Tier 1, verify:
--    - dc_item_upgrade_tiers table has correct max_level values
--    - GetTierMaxLevel() returns correct values
--    - GetItemTier() finds items in dc_item_templates_upgrade
--
-- ═══════════════════════════════════════════════════════════════════════════════
