-- 81_hauler_spawn_cleanup.sql -- map 751 Lordaeron extension, DB step 20.
--
-- Removes the duplicate wagons and duplicate crew that 79_ exposed.
--
-- WHY THERE ARE DUPLICATES
-- The Silverpine wagons were captured by a sniffer while they were DRIVING, so
-- every position the wagon happened to occupy became a "spawn" in the source data,
-- each with its own copy of the crew standing beside it. Proof: hauler guid
-- 16719448 sits at (1376.23, 828.832, 48.7509), byte-identical to node 5 of route
-- 447310, and each capture faces the direction of travel.
--
-- 79_ gave the ONE real wagon (16716000) the route and the accessory crew, which
-- means the loose crew beside it is now a second copy riding along on foot --
-- the two stacked "Subdued Forest Ettin" nameplates in-game. The other four wagons
-- have no route and just sit there.
--
-- After this file: exactly one Horde Hauler, driving route 447310, carrying its
-- crew in the seats 79_ assigned.
--
-- REVERSIBLE: nothing here is referenced by anything else -- no waypoints, no
-- gossip, no quest, no vehicle accessory points at these guids. Re-importing the
-- band restores them.

-- ---------------------------------------------------------------------------
-- 1. The four captured wagons. 16716000 is KEPT -- it is the route origin and the
--    only one carrying creature_addon.path_id.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (16714741, 16715001, 16715487, 16719448);
DELETE FROM `creature`       WHERE `guid` IN (16714741, 16715001, 16715487, 16719448);

-- ---------------------------------------------------------------------------
-- 2. The crew clusters that belong to those four captures.
--    (Engineer 4144734, Forsaken Troopers 4144732/4144733, Subdued Forest Ettin
--     4144737 -- one cluster per captured wagon position.)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (
    16714742,
    16715000, 16715002, 16715003, 16715004, 16715005, 16715006, 16715007,
    16715488, 16715489, 16715490, 16715491, 16715492, 16715493, 16715494,
    16719449, 16719450, 16719451, 16719452, 16719453, 16719454, 16719455);
DELETE FROM `creature` WHERE `guid` IN (
    16714742,
    16715000, 16715002, 16715003, 16715004, 16715005, 16715006, 16715007,
    16715488, 16715489, 16715490, 16715491, 16715492, 16715493, 16715494,
    16719449, 16719450, 16719451, 16719452, 16719453, 16719454, 16719455);

-- ---------------------------------------------------------------------------
-- 3. The crew standing next to the SURVIVING wagon. This is the pair you can see
--    doubled in-game: 79_ seats an Engineer, an Ettin and five Troopers as vehicle
--    accessories, so these loose copies are now redundant and would be left behind
--    on foot the moment the wagon drives off.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (16716001, 16716011, 16716012, 16716013, 16716014, 16716015, 16716016);
DELETE FROM `creature`       WHERE `guid` IN (16716001, 16716011, 16716012, 16716013, 16716014, 16716015, 16716016);

-- ---------------------------------------------------------------------------
-- 4. The orphaned crew cluster at (-60.9, 1184.4) -- an Engineer and five Troopers
--    205 yards from any wagon, captured at the route terminus after their wagon had
--    already despawned. TrinityCore deletes these in the same statement.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (16714760, 16714761, 16714762, 16714763, 16714764, 16714765);
DELETE FROM `creature`       WHERE `guid` IN (16714760, 16714761, 16714762, 16714763, 16714764, 16714765);

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'Horde Hauler spawns (want 1)' AS what, COUNT(*) AS n FROM `creature` WHERE `id` = 4144731
UNION ALL SELECT '  and it is the routed one (want 1)', COUNT(*)
FROM `creature` c JOIN `creature_addon` a ON a.`guid` = c.`guid`
WHERE c.`id` = 4144731 AND c.`MovementType` = 2 AND a.`path_id` = 447310
UNION ALL SELECT 'loose crew left within 20yd of it (want 0)', COUNT(*)
FROM `creature` c
WHERE c.`id` IN (4144732, 4144733, 4144734, 4144737)
  AND EXISTS (SELECT 1 FROM `creature` w WHERE w.`id` = 4144731
              AND SQRT(POW(c.`position_x` - w.`position_x`, 2) + POW(c.`position_y` - w.`position_y`, 2)) < 20)
UNION ALL SELECT 'accessory rows that will seat them (want 7)', COUNT(*)
FROM `vehicle_template_accessory` WHERE `entry` = 4144731;

-- Whatever crew remains anywhere on map 751 -- these are legitimate standing NPCs
-- elsewhere in Silverpine, not wagon crew. Eyeball the count, do not blanket-delete.
SELECT c.`id`, t.`name`, COUNT(*) AS remaining
FROM `creature` c JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE c.`id` IN (4144732, 4144733, 4144734, 4144737)
GROUP BY c.`id`, t.`name` ORDER BY c.`id`;
