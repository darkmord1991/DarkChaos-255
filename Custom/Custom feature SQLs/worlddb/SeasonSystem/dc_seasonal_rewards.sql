-- Seasonal Quest & Chest Reward System - World Database Schema
-- Location: Custom/Custom feature SQLs/worlddb/dc_seasonal_rewards.sql
-- This file should be executed on the WORLD database

-- =====================================================================
-- TABLE: dc_seasonal_quest_rewards
-- =====================================================================
-- Stores quest reward configurations per season
-- Links: seasons.season_id -> quest ID from quest_template

DROP TABLE IF EXISTS `dc_seasonal_quest_rewards`;

CREATE TABLE `dc_seasonal_quest_rewards` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Foreign key to dc_seasons.season_id',
  `quest_id` INT UNSIGNED NOT NULL COMMENT 'Quest template ID',
  `reward_type` TINYINT NOT NULL COMMENT '1=Token, 2=Essence, 3=Both',
  `base_token_amount` INT UNSIGNED DEFAULT 0 COMMENT 'Base tokens awarded',
  `base_essence_amount` INT UNSIGNED DEFAULT 0 COMMENT 'Base essence awarded',
  `min_level` TINYINT UNSIGNED DEFAULT 1 COMMENT 'Minimum player level to reward',
  `quest_difficulty` TINYINT DEFAULT 2 COMMENT 'Difficulty tier (0-5, where 2=normal)',
  `seasonal_multiplier` FLOAT DEFAULT 1.0 COMMENT 'Season-specific multiplier (e.g., 1.15 for +15%)',
  `is_daily` BOOLEAN DEFAULT FALSE COMMENT 'Daily quest flag',
  `is_weekly` BOOLEAN DEFAULT FALSE COMMENT 'Weekly quest flag',
  `is_repeatable` BOOLEAN DEFAULT FALSE COMMENT 'Repeatable quest flag',
  `enabled` BOOLEAN DEFAULT TRUE COMMENT 'Enable/disable rewards for this quest',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_quest` (`season_id`, `quest_id`) COMMENT 'One reward config per quest per season',
  KEY `idx_season_id` (`season_id`),
  KEY `idx_quest_id` (`quest_id`),
  KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Quest reward configuration per season - Ascension/Remix style';

-- =====================================================================
-- TABLE: dc_seasonal_creature_rewards
-- =====================================================================
-- Stores boss/rare/creature kill reward configurations per season

DROP TABLE IF EXISTS `dc_seasonal_creature_rewards`;

CREATE TABLE `dc_seasonal_creature_rewards` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Foreign key to dc_seasons.season_id',
  `creature_id` INT UNSIGNED NOT NULL COMMENT 'Creature template ID',
  `reward_type` TINYINT NOT NULL COMMENT '1=Token, 2=Essence, 3=Both',
  `base_token_amount` INT UNSIGNED DEFAULT 0 COMMENT 'Base tokens per kill',
  `base_essence_amount` INT UNSIGNED DEFAULT 0 COMMENT 'Base essence per kill',
  `creature_rank` TINYINT DEFAULT 0 COMMENT 'Rank: 0=Normal, 1=Rare, 2=Boss, 3=Raid Boss',
  `content_type` TINYINT DEFAULT 1 COMMENT '1=Dungeon, 2=Raid, 3=World',
  `difficulty_level` TINYINT DEFAULT 1 COMMENT 'Content difficulty (1-5)',
  `seasonal_multiplier` FLOAT DEFAULT 1.0 COMMENT 'Season-specific multiplier',
  `minimum_players` TINYINT UNSIGNED DEFAULT 1 COMMENT 'Minimum group size required for reward',
  `group_split_tokens` BOOLEAN DEFAULT TRUE COMMENT 'Split tokens equally among group, or give all?',
  `enabled` BOOLEAN DEFAULT TRUE COMMENT 'Enable/disable rewards for this creature',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_creature` (`season_id`, `creature_id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_creature_id` (`creature_id`),
  KEY `idx_rank_type` (`creature_rank`, `content_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Boss/Rare/Creature kill reward configuration per season';

-- =====================================================================
-- TABLE: dc_seasonal_chest_rewards
-- =====================================================================
-- Stores loot pool for seasonal chests that drop from quests/bosses

DROP TABLE IF EXISTS `dc_seasonal_chest_rewards`;

CREATE TABLE `dc_seasonal_chest_rewards` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Foreign key to dc_seasons.season_id',
  `chest_tier` TINYINT NOT NULL COMMENT 'Tier: 1=Bronze, 2=Silver, 3=Gold, 4=Legendary',
  `item_id` INT UNSIGNED NOT NULL COMMENT 'Item template ID',
  `min_drop_ilvl` SMALLINT UNSIGNED DEFAULT 0 COMMENT 'Minimum item level (0=use item_template)',
  `max_drop_ilvl` SMALLINT UNSIGNED DEFAULT 0 COMMENT 'Maximum item level (0=use item_template)',
  `drop_chance` FLOAT NOT NULL DEFAULT 1.0 COMMENT 'Probability 0.0-1.0',
  `weight` INT UNSIGNED DEFAULT 1 COMMENT 'Selection weight in weighted random (higher=more likely)',
  `armor_class` TINYINT UNSIGNED COMMENT 'Filter: 1=Cloth, 2=Leather, 3=Mail, 4=Plate (NULL=all)',
  `slot` TINYINT UNSIGNED COMMENT 'Equipment slot filter (optional)',
  `class_restrictions` VARCHAR(255) COMMENT 'Comma-separated class IDs (1,2,3... NULL=all)',
  `spec_restrictions` VARCHAR(255) COMMENT 'Comma-separated spec names for filtering',
  `primary_stat` VARCHAR(50) COMMENT 'Primary stat priority (INT, STR, AGI, etc)',
  `enabled` BOOLEAN DEFAULT TRUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  KEY `idx_season_tier` (`season_id`, `chest_tier`),
  KEY `idx_item_id` (`item_id`),
  KEY `idx_chest_tier` (`chest_tier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Chest loot pool configuration - items that can drop';

-- =====================================================================
-- TABLE: dc_seasonal_reward_multipliers
-- =====================================================================
-- Dynamic multiplier overrides per season (flexible configuration)

DROP TABLE IF EXISTS `dc_seasonal_reward_multipliers`;

CREATE TABLE `dc_seasonal_reward_multipliers` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `multiplier_type` VARCHAR(50) NOT NULL COMMENT 'quest, creature, pvp, achievement, dungeon, raid',
  `base_multiplier` FLOAT DEFAULT 1.0 COMMENT 'Applied to all rewards of this type',
  `day_of_week` TINYINT DEFAULT 0 COMMENT '0=every day, 1=Monday, 7=Sunday (daily variations)',
  `hour_start` TINYINT DEFAULT 0 COMMENT 'Starting hour (UTC) for time-limited bonus',
  `hour_end` TINYINT DEFAULT 24 COMMENT 'Ending hour (UTC) for time-limited bonus',
  `description` VARCHAR(255) COMMENT 'Human-readable description of this multiplier',
  `enabled` BOOLEAN DEFAULT TRUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  KEY `idx_season_type` (`season_id`, `multiplier_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Flexible multiplier overrides for balancing';

-- Example: Season 2 has +15% quest rewards, +10% dungeon rewards on weekends
-- INSERT INTO dc_seasonal_reward_multipliers VALUES
-- (NULL, 2, 'quest', 1.15, 0, 0, 24, 'Season 2: +15% quest rewards all week', 1, NOW()),
-- (NULL, 2, 'dungeon', 1.10, 6, 0, 24, 'Weekend dungeon bonus: +10%', 1, NOW());

-- =====================================================================
-- TABLE: dc_seasonal_reward_config
-- =====================================================================
-- Global settings for seasonal reward system

DROP TABLE IF EXISTS `dc_seasonal_reward_config`;

CREATE TABLE `dc_seasonal_reward_config` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `config_key` VARCHAR(100) NOT NULL COMMENT 'Configuration key (e.g., weekly_token_cap, daily_essence_cap)',
  `config_value` VARCHAR(255) NOT NULL COMMENT 'Configuration value (can be JSON for complex configs)',
  `description` VARCHAR(255) COMMENT 'Human-readable description',
  `modified_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_config_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Global configuration for seasonal reward system';

-- Insert default config values
INSERT INTO `dc_seasonal_reward_config` (`config_key`, `config_value`, `description`) VALUES
('weekly_token_cap', '500', 'Maximum tokens a player can earn per week'),
('daily_token_cap', '0', 'Daily token cap (0=disabled, use weekly cap only)'),
('essence_cap', '0', 'Essence cap per week (0=uncapped)'),
('weekly_reset_day', '0', 'Day of week to reset caps (0=Sunday, 1=Monday, etc)'),
('weekly_reset_hour', '0', 'Hour of day to reset (0=00:00 server time)'),
('min_level_for_rewards', '50', 'Minimum level required to earn rewards'),
('trivial_quest_multiplier', '0.0', 'Multiplier for trivial quests (player level >> quest level)'),
('chest_drop_rate', '0.15', 'Default chest drop chance (0.0-1.0)'),
('boss_group_split', '1', 'Split boss rewards among group (0=give all to killer)'),
('transaction_log_days', '90', 'Days to keep transaction logs before archiving');

ON DUPLICATE KEY UPDATE `modified_at` = CURRENT_TIMESTAMP;

-- =====================================================================
-- SAMPLE DATA FOR TESTING
-- =====================================================================

-- Season 1: Default quests (uncomment to populate test data)
-- INSERT INTO `dc_seasonal_quest_rewards` 
-- (`season_id`, `quest_id`, `reward_type`, `base_token_amount`, `base_essence_amount`, `quest_difficulty`, `seasonal_multiplier`, `is_daily`)
-- VALUES
-- (1, 12000, 1, 15, 0, 2, 1.0, 0),   -- Normal quest: 15 tokens
-- (1, 12001, 1, 20, 0, 3, 1.0, 0),   -- Hard quest: 20 tokens
-- (1, 25000, 3, 50, 25, 3, 1.0, 1),  -- Daily quest: 50 tokens, 25 essence
-- (1, 35000, 3, 100, 50, 4, 1.0, 0); -- Weekly quest: 100 tokens, 50 essence

-- Season 1: Default creatures (uncomment to populate test data)
-- INSERT INTO `dc_seasonal_creature_rewards`
-- (`season_id`, `creature_id`, `reward_type`, `base_token_amount`, `base_essence_amount`, `creature_rank`, `content_type`, `difficulty_level`, `seasonal_multiplier`)
-- VALUES
-- (1, 1000, 3, 50, 10, 2, 1, 2, 1.0),   -- Dungeon boss
-- (1, 2000, 3, 100, 20, 3, 2, 2, 1.0),  -- Raid boss
-- (1, 9999, 3, 500, 100, 3, 3, 3, 1.0); -- World boss

-- Season 1: Sample chest rewards (uncomment to populate)
-- INSERT INTO `dc_seasonal_chest_rewards`
-- (`season_id`, `chest_tier`, `item_id`, `drop_chance`, `weight`, `armor_class`)
-- VALUES
-- (1, 1, 40000, 0.5, 100, NULL),   -- Bronze: Common item
-- (1, 2, 40010, 0.3, 150, NULL),   -- Silver: Uncommon item
-- (1, 3, 40020, 0.1, 200, NULL),   -- Gold: Rare item
-- (1, 4, 40030, 0.05, 500, NULL);  -- Legendary: Epic item
