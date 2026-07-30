-- =====================================================================
-- Plague (map 751)  --  60  Julak-Doom: own pool + the patrol routes
-- ---------------------------------------------------------------------
-- Boot-log pass 2026-07-20. Two problems with the two Julak-Doom world-boss
-- spawns (entry 3650089, guids 15000014 / 15000015):
--
-- 1) WAYPOINT_MOTION_TYPE with no path.
--    Both are MovementType=2 with no `creature_addon` row at all, so they
--    resolve to path id 0 and log
--      WaypointMovementGenerator::DoInitialize: creature Julak-Doom
--      (Entry: 3650089) doesn't have waypoint path id: 0
--    on every respawn. The routes DO exist in the source and were simply never
--    imported: nelt_world guids 246423 / 246424 (positions match ours EXACTLY
--    -- -2398.53/-5516.31/132.03 and -2443/-5078.04/123.142) carry path_id
--    5007520 (30 points) and 5007530 (21 points).
--
--    Path ids are carried across UNCHANGED rather than remapped. These spawns
--    live in the 15,000,000 "PoolFix-Nel" guid block, NOT the main Plaguelands
--    import block (creature +13,000,000 / waypoint +131,000,000 per
--    30_neltharion_spawn_layer.sql), so that layer's offsets do not apply to
--    them -- and 30_'s own cleanup range (`waypoint_data` 131,000,000-
--    131,999,999) would not cover a remapped id anyway, since nelt's raw ids
--    (5.0M) overflow that 1M-wide band. Verified 5007520 / 5007530 have ZERO
--    collisions in this DB's waypoint_data and are referenced by no existing
--    creature_addon.path_id. Same precedent as HyjalCata/159_, which also
--    carried source path ids across unchanged after a collision check.
--
--    nelt_world.waypoint_data has no `move_type` column (older schema) -- it is
--    dropped from the copy and the target keeps its default 0 (walk), correct
--    for a ground patrol.
--
-- 2) Pooled against bosses on two other continents.
--    Both sat in pool 130060017 ("Hyjal-Nel pool 60017", max_limit=1) together
--    with Hyjal's Twilight Firebird (guid 12246389, map 750) and a stray
--    duplicate Xariona clone (map 646, deleted by the companion file
--    Deepholm/47_movement_xariona_zeropower.sql, which documents the root
--    cause in full). Four bosses across three continents competing for one
--    slot meant Julak-Doom was absent roughly 3/4 of the time for no design
--    reason.
--
--    Root cause in brief: nelt_world pool 60017 is a single deliberate
--    6-member "worldboss Pool" (max_limit=2) spanning maps 0/1/646 -- Cata's
--    rotating world bosses. Each DC zone importer copied that whole cross-map
--    pool, kept the members landing on its own map, applied its own offsets and
--    rewrote max_limit to 1 -- so members leaked between zone pools.
--
--    Fix: give Julak-Doom its own Plaguelands-band pool. max_limit=1 is correct
--    and unchanged in intent -- one boss with two alternate spawn points, which
--    is what these two rows are. 130060017 keeps the Twilight Firebird, which
--    is the member that actually belongs to a "Hyjal-Nel" pool.
--
-- Apply against acore_world. Idempotent.
-- =====================================================================

-- --- (1) the patrol routes -------------------------------------------------
DELETE FROM `waypoint_data` WHERE `id` IN (5007520,5007530);

INSERT INTO `waypoint_data`
    (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `action`, `action_chance`, `wpguid`)
SELECT `id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `action`, `action_chance`, `wpguid`
FROM `nelt_world`.`waypoint_data`
WHERE `id` IN (5007520,5007530);

-- --- (2) point each spawn at its own route ---------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (15000014,15000015);

INSERT INTO `creature_addon` (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES
(15000014,5007520,0,0,0,0,0,NULL),
(15000015,5007530,0,0,0,0,0,NULL);

-- --- (3) their own pool ----------------------------------------------------
DELETE FROM `pool_template` WHERE `entry` = 131060089;

INSERT INTO `pool_template` (`entry`,`max_limit`,`description`) VALUES
(131060089,1,'Plague-Nel pool 60089 -- Julak-Doom (2 alternate spawn points)');

UPDATE `pool_creature` SET `pool_entry` = 131060089 WHERE `guid` IN (15000014,15000015);

-- ---------------------------------------------------------------------
-- Verification -- all three should hold after applying:
--   SELECT id, COUNT(*) FROM waypoint_data WHERE id IN (5007520,5007530) GROUP BY id;   -- 30 and 21
--   SELECT guid, path_id FROM creature_addon WHERE guid IN (15000014,15000015);         -- both non-zero
--   SELECT guid, pool_entry FROM pool_creature WHERE pool_entry = 130060017;            -- only 12246389 left
-- ---------------------------------------------------------------------
