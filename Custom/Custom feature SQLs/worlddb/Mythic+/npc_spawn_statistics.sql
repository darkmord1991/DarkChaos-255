-- ========================================================================
-- Mythic+ Statistics NPC Spawn
-- ========================================================================
-- Purpose: Spawn Archivist Serah (entry 100060) in Dalaran near vault
-- Location: Dalaran (Krasus' Landing), coordinates TBD
-- Entry: 100060 (Statistics NPC)
-- ========================================================================

USE acore_world;

-- ========================================================================
-- CREATURE TEMPLATE: Archivist Serah (if not already in db)
-- ========================================================================
DELETE FROM `creature_template` WHERE `entry` = 100060;
INSERT INTO `creature_template` (
    `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, 
    `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, 
    `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, 
    `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, 
    `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, 
    `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, 
    `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, 
    `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, 
    `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, 
    `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, 
    `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`
) VALUES (
    100060, 0, 0, 0, 0, 0, 'Archivist Serah', 'Statistics Keeper', NULL, 100060, 
    80, 80, 2, 35, 1, 1.0, 1.14286, 1.0, 1.0, 20, 1.0, 0, 0, 1.0, 2000, 2000, 1, 1, 
    1, 0, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1.0, 1.0, 1.0, 
    1.0, 0, 0, 1, 0, 0, 2, 'npc_mythic_plus_statistics', 12340
)
ON DUPLICATE KEY UPDATE `name`='Archivist Serah';

-- ========================================================================
-- CREATURE MODEL: Assign display model (human female)
-- ========================================================================
DELETE FROM `creature_template_model` WHERE `CreatureID` = 100060;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) 
VALUES (100060, 0, 30259, 1.0, 1.0, 12340);

-- ========================================================================
-- CREATURE SPAWN: Dalaran (Krasus' Landing)
-- ========================================================================
-- Location: Near the flight master at Krasus' Landing, Dalaran
-- Coordinates: (5814.21, 450.53, 658.75, 1.57) - adjust as needed
-- Map: 571 (Northrend)
-- Zone: Dalaran

DELETE FROM `creature` WHERE `id1` = 100060;
INSERT INTO `creature` (
    `guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, 
    `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, 
    `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, 
    `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`
) VALUES (
    9000060, 100060, 0, 0, 571, 4395, 4395, 1, 1, 0, 
    5814.21, 450.53, 658.75, 1.57, 300, 0, 0, 12600, 0, 0, 
    1, 0, 0, '', 12340, 0, 'Archivist Serah - Mythic+ Statistics Keeper'
);

-- ========================================================================
-- GOSSIP MENU: Archivist Serah
-- ========================================================================
DELETE FROM `gossip_menu` WHERE `MenuID` = 100060;
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES (100060, 100060);

DELETE FROM `npc_text` WHERE `ID` = 100060;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, 
    `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`, `VerifiedBuild`) 
VALUES (100060, 
    'Greetings, champion! I am Archivist Serah, keeper of Mythic+ records.$B$BYour deeds in the keystoned dungeons do not go unnoticed. Would you like to review your statistics or check the leaderboards?', 
    '', 0, 0, 1.0, 1, 0, 0, 0, 0, 0, 12340);

-- ========================================================================
-- GOSSIP MENU OPTIONS: Statistics viewing options
-- ========================================================================
DELETE FROM `gossip_menu_option` WHERE `MenuID` = 100060;
INSERT INTO `gossip_menu_option` (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`, `BoxCoded`, `BoxMoney`, `BoxText`, `BoxBroadcastTextID`, `VerifiedBuild`) VALUES
(100060, 1, 0, '|cff00ccffShow me my personal Mythic+ statistics|r', 0, 1, 1, 0, 0, 0, 0, '', 0, 12340),
(100060, 2, 0, '|cffffff00Show me the global leaderboard|r', 0, 1, 1, 0, 0, 0, 0, '', 0, 12340),
(100060, 3, 0, '|cffff8000Show dungeon-specific leaderboards|r', 0, 1, 1, 0, 0, 0, 0, '', 0, 12340),
(100060, 4, 0, 'Nevermind.', 0, 1, 1, 0, 0, 0, 0, '', 0, 12340);

-- ========================================================================
-- COMPLETION MESSAGE
-- ========================================================================
SELECT 'Statistics NPC (Archivist Serah) spawned in Dalaran (Krasus Landing)' AS Status;
SELECT 'Entry: 100060, GUID: 9000060' AS Details;
SELECT 'Location: Near flight master (5814.21, 450.53, 658.75)' AS Location;
