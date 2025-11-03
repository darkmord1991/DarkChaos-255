-- ============================================
-- Extended Schema: Daily/Weekly Quests & Difficulty Support
-- ============================================

-- ============================================
-- 1. Add Difficulty Column to Mapping Table
-- ============================================
ALTER TABLE `dc_dungeon_quest_mapping` 
ADD COLUMN `difficulty` ENUM('Normal', 'Heroic', 'Mythic', 'Mythic+') NOT NULL DEFAULT 'Normal' COMMENT 'Dungeon difficulty tier' AFTER `level_type`,
ADD KEY `idx_difficulty` (`difficulty`);

-- ============================================
-- 2. Daily Quest Rotation System
-- ============================================
DROP TABLE IF EXISTS `dc_daily_quest_rotation`;
CREATE TABLE `dc_daily_quest_rotation` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `quest_id` INT UNSIGNED NOT NULL COMMENT 'Custom daily quest ID (700101-700150)',
  `base_quest_id` INT UNSIGNED DEFAULT NULL COMMENT 'Reference to base dungeon quest',
  `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Target dungeon map ID',
  `difficulty` ENUM('Normal', 'Heroic', 'Mythic', 'Mythic+') NOT NULL DEFAULT 'Normal',
  `is_active` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = currently active',
  `rotation_day` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Day of week (0-6, 0=Sunday)',
  `token_reward` SMALLINT UNSIGNED NOT NULL DEFAULT 10 COMMENT 'Bonus tokens for daily completion',
  `last_reset` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_quest_id` (`quest_id`),
  KEY `idx_active` (`is_active`),
  KEY `idx_rotation_day` (`rotation_day`),
  KEY `idx_map_difficulty` (`map_id`, `difficulty`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Daily dungeon quest rotation';

-- ============================================
-- 3. Weekly Quest Rotation System
-- ============================================
DROP TABLE IF EXISTS `dc_weekly_quest_rotation`;
CREATE TABLE `dc_weekly_quest_rotation` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `quest_id` INT UNSIGNED NOT NULL COMMENT 'Custom weekly quest ID (700201-700250)',
  `base_quest_id` INT UNSIGNED DEFAULT NULL COMMENT 'Reference to base dungeon quest',
  `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Target dungeon map ID',
  `difficulty` ENUM('Normal', 'Heroic', 'Mythic', 'Mythic+') NOT NULL DEFAULT 'Heroic',
  `is_active` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = currently active',
  `rotation_week` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Week number in rotation cycle',
  `token_reward` SMALLINT UNSIGNED NOT NULL DEFAULT 50 COMMENT 'Bonus tokens for weekly completion',
  `requires_group` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Requires group completion',
  `last_reset` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_quest_id` (`quest_id`),
  KEY `idx_active` (`is_active`),
  KEY `idx_rotation_week` (`rotation_week`),
  KEY `idx_map_difficulty` (`map_id`, `difficulty`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Weekly dungeon quest rotation';

-- ============================================
-- 4. Player Quest Statistics Tracking
-- ============================================
DROP TABLE IF EXISTS `dc_player_dungeon_stats`;
CREATE TABLE `dc_player_dungeon_stats` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `map_id` SMALLINT UNSIGNED NOT NULL COMMENT 'Dungeon map ID',
  `difficulty` ENUM('Normal', 'Heroic', 'Mythic', 'Mythic+') NOT NULL DEFAULT 'Normal',
  `total_completions` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Total quest completions',
  `daily_completions` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Daily quest completions',
  `weekly_completions` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Weekly quest completions',
  `fastest_completion_time` INT UNSIGNED DEFAULT NULL COMMENT 'Fastest completion in seconds',
  `last_completion` TIMESTAMP NULL DEFAULT NULL,
  `first_completion` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`guid`, `map_id`, `difficulty`),
  KEY `idx_guid` (`guid`),
  KEY `idx_map_difficulty` (`map_id`, `difficulty`),
  KEY `idx_total_completions` (`total_completions`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player dungeon quest statistics';

-- ============================================
-- 5. Achievement Progress Tracking
-- ============================================
DROP TABLE IF EXISTS `dc_achievement_progress`;
CREATE TABLE `dc_achievement_progress` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `achievement_id` INT UNSIGNED NOT NULL COMMENT 'Achievement entry ID',
  `current_progress` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Current progress value',
  `required_progress` INT UNSIGNED NOT NULL COMMENT 'Required progress for completion',
  `completed` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = achievement earned',
  `date_completed` TIMESTAMP NULL DEFAULT NULL,
  `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`, `achievement_id`),
  KEY `idx_completed` (`completed`),
  KEY `idx_achievement` (`achievement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Custom achievement progress tracking';

-- ============================================
-- 6. Difficulty Tier Configuration
-- ============================================
DROP TABLE IF EXISTS `dc_difficulty_config`;
CREATE TABLE `dc_difficulty_config` (
  `difficulty` ENUM('Normal', 'Heroic', 'Mythic', 'Mythic+') NOT NULL,
  `min_level` TINYINT UNSIGNED NOT NULL DEFAULT 80 COMMENT 'Minimum level requirement',
  `token_multiplier` DECIMAL(3,2) NOT NULL DEFAULT 1.00 COMMENT 'Token reward multiplier',
  `xp_multiplier` DECIMAL(3,2) NOT NULL DEFAULT 1.00 COMMENT 'XP reward multiplier',
  `requires_group` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Requires group',
  `min_group_size` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Minimum group size',
  `enabled` TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Difficulty enabled',
  PRIMARY KEY (`difficulty`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Difficulty tier configuration';

-- ============================================
-- 7. Insert Default Difficulty Configuration
-- ============================================
INSERT INTO `dc_difficulty_config` 
(`difficulty`, `min_level`, `token_multiplier`, `xp_multiplier`, `requires_group`, `min_group_size`, `enabled`) VALUES
('Normal',   1,  1.00, 1.00, 0, 1, 1),
('Heroic',   80, 1.50, 1.25, 0, 1, 1),
('Mythic',   80, 2.00, 1.50, 1, 3, 1),
('Mythic+',  80, 3.00, 2.00, 1, 5, 0); -- Disabled by default, enable when M+ system ready

-- ============================================
-- 8. Quest Reset Tracking
-- ============================================
DROP TABLE IF EXISTS `dc_quest_reset_tracking`;
CREATE TABLE `dc_quest_reset_tracking` (
  `reset_type` ENUM('Daily', 'Weekly') NOT NULL,
  `last_reset` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `next_reset` TIMESTAMP NOT NULL,
  `reset_count` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`reset_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tracks daily/weekly reset times';

-- Initialize reset tracking
INSERT INTO `dc_quest_reset_tracking` (`reset_type`, `last_reset`, `next_reset`) VALUES
('Daily', NOW(), DATE_ADD(DATE_ADD(CURDATE(), INTERVAL 1 DAY), INTERVAL 6 HOUR)),  -- 6 AM next day
('Weekly', NOW(), DATE_ADD(DATE_ADD(NOW(), INTERVAL (7 - WEEKDAY(NOW())) DAY), INTERVAL 6 HOUR));  -- Next Wednesday 6 AM

-- ============================================
-- 9. Daily Quest Pool (7 days rotation)
-- ============================================
-- Each day has 5 daily quests (1 per expansion + 2 rotating)
INSERT INTO `dc_daily_quest_rotation` 
(`quest_id`, `map_id`, `difficulty`, `rotation_day`, `token_reward`, `is_active`) VALUES
-- Sunday (Day 0)
(700101, 230, 'Normal',  0, 10, 0),  -- Blackrock Depths
(700102, 543, 'Heroic',  0, 15, 0),  -- Hellfire Ramparts (Heroic)
(700103, 600, 'Normal',  0, 10, 0),  -- Drak'Tharon Keep
(700104, 90,  'Normal',  0, 10, 0),  -- Gnomeregan
(700105, 329, 'Normal',  0, 10, 0),  -- Stratholme

-- Monday (Day 1)
(700106, 429, 'Normal',  1, 10, 0),  -- Dire Maul
(700107, 558, 'Heroic',  1, 15, 0),  -- Auchenai Crypts (Heroic)
(700108, 604, 'Normal',  1, 10, 0),  -- Gundrak
(700109, 189, 'Normal',  1, 10, 0),  -- Scarlet Monastery
(700110, 70,  'Normal',  1, 10, 0),  -- Uldaman

-- Tuesday (Day 2)
(700111, 229, 'Normal',  2, 10, 0),  -- Blackrock Spire
(700112, 547, 'Heroic',  2, 15, 0),  -- Slave Pens (Heroic)
(700113, 574, 'Normal',  2, 10, 0),  -- Utgarde Keep
(700114, 36,  'Normal',  2, 10, 0),  -- Deadmines
(700115, 289, 'Normal',  2, 10, 0),  -- Scholomance

-- Wednesday (Day 3)
(700116, 349, 'Normal',  3, 10, 0),  -- Maraudon
(700117, 555, 'Heroic',  3, 15, 0),  -- Shadow Labyrinth (Heroic)
(700118, 599, 'Normal',  3, 10, 0),  -- Halls of Stone
(700119, 43,  'Normal',  3, 10, 0),  -- Wailing Caverns
(700120, 209, 'Normal',  3, 10, 0),  -- Zul'Farrak

-- Thursday (Day 4)
(700121, 109, 'Normal',  4, 10, 0),  -- Sunken Temple
(700122, 545, 'Heroic',  4, 15, 0),  -- Steamvault (Heroic)
(700123, 576, 'Normal',  4, 10, 0),  -- Nexus
(700124, 48,  'Normal',  4, 10, 0),  -- Blackfathom Deeps
(700125, 129, 'Normal',  4, 10, 0),  -- Razorfen Downs

-- Friday (Day 5)
(700126, 33,  'Normal',  5, 10, 0),  -- Shadowfang Keep
(700127, 557, 'Heroic',  5, 15, 0),  -- Mana-Tombs (Heroic)
(700128, 601, 'Normal',  5, 10, 0),  -- Azjol-Nerub
(700129, 389, 'Normal',  5, 10, 0),  -- Ragefire Chasm
(700130, 47,  'Normal',  5, 10, 0),  -- Razorfen Kraul

-- Saturday (Day 6)
(700131, 34,  'Normal',  6, 10, 0),  -- Stockade
(700132, 546, 'Heroic',  6, 15, 0),  -- Underbog (Heroic)
(700133, 602, 'Normal',  6, 10, 0),  -- Halls of Lightning
(700134, 269, 'Normal',  6, 10, 0),  -- Caverns of Time
(700135, 189, 'Normal',  6, 10, 0);  -- Scarlet Monastery

-- ============================================
-- 10. Weekly Quest Pool (4 weeks rotation)
-- ============================================
-- Each week has 3 weekly quests (harder content, higher rewards)
INSERT INTO `dc_weekly_quest_rotation` 
(`quest_id`, `map_id`, `difficulty`, `rotation_week`, `token_reward`, `requires_group`, `is_active`) VALUES
-- Week 1
(700201, 230, 'Heroic', 1, 50, 1, 0),  -- Blackrock Depths (Heroic, Group)
(700202, 543, 'Mythic', 1, 100, 1, 0), -- Hellfire Ramparts (Mythic, Group)
(700203, 600, 'Heroic', 1, 50, 1, 0),  -- Drak'Tharon Keep (Heroic, Group)

-- Week 2
(700204, 429, 'Heroic', 2, 50, 1, 0),  -- Dire Maul (Heroic, Group)
(700205, 558, 'Mythic', 2, 100, 1, 0), -- Auchenai Crypts (Mythic, Group)
(700206, 574, 'Heroic', 2, 50, 1, 0),  -- Utgarde Keep (Heroic, Group)

-- Week 3
(700207, 229, 'Heroic', 3, 50, 1, 0),  -- Blackrock Spire (Heroic, Group)
(700208, 547, 'Mythic', 3, 100, 1, 0), -- Slave Pens (Mythic, Group)
(700209, 604, 'Heroic', 3, 50, 1, 0),  -- Gundrak (Heroic, Group)

-- Week 4
(700210, 349, 'Heroic', 4, 50, 1, 0),  -- Maraudon (Heroic, Group)
(700211, 555, 'Mythic', 4, 100, 1, 0), -- Shadow Labyrinth (Mythic, Group)
(700212, 599, 'Heroic', 4, 50, 1, 0);  -- Halls of Stone (Heroic, Group)

-- ============================================
-- NOTES:
-- ============================================
-- Daily quests: 35 total (5 per day × 7 days)
-- Weekly quests: 12 total (3 per week × 4 weeks)
-- Quest ID ranges:
--   - Daily: 700101-700135 (35 quests)
--   - Weekly: 700201-700212 (12 quests)
--   - Reserved for expansion: 700136-700200, 700213-700300
--
-- To activate today's dailies:
--   UPDATE dc_daily_quest_rotation SET is_active = 1 
--   WHERE rotation_day = WEEKDAY(NOW());
--
-- To activate this week's weeklies:
--   UPDATE dc_weekly_quest_rotation SET is_active = 1 
--   WHERE rotation_week = WEEK(NOW()) % 4 + 1;
