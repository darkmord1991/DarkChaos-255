-- =========================================================================
-- DarkChaos Item Upgrade System - Phase 1 Character DB Schema
-- Character Database Tables
-- =========================================================================

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- =========================================================================
-- TABLE: dc_player_upgrade_tokens
-- PURPOSE: Track player upgrade token currency (2 token types)
-- =========================================================================
CREATE TABLE IF NOT EXISTS `dc_player_upgrade_tokens` (
  `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID from characters table',
  `currency_type` ENUM('upgrade_token', 'artifact_essence') NOT NULL COMMENT 'Currency type (upgrade_token for T1-T4, artifact_essence for T5)',
  `amount` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Current amount of this currency',
  `season` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season this currency is for',
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
  PRIMARY KEY (`player_guid`, `currency_type`, `season`),
  KEY `idx_player_season` (`player_guid`, `season`),
  KEY `idx_currency_type` (`currency_type`),
  KEY `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player upgrade token currency tracking (simple 2-token economy)';

-- =========================================================================
-- TABLE: dc_player_item_upgrades
-- PURPOSE: Track upgrade level for individual items
-- =========================================================================
CREATE TABLE IF NOT EXISTS `dc_player_item_upgrades` (
  `item_guid` INT UNSIGNED NOT NULL UNIQUE COMMENT 'Item GUID from item_instance',
  `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID from characters table',
  `tier_id` TINYINT UNSIGNED NOT NULL COMMENT 'Item tier (1-5)',
  `upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Current upgrade level (0-5)',
  `tokens_invested` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total upgrade tokens invested in this item',
  `essence_invested` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total artifact essence invested (T5 only)',
  `stat_multiplier` FLOAT NOT NULL DEFAULT 1.0 COMMENT 'Current stat multiplier (1.0-1.5 or 1.75 for artifacts)',
  `first_upgraded_at` TIMESTAMP NULL COMMENT 'When item was first upgraded',
  `last_upgraded_at` TIMESTAMP NULL COMMENT 'When item was last upgraded',
  `season` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season this upgrade is for',
  PRIMARY KEY (`item_guid`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_tier` (`tier_id`),
  KEY `idx_upgrade_level` (`upgrade_level`),
  KEY `idx_season` (`season`),
  KEY `idx_player_season` (`player_guid`, `season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player item upgrade tracking (one row per upgradeable item owned)';

-- =========================================================================
-- TABLE: dc_upgrade_transaction_log
-- PURPOSE: Audit log of all upgrade transactions
-- =========================================================================
CREATE TABLE IF NOT EXISTS `dc_upgrade_transaction_log` (
  `transaction_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique transaction ID',
  `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player performing upgrade',
  `item_guid` INT UNSIGNED NOT NULL COMMENT 'Item being upgraded',
  `tier_id` TINYINT UNSIGNED NOT NULL COMMENT 'Item tier',
  `upgrade_level_from` TINYINT UNSIGNED NOT NULL COMMENT 'Previous upgrade level',
  `upgrade_level_to` TINYINT UNSIGNED NOT NULL COMMENT 'New upgrade level',
  `tokens_cost` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Upgrade tokens spent',
  `essence_cost` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Artifact essence spent',
  `success` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Was upgrade successful',
  `transaction_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When transaction occurred',
  `season` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season this occurred in',
  PRIMARY KEY (`transaction_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_item_guid` (`item_guid`),
  KEY `idx_transaction_at` (`transaction_at`),
  KEY `idx_season` (`season`),
  KEY `idx_player_time` (`player_guid`, `transaction_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Upgrade transaction audit log';

-- =========================================================================
-- TABLE: dc_player_artifact_discoveries
-- PURPOSE: Track which prestige artifacts player has discovered
-- =========================================================================
CREATE TABLE IF NOT EXISTS `dc_player_artifact_discoveries` (
  `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID from characters table',
  `artifact_id` INT UNSIGNED NOT NULL COMMENT 'Artifact ID from dc_prestige_artifact_items',
  `discovered_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When artifact was discovered',
  `season` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season artifact was discovered',
  PRIMARY KEY (`player_guid`, `artifact_id`, `season`),
  KEY `idx_artifact_id` (`artifact_id`),
  KEY `idx_season` (`season`),
  KEY `idx_discovered_at` (`discovered_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Track player artifact discoveries for achievements';

-- =========================================================================
-- Summary of Character DB Tables:
-- 1. dc_player_upgrade_tokens: 2 rows per player per season (upgrade_token + artifact_essence)
-- 2. dc_player_item_upgrades: 1 row per owned upgradeable item (can be hundreds)
-- 3. dc_upgrade_transaction_log: Audit trail (grows per upgrade)
-- 4. dc_player_artifact_discoveries: Achievement tracking
-- =========================================================================

/*!40101 SET TIME_ZONE=@OLD_TIME_ZONE */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
