-- 83_coffin_hauler_return.sql -- map 751 Lordaeron extension, DB step 22.
--
-- Gives the Horde Coffin Hauler the return trip it is supposed to run, and clears
-- its sniffer captures the way 81_ did for the Horde Hauler.
--
-- WHY: after 79_/81_ exactly ONE wagon on map 751 moved -- 4144731 on path 447310.
-- All four 4144764 Horde Coffin Hauler spawns sat at MovementType 0 with no path,
-- and two of them are 30 and 120 yards from the routed hauler's spawn point, so the
-- cluster reads as "the wagons do not move" even though one of them does.
--
-- Their four positions are strung along the SAME road in the opposite direction,
-- i.e. the same sniffer-capture pattern 81_ dealt with: one wagon recorded at four
-- moments of its journey, not four parked wagons.
--
-- TrinityCore never scripted 44764, so there is no upstream route to port. This
-- builds one by REVERSING path 447310 node-for-node: the coffin wagon runs Forsaken
-- Front -> Sepulcher -> Forsaken High Command while the passenger wagon runs the
-- other way. That is exactly what the conductor describes -- broadcast_text 44790,
-- "...you definitely don't want to be comin' back on the other wagon."
--
-- The three stop delays land on the mirrored nodes (old 11/35/60 -> new 53/29/4),
-- so it still pauses at the same three places.
--
-- Path id 447640 = 44764 * 10, matching 447310's derivation from 44731.

-- ---------------------------------------------------------------------------
-- 1. The return route: path 447310 reversed, 63 nodes
-- ---------------------------------------------------------------------------
DELETE FROM `waypoint_data` WHERE `id` = 447640;

INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`, `action`, `action_chance`, `wpguid`) VALUES
(447640, 1, -277.264, 1186.42, 63.71381, NULL, 0, 1, 0, 0, 0),
(447640, 2, -237.741, 1184, 63.89516, NULL, 0, 1, 0, 0, 0),
(447640, 3, -217.497, 1197.7, 61.34966, NULL, 0, 1, 0, 0, 0),
(447640, 4, -140.623, 1220.49, 55.77021, NULL, 14437, 1, 0, 0, 0),
(447640, 5, -122.601, 1218.69, 57.16767, NULL, 0, 1, 0, 0, 0),
(447640, 6, -97.8073, 1205.1, 61.67491, NULL, 0, 1, 0, 0, 0),
(447640, 7, -74.224, 1185.74, 64.07846, NULL, 0, 1, 0, 0, 0),
(447640, 8, -55.3455, 1183.69, 64.11707, NULL, 0, 1, 0, 0, 0),
(447640, 9, -22.8194, 1196.91, 64.54131, NULL, 0, 1, 0, 0, 0),
(447640, 10, 6.75347, 1207.66, 64.7567, NULL, 0, 1, 0, 0, 0),
(447640, 11, 41.9844, 1217.66, 65.97113, NULL, 0, 1, 0, 0, 0),
(447640, 12, 72.3872, 1224.89, 66.99799, NULL, 0, 1, 0, 0, 0),
(447640, 13, 99.1649, 1232.69, 68.65864, NULL, 0, 1, 0, 0, 0),
(447640, 14, 129.401, 1241.76, 70.83018, NULL, 0, 1, 0, 0, 0),
(447640, 15, 165.106, 1252.77, 71.03636, NULL, 0, 1, 0, 0, 0),
(447640, 16, 196.939, 1261.47, 73.74019, NULL, 0, 1, 0, 0, 0),
(447640, 17, 229.385, 1269.64, 75.74796, NULL, 0, 1, 0, 0, 0),
(447640, 18, 252.155, 1271.47, 76.86637, NULL, 0, 1, 0, 0, 0),
(447640, 19, 276.116, 1268.98, 76.91445, NULL, 0, 1, 0, 0, 0),
(447640, 20, 316.095, 1254.61, 79.77526, NULL, 0, 1, 0, 0, 0),
(447640, 21, 354.031, 1242.62, 81.45962, NULL, 0, 1, 0, 0, 0),
(447640, 22, 380.946, 1236.21, 82.31158, NULL, 0, 1, 0, 0, 0),
(447640, 23, 426.493, 1231.84, 86.02214, NULL, 0, 1, 0, 0, 0),
(447640, 24, 473.8, 1229.53, 88.59075, NULL, 0, 1, 0, 0, 0),
(447640, 25, 510.122, 1229.87, 89.16954, NULL, 0, 1, 0, 0, 0),
(447640, 26, 538.931, 1232.14, 88.07486, NULL, 0, 1, 0, 0, 0),
(447640, 27, 563.847, 1243.76, 86.40284, NULL, 0, 1, 0, 0, 0),
(447640, 28, 588.17, 1264.16, 87.0507, NULL, 0, 1, 0, 0, 0),
(447640, 29, 632.7715, 1297.872, 86.28932, NULL, 22727, 1, 0, 0, 0),
(447640, 30, 657.045, 1307.14, 83.46642, NULL, 0, 1, 0, 0, 0),
(447640, 31, 684.753, 1324.13, 79.64048, NULL, 0, 1, 0, 0, 0),
(447640, 32, 706.53, 1343.75, 76.35209, NULL, 0, 1, 0, 0, 0),
(447640, 33, 726.372, 1355.76, 72.68143, NULL, 0, 1, 0, 0, 0),
(447640, 34, 756.422, 1363.12, 68.24586, NULL, 0, 1, 0, 0, 0),
(447640, 35, 781.707, 1361.56, 63.38396, NULL, 0, 1, 0, 0, 0),
(447640, 36, 817.226, 1360.42, 56.82727, NULL, 0, 1, 0, 0, 0),
(447640, 37, 862.208, 1360.47, 55.05869, NULL, 0, 1, 0, 0, 0),
(447640, 38, 884.262, 1359.47, 51.60058, NULL, 0, 1, 0, 0, 0),
(447640, 39, 914.736, 1350.73, 48.26861, NULL, 0, 1, 0, 0, 0),
(447640, 40, 944.924, 1337.44, 46.59942, NULL, 0, 1, 0, 0, 0),
(447640, 41, 973.655, 1319.77, 45.81734, NULL, 0, 1, 0, 0, 0),
(447640, 42, 1003.73, 1300.82, 45.92109, NULL, 0, 1, 0, 0, 0),
(447640, 43, 1031.2, 1283.19, 46.02351, NULL, 0, 1, 0, 0, 0),
(447640, 44, 1058.24, 1260.29, 46.20926, NULL, 0, 1, 0, 0, 0),
(447640, 45, 1079.26, 1238.68, 46.27145, NULL, 0, 1, 0, 0, 0),
(447640, 46, 1104.62, 1214.52, 46.48087, NULL, 0, 1, 0, 0, 0),
(447640, 47, 1143.06, 1189.04, 47.96444, NULL, 0, 1, 0, 0, 0),
(447640, 48, 1179.04, 1166.92, 48.97422, NULL, 0, 1, 0, 0, 0),
(447640, 49, 1215.21, 1141.04, 50.52694, NULL, 0, 1, 0, 0, 0),
(447640, 50, 1242.83, 1120.81, 50.58637, NULL, 0, 1, 0, 0, 0),
(447640, 51, 1271.49, 1096.01, 51.89646, NULL, 0, 1, 0, 0, 0),
(447640, 52, 1296.54, 1066.29, 54.07921, NULL, 0, 1, 0, 0, 0),
(447640, 53, 1326.23, 1016.23, 54.71355, NULL, 22863, 1, 0, 0, 0),
(447640, 54, 1332.58, 998.137, 54.67904, NULL, 0, 1, 0, 0, 0),
(447640, 55, 1337.94, 956.62, 54.63557, NULL, 0, 1, 0, 0, 0),
(447640, 56, 1343.64, 925.507, 54.68269, NULL, 0, 1, 0, 0, 0),
(447640, 57, 1354.39, 887.825, 54.36447, NULL, 0, 1, 0, 0, 0),
(447640, 58, 1365.51, 856.457, 51.24048, NULL, 0, 1, 0, 0, 0),
(447640, 59, 1376.23, 828.832, 48.75095, NULL, 0, 1, 0, 0, 0),
(447640, 60, 1394.08, 784.649, 47.12907, NULL, 0, 1, 0, 0, 0),
(447640, 61, 1410.4, 745.214, 47.251, NULL, 0, 1, 0, 0, 0),
(447640, 62, 1422.39, 713.509, 47.1535, NULL, 0, 1, 0, 0, 0),
(447640, 63, 1442.45, 683.194, 47.21392, NULL, 0, 1, 0, 0, 0);

-- ---------------------------------------------------------------------------
-- 2. Keep the capture nearest the northern terminus as the real wagon and route it.
--    guid 16714703 (1.9, 1199.6) sits closest to reversed node 1 (-277.3, 1186.4).
-- ---------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` = 16714703;

INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
VALUES (16714703, 447640, 0, 0, 1, 0, 0, '');

UPDATE `creature` SET `MovementType` = 2, `wander_distance` = 0 WHERE `guid` = 16714703;

-- ---------------------------------------------------------------------------
-- 3. The other three captures. Two of these are the wagons parked beside the
--    routed Horde Hauler that make the whole group look static.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (16715041, 16719787, 16720390);
DELETE FROM `creature`       WHERE `guid` IN (16715041, 16719787, 16720390);

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'coffin hauler spawns (want 1)' AS what, COUNT(*) AS n FROM `creature` WHERE `id` = 4144764
UNION ALL SELECT '  routed (want 1)', COUNT(*) FROM `creature` c JOIN `creature_addon` a ON a.`guid` = c.`guid`
WHERE c.`id` = 4144764 AND c.`MovementType` = 2 AND a.`path_id` = 447640
UNION ALL SELECT 'return-route nodes (want 63)', COUNT(*) FROM `waypoint_data` WHERE `id` = 447640
UNION ALL SELECT 'stop delays on the return route (want 3)', COUNT(*) FROM `waypoint_data` WHERE `id` = 447640 AND `delay` > 0
UNION ALL SELECT 'ALL wagons on map 751 that now move (want 2)', COUNT(*)
FROM `creature` c JOIN `creature_addon` a ON a.`guid` = c.`guid`
WHERE c.`id` IN (4144731, 4144764) AND c.`MovementType` = 2 AND a.`path_id` > 0;

-- must be empty: a wagon left parked with no route
SELECT 'PROBLEM: wagon with no route' AS problem, c.`guid`, c.`id`, c.`MovementType`
FROM `creature` c LEFT JOIN `creature_addon` a ON a.`guid` = c.`guid`
WHERE c.`id` IN (4144731, 4144764) AND (c.`MovementType` <> 2 OR IFNULL(a.`path_id`, 0) = 0);
