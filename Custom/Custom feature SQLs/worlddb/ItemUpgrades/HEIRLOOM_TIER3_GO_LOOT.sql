-- ============================================================================
-- HEIRLOOM TIER 3 - GAMEOBJECT LOOT TABLES
-- Ensures each treasure gameobject (191001-191033) drops its paired heirloom.
-- Execute on the `acore_world` database.
-- ============================================================================

DELETE FROM `gameobject_loot_template` WHERE `entry` BETWEEN 1991001 AND 1991033;

INSERT INTO `gameobject_loot_template`
  (`entry`, `item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
  (1991001, 191101, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Flamefury Blade'),
  (1991002, 191102, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Stormfury'),
  (1991003, 191103, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Frostbite Axe'),
  (1991004, 191104, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Shadow Dagger'),
  (1991005, 191105, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Arcane Staff'),
  (1991006, 191106, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Zephyr Bow'),
  (1991007, 191107, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Arcane Wand'),
  (1991008, 191108, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Earthshaker Mace'),
  (1991009, 191109, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Polearm'),
  (1991010, 191110, 0, 100, 0, 1, 0, 1, 1, 'Heirloom War Crown'),
  (1991011, 191111, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Battle Helm'),
  (1991012, 191112, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Kingly Circlet'),
  (1991013, 191113, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Mantle of Honor'),
  (1991014, 191114, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Shoulders of Valor'),
  (1991015, 191115, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Pauldrons of Wisdom'),
  (1991016, 191116, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Chestplate of the Champion'),
  (1991017, 191117, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Battleplate'),
  (1991018, 191118, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Robes of Insight'),
  (1991019, 191119, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Vambraces of Might'),
  (1991020, 191120, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Bracers of Battle'),
  (1991021, 191121, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Cuffs of the Magi'),
  (1991022, 191122, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Gauntlets of Strength'),
  (1991023, 191123, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Grips of Precision'),
  (1991024, 191124, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Gloves of Sorcery'),
  (1991025, 191125, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Girdle of Power'),
  (1991026, 191126, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Belt of Agility'),
  (1991027, 191127, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Cord of Intellect'),
  (1991028, 191128, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Legplates of the Conqueror'),
  (1991029, 191129, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Leggings of Swiftness'),
  (1991030, 191130, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Trousers of Arcane Power'),
  (1991031, 191131, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Sabatons of Fury'),
  (1991032, 191132, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Boots of Haste'),
  (1991033, 191133, 0, 100, 0, 1, 0, 1, 1, 'Heirloom Sandals of Brilliance');
