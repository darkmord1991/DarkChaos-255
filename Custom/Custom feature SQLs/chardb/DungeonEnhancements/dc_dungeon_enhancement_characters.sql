-- ============================================================================
-- Dungeon Enhancement System - Characters Database Schema
-- ============================================================================
-- Purpose: Player-specific data for Mythic+ system
-- Prefix: dc_ (DarkChaos)
-- Tables: 5 total
-- ============================================================================

-- ============================================================================
-- Table: dc_mythic_player_rating
-- Purpose: Track player seasonal rating and rank
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_player_rating` (
    `seasonId` INT UNSIGNED NOT NULL,
    `playerGUID` BIGINT UNSIGNED NOT NULL,
    `rating` INT UNSIGNED NOT NULL DEFAULT 0,
    `rank` VARCHAR(50) DEFAULT 'Unranked',
    `lastUpdated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`seasonId`, `playerGUID`),
    INDEX `idx_season` (`seasonId`),
    INDEX `idx_rating` (`rating` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Player seasonal Mythic+ rating and rank';

-- ============================================================================
-- Table: dc_mythic_keystones
-- Purpose: Track player keystones (inventory)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_keystones` (
    `playerGUID` BIGINT UNSIGNED NOT NULL,
    `keystoneLevel` TINYINT UNSIGNED NOT NULL DEFAULT 2,
    `keystoneItemEntry` INT UNSIGNED NOT NULL,
    `obtainedDate` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`playerGUID`),
    INDEX `idx_level` (`keystoneLevel`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Player keystone inventory';

-- ============================================================================
-- Table: dc_mythic_run_history
-- Purpose: Historical record of completed/failed runs
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_run_history` (
    `runId` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `seasonId` INT UNSIGNED NOT NULL,
    `playerGUID` BIGINT UNSIGNED NOT NULL,
    `mapId` SMALLINT UNSIGNED NOT NULL,
    `keystoneLevel` TINYINT UNSIGNED NOT NULL,
    `completionTime` INT UNSIGNED NOT NULL COMMENT 'Seconds elapsed',
    `deaths` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `success` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1=completed, 0=failed',
    `tokensAwarded` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `completedDate` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`runId`),
    INDEX `idx_player_season` (`playerGUID`, `seasonId`),
    INDEX `idx_map_level` (`mapId`, `keystoneLevel`),
    INDEX `idx_date` (`completedDate` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Historical record of Mythic+ runs';

-- ============================================================================
-- Table: dc_mythic_vault_progress
-- Purpose: Weekly vault progress tracking
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_vault_progress` (
    `playerGUID` BIGINT UNSIGNED NOT NULL,
    `seasonId` INT UNSIGNED NOT NULL,
    `completedDungeons` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Dungeons completed this week',
    `slot1Claimed` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 dungeon reward claimed',
    `slot2Claimed` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '4 dungeons reward claimed',
    `slot3Claimed` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '8 dungeons reward claimed',
    `lastResetDate` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Last weekly reset',
    PRIMARY KEY (`playerGUID`, `seasonId`),
    INDEX `idx_season` (`seasonId`),
    INDEX `idx_progress` (`completedDungeons`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Weekly Great Vault progress';

-- ============================================================================
-- Table: dc_mythic_achievement_progress
-- Purpose: Track achievement progress and completion
-- ============================================================================
CREATE TABLE IF NOT EXISTS `dc_mythic_achievement_progress` (
    `playerGUID` BIGINT UNSIGNED NOT NULL,
    `achievementId` INT UNSIGNED NOT NULL,
    `progress` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Current progress count',
    `completedDate` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`playerGUID`, `achievementId`),
    INDEX `idx_achievement` (`achievementId`),
    INDEX `idx_completed` (`completedDate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Mythic+ achievement progress tracking';

-- ============================================================================
-- END OF CHARACTERS DATABASE SCHEMA
-- ============================================================================
