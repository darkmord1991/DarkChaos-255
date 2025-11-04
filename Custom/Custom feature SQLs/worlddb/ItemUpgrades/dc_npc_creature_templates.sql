/*
 * DarkChaos Item Upgrade System - NPC Creature Templates
 * 
 * Adds two new NPCs to the creature_template table:
 * - ID 190001: Item Upgrade Vendor
 * - ID 190002: Artifact Curator
 * 
 * This file must be executed BEFORE npc_spawns.sql
 */

-- Item Upgrade Vendor (ID: 190001)
DELETE FROM `creature_template` WHERE `entry` = 190001;
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
(190001, 0, 0, 0, 0, 0, 'Item Upgrade Vendor', 'Upgrade your items with tokens!', NULL, 0, 
 63, 63, 2, 35, 1, 1, 1.14286, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 
 7, 0, 0, 0, 0, 0, 0, 0, 0, 'PassiveAI', 0, 1, 50, 10, 5, 1, 0, 0, 1, 0, 0, 0, 
 'npc_item_upgrade_vendor', 12340);

-- Artifact Curator (ID: 190002)
DELETE FROM `creature_template` WHERE `entry` = 190002;
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
(190002, 0, 0, 0, 0, 0, 'Artifact Curator', 'Curator of Chaos Artifacts', NULL, 0, 
 63, 63, 2, 35, 1, 1, 1.14286, 1, 1, 18, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 
 7, 0, 0, 0, 0, 0, 0, 0, 0, 'PassiveAI', 0, 1, 50, 10, 5, 1, 0, 0, 1, 0, 0, 0, 
 'npc_item_upgrade_curator', 12340);

-- Add creature_template_model entries for visual display
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (190001, 190002);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(190001, 0, 4286, 1, 1, 12340),  -- Human merchant model
(190002, 0, 4299, 1, 1, 12340);  -- Dwarf model
