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
-- STEP 3: Insert HLBG Unified Match Data (for seasonal leaderboards)
-- ============================================================================

INSERT INTO dc_hlbg_winner_history
    (season, occurred_at, duration_seconds, zone_id, map_id, winner_tid, win_reason, score_alliance, score_horde, affix, weather, weather_intensity)
VALUES
    (1, NOW() - INTERVAL 7 DAY, 1020, 26, 1411, 0, 'depletion', 1600, 1220, 1, 0, 0.00),
    (1, NOW() - INTERVAL 6 DAY, 1105, 26, 1411, 1, 'tiebreaker', 1410, 1600, 4, 3, 0.45),
    (1, NOW() - INTERVAL 5 DAY, 980, 26, 1411, 0, 'manual', 1600, 1180, 2, 1, 0.25);

SET @hlbg_match_1 = LAST_INSERT_ID() - 2;
SET @hlbg_match_2 = LAST_INSERT_ID() - 1;
SET @hlbg_match_3 = LAST_INSERT_ID();

INSERT INTO dc_hlbg_match_participants
    (match_id, guid, player_name, account_id, account_name, team, season_id, match_date, kills, deaths, healing_done, damage_done, resources_captured, flags_returned, objectives_completed, rating_change)
SELECT
    @hlbg_match_1,
    c.guid,
    c.name,
    c.account,
    CONCAT('account_', c.account),
    CASE WHEN MOD(c.guid, 2) = 0 THEN 0 ELSE 1 END,
    1,
    NOW() - INTERVAL 7 DAY,
    8 + FLOOR(RAND() * 12),
    1 + FLOOR(RAND() * 6),
    FLOOR(RAND() * 25000),
    10000 + FLOOR(RAND() * 25000),
    150 + FLOOR(RAND() * 600),
    FLOOR(RAND() * 3),
    FLOOR(RAND() * 4),
    CASE WHEN MOD(c.guid, 2) = 0 THEN 18 + FLOOR(RAND() * 12) ELSE -15 - FLOOR(RAND() * 10) END
FROM characters c
WHERE c.guid IN (SELECT guid FROM characters LIMIT 5);

INSERT INTO dc_hlbg_match_participants
    (match_id, guid, player_name, account_id, account_name, team, season_id, match_date, kills, deaths, healing_done, damage_done, resources_captured, flags_returned, objectives_completed, rating_change)
SELECT
    @hlbg_match_2,
    c.guid,
    c.name,
    c.account,
    CONCAT('account_', c.account),
    CASE WHEN MOD(c.guid, 2) = 0 THEN 0 ELSE 1 END,
    1,
    NOW() - INTERVAL 6 DAY,
    6 + FLOOR(RAND() * 10),
    2 + FLOOR(RAND() * 7),
    FLOOR(RAND() * 22000),
    9000 + FLOOR(RAND() * 22000),
    120 + FLOOR(RAND() * 500),
    FLOOR(RAND() * 3),
    FLOOR(RAND() * 4),
    CASE WHEN MOD(c.guid, 2) = 1 THEN 16 + FLOOR(RAND() * 10) ELSE -12 - FLOOR(RAND() * 8) END
FROM characters c
WHERE c.guid IN (SELECT guid FROM characters LIMIT 5);

INSERT INTO dc_hlbg_match_participants
    (match_id, guid, player_name, account_id, account_name, team, season_id, match_date, kills, deaths, healing_done, damage_done, resources_captured, flags_returned, objectives_completed, rating_change)
SELECT
    @hlbg_match_3,
    c.guid,
    c.name,
    c.account,
    CONCAT('account_', c.account),
    CASE WHEN MOD(c.guid, 2) = 0 THEN 0 ELSE 1 END,
    1,
    NOW() - INTERVAL 5 DAY,
    7 + FLOOR(RAND() * 11),
    1 + FLOOR(RAND() * 5),
    FLOOR(RAND() * 24000),
    9500 + FLOOR(RAND() * 26000),
    140 + FLOOR(RAND() * 550),
    FLOOR(RAND() * 3),
    FLOOR(RAND() * 4),
    CASE WHEN MOD(c.guid, 2) = 0 THEN 14 + FLOOR(RAND() * 10) ELSE -10 - FLOOR(RAND() * 8) END
FROM characters c
WHERE c.guid IN (SELECT guid FROM characters LIMIT 5);

SELECT 'HLBG Unified Match Data' AS step, COUNT(*) AS rows_in_dc_hlbg_match_participants
FROM dc_hlbg_match_participants;

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
    (SELECT COUNT(*) FROM v_hlbg_player_seasonal_stats WHERE season_id = 1) AS hlbg_seasonal_players,
    (SELECT COUNT(*) FROM dc_hlbg_player_stats) AS hlbg_alltime_players,
    (SELECT COUNT(*) FROM dc_aoeloot_detailed_stats) AS aoe_loot_players,
    (SELECT COUNT(*) FROM dc_character_prestige WHERE prestige_level > 0) AS prestige_players,
    (SELECT COUNT(*) FROM dc_duel_statistics WHERE wins > 0) AS duel_players;
