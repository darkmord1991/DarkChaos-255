-- ============================================================================
-- DUNGEON QUEST SYSTEM - WORLD DATABASE SCHEMA
-- ============================================================================
-- This file contains WORLD database tables for:
-- - Dungeon quest configuration and mapping
-- - NPC spawn locations and phasing
-- - Quest definitions and objectives
-- - Reward configuration
-- - System configuration
-- ============================================================================
-- Database: acore_world
-- Prefix: dc_ (DarkChaos custom tables)
-- Version: 1.0 (Updated with dc_ prefix)
-- Date: November 3, 2025
-- ============================================================================

-- ============================================================================
-- DUNGEON CONFIGURATION
-- ============================================================================

-- Table: dc_dungeon_quest_mapping
-- Purpose: Map dungeon instances to quest systems and phases
CREATE TABLE IF NOT EXISTS `dc_dungeon_quest_mapping` (
  `dungeon_id` int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique dungeon ID',
  `dungeon_name` varchar(100) NOT NULL COMMENT 'Human-readable dungeon name',
  `map_id` int unsigned NOT NULL COMMENT 'World map ID for this dungeon',
  `phase_id` smallint unsigned NOT NULL COMMENT 'Phase ID for phasing (100-152)',
  `npc_entry` int unsigned NOT NULL COMMENT 'Quest giver NPC entry ID',
  `min_level` tinyint unsigned NOT NULL DEFAULT '60' COMMENT 'Minimum level',
  `max_level` tinyint unsigned NOT NULL DEFAULT '85' COMMENT 'Maximum level',
  `difficulty` enum('NORMAL','HEROIC','MYTHIC') NOT NULL DEFAULT 'NORMAL',
  `tier` enum('VANILLA','TBC','WOTLK') NOT NULL COMMENT 'Dungeon tier',
  `daily_quest_count` tinyint unsigned NOT NULL DEFAULT '5' COMMENT 'Daily quests available',
  `weekly_quest_count` tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Weekly quests available',
  `token_type` int unsigned NOT NULL COMMENT 'Token item ID for rewards',
  `base_gold_reward` int unsigned NOT NULL DEFAULT '1000' COMMENT 'Gold per quest',
  `base_token_reward` int unsigned NOT NULL DEFAULT '5' COMMENT 'Tokens per quest',
  `enabled` tinyint unsigned NOT NULL DEFAULT '1',
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`dungeon_id`),
  UNIQUE KEY `uk_map_id` (`map_id`),
  UNIQUE KEY `uk_phase_id` (`phase_id`),
  KEY `idx_npc_entry` (`npc_entry`),
  KEY `idx_tier` (`tier`),
  KEY `idx_difficulty` (`difficulty`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Dungeon quest system configuration';

-- ============================================================================
-- NPC SPAWNING AND PHASING
-- ============================================================================

-- Table: dc_dungeon_quest_npcs
-- Purpose: NPC spawning data with phasing
CREATE TABLE IF NOT EXISTS `dc_dungeon_quest_npcs` (
  `npc_id` int unsigned NOT NULL AUTO_INCREMENT,
  `npc_entry` int unsigned NOT NULL COMMENT 'Creature entry ID',
  `dungeon_id` int unsigned NOT NULL COMMENT 'Which dungeon (foreign key)',
  `spawn_x` float NOT NULL DEFAULT '0',
  `spawn_y` float NOT NULL DEFAULT '0',
  `spawn_z` float NOT NULL DEFAULT '0',
  `spawn_o` float NOT NULL DEFAULT '0' COMMENT 'Orientation',
  `phase_mask` int unsigned NOT NULL DEFAULT '1' COMMENT 'Phase visibility',
  `spawn_dist` float NOT NULL DEFAULT '5' COMMENT 'Spawn distance from home',
  `movement_type` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=static, 1=wander, 2=waypoints',
  `is_visible_on_entry` tinyint unsigned NOT NULL DEFAULT '1' COMMENT '1=appears when entering, 0=hidden',
  `despawn_on_combat` tinyint unsigned NOT NULL DEFAULT '1' COMMENT '1=disappear at first combat',
  `despawn_timer_ms` int unsigned NOT NULL DEFAULT '0' COMMENT 'Combat timeout before despawn (0=immediate)',
  `respawn_enabled` tinyint unsigned NOT NULL DEFAULT '1' COMMENT '1=manual respawn command available',
  `respawn_cooldown_sec` int unsigned NOT NULL DEFAULT '300' COMMENT 'Cooldown between respawns (5 min default)',
  PRIMARY KEY (`npc_id`),
  KEY `idx_npc_entry` (`npc_entry`),
  KEY `idx_dungeon_id` (`dungeon_id`),
  KEY `idx_phase_mask` (`phase_mask`),
  CONSTRAINT `fk_npc_dungeon_id` 
    FOREIGN KEY (`dungeon_id`) REFERENCES `dc_dungeon_quest_mapping` (`dungeon_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='NPC spawning configuration with combat-based despawn';

-- Table: dc_creature_phase_visibility
-- Purpose: Map creatures to phases for visibility
CREATE TABLE IF NOT EXISTS `dc_creature_phase_visibility` (
  `creature_guid` int unsigned NOT NULL COMMENT 'Creature GUID from creature table',
  `phase_id` smallint unsigned NOT NULL COMMENT 'Phase ID for visibility',
  `visible_by_default` tinyint unsigned NOT NULL DEFAULT '1' COMMENT '1=visible, 0=hidden by default',
  PRIMARY KEY (`creature_guid`, `phase_id`),
  KEY `idx_phase_id` (`phase_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Define which creatures appear in which phases';

-- ============================================================================
-- QUEST DEFINITIONS
-- ============================================================================

-- Table: dc_dungeon_quest_definitions
-- Purpose: Define daily/weekly quests
CREATE TABLE IF NOT EXISTS `dc_dungeon_quest_definitions` (
  `quest_id` int unsigned NOT NULL AUTO_INCREMENT,
  `dungeon_id` int unsigned NOT NULL COMMENT 'Which dungeon',
  `quest_type` enum('DAILY','WEEKLY','SPECIAL') NOT NULL DEFAULT 'DAILY',
  `title` varchar(200) NOT NULL,
  `description` text NOT NULL,
  `objective_count` int unsigned NOT NULL DEFAULT '1',
  `objective_type` enum('DEFEAT_BOSSES','COLLECT_ITEMS','DEFEAT_CREATURES','SPECIAL_OBJECTIVE','SPEEDRUN') NOT NULL,
  `objective_description` varchar(255) NOT NULL,
  `token_reward` int unsigned NOT NULL DEFAULT '5',
  `gold_reward` int unsigned NOT NULL DEFAULT '1000',
  `item_reward_entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'Optional item reward',
  `achievement_link` int unsigned NOT NULL DEFAULT '0' COMMENT 'Achievement ID for tracking',
  `order_index` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Display order',
  `enabled` tinyint unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`quest_id`),
  KEY `idx_dungeon_id` (`dungeon_id`),
  KEY `idx_quest_type` (`quest_type`),
  KEY `idx_achievement_link` (`achievement_link`),
  CONSTRAINT `fk_quest_dungeon_id` 
    FOREIGN KEY (`dungeon_id`) REFERENCES `dc_dungeon_quest_mapping` (`dungeon_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Define individual quest objectives';

-- ============================================================================
-- REWARD CONFIGURATION
-- ============================================================================

-- Table: dc_dungeon_quest_rewards
-- Purpose: Reward configuration per achievement
CREATE TABLE IF NOT EXISTS `dc_dungeon_quest_rewards` (
  `reward_id` int unsigned NOT NULL AUTO_INCREMENT,
  `achievement_id` int unsigned NOT NULL COMMENT 'Achievement ID from achievement_dbc',
  `dungeon_id` int unsigned NOT NULL,
  `token_count` int unsigned NOT NULL DEFAULT '5',
  `gold_count` int unsigned NOT NULL DEFAULT '1000',
  `item_entries` varchar(500) COMMENT 'Comma-separated item IDs',
  `reputation_id` int unsigned NOT NULL DEFAULT '0',
  `reputation_gain` int unsigned NOT NULL DEFAULT '0',
  `quest_item_id` int unsigned NOT NULL DEFAULT '0' COMMENT 'Special token item',
  PRIMARY KEY (`reward_id`),
  KEY `idx_achievement_id` (`achievement_id`),
  KEY `idx_dungeon_id` (`dungeon_id`),
  CONSTRAINT `fk_reward_dungeon_id` 
    FOREIGN KEY (`dungeon_id`) REFERENCES `dc_dungeon_quest_mapping` (`dungeon_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Define rewards for achievements';

-- ============================================================================
-- SYSTEM CONFIGURATION
-- ============================================================================

-- Table: dc_dungeon_quest_config
-- Purpose: Global configuration
CREATE TABLE IF NOT EXISTS `dc_dungeon_quest_config` (
  `config_id` int unsigned NOT NULL AUTO_INCREMENT,
  `config_key` varchar(100) NOT NULL UNIQUE,
  `config_value` text NOT NULL,
  `description` varchar(255) NOT NULL,
  `updated_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`config_id`),
  UNIQUE KEY `uk_config_key` (`config_key`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Global dungeon quest system configuration';

-- ============================================================================
-- SAMPLE DATA
-- ============================================================================

-- Sample dungeon configurations (first 5 dungeons)
INSERT INTO `dc_dungeon_quest_mapping` 
  (`dungeon_id`, `dungeon_name`, `map_id`, `phase_id`, `npc_entry`, `min_level`, `max_level`, `difficulty`, `tier`, `daily_quest_count`, `weekly_quest_count`, `token_type`, `base_gold_reward`, `base_token_reward`)
VALUES
  (1, 'Blackrock Depths', 228, 100, 700001, 52, 60, 'NORMAL', 'VANILLA', 5, 2, 700001, 1500, 5),
  (2, 'Stratholme', 329, 101, 700002, 60, 70, 'NORMAL', 'VANILLA', 5, 2, 700002, 2000, 5),
  (3, 'Molten Core', 409, 102, 700003, 60, 80, 'HEROIC', 'VANILLA', 5, 2, 700003, 2500, 8),
  (4, 'Black Temple', 564, 103, 700004, 70, 85, 'HEROIC', 'TBC', 5, 2, 700004, 3000, 10),
  (5, 'Ulduar', 533, 104, 700005, 80, 85, 'MYTHIC', 'WOTLK', 5, 2, 700005, 4000, 15);

-- Global configuration
INSERT INTO `dc_dungeon_quest_config` 
  (`config_key`, `config_value`, `description`)
VALUES
  ('SYSTEM_ENABLED', '1', 'Enable/disable dungeon quest system'),
  ('COMBAT_DESPAWN_ENABLED', '1', 'Enable NPC despawn on first combat'),
  ('MANUAL_RESPAWN_ENABLED', '1', 'Enable manual respawn command'),
  ('RESPAWN_COOLDOWN_DEFAULT', '300', 'Default respawn cooldown in seconds'),
  ('DAILY_RESET_HOUR', '6', 'Hour of day for daily reset (0-23)'),
  ('WEEKLY_RESET_DAY', 'TUESDAY', 'Day of week for weekly reset'),
  ('REWARD_TOKEN_ID_DEFAULT', '700001', 'Default reward token item ID'),
  ('MAX_CONCURRENT_QUESTS', '2', 'Max simultaneous quests per player');

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX idx_mapping_tier ON `dc_dungeon_quest_mapping` (`tier`);
CREATE INDEX idx_mapping_enabled ON `dc_dungeon_quest_mapping` (`enabled`);
CREATE INDEX idx_npcs_phase ON `dc_dungeon_quest_npcs` (`phase_mask`, `dungeon_id`);
CREATE INDEX idx_npcs_despawn ON `dc_dungeon_quest_npcs` (`despawn_on_combat`);
CREATE INDEX idx_quest_dungeon_type ON `dc_dungeon_quest_definitions` (`dungeon_id`, `quest_type`);
CREATE INDEX idx_visibility_phase ON `dc_creature_phase_visibility` (`phase_id`);

-- ============================================================================
-- END OF WORLD DATABASE SCHEMA
-- ============================================================================
