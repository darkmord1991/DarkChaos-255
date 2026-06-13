-- ============================================================================
-- GIANT ISLES - Invasion lane objective: longboat war standards (Phase 4)
-- ----------------------------------------------------------------------------
-- Each landing lane plants a Zandalari war standard when the assault begins
-- (see dc_giant_isles_invasion.cpp -> SpawnLaneStandards). Destroying a lane's
-- standard scuttles that longboat: the orchestrator stops feeding that lane's
-- reinforcements for the rest of the assault (and silences every lane once all
-- four are down). The standard is a passive, attackable banner the orchestrator
-- manages entirely (REACT_PASSIVE + DISABLE_MOVE set in C++), RegenHealth = 0
-- so damage sticks and the kill is a real objective.
--   400366 = Zandalari War Standard (Horde battle-standard banner display 14542)
-- ============================================================================

DELETE FROM `creature_template` WHERE `entry` IN (400366);
INSERT INTO `creature_template`
(`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(400366, 0, 0, 0, 0, 0, 'Zandalari War Standard', 'Longboat Mooring', '', 0, 81, 81, 2, 16, 0, 1, 1, 1, 1, 5, 0, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 35, 1, 2, 1, 0, 0, 0, 0, 0, '', 12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (400366);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400366, 0, 14542, 1, 1, 12340);  -- planted war-standard banner
