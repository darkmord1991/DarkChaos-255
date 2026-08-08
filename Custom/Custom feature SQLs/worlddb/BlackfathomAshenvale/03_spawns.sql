-- =====================================================================================
-- Blackfathom Deeps (Ashenvale) -- map 820 clone, step 3: spawns
--
-- Copies map 48's 212 creature and 50 gameobject spawns onto map 820 at identical
-- coordinates (the clone shares map 48's `Blackfathom` terrain directory, so every
-- position is valid unchanged) and repoints them at the cloned templates.
--
-- Run AFTER 01_templates.sql. Re-runnable.
--
-- ------------------------------------------------------------------------------------
-- GUID ALLOCATION -- read before changing these numbers.
--
-- Spawn guids are 24-BIT. Both generators abort the server at startup once the highest
-- guid reaches 0xFFFFFF = 16,777,215:
--     ObjectMgr::GenerateCreatureSpawnId()    ObjectMgr.cpp:7667
--     ObjectMgr::GenerateGameObjectSpawnId()  ObjectMgr.cpp:7677
--
-- The first version of this file used `source_guid + 16,700,000`. Map 48's gameobject
-- guids are sparse and reach 268,936, so the clone landed at 16,968,936 -- past the
-- ceiling, and the server refused to boot with TCE00007. A constant offset also burns as
-- much guid space as the SOURCE range is wide (269k for 50 objects), which is reckless
-- with a 24-bit budget.
--
-- So the guids are now allocated DENSELY: 50 gameobject guids and 212 creature guids,
-- numbered in source-guid order from a base. The mapping stays deterministic and is
-- rebuilt identically in 02_support_tables.sql, which needs it for two SmartAI rows that
-- reference gameobjects by spawn guid.
--
--   gameobject  16,340,000 + 0..49    (highest non-820 gameobject guid was 16,331,741)
--   creature    16,620,000 + 0..211   (highest non-820 creature guid was 16,614,473)
--   05_cata_npc_layer.sql continues the creature block at 16,621,000.
-- ------------------------------------------------------------------------------------

SET @MAP_DST := 820;
SET @C_OFF := 3900000;
SET @G_OFF := 4400000;
SET @GO_GUID_BASE := 16340000;
SET @CRE_GUID_BASE := 16620000;

-- -------------------------------------------------------------------------------------
-- Clear any previous run FIRST -- this is what removes the over-cap rows left by the
-- original offset scheme, so re-running this file is also the repair.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (SELECT `guid` FROM `creature` WHERE `map` = @MAP_DST);
DELETE FROM `creature` WHERE `map` = @MAP_DST;
DELETE FROM `gameobject` WHERE `map` = @MAP_DST;
-- belt and braces for the abandoned +16,700,000 block
DELETE FROM `creature_addon` WHERE `guid` BETWEEN 16700000 AND 16999999;

-- -------------------------------------------------------------------------------------
-- Deterministic dense guid maps (same construction as in 02_support_tables.sql)
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_gomap;
CREATE TEMPORARY TABLE tmp_bfd_gomap (old_guid INT UNSIGNED PRIMARY KEY, new_guid INT UNSIGNED);
INSERT INTO tmp_bfd_gomap (old_guid, new_guid)
SELECT t.guid, @GO_GUID_BASE + t.rn - 1 FROM (
    SELECT g.`guid`, ROW_NUMBER() OVER (ORDER BY g.`guid`) AS rn
    FROM `gameobject` g
    WHERE g.`map` = 48
      -- a static MO_TRANSPORT (type 15) cloned onto another map crashes the client;
      -- map 48 has none, the filter just stops a future edit reintroducing one
      AND g.`id` NOT IN (SELECT `entry` FROM `gameobject_template` WHERE `type` = 15)
) t;

DROP TEMPORARY TABLE IF EXISTS tmp_bfd_cmap;
CREATE TEMPORARY TABLE tmp_bfd_cmap (old_guid INT UNSIGNED PRIMARY KEY, new_guid INT UNSIGNED);
INSERT INTO tmp_bfd_cmap (old_guid, new_guid)
SELECT t.guid, @CRE_GUID_BASE + t.rn - 1 FROM (
    SELECT c.`guid`, ROW_NUMBER() OVER (ORDER BY c.`guid`) AS rn
    FROM `creature` c WHERE c.`map` = 48
) t;

-- -------------------------------------------------------------------------------------
-- creature spawns
-- zoneId/areaId are zeroed so the core resolves them from map 820's own terrain rather
-- than carrying map 48's cached ids.
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_c;
CREATE TEMPORARY TABLE tmp_bfd_c LIKE `creature`;
INSERT INTO tmp_bfd_c SELECT * FROM `creature` WHERE `map` = 48;
UPDATE tmp_bfd_c c JOIN tmp_bfd_cmap m ON m.old_guid = c.`guid` SET
    c.`guid`   = m.new_guid,
    c.`id`     = c.`id` + @C_OFF,
    c.`map`    = @MAP_DST,
    c.`zoneId` = 0,
    c.`areaId` = 0,
    c.`VerifiedBuild` = 0;
INSERT INTO `creature` SELECT * FROM tmp_bfd_c;

-- creature_addon is keyed by SPAWN guid, so it follows the same map or 41 spawns lose
-- their auras/emote state.
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ca;
CREATE TEMPORARY TABLE tmp_bfd_ca LIKE `creature_addon`;
INSERT INTO tmp_bfd_ca SELECT * FROM `creature_addon`
    WHERE `guid` IN (SELECT old_guid FROM tmp_bfd_cmap);
UPDATE tmp_bfd_ca a JOIN tmp_bfd_cmap m ON m.old_guid = a.`guid` SET a.`guid` = m.new_guid;
DELETE FROM `creature_addon` WHERE `guid` IN (SELECT `guid` FROM tmp_bfd_ca);
INSERT INTO `creature_addon` SELECT * FROM tmp_bfd_ca;

-- -------------------------------------------------------------------------------------
-- gameobject spawns
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_g;
CREATE TEMPORARY TABLE tmp_bfd_g LIKE `gameobject`;
INSERT INTO tmp_bfd_g SELECT * FROM `gameobject`
    WHERE `map` = 48 AND `guid` IN (SELECT old_guid FROM tmp_bfd_gomap);
UPDATE tmp_bfd_g g JOIN tmp_bfd_gomap m ON m.old_guid = g.`guid` SET
    g.`guid`   = m.new_guid,
    g.`id`     = g.`id` + @G_OFF,
    g.`map`    = @MAP_DST,
    g.`zoneId` = 0,
    g.`areaId` = 0,
    g.`VerifiedBuild` = 0;
INSERT INTO `gameobject` SELECT * FROM tmp_bfd_g;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'creature spawns (want 212)' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `creature` WHERE `map` = @MAP_DST
UNION ALL SELECT 'gameobject spawns (want 50)', CAST(COUNT(*) AS CHAR) FROM `gameobject` WHERE `map` = @MAP_DST
UNION ALL SELECT 'creature_addon rows', CAST(COUNT(*) AS CHAR) FROM `creature_addon` WHERE `guid` >= @CRE_GUID_BASE
UNION ALL SELECT 'highest creature guid (cap 16777215)', CAST(MAX(`guid`) AS CHAR) FROM `creature`
UNION ALL SELECT 'highest gameobject guid (cap 16777215)', CAST(MAX(`guid`) AS CHAR) FROM `gameobject`
UNION ALL SELECT 'spawns over the 24-bit cap (want 0)', CAST(
    (SELECT COUNT(*) FROM `creature` WHERE `guid` > 16777215)
  + (SELECT COUNT(*) FROM `gameobject` WHERE `guid` > 16777215) AS CHAR)
UNION ALL SELECT 'orphan spawns (want 0)', CAST(COUNT(*) AS CHAR) FROM `creature` c
    LEFT JOIN `creature_template` ct ON ct.`entry` = c.`id`
    WHERE c.`map` = @MAP_DST AND ct.`entry` IS NULL
UNION ALL SELECT 'orphan GO spawns (want 0)', CAST(COUNT(*) AS CHAR) FROM `gameobject` g
    LEFT JOIN `gameobject_template` gt ON gt.`entry` = g.`id`
    WHERE g.`map` = @MAP_DST AND gt.`entry` IS NULL
UNION ALL SELECT 'SmartAI GO-guid targets resolvable (want 2)', CAST(COUNT(*) AS CHAR) FROM `smart_scripts` s
    JOIN `gameobject` g ON g.`guid` = s.`target_param1` AND g.`id` = s.`target_param2`
    WHERE s.`source_type` = 0 AND s.`target_type` = 14 AND s.`entryorguid` >= @C_OFF;

DROP TEMPORARY TABLE IF EXISTS tmp_bfd_c;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_ca;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_g;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_gomap;
DROP TEMPORARY TABLE IF EXISTS tmp_bfd_cmap;
