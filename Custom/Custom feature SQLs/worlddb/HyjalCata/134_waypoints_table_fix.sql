-- ---------------------------------------------------------------------------
-- 134  Hyjal round-17 -- CORRECTS 130_: SmartAI waypoints live in `waypoints`
-- ---------------------------------------------------------------------------
-- 130_ imported the 31 missing paths into **`waypoint_data`**, which was the
-- wrong table, so every one of its errors came back unchanged after the
-- restart:
--     SmartAIMgr: Creature 4080300 Event 12 Action 53 uses non-existent
--     WaypointPath id 40803, skipped.
--
-- AzerothCore has TWO waypoint systems and they do not share storage:
--   * `waypoint_data`  -> WaypointMovementGenerator: ordinary creature patrols,
--                         selected per spawn via creature_addon.path_id.
--   * `waypoints`      -> SmartWaypointMgr::LoadFromDB, i.e. everything
--                         SMART_ACTION_WP_START (53) does.
--                         (WorldDatabase.cpp: "SELECT entry, pointid,
--                          position_x, position_y, position_z, orientation,
--                          delay FROM waypoints ORDER BY entry, pointid")
-- The irony is that `waypoints` is exactly the table name the source DBs use --
-- 130_'s note about nelt "calling it waypoints" was right about the source and
-- wrong about the destination.
--
-- This file undoes 130_'s misplaced rows and redoes the import correctly.
-- SmartWaypointMgr additionally requires each path's pointid to run 1..N with
-- no gaps ("unexpected point id {}, expected {}"); all 29 available paths were
-- checked and are contiguous from 1, so they import as-is.
--
-- 29 of the 31 paths are recoverable (11 from cata_world, which also carries
-- orientation/delay, 24 from nelt_world, overlapping). 16256 and 17238 exist in
-- neither source and stay missing -- both Plaguelands/EK-side and already
-- broken before this work.
-- ---------------------------------------------------------------------------
SET @PATHS := '11282,11283,16256,17238,5295500,53300,5330001,54070,37120,37801,3784601,37952,38017,38334,38335,38337,38338,39627,40803,40856,52955,52965,5296500,53017,53243,5330000,5330002,53355,53911,5391100,5391101';

-- --- undo 130_ ---------------------------------------------------------------
-- Scoped to exactly the ids 130_ inserted. Left in place they would be picked up
-- by any creature whose creature_addon.path_id happened to match, which is not
-- what the data means.
DELETE FROM `waypoint_data` WHERE FIND_IN_SET(`id`, @PATHS);

-- --- preferred source: cata_world.waypoints (has orientation + delay) --------
DELETE FROM `waypoints` WHERE FIND_IN_SET(`entry`, @PATHS);

INSERT INTO `waypoints` (`entry`,`pointid`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`point_comment`)
SELECT w.entry, w.pointid, w.position_x, w.position_y, w.position_z, w.orientation, w.delay,
       CONCAT('Hyjal-r17 (cata) ', IFNULL(w.point_comment,''))
FROM cata_world.waypoints w
WHERE FIND_IN_SET(w.entry, @PATHS);

-- --- fallback: nelt_world.waypoints (position only; orientation/delay default)
INSERT IGNORE INTO `waypoints` (`entry`,`pointid`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`point_comment`)
SELECT w.entry, w.pointid, w.position_x, w.position_y, w.position_z, 0, 0,
       CONCAT('Hyjal-r17 (nelt) ', IFNULL(w.point_comment,''))
FROM nelt_world.waypoints w
WHERE FIND_IN_SET(w.entry, @PATHS);

-- ---------------------------------------------------------------------------
-- VERIFY after applying -- should return only 16256 and 17238:
--   SELECT DISTINCT s.action_param2 FROM smart_scripts s
--   WHERE s.action_type = 53 AND s.action_param2 > 0
--     AND NOT EXISTS (SELECT 1 FROM waypoints w WHERE w.entry = s.action_param2);
-- ---------------------------------------------------------------------------
