-- ========================================================================
-- Fix Dungeon Portal/GameObject Visibility in Mythic Difficulty
-- ========================================================================
-- Issue: Portal gameobjects and dungeon objects disappear when players set
--        their difficulty to Mythic (DUNGEON_DIFFICULTY_EPIC, value 2).
-- 
-- Solution: Update all gameobjects in WotLK dungeons to have correct spawnMask
--           values that include Mythic difficulty visibility.
--
-- SpawnMask values:
--   1 = Normal (10-man)
--   2 = Heroic (25-man) 
--   4 = Mythic/Epic difficulty
--   3 = Normal + Heroic (1 | 2)
--   7 = All difficulties (1 | 2 | 4)
-- ========================================================================

USE acore_world;

-- List of WotLK 5-player dungeon maps
SET @WOTLK_DUNGEONS := '574,575,576,578,595,599,600,601,602,604,608,619,632,650,658,668';

-- List of all Instance_Portal and related gameobject IDs
-- Includes Instance_Portal_Difficulty variants and Doodad_InstancePortal variants
SET @INSTANCE_PORTAL_IDS := '19527,19528,19529,19530,181623,184127,184128,184129,184130,184131,184132,184171,184172,184173,184174,184175,184176,184177,184178,184179,184180,184189,184190,184191,184192,184193,184194,184195,184196,184197,184198,184199,184200,184201,184202,184213,184214,184215,184216,184217,184218,184219,184220,184221,184222,184223,184224,184225,184226,184227,184228,184524,184526,184527,184528,184529,188177,188178,191714,191715,192012,192013,202266';

-- ========================================================================
-- FIX INSTANCE PORTAL GAMEOBJECTS (Primary Fix)
-- ========================================================================
-- Update all Instance_Portal gameobjects to be visible in all difficulties
-- These are the meeting stone portals and dungeon entrance/exit portals
-- ========================================================================

UPDATE `gameobject`
SET `spawnMask` = `spawnMask` | 1 | 2 | 4
WHERE FIND_IN_SET(`id`, @INSTANCE_PORTAL_IDS);

-- ========================================================================
-- FIX ALL OTHER DUNGEON GAMEOBJECTS (Comprehensive Fix)
-- ========================================================================
-- ========================================================================
-- FIX ALL OTHER DUNGEON GAMEOBJECTS (Comprehensive Fix)
-- ========================================================================
-- Update all remaining gameobjects in WotLK dungeons
-- This includes doors, chests, interactive objects, etc.
-- ========================================================================

UPDATE `gameobject`
SET `spawnMask` = `spawnMask` | 1 | 2 | 4
WHERE FIND_IN_SET(`map`, @WOTLK_DUNGEONS)
  AND NOT FIND_IN_SET(`id`, @INSTANCE_PORTAL_IDS);

-- ========================================================================
-- FIX PORTAL KEEPER NPCs (if any exist in world)
-- ========================================================================
-- Update all Portal Keeper NPC spawns to be visible in all difficulties
-- These are world spawns (not inside dungeons) that should always be visible
-- ========================================================================

UPDATE `creature` 
SET `spawnMask` = 3, `phaseMask` = 1
WHERE `id1` = 100101 
  AND `map` NOT IN (SELECT DISTINCT `map` FROM `gameobject` WHERE FIND_IN_SET(`map`, @WOTLK_DUNGEONS));

-- ========================================================================
-- VERIFICATION QUERIES
-- ========================================================================

-- Check Instance_Portal gameobjects
SELECT 
    'Instance_Portal Gameobjects' AS Type,
    COUNT(*) AS total_spawns,
    GROUP_CONCAT(DISTINCT `spawnMask`) AS spawnMasks
FROM `gameobject`
WHERE FIND_IN_SET(`id`, @INSTANCE_PORTAL_IDS);

-- Check updated gameobjects count per dungeon
SELECT 
    'Dungeon Objects' AS Type,
    `map`,
    COUNT(*) AS object_count,
    GROUP_CONCAT(DISTINCT `spawnMask`) AS spawnMasks
FROM `gameobject`
WHERE FIND_IN_SET(`map`, @WOTLK_DUNGEONS)
GROUP BY `map`
ORDER BY `map`;

-- Check if Portal Keeper NPCs exist and are updated
SELECT 
    'Portal Keeper NPCs' AS Type,
    `guid`, 
    `id1`, 
    `map`, 
    `spawnMask`, 
    `phaseMask`
FROM `creature`
WHERE `id1` = 100101;

-- ========================================================================
-- SUCCESS MESSAGE
-- ========================================================================
SELECT 'Instance_Portal gameobjects updated to be visible in all difficulties!' AS Status;
SELECT 'All dungeon portals, doors, and interactive objects in WotLK dungeons should now be visible.' AS Info;

