-- ====================================================================================
-- HEIRLOOM TIER 3 CACHES - REAL ITEM-SHAPE DISPLAYS (PART A: STOCK MODELS, SQL-ONLY)
-- ====================================================================================
-- Goal: every heirloom cache (1991001-1991048) was displayId 259 (Treasure Chest).
--       Replace the identical chest with a model that fits the item in the cache -
--       "an axe looks like an axe on the ground" (Ascension "Worldforged" style).
--
-- This file is 100% SQL-only: every displayId below is an EXISTING stock
-- GameObjectDisplayInfo row that already ships in the 3.3.5 client AND has a valid
-- geo-bounding-box (so the cache stays click-/loot-able). No client patch required.
--
-- 3.3.5 has no standalone ground model for chest/legs/gloves/boots/belt/bracers/
-- cloak/neck/ring/trinket (they are geosets on the character body). Those slots use a
-- thematically-fitting prop instead of a chest (armor stand, hanging mail, gem, gold).
--
-- Rows marked (INTERIM) use a stand-in because no stock display row exists for that
-- exact shape; HEIRLOOM_TIER3_GO_DISPLAY_EXACT_SHAPES.sql upgrades them to purpose-made
-- rows AFTER the patch-4 DBC deploy. Do NOT apply that file before the DBC is deployed.
--
-- Behaviour (type=3 chest, loot, go_heirloom_cache script) is unchanged - display only.
-- Idempotent: plain UPDATEs, safe to re-run.
-- ====================================================================================

-- ---- Weapons (1991001-1991009) --------------------------------------------------
UPDATE `gameobject_template` SET `displayId`=669  WHERE `entry`=1991001; -- Flamefury Blade  -> HumanSword01
UPDATE `gameobject_template` SET `displayId`=670  WHERE `entry`=1991002; -- Stormfury        -> HumanSword02
UPDATE `gameobject_template` SET `displayId`=6861 WHERE `entry`=1991003; -- Frostbite Axe    -> 2SidedPickAxe (INTERIM)
UPDATE `gameobject_template` SET `displayId`=669  WHERE `entry`=1991004; -- Shadow Dagger    -> HumanSword01 (INTERIM)
UPDATE `gameobject_template` SET `displayId`=2455 WHERE `entry`=1991005; -- Arcane Staff     -> HumanStaff02
UPDATE `gameobject_template` SET `displayId`=2455 WHERE `entry`=1991006; -- Zephyr Bow       -> HumanStaff02 (INTERIM)
UPDATE `gameobject_template` SET `displayId`=70   WHERE `entry`=1991007; -- Arcane Wand      -> HumanMace02 (INTERIM)
UPDATE `gameobject_template` SET `displayId`=671  WHERE `entry`=1991008; -- Earthshaker Mace -> HumanMace01
UPDATE `gameobject_template` SET `displayId`=2455 WHERE `entry`=1991009; -- Polearm          -> HumanStaff02 (INTERIM)

-- ---- Helms (1991010-1991012) ----------------------------------------------------
UPDATE `gameobject_template` SET `displayId`=7740 WHERE `entry`=1991010; -- War Crown       -> ArmorHelmTrim
UPDATE `gameobject_template` SET `displayId`=7740 WHERE `entry`=1991011; -- Battle Helm      -> ArmorHelmTrim
UPDATE `gameobject_template` SET `displayId`=7740 WHERE `entry`=1991012; -- Kingly Circlet   -> ArmorHelmTrim

-- ---- Shoulders (1991013-1991015) ------------------------------------------------
UPDATE `gameobject_template` SET `displayId`=7622 WHERE `entry`=1991013; -- Mantle of Honor      -> ArmorShoulderTrim
UPDATE `gameobject_template` SET `displayId`=7943 WHERE `entry`=1991014; -- Shoulders of Valor   -> ArmorShoulderSilver
UPDATE `gameobject_template` SET `displayId`=7622 WHERE `entry`=1991015; -- Pauldrons of Wisdom  -> ArmorShoulderTrim

-- ---- Chest (1991016-1991018) ----------------------------------------------------
UPDATE `gameobject_template` SET `displayId`=7739 WHERE `entry`=1991016; -- Chestplate of the Champion -> ArmorBreastplateTrim
UPDATE `gameobject_template` SET `displayId`=7739 WHERE `entry`=1991017; -- Battleplate                -> ArmorBreastplateTrim
UPDATE `gameobject_template` SET `displayId`=7624 WHERE `entry`=1991018; -- Robes of Insight           -> ArmorBreastplateGreen

-- ---- Wrist / bracers (1991019-1991021) -- no ground model, small armor stand-in --
UPDATE `gameobject_template` SET `displayId`=7622 WHERE `entry`=1991019; -- Vambraces of Might -> ArmorShoulderTrim (INTERIM)
UPDATE `gameobject_template` SET `displayId`=7622 WHERE `entry`=1991020; -- Bracers of Battle  -> ArmorShoulderTrim (INTERIM)
UPDATE `gameobject_template` SET `displayId`=7622 WHERE `entry`=1991021; -- Cuffs of the Magi  -> ArmorShoulderTrim (INTERIM)

-- ---- Hands / gloves (1991022-1991024) -- no ground model, themed armor stand ------
UPDATE `gameobject_template` SET `displayId`=7736 WHERE `entry`=1991022; -- Gauntlets of Strength -> ArmorStand
UPDATE `gameobject_template` SET `displayId`=7736 WHERE `entry`=1991023; -- Grips of Precision    -> ArmorStand
UPDATE `gameobject_template` SET `displayId`=7736 WHERE `entry`=1991024; -- Gloves of Sorcery     -> ArmorStand

-- ---- Waist / belt (1991025-1991027) -- no ground model, hanging mail ---------------
UPDATE `gameobject_template` SET `displayId`=7737 WHERE `entry`=1991025; -- Girdle of Power    -> ArmorMailHangingBlueLong
UPDATE `gameobject_template` SET `displayId`=7737 WHERE `entry`=1991026; -- Belt of Agility    -> ArmorMailHangingBlueLong
UPDATE `gameobject_template` SET `displayId`=7737 WHERE `entry`=1991027; -- Cord of Intellect  -> ArmorMailHangingBlueLong

-- ---- Legs (1991028-1991030) -- no ground model, armor stand stand-in --------------
UPDATE `gameobject_template` SET `displayId`=7736 WHERE `entry`=1991028; -- Legplates of the Conqueror -> ArmorStand (INTERIM)
UPDATE `gameobject_template` SET `displayId`=7736 WHERE `entry`=1991029; -- Leggings of Swiftness      -> ArmorStand (INTERIM)
UPDATE `gameobject_template` SET `displayId`=7736 WHERE `entry`=1991030; -- Pants of the Arcane        -> ArmorStand (INTERIM)

-- ---- Feet / boots (1991031-1991033) -- no ground model, themed armor stand ---------
UPDATE `gameobject_template` SET `displayId`=7736 WHERE `entry`=1991031; -- Sabatons of Fury      -> ArmorStand
UPDATE `gameobject_template` SET `displayId`=7736 WHERE `entry`=1991032; -- Boots of Haste        -> ArmorStand
UPDATE `gameobject_template` SET `displayId`=7736 WHERE `entry`=1991033; -- Sandals of Brilliance -> ArmorStand

-- ---- Neck (1991034-1991036) -- jewelry, gem props ---------------------------------
UPDATE `gameobject_template` SET `displayId`=3511 WHERE `entry`=1991034; -- Pendant of Might   -> MuseumGem01
UPDATE `gameobject_template` SET `displayId`=2972 WHERE `entry`=1991035; -- Pendant of Agility -> UngoroCrystal_Green01
UPDATE `gameobject_template` SET `displayId`=2770 WHERE `entry`=1991036; -- Pendant of Wisdom  -> G_JewelBlue

-- ---- Back / cloak (1991037-1991039) -- cape geoset, hanging cloth stand-in ---------
UPDATE `gameobject_template` SET `displayId`=7737 WHERE `entry`=1991037; -- Cape of Valor      -> ArmorMailHangingBlueLong
UPDATE `gameobject_template` SET `displayId`=7737 WHERE `entry`=1991038; -- Drape of Swiftness -> ArmorMailHangingBlueLong
UPDATE `gameobject_template` SET `displayId`=7737 WHERE `entry`=1991039; -- Cloak of Insight   -> ArmorMailHangingBlueLong

-- ---- Ring (1991040-1991042) -- jewelry, gem props ---------------------------------
UPDATE `gameobject_template` SET `displayId`=2770 WHERE `entry`=1991040; -- Band of Power     -> G_JewelBlue
UPDATE `gameobject_template` SET `displayId`=2972 WHERE `entry`=1991041; -- Band of Precision -> UngoroCrystal_Green01
UPDATE `gameobject_template` SET `displayId`=3511 WHERE `entry`=1991042; -- Band of Intellect -> MuseumGem01

-- ---- Trinket (1991043-1991045) -- treasure / gem props ----------------------------
UPDATE `gameobject_template` SET `displayId`=7343 WHERE `entry`=1991043; -- Badge of Might    -> GoldPileLarge01
UPDATE `gameobject_template` SET `displayId`=3511 WHERE `entry`=1991044; -- Charm of Agility  -> MuseumGem01
UPDATE `gameobject_template` SET `displayId`=2770 WHERE `entry`=1991045; -- Stone of Wisdom   -> G_JewelBlue

-- ---- Shields (1991046-1991047) --------------------------------------------------
UPDATE `gameobject_template` SET `displayId`=522 WHERE `entry`=1991046; -- Bulwark of Might     -> WallShield03
UPDATE `gameobject_template` SET `displayId`=522 WHERE `entry`=1991047; -- Bulwark of Swiftness -> WallShield03

-- ---- Off-hand tome (1991048) ----------------------------------------------------
UPDATE `gameobject_template` SET `displayId`=184 WHERE `entry`=1991048; -- Tome of Insight -> BookLarge01
