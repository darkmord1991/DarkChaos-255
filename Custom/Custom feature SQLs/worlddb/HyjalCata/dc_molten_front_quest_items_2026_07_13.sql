-- ---------------------------------------------------------------------------
-- item_template additions -- 47 missing Molten Front / Hyjal quest items
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13): "Loading Quests..." boot log --
-- StartItem/RequiredItemId/ItemDrop/RewardChoiceItemId/RewardItemId references
-- to 47 items missing from item_template (cata_world has no item_template
-- table; nelt_world only had 2 of the 49 originally checked -- see the
-- companion 69765/69816 nelt_world-sourced rows applied separately). Sourced
-- from the real retail client ItemSparse/Item CSVs, same pipeline as every
-- other item downport this session. Mix of plain quest tokens (class 12,
-- bonding=4, no stats) and real armor/jewelry/consumable reward-choice items
-- (class 4/0, real ItemLevel/Quality/price from retail -- no sibling rows
-- existed in this DB to match a placeholder convention against, unlike the
-- Plaguelands reward set, so these ship with their real retail stats/price
-- data as-is; no stat_type/value fields populated, matching every other
-- hand-authored item this session). Icon-only ItemDisplayInfo minted the
-- same way (8,000,000 + IconFileDataID); icons + Item.dbc/ItemDisplayInfo.dbc
-- deployed to patch-4.MPQ + patch-enGB-3.MPQ + server mirror + all 3
-- WarcraftXLHost dirs, checksum-verified.
-- ---------------------------------------------------------------------------

DELETE FROM `item_template` WHERE `entry` IN (62387,62997,62996,62969,61377,61309,62979,62978,64641,61283,61284,61285,61280,61281,61036,61037,61038,62965,62962,60850,60770,60771,62198,62180,62959,62167,62164,61920,60861,61302,62984,62982,62995,62992,61318,61379,63022,63018,62966,61959,61960,61961,61962,60866,60984,62957,63023);

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,
     `BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,
     `maxcount`,`stackable`,`ContainerSlots`,`bonding`,`Material`,`sheath`,`VerifiedBuild`)
VALUES
(62387,12,0,-1,'Dolph''s Package',8132761,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(62997,4,1,-1,'Cloak of the Reverend',8133775,3,0,0,1,692980,138596,16,-1,-1,23,0,0,1,0,1,7,0,0),
(62996,4,0,-1,'Band of Zeal',8133346,3,0,0,1,14133,2826,11,-1,-1,23,0,0,1,0,1,3,0,0),
(62969,4,0,-1,'Korfax''s Signet',8133385,2,0,0,1,12352,2470,11,-1,-1,23,0,0,1,0,1,3,0,0),
(61377,12,0,-1,'The Baroness'' Missive',8134327,1,0,0,1,0,0,0,-1,-1,1,1,1,1,0,4,4,0,0),
(61309,12,0,-1,'Argent Scroll',8237450,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(62979,4,1,-1,'Rimblat''s Cloak',8133776,2,0,0,1,481185,96237,16,-1,-1,23,0,0,1,0,1,7,0,0),
(62978,4,0,-1,'Devourer''s Stomach',8237414,2,0,0,1,16182,3236,12,-1,-1,23,0,0,1,0,1,8,0,0),
(64641,0,5,-1,'"Delicious" Worm Steak',8133970,1,0,0,1,1200,300,0,-1,-1,11,11,0,20,0,1,4,0,0),
(61283,12,0,-1,'Death Cultist Disguise',8340017,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(61284,12,0,-1,'Betina''s Flasks',8134786,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(61285,12,0,-1,'Active Liquid Plague Agent',8134782,1,0,0,1,0,0,0,-1,-1,1,1,0,20,0,4,4,0,0),
(61280,12,0,-1,'Death Cultist Headwear',8340019,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(61281,12,0,-1,'Death Cultist Robes',8340017,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(61036,12,0,-1,'Rayne''s Seeds',8133668,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(61037,12,0,-1,'Plague Disseminator Control Rune',8132784,1,0,0,1,0,0,0,-1,-1,1,1,0,5,0,4,4,0,0),
(61038,12,0,-1,'Overcharged Mote',8136049,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(62965,4,0,-1,'Ring of New Life',8133406,2,0,0,1,10919,2183,11,-1,-1,22,0,0,1,0,1,3,0,0),
(62962,4,1,-1,'Fungal Vale Cloak',8133766,2,0,0,1,379426,75885,16,-1,-1,22,0,0,1,0,1,7,0,0),
(60850,12,0,-1,'Brownfeather Quill',8132922,1,0,0,1,0,0,0,-1,-1,1,1,0,20,0,4,4,0,0),
(60770,12,0,-1,'Gahrron Prayer Book',8133743,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(60771,12,0,-1,'Faded Finger Painting',8134941,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(62198,4,0,-1,'Andrea''s Locket',8133303,2,0,0,1,6772,1354,2,-1,-1,21,0,0,1,0,1,4,0,0),
(62180,4,0,-1,'Band of the Arachnid Wrangler',8133344,2,0,0,1,10004,2000,11,-1,-1,21,0,0,1,0,1,3,0,0),
(62959,4,0,-1,'Hidden Treasure',8133384,3,0,0,1,12820,2564,11,-1,-1,22,0,0,1,0,1,3,0,0),
(62167,4,1,-1,'Cloak of the Unrestful',8133757,2,0,0,1,149077,29815,16,-1,-1,21,0,0,1,0,1,7,0,0),
(62164,4,0,-1,'Valorfist Band',8133346,2,0,0,1,9185,1837,11,-1,-1,21,0,0,1,0,1,3,0,0),
(61920,12,0,-1,'Chillwind Tribute',8133788,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(60861,12,0,-1,'Holy Thurible',8132771,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(61302,12,0,-1,'Light-Touched Blades',8236273,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(62984,4,0,-1,'Omarion''s Gift',8134499,2,0,0,1,16542,3308,12,-1,-1,23,0,0,1,0,1,4,0,0),
(62982,4,0,-1,'Light-Touched Pendant',8133278,2,0,0,1,8210,1642,2,-1,-1,23,0,0,1,0,1,4,0,0),
(62995,4,0,-1,'Underlord''s Mandible',8237391,2,0,0,1,16000,3200,12,-1,-1,23,0,0,1,0,1,2,0,0),
(62992,4,0,-1,'Pendant of the Ill-Advised',8133303,2,0,0,1,7910,1582,2,-1,-1,23,0,0,1,0,1,4,0,0),
(61318,12,0,-1,'Gidwin''s Prayer Book',8133745,1,0,0,1,0,0,0,-1,-1,1,1,0,1,0,4,4,0,0),
(61379,12,0,-1,'Gidwin''s Hearthstone',8413582,1,0,0,1,0,0,0,-1,-1,1,1,1,1,0,4,4,0,0),
(63022,4,0,-1,'Gidwin''s Medallion',8133278,3,0,0,1,11273,2254,2,-1,-1,24,0,0,1,0,1,4,0,0),
(63018,4,0,-1,'Tarenar''s Token',8133391,3,0,0,1,15875,3175,11,-1,-1,24,0,0,1,0,1,3,0,0),
(62966,4,0,-1,'Emissary''s Watch',8134376,2,0,0,1,16664,3332,12,-1,-1,23,0,0,1,0,1,4,0,0),
(61959,12,0,-1,'Crimson Boar',8237180,1,0,0,1,0,0,0,-1,-1,1,1,1,1,0,4,4,0,0),
(61960,12,0,-1,'Lihanna''s Strand',8133324,1,0,0,1,0,0,0,-1,-1,1,1,1,1,0,4,4,0,0),
(61961,12,0,-1,'Shroud of Uther',8348543,1,0,0,1,0,0,0,-1,-1,1,1,1,1,0,4,4,0,0),
(61962,12,0,-1,'Gavinrad''s Sigil',8133439,1,0,0,1,0,0,0,-1,-1,1,1,1,1,0,4,4,0,0),
(60866,12,0,-1,'Battered Weapons and Armor',8132764,1,0,0,1,0,0,0,-1,-1,1,1,0,20,0,4,4,0,0),
(60984,12,0,-1,'Banshee''s Bells',8135789,1,0,0,1,0,0,0,-1,-1,1,1,0,20,0,4,4,0,0),
(62957,4,1,-1,'Homecoming Wrap',8133768,2,0,0,1,372492,74498,16,-1,-1,22,0,0,1,0,1,7,0,0),
(63023,0,5,-1,'Sweet Tea',8132802,1,0,0,1,2000,100,0,-1,-1,15,15,0,20,0,1,7,0,0);

-- ---------------------------------------------------------------------------
-- 2 more items (69765, 69816) -- these WERE found, but only in nelt_world,
-- not the retail CSVs (checked cata_world first per usual, empty; nelt_world
-- had real rows for exactly these 2). Field-mapped from nelt_world's own
-- item_template row (extra/renamed nelt-only columns like wowhead_model,
-- Unk430_1/2, DamageType, StatScalingFactor, CurrencySubstitutionId/Count
-- dropped -- no equivalent in this fork's schema).
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` IN (69765,69816);

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,
     `BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,
     `maxcount`,`stackable`,`ContainerSlots`,`bonding`,`Material`,`sheath`,`VerifiedBuild`)
VALUES
(69765,12,0,-1,'Lucifern',49932,1,65536,0,1,0,0,0,-1,-1,1,1,0,20,0,4,4,0,15595),
(69816,12,0,-1,'Houndbone Ash',98648,1,67584,0,1,0,0,0,-1,-1,1,1,0,20,0,4,4,0,15595);

-- ---------------------------------------------------------------------------
-- 1 more item (69646) -- initially missed from the 47-item batch above;
-- caught on a recount against the original boot log. Real retail data,
-- same pipeline (Item.csv/ItemSparse.csv).
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` = 69646;

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,
     `BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,
     `maxcount`,`stackable`,`ContainerSlots`,`bonding`,`Material`,`sheath`,`VerifiedBuild`)
VALUES
(69646,12,0,-1,'Branch of Nordrassil',8514019,4,0,0,1,0,0,0,-1,-1,1,0,0,1,0,4,4,0,0);
