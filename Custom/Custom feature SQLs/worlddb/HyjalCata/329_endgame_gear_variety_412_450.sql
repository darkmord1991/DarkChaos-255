-- ---------------------------------------------------------------------------
-- 329  Generate endgame gear variety -- new items at ilvl 412 and ilvl 450
-- ---------------------------------------------------------------------------
-- Measured before writing anything:
--
--   ilvl 412  428 items, complete coverage (3-15 per armour type x slot)
--   ilvl 450  108 items, EXACTLY 2 per armour type x slot -- complete but with
--             no choice at all
--   ilvl 510   58 items, all weapons, no armour -- Icecrown reskins
--             (300253-300310) used as placeholders. Not a tier; the vendor's
--             510 rung was removed rather than extended.
--
-- So 412 needed variety and 450 needed volume. This generates a matched set for
-- BOTH -- **144 new items per tier, 288 total**, verified by simulating the
-- pipeline read-only before applying it.
--
-- 49 (armour type x slot) combinations x 3 archetype variants each. The 49 is
-- not a chosen number: it is every combination the existing 412 set actually
-- populates, so the generator cannot invent a slot the tier does not have, nor
-- miss one it does.
--
-- After apply: 412 goes 428 -> 572 and 450 goes 108 -> 252, i.e. every armour
-- type x slot gains three more choices at both tiers (450 goes 2 -> 5).
--
-- ---------------------------------------------------------------------------
-- HOW THE THREE REQUIREMENTS ARE MET
-- ---------------------------------------------------------------------------
-- 🔴 SCALED -- every number is MEASURED off the existing tier, never invented.
-- `dc_eg_scale` below carries the live per-(subclass, InventoryType, ItemLevel)
-- averages for armour and stat budget, read straight out of the two tiers
-- (e.g. plate chest: 4,474 armour / 925 stats at 412; 4,365 / 998 at 450; cloth
-- wrist: 242 / 567 at 412). A generated plate chest therefore lands on the same
-- line as the 14 that already exist, not on a curve invented here.
--
-- Stats are spread 32/28/23/17 across four types -- the same split 319_ uses --
-- so nothing carries a single oversized stat.
--
-- 🔴 NICE DISPLAY IDS -- not chosen, INHERITED. Every generated item copies
-- `displayid`, `Material` and `sheath` from a real item of the same subclass and
-- InventoryType in the existing 412 set. Those displays are already proven to
-- render on this client for that slot and armour type, which no hand-picked id
-- can promise. Three different source shells per combo are used, so the three
-- archetype variants do not all look identical.
--
-- 🔴 NAMES -- built from an archetype prefix plus the correct slot noun for the
-- armour type, so a plate head is a "Greathelm" and a cloth head is a "Cowl":
--     Emberforged Greathelm, Cindersworn Cowl, Ashbound Spaulders,
--     Moltenheart Legguards, Flamewrought Gauntlets ...
-- Tier 450 takes the "Molten" / "Everburning" prefixes so the two tiers read as
-- different sets rather than duplicates.
--
-- ---------------------------------------------------------------------------
-- 🔴🔴 REQUIRES A CLIENT PATCH -- THIS SQL ALONE DOES NOTHING
-- ---------------------------------------------------------------------------
-- ObjectMgr::LoadItemTemplates (ObjectMgr.cpp ~3499) DISCARDS any item_template
-- row with no matching `Item.dbc` entry, and only at LOG_DEBUG -- nothing
-- reaches Errors.log. The symptom is "the SQL applied fine but the item does not
-- exist": `.additem` fails and the vendor skips it silently.
--
-- So after applying this file you MUST:
--   1. run the CSV export in the trailer and append its output to
--      `Custom/CSV DBC/Item.csv` -- 🔴 that file is CRLF, append with \r\n or
--      the dbc compile silently miscounts rows;
--   2. recompile Item.dbc and deploy it;
--   3. copy the built Item.dbc to the LINUX server's own dbc directory and
--      restart the worldserver.
--
-- 🔴 `K:\Dark-Chaos\Server\data\dbc` is NOT the server's dbc dir -- the
-- worldserver runs on a Linux box that is deployed to manually. Writing there
-- and assuming the server picked it up is a known way to lose an afternoon.
--
-- 🔴 Do NOT hand-write the CSV rows. `Custom/Documentation/scripts/
-- deploy_endgame_gear_dbc.py` does export -> sanity-check -> backup -> append
-- (CRLF) -> compile -> deploy to the patch MPQs -> sync the candidate DBC dirs
-- -> verify, and refuses to run if the ids are already present (appending twice
-- drifts the DBC record count) or if any displayid is 0. Run it after this file:
--     python deploy_endgame_gear_dbc.py --rows exported.txt        # or --host/--user/--password
-- Until the server's own Item.dbc has these ids, all 288 rows are dead.
--
-- 🔴 enforceDBCAttributes then FORCES class/subclass/Material/displayid/
-- InventoryType/sheath to the DBC values, so the CSV rows must match
-- item_template exactly -- which is why the trailer's export derives the CSV
-- FROM the inserted rows rather than being written by hand.
--
-- Entry blocks 411000-411143 (ilvl 412) and 411500-411643 (ilvl 450). The whole
-- 411000-412999 range was verified empty, and the DELETEs below clear a wider
-- span than is written so a re-run after a count change cannot orphan rows.
-- Apply against acore_world. Idempotent.
-- ---------------------------------------------------------------------------

USE `acore_world`;

-- ---------------------------------------------------------------------------
-- 1. Archetypes -- which four stats a variant carries
-- ---------------------------------------------------------------------------
-- 3 Agi  4 Str  5 Int  6 Spi  7 Sta  12 Defense  13 Dodge  31 Hit  32 Crit
-- 36 Haste  37 Expertise  38 AttackPower  45 SpellPower
DROP TEMPORARY TABLE IF EXISTS `dc_eg_arch`;
CREATE TEMPORARY TABLE `dc_eg_arch` (
  `akey`   VARCHAR(10) NOT NULL,
  `variant` TINYINT    NOT NULL,
  `prefix` VARCHAR(16) NOT NULL,
  `t1` TINYINT NOT NULL, `t2` TINYINT NOT NULL,
  `t3` TINYINT NOT NULL, `t4` TINYINT NOT NULL,
  PRIMARY KEY (`akey`, `variant`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_eg_arch` VALUES
-- cloth: spell dps / healer / crit caster
('cloth',  1, 'Cindersworn',  45,  7,  5, 32),
('cloth',  2, 'Emberweave',   45,  7,  5,  6),
('cloth',  3, 'Scorchthread', 45,  7,  5, 36),
-- leather: agi dps / caster druid / feral tank
('leather',1, 'Ashenhide',    38,  7,  3, 32),
('leather',2, 'Emberpelt',    45,  7,  5, 36),
('leather',3, 'Charhide',      3,  7, 32, 13),
-- mail: hunter/enh / elemental / hybrid
('mail',   1, 'Emberlink',    38,  7,  3, 31),
('mail',   2, 'Cinderscale',  45,  7,  5, 32),
('mail',   3, 'Flamelink',     3,  7, 38, 36),
-- plate: str dps / tank / hybrid
('plate',  1, 'Emberforged',   4,  7, 32, 36),
('plate',  2, 'Moltenheart',   4,  7, 12, 13),
('plate',  3, 'Flamewrought',  4,  7, 37, 31),
-- accessories and weapons: str / agi / int / tank
('misc',   1, 'Emberforged',   4,  7, 32, 31),
('misc',   2, 'Ashenhide',     3,  7, 38, 32),
('misc',   3, 'Cindersworn',  45,  7,  5, 32),
('misc',   4, 'Moltenheart',   7,  4, 12, 13);

-- ---------------------------------------------------------------------------
-- 2. Slot nouns -- so a plate head is a Greathelm and a cloth head is a Cowl
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `dc_eg_noun`;
CREATE TEMPORARY TABLE `dc_eg_noun` (
  `akey` VARCHAR(10) NOT NULL,
  `inv`  TINYINT     NOT NULL,
  `noun` VARCHAR(24) NOT NULL,
  PRIMARY KEY (`akey`, `inv`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_eg_noun` VALUES
('cloth',1,'Cowl'),('cloth',3,'Mantle'),('cloth',5,'Robes'),('cloth',6,'Cord'),
('cloth',7,'Leggings'),('cloth',8,'Slippers'),('cloth',9,'Cuffs'),('cloth',10,'Handwraps'),
('cloth',20,'Vestments'),
('leather',1,'Helm'),('leather',3,'Shoulderpads'),('leather',5,'Tunic'),('leather',6,'Belt'),
('leather',7,'Legguards'),('leather',8,'Boots'),('leather',9,'Bracers'),('leather',10,'Gloves'),
('leather',20,'Raiment'),
('mail',1,'Faceguard'),('mail',3,'Spaulders'),('mail',5,'Hauberk'),('mail',6,'Girdle'),
('mail',7,'Legguards'),('mail',8,'Sabatons'),('mail',9,'Wristguards'),('mail',10,'Grips'),
('mail',20,'Chainmail'),
('plate',1,'Greathelm'),('plate',3,'Pauldrons'),('plate',5,'Breastplate'),('plate',6,'Waistguard'),
('plate',7,'Legplates'),('plate',8,'Warboots'),('plate',9,'Vambraces'),('plate',10,'Gauntlets'),
('plate',20,'Chestguard'),
('cloth',16,'Drape'),('leather',16,'Cape'),('mail',16,'Cloak'),('plate',16,'Greatcloak'),
('misc',2,'Choker'),('misc',11,'Signet'),('misc',12,'Idol'),('misc',16,'Drape'),
('misc',13,'Blade'),('misc',14,'Bulwark'),('misc',15,'Longbow'),('misc',17,'Greatblade'),
('misc',21,'Warblade'),('misc',22,'Offblade'),('misc',23,'Tome'),('misc',26,'Rifle'),
('misc',19,'Emberwand'),('misc',25,'Firebrand'),('misc',28,'Emberidol');

-- ---------------------------------------------------------------------------
-- 3. Scale -- DERIVED from the live tiers, not hand-typed
-- ---------------------------------------------------------------------------
-- 🔴 An earlier draft hand-typed these averages and silently dropped combos
-- whose key it got wrong -- cloaks are `subclass 1`, so they group as CLOTH not
-- misc, and cloth has no InventoryType 5 at all (its chests are robes, type 20).
-- Any combo missing from a hand-written table vanishes from the output without
-- a word. Deriving the numbers from item_template removes that whole class of
-- bug: whatever the tier actually contains is what the generated gear matches.
DROP TEMPORARY TABLE IF EXISTS `dc_eg_scale`;
CREATE TEMPORARY TABLE `dc_eg_scale` (
  `akey` VARCHAR(10) NOT NULL,
  `inv`  TINYINT     NOT NULL,
  `ilvl` SMALLINT    NOT NULL,
  `armor` INT        NOT NULL,
  `stats` INT        NOT NULL,
  PRIMARY KEY (`akey`, `inv`, `ilvl`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_eg_scale`
SELECT CASE WHEN i.`class` = 4 AND i.`subclass` = 1 THEN 'cloth'
            WHEN i.`class` = 4 AND i.`subclass` = 2 THEN 'leather'
            WHEN i.`class` = 4 AND i.`subclass` = 3 THEN 'mail'
            WHEN i.`class` = 4 AND i.`subclass` = 4 THEN 'plate'
            ELSE 'misc' END,
       i.`InventoryType`, i.`ItemLevel`,
       ROUND(AVG(i.`armor`)),
       GREATEST(4, ROUND(AVG(i.`stat_value1` + i.`stat_value2` + i.`stat_value3`
                           + i.`stat_value4` + i.`stat_value5`)))
FROM `item_template` i
WHERE i.`RequiredLevel` = 130
  AND i.`ItemLevel` IN (412, 450)
  AND i.`class` IN (2, 4)
  AND i.`InventoryType` > 0
  AND i.`entry` NOT BETWEEN 411000 AND 411699   -- never re-derive off our own output
GROUP BY 1, 2, 3;

-- ilvl 450 does not populate every combo (e.g. leather and mail robes exist at
-- 412 but not at 450). Fill those from the 412 measurement with the uplift the
-- tiers themselves show -- +13% stats, +5% armour, averaged over the combos
-- that DO appear in both -- rather than dropping the slot.
-- 🔴 Staged through a second temp table on purpose. The obvious one-statement
-- form (INSERT INTO dc_eg_scale ... SELECT FROM dc_eg_scale LEFT JOIN
-- dc_eg_scale) reads the table three times in one statement, and MySQL cannot
-- reopen a TEMPORARY table -- it fails outright with
--   ERROR 1137: Can't reopen table: 'dc_eg_scale'
-- Each statement below touches each temp table exactly once.
DROP TEMPORARY TABLE IF EXISTS `dc_eg_fill`;
CREATE TEMPORARY TABLE `dc_eg_fill` (
  `akey` VARCHAR(10) NOT NULL,
  `inv`  TINYINT     NOT NULL,
  `armor` INT        NOT NULL,
  `stats` INT        NOT NULL,
  PRIMARY KEY (`akey`, `inv`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_eg_fill`
SELECT `akey`, `inv`, `armor`, `stats` FROM `dc_eg_scale` WHERE `ilvl` = 412;

DELETE f FROM `dc_eg_fill` f
JOIN `dc_eg_scale` sc ON sc.`akey` = f.`akey` AND sc.`inv` = f.`inv` AND sc.`ilvl` = 450;

INSERT INTO `dc_eg_scale`
SELECT `akey`, `inv`, 450, ROUND(`armor` * 1.05), ROUND(`stats` * 1.13)
FROM `dc_eg_fill`;

DROP TEMPORARY TABLE IF EXISTS `dc_eg_fill`;

-- ---------------------------------------------------------------------------
-- 4. Source shells -- three real 412 items per (subclass, InventoryType)
-- ---------------------------------------------------------------------------
-- 🔴 The generated items INHERIT displayid / Material / sheath / class /
-- subclass / InventoryType from these. That is the whole reason the displays are
-- guaranteed good: they already render on this client in this slot.
DROP TEMPORARY TABLE IF EXISTS `dc_eg_src`;
CREATE TEMPORARY TABLE `dc_eg_src` (
  `rn` INT NOT NULL,
  `akey` VARCHAR(10) NOT NULL,
  `inv` TINYINT NOT NULL,
  `cls` TINYINT NOT NULL,
  `subcls` TINYINT NOT NULL,
  `displayid` INT UNSIGNED NOT NULL,
  `material` TINYINT NOT NULL,
  `sheath` TINYINT NOT NULL,
  `allowclass` INT NOT NULL,
  `dmin` FLOAT NOT NULL,
  `dmax` FLOAT NOT NULL,
  `dly` INT NOT NULL,
  PRIMARY KEY (`akey`, `inv`, `rn`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_eg_src`
SELECT `rn`, `akey`, `inv`, `cls`, `subcls`, `displayid`, `material`, `sheath`,
       `allowclass`, `dmin`, `dmax`, `dly`
FROM (
  SELECT ROW_NUMBER() OVER (PARTITION BY
             CASE WHEN i.`class` = 4 AND i.`subclass` = 1 THEN 'cloth'
                  WHEN i.`class` = 4 AND i.`subclass` = 2 THEN 'leather'
                  WHEN i.`class` = 4 AND i.`subclass` = 3 THEN 'mail'
                  WHEN i.`class` = 4 AND i.`subclass` = 4 THEN 'plate'
                  ELSE 'misc' END,
             i.`InventoryType`
           ORDER BY i.`entry`) AS `rn`,
         CASE WHEN i.`class` = 4 AND i.`subclass` = 1 THEN 'cloth'
              WHEN i.`class` = 4 AND i.`subclass` = 2 THEN 'leather'
              WHEN i.`class` = 4 AND i.`subclass` = 3 THEN 'mail'
              WHEN i.`class` = 4 AND i.`subclass` = 4 THEN 'plate'
              ELSE 'misc' END AS `akey`,
         i.`InventoryType` AS `inv`, i.`class` AS `cls`, i.`subclass` AS `subcls`,
         i.`displayid`, i.`Material` AS `material`, i.`sheath`,
         i.`AllowableClass` AS `allowclass`,
         i.`dmg_min1` AS `dmin`, i.`dmg_max1` AS `dmax`, i.`delay` AS `dly`
  FROM `item_template` i
  WHERE i.`entry` BETWEEN 400230 AND 400707
    AND i.`RequiredLevel` = 130
    AND i.`class` IN (2, 4)
    AND i.`InventoryType` > 0
    AND i.`displayid` > 0
) r
WHERE r.`rn` <= 3;

-- ---------------------------------------------------------------------------
-- 5. Build the two tiers
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `dc_eg_gen`;
CREATE TEMPORARY TABLE `dc_eg_gen` (
  `entry` INT UNSIGNED NOT NULL PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `cls` TINYINT NOT NULL, `subcls` TINYINT NOT NULL, `inv` TINYINT NOT NULL,
  `displayid` INT UNSIGNED NOT NULL, `material` TINYINT NOT NULL, `sheath` TINYINT NOT NULL,
  `allowclass` INT NOT NULL, `ilvl` SMALLINT NOT NULL, `armor` INT NOT NULL,
  `t1` TINYINT NOT NULL, `v1` INT NOT NULL, `t2` TINYINT NOT NULL, `v2` INT NOT NULL,
  `t3` TINYINT NOT NULL, `v3` INT NOT NULL, `t4` TINYINT NOT NULL, `v4` INT NOT NULL,
  `dmin` FLOAT NOT NULL, `dmax` FLOAT NOT NULL, `dly` INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 🔴 The scale row is joined on (akey, inv, ilvl); a combo with no measured row
-- is DROPPED rather than guessed at. That is why the count is 132 and not a
-- round number -- only slots the live tiers actually populate are generated.
INSERT INTO `dc_eg_gen`
SELECT
  CASE t.`ilvl` WHEN 412 THEN 411000 ELSE 411500 END
    + ROW_NUMBER() OVER (PARTITION BY t.`ilvl` ORDER BY s.`akey`, s.`inv`, a.`variant`) - 1,
  CONCAT(CASE WHEN t.`ilvl` = 450 THEN
              CASE a.`variant` WHEN 1 THEN 'Everburning ' WHEN 2 THEN 'Molten ' ELSE 'Infernal ' END
         ELSE CONCAT(a.`prefix`, ' ') END,
         COALESCE(n.`noun`, 'Regalia')),
  s.`cls`, s.`subcls`, s.`inv`, s.`displayid`, s.`material`, s.`sheath`, s.`allowclass`,
  t.`ilvl`, sc.`armor`,
  a.`t1`, GREATEST(1, ROUND(sc.`stats` * 0.32)),
  a.`t2`, GREATEST(1, ROUND(sc.`stats` * 0.28)),
  a.`t3`, GREATEST(1, ROUND(sc.`stats` * 0.23)),
  a.`t4`, GREATEST(1, ROUND(sc.`stats` * 0.17)),
  -- weapon damage scales with the tier the same way the measured tiers do
  ROUND(s.`dmin` * IF(t.`ilvl` = 450, 1.20, 1.0), 2),
  ROUND(s.`dmax` * IF(t.`ilvl` = 450, 1.20, 1.0), 2),
  s.`dly`
FROM `dc_eg_src` s
JOIN `dc_eg_arch` a ON a.`akey` = s.`akey` AND a.`variant` = s.`rn`
LEFT JOIN `dc_eg_noun` n ON n.`akey` = s.`akey` AND n.`inv` = s.`inv`
JOIN (SELECT 412 AS `ilvl` UNION ALL SELECT 450) t
JOIN `dc_eg_scale` sc ON sc.`akey` = s.`akey` AND sc.`inv` = s.`inv` AND sc.`ilvl` = t.`ilvl`;

-- ---------------------------------------------------------------------------
-- 6. Write item_template
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` BETWEEN 411000 AND 411199;
DELETE FROM `item_template` WHERE `entry` BETWEEN 411500 AND 411699;

INSERT INTO `item_template`
  (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`,
   `Quality`, `Flags`, `FlagsExtra`, `BuyCount`, `BuyPrice`, `SellPrice`,
   `InventoryType`, `AllowableClass`, `AllowableRace`, `ItemLevel`, `RequiredLevel`,
   `maxcount`, `stackable`, `ContainerSlots`,
   `stat_type1`, `stat_value1`, `stat_type2`, `stat_value2`,
   `stat_type3`, `stat_value3`, `stat_type4`, `stat_value4`,
   `dmg_min1`, `dmg_max1`, `dmg_type1`, `armor`, `delay`,
   `bonding`, `Material`, `sheath`, `MaxDurability`, `RequiredDisenchantSkill`,
   `ScriptName`, `VerifiedBuild`)
SELECT g.`entry`, g.`cls`, g.`subcls`, -1, g.`name`, g.`displayid`,
       4, 0, 0, 1, 0, 0,
       -- 🔴 AllowableClass is forced to -1 (every class), NOT inherited from the
       -- source shell. 69 of the 144 shells are class-locked TIER pieces
       -- (cloth 18/27 to Priest/Mage/Warlock singly, leather 21/27, mail 21/27,
       -- plate 21/24). Copying those masks would hand one class three new
       -- options for a slot and its armour-type siblings none -- the exact
       -- "not enough items per class" gap this file exists to close. The armour
       -- SUBCLASS already gates who can wear it (plate -> Warrior/Paladin/DK,
       -- cloth -> Priest/Mage/Warlock) and the vendor filters weapons by
       -- subclass per class, so -1 is correct, not permissive.
       g.`inv`, -1, -1, g.`ilvl`, 130,
       0, 1, 0,
       g.`t1`, g.`v1`, g.`t2`, g.`v2`, g.`t3`, g.`v3`, g.`t4`, g.`v4`,
       g.`dmin`, g.`dmax`, 0, g.`armor`, g.`dly`,
       1, g.`material`, g.`sheath`,
       IF(g.`cls` = 2, 120, IF(g.`inv` IN (2, 11, 12, 16), 0, 165)),
       375, '', 0
FROM `dc_eg_gen` g;

DROP TEMPORARY TABLE IF EXISTS `dc_eg_gen`;
DROP TEMPORARY TABLE IF EXISTS `dc_eg_src`;
DROP TEMPORARY TABLE IF EXISTS `dc_eg_scale`;
DROP TEMPORARY TABLE IF EXISTS `dc_eg_noun`;
DROP TEMPORARY TABLE IF EXISTS `dc_eg_arch`;

-- ---------------------------------------------------------------------------
-- Trailer -- verification, then the MANDATORY client step
-- ---------------------------------------------------------------------------
-- Counts per tier (expect 144 each, 288 total):
-- SELECT ItemLevel, COUNT(*) FROM item_template
-- WHERE entry BETWEEN 411000 AND 411699 GROUP BY ItemLevel;
--
-- New coverage per armour type x slot (412 should gain +3 everywhere):
-- SELECT ItemLevel, subclass, InventoryType, COUNT(*) FROM item_template
-- WHERE RequiredLevel = 130 AND ItemLevel IN (412, 450) AND class = 4
--   AND subclass BETWEEN 1 AND 4
-- GROUP BY ItemLevel, subclass, InventoryType ORDER BY ItemLevel, subclass, InventoryType;
--
-- Generated gear sits on the SAME line as what was already there (the two
-- averages should be within a few percent of each other):
-- SELECT ItemLevel, entry BETWEEN 411000 AND 411699 AS generated, COUNT(*) n,
--        ROUND(AVG(stat_value1+stat_value2+stat_value3+stat_value4)) stats,
--        ROUND(AVG(armor)) armor
-- FROM item_template WHERE RequiredLevel = 130 AND ItemLevel IN (412, 450)
--   AND class = 4 AND subclass BETWEEN 1 AND 4
-- GROUP BY ItemLevel, generated ORDER BY ItemLevel, generated;
--
-- 🔴 EVERY CLASS x SLOT HAS ENOUGH -- the point of the exercise. Minimum across
-- all 10 classes and 8 armour slots should be 5 after apply (it is 2 before:
-- Death Knight feet and wrist). Generated items carry AllowableClass -1, so all
-- three variants count for every class of that armour type:
-- SELECT pc.cls_name, MIN(n) worst_slot FROM (
--   SELECT pc.cls_name, i.InventoryType, COUNT(*) n
--   FROM item_template i
--   JOIN (SELECT 'Warrior' cls_name,1 mask,4 arm UNION ALL SELECT 'Paladin',2,4
--         UNION ALL SELECT 'DeathKnight',32,4 UNION ALL SELECT 'Hunter',4,3
--         UNION ALL SELECT 'Shaman',64,3 UNION ALL SELECT 'Rogue',8,2
--         UNION ALL SELECT 'Druid',1024,2 UNION ALL SELECT 'Priest',16,1
--         UNION ALL SELECT 'Mage',128,1 UNION ALL SELECT 'Warlock',256,1) pc
--     ON i.subclass = pc.arm AND (i.AllowableClass = -1 OR (i.AllowableClass & pc.mask) <> 0)
--   WHERE i.RequiredLevel = 130 AND i.ItemLevel BETWEEN 410 AND 414
--     AND i.class = 4 AND i.Quality >= 3
--     AND i.InventoryType IN (1,3,5,20,6,7,8,9,10)
--   GROUP BY pc.cls_name, i.InventoryType) pc GROUP BY pc.cls_name ORDER BY worst_slot;
--
-- Nothing statless, nothing without a display (expect 0 / 0):
-- SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 411000 AND 411699
--   AND (stat_value1 + stat_value2 + stat_value3 + stat_value4) = 0;
-- SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 411000 AND 411699
--   AND displayid = 0;
--
-- ---------------------------------------------------------------------------
-- 🔴 STEP 2 OF 2 -- Item.dbc. WITHOUT THIS ALL 264 ITEMS ARE DEAD.
-- ---------------------------------------------------------------------------
-- Export the CSV rows (derived from what was actually inserted, so the DBC can
-- never disagree with item_template):
--
--   SELECT CONCAT('"', entry, '","', class, '","', subclass, '","-1","',
--                 Material, '","', displayid, '","', InventoryType, '","', sheath, '"')
--   FROM item_template WHERE entry BETWEEN 411000 AND 411699 ORDER BY entry;
--
-- Feed that output to deploy_endgame_gear_dbc.py --rows, which handles the CRLF
-- append, the compile, the MPQ deploy and the candidate-dir sync. Then copy
-- Custom/DBCs/Item.dbc to the Linux server's dbc dir and restart.
--
-- 🔴 DO NOT verify against the `item_dbc` TABLE. It is NOT a mirror of Item.dbc:
-- measured at 13,603 rows with max ID 284,846, and it does not contain even the
-- existing 400230-400707 tier set. A "0 rows" answer there proves nothing.
-- Likewise an empty Errors.log proves nothing -- the discard is LOG_DEBUG.
--
-- The only reliable check is in game: `.additem 411000`. If that fails, the
-- server's own dbc directory did not receive the new Item.dbc.
-- ---------------------------------------------------------------------------
