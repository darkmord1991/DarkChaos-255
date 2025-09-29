-- new Gadgetzan Bruiser
DELETE FROM `creature_template` WHERE (`entry` = 800000);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `modelid1`, `modelid2`, `modelid3`, `modelid4`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800000, 0, 0, 0, 0, 0, 11375, 11376, 11377, 0, 'Gadgetzan Bruiser', 'DC-WoW', NULL, 62000, 255, 255, 1, 475, 1, 1.2, 1.42857, 1, 1, 18, 1, 0, 0, 10, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 9460, 0, 0, 0, 0, 0, 'SmartAI', 1, 1, 20, 1, 10, 1, 0, 144, 1, 0, 0, 98304, '', 12340);

-- Ashzara Bruiser 
DELETE FROM `creature_template` WHERE `entry`=800003;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (800003, 0, 0, 0, 0, 0, 'Ashzara Bruiser', 'DC-WoW', 'Directions', 0, 255, 255, 0, 121, 1, 1, 1.42857, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 4624, 0, 0, 0, 0, 0, 'GuardAI', 0, 1, 2, 1, 1, 1, 0, 144, 1, 0, 0, 65536, 'AC_Guard_NPC', 12340);

-- creature texts for guards, still do not work :/
DELETE FROM `creature_text` WHERE (`CreatureID` = 800003);
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(800003, 0, 0, 'Were here to protect all interests in Crater of Ashzara and thats none of your business.', 12, 0, 0, 1, 0, 0, 0, 0, ''),
(800003, 0, 1, 'Good morning! Were here to protect all interests in Crater of Ashzara and thats a lot of work.', 12, 0, 0, 0, 0, 0, 0, 0, '');

-- Ashzara Crater Inkeeper
-- Standard goods + bigger scale
DELETE FROM `creature_template` WHERE (`entry` = 800001);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `modelid1`, `modelid2`, `modelid3`, `modelid4`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (800001, 0, 0, 0, 0, 0, 7346, 0, 0, 0, 'Innkeeper Fizzgrimble', 'Innkeeper', NULL, 2890, 80, 80, 0, 474, 66179, 1, 1.14286, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 4096, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1.05, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_innkeeper', 12340);

DELETE FROM `npc_vendor` WHERE (`entry` = 800001);
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`) VALUES
(800001, 0, 117, 0, 0, 0, 0),
(800001, 0, 159, 0, 0, 0, 0),
(800001, 0, 1179, 0, 0, 0, 0),
(800001, 0, 1205, 0, 0, 0, 0),
(800001, 0, 1645, 0, 0, 0, 0),
(800001, 0, 1708, 0, 0, 0, 0),
(800001, 0, 2287, 0, 0, 0, 0),
(800001, 0, 3770, 0, 0, 0, 0),
(800001, 0, 3771, 0, 0, 0, 0),
(800001, 0, 4599, 0, 0, 0, 0),
(800001, 0, 8766, 0, 0, 0, 0),
(800001, 0, 8952, 0, 0, 0, 0),
(800001, 0, 18046, 0, 0, 0, 0);

-- Teleporter
-- Lua Script with table in DB
DELETE FROM `creature_template` WHERE (`entry` = 800002);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `modelid1`, `modelid2`, `modelid3`, `modelid4`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (800002, 0, 0, 0, 0, 0, 11375, 11376, 11377, 0, 'Teleporter', NULL, NULL, 7956, 83, 83, 1, 475, 1, 1, 1.42857, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 9460, 0, 0, 0, 0, 0, 'SmartAI', 1, 1, 2, 1, 1, 1, 0, 144, 1, 0, 0, 98304, '', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800002);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800002, 0, 11375, 2, 2, 12340),
(800002, 1, 11376, 2, 2, 12340),
(800002, 2, 11377, 2, 2, 12340);

update creature_template set maxlevel = 255 where entry = 800000;
update creature_template set maxlevel = 255 where entry = 800001;
update creature_template set maxlevel = 255 where entry = 800002;
update creature_template set maxlevel = 255 where entry = 800003;

update creature_template set minlevel = 255 where entry = 800000;
update creature_template set minlevel = 255 where entry = 800001;
update creature_template set minlevel = 255 where entry = 800002;
update creature_template set minlevel = 255 where entry = 800003;

-- Try to have a fly protection or flying guards
-- did not work out yet
DELETE FROM `creature_template` WHERE (`entry` = 800004);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `modelid1`, `modelid2`, `modelid3`, `modelid4`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800004, 0, 0, 0, 0, 0, 20117, 20118, 16317, 16318, 'Ashzara Wyvern Rider', NULL, NULL, 0, 255, 255, 1, 475, 0, 1, 2.28571, 1, 2, 100, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 4096, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'GuardAI', 1, 50, 3, 1, 1, 1, 0, 0, 1, 0, 0, 32770, '', 12340);

DELETE FROM `creature_template_addon` WHERE (`entry` = 800004);
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`) VALUES
(800004, 0, 0, 54432, 0, 0, 0, '');

UPDATE `creature_template` SET `subname` = 'DC-WoW' WHERE (`entry` = 800003);
UPDATE `creature_template` SET `subname` = 'DC-WoW' WHERE (`entry` = 800000);
UPDATE `creature_template` SET `subname` = 'DC-WoW' WHERE (`entry` = 800002);

UPDATE `creature_template` SET `scale` = 2.5 WHERE (`entry` = 800001);

-- Welcome + Start Quests with this NPC
-- more to come
DELETE FROM `creature_template` WHERE (`entry` = 800009);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800009, 0, 0, 0, 0, 0, 'Hervikus the Chaotic', 'Starting Quests', '', 0, 255, 255, 2, 35, 3, 0.4, 0.4, 1, 1, 20, 1, 2, 0, 7.5, 2000, 2000, 1, 1, 1, 32832, 2048, 0, 0, 0, 0, 0, 0, 5, 8, 32487, 0, 0, 0, 0, 0, 0, '', 0, 1, 6, 1, 1, 1, 0, 58, 1, 0, 0, 0, 'AC_Quest_NPC_800009', 12340);

-- some standarad starting location vendors
UPDATE `creature_template` SET `faction` = 35 WHERE (`entry` = 2134);
UPDATE `creature_template` SET `faction` = 35 WHERE (`entry` = 2136);
UPDATE `creature_template` SET `faction` = 35 WHERE (`entry` = 2135);
UPDATE `creature_template` SET `faction` = 35 WHERE (`entry` = 10055);

-- butcher from crossroads
DELETE FROM `creature_template` WHERE (`entry` = 3489);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(3489, 0, 0, 0, 0, 0, 'Zargh', 'Butcher', NULL, 4341, 16, 16, 0, 35, 643, 1, 1.14286, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 0, 0, 0, 0, 7, 134217728, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 2, '', 12340);

-- flightmaster startcamp
DELETE FROM `creature_template` WHERE (`entry` = 800010);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800010, 0, 0, 0, 0, 0, 'Ashzara Flightmaster', 'Startcamp', 'Directions', 0, 255, 255, 0, 121, 1, 1, 1.42857, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 4624, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 144, 1, 0, 0, 65536, 'ACFM1', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800010);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800010, 0, 7102, 1, 1, 12340),
(800010, 1, 7103, 1, 1, 12340),
(800010, 2, 7104, 1, 1, 12340);

-- 28614 Gryphon vehicle
-- new ID 800011
DELETE FROM `creature_template` WHERE (`entry` = 800011);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800011, 0, 0, 0, 0, 0, 'Scarlet Gryphon', 'AC flying gryphon', '', 0, 53, 54, 0, 2089, 0, 1, 3.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 124, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 236, 1, 0, 0, 0, 'ac_gryphon_taxi_800011', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800011);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800011, 0, 25579, 1, 1, 12340);

INSERT INTO creature_template_movement (CreatureId, Ground, Swim, Flight, Rooted, Chase, Random)
VALUES (800011, 0, 0, 1, 0, 0, 0);

-- flightmaster 25+
DELETE FROM `creature_template` WHERE (`entry` = 800012);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800012, 0, 0, 0, 0, 0, 'Ashzara Flightmaster', 'Level 25+', 'Directions', 0, 255, 255, 0, 121, 1, 1, 1.42857, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 4624, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 144, 1, 0, 0, 65536, 'ACFM1', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800012);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800012, 0, 7102, 1, 1, 12340),
(800012, 1, 7103, 1, 1, 12340),
(800012, 2, 7104, 1, 1, 12340);

-- flightmaster 40+
DELETE FROM `creature_template` WHERE (`entry` = 800013);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800013, 0, 0, 0, 0, 0, 'Ashzara Flightmaster', 'Level 40+', 'Directions', 0, 255, 255, 0, 121, 1, 1, 1.42857, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 4624, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 144, 1, 0, 0, 65536, 'ACFM1', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800013);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800013, 0, 7102, 1, 1, 12340),
(800013, 1, 7103, 1, 1, 12340),
(800013, 2, 7104, 1, 1, 12340);

-- flightmaster 60+
DELETE FROM `creature_template` WHERE (`entry` = 800014);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(800014, 0, 0, 0, 0, 0, 'Ashzara Flightmaster', 'Level 60+', 'Directions', 0, 255, 255, 0, 121, 1, 1, 1.42857, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 4624, 0, 0, 0, 0, 0, '', 0, 1, 2, 1, 1, 1, 0, 144, 1, 0, 0, 65536, 'ACFM1', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 800014);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(800014, 0, 7102, 1, 1, 12340),
(800014, 1, 7103, 1, 1, 12340),
(800014, 2, 7104, 1, 1, 12340);