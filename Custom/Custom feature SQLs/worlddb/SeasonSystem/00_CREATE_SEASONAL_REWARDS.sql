-- ========================================================================
-- CLEAN DROP/CREATE: Seasonal Rewards System - World Database
-- ========================================================================
-- Database: acore_world
-- Purpose: Seasonal quest/creature reward configuration
-- Date: November 22, 2025
-- ========================================================================

USE acore_world;

-- ========================================================================
-- DROP EXISTING TABLES (Clean slate)
-- ========================================================================

DROP TABLE IF EXISTS `dc_seasonal_reward_config`;
DROP TABLE IF EXISTS `dc_seasonal_reward_multipliers`;
DROP TABLE IF EXISTS `dc_seasonal_chest_rewards`;
DROP TABLE IF EXISTS `dc_seasonal_creature_rewards`;
DROP TABLE IF EXISTS `dc_seasonal_quest_rewards`;

-- ========================================================================
-- TABLE: dc_seasonal_quest_rewards
-- ========================================================================
-- Quest reward configurations per season

CREATE TABLE `dc_seasonal_quest_rewards` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Foreign key to dc_seasons.season_id',
  `quest_id` INT UNSIGNED NOT NULL COMMENT 'Quest template ID',
  `reward_type` TINYINT NOT NULL COMMENT '1=Token, 2=Essence, 3=Both',
  `base_token_amount` INT UNSIGNED DEFAULT 0 COMMENT 'Base tokens awarded',
  `base_essence_amount` INT UNSIGNED DEFAULT 0 COMMENT 'Base essence awarded',
  `min_level` TINYINT UNSIGNED DEFAULT 1 COMMENT 'Minimum player level to reward',
  `quest_difficulty` TINYINT DEFAULT 2 COMMENT 'Difficulty tier (0-5, where 2=normal)',
  `seasonal_multiplier` FLOAT DEFAULT 1.0 COMMENT 'Season-specific multiplier',
  `is_daily` BOOLEAN DEFAULT FALSE COMMENT 'Daily quest flag',
  `is_weekly` BOOLEAN DEFAULT FALSE COMMENT 'Weekly quest flag',
  `is_repeatable` BOOLEAN DEFAULT FALSE COMMENT 'Repeatable quest flag',
  `enabled` BOOLEAN DEFAULT TRUE COMMENT 'Enable/disable rewards for this quest',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_quest` (`season_id`, `quest_id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_quest_id` (`quest_id`),
  KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Quest reward configuration per season';

-- ========================================================================
-- TABLE: dc_seasonal_creature_rewards
-- ========================================================================
-- Boss/rare/creature kill reward configurations per season

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
  `minimum_players` TINYINT UNSIGNED DEFAULT 1 COMMENT 'Minimum group size required',
  `group_split_tokens` BOOLEAN DEFAULT TRUE COMMENT 'Split tokens among group',
  `enabled` BOOLEAN DEFAULT TRUE COMMENT 'Enable/disable rewards',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_creature` (`season_id`, `creature_id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_creature_id` (`creature_id`),
  KEY `idx_rank_type` (`creature_rank`, `content_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Boss/Rare/Creature kill reward configuration';

-- ========================================================================
-- TABLE: dc_seasonal_chest_rewards
-- ========================================================================
-- Loot pool for seasonal chests that drop from quests/bosses

CREATE TABLE `dc_seasonal_chest_rewards` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL COMMENT 'Foreign key to dc_seasons.season_id',
  `chest_tier` TINYINT NOT NULL COMMENT 'Tier: 1=Bronze, 2=Silver, 3=Gold, 4=Legendary',
  `item_id` INT UNSIGNED NOT NULL COMMENT 'Item template ID',
  `min_drop_ilvl` SMALLINT UNSIGNED DEFAULT 0 COMMENT 'Minimum item level',
  `max_drop_ilvl` SMALLINT UNSIGNED DEFAULT 0 COMMENT 'Maximum item level',
  `drop_chance` FLOAT NOT NULL DEFAULT 1.0 COMMENT 'Probability 0.0-1.0',
  `weight` INT UNSIGNED DEFAULT 1 COMMENT 'Selection weight (higher=more likely)',
  `armor_class` TINYINT UNSIGNED COMMENT 'Filter: 1=Cloth, 2=Leather, 3=Mail, 4=Plate',
  `slot` TINYINT UNSIGNED COMMENT 'Equipment slot filter (optional)',
  `class_restrictions` VARCHAR(255) COMMENT 'Comma-separated class IDs',
  `spec_restrictions` VARCHAR(255) COMMENT 'Comma-separated spec names',
  `primary_stat` VARCHAR(50) COMMENT 'Primary stat priority (INT, STR, AGI)',
  `enabled` BOOLEAN DEFAULT TRUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  KEY `idx_season_tier` (`season_id`, `chest_tier`),
  KEY `idx_item_id` (`item_id`),
  KEY `idx_chest_tier` (`chest_tier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Chest loot pool configuration';

-- ========================================================================
-- TABLE: dc_seasonal_reward_multipliers
-- ========================================================================
-- Dynamic multiplier overrides per season

CREATE TABLE `dc_seasonal_reward_multipliers` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `multiplier_type` VARCHAR(50) NOT NULL COMMENT 'quest, creature, pvp, achievement, dungeon, raid',
  `base_multiplier` FLOAT DEFAULT 1.0 COMMENT 'Applied to all rewards of this type',
  `day_of_week` TINYINT DEFAULT 0 COMMENT '0=every day, 1=Monday, 7=Sunday',
  `hour_start` TINYINT DEFAULT 0 COMMENT 'Starting hour (UTC)',
  `hour_end` TINYINT DEFAULT 24 COMMENT 'Ending hour (UTC)',
  `description` VARCHAR(255) COMMENT 'Human-readable description',
  `enabled` BOOLEAN DEFAULT TRUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  KEY `idx_season_type` (`season_id`, `multiplier_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Flexible multiplier overrides for balancing';

-- ========================================================================
-- TABLE: dc_seasonal_reward_config
-- ========================================================================
-- Global settings for seasonal reward system

CREATE TABLE `dc_seasonal_reward_config` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `config_key` VARCHAR(100) NOT NULL COMMENT 'Configuration key',
  `config_value` VARCHAR(255) NOT NULL COMMENT 'Configuration value (can be JSON)',
  `description` VARCHAR(255) COMMENT 'Human-readable description',
  `modified_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_config_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Global configuration for seasonal reward system';

-- ========================================================================
-- SEED DATA: Default Configuration
-- ========================================================================

INSERT INTO `dc_seasonal_reward_config` (`config_key`, `config_value`, `description`) VALUES
('weekly_token_cap', '5000', 'Maximum tokens a player can earn per week (0=unlimited)'),
('weekly_essence_cap', '2500', 'Maximum essence a player can earn per week (0=unlimited)'),
('daily_token_cap', '0', 'Daily token cap (0=disabled, use weekly cap only)'),
('daily_essence_cap', '0', 'Daily essence cap (0=disabled)'),
('weekly_reset_day', '2', 'Day of week to reset caps (0=Sunday, 1=Monday, 2=Tuesday)'),
('weekly_reset_hour', '15', 'Hour of day to reset (server time)'),
('min_level_for_rewards', '50', 'Minimum level required to earn rewards'),
('trivial_quest_multiplier', '0.1', 'Multiplier for trivial quests (player level >> quest level)'),
('chest_drop_rate', '0.15', 'Default chest drop chance (0.0-1.0)'),
('boss_group_split', '1', 'Split boss rewards among group (0=give all to killer)'),
('transaction_log_days', '90', 'Days to keep transaction logs before archiving'),
('token_item_id', '49426', 'Item ID for seasonal tokens'),
('essence_item_id', '47241', 'Item ID for seasonal essence');

-- ========================================================================
-- SEED DATA: Example Quest Rewards (Season 1)
-- ========================================================================

INSERT INTO `dc_seasonal_quest_rewards` 
  (`season_id`, `quest_id`, `reward_type`, `base_token_amount`, `base_essence_amount`, 
   `quest_difficulty`, `seasonal_multiplier`, `is_daily`, `is_weekly`, `enabled`)
VALUES
  -- Example normal quests
  (1, 24627, 1, 15, 0, 2, 1.0, 0, 0, 1),  -- Quest: "A Blade Fit For A Champion"
  (1, 24628, 1, 20, 0, 3, 1.0, 0, 0, 1),  -- Quest: "The Edge of Winter"
  (1, 24629, 3, 25, 10, 3, 1.0, 0, 0, 1), -- Quest: "A Worthy Weapon" (tokens + essence)
  
  -- Example daily quests
  (1, 13830, 3, 50, 25, 2, 1.0, 1, 0, 1), -- Daily: "The Last Line Of Defense"
  (1, 13832, 3, 50, 25, 2, 1.0, 1, 0, 1), -- Daily: "Threat From Above"
  
  -- Example weekly quests
  (1, 24590, 3, 100, 50, 4, 1.0, 0, 1, 1); -- Weekly: "Sartharion Must Die!"

-- ========================================================================
-- SEED DATA: Example Creature Rewards (Season 1)
-- ========================================================================

INSERT INTO `dc_seasonal_creature_rewards`
  (`season_id`, `creature_id`, `reward_type`, `base_token_amount`, `base_essence_amount`,
   `creature_rank`, `content_type`, `difficulty_level`, `seasonal_multiplier`, 
   `minimum_players`, `group_split_tokens`, `enabled`)
VALUES
  -- Dungeon bosses (5-man)
  (1, 23954, 3, 50, 10, 2, 1, 2, 1.0, 1, 1, 1),  -- Ingvar the Plunderer (Utgarde Keep)
  (1, 26861, 3, 60, 15, 2, 1, 3, 1.0, 1, 1, 1),  -- King Ymiron (Utgarde Pinnacle)
  (1, 26723, 3, 50, 10, 2, 1, 2, 1.0, 1, 1, 1),  -- Keristrasza (Nexus)
  (1, 27656, 3, 50, 10, 2, 1, 2, 1.0, 1, 1, 1),  -- Ley-Guardian Eregos (Oculus)
  (1, 26533, 3, 60, 15, 2, 1, 3, 1.0, 1, 1, 1),  -- Mal'Ganis (Culling of Stratholme)
  
  -- Raid bosses (10/25-man)
  (1, 15956, 3, 200, 50, 3, 2, 4, 1.5, 10, 1, 1), -- Anub'Rekhan (Naxxramas)
  (1, 15953, 3, 200, 50, 3, 2, 4, 1.5, 10, 1, 1), -- Grand Widow Faerlina
  (1, 15952, 3, 250, 75, 3, 2, 5, 1.5, 10, 1, 1), -- Maexxna
  (1, 28860, 3, 300, 100, 3, 2, 5, 2.0, 10, 1, 1), -- Sartharion (Obsidian Sanctum)
  (1, 28859, 3, 300, 100, 3, 2, 5, 2.0, 10, 1, 1), -- Malygos (Eye of Eternity)
  
  -- World bosses
  (1, 32630, 3, 500, 150, 3, 3, 5, 2.5, 20, 1, 1); -- Archavon the Stone Watcher

-- ========================================================================
-- SEED DATA: Example Chest Rewards (Season 1)
-- ========================================================================

INSERT INTO `dc_seasonal_chest_rewards`
  (`season_id`, `chest_tier`, `item_id`, `drop_chance`, `weight`, 
   `min_drop_ilvl`, `max_drop_ilvl`, `armor_class`, `enabled`)
VALUES
  -- Bronze Tier (common)
  (1, 1, 40000, 0.5, 100, 200, 213, NULL, 1),
  (1, 1, 40001, 0.5, 100, 200, 213, NULL, 1),
  
  -- Silver Tier (uncommon)
  (1, 2, 40010, 0.3, 150, 213, 226, NULL, 1),
  (1, 2, 40011, 0.3, 150, 213, 226, NULL, 1),
  
  -- Gold Tier (rare)
  (1, 3, 40020, 0.15, 200, 226, 239, NULL, 1),
  (1, 3, 40021, 0.15, 200, 226, 239, NULL, 1),
  
  -- Legendary Tier (epic)
  (1, 4, 40030, 0.05, 500, 239, 252, NULL, 1);

-- ========================================================================
-- SEED DATA: Example Multipliers (Season 1)
-- ========================================================================

INSERT INTO `dc_seasonal_reward_multipliers`
  (`season_id`, `multiplier_type`, `base_multiplier`, `day_of_week`, 
   `hour_start`, `hour_end`, `description`, `enabled`)
VALUES
  -- Weekend bonus
  (1, 'dungeon', 1.25, 6, 0, 24, 'Saturday: +25% dungeon rewards', 1),
  (1, 'dungeon', 1.25, 0, 0, 24, 'Sunday: +25% dungeon rewards', 1),
  
  -- Raid night bonus (Friday evenings)
  (1, 'raid', 1.5, 5, 18, 23, 'Friday raid night: +50% raid rewards', 1),
  
  -- Daily quest bonus (every day during peak hours)
  (1, 'quest', 1.15, 0, 17, 22, 'Peak hours: +15% quest rewards', 1);

-- ========================================================================
-- Verification
-- ========================================================================

SELECT '✅ Seasonal Rewards System Tables Created Successfully' AS status;

SELECT 
  TABLE_NAME,
  TABLE_ROWS,
  TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_world'
  AND TABLE_NAME LIKE 'dc_seasonal_%'
ORDER BY TABLE_NAME;

SELECT '========================================' AS divider;
SELECT 'Tables created: 5' AS table_count;
SELECT 'Configuration entries: 13' AS config_count;
SELECT 'Example quest rewards: 6' AS quest_reward_count;
SELECT 'Example creature rewards: 12' AS creature_reward_count;
SELECT 'Example chest rewards: 7' AS chest_reward_count;
SELECT 'Example multipliers: 4' AS multiplier_count;
SELECT '========================================' AS divider;
