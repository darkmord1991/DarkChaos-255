-- DarkChaos: map 751 Alliance phase 1 - why bots almost never finished seven of its quests, and the data fixes
--
-- Source: the bot run of 2026-11-13 07:51-09:53 (playerbots_quest_stats.json) and the live acore_world.
-- How a bot works a quest objective: it walks to a random point inside a quest_poi polygon of that objective (or,
-- when no polygon of it lies in the bot's zone, to the five nearest spawns of the target), stays there five minutes
-- moving about 8 yards, and gives up ("no_progress") if the objective still has no count by then. From that point it
-- attacks targets up to 100 yards away, but only those at most 5 yards higher or lower, and it loots objects only
-- within 15 yards and 3 yards of height. A polygon point takes its height from the terrain surface, so a point over a
-- cave puts the bot on the hill above it.
--
-- 1. 751034 Too Close for Comfort (32 taken, 1 done, 10 no_progress). 12 of the 18 Cave Yetis and all 16 Ferocious
--    Yetis stand in a cave 40 to 128 yards below the terrain that the two objective polygons cover; from 99-100% of
--    the points in them no yeti is in reach. Players can walk into the cave, so the quest works for them. The two
--    objective polygons are removed, so bots go to the yetis' own spawn points instead. The turn-in marker stays.
-- 2. 751005 Wolfsbane (26 taken, 1 done). The 17 Wolfsbane plants (gameobject 4805367, a chest that gives item 60958
--    at 100% for the quest) lie in one 400 x 245 yard polygon on hilly ground; from 60% of its points no plant is in
--    loot reach. 751008 Intercepted Orders uses the same kind of object with a 50-yard square, and bots finish it.
--    The polygon is replaced by two small ones over the two patches of four plants; every point of them has 3 or 4
--    plants in reach. For players only the map marker changes.
-- 3. 200505 Syndicate Assassins (27 taken, 0 done, 6 no_progress). The Argus Shadow Mage polygon covers 570 x 470
--    yards of hills for 14 mages standing in five small groups; from 87% of its points no mage is in reach. It is
--    replaced by five small polygons over the groups (13 mages; the 14th stands just north of Strahnbrad).
-- 4. 205542 Demon Dogs (15 taken, 0 done). The clone still asks for the stock map-0 entries 8596-8598. On 751 only the
--    level-158 copies 3608596-3608598 spawn, and they credit those through KillCredit1. Players get the credit, but a
--    bot only goes after a target outside aggro range when the quest names that creature's own entry, so it killed
--    only hounds that attacked it. The objectives now name the 751 entries; a kill also credits the creature's own
--    entry, so nothing changes for players. Two polygons copied from the stock quest (ids 1 and 5) lie where 751 has
--    1 and 2 of their targets; they are removed.
-- 5. Respawn of small target groups. 26-34 bots took each Stormpike and Ambermill quest within minutes of each other.
--    The Gilneas quests of this set, whose targets respawn after 2 minutes, were finished by 77-90% of the bots that
--    took them. The groups below respawn after 5 minutes and give fewer kills per hour than the bots holding the
--    quest need:
--      Syndicate Wizard 4102319 x8 and Argus Shadow Mage 4102318 x14 (200505),
--      Cave Yeti 4102248 x18 and Ferocious Yeti 4148628 x16 (751034),
--      Torn Fin Tidehunter 4102377 x24 and Torn Fin Oracle 4102376 x22 (200536 Down the Coast: 34 taken, 3 done),
--      Vile Fin Oracle 4146573 x8 and Vile Fin Tidehunter 4146574 x9 at Lordamere Lake (751027 Lordamere Vile Fins:
--      26 taken, 2 done; 8 scales at 40%).
--    They now respawn after 2 minutes, like the Gilneas targets. Players on a busy server benefit as well.
--
-- NOT changed: 751018 The Blackhowl Pack (26 taken, 0 done). 19 of the 22 Blackhowl Bloodhounds stand within 30 yards
-- of 3 to 20 elite Blackhowl Footsoldiers, Snipers or Packmasters (249 elites in Gilneas City), so this solo quest is
-- an elite fight for players too. Whether it becomes a group quest like 751020/751021 or some hounds move to the edge
-- of the city is a design decision.
--
-- Re-running changes nothing: every UPDATE is guarded by the values it replaces, and the markers are deleted and
-- re-inserted by key.
-- Revert: spawntimesecs back to 300 on the 119 spawns below; RequiredNpcOrGo1-3 of 205542 back to 8596, 8597, 8598;
-- the removed polygons from rev_1794433543678762600.sql (751005, 751034, 200505) and from quest 5542 (205542 ids 1
-- and 5).
-- Apply to acore_world, then restart the worldserver.

-- 1. 751034: the objective markers over the cave go; the turn-in marker (id 2) stays
DELETE FROM `quest_poi_points` WHERE `QuestID` = 751034 AND `Idx1` IN (0, 1);
DELETE FROM `quest_poi` WHERE `QuestID` = 751034 AND `id` IN (0, 1);

-- 2. 751005: two small markers over the Wolfsbane patches (item objective = index 4); the turn-in marker (id 1)
-- stays
DELETE FROM `quest_poi` WHERE `QuestID` = 751005 AND `id` IN (0, 2);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`) VALUES
(751005, 0, 4, 751, 1274, 0, 0, 1, 0),
(751005, 2, 4, 751, 1274, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 751005 AND `Idx1` IN (0, 2);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(751005, 0, 0, -1193, 1557, 0),
(751005, 0, 1, -1202, 1578, 0),
(751005, 0, 2, -1224, 1587, 0),
(751005, 0, 3, -1245, 1578, 0),
(751005, 0, 4, -1254, 1557, 0),
(751005, 0, 5, -1245, 1535, 0),
(751005, 0, 6, -1224, 1526, 0),
(751005, 0, 7, -1202, 1535, 0),
(751005, 2, 0, -1091, 1576, 0),
(751005, 2, 1, -1098, 1595, 0),
(751005, 2, 2, -1117, 1602, 0),
(751005, 2, 3, -1135, 1595, 0),
(751005, 2, 4, -1143, 1576, 0),
(751005, 2, 5, -1135, 1558, 0),
(751005, 2, 6, -1117, 1550, 0),
(751005, 2, 7, -1098, 1558, 0);

-- 3. 200505: the Argus Shadow Mage marker (id 1) becomes five small ones (ids 1, 3-6); the wizard marker (id 0)
-- and the turn-in marker (id 2) stay
DELETE FROM `quest_poi` WHERE `QuestID` = 200505 AND `id` IN (1, 3, 4, 5, 6);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`) VALUES
(200505, 1, 1, 751, 1271, 0, 0, 1, 0),
(200505, 3, 1, 751, 1271, 0, 0, 1, 0),
(200505, 4, 1, 751, 1271, 0, 0, 1, 0),
(200505, 5, 1, 751, 1271, 0, 0, 1, 0),
(200505, 6, 1, 751, 1271, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 200505 AND `Idx1` IN (1, 3, 4, 5, 6);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(200505, 1, 0, 754, -949, 0),
(200505, 1, 1, 735, -902, 0),
(200505, 1, 2, 687, -883, 0),
(200505, 1, 3, 640, -902, 0),
(200505, 1, 4, 621, -949, 0),
(200505, 1, 5, 640, -996, 0),
(200505, 1, 6, 687, -1016, 0),
(200505, 1, 7, 735, -996, 0),
(200505, 3, 0, 966, -845, 0),
(200505, 3, 1, 958, -827, 0),
(200505, 3, 2, 941, -820, 0),
(200505, 3, 3, 923, -827, 0),
(200505, 3, 4, 916, -845, 0),
(200505, 3, 5, 923, -863, 0),
(200505, 3, 6, 941, -870, 0),
(200505, 3, 7, 958, -863, 0),
(200505, 4, 0, 1023, -789, 0),
(200505, 4, 1, 1016, -771, 0),
(200505, 4, 2, 998, -764, 0),
(200505, 4, 3, 980, -771, 0),
(200505, 4, 4, 973, -789, 0),
(200505, 4, 5, 980, -806, 0),
(200505, 4, 6, 998, -814, 0),
(200505, 4, 7, 1016, -806, 0),
(200505, 5, 0, 1138, -717, 0),
(200505, 5, 1, 1130, -699, 0),
(200505, 5, 2, 1113, -692, 0),
(200505, 5, 3, 1095, -699, 0),
(200505, 5, 4, 1088, -717, 0),
(200505, 5, 5, 1095, -734, 0),
(200505, 5, 6, 1113, -742, 0),
(200505, 5, 7, 1130, -734, 0),
(200505, 6, 0, 1204, -555, 0),
(200505, 6, 1, 1196, -537, 0),
(200505, 6, 2, 1179, -530, 0),
(200505, 6, 3, 1161, -537, 0),
(200505, 6, 4, 1154, -555, 0),
(200505, 6, 5, 1161, -573, 0),
(200505, 6, 6, 1179, -580, 0),
(200505, 6, 7, 1196, -573, 0);

-- 4. 205542: the objectives name the 751 hounds; the two stock-copied markers without 751 targets (ids 1, 5) go
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3608596, `RequiredNpcOrGo2` = 3608597,
    `RequiredNpcOrGo3` = 3608598
WHERE `ID` = 205542 AND `RequiredNpcOrGo1` = 8596 AND `RequiredNpcOrGo2` = 8597 AND `RequiredNpcOrGo3` = 8598;
DELETE FROM `quest_poi_points` WHERE `QuestID` = 205542 AND `Idx1` IN (1, 5);
DELETE FROM `quest_poi` WHERE `QuestID` = 205542 AND `id` IN (1, 5);

-- 5. Respawn 300 -> 120 seconds for the small target groups of 200505, 751034, 200536 and 751027
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102319 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16717263, 16717265, 16717266, 16717268,
    16717272, 16717273, 16717276, 16717277);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102318 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16717259, 16717264, 16717271, 16717275,
    16717572, 16717839, 16717840, 16718229, 16718230, 16718231, 16718236, 16718237, 16718434, 16718435);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102248 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16717021, 16717023, 16717032, 16717033,
    16717037, 16717038, 16717039, 16717041, 16717042, 16717091, 16717095, 16717215, 16717226, 16717228, 16717229,
    16717234, 16717237, 16717239);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4148628 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16717024, 16717025, 16717040, 16717094,
    16717096, 16717232, 16717233, 16717235, 16717236, 16717238, 16717240, 16717241, 16717242, 16717243, 16717283,
    16717307);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102377 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16716378, 16716474, 16716478, 16716480,
    16716481, 16716483, 16716484, 16716488, 16716762, 16716763, 16716766, 16716768, 16716770, 16716772, 16716774,
    16716775, 16716854, 16716855, 16716860, 16716861, 16716863, 16716864, 16716866, 16716947);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102376 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16716475, 16716476, 16716477, 16716479,
    16716482, 16716485, 16716486, 16716487, 16716761, 16716765, 16716767, 16716769, 16716771, 16716773, 16716853,
    16716857, 16716858, 16716859, 16716865, 16716867, 16716869, 16716946);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4146573 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16714952, 16714955, 16714956, 16714957,
    16715030, 16715032, 16715034, 16715035);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4146574 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16714953, 16714954, 16714958, 16714960,
    16714961, 16715026, 16715027, 16715029, 16715033);

-- Verify after apply (expected values in brackets):
--   SELECT `QuestID`, COUNT(*) FROM `quest_poi` WHERE `QuestID` IN (751005, 751034, 200505, 205542)
--     GROUP BY `QuestID`                                         [751005: 3, 751034: 1, 200505: 7, 205542: 5]
--   SELECT `QuestID`, COUNT(*) FROM `quest_poi_points` WHERE `QuestID` IN (751005, 751034, 200505, 205542)
--     GROUP BY `QuestID`                                     [751005: 17, 751034: 1, 200505: 49, 205542: 42]
--   SELECT `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3` FROM `quest_template` WHERE `ID` = 205542
--                                                                                  [3608596 3608597 3608598]
--   SELECT COUNT(*) FROM `creature` WHERE `map` = 751 AND `spawntimesecs` = 120 AND `id` IN (4102319, 4102318,
--     4102248, 4148628, 4102377, 4102376, 4146573, 4146574)                                             [119]
