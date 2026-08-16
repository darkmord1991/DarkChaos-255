-- ---------------------------------------------------------------------------
-- 288  The 193 mobs that drop nothing -- and 6 that were never re-levelled
-- ---------------------------------------------------------------------------
-- 🔴 READ THIS FIRST, BECAUSE IT CHANGES WHAT THIS FILE IS.
-- I originally pitched this round as "200 no-loot mobs at endgame levels" as if
-- it were an import miss. It is NOT. Checked both sources afterwards:
--     +3.6M band: 163 of them exist in cata_world, and exactly **1** has a
--                 lootid there. Total importable source loot rows: 15.
--     +3.7M band:  35 exist in nelt_world, and **0** have a lootid.
-- So the sources agree: in Cataclysm and in vanilla these creatures drop
-- nothing, because they are quest-objective, event and encounter-add mobs where
-- loot was never the point. Nothing was dropped on import.
--
-- What makes it a problem is DC-specific: map 750 was repurposed as an 80-130
-- levelling continent, so these are now ordinary world mobs standing in
-- levelling zones. Flamewaker Centurion has **153 spawns** on Molten Front,
-- Lava Rager 44 in Ashenvale, Druid of the Talon 31 in Hyjal, Ironbark Ancient
-- 21, Furious Hyjal Warden and Hyjal Ritualist 18 each -- 2,859 spawns in total
-- that a player can kill all day for literally nothing (65 of the 193 do not
-- even drop copper). Also verified there is no broken link hiding here: **0**
-- of them have an orphaned `creature_loot_template` sitting at Entry = entry.
--
-- So section 2 is AUTHORED CONTENT, not a restore. It is a deliberate decision
-- to make DC's world more generous than Cataclysm's. Reverting it is one DELETE
-- plus one UPDATE (both given at the bottom) if you disagree.
--
-- ORDER MATTERS: section 1 must run before section 2. Section 2 derives each
-- creature's reward tier from `dc_map750_entryzone`, and section 1 is what puts
-- the six stragglers into that table.
--
-- Apply against acore_world, then restart worldserver. Idempotent.

-- ---------------------------------------------------------------------------
-- 1) Six mobs on a levelling continent still at vanilla levels
-- ---------------------------------------------------------------------------
-- Found while scoping section 2. 233_ re-levels by joining
-- `dc_map750_entryzone`, so an entry with no row there is silently skipped --
-- no error, no log line. Exactly **6** spawned real mobs on map 750 have no
-- row (21 unzoned entries total; the other 15 are critters, triggers and
-- friendly NPCs that correctly keep their own levels):
--
--   3632856  Warsong Invader      22-23   10 spawns
--   3633374  Brutusk              25      1
--   3634492  Astranaar Thrower    22      4
--   3634494  Astranaar Sentinel   40      23
--   3634603  Ashenvale Assassin   26      17   <- the green-texture NPC from r29
--   3636822  Lord Kassarus        18      1    rank 1
--
-- A level-95 player walking into Astranaar meets level-22 Sentinels.
--
-- ZONE ATTRIBUTION was measured, not read off the names: for each one, the
-- modal `dc_map750_entryzone` zone of every spawned creature within 250 yd of
-- its own spawn centroid. Five resolve to 4931 Ashenvale (36-200 neighbours
-- each) and Lord Kassarus to 4930 Azshara (110 neighbours) -- which does match
-- the names, but the names are not the evidence.
--
-- The rest of the re-level is healthy, which is why this is 6 rows and not a
-- project: across all six banded zones only **1** real hostile mob sits below
-- its band, and the 221 raw "below band" entries are critters, triggers and
-- friendly NPCs.
--
-- 1a. Freeze their ORIGINAL levels first. These entries were never touched by
--     233_, so their current levels ARE the source values -- but INSERT IGNORE
--     means that if this file is ever re-run after 1c, the snapshot is not
--     re-frozen from already-scaled numbers. That ordering is the whole reason
--     `dc_map750_snap` exists.
INSERT IGNORE INTO acore_world.`dc_map750_snap` (`entry`,`minlevel0`,`maxlevel0`,`mingold0`,`maxgold0`)
SELECT `entry`, `minlevel`, `maxlevel`, `mingold`, `maxgold` FROM acore_world.`creature_template`
 WHERE `entry` IN (3632856,3633374,3634492,3634494,3634603,3636822);

-- 1b. Give them the zone rows 231_ never produced. `share`/`spawns` are
--     documentation only -- 233_ reads `zone` alone -- so share is 1.000 (all
--     spawns of each entry are in the one zone) and `spawns` is the live count.
INSERT INTO acore_world.`dc_map750_entryzone` (`entry`,`zone`,`share`,`spawns`) VALUES
(3632856,4931,1.000,10),
(3633374,4931,1.000,1),
(3634492,4931,1.000,4),
(3634494,4931,1.000,23),
(3634603,4931,1.000,17),
(3636822,4930,1.000,1)
ON DUPLICATE KEY UPDATE `zone` = VALUES(`zone`);

-- 1c. Same formula as 233_ sections C and D, scoped to these six. Restated
--     rather than re-running 233_ wholesale: 233_ would sweep all 1,641 entries
--     again, and while it is idempotent through the snapshot there is no reason
--     to re-touch 1,635 rows that are already correct.
--     Guarded on the pre-image so re-applying is a no-op.
--
--     rank 0 -- straight band remap
UPDATE acore_world.`creature_template` ct
JOIN acore_world.`dc_map750_snap` s ON s.`entry` = ct.`entry`
JOIN acore_world.`dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN acore_world.`dc_map750_band` b ON b.`zone` = ez.`zone`
SET ct.`minlevel` = LEAST(130, b.`t_lo` + ROUND(
      (LEAST(GREATEST(s.`minlevel0`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
      * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`))),
    ct.`maxlevel` = LEAST(130, b.`t_lo` + ROUND(
      (LEAST(GREATEST(s.`maxlevel0`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
      * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`)))
WHERE ct.`entry` IN (3632856,3633374,3634492,3634494,3634603)
  AND ct.`rank` = 0
  AND ct.`maxlevel` < b.`t_lo`;

--     rank 1 (elite) -- band remap + 1, capped at t_hi + 1
UPDATE acore_world.`creature_template` ct
JOIN acore_world.`dc_map750_snap` s ON s.`entry` = ct.`entry`
JOIN acore_world.`dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
JOIN acore_world.`dc_map750_band` b ON b.`zone` = ez.`zone`
SET ct.`minlevel` = LEAST(130, LEAST(b.`t_hi` + 1, 1 + b.`t_lo` + ROUND(
      (LEAST(GREATEST(s.`minlevel0`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
      * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`)))),
    ct.`maxlevel` = LEAST(130, LEAST(b.`t_hi` + 1, 1 + b.`t_lo` + ROUND(
      (LEAST(GREATEST(s.`maxlevel0`, b.`s_lo`), b.`s_hi`) - b.`s_lo`)
      * (b.`t_hi` - b.`t_lo`) / (b.`s_hi` - b.`s_lo`))))
WHERE ct.`entry` = 3636822
  AND ct.`rank` = 1
  AND ct.`maxlevel` < b.`t_lo`;

-- Expected outcome (computed against the live rows before writing this):
--   3632856 Warsong Invader    22-23 -> 91-92
--   3633374 Brutusk            25    -> 94
--   3634492 Astranaar Thrower  22    -> 91
--   3634494 Astranaar Sentinel 40    -> 98   (source level is above s_hi 30, so
--                                             it clamps to the band top)
--   3634603 Ashenvale Assassin 26    -> 95
--   3636822 Lord Kassarus      18    -> 86   (rank 1: base 85, +1)

-- ---------------------------------------------------------------------------
-- 2) 193 mobs that drop nothing get their zone's gear-ladder chance
-- ---------------------------------------------------------------------------
-- WHAT THEY GET, AND WHY IT IS ONLY THIS. One row: the reference their own
-- zone's neighbours already use, at the chance those neighbours already use.
-- Nothing invented.
--
--   zone 4929 Darkshore  80-90  -> ref 750080   ilvl 300, ReqLvl 82
--   zone 4930 Azshara    80-90  -> ref 750081   ilvl 300, ReqLvl 82
--   zone 4931 Ashenvale  88-98  -> ref 750088   ilvl 332, ReqLvl 92
--   zone 4927 Felwood    96-106 -> ref 750096   ilvl 372, ReqLvl 102
--   zone 4926 Winterspr 104-115 -> ref 750104   ilvl 372, ReqLvl 102
--   zone 4923 Hyjal     113-128 -> ref 750113   ilvl 398, ReqLvl 115
--   map 861 Molten Front 128-130 -> ref 750113  (top tier; 861 has no zone row)
--
-- Chance 2 for rank 0, 6 for rank>0. That mapping was verified against the live
-- data rather than assumed: **every one** of the 42 existing ladder rows at
-- chance 6 belongs to a rank>0 creature (42/42).
--
-- 🔴 DELIBERATELY NOT ADDING THE VANILLA TRASH REFERENCE. The obvious way to
-- make these mobs feel less empty is reference 45009, which 74 of their
-- neighbours carry at 100%. Opened it first: it is Linen Cloth 22%, Wool Cloth
-- 24%, Ice Cold Milk, Lesser Healing Potion, Minor Mana Potion -- the
-- un-rescaled VANILLA trash layer, and it only exists in the 80-98 zones.
-- Bolting it onto level-129 Hyjal and Molten Front mobs would spread the exact
-- problem flagged below (classic ilvl-40 loot on 100+ mobs) into content that
-- does not have it yet. So the ladder ref only.
--
-- 2a. Freeze the target set into its own table. The set is derived from six
--     predicates; writing it down once means the INSERT and the revert act on
--     exactly the same rows, and it is what you read to see what was touched.
DROP TABLE IF EXISTS acore_world.`dc_map750_noloot_backfill`;
CREATE TABLE acore_world.`dc_map750_noloot_backfill` (
  `entry`  INT UNSIGNED NOT NULL,
  `zone`   INT NOT NULL,
  `refid`  INT NOT NULL,
  `chance` FLOAT NOT NULL,
  `rank`   TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO acore_world.`dc_map750_noloot_backfill` (`entry`,`zone`,`refid`,`chance`,`rank`)
SELECT t.`entry`,
       COALESCE(ez.`zone`, 861),
       CASE
         WHEN EXISTS (SELECT 1 FROM acore_world.`creature` c WHERE c.`id` = t.`entry` AND c.`map` = 861) THEN 750113
         WHEN ez.`zone` = 4929 THEN 750080
         WHEN ez.`zone` = 4930 THEN 750081
         WHEN ez.`zone` = 4931 THEN 750088
         WHEN ez.`zone` = 4927 THEN 750096
         WHEN ez.`zone` = 4926 THEN 750104
         ELSE 750113
       END,
       IF(t.`rank` > 0, 6, 2),
       t.`rank`
FROM acore_world.`creature_template` t
LEFT JOIN acore_world.`dc_map750_entryzone` ez ON ez.`entry` = t.`entry`
WHERE t.`entry` IN (SELECT DISTINCT `id` FROM acore_world.`creature` WHERE `map` IN (750,861))
  AND t.`lootid` = 0
  -- the screens: not a trigger, not a critter-level stub, not a friendly NPC,
  -- no vendor/questgiver/trainer flag, not immune-to-players
  AND t.`type` <> 10
  AND (t.`flags_extra` & 128) = 0
  AND t.`minlevel` > 1
  AND t.`npcflag` = 0
  AND (t.`unit_flags` & 768) = 0
  AND t.`faction` NOT IN (35,7,31,114,1080,2005)
  -- 4928 Moonglade is a sanctuary and has no band row; 233_ left it alone and
  -- so does this.
  AND COALESCE(ez.`zone`, 0) <> 4928;

-- 2b. Point each template at its own entry. `lootid == entry` is the invariant
--     232_ established for the 3.6M-3.8M band -- never reuse a <3.6M lootid for
--     map-750 purposes, it is shared with stock mobs.
UPDATE acore_world.`creature_template` ct
JOIN acore_world.`dc_map750_noloot_backfill` b ON b.`entry` = ct.`entry`
SET ct.`lootid` = ct.`entry`
WHERE ct.`lootid` = 0;

-- 2c. The loot rows. `Item` repeats the reference id, which is this table's
--     convention for a reference row (matches every existing 'DC750 ladder
--     drop' row). LootMode 1, not 0 -- see 281_, a 0 there means the row never
--     rolls.
--     The DELETE is a no-op on a first run (measured: 0 of the 193 have any row
--     at Entry = entry) and is what makes a re-run idempotent.
DELETE l FROM acore_world.`creature_loot_template` l
JOIN acore_world.`dc_map750_noloot_backfill` b ON b.`entry` = l.`Entry`;

INSERT INTO acore_world.`creature_loot_template`
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT b.`entry`, b.`refid`, b.`refid`, b.`chance`, 0, 1, 0, 1, 1, 'DC750 ladder drop (288 no-loot backfill)'
FROM acore_world.`dc_map750_noloot_backfill` b;

-- ---------------------------------------------------------------------------
-- Verify after apply
-- ---------------------------------------------------------------------------
--  1  SELECT entry, minlevel, maxlevel FROM creature_template
--      WHERE entry IN (3632856,3633374,3634492,3634494,3634603,3636822);
--       -> 91-92 / 94 / 91 / 98 / 95 / 86
--     SELECT COUNT(*) FROM creature c JOIN creature_template t ON t.entry=c.id
--      WHERE c.map=750 AND t.type NOT IN (8,10) AND (t.flags_extra&128)=0
--        AND t.npcflag=0 AND (t.unit_flags&768)=0
--        AND t.faction NOT IN (35,7,31,114,1080,2005)
--        AND NOT EXISTS (SELECT 1 FROM dc_map750_entryzone ez WHERE ez.entry=t.entry);
--       -> 0   (no real mob on 750 is unzoned any more)
--
--  2  SELECT COUNT(*) FROM dc_map750_noloot_backfill;                    -> 193
--     SELECT refid, COUNT(*) FROM dc_map750_noloot_backfill GROUP BY refid;
--       -> 750080:17  750081:39  750088:44  750096:4  750104:2  750113:87
--          (the base set is 187; section 1's six add 5 to 750088 (Ashenvale)
--           and 1 to 750081 (Azshara), which is what makes it 193)
--     SELECT COUNT(*) FROM dc_map750_noloot_backfill WHERE refid NOT IN
--       (750080,750081,750088,750096,750104,750113);                     -> 0
--     SELECT COUNT(*) FROM creature_loot_template
--      WHERE Comment='DC750 ladder drop (288 no-loot backfill)';         -> 193
--     SELECT COUNT(*) FROM creature_template t
--      JOIN dc_map750_noloot_backfill b ON b.entry=t.entry
--      WHERE t.lootid <> t.entry;                                        -> 0
--     -- and the loot loader must stay clean: no new "isn't creature entry and
--     -- not referenced from loot" lines, because every new Entry now has a
--     -- creature_template pointing at it.
--
-- REVERT
--   DELETE l FROM creature_loot_template l
--     JOIN dc_map750_noloot_backfill b ON b.entry = l.Entry;
--   UPDATE creature_template ct JOIN dc_map750_noloot_backfill b ON b.entry=ct.entry
--     SET ct.lootid = 0 WHERE ct.lootid = ct.entry;
--   -- section 1 reverts from the snapshot:
--   UPDATE creature_template ct JOIN dc_map750_snap s ON s.entry=ct.entry
--     SET ct.minlevel=s.minlevel0, ct.maxlevel=s.maxlevel0
--     WHERE ct.entry IN (3632856,3633374,3634492,3634494,3634603,3636822);
--   DELETE FROM dc_map750_entryzone WHERE entry IN
--     (3632856,3633374,3634492,3634494,3634603,3636822);
--
-- `dc_map750_noloot_backfill` is the revert key, so keep it until you are happy
-- with the result -- then `DROP TABLE dc_map750_noloot_backfill;` is safe, the
-- core never reads it. (`dc_map750_snap`, `_band`, `_entryzone` and
-- `_chunkzone` must STAY -- 233_ and this file both re-derive from them.)
--
-- ---------------------------------------------------------------------------
-- The bigger loot question this round does NOT answer
-- ---------------------------------------------------------------------------
-- Asked directly: "did we scale up all the lootable items on those maps to the
-- area levels?" The honest answer is **the ladder was added, the original loot
-- was never rebalanced**, and this file does not change that.
--
-- Measured on direct (`Reference = 0`) weapon/armour rows for creatures spawned
-- on 750/861:
--     creature level 91-110 : 1,038 rows, average item ilvl **42.7**,
--                             average ReqLvl 37.6, and **zero** above ilvl 80.
-- So a level-100 Felwood mob drops vanilla greens most of the time and a
-- band-appropriate ladder piece at 2%. That is a map-wide tuning question
-- affecting all 594 lootable creatures equally, not something to bolt onto a
-- 193-row backfill.
--
-- Two more findings from the same measurement, both left alone deliberately:
--   * **750104 (Winterspring 104-115) is the same tier as 750096** -- both ilvl
--     372 / ReqLvl 102. That is 238_'s four-tier ladder (82/92/102/115) stretched
--     over six zones, so Winterspring offers no gear step up over Felwood.
--     Closing it means a fifth 15-item tier, new item ids and an Item.dbc
--     deploy -- a project, not a section.
--   * **65 of these 193 drop no gold at all**, and the peer data is too
--     inconsistent to copy from: rank-4 bosses in four zones sit at 18-156
--     copper while rank-0 mobs beside them drop 5,000-17,000. Gold wants to be
--     derived from LEVEL, map-wide, in a pass that also fixes those rank-4
--     rows -- deriving it from these peers would just spread the anomaly.
--
-- Map 861 needs no ladder for its 20 already-lootable creatures and correctly
-- has none: they carry native Cata Firelands tables, 3,841 direct gear rows
-- averaging ilvl 272 (150-359) at levels 128-130. Only its 29 LOOT-LESS mobs
-- are touched here.
