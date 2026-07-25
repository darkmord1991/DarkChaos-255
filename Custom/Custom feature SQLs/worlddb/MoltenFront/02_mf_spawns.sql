-- =====================================================================
-- Molten Front -- 02  Curated spawn port (fully-unlocked snapshot)
-- ---------------------------------------------------------------------
-- Ports the curated Molten Front spawns (nelt_world map 861, phaseMask IN
-- (2047,8,16,128) -- see 00_README.md) onto DC map **861** at their native
-- nelt coordinates. dc_entry = +3,600,000.
--
-- *** SEPARATE MAP (not map 750) ***  The Molten Front is a self-contained map
-- in the source with its OWN coordinate frame (ground z ~ -93..235), NOT a
-- corner of map 750 (Hyjal terrain z ~ 880..1929). So it becomes its own DC
-- map (id 861, free in Map.csv), connected to Hyjal by a portal (04). The
-- spawns keep their nelt coords verbatim -- they align on map 861's own terrain
-- (downported offline; see OFFLINE_PIPELINE.md). This file also deletes the old
-- FAILED map-750 MF placements (HyjalCata 32_/51_), which sat at incompatible coords.
--
-- *** PHASE COLLAPSE ***  This server has no phasing; a normal player is in
-- phaseMask 1. The source phases 8/16/128 do NOT contain bit 1, so their
-- creatures would be INVISIBLE if copied verbatim. Every ported spawn is
-- therefore forced to phaseMask=1 -- flattening the 4 curated phases into one
-- coherent, always-visible world (the whole point of the "fully-unlocked" snapshot).
--
-- npcflag/unit_flags are copied from the nelt TEMPLATE (not zeroed) so
-- questgivers/vendors/gossip work regardless of inherit semantics.
--
-- SUPERSEDES the partial HyjalCata MF spawn layers 32 (guid 14,000,000+/
-- 14,500,000+) and 51 (guid 12,900,000+ / 15,100,000+): their blocks are
-- deleted here, and this file lays down the complete set in fresh blocks
-- (creature 15,300,000+ / gameobject 15,200,000+). Remove the SOURCE lines for
-- 32_ and 51_ from ../HyjalCata/apply_all.sql, or ensure this folder runs last.
-- Idempotent. Run AFTER 01_mf_templates.sql.
-- =====================================================================
SET @OFF := 3600000;

-- ---- supersede the partial MF layers (32 + 51) and this file's own blocks ----
DELETE FROM acore_world.creature        WHERE guid BETWEEN 12900000 AND 12949999; -- 51 anchors
DELETE FROM acore_world.creature        WHERE guid BETWEEN 14000000 AND 14499999; -- 32 hub
DELETE FROM acore_world.creature_addon  WHERE guid BETWEEN 14000000 AND 14499999;
DELETE FROM acore_world.gameobject      WHERE guid BETWEEN 14500000 AND 14999999; -- 32 GO
DELETE FROM acore_world.gameobject      WHERE guid BETWEEN 15100000 AND 15149999; -- 51 GO
DELETE FROM acore_world.pool_creature   WHERE pool_entry BETWEEN 132000000 AND 132999999;
DELETE FROM acore_world.pool_gameobject WHERE pool_entry BETWEEN 132000000 AND 132999999;
DELETE FROM acore_world.pool_template   WHERE entry BETWEEN 132000000 AND 132999999;
DELETE FROM acore_world.creature        WHERE guid BETWEEN 15300000 AND 15309999; -- this file (cr)
DELETE FROM acore_world.gameobject      WHERE guid BETWEEN 15200000 AND 15209999; -- this file (GO)

-- ---- creatures: 1,118 curated spawns -> map 861, phaseMask forced to 1 ----
INSERT INTO acore_world.creature
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`)
SELECT 15300000 + ROW_NUMBER() OVER (ORDER BY c.guid), c.id+@OFF, 861, 4925, 4925, 1, 1, -1,
       c.position_x, c.position_y, c.position_z, c.orientation, GREATEST(c.spawntimesecs,120), c.spawndist, c.currentwaypoint,
       c.curhealth, c.curmana, c.MovementType, ct.npcflag, ct.unit_flags, 0, '', 0, 0, 'MoltenFront'
FROM nelt_world.creature c
JOIN nelt_world.creature_template ct ON ct.entry=c.id
WHERE c.map=861 AND c.phaseMask IN (2047,8,16,128);

-- ---- gameobjects: 241 curated spawns -> map 861, phaseMask forced to 1 ----
INSERT INTO acore_world.gameobject
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`)
SELECT 15200000 + ROW_NUMBER() OVER (ORDER BY g.guid), g.id+@OFF, 861, 4925, 4925, 1, 1,
       g.position_x, g.position_y, g.position_z, g.orientation, g.rotation0, g.rotation1, g.rotation2, g.rotation3,
       GREATEST(g.spawntimesecs,120), g.animprogress, g.state, '', 0, 'MoltenFront'
FROM nelt_world.gameobject g
WHERE g.map=861 AND g.phaseMask IN (2047,8,16,128);
