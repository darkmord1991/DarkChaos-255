-- 70_new_zone_waypoints.sql — map 751 Lordaeron extension, DB step 9.
--
-- Restores the patrols 63_ deliberately disabled. REQUIRES 62_ and 63_.
--
-- 63_ set MovementType 2 -> 0 on every waypoint spawn, because a waypoint spawn
-- with no `waypoint_data` path fails to load. This file puts the paths in and turns
-- the movement back on, STRICTLY in this order:
--     waypoint_data  ->  creature_addon.path_id  ->  MovementType = 2
-- Any other order reproduces exactly the load failure 63_ was avoiding.
--
-- 82 paths / 2,800 waypoint rows. `wpguid` and `action` are 0 on every row, so
-- there are no foreign ids inside the path data to remap.
--
-- PATH IDS CANNOT USE A +OFFSET: the largest source `waypointPathId` here is
-- 3,275,990, so any offset big enough to clear collisions runs somewhere unhelpful.
-- They are allocated sequentially into 4,100,000+ instead (that band is empty in
-- waypoint_data; acore's max id is 230,759,059).
--
-- REBUILDING THE GUID MAP: 67_ drops and recreates `dc_map751_spawn_guid`, so
-- running it a second time (when nothing is above the cap any more) leaves the
-- table EMPTY — which is the state it is in now. Rather than depend on it, this
-- file reconstructs the mapping from the data: our spawn -> source spawn by
-- (entry - 4,100,000) plus exact x/y/z. That matched all 9,667 spawns.
-- ~12 source spawns are stacked on an identical point (Blizzard does this
-- deliberately), so the join is 1:many there; MIN(source guid) is the tie-break.
-- Only 2 of the path-carrying spawns are affected and both are stacked patrol
-- guards where either path is plausible.

-- ---------------------------------------------------------------------------
-- 1. Rebuild the spawn guid map (our guid -> source guid)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map751_spawn_guid`;
CREATE TABLE `dc_map751_spawn_guid` (
  `kind`     ENUM('c','g') NOT NULL,
  `src_guid` INT UNSIGNED NOT NULL,
  `old_guid` INT UNSIGNED NOT NULL DEFAULT 0,
  `new_guid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`kind`,`new_guid`),
  KEY `k_src` (`kind`,`src_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map751_spawn_guid` (`kind`,`src_guid`,`new_guid`)
SELECT 'c', MIN(c.`guid`), n.`guid`
FROM `creature` n
JOIN `cata_world`.`creature` c
  ON c.`id` = n.`id` - 4100000
 AND c.`position_x` = n.`position_x`
 AND c.`position_y` = n.`position_y`
 AND c.`position_z` = n.`position_z`
WHERE n.`map` = 751 AND n.`id` BETWEEN 4100000 AND 4199999
GROUP BY n.`guid`;

INSERT INTO `dc_map751_spawn_guid` (`kind`,`src_guid`,`new_guid`)
SELECT 'g', MIN(c.`guid`), n.`guid`
FROM `gameobject` n
JOIN `cata_world`.`gameobject` c
  ON c.`id` = n.`id` - 4600000
 AND c.`position_x` = n.`position_x`
 AND c.`position_y` = n.`position_y`
 AND c.`position_z` = n.`position_z`
WHERE n.`map` = 751 AND n.`id` BETWEEN 4600000 AND 4899999
GROUP BY n.`guid`;

-- ---------------------------------------------------------------------------
-- 2. Allocate path ids
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map751_path_map`;
CREATE TABLE `dc_map751_path_map` (
  `src_path` INT UNSIGNED NOT NULL,
  `new_path` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`src_path`),
  UNIQUE KEY `uk_new` (`new_path`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map751_path_map` (`src_path`,`new_path`)
SELECT p.`src_path`, 4100000 + ROW_NUMBER() OVER (ORDER BY p.`src_path`)
FROM (
  SELECT DISTINCT a.`waypointPathId` AS `src_path`
    FROM `cata_world`.`creature_addon` a
    JOIN `dc_map751_spawn_guid` m ON m.`kind` = 'c' AND m.`src_guid` = a.`guid`
   WHERE a.`waypointPathId` > 0
  UNION
  SELECT DISTINCT ta.`waypointPathId`
    FROM `cata_world`.`creature_template_addon` ta
    JOIN `dc_map751_src_creature` s ON s.`id` = ta.`entry`
   WHERE ta.`waypointPathId` > 0
) p;

-- ---------------------------------------------------------------------------
-- 3. waypoint_data FIRST — the paths must exist before anything points at them
-- ---------------------------------------------------------------------------
DELETE FROM `waypoint_data` WHERE `id` BETWEEN 4100000 AND 4199999;
INSERT INTO `waypoint_data`
  (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,
   `move_type`,`action`,`action_chance`,`wpguid`)
SELECT pm.`new_path`, w.`point`, w.`position_x`, w.`position_y`, w.`position_z`,
       w.`orientation`, w.`delay`, w.`move_type`, w.`action`, w.`action_chance`, 0
FROM `cata_world`.`waypoint_data` w
JOIN `dc_map751_path_map` pm ON pm.`src_path` = w.`id`;

-- ---------------------------------------------------------------------------
-- 4. THEN point the spawns at them. Most of these spawns have no creature_addon
--    row at all (only 121 of 9,667 do), so upsert rather than update.
-- ---------------------------------------------------------------------------
INSERT INTO `creature_addon`
  (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`)
SELECT m.`new_guid`, pm.`new_path`, 0, 0, 0, 0, 0, ''
FROM `cata_world`.`creature_addon` a
JOIN `dc_map751_spawn_guid` m  ON m.`kind` = 'c' AND m.`src_guid` = a.`guid`
JOIN `dc_map751_path_map`   pm ON pm.`src_path` = a.`waypointPathId`
WHERE a.`waypointPathId` > 0
ON DUPLICATE KEY UPDATE `path_id` = VALUES(`path_id`);

-- template-level paths apply to every spawn of that entry
UPDATE `creature_template_addon` t
  JOIN `cata_world`.`creature_template_addon` ta ON ta.`entry` = t.`entry` - 4100000
  JOIN `dc_map751_path_map` pm ON pm.`src_path` = ta.`waypointPathId`
  SET t.`path_id` = pm.`new_path`
  WHERE t.`entry` BETWEEN 4100000 AND 4199999 AND ta.`waypointPathId` > 0;

-- ---------------------------------------------------------------------------
-- 5. ONLY NOW turn waypoint movement back on, and only where the source had it
--    AND a path actually landed.
-- ---------------------------------------------------------------------------
UPDATE `creature` n
  JOIN `dc_map751_spawn_guid` m ON m.`kind` = 'c' AND m.`new_guid` = n.`guid`
  JOIN `cata_world`.`creature` c ON c.`guid` = m.`src_guid`
  JOIN `creature_addon` na ON na.`guid` = n.`guid` AND na.`path_id` > 0
  SET n.`MovementType` = 2
  WHERE n.`map` = 751 AND c.`MovementType` = 2;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'guid map rebuilt (creature)' AS what, COUNT(*) AS n FROM `dc_map751_spawn_guid` WHERE `kind` = 'c'
UNION ALL SELECT 'guid map rebuilt (gameobject)', COUNT(*) FROM `dc_map751_spawn_guid` WHERE `kind` = 'g'
UNION ALL SELECT 'paths allocated',   COUNT(*) FROM `dc_map751_path_map`
UNION ALL SELECT 'waypoint_data rows', COUNT(*) FROM `waypoint_data` WHERE `id` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'spawns given a path', COUNT(*) FROM `creature_addon` a JOIN `creature` c ON c.`guid` = a.`guid`
  WHERE c.`map` = 751 AND a.`path_id` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'templates given a path', COUNT(*) FROM `creature_template_addon`
  WHERE `entry` BETWEEN 4100000 AND 4199999 AND `path_id` > 0
UNION ALL SELECT 'patrols re-enabled (MovementType=2)', COUNT(*) FROM `creature`
  WHERE `map` = 751 AND `id` BETWEEN 4100000 AND 4199999 AND `MovementType` = 2;

-- THE load-failure check: a waypoint spawn with no path. Must be zero.
SELECT 'PROBLEM: MovementType=2 with no path' AS problem, COUNT(*) AS n
FROM `creature` c
LEFT JOIN `creature_addon` a ON a.`guid` = c.`guid`
LEFT JOIN `creature_template_addon` t ON t.`entry` = c.`id`
WHERE c.`map` = 751 AND c.`MovementType` = 2
  AND COALESCE(a.`path_id`, 0) = 0 AND COALESCE(t.`path_id`, 0) = 0;

-- a path_id pointing at a path with no rows would fail the same way
SELECT 'PROBLEM: path_id with no waypoint_data' AS problem, COUNT(*) AS n
FROM `creature_addon` a
WHERE a.`path_id` BETWEEN 4100000 AND 4199999
  AND NOT EXISTS (SELECT 1 FROM `waypoint_data` w WHERE w.`id` = a.`path_id`);

-- every allocated path should have landed rows
SELECT 'PROBLEM: allocated path with no rows' AS problem, COUNT(*) AS n
FROM `dc_map751_path_map` pm
WHERE NOT EXISTS (SELECT 1 FROM `waypoint_data` w WHERE w.`id` = pm.`new_path`);

-- the 2 stacked spawns where the source was ambiguous, for the record
SELECT 'stacked spawn, path chosen by MIN(source guid)' AS note, n.`guid`, n.`id`,
       COUNT(DISTINCT a.`waypointPathId`) AS candidate_paths
FROM `creature` n
JOIN `cata_world`.`creature` c ON c.`id` = n.`id` - 4100000
 AND c.`position_x` = n.`position_x` AND c.`position_y` = n.`position_y` AND c.`position_z` = n.`position_z`
JOIN `cata_world`.`creature_addon` a ON a.`guid` = c.`guid` AND a.`waypointPathId` > 0
WHERE n.`map` = 751 AND n.`id` BETWEEN 4100000 AND 4199999
GROUP BY n.`guid`, n.`id` HAVING candidate_paths > 1;
