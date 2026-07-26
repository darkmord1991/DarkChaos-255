-- ---------------------------------------------------------------------------
-- 30  Entry points: DC Teleporter NPC + .tele / addon destinations
-- ---------------------------------------------------------------------------
-- Until now the ONLY way into the 80-130 zone was `.tele dchyjal` (a GM command),
-- and the player-facing route was broken: the Teleporter NPC's "Level Areas ->
-- Hyjal 80 - 130" menu had both of its destinations pointing at map **1410**,
-- the superseded `Hyjal130` clone. A player picking "Hyjal Start" landed in the
-- dead zone -- correct map id, no content.
--
--   411  Hyjal Start Alli   map 1410 @ 5106.56, -1785.61, 1322.64
--   412  Hyjal Start Horde  map 1410 @ 5453.32, -2953.41, 1539.62
--
-- Both are repointed at the real map 750 camps created by 10_faction_bases.sql,
-- keeping the existing faction split (`dc_teleporter.faction`: 0 = Alliance,
-- 1 = Horde, -1 = both -- see src/server/scripts/DC/Teleporters/dc_teleporter.cpp).
--
-- Two surfaces need feeding, and they read different tables:
--   * the Teleporter NPC gossip (creatures 800002 / 33274) reads `dc_teleporter`
--   * the in-game addon teleport list reads `game_tele`
--     (src/server/scripts/DC/AddonExtension/dc_addon_teleports.cpp)
-- so both get rows. Hot-reload the first with `.dc teleporter reload`.
--
-- Arrival points are the verified camp centres from 10_faction_bases.sql. The
-- first pass dropped players 35 yd off-centre at a z ~2 yd above ground, which
-- is why arrivals fell -- these land exactly on the measured ground height.
--
-- !! 412 (Thrall's Vanguard) is NOT written yet. The Horde site has no verified
-- GroundZ == FloorZ coordinate: the scouted area (5660.58, -2980.15) reports
-- GroundZ 1546.50 but FloorZ 1560.70, i.e. a VMAP object 14 yd above the
-- terrain, so neither height is safe to teleport into. The stale row pointing at
-- the dead map 1410 is removed rather than left live, so the Horde entry is
-- simply absent from the menu until the coordinate is confirmed.
--
-- !! 413 (The Molten Front, map 861) is included but LEFT DISABLED at
-- security_level 3 (GM-only). Map 861 is not yet on the live Linux server's
-- Map.dbc / maps / vmaps / mmaps, and `MapMgr::CreateBaseMap` asserts on an
-- unknown map id -- exposing it to players before that deployment lands would
-- hang them at the loading screen. Drop it to 0 once
-- HYJAL_MOLTENFRONT_HANDOFF.md sections E0 + E03 are done.
-- ---------------------------------------------------------------------------

-- 1. Teleporter NPC menu.
DELETE FROM `dc_teleporter` WHERE `id` IN (411, 412, 413);
INSERT INTO `dc_teleporter` (`id`, `parent`, `type`, `faction`, `security_level`, `comment`, `icon`, `name`, `map`, `x`, `y`, `z`, `o`) VALUES
(411, 410, 2,  0, 0, 'Jaina''s Encampment, Mount Hyjal (map 750)', 2, 'Jaina''s Encampment (Alliance)', 750, 4443.50, -2077.47, 1206.25, 4.712),
(413, 410, 2, -1, 3, 'The Molten Front (map 861) - GM-gated until 861 ships to the Linux host', 2, 'The Molten Front', 861, 1021.00, 394.00, 42.20, 5.640);

-- 2. `.tele` / addon destinations.
--    10612 dchyjal, 10621 moltenfront and 10622 hyjalmfportal already exist and
--    are left alone -- they are the raw map anchors, these are the camp arrivals.
DELETE FROM `game_tele` WHERE `id` BETWEEN 10630 AND 10632;
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
(10630, 4443.50, -2077.47, 1206.25, 4.712, 750, 'JainasEncampment'),
(10632, 5135.00, -1731.00, 1335.50, 0.000, 750, 'Nordrassil');
