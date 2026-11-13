-- DC: rested XP for the 18 inns on map 751 (DCPlaguelands). Tavern areatriggers 6985-7002.
-- Client side: matching AreaTrigger.dbc rows, inserted inside the map 751 scan run (Custom/CSV DBC/AreaTrigger.csv).
-- faction mask: 2 = Alliance, 4 = Horde, 6 = both (ObjectMgr::IsTavernAreaTrigger, player original team).
DELETE FROM `areatrigger` WHERE `entry` BETWEEN 6985 AND 7002;
INSERT INTO `areatrigger` (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
(6985, 751, 2302.5, -5341, 90.7519, 0, 29, 17.9, 24.56, 2.394),
(6986, 751, 945.431, -1448.39, 63.3995, 0, 12, 12, 10, 0.02422),
(6987, 751, 1538.97, -1670.33, 67.354, 0, 44.28, 42.14, 30, 0.06273),
(6988, 751, 1642.18, 219.68, -37.53, 0, 22.14, 19.04, 17.2, 6.2745),
(6989, 751, 1668.09, -721.715, 58.9155, 0, 9.208, 15.53, 10, 5.746),
(6990, 751, 2303.72, 279.352, 30, 25, 0, 0, 0, 0),
(6991, 751, 465.02, 1487.89, 134.96, 0, 44.28, 42.14, 30, 5.7612),
(6992, 751, 1096.38, 1583.06, 34.87, 0, 16.23, 18.79, 30.62, 3.3859),
(6993, 751, -612.37, -1045.95, 65.83, 15, 0, 0, 0, 0),
(6994, 751, -500.911, 111.667, 56.8404, 15, 0, 0, 0, 0),
(6995, 751, -58.2847, -979.064, 53.4992, 0, 40.22, 54.47, 40.58, 5.829),
(6996, 751, -28.2, -321.2, 131.22, 15, 0, 0, 0, 0),
(6997, 751, -622.142, -4582.14, 21, 0, 27.39, 27.17, 21.64, 3.194),
(6998, 751, -31.3333, -2808.71, 122.411, 0, 42, 58, 10, 5.52),
(6999, 751, 357.22, -2106.09, 121.839, 60, 0, 0, 0, 0),
(7000, 751, 340.186, -4128, 120, 24, 0, 0, 0, 0),
(7001, 751, -1282.58, -2513.56, 21.5488, 5, 0, 0, 0, 0),
(7002, 751, -907.865, -3534.24, 83.7878, 30, 0, 0, 0, 0);

DELETE FROM `areatrigger_tavern` WHERE `id` BETWEEN 6985 AND 7002;
INSERT INTO `areatrigger_tavern` (`id`, `name`, `faction`) VALUES
(6985, 'DCPlaguelands - Light''s Hope Chapel', 6),
(6986, 'DCPlaguelands - Chillwind Camp', 2),
(6987, 'DCPlaguelands - Andorhal', 4),
(6988, 'DCPlaguelands - Undercity', 4),
(6989, 'DCPlaguelands - The Bulwark', 4),
(6990, 'DCPlaguelands - Brill - Gallows'' End Tavern', 4),
(6991, 'DCPlaguelands - The Sepulcher', 4),
(6992, 'DCPlaguelands - Forsaken Rear Guard', 4),
(6993, 'DCPlaguelands - Eastpoint Tower', 4),
(6994, 'DCPlaguelands - The Sludge Fields', 4),
(6995, 'DCPlaguelands - Tarren Mill', 4),
(6996, 'DCPlaguelands - Stormpike camp', 2),
(6997, 'DCPlaguelands - Revantusk Village', 4),
(6998, 'DCPlaguelands - Hiri''watha Research Station', 4),
(6999, 'DCPlaguelands - Aerie Peak', 2),
(7000, 'DCPlaguelands - Stormfeather Outpost', 2),
(7001, 'DCPlaguelands - Refuge Pointe', 2),
(7002, 'DCPlaguelands - Hammerfall', 4);
