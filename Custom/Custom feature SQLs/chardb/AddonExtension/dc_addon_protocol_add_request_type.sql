-- ============================================================================
-- Migration: Add request_type column to dc_addon_protocol_log
-- ============================================================================
-- Run this if you already have the dc_addon_protocol_log table created.
-- This adds the request_type column to track STANDARD, JSON, or AIO messages.
-- ============================================================================

-- Add request_type column if it doesn't exist
SET @dbname = DATABASE();
SET @tablename = 'dc_addon_protocol_log';
SET @columnname = 'request_type';
SET @preparedStatement = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @columnname) > 0,
    'SELECT "Column already exists"',
    CONCAT('ALTER TABLE `', @tablename, '` ADD COLUMN `', @columnname, 
           "` ENUM('STANDARD', 'JSON', 'AIO') NOT NULL DEFAULT 'STANDARD' ",
           "COMMENT 'Protocol type: STANDARD (colon-delim), JSON, or AIO (Rochet2)' ",
           "AFTER `direction`")
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- Add index for request_type if it doesn't exist
SET @indexname = 'idx_request_type';
SET @preparedStatement = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
     WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND INDEX_NAME = @indexname) > 0,
    'SELECT "Index already exists"',
    CONCAT('ALTER TABLE `', @tablename, '` ADD INDEX `', @indexname, '` (`request_type`)')
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- Update existing rows to have proper request_type based on data_preview content
UPDATE `dc_addon_protocol_log` 
SET `request_type` = 
    CASE 
        WHEN `data_preview` LIKE '{%' THEN 'JSON'
        WHEN `data_preview` LIKE 'AIO%' OR `module` IN ('SPOT', 'SEAS') THEN 'AIO'
        ELSE 'STANDARD'
    END
WHERE `request_type` = 'STANDARD' AND `data_preview` IS NOT NULL;
