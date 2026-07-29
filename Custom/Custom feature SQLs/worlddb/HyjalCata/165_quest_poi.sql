-- ---------------------------------------------------------------------------
-- 165  Hyjal round-31 -- quest POI (the map markers) were never ported
-- ---------------------------------------------------------------------------
-- Question asked: do the map-750 quests have POI data?  No -- and it exists in
-- the source, so this is a pure import rather than authoring.
--
--     508 downported Hyjal/Molten Front quests
--     0    quest_poi rows with MapID = 750 or WorldMapAreaId = 1216
--     0    quest_poi rows for any of the 39 Molten Front quests
--     507  of the 508 HAVE POI data in cata_world (951 rows)
--
-- Without these the objective arrow, the yellow blobs on the world map and the
-- minimap tracking all do nothing for the entire zone -- the quests work but
-- give no navigation.
--
-- WHAT IS IMPORTED
--   Only the two blocks whose points genuinely land in this content:
--     Cata MapID 1  / WorldMapAreaID 606 "Hyjal"           363 rows, 177 quests
--     Cata MapID 1  / WorldMapAreaID 683 "Hyjal_terrain1"    3 rows,   2 quests
--     Cata MapID 861/ WorldMapAreaID 795 "Molten Front"    115 rows,  50 quests
--   = 481 POI rows across ~227 quests.
--
--   All 366 Hyjal-side rows were checked to have at least one point inside the
--   map-750 terrain box (x 3200..8000, y -5334..-533); none is a stray.
--
-- WHAT IS DELIBERATELY NOT IMPORTED
--   The same query also matches ~450 rows on Cata MapID 0 (WorldMapAreaID 22,
--   23, 15, 301, 29 ...).  Those are NOT Hyjal objectives -- they are unrelated
--   vanilla quests that happen to share a quest id with a Cata one, and only 22
--   of 218 rows in the largest group have a point anywhere near this terrain.
--   Importing them would scatter markers across Azeroth.  Matching by quest id
--   alone is not sufficient here; the MapID/WorldMapAreaID pair is what makes
--   the selection safe.
--
-- COORDINATE FRAME
--   Unchanged.  quest_poi_points stores world X/Y as integers, and map 750
--   reuses Cata's Kalimdor frame for this region -- the same reason 155_ copies
--   spawn coordinates verbatim.  Only MapID and WorldMapAreaId are rewritten:
--     Cata map 1,  WMA 606/683  ->  map 750, WMA 1216 (DC "Mount Hyjal")
--     Cata map 861, WMA 795     ->  map 861, WMA 1255 (DC "MoltenFront")
--
--   The DC WorldMapArea ids come from Custom/CSV DBC/WorldMapArea.csv rows 1216
--   and 1255.  1216's Loc bounds were corrected in the same session (they were
--   a 1:1 square taken from the raw ADT extent instead of Cata's 3:2 box, which
--   put the player marker 26% too far south) -- POI blobs are projected through
--   exactly those bounds, so this import only lines up if that fix is deployed.
--
-- SCHEMA NOTE: cata_world.quest_poi keys its blob as (QuestID, BlobIndex, Idx1)
-- while this fork uses (QuestID, id).  `Idx1` is the value quest_poi_points
-- joins on, so `id` <- `Idx1` is the correct mapping, not BlobIndex.
--
-- Idempotent.
-- ---------------------------------------------------------------------------

DELETE FROM `quest_poi_points`
WHERE `QuestID` IN (SELECT `QuestID` FROM cata_world.quest_poi
                    WHERE (`MapID` = 1 AND `WorldMapAreaID` IN (606, 683))
                       OR (`MapID` = 861 AND `WorldMapAreaID` = 795));

DELETE FROM `quest_poi`
WHERE `QuestID` IN (SELECT `QuestID` FROM cata_world.quest_poi
                    WHERE (`MapID` = 1 AND `WorldMapAreaID` IN (606, 683))
                       OR (`MapID` = 861 AND `WorldMapAreaID` = 795));

INSERT INTO `quest_poi`
  (`QuestID`,`id`,`ObjectiveIndex`,`MapID`,`WorldMapAreaId`,`Floor`,`Priority`,`Flags`,`VerifiedBuild`)
SELECT cp.`QuestID`, cp.`Idx1`, cp.`ObjectiveIndex`,
       CASE WHEN cp.`MapID` = 861 THEN 861 ELSE 750 END,
       CASE WHEN cp.`MapID` = 861 THEN 1255 ELSE 1216 END,
       cp.`Floor`, cp.`Priority`, cp.`Flags`, 0
FROM cata_world.quest_poi cp
WHERE ((cp.`MapID` = 1 AND cp.`WorldMapAreaID` IN (606, 683))
    OR (cp.`MapID` = 861 AND cp.`WorldMapAreaID` = 795))
  AND EXISTS (SELECT 1 FROM `quest_template` q WHERE q.`ID` = cp.`QuestID`);

INSERT INTO `quest_poi_points` (`QuestID`,`Idx1`,`Idx2`,`X`,`Y`,`VerifiedBuild`)
SELECT pt.`QuestID`, pt.`Idx1`, pt.`Idx2`, pt.`X`, pt.`Y`, 0
FROM cata_world.quest_poi_points pt
WHERE EXISTS (SELECT 1 FROM `quest_poi` p
              WHERE p.`QuestID` = pt.`QuestID` AND p.`id` = pt.`Idx1`
                AND p.`MapID` IN (750, 861));

-- ---------------------------------------------------------------------------
-- STATIC POIs (the permanent map flags: towns, camps, flight points)
-- ---------------------------------------------------------------------------
-- `points_of_interest` has ZERO rows anywhere inside the map-750 terrain box,
-- so the world map has no place labels of its own beyond what the map ART
-- draws.  Cata stores these in the client's AreaPOI.dbc rather than the world
-- DB, and the fork's AreaPOI already carries 768 rows (30 more than the client
-- had before this session's enGB-3 refresh), so the labels visible on the Hyjal
-- map are coming from there.  Nothing to import server-side; noted so the
-- question is answered rather than left open.
-- ---------------------------------------------------------------------------
