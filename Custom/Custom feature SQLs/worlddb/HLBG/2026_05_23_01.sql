-- DB update 2026_05_23_00 -> 2026_05_23_01
-- Harden custom battleground startup against missing custom runtime DBC rows.

DELETE FROM `game_graveyard` WHERE `ID` IN (1721, 1722);
INSERT INTO `game_graveyard` (`ID`, `Map`, `x`, `y`, `z`, `Comment`) VALUES
(1721, 1411, 197.165, -4808.544, 7.848, 'Hinterland BG - Alliance Start'),
(1722, 1411, -628.484, -4684.510, 5.144, 'Hinterland BG - Horde Start');

DELETE FROM `battlemasterlist_dbc` WHERE `ID` IN (20, 120);
INSERT INTO `battlemasterlist_dbc`
    (`ID`, `MapID_1`, `MapID_2`, `MapID_3`, `MapID_4`, `MapID_5`, `MapID_6`, `MapID_7`, `MapID_8`, `InstanceType`, `GroupsAllowed`,
     `Name_Lang_enUS`, `Name_Lang_enGB`, `Name_Lang_koKR`, `Name_Lang_frFR`, `Name_Lang_deDE`, `Name_Lang_enCN`, `Name_Lang_zhCN`,
     `Name_Lang_enTW`, `Name_Lang_zhTW`, `Name_Lang_esES`, `Name_Lang_esMX`, `Name_Lang_ruRU`, `Name_Lang_ptPT`, `Name_Lang_ptBR`,
     `Name_Lang_itIT`, `Name_Lang_Unk`, `Name_Lang_Mask`, `MaxGroupSize`, `HolidayWorldState`, `Minlevel`, `Maxlevel`)
VALUES
(20, 1411, -1, -1, -1, -1, -1, -1, -1, 3, 1,
 'Hinterland BG', 'Hinterland BG', 'Hinterland BG', 'Hinterland BG', '', '', 'Hinterland BG', 'Hinterland BG', 'Hinterland BG', '', '', '', '', '', '', '',
 16712190, 10, 0, 71, 80),
(120, 761, -1, -1, -1, -1, -1, -1, -1, 3, 1,
 'Battle for Gilneas', 'Battle for Gilneas', 'Battle for Gilneas', 'Battle for Gilneas', '', '', 'Battle for Gilneas', 'Battle for Gilneas', 'Battle for Gilneas', '', '', '', '', '', '', '',
 16712190, 10, 5360, 10, 80);