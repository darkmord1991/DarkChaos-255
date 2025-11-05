-- =====================================================================
-- DarkChaos Item Upgrade System - Phase 5: Transmutation Character DB Schema
--
-- Character database tables for the transmutation system.
-- Player-specific data, sessions, and logs.
--
-- Author: DarkChaos Development Team
-- Date: November 5, 2025
--
-- This file contains ONLY character database (acore_characters) tables.
-- =====================================================================

-- =====================================================================
-- CHARACTER DATABASE TABLES (acore_characters)
-- Player-specific data, sessions, and logs
-- =====================================================================

-- =====================================================================
-- Synthesis Cooldowns Table
-- =====================================================================

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_synthesis_cooldowns` (
    `player_guid` INT UNSIGNED NOT NULL,
    `recipe_id` INT UNSIGNED NOT NULL,
    `cooldown_end` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`player_guid`, `recipe_id`),
    INDEX `idx_cooldown_end` (`cooldown_end`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- Synthesis Log Table
-- =====================================================================

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_synthesis_log` (
    `log_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `recipe_id` INT UNSIGNED NOT NULL,
    `success` TINYINT UNSIGNED NOT NULL,
    `attempt_time` INT UNSIGNED NOT NULL,
    `consumed_items` TEXT,
    PRIMARY KEY (`log_id`),
    INDEX `idx_player_guid` (`player_guid`),
    INDEX `idx_recipe_id` (`recipe_id`),
    INDEX `idx_attempt_time` (`attempt_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- Transmutation Sessions Table
-- =====================================================================

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_transmutation_sessions` (
    `session_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `recipe_id` INT UNSIGNED NOT NULL,
    `start_time` INT UNSIGNED NOT NULL,
    `end_time` INT UNSIGNED NOT NULL,
    `completed` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `success` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `input_item_guid` INT UNSIGNED NOT NULL DEFAULT 0,
    `target_tier` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `source_tier` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`session_id`),
    INDEX `idx_player_guid` (`player_guid`),
    INDEX `idx_completed` (`completed`),
    INDEX `idx_end_time` (`end_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- Currency Exchange Log Table
-- =====================================================================

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_currency_exchange_log` (
    `log_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `exchange_type` ENUM('tokens_to_essence', 'essence_to_tokens') NOT NULL,
    `amount` INT UNSIGNED NOT NULL,
    `exchange_rate` DECIMAL(5,2) NOT NULL,
    `exchange_time` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`log_id`),
    INDEX `idx_player_guid` (`player_guid`),
    INDEX `idx_exchange_time` (`exchange_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- Update existing upgrade tables if needed (Character DB)
-- =====================================================================

-- Add transmutation columns to existing upgrade state table if it exists
-- Only proceed if the table exists and columns don't exist
DELIMITER //

CREATE PROCEDURE AddTransmutationColumns()
BEGIN
    DECLARE table_exists INT DEFAULT 0;
    DECLARE column_exists INT DEFAULT 0;

    -- Check if table exists
    SELECT COUNT(*) INTO table_exists
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'dc_item_upgrade_states';

    IF table_exists > 0 THEN
        -- Check if transmutation_count column exists
        SELECT COUNT(*) INTO column_exists
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'dc_item_upgrade_states'
        AND COLUMN_NAME = 'transmutation_count';

        IF column_exists = 0 THEN
            ALTER TABLE `dc_item_upgrade_states` ADD COLUMN `transmutation_count` INT UNSIGNED NOT NULL DEFAULT 0;
        END IF;

        -- Check if last_transmutation column exists
        SELECT COUNT(*) INTO column_exists
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'dc_item_upgrade_states'
        AND COLUMN_NAME = 'last_transmutation';

        IF column_exists = 0 THEN
            ALTER TABLE `dc_item_upgrade_states` ADD COLUMN `last_transmutation` INT UNSIGNED NOT NULL DEFAULT 0;
        END IF;

        -- Check if index exists
        SELECT COUNT(*) INTO column_exists
        FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'dc_item_upgrade_states'
        AND INDEX_NAME = 'idx_transmutation_count';

        IF column_exists = 0 THEN
            ALTER TABLE `dc_item_upgrade_states` ADD INDEX `idx_transmutation_count` (`transmutation_count`);
        END IF;
    END IF;
END //

DELIMITER ;

-- Execute the procedure
CALL AddTransmutationColumns();

-- Drop the procedure after use
DROP PROCEDURE AddTransmutationColumns;

-- =====================================================================
-- Cleanup old data (optional) - Character DB
-- =====================================================================

-- Remove expired cooldowns (run this periodically)
DELETE FROM `dc_item_upgrade_synthesis_cooldowns` WHERE `cooldown_end` < UNIX_TIMESTAMP();

-- =====================================================================
-- Permissions and Grants (Character DB)
-- =====================================================================

-- Note: Adjust these based on your database user permissions
-- Character DB permissions:
-- GRANT SELECT, INSERT, UPDATE, DELETE ON `dc_item_upgrade_synthesis_cooldowns` TO 'acore'@'localhost';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON `dc_item_upgrade_synthesis_log` TO 'acore'@'localhost';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON `dc_item_upgrade_transmutation_sessions` TO 'acore'@'localhost';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON `dc_item_upgrade_currency_exchange_log` TO 'acore'@'localhost';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON `dc_item_upgrade_states` TO 'acore'@'localhost';