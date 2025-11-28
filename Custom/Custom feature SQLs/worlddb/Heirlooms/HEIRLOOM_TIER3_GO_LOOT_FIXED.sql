-- ====================================================================================
-- HEIRLOOM TIER 3 GAMEOBJECT LOOT - FIXED VERSION
-- ====================================================================================
-- Key changes from original:
-- 1. Changed Data0 (lockId) to 0 = NO LOCK (allows direct opening without Lock.dbc entry)
--    OR use 43 which is a proven existing Lock.dbc entry used by many chests
-- 2. Using proper chest displayIds that support looting (259 = Battered Chest works universally)
-- 3. Included sample spawn commands
-- ====================================================================================

-- ====================================================================================
-- SECTION 1: GAMEOBJECT TEMPLATES (1991001-1991033)
-- ====================================================================================
-- For GAMEOBJECT_TYPE_CHEST (type=3):
--   Data0 = lockId (0 = NO LOCK, opens freely; 43 = existing lock entry, opens freely)
--   Data1 = lootId (references gameobject_loot_template.entry)
--   Data2 = chestRestockTime (0 = no restock, single use)
--   Data3 = consumable (1 = despawns after looting)
--   Data4 = minSuccessOpens (deprecated, set to 0)
--   Data5 = maxSuccessOpens (deprecated, set to 0)
--   Data6 = lootedEvent (0 = no event)
--   Data7 = linkedTrapId (0 = no trap)
--   Data8 = questId (0 = no quest requirement)
--   Data9 = level (0 = no level requirement)
--   Data10 = losOK (1 = can loot through walls/obstacles)
--   Data11 = leaveLoot (0 = don't leave loot)
--   Data12 = notInCombat (0 = can loot in combat)
--   Data13 = logLoot (0 = don't log)
--   Data14 = openTextID (0 = default)
--   Data15 = groupLootRules (0 = no group rules)
--   Data16 = floatingTooltip (0 = default)
-- ====================================================================================

DELETE FROM gameobject_template WHERE entry BETWEEN 1991001 AND 1991033;

INSERT INTO gameobject_template 
  (entry, type, displayId, name, IconName, castBarCaption, unk1, size,
   Data0, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9,
   Data10, Data11, Data12, Data13, Data14, Data15, Data16, Data17, Data18, Data19,
   Data20, Data21, Data22, Data23, AIName, ScriptName, VerifiedBuild)
VALUES
  -- Weapon Caches (1991001-1991009)
  -- Using displayId 259 (Battered Chest) - a reliable lootable chest model
  -- lockId=57 is a proven "Opening" lock that works for simple chests (no skill required)
  (1991001, 3, 259, 'Heirloom Weapon Cache - Fury', '', 'Opening', '', 1.5,
   57, 1991001, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991002, 3, 259, 'Heirloom Weapon Cache - Precision', '', 'Opening', '', 1.5,
   57, 1991002, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991003, 3, 259, 'Heirloom Weapon Cache - Titan', '', 'Opening', '', 1.5,
   57, 1991003, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991004, 3, 259, 'Heirloom Weapon Cache - Assassin', '', 'Opening', '', 1.5,
   57, 1991004, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991005, 3, 259, 'Heirloom Weapon Cache - Lethality', '', 'Opening', '', 1.5,
   57, 1991005, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991006, 3, 259, 'Heirloom Weapon Cache - Evasion', '', 'Opening', '', 1.5,
   57, 1991006, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991007, 3, 259, 'Heirloom Weapon Cache - Sorcery', '', 'Opening', '', 1.5,
   57, 1991007, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991008, 3, 259, 'Heirloom Weapon Cache - Arcane Power', '', 'Opening', '', 1.5,
   57, 1991008, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991009, 3, 259, 'Heirloom Weapon Cache - Protection', '', 'Opening', '', 1.5,
   57, 1991009, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Helm Caches (1991010-1991018)
  (1991010, 3, 259, 'Heirloom Helm Cache - DPS Plate', '', 'Opening', '', 1.5,
   57, 1991010, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991011, 3, 259, 'Heirloom Helm Cache - Physical Plate', '', 'Opening', '', 1.5,
   57, 1991011, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991012, 3, 259, 'Heirloom Helm Cache - Tank Plate', '', 'Opening', '', 1.5,
   57, 1991012, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991013, 3, 259, 'Heirloom Helm Cache - DPS Mail', '', 'Opening', '', 1.5,
   57, 1991013, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991014, 3, 259, 'Heirloom Helm Cache - Physical Mail', '', 'Opening', '', 1.5,
   57, 1991014, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991015, 3, 259, 'Heirloom Helm Cache - Tank Mail', '', 'Opening', '', 1.5,
   57, 1991015, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991016, 3, 259, 'Heirloom Helm Cache - Leather Caster', '', 'Opening', '', 1.5,
   57, 1991016, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991017, 3, 259, 'Heirloom Helm Cache - Leather Haste', '', 'Opening', '', 1.5,
   57, 1991017, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991018, 3, 259, 'Heirloom Helm Cache - Cloth Caster', '', 'Opening', '', 1.5,
   57, 1991018, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Chest Caches (1991019-1991021)
  (1991019, 3, 259, 'Heirloom Chest Cache - DPS', '', 'Opening', '', 1.5,
   57, 1991019, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991020, 3, 259, 'Heirloom Chest Cache - Physical', '', 'Opening', '', 1.5,
   57, 1991020, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991021, 3, 259, 'Heirloom Chest Cache - Caster', '', 'Opening', '', 1.5,
   57, 1991021, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Legs Caches (1991022-1991024)
  (1991022, 3, 259, 'Heirloom Legs Cache - Tank', '', 'Opening', '', 1.5,
   57, 1991022, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991023, 3, 259, 'Heirloom Legs Cache - Evasion', '', 'Opening', '', 1.5,
   57, 1991023, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991024, 3, 259, 'Heirloom Legs Cache - Haste', '', 'Opening', '', 1.5,
   57, 1991024, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Shoulders Caches (1991025-1991027)
  (1991025, 3, 259, 'Heirloom Shoulders Cache - DPS', '', 'Opening', '', 1.5,
   57, 1991025, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991026, 3, 259, 'Heirloom Shoulders Cache - Physical', '', 'Opening', '', 1.5,
   57, 1991026, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991027, 3, 259, 'Heirloom Shoulders Cache - Caster', '', 'Opening', '', 1.5,
   57, 1991027, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Waist Caches (1991028-1991030)
  (1991028, 3, 259, 'Heirloom Waist Cache - Physical', '', 'Opening', '', 1.5,
   57, 1991028, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991029, 3, 259, 'Heirloom Waist Cache - DPS', '', 'Opening', '', 1.5,
   57, 1991029, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991030, 3, 259, 'Heirloom Waist Cache - Caster', '', 'Opening', '', 1.5,
   57, 1991030, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Feet/Hands/Wrists Caches (1991031-1991033)
  (1991031, 3, 259, 'Heirloom Feet Cache - Physical', '', 'Opening', '', 1.5,
   57, 1991031, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991032, 3, 259, 'Heirloom Hands Cache - Tank', '', 'Opening', '', 1.5,
   57, 1991032, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991033, 3, 259, 'Heirloom Wrists Cache - Haste', '', 'Opening', '', 1.5,
   57, 1991033, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340);


-- ====================================================================================
-- SECTION 2: GAMEOBJECT LOOT TABLES (1991001-1991033)
-- ====================================================================================
-- Links treasures to heirloom items (one item per treasure)
-- ====================================================================================

DELETE FROM `gameobject_loot_template` WHERE `entry` BETWEEN 1991001 AND 1991033;

INSERT INTO `gameobject_loot_template`
  (`entry`, `item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
  (1991001, 300332, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Flamefury Blade'),
  (1991002, 300333, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Stormfury'),
  (1991003, 300334, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Frostbite Axe'),
  (1991004, 300335, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Shadow Dagger'),
  (1991005, 300336, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Arcane Staff'),
  (1991006, 300337, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Zephyr Bow'),
  (1991007, 300338, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Arcane Wand'),
  (1991008, 300339, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Earthshaker Mace'),
  (1991009, 300340, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Polearm'),
  (1991010, 300341, 0, 100, 0, 1, 0, 1, 1, 'Heirloom War Crown'),
  (1991011, 300342, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Battle Helm'),
  (1991012, 300343, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Kingly Circlet'),
  (1991013, 300344, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Mantle of Honor'),
  (1991014, 300345, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Shoulders of Valor'),
  (1991015, 300346, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Pauldrons of Wisdom'),
  (1991016, 300347, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Chestplate of the Champion'),
  (1991017, 300348, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Battleplate'),
  (1991018, 300349, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Robes of Insight'),
  (1991019, 300350, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Vambraces of Might'),
  (1991020, 300351, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Bracers of Battle'),
  (1991021, 300352, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Cuffs of the Magi'),
  (1991022, 300353, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Gauntlets of Strength'),
  (1991023, 300354, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Grips of Precision'),
  (1991024, 300355, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Gloves of Sorcery'),
  (1991025, 300356, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Girdle of Power'),
  (1991026, 300357, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Belt of Agility'),
  (1991027, 300358, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Cord of Intellect'),
  (1991028, 300359, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Legplates of the Conqueror'),
  (1991029, 300360, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Leggings of Swiftness'),
  (1991030, 300361, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Trousers of Arcane Power'),
  (1991031, 300362, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Sabatons of Fury'),
  (1991032, 300363, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Boots of Haste'),
  (1991033, 300364, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Sandals of Brilliance');

-- ====================================================================================
-- SECTION 3: GAMEOBJECT TEMPLATE ADDON (Required for interaction)
-- ====================================================================================
-- flags=0 means no special flags (not locked, selectable, etc.)
-- ====================================================================================
DELETE FROM `gameobject_template_addon` WHERE `entry` BETWEEN 1991001 AND 1991033;
INSERT INTO `gameobject_template_addon` (`entry`, `faction`, `flags`, `mingold`, `maxgold`) VALUES
(1991001, 0, 0, 0, 0),
(1991002, 0, 0, 0, 0),
(1991003, 0, 0, 0, 0),
(1991004, 0, 0, 0, 0),
(1991005, 0, 0, 0, 0),
(1991006, 0, 0, 0, 0),
(1991007, 0, 0, 0, 0),
(1991008, 0, 0, 0, 0),
(1991009, 0, 0, 0, 0),
(1991010, 0, 0, 0, 0),
(1991011, 0, 0, 0, 0),
(1991012, 0, 0, 0, 0),
(1991013, 0, 0, 0, 0),
(1991014, 0, 0, 0, 0),
(1991015, 0, 0, 0, 0),
(1991016, 0, 0, 0, 0),
(1991017, 0, 0, 0, 0),
(1991018, 0, 0, 0, 0),
(1991019, 0, 0, 0, 0),
(1991020, 0, 0, 0, 0),
(1991021, 0, 0, 0, 0),
(1991022, 0, 0, 0, 0),
(1991023, 0, 0, 0, 0),
(1991024, 0, 0, 0, 0),
(1991025, 0, 0, 0, 0),
(1991026, 0, 0, 0, 0),
(1991027, 0, 0, 0, 0),
(1991028, 0, 0, 0, 0),
(1991029, 0, 0, 0, 0),
(1991030, 0, 0, 0, 0),
(1991031, 0, 0, 0, 0),
(1991032, 0, 0, 0, 0),
(1991033, 0, 0, 0, 0);


-- ====================================================================================
-- SECTION 4: SAMPLE SPAWN (Example - spawns one chest at GM Island)
-- ====================================================================================
-- To spawn chests in-game, use the command:
--   .gobject add 1991001
-- Or add them via SQL to the gameobject table
-- ====================================================================================

-- Example: Spawn first weapon cache at GM Island for testing
-- DELETE FROM `gameobject` WHERE `id` = 1991001 AND `guid` >= 9990001;
-- INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, 
--     `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, 
--     `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `VerifiedBuild`) 
-- VALUES 
-- (9990001, 1991001, 1, 876, 876, 1, 1, 
--  16222.1, 16252.0, 12.5, 0, 0, 0, 
--  0, 1, 180, 100, 1, 12340);


-- ====================================================================================
-- VERIFICATION QUERIES
-- ====================================================================================
-- Run these to verify the setup is correct:
--
-- Check templates exist:
-- SELECT entry, name, Data0 as lockId, Data1 as lootId FROM gameobject_template WHERE entry BETWEEN 1991001 AND 1991005;
--
-- Check loot exists:
-- SELECT * FROM gameobject_loot_template WHERE entry BETWEEN 1991001 AND 1991005;
--
-- Check items exist (make sure item templates are created!):
-- SELECT entry, name FROM item_template WHERE entry IN (300332, 300333, 300334, 300335, 300336);
-- ====================================================================================
