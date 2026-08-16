-- ---------------------------------------------------------------------------
-- 290  The three things 288_ deferred: gold, the vanilla junk layer, skinning
-- ---------------------------------------------------------------------------
-- Four sections, each independently revertible and each backed by a measurement
-- rather than a guess. Two of them are fixes to EARLIER files of mine, found by
-- going looking for the cause rather than re-deriving the symptom.
--
--   1  gold      271 templates on 750/861 below 235_'s own curve
--   2  skinning  23 beasts 239_ missed -- it queried the WRONG SOURCE DB
--   3  junk loot 4,118 vanilla gear rows on level-87 mobs, + 22 tables that
--                 would be left without a ladder ref
--   4  duplicates 107 orphaned loot tables, PROVEN redundant -- this finally
--                 closes the "isn't creature entry ... and thus useless" class
--                 that has been carried as "benign" since r20
--
-- Apply against acore_world, then restart worldserver. Idempotent throughout:
-- section 1 is a floor (only ever raises), 2 is guarded on skinloot = 0, and
-- 3 and 4 delete into backup tables and re-run clean.

-- ---------------------------------------------------------------------------
-- 1) Gold -- 235_'s curve is right, its GUARD is what went stale
-- ---------------------------------------------------------------------------
-- The symptom I reported after 288_ was "the peer data is too inconsistent to
-- copy from -- rank-4 bosses at 18-156 copper next to rank-0 mobs at 17,000".
-- That is real, and the cause is a two-file interaction:
--
--   235_ sets gold from level:  mingold = maxlevel * 100 * rankMult
--                               maxgold = maxlevel * 180 * rankMult
--                               rankMult: rank 0 = 1.0, rank 4 = 5.0, else 2.5
--        ...but ONLY where the 233_ SNAPSHOT gold was 0/0, deliberately, so
--        that hand-authored gold survives.
--   233_ had already multiplied those creatures' LEVELS by up to 4x.
--
-- So every creature that arrived with Blizzard-authored vanilla gold kept a
-- value written for level 16-51 while its level went to 92-130. Examples, with
-- their snapshot levels, straight from the live rows:
--
--   3603773 Akkrilus            rank 4  lvl 100 (was 26)   34-49 copper
--   3702186 Carnivous the Breaker rank 4 lvl 92 (was 19)   18-29 copper
--   3702184 Lady Moongazer      rank 4  lvl 92 (was 16)    20-31 copper
--   3606650 General Fangferror  rank 4  lvl 92 (was 51)   101-137 copper
--
-- A level-100 rare boss worth 34 copper. Worst case in the set is 1/2957 of
-- what its level says.
--
-- THE FIX IS A FLOOR, NOT A REWRITE. 235_'s intent -- preserve hand-authored
-- gold -- is still right for anything authored ABOVE the curve (Cata values
-- generally are). So this only raises rows that sit BELOW it and leaves
-- everything else untouched. That also makes it re-runnable by construction:
-- once raised, a row is no longer below the curve.
--
-- SCOPE: 271 templates spawned on 750 or 861 -- 222 with stale non-zero gold,
-- 49 with none at all. Same type screen as 235_ (2 dragonkin, 3 demon,
-- 4 elemental, 5 giant, 6 undead, 7 humanoid, 9 mechanical, 11 uncategorized);
-- beasts stay coinless on purpose, that is what section 2 is for.
--
-- 🔴 THIS ALSO COVERS MAP 861, WHICH 235_ NEVER TOUCHED AT ALL. 235_ joins
-- `dc_map750_entryzone`, and Molten Front has no rows in that table -- 231_ only
-- ever zoned map 750. 41 of the 271 are 861's, and 35 of those had zero gold.
-- Scoping on "spawned on 750 or 861" instead of on the zone table is what closes
-- that hole; do not re-scope this to entryzone.
UPDATE acore_world.`creature_template` ct
SET ct.`mingold` = ROUND(ct.`maxlevel` * 100 *
      (CASE ct.`rank` WHEN 0 THEN 1.0 WHEN 4 THEN 5.0 ELSE 2.5 END)),
    ct.`maxgold` = ROUND(ct.`maxlevel` * 180 *
      (CASE ct.`rank` WHEN 0 THEN 1.0 WHEN 4 THEN 5.0 ELSE 2.5 END))
WHERE ct.`entry` IN (SELECT DISTINCT `id` FROM acore_world.`creature` WHERE `map` IN (750, 861))
  AND ct.`npcflag` = 0
  AND ct.`type` IN (2, 3, 4, 5, 6, 7, 9, 11)
  AND ct.`minlevel` > 1
  AND (ct.`flags_extra` & 128) = 0
  AND ct.`maxgold` < ROUND(ct.`maxlevel` * 180 *
      (CASE ct.`rank` WHEN 0 THEN 1.0 WHEN 4 THEN 5.0 ELSE 2.5 END));

-- ---------------------------------------------------------------------------
-- 2) Skinning -- 239_ asked the wrong database for the +3.7M band
-- ---------------------------------------------------------------------------
-- 239_ backfills skinloot from the source, and both of its UPDATE statements
-- join `cata_world` -- one at `entry - 3600000`, one at `entry - 3700000`. But
-- the +3,700,000 band's source is **nelt_world**, not cata_world. The join
-- still resolves (both DBs hold the same classic creature ids) so it fails
-- silently, and it simply reports "not skinnable" wherever Cataclysm removed a
-- skin table that vanilla had.
--
-- Measured: of the 54 zoned beasts on 750 in the +3.7M band with skinloot = 0,
-- **cata_world says 0 are skinnable and nelt_world says 23 are**. All 82 of
-- those 23 beasts' nelt skin rows reference items that already exist here, so
-- nothing is skipped for a missing item and no table ends up empty -- the
-- failure mode 239_ guards against cannot fire.
--
-- These are Darkshore/Ashenvale wildlife: Fleetfoot, Moonstalker, Darkshore
-- Stag, Thistle Bear Cub, Corrupted Thistle Bear and friends -- beasts that
-- give no gold by design and, until now, no skin either, i.e. nothing at all.
--
-- 2a. point skinloot at the entry's own id (232_'s lootid == entry invariant)
UPDATE acore_world.`creature_template` ct
JOIN acore_world.`dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `nelt_world`.`creature_template` src ON src.`entry` = CAST(ct.`entry` AS SIGNED) - 3700000
SET ct.`skinloot` = ct.`entry`
WHERE ct.`entry` BETWEEN 3700000 AND 3799999
  AND ct.`type` = 1 AND ct.`skinloot` = 0 AND ct.`minlevel` > 1
  AND src.`skinloot` <> 0;

-- 2b. copy the nelt skin rows under our own ids. Existing-item rows only, the
--     same screen 239_ uses -- measured to drop nothing here, but the guard
--     stays so a future re-run on a different set cannot create a skin table
--     full of items the client does not have.
DELETE slt FROM acore_world.`skinning_loot_template` slt
JOIN acore_world.`creature_template` ct ON ct.`entry` = slt.`Entry`
WHERE ct.`entry` BETWEEN 3700000 AND 3799999
  AND ct.`type` = 1 AND ct.`skinloot` = ct.`entry`
  AND EXISTS (SELECT 1 FROM `nelt_world`.`creature_template` s2
               WHERE s2.`entry` = CAST(ct.`entry` AS SIGNED) - 3700000 AND s2.`skinloot` <> 0);

INSERT INTO acore_world.`skinning_loot_template`
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT ct.`entry`, sl.`item`, 0, sl.`ChanceOrQuestChance`, 0, 1, sl.`groupid`, sl.`mincountOrRef`, sl.`maxcount`,
       CONCAT('DC750 skin from nelt ', src.`entry`, ' (290 -- 239_ used cata_world for this band)')
FROM acore_world.`creature_template` ct
JOIN acore_world.`dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `nelt_world`.`creature_template` src ON src.`entry` = CAST(ct.`entry` AS SIGNED) - 3700000
JOIN `nelt_world`.`skinning_loot_template` sl ON sl.`entry` = src.`skinloot`
WHERE ct.`entry` BETWEEN 3700000 AND 3799999
  AND ct.`type` = 1 AND ct.`skinloot` = ct.`entry` AND src.`skinloot` <> 0
  AND EXISTS (SELECT 1 FROM acore_world.`item_template` i WHERE i.`entry` = sl.`item`)
  -- MaNGOS overloads two columns with negative values: ChanceOrQuestChance < 0
  -- means quest-gated, mincountOrRef < 0 means the row is a REFERENCE, not an
  -- item. Measured across all 82 rows in this set: zero of either. The guards
  -- stay so a re-run over a wider set cannot silently import a negative count
  -- as MinCount (a tinyint unsigned -- it would wrap) or a reference as an item.
  AND sl.`ChanceOrQuestChance` > 0
  AND sl.`mincountOrRef` > 0;

-- ---------------------------------------------------------------------------
-- 3) The vanilla junk gear layer
-- ---------------------------------------------------------------------------
-- The question was "is the loot scaled to the area levels?" and the answer was
-- "the ladder was added, the original loot was never rebalanced".
--
-- 🔴 MY FIRST ATTEMPT AT A RULE FOR THIS WAS WRONG AND IS WORTH RECORDING.
-- I started from "item RequiredLevel far below the creature's level", which
-- flagged **15,309 rows** and looked like a huge find. It is a broken test on
-- this continent: source item ReqLvl caps at 85 everywhere, while DC creatures
-- run to 130, so it flags all legitimate Cata endgame gear too (the flagged set
-- averaged ilvl 215 -- clearly not junk).
--
-- ITEM LEVEL is the signal that actually separates them, and it separates them
-- cleanly. Direct (Reference = 0) weapon/armour rows on the 750/861 forked
-- tables, bucketed:
--
--   ilvl <60     4,118 rows  271 tables  562 items  avg creature lvl  87  avg ReqLvl  18   <- junk
--   ilvl 60-99      93 rows    4 tables
--   ilvl 100-199 3,773 rows   78 tables  avg creature lvl 119  avg ReqLvl 114
--   ilvl 200-299 9,338 rows   60 tables  avg creature lvl 114  avg ReqLvl  81
--   ilvl 300+    4,361 rows   75 tables  avg creature lvl 125  avg ReqLvl  95
--
-- Only the first bucket is the vanilla layer, and there is a 40-point gap to
-- the next one, so the threshold is not a judgement call sitting on a slope.
-- Level-87 mobs dropping ReqLvl-18 greens; everything at ilvl 100+ is DC or
-- Cata gear and is left alone.
--
-- WHAT IS *NOT* REMOVED: cloth, leather, meat, mats, consumables, quest items,
-- and every reference row. Those are level-agnostic and are most of what these
-- tables are -- 8,745 rows survive on the 271 affected tables (1,110 references
-- + 7,635 non-gear items). Verified: **0 tables are left empty.**
--
-- 3a. back up first -- this is the revert key and the record of what went
DROP TABLE IF EXISTS acore_world.`dc_map750_junkgear_backup`;
CREATE TABLE acore_world.`dc_map750_junkgear_backup` LIKE acore_world.`creature_loot_template`;

INSERT INTO acore_world.`dc_map750_junkgear_backup`
SELECT l.* FROM acore_world.`creature_loot_template` l
JOIN acore_world.`creature_template` t ON t.`lootid` = l.`Entry`
JOIN acore_world.`item_template` i ON i.`entry` = l.`Item`
WHERE t.`entry` IN (SELECT DISTINCT `id` FROM acore_world.`creature` WHERE `map` IN (750,861))
  AND t.`lootid` BETWEEN 3600000 AND 3799999
  AND l.`Reference` = 0
  AND i.`class` IN (2,4)
  AND i.`ItemLevel` < 60;

-- 3b. delete exactly what was saved -- the DELETE joins the backup rather than
--     re-deriving the set, so removed == saved even if something shifts between
--     the two statements (the trap 285_ was written to avoid).
DELETE l FROM acore_world.`creature_loot_template` l
JOIN acore_world.`dc_map750_junkgear_backup` b
  ON b.`Entry` = l.`Entry` AND b.`Item` = l.`Item`
 AND b.`Reference` = l.`Reference` AND b.`GroupId` = l.`GroupId`;

-- 3c. 22 of the 271 affected tables have no ladder reference at all, so after
--     3b they would hold only trash. Give them their zone's ladder ref on the
--     same terms 288_ used -- chance 2 for rank 0, 6 for rank>0, `Item` echoing
--     the reference id, LootMode 1.
DELETE l FROM acore_world.`creature_loot_template` l
WHERE l.`Comment` = 'DC750 ladder drop (290 junk-layer backfill)';

INSERT INTO acore_world.`creature_loot_template`
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT r.`lootid`, r.`refid`, r.`refid`, r.`chance`, 0, 1, 0, 1, 1,
       'DC750 ladder drop (290 junk-layer backfill)'
FROM (
  SELECT t.`lootid`,
         IF(t.`rank` > 0, 6, 2) AS `chance`,
         CASE
           WHEN EXISTS (SELECT 1 FROM acore_world.`creature` c WHERE c.`id` = t.`entry` AND c.`map` = 861) THEN 750113
           WHEN ez.`zone` = 4929 THEN 750080
           WHEN ez.`zone` = 4930 THEN 750081
           WHEN ez.`zone` = 4931 THEN 750088
           WHEN ez.`zone` = 4927 THEN 750096
           WHEN ez.`zone` = 4926 THEN 750104
           ELSE 750113
         END AS `refid`
  FROM acore_world.`creature_template` t
  JOIN (SELECT DISTINCT `Entry` FROM acore_world.`dc_map750_junkgear_backup`) j ON j.`Entry` = t.`lootid`
  LEFT JOIN acore_world.`dc_map750_entryzone` ez ON ez.`entry` = t.`entry`
  WHERE NOT EXISTS (SELECT 1 FROM acore_world.`creature_loot_template` l2
                     WHERE l2.`Entry` = t.`lootid`
                       AND l2.`Reference` IN (750080,750081,750088,750096,750104,750113))
) r;

-- ---------------------------------------------------------------------------
-- 4) 107 duplicate loot tables -- the "useless" class, finally closed
-- ---------------------------------------------------------------------------
--     Table 'creature_loot_template' Entry 32860 isn't creature entry and not
--     referenced from loot, and thus useless.
--
-- This class has been carried as "documented benign, blind deletion is
-- dangerous (266_)" for many rounds. It is now settled with evidence rather
-- than left as a judgement call.
--
-- WHAT THEY ARE: an importer wrote nelt's loot at the RAW source id before 232_
-- established `lootid == entry` for the clone band. Every single one of the 107
-- has a **+3,700,000 clone that exists AND is spawned**, and **0 of those clones
-- have lootid = 0** -- they all already carry their own forked table.
--
-- THE TEST THAT MAKES DELETION SAFE, and the reason this is not 266_ again:
-- for each orphan, every (Item, Reference) pair it holds must also appear in
-- the live clone's table. Run over all 107: **107 are strict subsets, 0 would
-- lose data.** The clones consistently hold 2 rows MORE (the ladder ref and a
-- reband row added by 236_/237_). So this removes 4,002 rows that are pure
-- duplicates of rows that stay.
--
-- 🔴 THE OTHER "useless" CLASSES FAIL THIS TEST AND ARE NOT TOUCHED.
-- Applying the same +3.7M duplicate check to them:
--     pickpocketing_loot_template  4 orphans -- 0 are duplicates
--     skinning_loot_template       6 orphans -- 1 is a duplicate
--     reference_loot_template     61 orphans -- and my orphan test for that
--        table is INCOMPLETE: a Reference can be held by mail/spell/fishing/
--        disenchant/prospecting/milling loot tables that the check did not
--        look at, which is why it reports 61 while the core only flags 2.
-- Unproven is not the same as junk. They stay.
DROP TABLE IF EXISTS acore_world.`dc_orphan_loot_backup`;
CREATE TABLE acore_world.`dc_orphan_loot_backup` LIKE acore_world.`creature_loot_template`;

INSERT INTO acore_world.`dc_orphan_loot_backup`
SELECT l.* FROM acore_world.`creature_loot_template` l
WHERE l.`Entry` IN (
  SELECT z.`Entry` FROM (
    SELECT DISTINCT d.`Entry` FROM acore_world.`creature_loot_template` d
     WHERE NOT EXISTS (SELECT 1 FROM acore_world.`creature_template` t WHERE t.`lootid` = d.`Entry`)
       AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_loot_template` r WHERE r.`Reference` = d.`Entry`)
       AND NOT EXISTS (SELECT 1 FROM acore_world.`reference_loot_template` r2 WHERE r2.`Reference` = d.`Entry`)
       AND EXISTS (SELECT 1 FROM acore_world.`creature` c WHERE c.`id` = d.`Entry` + 3700000)
       AND NOT EXISTS (
             SELECT 1 FROM acore_world.`creature_loot_template` a
              WHERE a.`Entry` = d.`Entry`
                AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_loot_template` b
                                 WHERE b.`Entry` = d.`Entry` + 3700000
                                   AND b.`Item` = a.`Item` AND b.`Reference` = a.`Reference`))
  ) z);

DELETE l FROM acore_world.`creature_loot_template` l
JOIN acore_world.`dc_orphan_loot_backup` b
  ON b.`Entry` = l.`Entry` AND b.`Item` = l.`Item`
 AND b.`Reference` = l.`Reference` AND b.`GroupId` = l.`GroupId`;

-- ---------------------------------------------------------------------------
-- Verify after apply
-- ---------------------------------------------------------------------------
--  1  SELECT COUNT(*) FROM creature_template t
--      WHERE t.entry IN (SELECT DISTINCT id FROM creature WHERE map IN (750,861))
--        AND t.npcflag=0 AND t.type IN (2,3,4,5,6,7,9,11) AND t.minlevel>1
--        AND (t.flags_extra&128)=0
--        AND t.maxgold < ROUND(t.maxlevel*180*(CASE t.`rank` WHEN 0 THEN 1.0
--              WHEN 4 THEN 5.0 ELSE 2.5 END));                            -> 0
--     SELECT entry, maxlevel, mingold, maxgold FROM creature_template
--      WHERE entry=3603773;        -> Akkrilus lvl 100 rank 4: 50000-90000
--
--  2  SELECT COUNT(*) FROM creature_template t
--      JOIN dc_map750_entryzone ez ON ez.entry=t.entry
--      WHERE t.type=1 AND t.skinloot=t.entry
--        AND t.entry BETWEEN 3700000 AND 3799999;              -> was 0, now 23
--     SELECT COUNT(*) FROM skinning_loot_template
--      WHERE Comment LIKE 'DC750 skin from nelt%';                        -> 82
--     SELECT COUNT(*) FROM creature_template t WHERE t.skinloot<>0
--       AND NOT EXISTS (SELECT 1 FROM skinning_loot_template s
--                        WHERE s.Entry=t.skinloot);   -> 0 (no dangling skinloot)
--
--  3  SELECT COUNT(*) FROM dc_map750_junkgear_backup;                 -> 4,118
--     SELECT COUNT(*) FROM creature_loot_template l
--      JOIN creature_template t ON t.lootid=l.Entry
--      JOIN item_template i ON i.entry=l.Item
--      WHERE t.entry IN (SELECT DISTINCT id FROM creature WHERE map IN (750,861))
--        AND t.lootid BETWEEN 3600000 AND 3799999
--        AND l.Reference=0 AND i.class IN (2,4) AND i.ItemLevel<60;        -> 0
--     SELECT COUNT(*) FROM creature_loot_template
--      WHERE Comment='DC750 ladder drop (290 junk-layer backfill)';       -> 22
--     -- and no table may be empty:
--     SELECT COUNT(*) FROM creature_template t
--      WHERE t.lootid<>0 AND NOT EXISTS
--        (SELECT 1 FROM creature_loot_template l WHERE l.Entry=t.lootid);  -> 0
--
--  4  SELECT COUNT(DISTINCT Entry) FROM dc_orphan_loot_backup;          -> 107
--     SELECT COUNT(*) FROM dc_orphan_loot_backup;                      -> 4,002
--     next boot: the ~107 creature_loot_template "useless" lines are gone.
--     The 4 pickpocket + 6 skinning + 2 reference "useless" lines REMAIN, on
--     purpose.
--
-- REVERT
--   3: INSERT INTO creature_loot_template SELECT * FROM dc_map750_junkgear_backup;
--      DELETE FROM creature_loot_template
--       WHERE Comment='DC750 ladder drop (290 junk-layer backfill)';
--   4: INSERT INTO creature_loot_template SELECT * FROM dc_orphan_loot_backup;
--   2: UPDATE creature_template SET skinloot=0 WHERE entry BETWEEN 3700000 AND 3799999
--       AND type=1 AND skinloot=entry;
--      DELETE FROM skinning_loot_template WHERE Comment LIKE 'DC750 skin from nelt%';
--   1: no backup -- the curve is deterministic from level and rank, and the
--      pre-image was demonstrably wrong. `dc_map750_snap` still holds the
--      original vanilla gold in mingold0/maxgold0 if you ever want it back.
--
-- Both backup tables can be dropped once you are happy; the core never reads
-- them. `dc_map750_snap`, `_band`, `_entryzone`, `_chunkzone` must STAY.
--
-- ---------------------------------------------------------------------------
-- Still open, and why it is not in this file
-- ---------------------------------------------------------------------------
-- **Winterspring has no gear step-up.** Reference 750104 (Winterspring 104-115)
-- resolves to ilvl 372 / ReqLvl 102 -- byte-identical in tier to 750096
-- (Felwood 96-106). That is 238_'s four-tier ladder (ReqLvl 82/92/102/115)
-- stretched across six zones, so a player gains nothing new for eleven levels.
-- Closing it properly means a FIFTH 15-item tier at roughly ilvl 385 / ReqLvl
-- 108: new item ids, `gen_map750_themed_sets.py` run, Item.dbc + ItemDisplayInfo
-- rebuild and a client deploy, plus a `dc_item_upgrade_tiers` review since
-- tier-4 membership is purely ItemLevel. That is a project with a balance
-- decision in it (what ilvl, and whether Hyjal's 398 should move up to keep its
-- lead), not a section -- so it wants deciding rather than guessing.
