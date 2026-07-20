-- ---------------------------------------------------------------------------
-- 20  item_template downport -- the 18 items 19_trash_loot.sql flagged as
--     "NOT in item_template"
-- ---------------------------------------------------------------------------
-- All 18 came back real (not fabricated/placeholder) once checked against the
-- retail client instead of the SL-era SQL dumps 19_trash_loot.sql's source used
-- (that dump has no `item_template` table at all, only `item_template_addon`;
-- cata_world/nelt_world/TC-master-TDB also have zero rows for any of these
-- ids). Decoded Item.db2 + ItemSparse.db2 from the 9.2.7 DekkCore repack
-- (`K:\Dark-Chaos\SL stuff\[9.2.7] DekkCore Donor Repack 9.2.7\Clientdata\dbc\
-- enUS\`, same source [[retail-1207-encrypted-db2s]] uses for 12.0.7's
-- TACT-encrypted Item/ItemSparse) via `db2-decode-loose.js` -- all 18 ids
-- resolved cleanly: real names, ClassID/SubclassID/Quality/SellPrice/BuyPrice/
-- Stackable/RequiredLevel/ItemLevel/Bonding, and a real IconFileDataID apiece.
--
-- All 18 are InventoryType=0 (non-equippable trade-good/junk/quest fillers),
-- so no model/appearance chain is needed -- just an icon, same convention as
-- [[item-downport-wraith-pipeline]]'s Track-C `--fix-disp0` fix and
-- [[dc-real-item-icon-pipeline]]: new ItemDisplayInfo id = 8,000,000 +
-- IconFileDataID, icon-only row (blank model fields). 17 of the 18 needed a
-- brand new id; the 18th (173871 "Harrowed Ichor", icon
-- ability_warlock_everlastingaffliction) collided with an id already minted
-- by an earlier batch for the same icon -- reused as-is, no new row/asset.
--
-- Deployed this pass (client-side, all byte-verified):
--   - Item.csv / ItemDisplayInfo.csv (Custom/CSV DBC) appended (18 / 17 rows)
--     and recompiled via dbc-compile.py (0 field diffs on --verify).
--   - 17 new icon BLPs extracted from the retail (12.0.7, unencrypted assets)
--     client by FileDataID, renamed to their real basenames, packed into
--     patch-E.MPQ (the icon-downport patch) -- BLPs are base-resident, not
--     enGB-shadowed, so patch-E alone is enough for icons.
--   - Item.dbc + ItemDisplayInfo.dbc deployed to patch-4.MPQ AND
--     patch-enGB-3.MPQ (both confirmed present there, so both shadow) +
--     synced to all 3 WarcraftXLHost candidate dirs.
-- Server-side: compiled files left in Custom/DBCs for the user's manual
-- Linux deploy (per [[dbc-csv-compile-deploy-pipeline]] -- Server/data/dbc is
-- NOT the real server dbc dir); the item_dbc/itemdisplayinfo_dbc SQL overlay
-- below (world DB, applied by the user like every other file here) covers the
-- server-side sItemStore/sItemDisplayInfoStore lookup independent of when
-- that manual deploy happens.
--
-- Quest-class (12) items keep their Blizzard StartQuestID OUT of `startquest`
-- deliberately -- these Shadowlands quest chains don't exist in this DB and
-- copying the id would just create a fresh "missing quest" boot warning; they
-- ship as plain QuestRequired loot drops only, matching 19_trash_loot.sql's
-- own scope decision. Retail Flags/FlagsExtra bitmasks are NOT copied either
-- (bit meanings drift across expansions) -- 0/0 for all, matching every other
-- hand-authored item this session. Class-12 items get `bonding`=4 (Quest bind)
-- regardless of retail's raw Bonding value, matching this project's own
-- established convention (see dc_molten_front_quest_items_2026_07_13.sql);
-- everything else keeps retail's real Bonding value as-is.
-- ---------------------------------------------------------------------------

DELETE FROM `item_template` WHERE `entry` IN
    (173202,173204,178061,178113,178115,178128,178131,178132,173705,173715,
     173871,173875,176852,176860,176862,180310,180453,180834);

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,
     `BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,
     `maxcount`,`stackable`,`ContainerSlots`,`bonding`,`Material`,`sheath`,`VerifiedBuild`)
VALUES
(173202,7,5,-1,'Shrouded Cloth',11528456,1,0,0,1,10,2,0,-1,-1,50,1,0,200,0,0,7,0,0),
(173204,7,5,-1,'Lightless Silk',11528460,2,0,0,1,12,3,0,-1,-1,50,1,0,200,0,0,7,0,0),
(178061,15,4,-1,'Malleable Flesh',10032179,2,0,0,1,50000,1,0,-1,-1,1,0,0,500,0,1,8,0,0),
(178113,15,0,-1,'Twitching Stone',8135239,0,0,0,1,15584,3896,0,-1,-1,50,1,0,200,0,0,0,0,0),
(178115,15,0,-1,'Tapping Stone Claw',9508485,0,0,0,1,652636,163159,0,-1,-1,50,1,0,200,0,0,0,0,0),
(178128,15,0,-1,'Pouch of Shinies',9519431,1,0,0,1,676240,0,0,-1,-1,50,1,0,1,0,1,0,0,0),
(178131,15,0,-1,'Whetstone Talon File',8519379,0,0,0,1,46784,11696,0,-1,-1,120,1,0,200,0,0,0,0,0),
(178132,15,0,-1,'Richly Calligraphed Invitation',9505928,0,0,0,1,56992,14248,0,-1,-1,120,1,0,200,0,0,0,0,0),
(173705,12,0,-1,'The Venthyr Diaries',10101967,2,0,0,1,0,0,0,-1,-1,1,0,1,1,0,4,0,0,0),
(173715,12,0,-1,'Dredger''s Toolkit',9063279,2,0,0,1,0,0,0,-1,-1,1,0,1,1,0,4,0,0,0),
(173871,15,0,-1,'Harrowed Ichor',8236296,0,0,0,1,14388,3597,0,-1,-1,50,1,0,200,0,0,0,0,0),
(173875,15,0,-1,'Defiling Mire',8576309,0,0,0,1,570340,142585,0,-1,-1,50,1,0,200,0,0,0,0,0),
(176852,15,0,-1,'Hardened Tail Bone',9029749,0,0,0,1,51780,12945,0,-1,-1,120,1,0,200,0,0,0,0,0),
(176860,15,0,-1,'Keen Incisor',9518088,0,0,0,1,630944,157736,0,-1,-1,50,1,0,200,0,0,0,0,0),
(176862,15,0,-1,'Marred Skin',8377272,0,0,0,1,14100,3525,0,-1,-1,120,1,0,200,0,0,0,0,0),
(180310,15,0,-1,'Fluttering Stone Wings',10103876,0,0,0,1,593944,148486,0,-1,-1,50,1,0,200,0,0,0,0,0),
(180453,12,0,-1,'She Had a Stone Heart',9505962,2,0,0,1,0,0,0,-1,-1,1,0,1,1,0,4,0,0,0),
(180834,15,4,-1,'Renathal''s Journal Pages',9505939,2,0,0,1,50,12,0,-1,-1,50,1,0,10,0,1,0,0,0);

-- ---------------------------------------------------------------------------
-- item_dbc / itemdisplayinfo_dbc overlay -- mirrors the client DBC rows so
-- sItemStore / sItemDisplayInfoStore resolve these ids server-side too,
-- independent of when the compiled Item.dbc/ItemDisplayInfo.dbc get manually
-- deployed to the Linux worldserver's own dbc dir.
-- ---------------------------------------------------------------------------
DELETE FROM `item_dbc` WHERE `ID` IN
    (173202,173204,178061,178113,178115,178128,178131,178132,173705,173715,
     173871,173875,176852,176860,176862,180310,180453,180834);

INSERT INTO `item_dbc`
    (`ID`,`ClassID`,`SubclassID`,`Sound_Override_Subclassid`,`Material`,`DisplayInfoID`,`InventoryType`,`SheatheType`)
VALUES
(173202,7,5,-1,7,11528456,0,0),
(173204,7,5,-1,7,11528460,0,0),
(178061,15,4,-1,8,10032179,0,0),
(178113,15,0,-1,0,8135239,0,0),
(178115,15,0,-1,0,9508485,0,0),
(178128,15,0,-1,0,9519431,0,0),
(178131,15,0,-1,0,8519379,0,0),
(178132,15,0,-1,0,9505928,0,0),
(173705,12,0,-1,0,10101967,0,0),
(173715,12,0,-1,0,9063279,0,0),
(173871,15,0,-1,0,8236296,0,0),
(173875,15,0,-1,0,8576309,0,0),
(176852,15,0,-1,0,9029749,0,0),
(176860,15,0,-1,0,9518088,0,0),
(176862,15,0,-1,0,8377272,0,0),
(180310,15,0,-1,0,10103876,0,0),
(180453,12,0,-1,0,9505962,0,0),
(180834,15,4,-1,0,9505939,0,0);

-- 173871 reuses an id already minted by an earlier batch -- don't touch its row.
DELETE FROM `itemdisplayinfo_dbc` WHERE `ID` IN
    (11528456,11528460,10032179,8135239,9508485,9519431,8519379,9505928,
     10101967,9063279,8576309,9029749,9518088,8377272,10103876,9505962,9505939);

INSERT INTO `itemdisplayinfo_dbc`
    (`ID`,`InventoryIcon_1`,`GeosetGroup_1`,`GeosetGroup_2`,`GeosetGroup_3`,`Flags`,`SpellVisualID`,
     `GroupSoundIndex`,`HelmetGeosetVis_1`,`HelmetGeosetVis_2`,`ItemVisual`,`ParticleColorID`)
VALUES
(11528456,'inv_tailoring_commoncloth',0,0,0,0,0,0,0,0,0,0),
(11528460,'inv_tailoring_uncommoncloth',0,0,0,0,0,0,0,0,0,0),
(10032179,'inv_skinning_80_tempesthide',0,0,0,0,0,0,0,0,0,0),
(8135239,'inv_stone_13',0,0,0,0,0,0,0,0,0,0),
(9508485,'inv_misc_bearclaw_black',0,0,0,0,0,0,0,0,0,0),
(9519431,'inv_misc_coinbag11',0,0,0,0,0,0,0,0,0,0),
(8519379,'creatureportrait_altarofearth_01',0,0,0,0,0,0,0,0,0,0),
(9505928,'inv_misc_noteblank2a',0,0,0,0,0,0,0,0,0,0),
(10101967,'inv_archaeology_80_witch_book',0,0,0,0,0,0,0,0,0,0),
(9063279,'inv_misc_1h_bucket_b_01',0,0,0,0,0,0,0,0,0,0),
(8576309,'spell_yorsahj_bloodboil_black',0,0,0,0,0,0,0,0,0,0),
(9029749,'inv_misc_wailingbone',0,0,0,0,0,0,0,0,0,0),
(9518088,'inv_misc_tootha_01',0,0,0,0,0,0,0,0,0,0),
(8377272,'inv_misc_rubysanctum3',0,0,0,0,0,0,0,0,0,0),
(10103876,'inv_icon_wing07c',0,0,0,0,0,0,0,0,0,0),
(9505962,'inv_misc_notescript2e',0,0,0,0,0,0,0,0,0,0),
(9505939,'inv_misc_notefolded2e',0,0,0,0,0,0,0,0,0,0);
