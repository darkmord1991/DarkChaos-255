-- Reference loot tables the zones' loot rows point at (Reference>0) but acore lacks (10 of them).
-- Import from cata_world; INSERT IGNORE leaves stock refs untouched. Covers both maps.
INSERT IGNORE INTO acore_world.reference_loot_template
(`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT `Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`
FROM cata_world.reference_loot_template
WHERE `Entry` IN (
  SELECT DISTINCT lt.`Reference` FROM acore_world.creature_loot_template lt
  WHERE lt.`Reference`>0 AND lt.`Entry` IN (
    SELECT lootid FROM acore_world.creature_template
    WHERE entry IN (SELECT id FROM acore_world.creature WHERE map IN (750,751)) AND lootid>0));
