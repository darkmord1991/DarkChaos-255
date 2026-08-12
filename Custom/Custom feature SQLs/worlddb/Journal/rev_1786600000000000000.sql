-- DC custom dungeon/raid encounters: per-difficulty rows + final-boss fix.
--
-- The 30 existing custom rows sat on DungeonEncounter Difficulty = -1, which
-- ObjectMgr::LoadInstanceEncounters files under an unreachable store key, so no
-- custom boss ever credited an encounter. DungeonEncounter.dbc now carries one
-- row per (map, difficulty) sharing the Bit, matching Blizzard's convention;
-- these are the matching credit rows.
--
-- lastEncounterDungeon is 0 throughout: 819/823/824 were MAP ids, not
-- LFGDungeons.dbc ids, and the core dropped those three rows outright
-- ("marked as final for invalid dungeon id" in Errors.log). Custom dungeons
-- have no LFGDungeons entries, so there is no valid value to point at.

-- Clear the final-boss markers that the core was rejecting at load.
UPDATE `instance_encounters` SET `lastEncounterDungeon` = 0 WHERE `entry` IN (1106, 1114, 1121);

-- Map 669 - difficulty 1 (25N)
DELETE FROM `instance_encounters` WHERE `entry` IN (1200, 1201, 1202, 1203, 1204, 1205);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1200, 0, 41442, 0, 'Atramedes (25N)'),
(1201, 0, 43296, 0, 'Chimaeron (25N)'),
(1202, 0, 41570, 0, 'Magmaw (25N)'),
(1203, 0, 41378, 0, 'Maloriak (25N)'),
(1204, 0, 41376, 0, 'Nefarian''s End (25N)'),
(1205, 0, 42180, 0, 'Omnotron Defense System (25N)');

-- Map 669 - difficulty 2 (10H)
DELETE FROM `instance_encounters` WHERE `entry` IN (1206, 1207, 1208, 1209, 1210, 1211);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1206, 0, 41442, 0, 'Atramedes (10H)'),
(1207, 0, 43296, 0, 'Chimaeron (10H)'),
(1208, 0, 41570, 0, 'Magmaw (10H)'),
(1209, 0, 41378, 0, 'Maloriak (10H)'),
(1210, 0, 41376, 0, 'Nefarian''s End (10H)'),
(1211, 0, 42180, 0, 'Omnotron Defense System (10H)');

-- Map 669 - difficulty 3 (25H)
DELETE FROM `instance_encounters` WHERE `entry` IN (1212, 1213, 1214, 1215, 1216, 1217);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1212, 0, 41442, 0, 'Atramedes (25H)'),
(1213, 0, 43296, 0, 'Chimaeron (25H)'),
(1214, 0, 41570, 0, 'Magmaw (25H)'),
(1215, 0, 41378, 0, 'Maloriak (25H)'),
(1216, 0, 41376, 0, 'Nefarian''s End (25H)'),
(1217, 0, 42180, 0, 'Omnotron Defense System (25H)');

-- Map 819 - difficulty 1 (Heroic)
DELETE FROM `instance_encounters` WHERE `entry` IN (1218, 1219, 1220, 1221, 1222, 1223, 1224);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1218, 0, 4010001, 0, 'Gatewarden Mor''thak (Heroic)'),
(1219, 0, 4010002, 0, 'The Sundered Chieftain (Heroic)'),
(1220, 0, 4010003, 0, 'Den Mother Ursara (Heroic)'),
(1221, 0, 4010004, 0, 'Xanthir the Defiler (Heroic)'),
(1222, 0, 4010005, 0, 'The Nightmare Given Root (Heroic)'),
(1223, 0, 4010006, 0, 'Ursol (Heroic)'),
(1224, 0, 4010007, 0, 'Ursoc (Heroic)');

-- Map 819 - difficulty 2 (Mythic)
DELETE FROM `instance_encounters` WHERE `entry` IN (1225, 1226, 1227, 1228, 1229, 1230, 1231);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1225, 0, 4010001, 0, 'Gatewarden Mor''thak (Mythic)'),
(1226, 0, 4010002, 0, 'The Sundered Chieftain (Mythic)'),
(1227, 0, 4010003, 0, 'Den Mother Ursara (Mythic)'),
(1228, 0, 4010004, 0, 'Xanthir the Defiler (Mythic)'),
(1229, 0, 4010005, 0, 'The Nightmare Given Root (Mythic)'),
(1230, 0, 4010006, 0, 'Ursol (Mythic)'),
(1231, 0, 4010007, 0, 'Ursoc (Mythic)');

-- Map 823 - difficulty 1 (Heroic)
DELETE FROM `instance_encounters` WHERE `entry` IN (1232, 1233, 1234, 1235, 1236);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1232, 0, 4020001, 0, 'Keeper Ranathos (Heroic)'),
(1233, 0, 4020002, 0, 'Grovetender Engryss (+ both elders) (Heroic)'),
(1234, 0, 4020005, 0, 'High Priestess A''lathea (Heroic)'),
(1235, 0, 4020006, 0, 'Fenektis the Deceiver (Heroic)'),
(1236, 0, 4020007, 0, 'Master Raxxieth (Heroic)');

-- Map 823 - difficulty 2 (Mythic)
DELETE FROM `instance_encounters` WHERE `entry` IN (1237, 1238, 1239, 1240, 1241);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1237, 0, 4020001, 0, 'Keeper Ranathos (Mythic)'),
(1238, 0, 4020002, 0, 'Grovetender Engryss (+ both elders) (Mythic)'),
(1239, 0, 4020005, 0, 'High Priestess A''lathea (Mythic)'),
(1240, 0, 4020006, 0, 'Fenektis the Deceiver (Mythic)'),
(1241, 0, 4020007, 0, 'Master Raxxieth (Mythic)');

-- Map 824 - difficulty 1 (Heroic)
DELETE FROM `instance_encounters` WHERE `entry` IN (1242, 1243);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1242, 0, 4030001, 0, 'Erennius (Heroic)'),
(1243, 0, 4030002, 0, 'The Wakener (Heroic)');

-- Map 824 - difficulty 2 (Mythic)
DELETE FROM `instance_encounters` WHERE `entry` IN (1244, 1245);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1244, 0, 4030001, 0, 'Erennius (Mythic)'),
(1245, 0, 4030002, 0, 'The Wakener (Mythic)');

-- Map 2296 - difficulty 1 (25N)
DELETE FROM `instance_encounters` WHERE `entry` IN (1246, 1247, 1248, 1249, 1250, 1251, 1252, 1253, 1254, 1255);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1246, 0, 164406, 0, 'Shriekwing (25N)'),
(1247, 0, 165066, 0, 'Huntsman Altimor (25N)'),
(1248, 0, 164261, 0, 'Hungering Destroyer (25N)'),
(1249, 0, 165759, 0, 'Sun King''s Salvation (25N)'),
(1250, 0, 166644, 0, 'Artificer Xy''mox (25N)'),
(1251, 0, 165521, 0, 'Lady Inerva Darkvein (25N)'),
(1252, 0, 166969, 0, 'Council of Blood (25N)'),
(1253, 0, 164407, 0, 'Sludgefist (25N)'),
(1254, 0, 168112, 0, 'Stone Legion Generals (25N)'),
(1255, 0, 167406, 0, 'Sire Denathrius (25N)');

-- Map 2296 - difficulty 2 (10H)
DELETE FROM `instance_encounters` WHERE `entry` IN (1256, 1257, 1258, 1259, 1260, 1261, 1262, 1263, 1264, 1265);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1256, 0, 164406, 0, 'Shriekwing (10H)'),
(1257, 0, 165066, 0, 'Huntsman Altimor (10H)'),
(1258, 0, 164261, 0, 'Hungering Destroyer (10H)'),
(1259, 0, 165759, 0, 'Sun King''s Salvation (10H)'),
(1260, 0, 166644, 0, 'Artificer Xy''mox (10H)'),
(1261, 0, 165521, 0, 'Lady Inerva Darkvein (10H)'),
(1262, 0, 166969, 0, 'Council of Blood (10H)'),
(1263, 0, 164407, 0, 'Sludgefist (10H)'),
(1264, 0, 168112, 0, 'Stone Legion Generals (10H)'),
(1265, 0, 167406, 0, 'Sire Denathrius (10H)');

-- Map 2296 - difficulty 3 (25H)
DELETE FROM `instance_encounters` WHERE `entry` IN (1266, 1267, 1268, 1269, 1270, 1271, 1272, 1273, 1274, 1275);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1266, 0, 164406, 0, 'Shriekwing (25H)'),
(1267, 0, 165066, 0, 'Huntsman Altimor (25H)'),
(1268, 0, 164261, 0, 'Hungering Destroyer (25H)'),
(1269, 0, 165759, 0, 'Sun King''s Salvation (25H)'),
(1270, 0, 166644, 0, 'Artificer Xy''mox (25H)'),
(1271, 0, 165521, 0, 'Lady Inerva Darkvein (25H)'),
(1272, 0, 166969, 0, 'Council of Blood (25H)'),
(1273, 0, 164407, 0, 'Sludgefist (25H)'),
(1274, 0, 168112, 0, 'Stone Legion Generals (25H)'),
(1275, 0, 167406, 0, 'Sire Denathrius (25H)');

-- Map 820 Blackfathom Deeps (Ashenvale) - difficulty 0 (Normal)
DELETE FROM `instance_encounters` WHERE `entry` IN (1280, 1281, 1282, 1283, 1284, 1285);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1280, 0, 3904887, 0, 'Ghamoo-ra (Normal)'),
(1281, 0, 3904831, 0, 'Lady Sarevess (Normal)'),
(1282, 0, 3906243, 0, 'Gelihast (Normal)'),
(1283, 0, 3904830, 0, 'Old Serra''kis (Normal)'),
(1284, 0, 3904832, 0, 'Twilight Lord Kelris (Normal)'),
(1285, 0, 3904829, 0, 'Aku''mai (Normal)');

-- Map 820 Blackfathom Deeps (Ashenvale) - difficulty 1 (Heroic)
DELETE FROM `instance_encounters` WHERE `entry` IN (1286, 1287, 1288, 1289, 1290, 1291);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1286, 0, 3904887, 0, 'Ghamoo-ra (Heroic)'),
(1287, 0, 3904831, 0, 'Lady Sarevess (Heroic)'),
(1288, 0, 3906243, 0, 'Gelihast (Heroic)'),
(1289, 0, 3904830, 0, 'Old Serra''kis (Heroic)'),
(1290, 0, 3904832, 0, 'Twilight Lord Kelris (Heroic)'),
(1291, 0, 3904829, 0, 'Aku''mai (Heroic)');

-- Map 820 Blackfathom Deeps (Ashenvale) - difficulty 2 (Mythic)
DELETE FROM `instance_encounters` WHERE `entry` IN (1292, 1293, 1294, 1295, 1296, 1297);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1292, 0, 3904887, 0, 'Ghamoo-ra (Mythic)'),
(1293, 0, 3904831, 0, 'Lady Sarevess (Mythic)'),
(1294, 0, 3906243, 0, 'Gelihast (Mythic)'),
(1295, 0, 3904830, 0, 'Old Serra''kis (Mythic)'),
(1296, 0, 3904832, 0, 'Twilight Lord Kelris (Mythic)'),
(1297, 0, 3904829, 0, 'Aku''mai (Mythic)');
