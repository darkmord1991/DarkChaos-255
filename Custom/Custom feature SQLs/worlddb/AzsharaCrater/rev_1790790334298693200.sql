-- Azshara Crater (map 37): the starting tent (Innkeeper Fizzgrimble) becomes an inn / rest area.
-- Box = the indoor group of TaurenHutBig.wmo (PVPZone02_30_31.adt, placed at 103.42 1035.65 296.20, yaw 141.5)
-- mapped to world space and padded 1.5 yd per side; long axis along the orientation.
-- The client only sends CMSG_AREATRIGGER for ids in its own AreaTrigger.dbc, so this needs
-- AreaTrigger.dbc row 6962 (Custom/CSV DBC/AreaTrigger.csv) in patch-4, patch-enGB-3 and patch-enGB-4.
DELETE FROM `areatrigger` WHERE `entry` = 6962;
INSERT INTO `areatrigger` (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
(6962, 37, 104.18, 1035.24, 308.2, 0, 60, 28, 28, 0.8988);

DELETE FROM `areatrigger_tavern` WHERE `id` = 6962;
INSERT INTO `areatrigger_tavern` (`id`, `name`, `faction`) VALUES
(6962, 'Azshara Crater - Starting Tent', 6);
