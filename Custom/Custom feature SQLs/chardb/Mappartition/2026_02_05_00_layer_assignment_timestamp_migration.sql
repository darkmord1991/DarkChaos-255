-- Migration: Convert dc_character_layer_assignment.timestamp from UNIX epoch to human-readable DATETIME
-- This makes it consistent with dc_character_partition_ownership which uses auto-updating TIMESTAMP

-- Step 1: Add new column with proper TIMESTAMP type
ALTER TABLE `dc_character_layer_assignment` 
ADD COLUMN `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `layer_id`;

-- Step 2: Migrate existing data (convert Unix timestamp to DATETIME)
UPDATE `dc_character_layer_assignment` 
SET `updated_at` = FROM_UNIXTIME(`timestamp`) 
WHERE `timestamp` > 0;

-- Step 3: Drop old column and index
ALTER TABLE `dc_character_layer_assignment` 
DROP INDEX `idx_timestamp`,
DROP COLUMN `timestamp`;

-- Step 4: Recreate index on new column for cleanup event
ALTER TABLE `dc_character_layer_assignment`
ADD INDEX `idx_updated_at` (`updated_at`);

-- Step 5: Update cleanup event to use new column
DROP EVENT IF EXISTS `dc_layer_assignment_cleanup`;
DELIMITER //
CREATE EVENT `dc_layer_assignment_cleanup`
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DELETE FROM `dc_character_layer_assignment` 
    WHERE `updated_at` < DATE_SUB(NOW(), INTERVAL 7 DAY);
END //
DELIMITER ;
