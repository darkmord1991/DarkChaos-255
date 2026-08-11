-- =============================================================================
-- Underbelly fix-ups: model info, movement, SmartAI talk target, well landing
-- =============================================================================
-- Four defects from the boot log, all mine.
-- =============================================================================

-- ---------- 1. "Creature (Entry: X) has no model NNN defined in table
--                `creature_template_model`, can't load."  (32 displays) ----------
-- The message is misleading: the failing lookup is GetCreatureModelRandomGender,
-- i.e. a MISSING `creature_model_info` row for the display (Creature.cpp:526-529).
-- I shipped CreatureDisplayInfo + Extra but never generated the model-info rows,
-- so every named Underbelly NPC refused to spawn.
--
-- Values are copied from an existing display that uses the SAME model, so the
-- bounding radius / combat reach are exactly right for that skeleton rather than
-- guessed. Gender comes from the CreatureDisplayInfoExtra row we shipped.
DELETE FROM `creature_model_info` WHERE `DisplayID` BETWEEN 503700 AND 503731;
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`) VALUES
(503700, 0.208, 1.5, 1, 0),
(503701, 0.208, 1.5, 1, 0),
(503702, 0.208, 1.5, 1, 0),
(503703, 0.306, 1.5, 1, 0),
(503704, 0.306, 1.5, 0, 0),
(503705, 0.306, 1.5, 0, 0),
(503706, 0.383, 1.5, 0, 0),
(503707, 0.306, 1.5, 1, 0),
(503708, 0.47875, 1.875, 1, 0),
(503709, 0.306, 1.5, 0, 0),
(503710, 0.306, 1.5, 1, 0),
(503711, 0.306, 1.5, 0, 0),
(503712, 0.306, 1.5, 0, 0),
(503713, 0.3519, 1.725, 1, 0),
(503714, 0.383, 1.5, 0, 0),
(503715, 0.383, 1.5, 1, 0),
(503716, 0.306, 1.5, 0, 0),
(503717, 0.3519, 1.725, 0, 0),
(503718, 0.306, 1.5, 0, 0),
(503719, 0.47875, 1.875, 0, 0),
(503720, 0.236, 1.5, 0, 0),
(503721, 0.306, 1.5, 1, 0),
(503722, 0.383, 1.5, 1, 0),
(503723, 0.3519, 1.725, 1, 0),
(503724, 0.347, 1.5, 0, 0),
(503725, 0.347, 1.5, 2, 0),
(503726, 0.383, 1.5, 2, 0),
(503727, 0.3519, 1.725, 2, 0),
(503728, 0.8725, 3.75, 2, 0),
(503729, 0.306, 1.5, 2, 0),
(503730, 0.306, 1.5, 2, 0),
(503731, 0.306, 1.5, 2, 0);

-- ---------- 2. "WaypointMovementGenerator::DoInitialize: ... doesn't have
--                waypoint path id: 0" ----------
-- My Underbelly import copied the source MovementType verbatim; rows with
-- MovementType 2 (waypoint) reference retail paths that were never imported, so
-- every one of those creatures spams the log on spawn. They have no path here, so
-- they should simply stand still. (Random movement with wander_distance 0 was
-- already collapsed to idle; waypoint was not.)
UPDATE `creature` SET `MovementType` = 0
WHERE `map` = 1413 AND `MovementType` = 2
  AND `guid` BETWEEN 16710000 AND 16712999;

-- ---------- 3. "SMART_ACTION_TALK ... using non-existent Text id 9 for
--                talker 3500046" ----------
-- SMART_ACTION_TALK makes the TARGET talk, not the script owner. Where the ported
-- script used target ACTION_INVOKER (7), the core looked the text group up on
-- whoever walked past instead of on the NPC that owns the lines. Every ported
-- creature_text group belongs to the script owner, so point TALK at self.
UPDATE `smart_scripts` SET `target_type` = 1
WHERE `source_type` IN (0, 9) AND `action_type` = 1 AND `target_type` = 7
  AND (`entryorguid` BETWEEN 3500000 AND 3500999
    OR `entryorguid` BETWEEN 350000000 AND 350099999);

-- ---------- 4. The well teleport lands inside the rocks ----------
-- The old target was the WotLK sewer pipe-exit run through the transform, and the
-- Legion sewers are shaped differently there. Now that the Underbelly is populated
-- we can aim at real, provably open floor: the densest NPC cluster on the main
-- sewer level (17 spawns within 15 yd), with the exact point nudged to the local
-- centroid so it is 3.9 yd clear of the nearest spawn.
UPDATE `areatrigger_teleport`
SET `target_position_x` = 1113.08, `target_position_y` = 1030.18,
    `target_position_z` = 496.10,  `target_orientation` = 3.60
WHERE `ID` IN (6101, 607009);

UPDATE `smart_scripts`
SET `target_x` = 1113.08, `target_y` = 1030.18, `target_z` = 496.10, `target_o` = 3.60
WHERE `entryorguid` = 3500901 AND `source_type` = 0 AND `action_type` = 62;
