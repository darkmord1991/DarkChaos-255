-- ====================================================================================
-- HEIRLOOM TIER 3 GAMEOBJECT LOOT - WITH C++ SCRIPT
-- ====================================================================================
-- Key changes:
-- 1. Uses custom C++ script "go_heirloom_cache" for direct loot handling
-- 2. No Lock.dbc dependency - script handles loot display directly on click
-- 3. Despawns after looting (Data3=1 consumable flag)
-- 4. Using displayId 259 (Battered Chest) - reliable lootable chest model
-- ====================================================================================

-- ====================================================================================
-- SECTION 1: GAMEOBJECT TEMPLATES (1991001-1991033)
-- ====================================================================================
-- For GAMEOBJECT_TYPE_CHEST (type=3):
--   Data0 = lockId (0 = no lock needed since script handles opening)
--   Data1 = lootId (references gameobject_loot_template.entry)
--   Data3 = consumable (1 = despawns after looting)
--   ScriptName = "go_heirloom_cache" (C++ script handles the loot)
-- ====================================================================================

DELETE FROM gameobject_template WHERE entry BETWEEN 1991001 AND 1991033;

INSERT INTO gameobject_template 
  (entry, type, displayId, name, IconName, castBarCaption, unk1, size,
   Data0, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9,
   Data10, Data11, Data12, Data13, Data14, Data15, Data16, Data17, Data18, Data19,
   Data20, Data21, Data22, Data23, AIName, ScriptName, VerifiedBuild)
VALUES
  -- Weapon Caches (1991001-1991009)
  (1991001, 3, 259, 'Heirloom Weapon Cache - Fury', '', 'Looting', '', 1.5,
   0, 1991001, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991002, 3, 259, 'Heirloom Weapon Cache - Precision', '', 'Looting', '', 1.5,
   0, 1991002, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991003, 3, 259, 'Heirloom Weapon Cache - Titan', '', 'Looting', '', 1.5,
   0, 1991003, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991004, 3, 259, 'Heirloom Weapon Cache - Assassin', '', 'Looting', '', 1.5,
   0, 1991004, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991005, 3, 259, 'Heirloom Weapon Cache - Lethality', '', 'Looting', '', 1.5,
   0, 1991005, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991006, 3, 259, 'Heirloom Weapon Cache - Evasion', '', 'Looting', '', 1.5,
   0, 1991006, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991007, 3, 259, 'Heirloom Weapon Cache - Sorcery', '', 'Looting', '', 1.5,
   0, 1991007, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991008, 3, 259, 'Heirloom Weapon Cache - Arcane Power', '', 'Looting', '', 1.5,
   0, 1991008, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991009, 3, 259, 'Heirloom Weapon Cache - Protection', '', 'Looting', '', 1.5,
   0, 1991009, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  
  -- Helm Caches (1991010-1991018)
  (1991010, 3, 259, 'Heirloom Helm Cache - DPS Plate', '', 'Looting', '', 1.5,
   0, 1991010, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991011, 3, 259, 'Heirloom Helm Cache - Physical Plate', '', 'Looting', '', 1.5,
   0, 1991011, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991012, 3, 259, 'Heirloom Helm Cache - Tank Plate', '', 'Looting', '', 1.5,
   0, 1991012, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991013, 3, 259, 'Heirloom Helm Cache - DPS Mail', '', 'Looting', '', 1.5,
   0, 1991013, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991014, 3, 259, 'Heirloom Helm Cache - Physical Mail', '', 'Looting', '', 1.5,
   0, 1991014, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991015, 3, 259, 'Heirloom Helm Cache - Tank Mail', '', 'Looting', '', 1.5,
   0, 1991015, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991016, 3, 259, 'Heirloom Helm Cache - Leather Caster', '', 'Looting', '', 1.5,
   0, 1991016, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991017, 3, 259, 'Heirloom Helm Cache - Leather Haste', '', 'Looting', '', 1.5,
   0, 1991017, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991018, 3, 259, 'Heirloom Helm Cache - Cloth Caster', '', 'Looting', '', 1.5,
   0, 1991018, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  
  -- Chest Caches (1991019-1991021)
  (1991019, 3, 259, 'Heirloom Chest Cache - DPS', '', 'Looting', '', 1.5,
   0, 1991019, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991020, 3, 259, 'Heirloom Chest Cache - Physical', '', 'Looting', '', 1.5,
   0, 1991020, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991021, 3, 259, 'Heirloom Chest Cache - Caster', '', 'Looting', '', 1.5,
   0, 1991021, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  
  -- Legs Caches (1991022-1991024)
  (1991022, 3, 259, 'Heirloom Legs Cache - Tank', '', 'Looting', '', 1.5,
   0, 1991022, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991023, 3, 259, 'Heirloom Legs Cache - Evasion', '', 'Looting', '', 1.5,
   0, 1991023, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991024, 3, 259, 'Heirloom Legs Cache - Haste', '', 'Looting', '', 1.5,
   0, 1991024, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  
  -- Shoulders Caches (1991025-1991027)
  (1991025, 3, 259, 'Heirloom Shoulders Cache - DPS', '', 'Looting', '', 1.5,
   0, 1991025, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991026, 3, 259, 'Heirloom Shoulders Cache - Physical', '', 'Looting', '', 1.5,
   0, 1991026, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991027, 3, 259, 'Heirloom Shoulders Cache - Caster', '', 'Looting', '', 1.5,
   0, 1991027, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  
  -- Waist Caches (1991028-1991030)
  (1991028, 3, 259, 'Heirloom Waist Cache - Physical', '', 'Looting', '', 1.5,
   0, 1991028, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991029, 3, 259, 'Heirloom Waist Cache - DPS', '', 'Looting', '', 1.5,
   0, 1991029, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991030, 3, 259, 'Heirloom Waist Cache - Caster', '', 'Looting', '', 1.5,
   0, 1991030, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  
  -- Feet/Hands/Wrists Caches (1991031-1991033)
  (1991031, 3, 259, 'Heirloom Feet Cache - Physical', '', 'Looting', '', 1.5,
   0, 1991031, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991032, 3, 259, 'Heirloom Hands Cache - Tank', '', 'Looting', '', 1.5,
   0, 1991032, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340),
  (1991033, 3, 259, 'Heirloom Wrists Cache - Haste', '', 'Looting', '', 1.5,
   0, 1991033, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_heirloom_cache', 12340);

-- ====================================================================================
-- SECTION 2: GAMEOBJECT LOOT TEMPLATES (Entry = lootId from Data1)
-- ====================================================================================
-- Each cache drops one specific heirloom item with 100% chance
-- Items 300332-300364 are defined in HEIRLOOM_TIER3_ITEMS_COMPLETE.sql
-- ====================================================================================

DELETE FROM gameobject_loot_template WHERE Entry BETWEEN 1991001 AND 1991033;

INSERT INTO gameobject_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment) VALUES
-- Weapon Caches
(1991001, 300332, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Flamefury Blade'),
(1991002, 300333, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Stormfury'),
(1991003, 300334, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Frostbite Axe'),
(1991004, 300335, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Shadow Dagger'),
(1991005, 300336, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Arcane Staff'),
(1991006, 300337, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Zephyr Bow'),
(1991007, 300338, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Arcane Wand'),
(1991008, 300339, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Earthshaker Mace'),
(1991009, 300340, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Polearm'),

-- Helm Caches
(1991010, 300341, 0, 100, 0, 1, 0, 1, 1, 'Heirloom War Crown'),
(1991011, 300342, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Battle Helm'),
(1991012, 300343, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Kingly Circlet'),
(1991013, 300344, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Mantle of Honor'),
(1991014, 300345, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Shoulders of Valor'),
(1991015, 300346, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Pauldrons of Wisdom'),
(1991016, 300347, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Chestplate of the Champion'),
(1991017, 300348, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Battleplate'),
(1991018, 300349, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Robes of Insight'),

-- Chest Caches
(1991019, 300350, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Vambraces of Might'),
(1991020, 300351, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Bracers of Battle'),
(1991021, 300352, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Cuffs of the Magi'),

-- Legs Caches
(1991022, 300353, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Gauntlets of Strength'),
(1991023, 300354, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Grips of Precision'),
(1991024, 300355, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Gloves of Sorcery'),

-- Shoulders Caches
(1991025, 300356, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Girdle of Power'),
(1991026, 300357, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Belt of Agility'),
(1991027, 300358, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Cord of Intellect'),

-- Waist Caches
(1991028, 300359, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Legplates of the Conqueror'),
(1991029, 300360, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Leggings of Swiftness'),
(1991030, 300361, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Pants of the Arcane'),

-- Feet/Hands/Wrists Caches
(1991031, 300362, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Treads of the Warrior'),
(1991032, 300363, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Boots of Swiftness'),
(1991033, 300364, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Slippers of the Magi');

-- ====================================================================================
-- USAGE NOTES:
-- ====================================================================================
-- 1. Build the server with the new go_heirloom_cache.cpp script
-- 2. Run this SQL on your world database
-- 3. Spawn a cache: .gobject add 1991001
-- 4. Right-click the chest to open loot window directly (no "Opening" spell needed)
-- 5. After looting, the chest despawns automatically
-- ====================================================================================
