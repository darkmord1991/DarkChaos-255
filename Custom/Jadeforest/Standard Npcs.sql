-- Jadeforest Inkeeper
-- Standard goods + bigger scale
DELETE FROM `creature_template` WHERE (`entry` = 800020);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800020, 0, 0, 0, 0, 0, 'Innkeeper Pandgrimble', 'Innkeeper', NULL, 2890, 255, 255, 0, 474, 66179, 1, 1.14286, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 4096, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1.05, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_innkeeper', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800020);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800020, 0, 30414, 2.5, 1, 12340);

DELETE FROM `npc_vendor` WHERE (`entry` = 800020);
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`) VALUES
(800020, 0, 117, 0, 0, 0, 0),
(800020, 0, 159, 0, 0, 0, 0),
(800020, 0, 1179, 0, 0, 0, 0),
(800020, 0, 1205, 0, 0, 0, 0),
(800020, 0, 1645, 0, 0, 0, 0),
(800020, 0, 1708, 0, 0, 0, 0),
(800020, 0, 2287, 0, 0, 0, 0),
(800020, 0, 3770, 0, 0, 0, 0),
(800020, 0, 3771, 0, 0, 0, 0),
(800020, 0, 4599, 0, 0, 0, 0),
(800020, 0, 8766, 0, 0, 0, 0),
(800020, 0, 8952, 0, 0, 0, 0),
(800020, 0, 18046, 0, 0, 0, 0);

-- Panda Bruiser, Guard
DELETE FROM `creature_template` WHERE (`entry` = 800021);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800021, 0, 0, 0, 0, 0, 'Panda Bruiser', 'DC-WoW', NULL, 60000, 255, 255, 1, 475, 1, 1.2, 1.42857, 1, 1, 18, 1, 0, 0, 10, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 1, 1, 20, 1, 10, 1, 0, 144, 1, 0, 0, 98304, 'jadeforest_guard', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800021) AND (`Idx` IN (0));
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800021, 0, 30414, 2, 1, 12340);

-- Add gossip menu entry
DELETE FROM `gossip_menu` WHERE `MenuID` = 60000;
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES (60000, 160000);

DELETE FROM `npc_text` WHERE `ID` = 160000;
INSERT INTO `npc_text` (`ID`, `text0_0`) VALUES (160000, 'Greetings, $N!');

-- flightmaster Jadeforest
DELETE FROM `creature_template` WHERE (`entry` = 800022);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800022, 0, 0, 0, 0, 0, 'Flightmaster', 'Jadeforest 1', 'Directions', 0, 255, 255, 0, 121, 1, 1, 1.42857, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 4624, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 144, 1, 0, 0, 65536, 'jadeforest_flightmaster', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800022);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800022, 0, 7102, 1, 1, 12340),
(800022, 1, 7103, 1, 1, 12340),
(800022, 2, 7104, 1, 1, 12340);

-- 28614 Gryphon vehicle
-- new ID 800023
DELETE FROM `creature_template` WHERE (`entry` = 800023);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800023, 0, 0, 0, 0, 0, 'Scarlet Gryphon', 'JF flying gryphon', '', 0, 53, 54, 0, 2089, 0, 1, 3.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 124, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 236, 1, 0, 0, 0, 'ac_gryphon_taxi_800023', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800023);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800023, 0, 25579, 1, 1, 12340);

INSERT INTO creature_template_movement (CreatureId, Ground, Swim, Flight, Rooted, Chase, Random)
VALUES (800023, 0, 0, 1, 0, 0, 0);

-- flightmaster Jadeforest 2
DELETE FROM `creature_template` WHERE (`entry` = 800022);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800024, 0, 0, 0, 0, 0, 'Flightmaster', 'Jadeforest 1', 'Directions', 0, 255, 255, 0, 121, 1, 1, 1.42857, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 4624, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 144, 1, 0, 0, 65536, 'jadeforest_flightmaster', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800024);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800024, 0, 7102, 1, 1, 12340),
(800024, 1, 7103, 1, 1, 12340),
(800024, 2, 7104, 1, 1, 12340);

-- flightmaster Jadeforest 3
DELETE FROM `creature_template` WHERE (`entry` = 800022);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800025, 0, 0, 0, 0, 0, 'Flightmaster', 'Jadeforest 1', 'Directions', 0, 255, 255, 0, 121, 1, 1, 1.42857, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 4624, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 144, 1, 0, 0, 65536, 'jadeforest_flightmaster', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800025);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800025, 0, 7102, 1, 1, 12340),
(800025, 1, 7103, 1, 1, 12340),
(800025, 2, 7104, 1, 1, 12340);

-- flightmaster Jadeforest 4
DELETE FROM `creature_template` WHERE (`entry` = 800022);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800026, 0, 0, 0, 0, 0, 'Flightmaster', 'Jadeforest 1', 'Directions', 0, 255, 255, 0, 121, 1, 1, 1.42857, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 4624, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 144, 1, 0, 0, 65536, 'jadeforest_flightmaster', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800026);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800026, 0, 7102, 1, 1, 12340),
(800026, 1, 7103, 1, 1, 12340),
(800026, 2, 7104, 1, 1, 12340);

-- flightmaster Jadeforest 5
DELETE FROM `creature_template` WHERE (`entry` = 800022);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800027, 0, 0, 0, 0, 0, 'Flightmaster', 'Jadeforest 1', 'Directions', 0, 255, 255, 0, 121, 1, 1, 1.42857, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 4624, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 144, 1, 0, 0, 65536, 'jadeforest_flightmaster', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800027);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800027, 0, 7102, 1, 1, 12340),
(800027, 1, 7103, 1, 1, 12340),
(800027, 2, 7104, 1, 1, 12340);

