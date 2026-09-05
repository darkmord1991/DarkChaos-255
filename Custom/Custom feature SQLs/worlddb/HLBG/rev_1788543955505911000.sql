-- Hinterland BG: sync the spawn work done on map 1412 across to map 1411.
--
-- WHAT CHANGED ON 1412
-- Diffing the two maps per entry, the only additions are 14 creature spawns:
--   810024 Kor'kron Grunt        +5
--   810025 Kor'kron Shieldguard  +3
--   810026 Kor'kron Axethrower   +2
--   810027 Kor'kron Overseer     +3
--   55002  Services NPC          +1
-- No gameobjects were added, so nothing is copied on that side.
--
-- THIS SYNC IS ADDITIVE ONLY - it deliberately does not make 1411 identical.
-- 1411 also holds content 1412 has never had, and deleting it would be wrong:
--   * 15 creatures: the Revantusk Village vendors and questgivers (Smith
--     Slagtree, Otho Moji'ko, Mystic Yayo'jin, Katoom the Angler, Huntsman
--     Markhor, Lard, Primal Torntusk, Gorkas, Mrs. Winters) plus holiday NPCs
--     (Winter Reveler, Midsummer bonfire bunny, Bountiful Feast Hostess).
--   * 109 gameobjects, almost entirely seasonal decor - Hallow's End pumpkins,
--     ghosts, bats and skull candles; Midsummer Fire Festival streamers and
--     posts; Winter Veil mistletoe; a Pilgrim's Bounty table; plus a mailbox,
--     a bonfire and the Stormwind's Pride icebreaker.
-- Those are pre-existing clone differences, not work done on 1412, so they stay.
--
-- WAYPOINTS
-- Two of the new spawns patrol (MovementType 2) and carry creature_addon
-- path ids 230759060 (26 points) and 230759061 (43 points). The two maps
-- already SHARE waypoint paths - path 53004954 is referenced by the Revantusk
-- Warcaller on 1411 and on 1412 alike - because the terrain is identical, so
-- the 1411 copies reference the same paths rather than duplicating the points.
--
-- NOT COPIED: four "Waypoint (Only GM can see it)" creatures (entry 1, guids
-- 16751217/16751218/16751226/16751227) sit on 1412 at the exact coordinates of
-- the two patrol start points, two per path. They are leftover markers from the
-- in-game .wp editor, not content. See the cleanup at the bottom of this file.
--
-- GUIDs are explicit. creature.guid is capped at 0xFFFFFF (16,777,215) and the
-- table is already at 16,751,232, so the ~26k of remaining auto-increment
-- headroom must not be spent on routine spawn work. 9002224-9002237 is verified
-- free.

DELETE FROM `creature` WHERE `guid` BETWEEN 9002224 AND 9002237;
INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `dynamicflags`, `VerifiedBuild`) VALUES
-- Services NPC
(9002224, 55002,  1411, 47, 6738, 1, 4294967295, 0, -643.042, -4703.46,  4.90362, 0.897667, 300, 0, 0, 630000, 0, 0, 0, 0, 0, 0),
-- Kor'kron Grunt (9002225 patrols path 230759060)
(9002225, 810024, 1411, 47, 6738, 1, 4294967295, 1, -617.038, -4659.58,  5.04503, 1.08062,  300, 0, 0,  63000, 0, 2, 0, 0, 0, 0),
(9002226, 810024, 1411, 47, 6738, 1, 4294967295, 1, -596.458, -4558.10,  9.10548, 6.18258,  300, 0, 0,  63000, 0, 0, 0, 0, 0, 0),
(9002227, 810024, 1411, 47, 6738, 1, 4294967295, 1, -593.858, -4603.65, 10.13270, 5.56447,  300, 0, 0,  63000, 0, 0, 0, 0, 0, 0),
(9002228, 810024, 1411, 47, 6738, 1, 4294967295, 1, -619.160, -4577.60, 27.72220, 3.99647,  300, 0, 0,  63000, 0, 0, 0, 0, 0, 0),
(9002229, 810024, 1411, 47, 6738, 1, 4294967295, 1, -622.742, -4589.37, 27.72220, 1.46671,  300, 0, 0,  63000, 0, 0, 0, 0, 0, 0),
-- Kor'kron Shieldguard
(9002230, 810025, 1411, 47, 6738, 1, 4294967295, 1, -558.278, -4636.34, 13.20820, 3.00957,  300, 0, 0, 126000, 0, 0, 0, 0, 0, 0),
(9002231, 810025, 1411, 47, 6738, 1, 4294967295, 1, -592.487, -4553.25,  9.10548, 5.65636,  300, 0, 0, 126000, 0, 0, 0, 0, 0, 0),
(9002232, 810025, 1411, 47, 6738, 1, 4294967295, 1, -464.411, -4550.60,  8.40634, 5.91364,  300, 0, 0, 126000, 0, 0, 0, 0, 0, 0),
-- Kor'kron Axethrower
(9002233, 810026, 1411, 47, 6738, 1, 4294967295, 1, -575.262, -4640.22, 15.43050, 0.268533, 300, 0, 0,  63000, 0, 0, 0, 0, 0, 0),
(9002234, 810026, 1411, 47, 6738, 1, 4294967295, 1, -599.548, -4609.53,  9.71920, 5.58332,  300, 0, 0,  63000, 0, 0, 0, 0, 0, 0),
-- Kor'kron Overseer (9002235 patrols path 230759061)
(9002235, 810027, 1411, 47, 6738, 1, 4294967295, 1, -586.697, -4615.40,  9.39069, 2.46058,  300, 0, 0, 126000, 0, 2, 0, 0, 0, 0),
(9002236, 810027, 1411, 47, 6738, 1, 4294967295, 1, -607.973, -4569.15, 12.31850, 0.69186,  300, 0, 0, 126000, 0, 0, 0, 0, 0, 0),
(9002237, 810027, 1411, 47, 6738, 1, 4294967295, 1, -406.705, -4444.59, 34.03610, 5.71888,  300, 0, 0, 126000, 0, 0, 0, 0, 0, 0);

-- Patrol paths, shared with the 1412 originals.
DELETE FROM `creature_addon` WHERE `guid` IN (9002225, 9002235);
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`) VALUES
(9002225, 230759060, 0, 0, 0, 0, 0, NULL),
(9002235, 230759061, 0, 0, 0, 0, 0, NULL);

-- The 1412 originals were placed in-game, which defaults phaseMask to 1 and
-- leaves zoneId/areaId at 0. Every other spawn on both maps uses phaseMask
-- 4294967295 with zoneId 47 / areaId 6738. Normalising the originals keeps the
-- two maps byte-comparable and avoids a phase-gated guard if phasing is ever
-- used here.
UPDATE `creature` SET `phaseMask` = 4294967295, `zoneId` = 47, `areaId` = 6738
WHERE `map` = 1412 AND `guid` BETWEEN 16751213 AND 16751232 AND `id` <> 1;

-- Cleanup: leftover .wp editor markers on 1412. Entry 1 is the GM-only visual
-- waypoint creature; these four are duplicates sitting on the two patrol start
-- points and are not content. The two maps will still differ in total spawn
-- count afterwards (1411 keeps its 17 village and holiday NPCs), which is the
-- intended pre-existing difference described at the top of this file.
DELETE FROM `creature_addon` WHERE `guid` IN (16751217, 16751218, 16751226, 16751227);
DELETE FROM `creature` WHERE `guid` IN (16751217, 16751218, 16751226, 16751227) AND `id` = 1;
