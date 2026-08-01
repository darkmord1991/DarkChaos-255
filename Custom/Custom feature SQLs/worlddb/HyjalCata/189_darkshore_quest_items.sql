-- ---------------------------------------------------------------------------
-- 189  Darkshore/Felwood Cata quest items -- 56 items downported
-- ---------------------------------------------------------------------------
-- Stage 1 of unblocking the Cata Darkshore quest layer. The 175 Darkshore
-- quests reference 215 items; 159 already existed, these are the other 56.
-- They also un-empty the 10 gameobject chests that 184_ had to leave without
-- loot (Encrusted Clam x139, Highborne Relic x46, Bear's Paw x27, Slain Wildkin
-- Feather x25, ...), because each of those chests drops exactly one of them.
--
-- SOURCE -- this is the part that was previously blocked. `cata_world` has no
-- item_template and the retail DB2s store icons as FileDataIDs, so the
-- item -> displayid mapping could not be derived. It comes instead from the
-- UNTOUCHED 4.3.4 CLIENT at K:\UntouchedClients\Cata:
--     Data\wow-update-base-15601.MPQ -> DBFilesClient\Item.db2          (WDB2, build 15595, 64,775 rows)
--     Data\wow-update-base-15601.MPQ -> DBFilesClient\ItemDisplayInfo.dbc (WDBC, 95,359 rows)
-- Item.db2 gives class/subclass/material/inventorytype/sheath/displayid for all
-- 56; ItemDisplayInfo.dbc gives the real icon names for all 53 displays they
-- use. Names/quality/stackable/bonding come from `nelt_world`.`db_item-sparse_15595`
-- (the same build), which is why the INSERTs below are INSERT...SELECT against
-- it rather than hand-typed literals -- no transcription risk on 56 names.
--
-- DISPLAY-ID COLLISION CHECK (the thing that would have silently corrupted
-- existing items): of the 53 display IDs, 24 already exist in our
-- ItemDisplayInfo and every one of those 24 has a BYTE-IDENTICAL icon name to
-- Cata's -- i.e. they are genuinely the same rows, inherited from WotLK. ZERO
-- clashed. Only the other 29 are new, and only those 29 are inserted.
--
-- Flags/FlagsExtra are forced to 0 rather than copied. Cata inserted new bits
-- into both fields, so the raw values (65536, 8388672, 196608, Flags2=8192...)
-- do not mean the same thing in 3.3.5. This follows the precedent set by
-- CastleNathria/20_missing_trash_items.sql. Everything that actually matters
-- for a quest item -- bonding=4, stackable, maxcount -- is copied verbatim.
--
-- Apply against acore_world. Item.dbc and ItemDisplayInfo.dbc are ALSO updated
-- and deployed, so a CLIENT RESTART is required. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) item_template -- Item.db2 columns joined to Item-sparse for the rest
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` IN (
  44830, 44850, 44863, 44864, 44887, 44888, 44889, 44911, 44913, 44925, 
  44929, 44942, 44959, 44960, 44966, 44968, 44969, 44975, 44976, 44979, 
  44985, 44995, 44999, 45027, 45885, 45898, 45911, 45944, 46318, 46325, 
  46337, 46354, 46355, 46356, 46363, 46370, 46384, 46385, 46386, 46387, 
  46388, 46546, 46692, 46695, 46696, 52659, 52660, 52662, 52663, 52664, 
  52671, 52673, 52675, 55135, 58365, 64450
);

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,
     `BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,
     `RequiredLevel`,`maxcount`,`stackable`,`ContainerSlots`,`bonding`,`Material`,`sheath`,`VerifiedBuild`)
SELECT m.`entry`, m.`cls`, m.`sub`, m.`snd`, s.`Name`, m.`disp`, s.`Quality`, 0, 0,
       1, s.`Buyprice`, s.`Sellprice`, m.`inv`, s.`Allowableclass`, s.`Allowablerace`, s.`Itemlevel`,
       s.`Requiredlevel`, s.`Maxcount`, s.`Stackable`, s.`Containerslots`, s.`Bonding`, m.`mat`, m.`sheath`, 15595
FROM (
SELECT * FROM (VALUES
  ROW(44830,12,0,0,4,34145,0,0),
  ROW(44850,12,0,0,4,18087,0,0),
  ROW(44863,12,0,0,4,54534,0,0),
  ROW(44864,12,0,0,4,53856,0,0),
  ROW(44887,12,0,0,4,57686,0,0),
  ROW(44888,12,0,0,4,18087,0,0),
  ROW(44889,12,0,0,4,57686,0,0),
  ROW(44911,12,0,0,4,57708,0,0),
  ROW(44913,12,0,0,4,3759,0,0),
  ROW(44925,13,0,-1,4,22071,0,0),
  ROW(44929,12,0,-1,1,57744,0,0),
  ROW(44942,12,0,0,4,32073,0,0),
  ROW(44959,12,0,-1,0,59812,0,0),
  ROW(44960,12,0,0,4,46154,0,0),
  ROW(44966,12,0,0,4,57852,0,0),
  ROW(44968,12,0,0,4,23229,0,0),
  ROW(44969,12,0,0,4,18098,0,0),
  ROW(44975,12,0,-1,4,26571,0,0),
  ROW(44976,12,0,0,4,57893,0,0),
  ROW(44979,12,0,-1,4,57898,0,0),
  ROW(44985,12,0,0,4,58862,0,0),
  ROW(44995,12,0,0,4,57929,0,0),
  ROW(44999,12,0,0,4,57936,0,0),
  ROW(45027,12,0,0,4,57987,0,0),
  ROW(45885,12,0,0,4,58615,0,0),
  ROW(45898,12,0,0,4,21143,0,0),
  ROW(45911,12,0,0,4,58655,0,0),
  ROW(45944,12,0,0,4,3154,0,0),
  ROW(46318,12,0,-1,4,59523,0,0),
  ROW(46325,15,2,-1,2,67461,0,0),
  ROW(46337,2,20,-1,2,20618,17,1),
  ROW(46354,12,0,0,2,4664,0,0),
  ROW(46355,12,0,0,2,59564,0,0),
  ROW(46356,12,0,0,2,59565,0,0),
  ROW(46363,12,0,0,4,4969,0,0),
  ROW(46370,12,0,0,4,4969,0,0),
  ROW(46384,12,0,0,4,30710,0,0),
  ROW(46385,12,0,0,4,59669,0,0),
  ROW(46386,12,0,0,4,59682,0,0),
  ROW(46387,12,0,0,4,46851,0,0),
  ROW(46388,12,0,0,4,70849,0,0),
  ROW(46546,12,0,-1,0,59836,0,0),
  ROW(46692,0,0,0,4,59851,0,0),
  ROW(46695,12,0,-1,0,39631,0,0),
  ROW(46696,0,0,0,4,59868,0,0),
  ROW(52659,4,1,-1,7,69328,16,0),
  ROW(52660,4,1,-1,7,23143,16,0),
  ROW(52662,4,1,-1,7,69334,16,0),
  ROW(52663,4,1,-1,7,69329,16,0),
  ROW(52664,4,1,-1,7,69333,16,0),
  ROW(52671,4,0,-1,0,64176,11,0),
  ROW(52673,4,0,-1,0,24022,11,0),
  ROW(52675,4,1,-1,7,69335,16,0),
  ROW(55135,4,0,-1,3,53042,11,0),
  ROW(58365,0,0,-1,4,54474,0,0),
  ROW(64450,12,0,-1,4,74777,0,0)) AS t(`entry`,`cls`,`sub`,`snd`,`mat`,`disp`,`inv`,`sheath`)
) m
JOIN `nelt_world`.`db_item-sparse_15595` s ON s.`ID` = m.`entry`;

-- ---------------------------------------------------------------------------
-- B) item_dbc overlay -- so sItemStore resolves these ids server-side
--    independently of when the compiled Item.dbc reaches the worldserver's
--    own dbc dir (same reasoning as CastleNathria/20_).
-- ---------------------------------------------------------------------------
DELETE FROM `item_dbc` WHERE `ID` IN (
  44830, 44850, 44863, 44864, 44887, 44888, 44889, 44911, 44913, 44925, 
  44929, 44942, 44959, 44960, 44966, 44968, 44969, 44975, 44976, 44979, 
  44985, 44995, 44999, 45027, 45885, 45898, 45911, 45944, 46318, 46325, 
  46337, 46354, 46355, 46356, 46363, 46370, 46384, 46385, 46386, 46387, 
  46388, 46546, 46692, 46695, 46696, 52659, 52660, 52662, 52663, 52664, 
  52671, 52673, 52675, 55135, 58365, 64450
);

INSERT INTO `item_dbc`
    (`ID`,`ClassID`,`SubclassID`,`Sound_Override_Subclassid`,`Material`,`DisplayInfoID`,`InventoryType`,`SheatheType`)
VALUES
  (44830,12,0,0,4,34145,0,0),
  (44850,12,0,0,4,18087,0,0),
  (44863,12,0,0,4,54534,0,0),
  (44864,12,0,0,4,53856,0,0),
  (44887,12,0,0,4,57686,0,0),
  (44888,12,0,0,4,18087,0,0),
  (44889,12,0,0,4,57686,0,0),
  (44911,12,0,0,4,57708,0,0),
  (44913,12,0,0,4,3759,0,0),
  (44925,13,0,-1,4,22071,0,0),
  (44929,12,0,-1,1,57744,0,0),
  (44942,12,0,0,4,32073,0,0),
  (44959,12,0,-1,0,59812,0,0),
  (44960,12,0,0,4,46154,0,0),
  (44966,12,0,0,4,57852,0,0),
  (44968,12,0,0,4,23229,0,0),
  (44969,12,0,0,4,18098,0,0),
  (44975,12,0,-1,4,26571,0,0),
  (44976,12,0,0,4,57893,0,0),
  (44979,12,0,-1,4,57898,0,0),
  (44985,12,0,0,4,58862,0,0),
  (44995,12,0,0,4,57929,0,0),
  (44999,12,0,0,4,57936,0,0),
  (45027,12,0,0,4,57987,0,0),
  (45885,12,0,0,4,58615,0,0),
  (45898,12,0,0,4,21143,0,0),
  (45911,12,0,0,4,58655,0,0),
  (45944,12,0,0,4,3154,0,0),
  (46318,12,0,-1,4,59523,0,0),
  (46325,15,2,-1,2,67461,0,0),
  (46337,2,20,-1,2,20618,17,1),
  (46354,12,0,0,2,4664,0,0),
  (46355,12,0,0,2,59564,0,0),
  (46356,12,0,0,2,59565,0,0),
  (46363,12,0,0,4,4969,0,0),
  (46370,12,0,0,4,4969,0,0),
  (46384,12,0,0,4,30710,0,0),
  (46385,12,0,0,4,59669,0,0),
  (46386,12,0,0,4,59682,0,0),
  (46387,12,0,0,4,46851,0,0),
  (46388,12,0,0,4,70849,0,0),
  (46546,12,0,-1,0,59836,0,0),
  (46692,0,0,0,4,59851,0,0),
  (46695,12,0,-1,0,39631,0,0),
  (46696,0,0,0,4,59868,0,0),
  (52659,4,1,-1,7,69328,16,0),
  (52660,4,1,-1,7,23143,16,0),
  (52662,4,1,-1,7,69334,16,0),
  (52663,4,1,-1,7,69329,16,0),
  (52664,4,1,-1,7,69333,16,0),
  (52671,4,0,-1,0,64176,11,0),
  (52673,4,0,-1,0,24022,11,0),
  (52675,4,1,-1,7,69335,16,0),
  (55135,4,0,-1,3,53042,11,0),
  (58365,0,0,-1,4,54474,0,0),
  (64450,12,0,-1,4,74777,0,0);

-- ---------------------------------------------------------------------------
-- C) itemdisplayinfo_dbc overlay -- ONLY the 29 display ids we do not have.
--    The other 24 already exist with identical icons; they are left untouched.
-- ---------------------------------------------------------------------------
DELETE FROM `itemdisplayinfo_dbc` WHERE `ID` IN (
  57686, 57708, 57744, 57852, 57893, 57898, 57929, 57936, 57987, 58615, 
  58655, 58862, 59523, 59564, 59565, 59669, 59682, 59812, 59836, 59851, 
  59868, 67461, 69328, 69329, 69333, 69334, 69335, 70849, 74777
);

INSERT INTO `itemdisplayinfo_dbc`
    (`ID`,`InventoryIcon_1`,`GeosetGroup_1`,`GeosetGroup_2`,`GeosetGroup_3`,`Flags`,`SpellVisualID`,
     `GroupSoundIndex`,`HelmetGeosetVis_1`,`HelmetGeosetVis_2`,`ItemVisual`,`ParticleColorID`)
VALUES
  (57686,'INV_Misc_Plant_02',0,0,0,0,0,23,0,0,0,0),
  (57708,'INV_Misc_Pelt_Bear_Ruin_03',0,0,0,0,0,15,0,0,0,0),
  (57744,'INV_Elemental_Eternal_Air',0,0,0,0,0,24,0,0,0,0),
  (57852,'inv_misc_slime_02',0,0,0,0,0,15,0,0,0,0),
  (57893,'inv_mushroom_01',0,0,0,0,0,15,0,0,0,0),
  (57898,'inv_scroll_03',0,0,0,0,0,8,0,0,0,0),
  (57929,'spell_nature_dryaddispelmagic',0,0,0,0,0,13,0,0,0,0),
  (57936,'inv_torch_thrown',0,0,0,0,0,13,0,0,0,0),
  (57987,'inv_misc_monstertail_01',0,0,0,0,0,15,0,0,0,0),
  (58615,'inv_misc_leatherscrap_18',0,0,0,0,0,15,0,0,0,0),
  (58655,'inv_misc_root_02',0,0,0,0,0,13,0,0,0,0),
  (58862,'inv_ammo_arrow_03',0,0,0,0,0,14,0,0,0,0),
  (59523,'inv_letter_10',0,0,0,0,0,8,0,0,0,0),
  (59564,'spell_nature_wispsplode',0,0,0,0,0,0,0,0,0,0),
  (59565,'inv_elemental_mote_water01',0,0,0,0,0,0,0,0,0,0),
  (59669,'Ability_Repair',0,0,0,0,0,0,0,0,0,0),
  (59682,'inv_misc_token_argentdawn',0,0,0,0,0,0,0,0,0,0),
  (59812,'spell_nature_natureresistancetotem',0,0,0,0,0,22,0,0,0,0),
  (59836,'spell_frost_fireresistancetotem',0,0,0,0,0,22,0,0,0,0),
  (59851,'spell_fire_bluefire',0,0,0,0,0,12,0,0,0,0),
  (59868,'inv_jewelcrafting_blackpearlpanther',0,0,0,0,0,12,0,0,0,0),
  (67461,'ability_druid_forceofnature',0,0,0,0,0,12,0,0,0,0),
  (69328,'INV_Misc_Cape_11',2,0,0,0,0,7,0,0,0,0),
  (69329,'INV_Misc_Cape_11',2,0,0,0,0,7,0,0,0,0),
  (69333,'INV_Misc_Cape_11',2,0,0,0,0,7,0,0,0,0),
  (69334,'INV_Misc_Cape_11',2,0,0,0,0,7,0,0,0,0),
  (69335,'inv_misc_cape_06',2,0,0,0,0,7,0,0,0,0),
  (70849,'inv_misc_weathermachine_01',0,0,0,0,0,9,0,0,0,0),
  (74777,'trade_archaeology_highborne_scroll',0,0,0,0,0,8,0,0,0,0);
-- ---------------------------------------------------------------------------
-- D) gameobject_loot_template -- un-empty the 10 chests 184_ had to skip
-- ---------------------------------------------------------------------------
-- 184_ imported 753 Darkshore gameobjects but filtered 10 loot ids because
-- every one of them drops a single quest item that did not exist yet. Section A
-- just created all ten, so the rows can go in now. 306 spawns are affected:
--     26827 Encrusted Clam        x139     26821 Highborne Relic        x46
--     26825 Bear's Paw             x27     27217 Slain Wildkin Feather  x25
--     27237 Glittering Shell       x19     26866 Twilight Plans         x18
--     26867 Fuming Toadstool       x17     27249 Greymist Debris        x13+13
--     27011 Charred Book            x1     27250 Mud-Crusted Disc        x1
-- Copied straight from cata_world; the guard re-checks item existence so this
-- stays a no-op if section A is ever rolled back.
-- ---------------------------------------------------------------------------
DELETE FROM `gameobject_loot_template` WHERE `Entry` IN
    (26821, 26825, 26827, 26866, 26867, 27011, 27217, 27237, 27249, 27250);

INSERT INTO `gameobject_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT g.`Entry`, g.`Item`, g.`Reference`, g.`Chance`, g.`QuestRequired`, g.`LootMode`,
       g.`GroupId`, g.`MinCount`, g.`MaxCount`, 'Darkshore-Cata'
FROM `cata_world`.`gameobject_loot_template` g
WHERE g.`Entry` IN (26821, 26825, 26827, 26866, 26867, 27011, 27217, 27237, 27249, 27250)
  AND EXISTS (SELECT 1 FROM `item_template` it WHERE it.`entry` = g.`Item`);

-- ---------------------------------------------------------------------------
-- Verification after applying + client restart:
--   SELECT COUNT(*) FROM item_template WHERE entry IN (44830,44850,44864,58365,64450); -- 5
--   SELECT COUNT(*) FROM item_dbc      WHERE ID BETWEEN 44830 AND 64450;               -- >= 56
--   SELECT COUNT(*) FROM gameobject_loot_template WHERE Comment='Darkshore-Cata';      -- 10
--   -- every chest on map 750 now has loot (expect 0):
--   SELECT COUNT(DISTINCT gt.Data1) FROM gameobject g JOIN gameobject_template gt ON gt.entry=g.id
--    WHERE g.map=750 AND gt.type=3 AND gt.Data1>0
--      AND NOT EXISTS (SELECT 1 FROM gameobject_loot_template x WHERE x.Entry=gt.Data1);
--
-- In game: an Encrusted Clam on the Darkshore coast should now be lootable and
-- give "Encrusted Clam Muscle" with a real icon rather than the green question
-- mark.
-- ---------------------------------------------------------------------------
