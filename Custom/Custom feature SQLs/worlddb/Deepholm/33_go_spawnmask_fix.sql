-- =====================================================================
-- Deepholm Downport  --  33  GO spawnMask fix
-- ---------------------------------------------------------------------
-- AzerothCore's LoadGameObjects() hard-skips any GO whose spawnMask has
-- bits outside GetSpawnMask(mapId). For map 646 that supported set is 0
-- (no difficulty entries), so only spawnMask=0 ("spawn always") loads.
--
-- Most Neltharion map-646 GOs were already spawnMask=0.  A subset of
-- environmental decoration entries (202747, 202750, 202778, 203748-50,
-- 204045, 204253, 204274, 204296) were spawnMask=1, causing the server
-- to skip them entirely on load with:
--   "has wrong spawn mask 1 including not supported difficulty modes for
--    map (Id: 646), skip"
--
-- Fix: set spawnMask=0 for all map-646 GOs in our guid block.
-- gen_neltharion_spawns.py is also patched to hardcode 0 so a
-- regeneration of 30 won't reintroduce the problem.
-- =====================================================================

UPDATE `gameobject`
SET    `spawnMask` = 0
WHERE  `map` = 646
  AND  `guid` >= 9600000
  AND  `spawnMask` != 0;

-- Verify: no affected GOs should remain after this.
-- SELECT COUNT(*) FROM `gameobject` WHERE `map`=646 AND `guid`>=9600000 AND `spawnMask`!=0;
-- Expected: 0 rows.
