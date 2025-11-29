-- ========================================================================
-- DC Missing Tables Update - Characters Database (acore_chars)
-- ========================================================================
-- Purpose: Create tables that are missing from the current database
-- Database: acore_chars
-- Date: November 29, 2025
-- ========================================================================
-- 
-- This script creates tables that are used by C++ code but might not exist:
--   - HLBG seasonal tables (used by HLBGSeasonalParticipant.cpp)
--   - Mythic+ player tables (used by MythicPlusRunManager.cpp)
--   - Spectator settings (used by dc_addon_spectator.cpp)
--
-- EXECUTION:
--   mysql -u root -p acore_chars < "this_file.sql"
--
-- ========================================================================

USE acore_chars;

-- ========================================================================
-- HLBG (Hinterlands BG) System Tables
-- ========================================================================
-- Referenced by: HLBGSeasonalParticipant.cpp

SELECT '📋 Creating HLBG System Tables...' AS step;

-- HLBG Season Config - stores HLBG-specific season settings
-- This is NOT obsolete - it holds HLBG-specific config like base_rating
CREATE TABLE IF NOT EXISTS `dc_hlbg_season_config` (
    `season_id` INT UNSIGNED NOT NULL,
    `base_rating` INT UNSIGNED NOT NULL DEFAULT 1500,
    `max_rating_change` INT UNSIGNED NOT NULL DEFAULT 50,
    `min_players_per_team` TINYINT UNSIGNED NOT NULL DEFAULT 5,
    `max_players_per_team` TINYINT UNSIGNED NOT NULL DEFAULT 10,
    `match_duration` INT UNSIGNED NOT NULL DEFAULT 1800 COMMENT 'In seconds',
    `rating_decay_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    `rating_decay_threshold` INT UNSIGNED DEFAULT 0 COMMENT 'Days inactive before decay',
    `rating_decay_amount` INT UNSIGNED DEFAULT 0 COMMENT 'Rating lost per decay period',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='HLBG-specific season configuration (base_rating, match settings, etc.)';

-- HLBG Player Season Data - tracks player stats per season
CREATE TABLE IF NOT EXISTS `dc_hlbg_player_season_data` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `season_id` INT UNSIGNED NOT NULL,
    `joined_at` BIGINT UNSIGNED NOT NULL,
    `rating` INT UNSIGNED NOT NULL DEFAULT 1500,
    `completed_games` INT UNSIGNED NOT NULL DEFAULT 0,
    `wins` INT UNSIGNED NOT NULL DEFAULT 0,
    `losses` INT UNSIGNED NOT NULL DEFAULT 0,
    `highest_rating` INT UNSIGNED NOT NULL DEFAULT 1500,
    `lowest_rating` INT UNSIGNED NOT NULL DEFAULT 1500,
    `total_score` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `average_score` INT UNSIGNED NOT NULL DEFAULT 0,
    `win_streak` INT UNSIGNED NOT NULL DEFAULT 0,
    `best_win_streak` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_game_at` BIGINT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_player_season` (`player_guid`, `season_id`),
    KEY `idx_season_rating` (`season_id`, `rating` DESC),
    KEY `idx_player_guid` (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='HLBG player seasonal stats (rating, wins, losses, etc.)';

-- HLBG Player History - archived player data from previous seasons
CREATE TABLE IF NOT EXISTS `dc_hlbg_player_history` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `season_id` INT UNSIGNED NOT NULL,
    `joined_at` BIGINT UNSIGNED NOT NULL,
    `rating` INT UNSIGNED NOT NULL,
    `completed_games` INT UNSIGNED NOT NULL,
    `wins` INT UNSIGNED NOT NULL,
    `losses` INT UNSIGNED NOT NULL,
    `highest_rating` INT UNSIGNED NOT NULL,
    `lowest_rating` INT UNSIGNED NOT NULL,
    `total_score` BIGINT UNSIGNED NOT NULL,
    `average_score` INT UNSIGNED NOT NULL,
    `final_rank` INT UNSIGNED DEFAULT NULL,
    `archived_at` BIGINT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_player_season` (`player_guid`, `season_id`),
    KEY `idx_season_rank` (`season_id`, `final_rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Archived HLBG player stats from previous seasons';

-- HLBG Match History - archived match data
CREATE TABLE IF NOT EXISTS `dc_hlbg_match_history` (
    `match_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `season_id` INT UNSIGNED NOT NULL,
    `start_time` BIGINT UNSIGNED NOT NULL,
    `end_time` BIGINT UNSIGNED DEFAULT NULL,
    `winner_team` TINYINT UNSIGNED DEFAULT NULL COMMENT '0 = draw, 1 = team1, 2 = team2',
    `team1_score` INT UNSIGNED NOT NULL DEFAULT 0,
    `team2_score` INT UNSIGNED NOT NULL DEFAULT 0,
    `player_count` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `map_id` INT UNSIGNED DEFAULT NULL,
    `match_duration` INT UNSIGNED DEFAULT NULL COMMENT 'In seconds',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`match_id`),
    KEY `idx_season` (`season_id`),
    KEY `idx_start_time` (`start_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='HLBG match history and results';

SELECT '✅ HLBG Tables Created/Verified' AS status;

-- ========================================================================
-- Mythic+ Player Tables
-- ========================================================================
-- Referenced by: MythicPlusRunManager.cpp, dc_addon_mythicplus.cpp

SELECT '📋 Creating Mythic+ Player Tables...' AS step;

-- Player Keystones - tracks current keystone level per player
CREATE TABLE IF NOT EXISTS `dc_player_keystones` (
    `player_guid` INT UNSIGNED NOT NULL,
    `current_keystone_level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `highest_completed` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `weekly_highest` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `total_runs` INT UNSIGNED NOT NULL DEFAULT 0,
    `successful_runs` INT UNSIGNED NOT NULL DEFAULT 0,
    `failed_runs` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_cancelled` BIGINT UNSIGNED DEFAULT NULL,
    `last_updated` BIGINT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`player_guid`),
    KEY `idx_keystone_level` (`current_keystone_level` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Player M+ keystone progress';

-- Mythic Keystones - specific keystone instances per player
CREATE TABLE IF NOT EXISTS `dc_mythic_keystones` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `dungeon_id` INT UNSIGNED NOT NULL,
    `level` TINYINT UNSIGNED NOT NULL,
    `depleted` TINYINT(1) NOT NULL DEFAULT 0,
    `obtained_at` BIGINT UNSIGNED NOT NULL,
    `expires_at` BIGINT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_player_dungeon` (`player_guid`, `dungeon_id`),
    KEY `idx_player_guid` (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Individual keystone instances';

SELECT '✅ Mythic+ Player Tables Created/Verified' AS status;

-- ========================================================================
-- Spectator Settings
-- ========================================================================
-- Referenced by: dc_addon_spectator.cpp

SELECT '📋 Creating Spectator Settings Table...' AS step;

CREATE TABLE IF NOT EXISTS `dc_spectator_settings` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `setting_key` VARCHAR(50) NOT NULL,
    `setting_value` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_player_setting` (`player_guid`, `setting_key`),
    KEY `idx_player_guid` (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Player spectator mode settings';

SELECT '✅ Spectator Settings Table Created/Verified' AS status;

-- ========================================================================
-- Player Season Data (generic seasonal system)
-- ========================================================================
-- Referenced by: SeasonalSystem.cpp

SELECT '📋 Creating Generic Season Tables...' AS step;

CREATE TABLE IF NOT EXISTS `dc_player_season_data` (
    `player_guid` INT UNSIGNED NOT NULL,
    `current_season_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `joined_season_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `last_activity_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `total_seasons_played` INT UNSIGNED NOT NULL DEFAULT 0,
    `seasons_completed` INT UNSIGNED NOT NULL DEFAULT 0,
    `first_season_joined` BIGINT UNSIGNED DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`player_guid`),
    KEY `idx_current_season` (`current_season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Player seasonal participation tracking (generic system)';

SELECT '✅ Generic Season Tables Created/Verified' AS status;

-- ========================================================================
-- Weekly Rewards Unified Table
-- ========================================================================
-- This table consolidates dc_weekly_vault and dc_player_seasonal_chests
-- Referenced by: DATABASE_CONSOLIDATION docs

SELECT '📋 Creating Unified Weekly Rewards Table...' AS step;

CREATE TABLE IF NOT EXISTS `dc_player_weekly_rewards` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_guid` INT UNSIGNED NOT NULL,
    `season_id` INT UNSIGNED NOT NULL,
    `week_start` BIGINT UNSIGNED NOT NULL,
    `system_type` ENUM('mythic_plus', 'seasonal_rewards', 'pvp', 'raid') NOT NULL DEFAULT 'mythic_plus',
    
    -- M+ specific fields
    `runs_completed` TINYINT UNSIGNED DEFAULT 0,
    `highest_level` TINYINT UNSIGNED DEFAULT 0,
    
    -- Seasonal rewards specific fields
    `tokens_earned` INT UNSIGNED DEFAULT 0,
    `essence_earned` INT UNSIGNED DEFAULT 0,
    
    -- Common slot system
    `slot1_unlocked` TINYINT(1) NOT NULL DEFAULT 0,
    `slot2_unlocked` TINYINT(1) NOT NULL DEFAULT 0,
    `slot3_unlocked` TINYINT(1) NOT NULL DEFAULT 0,
    `slot1_reward` INT UNSIGNED DEFAULT NULL,
    `slot2_reward` INT UNSIGNED DEFAULT NULL,
    `slot3_reward` INT UNSIGNED DEFAULT NULL,
    
    -- Claim tracking
    `reward_claimed` TINYINT(1) NOT NULL DEFAULT 0,
    `claimed_slot` TINYINT UNSIGNED DEFAULT NULL,
    `claimed_item_id` INT UNSIGNED DEFAULT NULL,
    `claimed_tokens` INT UNSIGNED DEFAULT NULL,
    `claimed_essence` INT UNSIGNED DEFAULT NULL,
    `claimed_at` TIMESTAMP NULL DEFAULT NULL,
    
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_char_season_week_type` (`character_guid`, `season_id`, `week_start`, `system_type`),
    KEY `idx_pending_rewards` (`season_id`, `week_start`, `reward_claimed`),
    KEY `idx_system_type` (`system_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Unified weekly rewards (M+ vault + seasonal chests)';

SELECT '✅ Unified Weekly Rewards Table Created/Verified' AS status;

-- ========================================================================
-- VERIFICATION
-- ========================================================================

SELECT '========================================' AS divider;
SELECT '✅ ALL MISSING TABLES CREATED' AS final_status;
SELECT '========================================' AS divider;

SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024, 2) AS 'Size_KB',
    TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_chars'
AND TABLE_NAME IN (
    'dc_hlbg_season_config',
    'dc_hlbg_player_season_data',
    'dc_hlbg_player_history',
    'dc_hlbg_match_history',
    'dc_player_keystones',
    'dc_mythic_keystones',
    'dc_spectator_settings',
    'dc_player_season_data',
    'dc_player_weekly_rewards'
)
ORDER BY TABLE_NAME;

SELECT '========================================' AS divider;
SELECT 'Tables verified: 9' AS table_count;
SELECT 'Status: Ready for use' AS status;
SELECT '========================================' AS divider;
