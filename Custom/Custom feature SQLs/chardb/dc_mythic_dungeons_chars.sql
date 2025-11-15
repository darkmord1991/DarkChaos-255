-- ========================================================================
-- DarkChaos Mythic+ System - Character Database Schema
-- ========================================================================
-- Purpose: Player progression tracking, keystones, vault, and run history
-- Database: acore_characters
-- Author: DarkChaos Development Team
-- Date: November 2025
-- ========================================================================

USE acore_chars;

-- ========================================================================
-- Table: dc_mplus_keystones
-- Purpose: Tracks each player's active keystone (max 1 per character)
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_mplus_keystones` (
  `character_guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Dungeon map ID',
  `level` TINYINT UNSIGNED NOT NULL COMMENT 'Keystone level (1-8)',
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season ID from dc_mplus_seasons',
  `expires_on` BIGINT UNSIGNED NOT NULL COMMENT 'Expiration timestamp (Unix)',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation timestamp',
  PRIMARY KEY (`character_guid`),
  INDEX `idx_season` (`season_id`),
  INDEX `idx_expiration` (`expires_on`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Active Mythic+ keystones (one per player)';

-- ========================================================================
-- Table: dc_mplus_scores
-- Purpose: Player's best score per dungeon per season
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_mplus_scores` (
  `character_guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season ID',
  `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Dungeon map ID',
  `best_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Highest keystone level cleared',
  `best_score` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Best score achieved',
  `last_run_ts` BIGINT UNSIGNED NOT NULL COMMENT 'Last run timestamp (Unix)',
  `total_runs` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total runs of this dungeon',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`character_guid`, `season_id`, `map_id`),
  INDEX `idx_leaderboard` (`season_id`, `map_id`, `best_score` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Per-dungeon Mythic+ scores and best clears';

-- ========================================================================
-- Table: dc_mplus_runs
-- Purpose: Complete run history for vault eligibility and statistics
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_mplus_runs` (
  `run_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique run identifier',
  `character_guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season ID',
  `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Dungeon map ID',
  `keystone_level` TINYINT UNSIGNED NOT NULL COMMENT 'Keystone level',
  `score` INT NOT NULL DEFAULT 0 COMMENT 'Run score (can be negative on failure)',
  `deaths` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total deaths',
  `wipes` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total wipes',
  `completion_time` INT UNSIGNED DEFAULT NULL COMMENT 'Completion time in seconds (NULL if failed)',
  `success` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'TRUE if run completed successfully',
  `affix_pair_id` INT UNSIGNED DEFAULT NULL COMMENT 'Active affix pair',
  `group_members` JSON DEFAULT NULL COMMENT 'Array of participant GUIDs',
  `completed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Run completion timestamp',
  PRIMARY KEY (`run_id`),
  INDEX `idx_player_season` (`character_guid`, `season_id`, `completed_at` DESC),
  INDEX `idx_vault_eligibility` (`character_guid`, `season_id`, `success`, `completed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Complete Mythic+ run history for vault and statistics';

-- ========================================================================
-- Table: dc_weekly_vault
-- Purpose: Weekly Great Vault state and reward tracking
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_weekly_vault` (
  `character_guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season ID',
  `week_start` BIGINT UNSIGNED NOT NULL COMMENT 'Week start timestamp (Unix Tuesday reset)',
  `runs_completed` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Mythic+ runs this week',
  `highest_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Highest keystone cleared this week',
  `slot1_unlocked` BOOLEAN NOT NULL DEFAULT FALSE COMMENT '1+ runs',
  `slot2_unlocked` BOOLEAN NOT NULL DEFAULT FALSE COMMENT '4+ runs',
  `slot3_unlocked` BOOLEAN NOT NULL DEFAULT FALSE COMMENT '8+ runs',
  `reward_claimed` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'TRUE if player claimed their reward',
  `claimed_slot` TINYINT UNSIGNED DEFAULT NULL COMMENT 'Which slot was claimed (1/2/3)',
  `claimed_item_id` INT UNSIGNED DEFAULT NULL COMMENT 'Item entry claimed (NULL if tokens)',
  `claimed_tokens` INT UNSIGNED DEFAULT NULL COMMENT 'Token count claimed (NULL if item)',
  `claimed_at` TIMESTAMP NULL DEFAULT NULL COMMENT 'Claim timestamp',
  PRIMARY KEY (`character_guid`, `season_id`, `week_start`),
  INDEX `idx_pending_rewards` (`season_id`, `week_start`, `reward_claimed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Weekly Great Vault progress and reward claims';

-- ========================================================================
-- Table: dc_vault_reward_pool
-- Purpose: Generated reward options for each unlocked vault slot
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_vault_reward_pool` (
  `character_guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season ID',
  `week_start` BIGINT UNSIGNED NOT NULL COMMENT 'Week start timestamp',
  `slot` TINYINT UNSIGNED NOT NULL COMMENT 'Vault slot (1/2/3)',
  `item_entry` INT UNSIGNED NOT NULL COMMENT 'Item entry from item_template',
  `item_level` SMALLINT UNSIGNED NOT NULL COMMENT 'Item level',
  `token_alternative` INT UNSIGNED NOT NULL COMMENT 'Token count if player chooses tokens instead',
  PRIMARY KEY (`character_guid`, `season_id`, `week_start`, `slot`),
  FOREIGN KEY (`character_guid`, `season_id`, `week_start`) 
    REFERENCES `dc_weekly_vault`(`character_guid`, `season_id`, `week_start`) 
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Pre-generated vault reward options';

-- ========================================================================
-- Table: dc_token_rewards_log
-- Purpose: Tracks token rewards distributed at final boss kills
-- ========================================================================
CREATE TABLE IF NOT EXISTS `dc_token_rewards_log` (
  `log_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique log entry',
  `character_guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Dungeon map ID',
  `difficulty` TINYINT UNSIGNED NOT NULL COMMENT 'Difficulty (0=Normal, 1=Heroic, 3=Mythic)',
  `keystone_level` TINYINT UNSIGNED DEFAULT NULL COMMENT 'Mythic+ level (NULL for base Mythic)',
  `player_level` TINYINT UNSIGNED NOT NULL COMMENT 'Player level at time of reward',
  `tokens_awarded` INT UNSIGNED NOT NULL COMMENT 'Token count awarded',
  `boss_entry` INT UNSIGNED NOT NULL COMMENT 'Final boss creature entry',
  `awarded_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Reward timestamp',
  PRIMARY KEY (`log_id`),
  INDEX `idx_player_history` (`character_guid`, `awarded_at` DESC),
  INDEX `idx_dungeon_stats` (`map_id`, `difficulty`, `awarded_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Token reward history for final boss kills';

-- ========================================================================
-- Complete
-- ========================================================================
