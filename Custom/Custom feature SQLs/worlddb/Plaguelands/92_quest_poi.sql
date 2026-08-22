-- 92_quest_poi.sql -- map 751 Lordaeron extension, DB step 31.
--
-- Quest POIs: the objective circles the world map draws. `quest_poi` had **0 rows
-- for MapID 751** -- not one quest on the continent showed an objective marker.
--
-- ===========================================================================
-- THE CONSTRAINT THAT SHAPES THIS FILE -- READ BEFORE WIDENING THE SCOPE
--
-- `quest_poi` is keyed by QuestID (+ blob index) and has no per-map variant, so
-- **a quest can only have ONE set of POIs anywhere in the world.** Map 751 reuses
-- stock quest ids, and many of its quests are ALSO handed out by ordinary NPCs in
-- the real Eastern Kingdoms.
--
--     map-751 quests, total .............................. 1135
--       also given by a stock (non-band) NPC ..............  337   <-- NOT TOUCHED
--       exclusive to map 751 ..............................  798
--         of those, Cata has POIs inside Lordaeron .........  402   <-- this file
--
-- Repointing a shared quest at map 751 would move its marker off the stock version,
-- so the 337 are deliberately left alone. Nothing in this schema can satisfy both;
-- doing so would mean giving map 751 its own quest ids, which is a far larger change
-- than a POI import.
--
-- Of the 402 handled here, **333 already had POIs pointing at MapID 0** even though
-- the quest exists only on 751 -- those markers were landing on the real Eastern
-- Kingdoms map, where the player cannot go. Replacing them is a fix, not a risk.
--
-- ===========================================================================
-- HOW THE ZONE IS DECIDED
--
-- Not by translating Cata WorldMapArea ids: `cata_world` has no WMA table, and Cata
-- renumbered them anyway (its quest_poi uses 34 distinct WMA ids that do not line up
-- with 3.3.5's). Each POI blob is instead classified by **the centroid of its own
-- points**, tested against the eight map-751 zone boxes. That needs no cross-version
-- id table and is self-checking -- a blob whose points are not in Lordaeron simply
-- does not import.
--
-- The zone boxes overlap, so they are tested SMALLEST FIRST (Gilneas 6.6M sq yd
-- through Tirisfal 13.6M) and the first containing box wins: the most specific
-- answer rather than whichever the optimiser happened to reach.
--
-- Only Cata POIs on **MapID 0** are considered. These quests also carry POIs on maps
-- 1/30/90/189/389/529/530/571 -- objectives genuinely elsewhere -- and those are
-- skipped rather than imported, because their WorldMapAreaID is a Cata id with no
-- verified 3.3.5 counterpart. A quest with objectives both in Lordaeron and abroad
-- therefore gets its Lordaeron markers only, which beats shipping a wrong one.
--
-- COLUMN TRAP: cata `quest_poi` has BOTH `BlobIndex` and `Idx1`, and **they differ
-- on 3,643 rows table-wide -- 100 of them inside this very selection**. Our `quest_poi`.`id` is the key `quest_poi_points`.`Idx1` joins
-- against, so it must come from Cata's **Idx1**. Taking BlobIndex would silently
-- orphan every point.
--
-- X/Y in quest_poi_points are WORLD coordinates, and map 751 preserves Eastern
-- Kingdoms coordinates, so they copy across untouched.
-- ===========================================================================

DELETE FROM `quest_poi_points` WHERE `QuestID` IN (
  SELECT z.q FROM (
    SELECT `quest` AS q FROM `creature_queststarter` WHERE `id` BETWEEN 3600000 AND 3699999 OR `id` BETWEEN 4100000 AND 4199999
    UNION SELECT `quest` FROM `creature_questender` WHERE `id` BETWEEN 3600000 AND 3699999 OR `id` BETWEEN 4100000 AND 4199999) z
  WHERE NOT EXISTS (SELECT 1 FROM `creature_queststarter` s WHERE s.`quest` = z.q AND s.`id` < 3600000)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender`   e WHERE e.`quest` = z.q AND e.`id` < 3600000)
    AND EXISTS (SELECT 1 FROM `cata_world`.`quest_poi` p WHERE p.`QuestID` = z.q AND p.`MapID` = 0));

DELETE FROM `quest_poi` WHERE `QuestID` IN (
  SELECT z.q FROM (
    SELECT `quest` AS q FROM `creature_queststarter` WHERE `id` BETWEEN 3600000 AND 3699999 OR `id` BETWEEN 4100000 AND 4199999
    UNION SELECT `quest` FROM `creature_questender` WHERE `id` BETWEEN 3600000 AND 3699999 OR `id` BETWEEN 4100000 AND 4199999) z
  WHERE NOT EXISTS (SELECT 1 FROM `creature_queststarter` s WHERE s.`quest` = z.q AND s.`id` < 3600000)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender`   e WHERE e.`quest` = z.q AND e.`id` < 3600000)
    AND EXISTS (SELECT 1 FROM `cata_world`.`quest_poi` p WHERE p.`QuestID` = z.q AND p.`MapID` = 0));

-- ---------------------------------------------------------------------------
-- 1. quest_poi -- 857 blobs, MapID 0 -> 751, zone from the points' centroid
-- ---------------------------------------------------------------------------
INSERT INTO `quest_poi`
  (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT p.`QuestID`, p.`Idx1`, p.`ObjectiveIndex`, 751,
       CASE
         WHEN c.mx BETWEEN -2631 AND  -533 AND c.my BETWEEN   294 AND  3440 THEN 1274
         WHEN c.mx BETWEEN -1733 AND   400 AND c.my BETWEEN -2133 AND  1067 THEN 1271
         WHEN c.mx BETWEEN -2533 AND  -133 AND c.my BETWEEN -4467 AND  -867 THEN 1273
         WHEN c.mx BETWEEN -1100 AND  1467 AND c.my BETWEEN -5425 AND -1575 THEN 1272
         WHEN c.mx BETWEEN  1017 AND  3704 AND c.my BETWEEN -6319 AND -2288 THEN 1217
         WHEN c.mx BETWEEN -1133 AND  1667 AND c.my BETWEEN  -750 AND  3450 THEN 1270
         WHEN c.mx BETWEEN   500 AND  3367 AND c.my BETWEEN -3883 AND   417 THEN 1268
         ELSE 1269
       END,
       p.`Floor`, p.`Priority`, p.`Flags`, p.`VerifiedBuild`
FROM `cata_world`.`quest_poi` p
JOIN (SELECT `QuestID`, `Idx1`, AVG(`X`) AS mx, AVG(`Y`) AS my
      FROM `cata_world`.`quest_poi_points` GROUP BY `QuestID`, `Idx1`) c
  ON c.`QuestID` = p.`QuestID` AND c.`Idx1` = p.`Idx1`
JOIN (SELECT z.q AS QuestID FROM (
        SELECT `quest` AS q FROM `creature_queststarter` WHERE `id` BETWEEN 3600000 AND 3699999 OR `id` BETWEEN 4100000 AND 4199999
        UNION SELECT `quest` FROM `creature_questender` WHERE `id` BETWEEN 3600000 AND 3699999 OR `id` BETWEEN 4100000 AND 4199999) z
      WHERE NOT EXISTS (SELECT 1 FROM `creature_queststarter` s WHERE s.`quest` = z.q AND s.`id` < 3600000)
        AND NOT EXISTS (SELECT 1 FROM `creature_questender`   e WHERE e.`quest` = z.q AND e.`id` < 3600000)) q751
  ON q751.`QuestID` = p.`QuestID`
WHERE p.`MapID` = 0
  AND (   (c.mx BETWEEN -2631 AND  -533 AND c.my BETWEEN   294 AND  3440)
       OR (c.mx BETWEEN -1733 AND   400 AND c.my BETWEEN -2133 AND  1067)
       OR (c.mx BETWEEN -2533 AND  -133 AND c.my BETWEEN -4467 AND  -867)
       OR (c.mx BETWEEN -1100 AND  1467 AND c.my BETWEEN -5425 AND -1575)
       OR (c.mx BETWEEN  1017 AND  3704 AND c.my BETWEEN -6319 AND -2288)
       OR (c.mx BETWEEN -1133 AND  1667 AND c.my BETWEEN  -750 AND  3450)
       OR (c.mx BETWEEN   500 AND  3367 AND c.my BETWEEN -3883 AND   417)
       OR (c.mx BETWEEN   825 AND  3838 AND c.my BETWEEN -1485 AND  3033));

-- ---------------------------------------------------------------------------
-- 2. quest_poi_points -- 2,994 points, coordinates verbatim.
--    Driven off the rows section 1 just wrote, so the two can never disagree.
-- ---------------------------------------------------------------------------
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT pt.`QuestID`, pt.`Idx1`, pt.`Idx2`, pt.`X`, pt.`Y`, pt.`VerifiedBuild`
FROM `cata_world`.`quest_poi_points` pt
WHERE EXISTS (SELECT 1 FROM `quest_poi` o
              WHERE o.`QuestID` = pt.`QuestID` AND o.`id` = pt.`Idx1` AND o.`MapID` = 751);

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'quest_poi rows on map 751 (want 857)' AS what, COUNT(*) AS n FROM `quest_poi` WHERE `MapID` = 751
UNION ALL SELECT '  ...distinct quests covered (want 402)', COUNT(DISTINCT `QuestID`) FROM `quest_poi` WHERE `MapID` = 751
UNION ALL SELECT 'quest_poi_points for those blobs (want 2994)', COUNT(*)
FROM `quest_poi_points` pt WHERE EXISTS (SELECT 1 FROM `quest_poi` o
  WHERE o.`QuestID` = pt.`QuestID` AND o.`id` = pt.`Idx1` AND o.`MapID` = 751)
UNION ALL SELECT 'distinct WorldMapAreaId used (want 8)', COUNT(DISTINCT `WorldMapAreaId`)
FROM `quest_poi` WHERE `MapID` = 751;

-- must be empty: a WorldMapAreaId on map 751 that is not one of our eight zone rows
SELECT 'PROBLEM: unknown WorldMapAreaId' AS problem, `WorldMapAreaId`, COUNT(*) AS n
FROM `quest_poi` WHERE `MapID` = 751
  AND `WorldMapAreaId` NOT IN (1217, 1268, 1269, 1270, 1271, 1272, 1273, 1274)
GROUP BY `WorldMapAreaId`;

-- must be empty: a blob with no points -- it draws nothing and is pure noise
SELECT 'PROBLEM: blob with no points' AS problem, o.`QuestID`, o.`id`
FROM `quest_poi` o WHERE o.`MapID` = 751
  AND NOT EXISTS (SELECT 1 FROM `quest_poi_points` pt
                  WHERE pt.`QuestID` = o.`QuestID` AND pt.`Idx1` = o.`id`);

-- must be empty: we repointed a quest that stock content also hands out, which would
-- move its marker off the real Eastern Kingdoms copy
SELECT 'PROBLEM: repointed a shared quest' AS problem, o.`QuestID`
FROM `quest_poi` o WHERE o.`MapID` = 751
  AND (EXISTS (SELECT 1 FROM `creature_queststarter` s WHERE s.`quest` = o.`QuestID` AND s.`id` < 3600000)
    OR EXISTS (SELECT 1 FROM `creature_questender`   e WHERE e.`quest` = o.`QuestID` AND e.`id` < 3600000));
