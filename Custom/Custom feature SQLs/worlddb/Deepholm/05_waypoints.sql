-- =====================================================================
-- Deepholm Downport  --  05  Waypoints  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
-- Run AFTER 04 (spawns) -- creature_addon.path_id references these paths.
--
-- Deepholm uses only the path-based system (waypoint_data); the entry-based
-- `waypoints` table has 0 Deepholm rows. Just 3 distinct paths are referenced
-- (by per-spawn creature_addon.path_id), 79 points total:
--     3500870 (18 pts), 3503350 (44 pts), 3543750 (17 pts)
-- These path ids do NOT collide with any existing acore_world.waypoint_data id,
-- so they are kept verbatim -- no offset, and the path_id values imported in 04
-- resolve directly.
--
-- waypoint_data schema is identical Cata<->AC -> straight copy. `wpguid` (a GM
-- visualiser handle, normally 0) is forced to 0 to avoid dangling guid refs.
-- =====================================================================

DELETE FROM `waypoint_data` WHERE `id` IN (3500870, 3503350, 3543750);

INSERT INTO `waypoint_data`
(`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `velocity`, `delay`,
 `smoothTransition`, `move_type`, `action`, `action_chance`, `wpguid`)
SELECT wd.`id`, wd.`point`, wd.`position_x`, wd.`position_y`, wd.`position_z`, wd.`orientation`,
 wd.`velocity`, wd.`delay`, wd.`smoothTransition`, wd.`move_type`, wd.`action`, wd.`action_chance`, 0
FROM `cata_world`.`waypoint_data` wd
WHERE wd.`id` IN (3500870, 3503350, 3543750);
