-- Add show_messages column to dc_aoeloot_preferences table
-- This allows players to toggle debug/info messages

-- MySQL doesn't support IF NOT EXISTS for ADD COLUMN, so we use a procedure
DROP PROCEDURE IF EXISTS add_show_messages_column;

DELIMITER //
CREATE PROCEDURE add_show_messages_column()
BEGIN
    IF NOT EXISTS (
        SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'dc_aoeloot_preferences' 
        AND COLUMN_NAME = 'show_messages'
    ) THEN
        ALTER TABLE `dc_aoeloot_preferences` 
        ADD COLUMN `show_messages` TINYINT(1) NOT NULL DEFAULT 1 
        COMMENT 'Whether to show AoE loot info/debug messages (1=show, 0=hide)';
    END IF;
END //
DELIMITER ;

CALL add_show_messages_column();
DROP PROCEDURE IF EXISTS add_show_messages_column;
