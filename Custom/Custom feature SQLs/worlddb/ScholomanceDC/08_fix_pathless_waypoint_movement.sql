-- =====================================================================================
-- Scholomance DC clone -- map 822, step 08: silence two pathless waypoint movers
--
-- Requires 02 and 04.
--
-- ---------------------------------------------------------------------------------
-- THE LOG SPAM
-- ---------------------------------------------------------------------------------
--     WaypointMovementGenerator::DoInitialize: creature Ras Frostwhisper (... Entry:
--     5700031 ...) doesn't have waypoint path id: 0
--     WaypointMovementGenerator::DoInitialize: creature Lord Blackwood (... Entry:
--     5700041 ...) doesn't have waypoint path id: 0
--
-- ---------------------------------------------------------------------------------
-- THIS IS INHERITED, NOT IMPORT DAMAGE
-- ---------------------------------------------------------------------------------
-- Both spawns carry MovementType = 2 (WAYPOINT_MOTION_TYPE) but have NO path to walk:
--
--     * no `creature_addon` row at all, so path_id is 0
--     * no `waypoint_data` rows keyed by their guid either
--
-- Their stock counterparts on map 289 (guids 153321 and 48850) are in exactly the same
-- state and log exactly the same error. It is not confined to Scholomance: 28 spawns
-- across the realm have this shape. The clone reproduces it faithfully because 04 copies
-- MovementType verbatim -- which is correct behaviour for a clone, it just also copies the
-- defect.
--
-- ---------------------------------------------------------------------------------
-- WHY IT IS HARMLESS, AND WHY IT IS STILL WORTH FIXING HERE
-- ---------------------------------------------------------------------------------
-- WaypointMovementGenerator.cpp:72-76 logs and returns *before* it reaches
--     creature->AddUnitState(UNIT_STATE_ROAMING | UNIT_STATE_ROAMING_MOVE);
-- so the creature is simply left standing still. Nothing dangles and nothing crashes.
--
-- But DoInitialize runs on every spawn AND every respawn, so the pair produce a steady
-- trickle of sql.sql errors for the lifetime of the map -- noise that makes a real import
-- problem harder to spot later. Since they never move anyway, declaring that in the data
-- costs nothing and changes no behaviour.
--
-- MovementType 0 = IDLE_MOTION_TYPE, which is what they effectively already have.
--
-- SCOPE: map 822 only. Stock 289 is deliberately left alone -- fixing it there would be an
-- edit to stock content, which this whole clone exists to avoid. The same is true of the
-- other 26 realm-wide occurrences; they are somebody else's call, not this port's.
-- =====================================================================================

UPDATE `creature` c
    LEFT JOIN `creature_addon` a ON a.`guid` = c.`guid`
    SET c.`MovementType` = 0
    WHERE c.`map` = 822
      AND c.`MovementType` = 2
      AND IFNULL(a.`path_id`, 0) = 0;

-- -------------------------------------------------------------------------------------
-- Report -- every branch numeric and CAST to CHAR (collation, see 01).
-- -------------------------------------------------------------------------------------
SELECT 'clone spawns still on waypoint movement with no path (want 0)' AS `check`,
       CAST(COUNT(*) AS CHAR) AS result
    FROM `creature` c LEFT JOIN `creature_addon` a ON a.`guid` = c.`guid`
    WHERE c.`map` = 822 AND c.`MovementType` = 2 AND IFNULL(a.`path_id`, 0) = 0
-- The two named in the log, by clone guid.
UNION ALL SELECT 'Ras Frostwhisper now idle (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` = 16750122 AND `MovementType` = 0
UNION ALL SELECT 'Lord Blackwood now idle (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` = 16750397 AND `MovementType` = 0
-- The 16 spawns that DO have a real path must be untouched and still walking it.
UNION ALL SELECT 'clone spawns still on waypoint movement WITH a path (want 16)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c JOIN `creature_addon` a ON a.`guid` = c.`guid`
    WHERE c.`map` = 822 AND c.`MovementType` = 2 AND a.`path_id` > 0
UNION ALL SELECT 'and every one of those paths has waypoints (want 16)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c JOIN `creature_addon` a ON a.`guid` = c.`guid`
    WHERE c.`map` = 822 AND c.`MovementType` = 2 AND a.`path_id` > 0
      AND a.`path_id` IN (SELECT DISTINCT `id` FROM `waypoint_data`)
-- Stock untouched: its two keep the defect, which is not this port's to fix.
UNION ALL SELECT 'stock 289 pathless waypoint spawns (unchanged, expect 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature` c LEFT JOIN `creature_addon` a ON a.`guid` = c.`guid`
    WHERE c.`map` = 289 AND c.`MovementType` = 2 AND IFNULL(a.`path_id`, 0) = 0
UNION ALL SELECT 'stock 289 total spawns (want 399, unchanged)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `map` = 289;
