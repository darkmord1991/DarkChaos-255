-- ---------------------------------------------------------------------------
-- 322  Map 750 -- rares loot their OWN level's band, not their zone's floor
-- ---------------------------------------------------------------------------
-- This is the file that actually answers the original report: "I killed
-- Antilos, a level 91 rare, and got green level 80 loot."
--
-- 319_ fixed WHAT the items are (they had no stats at all) and 321_ fixed the
-- level they gate at. Neither touches WHICH pool a rare draws from, and that is
-- the real mismatch:
--
--   🔴 EVERY named rare on the continent stands 1-2 levels ABOVE its zone band's
--   CEILING, but loots from the band's FLOOR.
--
--     zone band     rare levels     loots from      should loot
--     80 - 90         91 - 92        band 80          band 88
--     88 - 98         99 - 100       band 88          band 96
--     96 - 106       107 - 108       band 96          band 104
--     104 - 115      116 - 117       band 104         band 113
--     113 - 128      129 - 130       band 113         band 113 (top)
--
--   That is not a handful of outliers -- it is all 46 rank >= 2 creatures, and
--   it is clearly deliberate creature design (rares are meant to be a step above
--   the zone). Only the loot never followed.
--
--   43 of the 46 are actually touched. The other three -- Malfurion Stormrage
--   (twice) and Aros -- have `lootid = 0`, i.e. no loot table at all: they are
--   lore NPCs, not kills. 🔴 The `ct.lootid = ct.entry` guard in step 3 is what
--   keeps them out, and it is load-bearing: `lootid = 0` is shared by 29,075
--   creature templates server-wide, so writing a loot row at Entry 0 would
--   attach this pool to a third of the game.
--
-- ---------------------------------------------------------------------------
-- THE RULE -- derived, not hardcoded
-- ---------------------------------------------------------------------------
-- A rare draws from the band whose level range contains ITS OWN level:
--
--     promoted_band = MAX(t_lo) FROM dc_map750_band WHERE t_lo <= creature_level
--
-- Because the bands overlap by two levels at every seam (80-90, 88-98, 96-106,
-- ...), taking the HIGHEST qualifying floor lands on exactly "one band up" for
-- every rare, without a single hardcoded pairing. Verified against all 46:
--
--     promoted to    mobs   rare levels   from zone band
--         88          17      90 - 92          80
--         96           8        100            88
--        104           7     106 - 108         96
--        113          13     114 - 130      104, 113
--
-- The top band (113-128) has nowhere to go and keeps its own pool -- correct,
-- since its rares at 129-130 are the end of the continent.
--
-- 🔴 ONE STRAGGLER: "The Ongar" (3714345) is level 51 while standing in Felwood
-- (banded 96-106). Its own level resolves to no band at all, so it falls back to
-- its ZONE band via COALESCE. That keeps its loot consistent with where it
-- stands, but the creature itself was missed by the 233_ re-level and should be
-- fixed separately -- a level-51 rare in a level-100 zone is its own bug.
--
-- ---------------------------------------------------------------------------
-- WHAT IT DOES
-- ---------------------------------------------------------------------------
-- 1. Builds one reference per band that something promotes TO, holding every
--    equippable clone of that band, equal chance:
--
--      752088 -> 1,196 items (1,096 green / 82 blue / 18 epic)
--      752096 ->   110       (79 / 22 / 9)
--      752104 ->   637       (538 / 75 / 24)
--      752113 ->   101       (80 / 21 / 0)
--
--    Band 80 gets NO pool: rares draw from the band above their own and the
--    lowest rank >= 2 creature is level 90, so nothing promotes to band 80.
--    Building it anyway produced a "useless reference" warning on the live
--    server -- see the EXISTS guard in step 1 and the cleanup in 324_.
--
--    Blues and epics are already in these pools, so a promoted rare gets a real
--    shot at one without a separate rarity layer being invented here.
--
-- 2. REMOVES the 177 band-floor clone references currently on those 46 creatures
--    (29 loot tables, 51 table/group pairs, groups 0/1/5/6). Without this the
--    rare would still hand out the level-80 green alongside the new drop, which
--    is the exact complaint. Only rows whose `Reference` is in the 751000-751999
--    clone range are touched -- tokens, sap, the 750xxx ladder references and
--    every direct item row are left alone.
--
-- 3. Adds the promoted band's reference to the 43 rank >= 2 creatures that own
--    a loot table: guaranteed for rank 3/4 (boss, named rare), 50% for rank 2
--    (rare elite, which respawn far more freely).
--
-- 🔴 Step 2 is destructive and a re-run cannot undo it, so the deleted rows are
-- snapshotted into `dc_map750_rare_loot_backup` FIRST. That table is the
-- rollback; see the trailer.
--
-- Apply against acore_world, AFTER 319_ and 321_. Idempotent. Needs
-- `.reload creature_loot_template` + `.reload reference_loot_template`, or a
-- worldserver restart.
-- ---------------------------------------------------------------------------

USE `acore_world`;

-- ---------------------------------------------------------------------------
-- 1. Per-band rare reward pools
-- ---------------------------------------------------------------------------
-- Ref id encodes the band floor (752080 = band 80) so the mapping is readable
-- in a loot dump without consulting this file. 752000-752999 verified empty.
DELETE FROM `reference_loot_template` WHERE `Entry` BETWEEN 752080 AND 752113;

INSERT INTO `reference_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 752000 + m.`band_lo`, i.`entry`, 0, 0, 0, 1, 1, 1, 1,
       CONCAT('DC750 rare band-', m.`band_lo`, ' pool - ', i.`name`)
FROM `dc_map750_item_clone` m
JOIN `item_template` i ON i.`entry` = m.`clone_entry`
WHERE i.`class` IN (2, 4)
  AND i.`InventoryType` > 0
  -- 🔴 Only build a pool something actually promotes TO. A rare draws from the
  -- band ABOVE its own and the lowest rank >= 2 creature is level 90, so band 80
  -- has no consumer and its pool would boot as "isn't reference id and not
  -- referenced from loot, and thus useless" (found in the live log; 324_ cleans
  -- up the copy the first apply created). This predicate is the same expression
  -- step 3 uses, so the two cannot disagree about which pools exist.
  AND EXISTS (
    SELECT 1
    FROM `creature_template` ct
    JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
    JOIN `dc_map750_band` zb ON zb.`zone` = ez.`zone`
    WHERE ct.`rank` >= 2
      AND ct.`entry` BETWEEN 3600000 AND 3799999
      AND ct.`lootid` = ct.`entry`
      AND COALESCE(
            (SELECT MAX(bb.`t_lo`)
             FROM (SELECT DISTINCT `t_lo` FROM `dc_map750_band`) bb
             WHERE bb.`t_lo` <= ROUND((ct.`minlevel` + ct.`maxlevel`) / 2)),
            zb.`t_lo`) = m.`band_lo`
  );

-- ---------------------------------------------------------------------------
-- 2. Snapshot, then strip the band-floor gear from rank >= 2 creatures
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_map750_rare_loot_backup` (
  `Entry`         INT UNSIGNED NOT NULL,
  `Item`          INT UNSIGNED NOT NULL,
  `Reference`     INT UNSIGNED NOT NULL,
  `Chance`        FLOAT        NOT NULL,
  `QuestRequired` TINYINT      NOT NULL,
  `LootMode`      SMALLINT UNSIGNED NOT NULL,
  `GroupId`       TINYINT UNSIGNED  NOT NULL,
  `MinCount`      INT UNSIGNED NOT NULL,
  `MaxCount`      INT UNSIGNED NOT NULL,
  `Comment`       TEXT NULL,
  `taken_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`Entry`, `Item`, `Reference`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- INSERT IGNORE against a frozen snapshot: a second run must not overwrite the
-- original rows with whatever the first run left behind.
INSERT IGNORE INTO `dc_map750_rare_loot_backup`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT clt.`Entry`, clt.`Item`, clt.`Reference`, clt.`Chance`, clt.`QuestRequired`,
       clt.`LootMode`, clt.`GroupId`, clt.`MinCount`, clt.`MaxCount`, clt.`Comment`
FROM `creature_loot_template` clt
JOIN `creature_template` ct ON ct.`lootid` = clt.`Entry`
WHERE ct.`rank` >= 2
  AND ct.`entry` BETWEEN 3600000 AND 3799999
  AND clt.`Reference` BETWEEN 751000 AND 751999;

DELETE clt FROM `creature_loot_template` clt
JOIN `creature_template` ct ON ct.`lootid` = clt.`Entry`
WHERE ct.`rank` >= 2
  AND ct.`entry` BETWEEN 3600000 AND 3799999
  AND clt.`Reference` BETWEEN 751000 AND 751999;

-- ---------------------------------------------------------------------------
-- 3. Attach the promoted pool
-- ---------------------------------------------------------------------------
-- GroupId 0 with an explicit Chance: the reference is rolled independently
-- rather than competing inside a group, so the rare's gear drop does not
-- displace its token/sap/ladder rolls.
DELETE FROM `creature_loot_template`
WHERE `Reference` BETWEEN 752080 AND 752113;

INSERT INTO `creature_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT DISTINCT
       ct.`lootid`,
       752000 + r.`promoted_band`,
       752000 + r.`promoted_band`,
       IF(ct.`rank` = 2, 50, 100),
       0, 1, 0, 1, 1,
       CONCAT('DC750 rare promoted to band ', r.`promoted_band`)
FROM `creature_template` ct
JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN `dc_map750_band` zb ON zb.`zone` = ez.`zone`
JOIN LATERAL (
  SELECT COALESCE(
           (SELECT MAX(bb.`t_lo`)
            FROM (SELECT DISTINCT `t_lo` FROM `dc_map750_band`) bb
            WHERE bb.`t_lo` <= ROUND((ct.`minlevel` + ct.`maxlevel`) / 2)),
           zb.`t_lo`) AS `promoted_band`
) r ON TRUE
WHERE ct.`rank` >= 2
  AND ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`lootid` = ct.`entry`;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- Pools built (expect 492 / 1196 / 110 / 637 / 101):
-- SELECT Entry, COUNT(*) FROM reference_loot_template
-- WHERE Entry BETWEEN 752080 AND 752113 GROUP BY Entry ORDER BY Entry;
--
-- Every rank >= 2 creature with a loot table got exactly one promoted row
-- (expect 43 rows, and 0 with more than one):
-- SELECT COUNT(*) FROM creature_loot_template WHERE Reference BETWEEN 752080 AND 752113;
-- SELECT Entry, COUNT(*) c FROM creature_loot_template
-- WHERE Reference BETWEEN 752080 AND 752113 GROUP BY Entry HAVING c > 1;
--
-- No rare still points at a band-floor clone reference (expect 0):
-- SELECT COUNT(*) FROM creature_loot_template clt
-- JOIN creature_template ct ON ct.lootid = clt.Entry
-- WHERE ct.rank >= 2 AND ct.entry BETWEEN 3600000 AND 3799999
--   AND clt.Reference BETWEEN 751000 AND 751999;
--
-- Antilos specifically -- expect ref 752088, and its pool to be ilvl 305-341
-- gear gating at 88-94 rather than ilvl 289 gating at 80:
-- SELECT clt.Reference, i.ItemLevel, i.RequiredLevel, i.Quality, COUNT(*)
-- FROM creature_loot_template clt
-- JOIN reference_loot_template rlt ON rlt.Entry = clt.Reference
-- JOIN item_template i ON i.entry = rlt.Item
-- WHERE clt.Entry = 3606648 AND clt.Reference BETWEEN 752080 AND 752113
-- GROUP BY clt.Reference, i.ItemLevel, i.RequiredLevel, i.Quality
-- ORDER BY i.ItemLevel LIMIT 20;
--
-- ROLLBACK (restores the band-floor references and drops the promotion):
-- DELETE FROM creature_loot_template WHERE Reference BETWEEN 752080 AND 752113;
-- DELETE FROM reference_loot_template WHERE Entry BETWEEN 752080 AND 752113;
-- INSERT IGNORE INTO creature_loot_template
--   (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
-- SELECT Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment
-- FROM dc_map750_rare_loot_backup;
-- ---------------------------------------------------------------------------
