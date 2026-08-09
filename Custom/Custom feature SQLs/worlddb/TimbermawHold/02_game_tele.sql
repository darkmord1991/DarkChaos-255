-- Timbermaw Hold (map 819) -- `.tele dctimbermaw` / `.tele dctimbermawgate` command entries.
--
-- ids 10640/10641: live max is 10632, and 10633-10639 are reserved by the pending map-750
-- round-51 batch (dclordanel/dcbilgewater/...), so this block starts above that reservation.
--
-- dctimbermaw     = the raid's arrival point, WMO group 1 "EntranceMeetingRoom02".
-- dctimbermawgate = the world-side entrance on map 750, at the Timbermaw Hold furbolg camp.
--
-- Both Z values are DERIVED, not measured: the raid point comes from the WMO group bounding
-- box (floor 219.5, so 221.0 sits just above it) and the gate point from the average ground
-- height of the 31 map-750 spawns in that camp (586.15-602.83, mean 587.44). Verify both with
-- `.gps` once maps/vmaps exist for map 819 and adjust if GroundZ != FloorZ.
DELETE FROM `game_tele` WHERE `id` IN (10640, 10641);
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
    (10640, -8153.15, -3456.87, 222.4, 0.306, 819, 'dctimbermaw'),
    (10641, 7015.0, -2145.0, 587.0, 0, 750, 'dctimbermawgate');
