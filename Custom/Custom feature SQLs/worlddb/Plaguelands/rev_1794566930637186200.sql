-- DarkChaos: map 751 Alliance route, phase 2, block 3 of 5: Silverpine Forest (Ambermill)
--
-- Phase-2 set, apply in this order: rev_1794566930352012600 (Gilneas west/south), rev_1794566930499515200
--   (Tirisfal), rev_1794566930637186200 (Silverpine), rev_1794566930778776100 (Hillsbrad), rev_1794566930955974800
--   (group quests and dailies). Each file needs only phase 1 and the drop ladder; the five do not depend on each
--   other.
--
-- Quests (QuestLevel -1; MinLevel = zone band low - 2, or the band low where the targets stand 4-5 levels
-- above it; every target is a mob already spawned on 751):
--   751057 Skitterweb Menace [MinLevel 133, XP difficulty 6]: 10x Skitterweb Lurker (4101781); 4x Skitterweb
--     Striker (4101780)
--   751058 Skittering Blood [MinLevel 133, XP difficulty 5]: 8x Skittering Blood (3254)
--   751059 Vile Fin Raiders [MinLevel 133, XP difficulty 6]: 10x Vile Fin Oracle (4101908); 10x Vile Fin Tidehunter
--     (4101768)
-- Objective markers are small octagons over the target groups on open ground (none over caves); each was checked
-- against the terrain heightmap: from every point of it at least one target stands within 100 yd and 5 yd of
-- height, as a playerbot needs.
-- Respawn: the target groups below go from 300 s to 120 s, so 20-30 bots on the same quest do not starve them
--   (revert: spawntimesecs back to 300 on the listed guids): Skitterweb Lurker 4101781 x24, Skitterweb Striker
--     4101780 x9
-- New quest drops (QuestRequired, so they drop only while the quest is active; revert: delete the rows):
--   item 3254 on 4101781 at 40%
--   item 3254 on 4101780 at 40%
-- IDS: quests 751057-751059 (verified free).
-- DEPENDS ON: phase 1 (Magus Lyria Ashcombe 830316 and Ranger Corwin Dale 830317 at Ambermill); the drop ladder
--   rev_1794428606734586200 for gear rewards.
-- REVERT: quests 751057-751059 with their addon/texts/starters/enders/POIs, plus the respawn change and the loot
--   rows above.
-- Re-runnable: quest_template is REPLACEd, every INSERT is preceded by a DELETE of exactly its keys, and every
-- UPDATE is guarded by the value it replaces. Apply to acore_world, then restart the worldserver.

-- 1. quests 751057-751059 (REPLACE: template rows are never deleted)
REPLACE INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`, `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`, `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`) VALUES
(751057, 2, -1, 133, 4935, 0, 0, 6, 154125, 8, 421177, 421185, 421193, 421201, 0, 0, 1, 1, 1, 1, 0, 0, 751, 1213.5, 1903.1, 72, 5, 910163021, 'Skitterweb Menace', 'Slay 10 Skitterweb Lurkers and 4 Skitterweb Strikers in the Skittering Dark, north-west Silverpine.', 'Our scouts in the north-west of the forest come back pale and shaking - when they come back. The Skittering Dark is spider country, and the brood there has grown so big it spills onto the coast road.$B$BGo north, $N. Kill ten of the lurkers and four of the strikers that hunt the road, and keep away from the Forsaken''s camps on the way.', '', 'Return to Ranger Corwin Dale in Ambermill, Silverpine Forest.', 4101781, 4101780, 0, 0, 10, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751058, 2, -1, 133, 4935, 0, 0, 5, 123300, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, 1216.8, 1917.6, 1090, 5, 910163021, 'Skittering Blood', 'Collect 8 Skittering Blood from the Skitterweb spiders of the Skittering Dark.', 'The spiders of the Skittering Dark carry a venom that dulls arcane wards - our wards. If the Forsaken learn to bottle it, Ambermill will not hold a week.$B$BI need to know what it is. Bring me eight vials of their blood, $N. The lurkers and strikers of the Skittering Dark will do.', '', 'Return to Magus Lyria Ashcombe in Ambermill, Silverpine Forest.', 0, 0, 0, 0, 0, 0, 0, 0, 3254, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751059, 2, -1, 133, 4935, 0, 0, 6, 154125, 8, 421179, 421187, 421195, 421203, 0, 0, 1, 1, 1, 1, 0, 0, 751, 900.3, 200.2, 72, 5, 910163021, 'Vile Fin Raiders', 'Slay 10 Vile Fin Oracles and 10 Vile Fin Tidehunters on the northern coast of Silverpine.', 'The Vile Fin murlocs of the northern coast raid every boat on the sea road, and the Lordamere fishers who brought us fish now stay in harbour. Their oracles and tidehunters gather on the shore by the Dawning Isles.$B$BBreak them, $N. Ten oracles, ten tidehunters.', '', 'Return to Ranger Corwin Dale in Ambermill, Silverpine Forest.', 4101908, 4101768, 0, 0, 10, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0);

-- chains, breadcrumbs and daily flags
DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 751057 AND 751059;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`, `BreadcrumbForQuestId`, `SpecialFlags`) VALUES
(751057, 0, 0, 0),
(751058, 0, 0, 0),
(751059, 0, 0, 0);

-- texts
DELETE FROM `quest_offer_reward` WHERE `ID` BETWEEN 751057 AND 751059;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES
(751057, 1, 'Ten lurkers and their strikers. That should keep the road open for a while. Here, for your boots.', 0),
(751058, 1, 'Careful - set them down gently. Yes... this explains a great deal. The Kirin Tor are in your debt.', 0),
(751059, 1, 'The fishers will be out again by the end of the week. Take a pair of these.', 0);
DELETE FROM `quest_request_items` WHERE `ID` BETWEEN 751057 AND 751059;
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`) VALUES
(751057, 6, 6, 'Is the road through the Skittering Dark open?', 0),
(751058, 6, 6, 'Have you got the blood?', 0),
(751059, 6, 6, 'Are the murlocs still raiding the coast?', 0);

-- givers and enders
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 751057 AND 751059;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(830317, 751057),
(830316, 751058),
(830317, 751059);
DELETE FROM `creature_questender` WHERE `quest` BETWEEN 751057 AND 751059;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(830317, 751057),
(830316, 751058),
(830317, 751059);

-- quest map markers: small octagons over the target groups that stand on open ground (none over a mine or
-- cave, so bots use the spawn points there), and the turn-in point
DELETE FROM `quest_poi` WHERE `QuestID` BETWEEN 751057 AND 751059;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(751057, 0, 0, 751, 1270, 0, 0, 1, 0),
(751057, 1, 0, 751, 1270, 0, 0, 1, 0),
(751057, 2, 1, 751, 1270, 0, 0, 1, 0),
(751057, 3, 1, 751, 1270, 0, 0, 1, 0),
(751057, 4, -1, 751, 1270, 0, 0, 1, 0),
(751058, 0, 4, 751, 1270, 0, 0, 1, 0),
(751058, 1, 4, 751, 1270, 0, 0, 1, 0),
(751058, 2, -1, 751, 1270, 0, 0, 1, 0),
(751059, 0, 0, 751, 1270, 0, 0, 1, 0),
(751059, 1, 0, 751, 1270, 0, 0, 1, 0),
(751059, 2, 0, 751, 1270, 0, 0, 1, 0),
(751059, 3, 0, 751, 1270, 0, 0, 1, 0),
(751059, 4, 1, 751, 1270, 0, 0, 1, 0),
(751059, 5, 1, 751, 1270, 0, 0, 1, 0),
(751059, 6, 1, 751, 1270, 0, 0, 1, 0),
(751059, 7, 1, 751, 1270, 0, 0, 1, 0),
(751059, 8, -1, 751, 1270, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` BETWEEN 751057 AND 751059;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(751057, 0, 0, 1300, 1929, 0),
(751057, 0, 1, 1283, 1971, 0),
(751057, 0, 2, 1240, 1989, 0),
(751057, 0, 3, 1198, 1971, 0),
(751057, 0, 4, 1180, 1929, 0),
(751057, 0, 5, 1198, 1887, 0),
(751057, 0, 6, 1240, 1869, 0),
(751057, 0, 7, 1283, 1887, 0),
(751057, 1, 0, 1247, 1877, 0),
(751057, 1, 1, 1229, 1920, 0),
(751057, 1, 2, 1187, 1937, 0),
(751057, 1, 3, 1144, 1920, 0),
(751057, 1, 4, 1127, 1877, 0),
(751057, 1, 5, 1144, 1835, 0),
(751057, 1, 6, 1187, 1817, 0),
(751057, 1, 7, 1229, 1835, 0),
(751057, 2, 0, 1317, 2004, 0),
(751057, 2, 1, 1299, 2047, 0),
(751057, 2, 2, 1257, 2064, 0),
(751057, 2, 3, 1214, 2047, 0),
(751057, 2, 4, 1197, 2004, 0),
(751057, 2, 5, 1214, 1962, 0),
(751057, 2, 6, 1257, 1944, 0),
(751057, 2, 7, 1299, 1962, 0),
(751057, 3, 0, 1204, 2011, 0),
(751057, 3, 1, 1196, 2030, 0),
(751057, 3, 2, 1176, 2038, 0),
(751057, 3, 3, 1157, 2030, 0),
(751057, 3, 4, 1149, 2011, 0),
(751057, 3, 5, 1157, 1991, 0),
(751057, 3, 6, 1176, 1983, 0),
(751057, 3, 7, 1196, 1991, 0),
(751057, 4, 0, -88, 726, 0),
(751058, 0, 0, 1307, 1958, 0),
(751058, 0, 1, 1289, 2000, 0),
(751058, 0, 2, 1247, 2018, 0),
(751058, 0, 3, 1204, 2000, 0),
(751058, 0, 4, 1187, 1958, 0),
(751058, 0, 5, 1204, 1916, 0),
(751058, 0, 6, 1247, 1898, 0),
(751058, 0, 7, 1289, 1916, 0),
(751058, 1, 0, 1247, 1877, 0),
(751058, 1, 1, 1229, 1920, 0),
(751058, 1, 2, 1187, 1937, 0),
(751058, 1, 3, 1144, 1920, 0),
(751058, 1, 4, 1127, 1877, 0),
(751058, 1, 5, 1144, 1835, 0),
(751058, 1, 6, 1187, 1817, 0),
(751058, 1, 7, 1229, 1835, 0),
(751058, 2, 0, -100, 732, 0),
(751059, 0, 0, 878, 148, 0),
(751059, 0, 1, 860, 191, 0),
(751059, 0, 2, 818, 208, 0),
(751059, 0, 3, 775, 191, 0),
(751059, 0, 4, 758, 148, 0),
(751059, 0, 5, 775, 106, 0),
(751059, 0, 6, 818, 88, 0),
(751059, 0, 7, 860, 106, 0),
(751059, 1, 0, 1028, 171, 0),
(751059, 1, 1, 1011, 213, 0),
(751059, 1, 2, 968, 231, 0),
(751059, 1, 3, 926, 213, 0),
(751059, 1, 4, 908, 171, 0),
(751059, 1, 5, 926, 128, 0),
(751059, 1, 6, 968, 111, 0),
(751059, 1, 7, 1011, 128, 0),
(751059, 2, 0, 1158, 267, 0),
(751059, 2, 1, 1141, 309, 0),
(751059, 2, 2, 1098, 327, 0),
(751059, 2, 3, 1056, 309, 0),
(751059, 2, 4, 1038, 267, 0),
(751059, 2, 5, 1056, 224, 0),
(751059, 2, 6, 1098, 207, 0),
(751059, 2, 7, 1141, 224, 0),
(751059, 3, 0, 755, 215, 0),
(751059, 3, 1, 744, 242, 0),
(751059, 3, 2, 717, 253, 0),
(751059, 3, 3, 690, 242, 0),
(751059, 3, 4, 679, 215, 0),
(751059, 3, 5, 690, 188, 0),
(751059, 3, 6, 717, 177, 0),
(751059, 3, 7, 744, 188, 0),
(751059, 4, 0, 825, 194, 0),
(751059, 4, 1, 807, 236, 0),
(751059, 4, 2, 765, 254, 0),
(751059, 4, 3, 722, 236, 0),
(751059, 4, 4, 705, 194, 0),
(751059, 4, 5, 722, 152, 0),
(751059, 4, 6, 765, 134, 0),
(751059, 4, 7, 807, 152, 0),
(751059, 5, 0, 1130, 284, 0),
(751059, 5, 1, 1112, 327, 0),
(751059, 5, 2, 1070, 344, 0),
(751059, 5, 3, 1027, 327, 0),
(751059, 5, 4, 1010, 284, 0),
(751059, 5, 5, 1027, 242, 0),
(751059, 5, 6, 1070, 224, 0),
(751059, 5, 7, 1112, 242, 0),
(751059, 6, 0, 971, 199, 0),
(751059, 6, 1, 954, 242, 0),
(751059, 6, 2, 911, 259, 0),
(751059, 6, 3, 869, 242, 0),
(751059, 6, 4, 851, 199, 0),
(751059, 6, 5, 869, 157, 0),
(751059, 6, 6, 911, 139, 0),
(751059, 6, 7, 954, 157, 0),
(751059, 7, 0, 909, 91, 0),
(751059, 7, 1, 896, 122, 0),
(751059, 7, 2, 865, 135, 0),
(751059, 7, 3, 834, 122, 0),
(751059, 7, 4, 821, 91, 0),
(751059, 7, 5, 834, 60, 0),
(751059, 7, 6, 865, 47, 0),
(751059, 7, 7, 896, 60, 0),
(751059, 8, 0, -88, 726, 0);

-- 2. respawn 300 -> 120 seconds for the target groups
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4101781 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16715792, 16715793, 16715794,
    16715797, 16715816, 16715817, 16715819, 16715820, 16715821, 16715823, 16715825, 16715827, 16715828, 16715829,
    16715940, 16715941, 16715944, 16715947, 16715950, 16715951, 16715954, 16715965, 16715966, 16718705);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4101780 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16715799, 16715801, 16715812,
    16715813, 16715814, 16715818, 16715943, 16715948, 16715955);

-- 3. quest drops
DELETE FROM `creature_loot_template` WHERE `Reference` = 0 AND (`Entry`, `Item`) IN ((4101781, 3254), (4101780, 3254));
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(4101781, 3254, 0, 40, 1, 1, 0, 1, 1, 'DC Alliance 751 p2: Skittering Blood (751058)'),
(4101780, 3254, 0, 40, 1, 1, 0, 1, 1, 'DC Alliance 751 p2: Skittering Blood (751058)');

-- Verification, to run after applying (expected values in the labels):
--   SELECT 'quests (want 3)' AS `check`, COUNT(*) AS `n` FROM `quest_template` WHERE `ID` BETWEEN 751057 AND 751059
--   UNION ALL SELECT 'givers (want 3)', COUNT(*) FROM `creature_queststarter` WHERE `quest` BETWEEN 751057 AND 751059
--   UNION ALL SELECT 'enders (want 3)', COUNT(*) FROM `creature_questender` WHERE `quest` BETWEEN 751057 AND 751059
