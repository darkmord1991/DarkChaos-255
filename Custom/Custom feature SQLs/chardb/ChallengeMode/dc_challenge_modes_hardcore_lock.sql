-- ========================================
-- DarkChaos-255: Challenge Modes Hardcore Character Lock
-- ========================================
-- Adds database structure for tracking hardcore deaths
-- ========================================

-- Characters database (acore_characters)

-- Add column to track hardcore death status
-- Note: Player settings are already handled by the module via UpdatePlayerSetting
-- This is just for manual queries and GM tools

-- Query to find all dead hardcore characters:
-- SELECT 
--     c.guid, 
--     c.name, 
--     c.level, 
--     c.class, 
--     c.totaltime,
--     FROM_UNIXTIME(c.logout_time) as death_time
-- FROM characters c
-- INNER JOIN character_settings cs ON c.guid = cs.guid
-- WHERE cs.source = 'mod-challenge-modes' 
--   AND cs.name = '8' -- CHALLENGE_HARDCORE_DEAD
--   AND cs.value = '1';

-- GM Command to unlock a hardcore character (emergency use only):
-- DELETE FROM character_settings 
-- WHERE guid = ? 
--   AND source = 'mod-challenge-modes' 
--   AND name = '8';

-- GM Command to manually lock a hardcore character:
-- INSERT INTO character_settings (guid, source, name, value)
-- VALUES (?, 'mod-challenge-modes', '8', '1')
-- ON DUPLICATE KEY UPDATE value = '1';

-- ========================================
-- ADMIN VIEW: Dead Hardcore Characters
-- ========================================
CREATE OR REPLACE VIEW `dc_hardcore_deaths` AS
SELECT 
    c.guid,
    c.name AS character_name,
    c.level AS final_level,
    CASE c.race
        WHEN 1 THEN 'Human'
        WHEN 2 THEN 'Orc'
        WHEN 3 THEN 'Dwarf'
        WHEN 4 THEN 'Night Elf'
        WHEN 5 THEN 'Undead'
        WHEN 6 THEN 'Tauren'
        WHEN 7 THEN 'Gnome'
        WHEN 8 THEN 'Troll'
        WHEN 10 THEN 'Blood Elf'
        WHEN 11 THEN 'Draenei'
        ELSE 'Unknown'
    END AS race,
    CASE c.class
        WHEN 1 THEN 'Warrior'
        WHEN 2 THEN 'Paladin'
        WHEN 3 THEN 'Hunter'
        WHEN 4 THEN 'Rogue'
        WHEN 5 THEN 'Priest'
        WHEN 6 THEN 'Death Knight'
        WHEN 7 THEN 'Shaman'
        WHEN 8 THEN 'Mage'
        WHEN 9 THEN 'Warlock'
        WHEN 11 THEN 'Druid'
        ELSE 'Unknown'
    END AS class,
    FLOOR(c.totaltime / 3600) AS hours_played,
    FROM_UNIXTIME(c.logout_time) AS death_timestamp,
    a.username AS account_name
FROM characters c
INNER JOIN character_settings cs ON c.guid = cs.guid
INNER JOIN account a ON c.account = a.id
WHERE cs.source = 'mod-challenge-modes'
  AND cs.name = '8' -- CHALLENGE_HARDCORE_DEAD
  AND cs.value = '1'
ORDER BY c.logout_time DESC;

-- Usage: SELECT * FROM dc_hardcore_deaths;

-- ========================================
-- NOTES:
-- ========================================
-- The actual locking is handled by C++ code in ChallengeModes.cpp
-- This SQL is for database visibility and GM tools
-- Setting name '8' corresponds to CHALLENGE_HARDCORE_DEAD enum value
-- ========================================
