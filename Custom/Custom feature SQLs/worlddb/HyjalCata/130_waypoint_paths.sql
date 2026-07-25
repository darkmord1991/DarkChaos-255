-- ---------------------------------------------------------------------------
-- 130  Hyjal round-16 -- the 31 missing SmartAI waypoint paths
-- ---------------------------------------------------------------------------
-- Sibling of 122_.  With the timed action lists finally imported, the next
-- layer of the same omission surfaced:
--     SmartAIMgr: Creature 4080300 Event 12 Action 53 uses non-existent
--     WaypointPath id 40803, skipped.
-- SMART_ACTION_WP_START (53) takes the path id in **action_param2**, and 31 of
-- those paths have no `waypoint_data` rows.  Every scripted walk in the zone is
-- therefore dead even now that the action lists exist -- Cenarius (40803),
-- Emerald Flameweaver (40856), Sira Moonwarden (52955), Keeper Taldros (52965),
-- the Forlorn Spire camera (53017), Injured Druid of the Talon (53243), Trained
-- Fire Hawk (53300 / 5330000 / 5330001 / 5330002), Windcaller Nordrala (53355),
-- Tenaron Stormgrip (54070), Goldrinn (39627), the 5391xxx random-range set,
-- plus 8 Plaguelands-side paths from the same clone block.
--
-- WHY NOTHING FOUND THESE EARLIER: `nelt_world` has no `waypoint_data` table at
-- all -- the old-TC schema calls it **`waypoints`** (entry / pointid /
-- position_x/y/z / point_comment).  Every previous sweep queried
-- waypoint_data, got zero rows, and concluded the data did not exist.
--   nelt_world.waypoints  -> 24 of the 31 paths
--   cata_world.waypoints  -> 11 (overlapping; it also carries orientation,
--                            velocity, delay and smoothTransition, which the
--                            nelt table does not, so it is preferred where both
--                            have the path)
--
-- Path ids are NOT offset (the smart_scripts rows already reference the raw
-- nelt/cata numbering, same convention as the action lists).  Verified none of
-- the 31 currently exists in acore_world.waypoint_data.
--
-- 7 paths (11282, 11283, 16256, 17238, 37120, 37801, ... -- see the verify
-- query at the bottom) exist in NEITHER source and stay missing; they are
-- Plaguelands/EK-side and were already broken before this round.
--
-- Idempotent (INSERT IGNORE).  Apply AFTER 122_.
-- ---------------------------------------------------------------------------
SET @PATHS := '11282,11283,16256,17238,5295500,53300,5330001,54070,37120,37801,3784601,37952,38017,38334,38335,38337,38338,39627,40803,40856,52955,52965,5296500,53017,53243,5330000,5330002,53355,53911,5391100,5391101';

-- --- preferred source: cata_world.waypoints (has orientation/velocity/delay) --
INSERT IGNORE INTO acore_world.waypoint_data
(`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`velocity`,`delay`,`smoothTransition`,`move_type`,`action`,`action_chance`,`wpguid`)
SELECT w.entry, w.pointid, w.position_x, w.position_y, w.position_z, w.orientation, w.velocity, w.delay, w.smoothTransition, 0, 0, 100, 0
FROM cata_world.waypoints w
WHERE FIND_IN_SET(w.entry, @PATHS);

-- --- fallback: nelt_world.waypoints (position only; the rest defaults) -------
-- INSERT IGNORE means any path cata_world already supplied is left untouched.
INSERT IGNORE INTO acore_world.waypoint_data
(`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`velocity`,`delay`,`smoothTransition`,`move_type`,`action`,`action_chance`,`wpguid`)
SELECT w.entry, w.pointid, w.position_x, w.position_y, w.position_z, 0, 0, 0, 0, 0, 0, 100, 0
FROM nelt_world.waypoints w
WHERE FIND_IN_SET(w.entry, @PATHS);

-- ---------------------------------------------------------------------------
-- VERIFY (run by hand after applying) -- should list only the paths that exist
-- in neither source DB:
--
--   SELECT s.entryorguid, s.id, s.action_param2 path_id
--   FROM smart_scripts s
--   WHERE s.action_type = 53 AND s.action_param2 > 0
--     AND NOT EXISTS (SELECT 1 FROM waypoint_data w WHERE w.id = s.action_param2);
-- ---------------------------------------------------------------------------
