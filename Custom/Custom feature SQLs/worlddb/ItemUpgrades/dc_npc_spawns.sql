/*
 * DarkChaos Item Upgrade System - NPC Spawn Locations
 * 
 * Spawns three NPCs in main cities:
 * - Item Upgrade Vendor (ID: 190001) - Multiple city locations
 * - Artifact Curator (ID: 190002) - Central location
 * - Item Upgrader (ID: 190003) - Main upgrade interface in cities
 * 
 * Execute AFTER dc_npc_creature_templates.sql
 */

-- Item Upgrade Vendor spawns (ID: 190001)
-- Stormwind (Main square area)
DELETE FROM `creature` WHERE `guid` = 450001;
INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`) 
VALUES 
(450001, 190001, 0, 0, 0, 1, 1, 0, -8835.36, 531.91, 96.05, 1.57, 300, 0, 0, 100, 0, 0, 0, 0, 0);

-- Orgrimmar (Durotar area)
DELETE FROM `creature` WHERE `guid` = 450002;
INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`) 
VALUES 
(450002, 190001, 0, 0, 1, 1, 1, 0, 1632.48, -4251.78, 41.18, 4.71, 300, 0, 0, 100, 0, 0, 0, 0, 0);

-- Artifact Curator spawn (ID: 190002)
-- Shattrath (Central location)
DELETE FROM `creature` WHERE `guid` = 450003;
INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`) 
VALUES 
(450003, 190002, 0, 0, 530, 1, 1, 0, -1860.34, 5435.15, -12.43, 3.14, 300, 0, 0, 100, 0, 0, 0, 0, 0);

-- Item Upgrader spawns (ID: 190003) - Main upgrade interface
-- Stormwind (Near vendor)
DELETE FROM `creature` WHERE `guid` = 450004;
INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`) 
VALUES 
(450004, 190003, 0, 0, 0, 1, 1, 0, -8840.36, 531.91, 96.05, 1.57, 300, 0, 0, 100, 0, 0, 0, 0, 0);

-- Orgrimmar (Near vendor)
DELETE FROM `creature` WHERE `guid` = 450005;
INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`) 
VALUES 
(450005, 190003, 0, 0, 1, 1, 1, 0, 1627.48, -4251.78, 41.18, 4.71, 300, 0, 0, 100, 0, 0, 0, 0, 0);

