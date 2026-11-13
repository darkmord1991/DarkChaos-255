-- Map 751 Silverpine: data for src/server/scripts/DC/Plaguelands/Silverpine/silverpine_dc_fenris_isle.cpp
-- (Agatha, the Fenris Keep scene of 27099 "No Escape", Sylvanas's ride of 27098 "Lordaeron").
--
-- 1. creature_template: none of these 20 entries existed. Values from cata_world, levels moved into
--    the Silverpine band (134-140), ScriptNames as nelt_world binds them.
--    - Plain Cata ids: all are summoned (by spell 83982 or by the scripts), never spawned.
--      44951 Agatha (guardian), 45003 camera, the eight Fenris Keep actors, both warhorses,
--      45051 Sylvanas, Forsaken Troopers 44958-44961.
--    - 44953 is only the quest objective of 27097 (x15); 44951 and 45051 are the objectives of
--      27099 and 27098. AC drops an objective whose creature template does not exist.
--    - 4174951/4174952: Neltharion's bunnies 74951/74952 (no Cata entry) in the 751 band.
--    VehicleIds: the source's 1070/1075/1076/1077 are not in Vehicle.dbc and an unknown id hangs
--    the client, so stock vehicles are used: 532 (Val'kyr Shadowguard carry seat) for Agatha,
--    747 (Camera Vehicle, hidden passenger) for the camera, 636 (Argent Warhorse) for the horses.
--    Displays: 34161 (Crowley) and 34205 (Sophia Zowski) are not in CreatureDisplayInfo.dbc;
--    34078 (a Worgen Renegade display) and 33982 (human female refugee) stand in. Troopers
--    44962-44965 are left out, their displays 33991/33992 are missing too. Bunnies and camera use
--    the invisible display 11686.
-- 2. creature_template_model / _movement / _addon for those entries (Agatha hovers and flies,
--    like the Val'kyr Shadowguard 36609 she borrows the vehicle from).
-- 3. creature_text: Agatha, Crowley, Magistrate Maleb, Sylvanas (nelt_world, 41 rows).
-- 4. summonproperties_dbc 3030 (Cata row). Spell 83982 "Summon Agatha" names it; without it
--    EffectSummonType logs "Unhandled summon type 3030" and Agatha is never summoned. Category 1
--    with flag 0x200 makes her a guardian; slot 6 (quest) is how the script finds her.
-- 5. Six spawns of the two bunnies at their nelt_world positions (zone 4935).
--    Guids 16121951-16121956 were free and are below the 16,777,215 spawn id cap.
--
-- Not here (outside this slice): quests 27097/27098/27099 are not in quest_template, and their
-- giver/ender Lady Sylvanas Windrunner 44365 has no 751 entry, so nothing in this file can be
-- reached in game until those exist.

REPLACE INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`, `unit_flags`, `unit_flags2`, `type`, `type_flags`, `VehicleId`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(44951, 'Agatha', '', 139, 139, 68, 2, 1, 1.14286, 1, 2, 2000, 2000, 2, 0, 2048, 7, 266248, 532, 2.4, 30, 20, 0, 'npc_agatha1_silverpine', 0),
(44953, 'Human to Forsaken Kill Credit', '', 135, 135, 35, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 33554432, 2048, 7, 0, 0, 1, 1, 1, 128, '', 0),
(44958, 'Forsaken Trooper', '', 135, 135, 68, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 33555200, 2048, 7, 0, 0, 1, 1, 1, 0, '', 0),
(44959, 'Forsaken Trooper', '', 135, 135, 68, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 33555200, 2048, 7, 0, 0, 1, 1, 1, 0, '', 0),
(44960, 'Forsaken Trooper', '', 135, 135, 68, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 33555200, 2048, 7, 0, 0, 1, 1, 1, 0, '', 0),
(44961, 'Forsaken Trooper', '', 135, 135, 68, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 33555200, 2048, 7, 0, 0, 1, 1, 1, 0, '', 0),
(44989, 'Lord Darius Crowley', 'Leader of the Gilneas Liberation Front', 137, 137, 2173, 0, 1, 1.14286, 1, 1, 2000, 2000, 1, 768, 2048, 7, 262148, 0, 1, 20, 1, 0, '', 0),
(44990, 'Packleader Ivar Bloodfang', '', 137, 137, 2173, 0, 1, 1.14286, 1, 1, 2000, 2000, 1, 768, 2048, 7, 262148, 0, 1, 20, 1, 0, '', 0),
(44993, 'Phin Odelic', '', 136, 136, 12, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 768, 2048, 7, 0, 0, 1, 1.15, 1, 0, '', 0),
(44994, 'Bartolo Ginsetti', '', 136, 136, 12, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 768, 2048, 7, 0, 0, 1, 1.1, 1, 0, '', 0),
(44995, 'Loremaster Dibbs', '', 136, 136, 12, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 768, 2048, 7, 0, 0, 1, 1.05, 1, 0, '', 0),
(44996, 'Magistrate Henry Maleb', '', 137, 137, 12, 0, 1, 1.14286, 1, 1, 2000, 2000, 2, 768, 2048, 7, 0, 0, 1, 20, 10, 0, '', 0),
(44997, 'Caretaker Smithers', '', 136, 136, 12, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 768, 2048, 7, 0, 0, 1, 1.1, 1, 0, '', 0),
(45002, 'Sophia Zowski', '', 136, 136, 12, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 768, 2048, 7, 0, 0, 1, 1.1, 1, 0, '', 0),
(45003, 'Fenris Keep Camera', '', 1, 1, 35, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 768, 2048, 10, 0, 747, 1, 1, 1, 0, 'npc_fenris_no_escape_camera', 0),
(45041, 'Forsaken Warhorse', '', 135, 135, 35, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 768, 2048, 1, 0, 636, 1, 1, 1, 0, '', 0),
(45051, 'Lady Sylvanas Windrunner', 'Banshee Queen', 140, 140, 35, 0, 1, 1.14286, 3, 1, 2000, 2000, 2, 768, 2048, 7, 2124, 0, 1, 400, 20, 0, '', 0),
(45057, 'Forsaken Warhorse', '', 135, 135, 35, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 768, 2048, 1, 0, 636, 1, 1, 1, 0, 'npc_forsaken_sylv_horse', 0),
(4174951, 'Wondi''s Bunny - Summon Agatha - 2 Quests to No Escape', 'Silverpine Forest', 1, 1, 35, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 33554432, 2048, 10, 0, 0, 1, 1, 1, 128, 'npc_agatha_resummon_controller', 0),
(4174952, 'Wondi''s Bunny - No Escape - Cutscene Controller', 'Silverpine Forest', 1, 1, 35, 0, 1, 1.14286, 0, 1, 2000, 2000, 1, 33554432, 2048, 10, 0, 0, 1, 1, 1, 128, 'npc_no_escape_controller', 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (44951, 44953, 44958, 44959, 44960, 44961, 44989, 44990, 44993, 44994, 44995, 44996, 44997, 45002, 45003, 45041, 45051, 45057, 4174951, 4174952);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(44951, 0, 33996, 1, 1, 0),
(44953, 0, 33978, 1, 1, 0),
(44958, 0, 33986, 1, 1, 0),
(44958, 1, 33987, 1, 1, 0),
(44959, 0, 33986, 1, 1, 0),
(44959, 1, 33987, 1, 1, 0),
(44960, 0, 33986, 1, 1, 0),
(44960, 1, 33987, 1, 1, 0),
(44961, 0, 33986, 1, 1, 0),
(44961, 1, 33987, 1, 1, 0),
(44989, 0, 34078, 1, 1, 0),
(44990, 0, 34162, 1, 1, 0),
(44993, 0, 3666, 1, 1, 0),
(44994, 0, 1662, 1, 1, 0),
(44995, 0, 3702, 1, 1, 0),
(44996, 0, 3665, 1, 1, 0),
(44997, 0, 3704, 1, 1, 0),
(45002, 0, 33982, 1, 1, 0),
(45003, 0, 11686, 1, 1, 0),
(45041, 0, 29252, 1, 1, 0),
(45051, 0, 28213, 1, 1, 0),
(45057, 0, 29257, 1, 1, 0),
(4174951, 0, 11686, 1, 1, 0),
(4174952, 0, 11686, 1, 1, 0);

DELETE FROM `creature_template_movement` WHERE `CreatureId` = 44951;
INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`) VALUES
(44951, 2, 1, 1, 0, 0, 0);

DELETE FROM `creature_template_addon` WHERE `entry` = 44951;
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`) VALUES
(44951, 0, 0, 50331648, 0, 0, 0, '');

DELETE FROM `creature_text` WHERE `CreatureID` IN (44951, 44989, 44996, 45051);
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(44951, 0, 0, 'The warmth of this place sickens me.', 12, 0, 100, 0, 0, 0, 0, 0, 'Agatha - idle'),
(44951, 0, 1, 'Different master, same insatiable thirst for power.', 12, 0, 100, 0, 0, 0, 0, 0, 'Agatha - idle'),
(44951, 0, 2, 'Life is meaningless. It is in the afterlife that we are truly tested.', 12, 0, 100, 0, 0, 0, 0, 0, 'Agatha - idle'),
(44951, 0, 3, 'Waste no time, $n. We mustn''t keep the Banshee Queen waiting.', 12, 0, 100, 0, 0, 0, 0, 0, 'Agatha - idle'),
(44951, 0, 4, 'I sense doom in your future, $n.', 12, 0, 100, 0, 0, 0, 0, 0, 'Agatha - idle'),
(44951, 0, 5, 'I long for the frozen wastes of Northrend.', 12, 0, 100, 0, 0, 0, 0, 0, 'Agatha - idle'),
(44951, 0, 6, 'Through me the Banshee Queen sees all...', 12, 0, 100, 0, 0, 0, 0, 0, 'Agatha - idle'),
(44951, 0, 7, 'Do you feel it, $n? The darkness surrounds us.', 12, 0, 100, 0, 0, 0, 0, 0, 'Agatha - idle'),
(44951, 1, 0, 'This way, $n. We will take them by surprise.', 12, 0, 100, 0, 0, 0, 0, 0, 'Agatha - No Escape, to Fenris Keep'),
(44951, 2, 0, 'Run...!', 12, 0, 100, 0, 0, 0, 0, 0, 'Agatha - No Escape, Crowley is done'),
(44951, 3, 0, 'RUN!', 12, 0, 100, 0, 0, 0, 0, 0, 'Agatha - No Escape, carrying the player'),
(44989, 0, 0, 'The Forsaken have broken through your defenses, magistrate.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Darius Crowley - No Escape'),
(44989, 1, 0, 'You are out of time.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Darius Crowley - No Escape'),
(44989, 2, 0, 'A decision must be made.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Darius Crowley - No Escape'),
(44989, 3, 0, 'Die in battle and be raised as a servant of the Forsaken or...', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Darius Crowley - No Escape'),
(44989, 4, 0, 'Drink my blood and be reborn as worgen, immune to the depravity of the Forsaken.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Darius Crowley - No Escape'),
(44989, 5, 0, 'Help us destroy the Forsaken and retake Lordaeron for the Alliance!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Darius Crowley - No Escape'),
(44996, 0, 0, 'We would rather die than be turned into worgen, but seeing as how even death provides no relief from the atrocities of this war...', 12, 0, 100, 0, 0, 0, 0, 0, 'Magistrate Henry Maleb - No Escape'),
(44996, 1, 0, 'We choose vengeance!', 12, 0, 100, 0, 0, 0, 0, 0, 'Magistrate Henry Maleb - No Escape'),
(45051, 0, 0, 'I have not always been the Banshee Queen, $N.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 1, 0, 'And my people have not always been the Forsaken.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 2, 0, 'Long ago this land comprised the northern kingdoms of Lordaeron, ruled by King Terenas Menethil.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 3, 0, 'Terenas had a son named Arthas.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 4, 0, 'Arthas... even saying his name makes my body quiver in rage.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 5, 0, 'This man-child, Arthas, took for himself a cursed blade known as Frostmourne.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 6, 0, 'Through Frostmourne, Arthas killed his own father and razed this land along with every living creature in it!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 7, 0, 'My own death came at the hands of Arthas when he and his armies sacked my homeland, Quel''Thalas, and murdered my people.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 8, 0, 'In his vast cruelty, Arthas severed my spirit from my body and raised me as a banshee to serve in his Scourge army.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 9, 0, 'A similar fate befell all that would die to the Scourge war machine.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 10, 0, 'In death, they were reborn as mindless undead.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 11, 0, 'But Arthas was not invincible! With each passing day his power waned - his grip over the will of the damned loosening.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 12, 0, 'It was when Arthas was at his weakest that I struck!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 13, 0, 'And though the hour of his atonement had come, the worm managed to escape his fate, returning to the frozen wastes of Northrend.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 14, 0, 'With Arthas gone, so too was the control he held over the undead masses of Lordaeron. After recovering my body, I freed the remaining Scourge that were left behind.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 15, 0, 'From the cruelty and mercilessness of Arthas, the man who would be the Lich King, the Forsaken were born.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 16, 0, 'Our goal... Our sole purpose was to destroy the Lich King. We threw our lot in with the Horde and began our journey towards redemption.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 17, 0, 'Now the Lich King is dead and we have returned.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 18, 0, 'The people who called this land their home in life, do so in death as well.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 19, 0, 'But the Alliance does not recognize our rights. They claim this land as their own while attempting to invalidate the claims of the founders of this kingdom.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 20, 0, 'I will never allow it... Never!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron'),
(45051, 21, 0, 'Lordaeron belongs to the Forsaken - always and forever.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Lordaeron');

-- SummonProperties 3030 is added by rev_1794231896144905400.sql with the other Cata summon rows
-- (Flags masked to the 3.3.5 bits, 0x0F0A).

DELETE FROM `creature` WHERE `id` IN (4174951, 4174952) AND `guid` BETWEEN 16121951 AND 16121956;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `MovementType`, `Comment`) VALUES
(16121951, 4174951, 751, 4935, 4935, 1, 1, 745.275, 694.065, 43.0247, 6.01931, 300, 0, 0, 'Silverpine 751 - Agatha resummon bunny (nelt 14538)'),
(16121952, 4174951, 751, 4935, 4935, 1, 1, 998.835, 694.172, 69.7969, 6.24422, 300, 0, 0, 'Silverpine 751 - Agatha resummon bunny (nelt 14539)'),
(16121953, 4174951, 751, 4935, 4935, 1, 1, 1366.35, 1029.82, 52.8171, 0.76892, 300, 0, 0, 'Silverpine 751 - Agatha resummon bunny (nelt 14531)'),
(16121954, 4174951, 751, 4935, 4935, 1, 1, 915.223, 689.471, 65.2338, 3.18009, 300, 0, 0, 'Silverpine 751 - Agatha resummon bunny (nelt 14537)'),
(16121955, 4174951, 751, 4935, 4935, 1, 1, 1065.53, 711.366, 51.0095, 2.79132, 300, 0, 0, 'Silverpine 751 - Agatha resummon bunny (nelt 14530)'),
(16121956, 4174952, 751, 4935, 4935, 1, 1, 978.631, 689.145, 74.8986, 0.0862095, 300, 0, 0, 'Silverpine 751 - No Escape cutscene controller (nelt 14532)');
