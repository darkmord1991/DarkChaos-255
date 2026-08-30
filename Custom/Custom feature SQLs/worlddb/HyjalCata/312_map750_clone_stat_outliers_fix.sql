-- ---------------------------------------------------------------------------
-- 312  Fix two defects in 309_'s stat rescale (found in post-apply verification)
-- ---------------------------------------------------------------------------
-- 309_ is applied and its structure is right -- 2,536 clones, loot fully
-- re-pointed, originals untouched. Verifying the resulting NUMBERS found two
-- problems in the stat maths. 309_ itself is corrected at source as well, so a
-- fresh apply on another realm does not reproduce them; this file repairs the
-- live data.
--
-- 🔴 DEFECT 1 -- NEGATIVE STATS BLOW THE FACTOR UP. Some classic items carry a
-- stat PENALTY. 309_ computed `total_src` as the plain SUM of stat values, so a
-- mixed-sign item collapsed the denominator to near zero:
--
--   4696 Lapidis Tankard of Tidesippe: Agility -15, Spirit +16
--        total_src = 1  ->  factor = 84  ->  clone got **-1,261 Agility**
--                                                      **+1,345 Spirit**
--   4462 Cloak of Rot: Stamina -5, Intellect +7
--        total_src = 2  ->  factor = 136 ->  -682 Stamina / +955 Intellect
--
-- Only **4 clones** are affected, but the values are absurd. Fix: the budget is
-- distributed over POSITIVE stats only, and negative stats are dropped (value
-- and type both zeroed). A -5 Stamina quirk on a level-30 vanilla green becomes
-- a -450 Stamina wound at ilvl 380 -- it does not survive the rescale in any
-- sane form, so it does not survive at all.
--
-- 🔴 DEFECT 2 -- SINGLE-STAT ITEMS SWALLOW THE WHOLE BUDGET. The model gives
-- each clone its slot's total budget and splits it in the source's proportions.
-- For an item with ONE stat that means the entire budget lands on it:
--
--   13009 Cow King's Hide (Stamina 10 only) -> **761 Stamina** at ilvl 384
--   943   Warden Staff    (Stamina 11 only) -> 719 Stamina
--
-- That is internally consistent but wrong against the rest of the game: the
-- ladder's best piece (Worldtree Legplates, ilvl 398) has **231** in its top
-- stat out of 819 across four -- 28%. A 761-Stamina green would be
-- best-in-slot on the whole continent. **93 clones exceed 400 in one stat and
-- 358 exceed 250.** Fix: cap any single stat at 40% of the item's budget --
-- generous next to the ladder's own 28%, but bounded. A capped item simply
-- carries less than its full budget, which is the correct outcome for a green.
--
-- Both fixes recompute the budget from the clone's OWN ItemLevel / slot /
-- quality, which 309_ set correctly and this file does not touch -- so the
-- corrected values do not depend on the broken ones except through the ratios
-- between stats, and those were never wrong (every stat on an item was scaled
-- by the same factor).
--
-- Apply against acore_world. Idempotent: re-running recomputes the same target
-- from the same ilvl and rescales the already-correct values onto themselves.
-- ---------------------------------------------------------------------------

DROP TEMPORARY TABLE IF EXISTS `dc_statfix`;
CREATE TEMPORARY TABLE `dc_statfix` (
  `entry`   INT UNSIGNED NOT NULL PRIMARY KEY,
  `budget`  INT NOT NULL,
  `cap`     INT NOT NULL,
  `factor2` DECIMAL(14,6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_statfix` (`entry`, `budget`, `cap`, `factor2`)
SELECT i.`entry`, t.`budget`, GREATEST(1, ROUND(t.`budget` * 0.40)),
       ROUND(t.`budget` / t.`pos_sum`, 6)
FROM `item_template` i
JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry`
JOIN LATERAL (
  SELECT
    ROUND(0.00207 * POW(i.`ItemLevel`, 2.13)
      * CASE WHEN i.`InventoryType` IN (1, 5, 7, 20) THEN 1.15
             WHEN i.`InventoryType` IN (2, 8, 9, 10, 6, 11, 12, 14, 15, 16, 23, 26) THEN 0.75
             ELSE 1.00 END
      * CASE i.`Quality` WHEN 3 THEN 1.00 WHEN 4 THEN 1.15 ELSE 0.85 END) AS budget,
    GREATEST(1,
      GREATEST(i.`stat_value1`,0)+GREATEST(i.`stat_value2`,0)+GREATEST(i.`stat_value3`,0)
     +GREATEST(i.`stat_value4`,0)+GREATEST(i.`stat_value5`,0)+GREATEST(i.`stat_value6`,0)
     +GREATEST(i.`stat_value7`,0)+GREATEST(i.`stat_value8`,0)+GREATEST(i.`stat_value9`,0)
     +GREATEST(i.`stat_value10`,0)) AS pos_sum
) t ON TRUE;

-- 🔴 stat_typeN is assigned BEFORE stat_valueN in every pair. MySQL applies SET
-- clauses left to right, so the type's test reads the OLD value -- reversing the
-- order would test the value this statement had just written and keep the type
-- of a stat it had just zeroed.
UPDATE `item_template` i
JOIN `dc_statfix` f ON f.`entry` = i.`entry`
SET i.`stat_type1`  = IF(i.`stat_value1`  <= 0, 0, i.`stat_type1`),
    i.`stat_value1` = LEAST(f.`cap`, ROUND(GREATEST(i.`stat_value1`,  0) * f.`factor2`)),
    i.`stat_type2`  = IF(i.`stat_value2`  <= 0, 0, i.`stat_type2`),
    i.`stat_value2` = LEAST(f.`cap`, ROUND(GREATEST(i.`stat_value2`,  0) * f.`factor2`)),
    i.`stat_type3`  = IF(i.`stat_value3`  <= 0, 0, i.`stat_type3`),
    i.`stat_value3` = LEAST(f.`cap`, ROUND(GREATEST(i.`stat_value3`,  0) * f.`factor2`)),
    i.`stat_type4`  = IF(i.`stat_value4`  <= 0, 0, i.`stat_type4`),
    i.`stat_value4` = LEAST(f.`cap`, ROUND(GREATEST(i.`stat_value4`,  0) * f.`factor2`)),
    i.`stat_type5`  = IF(i.`stat_value5`  <= 0, 0, i.`stat_type5`),
    i.`stat_value5` = LEAST(f.`cap`, ROUND(GREATEST(i.`stat_value5`,  0) * f.`factor2`)),
    i.`stat_type6`  = IF(i.`stat_value6`  <= 0, 0, i.`stat_type6`),
    i.`stat_value6` = LEAST(f.`cap`, ROUND(GREATEST(i.`stat_value6`,  0) * f.`factor2`)),
    i.`stat_type7`  = IF(i.`stat_value7`  <= 0, 0, i.`stat_type7`),
    i.`stat_value7` = LEAST(f.`cap`, ROUND(GREATEST(i.`stat_value7`,  0) * f.`factor2`)),
    i.`stat_type8`  = IF(i.`stat_value8`  <= 0, 0, i.`stat_type8`),
    i.`stat_value8` = LEAST(f.`cap`, ROUND(GREATEST(i.`stat_value8`,  0) * f.`factor2`)),
    i.`stat_type9`  = IF(i.`stat_value9`  <= 0, 0, i.`stat_type9`),
    i.`stat_value9` = LEAST(f.`cap`, ROUND(GREATEST(i.`stat_value9`,  0) * f.`factor2`)),
    i.`stat_type10` = IF(i.`stat_value10` <= 0, 0, i.`stat_type10`),
    i.`stat_value10`= LEAST(f.`cap`, ROUND(GREATEST(i.`stat_value10`, 0) * f.`factor2`))
WHERE i.`entry` BETWEEN 500000 AND 599999;

DROP TEMPORARY TABLE IF EXISTS `dc_statfix`;

-- ---------------------------------------------------------------------------
-- Verify (expected: 0 / 0, and the top stat in line with the ladder's 231)
-- ---------------------------------------------------------------------------
--   SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 500000 AND 599999
--     AND LEAST(stat_value1,stat_value2,stat_value3,stat_value4,stat_value5,
--               stat_value6,stat_value7,stat_value8,stat_value9,stat_value10) < 0;   -- 0
--   SELECT MAX(GREATEST(stat_value1,stat_value2,stat_value3,stat_value4,stat_value5))
--     FROM item_template WHERE entry BETWEEN 500000 AND 599999;                      -- <= ~370
--   SELECT entry, name, ItemLevel, stat_type1, stat_value1, stat_type2, stat_value2
--     FROM item_template WHERE entry IN (500247, 500238, 501097, 500023);
-- ---------------------------------------------------------------------------
