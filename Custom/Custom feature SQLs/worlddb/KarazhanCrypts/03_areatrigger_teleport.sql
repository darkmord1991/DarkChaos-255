-- Karazhan Crypts (map 2875) -- walk-in entrance near Karazhan's grounds in Deadwind Pass
-- (map 0) and a return exit inside the dungeon. Trigger boxes (AreaTrigger.dbc ids 607000/607001)
-- are already compiled into Custom/DBCs/AreaTrigger.dbc and deployed to patch-4.MPQ.
-- Entrance placement is offset from Karazhan's own raid-entrance target (map 532 id 4131,
-- target -11100,-2003.98,49.89 / service entrance id 4135, target -11040.1,-1996.85,94.68) --
-- verify against the real building footprint once Noggit/in-game inspection is possible.
DELETE FROM `areatrigger_teleport` WHERE `ID` IN (607000, 607001);
INSERT INTO `areatrigger_teleport` (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`) VALUES
    (607000, 'Karazhan Crypts (Entrance)', 2875, -10666.0, -1866.0, 101.0, 0),
    (607001, 'Karazhan Crypts (Exit)', 0, -11080.0, -1975.0, 95.0, 0.577268);
