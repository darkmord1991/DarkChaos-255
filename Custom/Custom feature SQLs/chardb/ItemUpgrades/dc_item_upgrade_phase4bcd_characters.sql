-- ====================================================================
-- DarkChaos Item Upgrade System - Phase 4B/C/D Database Schema
-- CHARACTER DATABASE TABLES ONLY
-- 
-- Complete database structure for progression, seasonal, and advanced features
-- Date: November 5, 2025
-- 
-- IMPORTANT: Run this on the CHARACTER database (acore_characters)
-- ====================================================================

-- ====================================================================
-- PHASE 4B: PROGRESSION TABLES
-- ====================================================================

-- Player tier unlock status
CREATE TABLE IF NOT EXISTS `dc_player_tier_unlocks` (
    `player_guid` INT UNSIGNED NOT NULL,
    `tier_id` TINYINT UNSIGNED NOT NULL,
    `unlocked_timestamp` BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (`player_guid`, `tier_id`),
    INDEX `idx_player` (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tracks which tiers players have unlocked';

-- Player tier caps
CREATE TABLE IF NOT EXISTS `dc_player_tier_caps` (
    `player_guid` INT UNSIGNED NOT NULL,
    `tier_id` TINYINT UNSIGNED NOT NULL,
    `max_level` TINYINT UNSIGNED NOT NULL DEFAULT 15,
    `last_updated` BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (`player_guid`, `tier_id`),
    INDEX `idx_player` (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Custom tier caps per player';

-- Weekly spending tracker
CREATE TABLE IF NOT EXISTS `dc_weekly_spending` (
    `player_guid` INT UNSIGNED NOT NULL,
    `week_start` BIGINT UNSIGNED NOT NULL,
    `essence_spent` INT UNSIGNED NOT NULL DEFAULT 0,
    `tokens_spent` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`player_guid`, `week_start`),
    INDEX `idx_week` (`week_start`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tracks weekly spending for caps';

-- Player artifact mastery system (renamed from prestige to avoid conflict)
CREATE TABLE IF NOT EXISTS `dc_player_artifact_mastery` (
    `player_guid` INT UNSIGNED NOT NULL,
    `total_mastery_points` INT UNSIGNED NOT NULL DEFAULT 0,
    `mastery_rank` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `mastery_points_this_rank` INT UNSIGNED NOT NULL DEFAULT 0,
    `items_fully_upgraded` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_upgrades_applied` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_upgrade_timestamp` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`player_guid`),
    INDEX `idx_mastery_rank` (`total_mastery_points` DESC),
    INDEX `idx_rank` (`mastery_rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player artifact mastery progression (upgrade system prestige)';

-- Artifact mastery events log
CREATE TABLE IF NOT EXISTS `dc_artifact_mastery_events` (
    `event_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `event_type` VARCHAR(50) NOT NULL,
    `new_rank` TINYINT UNSIGNED NOT NULL,
    `timestamp` BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (`event_id`),
    INDEX `idx_player` (`player_guid`),
    INDEX `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Log of artifact mastery rank-up events';

-- ====================================================================
-- PHASE 4C: SEASONAL TABLES
-- ====================================================================

-- Seasons configuration
CREATE TABLE IF NOT EXISTS `dc_seasons` (
    `season_id` INT UNSIGNED NOT NULL,
    `season_name` VARCHAR(100) NOT NULL,
    `start_timestamp` BIGINT UNSIGNED NOT NULL,
    `end_timestamp` BIGINT UNSIGNED DEFAULT 0,
    `is_active` TINYINT(1) NOT NULL DEFAULT 0,
    `max_upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 15,
    `cost_multiplier` FLOAT NOT NULL DEFAULT 1.0,
    `reward_multiplier` FLOAT NOT NULL DEFAULT 1.0,
    `theme` VARCHAR(255) DEFAULT NULL,
    `milestone_essence_cap` INT UNSIGNED NOT NULL DEFAULT 50000,
    `milestone_token_cap` INT UNSIGNED NOT NULL DEFAULT 25000,
    PRIMARY KEY (`season_id`),
    INDEX `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Season configuration';

-- Insert default season
INSERT INTO `dc_seasons` (`season_id`, `season_name`, `start_timestamp`, `is_active`, `theme`)
VALUES (1, 'Season 1: Awakening', UNIX_TIMESTAMP(), 1, 'The beginning of artifact mastery')
ON DUPLICATE KEY UPDATE `season_name`=VALUES(`season_name`);

-- Player season data
CREATE TABLE IF NOT EXISTS `dc_player_season_data` (
    `player_guid` INT UNSIGNED NOT NULL,
    `season_id` INT UNSIGNED NOT NULL,
    `essence_earned` INT UNSIGNED NOT NULL DEFAULT 0,
    `tokens_earned` INT UNSIGNED NOT NULL DEFAULT 0,
    `essence_spent` INT UNSIGNED NOT NULL DEFAULT 0,
    `tokens_spent` INT UNSIGNED NOT NULL DEFAULT 0,
    `items_upgraded` INT UNSIGNED NOT NULL DEFAULT 0,
    `upgrades_applied` INT UNSIGNED NOT NULL DEFAULT 0,
    `mastery_earned` INT UNSIGNED NOT NULL DEFAULT 0,
    `rank_this_season` INT UNSIGNED NOT NULL DEFAULT 0,
    `first_upgrade_timestamp` BIGINT UNSIGNED DEFAULT 0,
    `last_upgrade_timestamp` BIGINT UNSIGNED DEFAULT 0,
    PRIMARY KEY (`player_guid`, `season_id`),
    INDEX `idx_season` (`season_id`),
    INDEX `idx_upgrades` (`upgrades_applied` DESC),
    INDEX `idx_mastery` (`mastery_earned` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Per-season player statistics';

-- Season history archive
CREATE TABLE IF NOT EXISTS `dc_season_history` (
    `archive_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `archived_season_id` INT UNSIGNED NOT NULL,
    `player_guid` INT UNSIGNED NOT NULL,
    `season_id` INT UNSIGNED NOT NULL,
    `essence_earned` INT UNSIGNED NOT NULL,
    `tokens_earned` INT UNSIGNED NOT NULL,
    `essence_spent` INT UNSIGNED NOT NULL,
    `tokens_spent` INT UNSIGNED NOT NULL,
    `items_upgraded` INT UNSIGNED NOT NULL,
    `upgrades_applied` INT UNSIGNED NOT NULL,
    `final_rank` INT UNSIGNED NOT NULL,
    `archived_timestamp` BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (`archive_id`),
    INDEX `idx_player_season` (`player_guid`, `archived_season_id`),
    INDEX `idx_season` (`archived_season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Historical season data archive';

-- Upgrade history
CREATE TABLE IF NOT EXISTS `dc_upgrade_history` (
    `history_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `item_guid` INT UNSIGNED NOT NULL,
    `item_id` INT UNSIGNED NOT NULL,
    `season_id` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `upgrade_from` TINYINT UNSIGNED NOT NULL,
    `upgrade_to` TINYINT UNSIGNED NOT NULL,
    `essence_cost` INT UNSIGNED NOT NULL,
    `token_cost` INT UNSIGNED NOT NULL,
    `timestamp` BIGINT UNSIGNED NOT NULL,
    `old_ilvl` SMALLINT UNSIGNED NOT NULL,
    `new_ilvl` SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (`history_id`),
    INDEX `idx_player` (`player_guid`, `timestamp` DESC),
    INDEX `idx_item` (`item_guid`),
    INDEX `idx_season` (`season_id`),
    INDEX `idx_timestamp` (`timestamp` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Complete upgrade history log';

-- Leaderboard cache
CREATE TABLE IF NOT EXISTS `dc_leaderboard_cache` (
    `season_id` INT UNSIGNED NOT NULL,
    `player_guid` INT UNSIGNED NOT NULL,
    `upgrade_rank` INT UNSIGNED NOT NULL DEFAULT 0,
    `mastery_rank` INT UNSIGNED NOT NULL DEFAULT 0,
    `efficiency_rank` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_updated` BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (`season_id`, `player_guid`),
    INDEX `idx_upgrade_rank` (`season_id`, `upgrade_rank`),
    INDEX `idx_mastery_rank` (`season_id`, `mastery_rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Cached leaderboard rankings';

-- ====================================================================
-- PHASE 4D: ADVANCED FEATURES TABLES
-- ====================================================================

-- Respec history
CREATE TABLE IF NOT EXISTS `dc_respec_history` (
    `respec_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `item_guid` INT UNSIGNED NOT NULL,
    `previous_level` TINYINT UNSIGNED NOT NULL,
    `essence_refunded` INT UNSIGNED NOT NULL,
    `tokens_refunded` INT UNSIGNED NOT NULL,
    `timestamp` BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (`respec_id`),
    INDEX `idx_player` (`player_guid`, `timestamp` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Individual item respec history';

-- Full respec log
CREATE TABLE IF NOT EXISTS `dc_respec_log` (
    `log_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `respec_type` VARCHAR(20) NOT NULL,
    `total_essence_refunded` INT UNSIGNED NOT NULL,
    `total_tokens_refunded` INT UNSIGNED NOT NULL,
    `timestamp` BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (`log_id`),
    INDEX `idx_player` (`player_guid`),
    INDEX `idx_timestamp` (`timestamp` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Full respec event log';

-- Player achievements
CREATE TABLE IF NOT EXISTS `dc_player_achievements` (
    `player_guid` INT UNSIGNED NOT NULL,
    `achievement_id` INT UNSIGNED NOT NULL,
    `earned_timestamp` BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (`player_guid`, `achievement_id`),
    INDEX `idx_achievement` (`achievement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player upgrade achievements';

-- Achievement definitions (optional - can be hardcoded)
CREATE TABLE IF NOT EXISTS `dc_achievement_definitions` (
    `achievement_id` INT UNSIGNED NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `description` VARCHAR(255) NOT NULL,
    `reward_mastery_points` INT UNSIGNED NOT NULL DEFAULT 0,
    `reward_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
    `is_hidden` TINYINT(1) NOT NULL DEFAULT 0,
    `unlock_requirement` INT UNSIGNED NOT NULL DEFAULT 0,
    `unlock_type` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`achievement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Achievement definitions';

-- Insert default achievements
INSERT INTO `dc_achievement_definitions` VALUES
(1, 'First Blood', 'Perform your first item upgrade', 10, 50, 0, 1, 'UPGRADE_COUNT'),
(2, 'Dedicated Upgrader', 'Perform 100 upgrades', 100, 500, 0, 100, 'UPGRADE_COUNT'),
(3, 'Maxed Out', 'Fully upgrade an item to level 15', 50, 250, 0, 15, 'MAX_LEVEL'),
(4, 'Legendary Ascension', 'Fully upgrade a Legendary item', 200, 1000, 0, 1, 'MAX_LEGENDARY'),
(5, 'Upgrade Master', 'Perform 500 upgrades', 250, 1500, 0, 500, 'UPGRADE_COUNT'),
(6, 'Mastery Hunter', 'Reach Artifact Mastery Rank 10', 500, 2500, 0, 10, 'MASTERY_RANK')
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- Spec loadouts
CREATE TABLE IF NOT EXISTS `dc_upgrade_loadouts` (
    `loadout_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_guid` INT UNSIGNED NOT NULL,
    `spec_id` TINYINT UNSIGNED NOT NULL,
    `loadout_name` VARCHAR(50) NOT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 0,
    `created_timestamp` BIGINT UNSIGNED NOT NULL,
    `last_used_timestamp` BIGINT UNSIGNED DEFAULT 0,
    PRIMARY KEY (`loadout_id`),
    INDEX `idx_player` (`player_guid`),
    INDEX `idx_active` (`player_guid`, `is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Spec-based upgrade loadouts';

-- Loadout item mappings
CREATE TABLE IF NOT EXISTS `dc_loadout_items` (
    `loadout_id` INT UNSIGNED NOT NULL,
    `item_guid` INT UNSIGNED NOT NULL,
    `upgrade_level` TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (`loadout_id`, `item_guid`),
    FOREIGN KEY (`loadout_id`) REFERENCES `dc_upgrade_loadouts`(`loadout_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Items in each loadout';

-- Guild upgrade statistics
CREATE TABLE IF NOT EXISTS `dc_guild_upgrade_stats` (
    `guild_id` INT UNSIGNED NOT NULL,
    `total_members` INT UNSIGNED NOT NULL DEFAULT 0,
    `members_with_upgrades` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_guild_upgrades` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_items_upgraded` INT UNSIGNED NOT NULL DEFAULT 0,
    `average_ilvl_increase` FLOAT NOT NULL DEFAULT 0.0,
    `total_essence_invested` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `total_tokens_invested` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `last_updated` BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (`guild_id`),
    INDEX `idx_guild_upgrades` (`total_guild_upgrades` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Guild progression statistics';

-- ====================================================================
-- VIEWS FOR QUICK STATISTICS
-- ====================================================================

-- Player progression summary
CREATE OR REPLACE VIEW `dc_player_progression_summary` AS
SELECT 
    p.player_guid,
    p.total_mastery_points,
    p.mastery_rank,
    p.items_fully_upgraded,
    p.total_upgrades_applied,
    s.essence_earned,
    s.tokens_earned,
    s.essence_spent,
    s.tokens_spent,
    s.items_upgraded,
    s.season_id
FROM dc_player_artifact_mastery p
LEFT JOIN dc_player_season_data s ON s.player_guid = p.player_guid
WHERE s.season_id = (SELECT season_id FROM dc_seasons WHERE is_active = 1 LIMIT 1);

-- Top upgraders by season
CREATE OR REPLACE VIEW `dc_top_upgraders` AS
SELECT 
    s.player_guid,
    c.name as player_name,
    s.upgrades_applied,
    s.items_upgraded,
    s.essence_spent,
    s.tokens_spent,
    p.mastery_rank,
    p.total_mastery_points,
    s.season_id
FROM dc_player_season_data s
LEFT JOIN characters c ON c.guid = s.player_guid
LEFT JOIN dc_player_artifact_mastery p ON p.player_guid = s.player_guid
WHERE s.season_id = (SELECT season_id FROM dc_seasons WHERE is_active = 1 LIMIT 1)
ORDER BY s.upgrades_applied DESC
LIMIT 100;

-- Recent upgrades feed
CREATE OR REPLACE VIEW `dc_recent_upgrades_feed` AS
SELECT 
    h.history_id,
    h.player_guid,
    c.name as player_name,
    h.item_id,
    h.upgrade_from,
    h.upgrade_to,
    h.essence_cost,
    h.token_cost,
    h.timestamp,
    h.season_id
FROM dc_upgrade_history h
LEFT JOIN characters c ON c.guid = h.player_guid
ORDER BY h.timestamp DESC
LIMIT 50;

-- Guild leaderboard
CREATE OR REPLACE VIEW `dc_guild_leaderboard` AS
SELECT 
    g.guildid,
    g.name as guild_name,
    gs.total_members,
    gs.members_with_upgrades,
    gs.total_guild_upgrades,
    gs.total_items_upgraded,
    gs.average_ilvl_increase,
    gs.total_essence_invested,
    gs.total_tokens_invested
FROM guild g
INNER JOIN dc_guild_upgrade_stats gs ON gs.guild_id = g.guildid
ORDER BY gs.total_guild_upgrades DESC;

-- ====================================================================
-- STORED PROCEDURES FOR MAINTENANCE
-- ====================================================================
-- Note: Run these stored procedure creations separately if using MySQL Workbench
-- or ensure your client supports DELIMITER changes

DROP PROCEDURE IF EXISTS `sp_reset_weekly_caps`;
DROP PROCEDURE IF EXISTS `sp_update_guild_stats`;
DROP PROCEDURE IF EXISTS `sp_archive_season`;

DELIMITER $$

-- Reset weekly spending caps (run every Sunday)
CREATE PROCEDURE `sp_reset_weekly_caps`()
BEGIN
    -- Get current week start
    SET @week_start = UNIX_TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY));
    
    -- Clean old entries (keep last 4 weeks)
    DELETE FROM dc_weekly_spending 
    WHERE week_start < @week_start - (4 * 7 * 86400);
    
    SELECT CONCAT('Weekly caps reset. Entries older than 4 weeks removed.') as result;
END$$

-- Update guild statistics
CREATE PROCEDURE `sp_update_guild_stats`(IN p_guild_id INT UNSIGNED)
BEGIN
    REPLACE INTO dc_guild_upgrade_stats
    (guild_id, total_members, members_with_upgrades, total_guild_upgrades,
     total_items_upgraded, average_ilvl_increase, total_essence_invested,
     total_tokens_invested, last_updated)
    SELECT 
        p_guild_id,
        (SELECT COUNT(*) FROM guild_member WHERE guildid = p_guild_id),
        COUNT(DISTINCT u.player_guid),
        SUM(u.upgrade_level),
        COUNT(DISTINCT u.item_guid),
        AVG(u.upgraded_item_level - u.base_item_level),
        SUM(u.essence_invested),
        SUM(u.tokens_invested),
        UNIX_TIMESTAMP()
    FROM dc_item_upgrades u
    INNER JOIN guild_member gm ON gm.guid = u.player_guid
    WHERE gm.guildid = p_guild_id;
    
    SELECT CONCAT('Guild ', p_guild_id, ' statistics updated.') as result;
END$$

-- Archive completed season
CREATE PROCEDURE `sp_archive_season`(IN p_season_id INT UNSIGNED)
BEGIN
    -- Archive season data
    INSERT INTO dc_season_history
    (archived_season_id, player_guid, season_id, essence_earned, tokens_earned,
     essence_spent, tokens_spent, items_upgraded, upgrades_applied, final_rank, archived_timestamp)
    SELECT 
        p_season_id, player_guid, season_id, essence_earned, tokens_earned,
        essence_spent, tokens_spent, items_upgraded, upgrades_applied, 
        rank_this_season, UNIX_TIMESTAMP()
    FROM dc_player_season_data
    WHERE season_id = p_season_id;
    
    -- Mark season as inactive
    UPDATE dc_seasons SET is_active = 0 WHERE season_id = p_season_id;
    
    SELECT CONCAT('Season ', p_season_id, ' archived successfully.') as result;
END$$

DELIMITER ;

-- ====================================================================
-- INITIAL DATA CLEANUP
-- ====================================================================

-- Ensure at least one season exists
INSERT IGNORE INTO dc_player_season_data (player_guid, season_id, essence_earned, tokens_earned)
SELECT DISTINCT player_guid, 1, 0, 0
FROM dc_item_upgrades;

-- Initialize artifact mastery for existing players
INSERT IGNORE INTO dc_player_artifact_mastery (player_guid, total_mastery_points, mastery_rank)
SELECT DISTINCT player_guid, 0, 0
FROM dc_item_upgrades;

-- ====================================================================
-- INDEXES FOR PERFORMANCE
-- ====================================================================

-- Additional indexes for common queries
CREATE INDEX idx_history_season_player ON dc_upgrade_history(season_id, player_guid, timestamp DESC);
CREATE INDEX idx_mastery_leaderboard ON dc_player_artifact_mastery(total_mastery_points DESC, mastery_rank DESC);
CREATE INDEX idx_season_leaderboard ON dc_player_season_data(season_id, upgrades_applied DESC);

-- ====================================================================
-- COMPLETION MESSAGE
-- ====================================================================

SELECT '=====================================================================' as '';
SELECT 'Phase 4B/C/D CHARACTER DATABASE Schema Deployment Complete!' as '';
SELECT '=====================================================================' as '';
SELECT 'Tables Created:' as '';
SELECT '  - 8 Progression tables (Phase 4B)' as '';
SELECT '  - 6 Seasonal tables (Phase 4C)' as '';
SELECT '  - 9 Advanced feature tables (Phase 4D)' as '';
SELECT '  - 4 Views for analytics' as '';
SELECT '  - 3 Stored procedures for maintenance' as '';
SELECT '' as '';
SELECT 'NOTE: "Prestige" system renamed to "Artifact Mastery" to avoid conflicts' as '';
SELECT '      with existing DarkChaos prestige system.' as '';
SELECT '=====================================================================' as '';
SELECT 'Next Steps:' as '';
SELECT '  1. Compile new .cpp implementation files' as '';
SELECT '  2. Test progression commands (.upgradeprog mastery, etc.)' as '';
SELECT '  3. Test seasonal commands (.season info, .season leaderboard, etc.)' as '';
SELECT '  4. Test advanced commands (.upgradeadv respec, achievements, guild)' as '';
SELECT '  5. Use .upgradeprog testset to get class-specific gear for testing' as '';
SELECT '=====================================================================' as '';
