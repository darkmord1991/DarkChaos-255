-- Karazhan Crypts (map 2875) -- walk-in entrance near Karazhan's grounds in Deadwind Pass
-- (map 0) and a return exit inside the dungeon.
--
-- IDS: 6921 (entrance box, map 0) / 6922 (exit box, map 2875). These were authored as
-- 607000/607001 and renumbered by `_shared/renumber_areatrigger_ids.sql` -- the 3.3.5 client
-- keeps areatrigger ids in a 16-BIT table (0xFFFF = not found, Wow.exe VA 0x00831686), so
-- anything above 65535 indexed out of bounds and crashed it with ERROR #132 on map changes.
-- Both rows are already compiled into AreaTrigger.dbc and deployed to patch-4.MPQ.
--
-- Entrance placement is offset from Karazhan's own raid-entrance target (map 532 id 4131,
-- target -11100,-2003.98,49.89 / service entrance id 4135, target -11040.1,-1996.85,94.68) --
-- verify against the real building footprint once Noggit/in-game inspection is possible.

-- The SERVER geometry. The worldserver does not read AreaTrigger.dbc -- it loads boxes from
-- this table -- so a teleport row without a definition row here is inert. Both were missing
-- from the world DB entirely (checked 2026-08-29); the values below are copied field-for-field
-- from the deployed DBC rows so client and server agree by construction.
DELETE FROM `areatrigger` WHERE `entry` IN (6921, 6922);
INSERT INTO `areatrigger`
    (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
    (6921, 0, -11080, -1980, 95, 0, 8, 8, 10, 0),
    (6922, 2875, -10666, -1866, 100, 0, 8, 8, 10, 0);

DELETE FROM `areatrigger_teleport` WHERE `ID` IN (6921, 6922);
INSERT INTO `areatrigger_teleport` (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`) VALUES
    (6921, 'Karazhan Crypts (Entrance)', 2875, -10666.0, -1866.0, 101.0, 0),
    (6922, 'Karazhan Crypts (Exit)', 0, -11080.0, -1975.0, 95.0, 0.577268);
