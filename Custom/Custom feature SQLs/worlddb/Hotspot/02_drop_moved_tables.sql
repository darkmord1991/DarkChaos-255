-- =====================================================================
-- DarkChaos Hotspots - drop the world-DB copies after the chardb migration
-- =====================================================================
-- RUN AGAINST: acore_world
--
-- ONLY run this AFTER chardb/Hotspot/01_hotspot_tables_move_to_chardb.sql has
-- been applied - that script copies the surviving rows across from here.
--
-- Both tables are runtime state written by the worldserver and now live in
-- acore_characters. Leaving them here is harmless but misleading: nothing
-- reads or writes them any more, and a world-DB rebuild would have wiped
-- them anyway.
--
-- dc_hotspots_table.sql / dc_hotspot_spawn_points.sql in this folder are
-- superseded by the chardb script and should not be applied again.
-- =====================================================================

DROP TABLE IF EXISTS `dc_hotspots_active`;
DROP TABLE IF EXISTS `dc_hotspot_spawn_points`;
