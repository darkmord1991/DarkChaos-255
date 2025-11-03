-- =====================================================================
-- DUNGEON QUEST SYSTEM v4.0 - CHARACTER DATABASE COMPLETE
-- =====================================================================
-- Purpose: All character database tables for dungeon quest tracking
-- Version: 4.0 (Complete)
-- Database: acore_characters
-- Date: November 3, 2025
-- 
-- This file consolidates character tracking tables from:
-- - EXTENSION_01_difficulty_support.sql (character tables only)
-- 
-- Installation Order: Run WORLD database file FIRST, then this file
-- =====================================================================

-- =====================================================================
-- SECTION 0: DROP EXISTING TABLES (CLEAN INSTALL)
-- =====================================================================

DROP TABLE IF EXISTS `dc_character_difficulty_completions`;
DROP TABLE IF EXISTS `dc_character_difficulty_streaks`;

-- =====================================================================
-- SECTION 1: CHARACTER STATISTICS TABLE ENHANCEMENT
-- =====================================================================
-- Note: This assumes dc_character_dungeon_statistics already exists
-- from the base dungeon quest system. We're extending it for difficulty
-- tracking.
-- =====================================================================

-- Add stat_name and stat_value columns if they don't exist (for flexible tracking)
-- Check if column exists before adding
SET @columnExists1 = (
    SELECT COUNT(*) 
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_SCHEMA = 'acore_characters'
    AND TABLE_NAME = 'dc_character_dungeon_statistics' 
    AND COLUMN_NAME = 'stat_name'
);

-- Only add columns if they don't exist
SET @sql1 = IF(@columnExists1 = 0,
    'ALTER TABLE `dc_character_dungeon_statistics` 
     ADD COLUMN `stat_name` VARCHAR(100) NOT NULL DEFAULT ''total_quests_completed'' AFTER `guid`,
     ADD COLUMN `stat_value` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `stat_name`,
     ADD COLUMN `last_update` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `stat_value`,
     ADD KEY `idx_stat_name` (`stat_name`)',
    'SELECT "Columns already exist - skipping ALTER TABLE" AS info'
);

PREPARE stmt1 FROM @sql1;
EXECUTE stmt1;
DEALLOCATE PREPARE stmt1;

-- =====================================================================
-- SECTION 2: DIFFICULTY-SPECIFIC COMPLETION TRACKING
-- =====================================================================

CREATE TABLE `dc_character_difficulty_completions` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID from characters table',
  `dungeon_id` INT UNSIGNED NOT NULL COMMENT 'Dungeon map ID from acore_world.dc_dungeon_npc_mapping',
  `difficulty` ENUM('Normal','Heroic','Mythic','Mythic+') NOT NULL,
  `total_completions` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total times completed at this difficulty',
  `best_time_seconds` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 = no timed run yet',
  `fastest_completion_date` TIMESTAMP NULL DEFAULT NULL,
  `last_completion_date` TIMESTAMP NULL DEFAULT NULL,
  `total_deaths` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total deaths across all runs',
  `perfect_runs` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Runs with 0 deaths',
  PRIMARY KEY (`guid`, `dungeon_id`, `difficulty`),
  KEY `idx_guid` (`guid`),
  KEY `idx_dungeon_difficulty` (`dungeon_id`, `difficulty`),
  KEY `idx_best_time` (`best_time_seconds`),
  CONSTRAINT `fk_diff_comp_guid` 
    FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='v4.0 - Track per-difficulty dungeon completions for each player';

-- =====================================================================
-- SECTION 3: DIFFICULTY STREAK TRACKING
-- =====================================================================

CREATE TABLE `dc_character_difficulty_streaks` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID from characters table',
  `difficulty` ENUM('Normal','Heroic','Mythic','Mythic+') NOT NULL,
  `current_streak` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Current consecutive completions',
  `longest_streak` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Longest streak ever achieved',
  `last_completion_date` TIMESTAMP NULL DEFAULT NULL,
  `streak_start_date` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`guid`, `difficulty`),
  KEY `idx_current_streak` (`current_streak`),
  KEY `idx_longest_streak` (`longest_streak`),
  CONSTRAINT `fk_diff_streak_guid` 
    FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='v4.0 - Track consecutive completion streaks per difficulty';

-- =====================================================================
-- VERIFICATION QUERIES
-- =====================================================================

-- Check if dc_character_difficulty_completions table exists
SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    CREATE_TIME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_characters'
AND TABLE_NAME LIKE 'dc_character%'
ORDER BY TABLE_NAME;

-- Check column structure
SHOW COLUMNS FROM `dc_character_difficulty_completions`;
SHOW COLUMNS FROM `dc_character_difficulty_streaks`;

-- Verify statistics table enhancement
SELECT COLUMN_NAME, COLUMN_TYPE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'acore_characters'
AND TABLE_NAME = 'dc_character_dungeon_statistics'
AND COLUMN_NAME IN ('stat_name', 'stat_value', 'last_update');

-- =====================================================================
-- SAMPLE USAGE EXAMPLES (for reference)
-- =====================================================================

-- Example 1: Track a completion for character GUID 123 in RFC Heroic
/*
INSERT INTO dc_character_difficulty_completions 
(guid, dungeon_id, difficulty, total_completions, last_completion_date)
VALUES (123, 389, 'Heroic', 1, NOW())
ON DUPLICATE KEY UPDATE
    total_completions = total_completions + 1,
    last_completion_date = NOW();
*/

-- Example 2: Update streak for Heroic difficulty
/*
INSERT INTO dc_character_difficulty_streaks
(guid, difficulty, current_streak, longest_streak, last_completion_date, streak_start_date)
VALUES (123, 'Heroic', 1, 1, NOW(), NOW())
ON DUPLICATE KEY UPDATE
    current_streak = current_streak + 1,
    longest_streak = GREATEST(longest_streak, current_streak + 1),
    last_completion_date = NOW();
*/

-- Example 3: Reset streak if more than 24 hours passed
/*
UPDATE dc_character_difficulty_streaks
SET current_streak = 1,
    streak_start_date = NOW()
WHERE guid = 123
AND difficulty = 'Heroic'
AND TIMESTAMPDIFF(HOUR, last_completion_date, NOW()) > 24;
*/

-- Example 4: Get player's best times per dungeon
/*
SELECT 
    d.dungeon_name,
    c.difficulty,
    c.total_completions,
    c.best_time_seconds,
    c.perfect_runs,
    c.last_completion_date
FROM dc_character_difficulty_completions c
JOIN acore_world.dc_dungeon_npc_mapping d ON c.dungeon_id = d.map_id
WHERE c.guid = 123
ORDER BY d.dungeon_name, c.difficulty;
*/

-- Example 5: Leaderboard - Fastest runs per dungeon
/*
SELECT 
    c.name AS character_name,
    d.dungeon_name,
    comp.difficulty,
    comp.best_time_seconds,
    comp.fastest_completion_date
FROM dc_character_difficulty_completions comp
JOIN characters c ON comp.guid = c.guid
JOIN acore_world.dc_dungeon_npc_mapping d ON comp.dungeon_id = d.map_id
WHERE comp.best_time_seconds > 0
ORDER BY d.dungeon_name, comp.difficulty, comp.best_time_seconds ASC
LIMIT 100;
*/

-- =====================================================================
-- INTEGRATION NOTES FOR C++ DEVELOPERS
-- =====================================================================

/*
When implementing difficulty tracking in DungeonQuestSystem.cpp:

1. On Quest Completion:
   - Query acore_world.dc_quest_difficulty_mapping to get difficulty tier
   - Update dc_character_difficulty_completions (increment total_completions)
   - If timed run, check and update best_time_seconds
   - Track deaths and update perfect_runs if 0 deaths
   - Update dc_character_difficulty_streaks (check if within 24 hours)

2. On Quest Accept:
   - Verify player meets difficulty requirements:
     * Check min_level from acore_world.dc_difficulty_config
     * Check min_group_size if requires_group = 1
     * Check min_ilvl if implemented
   - Show difficulty tier in quest text/gossip

3. Reward Multipliers:
   - Query acore_world.dc_difficulty_config for multipliers
   - Apply token_multiplier to base_token_reward
   - Apply gold_multiplier to base_gold_reward
   - Apply xp_multiplier to quest XP

4. Statistics Queries:
   - Query dc_character_difficulty_completions for player progress
   - Query dc_character_difficulty_streaks for streak bonuses
   - Use for achievements, titles, rewards

5. Leaderboards:
   - Query best_time_seconds for speed rankings
   - Query perfect_runs for deathless achievements
   - Query longest_streak for consistency rewards
*/

-- =====================================================================
-- COMPLETION MESSAGE
-- =====================================================================

SELECT 'Character Database v4.0 Installation Complete!' AS Status,
       DATABASE() AS current_database,
       (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = 'acore_characters' 
        AND TABLE_NAME LIKE 'dc_character%') AS dungeon_tables,
       NOW() AS installation_time;

-- =====================================================================
-- DEPLOYMENT CHECKLIST
-- =====================================================================

/*
✓ 1. Import MASTER_WORLD_v4.0.sql FIRST (creates config and mapping tables)
✓ 2. Import this file SECOND (creates character tracking tables)
□ 3. Update C++ scripts to use new difficulty system
□ 4. Test difficulty multipliers in-game
□ 5. Verify streak tracking works correctly
□ 6. Test foreign key constraints (character deletion should cascade)
□ 7. Monitor performance on high-population servers
□ 8. Create achievement DBC entries (use category 10010)
□ 9. Create GM commands for difficulty testing
□ 10. Document player-facing difficulty system in patch notes
*/

-- =====================================================================
-- END OF CHARACTER DATABASE v4.0
-- =====================================================================
