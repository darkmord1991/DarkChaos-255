-- Replace Corrupt Water Spirit (5897) with Fouled Water Spirit (17358)
-- for Azshara Crater map 37, update quest 300208, and rebuild its POI rows.

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 1) Sanity checks
-- -----------------------------------------------------------------------------
SELECT entry, name, minlevel, maxlevel, faction,
       creature_template.rank AS rank_value
FROM creature_template
WHERE entry IN (5897, 17358);

SELECT COUNT(*) AS old_spawn_count
FROM creature
WHERE map = 37
  AND (id1 = 5897 OR id2 = 5897 OR id3 = 5897);

SELECT ID, LogTitle, QuestLevel, MinLevel,
       RequiredNpcOrGo1, RequiredNpcOrGoCount1,
       RequiredNpcOrGo2, RequiredNpcOrGoCount2,
       RequiredNpcOrGo3, RequiredNpcOrGoCount3,
       RequiredNpcOrGo4, RequiredNpcOrGoCount4,
       LogDescription, QuestCompletionLog
FROM quest_template
WHERE ID = 300208;

-- -----------------------------------------------------------------------------
-- 2) 1:1 spawn replacement on map 37
-- -----------------------------------------------------------------------------
UPDATE creature
SET
    id1 = IF(id1 = 5897, 17358, id1),
    id2 = IF(id2 = 5897, 17358, id2),
    id3 = IF(id3 = 5897, 17358, id3)
WHERE map = 37
  AND (id1 = 5897 OR id2 = 5897 OR id3 = 5897);

-- -----------------------------------------------------------------------------
-- 3) Quest update (Elemental Imbalance)
-- -----------------------------------------------------------------------------
UPDATE quest_template
SET
    RequiredNpcOrGo1 = IF(RequiredNpcOrGo1 = 5897, 17358, RequiredNpcOrGo1),
    RequiredNpcOrGo2 = IF(RequiredNpcOrGo2 = 5897, 17358, RequiredNpcOrGo2),
    RequiredNpcOrGo3 = IF(RequiredNpcOrGo3 = 5897, 17358, RequiredNpcOrGo3),
    RequiredNpcOrGo4 = IF(RequiredNpcOrGo4 = 5897, 17358, RequiredNpcOrGo4),
    LogDescription = REPLACE(LogDescription, 'Corrupt Water Spirits', 'Fouled Water Spirits'),
    QuestCompletionLog = REPLACE(QuestCompletionLog, 'Corrupt Water Spirits', 'Fouled Water Spirits')
WHERE ID = 300208;

-- -----------------------------------------------------------------------------
-- 4) Rebuild POI rows for quest 300208
-- -----------------------------------------------------------------------------
DELETE FROM quest_poi_points
WHERE QuestID = 300208;

DELETE FROM quest_poi
WHERE QuestID = 300208;

-- Objective POI (target mob cluster)
INSERT INTO quest_poi
(QuestID, id, ObjectiveIndex, MapID, WorldMapAreaId, Floor, Priority, Flags, VerifiedBuild)
SELECT 300208, 0, 0, 37, 268, 0, 0, 3, 0
FROM creature c
WHERE c.map = 37
  AND c.id1 = 17358
LIMIT 1;

INSERT INTO quest_poi_points
(QuestID, Idx1, Idx2, X, Y, VerifiedBuild)
SELECT 300208, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0
FROM creature c
WHERE c.map = 37
  AND c.id1 = 17358
HAVING AVG(c.position_x) IS NOT NULL;

-- Turn-in POI (quest giver 300010)
INSERT INTO quest_poi
(QuestID, id, ObjectiveIndex, MapID, WorldMapAreaId, Floor, Priority, Flags, VerifiedBuild)
SELECT 300208, 1, -1, 37, 268, 0, 0, 1, 0
FROM creature c
WHERE c.map = 37
  AND c.id1 = 300010
LIMIT 1;

INSERT INTO quest_poi_points
(QuestID, Idx1, Idx2, X, Y, VerifiedBuild)
SELECT 300208, 1, 0, c.position_x, c.position_y, 0
FROM creature c
WHERE c.map = 37
  AND c.id1 = 300010
LIMIT 1;

-- -----------------------------------------------------------------------------
-- 5) Post-checks
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS remaining_old_spawns
FROM creature
WHERE map = 37
  AND (id1 = 5897 OR id2 = 5897 OR id3 = 5897);

SELECT COUNT(*) AS new_spawn_count
FROM creature
WHERE map = 37
  AND (id1 = 17358 OR id2 = 17358 OR id3 = 17358);

SELECT ID, LogTitle,
       RequiredNpcOrGo1, RequiredNpcOrGoCount1,
       RequiredNpcOrGo2, RequiredNpcOrGoCount2,
       RequiredNpcOrGo3, RequiredNpcOrGoCount3,
       RequiredNpcOrGo4, RequiredNpcOrGoCount4,
       LogDescription, QuestCompletionLog
FROM quest_template
WHERE ID = 300208;

SELECT QuestID, id, ObjectiveIndex, MapID, WorldMapAreaId, Floor, Priority, Flags
FROM quest_poi
WHERE QuestID = 300208
ORDER BY id;

SELECT QuestID, Idx1, Idx2, X, Y
FROM quest_poi_points
WHERE QuestID = 300208
ORDER BY Idx1, Idx2;

COMMIT;
