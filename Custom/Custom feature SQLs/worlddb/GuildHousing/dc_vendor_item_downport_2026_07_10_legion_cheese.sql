-- ---------------------------------------------------------------------------
-- item_template additions  --  3 more vendor items missing (Legion Dalaran)
-- ---------------------------------------------------------------------------
-- Follow-up to dc_vendor_item_downport_2026_07_10.sql: 3 cheese items
-- referenced by the REAL LegionCore npc_vendor data for Nomi (295) and Mel
-- Lynchen (483) (recovered from K:/Dark-Chaos/legion stuff/LegionCore-7.3.5-
-- master/sql/base/LegionCore_world_2020_04_25.sql -- the source dump is NOT
-- lost after all, just nested one level deeper than first searched).
-- Sourced the same way as the other 19: real retail client ItemSparse/Item
-- CSVs + icon extraction, no use-effect spellids fabricated.
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` IN (58259,81921,81922);

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,
     `BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,
     `maxcount`,`stackable`,`ContainerSlots`,`bonding`,`Material`,`sheath`,`VerifiedBuild`)
VALUES
(58259,0,5,-1,'Highland Sheep Cheese',8133947,1,0,0,1,20000,1000,0,-1,-1,32,32,0,20,0,0,4,0,0),
(81921,0,5,-1,'Chilton Stilton',8133955,1,0,0,1,25600,1280,0,-1,-1,35,32,0,20,0,0,4,0,0),
(81922,0,5,-1,'Redridge Roquefort',8133954,1,0,0,1,22400,1120,0,-1,-1,32,30,0,20,0,0,4,0,0);
