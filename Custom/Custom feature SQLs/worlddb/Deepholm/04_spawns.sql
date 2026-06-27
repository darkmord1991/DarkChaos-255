-- =====================================================================
-- Deepholm Downport  --  04  Spawns  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
-- Run AFTER 01 (creature templates) + 02 (gameobject templates).
--
-- Imports ALL Deepholm spawns (spawns of the 6 shared templates are kept --
-- only the shared TEMPLATES were excluded, not their Deepholm placements):
--   creature        6522 rows  -> guid block 9,400,000 .. 9,460,000
--   creature_addon  6519 rows  (per-spawn, same guid offset)
--   gameobject       947 rows  -> guid block 9,300,000 .. 9,330,000
--   gameobject_addon       (per-spawn, same guid offset)
--
-- GUID strategy: FIXED OFFSET (preserves relative guids so later phases --
-- SmartAI-by-guid, pools, events -- can remap with the same constant):
--   creature   new_guid = cata_guid + 9059257   (cata 340743..396407 -> 9.40M..9.456M)
--   gameobject new_guid = cata_guid + 9099132   (cata 200868..224294 -> 9.30M..9.323M)
-- Both blocks verified free (acore max creature 9,305,959 / gameobject 9,151,886).
--
-- zoneId/areaId set to 0 -> the core resolves them from position via the map's
--   area grid. This deliberately sidesteps the retail-5042 vs authored-4922
--   zone-id conflict; do NOT copy cata zoneId (5042 = "Camp Nooka Nooka" here).
--
-- PHASING (critical): Cata phaseMask is uniformly 1; the storyline split lives
--   in PhaseId. We translate PhaseId -> a distinct phasemask BIT. Base zone
--   (PhaseId 169) = bit 1 (visible to every player). Storyline PhaseIds map to
--   bits 2..256 = HIDDEN until the P3 storyline grants the matching phase.
--   NEVER copy cata phaseMask verbatim (would stack every state on phase 1).
--
--   PhaseId -> phasemask bit (also documented in 00_README / used again in P3):
--     169 (base) -> 1     237 -> 8      252 -> 32     254 -> 128
--       0 (none) -> 1     251 -> 16     253 -> 64     257 -> 256
--     170 -> 2   187 -> 4
-- =====================================================================

-- ---------------------------------------------------------------------
-- creature  (spawns)
-- ---------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 9400000 AND 9460000;

INSERT INTO `creature`
(`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
 `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`,
 `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`,
 `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`)
SELECT
 c.`guid` + 9059257, c.`id`, 646, 0, 0, c.`spawnMask`,
 CASE c.`PhaseId`
   WHEN 170 THEN 2  WHEN 187 THEN 4   WHEN 237 THEN 8    WHEN 251 THEN 16
   WHEN 252 THEN 32 WHEN 253 THEN 64  WHEN 254 THEN 128  WHEN 257 THEN 256
   ELSE 1
 END,
 c.`equipment_id`, c.`position_x`, c.`position_y`, c.`position_z`, c.`orientation`,
 c.`spawntimesecs`, c.`spawndist`, c.`currentwaypoint`, c.`curhealth`, c.`curmana`,
 c.`MovementType`, c.`npcflag`, c.`unit_flags`, c.`dynamicflags`,
 CASE WHEN c.`ScriptName` = 'npc_deepholm_xariona' THEN '' ELSE c.`ScriptName` END,
 c.`VerifiedBuild`, 0, 'Deepholm'
FROM `cata_world`.`creature` c
WHERE c.`map` = 646;

-- ---------------------------------------------------------------------
-- creature_addon  (per-spawn; waypointPathId -> path_id, drop AnimKits/cyclic)
-- ---------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` BETWEEN 9400000 AND 9460000;

INSERT INTO `creature_addon`
(`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT a.`guid` + 9059257, a.`waypointPathId`, a.`mount`, a.`bytes1`, a.`bytes2`, a.`emote`,
 a.`visibilityDistanceType`, a.`auras`
FROM `cata_world`.`creature_addon` a
WHERE a.`guid` IN (SELECT `guid` FROM `cata_world`.`creature` WHERE `map` = 646);

-- ---------------------------------------------------------------------
-- gameobject  (spawns)
-- ---------------------------------------------------------------------
DELETE FROM `gameobject` WHERE `guid` BETWEEN 9300000 AND 9330000;

INSERT INTO `gameobject`
(`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`,
 `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`,
 `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`)
SELECT
 g.`guid` + 9099132, g.`id`, 646, 0, 0, g.`spawnMask`,
 CASE g.`PhaseId`
   WHEN 170 THEN 2  WHEN 187 THEN 4   WHEN 237 THEN 8    WHEN 251 THEN 16
   WHEN 252 THEN 32 WHEN 253 THEN 64  WHEN 254 THEN 128  WHEN 257 THEN 256
   ELSE 1
 END,
 g.`position_x`, g.`position_y`, g.`position_z`, g.`orientation`,
 g.`rotation0`, g.`rotation1`, g.`rotation2`, g.`rotation3`, g.`spawntimesecs`,
 g.`animprogress`, g.`state`, g.`ScriptName`, g.`VerifiedBuild`, 'Deepholm'
FROM `cata_world`.`gameobject` g
WHERE g.`map` = 646;

-- ---------------------------------------------------------------------
-- gameobject_addon  (per-spawn; identical schema -- straight copy + offset)
-- ---------------------------------------------------------------------
DELETE FROM `gameobject_addon` WHERE `guid` BETWEEN 9300000 AND 9330000;

INSERT INTO `gameobject_addon`
(`guid`, `parent_rotation0`, `parent_rotation1`, `parent_rotation2`, `parent_rotation3`, `invisibilityType`, `invisibilityValue`)
SELECT ga.`guid` + 9099132, ga.`parent_rotation0`, ga.`parent_rotation1`, ga.`parent_rotation2`,
 ga.`parent_rotation3`, ga.`invisibilityType`, ga.`invisibilityValue`
FROM `cata_world`.`gameobject_addon` ga
WHERE ga.`guid` IN (SELECT `guid` FROM `cata_world`.`gameobject` WHERE `map` = 646);

-- ---------------------------------------------------------------------
-- Collapse stacked spawn-pool duplicates
-- ---------------------------------------------------------------------
-- Retail gates these via pool_creature/pool_gameobject (only K of N active at a
-- time), but those membership tables are absent from cata_world, so every raw
-- pool member imported ungated -> e.g. 8x "Stone Trogg Reinforcement" and
-- 8x "Verlok Pillartumbler" on a single coordinate, visible stacked even to a
-- base-phase player. Collapse to one spawn per (id, exact position, phaseMask),
-- keeping the lowest guid. Only removes literally-overlapping same-phase, same-id
-- spawns (clustered camps at different coords are untouched). Idempotent.
-- First run removes ~575 creature + ~31 gameobject rows.
DELETE c1 FROM `creature` c1
INNER JOIN `creature` c2
  ON c1.`id` = c2.`id` AND c1.`position_x` = c2.`position_x` AND c1.`position_y` = c2.`position_y`
 AND c1.`position_z` = c2.`position_z` AND c1.`phaseMask` = c2.`phaseMask` AND c1.`guid` > c2.`guid`
WHERE c1.`map` = 646;

DELETE g1 FROM `gameobject` g1
INNER JOIN `gameobject` g2
  ON g1.`id` = g2.`id` AND g1.`position_x` = g2.`position_x` AND g1.`position_y` = g2.`position_y`
 AND g1.`position_z` = g2.`position_z` AND g1.`phaseMask` = g2.`phaseMask` AND g1.`guid` > g2.`guid`
WHERE g1.`map` = 646;

-- drop per-spawn addon rows orphaned by the dedup
DELETE FROM `creature_addon` WHERE `guid` BETWEEN 9400000 AND 9460000 AND `guid` NOT IN (SELECT `guid` FROM `creature` WHERE `map` = 646);
DELETE FROM `gameobject_addon` WHERE `guid` BETWEEN 9300000 AND 9330000 AND `guid` NOT IN (SELECT `guid` FROM `gameobject` WHERE `map` = 646);
