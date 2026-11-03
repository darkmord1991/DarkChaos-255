-- Map 751: repopulate Caer Darrow and remove its doubled gameobjects.
--
-- The island held 5 creatures against 30 on stock map 0. Every clone template exists,
-- only the spawns were lost:
--   Eva, Lucien, Marduke are Neltharion-only NPCs. Their rows in 30_neltharion_spawn_layer
--   fell to that file's orphan cleanup, the 29_ templates landed too late to save them.
--   Citizens, Guardsmen, Cannoneers, Horsemen, Melia, Sammy, Baker Masterson and Joseph
--   Dirte are Cata-only NPCs. 30_ keeps their Cata spawns, but those rows are gone too.
--
-- Spawns are copied from stock map 0, whose coordinates match map 751 and the Cata source.
-- guid = 13000000 + stock guid, the same rule as the Neltharion layer.
--
-- These templates were never spawned when 71_ re-leveled the map, so they still carry
-- their original levels. They move to the Western Plaguelands band here and join its
-- bookkeeping tables. The 106_ stat pass is skipped: all of them are friendly.
--
-- Safe to run twice.

-- Spawns
DELETE FROM `creature` WHERE `map` = 751 AND `id` IN (3611216, 3611217, 3611277, 3611279, 3611280, 3611281, 3611282, 3611283, 3611286, 3611287, 3611316) AND `guid` IN (13018037, 13045423, 13045424, 13131325, 13131326, 13131327, 13131328, 13131329, 13131330, 13131331, 13131332, 13131333, 13131334, 13131335, 13131336, 13131337, 13131338, 13131339, 13131340, 13131341, 13131342, 13131343, 13131344, 13131345, 13131346, 13131347);
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`)
SELECT `guid` + 13000000, `id` + 3600000, 751, 4932, 4932, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, 1, 0, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, 'Caer Darrow restore'
FROM `creature`
WHERE `map` = 0
  AND `id` IN (11216, 11217, 11277, 11279, 11280, 11281, 11282, 11283, 11286, 11287, 11316)
  AND `guid` IN (18037, 45423, 45424, 131325, 131326, 131327, 131328, 131329, 131330, 131331, 131332, 131333, 131334, 131335, 131336, 131337, 131338, 131339, 131340, 131341, 131342, 131343, 131344, 131345, 131346, 131347);

-- Addons: the four walkers carry their stock path and auras, the Sarkhoffs their sheath state
DELETE FROM `creature_addon` WHERE `guid` IN (13045423, 13045424, 13131340, 13131341, 13131346, 13131347);
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT `guid` + 13000000, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`
FROM `creature_addon`
WHERE `guid` IN (45423, 45424, 131340, 131341, 131346, 131347);

-- Formation: one horseman escorts the patrolling one
DELETE FROM `creature_formations` WHERE `memberGUID` IN (13131339, 13131341);
INSERT INTO `creature_formations` (`leaderGUID`, `memberGUID`, `dist`, `angle`, `groupAI`, `point_1`, `point_2`) VALUES
(13131341, 13131339, 9, 360, 514, 9, 19),
(13131341, 13131341, 0, 0, 2, 0, 0);

-- Equipment: these spawns use equipment_id 1, which the clones never received
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (3611277, 3611279, 3611280, 3611286, 3611287, 3611316);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT `CreatureID` + 3600000, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`
FROM `creature_equip_template`
WHERE `CreatureID` IN (11277, 11279, 11280, 11286, 11287, 11316);

-- Levels: bookkeeping keeps the original levels, the results are the 71_ formula for band 4932
DELETE FROM `dc_map751_entryzone` WHERE `entry` IN (3611216, 3611217, 3611277, 3611279, 3611280, 3611281, 3611282, 3611283, 3611286, 3611287, 3611316);
INSERT INTO `dc_map751_entryzone` (`entry`, `zone`) VALUES
(3611216, 4932),
(3611217, 4932),
(3611277, 4932),
(3611279, 4932),
(3611280, 4932),
(3611281, 4932),
(3611282, 4932),
(3611283, 4932),
(3611286, 4932),
(3611287, 4932),
(3611316, 4932);
DELETE FROM `dc_map751_snap` WHERE `entry` IN (3611216, 3611217, 3611277, 3611279, 3611280, 3611281, 3611282, 3611283, 3611286, 3611287, 3611316);
INSERT INTO `dc_map751_snap` (`entry`, `minlevel`, `maxlevel`, `rank`) VALUES
(3611216, 54, 54, 0),
(3611217, 55, 55, 0),
(3611277, 43, 60, 0),
(3611279, 51, 55, 0),
(3611280, 54, 54, 0),
(3611281, 52, 56, 0),
(3611282, 1, 1, 0),
(3611283, 1, 1, 0),
(3611286, 57, 57, 0),
(3611287, 37, 37, 0),
(3611316, 31, 31, 0);
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 153 WHERE `entry` IN (3611216, 3611217, 3611277, 3611279, 3611280, 3611281, 3611286);
UPDATE `creature_template` SET `minlevel` = 149, `maxlevel` = 149 WHERE `entry` = 3611287;
UPDATE `creature_template` SET `minlevel` = 148, `maxlevel` = 148 WHERE `entry` IN (3611282, 3611283, 3611316);

-- Melia and Sammy: the race script targets stock Sammy by entry, which does not exist on
-- this map, so the clone gets its own action list (raw list + 100 * creature offset)
DELETE FROM `smart_scripts` WHERE `entryorguid` = 361128200 AND `source_type` = 9;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT 361128200, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, IF(`target_type` = 19 AND `target_param1` = 11283, 3611283, `target_param1`), `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`
FROM `smart_scripts`
WHERE `entryorguid` = 1128200 AND `source_type` = 9;
UPDATE `smart_scripts` SET `action_param1` = 361128200 WHERE `entryorguid` = 3611282 AND `source_type` = 0 AND `id` = 1 AND `action_type` = 80;

-- Doubled gameobjects on the island: the Meeting Stone, both campfires and the skeleton.
-- 30_ replaced the Cata creature layer but never removed the Cata gameobject layer, so
-- these sit exactly on their Neltharion copies. The Cata copies go.
DELETE FROM `gameobject` WHERE `map` = 751 AND `id` IN (3776186, 3776187, 3776745, 3778832) AND `guid` IN (12627471, 12627472, 12627474, 12627499);
