-- =====================================================================
-- Deepholm Downport  --  15  Script-NPC bridge  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
-- Run AFTER 01 (creature templates).  Pairs with the C++ in
--   src/server/scripts/DC/Deepholm/zone_deepholm.cpp  (needs a worldserver rebuild).
--
-- The zone C++ attaches by ScriptName. Two gaps to close:
--   1. Xariona (50061) IS spawned and was imported in 01, but 01 blanked its
--      ScriptName (the C++ did not exist yet) -> restore it here.
--   2. The Wyvern (45004 / 45024) and Twilight Fissure (50431) are SUMMON-only
--      (never spawned on map 646), so 01 did not import their templates -> import
--      them here. The fissure has a blank ScriptName in Cata; set it to the new
--      AI's name. Wyverns already carry 'npc_deepholm_wyvern'.
--
-- Display models for these 3 are Cata-new (wyvern + fissure) -> add to the bake
-- list (06_assets_manifest.md) alongside the spawned-creature models.
-- =====================================================================

-- ---------------------------------------------------------------------
-- (1) restore Xariona's ScriptName (already imported by 01)
-- ---------------------------------------------------------------------
UPDATE `creature_template` SET `ScriptName` = 'npc_deepholm_xariona' WHERE `entry` = 50061;

-- ---------------------------------------------------------------------
-- (2) import the 3 summon-only templates (45004, 45024 wyverns; 50431 fissure)
-- ---------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (45004, 45024, 50431);

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
 ct.`minlevel`, ct.`maxlevel`, LEAST(ct.`exp`, 2), ct.`faction`, ct.`npcflag`,
 ct.`speed_walk`, ct.`speed_run`, 1, 1, 0, ct.`rank`, ct.`dmgschool`,
 ct.`DamageModifier`, ct.`BaseAttackTime`, ct.`RangeAttackTime`, ct.`BaseVariance`, ct.`RangeVariance`,
 ct.`unit_class`, ct.`unit_flags`, ct.`unit_flags2`, ct.`dynamicflags`, ct.`family`, ct.`type`,
 ct.`type_flags`, ct.`lootid`, ct.`pickpocketloot`, ct.`skinloot`, ct.`PetSpellDataId`, ct.`VehicleId`,
 ct.`mingold`, ct.`maxgold`, ct.`AIName`, ct.`MovementType`, ct.`HoverHeight`, ct.`HealthModifier`,
 ct.`ManaModifier`, ct.`ArmorModifier`, ct.`ExperienceModifier`, ct.`RacialLeader`, ct.`movementId`,
 ct.`RegenHealth`, 0, ct.`flags_extra`,
 CASE WHEN ct.`entry` = 50431 THEN 'npc_deepholm_twilight_fissure' ELSE ct.`ScriptName` END,
 ct.`VerifiedBuild`
FROM `cata_world`.`creature_template` ct
WHERE ct.`entry` IN (45004, 45024, 50431);

-- ---------------------------------------------------------------------
-- their display models + model_info + addon
-- ---------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (45004, 45024, 50431);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`modelid1`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`modelid1` > 0 AND ct.`entry` IN (45004, 45024, 50431)
UNION ALL
SELECT ct.`entry`, 1, ct.`modelid2`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`modelid2` > 0 AND ct.`entry` IN (45004, 45024, 50431);

INSERT IGNORE INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`)
SELECT cmi.`DisplayID`, cmi.`BoundingRadius`, cmi.`CombatReach`, cmi.`Gender`, cmi.`DisplayID_Other_Gender`, 0
FROM `cata_world`.`creature_model_info` cmi
JOIN (
    SELECT DISTINCT m FROM (
        SELECT ct.`modelid1` AS m FROM `cata_world`.`creature_template` ct WHERE ct.`modelid1` > 0 AND ct.`entry` IN (45004, 45024, 50431)
        UNION SELECT ct.`modelid2` FROM `cata_world`.`creature_template` ct WHERE ct.`modelid2` > 0 AND ct.`entry` IN (45004, 45024, 50431)
    ) u
) dd ON dd.m = cmi.`DisplayID`;

DELETE FROM `creature_template_addon` WHERE `entry` IN (45004, 45024, 50431);
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT a.`entry`, a.`waypointPathId`, a.`mount`, a.`bytes1`, a.`bytes2`, a.`emote`, a.`visibilityDistanceType`, a.`auras`
FROM `cata_world`.`creature_template_addon` a
WHERE a.`entry` IN (45004, 45024, 50431);
