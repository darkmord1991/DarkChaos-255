-- =====================================================================
-- HLBG CONFIG TABLE HELPER
-- =====================================================================
-- Run this after HLBG_PRODUCTION_SETUP.sql to configure hlbg_config
-- This script adapts to your specific hlbg_config table structure
-- =====================================================================

-- Discover the actual structure first
SELECT 'HLBG_CONFIG TABLE ANALYSIS:' as Info;

-- Show the table creation statement
SHOW CREATE TABLE hlbg_config;

-- Show column details
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
FROM information_schema.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME = 'hlbg_config'
ORDER BY ORDINAL_POSITION;

-- Show current data
SELECT 'CURRENT CONFIG DATA:' as Info;
SELECT * FROM hlbg_config;

-- ==================================================
-- CONFIGURATION INSTRUCTIONS
-- ==================================================
-- Based on the results above, use one of these patterns:
--
-- If columns are (setting_name, setting_value):
-- INSERT INTO hlbg_config (setting_name, setting_value) VALUES ('affix_enabled', '1');
--
-- If columns are (name, value):  
-- INSERT INTO hlbg_config (name, value) VALUES ('affix_enabled', '1');
--
-- If columns are (config_name, config_value):
-- INSERT INTO hlbg_config (config_name, config_value) VALUES ('affix_enabled', '1');
--
-- If it's a key-value table with different structure, adapt accordingly.
-- ==================================================

SELECT 'CONFIGURATION HELPER COMPLETE' as Status;
SELECT 'Use the structure shown above to manually add config entries if needed' as Instructions;
SELECT 'Core HLBG systems work without hlbg_config - it is optional' as Note;