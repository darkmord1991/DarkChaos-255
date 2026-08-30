-- ---------------------------------------------------------------------------
-- 305  Round 47 -- the last missing map-750 patrol routes (22 spawns)
-- ---------------------------------------------------------------------------
-- Closes the "~15 guard patrols still missing" item left open after 277_'s
-- wander restore. The number in the handoff was a per-ENTRY count; this is the
-- per-SPAWN answer, measured rather than assumed.
--
-- HOW THE SET WAS DERIVED
--   candidate  = a map-750 spawn with MovementType 0/1 and NO creature_addon
--                path, whose source counterpart (same entry, minus the import
--                offset) is MovementType 2 with a real path of >= 3 points
--   matched by = MINIMUM DISTANCE FROM OUR SPAWN TO THE ROUTE, not to the
--                source spawn. Felwood/Ashenvale carry Cata entries on a
--                different spawn layout, so spawn-to-spawn matching finds
--                nothing there; route distance does. Mutual-nearest one-to-one
--                with a 25 yd cutoff (the same rule 202_/230_ used).
--
-- THE TRAP THAT SHRANK THIS FILE FROM 76 PAIRS TO 22.
-- The raw match produced 54 cata_world pairs and 22 nelt_world pairs. Testing
-- each candidate route's FIRST POINT against our live `waypoint_data` showed
-- **52 of the 54 cata routes are ALREADY IMPORTED** -- 202_/230_ brought them
-- in and assigned them to a different spawn of the same entry. Those 52 are
-- not a gap: our spawn merely stands near a route that already belongs to a
-- neighbour, and importing it again would put two creatures walking the same
-- line in lockstep. Only the 2 unclaimed cata routes and the 21 unclaimed nelt
-- routes are real, and one spawn (16467233) matched in both sources -- nelt
-- wins there on distance (5.4 yd vs 7.1 yd), so 22 pairs remain.
--
-- SOURCE SPLIT: 1 route from cata_world, 21 from nelt_world. That is expected
-- -- these are the Darkshore/Moonglade/Ashenvale sentries and the Hyjal spirit
-- walkers, all of which live in the Neltharion layer.
--
-- COLUMN MAPPING. `waypoint_data` is column-identical between ours and
-- cata_world (13 columns), so that side copies verbatim. nelt_world's table is
-- 12 columns and differs in three places:
--     nelt `move_flag`   -> ours `move_type`      (0 = walk, 1 = run; aligned)
--     nelt `orientation` -> INT, and every row in these 21 paths is 0, which
--                           means "no forced facing" -> ours NULL, NOT 0.0
--                           (0.0 would nail all 302 waypoints facing east)
--     nelt has no `velocity` / `smoothTransition` -> 0, the core defaults
--
-- PATH IDS ARE THE SPAWN GUID, the convention 202_ set: unique by construction
-- and self-documenting. Verified none of the 22 guids collides with an existing
-- `waypoint_data` id.
--
-- 4 of the 22 spawns are currently MovementType 1 (wander): 3 Spirits of
-- Malorne and 1 Ashenvale Skirmisher. They lose their wander radius in favour
-- of the authored route -- that is the faithful reading of the source, which
-- has them patrolling, and 277_ only gave them wander because no path existed.
-- `dc_map750_patrol_backup` records the old values so it is revertable.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) The pinned pair list
-- ---------------------------------------------------------------------------
-- Pinned as literals on purpose. Computing the set live would feed the same
-- predicate to the DELETE and the INSERT, and any later import that adds a
-- pathless spawn near one of these routes would silently widen it -- the exact
-- failure documented for 202_/203_.
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `dc_patrol_map`;
CREATE TEMPORARY TABLE `dc_patrol_map` (
  `our_guid`  INT UNSIGNED NOT NULL PRIMARY KEY,
  `src`       VARCHAR(4)   NOT NULL,
  `src_path`  INT UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_patrol_map` (`our_guid`,`src`,`src_path`) VALUES
-- cata_world (1)
(15801056,'cata',3601740),  -- 3707115 Jaedenar Adept          25 pts, 0.04 yd
-- nelt_world (21)
(16467234,'nelt',240701),   -- 3603296 Orgrimmar Grunt          5 pts, 13.03 yd
(16461802,'nelt',66657678), -- 3603885 Sentinel Velene Starstrike 10 pts, 14.34 yd
(16461118,'nelt',66657679), -- 3606087 Astranaar Sentinel       27 pts,  3.29 yd
(16467207,'nelt',165405),   -- 3633193 Ashenvale Skirmisher      9 pts,  1.80 yd
(16461719,'nelt',66657677), -- 3639254 Stardust Sentinel         6 pts,  6.60 yd
(9844298 ,'nelt',4092200),  -- 3640922 Okrog                    19 pts,  1.68 yd
(16467233,'nelt',239159),   -- 3642650 Goblin Siegeworker        7 pts,  5.39 yd
(9843832 ,'nelt',2509680),  -- 3652176 Spirit of Malorne        17 pts,  3.20 yd
(9843840 ,'nelt',1952690),  -- 3652176 Spirit of Malorne        16 pts, 16.90 yd
(9843902 ,'nelt',1945050),  -- 3652176 Spirit of Malorne        20 pts,  9.60 yd
(15802025,'nelt',10000284), -- 3711754 Meggi Peppinrocker       15 pts, 10.30 yd
(15802074,'nelt',10000273), -- 3711822 Moonglade Warden          9 pts,  8.45 yd
(15860658,'nelt',10000314), -- 3732969 Lor'danel Sentinel       12 pts,  6.52 yd
(15860663,'nelt',10000318), -- 3732969 Lor'danel Sentinel        6 pts,  6.30 yd
(15860672,'nelt',10000316), -- 3732969 Lor'danel Sentinel       20 pts,  4.11 yd
(15860682,'nelt',10000317), -- 3732969 Lor'danel Sentinel       10 pts, 10.56 yd
(15861485,'nelt',10000313), -- 3733359 Nightsaber Rider         14 pts,  7.45 yd
(15861945,'nelt',1689300),  -- 3734385 Horoo the Flamekeeper    25 pts,  6.37 yd
(15830057,'nelt',10000293), -- 3747844 Whisperwind Protector    14 pts, 13.79 yd
(15830350,'nelt',10000294), -- 3748556 Talonbranch Guardian     13 pts,  6.12 yd
(15830354,'nelt',10000295); -- 3748556 Talonbranch Guardian      3 pts,  3.43 yd

-- ---------------------------------------------------------------------------
-- B) Backup, so the movement change is revertable
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_map750_patrol_backup` (
  `guid`            INT UNSIGNED NOT NULL PRIMARY KEY,
  `old_mt`          TINYINT UNSIGNED NOT NULL,
  `old_wander`      FLOAT NOT NULL,
  `old_path_id`     INT UNSIGNED NOT NULL DEFAULT 0,
  `backed_up_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- INSERT IGNORE with no leading DELETE, on purpose and for the same reason
-- 233_ freezes `dc_map750_snap`: the backup must hold the PRE-change values. A
-- delete-and-reinsert would, on the second run, "back up" the state this file
-- just created and destroy the only record of the original.
INSERT IGNORE INTO `dc_map750_patrol_backup` (`guid`,`old_mt`,`old_wander`,`old_path_id`)
SELECT c.`guid`, c.`MovementType`, c.`wander_distance`,
       COALESCE((SELECT a.`path_id` FROM `creature_addon` a WHERE a.`guid` = c.`guid`), 0)
FROM `creature` c
JOIN `dc_patrol_map` m ON m.`our_guid` = c.`guid`;

-- ---------------------------------------------------------------------------
-- C) waypoint_data -- 302 waypoints across 22 paths, keyed by our spawn guid
-- ---------------------------------------------------------------------------
-- Multi-table DELETE rather than `id IN (SELECT ...)`: a TEMPORARY table cannot
-- be opened twice in one statement, and the join form keeps it to one reference.
DELETE w FROM `waypoint_data` w
JOIN `dc_patrol_map` m ON m.`our_guid` = w.`id`;

INSERT INTO `waypoint_data`
    (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`velocity`,`delay`,
     `smoothTransition`,`move_type`,`action`,`action_chance`,`wpguid`)
SELECT m.`our_guid`, w.`point`, w.`position_x`, w.`position_y`, w.`position_z`, w.`orientation`,
       w.`velocity`, w.`delay`, w.`smoothTransition`, w.`move_type`, w.`action`, w.`action_chance`, 0
FROM `dc_patrol_map` m
JOIN `cata_world`.`waypoint_data` w ON w.`id` = m.`src_path`
WHERE m.`src` = 'cata';

INSERT INTO `waypoint_data`
    (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`velocity`,`delay`,
     `smoothTransition`,`move_type`,`action`,`action_chance`,`wpguid`)
SELECT m.`our_guid`, w.`point`, w.`position_x`, w.`position_y`, w.`position_z`,
       NULLIF(w.`orientation`, 0), 0, w.`delay`, 0, w.`move_flag`, w.`action`, w.`action_chance`, 0
FROM `dc_patrol_map` m
JOIN `nelt_world`.`waypoint_data` w ON w.`id` = m.`src_path`
WHERE m.`src` = 'nelt';

-- ---------------------------------------------------------------------------
-- D) creature_addon -- point each spawn at its new path
-- ---------------------------------------------------------------------------
-- 6 of the 22 already have an addon row (auras/emotes/visibility from 273_), so
-- this is an UPSERT and deliberately has NO leading DELETE: dropping those rows
-- to re-insert them would strip the aura layer 273_ built. Only `path_id`
-- moves. Idempotency comes from the NOT EXISTS guard on the insert and from the
-- update being a fixed assignment, so re-running changes nothing.
-- ---------------------------------------------------------------------------
INSERT INTO `creature_addon` (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`)
SELECT m.`our_guid`, m.`our_guid`, 0, 0, 0, 0, 0, NULL
FROM `dc_patrol_map` m
WHERE NOT EXISTS (SELECT 1 FROM `creature_addon` a WHERE a.`guid` = m.`our_guid`);

UPDATE `creature_addon` a
JOIN `dc_patrol_map` m ON m.`our_guid` = a.`guid`
SET a.`path_id` = m.`our_guid`;

-- ---------------------------------------------------------------------------
-- E) creature -- switch the 22 to waypoint movement
-- ---------------------------------------------------------------------------
-- wander_distance must go to 0: `ObjectMgr::LoadCreatures` rejects a spawn that
-- carries both MovementType 2 and a wander radius.
-- ---------------------------------------------------------------------------
UPDATE `creature` c
JOIN `dc_patrol_map` m ON m.`our_guid` = c.`guid`
SET c.`MovementType` = 2, c.`wander_distance` = 0
WHERE c.`map` = 750;

DROP TEMPORARY TABLE IF EXISTS `dc_patrol_map`;

-- ---------------------------------------------------------------------------
-- Verify (expected: 22 / 302 / 0)
-- ---------------------------------------------------------------------------
--   SELECT COUNT(*) FROM creature c JOIN creature_addon a ON a.guid = c.guid
--    WHERE c.map = 750 AND c.MovementType = 2 AND a.path_id = c.guid
--      AND c.guid IN (SELECT guid FROM dc_map750_patrol_backup);
--   SELECT COUNT(*) FROM waypoint_data
--    WHERE id IN (SELECT guid FROM dc_map750_patrol_backup);
--   -- no map-750 spawn left with MovementType 2 and no path:
--   SELECT COUNT(*) FROM creature c WHERE c.map = 750 AND c.MovementType = 2
--     AND NOT EXISTS (SELECT 1 FROM creature_addon a WHERE a.guid = c.guid AND a.path_id > 0);
-- ---------------------------------------------------------------------------
