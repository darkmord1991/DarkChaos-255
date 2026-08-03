-- ---------------------------------------------------------------------------
-- 230  Map 750/751 -- patrol paths the LATER spawn imports never brought across
-- ---------------------------------------------------------------------------
-- 202_ (2026-08-01) restored 82 paths for the spawns that existed then. The
-- terrain-expansion import that followed added thousands more spawns and did
-- not repeat that step, so another 41 patrolling creatures stand still.
--
-- Matched the same way 202_ did, because the imports assigned fresh guids and
-- the link back to the source spawn is gone: join on (entry - offset) AND
-- rounded x/y position. 39 resolve against cata_world, 2 against nelt_world.
-- Biggest ones: Brumeran 96 points, Nemesis 60, Lava Surger 48, Everlook
-- Bruiser 33, Goblin Siegeworker 23, Timbermaw Mystic 20.
--
-- Path id = the spawn guid, the convention 202_ established: ids only need to
-- be unique and the guid already is, it is self-documenting, and it cannot
-- drift. Verified all 41 guids are absent from waypoint_data, and that none of
-- the 41 spawns has a creature_addon row yet -- so these are pure INSERTs with
-- no risk of clobbering an existing addon.
--
-- THREE SPAWNS WERE DELIBERATELY EXCLUDED. Ice Thistle Yeti (16376911) and two
-- Moontouched Owlbeasts (16377262/3) carry a waypointPathId in cata but their
-- source MovementType is 1 (random), so the path is never used there either.
-- Ours already match the source at MovementType 1. Importing the path would
-- have looked like progress and changed nothing; forcing them to 2 would have
-- changed behaviour the source does not have.
--
-- MovementType is set to 2 only where the SOURCE says 2 -- 33 of these are
-- currently 0 (idle) and 6 are already 2 (those are the ones logging
-- "doesn't have waypoint path id: 0" every boot).
--
-- SCHEMA: cata_world.waypoint_data is column-identical to ours, so those 39
-- copy with INSERT ... SELECT. nelt_world's is NOT -- it has no `velocity`,
-- `smoothTransition` or `move_type` and adds `move_flag` and
-- `inverse_formation_angle` -- so the 2 nelt paths map move_flag -> move_type
-- and default the rest. Column names also differ on the addon table:
-- ours/nelt `path_id`, cata `waypointPathId`.
--
-- ALREADY VERIFIED CLEAN, so not touched here:
--   * every existing creature_addon.path_id on 750/751 resolves in waypoint_data
--   * all 25 SmartAI WP_START actions resolve. NOTE those validate against the
--     `waypoints` table via SmartWaypointMgr, NOT `waypoint_data`, and the path
--     id is action_param2 (param1 is forcedMovement) -- checking either the
--     wrong table or the wrong column reports a fleet of false failures.
-- ---------------------------------------------------------------------------

-- --- 39 paths from cata_world ---------------------------------------------
DELETE FROM `waypoint_data` WHERE `id` IN (
  9841113, 9841117, 9841619, 9842215, 9842235, 9842671, 9842675, 9842679, 9842686,
  9842713, 9842719, 9842756, 9842767, 9842786, 9842792, 9842802, 9842809, 9842817,
  9842827, 9842835, 9842836, 9842843, 9842847, 9842849, 9842861, 9842894, 9842895,
  9842919, 9843049, 9843050, 9843056, 9843503, 9843519, 16376740, 16377014,
  16377021, 16377061, 16460860, 16467232);
INSERT INTO `waypoint_data`
 (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `velocity`,
  `delay`, `smoothTransition`, `move_type`, `action`, `action_chance`, `wpguid`)
SELECT m.dst, w.`point`, w.`position_x`, w.`position_y`, w.`position_z`, w.`orientation`,
       w.`velocity`, w.`delay`, w.`smoothTransition`, w.`move_type`, w.`action`,
       w.`action_chance`, 0
FROM cata_world.`waypoint_data` w
JOIN (SELECT 9841113 dst, 3848250 src UNION ALL SELECT 9841117, 3848320
  UNION ALL SELECT 9841619, 3853710 UNION ALL SELECT 9842215, 3859990
  UNION ALL SELECT 9842235, 3860190 UNION ALL SELECT 9842671, 3865390
  UNION ALL SELECT 9842675, 3865430 UNION ALL SELECT 9842679, 3865470
  UNION ALL SELECT 9842686, 3865540 UNION ALL SELECT 9842713, 3865810
  UNION ALL SELECT 9842719, 3865870 UNION ALL SELECT 9842756, 3866250
  UNION ALL SELECT 9842767, 3866370 UNION ALL SELECT 9842786, 3866580
  UNION ALL SELECT 9842792, 3866640 UNION ALL SELECT 9842802, 3866740
  UNION ALL SELECT 9842809, 3866810 UNION ALL SELECT 9842817, 3866890
  UNION ALL SELECT 9842827, 3866990 UNION ALL SELECT 9842835, 3867070
  UNION ALL SELECT 9842836, 3867080 UNION ALL SELECT 9842843, 3867150
  UNION ALL SELECT 9842847, 3867190 UNION ALL SELECT 9842849, 3867210
  UNION ALL SELECT 9842861, 3867340 UNION ALL SELECT 9842894, 3867670
  UNION ALL SELECT 9842895, 3867680 UNION ALL SELECT 9842919, 3867920
  UNION ALL SELECT 9843049, 3869340 UNION ALL SELECT 9843050, 3869350
  UNION ALL SELECT 9843056, 3869410 UNION ALL SELECT 9843503, 3874200
  UNION ALL SELECT 9843519, 3874430 UNION ALL SELECT 16376740, 2767400
  UNION ALL SELECT 16377014, 2770140 UNION ALL SELECT 16377021, 2770210
  UNION ALL SELECT 16377061, 2770610 UNION ALL SELECT 16460860, 3608600
  UNION ALL SELECT 16467232, 3755800) m ON m.src = w.`id`;

-- --- 2 paths from nelt_world (different columns) --------------------------
DELETE FROM `waypoint_data` WHERE `id` IN (15802079, 16467154);
INSERT INTO `waypoint_data`
 (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `velocity`,
  `delay`, `smoothTransition`, `move_type`, `action`, `action_chance`, `wpguid`)
SELECT m.dst, w.`point`, w.`position_x`, w.`position_y`, w.`position_z`, w.`orientation`,
       0, w.`delay`, 0, w.`move_flag`, w.`action`, w.`action_chance`, 0
FROM nelt_world.`waypoint_data` w
JOIN (SELECT 15802079 dst, 10000275 src
  UNION ALL SELECT 16467154, 99759016) m ON m.src = w.`id`;

-- --- link the spawns to their paths ---------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (
  9841113, 9841117, 9841619, 9842215, 9842235, 9842671, 9842675, 9842679, 9842686,
  9842713, 9842719, 9842756, 9842767, 9842786, 9842792, 9842802, 9842809, 9842817,
  9842827, 9842835, 9842836, 9842843, 9842847, 9842849, 9842861, 9842894, 9842895,
  9842919, 9843049, 9843050, 9843056, 9843503, 9843519, 16376740, 16377014,
  16377021, 16377061, 16460860, 16467232, 15802079, 16467154);
INSERT INTO `creature_addon`
 (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT DISTINCT w.`id`, w.`id`, 0, 0, 1, 0, 0, ''
FROM `waypoint_data` w
WHERE w.`id` IN (
  9841113, 9841117, 9841619, 9842215, 9842235, 9842671, 9842675, 9842679, 9842686,
  9842713, 9842719, 9842756, 9842767, 9842786, 9842792, 9842802, 9842809, 9842817,
  9842827, 9842835, 9842836, 9842843, 9842847, 9842849, 9842861, 9842894, 9842895,
  9842919, 9843049, 9843050, 9843056, 9843503, 9843519, 16376740, 16377014,
  16377021, 16377061, 16460860, 16467232, 15802079, 16467154);

-- --- and make them actually walk it ---------------------------------------
UPDATE `creature` SET `MovementType` = 2 WHERE `guid` IN (
  9841113, 9841117, 9841619, 9842215, 9842235, 9842671, 9842675, 9842679, 9842686,
  9842713, 9842719, 9842756, 9842767, 9842786, 9842792, 9842802, 9842809, 9842817,
  9842827, 9842835, 9842836, 9842843, 9842847, 9842849, 9842861, 9842894, 9842895,
  9842919, 9843049, 9843050, 9843056, 9843503, 9843519, 16376740, 16377014,
  16377021, 16377061, 16460860, 16467232, 15802079, 16467154);

-- Verify -- expect 41 paths, 41 addon rows, and 0 broken links:
--   SELECT COUNT(DISTINCT id) FROM `waypoint_data` WHERE id IN (9841113, ..., 16467154);
--   SELECT COUNT(*) FROM `creature_addon` a JOIN `creature` c ON c.guid=a.guid
--    WHERE c.map IN (750,751) AND a.path_id<>0
--      AND NOT EXISTS (SELECT 1 FROM `waypoint_data` w WHERE w.id=a.path_id);   -- 0
--   SELECT COUNT(*) FROM `creature` c WHERE c.map IN (750,751) AND c.MovementType=2
--     AND NOT EXISTS (SELECT 1 FROM `creature_addon` a WHERE a.guid=c.guid AND a.path_id<>0);
-- and the boot log should lose its "doesn't have waypoint path id: 0" lines.
