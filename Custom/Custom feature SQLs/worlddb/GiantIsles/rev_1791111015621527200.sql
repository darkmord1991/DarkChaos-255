-- Area triggers, 2026-10-04 (client side: AreaTrigger.dbc of the same deploy, which moves these rows into their
-- map's scan run - the client never tested them before, see the Isles of Giants cavern SQL).
--
-- 1. Isles of Giants temple cavern boxes 6965-6984: tell the player why they were moved. The C++ script
--    at_iog_temple_cavern_return (dc_giant_isles_sunken_temple.cpp) only shows the message and returns false, so
--    areatrigger_teleport still does the teleport. GMs skip trigger scripts: test with .gm off.
DELETE FROM `areatrigger_scripts` WHERE `entry` BETWEEN 6965 AND 6984;
INSERT INTO `areatrigger_scripts` (`entry`, `ScriptName`) VALUES
(6965, 'at_iog_temple_cavern_return'),
(6966, 'at_iog_temple_cavern_return'),
(6967, 'at_iog_temple_cavern_return'),
(6968, 'at_iog_temple_cavern_return'),
(6969, 'at_iog_temple_cavern_return'),
(6970, 'at_iog_temple_cavern_return'),
(6971, 'at_iog_temple_cavern_return'),
(6972, 'at_iog_temple_cavern_return'),
(6973, 'at_iog_temple_cavern_return'),
(6974, 'at_iog_temple_cavern_return'),
(6975, 'at_iog_temple_cavern_return'),
(6976, 'at_iog_temple_cavern_return'),
(6977, 'at_iog_temple_cavern_return'),
(6978, 'at_iog_temple_cavern_return'),
(6979, 'at_iog_temple_cavern_return'),
(6980, 'at_iog_temple_cavern_return'),
(6981, 'at_iog_temple_cavern_return'),
(6982, 'at_iog_temple_cavern_return'),
(6983, 'at_iog_temple_cavern_return'),
(6984, 'at_iog_temple_cavern_return');

-- 2. Timbermaw Hold (Exit) 6924 had a teleport row but no areatrigger row, so the server ignored it. Values = its
--    AreaTrigger.dbc row (map 819). Its arrival point sat on the entrance box 6923 (7015, -2145, 587), which would
--    have sent everyone straight back in: moved 8 yd north onto walkable ground (server navmesh), facing away.
DELETE FROM `areatrigger` WHERE `entry` = 6924;
INSERT INTO `areatrigger` (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
(6924, 819, -8165.96, -3459.75, 221, 0, 8, 8, 10, 0);
UPDATE `areatrigger_teleport` SET `target_position_x` = 7015, `target_position_y` = -2137, `target_position_z` = 587.6, `target_orientation` = 1.5708 WHERE `ID` = 6924;
