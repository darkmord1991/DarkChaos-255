-- Hyjal Frontier areatrigger_teleport entries
-- Entry points: one portal from Dalaran (create GO separately) plus a
-- "back to Dalaran" edge trigger in case players fall off the map.
--
-- NOTE: AreaTrigger.dbc rows must be added client-side for these IDs to
-- physically exist in the world. Reserved range: 15000-15020.
-- Client-side rows (map=1410, box/radius around a visible GO) are expected
-- to live in the custom DBC CSVs once Noggit placements are final.

DELETE FROM `areatrigger_teleport` WHERE `ID` BETWEEN 15000 AND 15020;
INSERT INTO `areatrigger_teleport`
    (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`)
VALUES
-- Entry from Dalaran (client AreaTrigger.dbc row 15000 placed in Dalaran)
(15000, 'Hyjal Frontier, Entry Portal (from Dalaran)',
    1410, 4634.0, -3786.0, 942.0, 0.75),
-- Return to Dalaran (client row 15001 placed at the Hyjal portal GO)
(15001, 'Hyjal Frontier, Exit Portal (to Dalaran)',
    571, 5804.15, 624.771, 647.767, 1.64);
