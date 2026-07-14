-- ---------------------------------------------------------------------------
-- reference_loot_template Entry 25 -- server-wide "junk item" reference group
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13, ultracode workflow investigation):
-- "Table `reference_loot_template` loot for a reference (25) not found" --
-- Entry 25 is a stock, server-wide generic loot reference used by hundreds of
-- creature_loot_template rows across both stock (883, 1783, 1784, 1794, ...)
-- and custom content -- not zone-scoped, so this file lives at the worlddb
-- root rather than in a zone folder. It was entirely missing from this DB's
-- `reference_loot_template` (0 rows), even though dozens of creatures already
-- reference it.
--
-- Sourced from nelt_world.reference_loot_template (551 items, all GroupId=1,
-- no nested references). IMPORTANT: nelt's source data has a literal
-- ChanceOrQuestChance=1 on every single row, but this is NOT a real "1% per
-- item" design -- verified directly against LootTemplate::LootGroup::AddEntry
-- (LootMgr.cpp): any nonzero chance routes an item into the ExplicitlyChanced
-- list, which is resolved via a SEQUENTIAL roll-subtraction over a single
-- 0-100 random roll (LootGroup::Roll). With 551 items each subtracting 1 from
-- one roll of at most 100, only roughly the first ~100 items in list order
-- could ever be reached at all -- the remaining ~450 would be silently
-- unreachable, and the EqualChanced fallback path is never used once
-- ExplicitlyChanced is non-empty. Forcing Chance to 0 for every row (the
-- table's own dominant convention -- 18553 GroupId>0 rows already use 0
-- vs. only 156 using literal 1 elsewhere in this DB) routes all 551 items into
-- EqualChanced instead, which picks uniformly at random via
-- SelectRandomContainerElement -- the actually-intended behavior for a
-- generic "any one junk item" reference group.
-- ---------------------------------------------------------------------------
DELETE FROM `reference_loot_template` WHERE `Entry` = 25;

INSERT INTO `reference_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT `entry`, `item`, 0, 0, 0, `lootmode`, `groupid`, `mincountOrRef`, `maxcount`
FROM `nelt_world`.`reference_loot_template`
WHERE `entry` = 25;
