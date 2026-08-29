-- Timbermaw Hold (map 819) -- walk-in entrance and return exit.
--
-- The trigger BOXES live in AreaTrigger.dbc (ids 6923/6924, added to
-- Custom/CSV DBC/AreaTrigger.csv by add_timbermaw_dbc_rows.py) and must be compiled +
-- deployed to the client before these rows do anything.
--
-- Entrance sits inside the Timbermaw Hold furbolg camp on map 750 -- the raid's own lore
-- location, and already populated there (Gorn One Eye 3711555, Kernda 3711558,
-- Meilosh 3711557, Salfa 3711556, Timbermaw Mystic 3711552 and 26 more spawns).
-- The source pack placed the exterior gate WMO in Azshara instead; that WMO is shipped
-- but deliberately NOT placed, because map 750 already has the real hold.
--
-- Both positions are PROVISIONAL -- see 02_game_tele.sql for how the Z values were derived.
DELETE FROM `areatrigger_teleport` WHERE `ID` IN (6923, 6924);
INSERT INTO `areatrigger_teleport` (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`) VALUES
    (6923, 'Timbermaw Hold (Entrance)', 819, -8153.15, -3456.87, 222.4, 0.306),
    (6924, 'Timbermaw Hold (Exit)', 750, 7015.0, -2145.0, 587.0, 3.14159);
