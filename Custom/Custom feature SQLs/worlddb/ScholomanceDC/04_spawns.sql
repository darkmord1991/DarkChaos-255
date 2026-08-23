-- =====================================================================================
-- Scholomance DC clone -- map 822, step 04: spawns
--
-- Requires 02 (remap tables) and 03 (templates -- a spawn whose template is missing is
-- dropped at load with an error, so the order matters).
--
-- 399 creatures and 62 gameobjects, copied from stock map 289 with three substitutions:
--   guid -> dc_scholo822_cguid / dc_scholo822_gguid
--   id   -> dc_scholo822_cmap  / dc_scholo822_gmap
--   map  -> 822
-- Positions, orientations, rotations, spawn timers and states are carried across untouched:
-- the terrain is a byte-identical rename-copy of map 289, so every coordinate is valid.
--
-- ---------------------------------------------------------------------------------
-- GUIDS ARE ALWAYS EXPLICIT
-- ---------------------------------------------------------------------------------
-- Never let these tables auto-assign. The AUTO_INCREMENT counters on this realm sit ABOVE
-- 0xFFFFFF, and ObjectMgr.cpp:7669/7679 rejects any spawn id at or above that -- a single
-- guid-less INSERT bricks worldserver startup with TCE00007.
--
-- ---------------------------------------------------------------------------------
-- SPAWNMASK IS 7 -- ALL THREE DIFFICULTIES
-- ---------------------------------------------------------------------------------
-- Every one of the 399 creature spawns and all 62 gameobject spawns carries spawnMask 7,
-- and stock 289 already has all three MapDifficulty rows on this realm (28 normal, plus
-- DC-added 9128 heroic and 9129 mythic).
--
-- The mask is carried across unchanged, so the clone MUST get all three MapDifficulty rows
-- too -- Custom/ScholomanceDC/add_scholo822_dbc_rows.py adds 9358/9359/9360 for map 822.
-- Skipping that half is silent: the dungeon works on normal and comes up completely empty
-- on heroic and mythic, with nothing in any log to say why.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. creature  (399 rows)
-- -------------------------------------------------------------------------------------
DELETE FROM `creature` WHERE `map` = 822;
DELETE FROM `creature` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_scholo822_cguid`);

DROP TEMPORARY TABLE IF EXISTS `tmp_scholo_c`;
CREATE TEMPORARY TABLE `tmp_scholo_c` LIKE `creature`;

INSERT INTO `tmp_scholo_c` SELECT * FROM `creature` WHERE `map` = 289;

-- guid first, then id, then map. The two joins are independent (one keys on the original
-- guid, the other on the original id), so neither can see the other's rewrite.
UPDATE `tmp_scholo_c` t
    JOIN `dc_scholo822_cguid` g ON g.`src_guid` = t.`guid`
    SET t.`guid` = g.`dst_guid`;

UPDATE `tmp_scholo_c` t
    JOIN `dc_scholo822_cmap` m ON m.`src_entry` = t.`id`
    SET t.`id` = m.`dst_entry`;

UPDATE `tmp_scholo_c` SET `map` = 822;

INSERT INTO `creature` SELECT * FROM `tmp_scholo_c`;
DROP TEMPORARY TABLE `tmp_scholo_c`;

-- A per-spawn ScriptName overrides the template's. Any that came across would name a stock
-- Scholomance script that cannot resolve an instance on map 822, so they are cleared.
UPDATE `creature` SET `ScriptName` = '' WHERE `map` = 822 AND `ScriptName` <> '';

-- -------------------------------------------------------------------------------------
-- 2. gameobject  (62 rows)
-- -------------------------------------------------------------------------------------
DELETE FROM `gameobject` WHERE `map` = 822;
DELETE FROM `gameobject` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_scholo822_gguid`);

DROP TEMPORARY TABLE IF EXISTS `tmp_scholo_g`;
CREATE TEMPORARY TABLE `tmp_scholo_g` LIKE `gameobject`;

INSERT INTO `tmp_scholo_g` SELECT * FROM `gameobject` WHERE `map` = 289;

UPDATE `tmp_scholo_g` t
    JOIN `dc_scholo822_gguid` g ON g.`src_guid` = t.`guid`
    SET t.`guid` = g.`dst_guid`;

UPDATE `tmp_scholo_g` t
    JOIN `dc_scholo822_gmap` m ON m.`src_entry` = t.`id`
    SET t.`id` = m.`dst_entry`;

UPDATE `tmp_scholo_g` SET `map` = 822;

INSERT INTO `gameobject` SELECT * FROM `tmp_scholo_g`;
DROP TEMPORARY TABLE `tmp_scholo_g`;

UPDATE `gameobject` SET `ScriptName` = '' WHERE `map` = 822 AND `ScriptName` <> '';

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'creature spawns on 822 (want 399)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature` WHERE `map` = 822
UNION ALL SELECT 'gameobject spawns on 822 (want 62)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 822
-- All three difficulties, matching stock.
UNION ALL SELECT 'creature spawns on all 3 difficulties (want 399)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 822 AND `spawnMask` = 7
UNION ALL SELECT 'gameobject spawns on all 3 difficulties (want 62)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 822 AND `spawnMask` = 7
-- Every spawn must point at a clone template, never at a stock one.
UNION ALL SELECT 'creature spawns pointing outside the clone band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 822
      AND `id` NOT IN (SELECT `dst_entry` FROM `dc_scholo822_cmap`)
UNION ALL SELECT 'gameobject spawns pointing outside the clone band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 822
      AND `id` NOT IN (SELECT `dst_entry` FROM `dc_scholo822_gmap`)
-- A spawn whose template is missing is discarded at load.
UNION ALL SELECT 'creature spawns with no template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c WHERE c.`map` = 822
      AND c.`id` NOT IN (SELECT `entry` FROM `creature_template`)
UNION ALL SELECT 'gameobject spawns with no template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` g WHERE g.`map` = 822
      AND g.`id` NOT IN (SELECT `entry` FROM `gameobject_template`)
-- TCE00007 guard.
UNION ALL SELECT 'creature guids at/over the 0xFFFFFF cap (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 822 AND `guid` >= 16777215
UNION ALL SELECT 'gameobject guids at/over the 0xFFFFFF cap (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 822 AND `guid` >= 16777215
UNION ALL SELECT 'clone spawns left naming a script (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 822 AND `ScriptName` <> ''
-- Stock Scholomance, unchanged. And the Stratholme clone must not have been disturbed.
UNION ALL SELECT 'stock 289 creature spawns (want 399)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 289
UNION ALL SELECT 'stock 289 gameobject spawns (want 62)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 289
UNION ALL SELECT 'Stratholme clone spawns still on 821 (want 469)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 821;
