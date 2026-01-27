-- Dalaran Guildhouse Teleporter Guard
DELETE FROM `creature_template` WHERE `entry` = 800030;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
	(800030, 0, 0, 0, 0, 0, 'Guild House Teleporter Guard', 'Dalaran Guildhouse', 'Teleport', 0, 255, 255, 0, 35, 1, 1, 1.42857, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 7, 0, 0, 4624, 0, 0, 0, 0, 0, 'GuardAI', 0, 1, 2, 1, 1, 1, 0, 144, 1, 0, 0, 65536, 'DalaranGuardNPC', 12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` = 800030;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
	(800030, 0, 3711, 1, 1, 12340),
	(800030, 1, 11474, 1, 1, 12340);
