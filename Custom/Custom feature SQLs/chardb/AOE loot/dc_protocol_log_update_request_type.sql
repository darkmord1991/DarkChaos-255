-- ============================================================================
-- Migration: Update request_type ENUM values
-- ============================================================================
-- Run this on acore_characters to update the request_type column
-- ============================================================================

-- Update the ENUM to include new values
ALTER TABLE `dc_addon_protocol_log` 
MODIFY COLUMN `request_type` ENUM('STANDARD', 'DC_JSON', 'DC_PLAIN', 'AIO', 'JSON') 
NOT NULL DEFAULT 'DC_PLAIN' 
COMMENT 'Protocol format: STANDARD=Blizz addon msg, DC_JSON=DC protocol+JSON, DC_PLAIN=DC protocol+plain, AIO=AIO framework';

-- Migrate old 'JSON' values to 'DC_JSON' and old 'STANDARD' to 'DC_PLAIN'
-- (since most were actually DC protocol messages with JSON payloads)
UPDATE `dc_addon_protocol_log` SET `request_type` = 'DC_JSON' WHERE `request_type` = 'JSON';
UPDATE `dc_addon_protocol_log` SET `request_type` = 'DC_PLAIN' WHERE `request_type` = 'STANDARD' AND `module` != '';

-- Now remove the old 'JSON' value from ENUM (optional - keeps backward compat if you skip this)
-- ALTER TABLE `dc_addon_protocol_log` 
-- MODIFY COLUMN `request_type` ENUM('STANDARD', 'DC_JSON', 'DC_PLAIN', 'AIO') 
-- NOT NULL DEFAULT 'DC_PLAIN';

-- Verify the migration
SELECT request_type, COUNT(*) as count FROM dc_addon_protocol_log GROUP BY request_type;
