-- =====================================================================
-- Molten Front -- 04  Portal: Hyjal (map 750) <-> Molten Front (map 861)
-- ---------------------------------------------------------------------
-- The Molten Front is its own map (861); players reach it through a portal,
-- exactly like retail. This authors the two server-side areatrigger_teleport
-- rows (walk-in portals). Each needs a matching client AreaTrigger.dbc row
-- (defines WHERE the trigger sits + its radius) -- author those in the DBC
-- pass and repack per OFFLINE_PIPELINE.md.
--
--   9861  on map 750 (Hyjal staging) -> map 861 Molten Front hub
--   9862  on map 861 (MF hub)         -> map 750 Hyjal staging
--
-- *** COORDS ARE PROVISIONAL ***  The Hyjal-side point reuses the covered
-- staging spot the old 32_ hub used (map 750 ~4620,-2090,1237). The MF-side
-- landing is the nelt MF hub (General Taldris Moonfall, map 861 1021,394,42).
-- Finalize both after the map-861 terrain carve confirms exact ground z.
-- Idempotent. Run AFTER 01/02.
-- =====================================================================

DELETE FROM `areatrigger_teleport` WHERE `ID` IN (9861,9862);
INSERT INTO `areatrigger_teleport`
  (`ID`,`Name`,`target_map`,`target_position_x`,`target_position_y`,`target_position_z`,`target_orientation`)
VALUES
  (9861,'Hyjal -> Molten Front', 861, 1021.0,  394.0,  42.2, 5.64),
  (9862,'Molten Front -> Hyjal', 750, 4620.0, -2090.0, 1237.0, 3.14);

-- ---------------------------------------------------------------------
-- CLIENT side (offline DBC pass -- add to Custom/CSV DBC/AreaTrigger.csv,
-- recompile, pack into patch-4; verify the two ids are free first):
--   AreaTrigger 9861: ContinentID 750, x 4620, y -2090, z 1237, radius 5
--   AreaTrigger 9862: ContinentID 861, x 1021, y  394,  z 42,   radius 5
-- (Sphere trigger -> set Radius=5, box fields 0. Without these rows the
--  walk-in never fires client-side.)
--
-- OPTIONAL visual: place a fire-portal GameObject at each end for looks
-- (co-located with the trigger). Left out here to avoid guessing a display id;
-- add in the immersion pass if desired.
-- ---------------------------------------------------------------------
