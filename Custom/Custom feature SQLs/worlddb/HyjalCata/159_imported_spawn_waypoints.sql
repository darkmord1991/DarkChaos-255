-- ---------------------------------------------------------------------------
-- 159  CORRECTIVE -- waypoint paths for the spawns 155_ imported
-- ---------------------------------------------------------------------------
--     WaypointMovementGenerator::DoInitialize: creature Twilight Stormcaller
--     (Entry: 3639843) doesn't have waypoint path id: 0
--     ... same for Thartuk the Exile (3650053) and Goldrinn Defender (3639637)
--
-- Self-inflicted by 155_.  It copied `MovementType` straight from cata_world
-- but imported no `creature_addon` rows, so 13 spawns arrived asking for
-- WAYPOINT_MOTION_TYPE (2) with no path to walk, and the core logs on every
-- respawn.  155_ guarded MovementType 1 (random-with-zero-wander) and simply
-- did not consider 2 -- the same "guard one case, forget the neighbouring one"
-- mistake as the 154_/155_ radius mismatch.
--
-- Two more rows arrived as MovementType 3, which is not a valid
-- MovementGeneratorType on this core (0 IDLE / 1 RANDOM / 2 WAYPOINT); they
-- are Cata-only and get normalised below.
--
-- FIXING IT PROPERLY RATHER THAN FLATTENING TO IDLE
-- The obvious shortcut is to set MovementType = 0 and silence the log, but that
-- would permanently freeze patrols that Cata actually defines.  cata_world has
-- real paths for 11 of the 13 entries, so they are imported for real:
--
--   * `cata_world.creature_addon.waypointPathId` gives the path per spawn;
--   * the path ids (3,842,000 - 3,892,340) were checked against this DB and
--     have ZERO collisions with the 158,339 existing `waypoint_data` rows
--     (max id 230,759,059), so they are carried across UNCHANGED -- no
--     renumbering, which keeps them traceable back to the source;
--   * both schemas expose the same 13 waypoint_data columns including
--     `velocity` and `smoothTransition`, so the copy is column-for-column.
--
-- Spawns are matched back to their Cata original by entry AND position within
-- half a yard.  155_ copies coordinates unchanged, so this is exact in
-- practice; the tolerance only guards float round-tripping.
--
-- Idempotent.  Apply AFTER 155_.
-- ---------------------------------------------------------------------------

-- --- (1) the path assignment -----------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` BETWEEN 15500000 AND 15599999;

INSERT INTO `creature_addon` (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`)
SELECT dc.`guid`, ca.`waypointPathId`, 0, 0, 0, 0, 0, NULL
FROM `creature` dc
JOIN cata_world.creature cc
  ON cc.`id` = dc.`id` - 3600000
 AND cc.`map` = 1
 AND ABS(cc.`position_x` - dc.`position_x`) < 0.5
 AND ABS(cc.`position_y` - dc.`position_y`) < 0.5
JOIN cata_world.creature_addon ca ON ca.`guid` = cc.`guid`
WHERE dc.`guid` BETWEEN 15500000 AND 15599999
  AND dc.`MovementType` IN (2,3)
  AND ca.`waypointPathId` <> 0;

-- --- (2) the paths themselves ----------------------------------------------
INSERT IGNORE INTO `waypoint_data`
  (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`velocity`,
   `delay`,`smoothTransition`,`move_type`,`action`,`action_chance`,`wpguid`)
SELECT w.`id`, w.`point`, w.`position_x`, w.`position_y`, w.`position_z`, w.`orientation`,
       w.`velocity`, w.`delay`, w.`smoothTransition`, w.`move_type`, w.`action`,
       w.`action_chance`, 0
FROM cata_world.waypoint_data w
WHERE w.`id` IN (SELECT `path_id` FROM `creature_addon`
                 WHERE `guid` BETWEEN 15500000 AND 15599999 AND `path_id` <> 0);

-- --- (3) normalise MovementType --------------------------------------------
-- Anything still claiming waypoint movement without a path drops to idle --
-- that is what the core does anyway after logging, minus the log spam.  This
-- also catches the two MovementType = 3 rows, which this core cannot express.
UPDATE `creature` c SET c.`MovementType` = 0
WHERE c.`guid` BETWEEN 15500000 AND 15599999
  AND c.`MovementType` IN (2,3)
  AND NOT EXISTS (SELECT 1 FROM `creature_addon` a
                  WHERE a.`guid` = c.`guid` AND a.`path_id` <> 0);

-- Rows that DID get a path but arrived as MovementType 3 become proper
-- waypoint movers.
UPDATE `creature` c SET c.`MovementType` = 2
WHERE c.`guid` BETWEEN 15500000 AND 15599999
  AND c.`MovementType` = 3
  AND EXISTS (SELECT 1 FROM `creature_addon` a
              WHERE a.`guid` = c.`guid` AND a.`path_id` <> 0);

-- ---------------------------------------------------------------------------
-- Verification -- both of these should return zero rows:
--
--   -- waypoint movers with no path
--   SELECT c.guid, c.id, c.MovementType FROM creature c
--   WHERE c.guid BETWEEN 15500000 AND 15599999 AND c.MovementType = 2
--     AND NOT EXISTS (SELECT 1 FROM creature_addon a WHERE a.guid=c.guid AND a.path_id<>0);
--
--   -- assigned paths with no points
--   SELECT DISTINCT a.path_id FROM creature_addon a
--   WHERE a.guid BETWEEN 15500000 AND 15599999 AND a.path_id<>0
--     AND NOT EXISTS (SELECT 1 FROM waypoint_data w WHERE w.id=a.path_id);
-- ---------------------------------------------------------------------------
