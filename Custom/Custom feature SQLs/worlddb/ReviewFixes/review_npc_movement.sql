-- =====================================================================
-- FIX: Restore waypoint (MovementType=2) movement for downported NPCs
--      on Mount Hyjal (map 750) and Plaguelands (map 751).
--
-- ROOT CAUSE: The clone (+3,600,000 entry, NEW guids) ported the
-- creature spawns with MovementType=2 but DID NOT port:
--   - creature_addon rows (0 of 61 dc waypoint spawns have an addon)
--   - the waypoint_data path rows
-- In cata_world, waypoint paths are keyed by:
--   creature.guid -> creature_addon.waypointPathId -> waypoint_data.id
-- The clone changed the guids and dropped the addon, so ALL 61 are broken
-- (they stand at their spawn point forever).
--
-- RESOLUTION:
--   - 59 of 61 dc spawns map to a real cata path (927 waypoint points total).
--   - 2 dc spawns (9832309 / id 3628500, 9832405 / id 3645681) have NO path
--     even in the cata SOURCE (pre-existing TDB defect, not a downport
--     regression) -> nothing to port; they will remain idle. Left as-is.
--
-- NEW path_id namespace = cata_waypointPathId + 100000000
--   (acore_world.waypoint_data MAX(id)=54,054,621 and the 90M-100M+ range
--    is empty, so this is collision-free. NOTE: 4 raw cata path ids
--    1313400/1313410/1313460/1313470 ALREADY EXIST in acore_world.waypoint_data,
--    so the raw ids could NOT be reused -- hence the +100M offset.)
--
-- AzerothCore reads creature_addon.path_id (>0) as a TC-style waypoint
-- group id into waypoint_data.id. Confirmed acore creature_addon col = path_id.
--
-- All values verified read-only against the live DBs (2026-06-30).
-- APPLY ON: acore_world.  Idempotent-safe via DELETE guards below.
-- =====================================================================

-- The 59-row resolved mapping (dc_guid -> source cata waypointPathId).
-- Disambiguation applied: where a dc spawn matched two cata source rows
-- (same entry+xyz), the candidate with MovementType=2 AND a valid
-- waypointPathId was chosen (dc 9832400 -> cata path 1313460, not the
-- MT0 twin). dc 9832309 / 9832405 intentionally ABSENT (no source path).
--
-- A temporary mapping table makes this a clean, auditable two-statement
-- port. If your toolchain forbids temp tables, replace the
-- _dc_wp_map references with the inline VALUES (listed in the table below).

DROP TEMPORARY TABLE IF EXISTS _dc_wp_map;
CREATE TEMPORARY TABLE _dc_wp_map (
  dc_guid    INT UNSIGNED NOT NULL PRIMARY KEY,
  src_pathid INT UNSIGNED NOT NULL,        -- cata waypoint_data.id to copy FROM
  new_pathid INT UNSIGNED NOT NULL         -- = src_pathid + 100000000
);

INSERT INTO _dc_wp_map (dc_guid, src_pathid, new_pathid) VALUES
(9824200,3842000,103842000),(9824680,3847720,103847720),(9824731,3848250,103848250),
(9824735,3848320,103848320),(9824792,3848940,103848940),(9824967,3850860,103850860),
(9825117,3852460,103852460),(9825119,3852480,103852480),(9825155,3852860,103852860),
(9825237,3853710,103853710),(9825833,3859990,103859990),(9825853,3860190,103860190),
(9825926,3860970,103860970),(9825938,3861100,103861100),(9825939,3861110,103861110),
(9825945,3861170,103861170),(9825961,3861330,103861330),(9825976,3861480,103861480),
(9826289,3865390,103865390),(9826293,3865430,103865430),(9826297,3865470,103865470),
(9826304,3865540,103865540),(9826331,3865810,103865810),(9826337,3865870,103865870),
(9826374,3866250,103866250),(9826385,3866370,103866370),(9826404,3866580,103866580),
(9826410,3866640,103866640),(9826420,3866740,103866740),(9826427,3866810,103866810),
(9826435,3866890,103866890),(9826445,3866990,103866990),(9826453,3867070,103867070),
(9826454,3867080,103867080),(9826461,3867150,103867150),(9826465,3867190,103867190),
(9826467,3867210,103867210),(9826479,3867340,103867340),(9826512,3867670,103867670),
(9826513,3867680,103867680),(9826537,3867920,103867920),(9826547,3868020,103868020),
(9826667,3869340,103869340),(9826668,3869350,103869350),(9826674,3869410,103869410),
(9827121,3874200,103874200),(9827137,3874430,103874430),(9828767,3892340,103892340),
(9832337,1304900,101304900),(9832338,1304910,101304910),(9832339,1304930,101304930),
(9832340,1304940,101304940),(9832394,1313400,101313400),(9832395,1313410,101313410),
(9832400,1313460,101313460),(9832401,1313470,101313470),(9834398,3199500,103199500),
(9834805,3203830,103203830),(9834807,3203850,103203850);

-- ---------------------------------------------------------------------
-- 1) Port the waypoint points (927 rows) into acore_world.waypoint_data
--    under the new collision-free path ids. acore + cata waypoint_data
--    have IDENTICAL 13-column layouts (verified).
-- ---------------------------------------------------------------------
DELETE wd FROM acore_world.waypoint_data wd
  JOIN _dc_wp_map m ON wd.id = m.new_pathid;   -- re-run safety

INSERT INTO acore_world.waypoint_data
  (id, point, position_x, position_y, position_z, orientation,
   velocity, delay, smoothTransition, move_type, action, action_chance, wpguid)
SELECT m.new_pathid, src.point, src.position_x, src.position_y, src.position_z,
       src.orientation, src.velocity, src.delay, src.smoothTransition,
       src.move_type, src.action, src.action_chance, 0 AS wpguid
FROM _dc_wp_map m
JOIN cata_world.waypoint_data src ON src.id = m.src_pathid;

-- ---------------------------------------------------------------------
-- 2) Create the creature_addon rows linking each dc spawn to its new path.
--    (AzerothCore creature_addon schema: guid, path_id, mount, bytes1,
--     bytes2, emote, visibilityDistanceType, auras.)
-- ---------------------------------------------------------------------
DELETE ca FROM acore_world.creature_addon ca
  JOIN _dc_wp_map m ON ca.guid = m.dc_guid;    -- re-run safety

INSERT INTO acore_world.creature_addon
  (guid, path_id, mount, bytes1, bytes2, emote, visibilityDistanceType, auras)
SELECT m.dc_guid, m.new_pathid, 0, 0, 0, 0, 0, NULL
FROM _dc_wp_map m;

DROP TEMPORARY TABLE IF EXISTS _dc_wp_map;

-- ---------------------------------------------------------------------
-- VERIFY (run after apply; expect 59 / 59 / 927):
--   SELECT COUNT(*) FROM acore_world.creature_addon ca
--     JOIN acore_world.creature c ON c.guid=ca.guid
--     WHERE c.map IN (750,751) AND c.MovementType=2 AND ca.path_id>0;        -- 59
--   SELECT COUNT(DISTINCT ca.path_id) FROM acore_world.creature_addon ca
--     JOIN acore_world.creature c ON c.guid=ca.guid
--     JOIN acore_world.waypoint_data wd ON wd.id=ca.path_id
--     WHERE c.map IN (750,751) AND c.MovementType=2;                         -- 59
--   SELECT COUNT(*) FROM acore_world.waypoint_data WHERE id BETWEEN 101000000 AND 104000000; -- 927
--
-- REMAINING (no source path, leave idle OR demote to MovementType=0/1):
--   dc guid 9832309 (entry 3628500), dc guid 9832405 (entry 3645681)
-- =====================================================================
