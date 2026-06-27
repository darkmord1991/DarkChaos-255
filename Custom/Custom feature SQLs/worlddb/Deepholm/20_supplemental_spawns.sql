-- =====================================================================
-- Deepholm Downport  --  20  Supplemental spawns (content the TDB omitted)
-- ---------------------------------------------------------------------
-- Source: cata_world (template) + Project Neltharion 4.3.4 (spawn point).
-- REQUIRES cata_world present at import time. Run AFTER 01.
--
-- The review vs the fully-populated Neltharion 4.3.4 repack found one piece of
-- real content the TDB (cata_world) shipped a template for but never SPAWNED, so
-- 01/04 could not import it:
--   * 50060  Terborus  -- the Deepholm rare elite (rank 4). cata_world has the
--     template, 0 spawns; Neltharion spawns it at the Crimson Expanse.
-- (The other 23 NPC-id deltas vs Neltharion are invisible trigger bunnies or
--  Neltharion spawn-only quirks with no template -- intentionally skipped.)
--
-- GUID block for supplemental creatures: 9,461,000 .. 9,461,099 (just past the
-- 04 creature block 9,400,000-9,460,000; verified free).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Terborus template  (normalized exactly like 01_creature_templates.sql)
-- ---------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` = 50060;
INSERT INTO `creature_template`
(`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`,
 `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`,
 `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`,
 `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
 `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
 `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
 `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
 `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
 ct.`entry`, ct.`difficulty_entry_1`, ct.`difficulty_entry_2`, ct.`difficulty_entry_3`,
 ct.`KillCredit1`, ct.`KillCredit2`, ct.`name`, ct.`subname`, ct.`IconName`, ct.`gossip_menu_id`,
 ct.`minlevel`, ct.`maxlevel`, GREATEST(0, LEAST(ct.`HealthScalingExpansion`, 2)), ct.`faction`, ct.`npcflag`,
 ct.`speed_walk`, ct.`speed_run`, 1, 1, 0, ct.`rank`, ct.`dmgschool`,
 ct.`DamageModifier`, ct.`BaseAttackTime`, ct.`RangeAttackTime`, ct.`BaseVariance`, ct.`RangeVariance`,
 ct.`unit_class`, ct.`unit_flags`, ct.`unit_flags2`, 0, ct.`family`, ct.`type`,
 ct.`type_flags`, ct.`lootid`, ct.`pickpocketloot`, ct.`skinloot`, ct.`PetSpellDataId`, ct.`VehicleId`,
 ct.`mingold`, ct.`maxgold`, ct.`AIName`, ct.`MovementType`, ct.`HoverHeight`, ct.`HealthModifier`,
 ct.`ManaModifier`, ct.`ArmorModifier`, ct.`ExperienceModifier`, ct.`RacialLeader`, ct.`movementId`,
 ct.`RegenHealth`, 0, ct.`flags_extra`, '', ct.`VerifiedBuild`
FROM `cata_world`.`creature_template` ct WHERE ct.`entry` = 50060;

-- display model(s) + model_info + addon (mirror 01)
DELETE FROM `creature_template_model` WHERE `CreatureID` = 50060;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`modelid1`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`entry` = 50060 AND ct.`modelid1` > 0;

INSERT IGNORE INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`)
SELECT cmi.`DisplayID`, cmi.`BoundingRadius`, cmi.`CombatReach`, cmi.`Gender`, cmi.`DisplayID_Other_Gender`, 0
FROM `cata_world`.`creature_model_info` cmi
JOIN ( SELECT ct.`modelid1` AS m FROM `cata_world`.`creature_template` ct WHERE ct.`entry` = 50060 AND ct.`modelid1` > 0 ) dd ON dd.m = cmi.`DisplayID`;

DELETE FROM `creature_template_addon` WHERE `entry` = 50060;
-- NB: this cata_world split bytes1/bytes2 into StandState/AnimTier/VisFlags + SheathState/PvPFlags
-- (TC schema migration) -> repack to the fork's bytes1/bytes2 (UNIT_FIELD_BYTES_1/2 layout).
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT a.`entry`, a.`waypointPathId`, a.`mount`,
 (a.`StandState` + (a.`VisFlags` << 16) + (a.`AnimTier` << 24)),
 (a.`SheathState` + (a.`PvPFlags` << 8)),
 a.`emote`, a.`visibilityDistanceType`, a.`auras`
FROM `cata_world`.`creature_template_addon` a WHERE a.`entry` = 50060;

-- ---------------------------------------------------------------------
-- Terborus spawn  (Neltharion coords; rare timer; base phase = visible)
-- ---------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` = 9461000;
INSERT INTO `creature`
(`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
 `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`,
 `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`,
 `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`)
VALUES
(9461000, 50060, 646, 0, 0, 1, 1, 0,
 2023.91, 191.648, -124.709, 3.84099, 72000, 5,
 0, 1, 1, 1, 0, 0,
 0, '', 0, 0, 'Deepholm - Terborus (rare elite, TDB-omitted)');
