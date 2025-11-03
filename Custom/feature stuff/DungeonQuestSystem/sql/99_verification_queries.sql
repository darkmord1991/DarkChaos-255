-- ============================================
-- Dungeon Quest System - Verification Queries
-- Run these after importing all SQL files
-- ============================================

-- ============================================
-- 1. TABLE EXISTENCE CHECKS
-- ============================================
SELECT 'Checking table existence...' AS status;

SELECT 
    CASE 
        WHEN COUNT(*) = 1 THEN 'OK: dc_dungeon_quest_mapping table exists'
        ELSE 'ERROR: dc_dungeon_quest_mapping table NOT found'
    END AS table_check
FROM information_schema.tables 
WHERE table_schema = DATABASE() 
AND table_name = 'dc_dungeon_quest_mapping';

-- ============================================
-- 2. RECORD COUNT CHECKS
-- ============================================
SELECT 'Checking record counts...' AS status;

-- Should be 435
SELECT 
    COUNT(*) AS total_quests,
    CASE 
        WHEN COUNT(*) = 435 THEN 'OK: All 435 quests loaded'
        ELSE CONCAT('ERROR: Expected 435, found ', COUNT(*))
    END AS validation
FROM dc_dungeon_quest_mapping;

-- Quest starters (should be 435)
SELECT 
    COUNT(*) AS starter_count,
    CASE 
        WHEN COUNT(*) = 435 THEN 'OK: All quest starters linked'
        ELSE CONCAT('ERROR: Expected 435, found ', COUNT(*))
    END AS validation
FROM creature_queststarter 
WHERE id IN (700000, 700001, 700002);

-- Quest enders (should be 435)
SELECT 
    COUNT(*) AS ender_count,
    CASE 
        WHEN COUNT(*) = 435 THEN 'OK: All quest enders linked'
        ELSE CONCAT('ERROR: Expected 435, found ', COUNT(*))
    END AS validation
FROM creature_questender 
WHERE id IN (700000, 700001, 700002);

-- ============================================
-- 3. DATA INTEGRITY CHECKS
-- ============================================
SELECT 'Checking data integrity...' AS status;

-- Check for unmapped quests (should be 0)
SELECT 
    COUNT(*) AS unmapped_count,
    CASE 
        WHEN COUNT(*) = 0 THEN 'OK: All quests have valid map IDs'
        ELSE CONCAT('ERROR: ', COUNT(*), ' quests with map_id = 0')
    END AS validation
FROM dc_dungeon_quest_mapping 
WHERE map_id = 0;

-- Check for orphaned quest starters (should be 0)
SELECT 
    COUNT(*) AS orphaned_starters,
    CASE 
        WHEN COUNT(*) = 0 THEN 'OK: No orphaned quest starters'
        ELSE CONCAT('WARNING: ', COUNT(*), ' quest starters without mapping')
    END AS validation
FROM creature_queststarter cqs
LEFT JOIN dc_dungeon_quest_mapping dqm ON cqs.quest = dqm.quest_id
WHERE cqs.id IN (700000, 700001, 700002) 
AND dqm.quest_id IS NULL;

-- Check for duplicate quest IDs (should be 0)
SELECT 
    COUNT(*) AS duplicate_count,
    CASE 
        WHEN COUNT(*) = 0 THEN 'OK: No duplicate quest IDs'
        ELSE CONCAT('ERROR: ', COUNT(*), ' duplicate quest IDs found')
    END AS validation
FROM (
    SELECT quest_id, COUNT(*) as cnt
    FROM dc_dungeon_quest_mapping
    GROUP BY quest_id
    HAVING cnt > 1
) AS duplicates;

-- ============================================
-- 4. EXPANSION DISTRIBUTION
-- ============================================
SELECT 'Checking expansion distribution...' AS status;

SELECT 
    CASE 
        WHEN map_id < 500 THEN 'Classic'
        WHEN map_id < 570 THEN 'TBC'
        ELSE 'WotLK'
    END AS expansion,
    COUNT(*) AS quest_count,
    MIN(npc_entry) AS npc_entry,
    CASE 
        WHEN COUNT(*) = 341 AND map_id < 500 THEN 'OK'
        WHEN COUNT(*) = 37 AND map_id >= 500 AND map_id < 570 THEN 'OK'
        WHEN COUNT(*) = 57 AND map_id >= 570 THEN 'OK'
        ELSE 'WARNING: Count mismatch'
    END AS validation
FROM dc_dungeon_quest_mapping
GROUP BY expansion
ORDER BY MIN(map_id);

-- ============================================
-- 5. LEVEL TYPE DISTRIBUTION
-- ============================================
SELECT 'Checking level type distribution...' AS status;

SELECT 
    level_type,
    COUNT(*) AS quest_count,
    MIN(quest_level) AS min_level,
    MAX(quest_level) AS max_level
FROM dc_dungeon_quest_mapping
GROUP BY level_type
ORDER BY quest_count DESC;

-- ============================================
-- 6. TOP DUNGEONS BY QUEST COUNT
-- ============================================
SELECT 'Checking top dungeons...' AS status;

SELECT 
    dungeon_name,
    map_id,
    COUNT(*) AS quest_count,
    MIN(quest_level) AS min_level,
    MAX(quest_level) AS max_level
FROM dc_dungeon_quest_mapping
GROUP BY dungeon_name, map_id
ORDER BY quest_count DESC
LIMIT 10;

-- ============================================
-- 7. SAMPLE DUNGEON VERIFICATION
-- ============================================
SELECT 'Verifying sample dungeons...' AS status;

-- Blackrock Depths (should be 43 quests)
SELECT 
    'Blackrock Depths' AS dungeon,
    COUNT(*) AS quest_count,
    CASE 
        WHEN COUNT(*) = 43 THEN 'OK'
        ELSE CONCAT('ERROR: Expected 43, found ', COUNT(*))
    END AS validation
FROM dc_dungeon_quest_mapping 
WHERE map_id = 230;

-- Gnomeregan (should be 28 quests)
SELECT 
    'Gnomeregan' AS dungeon,
    COUNT(*) AS quest_count,
    CASE 
        WHEN COUNT(*) = 28 THEN 'OK'
        ELSE CONCAT('ERROR: Expected 28, found ', COUNT(*))
    END AS validation
FROM dc_dungeon_quest_mapping 
WHERE map_id = 90;

-- Drak'Tharon Keep (should have some quests)
SELECT 
    'Drak\'Tharon Keep' AS dungeon,
    COUNT(*) AS quest_count,
    CASE 
        WHEN COUNT(*) > 0 THEN 'OK'
        ELSE 'ERROR: No quests found'
    END AS validation
FROM dc_dungeon_quest_mapping 
WHERE map_id = 600;

-- ============================================
-- 8. NPC QUEST ASSIGNMENTS
-- ============================================
SELECT 'Checking NPC quest assignments...' AS status;

SELECT 
    npc_entry,
    CASE 
        WHEN npc_entry = 700000 THEN 'Classic Quest Master'
        WHEN npc_entry = 700001 THEN 'TBC Quest Master'
        WHEN npc_entry = 700002 THEN 'WotLK Quest Master'
        ELSE 'Unknown NPC'
    END AS npc_name,
    COUNT(*) AS quest_count,
    MIN(quest_level) AS min_level,
    MAX(quest_level) AS max_level
FROM dc_dungeon_quest_mapping
GROUP BY npc_entry
ORDER BY npc_entry;

-- ============================================
-- 9. MAP ID VALIDATION
-- ============================================
SELECT 'Validating map IDs...' AS status;

-- Check if all map IDs are valid dungeon/raid instances
-- Map IDs should be: Classic (33-429), TBC (540-568), WotLK (574-724)
SELECT 
    COUNT(*) AS invalid_map_ids,
    CASE 
        WHEN COUNT(*) = 0 THEN 'OK: All map IDs are valid'
        ELSE CONCAT('WARNING: ', COUNT(*), ' quests with unusual map IDs')
    END AS validation
FROM dc_dungeon_quest_mapping
WHERE map_id NOT IN (
    33, 34, 36, 43, 47, 48, 70, 90, 109, 129, 189, 209, 229, 230, 
    269, 289, 329, 349, 389, 429,  -- Classic
    540, 542, 543, 545, 546, 547, 552, 553, 554, 555, 556, 557, 558, 560, 585,  -- TBC
    574, 575, 576, 578, 595, 599, 600, 601, 602, 604, 608, 619, 632, 658, 668  -- WotLK
);

-- ============================================
-- 10. QUEST LEVEL RANGES
-- ============================================
SELECT 'Checking quest level ranges...' AS status;

SELECT 
    CASE 
        WHEN quest_level BETWEEN 1 AND 20 THEN '1-20'
        WHEN quest_level BETWEEN 21 AND 40 THEN '21-40'
        WHEN quest_level BETWEEN 41 AND 60 THEN '41-60'
        WHEN quest_level BETWEEN 61 AND 70 THEN '61-70'
        WHEN quest_level BETWEEN 71 AND 80 THEN '71-80'
        ELSE 'Other'
    END AS level_range,
    COUNT(*) AS quest_count
FROM dc_dungeon_quest_mapping
GROUP BY level_range
ORDER BY MIN(quest_level);

-- ============================================
-- 11. SAMPLE QUEST DETAILS
-- ============================================
SELECT 'Sample quest details...' AS status;

SELECT 
    quest_id,
    map_id,
    dungeon_name,
    level_type,
    quest_level,
    npc_entry
FROM dc_dungeon_quest_mapping
ORDER BY RAND()
LIMIT 10;

-- ============================================
-- 12. FINAL SUMMARY
-- ============================================
SELECT 'SUMMARY' AS status;

SELECT 
    (SELECT COUNT(*) FROM dc_dungeon_quest_mapping) AS total_quests,
    (SELECT COUNT(DISTINCT map_id) FROM dc_dungeon_quest_mapping) AS unique_dungeons,
    (SELECT COUNT(DISTINCT level_type) FROM dc_dungeon_quest_mapping) AS level_types,
    (SELECT COUNT(*) FROM creature_queststarter WHERE id IN (700000, 700001, 700002)) AS quest_starters,
    (SELECT COUNT(*) FROM creature_questender WHERE id IN (700000, 700001, 700002)) AS quest_enders;

SELECT 'All verification queries complete!' AS status;
