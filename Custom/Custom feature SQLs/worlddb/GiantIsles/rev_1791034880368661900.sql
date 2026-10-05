-- Isles of Giants: the island temple (the classic outdoor Sunken Temple model, az_sunkentemple.wmo) populated
-- like the same model in the Swamp of Sorrows, at level 80, and linked to the dungeon copy below it.
-- Positions = the stock map-0 spawns moved through the transform between the two placements (the island copy
-- is turned 6.66 deg and raised 53 yd), checked against the island navmesh. Needs the client patch with
-- AreaTrigger.dbc rows 6963/6964 (the dungeon-copy package) for the portals to fire; the same package maps
-- the temple's WMOAreaTable rows to area 5008 (The Temple of Atal'Hakkar), which the spawns use.
--
-- creature_template   400562-400571 (clones of 5263, 5261, 5243, 5225, 5224, 5235, 5399, 5400, 5401, 5269)
-- gameobject_template 700035 (Mossy Footlocker, level 80), 700036 (Atal'ai Tablet, decoration)
-- creature guid       9004001-9004057, gameobject guid 9005451-9005468
-- areatrigger         6963 (the temple's portal swirl -> dungeon), 6964 (dungeon swirl -> island temple)
-- Deleting from creature_template/gameobject_template is intended (custom ids only).

-- ---- mapping table (this session only) -------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `tmp_iog_out_npc`;
CREATE TEMPORARY TABLE `tmp_iog_out_npc` (`src` INT UNSIGNED NOT NULL PRIMARY KEY, `dst` INT UNSIGNED NOT NULL,
    `minlevel` TINYINT UNSIGNED NOT NULL, `maxlevel` TINYINT UNSIGNED NOT NULL, `rank` TINYINT UNSIGNED NOT NULL, `hp` FLOAT NOT NULL, `mp` FLOAT NOT NULL, `dmg` FLOAT NOT NULL,
    `lootid` INT UNSIGNED NOT NULL, `skinloot` INT UNSIGNED NOT NULL, `pickpocketloot` INT UNSIGNED NOT NULL, `mingold` INT UNSIGNED NOT NULL, `maxgold` INT UNSIGNED NOT NULL,
    `ai` VARCHAR(64) NOT NULL) ENGINE=InnoDB;
DELETE FROM `tmp_iog_out_npc`;
INSERT INTO `tmp_iog_out_npc` (`src`, `dst`, `minlevel`, `maxlevel`, `rank`, `hp`, `mp`, `dmg`, `lootid`, `skinloot`, `pickpocketloot`, `mingold`, `maxgold`, `ai`) VALUES
(5263, 400562, 79, 80, 0, 1, 1, 1, 400562, 0, 27533, 500, 3500, 'SmartAI'),
(5261, 400563, 79, 80, 0, 1, 1, 1, 400563, 0, 27533, 500, 3500, 'SmartAI'),
(5243, 400564, 79, 80, 0, 1, 1, 1, 400564, 0, 27533, 500, 3500, 'SmartAI'),
(5225, 400565, 79, 80, 0, 1, 1, 1, 400565, 70212, 0, 0, 0, 'SmartAI'),
(5224, 400566, 79, 80, 0, 1, 1, 1, 400566, 70212, 0, 0, 0, ''),
(5235, 400567, 79, 80, 0, 1, 1, 1, 400567, 0, 0, 500, 3500, ''),
(5399, 400568, 81, 81, 2, 4, 1, 7.5, 400568, 0, 0, 4000, 8000, 'SmartAI'),
(5400, 400569, 81, 81, 2, 4, 1, 7.5, 400569, 0, 0, 4000, 8000, 'SmartAI'),
(5401, 400570, 80, 80, 0, 1.5, 2, 1, 400570, 0, 27533, 4000, 8000, 'SmartAI'),
(5269, 400571, 79, 80, 0, 1, 5, 1, 400571, 0, 27533, 500, 3500, 'SmartAI');

-- ---- creature templates: the stock template with level-80 numbers ---------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (400562, 400563, 400564, 400565, 400566, 400567, 400568, 400569, 400570, 400571);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
    `m`.`dst`, 0, 0, 0, 0, 0,
    `t`.`name`, `t`.`subname`, `t`.`IconName`, `t`.`gossip_menu_id`, `m`.`minlevel`, `m`.`maxlevel`,
    2, `t`.`faction`, `t`.`npcflag`, `t`.`speed_walk`, `t`.`speed_run`, `t`.`speed_swim`,
    `t`.`speed_flight`, `t`.`detection_range`, `m`.`rank`, `t`.`dmgschool`, `m`.`dmg`, `t`.`BaseAttackTime`,
    `t`.`RangeAttackTime`, `t`.`BaseVariance`, `t`.`RangeVariance`, `t`.`unit_class`, `t`.`unit_flags`, `t`.`unit_flags2`,
    `t`.`dynamicflags`, `t`.`family`, `t`.`type`, `t`.`type_flags`, `m`.`lootid`, `m`.`pickpocketloot`,
    `m`.`skinloot`, `t`.`PetSpellDataId`, `t`.`VehicleId`, `m`.`mingold`, `m`.`maxgold`, `m`.`ai`,
    `t`.`MovementType`, `t`.`HoverHeight`, `m`.`hp`, `m`.`mp`, `t`.`ArmorModifier`, `t`.`ExperienceModifier`,
    `t`.`RacialLeader`, `t`.`movementId`, `t`.`RegenHealth`, `t`.`CreatureImmunitiesId`, `t`.`flags_extra`, '',
    12340
FROM `creature_template` AS `t`
JOIN `tmp_iog_out_npc` AS `m` ON `m`.`src` = `t`.`entry`;
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (400562, 400563, 400564, 400565, 400566, 400567, 400568, 400569, 400570, 400571);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT
    `m`.`dst`, `x`.`Idx`, `x`.`CreatureDisplayID`, `x`.`DisplayScale`, `x`.`Probability`, `x`.`VerifiedBuild`
FROM `creature_template_model` AS `x`
JOIN `tmp_iog_out_npc` AS `m` ON `m`.`src` = `x`.`CreatureID`;
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (400562, 400563, 400564, 400565, 400566, 400567, 400568, 400569, 400570, 400571);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT
    `m`.`dst`, `x`.`ID`, `x`.`ItemID1`, `x`.`ItemID2`, `x`.`ItemID3`, `x`.`VerifiedBuild`
FROM `creature_equip_template` AS `x`
JOIN `tmp_iog_out_npc` AS `m` ON `m`.`src` = `x`.`CreatureID`;
DELETE FROM `creature_template_addon` WHERE `entry` IN (400562, 400563, 400564, 400565, 400566, 400567, 400568, 400569, 400570, 400571);
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT
    `m`.`dst`, `x`.`path_id`, `x`.`mount`, `x`.`bytes1`, `x`.`bytes2`, `x`.`emote`, `x`.`visibilityDistanceType`, `x`.`auras`
FROM `creature_template_addon` AS `x`
JOIN `tmp_iog_out_npc` AS `m` ON `m`.`src` = `x`.`entry`;
DELETE FROM `creature_template_movement` WHERE `CreatureId` IN (400562, 400563, 400564, 400565, 400566, 400567, 400568, 400569, 400570, 400571);
INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`)
SELECT
    `m`.`dst`, `x`.`Ground`, `x`.`Swim`, `x`.`Flight`, `x`.`Rooted`, `x`.`Chase`, `x`.`Random`, `x`.`InteractionPauseTimer`
FROM `creature_template_movement` AS `x`
JOIN `tmp_iog_out_npc` AS `m` ON `m`.`src` = `x`.`CreatureId`;
DELETE FROM `creature_template_resistance` WHERE `CreatureID` IN (400562, 400563, 400564, 400565, 400566, 400567, 400568, 400569, 400570, 400571);
INSERT INTO `creature_template_resistance` (`CreatureID`, `School`, `Resistance`, `VerifiedBuild`)
SELECT
    `m`.`dst`, `x`.`School`, `x`.`Resistance`, `x`.`VerifiedBuild`
FROM `creature_template_resistance` AS `x`
JOIN `tmp_iog_out_npc` AS `m` ON `m`.`src` = `x`.`CreatureID`;
DELETE FROM `creature_template_spell` WHERE `CreatureID` IN (400562, 400563, 400564, 400565, 400566, 400567, 400568, 400569, 400570, 400571);
INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`)
SELECT
    `m`.`dst`, `x`.`Index`, `x`.`Spell`, `x`.`VerifiedBuild`
FROM `creature_template_spell` AS `x`
JOIN `tmp_iog_out_npc` AS `m` ON `m`.`src` = `x`.`CreatureID`;

-- ---- SmartAI (stock rows with level-80 spells; the two rares and Kazkaz get their template spells) --------
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (400562, 400563, 400564, 400565, 400566, 400567, 400568, 400569, 400570, 400571);
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(400562, 0, 0, 0, 0, 0, 100, 0, 0, 6000, 7000, 11000, 0, 0, 11, 16186, 0, 0, 0, 0, 0, 5, 30, 0, 0, 0, 0, 0, 0, 0, 'Mummified Atal''ai - In Combat - Cast ''Fevered Plague'''),
(400563, 0, 0, 0, 0, 0, 100, 0, 5000, 12000, 18000, 25000, 0, 0, 11, 12021, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Enthralled Atal''ai - In Combat - Cast ''Fixate'''),
(400564, 0, 0, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 0, 11, 12020, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Cursed Atal''ai - Between 0-30% Health - Cast ''Call of the Grave'''),
(400565, 0, 0, 0, 0, 0, 100, 0, 4000, 9000, 16000, 20000, 0, 0, 11, 45577, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Murk Spitter - In Combat - Cast ''Venom Spit'''),
(400568, 0, 0, 0, 0, 0, 100, 0, 3000, 6000, 12000, 16000, 0, 0, 11, 48880, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Veyzhak the Cannibal - In Combat - Cast ''Rend'''),
(400568, 0, 1, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Veyzhak the Cannibal - Between 0-30% Health - Cast ''Enrage'''),
(400569, 0, 0, 0, 0, 0, 100, 0, 0, 5000, 60000, 60000, 0, 0, 11, 24673, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Zekkis - In Combat - Cast ''Curse of Blood'''),
(400569, 0, 1, 0, 0, 0, 100, 0, 5000, 10000, 120000, 120000, 0, 0, 11, 7102, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Zekkis - In Combat - Cast ''Contagion of Rot'''),
(400570, 0, 0, 0, 0, 0, 100, 0, 6000, 9000, 15000, 20000, 0, 0, 11, 36736, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Kazkaz the Unholy - In Combat - Cast ''Shadow Bolt Volley'''),
(400570, 0, 1, 0, 0, 0, 100, 0, 2000, 5000, 12000, 18000, 0, 0, 11, 60005, 0, 0, 0, 0, 0, 5, 30, 0, 0, 0, 0, 0, 0, 0, 'Kazkaz the Unholy - In Combat - Cast ''Shadow Word: Pain'''),
(400571, 0, 0, 0, 14, 0, 100, 0, 12000, 40, 4000, 6000, 0, 0, 11, 31739, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Priest - Friendly Missing Health - Cast ''Heal'''),
(400571, 0, 1, 0, 0, 0, 100, 0, 0, 3000, 3000, 5000, 0, 0, 11, 51432, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Atal''ai Priest - In Combat - Cast ''Shadow Bolt''');

-- ---- loot: level-80 world loot; the rares drop one dungeon-trash rare -------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` IN (400562, 400563, 400564, 400565, 400566, 400567, 400568, 400569, 400570, 400571);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400562, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Mummified Atal''ai - World Loot Level 80'),
(400562, 33445, 0, 4, 0, 1, 0, 1, 1, 'Mummified Atal''ai - Honeymint Tea'),
(400562, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Mummified Atal''ai - Frostweave Cloth'),
(400562, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Mummified Atal''ai - Thick Fur Clothing Scraps'),
(400562, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Mummified Atal''ai - Dungeon Trash Rares'),
(400563, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Enthralled Atal''ai - World Loot Level 80'),
(400563, 33445, 0, 4, 0, 1, 0, 1, 1, 'Enthralled Atal''ai - Honeymint Tea'),
(400563, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Enthralled Atal''ai - Frostweave Cloth'),
(400563, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Enthralled Atal''ai - Thick Fur Clothing Scraps'),
(400563, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Enthralled Atal''ai - Dungeon Trash Rares'),
(400564, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Cursed Atal''ai - World Loot Level 80'),
(400564, 33445, 0, 4, 0, 1, 0, 1, 1, 'Cursed Atal''ai - Honeymint Tea'),
(400564, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Cursed Atal''ai - Frostweave Cloth'),
(400564, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Cursed Atal''ai - Thick Fur Clothing Scraps'),
(400564, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Cursed Atal''ai - Dungeon Trash Rares'),
(400565, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Murk Spitter - World Loot Level 80'),
(400565, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Murk Spitter - Dungeon Trash Rares'),
(400566, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Murk Slitherer - World Loot Level 80'),
(400566, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Murk Slitherer - Dungeon Trash Rares'),
(400567, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Fungal Ooze - World Loot Level 80'),
(400567, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Fungal Ooze - Dungeon Trash Rares'),
(400568, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Veyzhak the Cannibal - World Loot Level 80'),
(400568, 33445, 0, 4, 0, 1, 0, 1, 1, 'Veyzhak the Cannibal - Honeymint Tea'),
(400568, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Veyzhak the Cannibal - Frostweave Cloth'),
(400568, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Veyzhak the Cannibal - Thick Fur Clothing Scraps'),
(400568, 1604000, 1604000, 100, 0, 1, 0, 1, 1, 'Veyzhak the Cannibal - Dungeon Trash Rares (one guaranteed)'),
(400569, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Zekkis - World Loot Level 80'),
(400569, 1604000, 1604000, 100, 0, 1, 0, 1, 1, 'Zekkis - Dungeon Trash Rares (one guaranteed)'),
(400570, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Kazkaz the Unholy - World Loot Level 80'),
(400570, 33445, 0, 4, 0, 1, 0, 1, 1, 'Kazkaz the Unholy - Honeymint Tea'),
(400570, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Kazkaz the Unholy - Frostweave Cloth'),
(400570, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Kazkaz the Unholy - Thick Fur Clothing Scraps'),
(400570, 1604000, 1604000, 25, 0, 1, 0, 1, 1, 'Kazkaz the Unholy - Dungeon Trash Rares'),
(400571, 1, 1200380, 0, 0, 1, 5, 1, 1, 'Atal''ai Priest - World Loot Level 80'),
(400571, 33445, 0, 4, 0, 1, 0, 1, 1, 'Atal''ai Priest - Honeymint Tea'),
(400571, 33470, 1270002, 25, 0, 1, 0, 1, 1, 'Atal''ai Priest - Frostweave Cloth'),
(400571, 43852, 0, 18.8, 0, 1, 0, 1, 1, 'Atal''ai Priest - Thick Fur Clothing Scraps'),
(400571, 1604000, 1604000, 3, 0, 1, 0, 1, 1, 'Atal''ai Priest - Dungeon Trash Rares');
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 700035;
INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(700035, 33447, 0, 25, 0, 1, 0, 1, 2, 'Mossy Footlocker - Runic Healing Potion'),
(700035, 33448, 0, 25, 0, 1, 0, 1, 2, 'Mossy Footlocker - Runic Mana Potion'),
(700035, 40211, 0, 10, 0, 1, 0, 1, 1, 'Mossy Footlocker - Potion of Speed'),
(700035, 40212, 0, 10, 0, 1, 0, 1, 1, 'Mossy Footlocker - Potion of Wild Magic'),
(700035, 33444, 0, 40, 0, 1, 0, 1, 3, 'Mossy Footlocker - Pungent Seal Whey'),
(700035, 33449, 0, 30, 0, 1, 0, 1, 3, 'Mossy Footlocker - Crusty Flatbread'),
(700035, 1604000, 1604000, 10, 0, 1, 0, 1, 1, 'Mossy Footlocker - Dungeon Trash Rares');

-- ---- gameobject templates ----------------------------------------------------------------------------------
DELETE FROM `gameobject_template` WHERE `entry` IN (700035, 700036);
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`) VALUES
(700035, 3, 5744, 'Mossy Footlocker', '', '', '', 1, 1812, 700035, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340),
(700036, 5, 403, 'Atal''ai Tablet', '', '', '', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340);
DELETE FROM `gameobject_template_addon` WHERE `entry` = 700035;
INSERT INTO `gameobject_template_addon` (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`) VALUES
(700035, 94, 2, 20000, 60000, 0, 0, 0, 0);

-- ---- spawns ----------------------------------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 9004001 AND 9004057 AND `id` IN (400562, 400563, 400564, 400565, 400566, 400567, 400568, 400569, 400570, 400571);
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(9004001, 400563, 1405, 5006, 5008, 1, 1, 1, 6352.456, 847.393, -20.164, 3.0012, 900, 5, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Enthralled Atal''ai (stock 31844)'),
(9004002, 400562, 1405, 5006, 5008, 1, 1, 0, 6439.363, 903.506, -52.48, 5.4569, 900, 5, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 37601)'),
(9004003, 400571, 1405, 5006, 5008, 1, 1, 1, 6330.405, 1018.711, -43.93, 0.0813, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Atal''ai Priest (stock 38670)'),
(9004004, 400564, 1405, 5006, 5008, 1, 1, 1, 6323.16, 985.92, -44.014, 4.6366, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Cursed Atal''ai (stock 38671)'),
(9004005, 400563, 1405, 5006, 5008, 1, 1, 1, 6339.554, 991.217, -43.735, 4.3573, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Enthralled Atal''ai (stock 38672)'),
(9004006, 400566, 1405, 5006, 5008, 1, 1, 0, 6374.541, 1009.699, -37.264, 2.0556, 900, 3, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Murk Slitherer (stock 38673)'),
(9004007, 400564, 1405, 5006, 5008, 1, 1, 1, 6333.959, 1018.451, -43.868, 2.9785, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Cursed Atal''ai (stock 38674)'),
(9004008, 400563, 1405, 5006, 5008, 1, 1, 1, 6321.54, 1004.97, -44.067, 4.689, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Enthralled Atal''ai (stock 38675)'),
(9004009, 400563, 1405, 5006, 5008, 1, 1, 1, 6335.302, 978.478, -43.793, 4.3748, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Enthralled Atal''ai (stock 38676)'),
(9004010, 400571, 1405, 5006, 5008, 1, 1, 1, 6318.678, 971.704, -44.073, 4.8111, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Atal''ai Priest (stock 38677)'),
(9004011, 400564, 1405, 5006, 5008, 1, 1, 1, 6337.313, 963.842, -43.738, 4.2177, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Cursed Atal''ai (stock 38678)'),
(9004012, 400564, 1405, 5006, 5008, 1, 1, 1, 6391.138, 880.499, -19.757, 0.9738, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Cursed Atal''ai (stock 38679)'),
(9004013, 400564, 1405, 5006, 5008, 1, 1, 1, 6398.645, 911.056, -19.596, 4.579, 900, 5, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Cursed Atal''ai (stock 38680)'),
(9004014, 400563, 1405, 5006, 5008, 1, 1, 1, 6384.936, 899.136, -19.89, 1.6297, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Enthralled Atal''ai (stock 38683)'),
(9004015, 400562, 1405, 5006, 5008, 1, 1, 0, 6437.543, 923.87, -32.298, 4.7413, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 38705)'),
(9004016, 400562, 1405, 5006, 5008, 1, 1, 0, 6462.67, 944.03, -31.826, 3.6243, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 38706)'),
(9004017, 400562, 1405, 5006, 5008, 1, 1, 0, 6439.782, 946.079, -32.225, 0.4129, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 38707)'),
(9004018, 400562, 1405, 5006, 5008, 1, 1, 0, 6483.096, 918.235, -31.445, 3.9036, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 38708)'),
(9004019, 400565, 1405, 5006, 5008, 1, 1, 0, 6484.23, 939.571, -31.447, 5.5442, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Murk Spitter (stock 38709)'),
(9004020, 400562, 1405, 5006, 5008, 1, 1, 0, 6478.445, 895.986, -31.504, 4.0781, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 38710)'),
(9004021, 400566, 1405, 5006, 5008, 1, 1, 0, 6408.469, 935.56, -13.728, 2.288, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Murk Slitherer (stock 38790)'),
(9004022, 400571, 1405, 5006, 5008, 1, 1, 1, 6339.038, 928.518, -21.412, 1.7917, 900, 5, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Atal''ai Priest (stock 38791)'),
(9004023, 400563, 1405, 5006, 5008, 1, 1, 1, 6337.589, 931.45, -21.44, 5.0904, 900, 5, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Enthralled Atal''ai (stock 38792)'),
(9004024, 400562, 1405, 5006, 5008, 1, 1, 0, 6435.603, 902.531, -32.234, 2.1233, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 38882)'),
(9004025, 400565, 1405, 5006, 5008, 1, 1, 0, 6476.212, 942.732, -31.671, 3.0406, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Murk Spitter (stock 38884)'),
(9004026, 400566, 1405, 5006, 5008, 1, 1, 0, 6413.013, 1053.216, 17.987, 3.7601, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Murk Slitherer (stock 38922)'),
(9004027, 400566, 1405, 5006, 5008, 1, 1, 0, 6383.36, 958.362, -14.195, 2.5768, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Murk Slitherer (stock 38924)'),
(9004028, 400571, 1405, 5006, 5008, 1, 1, 1, 6328.624, 912.522, -21.555, 2.8696, 900, 3, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Atal''ai Priest (stock 38925)'),
(9004029, 400567, 1405, 5006, 5008, 1, 1, 0, 6407.057, 981.295, -13.813, 4.0107, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Fungal Ooze (stock 38926)'),
(9004030, 400566, 1405, 5006, 5008, 1, 1, 0, 6407.852, 1011.107, 0.978, 1.4711, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Murk Slitherer (stock 38927)'),
(9004031, 400564, 1405, 5006, 5008, 1, 1, 1, 6288.933, 930.942, -28.507, 4.5167, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Cursed Atal''ai (stock 38928)'),
(9004032, 400565, 1405, 5006, 5008, 1, 1, 0, 6361.54, 939.191, -14.579, 1.4326, 900, 3, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Murk Spitter (stock 38930)'),
(9004033, 400567, 1405, 5006, 5008, 1, 1, 0, 6356.873, 901.517, -20.279, 3.7988, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Fungal Ooze (stock 38933)'),
(9004034, 400571, 1405, 5006, 5008, 1, 1, 1, 6291.148, 943.877, -28.487, 1.7687, 900, 5, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Atal''ai Priest (stock 38934)'),
(9004035, 400563, 1405, 5006, 5008, 1, 1, 1, 6318.673, 928.788, -21.766, 0.7271, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Enthralled Atal''ai (stock 38938)'),
(9004036, 400563, 1405, 5006, 5008, 1, 1, 1, 6322.262, 930.808, -21.706, 3.4323, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Enthralled Atal''ai (stock 38942)'),
(9004037, 400570, 1405, 5006, 5008, 1, 1, 1, 6325.333, 949.586, -29.128, 6.0391, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Kazkaz the Unholy (stock 38944)'),
(9004038, 400562, 1405, 5006, 5008, 1, 1, 0, 6318.389, 851.768, -20.969, 3.9771, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 38947)'),
(9004039, 400562, 1405, 5006, 5008, 1, 1, 0, 6368.652, 841.982, -19.925, 3.0658, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 38948)'),
(9004040, 400562, 1405, 5006, 5008, 1, 1, 0, 6338.899, 853.69, -20.456, 5.1777, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 38949)'),
(9004041, 400562, 1405, 5006, 5008, 1, 1, 0, 6364.876, 842.427, -19.991, 6.155, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 38950)'),
(9004042, 400564, 1405, 5006, 5008, 1, 1, 1, 6385.391, 844.31, -19.536, 0.4105, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Cursed Atal''ai (stock 38952)'),
(9004043, 400571, 1405, 5006, 5008, 1, 1, 1, 6428.231, 838.67, -18.988, 1.6476, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Atal''ai Priest (stock 38954)'),
(9004044, 400571, 1405, 5006, 5008, 1, 1, 1, 6403.78, 844.604, -19.266, 2.3851, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Atal''ai Priest (stock 38956)'),
(9004045, 400563, 1405, 5006, 5008, 1, 1, 1, 6354.228, 847.396, -20.083, 6.0802, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Enthralled Atal''ai (stock 38957)'),
(9004046, 400571, 1405, 5006, 5008, 1, 1, 1, 6341.139, 850.881, -20.413, 2.0012, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Atal''ai Priest (stock 38960)'),
(9004047, 400562, 1405, 5006, 5008, 1, 1, 0, 6400.047, 846.384, -19.282, 5.8932, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 38964)'),
(9004048, 400562, 1405, 5006, 5008, 1, 1, 0, 6476.851, 918.026, -41.592, 5.4918, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 39549)'),
(9004049, 400562, 1405, 5006, 5008, 1, 1, 0, 6456.286, 920.655, -52.208, 3.7639, 900, 3, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 40157)'),
(9004050, 400562, 1405, 5006, 5008, 1, 1, 0, 6445.587, 939.223, -42.147, 5.5267, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 40158)'),
(9004051, 400565, 1405, 5006, 5008, 1, 1, 0, 6465.487, 924.619, -52.053, 2.1582, 900, 3, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Murk Spitter (stock 40159)'),
(9004052, 400562, 1405, 5006, 5008, 1, 1, 0, 6465.527, 911.334, -51.952, 6.1725, 900, 3, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 40183)'),
(9004053, 400565, 1405, 5006, 5008, 1, 1, 0, 6457.99, 887.912, -46.077, 6.1032, 900, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Murk Spitter (stock 40186)'),
(9004054, 400565, 1405, 5006, 5008, 1, 1, 0, 6479.453, 935.405, -41.571, 4.2003, 900, 2, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Murk Spitter (stock 40187)'),
(9004055, 400562, 1405, 5006, 5008, 1, 1, 0, 6441.435, 912.713, -42.284, 5.1951, 900, 5, 0, 0, 0, 1, 0, 0, 0, '', 0, 0, 'IoG island temple - Mummified Atal''ai (stock 40199)'),
(9004056, 400569, 1405, 5006, 5008, 1, 1, 1, 6440.74, 922.961, -42.21, 0.5173, 28800, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Zekkis (stock 160355)'),
(9004057, 400568, 1405, 5006, 5008, 1, 1, 1, 6393.082, 895.531, -18.177, 2.9066, 28800, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'IoG island temple - Veyzhak the Cannibal (stock 160358)');
DELETE FROM `creature_addon` WHERE `guid` BETWEEN 9004001 AND 9004057;
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`) VALUES
(9004001, 0, 0, 0, 1, 0, 0, NULL),
(9004003, 0, 0, 0, 1, 0, 0, NULL),
(9004004, 0, 0, 8, 1, 0, 0, NULL),
(9004005, 0, 0, 8, 1, 0, 0, NULL),
(9004007, 0, 0, 0, 1, 0, 0, NULL),
(9004008, 0, 0, 8, 1, 0, 0, NULL),
(9004009, 0, 0, 8, 1, 0, 0, NULL),
(9004010, 0, 0, 8, 1, 0, 0, NULL),
(9004011, 0, 0, 8, 1, 0, 0, NULL),
(9004012, 0, 0, 0, 1, 0, 0, NULL),
(9004013, 0, 0, 0, 1, 0, 0, NULL),
(9004014, 0, 0, 0, 1, 0, 0, NULL),
(9004022, 0, 0, 0, 1, 0, 0, NULL),
(9004023, 0, 0, 0, 1, 0, 0, NULL),
(9004028, 0, 0, 0, 1, 0, 0, NULL),
(9004031, 0, 0, 0, 1, 0, 0, NULL),
(9004034, 0, 0, 0, 1, 0, 0, NULL),
(9004035, 0, 0, 0, 1, 0, 0, NULL),
(9004036, 0, 0, 0, 1, 0, 0, NULL),
(9004037, 0, 0, 0, 1, 0, 0, NULL),
(9004042, 0, 0, 0, 1, 0, 0, NULL),
(9004043, 0, 0, 0, 1, 0, 0, NULL),
(9004044, 0, 0, 0, 1, 0, 0, NULL),
(9004045, 0, 0, 0, 1, 0, 0, NULL),
(9004046, 0, 0, 0, 1, 0, 0, NULL);
DELETE FROM `gameobject` WHERE `guid` BETWEEN 9005451 AND 9005468 AND `id` IN (700035, 700036);
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`) VALUES
(9005451, 700036, 1405, 5006, 5008, 1, 1, 6396.857, 954.43, -16.908, 2.5597, 0, 0, 0.958, 0.2869, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30342)'),
(9005452, 700036, 1405, 5006, 5008, 1, 1, 6315.08, 896.486, -20.945, 0.8492, 0, 0, 0.412, 0.9112, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30344)'),
(9005453, 700036, 1405, 5006, 5008, 1, 1, 6318.134, 935.148, -21.868, 5.1428, 0, 0, 0.5398, -0.8418, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30345)'),
(9005454, 700036, 1405, 5006, 5008, 1, 1, 6392.087, 987.963, -14.182, 4.5843, 0, 0, 0.7509, -0.6604, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30351)'),
(9005455, 700036, 1405, 5006, 5008, 1, 1, 6363.608, 1045.056, 18.588, 1.2332, 0, 0, 0.5783, 0.8158, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30352)'),
(9005456, 700036, 1405, 5006, 5008, 1, 1, 6329.666, 1023.808, -41.421, 0.7794, 0, 0, 0.3799, 0.925, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30353)'),
(9005457, 700036, 1405, 5006, 5008, 1, 1, 6335.659, 1066.85, 2.809, 3.9734, 0, 0, 0.9148, -0.404, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30354)'),
(9005458, 700036, 1405, 5006, 5008, 1, 1, 6349.133, 981.219, -41.026, 2.2979, 0, 0, 0.9123, 0.4094, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30355)'),
(9005459, 700036, 1405, 5006, 5008, 1, 1, 6370.053, 1081.267, 18.653, 1.1983, 0, 0, 0.5639, 0.8258, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30357)'),
(9005460, 700036, 1405, 5006, 5008, 1, 1, 6310.836, 952.841, -27.969, 1.9488, 0, 0, 0.8274, 0.5617, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30358)'),
(9005461, 700036, 1405, 5006, 5008, 1, 1, 6327.627, 953.747, -26.837, 4.5494, 0, 0, 0.7623, -0.6472, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30359)'),
(9005462, 700036, 1405, 5006, 5008, 1, 1, 6284.209, 928.946, -27.113, 0.6747, 0, 0, 0.331, 0.9436, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30366)'),
(9005463, 700036, 1405, 5006, 5008, 1, 1, 6308.058, 964.008, -41.719, 1.1459, 0, 0, 0.5421, 0.8403, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30367)'),
(9005464, 700036, 1405, 5006, 5008, 1, 1, 6341.242, 950.21, -27.436, 5.6489, 0, 0, 0.3119, -0.9501, 300, 100, 1, '', 0, 'IoG island temple - Atal''ai Tablet (stock 30368)'),
(9005465, 700035, 1405, 5006, 5008, 1, 1, 6295.662, 1138.869, 47.684, 1.0936, 0, 0, 0.52, 0.8542, 1800, 100, 1, '', 0, 'IoG island temple - Mossy Footlocker (stock 30566)'),
(9005466, 700035, 1405, 5006, 5015, 1, 1, 6148.099, 1154.418, 33.3, 1.0936, 0, 0, 0.52, 0.8542, 1800, 100, 1, '', 0, 'IoG island temple - Mossy Footlocker (stock 30567)'),
(9005467, 700035, 1405, 5006, 5008, 1, 1, 6277.236, 1004.876, 49.903, 5.5791, 0, 0, 0.3448, -0.9387, 1800, 100, 1, '', 0, 'IoG island temple - Mossy Footlocker (stock 30580)'),
(9005468, 700035, 1405, 5006, 5008, 1, 1, 6312.308, 1112.171, 51.458, 0.2558, 0, 0, 0.1276, 0.9918, 1800, 100, 1, '', 0, 'IoG island temple - Mossy Footlocker (stock 30582)');

-- ---- portals: the island temple's own swirl into the dungeon copy, and the dungeon's swirl back out ---------
DELETE FROM `areatrigger` WHERE `entry` IN (6963, 6964);
INSERT INTO `areatrigger` (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
(6963, 1405, 6527.579, 940.876, -49.091, 11, 0, 0, 0, 0),
(6964, 1405, 6467, 1084, -227, 13, 0, 0, 0, 0);
DELETE FROM `areatrigger_teleport` WHERE `ID` IN (6963, 6964);
INSERT INTO `areatrigger_teleport` (`ID`, `Name`, `target_map`, `target_position_x`, `target_position_y`, `target_position_z`, `target_orientation`) VALUES
(6963, 'Isles of Giants - Temple of Atal''Hakkar (entrance)', 1405, 6447.76, 1084.9, -231.85, 3.19),
(6964, 'Isles of Giants - Temple of Atal''Hakkar (exit)', 1405, 6514.945, 942.908, -53.596, 3.0756);

DROP TEMPORARY TABLE IF EXISTS `tmp_iog_out_npc`;
