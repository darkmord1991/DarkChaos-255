-- =============================================================================
-- Fix dc_addon_protocol_log module column and populate HLBG test data
-- Run this on acore_chars database
-- =============================================================================

-- Fix 1: Expand the module column to accommodate longer module names
ALTER TABLE `dc_addon_protocol_log` 
MODIFY COLUMN `module` VARCHAR(16) NOT NULL COMMENT 'Module code (CORE, AOE, SPEC, LBRD, etc.)';

-- Fix 2: Also expand in stats table if exists
ALTER TABLE `dc_addon_protocol_stats` 
MODIFY COLUMN `module` VARCHAR(16) NOT NULL COMMENT 'Module code';

-- =============================================================================
-- HLBG Test Data - Populate for leaderboards
-- =============================================================================

-- Ensure active season exists
INSERT IGNORE INTO `dc_hlbg_seasons` (`season`, `name`, `start_date`, `end_date`, `is_active`, `description`) 
VALUES (1, 'Season 1: Genesis', NOW(), NULL, 1, 'The first season of Hinterland Battleground');

-- Populate HLBG seasonal data for existing characters
INSERT INTO dc_hlbg_player_season_data 
    (player_guid, season_id, joined_at, rating, completed_games, wins, losses, highest_rating, lowest_rating, total_score, average_score)
SELECT 
    c.guid, 
    1,  -- season_id = 1
    UNIX_TIMESTAMP(), 
    1500 + FLOOR(RAND() * 500),  -- Random rating 1500-2000
    FLOOR(RAND() * 50) + 10,     -- 10-60 games
    FLOOR(RAND() * 30) + 5,      -- 5-35 wins  
    FLOOR(RAND() * 20),          -- 0-20 losses
    1500 + FLOOR(RAND() * 600),  -- Highest rating
    1400 + FLOOR(RAND() * 200),  -- Lowest rating
    FLOOR(RAND() * 100000),      -- Total score
    FLOOR(RAND() * 2000)         -- Average score
FROM characters c
WHERE c.guid IN (SELECT guid FROM characters ORDER BY RAND() LIMIT 10)
ON DUPLICATE KEY UPDATE
    rating = VALUES(rating),
    completed_games = VALUES(completed_games),
    wins = VALUES(wins),
    losses = VALUES(losses),
    highest_rating = VALUES(highest_rating),
    lowest_rating = VALUES(lowest_rating);

-- Populate HLBG all-time stats
INSERT INTO dc_hlbg_player_stats 
    (player_guid, player_name, faction, battles_participated, battles_won, total_kills, total_deaths, resources_captured)
SELECT 
    c.guid, 
    c.name, 
    CASE WHEN c.race IN (1,3,4,7,11) THEN 'Alliance' ELSE 'Horde' END,
    FLOOR(RAND() * 100) + 20,   -- 20-120 battles
    FLOOR(RAND() * 50) + 10,    -- 10-60 wins
    FLOOR(RAND() * 200) + 50,   -- 50-250 kills
    FLOOR(RAND() * 100) + 20,   -- 20-120 deaths
    FLOOR(RAND() * 50000) + 5000 -- 5000-55000 resources
FROM characters c
WHERE c.guid IN (SELECT guid FROM characters ORDER BY RAND() LIMIT 10)
ON DUPLICATE KEY UPDATE
    battles_participated = VALUES(battles_participated),
    battles_won = VALUES(battles_won),
    total_kills = VALUES(total_kills),
    total_deaths = VALUES(total_deaths),
    resources_captured = VALUES(resources_captured);

-- Verify the data
SELECT 'HLBG Seasons' AS category, COUNT(*) AS count FROM dc_hlbg_seasons WHERE is_active = 1
UNION ALL
SELECT 'HLBG Seasonal Players', COUNT(*) FROM dc_hlbg_player_season_data
UNION ALL
SELECT 'HLBG All-time Players', COUNT(*) FROM dc_hlbg_player_stats;

-- Show sample data
SELECT 'Sample HLBG Seasonal Data' AS info;
SELECT psd.player_guid, c.name, psd.season_id, psd.rating, psd.wins, psd.losses, psd.completed_games
FROM dc_hlbg_player_season_data psd
JOIN characters c ON psd.player_guid = c.guid
WHERE psd.season_id = 1
ORDER BY psd.rating DESC
LIMIT 5;
