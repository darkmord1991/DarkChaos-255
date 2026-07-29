-- ---------------------------------------------------------------------------
-- 170  Hyjal round-37 -- flight points for the border zones
-- ---------------------------------------------------------------------------
-- 164_ populated the true map extent but deliberately excluded flight masters,
-- so the eastern two-thirds of map 750 -- Everlook, Moonglade, Talonbranch,
-- Valormok -- had no way in or out by air.  Every one of the eight flight
-- masters on the map stood at x < 5600.
--
-- Seven stock flight points fall inside the map-750 terrain box
-- (x 3200-8000, y -5334..-533).  Gorrim at Emerald Sanctuary already arrived
-- with the border-zone import; the other six are spawned here.
--
--     8610  Kroum        Valormok, Azshara            -> taxi node 338
--    22931  Gorrim       Emerald Sanctuary, Felwood   -> taxi node 339  (spawned)
--    12578  Mishellena   Talonbranch Glade, Felwood   -> taxi node 343
--    11138  Maethrya     Everlook, Winterspring       -> taxi node 344
--    11139  Yugrek       Everlook, Winterspring       -> taxi node 345
--    10897  Sindrayl     Moonglade                    -> taxi node 446
--    12740  Faustron     Moonglade                    -> taxi node 447
--
-- MUST RUN BEFORE 166_.  The spawns go in with their RAW entry ids, inside the
-- 15,6xx,xxx guid block that 166_ reads to build its source set -- so 166_ picks
-- them up on the same pass and gives them private +3,700,000 clones like every
-- other border NPC.  Running it after 166_ would leave six raw NPCs on the map,
-- editable only by editing the real Everlook.
--
-- THE DBC SIDE IS NOT OPTIONAL
--   Taxi nodes live in TaxiNodes.dbc, not the world DB.  The npcflag alone does
--   nothing: the core resolves the flight master to a node by position via
--   GetNearestTaxiNode(x, y, z, map, team), so without the DBC rows these six
--   open an empty flight map.  Custom/Documentation/scripts/gen_taxi.py has been
--   extended to emit them (nodes 338/339/343/344/345/446/447, paths 9500-9763);
--   the three CSVs are regenerated and still need compiling and deploying to
--   BOTH Server/data/dbc and the client patch.
--
--   The routes for the seven new nodes come from the STOCK 3.3.5 tables rather
--   than Cata, because that eastern terrain IS stock WotLK Kalimdor.  Azshara
--   shows why it matters: Cata's node 44 is 'Bilgewater Harbor' at (3547,-6295)
--   after the revamp, 1,900 yards out into open water from where Kroum actually
--   stands.  Cross-cluster pairs (the five Cata-sourced Hyjal points to the seven
--   stock border points) exist in neither source and are flown as a climb-cruise-
--   descend arc; AzerothCore has no TaxiPathGraph, it reads
--   sTaxiPathSetBySource[from][to] directly, so all 132 ordered pairs need a row.
--
-- Idempotent: fixed guid range, deleted before insert.
-- ---------------------------------------------------------------------------

-- Copy the stock rows wholesale rather than naming columns.  `creature` drifts
-- on this fork and a hand-written column list is how 166_'s first revision
-- silently shifted fields; SELECT * into a temporary table cannot.
DROP TEMPORARY TABLE IF EXISTS `_dc_fm_spawn`;
CREATE TEMPORARY TABLE `_dc_fm_spawn` AS
SELECT * FROM `creature`
WHERE `map` = 1 AND `id` IN (8610, 12578, 11138, 11139, 10897, 12740);

-- zoneId/areaId 0 makes the core derive them from the map-750 terrain instead of
-- carrying Kalimdor's ids across.  phaseMask 1 puts them in the base phase.
UPDATE `_dc_fm_spawn`
SET `map` = 750, `zoneId` = 0, `areaId` = 0, `phaseMask` = 1,
    `guid` = 15810000 + FIELD(`id`, 8610, 12578, 11138, 11139, 10897, 12740);

DELETE FROM `creature` WHERE `guid` BETWEEN 15810001 AND 15810006;
INSERT INTO `creature` SELECT * FROM `_dc_fm_spawn`;

DROP TEMPORARY TABLE `_dc_fm_spawn`;

-- ---------------------------------------------------------------------------
-- Two stacked flight masters, same cause as 154_/158_/160_
-- ---------------------------------------------------------------------------
-- 155_ re-imported flight masters that the clone layer already had, so two of
-- the five Hyjal points carry a duplicate standing on top of the original:
--
--     Ranela Featherglen   3654393 (guid 15501257) on 3654392 (guid  9842750)
--                          0.05 yards apart, node 422
--     Elizil Wintermoth    3653783 (guid 15501254) on 3641860 (guid 12196648)
--                          1.8 yards apart, node 421
--
-- The 155_-imported copy is the one removed, matching what 158_ and 160_ did --
-- the older spawn is the one the rest of the port references.  Scoped to the two
-- guids rather than a pattern, because the other six flight masters in the
-- 155,xxxxx block are the only spawn of their NPC and must stay.
DELETE FROM `creature` WHERE `guid` IN (15501254, 15501257);
