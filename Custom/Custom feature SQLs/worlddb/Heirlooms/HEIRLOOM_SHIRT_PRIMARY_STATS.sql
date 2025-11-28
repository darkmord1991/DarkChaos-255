-- ═══════════════════════════════════════════════════════════════════════════════
-- HEIRLOOM SHIRT (300365) - PRIMARY STAT UPDATES
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- FILE: HEIRLOOM_SHIRT_PRIMARY_STATS.sql
-- DATABASE: acore_world
-- 
-- OVERVIEW:
-- Updates the Heirloom Adventurer's Shirt (300365) to include ALL primary stats
-- so it benefits all classes and specs. The stats scale with player level via
-- ScalingStatDistribution.
--
-- BEFORE: Only +10 Stamina
-- AFTER:  +Strength, +Agility, +Intellect, +Spirit, +Stamina (all scaling)
--
-- HOW SCALING WORKS:
-- - ScalingStatDistribution ID 300365 (custom) defines which stats scale
-- - ScalingStatValue determines the scaling factor per level
-- - heirloom_scaling_255.cpp extends scaling beyond level 80
--
-- ═══════════════════════════════════════════════════════════════════════════════

USE acore_world;

-- ═══════════════════════════════════════════════════════════════════════════════
-- UPDATE 1: Add all primary stats to the shirt
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- STAT TYPES:
--   3 = ITEM_MOD_AGILITY
--   4 = ITEM_MOD_STRENGTH
--   5 = ITEM_MOD_INTELLECT
--   6 = ITEM_MOD_SPIRIT
--   7 = ITEM_MOD_STAMINA
--
-- We use stat slots 1-5 for the primary stats.
-- Secondary stats from packages are applied via enchantments (not item stats).

UPDATE `item_template` SET
    -- Primary stat 1: Stamina (main survivability stat for all)
    `stat_type1` = 7,   -- Stamina
    `stat_value1` = 15, -- Base value (scales with level)
    
    -- Primary stat 2: Strength (melee physical)
    `stat_type2` = 4,   -- Strength
    `stat_value2` = 10, -- Base value
    
    -- Primary stat 3: Agility (rogues, hunters, feral)
    `stat_type3` = 3,   -- Agility
    `stat_value3` = 10, -- Base value
    
    -- Primary stat 4: Intellect (casters)
    `stat_type4` = 5,   -- Intellect
    `stat_value4` = 10, -- Base value
    
    -- Primary stat 5: Spirit (healers, mana regen)
    `stat_type5` = 6,   -- Spirit
    `stat_value5` = 8,  -- Slightly lower (less universally useful)
    
    -- Ensure scaling is enabled
    `ScalingStatDistribution` = 300365,  -- Custom SSD entry
    `ScalingStatValue` = 465,            -- Scaling tier (matches heirloom formula)
    
    -- Update description to reflect new functionality
    `description` = 'All primary stats scale with your level. Choose a secondary stat package and upgrade it for additional power!',
    
    -- Ensure proper flags for heirloom behavior
    `Flags` = 524288,  -- ITEM_FLAG_BIND_TO_ACCOUNT (heirloom flag)
    `Quality` = 7,     -- ITEM_QUALITY_HEIRLOOM
    
    -- Update item level for proper scaling baseline
    `ItemLevel` = 80
    
WHERE `entry` = 300365;


-- ═══════════════════════════════════════════════════════════════════════════════
-- UPDATE 2: Verify the ScalingStatDistribution entry exists
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- Note: ScalingStatDistribution.dbc needs a custom entry 300365.
-- The CSV should look like:
-- "300365","7","4","3","5","6","-1","-1","-1","-1","-1","10000","0","0","0","0","0","0","0","0","0","255"
--
-- Fields:
--   ID: 300365
--   StatMod[0]: 7 (Stamina)
--   StatMod[1]: 4 (Strength)
--   StatMod[2]: 3 (Agility)
--   StatMod[3]: 5 (Intellect)
--   StatMod[4]: 6 (Spirit)
--   StatMod[5-9]: -1 (unused)
--   Modifier[0]: 10000 (100% scaling for Stamina)
--   Modifier[1-9]: 0 (other modifiers)
--   MaxLevel: 255 (scale up to level 255)


-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERY
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT 
    `entry`,
    `name`,
    `Quality`,
    CASE `stat_type1` WHEN 3 THEN 'AGI' WHEN 4 THEN 'STR' WHEN 5 THEN 'INT' WHEN 6 THEN 'SPI' WHEN 7 THEN 'STA' ELSE `stat_type1` END AS 'Stat1',
    `stat_value1` AS 'Val1',
    CASE `stat_type2` WHEN 3 THEN 'AGI' WHEN 4 THEN 'STR' WHEN 5 THEN 'INT' WHEN 6 THEN 'SPI' WHEN 7 THEN 'STA' ELSE `stat_type2` END AS 'Stat2',
    `stat_value2` AS 'Val2',
    CASE `stat_type3` WHEN 3 THEN 'AGI' WHEN 4 THEN 'STR' WHEN 5 THEN 'INT' WHEN 6 THEN 'SPI' WHEN 7 THEN 'STA' ELSE `stat_type3` END AS 'Stat3',
    `stat_value3` AS 'Val3',
    CASE `stat_type4` WHEN 3 THEN 'AGI' WHEN 4 THEN 'STR' WHEN 5 THEN 'INT' WHEN 6 THEN 'SPI' WHEN 7 THEN 'STA' ELSE `stat_type4` END AS 'Stat4',
    `stat_value4` AS 'Val4',
    CASE `stat_type5` WHEN 3 THEN 'AGI' WHEN 4 THEN 'STR' WHEN 5 THEN 'INT' WHEN 6 THEN 'SPI' WHEN 7 THEN 'STA' ELSE `stat_type5` END AS 'Stat5',
    `stat_value5` AS 'Val5',
    `ScalingStatDistribution` AS 'SSD',
    `description`
FROM `item_template`
WHERE `entry` = 300365;

/*
Expected output:
+--------+----------------------------+---------+------+------+------+------+------+------+------+------+------+------+--------+
| entry  | name                       | Quality | Stat1| Val1 | Stat2| Val2 | Stat3| Val3 | Stat4| Val4 | Stat5| Val5 | SSD    |
+--------+----------------------------+---------+------+------+------+------+------+------+------+------+------+------+--------+
| 300365 | Heirloom Adventurer's Shirt| 7       | STA  | 15   | STR  | 10   | AGI  | 10   | INT  | 10   | SPI  | 8    | 300365 |
+--------+----------------------------+---------+------+------+------+------+------+------+------+------+------+------+--------+
*/


-- ═══════════════════════════════════════════════════════════════════════════════
-- SCALING FORMULA (for reference)
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- At level 1:   ~5-8 of each stat
-- At level 40:  ~25-40 of each stat
-- At level 80:  ~50-80 of each stat
-- At level 120: ~75-120 of each stat (via heirloom_scaling_255.cpp)
-- At level 200: ~125-200 of each stat
-- At level 255: ~160-255 of each stat
--
-- The exact values depend on ScalingStatValues.dbc and the extrapolation
-- formula in heirloom_scaling_255.cpp for levels above 80.


-- ═══════════════════════════════════════════════════════════════════════════════
-- END OF FILE
-- ═══════════════════════════════════════════════════════════════════════════════
