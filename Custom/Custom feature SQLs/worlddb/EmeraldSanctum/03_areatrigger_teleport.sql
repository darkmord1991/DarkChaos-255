-- Emerald Sanctum (map 824) -- walk-in entrance.
--
-- The trigger BOX lives in AreaTrigger.dbc id 607007 (added to Custom/CSV DBC/AreaTrigger.csv
-- by Custom/TurtleDungeons/add_turtle_dungeon_dbc_rows.py, already compiled and deployed to
-- patch-4 and the three WarcraftXLHost candidate dirs). It must also reach the SERVER's
-- data/dbc before this row does anything.
--
-- No exit trigger, on purpose -- see the matching note in CrescentGrove/03. The way out is the
-- Emerald Sanctum Warden (3999008), from _shared/dungeon_entrance_npcs.sql.
--
-- The box sits at Turtle's own entrance x/y with OUR Z (1190.27, computed from the deployed
-- map-750 terrain). Turtle's 1158.0 comes from vanilla Hyjal and is 32 yd underground here.
-- Expect this one to need a look in game before anything else in the import does: unlike
-- Crescent Grove, whose Ashenvale hillside survived the Cataclysm mostly intact, map 750's
-- Hyjal is a completely rebuilt zone, so "the same coordinates" is a much weaker claim.
DELETE FROM `areatrigger_teleport` WHERE `ID` = 607007;
INSERT INTO `areatrigger_teleport` (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`) VALUES
    (607007, 'Emerald Sanctum (Entrance)', 824, 2767.4, 2959.0, 30.10, 0.785);
