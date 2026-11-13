-- DarkChaos: map 751 quest rewards - gear rescaled to the 130-160 bands, consumables, gold
--
-- GEAR: every gear reward of the 751 quests sat at item level 0-50 (the Cata import shipped them as
-- statless placeholders: ItemLevel 0, RequiredLevel 1, no stats). This file rescales them with HyjalCata/309_'s
-- model so 751 continues 750's power curve:
--   item level  green 392/400/406/415/419/421/423 for the bands starting 130/134/138/142/145/148/152 (the
--               level the CoA worldforged gear of those bands sits at), +8 blue, +16 purple
--   RequiredLevel = band floor (as 309_)
--   stats       budget 0.00207 x ilvl^2.13 x slot weight x quality (0.85/1/1.15), spread over the item's
--               own positive stats in their proportions, no single stat above 40% (312_'s cap). Placeholders
--               take their stat mix from the real Cata item (nelt_world item-sparse 15595, mastery -> haste
--               or crit); items with no stat data anywhere get a mix by armor type / weapon family
--   armor/damage from the Cata curve DBCs (ItemArmorTotal/Quality/Shield, ArmorLocation, ItemDamage*), the
--               same maths as gen_zone_gear_armor_dmg.py
--   random properties and scaling stats cleared, prices x12, quest-reward placeholders become BoP
-- 343 Cata items that only these 751 quests use are rescaled IN PLACE (they already have Item.dbc
-- rows). 27 stock items are COPIED to 505000-505026 (dc_quest_reward_item), the stock originals are
-- untouched, and the 751 quests are switched to the copies.
-- 🔴 THE COPIES NEED Item.dbc ROWS BEFORE THIS FILE IS APPLIED (server and client) - without one the server
-- silently drops the item_template row and the quest reward points at nothing. Rows are in
-- Custom/CSV DBC/Item.csv. Grey/white gear is left as it is, like 309_.
--
-- SCOPE: the quests 234_ (750) / 71_ (751) scaled, the 46 from rev_1794308125336406000 and the 175 clones
-- from rev_1794309353491880400 (applied after both - this file sorts later). Every quest UPDATE re-checks at
-- apply time that no giver or turn-in of the quest spawns on a stock map (< 725, other than 37), so nothing
-- here can change a quest the old world uses. The swaps are kept in dc_quest_reward_swap (old_item ->
-- new_item) and dc_quest_reward_money, which double as the revert record.
--
-- GOLD: RewardMoney = band midpoint x 900 copper x the quest's XP-difficulty ratio from QuestXP.dbc
-- (0 / 0.1 / 0.25 / 0.5 / 0.75 / 1 / 1.25 / 1.5 / 2 for RewardXPDifficulty 0-8), i.e. a standard quest pays
-- about 7.7 gold at Darkshore, 10.8 at Hyjal and 13.9 in Eastern Plaguelands - stock WotLK pays ~7.4 gold at
-- 80. Never lowered, quests that cost money untouched.
-- CONSUMABLES: food / drink / healing / mana / healing+mana rewards become the DC band tier (245_):
-- Emberwood 80, Skyfire 95, Summit 110, Nordrassil 125 (the top tier, also used for 751). Quest tools,
-- elixirs, holiday items and care packages are not touched.

CREATE TABLE IF NOT EXISTS `dc_quest_reward_swap` (
    `map` SMALLINT UNSIGNED NOT NULL,
    `kind` CHAR(1) NOT NULL,
    `quest` INT UNSIGNED NOT NULL,
    `col` TINYINT UNSIGNED NOT NULL,
    `old_item` INT UNSIGNED NOT NULL,
    `new_item` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`quest`, `col`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dc_quest_reward_money` (
    `map` SMALLINT UNSIGNED NOT NULL,
    `quest` INT UNSIGNED NOT NULL,
    `money` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dc_quest_reward_item` (
    `src_entry` INT UNSIGNED NOT NULL,
    `clone_entry` INT UNSIGNED NOT NULL,
    `band_lo` SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (`src_entry`),
    UNIQUE KEY `clone_entry` (`clone_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELETE FROM `dc_quest_reward_item`;
INSERT INTO `dc_quest_reward_item` (`src_entry`, `clone_entry`, `band_lo`) VALUES
(3440, 505000, 130),
(3446, 505001, 130),
(13216, 505002, 152),
(13217, 505003, 152),
(13315, 505004, 152),
(15805, 505005, 148),
(15806, 505006, 148),
(15812, 505007, 148),
(15813, 505008, 148),
(16994, 505009, 152),
(16995, 505010, 152),
(17003, 505011, 152),
(17004, 505012, 152),
(18022, 505013, 152),
(20504, 505014, 148),
(20505, 505015, 148),
(22656, 505016, 152),
(22657, 505017, 152),
(22659, 505018, 152),
(22667, 505019, 152),
(22668, 505020, 152),
(22680, 505021, 152),
(22681, 505022, 152),
(22688, 505023, 152),
(22689, 505024, 152),
(22690, 505025, 152),
(25878, 505026, 138);

-- the copies: every column from the stock item, entry changed (item_template rows are never deleted)
REPLACE INTO `item_template` (
    `entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`, `Quality`, `Flags`, `FlagsExtra`,
    `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`, `AllowableClass`, `AllowableRace`, `ItemLevel`,
    `RequiredLevel`, `RequiredSkill`, `RequiredSkillRank`, `requiredspell`, `requiredhonorrank`, `RequiredCityRank`,
    `RequiredReputationFaction`, `RequiredReputationRank`, `maxcount`, `stackable`, `ContainerSlots`, `stat_type1`,
    `stat_value1`, `stat_type2`, `stat_value2`, `stat_type3`, `stat_value3`, `stat_type4`, `stat_value4`,
    `stat_type5`, `stat_value5`, `stat_type6`, `stat_value6`, `stat_type7`, `stat_value7`, `stat_type8`,
    `stat_value8`, `stat_type9`, `stat_value9`, `stat_type10`, `stat_value10`, `ScalingStatDistribution`,
    `ScalingStatValue`, `dmg_min1`, `dmg_max1`, `dmg_type1`, `dmg_min2`, `dmg_max2`, `dmg_type2`, `armor`,
    `holy_res`, `fire_res`, `nature_res`, `frost_res`, `shadow_res`, `arcane_res`, `delay`, `ammo_type`,
    `RangedModRange`, `spellid_1`, `spelltrigger_1`, `spellcharges_1`, `spellppmRate_1`, `spellcooldown_1`,
    `spellcategory_1`, `spellcategorycooldown_1`, `spellid_2`, `spelltrigger_2`, `spellcharges_2`, `spellppmRate_2`,
    `spellcooldown_2`, `spellcategory_2`, `spellcategorycooldown_2`, `spellid_3`, `spelltrigger_3`,
    `spellcharges_3`, `spellppmRate_3`, `spellcooldown_3`, `spellcategory_3`, `spellcategorycooldown_3`,
    `spellid_4`, `spelltrigger_4`, `spellcharges_4`, `spellppmRate_4`, `spellcooldown_4`, `spellcategory_4`,
    `spellcategorycooldown_4`, `spellid_5`, `spelltrigger_5`, `spellcharges_5`, `spellppmRate_5`, `spellcooldown_5`,
    `spellcategory_5`, `spellcategorycooldown_5`, `bonding`, `description`, `PageText`, `LanguageID`,
    `PageMaterial`, `startquest`, `lockid`, `Material`, `sheath`, `RandomProperty`, `RandomSuffix`, `block`,
    `itemset`, `MaxDurability`, `area`, `Map`, `BagFamily`, `TotemCategory`, `socketColor_1`, `socketContent_1`,
    `socketColor_2`, `socketContent_2`, `socketColor_3`, `socketContent_3`, `socketBonus`, `GemProperties`,
    `RequiredDisenchantSkill`, `ArmorDamageModifier`, `duration`, `ItemLimitCategory`, `HolidayId`, `ScriptName`,
    `DisenchantID`, `FoodType`, `minMoneyLoot`, `maxMoneyLoot`, `flagsCustom`, `VerifiedBuild`)
SELECT
    `m`.`clone_entry`, `t`.`class`, `t`.`subclass`, `t`.`SoundOverrideSubclass`, `t`.`name`, `t`.`displayid`,
    `t`.`Quality`, `t`.`Flags`, `t`.`FlagsExtra`, `t`.`BuyCount`, `t`.`BuyPrice`, `t`.`SellPrice`,
    `t`.`InventoryType`, `t`.`AllowableClass`, `t`.`AllowableRace`, `t`.`ItemLevel`, `t`.`RequiredLevel`,
    `t`.`RequiredSkill`, `t`.`RequiredSkillRank`, `t`.`requiredspell`, `t`.`requiredhonorrank`,
    `t`.`RequiredCityRank`, `t`.`RequiredReputationFaction`, `t`.`RequiredReputationRank`, `t`.`maxcount`,
    `t`.`stackable`, `t`.`ContainerSlots`, `t`.`stat_type1`, `t`.`stat_value1`, `t`.`stat_type2`, `t`.`stat_value2`,
    `t`.`stat_type3`, `t`.`stat_value3`, `t`.`stat_type4`, `t`.`stat_value4`, `t`.`stat_type5`, `t`.`stat_value5`,
    `t`.`stat_type6`, `t`.`stat_value6`, `t`.`stat_type7`, `t`.`stat_value7`, `t`.`stat_type8`, `t`.`stat_value8`,
    `t`.`stat_type9`, `t`.`stat_value9`, `t`.`stat_type10`, `t`.`stat_value10`, `t`.`ScalingStatDistribution`,
    `t`.`ScalingStatValue`, `t`.`dmg_min1`, `t`.`dmg_max1`, `t`.`dmg_type1`, `t`.`dmg_min2`, `t`.`dmg_max2`,
    `t`.`dmg_type2`, `t`.`armor`, `t`.`holy_res`, `t`.`fire_res`, `t`.`nature_res`, `t`.`frost_res`,
    `t`.`shadow_res`, `t`.`arcane_res`, `t`.`delay`, `t`.`ammo_type`, `t`.`RangedModRange`, `t`.`spellid_1`,
    `t`.`spelltrigger_1`, `t`.`spellcharges_1`, `t`.`spellppmRate_1`, `t`.`spellcooldown_1`, `t`.`spellcategory_1`,
    `t`.`spellcategorycooldown_1`, `t`.`spellid_2`, `t`.`spelltrigger_2`, `t`.`spellcharges_2`,
    `t`.`spellppmRate_2`, `t`.`spellcooldown_2`, `t`.`spellcategory_2`, `t`.`spellcategorycooldown_2`,
    `t`.`spellid_3`, `t`.`spelltrigger_3`, `t`.`spellcharges_3`, `t`.`spellppmRate_3`, `t`.`spellcooldown_3`,
    `t`.`spellcategory_3`, `t`.`spellcategorycooldown_3`, `t`.`spellid_4`, `t`.`spelltrigger_4`,
    `t`.`spellcharges_4`, `t`.`spellppmRate_4`, `t`.`spellcooldown_4`, `t`.`spellcategory_4`,
    `t`.`spellcategorycooldown_4`, `t`.`spellid_5`, `t`.`spelltrigger_5`, `t`.`spellcharges_5`,
    `t`.`spellppmRate_5`, `t`.`spellcooldown_5`, `t`.`spellcategory_5`, `t`.`spellcategorycooldown_5`,
    `t`.`bonding`, `t`.`description`, `t`.`PageText`, `t`.`LanguageID`, `t`.`PageMaterial`, `t`.`startquest`,
    `t`.`lockid`, `t`.`Material`, `t`.`sheath`, `t`.`RandomProperty`, `t`.`RandomSuffix`, `t`.`block`,
    `t`.`itemset`, `t`.`MaxDurability`, `t`.`area`, `t`.`Map`, `t`.`BagFamily`, `t`.`TotemCategory`,
    `t`.`socketColor_1`, `t`.`socketContent_1`, `t`.`socketColor_2`, `t`.`socketContent_2`, `t`.`socketColor_3`,
    `t`.`socketContent_3`, `t`.`socketBonus`, `t`.`GemProperties`, `t`.`RequiredDisenchantSkill`,
    `t`.`ArmorDamageModifier`, `t`.`duration`, `t`.`ItemLimitCategory`, `t`.`HolidayId`, `t`.`ScriptName`,
    `t`.`DisenchantID`, `t`.`FoodType`, `t`.`minMoneyLoot`, `t`.`maxMoneyLoot`, `t`.`flagsCustom`,
    `t`.`VerifiedBuild`
FROM `item_template` AS `t`
JOIN `dc_quest_reward_item` AS `m` ON `m`.`src_entry` = `t`.`entry`;

-- the rescale itself: absolute values, so re-running is harmless
-- 57166 Advanced Night Web Crossbow (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 176,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2018, `dmg_max1` = 2730, `delay` = 2800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 57166;
-- 57167 Night Web Gloves (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 176,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 937, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 57167;
-- 57168 Reaper's Buckler (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 176,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 12438, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 57168;
-- 57169 Darrington's Dirk (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 235,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 962, `dmg_max1` = 1301, `delay` = 1800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 57169;
-- 57170 Lilian's Staff (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 235,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 882, `dmg_max1` = 1193, `delay` = 3300, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 57170;
-- 57171 Executor's Breastplate (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 270,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 3773, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 57171;
-- 59158 Craig's Steel (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 36, `stat_value1` = 265,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 927, `dmg_max1` = 1254, `delay` = 1400, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59158;
-- 59159 Highland Mace (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 265,
    `stat_type2` = 7, `stat_value2` = 255, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2946, `dmg_max1` = 3986, `delay` = 3300, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59159;
-- 59160 Trelane's Leggings (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 305,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1475, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59160;
-- 59161 Belt of Refuge (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 199,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1203, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59161;
-- 59162 Lightstep Boots (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2774, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59162;
-- 59163 Craig's Steel (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 36, `stat_value1` = 265,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 927, `dmg_max1` = 1254, `delay` = 1400, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59163;
-- 59164 Grim Mace (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 265,
    `stat_type2` = 3, `stat_value2` = 265, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2946, `dmg_max1` = 3986, `delay` = 3300, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59164;
-- 59165 Genavie's Leggings (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 305,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1475, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59165;
-- 59166 Adulterous Belt (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 199,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1203, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59166;
-- 59167 Treads of Unforgotten Pain (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2774, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59167;
-- 59168 Stromgarde Surcoat (inplace, own stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 187, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 843, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 13836, `BuyPrice` = 55344
WHERE `entry` = 59168;
-- 59169 Stromgarde Leggings (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 254,
    `stat_type2` = 7, `stat_value2` = 254, `stat_type3` = 31, `stat_value3` = 254, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1871, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59169;
-- 59170 Stromgarde Bracers (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 199,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1766, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59170;
-- 59171 Bloodstone-Studded Cloak (inplace, own stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 843, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 12720, `BuyPrice` = 50880
WHERE `entry` = 59171;
-- 59172 Drakeskin Leggings (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 254,
    `stat_type2` = 7, `stat_value2` = 254, `stat_type3` = 31, `stat_value3` = 254, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1871, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59172;
-- 59173 Radiant Silver Armguards (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 199,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1766, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59173;
-- 59174 Dustfall Bracers (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 199,
    `stat_type2` = 32, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 738, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59174;
-- 59175 Sandals of Sorrow (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 32, `stat_value1` = 199,
    `stat_type2` = 5, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1470, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59175;
-- 59176 War Rider Belt (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 199,
    `stat_type2` = 3, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1203, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59176;
-- 59177 Captain Nials' Belt (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 32, `stat_value1` = 199,
    `stat_type2` = 4, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2270, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59177;
-- 59178 Ramshackle Bracers (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 32, `stat_value1` = 199,
    `stat_type2` = 5, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 738, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59178;
-- 59179 Extra Credit Boots (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 199,
    `stat_type2` = 32, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1470, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59179;
-- 59180 Lurking Belt (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1203, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59180;
-- 59181 Belt of Gutted Ruin (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 199,
    `stat_type2` = 32, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2270, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59181;
-- 59182 Syndicate Dagger (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 265,
    `stat_type2` = 7, `stat_value2` = 265, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 1192, `dmg_max1` = 1613, `delay` = 1800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59182;
-- 59183 Silenced Rifle (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2500, `dmg_max1` = 3382, `delay` = 2800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59183;
-- 59184 Demon-Trafficker's Belt (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 199,
    `stat_type2` = 5, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 948, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59184;
-- 59185 Vest of Dark Rumors (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 305,
    `stat_type2` = 5, `stat_value2` = 305, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2138, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59185;
-- 59186 Skullslasher (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 265,
    `stat_type2` = 7, `stat_value2` = 265, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 1192, `dmg_max1` = 1613, `delay` = 1800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59186;
-- 59187 Silent Huntress (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2500, `dmg_max1` = 3382, `delay` = 2800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59187;
-- 59188 Belt of Affront (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 199,
    `stat_type2` = 5, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 948, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59188;
-- 59189 Mistspray Vest (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 305,
    `stat_type2` = 7, `stat_value2` = 305, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2138, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59189;
-- 59190 Slippers of Sorrowful Tidings (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 166, `stat_type3` = 32, `stat_value3` = 166, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1159, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59190;
-- 59191 Yellow Ribbon Armbands (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 935, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59191;
-- 59192 Griefstricken Gloves (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 199,
    `stat_type2` = 32, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1336, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59192;
-- 59193 Heartsick Breastplate (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 254,
    `stat_type2` = 7, `stat_value2` = 254, `stat_type3` = 31, `stat_value3` = 254, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 4035, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59193;
-- 59194 Sandals of Satisfaction (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 166, `stat_type3` = 32, `stat_value3` = 166, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1159, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59194;
-- 59195 Bracers of Sensations (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 935, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59195;
-- 59196 Alina's Gloves (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 199,
    `stat_type2` = 32, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1336, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59196;
-- 59197 Lordaeron-Made Breastplate (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 254,
    `stat_type2` = 7, `stat_value2` = 254, `stat_type3` = 31, `stat_value3` = 254, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 4035, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59197;
-- 59198 Draxlegauge Ring (inplace, own stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 16188, `BuyPrice` = 64752
WHERE `entry` = 59198;
-- 59199 Bottom Waders (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 31, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1470, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59199;
-- 59200 Decalcified Elven Spear (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 221,
    `stat_type2` = 7, `stat_value2` = 221, `stat_type3` = 32, `stat_value3` = 221, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 2678, `dmg_max1` = 3624, `delay` = 3000, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500,
    `BuyPrice` = 166000
WHERE `entry` = 59200;
-- 59201 Hammerfall Band (inplace, own stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 16188, `BuyPrice` = 64752
WHERE `entry` = 59201;
-- 59202 Hammerfall Ring (inplace, own stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 16188, `BuyPrice` = 64752
WHERE `entry` = 59202;
-- 59203 Hammerfall Gloves (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1336, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59203;
-- 59204 Hammerfall Mace (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 265,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 1722, `dmg_max1` = 2329, `delay` = 2600, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59204;
-- 59205 Folly's Spar (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 221,
    `stat_type2` = 7, `stat_value2` = 221, `stat_type3` = 32, `stat_value3` = 221, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1093, `dmg_max1` = 1478, `delay` = 3300, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500,
    `BuyPrice` = 166000
WHERE `entry` = 59205;
-- 59206 Steelgut Vest (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 305,
    `stat_type2` = 7, `stat_value2` = 305, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2138, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59206;
-- 59207 Maiden's Tattered Sail (inplace, own stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 199,
    `stat_type2` = 4, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 843, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 13788, `BuyPrice` = 55152
WHERE `entry` = 59207;
-- 59208 Wrap of Open Menace (inplace, own stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 243,
    `stat_type2` = 3, `stat_value2` = 243, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 877, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 16608, `BuyPrice` = 66432
WHERE `entry` = 59208;
-- 59209 Eldritch Gloves (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 243,
    `stat_type2` = 5, `stat_value2` = 243, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1096, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 84600, `BuyPrice` = 338400
WHERE `entry` = 59209;
-- 59210 Earthbound Mantle (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 325,
    `stat_type2` = 5, `stat_value2` = 325, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1659, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 84600, `BuyPrice` = 338400
WHERE `entry` = 59210;
-- 59211 Shackling Gloves (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 243,
    `stat_type2` = 7, `stat_value2` = 243, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2582, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 84600, `BuyPrice` = 338400
WHERE `entry` = 59211;
-- 59212 O'Breen's Dress Robes (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 254,
    `stat_type2` = 7, `stat_value2` = 254, `stat_type3` = 31, `stat_value3` = 254, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1686, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59212;
-- 59213 Faldir's Leggings (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 32, `stat_value1` = 305,
    `stat_type2` = 7, `stat_value2` = 293, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1871, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59213;
-- 59214 Armguards of the Good Captain (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 199,
    `stat_type2` = 7, `stat_value2` = 199, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 935, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59214;
-- 59215 Legguards of the Promising Hero (inplace, cata stats, band 142)
UPDATE `item_template` SET
    `ItemLevel` = 415, `RequiredLevel` = 142, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 305,
    `stat_type2` = 7, `stat_value2` = 293, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 3531, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41500, `BuyPrice` = 166000
WHERE `entry` = 59215;
-- 59235 Razorbeak Amulet (inplace, own stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 203,
    `stat_type2` = 3, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 21540, `BuyPrice` = 86160
WHERE `entry` = 59235;
-- 59236 Gryphon-Down Scarf (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 311,
    `stat_type2` = 7, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1398, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59236;
-- 59237 Gryphon Master's Belt (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 203,
    `stat_type2` = 6, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1223, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59237;
-- 59238 Talon Axe (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 270,
    `stat_type2` = 31, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1787, `dmg_max1` = 2418, `delay` = 2600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900,
    `BuyPrice` = 167600
WHERE `entry` = 59238;
-- 59239 Wand of Oomph (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 203,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2095, `dmg_max1` = 2835, `delay` = 1600, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59239;
-- 59240 Blastbrew Hat (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 311,
    `stat_type2` = 3, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1767, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59240;
-- 59241 Direglob-Slimed Belt (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2297, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59241;
-- 59242 Ironsight Crossbow (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2595, `dmg_max1` = 3511, `delay` = 2800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59242;
-- 59243 Theresa's Bracers (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 203,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 753, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59243;
-- 59244 Stormfeather Boots (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 32, `stat_value1` = 203,
    `stat_type2` = 5, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1495, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59244;
-- 59245 Head Kickers (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2807, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59245;
-- 59246 Blood Drinker Staff (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 270,
    `stat_type2` = 32, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1134, `dmg_max1` = 1534, `delay` = 3300, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900,
    `BuyPrice` = 167600
WHERE `entry` = 59246;
-- 59247 Soul Eater Shoulderguard (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 270,
    `stat_type2` = 7, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1631, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59247;
-- 59248 Steelwing Pendant (inplace, own stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 26064, `BuyPrice` = 104256
WHERE `entry` = 59248;
-- 59249 Vile Branch (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 270,
    `stat_type2` = 3, `stat_value2` = 237, `stat_type3` = 31, `stat_value3` = 135, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 3058, `dmg_max1` = 4137, `delay` = 3300, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900,
    `BuyPrice` = 167600
WHERE `entry` = 59249;
-- 59250 Necklace of Evil Faces (inplace, own stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 26064, `BuyPrice` = 104256
WHERE `entry` = 59250;
-- 59251 Jintha'Alor Bracers (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1786, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59251;
-- 59252 Sandals of Tainted Blood (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 203,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1183, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59252;
-- 59253 Sandrene's Invisible Vest (inplace, own stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 311,
    `stat_type2` = 7, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2174, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 35160, `BuyPrice` = 140640
WHERE `entry` = 59253;
-- 59254 Spider Venom Leggings (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 311,
    `stat_type2` = 3, `stat_value2` = 234, `stat_type3` = 31, `stat_value3` = 195, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1903, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59254;
-- 59255 Dark Vessel Breastplate (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 311,
    `stat_type2` = 4, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 4083, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59255;
-- 59256 Unkeeper Blade (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 270,
    `stat_type2` = 7, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 1237, `dmg_max1` = 1674, `delay` = 1800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59256;
-- 59257 Leggings of Secret Rituals (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 311,
    `stat_type2` = 7, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1505, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59257;
-- 59258 Gloves of Strange Words (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1359, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59258;
-- 59259 Tablet-Bearer's Pauldrons (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 270,
    `stat_type2` = 4, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 3062, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59259;
-- 59260 Shadraspawn Mantle (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 270,
    `stat_type2` = 5, `stat_value2` = 226, `stat_type3` = 31, `stat_value3` = 135, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1290, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59260;
-- 59262 Cloudcaller Leggings (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 311,
    `stat_type2` = 7, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1903, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59262;
-- 59263 Belt of the Scattering Wind (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1223, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59263;
-- 59264 Legguards of Caution (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 311,
    `stat_type2` = 4, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 3573, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59264;
-- 59265 Gown of the Last Priestess (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 260,
    `stat_type2` = 31, `stat_value2` = 260, `stat_type3` = 32, `stat_value3` = 260, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1720, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59265;
-- 59266 Gwenyth's Bracers (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 6, `stat_value1` = 203,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 951, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59266;
-- 59267 Gloves of Fanatical Zealotry (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 203,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1359, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59267;
-- 59268 Greathammer of the Hinterlands (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 270,
    `stat_type2` = 7, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 3058, `dmg_max1` = 4137, `delay` = 3300, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59268;
-- 59269 Veil of Aerie Peak (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 427, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 318,
    `stat_type2` = 7, `stat_value2` = 318, `stat_type3` = 32, `stat_value3` = 318, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1454, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85400, `BuyPrice` = 341600
WHERE `entry` = 59269;
-- 59270 Headguard of Aerie Peak (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 427, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 381,
    `stat_type2` = 7, `stat_value2` = 381, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1827, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85400, `BuyPrice` = 341600
WHERE `entry` = 59270;
-- 59271 Headcover of Aerie Peak (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 427, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 381,
    `stat_type2` = 3, `stat_value2` = 318, `stat_type3` = 32, `stat_value3` = 223, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1827, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85400, `BuyPrice` = 341600
WHERE `entry` = 59271;
-- 59272 Helm of Aerie Peak (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 427, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 381,
    `stat_type2` = 4, `stat_value2` = 381, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 3396, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85400, `BuyPrice` = 341600
WHERE `entry` = 59272;
-- 59273 Luring Necklace (inplace, own stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 21540, `BuyPrice` = 86160
WHERE `entry` = 59273;
-- 59274 Katoom's Mask (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 311,
    `stat_type2` = 7, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1398, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59274;
-- 59275 Stomachache Belt (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 203,
    `stat_type2` = 6, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1223, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59275;
-- 59276 Snapjaw Bracers (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1786, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59276;
-- 59277 Research Assistant's Wand (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 203,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2095, `dmg_max1` = 2835, `delay` = 1600, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59277;
-- 59278 Slime Hunter Headguard (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 311,
    `stat_type2` = 3, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1767, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59278;
-- 59279 Skulk Rock Belt (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2297, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59279;
-- 59280 Voice Stealer (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2595, `dmg_max1` = 3511, `delay` = 2800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59280;
-- 59281 Elder's Wristwraps (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 203,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 753, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59281;
-- 59282 Encroaching Treads (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 203,
    `stat_type2` = 32, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1495, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59282;
-- 59283 Revantusk Boots (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2807, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59283;
-- 59284 Unkeeper Blade (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 270,
    `stat_type2` = 7, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 1237, `dmg_max1` = 1674, `delay` = 1800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59284;
-- 59285 Leggings of Secret Rituals (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 311,
    `stat_type2` = 7, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1505, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59285;
-- 59286 Gloves of Strange Words (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 203,
    `stat_type2` = 5, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1359, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59286;
-- 59287 Tablet-Bearer's Pauldrons (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 270,
    `stat_type2` = 7, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 3062, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59287;
-- 59288 Vile Branch (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 226,
    `stat_type2` = 7, `stat_value2` = 226, `stat_type3` = 31, `stat_value3` = 226, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 3058, `dmg_max1` = 4137, `delay` = 3300, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900,
    `BuyPrice` = 167600
WHERE `entry` = 59288;
-- 59289 Necklace of Evil Faces (inplace, own stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 26064, `BuyPrice` = 104256
WHERE `entry` = 59289;
-- 59290 Jintha'Alor Axe (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 270,
    `stat_type2` = 31, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1787, `dmg_max1` = 2418, `delay` = 2600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900,
    `BuyPrice` = 167600
WHERE `entry` = 59290;
-- 59291 Blood Drinker Staff (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 270,
    `stat_type2` = 32, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1134, `dmg_max1` = 1534, `delay` = 3300, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900,
    `BuyPrice` = 167600
WHERE `entry` = 59291;
-- 59292 Soul Eater Shoulderguard (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 270,
    `stat_type2` = 3, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1631, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59292;
-- 59293 Torntusk Pendant (inplace, own stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 203,
    `stat_type2` = 4, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 26064, `BuyPrice` = 104256
WHERE `entry` = 59293;
-- 59294 Sandals of Tainted Blood (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 203,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1183, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59294;
-- 59295 Sandrene's Invisible Vest (inplace, own stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 311,
    `stat_type2` = 5, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2174, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 36372, `BuyPrice` = 145488
WHERE `entry` = 59295;
-- 59296 Spider Venom Leggings (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 311,
    `stat_type2` = 3, `stat_value2` = 273, `stat_type3` = 31, `stat_value3` = 156, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1903, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59296;
-- 59297 Dark Vessel Breastplate (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 311,
    `stat_type2` = 4, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 4083, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59297;
-- 59298 Surlis' Mantle (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 226,
    `stat_type2` = 7, `stat_value2` = 226, `stat_type3` = 31, `stat_value3` = 226, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1290, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59298;
-- 59299 Apothecary Leggings (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 311,
    `stat_type2` = 7, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1903, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59299;
-- 59300 Shadraspawn Belt (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 203,
    `stat_type2` = 3, `stat_value2` = 203, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1223, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59300;
-- 59301 Legguards of Caution (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 311,
    `stat_type2` = 7, `stat_value2` = 311, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 3573, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59301;
-- 59302 Gown of the Last Priestess (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 260,
    `stat_type2` = 31, `stat_value2` = 260, `stat_type3` = 32, `stat_value3` = 260, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1720, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59302;
-- 59303 Gwenyth's Bracers (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 6, `stat_value1` = 203,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 951, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59303;
-- 59304 Gloves of Fanatical Zealotry (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 203,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1359, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59304;
-- 59305 Greataxe of the Hinterlands (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 419, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 270,
    `stat_type2` = 4, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 3058, `dmg_max1` = 4137, `delay` = 3300, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 41900, `BuyPrice` = 167600
WHERE `entry` = 59305;
-- 59306 Darkcleric's Veil (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 427, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 318,
    `stat_type2` = 7, `stat_value2` = 318, `stat_type3` = 32, `stat_value3` = 318, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1454, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85400, `BuyPrice` = 341600
WHERE `entry` = 59306;
-- 59307 Virulent Headguard (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 427, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 318,
    `stat_type2` = 7, `stat_value2` = 318, `stat_type3` = 32, `stat_value3` = 318, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1827, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85400, `BuyPrice` = 341600
WHERE `entry` = 59307;
-- 59308 Venomous Headcover (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 427, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 318,
    `stat_type2` = 7, `stat_value2` = 318, `stat_type3` = 32, `stat_value3` = 318, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1827, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85400, `BuyPrice` = 341600
WHERE `entry` = 59308;
-- 59309 Poisoner's Helm (inplace, cata stats, band 145)
UPDATE `item_template` SET
    `ItemLevel` = 427, `RequiredLevel` = 145, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 318,
    `stat_type2` = 7, `stat_value2` = 318, `stat_type3` = 32, `stat_value3` = 318, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 3396, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85400, `BuyPrice` = 341600
WHERE `entry` = 59309;
-- 62140 Dried-Up Bracers (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 760, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62140;
-- 62141 Belt of the Laconic (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 36,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1233, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62141;
-- 62142 Behemoth Boots (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 3, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1508, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62142;
-- 62143 Gut Opener Gloves (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 12, `stat_value3` = 118, `stat_type4` = 13,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2567, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62143;
-- 62144 Bracers of Favorable Chance (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 760, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62144;
-- 62145 Belt of the Blathering Fool (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 36,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1233, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62145;
-- 62146 Behemoth Boots (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 3, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1508, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62146;
-- 62147 Gut Opener Gloves (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 12, `stat_value3` = 118, `stat_type4` = 13,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2567, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62147;
-- 62148 Gandling's Gloves (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1086, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62148;
-- 62149 Burden of Time (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 219,
    `stat_type2` = 7, `stat_value2` = 192, `stat_type3` = 5, `stat_value3` = 157, `stat_type4` = 36,
    `stat_value4` = 117, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1645, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62149;
-- 62150 Elimination Bracers (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 3, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 959, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62150;
-- 62151 Belt of Lingering Corruption (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 12, `stat_value3` = 118, `stat_type4` = 13,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2310, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62151;
-- 62152 Gandling's Gloves (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1086, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62152;
-- 62153 Burden of Time (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 219,
    `stat_type2` = 7, `stat_value2` = 192, `stat_type3` = 5, `stat_value3` = 157, `stat_type4` = 36,
    `stat_value4` = 117, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1645, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62153;
-- 62154 Elimination Bracers (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 3, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 959, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62154;
-- 62155 Belt of Lingering Corruption (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 12, `stat_value3` = 118, `stat_type4` = 13,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2310, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62155;
-- 62156 Grant's Signet (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 164,
    `stat_type2` = 4, `stat_value2` = 144, `stat_type3` = 38, `stat_value3` = 118, `stat_type4` = 31,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62156;
-- 62157 Farmer's Vest (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 252,
    `stat_type2` = 7, `stat_value2` = 220, `stat_type3` = 5, `stat_value3` = 181, `stat_type4` = 36,
    `stat_value4` = 133, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2193, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62157;
-- 62158 Homestead Helm (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 252,
    `stat_type2` = 7, `stat_value2` = 220, `stat_type3` = 32, `stat_value3` = 181, `stat_type4` = 36,
    `stat_value4` = 133, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 3337, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62158;
-- 62159 Bear Hunter's Rifle (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 31, `stat_value3` = 118, `stat_type4` = 36,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 2738, `dmg_max1` = 3704, `delay` = 2900, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100,
    `BuyPrice` = 168400
WHERE `entry` = 62159;
-- 62160 Vandis' Band (inplace, own stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 176,
    `stat_type2` = 32, `stat_value2` = 147, `stat_type3` = 5, `stat_value3` = 110, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 34692, `BuyPrice` = 138768
WHERE `entry` = 62160;
-- 62161 Bullmastiff Vest (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 270,
    `stat_type2` = 31, `stat_value2` = 225, `stat_type3` = 3, `stat_value3` = 161, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1936, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62161;
-- 62162 Territorial Helm (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 270,
    `stat_type2` = 36, `stat_value2` = 225, `stat_type3` = 5, `stat_value3` = 161, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 3066, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62162;
-- 62163 Fox Hunter's Rifle (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 176,
    `stat_type2` = 4, `stat_value2` = 176, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2018, `dmg_max1` = 2730, `delay` = 2800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62163;
-- 62168 Glimmering Ring (inplace, own stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 176,
    `stat_type2` = 3, `stat_value2` = 176, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 34692, `BuyPrice` = 138768
WHERE `entry` = 62168;
-- 62169 Dithering Belt (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 176,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 843, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62169;
-- 62170 Plague Cauldron Lid (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 176,
    `stat_type2` = 5, `stat_value2` = 176, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 12438, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62170;
-- 62171 Cloak of the Salted Earth (inplace, own stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 176,
    `stat_type2` = 36, `stat_value2` = 147, `stat_type3` = 4, `stat_value3` = 110, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 749, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 28836, `BuyPrice` = 115344
WHERE `entry` = 62171;
-- 62172 Forest Green Cloak (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 869, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62172;
-- 62173 Boots of the Flowering Earth (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 36,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1508, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62173;
-- 62174 Bracers of the Returning Wild (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 32, `stat_value3` = 118, `stat_type4` = 36,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1797, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62174;
-- 62175 Lumberjack's Hatchet (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 219,
    `stat_type2` = 7, `stat_value2` = 192, `stat_type3` = 37, `stat_value3` = 157, `stat_type4` = 36,
    `stat_value4` = 117, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1821, `dmg_max1` = 2463, `delay` = 2600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100,
    `BuyPrice` = 168400
WHERE `entry` = 62175;
-- 62176 Redpine Cloak (inplace, cata stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 205,
    `stat_type2` = 7, `stat_value2` = 205, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 869, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 408636, `BuyPrice` = 1634544
WHERE `entry` = 62176;
-- 62177 Kelly's Booties (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 12, `stat_value3` = 118, `stat_type4` = 13,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2823, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62177;
-- 62181 Zombie Shotgun (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 31, `stat_value3` = 118, `stat_type4` = 36,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 2738, `dmg_max1` = 3704, `delay` = 2900, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100,
    `BuyPrice` = 168400
WHERE `entry` = 62181;
-- 62182 Training Leggings (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 252,
    `stat_type2` = 7, `stat_value2` = 220, `stat_type3` = 5, `stat_value3` = 181, `stat_type4` = 32,
    `stat_value4` = 133, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1520, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62182;
-- 62183 Gory Gloves (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 36,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1371, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62183;
-- 62184 Abominable Shoulderguards (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 219,
    `stat_type2` = 7, `stat_value2` = 192, `stat_type3` = 32, `stat_value3` = 157, `stat_type4` = 36,
    `stat_value4` = 117, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 3080, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62184;
-- 62185 Zombie Shotgun (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 31, `stat_value3` = 118, `stat_type4` = 36,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 2738, `dmg_max1` = 3704, `delay` = 2900, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100,
    `BuyPrice` = 168400
WHERE `entry` = 62185;
-- 62186 Ravensun Britches (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 252,
    `stat_type2` = 7, `stat_value2` = 220, `stat_type3` = 5, `stat_value3` = 181, `stat_type4` = 32,
    `stat_value4` = 133, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1520, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62186;
-- 62187 Charming Gloves (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 36,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1371, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62187;
-- 62188 Abominable Shoulderguards (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 219,
    `stat_type2` = 7, `stat_value2` = 192, `stat_type3` = 32, `stat_value3` = 157, `stat_type4` = 36,
    `stat_value4` = 117, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 3080, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62188;
-- 62192 Zen'Kiki's Thanks (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 164,
    `stat_type2` = 4, `stat_value2` = 144, `stat_type3` = 38, `stat_value3` = 118, `stat_type4` = 31,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62192;
-- 62193 Leggings of the Slippery Shifter (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 252,
    `stat_type2` = 7, `stat_value2` = 220, `stat_type3` = 5, `stat_value3` = 181, `stat_type4` = 36,
    `stat_value4` = 133, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1919, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62193;
-- 62194 Breastplate of the Patient (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 252,
    `stat_type2` = 7, `stat_value2` = 220, `stat_type3` = 32, `stat_value3` = 181, `stat_type4` = 36,
    `stat_value4` = 133, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 4107, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62194;
-- 62195 Footfalls of Memories (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 143, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 6,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1194, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62195;
-- 62196 Gloria's Work Vest (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 252,
    `stat_type2` = 7, `stat_value2` = 220, `stat_type3` = 3, `stat_value3` = 181, `stat_type4` = 32,
    `stat_value4` = 133, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2193, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62196;
-- 62197 Gahrron's Shoulderguard (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 218,
    `stat_type2` = 7, `stat_value2` = 191, `stat_type3` = 5, `stat_value3` = 158, `stat_type4` = 36,
    `stat_value4` = 117, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1645, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62197;
-- 62198 Andrea's Locket (inplace, cata stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 205,
    `stat_type2` = 7, `stat_value2` = 205, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 16248, `BuyPrice` = 64992
WHERE `entry` = 62198;
-- 62199 Malicia's Scepter (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 219,
    `stat_type2` = 7, `stat_value2` = 192, `stat_type3` = 37, `stat_value3` = 157, `stat_type4` = 36,
    `stat_value4` = 117, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1821, `dmg_max1` = 2463, `delay` = 2600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100,
    `BuyPrice` = 168400
WHERE `entry` = 62199;
-- 62200 Field Agent's Belt (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 3, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1233, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62200;
-- 62201 Kaartish's Sword (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 219,
    `stat_type2` = 7, `stat_value2` = 192, `stat_type3` = 37, `stat_value3` = 157, `stat_type4` = 36,
    `stat_value4` = 117, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1821, `dmg_max1` = 2463, `delay` = 2600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100,
    `BuyPrice` = 168400
WHERE `entry` = 62201;
-- 62202 Bracers of Envy (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 760, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62202;
-- 62203 Belt of the Unafraid (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 36,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1233, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62203;
-- 62204 Gloves of the Able (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 3, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1371, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62204;
-- 62205 Defender's Band (inplace, cata stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 13, `stat_value1` = 205,
    `stat_type2` = 4, `stat_value2` = 147, `stat_type3` = 7, `stat_value3` = 147, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 25344, `BuyPrice` = 101376
WHERE `entry` = 62205;
-- 62206 Bracers of Envy (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 760, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62206;
-- 62207 Belt of the Unafraid (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 5, `stat_value3` = 118, `stat_type4` = 36,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1233, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62207;
-- 62208 Gloves of the Able (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 3, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1371, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62208;
-- 62209 Deathguard Band (inplace, cata stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 13, `stat_value1` = 205,
    `stat_type2` = 4, `stat_value2` = 147, `stat_type3` = 7, `stat_value3` = 147, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 25728, `BuyPrice` = 102912
WHERE `entry` = 62209;
-- 62210 Pack Leader's Band (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 164,
    `stat_type2` = 4, `stat_value2` = 144, `stat_type3` = 38, `stat_value3` = 118, `stat_type4` = 31,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62210;
-- 62211 Shoulderwraps of the Enthralled (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 219,
    `stat_type2` = 7, `stat_value2` = 192, `stat_type3` = 5, `stat_value3` = 157, `stat_type4` = 6,
    `stat_value4` = 117, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1303, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62211;
-- 62212 Quelling Bracers (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 3, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 959, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62212;
-- 62213 Minuteman Pike (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 219,
    `stat_type2` = 7, `stat_value2` = 192, `stat_type3` = 37, `stat_value3` = 157, `stat_type4` = 36,
    `stat_value4` = 117, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 3399, `dmg_max1` = 4598, `delay` = 3600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100,
    `BuyPrice` = 168400
WHERE `entry` = 62213;
-- 62214 Ring of Aces (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 164,
    `stat_type2` = 3, `stat_value2` = 144, `stat_type3` = 38, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62214;
-- 62215 Shoulderwraps of the Enthralled (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 219,
    `stat_type2` = 7, `stat_value2` = 192, `stat_type3` = 5, `stat_value3` = 157, `stat_type4` = 6,
    `stat_value4` = 117, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1303, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62215;
-- 62216 Lurid Bracers (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 164,
    `stat_type2` = 7, `stat_value2` = 144, `stat_type3` = 3, `stat_value3` = 118, `stat_type4` = 32,
    `stat_value4` = 87, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 959, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100, `BuyPrice` = 168400
WHERE `entry` = 62216;
-- 62217 Minuteman Pike (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 219,
    `stat_type2` = 7, `stat_value2` = 192, `stat_type3` = 37, `stat_value3` = 157, `stat_type4` = 36,
    `stat_value4` = 117, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 3399, `dmg_max1` = 4598, `delay` = 3600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42100,
    `BuyPrice` = 168400
WHERE `entry` = 62217;
-- 62218 Chillwind Dagger (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 268,
    `stat_type2` = 7, `stat_value2` = 235, `stat_type3` = 38, `stat_value3` = 192, `stat_type4` = 32,
    `stat_value4` = 142, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1358, `dmg_max1` = 1837, `delay` = 1800, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85800,
    `BuyPrice` = 343200
WHERE `entry` = 62218;
-- 62219 Chillwind Staff (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 268,
    `stat_type2` = 7, `stat_value2` = 235, `stat_type3` = 5, `stat_value3` = 192, `stat_type4` = 36,
    `stat_value4` = 142, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1358, `dmg_max1` = 1837, `delay` = 3600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85800,
    `BuyPrice` = 343200
WHERE `entry` = 62219;
-- 62220 Chillwind Tunic (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 308,
    `stat_type2` = 7, `stat_value2` = 269, `stat_type3` = 5, `stat_value3` = 222, `stat_type4` = 32,
    `stat_value4` = 164, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1807, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85800, `BuyPrice` = 343200
WHERE `entry` = 62220;
-- 62221 Chillwind Legguards (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 308,
    `stat_type2` = 7, `stat_value2` = 269, `stat_type3` = 5, `stat_value3` = 222, `stat_type4` = 36,
    `stat_value4` = 164, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1984, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85800, `BuyPrice` = 343200
WHERE `entry` = 62221;
-- 62222 Chillwind Pauldrons (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 268,
    `stat_type2` = 7, `stat_value2` = 235, `stat_type3` = 32, `stat_value3` = 192, `stat_type4` = 36,
    `stat_value4` = 142, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 3153, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85800, `BuyPrice` = 343200
WHERE `entry` = 62222;
-- 62223 Dagger of Andorhal (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 268,
    `stat_type2` = 7, `stat_value2` = 235, `stat_type3` = 31, `stat_value3` = 192, `stat_type4` = 36,
    `stat_value4` = 142, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1358, `dmg_max1` = 1837, `delay` = 1800, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85800,
    `BuyPrice` = 343200
WHERE `entry` = 62223;
-- 62224 Staff of Andorhal (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 268,
    `stat_type2` = 7, `stat_value2` = 235, `stat_type3` = 5, `stat_value3` = 192, `stat_type4` = 32,
    `stat_value4` = 142, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1358, `dmg_max1` = 1837, `delay` = 3600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85800,
    `BuyPrice` = 343200
WHERE `entry` = 62224;
-- 62225 Andorhal Tunic (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 308,
    `stat_type2` = 7, `stat_value2` = 269, `stat_type3` = 5, `stat_value3` = 222, `stat_type4` = 6,
    `stat_value4` = 164, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1807, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85800, `BuyPrice` = 343200
WHERE `entry` = 62225;
-- 62226 Andorhal Legguards (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 308,
    `stat_type2` = 7, `stat_value2` = 269, `stat_type3` = 3, `stat_value3` = 222, `stat_type4` = 32,
    `stat_value4` = 164, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1984, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85800, `BuyPrice` = 343200
WHERE `entry` = 62226;
-- 62227 Pauldrons of Andorhal (inplace, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 268,
    `stat_type2` = 7, `stat_value2` = 235, `stat_type3` = 12, `stat_value3` = 192, `stat_type4` = 13,
    `stat_value4` = 142, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 3153, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 85800, `BuyPrice` = 343200
WHERE `entry` = 62227;
-- 62837 Nubish Cloak (inplace, own stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 184,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 781, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 1164, `BuyPrice` = 4656
WHERE `entry` = 62837;
-- 62838 Nub's Wand (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 184,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 1755, `dmg_max1` = 2375, `delay` = 1600, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62838;
-- 62839 Nubly Bracers (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 184,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1690, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62839;
-- 62840 Sober Pup Wristbands (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 184,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 684, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62840;
-- 62841 Bloodfang Vest (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 282,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2005, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62841;
-- 62842 Steel Thunder Belt (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 184,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2173, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62842;
-- 62843 Bush Chicken Remote Injector (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 184,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2174, `dmg_max1` = 2941, `delay` = 2800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62843;
-- 62844 Suppository Preventors (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 282,
    `stat_type2` = 7, `stat_value2` = 282, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1367, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62844;
-- 62845 Chicken Stuffers (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 184,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2414, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62845;
-- 62846 Ale-Soaked Robes (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 282,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1562, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62846;
-- 62847 Sea Dog Belt (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 184,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1128, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62847;
-- 62848 Treads of the Sepulcher (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 184,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2655, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62848;
-- 62849 Skitterweb Glovelettes (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 184,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 977, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62849;
-- 62850 Drunken Style Bracers (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 184,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 877, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62850;
-- 62851 Rear Guard Britches (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 282,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 3380, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62851;
-- 62852 Sabots of Red Waters (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 184,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1378, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62852;
-- 62853 Blood Offering Platter (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 184,
    `stat_type2` = 7, `stat_value2` = 184, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 12577, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62853;
-- 62860 Watched Watcher's Slippers (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 176,
    `stat_type2` = 7, `stat_value2` = 176, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1030, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62860;
-- 62861 Wolfsbane Vest (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 270,
    `stat_type2` = 7, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1936, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62861;
-- 62862 Belmont's Bracers (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 176,
    `stat_type2` = 7, `stat_value2` = 176, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1651, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62862;
-- 62863 Wild Howl Dagger (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 235,
    `stat_type2` = 7, `stat_value2` = 235, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 748, `dmg_max1` = 1012, `delay` = 1400, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62863;
-- 62864 Bracers of the Final Transmission (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 176,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 656, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62864;
-- 62865 Emberstone Breastplate (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 270,
    `stat_type2` = 4, `stat_value2` = 270, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 3773, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62865;
-- 62866 Cromush's Cloak (inplace, own stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 176,
    `stat_type2` = 7, `stat_value2` = 176, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 749, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 2532, `BuyPrice` = 10128
WHERE `entry` = 62866;
-- 62867 Belt of the Second Head (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 176,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 843, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62867;
-- 62868 Korok's Ring (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 176,
    `stat_type2` = 7, `stat_value2` = 176, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2122, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62868;
-- 62872 Cloak of Secret Purpose (inplace, own stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 176,
    `stat_type2` = 7, `stat_value2` = 176, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 749, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 2976, `BuyPrice` = 11904
WHERE `entry` = 62872;
-- 62873 Godfrey's Belt (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 176,
    `stat_type2` = 7, `stat_value2` = 176, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1089, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62873;
-- 62874 Treads of the True Plan (inplace, cata stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 176,
    `stat_type2` = 7, `stat_value2` = 176, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2594, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 39200, `BuyPrice` = 156800
WHERE `entry` = 62874;
-- 62875 Betrayal's Sting (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 184,
    `stat_type2` = 7, `stat_value2` = 184, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2174, `dmg_max1` = 2941, `delay` = 2800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62875;
-- 62876 Relios's Mace (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 245,
    `stat_type2` = 5, `stat_value2` = 204, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 461, `dmg_max1` = 623, `delay` = 1600, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62876;
-- 62877 Forsaken Ball (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 184,
    `stat_type2` = 7, `stat_value2` = 184, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62877;
-- 62878 Codex Breaker (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 245,
    `stat_type2` = 4, `stat_value2` = 245, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2562, `dmg_max1` = 3466, `delay` = 3300, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62878;
-- 62879 Psychopathic Hatchet (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 204,
    `stat_type2` = 7, `stat_value2` = 204, `stat_type3` = 31, `stat_value3` = 204, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1497, `dmg_max1` = 2025, `delay` = 2600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000,
    `BuyPrice` = 160000
WHERE `entry` = 62879;
-- 62880 Axe of Practical Vengeance (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 245,
    `stat_type2` = 7, `stat_value2` = 245, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2562, `dmg_max1` = 3466, `delay` = 3300, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62880;
-- 62881 Dawnweaver's Dagger (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 204,
    `stat_type2` = 7, `stat_value2` = 204, `stat_type3` = 32, `stat_value3` = 204, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 403, `dmg_max1` = 545, `delay` = 1400, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000,
    `BuyPrice` = 160000
WHERE `entry` = 62881;
-- 62882 Edge of Unlifted Burdens (inplace, cata stats, band 134)
UPDATE `item_template` SET
    `ItemLevel` = 400, `RequiredLevel` = 134, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 245,
    `stat_type2` = 7, `stat_value2` = 245, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 1497, `dmg_max1` = 2025, `delay` = 2600, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40000, `BuyPrice` = 160000
WHERE `entry` = 62882;
-- 62935 Flower Picker's Gloves (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 5, `stat_value3` = 119, `stat_type4` = 6,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1096, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62935;
-- 62936 Treads of Banshee Bells (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 3, `stat_value3` = 119, `stat_type4` = 32,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1520, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62936;
-- 62937 Thondroril River Boots (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 5, `stat_value3` = 119, `stat_type4` = 32,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2094, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62937;
-- 62938 Giddy's Old Gloves (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 32, `stat_value3` = 119, `stat_type4` = 36,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2582, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62938;
-- 62939 Caravan Sash (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 5, `stat_value3` = 119, `stat_type4` = 6,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 987, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62939;
-- 62940 Belt of Appeasement (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 3, `stat_value3` = 119, `stat_type4` = 32,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1244, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62940;
-- 62941 Plaguehound Armbands (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 5, `stat_value3` = 119, `stat_type4` = 36,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 967, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62941;
-- 62942 Gentling Breastplate (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 255,
    `stat_type2` = 7, `stat_value2` = 222, `stat_type3` = 3, `stat_value3` = 183, `stat_type4` = 31,
    `stat_value4` = 135, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 3046, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62942;
-- 62943 Helm of Thoughtful Gifts (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 255,
    `stat_type2` = 7, `stat_value2` = 222, `stat_type3` = 12, `stat_value3` = 183, `stat_type4` = 13,
    `stat_value4` = 135, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 3356, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62943;
-- 62944 Slippers of the Lonely Road (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 5, `stat_value3` = 119, `stat_type4` = 32,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1206, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62944;
-- 62945 Plaguebat Vest (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 255,
    `stat_type2` = 7, `stat_value2` = 222, `stat_type3` = 5, `stat_value3` = 183, `stat_type4` = 36,
    `stat_value4` = 135, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2211, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62945;
-- 62946 Crown Guard Armbands (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 3, `stat_value3` = 119, `stat_type4` = 31,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1333, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62946;
-- 62947 Treads of Youth (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 5, `stat_value3` = 119, `stat_type4` = 32,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2094, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62947;
-- 62972 Infectis Incher Leggings (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 255,
    `stat_type2` = 7, `stat_value2` = 222, `stat_type3` = 5, `stat_value3` = 183, `stat_type4` = 32,
    `stat_value4` = 135, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1535, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62972;
-- 62973 Infectis Puffer Gloves (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 5, `stat_value3` = 119, `stat_type4` = 36,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1382, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62973;
-- 62974 Infectis Scuttler Helm (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 255,
    `stat_type2` = 7, `stat_value2` = 222, `stat_type3` = 32, `stat_value3` = 183, `stat_type4` = 36,
    `stat_value4` = 135, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 3356, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62974;
-- 62985 Corpulent Shoulderpads (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 221,
    `stat_type2` = 7, `stat_value2` = 193, `stat_type3` = 5, `stat_value3` = 159, `stat_type4` = 6,
    `stat_value4` = 118, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1316, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62985;
-- 62986 Borelgore's Skin (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 255,
    `stat_type2` = 7, `stat_value2` = 222, `stat_type3` = 3, `stat_value3` = 183, `stat_type4` = 32,
    `stat_value4` = 135, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1935, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62986;
-- 62987 Eastwall Gauntlets (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 12, `stat_value3` = 119, `stat_type4` = 13,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2582, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62987;
-- 62989 Monnions of Final Rest (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 221,
    `stat_type2` = 7, `stat_value2` = 193, `stat_type3` = 5, `stat_value3` = 159, `stat_type4` = 36,
    `stat_value4` = 118, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1659, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62989;
-- 62990 Bat Claw Legguards (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 255,
    `stat_type2` = 7, `stat_value2` = 222, `stat_type3` = 3, `stat_value3` = 183, `stat_type4` = 31,
    `stat_value4` = 135, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2665, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62990;
-- 62992 Pendant of the Ill-Advised (inplace, cata stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 207,
    `stat_type2` = 31, `stat_value2` = 162, `stat_type3` = 5, `stat_value3` = 130, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 18984, `BuyPrice` = 75936
WHERE `entry` = 62992;
-- 62993 Belt of Delay (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 145, `stat_type3` = 5, `stat_value3` = 119, `stat_type4` = 36,
    `stat_value4` = 89, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1244, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62993;
-- 62994 Rash Gloves (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 145, `stat_type3` = 3, `stat_value3` = 119, `stat_type4` = 31,
    `stat_value4` = 89, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1904, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62994;
-- 62995 Underlord's Mandible (inplace, cata stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 207,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 38400, `BuyPrice` = 153600
WHERE `entry` = 62995;
-- 62999 Corpseburner's Mantle (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 221,
    `stat_type2` = 7, `stat_value2` = 193, `stat_type3` = 5, `stat_value3` = 159, `stat_type4` = 6,
    `stat_value4` = 118, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1316, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 62999;
-- 63000 Duskwing Boots (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 3, `stat_value3` = 119, `stat_type4` = 32,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1520, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 63000;
-- 63001 Duskwing Handwraps (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 5, `stat_value3` = 119, `stat_type4` = 36,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1382, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 63001;
-- 63007 Plaguewood Mace (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 221,
    `stat_type2` = 7, `stat_value2` = 193, `stat_type3` = 37, `stat_value3` = 159, `stat_type4` = 36,
    `stat_value4` = 118, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1855, `dmg_max1` = 2509, `delay` = 2600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300,
    `BuyPrice` = 169200
WHERE `entry` = 63007;
-- 63008 Judkins' Staff (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 221,
    `stat_type2` = 7, `stat_value2` = 193, `stat_type3` = 5, `stat_value3` = 159, `stat_type4` = 32,
    `stat_value4` = 118, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1284, `dmg_max1` = 1737, `delay` = 3600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300,
    `BuyPrice` = 169200
WHERE `entry` = 63008;
-- 63009 Rotberry Waistband (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 5, `stat_value3` = 119, `stat_type4` = 32,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1713, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 63009;
-- 63010 Flesh Giant Toe-Ring (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 32, `stat_value3` = 119, `stat_type4` = 36,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1807, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 63010;
-- 63011 Stinking Skull Mace (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 221,
    `stat_type2` = 7, `stat_value2` = 193, `stat_type3` = 37, `stat_value3` = 159, `stat_type4` = 36,
    `stat_value4` = 118, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1855, `dmg_max1` = 2509, `delay` = 2600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300,
    `BuyPrice` = 169200
WHERE `entry` = 63011;
-- 63013 Collector's Belt (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 5, `stat_value3` = 119, `stat_type4` = 32,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1713, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 63013;
-- 63014 Cloak of Hoarding (inplace, cata stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 207,
    `stat_type2` = 13, `stat_value2` = 207, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 877, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 1437780, `BuyPrice` = 5751120
WHERE `entry` = 63014;
-- 63015 Overload Robes (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 255,
    `stat_type2` = 7, `stat_value2` = 222, `stat_type3` = 5, `stat_value3` = 183, `stat_type4` = 6,
    `stat_value4` = 135, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1754, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 63015;
-- 63016 Corpsebeast Armbands (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 166,
    `stat_type2` = 7, `stat_value2` = 146, `stat_type3` = 3, `stat_value3` = 119, `stat_type4` = 32,
    `stat_value4` = 88, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 967, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 63016;
-- 63017 Legwraps of the Slain (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 255,
    `stat_type2` = 7, `stat_value2` = 222, `stat_type3` = 5, `stat_value3` = 183, `stat_type4` = 32,
    `stat_value4` = 135, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2665, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 42300, `BuyPrice` = 169200
WHERE `entry` = 63017;
-- 63018 Tarenar's Token (inplace, cata stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 431, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 253,
    `stat_type2` = 3, `stat_value2` = 181, `stat_type3` = 32, `stat_value3` = 181, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 38100, `BuyPrice` = 152400
WHERE `entry` = 63018;
-- 63019 Fiona's Armbands (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 431, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 178, `stat_type3` = 5, `stat_value3` = 146, `stat_type4` = 6,
    `stat_value4` = 107, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 798, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 86200, `BuyPrice` = 344800
WHERE `entry` = 63019;
-- 63020 Belt of the Gentle Lady (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 431, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 38, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 178, `stat_type3` = 3, `stat_value3` = 146, `stat_type4` = 32,
    `stat_value4` = 107, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1286, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 86200, `BuyPrice` = 344800
WHERE `entry` = 63020;
-- 63021 Gloves of Journey's End (inplace, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 431, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 45, `stat_value1` = 203,
    `stat_type2` = 7, `stat_value2` = 178, `stat_type3` = 5, `stat_value3` = 146, `stat_type4` = 32,
    `stat_value4` = 107, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1957, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 86200, `BuyPrice` = 344800
WHERE `entry` = 63021;
-- 63022 Gidwin's Medallion (inplace, cata stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 431, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 212,
    `stat_type2` = 7, `stat_value2` = 212, `stat_type3` = 31, `stat_value3` = 212, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 27048, `BuyPrice` = 108192
WHERE `entry` = 63022;
-- 65666 Botanist's Britches (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 291,
    `stat_type2` = 6, `stat_value2` = 273, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1800, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65666;
-- 65668 Officer's Armbands (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 189,
    `stat_type2` = 7, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 705, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65668;
-- 65669 Keyton's Sash (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 189,
    `stat_type2` = 5, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 906, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65669;
-- 65670 Spider-Handler's Mantle (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 253,
    `stat_type2` = 6, `stat_value2` = 253, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1208, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65670;
-- 65671 Cue Cue Gloves (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 189,
    `stat_type2` = 7, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1286, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65671;
-- 65672 Crossbow of the Twice-Slain (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 158,
    `stat_type2` = 7, `stat_value2` = 158, `stat_type3` = 31, `stat_value3` = 158, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 2299, `dmg_max1` = 3110, `delay` = 2800, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600,
    `BuyPrice` = 162400
WHERE `entry` = 65672;
-- 65676 Helcular's Other Rod (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 253,
    `stat_type2` = 5, `stat_value2` = 173, `stat_type3` = 32, `stat_value3` = 173, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1005, `dmg_max1` = 1359, `delay` = 3300, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600,
    `BuyPrice` = 162400
WHERE `entry` = 65676;
-- 65677 Preemptive Staff (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 253,
    `stat_type2` = 3, `stat_value2` = 173, `stat_type3` = 31, `stat_value3` = 173, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 2709, `dmg_max1` = 3665, `delay` = 3300, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600,
    `BuyPrice` = 162400
WHERE `entry` = 65677;
-- 65679 Hinott's Outer Robe (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 291,
    `stat_type2` = 5, `stat_value2` = 199, `stat_type3` = 32, `stat_value3` = 199, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1611, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65679;
-- 65680 Belt of the Hero (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 232,
    `stat_type2` = 5, `stat_value2` = 166, `stat_type3` = 32, `stat_value3` = 166, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 944, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 82800, `BuyPrice` = 331200
WHERE `entry` = 65680;
-- 65681 Stagwich Slicer (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 253,
    `stat_type2` = 7, `stat_value2` = 253, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2709, `dmg_max1` = 3665, `delay` = 3300, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65681;
-- 65682 Bel'varil's Armbands (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 189,
    `stat_type2` = 5, `stat_value2` = 136, `stat_type3` = 6, `stat_value3` = 136, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 705, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65682;
-- 65683 Sofera's Belt (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 189,
    `stat_type2` = 5, `stat_value2` = 178, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1157, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65683;
-- 65685 Broken Fingers of Hillsbrad (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 232,
    `stat_type2` = 32, `stat_value2` = 194, `stat_type3` = 3, `stat_value3` = 116, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1331, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 82800, `BuyPrice` = 331200
WHERE `entry` = 65685;
-- 65686 Mantle of Haunting (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 253,
    `stat_type2` = 32, `stat_value2` = 211, `stat_type3` = 5, `stat_value3` = 141, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1208, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65686;
-- 65687 Axe of the Judgment Day (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 310,
    `stat_type2` = 4, `stat_value2` = 233, `stat_type3` = 31, `stat_value3` = 233, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 1706, `dmg_max1` = 2308, `delay` = 2600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 82800,
    `BuyPrice` = 331200
WHERE `entry` = 65687;
-- 65688 Yetimus Maximus (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 310,
    `stat_type2` = 4, `stat_value2` = 222, `stat_type3` = 32, `stat_value3` = 222, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 2919, `dmg_max1` = 3949, `delay` = 3300, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 82800,
    `BuyPrice` = 331200
WHERE `entry` = 65688;
-- 65689 Brazie's Plant Light (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 189,
    `stat_type2` = 7, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 1856, `dmg_max1` = 2511, `delay` = 1600, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65689;
-- 65690 Slaver's Leggings (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 291,
    `stat_type2` = 7, `stat_value2` = 273, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1800, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65690;
-- 65691 Floppy Shoulderguards (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 253,
    `stat_type2` = 7, `stat_value2` = 253, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1543, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65691;
-- 65692 Bear Hide Vest (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 291,
    `stat_type2` = 3, `stat_value2` = 273, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2057, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65692;
-- 65693 Quest Giver's Pauldrons (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 253,
    `stat_type2` = 7, `stat_value2` = 253, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2948, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65693;
-- 65694 Clerk Whitesteed's Cloak (inplace, own stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 189,
    `stat_type2` = 7, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 806, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 6084, `BuyPrice` = 24336
WHERE `entry` = 65694;
-- 65698 Daggerspine Dagger (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 253,
    `stat_type2` = 31, `stat_value2` = 253, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 852, `dmg_max1` = 1153, `delay` = 1400, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600,
    `BuyPrice` = 162400
WHERE `entry` = 65698;
-- 65700 Chet's Slimy Bracers (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 189,
    `stat_type2` = 32, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 900, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65700;
-- 65701 Gloves of the Hero (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 232,
    `stat_type2` = 5, `stat_value2` = 166, `stat_type3` = 32, `stat_value3` = 166, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1331, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 82800, `BuyPrice` = 331200
WHERE `entry` = 65701;
-- 65702 Supple Yeti Leggings (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 280,
    `stat_type2` = 3, `stat_value2` = 224, `stat_type3` = 32, `stat_value3` = 224, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1800, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65702;
-- 65703 Gavin's Pauldrons (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 253,
    `stat_type2` = 4, `stat_value2` = 190, `stat_type3` = 32, `stat_value3` = 190, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2948, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65703;
-- 65705 Pocket-Nuke Belt (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 232,
    `stat_type2` = 4, `stat_value2` = 155, `stat_type3` = 32, `stat_value3` = 155, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2263, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 82800, `BuyPrice` = 331200
WHERE `entry` = 65705;
-- 65706 Mr. Hider's Bracers (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 189,
    `stat_type2` = 3, `stat_value2` = 136, `stat_type3` = 31, `stat_value3` = 136, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 900, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65706;
-- 65707 Discontinuer's Hammer (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 310,
    `stat_type2` = 5, `stat_value2` = 233, `stat_type3` = 6, `stat_value3` = 233, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 525, `dmg_max1` = 710, `delay` = 1600, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 82800,
    `BuyPrice` = 331200
WHERE `entry` = 65707;
-- 65708 Tarren Orb (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 224,
    `stat_type2` = 5, `stat_value2` = 179, `stat_type3` = 32, `stat_value3` = 179, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 82800, `BuyPrice` = 331200
WHERE `entry` = 65708;
-- 65709 Binding Plates (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 189,
    `stat_type2` = 7, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2211, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65709;
-- 65710 Creeping Boots (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 189,
    `stat_type2` = 7, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 2702, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65710;
-- 65711 Portable Lap Desk (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 189,
    `stat_type2` = 7, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 12684, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65711;
-- 65712 Citizen Wilkes' Ring (inplace, own stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 189,
    `stat_type2` = 7, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 7140, `BuyPrice` = 28560
WHERE `entry` = 65712;
-- 65716 Daggerspine Ball (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 189,
    `stat_type2` = 5, `stat_value2` = 136, `stat_type3` = 31, `stat_value3` = 136, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65716;
-- 65718 Lethality Leggings (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 291,
    `stat_type2` = 31, `stat_value2` = 291, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 3439, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65718;
-- 65719 Spaulders of the Hero (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 310,
    `stat_type2` = 3, `stat_value2` = 222, `stat_type3` = 31, `stat_value3` = 222, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1597, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 82800, `BuyPrice` = 331200
WHERE `entry` = 65719;
-- 65720 Tell-Tale Bracers (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 189,
    `stat_type2` = 7, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1720, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65720;
-- 65721 Corrahn's Cloak (inplace, own stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 189,
    `stat_type2` = 7, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 806, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 8292, `BuyPrice` = 33168
WHERE `entry` = 65721;
-- 65723 Cloak of Treason (inplace, own stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 232,
    `stat_type2` = 5, `stat_value2` = 159, `stat_type3` = 32, `stat_value3` = 159, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 839, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 10296, `BuyPrice` = 41184
WHERE `entry` = 65723;
-- 65724 Grasps of the Unyielding (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 189,
    `stat_type2` = 4, `stat_value2` = 142, `stat_type3` = 31, `stat_value3` = 142, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2457, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 40600, `BuyPrice` = 162400
WHERE `entry` = 65724;
-- 65725 D-1000 Ring (inplace, own stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 224,
    `stat_type2` = 3, `stat_value2` = 179, `stat_type3` = 31, `stat_value3` = 179, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 14208, `BuyPrice` = 56832
WHERE `entry` = 65725;
-- 65726 Shield of Uncurbed Appetite (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 224,
    `stat_type2` = 5, `stat_value2` = 179, `stat_type3` = 32, `stat_value3` = 179, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 12829, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 82800, `BuyPrice` = 331200
WHERE `entry` = 65726;
-- 65727 Band of the Eastern Strand (inplace, own stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 189,
    `stat_type2` = 31, `stat_value2` = 189, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 8208, `BuyPrice` = 32832
WHERE `entry` = 65727;
-- 65728 Boots of the Hero (inplace, cata stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 414, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 194,
    `stat_type2` = 7, `stat_value2` = 194, `stat_type3` = 31, `stat_value3` = 194, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2766, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 82800, `BuyPrice` = 331200
WHERE `entry` = 65728;
-- 505000 Bonecracker (copy, own stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 235,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2306, `dmg_max1` = 3120, `delay` = 3200, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 7680, `BuyPrice` = 30720
WHERE `entry` = 505000;
-- 505001 Darkwood Staff (copy, own stats, band 130)
UPDATE `item_template` SET
    `ItemLevel` = 392, `RequiredLevel` = 130, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 235,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 2306, `dmg_max1` = 3120, `delay` = 3200, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 7104, `BuyPrice` = 28416
WHERE `entry` = 505001;
-- 505002 Crown of the Penitent (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 317,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1425, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 153540, `BuyPrice` = 614160
WHERE `entry` = 505002;
-- 505003 Band of the Penitent (copy, cata stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 32, `stat_value1` = 207,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 105768, `BuyPrice` = 423072
WHERE `entry` = 505003;
-- 505004 Testament of Hope (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 6, `stat_value1` = 207,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 136752, `BuyPrice` = 547008
WHERE `entry` = 505004;
-- 505005 Penelope's Rose (copy, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 216,
    `stat_type2` = 6, `stat_value2` = 216, `stat_type3` = 7, `stat_value3` = 196, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 175944, `BuyPrice` = 703776
WHERE `entry` = 505005;
-- 505006 Mirah's Song (copy, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 335,
    `stat_type2` = 4, `stat_value2` = 335, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 1358, `dmg_max1` = 1837, `delay` = 1800, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 594168, `BuyPrice` = 2376672
WHERE `entry` = 505006;
-- 505007 Orchid Amice (copy, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 273,
    `stat_type2` = 7, `stat_value2` = 124, `stat_type3` = 6, `stat_value3` = 93, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1303, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 120912, `BuyPrice` = 483648
WHERE `entry` = 505007;
-- 505008 Gold Link Belt (copy, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 421, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 205,
    `stat_type2` = 5, `stat_value2` = 205, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1702, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 121356, `BuyPrice` = 485424
WHERE `entry` = 505008;
-- 505009 Duskwing Gloves (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 207,
    `stat_type2` = 7, `stat_value2` = 190, `stat_type3` = 6, `stat_value3` = 86, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1382, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 124416, `BuyPrice` = 497664
WHERE `entry` = 505009;
-- 505010 Duskwing Mantle (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 276,
    `stat_type2` = 7, `stat_value2` = 180, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 1659, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 187308, `BuyPrice` = 749232
WHERE `entry` = 505010;
-- 505011 Skullstone Hammer (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 276,
    `stat_type2` = 7, `stat_value2` = 173, `stat_type3` = 6, `stat_value3` = 130, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 963, `dmg_max1` = 1303, `delay` = 2700, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 521268,
    `BuyPrice` = 2085072
WHERE `entry` = 505011;
-- 505012 Sarah's Guide (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 423, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 276,
    `stat_type2` = 5, `stat_value2` = 276, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 892, `dmg_max1` = 1206, `delay` = 2500, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 653916, `BuyPrice` = 2615664
WHERE `entry` = 505012;
-- 505013 Royal Seal of Alexis (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 431, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 227,
    `stat_type2` = 7, `stat_value2` = 227, `stat_type3` = 6, `stat_value3` = 181, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 128508, `BuyPrice` = 514032
WHERE `entry` = 505013;
-- 505014 Lightforged Blade (copy, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 335,
    `stat_type2` = 7, `stat_value2` = 335, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 3357, `dmg_max1` = 4541, `delay` = 3300, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 454476, `BuyPrice` = 1817904
WHERE `entry` = 505014;
-- 505015 Chivalrous Signet (copy, own stats, band 148)
UPDATE `item_template` SET
    `ItemLevel` = 429, `RequiredLevel` = 148, `bonding` = 1, `stat_type1` = 4, `stat_value1` = 209,
    `stat_type2` = 7, `stat_value2` = 209, `stat_type3` = 5, `stat_value3` = 209, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 185484, `BuyPrice` = 741936
WHERE `entry` = 505015;
-- 505016 The Purifier (copy, cata stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 439, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 32, `stat_value1` = 303,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 3350, `dmg_max1` = 4532, `delay` = 3000, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 595344, `BuyPrice` = 2381376
WHERE `entry` = 505016;
-- 505017 Amulet of the Dawn (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 439, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 303,
    `stat_type2` = 7, `stat_value2` = 303, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 403500, `BuyPrice` = 1614000
WHERE `entry` = 505017;
-- 505018 Medallion of the Dawn (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 439, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 303,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 403500, `BuyPrice` = 1614000
WHERE `entry` = 505018;
-- 505019 Bracers of Hope (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 439, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 6, `stat_value1` = 276,
    `stat_type2` = 5, `stat_value2` = 253, `stat_type3` = 7, `stat_value3` = 230, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 474, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 153468, `BuyPrice` = 613872
WHERE `entry` = 505019;
-- 505020 Bracers of Subterfuge (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 439, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 303,
    `stat_type2` = 7, `stat_value2` = 246, `stat_type3` = 4, `stat_value3` = 205, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 810, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 192576, `BuyPrice` = 770304
WHERE `entry` = 505020;
-- 505021 Band of Resolution (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 431, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 253,
    `stat_type2` = 0, `stat_value2` = 0, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 128508, `BuyPrice` = 514032
WHERE `entry` = 505021;
-- 505022 Band of Piety (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 431, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 7, `stat_value1` = 253,
    `stat_type2` = 5, `stat_value2` = 253, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 128508, `BuyPrice` = 514032
WHERE `entry` = 505022;
-- 505023 Verimonde's Last Resort (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 431, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 338,
    `stat_type2` = 7, `stat_value2` = 338, `stat_type3` = 0, `stat_value3` = 0, `stat_type4` = 0, `stat_value4` = 0,
    `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0, `stat_value7` = 0,
    `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0, `stat_value10` = 0,
    `armor` = 0, `dmg_min1` = 538, `dmg_max1` = 728, `delay` = 1400, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 626124, `BuyPrice` = 2504496
WHERE `entry` = 505023;
-- 505024 Sanctified Leather Helm (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 431, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 5, `stat_value1` = 389,
    `stat_type2` = 7, `stat_value2` = 303, `stat_type3` = 6, `stat_value3` = 259, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 1858, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 235668, `BuyPrice` = 942672
WHERE `entry` = 505024;
-- 505025 Leggings of the Plague Hunter (copy, own stats, band 152)
UPDATE `item_template` SET
    `ItemLevel` = 431, `RequiredLevel` = 152, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 389,
    `stat_type2` = 7, `stat_value2` = 338, `stat_type3` = 5, `stat_value3` = 212, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 2740, `dmg_min1` = 0, `dmg_max1` = 0, `RandomProperty` = 0, `RandomSuffix` = 0,
    `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 378504, `BuyPrice` = 1514016
WHERE `entry` = 505025;
-- 505026 Dusksteel Throwing Knife (copy, generic stats, band 138)
UPDATE `item_template` SET
    `ItemLevel` = 406, `RequiredLevel` = 138, `bonding` = 1, `stat_type1` = 3, `stat_value1` = 253,
    `stat_type2` = 7, `stat_value2` = 190, `stat_type3` = 32, `stat_value3` = 127, `stat_type4` = 0,
    `stat_value4` = 0, `stat_type5` = 0, `stat_value5` = 0, `stat_type6` = 0, `stat_value6` = 0, `stat_type7` = 0,
    `stat_value7` = 0, `stat_type8` = 0, `stat_value8` = 0, `stat_type9` = 0, `stat_value9` = 0, `stat_type10` = 0,
    `stat_value10` = 0, `armor` = 0, `dmg_min1` = 0, `dmg_max1` = 0, `delay` = 1800, `RandomProperty` = 0,
    `RandomSuffix` = 0, `ScalingStatDistribution` = 0, `ScalingStatValue` = 0, `SellPrice` = 159036,
    `BuyPrice` = 636144
WHERE `entry` = 505026;

DELETE FROM `dc_quest_reward_swap` WHERE `map` = 751;
INSERT INTO `dc_quest_reward_swap` (`map`, `kind`, `quest`, `col`, `old_item`, `new_item`) VALUES
(751, 'R', 204971, 5, 15812, 505007),
(751, 'R', 204971, 6, 15813, 505008),
(751, 'R', 205243, 5, 13216, 505002),
(751, 'R', 205243, 6, 13217, 505003),
(751, 'R', 205282, 1, 13315, 505004),
(751, 'R', 205384, 5, 15805, 505005),
(751, 'R', 205384, 6, 15806, 505006),
(751, 'R', 206135, 5, 16994, 505009),
(751, 'R', 206135, 6, 16995, 505010),
(751, 'R', 206136, 6, 17003, 505011),
(751, 'R', 206136, 7, 17004, 505012),
(751, 'R', 206163, 5, 18022, 505013),
(751, 'R', 208249, 1, 25878, 505026),
(751, 'R', 208418, 5, 20504, 505014),
(751, 'R', 208418, 7, 20505, 505015),
(751, 'R', 209221, 5, 22681, 505022),
(751, 'R', 209221, 6, 22680, 505021),
(751, 'R', 209221, 7, 22688, 505023),
(751, 'R', 209221, 9, 22690, 505025),
(751, 'R', 209221, 10, 22689, 505024),
(751, 'R', 209222, 5, 22657, 505017),
(751, 'R', 209222, 6, 22667, 505019),
(751, 'R', 209222, 7, 22668, 505020),
(751, 'R', 209222, 8, 22659, 505018),
(751, 'R', 209222, 10, 22656, 505016),
(751, 'R', 209223, 5, 22681, 505022),
(751, 'R', 209223, 6, 22680, 505021),
(751, 'R', 209223, 7, 22688, 505023),
(751, 'R', 209223, 9, 22690, 505025),
(751, 'R', 209223, 10, 22689, 505024),
(751, 'R', 209224, 5, 22657, 505017),
(751, 'R', 209224, 6, 22667, 505019),
(751, 'R', 209224, 7, 22668, 505020),
(751, 'R', 209224, 8, 22659, 505018),
(751, 'R', 209224, 10, 22656, 505016),
(751, 'R', 209225, 5, 22657, 505017),
(751, 'R', 209225, 6, 22667, 505019),
(751, 'R', 209225, 7, 22668, 505020),
(751, 'R', 209225, 8, 22659, 505018),
(751, 'R', 209225, 10, 22656, 505016),
(751, 'R', 209226, 5, 22681, 505022),
(751, 'R', 209226, 6, 22680, 505021),
(751, 'R', 209226, 7, 22688, 505023),
(751, 'R', 209226, 9, 22690, 505025),
(751, 'R', 209226, 10, 22689, 505024),
(751, 'R', 209227, 5, 22681, 505022),
(751, 'R', 209227, 6, 22680, 505021),
(751, 'R', 209227, 7, 22688, 505023),
(751, 'R', 209227, 9, 22690, 505025),
(751, 'R', 209227, 10, 22689, 505024),
(751, 'R', 209228, 5, 22657, 505017),
(751, 'R', 209228, 6, 22667, 505019),
(751, 'R', 209228, 7, 22668, 505020),
(751, 'R', 209228, 8, 22659, 505018),
(751, 'R', 209228, 10, 22656, 505016),
(751, 'R', 25029, 5, 3446, 505001),
(751, 'R', 25029, 6, 3440, 505000),
(751, 'C', 205243, 1, 3928, 400821),
(751, 'C', 205243, 2, 6149, 400822),
(751, 'C', 205721, 1, 15723, 400823),
(751, 'C', 24970, 1, 159, 400819),
(751, 'C', 27088, 1, 62909, 400818),
(751, 'C', 28484, 1, 65731, 400818),
(751, 'C', 28489, 1, 65730, 400818);

DELETE FROM `dc_quest_reward_money` WHERE `map` = 751;
INSERT INTO `dc_quest_reward_money` (`map`, `quest`, `money`) VALUES
(751, 204971, 135450),
(751, 204972, 135450),
(751, 204984, 101590),
(751, 205142, 67720),
(751, 205149, 69750),
(751, 205152, 69750),
(751, 205153, 101590),
(751, 205154, 135450),
(751, 205168, 139500),
(751, 205181, 139500),
(751, 205206, 139500),
(751, 205210, 67720),
(751, 205211, 139500),
(751, 205212, 209250),
(751, 205213, 209250),
(751, 205214, 209250),
(751, 205241, 69750),
(751, 205243, 209250),
(751, 205263, 209250),
(751, 205264, 139500),
(751, 205281, 139500),
(751, 205282, 209250),
(751, 205343, 203180),
(751, 205344, 169310),
(751, 205382, 203180),
(751, 205384, 203180),
(751, 205461, 135450),
(751, 205462, 101590),
(751, 205507, 135450),
(751, 205513, 139500),
(751, 205515, 203180),
(751, 205517, 174380),
(751, 205521, 169310),
(751, 205542, 139500),
(751, 205543, 139500),
(751, 205544, 139500),
(751, 205721, 169310),
(751, 205742, 13950),
(751, 205781, 139500),
(751, 205845, 139500),
(751, 205846, 139500),
(751, 205848, 203180),
(751, 205861, 104620),
(751, 205903, 135450),
(751, 205904, 67720),
(751, 205941, 69750),
(751, 206021, 104620),
(751, 206022, 139500),
(751, 206026, 139500),
(751, 206042, 139500),
(751, 206133, 139500),
(751, 206135, 139500),
(751, 206136, 139500),
(751, 206146, 139500),
(751, 206147, 69750),
(751, 206163, 209250),
(751, 206164, 34880),
(751, 208414, 135450),
(751, 208416, 67720),
(751, 208418, 203180),
(751, 209033, 139500),
(751, 209124, 139500),
(751, 209126, 139500),
(751, 209128, 139500),
(751, 209131, 139500),
(751, 209136, 139500),
(751, 209141, 69750),
(751, 209446, 169310),
(751, 209474, 135450),
(751, 24959, 11970),
(751, 24960, 89780),
(751, 24961, 89780),
(751, 24962, 59850),
(751, 24964, 59850),
(751, 24965, 59850),
(751, 24966, 59850),
(751, 24967, 59850),
(751, 24968, 59850),
(751, 24969, 59850),
(751, 24970, 11970),
(751, 24971, 149620),
(751, 24972, 89780),
(751, 24973, 119700),
(751, 24974, 89780),
(751, 24975, 89780),
(751, 24976, 89780),
(751, 24977, 11970),
(751, 24978, 119700),
(751, 24979, 59850),
(751, 24980, 119700),
(751, 24981, 119700),
(751, 24982, 11970),
(751, 24983, 11970),
(751, 24988, 59850),
(751, 24989, 11970),
(751, 24990, 59850),
(751, 24991, 11970),
(751, 24992, 59850),
(751, 24993, 89780),
(751, 24994, 89780),
(751, 24995, 89780),
(751, 24996, 59850),
(751, 24997, 119700),
(751, 24998, 119700),
(751, 24999, 89780),
(751, 25003, 89780),
(751, 25004, 89780),
(751, 25005, 11970),
(751, 25006, 119700),
(751, 25007, 11970),
(751, 25009, 119700),
(751, 25010, 59850),
(751, 25011, 11970),
(751, 25012, 89780),
(751, 25013, 89780),
(751, 25029, 119700),
(751, 25030, 119700),
(751, 25031, 11970),
(751, 25038, 59850),
(751, 25039, 59850),
(751, 25046, 149620),
(751, 25056, 89780),
(751, 25089, 59850),
(751, 25090, 89780),
(751, 26022, 195080),
(751, 26023, 13000),
(751, 26024, 260100),
(751, 26025, 195080),
(751, 26027, 195080),
(751, 26029, 260100),
(751, 26030, 195080),
(751, 26031, 195080),
(751, 26032, 195080),
(751, 26033, 65020),
(751, 26035, 260100),
(751, 26036, 195080),
(751, 26037, 195080),
(751, 26038, 260100),
(751, 26039, 195080),
(751, 26041, 195080),
(751, 26042, 130050),
(751, 26049, 260100),
(751, 26050, 195080),
(751, 26051, 195080),
(751, 26052, 65020),
(751, 26053, 195080),
(751, 26055, 195080),
(751, 26079, 260100),
(751, 26081, 260100),
(751, 26083, 65020),
(751, 26084, 65020),
(751, 26093, 195080),
(751, 26095, 195080),
(751, 26107, 195080),
(751, 26108, 195080),
(751, 26110, 195080),
(751, 26113, 65020),
(751, 26114, 13000),
(751, 26116, 195080),
(751, 26117, 260100),
(751, 26139, 65020),
(751, 26210, 165940),
(751, 26211, 132750),
(751, 26212, 132750),
(751, 26223, 132750),
(751, 26224, 132750),
(751, 26225, 132750),
(751, 26238, 132750),
(751, 26240, 132750),
(751, 26263, 165940),
(751, 26267, 132750),
(751, 26268, 132750),
(751, 26283, 165940),
(751, 26306, 132750),
(751, 26307, 132750),
(751, 26308, 165940),
(751, 26309, 165940),
(751, 26310, 132750),
(751, 26336, 65020),
(751, 26341, 65020),
(751, 26346, 65020),
(751, 26357, 132750),
(751, 26363, 132750),
(751, 26366, 165940),
(751, 26367, 165940),
(751, 26368, 165940),
(751, 26369, 199120),
(751, 26381, 132750),
(751, 26382, 132750),
(751, 26384, 66380),
(751, 26387, 132750),
(751, 26406, 132750),
(751, 26418, 132750),
(751, 26419, 199120),
(751, 26428, 195080),
(751, 26429, 195080),
(751, 26430, 97540),
(751, 26432, 66380),
(751, 26462, 132750),
(751, 26483, 165940),
(751, 26485, 132750),
(751, 26486, 132750),
(751, 26490, 165940),
(751, 26491, 132750),
(751, 26492, 132750),
(751, 26496, 66380),
(751, 26497, 132750),
(751, 26498, 132750),
(751, 26515, 165940),
(751, 26516, 165940),
(751, 26517, 132750),
(751, 26518, 165940),
(751, 26521, 132750),
(751, 26523, 132750),
(751, 26524, 165940),
(751, 26525, 165940),
(751, 26526, 199120),
(751, 26528, 132750),
(751, 26529, 132750),
(751, 26530, 132750),
(751, 26531, 165940),
(751, 26532, 199120),
(751, 26542, 97540),
(751, 26546, 165940),
(751, 26547, 165940),
(751, 26548, 99560),
(751, 26558, 165940),
(751, 26628, 195080),
(751, 26641, 132750),
(751, 26643, 132750),
(751, 26799, 149620),
(751, 26800, 149620),
(751, 26801, 149620),
(751, 26802, 119700),
(751, 26867, 12330),
(751, 26909, 65020),
(751, 26911, 65020),
(751, 26912, 260100),
(751, 226920, 29920),
(751, 26921, 135450),
(751, 26922, 135450),
(751, 26923, 169310),
(751, 26924, 203180),
(751, 26925, 169310),
(751, 226926, 13540),
(751, 226930, 89780),
(751, 26931, 119700),
(751, 26933, 119700),
(751, 26934, 119700),
(751, 26935, 13540),
(751, 26936, 59850),
(751, 26937, 135450),
(751, 26938, 169310),
(751, 26943, 13000),
(751, 226952, 11970),
(751, 26953, 169310),
(751, 26954, 135450),
(751, 26955, 169310),
(751, 26956, 135450),
(751, 26957, 33860),
(751, 26964, 119700),
(751, 26965, 92480),
(751, 26978, 119700),
(751, 226979, 59850),
(751, 26982, 13000),
(751, 26986, 13000),
(751, 26987, 13280),
(751, 26988, 13280),
(751, 26989, 123300),
(751, 26999, 169310),
(751, 27002, 101590),
(751, 27011, 135450),
(751, 27012, 135450),
(751, 27013, 135450),
(751, 27017, 135450),
(751, 27039, 92480),
(751, 27053, 67720),
(751, 27054, 135450),
(751, 27055, 203180),
(751, 27057, 135450),
(751, 27065, 12330),
(751, 27069, 123300),
(751, 27073, 123300),
(751, 27082, 123300),
(751, 27083, 11970),
(751, 27084, 135450),
(751, 27085, 169310),
(751, 27086, 135450),
(751, 27087, 13540),
(751, 27088, 154120),
(751, 27089, 203180),
(751, 27090, 135450),
(751, 27093, 154120),
(751, 27094, 154120),
(751, 27095, 123300),
(751, 27096, 184950),
(751, 27117, 203180),
(751, 27144, 135450),
(751, 27151, 135450),
(751, 27152, 169310),
(751, 27153, 135450),
(751, 27154, 169310),
(751, 27155, 169310),
(751, 27156, 203180),
(751, 27157, 169310),
(751, 27158, 33860),
(751, 27159, 135450),
(751, 27160, 169310),
(751, 27161, 135450),
(751, 27162, 203180),
(751, 27163, 203180),
(751, 27164, 169310),
(751, 27165, 13540),
(751, 27167, 135450),
(751, 27172, 67720),
(751, 27173, 135450),
(751, 27174, 169310),
(751, 27175, 13540),
(751, 27181, 123300),
(751, 27197, 13540),
(751, 27198, 169310),
(751, 27199, 135450),
(751, 27201, 169310),
(751, 27202, 169310),
(751, 27204, 203180),
(751, 27205, 13540),
(751, 27206, 135450),
(751, 27226, 123300),
(751, 27231, 123300),
(751, 27232, 184950),
(751, 27233, 13540),
(751, 27277, 11970),
(751, 27278, 11970),
(751, 27279, 11970),
(751, 27281, 11970),
(751, 27282, 11970),
(751, 27283, 11970),
(751, 27290, 119700),
(751, 27298, 12330),
(751, 27304, 12330),
(751, 27322, 239400),
(751, 27331, 11970),
(751, 27332, 11970),
(751, 27333, 149620),
(751, 27334, 11970),
(751, 27335, 11970),
(751, 27342, 119700),
(751, 27349, 149620),
(751, 27350, 119700),
(751, 27364, 149620),
(751, 27367, 13950),
(751, 27368, 139500),
(751, 27369, 139500),
(751, 27370, 13950),
(751, 27371, 139500),
(751, 27372, 139500),
(751, 27373, 69750),
(751, 27381, 104620),
(751, 27382, 174380),
(751, 27401, 149620),
(751, 27405, 179550),
(751, 27406, 179550),
(751, 27422, 13950),
(751, 27423, 239400),
(751, 27432, 139500),
(751, 27438, 239400),
(751, 27448, 69750),
(751, 27450, 139500),
(751, 27455, 13950),
(751, 27457, 69750),
(751, 27466, 34880),
(751, 27476, 123300),
(751, 27477, 139500),
(751, 27478, 123300),
(751, 27479, 139500),
(751, 27480, 154120),
(751, 27483, 123300),
(751, 27484, 123300),
(751, 27487, 139500),
(751, 27488, 139500),
(751, 27489, 69750),
(751, 27512, 123300),
(751, 27513, 154120),
(751, 27521, 139500),
(751, 27522, 139500),
(751, 27523, 139500),
(751, 27524, 34880),
(751, 27525, 174380),
(751, 27526, 209250),
(751, 27527, 139500),
(751, 27528, 139500),
(751, 27529, 139500),
(751, 27530, 174380),
(751, 27531, 139500),
(751, 27532, 13950),
(751, 27535, 13950),
(751, 27539, 174380),
(751, 27544, 13950),
(751, 27551, 139500),
(751, 27625, 165940),
(751, 27626, 165940),
(751, 27683, 13540),
(751, 27684, 13950),
(751, 27725, 66380),
(751, 27746, 126900),
(751, 27762, 13950),
(751, 28089, 126900),
(751, 28096, 126900),
(751, 28111, 12690),
(751, 28114, 126900),
(751, 28115, 126900),
(751, 28138, 190350),
(751, 28144, 126900),
(751, 28146, 126900),
(751, 28154, 126900),
(751, 28156, 190350),
(751, 28164, 11970),
(751, 28168, 12690),
(751, 28192, 126900),
(751, 28196, 158620),
(751, 28197, 126900),
(751, 28199, 126900),
(751, 28206, 63450),
(751, 28251, 31720),
(751, 28290, 11970),
(751, 28297, 11970),
(751, 28298, 11970),
(751, 28299, 11970),
(751, 28300, 11970),
(751, 28302, 12330),
(751, 28303, 12330),
(751, 28304, 11970),
(751, 28307, 11970),
(751, 28309, 11970),
(751, 28323, 11970),
(751, 28324, 126900),
(751, 28325, 126900),
(751, 28329, 126900),
(751, 28330, 158620),
(751, 28331, 190350),
(751, 28332, 126900),
(751, 28344, 12690),
(751, 28355, 158620),
(751, 28356, 158620),
(751, 28400, 253800),
(751, 28484, 126900),
(751, 28485, 253800),
(751, 28487, 126900),
(751, 28489, 126900),
(751, 28495, 126900),
(751, 228505, 33190),
(751, 28506, 126900),
(751, 28508, 33190),
(751, 28538, 190350),
(751, 28556, 158620),
(751, 28566, 126900),
(751, 28568, 123300),
(751, 28571, 12690),
(751, 28572, 13000),
(751, 28573, 13000),
(751, 28574, 13280),
(751, 28575, 13540),
(751, 28576, 13540),
(751, 28577, 13950),
(751, 28578, 13950),
(751, 28579, 13950),
(751, 28580, 13950),
(751, 28587, 12690),
(751, 28600, 126900),
(751, 28603, 126900),
(751, 28605, 126900),
(751, 28608, 119700),
(751, 28616, 253800),
(751, 28617, 126900),
(751, 28619, 13000),
(751, 28620, 31720),
(751, 28634, 126900),
(751, 28635, 126900),
(751, 28636, 126900),
(751, 28643, 158620),
(751, 28644, 158620),
(751, 28645, 158620),
(751, 28646, 158620),
(751, 28647, 253800),
(751, 28651, 11970),
(751, 28652, 11970),
(751, 28653, 11970),
(751, 28672, 59850),
(751, 28733, 126900),
(751, 28744, 126900),
(751, 28747, 126900),
(751, 28749, 33860),
(751, 28750, 33860),
(751, 28751, 126900),
(751, 29315, 119700),
(751, 29317, 119700),
(751, 29319, 119700),
(751, 29320, 119700),
(751, 29322, 119700),
(751, 29332, 119700),
(751, 29333, 119700),
(751, 29334, 119700),
(751, 29360, 119700),
(751, 29361, 119700),
(751, 29374, 89780),
(751, 29375, 89780),
(751, 29376, 59850),
(751, 29377, 59850),
(751, 29400, 11970);

-- one statement per reward column; only rows still holding the old item change (idempotent)
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 751 AND `w`.`col` = 1 AND `q`.`RewardItem1` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardItem1` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 751 AND `w`.`col` = 2 AND `q`.`RewardItem2` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardItem2` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 751 AND `w`.`col` = 3 AND `q`.`RewardItem3` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardItem3` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 751 AND `w`.`col` = 4 AND `q`.`RewardItem4` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardItem4` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 751 AND `w`.`col` = 5 AND `q`.`RewardChoiceItemID1` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardChoiceItemID1` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 751 AND `w`.`col` = 6 AND `q`.`RewardChoiceItemID2` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardChoiceItemID2` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 751 AND `w`.`col` = 7 AND `q`.`RewardChoiceItemID3` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardChoiceItemID3` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 751 AND `w`.`col` = 8 AND `q`.`RewardChoiceItemID4` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardChoiceItemID4` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 751 AND `w`.`col` = 9 AND `q`.`RewardChoiceItemID5` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardChoiceItemID5` = `w`.`new_item`;
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_swap` AS `w`
    ON `w`.`quest` = `q`.`ID` AND `w`.`map` = 751 AND `w`.`col` = 10 AND `q`.`RewardChoiceItemID6` = `w`.`old_item`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardChoiceItemID6` = `w`.`new_item`;

-- quest money: raised to the band formula, never lowered; quests that cost money are left alone
UPDATE `quest_template` AS `q`
JOIN `dc_quest_reward_money` AS `r`
    ON `r`.`quest` = `q`.`ID` AND `r`.`map` = 751 AND `q`.`RewardMoney` >= 0
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` < 725 AND `c`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g`
        ON `g`.`id` = `s`.`id` WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` < 725 AND `g`.`map` <> 37)
SET `q`.`RewardMoney` = IF(`q`.`RewardMoney` > `r`.`money`, `q`.`RewardMoney`, `r`.`money`);
