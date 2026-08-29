-- Timbermaw Hold (map 819) -- `.tele dctimbermaw` / `.tele dctimbermawgate` command entries.
--
-- dctimbermaw     = a GM shortcut into the raid, placed IN GAME and read back out (id 10643).
-- dctimbermawgate = the world-side entrance on map 750, at the Timbermaw Hold furbolg camp.
--
-- The id this file originally claimed for dctimbermaw (10640) was never taken -- the live row
-- was added in game and landed on 10643 -- so the file now writes the live id. Its position is
-- likewise the live one and is NOT the same spot as the player-facing arrival point: the
-- gossip teleport and areatrigger 6923 both land at -8153.15/-3456.87/222.4, which was
-- measured with `.gps` and is confirmed working in both directions. Do not "reconcile" the two;
-- this row is a convenience, that one is the door.
--
-- DELETE covers the NAMES as well as the ids, so a stale 10640 row from an earlier run of this
-- file cannot leave `.tele dctimbermaw` ambiguous between two rows.
DELETE FROM `game_tele` WHERE `id` IN (10640, 10641, 10643) OR `name` IN ('dctimbermaw', 'dctimbermawgate');
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
    (10643, -7902.56, -3434.49, 250.701, 3.21621, 819, 'dctimbermaw'),
    (10641, 7015.0, -2145.0, 587.0, 0, 750, 'dctimbermawgate');
