-- Freed Crusader (30274, Icecrown): the random blessing never fired. List 3027400 called the random
-- list (action 87) from inside itself, and SmartScript::SetScript9 refuses that ("trying to overwrite
-- timed action list from a timed action", 15 times in 3.5 h on 11-21). Pick the random list on Just
-- Summoned instead and give each of the three lists the whole sequence from 2026_11_20_05: blessing and
-- its line, Holy Light, the farewell line, the waypoint and the despawn fallback. 3027400 is unused now.
DELETE FROM `smart_scripts` WHERE `entryorguid` = 30274 AND `source_type` = 0 AND `id` = 0;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(30274,0,0,0,54,0,100,512,0,0,0,0,0,0,87,3027401,3027402,3027403,0,0,0,1,0,0,0,0,0,0,0,0,'Freed Crusader - On Just Summoned - Call Random Timed Action List (Might, Kings, Wisdom)');

DELETE FROM `smart_scripts` WHERE `entryorguid` IN (3027400, 3027401, 3027402, 3027403) AND `source_type` = 9;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(3027401,9,0,0,0,0,100,0,0,0,0,0,0,0,11,56520,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Cast \'Blessing of Might\''),
(3027401,9,1,0,0,0,100,0,100,100,0,0,0,0,1,0,0,1,0,0,0,7,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Say Line 0'),
(3027401,9,2,0,0,0,100,0,3000,4900,0,0,0,0,11,56539,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Cast \'Holy Light\''),
(3027401,9,3,0,0,0,100,0,100,100,0,0,0,0,1,3,0,1,0,0,0,7,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Say Line 3'),
(3027401,9,4,0,0,0,100,0,3000,3000,0,0,0,0,53,2,30274,0,13008,1000,0,1,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Start Waypoint'),
(3027401,9,5,0,0,0,100,0,60000,60000,0,0,0,0,41,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Despawn (fallback)'),
(3027402,9,0,0,0,0,100,0,0,0,0,0,0,0,11,56525,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Cast \'Blessing of Kings\''),
(3027402,9,1,0,0,0,100,0,100,100,0,0,0,0,1,1,0,1,0,0,0,7,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Say Line 1'),
(3027402,9,2,0,0,0,100,0,3000,4900,0,0,0,0,11,56539,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Cast \'Holy Light\''),
(3027402,9,3,0,0,0,100,0,100,100,0,0,0,0,1,3,0,1,0,0,0,7,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Say Line 3'),
(3027402,9,4,0,0,0,100,0,3000,3000,0,0,0,0,53,2,30274,0,13008,1000,0,1,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Start Waypoint'),
(3027402,9,5,0,0,0,100,0,60000,60000,0,0,0,0,41,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Despawn (fallback)'),
(3027403,9,0,0,0,0,100,0,0,0,0,0,0,0,11,56521,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Cast \'Blessing of Wisdom\''),
(3027403,9,1,0,0,0,100,0,100,100,0,0,0,0,1,2,0,1,0,0,0,7,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Say Line 2'),
(3027403,9,2,0,0,0,100,0,3000,4900,0,0,0,0,11,56539,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Cast \'Holy Light\''),
(3027403,9,3,0,0,0,100,0,100,100,0,0,0,0,1,3,0,1,0,0,0,7,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Say Line 3'),
(3027403,9,4,0,0,0,100,0,3000,3000,0,0,0,0,53,2,30274,0,13008,1000,0,1,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Start Waypoint'),
(3027403,9,5,0,0,0,100,0,60000,60000,0,0,0,0,41,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,'Freed Crusader - On Script - Despawn (fallback)');
