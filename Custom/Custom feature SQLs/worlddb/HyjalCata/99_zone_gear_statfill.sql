-- =====================================================================
-- Mount Hyjal (map 750) + Molten Front (map 861) -- 99  Zone gear stat-fill
-- ---------------------------------------------------------------------
-- The mass item-downport shipped Cata armor/weapons as APPEARANCE-ONLY shells
-- (correct name/icon/model/InventoryType, but ItemLevel=0, RequiredLevel=1, all
-- stats/armor/damage = 0). This restores the AUTHENTIC Cata primary stats to the
-- exact shells that DROP in this zone -- so real Cata items (real names + icons)
-- become equippable leveling gear. Self-scoped: only fills class 2/4 empty shells
-- that a map-750 (Hyjal) or map-861 (Molten Front) creature actually drops
-- (~625 on Hyjal alone; MF adds more once MoltenFront/ is applied).
--
-- Source of truth: nelt_world.`db_item-sparse_15595` (the Cata build-15595
-- ItemSparse, ID = item entry, real Stat_Type/Value 1..10 + Itemlevel + Quality
-- + Requiredlevel + Delay). Cata stat-type ids that 3.3.5 doesn't implement
-- (e.g. mastery 49) are copied verbatim and simply ignored by the core -- harmless.
--
-- CORRECTION: Cata's ItemSparse uses -1 as the "empty stat slot" sentinel, but
-- this fork's item_template.stat_typeN is `tinyint unsigned` -- MySQL 8 strict
-- mode rejects a negative value into an unsigned column outright ("Out of range
-- value for column 'stat_type1'") rather than truncating it, so the UPDATE below
-- failed on first use (610 of the 625 target items carry a -1 in at least one
-- slot). -1 -> 0, the stock "no stat" value AzerothCore already uses, via IF().
--
-- PHASE 1 (this file): stats / ItemLevel / Quality / RequiredLevel / delay.
-- PHASE 2 (separate, offline generator): `armor` and `dmg_min1/dmg_max1` are NOT
-- stored in Cata's item data -- they are DERIVED from ItemLevel+Quality+slot via
-- the Cata ItemArmor*/ItemDamage* DBCs. Until the generator runs, armor shows 0
-- and weapons deal 0 damage. See notes at the bottom.
--
-- RequiredLevel is the authentic Cata value (80-85); the 80-130 SPREAD is applied
-- by the level-bands pass (retunes mobs + their gear together), not here.
--
-- Only touches rows that are STILL empty shells (guarded) -- never overwrites an
-- item that already has real stats. Idempotent / re-runnable.
-- =====================================================================

UPDATE acore_world.item_template it
JOIN nelt_world.`db_item-sparse_15595` s ON s.ID = it.entry
SET
  it.stat_type1=IF(s.Stat_Type1<0,0,s.Stat_Type1),   it.stat_value1=IF(s.Stat_Type1<0,0,s.Stat_Value1),
  it.stat_type2=IF(s.Stat_Type2<0,0,s.Stat_Type2),   it.stat_value2=IF(s.Stat_Type2<0,0,s.Stat_Value2),
  it.stat_type3=IF(s.Stat_Type3<0,0,s.Stat_Type3),   it.stat_value3=IF(s.Stat_Type3<0,0,s.Stat_Value3),
  it.stat_type4=IF(s.Stat_Type4<0,0,s.Stat_Type4),   it.stat_value4=IF(s.Stat_Type4<0,0,s.Stat_Value4),
  it.stat_type5=IF(s.Stat_Type5<0,0,s.Stat_Type5),   it.stat_value5=IF(s.Stat_Type5<0,0,s.Stat_Value5),
  it.stat_type6=IF(s.Stat_Type6<0,0,s.Stat_Type6),   it.stat_value6=IF(s.Stat_Type6<0,0,s.Stat_Value6),
  it.stat_type7=IF(s.Stat_Type7<0,0,s.Stat_Type7),   it.stat_value7=IF(s.Stat_Type7<0,0,s.Stat_Value7),
  it.stat_type8=IF(s.Stat_Type8<0,0,s.Stat_Type8),   it.stat_value8=IF(s.Stat_Type8<0,0,s.Stat_Value8),
  it.stat_type9=IF(s.Stat_Type9<0,0,s.Stat_Type9),   it.stat_value9=IF(s.Stat_Type9<0,0,s.Stat_Value9),
  it.stat_type10=IF(s.Stat_Type10<0,0,s.Stat_Type10), it.stat_value10=IF(s.Stat_Type10<0,0,s.Stat_Value10),
  it.ItemLevel=s.Itemlevel,
  it.Quality=s.Quality,
  it.RequiredLevel=s.Requiredlevel,
  it.delay=s.Delay
WHERE it.class IN (2,4) AND it.InventoryType>0
  AND it.armor=0 AND it.dmg_min1=0
  AND it.stat_value1=0 AND it.stat_value2=0 AND it.stat_value3=0
  AND it.entry IN (
    SELECT item FROM (
      SELECT DISTINCT lt.item
      FROM acore_world.creature_loot_template lt
      WHERE lt.Entry IN (
        SELECT DISTINCT ct.lootid FROM acore_world.creature_template ct
        WHERE ct.lootid>0 AND ct.entry IN (
          SELECT DISTINCT id FROM acore_world.creature WHERE map IN (750,861)))
    ) z
  );

-- ---------------------------------------------------------------------
-- PHASE 2 (offline, separate) -- derive armor + weapon damage from the Cata
-- DBC curves (NOT stored in any item table). Inputs are in the Cata client at
-- K:\UntouchedClients\Cata\Data (extract with mpq_stormlib_extract.py):
--   Armor : ItemArmorQuality.dbc x ItemArmorTotal.dbc x ItemArmorShield.dbc,
--           scaled by InventoryType (armor location) + armor subclass.
--   Weapon: ItemDamage{OneHand,TwoHand,OneHandCaster,TwoHandCaster,Ranged,
--           Wand,Thrown}.dbc -> dps[Itemlevel][Quality];
--           dmg_min/max = dps * (delay/1000) * (1 -/+ variance).
-- A `gen_zone_gear_armor_dmg.py` (reads those DBCs + this zone's filled items ->
-- emits UPDATEs for armor / dmg_min1 / dmg_max1 / dmg_type1) is the clean path.
-- Run it AFTER this file.
-- ---------------------------------------------------------------------
