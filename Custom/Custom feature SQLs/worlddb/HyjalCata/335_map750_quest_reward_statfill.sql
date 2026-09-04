-- ---------------------------------------------------------------------------
-- 335  Fill the 145 empty map-750 quest reward items
-- ---------------------------------------------------------------------------
-- 323_ closed with "the real gap is closed -- which is to restore ItemLevel on
-- the 57260+ ... items". This is that follow-through.
--
-- 145 green-or-better items handed out by map-750 quests are empty shells:
--
--     ItemLevel 0     stats: none at all      RequiredLevel 1
--     123 armour pieces with armor = 0
--     22 weapons with dmg_min1 = 0
--
-- They are STOCK Cata entries (52583-71270), so 319_'s clone-band stat
-- generation -- which keys off `dc_map750_item_clone` -- never saw them.
--
-- 🔴 Consequence beyond being weak: `ItemLevel = 0` matches NO row in
-- `dc_item_upgrade_tiers`, whose ranges are 1-212 / 213-299 / 300-411 / 412+.
-- `GetItemTier` (ItemUpgradeManager.cpp:1240) therefore returns TIER_INVALID and
-- the item is silently NOT UPGRADEABLE. Item level 0 is the only un-upgradeable
-- case in the whole system, and all 145 of these have it.
--
-- ---------------------------------------------------------------------------
-- 🔴 DO NOT "FIX" THESE FROM RETAIL
-- ---------------------------------------------------------------------------
-- `retroport_tools/_wago_69497/ItemSparse.csv` contains every one of them, and
-- copying it would be WRONG. Their real item levels are 5, 11 and 37: these are
-- Cataclysm's LOW-LEVEL zone quest rewards (the Darkshore / Ashenvale revamp,
-- levels 5-20 in retail) which DC re-purposed as 80-130 content. Retail values
-- would hand a level-91 player ilvl-5 gear.
--
-- They have to be scaled to the DC band the way 309_/319_/321_/323_ scale the
-- clone band, which is what this file does.
--
-- ---------------------------------------------------------------------------
-- THE MODEL -- all three parts reused, none invented
-- ---------------------------------------------------------------------------
-- BAND      `dc_map750_band` maps zone -> target level range. Each item is
--           assigned the band of its LOWEST-level questgiver, using 322_'s rule
--           `MAX(t_lo) WHERE t_lo <= level`. Lowest, not average, so an item
--           offered in two zones is tuned for the earlier one.
--
-- ITEMLEVEL 309_/323_'s per-band targets, +8 blue / +16 epic (323_ set band 113
--           to 388 green / 396 blue, so the step is 8):
--               band  80 -> 285    band  88 -> 315    band  96 -> 355
--               band 104 -> 372    band 113 -> 388
--
-- REQLEVEL  321_'s curve `ROUND(0.294 * ItemLevel - 6.1)`, clamped into the
--           band's own [t_lo, t_hi] so a reward can never gate above the zone
--           that gives it.
--
-- STATS     319_'s budget `0.00207 * ilvl^2.13 * slot_weight * quality_mult`
--           with 319_'s archetype table, split 32/28/23/17 across four stats.
--
-- Resulting spread (verified against the live DB, 145 items, all accounted for):
--     band  80   15 green @285    3 blue @293
--     band  88    7 green @315    7 blue @323
--     band  96    8 green @355
--     band 104    3 green @372    1 blue @380
--     band 113   87 green @388   10 blue @396   4 epic @404
--
-- ---------------------------------------------------------------------------
-- 🔴 ARMOUR AND WEAPON DAMAGE ARE **NOT** IN THIS FILE
-- ---------------------------------------------------------------------------
-- In Cata both are DERIVED from curve DBCs, not stored, so they come from
-- `Custom/Documentation/scripts/gen_zone_gear_armor_dmg.py` against the real
-- 4.3.4 curves in `K:/tmp/cata-itemcurves` -- exactly as 310_ was produced.
--
-- That generator's input filter is `armor = 0 AND dmg_min1 = 0 AND ItemLevel > 0`.
-- **It therefore cannot run until this file has set ItemLevel.** Run this, then
-- the generator, then apply its output as 336_.
--
-- `delay` is set here rather than there for the same reason: the generator reads
-- it (`avg = dps * delay / 1000`). All 145 carry the placeholder `delay = 1000`,
-- a 1.0s swing on everything including two-handers. DPS would still come out
-- right -- the generator divides by the same delay it multiplies back -- but a
-- greatsword swinging once a second is wrong to look at and wrong for anything
-- that keys off weapon speed.
--
-- Apply against acore_world. Idempotent -- the item set is frozen in a staging
-- table on first run, so a re-run still finds the same 145 after ItemLevel is
-- no longer 0. Needs a worldserver restart.
-- ---------------------------------------------------------------------------

-- 🔴 NO `USE` STATEMENT ON PURPOSE. **Select acore_world in your client**
-- before running this. A `USE `acore_world`;` line here was fed back as the
-- literal token `acore_world` glued to the following comment --
--   SQL error 1064 ... near 'acore_world-- ------'
-- because the client's statement splitter lost the terminating semicolon. The
-- file itself was byte-clean (no BOM, LF, semicolon present); dropping the USE
-- removes the only construct that can produce that token. Every statement below
-- names its tables unqualified, so the client's selected schema is what counts.

-- ---------------------------------------------------------------------------
-- 1. Freeze the target set + snapshot the originals
-- ---------------------------------------------------------------------------
-- 🔴 THE SET MUST BE FROZEN, not re-derived. The natural selector is
-- `ItemLevel = 0`, which this file then destroys -- so a second run would match
-- nothing and any later correction would silently no-op. INSERT IGNORE against a
-- PRIMARY KEY captures the set once and every step below reads from it.
CREATE TABLE IF NOT EXISTS `dc_map750_questreward_fix` (
  `entry`      INT UNSIGNED NOT NULL,
  `band`       SMALLINT     NOT NULL,
  `new_ilvl`   SMALLINT     NOT NULL,
  `new_req`    SMALLINT     NOT NULL,
  `budget`     INT          NOT NULL,
  `s1` SMALLINT NOT NULL, `s2` SMALLINT NOT NULL,
  `s3` SMALLINT NOT NULL, `s4` SMALLINT NOT NULL,
  `old_ilvl`   SMALLINT     NOT NULL,
  `old_req`    SMALLINT     NOT NULL,
  `old_delay`  SMALLINT     NOT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_map750_questreward_fix`
  (`entry`,`band`,`new_ilvl`,`new_req`,`budget`,`s1`,`s2`,`s3`,`s4`,`old_ilvl`,`old_req`,`old_delay`)
SELECT
  d.`entry`,
  d.`band`,
  d.`ilvl`,
  LEAST(d.`t_hi`, GREATEST(d.`band`, ROUND(0.294 * d.`ilvl` - 6.1))),
  GREATEST(4, ROUND(0.00207 * POW(d.`ilvl`, 2.13) * d.`slotw` * d.`qmul`)),
  a.`s1`, a.`s2`, a.`s3`, a.`s4`,
  0, d.`old_req`, d.`old_delay`
FROM (
  SELECT
    i.`entry`,
    i.`Quality`,
    i.`RequiredLevel` AS `old_req`,
    i.`delay`         AS `old_delay`,
    b.`band`,
    b.`t_hi`,
    CASE b.`band` WHEN 80 THEN 285 WHEN 88 THEN 315 WHEN 96 THEN 355
                  WHEN 104 THEN 372 ELSE 388 END
      + CASE i.`Quality` WHEN 3 THEN 8 WHEN 4 THEN 16 ELSE 0 END AS `ilvl`,
    CASE WHEN i.`InventoryType` IN (1, 5, 7, 20) THEN 1.15
         WHEN i.`InventoryType` IN (2, 8, 9, 10, 6, 11, 12, 14, 15, 16, 23, 26) THEN 0.75
         ELSE 1.00 END AS `slotw`,
    CASE i.`Quality` WHEN 3 THEN 1.00 WHEN 4 THEN 1.15 ELSE 0.85 END AS `qmul`,
    CASE
      WHEN i.`class` = 4 AND i.`subclass` = 1 THEN 'cloth'
      WHEN i.`class` = 4 AND i.`subclass` = 2 THEN 'leather'
      WHEN i.`class` = 4 AND i.`subclass` = 3 THEN 'mail'
      WHEN i.`class` = 4 AND i.`subclass` = 4 THEN 'plate'
      WHEN i.`class` = 4 AND i.`subclass` = 6 THEN 'shield'
      WHEN i.`class` = 4                      THEN 'misc'
      WHEN i.`class` = 2 AND i.`subclass` IN (2, 3, 15, 16, 18) THEN 'wep_agi'
      WHEN i.`class` = 2 AND i.`subclass` IN (10, 19)           THEN 'wep_int'
      ELSE 'wep_str'
    END AS `arch`,
    CASE WHEN i.`class` = 4 AND i.`subclass` NOT IN (1,2,3,4,6) THEN i.`entry` % 3
         ELSE i.`entry` % 2 END AS `variant`
  FROM `item_template` i
  JOIN (
    -- lowest questgiver level -> band, via 322_'s rule
    SELECT x.`entry`,
           COALESCE((SELECT MAX(bb.`t_lo`) FROM (SELECT DISTINCT `t_lo` FROM `dc_map750_band`) bb
                     WHERE bb.`t_lo` <= x.`lvl`), 80) AS `band`,
           COALESCE((SELECT MAX(bb2.`t_hi`) FROM (SELECT DISTINCT `t_lo`,`t_hi` FROM `dc_map750_band`) bb2
                     WHERE bb2.`t_lo` <= x.`lvl`), 90) AS `t_hi`
    FROM (
      SELECT it.`entry`, MIN(ct.`minlevel`) AS `lvl`
      FROM `item_template` it
      JOIN `quest_template` q
        ON it.`entry` IN (q.`RewardItem1`, q.`RewardItem2`, q.`RewardItem3`, q.`RewardItem4`,
                          q.`RewardChoiceItemID1`, q.`RewardChoiceItemID2`, q.`RewardChoiceItemID3`,
                          q.`RewardChoiceItemID4`, q.`RewardChoiceItemID5`, q.`RewardChoiceItemID6`)
      JOIN (SELECT `quest`, `id` FROM `creature_questender`
            UNION SELECT `quest`, `id` FROM `creature_queststarter`) qg ON qg.`quest` = q.`ID`
      JOIN `creature_template` ct ON ct.`entry` = qg.`id`
                                 AND ct.`entry` BETWEEN 3600000 AND 3799999
      WHERE it.`class` IN (2, 4) AND it.`InventoryType` > 0
        AND it.`ItemLevel` = 0 AND it.`Quality` >= 2
      GROUP BY it.`entry`
    ) x
  ) b ON b.`entry` = i.`entry`
) d
JOIN (
  -- 319_'s archetypes, pivoted to one row per (arch, variant) so this is read
  -- ONCE. 319_ hit MySQL 1137 "Can't reopen table" by reading a TEMPORARY table
  -- eleven times in a single statement; a derived table joined once cannot.
            SELECT 'cloth'   AS `arch`, 0 AS `variant`, 45 AS `s1`,  7 AS `s2`,  5 AS `s3`, 32 AS `s4`
  UNION ALL SELECT 'cloth',   1, 45,  7,  5,  6
  UNION ALL SELECT 'leather', 0, 38,  7,  3, 32
  UNION ALL SELECT 'leather', 1, 45,  7,  5, 36
  UNION ALL SELECT 'mail',    0, 38,  7,  3, 31
  UNION ALL SELECT 'mail',    1, 45,  7,  5, 32
  UNION ALL SELECT 'plate',   0,  4,  7, 32, 36
  UNION ALL SELECT 'plate',   1,  4,  7, 12, 13
  UNION ALL SELECT 'shield',  0,  7,  4, 12, 13
  UNION ALL SELECT 'shield',  1,  7,  5, 45,  6
  UNION ALL SELECT 'misc',    0,  7,  3, 38, 32
  UNION ALL SELECT 'misc',    1,  7,  5, 45, 32
  UNION ALL SELECT 'misc',    2,  7,  4, 38, 31
  UNION ALL SELECT 'wep_str', 0,  4,  7, 32, 31
  UNION ALL SELECT 'wep_str', 1,  4,  7, 37, 36
  UNION ALL SELECT 'wep_agi', 0,  3,  7, 38, 32
  UNION ALL SELECT 'wep_agi', 1,  3,  7, 31, 36
  UNION ALL SELECT 'wep_int', 0, 45,  7,  5, 32
  UNION ALL SELECT 'wep_int', 1, 45,  7,  5, 36
) a ON a.`arch` = d.`arch` AND a.`variant` = d.`variant`;

-- ---------------------------------------------------------------------------
-- 2. ItemLevel and RequiredLevel
-- ---------------------------------------------------------------------------
UPDATE `item_template` i
JOIN `dc_map750_questreward_fix` f ON f.`entry` = i.`entry`
SET i.`ItemLevel`     = f.`new_ilvl`,
    i.`RequiredLevel` = f.`new_req`;

-- ---------------------------------------------------------------------------
-- 3. Weapon delay -- must precede the armour/damage generator
-- ---------------------------------------------------------------------------
-- Standard 3.3.5 speeds by weapon subclass. Armour keeps delay 1000; the field
-- is meaningless for it and the generator ignores it.
UPDATE `item_template` i
JOIN `dc_map750_questreward_fix` f ON f.`entry` = i.`entry`
SET i.`delay` = CASE
      WHEN i.`subclass` = 15 THEN 1800                      -- dagger
      WHEN i.`subclass` = 19 THEN 1700                      -- wand
      WHEN i.`subclass` = 16 THEN 2000                      -- thrown
      WHEN i.`subclass` IN (2, 3, 18) THEN 2900             -- bow / gun / crossbow
      WHEN i.`subclass` IN (1, 5, 6, 8, 10) THEN 3600       -- two-handers, polearm, staff
      ELSE 2600                                             -- one-hand axe/mace/sword/fist
    END
WHERE i.`class` = 2;

-- ---------------------------------------------------------------------------
-- 4. Stats -- four per item, 32/28/23/17 of budget
-- ---------------------------------------------------------------------------
-- Slots 5-10 are cleared: these items had nothing, so anything in the tail would
-- be leftovers rather than intent.
UPDATE `item_template` i
JOIN `dc_map750_questreward_fix` f ON f.`entry` = i.`entry`
-- 🔴 No `StatsCount` assignment: that column does NOT exist in this fork's
-- `item_template` (verified against information_schema). The 3.3.5 client reads
-- the stat slots directly and stops at the first stat_type = 0, so zeroing slots
-- 5-10 below is what actually terminates the list.
SET i.`stat_type1`  = f.`s1`, i.`stat_value1` = GREATEST(1, ROUND(f.`budget` * 0.32)),
    i.`stat_type2`  = f.`s2`, i.`stat_value2` = GREATEST(1, ROUND(f.`budget` * 0.28)),
    i.`stat_type3`  = f.`s3`, i.`stat_value3` = GREATEST(1, ROUND(f.`budget` * 0.23)),
    i.`stat_type4`  = f.`s4`, i.`stat_value4` = GREATEST(1, ROUND(f.`budget` * 0.17)),
    i.`stat_type5`  = 0, i.`stat_value5`  = 0, i.`stat_type6`  = 0, i.`stat_value6`  = 0,
    i.`stat_type7`  = 0, i.`stat_value7`  = 0, i.`stat_type8`  = 0, i.`stat_value8`  = 0,
    i.`stat_type9`  = 0, i.`stat_value9`  = 0, i.`stat_type10` = 0, i.`stat_value10` = 0;

-- ---------------------------------------------------------------------------
-- Trailer -- verification, then the REQUIRED next step
-- ---------------------------------------------------------------------------
-- Expect 145 staged rows:
-- SELECT COUNT(*) FROM dc_map750_questreward_fix;
--
-- Expect 0 -- nothing left at ItemLevel 0, i.e. everything is now upgradeable:
-- SELECT COUNT(*) FROM item_template i
-- JOIN dc_map750_questreward_fix f ON f.entry = i.entry WHERE i.ItemLevel = 0;
--
-- Spot-check the spread by band (expect 285/293, 315/323, 355, 372/380,
-- 388/396/404 and RequiredLevel inside each band):
-- SELECT f.band, i.Quality, COUNT(*) AS n, MIN(i.ItemLevel) AS ilvl,
--        MIN(i.RequiredLevel) AS req, MIN(i.stat_value1) AS top_stat
-- FROM item_template i JOIN dc_map750_questreward_fix f ON f.entry = i.entry
-- GROUP BY f.band, i.Quality ORDER BY f.band, i.Quality;
--
-- 🔴 Every one now resolves to a real upgrade tier (expect NO row with tier 0 --
-- this mirrors GetItemTier's ilvl matching):
-- SELECT i.entry, i.name, i.ItemLevel,
--        (SELECT MAX(t.tier_id) FROM dc_item_upgrade_tiers t
--         WHERE t.is_artifact = 0 AND t.min_ilvl > 0
--           AND i.ItemLevel >= t.min_ilvl
--           AND (t.max_ilvl = 0 OR i.ItemLevel <= t.max_ilvl)) AS tier
-- FROM item_template i JOIN dc_map750_questreward_fix f ON f.entry = i.entry
-- HAVING tier IS NULL;
--
-- TO REVERT: old_ilvl / old_req / old_delay are in dc_map750_questreward_fix
-- (stats were all zero to begin with, which is why no stat backup is kept):
-- UPDATE item_template i JOIN dc_map750_questreward_fix f ON f.entry = i.entry
-- SET i.ItemLevel = f.old_ilvl, i.RequiredLevel = f.old_req, i.delay = f.old_delay,
--     i.stat_type1 = 0, i.stat_value1 = 0, i.stat_type2 = 0,
--     i.stat_value2 = 0, i.stat_type3 = 0, i.stat_value3 = 0, i.stat_type4 = 0,
--     i.stat_value4 = 0;
--
-- ---------------------------------------------------------------------------
-- 🔴 REQUIRED NEXT STEP -- 123 armour pieces still have armor = 0 and 22 weapons
-- still have dmg_min1 = 0. They are NOT filled here because Cata derives both
-- from curve DBCs. Now that ItemLevel is set, run:
--
--   1) export the generator's input (its documented query, restricted to these):
--      SELECT it.entry, it.ItemLevel, it.Quality, it.class, it.subclass,
--             it.InventoryType, it.delay,
--             (it.stat_type1=5 OR it.stat_type2=5 OR it.stat_type3=5
--              OR it.stat_type4=5) AS caster
--      FROM item_template it
--      JOIN dc_map750_questreward_fix f ON f.entry = it.entry
--      WHERE it.armor = 0 AND it.dmg_min1 = 0 AND it.ItemLevel > 0;
--
--   2) python Custom/Documentation/scripts/gen_zone_gear_armor_dmg.py \
--        --dbc-dir K:/tmp/cata-itemcurves --items-csv <that>.csv \
--        --out 336_map750_questreward_armor_dmg.sql
--
--   3) apply 336_.
--
-- 🔴 These items are already in Item.dbc (they are stock Cata entries the client
-- knows), so unlike 329_'s generated gear this needs NO DBC or MPQ work. But the
-- client caches item data: bump the cache id, or players keep seeing the old
-- statless tooltip.
-- ---------------------------------------------------------------------------
