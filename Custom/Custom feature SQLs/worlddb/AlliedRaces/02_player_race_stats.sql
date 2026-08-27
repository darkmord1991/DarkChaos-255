-- Allied races: racial base stats
-- Vulpera small/agile, Zandalari strong, Kul Tiran heavy-set.
DELETE FROM `player_race_stats` WHERE `Race` IN (24, 25, 26);
INSERT INTO `player_race_stats` (`Race`, `Strength`, `Agility`, `Stamina`, `Intellect`, `Spirit`) VALUES
(24, -3,  3,  0,  1, -1),
(25,  2,  1,  1, -2, -2),
(26,  3, -2,  2, -2, -1);
