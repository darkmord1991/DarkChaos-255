-- The 2 loot items the zones reference that exist in nelt_world but not acore (item ids kept verbatim).
INSERT IGNORE INTO acore_world.item_template
(`entry`,`class`,`subclass`,`name`,`displayid`,`Quality`,`Flags`,`BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`bonding`,`Material`,`sheath`,`VerifiedBuild`)
SELECT entry, class, subclass, name, displayid, Quality, Flags, BuyCount, BuyPrice, SellPrice, InventoryType, ItemLevel, RequiredLevel, maxcount, stackable, bonding, Material, sheath, 0
FROM nelt_world.item_template WHERE entry IN (53139,69679);

-- ============================================================================
-- 2026-07-03: 24 more reference_loot_template/creature_loot_template items
-- that are missing from item_template entirely (NOT present in nelt_world.item_template
-- either -- that table only has 884 rows and is a red herring for these). Authored from
-- nelt_world.`db_item-sparse_15595` (Cataclysm build 15595 ItemSparse.db2 dump, used as the
-- authoritative source for name/quality/stats/pricing -- these items were reclassified/
-- quality-demoted in modern retail as they became obsolete vendor loot, so the Cata-era
-- classification matches the ilvl/quality context of the loot tables they sit in).
-- IconFileDataID (for displayid minting) came from retail Item.csv (icon art is stable
-- across reclassification). displayid = 8,000,000 + IconFileDataID, same minting
-- convention as dc_item_downport_2026_07_03_fixes.sql's --fix-disp0 pass (icon-only
-- Track-C display, band disjoint from stock <=70k and retail <=~800k).
--
-- 63349 Flame-Scarred Junkbox: Cata sparse Lockid=1946 does not exist in this server's
-- Lock.dbc/Lock.csv -- left at 0 (unlocked/always-openable) rather than reference a
-- nonexistent lock. It also has no item_loot_template entry yet (right-click-open loot
-- contents are a separate authoring task, out of scope here -- icon/appearance only).
--
-- 67059 Halted Clock stat types 4/7/13/31 verified against src/server/game/Entities/Item/
-- ItemTemplate.h's ItemModType enum: 4=STRENGTH, 7=STAMINA, 13=DODGE_RATING,
-- 31=HIT_RATING -- all stable/unchanged between Cata and 3.3.5, so all 4 stats are kept
-- (note: type 4 is Strength, not Intellect).
-- ============================================================================
INSERT IGNORE INTO acore_world.item_template
(`entry`,`class`,`subclass`,`name`,`displayid`,`Quality`,`Flags`,`BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`stat_type1`,`stat_value1`,`stat_type2`,`stat_value2`,`stat_type3`,`stat_value3`,`stat_type4`,`stat_value4`,`bonding`,`Material`,`sheath`,`BagFamily`,`lockid`,`VerifiedBuild`)
VALUES
(52177,3,7,'Carnelian',8463896,2,0,1,0,5000,0,-1,81,0,0,20,0,0,0,0,0,0,0,0,0,-1,0,512,0,0),
(52178,3,7,'Zephyrite',8466283,2,0,1,0,5000,0,-1,81,0,0,20,0,0,0,0,0,0,0,0,0,-1,0,512,0,0),
(52179,3,7,'Alicite',8463564,2,0,1,0,5000,0,-1,81,0,0,20,0,0,0,0,0,0,0,0,0,-1,0,512,0,0),
(52180,3,7,'Nightstone',8463895,2,0,1,0,5000,0,-1,81,0,0,20,0,0,0,0,0,0,0,0,0,-1,0,512,0,0),
(52181,3,7,'Hessonite',8463897,2,0,1,0,5000,0,-1,81,0,0,20,0,0,0,0,0,0,0,0,0,-1,0,512,0,0),
(52182,3,7,'Jasper',8463894,2,0,1,0,5000,0,-1,81,0,0,20,0,0,0,0,0,0,0,0,0,-1,0,512,0,0),
(52190,3,7,'Inferno Ruby',8463891,3,0,1,0,32000,0,-1,85,0,0,20,0,0,0,0,0,0,0,0,0,-1,0,512,0,0),
(52191,3,7,'Ocean Sapphire',8463890,3,0,1,0,32000,0,-1,85,0,0,20,0,0,0,0,0,0,0,0,0,-1,0,512,0,0),
(52192,3,7,'Dream Emerald',8463889,3,0,1,0,32000,0,-1,85,0,0,20,0,0,0,0,0,0,0,0,0,-1,0,512,0,0),
(52193,3,7,'Ember Topaz',8463563,3,0,1,0,32000,0,-1,85,0,0,20,0,0,0,0,0,0,0,0,0,-1,0,512,0,0),
(52194,3,7,'Demonseye',8463892,3,0,1,0,32000,0,-1,85,0,0,20,0,0,0,0,0,0,0,0,0,-1,0,512,0,0),
(52195,3,7,'Amberjewel',8463893,3,0,1,0,32000,0,-1,85,0,0,20,0,0,0,0,0,0,0,0,0,-1,0,512,0,0),
(55975,15,0,'Inert Elemental Grain',8132872,0,0,1,588,147,0,-1,1,0,0,20,0,0,0,0,0,0,0,0,0,4,0,0,0,0),
(55978,15,0,'Inert Elemental Flake',8132872,0,0,1,960,240,0,-1,1,0,0,20,0,0,0,0,0,0,0,0,0,4,0,0,0,0),
(55982,15,0,'Inert Elemental Granule',8132872,0,0,1,280,70,0,-1,1,0,0,20,0,0,0,0,0,0,0,0,0,4,0,0,0,0),
(60863,12,0,'Time-Worn Breastplate',8133823,1,65536,1,0,0,0,-1,1,1,0,20,0,0,0,0,0,0,0,0,4,4,0,0,0,0),
(60864,12,0,'Rusted Sword',8135357,1,65536,1,0,0,0,-1,1,1,0,20,0,0,0,0,0,0,0,0,4,4,0,0,0,0),
(63292,0,5,'Disgusting Rotgut',8461805,1,0,1,150,37,0,-1,1,0,0,20,0,0,0,0,0,0,0,0,0,3,0,0,0,0),
(63300,0,1,'Rogue\'s Draught',8134804,1,0,1,24000,6000,0,8,81,80,0,20,0,0,0,0,0,0,0,0,1,3,0,0,0,0),
(63311,15,0,'Reddish Mud',8133748,0,0,1,80,20,0,-1,1,0,0,20,0,0,0,0,0,0,0,0,0,4,1,0,0,0),
(63323,15,0,'Pry Stone',8135241,0,0,1,80,20,0,-1,1,0,0,20,0,0,0,0,0,0,0,0,0,4,1,0,0,0),
(63341,15,0,'Tickling Feather',8132917,0,0,1,80,20,0,-1,1,0,0,20,0,0,0,0,0,0,0,0,0,4,1,0,0,0),
(63349,15,0,'Flame-Scarred Junkbox',8132597,1,4,1,0,0,0,-1,80,0,1,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0),
(67059,4,0,'Halted Clock',8136106,3,524288,1,348379,69675,28,32767,325,84,1,1,4,78,7,118,13,52,31,52,2,2,0,0,0,0);

-- sItemStore (server-side, DBCStores.cpp LOAD_DBC macro) is file+overlay: DBCDatabaseLoader
-- grows the index table to fit IDs not present in Item.dbc, so adding rows to the item_dbc /
-- itemdisplayinfo_dbc overlay tables is sufficient to make sItemStore.LookupEntry() resolve
-- these 24 items after a worldserver restart -- no binary Server/data/dbc/Item.dbc merge
-- needed (that file still holds the 231,417 ItemUpgrade clone records untouched).
-- 8135241 (Pry Stone's minted display) is already present in itemdisplayinfo_dbc from the
-- 2026-07-03 --fix-disp0 pass (same icon, inv_stone_15, reused verbatim) -- not re-inserted.
INSERT IGNORE INTO acore_world.item_dbc
(`ID`,`ClassID`,`SubclassID`,`Sound_Override_Subclassid`,`Material`,`DisplayInfoID`,`InventoryType`,`SheatheType`)
VALUES
(52177,3,7,-1,-1,8463896,0,0),
(52178,3,7,-1,-1,8466283,0,0),
(52179,3,7,-1,-1,8463564,0,0),
(52180,3,7,-1,-1,8463895,0,0),
(52181,3,7,-1,-1,8463897,0,0),
(52182,3,7,-1,-1,8463894,0,0),
(52190,3,7,-1,-1,8463891,0,0),
(52191,3,7,-1,-1,8463890,0,0),
(52192,3,7,-1,-1,8463889,0,0),
(52193,3,7,-1,-1,8463563,0,0),
(52194,3,7,-1,-1,8463892,0,0),
(52195,3,7,-1,-1,8463893,0,0),
(55975,15,0,-1,4,8132872,0,0),
(55978,15,0,-1,4,8132872,0,0),
(55982,15,0,-1,4,8132872,0,0),
(60863,12,0,-1,4,8133823,0,0),
(60864,12,0,-1,4,8135357,0,0),
(63292,0,5,-1,3,8461805,0,0),
(63300,0,1,-1,3,8134804,0,0),
(63311,15,0,-1,4,8133748,0,1),
(63323,15,0,-1,4,8135241,0,1),
(63341,15,0,-1,4,8132917,0,1),
(63349,15,0,-1,1,8132597,0,0),
(67059,4,0,-1,2,8136106,28,0);

INSERT IGNORE INTO acore_world.itemdisplayinfo_dbc
(`ID`,`ModelName_1`,`ModelName_2`,`ModelTexture_1`,`ModelTexture_2`,`InventoryIcon_1`,`InventoryIcon_2`,`GeosetGroup_1`,`GeosetGroup_2`,`GeosetGroup_3`,`Flags`,`SpellVisualID`,`GroupSoundIndex`,`HelmetGeosetVis_1`,`HelmetGeosetVis_2`,`Texture_1`,`Texture_2`,`Texture_3`,`Texture_4`,`Texture_5`,`Texture_6`,`Texture_7`,`Texture_8`,`ItemVisual`,`ParticleColorID`)
VALUES
(8463896,'','','','','inv_misc_uncutgemsuperior4','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8466283,'','','','','inv_misc_uncutgemsuperior6','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8463564,'','','','','inv_misc_uncutgemsuperior','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8463895,'','','','','inv_misc_uncutgemsuperior3','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8463897,'','','','','inv_misc_uncutgemsuperior5','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8463894,'','','','','inv_misc_uncutgemsuperior2','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8463891,'','','','','inv_misc_uncutgemnormal3','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8463890,'','','','','inv_misc_uncutgemnormal2','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8463889,'','','','','inv_misc_uncutgemnormal1','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8463563,'','','','','inv_misc_uncutgemnormal','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8463892,'','','','','inv_misc_uncutgemnormal4','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8463893,'','','','','inv_misc_uncutgemnormal5','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8132872,'','','','','inv_enchant_prismaticsphere','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8133823,'','','','','inv_misc_desecrated_mailchest','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8135357,'','','','','inv_sword_47','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8461805,'','','','','inv_drink_32_disgustingrotgut','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8134804,'','','','','inv_potion_24','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8133748,'','','','','inv_misc_bowl_01','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8132917,'','','','','inv_feather_04','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8132597,'','','','','inv_box_04','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0),
(8136106,'','','','','spell_nature_timestop','',0,0,0,0,0,0,0,0,'','','','','','','','',0,0);
