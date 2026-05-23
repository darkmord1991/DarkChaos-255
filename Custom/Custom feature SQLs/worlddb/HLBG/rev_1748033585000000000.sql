DELETE FROM `battleground_template` WHERE `ID` = 20;
INSERT INTO `battleground_template` (`ID`, `MinPlayersPerTeam`, `MaxPlayersPerTeam`, `MinLvl`, `MaxLvl`, `AllianceStartLoc`, `AllianceStartO`, `HordeStartLoc`, `HordeStartO`, `StartMaxDist`, `Weight`, `ScriptName`, `Comment`) VALUES
(20, 1, 10, 71, 80, 1721, 3.046, 1722, 1.125, 25, 1, '', 'Hinterland BG (battleground bootstrap)');

DELETE FROM `battlemaster_entry` WHERE `entry` = 900001;
INSERT INTO `battlemaster_entry` (`entry`, `bg_template`) VALUES
(900001, 20);

UPDATE `creature_template`
SET `npcflag` = `npcflag` | 1048576
WHERE `entry` = 900001;