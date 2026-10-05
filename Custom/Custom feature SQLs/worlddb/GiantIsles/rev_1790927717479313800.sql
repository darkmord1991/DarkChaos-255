-- Isles of Giants (map 1405), Sunken Temple: portals out of the cavern basement back to the entrance landing.
-- The temple terrace round the entrance (Z 60-85, under the rock shell) ends in sheer walls on every side. Whoever
-- runs down them lands 20-50 yd lower on the cavern floor (Z 33.3) with no visible way back up. A walk model of the
-- deployed terrain + temple + cavern found 2586 possible drop spots all round the terrace; these five spots (k-center
-- over those landings, 5+ yd headroom for the model) keep the nearest portal within ~52 yd walk, 28 yd on average.
-- Spellcaster with no spell + SmartAI teleport on gossip hello: no state change, no despawn, reusable, usable mounted.
-- More can be placed in game with .gobject add 700017; the teleport lives on the template.
DELETE FROM `gameobject_template` WHERE `entry` = 700017;
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`) VALUES
(700017, 22, 672, 'Portal to the Temple Entrance', '', '', '', 0.6, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartGameObjectAI', '', 0);
DELETE FROM `smart_scripts` WHERE `entryorguid` = 700017 AND `source_type` = 1;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(700017, 1, 0, 0, 64, 0, 100, 0, 1, 0, 0, 0, 0, 0, 62, 1405, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 6192.6577, 1084.4207, 81.83047, 6.1340504, 'Portal to the Temple Entrance - On Gossip Hello - Teleport Invoker');
DELETE FROM `gameobject` WHERE `id` = 700017 AND `guid` BETWEEN 9000327 AND 9000331;
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`) VALUES
(9000327, 700017, 1405, 0, 0, 1, 1, 6226.2, 1137.2, 33.3, 4.82487, 0, 0, 0.666242, -0.745736, 300, 100, 1, '', 0, 'Sunken Temple basement - return portal (west)'),
(9000328, 700017, 1405, 0, 0, 1, 1, 6182.2, 997.2, 33.3, 1.00390, 0, 0, 0.481138, 0.876645, 300, 100, 1, '', 0, 'Sunken Temple basement - return portal (south-east)'),
(9000329, 700017, 1405, 0, 0, 1, 1, 6166.2, 1161.2, 33.3, 5.38306, 0, 0, 0.435021, -0.900420, 300, 100, 1, '', 0, 'Sunken Temple basement - return portal (south-west)'),
(9000330, 700017, 1405, 0, 0, 1, 1, 6274.2, 1037.2, 33.3, 2.37348, 0, 0, 0.927152, 0.374686, 300, 100, 1, '', 0, 'Sunken Temple basement - return portal (east)'),
(9000331, 700017, 1405, 0, 0, 1, 1, 6320.2, 1125.2, 33.3, 3.64655, 0, 0, 0.968297, -0.249803, 300, 100, 1, '', 0, 'Sunken Temple basement - return portal (north-west)');
