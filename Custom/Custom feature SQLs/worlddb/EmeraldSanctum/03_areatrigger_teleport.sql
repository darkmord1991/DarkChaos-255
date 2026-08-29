-- Emerald Sanctum (map 824) -- walk-in entrance.
--
-- The trigger BOX lives in AreaTrigger.dbc id 6928 (added to Custom/CSV DBC/AreaTrigger.csv
-- by Custom/TurtleDungeons/add_turtle_dungeon_dbc_rows.py, already compiled and deployed to
-- patch-4 and the three WarcraftXLHost candidate dirs). It must also reach the SERVER's
-- data/dbc before this row does anything.
--
-- No exit trigger, on purpose -- see the matching note in CrescentGrove/03. The way out is the
-- Emerald Sanctum Warden (3999008), from _shared/dungeon_entrance_npcs.sql.
--
-- RELOCATED 2026-08-29. Turtle's x/y put the box in the middle of Ashen Lake on this map:
-- ground 1190.27 under an MH2O surface at 1253.44, i.e. 63 yd of water, because map 750's
-- Hyjal is the CATA zone and Turtle authored the spot against map 1's vanilla one. The box
-- is now the Kalidar moon gate in the Grove of Aessina (5091.64/-1767.09/1332.97) --
-- see 18_relocate_entrance.sql. This row's TARGET (inside the raid) never changed.
DELETE FROM `areatrigger_teleport` WHERE `ID` = 6928;
INSERT INTO `areatrigger_teleport` (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`) VALUES
    (6928, 'Emerald Sanctum (Entrance)', 824, 2767.4, 2959.0, 30.10, 0.785);
