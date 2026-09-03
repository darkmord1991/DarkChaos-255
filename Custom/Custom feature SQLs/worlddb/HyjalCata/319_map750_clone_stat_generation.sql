-- ---------------------------------------------------------------------------
-- 319  Map 750/751/861 -- give the cloned gear real stats
-- ---------------------------------------------------------------------------
-- Reported 2026-09-02: a level 91 named rare drops an ilvl-289 green with no
-- usable stats. Verified on the live row -- item 501288 "Opulent Belt" carries
-- 616 armor, ItemLevel 289, and **every stat_value 0, every spellid 0**.
--
-- 🔴 THE DEFECT, and it is bigger than one item. 309_'s rescale gives each
-- clone a stat budget and distributes it "in the source's own proportions".
-- That silently produces NOTHING when the source has no proportions to copy:
--
--   * 1,272 sources are vanilla RANDOM-PROPERTY greens -- items whose entire
--     power is the suffix rolled at drop time, with zero base stats. 309_ also
--     zeroed `RandomProperty` on the clones (correctly: RandPropPoints.dbc
--     stops at ilvl 300 on this realm). Budget x nothing = nothing.
--   * a further 441 sources are quest/vendor shells that never had base stats.
--
-- Measured across the 2,536 equippable clones (class 2/4, InventoryType > 0):
--
--     0 stats                      1,713   <- armor/damage only, no stats at all
--     1 stat,  under budget          114   at 40% of budget (312_'s cap binding)
--     2 stats, under budget          518   at 73%
--     3 stats, under budget           60   at 76%
--     3-5 stats, on budget           131   at ~95-100%
--
-- So 68% of the continent's drops are stat-free and another 27% are 40-76% of
-- what their item level promises. This file fixes all of it.
--
-- ---------------------------------------------------------------------------
-- THE MODEL -- deliberately the SAME budget 309_/312_ already use
-- ---------------------------------------------------------------------------
--     budget = 0.00207 * ilvl^2.13 * slot_weight * quality_multiplier
--
-- unchanged, so this file cannot drift from the ladder those two calibrated
-- against. What changes is only WHERE the stats come from when the source had
-- none, and how they are spread.
--
-- Each item resolves to exactly FOUR stats, chosen in this order:
--   1. the stat types the item ALREADY has (existing character is preserved --
--      a Strength/Stamina green stays a Strength/Stamina green, exactly as
--      309_ intended);
--   2. topped up from an ARCHETYPE for its armour class and slot, skipping any
--      type already present.
-- An item with 0 stats therefore gets the pure archetype; one with 2 keeps
-- both and gains 2; one with 4 keeps all four and is only re-weighted. This is
-- what turns "add stats" and "rebalance stats" into one pass instead of two
-- passes that could disagree.
--
-- The budget is then spread 32 / 28 / 23 / 17 across those four. That shape is
-- taken from the ladder itself (Tidewatcher's plate wrist is 108/117/68/59,
-- cloth is 110/78/78/68) rather than invented, and the top stat at 32% sits
-- comfortably under 312_'s 40% single-stat cap, so the cap never binds and the
-- two files cannot fight.
--
-- Sanity check against the ladder, which stays the better drop by design:
--     green wrist  ilvl 289 -> budget 230 ->  74 / 64 / 53 / 39
--     green chest  ilvl 289 -> budget 353 -> 113 / 99 / 81 / 60
--     ladder blue wrist ilvl 300 (Tidewatcher's) = 110 / 78 / 78 / 68 = 334
--
-- ---------------------------------------------------------------------------
-- ARCHETYPES
-- ---------------------------------------------------------------------------
-- Keyed on armour class / weapon family, with a deterministic variant from the
-- entry id so a zone's drops are not all the same spec. The source item cannot
-- inform this -- it has no stats, that is the whole defect -- so the item's own
-- subclass and slot are the only honest signal available.
--
-- Every stat type used here is one the 400xxx ladder already uses (3, 4, 5, 6,
-- 7, 12, 13, 31, 32, 36, 37, 38, 45), so nothing new has to be proven safe on
-- the 3.3.5 client.
--
-- 🔴 NOT TOUCHED: `armor`, `dmg_min1`/`dmg_max1` and `delay`. Those are derived
-- values filled by 310_ from gen_zone_gear_armor_dmg.py and are already correct
-- on every row (verified live: 0 weapons with no damage, 0 armour pieces with
-- no armour). Re-deriving them here would fight that tool.
--
-- Scope: the 2,536 equippable clones pinned in `dc_map750_item_clone`
-- (class 2 weapons and class 4 armour with InventoryType > 0). Non-equippable
-- clones, and every original item, are untouched.
--
-- RELATION TO 312_. This file supersedes 312_'s value pass and is designed so
-- the two cannot fight in either order. After 319_ an item's stat sum IS its
-- budget, so 312_'s factor (budget / positive_sum) becomes exactly 1.0 and its
-- 40% cap never binds on a 32% top stat -- re-running 312_ afterwards is a
-- verified no-op rather than a second rescale. Run 319_ AFTER 309_/310_/312_.
--
-- Apply against acore_world. Idempotent -- the resolved stat list and the
-- budget both derive from columns this file does not write, except stat_typeN,
-- and a re-run re-picks the same types in the same order. Needs a worldserver
-- restart (or `.reload item_template`) and a client cache bump for items a
-- player has already seen -- see the note in the trailer.
-- ---------------------------------------------------------------------------

USE `acore_world`;

-- ---------------------------------------------------------------------------
-- 1. Archetype table -- a real table, not nested CASEs, so it is reviewable
--    and retunable without touching the logic below.
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `dc_arch`;
CREATE TEMPORARY TABLE `dc_arch` (
  `arch`      VARCHAR(8) NOT NULL,
  `variant`   TINYINT    NOT NULL,
  `ord`       TINYINT    NOT NULL,
  `stat_type` TINYINT    NOT NULL,
  PRIMARY KEY (`arch`, `variant`, `ord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 45 SpellPower  38 AttackPower  3 Agi  4 Str  5 Int  6 Spirit  7 Stamina
-- 12 Defense  13 Dodge  31 Hit  32 Crit  36 Haste  37 Expertise
INSERT INTO `dc_arch` (`arch`, `variant`, `ord`, `stat_type`) VALUES
-- cloth: caster dps / healer
('cloth',  0, 1, 45), ('cloth',  0, 2,  7), ('cloth',  0, 3,  5), ('cloth',  0, 4, 32),
('cloth',  1, 1, 45), ('cloth',  1, 2,  7), ('cloth',  1, 3,  5), ('cloth',  1, 4,  6),
-- leather: agility dps / druid caster
('leather',0, 1, 38), ('leather',0, 2,  7), ('leather',0, 3,  3), ('leather',0, 4, 32),
('leather',1, 1, 45), ('leather',1, 2,  7), ('leather',1, 3,  5), ('leather',1, 4, 36),
-- mail: hunter/enhancement / elemental-restoration
('mail',   0, 1, 38), ('mail',   0, 2,  7), ('mail',   0, 3,  3), ('mail',   0, 4, 31),
('mail',   1, 1, 45), ('mail',   1, 2,  7), ('mail',   1, 3,  5), ('mail',   1, 4, 32),
-- plate: strength dps / tank
('plate',  0, 1,  4), ('plate',  0, 2,  7), ('plate',  0, 3, 32), ('plate',  0, 4, 36),
('plate',  1, 1,  4), ('plate',  1, 2,  7), ('plate',  1, 3, 12), ('plate',  1, 4, 13),
-- shields and off-hands: tank / caster
('shield', 0, 1,  7), ('shield', 0, 2,  4), ('shield', 0, 3, 12), ('shield', 0, 4, 13),
('shield', 1, 1,  7), ('shield', 1, 2,  5), ('shield', 1, 3, 45), ('shield', 1, 4,  6),
-- cloaks, rings, necks, trinkets, relics: agi / int / str, 3-way
('misc',   0, 1,  7), ('misc',   0, 2,  3), ('misc',   0, 3, 38), ('misc',   0, 4, 32),
('misc',   1, 1,  7), ('misc',   1, 2,  5), ('misc',   1, 3, 45), ('misc',   1, 4, 32),
('misc',   2, 1,  7), ('misc',   2, 2,  4), ('misc',   2, 3, 38), ('misc',   2, 4, 31),
-- strength weapons: axes, maces, swords, polearms, fist
('wep_str',0, 1,  4), ('wep_str',0, 2,  7), ('wep_str',0, 3, 32), ('wep_str',0, 4, 31),
('wep_str',1, 1,  4), ('wep_str',1, 2,  7), ('wep_str',1, 3, 37), ('wep_str',1, 4, 36),
-- agility weapons: bows, guns, crossbows, thrown, daggers
('wep_agi',0, 1,  3), ('wep_agi',0, 2,  7), ('wep_agi',0, 3, 38), ('wep_agi',0, 4, 32),
('wep_agi',1, 1,  3), ('wep_agi',1, 2,  7), ('wep_agi',1, 3, 31), ('wep_agi',1, 4, 36),
-- caster weapons: staves, wands
('wep_int',0, 1, 45), ('wep_int',0, 2,  7), ('wep_int',0, 3,  5), ('wep_int',0, 4, 32),
('wep_int',1, 1, 45), ('wep_int',1, 2,  7), ('wep_int',1, 3,  5), ('wep_int',1, 4, 36);

-- ---------------------------------------------------------------------------
-- 2. Per-item budget and archetype key
-- ---------------------------------------------------------------------------
-- slot_weight and quality_multiplier are copied verbatim from 309_/312_.
-- `misc` has three variants and everything else two, so the modulus follows
-- the archetype rather than being a global constant.
DROP TEMPORARY TABLE IF EXISTS `dc_gear`;
CREATE TEMPORARY TABLE `dc_gear` (
  `entry`   INT UNSIGNED NOT NULL PRIMARY KEY,
  `budget`  INT        NOT NULL,
  `cap`     INT        NOT NULL,
  `arch`    VARCHAR(8) NOT NULL,
  `variant` TINYINT    NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_gear` (`entry`, `budget`, `cap`, `arch`, `variant`)
SELECT i.`entry`,
       GREATEST(4, ROUND(0.00207 * POW(i.`ItemLevel`, 2.13)
         * CASE WHEN i.`InventoryType` IN (1, 5, 7, 20) THEN 1.15
                WHEN i.`InventoryType` IN (2, 8, 9, 10, 6, 11, 12, 14, 15, 16, 23, 26) THEN 0.75
                ELSE 1.00 END
         * CASE i.`Quality` WHEN 3 THEN 1.00 WHEN 4 THEN 1.15 ELSE 0.85 END)),
       GREATEST(1, ROUND(0.00207 * POW(i.`ItemLevel`, 2.13)
         * CASE WHEN i.`InventoryType` IN (1, 5, 7, 20) THEN 1.15
                WHEN i.`InventoryType` IN (2, 8, 9, 10, 6, 11, 12, 14, 15, 16, 23, 26) THEN 0.75
                ELSE 1.00 END
         * CASE i.`Quality` WHEN 3 THEN 1.00 WHEN 4 THEN 1.15 ELSE 0.85 END * 0.40)),
       a.`arch`,
       CASE WHEN a.`arch` = 'misc' THEN i.`entry` % 3 ELSE i.`entry` % 2 END
FROM `item_template` i
JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry`
JOIN LATERAL (
  SELECT CASE
    WHEN i.`class` = 4 AND i.`subclass` = 1 THEN 'cloth'
    WHEN i.`class` = 4 AND i.`subclass` = 2 THEN 'leather'
    WHEN i.`class` = 4 AND i.`subclass` = 3 THEN 'mail'
    WHEN i.`class` = 4 AND i.`subclass` = 4 THEN 'plate'
    WHEN i.`class` = 4 AND i.`subclass` = 6 THEN 'shield'
    WHEN i.`class` = 4                      THEN 'misc'
    WHEN i.`class` = 2 AND i.`subclass` IN (2, 3, 15, 16, 18) THEN 'wep_agi'
    WHEN i.`class` = 2 AND i.`subclass` IN (10, 19)           THEN 'wep_int'
    ELSE 'wep_str'
  END AS `arch`
) a ON TRUE
WHERE i.`class` IN (2, 4)
  AND i.`InventoryType` > 0;

-- ---------------------------------------------------------------------------
-- 3. Candidate stat types -- existing first, archetype after
-- ---------------------------------------------------------------------------
-- 🔴 Archetype rows are given `ord` 101-104 so that when a type appears in BOTH
-- lists the MIN(ord) in step 4 still resolves to the item's own slot order.
-- Using 1-4 for both would let an archetype position reorder the item's real
-- stats.
DROP TEMPORARY TABLE IF EXISTS `dc_cand`;
CREATE TEMPORARY TABLE `dc_cand` (
  `entry`     INT UNSIGNED NOT NULL,
  `stat_type` TINYINT      NOT NULL,
  `prio`      TINYINT      NOT NULL,
  `ord`       SMALLINT     NOT NULL,
  KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 🔴 MySQL cannot open a TEMPORARY table twice in ONE statement (error 1137
-- "Can't reopen table"). The ten stat slots are therefore unpivoted in a derived
-- table FIRST and joined to `dc_gear` exactly ONCE, instead of the obvious
-- ten-way `JOIN dc_gear` which fails outright. The scan is bounded by
-- `dc_map750_item_clone`, which is a REGULAR table (created by 309_) and so may
-- be referenced as many times as needed.
INSERT INTO `dc_cand` (`entry`, `stat_type`, `prio`, `ord`)
SELECT u.`entry`, u.`stat_type`, 0, u.`ord`
FROM (
            SELECT i.`entry`, i.`stat_type1`  AS `stat_type`,  1 AS `ord` FROM `item_template` i JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry` WHERE i.`stat_value1`  > 0 AND i.`stat_type1`  > 0
  UNION ALL SELECT i.`entry`, i.`stat_type2`,   2 FROM `item_template` i JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry` WHERE i.`stat_value2`  > 0 AND i.`stat_type2`  > 0
  UNION ALL SELECT i.`entry`, i.`stat_type3`,   3 FROM `item_template` i JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry` WHERE i.`stat_value3`  > 0 AND i.`stat_type3`  > 0
  UNION ALL SELECT i.`entry`, i.`stat_type4`,   4 FROM `item_template` i JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry` WHERE i.`stat_value4`  > 0 AND i.`stat_type4`  > 0
  UNION ALL SELECT i.`entry`, i.`stat_type5`,   5 FROM `item_template` i JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry` WHERE i.`stat_value5`  > 0 AND i.`stat_type5`  > 0
  UNION ALL SELECT i.`entry`, i.`stat_type6`,   6 FROM `item_template` i JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry` WHERE i.`stat_value6`  > 0 AND i.`stat_type6`  > 0
  UNION ALL SELECT i.`entry`, i.`stat_type7`,   7 FROM `item_template` i JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry` WHERE i.`stat_value7`  > 0 AND i.`stat_type7`  > 0
  UNION ALL SELECT i.`entry`, i.`stat_type8`,   8 FROM `item_template` i JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry` WHERE i.`stat_value8`  > 0 AND i.`stat_type8`  > 0
  UNION ALL SELECT i.`entry`, i.`stat_type9`,   9 FROM `item_template` i JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry` WHERE i.`stat_value9`  > 0 AND i.`stat_type9`  > 0
  UNION ALL SELECT i.`entry`, i.`stat_type10`, 10 FROM `item_template` i JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry` WHERE i.`stat_value10` > 0 AND i.`stat_type10` > 0
) u
JOIN `dc_gear` g ON g.`entry` = u.`entry`;

-- Separate statement on purpose -- folding this into the UNION above would be a
-- second reference to `dc_gear` in the same statement and hit 1137 again.
INSERT INTO `dc_cand` (`entry`, `stat_type`, `prio`, `ord`)
SELECT g.`entry`, a.`stat_type`, 1, 100 + a.`ord`
FROM `dc_gear` g
JOIN `dc_arch` a ON a.`arch` = g.`arch` AND a.`variant` = g.`variant`;

-- ---------------------------------------------------------------------------
-- 4. Resolve to exactly four stat types per item
-- ---------------------------------------------------------------------------
-- The GROUP BY is the dedup: a type present in both lists collapses to one row
-- with prio 0. The archetype always contributes 4 distinct types, so every item
-- resolves to at least 4 candidates and the LIMIT is never short.
--
-- Items that had 5 stats (4 rows on the whole continent) keep their first four
-- and are re-weighted onto the budget -- consolidated rather than truncated.
DROP TEMPORARY TABLE IF EXISTS `dc_pick`;
CREATE TEMPORARY TABLE `dc_pick` (
  `entry`     INT UNSIGNED NOT NULL,
  `stat_type` TINYINT      NOT NULL,
  `rn`        TINYINT      NOT NULL,
  PRIMARY KEY (`entry`, `rn`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_pick` (`entry`, `stat_type`, `rn`)
SELECT `entry`, `stat_type`, `rn` FROM (
  SELECT d.`entry`, d.`stat_type`,
         ROW_NUMBER() OVER (PARTITION BY d.`entry` ORDER BY d.`prio`, d.`ord`) AS `rn`
  FROM (
    SELECT `entry`, `stat_type`, MIN(`prio`) AS `prio`, MIN(`ord`) AS `ord`
    FROM `dc_cand`
    GROUP BY `entry`, `stat_type`
  ) d
) r
WHERE r.`rn` <= 4;

-- ---------------------------------------------------------------------------
-- 5. Pivot to four typed columns with the 32/28/23/17 spread
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `dc_final`;
CREATE TEMPORARY TABLE `dc_final` (
  `entry` INT UNSIGNED NOT NULL PRIMARY KEY,
  `t1` TINYINT NOT NULL, `v1` INT NOT NULL,
  `t2` TINYINT NOT NULL, `v2` INT NOT NULL,
  `t3` TINYINT NOT NULL, `v3` INT NOT NULL,
  `t4` TINYINT NOT NULL, `v4` INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_final` (`entry`, `t1`, `v1`, `t2`, `v2`, `t3`, `v3`, `t4`, `v4`)
SELECT g.`entry`,
       MAX(CASE WHEN p.`rn` = 1 THEN p.`stat_type` END), LEAST(g.`cap`, GREATEST(1, ROUND(g.`budget` * 0.32))),
       MAX(CASE WHEN p.`rn` = 2 THEN p.`stat_type` END), LEAST(g.`cap`, GREATEST(1, ROUND(g.`budget` * 0.28))),
       MAX(CASE WHEN p.`rn` = 3 THEN p.`stat_type` END), LEAST(g.`cap`, GREATEST(1, ROUND(g.`budget` * 0.23))),
       MAX(CASE WHEN p.`rn` = 4 THEN p.`stat_type` END), LEAST(g.`cap`, GREATEST(1, ROUND(g.`budget` * 0.17)))
FROM `dc_gear` g
JOIN `dc_pick` p ON p.`entry` = g.`entry`
GROUP BY g.`entry`
HAVING MAX(CASE WHEN p.`rn` = 4 THEN p.`stat_type` END) IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 6. Write it
-- ---------------------------------------------------------------------------
-- Slots 5-10 are cleared: after this file an item's stats are exactly the four
-- resolved above, so a leftover value in slot 5 would be budget nobody counted.
UPDATE `item_template` i
JOIN `dc_final` f ON f.`entry` = i.`entry`
SET i.`stat_type1` = f.`t1`, i.`stat_value1` = f.`v1`,
    i.`stat_type2` = f.`t2`, i.`stat_value2` = f.`v2`,
    i.`stat_type3` = f.`t3`, i.`stat_value3` = f.`v3`,
    i.`stat_type4` = f.`t4`, i.`stat_value4` = f.`v4`,
    i.`stat_type5` = 0, i.`stat_value5` = 0,
    i.`stat_type6` = 0, i.`stat_value6` = 0,
    i.`stat_type7` = 0, i.`stat_value7` = 0,
    i.`stat_type8` = 0, i.`stat_value8` = 0,
    i.`stat_type9` = 0, i.`stat_value9` = 0,
    i.`stat_type10` = 0, i.`stat_value10` = 0;

DROP TEMPORARY TABLE IF EXISTS `dc_final`;
DROP TEMPORARY TABLE IF EXISTS `dc_pick`;
DROP TEMPORARY TABLE IF EXISTS `dc_cand`;
DROP TEMPORARY TABLE IF EXISTS `dc_gear`;
DROP TEMPORARY TABLE IF EXISTS `dc_arch`;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- No equippable clone left without stats (expect 0):
-- SELECT COUNT(*) FROM dc_map750_item_clone m JOIN item_template i
--   ON i.entry = m.clone_entry
-- WHERE i.class IN (2, 4) AND i.InventoryType > 0
--   AND (i.stat_value1 + i.stat_value2 + i.stat_value3 + i.stat_value4) = 0;
--
-- Every one on budget (expect ~100% for all rows):
-- SELECT i.Quality, COUNT(*) n, ROUND(AVG(100 *
--          (i.stat_value1 + i.stat_value2 + i.stat_value3 + i.stat_value4) /
--          GREATEST(1, ROUND(0.00207 * POW(i.ItemLevel, 2.13)
--            * CASE WHEN i.InventoryType IN (1,5,7,20) THEN 1.15
--                   WHEN i.InventoryType IN (2,8,9,10,6,11,12,14,15,16,23,26) THEN 0.75
--                   ELSE 1.00 END
--            * CASE i.Quality WHEN 3 THEN 1.00 WHEN 4 THEN 1.15 ELSE 0.85 END))), 1) pct
-- FROM dc_map750_item_clone m JOIN item_template i ON i.entry = m.clone_entry
-- WHERE i.class IN (2, 4) AND i.InventoryType > 0 GROUP BY i.Quality;
--
-- Nothing outranks the ladder (expect max <= ~231, the ladder's top stat):
-- SELECT MAX(stat_value1) FROM dc_map750_item_clone m
-- JOIN item_template i ON i.entry = m.clone_entry WHERE i.Quality = 2;
--
-- The two items from the report:
-- SELECT entry, name, ItemLevel, Quality, armor,
--        stat_type1, stat_value1, stat_type2, stat_value2,
--        stat_type3, stat_value3, stat_type4, stat_value4
-- FROM item_template WHERE entry IN (501288, 500886);
--
-- 🔴 CLIENT CACHE: item_template changes are masked by the client's WDB cache
-- for any item a player has already inspected. Bump the cache id (or have
-- players clear Cache/WDB) or the old statless tooltip will persist in-game
-- even though the server data is correct.
-- ---------------------------------------------------------------------------
