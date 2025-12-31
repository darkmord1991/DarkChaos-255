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

INSERT INTO `creature_template` (
`entry`,
`name`,
`subname`,
`minlevel`,
`maxlevel`,
`exp`,
`faction`,
`npcflag`,
`speed_walk`,
`speed_run`,
`scale`,
`rank`,
`dmgschool`,
`BaseAttackTime`,
`RangeAttackTime`,
`unit_class`,
`unit_flags`,
`unit_flags2`,
`type`,
`ScriptName`,
`VerifiedBuild`
) VALUES
(400350,'Ancient Terror','Giant Isles Boss',83,83,2,14,0,1.0,1.14286,3.0,3,0,2000,2000,1,0,0,0,'npc_giant_water_monster',12340),
(400351,'Corrupted Elemental','Minion of the Deep',81,81,0,14,0,1.0,1.14286,1.0,1,0,2000,2000,1,0,0,0,'npc_corrupted_elemental',12340);

-- 2b. Restore models (required; otherwise creature creation/summon can fail)
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (400350, 400351);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400350, 0, 29487, 1.0, 1.0, 12340), -- Ancient Terror
(400351, 0, 17203, 1.0, 1.0, 12340); -- Corrupted Elemental

-- 2c. Restore movement flags (water/ground)
DELETE FROM `creature_template_movement` WHERE `CreatureId` IN (400350, 400351);
INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`) VALUES
(400350, 1, 1, 0, 0),
(400351, 1, 1, 0, 0);
