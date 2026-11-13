-- DarkChaos: Alliance hub at the Stormpike camp (map 751, Hillsbrad Foothills 4936, band 138-144)
--
-- Map 751 had no Alliance innkeeper between Hyjal (ends 128/130) and Arathi (142): Tirisfal, Silverpine and
-- Hillsbrad are the Cata Forsaken storyline and every innkeeper there is Horde. The Stormpike camp at the
-- Alterac Valley entrance is the one standing Alliance outpost in that range - guards, Thanthaldis
-- Snowgleam (vendor + repair), the Alterac Valley quartermasters - so it gets the missing innkeeper.
--
-- Innkeeper Brumli Frostbeard (830300) is a copy of Innkeeper Thulfram (4107744, 751 Aerie Peak): innkeeper and
-- food vendor, gossip menu 345 with the 'make this inn your home' option, the same food list (classic
-- food plus the band consumables 400812-400820), model and weapon. Faction 1334 Stormpike Guard like the
-- camp, so Alliance players can bind here and the Horde cannot use it. No SmartAI (the donor's two rows
-- are not copied).
--
-- Spawn guid 9025100 at (-28.2, -321.2, 131.22), about 4 yd west of Thanthaldis on the same floor.
-- Check it in game (.go creature / .gps) and nudge it with .npc move if it stands in a wall.
--
-- Not included, both need client DBC rows: a flight master (no Alliance taxi node near the camp - every
-- 751 node carries both mounts, so a flight master here would link to Tarren Mill) and rested XP
-- (AreaTrigger.dbc + areatrigger_tavern).
--
-- Bots: once map 751 is in Playerbots.RandomBotMaps with zone brackets, this innkeeper is the Alliance hub
-- for the Hillsbrad bracket automatically (faction 1334 is friendly to Alliance only).

-- creature_template rows are never deleted (codestyle), so the copy is a REPLACE
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
    830300, `t`.`difficulty_entry_1`, `t`.`difficulty_entry_2`, `t`.`difficulty_entry_3`, `t`.`KillCredit1`,
    `t`.`KillCredit2`, 'Innkeeper Brumli Frostbeard', 'Innkeeper', `t`.`IconName`, `t`.`gossip_menu_id`, 142, 142,
    `t`.`exp`, 1334, `t`.`npcflag`, `t`.`speed_walk`, `t`.`speed_run`, `t`.`speed_swim`, `t`.`speed_flight`,
    `t`.`detection_range`, `t`.`rank`, `t`.`dmgschool`, `t`.`DamageModifier`, `t`.`BaseAttackTime`,
    `t`.`RangeAttackTime`, `t`.`BaseVariance`, `t`.`RangeVariance`, `t`.`unit_class`, `t`.`unit_flags`,
    `t`.`unit_flags2`, `t`.`dynamicflags`, `t`.`family`, `t`.`type`, `t`.`type_flags`, `t`.`lootid`,
    `t`.`pickpocketloot`, `t`.`skinloot`, `t`.`PetSpellDataId`, `t`.`VehicleId`, `t`.`mingold`, `t`.`maxgold`, '',
    `t`.`MovementType`, `t`.`HoverHeight`, `t`.`HealthModifier`, `t`.`ManaModifier`, `t`.`ArmorModifier`,
    `t`.`ExperienceModifier`, `t`.`RacialLeader`, `t`.`movementId`, `t`.`RegenHealth`, `t`.`CreatureImmunitiesId`,
    `t`.`flags_extra`, '', 0
FROM `creature_template` AS `t`
WHERE `t`.`entry` = 4107744;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 830300;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`,
    `Probability`, `VerifiedBuild`)
SELECT 830300, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, 0
FROM `creature_template_model` WHERE `CreatureID` = 4107744;

DELETE FROM `creature_template_addon` WHERE `entry` = 830300;
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`,
    `visibilityDistanceType`, `auras`)
SELECT 830300, 0, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`
FROM `creature_template_addon` WHERE `entry` = 4107744;

DELETE FROM `creature_equip_template` WHERE `CreatureID` = 830300;
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`,
    `VerifiedBuild`)
SELECT 830300, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, 0
FROM `creature_equip_template` WHERE `CreatureID` = 4107744;

DELETE FROM `npc_vendor` WHERE `entry` = 830300;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`)
SELECT 830300, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, 0
FROM `npc_vendor` WHERE `entry` = 4107744;

DELETE FROM `creature` WHERE `guid` = 9025100 AND `id` = 830300;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`,
    `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`,
    `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`)
SELECT 9025100, 830300, 751, 4936, 4936, 1, 1, 1, -28.2, -321.2, 131.22, 4.82, 300, 0, 0, 1, 0,
    0, 0, 0, 0, '', 0, 0, 'DC: Stormpike camp innkeeper, Alliance hub 138-144';
