-- DC: Add missing quest_template rows for daily/weekly dungeon quests

DELETE FROM `quest_template`
WHERE `ID` IN (700101,700102,700103,700104,700201,700202,700203,700204);

INSERT INTO `quest_template`
(
  `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
  `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `Flags`,
  `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`
)
VALUES
-- Daily quests (Flags 0x0800)
(700101, 2, 80, 80, 0, 0, 0, 0, 0, 0, 0x0800,
 'Daily Dungeon Quest: Explorer I',
 'Complete todays daily dungeon quest and return for your reward.',
 'Complete the daily dungeon challenge and report back to the Quest Master.',
 'Daily dungeon quest completed.'),
(700102, 2, 80, 80, 0, 0, 0, 0, 0, 0, 0x0800,
 'Daily Dungeon Quest: Explorer II',
 'Complete todays daily dungeon quest and return for your reward.',
 'Complete the daily dungeon challenge and report back to the Quest Master.',
 'Daily dungeon quest completed.'),
(700103, 2, 80, 80, 0, 0, 0, 0, 0, 0, 0x0800,
 'Daily Dungeon Quest: Explorer III',
 'Complete todays daily dungeon quest and return for your reward.',
 'Complete the daily dungeon challenge and report back to the Quest Master.',
 'Daily dungeon quest completed.'),
(700104, 2, 80, 80, 0, 0, 0, 0, 0, 0, 0x0800,
 'Daily Dungeon Quest: Explorer IV',
 'Complete todays daily dungeon quest and return for your reward.',
 'Complete the daily dungeon challenge and report back to the Quest Master.',
 'Daily dungeon quest completed.'),
-- Weekly quests (Flags 0x1000)
(700201, 2, 80, 80, 0, 0, 0, 0, 0, 0, 0x1000,
 'Weekly Dungeon Quest: Specialist I',
 'Complete this weeks weekly dungeon quest and return for your reward.',
 'Complete the weekly dungeon challenge and report back to the Quest Master.',
 'Weekly dungeon quest completed.'),
(700202, 2, 80, 80, 0, 0, 0, 0, 0, 0, 0x1000,
 'Weekly Dungeon Quest: Specialist II',
 'Complete this weeks weekly dungeon quest and return for your reward.',
 'Complete the weekly dungeon challenge and report back to the Quest Master.',
 'Weekly dungeon quest completed.'),
(700203, 2, 80, 80, 0, 0, 0, 0, 0, 0, 0x1000,
 'Weekly Dungeon Quest: Specialist III',
 'Complete this weeks weekly dungeon quest and return for your reward.',
 'Complete the weekly dungeon challenge and report back to the Quest Master.',
 'Weekly dungeon quest completed.'),
(700204, 2, 80, 80, 0, 0, 0, 0, 0, 0, 0x1000,
 'Weekly Dungeon Quest: Specialist IV',
 'Complete this weeks weekly dungeon quest and return for your reward.',
 'Complete the weekly dungeon challenge and report back to the Quest Master.',
 'Weekly dungeon quest completed.');
