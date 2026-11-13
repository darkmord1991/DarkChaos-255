-- DarkChaos: map 751 Alliance route, phase 2, block 5 of 5: Gilneas City group quest and dailies
--
-- Phase-2 set, apply in this order: rev_1794566930352012600 (Gilneas west/south), rev_1794566930499515200
--   (Tirisfal), rev_1794566930637186200 (Silverpine), rev_1794566930778776100 (Hillsbrad), rev_1794566930955974800
--   (group quests and dailies). Each file needs only phase 1 and the drop ladder; the five do not depend on each
--   other.
--
-- Quests (QuestLevel -1; MinLevel = zone band low - 2, or the band low where the targets stand 4-5 levels
-- above it; every target is a mob already spawned on 751):
--   751066 The Blackhowl Packmasters [group of 3, MinLevel 131, XP difficulty 8]: 5x Blackhowl Packmaster (4157806)
--   751067 Daily: Holding the Ridge [daily, MinLevel 128, XP difficulty 4]: 15x Forsaken Vanguard (4145280)
--   751068 Daily: Wolfsbane for the Front [daily, MinLevel 128, XP difficulty 4]: 8x Wolfsbane (60958)
--   751069 Daily: Yetis at the Door [daily, MinLevel 136, XP difficulty 4]: 6x Cave Yeti (4102248); 6x Ferocious
--     Yeti (4148628)
--   751070 Daily: Crushridge Raiders [daily, MinLevel 138, XP difficulty 4]: 10x Crushridge Ogre (4102252)
--   751071 Daily: The Streets of Gilneas [group of 3, daily, MinLevel 131, XP difficulty 6]: 12x Blackhowl
--     Footsoldier (4157805)
-- Objective markers are small octagons over the target groups on open ground (none over caves); each was checked
-- against the terrain heightmap: from every point of it at least one target stands within 100 yd and 5 yd of
-- height, as a playerbot needs.
-- Group quests (QuestInfoID 1, SuggestedGroupNum 3) and dailies (Flags 4096 + SpecialFlags 1) are player content:
--   playerbots never take a group quest or a repeatable one.
-- IDS: quests 751066-751071 (verified free).
-- DEPENDS ON: phase 1 (Zazzo 830315, Lord Darius Crowley 830302, Krennan Aranas 830303, Stonebrow 830321, Redpath
--   830323); the drop ladder rev_1794428606734586200 for gear rewards.
-- REVERT: quests 751066-751071 with their addon/texts/starters/enders/POIs.
-- Re-runnable: quest_template is REPLACEd, every INSERT is preceded by a DELETE of exactly its keys, and every
-- UPDATE is guarded by the value it replaces. Apply to acore_world, then restart the worldserver.

-- 1. quests 751066-751071 (REPLACE: template rows are never deleted)
REPLACE INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`, `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`, `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`) VALUES
(751066, 2, -1, 131, 4939, 1, 3, 8, 239400, 8, 421221, 421229, 421237, 421245, 0, 0, 1, 1, 1, 1, 0, 0, 751, -1597.4, 1378.6, 72, 6, 910163021, 'The Blackhowl Packmasters', 'Slay 5 Blackhowl Packmasters in Gilneas City.', 'Every Blackhowl war band runs behind a packmaster - the biggest, cruellest wolf of the lot, with a pack of hounds and mercenaries at his heels. Kill the packmasters and the bands fall apart.$B$BFive of them hold the streets around the cathedral and the market. You will want company, $N. A great deal of it.', '', 'Return to Zazzo Twinklefingers at the north-eastern edge of Gilneas City.', 4157806, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751067, 2, -1, 128, 4939, 0, 0, 4, 89775, 4104, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, -911.2, 1628.2, 72, 5, 910163021, 'Daily: Holding the Ridge', 'Lord Darius Crowley wants you to slay 15 Forsaken Vanguards on the ridge west of the camp.', 'Every morning the Forsaken send fresh soldiers up the ridge, and every morning we throw them back down. That is the war here, $N - not glory, just the ridge, again and again.$B$BHelp us hold it today. Fifteen of their vanguard.', '', 'Return to Lord Darius Crowley at the 7th Legion Base Camp in Silverpine Forest.', 4145280, 0, 0, 0, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751068, 2, -1, 128, 4939, 0, 0, 4, 89775, 4104, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, -1170.2, 1566.4, 72, 5, 910163021, 'Daily: Wolfsbane for the Front', 'Krennan Aranas wants 8 Wolfsbane from the Northern Headlands of the Ruins of Gilneas.', 'The draught does not keep, $N. Every worgen on the Front needs a fresh dose every few days, and there are more of us every week.$B$BEight bundles of wolfsbane from the Headlands, today and every day you can spare.', '', 'Return to Krennan Aranas at the 7th Legion Base Camp in Silverpine Forest.', 0, 0, 0, 0, 0, 0, 0, 0, 60958, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751069, 2, -1, 136, 4936, 0, 0, 4, 95175, 4104, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, -226, -365, 730, 5, 910163021, 'Daily: Yetis at the Door', 'Slay 6 Cave Yetis and 6 Ferocious Yetis in the caves west of the Stormpike Encampment.', 'The cave west of camp never stays empty for long. Every night more yetis come down from the deep tunnels, and every morning someone has to go in and send them back.$B$BToday that someone is you, $N. Six cave yetis and six of the ferocious ones.', '', 'Return to Commander Brannoc Stonebrow at the Stormpike Encampment in Hillsbrad Foothills.', 4102248, 4148628, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751070, 2, -1, 138, 4936, 0, 0, 4, 95175, 4104, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, 564.8, -628.3, 730, 5, 910163021, 'Daily: Crushridge Raiders', 'Slay 10 Crushridge Ogres in the Ruins of Alterac.', 'The Crushridge send raiders down the hill every day to see whether we are still awake. Show them we are, $N.$B$BTen of their ogres, today.', '', 'Return to Marshal Redpath at the Stormpike Encampment in Hillsbrad Foothills.', 4102252, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751071, 2, -1, 131, 4939, 1, 3, 6, 149625, 4104, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, -1719.6, 1436.6, 72, 5, 910163021, 'Daily: The Streets of Gilneas', 'Slay 12 Blackhowl Footsoldiers in Gilneas City.', 'Creed may be gone, but his coin is not, and the Blackhowl keep holding the streets for whoever pays. Every day they walk the same routes, and every day we can make them pay for it.$B$BTake your friends into the city, $N, and cut down twelve footsoldiers.', '', 'Return to Zazzo Twinklefingers at the north-eastern edge of Gilneas City.', 4157805, 0, 0, 0, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0);

-- chains, breadcrumbs and daily flags
DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 751066 AND 751071;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`, `BreadcrumbForQuestId`, `SpecialFlags`) VALUES
(751066, 751019, 0, 0),
(751067, 751003, 0, 1),
(751068, 751005, 0, 1),
(751069, 751034, 0, 1),
(751070, 200500, 0, 1),
(751071, 751020, 0, 1);

-- texts
DELETE FROM `quest_offer_reward` WHERE `ID` BETWEEN 751066 AND 751071;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES
(751066, 1, 'Five packmasters. The Blackhowl are howling at each other now instead of at us. Lovely work.', 0),
(751067, 1, 'The ridge holds another day. Come back tomorrow - they certainly will.', 0),
(751068, 1, 'Enough for another day. Thank you, $N - truly.', 0),
(751069, 1, 'The cave is quiet again - until tonight. Thank you, $N.', 0),
(751070, 1, 'Good. Same again tomorrow, if you have the stomach for it.', 0),
(751071, 1, 'Another bad day for the Blackhowl. Same time tomorrow?', 0);
DELETE FROM `quest_request_items` WHERE `ID` BETWEEN 751066 AND 751071;
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`) VALUES
(751066, 6, 6, 'The packmasters still run the streets.', 0),
(751067, 6, 6, 'Does the ridge hold?', 0),
(751068, 6, 6, 'Have you brought the wolfsbane?', 0),
(751069, 6, 6, 'Is the cave quiet?', 0),
(751070, 6, 6, 'Have you been up the hill today?', 0),
(751071, 6, 6, 'The footsoldiers still hold the streets.', 0);

-- givers and enders
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 751066 AND 751071;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(830315, 751066),
(830302, 751067),
(830303, 751068),
(830321, 751069),
(830323, 751070),
(830315, 751071);
DELETE FROM `creature_questender` WHERE `quest` BETWEEN 751066 AND 751071;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(830315, 751066),
(830302, 751067),
(830303, 751068),
(830321, 751069),
(830323, 751070),
(830315, 751071);

-- quest map markers: small octagons over the target groups that stand on open ground (none over a mine or
-- cave, so bots use the spawn points there), and the turn-in point
DELETE FROM `quest_poi` WHERE `QuestID` BETWEEN 751066 AND 751071;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(751066, 0, 0, 751, 1274, 0, 0, 1, 0),
(751066, 1, 0, 751, 1274, 0, 0, 1, 0),
(751066, 2, 0, 751, 1274, 0, 0, 1, 0),
(751066, 3, 0, 751, 1274, 0, 0, 1, 0),
(751066, 4, -1, 751, 1274, 0, 0, 1, 0),
(751067, 0, 0, 751, 1274, 0, 0, 1, 0),
(751067, 1, 0, 751, 1274, 0, 0, 1, 0),
(751067, 2, 0, 751, 1274, 0, 0, 1, 0),
(751067, 3, 0, 751, 1274, 0, 0, 1, 0),
(751067, 4, -1, 751, 1270, 0, 0, 1, 0),
(751068, 0, 4, 751, 1274, 0, 0, 1, 0),
(751068, 1, 4, 751, 1274, 0, 0, 1, 0),
(751068, 2, -1, 751, 1270, 0, 0, 1, 0),
(751069, 0, -1, 751, 1271, 0, 0, 1, 0),
(751070, 0, 0, 751, 1271, 0, 0, 1, 0),
(751070, 1, 0, 751, 1271, 0, 0, 1, 0),
(751070, 2, 0, 751, 1271, 0, 0, 1, 0),
(751070, 3, -1, 751, 1271, 0, 0, 1, 0),
(751071, 0, 0, 751, 1274, 0, 0, 1, 0),
(751071, 1, 0, 751, 1274, 0, 0, 1, 0),
(751071, 2, -1, 751, 1274, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` BETWEEN 751066 AND 751071;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(751066, 0, 0, -1724, 1380, 0),
(751066, 0, 1, -1731, 1398, 0),
(751066, 0, 2, -1749, 1405, 0),
(751066, 0, 3, -1766, 1398, 0),
(751066, 0, 4, -1773, 1380, 0),
(751066, 0, 5, -1766, 1363, 0),
(751066, 0, 6, -1749, 1356, 0),
(751066, 0, 7, -1731, 1363, 0),
(751066, 1, 0, -1479, 1405, 0),
(751066, 1, 1, -1490, 1432, 0),
(751066, 1, 2, -1516, 1443, 0),
(751066, 1, 3, -1543, 1432, 0),
(751066, 1, 4, -1554, 1405, 0),
(751066, 1, 5, -1543, 1378, 0),
(751066, 1, 6, -1516, 1367, 0),
(751066, 1, 7, -1490, 1378, 0),
(751066, 2, 0, -1447, 1409, 0),
(751066, 2, 1, -1452, 1422, 0),
(751066, 2, 2, -1464, 1427, 0),
(751066, 2, 3, -1477, 1422, 0),
(751066, 2, 4, -1482, 1409, 0),
(751066, 2, 5, -1477, 1397, 0),
(751066, 2, 6, -1464, 1392, 0),
(751066, 2, 7, -1452, 1397, 0),
(751066, 3, 0, -1633, 1320, 0),
(751066, 3, 1, -1641, 1339, 0),
(751066, 3, 2, -1660, 1347, 0),
(751066, 3, 3, -1680, 1339, 0),
(751066, 3, 4, -1688, 1320, 0),
(751066, 3, 5, -1680, 1300, 0),
(751066, 3, 6, -1660, 1292, 0),
(751066, 3, 7, -1641, 1300, 0),
(751066, 4, 0, -1388, 1235, 0),
(751067, 0, 0, -792, 1712, 0),
(751067, 0, 1, -809, 1754, 0),
(751067, 0, 2, -852, 1772, 0),
(751067, 0, 3, -894, 1754, 0),
(751067, 0, 4, -912, 1712, 0),
(751067, 0, 5, -894, 1670, 0),
(751067, 0, 6, -852, 1652, 0),
(751067, 0, 7, -809, 1670, 0),
(751067, 1, 0, -775, 1552, 0),
(751067, 1, 1, -788, 1585, 0),
(751067, 1, 2, -821, 1599, 0),
(751067, 1, 3, -854, 1585, 0),
(751067, 1, 4, -868, 1552, 0),
(751067, 1, 5, -854, 1519, 0),
(751067, 1, 6, -821, 1506, 0),
(751067, 1, 7, -788, 1519, 0),
(751067, 2, 0, -931, 1721, 0),
(751067, 2, 1, -949, 1763, 0),
(751067, 2, 2, -991, 1781, 0),
(751067, 2, 3, -1034, 1763, 0),
(751067, 2, 4, -1051, 1721, 0),
(751067, 2, 5, -1034, 1678, 0),
(751067, 2, 6, -991, 1661, 0),
(751067, 2, 7, -949, 1678, 0),
(751067, 3, 0, -921, 1528, 0),
(751067, 3, 1, -938, 1570, 0),
(751067, 3, 2, -981, 1588, 0),
(751067, 3, 3, -1023, 1570, 0),
(751067, 3, 4, -1041, 1528, 0),
(751067, 3, 5, -1023, 1485, 0),
(751067, 3, 6, -981, 1468, 0),
(751067, 3, 7, -938, 1485, 0),
(751067, 4, 0, -676, 1716, 0),
(751068, 0, 0, -1091, 1576, 0),
(751068, 0, 1, -1098, 1595, 0),
(751068, 0, 2, -1117, 1602, 0),
(751068, 0, 3, -1135, 1595, 0),
(751068, 0, 4, -1143, 1576, 0),
(751068, 0, 5, -1135, 1558, 0),
(751068, 0, 6, -1117, 1550, 0),
(751068, 0, 7, -1098, 1558, 0),
(751068, 1, 0, -1193, 1557, 0),
(751068, 1, 1, -1202, 1578, 0),
(751068, 1, 2, -1224, 1587, 0),
(751068, 1, 3, -1245, 1578, 0),
(751068, 1, 4, -1254, 1557, 0),
(751068, 1, 5, -1245, 1535, 0),
(751068, 1, 6, -1224, 1526, 0),
(751068, 1, 7, -1202, 1535, 0),
(751068, 2, 0, -684, 1706, 0),
(751069, 0, 0, -12, -322, 0),
(751070, 0, 0, 922, -628, 0),
(751070, 0, 1, 905, -585, 0),
(751070, 0, 2, 862, -568, 0),
(751070, 0, 3, 820, -585, 0),
(751070, 0, 4, 802, -628, 0),
(751070, 0, 5, 820, -670, 0),
(751070, 0, 6, 862, -688, 0),
(751070, 0, 7, 905, -670, 0),
(751070, 1, 0, 529, -751, 0),
(751070, 1, 1, 518, -725, 0),
(751070, 1, 2, 492, -714, 0),
(751070, 1, 3, 466, -725, 0),
(751070, 1, 4, 456, -751, 0),
(751070, 1, 5, 466, -776, 0),
(751070, 1, 6, 492, -787, 0),
(751070, 1, 7, 518, -776, 0),
(751070, 2, 0, 398, -507, 0),
(751070, 2, 1, 381, -466, 0),
(751070, 2, 2, 340, -449, 0),
(751070, 2, 3, 299, -466, 0),
(751070, 2, 4, 283, -507, 0),
(751070, 2, 5, 299, -547, 0),
(751070, 2, 6, 340, -564, 0),
(751070, 2, 7, 381, -547, 0),
(751070, 3, 0, 8, -345, 0),
(751071, 0, 0, -1565, 1360, 0),
(751071, 0, 1, -1582, 1403, 0),
(751071, 0, 2, -1625, 1420, 0),
(751071, 0, 3, -1667, 1403, 0),
(751071, 0, 4, -1685, 1360, 0),
(751071, 0, 5, -1667, 1318, 0),
(751071, 0, 6, -1625, 1300, 0),
(751071, 0, 7, -1582, 1318, 0),
(751071, 1, 0, -1776, 1513, 0),
(751071, 1, 1, -1787, 1540, 0),
(751071, 1, 2, -1814, 1551, 0),
(751071, 1, 3, -1842, 1540, 0),
(751071, 1, 4, -1853, 1513, 0),
(751071, 1, 5, -1842, 1486, 0),
(751071, 1, 6, -1814, 1474, 0),
(751071, 1, 7, -1787, 1486, 0),
(751071, 2, 0, -1388, 1235, 0);

-- Verification, to run after applying (expected values in the labels):
--   SELECT 'quests (want 6)' AS `check`, COUNT(*) AS `n` FROM `quest_template` WHERE `ID` BETWEEN 751066 AND 751071
--   UNION ALL SELECT 'givers (want 6)', COUNT(*) FROM `creature_queststarter` WHERE `quest` BETWEEN 751066 AND 751071
--   UNION ALL SELECT 'enders (want 6)', COUNT(*) FROM `creature_questender` WHERE `quest` BETWEEN 751066 AND 751071
