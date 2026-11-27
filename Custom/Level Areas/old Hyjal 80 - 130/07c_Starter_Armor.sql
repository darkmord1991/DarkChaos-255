-- Hyjal Frontier - Weaponsmith & Armorer vendor stock (levels 80-90 entry gear)
--
-- Weaponsmith (830141 Alliance / 830154 Horde): sells the existing T1 weapons
--   (400824-400838, ilvl 300 req 80) and T1 trinkets (400884-400889).
--   Items were created in 07b but had no vendor -- wired here.
--
-- Armorer (830142 Alliance / 830155 Horde): sells four new armour sets
--   covering all four armour classes so every class/spec finds something
--   on day 1 in the zone.  Stats scale from the confirmed ilvl 300 ring
--   budget (07 accessories); armour values calibrated off the T1 shield
--   (400834, armour 4800).
--
-- New item block: 400909-400940 (free within 400909-400999 reserve).
-- Display IDs are all confirmed present in Custom/CSV DBC/Item.csv.
--
-- Item.csv DBC additions for 400909-400940 are appended to
--   Custom/CSV DBC/Item.csv as part of this change (see end of file).

-- =============================================================================
-- Armour items (400909-400940)  -- Weaponsmith uses existing 07b items
-- =============================================================================
DELETE FROM `item_template` WHERE `entry` BETWEEN 400909 AND 400940;

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,
     `Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,`SellPrice`,
     `InventoryType`,`AllowableClass`,`AllowableRace`,
     `ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`bonding`,
     `dmg_min1`,`dmg_max1`,`dmg_type1`,`delay`,
     `stat_type1`,`stat_value1`,`stat_type2`,`stat_value2`,
     `stat_type3`,`stat_value3`,`stat_type4`,`stat_value4`,
     `armor`,`block`,`description`,`VerifiedBuild`)
VALUES
-- ===== Cloth — Emberwood Mage's set (ilvl 300, req 80) ======================
--   stats: Spell Power / Stamina / secondary(Crit,Haste,Spirit,Hit)
--   display IDs confirmed from Item.csv (vanilla/TBC cloth armour entries)
(400909,4,1,-1,'Emberwood Mage''s Hood',      16826, 3,0,0,1,54000,10800,  1,-1,-1, 300,80, 0,1,1, 0,0,0,0, 45,190, 7,135, 32,130,  6,100,  240,0,'Level 80 Hyjal Frontier cloth head.',0),
(400910,4,1,-1,'Emberwood Mage''s Mantle',     6545, 3,0,0,1,46000, 9200,  3,-1,-1, 300,80, 0,1,1, 0,0,0,0, 45,165, 7,118, 32,113, 36, 88,  195,0,'Level 80 Hyjal Frontier cloth shoulders.',0),
(400911,4,1,-1,'Emberwood Mage''s Robe',      14154, 3,0,0,1,54000,10800,  5,-1,-1, 300,80, 0,1,1, 0,0,0,0, 45,190, 7,135, 32,130, 36,100,  354,0,'Level 80 Hyjal Frontier cloth chest.',0),
(400912,4,1,-1,'Emberwood Mage''s Cuffs',     16936, 3,0,0,1,36000, 7200,  9,-1,-1, 300,80, 0,1,1, 0,0,0,0, 45,106, 7, 76, 32, 73,  6, 58,  120,0,'Level 80 Hyjal Frontier cloth wrists.',0),
(400913,4,1,-1,'Emberwood Mage''s Gloves',    14449, 3,0,0,1,46000, 9200, 10,-1,-1, 300,80, 0,1,1, 0,0,0,0, 45,165, 7,118, 36,113, 32, 88,  184,0,'Level 80 Hyjal Frontier cloth hands.',0),
(400914,4,1,-1,'Emberwood Mage''s Sash',       4878, 3,0,0,1,42000, 8400,  6,-1,-1, 300,80, 0,1,1, 0,0,0,0, 45,146, 7,104, 32,100,  6, 77,  156,0,'Level 80 Hyjal Frontier cloth waist.',0),
(400915,4,1,-1,'Emberwood Mage''s Leggings',  14450, 3,0,0,1,54000,10800,  7,-1,-1, 300,80, 0,1,1, 0,0,0,0, 45,190, 7,135, 32,130,  6,100,  326,0,'Level 80 Hyjal Frontier cloth legs.',0),
(400916,4,1,-1,'Emberwood Mage''s Slippers',  16582, 3,0,0,1,46000, 9200,  8,-1,-1, 300,80, 0,1,1, 0,0,0,0, 45,165, 7,118, 36,113, 31, 88,  227,0,'Level 80 Hyjal Frontier cloth feet.',0),
-- ===== Leather — Emberwood Scout's set (ilvl 300, req 80) ===================
--   stats: Agility / Stamina / secondary(Crit,AP,Haste,Hit)
(400917,4,2,-1,'Emberwood Scout''s Hood',     15299, 3,0,0,1,54000,10800,  1,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,176, 7,176, 32,117, 31, 91,  592,0,'Level 80 Hyjal Frontier leather head.',0),
(400918,4,2,-1,'Emberwood Scout''s Spaulders',15002, 3,0,0,1,46000, 9200,  3,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,153, 7,153, 32,102, 38,145,  479,0,'Level 80 Hyjal Frontier leather shoulders.',0),
(400919,4,2,-1,'Emberwood Scout''s Tunic',    14278, 3,0,0,1,54000,10800,  5,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,176, 7,176, 32,117, 38,168,  870,0,'Level 80 Hyjal Frontier leather chest.',0),
(400920,4,2,-1,'Emberwood Scout''s Bracers',  14545, 3,0,0,1,36000, 7200,  9,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3, 99, 7, 99, 32, 66, 31, 52,  296,0,'Level 80 Hyjal Frontier leather wrists.',0),
(400921,4,2,-1,'Emberwood Scout''s Gloves',   14475, 3,0,0,1,46000, 9200, 10,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,153, 7,153, 36,102, 32, 81,  452,0,'Level 80 Hyjal Frontier leather hands.',0),
(400922,4,2,-1,'Emberwood Scout''s Belt',     16947, 3,0,0,1,42000, 8400,  6,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,135, 7,135, 32, 90, 31, 70,  383,0,'Level 80 Hyjal Frontier leather waist.',0),
(400923,4,2,-1,'Emberwood Scout''s Legguards',14476, 3,0,0,1,54000,10800,  7,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,176, 7,176, 32,117, 38,168,  800,0,'Level 80 Hyjal Frontier leather legs.',0),
(400924,4,2,-1,'Emberwood Scout''s Boots',    14474, 3,0,0,1,46000, 9200,  8,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,153, 7,153, 31,102, 32, 81,  557,0,'Level 80 Hyjal Frontier leather feet.',0),
-- ===== Mail — Emberwood Ranger's set (ilvl 300, req 80) =====================
--   stats: Agility / Stamina / secondary(Crit,AP,Haste,Hit,Expertise)
(400925,4,3,-1,'Emberwood Ranger''s Coif',    15324, 3,0,0,1,54000,10800,  1,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,176, 7,176, 32,117, 31, 91, 1089,0,'Level 80 Hyjal Frontier mail head.',0),
(400926,4,3,-1,'Emberwood Ranger''s Spaulders', 6480, 3,0,0,1,46000, 9200,  3,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,153, 7,153, 36,102, 32, 81,  881,0,'Level 80 Hyjal Frontier mail shoulders.',0),
(400927,4,3,-1,'Emberwood Ranger''s Hauberk', 16101, 3,0,0,1,54000,10800,  5,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,176, 7,176, 32,117, 38,168, 1602,0,'Level 80 Hyjal Frontier mail chest.',0),
(400928,4,3,-1,'Emberwood Ranger''s Vambraces',26928, 3,0,0,1,36000, 7200,  9,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3, 99, 7, 99, 31, 66, 32, 52,  545,0,'Level 80 Hyjal Frontier mail wrists.',0),
(400929,4,3,-1,'Emberwood Ranger''s Gauntlets', 6986, 3,0,0,1,46000, 9200, 10,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,153, 7,153, 32,102, 37, 81,  833,0,'Level 80 Hyjal Frontier mail hands.',0),
(400930,4,3,-1,'Emberwood Ranger''s Girdle',   6847, 3,0,0,1,42000, 8400,  6,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,135, 7,135, 31, 90, 32, 70,  705,0,'Level 80 Hyjal Frontier mail waist.',0),
(400931,4,3,-1,'Emberwood Ranger''s Legguards',10400, 3,0,0,1,54000,10800,  7,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,176, 7,176, 32,117, 36, 91, 1474,0,'Level 80 Hyjal Frontier mail legs.',0),
(400932,4,3,-1,'Emberwood Ranger''s Sabatons', 12745, 3,0,0,1,46000, 9200,  8,-1,-1, 300,80, 0,1,1, 0,0,0,0,  3,153, 7,153, 31,102, 32, 81, 1025,0,'Level 80 Hyjal Frontier mail feet.',0),
-- ===== Plate — Rootplate Warbear set (ilvl 300, req 80) =====================
--   stats: Strength / Stamina / secondary(Crit,Expertise,Parry,Hit,Defense,Haste)
--   display IDs from confirmed WotLK-era plate entries in Item.csv
(400933,4,4,-1,'Rootplate Warhelm',    16115, 3,0,0,1,54000,10800,  1,-1,-1, 300,80, 0,1,1, 0,0,0,0,  4,176, 7,243, 32,117, 31, 91, 4080,0,'Level 80 Hyjal Frontier plate head.',0),
(400934,4,4,-1,'Rootplate Pauldrons',  16089, 3,0,0,1,46000, 9200,  3,-1,-1, 300,80, 0,1,1, 0,0,0,0,  4,153, 7,211, 32,102, 37, 79, 3300,0,'Level 80 Hyjal Frontier plate shoulders.',0),
(400935,4,4,-1,'Rootplate Breastplate',16109, 3,0,0,1,54000,10800,  5,-1,-1, 300,80, 0,1,1, 0,0,0,0,  4,176, 7,243, 32,117, 37, 91, 6000,0,'Level 80 Hyjal Frontier plate chest.',0),
(400936,4,4,-1,'Rootplate Bracers',     9388, 3,0,0,1,36000, 7200,  9,-1,-1, 300,80, 0,1,1, 0,0,0,0,  4, 99, 7,136, 12, 66, 14, 52, 2040,0,'Level 80 Hyjal Frontier plate wrists.',0),
(400937,4,4,-1,'Rootplate Gauntlets',  16091, 3,0,0,1,46000, 9200, 10,-1,-1, 300,80, 0,1,1, 0,0,0,0,  4,153, 7,211, 32,102, 36, 79, 3120,0,'Level 80 Hyjal Frontier plate hands.',0),
(400938,4,4,-1,'Rootplate Girdle',     28399, 3,0,0,1,42000, 8400,  6,-1,-1, 300,80, 0,1,1, 0,0,0,0,  4,135, 7,187, 37, 90, 31, 70, 2640,0,'Level 80 Hyjal Frontier plate waist.',0),
(400939,4,4,-1,'Rootplate Legplates',  16092, 3,0,0,1,54000,10800,  7,-1,-1, 300,80, 0,1,1, 0,0,0,0,  4,176, 7,243, 32,117, 14, 91, 5520,0,'Level 80 Hyjal Frontier plate legs.',0),
(400940,4,4,-1,'Rootplate Sabatons',   16113, 3,0,0,1,46000, 9200,  8,-1,-1, 300,80, 0,1,1, 0,0,0,0,  4,153, 7,211, 31,102, 32, 79, 3840,0,'Level 80 Hyjal Frontier plate feet.',0);

-- Material field (same pattern as 07b weapons).
UPDATE `item_template` SET `material`=7 WHERE `entry` BETWEEN 400909 AND 400916;  -- cloth
UPDATE `item_template` SET `material`=8 WHERE `entry` BETWEEN 400917 AND 400924;  -- leather
UPDATE `item_template` SET `material`=5 WHERE `entry` BETWEEN 400925 AND 400932;  -- mail
UPDATE `item_template` SET `material`=6 WHERE `entry` BETWEEN 400933 AND 400940;  -- plate

-- =============================================================================
-- Vendor inventories
--   Weaponsmith : 830141 (Alliance) / 830154 (Horde)
--   Armorer     : 830142 (Alliance) / 830155 (Horde)
-- =============================================================================
DELETE FROM `npc_vendor` WHERE `entry` IN (830141, 830142, 830154, 830155);

-- ── Weaponsmith (T1 weapons 400824-400838 from 07b + T1 trinkets 400884-400889)
INSERT INTO `npc_vendor`
    (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`)
VALUES
-- Alliance
(830141,  1, 400824, 0,0,0,0),  -- Emberscorch Axe       (1H axe,   agi/phys)
(830141,  2, 400826, 0,0,0,0),  -- Cinderblade            (1H sword, agi/phys)
(830141,  3, 400827, 0,0,0,0),  -- Runeshard Dagger       (dagger,   caster/phys)
(830141,  4, 400825, 0,0,0,0),  -- Moonward Mace          (1H mace,  healer)
(830141,  5, 400828, 0,0,0,0),  -- Thornspire Polearm     (polearm,  phys)
(830141,  6, 400829, 0,0,0,0),  -- Doomcleave Axe         (2H axe,   str)
(830141,  7, 400831, 0,0,0,0),  -- Emberthorn Greatsword  (2H sword, str)
(830141,  8, 400830, 0,0,0,0),  -- Rootwood Staff         (staff,    caster)
(830141,  9, 400832, 0,0,0,0),  -- Embervine Bow          (bow,      phys ranged)
(830141, 10, 400833, 0,0,0,0),  -- Starfire Wand          (wand,     caster ranged)
(830141, 11, 400834, 0,0,0,0),  -- Rootplate Bulwark      (shield,   tank)
(830141, 12, 400835, 0,0,0,0),  -- Hyjal Codex            (off-hand, caster)
(830141, 13, 400836, 0,0,0,0),  -- Embercoil Totem        (relic,    shaman)
(830141, 14, 400837, 0,0,0,0),  -- Glyph of Ancient Growth(relic,    druid)
(830141, 15, 400838, 0,0,0,0),  -- Libram of the Frontier (relic,    paladin)
(830141, 16, 400884, 0,0,0,0),  -- Embershard Prism       (trinket,  caster SP/STA)
(830141, 17, 400885, 0,0,0,0),  -- Embervein Fragment     (trinket,  STR/AP)
(830141, 18, 400886, 0,0,0,0),  -- Ashen Talon            (trinket,  AGL/Crit)
(830141, 19, 400887, 0,0,0,0),  -- Thornweave Charm       (trinket,  SP/Spirit)
(830141, 20, 400888, 0,0,0,0),  -- Rootplate Core         (trinket,  tank STA/Def)
(830141, 21, 400889, 0,0,0,0),  -- Emberwood Shard        (trinket,  tank STA/Res)
-- Horde mirror
(830154,  1, 400824, 0,0,0,0),
(830154,  2, 400826, 0,0,0,0),
(830154,  3, 400827, 0,0,0,0),
(830154,  4, 400825, 0,0,0,0),
(830154,  5, 400828, 0,0,0,0),
(830154,  6, 400829, 0,0,0,0),
(830154,  7, 400831, 0,0,0,0),
(830154,  8, 400830, 0,0,0,0),
(830154,  9, 400832, 0,0,0,0),
(830154, 10, 400833, 0,0,0,0),
(830154, 11, 400834, 0,0,0,0),
(830154, 12, 400835, 0,0,0,0),
(830154, 13, 400836, 0,0,0,0),
(830154, 14, 400837, 0,0,0,0),
(830154, 15, 400838, 0,0,0,0),
(830154, 16, 400884, 0,0,0,0),
(830154, 17, 400885, 0,0,0,0),
(830154, 18, 400886, 0,0,0,0),
(830154, 19, 400887, 0,0,0,0),
(830154, 20, 400888, 0,0,0,0),
(830154, 21, 400889, 0,0,0,0),

-- ── Armorer (full 4-class set, 8 slots each = 32 items)
-- Alliance
(830142,  1, 400909, 0,0,0,0),  -- Cloth head
(830142,  2, 400910, 0,0,0,0),  -- Cloth shoulders
(830142,  3, 400911, 0,0,0,0),  -- Cloth chest
(830142,  4, 400912, 0,0,0,0),  -- Cloth wrists
(830142,  5, 400913, 0,0,0,0),  -- Cloth hands
(830142,  6, 400914, 0,0,0,0),  -- Cloth waist
(830142,  7, 400915, 0,0,0,0),  -- Cloth legs
(830142,  8, 400916, 0,0,0,0),  -- Cloth feet
(830142,  9, 400917, 0,0,0,0),  -- Leather head
(830142, 10, 400918, 0,0,0,0),  -- Leather shoulders
(830142, 11, 400919, 0,0,0,0),  -- Leather chest
(830142, 12, 400920, 0,0,0,0),  -- Leather wrists
(830142, 13, 400921, 0,0,0,0),  -- Leather hands
(830142, 14, 400922, 0,0,0,0),  -- Leather waist
(830142, 15, 400923, 0,0,0,0),  -- Leather legs
(830142, 16, 400924, 0,0,0,0),  -- Leather feet
(830142, 17, 400925, 0,0,0,0),  -- Mail head
(830142, 18, 400926, 0,0,0,0),  -- Mail shoulders
(830142, 19, 400927, 0,0,0,0),  -- Mail chest
(830142, 20, 400928, 0,0,0,0),  -- Mail wrists
(830142, 21, 400929, 0,0,0,0),  -- Mail hands
(830142, 22, 400930, 0,0,0,0),  -- Mail waist
(830142, 23, 400931, 0,0,0,0),  -- Mail legs
(830142, 24, 400932, 0,0,0,0),  -- Mail feet
(830142, 25, 400933, 0,0,0,0),  -- Plate head
(830142, 26, 400934, 0,0,0,0),  -- Plate shoulders
(830142, 27, 400935, 0,0,0,0),  -- Plate chest
(830142, 28, 400936, 0,0,0,0),  -- Plate wrists
(830142, 29, 400937, 0,0,0,0),  -- Plate hands
(830142, 30, 400938, 0,0,0,0),  -- Plate waist
(830142, 31, 400939, 0,0,0,0),  -- Plate legs
(830142, 32, 400940, 0,0,0,0),  -- Plate feet
-- Horde mirror
(830155,  1, 400909, 0,0,0,0),
(830155,  2, 400910, 0,0,0,0),
(830155,  3, 400911, 0,0,0,0),
(830155,  4, 400912, 0,0,0,0),
(830155,  5, 400913, 0,0,0,0),
(830155,  6, 400914, 0,0,0,0),
(830155,  7, 400915, 0,0,0,0),
(830155,  8, 400916, 0,0,0,0),
(830155,  9, 400917, 0,0,0,0),
(830155, 10, 400918, 0,0,0,0),
(830155, 11, 400919, 0,0,0,0),
(830155, 12, 400920, 0,0,0,0),
(830155, 13, 400921, 0,0,0,0),
(830155, 14, 400922, 0,0,0,0),
(830155, 15, 400923, 0,0,0,0),
(830155, 16, 400924, 0,0,0,0),
(830155, 17, 400925, 0,0,0,0),
(830155, 18, 400926, 0,0,0,0),
(830155, 19, 400927, 0,0,0,0),
(830155, 20, 400928, 0,0,0,0),
(830155, 21, 400929, 0,0,0,0),
(830155, 22, 400930, 0,0,0,0),
(830155, 23, 400931, 0,0,0,0),
(830155, 24, 400932, 0,0,0,0),
(830155, 25, 400933, 0,0,0,0),
(830155, 26, 400934, 0,0,0,0),
(830155, 27, 400935, 0,0,0,0),
(830155, 28, 400936, 0,0,0,0),
(830155, 29, 400937, 0,0,0,0),
(830155, 30, 400938, 0,0,0,0),
(830155, 31, 400939, 0,0,0,0),
(830155, 32, 400940, 0,0,0,0);
