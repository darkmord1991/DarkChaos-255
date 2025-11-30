-- =============================================================================
-- DC Leaderboards Test Data Population
-- Run this on acore_characters database to populate test data for leaderboards
-- Date: 2025-11-30
-- =============================================================================

-- ============================================================================
-- STEP 1: Ensure seasons exist
-- ============================================================================

-- HLBG Seasons (ensure at least one active season exists)
INSERT IGNORE INTO `dc_hlbg_seasons` (`season`, `name`, `start_date`, `end_date`, `is_active`, `description`) 
VALUES (1, 'Season 1: Genesis', NOW(), NULL, 1, 'The first season of Hinterland Battleground');

-- M+ Seasons (if table exists)
-- INSERT IGNORE INTO `dc_mplus_seasons` ...

SELECT 'Seasons verified' AS step, COUNT(*) AS active_seasons 
FROM dc_hlbg_seasons WHERE is_active = 1;

-- ============================================================================
-- STEP 2: Get some player GUIDs from the characters table
-- ============================================================================

SET @player1 = (SELECT guid FROM characters ORDER BY guid LIMIT 1);
SET @player2 = (SELECT guid FROM characters ORDER BY guid LIMIT 1 OFFSET 1);
SET @player3 = (SELECT guid FROM characters ORDER BY guid LIMIT 1 OFFSET 2);

SELECT 'Found players' AS step, @player1 AS p1, @player2 AS p2, @player3 AS p3;

-- ============================================================================
-- STEP 3: Insert HLBG Seasonal Data (for leaderboards)
-- ============================================================================

-- Insert/Update HLBG seasonal stats for test players
INSERT INTO dc_hlbg_player_season_data 
    (player_guid, season_id, joined_at, rating, completed_games, wins, losses, highest_rating, lowest_rating, total_score, average_score)
SELECT 
    guid, 1, UNIX_TIMESTAMP(), 
    1500 + FLOOR(RAND() * 500),  -- Random rating 1500-2000
    FLOOR(RAND() * 50) + 10,     -- 10-60 games
    FLOOR(RAND() * 30) + 5,      -- 5-35 wins  
    FLOOR(RAND() * 20),          -- 0-20 losses
    1500 + FLOOR(RAND() * 600),  -- Highest rating
    1400 + FLOOR(RAND() * 200),  -- Lowest rating
    FLOOR(RAND() * 100000),      -- Total score
    FLOOR(RAND() * 2000)         -- Average score
FROM characters
WHERE guid IN (SELECT guid FROM characters LIMIT 5)
ON DUPLICATE KEY UPDATE
    rating = VALUES(rating),
    completed_games = VALUES(completed_games),
    wins = VALUES(wins),
    losses = VALUES(losses);

SELECT 'HLBG Seasonal Data' AS step, COUNT(*) AS rows_in_dc_hlbg_player_season_data 
FROM dc_hlbg_player_season_data;

-- ============================================================================
-- STEP 4: Insert HLBG All-time Stats (for all-time leaderboards)
-- ============================================================================

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
WHERE c.guid IN (SELECT guid FROM characters LIMIT 5)
ON DUPLICATE KEY UPDATE
    battles_participated = VALUES(battles_participated),
    battles_won = VALUES(battles_won),
    total_kills = VALUES(total_kills),
    total_deaths = VALUES(total_deaths),
    resources_captured = VALUES(resources_captured);

SELECT 'HLBG All-time Stats' AS step, COUNT(*) AS rows_in_dc_hlbg_player_stats 
FROM dc_hlbg_player_stats;

-- ============================================================================
-- STEP 5: Insert AOE Loot Stats (for AOE leaderboards)
-- ============================================================================

INSERT INTO dc_aoeloot_detailed_stats 
    (player_guid, total_items, total_gold, vendor_gold, upgrades, skinned, mined, herbed)
SELECT 
    c.guid,
    FLOOR(RAND() * 10000) + 500,    -- 500-10500 items
    FLOOR(RAND() * 50000000) + 100000, -- Gold in copper
    FLOOR(RAND() * 10000000),       -- Vendor gold
    FLOOR(RAND() * 100),            -- Upgrades
    FLOOR(RAND() * 500),            -- Skinned
    FLOOR(RAND() * 300),            -- Mined
    FLOOR(RAND() * 200)             -- Herbed
FROM characters c
WHERE c.guid IN (SELECT guid FROM characters LIMIT 5)
ON DUPLICATE KEY UPDATE
    total_items = VALUES(total_items),
    total_gold = VALUES(total_gold),
    vendor_gold = VALUES(vendor_gold),
    upgrades = VALUES(upgrades);

SELECT 'AOE Loot Stats' AS step, COUNT(*) AS rows_in_dc_aoeloot_detailed_stats 
FROM dc_aoeloot_detailed_stats;

-- ============================================================================
-- STEP 6: Insert Prestige Data (for prestige leaderboards)
-- ============================================================================

INSERT INTO dc_character_prestige 
    (guid, prestige_level, total_prestiges, last_prestige_time)
SELECT 
    c.guid,
    FLOOR(RAND() * 10) + 1,         -- 1-11 prestige level
    FLOOR(RAND() * 5),              -- 0-5 total prestiges
    UNIX_TIMESTAMP() - FLOOR(RAND() * 604800)  -- Last week sometime
FROM characters c
WHERE c.guid IN (SELECT guid FROM characters LIMIT 5)
ON DUPLICATE KEY UPDATE
    prestige_level = VALUES(prestige_level),
    total_prestiges = VALUES(total_prestiges);

SELECT 'Prestige Data' AS step, COUNT(*) AS rows_in_dc_character_prestige 
FROM dc_character_prestige WHERE prestige_level > 0;

-- ============================================================================
-- STEP 7: Insert Duel Stats (for duel leaderboards)
-- ============================================================================

INSERT INTO dc_duel_statistics 
    (player_guid, wins, losses, total_duels, current_streak, best_streak, rating)
SELECT 
    c.guid,
    FLOOR(RAND() * 100) + 10,       -- 10-110 wins
    FLOOR(RAND() * 50),             -- 0-50 losses
    FLOOR(RAND() * 150) + 20,       -- 20-170 total
    FLOOR(RAND() * 10),             -- 0-10 current streak
    FLOOR(RAND() * 20) + 5,         -- 5-25 best streak
    1000 + FLOOR(RAND() * 1000)     -- 1000-2000 rating
FROM characters c
WHERE c.guid IN (SELECT guid FROM characters LIMIT 5)
ON DUPLICATE KEY UPDATE
    wins = VALUES(wins),
    losses = VALUES(losses),
    total_duels = VALUES(total_duels);

SELECT 'Duel Stats' AS step, COUNT(*) AS rows_in_dc_duel_statistics 
FROM dc_duel_statistics WHERE wins > 0;

-- ============================================================================
-- STEP 8: Insert Achievement Data (for achievement leaderboards)
-- ============================================================================

INSERT INTO dc_player_achievements 
    (player_guid, achievement_id, earned_at)
SELECT 
    c.guid,
    ach.id,
    UNIX_TIMESTAMP() - FLOOR(RAND() * 2592000)  -- Last month sometime
FROM characters c
CROSS JOIN (SELECT 1 AS id UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) ach
WHERE c.guid IN (SELECT guid FROM characters LIMIT 3)
ON DUPLICATE KEY UPDATE earned_at = VALUES(earned_at);

SELECT 'Achievement Data' AS step, COUNT(*) AS rows_in_dc_player_achievements 
FROM dc_player_achievements;

-- ============================================================================
-- FINAL VERIFICATION
-- ============================================================================

SELECT 
    'FINAL SUMMARY' AS report,
    (SELECT COUNT(*) FROM dc_hlbg_seasons WHERE is_active = 1) AS active_hlbg_seasons,
    (SELECT COUNT(*) FROM dc_hlbg_player_season_data) AS hlbg_seasonal_players,
    (SELECT COUNT(*) FROM dc_hlbg_player_stats) AS hlbg_alltime_players,
    (SELECT COUNT(*) FROM dc_aoeloot_detailed_stats) AS aoe_loot_players,
    (SELECT COUNT(*) FROM dc_character_prestige WHERE prestige_level > 0) AS prestige_players,
    (SELECT COUNT(*) FROM dc_duel_statistics WHERE wins > 0) AS duel_players;
