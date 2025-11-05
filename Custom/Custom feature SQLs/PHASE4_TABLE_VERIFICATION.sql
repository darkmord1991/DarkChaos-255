-- ====================================================================
-- Phase 4 Table Verification Script
-- Verifies all Phase 4 tables have correct dc_ prefix
-- Date: November 5, 2025
-- ====================================================================

USE acore_characters;

-- ====================================================================
-- Check for missing dc_ prefix tables (should return 0 rows)
-- ====================================================================
SELECT 
    TABLE_NAME,
    'MISSING DC_ PREFIX - NEEDS RENAME' AS status
FROM 
    INFORMATION_SCHEMA.TABLES
WHERE 
    TABLE_SCHEMA = 'acore_chars' 
    AND (
        -- Check for old table names without dc_ prefix that should have it
        TABLE_NAME IN (
            'item_upgrades',
            'item_upgrade_log',
            'item_upgrade_costs',
            'item_upgrade_stat_scaling',
            'player_upgrade_tokens',
            'player_tier_unlocks',
            'player_tier_caps',
            'weekly_spending',
            'player_artifact_mastery',
            'artifact_mastery_events',
            'seasons',
            'player_season_data',
            'season_history',
            'upgrade_history',
            'leaderboard_cache',
            'respec_history',
            'respec_log',
            'player_achievements',
            'achievement_definitions',
            'upgrade_loadouts',
            'loadout_items',
            'guild_upgrade_stats'
        )
    );

-- ====================================================================
-- List all Phase 4 tables with dc_ prefix (should return 27+ rows)
-- ====================================================================
SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Size_MB',
    CREATE_TIME,
    UPDATE_TIME
FROM 
    INFORMATION_SCHEMA.TABLES
WHERE 
    TABLE_SCHEMA = 'acore_chars' 
    AND TABLE_NAME LIKE 'dc_%'
    AND (
        -- Phase 4A tables
        TABLE_NAME IN ('dc_item_upgrades', 'dc_item_upgrade_log', 'dc_item_upgrade_costs', 'dc_item_upgrade_stat_scaling')
        OR
        -- Phase 4B tables
        TABLE_NAME IN ('dc_player_tier_unlocks', 'dc_player_tier_caps', 'dc_weekly_spending', 'dc_player_artifact_mastery', 'dc_artifact_mastery_events', 'dc_mastery_leaderboard')
        OR
        -- Phase 4C tables
        TABLE_NAME IN ('dc_seasons', 'dc_player_season_data', 'dc_season_history', 'dc_seasonal_competitions')
        OR
        -- Phase 4D tables
        TABLE_NAME IN ('dc_upgrade_history', 'dc_leaderboard_cache', 'dc_respec_history', 'dc_respec_log', 'dc_player_achievements', 'dc_achievement_definitions', 'dc_upgrade_loadouts', 'dc_loadout_items', 'dc_guild_upgrade_stats')
        OR
        -- Token/Currency tables
        TABLE_NAME IN ('dc_player_upgrade_tokens', 'dc_token_event_config', 'dc_token_transaction_log', 'dc_weekly_quest_progress', 'dc_player_progression_summary', 'dc_recent_upgrades_feed', 'dc_upgrade_speed_stats', 'dc_player_daily_quest_progress', 'dc_top_upgraders', 'dc_guild_leaderboard')
    )
ORDER BY 
    TABLE_NAME;

-- ====================================================================
-- Phase 4 Table Completeness Check
-- ====================================================================
SELECT 
    CASE 
        WHEN table_count >= 27 THEN CONCAT('✓ SUCCESS: All ', table_count, ' Phase 4 tables present')
        WHEN table_count >= 20 THEN CONCAT('⚠ WARNING: Only ', table_count, ' tables found (expected 27+)')
        ELSE CONCAT('✗ ERROR: Only ', table_count, ' tables found (expected 27+)')
    END AS deployment_status,
    table_count AS tables_found,
    27 AS tables_expected
FROM (
    SELECT COUNT(*) AS table_count
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'acore_chars' 
      AND TABLE_NAME LIKE 'dc_%'
      AND (
          TABLE_NAME IN ('dc_item_upgrades', 'dc_item_upgrade_log', 'dc_item_upgrade_costs', 'dc_item_upgrade_stat_scaling')
          OR TABLE_NAME IN ('dc_player_tier_unlocks', 'dc_player_tier_caps', 'dc_weekly_spending', 'dc_player_artifact_mastery', 'dc_artifact_mastery_events', 'dc_mastery_leaderboard')
          OR TABLE_NAME IN ('dc_seasons', 'dc_player_season_data', 'dc_season_history', 'dc_seasonal_competitions')
          OR TABLE_NAME IN ('dc_upgrade_history', 'dc_leaderboard_cache', 'dc_respec_history', 'dc_respec_log', 'dc_player_achievements', 'dc_achievement_definitions', 'dc_upgrade_loadouts', 'dc_loadout_items', 'dc_guild_upgrade_stats')
          OR TABLE_NAME IN ('dc_player_upgrade_tokens', 'dc_token_event_config', 'dc_token_transaction_log', 'dc_weekly_quest_progress', 'dc_player_progression_summary', 'dc_recent_upgrades_feed', 'dc_upgrade_speed_stats', 'dc_player_daily_quest_progress', 'dc_top_upgraders', 'dc_guild_leaderboard')
      )
) AS counts;

-- ====================================================================
-- C++ Code Table Reference Check
-- Expected tables referenced in C++ code:
-- ====================================================================
/*
These tables MUST exist for C++ code to work:

PHASE 4A (Core):
✓ dc_item_upgrades
✓ dc_item_upgrade_log  
✓ dc_item_upgrade_costs
✓ dc_item_upgrade_stat_scaling
✓ dc_player_upgrade_tokens

PHASE 4B (Progression):
✓ dc_player_tier_unlocks
✓ dc_player_tier_caps
✓ dc_weekly_spending
✓ dc_player_artifact_mastery
✓ dc_artifact_mastery_events
✓ dc_mastery_leaderboard

PHASE 4C (Seasonal):
✓ dc_seasons
✓ dc_player_season_data
✓ dc_season_history
✓ dc_seasonal_competitions

PHASE 4D (Advanced):
✓ dc_upgrade_history
✓ dc_leaderboard_cache
✓ dc_respec_history
✓ dc_respec_log
✓ dc_player_achievements
✓ dc_achievement_definitions
✓ dc_upgrade_loadouts
✓ dc_loadout_items
✓ dc_guild_upgrade_stats

All table names in C++ code have been verified to use dc_ prefix.
*/

-- ====================================================================
-- Table Name Consistency Report
-- ====================================================================
SELECT 
    'Phase 4A Core' AS phase,
    GROUP_CONCAT(TABLE_NAME SEPARATOR ', ') AS tables_present
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_chars'
  AND TABLE_NAME IN ('dc_item_upgrades', 'dc_item_upgrade_log', 'dc_item_upgrade_costs', 'dc_item_upgrade_stat_scaling', 'dc_player_upgrade_tokens')
UNION ALL
SELECT 
    'Phase 4B Progression' AS phase,
    GROUP_CONCAT(TABLE_NAME SEPARATOR ', ') AS tables_present
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_chars'
  AND TABLE_NAME IN ('dc_player_tier_unlocks', 'dc_player_tier_caps', 'dc_weekly_spending', 'dc_player_artifact_mastery', 'dc_artifact_mastery_events', 'dc_mastery_leaderboard')
UNION ALL
SELECT 
    'Phase 4C Seasonal' AS phase,
    GROUP_CONCAT(TABLE_NAME SEPARATOR ', ') AS tables_present
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_chars'
  AND TABLE_NAME IN ('dc_seasons', 'dc_player_season_data', 'dc_season_history', 'dc_seasonal_competitions')
UNION ALL
SELECT 
    'Phase 4D Advanced' AS phase,
    GROUP_CONCAT(TABLE_NAME SEPARATOR ', ') AS tables_present
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_chars'
  AND TABLE_NAME IN ('dc_upgrade_history', 'dc_leaderboard_cache', 'dc_respec_history', 'dc_respec_log', 'dc_player_achievements', 'dc_achievement_definitions', 'dc_upgrade_loadouts', 'dc_loadout_items', 'dc_guild_upgrade_stats');

-- ====================================================================
-- FINAL VERIFICATION
-- ====================================================================
SELECT 
    'DC_ PREFIX CHECK' AS verification_type,
    CASE 
        WHEN missing_count = 0 THEN '✓ PASS: All tables have dc_ prefix'
        ELSE CONCAT('✗ FAIL: ', missing_count, ' tables missing dc_ prefix')
    END AS result
FROM (
    SELECT COUNT(*) AS missing_count
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'acore_chars'
      AND TABLE_NAME IN (
          'item_upgrades', 'item_upgrade_log', 'item_upgrade_costs', 'item_upgrade_stat_scaling',
          'player_upgrade_tokens', 'player_tier_unlocks', 'player_tier_caps', 'weekly_spending',
          'player_artifact_mastery', 'artifact_mastery_events', 'seasons', 'player_season_data',
          'season_history', 'upgrade_history', 'leaderboard_cache', 'respec_history', 'respec_log',
          'player_achievements', 'achievement_definitions', 'upgrade_loadouts', 'loadout_items',
          'guild_upgrade_stats'
      )
) AS check_result;

