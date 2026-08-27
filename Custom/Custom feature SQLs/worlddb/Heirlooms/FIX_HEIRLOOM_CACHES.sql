-- ===========================================================================
-- Heirloom caches - rename all 48 to match the item they actually contain,
-- and record the 17 that still need placing.
-- ===========================================================================
--
-- TWO SEPARATE BUGS, both pre-existing.
--
-- BUG 1: 17 of the 48 caches have ZERO rows in `gameobject`, so 17 heirlooms
-- are currently unobtainable - the whole neck, back, ring, trinket, shield and
-- off-hand range, plus Stormfury and Gloves of Sorcery. The item, its
-- gameobject_template and its loot row all exist; only the world spawn is
-- missing, so nothing reports an error - the chest simply is not there.
--
-- BUG 2: the cache NAMES were written for a much larger design - 9 variants per
-- slot across 4 armor classes ("Helm Cache - DPS Plate", "- Tank Mail",
-- "- Leather Caster", "- Cloth Caster"...). Only 3 items per slot were ever
-- built, and the caches were then wired to items sequentially by entry, so the
-- names drifted off almost everywhere: "Helm Cache - DPS Mail" holds a
-- SHOULDER item, "Chest Cache - DPS" holds WRISTS, "Hands Cache - Tank" holds
-- BOOTS. The name is what a player sees on the tooltip before opening it, so
-- every one is renamed here to "<Slot> Cache - <item>".
--
-- The cache script needs no change: go_heirloom_cache.cpp resolves the item
-- from the GO lootId at runtime and has no hardcoded item list, so no C++
-- edit and no rebuild.
--
-- THIS FILE ONLY RENAMES. No world spawns are created, by request - so BUG 1
-- is documented here but NOT fixed: those 17 heirlooms stay unobtainable until
-- the caches are placed by hand. The entry list is in section 2 below.
--
-- When you do place them: never let a gameobject INSERT allocate its own guid
-- on this DB - the AUTO_INCREMENT counter sits above 0xFFFFFF and a guid-less
-- insert bricks startup. `.gobject add` in game handles this correctly.
-- ===========================================================================

USE acore_world;

-- --- 1. rename all 48 caches to match their actual contents -----------------
UPDATE `gameobject_template` SET `name` = 'Weapon Cache - Flamefury Blade' WHERE `entry` = 1991001;   -- holds 300332
UPDATE `gameobject_template` SET `name` = 'Weapon Cache - Stormfury' WHERE `entry` = 1991002;   -- holds 300333
UPDATE `gameobject_template` SET `name` = 'Weapon Cache - Frostbite Axe' WHERE `entry` = 1991003;   -- holds 300334
UPDATE `gameobject_template` SET `name` = 'Weapon Cache - Shadow Dagger' WHERE `entry` = 1991004;   -- holds 300335
UPDATE `gameobject_template` SET `name` = 'Weapon Cache - Arcane Staff' WHERE `entry` = 1991005;   -- holds 300336
UPDATE `gameobject_template` SET `name` = 'Weapon Cache - Zephyr Bow' WHERE `entry` = 1991006;   -- holds 300337
UPDATE `gameobject_template` SET `name` = 'Weapon Cache - Arcane Wand' WHERE `entry` = 1991007;   -- holds 300338
UPDATE `gameobject_template` SET `name` = 'Weapon Cache - Earthshaker Mace' WHERE `entry` = 1991008;   -- holds 300339
UPDATE `gameobject_template` SET `name` = 'Weapon Cache - Polearm' WHERE `entry` = 1991009;   -- holds 300340
UPDATE `gameobject_template` SET `name` = 'Head Cache - War Crown' WHERE `entry` = 1991010;   -- holds 300341
UPDATE `gameobject_template` SET `name` = 'Head Cache - Battle Helm' WHERE `entry` = 1991011;   -- holds 300342
UPDATE `gameobject_template` SET `name` = 'Head Cache - Kingly Circlet' WHERE `entry` = 1991012;   -- holds 300343
UPDATE `gameobject_template` SET `name` = 'Shoulder Cache - Mantle of Honor' WHERE `entry` = 1991013;   -- holds 300344
UPDATE `gameobject_template` SET `name` = 'Shoulder Cache - Shoulders of Valor' WHERE `entry` = 1991014;   -- holds 300345
UPDATE `gameobject_template` SET `name` = 'Shoulder Cache - Pauldrons of Wisdom' WHERE `entry` = 1991015;   -- holds 300346
UPDATE `gameobject_template` SET `name` = 'Chest Cache - Chestplate of the Champion' WHERE `entry` = 1991016;   -- holds 300347
UPDATE `gameobject_template` SET `name` = 'Chest Cache - Battleplate' WHERE `entry` = 1991017;   -- holds 300348
UPDATE `gameobject_template` SET `name` = 'Chest Cache - Robes of Insight' WHERE `entry` = 1991018;   -- holds 300349
UPDATE `gameobject_template` SET `name` = 'Wrist Cache - Vambraces of Might' WHERE `entry` = 1991019;   -- holds 300350
UPDATE `gameobject_template` SET `name` = 'Wrist Cache - Bracers of Battle' WHERE `entry` = 1991020;   -- holds 300351
UPDATE `gameobject_template` SET `name` = 'Wrist Cache - Cuffs of the Magi' WHERE `entry` = 1991021;   -- holds 300352
UPDATE `gameobject_template` SET `name` = 'Hands Cache - Gauntlets of Strength' WHERE `entry` = 1991022;   -- holds 300353
UPDATE `gameobject_template` SET `name` = 'Hands Cache - Grips of Precision' WHERE `entry` = 1991023;   -- holds 300354
UPDATE `gameobject_template` SET `name` = 'Hands Cache - Gloves of Sorcery' WHERE `entry` = 1991024;   -- holds 300355
UPDATE `gameobject_template` SET `name` = 'Waist Cache - Girdle of Power' WHERE `entry` = 1991025;   -- holds 300356
UPDATE `gameobject_template` SET `name` = 'Waist Cache - Belt of Agility' WHERE `entry` = 1991026;   -- holds 300357
UPDATE `gameobject_template` SET `name` = 'Waist Cache - Cord of Intellect' WHERE `entry` = 1991027;   -- holds 300358
UPDATE `gameobject_template` SET `name` = 'Legs Cache - Legplates of the Conqueror' WHERE `entry` = 1991028;   -- holds 300359
UPDATE `gameobject_template` SET `name` = 'Legs Cache - Leggings of Swiftness' WHERE `entry` = 1991029;   -- holds 300360
UPDATE `gameobject_template` SET `name` = 'Legs Cache - Trousers of Arcane Power' WHERE `entry` = 1991030;   -- holds 300361
UPDATE `gameobject_template` SET `name` = 'Feet Cache - Sabatons of Fury' WHERE `entry` = 1991031;   -- holds 300362
UPDATE `gameobject_template` SET `name` = 'Feet Cache - Boots of Haste' WHERE `entry` = 1991032;   -- holds 300363
UPDATE `gameobject_template` SET `name` = 'Feet Cache - Sandals of Brilliance' WHERE `entry` = 1991033;   -- holds 300364
UPDATE `gameobject_template` SET `name` = 'Neck Cache - Pendant of Might' WHERE `entry` = 1991034;   -- holds 300367
UPDATE `gameobject_template` SET `name` = 'Neck Cache - Pendant of Agility' WHERE `entry` = 1991035;   -- holds 300368
UPDATE `gameobject_template` SET `name` = 'Neck Cache - Pendant of Wisdom' WHERE `entry` = 1991036;   -- holds 300369
UPDATE `gameobject_template` SET `name` = 'Back Cache - Cape of Valor' WHERE `entry` = 1991037;   -- holds 300370
UPDATE `gameobject_template` SET `name` = 'Back Cache - Drape of Swiftness' WHERE `entry` = 1991038;   -- holds 300371
UPDATE `gameobject_template` SET `name` = 'Back Cache - Cloak of Insight' WHERE `entry` = 1991039;   -- holds 300372
UPDATE `gameobject_template` SET `name` = 'Ring Cache - Band of Power' WHERE `entry` = 1991040;   -- holds 300373
UPDATE `gameobject_template` SET `name` = 'Ring Cache - Band of Precision' WHERE `entry` = 1991041;   -- holds 300374
UPDATE `gameobject_template` SET `name` = 'Ring Cache - Band of Intellect' WHERE `entry` = 1991042;   -- holds 300375
UPDATE `gameobject_template` SET `name` = 'Trinket Cache - Badge of Might' WHERE `entry` = 1991043;   -- holds 300376
UPDATE `gameobject_template` SET `name` = 'Trinket Cache - Charm of Agility' WHERE `entry` = 1991044;   -- holds 300377
UPDATE `gameobject_template` SET `name` = 'Trinket Cache - Stone of Wisdom' WHERE `entry` = 1991045;   -- holds 300378
UPDATE `gameobject_template` SET `name` = 'Shield Cache - Bulwark of Might' WHERE `entry` = 1991046;   -- holds 300379
UPDATE `gameobject_template` SET `name` = 'Shield Cache - Bulwark of Swiftness' WHERE `entry` = 1991047;   -- holds 300380
UPDATE `gameobject_template` SET `name` = 'Off-hand Cache - Tome of Insight' WHERE `entry` = 1991048;   -- holds 300381

-- --- 2. the 17 caches that still need placing ---------------------------
-- NOT spawned by this file, by request. Stand where each should go and run:
--   .gobject add 1991002   -- Heirloom Stormfury (Weapon)
--   .gobject add 1991024   -- Heirloom Gloves of Sorcery (Hands)
--   .gobject add 1991034   -- Heirloom Pendant of Might (Neck)
--   .gobject add 1991035   -- Heirloom Pendant of Agility (Neck)
--   .gobject add 1991036   -- Heirloom Pendant of Wisdom (Neck)
--   .gobject add 1991037   -- Heirloom Cape of Valor (Back)
--   .gobject add 1991038   -- Heirloom Drape of Swiftness (Back)
--   .gobject add 1991039   -- Heirloom Cloak of Insight (Back)
--   .gobject add 1991040   -- Heirloom Band of Power (Ring)
--   .gobject add 1991041   -- Heirloom Band of Precision (Ring)
--   .gobject add 1991042   -- Heirloom Band of Intellect (Ring)
--   .gobject add 1991043   -- Heirloom Badge of Might (Trinket)
--   .gobject add 1991044   -- Heirloom Charm of Agility (Trinket)
--   .gobject add 1991045   -- Heirloom Stone of Wisdom (Trinket)
--   .gobject add 1991046   -- Heirloom Bulwark of Might (Shield)
--   .gobject add 1991047   -- Heirloom Bulwark of Swiftness (Shield)
--   .gobject add 1991048   -- Heirloom Tome of Insight (Off-hand)

-- --- verification ---------------------------------------------------------
SELECT t.`entry`, t.`name`, l.`Item`, i.`name` AS contains,
       (SELECT COUNT(*) FROM `gameobject` g WHERE g.`id` = t.`entry`) AS spawns
FROM `gameobject_template` t
LEFT JOIN `gameobject_loot_template` l ON l.`entry` = t.`Data1`
LEFT JOIN `item_template` i ON i.`entry` = l.`Item`
WHERE t.`entry` BETWEEN 1991001 AND 1991048
ORDER BY t.`entry`;
-- Expect 48 rows, each named after its own item. `spawns` still reads 0 for
-- the 17 listed in section 2 until they are placed.
