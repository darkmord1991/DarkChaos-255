-- Worgoblin: racial skill lines + weapon-skill fixes (mod-worgoblin)
DELETE FROM `playercreateinfo_skills` WHERE `raceMask` IN (256, 2048) AND `skill` IN (44, 54, 789, 790);
INSERT INTO `playercreateinfo_skills` (`raceMask`, `classMask`, `skill`, `rank`, `comment`) VALUES
(2048, 8, 44, 0, 'Axes - Worgen'),
(256, 8, 54, 0, 'Maces - Goblin'),
(2048, 0, 789, 0, 'Worgen - Racial'),
(256, 0, 790, 0, 'Goblin - Racial');
