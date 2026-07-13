-- Karazhan Crypts (map 2875) -- `.tele karazhancrypts` command entry.
-- Coordinates are the dungeon's WorldMapArea bbox center; verify/adjust ground height once
-- maps/vmaps exist for map 2875.
DELETE FROM `game_tele` WHERE `id` = 10615;
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
    (10615, -10666.0, -1866.0, 100.0, 0, 2875, 'KarazhanCrypts');
