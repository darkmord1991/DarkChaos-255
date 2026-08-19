-- 63_new_zone_spawns.sql — map 751 Lordaeron extension, DB step 3.
--
-- Places the 7 new zones' creature + gameobject spawns onto map 751.
-- REQUIRES 61_zone_split.sql (dc_map751_tilezone / dc_map751_chunkzone) and
-- 62_new_zone_templates.sql (templates + dc_map751_src_* sets).
--
-- ###########################################################################
-- SPAWN GUIDS ARE 24-BIT. This is the single most important constraint here.
--   ObjectMgr.cpp:7669 / 7679 -> if (spawnId >= 0xFFFFFF) StopNow()
-- 0xFFFFFF = 16,777,215, and the generator seeds from MAX(guid), so ONE row above
-- the ceiling stops the server at boot with TCE00007.
-- An earlier revision of this file used guid + 20,000,000 / + 21,000,000 after
-- confirming those bands were "empty" — they are empty because they are
-- unusable. That took the server down; 67_fix_spawn_guid_overflow.sql repaired it.
-- A plain offset can never work: source guids reach 362,097 and the free space
-- starts at ~16.71M, so offsetting overshoots the ceiling. Guids are therefore
-- ALLOCATED SEQUENTIALLY into the remaining space and the mapping is kept in
-- `dc_map751_spawn_guid` for later files to join.
-- ###########################################################################
--
-- Map 751 preserves Eastern Kingdoms world coordinates, so x/y/z transfer 1:1.
-- Heights were proven byte-identical to the live map on every shared tile.
--
-- ZONE is resolved from the retagged terrain, not copied from the source: chunk
-- precision on the mixed tiles, tile precision on the uniform ones. A spawn that
-- resolves to NEITHER lookup is outside the 195-tile footprint and is skipped —
-- the join filter doubles as the footprint filter.
--
-- Two deliberate downgrades:
--   * MovementType 2 (waypoint) -> 0. 90 source spawns; a waypoint spawn with no
--     waypoint_data path fails to load. Restore with the waypoint import.
--   * PhaseId / PhaseGroup dropped (cata keeps phaseMask=1 here and phases through
--     PhaseId, which 3.3.5 has no equivalent for), so phased storyline variants are
--     all visible at once. Known.
--
-- cata marks npcflag/unit_flags NULLable and means "inherit from template"; acore
-- makes them NOT NULL and means the same thing with 0
-- (ObjectMgr::ChooseCreatureFlags -> `if (data->npcflag) ...`), so COALESCE(...,0)
-- is the faithful translation. ALL 9,671 source rows are NULL there.
--
-- Deletes key on the ENTRY band (stable) rather than a guid band, so re-running is
-- safe whatever guids were used last time.

SET @COFF := 4100000;
SET @GOFF := 4600000;

-- ---------------------------------------------------------------------------
-- Clear any previous run of THIS import
-- ---------------------------------------------------------------------------
DELETE a FROM `creature_addon` a JOIN `creature` c ON c.`guid` = a.`guid`
  WHERE c.`map` = 751 AND c.`id` BETWEEN 4100000 AND 4199999;
DELETE FROM `creature`   WHERE `map` = 751 AND `id` BETWEEN 4100000 AND 4199999;
DELETE FROM `gameobject` WHERE `map` = 751 AND `id` BETWEEN 4600000 AND 4899999;

-- ---------------------------------------------------------------------------
-- Allocate guids sequentially in the space still free under 0xFFFFFF.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map751_spawn_guid`;
CREATE TABLE `dc_map751_spawn_guid` (
  `kind`     ENUM('c','g') NOT NULL,
  `src_guid` INT UNSIGNED NOT NULL,
  `old_guid` INT UNSIGNED NOT NULL DEFAULT 0,
  `new_guid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`kind`,`src_guid`),
  UNIQUE KEY `uk_new` (`kind`,`new_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET @cbase := (SELECT IFNULL(MAX(`guid`),0) FROM `creature`);
SET @gbase := (SELECT IFNULL(MAX(`guid`),0) FROM `gameobject`);

INSERT INTO `dc_map751_spawn_guid` (`kind`,`src_guid`,`new_guid`)
SELECT 'c', c.`guid`, @cbase + ROW_NUMBER() OVER (ORDER BY c.`guid`)
FROM `cata_world`.`creature` c
JOIN `dc_map751_src_creature` s ON s.`id` = c.`id`
LEFT JOIN `dc_map751_chunkzone` z
       ON z.`col`  = FLOOR(32 - c.`position_y`/533.3333333)
      AND z.`row`  = FLOOR(32 - c.`position_x`/533.3333333)
      AND z.`xsub` = FLOOR((32 - c.`position_x`/533.3333333 - z.`row`)*16)
      AND z.`ysub` = FLOOR((32 - c.`position_y`/533.3333333 - z.`col`)*16)
LEFT JOIN `dc_map751_tilezone` u
       ON u.`col`  = FLOOR(32 - c.`position_y`/533.3333333)
      AND u.`row`  = FLOOR(32 - c.`position_x`/533.3333333)
WHERE c.`map` = 0 AND c.`zoneId` IN (85,1497,130,267,47,45,4706)
  AND COALESCE(z.`zone`, u.`zone`) IS NOT NULL;

INSERT INTO `dc_map751_spawn_guid` (`kind`,`src_guid`,`new_guid`)
SELECT 'g', g.`guid`, @gbase + ROW_NUMBER() OVER (ORDER BY g.`guid`)
FROM `cata_world`.`gameobject` g
JOIN `dc_map751_src_gameobject` s ON s.`id` = g.`id`
LEFT JOIN `dc_map751_chunkzone` z
       ON z.`col`  = FLOOR(32 - g.`position_y`/533.3333333)
      AND z.`row`  = FLOOR(32 - g.`position_x`/533.3333333)
      AND z.`xsub` = FLOOR((32 - g.`position_x`/533.3333333 - z.`row`)*16)
      AND z.`ysub` = FLOOR((32 - g.`position_y`/533.3333333 - z.`col`)*16)
LEFT JOIN `dc_map751_tilezone` u
       ON u.`col`  = FLOOR(32 - g.`position_y`/533.3333333)
      AND u.`row`  = FLOOR(32 - g.`position_x`/533.3333333)
WHERE g.`map` = 0 AND g.`zoneId` IN (85,1497,130,267,47,45,4706)
  AND COALESCE(z.`zone`, u.`zone`) IS NOT NULL;

-- HARD STOP if the allocation would cross the ceiling. Inspect these before going on.
SELECT 'ABORT: allocation exceeds 0xFFFFFF' AS check_this, `kind`, COUNT(*) AS n
FROM `dc_map751_spawn_guid` WHERE `new_guid` > 16777214 GROUP BY `kind`;

-- ---------------------------------------------------------------------------
-- creature spawns
-- ---------------------------------------------------------------------------
INSERT INTO `creature`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
   `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,
   `wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,
   `npcflag`,`unit_flags`,`ScriptName`,`VerifiedBuild`,`Comment`)
SELECT
  mg.`new_guid`, c.`id` + @COFF, 751,
  COALESCE(z.`zone`, u.`zone`), COALESCE(z.`zone`, u.`zone`),
  IF(c.`spawnMask` = 0, 1, c.`spawnMask`), 1, c.`equipment_id`,
  c.`position_x`, c.`position_y`, c.`position_z`, c.`orientation`,
  c.`spawntimesecs`, c.`wander_distance`, 0, c.`curhealth`, c.`curmana`,
  IF(c.`MovementType` = 2, 0, c.`MovementType`),
  COALESCE(c.`npcflag`, 0), COALESCE(c.`unit_flags`, 0),
  COALESCE(c.`ScriptName`, ''), COALESCE(c.`VerifiedBuild`, 0),
  'Lordaeron-ext'
FROM `cata_world`.`creature` c
JOIN `dc_map751_spawn_guid` mg ON mg.`kind` = 'c' AND mg.`src_guid` = c.`guid`
LEFT JOIN `dc_map751_chunkzone` z
       ON z.`col`  = FLOOR(32 - c.`position_y`/533.3333333)
      AND z.`row`  = FLOOR(32 - c.`position_x`/533.3333333)
      AND z.`xsub` = FLOOR((32 - c.`position_x`/533.3333333 - z.`row`)*16)
      AND z.`ysub` = FLOOR((32 - c.`position_y`/533.3333333 - z.`col`)*16)
LEFT JOIN `dc_map751_tilezone` u
       ON u.`col`  = FLOOR(32 - c.`position_y`/533.3333333)
      AND u.`row`  = FLOOR(32 - c.`position_x`/533.3333333);

-- per-guid addon; same unpacked->packed byte conversion as 62_
-- (Creature.cpp:2763-2797). path_id stays 0 until waypoint_data exists.
INSERT INTO `creature_addon`
  (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`)
SELECT
  mg.`new_guid`, 0, a.`mount`,
  a.`StandState`  + a.`VisFlags` * 65536 + a.`AnimTier` * 16777216,
  a.`SheathState` + a.`PvPFlags` * 256,
  a.`emote`,
  COALESCE(a.`visibilityDistanceType`, 0),
  COALESCE(a.`auras`, '')
FROM `cata_world`.`creature_addon` a
JOIN `dc_map751_spawn_guid` mg ON mg.`kind` = 'c' AND mg.`src_guid` = a.`guid`;

-- ---------------------------------------------------------------------------
-- gameobject spawns
-- ---------------------------------------------------------------------------
INSERT INTO `gameobject`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,
   `position_x`,`position_y`,`position_z`,`orientation`,
   `rotation0`,`rotation1`,`rotation2`,`rotation3`,
   `spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`)
SELECT
  mg.`new_guid`, g.`id` + @GOFF, 751,
  COALESCE(z.`zone`, u.`zone`), COALESCE(z.`zone`, u.`zone`),
  IF(g.`spawnMask` = 0, 1, g.`spawnMask`), 1,
  g.`position_x`, g.`position_y`, g.`position_z`, g.`orientation`,
  g.`rotation0`, g.`rotation1`, g.`rotation2`, g.`rotation3`,
  g.`spawntimesecs`, g.`animprogress`, g.`state`,
  COALESCE(g.`ScriptName`, ''), COALESCE(g.`VerifiedBuild`, 0)
FROM `cata_world`.`gameobject` g
JOIN `dc_map751_spawn_guid` mg ON mg.`kind` = 'g' AND mg.`src_guid` = g.`guid`
LEFT JOIN `dc_map751_chunkzone` z
       ON z.`col`  = FLOOR(32 - g.`position_y`/533.3333333)
      AND z.`row`  = FLOOR(32 - g.`position_x`/533.3333333)
      AND z.`xsub` = FLOOR((32 - g.`position_x`/533.3333333 - z.`row`)*16)
      AND z.`ysub` = FLOOR((32 - g.`position_y`/533.3333333 - z.`col`)*16)
LEFT JOIN `dc_map751_tilezone` u
       ON u.`col`  = FLOOR(32 - g.`position_y`/533.3333333)
      AND u.`row`  = FLOOR(32 - g.`position_x`/533.3333333);

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT `zoneId`, COUNT(*) AS creatures FROM `creature`
WHERE `map` = 751 AND `id` BETWEEN 4100000 AND 4199999 GROUP BY `zoneId` ORDER BY creatures DESC;

SELECT 'creature spawns'   AS what, COUNT(*) AS n FROM `creature`   WHERE `map` = 751 AND `id` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'gameobject spawns', COUNT(*) FROM `gameobject` WHERE `map` = 751 AND `id` BETWEEN 4600000 AND 4899999
UNION ALL SELECT 'PROBLEM: any guid over 0xFFFFFF', (SELECT COUNT(*) FROM `creature` WHERE `guid` > 16777215) + (SELECT COUNT(*) FROM `gameobject` WHERE `guid` > 16777215)
UNION ALL SELECT 'PROBLEM: creature spawn with no template', (SELECT COUNT(*) FROM `creature` c LEFT JOIN `creature_template` t ON t.`entry` = c.`id` WHERE c.`map` = 751 AND c.`id` BETWEEN 4100000 AND 4199999 AND t.`entry` IS NULL)
UNION ALL SELECT 'PROBLEM: MovementType=2 without a path', (SELECT COUNT(*) FROM `creature` c LEFT JOIN `creature_addon` a ON a.`guid` = c.`guid` WHERE c.`map` = 751 AND c.`id` BETWEEN 4100000 AND 4199999 AND c.`MovementType` = 2 AND COALESCE(a.`path_id`,0) = 0)
UNION ALL SELECT 'PROBLEM: spawn on a zone we never created', (SELECT COUNT(*) FROM `creature` WHERE `map` = 751 AND `id` BETWEEN 4100000 AND 4199999 AND `zoneId` NOT IN (4924,4932,4933,4935,4936,4937,4938,4939))
UNION ALL SELECT 'guid headroom left below 0xFFFFFF (creature)', 16777215 - (SELECT MAX(`guid`) FROM `creature`)
UNION ALL SELECT 'guid headroom left below 0xFFFFFF (gameobject)', 16777215 - (SELECT MAX(`guid`) FROM `gameobject`);
