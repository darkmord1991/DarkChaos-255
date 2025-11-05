-- =====================================================================
-- DarkChaos Item Upgrade System - Transmutation NPC Database Fix
--
-- Creates the creature template for the ItemUpgradeTransmutationNPC script
-- that was missing from the database, causing the "script not assigned" error.
--
-- Author: DarkChaos Development Team
-- Date: November 5, 2025
-- =====================================================================

-- Transmutation Master NPC (ID: 190004) - Handles tier conversion, currency exchange, and synthesis
DELETE FROM `creature_template` WHERE `entry` = 190004;
INSERT INTO `creature_template`
(`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`,
 `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`,
 `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`,
 `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
 `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`,
 `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`,
 `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
 `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`,
 `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES
(190004, 0, 0, 0, 0, 0, 'Transmutation Master', 'Transform your upgraded items!', NULL, 0,
 63, 63, 2, 35, 1, 1, 1.14286, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0,
 7, 0, 0, 0, 0, 0, 0, 0, 0, 'PassiveAI', 0, 1, 50, 10, 5, 1, 0, 0, 1, 0, 0, 0,
 'ItemUpgradeTransmutationNPC', 12340);

-- Add creature_template_model entry for visual display
DELETE FROM `creature_template_model` WHERE `CreatureID` = 190004;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(190004, 0, 4297, 1, 1, 12340);  -- Blood Elf mage model (mystical/transmutation theme)

-- Spawn the Transmutation Master in major cities
-- Stormwind (Mage Quarter - near the portal trainers)
DELETE FROM `creature` WHERE `guid` = 450006;
INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`)
VALUES
(450006, 190004, 0, 0, 0, 1, 1, 0, -9003.46, 871.51, 148.62, 3.79, 300, 0, 0, 100, 0, 0, 0, 0, 0);

-- Orgrimmar (Valley of Spirits - near the alchemy/enchantment area)
DELETE FROM `creature` WHERE `guid` = 450007;
INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`)
VALUES
(450007, 190004, 0, 0, 1, 1, 1, 0, 1954.08, -4252.08, 23.42, 1.05, 300, 0, 0, 100, 0, 0, 0, 0, 0);

-- Shattrath City (Scryer/ Aldor areas - near the alchemy lab)
DELETE FROM `creature` WHERE `guid` = 450008;
INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`)
VALUES
(450008, 190004, 0, 0, 530, 1, 1, 0, -1847.67, 5223.40, -40.43, 4.71, 300, 0, 0, 100, 0, 0, 0, 0, 0);