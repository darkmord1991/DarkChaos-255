-- Hinterland BG: four more battleground quests, rewards for the existing two, and quest texts.
--
-- Existing: 920100 Daily "Claim Victory" (win 1) and 920101 Weekly "Frontline Duty" (play 5) at the
-- Hinterlands Battlemaster (900001). Both paid gold only, their quest log objective showed the hidden
-- credit creature's name, and their turn-in windows were empty.
--
-- New. Credit is granted by BattlegroundHLBG.cpp, so it can only be earned inside the battleground:
--   920104 Daily  "Blood on the Coast"   slay 10 enemy players    credit 920111, killer
--   920105 Daily  "Break Their Line"     slay 15 enemy guards     credit 920112, killer
--   920106 Daily  "Topple the Warlord"   defeat the enemy leader  credit 920113, every eligible player of the killing side
--   920107 Weekly "Hinterland Conqueror" win 3 matches            credit 920102, the existing win credit
-- Guard and leader credit is not granted while the Skirmish affix is active (its rule is "players only").
-- AFK-flagged players and deserters never receive credit.
--
-- Rewards are a first pass, to balance later: gold, honor and Emblem of Triumph (47241); weeklies add
-- DC Item Upgrade Tokens (300311). quest_template.RewardHonor is flat honor (QuestDef.cpp).

-- Hidden kill-credit creatures (never spawned; KilledMonsterCredit only needs the entry).
DELETE FROM `creature_template` WHERE `entry` IN (920111, 920112, 920113);
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `unit_class`, `type`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RegenHealth`, `VerifiedBuild`) VALUES
(920111, 'HLBG Enemy Player Credit', 'Hidden Quest Credit', 1, 1, 2, 35, 0, 1, 1.14286, 1, 7, 1, 1, 1, 1, 1, 12340),
(920112, 'HLBG Enemy Guard Credit', 'Hidden Quest Credit', 1, 1, 2, 35, 0, 1, 1.14286, 1, 7, 1, 1, 1, 1, 1, 12340),
(920113, 'HLBG Enemy Leader Credit', 'Hidden Quest Credit', 1, 1, 2, 35, 0, 1, 1.14286, 1, 7, 1, 1, 1, 1, 1, 12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (920111, 920112, 920113);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(920111, 0, 11686, 1, 1, 12340),
(920112, 0, 11686, 1, 1, 12340),
(920113, 0, 11686, 1, 1, 12340);

-- New quests.
DELETE FROM `quest_template` WHERE `ID` IN (920104, 920105, 920106, 920107);
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardHonor`, `Flags`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `ObjectiveText1`) VALUES
(920104, 2, 80, 80, 25, 0, 0, 0, 250000, 300, 0x1000, 47241, 1, 0, 0, 'Hinterland Daily: Blood on the Coast', 'Slay 10 enemy players in the Hinterland Battleground.', 'Every champion the enemy sends to the Hinterlands is one more blade pointed at our camp.$B$BCut them down on the coast, $N. Ten of them, and they will think twice before the next landing.', 'Return to the Hinterlands Battlemaster.', 920111, 10, 'Enemy players slain'),
(920105, 2, 80, 80, 25, 0, 0, 0, 250000, 300, 0x1000, 47241, 1, 0, 0, 'Hinterland Daily: Break Their Line', 'Slay 15 enemy guards in the Hinterland Battleground.', 'The enemy camp is only as strong as the guards who hold it.$B$BBreak through them. Fifteen will do, and their defence falls apart before their champions can regroup.', 'Return to the Hinterlands Battlemaster.', 920112, 15, 'Enemy guards slain'),
(920106, 2, 80, 80, 25, 0, 0, 0, 400000, 500, 0x1000, 47241, 2, 0, 0, 'Hinterland Daily: Topple the Warlord', 'Defeat the enemy faction leader in the Hinterland Battleground.', 'The enemy has sent its own leader to the Hinterlands.$B$BBring them down together with your side, $N. An army whose leader falls on the field loses its voice.', 'Return to the Hinterlands Battlemaster.', 920113, 1, 'Enemy leader defeated'),
(920107, 2, 80, 80, 25, 0, 0, 0, 1500000, 2500, 0x8000, 47241, 8, 300311, 3, 'Hinterland Weekly: Hinterland Conqueror', 'Win 3 Hinterland Battleground matches this week.', 'One victory is luck. Three is a campaign.$B$BWin three matches in the Hinterlands this week and the war council will learn your name, $N.', 'Return to the Hinterlands Battlemaster.', 920102, 3, 'Hinterland Battleground victories');

DELETE FROM `quest_template_addon` WHERE `ID` IN (920104, 920105, 920106, 920107);
INSERT INTO `quest_template_addon` (`ID`, `SpecialFlags`) VALUES
(920104, 1),
(920105, 1),
(920106, 1),
(920107, 1);

-- Existing quests: add honor and emblems, and a readable objective line.
UPDATE `quest_template` SET `RewardHonor` = 500, `RewardItem1` = 47241, `RewardAmount1` = 2, `ObjectiveText1` = 'Hinterland Battleground victory' WHERE `ID` = 920100;
UPDATE `quest_template` SET `RewardHonor` = 1500, `RewardItem1` = 47241, `RewardAmount1` = 5, `RewardItem2` = 300311, `RewardAmount2` = 2, `ObjectiveText1` = 'Hinterland Battleground matches completed' WHERE `ID` = 920101;

-- Turn-in texts for all six.
DELETE FROM `quest_request_items` WHERE `ID` IN (920100, 920101, 920104, 920105, 920106, 920107);
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`) VALUES
(920100, 1, 1, 'Has the Hinterlands seen your victory yet, $N?', 12340),
(920101, 1, 1, 'The front does not hold itself. How many matches have you fought this week?', 12340),
(920104, 1, 1, 'The coast is still crawling with enemy champions. How many have you cut down?', 12340),
(920105, 1, 1, 'Their guards still stand, $N. Break that line.', 12340),
(920106, 1, 1, 'Does the enemy leader still draw breath?', 12340),
(920107, 1, 1, 'A campaign is measured in victories, $N. Have you won enough of them?', 12340);

DELETE FROM `quest_offer_reward` WHERE `ID` IN (920100, 920101, 920104, 920105, 920106, 920107);
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`) VALUES
(920100, 1, 0, 0, 0, 0, 0, 0, 0, 'A victory in the Hinterlands. Take this, and be back tomorrow for the next one.', 12340),
(920101, 1, 0, 0, 0, 0, 0, 0, 0, 'Five matches on the front. That is the kind of duty the war effort runs on, $N.', 12340),
(920104, 1, 0, 0, 0, 0, 0, 0, 0, 'Ten fewer champions to worry about. Well fought, $N.', 12340),
(920105, 5, 0, 0, 0, 0, 0, 0, 0, 'Their line is broken. Take your reward before they rebuild it.', 12340),
(920106, 5, 0, 0, 0, 0, 0, 0, 0, 'The enemy leader fell on the field. That will be sung about tonight.', 12340),
(920107, 5, 0, 0, 0, 0, 0, 0, 0, 'Three victories in a single week. The war council knows your name now, $N.', 12340);

-- Quest giver and turn-in: the Hinterlands Battlemaster (map 745 hub).
DELETE FROM `creature_queststarter` WHERE `id` = 900001 AND `quest` IN (920104, 920105, 920106, 920107);
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(900001, 920104),
(900001, 920105),
(900001, 920106),
(900001, 920107);

DELETE FROM `creature_questender` WHERE `id` = 900001 AND `quest` IN (920104, 920105, 920106, 920107);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(900001, 920104),
(900001, 920105),
(900001, 920106),
(900001, 920107);
