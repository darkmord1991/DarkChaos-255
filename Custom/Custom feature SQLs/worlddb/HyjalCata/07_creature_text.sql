-- Mount Hyjal (DCMountHyjal, map 750)
-- dc_entry = 3,600,000 + original (isolated, tunable). Source cata_world(TDB434)->acore_world. Cross-DB INSERT...SELECT.
SET @OFF := 3600000;

INSERT IGNORE INTO acore_world.creature_text (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT `CreatureID`+@OFF, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment` FROM cata_world.creature_text WHERE CreatureID IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=616)) AND CreatureID NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.creature_text (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT `CreatureID`+@OFF, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment` FROM acore_world.creature_text WHERE CreatureID IN (SELECT DISTINCT c.id FROM cata_world.creature c WHERE (c.map=1 AND c.zoneId=616)) AND CreatureID IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF) AND CreatureID < @OFF;
