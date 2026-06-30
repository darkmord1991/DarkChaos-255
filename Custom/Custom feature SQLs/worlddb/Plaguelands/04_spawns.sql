-- Plaguelands (DCPlaguelands, map 751)
-- dc_entry = 3,600,000 + original (isolated, tunable). Source cata_world(TDB434)->acore_world. Cross-DB INSERT...SELECT.
SET @OFF := 3600000;

-- idempotent: drop any prior dc spawns for this map first (spawns use auto-guid, so re-running would dupe).
DELETE FROM acore_world.creature   WHERE map=751 AND id>=@OFF;
DELETE FROM acore_world.gameobject WHERE map=751 AND id>=@OFF;

-- creature spawns (COALESCE the NOT-NULL acore cols that are nullable in cata)
INSERT INTO acore_world.creature (`id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`)
SELECT c.`id`+@OFF, 751, 4924, 4924, c.`spawnMask`, c.`phaseMask`, c.`equipment_id`, c.`position_x`, c.`position_y`, c.`position_z`, c.`orientation`, c.`spawntimesecs`, c.`wander_distance`, c.`currentwaypoint`, COALESCE(c.`curhealth`,1), COALESCE(c.`curmana`,0), c.`MovementType`, COALESCE(c.`npcflag`,0), COALESCE(c.`unit_flags`,0)
FROM cata_world.creature c WHERE (c.map=0 AND c.zoneId IN (139,28));

-- gameobject spawns
INSERT INTO acore_world.gameobject (`id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`)
SELECT g.`id`+@OFF, 751, 4924, 4924, g.`spawnMask`, g.`phaseMask`, g.`position_x`, g.`position_y`, g.`position_z`, g.`orientation`, g.`rotation0`, g.`rotation1`, g.`rotation2`, g.`rotation3`, g.`spawntimesecs`, g.`animprogress`, g.`state`
FROM cata_world.gameobject g WHERE (g.map=0 AND g.zoneId IN (139,28));
