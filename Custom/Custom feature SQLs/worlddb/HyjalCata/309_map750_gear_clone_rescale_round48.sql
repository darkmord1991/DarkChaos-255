-- ---------------------------------------------------------------------------
-- 309  Round 48 -- clone + rescale map 750's gear to its own level bands
-- ---------------------------------------------------------------------------
-- THE PROBLEM. Map 750 was re-levelled to 80-130 (233_) but its GEAR never was.
-- Mobs carry no direct gear rows at all -- everything comes through references,
-- and those references are stock/classic tables shared with maps 0 and 1:
--     24036 avg ilvl 45.5   24048 avg 30.5   24064 avg 24.4 ...
-- So a level-100 Felwood mob rolls vanilla greens, with the 750xxx ladder as a
-- 2-6% good drop. The quest side is worse and had never been looked at: 605
-- quests across the six zones hand out 434 gear rewards and **not one** is
-- band-appropriate --
--     Darkshore (80-90) avg ilvl 2.2   Azshara 0.6   Ashenvale (88-98) 11.8
--     Felwood (96-106) 19.3            Winterspring (104-115) 18.4
--     Hyjal (113-128) 32.9
-- Quest MinLevel *was* re-levelled (Hyjal quests gate at ~108), so a level-115
-- player is sent on a correctly-gated quest for an ilvl-18 reward.
--
-- 🔴 THE CLASSIC REFERENCES ARE SHARED SERVER-WIDE AND ARE NEVER EDITED HERE.
-- 24036 and friends feed hundreds of vanilla mobs on maps 0/1. This file CLONES
-- them (new ref ids 751000+) with rescaled item clones inside, then re-points
-- only map-750 loot at the clones. The originals are untouched.
--
-- WHAT IS CLONED, AND WHAT IS NOT
--   cloned : Quality 2/3/4 (green/blue/purple) gear -- 2,131 loot items and 413
--            quest-reward items, no overlap between the two sets
--   NOT    : Quality 0/1 (grey/white) gear -- 357 items. Those are vendor trash
--            everywhere in the game and their value is the copper, not the
--            stats. Rescaling a grey "Worn Shortsword" to ilvl 355 is noise.
--   NOT    : non-gear rows in the cloned references (cloth, recipes, junk) --
--            copied as-is, still pointing at the original items.
--
-- SCALING MODEL, calibrated against DC's OWN ladder rather than invented.
-- Measured the 750080-750113 sets: total stat points vs ItemLevel gives
--     300 -> 393, 372 -> 623, 385 -> 666   (wrist)
--     332 -> 493, 398 -> 710               (feet)
-- Fitting those: **stat budget is proportional to ilvl^2.13**, consistent to
-- ~1% across all five tiers. That exponent is the Cataclysm curve, and using
-- DC's own gear as the calibration set means the clones land on the same power
-- line as the ladder instead of a curve invented here.
--
-- 🔴 The source items are NOT on that curve -- they are classic-era gear on the
-- vanilla curve -- so scaling by a ratio of the SAME curve would be wrong by
-- orders of magnitude ((355/40)^2.13 = 104x). Instead each clone is given the
-- TARGET budget for its ilvl/slot/quality outright, and that budget is
-- distributed across the stats the source item actually had, in the source's
-- own proportions. A Strength/Stamina green stays a Strength/Stamina green.
--
--   total_target = 0.00207 * ilvl^2.13 * slot_weight * quality_multiplier
--   stat_factor  = total_target / total_source     (per item, frozen in the map)
--   stat_valueN  = ROUND(stat_valueN_source * stat_factor)
--
--   slot_weight  1.15 head/chest/legs, 0.75 wrist/hands/waist/feet/neck/finger/
--                trinket/cloak/shield/off-hand/ranged, 1.00 everything else
--   quality_mul  0.85 green, 1.00 blue, 1.15 purple -- greens sit UNDER the
--                rare ladder piece on purpose: the ladder stays the good drop
--
-- TARGET ITEM LEVEL per band, again anchored on the ladder (285/315/355/372/385
-- vs the ladder's 300/332/372/385/398), with a +/-10 spread carried over from
-- the source item's own ilvl so a zone's drops are not all identical, plus
-- +8 blue / +16 purple.
--
-- ARMOR AND WEAPON DAMAGE ARE DELIBERATELY ZEROED on the clones. They are
-- derived values in Cata (ItemArmorTotal x ItemArmorQuality x ArmorLocation;
-- ItemDamage<Type> x delay), and this project already has the tool that
-- computes them: `Custom/Documentation/scripts/gen_zone_gear_armor_dmg.py`,
-- whose input filter is exactly `armor = 0 AND dmg_min1 = 0`. Zeroing here is
-- what makes the clones visible to it. THE ITEMS ARE NOT FINISHED UNTIL THAT
-- TOOL HAS RUN -- see the three-phase order at the bottom.
--
-- RandomProperty / RandomSuffix / ScalingStat* are zeroed too: random suffixes
-- scale off RandPropPoints.dbc, which stops at ilvl 300 on this realm (checked:
-- 300 records, 350/398/400 absent), so above that they would silently roll
-- nothing or garbage.
--
-- 🔴 APPLY 312_ AFTER THIS FILE. Post-apply verification of the live data found
-- two defects in the stat maths. The negative-stat one is corrected here at
-- source (see the total_src comment below). The second -- a single-stat item
-- swallowing its slot's whole budget, giving a green 761 Stamina where the
-- ladder's best piece has 231 -- is capped by 312_, which recomputes the budget
-- from each clone's own ItemLevel and is idempotent. The cap lives in exactly
-- one file on purpose, so the two cannot drift.
--
-- Apply against acore_world. Idempotent -- re-running allocates no new ids and
-- rewrites nothing that is already correct.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) The clone map -- allocated ONCE, then frozen
-- ---------------------------------------------------------------------------
-- This table IS the pin. Everything downstream joins it rather than recomputing
-- the source set, so the DELETE/INSERT pairs below can never drift apart the
-- way they would if each statement re-derived its own predicate.
--
-- Ids are appended after the current maximum instead of being ROW_NUMBERed from
-- a fixed base: if a later import adds an item in the middle of the range, a
-- fixed base would renumber everything after it and collide with clones that
-- already exist (INSERT IGNORE would then silently skip them). Appending cannot.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_map750_item_clone` (
  `src_entry`   INT UNSIGNED NOT NULL PRIMARY KEY,
  `clone_entry` INT UNSIGNED NOT NULL UNIQUE,
  `src_kind`    VARCHAR(5)   NOT NULL,
  `band_lo`     SMALLINT     NOT NULL,
  `tgt_ilvl`    SMALLINT     NOT NULL,
  `tgt_reqlvl`  SMALLINT     NOT NULL,
  `stat_factor` DECIMAL(12,6) NOT NULL DEFAULT 1.000000
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET @loot_base := (SELECT COALESCE(MAX(`clone_entry`), 499999) FROM `dc_map750_item_clone` WHERE `src_kind` = 'loot');

-- A1) loot items: Quality 2-4 gear reachable from a map-750 mob's references
INSERT IGNORE INTO `dc_map750_item_clone`
    (`src_entry`,`clone_entry`,`src_kind`,`band_lo`,`tgt_ilvl`,`tgt_reqlvl`,`stat_factor`)
SELECT z.`e`,
       @loot_base + ROW_NUMBER() OVER (ORDER BY z.`e`),
       'loot', z.`t_lo`, z.`tgt_ilvl`, z.`t_lo`,
       CASE WHEN z.`total_src` > 0
            THEN ROUND(0.00207 * POW(z.`tgt_ilvl`, 2.13) * z.`slotw` * z.`qmul` / z.`total_src`, 6)
            ELSE 1.000000 END
FROM (
  SELECT i.`entry` AS e, m.`t_lo`,
         LEAST(400, GREATEST(240,
           CASE m.`t_lo` WHEN 80 THEN 285 WHEN 88 THEN 315 WHEN 96 THEN 355
                         WHEN 104 THEN 372 WHEN 113 THEN 385 ELSE 285 END
           + ROUND((LEAST(GREATEST(i.`ItemLevel`, 5), 70) - 5) * 20 / 65) - 10
           + CASE i.`Quality` WHEN 3 THEN 8 WHEN 4 THEN 16 ELSE 0 END)) AS tgt_ilvl,
         CASE WHEN i.`InventoryType` IN (1, 5, 7, 20) THEN 1.15
              WHEN i.`InventoryType` IN (2, 8, 9, 10, 6, 11, 12, 14, 15, 16, 23, 26) THEN 0.75
              ELSE 1.00 END AS slotw,
         CASE i.`Quality` WHEN 3 THEN 1.00 WHEN 4 THEN 1.15 ELSE 0.85 END AS qmul,
         -- POSITIVE values only. Some classic items carry a stat PENALTY, and a
         -- plain SUM collapses the denominator: Lapidis Tankard of Tidesippe is
         -- Agility -15 / Spirit +16, total 1, which turned the factor into 84.
         (GREATEST(COALESCE(i.`stat_value1`,0),0)+GREATEST(COALESCE(i.`stat_value2`,0),0)
         +GREATEST(COALESCE(i.`stat_value3`,0),0)+GREATEST(COALESCE(i.`stat_value4`,0),0)
         +GREATEST(COALESCE(i.`stat_value5`,0),0)+GREATEST(COALESCE(i.`stat_value6`,0),0)
         +GREATEST(COALESCE(i.`stat_value7`,0),0)+GREATEST(COALESCE(i.`stat_value8`,0),0)
         +GREATEST(COALESCE(i.`stat_value9`,0),0)+GREATEST(COALESCE(i.`stat_value10`,0),0)) AS total_src
  FROM (
    SELECT r.`Item` AS item, b.`t_lo`,
           ROW_NUMBER() OVER (PARTITION BY r.`Item`
                              ORDER BY COUNT(DISTINCT ct.`entry`) DESC, b.`t_lo` ASC) AS rn
    FROM `creature_loot_template` l
    JOIN `creature_template` ct ON ct.`lootid` = l.`Entry`
    JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
    JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
    JOIN `reference_loot_template` r ON r.`Entry` = l.`Reference`
    WHERE l.`Reference` > 0
      AND l.`Reference` NOT IN (750080, 750081, 750088, 750096, 750104, 750113)
    GROUP BY r.`Item`, b.`t_lo`
  ) m
  JOIN `item_template` i ON i.`entry` = m.`item`
  WHERE m.`rn` = 1
    AND i.`class` IN (2, 4) AND i.`ItemLevel` < 200 AND i.`Quality` BETWEEN 2 AND 4
    AND NOT EXISTS (SELECT 1 FROM `dc_map750_item_clone` c WHERE c.`src_entry` = i.`entry`)
) z;

-- An item used in two zones is cloned ONCE, into the band where the most mobs
-- carry it (ties -> the lower band). Per-band duplicates would multiply this to
-- 6,049 items for no gain a player could notice.

SET @quest_base := (SELECT COALESCE(MAX(`clone_entry`), 502999) FROM `dc_map750_item_clone` WHERE `src_kind` = 'quest');

-- A2) quest reward items -- same model, band from the questgiver's zone
INSERT IGNORE INTO `dc_map750_item_clone`
    (`src_entry`,`clone_entry`,`src_kind`,`band_lo`,`tgt_ilvl`,`tgt_reqlvl`,`stat_factor`)
SELECT z.`e`,
       @quest_base + ROW_NUMBER() OVER (ORDER BY z.`e`),
       'quest', z.`t_lo`, z.`tgt_ilvl`, z.`t_lo`,
       CASE WHEN z.`total_src` > 0
            THEN ROUND(0.00207 * POW(z.`tgt_ilvl`, 2.13) * z.`slotw` * z.`qmul` / z.`total_src`, 6)
            ELSE 1.000000 END
FROM (
  SELECT i.`entry` AS e, m.`t_lo`,
         LEAST(400, GREATEST(240,
           CASE m.`t_lo` WHEN 80 THEN 285 WHEN 88 THEN 315 WHEN 96 THEN 355
                         WHEN 104 THEN 372 WHEN 113 THEN 385 ELSE 285 END
           + ROUND((LEAST(GREATEST(i.`ItemLevel`, 5), 70) - 5) * 20 / 65) - 10
           + CASE i.`Quality` WHEN 3 THEN 8 WHEN 4 THEN 16 ELSE 0 END)) AS tgt_ilvl,
         CASE WHEN i.`InventoryType` IN (1, 5, 7, 20) THEN 1.15
              WHEN i.`InventoryType` IN (2, 8, 9, 10, 6, 11, 12, 14, 15, 16, 23, 26) THEN 0.75
              ELSE 1.00 END AS slotw,
         CASE i.`Quality` WHEN 3 THEN 1.00 WHEN 4 THEN 1.15 ELSE 0.85 END AS qmul,
         -- POSITIVE values only. Some classic items carry a stat PENALTY, and a
         -- plain SUM collapses the denominator: Lapidis Tankard of Tidesippe is
         -- Agility -15 / Spirit +16, total 1, which turned the factor into 84.
         (GREATEST(COALESCE(i.`stat_value1`,0),0)+GREATEST(COALESCE(i.`stat_value2`,0),0)
         +GREATEST(COALESCE(i.`stat_value3`,0),0)+GREATEST(COALESCE(i.`stat_value4`,0),0)
         +GREATEST(COALESCE(i.`stat_value5`,0),0)+GREATEST(COALESCE(i.`stat_value6`,0),0)
         +GREATEST(COALESCE(i.`stat_value7`,0),0)+GREATEST(COALESCE(i.`stat_value8`,0),0)
         +GREATEST(COALESCE(i.`stat_value9`,0),0)+GREATEST(COALESCE(i.`stat_value10`,0),0)) AS total_src
  FROM (
    SELECT ri.`item`, MIN(b.`t_lo`) AS t_lo,
           ROW_NUMBER() OVER (PARTITION BY ri.`item` ORDER BY MIN(b.`t_lo`)) AS rn
    FROM (
      SELECT q.`ID` AS quest, qi.`item`
      FROM `quest_template` q
      JOIN (
        SELECT `ID`, `RewardItem1` AS item FROM `quest_template` WHERE `RewardItem1` > 0
        UNION ALL SELECT `ID`, `RewardItem2` FROM `quest_template` WHERE `RewardItem2` > 0
        UNION ALL SELECT `ID`, `RewardItem3` FROM `quest_template` WHERE `RewardItem3` > 0
        UNION ALL SELECT `ID`, `RewardItem4` FROM `quest_template` WHERE `RewardItem4` > 0
        UNION ALL SELECT `ID`, `RewardChoiceItemID1` FROM `quest_template` WHERE `RewardChoiceItemID1` > 0
        UNION ALL SELECT `ID`, `RewardChoiceItemID2` FROM `quest_template` WHERE `RewardChoiceItemID2` > 0
        UNION ALL SELECT `ID`, `RewardChoiceItemID3` FROM `quest_template` WHERE `RewardChoiceItemID3` > 0
        UNION ALL SELECT `ID`, `RewardChoiceItemID4` FROM `quest_template` WHERE `RewardChoiceItemID4` > 0
        UNION ALL SELECT `ID`, `RewardChoiceItemID5` FROM `quest_template` WHERE `RewardChoiceItemID5` > 0
        UNION ALL SELECT `ID`, `RewardChoiceItemID6` FROM `quest_template` WHERE `RewardChoiceItemID6` > 0
      ) qi ON qi.`ID` = q.`ID`
    ) ri
    JOIN `creature_queststarter` qs ON qs.`quest` = ri.`quest`
    JOIN `dc_map750_entryzone` ez ON ez.`entry` = qs.`id`
    JOIN `dc_map750_band` b ON b.`zone` = ez.`zone`
    GROUP BY ri.`item`
  ) m
  JOIN `item_template` i ON i.`entry` = m.`item`
  WHERE m.`rn` = 1
    AND i.`class` IN (2, 4) AND i.`ItemLevel` < 200 AND i.`Quality` BETWEEN 2 AND 4
    AND NOT EXISTS (SELECT 1 FROM `dc_map750_item_clone` c WHERE c.`src_entry` = i.`entry`)
) z;

-- ---------------------------------------------------------------------------
-- B) The item clones themselves
-- ---------------------------------------------------------------------------
-- Built in a staging table created with `LIKE item_template` so the copy is
-- `SELECT *`. That is deliberate: enumerating 138 columns by hand would break
-- silently the next time this fork's item_template gains one, and this table
-- has already drifted from stock (see creature-template-schema-drift).
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_item_clone_stage`;
CREATE TABLE `dc_item_clone_stage` LIKE `item_template`;

INSERT INTO `dc_item_clone_stage`
SELECT it.* FROM `item_template` it
JOIN `dc_map750_item_clone` m ON m.`src_entry` = it.`entry`
WHERE NOT EXISTS (SELECT 1 FROM `item_template` x WHERE x.`entry` = m.`clone_entry`);

-- Rescale while the rows still carry their SOURCE entry, so the join is simple.
-- Each stat assignment reads only its own column: MySQL applies SET clauses
-- left to right, so an expression that summed the stat_values here would read
-- already-updated ones. That is why the factor is precomputed in the map.
UPDATE `dc_item_clone_stage` s
JOIN `dc_map750_item_clone` m ON m.`src_entry` = s.`entry`
SET s.`ItemLevel`     = m.`tgt_ilvl`,
    s.`RequiredLevel` = m.`tgt_reqlvl`,
    s.`stat_value1`  = ROUND(s.`stat_value1`  * m.`stat_factor`),
    s.`stat_value2`  = ROUND(s.`stat_value2`  * m.`stat_factor`),
    s.`stat_value3`  = ROUND(s.`stat_value3`  * m.`stat_factor`),
    s.`stat_value4`  = ROUND(s.`stat_value4`  * m.`stat_factor`),
    s.`stat_value5`  = ROUND(s.`stat_value5`  * m.`stat_factor`),
    s.`stat_value6`  = ROUND(s.`stat_value6`  * m.`stat_factor`),
    s.`stat_value7`  = ROUND(s.`stat_value7`  * m.`stat_factor`),
    s.`stat_value8`  = ROUND(s.`stat_value8`  * m.`stat_factor`),
    s.`stat_value9`  = ROUND(s.`stat_value9`  * m.`stat_factor`),
    s.`stat_value10` = ROUND(s.`stat_value10` * m.`stat_factor`),
    s.`armor`    = 0,
    s.`dmg_min1` = 0, s.`dmg_max1` = 0,
    s.`dmg_min2` = 0, s.`dmg_max2` = 0, s.`dmg_type2` = 0,
    s.`RandomProperty` = 0, s.`RandomSuffix` = 0,
    s.`ScalingStatDistribution` = 0, s.`ScalingStatValue` = 0,
    s.`BuyPrice`  = LEAST(4294967295, ROUND(s.`BuyPrice`  * 12)),
    s.`SellPrice` = LEAST(4294967295, ROUND(s.`SellPrice` * 12));

-- entry last: everything above joins on the source entry.
UPDATE `dc_item_clone_stage` s
JOIN `dc_map750_item_clone` m ON m.`src_entry` = s.`entry`
SET s.`entry` = m.`clone_entry`;

INSERT INTO `item_template` SELECT * FROM `dc_item_clone_stage`;

DROP TABLE IF EXISTS `dc_item_clone_stage`;

-- ---------------------------------------------------------------------------
-- C) Cloned reference tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_map750_ref_clone` (
  `src_ref`   INT UNSIGNED NOT NULL PRIMARY KEY,
  `clone_ref` INT UNSIGNED NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET @ref_base := (SELECT COALESCE(MAX(`clone_ref`), 750999) FROM `dc_map750_ref_clone`);

INSERT IGNORE INTO `dc_map750_ref_clone` (`src_ref`, `clone_ref`)
SELECT z.`ref`, @ref_base + ROW_NUMBER() OVER (ORDER BY z.`ref`)
FROM (
  SELECT DISTINCT l.`Reference` AS ref
  FROM `creature_loot_template` l
  JOIN `creature_template` ct ON ct.`lootid` = l.`Entry`
  JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
  WHERE l.`Reference` > 0
    AND l.`Reference` NOT IN (750080, 750081, 750088, 750096, 750104, 750113)
    -- 🔴 NEVER clone a clone. Section D re-points these same loot rows AT the
    -- 751xxx clones, so on a second apply this SELECT would see 751xxx as fresh
    -- "sources" and build a second generation -- and because the DELETE below
    -- wipes gen1's rows before this INSERT can read them, that generation comes
    -- out EMPTY and every map-750 mob drops nothing. That is exactly what
    -- happened on 2026-08-30; 313_ repaired it.
    AND l.`Reference` NOT BETWEEN 751000 AND 751999
    AND NOT EXISTS (SELECT 1 FROM `dc_map750_ref_clone` rc WHERE rc.`src_ref` = l.`Reference`)
) z;

DELETE r FROM `reference_loot_template` r
JOIN `dc_map750_ref_clone` rc ON rc.`clone_ref` = r.`Entry`;

INSERT INTO `reference_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT rc.`clone_ref`,
       COALESCE(mi.`clone_entry`, r.`Item`),
       COALESCE(rn.`clone_ref`, r.`Reference`),
       r.`Chance`, r.`QuestRequired`, r.`LootMode`, r.`GroupId`, r.`MinCount`, r.`MaxCount`,
       CONCAT('DC750 band clone of ref ', r.`Entry`)
FROM `reference_loot_template` r
JOIN `dc_map750_ref_clone` rc ON rc.`src_ref` = r.`Entry`
LEFT JOIN `dc_map750_item_clone` mi ON mi.`src_entry` = r.`Item` AND mi.`src_kind` = 'loot'
LEFT JOIN `dc_map750_ref_clone` rn ON rn.`src_ref` = r.`Reference` AND r.`Reference` > 0;

-- Rows whose item was not cloned (grey/white gear, cloth, recipes, junk) keep
-- pointing at the original item -- that is intended, they are trash and reagents.
-- A nested Reference is re-pointed at ITS clone when one exists, so a chain like
-- 24029 -> 24036 stays inside the rescaled set instead of leaking back to stock.

-- ---------------------------------------------------------------------------
-- D) Re-point map-750 creature loot at the cloned references
-- ---------------------------------------------------------------------------
-- 🔴 SCOPED BY "EVERY OWNER OF THIS lootid IS A MAP-750 MOB". A lootid shared
-- with a mob outside the zone table would otherwise have its loot silently
-- rescaled for the rest of the server -- the same blast-radius mistake the
-- shared 24xxx references would have been.
--
-- Done as DELETE + INSERT rather than UPDATE because `Reference` is part of the
-- primary key (Entry, Item, Reference, GroupId).
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `dc_repoint`;
CREATE TEMPORARY TABLE `dc_repoint` (
  `Entry` INT UNSIGNED NOT NULL, `Item` INT UNSIGNED NOT NULL,
  `Reference` INT NOT NULL, `Chance` FLOAT NOT NULL, `QuestRequired` TINYINT NOT NULL,
  `LootMode` SMALLINT UNSIGNED NOT NULL, `GroupId` TINYINT UNSIGNED NOT NULL,
  `MinCount` TINYINT UNSIGNED NOT NULL, `MaxCount` TINYINT UNSIGNED NOT NULL,
  `clone_ref` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`Entry`,`Item`,`Reference`,`GroupId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_repoint`
SELECT DISTINCT l.`Entry`, l.`Item`, l.`Reference`, l.`Chance`, l.`QuestRequired`,
       l.`LootMode`, l.`GroupId`, l.`MinCount`, l.`MaxCount`, rc.`clone_ref`
FROM `creature_loot_template` l
JOIN `dc_map750_ref_clone` rc ON rc.`src_ref` = l.`Reference`
WHERE l.`Reference` NOT BETWEEN 751000 AND 751999   -- already re-pointed; see C
  AND EXISTS (
        SELECT 1 FROM `creature_template` ct
        JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
        WHERE ct.`lootid` = l.`Entry`)
  AND NOT EXISTS (
        SELECT 1 FROM `creature_template` ct2
        WHERE ct2.`lootid` = l.`Entry`
          AND NOT EXISTS (SELECT 1 FROM `dc_map750_entryzone` ez2 WHERE ez2.`entry` = ct2.`entry`));

DELETE l FROM `creature_loot_template` l
JOIN `dc_repoint` d
  ON d.`Entry` = l.`Entry` AND d.`Item` = l.`Item`
 AND d.`Reference` = l.`Reference` AND d.`GroupId` = l.`GroupId`;

INSERT INTO `creature_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT d.`Entry`, d.`clone_ref`, d.`clone_ref`, d.`Chance`, d.`QuestRequired`,
       d.`LootMode`, d.`GroupId`, d.`MinCount`, d.`MaxCount`,
       CONCAT('DC750 rescaled (was ref ', d.`Reference`, ')')
FROM `dc_repoint` d;

DROP TEMPORARY TABLE IF EXISTS `dc_repoint`;

-- ---------------------------------------------------------------------------
-- E) Quest rewards -- re-point to the rescaled clone
-- ---------------------------------------------------------------------------
-- Scoped to quests started by a map-750 zone NPC. Names and icons are unchanged,
-- so "Emerald Sanctuary Cloak" is still that cloak -- it just carries its zone's
-- budget now.
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `dc_m750_quests`;
CREATE TEMPORARY TABLE `dc_m750_quests` (`ID` INT UNSIGNED NOT NULL PRIMARY KEY)
  ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_m750_quests` (`ID`)
SELECT DISTINCT qs.`quest`
FROM `creature_queststarter` qs
JOIN `dc_map750_entryzone` ez ON ez.`entry` = qs.`id`;

UPDATE `quest_template` q JOIN `dc_m750_quests` t ON t.`ID` = q.`ID`
JOIN `dc_map750_item_clone` m ON m.`src_entry` = q.`RewardItem1` AND m.`src_kind` = 'quest'
SET q.`RewardItem1` = m.`clone_entry`;
UPDATE `quest_template` q JOIN `dc_m750_quests` t ON t.`ID` = q.`ID`
JOIN `dc_map750_item_clone` m ON m.`src_entry` = q.`RewardItem2` AND m.`src_kind` = 'quest'
SET q.`RewardItem2` = m.`clone_entry`;
UPDATE `quest_template` q JOIN `dc_m750_quests` t ON t.`ID` = q.`ID`
JOIN `dc_map750_item_clone` m ON m.`src_entry` = q.`RewardItem3` AND m.`src_kind` = 'quest'
SET q.`RewardItem3` = m.`clone_entry`;
UPDATE `quest_template` q JOIN `dc_m750_quests` t ON t.`ID` = q.`ID`
JOIN `dc_map750_item_clone` m ON m.`src_entry` = q.`RewardItem4` AND m.`src_kind` = 'quest'
SET q.`RewardItem4` = m.`clone_entry`;
UPDATE `quest_template` q JOIN `dc_m750_quests` t ON t.`ID` = q.`ID`
JOIN `dc_map750_item_clone` m ON m.`src_entry` = q.`RewardChoiceItemID1` AND m.`src_kind` = 'quest'
SET q.`RewardChoiceItemID1` = m.`clone_entry`;
UPDATE `quest_template` q JOIN `dc_m750_quests` t ON t.`ID` = q.`ID`
JOIN `dc_map750_item_clone` m ON m.`src_entry` = q.`RewardChoiceItemID2` AND m.`src_kind` = 'quest'
SET q.`RewardChoiceItemID2` = m.`clone_entry`;
UPDATE `quest_template` q JOIN `dc_m750_quests` t ON t.`ID` = q.`ID`
JOIN `dc_map750_item_clone` m ON m.`src_entry` = q.`RewardChoiceItemID3` AND m.`src_kind` = 'quest'
SET q.`RewardChoiceItemID3` = m.`clone_entry`;
UPDATE `quest_template` q JOIN `dc_m750_quests` t ON t.`ID` = q.`ID`
JOIN `dc_map750_item_clone` m ON m.`src_entry` = q.`RewardChoiceItemID4` AND m.`src_kind` = 'quest'
SET q.`RewardChoiceItemID4` = m.`clone_entry`;
UPDATE `quest_template` q JOIN `dc_m750_quests` t ON t.`ID` = q.`ID`
JOIN `dc_map750_item_clone` m ON m.`src_entry` = q.`RewardChoiceItemID5` AND m.`src_kind` = 'quest'
SET q.`RewardChoiceItemID5` = m.`clone_entry`;
UPDATE `quest_template` q JOIN `dc_m750_quests` t ON t.`ID` = q.`ID`
JOIN `dc_map750_item_clone` m ON m.`src_entry` = q.`RewardChoiceItemID6` AND m.`src_kind` = 'quest'
SET q.`RewardChoiceItemID6` = m.`clone_entry`;

DROP TEMPORARY TABLE IF EXISTS `dc_m750_quests`;

-- ---------------------------------------------------------------------------
-- THIS FILE IS PHASE 1 OF 3 -- THE ITEMS ARE NOT USABLE YET
-- ---------------------------------------------------------------------------
-- 2) Item.dbc. **Every clone needs a row or ObjectMgr silently drops the whole
--    item_template row** -- no error, the item simply does not exist. Generate
--    and deploy it:
--        python "Custom/Custom feature SQLs/worlddb/HyjalCata/tools/gen_item_dbc_append_r48.py" \
--            --dsn <host>,<user>,<password> --csv "Custom/CSV DBC/Item.csv"
--    (--dsn is comma-separated, matching gen_zone_gear_armor_dmg.py)
--        python Custom/Documentation/scripts/dbc-compile.py --only Item
--    then deploy Item.dbc to patch-4 AND patch-enGB-3 (it is enGB-shadowed) AND
--    the server's own data/dbc -- the SERVER reads Item.dbc too.
--
-- 3) Armor and weapon damage, which this file deliberately left at 0:
--        python Custom/Documentation/scripts/gen_zone_gear_armor_dmg.py \
--            --dsn <host>,<user>,<password> \
--            --dbc-dir K:/tmp/cata-itemcurves --out 310_clone_armor_dmg.sql
--    (the Cata curve DBCs are already extracted at K:/tmp/cata-itemcurves)
--    then apply 310_. Until it runs, every clone is a cloth rag with no damage.
--
-- Restart the worldserver only after 2 and 3.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Verify
-- ---------------------------------------------------------------------------
--   SELECT src_kind, COUNT(*), MIN(clone_entry), MAX(clone_entry),
--          MIN(tgt_ilvl), MAX(tgt_ilvl) FROM dc_map750_item_clone GROUP BY src_kind;
--     -> loot 2131 (500000-502130), quest 413 (503000-503412)
--   SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 500000 AND 599999;  -- 2544
--   -- no map-750 mob left rolling an un-rescaled classic reference:
--   SELECT COUNT(*) FROM creature_loot_template l
--     JOIN creature_template ct ON ct.lootid = l.Entry
--     JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
--    WHERE l.Reference > 0 AND l.Reference < 750000;                            -- 0
--   -- and the originals are untouched:
--   SELECT COUNT(*) FROM reference_loot_template WHERE Entry = 24036;           -- 42
-- ---------------------------------------------------------------------------
