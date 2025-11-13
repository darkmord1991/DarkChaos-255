-- ============================================================================
-- Check existing spawnMask values for WotLK dungeons and raids
-- ============================================================================
-- Run this query to see what spawnMask values currently exist in the database

-- WotLK Dungeons
SELECT 
    'DUNGEON' as type,
    map,
    CASE map
        WHEN 574 THEN 'Utgarde Keep'
        WHEN 575 THEN 'Utgarde Pinnacle'
        WHEN 576 THEN 'The Nexus'
        WHEN 578 THEN 'The Oculus'
        WHEN 595 THEN 'Culling of Stratholme'
        WHEN 599 THEN 'Halls of Stone'
        WHEN 600 THEN 'Drak\'Tharon Keep'
        WHEN 601 THEN 'Azjol-Nerub'
        WHEN 602 THEN 'Halls of Lightning'
        WHEN 604 THEN 'Gundrak'
        WHEN 608 THEN 'Violet Hold'
        WHEN 619 THEN 'Ahn\'kahet'
        WHEN 632 THEN 'Forge of Souls'
        WHEN 658 THEN 'Pit of Saron'
        WHEN 668 THEN 'Halls of Reflection'
        ELSE 'Unknown'
    END as dungeon_name,
    spawnMask,
    COUNT(*) as creature_count
FROM creature
WHERE map IN (574, 575, 576, 578, 595, 599, 600, 601, 602, 604, 608, 619, 632, 658, 668)
GROUP BY map, spawnMask
ORDER BY map, spawnMask;

-- WotLK Raids
SELECT 
    'RAID' as type,
    map,
    CASE map
        WHEN 249 THEN 'Onyxia\'s Lair'
        WHEN 603 THEN 'Ulduar'
        WHEN 615 THEN 'Obsidian Sanctum'
        WHEN 616 THEN 'Eye of Eternity'
        WHEN 624 THEN 'Vault of Archavon'
        WHEN 631 THEN 'Icecrown Citadel'
        WHEN 649 THEN 'Trial of the Crusader'
        WHEN 724 THEN 'Ruby Sanctum'
        ELSE 'Unknown'
    END as raid_name,
    spawnMask,
    COUNT(*) as creature_count
FROM creature
WHERE map IN (249, 603, 615, 616, 624, 631, 649, 724)
GROUP BY map, spawnMask
ORDER BY map, spawnMask;

-- ============================================================================
-- Expected Results Analysis:
-- ============================================================================
-- If you see spawnMask = 3 (Normal + Heroic) for WotLK dungeons:
--   - This means creatures already spawn in both difficulties
--   - Our UPDATE to 51 will add Mythic and Mythic+ support
--
-- If you see separate spawnMask values (1 for Normal, 2 for Heroic):
--   - This means different creatures spawn in different difficulties
--   - We need to be more careful with our UPDATE strategy
--
-- For raids, you might see:
--   - spawnMask = 1 (10-man Normal only)
--   - spawnMask = 2 (25-man Normal only)  
--   - spawnMask = 4 (10-man Heroic only)
--   - spawnMask = 8 (25-man Heroic only)
--   - Or combinations like 3, 5, 9, 12, 15, etc.
