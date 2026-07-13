-- ---------------------------------------------------------------------------
-- Blackwing Descent (map 669) -- raid-difficulty tier creature_template rows (round 2)
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13): 3 more dangling difficulty_entry_1
-- targets missed by 25_difficulty_variants.sql's original 75-entry sweep --
-- "Creature (Entry: N) has difficulty_entry_1=M but creature entry M does not
-- exist." Same root cause, same fix pattern exactly (identity/behavior columns
-- inherited from the already-deployed local base entry; genuine per-difficulty
-- stat columns from cata_world's tier row; difficulty_entry_1/2/3 hard-set to 0
-- on the new rows, matching cata_world's own data).
--   39666 <- base 39665 "Rom'ogg Bonecrusher"
--   49971 <- base 41440 "Aberration"
--   49654 <- base 42188 "Ozruk"
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (39666,49971,49654);

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
    m.target_id, 0, 0, 0, base.`KillCredit1`, base.`KillCredit2`,
    base.`name`, base.`subname`, base.`IconName`, base.`gossip_menu_id`, base.`minlevel`, base.`maxlevel`, base.`exp`, base.`faction`, base.`npcflag`,
    base.`speed_walk`, base.`speed_run`, base.`speed_swim`, base.`speed_flight`, base.`detection_range`, base.`rank`, base.`dmgschool`,
    cata.`DamageModifier`, cata.`BaseAttackTime`, cata.`RangeAttackTime`, cata.`BaseVariance`, cata.`RangeVariance`, base.`unit_class`,
    base.`unit_flags`, base.`unit_flags2`, base.`dynamicflags`, base.`family`, base.`type`, base.`type_flags`, base.`lootid`, base.`pickpocketloot`,
    base.`skinloot`, base.`PetSpellDataId`, base.`VehicleId`, base.`mingold`, base.`maxgold`, base.`AIName`, base.`MovementType`, base.`HoverHeight`,
    cata.`HealthModifier`, cata.`ManaModifier`, cata.`ArmorModifier`, cata.`ExperienceModifier`, base.`RacialLeader`, base.`movementId`,
    base.`RegenHealth`, base.`CreatureImmunitiesId`, base.`flags_extra`, base.`ScriptName`, 0
FROM (
    SELECT 39666 AS target_id, 39665 AS base_id
    UNION ALL SELECT 49971 AS target_id, 41440 AS base_id
    UNION ALL SELECT 49654 AS target_id, 42188 AS base_id
) m
JOIN `creature_template` base ON base.`entry` = m.base_id
JOIN `cata_world`.`creature_template` cata ON cata.`entry` = m.target_id;

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (39666,49971,49654);

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT m.target_id, basemodel.`Idx`, basemodel.`CreatureDisplayID`, basemodel.`DisplayScale`, basemodel.`Probability`, 0
FROM (
    SELECT 39666 AS target_id, 39665 AS base_id
    UNION ALL SELECT 49971 AS target_id, 41440 AS base_id
    UNION ALL SELECT 49654 AS target_id, 42188 AS base_id
) m
JOIN `creature_template_model` basemodel ON basemodel.`CreatureID` = m.base_id;

DELETE FROM `creature_template_resistance` WHERE `CreatureID` IN (39666,49971,49654);

INSERT INTO `creature_template_resistance` (`CreatureID`, `School`, `Resistance`, `VerifiedBuild`)
SELECT ct.`entry`, 1, ct.`resistance1`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance1` <> 0 AND ct.`entry` IN (39666,49971,49654)
UNION ALL SELECT ct.`entry`, 2, ct.`resistance2`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance2` <> 0 AND ct.`entry` IN (39666,49971,49654)
UNION ALL SELECT ct.`entry`, 3, ct.`resistance3`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance3` <> 0 AND ct.`entry` IN (39666,49971,49654)
UNION ALL SELECT ct.`entry`, 4, ct.`resistance4`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance4` <> 0 AND ct.`entry` IN (39666,49971,49654)
UNION ALL SELECT ct.`entry`, 5, ct.`resistance5`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance5` <> 0 AND ct.`entry` IN (39666,49971,49654)
UNION ALL SELECT ct.`entry`, 6, ct.`resistance6`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance6` <> 0 AND ct.`entry` IN (39666,49971,49654);

DELETE FROM `creature_template_spell` WHERE `CreatureID` IN (39666,49971,49654);

INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`spell1`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell1` > 0 AND ct.`entry` IN (39666,49971,49654)
UNION ALL SELECT ct.`entry`, 1, ct.`spell2`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell2` > 0 AND ct.`entry` IN (39666,49971,49654)
UNION ALL SELECT ct.`entry`, 2, ct.`spell3`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell3` > 0 AND ct.`entry` IN (39666,49971,49654)
UNION ALL SELECT ct.`entry`, 3, ct.`spell4`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell4` > 0 AND ct.`entry` IN (39666,49971,49654);
