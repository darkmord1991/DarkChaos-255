-- =====================================================================
-- Deepholm Downport  --  01  Creature definition layer  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4, TDB 22011).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
-- Imports the 307 Deepholm-new creature templates (313 spawned on map 646
-- minus 6 shared/stock infra entries that already exist server-wide).
-- See 00_README.md for the full column-mapping rationale.
--
-- Excluded shared entries (kept as stock, never overwritten):
--   6491 Spirit Healer, 23837/24110/24288/25670 ELM bunnies, 28332 Generic Trigger LAB.
-- =====================================================================

-- ---------------------------------------------------------------------
-- creature_template   (Cata inline columns -> this fork's normalized 55-col schema)
-- ---------------------------------------------------------------------
DELETE FROM `creature_template`
WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND `entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

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
 CASE WHEN ct.`ScriptName` = 'npc_deepholm_xariona' THEN '' ELSE ct.`ScriptName` END,
 ct.`VerifiedBuild`
FROM `cata_world`.`creature_template` ct
WHERE ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

-- ---------------------------------------------------------------------
-- creature_template_model   (inline modelid1-4 + scale -> per-slot rows)
-- ---------------------------------------------------------------------
DELETE FROM `creature_template_model`
WHERE `CreatureID` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND `CreatureID` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`modelid1`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
 WHERE ct.`modelid1` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
UNION ALL
SELECT ct.`entry`, 1, ct.`modelid2`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
 WHERE ct.`modelid2` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
UNION ALL
SELECT ct.`entry`, 2, ct.`modelid3`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
 WHERE ct.`modelid3` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
UNION ALL
SELECT ct.`entry`, 3, ct.`modelid4`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
 WHERE ct.`modelid4` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

-- ---------------------------------------------------------------------
-- creature_model_info   (server bounding/reach/gender for used display ids)
-- INSERT IGNORE: display ids shared with stock keep their existing row.
-- ---------------------------------------------------------------------
INSERT IGNORE INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`)
SELECT cmi.`DisplayID`, cmi.`BoundingRadius`, cmi.`CombatReach`, cmi.`Gender`, cmi.`DisplayID_Other_Gender`, 0
FROM `cata_world`.`creature_model_info` cmi
JOIN (
    SELECT DISTINCT m FROM (
        SELECT ct.`modelid1` AS m FROM `cata_world`.`creature_template` ct WHERE ct.`modelid1` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
        UNION SELECT ct.`modelid2` FROM `cata_world`.`creature_template` ct WHERE ct.`modelid2` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
        UNION SELECT ct.`modelid3` FROM `cata_world`.`creature_template` ct WHERE ct.`modelid3` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
        UNION SELECT ct.`modelid4` FROM `cata_world`.`creature_template` ct WHERE ct.`modelid4` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
    ) u
) dd ON dd.m = cmi.`DisplayID`;

-- ---------------------------------------------------------------------
-- creature_template_spell   (inline spell1-8 -> per-index rows, non-zero only)
-- ---------------------------------------------------------------------
DELETE FROM `creature_template_spell`
WHERE `CreatureID` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND `CreatureID` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`spell1`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell1` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
UNION ALL SELECT ct.`entry`, 1, ct.`spell2`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell2` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
UNION ALL SELECT ct.`entry`, 2, ct.`spell3`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell3` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
UNION ALL SELECT ct.`entry`, 3, ct.`spell4`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell4` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
UNION ALL SELECT ct.`entry`, 4, ct.`spell5`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell5` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
UNION ALL SELECT ct.`entry`, 5, ct.`spell6`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell6` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
UNION ALL SELECT ct.`entry`, 6, ct.`spell7`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell7` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332)
UNION ALL SELECT ct.`entry`, 7, ct.`spell8`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell8` > 0 AND ct.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND ct.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

-- ---------------------------------------------------------------------
-- creature_template_addon   (waypointPathId -> path_id; drop AnimKits/cyclicSpline)
-- ---------------------------------------------------------------------
DELETE FROM `creature_template_addon`
WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND `entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT a.`entry`, a.`waypointPathId`, a.`mount`, a.`bytes1`, a.`bytes2`, a.`emote`, a.`visibilityDistanceType`, a.`auras`
FROM `cata_world`.`creature_template_addon` a
WHERE a.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND a.`entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

-- ---------------------------------------------------------------------
-- creature_template_movement   (add Chase, absent in Cata)
-- ---------------------------------------------------------------------
DELETE FROM `creature_template_movement`
WHERE `CreatureId` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND `CreatureId` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`)
SELECT m.`CreatureId`, m.`Ground`, m.`Swim`, m.`Flight`, m.`Rooted`, 0, m.`Random`, m.`InteractionPauseTimer`
FROM `cata_world`.`creature_template_movement` m
WHERE m.`CreatureId` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND m.`CreatureId` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

-- ---------------------------------------------------------------------
-- creature_equip_template   (identical schema -- straight copy; 0 missing items)
-- ---------------------------------------------------------------------
DELETE FROM `creature_equip_template`
WHERE `CreatureID` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND `CreatureID` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT e.`CreatureID`, e.`ID`, e.`ItemID1`, e.`ItemID2`, e.`ItemID3`, e.`VerifiedBuild`
FROM `cata_world`.`creature_equip_template` e
WHERE e.`CreatureID` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND e.`CreatureID` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);
