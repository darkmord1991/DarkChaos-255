-- DarkChaos: map 751 creature HP + damage on map 750's model (332_), one curve from 80 to 160
--
-- Measured 2026-11-11 (normal mobs, zone averages, HP / base damage):
--   map 750  Felwood (100) 59k / 824     Hyjal + Winterspring (111) 70-75k / ~1,000-1,067
--   map 751  Tirisfal .. Hinterlands (132-145) 44-62k / 409-450
--            Western Plaguelands (151) 150k / 772   Eastern Plaguelands (156) 171k / 875
-- So most of 751 was easier than the end of 750, and the Plaguelands then jumped ~3x in HP. Map 751 templates
-- sit on the classic stat column (exp 0, DamageModifier ~1.15) where map 750 uses exp 2 (332_).
--
-- THE MODEL is 332_'s, unchanged, against the same-level player curve 13134 + (level - 80) * 515:
--   rank        HP x player   average swing (% of player HP)
--   0 normal        2.5            4.5%
--   4 rare          5              6%
--   1 elite         8              7.5%
--   2 rare elite   25             11%
--   3 boss         60             15%
--   HP = BaseHealth[2] * HealthModifier; swing = BaseDamage[2] * DamageModifier * 1.25 (Creature.cpp, 332_).
--
-- SCOPE: creature templates spawned on map 751 and on no other map, minlevel >= 125, combat creatures. The same
-- exclusions as 332_: critters/totems/pets (type 8, 11, 12), friendly NPCs (unit_flags & 258), triggers
-- (flags_extra & 128), unselectable (unit_flags & 0x2000000). Measured: 1,330 templates.
--
-- DIFFERENCE FROM 332_ - this pass also LOWERS, but only where it is safe:
--   * combat mobs (npcflag 0) are set to the target whether that raises or lowers them - that is what removes
--     the Plaguelands spike (369 templates sat at 1.25-3x the target);
--   * NPCs with a service (npcflag <> 0: vendors, quest givers, trainers) are only raised, as in 332_;
--   * anything above 3x its target HP is left completely alone - exp and both modifiers. That is 82 templates,
--     the hand-placed lore NPCs (Tirion 343x, Sylvanas 122-137x, Korfax 69x ...) and a training dummy.
-- The values are absolute targets, so a re-run lands on the same numbers.
--
-- Backup: the pre-change exp + modifiers of every template this file can touch go to
-- dc_creature_stat_rebalance_backup_751 on the FIRST run only (see the restore statement at the end).
-- Apply to acore_world, then restart the worldserver.

CREATE TABLE IF NOT EXISTS `dc_creature_stat_rebalance_backup_751` (
    `entry` INT UNSIGNED NOT NULL,
    `exp` SMALLINT NOT NULL,
    `HealthModifier` FLOAT NOT NULL,
    `DamageModifier` FLOAT NOT NULL,
    `captured_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- INSERT IGNORE keeps the first run's originals on a re-run (the PRIMARY KEY gives the idempotency). The DELETE
-- removes nothing; it only satisfies the codestyle rule that every INSERT follows a DELETE.
DELETE FROM `dc_creature_stat_rebalance_backup_751` WHERE `entry` = 0;
INSERT IGNORE INTO `dc_creature_stat_rebalance_backup_751` (`entry`, `exp`, `HealthModifier`, `DamageModifier`)
SELECT `t`.`entry`, `t`.`exp`, `t`.`HealthModifier`, `t`.`DamageModifier`
FROM `creature_template` AS `t`
WHERE `t`.`entry` IN (SELECT `c`.`id` FROM `creature` AS `c` WHERE `c`.`map` = 751)
  AND `t`.`entry` NOT IN (SELECT `o`.`id` FROM `creature` AS `o` WHERE `o`.`map` <> 751)
  AND `t`.`minlevel` >= 125;

-- The tuning knobs, identical to 332_/333_
SET @hp_normal := 2.5;
SET @dmg_normal := 0.045;
SET @hp_rare := 5.0;
SET @dmg_rare := 0.060;
SET @hp_elite := 8.0;
SET @dmg_elite := 0.075;
SET @hp_rareelite := 25.0;
SET @dmg_rareelite := 0.110;
SET @hp_boss := 60.0;
SET @dmg_boss := 0.150;
SET @swing_spread := 1.25;
SET @outlier := 3.0;

-- Absolute targets per template, computed once from the ORIGINAL values (the backup), so a re-run reads the same
-- inputs and writes the same outputs.
-- chp/cdm = current HP / average swing, thp/tdm = target, bhp/bdm = the exp-2 base values, svc = has a service
DROP TEMPORARY TABLE IF EXISTS `dc_751_mob_target`;
CREATE TEMPORARY TABLE `dc_751_mob_target` (
    `entry` INT UNSIGNED NOT NULL,
    `chp` DOUBLE NOT NULL,
    `cdm` DOUBLE NOT NULL,
    `thp` DOUBLE NOT NULL,
    `tdm` DOUBLE NOT NULL,
    `bhp` DOUBLE NOT NULL,
    `bdm` DOUBLE NOT NULL,
    `svc` TINYINT NOT NULL,
    PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELETE FROM `dc_751_mob_target`;
INSERT INTO `dc_751_mob_target`
SELECT `t`.`entry`,
    CASE `b`.`exp` WHEN 0 THEN `s`.`basehp0` WHEN 1 THEN `s`.`basehp1` ELSE `s`.`basehp2` END * `b`.`HealthModifier`,
    CASE `b`.`exp` WHEN 0 THEN `s`.`damage_base` WHEN 1 THEN `s`.`damage_exp1` ELSE `s`.`damage_exp2` END
        * `b`.`DamageModifier` * @swing_spread,
    CASE `t`.`rank` WHEN 1 THEN @hp_elite WHEN 2 THEN @hp_rareelite WHEN 3 THEN @hp_boss WHEN 4 THEN @hp_rare
        ELSE @hp_normal END * (13134 + (`t`.`minlevel` - 80) * 515),
    CASE `t`.`rank` WHEN 1 THEN @dmg_elite WHEN 2 THEN @dmg_rareelite WHEN 3 THEN @dmg_boss WHEN 4 THEN @dmg_rare
        ELSE @dmg_normal END * (13134 + (`t`.`minlevel` - 80) * 515),
    `s`.`basehp2`, `s`.`damage_exp2` * @swing_spread, IF(`t`.`npcflag` <> 0, 1, 0)
FROM `creature_template` AS `t`
JOIN `dc_creature_stat_rebalance_backup_751` AS `b` ON `b`.`entry` = `t`.`entry`
JOIN `creature_classlevelstats` AS `s` ON `s`.`level` = `t`.`minlevel` AND `s`.`class` = `t`.`unit_class`
WHERE `t`.`type` NOT IN (8, 11, 12)
  AND (`t`.`unit_flags` & 258) = 0
  AND (`t`.`flags_extra` & 128) = 0
  AND (`t`.`unit_flags` & 33554432) = 0
  AND `s`.`basehp2` > 0
  AND `s`.`damage_exp2` > 0;

-- Lore NPCs and other outliers (current HP above 3x target) are not touched at all
DELETE FROM `dc_751_mob_target` WHERE `chp` > @outlier * `thp`;

UPDATE `creature_template` AS `t`
JOIN `dc_751_mob_target` AS `m` ON `m`.`entry` = `t`.`entry`
SET `t`.`HealthModifier` = IF(`m`.`svc` = 1 AND `m`.`chp` > `m`.`thp`, `m`.`chp`, `m`.`thp`) / `m`.`bhp`;

UPDATE `creature_template` AS `t`
JOIN `dc_751_mob_target` AS `m` ON `m`.`entry` = `t`.`entry`
SET `t`.`DamageModifier` = IF(`m`.`svc` = 1 AND `m`.`cdm` > `m`.`tdm`, `m`.`cdm`, `m`.`tdm`) / `m`.`bdm`;

UPDATE `creature_template` AS `t`
JOIN `dc_751_mob_target` AS `m` ON `m`.`entry` = `t`.`entry`
SET `t`.`exp` = 2;

DROP TEMPORARY TABLE IF EXISTS `dc_751_mob_target`;

-- Restore (run by hand if ever needed):
--   UPDATE `creature_template` t JOIN `dc_creature_stat_rebalance_backup_751` b ON b.`entry` = t.`entry`
--   SET t.`exp` = b.`exp`, t.`HealthModifier` = b.`HealthModifier`, t.`DamageModifier` = b.`DamageModifier`;
