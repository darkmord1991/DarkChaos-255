-- ========================================================================
-- DC Missing Tables Update - Characters Database (acore_chars)
-- ========================================================================
-- Purpose: Create tables that are missing from the current database
-- Database: acore_chars
-- Date: November 29, 2025
-- ========================================================================
-- 
-- This script creates tables that are used by C++ code but might not exist:
--   - HLBG unified tables (used by addon stats, scoreboards, and leaderboards)
--   - Mythic+ player tables (used by MythicPlusRunManager.cpp)
--   - Spectator settings (used by dc_addon_spectator.cpp)
--
-- EXECUTION:
--   mysql -u root -p acore_chars < "this_file.sql"
--
-- ========================================================================

USE acore_chars;

-- ========================================================================
-- HLBG (Hinterlands BG) Unified Tables
-- ========================================================================
-- Referenced by: dc_addon_hlbg.cpp, dc_addon_leaderboards.cpp, HLBG runtime history

SELECT '📋 Creating HLBG System Tables...' AS step;

-- HLBG Match Participants - unified seasonal and per-match stats source
CREATE TABLE IF NOT EXISTS `dc_hlbg_match_participants` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `match_id` INT UNSIGNED NOT NULL,
    `guid` INT UNSIGNED NOT NULL,
    `player_name` VARCHAR(50) COLLATE utf8mb4_unicode_ci NOT NULL,
    `account_id` INT UNSIGNED NOT NULL,
    `account_name` VARCHAR(32) COLLATE utf8mb4_unicode_ci NOT NULL,
    `team` TINYINT NOT NULL COMMENT '0 = Alliance, 1 = Horde',
    `season_id` INT UNSIGNED NOT NULL DEFAULT 1,
    `match_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `kills` INT UNSIGNED NOT NULL DEFAULT 0,
    `deaths` INT UNSIGNED NOT NULL DEFAULT 0,
    `healing_done` INT UNSIGNED NOT NULL DEFAULT 0,
    `damage_done` INT UNSIGNED NOT NULL DEFAULT 0,
    `resources_captured` INT UNSIGNED NOT NULL DEFAULT 0,
    `flags_returned` INT UNSIGNED NOT NULL DEFAULT 0,
    `objectives_completed` INT UNSIGNED NOT NULL DEFAULT 0,
    `rating_change` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_guid` (`guid`),
    KEY `idx_match_id` (`match_id`),
    KEY `idx_account` (`account_id`),
    KEY `idx_season` (`season_id`),
    KEY `idx_date` (`match_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tracks individual player statistics for each HLBG match';

-- HLBG Player Stats - legacy all-time leaderboard counters still queried directly
CREATE TABLE IF NOT EXISTS `dc_hlbg_player_stats` (
    `player_guid` INT UNSIGNED NOT NULL,
    `player_name` VARCHAR(12) NOT NULL,
    `faction` VARCHAR(16) NOT NULL DEFAULT 'Unknown',
    `battles_participated` INT UNSIGNED NOT NULL DEFAULT 0,
    `battles_won` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_participation` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `total_kills` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_deaths` INT UNSIGNED NOT NULL DEFAULT 0,
    `resources_captured` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`player_guid`),
    KEY `idx_player_name` (`player_name`),
    KEY `idx_faction` (`faction`),
    KEY `idx_battles_won` (`battles_won`),
    KEY `idx_total_kills` (`total_kills`),
    KEY `idx_last_participation` (`last_participation`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='HLBG player all-time statistics';

-- HLBG Winner History - primary HLBG battle result history
CREATE TABLE IF NOT EXISTS `dc_hlbg_winner_history` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `season` SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    `occurred_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `duration_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    `zone_id` SMALLINT UNSIGNED NOT NULL DEFAULT 26,
    `map_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `winner_tid` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '0 = Alliance, 1 = Horde, 2 = Draw',
    `win_reason` VARCHAR(32) NOT NULL DEFAULT 'depletion',
    `score_alliance` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `score_horde` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `affix` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `weather` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `weather_intensity` FLOAT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_season` (`season`),
    KEY `idx_occurred_at` (`occurred_at`),
    KEY `idx_winner_tid` (`winner_tid`),
    KEY `idx_affix` (`affix`),
    KEY `idx_weather` (`weather`),
    KEY `idx_win_reason` (`win_reason`),
    KEY `idx_season_occurred` (`season`, `occurred_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='HLBG battle history';

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
    'dc_hlbg_match_participants',
    'dc_hlbg_player_stats',
    'dc_hlbg_winner_history',
    'dc_player_keystones',
    'dc_mythic_keystones',
    'dc_spectator_settings',
    'dc_player_season_data',
    'dc_player_weekly_rewards'
)
ORDER BY TABLE_NAME;

SELECT '========================================' AS divider;
SELECT 'Tables verified: 8' AS table_count;
SELECT 'Status: Ready for use' AS status;
SELECT '========================================' AS divider;
