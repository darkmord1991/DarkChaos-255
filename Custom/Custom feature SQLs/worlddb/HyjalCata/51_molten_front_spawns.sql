-- =====================================================================
-- Molten Front -- 51  Script-carrier spawns (OPTIONAL / terrain-gated)
-- ---------------------------------------------------------------------
-- Neltharion ran the Molten Front on its own map 861; this downport maps
-- it onto map 750 at identical coordinates (x ~600-1500 corner). Map 750
-- currently has NO spawns in that corner and the MF terrain may not be
-- baked yet -- these grids only load when a player travels there, so the
-- rows are inert until the terrain lands. Apply AFTER the extended 29.
--
-- Spawns only the entries the ported C++ scripts need as static anchors:
-- controllers 75181/75182/75186, portals 52531, behemoths 52552, splash
-- bunnies 52893, flame-protection runes 52884-90/53887, Saynna 52854,
-- camera channel bunny 44403, fire hawks 53297/53300, + the Furnace Door
-- GO 208427. Guid blocks 12,900,000+ (creature) / 12,950,000+ (GO) --
-- deliberately OUTSIDE 30_neltharion_spawn_layer.sql's delete ranges so
-- re-running 30 cannot wipe them. Idempotent.
-- =====================================================================
SET @OFF := 3600000;

DELETE FROM acore_world.creature WHERE guid BETWEEN 12900000 AND 12949999;
INSERT INTO acore_world.creature (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`)
SELECT 12900000 + ROW_NUMBER() OVER (ORDER BY c.guid), c.id+@OFF, 750, 0, 0, 1, c.phaseMask, -1,
       c.position_x, c.position_y, c.position_z, c.orientation, c.spawntimesecs, c.spawndist, c.currentwaypoint,
       c.curhealth, c.curmana, c.MovementType, 0, 0, 0, '', 0, 0, 'MoltenFront-Nel'
FROM nelt_world.creature c
WHERE c.map=861 AND c.id IN (75181,75182,75186,52531,52552,52893,52884,52885,52886,52887,52888,52889,52890,53887,52854,44403,53297,53300);

DELETE FROM acore_world.gameobject WHERE guid BETWEEN 12950000 AND 12999999;
INSERT INTO acore_world.gameobject (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`)
SELECT 12950000 + ROW_NUMBER() OVER (ORDER BY g.guid), g.id+@OFF, 750, 0, 0, 1, g.phaseMask,
       g.position_x, g.position_y, g.position_z, g.orientation, g.rotation0, g.rotation1, g.rotation2, g.rotation3,
       g.spawntimesecs, g.animprogress, g.state, '', 0, 'MoltenFront-Nel'
FROM nelt_world.gameobject g
WHERE g.map=861 AND g.id IN (208427);
