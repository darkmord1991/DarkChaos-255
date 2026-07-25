-- =====================================================================
-- Molten Front -- 12  Quartermaster stock (the empty-vendor fix) + token spend side
-- ---------------------------------------------------------------------
-- SYMPTOM (live play test): the three Molten Front quartermasters standing at the
-- portal camp are flagged as vendors and open a vendor window, but it is EMPTY.
-- Confirmed by query: all three have ZERO `npc_vendor` rows, while both source DBs
-- carry their full authentic lists. They were the ONLY vendors missing stock across
-- maps 750 + 861 (map 750's were backfilled by the earlier vendor-backfill pass):
--     3653881  Ayla Shadowstorm    "Treasures of Elune"        src has 12 items
--     3653214  Damek Bloombeard    "Exceptional Equipment"     src has 19 items
--     3653882  Varlan Highbough    "Provisions of the Grove"   src has 10 items
--
-- Of those 41 authentic vendor lines, 20 items exist here as downported
-- appearance-only shells (real name/icon/model/InventoryType, all ilvl-365 epics)
-- and are stocked below. The other 21 are DELIBERATELY NOT ported -- reasons in the
-- SKIPPED section at the bottom -- because each would ship a visibly broken item.
--
-- PRICING: sold for Emberwood Sap (item 400000) via itemextendedcost 14102 (30 sap)
-- / 14103 (50 sap, trinkets). This completes the token "SPEND side" that
-- HyjalCata/100_ explicitly left as a TODO, and wires the Molten Front into the
-- zone token economy exactly as planned (MF is not a silo).
--   !! CLIENT DBC PREREQUISITE -- ALREADY DONE, no action needed: the client's
--      ItemExtendedCost.dbc topped out at ID 3005 and did NOT contain 14100-14103,
--      even though the server table did. A vendor line whose ExtendedCost has no
--      client row cannot render its price. Rows 14100-14103 have been added to
--      Custom/CSV DBC/ItemExtendedCost.csv, recompiled, and packed into BOTH
--      patch-4.MPQ and enGB/patch-enGB-3.MPQ (+ synced to the host runtime paths).
--      Nothing live was broken by this before now: the only two vendors already
--      using 14100-14103 sit on the SUPERSEDED map 1410 and are unreachable.
--
-- Idempotent / re-runnable. Requires a worldserver restart (or `.reload
-- npc_vendor` + `.reload item_template`) to take effect.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Stat-fill the 20 vendor items.
--    HyjalCata/99_ only fills shells that a map-750/861 creature DROPS, so
--    vendor-ONLY items were never touched by it and would have gone on sale as
--    ilvl-0 / RequiredLevel-1 / all-zero-stat shells. Same source + same -1
--    sentinel handling as 99_ (Cata ItemSparse uses -1 for "empty stat slot",
--    which MySQL 8 strict mode refuses to write into an unsigned column).
--    Guarded to still-empty shells only -- never overwrites real stats.
--    NOTE `armor` / `dmg_min1` stay 0 here exactly as in 99_; they come from the
--    Phase-2 offline generator (gen_zone_gear_armor_dmg.py), which now also needs
--    to cover these 20 entries.
-- ---------------------------------------------------------------------
UPDATE acore_world.item_template it
JOIN nelt_world.`db_item-sparse_15595` s ON s.ID = it.entry
SET
  it.stat_type1=IF(s.Stat_Type1<0,0,s.Stat_Type1),    it.stat_value1=IF(s.Stat_Type1<0,0,s.Stat_Value1),
  it.stat_type2=IF(s.Stat_Type2<0,0,s.Stat_Type2),    it.stat_value2=IF(s.Stat_Type2<0,0,s.Stat_Value2),
  it.stat_type3=IF(s.Stat_Type3<0,0,s.Stat_Type3),    it.stat_value3=IF(s.Stat_Type3<0,0,s.Stat_Value3),
  it.stat_type4=IF(s.Stat_Type4<0,0,s.Stat_Type4),    it.stat_value4=IF(s.Stat_Type4<0,0,s.Stat_Value4),
  it.stat_type5=IF(s.Stat_Type5<0,0,s.Stat_Type5),    it.stat_value5=IF(s.Stat_Type5<0,0,s.Stat_Value5),
  it.stat_type6=IF(s.Stat_Type6<0,0,s.Stat_Type6),    it.stat_value6=IF(s.Stat_Type6<0,0,s.Stat_Value6),
  it.stat_type7=IF(s.Stat_Type7<0,0,s.Stat_Type7),    it.stat_value7=IF(s.Stat_Type7<0,0,s.Stat_Value7),
  it.stat_type8=IF(s.Stat_Type8<0,0,s.Stat_Type8),    it.stat_value8=IF(s.Stat_Type8<0,0,s.Stat_Value8),
  it.stat_type9=IF(s.Stat_Type9<0,0,s.Stat_Type9),    it.stat_value9=IF(s.Stat_Type9<0,0,s.Stat_Value9),
  it.stat_type10=IF(s.Stat_Type10<0,0,s.Stat_Type10), it.stat_value10=IF(s.Stat_Type10<0,0,s.Stat_Value10),
  it.ItemLevel=s.Itemlevel,
  it.Quality=s.Quality,
  it.RequiredLevel=s.Requiredlevel,
  it.delay=s.Delay
WHERE it.entry IN (70110,70112,70113,70114,70115,70116,70117,70118,70119,70120,
                   70121,70122,70123,70124,70126,70127,70141,70142,70143,70144)
  AND it.stat_value1=0 AND it.stat_value2=0 AND it.stat_value3=0
  AND it.armor=0 AND it.dmg_min1=0;

-- ---------------------------------------------------------------------
-- 2. Emberwood Sap drops on map-861 mobs (apply-ORDER fix).
--    HyjalCata/100_ derives its token drops from `creature WHERE map IN (750,861)`,
--    but HyjalCata is applied BEFORE MoltenFront/02 lays down the 861 spawns -- so
--    on a fresh apply the MF mobs are not yet in `creature` and get no sap line,
--    leaving the sap priced gear below unearnable in the Molten Front itself.
--    Re-run the same rank-weighted logic scoped to 861 so order stops mattering.
--    (Identical chance/count table to 100_; idempotent.)
-- ---------------------------------------------------------------------
DELETE lt FROM acore_world.creature_loot_template lt
JOIN acore_world.creature_template ct ON ct.lootid = lt.Entry
WHERE lt.Item = 400000 AND ct.entry IN (
  SELECT DISTINCT id FROM acore_world.creature WHERE map = 861);

INSERT IGNORE INTO acore_world.creature_loot_template
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT DISTINCT ct.lootid, 400000, 0,
  CASE ct.rank WHEN 1 THEN 22 WHEN 2 THEN 60 WHEN 3 THEN 100 WHEN 4 THEN 60 ELSE 8 END,
  0, 1, 0, 1,
  CASE ct.rank WHEN 1 THEN 2 WHEN 2 THEN 3 WHEN 3 THEN 4 WHEN 4 THEN 3 ELSE 1 END
FROM acore_world.creature_template ct
WHERE ct.lootid > 0
  AND ct.entry IN (SELECT DISTINCT id FROM acore_world.creature WHERE map = 861)
  AND ct.type <> 7
  AND EXISTS (SELECT 1 FROM acore_world.item_template WHERE entry = 400000);

-- ---------------------------------------------------------------------
-- 3. Vendor stock. Authentic item->vendor assignment and slot order taken from
--    cata_world/nelt_world npc_vendor (both agree exactly). Price tier:
--      trinkets (InventoryType 12) -> 14103 (50 sap)  -- premium chase slot
--      everything else             -> 14102 (30 sap)
--    Every row is guarded on the item AND the vendor template existing, so a
--    partially-applied set cannot create a dangling vendor line.
-- ---------------------------------------------------------------------
DELETE FROM acore_world.npc_vendor WHERE entry IN (3653214, 3653881, 3653882);

INSERT IGNORE INTO acore_world.npc_vendor
  (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT v.entry, v.slot, v.item, 0, 0, v.cost, 0
FROM (
  -- Damek Bloombeard "Exceptional Equipment" (plate/mail smith + repair)
  SELECT 3653214 AS entry, 1 AS slot, 70119 AS item, 14102 AS cost UNION ALL  -- Meteorite Ring
  SELECT 3653214, 2, 70144, 14103 UNION ALL  -- Ricket's Magnetic Fireball (trinket)
  SELECT 3653214, 3, 70115, 14102 UNION ALL  -- Fiery Treads
  SELECT 3653214, 4, 70116, 14102 UNION ALL  -- Gauntlets of Living Obsidium
  SELECT 3653214, 5, 70118, 14102 UNION ALL  -- Widow's Clutches
  SELECT 3653214, 6, 70114, 14102 UNION ALL  -- Fireplume Girdle
  SELECT 3653214, 7, 70117, 14102 UNION ALL  -- Belt of Living Obsidium
  SELECT 3653214, 8, 70120, 14102 UNION ALL  -- Rickety Belt
  SELECT 3653214, 9, 70121, 14102 UNION ALL  -- Ricket's Gun Show
  -- Ayla Shadowstorm "Treasures of Elune" (jewellery + moonwell relics)
  SELECT 3653881, 1, 70110, 14102 UNION ALL  -- Band of Glittering Lights
  SELECT 3653881, 2, 70113, 14102 UNION ALL  -- Moon Blessed Band
  SELECT 3653881, 3, 70142, 14103 UNION ALL  -- Moonwell Chalice (trinket)
  SELECT 3653881, 4, 70143, 14103 UNION ALL  -- Moonwell Phial (trinket)
  SELECT 3653881, 5, 70112, 14102 UNION ALL  -- Globe of Moonlight (held in off-hand)
  -- Varlan Highbough "Provisions of the Grove"
  SELECT 3653882, 1, 70124, 14102 UNION ALL  -- Spirit Fragment Band
  SELECT 3653882, 2, 70126, 14102 UNION ALL  -- Nemesis Shell Band
  SELECT 3653882, 3, 70127, 14102 UNION ALL  -- Lylagar Horn Ring
  SELECT 3653882, 4, 70123, 14102 UNION ALL  -- Lancer's Greaves
  SELECT 3653882, 5, 70122, 14102 UNION ALL  -- Aviana's Grips
  SELECT 3653882, 6, 70141, 14103           -- Dwyer's Caber (trinket)
) v
WHERE EXISTS (SELECT 1 FROM acore_world.item_template       i WHERE i.entry = v.item)
  AND EXISTS (SELECT 1 FROM acore_world.creature_template   c WHERE c.entry = v.entry)
  AND EXISTS (SELECT 1 FROM acore_world.itemextendedcost_dbc e WHERE e.ID   = v.cost);

-- ---------------------------------------------------------------------
-- SKIPPED (21 of the 41 authentic lines) -- each would ship a broken item.
-- Recorded here so the decision is not silently lost and can be revisited.
--
-- A. 13 profession recipes -- Plans/Pattern/Schematic 70166-70173, 70174-70177,
--    71078 ("Plans: Brainsplinter", "Pattern: Royal Scribe's Satchel",
--    "Schematic: Flintlocke's Woodchucker", ...). These teach CATACLYSM crafting
--    spells (Elementium/Pyrium smithing, Cata tailoring/engineering) that do not
--    exist on 3.3.5, and whose crafted results do not exist either. Porting them
--    means porting whole profession trees; shipping them as-is would sell recipes
--    that teach nothing. NOT in either source DB's item_template -- DBC data only.
--
-- B. 3 companion pets + 1 novelty -- 70140 Hyjal Bear Cub, 70160 Crimson Lasher,
--    70161 Mushroom Chair, 70159 Mylune's Call. Each needs a summon spell + a
--    creature template + a CreatureDisplayInfo entry: that is the established DC
--    pet-downport pipeline (dc_pet_gen_batch.py), a batch job of its own, not a
--    vendor row. Good candidates for the next pet batch -- they are thematically
--    perfect Molten Front rewards.
--
-- C. 4 relics -- 70109 Relic of Elune's Shadow, 70111 Relic of Elune's Light,
--    70125 Relic of Lo'Gosh, 70128 Relic of Tortolla (ilvl 365, InventoryType 28).
--    Exist only as raw Cata ItemSparse rows (3 of the 4 are in NEITHER world DB's
--    item_template) and carry Cata armor subclass 11, which this DB uses exactly
--    once (entry 57297) while every DC-authored relic uses the WotLK subclasses
--    7/8/9/10 (Libram/Idol/Totem/Sigil). Their stats also include Cata mastery
--    (stat type 49), which 3.3.5 ignores. Creating them would mean guessing a
--    class subclass per item, risking gear that the wrong class can equip or that
--    no class can. Better handled deliberately alongside the endgame relic
--    catalogue (400580-400688 / 400836-400852) which already follows the WotLK
--    convention.
-- ---------------------------------------------------------------------
