-- Remove orphaned POI points for Azshara Crater quest set.
-- This cleans points that reference a missing quest_poi row.

DELETE qpp
FROM `quest_poi_points` qpp
JOIN `quest_template` qt
  ON qt.`ID` = qpp.`QuestID`
LEFT JOIN `quest_poi` qp
  ON qp.`QuestID` = qpp.`QuestID`
 AND qp.`id` = qpp.`Idx1`
WHERE (qt.`QuestSortID` = 268 OR qt.`ID` = 820056)
  AND qp.`QuestID` IS NULL;
