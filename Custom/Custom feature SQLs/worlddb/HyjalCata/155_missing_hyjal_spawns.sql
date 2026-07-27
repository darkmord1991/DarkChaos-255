-- ---------------------------------------------------------------------------
-- 155  Hyjal round-25 -- 277 spawns the downport never brought across
-- ---------------------------------------------------------------------------
-- Audit: for every template in the 3,600,000 clone block, compare DC's spawn
-- count on map 750 against what `nelt_world` spawns inside the same coordinate
-- footprint.  1,100 templates exist; 785 are spawned, 93 have FEWER spawns than
-- the source, and 224 have NONE at all.
--
-- Most of those 224 are false positives -- their nelt spawns live on maps 0/1
-- outside Hyjal (generic world NPCs whose Cata originals the clone block
-- happened to pull in).  Filtering nelt to map 1 AND the actual Hyjal footprint
-- (x 3399..5771, y -4980..-1279, taken from DC's own map-750 spawn extents)
-- leaves **61 entries / 277 spawns that genuinely belong in the zone and are
-- simply not there**:
--
--   Ambience the zone is missing entirely
--     3652595 Alpine Songbird (62), 3652596 Forest Owl (22),
--     3639941 Grove Warden (17), 3607446 Rabid Shardtooth (17)
--
--   Quest content
--     3652300 Seething Pyrelord (20), 3640557 Child of Tortolla (12),
--     3639765 The Eye of Twilight (8), 3640288 Rescued Bear Cub (3),
--     3650083 Druid of the Talon, 3654319 Magria, 3650079 Borun Thundersky
--
--   The Nordrassil ritual cast (all at ~5335,-3490 -- the Thrall scene)
--     3654177 Farseer Nobundo, 3654178 Muln Earthfury,
--     3654179 Tyrande Whisperwind, 3654180 Lady Jaina Proudmoore,
--     3654312 Aggra, 3655227 Elder Evershade
--
--   Archaeology digsites (4)
--     3660461 Ruins of Lar'donir, 3660463 Shrine of Goldrinn,
--     3660465 Grove of Aessina, 3660467 Sanctuary of Malorne, 3660469 Scorched Plain
--
--   Event trigger bunnies (75005-75036) that scripts and SmartAI look for by
--   proximity, plus 3649456 Finkle's Mole Machine and 3613148 Flame of Ragnaros.
--
-- DELIBERATELY EXCLUDED -- five entries the C++ owns and summons itself, which
-- would double-populate if also world-spawned (verified by grepping the DC
-- script tree for each entry id):
--     3675014 Nemesis Crystal target      -> zone_mount_hyjal.cpp
--     3652177 Child of Tortolla           -> npc_punt_child_of_tortolla
--     3639431 Twilight Slave              -> npc_twilight_slave
--     3639436 Twilight Proveditor         -> npc_twilight_proveditor
--     3639438 Twilight Slavedriver        -> npc_twilight_slavedriver
--   (note 3640557 "Child of Tortolla" is a DIFFERENT entry and is imported.)
--
-- COORDINATES ARE COPIED UNCHANGED.  DC's map 750 reuses Cata's Kalimdor
-- coordinate frame for this region -- which is why the footprint filter above
-- works at all -- so no transform is needed or wanted.
--
-- GUIDs start at 15,500,000, above the current max creature guid (15,400,005)
-- and clear of the documented custom allocations.  ROW_NUMBER() keeps them
-- contiguous and deterministic, so a re-run after a partial apply produces the
-- same ids.
--
-- Idempotent: the DELETE clears the block first, and the INSERT re-derives it.
-- ---------------------------------------------------------------------------

DELETE FROM `creature` WHERE `guid` BETWEEN 15500000 AND 15599999;

INSERT INTO `creature`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
   `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,
   `wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,
   `npcflag`,`unit_flags`,`dynamicflags`,`VerifiedBuild`)
SELECT 15500000 + ROW_NUMBER() OVER (ORDER BY n.id, n.guid),
       n.id + 3600000, 750, 0, 0, 1, 1, 0,
       n.position_x, n.position_y, n.position_z, n.orientation,
       GREATEST(n.spawntimesecs, 30),
       n.spawndist, 0, n.curhealth, n.curmana, n.MovementType,
       0, 0, 0, 0
FROM nelt_world.creature n
JOIN acore_world.creature_template ct ON ct.entry = n.id + 3600000
WHERE n.map = 1
  AND n.position_x BETWEEN 3399 AND 5771
  AND n.position_y BETWEEN -4980 AND -1279
  AND NOT EXISTS (SELECT 1 FROM acore_world.creature c
                  WHERE c.id = ct.entry AND c.guid NOT BETWEEN 15500000 AND 15599999)
  AND n.id NOT IN (75014, 52177, 39431, 39436, 39438);

-- npcflag / unit_flags / dynamicflags are taken from creature_template rather
-- than copied per-spawn: nelt's per-spawn overrides are for a 4.3.4 flag layout
-- and carrying them across is exactly how earlier rounds produced "has
-- UNIT_NPC_FLAG_SPELLCLICK but no data in spellclick table" and the vendor-flag
-- mismatches 152_ had to clean up.  Zero means "inherit the template".

-- MovementType 1 (random) requires a non-zero wander_distance or the core logs
-- "MovementType=1 but with wander_distance=0, replace by idle movement".
UPDATE `creature` SET `MovementType` = 0
WHERE `guid` BETWEEN 15500000 AND 15599999
  AND `MovementType` = 1 AND `wander_distance` = 0;

-- ---------------------------------------------------------------------------
-- 156-adjacent: the single missing gameobject
-- ---------------------------------------------------------------------------
-- GAMEOBJECTS ARE, BY CONTRAST, ESSENTIALLY COMPLETE: map 750 carries 1,854 GO
-- spawns, only 5 of the 340 templates in the 3,800,000 block are unspawned, and
-- the same footprint comparison against nelt finds exactly ONE gameobject that
-- belongs in the zone and is absent -- 3808900 "Portal to the Firelands"
-- (type 22, spell caster).  That is the Sulfuron Spire portal.
DELETE FROM `gameobject` WHERE `guid` = 15340200;

INSERT INTO `gameobject`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,
   `position_x`,`position_y`,`position_z`,`orientation`,
   `rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`)
SELECT 15340200, n.id + 3600000, 750, 0, 0, 1, 1,
       n.position_x, n.position_y, n.position_z, n.orientation,
       n.rotation0, n.rotation1, n.rotation2, n.rotation3,
       GREATEST(n.spawntimesecs, 30), n.animprogress, n.state
FROM nelt_world.gameobject n
WHERE n.id = 208900 AND n.map = 1
  AND n.position_x BETWEEN 3399 AND 5771 AND n.position_y BETWEEN -4980 AND -1279
LIMIT 1;
