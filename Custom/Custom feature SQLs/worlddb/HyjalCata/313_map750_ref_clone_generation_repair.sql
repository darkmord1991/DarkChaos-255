-- ---------------------------------------------------------------------------
-- 313  Repair: 309_ was applied twice and cloned its own clones
-- ---------------------------------------------------------------------------
-- 🔴 SYMPTOM: map-750 mobs drop nothing, and Errors.log grew from 3 KB to
-- 194 KB with hundreds of
--     Table 'reference_loot_template' Entry 751xxx isn't reference id and not
--     referenced from loot, and thus useless.
--
-- ROOT CAUSE -- MY BUG IN 309_, not a bad apply. **309_ section D changes
-- section C's input.** C clones every reference a map-750 mob uses; D then
-- re-points those mobs at the clones. So on a SECOND run, C looks at
-- `creature_loot_template.Reference` and sees 751xxx -- the clones themselves --
-- treats them as fresh sources, and clones the clones:
--
--   gen1  751000-751191   cloned from the real classic refs   (5,218 rows)
--   gen2  751192-751383   cloned from GEN1                    (0 rows)
--
-- gen2 is EMPTY, and that is the second half of the bug. C's statement order is
--     DELETE  rows whose Entry is any clone_ref      <- wipes gen1's rows
--     INSERT  rows read from each clone's source     <- gen2's source WAS gen1
-- so the delete removed gen2's source before the insert could read it. gen1 was
-- rebuilt fine (its source, the classic refs, was never touched), but gen2 came
-- out with nothing -- and D had already re-pointed all 1,635 live loot rows at
-- gen2. Every map-750 mob is therefore rolling an empty reference.
--
-- THE DATA IS NOT LOST. gen1 is complete and correct: 5,218 rows, 3,437 item
-- rows pointing at the rescaled clones, 501 at originals (grey/white gear,
-- cloth, recipes -- intended), 1,280 nested reference rows. This file simply
-- points the live loot back at gen1 and removes the gen2 layer.
--
-- 309_ IS FIXED AT SOURCE TOO (both C and D now ignore references that are
-- already clones), so a third apply is a no-op instead of building gen3.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Re-point the live loot rows from gen2 back to gen1
-- ---------------------------------------------------------------------------
-- `Reference` is part of the primary key (Entry, Item, Reference, GroupId), so
-- this is a DELETE + INSERT rather than an UPDATE, same as 309_ section D.
-- The gen2 -> gen1 mapping is exact: every gen2 row in `dc_map750_ref_clone`
-- has src_ref = the gen1 clone_ref it was copied from (192 of 192 verified).
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `dc_regen`;
CREATE TEMPORARY TABLE `dc_regen` (
  `Entry` INT UNSIGNED NOT NULL, `Item` INT UNSIGNED NOT NULL,
  `Reference` INT NOT NULL, `Chance` FLOAT NOT NULL, `QuestRequired` TINYINT NOT NULL,
  `LootMode` SMALLINT UNSIGNED NOT NULL, `GroupId` TINYINT UNSIGNED NOT NULL,
  `MinCount` TINYINT UNSIGNED NOT NULL, `MaxCount` TINYINT UNSIGNED NOT NULL,
  `gen1_ref` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`Entry`,`Item`,`Reference`,`GroupId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_regen`
SELECT l.`Entry`, l.`Item`, l.`Reference`, l.`Chance`, l.`QuestRequired`,
       l.`LootMode`, l.`GroupId`, l.`MinCount`, l.`MaxCount`, rc.`src_ref`
FROM `creature_loot_template` l
JOIN `dc_map750_ref_clone` rc ON rc.`clone_ref` = l.`Reference`
WHERE l.`Reference` BETWEEN 751192 AND 751999
  AND rc.`src_ref` BETWEEN 751000 AND 751191;

DELETE l FROM `creature_loot_template` l
JOIN `dc_regen` d
  ON d.`Entry` = l.`Entry` AND d.`Item` = l.`Item`
 AND d.`Reference` = l.`Reference` AND d.`GroupId` = l.`GroupId`;

INSERT INTO `creature_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT d.`Entry`, d.`gen1_ref`, d.`gen1_ref`, d.`Chance`, d.`QuestRequired`,
       d.`LootMode`, d.`GroupId`, d.`MinCount`, d.`MaxCount`,
       CONCAT('DC750 rescaled (ref ', d.`gen1_ref`, ')')
FROM `dc_regen` d;

DROP TEMPORARY TABLE IF EXISTS `dc_regen`;

-- ---------------------------------------------------------------------------
-- B) Remove the gen2 layer
-- ---------------------------------------------------------------------------
-- gen2 has no `reference_loot_template` rows to delete (that is the bug), but
-- the DELETE is kept so this is correct even if a partial gen2 exists.
-- ---------------------------------------------------------------------------
DELETE r FROM `reference_loot_template` r
WHERE r.`Entry` BETWEEN 751192 AND 751999;

DELETE rc FROM `dc_map750_ref_clone` rc
WHERE rc.`clone_ref` BETWEEN 751192 AND 751999;

-- After this, `dc_map750_ref_clone` holds exactly the 192 classic -> gen1 rows,
-- which is what makes a re-run of 309_ a no-op: its NOT EXISTS guard on
-- `src_ref` matches the classic refs again.

-- ---------------------------------------------------------------------------
-- Verify (expected: 192 / 5218 / 1635 / 0 / 0)
-- ---------------------------------------------------------------------------
--   SELECT COUNT(*) FROM dc_map750_ref_clone;                                  -- 192
--   SELECT COUNT(*) FROM reference_loot_template WHERE Entry BETWEEN 751000 AND 751999;  -- 5218
--   SELECT COUNT(*) FROM creature_loot_template WHERE Reference BETWEEN 751000 AND 751191; -- 1635
--   SELECT COUNT(*) FROM creature_loot_template WHERE Reference >= 751192;     -- 0
--   -- every live map-750 reference now resolves to rows:
--   SELECT COUNT(*) FROM creature_loot_template l
--     JOIN creature_template ct ON ct.lootid = l.Entry
--     JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
--    WHERE l.Reference > 0
--      AND NOT EXISTS (SELECT 1 FROM reference_loot_template r WHERE r.Entry = l.Reference); -- 0
--   -- and Errors.log should be back to ~3 KB after the restart.
-- ---------------------------------------------------------------------------
