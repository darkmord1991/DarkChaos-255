-- ---------------------------------------------------------------------------
-- 155  Hyjal round-25 -- the spawns the downport never brought across
-- ---------------------------------------------------------------------------
-- REVISED: this file originally measured the gap against `nelt_world` and found
-- 277 spawns.  That was the wrong yardstick.  `nelt_world` is a private
-- server's partial data; `cata_world` (TDB 434) is the authoritative Cata
-- source and is far richer.  Measured against it, inside the same footprint:
--
--     cata_world  4,986 spawns        DC map 750  3,310 spawns
--     -> only 3 entries missing ENTIRELY, but 94 entries are SHORT,
--        1,883 spawn instances fewer.  The zone is populated at ~66% density.
--
-- So the problem was never mostly "missing creatures" -- it is missing
-- INSTANCES of creatures that already exist.  That is why the zone reads as
-- sparse while every template audit came back clean.
--
-- WHAT THIS IMPORTS
--   1,254 spawns across 110 entries -- every cata_world spawn in the footprint
--   whose entry exists in the clone block and which has NO DC spawn of the same
--   entry within 10 yards.  The proximity guard is what makes this safe to run:
--   it tops up thinned-out areas without duplicating anything already placed,
--   and it makes the file idempotent by construction (a second run finds
--   nothing new).
--
--   The difference between 1,883 and 1,254 is spawns that DC already has within
--   10 yards under a slightly different position -- correctly left alone.
--
-- FOOTPRINT
--   x 3399..5771, y -4980..-1279, taken from DC's own map-750 spawn extents.
--   DC map 750 reuses Cata's Kalimdor coordinate frame for this region, so
--   coordinates are copied unchanged -- no transform is needed or wanted.
--   Note the rectangle is larger than Hyjal proper and clips the neighbouring
--   vanilla zones; see 157_ for what that means and why it is left opt-in.
--
-- EXCLUDED -- five entries the DC C++ owns and summons itself, which would
-- double-populate if also world-spawned (verified by grepping the script tree
-- for each entry id):
--     3675014 Nemesis Crystal target      -> zone_mount_hyjal.cpp
--     3652177 Child of Tortolla           -> npc_punt_child_of_tortolla
--     3639431 Twilight Slave              -> npc_twilight_slave
--     3639436 Twilight Proveditor         -> npc_twilight_proveditor
--     3639438 Twilight Slavedriver        -> npc_twilight_slavedriver
--
-- GUIDs start at 15,500,000, above the current max creature guid (15,400,005)
-- and clear of the documented custom allocations.  ROW_NUMBER() keeps them
-- contiguous and deterministic.
--
-- npcflag / unit_flags / dynamicflags are deliberately NOT copied per-spawn --
-- they are left 0 to inherit from creature_template.  Carrying Cata's
-- per-spawn flag overrides across is exactly what produced the "has
-- UNIT_NPC_FLAG_SPELLCLICK but no data in spellclick table" and vendor-flag
-- mismatches that 145_ and 152_ had to clean up afterwards.
-- ---------------------------------------------------------------------------

DELETE FROM `creature` WHERE `guid` BETWEEN 15500000 AND 15599999;

INSERT INTO `creature`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
   `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,
   `wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,
   `npcflag`,`unit_flags`,`dynamicflags`,`VerifiedBuild`)
SELECT 15500000 + ROW_NUMBER() OVER (ORDER BY c.id, c.guid),
       c.id + 3600000, 750, 0, 0, 1, 1, GREATEST(c.equipment_id, 0),
       c.position_x, c.position_y, c.position_z, c.orientation,
       GREATEST(c.spawntimesecs, 30),
       c.wander_distance, 0, c.curhealth, c.curmana, c.MovementType,
       0, 0, 0, 0
FROM cata_world.creature c
WHERE c.map = 1
  AND c.position_x BETWEEN 3399 AND 5771
  AND c.position_y BETWEEN -4980 AND -1279
  AND EXISTS (SELECT 1 FROM acore_world.creature_template ct WHERE ct.entry = c.id + 3600000)
  AND c.id NOT IN (75014, 52177, 39431, 39436, 39438)
  AND NOT EXISTS (
        SELECT 1 FROM acore_world.creature a
        WHERE a.map = 750 AND a.id = c.id + 3600000
          AND a.guid NOT BETWEEN 15500000 AND 15599999
          AND ABS(a.position_x - c.position_x) < 10
          AND ABS(a.position_y - c.position_y) < 10);

-- MovementType 1 (random) needs a non-zero wander_distance or the core logs
-- "MovementType=1 but with wander_distance=0, replace by idle movement".
UPDATE `creature` SET `MovementType` = 0
WHERE `guid` BETWEEN 15500000 AND 15599999
  AND `MovementType` = 1 AND `wander_distance` = 0;

-- ---------------------------------------------------------------------------
-- Gameobjects, by contrast, are essentially complete
-- ---------------------------------------------------------------------------
-- Map 750 carries 1,854 GO spawns and only 5 of the 340 templates in the
-- 3,800,000 block are unspawned.  The same footprint comparison finds exactly
-- ONE gameobject that belongs in the zone and is absent: 3808900 "Portal to the
-- Firelands" (type 22), the Sulfuron Spire portal.
DELETE FROM `gameobject` WHERE `guid` = 15340200;

INSERT INTO `gameobject`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,
   `position_x`,`position_y`,`position_z`,`orientation`,
   `rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`)
SELECT 15340200, g.id + 3600000, 750, 0, 0, 1, 1,
       g.position_x, g.position_y, g.position_z, g.orientation,
       g.rotation0, g.rotation1, g.rotation2, g.rotation3,
       GREATEST(g.spawntimesecs, 30), g.animprogress, g.state
FROM cata_world.gameobject g
WHERE g.id = 208900 AND g.map = 1
  AND g.position_x BETWEEN 3399 AND 5771 AND g.position_y BETWEEN -4980 AND -1279
LIMIT 1;
