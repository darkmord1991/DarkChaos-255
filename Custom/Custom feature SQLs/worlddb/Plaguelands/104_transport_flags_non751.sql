-- 104_transport_flags_non751.sql -- GO_FLAG_TRANSPORT for the non-751 elevators, DB step 43.
--
-- Companion to 103_. Found while fixing the map-751 Undercity elevators, by asking
-- whether the same gap existed anywhere else. It did -- and it is exactly the place
-- the report compared it to:
--
--     "i fall through the platform like on blackwing descent"
--
-- Blackwing Descent has the identical defect. A server-wide sweep for
-- GAMEOBJECT_TYPE_TRANSPORT (type 11) templates with no `gameobject_template_addon`
-- row returns twelve, and only twelve:
--
--     9x  4620649..4620657   map 751 Undercity      -- handled by 103_, from stock source
--     1x  203716             map 669 Blackwing Descent Elevator
--     1x  207834             map 669 Doodad_BlackWingV2_Elevator_Onyxia01
--     1x  327444             Doodad_9CAS_Castle_ElevatorPlatform001 (Castle Nathria)
--
-- This file covers the three that 103_ cannot: they are Cata/Shadowlands imports with
-- no stock counterpart to copy flags from, so the value is set directly.
--
-- WHY 40 AND NOT SOMETHING ELSE -- taken from the data, not from habit. Of the 90
-- type-11 templates that DO have an addon row, 89 carry bit 0x08 GO_FLAG_TRANSPORT and
-- 74 use exactly 40 (0x08 GO_FLAG_TRANSPORT | 0x20 GO_FLAG_NODESPAWN). 40 is the
-- convention for a rideable elevator: 0x08 makes the client treat it as something that
-- carries passengers, 0x20 stops it despawning as it animates.
--
-- BOTH BLACKWING DESCENT ELEVATORS ALREADY HAVE THEIR ANIMATION -- TransportAnimation
-- carries 13 frames for 203716 and 14 for 207834, so unlike the map-751 elevators these
-- were spawning correctly all along. The missing flag was the whole bug: the platform
-- renders and moves, but is not a ride, so you drop through it.
--
-- 327444 IS INCLUDED BUT WILL NOT WORK YET, and that is deliberate rather than an
-- oversight: it has ZERO TransportAnimation frames and ZERO spawns, so
-- StaticTransport::Create would reject it on the AnimationInfo check regardless of any
-- flag. The row is added so the template is correct when Castle Nathria's transports are
-- imported; the animation frames are a separate job, the same one 101_ did for map 751.

DELETE FROM `gameobject_template_addon` WHERE `entry` IN (203716, 207834, 327444);
INSERT INTO `gameobject_template_addon`
  (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`) VALUES
(203716, 0, 40, 0, 0, 0, 0, 0, 0),
(207834, 0, 40, 0, 0, 0, 0, 0, 0),
(327444, 0, 40, 0, 0, 0, 0, 0, 0);

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'the 3 rows exist (want 3)' AS what, COUNT(*) AS n
  FROM `gameobject_template_addon` WHERE `entry` IN (203716, 207834, 327444)
UNION ALL SELECT '  ...all rideable, flags & 0x08 (want 3)', COUNT(*)
  FROM `gameobject_template_addon` WHERE `entry` IN (203716, 207834, 327444) AND `flags` & 8
UNION ALL SELECT 'type-11 templates left with no addon row (want 0 once 103_ is applied too)', COUNT(*)
  FROM `gameobject_template` t
  LEFT JOIN `gameobject_template_addon` a ON a.`entry` = t.`entry`
  WHERE t.`type` = 11 AND a.`entry` IS NULL
UNION ALL SELECT 'SPAWNED type-11 templates still not rideable (want 0)', COUNT(*)
  FROM (SELECT DISTINCT g.`id` FROM `gameobject` g
         JOIN `gameobject_template` t2 ON t2.`entry` = g.`id` AND t2.`type` = 11) q
  LEFT JOIN `gameobject_template_addon` a2 ON a2.`entry` = q.`id`
  WHERE a2.`entry` IS NULL OR NOT a2.`flags` & 8;
