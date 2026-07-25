-- =====================================================================
-- Mount Hyjal (map 750) -- 98  Zone consumables -> authentic 750 vendors
-- ---------------------------------------------------------------------
-- The branded 80-130 food/drink/potion line (item_template 400800-400823,
-- created by the Hyjal-Frontier set's 05c_Town_Vendor_Stock.sql and already
-- present live) was originally stocked ONLY on the superseded map-1410
-- vendors 830137/830139/830150/830152. This file wires the same consumables
-- onto the AUTHENTIC Cata "Guardians of Hyjal" vendors that actually spawn
-- on map 750, so leveling players can resupply at the real hubs.
--
-- Target vendors (all neutral Guardians-of-Hyjal, usable by both factions):
--   Food & drink : Sebelia (Innkeeper) 3640843, Edric Downing (Butcher) 3643565
--   General goods: Grunka 3643563, Jandunel Reedwind 3643493, Lenedil Moonwing
--                  3643411, Mirala Fawnsinger 3643547, Motah Tallhorn 3643555,
--                  Nenduil Meadowshade 3643551, Tomo 3643381
--
-- The food/drink (12) go on the two food vendors; the potions (12) go on
-- every general-goods vendor so resupply is available at each hub. slot=0
-- (auto-order) so we never collide with each vendor's existing stock; the
-- INSERT only touches items 400800-400823, leaving authentic stock intact.
--
-- *** PREREQUISITE (functionality) ***
-- Items 400800-400823 fire custom scaling spells 300550-300569 (food/drink
-- regen + potion heal/mana tuned to the inflated 80-130 pools). Those spells
-- exist client-side (Custom/CSV DBC/Spell.csv) but are NOT yet in server
-- `spell_dbc` (verified 0 rows), so the consumables are inert until ported.
-- Port them with the project spell generator (same path as 41/47/53/76):
--   gen_spell_dbc_sql.py --src Custom/CSV DBC/Spell.csv --ids 300550-300569
-- then apply its output before/with this file. This file is safe to apply
-- regardless (vendors just sell items whose on-use is a no-op until then).
--
-- Idempotent. Run on the world-DB host (acore_world).
-- =====================================================================

-- Drop only THIS file's rows (the 400800-400823 stock on the 9 vendors);
-- authentic vendor stock is preserved.
DELETE FROM `npc_vendor`
WHERE `entry` IN (3640843,3643565,3643563,3643493,3643411,3643547,3643555,3643551,3643381)
  AND `item` BETWEEN 400800 AND 400823;

-- ── Food & Drink vendors: all food/drink T1-T4 (400800-802 / 806-808 / 812-814 / 818-820)
INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT v.entry, 0, i.item, 0, 0, 0, 0
FROM (SELECT 3640843 AS entry UNION ALL SELECT 3643565) v
CROSS JOIN (
  SELECT 400800 AS item UNION ALL SELECT 400801 UNION ALL SELECT 400802
  UNION ALL SELECT 400806 UNION ALL SELECT 400807 UNION ALL SELECT 400808
  UNION ALL SELECT 400812 UNION ALL SELECT 400813 UNION ALL SELECT 400814
  UNION ALL SELECT 400818 UNION ALL SELECT 400819 UNION ALL SELECT 400820
) i;

-- ── General-goods vendors (7): all potions T1-T4 (400803-805 / 809-811 / 815-817 / 821-823)
INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT v.entry, 0, i.item, 0, 0, 0, 0
FROM (
  SELECT 3643563 AS entry UNION ALL SELECT 3643493 UNION ALL SELECT 3643411
  UNION ALL SELECT 3643547 UNION ALL SELECT 3643555 UNION ALL SELECT 3643551
  UNION ALL SELECT 3643381
) v
CROSS JOIN (
  SELECT 400803 AS item UNION ALL SELECT 400804 UNION ALL SELECT 400805
  UNION ALL SELECT 400809 UNION ALL SELECT 400810 UNION ALL SELECT 400811
  UNION ALL SELECT 400815 UNION ALL SELECT 400816 UNION ALL SELECT 400817
  UNION ALL SELECT 400821 UNION ALL SELECT 400822 UNION ALL SELECT 400823
) i;
