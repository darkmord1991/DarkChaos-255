-- =====================================================================================
-- Stratholme DC clone -- map 821, step 05: spawn support tables
--
-- Requires 02 (remap tables) and 04 (the spawns these rows attach to).
--
--   creature_addon        112 rows -- mount, bytes, emote, auras, and the patrol path link
--   creature_formations   338 rows -- 87 leaders and their members
--   waypoint_data         520 rows -- 29 patrol paths
--
-- gameobject_addon has NO rows for map 329, so there is nothing to copy; the report checks
-- that rather than leaving it as an unstated assumption.
--
-- ---------------------------------------------------------------------------------
-- THE PATH_ID TRAP
-- ---------------------------------------------------------------------------------
-- creature_addon.path_id points into waypoint_data.id. On this data path_id is NEVER equal
-- to the creature guid (0 of 29 match), so the widespread AzerothCore shortcut of "the path
-- id is the guid" is simply false here -- taking it would repoint all 29 patrols at
-- whatever happens to live at those guids. The paths get their own band and their own map
-- table (dc_strat821_wpmap, built in 02) for exactly that reason.
--
-- If path_id were left unmapped instead, every clone patroller would walk the STOCK path
-- rows. Those rows exist and are valid, so nothing would error -- the two dungeons would
-- just silently share patrol data, and editing one would move creatures in the other.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. waypoint_data  (520 rows across 29 paths)
--
-- Inserted before creature_addon so the paths exist by the time anything points at them.
--
-- wpguid is zeroed: it is a waypoint-editor bookkeeping field holding the source creature
-- guid, and carrying it across would leave clone paths annotated with stock spawn ids.
-- -------------------------------------------------------------------------------------
DELETE FROM `waypoint_data` WHERE `id` IN (SELECT `dst_path` FROM `dc_strat821_wpmap`);

DROP TEMPORARY TABLE IF EXISTS `tmp_strat_wp`;
CREATE TEMPORARY TABLE `tmp_strat_wp` LIKE `waypoint_data`;

INSERT INTO `tmp_strat_wp`
    SELECT * FROM `waypoint_data`
    WHERE `id` IN (SELECT `src_path` FROM `dc_strat821_wpmap`);

UPDATE `tmp_strat_wp` t
    JOIN `dc_strat821_wpmap` w ON w.`src_path` = t.`id`
    SET t.`id` = w.`dst_path`;

UPDATE `tmp_strat_wp` SET `wpguid` = 0;

INSERT INTO `waypoint_data` SELECT * FROM `tmp_strat_wp`;
DROP TEMPORARY TABLE `tmp_strat_wp`;

-- -------------------------------------------------------------------------------------
-- 2. creature_addon  (112 rows)
--
-- The `auras` column is carried across unchanged: those are stock spell ids that already
-- exist server-side and in the client, so no spell work is needed for the clone.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`);

DROP TEMPORARY TABLE IF EXISTS `tmp_strat_ca`;
CREATE TEMPORARY TABLE `tmp_strat_ca` LIKE `creature_addon`;

INSERT INTO `tmp_strat_ca`
    SELECT * FROM `creature_addon`
    WHERE `guid` IN (SELECT `src_guid` FROM `dc_strat821_cguid`);

UPDATE `tmp_strat_ca` t
    JOIN `dc_strat821_cguid` g ON g.`src_guid` = t.`guid`
    SET t.`guid` = g.`dst_guid`;

-- Only rows that actually have a path are touched, so path_id 0 stays 0.
UPDATE `tmp_strat_ca` t
    JOIN `dc_strat821_wpmap` w ON w.`src_path` = t.`path_id`
    SET t.`path_id` = w.`dst_path`
    WHERE t.`path_id` > 0;

INSERT INTO `creature_addon` SELECT * FROM `tmp_strat_ca`;
DROP TEMPORARY TABLE `tmp_strat_ca`;

-- -------------------------------------------------------------------------------------
-- 3. creature_formations  (338 rows, 87 leaders)
--
-- BOTH columns are guids and BOTH must be remapped. Mapping only memberGUID would leave
-- every clone group following its stock leader on another map -- the formation code would
-- resolve the leader to a creature that is not in the same map, and the group would either
-- do nothing or drag members toward a position that means nothing on 821.
--
-- The join is an inner join on both columns, so a row whose leader or member fell outside
-- the clone set is dropped rather than half-mapped; the report checks the count.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_formations` WHERE `memberGUID` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`);

DROP TEMPORARY TABLE IF EXISTS `tmp_strat_cf`;
CREATE TEMPORARY TABLE `tmp_strat_cf` LIKE `creature_formations`;

INSERT INTO `tmp_strat_cf`
    SELECT * FROM `creature_formations`
    WHERE `memberGUID` IN (SELECT `src_guid` FROM `dc_strat821_cguid`);

UPDATE `tmp_strat_cf` t
    JOIN `dc_strat821_cguid` g ON g.`src_guid` = t.`memberGUID`
    SET t.`memberGUID` = g.`dst_guid`;

UPDATE `tmp_strat_cf` t
    JOIN `dc_strat821_cguid` g ON g.`src_guid` = t.`leaderGUID`
    SET t.`leaderGUID` = g.`dst_guid`;

INSERT INTO `creature_formations` SELECT * FROM `tmp_strat_cf`;
DROP TEMPORARY TABLE `tmp_strat_cf`;

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'waypoint_data clone rows (want 520)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `waypoint_data` WHERE `id` IN (SELECT `dst_path` FROM `dc_strat821_wpmap`)
UNION ALL SELECT 'clone paths present (want 29)', CAST(COUNT(DISTINCT `id`) AS CHAR)
    FROM `waypoint_data` WHERE `id` IN (SELECT `dst_path` FROM `dc_strat821_wpmap`)
UNION ALL SELECT 'creature_addon clone rows (want 112)', CAST(COUNT(*) AS CHAR)
    FROM `creature_addon` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)
UNION ALL SELECT 'clone addons carrying a path (want 29)', CAST(COUNT(*) AS CHAR)
    FROM `creature_addon` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`) AND `path_id` > 0
-- The trap this file exists for: no clone patroller may still point at a stock path.
UNION ALL SELECT 'clone addons still on a STOCK path (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_addon`
    WHERE `guid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)
      AND `path_id` > 0
      AND `path_id` NOT IN (SELECT `dst_path` FROM `dc_strat821_wpmap`)
-- Every path referenced must actually have waypoints, or the creature stands still.
UNION ALL SELECT 'clone paths referenced but empty (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_addon` a
    WHERE a.`guid` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`) AND a.`path_id` > 0
      AND a.`path_id` NOT IN (SELECT DISTINCT `id` FROM `waypoint_data`)
UNION ALL SELECT 'creature_formations clone rows (want 338)', CAST(COUNT(*) AS CHAR)
    FROM `creature_formations` WHERE `memberGUID` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)
UNION ALL SELECT 'clone formation leaders (want 87)', CAST(COUNT(DISTINCT `leaderGUID`) AS CHAR)
    FROM `creature_formations` WHERE `memberGUID` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)
-- A leader left pointing at a stock guid is the half-mapped failure described above.
UNION ALL SELECT 'clone formations led by a STOCK guid (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_formations`
    WHERE `memberGUID` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)
      AND `leaderGUID` NOT IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)
-- Every formation leader must be a real spawn on 821.
UNION ALL SELECT 'clone formation leaders not spawned on 821 (want 0)', CAST(COUNT(DISTINCT `leaderGUID`) AS CHAR)
    FROM `creature_formations`
    WHERE `memberGUID` IN (SELECT `dst_guid` FROM `dc_strat821_cguid`)
      AND `leaderGUID` NOT IN (SELECT `guid` FROM `creature` WHERE `map` = 821)
UNION ALL SELECT 'gameobject_addon rows on stock 329 (expect 0, nothing to copy)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_addon` WHERE `guid` IN (SELECT `guid` FROM `gameobject` WHERE `map` = 329)
-- Stock untouched.
UNION ALL SELECT 'stock creature_addon rows (want 112)', CAST(COUNT(*) AS CHAR)
    FROM `creature_addon` WHERE `guid` IN (SELECT `src_guid` FROM `dc_strat821_cguid`)
UNION ALL SELECT 'stock waypoint_data rows (want 520)', CAST(COUNT(*) AS CHAR)
    FROM `waypoint_data` WHERE `id` IN (SELECT `src_path` FROM `dc_strat821_wpmap`);
