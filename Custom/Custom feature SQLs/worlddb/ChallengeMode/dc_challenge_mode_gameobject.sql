-- =====================================================================
-- DarkChaos-255 Challenge Mode GameObject
-- =====================================================================
-- Creates a gameobject that players can interact with to access challenge modes
-- Based on: https://github.com/nl-saw/mod-challenge-modes
-- =====================================================================

-- Delete existing entries if they exist
DELETE FROM `gameobject_template` WHERE `entry` = 700010;
DELETE FROM `gameobject` WHERE `id` = 700010;
DELETE FROM `gameobject` WHERE `guid` IN (2500010, 2500011, 2500012, 2500013);

-- =====================================================================
-- GameObject Template
-- =====================================================================
-- Creates a Crystal Ball of Knowledge template for challenge mode access
-- =====================================================================

DELETE FROM `gameobject_template` WHERE (`entry` = 700010);
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`) VALUES
(700010, 10, 1027, 'Challenge Mode Manager', 'Speak', 'Opening', '', 0.3, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'gobject_challenge_modes', 12340);

-- =====================================================================
-- GameObject Spawns
-- =====================================================================
-- Spawns the challenge mode gameobject in major cities
-- You can add more locations as needed
-- =====================================================================

-- Stormwind (Alliance) - Trade District near Auction House
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`) VALUES
(2500010, 700010, 0, 1519, 5390, 1, 1, -8834.95, 622.84, 94.056, 3.9095, 0, 0, 0.927184, -0.374607, 300, 100, 1, '', 0);

-- Orgrimmar (Horde) - Valley of Strength near Bank
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`) VALUES
(2500011, 700010, 1, 1637, 1637, 1, 1, 1595.17, -4378.93, 7.51, 1.5708, 0, 0, 0.707107, 0.707107, 300, 100, 1, '', 0);

-- Dalaran (Neutral) - Runeweaver Square
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`) VALUES
(2500012, 700010, 571, 4395, 4740, 1, 1, 5809.55, 588.347, 660.139, 2.26893, 0, 0, 0.906308, 0.422618, 300, 100, 1, '', 0);

-- Shattrath (Neutral) - Center of City
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`) VALUES
(2500013, 700010, 530, 3703, 3703, 1, 1, -1838.16, 5301.79, -12.428, 5.41052, 0, 0, -0.422618, 0.906308, 300, 100, 1, '', 0);

-- =====================================================================
-- Notes:
-- =====================================================================
-- GameObject Type 10 = GAMEOBJECT_TYPE_GOOBER (clickable object)
-- displayId 6786 = Crystal Ball of Knowledge (purple glowing orb)
-- Data0 = 2000 (gossip menu, handled by script)
-- 
-- To add more spawn locations:
-- 1. Use in-game .gps command to get coordinates
-- 2. Add new INSERT statement with unique guid
-- 3. Update map, zoneId, areaId, position_x/y/z as needed
-- =====================================================================
