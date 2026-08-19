-- 74_cauldron_lords.sql — map 751 Lordaeron extension, DB step 13.
--
-- DB half of `src/server/scripts/DC/Plaguelands/zone_western_plaguelands_dc.cpp`.
--
-- That script replaces stock `npc_the_scourge_cauldron` FOR MAP 751 ONLY. The stock
-- file is left untouched: it identifies the four cauldrons by sub-area, which is
-- right on Eastern Kingdoms and impossible on 751 (one area id per zone), so the DC
-- copy identifies them by position instead. Patching stock just for a downport would
-- make every upstream merge harder.
--
-- Two things here:
--   1. Bind entry 3611152 to the DC script.
--   2. Create the three MISSING Cauldron Lord clones.
--
-- On (2): the cauldron summons a Cauldron Lord to defend it. Only 3611078
-- (Soulwrath, level 153) was ever cloned; Bilemaw / Razarch / Malvinious exist only
-- as stock 11075 / 11076 / 11077 at levels 53-56, which would be a trivial speed
-- bump in a zone banded to 148-153 — and summoning the stock entry would also mean
-- the DC map animating a shared template. They are cloned into the same +3,600,000
-- band at stock level + 95, which is exactly the offset the existing 3611078 sits at
-- (58 -> 153) and lands all four inside the Western Plaguelands band 148-153.
--
-- These are SUMMON-ONLY templates: they have no spawn, so `71_`'s re-level never
-- sees them (it builds `dc_map751_entryzone` from spawned creatures). Their levels
-- are therefore set explicitly here and must be revisited by hand if the WPL band
-- in `dc_map751_band` is ever retuned.
--
-- The quests have no kill objective (RequiredNpcOrGo1 = 0) — the Cauldron Lord is
-- an obstacle, not a credit target — so no quest wiring is needed.

-- ---------------------------------------------------------------------------
-- 1. Clone the three missing Cauldron Lords (all columns, via a temp copy so the
--    clone tracks whatever the stock template happens to carry)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (3611075, 3611076, 3611077);

DROP TEMPORARY TABLE IF EXISTS `tmp_cauldron_lords`;
CREATE TEMPORARY TABLE `tmp_cauldron_lords` AS
  SELECT * FROM `creature_template` WHERE `entry` IN (11075, 11076, 11077);

-- ORDER MATTERS: MySQL applies SET assignments left to right, so anything derived
-- from `entry` must be computed BEFORE `entry` itself is rewritten — otherwise the
-- loot ids pick up the already-offset value and land at +7,200,000.
UPDATE `tmp_cauldron_lords`
SET `lootid`     = IF(`lootid` > 0, `entry` + 3600000, 0),
    `skinloot`   = IF(`skinloot` > 0, `entry` + 3600000, 0),
    `entry`      = `entry` + 3600000,
    `minlevel`   = `minlevel` + 95,
    `maxlevel`   = `maxlevel` + 95,
    `ScriptName` = '';

INSERT INTO `creature_template` SELECT * FROM `tmp_cauldron_lords`;
DROP TEMPORARY TABLE `tmp_cauldron_lords`;

-- Side tables. A creature with no creature_template_model row is INVISIBLE, so
-- this is not optional.
DELETE FROM `creature_template_model`      WHERE `CreatureID` IN (3611075, 3611076, 3611077);
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT `CreatureID` + 3600000, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`
FROM `creature_template_model` WHERE `CreatureID` IN (11075, 11076, 11077);

DELETE FROM `creature_template_resistance` WHERE `CreatureID` IN (3611075, 3611076, 3611077);
INSERT INTO `creature_template_resistance` (`CreatureID`,`School`,`Resistance`,`VerifiedBuild`)
SELECT `CreatureID` + 3600000, `School`, `Resistance`, `VerifiedBuild`
FROM `creature_template_resistance` WHERE `CreatureID` IN (11075, 11076, 11077);

DELETE FROM `creature_template_spell`      WHERE `CreatureID` IN (3611075, 3611076, 3611077);
INSERT INTO `creature_template_spell` (`CreatureID`,`Index`,`Spell`,`VerifiedBuild`)
SELECT `CreatureID` + 3600000, `Index`, `Spell`, `VerifiedBuild`
FROM `creature_template_spell` WHERE `CreatureID` IN (11075, 11076, 11077);

DELETE FROM `creature_template_addon`      WHERE `entry` IN (3611075, 3611076, 3611077);
INSERT INTO `creature_template_addon` (`entry`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`)
SELECT `entry` + 3600000, 0, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`
FROM `creature_template_addon` WHERE `entry` IN (11075, 11076, 11077);

-- ---------------------------------------------------------------------------
-- 2. Bind the DC cauldron script (stock 11152 keeps npc_the_scourge_cauldron)
-- ---------------------------------------------------------------------------
UPDATE `creature_template`
SET `ScriptName` = 'npc_dc_scourge_cauldron'
WHERE `entry` = 3611152;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT t.`entry`, t.`name`, t.`minlevel`, t.`maxlevel`,
       (SELECT COUNT(*) FROM `creature_template_model` m WHERE m.`CreatureID` = t.`entry`) AS model_rows
FROM `creature_template` t
WHERE t.`entry` IN (3611075, 3611076, 3611077, 3611078)
ORDER BY t.`entry`;

SELECT 'cauldron bound to the DC script' AS what, COUNT(*) AS n
FROM `creature_template` WHERE `entry` = 3611152 AND `ScriptName` = 'npc_dc_scourge_cauldron'
UNION ALL SELECT 'cauldron spawns on map 751', COUNT(*)
FROM `creature` WHERE `map` = 751 AND `id` = 3611152
UNION ALL SELECT 'stock cauldron untouched (still npc_the_scourge_cauldron)', COUNT(*)
FROM `creature_template` WHERE `entry` = 11152 AND `ScriptName` = 'npc_the_scourge_cauldron';

-- must be zero: a Cauldron Lord the script can summon but which has no model
SELECT 'PROBLEM: summonable Cauldron Lord with no model row' AS problem, COUNT(*) AS n
FROM `creature_template` t
LEFT JOIN `creature_template_model` m ON m.`CreatureID` = t.`entry`
WHERE t.`entry` IN (3611075, 3611076, 3611077, 3611078) AND m.`CreatureID` IS NULL;

-- must be zero: any of the four missing entirely (the script would summon nothing)
SELECT 'PROBLEM: Cauldron Lord clone missing' AS problem,
       4 - COUNT(*) AS n
FROM `creature_template` WHERE `entry` IN (3611075, 3611076, 3611077, 3611078);

-- all four should now sit inside the Western Plaguelands band (4932 = 148-153)
SELECT 'Cauldron Lord levels vs the WPL band' AS note,
       (SELECT CONCAT(`t_lo`,'-',`t_hi`) FROM `dc_map751_band` WHERE `zone` = 4932) AS wpl_band,
       CONCAT(MIN(`minlevel`),'-',MAX(`maxlevel`)) AS cauldron_lords
FROM `creature_template` WHERE `entry` IN (3611075, 3611076, 3611077, 3611078);
