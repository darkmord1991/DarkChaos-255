-- =====================================================================
-- FIX: "GameObject spawn id overflow!! ... TCE00007" at worldserver start
-- =====================================================================
-- RUN THIS NOW. The server will not boot without it.
--
-- Cause
-- -----
-- `gameobject`.`guid` and `creature`.`guid` are **AUTO_INCREMENT** in this
-- database, and both counters have drifted far above AzerothCore's hard cap
-- for STATIC spawn ids:
--
--     ObjectMgr.cpp:7679   if (_gameObjectSpawnId >= uint32(0xFFFFFF))  -> 16777215
--     ObjectMgr.cpp:7669   if (_creatureSpawnId   >= uint32(0xFFFFFF))  -> 16777215
--
--     gameobject AUTO_INCREMENT = 21231996
--     creature   AUTO_INCREMENT = 20362098
--
-- `03_naxx40_gameobjects.sql` inserts the Naxx40 entrance teleporter WITHOUT a
-- `guid` column, so MySQL auto-assigned **21231998** - above the cap.
-- `ObjectMgr::SetHighestGuids()` seeds `_gameObjectSpawnId` from
-- `MAX(guid) FROM gameobject`, so the very first call to
-- `GenerateGameObjectSpawnId()` trips the check and calls `World::StopNow()`.
--
-- Exactly ONE row is affected. Verified: no `pool_gameobject`,
-- `gameobject_addon`, `game_event_gameobject`, `spawn_group` or
-- `linked_respawn` row references it, so a plain guid change is safe.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Move the Naxx40 teleporter to an explicit guid below the cap.
--    16500000-16777214 is empty (verified); the next highest gameobject
--    guid in the whole table is 16403706.
-- ---------------------------------------------------------------------
UPDATE `gameobject` SET `guid` = 16500000
 WHERE `guid` = 21231998 AND `id` = 361001;

-- ---------------------------------------------------------------------
-- 2. Pull both AUTO_INCREMENT counters back below 0xFFFFFF.
--    Without this, ANY future INSERT into `gameobject` or `creature` that
--    omits `guid` - from any pipeline, not just naxx40 - produces another
--    server-killing guid. MySQL only allows setting the counter to
--    MAX(guid)+1 or higher, so run these AFTER step 1.
-- ---------------------------------------------------------------------
ALTER TABLE `gameobject` AUTO_INCREMENT = 16500001;
ALTER TABLE `creature`   AUTO_INCREMENT = 16721763;

-- ---------------------------------------------------------------------
-- 3. Verification - all four must come back clean
-- ---------------------------------------------------------------------
-- SELECT MAX(guid) FROM gameobject;                       -- expect 16500000  (< 16777215)
-- SELECT MAX(guid) FROM creature;                         -- expect 16721762  (< 16777215)
-- SELECT COUNT(*) FROM gameobject WHERE guid >= 16777215; -- expect 0
-- SELECT COUNT(*) FROM creature   WHERE guid >= 16777215; -- expect 0
-- SELECT AUTO_INCREMENT FROM information_schema.TABLES
--   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('gameobject','creature');

-- ---------------------------------------------------------------------
-- Headroom note
-- ---------------------------------------------------------------------
-- After this fix:
--   gameobject  MAX 16500000 -> 277,215 guids left below the cap
--   creature    MAX 16721762 ->  55,453 guids left below the cap
-- The creature band is TIGHT. Map 751 already consumed up to 16721762, so the
-- next large creature import needs a compaction pass, not another high band.
