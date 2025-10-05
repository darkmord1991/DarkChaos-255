-- DISCOVER HLBG_CONFIG TABLE STRUCTURE
-- Based on the error: "Unknown column 'setting_name'" 
-- Let's find the actual column names

SELECT 'hlbg_config TABLE STRUCTURE:' as Info;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA 
FROM information_schema.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME = 'hlbg_config'
ORDER BY ORDINAL_POSITION;

SELECT 'Current hlbg_config data:' as Info;
SELECT * FROM hlbg_config LIMIT 10;

SELECT 'hlbg_config CREATE STATEMENT:' as Info;
SHOW CREATE TABLE hlbg_config;