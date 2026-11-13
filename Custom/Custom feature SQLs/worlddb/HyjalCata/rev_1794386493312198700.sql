-- DarkChaos: Released Highborne Spirit (3748727), the creature spell 90798 summons on map 750
--
-- Suffering Highborne (3707523) and Anguished Highborne (3707524), the map-750 Winterspring clones, cast
-- 'Released Highborne' (90798) when they die. The spell summons 3748727, which was never imported, so every kill
-- logged "Creature::Create(): creature template (entry: 3748727) does not exist" and nothing appeared.
--
-- Source: cata_world 48727 'Released Highborne Spirit' (+3,700,000 like the rest of the band): faction 35, SmartAI
-- that on summon says one of four lines (broadcast texts 48896-48900, already in the DB), turns into a wisp, floats
-- to a point above Lake Kel'Theril and despawns. Map 750 keeps the stock Winterspring coordinates, so the Cata point
-- is used as is.
--
-- Two stand-ins, both stock 3.3.5, so no DBC or client change:
-- * displays: Cata's 36250-36253 are night elf models with Cata NPC bakes that the 3.3.5 client does not have.
--   The four Shen'dralar Spirit displays (14364: 14393, 14397, 14398, 14400; Highborne spirits, two male, two
--   female) are used instead.
-- * Cata casts 'Transform: Wisp' (90793), which is not in spell_dbc; the action list morphs to the Shen'dralar
--   Wisp display (10045) instead.
-- Level 110 like the casters. Flight 1 (no gravity) so it can rise to the Cata point.

-- creature_template rows are never deleted (codestyle), so the row is a REPLACE copied from the caster clone
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
    3748727, 0, 0, 0, 0, 0, 'Released Highborne Spirit', '', '', 0, 110, 110, `t`.`exp`, 35, 0, 1, 1.14286,
    `t`.`speed_swim`, `t`.`speed_flight`, `t`.`detection_range`, 0, 0, `t`.`DamageModifier`, `t`.`BaseAttackTime`,
    `t`.`RangeAttackTime`, `t`.`BaseVariance`, `t`.`RangeVariance`, `t`.`unit_class`, 0, 2048, 0, 0, 6, 0, 0, 0, 0,
    0, 0, 0, 0, 'SmartAI', 0, 1, `t`.`HealthModifier`, `t`.`ManaModifier`, `t`.`ArmorModifier`, 0, 0, 0, 1, 0, 0,
    '', 0
FROM `creature_template` AS `t`
WHERE `t`.`entry` = 3707523;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 3748727;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`,
    `VerifiedBuild`) VALUES
(3748727, 0, 14393, 1, 1, 0),
(3748727, 1, 14397, 1, 1, 0),
(3748727, 2, 14398, 1, 1, 0),
(3748727, 3, 14400, 1, 1, 0);

DELETE FROM `creature_template_movement` WHERE `CreatureId` = 3748727;
INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`,
    `InteractionPauseTimer`) VALUES
(3748727, 1, 1, 1, 0, 0, 0, 0);

DELETE FROM `creature_text` WHERE `CreatureID` = 3748727;
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`,
    `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(3748727, 0, 0, 'Leave now... you do not deserve to suffer the crystal''s wrath...', 12, 0, 25, 0, 0, 0, 48898, 0, ''),
(3748727, 0, 1, 'Relief at last...', 12, 0, 25, 0, 0, 0, 48896, 0, 'Released Highborne Spirit'),
(3748727, 0, 2, 'Thank you...', 12, 0, 25, 0, 0, 0, 48897, 0, 'Released Highborne Spirit'),
(3748727, 0, 3, 'The crystal has returned. You must leave...', 12, 0, 25, 0, 0, 0, 48900, 0, '');

-- Action list 374872700 = entry * 100, the numbering the 37xxxxx clones use (free; the Cata list is 4872700)
DELETE FROM `smart_scripts` WHERE `source_type` = 9 AND `entryorguid` = 374872700;
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 3748727;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`,
    `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`,
    `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`,
    `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`,
    `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(3748727, 0, 0, 0, 54, 0, 100, 1, 0, 0, 0, 0, 0, 0, 80, 374872700, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Released Highborne Spirit - On Just Summoned - Run Script (No Repeat)'),
(374872700, 9, 0, 0, 0, 0, 100, 0, 1000, 1000, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Released Highborne Spirit - On Script - Say Line 0'),
(374872700, 9, 1, 0, 0, 0, 100, 0, 1500, 1500, 0, 0, 0, 0, 3, 0, 10045, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Released Highborne Spirit - On Script - Morph To Wisp'),
(374872700, 9, 2, 0, 0, 0, 100, 0, 1000, 1000, 0, 0, 0, 0, 69, 0, 0, 1, 0, 0, 0, 8, 0, 0, 0, 0, 6540.52, -4113.04, 710.365, 1.95536, 'Released Highborne Spirit - On Script - Move To Position'),
(374872700, 9, 3, 0, 0, 0, 100, 0, 2000, 2000, 0, 0, 0, 0, 41, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Released Highborne Spirit - On Script - Despawn Instant');
