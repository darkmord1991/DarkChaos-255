-- Blackwing Descent (map 669) — creature + gameobject spawns
-- Source: cata_world.creature / cata_world.gameobject WHERE map=669 (152 creatures / 45 GOs).
--
-- GUID remap: the cata guids are SPARSE (creatures 250047..396406) and do not fit this server's
-- ~46k free creature window with a linear offset, so we DENSELY remap via ROW_NUMBER() into
-- reserved sub-blocks:  creatures 9,555,001+ , gameobjects 9,500,001+.
-- The mapping is DETERMINISTIC (same source set + same ORDER BY guid => identical result), so
-- 05_groups.sql re-derives the exact same map for creature_formations / creature_addon / waypoints.
--
-- Not imported here (correctly absent from cata static spawns): Omnotron golems 42166/42178/42179/42180
-- and Onyxia 41270 are SCRIPT-SUMMONED by the CataTC encounter; Atramedes/Nefarian are event-summoned.
--
-- Phasing: cata PhaseId/PhaseGroup are NOT copied — an instance uses phaseMask=1 (always visible).
-- spawnMask is preserved from cata (raid difficulty bits 0=10N,1=25N,2=10H,3=25H align with 3.3.5).
-- MovementType is preserved (patrols: cata guids 250050/250116/250117 keep MovementType=2; their
-- creature_addon.path_id + waypoint_data are remapped in 05_groups.sql).
--
-- >>> COORDINATE GUARD (plan 1.4): positions are 4.3.4 client coords. Verify the retail-baked WDT
-- >>> MODF placement matches the 4.3.4 WMO before relying on these; if it diverges, apply the uniform
-- >>> transform to every position here (and to the hardcoded C++ Positions).

-- ---------------------------------------------------------------------------
-- creature
-- ---------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 9555001 AND 9555999;

INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`,
     `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`,
     `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`)
SELECT
    9555000 + ROW_NUMBER() OVER (ORDER BY c.`guid`), c.`id`, 669, c.`zoneId`, c.`areaId`, c.`spawnMask`, 1, c.`equipment_id`,
    c.`position_x`, c.`position_y`, c.`position_z`, c.`orientation`, c.`spawntimesecs`, c.`wander_distance`,
    c.`currentwaypoint`, c.`curhealth`, c.`curmana`, c.`MovementType`, COALESCE(c.`npcflag`, 0), COALESCE(c.`unit_flags`, 0),
    0, c.`ScriptName`, 0, 0, 'BWD'
FROM `cata_world`.`creature` c
WHERE c.`map` = 669;

-- ---------------------------------------------------------------------------
-- gameobject
-- ---------------------------------------------------------------------------
DELETE FROM `gameobject` WHERE `guid` BETWEEN 9500001 AND 9500999;

INSERT INTO `gameobject`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
     `position_x`, `position_y`, `position_z`, `orientation`,
     `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`,
     `ScriptName`, `VerifiedBuild`, `Comment`)
SELECT
    9500000 + ROW_NUMBER() OVER (ORDER BY g.`guid`), g.`id`, 669, g.`zoneId`, g.`areaId`, g.`spawnMask`, 1,
    g.`position_x`, g.`position_y`, g.`position_z`, g.`orientation`,
    g.`rotation0`, g.`rotation1`, g.`rotation2`, g.`rotation3`, g.`spawntimesecs`, g.`animprogress`, g.`state`,
    g.`ScriptName`, 0, 'BWD'
FROM `cata_world`.`gameobject` g
WHERE g.`map` = 669;
