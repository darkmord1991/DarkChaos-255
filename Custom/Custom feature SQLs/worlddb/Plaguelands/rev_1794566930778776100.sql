-- DarkChaos: map 751 Alliance route, phase 2, block 4 of 5: Hillsbrad Foothills (Stormpike camp)
--
-- Phase-2 set, apply in this order: rev_1794566930352012600 (Gilneas west/south), rev_1794566930499515200
--   (Tirisfal), rev_1794566930637186200 (Silverpine), rev_1794566930778776100 (Hillsbrad), rev_1794566930955974800
--   (group quests and dailies). Each file needs only phase 1 and the drop ladder; the five do not depend on each
--   other.
--
-- Quests (QuestLevel -1; MinLevel = zone band low - 2, or the band low where the targets stand 4-5 levels
-- above it; every target is a mob already spawned on 751):
--   751060 Daggerspine Scales [MinLevel 136, XP difficulty 5]: 10x Daggerspine Scale (3509)
--   751061 Torn Fin Eyes [MinLevel 136, XP difficulty 5]: 10x Torn Fin Eye (3510)
--   751062 Mountain Yetis [MinLevel 136, XP difficulty 5]: 10x Mountain Yeti (4102250)
--   751063 Giants in the Ruins [MinLevel 138, XP difficulty 6]: 8x Giant Yeti (4102251)
--   751064 Rampaging Owlbeasts [MinLevel 136, XP difficulty 5]: 10x Rampaging Owlbeast (4149245)
--   751065 Brutes of the Crushridge [MinLevel 138, XP difficulty 6]: 8x Crushridge Brute (4102253); 6x Crushridge
--     Mauler (4102254)
-- Objective markers are small octagons over the target groups on open ground (none over caves); each was checked
-- against the terrain heightmap: from every point of it at least one target stands within 100 yd and 5 yd of
-- height, as a playerbot needs.
-- Respawn: the target groups below go from 300 s to 120 s, so 20-30 bots on the same quest do not starve them
--   (revert: spawntimesecs back to 300 on the listed guids): Daggerspine Shorestalker 4102368 x17, Daggerspine
--     Screamer 4102370 x11, Daggerspine Siren 4102371 x22, Daggerspine Shorehunter 4102369 x19, Mountain Yeti 4102250
--     x17, Giant Yeti 4102251 x28, Rampaging Owlbeast 4149245 x50, Crushridge Brute 4102253 x26, Crushridge Mauler
--     4102254 x16
-- IDS: quests 751060-751065 (verified free).
-- DEPENDS ON: phase 1 (Commander Stonebrow 830321, Lieutenant Farren Orinelle 830322, Marshal Redpath 830323); the
--   drop ladder rev_1794428606734586200 for gear rewards.
-- REVERT: quests 751060-751065 with their addon/texts/starters/enders/POIs, plus the respawn change above.
-- Re-runnable: quest_template is REPLACEd, every INSERT is preceded by a DELETE of exactly its keys, and every
-- UPDATE is guarded by the value it replaces. Apply to acore_world, then restart the worldserver.

-- 1. quests 751060-751065 (REPLACE: template rows are never deleted)
REPLACE INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`, `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`, `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`) VALUES
(751060, 2, -1, 136, 4936, 0, 0, 5, 126900, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, -1194.5, -905.1, 730, 5, 910163021, 'Daggerspine Scales', 'Collect 10 Daggerspine Scales from the Daggerspine naga on the Eastern Strand.', 'My transfer papers went to Stormwind, $N, and Stormwind wrote back. High Command wants proof the naga are what I say they are - scales, ten of them, for the scholars at the Cathedral.$B$BI will not pretend I can face them again. The Daggerspine on the Eastern Strand, south of the ruins: any of them will do.', '', 'Return to Lieutenant Farren Orinelle at the Stormpike Encampment in Hillsbrad Foothills.', 0, 0, 0, 0, 0, 0, 0, 0, 3509, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751061, 2, -1, 136, 4936, 0, 0, 5, 126900, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, -1042.9, -299.5, 730, 5, 910163021, 'Torn Fin Eyes', 'Collect 10 Torn Fin Eyes from the Torn Fin murlocs of the Western Strand.', 'Redpath again. Now he wants to know how many murlocs are left on the Western Strand, and he will not take my word for it. Murloc eyes, he says. Ten. One per murloc, so the count is honest.$B$BPlease, $N. I cannot look at another one of those things.', '', 'Return to Lieutenant Farren Orinelle at the Stormpike Encampment in Hillsbrad Foothills.', 0, 0, 0, 0, 0, 0, 0, 0, 3510, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751062, 2, -1, 136, 4936, 0, 0, 5, 126900, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, 172.5, -247.1, 730, 5, 910163021, 'Mountain Yetis', 'Slay 10 Mountain Yetis in the hills north of the Stormpike Encampment.', 'The yetis in the cave were only half our trouble. The mountain yetis on the slopes north of here come down to the camp whenever the snow is deep - and up here the snow is always deep.$B$BCull them, $N. Ten should keep the rest up the mountain.', '', 'Return to Commander Brannoc Stonebrow at the Stormpike Encampment in Hillsbrad Foothills.', 4102250, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751063, 2, -1, 138, 4936, 0, 0, 6, 158625, 8, 421263, 421271, 421279, 421287, 0, 0, 1, 1, 1, 1, 0, 0, 751, 456.3, -227.1, 730, 5, 910163021, 'Giants in the Ruins', 'Slay 8 Giant Yetis around the Ruins of Alterac and Growless Cave.', 'Bigger than the mountain yetis, meaner than the cave yetis: the giants. They roam the high ground around the Ruins of Alterac and Growless Cave, and they have taken two of our supply ponies this month.$B$BKill eight of them, $N. Take friends if you have them. Those things hit like a falling tree.', '', 'Return to Commander Brannoc Stonebrow at the Stormpike Encampment in Hillsbrad Foothills.', 4102251, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751064, 2, -1, 136, 4936, 0, 0, 5, 126900, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, -589.6, -1531.1, 730, 5, 910163021, 'Rampaging Owlbeasts', 'Slay 10 Rampaging Owlbeasts in the hills around Durnholde Keep.', 'Something has driven the owlbeasts of the southern hills mad. They tear through the old farms around Durnholde Keep and attack the patrols we send to watch the keep.$B$BI do not care what drives them. Kill ten, $N, so my patrols can do their work.', '', 'Return to Marshal Redpath at the Stormpike Encampment in Hillsbrad Foothills.', 4149245, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751065, 2, -1, 138, 4936, 0, 0, 6, 158625, 8, 421264, 421272, 421280, 421288, 0, 0, 1, 1, 1, 1, 0, 0, 751, 597.7, -592.7, 730, 5, 910163021, 'Brutes of the Crushridge', 'Slay 8 Crushridge Brutes at Crushridge Hold and 6 Crushridge Maulers in the Ruins of Alterac.', 'The warmongers were the Crushridge''s officers. Their brutes and maulers are the muscle, and they still hold Crushridge Hold and the ruins below it.$B$BKeep the pressure on, $N. Eight brutes at the hold and six maulers in the ruins. Ogres respect nothing but a beating.', '', 'Return to Marshal Redpath at the Stormpike Encampment in Hillsbrad Foothills.', 4102253, 4102254, 0, 0, 8, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0);

-- chains, breadcrumbs and daily flags
DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 751060 AND 751065;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`, `BreadcrumbForQuestId`, `SpecialFlags`) VALUES
(751060, 200562, 0, 0),
(751061, 200559, 0, 0),
(751062, 0, 0, 0),
(751063, 751062, 0, 0),
(751064, 0, 0, 0),
(751065, 200504, 0, 0);

-- texts
DELETE FROM `quest_offer_reward` WHERE `ID` BETWEEN 751060 AND 751065;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES
(751060, 1, 'Scales! Real naga scales. Stormwind cannot argue with these. I owe you, $N.', 0),
(751061, 1, 'They are staring at me. Take them to - no, I will take them to Redpath myself. Thank you.', 0),
(751062, 1, 'Ten mountain yetis. The pickets will sleep easier tonight.', 0),
(751063, 1, 'Eight giants! The lads will not believe it. Here - boots that will keep you on your feet in the snow.', 0),
(751064, 1, 'Ten owlbeasts. Good. The patrols go out again tomorrow.', 0),
(751065, 1, 'Well struck. The Crushridge will think twice before they come down this hill. Take these.', 0);
DELETE FROM `quest_request_items` WHERE `ID` BETWEEN 751060 AND 751065;
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`) VALUES
(751060, 6, 6, 'Do you have the scales?', 0),
(751061, 6, 6, 'Did you get the eyes?', 0),
(751062, 6, 6, 'Are the slopes clear?', 0),
(751063, 6, 6, 'Are the giants still roaming?', 0),
(751064, 6, 6, 'The owlbeasts are still loose.', 0),
(751065, 6, 6, 'You have more ogres to beat, $N.', 0);

-- givers and enders
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 751060 AND 751065;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(830322, 751060),
(830322, 751061),
(830321, 751062),
(830321, 751063),
(830323, 751064),
(830323, 751065);
DELETE FROM `creature_questender` WHERE `quest` BETWEEN 751060 AND 751065;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(830322, 751060),
(830322, 751061),
(830321, 751062),
(830321, 751063),
(830323, 751064),
(830323, 751065);

-- quest map markers: small octagons over the target groups that stand on open ground (none over a mine or
-- cave, so bots use the spawn points there), and the turn-in point
DELETE FROM `quest_poi` WHERE `QuestID` BETWEEN 751060 AND 751065;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(751060, 0, 4, 751, 1271, 0, 0, 1, 0),
(751060, 1, 4, 751, 1271, 0, 0, 1, 0),
(751060, 2, 4, 751, 1271, 0, 0, 1, 0),
(751060, 3, 4, 751, 1271, 0, 0, 1, 0),
(751060, 4, -1, 751, 1271, 0, 0, 1, 0),
(751061, 0, 4, 751, 1271, 0, 0, 1, 0),
(751061, 1, 4, 751, 1271, 0, 0, 1, 0),
(751061, 2, 4, 751, 1271, 0, 0, 1, 0),
(751061, 3, -1, 751, 1271, 0, 0, 1, 0),
(751062, 0, 0, 751, 1271, 0, 0, 1, 0),
(751062, 1, 0, 751, 1271, 0, 0, 1, 0),
(751062, 2, -1, 751, 1271, 0, 0, 1, 0),
(751063, 0, 0, 751, 1271, 0, 0, 1, 0),
(751063, 1, 0, 751, 1271, 0, 0, 1, 0),
(751063, 2, 0, 751, 1271, 0, 0, 1, 0),
(751063, 3, 0, 751, 1271, 0, 0, 1, 0),
(751063, 4, -1, 751, 1271, 0, 0, 1, 0),
(751064, 0, 0, 751, 1271, 0, 0, 1, 0),
(751064, 1, 0, 751, 1271, 0, 0, 1, 0),
(751064, 2, 0, 751, 1271, 0, 0, 1, 0),
(751064, 3, 0, 751, 1271, 0, 0, 1, 0),
(751064, 4, -1, 751, 1271, 0, 0, 1, 0),
(751065, 0, 0, 751, 1271, 0, 0, 1, 0),
(751065, 1, 0, 751, 1271, 0, 0, 1, 0),
(751065, 2, 1, 751, 1271, 0, 0, 1, 0),
(751065, 3, 1, 751, 1271, 0, 0, 1, 0),
(751065, 4, -1, 751, 1271, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` BETWEEN 751060 AND 751065;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(751060, 0, 0, -1088, -832, 0),
(751060, 0, 1, -1106, -790, 0),
(751060, 0, 2, -1148, -772, 0),
(751060, 0, 3, -1191, -790, 0),
(751060, 0, 4, -1208, -832, 0),
(751060, 0, 5, -1191, -875, 0),
(751060, 0, 6, -1148, -892, 0),
(751060, 0, 7, -1106, -875, 0),
(751060, 1, 0, -1312, -1056, 0),
(751060, 1, 1, -1330, -1013, 0),
(751060, 1, 2, -1372, -996, 0),
(751060, 1, 3, -1415, -1013, 0),
(751060, 1, 4, -1432, -1056, 0),
(751060, 1, 5, -1415, -1098, 0),
(751060, 1, 6, -1372, -1116, 0),
(751060, 1, 7, -1330, -1098, 0),
(751060, 2, 0, -953, -778, 0),
(751060, 2, 1, -970, -736, 0),
(751060, 2, 2, -1013, -718, 0),
(751060, 2, 3, -1055, -736, 0),
(751060, 2, 4, -1073, -778, 0),
(751060, 2, 5, -1055, -821, 0),
(751060, 2, 6, -1013, -838, 0),
(751060, 2, 7, -970, -821, 0),
(751060, 3, 0, -1188, -954, 0),
(751060, 3, 1, -1205, -914, 0),
(751060, 3, 2, -1245, -898, 0),
(751060, 3, 3, -1285, -914, 0),
(751060, 3, 4, -1301, -954, 0),
(751060, 3, 5, -1285, -994, 0),
(751060, 3, 6, -1245, -1011, 0),
(751060, 3, 7, -1205, -994, 0),
(751060, 4, 0, -2, -334, 0),
(751061, 0, 0, -1004, -314, 0),
(751061, 0, 1, -1022, -272, 0),
(751061, 0, 2, -1064, -254, 0),
(751061, 0, 3, -1107, -272, 0),
(751061, 0, 4, -1124, -314, 0),
(751061, 0, 5, -1107, -356, 0),
(751061, 0, 6, -1064, -374, 0),
(751061, 0, 7, -1022, -356, 0),
(751061, 1, 0, -1016, -98, 0),
(751061, 1, 1, -1034, -56, 0),
(751061, 1, 2, -1076, -38, 0),
(751061, 1, 3, -1118, -56, 0),
(751061, 1, 4, -1136, -98, 0),
(751061, 1, 5, -1118, -141, 0),
(751061, 1, 6, -1076, -158, 0),
(751061, 1, 7, -1034, -141, 0),
(751061, 2, 0, -957, -486, 0),
(751061, 2, 1, -966, -464, 0),
(751061, 2, 2, -988, -455, 0),
(751061, 2, 3, -1011, -464, 0),
(751061, 2, 4, -1020, -486, 0),
(751061, 2, 5, -1011, -509, 0),
(751061, 2, 6, -988, -518, 0),
(751061, 2, 7, -966, -509, 0),
(751061, 3, 0, -2, -334, 0),
(751062, 0, 0, 199, -302, 0),
(751062, 0, 1, 187, -274, 0),
(751062, 0, 2, 159, -262, 0),
(751062, 0, 3, 131, -274, 0),
(751062, 0, 4, 119, -302, 0),
(751062, 0, 5, 131, -330, 0),
(751062, 0, 6, 159, -342, 0),
(751062, 0, 7, 187, -330, 0),
(751062, 1, 0, 226, -192, 0),
(751062, 1, 1, 214, -164, 0),
(751062, 1, 2, 186, -152, 0),
(751062, 1, 3, 158, -164, 0),
(751062, 1, 4, 146, -192, 0),
(751062, 1, 5, 158, -221, 0),
(751062, 1, 6, 186, -232, 0),
(751062, 1, 7, 214, -221, 0),
(751062, 2, 0, -12, -322, 0),
(751063, 0, 0, 642, -90, 0),
(751063, 0, 1, 620, -37, 0),
(751063, 0, 2, 567, -15, 0),
(751063, 0, 3, 514, -37, 0),
(751063, 0, 4, 492, -90, 0),
(751063, 0, 5, 514, -143, 0),
(751063, 0, 6, 567, -165, 0),
(751063, 0, 7, 620, -143, 0),
(751063, 1, 0, 359, -380, 0),
(751063, 1, 1, 337, -327, 0),
(751063, 1, 2, 284, -305, 0),
(751063, 1, 3, 231, -327, 0),
(751063, 1, 4, 209, -380, 0),
(751063, 1, 5, 231, -433, 0),
(751063, 1, 6, 284, -455, 0),
(751063, 1, 7, 337, -433, 0),
(751063, 2, 0, 860, -211, 0),
(751063, 2, 1, 842, -167, 0),
(751063, 2, 2, 797, -148, 0),
(751063, 2, 3, 753, -167, 0),
(751063, 2, 4, 734, -211, 0),
(751063, 2, 5, 753, -256, 0),
(751063, 2, 6, 797, -274, 0),
(751063, 2, 7, 842, -256, 0),
(751063, 3, 0, 238, -227, 0),
(751063, 3, 1, 220, -184, 0),
(751063, 3, 2, 177, -166, 0),
(751063, 3, 3, 134, -184, 0),
(751063, 3, 4, 116, -227, 0),
(751063, 3, 5, 134, -270, 0),
(751063, 3, 6, 177, -288, 0),
(751063, 3, 7, 220, -270, 0),
(751063, 4, 0, -12, -322, 0),
(751064, 0, 0, -810, -1171, 0),
(751064, 0, 1, -832, -1119, 0),
(751064, 0, 2, -884, -1098, 0),
(751064, 0, 3, -936, -1119, 0),
(751064, 0, 4, -958, -1171, 0),
(751064, 0, 5, -936, -1224, 0),
(751064, 0, 6, -884, -1245, 0),
(751064, 0, 7, -832, -1224, 0),
(751064, 1, 0, -265, -1639, 0),
(751064, 1, 1, -287, -1586, 0),
(751064, 1, 2, -340, -1564, 0),
(751064, 1, 3, -393, -1586, 0),
(751064, 1, 4, -415, -1639, 0),
(751064, 1, 5, -393, -1692, 0),
(751064, 1, 6, -340, -1714, 0),
(751064, 1, 7, -287, -1692, 0),
(751064, 2, 0, -580, -1602, 0),
(751064, 2, 1, -602, -1549, 0),
(751064, 2, 2, -655, -1527, 0),
(751064, 2, 3, -708, -1549, 0),
(751064, 2, 4, -730, -1602, 0),
(751064, 2, 5, -708, -1655, 0),
(751064, 2, 6, -655, -1677, 0),
(751064, 2, 7, -602, -1655, 0),
(751064, 3, 0, -405, -1712, 0),
(751064, 3, 1, -427, -1659, 0),
(751064, 3, 2, -479, -1637, 0),
(751064, 3, 3, -532, -1659, 0),
(751064, 3, 4, -554, -1712, 0),
(751064, 3, 5, -532, -1765, 0),
(751064, 3, 6, -479, -1787, 0),
(751064, 3, 7, -427, -1765, 0),
(751064, 4, 0, 8, -345, 0),
(751065, 0, 0, 855, -565, 0),
(751065, 0, 1, 834, -515, 0),
(751065, 0, 2, 785, -495, 0),
(751065, 0, 3, 735, -515, 0),
(751065, 0, 4, 715, -565, 0),
(751065, 0, 5, 735, -614, 0),
(751065, 0, 6, 785, -635, 0),
(751065, 0, 7, 834, -614, 0),
(751065, 1, 0, 462, -621, 0),
(751065, 1, 1, 447, -584, 0),
(751065, 1, 2, 411, -569, 0),
(751065, 1, 3, 374, -584, 0),
(751065, 1, 4, 359, -621, 0),
(751065, 1, 5, 374, -657, 0),
(751065, 1, 6, 411, -672, 0),
(751065, 1, 7, 447, -657, 0),
(751065, 2, 0, 654, -416, 0),
(751065, 2, 1, 640, -382, 0),
(751065, 2, 2, 606, -368, 0),
(751065, 2, 3, 572, -382, 0),
(751065, 2, 4, 558, -416, 0),
(751065, 2, 5, 572, -450, 0),
(751065, 2, 6, 606, -464, 0),
(751065, 2, 7, 640, -450, 0),
(751065, 3, 0, 654, -505, 0),
(751065, 3, 1, 646, -486, 0),
(751065, 3, 2, 627, -478, 0),
(751065, 3, 3, 608, -486, 0),
(751065, 3, 4, 601, -505, 0),
(751065, 3, 5, 608, -524, 0),
(751065, 3, 6, 627, -532, 0),
(751065, 3, 7, 646, -524, 0),
(751065, 4, 0, 8, -345, 0);

-- 2. respawn 300 -> 120 seconds for the target groups
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102368 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16716122, 16716124, 16716126,
    16716127, 16716128, 16716130, 16716131, 16716132, 16716137, 16716142, 16716143, 16716145, 16716146, 16716196,
    16716197, 16716199, 16716201);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102370 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16716123, 16716125, 16716129,
    16716133, 16716134, 16716138, 16716139, 16716140, 16716141, 16716144, 16716198);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102371 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16716136, 16716235, 16716236,
    16716237, 16716251, 16716253, 16716255, 16716256, 16716257, 16716277, 16716278, 16716280, 16716303, 16716304,
    16716305, 16716306, 16716307, 16716380, 16716381, 16716382, 16716390, 16716391);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102369 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16716200, 16716202, 16716232,
    16716233, 16716234, 16716238, 16716252, 16716254, 16716276, 16716279, 16716308, 16716377, 16716379, 16716383,
    16716384, 16716385, 16716386, 16716387, 16716388);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102250 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16717592, 16717593, 16717596,
    16717597, 16717860, 16717862, 16717864, 16717867, 16717869, 16718076, 16718077, 16718201, 16718203, 16718270,
    16718298, 16718299, 16718362);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102251 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16717589, 16717590, 16717591,
    16717594, 16717595, 16717823, 16717858, 16717859, 16717861, 16717865, 16717866, 16717868, 16718300, 16718361,
    16718418, 16718420, 16718421, 16718422, 16718424, 16718425, 16718443, 16718444, 16718445, 16718446, 16718447,
    16718448, 16718496, 16718497);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4149245 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16716018, 16716019, 16716020,
    16716022, 16716025, 16716026, 16716027, 16716030, 16716032, 16716036, 16716037, 16716038, 16716051, 16716149,
    16716158, 16716159, 16716160, 16716161, 16716168, 16716177, 16716181, 16716184, 16716185, 16716192, 16716204,
    16716207, 16716209, 16716218, 16716219, 16716220, 16716222, 16716228, 16716230, 16716249, 16716268, 16716270,
    16716271, 16716274, 16716289, 16716293, 16716294, 16716298, 16716299, 16716309, 16716311, 16716341, 16716345,
    16716348, 16716366, 16716398);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102253 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16717560, 16717563, 16717564,
    16717568, 16717570, 16717575, 16717584, 16717586, 16717588, 16717825, 16717826, 16717831, 16717832, 16717851,
    16717853, 16717854, 16718219, 16718220, 16718221, 16718248, 16718249, 16718250, 16718251, 16718370, 16718376,
    16718431);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4102254 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16718212, 16718214, 16718215,
    16718216, 16718217, 16718254, 16718255, 16718256, 16718258, 16718260, 16718331, 16718332, 16718333, 16718366,
    16718428, 16718430);

-- Verification, to run after applying (expected values in the labels):
--   SELECT 'quests (want 6)' AS `check`, COUNT(*) AS `n` FROM `quest_template` WHERE `ID` BETWEEN 751060 AND 751065
--   UNION ALL SELECT 'givers (want 6)', COUNT(*) FROM `creature_queststarter` WHERE `quest` BETWEEN 751060 AND 751065
--   UNION ALL SELECT 'enders (want 6)', COUNT(*) FROM `creature_questender` WHERE `quest` BETWEEN 751060 AND 751065
