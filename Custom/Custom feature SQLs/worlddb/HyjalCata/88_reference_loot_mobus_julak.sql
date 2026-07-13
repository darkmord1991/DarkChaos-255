-- ---------------------------------------------------------------------------
-- reference_loot_template gaps for Mobus / Julak-Doom (Hyjal rare mobs)
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13, ultracode workflow investigation):
-- "Table `reference_loot_template` loot for a reference (67129/68787) not
-- found" -- creature_template.lootid 50009/50089 (Mobus entry 3650009,
-- Julak-Doom entry 3650089) each have a creature_loot_template row pointing
-- to these References, but the reference groups themselves were never
-- inserted. Verified: no negative mincountOrRef in nelt_world's source rows
-- (pure item lists, no nested references), so this is a straight schema
-- remap (nelt's overloaded mincountOrRef -> our split Reference/MinCount,
-- Reference=0 literal here) -- copied verbatim, Chance is already 0
-- (EqualChanced) in the source for both.
-- ---------------------------------------------------------------------------
DELETE FROM `reference_loot_template` WHERE `Entry` IN (67129,68787);

INSERT INTO `reference_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT `entry`, `item`, 0, `ChanceOrQuestChance`, 0, `lootmode`, `groupid`, `mincountOrRef`, `maxcount`
FROM `nelt_world`.`reference_loot_template`
WHERE `entry` IN (67129,68787);
