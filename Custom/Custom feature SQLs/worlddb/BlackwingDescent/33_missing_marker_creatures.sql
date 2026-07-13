-- ---------------------------------------------------------------------------
-- 2 missing marker creatures surfaced via `conditions` (Atramedes/Nefarian's End)
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13, ultracode workflow investigation):
-- "ObjectEntryGuid condition has non existing creature template entry (42001)"
-- and same for (43210). Both are summon-target marker NPCs for already-live
-- BWD boss spells (78431 "Roaring Flame Breath Fire Periodic" -> targets
-- 42001 "Reverberating Flame"; 85176 "Execution Sentence" -> targets 43210
-- "Execution Sentence") -- plain omissions from 01_creature_templates.sql's
-- static entry-id list (it has their near-identical siblings 41962/43206 but
-- skipped these two). The `conditions` rows referencing them are correct and
-- were NOT touched -- only the missing creature_template rows are added here.
-- Cross-DB INSERT...SELECT straight from cata_world.creature_template, same
-- pattern/schema mapping as 01_creature_templates.sql (both entries confirmed
-- present there with resistance1..6 = 0 and spell1..8 = 0, so no
-- creature_template_resistance/creature_template_spell rows are needed, same
-- as their siblings 41962/43206).
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (42001,43210);

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
WHERE ct.`entry` IN (42001,43210);

-- ---------------------------------------------------------------------------
-- creature_template_model  (scale -> DisplayScale; modelid1/modelid2 -> Idx 0/1)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (42001,43210);

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`modelid1`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
    WHERE ct.`modelid1` > 0 AND ct.`entry` IN (42001,43210)
UNION ALL
SELECT ct.`entry`, 1, ct.`modelid2`, ct.`scale`, 1, 0 FROM `cata_world`.`creature_template` ct
    WHERE ct.`modelid2` > 0 AND ct.`entry` IN (42001,43210);
