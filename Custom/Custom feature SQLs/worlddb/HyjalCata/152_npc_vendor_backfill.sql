-- ---------------------------------------------------------------------------
-- 152  Hyjal round-23 -- four vendors that advertise a shop and have none
-- ---------------------------------------------------------------------------
-- Audit finding, not a log line: four creatures in the clone block carry
-- UNIT_NPC_FLAG_VENDOR (128) but have zero npc_vendor rows, so right-clicking
-- them opens an empty buy window.
--
--   3616786  Argent Quartermaster     16 rows in source
--   3628512  Quartermaster Ozorg      33 rows
--   3650070  Jandunel Reedwind        15 rows
--   3652822  Zen'Vorka  (map 861)     17 rows  -- see the caveat below
--
-- The imports are guarded on item_template existence.  That guard is the point:
-- importing a vendor list whose items do not exist merely trades a silent empty
-- window for a screenful of "Table `npc_vendor` for Vendor ... Item ... does not
-- exist, ignoring" at every boot.
--
-- `slot` is not carried across -- the fork's column is a display-order hint and
-- nelt's values are for a different client's sort.  Left at 0 so the core keeps
-- source order.
--
-- Idempotent (PK is entry+item+ExtendedCost).
-- Apply AFTER 151_ (which creates 13 of Zen'Vorka's items).
-- ---------------------------------------------------------------------------

INSERT IGNORE INTO acore_world.npc_vendor (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT v.entry + 3600000, 0, v.item, v.maxcount, v.incrtime, v.ExtendedCost, 0
FROM nelt_world.npc_vendor v
WHERE v.entry IN (16786, 28512, 50070)
  AND EXISTS (SELECT 1 FROM acore_world.creature_template ct WHERE ct.entry = v.entry + 3600000)
  AND EXISTS (SELECT 1 FROM acore_world.item_template it WHERE it.entry = v.item);

-- ---------------------------------------------------------------------------
-- Zen'Vorka -- only the four gold-priced rows are imported
-- ---------------------------------------------------------------------------
-- Zen'Vorka is the Molten Front token vendor.  His 17-row list splits cleanly:
--
--   ExtendedCost 0     70105 Matoclaw's Band, 70106 Nightweaver's Amulet,
--                      70107 Fireheart Necklace, 70108 Pyrelord Greaves
--                      -- real gear, already in item_template, bought for gold.
--   ExtendedCost 3412  the 12 city "Writ of Commendation" reputation items plus
--                      71631 Zen'Vorka's Cache -- bought with Marks of the
--                      World Tree.
--
-- The 3412 rows are DELIBERATELY EXCLUDED, and this is a scope call rather than
-- an oversight, so it is written down:
--
--   * ItemExtendedCost 3412 is not in the fork's ItemExtendedCost.dbc (982 rows,
--     max id 14103, and 3412 is simply absent).  A row referencing a missing
--     extended cost is dropped by the core with a warning.
--   * 3.3.5's ItemExtendedCost layout has 16 fields -- ReqItem[5] /
--     ReqItemCount[5] / honor / arena.  It has NO currency columns, so Cata's
--     "1x currency 416" price cannot be expressed directly; it would have to be
--     re-expressed as a token ITEM.
--   * There is no such token: DC has no "Mark of the World Tree" item at all,
--     and all 39 Molten Front dailies reward gold only (94000 / 188000 copper,
--     RewardItem1 = 0 across the board).  Nothing in the zone would grant the
--     currency even if the cost row existed.
--
-- So finishing this is not a data backfill, it is designing the Mark economy:
-- mint a token item, decide the per-daily payout across 39 quests, and author
-- ItemExtendedCost 3412 with a price.  That is a content-balance decision and
-- is left to the project rather than invented here.  151_ creates the 13 items
-- so that work is one step away; until then they are inert and unsold.
--
-- Importing the four gold rows now is still worth doing on its own: it makes
-- the vendor flag honest and puts four pieces of real Molten Front gear back
-- in reach.
INSERT IGNORE INTO acore_world.npc_vendor (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT v.entry + 3600000, 0, v.item, v.maxcount, v.incrtime, v.ExtendedCost, 0
FROM nelt_world.npc_vendor v
WHERE v.entry = 52822
  AND v.ExtendedCost = 0
  AND EXISTS (SELECT 1 FROM acore_world.creature_template ct WHERE ct.entry = v.entry + 3600000)
  AND EXISTS (SELECT 1 FROM acore_world.item_template it WHERE it.entry = v.item);
