-- ---------------------------------------------------------------------------
-- 192  Felwood Cata quest items -- 46 items downported
-- ---------------------------------------------------------------------------
-- Stage 1 of the Felwood Cata quest layer, mirroring what 189_ did for
-- Darkshore. 181_/183_ imported Felwood's Cata creature layer (Whisperwind
-- Grove, Wildheart Point, Irontree Clearing) but no quests; 193_ brings the
-- quests, and they reference 46 items we do not have.
--
-- SOURCE -- the untouched 4.3.4 client at K:\UntouchedClients\Cata:
--     Data\wow-update-base-15601.MPQ -> DBFilesClient\Item.db2 (build 15595)
--                                    -> DBFilesClient\ItemDisplayInfo.dbc
-- All 46 resolve there, and so do all 41 display ids they use, with real icon
-- NAMES (retail stores icons as FileDataIDs and loses them). Names, quality,
-- stackable and bonding come from `nelt_world`.`db_item-sparse_15595` via
-- INSERT...SELECT so 46 item names are never hand-transcribed.
--
-- DISPLAY-ID COLLISION CHECK: of the 41 display ids, 22 already exist here and
-- every one has a BYTE-IDENTICAL icon name to Cata's -- they are the same rows
-- inherited from WotLK. ZERO clashed. Only the other 19 are inserted.
--
-- Flags/FlagsExtra forced to 0: Cata added new bits to both, so raw values do
-- not mean the same thing in 3.3.5. Same precedent as 189_ and
-- CastleNathria/20_missing_trash_items.sql.
--
-- NOTE 62820 "Honey Glob" is in this batch. Together with quests 27989 and
-- 27995 (in 193_) it finally makes the three CataTC Ruumbo scripts reachable --
-- they were deliberately skipped in 186_ as dead code precisely because this
-- item and those quests were missing.
--
-- Apply against acore_world. Item.dbc and ItemDisplayInfo.dbc are ALSO updated
-- and deployed, so a CLIENT RESTART is required. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) item_template
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` IN (
  62819, 62820, 62899, 62918, 62919, 62920, 63031, 63032, 63078, 63088,
  63091, 63123, 63279, 63284, 63332, 63395, 63419, 63513, 63514, 63516,
  63519, 63522, 63687, 63688, 63689, 63695, 63698, 64300, 64301, 65285,
  65286, 65305, 65306, 65311, 65317, 65319, 65324, 65325, 65330, 65333,
  65336, 65342, 65349, 65352, 65354, 65357);

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,
     `BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,
     `RequiredLevel`,`maxcount`,`stackable`,`ContainerSlots`,`bonding`,`Material`,`sheath`,`VerifiedBuild`)
SELECT m.`entry`, m.`cls`, m.`sub`, m.`snd`, s.`Name`, m.`disp`, s.`Quality`, 0, 0,
       1, s.`Buyprice`, s.`Sellprice`, m.`inv`, s.`Allowableclass`, s.`Allowablerace`, s.`Itemlevel`,
       s.`Requiredlevel`, s.`Maxcount`, s.`Stackable`, s.`Containerslots`, s.`Bonding`, m.`mat`, m.`sheath`, 15595
FROM (
SELECT * FROM (VALUES
  ROW(62819,12,0,-1,4,928,0,0),
  ROW(62820,12,0,-1,4,67464,0,0),
  ROW(62899,12,0,-1,4,33941,0,0),
  ROW(62918,12,0,-1,4,2637,0,0),
  ROW(62919,12,0,-1,4,73015,0,0),
  ROW(62920,12,0,-1,4,37854,0,0),
  ROW(63031,12,0,-1,4,73015,0,0),
  ROW(63032,12,0,-1,4,13489,0,0),
  ROW(63078,12,0,-1,4,19566,0,0),
  ROW(63088,12,0,-1,4,6685,0,0),
  ROW(63091,12,0,-1,4,57518,0,0),
  ROW(63123,12,0,-1,4,8560,0,0),
  ROW(63279,12,0,-1,4,73381,0,0),
  ROW(63284,12,0,-1,4,73381,0,0),
  ROW(63332,12,0,-1,4,73399,0,0),
  ROW(63395,12,0,-1,4,73468,0,0),
  ROW(63419,12,0,-1,4,1329,0,0),
  ROW(63513,12,0,-1,4,73507,0,0),
  ROW(63514,12,0,-1,4,73508,0,0),
  ROW(63516,12,0,-1,4,73509,0,0),
  ROW(63519,12,0,-1,4,58677,0,0),
  ROW(63522,12,0,-1,4,73513,0,0),
  ROW(63687,12,0,-1,0,8560,0,0),
  ROW(63688,12,0,-1,4,68100,0,0),
  ROW(63689,12,0,-1,4,73545,0,0),
  ROW(63695,12,0,-1,4,23741,0,0),
  ROW(63698,12,0,-1,4,61075,0,0),
  ROW(64300,12,0,-1,4,928,0,0),
  ROW(64301,12,0,-1,4,73509,0,0),
  ROW(65285,4,1,-1,7,76674,16,0),
  ROW(65286,4,0,-1,8,21975,12,0),
  ROW(65305,4,0,-1,4,52417,2,0),
  ROW(65306,4,0,-1,2,76734,2,0),
  ROW(65311,4,1,-1,7,76686,16,0),
  ROW(65317,4,0,-1,3,45948,11,0),
  ROW(65319,4,0,-1,4,48510,2,0),
  ROW(65324,4,0,-1,3,64176,11,0),
  ROW(65325,4,0,-1,3,35431,11,0),
  ROW(65330,4,0,-1,3,33856,11,0),
  ROW(65333,4,0,-1,3,31655,11,0),
  ROW(65336,4,1,-1,7,76672,16,0),
  ROW(65342,4,1,-1,7,76675,16,0),
  ROW(65349,4,1,-1,7,76697,16,0),
  ROW(65352,4,0,-1,3,3258,11,0),
  ROW(65354,4,1,-1,7,76676,16,0),
  ROW(65357,4,0,-1,4,26551,12,0)
) AS t(`entry`,`cls`,`sub`,`snd`,`mat`,`disp`,`inv`,`sheath`)
) m
JOIN `nelt_world`.`db_item-sparse_15595` s ON s.`ID` = m.`entry`;

-- ---------------------------------------------------------------------------
-- B) item_dbc overlay -- so sItemStore resolves these server-side
-- ---------------------------------------------------------------------------
DELETE FROM `item_dbc` WHERE `ID` IN (
  62819, 62820, 62899, 62918, 62919, 62920, 63031, 63032, 63078, 63088,
  63091, 63123, 63279, 63284, 63332, 63395, 63419, 63513, 63514, 63516,
  63519, 63522, 63687, 63688, 63689, 63695, 63698, 64300, 64301, 65285,
  65286, 65305, 65306, 65311, 65317, 65319, 65324, 65325, 65330, 65333,
  65336, 65342, 65349, 65352, 65354, 65357);

INSERT INTO `item_dbc`
    (`ID`,`ClassID`,`SubclassID`,`Sound_Override_Subclassid`,`Material`,`DisplayInfoID`,`InventoryType`,`SheatheType`)
VALUES
  (62819,12,0,-1,4,928,0,0),
  (62820,12,0,-1,4,67464,0,0),
  (62899,12,0,-1,4,33941,0,0),
  (62918,12,0,-1,4,2637,0,0),
  (62919,12,0,-1,4,73015,0,0),
  (62920,12,0,-1,4,37854,0,0),
  (63031,12,0,-1,4,73015,0,0),
  (63032,12,0,-1,4,13489,0,0),
  (63078,12,0,-1,4,19566,0,0),
  (63088,12,0,-1,4,6685,0,0),
  (63091,12,0,-1,4,57518,0,0),
  (63123,12,0,-1,4,8560,0,0),
  (63279,12,0,-1,4,73381,0,0),
  (63284,12,0,-1,4,73381,0,0),
  (63332,12,0,-1,4,73399,0,0),
  (63395,12,0,-1,4,73468,0,0),
  (63419,12,0,-1,4,1329,0,0),
  (63513,12,0,-1,4,73507,0,0),
  (63514,12,0,-1,4,73508,0,0),
  (63516,12,0,-1,4,73509,0,0),
  (63519,12,0,-1,4,58677,0,0),
  (63522,12,0,-1,4,73513,0,0),
  (63687,12,0,-1,0,8560,0,0),
  (63688,12,0,-1,4,68100,0,0),
  (63689,12,0,-1,4,73545,0,0),
  (63695,12,0,-1,4,23741,0,0),
  (63698,12,0,-1,4,61075,0,0),
  (64300,12,0,-1,4,928,0,0),
  (64301,12,0,-1,4,73509,0,0),
  (65285,4,1,-1,7,76674,16,0),
  (65286,4,0,-1,8,21975,12,0),
  (65305,4,0,-1,4,52417,2,0),
  (65306,4,0,-1,2,76734,2,0),
  (65311,4,1,-1,7,76686,16,0),
  (65317,4,0,-1,3,45948,11,0),
  (65319,4,0,-1,4,48510,2,0),
  (65324,4,0,-1,3,64176,11,0),
  (65325,4,0,-1,3,35431,11,0),
  (65330,4,0,-1,3,33856,11,0),
  (65333,4,0,-1,3,31655,11,0),
  (65336,4,1,-1,7,76672,16,0),
  (65342,4,1,-1,7,76675,16,0),
  (65349,4,1,-1,7,76697,16,0),
  (65352,4,0,-1,3,3258,11,0),
  (65354,4,1,-1,7,76676,16,0),
  (65357,4,0,-1,4,26551,12,0);

-- ---------------------------------------------------------------------------
-- C) itemdisplayinfo_dbc overlay -- ONLY the 19 display ids we lack
-- ---------------------------------------------------------------------------
DELETE FROM `itemdisplayinfo_dbc` WHERE `ID` IN (
  61075, 67464, 68100, 73015, 73381, 73399, 73468, 73507, 73508, 73509,
  73513, 73545, 76672, 76674, 76675, 76676, 76686, 76697, 76734);

INSERT INTO `itemdisplayinfo_dbc`
    (`ID`,`InventoryIcon_1`,`GeosetGroup_1`,`GeosetGroup_2`,`GeosetGroup_3`,`Flags`,`SpellVisualID`,
     `GroupSoundIndex`,`HelmetGeosetVis_1`,`HelmetGeosetVis_2`,`ItemVisual`,`ParticleColorID`)
VALUES
  (61075,'inv_gizmo_zapthrottlegascollector',0,0,0,0,0,9,0,0,0,0),
  (67464,'inv_inscription_pigment_golden',0,0,0,0,0,15,0,0,0,0),
  (68100,'inv_drink_waterskin_03',0,0,0,0,0,17,0,0,0,0),
  (73015,'inv_misc_cat_trinket07',0,0,0,0,0,21,0,0,0,0),
  (73381,'inv_jewelry_ring_12',0,0,0,0,0,8,0,0,0,0),
  (73399,'inv_alchemy_enchantedvial',0,0,0,0,0,8,0,0,0,0),
  (73468,'inv_enchant_shardprismaticlarge',0,0,0,0,0,21,0,0,0,0),
  (73507,'inv_misc_hook_01',0,0,0,0,0,7,0,0,0,0),
  (73508,'spell_fire_flare',0,0,0,0,0,8,0,0,0,0),
  (73509,'inv_misc_bomb_01',0,0,0,0,0,18,0,0,0,0),
  (73513,'spell_fire_felflamering',0,0,0,0,0,21,0,0,0,0),
  (73545,'inv_mace_06',0,0,0,0,0,13,0,0,0,0),
  (76672,'inv_misc_cape_03',1,0,0,0,0,7,0,0,0,0),
  (76674,'inv_misc_cape_21',2,0,0,0,0,7,0,0,0,0),
  (76675,'inv_misc_cape_09',1,0,0,0,0,7,0,0,0,0),
  (76676,'inv_misc_cape_26',3,0,0,0,0,7,0,0,0,0),
  (76686,'inv_misc_cape_20',1,0,0,0,0,7,0,0,0,0),
  (76697,'INV_Misc_Cape_14',3,0,0,0,0,7,0,0,0,0),
  (76734,'inv_jewelry_necklace_24',0,0,0,0,0,12,0,0,0,0);

-- ---------------------------------------------------------------------------
-- Verification after applying + client restart:
--   SELECT COUNT(*) FROM item_template WHERE entry IN (62819,62820,65357);  -- 3
--   SELECT COUNT(*) FROM item_dbc WHERE ID BETWEEN 62819 AND 65357;         -- >= 46
--   SELECT entry, name, displayid FROM item_template WHERE entry = 62820;   -- Honey Glob
-- ---------------------------------------------------------------------------
