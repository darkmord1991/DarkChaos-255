-- =====================================================================
-- DarkChaos-255 Prestige System - Reward Columns Migration
-- =====================================================================
-- Adds prestige point tracking and per-prestige reward logging columns.
-- Safe to run multiple times.
-- =====================================================================

SET @schema := DATABASE();

SELECT IF(
    EXISTS(
        SELECT 1
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = @schema
          AND TABLE_NAME = 'dc_character_prestige'
          AND COLUMN_NAME = 'prestige_points'
    ),
    'SELECT 1',
    'ALTER TABLE `dc_character_prestige` ADD COLUMN `prestige_points` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Total prestige points earned'' AFTER `total_prestiges`'
) INTO @sql;
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT IF(
    EXISTS(
        SELECT 1
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = @schema
          AND TABLE_NAME = 'dc_character_prestige_log'
          AND COLUMN_NAME = 'awarded_points'
    ),
    'SELECT 1',
    'ALTER TABLE `dc_character_prestige_log` ADD COLUMN `awarded_points` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Prestige points granted for this prestige'' AFTER `kept_gear`'
) INTO @sql;
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT IF(
    EXISTS(
        SELECT 1
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = @schema
          AND TABLE_NAME = 'dc_character_prestige_log'
          AND COLUMN_NAME = 'awarded_tokens'
    ),
    'SELECT 1',
    'ALTER TABLE `dc_character_prestige_log` ADD COLUMN `awarded_tokens` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Upgrade tokens granted for this prestige'' AFTER `awarded_points`'
) INTO @sql;
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT IF(
    EXISTS(
        SELECT 1
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = @schema
          AND TABLE_NAME = 'dc_character_prestige_log'
          AND COLUMN_NAME = 'awarded_essence'
    ),
    'SELECT 1',
    'ALTER TABLE `dc_character_prestige_log` ADD COLUMN `awarded_essence` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Artifact essence granted for this prestige'' AFTER `awarded_tokens`'
) INTO @sql;
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
