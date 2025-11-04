/*
 * DarkChaos Item Upgrade System - Phase 3C Token Acquisition Schema
 * 
 * This file creates additional tables and modifies existing ones to support
 * the token acquisition system. Execute AFTER Phase 2 schema.
 * 
 * Tables created/modified:
 * 1. dc_token_transaction_log - Audit trail of all token awards/deductions
 * 2. Updates to dc_player_upgrade_tokens - Add weekly tracking columns
 * 
 * Execute on: azerothcore_characters database
 */

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8mb4 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- =========================================================================
-- TABLE: dc_token_transaction_log
-- PURPOSE: Comprehensive audit trail of all token awards and deductions
-- =========================================================================

CREATE TABLE IF NOT EXISTS `dc_token_transaction_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique transaction ID',
  `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID from characters table',
  `event_type` VARCHAR(50) NOT NULL COMMENT 'Event type: Quest, Creature, PvP, Achievement, Battleground, Admin',
  `token_change` INT SIGNED NOT NULL DEFAULT 0 COMMENT 'Upgrade tokens earned (+) or spent (-)',
  `essence_change` INT SIGNED NOT NULL DEFAULT 0 COMMENT 'Artifact essence earned (+) or spent (-)',
  `reason` VARCHAR(255) NOT NULL COMMENT 'Human-readable reason (e.g., "Quest: The Basilisk", "PvP Kill vs Horde")',
  `source_id` INT UNSIGNED DEFAULT NULL COMMENT 'Source ID (quest_id, creature_id, achievement_id, etc.)',
  `source_type` VARCHAR(50) DEFAULT NULL COMMENT 'Source type matching event_type',
  `balance_tokens_after` INT UNSIGNED DEFAULT NULL COMMENT 'Token balance after transaction',
  `balance_essence_after` INT UNSIGNED DEFAULT NULL COMMENT 'Essence balance after transaction',
  `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When transaction occurred',
  `season` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season this occurred in',
  PRIMARY KEY (`id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_event_type` (`event_type`),
  KEY `idx_timestamp` (`timestamp`),
  KEY `idx_season` (`season`),
  KEY `idx_player_time` (`player_guid`, `timestamp`),
  KEY `idx_event_source` (`event_type`, `source_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
  COMMENT='Token transaction audit log for tracking all token acquisitions and spending';

-- =========================================================================
-- TABLE: dc_token_event_config
-- PURPOSE: Configure which events award tokens and how much
-- =========================================================================

CREATE TABLE IF NOT EXISTS `dc_token_event_config` (
  `event_id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique event config ID',
  `event_type` ENUM('quest', 'creature', 'achievement', 'pvp', 'battleground', 'daily') NOT NULL COMMENT 'Type of event',
  `event_source_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Source ID (quest_id, creature_id, achievement_id, etc.; 0 for general PvP)',
  `token_reward` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Base upgrade tokens awarded',
  `essence_reward` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Base artifact essence awarded',
  `scaling_factor` FLOAT DEFAULT 1.0 COMMENT 'Multiplier for difficulty/level scaling (1.0 = no scaling)',
  `cooldown_seconds` INT UNSIGNED DEFAULT 0 COMMENT 'Cooldown between awards (0 = no cooldown)',
  `is_active` TINYINT UNSIGNED DEFAULT 1 COMMENT 'Is this event currently active',
  `is_repeatable` TINYINT UNSIGNED DEFAULT 1 COMMENT 'Can award be earned multiple times (0 = one-time like achievements)',
  `season` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season this config applies to',
  `notes` VARCHAR(255) DEFAULT NULL COMMENT 'Notes about this event config',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When this config was created',
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'When last updated',
  PRIMARY KEY (`event_id`),
  UNIQUE KEY `uix_event_source` (`event_type`, `event_source_id`, `season`),
  KEY `idx_event_type` (`event_type`),
  KEY `idx_is_active` (`is_active`),
  KEY `idx_season` (`season`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
  COMMENT='Configuration for which events award tokens and how much';

-- =========================================================================
-- TABLE MODIFICATIONS: Add columns to dc_player_upgrade_tokens
-- =========================================================================

-- Add weekly tracking columns (safe for older MySQL versions)
-- Script checks if columns exist before adding (via application logic)
ALTER TABLE `dc_player_upgrade_tokens` 
ADD COLUMN `weekly_earned` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Upgrade tokens earned this week' AFTER `amount`;

ALTER TABLE `dc_player_upgrade_tokens` 
ADD COLUMN `week_reset_at` TIMESTAMP NULL COMMENT 'Last weekly reset timestamp' AFTER `weekly_earned`;

ALTER TABLE `dc_player_upgrade_tokens` 
ADD COLUMN `last_transaction_at` TIMESTAMP NULL COMMENT 'Last transaction timestamp' AFTER `week_reset_at`;

-- =========================================================================
-- Insert Default Token Event Configurations
-- =========================================================================

-- Default quest token rewards (populate based on quest level/difficulty)
-- These are examples; adjust amounts as needed

DELETE FROM `dc_token_event_config` WHERE `season` = 1;

-- Quest completions: generic rule for auto-scaled quests
INSERT INTO `dc_token_event_config` 
(`event_type`, `event_source_id`, `token_reward`, `essence_reward`, `scaling_factor`, `is_active`, `is_repeatable`, `season`, `notes`) 
VALUES 
('quest', 0, 10, 0, 1.0, 1, 1, 1, 'Default quest reward; scaling applied by code based on difficulty'),
('creature', 0, 5, 0, 1.0, 1, 1, 1, 'Default creature kill reward; scaling for bosses applied by code'),
('pvp', 0, 15, 0, 1.0, 1, 1, 1, 'PvP kill reward; scaled by opponent level'),
('achievement', 0, 0, 50, 0.0, 1, 0, 1, 'Achievement essence reward; one-time only'),
('battleground', 0, 25, 0, 1.0, 1, 1, 1, 'Battleground win reward; loss rewards 5 tokens');

-- =========================================================================
-- Indexes for Performance
-- =========================================================================

-- Ensure good query performance for common lookups
-- Note: These may fail if indexes already exist; that's OK (safe to ignore errors)
ALTER TABLE `dc_player_upgrade_tokens` 
ADD KEY `idx_week_reset` (`week_reset_at`) COMMENT 'For weekly reset queries';

ALTER TABLE `dc_player_artifact_discoveries` 
ADD KEY `idx_discovered_at` (`discovered_at`) COMMENT 'For discovery timeline queries';

-- =========================================================================
-- Summary of Changes
-- =========================================================================

-- New tables:
-- 1. dc_token_transaction_log (audit trail)
-- 2. dc_token_event_config (event configuration)

-- Modified tables:
-- 1. dc_player_upgrade_tokens (added weekly_earned, week_reset_at, last_transaction_at)

-- =========================================================================

/*!40101 SET TIME_ZONE=@OLD_TIME_ZONE */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
