-- ---------------------------------------------------------------------------
-- 40  Classic faction starts: Lor'danel (Alliance) + Bilgewater Harbor (Horde)
-- ---------------------------------------------------------------------------
-- The 80-130 continent goes classic: each faction starts in the zone Cata
-- built for it -- Alliance at Lor'danel in Darkshore (80-90), Horde at
-- Bilgewater Harbor in Azshara (80-90) -- and levels toward Hyjal (113-130).
-- Both towns already exist on map 750 with innkeeper + flight master; this
-- file wires the entries. Transport is the Teleporter NPC + addon list ONLY
-- (decision 2026-08-03: no portal objects -- the earlier capital<->hub portal
-- layer was dropped before ever being applied).
--
-- Anchors are ground-placed native service NPCs (the README's rule 4 -- they
-- are the only trustworthy z reference short of an in-game .gps):
--   Lor'danel plaza      Teldira Moonfeather (FM)   7462.24,  -326.55,  8.21
--   Bilgewater Harbor    Innkeeper Mixi             3527.24, -6518.98, 43.59
-- The Horde anchor is the INN, not Kroum's dock 230 yd north: arriving at the
-- inn gives an immediate hearthstone bind and puts the Bilgewater Harbor
-- graveyard (15047, 60 yd south) in range.
-- !! PROVISIONAL until an in-game `.gps` confirms GroundZ == FloorZ at both
-- arrival points. Verify, correct here if needed, re-apply.
--
-- Supersedes 30_entry_points.sql's teleporter rows and MUST run after it
-- (30_ re-inserts the old 411). IDs: dc_teleporter 412/414/415 and game_tele
-- 10633-10634 (verified free). Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. Teleporter NPC menu (hot-reload with `.dc teleporter reload`)
-- ---------------------------------------------------------------------------
-- faction: 0 = Alliance, 1 = Horde, -1 = both.
DELETE FROM `dc_teleporter` WHERE `id` IN (411, 412, 414, 415);
INSERT INTO `dc_teleporter` (`id`, `parent`, `type`, `faction`, `security_level`, `comment`, `icon`, `name`, `map`, `x`, `y`, `z`, `o`) VALUES
(411, 410, 2,  0, 0, 'Lor''danel, Darkshore (80-90) - Alliance start, Teldira plaza anchor', 2, 'Lor''danel (Alliance start)', 750, 7462.24, -326.55, 8.21, 3.194),
(412, 410, 2,  1, 0, 'Bilgewater Harbor, Azshara (80-90) - Horde start, inn anchor', 2, 'Bilgewater Harbor (Horde start)', 750, 3527.24, -6518.98, 43.59, 0.122),
(414, 410, 2,  0, 0, 'Jaina''s Encampment, Hyjal Frontier (113-130) - Alliance endgame hub', 2, 'Jaina''s Encampment (Alliance)', 750, 4443.50, -2077.47, 1206.25, 4.712),
(415, 410, 2, -1, 0, 'Nordrassil, Hyjal Frontier (113-130) - neutral endgame hub', 2, 'Nordrassil', 750, 5135.00, -1731.00, 1335.50, 0.000);

-- ---------------------------------------------------------------------------
-- 2. `.tele` / addon destinations -- one per band hub
-- ---------------------------------------------------------------------------
-- `dc` prefix throughout, matching the existing dchyjal/dcplague convention
-- AND avoiding collisions: stock `game_tele` already has "Astranaar" (58) and
-- "Everlook" (345) pointing at map 1, and `.tele` matches by name.
-- Pre-existing and left alone: 10612 dchyjal, 10613 dcplague,
-- 10630 JainasEncampment, 10632 Nordrassil.
DELETE FROM `game_tele` WHERE `id` BETWEEN 10633 AND 10639;
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`) VALUES
(10633, 7462.24,  -326.55,    8.21, 3.194, 750, 'dclordanel'),
(10634, 3527.24, -6518.98,   43.59, 0.122, 750, 'dcbilgewater'),
(10635, 2781.16,  -433.00,  116.66, 2.583, 750, 'dcastranaar'),
(10636, 2341.86, -2566.99,  103.18, 2.286, 750, 'dcsplintertree'),
(10637, 3981.74, -1321.47,  251.12, 2.007, 750, 'dcemerald'),
(10638, 6695.15, -4673.04,  721.65, 0.541, 750, 'dceverlook'),
(10639, 7454.85, -2491.61,  462.70, 1.152, 750, 'dcnighthaven');

-- ---------------------------------------------------------------------------
-- 3. cleanup: retire the never-deployed portal layer
-- ---------------------------------------------------------------------------
-- An earlier revision of this file shipped capital<->hub portals (spells
-- 300602/300603, GO templates 3809082/3809083, GO guids 9021000-9021005).
-- The design dropped them; these DELETEs are no-ops on a fresh DB and clean
-- up any DB the earlier revision touched. The ids return to the free pool.
DELETE FROM `gameobject` WHERE `guid` BETWEEN 9021000 AND 9021005;
DELETE FROM `gameobject_template_addon` WHERE `entry` IN (3809082, 3809083);
DELETE FROM `gameobject_template` WHERE `entry` IN (3809082, 3809083);
DELETE FROM `spell_target_position` WHERE `ID` IN (300602, 300603);
DELETE FROM `spell_dbc` WHERE `ID` IN (300602, 300603);

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- SELECT id, name, map, x, y, z FROM dc_teleporter WHERE id IN (411, 412, 414, 415);
-- SELECT id, name FROM game_tele WHERE id IN (10633, 10634);
-- In-game: `.tele Lordanel` / `.tele BilgewaterHarbor`, `.gps` at each arrival
-- -- GroundZ == FloorZ expected; take both teleporter menu entries per faction.
