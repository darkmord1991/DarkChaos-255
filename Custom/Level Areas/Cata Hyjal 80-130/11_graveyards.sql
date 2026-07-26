-- ---------------------------------------------------------------------------
-- 11  Graveyards for Mount Hyjal (750) and The Molten Front (861)
-- ---------------------------------------------------------------------------
-- Live state before this file: **neither map has a working graveyard.**
--
--   SELECT COUNT(*) FROM game_graveyard WHERE Map IN (750, 861);  -->  0
--   SELECT COUNT(*) FROM graveyard_zone WHERE GhostZone = 4925;   -->  0
--
-- Map 750: `HyjalCata/14_graveyard.sql` tried to create the zone's graveyard as
-- id **1723** with `INSERT IGNORE`. But 1723 was **already taken** -- it is
-- Azshara Crater's "Starter2" graveyard on map 37 -- so IGNORE silently dropped
-- the insert, while the companion `graveyard_zone` row still linked zone 4923 to
-- it. Net effect: **dying anywhere in Mount Hyjal resurrects the player in
-- Azshara Crater**, a different continent. Classic INSERT IGNORE trap: the row
-- that "already exists" was not the row anyone meant.
--
-- Map 861: no graveyard was ever authored, so `GetClosestGraveyard` logs
-- "Table `graveyard_zone` incomplete: Zone 4925 ... does not have a linked
-- graveyard" and falls back off-map.
--
-- `game_graveyard` IDs are free-form here -- `GameGraveyard.cpp:37` loads the
-- table directly (`SELECT ID, Map, x, y, z, Comment FROM game_graveyard`) with no
-- WorldSafeLocs.dbc lookup anywhere in the core, so no client DBC row is needed.
-- (14_graveyard.sql's comment claiming it "mirrors WorldSafeLocs.dbc id 1723" is
-- stale for this fork.) IDs 15013+ verified free; 15000-15012 are the dead
-- map-1410 Hyjal set plus Guildhouse/Hinterland BG.
--
-- Positions are taken from surveyed flat, ground-verified settlement centres
-- (service-NPC clusters), same method as 10_faction_bases.sql.
--
-- `graveyard_zone.Faction`: 0 = either team, 469 = Alliance, 67 = Horde.
-- ---------------------------------------------------------------------------

-- 1. Drop the mis-targeted link. Graveyard 1723 itself is Azshara Crater's and
--    is left completely untouched -- only Hyjal's claim on it is removed.
DELETE FROM `graveyard_zone` WHERE `ID` = 1723 AND `GhostZone` = 4923;

-- 2. Retire the superseded map-1410 graveyards and their zone links.
DELETE FROM `graveyard_zone` WHERE `GhostZone` BETWEEN 6100 AND 6106;
DELETE FROM `game_graveyard` WHERE `ID` BETWEEN 15000 AND 15003;

-- 3. Real graveyards for both maps.
DELETE FROM `game_graveyard` WHERE `ID` BETWEEN 15013 AND 15019;
INSERT INTO `game_graveyard` (`ID`, `Map`, `x`, `y`, `z`, `Comment`) VALUES
(15013, 750, 4445.00, -2085.00, 1208.30, 'Mount Hyjal - Jaina''s Encampment (Alliance)'),
(15014, 750, 5346.00, -2170.00, 1274.60, 'Mount Hyjal - Thrall''s Vanguard (Horde)'),
(15015, 750, 5135.00, -1731.00, 1335.50, 'Mount Hyjal - Nordrassil / Sanctuary of Malorne'),
(15016, 750, 4930.00, -2705.00, 1433.40, 'Mount Hyjal - Shrine of Aviana'),
(15017, 750, 5552.00, -3601.00, 1569.80, 'Mount Hyjal - southern summit camp'),
(15018, 750, 4593.00, -4693.00,  885.40, 'Mount Hyjal - south-western staging camp'),
(15019, 861, 1021.00,   394.00,   42.20, 'The Molten Front - staging camp');

-- 4. Link them. Each faction gets its own camp plus the shared neutral set, so
--    GetClosestGraveyard always has a same-map candidate wherever the player dies.
DELETE FROM `graveyard_zone` WHERE `ID` BETWEEN 15013 AND 15019;
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`) VALUES
(15013, 4923, 469, 'Mount Hyjal - Alliance camp'),
(15014, 4923,  67, 'Mount Hyjal - Horde camp'),
(15015, 4923,   0, 'Mount Hyjal - Nordrassil'),
(15016, 4923,   0, 'Mount Hyjal - Shrine of Aviana'),
(15017, 4923,   0, 'Mount Hyjal - southern summit'),
(15018, 4923,   0, 'Mount Hyjal - south-western staging'),
(15019, 4925,   0, 'The Molten Front');
