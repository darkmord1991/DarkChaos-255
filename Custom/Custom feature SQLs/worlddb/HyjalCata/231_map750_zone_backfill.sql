-- ---------------------------------------------------------------------------
-- 231  Map 750 -- zoneId/areaId backfill + per-entry zone attribution
-- ---------------------------------------------------------------------------
-- FIRST FILE of the 80-130 leveling-band project (231-241 + Level Areas 40-43).
-- Everything later in the series joins spawns/templates to a ZONE, and today
-- that join is unreliable: 8,952 of 18,972 map-750 creature rows carry
-- zoneId = 0 (Felwood has ZERO tagged creature rows despite ~2,100 spawns in
-- its footprint) because only the later import rounds (176/178/184/212)
-- stamped zoneId/areaId.
--
-- The `zoneId`/`areaId` columns are only spawn HINTS in AzerothCore (the core
-- recomputes from terrain at load where they are 0), so this is data hygiene,
-- not a gameplay fix -- but it is a hard prerequisite for the per-zone SQL in
-- 233-240.
--
-- Method: majority-vote zone per 33.33-yd terrain chunk, derived from
-- cata_world's own map-1 spawns (the map is a coordinate-preserving copy, so
-- Cata's spawn zoning IS the ground truth; the ADT areaids themselves are Cata
-- ids that do not resolve through our AreaTable -- see 212_'s header). Chunk
-- formula as in 212_: cx = FLOOR((32 - x/533.3333)*16).
--
--   cata zone -> DC zone: 616 Mount Hyjal -> 4923, 618 Winterspring -> 4926,
--   361 Felwood -> 4927, 493 Moonglade -> 4928, 148 Darkshore -> 4929,
--   16 Azshara -> 4930, 331 Ashenvale -> 4931.
--
-- areaId is set equal to the zone: our AreaTable defines only the seven
-- top-level zones on continent 750 (no sub-areas), and the Cata sub-area ids
-- baked into the ADTs are foreign to this fork's AreaTable.
--
-- Leaves behind two REFERENCE TABLES the rest of the series joins against:
--   dc_map750_chunkzone  (chunk -> zone)
--   dc_map750_entryzone  (creature template entry -> majority zone + share)
--   dc_map750_entryzone_go (same for gameobject templates)
--
-- Apply against acore_world. Idempotent (helper tables are rebuilt, the spawn
-- UPDATE is a recomputation). Requires cata_world to be reachable, same as
-- 212_. Restart not required for this file alone.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) chunk -> zone map from cata_world's spawn zoning (majority vote per chunk)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map750_chunkzone`;

CREATE TABLE `dc_map750_chunkzone` (
  `cx` INT NOT NULL,
  `cy` INT NOT NULL,
  `zone` INT NOT NULL,
  PRIMARY KEY (`cx`, `cy`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map750_chunkzone` (`cx`, `cy`, `zone`)
SELECT `cx`, `cy`, `zone` FROM (
  SELECT FLOOR((32 - s.`position_x` / 533.3333333) * 16) AS cx,
         FLOOR((32 - s.`position_y` / 533.3333333) * 16) AS cy,
         CASE s.`zoneId`
           WHEN 616 THEN 4923 WHEN 618 THEN 4926 WHEN 361 THEN 4927
           WHEN 493 THEN 4928 WHEN 148 THEN 4929 WHEN  16 THEN 4930
           WHEN 331 THEN 4931
         END AS zone,
         ROW_NUMBER() OVER (
           PARTITION BY FLOOR((32 - s.`position_x` / 533.3333333) * 16),
                        FLOOR((32 - s.`position_y` / 533.3333333) * 16)
           ORDER BY COUNT(*) DESC
         ) AS rn
  FROM `cata_world`.`creature` s
  WHERE s.`map` = 1
    AND s.`zoneId` IN (616, 618, 361, 493, 148, 16, 331)
  GROUP BY cx, cy, s.`zoneId`
) v
WHERE v.rn = 1 AND v.zone IS NOT NULL;

-- ---------------------------------------------------------------------------
-- B) backfill the spawn rows on map 750 (creatures + gameobjects)
-- ---------------------------------------------------------------------------
-- Pass 1: exact chunk hit. Unconditional recompute -- re-run safe.
UPDATE `creature` c
JOIN `dc_map750_chunkzone` z
  ON z.`cx` = FLOOR((32 - c.`position_x` / 533.3333333) * 16)
 AND z.`cy` = FLOOR((32 - c.`position_y` / 533.3333333) * 16)
SET c.`zoneId` = z.`zone`, c.`areaId` = z.`zone`
WHERE c.`map` = 750;

UPDATE `gameobject` g
JOIN `dc_map750_chunkzone` z
  ON z.`cx` = FLOOR((32 - g.`position_x` / 533.3333333) * 16)
 AND z.`cy` = FLOOR((32 - g.`position_y` / 533.3333333) * 16)
SET g.`zoneId` = z.`zone`, g.`areaId` = z.`zone`
WHERE g.`map` = 750;

-- Pass 2: residue -- chunks where cata_world has no spawn (buffer tiles, camp
-- shelves, water). Take the nearest classified chunk within a +/-12 window
-- (~400 yd). COALESCE keeps the row at 0 when even that finds nothing --
-- zoneId is NOT NULL, so a bare NULL subquery aborts the whole statement in
-- strict mode (error 1048); rows left at 0 are recomputed from terrain by the
-- core at load and reported by the trailer.
UPDATE `creature` c
SET c.`zoneId` = COALESCE((
      SELECT z.`zone` FROM `dc_map750_chunkzone` z
      WHERE z.`cx` BETWEEN FLOOR((32 - c.`position_x` / 533.3333333) * 16) - 12
                       AND FLOOR((32 - c.`position_x` / 533.3333333) * 16) + 12
        AND z.`cy` BETWEEN FLOOR((32 - c.`position_y` / 533.3333333) * 16) - 12
                       AND FLOOR((32 - c.`position_y` / 533.3333333) * 16) + 12
      ORDER BY POW(z.`cx` - FLOOR((32 - c.`position_x` / 533.3333333) * 16), 2)
             + POW(z.`cy` - FLOOR((32 - c.`position_y` / 533.3333333) * 16), 2)
      LIMIT 1), 0),
    c.`areaId` = c.`zoneId`
WHERE c.`map` = 750 AND c.`zoneId` = 0;

UPDATE `gameobject` g
SET g.`zoneId` = COALESCE((
      SELECT z.`zone` FROM `dc_map750_chunkzone` z
      WHERE z.`cx` BETWEEN FLOOR((32 - g.`position_x` / 533.3333333) * 16) - 12
                       AND FLOOR((32 - g.`position_x` / 533.3333333) * 16) + 12
        AND z.`cy` BETWEEN FLOOR((32 - g.`position_y` / 533.3333333) * 16) - 12
                       AND FLOOR((32 - g.`position_y` / 533.3333333) * 16) + 12
      ORDER BY POW(z.`cx` - FLOOR((32 - g.`position_x` / 533.3333333) * 16), 2)
             + POW(z.`cy` - FLOOR((32 - g.`position_y` / 533.3333333) * 16), 2)
      LIMIT 1), 0),
    g.`areaId` = g.`zoneId`
WHERE g.`map` = 750 AND g.`zoneId` = 0;

-- ---------------------------------------------------------------------------
-- C) per-template majority zone -- the join table for 233-240
-- ---------------------------------------------------------------------------
-- share = fraction of the entry's spawns in its majority zone. Adjacent bands
-- overlap by ~2 levels, so a sub-0.9 share (border patrollers) is absorbed by
-- the band overlap; the trailer lists them for eyeballing anyway.
DROP TABLE IF EXISTS `dc_map750_entryzone`;

CREATE TABLE `dc_map750_entryzone` (
  `entry` INT NOT NULL PRIMARY KEY,
  `zone` INT NOT NULL,
  `share` DECIMAL(4,3) NOT NULL,
  `spawns` INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map750_entryzone` (`entry`, `zone`, `share`, `spawns`)
SELECT v.entry, v.zone, v.cnt / v.tot, v.tot FROM (
  SELECT c.`id` AS entry, c.`zoneId` AS zone, COUNT(*) AS cnt,
         SUM(COUNT(*)) OVER (PARTITION BY c.`id`) AS tot,
         ROW_NUMBER() OVER (PARTITION BY c.`id` ORDER BY COUNT(*) DESC) AS rn
  FROM `creature` c
  WHERE c.`map` = 750 AND c.`zoneId` <> 0
  GROUP BY c.`id`, c.`zoneId`
) v
WHERE v.rn = 1;

DROP TABLE IF EXISTS `dc_map750_entryzone_go`;

CREATE TABLE `dc_map750_entryzone_go` (
  `entry` INT NOT NULL PRIMARY KEY,
  `zone` INT NOT NULL,
  `share` DECIMAL(4,3) NOT NULL,
  `spawns` INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map750_entryzone_go` (`entry`, `zone`, `share`, `spawns`)
SELECT v.entry, v.zone, v.cnt / v.tot, v.tot FROM (
  SELECT g.`id` AS entry, g.`zoneId` AS zone, COUNT(*) AS cnt,
         SUM(COUNT(*)) OVER (PARTITION BY g.`id`) AS tot,
         ROW_NUMBER() OVER (PARTITION BY g.`id` ORDER BY COUNT(*) DESC) AS rn
  FROM `gameobject` g
  WHERE g.`map` = 750 AND g.`zoneId` <> 0
  GROUP BY g.`id`, g.`zoneId`
) v
WHERE v.rn = 1;

-- ---------------------------------------------------------------------------
-- Trailer -- verification (expected: zero unresolved, per-zone counts sane,
-- Felwood no longer empty; low-share list short and border-shaped)
-- ---------------------------------------------------------------------------
-- SELECT zoneId, COUNT(*) FROM creature WHERE map = 750 GROUP BY zoneId;
-- SELECT zoneId, COUNT(*) FROM gameobject WHERE map = 750 GROUP BY zoneId;
-- SELECT COUNT(*) FROM creature WHERE map = 750 AND zoneId = 0;   -- want ~0;
-- SELECT COUNT(*) FROM gameobject WHERE map = 750 AND zoneId = 0; -- leftovers
--   are spawns > 400 yd from any cata-classified chunk (deep water/buffer) --
--   harmless, the core recomputes their zone from terrain at load. List them:
-- SELECT guid, id, position_x, position_y FROM creature
-- WHERE map = 750 AND zoneId = 0;
-- SELECT * FROM dc_map750_entryzone WHERE share < 0.9 ORDER BY share;
