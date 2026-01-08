-- ============================================================================
-- Guild House Spawn Cleanup (Post-Phase Migration)
-- ============================================================================
-- Run this AFTER the phase migration to remove orphaned spawns that used
-- the old phase formula (guildId + 10).
--
-- This script removes creatures and gameobjects on the guild house maps
-- that have phase values in the old range (11-999+) which are NOT valid
-- power-of-2 values.
--
-- Valid power-of-2 phases for guild houses: 16, 32, 64, 128, 256, 512, 1024, 
-- 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576,
-- 2097152, 4194304, 8388608, 16777216, 33554432, 67108864, 134217728,
-- 268435456, 536870912, 1073741824
-- ============================================================================

-- Delete old-formula spawns on GM Island (map 1) and any other guild house map
-- These are spawns with phaseMask > 1 that are NOT power-of-2 values

-- First, identify the valid power-of-2 phases (bits 4-30)
-- A number is power-of-2 if (n & (n-1)) == 0 and n > 0
-- And for guild houses, must be >= 16 (bit 4)

-- Cleanup creatures with invalid (old) phases on guild house map
DELETE FROM `creature` 
WHERE `map` = 1 
  AND `phaseMask` > 1 
  AND `phaseMask` < 16;  -- Old formula phases (guildId + 10) would be 11, 12, 13, etc.

DELETE FROM `creature` 
WHERE `map` = 1 
  AND `phaseMask` >= 16
  AND (`phaseMask` & (`phaseMask` - 1)) != 0;  -- Not a power of 2

-- Cleanup gameobjects with invalid (old) phases on guild house map
DELETE FROM `gameobject` 
WHERE `map` = 1 
  AND `phaseMask` > 1 
  AND `phaseMask` < 16;

DELETE FROM `gameobject` 
WHERE `map` = 1 
  AND `phaseMask` >= 16
  AND (`phaseMask` & (`phaseMask` - 1)) != 0;  -- Not a power of 2

-- Also clean up addon tables
DELETE ca FROM `creature_addon` ca
LEFT JOIN `creature` c ON ca.guid = c.guid
WHERE c.guid IS NULL;

DELETE ga FROM `gameobject_addon` ga
LEFT JOIN `gameobject` g ON ga.guid = g.guid
WHERE g.guid IS NULL;
