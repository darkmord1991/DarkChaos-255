-- =====================================================================================
-- Stratholme DC clone -- map 821, step 04: spawns
--
-- Requires 02 (remap tables) and 03 (templates -- a spawn whose template is missing is
-- dropped at load with an error, so the order matters).
--
-- 468 creatures and 188 gameobjects, copied from stock map 329 with three substitutions:
--   guid -> dc_strat821_cguid / dc_strat821_gguid
--   id   -> dc_strat821_cmap  / dc_strat821_gmap
--   map  -> 821
-- Positions, orientations, rotations, spawn timers and states are carried across untouched:
-- the terrain is a byte-identical rename-copy of map 329, so every coordinate is valid.
--
-- ---------------------------------------------------------------------------------
-- GUIDS ARE ALWAYS EXPLICIT
-- ---------------------------------------------------------------------------------
-- Never let these tables auto-assign. The AUTO_INCREMENT counters on this realm sit ABOVE
-- 0xFFFFFF, and ObjectMgr.cpp:7669/7679 rejects any spawn id at or above that -- a single
-- guid-less INSERT bricks worldserver startup with TCE00007. The guids come from the map
-- tables built in 02, which were checked against the cap there.
--
-- ---------------------------------------------------------------------------------
-- SPAWNMASK IS COPIED, AND IT IS 7 -- ALL THREE DIFFICULTIES
-- ---------------------------------------------------------------------------------
-- Stratholme is a normal-only dungeon in retail, but NOT on this realm: DC already added
-- heroic and mythic to stock map 329 (MapDifficulty rows 9130 and 9131 alongside stock 30),
-- and all 468 cloned creature spawns and all 188 gameobject spawns carry spawnMask 7.
--
-- The mask is therefore carried across unchanged, and the clone MUST get all three
-- MapDifficulty rows -- Custom/StratholmeDC/add_strat821_dbc_rows.py adds 9355/9356/9357
-- for map 821. Skipping that half is silent: the dungeon works on normal and comes up
-- completely empty on heroic and mythic, with nothing in any log to say why.
--
-- (The one stock spawn with spawnMask 1 is the naxx40 entrance trigger, which is excluded
-- from the clone entirely -- see 02.)
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. creature  (468 rows)
-- -------------------------------------------------------------------------------------
DELETE FROM `creature` WHERE `map` = 821;
DELETE FROM `creature` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`);

DROP TEMPORARY TABLE IF EXISTS `tmp_strat_c`;
CREATE TEMPORARY TABLE `tmp_strat_c` LIKE `creature`;

INSERT INTO `tmp_strat_c`
    SELECT * FROM `creature` WHERE `map` = 329 AND `id` <> 351097;

-- guid first, then id, then map. The two joins are independent (one keys on the original
-- guid, the other on the original id), so neither can see the other's rewrite.
UPDATE `tmp_strat_c` t
    JOIN `dc_strat821_cguid` g ON g.`src_guid` = t.`guid`
    SET t.`guid` = g.`dst_guid`;

UPDATE `tmp_strat_c` t
    JOIN `dc_strat821_cmap` m ON m.`src_entry` = t.`id`
    SET t.`id` = m.`dst_entry`;

UPDATE `tmp_strat_c` SET `map` = 821;

INSERT INTO `creature` SELECT * FROM `tmp_strat_c`;
DROP TEMPORARY TABLE `tmp_strat_c`;

-- A per-spawn ScriptName overrides the template's. Any that came across would name a stock
-- Stratholme script that cannot resolve an instance on map 821, so they are cleared; the
-- report below confirms none survived.
UPDATE `creature` SET `ScriptName` = '' WHERE `map` = 821 AND `ScriptName` <> '';

-- -------------------------------------------------------------------------------------
-- 2. gameobject  (188 rows)
-- -------------------------------------------------------------------------------------
DELETE FROM `gameobject` WHERE `map` = 821;
DELETE FROM `gameobject` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_strat821_gguid`);

DROP TEMPORARY TABLE IF EXISTS `tmp_strat_g`;
CREATE TEMPORARY TABLE `tmp_strat_g` LIKE `gameobject`;

INSERT INTO `tmp_strat_g`
    SELECT * FROM `gameobject` WHERE `map` = 329;

UPDATE `tmp_strat_g` t
    JOIN `dc_strat821_gguid` g ON g.`src_guid` = t.`guid`
    SET t.`guid` = g.`dst_guid`;

UPDATE `tmp_strat_g` t
    JOIN `dc_strat821_gmap` m ON m.`src_entry` = t.`id`
    SET t.`id` = m.`dst_entry`;

UPDATE `tmp_strat_g` SET `map` = 821;

INSERT INTO `gameobject` SELECT * FROM `tmp_strat_g`;
DROP TEMPORARY TABLE `tmp_strat_g`;

UPDATE `gameobject` SET `ScriptName` = '' WHERE `map` = 821 AND `ScriptName` <> '';

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'creature spawns on 821 (want 468)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature` WHERE `map` = 821
UNION ALL SELECT 'gameobject spawns on 821 (want 188)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 821
-- All three difficulties, matching stock. If this is not 468 the heroic/mythic clone is
-- partly empty -- and MapDifficulty rows 9355/9356/9357 must exist for 821 to match.
UNION ALL SELECT 'creature spawns on all 3 difficulties (want 468)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 821 AND `spawnMask` = 7
UNION ALL SELECT 'gameobject spawns on all 3 difficulties (want 188)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 821 AND `spawnMask` = 7
-- Every spawn must point at a clone template, never at a stock one.
UNION ALL SELECT 'creature spawns pointing outside the clone band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 821
      AND `id` NOT IN (SELECT `dst_entry` FROM `dc_strat821_cmap`)
UNION ALL SELECT 'gameobject spawns pointing outside the clone band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 821
      AND `id` NOT IN (SELECT `dst_entry` FROM `dc_strat821_gmap`)
-- A spawn whose template is missing is discarded at load.
UNION ALL SELECT 'creature spawns with no template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c WHERE c.`map` = 821
      AND c.`id` NOT IN (SELECT `entry` FROM `creature_template`)
UNION ALL SELECT 'gameobject spawns with no template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` g WHERE g.`map` = 821
      AND g.`id` NOT IN (SELECT `entry` FROM `gameobject_template`)
-- TCE00007 guard.
UNION ALL SELECT 'creature guids at/over the 0xFFFFFF cap (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 821 AND `guid` >= 16777215
UNION ALL SELECT 'gameobject guids at/over the 0xFFFFFF cap (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 821 AND `guid` >= 16777215
UNION ALL SELECT 'clone spawns left naming a script (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 821 AND `ScriptName` <> ''
-- The naxx40 module trigger must not have been cloned.
UNION ALL SELECT 'naxx40 trigger cloned onto 821 (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c JOIN `dc_strat821_cmap` m ON m.`dst_entry` = c.`id`
    WHERE c.`map` = 821 AND m.`src_entry` = 351097
-- Stock Stratholme, unchanged.
UNION ALL SELECT 'stock 329 creature spawns (want 469)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 329
UNION ALL SELECT 'stock 329 gameobject spawns (want 188)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject` WHERE `map` = 329
UNION ALL SELECT 'stock 329 naxx40 trigger still there (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 329 AND `id` = 351097;
