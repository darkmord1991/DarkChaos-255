-- =====================================================================
-- Molten Front -- 74  Missing entity backfill (Avengers of Hyjal daily/vehicle NPCs)
-- ---------------------------------------------------------------------
-- 01_creature_templates.sql / 02_gameobject_templates.sql only cloned from
-- cata_world entries with a `creature`/`gameobject` spawn row under
-- map=1/zoneId=616 (Hyjal proper). These 7 creatures + 2 gameobjects are
-- summon-only (no static spawn anywhere in cata_world either -- they're
-- driven by the Aessina's Miracle vehicle / Wings of Aviana daily / Ancient
-- Primal Altar C++ scripts already compiled into zone_mount_hyjal.cpp), so
-- that zone-scoped subquery never picked them up. Surfaced as
-- "SmartAIMgr: ... uses non-existent Creature/GameObject entry N, skipped"
-- boot-log errors on 2026-07-13. Direct entry-list clone, same +3,600,000
-- offset scheme and column set as 01_/02_.
--   40000 Injured Fawn              40288 Rescued Bear Cub
--   40719 Aviana's Guardian         40805 Arch Druid Hamuul Runetotem
--   41459 Player Float Vehicle      41581 Child of Tortolla
--   41632 Malfurion Stormrage       53009 Kalecgos (quest-ender variant)
--   203083 Manipulator's Portal Spell Effect (Fire)
--   203085 Manipulator's Portal Spell Effect (Air)
-- 53009 is a second "Kalecgos" entry (the questender-only phased variant of
-- 52995/3652995, already ported) needed by 75_molten_front_delegation_vow.sql.
-- Display 38490/32524 (Kalecgos variant / Child of Tortolla) reused existing
-- stock ModelIDs (2698 DragonKalecgos, 501041 Turtle) already in this
-- project's CreatureDisplayInfo.csv -- no new model/texture extraction.
-- =====================================================================
SET @OFF := 3600000;

INSERT IGNORE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`
FROM `cata_world`.`creature_template`
WHERE `entry` IN (40000,40288,40719,40805,41459,41581,41632,53009);

INSERT IGNORE INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `Probability`, `VerifiedBuild`)
SELECT `CreatureID`+@OFF, `Idx`, `CreatureDisplayID`, `Probability`, `VerifiedBuild`
FROM `cata_world`.`creature_template_model`
WHERE `CreatureID` IN (40000,40288,40719,40805,41459,41581,41632,53009);

INSERT IGNORE INTO `creature_template_addon` (`entry`, `mount`, `emote`, `visibilityDistanceType`, `auras`)
SELECT `entry`+@OFF, `mount`, `emote`, `visibilityDistanceType`, `auras`
FROM `cata_world`.`creature_template_addon`
WHERE `entry` IN (40000,40288,40719,40805,41459,41581,41632,53009);

INSERT IGNORE INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`
FROM `cata_world`.`gameobject_template`
WHERE `entry` IN (203083,203085);

INSERT IGNORE INTO `gameobject_template_addon` (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT `entry`+@OFF, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`
FROM `cata_world`.`gameobject_template_addon`
WHERE `entry` IN (203083,203085);
