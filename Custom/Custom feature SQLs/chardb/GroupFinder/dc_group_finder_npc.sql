-- ============================================================================
-- Dark Chaos - Group Finder NPC and Configuration
-- ============================================================================
-- Run this after the schema file (dc_group_finder_schema.sql)
-- ============================================================================

-- ============================================================================
-- NPC: Group Finder NPC
-- ============================================================================
-- Uses entry 600100 - Update if conflicts with existing NPCs

SET @NPC_ENTRY := 600100;
SET @NPC_NAME := 'Group Finder';
SET @NPC_SUBNAME := 'Dungeon & Raid Finder';

-- Delete existing if present
DELETE FROM `creature_template` WHERE `entry` = @NPC_ENTRY;

-- Insert NPC
INSERT INTO `creature_template` (
    `entry`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`,
    `faction`, `npcflag`, `speed_walk`, `speed_run`, `unit_class`, `unit_flags`, `unit_flags2`,
    `type`, `type_flags`, `ScriptName`
) VALUES (
    @NPC_ENTRY,
    @NPC_NAME,
    @NPC_SUBNAME,
    'Directions',           -- IconName for gossip
    0,                      -- gossip_menu_id (handled by script)
    80,                     -- minlevel
    80,                     -- maxlevel
    35,                     -- faction (Friendly)
    1,                      -- npcflag (GOSSIP)
    1.0,                    -- speed_walk
    1.14286,                -- speed_run
    1,                      -- unit_class (Warrior)
    0,                      -- unit_flags
    0,                      -- unit_flags2
    7,                      -- type (Humanoid)
    0,                      -- type_flags
    'npc_group_finder'      -- ScriptName
);

-- NPC appearance (using a human male model with fancy gear)
UPDATE `creature_template` SET 
    `modelid1` = 24085,     -- Human male in plate armor
    `modelid2` = 0,
    `modelid3` = 0,
    `modelid4` = 0
WHERE `entry` = @NPC_ENTRY;

-- ============================================================================
-- Example spawn locations (customize for your mall/hub)
-- ============================================================================

-- Mall Hub spawn (adjust coordinates for your server)
-- DELETE FROM `creature` WHERE `id1` = @NPC_ENTRY;

-- INSERT INTO `creature` (`id1`, `map`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`) VALUES
-- (@NPC_ENTRY, 0, -8847.00, 629.00, 94.00, 3.14, 300);  -- Example: Stormwind

-- ============================================================================
-- Configuration options (add to worldserver.conf)
-- ============================================================================
/*
# Dark Chaos - Group Finder Configuration
# ========================================

# Enable/Disable the Group Finder system
# Default: 1 (enabled)
DC.GroupFinder.Enable = 1

# Enable cross-faction group finding
# Default: 0 (disabled)
DC.GroupFinder.CrossFaction = 0

# Maximum listings per player
# Default: 3
DC.GroupFinder.MaxListingsPerPlayer = 3

# Listing expiration time in minutes
# Default: 120 (2 hours)
DC.GroupFinder.ListingExpireMinutes = 120

# Maximum applications per player
# Default: 10
DC.GroupFinder.MaxApplicationsPerPlayer = 10

# Rating match range for M+ (how far off your rating a listing can be)
# Default: 200
DC.GroupFinder.RatingMatchRange = 200

# Keystone level match range (how far off your key level a listing can be)
# Default: 3
DC.GroupFinder.KeyLevelMatchRange = 3

# Cleanup interval in milliseconds
# Default: 60000 (1 minute)
DC.GroupFinder.CleanupIntervalMs = 60000

*/

-- ============================================================================
-- Mythic+ Dungeon List (if not already exists)
-- ============================================================================

-- Check if table exists, create if not
CREATE TABLE IF NOT EXISTS `dc_mplus_dungeons` (
    `map_id` INT UNSIGNED NOT NULL,
    `dungeon_name` VARCHAR(100) NOT NULL,
    `short_name` VARCHAR(10) NOT NULL,
    `timer_seconds` INT UNSIGNED NOT NULL DEFAULT 1800,
    `difficulty` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `min_level` TINYINT UNSIGNED NOT NULL DEFAULT 80,
    `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`map_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Mythic+ Dungeon definitions';

-- Insert/update dungeon list (WotLK heroic dungeons)
INSERT INTO `dc_mplus_dungeons` (`map_id`, `dungeon_name`, `short_name`, `timer_seconds`, `difficulty`, `min_level`, `enabled`)
VALUES
    (574, 'Utgarde Keep', 'UK', 1500, 1, 70, 1),
    (575, 'Utgarde Pinnacle', 'UP', 1800, 1, 75, 1),
    (576, 'The Nexus', 'NEX', 1800, 1, 70, 1),
    (578, 'The Oculus', 'OCC', 2100, 2, 75, 1),
    (595, 'The Culling of Stratholme', 'COS', 1800, 2, 75, 1),
    (599, 'Halls of Stone', 'HOS', 1800, 1, 75, 1),
    (600, 'Drak''Tharon Keep', 'DTK', 1800, 1, 72, 1),
    (601, 'Azjol-Nerub', 'AN', 1200, 1, 70, 1),
    (602, 'Halls of Lightning', 'HOL', 1800, 2, 75, 1),
    (604, 'Gundrak', 'GD', 1500, 1, 74, 1),
    (608, 'Violet Hold', 'VH', 1500, 1, 73, 1),
    (619, 'Ahn''kahet: The Old Kingdom', 'OK', 1800, 2, 70, 1),
    (632, 'The Forge of Souls', 'FOS', 1500, 2, 78, 1),
    (650, 'Trial of the Champion', 'TOC', 1200, 2, 78, 1),
    (658, 'Pit of Saron', 'POS', 1800, 2, 78, 1),
    (668, 'Halls of Reflection', 'HOR', 1500, 3, 78, 1)
ON DUPLICATE KEY UPDATE 
    `dungeon_name` = VALUES(`dungeon_name`),
    `short_name` = VALUES(`short_name`),
    `timer_seconds` = VALUES(`timer_seconds`);

-- ============================================================================
-- Player Mythic Rating Table (if not already exists)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_mplus_player_ratings` (
    `player_guid` INT UNSIGNED NOT NULL,
    `rating` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `highest_key` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `total_runs` INT UNSIGNED NOT NULL DEFAULT 0,
    `timed_runs` INT UNSIGNED NOT NULL DEFAULT 0,
    `season_id` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`player_guid`, `season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player Mythic+ ratings';

-- ============================================================================
-- Mythic+ Runs Table (for spectating)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_mplus_runs` (
    `run_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `map_id` INT UNSIGNED NOT NULL,
    `key_level` TINYINT UNSIGNED NOT NULL DEFAULT 2,
    `leader_guid` INT UNSIGNED NOT NULL,
    `start_time` TIMESTAMP NULL,
    `end_time` TIMESTAMP NULL,
    `timer_elapsed` INT UNSIGNED NOT NULL DEFAULT 0,
    `deaths` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `status` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=pending, 1=active, 2=completed, 3=failed, 4=abandoned',
    `allow_spectate` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `key_upgraded` TINYINT NOT NULL DEFAULT 0 COMMENT 'Number of levels upgraded (-1 to +3)',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`run_id`),
    INDEX `idx_status` (`status`),
    INDEX `idx_leader` (`leader_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Active and completed Mythic+ runs';

-- ============================================================================
-- Grant execute privileges if needed
-- ============================================================================
-- GRANT EXECUTE ON PROCEDURE `characters`.* TO 'acore'@'localhost';

SELECT CONCAT('Group Finder NPC created with entry: ', @NPC_ENTRY) AS 'Installation Complete';
