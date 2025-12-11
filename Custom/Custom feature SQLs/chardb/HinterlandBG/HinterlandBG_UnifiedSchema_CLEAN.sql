-- ==============================================================================
-- HinterlandBG Unified Database Schema - CLEAN DEPLOYMENT
-- ==============================================================================
-- Use this script if you need to completely clean and rebuild the schema
-- This will DROP existing tables and views, then recreate everything fresh
-- 
-- WARNING: This will delete all data in dc_hlbg_match_participants!
-- Backup your database first if you have important data.
--
-- ==============================================================================

-- Drop views first (they depend on the table)
DROP VIEW IF EXISTS `v_hlbg_player_seasonal_stats`;
DROP VIEW IF EXISTS `v_hlbg_player_alltime_stats`;

-- Drop old deprecated tables
DROP TABLE IF EXISTS `dc_hlbg_match_history`;
DROP TABLE IF EXISTS `dc_hlbg_player_history`;
DROP TABLE IF EXISTS `dc_hlbg_season_config`;
DROP TABLE IF EXISTS `dc_hlbg_player_season_data`;

-- Drop new unified table (with cascade, FK constraints will be removed automatically)
DROP TABLE IF EXISTS `dc_hlbg_match_participants`;

-- ==============================================================================
-- STEP 2: CREATE UNIFIED MATCH PARTICIPANT TRACKING TABLE
-- ==============================================================================
-- This table tracks each player's performance in every HLBG match
-- Populated when match ends by server code in HinterlandBG arena module

CREATE TABLE `dc_hlbg_match_participants` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Unique participant record ID',
  `match_id` INT UNSIGNED NOT NULL COMMENT 'Foreign key to dc_hlbg_winner_history.id (the match ID)',
  `guid` INT UNSIGNED NOT NULL COMMENT 'Player GUID',
  `player_name` VARCHAR(50) NOT NULL COMMENT 'Player name (denormalized for convenience)',
  `account_id` INT UNSIGNED NOT NULL COMMENT 'Account ID (denormalized)',
  `account_name` VARCHAR(32) NOT NULL COMMENT 'Account name (denormalized)',
  `team` TINYINT NOT NULL COMMENT 'Team number (1=Horde, 2=Alliance)',
  `season_id` INT UNSIGNED NOT NULL DEFAULT '1' COMMENT 'Season when match occurred',
  `match_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When match was played',
  
  -- Player Performance Statistics
  `kills` INT UNSIGNED NOT NULL DEFAULT '0' COMMENT 'Player kills in match',
  `deaths` INT UNSIGNED NOT NULL DEFAULT '0' COMMENT 'Player deaths in match',
  `healing_done` INT UNSIGNED NOT NULL DEFAULT '0' COMMENT 'Healing dealt to allies',
  `damage_done` INT UNSIGNED NOT NULL DEFAULT '0' COMMENT 'Damage done to enemies',
  `resources_captured` INT UNSIGNED NOT NULL DEFAULT '0' COMMENT 'Resources collected (flags/resources)',
  `flags_returned` INT UNSIGNED NOT NULL DEFAULT '0' COMMENT 'For CTF-style: flags returned',
  `objectives_completed` INT UNSIGNED NOT NULL DEFAULT '0' COMMENT 'Any objective-based points',
  
  -- Rating Impact (set by match result calculation)
  `rating_change` INT NOT NULL DEFAULT '0' COMMENT 'Positive or negative rating change',
  
  PRIMARY KEY (`id`),
  KEY `idx_guid` (`guid`),
  KEY `idx_match_id` (`match_id`),
  KEY `idx_account` (`account_id`),
  KEY `idx_season` (`season_id`),
  KEY `idx_date` (`match_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tracks individual player statistics for each HLBG match';

-- ==============================================================================
-- STEP 3: CREATE MATERIALIZED VIEW: Seasonal Statistics
-- ==============================================================================
-- Groups participant data by player and season
-- Used for: rating, wins, winrate, games, kills, resources leaderboards

CREATE VIEW `v_hlbg_player_seasonal_stats` AS
SELECT 
  p.guid,
  p.account_id,
  p.player_name,
  p.account_name,
  p.season_id,
  
  -- Win Count (winner_tid: 1=Alliance, 2=Horde, 0=Draw)
  COUNT(CASE WHEN wh.winner_tid = p.team THEN 1 END) as `wins`,
  
  -- Loss Count
  COUNT(CASE WHEN wh.winner_tid != p.team AND wh.winner_tid != 0 THEN 1 END) as `losses`,
  
  -- Total Games Played
  COUNT(*) as `games_played`,
  
  -- Win Rate (as percentage, 0-100)
  ROUND(
    (COUNT(CASE WHEN wh.winner_tid = p.team THEN 1 END) * 100.0) / COUNT(*),
    2
  ) as `win_rate`,
  
  -- Aggregated Performance Stats
  SUM(p.kills) as `total_kills`,
  SUM(p.deaths) as `total_deaths`,
  ROUND(
    SUM(p.kills) / NULLIF(SUM(p.deaths), 0),
    2
  ) as `kd_ratio`,
  
  ROUND(SUM(p.kills) / NULLIF(COUNT(*), 0), 2) as `avg_kills_per_game`,
  ROUND(SUM(p.damage_done) / NULLIF(COUNT(*), 0), 0) as `avg_damage_per_game`,
  
  SUM(p.healing_done) as `total_healing`,
  SUM(p.resources_captured) as `total_resources_captured`,
  SUM(p.flags_returned) as `total_flags_returned`,
  
  -- Rating (sum of rating changes, or default 1200 if new)
  COALESCE(
    (SELECT SUM(rating_change) FROM dc_hlbg_match_participants p2 
     WHERE p2.guid = p.guid AND p2.season_id = p.season_id) + 1200,
    1200
  ) as `current_rating`,
  
  -- Last Match Time
  MAX(p.match_date) as `last_match_date`
  
FROM `dc_hlbg_match_participants` p
LEFT JOIN `dc_hlbg_winner_history` wh ON p.match_id = wh.id
GROUP BY p.guid, p.account_id, p.player_name, p.account_name, p.season_id;

-- ==============================================================================
-- STEP 4: CREATE MATERIALIZED VIEW: All-Time Statistics
-- ==============================================================================
-- Aggregates across all seasons for career statistics

CREATE VIEW `v_hlbg_player_alltime_stats` AS
SELECT 
  p.guid,
  p.account_id,
  p.player_name,
  p.account_name,
  
  -- Career Wins/Losses (winner_tid: 1=Alliance, 2=Horde, 0=Draw)
  COUNT(CASE WHEN wh.winner_tid = p.team THEN 1 END) as `lifetime_wins`,
  COUNT(CASE WHEN wh.winner_tid != p.team AND wh.winner_tid != 0 THEN 1 END) as `lifetime_losses`,
  COUNT(*) as `total_matches`,
  
  -- Career Win Rate
  ROUND(
    (COUNT(CASE WHEN wh.winner_tid = p.team THEN 1 END) * 100.0) / COUNT(*),
    2
  ) as `lifetime_win_rate`,
  
  -- Career Stats
  SUM(p.kills) as `lifetime_kills`,
  SUM(p.deaths) as `lifetime_deaths`,
  ROUND(
    SUM(p.kills) / NULLIF(SUM(p.deaths), 0),
    2
  ) as `lifetime_kd_ratio`,
  
  ROUND(SUM(p.kills) / NULLIF(COUNT(*), 0), 2) as `avg_kills_career`,
  ROUND(SUM(p.damage_done) / NULLIF(COUNT(*), 0), 0) as `avg_damage_career`,
  
  SUM(p.healing_done) as `lifetime_healing`,
  SUM(p.resources_captured) as `lifetime_resources`,
  SUM(p.flags_returned) as `lifetime_flags`,
  
  -- Career Stats By Season Count
  COUNT(DISTINCT p.season_id) as `seasons_played`,
  
  -- Most Recent Activity
  MAX(p.match_date) as `last_played`
  
FROM `dc_hlbg_match_participants` p
LEFT JOIN `dc_hlbg_winner_history` wh ON p.match_id = wh.id
GROUP BY p.guid, p.account_id, p.player_name, p.account_name;

-- ==============================================================================
-- STEP 5: CREATE INDEXES FOR PERFORMANCE
-- ==============================================================================

-- Indexes for participant table
CREATE INDEX `idx_participant_season_guid` ON `dc_hlbg_match_participants` (`season_id`, `guid`);
CREATE INDEX `idx_participant_team_date` ON `dc_hlbg_match_participants` (`team`, `match_date`);
CREATE INDEX `idx_participant_match_guid` ON `dc_hlbg_match_participants` (`match_id`, `guid`);

-- ==============================================================================
-- STEP 6: ADD FOREIGN KEY CONSTRAINT
-- ==============================================================================

ALTER TABLE `dc_hlbg_match_participants`
ADD CONSTRAINT `fk_match_id` FOREIGN KEY (`match_id`) 
REFERENCES `dc_hlbg_winner_history` (`id`) ON DELETE CASCADE;

-- ==============================================================================
-- VERIFICATION QUERIES
-- ==============================================================================

-- To verify setup, run these queries:

-- 1. Check participant table exists and count records:
--    SELECT COUNT(*) as participant_count FROM `dc_hlbg_match_participants`;

-- 2. Check seasonal stats view:
--    SELECT * FROM `v_hlbg_player_seasonal_stats` 
--    WHERE season_id = 1 
--    ORDER BY current_rating DESC 
--    LIMIT 10;

-- 3. Check all-time stats view:
--    SELECT * FROM `v_hlbg_player_alltime_stats` 
--    ORDER BY lifetime_wins DESC 
--    LIMIT 10;

-- 4. Verify winner_history table exists:
--    SELECT COUNT(*) as match_count FROM `dc_hlbg_winner_history`;

-- 5. Check foreign key constraint:
--    SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
--    WHERE TABLE_NAME = 'dc_hlbg_match_participants' AND CONSTRAINT_NAME = 'fk_match_id';

-- ==============================================================================
