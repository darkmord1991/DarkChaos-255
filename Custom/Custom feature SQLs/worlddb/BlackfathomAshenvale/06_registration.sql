-- =====================================================================================
-- Blackfathom Deeps (Ashenvale) -- map 820 clone, step 6: instance registration + entrance
--
-- Wires the clone into the world: instance binding, the level gates for its three
-- difficulties, the walk-in entrance on map 750, and a GM teleport.
--
-- The AreaTrigger BOXES live in AreaTrigger.dbc (ids 607004/607005, added by
-- Custom/BlackfathomAshenvale/add_bfd820_dbc_rows.py) and must be compiled and deployed to
-- the client before these rows do anything.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- instance_template
--
-- `script` binds the C++ InstanceScript. Map 48's own script is registered as
-- InstanceMapScript("instance_blackfathom_deeps", MAP_BLACKFATHOM_DEEPS) -- the map id is
-- baked into the constructor, so the clone cannot reuse it. The DC clone
-- src/server/scripts/DC/BlackfathomAshenvale/instance_bfd_ashenvale.cpp registers the same
-- logic against map 820 with the offset entry ids. WORLDSERVER REBUILD REQUIRED.
--
-- Without it the four Fire of Aku'mai objects still set instance data, but nothing listens,
-- so the Portal of Aku'Mai never opens and the final boss is unreachable.
-- -------------------------------------------------------------------------------------
DELETE FROM `instance_template` WHERE `map` = 820;
INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
    (820, 0, 'instance_bfd_ashenvale', 0);

-- -------------------------------------------------------------------------------------
-- dungeon_access_template -- one row per difficulty.
-- `id` is tinyint unsigned (max 255); live max was 145 before the Timbermaw row 146.
--
-- Levels are TUNING CHOICES, not constraints from the data:
--   normal 90  - the dungeon's own mobs are 92-96, inside the Ashenvale band (88-98)
--   heroic 125 / mythic 130 - the DC difficulty scaler re-levels every rank-1 creature to
--   129 on heroic and 130 on mythic (see 07), so these gates match what players will face.
-- -------------------------------------------------------------------------------------
DELETE FROM `dungeon_access_template` WHERE `map_id` = 820;
INSERT INTO `dungeon_access_template`
    (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`) VALUES
    (147, 820, 0, 90, 0, 0, 'Blackfathom Deeps (Ashenvale) - Normal'),
    (148, 820, 1, 125, 0, 0, 'Blackfathom Deeps (Ashenvale) - Heroic'),
    (149, 820, 2, 130, 0, 0, 'Blackfathom Deeps (Ashenvale) - Mythic');

-- -------------------------------------------------------------------------------------
-- areatrigger_teleport
--
-- Entrance sits on the REAL Blackfathom Deeps cave mouth on map 750 -- stock AreaTrigger.dbc
-- row 257 puts it at 4252.37 / 756.97 / -23.06 on continent 1, and that tile (30_24, Zoram
-- Strand) is present and populated on map 750 (407 spawns in the surrounding box).
-- The arrival point is stock trigger 257's own teleport target, so it is a known-good spot
-- inside the Blackfathom terrain that map 820 shares.
--
-- The exit target is deliberately ~35 yards clear of the entrance trigger's 12-yard radius.
-- Land inside it and the player is teleported straight back in, forever.
--
-- BOTH map-750 positions are PROVISIONAL -- verify with `.gps` and fix Z if GroundZ != FloorZ.
-- -------------------------------------------------------------------------------------
DELETE FROM `areatrigger_teleport` WHERE `ID` IN (607004, 607005);
INSERT INTO `areatrigger_teleport`
    (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`) VALUES
    (607004, 'Blackfathom Deeps Ashenvale (Entrance)', 820, -151.89, 106.96, -39.87, 1.15),
    (607005, 'Blackfathom Deeps Ashenvale (Exit)', 750, 4285.0, 775.0, -20.0, 3.90);

-- -------------------------------------------------------------------------------------
-- game_tele -- `.tele dcbfd`. 10640/10641 are the Timbermaw Hold pair, so this takes 10642.
-- -------------------------------------------------------------------------------------
DELETE FROM `game_tele` WHERE `id` = 10642;
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
    (10642, -151.89, 106.96, -39.87, 1.15, 820, 'dcbfd');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'instance_template' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `instance_template` WHERE `map` = 820
UNION ALL SELECT 'access rows (want 3)', CAST(COUNT(*) AS CHAR) FROM `dungeon_access_template` WHERE `map_id` = 820
UNION ALL SELECT 'areatrigger_teleport (want 2)', CAST(COUNT(*) AS CHAR) FROM `areatrigger_teleport` WHERE `ID` IN (607004, 607005)
UNION ALL SELECT 'game_tele (want 1)', CAST(COUNT(*) AS CHAR) FROM `game_tele` WHERE `id` = 10642;
