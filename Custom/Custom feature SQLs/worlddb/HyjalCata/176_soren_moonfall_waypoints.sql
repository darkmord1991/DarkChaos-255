-- ---------------------------------------------------------------------------
-- 176  Captain Soren Moonfall (3653073, guid 15820017) -- the missing patrol
-- ---------------------------------------------------------------------------
--     WaypointMovementGenerator::DoInitialize: creature Captain Soren Moonfall
--     (Entry: 3653073) doesn't have waypoint path id: 0
--
-- Boot-log pass 2026-07-20. Same gap class as 159_imported_spawn_waypoints.sql:
-- a spawn arrived carrying MovementType=2 (WAYPOINT_MOTION_TYPE) from its
-- source but no `creature_addon` row came with it, so it asks for a route,
-- resolves to path id 0, and logs on every respawn.
--
-- The route exists and is imported for real rather than flattening the spawn to
-- idle: nelt_world guid 252265 (entry 53073 = 3653073 - 3,600,000, position
-- matches ours EXACTLY -- 4452.54 / -2096.29 / 1203.96) carries path_id 2522650
-- with 8 points.
--
-- Path id carried across UNCHANGED, same precedent as 159_ (which carried cata
-- path ids 3,842,000-3,892,340 across after a collision check). Verified:
-- 2522650 has ZERO rows in this DB's waypoint_data and is referenced by no
-- existing creature_addon.path_id. This spawn is in the "MoltenFront-DeepLayer-
-- Hyjal" block (guid 15,820,017), which is outside 159_'s 15,500,000-15,599,999
-- range, so 159_ never covered it.
--
-- nelt_world.waypoint_data has no `move_type` column (older schema) -- dropped
-- from the copy; the target keeps its default 0 (walk), correct for a ground
-- patrol.
--
-- Idempotent.
-- ---------------------------------------------------------------------------

DELETE FROM `waypoint_data` WHERE `id` = 2522650;

INSERT INTO `waypoint_data`
    (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `action`, `action_chance`, `wpguid`)
SELECT `id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `action`, `action_chance`, `wpguid`
FROM `nelt_world`.`waypoint_data`
WHERE `id` = 2522650;

DELETE FROM `creature_addon` WHERE `guid` = 15820017;

INSERT INTO `creature_addon` (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES
(15820017,2522650,0,0,0,0,0,NULL);

-- ---------------------------------------------------------------------------
-- Verification -- should return 8:
--   SELECT COUNT(*) FROM waypoint_data WHERE id = 2522650;
-- ---------------------------------------------------------------------------
