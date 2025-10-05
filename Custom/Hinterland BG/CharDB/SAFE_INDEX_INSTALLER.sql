-- HLBG Schema Installation Script - Safe Index Creation
-- Run this AFTER the main schema if you get index errors
-- This script safely creates indexes without errors if they already exist

DELIMITER $$

-- Create procedure to safely add indexes
CREATE PROCEDURE `SafeCreateIndex`(
    IN table_name VARCHAR(64),
    IN index_name VARCHAR(64), 
    IN index_columns VARCHAR(255)
)
BEGIN
    DECLARE index_exists INT DEFAULT 0;
    
    -- Check if index already exists
    SELECT COUNT(*) INTO index_exists 
    FROM information_schema.statistics 
    WHERE table_schema = DATABASE() 
    AND table_name = table_name 
    AND index_name = index_name;
    
    -- Only create index if it doesn't exist
    IF index_exists = 0 THEN
        SET @sql = CONCAT('CREATE INDEX `', index_name, '` ON `', table_name, '` (', index_columns, ')');
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        SELECT CONCAT('Created index: ', index_name, ' on ', table_name) as Result;
    ELSE
        SELECT CONCAT('Index already exists: ', index_name, ' on ', table_name) as Result;
    END IF;
END$$

DELIMITER ;

-- Now safely create all indexes
CALL SafeCreateIndex('hlbg_seasons', 'idx_hlbg_seasons_active', '`is_active`');
CALL SafeCreateIndex('hlbg_seasons', 'idx_hlbg_seasons_dates', '`start_datetime`, `end_datetime`');

CALL SafeCreateIndex('hlbg_battle_history', 'idx_hlbg_history_end', '`battle_end`');
CALL SafeCreateIndex('hlbg_battle_history', 'idx_hlbg_history_winner', '`winner_faction`');
CALL SafeCreateIndex('hlbg_battle_history', 'idx_hlbg_history_instance', '`instance_id`');
CALL SafeCreateIndex('hlbg_battle_history', 'idx_hlbg_history_affix', '`affix_id`');
CALL SafeCreateIndex('hlbg_battle_history', 'idx_hlbg_history_start', '`battle_start`');

CALL SafeCreateIndex('hlbg_player_stats', 'idx_hlbg_player_name', '`player_name`');
CALL SafeCreateIndex('hlbg_player_stats', 'idx_hlbg_player_faction', '`faction`');
CALL SafeCreateIndex('hlbg_player_stats', 'idx_hlbg_player_battles', '`battles_participated`');
CALL SafeCreateIndex('hlbg_player_stats', 'idx_hlbg_player_wins', '`battles_won`');
CALL SafeCreateIndex('hlbg_player_stats', 'idx_hlbg_player_last_participation', '`last_participation`');

CALL SafeCreateIndex('hlbg_affixes', 'idx_hlbg_affixes_enabled', '`is_enabled`');
CALL SafeCreateIndex('hlbg_affixes', 'idx_hlbg_affixes_usage', '`usage_count`');

CALL SafeCreateIndex('hlbg_weather', 'idx_hlbg_weather_enabled', '`is_enabled`');

-- Clean up the procedure
DROP PROCEDURE SafeCreateIndex;

-- Verify installation
SELECT 'HLBG Schema Installation Complete!' as Status;
SELECT TABLE_NAME, TABLE_ROWS, TABLE_COMMENT 
FROM information_schema.tables 
WHERE table_schema = DATABASE() 
AND table_name LIKE 'hlbg_%';