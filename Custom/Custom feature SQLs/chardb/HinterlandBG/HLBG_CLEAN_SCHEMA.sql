-- =============================================================================
-- HINTERLAND BATTLEGROUND - CLEAN DATABASE SCHEMA
-- =============================================================================
-- Database: characters (CharacterDatabase)
-- Purpose: Store battle history, seasons, and player statistics for HLBG
-- Version: 2.0 (Cleaned and Optimized)
-- Date: October 28, 2025
-- 
-- Changes from Previous Schema:
-- - REMOVED hlbg_battle_history (duplicate of hlbg_winner_history)
-- - REMOVED hlbg_config (config handled in .conf files)
-- - REMOVED hlbg_affixes (affixes defined in C++ code)
-- - REMOVED hlbg_statistics (can be computed from hlbg_winner_history)
-- - REMOVED hlbg_weather (never existed, data in hlbg_winner_history.weather)
-- - FIXED database type (all tables now use CharacterDatabase)
-- - ADDED performance indexes for common queries
-- - KEPT hlbg_winner_history (primary table - 42 code references)
-- - KEPT hlbg_seasons (season management - 2 code references)
-- - KEPT hlbg_player_stats (player tracking - 6 code references, needs integration)
-- 
-- Total Tables: 3 (down from 8 - 62.5% reduction)
-- =============================================================================

-- =============================================================================
-- TABLE 1: hlbg_winner_history
-- =============================================================================
-- Purpose: Primary battle history table - stores all battle results
-- Usage: 42 references across codebase
-- Files: HL_ScoreboardNPC.cpp, hlbg_addon.cpp, OutdoorPvPHL_Admin.cpp, cs_hl_bg.cpp
-- Database: CharacterDatabase (player progression data)
-- =============================================================================

DROP TABLE IF EXISTS `hlbg_winner_history`;
CREATE TABLE `hlbg_winner_history` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique battle identifier',
    
    -- Season & Time Tracking
    `season` SMALLINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Season number (joins with hlbg_seasons)',
    `occurred_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Battle end timestamp',
    `duration_seconds` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Battle duration in seconds',
    
    -- Location Information
    `zone_id` SMALLINT UNSIGNED NOT NULL DEFAULT 26 COMMENT 'Zone ID (26 = Hinterlands)',
    `map_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Map ID (0 = Eastern Kingdoms)',
    
    -- Battle Result
    `winner_tid` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT 'Winner: 0=Alliance, 1=Horde, 2=Draw',
    `win_reason` VARCHAR(32) NOT NULL DEFAULT 'depletion' COMMENT 'Win reason: depletion, tiebreaker, manual',
    `score_alliance` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Final Alliance resource count',
    `score_horde` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Final Horde resource count',
    
    -- Affix System (Weather-Based Modifiers)
    `affix` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Affix ID: 0=None, 1=Sunlight, 2=Clear, 3=Breeze, 4=Storm, 5=Rain, 6=Fog',
    
    -- Weather System
    `weather` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Weather type: 0=Fine, 1=Rain, 2=Snow, 3=Storm, 4=Thunder, 5=BlackRain',
    `weather_intensity` FLOAT NOT NULL DEFAULT 0.0 COMMENT 'Weather intensity (0.0-1.0)',
    
    -- Primary Key
    PRIMARY KEY (`id`),
    
    -- Performance Indexes (Based on Common Queries)
    KEY `idx_season` (`season`) COMMENT 'Season filtering queries',
    KEY `idx_occurred_at` (`occurred_at`) COMMENT 'Date range queries',
    KEY `idx_winner_tid` (`winner_tid`) COMMENT 'Win rate aggregations',
    KEY `idx_affix` (`affix`) COMMENT 'Affix statistics queries',
    KEY `idx_weather` (`weather`) COMMENT 'Weather statistics queries',
    KEY `idx_win_reason` (`win_reason`) COMMENT 'Win condition analysis',
    KEY `idx_season_occurred` (`season`, `occurred_at`) COMMENT 'Composite index for season history'
    
    -- Foreign Key (Optional - uncomment if enforcing referential integrity)
    -- , CONSTRAINT `fk_hlbg_winner_season` FOREIGN KEY (`season`) REFERENCES `hlbg_seasons` (`season`) ON DELETE CASCADE
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='HLBG Battle History - Primary table for all battle results';

-- =============================================================================
-- TABLE 2: hlbg_seasons
-- =============================================================================
-- Purpose: Season definitions and metadata
-- Usage: 2 references (JOIN queries with hlbg_winner_history)
-- Files: HL_ScoreboardNPC.cpp, hlbg_addon.cpp
-- Database: CharacterDatabase (player progression data)
-- =============================================================================

DROP TABLE IF EXISTS `hlbg_seasons`;
CREATE TABLE `hlbg_seasons` (
    `season` SMALLINT UNSIGNED NOT NULL COMMENT 'Season number (increments each season)',
    `name` VARCHAR(64) NOT NULL DEFAULT '' COMMENT 'Season display name (e.g., "Season 1: Genesis")',
    `start_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Season start timestamp',
    `end_date` TIMESTAMP NULL DEFAULT NULL COMMENT 'Season end timestamp (NULL = current season)',
    `is_active` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1 = Active season, 0 = Past season',
    `description` TEXT DEFAULT NULL COMMENT 'Season description/changelog',
    
    -- Primary Key
    PRIMARY KEY (`season`),
    
    -- Indexes
    KEY `idx_is_active` (`is_active`) COMMENT 'Find current season',
    KEY `idx_dates` (`start_date`, `end_date`) COMMENT 'Date range queries'
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='HLBG Season Tracking - Season metadata and names';

-- =============================================================================
-- TABLE 3: hlbg_player_stats
-- =============================================================================
-- Purpose: Player-level statistics (participation, kills, deaths, wins)
-- Usage: 6 references (UPDATE queries in HLBG_Integration_Helper.cpp)
-- Status: PARTIALLY IMPLEMENTED - Table exists but stats not displayed to players
-- Database: CharacterDatabase (player progression data)
-- 
-- TODO: Add SELECT queries to display player stats in-game
-- TODO: Integrate with Scoreboard NPC or .hlbg stats command
-- =============================================================================

DROP TABLE IF EXISTS `hlbg_player_stats`;
CREATE TABLE `hlbg_player_stats` (
    `player_guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID (unique identifier)',
    `player_name` VARCHAR(12) NOT NULL COMMENT 'Player character name',
    `faction` VARCHAR(16) NOT NULL DEFAULT 'Unknown' COMMENT 'Alliance or Horde',
    
    -- Participation Stats
    `battles_participated` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total battles joined',
    `battles_won` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total battles won',
    `last_participation` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Last battle timestamp',
    
    -- Combat Stats
    `total_kills` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total player kills',
    `total_deaths` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total deaths',
    `resources_captured` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total resources captured',
    
    -- Primary Key
    PRIMARY KEY (`player_guid`),
    
    -- Indexes
    KEY `idx_player_name` (`player_name`) COMMENT 'Search by name',
    KEY `idx_faction` (`faction`) COMMENT 'Faction-specific leaderboards',
    KEY `idx_battles_won` (`battles_won`) COMMENT 'Win count leaderboard',
    KEY `idx_total_kills` (`total_kills`) COMMENT 'Kill count leaderboard',
    KEY `idx_last_participation` (`last_participation`) COMMENT 'Recent activity queries'
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='HLBG Player Statistics - Individual player performance tracking';

-- =============================================================================
-- DEFAULT DATA: Insert Initial Season
-- =============================================================================

INSERT INTO `hlbg_seasons` (`season`, `name`, `start_date`, `end_date`, `is_active`, `description`) VALUES
(1, 'Season 1: Genesis', CURRENT_TIMESTAMP, NULL, 1, 'The first season of Hinterland Battleground - weather-based affixes, custom maps, and 255 PvP action!');

-- =============================================================================
-- SAMPLE DATA: Example Battle History (Optional - for testing)
-- =============================================================================
-- Uncomment below to insert sample battles for testing

/*
INSERT INTO `hlbg_winner_history` 
    (`season`, `occurred_at`, `duration_seconds`, `zone_id`, `map_id`, `winner_tid`, `win_reason`, 
     `score_alliance`, `score_horde`, `affix`, `weather`, `weather_intensity`) 
VALUES
    -- Alliance victory via depletion, Sunlight affix, Clear weather
    (1, NOW() - INTERVAL 1 DAY, 1800, 26, 0, 0, 'depletion', 2000, 0, 1, 0, 0.5),
    
    -- Horde victory via tiebreaker, Storm affix, Heavy rain
    (1, NOW() - INTERVAL 12 HOUR, 1200, 26, 0, 1, 'tiebreaker', 1500, 1550, 4, 1, 0.8),
    
    -- Draw via manual end, No affix, Fine weather
    (1, NOW() - INTERVAL 6 HOUR, 600, 26, 0, 2, 'manual', 1000, 1000, 0, 0, 0.0),
    
    -- Alliance victory via depletion, Fog affix, Snow
    (1, NOW() - INTERVAL 3 HOUR, 1500, 26, 0, 0, 'depletion', 2000, 500, 6, 2, 0.6);
*/

-- =============================================================================
-- VERIFICATION QUERIES (Run after schema creation)
-- =============================================================================

-- Check tables created successfully
-- SHOW TABLES LIKE 'hlbg%';

-- Verify indexes created
-- SHOW INDEX FROM hlbg_winner_history;
-- SHOW INDEX FROM hlbg_seasons;
-- SHOW INDEX FROM hlbg_player_stats;

-- Check default season inserted
-- SELECT * FROM hlbg_seasons WHERE is_active = 1;

-- =============================================================================
-- MIGRATION NOTES (If upgrading from old schema)
-- =============================================================================

/*
IF UPGRADING FROM OLD SCHEMA:

1. BACKUP EXISTING DATA:
   - mysqldump -u root -p characters hlbg_winner_history > hlbg_backup.sql
   - mysqldump -u root -p characters hlbg_seasons >> hlbg_backup.sql
   - mysqldump -u root -p characters hlbg_player_stats >> hlbg_backup.sql

2. DATA MIGRATION (if hlbg_battle_history exists):
   -- Copy data from hlbg_battle_history to hlbg_winner_history if needed
   -- (Check if battle_history has any unique data not in winner_history)
   
   INSERT INTO hlbg_winner_history 
       (occurred_at, winner_tid, score_alliance, score_horde, affix, duration_seconds)
   SELECT 
       battle_end,
       CASE winner_faction WHEN 'Alliance' THEN 0 WHEN 'Horde' THEN 1 ELSE 2 END,
       alliance_resources,
       horde_resources,
       affix_id,
       duration_seconds
   FROM hlbg_battle_history
   WHERE battle_end IS NOT NULL
   AND id NOT IN (SELECT id FROM hlbg_winner_history);

3. DROP OLD TABLES:
   DROP TABLE IF EXISTS hlbg_battle_history;
   DROP TABLE IF EXISTS hlbg_config;
   DROP TABLE IF EXISTS hlbg_affixes;
   DROP TABLE IF EXISTS hlbg_statistics;

4. UPDATE CODE REFERENCES:
   - Search for "WorldDatabase" in HLBG_Integration_Helper.cpp
   - Replace with "CharacterDatabase" for all HLBG tables
   - Test all queries after migration

5. VERIFY DATA INTEGRITY:
   SELECT COUNT(*) FROM hlbg_winner_history;
   SELECT COUNT(*) FROM hlbg_player_stats;
   SELECT * FROM hlbg_seasons WHERE is_active = 1;
*/

-- =============================================================================
-- COMMON QUERIES (For reference when implementing features)
-- =============================================================================

/*
-- Get recent battle history with season names
SELECT 
    h.id,
    h.season,
    s.name AS season_name,
    h.occurred_at,
    CASE h.winner_tid WHEN 0 THEN 'Alliance' WHEN 1 THEN 'Horde' ELSE 'Draw' END AS winner,
    h.win_reason,
    h.score_alliance,
    h.score_horde,
    h.duration_seconds,
    CASE h.affix 
        WHEN 1 THEN 'Sunlight' 
        WHEN 2 THEN 'Clear Skies' 
        WHEN 3 THEN 'Gentle Breeze'
        WHEN 4 THEN 'Storm' 
        WHEN 5 THEN 'Heavy Rain' 
        WHEN 6 THEN 'Fog' 
        ELSE 'None' 
    END AS affix_name
FROM hlbg_winner_history h
LEFT JOIN hlbg_seasons s ON h.season = s.season
ORDER BY h.occurred_at DESC
LIMIT 20;

-- Calculate win rates by team
SELECT 
    CASE winner_tid WHEN 0 THEN 'Alliance' WHEN 1 THEN 'Horde' ELSE 'Draw' END AS winner,
    COUNT(*) AS total_wins,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM hlbg_winner_history), 2) AS win_percentage
FROM hlbg_winner_history
GROUP BY winner_tid;

-- Affix win rate analysis
SELECT 
    CASE h.affix 
        WHEN 1 THEN 'Sunlight' 
        WHEN 2 THEN 'Clear Skies' 
        WHEN 3 THEN 'Gentle Breeze'
        WHEN 4 THEN 'Storm' 
        WHEN 5 THEN 'Heavy Rain' 
        WHEN 6 THEN 'Fog' 
        ELSE 'None' 
    END AS affix_name,
    SUM(CASE WHEN winner_tid = 0 THEN 1 ELSE 0 END) AS alliance_wins,
    SUM(CASE WHEN winner_tid = 1 THEN 1 ELSE 0 END) AS horde_wins,
    SUM(CASE WHEN winner_tid = 2 THEN 1 ELSE 0 END) AS draws,
    COUNT(*) AS total_battles
FROM hlbg_winner_history h
GROUP BY h.affix
ORDER BY h.affix;

-- Weather statistics
SELECT 
    CASE h.weather 
        WHEN 0 THEN 'Fine' 
        WHEN 1 THEN 'Rain' 
        WHEN 2 THEN 'Snow'
        WHEN 3 THEN 'Storm' 
        WHEN 4 THEN 'Thunders' 
        WHEN 5 THEN 'Black Rain' 
        ELSE 'Unknown' 
    END AS weather_type,
    SUM(CASE WHEN winner_tid = 0 THEN 1 ELSE 0 END) AS alliance_wins,
    SUM(CASE WHEN winner_tid = 1 THEN 1 ELSE 0 END) AS horde_wins,
    AVG(duration_seconds) AS avg_duration,
    COUNT(*) AS total_battles
FROM hlbg_winner_history h
GROUP BY h.weather
ORDER BY h.weather;

-- Player leaderboard (Top 20 by wins)
SELECT 
    player_name,
    faction,
    battles_participated,
    battles_won,
    ROUND(battles_won * 100.0 / battles_participated, 2) AS win_rate,
    total_kills,
    total_deaths,
    ROUND(total_kills * 1.0 / NULLIF(total_deaths, 1), 2) AS kd_ratio,
    resources_captured
FROM hlbg_player_stats
WHERE battles_participated >= 5
ORDER BY battles_won DESC, win_rate DESC
LIMIT 20;

-- Season summary
SELECT 
    s.season,
    s.name,
    s.start_date,
    COUNT(h.id) AS total_battles,
    SUM(CASE WHEN h.winner_tid = 0 THEN 1 ELSE 0 END) AS alliance_wins,
    SUM(CASE WHEN h.winner_tid = 1 THEN 1 ELSE 0 END) AS horde_wins,
    SUM(CASE WHEN h.winner_tid = 2 THEN 1 ELSE 0 END) AS draws,
    AVG(h.duration_seconds) AS avg_duration_seconds
FROM hlbg_seasons s
LEFT JOIN hlbg_winner_history h ON s.season = h.season
GROUP BY s.season, s.name, s.start_date
ORDER BY s.season DESC;
*/

-- =============================================================================
-- END OF SCHEMA
-- =============================================================================
