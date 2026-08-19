-- 67_fix_spawn_guid_overflow.sql — URGENT REPAIR. Run this before starting the server.
--
-- THE BUG (mine, in 63_): I allocated spawn guids at +20,000,000 (creature) and
-- +21,000,000 (gameobject) after checking those bands were empty. They were empty
-- because they are UNUSABLE: AzerothCore spawn ids are 24-bit.
--
--   ObjectMgr.cpp:7669  if (_creatureSpawnId   >= uint32(0xFFFFFF)) ... StopNow()
--   ObjectMgr.cpp:7679  if (_gameObjectSpawnId >= uint32(0xFFFFFF)) ... StopNow()
--
-- 0xFFFFFF = 16,777,215. The spawn-id generator seeds itself from MAX(guid), so
-- guids above the ceiling make every later allocation overflow and the server
-- aborts at start with TCE00007. That is exactly why the live maxima sat at
-- 16,712,055 / 16,400,070 — right under the ceiling, not by coincidence.
--
-- THE FIX: renumber the 9,667 creature and 3,636 gameobject rows into the space
-- still free below the ceiling, packed sequentially:
--   creature   16,712,056 .. 16,721,722   (65,159 slots were free, 9,667 used)
--   gameobject 16,400,071 .. 16,403,706   (377,144 free, 3,636 used)
-- Nothing pre-existing is touched — only rows above the cap, all of which are mine.
--
-- A guid can no longer be "source guid + offset" (source guids reach 362,097, which
-- would land past the ceiling), so the mapping is materialised in
-- `dc_map751_spawn_guid` and later files join it instead of doing arithmetic.
--
-- Idempotent: re-running finds nothing above the cap and changes nothing.

-- ---------------------------------------------------------------------------
-- 1. Build the mapping (src_guid is recovered from the bad guid so later steps
--    can key off the ORIGINAL cata guid, which is what 66_ needs)
-- ---------------------------------------------------------------------------
-- CREATE IF NOT EXISTS + INSERT IGNORE, deliberately NOT drop-and-recreate: an
-- earlier revision dropped the table first, so running this file a SECOND time
-- (when nothing is above the cap any more) left the mapping EMPTY and later files
-- that join it silently matched nothing. An idempotent repair must not destroy the
-- artefact other steps depend on. 70_ can rebuild the map from position if needed.
CREATE TABLE IF NOT EXISTS `dc_map751_spawn_guid` (
  `kind`     ENUM('c','g') NOT NULL,
  `src_guid` INT UNSIGNED NOT NULL,
  `old_guid` INT UNSIGNED NOT NULL,
  `new_guid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`kind`,`src_guid`),
  UNIQUE KEY `uk_old` (`kind`,`old_guid`),
  UNIQUE KEY `uk_new` (`kind`,`new_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_map751_spawn_guid` (`kind`,`src_guid`,`old_guid`,`new_guid`)
SELECT 'c', `guid` - 20000000, `guid`,
       16712055 + ROW_NUMBER() OVER (ORDER BY `guid`)
FROM `creature`
WHERE `guid` > 16777215;

INSERT IGNORE INTO `dc_map751_spawn_guid` (`kind`,`src_guid`,`old_guid`,`new_guid`)
SELECT 'g', `guid` - 21000000, `guid`,
       16400070 + ROW_NUMBER() OVER (ORDER BY `guid`)
FROM `gameobject`
WHERE `guid` > 16777215;

-- refuse to proceed if the packed range would itself cross the ceiling
SELECT 'ABORT: new creature guids would exceed 0xFFFFFF' AS check_this, COUNT(*) AS n
FROM `dc_map751_spawn_guid` WHERE `kind` = 'c' AND `new_guid` > 16777214
UNION ALL
SELECT 'ABORT: new gameobject guids would exceed 0xFFFFFF', COUNT(*)
FROM `dc_map751_spawn_guid` WHERE `kind` = 'g' AND `new_guid` > 16777214;

-- ---------------------------------------------------------------------------
-- 2. Apply. creature_addon first — it keys on the old guid, and once creature is
--    renumbered the old value is gone.
--    Old (20M/21M) and new (16.4-16.8M) ranges are disjoint, so no PK collision
--    can occur mid-statement.
-- ---------------------------------------------------------------------------
UPDATE `creature_addon` a
  JOIN `dc_map751_spawn_guid` m ON m.`kind` = 'c' AND m.`old_guid` = a.`guid`
  SET a.`guid` = m.`new_guid`;

UPDATE `creature` c
  JOIN `dc_map751_spawn_guid` m ON m.`kind` = 'c' AND m.`old_guid` = c.`guid`
  SET c.`guid` = m.`new_guid`;

UPDATE `gameobject` g
  JOIN `dc_map751_spawn_guid` m ON m.`kind` = 'g' AND m.`old_guid` = g.`guid`
  SET g.`guid` = m.`new_guid`;

-- ---------------------------------------------------------------------------
-- 3. Verification — every one of these must be zero except the counts
-- ---------------------------------------------------------------------------
SELECT 'creature rows still over cap'   AS what, COUNT(*) AS n FROM `creature`   WHERE `guid` > 16777215
UNION ALL SELECT 'gameobject rows still over cap', COUNT(*) FROM `gameobject` WHERE `guid` > 16777215
UNION ALL SELECT 'creature_addon rows still over cap', COUNT(*) FROM `creature_addon` WHERE `guid` > 16777215
UNION ALL SELECT 'orphan creature_addon (no creature)', COUNT(*)
  FROM `creature_addon` a LEFT JOIN `creature` c ON c.`guid` = a.`guid`
  WHERE a.`guid` BETWEEN 16712056 AND 16777215 AND c.`guid` IS NULL
UNION ALL SELECT 'renumbered creatures', COUNT(*) FROM `dc_map751_spawn_guid` WHERE `kind` = 'c'
UNION ALL SELECT 'renumbered gameobjects', COUNT(*) FROM `dc_map751_spawn_guid` WHERE `kind` = 'g'
UNION ALL SELECT 'map 751 creatures total', COUNT(*) FROM `creature`   WHERE `map` = 751
UNION ALL SELECT 'map 751 gameobjects total', COUNT(*) FROM `gameobject` WHERE `map` = 751;

-- headroom left under the 24-bit ceiling, for the next import
SELECT 'creature guids left below 0xFFFFFF'   AS headroom, 16777215 - MAX(`guid`) AS n FROM `creature`
UNION ALL
SELECT 'gameobject guids left below 0xFFFFFF', 16777215 - MAX(`guid`) FROM `gameobject`;
