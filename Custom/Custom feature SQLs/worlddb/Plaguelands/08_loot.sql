-- Plaguelands (DCPlaguelands, map 751)
-- dc_entry = 3,600,000 + original (isolated, tunable). Source cata_world(TDB434)->acore_world. Cross-DB INSERT...SELECT.
SET @OFF := 3600000;

-- loot for our cata-new creatures (keyed by lootid, unchanged). INSERT IGNORE dedupes vs existing rows.
-- JOIN to a materialized lootid set (small) so the 500k-row loot table is hit by PRIMARY-key lookups.
-- (The 'Entry IN (subquery)' form full-scanned all 527k rows per the planner -> very slow.)
INSERT IGNORE INTO acore_world.creature_loot_template (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT lt.`Entry`, lt.`Item`, lt.`Reference`, lt.`Chance`, lt.`QuestRequired`, lt.`LootMode`, lt.`GroupId`, lt.`MinCount`, lt.`MaxCount`, lt.`Comment`
FROM (
  SELECT DISTINCT ct.lootid AS lootid
  FROM cata_world.creature_template ct
  JOIN cata_world.creature c ON c.id = ct.entry
  LEFT JOIN acore_world.creature_template ac ON ac.entry = ct.entry AND ac.entry < @OFF
  WHERE ct.lootid > 0 AND (c.map=0 AND c.zoneId IN (139,28)) AND ac.entry IS NULL
) L
JOIN cata_world.creature_loot_template lt ON lt.Entry = L.lootid;
