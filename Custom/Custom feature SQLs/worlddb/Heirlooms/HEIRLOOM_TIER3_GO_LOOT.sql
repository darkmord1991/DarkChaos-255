-- ====================================================================================
-- SECTION 2: GAMEOBJECT TEMPLATES (191001-191033)
-- ====================================================================================
-- 33 treasure gameobject templates (loot caches)
-- Note: Gameobject spawns should be placed manually by the user
-- ====================================================================================

DELETE FROM gameobject_template WHERE entry BETWEEN 1991001 AND 1991033;

INSERT INTO gameobject_template 
  (entry, type, displayId, name, IconName, castBarCaption, unk1, size,
   Data0, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9,
   Data10, Data11, Data12, Data13, Data14, Data15, Data16, Data17, Data18, Data19,
   Data20, Data21, Data22, Data23, AIName, ScriptName, VerifiedBuild)
VALUES
  -- Weapon Caches (191001-191009)
  -- Data fields: Data0=lockId(0), Data1=lootId, Data2=restockTime(0), Data3=consumable(1), rest=0
  (1991001, 3, 6851, 'Heirloom Weapon Cache - Fury', '', 'Opening', '', 1.0,
   0, 1991001, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991002, 3, 6851, 'Heirloom Weapon Cache - Precision', '', 'Opening', '', 1.0,
   0, 1991002, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991003, 3, 6851, 'Heirloom Weapon Cache - Titan', '', 'Opening', '', 1.0,
   0, 1991003, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991004, 3, 6851, 'Heirloom Weapon Cache - Assassin', '', 'Opening', '', 1.0,
   0, 1991004, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991005, 3, 6851, 'Heirloom Weapon Cache - Lethality', '', 'Opening', '', 1.0,
   0, 1991005, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991006, 3, 6851, 'Heirloom Weapon Cache - Evasion', '', 'Opening', '', 1.0,
   0, 1991006, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991007, 3, 6851, 'Heirloom Weapon Cache - Sorcery', '', 'Opening', '', 1.0,
   0, 1991007, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991008, 3, 6851, 'Heirloom Weapon Cache - Arcane Power', '', 'Opening', '', 1.0,
   0, 1991008, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991009, 3, 6851, 'Heirloom Weapon Cache - Protection', '', 'Opening', '', 1.0,
   0, 1991009, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Helm Caches (191010-191018)
  (1991010, 3, 7507, 'Heirloom Helm Cache - DPS Plate', '', 'Opening', '', 1.0,
   0, 1991010, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991011, 3, 7507, 'Heirloom Helm Cache - Physical Plate', '', 'Opening', '', 1.0,
   0, 1991011, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991012, 3, 7507, 'Heirloom Helm Cache - Tank Plate', '', 'Opening', '', 1.0,
   0, 1991012, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991013, 3, 7507, 'Heirloom Helm Cache - DPS Mail', '', 'Opening', '', 1.0,
   0, 1991013, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991014, 3, 7507, 'Heirloom Helm Cache - Physical Mail', '', 'Opening', '', 1.0,
   0, 1991014, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991015, 3, 7507, 'Heirloom Helm Cache - Tank Mail', '', 'Opening', '', 1.0,
   0, 1991015, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991016, 3, 7507, 'Heirloom Helm Cache - Leather Caster', '', 'Opening', '', 1.0,
   0, 1991016, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991017, 3, 7507, 'Heirloom Helm Cache - Leather Haste', '', 'Opening', '', 1.0,
   0, 1991017, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991018, 3, 7507, 'Heirloom Helm Cache - Cloth Caster', '', 'Opening', '', 1.0,
   0, 1991018, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Chest Caches (191019-191021)
  (1991019, 3, 7507, 'Heirloom Chest Cache - DPS', '', 'Opening', '', 1.0,
   0, 1991019, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991020, 3, 7507, 'Heirloom Chest Cache - Physical', '', 'Opening', '', 1.0,
   0, 1991020, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991021, 3, 7507, 'Heirloom Chest Cache - Caster', '', 'Opening', '', 1.0,
   0, 1991021, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Legs Caches (191022-191024)
  (1991022, 3, 7507, 'Heirloom Legs Cache - Tank', '', 'Opening', '', 1.0,
   0, 1991022, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991023, 3, 7507, 'Heirloom Legs Cache - Evasion', '', 'Opening', '', 1.0,
   0, 1991023, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991024, 3, 7507, 'Heirloom Legs Cache - Haste', '', 'Opening', '', 1.0,
   0, 1991024, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Shoulders Caches (191025-191027)
  (1991025, 3, 7507, 'Heirloom Shoulders Cache - DPS', '', 'Opening', '', 1.0,
   0, 1991025, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991026, 3, 7507, 'Heirloom Shoulders Cache - Physical', '', 'Opening', '', 1.0,
   0, 1991026, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991027, 3, 7507, 'Heirloom Shoulders Cache - Caster', '', 'Opening', '', 1.0,
   0, 1991027, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Waist Caches (191028-191030)
  (1991028, 3, 7507, 'Heirloom Waist Cache - Physical', '', 'Opening', '', 1.0,
   0, 1991028, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991029, 3, 7507, 'Heirloom Waist Cache - DPS', '', 'Opening', '', 1.0,
   0, 1991029, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991030, 3, 7507, 'Heirloom Waist Cache - Caster', '', 'Opening', '', 1.0,
   0, 1991030, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Feet/Hands/Wrists Caches (191031-191033)
  (1991031, 3, 7507, 'Heirloom Feet Cache - Physical', '', 'Opening', '', 1.0,
   0, 1991031, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991032, 3, 7507, 'Heirloom Hands Cache - Tank', '', 'Opening', '', 1.0,
   0, 1991032, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (1991033, 3, 7507, 'Heirloom Wrists Cache - Haste', '', 'Opening', '', 1.0,
   0, 1991033, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340);


-- ====================================================================================
-- SECTION 3: GAMEOBJECT LOOT TABLES (191001-191033)
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
-- SECTION 4: GAMEOBJECT TEMPLATE ADDON (Required for interaction)
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
