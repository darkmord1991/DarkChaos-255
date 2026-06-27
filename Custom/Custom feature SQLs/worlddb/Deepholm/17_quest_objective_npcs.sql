-- =====================================================================
-- Deepholm Downport  --  17  Quest-objective NPC templates  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
-- Run AFTER 01 + 11.
--
-- The 128 Deepholm quests reference 28 creature entries as RequiredNpcOrGo /
-- KillCredit objectives that 01 did NOT import, because they are never spawned on
-- map 646 -- they are invisible "Kill Credit" / event-controller proxies summoned
-- by quest spells/scripts (e.g. "Sealing the Way Kill Credit", "Therazane Audience
-- Credit", "Elemental Bonds Event Controller"), plus one cross-zone boss (42188
-- Ozruk, the Stonecore dungeon boss on map 725).
--
-- Without these templates the core logs "Quest ... RequiredNpcOrGo X does not
-- exist" and the objectives are DB-invalid. This imports the templates so the
-- references resolve.
--
-- NOTE (functional, not a DB error): the credit-GRANTING logic for most of these
-- lives in quest spells / SmartAI / C++ that is largely not yet ported, so those
-- objectives won't actually complete until that scripting is added (quest-scripting
-- track). 42188 Ozruk needs the Stonecore dungeon (out of scope). ScriptNames are
-- blanked here (their custom C++ is unported); AIName is kept as-is.
-- =====================================================================

DELETE FROM `creature_template` WHERE `entry` IN
 (42188,43027,43028,43029,43038,43164,43165,43166,43167,43597,43640,43649,43978,44051,44133,44135,44228,44229,44281,44282,44290,44772,44900,44938,45083,45091,46139,53744);

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
 ct.`RegenHealth`, 0, ct.`flags_extra`, '', ct.`VerifiedBuild`
FROM `cata_world`.`creature_template` ct
WHERE ct.`entry` IN
 (42188,43027,43028,43029,43038,43164,43165,43166,43167,43597,43640,43649,43978,44051,44133,44135,44228,44229,44281,44282,44290,44772,44900,44938,45083,45091,46139,53744);

-- display model + collision/reach + addon (mostly invisible trigger models)
DELETE FROM `creature_template_model` WHERE `CreatureID` IN
 (42188,43027,43028,43029,43038,43164,43165,43166,43167,43597,43640,43649,43978,44051,44133,44135,44228,44229,44281,44282,44290,44772,44900,44938,45083,45091,46139,53744);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`modelid1`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
 WHERE ct.`modelid1` > 0 AND ct.`entry` IN (42188,43027,43028,43029,43038,43164,43165,43166,43167,43597,43640,43649,43978,44051,44133,44135,44228,44229,44281,44282,44290,44772,44900,44938,45083,45091,46139,53744);

INSERT IGNORE INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`)
SELECT cmi.`DisplayID`, cmi.`BoundingRadius`, cmi.`CombatReach`, cmi.`Gender`, cmi.`DisplayID_Other_Gender`, 0
FROM `cata_world`.`creature_model_info` cmi
JOIN (
    SELECT DISTINCT ct.`modelid1` AS m FROM `cata_world`.`creature_template` ct
    WHERE ct.`modelid1` > 0 AND ct.`entry` IN (42188,43027,43028,43029,43038,43164,43165,43166,43167,43597,43640,43649,43978,44051,44133,44135,44228,44229,44281,44282,44290,44772,44900,44938,45083,45091,46139,53744)
) dd ON dd.m = cmi.`DisplayID`;

DELETE FROM `creature_template_addon` WHERE `entry` IN
 (42188,43027,43028,43029,43038,43164,43165,43166,43167,43597,43640,43649,43978,44051,44133,44135,44228,44229,44281,44282,44290,44772,44900,44938,45083,45091,46139,53744);
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT a.`entry`, a.`waypointPathId`, a.`mount`, a.`bytes1`, a.`bytes2`, a.`emote`, a.`visibilityDistanceType`, a.`auras`
FROM `cata_world`.`creature_template_addon` a
WHERE a.`entry` IN (42188,43027,43028,43029,43038,43164,43165,43166,43167,43597,43640,43649,43978,44051,44133,44135,44228,44229,44281,44282,44290,44772,44900,44938,45083,45091,46139,53744);
