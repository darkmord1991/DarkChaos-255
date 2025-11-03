-- ============================================================================
-- DUNGEON QUEST SYSTEM - CHARACTER DATABASE SCHEMA
-- ============================================================================
-- This file contains CHARACTER database tables for:
-- - Player dungeon quest progress tracking
-- - Quest completion history
-- - NPC respawn status (per-player)
-- - Player statistics and achievements
-- ============================================================================
-- Database: acore_characters
-- Prefix: dc_ (DarkChaos custom tables)
-- Version: 1.0 (Updated with dc_ prefix)
-- Date: November 3, 2025
-- ============================================================================

-- ============================================================================
-- PLAYER PROGRESS TRACKING
-- ============================================================================

-- Table: dc_character_dungeon_progress
-- Purpose: Track player progress through dungeon daily/weekly quests
-- Lifecycle: Reset daily/weekly via cron
CREATE TABLE IF NOT EXISTS `dc_character_dungeon_progress` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `dungeon_id` int unsigned NOT NULL COMMENT 'Dungeon ID from dc_dungeon_quest_mapping',
  `quest_id` int unsigned NOT NULL COMMENT 'Quest ID',
  `quest_type` enum('DAILY','WEEKLY','SPECIAL') NOT NULL DEFAULT 'DAILY' COMMENT 'Quest type',
  `status` enum('AVAILABLE','IN_PROGRESS','COMPLETED','FAILED') NOT NULL DEFAULT 'AVAILABLE' COMMENT 'Current quest status',
  `completion_count` int unsigned NOT NULL DEFAULT '0' COMMENT 'Times completed in this cycle',
  `last_completed` timestamp NULL DEFAULT NULL COMMENT 'Last completion time',
  `rewards_claimed` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Reward items claimed (0=no, 1=yes)',
  `token_amount` int unsigned NOT NULL DEFAULT '0' COMMENT 'Tokens earned',
  `gold_earned` int unsigned NOT NULL DEFAULT '0' COMMENT 'Gold earned',
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`, `dungeon_id`, `quest_id`),
  KEY `idx_dungeon` (`dungeon_id`),
  KEY `idx_quest` (`quest_id`),
  KEY `idx_status` (`status`),
  CONSTRAINT `fk_dungeon_progress_guid` 
    FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Track dungeon quest progress per character';

-- ============================================================================
-- PER-PLAYER DAILY / WEEKLY PROGRESS TABLES
-- These mirror the old unprefixed tables (player_daily_quest_progress, player_weekly_quest_progress)
-- but use the `dc_` prefix to avoid conflicts and follow DarkChaos conventions.
-- ============================================================================

-- Table: dc_player_daily_quest_progress
-- Purpose: Track per-player progress for individual daily dungeon quests
CREATE TABLE IF NOT EXISTS `dc_player_daily_quest_progress` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `daily_quest_entry` INT UNSIGNED NOT NULL COMMENT 'Daily quest entry id',
  `completed_today` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=no, 1=yes',
  `last_completed` TIMESTAMP NULL DEFAULT NULL COMMENT 'Last completion time',
  `created_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`, `daily_quest_entry`),
  KEY `idx_guid` (`guid`),
  KEY `idx_daily_entry` (`daily_quest_entry`),
  CONSTRAINT `fk_dc_player_daily_progress_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Per-player tracking for daily dungeon quest progress';

-- Table: dc_player_weekly_quest_progress
-- Purpose: Track per-player progress for individual weekly dungeon quests
CREATE TABLE IF NOT EXISTS `dc_player_weekly_quest_progress` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `weekly_quest_entry` INT UNSIGNED NOT NULL COMMENT 'Weekly quest entry id',
  `completed_this_week` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=no, 1=yes',
  `week_reset_date` TIMESTAMP NULL DEFAULT NULL COMMENT 'Last week reset timestamp',
  `last_completed` TIMESTAMP NULL DEFAULT NULL COMMENT 'Last completion time',
  `created_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`, `weekly_quest_entry`),
  KEY `idx_guid` (`guid`),
  KEY `idx_weekly_entry` (`weekly_quest_entry`),
  CONSTRAINT `fk_dc_player_weekly_progress_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Per-player tracking for weekly dungeon quest progress';

-- Table: dc_player_dungeon_completion_stats
-- Purpose: Track per-player dungeon completion and activity timestamps
CREATE TABLE IF NOT EXISTS `dc_player_dungeon_completion_stats` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `last_activity` TIMESTAMP NULL DEFAULT NULL COMMENT 'Last dungeon-related activity',
  `total_dungeons_completed` INT UNSIGNED NOT NULL DEFAULT 0,
  `total_quests_completed` INT UNSIGNED NOT NULL DEFAULT 0,
  `created_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`),
  KEY `idx_last_activity` (`last_activity`),
  CONSTRAINT `fk_dc_player_dungeon_stats_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Per-player dungeon completion stats and timestamps';

-- ============================================================================
-- QUEST COMPLETION HISTORY
-- ============================================================================

-- Table: dc_character_dungeon_quests_completed
-- Purpose: Historical record of completed quests for achievements
CREATE TABLE IF NOT EXISTS `dc_character_dungeon_quests_completed` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `dungeon_id` int unsigned NOT NULL COMMENT 'Dungeon ID',
  `quest_id` int unsigned NOT NULL COMMENT 'Quest ID',
  `completion_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `duration_seconds` int unsigned NOT NULL DEFAULT '0' COMMENT 'Time taken to complete',
  `party_size` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Party/group size',
  `difficulty` enum('NORMAL','HEROIC','MYTHIC') NOT NULL DEFAULT 'NORMAL',
  `tokens_earned` int unsigned NOT NULL DEFAULT '0',
  `gold_earned` int unsigned NOT NULL DEFAULT '0',
  `item_drops` text COMMENT 'JSON array of item IDs dropped',
  `achievement_triggered` tinyint unsigned DEFAULT '0' COMMENT 'Any achievement unlocked this run',
  PRIMARY KEY (`id`),
  KEY `idx_guid` (`guid`),
  KEY `idx_dungeon` (`dungeon_id`),
  KEY `idx_completion_time` (`completion_time`),
  CONSTRAINT `fk_completed_guid` 
    FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Historical dungeon quest completion log';

-- ============================================================================
-- NPC RESPAWN TRACKING (PER PLAYER)
-- ============================================================================

-- Table: dc_character_dungeon_npc_respawn
-- Purpose: Track NPC respawn status (combat-based despawn system)
-- Used for: "NPC disappeared at first combat" + "manual respawn outside combat"
CREATE TABLE IF NOT EXISTS `dc_character_dungeon_npc_respawn` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `npc_entry` int unsigned NOT NULL COMMENT 'NPC entry ID',
  `dungeon_id` int unsigned NOT NULL COMMENT 'Which dungeon',
  `is_despawned` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=spawned, 1=despawned',
  `despawn_time` timestamp NULL DEFAULT NULL COMMENT 'When NPC disappeared',
  `last_respawn_attempt` timestamp NULL DEFAULT NULL COMMENT 'Last respawn command used',
  `respawn_cooldown_until` timestamp NULL DEFAULT NULL COMMENT 'Respawn available after this time',
  PRIMARY KEY (`guid`, `npc_entry`, `dungeon_id`),
  KEY `idx_is_despawned` (`is_despawned`),
  KEY `idx_respawn_cooldown` (`respawn_cooldown_until`),
  CONSTRAINT `fk_respawn_guid` 
    FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Track NPC despawn/respawn status for combat-based system';

-- ============================================================================
-- PLAYER STATISTICS
-- ============================================================================

-- Table: dc_character_dungeon_statistics
-- Purpose: Track overall dungeon achievements and statistics
CREATE TABLE IF NOT EXISTS `dc_character_dungeon_statistics` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `total_quests_completed` int unsigned NOT NULL DEFAULT '0',
  `total_tokens_earned` int unsigned NOT NULL DEFAULT '0',
  `total_gold_earned` int unsigned NOT NULL DEFAULT '0',
  `total_dungeons_completed` int unsigned NOT NULL DEFAULT '0',
  `speedrun_records` int unsigned NOT NULL DEFAULT '0' COMMENT 'Speedrun achievements',
  `rare_creatures_defeated` int unsigned NOT NULL DEFAULT '0',
  `achievement_count` int unsigned NOT NULL DEFAULT '0',
  `title_count` int unsigned NOT NULL DEFAULT '0',
  `last_quest_completed` timestamp NULL DEFAULT NULL,
  `current_streak_days` int unsigned NOT NULL DEFAULT '0',
  `longest_streak_days` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`),
  KEY `idx_total_quests` (`total_quests_completed`),
  KEY `idx_total_tokens` (`total_tokens_earned`),
  CONSTRAINT `fk_stat_guid` 
    FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Overall statistics for dungeon quest achievements';

-- ============================================================================
-- DAILY/WEEKLY RESET TRACKING
-- ============================================================================

-- Table: dc_dungeon_instance_resets
-- Purpose: Track daily/weekly resets per player per dungeon
CREATE TABLE IF NOT EXISTS `dc_dungeon_instance_resets` (
  `reset_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `dungeon_id` int unsigned NOT NULL COMMENT 'Dungeon ID',
  `reset_type` enum('DAILY','WEEKLY') NOT NULL,
  `reset_date` date NOT NULL,
  `reset_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`reset_id`),
  UNIQUE KEY `uk_guid_dungeon_date` (`guid`, `dungeon_id`, `reset_date`, `reset_type`),
  KEY `idx_dungeon_id` (`dungeon_id`),
  KEY `idx_reset_date` (`reset_date`),
  CONSTRAINT `fk_reset_guid` 
    FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Track reset dates for daily/weekly quests';

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX idx_progress_guid_dungeon ON `dc_character_dungeon_progress` (`guid`, `dungeon_id`);
CREATE INDEX idx_progress_status_completed ON `dc_character_dungeon_progress` (`status`, `last_completed`);
CREATE INDEX idx_respawn_despawn_status ON `dc_character_dungeon_npc_respawn` (`is_despawned`, `respawn_cooldown_until`);

-- ============================================================================
-- END OF CHARACTER DATABASE SCHEMA
-- ============================================================================
