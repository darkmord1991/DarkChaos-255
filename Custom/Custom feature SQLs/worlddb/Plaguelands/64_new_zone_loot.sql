-- 64_new_zone_loot.sql — map 751 Lordaeron extension, DB step 4.
--
-- Loot for the templates imported by 62_. REQUIRES 62_ (templates + the
-- dc_map751_src_* sets). Safe to run before or after 63_.
--
-- THE INVARIANT: 62_ already set lootid / pickpocketloot / skinloot to the
-- creature's OWN new entry, so this file writes loot at `entry = new entry`.
-- That gives `lootid == entry` for the whole 4,1xx,xxx band from day one — the
-- same invariant map 750 relies on, which means a loot edit for one of these
-- creatures can never bleed into a stock mob. Several source creatures SHARE a
-- lootid in cata; forking per-creature here is deliberate, not duplication by
-- accident.
--
-- Schemas are identical across the two databases for all five loot tables
-- (same 10 columns, no nullability mismatches), so this is a straight copy with
-- the entry remapped.
--
-- VALIDITY FILTER — rows are skipped, never imported broken:
--   * Reference > 0  -> the reference must exist in acore reference_loot_template
--   * Reference = 0  -> the Item must exist in acore item_template
-- Measured on this data set: 94 distinct references, 89 already present in acore
-- (these zones are vanilla-era content, so the reference id space largely agrees);
-- 1,193 distinct items, 39 missing (all Cata-era ids, ~58 rows). The tail is
-- reported at the bottom so it can be backfilled later the way
-- Plaguelands/44_missing_loot_items.sql did for the first import.

SET @COFF := 4100000;
SET @GOFF := 4600000;

-- ---------------------------------------------------------------------------
-- creature loot
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` BETWEEN 4100000 AND 4199999;
INSERT INTO `creature_loot_template`
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT t.`entry` + @COFF, l.`Item`, l.`Reference`, l.`Chance`, l.`QuestRequired`,
       l.`LootMode`, l.`GroupId`, l.`MinCount`, l.`MaxCount`, l.`Comment`
FROM `cata_world`.`creature_loot_template` l
JOIN `cata_world`.`creature_template` t ON t.`lootid` = l.`entry`
JOIN `dc_map751_src_creature` s ON s.`id` = t.`entry`
WHERE (l.`Reference` > 0 AND EXISTS (SELECT 1 FROM `reference_loot_template` r WHERE r.`Entry` = l.`Reference`))
   OR (l.`Reference` = 0 AND EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = l.`Item`));

-- ---------------------------------------------------------------------------
-- pickpocket loot
-- ---------------------------------------------------------------------------
DELETE FROM `pickpocketing_loot_template` WHERE `Entry` BETWEEN 4100000 AND 4199999;
INSERT INTO `pickpocketing_loot_template`
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT t.`entry` + @COFF, l.`Item`, l.`Reference`, l.`Chance`, l.`QuestRequired`,
       l.`LootMode`, l.`GroupId`, l.`MinCount`, l.`MaxCount`, l.`Comment`
FROM `cata_world`.`pickpocketing_loot_template` l
JOIN `cata_world`.`creature_template` t ON t.`pickpocketloot` = l.`entry`
JOIN `dc_map751_src_creature` s ON s.`id` = t.`entry`
WHERE (l.`Reference` > 0 AND EXISTS (SELECT 1 FROM `reference_loot_template` r WHERE r.`Entry` = l.`Reference`))
   OR (l.`Reference` = 0 AND EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = l.`Item`));

-- ---------------------------------------------------------------------------
-- skinning loot
-- ---------------------------------------------------------------------------
DELETE FROM `skinning_loot_template` WHERE `Entry` BETWEEN 4100000 AND 4199999;
INSERT INTO `skinning_loot_template`
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT t.`entry` + @COFF, l.`Item`, l.`Reference`, l.`Chance`, l.`QuestRequired`,
       l.`LootMode`, l.`GroupId`, l.`MinCount`, l.`MaxCount`, l.`Comment`
FROM `cata_world`.`skinning_loot_template` l
JOIN `cata_world`.`creature_template` t ON t.`skinloot` = l.`entry`
JOIN `dc_map751_src_creature` s ON s.`id` = t.`entry`
WHERE (l.`Reference` > 0 AND EXISTS (SELECT 1 FROM `reference_loot_template` r WHERE r.`Entry` = l.`Reference`))
   OR (l.`Reference` = 0 AND EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = l.`Item`));

-- ---------------------------------------------------------------------------
-- gameobject (chest) loot. 62_ set CHEST Data1 to the GO's own new entry, so the
-- same entry == lootid invariant holds on this side too.
-- ---------------------------------------------------------------------------
DELETE FROM `gameobject_loot_template` WHERE `Entry` BETWEEN 4600000 AND 4899999;
INSERT INTO `gameobject_loot_template`
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT t.`entry` + @GOFF, l.`Item`, l.`Reference`, l.`Chance`, l.`QuestRequired`,
       l.`LootMode`, l.`GroupId`, l.`MinCount`, l.`MaxCount`, l.`Comment`
FROM `cata_world`.`gameobject_loot_template` l
JOIN `cata_world`.`gameobject_template` t ON t.`type` = 3 AND t.`Data1` = l.`entry`
JOIN `dc_map751_src_gameobject` s ON s.`id` = t.`entry`
WHERE (l.`Reference` > 0 AND EXISTS (SELECT 1 FROM `reference_loot_template` r WHERE r.`Entry` = l.`Reference`))
   OR (l.`Reference` = 0 AND EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = l.`Item`));

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'creature_loot_template'      AS what, COUNT(*) AS n FROM `creature_loot_template`      WHERE `Entry` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'pickpocketing_loot_template', COUNT(*) FROM `pickpocketing_loot_template` WHERE `Entry` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'skinning_loot_template',      COUNT(*) FROM `skinning_loot_template`      WHERE `Entry` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'gameobject_loot_template',    COUNT(*) FROM `gameobject_loot_template`    WHERE `Entry` BETWEEN 4600000 AND 4899999;

-- the lootid == entry invariant must hold for every lootable creature we imported
SELECT 'PROBLEM: lootid != entry' AS problem, COUNT(*) AS n
FROM `creature_template`
WHERE `entry` BETWEEN 4100000 AND 4199999 AND `lootid` <> 0 AND `lootid` <> `entry`;

-- a template promising loot that has no rows (usually its source rows were all
-- filtered out as invalid) — these mobs drop nothing
SELECT 'templates with lootid but no loot rows' AS problem, COUNT(*) AS n
FROM `creature_template` t
LEFT JOIN `creature_loot_template` l ON l.`Entry` = t.`lootid`
WHERE t.`entry` BETWEEN 4100000 AND 4199999 AND t.`lootid` > 0 AND l.`Entry` IS NULL;

-- every Item / Reference actually written must resolve (both must be 0)
SELECT 'PROBLEM: written Item missing from item_template' AS problem, COUNT(*) AS n
FROM `creature_loot_template` l LEFT JOIN `item_template` i ON i.`entry` = l.`Item`
WHERE l.`Entry` BETWEEN 4100000 AND 4199999 AND l.`Reference` = 0 AND l.`Item` > 0 AND i.`entry` IS NULL
UNION ALL
SELECT 'PROBLEM: written Reference missing', COUNT(*)
FROM `creature_loot_template` l LEFT JOIN `reference_loot_template` r ON r.`Entry` = l.`Reference`
WHERE l.`Entry` BETWEEN 4100000 AND 4199999 AND l.`Reference` > 0 AND r.`Entry` IS NULL;

-- WHAT WAS SKIPPED — backfill list. Items first, then the 5 absent references.
SELECT 'SKIPPED item (not in item_template)' AS kind, l.`Item` AS id, COUNT(*) AS src_rows
FROM `cata_world`.`creature_loot_template` l
JOIN `cata_world`.`creature_template` t ON t.`lootid` = l.`entry`
JOIN `dc_map751_src_creature` s ON s.`id` = t.`entry`
LEFT JOIN `item_template` i ON i.`entry` = l.`Item`
WHERE l.`Reference` = 0 AND l.`Item` > 0 AND i.`entry` IS NULL
GROUP BY l.`Item`
UNION ALL
SELECT 'SKIPPED reference (not in reference_loot_template)', l.`Reference`, COUNT(*)
FROM `cata_world`.`creature_loot_template` l
JOIN `cata_world`.`creature_template` t ON t.`lootid` = l.`entry`
JOIN `dc_map751_src_creature` s ON s.`id` = t.`entry`
LEFT JOIN `reference_loot_template` r ON r.`Entry` = l.`Reference`
WHERE l.`Reference` > 0 AND r.`Entry` IS NULL
GROUP BY l.`Reference`
ORDER BY src_rows DESC;
