-- ---------------------------------------------------------------------------
-- 257  Map 750 -- the patrol routes position-matching could never recover
-- ---------------------------------------------------------------------------
-- 202_ and 230_ both matched spawns to their source on (entry - offset) AND
-- rounded x/y. That works wherever the import copied source coordinates. It
-- cannot work in Felwood, because Felwood on 750 was populated from the
-- PRE-Cata creature set: the entries are Cata but the spawn POSITIONS are the
-- older layout, so the Cata patrol layer had nothing to bind to. The symptom is
-- stark -- every 3707xxx entry on 750 has ZERO MovementType-2 spawns, while
-- cata_world has 65 patrol spawns across 30 of those entries. Same cause, much
-- smaller, in Moonglade and in the pockets of Hyjal the expansion re-placed.
--
-- Nothing here is a duplicate of 202_/230_. It closes the gap they structurally
-- could not see.
--
-- MATCHING. Per (source patrol spawn, our spawn) pair, distance is measured
-- from our spawn to the NEAREST POINT OF THE ROUTE, not to the source spawn.
-- That is the question that actually matters -- "does this creature stand on
-- this patrol route" -- and it is far more robust: a long circuit legitimately
-- has its spawn point hundreds of yards from the source's, while still passing
-- within a few yards of ours. Moonglade Warden 290132 is the clean example:
-- 170 yd from the source spawn, 5.3 yd from its own 501-point route.
--
-- Then MUTUAL-NEAREST one-to-one: a pair survives only if our spawn is the
-- closest candidate for that route AND that route is the closest candidate for
-- our spawn, with a 25 yd cutoff. Anything contested drops out rather than
-- being resolved by tie-break. This is what kills the noise the raw proximity
-- join produces -- 19 Talonbranch Wisp routes, 200-500 yd out, all collapsing
-- onto the single guid 15830268, which read as a fleet of missing patrols and
-- was nothing of the kind.
--
-- 33 pairs survived that. 15 WERE THEN CUT, and this is the trap in the file:
-- checking whether a source route is already imported by looking for its SOURCE
-- ID in our waypoint_data reports "absent" even when the route is fully present
-- -- because 202_/230_ re-key every path to the spawn guid on import. Source
-- 3874200 is local id 9843503; searching for 3874200 finds nothing. Comparing
-- CONTENT instead (point count + first-point coordinates) found 15 of the 33
-- already walked by another spawn, including 6 that 230_ itself imported. Left
-- in, they would have put two creatures in lockstep on one route and claimed a
-- source patrol twice. 18 pairs remain, and every one is genuinely new.
--
-- Path id = the spawn guid, the 202_/230_ convention. Verified: all 18 ids are
-- absent from waypoint_data, and none of the 18 spawns has a creature_addon row
-- at all, so the addon writes are pure INSERTs with nothing to clobber.
--
-- SCHEMA: all 18 come from cata_world, whose waypoint_data is column-identical
-- to ours, so they copy with INSERT ... SELECT. (nelt's is not -- see 230_ --
-- but no nelt path is needed here.)
-- ---------------------------------------------------------------------------

-- --- 18 routes: dst = our spawn guid, src = cata waypointPathId -------------
-- Felwood / Talonbranch (zone 361), 14:
--   15800428  Malygen                4 pts  21.7 yd    15801102  Jaedenar Warlock      12  23.9
--   15800612  Timbermaw Mystic      10 pts   0.2 yd    15801120  Deadwood Pathfinder   30  20.5
--   15800895  Jaedenar Cultist      35 pts  22.0 yd    15801143  Deadwood Pathfinder    6  14.1
--   15801008  Deadwood Den Watcher  19 pts   0.0 yd    15801168  Jadefire Felsworn     30   0.0
--   15801013  Deadwood Den Watcher  22 pts   5.1 yd    15801188  Jadefire Satyr        27   0.0
--   15801065  Jaedenar Darkweaver    2 pts  10.9 yd    15801192  Deadwood Pathfinder   28  12.6
--   15801081  Jaedenar Darkweaver    4 pts   7.5 yd    15801194  Deadwood Warrior       2  15.9
-- Moonglade (zone 493), 2:
--   15802075  Moonglade Warden      60 pts  15.1 yd    15802121  Moonglade Warden     112   0.0
-- Mount Hyjal (zone 616), 2:
--   12196760  Grove Tender           4 pts   7.9 yd    12252319  Goldrinn Defender      8   2.5
DELETE FROM `waypoint_data` WHERE `id` IN (
  12196760, 12252319, 15800428, 15800612, 15800895, 15801008, 15801013,
  15801065, 15801081, 15801102, 15801120, 15801143, 15801168, 15801188,
  15801192, 15801194, 15802075, 15802121);
INSERT INTO `waypoint_data`
 (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `velocity`,
  `delay`, `smoothTransition`, `move_type`, `action`, `action_chance`, `wpguid`)
SELECT m.dst, w.`point`, w.`position_x`, w.`position_y`, w.`position_z`, w.`orientation`,
       w.`velocity`, w.`delay`, w.`smoothTransition`, w.`move_type`, w.`action`,
       w.`action_chance`, 0
FROM cata_world.`waypoint_data` w
JOIN (SELECT 15800428 dst, 3599550 src
  UNION ALL SELECT 15800612, 3608610 UNION ALL SELECT 15800895, 3601520
  UNION ALL SELECT 15801008, 3602870 UNION ALL SELECT 15801013, 3602910
  UNION ALL SELECT 15801065, 3601850 UNION ALL SELECT 15801081, 3601870
  UNION ALL SELECT 15801102, 3601930 UNION ALL SELECT 15801120, 3602690
  UNION ALL SELECT 15801143, 3602710 UNION ALL SELECT 15801168, 3601250
  UNION ALL SELECT 15801188, 3600840 UNION ALL SELECT 15801192, 3602730
  UNION ALL SELECT 15801194, 3602520 UNION ALL SELECT 15802075, 2899790
  UNION ALL SELECT 15802121, 2901730 UNION ALL SELECT 12196760, 3861100
  UNION ALL SELECT 12252319, 3852460) m ON m.src = w.`id`;

-- --- link the spawns to their paths ----------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (
  12196760, 12252319, 15800428, 15800612, 15800895, 15801008, 15801013,
  15801065, 15801081, 15801102, 15801120, 15801143, 15801168, 15801188,
  15801192, 15801194, 15802075, 15802121);
INSERT INTO `creature_addon`
 (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT DISTINCT w.`id`, w.`id`, 0, 0, 1, 0, 0, ''
FROM `waypoint_data` w
WHERE w.`id` IN (
  12196760, 12252319, 15800428, 15800612, 15800895, 15801008, 15801013,
  15801065, 15801081, 15801102, 15801120, 15801143, 15801168, 15801188,
  15801192, 15801194, 15802075, 15802121);

-- --- and make them actually walk it ----------------------------------------
-- 12 are currently MovementType 0, 6 are currently 1 (15800895, 15801013,
-- 15801065, 15801081, 15801102, 15801168). All 18 sources say 2, so all 18 go
-- to 2 -- the rule from 202_ holds, this is not forcing behaviour the source
-- lacks. wander_distance is deliberately left as-is on the 6: it is unread at
-- MovementType 2 and preserves the original value if one is ever reverted.
UPDATE `creature` SET `MovementType` = 2 WHERE `guid` IN (
  12196760, 12252319, 15800428, 15800612, 15800895, 15801008, 15801013,
  15801065, 15801081, 15801102, 15801120, 15801143, 15801168, 15801188,
  15801192, 15801194, 15802075, 15802121);

-- STILL OPEN after this file, recorded so the next pass does not re-derive it:
--   * Felwood keeps a residual shortfall. cata has 65 patrol spawns over 30
--     entries in zone 361; between 230_ and this file we bind the ones that
--     resolve within 25 yd. The rest have no spawn near the route at all --
--     the pre-Cata layout simply has no creature there. Those need spawns
--     placed, not paths imported, and that is a content decision.
--   * Blazewing and Ban'thalos (cata MovementType 3, cyclic spline) still have
--     no flight path -- see the note in 256_.
--   * Talonbranch Wisps: 19 source routes, no spawn within 25 yd of any of
--     them. Same class as the Felwood residual, not a matching failure.

-- Verify -- expect 18 / 18 / 18 / 0 / 0:
--   SELECT COUNT(DISTINCT id) FROM `waypoint_data` WHERE id IN (12196760, ..., 15802121);
--   SELECT COUNT(*) FROM `creature_addon` WHERE guid IN (12196760, ..., 15802121) AND path_id <> 0;
--   SELECT COUNT(*) FROM `creature` WHERE guid IN (12196760, ..., 15802121) AND MovementType = 2;
--   -- no patroller anywhere on 750/751 without a resolvable path:
--   SELECT COUNT(*) FROM `creature` c WHERE c.map IN (750,751) AND c.MovementType = 2
--     AND NOT EXISTS (SELECT 1 FROM `creature_addon` a JOIN `waypoint_data` w
--       ON w.id = a.path_id WHERE a.guid = c.guid AND a.path_id <> 0);        -- 0
--   -- and no two spawns sharing one route:
--   SELECT COUNT(*) FROM (SELECT a.path_id FROM `creature_addon` a
--     JOIN `creature` c ON c.guid = a.guid WHERE c.map = 750 AND a.path_id <> 0
--     GROUP BY a.path_id HAVING COUNT(*) > 1) d;                              -- 0
