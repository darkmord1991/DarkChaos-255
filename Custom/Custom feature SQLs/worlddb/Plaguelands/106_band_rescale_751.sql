-- 106_band_rescale_751.sql -- map 751 HP/mana/damage band re-scale, DB step 45.
--
-- THE SYMPTOM
--   Thule Ravenclaw, a level 142 RARE, shows 16,136 health and 40,484 mana --
--   less health than his own mana pool, and well under half of the 39,396 a
--   level-131 player carries. The 130-160 band was re-leveled but never re-scaled.
--
-- WHAT WAS ACTUALLY WRONG
--   `creature_classlevelstats` is fine: fully populated to level 255, smooth curve.
--   The levels are fine too: `dc_map751_band` already mapped every zone onto its
--   segment (Tirisfal 130-136 ... EPL 152-158) and the creatures carry those levels.
--   What was never done is the stat half. Each creature kept whatever
--   HealthModifier its level 1-50 source mob happened to have, so the effective
--   curve is flat and noisy rather than banded:
--
--     level 136 -> 24,014 avg HP      level 137 -> 14,981
--     level 142 -> 24,814             level 145 -> 14,319
--
--   Thule reproduces exactly: basehp0 10757 x 1.5 = 16,136, basemana 20242 x 2 = 40,484.
--
-- THE DESIGN -- stats become a FUNCTION of (level, class, rank) instead of an
-- inherited per-mob accident. Because the levels already come from the band table,
-- making stats a function of level makes them band-derived by construction: every
-- Tirisfal mob lands on the 130-136 segment of one smooth curve, every EPL mob on
-- the 152-158 segment, and the per-level noise disappears.
--
--   target effective HP = basehp2(level, class) x rank_factor
--
--   `basehp2` is the reference curve on purpose. It is smooth, level-indexed, already
--   in the database, and at level 142 it gives 41,321 -- almost exactly the observed
--   level-131 player's 39,396. So "x1.0 of basehp2" reads as "one player's worth of
--   health", which is the unit the rank factors are expressed in.
--
-- WHY NOT JUST SET exp = 2 -- THE TRAP THAT LOOKS LIKE THE ONE-LINE FIX.
--   1,456 of 1,472 entries have exp = 0, which is why they use basehp0 (the classic
--   column) at all. Flipping exp to 2 would lift HP 2.6x and fix mana in one column
--   change -- and would ALSO switch the damage column, because `exp` selects
--   damage_base / damage_exp1 / damage_exp2 as well. At level 142 that is
--   88.6 -> 416.0, a 4.7x damage jump on every mob on the continent. exp is left alone.
--
-- NOTHING IS NERFED. Every modifier is applied as GREATEST(original, target), so the
-- deliberately hand-tuned outliers survive untouched -- the 38 elites above 10x, the
-- 1200x elite, and the two rank-3 bosses (excluded outright). Only mobs BELOW the
-- curve are lifted onto it. Measured effect:
--
--     rank            entries   old avg HP -> new avg HP    raised / unchanged
--     0 normal          1235        20,108 ->    23,907        996 / 239
--     1 elite            154       401,177 ->   518,958        119 /  35
--     2 rare elite         4       673,249 ->   927,045          3 /   1
--     4 rare              57        25,377 ->   105,110         57 /   0   <-- the real gap
--
--   Rares were uniformly 1x-3x with NO outliers, i.e. a silver dragon that died faster
--   than the player's own health bar. They are the one rank that changes character.
--
-- MANA IS CAPPED, NOT SCALED. `basemana` is a single curve while HP uses the weakest
-- of three columns, which is why casters overtake their own health at high level. The
-- HP lift alone fixes only 5 of the 71 cases; the rest need the explicit cap
-- ManaModifier <= new_HP / basemana. Mana is never raised.
--
-- SCOPE. map 751, zone in `dc_map751_band` (so Undercity and anything unzoned is out),
-- maxlevel 130-160, rank <> 3 (the two bosses are hand-tuned), type <> 8 (critters).
--
-- ONE ROW PER ENTRY, NOT PER (ENTRY, ZONE). 40 entries are spawned in more than one
-- zone -- 3606491 has 13 spawns in Eastern Plaguelands and 6 in Western -- so a plain
-- `SELECT DISTINCT id, zoneId` yields that entry twice and collides on the staging
-- primary key (1062). The zone does NOT enter the maths at all (that is level, class
-- and rank only); it is used to scope the work and to label the report. So each entry
-- is resolved to its DOMINANT zone -- the one holding most of its spawns, ties broken
-- by the lower zone id -- via ROW_NUMBER, which is deterministic and re-runnable.
--
-- REVERSIBLE AND IDEMPOTENT. `dc_map751_stat_snap` freezes the ORIGINAL modifiers on
-- first run via INSERT IGNORE, and every calculation derives from that snapshot rather
-- than from current values -- so re-running cannot ratchet upward, and the snapshot is
-- the restore path. That table is deliberately NOT dropped, exactly like dc_map750_snap.
-- Tunables live in `dc_map751_rank_scale`: edit it and re-run this file.

-- ---------------------------------------------------------------------------
-- 1. Tunables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_map751_rank_scale` (
  `rank` TINYINT UNSIGNED NOT NULL,
  `hp_factor` FLOAT NOT NULL DEFAULT 1,
  `dmg_floor` FLOAT NOT NULL DEFAULT 1,
  `comment` VARCHAR(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DELETE FROM `dc_map751_rank_scale` WHERE `rank` IN (0, 1, 2, 4);
INSERT INTO `dc_map751_rank_scale` (`rank`, `hp_factor`, `dmg_floor`, `comment`) VALUES
(0, 0.50, 1.0, 'normal -- half a player, matches the current sane value'),
(4, 2.50, 1.5, 'rare -- a real solo fight; was effectively a normal mob'),
(1, 5.00, 2.0, 'elite -- group content'),
(2, 8.00, 3.0, 'rare elite');

-- ---------------------------------------------------------------------------
-- 2. Freeze the originals (first run only)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_map751_stat_snap` (
  `entry` INT UNSIGNED NOT NULL,
  `HealthModifier` FLOAT NOT NULL DEFAULT 1,
  `ManaModifier` FLOAT NOT NULL DEFAULT 1,
  `DamageModifier` FLOAT NOT NULL DEFAULT 1,
  `ArmorModifier` FLOAT NOT NULL DEFAULT 1,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_map751_stat_snap`
  (`entry`, `HealthModifier`, `ManaModifier`, `DamageModifier`, `ArmorModifier`)
SELECT t.`entry`, t.`HealthModifier`, t.`ManaModifier`, t.`DamageModifier`, t.`ArmorModifier`
FROM (SELECT `id`, `zoneId` FROM (
        SELECT `id`, `zoneId`,
               ROW_NUMBER() OVER (PARTITION BY `id` ORDER BY COUNT(*) DESC, `zoneId`) AS rn
        FROM `creature` WHERE `map` = 751 GROUP BY `id`, `zoneId`
      ) q WHERE q.`rn` = 1) c
JOIN `dc_map751_band` b ON b.`zone` = c.`zoneId`
JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE t.`maxlevel` BETWEEN 130 AND 160 AND t.`rank` <> 3 AND t.`type` <> 8;

-- ---------------------------------------------------------------------------
-- 3. Compute the new modifiers from the SNAPSHOT, never from current values
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `_dc_rescale_751`;

CREATE TABLE `_dc_rescale_751` (
  `entry` INT UNSIGNED NOT NULL,
  `zone` INT UNSIGNED NOT NULL DEFAULT 0,
  `lvl` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `rank` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `old_hp_mod` FLOAT NOT NULL DEFAULT 1,
  `new_hp_mod` FLOAT NOT NULL DEFAULT 1,
  `new_mana_mod` FLOAT NOT NULL DEFAULT 1,
  `new_dmg_mod` FLOAT NOT NULL DEFAULT 1,
  `old_hp` INT UNSIGNED NOT NULL DEFAULT 0,
  `new_hp` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `_dc_rescale_751`
  (`entry`, `zone`, `lvl`, `rank`, `old_hp_mod`, `new_hp_mod`, `new_mana_mod`, `new_dmg_mod`,
   `old_hp`, `new_hp`)
SELECT t.`entry`, b.`zone`, t.`maxlevel`, t.`rank`,
       snap.`HealthModifier`,
       GREATEST(snap.`HealthModifier`, (s.`basehp2` * r.`hp_factor`) / s.`basehp0`),
       CASE WHEN s.`basemana` > 0
            THEN LEAST(snap.`ManaModifier`,
                       (s.`basehp0` * GREATEST(snap.`HealthModifier`,
                            (s.`basehp2` * r.`hp_factor`) / s.`basehp0`)) / s.`basemana`)
            ELSE snap.`ManaModifier` END,
       GREATEST(snap.`DamageModifier`, r.`dmg_floor`),
       ROUND(s.`basehp0` * snap.`HealthModifier`),
       ROUND(s.`basehp0` * GREATEST(snap.`HealthModifier`, (s.`basehp2` * r.`hp_factor`) / s.`basehp0`))
FROM (SELECT `id`, `zoneId` FROM (
        SELECT `id`, `zoneId`,
               ROW_NUMBER() OVER (PARTITION BY `id` ORDER BY COUNT(*) DESC, `zoneId`) AS rn
        FROM `creature` WHERE `map` = 751 GROUP BY `id`, `zoneId`
      ) q WHERE q.`rn` = 1) c
JOIN `dc_map751_band` b ON b.`zone` = c.`zoneId`
JOIN `creature_template` t ON t.`entry` = c.`id`
JOIN `dc_map751_stat_snap` snap ON snap.`entry` = t.`entry`
JOIN `dc_map751_rank_scale` r ON r.`rank` = t.`rank`
JOIN `creature_classlevelstats` s ON s.`level` = t.`maxlevel` AND s.`class` = t.`unit_class`
WHERE t.`maxlevel` BETWEEN 130 AND 160 AND t.`rank` <> 3 AND t.`type` <> 8
  AND s.`basehp0` > 0;

-- ---------------------------------------------------------------------------
-- 4. Apply
-- ---------------------------------------------------------------------------
UPDATE `creature_template` t
JOIN `_dc_rescale_751` x ON x.`entry` = t.`entry`
SET t.`HealthModifier` = x.`new_hp_mod`,
    t.`ManaModifier`   = x.`new_mana_mod`,
    t.`DamageModifier` = x.`new_dmg_mod`;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'templates re-scaled' AS what, COUNT(*) AS n FROM `_dc_rescale_751`
UNION ALL SELECT '  ...raised (rest already above the curve)', COUNT(*)
  FROM `_dc_rescale_751` WHERE `new_hp_mod` > `old_hp_mod`
UNION ALL SELECT '  ...NERFED (must be 0)', COUNT(*)
  FROM `_dc_rescale_751` WHERE `new_hp_mod` < `old_hp_mod`
UNION ALL SELECT 'rank-4 rares lifted (want 57)', COUNT(*)
  FROM `_dc_rescale_751` WHERE `rank` = 4 AND `new_hp_mod` > `old_hp_mod`
UNION ALL SELECT 'casters still with mana > HP (want 0)', COUNT(*)
  FROM `_dc_rescale_751` x
  JOIN `creature_template` t ON t.`entry` = x.`entry`
  JOIN `creature_classlevelstats` s ON s.`level` = t.`maxlevel` AND s.`class` = t.`unit_class`
  WHERE s.`basemana` * t.`ManaModifier` > s.`basehp0` * t.`HealthModifier`
UNION ALL SELECT 'bosses touched (must be 0)', COUNT(*)
  FROM `_dc_rescale_751` x JOIN `creature_template` t ON t.`entry` = x.`entry`
  WHERE t.`rank` = 3
UNION ALL SELECT 'snapshot rows held for rollback', COUNT(*) FROM `dc_map751_stat_snap`;

-- The resulting curve per zone band. Read the MIN column, not the average: the floor
-- is what this file guarantees, and it is monotone IN LEVEL by construction. The
-- averages stay uneven on purpose, because hand-tuned mobs above the curve are kept,
-- and a zone's MIN tracks the lowest-level mob that zone actually contains (several
-- zones hold a stray level-130 mob well below their band).
--
-- The old MIN column is the headline: there were level 130-160 normal mobs sitting on
-- THREE health, and others at 345 / 361 / 1,634 -- inherited straight from their level
-- 1-50 source mobs.
--
--     zone                  old MIN ->  new MIN
--     Tirisfal Glades             3 ->  14,692
--     Silverpine Forest         345 ->  16,180
--     Hillsbrad Foothills       361 ->  15,808
--     The Hinterlands         1,634 ->  17,110
--     Eastern Plaguelands         3 ->  18,618
SELECT b.`name` AS zone, b.`t_lo`, b.`t_hi`, COUNT(*) AS normal_entries,
       MIN(x.`old_hp`) AS old_MIN_hp,
       MIN(x.`new_hp`) AS new_MIN_hp,
       ROUND(AVG(x.`old_hp`)) AS old_avg_hp,
       ROUND(AVG(x.`new_hp`)) AS new_avg_hp
FROM `_dc_rescale_751` x
JOIN `dc_map751_band` b ON b.`zone` = x.`zone`
WHERE x.`rank` = 0
GROUP BY b.`name`, b.`t_lo`, b.`t_hi`
ORDER BY b.`t_lo`;

DROP TABLE `_dc_rescale_751`;

-- ROLLBACK, if the tuning turns out wrong:
--   UPDATE `creature_template` t
--   JOIN `dc_map751_stat_snap` s ON s.`entry` = t.`entry`
--   SET t.`HealthModifier` = s.`HealthModifier`,
--       t.`ManaModifier`   = s.`ManaModifier`,
--       t.`DamageModifier` = s.`DamageModifier`;
