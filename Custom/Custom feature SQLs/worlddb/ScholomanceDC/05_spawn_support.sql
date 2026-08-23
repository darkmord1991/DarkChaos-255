-- =====================================================================================
-- Scholomance DC clone -- map 822, step 05: spawn support tables
--
-- Requires 02 (remap tables) and 04 (the spawns these rows attach to).
--
--   creature_addon        182 rows -- mount, bytes, emote, auras, and the patrol path link
--   creature_formations     3 rows -- Scholomance barely uses formations
--   waypoint_data          16 paths
--
-- ---------------------------------------------------------------------------------
-- THE PATH_ID TRAP
-- ---------------------------------------------------------------------------------
-- creature_addon.path_id points into waypoint_data.id. Left unmapped every clone patroller
-- would walk the STOCK path rows. Those rows exist and are valid, so nothing would error --
-- the two dungeons would just silently share patrol data, and editing one would move
-- creatures in the other.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. waypoint_data  (16 paths)
--
-- Inserted before creature_addon so the paths exist by the time anything points at them.
-- wpguid is zeroed: it is a waypoint-editor bookkeeping field holding the source creature
-- guid, and carrying it across would leave clone paths annotated with stock spawn ids.
-- -------------------------------------------------------------------------------------
DELETE FROM `waypoint_data` WHERE `id` IN (SELECT `dst_path` FROM `dc_scholo822_wpmap`);

DROP TEMPORARY TABLE IF EXISTS `tmp_scholo_wp`;
CREATE TEMPORARY TABLE `tmp_scholo_wp` LIKE `waypoint_data`;

INSERT INTO `tmp_scholo_wp`
    SELECT * FROM `waypoint_data`
    WHERE `id` IN (SELECT `src_path` FROM `dc_scholo822_wpmap`);

UPDATE `tmp_scholo_wp` t
    JOIN `dc_scholo822_wpmap` w ON w.`src_path` = t.`id`
    SET t.`id` = w.`dst_path`;

UPDATE `tmp_scholo_wp` SET `wpguid` = 0;

INSERT INTO `waypoint_data` SELECT * FROM `tmp_scholo_wp`;
DROP TEMPORARY TABLE `tmp_scholo_wp`;

-- -------------------------------------------------------------------------------------
-- 2. creature_addon  (182 rows)
--
-- The `auras` column is carried across unchanged: those are stock spell ids that already
-- exist server-side and in the client, so no spell work is needed for the clone.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_scholo822_cguid`);

DROP TEMPORARY TABLE IF EXISTS `tmp_scholo_ca`;
CREATE TEMPORARY TABLE `tmp_scholo_ca` LIKE `creature_addon`;

INSERT INTO `tmp_scholo_ca`
    SELECT * FROM `creature_addon`
    WHERE `guid` IN (SELECT `src_guid` FROM `dc_scholo822_cguid`);

UPDATE `tmp_scholo_ca` t
    JOIN `dc_scholo822_cguid` g ON g.`src_guid` = t.`guid`
    SET t.`guid` = g.`dst_guid`;

-- Only rows that actually have a path are touched, so path_id 0 stays 0.
UPDATE `tmp_scholo_ca` t
    JOIN `dc_scholo822_wpmap` w ON w.`src_path` = t.`path_id`
    SET t.`path_id` = w.`dst_path`
    WHERE t.`path_id` > 0;

INSERT INTO `creature_addon` SELECT * FROM `tmp_scholo_ca`;
DROP TEMPORARY TABLE `tmp_scholo_ca`;

-- -------------------------------------------------------------------------------------
-- 3. creature_formations  (3 rows)
--
-- BOTH columns are guids and BOTH must be remapped. Mapping only memberGUID would leave the
-- clone group following its stock leader on another map.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_formations` WHERE `memberGUID` IN (SELECT `dst_guid` FROM `dc_scholo822_cguid`);

DROP TEMPORARY TABLE IF EXISTS `tmp_scholo_cf`;
CREATE TEMPORARY TABLE `tmp_scholo_cf` LIKE `creature_formations`;

INSERT INTO `tmp_scholo_cf`
    SELECT * FROM `creature_formations`
    WHERE `memberGUID` IN (SELECT `src_guid` FROM `dc_scholo822_cguid`);

UPDATE `tmp_scholo_cf` t
    JOIN `dc_scholo822_cguid` g ON g.`src_guid` = t.`memberGUID`
    SET t.`memberGUID` = g.`dst_guid`;

UPDATE `tmp_scholo_cf` t
    JOIN `dc_scholo822_cguid` g ON g.`src_guid` = t.`leaderGUID`
    SET t.`leaderGUID` = g.`dst_guid`;

INSERT INTO `creature_formations` SELECT * FROM `tmp_scholo_cf`;
DROP TEMPORARY TABLE `tmp_scholo_cf`;

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'waypoint_data clone paths (want 16)' AS `check`, CAST(COUNT(DISTINCT `id`) AS CHAR) AS result
    FROM `waypoint_data` WHERE `id` IN (SELECT `dst_path` FROM `dc_scholo822_wpmap`)
UNION ALL SELECT 'creature_addon clone rows (want 182)', CAST(COUNT(*) AS CHAR)
    FROM `creature_addon` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_scholo822_cguid`)
UNION ALL SELECT 'clone addons carrying a path (want 16)', CAST(COUNT(*) AS CHAR)
    FROM `creature_addon` WHERE `guid` IN (SELECT `dst_guid` FROM `dc_scholo822_cguid`) AND `path_id` > 0
-- The trap this file exists for: no clone patroller may still point at a stock path.
UNION ALL SELECT 'clone addons still on a STOCK path (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_addon`
    WHERE `guid` IN (SELECT `dst_guid` FROM `dc_scholo822_cguid`) AND `path_id` > 0
      AND `path_id` NOT IN (SELECT `dst_path` FROM `dc_scholo822_wpmap`)
-- Every path referenced must actually have waypoints, or the creature stands still.
UNION ALL SELECT 'clone paths referenced but empty (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_addon` a
    WHERE a.`guid` IN (SELECT `dst_guid` FROM `dc_scholo822_cguid`) AND a.`path_id` > 0
      AND a.`path_id` NOT IN (SELECT DISTINCT `id` FROM `waypoint_data`)
UNION ALL SELECT 'creature_formations clone rows (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `creature_formations` WHERE `memberGUID` IN (SELECT `dst_guid` FROM `dc_scholo822_cguid`)
UNION ALL SELECT 'clone formations led by a STOCK guid (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_formations`
    WHERE `memberGUID` IN (SELECT `dst_guid` FROM `dc_scholo822_cguid`)
      AND `leaderGUID` NOT IN (SELECT `dst_guid` FROM `dc_scholo822_cguid`)
-- Stock untouched.
UNION ALL SELECT 'stock creature_addon rows (want 182)', CAST(COUNT(*) AS CHAR)
    FROM `creature_addon` WHERE `guid` IN (SELECT `src_guid` FROM `dc_scholo822_cguid`);
