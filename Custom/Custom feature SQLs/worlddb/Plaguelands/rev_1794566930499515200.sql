-- DarkChaos: map 751 Alliance route, phase 2, block 2 of 5: Tirisfal Glades (Whispering Shore landing)
--
-- Phase-2 set, apply in this order: rev_1794566930352012600 (Gilneas west/south), rev_1794566930499515200
--   (Tirisfal), rev_1794566930637186200 (Silverpine), rev_1794566930778776100 (Hillsbrad), rev_1794566930955974800
--   (group quests and dailies). Each file needs only phase 1 and the drop ladder; the five do not depend on each
--   other.
--
-- Quests (QuestLevel -1; MinLevel = zone band low - 2, or the band low where the targets stand 4-5 levels
-- above it; every target is a mob already spawned on 751):
--   751051 Duskbat Pelts [MinLevel 128, XP difficulty 5]: 10x Duskbat Pelt (2876)
--   751052 Muckdwellers of the North Coast [MinLevel 128, XP difficulty 5]: 10x Vile Fin Muckdweller (4101545)
--   751053 Plagued Bruins [MinLevel 128, XP difficulty 5]: 8x Plagued Bruin (4139049)
--   751054 The Agamand Ancestors [MinLevel 128, XP difficulty 6]: 6x Rotting Ancestor (4101530); 6x Wailing
--     Ancestor (4101534)
--   751055 Bonecasters of Agamand [MinLevel 128, XP difficulty 5]: 10x Darkeye Bonecaster (4101522)
--   751056 Zealots at the Crusader Outpost [MinLevel 128, XP difficulty 5]: 8x Scarlet Zealot (4101537)
-- Objective markers are small octagons over the target groups on open ground (none over caves); each was checked
-- against the terrain heightmap: from every point of it at least one target stands within 100 yd and 5 yd of
-- height, as a playerbot needs.
-- Respawn: the target groups below go from 300 s to 120 s, so 20-30 bots on the same quest do not starve them
--   (revert: spawntimesecs back to 300 on the listed guids): Vile Fin Muckdweller 4101545 x55, Plagued Bruin
--     4139049 x42, Rotting Ancestor 4101530 x19, Wailing Ancestor 4101534 x15, Scarlet Zealot 4101537 x9
-- IDS: quests 751051-751056 (verified free).
-- DEPENDS ON: phase 1 (Scout Ellery Halvorsen 830313 at the Whispering Shore landing); the drop ladder
--   rev_1794428606734586200 for gear rewards.
-- REVERT: quests 751051-751056 with their addon/texts/starters/enders/POIs, plus the respawn change above.
-- Re-runnable: quest_template is REPLACEd, every INSERT is preceded by a DELETE of exactly its keys, and every
-- UPDATE is guarded by the value it replaces. Apply to acore_world, then restart the worldserver.

-- 1. quests 751051-751056 (REPLACE: template rows are never deleted)
REPLACE INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`, `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`, `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`) VALUES
(751051, 2, -1, 128, 4933, 0, 0, 5, 119700, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, 2461.9, 1207.4, 72, 5, 910163021, 'Duskbat Pelts', 'Scout Halvorsen wants 10 Duskbat Pelts from the duskbats of Tirisfal Glades.', 'The nights are cold on this shore, and we cannot light a fire without the Deathguard seeing it. Duskbat pelts are thin, but they are warm, and a few dozen sewn together make a fine blanket.$B$BThe glades inland are full of the creatures. Bring me ten pelts.', '', 'Return to Scout Ellery Halvorsen at the Whispering Shore in Tirisfal Glades.', 0, 0, 0, 0, 0, 0, 0, 0, 2876, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751052, 2, -1, 128, 4933, 0, 0, 5, 119700, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, 3012.2, 93, 72, 5, 910163021, 'Muckdwellers of the North Coast', 'Slay 10 Vile Fin Muckdwellers on the North Coast of Tirisfal Glades.', 'The submarine runs past the North Coast to reach us, and the Vile Fin muckdwellers there have learned to foul her screws with their nets. Twice now she has limped in late.$B$BGo up the coast and thin them out. Ten muckdwellers, and the captain will owe you a drink.', '', 'Return to Scout Ellery Halvorsen at the Whispering Shore in Tirisfal Glades.', 4101545, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751053, 2, -1, 128, 4933, 0, 0, 5, 119700, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, 2260.5, -295.6, 72, 5, 910163021, 'Plagued Bruins', 'Put down 8 Plagued Bruins in the hills east of Brill.', 'The Forsaken plague does not stop at people. The bears in the hills east of Brill are rotting where they stand, and they carry the sickness wherever they roam - even down to this shore.$B$BPut eight of the plagued bruins out of their misery, $N. Give Brill a wide berth on the way - the Deathguard do not love us.', '', 'Return to Scout Ellery Halvorsen at the Whispering Shore in Tirisfal Glades.', 4139049, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751054, 2, -1, 128, 4933, 0, 0, 6, 149625, 8, 421135, 421143, 421151, 421159, 0, 0, 1, 1, 1, 1, 0, 0, 751, 2930.2, 717.1, 72, 5, 910163021, 'The Agamand Ancestors', 'Destroy 6 Rotting Ancestors and 6 Wailing Ancestors around the Agamand family crypt.', 'The bones you brought me from Agamand Mills told our chaplain plenty. The Scourge left something worse behind: the Agamand ancestors themselves, risen from the family crypt and wailing.$B$BThey wander the hills around the crypt above the mills. Destroy six of the rotting ones and six of the wailing ones, $N, and let the Agamands sleep.', '', 'Return to Scout Ellery Halvorsen at the Whispering Shore in Tirisfal Glades.', 4101530, 4101534, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751055, 2, -1, 128, 4933, 0, 0, 5, 119700, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, 2832.4, 850.1, 72, 5, 910163021, 'Bonecasters of Agamand', 'Slay 10 Darkeye Bonecasters at Agamand Mills.', 'Someone is gathering the bones at Agamand Mills, I said. Now I know who: the Darkeye bonecasters, skeletal sorcerers who still bind the dead to the old Scourge''s will.$B$BKill ten of them, $N. Without their casters, the rest are just bones.', '', 'Return to Scout Ellery Halvorsen at the Whispering Shore in Tirisfal Glades.', 4101522, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0),
(751056, 2, -1, 128, 4933, 0, 0, 5, 119700, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 751, 2138, -525.1, 72, 5, 910163021, 'Zealots at the Crusader Outpost', 'Slay 8 Scarlet Zealots at the Crusader Outpost in eastern Tirisfal Glades.', 'The Scarlet Crusade keeps an outpost in the east of the glades, and its zealots ride out to hunt anything that is not one of them - Forsaken, worgen, or a 7th Legion scout who wandered too far.$B$BThey took one of mine last week. Kill eight of their zealots, $N. Let them learn that the Legion answers.', '', 'Return to Scout Ellery Halvorsen at the Whispering Shore in Tirisfal Glades.', 4101537, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', '', '', 0);

-- chains, breadcrumbs and daily flags
DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 751051 AND 751056;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`, `BreadcrumbForQuestId`, `SpecialFlags`) VALUES
(751051, 0, 0, 0),
(751052, 0, 0, 0),
(751053, 0, 0, 0),
(751054, 751015, 0, 0),
(751055, 751015, 0, 0),
(751056, 0, 0, 0);

-- texts
DELETE FROM `quest_offer_reward` WHERE `ID` BETWEEN 751051 AND 751056;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES
(751051, 1, 'Ugly, but warm. The lads will thank you when the sea wind blows.', 0),
(751052, 1, 'The captain says the coast was quiet last night. That drink is yours.', 0),
(751053, 1, 'A sad business, but a needed one. Wash your hands before you eat.', 0),
(751054, 1, 'The chaplain will say a prayer for them. You have earned something better than prayers - take one of these.', 0),
(751055, 1, 'No more casters, no more risen bones. The mills are only haunted now, not dangerous.', 0),
(751056, 1, 'Eight zealots. It will not bring her back, but it will make them careful. Thank you, $N.', 0);
DELETE FROM `quest_request_items` WHERE `ID` BETWEEN 751051 AND 751056;
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`) VALUES
(751051, 6, 6, 'Any pelts?', 0),
(751052, 6, 6, 'Have you been up the North Coast?', 0),
(751053, 6, 6, 'Are the bruins dealt with?', 0),
(751054, 6, 6, 'Do the ancestors still walk?', 0),
(751055, 6, 6, 'Are the bonecasters still at the mills?', 0),
(751056, 6, 6, 'Have you been to the outpost?', 0);

-- givers and enders
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 751051 AND 751056;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(830313, 751051),
(830313, 751052),
(830313, 751053),
(830313, 751054),
(830313, 751055),
(830313, 751056);
DELETE FROM `creature_questender` WHERE `quest` BETWEEN 751051 AND 751056;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(830313, 751051),
(830313, 751052),
(830313, 751053),
(830313, 751054),
(830313, 751055),
(830313, 751056);

-- quest map markers: small octagons over the target groups that stand on open ground (none over a mine or
-- cave, so bots use the spawn points there), and the turn-in point
DELETE FROM `quest_poi` WHERE `QuestID` BETWEEN 751051 AND 751056;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(751051, 0, 4, 751, 1269, 0, 0, 1, 0),
(751051, 1, 4, 751, 1269, 0, 0, 1, 0),
(751051, 2, 4, 751, 1269, 0, 0, 1, 0),
(751051, 3, -1, 751, 1269, 0, 0, 1, 0),
(751052, 0, 0, 751, 1269, 0, 0, 1, 0),
(751052, 1, 0, 751, 1269, 0, 0, 1, 0),
(751052, 2, 0, 751, 1269, 0, 0, 1, 0),
(751052, 3, 0, 751, 1269, 0, 0, 1, 0),
(751052, 4, -1, 751, 1269, 0, 0, 1, 0),
(751053, 0, 0, 751, 1269, 0, 0, 1, 0),
(751053, 1, 0, 751, 1269, 0, 0, 1, 0),
(751053, 2, -1, 751, 1269, 0, 0, 1, 0),
(751054, 0, 0, 751, 1269, 0, 0, 1, 0),
(751054, 1, 0, 751, 1269, 0, 0, 1, 0),
(751054, 2, 1, 751, 1269, 0, 0, 1, 0),
(751054, 3, -1, 751, 1269, 0, 0, 1, 0),
(751055, 0, 0, 751, 1269, 0, 0, 1, 0),
(751055, 1, 0, 751, 1269, 0, 0, 1, 0),
(751055, 2, -1, 751, 1269, 0, 0, 1, 0),
(751056, 0, 0, 751, 1269, 0, 0, 1, 0),
(751056, 1, 0, 751, 1269, 0, 0, 1, 0),
(751056, 2, -1, 751, 1269, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` BETWEEN 751051 AND 751056;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(751051, 0, 0, 2434, 1138, 0),
(751051, 0, 1, 2422, 1167, 0),
(751051, 0, 2, 2394, 1178, 0),
(751051, 0, 3, 2365, 1167, 0),
(751051, 0, 4, 2354, 1138, 0),
(751051, 0, 5, 2365, 1110, 0),
(751051, 0, 6, 2394, 1098, 0),
(751051, 0, 7, 2422, 1110, 0),
(751051, 1, 0, 2610, 1128, 0),
(751051, 1, 1, 2599, 1156, 0),
(751051, 1, 2, 2570, 1168, 0),
(751051, 1, 3, 2542, 1156, 0),
(751051, 1, 4, 2530, 1128, 0),
(751051, 1, 5, 2542, 1100, 0),
(751051, 1, 6, 2570, 1088, 0),
(751051, 1, 7, 2599, 1100, 0),
(751051, 2, 0, 2462, 1356, 0),
(751051, 2, 1, 2450, 1384, 0),
(751051, 2, 2, 2422, 1396, 0),
(751051, 2, 3, 2393, 1384, 0),
(751051, 2, 4, 2382, 1356, 0),
(751051, 2, 5, 2393, 1328, 0),
(751051, 2, 6, 2422, 1316, 0),
(751051, 2, 7, 2450, 1328, 0),
(751051, 3, 0, 2618, 1803, 0),
(751052, 0, 0, 3091, 39, 0),
(751052, 0, 1, 3071, 88, 0),
(751052, 0, 2, 3021, 109, 0),
(751052, 0, 3, 2972, 88, 0),
(751052, 0, 4, 2951, 39, 0),
(751052, 0, 5, 2972, -11, 0),
(751052, 0, 6, 3021, -31, 0),
(751052, 0, 7, 3071, -11, 0),
(751052, 1, 0, 3116, -326, 0),
(751052, 1, 1, 3096, -276, 0),
(751052, 1, 2, 3046, -256, 0),
(751052, 1, 3, 2997, -276, 0),
(751052, 1, 4, 2976, -326, 0),
(751052, 1, 5, 2997, -375, 0),
(751052, 1, 6, 3046, -396, 0),
(751052, 1, 7, 3096, -375, 0),
(751052, 2, 0, 3067, 382, 0),
(751052, 2, 1, 3046, 431, 0),
(751052, 2, 2, 2997, 452, 0),
(751052, 2, 3, 2947, 431, 0),
(751052, 2, 4, 2927, 382, 0),
(751052, 2, 5, 2947, 332, 0),
(751052, 2, 6, 2997, 312, 0),
(751052, 2, 7, 3046, 332, 0),
(751052, 3, 0, 3045, 277, 0),
(751052, 3, 1, 3027, 320, 0),
(751052, 3, 2, 2984, 338, 0),
(751052, 3, 3, 2942, 320, 0),
(751052, 3, 4, 2924, 277, 0),
(751052, 3, 5, 2942, 235, 0),
(751052, 3, 6, 2984, 217, 0),
(751052, 3, 7, 3027, 235, 0),
(751052, 4, 0, 2618, 1803, 0),
(751053, 0, 0, 2324, -366, 0),
(751053, 0, 1, 2302, -313, 0),
(751053, 0, 2, 2249, -291, 0),
(751053, 0, 3, 2196, -313, 0),
(751053, 0, 4, 2174, -366, 0),
(751053, 0, 5, 2196, -419, 0),
(751053, 0, 6, 2249, -441, 0),
(751053, 0, 7, 2302, -419, 0),
(751053, 1, 0, 2335, -225, 0),
(751053, 1, 1, 2316, -181, 0),
(751053, 1, 2, 2272, -162, 0),
(751053, 1, 3, 2228, -181, 0),
(751053, 1, 4, 2209, -225, 0),
(751053, 1, 5, 2228, -270, 0),
(751053, 1, 6, 2272, -288, 0),
(751053, 1, 7, 2316, -270, 0),
(751053, 2, 0, 2618, 1803, 0),
(751054, 0, 0, 3023, 743, 0),
(751054, 0, 1, 3011, 772, 0),
(751054, 0, 2, 2981, 785, 0),
(751054, 0, 3, 2952, 772, 0),
(751054, 0, 4, 2940, 743, 0),
(751054, 0, 5, 2952, 714, 0),
(751054, 0, 6, 2981, 702, 0),
(751054, 0, 7, 3011, 714, 0),
(751054, 1, 0, 2912, 691, 0),
(751054, 1, 1, 2902, 714, 0),
(751054, 1, 2, 2879, 724, 0),
(751054, 1, 3, 2856, 714, 0),
(751054, 1, 4, 2846, 691, 0),
(751054, 1, 5, 2856, 668, 0),
(751054, 1, 6, 2879, 659, 0),
(751054, 1, 7, 2902, 668, 0),
(751054, 2, 0, 3047, 663, 0),
(751054, 2, 1, 3029, 705, 0),
(751054, 2, 2, 2987, 723, 0),
(751054, 2, 3, 2944, 705, 0),
(751054, 2, 4, 2927, 663, 0),
(751054, 2, 5, 2944, 620, 0),
(751054, 2, 6, 2987, 603, 0),
(751054, 2, 7, 3029, 620, 0),
(751054, 3, 0, 2618, 1803, 0),
(751055, 0, 0, 2955, 897, 0),
(751055, 0, 1, 2937, 939, 0),
(751055, 0, 2, 2895, 957, 0),
(751055, 0, 3, 2852, 939, 0),
(751055, 0, 4, 2835, 897, 0),
(751055, 0, 5, 2852, 855, 0),
(751055, 0, 6, 2895, 837, 0),
(751055, 0, 7, 2937, 855, 0),
(751055, 1, 0, 2830, 803, 0),
(751055, 1, 1, 2812, 846, 0),
(751055, 1, 2, 2770, 863, 0),
(751055, 1, 3, 2728, 846, 0),
(751055, 1, 4, 2710, 803, 0),
(751055, 1, 5, 2728, 761, 0),
(751055, 1, 6, 2770, 743, 0),
(751055, 1, 7, 2812, 761, 0),
(751055, 2, 0, 2618, 1803, 0),
(751056, 0, 0, 2183, -450, 0),
(751056, 0, 1, 2173, -426, 0),
(751056, 0, 2, 2149, -416, 0),
(751056, 0, 3, 2125, -426, 0),
(751056, 0, 4, 2115, -450, 0),
(751056, 0, 5, 2125, -474, 0),
(751056, 0, 6, 2149, -484, 0),
(751056, 0, 7, 2173, -474, 0),
(751056, 1, 0, 2161, -600, 0),
(751056, 1, 1, 2151, -576, 0),
(751056, 1, 2, 2127, -567, 0),
(751056, 1, 3, 2103, -576, 0),
(751056, 1, 4, 2093, -600, 0),
(751056, 1, 5, 2103, -624, 0),
(751056, 1, 6, 2127, -634, 0),
(751056, 1, 7, 2151, -624, 0),
(751056, 2, 0, 2618, 1803, 0);

-- 2. respawn 300 -> 120 seconds for the target groups
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4101545 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16719744, 16719746, 16719840,
    16720029, 16720030, 16720032, 16720039, 16720292, 16720295, 16720296, 16720297, 16720299, 16720308, 16720309,
    16720311, 16720413, 16720414, 16720416, 16720570, 16720571, 16720572, 16720579, 16720583, 16720584, 16720585,
    16720684, 16720744, 16720746, 16720747, 16720749, 16720750, 16720754, 16720756, 16720758, 16720763, 16720764,
    16720820, 16720821, 16720825, 16720827, 16720829, 16720836, 16720900, 16720902, 16720907, 16720908, 16720909,
    16720910, 16720914, 16720918, 16720958, 16720959, 16720961, 16720962, 16720963);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4139049 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16720724, 16720785, 16720845,
    16720847, 16720852, 16720860, 16720862, 16720865, 16720867, 16720869, 16720872, 16720876, 16720877, 16720879,
    16720882, 16720883, 16720890, 16720926, 16720927, 16720930, 16720931, 16720934, 16720935, 16720944, 16720952,
    16720953, 16720969, 16720971, 16720979, 16720981, 16720982, 16720994, 16720995, 16720999, 16721028, 16721047,
    16721057, 16721064, 16721065, 16721141, 16721150, 16721151);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4101530 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16719501, 16719556, 16719558,
    16719586, 16719587, 16719588, 16719590, 16719591, 16719594, 16719597, 16719598, 16719599, 16719600, 16719602,
    16719603, 16719604, 16719606, 16719614, 16719693);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4101534 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16719500, 16719504, 16719557,
    16719559, 16719589, 16719593, 16719595, 16719596, 16719601, 16719605, 16719608, 16719609, 16719610, 16719612,
    16719613);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 4101537 AND `map` = 751 AND `spawntimesecs` = 300 AND `guid` IN (16720993, 16721030, 16721033,
    16721034, 16721037, 16721074, 16721076, 16721135, 16721136);

-- Verification, to run after applying (expected values in the labels):
--   SELECT 'quests (want 6)' AS `check`, COUNT(*) AS `n` FROM `quest_template` WHERE `ID` BETWEEN 751051 AND 751056
--   UNION ALL SELECT 'givers (want 6)', COUNT(*) FROM `creature_queststarter` WHERE `quest` BETWEEN 751051 AND 751056
--   UNION ALL SELECT 'enders (want 6)', COUNT(*) FROM `creature_questender` WHERE `quest` BETWEEN 751051 AND 751056
