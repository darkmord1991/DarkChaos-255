-- =====================================================================================
-- HOTFIX -- run this FIRST if the worldserver is refusing to start with
--   "GameObject spawn id overflow!! Can't continue, shutting down server. ... TCE00007"
--
-- Cause: the first version of 03_spawns.sql allocated map-820 spawn guids as
-- source_guid + 16,700,000. Map 48's gameobject guids run up to 268,936, so the clone
-- reached 16,968,936 -- past the hard 24-bit ceiling.
--
--   ObjectMgr::GenerateGameObjectSpawnId()  refuses at >= 0xFFFFFF = 16,777,215
--   ObjectMgr::GenerateCreatureSpawnId()    same ceiling
--
-- Both are 24-bit, and the check runs at startup, so the server stops before it finishes
-- loading. The creature block (max 16,760,030) stayed just under the cap but left only
-- 17,185 free creature spawn ids for the entire server, which is its own problem.
--
-- This file removes the bad rows so the server boots again. Then re-apply the corrected
-- 02_support_tables.sql, 03_spawns.sql and 05_cata_npc_layer.sql, which allocate densely
-- (50 gameobject and 243 creature guids instead of 269k and 145k).
-- =====================================================================================

DELETE FROM `gameobject` WHERE `map` = 820;
DELETE FROM `creature` WHERE `map` = 820;
DELETE FROM `creature_addon` WHERE `guid` BETWEEN 16700000 AND 16999999;

-- Both must now be well under 16,777,215.
SELECT 'gameobject max guid' AS `check`, CAST(MAX(`guid`) AS SIGNED) AS result FROM `gameobject`
UNION ALL SELECT 'creature max guid', CAST(MAX(`guid`) AS SIGNED) FROM `creature`
UNION ALL SELECT 'hard ceiling (0xFFFFFF)', 16777215
UNION ALL SELECT 'rows still over cap (want 0)',
    (SELECT COUNT(*) FROM `gameobject` WHERE `guid` > 16777215)
  + (SELECT COUNT(*) FROM `creature` WHERE `guid` > 16777215);
