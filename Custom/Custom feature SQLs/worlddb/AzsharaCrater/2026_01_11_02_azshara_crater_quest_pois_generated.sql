-- ============================================================================
-- Azshara Crater Quest POI Generator - COMPLETE
-- ============================================================================
-- Generated automatically for all Azshara Crater quests
-- Map: 37 | Zone: 268
-- ============================================================================

DELETE FROM `quest_poi` WHERE `QuestID` BETWEEN 300100 AND 300966;
DELETE FROM `quest_poi_points` WHERE `QuestID` BETWEEN 300100 AND 300966;

-- ============================================================================
-- POI Generation
-- ============================================================================

-- Quest 300101
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300101, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 1984 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300101, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 1984
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300101, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300002 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300101, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300002 LIMIT 1;

-- Quest 300102
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300102, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 822 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300102, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 822
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300102, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300002 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300102, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300002 LIMIT 1;

-- Quest 300103
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300103, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 2022 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300103, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 2022
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300103, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300001 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300103, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300001 LIMIT 1;

-- Quest 300104
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300104, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 1998 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300104, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 1998
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300104, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300002 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300104, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300002 LIMIT 1;

-- Quest 300105
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300105, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 2022 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300105, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 2022
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300105, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300002 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300105, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300002 LIMIT 1;

-- Quest 300108
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300108, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 46 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300108, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 46
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300108, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300001 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300108, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300001 LIMIT 1;

-- Quest 300106
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300106, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300010 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300106, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300010 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300106, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300010 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300106, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300010 LIMIT 1;

-- Quest 300200
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300200, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 16303 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300200, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 16303
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300200, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300010 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300200, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300010 LIMIT 1;

-- Quest 300201
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300201, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 418 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300201, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 418
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300201, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300010 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300201, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300010 LIMIT 1;

-- Quest 300202
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300202, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 36 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300202, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 36
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300202, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300010 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300202, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300010 LIMIT 1;

-- Quest 300204
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300204, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 48 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300204, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 48
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300204, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300011 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300204, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300011 LIMIT 1;

-- Quest 300205
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300205, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 16303 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300205, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 16303
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300205, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300011 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300205, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300011 LIMIT 1;

-- Quest 300208
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300208, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 5897 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300208, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 5897
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300208, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300010 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300208, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300010 LIMIT 1;

-- Quest 300203
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300203, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300011 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300203, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300011 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300203, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300011 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300203, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300011 LIMIT 1;

-- Quest 300206
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300206, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300206, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300206, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300206, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

-- Quest 300300
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300300, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 2044 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300300, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 2044
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300300, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300300, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

-- Quest 300302
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300302, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 3922 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300302, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 3922
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300302, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300302, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

-- Quest 300303
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300303, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 3924 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300303, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 3924
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300303, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300303, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

-- Quest 300304
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300304, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 3925 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300304, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 3925
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300304, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300304, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

-- Quest 300305
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300305, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 3926 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300305, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 3926
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300305, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300305, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

-- Quest 300308
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300308, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 2089 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300308, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 2089
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300308, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300308, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300020 LIMIT 1;

-- Quest 300306
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300306, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300001 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300306, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300001 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300306, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300001 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300306, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300001 LIMIT 1;

-- Quest 300400
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300400, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6190 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300400, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6190
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300400, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300030 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300400, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300030 LIMIT 1;

-- Quest 300401
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300401, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6348 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300401, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6348
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300401, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300030 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300401, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300030 LIMIT 1;

-- Quest 300402
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300402, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 11467 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300402, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 11467
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300402, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300030 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300402, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300030 LIMIT 1;

-- Quest 300403
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300403, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6129 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300403, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6129
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300403, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300030 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300403, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300030 LIMIT 1;

-- Quest 300404
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300404, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 2779 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300404, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 2779
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300404, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300030 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300404, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300030 LIMIT 1;

-- Quest 300405
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300405, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300405, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300405, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300405, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

-- Quest 300500
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300500, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 11791 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300500, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 11791
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300500, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300500, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

-- Quest 300501
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300501, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 5865 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300501, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 5865
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300501, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300501, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

-- Quest 300502
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300502, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 11464 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300502, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 11464
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300502, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300502, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

-- Quest 300503
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300503, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 11452 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300503, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 11452
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300503, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300503, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

-- Quest 300504
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300504, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6144 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300504, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6144
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300504, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300504, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300040 LIMIT 1;

-- Quest 300505
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300505, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300050 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300505, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300050 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300505, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300050 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300505, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300050 LIMIT 1;

-- Quest 300600
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300600, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6200 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300600, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6200
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300600, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300050 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300600, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300050 LIMIT 1;

-- Quest 300602
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300602, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 7671 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300602, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 7671
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300602, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300050 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300602, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300050 LIMIT 1;

-- Quest 300603
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300603, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 10831 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300603, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 10831
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300603, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300050 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300603, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300050 LIMIT 1;

-- Quest 300605
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300605, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 8716 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300605, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 8716
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300605, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300050 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300605, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300050 LIMIT 1;

-- Quest 300604
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300604, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300060 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300604, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300060 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300604, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300060 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300604, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300060 LIMIT 1;

-- Quest 300700
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300700, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6130 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300700, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6130
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300700, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300060 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300700, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300060 LIMIT 1;

-- Quest 300701
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300701, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 15527 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300701, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 15527
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300701, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300060 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300701, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300060 LIMIT 1;

-- Quest 300702
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300702, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 23456 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300702, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 23456
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300702, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300060 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300702, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300060 LIMIT 1;

-- Quest 300703
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300703, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 10196 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300703, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 10196
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300703, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300060 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300703, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300060 LIMIT 1;

-- Quest 300704
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300704, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300070 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300704, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300070 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300704, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300070 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300704, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300070 LIMIT 1;

-- Quest 300800
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300800, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 32164 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300800, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 32164
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300800, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300070 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300800, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300070 LIMIT 1;

-- Quest 300801
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300801, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 31691 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300801, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 31691
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300801, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300070 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300801, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300070 LIMIT 1;

-- Quest 300802
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300802, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 27220 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300802, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 27220
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300802, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300070 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300802, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300070 LIMIT 1;

-- Quest 300803
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300803, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6910 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300803, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6910
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300803, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300070 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300803, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300070 LIMIT 1;

-- Quest 300900
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300900, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 4831 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300900, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 4831
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300900, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300081 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300900, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300081 LIMIT 1;

-- Quest 300901
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300901, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 1716 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300901, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 1716
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300901, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300081 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300901, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300081 LIMIT 1;

-- Quest 300950
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300950, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300081 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300950, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300081 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300950, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300081 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300950, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300081 LIMIT 1;

-- Quest 300910
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300910, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 4424 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300910, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 4424
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300910, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300082 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300910, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300082 LIMIT 1;

-- Quest 300911
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300911, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 4428 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300911, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 4428
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300911, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300082 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300911, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300082 LIMIT 1;

-- Quest 300912
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300912, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 1012 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300912, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 1012
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300912, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300082 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300912, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300082 LIMIT 1;

-- Quest 300951
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300951, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300082 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300951, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300082 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300951, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300082 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300951, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300082 LIMIT 1;

-- Quest 300920
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300920, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 9024 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300920, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 9024
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300920, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300083 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300920, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300083 LIMIT 1;

-- Quest 300921
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300921, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 8637 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300921, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 8637
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300921, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300083 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300921, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300083 LIMIT 1;

-- Quest 300922
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300922, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 8279 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300922, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 8279
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300922, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300083 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300922, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300083 LIMIT 1;

-- Quest 300923
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300923, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 9156 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300923, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 9156
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300923, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300083 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300923, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300083 LIMIT 1;

-- Quest 300952
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300952, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300083 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300952, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300083 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300952, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300083 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300952, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300083 LIMIT 1;

-- Quest 300930
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300930, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 11486 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300930, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 11486
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300930, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300930, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

-- Quest 300931
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300931, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 12143 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300931, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 12143
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300931, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300931, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

-- Quest 300932
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300932, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 19261 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300932, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 19261
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300932, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300932, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

-- Quest 300933
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300933, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 18044 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300933, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 18044
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300933, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300933, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

-- Quest 300934
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300934, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6135 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300934, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6135
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300934, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300934, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

-- Quest 300953
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300953, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300953, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300953, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300953, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300084 LIMIT 1;

-- Quest 300940
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300940, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 24560 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300940, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 24560
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300940, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300940, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

-- Quest 300941
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300941, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 4832 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300941, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 4832
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300941, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300941, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

-- Quest 300942
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300942, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 16485 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300942, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 16485
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300942, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300942, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

-- Quest 300943
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300943, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 14515 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300943, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 14515
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300943, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300943, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

-- Quest 300944
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300944, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 10683 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300944, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 10683
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300944, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300944, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

-- Quest 300945
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300945, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 15467 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300945, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 15467
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300945, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300945, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

-- Quest 300946
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300946, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 13019 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300946, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 13019
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300946, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300946, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

-- Quest 300955
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300955, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300955, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300955, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300955, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300085 LIMIT 1;

-- Quest 300960
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300960, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 29317 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300960, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 29317
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300960, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300960, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

-- Quest 300961
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300961, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 11487 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300961, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 11487
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300961, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300961, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

-- Quest 300962
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300962, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 27959 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300962, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 27959
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300962, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300962, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

-- Quest 300963
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300963, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 15689 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300963, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 15689
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300963, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300963, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

-- Quest 300964
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300964, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 37881 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300964, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 37881
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300964, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300964, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

-- Quest 300965
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300965, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6116 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300965, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 6116
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300965, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300965, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

-- Quest 300966
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300966, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 27099 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300966, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c WHERE c.map = 37 AND c.id1 = 27099
HAVING AVG(c.position_x) IS NOT NULL;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300966, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300966, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

-- Quest 300954
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300954, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300954, 0, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT 300954, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT 300954, 1, 0, c.position_x, c.position_y, 0
FROM creature c WHERE c.map = 37 AND c.id1 = 300086 LIMIT 1;

-- ============================================================================
-- Verification Queries
-- ============================================================================

SELECT 
    qp.QuestID,
    qt.LogTitle as QuestName,
    qp.id as POI_ID,
    qp.ObjectiveIndex,
    qpp.X,
    qpp.Y
FROM quest_poi qp
JOIN quest_template qt ON qp.QuestID = qt.ID
LEFT JOIN quest_poi_points qpp ON qp.QuestID = qpp.QuestID AND qp.id = qpp.Idx1
WHERE qp.QuestID BETWEEN 300100 AND 300966
ORDER BY qp.QuestID, qp.id;

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================