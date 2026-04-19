-- Hyjal Frontier teleport destinations (.tele <name>)
-- Coordinates are placeholders taken from equivalent points on the CoT Hyjal
-- raid tileset; refine after the first Noggit pass on map 1410.

DELETE FROM `game_tele` WHERE `id` BETWEEN 1495 AND 1500;
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
(1495, 4634.0, -3786.0, 9425.0, 0.75, 1410, 'HyjalFrontier'),
(1496, 4600.0, -3760.0, 947.0, 1.55, 1410, 'HyjalFoothillsAlliance'),
(1498, 5050.0, -2800.0, 1473.0, 3.90, 1410, 'HyjalScorchedGroves'),
(1499, 5160.0, -3430.0, 1629.0, 0.78, 1410, 'HyjalTheSummit'),
(1500, 5370.0, -3380.0, 1659.0, 5.28, 1410, 'HyjalNordrassil');
