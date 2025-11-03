-- ============================================
-- Dark Chaos Achievement System
-- Custom achievement category and progression tracking
-- ============================================

-- ============================================
-- 1. Achievement Category (Dark Chaos)
-- ============================================
-- Note: This would normally go in achievement_category_dbc table
-- Category ID: 200 (Dark Chaos)
-- For reference, achievement categories:
--   92 = General, 96 = Quests, 14807 = Dungeons & Raids
-- 
-- Since we can't easily add DBC categories, we'll use existing category
-- but track our achievements separately in the database

-- ============================================
-- 2. Custom Achievement Definitions
-- ============================================
DROP TABLE IF EXISTS `dc_custom_achievements`;
CREATE TABLE `dc_custom_achievements` (
  `achievement_id` INT UNSIGNED NOT NULL COMMENT 'Achievement ID (50000-50999)',
  `category` VARCHAR(50) NOT NULL DEFAULT 'Dark Chaos' COMMENT 'Achievement category',
  `subcategory` VARCHAR(50) DEFAULT NULL COMMENT 'Subcategory',
  `name` VARCHAR(255) NOT NULL COMMENT 'Achievement name',
  `description` TEXT NOT NULL COMMENT 'Achievement description',
  `reward_title` VARCHAR(100) DEFAULT NULL COMMENT 'Title reward (if any)',
  `reward_item` INT UNSIGNED DEFAULT NULL COMMENT 'Item reward ID',
  `reward_tokens` SMALLINT UNSIGNED DEFAULT 0 COMMENT 'Bonus tokens',
  `points` TINYINT UNSIGNED NOT NULL DEFAULT 10 COMMENT 'Achievement points',
  `required_count` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Required completions',
  `is_account_wide` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Account-wide achievement',
  `parent_achievement` INT UNSIGNED DEFAULT NULL COMMENT 'Parent achievement ID',
  `display_order` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Display order in list',
  `enabled` TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Achievement enabled',
  PRIMARY KEY (`achievement_id`),
  KEY `idx_category` (`category`, `subcategory`),
  KEY `idx_parent` (`parent_achievement`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Custom Dark Chaos achievements';

-- ============================================
-- 3. Achievement Criteria (How to Earn)
-- ============================================
DROP TABLE IF EXISTS `dc_achievement_criteria`;
CREATE TABLE `dc_achievement_criteria` (
  `criteria_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `achievement_id` INT UNSIGNED NOT NULL COMMENT 'Achievement ID',
  `criteria_type` ENUM('DungeonQuest', 'MapCompletion', 'DifficultyCompletion', 'TotalQuests', 'DailyStreak', 'WeeklyStreak', 'GroupQuests') NOT NULL,
  `required_value` INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Required amount',
  `map_id` SMALLINT UNSIGNED DEFAULT NULL COMMENT 'Specific dungeon (if applicable)',
  `difficulty` ENUM('Normal', 'Heroic', 'Mythic', 'Mythic+', 'Any') DEFAULT 'Any' COMMENT 'Required difficulty',
  `description` VARCHAR(255) DEFAULT NULL COMMENT 'Criteria description',
  PRIMARY KEY (`criteria_id`),
  KEY `idx_achievement` (`achievement_id`),
  KEY `idx_type` (`criteria_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Achievement criteria definitions';

-- ============================================
-- 4. Insert Dark Chaos Achievement Definitions
-- ============================================

-- ===== CATEGORY: Dungeon Initiate =====
INSERT INTO `dc_custom_achievements` 
(`achievement_id`, `category`, `subcategory`, `name`, `description`, `points`, `required_count`, `display_order`) VALUES
(50001, 'Dark Chaos', 'Dungeon Initiate', 'First Steps', 'Complete your first dungeon quest', 10, 1, 10),
(50002, 'Dark Chaos', 'Dungeon Initiate', 'Quest Explorer', 'Complete 10 dungeon quests', 10, 10, 20),
(50003, 'Dark Chaos', 'Dungeon Initiate', 'Quest Veteran', 'Complete 25 dungeon quests', 15, 25, 30),
(50004, 'Dark Chaos', 'Dungeon Initiate', 'Quest Master', 'Complete 50 dungeon quests', 20, 50, 40),
(50005, 'Dark Chaos', 'Dungeon Initiate', 'Dungeon Enthusiast', 'Complete 100 dungeon quests', 25, 100, 50);

-- ===== CATEGORY: Expansion Mastery =====
INSERT INTO `dc_custom_achievements` 
(`achievement_id`, `category`, `subcategory`, `name`, `description`, `points`, `required_count`, `display_order`) VALUES
(50010, 'Dark Chaos', 'Expansion Mastery', 'Classic Dungeoneer', 'Complete all Classic dungeon quests', 30, 341, 100),
(50011, 'Dark Chaos', 'Expansion Mastery', 'Outland Conqueror', 'Complete all TBC dungeon quests', 30, 37, 110),
(50012, 'Dark Chaos', 'Expansion Mastery', 'Northrend Hero', 'Complete all WotLK dungeon quests', 30, 57, 120),
(50013, 'Dark Chaos', 'Expansion Mastery', 'Legendary Questmaster', 'Complete ALL dungeon quests across all expansions', 50, 435, 130);

-- ===== CATEGORY: Difficulty Challenges =====
INSERT INTO `dc_custom_achievements` 
(`achievement_id`, `category`, `subcategory`, `name`, `description`, `reward_title`, `points`, `required_count`, `display_order`) VALUES
(50020, 'Dark Chaos', 'Difficulty', 'Heroic Challenger', 'Complete 25 Heroic difficulty quests', NULL, 20, 25, 200),
(50021, 'Dark Chaos', 'Difficulty', 'Heroic Conqueror', 'Complete 50 Heroic difficulty quests', 'the Heroic', 30, 50, 210),
(50022, 'Dark Chaos', 'Difficulty', 'Mythic Challenger', 'Complete 10 Mythic difficulty quests', NULL, 30, 10, 220),
(50023, 'Dark Chaos', 'Difficulty', 'Mythic Conqueror', 'Complete 25 Mythic difficulty quests', 'the Mythic', 40, 25, 230),
(50024, 'Dark Chaos', 'Difficulty', 'Mythic+ Pioneer', 'Complete 10 Mythic+ quests', 'the Unstoppable', 50, 10, 240);

-- ===== CATEGORY: Daily/Weekly Dedication =====
INSERT INTO `dc_custom_achievements` 
(`achievement_id`, `category`, `subcategory`, `name`, `description`, `reward_tokens`, `points`, `required_count`, `display_order`) VALUES
(50030, 'Dark Chaos', 'Dedication', 'Daily Devotion', 'Complete 7 daily quests', 50, 10, 7, 300),
(50031, 'Dark Chaos', 'Dedication', 'Daily Dedication', 'Complete 30 daily quests', 100, 15, 30, 310),
(50032, 'Dark Chaos', 'Dedication', 'Daily Master', 'Complete 100 daily quests', 250, 25, 100, 320),
(50033, 'Dark Chaos', 'Dedication', 'Weekly Warrior', 'Complete 10 weekly quests', 100, 15, 10, 330),
(50034, 'Dark Chaos', 'Dedication', 'Weekly Champion', 'Complete 25 weekly quests', 250, 25, 25, 340),
(50035, 'Dark Chaos', 'Dedication', '7-Day Streak', 'Complete daily quests for 7 consecutive days', 150, 20, 7, 350),
(50036, 'Dark Chaos', 'Dedication', '30-Day Streak', 'Complete daily quests for 30 consecutive days', 500, 50, 30, 360);

-- ===== CATEGORY: Dungeon Specific =====
INSERT INTO `dc_custom_achievements` 
(`achievement_id`, `category`, `subcategory`, `name`, `description`, `points`, `required_count`, `display_order`) VALUES
-- Classic Dungeons
(50100, 'Dark Chaos', 'Classic Dungeons', 'Depths Master', 'Complete all Blackrock Depths quests', 15, 43, 1000),
(50101, 'Dark Chaos', 'Classic Dungeons', 'Time Traveler', 'Complete all Caverns of Time quests', 15, 40, 1010),
(50102, 'Dark Chaos', 'Classic Dungeons', 'Spire Conqueror', 'Complete all Blackrock Spire quests', 15, 37, 1020),
(50103, 'Dark Chaos', 'Classic Dungeons', 'Dire Maul Expert', 'Complete all Dire Maul quests', 15, 37, 1030),
(50104, 'Dark Chaos', 'Classic Dungeons', 'Uldaman Explorer', 'Complete all Uldaman quests', 10, 29, 1040),
(50105, 'Dark Chaos', 'Classic Dungeons', 'Gnomeregan Technician', 'Complete all Gnomeregan quests', 10, 28, 1050),

-- TBC Dungeons
(50110, 'Dark Chaos', 'TBC Dungeons', 'Hellfire Hero', 'Complete all Hellfire Citadel quests', 15, 15, 1100),
(50111, 'Dark Chaos', 'TBC Dungeons', 'Auchindoun Champion', 'Complete all Auchindoun quests', 15, 12, 1110),
(50112, 'Dark Chaos', 'TBC Dungeons', 'Coilfang Conqueror', 'Complete all Coilfang quests', 15, 10, 1120),

-- WotLK Dungeons
(50120, 'Dark Chaos', 'WotLK Dungeons', 'Utgarde Vanquisher', 'Complete all Utgarde quests', 10, 8, 1200),
(50121, 'Dark Chaos', 'WotLK Dungeons', 'Nexus Master', 'Complete all Nexus quests', 10, 7, 1210),
(50122, 'Dark Chaos', 'WotLK Dungeons', 'Icecrown Champion', 'Complete all Icecrown dungeons quests', 15, 15, 1220);

-- ===== CATEGORY: Speed & Efficiency =====
INSERT INTO `dc_custom_achievements` 
(`achievement_id`, `category`, `subcategory`, `name`, `description`, `points`, `required_count`, `display_order`) VALUES
(50200, 'Dark Chaos', 'Efficiency', 'Speed Runner I', 'Complete 10 quests in under 15 minutes each', 15, 10, 2000),
(50201, 'Dark Chaos', 'Efficiency', 'Speed Runner II', 'Complete 25 quests in under 15 minutes each', 20, 25, 2010),
(50202, 'Dark Chaos', 'Efficiency', 'Marathon Runner', 'Complete 5 quests in a single day', 10, 5, 2020),
(50203, 'Dark Chaos', 'Efficiency', 'Quest Speedster', 'Complete 10 quests in a single day', 20, 10, 2030);

-- ===== CATEGORY: Group Play =====
INSERT INTO `dc_custom_achievements` 
(`achievement_id`, `category`, `subcategory`, `name`, `description`, `reward_title`, `points`, `required_count`, `display_order`) VALUES
(50300, 'Dark Chaos', 'Group Play', 'Team Player', 'Complete 25 group quests', NULL, 15, 25, 3000),
(50301, 'Dark Chaos', 'Group Play', 'Group Leader', 'Complete 50 group quests', 'Group Leader', 25, 50, 3010),
(50302, 'Dark Chaos', 'Group Play', 'Party Hero', 'Complete 100 group quests', 'Party Hero', 35, 100, 3020);

-- ===== CATEGORY: Meta Achievements =====
INSERT INTO `dc_custom_achievements` 
(`achievement_id`, `category`, `subcategory`, `name`, `description`, `reward_title`, `reward_tokens`, `points`, `required_count`, `is_account_wide`, `display_order`) VALUES
(50900, 'Dark Chaos', 'Meta', 'Dungeon Quest Champion', 'Earn 10 Dungeon Quest achievements', 'Dungeon Champion', 500, 50, 10, 1, 9000),
(50901, 'Dark Chaos', 'Meta', 'Dungeon Quest Legend', 'Earn 25 Dungeon Quest achievements', 'Dungeon Legend', 1000, 75, 25, 1, 9010),
(50902, 'Dark Chaos', 'Meta', 'Dark Chaos Master', 'Earn ALL Dungeon Quest achievements', 'Dark Chaos Master', 2500, 100, 50, 1, 9020);

-- ============================================
-- 5. Insert Achievement Criteria
-- ============================================

-- Criteria for "First Steps" (50001)
INSERT INTO `dc_achievement_criteria` (`achievement_id`, `criteria_type`, `required_value`, `description`) VALUES
(50001, 'TotalQuests', 1, 'Complete 1 dungeon quest');

-- Criteria for "Quest Explorer" (50002)
INSERT INTO `dc_achievement_criteria` (`achievement_id`, `criteria_type`, `required_value`, `description`) VALUES
(50002, 'TotalQuests', 10, 'Complete 10 dungeon quests');

-- Criteria for "Quest Veteran" (50003)
INSERT INTO `dc_achievement_criteria` (`achievement_id`, `criteria_type`, `required_value`, `description`) VALUES
(50003, 'TotalQuests', 25, 'Complete 25 dungeon quests');

-- Criteria for "Quest Master" (50004)
INSERT INTO `dc_achievement_criteria` (`achievement_id`, `criteria_type`, `required_value`, `description`) VALUES
(50004, 'TotalQuests', 50, 'Complete 50 dungeon quests');

-- Criteria for "Dungeon Enthusiast" (50005)
INSERT INTO `dc_achievement_criteria` (`achievement_id`, `criteria_type`, `required_value`, `description`) VALUES
(50005, 'TotalQuests', 100, 'Complete 100 dungeon quests');

-- Criteria for Expansion Mastery
INSERT INTO `dc_achievement_criteria` (`achievement_id`, `criteria_type`, `required_value`, `description`) VALUES
(50010, 'TotalQuests', 341, 'Complete all 341 Classic dungeon quests'),
(50011, 'TotalQuests', 37, 'Complete all 37 TBC dungeon quests'),
(50012, 'TotalQuests', 57, 'Complete all 57 WotLK dungeon quests'),
(50013, 'TotalQuests', 435, 'Complete all 435 dungeon quests');

-- Criteria for Difficulty Challenges
INSERT INTO `dc_achievement_criteria` (`achievement_id`, `criteria_type`, `required_value`, `difficulty`, `description`) VALUES
(50020, 'DifficultyCompletion', 25, 'Heroic', 'Complete 25 Heroic quests'),
(50021, 'DifficultyCompletion', 50, 'Heroic', 'Complete 50 Heroic quests'),
(50022, 'DifficultyCompletion', 10, 'Mythic', 'Complete 10 Mythic quests'),
(50023, 'DifficultyCompletion', 25, 'Mythic', 'Complete 25 Mythic quests'),
(50024, 'DifficultyCompletion', 10, 'Mythic+', 'Complete 10 Mythic+ quests');

-- Criteria for Dungeon Specific (Blackrock Depths example)
INSERT INTO `dc_achievement_criteria` (`achievement_id`, `criteria_type`, `required_value`, `map_id`, `description`) VALUES
(50100, 'MapCompletion', 43, 230, 'Complete all Blackrock Depths quests'),
(50101, 'MapCompletion', 40, 269, 'Complete all Caverns of Time quests'),
(50102, 'MapCompletion', 37, 229, 'Complete all Blackrock Spire quests'),
(50103, 'MapCompletion', 37, 429, 'Complete all Dire Maul quests'),
(50104, 'MapCompletion', 29, 70, 'Complete all Uldaman quests'),
(50105, 'MapCompletion', 28, 90, 'Complete all Gnomeregan quests');

-- Criteria for Daily/Weekly
INSERT INTO `dc_achievement_criteria` (`achievement_id`, `criteria_type`, `required_value`, `description`) VALUES
(50030, 'DailyStreak', 7, 'Complete 7 daily quests'),
(50031, 'DailyStreak', 30, 'Complete 30 daily quests'),
(50032, 'DailyStreak', 100, 'Complete 100 daily quests'),
(50033, 'WeeklyStreak', 10, 'Complete 10 weekly quests'),
(50034, 'WeeklyStreak', 25, 'Complete 25 weekly quests'),
(50035, 'DailyStreak', 7, 'Complete daily quests for 7 consecutive days'),
(50036, 'DailyStreak', 30, 'Complete daily quests for 30 consecutive days');

-- Criteria for Group Play
INSERT INTO `dc_achievement_criteria` (`achievement_id`, `criteria_type`, `required_value`, `description`) VALUES
(50300, 'GroupQuests', 25, 'Complete 25 group quests'),
(50301, 'GroupQuests', 50, 'Complete 50 group quests'),
(50302, 'GroupQuests', 100, 'Complete 100 group quests');

-- ============================================
-- 6. Achievement Display Helper View
-- ============================================
CREATE OR REPLACE VIEW `dc_achievement_summary` AS
SELECT 
    a.achievement_id,
    a.category,
    a.subcategory,
    a.name,
    a.description,
    a.points,
    a.reward_title,
    a.reward_tokens,
    GROUP_CONCAT(CONCAT(c.criteria_type, ':', c.required_value) SEPARATOR ', ') AS criteria_summary,
    a.display_order
FROM dc_custom_achievements a
LEFT JOIN dc_achievement_criteria c ON a.achievement_id = c.achievement_id
WHERE a.enabled = 1
GROUP BY a.achievement_id
ORDER BY a.display_order;

-- ============================================
-- ACHIEVEMENT SUMMARY
-- ============================================
-- Total Achievements: 50+
-- Categories:
--   - Dungeon Initiate: 5 achievements (general progression)
--   - Expansion Mastery: 4 achievements (complete all quests per expansion)
--   - Difficulty: 5 achievements (Heroic/Mythic challenges)
--   - Dedication: 7 achievements (daily/weekly completion)
--   - Dungeon Specific: 12 achievements (individual dungeon mastery)
--   - Efficiency: 4 achievements (speed running)
--   - Group Play: 3 achievements (group content)
--   - Meta: 3 achievements (overall mastery)
--
-- Achievement ID Ranges:
--   50001-50099: General progression
--   50100-50199: Dungeon specific
--   50200-50299: Speed & efficiency
--   50300-50399: Group play
--   50900-50999: Meta achievements
--
-- Total Points Available: 1000+
-- Titles Available: 7
-- Token Rewards: 5,400+ tokens possible
