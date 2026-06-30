-- =====================================================================
-- Deepholm Downport  --  37  Creature spawnMask regression fix
-- ---------------------------------------------------------------------
-- File 34 changed creature spawnMask 1→0 to silence "wrong spawnMask"
-- boot warnings. This was wrong: those warnings are cosmetic (the
-- creature LOAD path only logs a debug message for mismatched masks).
-- The SPAWN path checks  spawnMask & (1 << difficulty).  Map 646 is an
-- open-world map whose effective difficulty is 0, so it needs bit 0 set
-- (mask = 1).  spawnMask=0 passes the load warning check but fails the
-- spawn check → the creature is silently not spawned.
--
-- Distinct behaviour for game objects (explained in 33/34): AC's GO
-- loader hard-skips any GO whose spawnMask has bits outside the map's
-- allowed mask.  For map 646, GetSpawnMask()=0, so a GO with spawnMask=1
-- is SKIPPED.  GOs therefore correctly keep spawnMask=0.
--
-- Fix: restore spawnMask=1 for all Neltharion creature spawns on map 646.
-- The ~3 269 "wrong spawnMask" warnings at boot are acceptable: they are
-- DEBUG-level and the creatures will be visible in the world.
-- =====================================================================

UPDATE `creature`
SET    `spawnMask` = 1
WHERE  `map` = 646
  AND  `guid` >= 9500000
  AND  `spawnMask` = 0;
