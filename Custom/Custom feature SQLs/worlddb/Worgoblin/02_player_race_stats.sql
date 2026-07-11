-- Worgoblin: racial base stats (mod-worgoblin values)
DELETE FROM `player_race_stats` WHERE `Race` IN (9, 12);
INSERT INTO `player_race_stats` (`Race`, `Strength`, `Agility`, `Stamina`, `Intellect`, `Spirit`) VALUES
(9, -3, 2, 0, 3, -2),
(12, 3, 2, 0, -4, -1);
