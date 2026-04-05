-- Ensure full quest POI coverage for Azshara Crater quests.
-- Scope: QuestSortID 268 plus explicit welcome quest 820056.
-- Strategy:
-- 1) detect quests with no quest_poi rows,
-- 2) insert one objective POI (id 0),
-- 3) insert one POI point using best available coordinate source.

DROP TEMPORARY TABLE IF EXISTS `dc_tmp_azshara_missing_poi_quests`;

CREATE TEMPORARY TABLE `dc_tmp_azshara_missing_poi_quests` (
  `QuestID` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`QuestID`)
) ENGINE=Memory;

INSERT INTO `dc_tmp_azshara_missing_poi_quests` (`QuestID`)
SELECT q.`ID` AS `QuestID`
FROM `quest_template` q
LEFT JOIN `quest_poi` qp
  ON qp.`QuestID` = q.`ID`
WHERE (q.`QuestSortID` = 268 OR q.`ID` = 820056)
GROUP BY q.`ID`
HAVING COUNT(qp.`id`) = 0;

-- Safety: remove any stale point for id 0 on quests we are about to patch.
DELETE qpp
FROM `quest_poi_points` qpp
JOIN `dc_tmp_azshara_missing_poi_quests` m
  ON m.`QuestID` = qpp.`QuestID`
WHERE qpp.`Idx1` = 0;

INSERT INTO `quest_poi`
(`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)
SELECT m.`QuestID`, 0, 0, 37, 268, 0, 0, 3, 0
FROM `dc_tmp_azshara_missing_poi_quests` m;

INSERT INTO `quest_poi_points`
(`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)
SELECT
    m.`QuestID`,
    0,
    0,
    COALESCE(
        (SELECT ROUND(AVG(c.`position_x`))
         FROM `creature` c
         JOIN (
             SELECT qt.`RequiredNpcOrGo1` AS `entry`
             UNION ALL SELECT qt.`RequiredNpcOrGo2`
             UNION ALL SELECT qt.`RequiredNpcOrGo3`
             UNION ALL SELECT qt.`RequiredNpcOrGo4`
         ) req
           ON req.`entry` > 0
          AND c.`id1` = req.`entry`
         WHERE c.`map` = 37),
        (SELECT ROUND(AVG(g.`position_x`))
         FROM `gameobject` g
         JOIN (
             SELECT qt.`RequiredNpcOrGo1` AS `entry`
             UNION ALL SELECT qt.`RequiredNpcOrGo2`
             UNION ALL SELECT qt.`RequiredNpcOrGo3`
             UNION ALL SELECT qt.`RequiredNpcOrGo4`
         ) req
           ON req.`entry` < 0
          AND g.`id` = -req.`entry`
         WHERE g.`map` = 37),
        (SELECT ROUND(AVG(c.`position_x`))
         FROM `creature` c
         WHERE c.`map` = 37
           AND c.`id1` IN (
               SELECT cq.`CreatureEntry`
               FROM `creature_questitem` cq
               WHERE cq.`ItemId` IN (
                   qt.`RequiredItemId1`, qt.`RequiredItemId2`, qt.`RequiredItemId3`,
                   qt.`RequiredItemId4`, qt.`RequiredItemId5`, qt.`RequiredItemId6`
               )
           )),
        (SELECT ROUND(AVG(g.`position_x`))
         FROM `gameobject` g
         WHERE g.`map` = 37
           AND g.`id` IN (
               SELECT gq.`GameObjectEntry`
               FROM `gameobject_questitem` gq
               WHERE gq.`ItemId` IN (
                   qt.`RequiredItemId1`, qt.`RequiredItemId2`, qt.`RequiredItemId3`,
                   qt.`RequiredItemId4`, qt.`RequiredItemId5`, qt.`RequiredItemId6`
               )
           )),
        (SELECT ROUND(AVG(c.`position_x`))
         FROM `creature` c
         JOIN `creature_queststarter` cqs
           ON cqs.`id` = c.`id1`
         WHERE c.`map` = 37
           AND cqs.`quest` = m.`QuestID`),
        (SELECT ROUND(AVG(g.`position_x`))
         FROM `gameobject` g
         JOIN `gameobject_queststarter` gqs
           ON gqs.`id` = g.`id`
         WHERE g.`map` = 37
           AND gqs.`quest` = m.`QuestID`),
        (SELECT ROUND(AVG(qpp.`X`))
         FROM `quest_poi_points` qpp
         JOIN `quest_template` q2
           ON q2.`ID` = qpp.`QuestID`
         WHERE q2.`QuestSortID` = 268),
        0
    ) AS `X`,
    COALESCE(
        (SELECT ROUND(AVG(c.`position_y`))
         FROM `creature` c
         JOIN (
             SELECT qt.`RequiredNpcOrGo1` AS `entry`
             UNION ALL SELECT qt.`RequiredNpcOrGo2`
             UNION ALL SELECT qt.`RequiredNpcOrGo3`
             UNION ALL SELECT qt.`RequiredNpcOrGo4`
         ) req
           ON req.`entry` > 0
          AND c.`id1` = req.`entry`
         WHERE c.`map` = 37),
        (SELECT ROUND(AVG(g.`position_y`))
         FROM `gameobject` g
         JOIN (
             SELECT qt.`RequiredNpcOrGo1` AS `entry`
             UNION ALL SELECT qt.`RequiredNpcOrGo2`
             UNION ALL SELECT qt.`RequiredNpcOrGo3`
             UNION ALL SELECT qt.`RequiredNpcOrGo4`
         ) req
           ON req.`entry` < 0
          AND g.`id` = -req.`entry`
         WHERE g.`map` = 37),
        (SELECT ROUND(AVG(c.`position_y`))
         FROM `creature` c
         WHERE c.`map` = 37
           AND c.`id1` IN (
               SELECT cq.`CreatureEntry`
               FROM `creature_questitem` cq
               WHERE cq.`ItemId` IN (
                   qt.`RequiredItemId1`, qt.`RequiredItemId2`, qt.`RequiredItemId3`,
                   qt.`RequiredItemId4`, qt.`RequiredItemId5`, qt.`RequiredItemId6`
               )
           )),
        (SELECT ROUND(AVG(g.`position_y`))
         FROM `gameobject` g
         WHERE g.`map` = 37
           AND g.`id` IN (
               SELECT gq.`GameObjectEntry`
               FROM `gameobject_questitem` gq
               WHERE gq.`ItemId` IN (
                   qt.`RequiredItemId1`, qt.`RequiredItemId2`, qt.`RequiredItemId3`,
                   qt.`RequiredItemId4`, qt.`RequiredItemId5`, qt.`RequiredItemId6`
               )
           )),
        (SELECT ROUND(AVG(c.`position_y`))
         FROM `creature` c
         JOIN `creature_queststarter` cqs
           ON cqs.`id` = c.`id1`
         WHERE c.`map` = 37
           AND cqs.`quest` = m.`QuestID`),
        (SELECT ROUND(AVG(g.`position_y`))
         FROM `gameobject` g
         JOIN `gameobject_queststarter` gqs
           ON gqs.`id` = g.`id`
         WHERE g.`map` = 37
           AND gqs.`quest` = m.`QuestID`),
        (SELECT ROUND(AVG(qpp.`Y`))
         FROM `quest_poi_points` qpp
         JOIN `quest_template` q2
           ON q2.`ID` = qpp.`QuestID`
         WHERE q2.`QuestSortID` = 268),
        0
    ) AS `Y`,
    0
FROM `dc_tmp_azshara_missing_poi_quests` m
JOIN `quest_template` qt
  ON qt.`ID` = m.`QuestID`;

DROP TEMPORARY TABLE IF EXISTS `dc_tmp_azshara_missing_poi_quests`;
