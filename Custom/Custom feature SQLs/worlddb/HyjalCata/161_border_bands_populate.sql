-- ---------------------------------------------------------------------------
-- 161  Hyjal round-27 -- populate the remaining border bands
--      *** SCOPE WAS WRONG -- SUPERSEDED BY 164_. The footprint below was
--      *** derived from existing map-750 spawns, which cannot reveal regions
--      *** that have none. It found 92 spawns; the real gap is 2,694. This
--      *** file is still correct as far as it goes and is safe to keep.
-- ---------------------------------------------------------------------------
-- 157_ populated the SE snow corner (Winterspring, 46 spawns).  This finishes
-- the job for the other edges of the map-750 footprint, which are equally
-- empty: the rectangle DC carved out of Kalimdor is wider than Hyjal and also
-- clips Felwood, Moonglade and Azshara.
--
--     band                     stock spawns in footprint
--     NW Felwood/Moonglade     77   Felpaw Wolf, Angerclaw Bear, Withered and
--                                   Crazed Ancient, Timbermaw NPCs
--     SW Felwood/Azshara       83   Timbermaw, Spitelash, Archmage Xylem
--     SE Winterspring          46   already done by 157_
--     remainder                200  Frostmaul Giant, Hederine line, Lorax,
--                                   Antilos, Winterspring Screecher
--
-- THE GUARD THAT MAKES THIS SAFE
--   Those bands are approximations -- a rectangle is not a zone boundary, and
--   the "remainder" figure in particular is NOT all border: it includes stock
--   spawns whose coordinates fall inside populated Hyjal.  Importing by band
--   would drop vanilla Winterspring mobs into the middle of the Hyjal quest
--   zone.
--
--   So this file does not use bands at all.  It imports a stock map-1 spawn
--   ONLY where map 750 has no spawn of any kind within 100 yards -- i.e. only
--   into genuinely empty ground.  That reduces 406 candidates to **92 spawns /
--   28 entries** and makes the result independent of where I drew the band
--   lines.  Gameobjects get the same treatment: **165 GOs / 83 entries**.
--
-- ENTRY IDS STAY RAW.  These are stock creatures and objects that already exist
-- in this DB -- no +3,600,000 clone is wanted, and cloning them would orphan
-- their loot, quests and script bindings.
--
-- LEVEL BAND: these are vanilla ~55-60 content in a zone advertised as 80-130.
-- That is a deliberate consequence of populating the border rather than walling
-- it off; 101_zone_level_bands.sql is where a rescale would go if wanted.  The
-- border is scenery you can walk into, not a quest area, so it is left at
-- source level here.
--
-- GUIDs: creatures 15,700,000+; gameobjects 15,700,000+ (separate tables, so
-- the ranges may overlap).  157_'s 15,6xx,xxx block is untouched and excluded
-- from the source so a re-run does not re-import it.
--
-- Idempotent.
-- ---------------------------------------------------------------------------

DELETE FROM `creature` WHERE `guid` BETWEEN 15700000 AND 15799999;

INSERT INTO `creature`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
   `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,
   `wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,
   `npcflag`,`unit_flags`,`dynamicflags`,`VerifiedBuild`)
SELECT 15700000 + ROW_NUMBER() OVER (ORDER BY c.`guid`),
       c.`id`, 750, 0, 0, 1, 1, c.`equipment_id`,
       c.`position_x`, c.`position_y`, c.`position_z`, c.`orientation`,
       GREATEST(c.`spawntimesecs`, 30),
       c.`wander_distance`, 0, c.`curhealth`, c.`curmana`, c.`MovementType`,
       0, 0, 0, 0
FROM `creature` c
WHERE c.`map` = 1
  AND c.`position_x` BETWEEN 3399 AND 5771
  AND c.`position_y` BETWEEN -4980 AND -1279
  AND c.`guid` NOT BETWEEN 15600000 AND 15799999
  AND NOT EXISTS (SELECT 1 FROM `creature` d WHERE d.`map` = 750
                    AND ABS(d.`position_x` - c.`position_x`) < 100
                    AND ABS(d.`position_y` - c.`position_y`) < 100);

-- Same MovementType hygiene as 155_/159_: random movement with no wander
-- distance, and waypoint movement with no path, both fall back to idle rather
-- than logging on every respawn.  Stock spawns bring their own creature_addon
-- paths keyed by the ORIGINAL guid, which the new guids do not inherit -- so
-- any waypoint mover imported here has no path by construction.
UPDATE `creature` SET `MovementType` = 0, `wander_distance` = 0
WHERE `guid` BETWEEN 15700000 AND 15799999
  AND (( `MovementType` = 1 AND `wander_distance` = 0 )
    OR ( `MovementType` IN (2,3) ));

-- --- gameobjects -----------------------------------------------------------
DELETE FROM `gameobject` WHERE `guid` BETWEEN 15700000 AND 15799999;

INSERT INTO `gameobject`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,
   `position_x`,`position_y`,`position_z`,`orientation`,
   `rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`)
SELECT 15700000 + ROW_NUMBER() OVER (ORDER BY g.`guid`),
       g.`id`, 750, 0, 0, 1, 1,
       g.`position_x`, g.`position_y`, g.`position_z`, g.`orientation`,
       g.`rotation0`, g.`rotation1`, g.`rotation2`, g.`rotation3`,
       GREATEST(g.`spawntimesecs`, 30), g.`animprogress`, g.`state`
FROM `gameobject` g
WHERE g.`map` = 1
  AND g.`position_x` BETWEEN 3399 AND 5771
  AND g.`position_y` BETWEEN -4980 AND -1279
  AND g.`guid` NOT BETWEEN 15700000 AND 15799999
  AND NOT EXISTS (SELECT 1 FROM `gameobject` d WHERE d.`map` = 750
                    AND ABS(d.`position_x` - g.`position_x`) < 100
                    AND ABS(d.`position_y` - g.`position_y`) < 100);

-- Keep 156_/160_'s combat-immunity sweep correct for anything this import
-- brought in (same ordering hazard that let Ranshalla slip through).
UPDATE `creature_template` ct
SET ct.`unit_flags` = ct.`unit_flags` | 512
WHERE (ct.`npcflag` & 130) <> 0
  AND (ct.`unit_flags` & 512) = 0
  AND EXISTS (SELECT 1 FROM `creature` c WHERE c.`id` = ct.`entry` AND c.`map` IN (750, 861));
