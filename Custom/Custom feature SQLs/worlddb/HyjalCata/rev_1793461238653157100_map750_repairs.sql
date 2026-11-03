-- Map 750 repairs: the same audit that map 751 had.
--
-- Duplicates: 46 gameobjects stood twice on one point with the same facing (mostly the Azshara and Ashenvale
-- import repeating itself). Two pairs of 4080427 differ in facing and stay. Creature stacks were checked against
-- cata_world and are Blizzard's own, so none are removed. Removed rows are kept in dc_map750_repair_go_bak.
--
-- Holidays: map 750 had no game_event links, so 540 holiday objects and 26 NPCs stood all year. Bound by
-- entry where the source is event-only. Goblin Commoner has mixed events and stays unbound.
--
-- Kill credit: quest ids are global, so stock quests keep their raw objectives and the clones credit them.
-- Cata removed three mobs that stock quests still name; a living relative credits those through KillCredit2.
--
-- Lost spawns: six quest NPCs and six objects never reached map 750. All positions come from cata_world, except
-- Je'neu and Thessera, who are not in cata_world and use nelt_world. Displays 10099 and 9877 are not in GameObjectDisplayInfo.dbc
-- and the core refuses such a spawn, so the two questgiver objects use existing art until the real models ship.
--
-- Quests: stock quests whose NPCs exist here as clones, enders before starters. Stock quest rows are not touched.
-- Quests 105165 and 104906 are DC-owned, so their objectives are edited directly.
--
-- Safe to run twice. Restart the server afterwards, do not use .reload quest_template.

-- 1. Duplicate gameobjects
CREATE TABLE IF NOT EXISTS `dc_map750_repair_go_bak` LIKE `gameobject`;
DELETE FROM `dc_map750_repair_go_bak` WHERE `guid` IN (SELECT `guid` FROM `gameobject` WHERE `map` = 750 AND `guid` IN (16326907, 16330248, 16330249, 16330250, 16330313, 16330314, 16330315, 16330316, 16330317, 16330318, 16330319, 16330320, 16330321, 16330322, 16330323, 16330324, 16330325, 16330326, 16330327, 16330328, 16330329, 16330330, 16330331, 16330332, 16330333, 16330334, 16330335, 16330336, 16330337, 16330338, 16330339, 16330340, 16330341, 16330342, 16330343, 16330344, 16330345, 16330346, 16330347, 16330393, 16330394, 16330395, 16330396, 16330398, 16330401, 16330407));
INSERT INTO `dc_map750_repair_go_bak` SELECT `g`.* FROM `gameobject` `g` WHERE `g`.`map` = 750 AND `g`.`guid` IN (16326907, 16330248, 16330249, 16330250, 16330313, 16330314, 16330315, 16330316, 16330317, 16330318, 16330319, 16330320, 16330321, 16330322, 16330323, 16330324, 16330325, 16330326, 16330327, 16330328, 16330329, 16330330, 16330331, 16330332, 16330333, 16330334, 16330335, 16330336, 16330337, 16330338, 16330339, 16330340, 16330341, 16330342, 16330343, 16330344, 16330345, 16330346, 16330347, 16330393, 16330394, 16330395, 16330396, 16330398, 16330401, 16330407);
DELETE FROM `gameobject_addon` WHERE `guid` IN (16326907, 16330248, 16330249, 16330250, 16330313, 16330314, 16330315, 16330316, 16330317, 16330318, 16330319, 16330320, 16330321, 16330322, 16330323, 16330324, 16330325, 16330326, 16330327, 16330328, 16330329, 16330330, 16330331, 16330332, 16330333, 16330334, 16330335, 16330336, 16330337, 16330338, 16330339, 16330340, 16330341, 16330342, 16330343, 16330344, 16330345, 16330346, 16330347, 16330393, 16330394, 16330395, 16330396, 16330398, 16330401, 16330407);
DELETE FROM `game_event_gameobject` WHERE `guid` IN (16326907, 16330248, 16330249, 16330250, 16330313, 16330314, 16330315, 16330316, 16330317, 16330318, 16330319, 16330320, 16330321, 16330322, 16330323, 16330324, 16330325, 16330326, 16330327, 16330328, 16330329, 16330330, 16330331, 16330332, 16330333, 16330334, 16330335, 16330336, 16330337, 16330338, 16330339, 16330340, 16330341, 16330342, 16330343, 16330344, 16330345, 16330346, 16330347, 16330393, 16330394, 16330395, 16330396, 16330398, 16330401, 16330407);
DELETE FROM `gameobject` WHERE `map` = 750 AND `id` IN (3780405, 3780406, 3780407, 3780411, 3780415, 3780425, 3780431, 3780471, 3780472, 3780523, 3790079, 3795638, 3795639, 3796475, 3890106) AND `guid` IN (16326907, 16330248, 16330249, 16330250, 16330313, 16330314, 16330315, 16330316, 16330317, 16330318, 16330319, 16330320, 16330321, 16330322, 16330323, 16330324, 16330325, 16330326, 16330327, 16330328, 16330329, 16330330, 16330331, 16330332, 16330333, 16330334, 16330335, 16330336, 16330337, 16330338, 16330339, 16330340, 16330341, 16330342, 16330343, 16330344, 16330345, 16330346, 16330347, 16330393, 16330394, 16330395, 16330396, 16330398, 16330401, 16330407);

-- 2. Holiday links
DELETE FROM `game_event_gameobject` WHERE `eventEntry` = 12 AND `guid` IN (SELECT `guid` FROM `gameobject` WHERE `map` = 750);
INSERT INTO `game_event_gameobject` (`eventEntry`, `guid`) SELECT 12, `guid` FROM `gameobject` WHERE `map` = 750 AND `id` IN (3780405, 3780406, 3780407, 3780408, 3780409, 3780410, 3780411, 3780415, 3780425, 3780426, 3780427, 3780431, 3780471, 3780472, 3780523, 3785436, 3790079, 3880405, 3880406, 3880407, 3880415, 3880426, 3880427, 3880471, 3880523, 3890106, 4080405, 4080406, 4080407, 4080411, 4080415, 4080425, 4080426, 4080427, 4080471, 4080472, 4080523);
DELETE FROM `game_event_gameobject` WHERE `eventEntry` = 1 AND `guid` IN (SELECT `guid` FROM `gameobject` WHERE `map` = 750);
INSERT INTO `game_event_gameobject` (`eventEntry`, `guid`) SELECT 1, `guid` FROM `gameobject` WHERE `map` = 750 AND `id` IN (3887918, 3887989, 4081388, 4081392, 4081393, 4081401, 4087576);
DELETE FROM `game_event_gameobject` WHERE `eventEntry` = 2 AND `guid` IN (SELECT `guid` FROM `gameobject` WHERE `map` = 750);
INSERT INTO `game_event_gameobject` (`eventEntry`, `guid`) SELECT 2, `guid` FROM `gameobject` WHERE `map` = 750 AND `id` IN (4080844);
DELETE FROM `game_event_gameobject` WHERE `eventEntry` = 8 AND `guid` IN (SELECT `guid` FROM `gameobject` WHERE `map` = 750);
INSERT INTO `game_event_gameobject` (`eventEntry`, `guid`) SELECT 8, `guid` FROM `gameobject` WHERE `map` = 750 AND `id` IN (3781055);
DELETE FROM `game_event_creature` WHERE `eventEntry` = 1 AND `guid` IN (SELECT `guid` FROM `creature` WHERE `map` = 750);
INSERT INTO `game_event_creature` (`eventEntry`, `guid`) SELECT 1, `guid` FROM `creature` WHERE `map` = 750 AND `id` IN (3625949, 3717066, 3725863, 3725866, 3725924, 3726355);
DELETE FROM `game_event_creature` WHERE `eventEntry` = 2 AND `guid` IN (SELECT `guid` FROM `creature` WHERE `map` = 750);
INSERT INTO `game_event_creature` (`eventEntry`, `guid`) SELECT 2, `guid` FROM `creature` WHERE `map` = 750 AND `id` IN (3715760);
DELETE FROM `game_event_creature` WHERE `eventEntry` = 7 AND `guid` IN (SELECT `guid` FROM `creature` WHERE `map` = 750);
INSERT INTO `game_event_creature` (`eventEntry`, `guid`) SELECT 7, `guid` FROM `creature` WHERE `map` = 750 AND `id` IN (3715897);

-- 3. Kill credit
UPDATE `creature_template` SET `KillCredit1` = `entry` - 3600000 WHERE `KillCredit1` = 0 AND `entry` IN (3603696, 3603743, 3603750, 3603924, 3603925, 3603932, 3603940, 3603941, 3603942, 3606072, 3606073, 3606115, 3606190, 3610737, 3611681, 3611684, 3611697, 3612856, 3617300, 3617304);
UPDATE `creature_template` SET `KillCredit1` = `entry` - 3700000 WHERE `KillCredit1` = 0 AND `entry` IN (3703924, 3703925, 3707428, 3707429, 3707431, 3707438, 3707439, 3709454, 3710807);
UPDATE `creature_template` SET `KillCredit2` = 3746 WHERE `KillCredit2` = 0 AND `entry` = 3603743; -- Foulweald Den Watcher, quest 1025
UPDATE `creature_template` SET `KillCredit2` = 3749 WHERE `KillCredit2` = 0 AND `entry` = 3603750; -- Foulweald Ursa, quest 1025
UPDATE `creature_template` SET `KillCredit2` = 11680 WHERE `KillCredit2` = 0 AND `entry` = 3611681; -- Horde Scout, quest 9518
UPDATE `creature_template` SET `KillCredit2` = 7441 WHERE `KillCredit2` = 0 AND `entry` = 3707441; -- Winterfall Totemic, quest 105082

-- 4. Combat scripts the clones lost
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (3703725, 3703730, 3707430);
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) SELECT `entryorguid` + 3700000, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment` FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (3725, 3730, 7430);
UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `entry` IN (3703725, 3703730, 3707430);

-- 5. Lost NPCs. Levels follow the 233_ band rules, and Lord Banehollow is a kill target here as he is in Cata.
DELETE FROM `creature` WHERE `map` = 750 AND `id` IN (3703846, 3709454, 3709516, 3709877, 3712736, 3733166) AND `guid` IN (16330401, 16330402, 16330403, 16330404, 16330405, 16330406);
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(16330401, 3709454, 750, 0, 0, 1, 1, 0, 4581.29, -228.356, 299.614, 4.66003, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'map750 repair'),
(16330402, 3709877, 750, 0, 0, 1, 1, 0, 4995.56, -445.32, 316.99, 1.38, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'map750 repair'),
(16330403, 3709516, 750, 0, 0, 1, 1, 0, 5301.08, -529.86, 273.15, 2.93, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'map750 repair'),
(16330404, 3703846, 750, 0, 0, 1, 1, 1, 3884.19, 649.361, 10.5395, 0.506145, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'map750 repair'),
(16330405, 3712736, 750, 0, 0, 1, 1, 1, 3355.07, 1033.14, 6.03463, 1.50098, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'map750 repair'),
(16330406, 3733166, 750, 0, 0, 1, 1, 0, 5768.42, -164.477, 13.8271, 2.46091, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'map750 repair');
DELETE FROM `dc_map750_entryzone` WHERE `entry` IN (3703846, 3709454, 3709516, 3709877, 3712736, 3733166);
INSERT INTO `dc_map750_entryzone` (`entry`, `zone`, `share`, `spawns`) VALUES
(3709454, 4927, 1.000, 1),
(3709877, 4927, 1.000, 1),
(3709516, 4927, 1.000, 1),
(3703846, 4931, 1.000, 1),
(3712736, 4931, 1.000, 1),
(3733166, 4929, 1.000, 1);
UPDATE `creature_template` SET `minlevel` = 103, `maxlevel` = 103 WHERE `entry` = 3709454;
UPDATE `creature_template` SET `minlevel` = 97, `maxlevel` = 97 WHERE `entry` = 3709877;
UPDATE `creature_template` SET `minlevel` = 106, `maxlevel` = 106 WHERE `entry` = 3709516;
UPDATE `creature_template` SET `minlevel` = 98, `maxlevel` = 98 WHERE `entry` = 3703846;
UPDATE `creature_template` SET `minlevel` = 98, `maxlevel` = 98 WHERE `entry` = 3712736;
UPDATE `creature_template` SET `minlevel` = 90, `maxlevel` = 90 WHERE `entry` = 3733166;
UPDATE `creature_template` SET `npcflag` = 0, `rank` = 0 WHERE `entry` = 3709516;

-- 6. Lost objects
UPDATE `gameobject_template` SET `displayId` = 6829 WHERE `entry` = 3906585 AND `displayId` = 10099;
UPDATE `gameobject_template` SET `displayId` = 356 WHERE `entry` = 3907104 AND `displayId` = 9877;
DELETE FROM `gameobject` WHERE `map` = 750 AND `id` IN (3876158, 3876159, 3876160, 3876161, 3906585, 3907104) AND `guid` IN (16530211, 16530212, 16530213, 16530214, 16530215, 16530216);
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`) VALUES
(16530211, 3906585, 750, 0, 0, 1, 1, 3852.05, -1323.41, 211.731, 5.50651, 0, 0, 0.37865, -0.92554, 300, 255, 1, '', 0, 'map750 repair'),
(16530212, 3907104, 750, 0, 0, 1, 1, 6333.04, -1869.49, 433.133, 0.942477, 0, 0, 0.45399, 0.891007, 300, 255, 1, '', 0, 'map750 repair'),
(16530213, 3876158, 750, 0, 0, 1, 1, 4976.81, -442.369, 315.446, 4.36332, 0, 0, 0.819153, -0.573575, 300, 255, 1, '', 0, 'map750 repair'),
(16530214, 3876159, 750, 0, 0, 1, 1, 5115.96, -522.245, 296.003, 4.36332, 0, 0, 0.819153, -0.573575, 300, 255, 1, '', 0, 'map750 repair'),
(16530215, 3876160, 750, 0, 0, 1, 1, 5093.39, -468.079, 297.572, 4.36332, 0, 0, 0.819153, -0.573575, 300, 255, 1, '', 0, 'map750 repair'),
(16530216, 3876161, 750, 0, 0, 1, 1, 5019.57, -454.598, 321.341, 5.36689, 0, 0, 0.442288, -0.896873, 300, 255, 1, '', 0, 'map750 repair');

-- 7. Quest objectives
-- Both Felwood brazier quests now share the clone braziers placed above.
UPDATE `quest_template` SET `RequiredNpcOrGo1` = -3876158, `RequiredNpcOrGo2` = -3876159, `RequiredNpcOrGo3` = -3876160, `RequiredNpcOrGo4` = -3876161 WHERE `ID` = 105165 AND `RequiredNpcOrGo1` = -176158;
-- Jadefire Betrayer has no spawn in any source.
UPDATE `quest_template` SET `RequiredNpcOrGo2` = 0, `RequiredNpcOrGoCount2` = 0 WHERE `ID` = 104906 AND `RequiredNpcOrGo2` = 7108;
-- Quest 1022 needs the raw Tome, and GO credit uses the object's own entry. The entry script summons at a map 1
-- position, so this spawn gets its own row at the tome.
UPDATE `gameobject` SET `id` = 19027 WHERE `id` = 3619027 AND `guid` = 16329341;
DELETE FROM `smart_scripts` WHERE `entryorguid` = -16329341 AND `source_type` = 1;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(-16329341, 1, 0, 0, 70, 0, 100, 0, 2, 0, 0, 0, 0, 0, 12, 3946, 2, 40000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Tome of Mel''Thandris - On Gameobject State Changed - Summon Velinde Starsong beside the map 750 tome');
-- Gnarl offered stock 9526 for raw mounds that are not on this map. Cata's 26446 uses the clones already here.
-- The ender for 9526 stays so nobody is left holding it.
DELETE FROM `creature_queststarter` WHERE `id` = 3617310 AND `quest` = 9526;

-- 8. Quest givers
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((3712736, 824), (3603891, 991), (3603691, 1023), (3603916, 1024), (3603916, 1026), (3603916, 1027), (3603691, 1029), (3603897, 1030), (3603897, 1045), (3603691, 1046), (3703847, 1010), (3603885, 1016), (3710918, 5126), (3710918, 5127), (3711806, 5713), (3712719, 6442), (3711799, 28), (3711799, 29), (3703846, 1007), (3703846, 1009), (3617310, 26446));
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(3712736, 824),
(3603891, 991),
(3603691, 1023),
(3603916, 1024),
(3603916, 1026),
(3603916, 1027),
(3603691, 1029),
(3603897, 1030),
(3603897, 1045),
(3603691, 1046),
(3703847, 1010),
(3603885, 1016),
(3710918, 5126),
(3710918, 5127),
(3711806, 5713),
(3712719, 6442),
(3711799, 28),
(3711799, 29),
(3703846, 1007),
(3703846, 1009),
(3617310, 26446);
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((3703694, 990), (3603691, 991), (3603891, 1023), (3603691, 1024), (3603916, 1026), (3603916, 1027), (3603916, 1029), (3603691, 1030), (3603897, 1045), (3603897, 1046), (3703847, 1010), (3703847, 1020), (3603885, 1016), (3710918, 5126), (3710918, 5127), (3711711, 5713), (3712719, 6442), (3712818, 6482), (3703846, 1007), (3703846, 1009), (3617310, 26446));
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(3703694, 990),
(3603691, 991),
(3603891, 1023),
(3603691, 1024),
(3603916, 1026),
(3603916, 1027),
(3603916, 1029),
(3603691, 1030),
(3603897, 1045),
(3603897, 1046),
(3703847, 1010),
(3703847, 1020),
(3603885, 1016),
(3710918, 5126),
(3710918, 5127),
(3711711, 5713),
(3712719, 6442),
(3712818, 6482),
(3703846, 1007),
(3703846, 1009),
(3617310, 26446);
DELETE FROM `gameobject_questender` WHERE `id` = 3619024 AND `quest` = 1028;
INSERT INTO `gameobject_questender` (`id`, `quest`) VALUES (3619024, 1028);
DELETE FROM `gameobject_queststarter` WHERE `id` = 3619024 AND `quest` = 1055;
INSERT INTO `gameobject_queststarter` (`id`, `quest`) VALUES (3619024, 1055);
