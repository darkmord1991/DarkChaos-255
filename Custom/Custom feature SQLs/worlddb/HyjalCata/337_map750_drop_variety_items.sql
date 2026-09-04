-- ---------------------------------------------------------------------------
-- 337  Map 750 drop variety -- 420 new items wired into the zone loot
-- ---------------------------------------------------------------------------
-- The continent's drop pool is thin and repetitive: outside the clone band the
-- same handful of looks recur across 50 levels. This generates a full ladder of
-- new gear, one complete set per level band, and attaches it to the zone's
-- creatures through reference loot.
--
--   5 bands x 4 armour classes x 8 slots  x 2 qualities = 320 armour
--   5 bands x 1 shield                    x 2 qualities =  10 shields
--   5 bands x 4 accessory slots           x 2 qualities =  40 neck/back/ring/trinket
--   5 bands x 6 weapon types              x 2 qualities =  60 weapons
--                                                        ---
--                                                         430 items, 420000-420429
--
-- Every band therefore gains a green AND a blue option in every slot, for every
-- armour class -- which is what "variety" has to mean if it is to help all ten
-- classes rather than whichever one the existing drops happened to favour.
--
-- ---------------------------------------------------------------------------
-- EVERYTHING IS DERIVED FROM MODELS ALREADY IN USE -- nothing new invented
-- ---------------------------------------------------------------------------
--   band -> ilvl   309_/323_:  80->285  88->315  96->355  104->372  113->388
--                  +8 for blue, exactly as 323_ stepped band 113 (388 -> 396)
--   stats          319_'s budget `0.00207 * ilvl^2.13 * slot_weight * quality`
--                  and 319_'s archetypes, split 32/28/23/17 over four stats
--   RequiredLevel  321_'s `ROUND(0.294 * ItemLevel - 6.1)`, clamped into the
--                  band so a drop never gates above the zone that drops it
--
-- ---------------------------------------------------------------------------
-- 🔴 DISPLAY IDS ARE BORROWED FROM REAL ITEMS, NEVER INVENTED
-- ---------------------------------------------------------------------------
-- A displayid that has no `ItemDisplayInfo` row renders as the ErrorCube (the
-- blue box). So each item takes a displayid from an EXISTING item of the same
-- class/subclass/InventoryType, picked with ROW_NUMBER so that the ten items
-- sharing a slot (5 bands x 2 qualities) all get DIFFERENT looks.
--
-- The pool is deep enough for that: 135-254 distinct looks per armour class and
-- slot in the ilvl 100-300 window. The one exception is cloth chest, which has
-- only 34 -- because cloth chests are mostly InventoryType 20 (robe), not 5. The
-- cloth chest row below therefore draws from BOTH 5 and 20.
--
-- ---------------------------------------------------------------------------
-- 🔴 THESE ITEMS ARE DEAD UNTIL THEY ARE IN Item.dbc
-- ---------------------------------------------------------------------------
-- `ObjectMgr::LoadItemTemplates` DISCARDS any item_template row with no Item.dbc
-- entry, and only at LOG_DEBUG -- nothing appears in Errors.log. The symptom is
-- "the SQL applied but .additem fails".
--
-- So after applying this, run the deploy script exactly as 329_ did:
--
--   python Custom/Documentation/scripts/deploy_endgame_gear_dbc.py \
--          --rows <exported>.txt        # see the trailer for the export query
--
-- (its BLOCKS/EXPECTED constants need pointing at 420000-420429 first), then
-- copy the rebuilt `Custom/DBCs/Item.dbc` to the Linux server's dbc dir. The
-- script derives the CSV FROM the applied rows on purpose: `enforceDBCAttributes`
-- forces class/subclass/Material/displayid/InventoryType/sheath from the DBC, so
-- a hand-written CSV that disagrees silently wins and the item is subtly wrong.
--
-- Apply against acore_world. Idempotent (DELETE before every INSERT).
-- Needs a worldserver restart.
-- ---------------------------------------------------------------------------

-- 🔴 NO `USE` STATEMENT ON PURPOSE. **Select acore_world in your client**
-- before running this. A `USE `acore_world`;` line here was fed back as the
-- literal token `acore_world` glued to the following comment --
--   SQL error 1064 ... near 'acore_world-- ------'
-- because the client's statement splitter lost the terminating semicolon. The
-- file itself was byte-clean (no BOM, LF, semicolon present); dropping the USE
-- removes the only construct that can produce that token. Every statement below
-- names its tables unqualified, so the client's selected schema is what counts.

-- ---------------------------------------------------------------------------
-- 1. Build the combination set
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_variety_stage`;
CREATE TABLE `dc_variety_stage` (
  `seq`      INT          NOT NULL AUTO_INCREMENT,
  `entry`    INT UNSIGNED NOT NULL DEFAULT 0,
  `band`     SMALLINT     NOT NULL,
  `quality`  TINYINT      NOT NULL,
  `cls`      TINYINT      NOT NULL,
  `subclass` TINYINT      NOT NULL,
  `invtype`  TINYINT      NOT NULL,
  `ilvl`     SMALLINT     NOT NULL,
  `reqlvl`   SMALLINT     NOT NULL,
  `budget`   INT          NOT NULL,
  `arch`     VARCHAR(8)   NOT NULL,
  `variant`  TINYINT      NOT NULL,
  `nm`       VARCHAR(120) NOT NULL,
  `displayid` INT UNSIGNED NOT NULL DEFAULT 0,
  `delay`    SMALLINT     NOT NULL DEFAULT 1000,
  `sheath`   TINYINT      NOT NULL DEFAULT 0,
  `material` TINYINT      NOT NULL DEFAULT -1,
  `grp`      VARCHAR(24)  NOT NULL,
  `rn`       INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`seq`),
  KEY `k_grp` (`grp`, `rn`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Cross-join of band x quality x piece. `piece` carries everything that varies
-- per slot, so the whole ladder is one INSERT.
INSERT INTO `dc_variety_stage`
  (`band`,`quality`,`cls`,`subclass`,`invtype`,`ilvl`,`reqlvl`,`budget`,
   `arch`,`variant`,`nm`,`delay`,`sheath`,`material`,`grp`)
SELECT
  b.`band`, q.`q`, p.`cls`, p.`sub`, p.`inv`,
  b.`base` + IF(q.`q` = 3, 8, 0) AS `ilvl`,
  LEAST(b.`t_hi`, GREATEST(b.`band`,
        ROUND(0.294 * (b.`base` + IF(q.`q` = 3, 8, 0)) - 6.1))) AS `reqlvl`,
  GREATEST(4, ROUND(0.00207 * POW(b.`base` + IF(q.`q` = 3, 8, 0), 2.13)
      * CASE WHEN p.`inv` IN (1,5,7,20) THEN 1.15
             WHEN p.`inv` IN (2,8,9,10,6,11,12,14,15,16,23,26) THEN 0.75
             ELSE 1.00 END
      * IF(q.`q` = 3, 1.00, 0.85))) AS `budget`,
  p.`arch`,
  IF(q.`q` = 3, 1, 0) AS `variant`,
  CONCAT(b.`pfx`, ' ', p.`noun`, IF(q.`q` = 3, CONCAT(' of the ', b.`sfx`), '')) AS `nm`,
  p.`delay`, p.`sheath`, p.`mat`,
  CONCAT(p.`cls`, '_', p.`sub`, '_', p.`inv`) AS `grp`
FROM (
            SELECT  80 AS `band`, 285 AS `base`,  90 AS `t_hi`, 'Shorewarden' AS `pfx`, 'Tides'   AS `sfx`
  UNION ALL SELECT  88, 315,  98, 'Ashenvale',   'Grove'
  UNION ALL SELECT  96, 355, 106, 'Felbound',    'Wilds'
  UNION ALL SELECT 104, 372, 115, 'Frostmantle', 'Everwinter'
  UNION ALL SELECT 113, 388, 128, 'Emberwood',   'Flame'
) b
CROSS JOIN (SELECT 2 AS `q` UNION ALL SELECT 3) q
CROSS JOIN (
  -- cloth (subclass 1). Chest is InventoryType 20 (robe) -- type 5 cloth chests
  -- barely exist, which is also why the display pool for 1/5 is only 34 deep.
            SELECT 4 AS `cls`, 1 AS `sub`,  1 AS `inv`, 'cloth'   AS `arch`, 'Cowl'          AS `noun`, 1000 AS `delay`, 0 AS `sheath`, 7 AS `mat`
  UNION ALL SELECT 4, 1,  3, 'cloth',   'Mantle',        1000, 0, 7
  UNION ALL SELECT 4, 1, 20, 'cloth',   'Robe',          1000, 0, 7
  UNION ALL SELECT 4, 1,  6, 'cloth',   'Cord',          1000, 0, 7
  UNION ALL SELECT 4, 1,  7, 'cloth',   'Leggings',      1000, 0, 7
  UNION ALL SELECT 4, 1,  8, 'cloth',   'Slippers',      1000, 0, 7
  UNION ALL SELECT 4, 1,  9, 'cloth',   'Bracers',       1000, 0, 7
  UNION ALL SELECT 4, 1, 10, 'cloth',   'Gloves',        1000, 0, 7
  -- leather (2)
  UNION ALL SELECT 4, 2,  1, 'leather', 'Helm',          1000, 0, 8
  UNION ALL SELECT 4, 2,  3, 'leather', 'Spaulders',     1000, 0, 8
  UNION ALL SELECT 4, 2,  5, 'leather', 'Vest',          1000, 0, 8
  UNION ALL SELECT 4, 2,  6, 'leather', 'Belt',          1000, 0, 8
  UNION ALL SELECT 4, 2,  7, 'leather', 'Legguards',     1000, 0, 8
  UNION ALL SELECT 4, 2,  8, 'leather', 'Boots',         1000, 0, 8
  UNION ALL SELECT 4, 2,  9, 'leather', 'Wristguards',   1000, 0, 8
  UNION ALL SELECT 4, 2, 10, 'leather', 'Grips',         1000, 0, 8
  -- mail (3)
  UNION ALL SELECT 4, 3,  1, 'mail',    'Coif',          1000, 0, 6
  UNION ALL SELECT 4, 3,  3, 'mail',    'Shoulderguards',1000, 0, 6
  UNION ALL SELECT 4, 3,  5, 'mail',    'Hauberk',       1000, 0, 6
  UNION ALL SELECT 4, 3,  6, 'mail',    'Girdle',        1000, 0, 6
  UNION ALL SELECT 4, 3,  7, 'mail',    'Legguards',     1000, 0, 6
  UNION ALL SELECT 4, 3,  8, 'mail',    'Sabatons',      1000, 0, 6
  UNION ALL SELECT 4, 3,  9, 'mail',    'Armguards',     1000, 0, 6
  UNION ALL SELECT 4, 3, 10, 'mail',    'Gauntlets',     1000, 0, 6
  -- plate (4)
  UNION ALL SELECT 4, 4,  1, 'plate',   'Greathelm',     1000, 0, 1
  UNION ALL SELECT 4, 4,  3, 'plate',   'Pauldrons',     1000, 0, 1
  UNION ALL SELECT 4, 4,  5, 'plate',   'Breastplate',   1000, 0, 1
  UNION ALL SELECT 4, 4,  6, 'plate',   'Waistguard',    1000, 0, 1
  UNION ALL SELECT 4, 4,  7, 'plate',   'Legplates',     1000, 0, 1
  UNION ALL SELECT 4, 4,  8, 'plate',   'Warboots',      1000, 0, 1
  UNION ALL SELECT 4, 4,  9, 'plate',   'Vambraces',     1000, 0, 1
  UNION ALL SELECT 4, 4, 10, 'plate',   'Handguards',    1000, 0, 1
  -- shield (subclass 6). Without this Paladin/Warrior/Shaman are a slot short.
  UNION ALL SELECT 4, 6, 14, 'shield',  'Bulwark',       1000, 0,  1
  -- accessories: neck / back / finger / trinket (armour class 4, subclass 0/1)
  UNION ALL SELECT 4, 0,  2, 'misc',    'Choker',        1000, 0, -1
  UNION ALL SELECT 4, 1, 16, 'misc',    'Drape',         1000, 0,  7
  UNION ALL SELECT 4, 0, 11, 'misc',    'Signet',        1000, 0, -1
  UNION ALL SELECT 4, 0, 12, 'misc',    'Idol',          1000, 0, -1
  -- weapons: one per proficiency family so every class is served
  UNION ALL SELECT 2, 7, 13, 'wep_str', 'Blade',         2600, 3, -1
  UNION ALL SELECT 2, 4, 13, 'wep_str', 'Cudgel',        2600, 4, -1
  UNION ALL SELECT 2, 1, 17, 'wep_str', 'Greataxe',      3600, 1, -1
  UNION ALL SELECT 2,15, 13, 'wep_agi', 'Dirk',          1800, 3, -1
  UNION ALL SELECT 2, 2, 15, 'wep_agi', 'Longbow',       2900, 3, -1
  UNION ALL SELECT 2,10, 17, 'wep_int', 'Staff',         3600, 2, -1
) p;

-- ---------------------------------------------------------------------------
-- 2. Allocate entry ids and a per-slot rank
-- ---------------------------------------------------------------------------
-- 🔴 `rn` is the item's index WITHIN its slot group, and it is what makes the
-- ten items that share a slot pick ten DIFFERENT looks in step 3.
UPDATE `dc_variety_stage` s
JOIN (
  SELECT `seq`,
         420000 + ROW_NUMBER() OVER (ORDER BY `seq`) - 1 AS `new_entry`,
         ROW_NUMBER() OVER (PARTITION BY `grp` ORDER BY `band`, `quality`) AS `new_rn`
  FROM `dc_variety_stage`
) r ON r.`seq` = s.`seq`
SET s.`entry` = r.`new_entry`, s.`rn` = r.`new_rn`;

-- ---------------------------------------------------------------------------
-- 3. Borrow a real displayid per slot
-- ---------------------------------------------------------------------------
-- Ranked pool of existing looks for the same class/subclass/InventoryType.
-- Cloth chest draws from types 5 AND 20 (see the header).
UPDATE `dc_variety_stage` s
JOIN (
  SELECT `grp`, `displayid`, ROW_NUMBER() OVER (PARTITION BY `grp` ORDER BY `displayid`) AS `rn`
  FROM (
    SELECT DISTINCT CONCAT(i.`class`, '_', i.`subclass`, '_',
             IF(i.`class` = 4 AND i.`subclass` = 1 AND i.`InventoryType` = 5, 20, i.`InventoryType`)) AS `grp`,
           i.`displayid`
    FROM `item_template` i
    WHERE i.`displayid` > 0
      AND i.`Quality` BETWEEN 2 AND 4
      AND i.`ItemLevel` BETWEEN 60 AND 320
      AND i.`entry` < 400000            -- stock/imported looks only, not our own generated ranges
  ) d
) pool ON pool.`grp` = s.`grp` AND pool.`rn` = s.`rn`
SET s.`displayid` = pool.`displayid`;

-- Fallback: any slot whose pool ran short reuses the first look rather than
-- shipping displayid 0, which renders as the ErrorCube.
UPDATE `dc_variety_stage` s
JOIN (
  SELECT `grp`, MIN(`displayid`) AS `displayid`
  FROM (
    SELECT DISTINCT CONCAT(i.`class`, '_', i.`subclass`, '_',
             IF(i.`class` = 4 AND i.`subclass` = 1 AND i.`InventoryType` = 5, 20, i.`InventoryType`)) AS `grp`,
           i.`displayid`
    FROM `item_template` i
    WHERE i.`displayid` > 0 AND i.`Quality` BETWEEN 2 AND 4
      AND i.`ItemLevel` BETWEEN 60 AND 320 AND i.`entry` < 400000
  ) d GROUP BY `grp`
) f ON f.`grp` = s.`grp`
SET s.`displayid` = f.`displayid`
WHERE s.`displayid` = 0;

-- ---------------------------------------------------------------------------
-- 4. Create the items
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` BETWEEN 420000 AND 420499;

INSERT INTO `item_template`
  (`entry`,`class`,`subclass`,`name`,`displayid`,`Quality`,`Flags`,`BuyPrice`,`SellPrice`,
   `InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,
   `maxcount`,`stackable`,`Material`,`sheath`,`delay`,`bonding`,
   `stat_type1`,`stat_value1`,`stat_type2`,`stat_value2`,
   `stat_type3`,`stat_value3`,`stat_type4`,`stat_value4`)
SELECT
  s.`entry`, s.`cls`, s.`subclass`, s.`nm`, s.`displayid`, s.`quality`, 0,
  ROUND(POW(s.`ilvl`, 2) * IF(s.`quality` = 3, 9, 5)),
  ROUND(POW(s.`ilvl`, 2) * IF(s.`quality` = 3, 9, 5) / 5),
  s.`invtype`,
  -1,                                   -- 🔴 every class: these are variety drops,
  -1,                                   -- inheriting a class lock would defeat the point
  s.`ilvl`, s.`reqlvl`, 0, 1,
  s.`material`, s.`sheath`, s.`delay`,
  1,                                    -- bind on pickup
  a.`s1`, GREATEST(1, ROUND(s.`budget` * 0.32)),
  a.`s2`, GREATEST(1, ROUND(s.`budget` * 0.28)),
  a.`s3`, GREATEST(1, ROUND(s.`budget` * 0.23)),
  a.`s4`, GREATEST(1, ROUND(s.`budget` * 0.17))
FROM `dc_variety_stage` s
JOIN (
  -- 319_'s archetypes, pivoted so this derived table is read ONCE (319_ hit
  -- MySQL 1137 "Can't reopen table" by reading its temp table eleven times).
            SELECT 'cloth'   AS `arch`, 0 AS `variant`, 45 AS `s1`,  7 AS `s2`,  5 AS `s3`, 32 AS `s4`
  UNION ALL SELECT 'cloth',   1, 45,  7,  5,  6
  UNION ALL SELECT 'leather', 0, 38,  7,  3, 32
  UNION ALL SELECT 'leather', 1, 45,  7,  5, 36
  UNION ALL SELECT 'mail',    0, 38,  7,  3, 31
  UNION ALL SELECT 'mail',    1, 45,  7,  5, 32
  UNION ALL SELECT 'plate',   0,  4,  7, 32, 36
  UNION ALL SELECT 'plate',   1,  4,  7, 12, 13
  UNION ALL SELECT 'shield',  0,  7,  4, 12, 13
  UNION ALL SELECT 'shield',  1,  7,  5, 45,  6
  UNION ALL SELECT 'misc',    0,  7,  3, 38, 32
  UNION ALL SELECT 'misc',    1,  7,  5, 45, 32
  UNION ALL SELECT 'wep_str', 0,  4,  7, 32, 31
  UNION ALL SELECT 'wep_str', 1,  4,  7, 37, 36
  UNION ALL SELECT 'wep_agi', 0,  3,  7, 38, 32
  UNION ALL SELECT 'wep_agi', 1,  3,  7, 31, 36
  UNION ALL SELECT 'wep_int', 0, 45,  7,  5, 32
  UNION ALL SELECT 'wep_int', 1, 45,  7,  5, 36
) a ON a.`arch` = s.`arch` AND a.`variant` = s.`variant`;

-- ---------------------------------------------------------------------------
-- 5. Reference loot, one per band
-- ---------------------------------------------------------------------------
-- 🔴 Reference loot, NOT a row per creature. Attaching 84 items directly to every
-- creature in a band would add hundreds of thousands of `creature_loot_template`
-- rows; a reference is one row per creature instead.
--
-- The rows carry `GroupId = 1`, so the whole reference is ONE loot group: when it
-- is rolled, exactly one item comes out, chosen by relative weight. Greens are
-- weight 100 and blues 25, which makes a blue a quarter as likely as a green
-- rather than a separate roll. Whether the reference is rolled at all is the
-- creature's business, and that chance is set per rank in step 6.
DELETE FROM `reference_loot_template` WHERE `Entry` BETWEEN 752200 AND 752204;

INSERT INTO `reference_loot_template`
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT 752200 + CASE s.`band` WHEN 80 THEN 0 WHEN 88 THEN 1 WHEN 96 THEN 2
                              WHEN 104 THEN 3 ELSE 4 END,
       s.`entry`, 0,
       IF(s.`quality` = 3, 25, 100),   -- blues a quarter as common as greens
       0, 1, 1, 1, 1
FROM `dc_variety_stage` s;

-- ---------------------------------------------------------------------------
-- 6. Attach each band's reference to that band's creatures
-- ---------------------------------------------------------------------------
-- Scoped the same way 332_ scoped its retune: real combat creatures only, no
-- critters, no friendly/immune NPCs, and no script-trigger bunnies.
DELETE FROM `creature_loot_template`
WHERE `Reference` BETWEEN 752200 AND 752204;

INSERT INTO `creature_loot_template`
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT DISTINCT ct.`lootid`, 0,
  752200 + CASE bnd.`band` WHEN 80 THEN 0 WHEN 88 THEN 1 WHEN 96 THEN 2
                           WHEN 104 THEN 3 ELSE 4 END,
  -- rank drives how often the zone's new gear shows up
  CASE ct.`rank` WHEN 0 THEN 1.2 WHEN 1 THEN 6.0 WHEN 4 THEN 20.0
                 WHEN 2 THEN 35.0 WHEN 3 THEN 60.0 ELSE 1.2 END,
  0, 1, 0, 1, 1
FROM `creature_template` ct
JOIN (
  SELECT ct2.`entry`,
         COALESCE((SELECT MAX(bb.`t_lo`) FROM (SELECT DISTINCT `t_lo` FROM `dc_map750_band`) bb
                   WHERE bb.`t_lo` <= ct2.`minlevel`), 80) AS `band`
  FROM `creature_template` ct2
  WHERE ct2.`entry` BETWEEN 3600000 AND 3799999
) bnd ON bnd.`entry` = ct.`entry`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`minlevel` BETWEEN 80 AND 130
  AND ct.`lootid` > 0
  AND ct.`lootid` = ct.`entry`        -- 🔴 skip shared lootids: 322_ found lore NPCs
                                      -- sharing one lootid across 29,075 templates
  AND ct.`type` NOT IN (8, 11, 12)
  AND (ct.`unit_flags` & 258) = 0
  AND (ct.`flags_extra` & 128) = 0
  AND (ct.`unit_flags` & 33554432) = 0;

-- ---------------------------------------------------------------------------
-- Trailer -- verification, then the REQUIRED client step
-- ---------------------------------------------------------------------------
-- Expect 430 items, ids 420000-420429, no displayid 0, no duplicate look inside
-- a slot:
-- SELECT COUNT(*) AS items, MIN(entry), MAX(entry), SUM(displayid = 0) AS bad_display
-- FROM item_template WHERE entry BETWEEN 420000 AND 420499;
--
-- SELECT class, subclass, InventoryType, COUNT(*) AS n, COUNT(DISTINCT displayid) AS looks
-- FROM item_template WHERE entry BETWEEN 420000 AND 420499
-- GROUP BY class, subclass, InventoryType HAVING looks < n;   -- expect 0 rows
--
-- Coverage: every band must offer every armour class in every slot:
-- SELECT s.band, s.subclass, COUNT(*) FROM dc_variety_stage s
-- WHERE s.cls = 4 AND s.subclass BETWEEN 1 AND 4 GROUP BY s.band, s.subclass;
--   -- expect 16 per row (8 slots x 2 qualities)
--
-- How many creatures now roll the new loot, by band:
-- SELECT Reference, COUNT(*) AS creatures FROM creature_loot_template
-- WHERE Reference BETWEEN 752200 AND 752204 GROUP BY Reference;
--
-- 🔴 NOW THE CLIENT SIDE, or every one of these is silently discarded at load:
--   1) export the rows:
--      SELECT entry, class, subclass, Material, displayid, InventoryType, sheath
--      FROM item_template WHERE entry BETWEEN 420000 AND 420499 ORDER BY entry;
--   2) point deploy_endgame_gear_dbc.py's BLOCKS at [(420000, 420429)] and
--      EXPECTED at 430, then run it with --rows;
--   3) copy Custom/DBCs/Item.dbc to the Linux server's dbc dir and restart;
--   4) verify in game with `.additem 420000` -- NOT via the `item_dbc` table,
--      which is not a mirror of Item.dbc.
--
-- 🔴 Bump the client cache id afterwards or players keep the stale tooltip.
--
-- TO REMOVE ENTIRELY: the three DELETEs at the top of steps 4, 5 and 6 are the
-- complete uninstall; run them alone, then DROP TABLE dc_variety_stage.
-- ---------------------------------------------------------------------------
