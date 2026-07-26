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
-- Arrival points are the two camp centres from 10_faction_bases.sql, nudged just
-- outside the 18 yd service ring so players do not land inside a vendor.
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
(411, 410, 2,  0, 0, 'Jaina''s Encampment, Mount Hyjal (map 750)', 2, 'Jaina''s Encampment (Alliance)', 750, 4433.0, -2043.0, 1208.3, 4.712),
(412, 410, 2,  1, 0, 'Thrall''s Vanguard, Mount Hyjal (map 750)',  2, 'Thrall''s Vanguard (Horde)',    750, 5334.0, -2128.0, 1274.6, 4.712),
(413, 410, 2, -1, 3, 'The Molten Front (map 861) - GM-gated until 861 ships to the Linux host', 2, 'The Molten Front', 861, 1021.0, 394.0, 42.2, 5.64);

-- 2. `.tele` / addon destinations for the same three points.
--    10612 dchyjal, 10621 moltenfront and 10622 hyjalmfportal already exist and
--    are left alone -- they are the raw map anchors, these are the camp arrivals.
DELETE FROM `game_tele` WHERE `id` BETWEEN 10630 AND 10632;
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
(10630, 4433.0, -2043.0, 1208.3, 4.712, 750, 'JainasEncampment'),
(10631, 5334.0, -2128.0, 1274.6, 4.712, 750, 'ThrallsVanguard'),
(10632, 5135.0, -1731.0, 1335.5, 0.000, 750, 'Nordrassil');
