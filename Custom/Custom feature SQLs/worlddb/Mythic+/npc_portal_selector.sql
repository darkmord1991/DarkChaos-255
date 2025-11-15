-- ========================================================================
-- Mythic+ Portal Selector NPC
-- ========================================================================
-- Purpose: Spawn portal NPC for dungeon difficulty selection and teleportation
-- Entry: 100101 (Dungeon Portal Selector)
-- Script: npc_dungeon_portal_selector
-- ========================================================================

USE acore_world;

-- ========================================================================
-- CREATURE TEMPLATE: Dungeon Portal Selector
-- ========================================================================
DELETE FROM `creature_template` WHERE `entry` = 100101;
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
    100101, 0, 0, 0, 0, 0, 'Portal Keeper', 'Dungeon Teleporter', NULL, 100101, 
    80, 80, 2, 35, 1, 1.0, 1.14286, 1.0, 1.0, 20, 1.0, 0, 0, 1.0, 2000, 2000, 1, 1, 
    1, 0, 2048, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1.0, 1.0, 1.0, 
    1.0, 0, 0, 1, 0, 0, 2, 'npc_dungeon_portal_selector', 12340
)
ON DUPLICATE KEY UPDATE `name`='Portal Keeper';

-- ========================================================================
-- CREATURE MODEL: Portal Keeper Display
-- ========================================================================
DELETE FROM `creature_template_model` WHERE `CreatureID` = 100101;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) 
VALUES 
(100101, 0, 25901, 1.0, 1.0, 12340);  -- Ethereal model

-- ========================================================================
-- GOSSIP MENU: Portal Keeper
-- ========================================================================
DELETE FROM `gossip_menu` WHERE `MenuID` = 100101;
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES (100101, 100101);

DELETE FROM `npc_text` WHERE `ID` = 100101;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, 
    `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`, `VerifiedBuild`) 
VALUES (100101, 
    'Greetings, adventurer. I can transport you to the dungeon entrance.$B$BChoose your difficulty and I shall open a portal.', 
    '', 0, 0, 1.0, 1, 0, 0, 0, 0, 0, 12340);

-- ========================================================================
-- EXAMPLE SPAWN LOCATIONS (Optional - uncomment to spawn)
-- ========================================================================
-- You can spawn this NPC manually with: .npc add 100101
-- Or uncomment below to place at specific locations:

-- Example: Dalaran (near Flight Master)
-- DELETE FROM `creature` WHERE `id1` = 100101 AND `guid` = 9000101;
-- INSERT INTO `creature` (
--     `guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, 
--     `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, 
--     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, 
--     `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`
-- ) VALUES (
--     9000101, 100101, 0, 0, 571, 4395, 4395, 1, 1, 0, 
--     5812.50, 448.75, 658.75, 4.71, 300, 0, 0, 12600, 0, 0, 
--     1, 0, 0, '', 12340, 0, 'Portal Keeper - Dungeon Teleporter (Dalaran)'
-- );

-- ========================================================================
-- USAGE NOTES
-- ========================================================================
-- This NPC provides a gossip menu to select dungeon difficulty (Normal/Heroic/Mythic)
-- and teleports players to the dungeon entrance using coordinates from dc_dungeon_entrances.
--
-- To spawn manually:
--   1. .npc add 100101 (spawns at your cursor location)
--   2. Place near dungeon entrances or major cities
--
-- The NPC uses npc_dungeon_portal_selector C++ script which:
--   - Queries dc_dungeon_entrances for teleport coordinates
--   - Sets player difficulty before teleporting
--   - Shows requirement information (level, item level)
--
-- ========================================================================

SELECT 'Portal Keeper NPC (entry 100101) created successfully!' AS Status;
SELECT 'Use ".npc add 100101" to spawn this NPC in-game' AS Usage;
