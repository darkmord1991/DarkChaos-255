-- =====================================================================
-- Blackwing Descent Downport  --  21  creature_summon_groups fixes
-- ---------------------------------------------------------------------
-- 6 more Cata 4.3.4 entries referenced by creature_summon_groups (dynamic
-- TempSummon, never appears in the static `creature` table -- a different
-- gap class than 20_'s static-spawn orphans) but missing from
-- acore_world.creature_template, logging at boot:
--   Table `creature_summon_groups` has creature in group [Summoner ID: 669,
--   Summoner Type: 2 (map), Group ID: 0] with non existing creature entry
--   43396/43400/43401/43402, skipped.
--   Table `creature_summon_groups` has creature in group [Summoner ID:
--   41378 (Maloriak), Summoner Type: 0, Group ID: 0] with non existing
--   creature entry 41440, skipped.
--   Table `creature_summon_groups` has creature in group [Summoner ID:
--   41376 (Nefarian), Summoner Type: 0, Group ID: 0] with non existing
--   creature entry 42844, skipped.
-- Same cross-schema INSERT...SELECT pattern as 01_/20_.
--
-- Also RESTORES AIName='SmartAI' on 43404/43407 (undoes 20_'s blanking):
-- both are summoned by the SAME map-669 group 0 as 43396/43400/43401/43402
-- above, so "never instantiated" (20_'s stated reason for blanking) doesn't
-- hold -- they're TempSummons, which is exactly why they have no static
-- `creature` row to begin with. Restoring is a no-op either way at runtime
-- (both still have zero smart_scripts rows -- SmartAI with no rules and no
-- AIName both just auto-attack) but keeps the data honest about which
-- entries this group actually uses.
-- =====================================================================

-- ---------------------------------------------------------------------------
-- creature_template
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (43396,43400,43401,43402,41440,42844);

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
WHERE ct.`entry` IN (43396,43400,43401,43402,41440,42844);

-- ---------------------------------------------------------------------------
-- creature_template_model  (scale -> DisplayScale; Cata display ids are placeholders)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (43396,43400,43401,43402,41440,42844);

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`modelid1`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
    WHERE ct.`modelid1` > 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL
SELECT ct.`entry`, 1, ct.`modelid2`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
    WHERE ct.`modelid2` > 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL
SELECT ct.`entry`, 2, ct.`modelid3`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
    WHERE ct.`modelid3` > 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL
SELECT ct.`entry`, 3, ct.`modelid4`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
    WHERE ct.`modelid4` > 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844);

-- ---------------------------------------------------------------------------
-- creature_template_resistance  (resistance1..6 -> School 1..6)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_resistance` WHERE `CreatureID` IN (43396,43400,43401,43402,41440,42844);

INSERT INTO `creature_template_resistance` (`CreatureID`, `School`, `Resistance`, `VerifiedBuild`)
SELECT ct.`entry`, 1, ct.`resistance1`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance1` <> 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL SELECT ct.`entry`, 2, ct.`resistance2`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance2` <> 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL SELECT ct.`entry`, 3, ct.`resistance3`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance3` <> 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL SELECT ct.`entry`, 4, ct.`resistance4`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance4` <> 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL SELECT ct.`entry`, 5, ct.`resistance5`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance5` <> 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL SELECT ct.`entry`, 6, ct.`resistance6`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance6` <> 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844);

-- ---------------------------------------------------------------------------
-- creature_template_spell  (spell1..8 -> Index 0..7)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_spell` WHERE `CreatureID` IN (43396,43400,43401,43402,41440,42844);

INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`spell1`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell1` > 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL SELECT ct.`entry`, 1, ct.`spell2`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell2` > 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL SELECT ct.`entry`, 2, ct.`spell3`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell3` > 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL SELECT ct.`entry`, 3, ct.`spell4`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell4` > 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL SELECT ct.`entry`, 4, ct.`spell5`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell5` > 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL SELECT ct.`entry`, 5, ct.`spell6`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell6` > 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL SELECT ct.`entry`, 6, ct.`spell7`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell7` > 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844)
UNION ALL SELECT ct.`entry`, 7, ct.`spell8`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell8` > 0 AND ct.`entry` IN (43396,43400,43401,43402,41440,42844);

-- ---------------------------------------------------------------------------
-- Restore AIName on 43404/43407 (see comment above; undoes 20_'s blanking)
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `entry` IN (43404,43407) AND `AIName` = '';
