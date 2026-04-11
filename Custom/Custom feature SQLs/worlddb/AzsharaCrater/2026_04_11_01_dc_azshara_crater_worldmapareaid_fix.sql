-- Azshara Crater quest POI fix
-- quest_poi.WorldMapAreaId expects WorldMapArea.ID, not AreaTable/Zone ID.
-- For Azshara Crater this is WorldMapAreaId=613 (MapID=37, AreaID/Zone=268).

UPDATE `quest_poi`
SET `WorldMapAreaId` = 613
WHERE `MapID` = 37
  AND `WorldMapAreaId` = 268;

-- Verification
SELECT COUNT(*) AS fixed_rows
FROM `quest_poi`
WHERE `MapID` = 37
  AND `WorldMapAreaId` = 613;

SELECT COUNT(*) AS remaining_wrong_rows
FROM `quest_poi`
WHERE `MapID` = 37
  AND `WorldMapAreaId` = 268;
