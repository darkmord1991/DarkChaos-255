-- Plaguelands (DCPlaguelands, map 751)
-- dc_entry = 3,600,000 + original (isolated, tunable). Source cata_world(TDB434)->acore_world. Cross-DB INSERT...SELECT.
SET @OFF := 3600000;

UPDATE acore_world.creature   SET zoneId=4924, areaId=4924 WHERE map=751 AND id>=@OFF;
UPDATE acore_world.gameobject SET zoneId=4924, areaId=4924 WHERE map=751 AND id>=@OFF;
