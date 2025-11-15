-- ========================================================================
-- Mythic+ Season 1 - Initial Setup
-- ========================================================================
-- Purpose: Create Season 1 entry required by foreign key constraints
-- This must be run BEFORE 00_MISSING_TABLES_FIX.sql
-- ========================================================================

USE acore_world;

-- ========================================================================
-- SEED DATA: Season 1 Definition
-- ========================================================================
-- Create Season 1 with featured dungeons and affix schedule
-- Start: Current timestamp (adjust as needed)
-- End: 1 year from start (31536000 seconds = 365 days)

DELETE FROM `dc_mplus_seasons` WHERE `season_id` = 1;
INSERT INTO `dc_mplus_seasons` (`season_id`, `label`, `start_ts`, `end_ts`, `featured_dungeons`, `affix_schedule`, `reward_curve`, `is_active`) 
VALUES (
    1,
    'Season 1: Wrath of Winter',
    UNIX_TIMESTAMP('2025-01-01 00:00:00'),  -- Start date
    UNIX_TIMESTAMP('2026-01-01 00:00:00'),  -- End date (1 year)
    JSON_ARRAY(574, 575, 576, 578, 599, 600, 601, 602, 608, 619),  -- Featured dungeon map IDs
    JSON_ARRAY(
        JSON_OBJECT('week', 0, 'affixPairId', 1),
        JSON_OBJECT('week', 1, 'affixPairId', 1),
        JSON_OBJECT('week', 2, 'affixPairId', 1),
        JSON_OBJECT('week', 3, 'affixPairId', 1),
        JSON_OBJECT('week', 4, 'affixPairId', 2),
        JSON_OBJECT('week', 5, 'affixPairId', 2),
        JSON_OBJECT('week', 6, 'affixPairId', 2),
        JSON_OBJECT('week', 7, 'affixPairId', 2),
        JSON_OBJECT('week', 8, 'affixPairId', 1),
        JSON_OBJECT('week', 9, 'affixPairId', 1),
        JSON_OBJECT('week', 10, 'affixPairId', 1),
        JSON_OBJECT('week', 11, 'affixPairId', 1)
    ),
    JSON_OBJECT(
        '2', JSON_OBJECT('ilvl', 219, 'tokens', 25),
        '3', JSON_OBJECT('ilvl', 222, 'tokens', 30),
        '4', JSON_OBJECT('ilvl', 225, 'tokens', 35),
        '5', JSON_OBJECT('ilvl', 228, 'tokens', 40),
        '6', JSON_OBJECT('ilvl', 231, 'tokens', 45),
        '7', JSON_OBJECT('ilvl', 234, 'tokens', 50),
        '8', JSON_OBJECT('ilvl', 237, 'tokens', 55),
        '9', JSON_OBJECT('ilvl', 240, 'tokens', 60),
        '10', JSON_OBJECT('ilvl', 243, 'tokens', 65),
        '11', JSON_OBJECT('ilvl', 246, 'tokens', 70),
        '12', JSON_OBJECT('ilvl', 249, 'tokens', 75),
        '13', JSON_OBJECT('ilvl', 252, 'tokens', 80),
        '14', JSON_OBJECT('ilvl', 255, 'tokens', 85),
        '15', JSON_OBJECT('ilvl', 258, 'tokens', 90),
        '16', JSON_OBJECT('ilvl', 261, 'tokens', 95),
        '17', JSON_OBJECT('ilvl', 264, 'tokens', 100),
        '18', JSON_OBJECT('ilvl', 267, 'tokens', 105),
        '19', JSON_OBJECT('ilvl', 270, 'tokens', 110),
        '20', JSON_OBJECT('ilvl', 273, 'tokens', 115)
    ),
    TRUE  -- is_active = TRUE (this is the active season)
);

-- ========================================================================
-- VERIFICATION
-- ========================================================================
SELECT 
    season_id,
    label,
    FROM_UNIXTIME(start_ts) AS start_date,
    FROM_UNIXTIME(end_ts) AS end_date,
    is_active
FROM dc_mplus_seasons 
WHERE season_id = 1;

SELECT 'Season 1 created successfully!' AS Status;
SELECT 'You can now run 00_MISSING_TABLES_FIX.sql' AS NextStep;
