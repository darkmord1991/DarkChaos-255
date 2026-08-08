-- =====================================================================================
-- Blackfathom Deeps (Ashenvale) -- map 820 clone, step 3: spawns
--
-- Copies map 48's 212 creature and 50 gameobject spawns onto map 820 at identical
-- coordinates (the clone shares map 48's `Blackfathom` terrain directory, so every
-- position is valid unchanged) and repoints them at the cloned templates.
--
-- Run AFTER 01_templates.sql. Re-runnable: the guid block is derived, not accumulated.
--
-- Guid offset +16,700,000 keeps both blocks clear of live data (creature max guid was
-- 16,614,473 and gameobject max 16,331,741 when this was written) and keeps the mapping
-- source_guid -> clone_guid deterministic, which 02_support_tables.sql relies on for the
-- two target_type 14 SmartAI rows.
--
-- spawnMask is carried over as 7 (difficulties 0|1|2 = normal|heroic|mythic), matching the
-- three MapDifficulty rows 9341/9342/9343 added for map 820.
-- =====================================================================================

SET @MAP_DST := 820;
SET @C_OFF := 3900000;
SET @G_OFF := 4400000;
SET @GUID_OFF := 16700000;

-- -------------------------------------------------------------------------------------
-- creature spawns
-- zoneId/areaId are zeroed so the core resolves them from map 820's own terrain rather
-- than carrying map 48's cached ids.
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_c;
CREATE TEMPORARY TABLE tmp_bfd_c LIKE `creature`;
INSERT INTO tmp_bfd_c SELECT * FROM `creature` WHERE `map` = 48;
UPDATE tmp_bfd_c SET
    `guid`   = `guid` + @GUID_OFF,
    `id`     = `id` + @C_OFF,
    `map`    = @MAP_DST,
    `zoneId` = 0,
    `areaId` = 0,
    `VerifiedBuild` = 0;
DELETE FROM `creature` WHERE `map` = @MAP_DST;
DELETE FROM `creature` WHERE `guid` IN (SELECT `guid` FROM tmp_bfd_c);
INSERT INTO `creature` SELECT * FROM tmp_bfd_c;

-- creature_addon is keyed by SPAWN guid, so it has to follow the same offset or 41 spawns
-- lose their auras/emote state.
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ca;
CREATE TEMPORARY TABLE tmp_bfd_ca LIKE `creature_addon`;
INSERT INTO tmp_bfd_ca SELECT * FROM `creature_addon`
    WHERE `guid` IN (SELECT `guid` FROM `creature` WHERE `map` = 48);
UPDATE tmp_bfd_ca SET `guid` = `guid` + @GUID_OFF;
DELETE FROM `creature_addon` WHERE `guid` IN (SELECT `guid` FROM tmp_bfd_ca);
INSERT INTO `creature_addon` SELECT * FROM tmp_bfd_ca;

-- -------------------------------------------------------------------------------------
-- gameobject spawns
--
-- Map 48 carries no GAMEOBJECT_TYPE_MO_TRANSPORT (type 15) object, so the HLBG 1411->1412
-- clone crash does not apply here -- but the guard is kept so a future edit to map 48
-- cannot reintroduce it silently.
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_g;
CREATE TEMPORARY TABLE tmp_bfd_g LIKE `gameobject`;
INSERT INTO tmp_bfd_g SELECT * FROM `gameobject`
    WHERE `map` = 48
      AND `id` NOT IN (SELECT `entry` FROM `gameobject_template` WHERE `type` = 15);
UPDATE tmp_bfd_g SET
    `guid`   = `guid` + @GUID_OFF,
    `id`     = `id` + @G_OFF,
    `map`    = @MAP_DST,
    `zoneId` = 0,
    `areaId` = 0,
    `VerifiedBuild` = 0;
DELETE FROM `gameobject` WHERE `map` = @MAP_DST;
DELETE FROM `gameobject` WHERE `guid` IN (SELECT `guid` FROM tmp_bfd_g);
INSERT INTO `gameobject` SELECT * FROM tmp_bfd_g;

-- -------------------------------------------------------------------------------------
-- Report -- the two SmartAI guid references from 02 must resolve on the clone
-- -------------------------------------------------------------------------------------
SELECT 'creature spawns'   AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `creature`   WHERE `map` = @MAP_DST
UNION ALL SELECT 'gameobject spawns', CAST(COUNT(*) AS CHAR) FROM `gameobject` WHERE `map` = @MAP_DST
UNION ALL SELECT 'creature_addon rows', CAST(COUNT(*) AS CHAR) FROM `creature_addon` WHERE `guid` >= @GUID_OFF
UNION ALL SELECT 'orphan spawns (must be 0)', CAST(COUNT(*) AS CHAR) FROM `creature` c
    LEFT JOIN `creature_template` ct ON ct.`entry` = c.`id`
    WHERE c.`map` = @MAP_DST AND ct.`entry` IS NULL
UNION ALL SELECT 'orphan GO spawns (must be 0)', CAST(COUNT(*) AS CHAR) FROM `gameobject` g
    LEFT JOIN `gameobject_template` gt ON gt.`entry` = g.`id`
    WHERE g.`map` = @MAP_DST AND gt.`entry` IS NULL
UNION ALL SELECT 'SmartAI GO-guid targets resolvable (want 2)', CAST(COUNT(*) AS CHAR) FROM `smart_scripts` s
    JOIN `gameobject` g ON g.`guid` = s.`target_param1` AND g.`id` = s.`target_param2`
    WHERE s.`source_type` = 0 AND s.`target_type` = 14 AND s.`entryorguid` >= @C_OFF;

DROP TEMPORARY TABLE IF EXISTS tmp_bfd_c;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ca;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_g;
