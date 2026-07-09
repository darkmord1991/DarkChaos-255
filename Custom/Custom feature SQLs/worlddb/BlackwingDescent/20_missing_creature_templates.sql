-- =====================================================================
-- Blackwing Descent Downport  --  20  Missing creature_template entries
-- ---------------------------------------------------------------------
-- 04_spawns.sql placed 45 creature spawns (guids 9555007-9555051) for
-- entries 47196, 47330, 49801, 53488 that 01_creature_templates.sql never
-- imported, so every one of those spawns failed to load at boot:
--   Table `creature` has creature (SpawnId: N) with non existing creature
--   entry NNNNN in `id` field, skipped.
-- Same cross-schema INSERT...SELECT pattern as 01_creature_templates.sql
-- (keeps retail entry ids; Cata display ids are placeholders -- remap to
-- the retroported 500xxx CreatureDisplayInfo ids after the model bake,
-- same as the rest of the BWD roster).
-- =====================================================================

-- ---------------------------------------------------------------------------
-- creature_template
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (47196,47330,49801,53488);

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
    ct.`name`, ct.`subname`, ct.`IconName`, ct.`gossip_menu_id`, ct.`minlevel`, ct.`maxlevel`, 2, ct.`faction`, ct.`npcflag`,
    ct.`speed_walk`, ct.`speed_run`, 1, 1, 20, ct.`rank`, ct.`dmgschool`,
    ct.`DamageModifier`, ct.`BaseAttackTime`, ct.`RangeAttackTime`, ct.`BaseVariance`, ct.`RangeVariance`, ct.`unit_class`,
    ct.`unit_flags`, ct.`unit_flags2`, 0, ct.`family`, ct.`type`, ct.`type_flags`, ct.`lootid`, ct.`pickpocketloot`,
    ct.`skinloot`, ct.`PetSpellDataId`, ct.`VehicleId`, ct.`mingold`, ct.`maxgold`, ct.`AIName`, ct.`MovementType`, ct.`HoverHeight`,
    ct.`HealthModifier`, ct.`ManaModifier`, ct.`ArmorModifier`, ct.`ExperienceModifier`, ct.`RacialLeader`, ct.`movementId`,
    ct.`RegenHealth`, 0, ct.`flags_extra`, ct.`ScriptName`, 0
FROM `cata_world`.`creature_template` ct
WHERE ct.`entry` IN (47196,47330,49801,53488);

-- ---------------------------------------------------------------------------
-- creature_template_model  (scale -> DisplayScale; Cata display ids are placeholders)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (47196,47330,49801,53488);

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`modelid1`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
    WHERE ct.`modelid1` > 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL
SELECT ct.`entry`, 1, ct.`modelid2`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
    WHERE ct.`modelid2` > 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL
SELECT ct.`entry`, 2, ct.`modelid3`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
    WHERE ct.`modelid3` > 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL
SELECT ct.`entry`, 3, ct.`modelid4`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
    WHERE ct.`modelid4` > 0 AND ct.`entry` IN (47196,47330,49801,53488);

-- ---------------------------------------------------------------------------
-- creature_template_resistance  (resistance1..6 -> School 1..6)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_resistance` WHERE `CreatureID` IN (47196,47330,49801,53488);

INSERT INTO `creature_template_resistance` (`CreatureID`, `School`, `Resistance`, `VerifiedBuild`)
SELECT ct.`entry`, 1, ct.`resistance1`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance1` <> 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL SELECT ct.`entry`, 2, ct.`resistance2`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance2` <> 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL SELECT ct.`entry`, 3, ct.`resistance3`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance3` <> 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL SELECT ct.`entry`, 4, ct.`resistance4`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance4` <> 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL SELECT ct.`entry`, 5, ct.`resistance5`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance5` <> 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL SELECT ct.`entry`, 6, ct.`resistance6`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance6` <> 0 AND ct.`entry` IN (47196,47330,49801,53488);

-- ---------------------------------------------------------------------------
-- creature_template_spell  (spell1..8 -> Index 0..7)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_spell` WHERE `CreatureID` IN (47196,47330,49801,53488);

INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`spell1`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell1` > 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL SELECT ct.`entry`, 1, ct.`spell2`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell2` > 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL SELECT ct.`entry`, 2, ct.`spell3`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell3` > 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL SELECT ct.`entry`, 3, ct.`spell4`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell4` > 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL SELECT ct.`entry`, 4, ct.`spell5`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell5` > 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL SELECT ct.`entry`, 5, ct.`spell6`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell6` > 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL SELECT ct.`entry`, 6, ct.`spell7`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell7` > 0 AND ct.`entry` IN (47196,47330,49801,53488)
UNION ALL SELECT ct.`entry`, 7, ct.`spell8`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell8` > 0 AND ct.`entry` IN (47196,47330,49801,53488);

-- ---------------------------------------------------------------------------
-- RETRACTED (see 21_summon_group_creature_templates.sql): 43404/43407 have
-- zero static `creature` rows, but ARE referenced by the map-669
-- creature_summon_groups entry alongside 43396/43400/43401/43402 (dynamic
-- TempSummon, which never appears in `creature`) -- so "never instantiated"
-- was not established, and blanking AIName here risked silently disabling
-- their SmartAI if that summon group actually fires. Left as-is
-- (AIName='SmartAI', still zero smart_scripts rows, still logs the boot
-- warning) until someone confirms whether/how that summon group triggers.
-- ---------------------------------------------------------------------------
