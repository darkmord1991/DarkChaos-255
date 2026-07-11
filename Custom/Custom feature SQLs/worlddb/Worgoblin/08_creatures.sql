-- Worgoblin: display metadata + racial creatures (Gobber pet, trike/horse mounts)
-- creature_template columns adapted to the DC schema (scale -> creature_template_model.DisplayScale,
-- trainer_*/mechanic masks dropped, CreatureImmunitiesId added).
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (29422, 29423, 33000, 33001, 32385, 35249, 35250, 36445, 36446, 39095, 39096);
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`) VALUES
(29422, 0.406, 1.5, 0, 0),
(29423, 0.406, 1.5, 1, 0),
(32385, 0.2325, 1.5, 0, 0),
(35249, 0.35, 1.5, 2, 0),
(35250, 0.35, 1.5, 2, 0),
(36445, 0.406, 1.5, 0, 0),
(36446, 0.306, 1.5, 0, 0),
(39095, 1, 1.5, 2, 0),
(39096, 1, 1.5, 2, 0);

DELETE FROM `creature_template` WHERE `entry` IN (36613, 46754, 46755, 55272, 55273);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(36613, 0, 0, 0, 0, 0, 'Gobber', '', NULL, 0, 55, 55, 0, 120, 131072, 1, 1.14286, 1, 1, 18, 0, 0, 1, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 2, '', 12340),
(46754, 0, 0, 0, 0, 0, 'Goblin Trike', NULL, NULL, 0, 20, 20, 0, 35, 0, 1, 1.38571, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 33554432, 2048, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 140, 1, 0, 0, '', 0),
(46755, 0, 0, 0, 0, 0, 'Goblin Turbo-Trike', NULL, NULL, 0, 40, 40, 0, 35, 0, 1, 1.38571, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 33554432, 2048, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 140, 1, 0, 0, '', 0),
(55272, 0, 0, 0, 0, 0, 'Mountain Horse', NULL, NULL, 0, 20, 20, 0, 35, 0, 1, 1.38571, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 140, 1, 0, 0, '', 0),
(55273, 0, 0, 0, 0, 0, 'Swift Mountain Horse', NULL, NULL, 0, 40, 40, 0, 35, 0, 1, 1.38571, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 140, 1, 0, 0, '', 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (36613, 46754, 46755, 55272, 55273);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(36613, 0, 32385, 1, 1, 12340),
(46754, 0, 35249, 1, 1, 12340),
(46755, 0, 35250, 1, 1, 12340),
(55272, 0, 39096, 1, 1, 12340),
(55273, 0, 39095, 1, 1, 12340);
