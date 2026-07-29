-- ---------------------------------------------------------------------------
-- 164  Hyjal round-30 -- populate the map for real (161_ used the wrong box)
-- ---------------------------------------------------------------------------
-- CORRECTION TO 161_.  That file derived map 750's footprint from where DC
-- spawns already were (x 3399..5771, y -4980..-1279).  That is circular: a
-- region with ZERO spawns can never appear inside the convex hull of existing
-- spawns, so the audit was structurally incapable of finding the empty parts of
-- the map.  161_ imported 92 creatures and reported the job done.
--
-- The real extent comes from the ADTs, not the spawns.  DCMountHyjal ships 81
-- tiles, columns 33-41 and rows 17-25, and tile (col, row) covers
-- x = (32-row)*533.33 down to (31-row)*533.33, y = (32-col)*533.33 down to
-- (31-col)*533.33.  That gives:
--
--     TRUE terrain extent   x 3200 .. 8000     y -5334 .. -533
--     what 161_ searched    x 3399 .. 5771     y -4980 .. -1279
--
-- Everything east of x 5771 -- roughly the eastern third of the map, 2,230
-- yards of terrain -- was never looked at.  Standing in Everlook at
-- (6715, -4666) there are no spawns at all, while stock map 1 has 181 in that
-- one town.
--
-- Across the true extent, stock Kalimdor has 3,188 spawns; 2,782 of them sit
-- outside the old box, and 2,699 are in ground where map 750 has nothing within
-- 100 yards.  So 161_ found 3% of the real gap.
--
-- WHAT THIS TERRAIN ACTUALLY IS
--   The rectangle swallows large parts of three vanilla zones, which is why the
--   NPC list reads the way it does:
--     Winterspring / Everlook  -- Innkeeper Vizzie, Auctioneer Grizzlin, Qia,
--                                 Legacki, Everlook Bruiser, Winterfall
--                                 furbolgs, Ice Thistle yeti
--     Moonglade                -- Keeper Remulos, Rabine Saturna, Dreamwarden
--                                 Lurosa, Maybess Riverbreeze
--     Felwood                  -- Niby the Almighty, Impsy, Witch Doctor
--                                 Mau'ari, Salfa
--
-- ---------------------------------------------------------------------------
-- WHAT IS IMPORTED, AND THE ONE THING THAT IS NOT
-- ---------------------------------------------------------------------------
-- 2,694 creatures and 1,680 gameobjects: everything in the true extent that
-- map 750 has no spawn within 100 yards of, EXCEPT flight masters.
--
-- FLIGHT MASTERS ARE EXCLUDED (5 of them: Faustron, Maethrya, Mishellena,
-- Sindrayl, Yugrek).  Taxi nodes carry their own map id, so a flight master
-- standing on map 750 next to a node defined for map 1 cannot offer it -- the
-- NPC would be decorative and the flight point dead.  Giving this map real
-- taxi coverage means adding TaxiNodes rows for map 750, which the project has
-- already done once for Hyjal proper (nodes 421-437); extending that to the
-- Winterspring/Moonglade side is separate work, not a spawn import.
--
-- THE OTHER SERVICE NPCs ARE INCLUDED and that is a deliberate, reversible
-- choice worth knowing about: 65 questgivers, 14 vendors, 6 trainers, 5
-- bankers, 1 auctioneer (Innkeeper Vizzie) and 1 stable master.  This gives
-- map 750 a fully working second Everlook and second Moonglade, which is what
-- makes the towns feel alive rather than being empty buildings -- but it also
-- means those quests can be picked up in two places and Keeper Remulos exists
-- twice on the server.  To keep the world purely ambient instead, change the
-- npcflag filter below from `& 8192` to `& 216690` -- that drops every service
-- NPC and questgiver and imports 2,602 pure ambient/hostile spawns.
--
-- ENTRY IDS STAY RAW -- these are stock creatures that already exist; cloning
-- them would orphan their loot, quests and script bindings.
--
-- GUIDs: 15,800,000+ for both tables (161_'s 15.7M block and 157_'s 15.6M block
-- are excluded from the source, so this is additive and a re-run finds nothing
-- new).
--
-- LEVEL: vanilla ~50-60 content in a zone advertised 80-130, same tradeoff
-- 157_/161_ documented.  101_zone_level_bands.sql is where a rescale would go.
--
-- Idempotent.
-- ---------------------------------------------------------------------------

DELETE FROM `creature` WHERE `guid` BETWEEN 15800000 AND 15899999;

INSERT INTO `creature`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
   `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,
   `wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,
   `npcflag`,`unit_flags`,`dynamicflags`,`VerifiedBuild`)
SELECT 15800000 + ROW_NUMBER() OVER (ORDER BY c.`guid`),
       c.`id`, 750, 0, 0, 1, 1, GREATEST(c.`equipment_id`, 0),
       c.`position_x`, c.`position_y`, c.`position_z`, c.`orientation`,
       GREATEST(c.`spawntimesecs`, 30),
       c.`wander_distance`, 0, c.`curhealth`, c.`curmana`, c.`MovementType`,
       0, 0, 0, 0
FROM `creature` c
JOIN `creature_template` ct ON ct.`entry` = c.`id`
WHERE c.`map` = 1
  AND c.`position_x` BETWEEN 3200 AND 8000
  AND c.`position_y` BETWEEN -5334 AND -533
  AND c.`guid` NOT BETWEEN 15600000 AND 15899999
  AND (ct.`npcflag` & 8192) = 0                      -- no flight masters, see above
  AND NOT EXISTS (SELECT 1 FROM `creature` d WHERE d.`map` = 750
                    AND ABS(d.`position_x` - c.`position_x`) < 100
                    AND ABS(d.`position_y` - c.`position_y`) < 100);

-- Same movement hygiene as 155_/159_/161_: a random mover with no wander
-- distance, and any waypoint mover (whose creature_addon path is keyed to the
-- ORIGINAL guid and so is not inherited), both fall back to idle rather than
-- logging on every respawn.  wander_distance is cleared in the same statement
-- so the row cannot end up contradictory -- the mistake 162_ had to repair.
UPDATE `creature` SET `MovementType` = 0, `wander_distance` = 0
WHERE `guid` BETWEEN 15800000 AND 15899999
  AND (( `MovementType` = 1 AND `wander_distance` = 0 )
    OR ( `MovementType` IN (2,3) ));

-- --- gameobjects -----------------------------------------------------------
DELETE FROM `gameobject` WHERE `guid` BETWEEN 15800000 AND 15899999;

INSERT INTO `gameobject`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,
   `position_x`,`position_y`,`position_z`,`orientation`,
   `rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`)
SELECT 15800000 + ROW_NUMBER() OVER (ORDER BY g.`guid`),
       g.`id`, 750, 0, 0, 1, 1,
       g.`position_x`, g.`position_y`, g.`position_z`, g.`orientation`,
       g.`rotation0`, g.`rotation1`, g.`rotation2`, g.`rotation3`,
       GREATEST(g.`spawntimesecs`, 30), g.`animprogress`, g.`state`
FROM `gameobject` g
WHERE g.`map` = 1
  AND g.`position_x` BETWEEN 3200 AND 8000
  AND g.`position_y` BETWEEN -5334 AND -533
  AND g.`guid` NOT BETWEEN 15700000 AND 15899999
  AND NOT EXISTS (SELECT 1 FROM `gameobject` d WHERE d.`map` = 750
                    AND ABS(d.`position_x` - g.`position_x`) < 100
                    AND ABS(d.`position_y` - g.`position_y`) < 100);

-- Keep the combat-immunity sweep correct for everything this brought in --
-- the same ordering hazard that let Ranshalla slip past 156_.
UPDATE `creature_template` ct
SET ct.`unit_flags` = ct.`unit_flags` | 512
WHERE (ct.`npcflag` & 130) <> 0
  AND (ct.`unit_flags` & 512) = 0
  AND EXISTS (SELECT 1 FROM `creature` c WHERE c.`id` = ct.`entry` AND c.`map` IN (750, 861));

-- ---------------------------------------------------------------------------
-- METHOD NOTE, because this class of mistake is easy to repeat
-- ---------------------------------------------------------------------------
-- Never derive a map's search footprint from its own spawn data.  The extent
-- must come from something independent of what you are auditing -- here the ADT
-- tile grid, which is authoritative about where terrain exists.  The same
-- applies to the earlier "694 missing doodads" figure, which was an artifact of
-- comparing rounded rotations, and to the Nordrassil "empty zone" report, which
-- was really WorldMapArea projecting the player 26% too far south.  In all
-- three cases the measurement, not the data, was wrong.
-- ---------------------------------------------------------------------------
