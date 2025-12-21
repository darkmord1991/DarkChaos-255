-- ============================================================================
-- FIX: Missing Script Assignments for Giant Isles
-- ============================================================================

-- 1. Assign 'creature_giant_isles_death' to basic Giant Isles dinosaurs (400000-400049)
-- These creatures currently have no script, so we assign the death handler to them.
UPDATE `creature_template` SET `ScriptName` = 'creature_giant_isles_death' WHERE `entry` BETWEEN 400000 AND 400049;

-- 2. Restore Giant Water Monster NPCs (400350, 400351)
-- These entries are often deleted by the cleanup in giant_isles_creatures.sql (range 400000-400999).
-- We re-insert them here to ensure the scripts 'npc_giant_water_monster' and 'npc_corrupted_elemental' are assigned.

DELETE FROM `creature_template` WHERE `entry` IN (400350, 400351);

INSERT INTO `creature_template` (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`trainer_type`,`trainer_spell`,`trainer_class`,`trainer_race`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`mechanic_immune_mask`,`spell_school_immune_mask`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES
(400350,0,0,0,0,0,'Ancient Terror','Giant Isles Boss','',0,83,83,2,14,0,1.0,1.14286,3.0,3,0,2000,2000,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'',0,1.0,100.0,1.0,1.0,1.0,0.0,0,1,0,0,1,0,'npc_giant_water_monster',12340),
(400351,0,0,0,0,0,'Corrupted Elemental','Minion of the Deep','',0,81,81,0,14,0,1.0,1.14286,1.0,1,0,2000,2000,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'',0,1.0,10.0,1.0,1.0,1.0,0.0,0,1,0,0,1,0,'npc_corrupted_elemental',12340);
