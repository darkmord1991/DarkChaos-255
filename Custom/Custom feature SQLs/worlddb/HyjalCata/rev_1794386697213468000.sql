-- DarkChaos: Magma Totem (3742211), the creature spell 78770 summons
--
-- Thistlefur Totemic (3703922, map 750, level 92-93) and Fraggar Thundermantle (4143156, level 150) cast 'Magma
-- Totem' (78770) in combat. The spell summons 3742211, which was never imported, so each cast logged
-- "Creature::Create(): creature template (entry: 3742211) does not exist" and no totem appeared.
--
-- Source: cata_world 42211 'Magma Totem' (+3,700,000), the same row as stock 5929 'Magma Totem': faction 58, totem
-- (type 11), health x0.05, display 4589. The template is copied from 5929. Neither Cata database gives 42211 a
-- totem spell, so like there it is a visual totem and pulses nothing. A summoned totem takes its caster's level
-- and faction (Totem::InitStats, TempSummon::InitStats), so one template serves both casters.

-- creature_template rows are never deleted (codestyle), so the row is a REPLACE copied from the stock totem
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
    3742211, 0, 0, 0, 0, 0, `t`.`name`, `t`.`subname`, `t`.`IconName`, 0, 92, 150, `t`.`exp`, `t`.`faction`, 0,
    `t`.`speed_walk`, `t`.`speed_run`, `t`.`speed_swim`, `t`.`speed_flight`, `t`.`detection_range`, `t`.`rank`,
    `t`.`dmgschool`, `t`.`DamageModifier`, `t`.`BaseAttackTime`, `t`.`RangeAttackTime`, `t`.`BaseVariance`,
    `t`.`RangeVariance`, `t`.`unit_class`, `t`.`unit_flags`, `t`.`unit_flags2`, `t`.`dynamicflags`, `t`.`family`,
    `t`.`type`, `t`.`type_flags`, 0, 0, 0, 0, 0, 0, 0, '', 0, `t`.`HoverHeight`, `t`.`HealthModifier`,
    `t`.`ManaModifier`, `t`.`ArmorModifier`, `t`.`ExperienceModifier`, 0, `t`.`movementId`, `t`.`RegenHealth`,
    `t`.`CreatureImmunitiesId`, `t`.`flags_extra`, '', 0
FROM `creature_template` AS `t`
WHERE `t`.`entry` = 5929;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 3742211;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`,
    `VerifiedBuild`) VALUES
(3742211, 0, 4589, 1, 1, 0);
