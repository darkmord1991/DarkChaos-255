-- Giant Water Monster Event SQL

-- NPC: Giant Water Monster (Boss)
DELETE FROM `creature_template` WHERE (`entry` = 400350);
-- Boss display scale (3.0) is set in creature_template_model.DisplayScale below.
-- Column list matches this core's creature_template schema: no scale/trainer_*/
-- *_immune_mask columns (immunities use CreatureImmunitiesId instead).
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(400350, 0, 0, 0, 0, 0, 'Ancient Terror', 'Giant Isles Boss', '', 0, 83, 83, 2, 14, 0, 1, 1.14286, 1, 1, 20, 3, 0, 5, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 100, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_giant_water_monster', 0);

-- NPC: Corrupted Water Elemental (Add)
DELETE FROM `creature_template` WHERE `entry` = 400351;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(400351, 0, 0, 0, 0, 0, 'Corrupted Elemental', 'Minion of the Deep', '', 0, 81, 81, 0, 14, 0, 1, 1.14286, 1, 1, 20, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 10, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_corrupted_elemental', 0);

-- GameObject: Ancient Stone
DELETE FROM `gameobject_template` WHERE `entry` = 700015;
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`) VALUES
(700015, 2, 7789, 'Ancient Stone', '', '', '', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'go_ancient_stone', 0);

-- Creature Models
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (400350, 400351);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400350, 0, 29487, 3, 1, 0), -- Ancient Terror (Water/Ground) - DisplayScale 3.0 (boss size)
(400351, 0, 17203, 1.0, 1, 0); -- Corrupted Elemental

-- Creature Movement (InhabitType)
DELETE FROM `creature_template_movement` WHERE `CreatureId` IN (400350, 400351);
INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`) VALUES
(400350, 1, 1, 0, 0), -- Ancient Terror (Water/Ground)
(400351, 1, 1, 0, 0); -- Corrupted Elemental (Water/Ground)
