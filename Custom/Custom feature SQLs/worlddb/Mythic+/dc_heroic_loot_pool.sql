-- =====================================================================
-- dc_heroic_loot_pool - the shared Heroic/Mythic dungeon gear pool
-- =====================================================================
-- Apply against: acore_world. Safe to re-run (full rebuild).
--
-- WHY
-- ---------------------------------------------------------------------
-- Classic and TBC dungeons have no heroic creature templates at all:
-- 0 of ~700 Vanilla creature templates carry difficulty_entry_1, so a
-- Heroic or Mythic run of Deadmines rolls the same ilvl 15-25 greens as
-- the level-17 Normal run. TBC dungeons do fork, but their heroic tables
-- cap at ilvl 115. Meanwhile dc_dungeon_mythic_profile.loot_ilvl has
-- carried a hand-tuned 198-239 value per dungeon that nothing ever read.
--
-- This table is the pool those dungeons draw from. It mirrors the
-- dc_vault_loot_table schema on purpose: the Mythic+ loot generator
-- already has a five-stage class/spec/armor/role filter built against
-- that shape, and LoadLootTable() now UNIONs both tables so one
-- selection engine serves ilvl 200 through 470.
--
-- It is a SEPARATE table rather than extra rows in dc_vault_loot_table
-- because the Great Vault reads that table directly and must not start
-- handing out ilvl 200 gear.
--
-- DERIVATION - everything comes from item_template, which is
-- authoritative. Same rules as dc_vault_loot_table_regenerate.sql:
--
--   class_mask  <- AllowableClass when it actually restricts the item;
--                  otherwise derived from the weapon/relic/shield
--                  subclass, since item_template does not model skill
--                  lines and leaves every gun, bow, thrown, crossbow,
--                  wand and shield at these tiers unrestricted. Armour
--                  stays 1023 and is gated by armor_type instead, which
--                  is what dc_vault_loot_table already does. 1023 is the
--                  sentinel TrySelectLootItem tests for, and druids
--                  reach it through the 512-bit bridge in that function
--                  (which is also why druid-only rows use 1536, not
--                  1024).
--   armor_type  <- subclass, EXCEPT necks, rings, trinkets, cloaks and
--                  all weapons, which become 'Misc' so every class can
--                  roll them. A cloak is subclass 1 (Cloth) in
--                  item_template; tagging it 'Cloth' from its subclass
--                  hands every cloak at this tier to clothies only.
--   slot_type   <- InventoryType. Note 28 (relic) maps to 'Ranged',
--                  which is the slot librams/idols/totems/sigils
--                  actually occupy in 3.3.5.
--   role_mask   <- the stat block: defense/dodge/parry/block = tank;
--                  spell power plus spirit or mp5 = healer; otherwise an
--                  offensive stat = dps; 7 when nothing matches.
--   spec_name   <- NULL throughout, same reasoning as the vault table:
--                  class_mask + role_mask + armor_type already pin a
--                  reward to the right player, and naming the spec on
--                  top only recreates the 'Feral' vs 'Feral Combat'
--                  mismatch that starved feral druids there.
--
-- Unlike the vault regenerate file this does NOT require the item to
-- already drop from a creature. That join is exactly what kept the
-- reachable pool at 189 items: emblem-vendor, crafted and quest-reward
-- gear at ilvl 200 is unreferenced by any loot table, and it is
-- precisely that gear which fills the holes (relics, cloth shoulders,
-- 2H swords, guns, thrown, off-hands). Junk is excluded by the
-- name/quality/stat filters below instead.
--
-- TIERS
-- ---------------------------------------------------------------------
-- The C++ side asks for clamp(dc_dungeon_mythic_profile.loot_ilvl,
-- 200, 219). Bands are disjoint so each target lands in exactly one.
--
--   band     serves loot_ilvl        holds real item levels
--   200-207  198-207                 200            Heroic dungeon tier
--   208-214  208-214                 200 + 213      Naxx10 / early raid
--   215-219  215-239 (clamped)       213 + 219      Ulduar10 / Naxx25
--
-- Retune by editing the six numbers in the tier list below; nothing else
-- in this file depends on them.
-- =====================================================================

DROP TABLE IF EXISTS `dc_heroic_loot_pool`;

CREATE TABLE `dc_heroic_loot_pool` (
  `item_id` INT UNSIGNED NOT NULL,
  `item_level_min` SMALLINT UNSIGNED NOT NULL DEFAULT 200,
  `item_level_max` SMALLINT UNSIGNED NOT NULL DEFAULT 219,
  `class_mask` INT UNSIGNED NOT NULL DEFAULT 0,
  `spec_name` VARCHAR(50) NULL DEFAULT NULL,
  `armor_type` ENUM('Cloth','Leather','Mail','Plate','Misc') NOT NULL DEFAULT 'Misc',
  `slot_type` ENUM('Head','Neck','Shoulder','Back','Chest','Wrist','Hands','Waist','Legs','Feet','Finger','Trinket','Weapon','Shield','Offhand','Ranged') NOT NULL DEFAULT 'Weapon',
  `role_mask` TINYINT UNSIGNED NOT NULL DEFAULT 7,
  `weight` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  `source` VARCHAR(100) NULL DEFAULT NULL,
  PRIMARY KEY (`item_id`, `item_level_min`),
  KEY `idx_band` (`item_level_min`, `item_level_max`),
  KEY `idx_class` (`class_mask`),
  KEY `idx_armor` (`armor_type`),
  KEY `idx_role` (`role_mask`)
-- COLLATE is explicit and must stay that way. A bare "DEFAULT CHARSET=utf8mb4"
-- resolves to utf8mb4_0900_ai_ci on MySQL 8, while every other table in this
-- schema (dc_vault_loot_table, item_template) is utf8mb4_unicode_ci. Comparing
-- or combining the text columns across the two collations raises errno 1271,
-- "illegal mix of collations".
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Shared Heroic/Mythic dungeon gear pool (ilvl 200-219)';

DELETE FROM `dc_heroic_loot_pool`;

INSERT INTO `dc_heroic_loot_pool`
    (`item_id`, `item_level_min`, `item_level_max`, `class_mask`, `spec_name`,
     `armor_type`, `slot_type`, `role_mask`, `weight`, `source`)
SELECT DISTINCT
    i.`entry`,
    tier.band_min,
    tier.band_max,
    CASE
      -- item_template wins whenever it actually restricts the item.
      -- 1535 is all ten class bits; -1/32767/262143 mean the same thing.
      WHEN i.`AllowableClass` > 0 AND i.`AllowableClass` < 1535 THEN i.`AllowableClass`
      -- Shields and relics: the equip slot is class-specific, but
      -- item_template leaves AllowableClass unrestricted on all 25
      -- shields and 18 of the 29 relics, and both tag as armor_type
      -- 'Misc', so class_mask is the only gate they have. Without these
      -- branches a mage wins shields and a warrior wins druid idols.
      WHEN i.`class` = 4 AND i.`subclass` = 6  THEN 67    -- Shield: war/pal/sha
      WHEN i.`class` = 4 AND i.`subclass` = 7  THEN 2     -- Libram: paladin
      WHEN i.`class` = 4 AND i.`subclass` = 8  THEN 1536  -- Idol:   druid (1024|512 bridge)
      WHEN i.`class` = 4 AND i.`subclass` = 9  THEN 64    -- Totem:  shaman
      WHEN i.`class` = 4 AND i.`subclass` = 10 THEN 32    -- Sigil:  death knight
      -- Weapons: usable classes come from the skill line, which
      -- item_template does not model at all. Every gun, bow, thrown,
      -- crossbow and wand at these item levels is unrestricted here.
      WHEN i.`class` = 2 AND i.`subclass` IN (0, 1)         THEN 103   -- axes
      WHEN i.`class` = 2 AND i.`subclass` IN (2, 3, 16, 18) THEN 13    -- ranged: war/hun/rog
      WHEN i.`class` = 2 AND i.`subclass` = 4  THEN 1659  -- 1H mace
      WHEN i.`class` = 2 AND i.`subclass` = 5  THEN 1635  -- 2H mace
      WHEN i.`class` = 2 AND i.`subclass` = 6  THEN 1575  -- polearm
      WHEN i.`class` = 2 AND i.`subclass` = 7  THEN 431   -- 1H sword
      WHEN i.`class` = 2 AND i.`subclass` = 8  THEN 39    -- 2H sword
      WHEN i.`class` = 2 AND i.`subclass` = 10 THEN 2005  -- staff
      WHEN i.`class` = 2 AND i.`subclass` = 13 THEN 1613  -- fist
      WHEN i.`class` = 2 AND i.`subclass` = 15 THEN 2013  -- dagger
      WHEN i.`class` = 2 AND i.`subclass` = 19 THEN 400   -- wand: pri/mag/wlk
      -- Armour keeps the vault table's proven behaviour: open to every
      -- class here, gated by armor_type instead.
      ELSE 1023
    END,
    NULL,
    CASE
      WHEN i.`class` = 2 THEN 'Misc'
      WHEN i.`InventoryType` IN (2, 11, 12, 16) THEN 'Misc'
      WHEN i.`subclass` = 1 THEN 'Cloth'
      WHEN i.`subclass` = 2 THEN 'Leather'
      WHEN i.`subclass` = 3 THEN 'Mail'
      WHEN i.`subclass` = 4 THEN 'Plate'
      ELSE 'Misc'
    END,
    CASE i.`InventoryType`
      WHEN 1  THEN 'Head'     WHEN 2  THEN 'Neck'     WHEN 3  THEN 'Shoulder'
      WHEN 5  THEN 'Chest'    WHEN 20 THEN 'Chest'    WHEN 6  THEN 'Waist'
      WHEN 7  THEN 'Legs'     WHEN 8  THEN 'Feet'     WHEN 9  THEN 'Wrist'
      WHEN 10 THEN 'Hands'    WHEN 11 THEN 'Finger'   WHEN 12 THEN 'Trinket'
      WHEN 16 THEN 'Back'     WHEN 14 THEN 'Shield'   WHEN 23 THEN 'Offhand'
      WHEN 22 THEN 'Offhand'  WHEN 15 THEN 'Ranged'   WHEN 25 THEN 'Ranged'
      WHEN 26 THEN 'Ranged'   WHEN 28 THEN 'Ranged'
      ELSE 'Weapon'
    END,
    CASE
      WHEN 12 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`)
           OR 13 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`)
           OR 14 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`)
           OR 15 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`)
           THEN 1
      WHEN 45 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`)
           AND (6 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`)
                OR 43 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`))
           THEN 2
      WHEN 3 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`)
           OR 4 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`)
           OR 38 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`)
           OR 44 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`)
           OR 45 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`)
           THEN 4
      ELSE 7
    END,
    100,
    CONCAT('generated - ilvl ', i.`ItemLevel`, ' q', i.`Quality`)
FROM `item_template` i
JOIN (          SELECT 200 AS band_min, 207 AS band_max, 200 AS ilvl_lo, 200 AS ilvl_hi
      UNION ALL SELECT 208,             214,             200,            213
      UNION ALL SELECT 215,             219,             213,            219) AS tier
  ON i.`ItemLevel` BETWEEN tier.ilvl_lo AND tier.ilvl_hi
WHERE i.`Quality` IN (3, 4)
  AND i.`class` IN (2, 4)
  AND i.`entry` <= 56806
  AND i.`RequiredLevel` >= 78
  AND i.`InventoryType` IN (1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,20,21,22,23,25,26,28)
  AND i.`name` NOT LIKE '%Test%'
  AND i.`name` NOT LIKE '%[PH]%'
  AND i.`name` NOT LIKE '%Deprecated%'
  AND i.`name` NOT LIKE '%OLD%'
  AND i.`name` NOT LIKE 'NPC Equip %'
  -- Statless placeholders are excluded, but relics (class 4, subclass
  -- 7-10: Libram/Idol/Totem/Sigil) legitimately carry no stat block at
  -- all - every one of the 29 at ilvl 200 has stat_value1 = 0. Without
  -- this exemption the filter drops all of them and re-opens the single
  -- largest hole in the old pool: four classes with an empty relic slot.
  AND (i.`stat_value1` > 0 OR i.`class` = 2
       OR (i.`class` = 4 AND i.`subclass` BETWEEN 7 AND 10))
  AND NOT 35 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`);

-- =====================================================================
-- Verification
-- =====================================================================
-- Row counts per band. A band under ~150 rows means the filters are too
-- tight and the five-stage fallback will start handing out off-spec
-- gear:
--
--   SELECT item_level_min, item_level_max, COUNT(*)
--   FROM dc_heroic_loot_pool GROUP BY item_level_min, item_level_max;
--
-- The gaps this table exists to close. Each of these was 0 in the
-- 189-item pool reachable from WotLK heroic dungeons, and must now be
-- non-zero:
--
--   SELECT slot_type, armor_type, COUNT(*) FROM dc_heroic_loot_pool
--   WHERE item_level_min = 200
--     AND (slot_type = 'Ranged'
--          OR (slot_type = 'Shoulder' AND armor_type = 'Cloth')
--          OR slot_type IN ('Offhand', 'Shield'))
--   GROUP BY slot_type, armor_type;
--
-- Every armour type must carry every role, tanks included, or the
-- protection specs get nothing but fallback rolls:
--
--   SELECT item_level_min, armor_type, role_mask, COUNT(*)
--   FROM dc_heroic_loot_pool GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;
--
-- No row may point at a missing or non-gear item (expect 0 rows):
--
--   SELECT p.item_id FROM dc_heroic_loot_pool p
--   LEFT JOIN item_template i ON i.entry = p.item_id
--   WHERE i.entry IS NULL OR i.class NOT IN (2, 4);
--
-- No row may contradict the item's own AllowableClass (expect 0 rows):
--
--   SELECT p.item_id FROM dc_heroic_loot_pool p
--   JOIN item_template i ON i.entry = p.item_id
--   WHERE p.class_mask <> 1023 AND i.AllowableClass <> -1
--     AND (i.AllowableClass & p.class_mask) = 0;
--
-- Item overlap with dc_vault_loot_table is EXPECTED, not a fault: the
-- vault's lowest band (226-245) deliberately holds real ilvl 213-226
-- gear, and the 208-214 / 215-219 bands here hold 213 and 219 too. About
-- 822 rows overlap on that basis. What must hold is that the BAND ranges
-- stay disjoint - heroic tops out at 219, the vault starts at 226 - so no
-- single target item level ever draws from both tables:
--
--   SELECT DISTINCT item_level_min, item_level_max FROM dc_heroic_loot_pool
--   UNION ALL
--   SELECT DISTINCT item_level_min, item_level_max FROM dc_vault_loot_table
--   ORDER BY 1;
--
-- The check that actually matters is that no ilvl 200 item reached the
-- vault, which would let the Great Vault pay out heroic-tier gear
-- (expect 0):
--
--   SELECT COUNT(*) FROM dc_vault_loot_table v
--   JOIN item_template i ON i.entry = v.item_id WHERE i.ItemLevel < 213;
-- =====================================================================
