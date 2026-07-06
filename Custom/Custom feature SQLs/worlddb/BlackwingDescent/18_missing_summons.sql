-- Two script-summoned BWD creatures missed by the 82-entry template port (boot error:
-- "Script named 'npc_maloriak_magma_jet' / 'npc_nefarians_end_animated_bone_warrior' is not
-- assigned in the database"): 50030 Magma Jet (Maloriak) + 41918 Animated Bone Warrior
-- (Nefarian's End). Same cross-schema clone pattern as 01_creature_templates.sql.

DELETE FROM `creature_template` WHERE `entry` IN (41918, 50030);
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
    ct.`entry`, ct.`difficulty_entry_1`, ct.`difficulty_entry_2`, ct.`difficulty_entry_3`, ct.`KillCredit1`, ct.`KillCredit2`,
    ct.`name`, ct.`subname`, ct.`IconName`, ct.`gossip_menu_id`, ct.`minlevel`, ct.`maxlevel`, 2, ct.`faction`, COALESCE(ct.`npcflag`, 0),
    ct.`speed_walk`, ct.`speed_run`, 1, 1, 20, ct.`rank`, ct.`dmgschool`,
    ct.`DamageModifier`, ct.`BaseAttackTime`, ct.`RangeAttackTime`, ct.`BaseVariance`, ct.`RangeVariance`, ct.`unit_class`,
    COALESCE(ct.`unit_flags`, 0), COALESCE(ct.`unit_flags2`, 0), 0, ct.`family`, ct.`type`, ct.`type_flags`, ct.`lootid`, ct.`pickpocketloot`,
    ct.`skinloot`, ct.`PetSpellDataId`, ct.`VehicleId`, ct.`mingold`, ct.`maxgold`, ct.`AIName`, ct.`MovementType`, ct.`HoverHeight`,
    ct.`HealthModifier`, ct.`ManaModifier`, ct.`ArmorModifier`, ct.`ExperienceModifier`, ct.`RacialLeader`, ct.`movementId`,
    ct.`RegenHealth`, 0, ct.`flags_extra`, ct.`ScriptName`, 0
FROM `cata_world`.`creature_template` ct
WHERE ct.`entry` IN (41918, 50030);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (41918, 50030);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`modelid1`, ct.`scale`, 1, 0
FROM `cata_world`.`creature_template` ct
WHERE ct.`modelid1` > 0 AND ct.`entry` IN (41918, 50030);

-- creature_model_info for their displays (missing-only import, mirrors 07)
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`)
SELECT cmi.`DisplayID`, cmi.`BoundingRadius`, cmi.`CombatReach`, cmi.`Gender`, cmi.`DisplayID_Other_Gender`, 0
FROM `cata_world`.`creature_model_info` cmi
WHERE cmi.`DisplayID` IN (
    SELECT `modelid1` FROM `cata_world`.`creature_template` WHERE `modelid1` > 0 AND `entry` IN (41918, 50030))
  AND NOT EXISTS (SELECT 1 FROM `creature_model_info` a WHERE a.`DisplayID` = cmi.`DisplayID`);

-- The DC client patch (patch-2) overrides the stock northrenddrake model with a broken HD retroport
-- (vertex explosion regardless of textures). Repoint the 3 BWD rares to stock proto-drake displays.
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (42764, 42767, 42768);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (42764, 0, 28044, 1.6, 1, 0),   -- Pyrecraw: red proto-drake
    (42767, 0, 28040, 1.6, 1, 0),   -- Ivoroc: black proto-drake
    (42768, 0, 28045, 1.5, 1, 0);   -- Maimgor: bronze proto-drake
