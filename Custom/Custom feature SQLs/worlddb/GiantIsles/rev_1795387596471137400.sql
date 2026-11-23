-- Nalak the Storm Lord (400102, boss_nalak): speech for the 7 text groups the script talks
-- (boss_nalak.cpp NalakTexts). The script shipped without any creature_text rows, so every
-- Talk() logged "Could not find Text for Creature(Nalak the Storm Lord)" in Errors.log.
-- Type 14 = yell, Language 0 = universal, no tokens ($n/$r need a target), ASCII only.
DELETE FROM `creature_text` WHERE `CreatureID` = 400102;
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
-- 0 SAY_AGGRO
(400102, 0, 0, 'The storm hungers! Come closer, little ones, and be devoured by the thunder!', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Aggro'),
(400102, 0, 1, 'Who dares walk beneath my sky? The lightning will answer for me!', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Aggro'),
(400102, 0, 2, 'I was old when your kind crawled from the mud. Kneel before the Storm Lord!', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Aggro'),
-- 1 SAY_ARC_NOVA
(400102, 1, 0, 'Feel the sky break!', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Arc Nova'),
(400102, 1, 1, 'Scatter, or be scorched by the storm!', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Arc Nova'),
-- 2 SAY_TETHER
(400102, 2, 0, 'The lightning binds you together! Burn as one!', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Lightning Tether'),
(400102, 2, 1, 'You cannot run from the storm. It will chain you to your fate!', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Lightning Tether'),
-- 3 SAY_STORM
(400102, 3, 0, 'Gather, clouds! Drown them in thunder!', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Storm Cloud'),
(400102, 3, 1, 'The storm answers my call!', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Storm Cloud'),
-- 4 SAY_BERSERK
(400102, 4, 0, 'Enough! Let the storm tear this isle apart, and you with it!', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Berserk'),
-- 5 SAY_DEATH
(400102, 5, 0, 'The thunder fades... but the storm... always returns...', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Death'),
-- 6 SAY_KILL (30% chance per player kill in the script)
(400102, 6, 0, 'Struck down, like all who defy the storm.', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Kill'),
(400102, 6, 1, 'Another spark snuffed out.', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Kill'),
(400102, 6, 2, 'Rest now. The thunder will remember you.', 14, 0, 100, 0, 0, 0, 0, 0, 'Nalak the Storm Lord - Kill');
