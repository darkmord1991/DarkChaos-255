-- ---------------------------------------------------------------------------
-- item_template additions  --  19 vendor items missing from item_template
-- ---------------------------------------------------------------------------
-- Referenced by nelt_world.npc_vendor lists for several Deepholm/Hyjal/
-- Plaguelands vendor NPCs but never downported (cata_world has no item_template
-- at all, and these ids simply weren't part of any prior item-downport batch).
-- Sourced from the real retail client (ItemSparse/Item DB2, build 12.0.7 --
-- pre-decoded CSVs already cached at K:/Dark-Chaos/retailextracts/, since the
-- live build's Item.db2 is TACT-encrypted). All 19 are simple vendor trash
-- (food/drink, a couple of enchanting reagents, a 14-slot BoP hunting bag, and
-- 7 Firelands/Avengers-of-Hyjal reputation-vendor recipe-unlock tokens) -- no
-- use-effect spellids are set (shipping honest inert flavor/vendor items rather
-- than fabricating an unverified spell effect). Icons (not full 3D models --
-- none of these are equippable/worn) extracted from the live retail client and
-- minted as icon-only ItemDisplayInfo rows (displayid = 8,000,000 + IconFileDataID,
-- matching this project's existing --fix-disp0 convention). 62367 and 68765 are
-- both "Arcanum of Hyjal" (Alliance/Horde-flavored duplicates in retail) and
-- share the same icon/displayid on purpose.
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` IN (58257,58274,58275,58279,59227,59228,59229,59231,59232,60335,62367,63388,64670,68765,71567,71577,71580,71587,71590);

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,
     `BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,
     `maxcount`,`stackable`,`ContainerSlots`,`bonding`,`Material`,`sheath`,`VerifiedBuild`)
VALUES
(58257,0,5,-1,'Highland Spring Water',8132826,1,0,0,1,13750,687,0,-1,-1,32,32,0,20,0,0,3,0,0),
(58274,0,5,-1,'Fresh Water',8132820,1,0,0,1,11000,550,0,-1,-1,28,27,0,20,0,0,3,0,0),
(58275,0,5,-1,'Hardtack',8134051,1,0,0,1,16000,800,0,-1,-1,28,27,0,20,0,0,4,0,0),
(58279,0,5,-1,'Tasty Puffball',8134533,1,0,0,1,16000,800,0,-1,-1,28,27,0,20,0,0,4,0,0),
(59227,0,5,-1,'Rock-Hard Biscuit',8135242,1,0,0,1,16000,800,0,-1,-1,28,27,0,20,0,0,4,0,0),
(59228,0,5,-1,'Vile Purple Fungus',8237413,1,0,0,1,18000,900,0,-1,-1,30,30,0,20,0,0,4,0,0),
(59229,0,5,-1,'Murky Water',8132825,1,0,0,1,11000,550,0,-1,-1,28,27,0,20,0,0,3,0,0),
(59231,0,5,-1,'Oily Giblets',8134343,1,0,0,1,16000,800,0,-1,-1,28,27,0,20,0,0,4,0,0),
(59232,0,5,-1,'Unidentifiable Meat Dish',8350561,1,0,0,1,18000,900,0,-1,-1,30,30,0,20,0,0,4,0,0),
(60335,1,0,-1,'Thick Hide Pack',8348519,1,0,0,1,120000,30000,18,-1,-1,30,0,0,1,14,2,8,0,0),
(62367,12,0,-1,'Arcanum of Hyjal',8135820,0,0,0,1,1000000,250000,0,-1,-1,32,32,0,1,0,1,4,0,0),
(63388,15,1,-1,'Dust of Disappearance',8236758,0,0,0,1,4500,1125,0,-1,-1,30,0,0,20,0,0,7,0,0),
(64670,15,1,-1,'Vanishing Powder',8133849,1,0,0,1,4000,61,0,-1,-1,7,0,0,20,0,0,7,0,0),
(68765,12,0,-1,'Arcanum of Hyjal',8135820,0,0,0,1,1000000,250000,0,-1,-1,32,32,0,1,0,1,4,0,0),
(71567,15,0,-1,'Covenant of the Flame',8237450,0,0,0,1,932806,186561,0,-1,-1,37,0,0,1,0,1,2,0,0),
(71577,15,0,-1,'Singed Plume of Aviana',8132919,0,0,0,1,932806,186561,0,-1,-1,37,0,0,1,0,1,2,0,0),
(71580,15,0,-1,'Soulflame Vial',8443371,0,0,0,1,932806,186561,0,-1,-1,37,0,0,1,0,1,2,0,0),
(71587,15,0,-1,'Relic of the Elemental Lords',8135824,0,0,0,1,932806,186561,0,-1,-1,37,0,0,1,0,1,2,0,0),
(71590,15,0,-1,'Deathclutch Figurine',8134451,0,0,0,1,943534,188706,0,-1,-1,37,0,0,1,0,1,2,0,0);
