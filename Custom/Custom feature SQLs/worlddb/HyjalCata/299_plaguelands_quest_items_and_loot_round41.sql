-- ---------------------------------------------------------------------------
-- 299  Round 41 -- 6 Cata quest items, the 9 loot ids they free, display 9901
-- ---------------------------------------------------------------------------
-- One item downport closes every remaining "loot table does not exist" line in
-- the boot log.  All nine were the same defect: the map 751 / 825 imports
-- brought the gameobjects across but not the items they hold, so the loot
-- tables could never be created.
--
--     Table 'gameobject_loot_template' Entry 4805099 does not exist but it is
--       used by Gameobject 4805099     (+ 34671/34677/34678 twice each, 4805363)
--     Table 'spell_loot_template' Entry 99500 does not exist but it is used by
--       Spell 99500
--
-- Every gameobject in that list is NAMED after the item it should contain, which
-- is what made the mapping unambiguous:
--     4805099  Ferocious Doomweed             18 spawns, map 751 -> 60741
--     4805363  Forsaken Communication Device    1 spawn,  map 751 -> 60953
--     5400038 / 5305476  Book of Lost Souls     1 spawn,  map 825 -> 60873
--     5400039 / 5305477  Moonsteel Ingots      30 spawns, map 825 -> 60872
--     5400040 / 5305479  Moontouched Wood      43 spawns, map 825 -> 60871
--     spell 99500                                                 -> 69988
--
-- ---------------------------------------------------------------------------
-- Why two loot id conventions appear below
-- ---------------------------------------------------------------------------
-- The 751 pair was renumbered by its importer to the lootid == entry convention
-- (232_); the 825 sets kept Cata raw lootids.  Both are correct, and each was
-- resolved back through cata_world.gameobject_template rather than inferred:
--     205099 + 4,600,000 = 4805099   lootid 32109 -> renumbered to 4805099
--     205363 + 4,600,000 = 4805363   lootid 34375 -> renumbered to 4805363
--     205476 + 5,100,000 = 5305476   lootid 34671 -> kept raw
--     205477 + 5,100,000 = 5305477   lootid 34677 -> kept raw
--     205479 + 5,100,000 = 5305479   lootid 34678 -> kept raw
-- The 5305xxx and 5400xxx templates are the SAME three Cata gameobjects imported
-- twice into different bands; they share a lootid, so one table row serves both,
-- and the 5305xxx set (0 spawns) is left alone rather than deleted.
--
-- CHECKED BEFORE CREATING TABLES AT STOCK-RANGE IDS.  34671/34677/34678 look
-- like they could collide with stock loot, so this was settled rather than
-- assumed: gameobject_loot_template is completely empty across 34600-34800
-- (MAX(entry) in that range is NULL) and no other gameobject_template in the DB
-- carries those Data1 values.  No remap needed -- the raw ids stand.
--
-- ---------------------------------------------------------------------------
-- The items
-- ---------------------------------------------------------------------------
-- Client fields come from the Cata 4.3.4 Item.db2 (build 15595) -- class,
-- subclass, SoundOverrideSubclass, material, displayid, inventorytype, sheath --
-- so they match the DBC the core validates against field for field.  Names and
-- stack sizes come from the retail ItemSparse extract, so the strings are
-- authentic rather than invented.  All six are class 12 (Quest), bind-on-pickup.
--
-- DISPLAY IDS ALL RESOLVED -- unusually, no zeroing was needed.  All six Cata
-- display ids (37412, 1312, 39486, 67550, 40558, 69999) already exist in the
-- fork ItemDisplayInfo (97,546 records), so every item ships with its real icon.
-- Earlier rounds had to zero the Cata-new 98xxx icons; none of these are new.
--
-- SoundOverrideSubclass is -1 in the Cata DBC and the item_template column
-- defaults to -1, so the two agree and ObjectMgr.cpp:3519 stays quiet.  Round 31
-- had to force four items to 0 for the opposite reason -- their DBC rows said 0.
-- It is written out explicitly here rather than left to the default.
--
-- CLIENT HALF, ALREADY DEPLOYED.  Item.csv 154,936 -> 154,942, recompiled with
-- dbc-compile.py and gated on a strict-superset diff: 0 ids lost, exactly 6
-- gained, 0 existing rows changed.  Written to patch-4.MPQ AND
-- enGB/patch-enGB-3.MPQ -- enGB shadows patch-4 for this table and both carried
-- it at 154,936 -- each verified byte-identical, plus the three WXL checkouts.
-- Item.dbc is safe to recompile from CSV, unlike the 234-field fork Spell.dbc:
-- its CSV and DBC agreed exactly at 154,936 before the edit, so nothing lives in
-- the binary that the CSV does not carry.
--
-- THE LOCAL Server/data/dbc MIRROR WAS 1,402 RECORDS STALE (153,540), NOT THE
-- LIVE SERVER.  Checked against the running worldserver with read_server_dbc
-- rather than trusting the mirror: live was already current at 154,936, and the
-- five rows that appeared to "change" (63682-4, 64663, 71716 display ids) were
-- only the stale mirror catching up -- live already matched item_template.  The
-- mirror now holds live+6 and is what needs pushing.
--
-- ---------------------------------------------------------------------------
-- 1) item_template -- the 6 items
-- ---------------------------------------------------------------------------
DELETE FROM acore_world.`item_template` WHERE `entry` IN (60741,60871,60872,60873,60953,69988);
INSERT INTO acore_world.`item_template`
  (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`, `Quality`, `Flags`,
   `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`, `AllowableClass`, `AllowableRace`,
   `ItemLevel`, `RequiredLevel`, `maxcount`, `stackable`, `ContainerSlots`, `bonding`,
   `description`, `startquest`, `Material`, `sheath`, `BagFamily`, `ScriptName`, `VerifiedBuild`)
VALUES
(60741, 12, 0, -1, 'Ferocious Doomweed', 37412, 1, 0, 1, 0, 0, 0, -1, -1, 1, 1, 0, 8, 0, 1, '', 0, 4, 0, 0, '', 0),
(60871, 12, 0, -1, 'Moontouched Wood', 1312, 1, 0, 1, 0, 0, 0, -1, -1, 1, 1, 0, 10, 0, 1, '', 0, 4, 0, 0, '', 0),
(60872, 12, 0, -1, 'Moonsteel Ingots', 39486, 1, 0, 1, 0, 0, 0, -1, -1, 1, 1, 0, 10, 0, 1, '', 0, 4, 0, 0, '', 0),
(60873, 12, 0, -1, 'Book of Lost Souls', 67550, 1, 0, 1, 0, 0, 0, -1, -1, 1, 1, 0, 10, 0, 1, '', 0, 4, 0, 0, '', 0),
(60953, 12, 0, -1, 'Forsaken Communication Device', 40558, 1, 0, 1, 0, 0, 0, -1, -1, 1, 1, 0, 1, 0, 1, '', 0, 4, 0, 0, '', 0),
(69988, 12, 0, -1, 'Pine Nut', 69999, 1, 0, 1, 0, 0, 0, -1, -1, 1, 1, 0, 100, 0, 1, 'Tiny but tasty.', 0, 4, 0, 0, '', 0);

-- ---------------------------------------------------------------------------
-- 2) gameobject_loot_template -- 5 tables, 8 of the 9 log lines
-- ---------------------------------------------------------------------------
-- Chance, QuestRequired and counts are copied from cata_world verbatim (all
-- 100%, quest-gated, 1-1) rather than guessed.
--
-- QuestRequired STAYS 1, DELIBERATELY.  None of the Cata quests that consume
-- these items exist in our DB yet: 60741 belongs to "Agony Abounds" (26992),
-- 60953 to "The F.C.D." (27345), and 60871/2/3 to the Cata class-weapon chain
-- (24 quests, all negative QuestSortID).  So these 93 gameobjects stay inert
-- until those chains are downported.  That is the right trade: dropping to
-- QuestRequired 0 would hand players bind-on-pickup quest items that can never
-- be turned in, and the log line clears either way -- the core only checks that
-- the TABLE exists, and the quest gate (LootMgr.cpp:446) is runtime-only with no
-- load-time validation.  When the quests land, the loot works with no rework.
DELETE FROM acore_world.`gameobject_loot_template` WHERE `Entry` IN (4805099,4805363,34671,34677,34678);
INSERT INTO acore_world.`gameobject_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
(4805099, 60741, 0, 100, 1, 1, 0, 1, 1, 'Ferocious Doomweed -- cata glt 32109 via GO 205099'),
(4805363, 60953, 0, 100, 1, 1, 0, 1, 1, 'Forsaken Communication Device -- cata glt 34375 via GO 205363'),
(34671, 60873, 0, 100, 1, 1, 0, 1, 1, 'Book of Lost Souls -- cata glt 34671 verbatim'),
(34677, 60872, 0, 100, 1, 1, 0, 1, 1, 'Moonsteel Ingots -- cata glt 34677 verbatim'),
(34678, 60871, 0, 100, 1, 1, 0, 1, 1, 'Moontouched Wood -- cata glt 34678 verbatim');

-- ---------------------------------------------------------------------------
-- 3) spell_loot_template -- the 9th line
-- ---------------------------------------------------------------------------
-- Spell 99500 gives 5 Pine Nuts, un-gated in Cata (QuestRequired 0) even though
-- 69988 also feeds quest 29358 "Pining for Nuts" -- copied as-is.
DELETE FROM acore_world.`spell_loot_template` WHERE `Entry` = 99500;
INSERT INTO acore_world.`spell_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
(99500, 69988, 0, 100, 0, 1, 0, 5, 5, 'Pine Nut x5 -- cata slt 99500 verbatim');

-- ---------------------------------------------------------------------------
-- 4) gameobject display 9901 -- DBC-only, no SQL, recorded here
-- ---------------------------------------------------------------------------
--     Gameobject (GUID: 16510130 Entry 5400038 GoType: 3) has an invalid
--     displayId (9901), not loaded.
--
-- The SAME two templates as section 2 -- 5305476 and 5400038, "Book of Lost
-- Souls" -- so this file gives them both their loot and their model.  Until now
-- the one spawned copy on map 825 was not loaded at all, which means its loot
-- table would have gone unused even after section 2.
--
-- GameObjectDisplayInfo is 21 fields / 84 bytes in Cata against 19 / 76 here,
-- and the remap turned out to be trivial: Cata is our layout plus two trailing
-- floats (OverrideLootEffectScale, OverrideNameScale), both 0.0 on this row, so
-- the first 19 fields transfer untouched.  Cata row 9901:
--     ModelName  world\generic\human\passive doodads\books\book_dwarf_darkiron_02.mdx
--     Sound[10]  all 0
--     GeoBox     all 0
--     ObjectEffectPackageID 0
--
-- THE ZERO GEOBOX IS CORRECT, NOT MISSING DATA.  It looks like an import gap,
-- but stock 3.3.5 ships the entire Book_<race>_NN family that way -- 8051, 8128,
-- 8131, 8133, 8135, 8136, 8301, 8345, 8350, 8351 and the already-downported
-- book_troll_03 (9450) all carry an all-zero box, while the older BookMedium /
-- BookLarge displays carry real ones.  Copying Cata verbatim matches the
-- siblings; inventing a bounding box would not.
--
-- ASSET CHAIN VERIFIED BEFORE POINTING ANYTHING AT IT -- a display id that
-- resolves to a missing model is a worse failure than the one being fixed:
--     book_dwarf_darkiron_02.m2      patch-8  MD20 v264, 278 verts, 1 view,
--                                             globalFlags 0x80 (not the 0x8
--                                             combiner-combos crash flag)
--     book_dwarf_darkiron_0200.skin  patch-8
--     books_dwarf_darkiron_01.blp    patch-8
--     orbreflectbright.blp           common.MPQ + patch-D
-- The model is one of our own bakes rather than stock, and it is intact.
--
-- ID 9901 IS FREE HERE and no existing display uses that model, so it goes in at
-- the Cata id and the gameobject_template rows need no change at all.
--
-- APPENDED TO THE BINARY, NOT REBUILT FROM CSV.  A csv2wdbc rebuild round-trips
-- cleanly on ids (46,928 in, 46,929 out, 0 lost) but drifts the GeoBox floats of
-- six rows -- 9140, 9141, 9146, 9375, 9376, 10014 -- by ~4e-6, because the CSV
-- holds about six significant digits and those rows hold more.  Harmless, but
-- avoidable: inserting the record straight into the DBC leaves every existing
-- byte identical.  Verified 0 lost / 1 gained / **0 existing rows changed**.
-- Deployed to patch-4 + enGB-3 (both verified byte-identical), the three WXL
-- checkouts, and the server mirror.  The CSV carries the new row too, so CSV and
-- DBC stay in parity at 46,929.
--
-- Nothing for this file to do -- both templates already point at 9901.
--
-- ---------------------------------------------------------------------------
-- Verify after apply
-- ---------------------------------------------------------------------------
--  1  SELECT COUNT(*) FROM item_template
--      WHERE entry IN (60741,60871,60872,60873,60953,69988);                -> 6
--  2  SELECT COUNT(DISTINCT Entry) FROM gameobject_loot_template
--      WHERE Entry IN (4805099,4805363,34671,34677,34678);                  -> 5
--  3  SELECT COUNT(*) FROM spell_loot_template WHERE Entry = 99500;         -> 1
--  4  REQUIRES THE REFRESHED Item.dbc ON THE LIVE SERVER.  Without it the core
--     logs six NEW lines instead ("Item (Entry: N) does not exist in Item.dbc"),
--     so push data/dbc BEFORE the restart, not after.
--  5  GameObjectDisplayInfo.dbc must go up in the same push (46,928 -> 46,929).
--     In-game, the Book of Lost Souls on map 825 should become visible.
--
--  Next boot: 10 more lines gone (9 loot + the display).  With 298_ applied that
--  takes the log from 54 to roughly 31 lines.
--
-- ---------------------------------------------------------------------------
-- Still open after this
-- ---------------------------------------------------------------------------
-- * SmartAI spells 95303/95305, the 8 unassigned scripts, 6 spell-script effect
--   mismatches, 2 upstream waypoint gaps, the stock loot-chance overflows, the
--   pickpocket/skinning/reference orphans and OutdoorPvP type 8 -- all
--   previously triaged as not-DB-fixes.
