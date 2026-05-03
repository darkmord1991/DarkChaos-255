-- HinterlandBGTest literal snapshot cleanup
-- Reverts the fixed-ID import from:
--   2026-05-03_copy_map0_slice_to_hinterlandbgtest_literal.sql

-- Imported fixed ranges:
--   creature guid range   = 9001718 .. 9001873
--   waypoint id range     = 53004947 .. 53004956
--   gameobject guid range = 5714939 .. 5715360

DELETE FROM `gameobject`
WHERE `guid` BETWEEN 5714939 AND 5715360;

DELETE FROM `waypoint_data`
WHERE `id` BETWEEN 53004947 AND 53004956;

DELETE FROM `creature_addon`
WHERE `guid` BETWEEN 9001718 AND 9001873;

DELETE FROM `creature`
WHERE `guid` BETWEEN 9001718 AND 9001873;