-- ========================================================================
-- DC Missing Tables - World Database (acore_world)
-- ========================================================================
-- Purpose: Create the 4 missing tables identified by DC TableChecker
-- Database: acore_world
-- Date: November 29, 2025
-- ========================================================================

USE acore_world;

-- ========================================================================
-- Quest System
-- ========================================================================

CREATE TABLE IF NOT EXISTS `dc_quest_difficulty_mapping` (
    `quest_id` INT UNSIGNED NOT NULL,
    `base_difficulty` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=Easy, 2=Normal, 3=Hard, 4=Heroic, 5=Mythic',
    `scaling_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    `min_level` TINYINT UNSIGNED DEFAULT NULL,
    `max_level` TINYINT UNSIGNED DEFAULT NULL,
    `reward_multiplier` FLOAT NOT NULL DEFAULT 1.0,
    `token_bonus` INT UNSIGNED NOT NULL DEFAULT 0,
    `essence_bonus` INT UNSIGNED NOT NULL DEFAULT 0,
    `notes` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`quest_id`),
    KEY `idx_difficulty` (`base_difficulty`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Quest difficulty settings and reward modifiers';

-- ========================================================================
-- Item Upgrade System
-- ========================================================================

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_tier_items` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tier_id` INT UNSIGNED NOT NULL,
    `item_entry` INT UNSIGNED NOT NULL,
    `slot_type` TINYINT UNSIGNED DEFAULT NULL COMMENT 'Equipment slot',
    `item_class` TINYINT UNSIGNED DEFAULT NULL,
    `item_subclass` TINYINT UNSIGNED DEFAULT NULL,
    `required_level` TINYINT UNSIGNED DEFAULT NULL,
    `base_ilvl` SMALLINT UNSIGNED DEFAULT NULL,
    `max_upgrade_level` TINYINT UNSIGNED NOT NULL DEFAULT 15,
    `upgrade_cost_multiplier` FLOAT NOT NULL DEFAULT 1.0,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `notes` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_tier_item` (`tier_id`, `item_entry`),
    KEY `idx_item_entry` (`item_entry`),
    KEY `idx_tier_id` (`tier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Items that can be upgraded per tier';

-- ========================================================================
-- Mythic+ System
-- ========================================================================

CREATE TABLE IF NOT EXISTS `dc_mythic_plus_dungeons` (
    `dungeon_id` INT UNSIGNED NOT NULL COMMENT 'Map ID',
    `dungeon_name` VARCHAR(100) NOT NULL,
    `short_name` VARCHAR(10) DEFAULT NULL COMMENT 'Abbreviation like UK, AN, etc.',
    `min_level` TINYINT UNSIGNED NOT NULL DEFAULT 80,
    `base_timer` INT UNSIGNED NOT NULL DEFAULT 1800 COMMENT 'Base completion timer in seconds',
    `trash_count` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Required trash kills for completion',
    `boss_count` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `difficulty_rating` TINYINT UNSIGNED NOT NULL DEFAULT 5 COMMENT '1-10 difficulty scale',
    `season_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `teleport_x` FLOAT DEFAULT NULL,
    `teleport_y` FLOAT DEFAULT NULL,
    `teleport_z` FLOAT DEFAULT NULL,
    `teleport_o` FLOAT DEFAULT NULL,
    `icon_path` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`dungeon_id`),
    KEY `idx_season_enabled` (`season_enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Mythic+ dungeon definitions';

-- Insert default WotLK dungeons
INSERT IGNORE INTO `dc_mythic_plus_dungeons` 
    (`dungeon_id`, `dungeon_name`, `short_name`, `base_timer`, `boss_count`, `difficulty_rating`) 
VALUES
    (574, 'Utgarde Keep', 'UK', 1500, 3, 3),
    (575, 'Utgarde Pinnacle', 'UP', 1800, 4, 5),
    (576, 'The Nexus', 'NEX', 1800, 4, 4),
    (578, 'The Oculus', 'OCC', 2100, 4, 7),
    (595, 'The Culling of Stratholme', 'COS', 1500, 5, 6),
    (599, 'Halls of Stone', 'HOS', 1800, 4, 5),
    (600, 'Drak''Tharon Keep', 'DTK', 1500, 4, 4),
    (601, 'Azjol-Nerub', 'AN', 1200, 3, 3),
    (602, 'Halls of Lightning', 'HOL', 1800, 4, 6),
    (604, 'Gundrak', 'GD', 1800, 5, 5),
    (608, 'Violet Hold', 'VH', 1500, 3, 4),
    (619, 'Ahn''kahet: The Old Kingdom', 'OK', 2100, 5, 7),
    (632, 'The Forge of Souls', 'FOS', 1500, 2, 6),
    (649, 'Trial of the Champion', 'TOC', 1200, 3, 5),
    (650, 'Trial of the Champion (H)', 'TOCH', 1200, 3, 6),
    (658, 'Pit of Saron', 'POS', 1800, 3, 7),
    (668, 'Halls of Reflection', 'HOR', 1500, 3, 8);

CREATE TABLE IF NOT EXISTS `dc_mythic_plus_weekly_affixes` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `week_number` TINYINT UNSIGNED NOT NULL COMMENT 'Week of rotation (1-12)',
    `affix1_id` INT UNSIGNED NOT NULL COMMENT 'Primary affix (always active 2+)',
    `affix2_id` INT UNSIGNED DEFAULT NULL COMMENT 'Secondary affix (active 4+)',
    `affix3_id` INT UNSIGNED DEFAULT NULL COMMENT 'Tertiary affix (active 7+)',
    `affix4_id` INT UNSIGNED DEFAULT NULL COMMENT 'Seasonal affix (active 10+)',
    `season_id` INT UNSIGNED NOT NULL DEFAULT 1,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `notes` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_week_season` (`week_number`, `season_id`),
    KEY `idx_season` (`season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Weekly affix rotation schedule';

-- Insert default affix rotation (12 weeks)
INSERT IGNORE INTO `dc_mythic_plus_weekly_affixes` 
    (`week_number`, `affix1_id`, `affix2_id`, `affix3_id`, `season_id`) 
VALUES
    (1, 1, 5, 9, 1),   -- Fortified, Bolstering, Tyrannical
    (2, 2, 6, 10, 1),  -- Tyrannical, Raging, Fortified
    (3, 1, 7, 11, 1),
    (4, 2, 8, 12, 1),
    (5, 1, 5, 13, 1),
    (6, 2, 6, 9, 1),
    (7, 1, 7, 10, 1),
    (8, 2, 8, 11, 1),
    (9, 1, 5, 12, 1),
    (10, 2, 6, 13, 1),
    (11, 1, 7, 9, 1),
    (12, 2, 8, 10, 1);

-- ========================================================================
-- VERIFICATION
-- ========================================================================

SELECT '✅ Created 4 missing tables in acore_world' AS status;

SELECT TABLE_NAME, TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'acore_world'
AND TABLE_NAME IN (
    'dc_quest_difficulty_mapping',
    'dc_item_upgrade_tier_items',
    'dc_mythic_plus_dungeons',
    'dc_mythic_plus_weekly_affixes'
)
ORDER BY TABLE_NAME;
