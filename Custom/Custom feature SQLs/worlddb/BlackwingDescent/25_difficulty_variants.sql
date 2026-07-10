-- Blackwing Descent (map 669) -- raid-difficulty tier creature_template rows
-- (25-man normal / 10-man heroic / 25-man heroic variants)
--
-- 01_creature_templates.sql imported difficulty_entry_1/2/3 verbatim from cata_world for
-- the base (10-man normal) entries, but never cloned the rows those pointers reference.
-- Creature::InitEntry(...) in src/server/game/Entities/Creature/Creature.cpp silently falls
-- back to the base template when GetCreatureTemplate(DifficultyEntry[diff]) returns null (see
-- ObjectMgr::CheckCreatureTemplate, which logs the gap but does not clear the dangling field),
-- so every BWD encounter has been running the 10N template unmodified on 25N/10H/25H --
-- confirmed live via 36 "difficulty_entry_N ... does not exist" lines in Errors.log.
--
-- All 75 missing target ids exist in cata_world.creature_template, so this is a pure migration
-- gap, not a bad reference. Combat-relevant ability/cooldown scaling is NOT affected by this gap
-- -- the ported boss AI already branches on IsHeroic()/Is25ManRaid()/RAID_MODE<>() directly in
-- C++ (see boss_omnotron_defense_system.cpp, boss_magmaw.cpp, etc.) -- what the dangling chain
-- was actually supposed to provide is the per-difficulty HP/mana/armor/damage pool, which is
-- what this file restores.
--
-- Column split for each new tier row:
--   * identity/behavior columns (name, ScriptName, AIName, flags_extra, unit_flags, lootid, ...)
--     are copied from the ALREADY-DEPLOYED local base entry, not from cata_world -- cata_world's
--     tier rows ship with ScriptName/AIName BLANK (verified), so a raw cata_world clone would
--     leave every boss with NO AI at all on 25N/10H/25H. Inheriting from the local base entry
--     also carries forward the flags_extra 0x200 flight-preservation patch
--     (01_creature_templates.sql line 54) automatically.
--   * genuine per-difficulty stat columns (HealthModifier, ManaModifier, ArmorModifier,
--     ExperienceModifier, DamageModifier, BaseAttackTime, RangeAttackTime, BaseVariance,
--     RangeVariance) are taken from cata_world's tier-specific row -- this is the actual fix.
--   * difficulty_entry_1/2/3 on the new rows are hard-set to 0 (matches cata_world's own data;
--     Creature::InitEntry only ever reads the chain off the originally-spawned entry, so this
--     doesn't matter functionally, but 0 is the correct/clean value regardless).
--
-- creature_template_model is likewise inherited from the local base entry (same visual model
-- across difficulties; also avoids re-doing the retroported-display-id remap from
-- 16_boss_displays.sql). creature_template_resistance/_spell come from cata_world per-tier
-- (legitimate tier-specific data; unused by the named bosses, whose abilities are hardcoded in
-- C++, but may matter for a few auto-cast trash entries).
--
-- Loot (`lootid`) is intentionally inherited from the base entry, not touched here -- heroic-vs-
-- normal loot table selection is a separate, pre-existing topic in 09_loot.sql/10_items.sql.

-- ---------------------------------------------------------------------------
-- creature_template
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461);

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
    SELECT 51101 AS target_id, 41570 AS base_id
    UNION ALL SELECT 51102 AS target_id, 41570 AS base_id
    UNION ALL SELECT 51103 AS target_id, 41570 AS base_id
    UNION ALL SELECT 51104 AS target_id, 41376 AS base_id
    UNION ALL SELECT 51105 AS target_id, 41376 AS base_id
    UNION ALL SELECT 51106 AS target_id, 41376 AS base_id
    UNION ALL SELECT 49974 AS target_id, 41378 AS base_id
    UNION ALL SELECT 49980 AS target_id, 41378 AS base_id
    UNION ALL SELECT 49986 AS target_id, 41378 AS base_id
    UNION ALL SELECT 49583 AS target_id, 41442 AS base_id
    UNION ALL SELECT 49584 AS target_id, 41442 AS base_id
    UNION ALL SELECT 49585 AS target_id, 41442 AS base_id
    UNION ALL SELECT 47774 AS target_id, 43296 AS base_id
    UNION ALL SELECT 47775 AS target_id, 43296 AS base_id
    UNION ALL SELECT 47776 AS target_id, 43296 AS base_id
    UNION ALL SELECT 51116 AS target_id, 41270 AS base_id
    UNION ALL SELECT 51117 AS target_id, 41270 AS base_id
    UNION ALL SELECT 51118 AS target_id, 41270 AS base_id
    UNION ALL SELECT 49973 AS target_id, 41576 AS base_id
    UNION ALL SELECT 49979 AS target_id, 41576 AS base_id
    UNION ALL SELECT 49985 AS target_id, 41576 AS base_id
    UNION ALL SELECT 51456 AS target_id, 41806 AS base_id
    UNION ALL SELECT 51457 AS target_id, 41806 AS base_id
    UNION ALL SELECT 51458 AS target_id, 41806 AS base_id
    UNION ALL SELECT 49975 AS target_id, 41841 AS base_id
    UNION ALL SELECT 49981 AS target_id, 41841 AS base_id
    UNION ALL SELECT 49987 AS target_id, 41841 AS base_id
    UNION ALL SELECT 51119 AS target_id, 41948 AS base_id
    UNION ALL SELECT 51120 AS target_id, 41948 AS base_id
    UNION ALL SELECT 51121 AS target_id, 41948 AS base_id
    UNION ALL SELECT 49056 AS target_id, 42166 AS base_id
    UNION ALL SELECT 49057 AS target_id, 42166 AS base_id
    UNION ALL SELECT 49058 AS target_id, 42166 AS base_id
    UNION ALL SELECT 49053 AS target_id, 42178 AS base_id
    UNION ALL SELECT 49054 AS target_id, 42178 AS base_id
    UNION ALL SELECT 49055 AS target_id, 42178 AS base_id
    UNION ALL SELECT 49047 AS target_id, 42179 AS base_id
    UNION ALL SELECT 49048 AS target_id, 42179 AS base_id
    UNION ALL SELECT 49049 AS target_id, 42179 AS base_id
    UNION ALL SELECT 49050 AS target_id, 42180 AS base_id
    UNION ALL SELECT 49051 AS target_id, 42180 AS base_id
    UNION ALL SELECT 49052 AS target_id, 42180 AS base_id
    UNION ALL SELECT 51459 AS target_id, 42321 AS base_id
    UNION ALL SELECT 51460 AS target_id, 42321 AS base_id
    UNION ALL SELECT 51461 AS target_id, 42321 AS base_id
    UNION ALL SELECT 51248 AS target_id, 42347 AS base_id
    UNION ALL SELECT 51249 AS target_id, 42347 AS base_id
    UNION ALL SELECT 51250 AS target_id, 42347 AS base_id
    UNION ALL SELECT 49121 AS target_id, 42897 AS base_id
    UNION ALL SELECT 49122 AS target_id, 42897 AS base_id
    UNION ALL SELECT 49123 AS target_id, 42897 AS base_id
    UNION ALL SELECT 49118 AS target_id, 42934 AS base_id
    UNION ALL SELECT 49119 AS target_id, 42934 AS base_id
    UNION ALL SELECT 49120 AS target_id, 42934 AS base_id
    UNION ALL SELECT 51251 AS target_id, 48270 AS base_id
    UNION ALL SELECT 51252 AS target_id, 48270 AS base_id
    UNION ALL SELECT 51253 AS target_id, 48270 AS base_id
    UNION ALL SELECT 49482 AS target_id, 49416 AS base_id
    UNION ALL SELECT 49483 AS target_id, 49416 AS base_id
    UNION ALL SELECT 49484 AS target_id, 49416 AS base_id
    UNION ALL SELECT 49976 AS target_id, 49811 AS base_id
    UNION ALL SELECT 49982 AS target_id, 49811 AS base_id
    UNION ALL SELECT 49988 AS target_id, 49811 AS base_id
    UNION ALL SELECT 49489 AS target_id, 42362 AS base_id
    UNION ALL SELECT 49490 AS target_id, 42649 AS base_id
    UNION ALL SELECT 49501 AS target_id, 42800 AS base_id
    UNION ALL SELECT 49504 AS target_id, 43119 AS base_id
    UNION ALL SELECT 49505 AS target_id, 43122 AS base_id
    UNION ALL SELECT 49507 AS target_id, 43125 AS base_id
    UNION ALL SELECT 49508 AS target_id, 43126 AS base_id
    UNION ALL SELECT 49509 AS target_id, 43127 AS base_id
    UNION ALL SELECT 49510 AS target_id, 43128 AS base_id
    UNION ALL SELECT 49511 AS target_id, 43129 AS base_id
    UNION ALL SELECT 49512 AS target_id, 43130 AS base_id
    UNION ALL SELECT 49798 AS target_id, 49740 AS base_id
) m
JOIN `creature_template` base ON base.`entry` = m.base_id
JOIN `cata_world`.`creature_template` cata ON cata.`entry` = m.target_id;

-- ---------------------------------------------------------------------------
-- creature_template_model  (same visual model as the base entry on every difficulty)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461);

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT m.target_id, basemodel.`Idx`, basemodel.`CreatureDisplayID`, basemodel.`DisplayScale`, basemodel.`Probability`, 0
FROM (
    SELECT 51101 AS target_id, 41570 AS base_id
    UNION ALL SELECT 51102 AS target_id, 41570 AS base_id
    UNION ALL SELECT 51103 AS target_id, 41570 AS base_id
    UNION ALL SELECT 51104 AS target_id, 41376 AS base_id
    UNION ALL SELECT 51105 AS target_id, 41376 AS base_id
    UNION ALL SELECT 51106 AS target_id, 41376 AS base_id
    UNION ALL SELECT 49974 AS target_id, 41378 AS base_id
    UNION ALL SELECT 49980 AS target_id, 41378 AS base_id
    UNION ALL SELECT 49986 AS target_id, 41378 AS base_id
    UNION ALL SELECT 49583 AS target_id, 41442 AS base_id
    UNION ALL SELECT 49584 AS target_id, 41442 AS base_id
    UNION ALL SELECT 49585 AS target_id, 41442 AS base_id
    UNION ALL SELECT 47774 AS target_id, 43296 AS base_id
    UNION ALL SELECT 47775 AS target_id, 43296 AS base_id
    UNION ALL SELECT 47776 AS target_id, 43296 AS base_id
    UNION ALL SELECT 51116 AS target_id, 41270 AS base_id
    UNION ALL SELECT 51117 AS target_id, 41270 AS base_id
    UNION ALL SELECT 51118 AS target_id, 41270 AS base_id
    UNION ALL SELECT 49973 AS target_id, 41576 AS base_id
    UNION ALL SELECT 49979 AS target_id, 41576 AS base_id
    UNION ALL SELECT 49985 AS target_id, 41576 AS base_id
    UNION ALL SELECT 51456 AS target_id, 41806 AS base_id
    UNION ALL SELECT 51457 AS target_id, 41806 AS base_id
    UNION ALL SELECT 51458 AS target_id, 41806 AS base_id
    UNION ALL SELECT 49975 AS target_id, 41841 AS base_id
    UNION ALL SELECT 49981 AS target_id, 41841 AS base_id
    UNION ALL SELECT 49987 AS target_id, 41841 AS base_id
    UNION ALL SELECT 51119 AS target_id, 41948 AS base_id
    UNION ALL SELECT 51120 AS target_id, 41948 AS base_id
    UNION ALL SELECT 51121 AS target_id, 41948 AS base_id
    UNION ALL SELECT 49056 AS target_id, 42166 AS base_id
    UNION ALL SELECT 49057 AS target_id, 42166 AS base_id
    UNION ALL SELECT 49058 AS target_id, 42166 AS base_id
    UNION ALL SELECT 49053 AS target_id, 42178 AS base_id
    UNION ALL SELECT 49054 AS target_id, 42178 AS base_id
    UNION ALL SELECT 49055 AS target_id, 42178 AS base_id
    UNION ALL SELECT 49047 AS target_id, 42179 AS base_id
    UNION ALL SELECT 49048 AS target_id, 42179 AS base_id
    UNION ALL SELECT 49049 AS target_id, 42179 AS base_id
    UNION ALL SELECT 49050 AS target_id, 42180 AS base_id
    UNION ALL SELECT 49051 AS target_id, 42180 AS base_id
    UNION ALL SELECT 49052 AS target_id, 42180 AS base_id
    UNION ALL SELECT 51459 AS target_id, 42321 AS base_id
    UNION ALL SELECT 51460 AS target_id, 42321 AS base_id
    UNION ALL SELECT 51461 AS target_id, 42321 AS base_id
    UNION ALL SELECT 51248 AS target_id, 42347 AS base_id
    UNION ALL SELECT 51249 AS target_id, 42347 AS base_id
    UNION ALL SELECT 51250 AS target_id, 42347 AS base_id
    UNION ALL SELECT 49121 AS target_id, 42897 AS base_id
    UNION ALL SELECT 49122 AS target_id, 42897 AS base_id
    UNION ALL SELECT 49123 AS target_id, 42897 AS base_id
    UNION ALL SELECT 49118 AS target_id, 42934 AS base_id
    UNION ALL SELECT 49119 AS target_id, 42934 AS base_id
    UNION ALL SELECT 49120 AS target_id, 42934 AS base_id
    UNION ALL SELECT 51251 AS target_id, 48270 AS base_id
    UNION ALL SELECT 51252 AS target_id, 48270 AS base_id
    UNION ALL SELECT 51253 AS target_id, 48270 AS base_id
    UNION ALL SELECT 49482 AS target_id, 49416 AS base_id
    UNION ALL SELECT 49483 AS target_id, 49416 AS base_id
    UNION ALL SELECT 49484 AS target_id, 49416 AS base_id
    UNION ALL SELECT 49976 AS target_id, 49811 AS base_id
    UNION ALL SELECT 49982 AS target_id, 49811 AS base_id
    UNION ALL SELECT 49988 AS target_id, 49811 AS base_id
    UNION ALL SELECT 49489 AS target_id, 42362 AS base_id
    UNION ALL SELECT 49490 AS target_id, 42649 AS base_id
    UNION ALL SELECT 49501 AS target_id, 42800 AS base_id
    UNION ALL SELECT 49504 AS target_id, 43119 AS base_id
    UNION ALL SELECT 49505 AS target_id, 43122 AS base_id
    UNION ALL SELECT 49507 AS target_id, 43125 AS base_id
    UNION ALL SELECT 49508 AS target_id, 43126 AS base_id
    UNION ALL SELECT 49509 AS target_id, 43127 AS base_id
    UNION ALL SELECT 49510 AS target_id, 43128 AS base_id
    UNION ALL SELECT 49511 AS target_id, 43129 AS base_id
    UNION ALL SELECT 49512 AS target_id, 43130 AS base_id
    UNION ALL SELECT 49798 AS target_id, 49740 AS base_id
) m
JOIN `creature_template_model` basemodel ON basemodel.`CreatureID` = m.base_id;

-- ---------------------------------------------------------------------------
-- creature_template_resistance  (tier-specific values from cata_world; School 1..6)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_resistance` WHERE `CreatureID` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461);

INSERT INTO `creature_template_resistance` (`CreatureID`, `School`, `Resistance`, `VerifiedBuild`)
SELECT ct.`entry`, 1, ct.`resistance1`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance1` <> 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461)
UNION ALL SELECT ct.`entry`, 2, ct.`resistance2`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance2` <> 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461)
UNION ALL SELECT ct.`entry`, 3, ct.`resistance3`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance3` <> 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461)
UNION ALL SELECT ct.`entry`, 4, ct.`resistance4`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance4` <> 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461)
UNION ALL SELECT ct.`entry`, 5, ct.`resistance5`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance5` <> 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461)
UNION ALL SELECT ct.`entry`, 6, ct.`resistance6`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`resistance6` <> 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461);

-- ---------------------------------------------------------------------------
-- creature_template_spell  (tier-specific values from cata_world; Index 0..7)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_spell` WHERE `CreatureID` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461);

INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`)
SELECT ct.`entry`, 0, ct.`spell1`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell1` > 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461)
UNION ALL SELECT ct.`entry`, 1, ct.`spell2`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell2` > 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461)
UNION ALL SELECT ct.`entry`, 2, ct.`spell3`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell3` > 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461)
UNION ALL SELECT ct.`entry`, 3, ct.`spell4`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell4` > 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461)
UNION ALL SELECT ct.`entry`, 4, ct.`spell5`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell5` > 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461)
UNION ALL SELECT ct.`entry`, 5, ct.`spell6`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell6` > 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461)
UNION ALL SELECT ct.`entry`, 6, ct.`spell7`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell7` > 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461)
UNION ALL SELECT ct.`entry`, 7, ct.`spell8`, 0 FROM `cata_world`.`creature_template` ct WHERE ct.`spell8` > 0 AND ct.`entry` IN (47774,47775,47776,49047,49048,49049,49050,49051,49052,49053,49054,49055,49056,49057,49058,49118,49119,49120,49121,49122,49123,49482,49483,49484,49489,49490,49501,49504,49505,49507,49508,49509,49510,49511,49512,49583,49584,49585,49798,49973,49974,49975,49976,49979,49980,49981,49982,49985,49986,49987,49988,51101,51102,51103,51104,51105,51106,51116,51117,51118,51119,51120,51121,51248,51249,51250,51251,51252,51253,51456,51457,51458,51459,51460,51461);
