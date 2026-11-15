-- DarkChaos: map 750 - Winterspring and Mount Hyjal Cata quests ported, dead quests repaired (2026-11-14)
--
-- Why: Winterspring (104-113) gave 48% and Hyjal (113-130) 56% of the quest XP those levels need.
--
-- 1. Imported from cata_world (8 quests): 28638 The Owls Have It, 28513 Pride of the Highborne,
--    28534 Descendants of the Highborne, 28535 Descendants of the High Elves, 28519 Pain of the Blood Elves,
--    28524 Delivery for Donova, 28842 Umbranse's Deliverance (Winterspring), 25328 Gar'gol's Gotta Go (Hyjal).
-- 2. Everlook hunters: the five finales had only the hostile rare as giver (Cata auto-accept on sight; AC never
--    offers a quest from a hostile NPC). Jez Goodgrub / Francis Morcott / Jeb Guthrie now give them, the mob
--    starter rows go and the mobs lose UNIT_NPC_FLAG_QUESTGIVER. Jeb's chain 28638 -> 28745 -> 28782 was
--    remote turn-in in Cata (no ender in TDB), so Jeb takes the turn-ins; 28745 was retired by 195_ for that.
-- 3. Kel'Theril: Kaldorei, Quel'dorei and Sin'dorei Spirit (3748658-3748660, new copies with stock 3.3.5 ghost
--    displays; Cata's displays are not in the client) stand at the Cata POI points. 28479 -> 28513 -> 28534 ->
--    28535 -> 28519 -> 28536 runs again and opens the existing 28537 / 28848. 28518 needs item 64441, which has
--    no Item.dbc row, so 28535 follows 28534 directly.
-- 4. Felwood 28221 / 28224: the Sapling Protector (Cata: a personal summon) stands on the Irontree Woods island
--    and gives and takes both; the dead Seedling quests 28219 / 28220 no longer gate 28221.
-- 5. Mount Hyjal: 25316 As Hyjal Burns had no giver, and every later step of the Nordrassil story (25317 ->
--    ... -> 25584 -> the Shrine of Goldrinn, 22 offered quests) required it, so none could be taken. Emissary
--    Windsong (3639865) now stands at her Cata spot in Nighthaven. At the Shrine of Goldrinn: Lycanthoth
--    (3639446, static, 120 s) by his altar so 25272 / 25273 can be done without the incense summon, and static
--    questgiver copies of the Spirits of Goldrinn / Lo'Gosh (3739622 / 3739627; the 36396xx ones are the
--    scripted ride vehicles and drop their quest flag when summoned) in the Maw and on the Lightning Ledge take
--    25272 / 25273 / 25353 / 25355 and give 25279 / 25280 (which open 25277 / 25278). Kristoff Manheim is
--    spawned in Gar'gol's Hovel for 25328; his escort 25332 has no script or path, so he stops offering it.
--
-- Conventions: QuestLevel -1, MinLevel = band low (Winterspring 104, Hyjal 113, Felwood 96; the Everlook hunter
-- finales stay at 101 like their first steps and the Hyjal chain at 110), Cata RewardXPDifficulty, Cata flag
-- 0x10000 (remote turn-in = AC auto-complete) removed, gold by the 11-10 formula and never lowered, gear through
-- the 750 ladder (no new items), turn-in markers on the ender spawns, small objective polygons, none in caves.
-- Quest-target rares, the Wretched Spirit pool and the Winterspring owls / screechers respawn in 120 s.
-- Revert record: dc_backup_20261114_wshyjal_quest (first-run values of the existing quests).
--
-- Apply to acore_world (it reads cata_world on the same server), then restart the worldserver.

CREATE TABLE IF NOT EXISTS `dc_backup_20261114_wshyjal_quest` (
    `ID` INT UNSIGNED NOT NULL,
    `QuestLevel` INT NOT NULL,
    `MinLevel` INT NOT NULL,
    `Flags` INT NOT NULL,
    `RewardMoney` INT NOT NULL,
    `RewardNextQuest` INT NOT NULL,
    `RequiredNpcOrGo1` INT NOT NULL,
    `PrevQuestID` INT NOT NULL,
    `NextQuestID` INT NOT NULL,
    PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- first run only (INSERT IGNORE keeps the originals on a re-run; the DELETE removes nothing)
DELETE FROM `dc_backup_20261114_wshyjal_quest` WHERE `ID` = 0;
INSERT IGNORE INTO `dc_backup_20261114_wshyjal_quest` (
    `ID`, `QuestLevel`, `MinLevel`, `Flags`, `RewardMoney`, `RewardNextQuest`, `RequiredNpcOrGo1`, `PrevQuestID`,
    `NextQuestID`)
SELECT
    `t`.`ID`, `t`.`QuestLevel`, `t`.`MinLevel`, `t`.`Flags`, `t`.`RewardMoney`, `t`.`RewardNextQuest`,
    `t`.`RequiredNpcOrGo1`, `a`.`PrevQuestID`, `a`.`NextQuestID`
FROM `quest_template` AS `t`
JOIN `quest_template_addon` AS `a` ON `a`.`ID` = `t`.`ID`
WHERE `t`.`ID` IN (25272, 25273, 25279, 25280, 25316, 25353, 25355, 28219, 28220, 28221, 28224, 28479, 28536, 28639,
    28641, 28719, 28745, 28782);

-- 1. new templates (REPLACE: creature_template rows are never deleted), copied from a map-750 base row
-- 3639865 Emissary Windsong (base 3710920)
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
    3639865, 0, 0, 0, 0, 0, 'Emissary Windsong', '', '', 0, 115, 115, 2, 35, 2, `t`.`speed_walk`, `t`.`speed_run`,
    `t`.`speed_swim`, `t`.`speed_flight`, `t`.`detection_range`, 0, `t`.`dmgschool`, `t`.`DamageModifier`,
    `t`.`BaseAttackTime`, `t`.`RangeAttackTime`, `t`.`BaseVariance`, `t`.`RangeVariance`, 8, `t`.`unit_flags`,
    `t`.`unit_flags2`, 0, 0, 7, 0, `t`.`lootid`, `t`.`pickpocketloot`, `t`.`skinloot`, 0, 0, `t`.`mingold`,
    `t`.`maxgold`, '', 0, `t`.`HoverHeight`, `t`.`HealthModifier`, `t`.`ManaModifier`, `t`.`ArmorModifier`,
    `t`.`ExperienceModifier`, `t`.`RacialLeader`, `t`.`movementId`, `t`.`RegenHealth`, `t`.`CreatureImmunitiesId`,
    `t`.`flags_extra`, '', 0
FROM `creature_template` AS `t`
WHERE `t`.`entry` = 3710920;

-- 3739622 Spirit of Lo'Gosh (base 3710920)
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
    3739622, 0, 0, 0, 0, 0, 'Spirit of Lo''Gosh', '', '', 0, 115, 115, 2, 35, 2, `t`.`speed_walk`, `t`.`speed_run`,
    `t`.`speed_swim`, `t`.`speed_flight`, `t`.`detection_range`, 0, `t`.`dmgschool`, `t`.`DamageModifier`,
    `t`.`BaseAttackTime`, `t`.`RangeAttackTime`, `t`.`BaseVariance`, `t`.`RangeVariance`, 1, `t`.`unit_flags`,
    `t`.`unit_flags2`, 0, 0, 10, 0, `t`.`lootid`, `t`.`pickpocketloot`, `t`.`skinloot`, 0, 0, `t`.`mingold`,
    `t`.`maxgold`, '', 0, `t`.`HoverHeight`, `t`.`HealthModifier`, `t`.`ManaModifier`, `t`.`ArmorModifier`,
    `t`.`ExperienceModifier`, `t`.`RacialLeader`, `t`.`movementId`, `t`.`RegenHealth`, `t`.`CreatureImmunitiesId`,
    `t`.`flags_extra`, '', 0
FROM `creature_template` AS `t`
WHERE `t`.`entry` = 3710920;

-- 3739627 Spirit of Goldrinn (base 3710920)
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
    3739627, 0, 0, 0, 0, 0, 'Spirit of Goldrinn', '', '', 0, 115, 115, 2, 35, 2, `t`.`speed_walk`, `t`.`speed_run`,
    `t`.`speed_swim`, `t`.`speed_flight`, `t`.`detection_range`, 0, `t`.`dmgschool`, `t`.`DamageModifier`,
    `t`.`BaseAttackTime`, `t`.`RangeAttackTime`, `t`.`BaseVariance`, `t`.`RangeVariance`, 1, `t`.`unit_flags`,
    `t`.`unit_flags2`, 0, 0, 10, 0, `t`.`lootid`, `t`.`pickpocketloot`, `t`.`skinloot`, 0, 0, `t`.`mingold`,
    `t`.`maxgold`, '', 0, `t`.`HoverHeight`, `t`.`HealthModifier`, `t`.`ManaModifier`, `t`.`ArmorModifier`,
    `t`.`ExperienceModifier`, `t`.`RacialLeader`, `t`.`movementId`, `t`.`RegenHealth`, `t`.`CreatureImmunitiesId`,
    `t`.`flags_extra`, '', 0
FROM `creature_template` AS `t`
WHERE `t`.`entry` = 3710920;

-- 3748658 Kaldorei Spirit (base 3710920)
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
    3748658, 0, 0, 0, 0, 0, 'Kaldorei Spirit', '', '', 0, 115, 115, 2, 35, 2, `t`.`speed_walk`, `t`.`speed_run`,
    `t`.`speed_swim`, `t`.`speed_flight`, `t`.`detection_range`, 0, `t`.`dmgschool`, `t`.`DamageModifier`,
    `t`.`BaseAttackTime`, `t`.`RangeAttackTime`, `t`.`BaseVariance`, `t`.`RangeVariance`, 2, `t`.`unit_flags`,
    `t`.`unit_flags2`, 0, 0, 7, 0, `t`.`lootid`, `t`.`pickpocketloot`, `t`.`skinloot`, 0, 0, `t`.`mingold`,
    `t`.`maxgold`, '', 0, `t`.`HoverHeight`, `t`.`HealthModifier`, `t`.`ManaModifier`, `t`.`ArmorModifier`,
    `t`.`ExperienceModifier`, `t`.`RacialLeader`, `t`.`movementId`, `t`.`RegenHealth`, `t`.`CreatureImmunitiesId`,
    `t`.`flags_extra`, '', 0
FROM `creature_template` AS `t`
WHERE `t`.`entry` = 3710920;

-- 3748659 Quel'dorei Spirit (base 3710920)
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
    3748659, 0, 0, 0, 0, 0, 'Quel''dorei Spirit', '', '', 0, 115, 115, 2, 35, 2, `t`.`speed_walk`, `t`.`speed_run`,
    `t`.`speed_swim`, `t`.`speed_flight`, `t`.`detection_range`, 0, `t`.`dmgschool`, `t`.`DamageModifier`,
    `t`.`BaseAttackTime`, `t`.`RangeAttackTime`, `t`.`BaseVariance`, `t`.`RangeVariance`, 2, `t`.`unit_flags`,
    `t`.`unit_flags2`, 0, 0, 7, 0, `t`.`lootid`, `t`.`pickpocketloot`, `t`.`skinloot`, 0, 0, `t`.`mingold`,
    `t`.`maxgold`, '', 0, `t`.`HoverHeight`, `t`.`HealthModifier`, `t`.`ManaModifier`, `t`.`ArmorModifier`,
    `t`.`ExperienceModifier`, `t`.`RacialLeader`, `t`.`movementId`, `t`.`RegenHealth`, `t`.`CreatureImmunitiesId`,
    `t`.`flags_extra`, '', 0
FROM `creature_template` AS `t`
WHERE `t`.`entry` = 3710920;

-- 3748660 Sin'dorei Spirit (base 3710920)
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
    3748660, 0, 0, 0, 0, 0, 'Sin''dorei Spirit', '', '', 0, 115, 115, 2, 35, 2, `t`.`speed_walk`, `t`.`speed_run`,
    `t`.`speed_swim`, `t`.`speed_flight`, `t`.`detection_range`, 0, `t`.`dmgschool`, `t`.`DamageModifier`,
    `t`.`BaseAttackTime`, `t`.`RangeAttackTime`, `t`.`BaseVariance`, `t`.`RangeVariance`, 2, `t`.`unit_flags`,
    `t`.`unit_flags2`, 0, 0, 7, 0, `t`.`lootid`, `t`.`pickpocketloot`, `t`.`skinloot`, 0, 0, `t`.`mingold`,
    `t`.`maxgold`, '', 0, `t`.`HoverHeight`, `t`.`HealthModifier`, `t`.`ManaModifier`, `t`.`ArmorModifier`,
    `t`.`ExperienceModifier`, `t`.`RacialLeader`, `t`.`movementId`, `t`.`RegenHealth`, `t`.`CreatureImmunitiesId`,
    `t`.`flags_extra`, '', 0
FROM `creature_template` AS `t`
WHERE `t`.`entry` = 3710920;

-- 3639446 Lycanthoth (base 3639445)
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
    3639446, 0, 0, 0, 0, 0, 'Lycanthoth', '', '', 0, 115, 115, 2, 14, 0, `t`.`speed_walk`, `t`.`speed_run`,
    `t`.`speed_swim`, `t`.`speed_flight`, `t`.`detection_range`, 0, `t`.`dmgschool`, 1.5, `t`.`BaseAttackTime`,
    `t`.`RangeAttackTime`, `t`.`BaseVariance`, `t`.`RangeVariance`, 1, `t`.`unit_flags`, `t`.`unit_flags2`, 0, 0, 7,
    0, 0, 0, 0, 0, 0, `t`.`mingold`, `t`.`maxgold`, '', 0, `t`.`HoverHeight`, 3, `t`.`ManaModifier`,
    `t`.`ArmorModifier`, `t`.`ExperienceModifier`, `t`.`RacialLeader`, `t`.`movementId`, `t`.`RegenHealth`,
    `t`.`CreatureImmunitiesId`, 0, '', 0
FROM `creature_template` AS `t`
WHERE `t`.`entry` = 3639445;

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (3639446, 3639865, 3739622, 3739627);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`,
    `VerifiedBuild`) VALUES
(3639865, 0, 15321, 1, 1, 0),
(3739622, 0, 23990, 1, 1, 0),
(3739627, 0, 23990, 1, 1, 0),
(3639446, 0, 31488, 1, 1, 0);
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (3748658, 3748659, 3748660);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`,
    `VerifiedBuild`) VALUES
(3748658, 0, 14397, 1, 1, 0),
(3748659, 0, 16124, 1, 1, 0),
(3748660, 0, 17305, 1, 1, 0);

-- Kristoff Manheim: Cata faction 2252 is not in the 3.3.5 FactionTemplate.dbc (the core falls back to 35)
UPDATE `creature_template` SET `faction` = 35, `minlevel` = 115, `maxlevel` = 115 WHERE `entry` = 3639640;
-- Sapling Protector: Cata level 47 -> Felwood band
UPDATE `creature_template` SET `minlevel` = 100, `maxlevel` = 100, `exp` = 2 WHERE `entry` = 3748042;
-- Anguished Highborne count for Pride of the Highborne, as in Cata (7524 KillCredit1 = 7523)
UPDATE `creature_template` SET `KillCredit1` = 3707523 WHERE `entry` = 3707524 AND `KillCredit1` = 0;
-- hostile rares / mobs that lose their auto-accept starter rows (they start nothing else)
UPDATE `creature_template` SET `npcflag` = `npcflag` & ~2
WHERE `entry` IN (3707139, 3707149, 3707434, 3707443, 3710806, 3750044);
-- every giver and ender here needs UNIT_NPC_FLAG_QUESTGIVER
UPDATE `creature_template` SET `npcflag` = `npcflag` | 2
WHERE `entry` IN (3639640, 3639865, 3649396, 3649436, 3649537, 3709298, 3710920, 3710929, 3711556, 3739622, 3739627,
    3748042, 3748658, 3748659, 3748660);

-- 2. spawns (explicit guids in this file's block 9030000-9031999, below the 16,777,215 spawn-id cap)
DELETE FROM `creature` WHERE `guid` = 9030000 AND `id` = 3639865;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
    `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`)
SELECT
    9030000, 3639865, 750, 4928, 4928, 1, 1, 0, 7801, -2431, 487.7, 0.3, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
    'DC Winterspring/Hyjal quest port: Emissary Windsong';
DELETE FROM `creature` WHERE `guid` = 9030001 AND `id` = 3739622;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
    `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`)
SELECT
    9030001, 3739622, 750, 4923, 4923, 1, 1, 0, 5138, -2312.5, 1279.6, 2.6, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
    'DC Winterspring/Hyjal quest port: Spirit of Lo''Gosh';
DELETE FROM `creature` WHERE `guid` = 9030002 AND `id` = 3739627;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
    `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`)
SELECT
    9030002, 3739627, 750, 4923, 4923, 1, 1, 0, 5139.5, -2307.5, 1279, 3.3, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
    'DC Winterspring/Hyjal quest port: Spirit of Goldrinn';
DELETE FROM `creature` WHERE `guid` = 9030003 AND `id` = 3739627;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
    `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`)
SELECT
    9030003, 3739627, 750, 4923, 4923, 1, 1, 0, 5082, -2142, 1376.6, 0.9, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
    'DC Winterspring/Hyjal quest port: Spirit of Goldrinn';
DELETE FROM `creature` WHERE `guid` = 9030004 AND `id` = 3739622;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
    `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`)
SELECT
    9030004, 3739622, 750, 4923, 4923, 1, 1, 0, 5097, -2146, 1376.5, 2.2, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
    'DC Winterspring/Hyjal quest port: Spirit of Lo''Gosh';
DELETE FROM `creature` WHERE `guid` = 9030005 AND `id` = 3639446;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
    `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`)
SELECT
    9030005, 3639446, 750, 4923, 4923, 1, 1, 0, 5134, -2310, 1279.6, 0.4, 120, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
    'DC Winterspring/Hyjal quest port: Lycanthoth';
DELETE FROM `creature` WHERE `guid` = 9030006 AND `id` = 3639640;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
    `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`)
SELECT
    9030006, 3639640, 750, 4923, 4923, 1, 1, 0, 5036, -2082.5, 1274.6, 0.5, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
    'DC Winterspring/Hyjal quest port: Kristoff Manheim';
DELETE FROM `creature` WHERE `guid` = 9030007 AND `id` = 3748658;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
    `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`)
SELECT
    9030007, 3748658, 750, 4926, 4926, 1, 1, 0, 6544, -4111, 663.6, 4, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
    'DC Winterspring/Hyjal quest port: Kaldorei Spirit';
DELETE FROM `creature` WHERE `guid` = 9030008 AND `id` = 3748659;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
    `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`)
SELECT
    9030008, 3748659, 750, 4926, 4926, 1, 1, 0, 6539, -4116, 664.8, 0.8, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
    'DC Winterspring/Hyjal quest port: Quel''dorei Spirit';
DELETE FROM `creature` WHERE `guid` = 9030009 AND `id` = 3748660;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
    `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`)
SELECT
    9030009, 3748660, 750, 4926, 4926, 1, 1, 0, 6536, -4109, 663, 5.5, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
    'DC Winterspring/Hyjal quest port: Sin''dorei Spirit';
DELETE FROM `creature` WHERE `guid` = 9030010 AND `id` = 3748042;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
    `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`)
SELECT
    9030010, 3748042, 750, 4927, 4927, 1, 1, 0, 6220.7, -1152.1, 383.4, 4.7, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
    'DC Winterspring/Hyjal quest port: Sapling Protector';

-- quest-target rares, the Wretched Spirit pool and the owls / screechers of the Jeb chain: 120 s respawn
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3610737 AND `guid` IN (16464384);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3710806 AND `guid` IN (15801867, 16377270);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3750044 AND `guid` IN (16377481);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3707149 AND `guid` IN (15800697);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3750325 AND `guid` IN (16376597);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3748664 AND `guid` IN (16376799, 16376806, 16378055, 16378056);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3748665 AND `guid` IN (16376800, 16376801, 16376803, 16376804, 16376805, 16376855, 16376857, 16376859,
    16376861, 16378057);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3707455 AND `guid` IN (15801709, 15801710, 15801711, 15801712, 15801713, 15801714, 15801715, 15801716,
    15801717, 15801718, 15801719, 15801720, 15801721, 15801722, 15801723, 15801724, 15801725, 15801726, 15801727,
    15801728, 15801729, 15801730, 15801731, 15801732, 15801733, 15801734, 15801735, 15801736, 15801737, 15801738,
    15801739, 15801740, 15801741, 15801742, 15801743, 15801744, 15801745, 15801746, 15801747, 15801748, 15801749,
    15801750, 15801751, 15801752, 16377349, 16377355, 16377375, 16377377, 16377381, 16377382, 16377384, 16377387,
    16377393, 16377397, 16377430, 16377432, 16377434, 16377436, 16377442, 16377443, 16377475, 16377476, 16377478,
    16377490, 16377496, 16377497, 16377515, 16377516, 16377518, 16377523, 16377524, 16377526, 16377529, 16377539,
    16377545);
UPDATE `creature` SET `spawntimesecs` = 120
WHERE `id` = 3707456 AND `guid` IN (15600039, 15600040, 15600041, 15600042, 15600043, 15600044, 15700091, 15801753,
    15801755, 15801756, 15801757, 15801758, 15801759, 15801760, 15801761, 15801762, 15801763, 15801764, 15801766,
    15801767, 15801768, 15801769, 15801770, 15801771, 15801772, 15801773, 15801774, 15801775, 15801776, 15801777,
    16377252, 16377266, 16377288, 16377302, 16377308, 16377310, 16377312, 16377313, 16377314, 16377315, 16377317,
    16377318, 16377319, 16377348, 16377373, 16377374, 16377379, 16377380, 16377413, 16377444, 16377445, 16377446,
    16377447, 16377448, 16377450, 16377491, 16377500, 16377501, 16377502);

-- 3. the imported quests (quest_template rows are never deleted - codestyle - so this is a REPLACE)
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RequiredFactionId1`, `RequiredFactionId2`, `RequiredFactionValue1`, `RequiredFactionValue2`, `RewardNextQuest`,
    `RewardXPDifficulty`, `RewardMoney`, `RewardMoneyDifficulty`, `RewardDisplaySpell`, `RewardSpell`,
    `RewardHonor`, `RewardKillHonor`, `StartItem`, `Flags`, `RequiredPlayerKills`, `RewardItem1`, `RewardAmount1`,
    `RewardItem2`, `RewardAmount2`, `RewardItem3`, `RewardAmount3`, `RewardItem4`, `RewardAmount4`, `ItemDrop1`,
    `ItemDropQuantity1`, `ItemDrop2`, `ItemDropQuantity2`, `ItemDrop3`, `ItemDropQuantity3`, `ItemDrop4`,
    `ItemDropQuantity4`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`,
    `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`, `POIy`, `POIPriority`, `RewardTitle`, `RewardTalents`,
    `RewardArenaPoints`, `RewardFactionID1`, `RewardFactionValue1`, `RewardFactionOverride1`, `RewardFactionID2`,
    `RewardFactionValue2`, `RewardFactionOverride2`, `RewardFactionID3`, `RewardFactionValue3`,
    `RewardFactionOverride3`, `RewardFactionID4`, `RewardFactionValue4`, `RewardFactionOverride4`,
    `RewardFactionID5`, `RewardFactionValue5`, `RewardFactionOverride5`, `TimeAllowed`, `AllowableRaces`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`,
    `RequiredNpcOrGo2`, `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `Unknown0`,
    `ObjectiveText1`, `ObjectiveText2`, `ObjectiveText3`, `ObjectiveText4`, `VerifiedBuild`)
SELECT
    `q`.`ID`, `q`.`QuestType`, `q`.`QuestLevel`, `q`.`MinLevel`, `q`.`QuestSortID`, `q`.`QuestInfoID`,
    `q`.`SuggestedGroupNum`, `q`.`RequiredFactionId1`, `q`.`RequiredFactionId2`, `q`.`RequiredFactionValue1`,
    `q`.`RequiredFactionValue2`, `q`.`RewardNextQuest`, `q`.`RewardXPDifficulty`, `q`.`RewardMoney`, 0,
    `q`.`RewardDisplaySpell`, `q`.`RewardSpell`, `q`.`RewardHonor`, `q`.`RewardKillHonor`, `q`.`StartItem`,
    `q`.`Flags`, `q`.`RequiredPlayerKills`, `q`.`RewardItem1`, `q`.`RewardAmount1`, `q`.`RewardItem2`,
    `q`.`RewardAmount2`, `q`.`RewardItem3`, `q`.`RewardAmount3`, `q`.`RewardItem4`, `q`.`RewardAmount4`,
    `q`.`ItemDrop1`, `q`.`ItemDropQuantity1`, `q`.`ItemDrop2`, `q`.`ItemDropQuantity2`, `q`.`ItemDrop3`,
    `q`.`ItemDropQuantity3`, `q`.`ItemDrop4`, `q`.`ItemDropQuantity4`, `q`.`RewardChoiceItemID1`,
    `q`.`RewardChoiceItemQuantity1`, `q`.`RewardChoiceItemID2`, `q`.`RewardChoiceItemQuantity2`,
    `q`.`RewardChoiceItemID3`, `q`.`RewardChoiceItemQuantity3`, `q`.`RewardChoiceItemID4`,
    `q`.`RewardChoiceItemQuantity4`, `q`.`RewardChoiceItemID5`, `q`.`RewardChoiceItemQuantity5`,
    `q`.`RewardChoiceItemID6`, `q`.`RewardChoiceItemQuantity6`, `q`.`POIContinent`, `q`.`POIx`, `q`.`POIy`,
    `q`.`POIPriority`, `q`.`RewardTitle`, `q`.`RewardTalents`, `q`.`RewardArenaPoints`, `q`.`RewardFactionID1`,
    `q`.`RewardFactionValue1`, `q`.`RewardFactionOverride1`, `q`.`RewardFactionID2`, `q`.`RewardFactionValue2`,
    `q`.`RewardFactionOverride2`, `q`.`RewardFactionID3`, `q`.`RewardFactionValue3`, `q`.`RewardFactionOverride3`,
    `q`.`RewardFactionID4`, `q`.`RewardFactionValue4`, `q`.`RewardFactionOverride4`, `q`.`RewardFactionID5`,
    `q`.`RewardFactionValue5`, `q`.`RewardFactionOverride5`,
    CASE WHEN `a`.`TimeAllowed` IS NULL THEN 0 ELSE `a`.`TimeAllowed` END,
    CASE WHEN `a`.`AllowableRaces` IS NULL THEN 0 ELSE `a`.`AllowableRaces` END, `q`.`LogTitle`,
    `q`.`LogDescription`, `q`.`QuestDescription`, `q`.`AreaDescription`, `q`.`QuestCompletionLog`,
    `q`.`RequiredNpcOrGo1`, `q`.`RequiredNpcOrGo2`, `q`.`RequiredNpcOrGo3`, `q`.`RequiredNpcOrGo4`,
    `q`.`RequiredNpcOrGoCount1`, `q`.`RequiredNpcOrGoCount2`, `q`.`RequiredNpcOrGoCount3`,
    `q`.`RequiredNpcOrGoCount4`, `q`.`RequiredItemId1`, `q`.`RequiredItemId2`, `q`.`RequiredItemId3`,
    `q`.`RequiredItemId4`, `q`.`RequiredItemId5`, `q`.`RequiredItemId6`, `q`.`RequiredItemCount1`,
    `q`.`RequiredItemCount2`, `q`.`RequiredItemCount3`, `q`.`RequiredItemCount4`, `q`.`RequiredItemCount5`,
    `q`.`RequiredItemCount6`, 0, `q`.`ObjectiveText1`, `q`.`ObjectiveText2`, `q`.`ObjectiveText3`,
    `q`.`ObjectiveText4`, `q`.`VerifiedBuild`
FROM `cata_world`.`quest_template` AS `q`
LEFT JOIN `cata_world`.`quest_template_addon` AS `a` ON `a`.`ID` = `q`.`ID`
WHERE `q`.`ID` IN (25328, 28513, 28519, 28524, 28534, 28535, 28638, 28842);

DELETE FROM `quest_template_addon` WHERE `ID` IN (25328, 28513, 28519, 28524, 28534, 28535, 28638, 28842);
INSERT INTO `quest_template_addon` (
    `ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`,
    `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`,
    `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`,
    `ProvidedItemCount`, `SpecialFlags`)
SELECT
    `s`.`ID`, `s`.`MaxLevel`, `s`.`AllowableClasses`, `s`.`SourceSpellID`, `s`.`PrevQuestID`, `s`.`NextQuestID`,
    `s`.`ExclusiveGroup`, `s`.`BreadcrumbForQuestId`, `s`.`RewardMailTemplateID`, `s`.`RewardMailDelay`,
    `s`.`RequiredSkillID`, `s`.`RequiredSkillPoints`, `s`.`RequiredMinRepFaction`, `s`.`RequiredMaxRepFaction`,
    `s`.`RequiredMinRepValue`, `s`.`RequiredMaxRepValue`, `s`.`ProvidedItemCount`, `s`.`SpecialFlags`
FROM `cata_world`.`quest_template_addon` AS `s`
WHERE `s`.`ID` IN (25328, 28513, 28519, 28524, 28534, 28535, 28638, 28842);

DELETE FROM `quest_offer_reward` WHERE `ID` IN (25328, 28513, 28519, 28524, 28534, 28535, 28638, 28842);
INSERT INTO `quest_offer_reward` (
    `ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`,
    `RewardText`, `VerifiedBuild`)
SELECT
    `s`.`ID`, `s`.`Emote1`, `s`.`Emote2`, `s`.`Emote3`, `s`.`Emote4`, `s`.`EmoteDelay1`, `s`.`EmoteDelay2`,
    `s`.`EmoteDelay3`, `s`.`EmoteDelay4`, `s`.`RewardText`, `s`.`VerifiedBuild`
FROM `cata_world`.`quest_offer_reward` AS `s`
WHERE `s`.`ID` IN (25328, 28513, 28519, 28524, 28534, 28535, 28638, 28842);

DELETE FROM `quest_request_items` WHERE `ID` IN (25328, 28513, 28519, 28524, 28534, 28535, 28638, 28842);
INSERT INTO `quest_request_items` (
    `ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`)
SELECT
    `s`.`ID`, `s`.`EmoteOnComplete`, `s`.`EmoteOnIncomplete`, `s`.`CompletionText`, `s`.`VerifiedBuild`
FROM `cata_world`.`quest_request_items` AS `s`
WHERE `s`.`ID` IN (25328, 28513, 28519, 28524, 28534, 28535, 28638, 28842);

-- Cata-only pieces that 3.3.5 does not have: the 'Update Zone Auras and Phase Shift' reward spell, the start /
-- source items 64446 / 66061 (no Item.dbc row) and reputation with Guardians of Hyjal (faction 1158)
UPDATE `quest_template` SET `RewardSpell` = 0, `RewardDisplaySpell` = 0
WHERE `ID` IN (25328, 28513, 28519, 28524, 28534, 28535, 28638, 28842);
UPDATE `quest_template` SET `StartItem` = 0 WHERE `ID` IN (28524, 28842);
UPDATE `quest_template_addon` SET `ProvidedItemCount` = 0 WHERE `ID` IN (28524, 28842);
UPDATE `quest_template` SET `ItemDrop2` = 0, `ItemDropQuantity2` = 0 WHERE `ID` = 28842 AND `ItemDrop2` = 66061;
UPDATE `quest_template` SET `RewardFactionID1` = 0, `RewardFactionValue1` = 0 WHERE `ID` = 25328;
-- Cata's all-race masks (races 1-11 + 22) would shut out the DC custom races; 0 = every race, like most of 750
UPDATE `quest_template` SET `AllowableRaces` = 0
WHERE `ID` IN (25328, 28513, 28519, 28524, 28534, 28535, 28638, 28842) AND `AllowableRaces` IN (2099199, 8388607);
-- Cata flag 0x10000 is remote turn-in; on AC it is QUEST_FLAGS_AUTOCOMPLETE and skips the objectives
UPDATE `quest_template` SET `Flags` = `Flags` & ~65536
WHERE `ID` IN (25272, 25273, 25279, 25280, 25316, 25328, 25353, 25355, 28221, 28224, 28479, 28513, 28519, 28524,
    28534, 28535, 28536, 28638, 28639, 28641, 28719, 28745, 28782, 28842);

-- 4. levels, gold (only raised), objectives on the map-750 entries, chain links
UPDATE `quest_template` SET `QuestLevel` = -1
WHERE `ID` IN (25272, 25273, 25279, 25280, 25316, 25328, 25353, 25355, 28221, 28224, 28479, 28513, 28519, 28524,
    28534, 28535, 28536, 28638, 28639, 28641, 28719, 28745, 28782, 28842);
UPDATE `quest_template` SET `MinLevel` = 96
WHERE `ID` IN (28221, 28224);
UPDATE `quest_template` SET `MinLevel` = 104
WHERE `ID` IN (28479, 28513, 28519, 28524, 28534, 28535, 28536, 28638, 28745, 28842);
UPDATE `quest_template` SET `MinLevel` = 113
WHERE `ID` IN (25328);
UPDATE `quest_template` SET `RewardMoney` = 10840
WHERE `RewardMoney` < 10840 AND `ID` IN (25279, 25280);
UPDATE `quest_template` SET `RewardMoney` = 24640
WHERE `RewardMoney` < 24640 AND `ID` IN (28534, 28535);
UPDATE `quest_template` SET `RewardMoney` = 49280
WHERE `RewardMoney` < 49280 AND `ID` IN (28479, 28524, 28536);
UPDATE `quest_template` SET `RewardMoney` = 81340
WHERE `RewardMoney` < 81340 AND `ID` IN (25316);
UPDATE `quest_template` SET `RewardMoney` = 90900
WHERE `RewardMoney` < 90900 AND `ID` IN (28221, 28224);
UPDATE `quest_template` SET `RewardMoney` = 108450
WHERE `RewardMoney` < 108450 AND `ID` IN (25272, 25273, 25328, 25353, 25355);
UPDATE `quest_template` SET `RewardMoney` = 123190
WHERE `RewardMoney` < 123190 AND `ID` IN (28513, 28519, 28641, 28719);
UPDATE `quest_template` SET `RewardMoney` = 147820
WHERE `RewardMoney` < 147820 AND `ID` IN (28638, 28639, 28745, 28782, 28842);
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3639446 WHERE `ID` = 25272;
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3639446 WHERE `ID` = 25273;
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3707523 WHERE `ID` = 28513;
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3748664 WHERE `ID` = 28519;
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3707455 WHERE `ID` = 28638;
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3750325 WHERE `ID` = 28842;
UPDATE `quest_template_addon` SET `PrevQuestID` = 28534 WHERE `ID` = 28535;
UPDATE `quest_template_addon` SET `PrevQuestID` = 28519 WHERE `ID` = 28536;
UPDATE `quest_template_addon` SET `PrevQuestID` = 28637 WHERE `ID` = 28719;
UPDATE `quest_template_addon` SET `PrevQuestID` = 28638 WHERE `ID` = 28745;
UPDATE `quest_template_addon` SET `NextQuestID` = 0 WHERE `ID` = 28219 AND `NextQuestID` = 28221;
UPDATE `quest_template_addon` SET `NextQuestID` = 0 WHERE `ID` = 28220 AND `NextQuestID` = 28221;
UPDATE `quest_template_addon` SET `NextQuestID` = 0 WHERE `ID` = 28524 AND `NextQuestID` = 28460;
UPDATE `quest_template` SET `RewardNextQuest` = 28513 WHERE `ID` = 28479;
UPDATE `quest_template` SET `RewardNextQuest` = 28535 WHERE `ID` = 28534;
UPDATE `quest_template` SET `RewardNextQuest` = 0 WHERE `ID` IN (28524);

-- rewards of the imports: gear -> the 750 ladder item of the same slot/type/quality, placeholders without a
-- ladder match dropped, choices de-duplicated and compacted (slots stay contiguous)
UPDATE `quest_template` SET
    `RewardItem1` = 0, `RewardAmount1` = 0, `RewardItem2` = 0, `RewardAmount2` = 0, `RewardItem3` = 0,
    `RewardAmount3` = 0, `RewardItem4` = 0, `RewardAmount4` = 0, `RewardChoiceItemID1` = 420402,
    `RewardChoiceItemQuantity1` = 1, `RewardChoiceItemID2` = 0, `RewardChoiceItemQuantity2` = 0,
    `RewardChoiceItemID3` = 0, `RewardChoiceItemQuantity3` = 0, `RewardChoiceItemID4` = 0,
    `RewardChoiceItemQuantity4` = 0, `RewardChoiceItemID5` = 0, `RewardChoiceItemQuantity5` = 0,
    `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity6` = 0
WHERE `ID` = 28513;
UPDATE `quest_template` SET
    `RewardItem1` = 0, `RewardAmount1` = 0, `RewardItem2` = 0, `RewardAmount2` = 0, `RewardItem3` = 0,
    `RewardAmount3` = 0, `RewardItem4` = 0, `RewardAmount4` = 0, `RewardChoiceItemID1` = 420402,
    `RewardChoiceItemQuantity1` = 1, `RewardChoiceItemID2` = 420372, `RewardChoiceItemQuantity2` = 1,
    `RewardChoiceItemID3` = 0, `RewardChoiceItemQuantity3` = 0, `RewardChoiceItemID4` = 0,
    `RewardChoiceItemQuantity4` = 0, `RewardChoiceItemID5` = 0, `RewardChoiceItemQuantity5` = 0,
    `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity6` = 0
WHERE `ID` = 28519;
UPDATE `quest_template` SET
    `RewardItem1` = 0, `RewardAmount1` = 0, `RewardItem2` = 0, `RewardAmount2` = 0, `RewardItem3` = 0,
    `RewardAmount3` = 0, `RewardItem4` = 0, `RewardAmount4` = 0, `RewardChoiceItemID1` = 420423,
    `RewardChoiceItemQuantity1` = 1, `RewardChoiceItemID2` = 420143, `RewardChoiceItemQuantity2` = 1,
    `RewardChoiceItemID3` = 420163, `RewardChoiceItemQuantity3` = 1, `RewardChoiceItemID4` = 420313,
    `RewardChoiceItemQuantity4` = 1, `RewardChoiceItemID5` = 0, `RewardChoiceItemQuantity5` = 0,
    `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity6` = 0
WHERE `ID` = 28842;

-- 5. givers and turn-ins (full sets for these quests; the hostile-mob starter rows and Kristoff's 25332 go)
DELETE FROM `creature_queststarter` WHERE `quest` IN (25279, 25280, 25316, 25328, 25332, 28221, 28224, 28479);
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(3639640, 25328),
(3639865, 25316),
(3710920, 28479),
(3739622, 25279),
(3739627, 25280),
(3748042, 28221),
(3748042, 28224);
DELETE FROM `creature_queststarter` WHERE `quest` IN (28513, 28519, 28524, 28534, 28535, 28536, 28638, 28639);
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(3649436, 28639),
(3649537, 28638),
(3711556, 28524),
(3748658, 28513),
(3748658, 28534),
(3748659, 28535),
(3748660, 28519),
(3748660, 28536);
DELETE FROM `creature_queststarter` WHERE `quest` IN (28641, 28719, 28745, 28782, 28842);
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(3649396, 28641),
(3649436, 28719),
(3649537, 28745),
(3649537, 28782),
(3710929, 28842);
DELETE FROM `creature_questender` WHERE `quest` IN (25272, 25273, 25328, 25353, 25355, 28224, 28479, 28513);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(3639640, 25328),
(3739622, 25272),
(3739622, 25273),
(3739622, 25353),
(3739622, 25355),
(3739627, 25273),
(3739627, 25353),
(3748042, 28224),
(3748658, 28479),
(3748658, 28513);
DELETE FROM `creature_questender` WHERE `quest` IN (28519, 28524, 28534, 28535, 28638, 28745, 28842);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(3649537, 28638),
(3649537, 28745),
(3709298, 28524),
(3710929, 28842),
(3748659, 28534),
(3748660, 28519),
(3748660, 28535);

-- 6. quest map markers: turn-in on the ender spawn, small objective polygons over the spawn clusters
DELETE FROM `quest_poi` WHERE `QuestID` IN (25272, 25273, 25328, 25353, 25355, 28221, 28224, 28479);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`) VALUES
(25272, 0, -1, 750, 1216, 0, 0, 1, 0),
(25273, 0, -1, 750, 1216, 0, 0, 1, 0),
(25328, 0, -1, 750, 1216, 0, 0, 1, 0),
(25353, 0, 4, 750, 1216, 0, 0, 1, 0),
(25353, 1, -1, 750, 1216, 0, 0, 1, 0),
(25355, 0, 4, 750, 1216, 0, 0, 1, 0),
(25355, 1, -1, 750, 1216, 0, 0, 1, 0),
(28221, 0, 0, 750, 1257, 0, 0, 1, 0),
(28221, 1, 0, 750, 1257, 0, 0, 1, 0),
(28221, 2, -1, 750, 1257, 0, 0, 1, 0),
(28224, 0, 0, 750, 1257, 0, 0, 1, 0),
(28224, 1, -1, 750, 1257, 0, 0, 1, 0),
(28479, 0, -1, 750, 1256, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` IN (25272, 25273, 25328, 25353, 25355, 28221, 28224, 28479);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(25272, 0, 0, 5138, -2312, 0),
(25273, 0, 0, 5140, -2308, 0),
(25328, 0, 0, 5036, -2082, 0),
(25353, 0, 0, 5065, -2278, 0),
(25353, 0, 1, 5100, -2219, 0),
(25353, 0, 2, 5126, -2049, 0),
(25353, 0, 3, 5073, -2070, 0),
(25353, 0, 4, 5041, -2163, 0),
(25353, 1, 0, 5082, -2142, 0),
(25355, 0, 0, 5065, -2278, 0),
(25355, 0, 1, 5100, -2219, 0),
(25355, 0, 2, 5126, -2049, 0),
(25355, 0, 3, 5073, -2070, 0),
(25355, 0, 4, 5041, -2163, 0),
(25355, 1, 0, 5097, -2146, 0),
(28221, 0, 0, 6371, -1285, 0),
(28221, 0, 1, 6353, -1243, 0),
(28221, 0, 2, 6311, -1225, 0),
(28221, 0, 3, 6268, -1243, 0),
(28221, 0, 4, 6251, -1285, 0),
(28221, 0, 5, 6268, -1328, 0),
(28221, 0, 6, 6311, -1345, 0),
(28221, 0, 7, 6353, -1328, 0),
(28221, 1, 0, 6274, -1041, 0),
(28221, 1, 1, 6256, -999, 0),
(28221, 1, 2, 6214, -981, 0),
(28221, 1, 3, 6172, -999, 0),
(28221, 1, 4, 6154, -1041, 0),
(28221, 1, 5, 6172, -1083, 0),
(28221, 1, 6, 6214, -1100, 0),
(28221, 1, 7, 6256, -1083, 0),
(28221, 2, 0, 6221, -1152, 0),
(28224, 0, 0, 6287, -1119, 0),
(28224, 0, 1, 6283, -1108, 0),
(28224, 0, 2, 6272, -1104, 0),
(28224, 0, 3, 6262, -1108, 0),
(28224, 0, 4, 6257, -1119, 0),
(28224, 0, 5, 6262, -1130, 0),
(28224, 0, 6, 6272, -1134, 0),
(28224, 0, 7, 6283, -1130, 0),
(28224, 1, 0, 6221, -1152, 0),
(28479, 0, 0, 6544, -4111, 0);
DELETE FROM `quest_poi` WHERE `QuestID` IN (28513, 28519, 28524, 28534, 28535, 28536, 28638, 28745);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`) VALUES
(28513, 0, 0, 750, 1256, 0, 0, 1, 0),
(28513, 1, 0, 750, 1256, 0, 0, 1, 0),
(28513, 2, 0, 750, 1256, 0, 0, 1, 0),
(28513, 3, -1, 750, 1256, 0, 0, 1, 0),
(28519, 0, 0, 750, 1256, 0, 0, 1, 0),
(28519, 1, 0, 750, 1256, 0, 0, 1, 0),
(28519, 2, 0, 750, 1256, 0, 0, 1, 0),
(28519, 3, -1, 750, 1256, 0, 0, 1, 0),
(28524, 0, -1, 750, 1256, 0, 0, 1, 0),
(28534, 0, -1, 750, 1256, 0, 0, 1, 0),
(28535, 0, -1, 750, 1256, 0, 0, 1, 0),
(28536, 0, -1, 750, 1256, 0, 0, 1, 0),
(28638, 0, 0, 750, 1256, 0, 0, 1, 0),
(28638, 1, -1, 750, 1256, 0, 0, 1, 0),
(28745, 0, 0, 750, 1256, 0, 0, 1, 0),
(28745, 1, 0, 750, 1256, 0, 0, 1, 0),
(28745, 2, 0, 750, 1256, 0, 0, 1, 0),
(28745, 3, -1, 750, 1256, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` IN (28513, 28519, 28524, 28534, 28535, 28536, 28638, 28745);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28513, 0, 0, 6650, -4082, 0),
(28513, 0, 1, 6636, -4047, 0),
(28513, 0, 2, 6600, -4032, 0),
(28513, 0, 3, 6565, -4047, 0),
(28513, 0, 4, 6550, -4082, 0),
(28513, 0, 5, 6565, -4118, 0),
(28513, 0, 6, 6600, -4132, 0),
(28513, 0, 7, 6636, -4118, 0),
(28513, 1, 0, 6644, -4027, 0),
(28513, 1, 1, 6636, -4008, 0),
(28513, 1, 2, 6617, -4000, 0),
(28513, 1, 3, 6598, -4008, 0),
(28513, 1, 4, 6590, -4027, 0),
(28513, 1, 5, 6598, -4046, 0),
(28513, 1, 6, 6617, -4054, 0),
(28513, 1, 7, 6636, -4046, 0),
(28513, 2, 0, 6635, -3970, 0),
(28513, 2, 1, 6625, -3947, 0),
(28513, 2, 2, 6602, -3937, 0),
(28513, 2, 3, 6578, -3947, 0),
(28513, 2, 4, 6568, -3970, 0),
(28513, 2, 5, 6578, -3994, 0),
(28513, 2, 6, 6602, -4004, 0),
(28513, 2, 7, 6625, -3994, 0),
(28513, 3, 0, 6544, -4111, 0),
(28519, 0, 0, 6460, -4004, 0),
(28519, 0, 1, 6449, -3978, 0),
(28519, 0, 2, 6423, -3967, 0),
(28519, 0, 3, 6397, -3978, 0),
(28519, 0, 4, 6387, -4004, 0),
(28519, 0, 5, 6397, -4030, 0),
(28519, 0, 6, 6423, -4040, 0),
(28519, 0, 7, 6449, -4030, 0),
(28519, 1, 0, 6489, -4124, 0),
(28519, 1, 1, 6478, -4099, 0),
(28519, 1, 2, 6453, -4088, 0),
(28519, 1, 3, 6427, -4099, 0),
(28519, 1, 4, 6416, -4124, 0),
(28519, 1, 5, 6427, -4150, 0),
(28519, 1, 6, 6453, -4161, 0),
(28519, 1, 7, 6478, -4150, 0),
(28519, 2, 0, 6471, -4066, 0),
(28519, 2, 1, 6460, -4041, 0),
(28519, 2, 2, 6436, -4031, 0),
(28519, 2, 3, 6412, -4041, 0),
(28519, 2, 4, 6402, -4066, 0),
(28519, 2, 5, 6412, -4090, 0),
(28519, 2, 6, 6436, -4100, 0),
(28519, 2, 7, 6460, -4090, 0),
(28519, 3, 0, 6536, -4109, 0),
(28524, 0, 0, 6396, -2537, 0),
(28534, 0, 0, 6539, -4116, 0),
(28535, 0, 0, 6536, -4109, 0),
(28536, 0, 0, 6586, -3873, 0),
(28638, 0, 0, 7603, -4431, 0),
(28638, 0, 1, 7585, -4389, 0),
(28638, 0, 2, 7543, -4371, 0),
(28638, 0, 3, 7500, -4389, 0),
(28638, 0, 4, 7483, -4431, 0),
(28638, 0, 5, 7500, -4474, 0),
(28638, 0, 6, 7543, -4491, 0),
(28638, 0, 7, 7585, -4474, 0),
(28638, 1, 0, 7636, -4434, 0),
(28745, 0, 0, 7406, -4436, 0),
(28745, 0, 1, 7390, -4398, 0),
(28745, 0, 2, 7352, -4382, 0),
(28745, 0, 3, 7314, -4398, 0),
(28745, 0, 4, 7298, -4436, 0),
(28745, 0, 5, 7314, -4474, 0),
(28745, 0, 6, 7352, -4490, 0),
(28745, 0, 7, 7390, -4474, 0),
(28745, 1, 0, 7275, -4896, 0),
(28745, 1, 1, 7264, -4869, 0),
(28745, 1, 2, 7237, -4858, 0),
(28745, 1, 3, 7210, -4869, 0),
(28745, 1, 4, 7199, -4896, 0),
(28745, 1, 5, 7210, -4923, 0),
(28745, 1, 6, 7237, -4934, 0),
(28745, 1, 7, 7264, -4923, 0),
(28745, 2, 0, 7447, -4297, 0),
(28745, 2, 1, 7436, -4271, 0),
(28745, 2, 2, 7410, -4260, 0),
(28745, 2, 3, 7384, -4271, 0),
(28745, 2, 4, 7373, -4297, 0),
(28745, 2, 5, 7384, -4323, 0),
(28745, 2, 6, 7410, -4334, 0),
(28745, 2, 7, 7436, -4323, 0),
(28745, 3, 0, 7636, -4434, 0);
DELETE FROM `quest_poi` WHERE `QuestID` IN (28842);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`) VALUES
(28842, 0, -1, 750, 1256, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` IN (28842);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28842, 0, 0, 6110, -4189, 0);

-- Check after applying (expect 0):
--   SELECT COUNT(*) FROM `quest_template` WHERE (`RewardItem1` = 0 AND `RewardItem2` <> 0)
--       OR (`RewardChoiceItemID1` = 0 AND `RewardChoiceItemID2` <> 0);
--   SELECT COUNT(*) FROM `creature` WHERE `guid` > 16777215;
