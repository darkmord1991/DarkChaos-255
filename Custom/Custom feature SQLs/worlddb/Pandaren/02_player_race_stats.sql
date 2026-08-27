-- Pandaren: racial base stats (MoP values: spirit-heavy, low agility)
DELETE FROM `player_race_stats` WHERE `Race` IN (22, 23);
INSERT INTO `player_race_stats` (`Race`, `Strength`, `Agility`, `Stamina`, `Intellect`, `Spirit`) VALUES
(22, 0, -2, 1, -1, 2),
(23, 0, -2, 1, -1, 2);
