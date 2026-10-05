-- ---------------------------------------------------------------------------
-- Azshara Crater (map 37) -- side-hub group quests + main-hub spawn corrections, 2026-10-01
-- ---------------------------------------------------------------------------
-- Part 1 moves 19 of the 100 main-hub spawns from rev_1790885136842811900. Those points were
-- picked from the ADT height map, which cannot see rocks, trees or the water's edge; the
-- server's own navmesh (mmaps) has no walkable ground under them. They now stand on navmesh
-- ground in the same camps, and the affected map markers follow. That file was regenerated
-- with the same positions, so re-running it gives the same result as this part.
--
-- Part 2 fixes the side-hub group quests:
--   300512 Grim Wanderers         Skul clone 300092 (stock Skul despawns itself on spawn) and
--                                 stock Tendris Warpwood, in Lunara's temple
--   300931 Spirestone Menace      one objective, "10 Spirestone ogres, whatever their kind" as
--                                 the text always said: Reaver 9200, Lord Magus 9217 and Butcher
--                                 9219 now give Spirestone Mystic credit (KillCredit1 = 9198; no
--                                 other quest uses 9198). 5 Mystics + 4 Reavers added to the pit.
--   300934 The Dark Iron General  General Angerforge clone 300096: the stock C++ AI only exists
--                                 inside Blackrock Depths, the clone fights with the same three
--                                 abilities as SmartAI
--   300962 The Forgotten Ones     Faceless Lurker 31691 (+7 spawns), was "Your Inner Turmoil"
--   300963 Arcane Sentinels       Arcane Sentinel clone 300095 of Library Guardian 29724
--                                 (rooted until pulled), was Netherspite
--   300964 Scourge Infestation    Darkmender's Ghoul clone 300094 (stock is faction 2050,
--                                 friendly) + Malefic Necromancer 31155 (as 300802)
--   300965 Highborne Spirits      Darkmender's Ghouls ("Setaal's Pet" = the servants of Setaal)
--                                 + Moonrest Highborne; 10 more Moonrest, which also feeds 300801,
--                                 300804 and 300805 (the crater had 2 spawns for four quests)
--   300966 Lady Nightswood        clone 300093: the stock one is a "Free Your Mind" quest NPC
--                                 that cannot die (invincible at 1%, feigns death, despawns)
-- Clones keep only combat SmartAI rows; loot from Ymirjar Dusk Shaman 26694 (Nightswood) and
-- Blighted Corpse 28641 (ghouls), the rest keep their own.
--
-- Every new and moved point was taken from the server navmesh (K:/Dark-Chaos/Server/data/mmaps,
-- built 2026-09-05 like the maps): centre of a walkable ground triangle, in the same connected
-- mesh as existing spawns of that floor (cave and temple floors included), 2.5 yd of ground
-- around it, inside the floor's height band, away from guards/NPCs/other camps. Spawns:
-- guids 9002401-9002460. Bosses 600 s respawn and stand still, everything else 300 s.
-- Map markers: objective rectangles; 300963/300964/300966 pointed at maps 0 and 571.
-- Arcanigos' quests also get a turn-in marker.
--
-- Idempotent and guarded like the earlier crater files. Restart the worldserver afterwards;
-- no `.reload` (playerbots hold Quest pointers).
-- ---------------------------------------------------------------------------

-- 1. Main-hub spawns onto navmesh ground
UPDATE `creature` SET `position_x` = 236.08, `position_y` = 934.94, `position_z` = 262.58 WHERE `guid` = 9002303 AND `id` = 1128 AND `map` = 37;
UPDATE `creature` SET `position_x` = 207.73, `position_y` = 940.18, `position_z` = 263.12 WHERE `guid` = 9002307 AND `id` = 1128 AND `map` = 37;
UPDATE `creature` SET `position_x` = 175.89, `position_y` = 921.28, `position_z` = 266.49 WHERE `guid` = 9002308 AND `id` = 1128 AND `map` = 37;
UPDATE `creature` SET `position_x` = 186.51, `position_y` = 938.40, `position_z` = 266.58 WHERE `guid` = 9002309 AND `id` = 1128 AND `map` = 37;
UPDATE `creature` SET `position_x` = 3.55, `position_y` = 785.86, `position_z` = 282.85 WHERE `guid` = 9002315 AND `id` = 2027 AND `map` = 37;
UPDATE `creature` SET `position_x` = 95.64, `position_y` = 830.71, `position_z` = 273.78 WHERE `guid` = 9002324 AND `id` = 2022 AND `map` = 37;
UPDATE `creature` SET `position_x` = 430.62, `position_y` = 265.96, `position_z` = 249.79 WHERE `guid` = 9002341 AND `id` = 300090 AND `map` = 37;
UPDATE `creature` SET `position_x` = 439.29, `position_y` = 265.51, `position_z` = 243.03 WHERE `guid` = 9002342 AND `id` = 300090 AND `map` = 37;
UPDATE `creature` SET `position_x` = 428.80, `position_y` = 261.24, `position_z` = 240.28 WHERE `guid` = 9002344 AND `id` = 300090 AND `map` = 37;
UPDATE `creature` SET `position_x` = 418.31, `position_y` = 255.38, `position_z` = 240.72 WHERE `guid` = 9002346 AND `id` = 300090 AND `map` = 37;
UPDATE `creature` SET `position_x` = 444.44, `position_y` = 254.93, `position_z` = 241.52 WHERE `guid` = 9002348 AND `id` = 300090 AND `map` = 37;
UPDATE `creature` SET `position_x` = 438.93, `position_y` = 245.60, `position_z` = 239.83 WHERE `guid` = 9002350 AND `id` = 300090 AND `map` = 37;
UPDATE `creature` SET `position_x` = 268.79, `position_y` = 93.86, `position_z` = 240.46 WHERE `guid` = 9002361 AND `id` = 2505 AND `map` = 37;
UPDATE `creature` SET `position_x` = 233.24, `position_y` = 99.09, `position_z` = 236.90 WHERE `guid` = 9002362 AND `id` = 2505 AND `map` = 37;
UPDATE `creature` SET `position_x` = 1107.17, `position_y` = 108.62, `position_z` = 268.57 WHERE `guid` = 9002364 AND `id` = 10661 AND `map` = 37;
UPDATE `creature` SET `position_x` = 1097.07, `position_y` = 87.02, `position_z` = 269.01 WHERE `guid` = 9002367 AND `id` = 10661 AND `map` = 37;
UPDATE `creature` SET `position_x` = 1110.96, `position_y` = 156.53, `position_z` = 274.26 WHERE `guid` = 9002369 AND `id` = 10661 AND `map` = 37;
UPDATE `creature` SET `position_x` = 1114.13, `position_y` = 100.80, `position_z` = 269.46 WHERE `guid` = 9002372 AND `id` = 10660 AND `map` = 37;
UPDATE `creature` SET `position_x` = 1090.02, `position_y` = 117.67, `position_z` = 268.66 WHERE `guid` = 9002376 AND `id` = 10660 AND `map` = 37;
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300102 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300102, 0, 0, 141, 862, 0),
(300102, 0, 1, 141, 970, 0),
(300102, 0, 2, 257, 970, 0),
(300102, 0, 3, 257, 862, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300103 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300103, 0, 0, 75, 750, 0),
(300103, 0, 1, 75, 874, 0),
(300103, 0, 2, 202, 874, 0),
(300103, 0, 3, 202, 750, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300401 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300401, 0, 0, 213, 73, 0),
(300401, 0, 1, 213, 146, 0),
(300401, 0, 2, 294, 146, 0),
(300401, 0, 3, 294, 73, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300403 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300403, 0, 0, 1070, 61, 0),
(300403, 0, 1, 1070, 169, 0),
(300403, 0, 2, 1143, 169, 0),
(300403, 0, 3, 1143, 61, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300402 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300402, 0, 0, 1067, 67, 0),
(300402, 0, 1, 1067, 177, 0),
(300402, 0, 2, 1167, 177, 0),
(300402, 0, 3, 1167, 67, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300400 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300400, 0, 0, 349, 189, 0),
(300400, 0, 1, 349, 289, 0),
(300400, 0, 2, 465, 289, 0),
(300400, 0, 3, 465, 189, 0);

-- 2a. Clone templates
DELETE FROM `creature_template` WHERE `entry` = 300092;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 300092, 0, 0, 0, 0, 0, `s`.`name`, `s`.`subname`, `s`.`IconName`, `s`.`gossip_menu_id`, 60, 60,
    `s`.`exp`, `s`.`faction`, `s`.`npcflag`, `s`.`speed_walk`, `s`.`speed_run`, `s`.`speed_swim`,
    `s`.`speed_flight`, `s`.`detection_range`, `s`.`rank`, `s`.`dmgschool`, `s`.`DamageModifier`,
    `s`.`BaseAttackTime`, `s`.`RangeAttackTime`, `s`.`BaseVariance`, `s`.`RangeVariance`, `s`.`unit_class`,
    `s`.`unit_flags`, `s`.`unit_flags2`, `s`.`dynamicflags`, `s`.`family`, `s`.`type`, `s`.`type_flags`,
    `d`.`lootid`, `d`.`pickpocketloot`, `d`.`skinloot`, `s`.`PetSpellDataId`, `s`.`VehicleId`, `d`.`mingold`,
    `d`.`maxgold`, `s`.`AIName`, `s`.`MovementType`, `s`.`HoverHeight`, `s`.`HealthModifier`,
    `s`.`ManaModifier`, `s`.`ArmorModifier`, `s`.`ExperienceModifier`, `s`.`RacialLeader`, `s`.`movementId`,
    `s`.`RegenHealth`, `s`.`CreatureImmunitiesId`, `s`.`flags_extra`, '', 0
FROM `creature_template` AS `s` JOIN `creature_template` AS `d` ON `d`.`entry` = 10393 WHERE `s`.`entry` = 10393;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 300092;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT 300092, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`
FROM `creature_template_model` WHERE `CreatureID` = 10393;
DELETE FROM `creature_template_spell` WHERE `CreatureID` = 300092;
INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`)
SELECT 300092, `Index`, `Spell`, `VerifiedBuild`
FROM `creature_template_spell` WHERE `CreatureID` = 10393;
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 300092;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT 300092, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`,
    `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
    `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`,
    `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
    `target_x`, `target_y`, `target_z`, `target_o`, `comment`
FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 10393 AND `id` IN (1, 2, 3, 4);

DELETE FROM `creature_template` WHERE `entry` = 300093;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 300093, 0, 0, 0, 0, 0, `s`.`name`, `s`.`subname`, `s`.`IconName`, `s`.`gossip_menu_id`, 78, 78, 2,
    `s`.`faction`, `s`.`npcflag`, `s`.`speed_walk`, `s`.`speed_run`, `s`.`speed_swim`, `s`.`speed_flight`,
    `s`.`detection_range`, 1, `s`.`dmgschool`, 1.5, `s`.`BaseAttackTime`, `s`.`RangeAttackTime`,
    `s`.`BaseVariance`, `s`.`RangeVariance`, `s`.`unit_class`, `s`.`unit_flags`, `s`.`unit_flags2`,
    `s`.`dynamicflags`, `s`.`family`, `s`.`type`, `s`.`type_flags`, `d`.`lootid`, `d`.`pickpocketloot`,
    `d`.`skinloot`, `s`.`PetSpellDataId`, `s`.`VehicleId`, `d`.`mingold`, `d`.`maxgold`, `s`.`AIName`,
    `s`.`MovementType`, `s`.`HoverHeight`, 6, `s`.`ManaModifier`, `s`.`ArmorModifier`,
    `s`.`ExperienceModifier`, `s`.`RacialLeader`, `s`.`movementId`, `s`.`RegenHealth`,
    `s`.`CreatureImmunitiesId`, `s`.`flags_extra`, '', 0
FROM `creature_template` AS `s` JOIN `creature_template` AS `d` ON `d`.`entry` = 26694 WHERE `s`.`entry` = 29770;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 300093;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT 300093, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`
FROM `creature_template_model` WHERE `CreatureID` = 29770;
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 300093;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT 300093, `source_type`, `id` - 20, `link`, `event_type`, `event_phase_mask`, `event_chance`,
    `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`,
    `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`,
    `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`,
    `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`
FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 29770 AND `id` IN (20, 21);

DELETE FROM `creature_template` WHERE `entry` = 300094;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 300094, 0, 0, 0, 0, 0, `s`.`name`, `s`.`subname`, `s`.`IconName`, `s`.`gossip_menu_id`, 76, 77, 2, 21,
    `s`.`npcflag`, `s`.`speed_walk`, `s`.`speed_run`, `s`.`speed_swim`, `s`.`speed_flight`,
    `s`.`detection_range`, `s`.`rank`, `s`.`dmgschool`, `s`.`DamageModifier`, `s`.`BaseAttackTime`,
    `s`.`RangeAttackTime`, `s`.`BaseVariance`, `s`.`RangeVariance`, `s`.`unit_class`, `s`.`unit_flags`,
    `s`.`unit_flags2`, `s`.`dynamicflags`, `s`.`family`, `s`.`type`, `s`.`type_flags`, `d`.`lootid`,
    `d`.`pickpocketloot`, `d`.`skinloot`, `s`.`PetSpellDataId`, `s`.`VehicleId`, `d`.`mingold`, `d`.`maxgold`,
    `s`.`AIName`, `s`.`MovementType`, `s`.`HoverHeight`, `s`.`HealthModifier`, `s`.`ManaModifier`,
    `s`.`ArmorModifier`, `s`.`ExperienceModifier`, `s`.`RacialLeader`, `s`.`movementId`, `s`.`RegenHealth`,
    `s`.`CreatureImmunitiesId`, `s`.`flags_extra`, '', 0
FROM `creature_template` AS `s` JOIN `creature_template` AS `d` ON `d`.`entry` = 28641 WHERE `s`.`entry` = 29517;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 300094;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT 300094, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`
FROM `creature_template_model` WHERE `CreatureID` = 29517;

DELETE FROM `creature_template` WHERE `entry` = 300095;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 300095, 0, 0, 0, 0, 0, 'Arcane Sentinel', '', `s`.`IconName`, `s`.`gossip_menu_id`, 74, 75, `s`.`exp`,
    `s`.`faction`, `s`.`npcflag`, `s`.`speed_walk`, `s`.`speed_run`, `s`.`speed_swim`, `s`.`speed_flight`,
    `s`.`detection_range`, `s`.`rank`, `s`.`dmgschool`, `s`.`DamageModifier`, `s`.`BaseAttackTime`,
    `s`.`RangeAttackTime`, `s`.`BaseVariance`, `s`.`RangeVariance`, `s`.`unit_class`, `s`.`unit_flags`,
    `s`.`unit_flags2`, `s`.`dynamicflags`, `s`.`family`, `s`.`type`, `s`.`type_flags`, `d`.`lootid`,
    `d`.`pickpocketloot`, `d`.`skinloot`, `s`.`PetSpellDataId`, `s`.`VehicleId`, `d`.`mingold`, `d`.`maxgold`,
    `s`.`AIName`, `s`.`MovementType`, `s`.`HoverHeight`, `s`.`HealthModifier`, `s`.`ManaModifier`,
    `s`.`ArmorModifier`, `s`.`ExperienceModifier`, `s`.`RacialLeader`, `s`.`movementId`, `s`.`RegenHealth`,
    `s`.`CreatureImmunitiesId`, `s`.`flags_extra`, '', 0
FROM `creature_template` AS `s` JOIN `creature_template` AS `d` ON `d`.`entry` = 29724 WHERE `s`.`entry` = 29724;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 300095;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT 300095, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`
FROM `creature_template_model` WHERE `CreatureID` = 29724;
DELETE FROM `creature_equip_template` WHERE `CreatureID` = 300095;
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT 300095, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`
FROM `creature_equip_template` WHERE `CreatureID` = 29724;
DELETE FROM `creature_template_addon` WHERE `entry` = 300095;
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT 300095, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`
FROM `creature_template_addon` WHERE `entry` = 29724;
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 300095;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT 300095, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`,
    `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
    `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`,
    `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
    `target_x`, `target_y`, `target_z`, `target_o`, `comment`
FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 29724 AND `id` IN (1);

DELETE FROM `creature_template` WHERE `entry` = 300096;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 300096, 0, 0, 0, 0, 0, `s`.`name`, `s`.`subname`, `s`.`IconName`, `s`.`gossip_menu_id`, 57, 57,
    `s`.`exp`, `s`.`faction`, `s`.`npcflag`, `s`.`speed_walk`, `s`.`speed_run`, `s`.`speed_swim`,
    `s`.`speed_flight`, `s`.`detection_range`, `s`.`rank`, `s`.`dmgschool`, `s`.`DamageModifier`,
    `s`.`BaseAttackTime`, `s`.`RangeAttackTime`, `s`.`BaseVariance`, `s`.`RangeVariance`, `s`.`unit_class`,
    `s`.`unit_flags`, `s`.`unit_flags2`, `s`.`dynamicflags`, `s`.`family`, `s`.`type`, `s`.`type_flags`,
    `d`.`lootid`, `d`.`pickpocketloot`, `d`.`skinloot`, `s`.`PetSpellDataId`, `s`.`VehicleId`, `d`.`mingold`,
    `d`.`maxgold`, 'SmartAI', `s`.`MovementType`, `s`.`HoverHeight`, `s`.`HealthModifier`, `s`.`ManaModifier`,
    `s`.`ArmorModifier`, `s`.`ExperienceModifier`, `s`.`RacialLeader`, `s`.`movementId`, `s`.`RegenHealth`,
    `s`.`CreatureImmunitiesId`, `s`.`flags_extra`, '', 0
FROM `creature_template` AS `s` JOIN `creature_template` AS `d` ON `d`.`entry` = 9033 WHERE `s`.`entry` = 9033;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 300096;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT 300096, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`
FROM `creature_template_model` WHERE `CreatureID` = 9033;
DELETE FROM `creature_equip_template` WHERE `CreatureID` = 300096;
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT 300096, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`
FROM `creature_equip_template` WHERE `CreatureID` = 9033;
DELETE FROM `creature_template_addon` WHERE `entry` = 300096;
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT 300096, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`
FROM `creature_template_addon` WHERE `entry` = 9033;
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 300096;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(300096, 0, 0, 0, 0, 0, 100, 0, 8000, 8000, 18000, 18000, 0, 0, 11, 14099, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'General Angerforge (crater) - In Combat - Cast Mighty Blow'),
(300096, 0, 1, 0, 0, 0, 100, 0, 12000, 12000, 15000, 15000, 0, 0, 11, 9080, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'General Angerforge (crater) - In Combat - Cast Hamstring'),
(300096, 0, 2, 0, 0, 0, 100, 0, 16000, 16000, 9000, 9000, 0, 0, 11, 20691, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'General Angerforge (crater) - In Combat - Cast Cleave');

-- 2b. Every Spirestone kind counts for 300931 (KillCredit1 -> Spirestone Mystic 9198)
UPDATE `creature_template` SET `KillCredit1` = 9198 WHERE `entry` IN (9200, 9217, 9219) AND `KillCredit1` = 0;

-- 2c. Spawns
DELETE FROM `creature` WHERE `guid` BETWEEN 9002401 AND 9002499 AND `id` IN (9198, 9200, 11489, 26455, 31155, 31691, 300092, 300093, 300094, 300095, 300096) AND `map` = 37;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(9002401, 9198, 37, 0, 0, 1, 1, 1, 192.09, -415.56, 247.66, 5.4820, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300931 Spirestone Menace'),
(9002402, 9198, 37, 0, 0, 1, 1, 1, 183.71, -406.89, 248.54, 1.5988, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300931 Spirestone Menace'),
(9002403, 9198, 37, 0, 0, 1, 1, 1, 195.08, -429.11, 248.63, 3.9988, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300931 Spirestone Menace'),
(9002404, 9198, 37, 0, 0, 1, 1, 1, 178.71, -421.00, 250.06, 0.1156, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300931 Spirestone Menace'),
(9002405, 9198, 37, 0, 0, 1, 1, 1, 185.41, -435.39, 251.12, 2.5155, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300931 Spirestone Menace'),
(9002406, 9200, 37, 0, 0, 1, 1, 1, 197.96, -440.18, 250.50, 4.9155, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300931 Spirestone Menace'),
(9002407, 9200, 37, 0, 0, 1, 1, 1, 166.93, -420.44, 250.32, 1.0323, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300931 Spirestone Menace'),
(9002408, 9200, 37, 0, 0, 1, 1, 1, 173.52, -434.13, 252.01, 3.4322, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300931 Spirestone Menace'),
(9002409, 9200, 37, 0, 0, 1, 1, 1, 208.86, -388.48, 249.79, 5.8322, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300931 Spirestone Menace'),
(9002410, 300096, 37, 0, 0, 1, 1, 1, 248.44, -374.58, 257.43, 1.9490, 600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300934 The Dark Iron General'),
(9002411, 300092, 37, 0, 0, 1, 1, 0, 924.27, 428.00, 263.90, 4.3489, 600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300512 Grim Wanderers'),
(9002412, 11489, 37, 0, 0, 1, 1, 0, 939.33, 515.07, 221.14, 0.4657, 600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300512 Grim Wanderers'),
(9002413, 31691, 37, 0, 0, 1, 1, 0, -472.44, 4.00, 314.94, 2.8657, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300962 The Forgotten Ones'),
(9002414, 31691, 37, 0, 0, 1, 1, 0, -471.38, -7.73, 314.06, 5.2656, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300962 The Forgotten Ones'),
(9002415, 31691, 37, 0, 0, 1, 1, 0, -452.72, 3.03, 313.88, 1.3824, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300962 The Forgotten Ones'),
(9002416, 31691, 37, 0, 0, 1, 1, 0, -471.79, 16.36, 318.68, 3.7824, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300962 The Forgotten Ones'),
(9002417, 31691, 37, 0, 0, 1, 1, 0, -483.87, 0.71, 316.72, 6.1823, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300962 The Forgotten Ones'),
(9002418, 31691, 37, 0, 0, 1, 1, 0, -460.60, -20.91, 310.06, 2.2991, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300962 The Forgotten Ones'),
(9002419, 31691, 37, 0, 0, 1, 1, 0, -481.08, -15.56, 317.71, 4.6991, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300962 The Forgotten Ones'),
(9002420, 300095, 37, 0, 0, 1, 1, 1, -571.73, -130.86, 330.41, 0.8159, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300963 Arcane Sentinels'),
(9002421, 300095, 37, 0, 0, 1, 1, 1, -531.31, -169.42, 338.69, 3.2158, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300963 Arcane Sentinels'),
(9002422, 300095, 37, 0, 0, 1, 1, 1, -530.93, -173.87, 321.89, 5.6158, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300963 Arcane Sentinels'),
(9002423, 300095, 37, 0, 0, 1, 1, 1, -584.80, -131.02, 334.59, 1.7326, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300963 Arcane Sentinels'),
(9002424, 300095, 37, 0, 0, 1, 1, 1, -520.21, -162.34, 338.42, 4.1325, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300963 Arcane Sentinels'),
(9002425, 300095, 37, 0, 0, 1, 1, 1, -512.18, -155.91, 337.26, 0.2493, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300963 Arcane Sentinels'),
(9002426, 300095, 37, 0, 0, 1, 1, 1, -518.58, -180.27, 317.35, 2.6493, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300963 Arcane Sentinels'),
(9002427, 300095, 37, 0, 0, 1, 1, 1, -505.54, -147.93, 336.55, 5.0492, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300963 Arcane Sentinels'),
(9002428, 300095, 37, 0, 0, 1, 1, 1, -495.13, -147.77, 333.80, 1.1660, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300963 Arcane Sentinels'),
(9002429, 300095, 37, 0, 0, 1, 1, 1, -538.40, -209.87, 319.83, 3.5660, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300963 Arcane Sentinels'),
(9002430, 300095, 37, 0, 0, 1, 1, 1, -505.61, -110.83, 317.44, 5.9659, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300963 Arcane Sentinels'),
(9002431, 300095, 37, 0, 0, 1, 1, 1, -520.83, -91.68, 320.29, 2.0827, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300963 Arcane Sentinels'),
(9002432, 300094, 37, 0, 0, 1, 1, 0, -379.72, -145.31, 297.35, 4.4827, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002433, 300094, 37, 0, 0, 1, 1, 0, -379.74, -156.45, 296.91, 0.5994, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002434, 300094, 37, 0, 0, 1, 1, 0, -391.12, -159.76, 299.57, 2.9994, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002435, 300094, 37, 0, 0, 1, 1, 0, -389.68, -139.38, 297.26, 5.3994, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002436, 300094, 37, 0, 0, 1, 1, 0, -371.20, -150.76, 297.35, 1.5162, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002437, 300094, 37, 0, 0, 1, 1, 0, -399.88, -143.64, 300.29, 3.9161, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002438, 300094, 37, 0, 0, 1, 1, 0, -400.89, -157.52, 301.35, 0.0329, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002439, 300094, 37, 0, 0, 1, 1, 0, -385.19, -168.21, 298.15, 2.4329, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002440, 300094, 37, 0, 0, 1, 1, 0, -397.61, -132.84, 298.60, 4.8328, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002441, 300094, 37, 0, 0, 1, 1, 0, -376.41, -129.42, 297.26, 0.9496, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002442, 300094, 37, 0, 0, 1, 1, 0, -364.09, -157.87, 297.26, 3.3496, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002443, 300094, 37, 0, 0, 1, 1, 0, -395.95, -169.96, 299.66, 5.7495, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002444, 300094, 37, 0, 0, 1, 1, 0, -387.78, -125.16, 296.82, 1.8663, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002445, 300094, 37, 0, 0, 1, 1, 0, -411.53, -153.24, 302.15, 4.2663, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964/300965 Darkmender''s Ghouls'),
(9002446, 31155, 37, 0, 0, 1, 1, 0, -408.25, -145.80, 301.26, 0.3830, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964 Scourge Infestation'),
(9002447, 31155, 37, 0, 0, 1, 1, 0, -405.03, -164.39, 300.73, 2.7830, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964 Scourge Infestation'),
(9002448, 31155, 37, 0, 0, 1, 1, 0, -391.11, -178.48, 297.97, 5.1830, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964 Scourge Infestation'),
(9002449, 31155, 37, 0, 0, 1, 1, 0, -381.07, -119.29, 297.35, 1.2997, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300964 Scourge Infestation'),
(9002450, 26455, 37, 0, 0, 1, 1, 0, -628.00, -221.95, 354.14, 3.6997, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300965 Highborne Spirits'),
(9002451, 26455, 37, 0, 0, 1, 1, 0, -638.58, -217.49, 354.41, 6.0997, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300965 Highborne Spirits'),
(9002452, 26455, 37, 0, 0, 1, 1, 0, -575.38, -183.73, 353.97, 2.2164, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300965 Highborne Spirits'),
(9002453, 26455, 37, 0, 0, 1, 1, 0, -619.02, -233.07, 352.37, 4.6164, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300965 Highborne Spirits'),
(9002454, 26455, 37, 0, 0, 1, 1, 0, -648.80, -211.91, 355.03, 0.7332, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300965 Highborne Spirits'),
(9002455, 26455, 37, 0, 0, 1, 1, 0, -613.72, -151.56, 356.81, 3.1332, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300965 Highborne Spirits'),
(9002456, 26455, 37, 0, 0, 1, 1, 0, -640.09, -229.51, 352.54, 5.5331, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300965 Highborne Spirits'),
(9002457, 26455, 37, 0, 0, 1, 1, 0, -563.20, -196.28, 353.17, 1.6499, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300965 Highborne Spirits'),
(9002458, 26455, 37, 0, 0, 1, 1, 0, -632.28, -236.36, 351.12, 4.0499, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300965 Highborne Spirits'),
(9002459, 26455, 37, 0, 0, 1, 1, 0, -648.72, -223.29, 353.52, 0.1666, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300965 Highborne Spirits'),
(9002460, 300093, 37, 0, 0, 1, 1, 0, -654.22, -184.53, 355.30, 2.5666, 600, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Azshara Crater 300966 Lady Nightswood');

-- 2d. Quest targets (guarded: only while the old target is set)
-- 300512 Grim Wanderers
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 300092
WHERE `ID` = 300512 AND `RequiredNpcOrGo1` = 10393;
-- 300931 Spirestone Menace
UPDATE `quest_template` SET
    `RequiredNpcOrGo2` = 0,
    `RequiredNpcOrGoCount2` = 0,
    `RequiredNpcOrGo3` = 0,
    `RequiredNpcOrGoCount3` = 0,
    `ObjectiveText1` = 'Spirestone ogres slain',
    `LogDescription` = 'Slay 10 Spirestone ogres: Mystics, Reavers, Lords or Butchers.'
WHERE `ID` = 300931 AND `RequiredNpcOrGo2` = 9217;
-- 300934 The Dark Iron General
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 300096
WHERE `ID` = 300934 AND `RequiredNpcOrGo1` = 9033;
-- 300962 The Forgotten Ones
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 31691,
    `LogDescription` = 'Slay 10 Faceless Lurkers.',
    `QuestDescription` = 'Beware the deep places of this Sanctum, mortal. Where arcane power pools untended, older and hungrier things take shape. The Forgotten Ones, faceless lurkers born of a madness that has no name in your tongue, slither through the shadows here.$B$BThey must not be left to grow. Cleanse ten of the Faceless Lurkers from this sacred ground before their whispers take root.'
WHERE `ID` = 300962 AND `RequiredNpcOrGo1` = 27959;
-- 300963 Arcane Sentinels
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 300095
WHERE `ID` = 300963 AND `RequiredNpcOrGo1` = 15689;
-- 300964 Scourge Infestation
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 300094,
    `RequiredNpcOrGo2` = 31155,
    `LogDescription` = 'Slay 12 Darkmender''s Ghouls and 8 Malefic Necromancers.',
    `QuestDescription` = 'The Scourge do not relent, mortal. Where their shaman fell, more of the plague pours in behind. Darkmender''s Ghouls shamble through the outer halls, driven on by Malefic Necromancers who raise them faster than they can be cut down.$B$BThis tide must be broken here, or it will drown the Sanctum entirely. Destroy twelve of Darkmender''s Ghouls and eight of the Malefic Necromancers who command them.'
WHERE `ID` = 300964 AND `RequiredNpcOrGo1` = 29517 AND `RequiredNpcOrGo2` = 29518;
-- 300965 Highborne Spirits
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 300094,
    `LogDescription` = 'Slay 10 Darkmender''s Ghouls and 8 Moonrest Highborne.',
    `QuestDescription` = 'Listen, mortal. The wailing you hear is grief ten thousand years old. The Moonrest Highborne are bound spirits, chained to this place by the pride that drowned their city, and the ghouls of Setaal Darkmender stand guard over their chains.$B$BIt is a mercy, not a slaughter, that I ask of you. Destroy ten of the Darkmender''s Ghouls and release eight of the Moonrest Highborne, and let these ancient sinners find the peace they were so long denied.'
WHERE `ID` = 300965 AND `RequiredNpcOrGo1` = 29519;
-- 300966 Lady Nightswood
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 300093
WHERE `ID` = 300966 AND `RequiredNpcOrGo1` = 29770;

-- 2e. Map markers (WorldMapAreaId 613; objective = camp +/- 20 yd, turn-in = Image of Arcanigos)
DELETE FROM `quest_poi` WHERE `QuestID` = 300931 AND `id` IN (1, 2);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300931 AND `Idx1` IN (1, 2);
DELETE FROM `quest_poi` WHERE `QuestID` = 300512 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300512, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300512 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300512, 0, 0, 904, 408, 0),
(300512, 0, 1, 904, 448, 0),
(300512, 0, 2, 945, 448, 0),
(300512, 0, 3, 945, 408, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300512 AND `id` = 1;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300512, 1, 1, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300512 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300512, 1, 0, 919, 495, 0),
(300512, 1, 1, 919, 536, 0),
(300512, 1, 2, 960, 536, 0),
(300512, 1, 3, 960, 495, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300931 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300931, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300931 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300931, 0, 0, 146, -470, 0),
(300931, 0, 1, 146, -361, 0),
(300931, 0, 2, 229, -361, 0),
(300931, 0, 3, 229, -470, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300934 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300934, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300934 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300934, 0, 0, 228, -395, 0),
(300934, 0, 1, 228, -354, 0),
(300934, 0, 2, 269, -354, 0),
(300934, 0, 3, 269, -395, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300962 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300962, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300962 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300962, 0, 0, -517, -41, 0),
(300962, 0, 1, -517, 37, 0),
(300962, 0, 2, -416, 37, 0),
(300962, 0, 3, -416, -41, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300963 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300963, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300963 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300963, 0, 0, -605, -230, 0),
(300963, 0, 1, -605, -71, 0),
(300963, 0, 2, -475, -71, 0),
(300963, 0, 3, -475, -230, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300964 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300964, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300964 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300964, 0, 0, -432, -190, 0),
(300964, 0, 1, -432, -105, 0),
(300964, 0, 2, -344, -105, 0),
(300964, 0, 3, -344, -190, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300964 AND `id` = 1;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300964, 1, 1, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300964 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300964, 1, 0, -429, -199, 0),
(300964, 1, 1, -429, -99, 0),
(300964, 1, 2, -332, -99, 0),
(300964, 1, 3, -332, -199, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300965 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300965, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300965 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300965, 0, 0, -432, -190, 0),
(300965, 0, 1, -432, -105, 0),
(300965, 0, 2, -344, -105, 0),
(300965, 0, 3, -344, -190, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300965 AND `id` = 1;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300965, 1, 1, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300965 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300965, 1, 0, -669, -257, 0),
(300965, 1, 1, -669, -131, 0),
(300965, 1, 2, -534, -131, 0),
(300965, 1, 3, -534, -257, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300966 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300966, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300966 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300966, 0, 0, -675, -205, 0),
(300966, 0, 1, -675, -164, 0),
(300966, 0, 2, -634, -164, 0),
(300966, 0, 3, -634, -205, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300962 AND `id` = 3;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300962, 3, -1, 37, 613, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300962 AND `Idx1` = 3;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300962, 3, 0, -81, -15, 0),
(300962, 3, 1, -81, 25, 0),
(300962, 3, 2, -40, 25, 0),
(300962, 3, 3, -40, -15, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300963 AND `id` = 3;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300963, 3, -1, 37, 613, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300963 AND `Idx1` = 3;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300963, 3, 0, -81, -15, 0),
(300963, 3, 1, -81, 25, 0),
(300963, 3, 2, -40, 25, 0),
(300963, 3, 3, -40, -15, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300964 AND `id` = 3;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300964, 3, -1, 37, 613, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300964 AND `Idx1` = 3;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300964, 3, 0, -81, -15, 0),
(300964, 3, 1, -81, 25, 0),
(300964, 3, 2, -40, 25, 0),
(300964, 3, 3, -40, -15, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300965 AND `id` = 3;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300965, 3, -1, 37, 613, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300965 AND `Idx1` = 3;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300965, 3, 0, -81, -15, 0),
(300965, 3, 1, -81, 25, 0),
(300965, 3, 2, -40, 25, 0),
(300965, 3, 3, -40, -15, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300966 AND `id` = 3;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300966, 3, -1, 37, 613, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300966 AND `Idx1` = 3;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300966, 3, 0, -81, -15, 0),
(300966, 3, 1, -81, 25, 0),
(300966, 3, 2, -40, 25, 0),
(300966, 3, 3, -40, -15, 0);
