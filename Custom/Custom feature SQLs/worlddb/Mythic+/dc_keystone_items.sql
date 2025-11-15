/*
 * Mythic+ Keystone Item Templates
 * Quest items for each M+ difficulty level (M+2 through M+10)
 * Players receive these from the NPC vendor via gossip
 * Items are consumed when used on the Keystone Pedestal in dungeons
 * 
 * Entry IDs: 190001-190009
 * M+2 = 190001, M+3 = 190002, ..., M+10 = 190009
 */

-- ============================================================
-- ITEM TEMPLATES: Keystones (M+2 through M+10)
-- ============================================================

-- M+2 Keystone (Uncommon - Blue - 1)
DELETE FROM item_template WHERE entry = 190001;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild) 
VALUES (190001, 12, 0, -1, 'Mythic +2 Keystone', 32837, 1, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +2 dungeons', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+3 Keystone (Uncommon - Blue - 1)
DELETE FROM item_template WHERE entry = 190002;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190002, 12, 0, -1, 'Mythic +3 Keystone', 32837, 1, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +3 dungeons', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+4 Keystone (Uncommon - Blue - 1)
DELETE FROM item_template WHERE entry = 190003;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190003, 12, 0, -1, 'Mythic +4 Keystone', 32837, 1, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +4 dungeons', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+5 Keystone (Rare - Green - 2)
DELETE FROM item_template WHERE entry = 190004;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190004, 12, 0, -1, 'Mythic +5 Keystone', 32837, 2, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +5 dungeons (Rare)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+6 Keystone (Rare - Green - 2)
DELETE FROM item_template WHERE entry = 190005;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190005, 12, 0, -1, 'Mythic +6 Keystone', 32837, 2, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +6 dungeons (Rare)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+7 Keystone (Rare - Green - 2)
DELETE FROM item_template WHERE entry = 190006;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190006, 12, 0, -1, 'Mythic +7 Keystone', 32837, 2, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +7 dungeons (Rare)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+8 Keystone (Epic - Purple - 4)
DELETE FROM item_template WHERE entry = 190007;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190007, 12, 0, -1, 'Mythic +8 Keystone', 32837, 4, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +8 dungeons (Epic)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+9 Keystone (Epic - Purple - 4)
DELETE FROM item_template WHERE entry = 190008;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190008, 12, 0, -1, 'Mythic +9 Keystone', 32837, 4, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +9 dungeons (Epic)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+10 Keystone (Epic - Purple - 4)
DELETE FROM item_template WHERE entry = 190009;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190009, 12, 0, -1, 'Mythic +10 Keystone', 32837, 4, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +10 dungeons (Epic)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+11 Keystone (Epic - Purple - 4)
DELETE FROM item_template WHERE entry = 190010;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190010, 12, 0, -1, 'Mythic +11 Keystone', 32837, 4, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +11 dungeons (Epic)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+12 Keystone (Epic - Purple - 4)
DELETE FROM item_template WHERE entry = 190011;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190011, 12, 0, -1, 'Mythic +12 Keystone', 32837, 4, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +12 dungeons (Epic)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+13 Keystone (Epic - Purple - 4)
DELETE FROM item_template WHERE entry = 190012;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190012, 12, 0, -1, 'Mythic +13 Keystone', 32837, 4, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +13 dungeons (Epic)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+14 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 190013;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190013, 12, 0, -1, 'Mythic +14 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +14 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+15 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 190014;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190014, 12, 0, -1, 'Mythic +15 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +15 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+16 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 190015;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190015, 12, 0, -1, 'Mythic +16 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +16 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+17 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 190016;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190016, 12, 0, -1, 'Mythic +17 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +17 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+18 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 190017;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190017, 12, 0, -1, 'Mythic +18 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +18 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+19 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 190018;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190018, 12, 0, -1, 'Mythic +19 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +19 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+20 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 190019;
INSERT INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, 
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, 
    AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, 
    requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, 
    stackable, ContainerSlots, bonding, description, PageText, LanguageID, PageMaterial, startquest, 
    lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, 
    BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, 
    socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, 
    ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, 
    FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild)
VALUES (190019, 12, 0, -1, 'Mythic +20 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +20 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);
