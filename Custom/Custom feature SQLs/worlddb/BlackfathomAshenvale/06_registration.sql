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
-- The arrival orientation is stock 257's own (4.53), not the 1.15 this file used to carry.
--
-- BOTH BOXES WERE RE-MEASURED IN GAME and moved in `Custom/CSV DBC/AreaTrigger.csv`; this
-- file only supplies their teleport targets. **The DBC must be recompiled and redeployed to
-- the client or neither trigger fires** -- the client reads AreaTrigger.dbc itself and only
-- sends CMSG_AREATRIGGER for boxes it knows about, which is why 607004 was silent while
-- Timbermaw's 607002 worked: 607002 had been deployed, 607004 had not.
--
--   607004 entrance, map 750: 4250.2705 / 748.8062 / -23.281  (was 4252.37 / 756.97 / -23.06,
--     which came off stock trigger 257 on map 1 -- VANILLA Zoram Strand, not map 750's Cata one)
--   607005 exit,     map 820: -176.8639 / 51.55968 / -49.6351 (was sitting on the arrival point)
--
-- Both now use the radius-0, 8x8x10 box shape that 607002 already proves fires in game. The
-- old 607004 used Radius 12, and THAT is what made the pair unsafe: the exit drops the player
-- 11.53 yd from the entrance box, inside a 12-yd sphere, so walking out would have teleported
-- them straight back in. Against an 8-wide box (half-extent 4) the 10.48 yd Y-separation is
-- clear. Clearances, all verified: exit landing -> entrance box 11.53 yd; entrance box ->
-- Blackfathom Gatekeeper 18.56 yd (a trigger closer than ~15 yd fires while you walk up to
-- the NPC, which is the bug Timbermaw's gate had); exit box -> arrival point 61.55 yd.
-- Re-check all three if you move any of them.
-- -------------------------------------------------------------------------------------
DELETE FROM `areatrigger_teleport` WHERE `ID` IN (607004, 607005);
INSERT INTO `areatrigger_teleport`
    (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`) VALUES
    (607004, 'Blackfathom Deeps Ashenvale (Entrance)', 820, -151.89, 106.96, -39.87, 4.53),
    (607005, 'Blackfathom Deeps Ashenvale (Exit)', 750, 4246.28, 738.322, -25.9246, 1.86366);

-- -------------------------------------------------------------------------------------
-- game_tele -- `.tele dcbfd`.
--
-- Id and position are the LIVE ones, added in game and read back out: id 10644, and the
-- map-750 cave mouth rather than the dungeon interior. The id this file used to claim
-- (10642) was never taken, and the old target (820, -151.89/106.96/-39.87) duplicated the
-- areatrigger arrival above; as a GM shortcut the surface entrance is the more useful end.
--
-- DELETE covers the NAME as well as the id: a stale 10642 `dcbfd` left over from an earlier
-- run of this file would otherwise make `.tele dcbfd` ambiguous between two rows.
-- -------------------------------------------------------------------------------------
DELETE FROM `game_tele` WHERE `id` IN (10642, 10644) OR `name` = 'dcbfd';
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
    (10644, 4246.28, 738.322, -25.9246, 1.86366, 750, 'dcbfd');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'instance_template' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `instance_template` WHERE `map` = 820
UNION ALL SELECT 'access rows (want 3)', CAST(COUNT(*) AS CHAR) FROM `dungeon_access_template` WHERE `map_id` = 820
UNION ALL SELECT 'areatrigger_teleport (want 2)', CAST(COUNT(*) AS CHAR) FROM `areatrigger_teleport` WHERE `ID` IN (607004, 607005)
UNION ALL SELECT 'game_tele dcbfd (want 1)', CAST(COUNT(*) AS CHAR) FROM `game_tele` WHERE `name` = 'dcbfd';
