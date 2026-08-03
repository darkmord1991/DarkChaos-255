-- ---------------------------------------------------------------------------
-- 239  Map 750 -- skinning backfill (Hyjal had 2 skinnable beasts)
-- ---------------------------------------------------------------------------
-- The downport dropped most skinloot: only 108 of 1,641 spawned templates are
-- skinnable, and the 80-85 endgame zone had exactly TWO. Cata's own data has
-- the answer -- both clone bands map back to cata_world templates
-- (entry - 3,600,000 / - 3,700,000), and cata_world.skinning_loot_template
-- still holds their skin tables.
--
-- Steps: for type-1 beasts with skinloot = 0 whose Cata source is skinnable,
-- point skinloot at the entry's own id (232_'s invariant) and copy the source
-- rows -- but ONLY rows whose Item exists in item_template (Cata leathers that
-- were never downported are skipped and reported by the trailer; backfill them
-- via the 210_ cata-client-item pattern if wanted). Templates whose table
-- would end up EMPTY are reverted to skinloot = 0 (a dangling skinloot logs
-- errors and yields nothing).
--
-- Run AFTER 232_. Idempotent: the skinloot UPDATE is guarded on 0, the row
-- copy DELETEs its own target set first, the empty-table revert re-runs clean.
-- ---------------------------------------------------------------------------

-- 1. point skinloot at the entry's own id where the Cata source is skinnable
UPDATE `creature_template` ct
JOIN `cata_world`.`creature_template` src ON src.`entry` = ct.`entry` - 3600000
SET ct.`skinloot` = ct.`entry`
WHERE ct.`entry` BETWEEN 3600000 AND 3699999
  AND ct.`type` = 1 AND ct.`skinloot` = 0 AND src.`skinloot` <> 0;

UPDATE `creature_template` ct
JOIN `cata_world`.`creature_template` src ON src.`entry` = ct.`entry` - 3700000
SET ct.`skinloot` = ct.`entry`
WHERE ct.`entry` BETWEEN 3700000 AND 3799999
  AND ct.`type` = 1 AND ct.`skinloot` = 0 AND src.`skinloot` <> 0;

-- 2. copy the Cata skin tables under our own ids (existing-item rows only)
DELETE slt FROM `skinning_loot_template` slt
JOIN `creature_template` ct ON ct.`entry` = slt.`Entry`
JOIN `cata_world`.`creature_template` src
  ON src.`entry` = ct.`entry` - IF(ct.`entry` < 3700000, 3600000, 3700000)
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`skinloot` = ct.`entry` AND src.`skinloot` <> 0;

INSERT INTO `skinning_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT ct.`entry`, s.`Item`, s.`Reference`, s.`Chance`, s.`QuestRequired`,
       s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`,
       CONCAT('DC750 skin copy of cata ', src.`skinloot`)
FROM `creature_template` ct
JOIN `cata_world`.`creature_template` src
  ON src.`entry` = ct.`entry` - IF(ct.`entry` < 3700000, 3600000, 3700000)
JOIN `cata_world`.`skinning_loot_template` s ON s.`Entry` = src.`skinloot`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`skinloot` = ct.`entry` AND src.`skinloot` <> 0
  AND (s.`Reference` <> 0 OR EXISTS (SELECT 1 FROM `item_template` it WHERE it.`entry` = s.`Item`));

-- 3. revert templates whose table came out empty (all rows filtered)
UPDATE `creature_template` ct
SET ct.`skinloot` = 0
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`type` = 1 AND ct.`skinloot` = ct.`entry`
  AND NOT EXISTS (SELECT 1 FROM `skinning_loot_template` slt WHERE slt.`Entry` = ct.`entry`);

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- skinnable coverage per zone after apply:
-- SELECT ez.zone, SUM(ct.skinloot <> 0) skinnable, COUNT(*) beasts
-- FROM creature_template ct
-- JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
-- WHERE ct.type = 1 GROUP BY ez.zone;
-- Cata skin items we skipped because they are not downported (backfill list):
-- SELECT DISTINCT s.Item FROM cata_world.creature_template src
-- JOIN cata_world.skinning_loot_template s ON s.Entry = src.skinloot
-- JOIN creature_template ct
--   ON src.entry = ct.entry - IF(ct.entry < 3700000, 3600000, 3700000)
-- WHERE ct.entry BETWEEN 3600000 AND 3799999 AND ct.type = 1
--   AND s.Reference = 0
--   AND NOT EXISTS (SELECT 1 FROM item_template it WHERE it.entry = s.Item);
-- no dangling skinloot (expect 0):
-- SELECT COUNT(*) FROM creature_template ct
-- WHERE ct.entry BETWEEN 3600000 AND 3799999 AND ct.skinloot <> 0
--   AND NOT EXISTS (SELECT 1 FROM skinning_loot_template s WHERE s.Entry = ct.skinloot);
