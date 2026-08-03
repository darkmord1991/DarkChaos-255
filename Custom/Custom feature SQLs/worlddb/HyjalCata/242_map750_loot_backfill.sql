-- ---------------------------------------------------------------------------
-- 242  Map 750 -- loot backfill: give the loot-less killables their Cata loot
-- ---------------------------------------------------------------------------
-- Only 559 of ~1,180 killable templates on map 750 carry a loot table; the
-- rest have lootid = 0 and drop nothing (the classic-drops design wants mob
-- kills to feel rewarding everywhere). Cata itself knows what most of them
-- dropped: both clone bands map back to cata_world templates
-- (entry - 3,600,000 / - 3,700,000) whose creature_loot_template rows are
-- still there.
--
-- Rules, mirroring 239_'s skinning backfill:
--   * only spawned killables (type not 8/10, npcflag 0) with lootid = 0
--     whose Cata source has a non-zero lootid backed by rows;
--   * copy plain item rows only (Reference = 0) whose Item exists in
--     item_template -- Cata reference ids are foreign to this fork's
--     reference_loot_template and would dangle;
--   * templates whose table would come out EMPTY are reverted to lootid = 0;
--   * new tables use lootid = entry (232_'s invariant), so a later re-run of
--     236_/237_ automatically extends gear re-banding, ladder refs and the
--     token to them -- apply_all re-sources both after this file.
--
-- Mobs that had no loot in Cata either stay loot-less -- authentic.
-- Run AFTER 232_. Idempotent.
-- ---------------------------------------------------------------------------

-- 1. point lootid at the entry's own id where the Cata source has loot
UPDATE `creature_template` ct
JOIN `cata_world`.`creature_template` src ON src.`entry` = ct.`entry` - 3600000
SET ct.`lootid` = ct.`entry`
WHERE ct.`entry` BETWEEN 3600000 AND 3699999
  AND ct.`type` NOT IN (8, 10) AND ct.`npcflag` = 0
  AND ct.`lootid` = 0 AND src.`lootid` <> 0
  AND ct.`entry` IN (SELECT DISTINCT c.`id` FROM `creature` c WHERE c.`map` = 750);

UPDATE `creature_template` ct
JOIN `cata_world`.`creature_template` src ON src.`entry` = ct.`entry` - 3700000
SET ct.`lootid` = ct.`entry`
WHERE ct.`entry` BETWEEN 3700000 AND 3799999
  AND ct.`type` NOT IN (8, 10) AND ct.`npcflag` = 0
  AND ct.`lootid` = 0 AND src.`lootid` <> 0
  AND ct.`entry` IN (SELECT DISTINCT c.`id` FROM `creature` c WHERE c.`map` = 750);

-- 2. copy the Cata tables (plain, resolvable item rows only)
DELETE clt FROM `creature_loot_template` clt
JOIN `creature_template` ct ON ct.`entry` = clt.`Entry`
JOIN `cata_world`.`creature_template` src
  ON src.`entry` = ct.`entry` - IF(ct.`entry` < 3700000, 3600000, 3700000)
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`lootid` = ct.`entry` AND src.`lootid` <> 0
  AND clt.`Comment` LIKE 'DC750 loot backfill%';

INSERT INTO `creature_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT ct.`entry`, s.`Item`, 0, s.`Chance`, s.`QuestRequired`,
       s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`,
       CONCAT('DC750 loot backfill from cata ', src.`lootid`)
FROM `creature_template` ct
JOIN `cata_world`.`creature_template` src
  ON src.`entry` = ct.`entry` - IF(ct.`entry` < 3700000, 3600000, 3700000)
JOIN `cata_world`.`creature_loot_template` s ON s.`Entry` = src.`lootid`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`lootid` = ct.`entry` AND src.`lootid` <> 0
  AND s.`Reference` = 0
  AND EXISTS (SELECT 1 FROM `item_template` it WHERE it.`entry` = s.`Item`)
  AND NOT EXISTS (SELECT 1 FROM `creature_loot_template` d
                  WHERE d.`Entry` = ct.`entry` AND d.`Item` = s.`Item` AND d.`Reference` = 0);

-- 3. revert templates whose table came out empty (all rows filtered)
UPDATE `creature_template` ct
SET ct.`lootid` = 0
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`type` NOT IN (8, 10) AND ct.`npcflag` = 0
  AND ct.`lootid` = ct.`entry`
  AND NOT EXISTS (SELECT 1 FROM `creature_loot_template` clt WHERE clt.`Entry` = ct.`entry`);

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- lootable coverage per zone (expect a large jump from the pre-apply 43%):
-- SELECT ez.zone, COUNT(*) killable, SUM(ct.lootid <> 0) lootable
-- FROM creature_template ct
-- JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
-- WHERE ct.type NOT IN (8, 10) AND ct.npcflag = 0 GROUP BY ez.zone;
-- no dangling lootids (expect 0):
-- SELECT COUNT(*) FROM creature_template ct
-- WHERE ct.entry BETWEEN 3600000 AND 3799999 AND ct.lootid <> 0
--   AND NOT EXISTS (SELECT 1 FROM creature_loot_template c WHERE c.Entry = ct.lootid);
-- Cata items we skipped (not downported -- candidates for a later 210_-style
-- backfill):
-- SELECT DISTINCT s.Item FROM cata_world.creature_template src
-- JOIN cata_world.creature_loot_template s ON s.Entry = src.lootid
-- JOIN creature_template ct
--   ON src.entry = ct.entry - IF(ct.entry < 3700000, 3600000, 3700000)
-- WHERE ct.entry BETWEEN 3600000 AND 3799999 AND s.Reference = 0
--   AND NOT EXISTS (SELECT 1 FROM item_template it WHERE it.entry = s.Item);
