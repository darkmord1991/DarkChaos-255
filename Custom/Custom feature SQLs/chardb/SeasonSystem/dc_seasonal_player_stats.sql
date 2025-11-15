-- Seasonal Quest & Chest Reward System - Character Database Schema
-- Location: Custom/Custom feature SQLs/chardb/dc_seasonal_player_stats.sql
-- This file should be executed on the CHARACTER database

-- =====================================================================
-- TABLE: dc_player_seasonal_stats
-- =====================================================================
-- Tracks player statistics and progress within each season

DROP TABLE IF EXISTS `dc_player_seasonal_stats`;

CREATE TABLE `dc_player_seasonal_stats` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID',
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season ID',
  `total_tokens_earned` BIGINT UNSIGNED DEFAULT 0 COMMENT 'Total tokens earned this season',
  `total_essence_earned` BIGINT UNSIGNED DEFAULT 0 COMMENT 'Total essence earned this season',
  `quests_completed` INT UNSIGNED DEFAULT 0 COMMENT 'Total quests completed this season',
  `bosses_killed` INT UNSIGNED DEFAULT 0 COMMENT 'Total bosses killed this season',
  `chests_claimed` INT UNSIGNED DEFAULT 0 COMMENT 'Total chests opened this season',
  `weekly_tokens_earned` INT UNSIGNED DEFAULT 0 COMMENT 'Tokens earned this week',
  `weekly_essence_earned` INT UNSIGNED DEFAULT 0 COMMENT 'Essence earned this week',
  `weekly_reset_at` BIGINT UNSIGNED COMMENT 'Unix timestamp of last weekly reset',
  `season_best_run` VARCHAR(255) COMMENT 'Best achievement this season (JSON or text)',
  `last_reward_at` BIGINT UNSIGNED COMMENT 'Unix timestamp of last reward earned',
  `last_activity_at` BIGINT UNSIGNED COMMENT 'Unix timestamp of last activity',
  `joined_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_player_season` (`player_guid`, `season_id`) COMMENT 'One stat record per player per season',
  KEY `idx_season_id` (`season_id`),
  KEY `idx_tokens_earned` (`total_tokens_earned`),
  KEY `idx_last_activity` (`last_activity_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Player seasonal statistics - progress tracking';

-- =====================================================================
-- TABLE: dc_reward_transactions
-- =====================================================================
-- Audit trail for all reward transactions (quest/creature/chest)
-- Use for debugging, analytics, and transaction verification

DROP TABLE IF EXISTS `dc_reward_transactions`;

CREATE TABLE `dc_reward_transactions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player receiving reward',
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Season when reward earned',
  `transaction_type` ENUM('quest', 'creature', 'creature_group', 'chest', 'manual', 'adjustment') NOT NULL COMMENT 'Reward source type',
  `source_id` INT UNSIGNED COMMENT 'Quest ID or Creature ID (source of reward)',
  `source_name` VARCHAR(255) COMMENT 'Human-readable source name (Quest name, Creature name)',
  `reward_type` TINYINT COMMENT '1=Token, 2=Essence, 3=Both',
  `token_amount` INT UNSIGNED DEFAULT 0,
  `essence_amount` INT UNSIGNED DEFAULT 0,
  `base_amount` INT UNSIGNED COMMENT 'Amount before multipliers',
  `difficulty_multiplier` FLOAT DEFAULT 1.0 COMMENT 'Applied difficulty multiplier',
  `season_multiplier` FLOAT DEFAULT 1.0 COMMENT 'Applied season multiplier',
  `final_multiplier` FLOAT DEFAULT 1.0 COMMENT 'Total multiplier (difficulty × season)',
  `weekly_total_after` INT UNSIGNED COMMENT 'Weekly total after this transaction',
  `notes` VARCHAR(255) COMMENT 'Additional notes (e.g., group size, difficulty, reason for adjustment)',
  `transaction_at` BIGINT UNSIGNED NOT NULL COMMENT 'Unix timestamp of transaction',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  KEY `idx_player_season` (`player_guid`, `season_id`) COMMENT 'Query player transactions per season',
  KEY `idx_season_id` (`season_id`),
  KEY `idx_transaction_type` (`transaction_type`),
  KEY `idx_transaction_at` (`transaction_at`) COMMENT 'Query by time range',
  KEY `idx_source_id` (`source_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Audit trail: all reward transactions logged for verification and analytics';

-- =====================================================================
-- TABLE: dc_player_seasonal_chests
-- =====================================================================
-- Tracks claimed chests per player (prevents duplicate claims)

DROP TABLE IF EXISTS `dc_player_seasonal_chests`;

CREATE TABLE `dc_player_seasonal_chests` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `chest_id` VARCHAR(50) NOT NULL COMMENT 'Unique chest identifier (from quest/creature drop)',
  `chest_tier` TINYINT NOT NULL COMMENT 'Tier claimed: 1=Bronze, 2=Silver, 3=Gold, 4=Legendary',
  `items_received` JSON COMMENT 'Array of item entries claimed: [{item_id, count, ilvl}, ...]',
  `claimed_at` BIGINT UNSIGNED NOT NULL,
  `claimed_by_npc_guid` INT UNSIGNED COMMENT 'NPC GUID if claimed from NPC, else 0',
  `transaction_id` BIGINT UNSIGNED COMMENT 'Reference to dc_reward_transactions for logging',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  KEY `idx_player_season` (`player_guid`, `season_id`),
  KEY `idx_chest_id` (`chest_id`),
  KEY `idx_claimed_at` (`claimed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Prevents duplicate chest claims - tracks claimed chests per player';

-- =====================================================================
-- TABLE: dc_player_weekly_cap_snapshot
-- =====================================================================
-- Snapshots of weekly caps at each reset (historical tracking)

DROP TABLE IF EXISTS `dc_player_weekly_cap_snapshot`;

CREATE TABLE `dc_player_weekly_cap_snapshot` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `week_ending` DATE NOT NULL COMMENT 'Week ending date',
  `tokens_earned` INT UNSIGNED DEFAULT 0 COMMENT 'Tokens earned this week',
  `essence_earned` INT UNSIGNED DEFAULT 0 COMMENT 'Essence earned this week',
  `quests_completed` INT UNSIGNED DEFAULT 0,
  `bosses_killed` INT UNSIGNED DEFAULT 0,
  `chests_claimed` INT UNSIGNED DEFAULT 0,
  `snapshot_at` BIGINT UNSIGNED NOT NULL COMMENT 'When this snapshot was taken (reset time)',
  
  PRIMARY KEY (`id`),
  KEY `idx_player_season_week` (`player_guid`, `season_id`, `week_ending`),
  KEY `idx_week_ending` (`week_ending`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Historical snapshots of weekly caps - for analytics and auditing';

-- =====================================================================
-- TABLE: dc_player_seasonal_achievements
-- =====================================================================
-- Seasonal milestones/achievements reached by players

DROP TABLE IF EXISTS `dc_player_seasonal_achievements`;

CREATE TABLE `dc_player_seasonal_achievements` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `achievement_type` VARCHAR(50) NOT NULL COMMENT 'milestone_100_tokens, quest_spree_10, boss_slayer_50, etc',
  `achievement_name` VARCHAR(255) NOT NULL COMMENT 'Human-readable achievement name',
  `achievement_description` VARCHAR(255) COMMENT 'Description of what was achieved',
  `progress_value` INT UNSIGNED COMMENT 'Progress metric (100 tokens, 10 quests, etc)',
  `reward_tokens` INT UNSIGNED DEFAULT 0 COMMENT 'Bonus tokens for achievement',
  `reward_essence` INT UNSIGNED DEFAULT 0 COMMENT 'Bonus essence for achievement',
  `achieved_at` BIGINT UNSIGNED NOT NULL,
  `rewarded_at` BIGINT UNSIGNED COMMENT 'When rewards were distributed',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  KEY `idx_player_season` (`player_guid`, `season_id`),
  KEY `idx_achievement_type` (`achievement_type`),
  KEY `idx_achieved_at` (`achieved_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Seasonal achievements and milestone tracking';

-- =====================================================================
-- SAMPLE DATA FOR TESTING
-- =====================================================================

-- Example: Player GUID 1 joining Season 1
-- INSERT INTO `dc_player_seasonal_stats` (`player_guid`, `season_id`, `weekly_reset_at`)
-- VALUES (1, 1, UNIX_TIMESTAMP());

-- Example: Transaction log entry
-- INSERT INTO `dc_reward_transactions`
-- (`player_guid`, `season_id`, `transaction_type`, `source_id`, `source_name`, `reward_type`, `token_amount`, `essence_amount`, `base_amount`, `difficulty_multiplier`, `season_multiplier`, `transaction_at`)
-- VALUES (1, 1, 'quest', 12345, 'Defeat the Dragons', 1, 15, 0, 15, 1.0, 1.0, UNIX_TIMESTAMP());

-- =====================================================================
-- VIEWS (Optional - for easier querying)
-- =====================================================================

-- View: Player seasonal leaderboard
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

-- View: Top performers this week
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

-- View: Transaction audit summary
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
