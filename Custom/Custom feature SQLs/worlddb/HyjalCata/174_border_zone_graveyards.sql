-- ---------------------------------------------------------------------------
-- 174  Hyjal round-41 -- graveyards for the six border zones
-- ---------------------------------------------------------------------------
-- Found while auditing zone-integration completeness: `graveyard_zone` links
-- exist only for 4923 (Hyjal, 5 links) and 4924 (Plaguelands).  The six border
-- zones 4926-4931 have NONE -- dying in Everlook leaves the corpse run with no
-- graveyard to resolve to (the core logs an error and falls back badly).
--
-- Ten stock graveyards fall inside the map-750 terrain box (six Winterspring,
-- two Felwood, one Moonglade, one Azshara).  They are cloned onto map 750 at
-- ids 15020+ -- the map-750 block already uses 15013-15018, and coordinates
-- carry over verbatim because the terrain is a coordinate-preserving copy.
--
-- LINKING STRATEGY: every border zone is linked to EVERY map-750 graveyard
-- (the 5 existing Hyjal ones + the 10 clones), faction 0.  The core picks the
-- NEAREST linked graveyard at death, so blanket links are self-correcting and
-- sidestep assigning graveyards to zones by hand -- a Winterspring death
-- resolves to a Winterspring graveyard because it is closest, not because a
-- table says so.  4923's five existing links are left untouched but Hyjal is
-- NOT blanket-linked to the new clones: its corpse runs already work and
-- changing which graveyard wins there is not this file's business.
--
-- Idempotent: fixed id range, deleted before insert.
-- ---------------------------------------------------------------------------

DELETE FROM `game_graveyard` WHERE `ID` BETWEEN 15020 AND 15029;
INSERT INTO `game_graveyard` (`ID`, `Map`, `x`, `y`, `z`, `Comment`)
SELECT 15020 + n.`rn`, 750, g.`x`, g.`y`, g.`z`, CONCAT('DC750 ', g.`Comment`)
FROM `game_graveyard` g
JOIN (SELECT 449 id, 0 rn UNION SELECT 511, 1 UNION SELECT 633, 2 UNION SELECT 635, 3
      UNION SELECT 1283, 4 UNION SELECT 1284, 5 UNION SELECT 1416, 6 UNION SELECT 1417, 7
      UNION SELECT 1418, 8 UNION SELECT 1420, 9) n ON n.`id` = g.`ID`
WHERE g.`Map` = 1;

DELETE FROM `graveyard_zone` WHERE `GhostZone` IN (4926, 4927, 4928, 4929, 4930, 4931);
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`)
SELECT g.`ID`, z.`zone`, 0
FROM `game_graveyard` g
JOIN (SELECT 4926 zone UNION SELECT 4927 UNION SELECT 4928 UNION SELECT 4929
      UNION SELECT 4930 UNION SELECT 4931) z
WHERE g.`Map` = 750;

-- Verify -- expect 10 and 90 (15 graveyards x 6 zones):
--   SELECT COUNT(*) FROM `game_graveyard` WHERE `ID` BETWEEN 15020 AND 15029;
--   SELECT COUNT(*) FROM `graveyard_zone` WHERE `GhostZone` IN (4926,4927,4928,4929,4930,4931);
