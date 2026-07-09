-- =====================================================================
-- Mount Hyjal / Molten Front Downport  --  64  Missing quest item_template rows
-- ---------------------------------------------------------------------
-- 30 Cata 4.3.4 items that Hyjal (map 750) quest_template rows reference
-- (StartItem/RequiredItemId/ItemDrop/RewardChoiceItemID -- 25 broken quests,
-- see 63_quest_sort_and_reward_fixes.sql's sibling audit) but that were never
-- downported to acore_world.item_template, causing e.g.:
--   Quest 25272 has `StartItem` = 52682 but item with entry 52682 does not
--   exist, quest can't be done.
-- Source: real Cata 4.3.4 (build 15595/15601) Item.db2 + Item-sparse.db2,
-- extracted from the local K:/Cata client (StormLib, full patch-chain
-- resolved via wow-update-base-15601.MPQ -- see scratchpad
-- mpq_patchchain_extract.py / parse_item_sparse.py for the extraction +
-- decode pipeline, verified against known items Hearthstone/Healthstone/
-- Soul Shard before trusting it for these 30). Flags zeroed -- same
-- convention as Deepholm/03_item_templates.sql (Cata-era item-flag bits
-- don't map cleanly onto 3.3.5's ITEM_FLAGS enum).
--
-- itemdisplayinfo_dbc: real Cata ItemDisplayInfo.dbc rows for the 28 unique
-- display ids these items use. Most (17) are ICON-ONLY reuses of stock
-- WotLK icon names (e.g. INV_Potion_122, INV_Staff_02, Ability_Hunter_
-- BeastCall) that already exist in the 3.3.5 client -- those render
-- immediately. 7 items (57321,57339,57341,57349,57350,57364,57365) reference Track-A
-- Cata-only .mdx models (helm/shoulder/weapon geosets) and 3 (57336,57376,57379)
-- reference Track-B Cata-only glove textures -- those display ids are
-- correct/complete DBC data, but the actual model/texture/new-icon assets
-- (interface/icons/inv_*_cataclysm_b_01*.blp etc, plus the .mdx models)
-- still need extracting + packing into a client patch MPQ before they
-- render (same follow-up as the rest of the item-downport pipeline
-- documented in Custom/Documentation/Item_Downport_Wraith_Pipeline.md) --
-- NOT done here. Until then those items are correct/functional in-game
-- (grantable, stackable, statted right) but show the default
-- question-mark icon / no 3D model.
-- =====================================================================

-- ---------------------------------------------------------------------------
-- item_template
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` IN (52682,52717,52708,52730,53009,53464,53454,54574,55153,55178,55210,55211,56016,57297,57299,57321,57322,57335,57336,57339,57341,57349,57350,57364,57365,57374,57376,57377,57379,65662);

INSERT INTO `item_template`
(`entry`,`class`,`subclass`,`name`,`displayid`,`Quality`,`Flags`,`BuyCount`,`BuyPrice`,`SellPrice`,
 `InventoryType`,`ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`bonding`,`startquest`,`Material`,`sheath`,`VerifiedBuild`)
VALUES
(52682,12,0,'Lycanthoth''s Incense',65855,1,0,1,0,0,0,1,0,0,1,4,0,4,0,0),
(52717,0,0,'Fiery Leash',65913,1,0,1,0,0,0,1,1,1,1,4,0,4,0,0),
(52708,12,0,'Charred Basilisk Meat',39724,1,0,1,0,0,0,68,0,0,5,4,0,4,0,0),
(52730,12,0,'Cleansing Draught',37849,1,0,1,0,0,0,1,0,0,1,4,0,4,0,0),
(53009,0,0,'Juniper Berries',50879,1,0,1,0,0,0,1,1,0,4,4,0,4,0,0),
(53464,12,0,'Charred Branch',7866,1,0,1,0,0,0,1,0,1,1,4,0,7,0,0),
(53454,12,0,'Black Heart of Thol''embaar',54178,1,0,1,0,0,0,1,0,0,20,4,0,4,0,0),
(54574,12,0,'Hyjal Seedling',67192,1,0,1,0,0,0,1,0,0,10,4,0,4,0,0),
(55153,0,0,'Horn of Cenarius',54474,1,0,1,0,0,0,1,1,1,1,4,0,4,0,0),
(55178,0,0,'Pure Twilight Egg',40946,1,0,1,0,0,0,1,78,1,1,4,0,4,0,0),
(55210,12,0,'Ancient Feather',60990,1,0,1,0,0,0,1,0,1,1,4,0,4,0,0),
(55211,12,0,'Enormous Bird Call',30959,1,0,1,0,0,0,1,0,1,1,4,0,7,0,0),
(56016,12,0,'Herald''s Incense',67979,1,0,1,0,0,0,1,0,1,1,4,0,7,0,0),
(57297,4,11,'Azralon''s Twisted Rune',77162,2,0,1,250580,50116,28,285,0,0,1,1,0,2,0,0),
(57299,4,0,'Torque of the Herald',64199,2,0,1,238733,59683,2,272,0,0,1,1,0,4,0,0),
(57321,4,2,'Charbite Hood',72619,2,0,1,312153,62430,1,272,0,0,1,1,0,8,0,0),
(57322,4,0,'Signet of Nascent Fire',76516,2,0,1,238733,59683,11,272,0,0,1,1,0,3,0,0),
(57335,4,0,'Signet of Fragrant Summoning',79959,2,0,1,238733,59683,11,272,0,0,1,1,0,3,0,0),
(57336,4,2,'Skygrip Handguards',72624,2,0,1,204303,40860,10,272,0,0,1,1,0,8,0,0),
(57339,2,5,'Heartcrush Greathammer',68629,2,0,1,1032812,206562,17,272,0,0,1,1,0,1,1,0),
(57341,4,2,'Shoulderpads of Dead Memories',72620,2,0,1,312122,62424,3,272,0,0,1,1,0,8,0,0),
(57349,4,4,'Helm of the Mendicant',73141,2,0,1,417074,83414,1,272,0,0,1,1,0,6,0,0),
(57350,2,10,'Kindleprotector Staff',68721,2,0,1,998727,199745,17,272,0,0,1,1,0,2,2,0),
(57364,4,3,'Purifying Spaulders',72716,2,0,1,352898,70579,3,272,0,0,1,1,0,5,0,0),
(57365,2,4,'Crusher of Bonds',68136,2,0,1,783787,156757,13,272,0,0,1,1,0,1,3,0),
(57374,4,0,'Choker of Lo''Gosh',82367,2,0,1,238733,59683,2,272,0,0,1,1,0,4,0,0),
(57376,4,1,'Handguards of Restrained Brutality',72523,2,0,1,163393,32678,10,272,0,0,1,1,0,7,0,0),
(57377,4,0,'Goldrinn''s Locket',82367,2,0,1,238733,59683,2,272,0,0,1,1,0,4,0,0),
(57379,4,1,'Clutches of the Worgen Spirit',72523,2,0,1,165200,33040,10,272,0,0,1,1,0,7,0,0),
(65662,15,2,'Gold Mini Jouster',75155,1,0,1,5000,0,0,1,0,0,1,1,0,4,0,0);

-- ---------------------------------------------------------------------------
-- itemdisplayinfo_dbc (server-side mirror; add the matching Custom/CSV DBC/
-- ItemDisplayInfo.csv row + icon/model assets separately for client render)
-- ---------------------------------------------------------------------------
DELETE FROM `itemdisplayinfo_dbc` WHERE `ID` IN (7866,30959,37849,39724,40946,50879,54178,54474,60990,64199,65855,65913,67192,67979,68136,68629,68721,72523,72619,72620,72624,72716,73141,75155,76516,77162,79959,82367);

INSERT INTO `itemdisplayinfo_dbc`
(`ID`,`ModelName_1`,`ModelName_2`,`ModelTexture_1`,`ModelTexture_2`,`InventoryIcon_1`,`InventoryIcon_2`,
 `GeosetGroup_1`,`GeosetGroup_2`,`GeosetGroup_3`,`Flags`,`SpellVisualID`,`GroupSoundIndex`,
 `HelmetGeosetVis_1`,`HelmetGeosetVis_2`,`Texture_1`,`Texture_2`,`Texture_3`,`Texture_4`,`Texture_5`,
 `Texture_6`,`Texture_7`,`Texture_8`,`ItemVisual`,`ParticleColorID`)
VALUES
(7866,'','','','','INV_Staff_02','',0,0,0,0,0,13,0,0,'','','','','','','','',0,0),
(30959,'','','','','Ability_Hunter_BeastCall','',0,0,0,0,0,12,0,0,'','','','','','','','',0,0),
(37849,'','','','','INV_Potion_122','',0,0,0,0,0,17,0,0,'','','','','','','','',0,0),
(39724,'','','','','INV_Misc_Food_83_TalbukSteak','',0,0,0,0,0,15,0,0,'','','','','','','','',0,0),
(40946,'','','','','INV_Misc_ShadowEgg','',0,0,0,0,0,15,0,0,'','','','','','','','',0,0),
(50879,'','','','','INV_Misc_Food_104_TundraBerries','',0,0,0,0,0,16,0,0,'','','','','','','','',0,0),
(54178,'','','','','INV_Stone_WeightStone_08','',0,0,0,0,0,22,0,0,'','','','','','','','',0,0),
(54474,'','','','','INV_Misc_Horn_04','',0,0,0,0,0,9,0,0,'','','','','','','','',0,0),
(60990,'','','','','INV_Feather_01','',0,0,0,0,0,23,0,0,'','','','','','','','',0,0),
(64199,'','','','','inv_jewelry_necklace_52','',0,0,0,0,0,14,0,0,'','','','','','','','',0,0),
(65855,'','','','','inv_alchemy_enchantedvial','',0,0,0,0,0,22,0,0,'','','','','','','','',0,0),
(65913,'','','','','inv_belt_57.tga','',0,0,0,0,0,7,0,0,'','','','','','','','',0,0),
(67192,'','','','','inv_sigil_freya','',0,0,0,0,0,23,0,0,'','','','','','','','',0,0),
(67979,'','','','','inv_wand_24','',0,0,0,0,0,12,0,0,'','','','','','','','',0,0),
(68136,'mace_1h_cataclysm_b_01.mdx','','mace_1h_cataclysm_b_01','','inv_mace_1h_cataclysm_b_01','',0,0,0,0,0,8,0,0,'','','','','','','','',0,0),
(68629,'mace_2h_cataclysm_b_01.mdx','','mace_2h_cataclysm_b_01black','','inv_mace_2h_cataclysm_b_01','',0,0,0,0,0,9,0,0,'','','','','','','','',0,0),
(68721,'stave_2h_cataclysm_b_01.mdx','','stave_2h_cataclysm_b_01','','inv_stave_2h_cataclysm_b_01','',0,0,0,0,0,13,0,0,'','','','','','','','',0,0),
(72523,'','','','','inv_gauntlets_cloth_cataclysm_b_01','',0,0,0,0,0,7,0,0,'','cloth_cataclysm_b_01blue_Glove_AL','cloth_cataclysm_b_01blue_Glove_HA','','','','','',0,0),
(72619,'helm_leather_cataclysm_b_01.mdx','','helm_leather_cataclysm_b_01','','inv_helmet_leather_cataclysm_b_01','',0,0,0,0,0,7,246,307,'','','','','','','','',0,0),
(72620,'lshoulder_leather_cataclysm_b_01.mdx','rshoulder_leather_cataclysm_b_01.mdx','leather_cataclysm_b_01','leather_cataclysm_b_01','inv_shoulder_leather_cataclysm_b_01','',0,0,0,0,0,7,0,0,'','','','','','','','',0,0),
(72624,'','','','','inv_gauntlets_leather_cataclysm_b_01','',0,0,0,0,0,7,0,0,'','leather_cataclysm_b_01_Glove_AL','leather_cataclysm_b_01_Glove_HA','','','','','',0,0),
(72716,'lshoulder_mail_cataclysm_b_01.mdx','rshoulder_mail_cataclysm_b_01.mdx','shoulder_mail_cataclysm_b_01brown','shoulder_mail_cataclysm_b_01brown','inv_shoulder_150','',0,0,0,0,0,10,0,0,'','','','','','','','',0,0),
(73141,'helm_plate_cataclysm_b_01.mdx','','helm_plate_cataclysm_b_01black','','inv_helmet_189','',0,0,0,0,0,11,246,307,'','','','','','','','',0,0),
(75155,'','','','','ability_hunter_pet_vulture','',0,0,0,0,0,12,0,0,'','','','','','','','',0,0),
(76516,'','','','','inv_misc_moodring2','',0,0,0,0,0,14,0,0,'','','','','','','','',0,0),
(77162,'','','','','INV_Wand_02','',0,0,0,0,0,22,0,0,'','','','','','','','',0,0),
(79959,'','','','','inv_misc_starring3','',0,0,0,0,0,14,0,0,'','','','','','','','',0,0),
(82367,'','','','','inv_misc_necklacea2','',0,0,0,0,0,14,0,0,'','','','','','','','',0,0);
