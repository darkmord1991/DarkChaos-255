-- Naxxramas (map 2921) -- `.tele naxxramas` command entry.
-- Coordinates are the zone's WorldMapArea bbox center; verify/adjust ground height once
-- maps/vmaps exist for map 2921.
DELETE FROM `game_tele` WHERE `id` = 10616;
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
    (10616, 3200.0, -4266.667, 100.0, 0, 2921, 'DCNaxxramas');
