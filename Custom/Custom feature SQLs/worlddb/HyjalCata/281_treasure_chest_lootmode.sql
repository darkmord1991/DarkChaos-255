-- ---------------------------------------------------------------------------
-- 281  gameobject_loot_template 39335 -- LootMode 0 on all 272 rows
-- ---------------------------------------------------------------------------
--     Table 'gameobject_loot_template' Entry 39335 Item 15306: LootMode is
--     equal to 0, item will never drop - setting mode 1
--
-- 🔴 272 LINES = 36% OF THE ENTIRE Errors.log (272 of 745). Nothing here is
-- broken -- `LootStoreItem` rewrites LootMode 0 to 1 in memory on every boot, so
-- the chests already drop correctly. This is purely about signal: a third of the
-- log was one table shouting, which is exactly how a real error gets missed.
-- Writing the value the core already computes makes the DB agree with runtime
-- and changes no behaviour whatsoever.
--
-- SCOPE. Table 39335 feeds 4 map-750 treasure chests (5 spawns):
--     3807485 Sturdy Treasure Chest      x1
--     3807521 Maplewood Treasure Chest   x1
--     3907521 Maplewood Treasure Chest   x2
--     3907533 Runestone Treasure Chest   x1
-- The table itself is healthy otherwise -- 272 rows, 3 groups, chances 0.5-8.5,
-- and **0 of its items are missing from item_template**, so this is the only
-- thing wrong with it.
--
-- It is also the ONLY table in the database with the defect: every other loot
-- table (creature, reference, item, skinning, pickpocketing, fishing,
-- disenchant, mail) returns 0 rows at LootMode = 0. Scoped to Entry 39335
-- rather than a blanket `WHERE LootMode = 0` so it cannot quietly rewrite a
-- table some future import adds for a different reason.
UPDATE acore_world.`gameobject_loot_template`
SET `LootMode` = 1
WHERE `Entry` = 39335 AND `LootMode` = 0;

-- Verify after apply:
--   SELECT COUNT(*) FROM gameobject_loot_template WHERE LootMode = 0;   -> 0
--   next boot: Errors.log loses 272 lines and drops to roughly 470.
