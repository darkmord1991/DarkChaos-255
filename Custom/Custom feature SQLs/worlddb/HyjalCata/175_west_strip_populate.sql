-- ---------------------------------------------------------------------------
-- 175  Hyjal round-42 -- populate the new western strip (terrain cols 30-32)
-- ---------------------------------------------------------------------------
-- Map 750's terrain grew from 81 tiles (cols 33-41) to 108 (cols 30-41): three
-- new columns baked from the SAME retail source as the rest of the map, which
-- takes Felwood from 86% to 100% of its real footprint and adds the eastern
-- half of Darkshore plus a slice of northern Ashenvale.
--
--     new terrain box:  x 3200 .. 8000,  y -533 .. 1067
--
-- This imports the stock map-1 spawns that fall inside it, mirroring 164_'s
-- pattern (which populated the ORIGINAL box) so the two strips behave alike.
--
-- ---------------------------------------------------------------------------
-- WHAT THIS FILE DOES DIFFERENTLY FROM 164_
-- ---------------------------------------------------------------------------
-- 164_ imported every stock spawn in its box and, because world-event content
-- lives in the same `creature`/`gameobject` tables, dragged in Scourge Invasion
-- and holiday spawns WITHOUT their `game_event_*` gating -- a necropolis ended
-- up permanently built over Winterspring and 171_ had to delete 660 GO + 348
-- creature rows to undo it.  That exclusion is applied HERE at import time
-- instead of being cleaned up afterwards.
--
-- An entry counts as event-only when EVERY stock spawn of it is gated.  An
-- entry with even one ungated spawn is ordinary world content that merely also
-- appears in an event, and is imported normally.
--
-- ---------------------------------------------------------------------------
-- KNOWN MISMATCH, ACCEPTED DELIBERATELY
-- ---------------------------------------------------------------------------
-- The terrain is POST-Cataclysm Darkshore (sundered coast, Auberdine gone,
-- Lor'danel in its place); these spawns are the WotLK-era layout this DB holds.
-- Where Cataclysm reshaped the coast some NPCs will stand in water, inside new
-- geometry, or on ground that no longer exists.  Felwood and Ashenvale changed
-- far less and should land cleanly.  This is imported wholesale by choice --
-- strays get cleaned up from the live log afterwards rather than guessed at
-- now.  The 100-yard emptiness guard below only protects EXISTING map-750
-- spawns; it cannot know where the retail terrain moved.
--
-- GUID BLOCKS
--   creature    15,830,001+   (164_ used 15,800,001-15,802,694; 170_ 15,810,00x;
--                              current block max was 15,820,020)
--   gameobject  15,850,001+   (164_ used 15,800,001-15,801,680)
--   Both sit inside 15,600,000-15,899,999, so 166_ picks them up on its next
--   run and gives them private +3,700,000 / +3,900,000 clones like the rest of
--   the border content.  MUST therefore be applied BEFORE re-running 166_.
--
-- Idempotent: fixed guid ranges, deleted before insert.
-- ---------------------------------------------------------------------------

-- Event-only entry sets, materialised: the identifying query groups over the
-- same tables the INSERTs read, and inlining it made the statement crawl.
DROP TABLE IF EXISTS `_dc_ev_cre`;
CREATE TABLE `_dc_ev_cre` (`id` INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO `_dc_ev_cre` (`id`)
SELECT s.`id` FROM `creature` s
LEFT JOIN `game_event_creature` e ON e.`guid` = s.`guid`
GROUP BY s.`id` HAVING SUM(e.`guid` IS NOT NULL) = COUNT(*);

DROP TABLE IF EXISTS `_dc_ev_go`;
CREATE TABLE `_dc_ev_go` (`id` INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO `_dc_ev_go` (`id`)
SELECT s.`id` FROM `gameobject` s
LEFT JOIN `game_event_gameobject` e ON e.`guid` = s.`guid`
GROUP BY s.`id` HAVING SUM(e.`guid` IS NOT NULL) = COUNT(*);

-- --- creatures ---------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 15830001 AND 15839999;

INSERT INTO `creature`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
   `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,
   `wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,
   `npcflag`,`unit_flags`,`dynamicflags`,`VerifiedBuild`)
SELECT 15830000 + ROW_NUMBER() OVER (ORDER BY c.`guid`),
       c.`id`, 750, 0, 0, 1, 1, GREATEST(c.`equipment_id`, 0),
       c.`position_x`, c.`position_y`, c.`position_z`, c.`orientation`,
       GREATEST(c.`spawntimesecs`, 30),
       c.`wander_distance`, 0, c.`curhealth`, c.`curmana`, c.`MovementType`,
       0, 0, 0, 0
FROM `creature` c
JOIN `creature_template` ct ON ct.`entry` = c.`id`
WHERE c.`map` = 1
  AND c.`position_x` BETWEEN 3200 AND 8000
  AND c.`position_y` BETWEEN -533 AND 1067
  AND c.`guid` NOT BETWEEN 15600000 AND 15899999
  AND (ct.`npcflag` & 8192) = 0                      -- no flight masters: no taxi nodes out here
  AND c.`id` NOT IN (SELECT `id` FROM `_dc_ev_cre`)  -- no world-event-only content
  AND NOT EXISTS (SELECT 1 FROM `creature` d WHERE d.`map` = 750
                    AND ABS(d.`position_x` - c.`position_x`) < 100
                    AND ABS(d.`position_y` - c.`position_y`) < 100);

-- Movement hygiene, same as 155_/159_/161_/164_: a random mover with no wander
-- distance, and any waypoint mover (whose creature_addon path is keyed to the
-- ORIGINAL guid and so is NOT inherited), both fall back to idle rather than
-- logging "doesn't have waypoint path id" on every respawn.  wander_distance is
-- cleared in the same statement so the row cannot end up contradictory -- the
-- exact inconsistency 162_ had to repair.
UPDATE `creature` SET `MovementType` = 0, `wander_distance` = 0
WHERE `guid` BETWEEN 15830001 AND 15839999
  AND (( `MovementType` = 1 AND `wander_distance` = 0 )
    OR ( `MovementType` IN (2,3) ));

-- --- gameobjects -------------------------------------------------------------
DELETE FROM `gameobject` WHERE `guid` BETWEEN 15850001 AND 15859999;

INSERT INTO `gameobject`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,
   `position_x`,`position_y`,`position_z`,`orientation`,
   `rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`)
SELECT 15850000 + ROW_NUMBER() OVER (ORDER BY g.`guid`),
       g.`id`, 750, 0, 0, 1, 1,
       g.`position_x`, g.`position_y`, g.`position_z`, g.`orientation`,
       g.`rotation0`, g.`rotation1`, g.`rotation2`, g.`rotation3`,
       GREATEST(g.`spawntimesecs`, 30), g.`animprogress`, g.`state`
FROM `gameobject` g
JOIN `gameobject_template` gt ON gt.`entry` = g.`id`
WHERE g.`map` = 1
  AND g.`position_x` BETWEEN 3200 AND 8000
  AND g.`position_y` BETWEEN -533 AND 1067
  AND g.`guid` NOT BETWEEN 15600000 AND 15899999
  AND g.`id` NOT IN (SELECT `id` FROM `_dc_ev_go`)   -- no world-event-only content
  AND NOT EXISTS (SELECT 1 FROM `gameobject` d WHERE d.`map` = 750
                    AND ABS(d.`position_x` - g.`position_x`) < 100
                    AND ABS(d.`position_y` - g.`position_y`) < 100);

DROP TABLE IF EXISTS `_dc_ev_cre`;
DROP TABLE IF EXISTS `_dc_ev_go`;

-- Verify -- expect roughly 1,770 creatures and 880 gameobjects (the exact count
-- depends on how many the event and proximity filters drop):
--   SELECT COUNT(*) FROM `creature`   WHERE `guid` BETWEEN 15830001 AND 15839999;
--   SELECT COUNT(*) FROM `gameobject` WHERE `guid` BETWEEN 15850001 AND 15859999;
-- And nothing should be left with a contradictory movement state:
--   SELECT COUNT(*) FROM `creature` WHERE `guid` BETWEEN 15830001 AND 15839999
--     AND `MovementType` = 0 AND `wander_distance` <> 0;
