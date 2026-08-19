-- 84_hauler_crew_and_pathing.sql -- map 751 Lordaeron extension, DB step 23.
--
-- Three fixes to the working wagons:
--   1. they leave the road at bridges
--   2. the coffin wagon has no crew and no cargo
--   3. nine coffins are left floating where 83_ deleted their wagons
--
-- ---------------------------------------------------------------------------
-- 1. BRIDGES: stop the wagons pathfinding around them
--
-- WaypointMovementGenerator calls `init.MoveTo(...)` with generatePath defaulting
-- to TRUE (WaypointMovementGenerator.cpp:279), so every leg is routed through the
-- server's navmesh. Map 751's mmaps do not contain the bridge geometry, so the
-- navmesh sees a gap and the wagon detours down the bank and up the far side --
-- exactly what happens in game.
--
-- CREATURE_FLAG_EXTRA_IGNORE_PATHFINDING (0x20000000, CreatureData.h:75) sets
-- UNIT_STATE_IGNORE_PATHFINDING (Creature.cpp:1237-1238), which makes the spline go
-- straight from node to node instead of asking the navmesh.
--
-- That is the CORRECT behaviour here, not a workaround: path 447310 was sniffed
-- from Blizzard's own wagon driving the real road, so the straight line between two
-- consecutive nodes IS the road, bridge included. Pathfinding can only do damage.
--
-- Existing flags_extra is 8192 (CANNOT_ENTER_COMBAT) and is preserved.
-- ---------------------------------------------------------------------------
UPDATE `creature_template`
SET `flags_extra` = `flags_extra` | 0x20000000
WHERE `entry` IN (4144731, 4144764);

-- ---------------------------------------------------------------------------
-- 2. The coffin wagon's crew and cargo.
--
-- TrinityCore never scripted 44764 so there is no upstream accessory data, but the
-- seat geometry gives it away. Vehicle 1049's seats are structurally parallel to
-- 1048's, which TC DID script:
--
--   seat 0  attach  1  offset (0.55, 0.00, 3.00)   -- identical on both -> Engineer
--   seat 1  attach 15  offset (2.00, 0.00, 0.00)   -- identical on both -> Ettin puller
--   seat 2  attach 13  flags 0x4300800b            -- the flag shape TC leaves EMPTY
--                                                     for the player on 1048
--   seat 3  attach 19  offset (1.00,-1.00, 0.00)
--   seat 4  attach 19  offset (1.00,-1.00, 1.20)   -- three slots stacked 1.2 apart
--   seat 5  attach 19  offset (1.00,-1.00, 2.40)
--
-- Those three stacked slots are the coffins: the loose `Coffins` (4144766) spawns
-- sit in threes at one X/Y with Z 49/50/51 and 67/68/70 -- the same 1.2 spacing.
--
-- Seat 2 is deliberately left empty so the player still has somewhere to ride.
-- ---------------------------------------------------------------------------
DELETE FROM `vehicle_template_accessory` WHERE `entry` = 4144764;

INSERT INTO `vehicle_template_accessory` (`entry`, `accessory_entry`, `seat_id`, `minion`, `description`, `summontype`, `summontimer`) VALUES
(4144764, 4144734, 0, 1, 'Sitting on top - Horde Engineer', 8, 30000),
(4144764, 4144737, 1, 1, 'Subdued Forest Ettin', 8, 30000),
(4144764, 4144766, 3, 1, 'Coffins - bottom of the stack', 8, 30000),
(4144764, 4144766, 4, 1, 'Coffins - middle of the stack', 8, 30000),
(4144764, 4144766, 5, 1, 'Coffins - top of the stack', 8, 30000);

-- ---------------------------------------------------------------------------
-- 3. The nine orphaned coffins.
--
-- They were the cargo of the three capture wagons 83_ removed, so they are now
-- three stacks of coffins floating in mid-air with nothing under them. Section 2
-- gives the surviving wagon its own cargo, so these are pure leftovers.
--
--   16715044-46 at (40, 1209)   -- belonged to capture 16715041
--   16719789-91 at (1410, 718)  -- belonged to capture 16719787
--   16720392-94 at (1468, 639)  -- belonged to capture 16720390
-- ---------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (16715044,16715045,16715046,16719789,16719790,16719791,16720392,16720393,16720394);
DELETE FROM `creature`       WHERE `guid` IN (16715044,16715045,16715046,16719789,16719790,16719791,16720392,16720393,16720394);

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'both wagons ignore pathfinding (want 2)' AS what, COUNT(*) AS n
FROM `creature_template` WHERE `entry` IN (4144731, 4144764) AND (`flags_extra` & 0x20000000)
UNION ALL SELECT '  ...and kept CANNOT_ENTER_COMBAT (want 2)', COUNT(*)
FROM `creature_template` WHERE `entry` IN (4144731, 4144764) AND (`flags_extra` & 8192)
UNION ALL SELECT 'coffin wagon accessories (want 5)', COUNT(*)
FROM `vehicle_template_accessory` WHERE `entry` = 4144764
UNION ALL SELECT 'passenger wagon accessories, untouched (want 7)', COUNT(*)
FROM `vehicle_template_accessory` WHERE `entry` = 4144731
UNION ALL SELECT 'loose Coffins spawns left (want 0)', COUNT(*)
FROM `creature` WHERE `id` = 4144766
UNION ALL SELECT 'wagons that move (want 2)', COUNT(*)
FROM `creature` c JOIN `creature_addon` a ON a.`guid` = c.`guid`
WHERE c.`id` IN (4144731, 4144764) AND c.`MovementType` = 2 AND a.`path_id` > 0;

-- must be empty: an accessory whose creature does not exist
SELECT 'PROBLEM: missing accessory creature' AS problem, a.`entry`, a.`accessory_entry`
FROM `vehicle_template_accessory` a
LEFT JOIN `creature_template` t ON t.`entry` = a.`accessory_entry`
WHERE a.`entry` IN (4144731, 4144764) AND t.`entry` IS NULL;

-- must be empty: two accessories fighting over one seat
SELECT 'PROBLEM: duplicate seat' AS problem, `entry`, `seat_id`, COUNT(*) AS n
FROM `vehicle_template_accessory` WHERE `entry` IN (4144731, 4144764)
GROUP BY `entry`, `seat_id` HAVING COUNT(*) > 1;
