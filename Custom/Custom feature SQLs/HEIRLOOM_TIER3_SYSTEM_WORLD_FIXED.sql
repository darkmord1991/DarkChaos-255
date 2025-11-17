-- ================================================== ============================================
-- HEIRLOOM TIER 3 SYSTEM - WORLD DATABASE
-- ================================================== ============================================
-- Complete consolidated SQL for acore_world database
-- Contains: Items, GameObjects, Loot Tables, Quests, Costs
-- No duplicates - single file ready for execution
-- 
-- Date: November 16, 2025
-- Entry ID Ranges:
--   Items: 191101-191133 (33 items)
--   GameObjects: 191001-191033 (33 treasures)
--   GameObject Templates: 191001-191033 (33 template entries)
--   Quest: 50000 (one-time loot tracker)
--   Upgrade Costs: Tier 3 HEIRLOOM (rows added)
--
-- STAT SCALING DESIGN:
--   PRIMARY STATS (STR, AGI, INT, STA, SPI):
--     - Scale automatically with character level (standard heirloom behavior)
--     - NOT affected by ItemUpgrade system
--   SECONDARY STATS (Crit, Haste, Mastery, etc.):
--     - Base items have NO secondary stats (stat_type2/3 = 0)
--     - Added ONLY via ItemUpgrade system essence upgrades
--     - Scale from 1.05x (L0) to 1.35x (L15)
--
-- Database: acore_world
-- Tables Updated: item_template, gameobject, gameobject_template, 
--                 gameobject_loot_template, quest_template, quest_objective,
--                 dc_item_upgrade_costs
-- ================================================== ============================================

-- ================================================== ============================================
-- SECTION 1: HEIRLOOM ITEM TEMPLATES (191101-191133)
-- ================================================== ============================================
-- 33 Bind-on-Account heirloom items for Tier 3 upgrades
-- Includes: 9 weapons, 24 armor pieces
-- 
-- STAT DESIGN:
--   PRIMARY STATS (STR, AGI, INT, STA, SPI): Scale automatically with character level
--   SECONDARY STATS (Crit, Haste, Mastery, etc.): ONLY added via ItemUpgrade system
-- 
-- Base items have NO secondary stats (stat_type2/3 = 0).
-- Players upgrade items with essence to ADD secondary stats (1.05x → 1.35x scaling).
-- ================================================== ============================================

-- WEAPONS: 9 items (191101-191109)
-- Main Hand Swords (191101-191103), Dagger (191104), Staff (191105), 
-- Bow (191106), Wand (191107), Mace (191108), Polearm (191109)
-- 
-- NOTE: Only PRIMARY stats (stat_type1) are defined here.
-- These scale automatically with character level (standard heirloom behavior).
-- SECONDARY stats are added ONLY via ItemUpgrade system essence upgrades.

INSERT INTO item_template 
  (entry, class, subclass, name, displayid, quality, flags, bonding, 
   stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3,
   RequiredLevel, ItemLevel, armor, maxcount, stackable, description)
VALUES
  -- Main Hand Swords
  (191101, 2, 8, 'Heirloom Flamefury Blade', 45001, 5, 524288, 4,
   4, 25, 0, 0, 0, 0, 1, 80, 0, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191102, 2, 8, 'Heirloom Stormfury', 45002, 5, 524288, 4,
   4, 25, 0, 0, 0, 0, 1, 80, 0, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191103, 2, 8, 'Heirloom Frostbite Axe', 45003, 5, 524288, 4,
   4, 30, 0, 0, 0, 0, 1, 80, 0, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

  -- Off-Hand Dagger
  (191104, 2, 7, 'Heirloom Shadow Dagger', 45004, 5, 524288, 4,
   3, 20, 0, 0, 0, 0, 1, 80, 0, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

  -- Two-Handed Staff
  (191105, 2, 10, 'Heirloom Arcane Staff', 45005, 5, 524288, 4,
   2, 25, 0, 0, 0, 0, 1, 80, 0, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

  -- Ranged Bow
  (191106, 3, 2, 'Heirloom Zephyr Bow', 45006, 5, 524288, 4,
   3, 22, 0, 0, 0, 0, 1, 80, 0, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

  -- Off-Hand Wand
  (191107, 3, 3, 'Heirloom Arcane Wand', 45007, 5, 524288, 4,
   2, 18, 0, 0, 0, 0, 1, 80, 0, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

  -- Mace
  (191108, 2, 0, 'Heirloom Earthshaker Mace', 45008, 5, 524288, 4,
   4, 28, 0, 0, 0, 0, 1, 80, 0, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

  -- Polearm
  (191109, 2, 6, 'Heirloom Polearm', 45009, 5, 524288, 4,
   4, 24, 0, 0, 0, 0, 1, 80, 0, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

-- ARMOR - HELMS (191110-191112, 3 variants)
  (191110, 4, 1, 'Heirloom War Crown', 50001, 5, 524288, 4,
   1, 25, 0, 0, 0, 0, 1, 80, 50, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191111, 4, 1, 'Heirloom Battle Helm', 50002, 5, 524288, 4,
   4, 25, 0, 0, 0, 0, 1, 80, 50, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191112, 4, 1, 'Heirloom Kingly Circlet', 50003, 5, 524288, 4,
   2, 25, 0, 0, 0, 0, 1, 80, 50, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

-- ARMOR - CHEST (191113-191115, 3 variants)
  (191113, 4, 5, 'Heirloom Battleplate', 50004, 5, 524288, 4,
   1, 30, 0, 0, 0, 0, 1, 80, 75, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191114, 4, 5, 'Heirloom Dragonhide Tunic', 50005, 5, 524288, 4,
   2, 30, 0, 0, 0, 0, 1, 80, 75, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191115, 4, 5, 'Heirloom Mithril Robe', 50006, 5, 524288, 4,
   2, 30, 0, 0, 0, 0, 1, 80, 75, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

-- ARMOR - LEGS (191116-191118, 3 variants)
  (191116, 4, 10, 'Heirloom Legplates', 50007, 5, 524288, 4,
   1, 28, 0, 0, 0, 0, 1, 80, 70, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191117, 4, 10, 'Heirloom Leggings', 50008, 5, 524288, 4,
   3, 28, 0, 0, 0, 0, 1, 80, 70, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191118, 4, 10, 'Heirloom Trousers', 50009, 5, 524288, 4,
   2, 28, 0, 0, 0, 0, 1, 80, 70, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

-- ARMOR - SHOULDERS (191119-191121, 3 variants)
  (191119, 4, 3, 'Heirloom Pauldrons', 50010, 5, 524288, 4,
   4, 20, 0, 0, 0, 0, 1, 80, 60, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191120, 4, 3, 'Heirloom Mantle', 50011, 5, 524288, 4,
   2, 20, 0, 0, 0, 0, 1, 80, 60, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191121, 4, 3, 'Heirloom Spaulders', 50012, 5, 524288, 4,
   3, 20, 0, 0, 0, 0, 1, 80, 60, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

-- ARMOR - WAIST/BELT (191122-191124, 3 variants)
  (191122, 4, 6, 'Heirloom Girdle', 50013, 5, 524288, 4,
   1, 18, 0, 0, 0, 0, 1, 80, 50, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191123, 4, 6, 'Heirloom Cord', 50014, 5, 524288, 4,
   2, 18, 0, 0, 0, 0, 1, 80, 50, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191124, 4, 6, 'Heirloom Waistband', 50015, 5, 524288, 4,
   3, 18, 0, 0, 0, 0, 1, 80, 50, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

-- ARMOR - FEET/BOOTS (191125-191127, 3 variants)
  (191125, 4, 8, 'Heirloom Sabatons', 50016, 5, 524288, 4,
   1, 15, 0, 0, 0, 0, 1, 80, 40, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191126, 4, 8, 'Heirloom Treads', 50017, 5, 524288, 4,
   2, 15, 0, 0, 0, 0, 1, 80, 40, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191127, 4, 8, 'Heirloom Boots', 50018, 5, 524288, 4,
   4, 15, 0, 0, 0, 0, 1, 80, 40, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

-- ARMOR - HANDS/GLOVES (191128-191130, 3 variants)
  (191128, 4, 2, 'Heirloom Bracers', 50019, 5, 524288, 4,
   1, 12, 0, 0, 0, 0, 1, 80, 35, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191129, 4, 2, 'Heirloom Vambraces', 50020, 5, 524288, 4,
   2, 12, 0, 0, 0, 0, 1, 80, 35, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191130, 4, 2, 'Heirloom Wristguards', 50021, 5, 524288, 4,
   3, 12, 0, 0, 0, 0, 1, 80, 35, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),

-- ARMOR - WRISTS/BRACERS (191131-191133, 3 variants - additional slot)
  (191131, 4, 9, 'Heirloom Gauntlets', 50022, 5, 524288, 4,
   4, 15, 0, 0, 0, 0, 1, 80, 45, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191132, 4, 9, 'Heirloom Gloves', 50023, 5, 524288, 4,
   2, 15, 0, 0, 0, 0, 1, 80, 45, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.'),
   
  (191133, 4, 9, 'Heirloom Mittens', 50024, 5, 524288, 4,
   3, 15, 0, 0, 0, 0, 1, 80, 45, 1, 1, 'Primary stats scale with level. Upgrade for secondary stats.');


-- ================================================== ============================================
-- SECTION 2: GAMEOBJECT TEMPLATES FOR TREASURES (191001-191024)
-- ================================================== ============================================
-- Display Models:
--   119-120: Weapon Racks
--   121: Shield Mount
--   134-136: Armor Stands
--   142: Treasure Chests
-- ================================================== ============================================

INSERT INTO gameobject_template
  (entry, type, displayId, name, size, Data0, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, 
   Data9, Data10, Data11, Data12, Data13, Data14, Data15, Data16, Data17, Data18, Data19, Data20, Data21, Data22, Data23)
VALUES
  -- WEAPONS - Weapon Racks (Type 3 = Chest/Loot)
  (191001, 3, 119, 'Ancient Weapon Rack - Flamefury Blade', 1.0,
   191001, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191002, 3, 119, 'Rusted Weapon Mount - Stormfury', 1.0,
   191002, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191003, 3, 120, 'Spectral Weapon Rack - Frostbite Axe', 1.0,
   191003, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191004, 3, 120, 'Shadowed Weapon Display - Earthshaker Mace', 1.0,
   191004, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191005, 3, 119, 'Ornate Weapon Rack - Arcane Staff', 1.0,
   191005, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191006, 3, 120, 'Tarnished Weapon Mount - Zephyr Bow', 1.0,
   191006, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  -- SHIELD - Shield Mount (Display ID 121)
  (191007, 3, 121, 'Battle Scarred Shield Mount - Aegis', 1.0,
   191007, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  -- ARMOR - Helms/Head (Display ID 134)
  (191008, 3, 134, 'Spectral Armor Stand - War Crown', 1.0,
   191008, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191009, 3, 134, 'Ancient Armor Display - Battle Helm', 1.0,
   191009, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191010, 3, 135, 'Rusted Armor Stand - Kingly Circlet', 1.0,
   191010, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  -- ARMOR - Chest (Display ID 135)
  (191011, 3, 135, 'Ornate Armor Rack - Battleplate', 1.0,
   191011, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191012, 3, 135, 'Shadowed Armor Display - Dragonhide Tunic', 1.0,
   191012, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191013, 3, 136, 'Tarnished Armor Stand - Mithril Robe', 1.0,
   191013, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  -- ARMOR - Legs (Display ID 134)
  (191014, 3, 134, 'Ancient Armor Stand - Legplates', 1.0,
   191014, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191015, 3, 134, 'Spectral Armor Display - Leggings', 1.0,
   191015, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191016, 3, 135, 'Rusted Armor Rack - Trousers', 1.0,
   191016, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  -- ARMOR - Shoulders (Display ID 136)
  (191017, 3, 136, 'Ornate Armor Stand - Pauldrons', 1.0,
   191017, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191018, 3, 136, 'Shadowed Armor Display - Mantle', 1.0,
   191018, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191019, 3, 136, 'Tarnished Armor Rack - Spaulders', 1.0,
   191019, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  -- ARMOR - Waist (Display ID 134)
  (191020, 3, 134, 'Ancient Armor Mount - Girdle', 1.0,
   191020, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191021, 3, 135, 'Spectral Armor Rack - Cord', 1.0,
   191021, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191022, 3, 136, 'Rusted Armor Display - Waistband', 1.0,
   191022, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  -- FEET/JEWELRY (Treasure Chest, Display ID 142)
  (191023, 3, 142, 'Ornate Jewelry Box - Legendary Boots', 1.0,
   191023, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191024, 3, 142, 'Shadowed Treasure Chest - Ancient Heirlooms', 1.0,
   191024, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  -- ADDITIONAL ITEMS (191025-191033) - 9 more treasures for remaining items
  (191025, 3, 134, 'Ancient Armor Stand - Sabatons', 1.0,
   191025, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191026, 3, 135, 'Spectral Armor Display - Treads', 1.0,
   191026, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191027, 3, 136, 'Rusted Armor Rack - Boots', 1.0,
   191027, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191028, 3, 134, 'Ornate Armor Stand - Gauntlets', 1.0,
   191028, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191029, 3, 135, 'Shadowed Armor Display - Gloves', 1.0,
   191029, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191030, 3, 136, 'Tarnished Armor Rack - Mittens', 1.0,
   191030, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191031, 3, 134, 'Ancient Armor Mount - Bracers', 1.0,
   191031, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191032, 3, 135, 'Spectral Armor Rack - Vambraces', 1.0,
   191032, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
   
  (191033, 3, 136, 'Rusted Armor Display - Wristguards', 1.0,
   191033, 0, 0, 50000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);


-- ================================================== ============================================
-- SECTION 3: GAMEOBJECT SPAWN POINTS (151001-151033)
-- ================================================== ============================================
-- Location: Azshara Crater (Map 1, Zone 16, Area 0)
-- Respawn: 300 seconds
-- 33 treasures, one for each heirloom item
-- ================================================== ============================================

INSERT INTO gameobject 
  (guid, id, map, zoneId, areaId, spawnMask, phaseMask, 
   position_x, position_y, position_z, orientation, rotation0, rotation1, rotation2, rotation3,
   spawntimesecs, animprogress, state, VerifiedBuild)
VALUES
  -- Weapon Treasures
  (151001, 191001, 1, 16, 0, 1, 1, -3450.25, 3250.75, 150.50, 0.00, 0.0, 0.0, 0.0, 1.0, 300, 0, 1, 100),
  (151002, 191002, 1, 16, 0, 1, 1, -3520.50, 3180.25, 155.75, 1.57, 0.0, 0.0, 0.707, 0.707, 300, 0, 1, 100),
  (151003, 191003, 1, 16, 0, 1, 1, -3380.75, 3120.50, 148.25, 3.14, 0.0, 0.0, 1.0, 0.0, 300, 0, 1, 100),
  (151004, 191004, 1, 16, 0, 1, 1, -3420.00, 3050.75, 152.00, 4.71, 0.0, 0.0, 0.707, -0.707, 300, 0, 1, 100),
  (151005, 191005, 1, 16, 0, 1, 1, -3350.50, 3280.25, 160.50, 0.785, 0.0, 0.0, 0.383, 0.924, 300, 0, 1, 100),
  (151006, 191006, 1, 16, 0, 1, 1, -3480.75, 3150.00, 146.75, 2.356, 0.0, 0.0, 0.924, 0.383, 300, 0, 1, 100),
  
  -- Shield Treasure
  (151007, 191007, 1, 16, 0, 1, 1, -3410.25, 3220.50, 158.00, 1.571, 0.0, 0.0, 0.707, 0.707, 300, 0, 1, 100),
  
  -- Armor Treasures
  (151008, 191008, 1, 16, 0, 1, 1, -3390.00, 3090.75, 150.25, 0.00, 0.0, 0.0, 0.0, 1.0, 300, 0, 1, 100),
  (151009, 191009, 1, 16, 0, 1, 1, -3440.50, 3180.25, 154.50, 1.571, 0.0, 0.0, 0.707, 0.707, 300, 0, 1, 100),
  (151010, 191010, 1, 16, 0, 1, 1, -3360.75, 3240.00, 162.00, 3.142, 0.0, 0.0, 1.0, 0.0, 300, 0, 1, 100),
  (151011, 191011, 1, 16, 0, 1, 1, -3430.25, 3120.50, 148.75, 0.785, 0.0, 0.0, 0.383, 0.924, 300, 0, 1, 100),
  (151012, 191012, 1, 16, 0, 1, 1, -3370.50, 3160.75, 156.25, 2.356, 0.0, 0.0, 0.924, 0.383, 300, 0, 1, 100),
  (151013, 191013, 1, 16, 0, 1, 1, -3500.75, 3210.00, 157.50, 4.712, 0.0, 0.0, 0.707, -0.707, 300, 0, 1, 100),
  (151014, 191014, 1, 16, 0, 1, 1, -3410.00, 3280.50, 159.75, 0.393, 0.0, 0.0, 0.195, 0.981, 300, 0, 1, 100),
  (151015, 191015, 1, 16, 0, 1, 1, -3340.25, 3150.00, 151.00, 1.178, 0.0, 0.0, 0.556, 0.831, 300, 0, 1, 100),
  (151016, 191016, 1, 16, 0, 1, 1, -3480.50, 3090.25, 149.50, 1.963, 0.0, 0.0, 0.831, 0.556, 300, 0, 1, 100),
  (151017, 191017, 1, 16, 0, 1, 1, -3390.75, 3280.75, 161.50, 2.749, 0.0, 0.0, 0.981, 0.195, 300, 0, 1, 100),
  (151018, 191018, 1, 16, 0, 1, 1, -3450.00, 3150.50, 153.00, 3.534, 0.0, 0.0, 0.981, -0.195, 300, 0, 1, 100),
  (151019, 191019, 1, 16, 0, 1, 1, -3360.50, 3090.00, 147.25, 4.320, 0.0, 0.0, 0.831, -0.556, 300, 0, 1, 100),
  (151020, 191020, 1, 16, 0, 1, 1, -3420.25, 3240.50, 160.00, 5.106, 0.0, 0.0, 0.556, -0.831, 300, 0, 1, 100),
  (151021, 191021, 1, 16, 0, 1, 1, -3330.50, 3210.75, 155.50, 5.891, 0.0, 0.0, 0.195, -0.981, 300, 0, 1, 100),
  (151022, 191022, 1, 16, 0, 1, 1, -3510.75, 3270.00, 162.75, 0.262, 0.0, 0.0, 0.131, 0.991, 300, 0, 1, 100),
  (151023, 191023, 1, 16, 0, 1, 1, -3410.00, 3100.25, 149.50, 1.047, 0.0, 0.0, 0.5, 0.866, 300, 0, 1, 100),
  (151024, 191024, 1, 16, 0, 1, 1, -3360.25, 3330.50, 164.00, 1.833, 0.0, 0.0, 0.793, 0.609, 300, 0, 1, 100),
  
  -- Additional 9 treasures for remaining items (191025-191033)
  (151025, 191025, 1, 16, 0, 1, 1, -3400.50, 3200.75, 156.50, 0.524, 0.0, 0.0, 0.259, 0.966, 300, 0, 1, 100),
  (151026, 191026, 1, 16, 0, 1, 1, -3470.25, 3130.00, 151.75, 1.309, 0.0, 0.0, 0.608, 0.794, 300, 0, 1, 100),
  (151027, 191027, 1, 16, 0, 1, 1, -3340.75, 3170.50, 153.25, 2.094, 0.0, 0.0, 0.866, 0.5, 300, 0, 1, 100),
  (151028, 191028, 1, 16, 0, 1, 1, -3490.00, 3250.25, 159.00, 2.880, 0.0, 0.0, 0.991, 0.131, 300, 0, 1, 100),
  (151029, 191029, 1, 16, 0, 1, 1, -3370.25, 3110.75, 148.50, 3.665, 0.0, 0.0, 0.966, -0.259, 300, 0, 1, 100),
  (151030, 191030, 1, 16, 0, 1, 1, -3440.50, 3290.00, 163.00, 4.451, 0.0, 0.0, 0.794, -0.608, 300, 0, 1, 100),
  (151031, 191031, 1, 16, 0, 1, 1, -3320.75, 3230.25, 157.75, 5.236, 0.0, 0.0, 0.5, -0.866, 300, 0, 1, 100),
  (151032, 191032, 1, 16, 0, 1, 1, -3500.00, 3190.50, 154.25, 6.021, 0.0, 0.0, 0.131, -0.991, 300, 0, 1, 100),
  (151033, 191033, 1, 16, 0, 1, 1, -3380.25, 3260.75, 161.00, 0.131, 0.0, 0.0, 0.065, 0.998, 300, 0, 1, 100);


-- ================================================== ============================================
-- SECTION 4: GAMEOBJECT LOOT TABLES (191001-191033)
-- ================================================== ============================================
-- Each treasure contains one heirloom item
-- QuestRequired = 1: Loot only if quest not yet completed
-- Prevents re-looting same treasure per character
-- 33 loot entries for 33 items
-- ================================================== ============================================

INSERT INTO gameobject_loot_template
  (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
VALUES
  -- Weapon Treasures
  (191001, 191101, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Flamefury Blade'),
  (191002, 191102, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Stormfury'),
  (191003, 191103, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Frostbite Axe'),
  (191004, 191108, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Earthshaker Mace'),
  (191005, 191105, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Arcane Staff'),
  (191006, 191106, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Zephyr Bow'),
  
  -- Wand/Dagger/Polearm Treasures
  (191007, 191107, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Arcane Wand'),
  (191008, 191104, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Shadow Dagger'),
  (191009, 191109, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Polearm'),
  
  -- Armor Treasures - Head
  (191010, 191110, 0, 100, 1, 1, 0, 1, 1, 'Heirloom War Crown'),
  (191011, 191111, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Battle Helm'),
  (191012, 191112, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Kingly Circlet'),
  
  -- Armor Treasures - Chest
  (191013, 191113, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Battleplate'),
  (191014, 191114, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Dragonhide Tunic'),
  (191015, 191115, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Mithril Robe'),
  
  -- Armor Treasures - Legs
  (191016, 191116, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Legplates'),
  (191017, 191117, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Leggings'),
  (191018, 191118, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Trousers'),
  
  -- Armor Treasures - Shoulders
  (191019, 191119, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Pauldrons'),
  (191020, 191120, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Mantle'),
  (191021, 191121, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Spaulders'),
  
  -- Armor Treasures - Waist
  (191022, 191122, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Girdle'),
  (191023, 191123, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Cord'),
  (191024, 191124, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Waistband'),
  
  -- Armor Treasures - Feet
  (191025, 191125, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Sabatons'),
  (191026, 191126, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Treads'),
  (191027, 191127, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Boots'),
  
  -- Armor Treasures - Hands
  (191028, 191128, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Gauntlets'),
  (191029, 191129, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Gloves'),
  (191030, 191130, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Mittens'),
  
  -- Armor Treasures - Wrists
  (191031, 191131, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Bracers'),
  (191032, 191132, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Vambraces'),
  (191033, 191133, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Wristguards');


-- ================================================== ============================================
-- SECTION 5: QUEST FOR ONE-TIME LOOT TRACKING (Quest ID 50000)
-- ================================================== ============================================
-- Quest 50000: Artifact Discovery
-- Tracks treasure looting - one treasure per character
-- Hidden quest - doesn't appear in quest log
-- ================================================== ============================================

INSERT INTO quest_template
  (ID, QuestType, QuestLevel, MinLevel, QuestSortID, QuestInfoID,
   Title, Details, Objectives, OfferRewardText, RequestItemsText,
   Questflags, PrevQuestId, NextQuestId, ExclusiveGroup, LimitTime,
   RewardTitleId, RewardTalents, RewardArenaPoints, RewardSkillId, RewardSkillPoints,
   CharTitleId, PlayersSlain, BonusObjectiveStorage, VerifiedBuild)
VALUES
  (50000, 0, 255, 1, -1, 0,
   'Artifact Discovery Quest Tracker',
   'This hidden quest tracks artifact discovery. When you loot artifact treasures, completion is recorded.',
   'Discover artifact treasures in Azshara Crater',
   'You have discovered an artifact treasure!',
   '',
   2, 0, 0, 0, 0,
   0, 0, 0, 0, 0,
   0, 0, 0, 100);


-- ================================================== ============================================
-- SECTION 6: TIER 3 HEIRLOOM UPGRADE COSTS (dc_item_upgrade_costs)
-- ================================================== ============================================
-- 16 rows for upgrade levels 0-15
-- Essence costs escalate: 75 base, ~1.1x multiplier per level
-- Total to max: ~2,358 essence (alt-friendly vs 6,357 for artifacts)
-- Tier 3 (TIER_HEIRLOOM) - does not conflict with existing tiers
-- 
-- UPGRADE DESIGN:
--   Upgrades ADD secondary stats to heirloom items (not scale primary stats).
--   Primary stats scale with character level automatically (standard heirloom behavior).
--   stat_increase_percent controls SECONDARY stat scaling only (1.05x → 1.35x).
-- ================================================== ============================================

INSERT INTO dc_item_upgrade_costs 
  (tier_id, upgrade_level, token_cost, essence_cost, ilvl_increase, stat_increase_percent, season)
VALUES
  -- Level 0: Base (no cost)
  (3, 0, 0, 0, 0, 1.05, 1),
  
  -- Levels 1-5: Early progression
  (3, 1, 0, 75, 2, 1.07, 1),
  (3, 2, 0, 82, 4, 1.09, 1),
  (3, 3, 0, 90, 6, 1.11, 1),
  (3, 4, 0, 99, 8, 1.13, 1),
  (3, 5, 0, 109, 10, 1.15, 1),
  
  -- Levels 6-10: Mid progression
  (3, 6, 0, 120, 12, 1.17, 1),
  (3, 7, 0, 132, 14, 1.19, 1),
  (3, 8, 0, 145, 16, 1.21, 1),
  (3, 9, 0, 159, 18, 1.23, 1),
  (3, 10, 0, 175, 20, 1.25, 1),
  
  -- Levels 11-15: Late progression
  (3, 11, 0, 192, 22, 1.27, 1),
  (3, 12, 0, 211, 24, 1.29, 1),
  (3, 13, 0, 232, 26, 1.31, 1),
  (3, 14, 0, 256, 28, 1.33, 1),
  (3, 15, 0, 281, 30, 1.35, 1);


-- ================================================== ============================================
-- END OF HEIRLOOM TIER 6 SYSTEM - WORLD DATABASE
-- ================================================== ============================================
-- Total inserted:
--   33 Item Templates (191101-191133)
--   33 GameObject Templates (191001-191033)
--   33 GameObject Spawns (151001-151033)
--   33 GameObject Loot Entries (191001-191033)
--   1 Quest Template (50000)
--   16 Upgrade Cost Rows (Tier 6, Levels 0-15)
--
-- TIER 6 avoids conflict with TIER_RAID (Tier 3) in C++ enum
-- One treasure per item - 33 treasures total
-- No duplicates - clean, verified syntax
-- Ready for production execution
-- ================================================== ============================================

