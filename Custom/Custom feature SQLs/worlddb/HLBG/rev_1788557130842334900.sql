-- Hinterland BG: make map 1411 match map 1412 exactly.
--
-- Supersedes the additive-only stance of the previous sync. That earlier file
-- compared the two maps by per-entry spawn COUNT, which cannot see a spawn that
-- was moved rather than added or deleted - and several were. Thrall, for one,
-- stands at (-588.86, -4578.63) on 1411 but (-623.71, -4581.64) on 1412, about
-- 35 yards apart.
--
-- Re-diffed by entry AND position (0.5 yard tolerance):
--   creatures    1411: 175   1412: 155   only-on-1411: 26   only-on-1412: 6
--   gameobjects  1411: 288   1412: 179   only-on-1411: 109  only-on-1412: 0
--
-- After this file both maps hold the same 155 creatures and 179 gameobjects at
-- the same coordinates.
--
-- WHAT LEAVES 1411 (26 creatures)
--   Revantusk Village population - Smith Slagtree, Otho Moji'ko, Mystic
--   Yayo'jin, Katoom the Angler, Huntsman Markhor, Lard, Primal Torntusk,
--   Gorkas, Mrs. Winters - plus holiday NPCs (Winter Reveler x2, Midsummer
--   bonfire bunny, Bountiful Table, Bountiful Feast Hostess, Ribbon Pole debug
--   target), 4 Teleporters, an outlying Alliance guard, Thrall and a Services
--   NPC at their old positions, and 4 Kor'kron left at the coordinates I first
--   placed them before they were moved on 1412.
--
-- WHAT LEAVES 1411 (109 gameobjects)
--   Seasonal decor almost end to end: Hallow's End pumpkins, ghosts, bats,
--   skull candles and candy buckets; Midsummer Fire Festival streamers, posts
--   and hangings; Winter Veil mistletoe; a Pilgrim's Bounty table; plus a
--   mailbox, a bonfire, a Call to Arms board and the Stormwind's Pride
--   icebreaker.
--
-- WHAT ARRIVES ON 1411 (6 creatures)
--   The repositioned spawns: Thrall, an Alliance guard, a Services NPC, two
--   Teleporters and one Kor'kron Shieldguard. None of them carries a waypoint
--   path, so no creature_addon rows are needed.
--
-- Waypoint paths themselves are untouched, as agreed - duplicate points and the
-- open loop on 230759060 stay exactly as walked.
--
-- GUIDs for the six additions reuse slots freed by the deletions above
-- (9001718/9001719/9001720/9001721/9001724/9001729), so this consumes no new
-- auto-increment headroom. creature.guid is capped at 0xFFFFFF and the table is
-- already at 16,751,232, leaving only ~26k.

-- ---------------------------------------------------------------------------
-- 1. Remove the 26 creatures that exist only on 1411.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN
    (9001691, 9001718, 9001719, 9001720, 9001721, 9001724, 9001729, 9001731,
     9001732, 9001733, 9001734, 9001735, 9001736, 9001806, 9001807, 9001810,
     9001811, 9001817, 9001823, 9001871, 9001873, 9001876, 9002200, 9002201,
     9002202, 9002204);

DELETE FROM `creature` WHERE `map` = 1411 AND `guid` IN
    (9001691, 9001718, 9001719, 9001720, 9001721, 9001724, 9001729, 9001731,
     9001732, 9001733, 9001734, 9001735, 9001736, 9001806, 9001807, 9001810,
     9001811, 9001817, 9001823, 9001871, 9001873, 9001876, 9002200, 9002201,
     9002202, 9002204);

-- ---------------------------------------------------------------------------
-- 2. Remove the 109 gameobjects that exist only on 1411.
-- ---------------------------------------------------------------------------
DELETE FROM `gameobject` WHERE `map` = 1411 AND `guid` IN
    (5714939, 5714940, 5714941, 5714942, 5714943, 5714944, 5714945, 5714946,
     5714947, 5714948, 5714949, 5714950, 5714951, 5714952, 5714953, 5714954,
     5714955, 5714956, 5714957, 5714958, 5714959, 5714960, 5714961, 5714962,
     5714963, 5714964, 5714965, 5714966, 5714967, 5714968, 5714969, 5714970,
     5714971, 5714972, 5714973, 5714979, 5714980, 5714981, 5714982, 5714983,
     5714984, 5714985, 5714986, 5714987, 5714988, 5714989, 5714990, 5714991,
     5714992, 5714993, 5714994, 5714995, 5714996, 5714997, 5714998, 5714999,
     5715002, 5715006, 5715009, 5715043, 5715044, 5715045, 5715053, 5715054,
     5715055, 5715056, 5715057, 5715060, 5715063, 5715069, 5715070, 5715071,
     5715072, 5715073, 5715074, 5715075, 5715076, 5715077, 5715078, 5715079,
     5715080, 5715082, 5715083, 5715085, 5715086, 5715087, 5715088, 5715089,
     5715090, 5715091, 5715092, 5715093, 5715094, 5715095, 5715098, 5715099,
     5715100, 5715101, 5715102, 5715103, 5715104, 5715105, 5715108, 5715109,
     5715110, 5715111, 5715207, 5715211, 5715355);

-- ---------------------------------------------------------------------------
-- 3. Add the 6 repositioned spawns, copied from their 1412 counterparts.
--    curhealth is normalised to the value the template generates; 9002216 on
--    1412 carries curhealth 1 from an in-game move, which is inert only because
--    these creatures have RegenHealth = 1.
-- ---------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` IN (9001691, 9001718, 9001719, 9001720, 9001721, 9001724);
INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `dynamicflags`, `VerifiedBuild`) VALUES
(9001691, 810002, 1411, 47, 6738, 1, 4294967295, 1, -623.711, -4581.640, 11.68720, 5.54805, 300,  0, 0, 4221000, 119820, 0, 0, 0, 0, 0),
(9001718, 810001, 1411, 47, 6738, 1, 4294967295, 1,   21.9848, -4689.600,  8.01701, 1.14034, 300, 30, 0,   63000,      0, 1, 0, 0, 0, 0),
(9001719, 810025, 1411, 47, 6738, 1, 4294967295, 1, -574.674, -4600.570, 10.53290, 1.08815, 300,  0, 0,  126000,      0, 0, 0, 0, 0, 0),
(9001720,  55002, 1411, 47, 6738, 1, 4294967295, 0,  183.350, -4795.630,  7.84753, 5.73650, 300,  0, 0,  630000, 199700, 0, 0, 0, 0, 0),
(9001721, 800002, 1411, 47, 6738, 1, 4294967295, 0,  188.804, -4832.980,  7.84753, 1.54012, 300,  0, 0,   18430,      0, 0, 0, 0, 0, 0),
(9001724, 800002, 1411, 47, 6738, 1, 4294967295, 0, -634.267, -4720.800,  5.38737, 2.55250, 300,  0, 0,  111864,      0, 0, 0, 0, 0, 0);
