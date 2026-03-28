-- Hinterland BG daily/weekly quests and quest giver wiring.
-- Uses custom kill-credit creature entries granted by HLBG match-end script:
--   920102 = win credit
--   920103 = participation credit

-- Ensure the HLBG battlemaster can also offer/complete quests.
UPDATE `creature_template`
SET `npcflag` = `npcflag` | 2
WHERE `entry` = 900001;

-- Hidden credit creature templates used by KilledMonsterCredit.
DELETE FROM `creature_template` WHERE `entry` IN (920102, 920103);
INSERT INTO `creature_template`
(
	`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`,
	`npcflag`, `speed_walk`, `speed_run`, `unit_class`, `type`,
	`HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`,
	`RegenHealth`, `VerifiedBuild`
)
VALUES
(920102, 'HLBG Daily Win Credit', 'Hidden Quest Credit', 1, 1, 2, 35, 0, 1, 1.14286, 1, 7, 1, 1, 1, 1, 1, 12340),
(920103, 'HLBG Weekly Participation Credit', 'Hidden Quest Credit', 1, 1, 2, 35, 0, 1, 1.14286, 1, 7, 1, 1, 1, 1, 1, 12340);

-- Daily + weekly HLBG quests.
DELETE FROM `quest_template` WHERE `ID` IN (920100, 920101);
INSERT INTO `quest_template`
(
	`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
	`RewardXPDifficulty`, `RewardMoney`, `Flags`,
	`LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`,
	`RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`
)
VALUES
(
	920100, 2, 80, 80, 25, 0, 0,
	0, 250000, 0x0800,
	'Hinterland Daily: Claim Victory',
	'Win one Hinterland Battleground match.',
	'Fight in the Hinterlands and secure a victory for your faction.',
	'Daily objective complete: victory achieved in Hinterland BG.',
	920102, 1
),
(
	920101, 2, 80, 80, 25, 0, 0,
	0, 1000000, 0x1000,
	'Hinterland Weekly: Frontline Duty',
	'Participate in five Hinterland Battleground matches.',
	'The war effort needs veterans. Complete five Hinterland BG matches this week.',
	'Weekly objective complete: frontline duty fulfilled.',
	920103, 5
);

-- Bind both quests to the HLBG battlemaster (entry 900001).
DELETE FROM `creature_queststarter` WHERE `id` = 900001 AND `quest` IN (920100, 920101);
DELETE FROM `creature_questender` WHERE `id` = 900001 AND `quest` IN (920100, 920101);

INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(900001, 920100),
(900001, 920101);

INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(900001, 920100),
(900001, 920101);
