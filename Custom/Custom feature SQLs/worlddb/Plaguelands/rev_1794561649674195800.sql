-- DarkChaos: the Tyr's Hand quests of map 751 (Eastern Plaguelands) - kill credit for Soft Landing, band rewards and
-- gold for ten quests, and their quest map markers
--
-- Why bots finished none of 27460, 27614, 27615, 27616 and 27619 in the 2026-11-13 run: every objective of these
-- quests lies inside the Scarlet garrison of Tyr's Hand, and on 751 that garrison is 166 level-160 elites (Scarlet
-- Warder, Praetorian, Cleric, Curate, Archmage and Enchanter 3609447-3609452, plus Abbendis, Valdelmar and two
-- Inquisitors), carried over from the classic elite area. The quests start at level 150, and each target (the four
-- level-154 named Scarlet officers and the four Battered Chests) has 4 to 14 of those elites within 30 yards. Of the
-- 25 bots traced in Playerbots.log after they took the quests, 22 died (69 deaths, mostly three each) before the
-- level manager moved them away. No bot stayed five minutes at a target, so no abandon was recorded either. Players
-- at level 150-158 meet the same wall. Whether Tyr's Hand stays an elite area or becomes the Cata normal-mob quest
-- hub is a design decision, so this file does NOT change the garrison.
--
-- What this file fixes:
-- 1. 27460 Soft Landing asks for 10 "Tyr's Hand Scarlet Crusader slain", which is 3609447 Scarlet Warder. In
--    cata_world the five other Tyr's Hand Scarlet types carry KillCredit1 = 9447, so any of them counts. On 751 only
--    the 32 Warders counted. KillCredit1 = 3609447 is set on 3609448-3609452, which adds 130 spawns, all on 751 only.
--    No other quest asks for any of these six entries, and a kill still credits the creature's own entry as well.
-- 2. The reward choices of 27613 The Assassin and 27619 The Commander were the Cata placeholders 62966-62971 (item
--    level 0 or 23, no stats). They now point at the green item of the same slot, armour type and quality from the
--    map 751 drop ladder, band 152 (Eastern Plaguelands, item level 496, required level 152), as 27620 already does.
--      27613: 62968 plate legs -> 421630, 62967 leather head -> 421610, 62966 trinket -> 421638
--      27619: 62971 plate feet -> 421631, 62970 mail head -> 421618, 62969 ring -> 421637
--    The placeholder items themselves are not changed.
-- 3. RewardMoney of the ten quests was still the Cata value (6 to 55 silver). It is set by the 11-10 formula, band
--    midpoint x 900 copper x the RewardXPDifficulty ratio, and only ever raised:
--      Eastern Plaguelands band 152-160, midpoint 156: difficulty 5 = 140400 (27613, 27614, 27615, 27616, 27619)
--      and difficulty 1 = 14040 (27461, 27462, 27617, 27618).
--      Western Plaguelands band 148-153, midpoint 150.5: difficulty 5 = 135450 (27166 Go Fletch!).
-- 4. Quest map markers. None of the ten had a quest_poi row. The objective markers are the cata_world ones (map
--    0 -> 751, world map area 23 -> 1217 and 22 -> 1268, as in rev_1794429413835942600.sql). The turn-in markers are
--    NOT taken from Cata: there Eligor, Korfax and Dosantos stand inside Tyr's Hand (1740,-5380 / 1657,-5325 /
--    1679,-5355), but on 751 they stand at its north edge (about 1692,-5213), so each turn-in marker is the live 751
--    spawn of the quest's turn-in NPC. A marker 170 yards off would also send bots into the garrison to look for the
--    NPC. 19 quest_poi rows and 26 quest_poi_points rows.
--
-- Every UPDATE is guarded by the values it replaces (and by QuestLevel -1, set by rev_1794431829690775000.sql), and
-- the markers are deleted and re-inserted for exactly these ten quests, which had none. Re-running changes nothing.
-- Revert: KillCredit1 back to 0 on 3609448-3609452, the six reward choices back to 62966-62971 in the order above,
-- RewardMoney back to 5500 (27613-27616, 27619), 600 (27461, 27462, 27617, 27618) and 4000 (27166), and delete the
-- quest_poi and quest_poi_points rows of the ten quests.
-- Apply to acore_world, then restart the worldserver.

-- 1. Soft Landing: every Tyr's Hand Scarlet type counts, as in Cata
UPDATE `creature_template` SET `KillCredit1` = 3609447
WHERE `entry` IN (3609448, 3609449, 3609450, 3609451, 3609452) AND `KillCredit1` = 0
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37);

-- 2. Reward choices: Cata placeholders -> band 152 ladder greens of the same slot and armour type
UPDATE `quest_template` SET `RewardChoiceItemID1` = 421630, `RewardChoiceItemID2` = 421610,
    `RewardChoiceItemID3` = 421638
WHERE `ID` = 27613 AND `RewardChoiceItemID1` = 62968 AND `RewardChoiceItemID2` = 62967
  AND `RewardChoiceItemID3` = 62966;
UPDATE `quest_template` SET `RewardChoiceItemID1` = 421631, `RewardChoiceItemID2` = 421618,
    `RewardChoiceItemID3` = 421637
WHERE `ID` = 27619 AND `RewardChoiceItemID1` = 62971 AND `RewardChoiceItemID2` = 62970
  AND `RewardChoiceItemID3` = 62969;

-- 3. Gold by the band formula, only raised
UPDATE `quest_template` SET `RewardMoney` = 140400
WHERE `ID` IN (27613, 27614, 27615, 27616, 27619) AND `RewardXPDifficulty` = 5 AND `QuestLevel` = -1
  AND `RewardMoney` < 140400;
UPDATE `quest_template` SET `RewardMoney` = 14040
WHERE `ID` IN (27461, 27462, 27617, 27618) AND `RewardXPDifficulty` = 1 AND `QuestLevel` = -1
  AND `RewardMoney` < 14040;
UPDATE `quest_template` SET `RewardMoney` = 135450
WHERE `ID` = 27166 AND `RewardXPDifficulty` = 5 AND `QuestLevel` = -1 AND `RewardMoney` < 135450;

-- 4. Quest map markers: objectives from cata_world, turn-ins at the 751 turn-in NPC
-- (Eligor 3616115 at 1691,-5212, Korfax 3616112 at 1694,-5211, Dosantos 3616116 at 1693,-5216, Valorfist 3610838
-- at 957,-1418). Objective index 4-7 is the item objective, as in AzerothCore.
DELETE FROM `quest_poi` WHERE `QuestID` IN (27166, 27461, 27462, 27613, 27614, 27615, 27616, 27617, 27618, 27619);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`) VALUES
(27166, 0, 4, 751, 1268, 0, 0, 1, 0),
(27166, 1, -1, 751, 1268, 0, 0, 1, 0),
(27461, 0, -1, 751, 1217, 0, 0, 1, 0),
(27462, 0, -1, 751, 1217, 0, 0, 1, 0),
(27613, 0, 0, 751, 1217, 0, 0, 1, 0),
(27613, 1, -1, 751, 1217, 0, 0, 1, 0),
(27614, 0, 4, 751, 1217, 0, 0, 1, 0),
(27614, 1, 5, 751, 1217, 0, 0, 1, 0),
(27614, 2, 6, 751, 1217, 0, 0, 1, 0),
(27614, 3, 7, 751, 1217, 0, 0, 1, 0),
(27614, 4, -1, 751, 1217, 0, 0, 1, 0),
(27615, 0, 0, 751, 1217, 0, 0, 1, 0),
(27615, 1, -1, 751, 1217, 0, 0, 1, 0),
(27616, 0, 0, 751, 1217, 0, 0, 1, 0),
(27616, 1, -1, 751, 1217, 0, 0, 1, 0),
(27617, 0, -1, 751, 1217, 0, 0, 1, 0),
(27618, 0, -1, 751, 1217, 0, 0, 1, 0),
(27619, 0, 0, 751, 1217, 0, 0, 1, 0),
(27619, 1, -1, 751, 1217, 0, 0, 1, 0);

DELETE FROM `quest_poi_points` WHERE `QuestID` IN (27166, 27461, 27462, 27613, 27614);
DELETE FROM `quest_poi_points` WHERE `QuestID` IN (27615, 27616, 27617, 27618, 27619);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(27166, 0, 0, 1052, -1468, 0),
(27166, 0, 1, 1078, -1451, 0),
(27166, 0, 2, 1238, -1127, 0),
(27166, 0, 3, 1319, -941, 0),
(27166, 0, 4, 1305, -920, 0),
(27166, 0, 5, 1022, -1150, 0),
(27166, 0, 6, 997, -1239, 0),
(27166, 0, 7, 967, -1378, 0),
(27166, 1, 0, 957, -1418, 0),
(27461, 0, 0, 1691, -5212, 0),
(27462, 0, 0, 1694, -5211, 0),
(27613, 0, 0, 1751, -5417, 0),
(27613, 1, 0, 1691, -5212, 0),
(27614, 0, 0, 1643, -5302, 0),
(27614, 1, 0, 1599, -5280, 0),
(27614, 2, 0, 1580, -5315, 0),
(27614, 3, 0, 1621, -5346, 0),
(27614, 4, 0, 1694, -5211, 0),
(27615, 0, 0, 1600, -5307, 0),
(27615, 1, 0, 1694, -5211, 0),
(27616, 0, 0, 1623, -5288, 0),
(27616, 1, 0, 1694, -5211, 0),
(27617, 0, 0, 1693, -5216, 0),
(27618, 0, 0, 1693, -5216, 0),
(27619, 0, 0, 1600, -5306, 0),
(27619, 1, 0, 1694, -5211, 0);

-- Verify after apply (expected values in brackets):
--   SELECT COUNT(*) FROM `creature_template` WHERE `entry` BETWEEN 3609448 AND 3609452
--     AND `KillCredit1` = 3609447                                                                            [5]
--   SELECT `RewardChoiceItemID1`, `RewardChoiceItemID2`, `RewardChoiceItemID3` FROM `quest_template`
--     WHERE `ID` IN (27613, 27619)                                       [421630 421610 421638 / 421631 421618 421637]
--   SELECT `ID`, `RewardMoney` FROM `quest_template` WHERE `ID` IN (27166, 27461, 27462, 27613, 27614, 27615, 27616,
--     27617, 27618, 27619)                                                     [135450, 14040 x4, 140400 x5]
--   SELECT COUNT(*) FROM `quest_poi` WHERE `QuestID` IN (27166, 27461, 27462, 27613, 27614, 27615, 27616, 27617,
--     27618, 27619)                                                                                         [19]
--   SELECT COUNT(*) FROM `quest_poi_points` WHERE `QuestID` IN (27166, 27461, 27462, 27613, 27614, 27615, 27616,
--     27617, 27618, 27619)                                                                                  [26]
