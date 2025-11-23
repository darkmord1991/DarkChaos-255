/*
 * Mythic+ Keystone Item Templates
 * Quest items for each M+ difficulty level (M+2 through M+10)
 * Players receive these from the NPC vendor via gossip
 * Items are consumed when used on the Keystone Pedestal in dungeons
 * 
 * Entry IDs: 300313-300321
 * M+2 = 300313, M+3 = 300314, ..., M+10 = 300321
 */

-- ============================================================
-- ITEM TEMPLATES: Keystones (M+2 through M+10)
-- ============================================================

-- M+2 Keystone (Uncommon - Blue - 1)
DELETE FROM item_template WHERE entry = 300313;
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
VALUES (300313, 12, 0, -1, 'Mythic +2 Keystone', 32837, 1, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +2 dungeons', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+3 Keystone (Uncommon - Blue - 1)
DELETE FROM item_template WHERE entry = 300314;
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
VALUES (300314, 12, 0, -1, 'Mythic +3 Keystone', 32837, 1, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +3 dungeons', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+4 Keystone (Uncommon - Blue - 1)
DELETE FROM item_template WHERE entry = 300315;
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
VALUES (300315, 12, 0, -1, 'Mythic +4 Keystone', 32837, 1, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +4 dungeons', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+5 Keystone (Rare - Green - 2)
DELETE FROM item_template WHERE entry = 300316;
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
VALUES (300316, 12, 0, -1, 'Mythic +5 Keystone', 32837, 2, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +5 dungeons (Rare)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+6 Keystone (Rare - Green - 2)
DELETE FROM item_template WHERE entry = 300317;
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
VALUES (300317, 12, 0, -1, 'Mythic +6 Keystone', 32837, 2, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +6 dungeons (Rare)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+7 Keystone (Rare - Green - 2)
DELETE FROM item_template WHERE entry = 300318;
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
VALUES (300318, 12, 0, -1, 'Mythic +7 Keystone', 32837, 2, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +7 dungeons (Rare)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+8 Keystone (Epic - Purple - 4)
DELETE FROM item_template WHERE entry = 300319;
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
VALUES (300319, 12, 0, -1, 'Mythic +8 Keystone', 32837, 4, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +8 dungeons (Epic)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+9 Keystone (Epic - Purple - 4)
DELETE FROM item_template WHERE entry = 300320;
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
VALUES (300320, 12, 0, -1, 'Mythic +9 Keystone', 32837, 4, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +9 dungeons (Epic)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+10 Keystone (Epic - Purple - 4)
DELETE FROM item_template WHERE entry = 300321;
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
VALUES (300321, 12, 0, -1, 'Mythic +10 Keystone', 32837, 4, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +10 dungeons (Epic)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+11 Keystone (Epic - Purple - 4)
DELETE FROM item_template WHERE entry = 300322;
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
VALUES (300322, 12, 0, -1, 'Mythic +11 Keystone', 32837, 4, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +11 dungeons (Epic)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+12 Keystone (Epic - Purple - 4)
DELETE FROM item_template WHERE entry = 300323;
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
VALUES (300323, 12, 0, -1, 'Mythic +12 Keystone', 32837, 4, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +12 dungeons (Epic)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+13 Keystone (Epic - Purple - 4)
DELETE FROM item_template WHERE entry = 300324;
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
VALUES (300324, 12, 0, -1, 'Mythic +13 Keystone', 32837, 4, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +13 dungeons (Epic)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+14 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 300325;
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
VALUES (300325, 12, 0, -1, 'Mythic +14 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +14 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+15 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 300326;
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
VALUES (300326, 12, 0, -1, 'Mythic +15 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +15 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+16 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 300327;
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
VALUES (300327, 12, 0, -1, 'Mythic +16 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +16 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+17 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 300328;
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
VALUES (300328, 12, 0, -1, 'Mythic +17 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +17 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+18 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 300329;
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
VALUES (300329, 12, 0, -1, 'Mythic +18 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +18 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+19 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 300330;
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
VALUES (300330, 12, 0, -1, 'Mythic +19 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +19 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);

-- M+20 Keystone (Legendary - Orange - 5)
DELETE FROM item_template WHERE entry = 300331;
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
VALUES (300331, 12, 0, -1, 'Mythic +20 Keystone', 32837, 5, 4, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 0, 'Keystone for Mythic +20 dungeons (Legendary)', 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 604800, 0, 0, '', 0, 0, 0, 0, 0, 0);
