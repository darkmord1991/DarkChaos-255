-- ---------------------------------------------------------------------------
-- 266  creature_loot_template -- the orphan duplicates and two singletons
-- ---------------------------------------------------------------------------
-- With 265_ applied the loot block is down to three classes. This closes two of
-- them and explains why the third is deliberately left alone.
--
-- 🔴 THE INVESTIGATION CHANGED THE FIX. The 327 "isn't creature entry and not
-- referenced from loot, and thus useless" lines look like pure noise, and the
-- obvious move -- delete every orphan -- would have DESTROYED CONTENT. Breaking
-- them down:
--
--   A  220  the +3,600,000 clone table exists AND a creature points at it, so
--           the raw copy is unreachable import duplication
--   D  107  no creature at the raw id NOR at +3,600,000
--   (B and C are both 0 -- there is no case of a clone using a different lootid,
--    and no case of a live creature at the raw id)
--
-- and then, comparing class A row by row rather than trusting the label:
--
--   71  raw and clone have the same row count
--  141  the clone has MORE rows than the raw
--    8  the RAW has more rows than the clone
--   16  the raw contains an item the clone does NOT  <-- would have been lost
--
-- All 16 differ by exactly one item: 400000 "Emberwood Sap", the DC Hyjal
-- Frontier token. It sits on 591 loot tables -- 534 in the clone band and 57 raw
-- ones, of which ZERO are reachable. So a past round added the token to the
-- clone tables (right) and to a handful of raw ones (dead), and for these 16
-- creatures ONLY the dead copy got it. That is a real content gap, not
-- bookkeeping: 16 Hyjal Frontier creatures never drop a token they should.
--
-- So section 1 gives those 16 clones their token, and only then does section 2
-- delete the raw tables -- by which point all 220 are provably redundant.

-- ---- 1. the 16 clone tables missing Emberwood Sap --------------------------
-- Chance / MinCount / MaxCount are carried over from the raw row rather than
-- flattened, because they vary by creature (13 at 8%, two at 22% 1-2, one at
-- 60% 1-3) and match the per-creature tuning the other 534 clones already have.
-- Guarded on the clone not already having the item, so re-running is a no-op.
INSERT INTO acore_world.`creature_loot_template`
(`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT raw.`Entry` + 3600000, raw.`Item`, raw.`Reference`, raw.`Chance`, raw.`QuestRequired`,
       raw.`LootMode`, raw.`GroupId`, raw.`MinCount`, raw.`MaxCount`, 'DC750 Emberwood Sap token'
FROM acore_world.`creature_loot_template` raw
WHERE raw.`Item` = 400000
  AND raw.`Entry` IN (40134,50419,50478,52107,52552,52648,52660,52680,52981,53152,53240,53245,53249,53656,54322,54339)
  AND EXISTS (SELECT 1 FROM acore_world.`creature_template` ct WHERE ct.`lootid` = raw.`Entry` + 3600000)
  AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_loot_template` cl
                  WHERE cl.`Entry` = raw.`Entry` + 3600000 AND cl.`Item` = 400000);

-- ---- 2. drop the now-redundant raw duplicates ------------------------------
-- A backup table first, so this is trivially reversible without going back to
-- source:  INSERT INTO creature_loot_template SELECT * FROM clt_backup_r266;
DROP TABLE IF EXISTS acore_world.`clt_backup_r266`;

CREATE TABLE acore_world.`clt_backup_r266` LIKE acore_world.`creature_loot_template`;

-- The safe set is RE-DERIVED at apply time rather than frozen as an id list, so
-- it can only ever touch tables that still satisfy all three conditions when you
-- run it: nothing references them, a +3,600,000 clone table is live, and every
-- one of their rows already exists on that clone. Section 1 is what makes the
-- last condition true for the 16 -- run these in order.
INSERT INTO acore_world.`clt_backup_r266`
SELECT * FROM acore_world.`creature_loot_template` WHERE `Entry` IN (
  SELECT * FROM (
    SELECT DISTINCT l.`Entry` FROM acore_world.`creature_loot_template` l
    WHERE NOT EXISTS (SELECT 1 FROM acore_world.`creature_template` ct
            WHERE ct.`lootid` = l.`Entry` OR ct.`pickpocketloot` = l.`Entry` OR ct.`skinloot` = l.`Entry`)
      AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_loot_template` r WHERE r.`Reference` = l.`Entry`)
      AND EXISTS (SELECT 1 FROM acore_world.`creature_template` c2 WHERE c2.`lootid` = l.`Entry` + 3600000)
      AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_loot_template` a
            WHERE a.`Entry` = l.`Entry`
              AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_loot_template` b
                    WHERE b.`Entry` = l.`Entry` + 3600000 AND b.`Item` = a.`Item` AND b.`Reference` = a.`Reference`))
  ) keep
);

DELETE FROM acore_world.`creature_loot_template` WHERE `Entry` IN (
  SELECT * FROM (SELECT DISTINCT `Entry` FROM acore_world.`clt_backup_r266`) gone
);

-- ---- 3. Entry 164407 group 1 sums to 114% ----------------------------------
--     Table 'creature_loot_template' entry 164407 group 1 has total chance
--     > 100% (114)
--
-- Eight Castle Nathria armour pieces in one group: 15 + 15 + 14 x6 = 114. In a
-- grouped drop the chances are a distribution and must not exceed 100, or the
-- tail entries can never roll. Rescaled by 100/114 so the RELATIVE weighting is
-- untouched -- the two 15s stay proportionally ahead of the six 14s -- landing
-- on 99.98 rather than flattening everything to 12.5 and losing that intent.
UPDATE acore_world.`creature_loot_template` SET `Chance` = 13.15
WHERE `Entry` = 164407 AND `GroupId` = 1 AND `Item` IN (182981,182984);

UPDATE acore_world.`creature_loot_template` SET `Chance` = 12.28
WHERE `Entry` = 164407 AND `GroupId` = 1 AND `Item` IN (182999,183005,183006,183016,183022,184026);

-- ---- 4. Reverberating Eruption Stalker 175102 ------------------------------
--     Table 'creature_loot_template' Entry 175102 does not exist but it is used
--     by Creature 175102
--
-- A Shadowlands trigger dummy: 0 spawns, unit_flags 768, and NO loot table in
-- nelt_world or cata_world either -- so there is nothing to restore and the
-- lootid is simply wrong. Cleared rather than inventing a drop table for an
-- invisible stalker. Guarded so it cannot fire if a table is added later.
UPDATE acore_world.`creature_template` SET `lootid` = 0
WHERE `entry` = 175102 AND `lootid` = 175102
  AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_loot_template` l WHERE l.`Entry` = 175102);

-- ---- NOT TOUCHED: the 107 class-D orphans ---------------------------------
-- No creature exists at the raw id or at +3,600,000, so these are loot tables
-- for content that was never imported (or was removed). Unlike class A there is
-- no live copy holding the same rows, so deleting them discards the only copy we
-- have of that creature's drops -- and a later import would want them. They cost
-- 107 boot-log lines and nothing else. Leave them until the matching creatures
-- are either imported or written off deliberately.
--
-- Verify after apply:
--   * SELECT COUNT(*) FROM creature_loot_template WHERE Item = 400000
--       AND Entry >= 3600000;                          -> 550 (was 534)
--   * SELECT COUNT(*) FROM clt_backup_r266;            -> ~23,000 rows / 220 tables
--   * the orphan count drops 327 -> 107:
--       SELECT COUNT(*) FROM (SELECT DISTINCT l.Entry FROM creature_loot_template l
--        WHERE NOT EXISTS (SELECT 1 FROM creature_template ct WHERE ct.lootid=l.Entry
--                OR ct.pickpocketloot=l.Entry OR ct.skinloot=l.Entry)
--          AND NOT EXISTS (SELECT 1 FROM creature_loot_template r WHERE r.Reference=l.Entry)) a;
--   * no "total chance > 100%" and no "Entry 175102 does not exist" line.
--   * Once you are happy:  DROP TABLE acore_world.clt_backup_r266;
