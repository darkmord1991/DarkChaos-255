-- DarkChaos: map 750, Mount Hyjal - the Firelands route: a camp by Sulfuron Spire and 31 quests (2026-11-14)
--
-- Why: Hyjal (zone 4923, 113-130) gives about 57% of the quest XP its levels need after the pending fixes; the
-- Firelands corner of southern Hyjal had almost no quests. Owner-approved plan.
--
-- 1. The Avengers' camp stands on the north-west shore of the Throne of Flame, about 250 yd from Sulfuron Spire and
--    in sight of it, on navmesh ground that is walkable from every quest area (the tower platform with the raid
--    portal is a lava island that only flyers reach). New NPCs 832000-832003: Commander Mirelle Dawnspear,
--    Archdruid Valtorin Mossheart (quest givers), Innkeeper Seraleth Emberwell (innkeeper + food, gossip 345 with
--    the bind option -> a bot hub for 4923) and Tahu Ashhoof (food + repair). Rest: tavern trigger 7007 (sphere
--    r 15 at 4205, -2832, 1008); its client row is in AreaTrigger.dbc (map 750's run). Graveyard 15064 with a Spirit
--    Healer at the camp, linked to zone 4923 for both factions (the nearest one, Ascendant's Circle, is 680 yd off).
-- 2. Field quest givers on navmesh ground (832004-832009): Warden Lyria Moonshade and Windspeaker Hela Mistmane at
--    Ascendant's Circle, Earthcaller Mahkoa Stonehoof south-east of the Sanctum of the Prophets, Watcher Kaldras
--    Thornwood at the Gates of Sothann, Talon Scout Ashari Swiftwing above the Scorched Plain, Keeper Elarion
--    Duskleaf on the ridge south of the Regrowth. All neutral to both factions (2252 / 2379, EnemyGroup 8).
-- 3. Quests 751250-751280, one chain with side branches, MinLevel 116 -> 128: breadcrumb from Hamuul at the
--    Sanctuary of Malorne -> Throne of Flame -> Ascendant's Rise -> Sanctum of the Prophets -> Gates of Sothann /
--    Darkwhisper Gorge -> the Scorched Plain -> back to the camp -> the Regrowth -> camp finale (open-ended).
--    Kill objectives name the DC entries directly; collect objectives use existing quest items (Item.dbc rows
--    present) dropped by the target mobs (QuestRequired loot rows). Small objective polygons over the spawn
--    clusters, none within 40 yd of an elite, none over lava; turn-in markers on the enders.
-- 4. The map-750 spawns of the 12 target entries respawn in 120 s (originals in
--    dc_backup_20261114_firelands_respawn); the Raging Invaders inside the Sanctuary of Malorne keep theirs.
--
-- Conventions: QuestLevel -1, RewardXPDifficulty 5-7, gold by the 11-10 formula on the 4923 band, Guardians of
-- Hyjal reputation, gear from the 750 ladder (bands 117 / 121 / 125, 421860 / 421000 / 421946; no new items).
-- XP: all 31 quests at level 120 = 2,373,500 XP (3.23 levels), at 126 = 2,481,600.
-- IDS: creature_template 832000-832009, creature guids 9036000-9036010, quests 751250-751280, AreaTrigger 7007,
-- graveyard 15064.
-- Applies after the pending Winterspring/Hyjal, EPL and Silverpine files; it touches none of their rows.
-- Re-runnable. Apply to acore_world, then restart the worldserver (server AreaTrigger.dbc needs no reload: the
-- server reads triggers from the table; the client needs the new AreaTrigger.dbc for the rest area).

CREATE TABLE IF NOT EXISTS `dc_backup_20261114_firelands_respawn` (
    `guid` INT UNSIGNED NOT NULL,
    `id` INT UNSIGNED NOT NULL,
    `spawntimesecs` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- first run only (INSERT IGNORE keeps the originals on a re-run; the DELETE removes nothing)
DELETE FROM `dc_backup_20261114_firelands_respawn` WHERE `guid` = 0;
INSERT IGNORE INTO `dc_backup_20261114_firelands_respawn` (`guid`, `id`, `spawntimesecs`)
SELECT `c`.`guid`, `c`.`id`, `c`.`spawntimesecs`
FROM `creature` AS `c`
WHERE `c`.`map` = 750 AND `c`.`spawntimesecs` > 120 AND `c`.`id` IN (
    3640755, 3640463, 3640709, 3640713, 3640767, 3640465, 3639724, 3641500, 3641502, 3652791, 3652794, 3652557);

-- 1. NPC templates, level 128 like the other Hyjal service NPCs (copied from Isara Riverstride 3643487)
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (
    832000, 0, 0, 0, 0, 0, 'Commander Mirelle Dawnspear', 'Avengers of Hyjal', '', 0, 128, 128, 2, 2379, 2, 1,
    1.14286, 1, 1, 20, 0, 0, 0.799251, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5,
    1, 1, 1, 0, 0, 1, 0, 0, '', 0);
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (
    832001, 0, 0, 0, 0, 0, 'Archdruid Valtorin Mossheart', 'Cenarion Circle', '', 0, 128, 128, 2, 2252, 2, 1,
    1.14286, 1, 1, 20, 0, 0, 0.799251, 2000, 2000, 1, 1, 2, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5,
    1, 1, 1, 0, 0, 1, 0, 0, '', 0);
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (
    832002, 0, 0, 0, 0, 0, 'Innkeeper Seraleth Emberwell', 'Innkeeper', '', 345, 128, 128, 2, 2252, 66177, 1,
    1.14286, 1, 1, 20, 0, 0, 0.799251, 2000, 2000, 1, 1, 2, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1,
    1, 1, 1, 0, 0, 1, 0, 0, '', 0);
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (
    832003, 0, 0, 0, 0, 0, 'Tahu Ashhoof', 'Provisions & Repairs', '', 0, 128, 128, 2, 2252, 4736, 1, 1.14286, 1, 1,
    20, 0, 0, 0.799251, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0,
    1, 0, 0, '', 0);
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (
    832004, 0, 0, 0, 0, 0, 'Warden Lyria Moonshade', 'Guardians of Hyjal', '', 0, 128, 128, 2, 2252, 2, 1, 1.14286,
    1, 1, 20, 0, 0, 0.799251, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5, 1, 1, 1,
    0, 0, 1, 0, 0, '', 0);
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (
    832005, 0, 0, 0, 0, 0, 'Windspeaker Hela Mistmane', 'Guardians of Hyjal', '', 0, 128, 128, 2, 2252, 2, 1,
    1.14286, 1, 1, 20, 0, 0, 0.799251, 2000, 2000, 1, 1, 2, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5,
    1, 1, 1, 0, 0, 1, 0, 0, '', 0);
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (
    832006, 0, 0, 0, 0, 0, 'Earthcaller Mahkoa Stonehoof', 'The Earthen Ring', '', 0, 128, 128, 2, 2252, 2, 1,
    1.14286, 1, 1, 20, 0, 0, 0.799251, 2000, 2000, 1, 1, 2, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5,
    1, 1, 1, 0, 0, 1, 0, 0, '', 0);
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (
    832007, 0, 0, 0, 0, 0, 'Watcher Kaldras Thornwood', 'Guardians of Hyjal', '', 0, 128, 128, 2, 2252, 2, 1,
    1.14286, 1, 1, 20, 0, 0, 0.799251, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5,
    1, 1, 1, 0, 0, 1, 0, 0, '', 0);
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (
    832008, 0, 0, 0, 0, 0, 'Talon Scout Ashari Swiftwing', 'Druids of the Talon', '', 0, 128, 128, 2, 2252, 2, 1,
    1.14286, 1, 1, 20, 0, 0, 0.799251, 2000, 2000, 1, 1, 2, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5,
    1, 1, 1, 0, 0, 1, 0, 0, '', 0);
REPLACE INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`,
    `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`,
    `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`,
    `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
    `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`,
    `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`,
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`,
    `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES (
    832009, 0, 0, 0, 0, 0, 'Keeper Elarion Duskleaf', 'Guardians of Hyjal', '', 0, 128, 128, 2, 2252, 2, 1, 1.14286,
    1, 1, 20, 0, 0, 0.799251, 2000, 2000, 1, 1, 1, 512, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 5, 1, 1, 1,
    0, 0, 1, 0, 0, '', 0);
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 832000 AND 832009;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`,
    `VerifiedBuild`) VALUES
(832000, 0, 31213, 1, 1, 0),
(832001, 0, 33408, 1, 1, 0),
(832002, 0, 32107, 1, 1, 0),
(832003, 0, 33358, 1, 1, 0),
(832004, 0, 33357, 1, 1, 0),
(832005, 0, 31230, 1, 1, 0),
(832006, 0, 33407, 1, 1, 0),
(832007, 0, 33387, 1, 1, 0),
(832008, 0, 33388, 1, 1, 0),
(832009, 0, 33359, 1, 1, 0);

-- vendor lists: the innkeeper sells Isara Riverstride's food, the provisioner adds Motah Tallhorn's potions
DELETE FROM `npc_vendor` WHERE `entry` IN (832002, 832003);
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`) VALUES
(832002, 0, 400800, 0, 0, 0, 0),
(832002, 1, 400801, 0, 0, 0, 0),
(832002, 2, 400802, 0, 0, 0, 0),
(832002, 3, 400806, 0, 0, 0, 0),
(832002, 4, 400807, 0, 0, 0, 0),
(832002, 5, 400808, 0, 0, 0, 0),
(832002, 6, 400812, 0, 0, 0, 0),
(832002, 7, 400813, 0, 0, 0, 0),
(832002, 8, 400814, 0, 0, 0, 0),
(832002, 9, 400818, 0, 0, 0, 0),
(832002, 10, 400819, 0, 0, 0, 0),
(832002, 11, 400820, 0, 0, 0, 0),
(832003, 0, 400800, 0, 0, 0, 0),
(832003, 1, 400801, 0, 0, 0, 0),
(832003, 2, 400802, 0, 0, 0, 0),
(832003, 3, 400806, 0, 0, 0, 0),
(832003, 4, 400807, 0, 0, 0, 0),
(832003, 5, 400808, 0, 0, 0, 0),
(832003, 6, 400812, 0, 0, 0, 0),
(832003, 7, 400813, 0, 0, 0, 0),
(832003, 8, 400814, 0, 0, 0, 0),
(832003, 9, 400818, 0, 0, 0, 0),
(832003, 10, 400819, 0, 0, 0, 0),
(832003, 11, 400820, 0, 0, 0, 0),
(832003, 12, 400803, 0, 0, 0, 0),
(832003, 13, 400804, 0, 0, 0, 0),
(832003, 14, 400805, 0, 0, 0, 0),
(832003, 15, 400809, 0, 0, 0, 0),
(832003, 16, 400810, 0, 0, 0, 0),
(832003, 17, 400811, 0, 0, 0, 0),
(832003, 18, 400815, 0, 0, 0, 0),
(832003, 19, 400816, 0, 0, 0, 0),
(832003, 20, 400817, 0, 0, 0, 0),
(832003, 21, 400821, 0, 0, 0, 0),
(832003, 22, 400822, 0, 0, 0, 0),
(832003, 23, 400823, 0, 0, 0, 0);

-- 2. spawns (explicit guids 9036000-9036010, below the 16,777,215 spawn-id cap)
--   9036000 Commander Mirelle Dawnspear (4204.0, -2832.0, 1007.2)
--   9036001 Archdruid Valtorin Mossheart (4196.0, -2824.0, 1008.88)
--   9036002 Innkeeper Seraleth Emberwell (4212.0, -2822.0, 1008.52)
--   9036003 Tahu Ashhoof (4210.0, -2842.0, 1005.35)
--   9036004 Warden Lyria Moonshade (3745.0, -3304.0, 1004.49)
--   9036005 Windspeaker Hela Mistmane (3739.0, -3298.0, 1003.54)
--   9036006 Earthcaller Mahkoa Stonehoof (4058.0, -3602.0, 1012.74)
--   9036007 Watcher Kaldras Thornwood (4110.0, -3965.0, 970.96)
--   9036008 Talon Scout Ashari Swiftwing (4394.0, -3118.0, 1017.33)
--   9036009 Keeper Elarion Duskleaf (4290.0, -2346.0, 1149.08)
DELETE FROM `creature` WHERE `guid` BETWEEN 9036000 AND 9036009 AND `id` BETWEEN 832000 AND 832009;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`,
    `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`,
    `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`) VALUES
(9036000, 832000, 750, 4923, 4923, 1, 1, 0, 4204, -2832, 1007.2, 3.66, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, ''),
(9036001, 832001, 750, 4923, 4923, 1, 1, 0, 4196, -2824, 1008.88, 5.3, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, ''),
(9036002, 832002, 750, 4923, 4923, 1, 1, 0, 4212, -2822, 1008.52, 4.04, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, ''),
(9036003, 832003, 750, 4923, 4923, 1, 1, 0, 4210, -2842, 1005.35, 2.6, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, ''),
(9036004, 832004, 750, 4923, 16546, 1, 1, 0, 3745, -3304, 1004.49, 5.62, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, ''),
(9036005, 832005, 750, 4923, 4923, 1, 1, 0, 3739, -3298, 1003.54, 5.62, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, ''),
(9036006, 832006, 750, 4923, 4923, 1, 1, 0, 4058, -3602, 1012.74, 1.03, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, ''),
(9036007, 832007, 750, 4923, 16544, 1, 1, 0, 4110, -3965, 970.96, 0.69, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, ''),
(9036008, 832008, 750, 4923, 4923, 1, 1, 0, 4394, -3118, 1017.33, 0.14, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, ''),
(9036009, 832009, 750, 4923, 16481, 1, 1, 0, 4290, -2346, 1149.08, 5.78, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, '');

-- the camp graveyard: Spirit Healer 9036010 (6491, like the other DC750 graveyards) and graveyard 15064
DELETE FROM `creature` WHERE `guid` = 9036010 AND `id` = 6491;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`,
    `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`,
    `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`) VALUES
(9036010, 6491, 750, 4923, 4923, 1, 1, 0, 4216, -2856, 1001.75, 2.1, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, '');
DELETE FROM `game_graveyard` WHERE `ID` = 15064;
INSERT INTO `game_graveyard` (`ID`, `Map`, `x`, `y`, `z`, `Comment`) VALUES
(15064, 750, 4216, -2856, 1001.75, 'DC750 Hyjal - Throne of Flame, Avengers camp (Firelands route)');
DELETE FROM `graveyard_zone` WHERE `ID` = 15064 AND `GhostZone` = 4923;
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`) VALUES
(15064, 4923, 0, 'DC750 Hyjal - Throne of Flame camp');

-- 3. quests (quest_template rows are never deleted - codestyle - so REPLACE)
-- 751250 Smoke Over the Spire (MinLevel 116): Arch Druid Hamuul Runetotem -> Commander Mirelle Dawnspear
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751250, 2, -1, 116, 4923, 0, 0, 5, 108450, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 750, 4204, -2832, 1158, 5, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Smoke Over the Spire',
    'Report to Commander Mirelle Dawnspear at the Avengers'' camp by Sulfuron Spire in the south of Mount Hyjal.',
    CONCAT('Look south-east, $N. That smoke has hung over Sulfuron Spire since the Firelord''s gate tore ',
        'open beneath it. Ragnaros''s servants pour out of the Firelands faster than the Circle can burn ',
        'them back, and the Twilight''s Hammer marches with them.$B$BThe Avengers of Hyjal have pitched ',
        'their camp on the shore of the Throne of Flame, north-west of the spire and within sight of the ',
        'burning gate at its crown. Commander Mirelle Dawnspear leads them, and she has asked for every ',
        'able hand. Go to her and tell her that Hamuul sent you.$B$BMind the lake of fire around the ',
        'spire. Nothing walks there and lives.'),
    '',
    'Speak to Commander Mirelle Dawnspear at the Avengers'' camp by Sulfuron Spire.');
-- 751251 Envoys of the Firelord (MinLevel 117): Commander Mirelle Dawnspear -> Commander Mirelle Dawnspear
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751251, 2, -1, 117, 4923, 0, 0, 6, 135560, 8, 421867, 421875, 421883, 421891, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    4147.6, -2934, 1158, 5, 0, 3640755, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Envoys of the Firelord',
    CONCAT('Commander Mirelle Dawnspear wants you to slay 6 Emissaries of Flame on the black shore of the ',
        'Throne of Flame, south-east of the Avengers'' camp.'),
    CONCAT('Look south-east along the black shore of the Throne of Flame, toward the fire. The robed ',
        'figures there are Emissaries of Flame - Twilight''s Hammer cultists who have sworn themselves ',
        'to Ragnaros and carry his word to the elementals still sleeping in the stone.$B$BEvery sermon ',
        'they finish wakes another fire spirit. End their preaching, $N. Six of them should make the ',
        'rest think twice.'),
    '',
    'Return to Commander Mirelle Dawnspear at the Avengers'' camp by Sulfuron Spire.');
-- 751252 Smoldering Hearts (MinLevel 117): Archdruid Valtorin Mossheart -> Archdruid Valtorin Mossheart
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751252, 2, -1, 117, 4923, 0, 0, 6, 135560, 8, 421865, 421873, 421881, 421889, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    4147.6, -2934, 1158, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 55123, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0,
    'Smoldering Hearts',
    CONCAT('Archdruid Valtorin Mossheart wants 5 Smoldering Cores taken from the Emissaries of Flame at the ',
        'Throne of Flame.'),
    CONCAT('The Emissaries carry cores of living flame in their robes, torn from the elementals they have ',
        'bound. While a core still smolders, the spirit it came from cannot rest. It answers whoever ',
        'holds it.$B$BBring me five of those cores, $N. I will sink them in moonwell water and let the ',
        'spirits go - or at the very least, out of the cultists'' hands.'),
    '',
    'Return to Archdruid Valtorin Mossheart at the Avengers'' camp by Sulfuron Spire.');
-- 751253 Ascendant's Rise (MinLevel 117): Commander Mirelle Dawnspear -> Warden Lyria Moonshade
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751253, 2, -1, 117, 4923, 0, 0, 5, 108450, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 750, 3745, -3304, 1158, 5, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Ascendant''s Rise',
    'Report to Warden Lyria Moonshade at Ascendant''s Circle, south-east of Sulfuron Spire.',
    CONCAT('The Emissaries are only heralds. East of the spire, beyond the lava lake, lies Ascendant''s ',
        'Rise, where the Twilight''s Hammer trains its zealots to be reborn as creatures of fire. The ',
        'Guardians of Hyjal keep a watch at Ascendant''s Circle, by the spirit healer, under Warden ',
        'Lyria Moonshade.$B$BGo to her. Whatever she needs from you, give it.'),
    '',
    'Speak to Warden Lyria Moonshade at Ascendant''s Circle.');
-- 751254 Breaking the Subjugators (MinLevel 117): Warden Lyria Moonshade -> Warden Lyria Moonshade
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751254, 2, -1, 117, 4923, 0, 0, 6, 135560, 8, 421866, 421874, 421882, 421890, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    3893.5, -3427.6, 1158, 5, 0, 3640463, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Breaking the Subjugators',
    'Warden Lyria Moonshade wants you to slay 8 Twilight Subjugators on Ascendant''s Rise.',
    CONCAT('The Twilight Subjugators drive captives and fresh converts up the Rise with whip and flame. ',
        'Take them away and half of the ones below would run - or at least stop long enough to ',
        'think.$B$BKill eight Subjugators on Ascendant''s Rise, $N.'),
    '',
    'Return to Warden Lyria Moonshade at Ascendant''s Circle.');
-- 751255 No Ascension (MinLevel 117): Warden Lyria Moonshade -> Warden Lyria Moonshade
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751255, 2, -1, 117, 4923, 0, 0, 6, 135560, 8, 421863, 421871, 421879, 421887, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    3917.1, -3463.1, 1158, 5, 0, 3640709, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'No Ascension',
    'Warden Lyria Moonshade wants you to slay 8 Flame Ascendants on Ascendant''s Rise.',
    CONCAT('You have seen them by now - men and women whose skin has cracked into embers and whose eyes ',
        'burn like coals. That is what the Hammer promises its faithful, and the Flame Ascendants are ',
        'all that is left of them afterward.$B$BThey are beyond saving, $N. Grant eight of them the end ',
        'their masters denied them.'),
    '',
    'Return to Warden Lyria Moonshade at Ascendant''s Circle.');
-- 751256 Rites in Cipher (MinLevel 118): Windspeaker Hela Mistmane -> Windspeaker Hela Mistmane
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751256, 2, -1, 118, 4923, 0, 0, 6, 135560, 8, 421861, 421869, 421877, 421885, 0, 0, 1, 1, 1, 1, 0, 0, 750, 3903,
    -3432.2, 1158, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20404, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0,
    'Rites in Cipher',
    CONCAT('Windspeaker Hela Mistmane wants 6 pages of Encrypted Twilight Text taken from the Subjugators ',
        'and Ascendants of Ascendant''s Rise.'),
    CONCAT('The cultists on the Rise carry pages of their rites, written in the Hammer''s cipher. The winds ',
        'carried one to me last night, half burned. It speaks of a door, and of a fire that ',
        'walks.$B$BBring me six more pages from the Subjugators and Ascendants, $N. With enough of them, ',
        'the Earthen Ring can break the cipher - and learn what door they mean.'),
    '',
    'Return to Windspeaker Hela Mistmane at Ascendant''s Circle.');
-- 751257 Ashes on the Rise (MinLevel 118): Warden Lyria Moonshade -> Warden Lyria Moonshade
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751257, 2, -1, 118, 4923, 0, 0, 7, 162680, 8, 421905, 421913, 421921, 421929, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    3852.4, -3420, 1158, 6, 0, 3640463, 3640709, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Ashes on the Rise',
    CONCAT('Warden Lyria Moonshade wants you to slay 6 Twilight Subjugators and 6 Flame Ascendants on the ',
        'high terrace of Ascendant''s Rise.'),
    CONCAT('The high terrace at the far end of the Rise is where the Hammer holds its rites. The newest ',
        'Ascendants are made there, and the Subjugators guard the fire.$B$BBreak the rite, $N. Six ',
        'Subjugators, six Ascendants. When the terrace goes dark, the whole Rise will know it.'),
    '',
    'Return to Warden Lyria Moonshade at Ascendant''s Circle.');
-- 751258 The Sanctum of the Prophets (MinLevel 119): Warden Lyria Moonshade -> Earthcaller Mahkoa Stonehoof
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751258, 2, -1, 119, 4923, 0, 0, 5, 108450, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 750, 4058, -3602, 1158, 5, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'The Sanctum of the Prophets',
    'Report to Earthcaller Mahkoa Stonehoof south-east of the Sanctum of the Prophets.',
    CONCAT('There is another Twilight camp north of the Rise - the cultists call it the Sanctum of the ',
        'Prophets. Earthcaller Mahkoa Stonehoof of the Earthen Ring watches it from the south-east, and ',
        'his last message said the ground there is running hot.$B$BGo to him. He knows the earth''s ',
        'anger better than any of us, and he will know what to do with a pair of hands like yours.'),
    '',
    'Speak to Earthcaller Mahkoa Stonehoof south-east of the Sanctum of the Prophets.');
-- 751259 False Prophets (MinLevel 119): Earthcaller Mahkoa Stonehoof -> Earthcaller Mahkoa Stonehoof
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751259, 2, -1, 119, 4923, 0, 0, 6, 135560, 8, 421860, 421868, 421876, 421884, 0, 0, 1, 1, 1, 1, 0, 0, 750, 4169,
    -3448, 1158, 5, 0, 3640713, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'False Prophets',
    'Earthcaller Mahkoa Stonehoof wants you to slay 8 Twilight Augurs at the Sanctum of the Prophets.',
    CONCAT('The Augurs read the future in the cracks of burning stone, and the future they read is always ',
        'the same: fire, and more fire. Their prophecies keep the whole camp fanatical.$B$BSilence eight ',
        'of the Twilight Augurs, $N. We will see how long their faith lasts without its prophets.'),
    '',
    'Return to Earthcaller Mahkoa Stonehoof south-east of the Sanctum of the Prophets.');
-- 751260 Retainers of the Hammer (MinLevel 119): Earthcaller Mahkoa Stonehoof -> Earthcaller Mahkoa Stonehoof
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751260, 2, -1, 119, 4923, 0, 0, 6, 135560, 8, 421864, 421872, 421880, 421888, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    4166.2, -3440.9, 1158, 5, 0, 3640767, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Retainers of the Hammer',
    'Earthcaller Mahkoa Stonehoof wants you to slay 8 Twilight Retainers at the Sanctum of the Prophets.',
    CONCAT('The Retainers guard the Augurs and haul whatever the prophets demand. They are not clever, but ',
        'there are many of them, and they fight like cornered wolves.$B$BThin their ranks. Eight of ',
        'them, $N, and the Sanctum will be far easier to crack.'),
    '',
    'Return to Earthcaller Mahkoa Stonehoof south-east of the Sanctum of the Prophets.');
-- 751261 Broken Prophecies (MinLevel 120): Earthcaller Mahkoa Stonehoof -> Earthcaller Mahkoa Stonehoof
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751261, 2, -1, 120, 4923, 0, 0, 6, 135560, 8, 421893, 421894, 421895, 0, 0, 0, 1, 1, 1, 0, 0, 0, 750, 4169,
    -3448, 1158, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20378, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0,
    'Broken Prophecies',
    'Earthcaller Mahkoa Stonehoof wants 6 Twilight Tablet Fragments taken from the Twilight Augurs.',
    CONCAT('The Augurs carve their prophecies into tablets of black stone and break them when the vision is ',
        'spent. The pieces they carry still hum with whatever they saw.$B$BBring me six Twilight Tablet ',
        'Fragments, $N. The earth remembers what is carved into it. If I listen closely, perhaps I can ',
        'hear the prophecy too - before it comes true.'),
    '',
    'Return to Earthcaller Mahkoa Stonehoof south-east of the Sanctum of the Prophets.');
-- 751262 The Last Sermon (MinLevel 120): Earthcaller Mahkoa Stonehoof -> Earthcaller Mahkoa Stonehoof
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751262, 2, -1, 120, 4923, 0, 0, 7, 162680, 8, 421940, 421941, 421942, 421943, 421944, 421945, 1, 1, 1, 1, 1, 1,
    750, 4173, -3418.9, 1158, 6, 0, 3640755, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'The Last Sermon',
    'Earthcaller Mahkoa Stonehoof wants you to slay 5 Emissaries of Flame at the Sanctum of the Prophets.',
    CONCAT('The Emissaries of Flame preach at the Sanctum as well. When they speak, the ground grows hot ',
        'beneath my hooves - they are calling something up from below. I am certain of it.$B$BFinish ',
        'what you began at the Throne of Flame. Five Emissaries, $N. Let their last sermon be a short ',
        'one.'),
    '',
    'Return to Earthcaller Mahkoa Stonehoof south-east of the Sanctum of the Prophets.');
-- 751263 Down to the Gates (MinLevel 121): Earthcaller Mahkoa Stonehoof -> Watcher Kaldras Thornwood
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751263, 2, -1, 121, 4923, 0, 0, 5, 108450, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 750, 4110, -3965, 1158, 5, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Down to the Gates',
    'Report to Watcher Kaldras Thornwood at the Gates of Sothann.',
    CONCAT('East of here the old Gates of Sothann stand open. Demons came through them once, in the War of ',
        'the Ancients, and the Twilight''s Hammer has found their leftovers useful again.$B$BWatcher ',
        'Kaldras Thornwood keeps the Guardians'' camp beside the gates. He sent word that the gorge ',
        'behind him is crawling. Go to him, $N.'),
    '',
    'Speak to Watcher Kaldras Thornwood at the Gates of Sothann.');
-- 751264 The Fallen (MinLevel 121): Watcher Kaldras Thornwood -> Watcher Kaldras Thornwood
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751264, 2, -1, 121, 4923, 0, 0, 6, 135560, 8, 421007, 421015, 421023, 421031, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    4299.1, -3949.5, 1158, 5, 0, 3640465, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'The Fallen',
    'Watcher Kaldras Thornwood wants you to slay 8 Fallen Cultists in Darkwhisper Gorge.',
    CONCAT('The cultists in the gorge are the ones the Hammer threw away - failed recruits, the weak, the ',
        'half-mad. Rather than die forgotten, they sold themselves to what the Legion left ',
        'behind.$B$BPity them if you like. Then kill them. Eight of the Fallen Cultists, in the gorge ',
        'north of the gates.'),
    '',
    'Return to Watcher Kaldras Thornwood at the Gates of Sothann.');
-- 751265 Horrors of the Gorge (MinLevel 121): Watcher Kaldras Thornwood -> Watcher Kaldras Thornwood
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751265, 2, -1, 121, 4923, 0, 0, 6, 135560, 8, 421005, 421013, 421021, 421029, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    4271.3, -3945.5, 1158, 5, 0, 3639724, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Horrors of the Gorge',
    'Watcher Kaldras Thornwood wants you to slay 8 Horrorguards in Darkwhisper Gorge.',
    CONCAT('Horrorguards. Demon-spawn from the old gates, bound by the Fallen to stand watch over the ',
        'gorge. They do not tire and they do not sleep.$B$BCut down eight of them, $N, before the Fallen ',
        'bind enough of them to call it an army.'),
    '',
    'Return to Watcher Kaldras Thornwood at the Gates of Sothann.');
-- 751266 The Scorched Plain (MinLevel 122): Watcher Kaldras Thornwood -> Talon Scout Ashari Swiftwing
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751266, 2, -1, 122, 4923, 0, 0, 5, 108450, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 750, 4394, -3118, 1158, 5, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'The Scorched Plain',
    'Report to Talon Scout Ashari Swiftwing on the ridge south-west of the Scorched Plain.',
    CONCAT('A storm crow came down this morning with a message from the west. Talon Scout Ashari Swiftwing ',
        'is watching the Scorched Plain, north of the Throne of Flame, and she says the Twilight''s ',
        'Hammer is massing there.$B$BThe gorge can hold without you now. Go to Ashari, $N. Her ridge ',
        'lies to the west, in the hills above the plain.'),
    '',
    'Speak to Talon Scout Ashari Swiftwing above the Scorched Plain.');
-- 751267 Scorchlords of the Plain (MinLevel 123): Talon Scout Ashari Swiftwing -> Talon Scout Ashari Swiftwing
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751267, 2, -1, 123, 4923, 0, 0, 6, 135560, 8, 421002, 421010, 421018, 421026, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    4619.6, -3199.5, 1158, 5, 0, 3641500, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Scorchlords of the Plain',
    'Talon Scout Ashari Swiftwing wants you to slay 10 Twilight Scorchlords in the camps on the Scorched Plain.',
    CONCAT('The Scorchlords burned this plain to cinders so nothing would grow tall enough to hide us. Now ',
        'they drill their soldiers in the ash.$B$BTen of them, $N. Strike the camps below this ridge and ',
        'get out before they can form a line.'),
    '',
    'Return to Talon Scout Ashari Swiftwing above the Scorched Plain.');
-- 751268 Captains in Cinder (MinLevel 123): Talon Scout Ashari Swiftwing -> Talon Scout Ashari Swiftwing
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751268, 2, -1, 123, 4923, 0, 0, 6, 135560, 8, 421006, 421014, 421022, 421030, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    4558.2, -3027.5, 1158, 5, 0, 3641502, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Captains in Cinder',
    'Talon Scout Ashari Swiftwing wants you to slay 4 Twilight Field Captains in the camps of the Scorched Plain.',
    CONCAT('Every army needs officers, and the Hammer''s are the Twilight Field Captains. You can tell them ',
        'by the way the others jump when they shout. Each camp on the plain has one or two.$B$BKill four ',
        'of them. An army that cannot be ordered is just a mob.'),
    '',
    'Return to Talon Scout Ashari Swiftwing above the Scorched Plain.');
-- 751269 Pendants of the Faithful (MinLevel 123): Talon Scout Ashari Swiftwing -> Talon Scout Ashari Swiftwing
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751269, 2, -1, 123, 4923, 0, 0, 6, 135560, 8, 421003, 421011, 421019, 421027, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    4605.7, -3134.6, 1158, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5879, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0,
    'Pendants of the Faithful',
    'Talon Scout Ashari Swiftwing wants 8 Twilight Pendants taken from the Twilight Scorchlords.',
    CONCAT('Every Scorchlord wears a pendant of the Twilight''s Hammer. The Druids of the Talon have ',
        'learned a thing or two about such trinkets: they mark rank, and they tell us which cell a ',
        'cultist belongs to.$B$BBring me eight of them, $N. With enough pendants I can tell how many ',
        'cells are camped on this plain - and which of them will march first.'),
    '',
    'Return to Talon Scout Ashari Swiftwing above the Scorched Plain.');
-- 751270 The Ridge Camp (MinLevel 124): Talon Scout Ashari Swiftwing -> Talon Scout Ashari Swiftwing
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751270, 2, -1, 124, 4923, 0, 0, 6, 135560, 8, 421001, 421009, 421017, 421025, 0, 0, 1, 1, 1, 1, 0, 0, 750, 4628,
    -2965, 1158, 5, 0, 3641500, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'The Ridge Camp',
    CONCAT('Talon Scout Ashari Swiftwing wants you to slay 8 Twilight Scorchlords in the ridge camp at the ',
        'western edge of the Scorched Plain.'),
    CONCAT('The camps on the plain are reeling, but the Hammer keeps another camp up on the ridge to the ',
        'north-west, where the ash meets the cliffs. From there they can see every move we make - and ',
        'they have started sending reinforcements down.$B$BCut off the flow, $N. Eight Scorchlords from ',
        'the ridge camp should keep them busy licking their own wounds.'),
    '',
    'Return to Talon Scout Ashari Swiftwing above the Scorched Plain.');
-- 751271 Orders from the Plain (MinLevel 124): Talon Scout Ashari Swiftwing -> Talon Scout Ashari Swiftwing
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751271, 2, -1, 124, 4923, 0, 0, 7, 162680, 8, 421047, 421055, 421063, 421071, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    4558.2, -3027.5, 1158, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 60264, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
    'Orders from the Plain',
    'Talon Scout Ashari Swiftwing wants the Twilight Orders carried by one of the Twilight Field Captains.',
    CONCAT('The captains get their orders in writing, sealed with the Hammer''s mark. One of them will be ',
        'carrying the latest.$B$BBring me those orders, $N. I want to know where this army means to ',
        'march before it takes its first step.'),
    '',
    'Return to Talon Scout Ashari Swiftwing above the Scorched Plain.');
-- 751272 Word for the Commander (MinLevel 124): Talon Scout Ashari Swiftwing -> Commander Mirelle Dawnspear
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751272, 2, -1, 124, 4923, 0, 0, 5, 108450, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 750, 4204, -2832, 1158, 5, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Word for the Commander',
    CONCAT('Take the news of the Twilight''s Hammer''s plans to Commander Mirelle Dawnspear at the ',
        'Avengers'' camp by Sulfuron Spire.'),
    CONCAT('Commander Mirelle must hear this today. The Avengers are the only force close enough to the ',
        'Regrowth to stop that march.$B$BHurry back to our camp by Sulfuron Spire, $N, and tell her ',
        'everything. I will keep watching the plain.'),
    '',
    'Speak to Commander Mirelle Dawnspear at the Avengers'' camp by Sulfuron Spire.');
-- 751273 Fire in the Regrowth (MinLevel 125): Commander Mirelle Dawnspear -> Keeper Elarion Duskleaf
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751273, 2, -1, 125, 4923, 0, 0, 5, 108450, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 750, 4290, -2346, 1158, 5, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Fire in the Regrowth',
    'Report to Keeper Elarion Duskleaf on the ridge south of the Regrowth.',
    CONCAT('The Firelord''s invaders are already in the Regrowth - Charred Flamewakers, Brimstone ',
        'Destroyers and worse. If the Hammer joins them there, the Sanctuary of Malorne will be fighting ',
        'on two fronts.$B$BKeeper Elarion Duskleaf watches the Regrowth from the ridge south of it, west ',
        'of our camp. Go to him. Whatever he asks, the Avengers will stand behind it.'),
    '',
    'Speak to Keeper Elarion Duskleaf on the ridge south of the Regrowth.');
-- 751274 Charred and Broken (MinLevel 125): Keeper Elarion Duskleaf -> Keeper Elarion Duskleaf
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751274, 2, -1, 125, 4923, 0, 0, 6, 135560, 8, 421946, 421954, 421962, 421970, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    4495.3, -2581.2, 1158, 5, 0, 3652791, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Charred and Broken',
    'Keeper Elarion Duskleaf wants you to slay 8 Charred Flamewakers in the Regrowth.',
    CONCAT('The Charred Flamewakers walk the Regrowth setting fire to every sapling we coax out of the ash. ',
        'They do not fight for land or for plunder. They burn because Ragnaros tells them to.$B$BEight ',
        'of them, $N. Give the seedlings one night without fire.'),
    '',
    'Return to Keeper Elarion Duskleaf on the ridge south of the Regrowth.');
-- 751275 Brimstone Tide (MinLevel 125): Keeper Elarion Duskleaf -> Keeper Elarion Duskleaf
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751275, 2, -1, 125, 4923, 0, 0, 6, 135560, 8, 421953, 421961, 421969, 421977, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    4577.9, -2472.8, 1158, 5, 0, 3652794, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Brimstone Tide',
    'Keeper Elarion Duskleaf wants you to slay 8 Brimstone Destroyers in the Regrowth.',
    CONCAT('The Brimstone Destroyers are the Firelord''s siege beasts - stone and fire and nothing else. ',
        'Where they walk, the soil turns to glass and nothing grows for a generation.$B$BBreak eight of ',
        'them before they reach the Sanctuary''s roots.'),
    '',
    'Return to Keeper Elarion Duskleaf on the ridge south of the Regrowth.');
-- 751276 Cores of the Invasion (MinLevel 126): Keeper Elarion Duskleaf -> Keeper Elarion Duskleaf
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751276, 2, -1, 126, 4923, 0, 0, 6, 135560, 8, 421979, 421980, 421981, 0, 0, 0, 1, 1, 1, 0, 0, 0, 750, 4499.9,
    -2479.7, 1158, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 55123, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0,
    'Cores of the Invasion',
    CONCAT('Keeper Elarion Duskleaf wants 6 Smoldering Cores taken from the Charred Flamewakers and ',
        'Brimstone Destroyers of the Regrowth.'),
    CONCAT('The elementals in the Regrowth burn from cores of living fire, like the ones the Emissaries ',
        'carry. An elemental whose core is torn out does not come back - not even in the ',
        'Firelands.$B$BBring me six Smoldering Cores, $N. I will see them sealed away where no cultist ',
        'can wake them again.'),
    '',
    'Return to Keeper Elarion Duskleaf on the ridge south of the Regrowth.');
-- 751277 Rage Unchecked (MinLevel 126): Keeper Elarion Duskleaf -> Keeper Elarion Duskleaf
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751277, 2, -1, 126, 4923, 0, 0, 6, 135560, 8, 421951, 421959, 421967, 421975, 0, 0, 1, 1, 1, 1, 0, 0, 750,
    4559.6, -2401, 1158, 5, 0, 3652557, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Rage Unchecked',
    'Keeper Elarion Duskleaf wants you to slay 8 Raging Invaders in the Regrowth.',
    CONCAT('The Raging Invaders lead the elementals'' push west toward the Sanctuary of Malorne. Some of ',
        'them have already reached its edge.$B$BHunt them, $N - in the heart of the Regrowth, and at the ',
        'Sanctuary itself if you must. Eight of them, and the push loses its spearhead.'),
    '',
    'Return to Keeper Elarion Duskleaf on the ridge south of the Regrowth.');
-- 751278 Hold the Regrowth (MinLevel 127): Keeper Elarion Duskleaf -> Keeper Elarion Duskleaf
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751278, 2, -1, 127, 4923, 0, 0, 7, 162680, 8, 422026, 422027, 422028, 422029, 422030, 422031, 1, 1, 1, 1, 1, 1,
    750, 4530.8, -2492.3, 1158, 6, 0, 3652791, 3652794, 3652557, 0, 6, 6, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0,
    'Hold the Regrowth',
    CONCAT('Keeper Elarion Duskleaf wants you to slay 6 Charred Flamewakers, 6 Brimstone Destroyers and 4 ',
        'Raging Invaders in the heart of the Regrowth.'),
    CONCAT('This is the moment, $N. The invaders are gathering in the heart of the Regrowth for one last ',
        'push, and the Hammer has not yet arrived to join them. If we break them now, the Twilight army ',
        'will find nothing to march toward.$B$BSix Flamewakers. Six Destroyers. Four Invaders. Hold the ',
        'Regrowth.'),
    '',
    'Return to Keeper Elarion Duskleaf on the ridge south of the Regrowth.');
-- 751279 Return to the Spire (MinLevel 127): Keeper Elarion Duskleaf -> Commander Mirelle Dawnspear
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751279, 2, -1, 127, 4923, 0, 0, 5, 108450, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 750, 4204, -2832, 1158, 5, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'Return to the Spire',
    'Return to Commander Mirelle Dawnspear at the Avengers'' camp by Sulfuron Spire.',
    CONCAT('Go back to our camp by the spire and tell Commander Mirelle that the Regrowth holds. The ',
        'Hammer''s army will arrive to find nothing left to join.$B$BAnd $N - thank you. When the trees ',
        'grow back here, some of them will be yours.'),
    '',
    'Speak to Commander Mirelle Dawnspear at the Avengers'' camp by Sulfuron Spire.');
-- 751280 The Fires Beyond (MinLevel 128): Commander Mirelle Dawnspear -> Archdruid Valtorin Mossheart
REPLACE INTO `quest_template` (
    `ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`,
    `RewardXPDifficulty`, `RewardMoney`, `Flags`, `RewardChoiceItemID1`, `RewardChoiceItemID2`,
    `RewardChoiceItemID3`, `RewardChoiceItemID4`, `RewardChoiceItemID5`, `RewardChoiceItemID6`,
    `RewardChoiceItemQuantity1`, `RewardChoiceItemQuantity2`, `RewardChoiceItemQuantity3`,
    `RewardChoiceItemQuantity4`, `RewardChoiceItemQuantity5`, `RewardChoiceItemQuantity6`, `POIContinent`, `POIx`,
    `POIy`, `RewardFactionID1`, `RewardFactionValue1`, `AllowableRaces`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`,
    `RequiredNpcOrGo3`, `RequiredNpcOrGo4`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`,
    `RequiredNpcOrGoCount3`, `RequiredNpcOrGoCount4`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`,
    `RequiredItemId4`, `RequiredItemId5`, `RequiredItemId6`, `RequiredItemCount1`, `RequiredItemCount2`,
    `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`, `RequiredItemCount6`, `VerifiedBuild`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`) VALUES (
    751280, 2, -1, 128, 4923, 0, 0, 5, 108450, 8, 422022, 422023, 422024, 422025, 0, 0, 1, 1, 1, 1, 0, 0, 750, 4196,
    -2824, 1158, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    'The Fires Beyond',
    'Speak with Archdruid Valtorin Mossheart at the Avengers'' camp by Sulfuron Spire.',
    CONCAT('We have pushed the Firelord''s servants back from every corner of southern Hyjal. But look ',
        'across the lake, $N. The gate on the spire still burns. Every elemental we killed came through ',
        'it, and in time every one of them will come back through it.$B$BThis war will not be won on our ',
        'side of the gate. Archdruid Valtorin has studied the portal since the day we came here. Speak ',
        'with him - he knows better than I do what waits beyond.'),
    '',
    'Speak to Archdruid Valtorin Mossheart at the Avengers'' camp by Sulfuron Spire.');

-- chain links, breadcrumb
DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 751250 AND 751280;
INSERT INTO `quest_template_addon` (`ID`, `MaxLevel`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`,
    `BreadcrumbForQuestId`, `SpecialFlags`) VALUES
(751250, 0, 0, 0, 0, 751251, 0),
(751251, 0, 0, 0, 0, 0, 0),
(751252, 0, 0, 0, 0, 0, 0),
(751253, 0, 751251, 0, 0, 0, 0),
(751254, 0, 751253, 0, 0, 0, 0),
(751255, 0, 751253, 0, 0, 0, 0),
(751256, 0, 751253, 0, 0, 0, 0),
(751257, 0, 751254, 0, 0, 0, 0),
(751258, 0, 751257, 0, 0, 0, 0),
(751259, 0, 751258, 0, 0, 0, 0),
(751260, 0, 751258, 0, 0, 0, 0),
(751261, 0, 751259, 0, 0, 0, 0),
(751262, 0, 751260, 0, 0, 0, 0),
(751263, 0, 751262, 0, 0, 0, 0),
(751264, 0, 751263, 0, 0, 0, 0),
(751265, 0, 751263, 0, 0, 0, 0),
(751266, 0, 751264, 0, 0, 0, 0),
(751267, 0, 751266, 0, 0, 0, 0),
(751268, 0, 751266, 0, 0, 0, 0),
(751269, 0, 751266, 0, 0, 0, 0),
(751270, 0, 751267, 0, 0, 0, 0),
(751271, 0, 751268, 0, 0, 0, 0),
(751272, 0, 751271, 0, 0, 0, 0),
(751273, 0, 751272, 0, 0, 0, 0),
(751274, 0, 751273, 0, 0, 0, 0),
(751275, 0, 751273, 0, 0, 0, 0),
(751276, 0, 751273, 0, 0, 0, 0),
(751277, 0, 751274, 0, 0, 0, 0),
(751278, 0, 751277, 0, 0, 0, 0),
(751279, 0, 751278, 0, 0, 0, 0),
(751280, 0, 751279, 0, 0, 0, 0);

-- texts
DELETE FROM `quest_offer_reward` WHERE `ID` BETWEEN 751250 AND 751280;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751250, 1,
    CONCAT('Hamuul sent you? Then the Circle has not forgotten us.$B$BWe hold the doorstep of the Firelands ',
        'with too few blades, and the enemy grows bolder every night. Catch your breath, $C. Then we ',
        'have work.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751251;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751251, 1,
    CONCAT('The shore has gone quiet. I can almost hear the fire settle.$B$BThat was good work. Take this - ',
        'the Avengers look after those who stand with them.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751252;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751252, 1,
    CONCAT('Five... and every one of them still warm. Listen - you can hear them, faintly, like a fire in ',
        'another room.$B$BThey will be quiet soon. Thank you, $N.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751253;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751253, 1,
    CONCAT('Mirelle sent you? She always knows when I am about to ask for help.$B$BWelcome to the Rise, $N. ',
        'Keep your head low - the Hammer has eyes on every ridge.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751254;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751254, 1,
    CONCAT('Already the line is breaking. I watched two of their captives slip away into the rocks while ',
        'you worked. Well done.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751255;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751255, 1,
    CONCAT('It gives me no joy. Some of them were druids of this mountain once. Still... it had to be done, ',
        'and you did it cleanly.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751256;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751256, 1,
    CONCAT('Singed, but readable. The winds whisper that the answer is in here somewhere. I will send ',
        'copies to our camp and to the Earthen Ring by nightfall. You have my thanks.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751257;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751257, 1,
    CONCAT('The fires on the terrace have gone out. I never thought I would see the Rise this ',
        'quiet.$B$BTake this. You have earned better than the rags the Hammer left behind.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751258;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751258, 1,
    CONCAT('Lyria''s champion. Good. The stone beneath the Sanctum is crying out, and I am only one ',
        'tauren.$B$BKneel a moment. Feel how the ground trembles? That is not the mountain. That is ',
        'them.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751259;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751259, 1,
    'The chanting falters. Faith without a voice does not last long - not that kind of faith. You have done well.', 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751260;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751260, 1,
    'Fewer guards, fewer hands to carry stone and fire. The Sanctum weakens.', 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751261;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751261, 1,
    CONCAT('Fire beneath the mountain... a gate that does not close... and a host that waits for a sign. ',
        'Hm. This is darker than I feared.$B$BStill, you have done well to bring them. The Augurs will ',
        'not finish this prophecy.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751262;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751262, 1,
    CONCAT('There. Do you feel it? The stone is cooling. Whatever they were calling has turned back toward ',
        'the deep.$B$BThe Earthen Ring does not forget a friend. Choose one of these - you will need it ',
        'where you are going.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751263;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751263, 1,
    CONCAT('Mahkoa''s runner said you might come. I hoped you would.$B$BLook north, into Darkwhisper Gorge. ',
        'Everything that moves in there wants us dead.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751264;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751264, 1,
    'Eight fewer voices calling to the old gate. The gorge feels less crowded already.', 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751265;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751265, 1,
    'Good. Demons do not mourn their own, but the Fallen will notice their guards are gone. Let them worry.', 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751266;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751266, 1,
    CONCAT('You came quickly. Good. Look down there - see the banners? That is not a camp. That is an army ',
        'getting ready to march.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751267;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751267, 1,
    'Ha! I watched it all from the ridge. They never knew where you were coming from. Here - take this.', 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751268;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751268, 1,
    'Listen to them down there, shouting over each other. Nobody is giving the orders now. Well done.', 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751269;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751269, 1,
    CONCAT('Three different cells... no, four. The Hammer is pouring everything it has into this plain. I ',
        'will send word to the Circle at once.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751270;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751270, 1,
    'No more reinforcements, and no more eyes on the ridge. Now I can read the plain like a map.', 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751271;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751271, 1,
    CONCAT('By the Earthmother... They are not marching on the Gates, or on the Rise. They mean to march ',
        'west through the hills and join the invaders in the Regrowth - and from there, strike at the ',
        'Sanctuary of Malorne itself.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751272;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751272, 1,
    CONCAT('The Regrowth. Of course. After everything the Circle has replanted there, they mean to burn it ',
        'twice.$B$BYou were right to come straight to me.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751273;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751273, 1,
    CONCAT('Mirelle sends help? Then Elune has not turned her face from this mountain after all.$B$BLook ',
        'down there, $N. Every tree we planted, they burned. Every one.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751274;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751274, 1,
    'Fewer fires tonight. Tomorrow we plant again. Thank you.', 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751275;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751275, 1,
    'Glass and slag... but it stops where they fell. The soil past that line can still be saved.', 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751276;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751276, 1,
    'Six. Each one of these would have come back to burn the Regrowth again. Now they will sleep.', 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751277;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751277, 1,
    'The push is faltering. I can see the Sanctuary''s defenders holding their ground at last.', 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751278;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751278, 1,
    CONCAT('It holds. It holds! Look at it - ash and cinders, and not one flame moving.$B$BThis mountain ',
        'will remember what you did here. So will I.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751279;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751279, 1,
    CONCAT('The Regrowth holds, the Rise is quiet, the Gates are watched and the Scorched Plain is in ',
        'disarray. You have done in days what my Avengers could not do in weeks.'), 0);
DELETE FROM `quest_offer_reward` WHERE `ID` = 751280;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`) VALUES (
    751280, 1,
    CONCAT('Mirelle is right. What waits on the other side is the Firelord''s own realm, and it will not be ',
        'won by holding a ridge.$B$BThe Circle is gathering its strength. When the call comes to carry ',
        'the fight through the fire, we will need champions who have already walked through it. Be ',
        'ready, $N. That day is coming.'), 0);
DELETE FROM `quest_request_items` WHERE `ID` BETWEEN 751250 AND 751280;
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`,
    `VerifiedBuild`) VALUES
(751251, 6, 6, 'Are the Emissaries still preaching on that shore?', 0),
(751252, 6, 6, 'Do you have the cores? Careful - they burn through cloth.', 0),
(751254, 6, 6, 'The whips still crack up on the Rise. I can hear them from here.', 0),
(751255, 6, 6, 'Did the Ascendants burn out?', 0),
(751256, 6, 6, 'Have you found more of their pages, $N?', 0),
(751257, 6, 6, 'Is the terrace still burning?', 0),
(751259, 6, 6, 'The Augurs still chant. I can feel it in my hooves.', 0),
(751260, 6, 6, 'Do the Retainers still stand guard?', 0),
(751261, 6, 6, 'Have you brought the fragments? Hold them by the edges.', 0),
(751262, 6, 6, 'The ground is still warm. Are the Emissaries still speaking?', 0),
(751264, 6, 6, 'Did you find the Fallen?', 0),
(751265, 6, 6, 'Still hearing hooves in the gorge, $N?', 0),
(751267, 6, 6, 'From up here I count fewer banners. Not enough fewer.', 0),
(751268, 6, 6, 'Have the captains fallen?', 0),
(751269, 6, 6, 'Pendants? Any more?', 0),
(751270, 6, 6, 'Are they still coming down from the ridge?', 0),
(751271, 6, 6, 'Did one of the captains have the orders?', 0),
(751274, 6, 6, 'I still see fires down there.', 0),
(751275, 6, 6, 'Are the Destroyers still on the move?', 0),
(751276, 6, 6, 'Do you have the cores?', 0),
(751277, 6, 6, 'The Invaders still rage. Hurry.', 0),
(751278, 6, 6, 'Does the Regrowth hold?', 0);

-- givers and enders (Arch Druid Hamuul Runetotem 3639858 at the Sanctuary of Malorne gives the breadcrumb)
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 751250 AND 751280;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(3639858, 751250),
(832000, 751251),
(832001, 751252),
(832000, 751253),
(832004, 751254),
(832004, 751255),
(832005, 751256),
(832004, 751257),
(832004, 751258),
(832006, 751259),
(832006, 751260),
(832006, 751261),
(832006, 751262),
(832006, 751263),
(832007, 751264),
(832007, 751265),
(832007, 751266),
(832008, 751267),
(832008, 751268),
(832008, 751269),
(832008, 751270),
(832008, 751271),
(832008, 751272),
(832000, 751273),
(832009, 751274),
(832009, 751275),
(832009, 751276),
(832009, 751277),
(832009, 751278),
(832009, 751279),
(832000, 751280);
DELETE FROM `creature_questender` WHERE `quest` BETWEEN 751250 AND 751280;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(832000, 751250),
(832000, 751251),
(832001, 751252),
(832004, 751253),
(832004, 751254),
(832004, 751255),
(832005, 751256),
(832004, 751257),
(832006, 751258),
(832006, 751259),
(832006, 751260),
(832006, 751261),
(832006, 751262),
(832007, 751263),
(832007, 751264),
(832007, 751265),
(832008, 751266),
(832008, 751267),
(832008, 751268),
(832008, 751269),
(832008, 751270),
(832008, 751271),
(832000, 751272),
(832009, 751273),
(832009, 751274),
(832009, 751275),
(832009, 751276),
(832009, 751277),
(832009, 751278),
(832000, 751279),
(832001, 751280);

-- quest map markers: octagons over the target spawn clusters (bots walk to a random point inside), turn-in on the
-- ender spawn
DELETE FROM `quest_poi` WHERE `QuestID` BETWEEN 751250 AND 751280;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`,
    `Flags`, `VerifiedBuild`) VALUES
(751250, 0, -1, 750, 1216, 0, 0, 1, 0),
(751251, 0, 0, 750, 1216, 0, 0, 1, 0),
(751251, 1, 0, 750, 1216, 0, 0, 1, 0),
(751251, 2, 0, 750, 1216, 0, 0, 1, 0),
(751251, 3, 0, 750, 1216, 0, 0, 1, 0),
(751251, 4, -1, 750, 1216, 0, 0, 1, 0),
(751252, 0, 4, 750, 1216, 0, 0, 1, 0),
(751252, 1, 4, 750, 1216, 0, 0, 1, 0),
(751252, 2, 4, 750, 1216, 0, 0, 1, 0),
(751252, 3, 4, 750, 1216, 0, 0, 1, 0),
(751252, 4, -1, 750, 1216, 0, 0, 1, 0),
(751253, 0, -1, 750, 1216, 0, 0, 1, 0),
(751254, 0, 0, 750, 1216, 0, 0, 1, 0),
(751254, 1, 0, 750, 1216, 0, 0, 1, 0),
(751254, 2, 0, 750, 1216, 0, 0, 1, 0),
(751254, 3, -1, 750, 1216, 0, 0, 1, 0),
(751255, 0, 0, 750, 1216, 0, 0, 1, 0),
(751255, 1, 0, 750, 1216, 0, 0, 1, 0),
(751255, 2, -1, 750, 1216, 0, 0, 1, 0),
(751256, 0, 4, 750, 1216, 0, 0, 1, 0),
(751256, 1, -1, 750, 1216, 0, 0, 1, 0),
(751257, 0, 0, 750, 1216, 0, 0, 1, 0),
(751257, 1, 1, 750, 1216, 0, 0, 1, 0),
(751257, 2, -1, 750, 1216, 0, 0, 1, 0),
(751258, 0, -1, 750, 1216, 0, 0, 1, 0),
(751259, 0, 0, 750, 1216, 0, 0, 1, 0),
(751259, 1, -1, 750, 1216, 0, 0, 1, 0),
(751260, 0, 0, 750, 1216, 0, 0, 1, 0),
(751260, 1, 0, 750, 1216, 0, 0, 1, 0),
(751260, 2, -1, 750, 1216, 0, 0, 1, 0),
(751261, 0, 4, 750, 1216, 0, 0, 1, 0),
(751261, 1, -1, 750, 1216, 0, 0, 1, 0),
(751262, 0, 0, 750, 1216, 0, 0, 1, 0),
(751262, 1, 0, 750, 1216, 0, 0, 1, 0),
(751262, 2, -1, 750, 1216, 0, 0, 1, 0),
(751263, 0, -1, 750, 1216, 0, 0, 1, 0),
(751264, 0, 0, 750, 1216, 0, 0, 1, 0),
(751264, 1, 0, 750, 1216, 0, 0, 1, 0),
(751264, 2, -1, 750, 1216, 0, 0, 1, 0),
(751265, 0, 0, 750, 1216, 0, 0, 1, 0),
(751265, 1, 0, 750, 1216, 0, 0, 1, 0),
(751265, 2, 0, 750, 1216, 0, 0, 1, 0),
(751265, 3, -1, 750, 1216, 0, 0, 1, 0),
(751266, 0, -1, 750, 1216, 0, 0, 1, 0),
(751267, 0, 0, 750, 1216, 0, 0, 1, 0),
(751267, 1, 0, 750, 1216, 0, 0, 1, 0),
(751267, 2, 0, 750, 1216, 0, 0, 1, 0),
(751267, 3, -1, 750, 1216, 0, 0, 1, 0),
(751268, 0, 0, 750, 1216, 0, 0, 1, 0),
(751268, 1, 0, 750, 1216, 0, 0, 1, 0),
(751268, 2, -1, 750, 1216, 0, 0, 1, 0),
(751269, 0, 4, 750, 1216, 0, 0, 1, 0),
(751269, 1, 4, 750, 1216, 0, 0, 1, 0),
(751269, 2, 4, 750, 1216, 0, 0, 1, 0),
(751269, 3, 4, 750, 1216, 0, 0, 1, 0),
(751269, 4, -1, 750, 1216, 0, 0, 1, 0),
(751270, 0, 0, 750, 1216, 0, 0, 1, 0),
(751270, 1, 0, 750, 1216, 0, 0, 1, 0),
(751270, 2, -1, 750, 1216, 0, 0, 1, 0),
(751271, 0, 4, 750, 1216, 0, 0, 1, 0),
(751271, 1, 4, 750, 1216, 0, 0, 1, 0),
(751271, 2, -1, 750, 1216, 0, 0, 1, 0),
(751272, 0, -1, 750, 1216, 0, 0, 1, 0),
(751273, 0, -1, 750, 1216, 0, 0, 1, 0),
(751274, 0, 0, 750, 1216, 0, 0, 1, 0),
(751274, 1, 0, 750, 1216, 0, 0, 1, 0),
(751274, 2, -1, 750, 1216, 0, 0, 1, 0),
(751275, 0, 0, 750, 1216, 0, 0, 1, 0),
(751275, 1, 0, 750, 1216, 0, 0, 1, 0),
(751275, 2, 0, 750, 1216, 0, 0, 1, 0),
(751275, 3, -1, 750, 1216, 0, 0, 1, 0),
(751276, 0, 4, 750, 1216, 0, 0, 1, 0),
(751276, 1, 4, 750, 1216, 0, 0, 1, 0),
(751276, 2, 4, 750, 1216, 0, 0, 1, 0),
(751276, 3, -1, 750, 1216, 0, 0, 1, 0),
(751277, 0, 0, 750, 1216, 0, 0, 1, 0),
(751277, 1, -1, 750, 1216, 0, 0, 1, 0),
(751278, 0, 0, 750, 1216, 0, 0, 1, 0),
(751278, 1, 0, 750, 1216, 0, 0, 1, 0),
(751278, 2, 1, 750, 1216, 0, 0, 1, 0),
(751278, 3, 2, 750, 1216, 0, 0, 1, 0),
(751278, 4, -1, 750, 1216, 0, 0, 1, 0),
(751279, 0, -1, 750, 1216, 0, 0, 1, 0),
(751280, 0, -1, 750, 1216, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` BETWEEN 751250 AND 751280;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(751250, 0, 0, 4204, -2832, 0),
(751251, 0, 0, 4155, -2901, 0),
(751251, 0, 1, 4152, -2894, 0),
(751251, 0, 2, 4146, -2892, 0),
(751251, 0, 3, 4140, -2894, 0),
(751251, 0, 4, 4137, -2901, 0),
(751251, 0, 5, 4140, -2907, 0),
(751251, 0, 6, 4146, -2910, 0),
(751251, 0, 7, 4152, -2907, 0),
(751251, 1, 0, 4214, -2917, 0),
(751251, 1, 1, 4212, -2911, 0),
(751251, 1, 2, 4205, -2908, 0),
(751251, 1, 3, 4199, -2911, 0),
(751251, 1, 4, 4196, -2917, 0),
(751251, 1, 5, 4199, -2924, 0),
(751251, 1, 6, 4205, -2926, 0),
(751251, 1, 7, 4212, -2924, 0),
(751251, 2, 0, 4126, -2933, 0),
(751251, 2, 1, 4123, -2927, 0),
(751251, 2, 2, 4117, -2924, 0),
(751251, 2, 3, 4111, -2927, 0),
(751251, 2, 4, 4108, -2933, 0),
(751251, 2, 5, 4111, -2940, 0),
(751251, 2, 6, 4117, -2942, 0),
(751251, 2, 7, 4123, -2940, 0),
(751251, 3, 0, 4131, -2985, 0),
(751251, 3, 1, 4128, -2978, 0),
(751251, 3, 2, 4122, -2976, 0),
(751251, 3, 3, 4116, -2978, 0),
(751251, 3, 4, 4113, -2985, 0),
(751251, 3, 5, 4116, -2991, 0),
(751251, 3, 6, 4122, -2994, 0),
(751251, 3, 7, 4128, -2991, 0),
(751251, 4, 0, 4204, -2832, 0),
(751252, 0, 0, 4155, -2901, 0),
(751252, 0, 1, 4152, -2894, 0),
(751252, 0, 2, 4146, -2892, 0),
(751252, 0, 3, 4140, -2894, 0),
(751252, 0, 4, 4137, -2901, 0),
(751252, 0, 5, 4140, -2907, 0),
(751252, 0, 6, 4146, -2910, 0),
(751252, 0, 7, 4152, -2907, 0),
(751252, 1, 0, 4214, -2917, 0),
(751252, 1, 1, 4212, -2911, 0),
(751252, 1, 2, 4205, -2908, 0),
(751252, 1, 3, 4199, -2911, 0),
(751252, 1, 4, 4196, -2917, 0),
(751252, 1, 5, 4199, -2924, 0),
(751252, 1, 6, 4205, -2926, 0),
(751252, 1, 7, 4212, -2924, 0),
(751252, 2, 0, 4126, -2933, 0),
(751252, 2, 1, 4123, -2927, 0),
(751252, 2, 2, 4117, -2924, 0),
(751252, 2, 3, 4111, -2927, 0),
(751252, 2, 4, 4108, -2933, 0),
(751252, 2, 5, 4111, -2940, 0),
(751252, 2, 6, 4117, -2942, 0),
(751252, 2, 7, 4123, -2940, 0),
(751252, 3, 0, 4131, -2985, 0),
(751252, 3, 1, 4128, -2978, 0),
(751252, 3, 2, 4122, -2976, 0),
(751252, 3, 3, 4116, -2978, 0),
(751252, 3, 4, 4113, -2985, 0),
(751252, 3, 5, 4116, -2991, 0),
(751252, 3, 6, 4122, -2994, 0),
(751252, 3, 7, 4128, -2991, 0),
(751252, 4, 0, 4196, -2824, 0),
(751253, 0, 0, 3745, -3304, 0),
(751254, 0, 0, 3942, -3366, 0),
(751254, 0, 1, 3930, -3338, 0),
(751254, 0, 2, 3902, -3326, 0),
(751254, 0, 3, 3874, -3338, 0),
(751254, 0, 4, 3862, -3366, 0),
(751254, 0, 5, 3874, -3394, 0),
(751254, 0, 6, 3902, -3406, 0),
(751254, 0, 7, 3930, -3394, 0),
(751254, 1, 0, 3984, -3477, 0),
(751254, 1, 1, 3972, -3448, 0),
(751254, 1, 2, 3944, -3437, 0),
(751254, 1, 3, 3916, -3448, 0),
(751254, 1, 4, 3904, -3477, 0),
(751254, 1, 5, 3916, -3505, 0),
(751254, 1, 6, 3944, -3517, 0),
(751254, 1, 7, 3972, -3505, 0),
(751254, 2, 0, 3865, -3440, 0),
(751254, 2, 1, 3856, -3418, 0),
(751254, 2, 2, 3835, -3409, 0),
(751254, 2, 3, 3813, -3418, 0),
(751254, 2, 4, 3804, -3440, 0),
(751254, 2, 5, 3813, -3462, 0),
(751254, 2, 6, 3835, -3471, 0),
(751254, 2, 7, 3856, -3462, 0),
(751254, 3, 0, 3745, -3304, 0),
(751255, 0, 0, 3917, -3451, 0),
(751255, 0, 1, 3905, -3423, 0),
(751255, 0, 2, 3877, -3411, 0),
(751255, 0, 3, 3849, -3423, 0),
(751255, 0, 4, 3837, -3451, 0),
(751255, 0, 5, 3849, -3479, 0),
(751255, 0, 6, 3877, -3491, 0),
(751255, 0, 7, 3905, -3479, 0),
(751255, 1, 0, 3997, -3475, 0),
(751255, 1, 1, 3986, -3447, 0),
(751255, 1, 2, 3957, -3435, 0),
(751255, 1, 3, 3929, -3447, 0),
(751255, 1, 4, 3917, -3475, 0),
(751255, 1, 5, 3929, -3504, 0),
(751255, 1, 6, 3957, -3515, 0),
(751255, 1, 7, 3986, -3504, 0),
(751255, 2, 0, 3745, -3304, 0),
(751256, 0, 0, 3943, -3432, 0),
(751256, 0, 1, 3931, -3404, 0),
(751256, 0, 2, 3903, -3392, 0),
(751256, 0, 3, 3875, -3404, 0),
(751256, 0, 4, 3863, -3432, 0),
(751256, 0, 5, 3875, -3461, 0),
(751256, 0, 6, 3903, -3472, 0),
(751256, 0, 7, 3931, -3461, 0),
(751256, 1, 0, 3739, -3298, 0),
(751257, 0, 0, 3875, -3395, 0),
(751257, 0, 1, 3863, -3367, 0),
(751257, 0, 2, 3835, -3355, 0),
(751257, 0, 3, 3807, -3367, 0),
(751257, 0, 4, 3795, -3395, 0),
(751257, 0, 5, 3807, -3423, 0),
(751257, 0, 6, 3835, -3435, 0),
(751257, 0, 7, 3863, -3423, 0),
(751257, 1, 0, 3910, -3445, 0),
(751257, 1, 1, 3898, -3417, 0),
(751257, 1, 2, 3870, -3405, 0),
(751257, 1, 3, 3841, -3417, 0),
(751257, 1, 4, 3830, -3445, 0),
(751257, 1, 5, 3841, -3473, 0),
(751257, 1, 6, 3870, -3485, 0),
(751257, 1, 7, 3898, -3473, 0),
(751257, 2, 0, 3745, -3304, 0),
(751258, 0, 0, 4058, -3602, 0),
(751259, 0, 0, 4209, -3448, 0),
(751259, 0, 1, 4197, -3420, 0),
(751259, 0, 2, 4169, -3408, 0),
(751259, 0, 3, 4141, -3420, 0),
(751259, 0, 4, 4129, -3448, 0),
(751259, 0, 5, 4141, -3476, 0),
(751259, 0, 6, 4169, -3488, 0),
(751259, 0, 7, 4197, -3476, 0),
(751259, 1, 0, 4058, -3602, 0),
(751260, 0, 0, 4201, -3391, 0),
(751260, 0, 1, 4189, -3362, 0),
(751260, 0, 2, 4161, -3351, 0),
(751260, 0, 3, 4132, -3362, 0),
(751260, 0, 4, 4121, -3391, 0),
(751260, 0, 5, 4132, -3419, 0),
(751260, 0, 6, 4161, -3431, 0),
(751260, 0, 7, 4189, -3419, 0),
(751260, 1, 0, 4212, -3491, 0),
(751260, 1, 1, 4200, -3463, 0),
(751260, 1, 2, 4172, -3451, 0),
(751260, 1, 3, 4143, -3463, 0),
(751260, 1, 4, 4132, -3491, 0),
(751260, 1, 5, 4143, -3519, 0),
(751260, 1, 6, 4172, -3531, 0),
(751260, 1, 7, 4200, -3519, 0),
(751260, 2, 0, 4058, -3602, 0),
(751261, 0, 0, 4209, -3448, 0),
(751261, 0, 1, 4197, -3420, 0),
(751261, 0, 2, 4169, -3408, 0),
(751261, 0, 3, 4141, -3420, 0),
(751261, 0, 4, 4129, -3448, 0),
(751261, 0, 5, 4141, -3476, 0),
(751261, 0, 6, 4169, -3488, 0),
(751261, 0, 7, 4197, -3476, 0),
(751261, 1, 0, 4058, -3602, 0),
(751262, 0, 0, 4201, -3480, 0),
(751262, 0, 1, 4189, -3451, 0),
(751262, 0, 2, 4161, -3440, 0),
(751262, 0, 3, 4133, -3451, 0),
(751262, 0, 4, 4121, -3480, 0),
(751262, 0, 5, 4133, -3508, 0),
(751262, 0, 6, 4161, -3520, 0),
(751262, 0, 7, 4189, -3508, 0),
(751262, 1, 0, 4220, -3358, 0),
(751262, 1, 1, 4210, -3333, 0),
(751262, 1, 2, 4185, -3323, 0),
(751262, 1, 3, 4160, -3333, 0),
(751262, 1, 4, 4150, -3358, 0),
(751262, 1, 5, 4160, -3383, 0),
(751262, 1, 6, 4185, -3393, 0),
(751262, 1, 7, 4210, -3383, 0),
(751262, 2, 0, 4058, -3602, 0),
(751263, 0, 0, 4110, -3965, 0),
(751264, 0, 0, 4312, -4061, 0),
(751264, 0, 1, 4301, -4033, 0),
(751264, 0, 2, 4272, -4021, 0),
(751264, 0, 3, 4244, -4033, 0),
(751264, 0, 4, 4232, -4061, 0),
(751264, 0, 5, 4244, -4089, 0),
(751264, 0, 6, 4272, -4101, 0),
(751264, 0, 7, 4301, -4089, 0),
(751264, 1, 0, 4354, -3838, 0),
(751264, 1, 1, 4346, -3818, 0),
(751264, 1, 2, 4326, -3810, 0),
(751264, 1, 3, 4306, -3818, 0),
(751264, 1, 4, 4297, -3838, 0),
(751264, 1, 5, 4306, -3858, 0),
(751264, 1, 6, 4326, -3866, 0),
(751264, 1, 7, 4346, -3858, 0),
(751264, 2, 0, 4110, -3965, 0),
(751265, 0, 0, 4298, -3965, 0),
(751265, 0, 1, 4286, -3936, 0),
(751265, 0, 2, 4258, -3925, 0),
(751265, 0, 3, 4230, -3936, 0),
(751265, 0, 4, 4218, -3965, 0),
(751265, 0, 5, 4230, -3993, 0),
(751265, 0, 6, 4258, -4005, 0),
(751265, 0, 7, 4286, -3993, 0),
(751265, 1, 0, 4365, -3770, 0),
(751265, 1, 1, 4353, -3741, 0),
(751265, 1, 2, 4325, -3730, 0),
(751265, 1, 3, 4297, -3741, 0),
(751265, 1, 4, 4285, -3770, 0),
(751265, 1, 5, 4297, -3798, 0),
(751265, 1, 6, 4325, -3810, 0),
(751265, 1, 7, 4353, -3798, 0),
(751265, 2, 0, 4271, -4102, 0),
(751265, 2, 1, 4259, -4074, 0),
(751265, 2, 2, 4231, -4062, 0),
(751265, 2, 3, 4203, -4074, 0),
(751265, 2, 4, 4191, -4102, 0),
(751265, 2, 5, 4203, -4130, 0),
(751265, 2, 6, 4231, -4142, 0),
(751265, 2, 7, 4259, -4130, 0),
(751265, 3, 0, 4110, -3965, 0),
(751266, 0, 0, 4394, -3118, 0),
(751267, 0, 0, 4642, -3343, 0),
(751267, 0, 1, 4630, -3315, 0),
(751267, 0, 2, 4602, -3303, 0),
(751267, 0, 3, 4573, -3315, 0),
(751267, 0, 4, 4562, -3343, 0),
(751267, 0, 5, 4573, -3371, 0),
(751267, 0, 6, 4602, -3383, 0),
(751267, 0, 7, 4630, -3371, 0),
(751267, 1, 0, 4736, -3150, 0),
(751267, 1, 1, 4724, -3122, 0),
(751267, 1, 2, 4696, -3110, 0),
(751267, 1, 3, 4668, -3122, 0),
(751267, 1, 4, 4656, -3150, 0),
(751267, 1, 5, 4668, -3179, 0),
(751267, 1, 6, 4696, -3190, 0),
(751267, 1, 7, 4724, -3179, 0),
(751267, 2, 0, 4601, -3105, 0),
(751267, 2, 1, 4589, -3077, 0),
(751267, 2, 2, 4561, -3065, 0),
(751267, 2, 3, 4533, -3077, 0),
(751267, 2, 4, 4521, -3105, 0),
(751267, 2, 5, 4533, -3134, 0),
(751267, 2, 6, 4561, -3145, 0),
(751267, 2, 7, 4589, -3134, 0),
(751267, 3, 0, 4394, -3118, 0),
(751268, 0, 0, 4600, -3106, 0),
(751268, 0, 1, 4589, -3077, 0),
(751268, 0, 2, 4560, -3066, 0),
(751268, 0, 3, 4532, -3077, 0),
(751268, 0, 4, 4520, -3106, 0),
(751268, 0, 5, 4532, -3134, 0),
(751268, 0, 6, 4560, -3146, 0),
(751268, 0, 7, 4589, -3134, 0),
(751268, 1, 0, 4596, -2949, 0),
(751268, 1, 1, 4585, -2921, 0),
(751268, 1, 2, 4556, -2909, 0),
(751268, 1, 3, 4528, -2921, 0),
(751268, 1, 4, 4516, -2949, 0),
(751268, 1, 5, 4528, -2978, 0),
(751268, 1, 6, 4556, -2989, 0),
(751268, 1, 7, 4585, -2978, 0),
(751268, 2, 0, 4394, -3118, 0),
(751269, 0, 0, 4642, -3343, 0),
(751269, 0, 1, 4630, -3315, 0),
(751269, 0, 2, 4602, -3303, 0),
(751269, 0, 3, 4573, -3315, 0),
(751269, 0, 4, 4562, -3343, 0),
(751269, 0, 5, 4573, -3371, 0),
(751269, 0, 6, 4602, -3383, 0),
(751269, 0, 7, 4630, -3371, 0),
(751269, 1, 0, 4730, -3134, 0),
(751269, 1, 1, 4718, -3106, 0),
(751269, 1, 2, 4690, -3094, 0),
(751269, 1, 3, 4662, -3106, 0),
(751269, 1, 4, 4650, -3134, 0),
(751269, 1, 5, 4662, -3163, 0),
(751269, 1, 6, 4690, -3174, 0),
(751269, 1, 7, 4718, -3163, 0),
(751269, 2, 0, 4601, -3105, 0),
(751269, 2, 1, 4589, -3077, 0),
(751269, 2, 2, 4561, -3065, 0),
(751269, 2, 3, 4533, -3077, 0),
(751269, 2, 4, 4521, -3105, 0),
(751269, 2, 5, 4533, -3134, 0),
(751269, 2, 6, 4561, -3145, 0),
(751269, 2, 7, 4589, -3134, 0),
(751269, 3, 0, 4610, -2956, 0),
(751269, 3, 1, 4598, -2927, 0),
(751269, 3, 2, 4570, -2916, 0),
(751269, 3, 3, 4542, -2927, 0),
(751269, 3, 4, 4530, -2956, 0),
(751269, 3, 5, 4542, -2984, 0),
(751269, 3, 6, 4570, -2996, 0),
(751269, 3, 7, 4598, -2984, 0),
(751269, 4, 0, 4394, -3118, 0),
(751270, 0, 0, 4610, -2956, 0),
(751270, 0, 1, 4598, -2927, 0),
(751270, 0, 2, 4570, -2916, 0),
(751270, 0, 3, 4542, -2927, 0),
(751270, 0, 4, 4530, -2956, 0),
(751270, 0, 5, 4542, -2984, 0),
(751270, 0, 6, 4570, -2996, 0),
(751270, 0, 7, 4598, -2984, 0),
(751270, 1, 0, 4726, -2974, 0),
(751270, 1, 1, 4714, -2946, 0),
(751270, 1, 2, 4686, -2934, 0),
(751270, 1, 3, 4658, -2946, 0),
(751270, 1, 4, 4646, -2974, 0),
(751270, 1, 5, 4658, -3003, 0),
(751270, 1, 6, 4686, -3014, 0),
(751270, 1, 7, 4714, -3003, 0),
(751270, 2, 0, 4394, -3118, 0),
(751271, 0, 0, 4600, -3106, 0),
(751271, 0, 1, 4589, -3077, 0),
(751271, 0, 2, 4560, -3066, 0),
(751271, 0, 3, 4532, -3077, 0),
(751271, 0, 4, 4520, -3106, 0),
(751271, 0, 5, 4532, -3134, 0),
(751271, 0, 6, 4560, -3146, 0),
(751271, 0, 7, 4589, -3134, 0),
(751271, 1, 0, 4596, -2949, 0),
(751271, 1, 1, 4585, -2921, 0),
(751271, 1, 2, 4556, -2909, 0),
(751271, 1, 3, 4528, -2921, 0),
(751271, 1, 4, 4516, -2949, 0),
(751271, 1, 5, 4528, -2978, 0),
(751271, 1, 6, 4556, -2989, 0),
(751271, 1, 7, 4585, -2978, 0),
(751271, 2, 0, 4394, -3118, 0),
(751272, 0, 0, 4204, -2832, 0),
(751273, 0, 0, 4290, -2346, 0),
(751274, 0, 0, 4459, -2574, 0),
(751274, 0, 1, 4447, -2545, 0),
(751274, 0, 2, 4419, -2534, 0),
(751274, 0, 3, 4391, -2545, 0),
(751274, 0, 4, 4379, -2574, 0),
(751274, 0, 5, 4391, -2602, 0),
(751274, 0, 6, 4419, -2614, 0),
(751274, 0, 7, 4447, -2602, 0),
(751274, 1, 0, 4603, -2589, 0),
(751274, 1, 1, 4594, -2566, 0),
(751274, 1, 2, 4572, -2557, 0),
(751274, 1, 3, 4549, -2566, 0),
(751274, 1, 4, 4540, -2589, 0),
(751274, 1, 5, 4549, -2611, 0),
(751274, 1, 6, 4572, -2620, 0),
(751274, 1, 7, 4594, -2611, 0),
(751274, 2, 0, 4290, -2346, 0),
(751275, 0, 0, 4613, -2406, 0),
(751275, 0, 1, 4601, -2378, 0),
(751275, 0, 2, 4573, -2366, 0),
(751275, 0, 3, 4545, -2378, 0),
(751275, 0, 4, 4533, -2406, 0),
(751275, 0, 5, 4545, -2434, 0),
(751275, 0, 6, 4573, -2446, 0),
(751275, 0, 7, 4601, -2434, 0),
(751275, 1, 0, 4702, -2559, 0),
(751275, 1, 1, 4691, -2533, 0),
(751275, 1, 2, 4665, -2523, 0),
(751275, 1, 3, 4640, -2533, 0),
(751275, 1, 4, 4629, -2559, 0),
(751275, 1, 5, 4640, -2585, 0),
(751275, 1, 6, 4665, -2596, 0),
(751275, 1, 7, 4691, -2585, 0),
(751275, 2, 0, 4535, -2453, 0),
(751275, 2, 1, 4524, -2425, 0),
(751275, 2, 2, 4495, -2413, 0),
(751275, 2, 3, 4467, -2425, 0),
(751275, 2, 4, 4455, -2453, 0),
(751275, 2, 5, 4467, -2482, 0),
(751275, 2, 6, 4495, -2493, 0),
(751275, 2, 7, 4524, -2482, 0),
(751275, 3, 0, 4290, -2346, 0),
(751276, 0, 0, 4636, -2412, 0),
(751276, 0, 1, 4624, -2384, 0),
(751276, 0, 2, 4596, -2372, 0),
(751276, 0, 3, 4567, -2384, 0),
(751276, 0, 4, 4556, -2412, 0),
(751276, 0, 5, 4567, -2441, 0),
(751276, 0, 6, 4596, -2452, 0),
(751276, 0, 7, 4624, -2441, 0),
(751276, 1, 0, 4469, -2569, 0),
(751276, 1, 1, 4457, -2541, 0),
(751276, 1, 2, 4429, -2529, 0),
(751276, 1, 3, 4400, -2541, 0),
(751276, 1, 4, 4389, -2569, 0),
(751276, 1, 5, 4400, -2597, 0),
(751276, 1, 6, 4429, -2609, 0),
(751276, 1, 7, 4457, -2597, 0),
(751276, 2, 0, 4515, -2458, 0),
(751276, 2, 1, 4504, -2429, 0),
(751276, 2, 2, 4475, -2418, 0),
(751276, 2, 3, 4447, -2429, 0),
(751276, 2, 4, 4435, -2458, 0),
(751276, 2, 5, 4447, -2486, 0),
(751276, 2, 6, 4475, -2498, 0),
(751276, 2, 7, 4504, -2486, 0),
(751276, 3, 0, 4290, -2346, 0),
(751277, 0, 0, 4597, -2401, 0),
(751277, 0, 1, 4586, -2375, 0),
(751277, 0, 2, 4560, -2364, 0),
(751277, 0, 3, 4533, -2375, 0),
(751277, 0, 4, 4522, -2401, 0),
(751277, 0, 5, 4533, -2427, 0),
(751277, 0, 6, 4560, -2438, 0),
(751277, 0, 7, 4586, -2427, 0),
(751277, 1, 0, 4290, -2346, 0),
(751278, 0, 0, 4459, -2574, 0),
(751278, 0, 1, 4447, -2545, 0),
(751278, 0, 2, 4419, -2534, 0),
(751278, 0, 3, 4391, -2545, 0),
(751278, 0, 4, 4379, -2574, 0),
(751278, 0, 5, 4391, -2602, 0),
(751278, 0, 6, 4419, -2614, 0),
(751278, 0, 7, 4447, -2602, 0),
(751278, 1, 0, 4603, -2589, 0),
(751278, 1, 1, 4594, -2566, 0),
(751278, 1, 2, 4572, -2557, 0),
(751278, 1, 3, 4549, -2566, 0),
(751278, 1, 4, 4540, -2589, 0),
(751278, 1, 5, 4549, -2611, 0),
(751278, 1, 6, 4572, -2620, 0),
(751278, 1, 7, 4594, -2611, 0),
(751278, 2, 0, 4613, -2406, 0),
(751278, 2, 1, 4601, -2378, 0),
(751278, 2, 2, 4573, -2366, 0),
(751278, 2, 3, 4545, -2378, 0),
(751278, 2, 4, 4533, -2406, 0),
(751278, 2, 5, 4545, -2434, 0),
(751278, 2, 6, 4573, -2446, 0),
(751278, 2, 7, 4601, -2434, 0),
(751278, 3, 0, 4597, -2401, 0),
(751278, 3, 1, 4586, -2375, 0),
(751278, 3, 2, 4560, -2364, 0),
(751278, 3, 3, 4533, -2375, 0),
(751278, 3, 4, 4522, -2401, 0),
(751278, 3, 5, 4533, -2427, 0),
(751278, 3, 6, 4560, -2438, 0),
(751278, 3, 7, 4586, -2427, 0),
(751278, 4, 0, 4290, -2346, 0),
(751279, 0, 0, 4204, -2832, 0),
(751280, 0, 0, 4196, -2824, 0);

-- 4. quest-item drops on the target mobs' own loot tables (QuestRequired: only while a quest needs the item)
DELETE FROM `creature_loot_template` WHERE `Entry` = 3640755 AND `Item` = 55123 AND `Reference` = 0;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`,
    `MinCount`, `MaxCount`, `Comment`) VALUES
(3640755, 55123, 0, 60, 1, 1, 0, 1, 1, 'DC Firelands route: Smoldering Core');
DELETE FROM `creature_loot_template` WHERE `Entry` = 3640463 AND `Item` = 20404 AND `Reference` = 0;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`,
    `MinCount`, `MaxCount`, `Comment`) VALUES
(3640463, 20404, 0, 45, 1, 1, 0, 1, 1, 'DC Firelands route: Encrypted Twilight Text');
DELETE FROM `creature_loot_template` WHERE `Entry` = 3640709 AND `Item` = 20404 AND `Reference` = 0;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`,
    `MinCount`, `MaxCount`, `Comment`) VALUES
(3640709, 20404, 0, 45, 1, 1, 0, 1, 1, 'DC Firelands route: Encrypted Twilight Text');
DELETE FROM `creature_loot_template` WHERE `Entry` = 3640713 AND `Item` = 20378 AND `Reference` = 0;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`,
    `MinCount`, `MaxCount`, `Comment`) VALUES
(3640713, 20378, 0, 50, 1, 1, 0, 1, 1, 'DC Firelands route: Twilight Tablet Fragment');
DELETE FROM `creature_loot_template` WHERE `Entry` = 3641500 AND `Item` = 5879 AND `Reference` = 0;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`,
    `MinCount`, `MaxCount`, `Comment`) VALUES
(3641500, 5879, 0, 50, 1, 1, 0, 1, 1, 'DC Firelands route: Twilight Pendant');
DELETE FROM `creature_loot_template` WHERE `Entry` = 3641502 AND `Item` = 60264 AND `Reference` = 0;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`,
    `MinCount`, `MaxCount`, `Comment`) VALUES
(3641502, 60264, 0, 35, 1, 1, 0, 1, 1, 'DC Firelands route: Twilight Orders');
DELETE FROM `creature_loot_template` WHERE `Entry` = 3652791 AND `Item` = 55123 AND `Reference` = 0;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`,
    `MinCount`, `MaxCount`, `Comment`) VALUES
(3652791, 55123, 0, 45, 1, 1, 0, 1, 1, 'DC Firelands route: Smoldering Core');
DELETE FROM `creature_loot_template` WHERE `Entry` = 3652794 AND `Item` = 55123 AND `Reference` = 0;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`,
    `MinCount`, `MaxCount`, `Comment`) VALUES
(3652794, 55123, 0, 45, 1, 1, 0, 1, 1, 'DC Firelands route: Smoldering Core');

-- quest-target pools respawn in 120 s (bots: 300 s starves concurrent questers)
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 750 AND `id` = 3640755
    AND `guid` BETWEEN 12192721 AND 15500652 AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 750 AND `id` = 3640463
    AND `guid` BETWEEN 12190994 AND 15500578 AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 750 AND `id` = 3640709
    AND `guid` BETWEEN 12191820 AND 15500629 AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 750 AND `id` = 3640713
    AND `guid` BETWEEN 12191831 AND 15500649 AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 750 AND `id` = 3640767
    AND `guid` BETWEEN 12192890 AND 15500747 AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 750 AND `id` = 3640465
    AND `guid` BETWEEN 9844272 AND 9845012 AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 750 AND `id` = 3639724
    AND `guid` BETWEEN 9844271 AND 9844721 AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 750 AND `id` = 3641500
    AND `guid` BETWEEN 12192936 AND 15500949 AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 750 AND `id` = 3641502
    AND `guid` BETWEEN 12192962 AND 15500962 AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 750 AND `id` = 3652791
    AND `guid` BETWEEN 9843663 AND 9844163 AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 750 AND `id` = 3652794
    AND `guid` BETWEEN 9843670 AND 9843983 AND `spawntimesecs` > 120;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` = 750 AND `id` = 3652557 AND `spawntimesecs` > 120
    AND `guid` IN (
        9843724, 9843725, 9843733, 9843734, 9843735, 9843736, 9843737, 9843738, 9843739, 9843740, 9843742, 9843744,
        9843745, 9843746, 9843747, 9843748, 9843749, 9843750, 9843751);

-- 5. rest area: tavern trigger 7007 (client row in AreaTrigger.dbc, inside map 750's run; faction 6 = both)
DELETE FROM `areatrigger` WHERE `entry` = 7007;
INSERT INTO `areatrigger` (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
(7007, 750, 4205, -2832, 1008, 15, 0, 0, 0, 0);
DELETE FROM `areatrigger_tavern` WHERE `id` = 7007;
INSERT INTO `areatrigger_tavern` (`id`, `name`, `faction`) VALUES
(7007, 'DCHyjal - Throne of Flame, Avengers camp', 6);

-- Checks after applying (expected values in the labels):
--   SELECT 'quests (want 31)', COUNT(*) FROM `quest_template` WHERE `ID` BETWEEN 751250 AND 751280
--   UNION ALL SELECT 'spawns (want 11)', COUNT(*) FROM `creature` WHERE `guid` BETWEEN 9036000 AND 9036010
--   UNION ALL SELECT 'guids over cap (want 0)', COUNT(*) FROM `creature` WHERE `guid` > 16777215
--   UNION ALL SELECT 'starters (want 31)', COUNT(*) FROM `creature_queststarter`
--       WHERE `quest` BETWEEN 751250 AND 751280;
