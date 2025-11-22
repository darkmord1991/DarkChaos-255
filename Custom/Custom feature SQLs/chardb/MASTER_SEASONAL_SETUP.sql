-- ========================================================================
-- MASTER SETUP: Seasonal System - Characters Database (ac_chars)
-- ========================================================================
-- Purpose: Complete database setup for seasonal systems
-- Database: ac_chars
-- Date: November 22, 2025
-- ========================================================================
-- 
-- This script sets up all tables for:
--   ✓ Seasonal rewards (tokens/essence tracking)
--   ✓ Weekly vault (M+ Great Vault)
--   ✓ Weekly chests (seasonal rewards)
--   ✓ Transaction logging and analytics
--
-- EXECUTION:
--   mysql -u root -p ac_chars < "path/to/this/file.sql"
--
-- OR execute individual scripts in this order:
--   1. 00_CREATE_SEASONAL_TABLES.sql
--   2. 00_CREATE_WEEKLY_VAULT.sql (Mythic+ folder)
--   3. 01_CREATE_WEEKLY_CHESTS.sql
--
-- ========================================================================

USE ac_chars;

-- ========================================================================
-- PART 1: Core Seasonal Tables
-- ========================================================================

SELECT '📋 Creating Core Seasonal Tables...' AS step;

DROP TABLE IF EXISTS `dc_player_seasonal_achievements`;
DROP TABLE IF EXISTS `dc_player_weekly_cap_snapshot`;
DROP TABLE IF EXISTS `dc_reward_transactions`;
DROP TABLE IF EXISTS `dc_player_seasonal_stats_history`;
DROP TABLE IF EXISTS `dc_player_seasonal_stats`;
DROP TABLE IF EXISTS `dc_season_history`;
DROP TABLE IF EXISTS `dc_seasons`;

CREATE TABLE `dc_seasons` (
  `season_id` INT UNSIGNED NOT NULL,
  `season_name` VARCHAR(100) NOT NULL,
  `start_timestamp` BIGINT UNSIGNED NOT NULL,
  `end_timestamp` BIGINT UNSIGNED DEFAULT 0,
  `is_active` TINYINT(1) NOT NULL DEFAULT 0,
  `max_upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 15,
  `cost_multiplier` FLOAT NOT NULL DEFAULT 1,
  `reward_multiplier` FLOAT NOT NULL DEFAULT 1,
  `theme` VARCHAR(255) DEFAULT NULL,
  `milestone_essence_cap` INT UNSIGNED NOT NULL DEFAULT 50000,
  `milestone_token_cap` INT UNSIGNED NOT NULL DEFAULT 25000,
  PRIMARY KEY (`season_id`),
  KEY `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Season configuration';

INSERT INTO `dc_seasons` 
  (`season_id`, `season_name`, `start_timestamp`, `end_timestamp`, `is_active`, 
   `max_upgrade_level`, `cost_multiplier`, `reward_multiplier`, `theme`, 
   `milestone_essence_cap`, `milestone_token_cap`) 
VALUES 
  (1, 'Season 1: Awakening', UNIX_TIMESTAMP(), 0, 1, 15, 1, 1, 
   'The beginning of artifact mastery', 50000, 25000);

CREATE TABLE `dc_player_seasonal_stats` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `total_tokens_earned` BIGINT UNSIGNED DEFAULT 0,
  `total_essence_earned` BIGINT UNSIGNED DEFAULT 0,
  `quests_completed` INT UNSIGNED DEFAULT 0,
  `bosses_killed` INT UNSIGNED DEFAULT 0,
  `chests_claimed` INT UNSIGNED DEFAULT 0,
  `weekly_tokens_earned` INT UNSIGNED DEFAULT 0,
  `weekly_essence_earned` INT UNSIGNED DEFAULT 0,
  `weekly_reset_at` BIGINT UNSIGNED,
  `season_best_run` VARCHAR(255),
  `last_reward_at` BIGINT UNSIGNED,
  `last_activity_at` BIGINT UNSIGNED,
  `joined_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_player_season` (`player_guid`, `season_id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_tokens_earned` (`total_tokens_earned`),
  KEY `idx_last_activity` (`last_activity_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Player seasonal statistics';

CREATE TABLE `dc_reward_transactions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `transaction_type` ENUM('quest', 'creature', 'creature_group', 'chest', 'manual', 'adjustment') NOT NULL,
  `source_id` INT UNSIGNED,
  `source_name` VARCHAR(255),
  `reward_type` TINYINT,
  `token_amount` INT UNSIGNED DEFAULT 0,
  `essence_amount` INT UNSIGNED DEFAULT 0,
  `base_amount` INT UNSIGNED,
  `difficulty_multiplier` FLOAT DEFAULT 1.0,
  `season_multiplier` FLOAT DEFAULT 1.0,
  `final_multiplier` FLOAT DEFAULT 1.0,
  `weekly_total_after` INT UNSIGNED,
  `notes` VARCHAR(255),
  `transaction_at` BIGINT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player_season` (`player_guid`, `season_id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_transaction_type` (`transaction_type`),
  KEY `idx_transaction_at` (`transaction_at`),
  KEY `idx_source_id` (`source_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Audit trail: all reward transactions';

CREATE TABLE `dc_player_weekly_cap_snapshot` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `week_ending` DATE NOT NULL,
  `tokens_earned` INT UNSIGNED DEFAULT 0,
  `essence_earned` INT UNSIGNED DEFAULT 0,
  `quests_completed` INT UNSIGNED DEFAULT 0,
  `bosses_killed` INT UNSIGNED DEFAULT 0,
  `chests_claimed` INT UNSIGNED DEFAULT 0,
  `snapshot_at` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_player_season_week` (`player_guid`, `season_id`, `week_ending`),
  KEY `idx_week_ending` (`week_ending`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Historical snapshots of weekly caps';

CREATE TABLE `dc_player_seasonal_achievements` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `achievement_type` VARCHAR(50) NOT NULL,
  `achievement_name` VARCHAR(255) NOT NULL,
  `achievement_description` VARCHAR(255),
  `progress_value` INT UNSIGNED,
  `reward_tokens` INT UNSIGNED DEFAULT 0,
  `reward_essence` INT UNSIGNED DEFAULT 0,
  `achieved_at` BIGINT UNSIGNED NOT NULL,
  `rewarded_at` BIGINT UNSIGNED,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player_season` (`player_guid`, `season_id`),
  KEY `idx_achievement_type` (`achievement_type`),
  KEY `idx_achieved_at` (`achieved_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Seasonal achievements';

CREATE TABLE `dc_season_history` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `event_type` ENUM('created', 'started', 'ended', 'archived') NOT NULL,
  `event_timestamp` BIGINT UNSIGNED NOT NULL,
  `notes` TEXT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_event_type` (`event_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Season lifecycle history';

CREATE TABLE `dc_player_seasonal_stats_history` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `total_tokens_earned` BIGINT UNSIGNED DEFAULT 0,
  `total_essence_earned` BIGINT UNSIGNED DEFAULT 0,
  `quests_completed` INT UNSIGNED DEFAULT 0,
  `bosses_killed` INT UNSIGNED DEFAULT 0,
  `chests_claimed` INT UNSIGNED DEFAULT 0,
  `final_rank_tokens` INT UNSIGNED,
  `final_rank_bosses` INT UNSIGNED,
  `archived_at` BIGINT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player_season` (`player_guid`, `season_id`),
  KEY `idx_archived_at` (`archived_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Archived player stats';

SELECT '✅ Core Seasonal Tables Created' AS status;

-- ========================================================================
-- PART 2: Weekly Vault (M+ Great Vault)
-- ========================================================================

SELECT '📋 Creating Weekly Vault Table...' AS step;

DROP TABLE IF EXISTS `dc_weekly_vault`;

CREATE TABLE `dc_weekly_vault` (
  `character_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `week_start` BIGINT UNSIGNED NOT NULL,
  `runs_completed` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `highest_level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `slot1_unlocked` TINYINT(1) NOT NULL DEFAULT 0,
  `slot2_unlocked` TINYINT(1) NOT NULL DEFAULT 0,
  `slot3_unlocked` TINYINT(1) NOT NULL DEFAULT 0,
  `reward_claimed` TINYINT(1) NOT NULL DEFAULT 0,
  `claimed_slot` TINYINT UNSIGNED DEFAULT NULL,
  `claimed_item_id` INT UNSIGNED DEFAULT NULL,
  `claimed_tokens` INT UNSIGNED DEFAULT NULL,
  `claimed_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`character_guid`, `season_id`, `week_start`),
  KEY `idx_pending_rewards` (`season_id`, `week_start`, `reward_claimed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Weekly Great Vault progress';

SELECT '✅ Weekly Vault Table Created' AS status;

-- ========================================================================
-- PART 3: Weekly Chests (Seasonal Rewards)
-- ========================================================================

SELECT '📋 Creating Weekly Chest Tables...' AS step;

DROP TABLE IF EXISTS `dc_player_seasonal_chests`;
DROP TABLE IF EXISTS `dc_player_claimed_chests`;

CREATE TABLE `dc_player_seasonal_chests` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `week_timestamp` BIGINT UNSIGNED NOT NULL,
  `slot1_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
  `slot1_essence` INT UNSIGNED NOT NULL DEFAULT 0,
  `slot2_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
  `slot2_essence` INT UNSIGNED NOT NULL DEFAULT 0,
  `slot3_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
  `slot3_essence` INT UNSIGNED NOT NULL DEFAULT 0,
  `slots_unlocked` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `collected` BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_player_season_week` (`player_guid`, `season_id`, `week_timestamp`),
  KEY `idx_season_week` (`season_id`, `week_timestamp`),
  KEY `idx_uncollected` (`collected`, `season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Weekly seasonal reward chest tracking';

CREATE TABLE `dc_player_claimed_chests` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `chest_id` VARCHAR(50) NOT NULL,
  `chest_tier` TINYINT NOT NULL,
  `items_received` JSON,
  `claimed_at` BIGINT UNSIGNED NOT NULL,
  `claimed_by_npc_guid` INT UNSIGNED,
  `transaction_id` BIGINT UNSIGNED,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player_season` (`player_guid`, `season_id`),
  KEY `idx_chest_id` (`chest_id`),
  KEY `idx_claimed_at` (`claimed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Prevents duplicate chest claims';

SELECT '✅ Weekly Chest Tables Created' AS status;

-- ========================================================================
-- PART 4: Analytics Views
-- ========================================================================

SELECT '📋 Creating Analytics Views...' AS step;

DROP VIEW IF EXISTS `v_seasonal_leaderboard`;
CREATE VIEW `v_seasonal_leaderboard` AS
SELECT 
  `player_guid`,
  `season_id`,
  `total_tokens_earned`,
  `total_essence_earned`,
  `quests_completed`,
  `bosses_killed`,
  `chests_claimed`,
  ROW_NUMBER() OVER (PARTITION BY `season_id` ORDER BY `total_tokens_earned` DESC) AS `token_rank`,
  ROW_NUMBER() OVER (PARTITION BY `season_id` ORDER BY `bosses_killed` DESC) AS `boss_rank`
FROM `dc_player_seasonal_stats`
WHERE `total_tokens_earned` > 0
ORDER BY `season_id`, `total_tokens_earned` DESC;

DROP VIEW IF EXISTS `v_weekly_top_performers`;
CREATE VIEW `v_weekly_top_performers` AS
SELECT 
  `player_guid`,
  `season_id`,
  `weekly_tokens_earned`,
  `weekly_essence_earned`,
  `quests_completed`,
  `bosses_killed`,
  ROW_NUMBER() OVER (PARTITION BY `season_id` ORDER BY `weekly_tokens_earned` DESC) AS `weekly_rank`
FROM `dc_player_seasonal_stats`
WHERE `weekly_reset_at` = (SELECT MAX(`weekly_reset_at`) FROM `dc_player_seasonal_stats` LIMIT 1)
ORDER BY `weekly_tokens_earned` DESC;

DROP VIEW IF EXISTS `v_transaction_summary`;
CREATE VIEW `v_transaction_summary` AS
SELECT 
  `transaction_type`,
  COUNT(*) AS `total_transactions`,
  SUM(`token_amount`) AS `total_tokens`,
  SUM(`essence_amount`) AS `total_essence`,
  AVG(`token_amount`) AS `avg_token_reward`,
  MIN(`transaction_at`) AS `first_transaction`,
  MAX(`transaction_at`) AS `last_transaction`
FROM `dc_reward_transactions`
GROUP BY `transaction_type`;

SELECT '✅ Analytics Views Created' AS status;

-- ========================================================================
-- VERIFICATION
-- ========================================================================

SELECT '========================================' AS divider;
SELECT '✅ ALL TABLES CREATED SUCCESSFULLY' AS final_status;
SELECT '========================================' AS divider;

SELECT 
  TABLE_NAME,
  TABLE_ROWS,
  ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024, 2) AS 'Size_KB',
  TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ac_chars'
  AND (
    TABLE_NAME LIKE 'dc_%season%' OR
    TABLE_NAME LIKE 'dc_weekly_%' OR
    TABLE_NAME LIKE 'dc_reward%' OR
    TABLE_NAME LIKE 'dc_player_%chest%'
  )
ORDER BY TABLE_NAME;

SELECT '========================================' AS divider;
SELECT 'Database: ac_chars' AS db_name;
SELECT 'Tables created: 11' AS table_count;
SELECT 'Views created: 3' AS view_count;
SELECT 'Status: Ready for use' AS status;
SELECT '========================================' AS divider;
