-- ===========================================================================
-- Map 861 -- open the Molten Front teleporter (dc_teleporter 413) to players.
--
-- 413 was GM-gated (security_level 3) by Level Areas 30_entry_points.sql
-- until map 861 reached the live server: an unknown map id hangs players at
-- the loading screen. 861 is extracted there (confirmed 2026-08-16) and
-- Map.dbc on the server holds it. The arrival is the base hub, beside General
-- Taldris Moonfall, with Malfurion (29201) close by; the stage areas around it
-- are quest-phased (r55).
-- The Hyjal breadcrumb the 247_ notes reserved quests 81316+ for exists as
-- DC quest 751330 "Gateway to the Molten Front" (Ilthaine Ashbough, level 124).
-- Like the other Level Areas entries, the menu has no level check.
-- Takes effect after `.dc teleporter reload` or a restart.
-- ===========================================================================

UPDATE `dc_teleporter` SET `security_level` = 0, `comment` = 'The Molten Front (map 861) - open to players since 2026-11-20' WHERE `id` = 413 AND `security_level` = 3;
