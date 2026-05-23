-- DB update 2026_05_20_00 -> 2026_05_23_00
-- HLBG stock queue bootstrap depends on battleground_template row 20.
DELETE FROM `battleground_template` WHERE `ID` = 20;
INSERT INTO `battleground_template` (`ID`, `MinPlayersPerTeam`, `MaxPlayersPerTeam`, `MinLvl`, `MaxLvl`, `AllianceStartLoc`, `AllianceStartO`, `HordeStartLoc`, `HordeStartO`, `StartMaxDist`, `Weight`, `ScriptName`, `Comment`) VALUES
(20, 1, 10, 71, 80, 1721, 3.046, 1722, 1.125, 25, 1, '', 'Hinterland BG (battleground bootstrap)');