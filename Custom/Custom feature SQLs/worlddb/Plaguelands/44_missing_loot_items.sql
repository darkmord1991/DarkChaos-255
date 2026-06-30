-- The 2 loot items the zones reference that exist in nelt_world but not acore (item ids kept verbatim).
INSERT IGNORE INTO acore_world.item_template
(`entry`,`class`,`subclass`,`name`,`displayid`,`Quality`,`Flags`,`BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`bonding`,`Material`,`sheath`,`VerifiedBuild`)
SELECT entry, class, subclass, name, displayid, Quality, Flags, BuyCount, BuyPrice, SellPrice, InventoryType, ItemLevel, RequiredLevel, maxcount, stackable, bonding, Material, sheath, 0
FROM nelt_world.item_template WHERE entry IN (53139,69679);
