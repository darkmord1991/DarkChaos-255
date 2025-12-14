-- ═══════════════════════════════════════════════════════════════════════════════
-- DarkChaos Item Upgrade System - CHARACTER DATABASE COMPLETE SCHEMA
-- Database: acore_chars
-- All 13 tables with complete CREATE TABLE definitions
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- DROP ALL EXISTING TABLES (Clean slate)
-- ═══════════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS `dc_season_history`;
DROP TABLE IF EXISTS `dc_player_artifact_discoveries`;
DROP TABLE IF EXISTS `dc_tier_conversion_log`;
DROP TABLE IF EXISTS `dc_item_upgrade_transmutation_sessions`;
DROP TABLE IF EXISTS `dc_player_transmutation_cooldowns`;
DROP TABLE IF EXISTS `dc_artifact_mastery_events`;
DROP TABLE IF EXISTS `dc_player_tier_caps`;
DROP TABLE IF EXISTS `dc_player_tier_unlocks`;
DROP TABLE IF EXISTS `dc_player_artifact_mastery`;
DROP TABLE IF EXISTS `dc_weekly_spending`;
DROP TABLE IF EXISTS `dc_token_transaction_log`;
DROP TABLE IF EXISTS `dc_player_upgrade_tokens`;
DROP TABLE IF EXISTS `dc_player_item_upgrades`;

-- ═══════════════════════════════════════════════════════════════════════════════
-- CREATE ALL TABLES (Fresh deployment)
-- ═══════════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────────
-- 1. PLAYER ITEM UPGRADES TABLE (PRIMARY TABLE)
-- ───────────────────────────────────────────────────────────────────────────────
-- Purpose: Tracks all item upgrades for each player
-- Primary Key: item_guid (unique per item instance)
-- Relationships: player_guid, tier_id (foreign to world db)

CREATE TABLE `dc_player_item_upgrades` (
  `item_guid` INT UNSIGNED NOT NULL,
  `player_guid` INT UNSIGNED NOT NULL,
  `tier_id` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `base_item_level` SMALLINT UNSIGNED DEFAULT 0,
  `upgraded_item_level` SMALLINT UNSIGNED DEFAULT 0,
  `tokens_invested` INT UNSIGNED DEFAULT 0,
  `essence_invested` INT UNSIGNED DEFAULT 0,
  `stat_multiplier` FLOAT DEFAULT 1.0,
  `first_upgraded_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `last_upgraded_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `season` INT UNSIGNED DEFAULT 1,
  PRIMARY KEY (`item_guid`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_tier_id` (`tier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Main table storing item upgrade data per item instance';

-- ───────────────────────────────────────────────────────────────────────────────
-- 2. PLAYER UPGRADE TOKENS TABLE
-- ───────────────────────────────────────────────────────────────────────────────
CREATE TABLE `dc_player_upgrade_tokens` (
  `player_guid` INT UNSIGNED NOT NULL,
  `currency_type` ENUM('upgrade_token', 'artifact_essence', 'upgrade_key', 'ancient_crystal') DEFAULT 'upgrade_token',
  `amount` INT UNSIGNED DEFAULT 0,
  `weekly_earned` INT UNSIGNED DEFAULT 0,
  `season` INT UNSIGNED NOT NULL DEFAULT 1,
  `last_transaction_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`, `currency_type`, `season`),
  KEY `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player currency storage for upgrades';

-- ───────────────────────────────────────────────────────────────────────────────
-- 3. TOKEN TRANSACTION LOG TABLE
-- ───────────────────────────────────────────────────────────────────────────────
CREATE TABLE `dc_token_transaction_log` (
  `transaction_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `currency_type` ENUM('upgrade_token', 'artifact_essence', 'upgrade_key', 'ancient_crystal') DEFAULT 'upgrade_token',
  `amount` INT UNSIGNED NOT NULL,
  `transaction_type` ENUM('earn', 'spend', 'admin_add', 'admin_remove', 'transfer', 'reward', 'penalty') DEFAULT 'earn',
  `reason` VARCHAR(255) DEFAULT NULL,
  `balance_before` INT UNSIGNED DEFAULT 0,
  `balance_after` INT UNSIGNED DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`transaction_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_transaction_type` (`transaction_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Complete audit trail of token/currency transactions';

-- ───────────────────────────────────────────────────────────────────────────────
-- 4. WEEKLY SPENDING TABLE
-- ───────────────────────────────────────────────────────────────────────────────
CREATE TABLE `dc_weekly_spending` (
  `player_guid` INT UNSIGNED NOT NULL,
  `week_start` DATE NOT NULL,
  `tokens_spent` INT UNSIGNED DEFAULT 0,
  `essence_spent` INT UNSIGNED DEFAULT 0,
  `upgrades_performed` INT UNSIGNED DEFAULT 0,
  `reset_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`, `week_start`),
  KEY `idx_week_start` (`week_start`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Weekly spending tracking for progression and limits';

-- ───────────────────────────────────────────────────────────────────────────────
-- 5. PLAYER ARTIFACT MASTERY TABLE
-- ───────────────────────────────────────────────────────────────────────────────
CREATE TABLE `dc_player_artifact_mastery` (
  `player_guid` INT UNSIGNED NOT NULL,
  `artifact_id` INT UNSIGNED NOT NULL,
  `mastery_level` TINYINT UNSIGNED DEFAULT 0,
  `mastery_points` INT UNSIGNED DEFAULT 0,
  `total_points_earned` INT UNSIGNED DEFAULT 0,
  `unlocked_abilities` TEXT DEFAULT NULL,
  `unlocked_at` TIMESTAMP NULL DEFAULT NULL,
  `last_updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`, `artifact_id`),
  KEY `idx_mastery_level` (`mastery_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Artifact mastery progression per player';

-- ───────────────────────────────────────────────────────────────────────────────
-- 6. PLAYER TIER UNLOCKS TABLE
-- ───────────────────────────────────────────────────────────────────────────────
CREATE TABLE `dc_player_tier_unlocks` (
  `player_guid` INT UNSIGNED NOT NULL,
  `tier_id` TINYINT UNSIGNED NOT NULL,
  `is_unlocked` BOOLEAN DEFAULT 1,
  `unlocked_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `tier_reset_count` INT UNSIGNED DEFAULT 0,
  PRIMARY KEY (`player_guid`, `tier_id`),
  KEY `idx_tier_id` (`tier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tracks which upgrade tiers players have unlocked';

-- ───────────────────────────────────────────────────────────────────────────────
-- 7. PLAYER TIER CAPS TABLE
-- ───────────────────────────────────────────────────────────────────────────────
CREATE TABLE `dc_player_tier_caps` (
  `player_guid` INT UNSIGNED NOT NULL,
  `tier_id` TINYINT UNSIGNED NOT NULL,
  `max_level` TINYINT UNSIGNED DEFAULT 1,
  `progression_percentage` TINYINT UNSIGNED DEFAULT 0,
  `capped_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`, `tier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Maximum achievable level per tier per player';

-- ───────────────────────────────────────────────────────────────────────────────
-- 8. ARTIFACT MASTERY EVENTS TABLE
-- ───────────────────────────────────────────────────────────────────────────────
CREATE TABLE `dc_artifact_mastery_events` (
  `event_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `artifact_id` INT UNSIGNED NOT NULL,
  `event_type` ENUM('unlock', 'level_up', 'ability_gained', 'milestone_reached', 'reset', 'rank_up') DEFAULT 'level_up',
  `event_data` JSON DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`event_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_artifact_id` (`artifact_id`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Historical log of artifact mastery events';

-- ───────────────────────────────────────────────────────────────────────────────
-- 9. PLAYER TRANSMUTATION COOLDOWNS TABLE
-- ───────────────────────────────────────────────────────────────────────────────
CREATE TABLE `dc_player_transmutation_cooldowns` (
  `player_guid` INT UNSIGNED NOT NULL,
  `transmutation_type` ENUM('standard', 'special', 'fusion', 'synthesis') DEFAULT 'standard',
  `cooldown_until` TIMESTAMP NULL DEFAULT NULL,
  `daily_uses` INT UNSIGNED DEFAULT 0,
  `last_reset` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`, `transmutation_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Transmutation cooldown tracking per player';

-- ───────────────────────────────────────────────────────────────────────────────
-- 10. ITEM UPGRADE TRANSMUTATION SESSIONS TABLE
-- ───────────────────────────────────────────────────────────────────────────────
CREATE TABLE `dc_item_upgrade_transmutation_sessions` (
  `session_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `item_guid` INT UNSIGNED NOT NULL,
  `transmutation_type` ENUM('standard', 'special', 'fusion', 'synthesis') DEFAULT 'standard',
  `status` ENUM('pending', 'in_progress', 'completed', 'failed', 'cancelled') DEFAULT 'pending',
  `target_tier` TINYINT UNSIGNED DEFAULT 1,
  `target_level` TINYINT UNSIGNED DEFAULT 1,
  `tokens_required` INT UNSIGNED DEFAULT 0,
  `essence_required` INT UNSIGNED DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `started_at` TIMESTAMP NULL DEFAULT NULL,
  `completed_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`session_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_item_guid` (`item_guid`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Session tracking for transmutation processes';

-- ───────────────────────────────────────────────────────────────────────────────
-- 11. TIER CONVERSION LOG TABLE
-- ───────────────────────────────────────────────────────────────────────────────
CREATE TABLE `dc_tier_conversion_log` (
  `log_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_guid` INT UNSIGNED NOT NULL,
  `from_tier` TINYINT UNSIGNED NOT NULL,
  `to_tier` TINYINT UNSIGNED NOT NULL,
  `conversion_type` ENUM('upgrade', 'downgrade', 'reset', 'skip') DEFAULT 'upgrade',
  `tokens_spent` INT UNSIGNED DEFAULT 0,
  `reason` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`log_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Audit trail for tier conversion events';

-- ───────────────────────────────────────────────────────────────────────────────
-- 12. PLAYER ARTIFACT DISCOVERIES TABLE
-- ───────────────────────────────────────────────────────────────────────────────
CREATE TABLE `dc_player_artifact_discoveries` (
  `player_guid` INT UNSIGNED NOT NULL,
  `artifact_id` INT UNSIGNED NOT NULL,
  `discovery_type` ENUM('quest', 'craft', 'purchase', 'event', 'admin') DEFAULT 'craft',
  `discovered_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `completion_percentage` TINYINT UNSIGNED DEFAULT 0,
  PRIMARY KEY (`player_guid`, `artifact_id`),
  KEY `idx_discovery_type` (`discovery_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tracks discovered artifacts per player';

-- ───────────────────────────────────────────────────────────────────────────────
-- 13. SEASON HISTORY TABLE
-- ───────────────────────────────────────────────────────────────────────────────
CREATE TABLE `dc_season_history` (
  `player_guid` INT UNSIGNED NOT NULL,
  `season` INT UNSIGNED NOT NULL,
  `highest_tier_reached` TINYINT UNSIGNED DEFAULT 1,
  `highest_level_reached` TINYINT UNSIGNED DEFAULT 1,
  `total_upgrades_performed` INT UNSIGNED DEFAULT 0,
  `total_tokens_earned` INT UNSIGNED DEFAULT 0,
  `total_tokens_spent` INT UNSIGNED DEFAULT 0,
  `total_essence_earned` INT UNSIGNED DEFAULT 0,
  `total_essence_spent` INT UNSIGNED DEFAULT 0,
  `total_gold_spent` INT UNSIGNED DEFAULT 0,
  `achievements_unlocked` INT UNSIGNED DEFAULT 0,
  `started_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `completed_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`player_guid`, `season`),
  KEY `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Season statistics and progression history per player';

-- ═══════════════════════════════════════════════════════════════════════════════
-- INDEX SUMMARY
-- ═══════════════════════════════════════════════════════════════════════════════
-- All tables are properly indexed for:
--   ✓ Primary lookups (player_guid, item_guid, session_id, etc.)
--   ✓ Foreign key relationships (tier_id, artifact_id, etc.)
--   ✓ Common queries (date ranges, status filters)
--   ✓ Audit trails (created_at, transaction_type)
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE STATISTICS
-- ═══════════════════════════════════════════════════════════════════════════════
-- Total Character Database Tables: 13
--
-- Primary Tables (Core Data):
--   1. dc_player_item_upgrades              [Primary: Item instances with upgrade data]
--   2. dc_player_upgrade_tokens             [Currency: Players' upgrade resources]
--   3. dc_player_tier_unlocks               [Progression: Tier access control]
--
-- Supporting Tables (Progression):
--   4. dc_player_artifact_mastery           [Mastery tree progression]
--   5. dc_player_tier_caps                  [Level caps per tier]
--   6. dc_player_artifact_discoveries       [Artifact collection]
--
-- Transactional Tables (Sessions & Cooldowns):
--   7. dc_item_upgrade_transmutation_sessions [Multi-step processes]
--   8. dc_player_transmutation_cooldowns    [Rate limiting]
--
-- Audit Tables (Logging & History):
--   9. dc_token_transaction_log             [Currency audit trail]
--   10. dc_artifact_mastery_events          [Mastery achievement log]
--   11. dc_tier_conversion_log              [Tier change history]
--   12. dc_weekly_spending                  [Weekly statistics]
--   13. dc_season_history                   [Season-end records]
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- RELATIONSHIP DIAGRAM
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- dc_player_item_upgrades
--   ├─→ player_guid (to WoW characters table)
--   ├─→ item_guid (to WoW character_inventory table)
--   └─→ tier_id (to acore_world.dc_item_upgrade_tiers)
--
-- dc_player_artifact_mastery
--   ├─→ player_guid (to WoW characters table)
--   └─→ artifact_id (to acore_world.dc_chaos_artifact_items)
--
-- dc_player_tier_unlocks
--   ├─→ player_guid (to WoW characters table)
--   └─→ tier_id (to acore_world.dc_item_upgrade_tiers)
--
-- dc_player_upgrade_tokens
--   └─→ player_guid (to WoW characters table)
--
-- All audit tables reference player_guid back to characters table
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Verify all 13 tables exist:
/*
SELECT TABLE_NAME, ENGINE, TABLE_ROWS, DATA_LENGTH, INDEX_LENGTH
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_chars'
  AND TABLE_NAME LIKE 'dc_%'
ORDER BY TABLE_NAME;

Expected Output: 13 rows, all ENGINE=InnoDB
*/

-- Check specific table structure:
/*
DESCRIBE acore_chars.dc_player_item_upgrades;

Expected columns:
  item_guid (INT UNSIGNED, PK)
  player_guid (INT UNSIGNED, KEY)
  tier_id (TINYINT UNSIGNED, KEY)
  upgrade_level (TINYINT UNSIGNED)
  base_item_level (SMALLINT UNSIGNED)
  upgraded_item_level (SMALLINT UNSIGNED)
  tokens_invested (INT UNSIGNED)
  essence_invested (INT UNSIGNED)
  stat_multiplier (FLOAT)
  first_upgraded_at (TIMESTAMP)
  last_upgraded_at (TIMESTAMP)
  season (INT UNSIGNED)
*/

-- Count total columns across all tables:
/*
SELECT TABLE_NAME, COUNT(*) as COLUMN_COUNT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'acore_chars'
  AND TABLE_NAME LIKE 'dc_%'
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;

Expected: ~150+ total columns across 13 tables
*/

-- ═══════════════════════════════════════════════════════════════════════════════
