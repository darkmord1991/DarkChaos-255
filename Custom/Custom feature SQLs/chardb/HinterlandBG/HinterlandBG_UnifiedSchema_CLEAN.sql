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
  `team` TINYINT NOT NULL COMMENT 'TeamId: 0=Alliance, 1=Horde',
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
-- STEP 3-4: CREATE THE STATISTICS VIEWS
-- ==============================================================================
-- These are the live definitions (characters rev_1793962095460547800.sql, 2026-11-06).
-- winner_tid and team both hold a TeamId: 0 = Alliance, 1 = Horde. winner_tid 2 is a draw
-- or a manual reset, which is neither a win nor a loss. The views this file used to create
-- read winner_tid 0 as a draw, so every Alliance win went uncounted as a Horde loss, and
-- the all-time view used other column names (lifetime_wins, total_matches, ...).
-- Keep these in step with the live views: the server reads both, but leaderboards and
-- .hlbg read the live names first.

DROP VIEW IF EXISTS `v_hlbg_player_seasonal_stats`;
CREATE SQL SECURITY INVOKER VIEW `v_hlbg_player_seasonal_stats` AS
SELECT
    `p`.`guid` AS `guid`,
    `p`.`account_id` AS `account_id`,
    `p`.`player_name` AS `player_name`,
    `p`.`account_name` AS `account_name`,
    `p`.`season_id` AS `season_id`,
    COUNT(CASE WHEN `wh`.`winner_tid` = `p`.`team` THEN 1 END) AS `wins`,
    COUNT(CASE WHEN `wh`.`winner_tid` IN (0, 1) AND `wh`.`winner_tid` <> `p`.`team` THEN 1 END) AS `losses`,
    COUNT(*) AS `games_played`,
    ROUND((COUNT(CASE WHEN `wh`.`winner_tid` = `p`.`team` THEN 1 END) * 100.0) / COUNT(*), 2) AS `win_rate`,
    SUM(`p`.`kills`) AS `total_kills`,
    SUM(`p`.`deaths`) AS `total_deaths`,
    ROUND(SUM(`p`.`kills`) / NULLIF(SUM(`p`.`deaths`), 0), 2) AS `kd_ratio`,
    ROUND(SUM(`p`.`kills`) / NULLIF(COUNT(*), 0), 2) AS `avg_kills_per_game`,
    ROUND(SUM(`p`.`damage_done`) / NULLIF(COUNT(*), 0), 0) AS `avg_damage_per_game`,
    SUM(`p`.`healing_done`) AS `total_healing`,
    SUM(`p`.`resources_captured`) AS `total_resources_captured`,
    SUM(`p`.`flags_returned`) AS `total_flags_returned`,
    COALESCE((
        SELECT
            SUM(`p2`.`rating_change`)
        FROM `dc_hlbg_match_participants` `p2`
        WHERE `p2`.`guid` = `p`.`guid` AND `p2`.`season_id` = `p`.`season_id`) + 1200, 1200) AS `current_rating`,
    MAX(`p`.`match_date`) AS `last_match_date`
FROM `dc_hlbg_match_participants` `p`
LEFT JOIN `dc_hlbg_winner_history` `wh` ON `p`.`match_id` = `wh`.`id`
GROUP BY `p`.`guid`, `p`.`account_id`, `p`.`player_name`, `p`.`account_name`, `p`.`season_id`;

DROP VIEW IF EXISTS `v_hlbg_player_alltime_stats`;
CREATE SQL SECURITY INVOKER VIEW `v_hlbg_player_alltime_stats` AS
SELECT
    `p`.`guid` AS `guid`,
    `p`.`account_id` AS `account_id`,
    `p`.`player_name` AS `player_name`,
    `p`.`account_name` AS `account_name`,
    COUNT(CASE WHEN `wh`.`winner_tid` = `p`.`team` THEN 1 END) AS `total_wins`,
    COUNT(CASE WHEN `wh`.`winner_tid` IN (0, 1) AND `wh`.`winner_tid` <> `p`.`team` THEN 1 END) AS `total_losses`,
    COUNT(*) AS `total_games_played`,
    ROUND((COUNT(CASE WHEN `wh`.`winner_tid` = `p`.`team` THEN 1 END) * 100.0) / COUNT(*), 2) AS `overall_win_rate`,
    SUM(`p`.`kills`) AS `total_kills`,
    SUM(`p`.`deaths`) AS `total_deaths`,
    ROUND(SUM(`p`.`kills`) / NULLIF(SUM(`p`.`deaths`), 0), 2) AS `overall_kd_ratio`,
    ROUND(SUM(`p`.`kills`) / NULLIF(COUNT(*), 0), 2) AS `avg_kills_per_game`,
    ROUND(SUM(`p`.`damage_done`) / NULLIF(COUNT(*), 0), 0) AS `avg_damage_per_game`,
    SUM(`p`.`healing_done`) AS `total_healing`,
    SUM(`p`.`resources_captured`) AS `total_resources_captured`,
    SUM(`p`.`flags_returned`) AS `total_flags_returned`,
    (
        SELECT
            COALESCE(SUM(`p2`.`rating_change`), 0) + 1200
        FROM `dc_hlbg_match_participants` `p2`
        WHERE `p2`.`guid` = `p`.`guid` AND `p2`.`season_id` = (
            SELECT
                MAX(`p3`.`season_id`)
            FROM `dc_hlbg_match_participants` `p3`
            WHERE `p3`.`guid` = `p`.`guid`)) AS `current_rating`,
    COUNT(DISTINCT `p`.`season_id`) AS `seasons_participated`,
    MIN(`p`.`match_date`) AS `first_match_date`,
    MAX(`p`.`match_date`) AS `last_match_date`
FROM `dc_hlbg_match_participants` `p`
LEFT JOIN `dc_hlbg_winner_history` `wh` ON `p`.`match_id` = `wh`.`id`
GROUP BY `p`.`guid`, `p`.`account_id`, `p`.`player_name`, `p`.`account_name`;

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
--    ORDER BY total_wins DESC 
--    LIMIT 10;

-- 4. Verify winner_history table exists:
--    SELECT COUNT(*) as match_count FROM `dc_hlbg_winner_history`;

-- 5. Check foreign key constraint:
--    SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
--    WHERE TABLE_NAME = 'dc_hlbg_match_participants' AND CONSTRAINT_NAME = 'fk_match_id';

-- ==============================================================================
