-- ---------------------------------------------------------------------------
-- 315  Make creatures above level 83 actually dangerous (x3 HP / x5 damage)
-- ---------------------------------------------------------------------------
-- ⚠ THIS IS A GLOBAL CHANGE, not a map-750 one. `creature_classlevelstats` is
-- keyed only by (level, class), so every creature at level 84+ on every map is
-- affected -- ~32,000 spawns, mostly maps 751 (14,061), 750 (12,786), 646
-- (2,922) and 861 (1,159). It lives in this folder because this is the active
-- chain, not because it is Hyjal-specific.
--
-- WHY IT WAS NEEDED -- two independent things stacked:
--
-- 1. **Every map-750 creature is `exp = 0`**, the CLASSIC stat column. At level
--    80 that is 5,342 HP / 47.2 damage, where WotLK's own level-80 values
--    (basehp2 / damage_exp2) are 12,600 / 164.9. The whole 80-130 continent was
--    running on **42% of the HP and 29% of the damage of a WotLK mob at the
--    same level**.
-- 2. **The 84-255 extension of this table is LINEAR**: +170 HP and +0.67 damage
--    per level, flat forever. So it never catches up. A level-130 mob had
--    13,791 HP and hit for 80.6 -- **0.24% of a player's health per swing**,
--    against WotLK trash's 0.82%.
--
-- THE CURVE. A geometric ramp anchored at level 83, reaching **x3 health and
-- x5 damage at level 130**, then HELD FLAT at x3/x5 for 131-255:
--
--     ramp     = (LEAST(level, 130) - 83) / 47
--     hp   x= POW(3.0, ramp)        dmg x= POW(5.0, ramp)
--
--   lvl   HP before -> after     dmg before -> after    % of player HP/swing
--    90     6,991 ->   8,234      53.9 ->    69          0.34% -> 0.4%
--   100     8,691 ->  12,931      60.6 ->   108          0.30% -> 0.5%
--   110    10,391 ->  19,532      67.2 ->   169          0.27% -> 0.7%
--   120    12,091 ->  28,712      73.9 ->   262          0.25% -> 0.9%
--   130    13,791 ->  41,373      80.6 ->   403          0.24% -> 1.2%
--
-- Level 84 starts at x1.02 / x1.04, so the change is invisible at the bottom and
-- builds -- there is no cliff where players suddenly hit a wall.
--
-- 🔴 LEVELS 80-83 ARE DELIBERATELY UNTOUCHED. That is where Naxxramas (533),
-- Ulduar (603), ICC (631) and BWD (669) sit, and their encounters are tuned
-- against stock values. The ramp being 1.0 at 83 is what keeps them exact.
--
-- 🔴 THE `basehp = 1` PLACEHOLDER MUST NOT BE SCALED. Some rows carry 1 in a
-- basehp column as a "not set" marker -- class 8 level 83 basehp1 is one --
-- and `ObjectMgr.cpp:10730` borrows a real value from another column whenever
-- it sees <= 1. Multiplying 1 by 3 gives 3, which is > 1, so the fallback would
-- stop firing and those creatures would spawn with **3 HP**. Every health
-- assignment below is therefore guarded on `> 1`.
--
-- WHAT IS NOT TOUCHED: `basearmor`, `attackpower`, `rangedattackpower` and the
-- stat columns. Armour would change how long fights last in a way that is felt
-- as "spongy" rather than "dangerous", and it was not what was asked for.
--
-- Lore NPCs scale too -- Thrall (HealthModifier 1200) goes from 12.5M to 37M --
-- but they are unkillable set-dressing by design, so it changes nothing.
--
-- STILL AVAILABLE, NOT APPLIED: setting `creature_template.exp = 2` on the
-- map-750/751/861 creatures would move them off the Classic column onto WotLK's,
-- worth roughly another x2.6 HP and x3.7 damage on top of this. The table above
-- is computed on the exp-0 columns those creatures actually use, so what you see
-- is what you get -- the exp lever is a separate decision.
--
-- Apply against acore_world, then restart worldserver. Idempotent: every value
-- is recomputed from the frozen backup, never from the current value.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Freeze the originals
-- ---------------------------------------------------------------------------
-- INSERT IGNORE with no DELETE, for the same reason 233_ freezes
-- dc_map750_snap: the backup must hold the PRE-change numbers. A second run
-- must not "back up" the values this file just wrote.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_clstats_backup` (
  `level`        TINYINT UNSIGNED NOT NULL,
  `class`        TINYINT UNSIGNED NOT NULL,
  `basehp0`      INT UNSIGNED NOT NULL,
  `basehp1`      INT UNSIGNED NOT NULL,
  `basehp2`      INT UNSIGNED NOT NULL,
  `damage_base`  FLOAT NOT NULL,
  `damage_exp1`  FLOAT NOT NULL,
  `damage_exp2`  FLOAT NOT NULL,
  `backed_up_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`level`, `class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_clstats_backup`
    (`level`,`class`,`basehp0`,`basehp1`,`basehp2`,`damage_base`,`damage_exp1`,`damage_exp2`)
SELECT `level`, `class`, `basehp0`, `basehp1`, `basehp2`,
       `damage_base`, `damage_exp1`, `damage_exp2`
FROM `creature_classlevelstats`
WHERE `level` BETWEEN 84 AND 255;

-- ---------------------------------------------------------------------------
-- B) Apply the curve, always reading the backup
-- ---------------------------------------------------------------------------
UPDATE `creature_classlevelstats` s
JOIN `dc_clstats_backup` b ON b.`level` = s.`level` AND b.`class` = s.`class`
SET s.`basehp0` = IF(b.`basehp0` > 1,
      GREATEST(2, ROUND(b.`basehp0` * POW(3.0, (LEAST(s.`level`, 130) - 83) / 47.0))), b.`basehp0`),
    s.`basehp1` = IF(b.`basehp1` > 1,
      GREATEST(2, ROUND(b.`basehp1` * POW(3.0, (LEAST(s.`level`, 130) - 83) / 47.0))), b.`basehp1`),
    s.`basehp2` = IF(b.`basehp2` > 1,
      GREATEST(2, ROUND(b.`basehp2` * POW(3.0, (LEAST(s.`level`, 130) - 83) / 47.0))), b.`basehp2`),
    s.`damage_base` = b.`damage_base` * POW(5.0, (LEAST(s.`level`, 130) - 83) / 47.0),
    s.`damage_exp1` = b.`damage_exp1` * POW(5.0, (LEAST(s.`level`, 130) - 83) / 47.0),
    s.`damage_exp2` = b.`damage_exp2` * POW(5.0, (LEAST(s.`level`, 130) - 83) / 47.0)
WHERE s.`level` BETWEEN 84 AND 255;

-- All three health columns and all three damage columns move together, so a
-- creature's relative standing does not depend on which `exp` value it carries
-- -- only its absolute numbers change.

-- ---------------------------------------------------------------------------
-- Verify (688 rows; class 1 samples)
-- ---------------------------------------------------------------------------
--   SELECT COUNT(*) FROM dc_clstats_backup;                                -- 688
--   SELECT level, basehp0, ROUND(damage_base,1) dmg FROM creature_classlevelstats
--    WHERE class = 1 AND level IN (83,84,90,100,110,120,130,131,255) ORDER BY level;
--     -> 83 unchanged 5808 / 49.2
--        90   8234 /  69      100  12931 / 108     110  19532 / 169
--        120 28712 / 262      130  41373 / 403     131  41883 / 406
--        255 105123 / 819     (flat x3 / x5 above 130)
--   -- nothing below 84 moved -- check the anchor itself, not the backup join
--   -- (the backup only holds 84+, so joining it proves nothing):
--   SELECT level, basehp0, ROUND(damage_base,2) FROM creature_classlevelstats
--    WHERE class = 1 AND level IN (80,83);      -- must still be 5342/47.24 and 5808/49.24
--   -- no placeholder was promoted:
--   SELECT COUNT(*) FROM creature_classlevelstats WHERE basehp0 = 2 OR basehp1 = 2 OR basehp2 = 2;
--
-- REVERT:
--   UPDATE creature_classlevelstats s JOIN dc_clstats_backup b
--      ON b.level = s.level AND b.class = s.class
--     SET s.basehp0 = b.basehp0, s.basehp1 = b.basehp1, s.basehp2 = b.basehp2,
--         s.damage_base = b.damage_base, s.damage_exp1 = b.damage_exp1,
--         s.damage_exp2 = b.damage_exp2;
--   DROP TABLE dc_clstats_backup;
-- ---------------------------------------------------------------------------
