-- ---------------------------------------------------------------------------
-- 237  Map 750 -- 400xxx ladder as zone drops + Emberwood Sap token map-wide
-- ---------------------------------------------------------------------------
-- Leveling gear never dropped from anything. This file makes it the "uncommon
-- drop you look forward to" via per-ZONE reference loot, each zone dropping
-- its own THEMED set (243_) so the loot matches the area's topic; only Hyjal
-- drops the original ladder (which is Hyjal-themed by name already):
--
--   ref 750080 -> Tidewatcher's (400708-400722)            4929 Darkshore
--   ref 750081 -> Bilgewater Profiteer's (400723-400737)   4930 Azshara
--   ref 750088 -> Ashenvale Skirmisher's (400738-400752)   4931 Ashenvale
--   ref 750096 -> Emerald Warden's (400753-400767)         4927 Felwood
--   ref 750104 -> Frostsaber Stalker's (400768-400782)     4926 Winterspring
--   ref 750113 -> Hyjal ladder tier 4 (400110-400124)      4923 Hyjal
--
-- The generic ladder tiers 1-3 stay acquirable at the quartermaster vendors
-- (Emberwood Sap). Tier RequiredLevels are re-tuned to 82/92/102/115 by 238_
-- so every set is equippable inside its band.
--
-- NOTE: on a FIRST full apply this file runs before 243_ creates the themed
-- items (empty selects) -- apply_all re-sources it after 243_, and it is
-- idempotent, so the second pass populates everything.
--
-- Drop chances: rank 0/1 mobs 2%, rank 2/3/4 6%. Group rolls are equal-chance
-- (Chance 0 inside GroupId 1), so each tier item is equally likely.
--
-- Token economy: item 400000 (Emberwood Sap) extends from the 45 hand-authored
-- Hyjal mobs to every killable with a loot table, chance graded by band
-- (6/8/10/12/15%), Hyjal dropping 1-2. The old hand rows are superseded by the
-- DELETE below -- intentional.
--
-- Scope: only templates that ALREADY have a loot table (lootid = entry after
-- 232_'s fork). Pure-trash mobs with no loot table stay lootless -- classic.
--
-- Run AFTER 232_ (fork) and 233_ (bands). Idempotent (full DELETE + re-insert
-- of everything this file owns).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) the reference tables
-- ---------------------------------------------------------------------------
DELETE FROM `reference_loot_template` WHERE `Entry` BETWEEN 750080 AND 750199;

INSERT INTO `reference_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 750080, it.`entry`, 0, 0, 0, 1, 1, 1, 1, CONCAT('DC750 Darkshore set - ', it.`name`)
FROM `item_template` it WHERE it.`entry` BETWEEN 400708 AND 400722;

INSERT INTO `reference_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 750081, it.`entry`, 0, 0, 0, 1, 1, 1, 1, CONCAT('DC750 Azshara set - ', it.`name`)
FROM `item_template` it WHERE it.`entry` BETWEEN 400723 AND 400737;

INSERT INTO `reference_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 750088, it.`entry`, 0, 0, 0, 1, 1, 1, 1, CONCAT('DC750 Ashenvale set - ', it.`name`)
FROM `item_template` it WHERE it.`entry` BETWEEN 400738 AND 400752;

INSERT INTO `reference_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 750096, it.`entry`, 0, 0, 0, 1, 1, 1, 1, CONCAT('DC750 Felwood set - ', it.`name`)
FROM `item_template` it WHERE it.`entry` BETWEEN 400753 AND 400767;

INSERT INTO `reference_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 750104, it.`entry`, 0, 0, 0, 1, 1, 1, 1, CONCAT('DC750 Winterspring set - ', it.`name`)
FROM `item_template` it WHERE it.`entry` BETWEEN 400768 AND 400782;

INSERT INTO `reference_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 750113, it.`entry`, 0, 0, 0, 1, 1, 1, 1, CONCAT('DC750 Hyjal ladder T4 - ', it.`name`)
FROM `item_template` it WHERE it.`entry` BETWEEN 400110 AND 400124;

-- ---------------------------------------------------------------------------
-- B) hook one reference row into every killable loot table, per band
-- ---------------------------------------------------------------------------
DELETE clt FROM `creature_loot_template` clt
WHERE clt.`Reference` BETWEEN 750080 AND 750199
  AND clt.`Entry` BETWEEN 3600000 AND 3799999;

INSERT INTO `creature_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT DISTINCT ct.`lootid`,
       CASE ez.`zone` WHEN 4929 THEN 750080 WHEN 4930 THEN 750081
                      WHEN 4931 THEN 750088 WHEN 4927 THEN 750096
                      WHEN 4926 THEN 750104 WHEN 4923 THEN 750113 END,
       CASE ez.`zone` WHEN 4929 THEN 750080 WHEN 4930 THEN 750081
                      WHEN 4931 THEN 750088 WHEN 4927 THEN 750096
                      WHEN 4926 THEN 750104 WHEN 4923 THEN 750113 END,
       IF(ct.`rank` >= 2, 6, 2), 0, 1, 0, 1, 1,
       'DC750 ladder drop'
FROM `creature_template` ct
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`lootid` = ct.`entry`
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` = 0;

-- ---------------------------------------------------------------------------
-- C) Emberwood Sap (400000) on every killable with a loot table
-- ---------------------------------------------------------------------------
-- Supersedes the 45 hand-authored token rows from 100_ -- deliberate.
DELETE clt FROM `creature_loot_template` clt
WHERE clt.`Item` = 400000 AND clt.`Reference` = 0
  AND clt.`Entry` BETWEEN 3600000 AND 3799999;

INSERT INTO `creature_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT DISTINCT ct.`lootid`, 400000, 0,
       CASE ez.`zone` WHEN 4929 THEN 6 WHEN 4930 THEN 6 WHEN 4931 THEN 8
                      WHEN 4927 THEN 10 WHEN 4926 THEN 12 WHEN 4923 THEN 15 END,
       0, 1, 0, 1,
       IF(ez.`zone` = 4923, 2, 1),
       'DC750 Emberwood Sap token'
FROM `creature_template` ct
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`lootid` = ct.`entry`
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` = 0;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- ref tables populated (expect 15 rows in each of the 6 refs; the five
-- themed refs are empty until 243_ has run and this file is re-sourced):
-- SELECT Entry, COUNT(*) FROM reference_loot_template
-- WHERE Entry BETWEEN 750080 AND 750199 GROUP BY Entry;
-- hook coverage per zone:
-- SELECT ez.zone, COUNT(DISTINCT clt.Entry) FROM creature_loot_template clt
-- JOIN dc_map750_entryzone ez ON ez.entry = clt.Entry
-- WHERE clt.Reference BETWEEN 750080 AND 750199 GROUP BY ez.zone;
-- token coverage per zone:
-- SELECT ez.zone, COUNT(DISTINCT clt.Entry) FROM creature_loot_template clt
-- JOIN dc_map750_entryzone ez ON ez.entry = clt.Entry
-- WHERE clt.Item = 400000 AND clt.Reference = 0 GROUP BY ez.zone;
