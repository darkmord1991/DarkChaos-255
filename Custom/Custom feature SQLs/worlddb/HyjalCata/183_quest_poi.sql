-- ---------------------------------------------------------------------------
-- 183  Hyjal round-45 -- quest POI (map markers) for map 750
-- ---------------------------------------------------------------------------
-- 123 of the 642 quests offered on map 750 had no quest_poi rows, so their
-- objectives drew no marker on the world map or minimap.  cata_world has POI
-- for 120 of them.
--
-- TWO REMAPS ARE MANDATORY, and skipping either puts markers on the wrong map:
--
--  1. MapID 1 (Kalimdor) -> 750.  Map 750 is a coordinate-preserving Kalimdor
--     copy, so the X/Y in quest_poi_points carry over untouched -- only the map
--     id changes.
--  2. WorldMapAreaID: cata's Kalimdor WMA ids -> our map-750 rows.
--        Azshara     181 -> 1260      Darkshore     42 -> 1259
--        Ashenvale    43 -> 1261      Felwood      182 -> 1257
--        Moonglade   241 -> 1258      Hyjal        606 -> 1216
--        Winterspring 281 -> 1256
--
-- INDEX COLUMN: cata's quest_poi has BOTH `BlobIndex` and `Idx1` and they
-- DIFFER in 3,643 of 29,528 rows.  `Idx1` is the one quest_poi_points keys on --
-- verified set-wise: joining points via Idx1 leaves 0 orphans, joining via
-- BlobIndex leaves 2,227.  Our schema calls that column `id`.
--
-- Rows whose WorldMapAreaID is NOT one of the seven are DROPPED, not remapped:
-- those objectives sit in Kalimdor proper (Stonetalon, Orgrimmar, Darnassus),
-- off our map, and a marker pointing at unreachable ground is worse than none.
-- That is why ~15 quests still end up with no POI rather than 3.
--
-- PURELY ADDITIVE, NO DELETES.  The first revision of this file opened with
--   DELETE FROM `quest_poi` WHERE `QuestID` IN (... SELECT FROM `quest_poi`)
-- which is MySQL error 1093 -- you cannot read the DELETE target in a subquery.
-- It is not merely rewritten but REMOVED: map 750 already carries 1,543 POI
-- rows across 727 quests from earlier rounds, and any delete broad enough to
-- clean this file's own rows would take those with it.  Every INSERT below is
-- guarded by NOT EXISTS instead, which makes the file idempotent AND safe to
-- re-run over the partially-applied state (INSERT...SELECT may read its own
-- target table; only UPDATE/DELETE may not).
-- ---------------------------------------------------------------------------

INSERT INTO `quest_poi`
  (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT p.`QuestID`, p.`Idx1`, p.`ObjectiveIndex`, 750,
       CASE p.`WorldMapAreaID`
         WHEN 181 THEN 1260 WHEN  42 THEN 1259 WHEN  43 THEN 1261
         WHEN 182 THEN 1257 WHEN 241 THEN 1258 WHEN 606 THEN 1216
         WHEN 281 THEN 1256 END,
       p.`Floor`, p.`Priority`, p.`Flags`, 0
FROM cata_world.quest_poi p
WHERE p.`MapID` = 1
  AND p.`WorldMapAreaID` IN (181, 42, 43, 182, 241, 606, 281)
  AND p.`QuestID` IN (SELECT DISTINCT qs.`quest` FROM acore_world.creature_queststarter qs
                      JOIN acore_world.creature c ON c.`id` = qs.`id` WHERE c.`map` = 750)
  AND NOT EXISTS (SELECT 1 FROM acore_world.quest_poi ex
                  WHERE ex.`QuestID` = p.`QuestID` AND ex.`id` = p.`Idx1`);

-- Points carry over verbatim (identical schema, X/Y need no transform).
-- The NOT EXISTS guard is what the first revision lacked: it aborted with 1062
-- 'Duplicate entry 13504-0-0' because many map-750 POI rows from earlier rounds
-- already have their points, and the join pulled those in again.
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT pt.`QuestID`, pt.`Idx1`, pt.`Idx2`, pt.`X`, pt.`Y`, 0
FROM cata_world.quest_poi_points pt
JOIN acore_world.quest_poi ap
  ON ap.`QuestID` = pt.`QuestID` AND ap.`id` = pt.`Idx1` AND ap.`MapID` = 750
WHERE NOT EXISTS (SELECT 1 FROM acore_world.quest_poi_points ex
                  WHERE ex.`QuestID` = pt.`QuestID`
                    AND ex.`Idx1` = pt.`Idx1` AND ex.`Idx2` = pt.`Idx2`);

-- Verify -- expect 0 POI blobs left without points, and ~15 quests still
-- without POI (their objectives are off-map, see the header):
--   SELECT COUNT(*) FROM `quest_poi` ap WHERE ap.MapID = 750
--     AND NOT EXISTS (SELECT 1 FROM `quest_poi_points` pt
--                     WHERE pt.QuestID = ap.QuestID AND pt.Idx1 = ap.id);
--   SELECT COUNT(DISTINCT qs.quest) FROM `creature_queststarter` qs
--     JOIN `creature` c ON c.id = qs.id
--    WHERE c.map = 750 AND qs.quest NOT IN (SELECT QuestID FROM `quest_poi`);
