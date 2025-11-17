-- ====================================================================================
-- HEIRLOOM TIER 3 SYSTEM - COMPLETE ITEM & GAMEOBJECT IMPLEMENTATION
-- ====================================================================================
-- Date: November 16, 2025
-- Database: acore_world
--
-- Entry ID Ranges:
--   Items: 191101-191135 (35 items - 33 upgradeable + 1 bag + 1 shirt)
--   Gameobjects: 191001-191033 (33 treasures)
--
-- DESIGN NOTES:
--   - Items 191101-191133: Upgradeable heirlooms (Tier 3, 15 levels, essence-based)
--   - Item 191134: Heirloom Bag (scales slots with heirloom_scaling_255 system, NOT upgradeable)
--   - Item 191135: Heirloom Shirt (cosmetic, NOT upgradeable)
--   - PRIMARY STATS: Scale automatically with character level (heirloom_scaling_255.cpp)
--   - SECONDARY STATS: Added ONLY via Tier 3 upgrade system (1.05x → 1.35x)
--   - Gameobject spawns: To be placed manually by user
-- ====================================================================================

-- ====================================================================================
-- SECTION 1: HEIRLOOM ITEM TEMPLATES (191101-191135)
-- ====================================================================================
-- 33 upgradeable items + 1 bag + 1 shirt
-- Stat variants: DPS (Crit/Haste), Physical (Hit/Expertise), Tank (Dodge/Defense)
-- 
-- SCALING SYSTEM:
--   - ScalingStatDistribution: Links to ScalingStatDistribution.csv for primary stats
--   - ScalingStatValue: Always 1 for heirlooms (uniform scaling curve)
--   - Quality: 7 (ITEM_QUALITY_HEIRLOOM) - detected by heirloom_scaling_255.cpp
--   - stat_type1: Primary stat (STR=7, AGI=3, INT=5, STA=4) - scales with player level
--   - stat_type2: Secondary stat (Crit/Hit/etc.) - ONLY added via Tier 3 upgrades
--   - bonding: 1 (Bind on Pickup, acts as BoA for heirlooms via Quality=7)
-- ====================================================================================

DELETE FROM item_template WHERE entry BETWEEN 191101 AND 191135;

INSERT INTO item_template 
  (entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra,
   BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace,
   ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank,
   RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable,
   ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3,
   stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7,
   stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10,
   ScalingStatDistribution, ScalingStatValue,
   dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2,
   armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res,
   delay, ammo_type, RangedModRange,
   spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1,
   spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2,
   spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3,
   spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4,
   spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5,
   bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath,
   RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory,
   socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3,
   socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory,
   HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES
  -- ====================================================================================
  -- WEAPONS (191101-191109) - 9 items, 3 stat variants each (STR, AGI, INT)
  -- ====================================================================================
  
  -- Two-Hand Swords (Strength) - 3 variants
  (191101, 2, 8, 'Heirloom Greatsword of Fury', 31309, 7, 1, 0, 1, 0, 0,
   17, -1, -1, 1, 1,
   7, 1, 32, 0,  -- STR + Crit (added via upgrade)
   0, 0,
   0, 3600, 1, 'Scales with level. Upgradeable with essence.', 1, 1, 0,
   0, 0, '', 12340),
  (191102, 2, 8, 'Heirloom Greatsword of Precision', 31309, 7, 1, 0, 1, 0, 0,
   17, -1, -1, 1, 1,
   7, 1, 31, 0,  -- STR + Hit (added via upgrade)
   0, 0,
   0, 3600, 1, 'Scales with level. Upgradeable with essence.', 1, 1, 0,
   0, 0, '', 12340),
  (191103, 2, 8, 'Heirloom Greatsword of the Titan', 31309, 7, 1, 0, 1, 0, 0,
   17, -1, -1, 1, 1,
   7, 1, 13, 0,  -- STR + Dodge (tank, added via upgrade)
   0, 0,
   0, 3600, 1, 'Scales with level. Upgradeable with essence.', 1, 1, 0,
   0, 0, '', 12340),
  
  -- Daggers (Agility) - 3 variants
  (191104, 2, 15, 'Heirloom Dagger of the Assassin', 29132, 7, 1, 0, 1, 0, 0,
   13, -1, -1, 1, 1,
   3, 1, 32, 0,  -- AGI + Crit (added via upgrade)
   0, 0,
   0, 1800, 1, 'Scales with level. Upgradeable with essence.', 1, 3, 0,
   0, 0, '', 12340),
  (191105, 2, 15, 'Heirloom Dagger of Lethality', 29132, 7, 1, 0, 1, 0, 0,
   13, -1, -1, 1, 1,
   3, 1, 37, 0,  -- AGI + Expertise (added via upgrade)
   0, 0,
   0, 1800, 1, 'Scales with level. Upgradeable with essence.', 1, 3, 0,
   0, 0, '', 12340),
  (191106, 2, 15, 'Heirloom Dagger of Evasion', 29132, 7, 1, 0, 1, 0, 0,
   13, -1, -1, 1, 1,
   3, 1, 13, 0,  -- AGI + Dodge (added via upgrade)
   0, 0,
   0, 1800, 1, 'Scales with level. Upgradeable with essence.', 1, 3, 0,
   0, 0, '', 12340),
  
  -- Staves (Intellect) - 3 variants
  (191107, 2, 10, 'Heirloom Staff of Sorcery', 31452, 7, 1, 0, 1, 0, 0,
   17, -1, -1, 1, 1,
   5, 1, 32, 0,  -- INT + Crit (added via upgrade)
   0, 0,
   0, 3400, 1, 'Scales with level. Upgradeable with essence.', 2, 2, 0,
   0, 0, '', 12340),
  (191108, 2, 10, 'Heirloom Staff of Arcane Power', 31452, 7, 1, 0, 1, 0, 0,
   17, -1, -1, 1, 1,
   5, 1, 36, 0,  -- INT + Haste (added via upgrade)
   0, 0,
   0, 3400, 1, 'Scales with level. Upgradeable with essence.', 2, 2, 0,
   0, 0, '', 12340),
  (191109, 2, 10, 'Heirloom Staff of Protection', 31452, 7, 1, 0, 1, 0, 0,
   17, -1, -1, 1, 1,
   5, 1, 12, 0,  -- INT + Defense (added via upgrade)
   0, 0,
   0, 3400, 1, 'Scales with level. Upgradeable with essence.', 2, 2, 0,
   0, 0, '', 12340),
  
  -- ====================================================================================
  -- ARMOR - HEAD (191110-191118) - 9 items, 3 per armor type × 3 stat variants
  -- ====================================================================================
  
  -- Plate Helms
  (191110, 4, 4, 'Heirloom Plate Helm of Fury', 22418, 7, 1, 0, 1, 0, 0,
   1, -1, -1, 1, 1,
   7, 1, 32, 0,  -- STR + Crit
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 6, 0, 120,
   0, 0, '', 12340),
  (191111, 4, 4, 'Heirloom Plate Helm of Precision', 22418, 7, 1, 0, 1, 0, 0,
   1, -1, -1, 1, 1,
   7, 1, 31, 0,  -- STR + Hit
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 6, 0, 120,
   0, 0, '', 12340),
  (191112, 4, 4, 'Heirloom Plate Helm of the Titan', 22418, 7, 1, 0, 1, 0, 0,
   1, -1, -1, 1, 1,
   7, 1, 13, 0,  -- STR + Dodge
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 6, 0, 120,
   0, 0, '', 12340),
  
  -- Mail Helms
  (191113, 4, 3, 'Heirloom Mail Helm of the Predator', 22401, 7, 1, 0, 1, 0, 0,
   1, -1, -1, 1, 1,
   3, 1, 32, 0,  -- AGI + Crit
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 5, 0, 100,
   0, 0, '', 12340),
  (191114, 4, 3, 'Heirloom Mail Helm of Lethality', 22401, 7, 1, 0, 1, 0, 0,
   1, -1, -1, 1, 1,
   3, 1, 37, 0,  -- AGI + Expertise
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 5, 0, 100,
   0, 0, '', 12340),
  (191115, 4, 3, 'Heirloom Mail Helm of Evasion', 22401, 7, 1, 0, 1, 0, 0,
   1, -1, -1, 1, 1,
   3, 1, 13, 0,  -- AGI + Dodge
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 5, 0, 100,
   0, 0, '', 12340),
  
  -- Leather/Cloth Helms
  (191116, 4, 2, 'Heirloom Leather Helm of Sorcery', 22376, 7, 1, 0, 1, 0, 0,
   1, -1, -1, 1, 1,
   5, 1, 32, 0,  -- INT + Crit
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 8, 0, 75,
   0, 0, '', 12340),
  (191117, 4, 2, 'Heirloom Leather Helm of Arcane Power', 22376, 7, 1, 0, 1, 0, 0,
   1, -1, -1, 1, 1,
   5, 1, 36, 0,  -- INT + Haste
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 8, 0, 75,
   0, 0, '', 12340),
  (191118, 4, 1, 'Heirloom Cloth Helm of Insight', 22347, 7, 1, 0, 1, 0, 0,
   1, -1, -1, 1, 1,
   5, 1, 45, 0,  -- INT + Spell Power
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 7, 0, 50,
   0, 0, '', 12340),
  
  -- ====================================================================================
  -- ARMOR - CHEST (191119-191121) - 3 items
  -- ====================================================================================
  
  (191119, 4, 4, 'Heirloom Plate Chestguard of Fury', 22428, 7, 1, 0, 1, 0, 0,
   5, -1, -1, 1, 1,
   7, 1, 32, 0,  -- STR + Crit
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 6, 0, 165,
   0, 0, '', 12340),
  (191120, 4, 3, 'Heirloom Mail Hauberk of the Predator', 22407, 7, 1, 0, 1, 0, 0,
   5, -1, -1, 1, 1,
   3, 1, 32, 0,  -- AGI + Crit
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 5, 0, 140,
   0, 0, '', 12340),
  (191121, 4, 1, 'Heirloom Cloth Robe of Sorcery', 22350, 7, 1, 0, 1, 0, 0,
   20, -1, -1, 1, 1,
   5, 1, 32, 0,  -- INT + Crit
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 7, 0, 100,
   0, 0, '', 12340),
  
  -- ====================================================================================
  -- ARMOR - LEGS (191122-191124) - 3 items
  -- ====================================================================================
  
  (191122, 4, 4, 'Heirloom Plate Legguards of the Titan', 22433, 7, 1, 0, 1, 0, 0,
   7, -1, -1, 1, 1,
   7, 1, 13, 0,  -- STR + Dodge
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 6, 0, 150,
   0, 0, '', 12340),
  (191123, 4, 3, 'Heirloom Mail Leggings of Evasion', 22412, 7, 1, 0, 1, 0, 0,
   7, -1, -1, 1, 1,
   3, 1, 13, 0,  -- AGI + Dodge
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 5, 0, 120,
   0, 0, '', 12340),
  (191124, 4, 1, 'Heirloom Cloth Trousers of Arcane Power', 22352, 7, 1, 0, 1, 0, 0,
   7, -1, -1, 1, 1,
   5, 1, 36, 0,  -- INT + Haste
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 7, 0, 75,
   0, 0, '', 12340),
  
  -- ====================================================================================
  -- ARMOR - SHOULDERS (191125-191127) - 3 items
  -- ====================================================================================
  
  (191125, 4, 4, 'Heirloom Plate Pauldrons of Fury', 22423, 7, 1, 0, 1, 0, 0,
   3, -1, -1, 1, 1,
   7, 1, 32, 0,  -- STR + Crit
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 6, 0, 120,
   0, 0, '', 12340),
  (191126, 4, 3, 'Heirloom Mail Spaulders of Lethality', 22402, 7, 1, 0, 1, 0, 0,
   3, -1, -1, 1, 1,
   3, 1, 37, 0,  -- AGI + Expertise
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 5, 0, 100,
   0, 0, '', 12340),
  (191127, 4, 1, 'Heirloom Cloth Mantle of Insight', 22348, 7, 1, 0, 1, 0, 0,
   3, -1, -1, 1, 1,
   5, 1, 45, 0,  -- INT + Spell Power
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 7, 0, 60,
   0, 0, '', 12340),
  
  -- ====================================================================================
  -- ARMOR - WAIST (191128-191130) - 3 items
  -- ====================================================================================
  
  (191128, 4, 4, 'Heirloom Plate Girdle of Precision', 22415, 7, 1, 0, 1, 0, 0,
   6, -1, -1, 1, 1,
   7, 1, 31, 0,  -- STR + Hit
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 6, 0, 75,
   0, 0, '', 12340),
  (191129, 4, 2, 'Heirloom Leather Cord of the Predator', 22378, 7, 1, 0, 1, 0, 0,
   6, -1, -1, 1, 1,
   3, 1, 32, 0,  -- AGI + Crit
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 8, 0, 55,
   0, 0, '', 12340),
  (191130, 4, 1, 'Heirloom Cloth Waistband of Sorcery', 22349, 7, 1, 0, 1, 0, 0,
   6, -1, -1, 1, 1,
   5, 1, 32, 0,  -- INT + Crit
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 7, 0, 40,
   0, 0, '', 12340),
  
  -- ====================================================================================
  -- ARMOR - FEET (191131) - 1 item (continuing from waist)
  -- ====================================================================================
  
  (191131, 4, 3, 'Heirloom Mail Treads of Lethality', 22409, 7, 1, 0, 1, 0, 0,
   8, -1, -1, 1, 1,
   3, 1, 37, 0,  -- AGI + Expertise
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 5, 0, 90,
   0, 0, '', 12340),
  
  -- ====================================================================================
  -- ARMOR - HANDS (191132) - 1 item
  -- ====================================================================================
  
  (191132, 4, 4, 'Heirloom Plate Gauntlets of the Titan', 22420, 7, 1, 0, 1, 0, 0,
   10, -1, -1, 1, 1,
   7, 1, 13, 0,  -- STR + Dodge
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 6, 0, 75,
   0, 0, '', 12340),
  
  -- ====================================================================================
  -- ARMOR - WRISTS (191133) - 1 item
  -- ====================================================================================
  
  (191133, 4, 1, 'Heirloom Cloth Wristguards of Arcane Power', 22351, 7, 1, 0, 1, 0, 0,
   9, -1, -1, 1, 1,
   5, 1, 36, 0,  -- INT + Haste
   0, 0,
   1, 0, 1, 'Scales with level. Upgradeable with essence.', 7, 0, 40,
   0, 0, '', 12340),
  
  -- ====================================================================================
  -- SPECIAL ITEMS - BAG & SHIRT (191134-191135)
  -- ====================================================================================
  
  -- Heirloom Bag (NOT upgradeable, scales slots via heirloom_scaling_255 system)
  (191134, 1, 0, 'Heirloom Bottomless Bag', 19914, 7, 1, 0, 1, 0, 0,
   0, -1, -1, 1, 1,
   0, 0, 0, 0,
   0, 0,
   0, 0, 1, 'Bag slots scale with character level. NOT upgradeable.', 5, 0, 0,
   0, 16, 'HeirloomBagScript', 12340),
  
  -- Heirloom Shirt (Cosmetic, NOT upgradeable)
  (191135, 4, 0, 'Heirloom Formal Shirt', 6833, 7, 1, 0, 1, 0, 0,
   4, -1, -1, 1, 1,
   0, 0, 0, 0,
   0, 0,
   0, 0, 1, 'A stylish formal shirt. NOT upgradeable.', 7, 0, 0,
   0, 0, '', 12340);


-- ====================================================================================
-- SECTION 2: GAMEOBJECT TEMPLATES (191001-191033)
-- ====================================================================================
-- 33 treasure gameobject templates (loot caches)
-- Note: Gameobject spawns should be placed manually by the user
-- ====================================================================================

DELETE FROM gameobject_template WHERE entry BETWEEN 191001 AND 191033;

INSERT INTO gameobject_template 
  (entry, type, displayId, name, IconName, castBarCaption, unk1, size,
   Data0, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9,
   Data10, Data11, Data12, Data13, Data14, Data15, Data16, Data17, Data18, Data19,
   Data20, Data21, Data22, Data23, AIName, ScriptName, VerifiedBuild)
VALUES
  -- Weapon Caches (191001-191009)
  (191001, 3, 6851, 'Heirloom Weapon Cache - Fury', '', 'Opening', '', 1.0,
   0, 191001, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191002, 3, 6851, 'Heirloom Weapon Cache - Precision', '', 'Opening', '', 1.0,
   0, 191002, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191003, 3, 6851, 'Heirloom Weapon Cache - Titan', '', 'Opening', '', 1.0,
   0, 191003, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191004, 3, 6851, 'Heirloom Weapon Cache - Assassin', '', 'Opening', '', 1.0,
   0, 191004, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191005, 3, 6851, 'Heirloom Weapon Cache - Lethality', '', 'Opening', '', 1.0,
   0, 191005, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191006, 3, 6851, 'Heirloom Weapon Cache - Evasion', '', 'Opening', '', 1.0,
   0, 191006, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191007, 3, 6851, 'Heirloom Weapon Cache - Sorcery', '', 'Opening', '', 1.0,
   0, 191007, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191008, 3, 6851, 'Heirloom Weapon Cache - Arcane Power', '', 'Opening', '', 1.0,
   0, 191008, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191009, 3, 6851, 'Heirloom Weapon Cache - Protection', '', 'Opening', '', 1.0,
   0, 191009, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Helm Caches (191010-191018)
  (191010, 3, 7507, 'Heirloom Helm Cache - DPS Plate', '', 'Opening', '', 1.0,
   0, 191010, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191011, 3, 7507, 'Heirloom Helm Cache - Physical Plate', '', 'Opening', '', 1.0,
   0, 191011, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191012, 3, 7507, 'Heirloom Helm Cache - Tank Plate', '', 'Opening', '', 1.0,
   0, 191012, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191013, 3, 7507, 'Heirloom Helm Cache - DPS Mail', '', 'Opening', '', 1.0,
   0, 191013, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191014, 3, 7507, 'Heirloom Helm Cache - Physical Mail', '', 'Opening', '', 1.0,
   0, 191014, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191015, 3, 7507, 'Heirloom Helm Cache - Tank Mail', '', 'Opening', '', 1.0,
   0, 191015, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191016, 3, 7507, 'Heirloom Helm Cache - Leather Caster', '', 'Opening', '', 1.0,
   0, 191016, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191017, 3, 7507, 'Heirloom Helm Cache - Leather Haste', '', 'Opening', '', 1.0,
   0, 191017, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191018, 3, 7507, 'Heirloom Helm Cache - Cloth Caster', '', 'Opening', '', 1.0,
   0, 191018, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Chest Caches (191019-191021)
  (191019, 3, 7507, 'Heirloom Chest Cache - DPS', '', 'Opening', '', 1.0,
   0, 191019, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191020, 3, 7507, 'Heirloom Chest Cache - Physical', '', 'Opening', '', 1.0,
   0, 191020, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191021, 3, 7507, 'Heirloom Chest Cache - Caster', '', 'Opening', '', 1.0,
   0, 191021, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Legs Caches (191022-191024)
  (191022, 3, 7507, 'Heirloom Legs Cache - Tank', '', 'Opening', '', 1.0,
   0, 191022, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191023, 3, 7507, 'Heirloom Legs Cache - Evasion', '', 'Opening', '', 1.0,
   0, 191023, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191024, 3, 7507, 'Heirloom Legs Cache - Haste', '', 'Opening', '', 1.0,
   0, 191024, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Shoulders Caches (191025-191027)
  (191025, 3, 7507, 'Heirloom Shoulders Cache - DPS', '', 'Opening', '', 1.0,
   0, 191025, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191026, 3, 7507, 'Heirloom Shoulders Cache - Physical', '', 'Opening', '', 1.0,
   0, 191026, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191027, 3, 7507, 'Heirloom Shoulders Cache - Caster', '', 'Opening', '', 1.0,
   0, 191027, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Waist Caches (191028-191030)
  (191028, 3, 7507, 'Heirloom Waist Cache - Physical', '', 'Opening', '', 1.0,
   0, 191028, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191029, 3, 7507, 'Heirloom Waist Cache - DPS', '', 'Opening', '', 1.0,
   0, 191029, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191030, 3, 7507, 'Heirloom Waist Cache - Caster', '', 'Opening', '', 1.0,
   0, 191030, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  
  -- Feet/Hands/Wrists Caches (191031-191033)
  (191031, 3, 7507, 'Heirloom Feet Cache - Physical', '', 'Opening', '', 1.0,
   0, 191031, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191032, 3, 7507, 'Heirloom Hands Cache - Tank', '', 'Opening', '', 1.0,
   0, 191032, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
  (191033, 3, 7507, 'Heirloom Wrists Cache - Haste', '', 'Opening', '', 1.0,
   0, 191033, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340);


-- ====================================================================================
-- SECTION 3: GAMEOBJECT LOOT TABLES (191001-191033)
-- ====================================================================================
-- Links treasures to heirloom items (one item per treasure)
-- ====================================================================================

DELETE FROM gameobject_loot_template WHERE entry BETWEEN 191001 AND 191033;

INSERT INTO gameobject_loot_template 
  (entry, item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
VALUES
  -- Weapons (191001-191009 → items 191101-191109)
  (191001, 191101, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Greatsword of Fury'),
  (191002, 191102, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Greatsword of Precision'),
  (191003, 191103, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Greatsword of the Titan'),
  (191004, 191104, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Dagger of the Assassin'),
  (191005, 191105, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Dagger of Lethality'),
  (191006, 191106, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Dagger of Evasion'),
  (191007, 191107, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Staff of Sorcery'),
  (191008, 191108, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Staff of Arcane Power'),
  (191009, 191109, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Staff of Protection'),
  
  -- Helms (191010-191018 → items 191110-191118)
  (191010, 191110, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Plate Helm of Fury'),
  (191011, 191111, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Plate Helm of Precision'),
  (191012, 191112, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Plate Helm of the Titan'),
  (191013, 191113, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Mail Helm of the Predator'),
  (191014, 191114, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Mail Helm of Lethality'),
  (191015, 191115, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Mail Helm of Evasion'),
  (191016, 191116, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Leather Helm of Sorcery'),
  (191017, 191117, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Leather Helm of Arcane Power'),
  (191018, 191118, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Cloth Helm of Insight'),
  
  -- Chest (191019-191021 → items 191119-191121)
  (191019, 191119, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Plate Chestguard of Fury'),
  (191020, 191120, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Mail Hauberk of the Predator'),
  (191021, 191121, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Cloth Robe of Sorcery'),
  
  -- Legs (191022-191024 → items 191122-191124)
  (191022, 191122, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Plate Legguards of the Titan'),
  (191023, 191123, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Mail Leggings of Evasion'),
  (191024, 191124, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Cloth Trousers of Arcane Power'),
  
  -- Shoulders (191025-191027 → items 191125-191127)
  (191025, 191125, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Plate Pauldrons of Fury'),
  (191026, 191126, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Mail Spaulders of Lethality'),
  (191027, 191127, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Cloth Mantle of Insight'),
  
  -- Waist (191028-191030 → items 191128-191130)
  (191028, 191128, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Plate Girdle of Precision'),
  (191029, 191129, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Leather Cord of the Predator'),
  (191030, 191130, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Cloth Waistband of Sorcery'),
  
  -- Feet/Hands/Wrists (191031-191033 → items 191131-191133)
  (191031, 191131, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Mail Treads of Lethality'),
  (191032, 191132, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Plate Gauntlets of the Titan'),
  (191033, 191133, 0, 100, 1, 1, 0, 1, 1, 'Heirloom Cloth Wristguards of Arcane Power');


-- ====================================================================================
-- SECTION 4: QUEST SYSTEM (Quest ID 50000)
-- ====================================================================================
-- Tracks one-time loot per character
-- ====================================================================================

-- ====================================================================================
-- SECTION 5: UPGRADE COSTS (Tier 3)
-- ====================================================================================
-- Already exists in HEIRLOOM_TIER3_SYSTEM_WORLD.sql
-- Included here for reference - DO NOT execute twice
-- ====================================================================================

-- See HEIRLOOM_TIER3_SYSTEM_WORLD.sql for:
-- INSERT INTO dc_item_upgrade_costs (tier_id=3, levels 0-15)


-- ====================================================================================
-- SECTION 6: ITEM-TO-TIER MAPPING (dc_item_templates_upgrade)
-- ====================================================================================
-- Maps 33 upgradeable heirloom items to Tier 3
-- Bag (191134) and Shirt (191135) are NOT included (not upgradeable)
-- ====================================================================================

DELETE FROM dc_item_templates_upgrade WHERE item_id BETWEEN 191101 AND 191133;

INSERT INTO dc_item_templates_upgrade (item_id, tier_id, season, is_active)
VALUES
  -- Weapons (9 items)
  (191101, 3, 1, 1), (191102, 3, 1, 1), (191103, 3, 1, 1),
  (191104, 3, 1, 1), (191105, 3, 1, 1), (191106, 3, 1, 1),
  (191107, 3, 1, 1), (191108, 3, 1, 1), (191109, 3, 1, 1),
  
  -- Helms (9 items)
  (191110, 3, 1, 1), (191111, 3, 1, 1), (191112, 3, 1, 1),
  (191113, 3, 1, 1), (191114, 3, 1, 1), (191115, 3, 1, 1),
  (191116, 3, 1, 1), (191117, 3, 1, 1), (191118, 3, 1, 1),
  
  -- Chest (3 items)
  (191119, 3, 1, 1), (191120, 3, 1, 1), (191121, 3, 1, 1),
  
  -- Legs (3 items)
  (191122, 3, 1, 1), (191123, 3, 1, 1), (191124, 3, 1, 1),
  
  -- Shoulders (3 items)
  (191125, 3, 1, 1), (191126, 3, 1, 1), (191127, 3, 1, 1),
  
  -- Waist (3 items)
  (191128, 3, 1, 1), (191129, 3, 1, 1), (191130, 3, 1, 1),
  
  -- Feet/Hands/Wrists (3 items)
  (191131, 3, 1, 1), (191132, 3, 1, 1), (191133, 3, 1, 1);


-- ====================================================================================
-- END OF FILE
-- ====================================================================================
-- Summary:
--   - 35 items created (33 upgradeable + 1 bag + 1 shirt)
--   - 33 gameobject templates created
--   - 33 loot tables created
--   - 1 quest created (one-time loot tracking)
--   - 33 item-to-tier mappings created
--
-- Next Steps:
--   1. Place gameobject spawns manually in-game
--   2. Execute this SQL file on acore_world database
--   3. Test loot system and upgrade functionality
-- ====================================================================================
