/*
 * Migration script for dc_player_keystones table
 * Adds missing columns: expires_on and last_updated
 * 
 * This script is safe to run multiple times - it checks for column existence
 */

-- Add expires_on column if it doesn't exist
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'dc_player_keystones'
  AND COLUMN_NAME = 'expires_on';

SET @query = IF(@col_exists = 0,
    'ALTER TABLE `dc_player_keystones` ADD COLUMN `expires_on` BIGINT UNSIGNED DEFAULT 0 COMMENT ''Unix timestamp when keystone expires'' AFTER `last_keystone_used`',
    'SELECT ''Column expires_on already exists'' AS message');

PREPARE stmt FROM @query;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add last_updated column if it doesn't exist
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'dc_player_keystones'
  AND COLUMN_NAME = 'last_updated';

SET @query = IF(@col_exists = 0,
    'ALTER TABLE `dc_player_keystones` ADD COLUMN `last_updated` INT UNSIGNED DEFAULT 0 COMMENT ''Unix timestamp of last keystone update'' AFTER `expires_on`',
    'SELECT ''Column last_updated already exists'' AS message');

PREPARE stmt FROM @query;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Update existing rows to have current timestamp in last_updated if they have 0
UPDATE `dc_player_keystones` 
SET `last_updated` = UNIX_TIMESTAMP() 
WHERE `last_updated` = 0;
