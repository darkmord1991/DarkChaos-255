-- ---------------------------------------------------------------------------
-- Vendor 3654402's ExtendedCost gap + the missing shared currency item
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13, ultracode workflow investigation):
-- "Item extended cost (X) does not exist" for npc_vendor entry 3654402's 16
-- item slots (ExtendedCost 3629-3641, 3647-3649). `itemextendedcost_dbc` is a
-- live SQL-mirror table (same LOAD_DBC macro as vehicle_dbc/spell_dbc/
-- faction_dbc/questsort_dbc, all confirmed this session) but was never
-- populated past the stock WotLK id range for this Firelands-quartermaster-
-- style vendor. Decoded straight from the real Cata 4.3.4 client:
-- ItemExtendedCost moved to WDB2/.db2 format in this build (not .dbc) --
-- located via `DBFilesClient\ItemExtendedCost.db2`, extracted from the base
-- `locale-enUS.MPQ` (the `wow-update-enUS-*.MPQ` copies are binary PATCH
-- records, not full tables -- must pull from the base archive). Real schema
-- is 31 fields (id, 3x required_item/amount, arena_bg_rating, 3x currency
-- type/qty, rest unknown/reserved) vs this fork's 17-field WotLK-era
-- itemextendedcost_dbc (5 item slots, no generalized currency slots) --
-- mapped required_item1/2 -> ItemID_1/2, required_item1/2_amount ->
-- ItemCount_1/2 (slots 3-5 unused, all currency/arena fields 0 for every one
-- of these 16 rows -- pure double-item-cost vendor, no honor/arena/currency
-- component).
--
-- All 16 rows require 1x a unique Firelands quest/rep item + 1x item 71617
-- "Crystallized Firestone" -- which itself was missing from item_template
-- (cata_world has no item_template; nelt_world doesn't cover this id either).
-- Downported from the real retail ItemSparse/Item CSVs, same pipeline as
-- every other item this session. Icon reused an ALREADY-DEPLOYED icon-only
-- ItemDisplayInfo row (displayid 8132787 / inv_diablostone.blp, originally
-- minted for unrelated item 194333) -- no new icon extraction or MPQ pack
-- needed, just a new Item.csv row + Item.dbc recompile/redeploy (done).
--
-- NOTE: while fixing this, found and corrected a REGRESSION in Item.csv --
-- the earlier Branch of Nordrassil (69646) follow-up had appended a raw
-- retail-column-order row instead of remapping to this fork's Item.csv
-- header, leaving DisplayInfoID=0 (item would render with no model at all).
-- Fixed in the same Item.dbc recompile/redeploy pass.
-- ---------------------------------------------------------------------------

DELETE FROM `item_template` WHERE `entry` = 71617;

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,
     `BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,
     `maxcount`,`stackable`,`ContainerSlots`,`bonding`,`Material`,`sheath`,`VerifiedBuild`)
VALUES
(71617,15,0,-1,'Crystallized Firestone',8132787,4,0,0,1,200000,50000,0,-1,-1,37,32,0,1,0,1,4,0,0);

DELETE FROM `itemextendedcost_dbc` WHERE `ID` IN (3629,3630,3631,3632,3633,3634,3635,3636,3637,3638,3639,3640,3641,3647,3648,3649);

INSERT INTO `itemextendedcost_dbc`
    (`ID`,`HonorPoints`,`ArenaPoints`,`ArenaBracket`,`ItemID_1`,`ItemID_2`,`ItemID_3`,`ItemID_4`,`ItemID_5`,
     `ItemCount_1`,`ItemCount_2`,`ItemCount_3`,`ItemCount_4`,`ItemCount_5`,`RequiredArenaRating`,`ItemPurchaseGroup`)
VALUES
(3629,0,0,0,71361,71617,0,0,0,1,1,0,0,0,0,0),
(3630,0,0,0,71366,71617,0,0,0,1,1,0,0,0,0,0),
(3631,0,0,0,71360,71617,0,0,0,1,1,0,0,0,0,0),
(3632,0,0,0,71359,71617,0,0,0,1,1,0,0,0,0,0),
(3633,0,0,0,71640,71617,0,0,0,1,1,0,0,0,0,0),
(3634,0,0,0,71365,71617,0,0,0,1,1,0,0,0,0,0),
(3635,0,0,0,71362,71617,0,0,0,1,1,0,0,0,0,0),
(3636,0,0,0,70929,71617,0,0,0,1,1,0,0,0,0,0),
(3637,0,0,0,71367,71617,0,0,0,1,1,0,0,0,0,0),
(3638,0,0,0,68972,71617,0,0,0,1,1,0,0,0,0,0),
(3639,0,0,0,68915,71617,0,0,0,1,1,0,0,0,0,0),
(3640,0,0,0,71151,71617,0,0,0,1,1,0,0,0,0,0),
(3641,0,0,0,71150,71617,0,0,0,1,1,0,0,0,0,0),
(3647,0,0,0,71152,71617,0,0,0,1,1,0,0,0,0,0),
(3648,0,0,0,71218,71617,0,0,0,1,1,0,0,0,0,0),
(3649,0,0,0,71154,71617,0,0,0,1,1,0,0,0,0,0);
