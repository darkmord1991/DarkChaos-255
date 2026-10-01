-- Map 1413 (Legion Dalaran guild house): restore the second half of the Illidari Gateway.
-- Retail stacks two objects on this spot: 251579, the Legion portal ring (our 4100478, spawn 9600114),
-- and 251286, the Illidari door, banner and ground glow (our 4100472). 2026_06_28_01 deleted the
-- 4100472 spawn along with the non-functional class-hall portals. Restored as decoration only:
-- template 4100472 is GENERIC and its retail spell 215782 does not exist on this server.
DELETE FROM `gameobject` WHERE `id` = 4100472 AND `guid` = 9600496;
INSERT INTO `gameobject` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`, `ScriptName`, `VerifiedBuild`, `Comment`) VALUES
(9600496, 4100472, 1413, 0, 0, 1, 1, 942.2466, 1466.5264, 445.0687, 4.47212, 0, 0, 0.786755, -0.617266, 180, 255, 1, '', 0, 'Legion Dalaran 1413');
