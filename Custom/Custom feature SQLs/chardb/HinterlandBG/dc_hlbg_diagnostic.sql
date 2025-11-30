-- =============================================================================
-- DC Leaderboards Diagnostic - Run this to check why HLBG shows empty
-- =============================================================================

-- Check 1: Does dc_hlbg_seasons exist and have an active season?
SELECT 'CHECK 1: Active HLBG Seasons' AS diagnostic;
SELECT season, name, is_active 
FROM dc_hlbg_seasons 
WHERE is_active = 1 
ORDER BY season DESC;

-- Check 2: What season ID would be used?
SELECT 'CHECK 2: Current Season ID Query Result' AS diagnostic;
SELECT season FROM dc_hlbg_seasons WHERE is_active = 1 ORDER BY season DESC LIMIT 1;

-- Check 3: Does dc_hlbg_player_season_data have any rows?
SELECT 'CHECK 3: HLBG Player Season Data Row Count' AS diagnostic;
SELECT COUNT(*) AS total_rows, 
       COUNT(DISTINCT player_guid) AS unique_players,
       COUNT(DISTINCT season_id) AS seasons_with_data
FROM dc_hlbg_player_season_data;

-- Check 4: What season_ids exist in player data?
SELECT 'CHECK 4: Season IDs in Player Data' AS diagnostic;
SELECT season_id, COUNT(*) AS player_count 
FROM dc_hlbg_player_season_data 
GROUP BY season_id;

-- Check 5: Do we have data for season 1?
SELECT 'CHECK 5: Sample Data for Season 1' AS diagnostic;
SELECT psd.player_guid, c.name, psd.season_id, psd.rating, psd.wins, psd.losses, psd.completed_games
FROM dc_hlbg_player_season_data psd
LEFT JOIN characters c ON psd.player_guid = c.guid
WHERE psd.season_id = 1
LIMIT 5;

-- Check 6: Does dc_hlbg_player_stats have data (for all-time tabs)?
SELECT 'CHECK 6: HLBG All-Time Stats' AS diagnostic;
SELECT COUNT(*) AS total_rows FROM dc_hlbg_player_stats;

-- Check 7: The actual query the leaderboard runs
SELECT 'CHECK 7: Simulated Leaderboard Query (Season 1, hlbg_games)' AS diagnostic;
SELECT c.name, c.class, h.rating, h.wins, h.losses, h.completed_games
FROM dc_hlbg_player_season_data h
JOIN characters c ON h.player_guid = c.guid
WHERE h.season_id = 1
ORDER BY h.completed_games DESC
LIMIT 10;

-- Fix: If season table is missing, create it
SELECT 'FIX: Creating active season if missing' AS diagnostic;
INSERT IGNORE INTO `dc_hlbg_seasons` (`season`, `name`, `start_date`, `end_date`, `is_active`, `description`) 
VALUES (1, 'Season 1: Genesis', NOW(), NULL, 1, 'The first season of Hinterland Battleground');

-- Recheck after fix
SELECT 'RECHECK: Active seasons after fix' AS diagnostic;
SELECT season, name, is_active FROM dc_hlbg_seasons WHERE is_active = 1;
