-- ---------------------------------------------------------------------------
-- 202  Map 750 -- restore the waypoint paths the creature imports left behind
-- ---------------------------------------------------------------------------
-- Live Errors.log:
--     "WaypointMovementGenerator::DoInitialize: creature Vile Grell (...)
--      doesn't have waypoint path id: 0"
--
-- 98 spawns on map 750 carry MovementType = 2 (waypoint movement) and NOT ONE
-- of them has a path -- the creature imports (181_/183_/184_) copied the
-- MovementType column but never the waypoint tables, so every one of them
-- initialises, finds nothing to walk, and logs. They stand still instead of
-- patrolling.
--
-- HOW THE LINK WORKS ON THIS CORE: `creature_addon.path_id` -> `waypoint_data.id`.
-- Column names differ between the source DBs, which is what makes this fiddly:
--     ours / nelt_world : creature_addon.path_id
--     cata_world        : creature_addon.waypointPathId
-- `waypoint_data` itself is column-identical between ours and cata_world (13
-- columns), so the path rows copy verbatim.
--
-- MATCHING BACK TO THE SOURCE -- the imports assigned fresh guids, so the link
-- to cata's spawn is gone and has to be re-derived. Each map-750 spawn is
-- matched to its cata original on (entry - 3,700,000) AND rounded x/y position.
-- That resolves 82 of the 98; those 82 have 82 distinct paths totalling 797
-- waypoints, all with coordinates inside map 750's footprint (x 5776-7999,
-- y -2100..286), which is the sanity check that the match is real.
--
-- PATH IDS ARE THE SPAWN GUID. Path ids only have to be unique, and our guid
-- already is -- so path_id = guid, which is self-documenting and cannot drift.
-- Verified: the 82 guids (15,830,149-15,861,650) collide with ZERO existing
-- `waypoint_data` ids, and the whole 15.8M-16.0M band is empty of paths.
--
-- THE OTHER 16: no cata spawn with a path matches them, so there is nothing to
-- import. They are set to MovementType = 0 rather than left logging every
-- startup -- an idle creature is honest, a waypoint creature with no waypoints
-- is not. All 16 already have a creature_addon row, so only the movement type
-- changes.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) waypoint_data -- 797 waypoints across 82 paths, keyed by our spawn guid
-- ---------------------------------------------------------------------------
DELETE FROM `waypoint_data` WHERE `id` IN (
  SELECT * FROM (
    SELECT c.`guid` FROM `creature` c WHERE c.`map` = 750 AND c.`MovementType` = 2
  ) x);

INSERT INTO `waypoint_data`
    (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`velocity`,`delay`,
     `smoothTransition`,`move_type`,`action`,`action_chance`,`wpguid`)
SELECT c.`guid`, w.`point`, w.`position_x`, w.`position_y`, w.`position_z`, w.`orientation`,
       w.`velocity`, w.`delay`, w.`smoothTransition`, w.`move_type`, w.`action`, w.`action_chance`, 0
FROM `creature` c
JOIN (
  SELECT c2.`id` AS src_id, ROUND(c2.`position_x`, 1) AS px, ROUND(c2.`position_y`, 1) AS py,
         a2.`waypointPathId` AS wpid
  FROM `cata_world`.`creature` c2
  JOIN `cata_world`.`creature_addon` a2 ON a2.`guid` = c2.`guid`
  WHERE c2.`map` = 1 AND a2.`waypointPathId` > 0
) src ON src.`src_id` = CAST(c.`id` AS SIGNED) - 3700000
      AND src.`px` = ROUND(c.`position_x`, 1)
      AND src.`py` = ROUND(c.`position_y`, 1)
JOIN `cata_world`.`waypoint_data` w ON w.`id` = src.`wpid`
WHERE c.`map` = 750 AND c.`MovementType` = 2;

-- ---------------------------------------------------------------------------
-- B) creature_addon -- point the 82 spawns at their new paths
-- ---------------------------------------------------------------------------
-- None of the 82 has an existing creature_addon row (verified), so this is a
-- clean insert; the DELETE keeps it re-runnable.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (
  SELECT * FROM (
    SELECT c.`guid` FROM `creature` c
    WHERE c.`map` = 750 AND c.`MovementType` = 2
      AND EXISTS (SELECT 1 FROM `waypoint_data` w WHERE w.`id` = c.`guid`)
  ) x);

INSERT INTO `creature_addon` (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`)
SELECT c.`guid`, c.`guid`, 0, 0, 1, 0, 0, ''
FROM `creature` c
WHERE c.`map` = 750 AND c.`MovementType` = 2
  AND EXISTS (SELECT 1 FROM `waypoint_data` w WHERE w.`id` = c.`guid`);

-- ---------------------------------------------------------------------------
-- C) The 16 with no importable path -- stop them claiming to patrol
-- ---------------------------------------------------------------------------
UPDATE `creature` c
   SET c.`MovementType` = 0
 WHERE c.`map` = 750 AND c.`MovementType` = 2
   AND NOT EXISTS (SELECT 1 FROM `waypoint_data` w WHERE w.`id` = c.`guid`);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(*) FROM waypoint_data WHERE id BETWEEN 15830000 AND 15870000;  -- 797
--   SELECT COUNT(*) FROM creature_addon a JOIN creature c ON c.guid=a.guid
--    WHERE c.map=750 AND a.path_id=a.guid;                                      -- 82
--
--   -- nothing on map 750 claims waypoint movement without a path (expect 0):
--   SELECT COUNT(*) FROM creature c
--    WHERE c.map=750 AND c.MovementType=2
--      AND NOT EXISTS (SELECT 1 FROM waypoint_data w WHERE w.id=c.guid);
--
-- Errors.log should gain no further "doesn't have waypoint path id: 0" lines,
-- and the Felwood/Darkshore patrols (Vile Grell, Vile Corruptor, Rabid
-- Screecher, Enthralled Earth Elemental ...) should walk their routes.
-- ---------------------------------------------------------------------------
