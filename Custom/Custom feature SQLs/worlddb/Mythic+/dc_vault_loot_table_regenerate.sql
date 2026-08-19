-- =====================================================================
-- dc_vault_loot_table - regenerate the three WotLK tiers
-- =====================================================================
-- Apply against: acore_world.  Run AFTER dc_vault_loot_table_repair.sql
-- or instead of it - this file replaces every WotLK row outright, so the
-- tagging fixes in that file only matter if you want to keep the curated
-- list. Safe to re-run.
--
-- WHY
-- ---------------------------------------------------------------------
-- The 255 hand-authored WotLK rows were built by walking a contiguous
-- item id range alongside a list of tier token names, and the two lists
-- drifted apart: 190 of 255 rows pointed at an item that was not the one
-- their own source note named, 6 pointed at no item at all, and several
-- notes matched no item in the database, so the ids could not be
-- recovered from the notes either.
--
-- The 430 tier, which was generated rather than hand-written, had no
-- defects at all. So this file rebuilds the WotLK tiers the same way.
--
-- Everything is derived from item_template, which is authoritative:
--
--   class_mask   <- AllowableClass, or 1023 when the item has no class
--                   restriction. 1023 is the sentinel fetchCandidates
--                   tests for, and it is matched by its own OR branch,
--                   so druids reach it even though 1024 is not inside
--                   1023.
--   armor_type   <- subclass, except necks, rings, trinkets, cloaks and
--                   all weapons, which become 'Misc' so every class can
--                   roll them. Tagging a cloak 'Cloth' from its subclass
--                   would hand every cloak to clothies only.
--   slot_type    <- InventoryType
--   role_mask    <- the stat block: defense, dodge, parry or block means
--                   tank; spell power plus spirit or mp5 means healer;
--                   otherwise an offensive stat means dps; 7 when
--                   nothing matches.
--   spec_name    <- NULL throughout. class_mask, role_mask and
--                   armor_type already pin a reward to the right player.
--                   Naming the spec on top of that only creates the
--                   mismatches that starved feral druids ('Feral' in the
--                   table vs 'Feral Combat' from GetPlayerSpec) and
--                   discipline priests (priest healer rows tagged
--                   'Holy' only).
--
-- Only epics that actually drop from a creature are eligible, so the
-- vault hands out real raid and dungeon gear rather than any epic that
-- happens to sit at the right item level. PvP gear is excluded via its
-- resilience stat.
--
-- TIERS
-- ---------------------------------------------------------------------
-- GetItemLevelForKeystoneLevel() asks for 226, 239, 252, 264, 277, 290
-- and 303. MythicPlus.Vault.Raid.ItemLevel and .PvP.ItemLevel ask for
-- 264. The bands below are disjoint, so each of those targets lands in
-- exactly one tier. The old bands all ended at 310, which let a +20 key
-- roll ilvl 213 gear.
--
--   band     serves targets          holds real item levels
--   226-245  226, 239  (+2..+4)      213-226   Naxx / Ulduar entry
--   246-264  252, 264  (+5..+11)     232-251   Ulduar / ToC
--   265-310  277, 290, 303 (+12..)   258-284   ToGC / ICC
--
-- Retune by editing the six numbers in the tier list below. Nothing else
-- in this file depends on them.
--
-- The 430-470 tier is left untouched because it was already clean. Note
-- that no current target reaches it, so it stays unreachable until a key
-- level or a Raid/PvP.ItemLevel config lands above 310.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Replace the three WotLK tiers. The 430 tier is deliberately kept.
-- ---------------------------------------------------------------------
DELETE FROM `dc_vault_loot_table`
WHERE `item_level_min` IN (226, 239, 246, 252, 264, 265);

INSERT INTO `dc_vault_loot_table`
    (`item_id`, `item_level_min`, `item_level_max`, `class_mask`, `spec_name`,
     `armor_type`, `slot_type`, `role_mask`, `weight`, `source`)
SELECT DISTINCT
    i.`entry`,
    tier.band_min,
    tier.band_max,
    CASE WHEN i.`AllowableClass` < 0 THEN 1023 ELSE i.`AllowableClass` END,
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
      WHEN 15 THEN 'Ranged'   WHEN 25 THEN 'Ranged'   WHEN 26 THEN 'Ranged'
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
    CONCAT('generated - ilvl ', i.`ItemLevel`)
FROM `item_template` i
JOIN (SELECT `Item` FROM `creature_loot_template`
      UNION
      SELECT `Item` FROM `reference_loot_template`) AS drops
  ON drops.`Item` = i.`entry`
JOIN (          SELECT 226 AS band_min, 245 AS band_max, 213 AS ilvl_lo, 226 AS ilvl_hi
      UNION ALL SELECT 246,             264,             232,            251
      UNION ALL SELECT 265,             310,             258,            284) AS tier
  ON i.`ItemLevel` BETWEEN tier.ilvl_lo AND tier.ilvl_hi
WHERE i.`Quality` = 4
  AND i.`class` IN (2, 4)
  AND i.`entry` <= 56806
  AND i.`RequiredLevel` >= 70
  AND i.`InventoryType` IN (1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,20,21,22,23,25,26)
  AND i.`name` NOT LIKE '%Test%'
  AND i.`name` NOT LIKE '%[PH]%'
  AND i.`name` NOT LIKE '%Deprecated%'
  AND i.`name` NOT LIKE '%OLD%'
  AND NOT 35 IN (i.`stat_type1`,i.`stat_type2`,i.`stat_type3`,i.`stat_type4`,i.`stat_type5`,i.`stat_type6`,i.`stat_type7`,i.`stat_type8`,i.`stat_type9`,i.`stat_type10`);


-- =====================================================================
-- Verification
-- =====================================================================
-- Expected shape after applying, measured against the current world DB:
--
--   band 226-245  ~772 rows
--   band 246-264  ~964 rows
--   band 265-310  ~705 rows
--   band 430-470   108 rows, unchanged
--
-- Every armour type carries every role it should, tanks included:
--
--   SELECT item_level_min, armor_type, role_mask, COUNT(*)
--   FROM dc_vault_loot_table
--   GROUP BY item_level_min, armor_type, role_mask
--   ORDER BY item_level_min, armor_type, role_mask;
--
--   -> Plate with role_mask 1 is present in all three WotLK bands. The
--      old 239 band had none at all, which is why Protection Warrior,
--      Protection Paladin and Blood Death Knight were handed a token on
--      every +2 to +4 key.
--
-- No row may point at a missing or non-gear item (expect 0 rows):
--
--   SELECT t.item_id FROM dc_vault_loot_table t
--   LEFT JOIN item_template i ON i.entry = t.item_id
--   WHERE i.entry IS NULL OR i.class NOT IN (2, 4);
--
-- No row may contradict the item's own AllowableClass (expect 0 rows):
--
--   SELECT t.item_id FROM dc_vault_loot_table t
--   JOIN item_template i ON i.entry = t.item_id
--   WHERE t.class_mask <> 1023 AND i.AllowableClass <> -1
--     AND (i.AllowableClass & t.class_mask) = 0;
--
-- Bands must stay disjoint, or a high key can roll low-tier gear:
--
--   SELECT DISTINCT item_level_min, item_level_max
--   FROM dc_vault_loot_table ORDER BY item_level_min;
-- =====================================================================
