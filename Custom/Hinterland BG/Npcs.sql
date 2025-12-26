-- HinterlandBG - Additional faction NPC templates (810006+)
-- Includes: creature_template, creature_template_model, creature_text, smart_scripts
-- Note: This file defines templates only (no spawns).

-- =========================================
-- Creature templates
-- =========================================

-- Horde: Revantusk Warcaller (drummer/sergeant)
DELETE FROM `creature_template` WHERE (`entry` = 810006);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(810006, 0, 0, 0, 0, 0, 'Revantusk Warcaller', 'HinterlandBG', NULL, 0, 80, 80, 1, 1495, 0, 1, 1.14286, 1, 1, 18, 1, 0, 0, 3, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartAI', 0, 1, 60, 10, 5, 1, 0, 0, 1, 0, 0, 0, '', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 810006);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(810006, 0, 28257, 1, 1, 12340),
(810006, 1, 28258, 1, 1, 12340),
(810006, 2, 28259, 1, 1, 12340),
(810006, 3, 14767, 1, 1, 12340);

-- Horde: Revantusk Watchblade (melee)
DELETE FROM `creature_template` WHERE (`entry` = 810007);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(810007, 0, 0, 0, 0, 0, 'Revantusk Watchblade', 'HinterlandBG', NULL, 0, 80, 80, 1, 1495, 0, 1, 1.14286, 1, 1, 18, 1, 0, 0, 3, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartAI', 0, 1, 60, 10, 5, 1, 0, 0, 1, 0, 0, 0, '', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 810007);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(810007, 0, 14762, 1, 1, 12340),
(810007, 1, 14763, 1, 1, 12340),
(810007, 2, 28260, 1, 1, 12340),
(810007, 3, 28261, 1, 1, 12340);

-- Horde: Revantusk Spiritmender (caster)
DELETE FROM `creature_template` WHERE (`entry` = 810008);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(810008, 0, 0, 0, 0, 0, 'Revantusk Spiritmender', 'HinterlandBG', NULL, 0, 80, 80, 1, 1495, 0, 1, 1.14286, 1, 1, 18, 1, 0, 0, 2, 2000, 2000, 1, 1, 2, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartAI', 0, 1, 50, 10, 5, 1, 0, 0, 1, 0, 0, 0, '', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 810008);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(810008, 0, 3996, 1, 1, 12340),
(810008, 1, 28237, 1, 1, 12340);

-- Alliance: Wildhammer Battlewarden (melee)
DELETE FROM `creature_template` WHERE (`entry` = 810009);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(810009, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden', 'HinterlandBG', NULL, 0, 80, 80, 1, 11, 0, 1, 1.42857, 1, 1, 18, 1, 0, 0, 2, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartAI', 0, 1, 50, 10, 5, 1, 0, 0, 1, 0, 0, 98304, '', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 810009);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(810009, 0, 18749, 1, 1, 12340),
(810009, 1, 18750, 1, 1, 12340),
(810009, 2, 18751, 1, 1, 12340),
(810009, 3, 18752, 1, 1, 12340);

-- Alliance: Wildhammer Sentry (rifleman)
DELETE FROM `creature_template` WHERE (`entry` = 810010);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(810010, 0, 0, 0, 0, 0, 'Wildhammer Sentry', 'HinterlandBG', NULL, 0, 80, 80, 1, 11, 0, 1, 1.42857, 1, 1, 18, 1, 0, 0, 2, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartAI', 0, 1, 45, 10, 5, 1, 0, 0, 1, 0, 0, 98304, '', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 810010);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(810010, 0, 7859, 1, 1, 12340),
(810010, 1, 7860, 1, 1, 12340),
(810010, 2, 7861, 1, 1, 12340),
(810010, 3, 7862, 1, 1, 12340);

-- Alliance: Wildhammer Scout (skirmisher)
DELETE FROM `creature_template` WHERE (`entry` = 810011);
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(810011, 0, 0, 0, 0, 0, 'Wildhammer Scout', 'HinterlandBG', NULL, 0, 80, 80, 1, 11, 0, 1, 1.42857, 1, 1, 18, 1, 0, 0, 2, 2000, 2000, 1, 1, 1, 32768, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'SmartAI', 0, 1, 40, 10, 5, 1, 0, 0, 1, 0, 0, 98304, '', 12340);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 810011);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(810011, 0, 18788, 1, 1, 12340),
(810011, 1, 18789, 1, 1, 12340),
(810011, 2, 18790, 1, 1, 12340),
(810011, 3, 18791, 1, 1, 12340);

-- =========================================
-- Creature texts
-- =========================================

DELETE FROM `creature_text` WHERE `CreatureID` IN (810006, 810007, 810008, 810009, 810010, 810011);
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
-- 810006: Revantusk Warcaller
(810006, 0, 0, 'Drums o'' war! Smash ''em!', 14, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Warcaller - Aggro'),
(810006, 0, 1, 'Da hills echo wit'' our wrath!', 14, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Warcaller - Aggro'),
(810006, 1, 0, 'Da drums... go silent...', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Warcaller - Death'),
(810006, 1, 1, 'Revantusk... remember...', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Warcaller - Death'),
(810006, 2, 0, 'Now you face da true fury!', 14, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Warcaller - Low HP'),
(810006, 2, 1, 'No retreat! No mercy!', 14, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Warcaller - Low HP'),

-- 810007: Revantusk Watchblade
(810007, 0, 0, 'Your blood will feed da forest.', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Watchblade - Aggro'),
(810007, 0, 1, 'You trespass in Revantusk lands!', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Watchblade - Aggro'),
(810007, 1, 0, 'Da shadows... take me...', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Watchblade - Death'),
(810007, 1, 1, 'I fall... but da tribe stands...', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Watchblade - Death'),
(810007, 2, 0, 'I will not be brought low!', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Watchblade - Low HP'),
(810007, 2, 1, 'Come! Let us end dis!', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Watchblade - Low HP'),

-- 810008: Revantusk Spiritmender
(810008, 0, 0, 'Da spirits judge you!', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Spiritmender - Aggro'),
(810008, 0, 1, 'You face voodoo older than dese hills.', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Spiritmender - Aggro'),
(810008, 1, 0, 'Da Loa... call me home...', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Spiritmender - Death'),
(810008, 1, 1, 'Spirits... forgive me...', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Spiritmender - Death'),
(810008, 2, 0, 'Spirits, mend my flesh!', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Spiritmender - Low HP'),
(810008, 2, 1, 'Not yet... I still fight!', 12, 0, 100, 0, 0, 0, 0, 0, 'Revantusk Spiritmender - Low HP'),

-- 810009: Wildhammer Battlewarden
(810009, 0, 0, 'For Aerie Peak! Stand fast!', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden - Aggro'),
(810009, 0, 1, 'Ye picked the wrong valley to raid!', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden - Aggro'),
(810009, 1, 0, 'Tell Kurdran... we held...', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden - Death'),
(810009, 1, 1, 'Ach... I''ll not see the peaks again...', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden - Death'),
(810009, 2, 0, 'I''ll die on me feet afore I yield!', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden - Low HP'),
(810009, 2, 1, 'No quarter!', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden - Low HP'),

-- 810010: Wildhammer Sentry
(810010, 0, 0, 'Enemy in the trees! Open fire!', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Sentry - Aggro'),
(810010, 0, 1, 'To arms! Defend the pass!', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Sentry - Aggro'),
(810010, 1, 0, 'Me rifle... slipped...', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Sentry - Death'),
(810010, 1, 1, 'Fall back... fall back...', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Sentry - Death'),
(810010, 2, 0, 'I''m not done yet!', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Sentry - Low HP'),
(810010, 2, 1, 'You''ll not break our line!', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Sentry - Low HP'),

-- 810011: Wildhammer Scout
(810011, 0, 0, 'Spotted! Take ''em down!', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Scout - Aggro'),
(810011, 0, 1, 'I''ll put an arrow in yer knee!', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Scout - Aggro'),
(810011, 1, 0, 'The forest... grows dark...', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Scout - Death'),
(810011, 1, 1, 'Aerie Peak... forgive me...', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Scout - Death'),
(810011, 2, 0, 'If I''m goin'' down, I''m takin'' you wi'' me!', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Scout - Low HP'),
(810011, 2, 1, 'Keep yer distance!', 12, 0, 100, 0, 0, 0, 0, 0, 'Wildhammer Scout - Low HP');

-- =========================================
-- Creature equipment (weapons)
-- =========================================

-- This core uses equipment per-spawn (`creature.equipment_id`).
-- We define the equipment set here as ID=1 for each creature entry.

DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (810006, 810007, 810008, 810009, 810010, 810011);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(810006, 1, 12748, 12651, 0, 12340),  -- Revantusk Warcaller - Axe + Shield
(810007, 1, 12749, 12651, 0, 12340),  -- Revantusk Watchblade - Sword + Shield
(810008, 1, 12584, 0, 0, 12340),      -- Revantusk Spiritmender - Staff
(810009, 1, 12749, 12651, 0, 12340),  -- Wildhammer Battlewarden - Sword + Shield
(810010, 1, 12749, 0, 2507, 12340),   -- Wildhammer Sentry - Sword + Rifle
(810011, 1, 12749, 0, 2506, 12340);   -- Wildhammer Scout - Sword + Crossbow

-- If DB spawns already exist for these entries, set them to use equipment set 1.
UPDATE `creature` SET `equipment_id` = 1 WHERE `id1` IN (810006, 810007, 810008, 810009, 810010, 810011);

-- =========================================
-- SmartAI scripts
-- =========================================

DELETE FROM `smart_scripts` WHERE `entryorguid` IN (810006, 810007, 810008, 810009, 810010, 810011) AND `source_type` = 0;

-- 810006: Revantusk Warcaller
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(810006, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Warcaller - On Aggro - Say Line 0'),
(810006, 0, 1, 0, 0, 0, 100, 0, 2000, 5000, 25000, 35000, 0, 11, 9128, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Warcaller - In Combat - Cast Battle Shout'),
(810006, 0, 2, 0, 0, 0, 100, 0, 6000, 9000, 20000, 30000, 0, 11, 13730, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Warcaller - In Combat - Cast Demoralizing Shout'),
(810006, 0, 3, 0, 0, 0, 100, 0, 3500, 7000, 8000, 14000, 0, 11, 11971, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Warcaller - In Combat - Cast Sunder Armor'),
(810006, 0, 4, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Warcaller - Between 0-30% Health - Cast Enrage (No Repeat)'),
(810006, 0, 5, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Warcaller - Between 0-30% Health - Say Line 2 (No Repeat)'),
(810006, 0, 6, 0, 6, 0, 100, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Warcaller - On Death - Say Line 1');

-- 810007: Revantusk Watchblade
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(810007, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Watchblade - On Aggro - Say Line 0'),
(810007, 0, 1, 0, 0, 0, 100, 0, 3000, 6000, 8000, 14000, 0, 11, 11971, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Watchblade - In Combat - Cast Sunder Armor'),
(810007, 0, 2, 0, 0, 0, 100, 0, 6000, 9000, 12000, 18000, 0, 11, 9080, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Watchblade - In Combat - Cast Hamstring'),
(810007, 0, 3, 0, 2, 0, 100, 1, 0, 40, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Watchblade - Between 0-40% Health - Cast Enrage (No Repeat)'),
(810007, 0, 4, 0, 2, 0, 100, 1, 0, 40, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Watchblade - Between 0-40% Health - Say Line 2 (No Repeat)'),
(810007, 0, 5, 0, 6, 0, 100, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Watchblade - On Death - Say Line 1');

-- 810008: Revantusk Spiritmender
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(810008, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Spiritmender - On Aggro - Say Line 0'),
(810008, 0, 1, 0, 0, 0, 100, 0, 2000, 4000, 3500, 5400, 0, 11, 9532, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Spiritmender - In Combat - Cast Lightning Bolt'),
(810008, 0, 2, 0, 0, 0, 100, 0, 6000, 10000, 12000, 18000, 0, 11, 2606, 1, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Spiritmender - In Combat - Cast Shock'),
(810008, 0, 3, 0, 2, 0, 100, 0, 0, 40, 15000, 25000, 0, 11, 913, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Spiritmender - Between 0-40% Health - Cast Healing Wave'),
(810008, 0, 4, 0, 2, 0, 100, 1, 0, 40, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Spiritmender - Between 0-40% Health - Say Line 2 (No Repeat)'),
(810008, 0, 5, 0, 6, 0, 100, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Revantusk Spiritmender - On Death - Say Line 1');

-- 810009: Wildhammer Battlewarden
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(810009, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden - On Aggro - Say Line 0'),
(810009, 0, 1, 0, 0, 0, 100, 0, 3500, 7000, 12000, 18000, 0, 11, 11971, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden - In Combat - Cast Sunder Armor'),
(810009, 0, 2, 0, 0, 0, 100, 0, 6000, 9000, 20000, 30000, 0, 11, 8078, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden - In Combat - Cast Thunder Clap'),
(810009, 0, 3, 0, 2, 0, 100, 1, 0, 35, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden - Between 0-35% Health - Cast Enrage (No Repeat)'),
(810009, 0, 4, 0, 2, 0, 100, 1, 0, 35, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden - Between 0-35% Health - Say Line 2 (No Repeat)'),
(810009, 0, 5, 0, 6, 0, 100, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Battlewarden - On Death - Say Line 1');

-- 810010: Wildhammer Sentry
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(810010, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Sentry - On Aggro - Say Line 0'),
(810010, 0, 1, 0, 0, 0, 100, 0, 0, 0, 2300, 3900, 0, 11, 6660, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Sentry - In Combat - Cast Shoot'),
(810010, 0, 2, 0, 0, 0, 100, 0, 12000, 18000, 30000, 30000, 0, 11, 6685, 1, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Sentry - In Combat - Cast Piercing Shot'),
(810010, 0, 3, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Sentry - Between 0-30% Health - Say Line 2 (No Repeat)'),
(810010, 0, 4, 0, 6, 0, 100, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Sentry - On Death - Say Line 1');

-- 810011: Wildhammer Scout
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(810011, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Scout - On Aggro - Say Line 0'),
(810011, 0, 1, 0, 0, 0, 100, 0, 0, 0, 2300, 3900, 0, 11, 6660, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Scout - In Combat - Cast Shoot'),
(810011, 0, 2, 0, 0, 0, 100, 0, 8000, 12000, 12000, 18000, 0, 11, 32908, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Scout - In Combat - Cast Wing Clip'),
(810011, 0, 3, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Scout - Between 0-30% Health - Say Line 2 (No Repeat)'),
(810011, 0, 4, 0, 6, 0, 100, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildhammer Scout - On Death - Say Line 1');
