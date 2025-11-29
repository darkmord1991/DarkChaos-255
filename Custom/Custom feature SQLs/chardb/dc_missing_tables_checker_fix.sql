-- ========================================================================
-- DC Missing Tables - Characters Database (acore_chars)
-- ========================================================================
-- Purpose: Create the 8 missing tables identified by DC TableChecker
-- Database: acore_chars
-- Date: November 29, 2025
-- ========================================================================

USE acore_chars;

-- ========================================================================
-- Achievements System
-- ========================================================================

CREATE TABLE IF NOT EXISTS `dc_player_achievements` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `achievement_id` INT UNSIGNED NOT NULL,
    `achievement_type` VARCHAR(50) DEFAULT NULL,
    `progress` INT UNSIGNED NOT NULL DEFAULT 0,
    `max_progress` INT UNSIGNED NOT NULL DEFAULT 1,
    `completed` TINYINT(1) NOT NULL DEFAULT 0,
    `completed_at` BIGINT UNSIGNED DEFAULT NULL,
    `reward_claimed` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_player_achievement` (`player_guid`, `achievement_id`),
    KEY `idx_player_guid` (`player_guid`),
    KEY `idx_achievement_id` (`achievement_id`),
    KEY `idx_completed` (`completed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Player custom achievement progress';

-- ========================================================================
-- Challenge Mode System
-- ========================================================================

CREATE TABLE IF NOT EXISTS `dc_character_challenge_mode_log` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_guid` INT UNSIGNED NOT NULL,
    `dungeon_id` INT UNSIGNED NOT NULL,
    `difficulty` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `completion_time` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'In seconds',
    `deaths` INT UNSIGNED NOT NULL DEFAULT 0,
    `party_size` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `success` TINYINT(1) NOT NULL DEFAULT 0,
    `score` INT UNSIGNED NOT NULL DEFAULT 0,
    `completed_at` BIGINT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_character_dungeon` (`character_guid`, `dungeon_id`),
    KEY `idx_dungeon_difficulty` (`dungeon_id`, `difficulty`),
    KEY `idx_completed_at` (`completed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Challenge mode run history log';

CREATE TABLE IF NOT EXISTS `dc_character_challenge_mode_stats` (
    `character_guid` INT UNSIGNED NOT NULL,
    `dungeon_id` INT UNSIGNED NOT NULL,
    `total_runs` INT UNSIGNED NOT NULL DEFAULT 0,
    `successful_runs` INT UNSIGNED NOT NULL DEFAULT 0,
    `failed_runs` INT UNSIGNED NOT NULL DEFAULT 0,
    `best_time` INT UNSIGNED DEFAULT NULL COMMENT 'In seconds',
    `best_score` INT UNSIGNED DEFAULT NULL,
    `highest_difficulty` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `total_deaths` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_run_at` BIGINT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`character_guid`, `dungeon_id`),
    KEY `idx_character_guid` (`character_guid`),
    KEY `idx_best_time` (`dungeon_id`, `best_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Challenge mode statistics per character per dungeon';

-- ========================================================================
-- Leaderboards System
-- ========================================================================

CREATE TABLE IF NOT EXISTS `dc_guild_upgrade_stats` (
    `guild_id` INT UNSIGNED NOT NULL,
    `season_id` INT UNSIGNED NOT NULL DEFAULT 1,
    `total_upgrades` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `total_tokens_spent` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `highest_tier_reached` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `active_upgraders` INT UNSIGNED NOT NULL DEFAULT 0,
    `weekly_upgrades` INT UNSIGNED NOT NULL DEFAULT 0,
    `weekly_tokens_spent` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_activity_at` BIGINT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`guild_id`, `season_id`),
    KEY `idx_season` (`season_id`),
    KEY `idx_total_upgrades` (`total_upgrades` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Guild-level upgrade statistics for leaderboards';

CREATE TABLE IF NOT EXISTS `dc_leaderboard_cache` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `leaderboard_type` VARCHAR(50) NOT NULL COMMENT 'upgrades, tokens, mythic, pvp, etc.',
    `season_id` INT UNSIGNED NOT NULL DEFAULT 1,
    `rank` INT UNSIGNED NOT NULL,
    `entity_guid` INT UNSIGNED NOT NULL COMMENT 'Player or guild GUID',
    `entity_type` ENUM('player', 'guild') NOT NULL DEFAULT 'player',
    `entity_name` VARCHAR(64) DEFAULT NULL,
    `score` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `secondary_score` BIGINT UNSIGNED DEFAULT NULL,
    `cached_at` BIGINT UNSIGNED NOT NULL,
    `expires_at` BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_type_season_rank` (`leaderboard_type`, `season_id`, `rank`),
    KEY `idx_entity` (`entity_guid`, `entity_type`),
    KEY `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Cached leaderboard rankings for fast retrieval';

-- ========================================================================
-- Item Upgrade System
-- ========================================================================

CREATE TABLE IF NOT EXISTS `dc_respec_history` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `item_guid` INT UNSIGNED NOT NULL,
    `item_entry` INT UNSIGNED NOT NULL,
    `old_stats` JSON DEFAULT NULL COMMENT 'Stats before respec',
    `new_stats` JSON DEFAULT NULL COMMENT 'Stats after respec',
    `respec_type` VARCHAR(50) DEFAULT 'full',
    `cost_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
    `cost_gold` INT UNSIGNED NOT NULL DEFAULT 0,
    `respec_at` BIGINT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_player_guid` (`player_guid`),
    KEY `idx_item_guid` (`item_guid`),
    KEY `idx_respec_at` (`respec_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Item upgrade respec history';

CREATE TABLE IF NOT EXISTS `dc_respec_log` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `action` VARCHAR(50) NOT NULL COMMENT 'respec, refund, reset, etc.',
    `item_entry` INT UNSIGNED DEFAULT NULL,
    `tokens_refunded` INT UNSIGNED NOT NULL DEFAULT 0,
    `gold_refunded` INT UNSIGNED NOT NULL DEFAULT 0,
    `details` TEXT DEFAULT NULL,
    `logged_at` BIGINT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_player_guid` (`player_guid`),
    KEY `idx_action` (`action`),
    KEY `idx_logged_at` (`logged_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Respec action audit log';

CREATE TABLE IF NOT EXISTS `dc_upgrade_history` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `item_guid` INT UNSIGNED NOT NULL,
    `item_entry` INT UNSIGNED NOT NULL,
    `upgrade_type` VARCHAR(50) NOT NULL COMMENT 'tier, stat, socket, enchant, etc.',
    `old_value` INT UNSIGNED DEFAULT NULL,
    `new_value` INT UNSIGNED DEFAULT NULL,
    `cost_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
    `cost_essence` INT UNSIGNED NOT NULL DEFAULT 0,
    `cost_gold` INT UNSIGNED NOT NULL DEFAULT 0,
    `season_id` INT UNSIGNED NOT NULL DEFAULT 1,
    `upgraded_at` BIGINT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_player_guid` (`player_guid`),
    KEY `idx_item_guid` (`item_guid`),
    KEY `idx_season` (`season_id`),
    KEY `idx_upgraded_at` (`upgraded_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Complete item upgrade history log';

-- ========================================================================
-- VERIFICATION
-- ========================================================================

SELECT '✅ Created 8 missing tables in acore_chars' AS status;

SELECT TABLE_NAME, TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_chars'
AND TABLE_NAME IN (
    'dc_player_achievements',
    'dc_character_challenge_mode_log',
    'dc_character_challenge_mode_stats',
    'dc_guild_upgrade_stats',
    'dc_leaderboard_cache',
    'dc_respec_history',
    'dc_respec_log',
    'dc_upgrade_history'
)
ORDER BY TABLE_NAME;
