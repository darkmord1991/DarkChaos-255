-- Custom races: second language from the parent race, as the client tables carry it.
-- Dark Iron (27) Dwarven, Zandalari (25) and Drakkari (28) Troll, Void Elf (29) Thalassian,
-- Lightforged (30) Draenei. The language skill comes from playercreateinfo_skills (existing characters
-- get it at their next login, Player::LearnDefaultSkills), the language spell from the SkillLineAbility
-- row, and SkillRaceClassInfo moves the race from the 'every other race' row to the language's own row.
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 67108864 WHERE `skill` = 111;
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 268435456 WHERE `skill` = 137;
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 150994944 WHERE `skill` = 315;
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 536870912 WHERE `skill` = 759;

DELETE FROM `skilllineability_dbc` WHERE `ID` IN (594, 727, 4247, 14260);
INSERT INTO `skilllineability_dbc` (`ID`, `SkillLine`, `Spell`, `RaceMask`, `ClassMask`, `ExcludeRace`,
    `ExcludeClass`, `MinSkillLineRank`, `SupercededBySpell`, `AcquireMethod`, `TrivialSkillLineRankHigh`,
    `TrivialSkillLineRankLow`, `CharacterPoints_1`, `CharacterPoints_2`) VALUES
(594, 111, 672, 67108868, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),
(727, 137, 813, 268435968, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),
(4247, 315, 7341, 150995072, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),
(14260, 759, 29932, 536871936, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0);

DELETE FROM `skillraceclassinfo_dbc` WHERE `ID` IN (44, 45, 52, 53, 91, 875, 876, 882);
INSERT INTO `skillraceclassinfo_dbc` (`ID`, `SkillID`, `RaceMask`, `ClassMask`, `Flags`, `MinLevel`,
    `SkillTierID`, `SkillCostIndex`) VALUES
(44, 111, 67108868, 1535, 128, 0, 0, 0),
(45, 111, 2078281723, 1503, 160, 0, 21, 0),
(52, 315, 150995072, 1535, 128, 0, 0, 0),
(53, 315, 1994395519, 1503, 160, 0, 21, 0),
(91, 137, 1876954623, 1503, 160, 0, 21, 0),
(875, 759, 536871936, 262143, 128, 0, 0, 0),
(876, 759, 1608518655, -1, 0, 0, 21, 0),
(882, 137, 268435968, 1535, 128, 0, 0, 0);
